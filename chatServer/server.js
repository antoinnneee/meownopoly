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
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || ''; // Si défini, requis pour les commandes admin (CLEAR_ALL_SESSIONS) et /api/stats
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
// Rate-limit par IP (token bucket). Défauts : 60 tokens, refill 10/s.
const RATE_LIMIT_BUCKET = parseInt(process.env.RATE_LIMIT_BUCKET) || 60;
const RATE_LIMIT_REFILL = parseFloat(process.env.RATE_LIMIT_REFILL) || 10;
const HEARTBEAT_INTERVAL_MS = parseInt(process.env.HEARTBEAT_INTERVAL_MS) || 30000;

// Limites de taille / format pour l'input utilisateur.
const MAX_ID_LEN = 64;
const MAX_NAME_LEN = 128;
const MAX_NICKNAME_LEN = 64;
const MAX_MAX_PLAYERS = 16;
const ID_REGEX = /^[A-Za-z0-9_.:\-]{1,64}$/; // UUIDs, timestamps, ids composites OK
// SHA-256 = 32 octets. Le client C++ envoie le hash en base64 (44 chars, 1 `=`)
// via `ChatCrypto::derivePasswordProof().toBase64()`. On accepte aussi la
// forme hex canonique (64 chars) pour la compat dashboard / futurs clients.
const HASH_HEX_REGEX = /^[0-9a-fA-F]{64}$/;
const HASH_B64_REGEX = /^[A-Za-z0-9+/]{43}=$/;

function isNonEmptyString(v, maxLen) {
    return typeof v === 'string' && v.length > 0 && v.length <= maxLen;
}
function isValidId(v) {
    return typeof v === 'string' && ID_REGEX.test(v);
}
function isValidHash(v) {
    if (typeof v !== 'string') return false;
    return HASH_HEX_REGEX.test(v) || HASH_B64_REGEX.test(v);
}
function isValidMaxPlayers(v) {
    return Number.isInteger(v) && v >= 1 && v <= MAX_MAX_PLAYERS;
}

function debug(...args) {
    if (DEBUG_MODE) {
        const timestamp = new Date().toISOString();
        console.log(`[DEBUG] ${timestamp}:`, ...args);
    }
}

debug('Server starting in DEBUG mode...');

// ─────────────────────────────────────────────────────────────────────────
// HTTP server — static dashboard + REST admin API (dev-only).
// Toutes les routes `/api/*` sont gatées par `ADMIN_TOKEN` si défini ; sinon
// ouvertes (dev local). Le dashboard n'est jamais destiné à la prod.
// ─────────────────────────────────────────────────────────────────────────

function sendJson(res, status, body) {
    res.writeHead(status, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify(body));
}

function requireAdmin(req, res) {
    if (!ADMIN_TOKEN) return true; // mode dev : pas de token requis
    const auth = req.headers['authorization'] || '';
    if (auth !== `Bearer ${ADMIN_TOKEN}`) {
        sendJson(res, 401, { error: 'unauthorized', hint: 'set Authorization: Bearer <token>' });
        return false;
    }
    return true;
}

function readJsonBody(req) {
    return new Promise((resolve, reject) => {
        let raw = '';
        req.on('data', chunk => { raw += chunk; if (raw.length > 1024 * 1024) { req.destroy(); reject(new Error('body too large')); } });
        req.on('end', () => {
            if (!raw) return resolve({});
            try { resolve(JSON.parse(raw)); } catch (e) { reject(e); }
        });
        req.on('error', reject);
    });
}

function disconnectSessionClients(sessionId, reason) {
    const room = rooms.get(sessionId);
    if (!room) return 0;
    let n = 0;
    const msg = JSON.stringify({ type: 'SESSION_ENDED', payload: { session_id: sessionId, reason } });
    for (const client of room) {
        if (client.readyState === WebSocket.OPEN) { try { client.send(msg); } catch (_) {} }
        client.session_id = null;
        client.player_id = null;
        n++;
    }
    rooms.delete(sessionId);
    keyRotationRequired.delete(sessionId);
    return n;
}

function broadcastSessionDeleted(sessionId) {
    const msg = JSON.stringify({ type: 'SESSION_DELETED', payload: { session_id: sessionId } });
    wss.clients.forEach(c => { if (c.readyState === WebSocket.OPEN) { try { c.send(msg); } catch (_) {} } });
}

async function handleApi(req, res, pathname) {
    if (!requireAdmin(req, res)) return;

    // GET /api/stats — stats globales + sessions détaillées (même shape que
    // /api/sessions pour éviter les appels redondants côté dashboard).
    if (pathname === '/api/stats' && req.method === 'GET') {
        const sessions = getDetailedSessionList().map(s => ({
            ...s,
            message_count: getSessionMessageCount(s.session_id)
        }));
        return sendJson(res, 200, {
            connections: wss.clients.size,
            rooms: rooms.size,
            messages: getTotalMessages(),
            sessions,
            uptime: process.uptime(),
            memory: process.memoryUsage(),
            dbSize: db.getDbSize(),
            adminTokenRequired: !!ADMIN_TOKEN,
            maxSessions: MAX_SESSIONS,
            rateLimit: { bucket: RATE_LIMIT_BUCKET, refill: RATE_LIMIT_REFILL }
        });
    }

    // GET /api/sessions — même shape, endpoint séparé pour clarté.
    if (pathname === '/api/sessions' && req.method === 'GET') {
        const list = getDetailedSessionList().map(s => ({
            ...s,
            message_count: getSessionMessageCount(s.session_id)
        }));
        return sendJson(res, 200, { sessions: list, total: list.length });
    }

    // Routes paramétrées /api/sessions/:id[/messages]
    const sessionMatch = pathname.match(/^\/api\/sessions\/([^/]+)(\/messages)?$/);
    if (sessionMatch) {
        const sessionId = decodeURIComponent(sessionMatch[1]);
        const isMessages = !!sessionMatch[2];
        const existing = db.getSession(sessionId);
        if (!existing) return sendJson(res, 404, { error: 'session not found', session_id: sessionId });

        if (!isMessages && req.method === 'GET') {
            const participants = db.getParticipants(sessionId);
            const room = rooms.get(sessionId);
            const online = new Set();
            if (room) for (const c of room) if (c.player_id && c.readyState === WebSocket.OPEN) online.add(c.player_id);
            return sendJson(res, 200, {
                session: {
                    id: sessionId,
                    name: existing.session_name,
                    host_player_id: existing.host_player_id,
                    version: existing.version,
                    max_players: existing.max_players,
                    is_public: existing.is_public !== 0,
                    created_at: existing.created_at,
                    message_count: getSessionMessageCount(sessionId),
                    key_rotation_required: keyRotationRequired.has(sessionId)
                },
                participants: participants.map(p => ({
                    player_id: p.player_id,
                    nickname: p.nickname,
                    online: online.has(p.player_id)
                }))
            });
        }

        if (!isMessages && req.method === 'DELETE') {
            const disconnected = disconnectSessionClients(sessionId, 'Session deleted by admin');
            try { db.deleteSession(sessionId); } catch (e) { return sendJson(res, 500, { error: e.message }); }
            broadcastSessionDeleted(sessionId);
            return sendJson(res, 200, { ok: true, session_id: sessionId, disconnected });
        }

        if (isMessages && req.method === 'GET') {
            const urlObj = new URL(req.url, 'http://x');
            const limit = Math.min(parseInt(urlObj.searchParams.get('limit')) || 50, 500);
            // Métadonnées seulement — on n'envoie pas tout le ciphertext (peut être lourd).
            // Server-side on reste aveugle : on expose juste taille + timestamps.
            const rows = db.db.prepare(
                'SELECT id, sender_id, sender_nickname, key_version, server_timestamp, LENGTH(payload) AS payload_len FROM messages WHERE session_id = ? ORDER BY id DESC LIMIT ?'
            ).all(sessionId, limit);
            return sendJson(res, 200, { messages: rows.reverse(), limit });
        }

        if (isMessages && req.method === 'DELETE') {
            try { db.clearMessages(sessionId); } catch (e) { return sendJson(res, 500, { error: e.message }); }
            const room = rooms.get(sessionId);
            if (room) {
                const msg = JSON.stringify({ type: 'HISTORY_CLEARED', payload: { session_id: sessionId } });
                room.forEach(c => { if (c.readyState === WebSocket.OPEN) { try { c.send(msg); } catch (_) {} } });
            }
            return sendJson(res, 200, { ok: true, session_id: sessionId });
        }
    }

    // Actions DB globales
    if (pathname === '/api/db/cleanup' && req.method === 'POST') {
        try { db.cleanupOldData(24); return sendJson(res, 200, { ok: true, action: 'cleanup', size: db.getDbSize() }); }
        catch (e) { return sendJson(res, 500, { error: e.message }); }
    }
    if (pathname === '/api/db/vacuum' && req.method === 'POST') {
        try { db.vacuum(); return sendJson(res, 200, { ok: true, action: 'vacuum', size: db.getDbSize() }); }
        catch (e) { return sendJson(res, 500, { error: e.message }); }
    }
    if (pathname === '/api/db' && req.method === 'DELETE') {
        // Reset total. Détruit tout comme CLEAR_ALL_SESSIONS mais via REST.
        // Équivaut à un wipe manuel de `chat.db`.
        try { db.clearAllData(); } catch (e) { return sendJson(res, 500, { error: e.message }); }
        const resetMsg = JSON.stringify({ type: 'SERVER_RESET', payload: { message: 'DB wiped by admin' } });
        wss.clients.forEach(c => {
            if (c.readyState === WebSocket.OPEN) { try { c.send(resetMsg); } catch (_) {} }
            c.session_id = null; c.player_id = null;
        });
        rooms.clear();
        keyRotationRequired.clear();
        return sendJson(res, 200, { ok: true, action: 'db-wipe' });
    }

    sendJson(res, 404, { error: 'not found', path: pathname, method: req.method });
}

const DASHBOARD_ALLOWED = new Set(['/dashboard.html', '/dashboard.css', '/dashboard.js', '/chat_crypto.js', '/labo.html']);
const MIME_TYPES = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json' };

function serveStatic(req, res) {
    const urlPath = req.url === '/' ? '/dashboard.html' : req.url.split('?')[0];
    if (!DASHBOARD_ALLOWED.has(urlPath)) {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        return res.end('<h1>Meownopoly Chat Server</h1><p><a href="/dashboard.html">Dashboard</a> · <a href="/labo.html">Labo</a></p>');
    }
    const filePath = path.join(__dirname, urlPath.substring(1));
    const contentType = MIME_TYPES[path.extname(filePath)] || 'text/plain';
    fs.readFile(filePath, (err, content) => {
        if (err) { res.writeHead(404, { 'Content-Type': 'text/plain' }); return res.end(`Not found: ${urlPath}`); }
        res.writeHead(200, { 'Content-Type': contentType, 'Cache-Control': 'no-cache' });
        res.end(content);
    });
}

const server = http.createServer((req, res) => {
    // CORS preflight for dev usage from other origins (dashboard served from file://, etc.)
    if (req.method === 'OPTIONS') {
        res.writeHead(204, {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        });
        return res.end();
    }

    const pathname = (req.url || '').split('?')[0];

    if (pathname.startsWith('/api/')) {
        if (!ENABLE_DASHBOARD) return sendJson(res, 404, { error: 'dashboard disabled' });
        handleApi(req, res, pathname).catch(err => {
            console.error('[API] Uncaught error:', err);
            sendJson(res, 500, { error: err.message || 'internal' });
        });
        return;
    }

    if (ENABLE_DASHBOARD) {
        return serveStatic(req, res);
    }
    res.writeHead(200);
    res.end('Blind Relay Chat Server is running.');
    return;
});

const wss = new WebSocket.Server({
    server,
    // Drop les frames oversized au parser avant allocation (protège contre
    // un client qui envoie 100 MB : le default de ws est 100 MiB).
    maxPayload: MAX_PAYLOAD_SIZE,
    // Origin check opt-in via ALLOWED_ORIGINS="https://a,https://b". Si vide,
    // on laisse tout passer (compat dev + clients C++ qui n'envoient pas
    // d'Origin). En prod, configurer pour mitiger les détournements CSWSH.
    verifyClient: ALLOWED_ORIGINS.length > 0
        ? (info) => {
            const origin = info.origin || info.req.headers['origin'] || '';
            if (!origin) return true; // clients natifs (C++) n'envoient pas Origin
            return ALLOWED_ORIGINS.includes(origin);
        }
        : undefined
});

// Room management: Map<SessionID, Set<Socket>>
const rooms = new Map();

// Sessions bloquées en attente d'une rotation de clé (nouveau participant)
const keyRotationRequired = new Set();

// Rate-limit par IP (token bucket). Map<ip, { tokens, last }>.
// La consommation se fait à la réception de chaque frame WebSocket.
const rateBuckets = new Map();

function getClientIp(req) {
    const xff = req.headers['x-forwarded-for'];
    if (xff) return String(xff).split(',')[0].trim();
    return (req.socket && req.socket.remoteAddress) || 'unknown';
}

function rateLimit(ip) {
    const now = Date.now();
    let bucket = rateBuckets.get(ip);
    if (!bucket) {
        bucket = { tokens: RATE_LIMIT_BUCKET, last: now };
        rateBuckets.set(ip, bucket);
    } else {
        const elapsed = (now - bucket.last) / 1000;
        bucket.tokens = Math.min(RATE_LIMIT_BUCKET, bucket.tokens + elapsed * RATE_LIMIT_REFILL);
        bucket.last = now;
    }
    if (bucket.tokens < 1) return false;
    bucket.tokens -= 1;
    return true;
}

// GC périodique des buckets inactifs pour éviter la fuite mémoire si des IPs
// se connectent ponctuellement puis disparaissent.
setInterval(() => {
    const now = Date.now();
    for (const [ip, bucket] of rateBuckets) {
        if (now - bucket.last > 5 * 60 * 1000 && bucket.tokens >= RATE_LIMIT_BUCKET) {
            rateBuckets.delete(ip);
        }
    }
}, 60 * 1000).unref();

wss.on('connection', (ws, req) => {
    ws.clientIp = getClientIp(req);
    ws.isAlive = true;
    debug(`New client connected from ${ws.clientIp}`);

    // Capture toute erreur socket pour éviter un uncaughtException (crash process)
    // sur un ws.send vers une socket fermée entre deux ticks.
    ws.on('error', (err) => {
        debug(`WS error from ${ws.clientIp}: ${err.message}`);
    });

    ws.on('pong', () => { ws.isAlive = true; });

    ws.on('message', (data) => {
        // Rate-limit : drop + error si le bucket est vide. Pas de disconnect
        // automatique — on laisse le client ralentir.
        if (!rateLimit(ws.clientIp)) {
            return sendError(ws, 'RATE_LIMITED', 'Too many requests, slow down');
        }

        debug(`Received raw data from ${ws.clientIp}: ${data.length} bytes`);
        // `maxPayload` a déjà rejeté les frames trop grosses, mais on garde
        // le check pour les clients qui ne respectent pas le close code 1009.
        if (data.length > MAX_PAYLOAD_SIZE) {
            return sendError(ws, 'PAYLOAD_TOO_LARGE', `Message exceeds ${MAX_PAYLOAD_SIZE / (1024 * 1024)}MB limit`);
        }

        let message;
        try {
            message = JSON.parse(data);
        } catch (err) {
            return sendError(ws, 'INVALID_FORMAT', 'Message must be valid JSON');
        }
        if (!message || typeof message !== 'object' || typeof message.type !== 'string') {
            return sendError(ws, 'INVALID_FORMAT', 'Message must have a string `type`');
        }

        try {
            debug(`Received command: ${message.type}`, message.payload);
            handleCommand(ws, message);
            checkDbSize();
        } catch (err) {
            console.error(`[ERR] while handling ${message.type} for ${ws.player_id || 'unknown'}:`, err);
            sendError(ws, 'INTERNAL_ERROR', 'Server error while processing command');
        }
    });

    ws.on('close', () => {
        debug(`Client disconnected: ${ws.clientIp}`);
        removeFromRooms(ws);
    });
});

// Heartbeat : détecte les sockets mortes (TCP bloqué, NAT timeout) que
// `ws` ne notifie pas spontanément. Sans ça, un participant "online" peut
// rester fantôme dans `rooms` pendant plusieurs heures.
const heartbeatInterval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
            debug(`Heartbeat: terminating dead socket ${ws.clientIp || '?'}`);
            return ws.terminate();
        }
        ws.isAlive = false;
        try { ws.ping(); } catch (_) { /* ignore */ }
    });
}, HEARTBEAT_INTERVAL_MS);
heartbeatInterval.unref();
wss.on('close', () => clearInterval(heartbeatInterval));

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
    if (!payload || typeof payload !== 'object') {
        return sendError(ws, 'MISSING_PARAMETER', 'payload is required');
    }
    const { session_id, player_id, player_nickname, password_hash } = payload;
    if (!isValidId(session_id)) {
        return sendError(ws, 'MISSING_PARAMETER', 'session_id invalid or missing');
    }
    if (!isValidId(player_id)) {
        return sendError(ws, 'MISSING_PARAMETER', 'player_id invalid or missing');
    }
    if (player_nickname != null && !isNonEmptyString(player_nickname, MAX_NICKNAME_LEN)) {
        return sendError(ws, 'MISSING_PARAMETER', `player_nickname must be a string ≤ ${MAX_NICKNAME_LEN} chars`);
    }
    if (password_hash != null && !isValidHash(password_hash)) {
        return sendError(ws, 'MISSING_PARAMETER', 'password_hash must be a SHA-256 (64-char hex or 44-char base64)');
    }

    // VÉRIFICATION: Limite de sessions (même métrique que CREATE_SESSION → DB).
    // `rooms.size` comptait les sessions en mémoire et divergeait : on pouvait
    // rejoindre une 11e session DB alors que CREATE en refusait une nouvelle.
    const allSessionsCount = db.getAllSessions ? db.getAllSessions().length : rooms.size;
    if (!rooms.has(session_id) && allSessionsCount >= MAX_SESSIONS) {
        return sendError(ws, 'MAX_SESSIONS_REACHED',
            `Server has reached maximum capacity (${MAX_SESSIONS} sessions). Please try again later.`);
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

    // VÉRIFICATION: Aucune autre socket OPEN ne revendique déjà ce player_id
    // dans la session. Mitige (sans authentifier) l'usurpation : un second
    // client qui tenterait de se faire passer pour un membre actif est refusé.
    // Un client qui rejoint après un disconnect propre passe car l'ancienne
    // socket n'est plus dans `rooms`.
    const existingRoom = rooms.get(session_id);
    if (existingRoom) {
        for (const client of existingRoom) {
            if (client !== ws && client.player_id === player_id && client.readyState === WebSocket.OPEN) {
                return sendError(ws, 'PLAYER_ID_IN_USE',
                    'Another active connection already claims this player_id in this session');
            }
        }
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
    if (!payload || typeof payload !== 'object') {
        return sendError(ws, 'MISSING_PARAMETER', 'payload is required');
    }
    const { session_id, session_name, password_hash, max_players, is_public } = payload;

    if (!isValidId(session_id)) {
        return sendError(ws, 'MISSING_PARAMETER', 'session_id invalid or missing');
    }
    if (!isValidHash(password_hash)) {
        return sendError(ws, 'MISSING_PARAMETER', 'password_hash must be a SHA-256 (64-char hex or 44-char base64)');
    }
    if (session_name != null && (typeof session_name !== 'string' || session_name.length > MAX_NAME_LEN)) {
        return sendError(ws, 'MISSING_PARAMETER', `session_name must be a string ≤ ${MAX_NAME_LEN} chars`);
    }
    if (max_players != null && !isValidMaxPlayers(max_players)) {
        return sendError(ws, 'MISSING_PARAMETER', `max_players must be an integer in [1, ${MAX_MAX_PLAYERS}]`);
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
    const { session_id, payload: ciphertext, nonce, key_v, recipient_id } = payload;
    if (!session_id || !ciphertext || !nonce) {
        return sendError(ws, 'MISSING_PARAMETER', 'session_id, payload and nonce are required');
    }

    // SECURITY: ne JAMAIS faire confiance à payload.sender_id ni
    // payload.sender_nickname (tous deux spoofables). L'identité et le pseudo
    // d'expéditeur sont ceux attachés à la socket par JOIN_SESSION.
    const sender_id = ws.player_id;
    if (!sender_id) {
        return sendError(ws, 'UNAUTHORIZED', 'You must join a session before sending messages');
    }

    if (recipient_id != null && !isValidId(recipient_id)) {
        return sendError(ws, 'MISSING_PARAMETER', 'recipient_id must be a valid player id');
    }

    if (keyRotationRequired.has(session_id)) {
        return sendError(ws, 'KEY_ROTATION_REQUIRED', 'A new participant joined; a client must publish a new key before sending messages');
    }

    const nickname = ws.player_nickname || '';
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
    if (!session_id || !player_id) {
        return sendError(ws, 'MISSING_PARAMETER', 'session_id and player_id are required');
    }

    if (ws.player_id !== player_id) {
        return sendError(ws, 'FORBIDDEN', 'Cannot leave session for another player');
    }

    db.removeParticipant(session_id, player_id);
    // Si le partant était l'hôte désigné, on libère le champ. Sans ça, son
    // retour éventuel dans la session lui rendrait les droits admin
    // (CLEAR_HISTORY, DELETE_SESSION) via un `isHost` qui continuait à
    // matcher. L'élection Phase 8 côté client enverra TRANSFER_HOST.
    try { db.clearHostIfMatches(session_id, player_id); } catch (_) { /* ignore */ }

    // Remove socket from room AVANT le broadcast pour ne pas notifier le
    // partant de son propre départ (le client recevait un PARTICIPANT_LEFT
    // avec son propre player_id, générant du bruit UI).
    const room = rooms.get(session_id);
    if (room && room.has(ws)) {
        room.delete(ws);
    }

    if (room) {
        const leftMsg = JSON.stringify({
            type: 'PARTICIPANT_LEFT',
            payload: { session_id, player_id }
        });
        room.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(leftMsg);
            }
        });

        if (room.size === 0) {
            rooms.delete(session_id);
            keyRotationRequired.delete(session_id);
            // Cohérence avec `removeFromRooms` (disconnect brut) : on purge
            // la session DB quand elle devient vide. Sinon, un LEAVE propre
            // laissait la session orpheline en DB jusqu'au TTL 24 h, alors
            // qu'un disconnect la supprimait immédiatement.
            try {
                db.deleteSession(session_id);
                debug(`Session ${session_id} empty after LEAVE — purged from DB`);
                const delMsg = JSON.stringify({
                    type: 'SESSION_DELETED',
                    payload: { session_id }
                });
                wss.clients.forEach(client => {
                    if (client.readyState === WebSocket.OPEN) client.send(delMsg);
                });
            } catch (err) {
                console.error(`[Cleanup] Failed to purge empty session ${session_id}:`, err);
            }
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
    if (!session_id || !target_player_id) {
        return sendError(ws, 'MISSING_PARAMETER', 'session_id and target_player_id are required');
    }

    // Use db.isHost (qui lit sessions.host_player_id en priorité) pour
    // rester cohérent avec CLEAR_HISTORY / DELETE_SESSION. Avant, KICK
    // reposait sur participants[0] → le nouvel hôte post-TRANSFER_HOST
    // ne pouvait pas kick, et l'ancien hôte (si de retour) gardait le droit.
    if (!db.isHost(session_id, ws.player_id)) {
        return sendError(ws, 'FORBIDDEN', 'Only the host can kick participants');
    }

    if (target_player_id === ws.player_id) {
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

    // Note : on ne peut pas refuser l'auto-promotion "si l'ancien hôte est
    // encore connecté" côté serveur — la WS chat lobby peut rester ouverte
    // alors que le client a quitté l'éditeur P2P (timeout / HostLeaving).
    // L'élection Phase 8 est déterministe côté client (min lexico du roster),
    // tous les pairs convergent ; faire confiance au caller est le design
    // voulu. La limite de surface d'attaque reste : seuls les participants
    // de la session peuvent s'auto-promouvoir (check `isParticipant` ci-bas).

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
    // Protège contre un send vers une socket fermée entre deux ticks
    // (remonterait sinon en uncaughtException → crash process).
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    try {
        ws.send(JSON.stringify({
            type: 'ERROR',
            payload: { code, message }
        }));
    } catch (err) {
        debug(`sendError swallowed: ${err.message}`);
    }
}

function checkDbSize() {
    const size = db.getDbSize();
    if (size > MAX_DB_SIZE) {
        console.log(`[Database] Size limit reached (${(size / 1024 / 1024).toFixed(2)}MB > ${(MAX_DB_SIZE / 1024 / 1024).toFixed(2)}MB). Cleaning up...`);
        // Purge proportionnelle (cf. database.js). `50` fixé était insuffisant
        // sur spam : on restait en permanence au-dessus du seuil.
        db.deleteOldestMessages();
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
            // Libère host_player_id si le partant était l'hôte désigné.
            // Sans ça, `isHost` continuait à matcher son player_id et lui
            // redonnait les droits admin s'il revenait. L'élection Phase 8
            // côté client enverra TRANSFER_HOST pour le nouvel hôte.
            try { db.clearHostIfMatches(sessionId, playerId); } catch (_) { /* ignore */ }
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

function startupChecks() {
    const warnings = [];
    if (ENABLE_DASHBOARD && !ADMIN_TOKEN) {
        warnings.push('ENABLE_DASHBOARD=true sans ADMIN_TOKEN : /api/stats est public (info disclosure).');
    }
    if (!ADMIN_TOKEN) {
        warnings.push('ADMIN_TOKEN non défini : CLEAR_ALL_SESSIONS est désactivé (fail-closed).');
    }
    if (ALLOWED_ORIGINS.length === 0) {
        warnings.push('ALLOWED_ORIGINS vide : aucun check d\'origine WebSocket (OK pour clients C++ natifs).');
    }
    warnings.forEach(w => console.warn(`[Startup] ${w}`));
    console.log(`[Startup] Limits: MAX_SESSIONS=${MAX_SESSIONS}, MAX_PAYLOAD=${MAX_PAYLOAD_SIZE}B, MAX_DB=${MAX_DB_SIZE}B`);
    console.log(`[Startup] Rate-limit: bucket=${RATE_LIMIT_BUCKET}, refill=${RATE_LIMIT_REFILL}/s`);
    console.log(`[Startup] Heartbeat: interval=${HEARTBEAT_INTERVAL_MS}ms`);
}

server.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
    if (ENABLE_DASHBOARD) {
        console.log(`Dashboard disponible sur http://localhost:${PORT}/dashboard.html`);
        console.log(`Labo disponible sur http://localhost:${PORT}/labo.html`);
    }
    startupChecks();

    // Start STUN server
    try {
        stun.startStunServer(STUN_PORT);
    } catch (err) {
        console.error('Failed to start STUN server:', err);
    }
});