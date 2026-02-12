const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const dbPath = path.join(__dirname, 'chat.db');
const db = new Database(dbPath);

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

module.exports = {
  // Session methods
  getSession: (sessionId) => {
    return db.prepare('SELECT * FROM sessions WHERE session_id = ?').get(sessionId);
  },
  getSessionKeys: (sessionId) => {
    const session = db.prepare('SELECT version, key_package, key_nonce, password_hash FROM sessions WHERE session_id = ?').get(sessionId);
    return session ? [session] : [];
  },
  createSession: (sessionId, passwordHash, keyPackage, keyNonce) => {
    db.prepare('INSERT OR IGNORE INTO sessions (session_id, password_hash, key_package, key_nonce, version) VALUES (?, ?, ?, ?, 1)')
      .run(sessionId, passwordHash, keyPackage, keyNonce);
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
  cleanupOldData: (hours = 24) => {
    const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();

    db.transaction(() => {
      // Delete old messages
      db.prepare('DELETE FROM messages WHERE server_timestamp < ?').run(cutoff);
      // Delete sessions with no messages and older than cutoff
      db.prepare(`
        DELETE FROM sessions 
        WHERE created_at < ? 
        AND session_id NOT IN (SELECT DISTINCT session_id FROM messages)
      `).run(cutoff);
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
  deleteOldestMessages: (count = 50) => {
    return db.prepare(`
            DELETE FROM messages 
            WHERE id IN (
                SELECT id FROM messages 
                ORDER BY id ASC 
                LIMIT ?
            )
        `).run(count);
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
  addParticipant: (sessionId, playerId, nickname) => {
    return db.prepare('INSERT OR IGNORE INTO participants (session_id, player_id, nickname) VALUES (?, ?, ?)')
      .run(sessionId, playerId, nickname || '');
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
	getAllSessions: () => {
	return db.prepare('SELECT * FROM sessions ORDER BY created_at DESC').all();
	},
  // Expose db pour stats
  db: db
};
