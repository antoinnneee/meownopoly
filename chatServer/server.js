require('dotenv').config();
const WebSocket = require('ws');
const http = require('http');
const db = require('./database');
const cleanup = require('./cleanup');

// Initialize TTL cleanup (every hour) - Optional
const enableTtl = process.env.ENABLE_TTL !== 'false';
if (enableTtl) {
    const ttlInterval = process.env.TTL_INTERVAL_MS || 60 * 60 * 1000;
    cleanup.init(ttlInterval);
} else {
    console.log('[Cleanup] TTL cleanup is DISABLED by environment variable.');
}

const PORT = process.env.PORT || 3000;
const MAX_PAYLOAD_SIZE = parseInt(process.env.MAX_PAYLOAD_SIZE) || 10 * 1024 * 1024; // 10 MB
const MAX_DB_SIZE = parseInt(process.env.MAX_DB_SIZE) || 500 * 1024 * 1024; // 500 MB
const DEBUG_MODE = process.env.DEBUG_MODE === 'true';

function debug(...args) {
    if (DEBUG_MODE) {
        const timestamp = new Date().toISOString();
        console.log(`[DEBUG] ${timestamp}:`, ...args);
    }
}

debug('Server starting in DEBUG mode...');

const server = http.createServer((req, res) => {
    res.writeHead(200);
    res.end('Blind Relay Chat Server is running.');
});

const wss = new WebSocket.Server({ server });

// Room management: Map<SessionID, Set<Socket>>
const rooms = new Map();

wss.on('connection', (ws) => {
    debug('New client connected');

    ws.on('message', (data) => {
        try {
            debug(`Received raw data: ${data.length} bytes`);
            if (data.length > MAX_PAYLOAD_SIZE) {
                return sendError(ws, 'PAYLOAD_TOO_LARGE', `Message exceeds ${MAX_PAYLOAD_SIZE / (1024 * 1024)}MB limit`);
            }

            const message = JSON.parse(data);
            debug(`Received command: ${message.type}`, message.payload);
            handleCommand(ws, message);

            // Periodic check of DB size after a message is processed
            checkDbSize();
        } catch (err) {
            console.error('Error processing message:', err);
            sendError(ws, 'INVALID_FORMAT', 'Message must be valid JSON');
        }
    });

    ws.on('close', () => {
        debug('Client disconnected');
        removeFromRooms(ws);
    });
});

function handleCommand(ws, msg) {
    const { type, payload } = msg;
    debug(`Processing command: ${type}`, payload);

    switch (type) {
        case 'JOIN_SESSION':
            handleJoinSession(ws, payload);
            break;
        case 'PUBLISH_KEY':
            handlePublishKey(ws, payload);
            break;
        case 'SEND_MSG':
            handleSendMessage(ws, payload);
            break;
        case 'GET_HISTORY':
            handleGetHistory(ws, payload);
            break;
        case 'CLEAR_HISTORY':
            handleClearHistory(ws, payload);
            break;
        default:
            sendError(ws, 'UNKNOWN_COMMAND', `Command ${type} not recognized`);
    }
}

function handleJoinSession(ws, payload) {
    const { session_id, player_id } = payload;
    if (!session_id || !player_id) return;

    // Track player_id on ws object for management
    ws.player_id = player_id;
    ws.session_id = session_id;

    // Add to in-memory room
    if (!rooms.has(session_id)) {
        rooms.set(session_id, new Set());
    }
    rooms.get(session_id).add(ws);

    // Fetch session metadata and history
    const session = db.getSession(session_id);
    // Forward Secrecy: We DO NOT send past keys to new joiners.
    // They must generate their own V(N) key and can only read future messages.
    const history = db.getHistory(session_id);

    ws.send(JSON.stringify({
        type: 'INIT_SESSION',
        payload: {
            current_version: session ? session.version : 0,
            keys: [], // Empty to enforce Forward Secrecy
            history: history || []
        }
    }));
}

function handlePublishKey(ws, payload) {
    const { session_id, blob, nonce } = payload;
    if (!session_id || !blob || !nonce) return;

    // We allow overwriting for key rotation
    const result = db.updateSession(session_id, blob, nonce);

    if (result.changes === 0) {
        // If update failed (session doesn't exist yet), create it
        db.createSession(session_id, blob, nonce);
        debug(`Key package created for session ${session_id}`);

        // Notify everyone (including creator) of the new V1 key
        const room = rooms.get(session_id);
        if (room) {
            const updateMessage = JSON.stringify({
                type: 'KEY_UPDATE',
                payload: {
                    version: 1,
                    key_package: blob,
                    nonce: nonce
                }
            });
            room.forEach(client => {
                if (client.readyState === WebSocket.OPEN) {
                    client.send(updateMessage);
                }
            });
        }
    } else {
        debug(`Key package updated/rotated for session ${session_id} (Version ${result.version})`);

        // Broadcast the update to all OTHER clients in the room
        const room = rooms.get(session_id);
        if (room) {
            const updateMessage = JSON.stringify({
                type: 'KEY_UPDATE',
                payload: {
                    version: result.version,
                    key_package: blob,
                    nonce: nonce
                }
            });
            room.forEach(client => {
                if (client.readyState === WebSocket.OPEN) {
                    client.send(updateMessage);
                }
            });
        }
    }
}

function handleSendMessage(ws, payload) {
    const { session_id, sender_id, payload: ciphertext, nonce, key_v } = payload;
    if (!session_id || !sender_id || !ciphertext || !nonce) return;

    // Persist message
    const result = db.saveMessage(session_id, sender_id, ciphertext, nonce, key_v);

    const outboundMessage = {
        type: 'NEW_MESSAGE',
        payload: {
            msg_id: result.lastInsertRowid,
            sender_id,
            payload: ciphertext,
            nonce,
            key_version: key_v,
            timestamp: new Date().toISOString()
        }
    };

    // Broadcast to all in the same room
    const room = rooms.get(session_id);
    if (room) {
        const rawOutbound = JSON.stringify(outboundMessage);
        room.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(rawOutbound);
            }
        });
    }
}

function handleGetHistory(ws, payload) {
    const { session_id, before_id } = payload;
    if (!session_id) return;

    const history = db.getHistory(session_id, 50, before_id);
    ws.send(JSON.stringify({
        type: 'HISTORY_RESULT',
        payload: { history }
    }));
}

function handleClearHistory(ws, payload) {
    const { session_id } = payload;
    if (!session_id) return;

    // Delete from DB
    db.clearMessages(session_id);

    // Broadcast cleared event
    const room = rooms.get(session_id);
    if (room) {
        const clearMsg = JSON.stringify({
            type: 'HISTORY_CLEARED',
            payload: { session_id }
        });
        room.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(clearMsg);
            }
        });
    }
}

function sendError(ws, code, message) {
    ws.send(JSON.stringify({
        type: 'ERROR',
        payload: { code, message }
    }));
}

function checkDbSize() {
    const size = db.getDbSize();
    if (size > MAX_DB_SIZE) {
        console.log(`[Database] Size limit reached (${(size / 1024 / 1024).toFixed(2)}MB > ${(MAX_DB_SIZE / 1024 / 1024).toFixed(2)}MB). Cleaning up...`);
        db.deleteOldestMessages(50);
    }
}

function removeFromRooms(ws) {
    if (ws.session_id && rooms.has(ws.session_id)) {
        const room = rooms.get(ws.session_id);
        room.delete(ws);
        if (room.size === 0) {
            rooms.delete(ws.session_id);
        }
    }
}

server.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
});
