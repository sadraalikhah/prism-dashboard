const vm = require('node:vm'), fs = require('node:fs'), assert = require('node:assert/strict');
const dir = __dirname + '/../../';
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(dir+'src/MediaContext.js','utf8'),context);
const A='spotify:track:1234567890123456789012', B='spotify:track:abcdefghijklmnopqrstuv';
for(const url of [A,'https://open.spotify.com/track/1234567890123456789012?si=foo'])
  assert.equal(context.spotifyUri({metadata:{'xesam:url':url}}),A);
assert.equal(context.spotifyUri({uniqueId:'/com/spotify/track/1234567890123456789012'}),A);
assert.equal(context.spotifyUri({uniqueId:'spotify:ad:1234567890123456789012'}),'');
assert.equal(context.pageUrl({metadata:{'xesam:url':'file:///tmp/song'}}),'');
assert.equal(context.isBrowser({dbusName:'org.mpris.MediaPlayer2.chrome.tab123'}),true);
assert.equal(context.isSpotify({dbusName:'org.mpris.MediaPlayer2.spotify.instance9'}),true);
assert.equal(context.isPodcast({metadata:{'xesam:url':A.replace('track','episode')}}),true);
(async()=>{
  let saved=false, fail=false, adds=[], contains=[], hook, interval, deferred;
  class Socket {static OPEN=1; constructor(){this.readyState=1;this.messages=[];Socket.last=this} send(s){this.messages.push(JSON.parse(s))} close(){} }
  const player={data:undefined,getHeart:()=>saved,addEventListener:()=>{}};
  const library={contains:async(uri)=>{contains.push(uri);if(deferred){const f=deferred;deferred=null;await f()}return [saved]},add:async({uris})=>{adds.push(...uris);if(!fail)saved=true}};
  const env=vm.createContext({Spicetify:{Player:player,Platform:{LibraryAPI:library}},WebSocket:Socket,window:{addEventListener:()=>{}},setTimeout:()=>1,clearTimeout:()=>{},setInterval:f=>{interval=f;return 1},clearInterval:()=>{}});
  vm.runInContext(fs.readFileSync(dir+'integrations/spotify/dashboard-spotify.js','utf8'),env);
  const s=Socket.last;await s.onopen(); await new Promise(r=>setImmediate(r));
  assert.equal(s.messages.at(-1).uri,'');assert.equal(s.messages.at(-1).liked,null);
  player.data={item:{uri:A}};await s.onmessage({data:'{"action":"refresh"}'});
  assert.equal(s.messages.at(-1).liked,false);
  await s.onmessage({data:JSON.stringify({action:'like',uri:A,id:1})});
  assert.deepEqual(adds,[A]);assert.equal(s.messages.find(m=>m.id===1).ok,true);assert.equal(s.messages.at(-1).liked,true);
  await s.onmessage({data:JSON.stringify({action:'like',uri:A,id:2})});assert.deepEqual(adds,[A]);
  await s.onmessage({data:JSON.stringify({action:'like',uri:B,id:3})});assert.equal(s.messages.find(m=>m.id===3).ok,false);assert.deepEqual(adds,[A]);
  player.data.item={uri:'spotify:ad:example',type:'ad'};await s.onmessage({data:'{"action":"refresh"}'});assert.equal(s.messages.at(-1).liked,null);
  player.data.item={uri:A};saved=false;fail=true;await s.onmessage({data:JSON.stringify({action:'like',uri:A,id:4})});assert.equal(s.messages.find(m=>m.id===4).ok,false);
  fail=false;deferred=async()=>{player.data.item={uri:B}};
  await s.onmessage({data:JSON.stringify({action:'like',uri:A,id:5})});assert.equal(s.messages.find(m=>m.id===5).ok,false);assert.equal(adds.length,2);
  console.log('Provider matching and Spotify add-only, confirmed save, ad and track-change checks passed');
})().catch(e=>{console.error(e);process.exitCode=1});
