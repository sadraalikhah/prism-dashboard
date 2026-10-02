#!/usr/bin/env python3
"""Record the real plugin with private MPRIS fixtures; no user settings are saved."""
from pathlib import Path
import json,os,signal,subprocess,tempfile,time,sys
root=Path(__file__).resolve().parent;repo=root.parent;media=repo/'docs/media'
media.mkdir(parents=True,exist_ok=True)
children=[];scratch=Path(tempfile.mkdtemp(prefix='prism-demo-')); env=None
try:
 (scratch/'imports').mkdir();(scratch/'imports/qs').symlink_to('/usr/share/omarchy/shell')
 (scratch/'bus.conf').write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><policy context="default"><allow own="*"/><allow send_destination="*"/><allow receive_sender="*"/></policy></busconfig>')
 bus=subprocess.Popen(['dbus-daemon','--config-file='+str(scratch/'bus.conf'),'--nofork','--print-address=1'],stdout=subprocess.PIPE,text=True);children.append(bus)
 env=dict(os.environ,DBUS_SESSION_BUS_ADDRESS=bus.stdout.readline().strip(),QS_DISABLE_FILE_WATCHER='1',QML_IMPORT_PATH=str(scratch/'imports'),DASHBOARD_BAR=(repo/'src/BarWidget.qml').as_uri(),DASHBOARD_SPOTIFY_BRIDGE_PORT='19154',PRISM_DEMO_FIXTURES=str(root/'demo-fixtures'),DCONF_BACKEND='memory')
 def start(cmd,name):
  p=subprocess.Popen(cmd,env=env,stdout=(scratch/(name+'.log')).open('w'),stderr=subprocess.STDOUT);children.append(p);return p
 start(['python3',str(root/'demo-player.py')],'player');start(['python3',str(root/'demo-spotify.py')],'spotify')
 time.sleep(.3);shell=start(['qs','-p',str(root/'demo.qml'),'--no-color'],'qml')
 base=['qs','ipc','-p',str(root/'demo.qml'),'call','prism-demo']
 def call(*args):return subprocess.check_output(base+list(args),env=env,text=True,stderr=subprocess.DEVNULL).strip()
 for _ in range(60):
  try:call('ready');break
  except subprocess.CalledProcessError:
   if shell.poll() is not None:raise RuntimeError((scratch/'qml.log').read_text())
   time.sleep(.1)
 else:raise RuntimeError('Demo not ready: '+(scratch/'qml.log').read_text())
 def scenario(value,player='music_test'):
  subprocess.run(['busctl','--address='+env['DBUS_SESSION_BUS_ADDRESS'],'call','org.mpris.MediaPlayer2.'+player,'/org/mpris/MediaPlayer2','org.example.MusicTest','Scenario','s',value],check=True,capture_output=True)
 def setup():
  call('stopHover');scenario('red');scenario('normal');call('reset');time.sleep(.3)
 def geometry():
  g=json.loads(call('geom'));return f"{round(g['x'])},{round(g['y'])} {round(g['w'])}x{round(g['h'])}"
 def grab(path,method='capture'):
  call('ensureOpen');call(method,str(path))
  for _ in range(150):
   if path.exists():
    data=path.read_bytes()
    if data.endswith(b'IEND\xaeB`\x82'):return data
   time.sleep(.003)
  raise RuntimeError('UI capture did not complete: '+str(path))
 def png(name):
  path=media/(name+'.png')
  if path.exists():path.unlink()
  if name=='playback-options':
   if not json.loads(call('menuState'))['opened']:raise RuntimeError('Playback menu is not open')
   subprocess.run(['grim','-g',geometry(),str(path)],check=True)
  else:grab(path)
 def record(name,duration,events=None,clock=False):
  events=events or {};fps=15;path=media/(name+'.mp4')
  encoder=subprocess.Popen(['ffmpeg','-v','error','-y','-f','image2pipe','-framerate',str(fps),'-i','pipe:0','-an','-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-vf','pad=ceil(iw/2)*2:ceil(ih/2)*2','-movflags','+faststart',str(path)],stdin=subprocess.PIPE)
  start_time=time.monotonic();rect=geometry()
  try:
   for frame in range(int(duration*fps)):
    if frame in events:events[frame]()
    shot=scratch/f'frame-{frame}.png'
    encoder.stdin.write(grab(shot,'captureClock' if clock else 'capture'));shot.unlink()
    encoder.stdin.flush();time.sleep(max(0,start_time+(frame+1)/fps-time.monotonic()))
  finally:encoder.stdin.close();encoder.wait(timeout=10)
  if encoder.returncode:raise RuntimeError('Video encoding failed')
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-filter_complex','fps=10,scale=688:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=112[p];[b][p]paletteuse=dither=bayer:bayer_scale=3','-loop','0',str(media/(name+'.gif'))],check=True)
  print('Recorded '+name,flush=True)
 if '--finish' not in sys.argv:
  setup();png('overview')
  record('dynamic-colors',6,{30:lambda:call('toggle','dynamicCoverColors'),60:lambda:call('toggle','dynamicCoverColors')})
  setup();call('toggle','displayWaves');record('dots',5)
  setup();call('toggle','displayDots');record('waves',5)
  setup();call('hover');record('liquid-hover',6);call('stopHover')
  setup();record('playback',6,{20:lambda:call('month','1'),40:lambda:call('month','-1'),60:lambda:scenario('noControls'),75:lambda:scenario('normal')})
  setup();call('settings');png('settings')
  record('settings',7,{15:lambda:call('toggle','dynamicCoverColors'),35:lambda:call('toggle','dynamicCoverColors'),55:lambda:call('toggle','displayDots'),75:lambda:call('toggle','displayWaves'),90:lambda:call('toggle','displayDots')})
  setup();call('location');time.sleep(.2);png('location');record('location',3)
  setup();call('select','spotify');time.sleep(.8);png('spotify-unliked')
  record('spotify-like',4,{15:lambda:call('like')});png('spotify-liked')
 else:
  setup();call('select','spotify');time.sleep(.8);call('like');time.sleep(.3)
 call('menu');time.sleep(.2);png('playback-options')
 setup();call('select','spotify');scenario('episode','spotify');time.sleep(.2);png('podcast')
 setup();call('select','chrome');time.sleep(.2);png('browser')
 setup();call('clockPreview');time.sleep(.15);call('captureClock',str(media/'clock.png'));time.sleep(.15)
 record('clock',6,{20:lambda:call('clock'),40:lambda:call('clock'),60:lambda:call('clock')},clock=True)
 (media/'capture-info.json').write_text(json.dumps({'source':'Frame recordings of the real Prism Dashboard QML scene in a Quickshell desktop session','metadata':'Private MPRIS fixtures for Poison Girl by HIM, Razorblade Romance artwork, Paris-only Open-Meteo/Photon responses','audio':'No audio recorded. Clock clip uses deterministic demo band levels in the real clock renderer; production uses CAVA and PipeWire.','clockSpectrum':json.loads(call('spectrum')),'fps':15,'loopPreviewFps':10},indent=2))
 log=(scratch/'qml.log').read_text()
 if 'ReferenceError' in log or 'TypeError' in log or 'ERROR' in log or 'QtQuickTest::fail' in log:raise RuntimeError(log)
 print('Demo capture complete: '+str(media),flush=True)
finally:
 for p in reversed(children):
  if p.poll() is None:p.terminate()
 for p in children:
  try:p.wait(timeout=3)
  except subprocess.TimeoutExpired:p.kill()
 if scratch.exists():
  print('Capture logs: '+str(scratch),flush=True)
