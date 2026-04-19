require('dotenv').config();
const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');
const db = require('./database');
const cleanup = require('./cleanup');
const stun = require('./simple_stun');

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
const STUN_PORT = parseInt(process.env.STUN_PORT) || 3478;
const DEBUG_MODE = process.env.DEBUG_MODE === 'true';
const ENABLE_DASHBOARD = process.env.ENABLE_DASHBOARD === 'true';
const MAX_SESSIONS = parseInt(process.env.MAX_SESSIONS) || 500; // Limite de sessions actives
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || ''; // Si défini, requis pour les commandes admin (CLEAR_ALL_SESSIONS)

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

        const detailedSessions = getDetailedSessionList();
        const stats = {
            connections: wss.clients.size,
            rooms: rooms.size,
            messages: getTotalMessages(),
            sessions: detailedSessions.map(s => ({
                id: s.session_id,
                participants: s.player_count,
                messages: getSessionMessageCount(s.session_id)
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

    // COMMANDS THAT REQUIRE BEING JOINED TO A SESSION
    const sessionCommands = [
        'PUBLISH_KEY', 'SEND_MSG', 'SEND_COMMAND', 'GET_HISTORY',
        'CLEAR_HISTORY', 'GET_PARTICIPANTS', 'LEAVE_SESSION',
        'DELETE_SESSION', 'KICK', 'RENAME_SESSION', 'TRANSFER_HOST'
    ];

    if (sessionCommands.includes(type)) {
        const session_id = payload ? payload.session_id : null;
        if (!ws.session_id || ws.session_id !== session_id) {
            debug(`Access denied for ${ws.player_id || 'unknown'} for command ${type} on session ${session_id}`);
            return sendError(ws, 'UNAUTHORIZED', 'You must join the session before performing this action.');
        }
    }

    switch (type) {
        case 'JOIN_SESSION':
            handleJoinSession(ws, payload);
            break;
        case 'CREATE_SESSION':
            handleCreateSession(ws, payload);
            break;
        case 'PUBLISH_KEY':
            handlePublishKey(ws, payload);
            break;
        case 'SEND_MSG':
            handleSendMessage(ws, payload);
            break;
        case 'SEND_COMMAND':
            handleSendCommand(ws, payload);
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
        case 'KICK':
            handleKick(ws, payload);
            break;
        case 'RENAME_SESSION':
            handleRenameSession(ws, payload);
            break;
        case 'TRANSFER_HOST':
            handleTransferHost(ws, payload);
            break;
        case 'LIST_SESSIONS':
        case 'GET_SESSION_LIST':
            handleListSessions(ws);
            break;
        case 'CLEAR_ALL_SESSIONS':
            handleClearAllRooms(ws, payload);
            break;
        default:
            sendError(ws, 'UNKNOWN_COMMAND', `Command ${type} not recognized`);
    }
}

function handleJoinSession(ws, payload) {
    const { session_id, player_id, player_nickname, password_hash } = payload;
    if (!session_id || !player_id) return;

    // VÉRIFICATION: Limite de sessions en mémoire
    if (!rooms.has(session_id) && rooms.size >= MAX_SESSIONS) {
        return sendError(ws, 'MAX_SESSIONS_REACHED',
            `Server has reached maximum capacity (${MAX_SESSIONS} active sessions). Please try again later.`);
    }

    const session = db.getSession(session_id);

    if (!session) {
        debug(`Join denied for ${player_id}: session ${session_id} does not exist.`);
        return sendError(ws, 'SESSION_NOT_FOUND', 'Cette session n\'existe pas. Veuillez d\'abord la créer.');
    }

    // VÉRIFICATION: Mot de passe
    if (session.password_hash && session.password_hash !== password_hash) {
        debug(`Join denied for ${player_id} in session ${session_id}: Invalid password proof`);
        return sendError(ws, 'INVALID_PASSWORD', 'The password for this session is incorrect.');
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

    // Si la session n'a pas d'hôte explicite (session_id fraîchement créée,
    // ou legacy pré-migration schéma), on désigne le premier participant
    // comme hôte. Les appels TRANSFER_HOST ultérieurs peuvent écraser.
    if (!session.host_player_id) {
        db.setHost(session_id, player_id);
        debug(`Session ${session_id}: host initialisé sur ${player_id} (premier join)`);
    }

    let keys = [];
    let history = [];

    if (isKnownParticipant) {
        // Send current key if available
        const sessionKeys = db.getSessionKeys(session_id);
        if (sessionKeys && sessionKeys.length > 0) {
            keys = sessionKeys.filter(k => k.key_package !== null);
        }
        // Send history (enc)
        history = db.getHistory(session_id) || [];
    }

    ws.send(JSON.stringify({
        type: 'INIT_SESSION',
        payload: {
            current_version: session.version,
            keys,
            history,
            new_joiner: isNewParticipant
        }
    }));

    if (isNewParticipant) {
        keyRotationRequired.add(session_id);
        const newParticipantMsg = JSON.stringify({
            type: 'NEW_PARTICIPANT',
            payload: { session_id, player_id, player_nickname }
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

function handleCreateSession(ws, payload) {
    const { session_id, session_name, password_hash, max_players, is_public } = payload;

    if (!session_id) {
        return sendError(ws, 'MISSING_PARAMETER', 'session_id is required');
    }

    if (!password_hash) {
        return sendError(ws, 'MISSING_PARAMETER', 'password_hash is required');
    }

    // Vérifier si la session existe déjà
    const existingSession = db.getSession(session_id);
    if (existingSession) {
        return sendError(ws, 'SESSION_EXISTS', 'A session with this ID already exists');
    }

    // VÉRIFICATION: Limite de sessions (compter toutes les sessions DB)
    const allSessions = db.getAllSessions ? db.getAllSessions() : [];
    if (allSessions.length >= MAX_SESSIONS) {
        return sendError(ws, 'MAX_SESSIONS_REACHED',
            `Server has reached maximum capacity (${MAX_SESSIONS} sessions). Please try again later.`);
    }

    // Créer la session dans la DB (sans participants pour l'instant).
    // host_player_id reste null ici : il sera désigné au premier JOIN_SESSION
    // (typiquement le créateur qui enchaîne create→join). TRANSFER_HOST peut
    // ensuite l'écraser lors d'une migration P2P.
    debug(`Creating new session: ${session_id} (name: ${session_name || 'N/A'})`);

    db.createSession(session_id, session_name || '', password_hash, null, null, max_players || 4, is_public !== false ? 1 : 0, null);

    // Répondre au client
    ws.send(JSON.stringify({
        type: 'SESSION_CREATED',
        payload: {
            session_id: session_id,
            session_name: session_name || session_id,
            max_players: max_players || 4,
            is_public: is_public !== false,
            created_at: new Date().toISOString()
        }
    }));

    debug(`Session ${session_id} created successfully`);

    // Broadcast aux autres clients connectés (pour mettre à jour leur liste)
    const broadcastMsg = JSON.stringify({
        type: 'SESSION_CREATED_BROADCAST',
        payload: {
            session_id: session_id,
            session_name: session_name || session_id
        }
    });

    wss.clients.forEach(client => {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
            client.send(broadcastMsg);
        }
    });
}

function handlePublishKey(ws, payload) {
    const { session_id, blob, nonce } = payload;
    if (!session_id || !blob || !nonce) return;

    const result = db.updateSession(session_id, blob, nonce);
    if (result.changes === 0) {
        // La session DOIT exister (créée par CREATE_SESSION). On refuse plutôt que
        // d'invoquer createSession() avec des paramètres mal alignés.
        return sendError(ws, 'SESSION_NOT_FOUND', 'Cannot publish key: session does not exist');
    }
    const version = result.version;
    debug(`Key package updated/rotated for session ${session_id} (Version ${version})`);

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
    const { session_id, sender_nickname, payload: ciphertext, nonce, key_v, recipient_id } = payload;
    if (!session_id || !ciphertext || !nonce) return;

    // SECURITY: ne JAMAIS faire confiance à payload.sender_id (spoofable).
    // L'identité d'expéditeur est celle attachée à la socket par JOIN_SESSION.
    const sender_id = ws.player_id;
    if (!sender_id) {
        return sendError(ws, 'UNAUTHORIZED', 'You must join a session before sending messages');
    }

    if (keyRotationRequired.has(session_id)) {
        return sendError(ws, 'KEY_ROTATION_REQUIRED', 'A new participant joined; a client must publish a new key before sending messages');
    }

    const nickname = sender_nickname || (ws.player_nickname || '');
    const room = rooms.get(session_id);
    if (!room) return;

    const isPrivate = !!recipient_id;
    const timestamp = new Date().toISOString();

    // Les messages privés (unicast) ne sont PAS persistés et NE sont PAS broadcastés.
    let msgId = null;
    if (!isPrivate) {
        const result = db.saveMessage(session_id, sender_id, nickname, ciphertext, nonce, key_v);
        msgId = result.lastInsertRowid;
    }

    const outboundMessage = {
        type: 'NEW_MESSAGE',
        payload: {
            msg_id: msgId,
            sender_id,
            sender_nickname: nickname,
            payload: ciphertext,
            nonce,
            key_version: key_v,
            timestamp,
            ephemeral: isPrivate,
            ...(isPrivate ? { recipient_id } : {})
        }
    };
    const raw = JSON.stringify(outboundMessage);

    if (isPrivate) {
        // Unicast: n'envoyer qu'au destinataire (l'expéditeur a déjà l'affichage optimiste).
        let delivered = false;
        for (const client of room) {
            if (client.player_id === recipient_id && client.readyState === WebSocket.OPEN) {
                client.send(raw);
                delivered = true;
                break;
            }
        }
        if (!delivered) {
            debug(`Private message recipient ${recipient_id} not online in session ${session_id}`);
        }
    } else {
        // Broadcast à tous (y compris l'expéditeur, qui filtrera côté client).
        room.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(raw);
            }
        });
    }
}

function handleSendCommand(ws, payload) {
    const { session_id, recipient_id, payload: ciphertext, nonce, key_v } = payload;
    if (!session_id || !ciphertext || !nonce) return;

    // Optional: Check key rotation if strict security is desired for commands too
    if (keyRotationRequired.has(session_id)) {
        return sendError(ws, 'KEY_ROTATION_REQUIRED', 'A new participant joined; a client must publish a new key before sending commands');
    }

    const commandMessage = {
        type: 'NEW_COMMAND',
        payload: {
            sender_id: ws.player_id,
            payload: ciphertext,
            nonce,
            key_version: key_v,
            timestamp: new Date().toISOString()
        }
    };

    const room = rooms.get(session_id);
    if (!room) return;

    if (recipient_id) {
        // Unicast: Find specific client
        let found = false;
        for (const client of room) {
            if (client.player_id === recipient_id && client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify(commandMessage));
                found = true;
                break;
            }
        }
        if (!found) {
            // Optional: Notify sender that recipient was not found
            debug(`Command recipient ${recipient_id} not found in session ${session_id}`);
        }
    } else {
        // Broadcast: Send to all EXCEPT sender
        const rawCommand = JSON.stringify(commandMessage);
        room.forEach(client => {
            if (client !== ws && client.readyState === WebSocket.OPEN) {
                client.send(rawCommand);
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

    // SECURITY: seul le host peut effacer l'historique de la session
    if (!db.isHost(session_id, ws.player_id)) {
        return sendError(ws, 'FORBIDDEN', 'Only the host can clear the session history');
    }

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

function handleClearAllRooms(ws, payload) {
    // SECURITY: si ADMIN_TOKEN est défini côté serveur, on l'exige.
    // S'il n'est PAS défini, la commande est désactivée par défaut (fail-closed).
    const providedToken = (payload && typeof payload.admin_token === 'string') ? payload.admin_token : '';
    if (!ADMIN_TOKEN) {
        return sendError(ws, 'FORBIDDEN', 'CLEAR_ALL_SESSIONS is disabled (no ADMIN_TOKEN configured)');
    }
    if (providedToken !== ADMIN_TOKEN) {
        return sendError(ws, 'FORBIDDEN', 'Invalid admin token');
    }
    debug('CLEANING ALL ROOMS AND SESSIONS...');

    // Delete from DB
    db.clearAllData();

    // Notify ALL connected clients
    const clearMsg = JSON.stringify({
        type: 'SERVER_RESET',
        payload: { message: 'All sessions and history have been cleared by an administrator.' }
    });

    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(clearMsg);
        }
        // Reset client session state
        client.session_id = null;
        client.player_id = null;
    });

    // Clear in-memory state
    rooms.clear();
    keyRotationRequired.clear();

    debug('ALL ROOMS AND SESSIONS CLEARED.');
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

    const activeSessions = getDetailedSessionList();

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

/**
 * Récupère la liste détaillée de TOUTES les sessions (DB + mémoire)
 * @returns {Array} Liste des objets session
 */
function getDetailedSessionList() {
    const activeSessions = [];
    const processedSessions = new Set();

    // 1. Récupérer toutes les sessions de la DB (même sans clients connectés)
    const allDbSessions = db.getAllSessions ? db.getAllSessions() : [];

    debug(`Found ${allDbSessions.length} sessions in database`);

    for (const session of allDbSessions) {
        const sessionId = session.session_id;
        const participants = db.getParticipants(sessionId);

        // Lister toutes les sessions, même sans participants
        processedSessions.add(sessionId);

        // Déterminer qui est en ligne (si la room existe en mémoire)
        const room = rooms.get(sessionId);
        const onlinePlayerIds = new Set();

        if (room) {
            for (const client of room) {
                if (client.player_id && client.readyState === WebSocket.OPEN) {
                    onlinePlayerIds.add(client.player_id);
                }
            }
        }

        // Host explicite si présent (post-TRANSFER_HOST), sinon fallback sur
        // le premier participant (legacy pré-migration de schéma).
        const explicitHost = session.host_player_id
            ? participants.find(p => p.player_id === session.host_player_id)
            : null;
        const hostEntry = explicitHost || (participants.length > 0 ? participants[0] : null);

        // Construire l'objet session
        const sessionData = {
            session_id: sessionId,
            session_name: session.session_name || sessionId,
            host_id: hostEntry ? hostEntry.player_id : null,
            host_nickname: hostEntry ? (hostEntry.nickname || hostEntry.player_id) : 'En attente',
            player_count: participants.length,
            max_players: session.max_players || 4,
            created_at: session.created_at,
            online_count: onlinePlayerIds.size,
            is_public: session.is_public !== 0,
            status: participants.length === 0 ? 'waiting' :
                participants.length >= (session.max_players || 4) ? 'full' : 'available'
        };

        activeSessions.push(sessionData);
    }

    // 2. Ajouter les sessions en mémoire qui ne sont pas encore en DB (cas rare)
    for (const [sessionId, clients] of rooms.entries()) {
        if (!processedSessions.has(sessionId)) {
            const participants = db.getParticipants(sessionId);
            const session = db.getSession(sessionId);

            const onlinePlayerIds = new Set();
            for (const client of clients) {
                if (client.player_id && client.readyState === WebSocket.OPEN) {
                    onlinePlayerIds.add(client.player_id);
                }
            }

            const host = participants[0] || null;
            activeSessions.push({
                session_id: sessionId,
                session_name: session ? session.session_name || '' : '',
                host_id: host ? host.player_id : null,
                host_nickname: host ? (host.nickname || host.player_id) : 'En attente',
                player_count: participants.length,
                max_players: (session && session.max_players) || 4,
                created_at: session ? session.created_at : new Date().toISOString(),
                online_count: onlinePlayerIds.size,
                status: participants.length === 0 ? 'waiting' :
                    participants.length >= ((session && session.max_players) || 4) ? 'full' : 'available'
            });
        }
    }

    // Trier par date de création (plus récentes en premier)
    activeSessions.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

    debug(`Returning ${activeSessions.length} sessions to client`);
    return activeSessions;
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

    // SECURITY: seul le host peut supprimer une session
    if (!db.isHost(session_id, ws.player_id)) {
        return sendError(ws, 'FORBIDDEN', 'Only the host can delete the session');
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

function handleKick(ws, payload) {
    const { session_id, target_player_id } = payload;
    if (!session_id || !target_player_id) return;

    const participants = db.getParticipants(session_id);
    if (!participants || participants.length === 0) return;

    // The host is the first participant in the database
    const hostId = participants[0].player_id;
    debug(`Host ID: ${hostId}`);
    debug(`Player ID: ${ws.player_id}`);
    debug(`Target player ID: ${target_player_id}`);

    if (ws.player_id !== hostId) {
        return sendError(ws, 'FORBIDDEN', 'Only the host can kick participants');
    }

    if (target_player_id === hostId) {
        return sendError(ws, 'INVALID_OPERATION', 'Host cannot kick themselves');
    }

    // Remove from DB
    db.removeParticipant(session_id, target_player_id);

    // Notify and disconnect target
    const room = rooms.get(session_id);
    if (room) {
        const kickedMsg = JSON.stringify({
            type: 'KICKED',
            payload: { session_id, reason: 'Kicked by host' }
        });

        const broadcastMsg = JSON.stringify({
            type: 'PARTICIPANT_KICKED',
            payload: { session_id, player_id: target_player_id }
        });

        for (const client of room) {
            if (client.player_id === target_player_id) {
                if (client.readyState === WebSocket.OPEN) {
                    client.send(kickedMsg);
                }
                room.delete(client);
                client.session_id = null;
                // We keep connection open, but they are out of the room
                debug(`Participant ${target_player_id} was kicked from session ${session_id}`);
            } else if (client.readyState === WebSocket.OPEN) {
                client.send(broadcastMsg);
            }
        }
    }

    // Trigger key rotation requirement
    keyRotationRequired.add(session_id);

    debug(`Host ${hostId} kicked ${target_player_id} from session ${session_id}`);
}

// Phase 8 — host migration : rename une session existante (même session_id).
// Utilisé quand un client élu se promeut hôte et réécrit le prefix
// `[EDIT:<hostId>]` dans le nom affiché au lobby. Tous les clients reçoivent
// un broadcast SESSION_RENAMED pour mettre à jour leur availableSessions.
function handleRenameSession(ws, payload) {
    const { session_id, session_name } = payload;
    if (!session_id) return sendError(ws, 'MISSING_PARAMETER', 'session_id is required');
    if (typeof session_name !== 'string') return sendError(ws, 'MISSING_PARAMETER', 'session_name required');

    const existing = db.getSession(session_id);
    if (!existing) return sendError(ws, 'SESSION_NOT_FOUND', 'Session not found');

    const result = db.renameSession(session_id, session_name);
    if (!result || result.changes === 0) {
        return sendError(ws, 'RENAME_FAILED', 'Unable to rename session');
    }

    debug(`Session ${session_id} renamed to "${session_name}" by ${ws.player_id || 'unknown'}`);

    const broadcastMsg = JSON.stringify({
        type: 'SESSION_RENAMED',
        payload: { session_id, session_name }
    });
    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) client.send(broadcastMsg);
    });
}

// Migration P2P : transfert d'hôte. Appelé par le client élu (ou par l'ancien
// hôte avant qu'il parte) pour mettre à jour l'ownership serveur. Sans ça,
// `isHost` continuerait à renvoyer l'ancien hôte via son joined_at initial,
// et son retour éventuel lui rendrait les droits admin (DELETE_SESSION,
// CLEAR_HISTORY…) sur la session qu'il a pourtant quittée.
//
// Autorisation : l'hôte courant OU le nouvel hôte désigné (self). Le cas "new
// host désigne self" est nécessaire car après l'élection, l'ancien hôte n'est
// souvent plus connecté.
function handleTransferHost(ws, payload) {
    const { session_id, new_host_id } = payload;
    if (!session_id) return sendError(ws, 'MISSING_PARAMETER', 'session_id is required');
    if (!new_host_id) return sendError(ws, 'MISSING_PARAMETER', 'new_host_id is required');

    const existing = db.getSession(session_id);
    if (!existing) return sendError(ws, 'SESSION_NOT_FOUND', 'Session not found');

    const callerId = ws.player_id;
    const isCurrentHost = callerId && db.isHost(session_id, callerId);
    const isSelfPromotion = callerId && callerId === new_host_id;
    if (!isCurrentHost && !isSelfPromotion) {
        return sendError(ws, 'FORBIDDEN', 'Only current host or the new host (self) can transfer host');
    }

    // Vérifier que le nouvel hôte est participant actuel de la session.
    if (!db.isParticipant(session_id, new_host_id)) {
        return sendError(ws, 'NOT_PARTICIPANT', 'new_host_id is not a participant of this session');
    }

    const result = db.setHost(session_id, new_host_id);
    if (!result || result.changes === 0) {
        return sendError(ws, 'TRANSFER_FAILED', 'Unable to transfer host');
    }

    debug(`Session ${session_id} host transferred to ${new_host_id} by ${callerId || 'unknown'}`);

    // Broadcast aux membres de la session (et au lobby pour rafraîchir les
    // listes si l'UI expose l'hôte). On broadcast global comme rename.
    const broadcastMsg = JSON.stringify({
        type: 'HOST_CHANGED',
        payload: { session_id, host_player_id: new_host_id }
    });
    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) client.send(broadcastMsg);
    });
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
            keyRotationRequired.delete(sessionId);
            // Phase 8 : si plus personne n'est connecté, on purge la session
            // en DB (participants + messages + session). Laisse ainsi le lobby
            // propre et évite l'accumulation après toutes les déconnexions.
            // Note : si un joueur revient ensuite avec le même session_id, il
            // créera une nouvelle session (ou recevra SESSION_NOT_FOUND).
            try {
                db.deleteSession(sessionId);
                debug(`Session ${sessionId} empty — purged from DB`);
                // Broadcast à tous les clients restants pour rafraîchir leur
                // liste (la session disparaît du lobby).
                const msg = JSON.stringify({
                    type: 'SESSION_DELETED',
                    payload: { session_id: sessionId }
                });
                wss.clients.forEach(client => {
                    if (client.readyState === WebSocket.OPEN) client.send(msg);
                });
            } catch (err) {
                console.error(`[Cleanup] Failed to purge empty session ${sessionId}:`, err);
            }
        } else if (playerId) {
            // Phase 8 : retirer le participant de la DB quand il se déconnecte
            // (avant: on laissait tout en DB). Évite d'avoir des fantômes dans
            // `participants` qui comptent pour le quota `max_players`.
            try {
                if (db.removeParticipant) db.removeParticipant(sessionId, playerId);
            } catch (_) { /* ignore */ }
            // Notification aux autres membres.
            const msg = JSON.stringify({
                type: 'PARTICIPANT_LEFT',
                payload: { session_id: sessionId, player_id: playerId }
            });
            room.forEach(client => {
                if (client.readyState === WebSocket.OPEN) client.send(msg);
            });
            debug(`Participant ${playerId} disconnected from session ${sessionId}`);
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

    // Start STUN server
    try {
        stun.startStunServer(STUN_PORT);
    } catch (err) {
        console.error('Failed to start STUN server:', err);
    }
});