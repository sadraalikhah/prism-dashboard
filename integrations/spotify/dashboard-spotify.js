// NAME: Omarchy Dashboard Spotify Actions
// AUTHOR: cloud
// DESCRIPTION: Saved-track status and add-only likes for the local dashboard.
(function dashboardSpotify() {
  const BRIDGE_PUBLIC_KEY = "";
  if (!globalThis.Spicetify?.Player || !Spicetify.Platform?.LibraryAPI) {
    setTimeout(dashboardSpotify, 500);
    return;
  }
  if (!BRIDGE_PUBLIC_KEY || !globalThis.crypto?.subtle) {
    Spicetify.showNotification?.('Pair Prism Spotify actions with pair-spotify.py before enabling the heart.', true);
    return;
  }
  let socket, session, lastState = '', reconnect, refreshing = false, stopped = false;
  const protocol = new TextEncoder().encode('prism-spotify-v1');
  const bytes = value => Uint8Array.from(atob(value), c => c.charCodeAt(0));
  const base64 = value => btoa(Array.from(new Uint8Array(value), byte => String.fromCharCode(byte)).join(''));
  const hex = value => Array.from(value, byte => byte.toString(16).padStart(2, '0')).join('');
  function nonce(value) {
    if (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value)) throw new Error('Invalid bridge nonce');
    return Uint8Array.from(value.match(/../g), byte => parseInt(byte, 16));
  }
  function iv(direction, seq) {
    const buffer = new ArrayBuffer(12), view = new DataView(buffer);
    view.setUint32(0, direction);
    view.setBigUint64(4, BigInt(seq));
    return buffer;
  }
  async function decrypt(context, packet) {
    if (!Number.isInteger(packet.seq) || packet.seq !== context.received + 1 || packet.seq >= 2**32
        || typeof packet.data !== 'string' || packet.data.length > 16000) throw new Error('Invalid bridge frame');
    const data = await crypto.subtle.decrypt({name:'AES-GCM', iv:iv(1, packet.seq), additionalData:protocol}, context.key, bytes(packet.data));
    const message = JSON.parse(new TextDecoder().decode(data));
    if (!message || typeof message !== 'object' || Array.isArray(message)) throw new Error('Invalid bridge message');
    context.received = packet.seq;
    return message;
  }
  const library = Spicetify.Platform.LibraryAPI;
  const trackPattern = /^spotify:track:[A-Za-z0-9]{22}$/;
  function send(message) {
    const context = session;
    if (!context || context.socket.readyState !== WebSocket.OPEN) return Promise.resolve();
    context.outbound = context.outbound.then(async () => {
      if (session !== context || context.socket.readyState !== WebSocket.OPEN) return;
      const seq = ++context.sent;
      if (seq >= 2**32) throw new Error('Session expired');
      const data = await crypto.subtle.encrypt({name:'AES-GCM', iv:iv(0, seq), additionalData:protocol}, context.key,
        new TextEncoder().encode(JSON.stringify(message)));
      if (session === context && context.socket.readyState === WebSocket.OPEN)
        context.socket.send(JSON.stringify({seq, data:base64(data)}));
    }).catch(() => context.socket.close());
    return context.outbound;
  }
  function current() {
    const item = Spicetify.Player.data?.item;
    return {uri: item?.uri || '', ad: item?.type === 'ad' || item?.metadata?.is_advertisement === 'true'};
  }
  async function refresh(force = false) {
    const context = session;
    if (refreshing || !context || context.socket.readyState !== WebSocket.OPEN) return;
    refreshing = true;
    const item = current();
    try {
      let liked = null;
      if (trackPattern.test(item.uri) && !item.ad) {
        if (force || !lastState || JSON.parse(lastState).uri !== item.uri)
          [liked] = await library.contains(item.uri);
        else liked = Spicetify.Player.getHeart();
      }
      if (current().uri !== item.uri || session !== context) return;
      const state = JSON.stringify({type: 'state', ...item, liked});
      if (force || state !== lastState) { await send(JSON.parse(state)); if (session === context) lastState = state; }
    } catch (error) {
      if (session === context) await send({type:'state', ...item, liked:null, error: String(error.message || error)});
    } finally { refreshing = false; }
  }
  async function handle(command, context) {
    try {
      if (command.action === 'refresh') { await refresh(true); return; }
      if (command.action !== 'like' || !trackPattern.test(command.uri)) throw new Error('Unsupported action');
      if (session !== context || current().uri !== command.uri || current().ad) throw new Error('Spotify track changed or disconnected');
      const [alreadySaved] = await library.contains(command.uri);
      if (session !== context || current().uri !== command.uri || current().ad) throw new Error('Spotify track changed or disconnected');
      if (!alreadySaved) await library.add({uris:[command.uri]});
      const [saved] = await library.contains(command.uri);
      if (!saved) throw new Error('Spotify did not confirm the song was saved');
      if (session !== context) return;
      await send({type:'result', id:command.id, uri:command.uri, ok:true});
      lastState = '';
      await refresh(true);
    } catch (error) {
      if (session !== context) return;
      await send({type:'result', id:command?.id, uri:command?.uri, ok:false, error:String(error.message || error)});
      await refresh(true);
    }
  }
  function connect() {
    if (stopped) return;
    const ws = new WebSocket('ws://127.0.0.1:9154/dashboard');
    socket = ws;
    const context = {socket:ws, nonce:hex(crypto.getRandomValues(new Uint8Array(32))),
      sent:0, received:0, outbound:Promise.resolve(), inbound:Promise.resolve(), key:null};
    const deadline = setTimeout(() => ws.close(), 5000);
    ws.onopen = async () => {
      try {
        const pin = await crypto.subtle.importKey('spki', bytes(BRIDGE_PUBLIC_KEY), {name:'RSA-OAEP', hash:'SHA-256'}, false, ['encrypt']);
        const seed = crypto.getRandomValues(new Uint8Array(32));
        context.material = await crypto.subtle.importKey('raw', seed, 'HKDF', false, ['deriveKey']);
        const wrapped = await crypto.subtle.encrypt({name:'RSA-OAEP', label:protocol}, pin, seed);
        seed.fill(0);
        if (!stopped && ws.readyState === WebSocket.OPEN)
          ws.send(JSON.stringify({type:'hello', version:1, nonce:context.nonce, key:base64(wrapped)}));
      } catch (error) { ws.close(); }
    };
    ws.onmessage = event => context.inbound = context.inbound.then(async () => {
      if (stopped || ws !== socket || ws.readyState !== WebSocket.OPEN) return;
      if (typeof event.data !== 'string' || event.data.length > 16384) throw new Error('Invalid bridge message');
      const packet = JSON.parse(event.data);
      if (session !== context) {
        if (packet.type !== 'welcome' || !context.material) throw new Error('Bridge authentication required');
        const salt = new Uint8Array(64);
        salt.set(nonce(context.nonce)); salt.set(nonce(packet.nonce), 32);
        context.key = await crypto.subtle.deriveKey({name:'HKDF', hash:'SHA-256', salt, info:protocol}, context.material,
          {name:'AES-GCM', length:256}, false, ['encrypt', 'decrypt']);
        const ready = await decrypt(context, packet);
        if (ready.type !== 'ready') throw new Error('Invalid bridge proof');
        if (ws !== socket || ws.readyState !== WebSocket.OPEN) return;
        session = context;
        clearTimeout(deadline);
        await send({type:'confirm'});
        lastState = '';
        await refresh(true);
      } else {
        await handle(await decrypt(context, packet), context);
      }
    }).catch(() => ws.close());
    ws.onclose = () => {
      clearTimeout(deadline);
      if (session === context) session = null;
      if (ws === socket && !stopped) { clearTimeout(reconnect); reconnect = setTimeout(connect, 1000); }
    };
    ws.onerror = () => ws.close();
  }
  Spicetify.Player.addEventListener('songchange', () => {lastState = ''; refresh(true);});
  Spicetify.Player.addEventListener('onplaypause', () => refresh());
  const timer = setInterval(() => refresh(), 500);
  window.addEventListener('beforeunload', () => {
    stopped = true;
    session = null;
    clearInterval(timer); clearTimeout(reconnect);
    if (socket) {socket.onclose = null; socket.close();}
  });
  connect();
})();
