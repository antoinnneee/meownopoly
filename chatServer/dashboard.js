// Meownopoly Chat — dev dashboard
// REST client sur /api/*, pas de WebSocket.
// Token (si ADMIN_TOKEN défini côté serveur) stocké dans localStorage.

const STORAGE_TOKEN_KEY = 'meownopoly-dev-dashboard-token';
const POLL_INTERVAL_MS = 3000;

const state = {
    token: localStorage.getItem(STORAGE_TOKEN_KEY) || '',
    sessions: [],
    filter: '',
    pollTimer: null,
    adminRequired: null, // null unknown, true if server demands a token
};

// ────────── DOM helpers ──────────
const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);
function el(tag, attrs = {}, children = []) {
    const n = document.createElement(tag);
    for (const k in attrs) {
        if (k === 'class') n.className = attrs[k];
        else if (k === 'dataset') Object.assign(n.dataset, attrs[k]);
        else if (k.startsWith('on')) n.addEventListener(k.slice(2), attrs[k]);
        else if (attrs[k] !== undefined && attrs[k] !== null) n.setAttribute(k, attrs[k]);
    }
    (Array.isArray(children) ? children : [children]).forEach(c => {
        if (c == null) return;
        if (typeof c === 'string') n.appendChild(document.createTextNode(c));
        else n.appendChild(c);
    });
    return n;
}

// ────────── Log ──────────
function log(msg, kind = '') {
    const ts = new Date().toLocaleTimeString();
    const entry = el('span', { class: `log-entry ${kind}` }, [
        el('span', { class: 'ts' }, `[${ts}]`),
        msg,
    ]);
    const logEl = $('#log');
    logEl.appendChild(entry);
    logEl.appendChild(document.createTextNode('\n'));
    logEl.scrollTop = logEl.scrollHeight;
}

// ────────── API ──────────
async function api(path, opts = {}) {
    const headers = Object.assign(
        { 'Content-Type': 'application/json' },
        state.token ? { 'Authorization': `Bearer ${state.token}` } : {},
        opts.headers || {}
    );
    const res = await fetch(path, { ...opts, headers });
    const text = await res.text();
    let data;
    try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }
    if (!res.ok) {
        const msg = data.error || `HTTP ${res.status}`;
        throw new Error(msg);
    }
    return data;
}

// ────────── Stats + sessions polling ──────────
async function refresh() {
    try {
        const stats = await api('/api/stats');
        setServerStatus('online');
        state.adminRequired = !!stats.adminTokenRequired;
        updateTokenStatus();
        updateStats(stats);
        state.sessions = stats.sessions || [];
        renderSessions();
    } catch (err) {
        if (err.message === 'unauthorized') {
            setServerStatus('partial', 'unauthorized');
            state.adminRequired = true;
            updateTokenStatus('token required');
        } else {
            setServerStatus('offline', err.message);
        }
    }
}

function setServerStatus(kind, text) {
    const s = $('#serverStatus');
    s.className = `status ${kind}`;
    s.textContent = text || kind;
}

function updateStats(stats) {
    $('#statConnections').textContent = stats.connections;
    $('#statRooms').textContent = stats.rooms;
    $('#statSessionsDb').textContent = stats.sessions.length;
    $('#statMessages').textContent = stats.messages;
    $('#statDbSize').textContent = formatBytes(stats.dbSize);
    $('#statUptime').textContent = formatUptime(stats.uptime);
    $('#statMemory').textContent = formatBytes(stats.memory?.rss || 0);
    $('#statMaxSessions').textContent = stats.maxSessions;
}

function updateTokenStatus(msg) {
    const t = $('#tokenStatus');
    if (msg) t.textContent = msg;
    else if (state.adminRequired && !state.token) t.textContent = 'token required';
    else if (state.adminRequired) t.textContent = 'token active';
    else t.textContent = 'open mode (no ADMIN_TOKEN)';
}

function formatBytes(n) {
    if (n < 1024) return `${n} B`;
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
    if (n < 1024 * 1024 * 1024) return `${(n / 1024 / 1024).toFixed(1)} MB`;
    return `${(n / 1024 / 1024 / 1024).toFixed(2)} GB`;
}
function formatUptime(sec) {
    sec = Math.floor(sec || 0);
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}
function relTime(iso) {
    if (!iso) return '—';
    const d = new Date(iso);
    if (isNaN(d.getTime())) return iso;
    const diff = (Date.now() - d.getTime()) / 1000;
    if (diff < 60) return `${Math.floor(diff)}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
}

// ────────── Sessions table ──────────
function renderSessions() {
    const body = $('#sessionsBody');
    body.innerHTML = '';
    const filter = state.filter.toLowerCase();
    const filtered = state.sessions.filter(s =>
        !filter
        || (s.session_id || '').toLowerCase().includes(filter)
        || (s.session_name || '').toLowerCase().includes(filter)
    );
    $('#sessionsCount').textContent = `${filtered.length} / ${state.sessions.length}`;
    if (filtered.length === 0) {
        body.appendChild(el('tr', { class: 'empty' }, el('td', { colspan: '9' }, 'no session')));
        return;
    }
    for (const s of filtered) {
        body.appendChild(renderSessionRow(s));
    }
}

function renderSessionRow(s) {
    const sid = s.session_id;
    const online = s.online_count ?? 0;
    const onlineBadge = online > 0
        ? el('span', { class: 'badge online' }, String(online))
        : el('span', { class: 'badge offline' }, '0');
    const actions = el('td', { class: 'actions-cell' }, [
        el('button', { class: 'btn small', onclick: () => openSessionDetails(sid) }, 'inspect'),
        el('button', { class: 'btn small danger', onclick: () => deleteSession(sid) }, 'del'),
    ]);
    return el('tr', { dataset: { id: sid } }, [
        el('td', {}, ''),
        el('td', { class: 'col-id', onclick: () => openSessionDetails(sid), title: sid }, sid),
        el('td', { class: 'col-name', title: s.session_name || '' }, s.session_name || ''),
        el('td', {}, s.host_nickname || '—'),
        el('td', { class: 'num' }, `${s.player_count ?? 0}/${s.max_players ?? 0}`),
        el('td', { class: 'num' }, onlineBadge),
        el('td', { class: 'num' }, String(s.message_count ?? 0)),
        el('td', {}, relTime(s.created_at)),
        actions,
    ]);
}

// ────────── Session modal ──────────
async function openSessionDetails(sessionId) {
    try {
        const [info, messages] = await Promise.all([
            api(`/api/sessions/${encodeURIComponent(sessionId)}`),
            api(`/api/sessions/${encodeURIComponent(sessionId)}/messages?limit=20`),
        ]);
        renderSessionModal(info, messages);
    } catch (err) {
        log(`inspect ${sessionId} failed: ${err.message}`, 'err');
    }
}

function renderSessionModal(info, messages) {
    const s = info.session;
    const title = `Session ${s.id}`;
    const badges = [];
    if (s.key_rotation_required) badges.push(el('span', { class: 'badge rot' }, 'key rotation required'));
    if (s.is_public) badges.push(el('span', { class: 'badge' }, 'public')); else badges.push(el('span', { class: 'badge' }, 'private'));

    const kv = el('dl', { class: 'kv' }, [
        el('dt', {}, 'ID'), el('dd', {}, s.id),
        el('dt', {}, 'Name'), el('dd', {}, s.name || '—'),
        el('dt', {}, 'Host'), el('dd', {}, s.host_player_id || '— (fallback joined_at)'),
        el('dt', {}, 'Key version'), el('dd', {}, String(s.version)),
        el('dt', {}, 'Players'), el('dd', {}, `${info.participants.length}/${s.max_players}`),
        el('dt', {}, 'Messages'), el('dd', {}, String(s.message_count)),
        el('dt', {}, 'Created'), el('dd', {}, `${s.created_at} (${relTime(s.created_at)})`),
        el('dt', {}, 'Flags'), el('dd', {}, badges.length ? badges : el('span', {}, '—')),
    ]);

    const pTable = el('table', {}, [
        el('thead', {}, el('tr', {}, [
            el('th', {}, 'Player ID'), el('th', {}, 'Nickname'), el('th', {}, 'Status'), el('th', {}, ''),
        ])),
        el('tbody', {}, info.participants.map(p => el('tr', {}, [
            el('td', {}, p.player_id + (p.player_id === s.host_player_id ? ' 👑' : '')),
            el('td', {}, p.nickname || '—'),
            el('td', {}, p.online ? el('span', { class: 'badge online' }, 'online') : el('span', { class: 'badge offline' }, 'offline')),
            el('td', {}, ''),
        ]))),
    ]);

    const mTable = el('table', {}, [
        el('thead', {}, el('tr', {}, [
            el('th', {}, '#'), el('th', {}, 'Sender'), el('th', {}, 'Nick'), el('th', {}, 'KeyV'), el('th', {}, 'Size'), el('th', {}, 'Time'),
        ])),
        el('tbody', {}, messages.messages.length ? messages.messages.map(m => el('tr', {}, [
            el('td', {}, String(m.id)),
            el('td', {}, m.sender_id || '—'),
            el('td', {}, m.sender_nickname || '—'),
            el('td', {}, String(m.key_version ?? '—')),
            el('td', {}, `${m.payload_len} B`),
            el('td', {}, relTime(m.server_timestamp)),
        ])) : [el('tr', { class: 'empty' }, el('td', { colspan: '6' }, 'no messages'))]),
    ]);

    const actionsRow = el('div', { class: 'modal-actions' }, [
        el('button', { class: 'btn small', onclick: () => openSessionDetails(s.id) }, 'refresh'),
        el('button', { class: 'btn small danger', onclick: () => clearHistory(s.id) }, 'clear history'),
        el('button', { class: 'btn small danger', onclick: () => deleteSession(s.id, true) }, 'delete session'),
    ]);

    $('#modalTitle').textContent = title;
    const content = $('#modalContent');
    content.innerHTML = '';
    content.appendChild(el('h4', {}, 'Session'));
    content.appendChild(kv);
    content.appendChild(actionsRow);
    content.appendChild(el('h4', {}, `Participants (${info.participants.length})`));
    content.appendChild(pTable);
    content.appendChild(el('h4', {}, `Recent messages (${messages.messages.length}, ciphertext metadata only)`));
    content.appendChild(mTable);
    $('#modal').classList.remove('hidden');
}

function closeModal() { $('#modal').classList.add('hidden'); }

// ────────── Actions ──────────
async function deleteSession(sessionId, closeModalAfter = false) {
    if (!confirm(`Delete session ${sessionId} and all its data?`)) return;
    try {
        const r = await api(`/api/sessions/${encodeURIComponent(sessionId)}`, { method: 'DELETE' });
        log(`deleted ${sessionId} (disconnected ${r.disconnected} sockets)`, 'ok');
        if (closeModalAfter) closeModal();
        refresh();
    } catch (err) {
        log(`delete ${sessionId} failed: ${err.message}`, 'err');
    }
}

async function clearHistory(sessionId) {
    if (!confirm(`Clear all messages of session ${sessionId}?`)) return;
    try {
        await api(`/api/sessions/${encodeURIComponent(sessionId)}/messages`, { method: 'DELETE' });
        log(`history cleared: ${sessionId}`, 'ok');
        openSessionDetails(sessionId); // refresh modal
        refresh();
    } catch (err) {
        log(`clear history failed: ${err.message}`, 'err');
    }
}

async function wipeDb() {
    if (!confirm('WIPE entire DB? This deletes ALL sessions, participants, messages, and disconnects everyone.')) return;
    if (!confirm('Really? There is no undo.')) return;
    try {
        await api('/api/db', { method: 'DELETE' });
        log('DB wiped', 'ok');
        refresh();
    } catch (err) { log(`wipe failed: ${err.message}`, 'err'); }
}

async function runCleanup() {
    try {
        const r = await api('/api/db/cleanup', { method: 'POST' });
        log(`cleanup done (size: ${formatBytes(r.size)})`, 'ok');
        refresh();
    } catch (err) { log(`cleanup failed: ${err.message}`, 'err'); }
}

async function runVacuum() {
    try {
        const r = await api('/api/db/vacuum', { method: 'POST' });
        log(`vacuum done (size: ${formatBytes(r.size)})`, 'ok');
        refresh();
    } catch (err) { log(`vacuum failed: ${err.message}`, 'err'); }
}

// ────────── Bindings ──────────
function saveToken() {
    state.token = $('#tokenInput').value.trim();
    if (state.token) localStorage.setItem(STORAGE_TOKEN_KEY, state.token);
    else localStorage.removeItem(STORAGE_TOKEN_KEY);
    log('token saved', 'ok');
    refresh();
}

function init() {
    $('#tokenInput').value = state.token;
    $('#saveTokenBtn').addEventListener('click', saveToken);
    $('#tokenInput').addEventListener('keydown', e => { if (e.key === 'Enter') saveToken(); });
    $('#refreshBtn').addEventListener('click', refresh);
    $('#filterInput').addEventListener('input', e => { state.filter = e.target.value; renderSessions(); });
    $('#actCleanup').addEventListener('click', runCleanup);
    $('#actVacuum').addEventListener('click', runVacuum);
    $('#actWipeDb').addEventListener('click', wipeDb);
    $('#clearLogBtn').addEventListener('click', () => { $('#log').innerHTML = ''; });
    $('#modalClose').addEventListener('click', closeModal);
    $('#modal').addEventListener('click', e => { if (e.target.id === 'modal') closeModal(); });
    document.addEventListener('keydown', e => {
        if (e.key === 'Escape') closeModal();
        if (e.key === 'r' && !e.target.matches('input')) refresh();
    });

    refresh();
    state.pollTimer = setInterval(refresh, POLL_INTERVAL_MS);
    log('dashboard ready — polling every 3s');
}

document.addEventListener('DOMContentLoaded', init);
