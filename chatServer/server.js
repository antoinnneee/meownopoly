const WebSocket = require('ws');
const http = require('http');
const db = require('./database');
const cleanup = require('./cleanup');

// Initialize TTL cleanup (every hour)
cleanup.init(60 * 60 * 1000);

const PORT = process.env.PORT || 3000;
const MAX_PAYLOAD_SIZE = 128 * 1024; // 128 KB

const server = http.createServer((req, res) => {
    res.writeHead(200);
    res.end('Blind Relay Chat Server is running.');
});

const wss = new WebSocket.Server({ server });

// Room management: Map<SessionID, Set<Socket>>
const rooms = new Map();

wss.on('connection', (ws) => {
    console.log('New client connected');

    ws.on('message', (data) => {
        try {
            if (data.length > MAX_PAYLOAD_SIZE) {
                return sendError(ws, 'PAYLOAD_TOO_LARGE', 'Message exceeds 128KB limit');
            }

            const message = JSON.parse(data);
            handleCommand(ws, message);
        } catch (err) {
            console.error('Error processing message:', err);
            sendError(ws, 'INVALID_FORMAT', 'Message must be valid JSON');
        }
    });

    ws.on('close', () => {
        console.log('Client disconnected');
        removeFromRooms(ws);
    });
});

function handleCommand(ws, msg) {
    const { type, payload } = msg;

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
    const history = db.getHistory(session_id);

    ws.send(JSON.stringify({
        type: 'INIT_SESSION',
        payload: {
            key_package: session ? session.key_package : null,
            nonce: session ? session.key_nonce : null,
            history: history || []
        }
    }));
}

function handlePublishKey(ws, payload) {
    const { session_id, blob, nonce } = payload;
    if (!session_id || !blob || !nonce) return;

    const result = db.createSession(session_id, blob, nonce);

    if (result.changes === 0) {
        // Key already exists, we don't overwrite
        console.log(`Key package already exists for session ${session_id}`);
    } else {
        console.log(`Key package published for session ${session_id}`);
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

function sendError(ws, code, message) {
    ws.send(JSON.stringify({
        type: 'ERROR',
        payload: { code, message }
    }));
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
