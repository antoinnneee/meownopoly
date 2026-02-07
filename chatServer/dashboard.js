// Configuration - Détection automatique de l'URL WebSocket
const WS_URL = window.location.protocol === 'https:' 
    ? `wss://${window.location.host}` 
    : `ws://${window.location.host}`;

// État global
let ws = null;
let reconnectInterval = null;
let startTime = Date.now();
let stats = {
    connections: 0,
    rooms: 0,
    messages: 0
};

// Connexions et salons simulés (car le serveur n'expose pas ces données directement)
let activeConnections = new Map();
let activeRooms = new Map();

// État du mini chat client
let chatWs = null;
let currentSession = null;
let currentNickname = null;
let currentPlayerId = null;
let currentPassword = null;
let lockKey = null;
let sessionKeys = new Map(); // version -> decrypted session key
let currentKeyVersion = 0;
let chatMessages = [];

// Initialisation
document.addEventListener('DOMContentLoaded', () => {
    initWebSocket();
    updateUptime();
    setInterval(updateUptime, 1000);
    
    // Récupérer les stats du serveur toutes les 3 secondes
    fetchServerStats();
    setInterval(fetchServerStats, 3000);
    
    document.getElementById('clearLogsBtn').addEventListener('click', clearLogs);
    
    // Toggle du journal d'activité
    document.getElementById('activityLogHeader').addEventListener('click', toggleActivityLog);
    
    // Initialiser le mini chat client
    initChatClient();
});

// Récupérer les statistiques du serveur via API REST
async function fetchServerStats() {
    try {
        const protocol = window.location.protocol;
        const host = window.location.host;
        const response = await fetch(`${protocol}//${host}/api/stats`);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        // Mettre à jour les statistiques
        stats.connections = data.connections || 0;
        stats.rooms = data.rooms || 0;
        stats.messages = data.messages || 0;
        updateStats();
        
        // Mettre à jour les salons avec les données réelles
        if (data.sessions && data.sessions.length > 0) {
            activeRooms.clear();
            data.sessions.forEach(session => {
                if (session.id !== '__dashboard_monitor__') {
                    activeRooms.set(session.id, {
                        id: session.id,
                        participants: new Set(),
                        participantCount: session.participants,
                        messageCount: session.messages,
                        createdAt: new Date()
                    });
                }
            });
            renderRooms();
        } else if (data.rooms === 0) {
            activeRooms.clear();
            renderRooms();
        }
        
        // Uptime du serveur
        if (data.uptime) {
            startTime = Date.now() - (data.uptime * 1000);
        }
        
    } catch (err) {
        console.error('Erreur lors de la récupération des stats:', err);
    }
}

// WebSocket
function initWebSocket() {
    addLog('Tentative de connexion au serveur...', 'info');
    
    try {
        ws = new WebSocket(WS_URL);
        
        ws.onopen = () => {
            addLog('✓ Connecté au serveur WebSocket', 'success');
            updateServerStatus(true);
            if (reconnectInterval) {
                clearInterval(reconnectInterval);
                reconnectInterval = null;
            }
            
            // Joindre une session de monitoring fictive
            ws.send(JSON.stringify({
                type: 'JOIN_SESSION',
                payload: {
                    session_id: '__dashboard_monitor__',
                    player_id: 'dashboard',
                    player_nickname: 'Dashboard Monitor'
                }
            }));
        };
        
        ws.onmessage = (event) => {
            try {
                const message = JSON.parse(event.data);
                handleServerMessage(message);
            } catch (err) {
                console.error('Erreur de parsing du message:', err);
            }
        };
        
        ws.onerror = (error) => {
            addLog('✗ Erreur de connexion WebSocket', 'error');
            console.error('WebSocket error:', error);
        };
        
        ws.onclose = () => {
            addLog('✗ Déconnecté du serveur', 'warning');
            updateServerStatus(false);
            
            if (!reconnectInterval) {
                reconnectInterval = setInterval(() => {
                    addLog('Tentative de reconnexion...', 'info');
                    initWebSocket();
                }, 5000);
            }
        };
    } catch (err) {
        addLog(`✗ Impossible de se connecter: ${err.message}`, 'error');
        updateServerStatus(false);
    }
}

function handleServerMessage(message) {
    const { type, payload } = message;
    
    switch (type) {
        case 'INIT_SESSION':
            addLog(`Session initialisée (version: ${payload.current_version})`, 'info');
            break;
            
        case 'NEW_MESSAGE':
            addLog(`💬 Nouveau message de ${payload.sender_nickname || payload.sender_id}`, 'info');
            
            // Mettre à jour l'activité (les stats seront rechargées par l'API)
            break;
            
        case 'NEW_PARTICIPANT':
            addLog(`👤 Nouveau participant: ${payload.player_id} dans la session ${payload.session_id}`, 'success');
            
            // Marquer pour rechargement des stats
            setTimeout(fetchServerStats, 500);
            break;
            
        case 'KEY_UPDATE':
            addLog(`🔑 Clé mise à jour (version: ${payload.version})`, 'info');
            break;
            
        case 'HISTORY_CLEARED':
            addLog(`🗑️ Historique effacé`, 'warning');
            // Effacer l'affichage du chat
            const messagesContainer = document.getElementById('chatMessages');
            if (messagesContainer) {
                messagesContainer.innerHTML = '<div class="chat-empty">Historique effacé - Aucun message</div>';
            }
            setTimeout(fetchServerStats, 500);
            break;
            
        case 'ERROR':
            addLog(`❌ Erreur: ${payload.message} (${payload.code})`, 'error');
            break;
            
        default:
            addLog(`Message reçu: ${type}`, 'info');
    }
}

// Gestion des connexions (affichage simplifié)
function renderConnections() {
    const container = document.getElementById('connectionsList');
    
    if (stats.connections === 0) {
        container.innerHTML = '<div class="empty-state">Aucune connexion active</div>';
        return;
    }
    
    container.innerHTML = `
        <div class="connection-item">
            <div class="connection-header">
                <div class="connection-id">Connexions WebSocket actives</div>
                <div class="connection-badge">${stats.connections} clients</div>
            </div>
            <div class="connection-details">
                <div>🌐 Clients connectés en temps réel</div>
                <div>📊 Données mises à jour automatiquement</div>
            </div>
        </div>
    `;
}

function renderRooms() {
    const container = document.getElementById('roomsList');
    
    if (activeRooms.size === 0) {
        container.innerHTML = '<div class="empty-state">Aucun salon actif</div>';
        return;
    }
    
    container.innerHTML = Array.from(activeRooms.values())
        .filter(room => room.id !== '__dashboard_monitor__')
        .sort((a, b) => b.messageCount - a.messageCount)
        .map(room => `
            <div class="room-item">
                <div class="room-header">
                    <div class="room-id">${room.id}</div>
                    <div class="room-badge">${room.participantCount || room.participants.size} participant(s)</div>
                </div>
                <div class="room-details">
                    <div>💬 Messages: ${room.messageCount}</div>
                    <div>🕐 Actif</div>
                    ${room.participants && room.participants.size > 0 ? `
                        <div class="room-participants">
                            ${Array.from(room.participants).map(p => 
                                `<span class="participant-tag">${p}</span>`
                            ).join('')}
                        </div>
                    ` : ''}
                </div>
            </div>
        `).join('');
}

function updateStats() {
    document.getElementById('totalConnections').textContent = stats.connections;
    document.getElementById('totalRooms').textContent = stats.rooms;
    document.getElementById('totalMessages').textContent = stats.messages;
    renderConnections();
}

function updateServerStatus(connected) {
    const badge = document.getElementById('serverStatus');
    const statusText = badge.querySelector('.status-text');
    
    if (connected) {
        badge.classList.add('connected');
        statusText.textContent = 'Connecté';
    } else {
        badge.classList.remove('connected');
        statusText.textContent = 'Déconnecté';
    }
}

function updateUptime() {
    const uptime = Date.now() - startTime;
    const hours = Math.floor(uptime / 3600000);
    const minutes = Math.floor((uptime % 3600000) / 60000);
    const seconds = Math.floor((uptime % 60000) / 1000);
    
    document.getElementById('uptime').textContent = 
        `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

// Journal d'activité
function addLog(message, type = 'info') {
    const logContainer = document.getElementById('activityLog');
    const timestamp = new Date().toLocaleTimeString('fr-FR');
    const autoScroll = document.getElementById('autoScrollCheck').checked;
    
    const logEntry = document.createElement('div');
    logEntry.className = `log-entry ${type}`;
    logEntry.innerHTML = `<span class="log-timestamp">[${timestamp}]</span>${message}`;
    
    logContainer.appendChild(logEntry);
    
    // Limiter à 100 entrées
    while (logContainer.children.length > 100) {
        logContainer.removeChild(logContainer.firstChild);
    }
    
    if (autoScroll) {
        logContainer.scrollTop = logContainer.scrollHeight;
    }
}

function clearLogs() {
    document.getElementById('activityLog').innerHTML = '';
    addLog('Journal effacé', 'info');
}

function toggleActivityLog() {
    const section = document.getElementById('activityLogSection');
    const icon = document.querySelector('.toggle-icon');
    
    if (section.style.display === 'none') {
        section.style.display = 'block';
        icon.classList.add('open');
    } else {
        section.style.display = 'none';
        icon.classList.remove('open');
    }
}

// Utilitaires
function formatTime(date) {
    return date.toLocaleTimeString('fr-FR', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
}

// ============================================
// MINI CHAT CLIENT
// ============================================

function initChatClient() {
    // Générer un ID unique pour ce client
    currentPlayerId = 'dashboard_' + Math.random().toString(36).substr(2, 9);
    
    // Événements
    document.getElementById('joinBtn').addEventListener('click', joinChatSession);
    document.getElementById('sendBtn').addEventListener('click', sendChatMessage);
    document.getElementById('clearChatBtn').addEventListener('click', clearChatMessages);
    document.getElementById('fileBtn').addEventListener('click', () => {
        document.getElementById('fileInput').click();
    });
    document.getElementById('fileInput').addEventListener('change', handleFileUpload);
    
    document.getElementById('messageInput').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            sendChatMessage();
        }
    });
    
    // Cliquer sur un salon pour le rejoindre
    document.getElementById('roomsList').addEventListener('click', (e) => {
        const roomItem = e.target.closest('.room-item');
        if (roomItem) {
            const roomId = roomItem.querySelector('.room-id').textContent;
            document.getElementById('sessionInput').value = roomId;
        }
    });
    
    // Drag & drop de fichiers sur la zone de chat
    const chatMessages = document.getElementById('chatMessages');
    
    chatMessages.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.stopPropagation();
        chatMessages.classList.add('drag-over');
    });
    
    chatMessages.addEventListener('dragleave', (e) => {
        e.preventDefault();
        e.stopPropagation();
        // Ne retirer que si on quitte vraiment la zone
        if (!chatMessages.contains(e.relatedTarget)) {
            chatMessages.classList.remove('drag-over');
        }
    });
    
    chatMessages.addEventListener('drop', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        chatMessages.classList.remove('drag-over');
        
        if (!currentSession) {
            alert('Rejoignez une session avant de déposer un fichier');
            return;
        }
        
        const files = e.dataTransfer.files;
        for (let i = 0; i < files.length; i++) {
            const file = files[i];
            // Vérifier si c'est un fichier texte (pas binaire)
            if (file.type.startsWith('text/') || isTextExtension(file.name)) {
                await handleFileUpload(file);
            } else if (file.type.startsWith('image/')) {
                // Aussi supporter le drop d'images
                await handleImageDrop(file);
            } else {
                addLog(`⚠️ Type de fichier non supporté: ${file.name}`, 'warning');
            }
        }
    });
}

function isTextExtension(filename) {
    const textExts = [
        'txt', 'md', 'json', 'xml', 'csv', 'log', 'yml', 'yaml', 'toml', 'ini', 'cfg',
        'js', 'ts', 'py', 'cpp', 'c', 'h', 'hpp', 'java', 'cs', 'go', 'rs', 'rb',
        'php', 'swift', 'kt', 'qml', 'html', 'css', 'sql', 'sh', 'bat', 'jsx', 'tsx',
        'vue', 'svelte', 'scss', 'less', 'sass', 'env', 'gitignore', 'dockerfile'
    ];
    const ext = filename.split('.').pop().toLowerCase();
    return textExts.includes(ext);
}

async function handleImageDrop(file) {
    if (file.size > 5 * 1024 * 1024) {
        alert('Image trop volumineuse (max 5MB)');
        return;
    }
    
    try {
        const reader = new FileReader();
        reader.onload = async (e) => {
            await sendRawMessage(e.target.result);
            addLog(`📤 Image "${file.name}" envoyée`, 'success');
        };
        reader.readAsDataURL(file);
    } catch (err) {
        console.error('Erreur envoi image:', err);
    }
}

async function handleFileUpload(event) {
    const file = event.target.files ? event.target.files[0] : event;
    if (!file) return;
    
    // Vérifier la taille
    const maxSize = 1024 * 1024; // 1MB max
    if (file.size > maxSize) {
        alert('Le fichier est trop volumineux (max 1MB)');
        return;
    }
    
    try {
        const text = await file.text();
        
        // Format: 📄FILE:extension:nom_fichier\n\ncontenu
        const extension = file.name.split('.').pop().toLowerCase();
        const content = `📄FILE:${extension}:${file.name}\n\n${text}`;
        
        // Envoyer directement (ne pas passer par l'input qui perd les \n)
        await sendRawMessage(content);
        
        // Réinitialiser l'input file si c'est un event
        if (event.target && event.target.files) {
            event.target.value = '';
        }
        
        addLog(`📤 Fichier "${file.name}" envoyé (${extension.toUpperCase()})`, 'success');
    } catch (err) {
        console.error('Erreur lecture fichier:', err);
        alert('Erreur lors de la lecture du fichier');
    }
}

function clearChatMessages() {
    if (!currentSession) return;
    
    if (confirm(`Voulez-vous vraiment effacer tous les messages de la session "${currentSession}" ?\n\nCette action est irréversible et affectera tous les participants.`)) {
        // Effacer immédiatement l'affichage local
        const messagesContainer = document.getElementById('chatMessages');
        messagesContainer.innerHTML = '<div class="chat-empty">Effacement en cours...</div>';
        
        // Envoyer la demande au serveur
        chatWs.send(JSON.stringify({
            type: 'CLEAR_HISTORY',
            payload: {
                session_id: currentSession
            }
        }));
        
        addLog(`🗑️ Historique effacé pour "${currentSession}"`, 'warning');
    }
}

function joinChatSession() {
    const sessionId = document.getElementById('sessionInput').value.trim();
    const nickname = document.getElementById('nicknameInput').value.trim() || 'Dashboard';
    const password = document.getElementById('passwordInput').value.trim();
    
    if (!sessionId) {
        alert('Veuillez entrer un ID de session');
        return;
    }
    
    if (!password) {
        alert('Veuillez entrer le mot de passe de la session');
        return;
    }
    
    // Fermer la connexion précédente si elle existe
    if (chatWs) {
        chatWs.close();
    }
    
    currentSession = sessionId;
    currentNickname = nickname;
    currentPassword = password;
    chatMessages = [];
    sessionKeys.clear();
    currentKeyVersion = 0;
    
    // Dériver la Lock Key de manière asynchrone
    ChatCrypto.deriveLockKey(sessionId, password).then(key => {
        lockKey = key;
        
        // Créer une nouvelle connexion WebSocket
        chatWs = new WebSocket(WS_URL);
        
        chatWs.onopen = () => {
            // Rejoindre la session
            chatWs.send(JSON.stringify({
                type: 'JOIN_SESSION',
                payload: {
                    session_id: sessionId,
                    player_id: currentPlayerId,
                    player_nickname: nickname
                }
            }));
            
            updateChatStatus('Connexion...', false);
        };
        
        chatWs.onmessage = (event) => {
            try {
                const message = JSON.parse(event.data);
                handleChatMessage(message);
            } catch (err) {
                console.error('Erreur chat:', err);
            }
        };
        
        chatWs.onerror = (error) => {
            console.error('Erreur WebSocket chat:', error);
            updateChatStatus('Erreur de connexion', false);
        };
        
        chatWs.onclose = () => {
            updateChatStatus('Déconnecté', false);
            document.getElementById('chatArea').style.display = 'none';
        };
    }).catch(err => {
        alert('Erreur lors de la dérivation de la clé: ' + err.message);
    });
}

async function handleChatMessage(message) {
    const { type, payload } = message;
    
    switch (type) {
        case 'INIT_SESSION':
            // Session rejointe avec succès
            updateChatStatus(`Connecté à "${currentSession}"`, true);
            document.getElementById('chatArea').style.display = 'block';
            
            // Traiter les clés du serveur
            if (payload.keys && payload.keys.length > 0) {
                for (const keyData of payload.keys) {
                    try {
                        const encryptedKeyBytes = ChatCrypto.base64ToBytes(keyData.key_package);
                        const nonceBytes = ChatCrypto.base64ToBytes(keyData.nonce);
                        const version = keyData.version;
                        
                        // Déchiffrer la clé de session avec la Lock Key
                        const sessionKey = await ChatCrypto.decrypt(encryptedKeyBytes, lockKey, nonceBytes);
                        
                        if (sessionKey) {
                            sessionKeys.set(version, sessionKey);
                            if (version > currentKeyVersion) {
                                currentKeyVersion = version;
                            }
                            addLog(`🔑 Clé v${version} déchiffrée`, 'success');
                        } else {
                            addLog(`❌ Clé v${version} - Mauvais mot de passe?`, 'error');
                        }
                    } catch (err) {
                        console.error('Erreur déchiffrement clé:', err);
                    }
                }
            }
            
            // Si aucune clé et pas un nouveau participant, créer une clé
            const isNewJoiner = payload.new_joiner;
            if (!isNewJoiner && sessionKeys.size === 0) {
                addLog('💡 Nouvelle session - génération clé...', 'info');
                await publishNewKey();
            }
            
            // Charger l'historique
            if (payload.history && payload.history.length > 0) {
                for (const msg of payload.history) {
                    await displayServerMessage(msg);
                }
            }
            break;
            
        case 'HISTORY_RESULT':
            if (payload.history && payload.history.length > 0) {
                for (const msg of payload.history) {
                    await displayServerMessage(msg);
                }
            }
            break;
            
        case 'NEW_MESSAGE':
            await displayServerMessage(payload);
            break;
            
        case 'NEW_PARTICIPANT':
            addLog(`👋 ${payload.player_id} a rejoint`, 'success');
            break;
            
        case 'KEY_UPDATE':
            addLog(`🔑 Nouvelle clé v${payload.version}`, 'info');
            try {
                const encryptedKeyBytes = ChatCrypto.base64ToBytes(payload.key_package);
                const nonceBytes = ChatCrypto.base64ToBytes(payload.nonce);
                const version = payload.version;
                
                const sessionKey = await ChatCrypto.decrypt(encryptedKeyBytes, lockKey, nonceBytes);
                if (sessionKey) {
                    sessionKeys.set(version, sessionKey);
                    if (version > currentKeyVersion) {
                        currentKeyVersion = version;
                    }
                    addLog(`✅ Clé v${version} installée`, 'success');
                }
            } catch (err) {
                console.error('Erreur KEY_UPDATE:', err);
            }
            break;
            
        case 'ERROR':
            addLog(`❌ ${payload.message}`, 'error');
            if (payload.code === 'KEY_ROTATION_REQUIRED') {
                await publishNewKey();
            }
            break;
    }
}

async function sendChatMessage() {
    const input = document.getElementById('messageInput');
    const content = input.value.trim();
    
    if (!content) return;
    
    await sendRawMessage(content);
    input.value = '';
}

// Envoyer un message brut (sans passer par l'input field)
async function sendRawMessage(content) {
    if (!content || !chatWs || chatWs.readyState !== WebSocket.OPEN) {
        return;
    }
    
    if (currentKeyVersion === 0 || !sessionKeys.has(currentKeyVersion)) {
        addLog('❌ Aucune clé de session disponible', 'error');
        return;
    }
    
    try {
        // Chiffrer le message avec la clé de session actuelle
        const plainBytes = ChatCrypto.stringToBytes(content);
        const sessionKey = sessionKeys.get(currentKeyVersion);
        const nonce = ChatCrypto.generateNonce();
        
        const cipherBytes = await ChatCrypto.encrypt(plainBytes, sessionKey, nonce);
        
        // Envoyer au serveur
        chatWs.send(JSON.stringify({
            type: 'SEND_MSG',
            payload: {
                session_id: currentSession,
                sender_id: currentPlayerId,
                sender_nickname: currentNickname,
                payload: ChatCrypto.bytesToBase64(cipherBytes),
                nonce: ChatCrypto.bytesToBase64(nonce),
                key_v: currentKeyVersion
            }
        }));
    } catch (err) {
        console.error('Erreur envoi message:', err);
        addLog('❌ Échec d\'envoi du message', 'error');
    }
}

// Afficher un message du serveur (déchiffré)
async function displayServerMessage(msgData) {
    try {
        const keyVersion = msgData.key_version || 1;
        const cipherBytes = ChatCrypto.base64ToBytes(msgData.payload);
        const nonceBytes = ChatCrypto.base64ToBytes(msgData.nonce);
        
        let content = '[Message chiffré - clé manquante]';
        let isDecrypted = false;
        
        if (sessionKeys.has(keyVersion)) {
            const sessionKey = sessionKeys.get(keyVersion);
            const plainBytes = await ChatCrypto.decrypt(cipherBytes, sessionKey, nonceBytes);
            
            if (plainBytes) {
                content = ChatCrypto.bytesToString(plainBytes);
                isDecrypted = true;
            } else {
                content = '[Échec du déchiffrement]';
            }
        }
        
        displayChatMessage({
            sender: msgData.sender_nickname || msgData.sender_id,
            content: content,
            time: new Date(msgData.timestamp || msgData.server_timestamp),
            isOwn: msgData.sender_id === currentPlayerId,
            isEncrypted: !isDecrypted
        });
    } catch (err) {
        console.error('Erreur affichage message:', err);
    }
}

// Publier une nouvelle clé de session
async function publishNewKey() {
    if (!lockKey) {
        addLog('❌ Impossible de publier une clé', 'error');
        return;
    }
    
    try {
        const sessionKey = ChatCrypto.generateSessionKey();
        const nonce = ChatCrypto.generateNonce();
        const encryptedKey = await ChatCrypto.encrypt(sessionKey, lockKey, nonce);
        
        chatWs.send(JSON.stringify({
            type: 'PUBLISH_KEY',
            payload: {
                session_id: currentSession,
                blob: ChatCrypto.bytesToBase64(encryptedKey),
                nonce: ChatCrypto.bytesToBase64(nonce)
            }
        }));
        
        addLog('📤 Nouvelle clé publiée', 'info');
    } catch (err) {
        console.error('Erreur publication clé:', err);
    }
}

function displayChatMessage({ sender, content, time, isOwn, isEncrypted }) {
    const messagesContainer = document.getElementById('chatMessages');
    
    // Supprimer le message "Aucun message" si présent
    const emptyState = messagesContainer.querySelector('.chat-empty');
    if (emptyState) {
        emptyState.remove();
    }
    
    const messageDiv = document.createElement('div');
    messageDiv.className = 'chat-message' + (isOwn ? ' own' : '');
    
    // Détecter les messages très longs (> 500 caractères)
    const isLongMessage = content.length > 500;
    
    // Détecter si c'est une image (supporte WEBP, PNG, JPEG, GIF, etc.)
    const isImage = content.match(/^data:image\/(webp|png|jpeg|jpg|gif|bmp|svg\+xml);base64,/i);
    
    // Détecter si c'est un fichier texte (nouveau format: 📄FILE:ext:filename)
    const isTextFile = content.startsWith('📄FILE:');
    
    let contentClass = 'chat-message-content';
    let displayContent = content;
    
    if (isImage && !isEncrypted) {
        // Extraire le type d'image
        const imageType = isImage[1].toUpperCase();
        const sizeKB = Math.round(content.length / 1024);
        
        // Afficher l'image avec des informations
        displayContent = `
            <div style="margin-bottom: 8px; color: #666; font-style: italic;">
                🖼️ Image ${imageType} (${sizeKB} KB)
            </div>
            <div style="position: relative; display: inline-block;">
                <img src="${content}" 
                     alt="Image ${imageType}" 
                     style="max-width: 100%; max-height: 400px; border-radius: 8px; cursor: pointer; display: block;" 
                     onclick="openImageModal(this.src)"
                     onload="this.style.opacity='1'"
                     onerror="this.parentElement.innerHTML='<div style=\\'color: red;\\'>❌ Erreur de chargement de l\\'image</div>'"
                     loading="lazy"
                     title="Cliquez pour agrandir">
                <div style="position: absolute; top: 5px; right: 5px; background: rgba(0,0,0,0.6); color: white; padding: 4px 8px; border-radius: 4px; font-size: 0.8em;">
                    ${sizeKB} KB
                </div>
            </div>
        `;
    } else if (isTextFile && !isEncrypted) {
        // Parser le format: 📄FILE:ext:filename\n\ncontenu (robuste)
        const firstLine = content.split('\n')[0];
        const fileIdx = firstLine.indexOf('FILE:');
        const afterPrefix = fileIdx !== -1 ? firstLine.substring(fileIdx + 5) : '';
        const parts = afterPrefix.split(':');
        const extension = parts[0] || 'txt';
        const fileName = parts[1] || 'Unknown';
        
        // Extraire le contenu via \n\n (robuste)
        const sepIdx = content.indexOf('\n\n');
        const fileContent = sepIdx !== -1 ? content.substring(sepIdx + 2) : content;
        
        // Icônes par extension
        const extensionIcons = {
            'txt': '📄', 'md': '📝', 'json': '📊', 'xml': '🏷️',
            'js': '📜', 'ts': '📜', 'py': '🐍', 'cpp': '⚙️', 'c': '⚙️', 'h': '⚙️',
            'java': '☕', 'html': '🌐', 'css': '🎨', 'log': '📋',
            'csv': '📊', 'sql': '🗄️', 'sh': '🖥️', 'bat': '🖥️'
        };
        const icon = extensionIcons[extension.toLowerCase()] || '📄';
        
        // Stocker les données pour les boutons (compteur unique)
        const fileId = 'file_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
        
        contentClass += ' long-message text-file-display';
        const escapedContent = fileContent.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        displayContent = `
            <div class="text-file-header">
                <span class="text-file-name">${icon} ${fileName}</span>
                <div class="text-file-actions">
                    <span class="text-file-ext">${extension.toUpperCase()}</span>
                    <button class="text-file-btn" onclick="copyFileContent('${fileId}')" title="Copier le contenu">📋</button>
                    <button class="text-file-btn" onclick="downloadFile('${fileId}')" title="Télécharger le fichier">💾</button>
                </div>
            </div>
            <pre id="${fileId}" class="text-file-content" data-filename="${fileName}">${escapedContent}</pre>
        `;
    } else if (isLongMessage) {
        // Message long non-image
        contentClass += ' long-message';
        displayContent = `<div style="margin-bottom: 8px; color: #666; font-style: italic;">📎 Message long (${content.length} caractères)</div>${content}`;
    }
    
    messageDiv.innerHTML = `
        <div class="chat-message-header">
            <span class="chat-message-sender">${sender}</span>
            <span class="chat-message-time">${formatTime(time)}</span>
        </div>
        <div class="${contentClass}">
            ${isEncrypted && !isImage ? '🔒 ' : ''}${displayContent}
        </div>
    `;
    
    messagesContainer.appendChild(messageDiv);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

function updateChatStatus(text, isConnected) {
    const statusEl = document.getElementById('chatStatus');
    statusEl.textContent = text;
    statusEl.className = 'chat-client-status' + (isConnected ? ' joined' : '');
}

// Fonctions pour la modale d'image
function openImageModal(src) {
    const modal = document.getElementById('imageModal');
    const modalImg = document.getElementById('modalImage');
    modal.style.display = 'block';
    modalImg.src = src;
}

function closeImageModal() {
    document.getElementById('imageModal').style.display = 'none';
}

// Fermer avec la touche Echap
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeImageModal();
    }
});

// Copier le contenu d'un fichier texte
function copyFileContent(fileId) {
    const pre = document.getElementById(fileId);
    if (!pre) return;
    
    const text = pre.textContent;
    navigator.clipboard.writeText(text).then(() => {
        // Feedback visuel
        const btn = pre.parentElement.querySelector('.text-file-btn');
        if (btn) {
            const original = btn.textContent;
            btn.textContent = '✅';
            setTimeout(() => { btn.textContent = original; }, 1500);
        }
    }).catch(err => {
        // Fallback pour les contextes non-sécurisés
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
    });
}

// Télécharger un fichier texte
function downloadFile(fileId) {
    const pre = document.getElementById(fileId);
    if (!pre) return;
    
    const text = pre.textContent;
    const fileName = pre.dataset.filename || 'file.txt';
    
    const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    
    setTimeout(() => {
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }, 100);
}

