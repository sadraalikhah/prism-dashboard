const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');
const Peer = require('./peer.cjs');
const {publicKey, privateKey} = crypto.generateKeyPairSync('rsa', {modulusLength: 2048});
const pin = publicKey.export({type: 'spki', format: 'der'}).toString('base64');
const uri = 'spotify:track:1234567890123456789012';
let reads = 0, writes = 0;
class Socket {
  static OPEN = 1;
  constructor() { this.readyState = 1; this.messages = []; Socket.last = this; }
  send(value) { this.messages.push(JSON.parse(value)); }
  close() { this.readyState = 3; }
}
const source = fs.readFileSync(__dirname + '/../../integrations/spotify/dashboard-spotify.js', 'utf8')
  .replace('const BRIDGE_PUBLIC_KEY = "";', `const BRIDGE_PUBLIC_KEY = ${JSON.stringify(pin)};`);
const env = vm.createContext({crypto: crypto.webcrypto, TextEncoder, TextDecoder, atob, btoa,
  Spicetify: {Player: {data: {item: {uri}}, getHeart: () => false, addEventListener() {}},
    Platform: {LibraryAPI: {contains: async () => { reads++; return [false]; }, add: async () => { writes++; }}}},
  WebSocket: Socket, window: {addEventListener() {}},
  setTimeout: () => 1, clearTimeout() {}, setInterval: () => 1, clearInterval() {}});
(async () => {
  vm.runInContext(source, env);
  for (let i = 0; !Socket.last && i < 30; i++) await new Promise(r => setImmediate(r));
  const socket = Socket.last;
  assert(socket, 'paired extension should connect');
  await socket.onopen();
  await new Promise(r => setImmediate(r));
  assert(!JSON.stringify(socket.messages).includes(uri), 'fake bridge must not receive the current track');
  assert.equal(reads, 0, 'do not query saved status before authenticating the bridge');
  await socket.onmessage({data: JSON.stringify({action: 'like', uri, id: 1})});
  assert.equal(writes, 0, 'unauthenticated server must not add a liked song');
  assert.equal(reads, 0);
  assert.equal(socket.readyState, 3, 'close an unauthenticated connection');
  vm.runInContext(source, env);
  const wrong = Socket.last;
  await wrong.onopen();
  await wrong.onmessage({data: JSON.stringify({type:'welcome', nonce:crypto.randomBytes(32).toString('hex'),
    seq:1, data:Buffer.alloc(32).toString('base64')})});
  assert.equal(reads, 0, 'a forged welcome must not disclose saved-song status');
  assert.equal(wrong.readyState, 3);
  vm.runInContext(source, env);
  const valid = Socket.last;
  await valid.onopen();
  const peer = new Peer(privateKey, valid.messages.shift());
  await valid.onmessage({data: JSON.stringify(peer.welcome())});
  assert.equal(peer.open(valid.messages.shift()).type, 'confirm');
  assert.equal(peer.open(valid.messages.shift()).uri, uri);
  const packet = peer.seal({action:'refresh'});
  await valid.onmessage({data: JSON.stringify(packet)});
  const afterRefresh = reads;
  await valid.onmessage({data: JSON.stringify(packet)});
  assert.equal(reads, afterRefresh, 'replayed commands must not run');
  assert.equal(valid.readyState, 3);
  vm.runInContext(source, env);
  const altered = Socket.last;
  await altered.onopen();
  const alteredPeer = new Peer(privateKey, altered.messages.shift());
  await altered.onmessage({data: JSON.stringify(alteredPeer.welcome())});
  const like = alteredPeer.seal({action:'like', uri, id:2});
  const corrupt = Buffer.from(like.data, 'base64'); corrupt[0] ^= 1;
  like.data = corrupt.toString('base64');
  await altered.onmessage({data: JSON.stringify(like)});
  assert.equal(writes, 0, 'tampered commands must not add a song');
  assert.equal(altered.readyState, 3);
  console.log('Port-spoofing regression passed: no track disclosure or library action');
})().catch(error => { console.error(error); process.exitCode = 1; });
