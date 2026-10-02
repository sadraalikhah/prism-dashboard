import subprocess, os, json, selectors, time, gi
from pathlib import Path
gi.require_version('Soup','3.0')
from gi.repository import Soup, GLib
port=19154
env=dict(os.environ,DASHBOARD_SPOTIFY_BRIDGE_PORT=str(port))
p=subprocess.Popen(['python3',str(Path(__file__).resolve().parents[2]/'spotify_bridge.py')],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
loop=GLib.MainLoop();session=Soup.Session();sock=None;messages=[];failures=[]
def finish(session,result):
 global sock
 try:
  sock=session.websocket_connect_finish(result)
  sock.connect('message',lambda s,k,b:messages.append(json.loads(b.get_data().decode())))
 except GLib.Error as e:failures.append(str(e))
 loop.quit()
def connect(origin):
 session.websocket_connect_async(Soup.Message.new('GET',f'http://127.0.0.1:{port}/dashboard'),origin,None,GLib.PRIORITY_DEFAULT,None,finish)
 GLib.timeout_add(2000,lambda:(loop.quit(),False)[1]);loop.run()
def pump():
 until=time.monotonic()+.15
 while time.monotonic()<until:
  while GLib.MainContext.default().pending():GLib.MainContext.default().iteration(False)
  time.sleep(.005)
def read():
 sel=selectors.DefaultSelector();sel.register(p.stdout,selectors.EVENT_READ)
 assert sel.select(2),'bridge did not return output: '+p.stderr.read() if p.poll() is not None else 'bridge timeout'
 return json.loads(p.stdout.readline())
try:
 time.sleep(.15);connect('https://example.org');assert failures and sock is None,'foreign origin accepted'
 connect('https://xpui.app.spotify.com');assert sock is not None,failures
 assert read()['type']=='connected';pump();assert messages.pop()['action']=='refresh'
 uri='spotify:track:1234567890123456789012'
 sock.send_text(json.dumps({'type':'state','uri':uri,'liked':False}));pump();assert read()['canLike']
 p.stdin.write(json.dumps({'action':'like','uri':uri,'id':1})+'\n');p.stdin.flush();pump();assert messages.pop()['uri']==uri
 p.stdin.write('{broken}\n');p.stdin.flush();assert read()['id'] is None
 p.stdin.write(json.dumps({'action':'like','uri':'spotify:track:abcdefghijklmnopqrstuv','id':2})+'\n');p.stdin.flush();assert read()['ok'] is False
 sock.send_text(json.dumps({'type':'state','uri':uri,'liked':True,'ad':True}));pump();assert read()['canLike'] is False
 sock.close(1000,'done');pump();assert read()['type']=='disconnected'
 print('Loopback bridge origin, URI, malformed input and disconnect checks passed')
finally:
 p.terminate();p.wait(timeout=3)
 errors=p.stderr.read()
 if errors:print(errors)
