require('dotenv').config();
const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');
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
const ENABLE_DASHBOARD = process.env.ENABLE_DASHBOARD === 'true';
const MAX_SESSIONS = 500; // Limite de sessions actives

function debug(...args) {
    if (DEBUG_MODE) {
        const timestamp = new Date().toISOString();
        console.log(`[DEBUG] ${timestamp}:`, ...args);
    }
}

debug('Server starting in DEBUG mode...');

const server = http.createServer((req, res) => {
    // API pour les statistiques du serveur
    if (req.url === '/api/stats' && ENABLE_DASHBOARD) {
        res.writeHead(200, {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        });

        const stats = {
            connections: wss.clients.size,
            rooms: rooms.size,
            messages: getTotalMessages(),
            sessions: Array.from(rooms.keys()).map(sessionId => ({
                id: sessionId,
                participants: rooms.get(sessionId).size,
                messages: getSessionMessageCount(sessionId)
            })),
            uptime: process.uptime(),
            memory: process.memoryUsage(),
            dbSize: db.getDbSize()
        };

        res.end(JSON.stringify(stats));
        return;
    }

    // Servir le dashboard si activé
    if (ENABLE_DASHBOARD) {
        const url = req.url === '/' ? '/dashboard.html' : req.url;

        const mimeTypes = {
            '.html': 'text/html',
            '.css': 'text/css',
            '.js': 'text/javascript',
            '.json': 'application/json',
            '.png': 'image/png',
            '.jpg': 'image/jpg',
            '.gif': 'image/gif',
            '.svg': 'image/svg+xml',
            '.ico': 'image/x-icon'
        };

        // Servir uniquement les fichiers du dashboard et labo
        const allowedFiles = ['/dashboard.html', '/dashboard.css', '/dashboard.js', '/chat_crypto.js', '/labo.html'];
        if (allowedFiles.includes(url)) {
            // Construire le chemin complet du fichier
            const fileName = url.substring(1); // Enlever le '/' initial
            const filePath = path.join(__dirname, fileName);
            const extname = path.extname(filePath);
            const contentType = mimeTypes[extname] || 'text/plain';

            // Vérifier que le fichier existe
            fs.access(filePath, fs.constants.F_OK, (err) => {
                if (err) {
                    console.error(`[Dashboard] Fichier introuvable: ${filePath}`);
                    res.writeHead(404, { 'Content-Type': 'text/plain' });
                    res.end(`Fichier non trouvé: ${fileName}\nChemin recherché: ${filePath}`);
                    return;
                }

                // Lire et servir le fichier
                fs.readFile(filePath, (err, content) => {
                    if (err) {
                        console.error(`[Dashboard] Erreur de lecture: ${err.message}`);
                        res.writeHead(500, { 'Content-Type': 'text/plain' });
                        res.end(`Erreur serveur: ${err.code}\nFichier: ${fileName}`);
                    } else {
                        res.writeHead(200, { 'Content-Type': contentType });
                        res.end(content, 'utf-8');
                    }
                });
            });
        } else {
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end('<html><body><h1>Meownopoly Chat Server</h1><p>Dashboard disponible sur <a href="/dashboard.html">/dashboard.html</a></p><p>Labo disponible sur <a href="/labo.html">/labo.html</a></p></body></html>');
        }
    } else {
        res.writeHead(200);
        res.end('Blind Relay Chat Server is running.');
    }
});

const wss = new WebSocket.Server({ server });

// Room management: Map<SessionID, Set<Socket>>
const rooms = new Map();

// Sessions bloquées en attente d'une rotation de clé (nouveau participant)
const keyRotationRequired = new Set();

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
        case 'GET_PARTICIPANTS':
            handleGetParticipants(ws, payload);
            break;
        case 'LEAVE_SESSION':
            handleLeaveSession(ws, payload);
            break;
        case 'DELETE_SESSION':
            handleDeleteSession(ws, payload);
            break;
        case 'LIST_SESSIONS':
            handleListSessions(ws);
            break;
        default:
            sendError(ws, 'UNKNOWN_COMMAND', `Command ${type} not recognized`);
    }
}

function handleJoinSession(ws, payload) {
    const { session_id, player_id, player_nickname } = payload;
    if (!session_id || !player_id) return;

    // VÉRIFICATION: Limite de sessions
    if (!rooms.has(session_id) && rooms.size >= MAX_SESSIONS) {
        return sendError(ws, 'MAX_SESSIONS_REACHED', 
            `Server has reached maximum capacity (${MAX_SESSIONS} active sessions). Please try again later.`);
    }

    ws.player_id = player_id;
    ws.player_nickname = player_nickname || '';
    ws.session_id = session_id;

    // Check if participant is already known in DB
    const isKnownParticipant = db.isParticipant(session_id, player_id);
    const isNewParticipant = !isKnownParticipant;

    if (!rooms.has(session_id)) {
        rooms.set(session_id, new Set());
    }
    rooms.get(session_id).add(ws);

    // If new, add to DB
    if (isNewParticipant) {
        db.addParticipant(session_id, player_id, player_nickname);
    }

    // Update nickname in case it changed or was missing
    if (isKnownParticipant && player_nickname) {
        // Optional: update nickname in DB if needed, but for now we trust the join payload
    }

    const session = db.getSession(session_id);
    let keys = [];
    let history = [];

    // If they are a known participant (rejoining), they assume they can read history if they have the keys.
    // If they are NEW, they get nothing until rotation (or if we changed that logic).
    // Actually, "isNewParticipant" logic in original code was about "is there anyone else".
    // We strictly follow: If you are NEW to the DB, you trigger rotation.

    if (isKnownParticipant) {
        // Send current key if available
        const sessionKeys = db.getSessionKeys(session_id);
        if (sessionKeys && sessionKeys.length > 0) {
            keys = sessionKeys;
        }
        // Send history (enc)
        history = db.getHistory(session_id) || [];
    }

    ws.send(JSON.stringify({
        type: 'INIT_SESSION',
        payload: {
            current_version: session ? session.version : 0,
            keys,
            history,
            new_joiner: isNewParticipant
        }
    }));

    if (isNewParticipant) {
        keyRotationRequired.add(session_id);
        const newParticipantMsg = JSON.stringify({
            type: 'NEW_PARTICIPANT',
            payload: { session_id, player_id, nickname: player_nickname }
        });
        const currentRoom = rooms.get(session_id);
        currentRoom.forEach(client => {
            if (client !== ws && client.readyState === WebSocket.OPEN) {
                client.send(newParticipantMsg);
            }
        });
        debug(`New participant ${player_id} added to DB for session ${session_id}; key rotation required`);
    } else {
        debug(`Participant ${player_id} rejoined session ${session_id}`);
    }
}

function handlePublishKey(ws, payload) {
    const { session_id, blob, nonce } = payload;
    if (!session_id || !blob || !nonce) return;

    const result = db.updateSession(session_id, blob, nonce);
    const version = result.changes === 0 ? 1 : result.version;

    if (result.changes === 0) {
        db.createSession(session_id, blob, nonce);
        debug(`Key package created for session ${session_id}`);
    } else {
        debug(`Key package updated/rotated for session ${session_id} (Version ${version})`);
    }

    keyRotationRequired.delete(session_id);

    const room = rooms.get(session_id);
    if (room) {
        const updateMessage = JSON.stringify({
            type: 'KEY_UPDATE',
            payload: {
                version,
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

function handleSendMessage(ws, payload) {
    const { session_id, sender_id, sender_nickname, payload: ciphertext, nonce, key_v } = payload;
    if (!session_id || !sender_id || !ciphertext || !nonce) return;

    if (keyRotationRequired.has(session_id)) {
        return sendError(ws, 'KEY_ROTATION_REQUIRED', 'A new participant joined; a client must publish a new key before sending messages');
    }

    const nickname = sender_nickname || (ws.player_nickname || '');
    const result = db.saveMessage(session_id, sender_id, nickname, ciphertext, nonce, key_v);

    const outboundMessage = {
        type: 'NEW_MESSAGE',
        payload: {
            msg_id: result.lastInsertRowid,
            sender_id,
            sender_nickname: nickname,
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

function handleGetParticipants(ws, payload) {
    const { session_id } = payload;
    if (!session_id) return;

    const dbParticipants = db.getParticipants(session_id);
    const room = rooms.get(session_id);

    const participants = dbParticipants.map(p => {
        let isOnline = false;
        if (room) {
            for (const client of room) {
                if (client.player_id === p.player_id && client.readyState === WebSocket.OPEN) {
                    isOnline = true;
                    break;
                }
            }
        }
        return {
            player_id: p.player_id,
            player_nickname: p.nickname,
            status: isOnline ? 'online' : 'offline'
        };
    });

    ws.send(JSON.stringify({
        type: 'PARTICIPANTS_LIST',
        payload: {
            session_id,
            count: participants.length,
            participants
        }
    }));
    debug(`Participants list sent for session ${session_id}: ${participants.length} participant(s)`);
}

function handleListSessions(ws) {
    debug('Listing all active sessions');
    
    // Récupère toutes les sessions actives
    const activeSessions = [];
    
    for (const [sessionId, clients] of rooms.entries()) {
        const participants = db.getParticipants(sessionId);
        const session = db.getSession(sessionId);
        
        // Ne lister que les sessions qui ont des participants
        if (participants.length > 0) {
            // Déterminer qui est en ligne
            const onlinePlayerIds = new Set();
            for (const client of clients) {
                if (client.player_id && client.readyState === WebSocket.OPEN) {
                    onlinePlayerIds.add(client.player_id);
                }
            }
            
            activeSessions.push({
                session_id: sessionId,
                host_id: participants[0].player_id, // Premier participant = hôte
                host_nickname: participants[0].nickname || participants[0].player_id,
                player_count: participants.length,
                max_players: 4, // Valeur par défaut, sera personnalisable plus tard
                created_at: session ? session.created_at : new Date().toISOString(),
                online_count: onlinePlayerIds.size,
                status: participants.length >= 4 ? 'full' : 'available'
            });
        }
    }
    
    // Trier par date de création (plus récentes en premier)
    activeSessions.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    
    // Limiter à MAX_SESSIONS
    const limitedSessions = activeSessions.slice(0, MAX_SESSIONS);
    
    ws.send(JSON.stringify({
        type: 'SESSIONS_LIST',
        payload: {
            sessions: limitedSessions,
            total: activeSessions.length,
            limit: MAX_SESSIONS,
            limited: activeSessions.length > MAX_SESSIONS
        }
    }));
    
    debug(`Sent ${limitedSessions.length}/${activeSessions.length} sessions to client (limit: ${MAX_SESSIONS})`);
}

function handleLeaveSession(ws, payload) {
    const { session_id, player_id } = payload;
    if (!session_id || !player_id) return;

    // Verify identity (optional but good practice: ensure ws.player_id matches)
    if (ws.player_id !== player_id) {
        return sendError(ws, 'FORBIDDEN', 'Cannot leave session for another player');
    }

    db.removeParticipant(session_id, player_id);

    // Broadcast leave logic
    const room = rooms.get(session_id);
    if (room) {
        // Notify remaining participants
        const leftMsg = JSON.stringify({
            type: 'PARTICIPANT_LEFT',
            payload: {
                session_id,
                player_id
            }
        });

        room.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(leftMsg);
            }
        });

        // Remove socket from room if present
        if (room.has(ws)) {
            room.delete(ws);
        }

        if (room.size === 0) {
            rooms.delete(session_id);
            keyRotationRequired.delete(session_id);
        }
    }

    // Leaving triggers key rotation necessity for remaining members to secure future messages
    keyRotationRequired.add(session_id);

    ws.send(JSON.stringify({
        type: 'LEFT_SESSION',
        payload: { session_id }
    }));

    debug(`Participant ${player_id} explicitly left session ${session_id}`);
}

function handleDeleteSession(ws, payload) {
    const { session_id } = payload;
    if (!session_id) return;

    // Optional: Check if user has rights to delete (e.g. is creator or admin)
    // For now, any participant can delete (blind relay logic) or maybe just anyone who knows the ID.
    // Let's assume anyone who can connect can delete for now, or check participation.
    if (!db.isParticipant(session_id, ws.player_id)) {
        return sendError(ws, 'FORBIDDEN', 'You must be a participant to delete the session');
    }

    // Delete from DB
    db.deleteSession(session_id);

    // Notify and disconnect all
    const room = rooms.get(session_id);
    if (room) {
        const endedMsg = JSON.stringify({
            type: 'SESSION_ENDED',
            payload: { session_id, reason: 'Session deleted by user' }
        });

        // We iterate and send, then clear the room
        for (const client of room) {
            if (client.readyState === WebSocket.OPEN) {
                client.send(endedMsg);
            }
            // clear session data from socket
            client.session_id = null;
            client.player_id = null;
            // We might want to keep the connection open but they are no longer in "session"
        }
        rooms.delete(session_id);
    }
    keyRotationRequired.delete(session_id);

    debug(`Session ${session_id} deleted by ${ws.player_id}`);
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
        const sessionId = ws.session_id;
        const playerId = ws.player_id;
        const room = rooms.get(sessionId);
        room.delete(ws);

        if (room.size === 0) {
            rooms.delete(sessionId);
            // We do NOT delete keyRotationRequired here immediately if we want persistent state, 
            // but for now, if no one is online, no one can rotate. 
            // When someone joins, they will see if they are new or known.
        } else if (playerId) {
            // Disconnection does NOT trigger PARTICIPANT_LEFT broadcast
            // nor does it remove them from the DB.
            debug(`Participant ${playerId} disconnected from session ${sessionId} (still in DB)`);
        }
    }
}

function getTotalMessages() {
    try {
        const result = db.db.prepare('SELECT COUNT(*) as count FROM messages').get();
        return result.count || 0;
    } catch (err) {
        return 0;
    }
}

function getSessionMessageCount(sessionId) {
    try {
        const result = db.db.prepare('SELECT COUNT(*) as count FROM messages WHERE session_id = ?').get(sessionId);
        return result.count || 0;
    } catch (err) {
        console.error('Error counting session messages:', err);
        return 0;
    }
}

server.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
    if (ENABLE_DASHBOARD) {
        console.log(`Dashboard disponible sur http://localhost:${PORT}/dashboard.html`);
        console.log(`Labo disponible sur http://localhost:${PORT}/labo.html`);
    }
});
