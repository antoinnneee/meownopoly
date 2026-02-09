const dgram = require('dgram');

function startStunServer(port = 3478) {
  const server = dgram.createSocket('udp4');

  server.on('message', (msg, rinfo) => {
    console.log(`Reçu requête de ${rinfo.address}:${rinfo.port}`);

    // STUN Message Type: Binding Request (0x0001)
    // Simple check
    const msgType = msg.readUInt16BE(0);

    if (msgType === 0x0001) {
      console.log(`  -> Binding Request détecté. Envoi de la réponse...`);

      // Construire la réponse (Binding Response: 0x0101)
      const response = Buffer.alloc(32);

      response.writeUInt16BE(0x0101, 0); // Type: Binding Response
      response.writeUInt16BE(12, 2);     // Length: 12 bytes (Attributes)
      msg.copy(response, 4, 4, 20);      // Copier Magic Cookie & Transaction ID (Echo exact)

      // Attribute: MAPPED-ADDRESS (0x0001)
      response.writeUInt16BE(0x0001, 20); // Type
      response.writeUInt16BE(8, 22);      // Length
      response.writeUInt8(0, 24);         // Reserved
      response.writeUInt8(0x01, 25);      // Family: IPv4
      response.writeUInt16BE(rinfo.port, 26); // Port

      // IP Address handling
      const parts = rinfo.address.split('.');
      for (let i = 0; i < 4; i++) {
        response.writeUInt8(parseInt(parts[i]), 28 + i);
      }

      server.send(response, rinfo.port, rinfo.address, (err) => {
        if (err) console.error(err);
        else console.log(`  -> Réponse envoyée à ${rinfo.address}:${rinfo.port}`);
      });
    }
  });

  server.on('listening', () => {
    const address = server.address();
    console.log(`Serveur STUN (Simple) écoute sur ${address.address}:${address.port}`);
  });

  server.bind(port);
  return server;
}

module.exports = { startStunServer };

// Si exécuté directement
if (require.main === module) {
  startStunServer();
}
