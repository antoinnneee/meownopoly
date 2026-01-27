const WebSocket = require('ws');

async function testClear() {
    const ws = new WebSocket('ws://192.168.1.40:3000');
    const sessionId = 'test-clear-' + Date.now();
    const playerId = 'tester';

    ws.on('open', () => {
        console.log('[Test] Connected');
        ws.send(JSON.stringify({
            type: 'JOIN_SESSION',
            payload: { session_id: sessionId, player_id: playerId }
        }));
    });

    ws.on('message', (data) => {
        const msg = JSON.parse(data);
        if (msg.type === 'INIT_SESSION') {
            // Send a message first
            ws.send(JSON.stringify({
                type: 'SEND_MSG',
                payload: {
                    session_id: sessionId,
                    sender_id: playerId,
                    payload: 'dummy-content',
                    nonce: 'dummy-nonce',
                    key_v: 1
                }
            }));
        }
        else if (msg.type === 'NEW_MESSAGE') {
            console.log('[Test] Message received. Sending CLEAR_HISTORY for session:', sessionId);
            ws.send(JSON.stringify({
                type: 'CLEAR_HISTORY',
                payload: { session_id: sessionId }
            }));
        }
        else if (msg.type === 'HISTORY_CLEARED') {
            console.log('[Test] HISTORY_CLEARED event received!');
            // Verify by asking for history
            console.log('[Test] Verifying history is empty...');
            ws.send(JSON.stringify({
                type: 'GET_HISTORY',
                payload: { session_id: sessionId }
            }));
        }
        else if (msg.type === 'HISTORY_RESULT') {
            if (msg.payload.history.length === 0) {
                console.log('[Test] SUCCESS: History is empty.');
                process.exit(0);
            } else {
                console.error('[Test] FAIL: History not empty!', msg.payload.history);
                process.exit(1);
            }
        }
    });
}

testClear();
