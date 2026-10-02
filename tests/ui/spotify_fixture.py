import gi,json
gi.require_version('Soup','3.0')
from gi.repository import GLib,Soup
session=Soup.Session();sock=None;liked=False;uri='spotify:track:1234567890123456789012'
def state():sock.send_text(json.dumps({'type':'state','uri':uri,'liked':liked}))
def message(s,k,b):
 global liked
 m=json.loads(b.get_data().decode())
 if m['action']=='like':
  liked=True;print('ADD '+m['uri'],flush=True)
  sock.send_text(json.dumps({'type':'result','uri':uri,'id':m['id'],'ok':True}))
 state()
def connected(s,r):
 global sock
 try:
  sock=s.websocket_connect_finish(r);sock.connect('message',message);state()
 except GLib.Error:GLib.timeout_add(250,connect)
def connect():
 session.websocket_connect_async(Soup.Message.new('GET','http://127.0.0.1:19154/dashboard'),'https://xpui.app.spotify.com',None,GLib.PRIORITY_DEFAULT,None,connected)
 return False
connect();GLib.MainLoop().run()
