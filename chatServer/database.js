const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const dbPath = path.join(__dirname, 'chat.db');
const db = new Database(dbPath);

// WAL : lectures concurrentes pendant une écriture, plus robuste aux crashes,
// performance correcte pour notre charge (single-writer Node.js).
db.pragma('journal_mode = WAL');
db.pragma('synchronous = NORMAL');
db.pragma('foreign_keys = ON');

// Initialize tables
db.exec(`
  CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    password_hash TEXT,
    key_package TEXT,
    key_nonce TEXT,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );

  DROP TABLE IF EXISTS session_keys;

  CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    sender_id TEXT,
    sender_nickname TEXT,
    payload TEXT,
    nonce TEXT,
    key_version INTEGER,
    server_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(session_id) REFERENCES sessions(session_id)
  );

  CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);

  CREATE TABLE IF NOT EXISTS participants (
    session_id TEXT,
    player_id TEXT,
    nickname TEXT,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (session_id, player_id)
  );
`);

// Migration: add sender_nickname and password_hash for existing DBs
try {
  db.prepare('ALTER TABLE messages ADD COLUMN sender_nickname TEXT').run();
} catch (e) { }
try {
  db.prepare('ALTER TABLE sessions ADD COLUMN password_hash TEXT').run();
} catch (e) { }
try {
  db.prepare('ALTER TABLE sessions ADD COLUMN session_name TEXT').run();
} catch (e) { }
try {
  db.prepare('ALTER TABLE sessions ADD COLUMN max_players INTEGER DEFAULT 4').run();
} catch (e) { }
try {
  db.prepare('ALTER TABLE sessions ADD COLUMN is_public INTEGER DEFAULT 1').run();
} catch (e) { }
// Host explicite. Avant cette colonne, `isHost` reposait uniquement sur
// `MIN(joined_at)`, ce qui gardait l'ancien hôte comme propriétaire même
// après une migration P2P (élection d'un successeur). On stocke maintenant
// l'hôte courant de façon explicite, mis à jour par TRANSFER_HOST.
try {
  db.prepare('ALTER TABLE sessions ADD COLUMN host_player_id TEXT').run();
} catch (e) { }

module.exports = {
  // Session methods
  getSession: (sessionId) => {
    return db.prepare('SELECT * FROM sessions WHERE session_id = ?').get(sessionId);
  },
  getSessionKeys: (sessionId) => {
    const session = db.prepare('SELECT version, key_package, key_nonce, password_hash FROM sessions WHERE session_id = ?').get(sessionId);
    return session ? [session] : [];
  },
  getAllSessions: () => {
    return db.prepare(
      'SELECT session_id, session_name, password_hash, version, created_at, max_players, is_public, host_player_id FROM sessions ORDER BY created_at DESC'
    ).all();
  },
  createSession: (sessionId, sessionName, passwordHash, keyPackage, keyNonce, maxPlayers = 4, isPublic = 1, hostPlayerId = null) => {
    db.prepare('INSERT OR IGNORE INTO sessions (session_id, session_name, password_hash, key_package, key_nonce, version, max_players, is_public, host_player_id) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)')
      .run(sessionId, sessionName || '', passwordHash, keyPackage, keyNonce, maxPlayers, isPublic ? 1 : 0, hostPlayerId || null);
  },
  updateSession: (sessionId, keyPackage, keyNonce) => {
    return db.transaction(() => {
      const session = db.prepare('SELECT version FROM sessions WHERE session_id = ?').get(sessionId);
      if (!session) return { changes: 0 };

      const newVersion = session.version + 1;
      db.prepare('UPDATE sessions SET key_package = ?, key_nonce = ?, version = ? WHERE session_id = ?')
        .run(keyPackage, keyNonce, newVersion, sessionId);

      return { changes: 1, version: newVersion };
    })();
  },
  // Phase 8 — host migration : renommer une session existante sans toucher à
  // son id, ses participants ni ses messages. Utilisé quand le nouveau host
  // adopte la session pour mettre à jour le prefix `[EDIT:<hostId>]`.
  renameSession: (sessionId, newName) => {
    return db.prepare('UPDATE sessions SET session_name = ? WHERE session_id = ?')
      .run(newName || '', sessionId);
  },
  // Migration d'hôte P2P : bascule le propriétaire de la session sur
  // un autre participant. Appelé par TRANSFER_HOST. Sans cet UPDATE,
  // l'ancien hôte (premier joined_at) garderait les droits admin
  // même après élection d'un successeur.
  setHost: (sessionId, hostPlayerId) => {
    return db.prepare('UPDATE sessions SET host_player_id = ? WHERE session_id = ?')
      .run(hostPlayerId || null, sessionId);
  },
  // Clear host_player_id si l'hôte désigné est ce joueur. Appelé quand un
  // participant part : évite que `isHost` continue de retourner `true` pour
  // lui s'il revient (il regagnerait les droits admin sur la session qu'il a
  // pourtant quittée). Le fallback legacy (MIN(joined_at) sur participants
  // restants) prend le relais jusqu'au prochain TRANSFER_HOST client-side
  // (élection Phase 8).
  clearHostIfMatches: (sessionId, playerId) => {
    return db.prepare(
      'UPDATE sessions SET host_player_id = NULL WHERE session_id = ? AND host_player_id = ?'
    ).run(sessionId, playerId);
  },
  deleteSession: (sessionId) => {
    db.transaction(() => {
      db.prepare('DELETE FROM messages WHERE session_id = ?').run(sessionId);
      db.prepare('DELETE FROM participants WHERE session_id = ?').run(sessionId);
      db.prepare('DELETE FROM sessions WHERE session_id = ?').run(sessionId);
    })();
  },

  // Message methods
  saveMessage: (sessionId, senderId, senderNickname, payload, nonce, keyVersion) => {
    return db.prepare(`
      INSERT INTO messages (session_id, sender_id, sender_nickname, payload, nonce, key_version)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(sessionId, senderId, senderNickname || '', payload, nonce, keyVersion);
  },
  getHistory: (sessionId, limit = 50, beforeId = null) => {
    if (beforeId) {
      return db.prepare(`
        SELECT * FROM messages 
        WHERE session_id = ? AND id < ? 
        ORDER BY id DESC LIMIT ?
      `).all(sessionId, beforeId, limit).reverse();
    }
    return db.prepare(`
      SELECT * FROM messages 
      WHERE session_id = ? 
      ORDER BY id DESC LIMIT ?
    `).all(sessionId, limit).reverse();
  },

  // Cleanup
  // Purge en cascade : messages vieux → sessions sans messages & vieilles →
  // participants et messages orphelins (sessions déjà supprimées). Sans la
  // purge des participants orphelins, la table grossit indéfiniment au fil
  // des TTL successifs.
  cleanupOldData: (hours = 24) => {
    const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();

    db.transaction(() => {
      db.prepare('DELETE FROM messages WHERE server_timestamp < ?').run(cutoff);
      db.prepare(`
        DELETE FROM sessions
        WHERE created_at < ?
        AND session_id NOT IN (SELECT DISTINCT session_id FROM messages)
      `).run(cutoff);
      db.prepare(`
        DELETE FROM participants
        WHERE session_id NOT IN (SELECT session_id FROM sessions)
      `).run();
      db.prepare(`
        DELETE FROM messages
        WHERE session_id NOT IN (SELECT session_id FROM sessions)
      `).run();
    })();
  },

  // Size management
  getDbSize: () => {
    try {
      const stats = fs.statSync(dbPath);
      return stats.size; // in bytes
    } catch (err) {
      console.error('Error checking DB size:', err);
      return 0;
    }
  },
  // Purge proportionnelle : sur gros spam, `count=50` ne suffisait pas à
  // repasser sous MAX_DB_SIZE entre deux messages → boucle d'évincement
  // permanente. On purge désormais un pourcentage du total (par défaut 10 %),
  // borné par un minimum pour les petites DB.
  deleteOldestMessages: (count = null, fraction = 0.1, minCount = 100) => {
    let toDelete = count;
    if (toDelete == null) {
      const total = db.prepare('SELECT COUNT(*) AS c FROM messages').get().c || 0;
      toDelete = Math.max(minCount, Math.floor(total * fraction));
    }
    return db.prepare(`
      DELETE FROM messages
      WHERE id IN (
        SELECT id FROM messages
        ORDER BY id ASC
        LIMIT ?
      )
    `).run(toDelete);
  },
  vacuum: () => {
    db.exec('VACUUM');
  },

  clearMessages: (sessionId) => {
    return db.prepare('DELETE FROM messages WHERE session_id = ?').run(sessionId);
  },

  clearAllData: () => {
    db.transaction(() => {
      db.prepare('DELETE FROM messages').run();
      db.prepare('DELETE FROM participants').run();
      db.prepare('DELETE FROM sessions').run();
    })();
    db.exec('VACUUM');
  },

  // Participant methods
  // UPSERT : un participant qui rejoint avec un nouveau pseudo voit son nickname
  // mis à jour (sinon INSERT OR IGNORE gelait l'ancien pseudo pour toujours).
  // joined_at n'est PAS touché sur conflit → l'ordre d'arrivée historique est
  // préservé pour le fallback legacy `getHost`.
  addParticipant: (sessionId, playerId, nickname) => {
    return db.prepare(`
      INSERT INTO participants (session_id, player_id, nickname)
      VALUES (?, ?, ?)
      ON CONFLICT(session_id, player_id) DO UPDATE SET nickname = excluded.nickname
    `).run(sessionId, playerId, nickname || '');
  },
  removeParticipant: (sessionId, playerId) => {
    return db.prepare('DELETE FROM participants WHERE session_id = ? AND player_id = ?')
      .run(sessionId, playerId);
  },
  isParticipant: (sessionId, playerId) => {
    const res = db.prepare('SELECT 1 FROM participants WHERE session_id = ? AND player_id = ?').get(sessionId, playerId);
    return !!res;
  },
  getParticipants: (sessionId) => {
    return db.prepare('SELECT player_id, nickname FROM participants WHERE session_id = ? ORDER BY joined_at ASC').all(sessionId);
  },
  /**
   * Host de la session. Priorité à sessions.host_player_id (mis à jour
   * par TRANSFER_HOST lors d'une migration P2P), fallback au premier
   * participant à avoir rejoint (legacy, pour les sessions créées avant
   * la migration de schéma).
   * Retourne null si aucun participant.
   */
  getHost: (sessionId) => {
    const session = db.prepare('SELECT host_player_id FROM sessions WHERE session_id = ?').get(sessionId);
    if (session && session.host_player_id) {
      const part = db.prepare('SELECT player_id, nickname FROM participants WHERE session_id = ? AND player_id = ?')
        .get(sessionId, session.host_player_id);
      if (part) return part;
      // host_player_id pointe sur quelqu'un qui n'est plus là : on retombe sur
      // le plus ancien participant et on ne corrige PAS ici — le prochain
      // TRANSFER_HOST (ou renameSession) ajustera.
    }
    return db.prepare('SELECT player_id, nickname FROM participants WHERE session_id = ? ORDER BY joined_at ASC LIMIT 1').get(sessionId) || null;
  },
  isHost: (sessionId, playerId) => {
    const session = db.prepare('SELECT host_player_id FROM sessions WHERE session_id = ?').get(sessionId);
    if (session && session.host_player_id) {
      return session.host_player_id === playerId;
    }
    // Legacy fallback : premier joined_at.
    const host = db.prepare('SELECT player_id FROM participants WHERE session_id = ? ORDER BY joined_at ASC LIMIT 1').get(sessionId);
    return !!host && host.player_id === playerId;
  },

  // Expose db pour stats
  db: db
};
