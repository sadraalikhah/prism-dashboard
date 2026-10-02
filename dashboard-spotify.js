// NAME: Omarchy Dashboard Spotify Actions
// AUTHOR: cloud
// DESCRIPTION: Saved-track status and add-only likes for the local dashboard.
(function dashboardSpotify() {
  if (!globalThis.Spicetify?.Player || !Spicetify.Platform?.LibraryAPI) {
    setTimeout(dashboardSpotify, 500);
    return;
  }
  let socket, lastState = '', reconnect, refreshing = false;
  const library = Spicetify.Platform.LibraryAPI;
  const trackPattern = /^spotify:track:[A-Za-z0-9]{22}$/;
  function send(message) {
    if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
  }
  function current() {
    const item = Spicetify.Player.data?.item;
    return {uri: item?.uri || '', ad: item?.type === 'ad' || item?.metadata?.is_advertisement === 'true'};
  }
  async function refresh(force = false) {
    if (refreshing || socket?.readyState !== WebSocket.OPEN) return;
    refreshing = true;
    const item = current();
    try {
      let liked = null;
      if (trackPattern.test(item.uri) && !item.ad) {
        if (force || !lastState || JSON.parse(lastState).uri !== item.uri)
          [liked] = await library.contains(item.uri);
        else liked = Spicetify.Player.getHeart();
      }
      if (current().uri !== item.uri) return;
      const state = JSON.stringify({type: 'state', ...item, liked});
      if (force || state !== lastState) { send(JSON.parse(state)); lastState = state; }
    } catch (error) {
      send({type:'state', ...item, liked:null, error: String(error.message || error)});
    } finally { refreshing = false; }
  }
  async function handle(event) {
    let command;
    try {
      command = JSON.parse(event.data);
      if (command.action === 'refresh') { await refresh(true); return; }
      if (command.action !== 'like' || !trackPattern.test(command.uri)) throw new Error('Unsupported action');
      if (current().uri !== command.uri || current().ad) throw new Error('Spotify track changed');
      const [alreadySaved] = await library.contains(command.uri);
      if (current().uri !== command.uri || current().ad) throw new Error('Spotify track changed');
      if (!alreadySaved) await library.add({uris:[command.uri]});
      const [saved] = await library.contains(command.uri);
      if (!saved) throw new Error('Spotify did not confirm the song was saved');
      send({type:'result', id:command.id, uri:command.uri, ok:true});
      lastState = '';
      await refresh(true);
    } catch (error) {
      send({type:'result', id:command?.id, uri:command?.uri, ok:false, error:String(error.message || error)});
      await refresh(true);
    }
  }
  function connect() {
    socket = new WebSocket('ws://127.0.0.1:9154/dashboard');
    socket.onopen = () => {lastState = ''; refresh(true);};
    socket.onmessage = handle;
    socket.onclose = () => {clearTimeout(reconnect); reconnect = setTimeout(connect, 1000);};
    socket.onerror = () => socket.close();
  }
  Spicetify.Player.addEventListener('songchange', () => {lastState = ''; refresh(true);});
  Spicetify.Player.addEventListener('onplaypause', () => refresh());
  const timer = setInterval(() => refresh(), 500);
  window.addEventListener('beforeunload', () => {
    clearInterval(timer); clearTimeout(reconnect);
    if (socket) {socket.onclose = null; socket.close();}
  });
  connect();
})();
