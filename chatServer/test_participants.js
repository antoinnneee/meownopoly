const WebSocket = require('ws');

async function testParticipants() {
    const ws = new WebSocket('ws://localhost:3000');
    const sessionId = 'test-session-' + Date.now();
    const playerId = 'player-host';

    ws.on('open', () => {
        console.log('[Test] Connected to server');
        ws.send(JSON.stringify({
            type: 'JOIN_SESSION',
            payload: { session_id: sessionId, player_id: playerId, player_nickname: 'The Host' }
        }));
    });

    ws.on('message', (data) => {
        const msg = JSON.parse(data);

        if (msg.type === 'INIT_SESSION') {
            console.log('[Test] Joined session. Requesting participants...');
            ws.send(JSON.stringify({
                type: 'GET_PARTICIPANTS',
                payload: { session_id: sessionId }
            }));
        }

        if (msg.type === 'PARTICIPANTS_LIST') {
            console.log('[Test] Participants List received:');
            console.log(JSON.stringify(msg.payload.participants, null, 2));

            const host = msg.payload.participants.find(p => p.player_id === playerId);
            if (host && host.is_host === true) {
                console.log('[Test] SUCCESS: Host correctly identified with is_host: true');
                process.exit(0);
            } else {
                console.error('[Test] FAIL: Host NOT identified correctly');
                process.exit(1);
            }
        }

        if (msg.type === 'ERROR') {
            console.error('[Test] FAIL:', msg.payload);
            process.exit(1);
        }
    });
}

testParticipants();
