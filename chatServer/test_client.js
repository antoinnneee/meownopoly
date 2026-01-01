const WebSocket = require('ws');

async function testServer() {
    const ws = new WebSocket('ws://localhost:3000');
    const sessionId = 'test-session-' + Date.now();
    const playerId = 'player-1';

    ws.on('open', () => {
        console.log('[Test] Connected to server');

        // 1. Join Session
        console.log('[Test] Joining session...');
        ws.send(JSON.stringify({
            type: 'JOIN_SESSION',
            payload: { session_id: sessionId, player_id: playerId }
        }));
    });

    ws.on('message', (data) => {
        const msg = JSON.parse(data);
        console.log('[Test] Received:', msg.type, msg.payload);

        if (msg.type === 'INIT_SESSION') {
            // 2. Publish Key
            console.log('[Test] Publishing key...');
            ws.send(JSON.stringify({
                type: 'PUBLISH_KEY',
                payload: { session_id: sessionId, blob: 'encrypted-key-package', nonce: 'key-nonce' }
            }));

            // 3. Send Message
            setTimeout(() => {
                console.log('[Test] Sending message...');
                ws.send(JSON.stringify({
                    type: 'SEND_MSG',
                    payload: {
                        session_id: sessionId,
                        sender_id: playerId,
                        payload: 'encrypted-message-payload',
                        nonce: 'msg-nonce',
                        key_v: 1
                    }
                }));
            }, 500);
        }

        if (msg.type === 'NEW_MESSAGE') {
            console.log('[Test] Message received successfully!');

            // 4. Get History
            console.log('[Test] Requesting history...');
            ws.send(JSON.stringify({
                type: 'GET_HISTORY',
                payload: { session_id: sessionId }
            }));
        }

        if (msg.type === 'HISTORY_RESULT') {
            console.log('[Test] History received:', msg.payload.history.length, 'messages');
            console.log('[Test] SUCCESS');
            ws.close();
            process.exit(0);
        }

        if (msg.type === 'ERROR') {
            console.error('[Test] FAIL:', msg.payload);
            ws.close();
            process.exit(1);
        }
    });

    ws.on('error', (err) => {
        console.error('[Test] WebSocket error:', err);
        process.exit(1);
    });
}

// Start the server in the background first or ensure it's running
testServer();
