import gi,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'context'))
from client import session_hello,session_welcome
gi.require_version('Soup','3.0')
from gi.repository import GLib,Soup
session=Soup.Session();sock=None;liked=False;uri='spotify:track:1234567890123456789012';channel=None
def send(message):sock.send_text(json.dumps(channel.seal(message)))
def state():send({'type':'state','uri':uri,'liked':liked})
def message(s,k,b):
 global liked,channel
 packet=json.loads(b.get_data().decode())
 if channel is None:
  channel=session_welcome(seed,hello,packet);send({'type':'confirm'});state();return
 m=channel.open(packet)
 if m['action']=='like':
  liked=True;print('ADD '+m['uri'],flush=True)
  send({'type':'result','uri':uri,'id':m['id'],'ok':True})
 state()
def connected(s,r):
 global sock,seed,hello,channel
 try:
  sock=s.websocket_connect_finish(r);channel=None;seed,hello=session_hello();sock.connect('message',message);sock.send_text(json.dumps(hello))
 except GLib.Error:GLib.timeout_add(250,connect)
def connect():
 session.websocket_connect_async(Soup.Message.new('GET','http://127.0.0.1:19154/dashboard'),'https://xpui.app.spotify.com',None,GLib.PRIORITY_DEFAULT,None,connected)
 return False
connect();GLib.MainLoop().run()
