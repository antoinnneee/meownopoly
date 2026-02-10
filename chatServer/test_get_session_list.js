const WebSocket = require('ws');

const ws = new WebSocket('ws://pattounecorp.ovh:3000');

ws.on('open', () => {
    console.log('Connected');
    ws.send(JSON.stringify({ type: 'GET_SESSION_LIST' }));
});

ws.on('message', (data) => {
    const msg = JSON.parse(data);
    console.log('Received:', msg);
    if (msg.type === 'SESSIONS_LIST') {
        console.log('Success!');
        ws.close();
        process.exit(0);
    }
});

ws.on('error', (err) => {
    console.error('Connection error:', err.message);
    process.exit(1);
});

setTimeout(() => {
    console.log('Timeout');
    process.exit(1);
}, 2000);
