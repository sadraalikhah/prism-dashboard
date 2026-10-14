// Independent Node crypto peer for the browser WebCrypto implementation.
const crypto = require('node:crypto');
const protocol = Buffer.from('prism-spotify-v1');
module.exports = class Peer {
  constructor(privateKey, hello) {
    const seed = crypto.privateDecrypt({key:privateKey, oaepHash:'sha256', oaepLabel:protocol}, Buffer.from(hello.key, 'base64'));
    this.nonce = crypto.randomBytes(32).toString('hex');
    this.key = Buffer.from(crypto.hkdfSync('sha256', seed, Buffer.from(hello.nonce + this.nonce, 'hex'), protocol, 32));
    this.sent = this.received = 0;
  }
  iv(direction, seq) {
    const iv = Buffer.alloc(12);
    iv.writeUInt32BE(direction); iv.writeBigUInt64BE(BigInt(seq), 4);
    return iv;
  }
  seal(message) {
    const seq = ++this.sent;
    const cipher = crypto.createCipheriv('aes-256-gcm', this.key, this.iv(1, seq));
    cipher.setAAD(protocol);
    const data = Buffer.concat([cipher.update(JSON.stringify(message)), cipher.final(), cipher.getAuthTag()]);
    return {seq, data:data.toString('base64')};
  }
  open(packet) {
    if (packet.seq !== this.received + 1) throw new Error('Unexpected client sequence');
    const data = Buffer.from(packet.data, 'base64');
    const decipher = crypto.createDecipheriv('aes-256-gcm', this.key, this.iv(0, packet.seq));
    decipher.setAAD(protocol); decipher.setAuthTag(data.subarray(-16));
    const result = JSON.parse(Buffer.concat([decipher.update(data.subarray(0, -16)), decipher.final()]));
    this.received = packet.seq;
    return result;
  }
  welcome() { return {...this.seal({type:'ready'}), type:'welcome', nonce:this.nonce}; }
};
