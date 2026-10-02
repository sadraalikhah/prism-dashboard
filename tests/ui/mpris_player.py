import dbus, dbus.service, json, time, tempfile
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
from pathlib import Path
DBusGMainLoop(set_as_default=True)
PLAYER='org.mpris.MediaPlayer2.Player'; PROPS='org.freedesktop.DBus.Properties'
ROOT=Path(__file__).resolve().parent
class Player(dbus.service.Object):
 def __init__(self,name,index):
  self.bus=dbus.SessionBus(private=True);self.name=dbus.service.BusName('org.mpris.MediaPlayer2.'+name,self.bus)
  super().__init__(self.bus,'/org/mpris/MediaPlayer2');self.index=index;self.cover='red';self.title='Test track';self.length=180000000;self.spotify_kind='track'
  self.props={'PlaybackStatus':'Playing' if index==1 else 'Paused','LoopStatus':'None','Rate':dbus.Double(1),'Shuffle':False,
  'Volume':dbus.Double(.6),'Position':dbus.Int64(45000000),'MinimumRate':dbus.Double(1),'MaximumRate':dbus.Double(1),
  'CanGoNext':True,'CanGoPrevious':True,'CanPlay':True,'CanPause':True,'CanSeek':True,'CanControl':True,'Metadata':self.metadata()}
 def metadata(self):
  art='' if self.cover=='none' else (ROOT/(self.cover+'.svg')).as_uri()
  return dbus.Dictionary({'mpris:trackid':dbus.ObjectPath('/track/'+str(self.index)), 'xesam:title':self.title,'xesam:artist':dbus.Array(['Test artist'],signature='s'),
   'mpris:length':dbus.Int64(self.length),'mpris:artUrl':art,'xesam:url': 'spotify:'+self.spotify_kind+':1234567890123456789012' if self.index==40 else 'https://example.org/media/'+str(self.index)},signature='sv')
 def change(self,**values): self.props.update(values);self.PropertiesChanged(PLAYER,values,[])
 def log(self,method,*args):
  with (Path(tempfile.gettempdir())/'prism-test-calls.jsonl').open('a') as f:f.write(json.dumps({'time':time.monotonic(),'player':str(self.name),'method':method,'args':args})+'\n')
 @dbus.service.method(PROPS,in_signature='s',out_signature='a{sv}')
 def GetAll(self,interface):
  if interface==PLAYER:return self.props
  return {'Identity':'Music test player','DesktopEntry':'music_test','CanQuit':False,'CanRaise':False,'HasTrackList':False,'SupportedUriSchemes':dbus.Array([],signature='s'),'SupportedMimeTypes':dbus.Array([],signature='s')}
 @dbus.service.method(PROPS,in_signature='ss',out_signature='v')
 def Get(self,interface,prop):return self.GetAll(interface)[prop]
 @dbus.service.method(PROPS,in_signature='ssv',out_signature='')
 def Set(self,interface,prop,value):self.log('Set',prop,float(value) if prop=='Volume' else str(value));self.change(**{prop:value})
 @dbus.service.signal(PROPS,signature='sa{sv}as')
 def PropertiesChanged(self,interface,changed,invalidated):pass
 @dbus.service.signal(PLAYER,signature='x')
 def Seeked(self,value):pass
 @dbus.service.method(PLAYER)
 def Play(self):self.log('Play');self.change(PlaybackStatus='Playing')
 @dbus.service.method(PLAYER)
 def Pause(self):self.log('Pause');self.change(PlaybackStatus='Paused')
 @dbus.service.method(PLAYER)
 def PlayPause(self):self.log('PlayPause');self.change(PlaybackStatus='Paused' if self.props['PlaybackStatus']=='Playing' else 'Playing')
 @dbus.service.method(PLAYER)
 def Next(self):self.log('Next');self.index+=1;self.cover='blue' if self.cover=='red' else 'red';self.change(Metadata=self.metadata());self.Seeked(0)
 @dbus.service.method(PLAYER)
 def Previous(self):self.log('Previous');self.index-=1;self.change(Metadata=self.metadata());self.Seeked(0)
 @dbus.service.method(PLAYER,in_signature='ox')
 def SetPosition(self,track,value):
  assert str(track)=='/track/'+str(self.index)
  self.log('SetPosition',int(value));self.props['Position']=dbus.Int64(value);self.Seeked(value)
 @dbus.service.method(PLAYER,in_signature='x')
 def Seek(self,offset):self.SetPosition('/track/'+str(self.index),self.props['Position']+offset)
 @dbus.service.method('org.example.MusicTest',in_signature='s')
 def Scenario(self,scenario):
  if scenario in ['ad','episode','track']:self.spotify_kind=scenario;self.change(Metadata=self.metadata())
  elif scenario in ['red','blue','none','broken']:self.cover=scenario;self.change(Metadata=self.metadata())
  elif scenario=='zeroLength':self.length=0;self.change(Metadata=self.metadata())
  elif scenario=='newNoLength':self.index+=1;self.length=0;self.change(Metadata=self.metadata());self.Seeked(0)
  elif scenario=='noControls':self.change(CanControl=False,CanPlay=False,CanPause=False,CanSeek=False,CanGoNext=False,CanGoPrevious=False)
  elif scenario=='normal':self.length=180000000;self.change(Metadata=self.metadata(),CanControl=True,CanPlay=True,CanPause=True,CanSeek=True,CanGoNext=True,CanGoPrevious=True)
  elif scenario=='empty':self.change(Metadata=dbus.Dictionary({},signature='sv'),PlaybackStatus='Stopped')
 @dbus.service.method('org.example.MusicTest')
 def Remove(self):self.bus.release_name('org.mpris.MediaPlayer2.music_second')
 @dbus.service.method('org.example.MusicTest')
 def Quit(self):GLib.idle_add(loop.quit)
players=[Player('music_test',1),Player('music_second',10),Player('chrome',20),Player('firefox',30),Player('spotify',40)];loop=GLib.MainLoop();print('READY',flush=True);loop.run()
