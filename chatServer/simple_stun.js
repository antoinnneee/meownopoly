const dgram = require('dgram');

// STUN Magic Cookie (RFC 5389).
const MAGIC_COOKIE = 0x2112A442;
const HEADER_SIZE = 20;
const BINDING_REQUEST = 0x0001;
const BINDING_RESPONSE = 0x0101;
const ATTR_MAPPED_ADDRESS = 0x0001;
const ATTR_XOR_MAPPED_ADDRESS = 0x0020;
const FAMILY_IPV4 = 0x01;

function parseIPv4(address) {
  const parts = address.split('.');
  if (parts.length !== 4) return null;
  const bytes = Buffer.alloc(4);
  for (let i = 0; i < 4; i++) {
    const n = parseInt(parts[i], 10);
    if (!Number.isFinite(n) || n < 0 || n > 255) return null;
    bytes[i] = n;
  }
  return bytes;
}

function buildBindingResponse(transactionId, port, ipBytes) {
  // Header (20) + MAPPED-ADDRESS (12) + XOR-MAPPED-ADDRESS (12) = 44.
  const response = Buffer.alloc(44);
  response.writeUInt16BE(BINDING_RESPONSE, 0);
  response.writeUInt16BE(24, 2); // attributes length (2 × 12)
  response.writeUInt32BE(MAGIC_COOKIE, 4);
  transactionId.copy(response, 8, 0, 12);

  // MAPPED-ADDRESS (legacy mais encore largement utilisé).
  response.writeUInt16BE(ATTR_MAPPED_ADDRESS, 20);
  response.writeUInt16BE(8, 22);
  response.writeUInt8(0, 24);
  response.writeUInt8(FAMILY_IPV4, 25);
  response.writeUInt16BE(port, 26);
  ipBytes.copy(response, 28);

  // XOR-MAPPED-ADDRESS (RFC 5389 mandatory). Port XOR high 16 bits du cookie ;
  // IPv4 XOR 32 bits entiers du cookie. Évite que des NATs rewritent la payload
  // en voyant leur propre IP publique en clair.
  response.writeUInt16BE(ATTR_XOR_MAPPED_ADDRESS, 32);
  response.writeUInt16BE(8, 34);
  response.writeUInt8(0, 36);
  response.writeUInt8(FAMILY_IPV4, 37);
  response.writeUInt16BE(port ^ (MAGIC_COOKIE >>> 16), 38);
  const xorIp = Buffer.alloc(4);
  for (let i = 0; i < 4; i++) {
    xorIp[i] = ipBytes[i] ^ ((MAGIC_COOKIE >>> (24 - i * 8)) & 0xff);
  }
  xorIp.copy(response, 40);

  return response;
}

function startStunServer(port = 3478) {
  const server = dgram.createSocket('udp4');

  server.on('message', (msg, rinfo) => {
    try {
      if (msg.length < HEADER_SIZE) return;

      const msgType = msg.readUInt16BE(0);
      const msgLength = msg.readUInt16BE(2);
      const cookie = msg.readUInt32BE(4);

      if (msgType !== BINDING_REQUEST) return;
      if (cookie !== MAGIC_COOKIE) return;
      if (HEADER_SIZE + msgLength > msg.length) return;

      const transactionId = msg.slice(8, 20);
      const ipBytes = parseIPv4(rinfo.address);
      if (!ipBytes) return; // IPv6 ou adresse malformée : on ignore.

      const response = buildBindingResponse(transactionId, rinfo.port, ipBytes);
      server.send(response, rinfo.port, rinfo.address, (err) => {
        if (err) console.error('[STUN] send error:', err.message);
      });
    } catch (err) {
      // Paquet malformé : on log mais on ne crash pas le serveur.
      console.error('[STUN] malformed packet from', `${rinfo.address}:${rinfo.port}`, err.message);
    }
  });

  server.on('error', (err) => {
    console.error('[STUN] socket error:', err);
  });

  server.on('listening', () => {
    const address = server.address();
    console.log(`Serveur STUN écoute sur ${address.address}:${address.port}`);
  });

  server.bind(port);
  return server;
}

module.exports = { startStunServer };

if (require.main === module) {
  startStunServer();
}
