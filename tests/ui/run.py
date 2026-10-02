from pathlib import Path
import subprocess,os,time
root=Path(__file__).resolve().parent;children=[]
import tempfile
runtime=Path(tempfile.mkdtemp(prefix='prism-ui-test-'));output=runtime
imports=runtime/'imports';imports.mkdir();(imports/'qs').symlink_to('/usr/share/omarchy/shell')
try:
 (runtime/'bus.conf').write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><policy context="default"><allow own="*"/><allow send_destination="*"/><allow receive_sender="*"/></policy></busconfig>')
 bus=subprocess.Popen(['dbus-daemon','--config-file='+str(runtime/'bus.conf'),'--nofork','--print-address=1'],stdout=subprocess.PIPE,text=True);children.append(bus)
 env=dict(os.environ,DBUS_SESSION_BUS_ADDRESS=bus.stdout.readline().strip(),QS_DISABLE_FILE_WATCHER='1',QML_IMPORT_PATH=str(imports),DASHBOARD_BAR=(root.parents[1]/'src/BarWidget.qml').as_uri(),DASHBOARD_SPOTIFY_BRIDGE_PORT='19154',DCONF_BACKEND='memory')
 for script in ['mpris_player.py','spotify_fixture.py']:
  children.append(subprocess.Popen(['python3',str(root/script)],env=env,stdout=(runtime/(script+'.log')).open('w'),stderr=subprocess.STDOUT))
 time.sleep(.3)
 shell=subprocess.Popen(['qs','-p',str(root/'shell.qml'),'--no-color'],env=env,stdout=(runtime/'qml.log').open('w'),stderr=subprocess.STDOUT);children.append(shell)
 base=['qs','ipc','-p',str(root/'shell.qml'),'call','spectrum-smoke']
 for _ in range(60):
  r=subprocess.run(base+['colors'],env=env,capture_output=True,text=True)
  if r.returncode==0:break
  if shell.poll() is not None:raise RuntimeError((runtime/'qml.log').read_text())
  time.sleep(.1)
 else:raise RuntimeError('QML never became ready: '+(runtime/'qml.log').read_text())
 r=subprocess.run(base+['checks',str(output)],env=env,capture_output=True,text=True,timeout=15)
 time.sleep(.3)
 log=(runtime/'qml.log').read_text();print(log)
 assert 'CONTEXT_CHECKS_PASS' in log,r.stderr
 assert (runtime/'spotify_fixture.py.log').read_text().count('ADD ')==1,'already liked wrote another save'
 print('Actual QML side buttons, repeat cycle, menu, browser action and confirmed heart passed')
finally:
 for p in reversed(children):
  if p.poll() is None:p.terminate()
 for p in children:
  try:p.wait(timeout=3)
  except subprocess.TimeoutExpired:p.kill()
