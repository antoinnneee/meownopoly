const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const dbPath = path.join(__dirname, 'chat.db');
const db = new Database(dbPath);

// Initialize tables
db.exec(`
  CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    key_package TEXT,
    key_nonce TEXT,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS session_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    version INTEGER,
    key_package TEXT,
    key_nonce TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(session_id) REFERENCES sessions(session_id)
  );

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
`);

// Migration: add sender_nickname for existing DBs
try {
  db.prepare('ALTER TABLE messages ADD COLUMN sender_nickname TEXT').run();
} catch (e) {
  // Column already exists
}

module.exports = {
  // Session methods
  getSession: (sessionId) => {
    return db.prepare('SELECT * FROM sessions WHERE session_id = ?').get(sessionId);
  },
  getSessionKeys: (sessionId) => {
    return db.prepare('SELECT version, key_package, key_nonce FROM session_keys WHERE session_id = ? ORDER BY version ASC').all(sessionId);
  },
  createSession: (sessionId, keyPackage, keyNonce) => {
    db.transaction(() => {
      db.prepare('INSERT OR IGNORE INTO sessions (session_id, key_package, key_nonce, version) VALUES (?, ?, ?, 1)')
        .run(sessionId, keyPackage, keyNonce);
      db.prepare('INSERT OR IGNORE INTO session_keys (session_id, version, key_package, key_nonce) VALUES (?, 1, ?, ?)')
        .run(sessionId, keyPackage, keyNonce);
    })();
  },
  updateSession: (sessionId, keyPackage, keyNonce) => {
    return db.transaction(() => {
      const session = db.prepare('SELECT version FROM sessions WHERE session_id = ?').get(sessionId);
      if (!session) return { changes: 0 };

      const newVersion = session.version + 1;
      db.prepare('UPDATE sessions SET key_package = ?, key_nonce = ?, version = ? WHERE session_id = ?')
        .run(keyPackage, keyNonce, newVersion, sessionId);
      db.prepare('INSERT INTO session_keys (session_id, version, key_package, key_nonce) VALUES (?, ?, ?, ?)')
        .run(sessionId, newVersion, keyPackage, keyNonce);

      return { changes: 1, version: newVersion };
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

  // Expose db pour stats
  db: db
};
