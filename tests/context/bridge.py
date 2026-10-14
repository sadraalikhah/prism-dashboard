"""Exercise authentication and encrypted actions against the real Soup server."""
import json
import os
from pathlib import Path
import queue
import subprocess
import tempfile
import threading
import time
import gi
from client import session_hello, session_welcome
from spotify_auth import load_key

gi.require_version('Soup', '3.0')
from gi.repository import Soup, GLib

root = Path(__file__).resolve().parents[2]
runtime = tempfile.TemporaryDirectory(prefix='prism-bridge-test-')
keyfile = Path(runtime.name) / 'identity/key.pem'
load_key(keyfile, create=True)
os.environ['PRISM_SPOTIFY_KEY_FILE'] = str(keyfile)
port = 19154
env = dict(os.environ, DASHBOARD_SPOTIFY_BRIDGE_PORT=str(port))
p = subprocess.Popen(['python3', str(root / 'integrations/spotify/spotify_bridge.py')], env=env,
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
output = queue.Queue()
def reader():
    for line in p.stdout:
        output.put(json.loads(line))
threading.Thread(target=reader, daemon=True).start()
loop = GLib.MainLoop()
session = Soup.Session()
sock = None
messages = []
failures = []

def finish(session, result):
    global sock
    try:
        sock = session.websocket_connect_finish(result)
        sock.connect('message', lambda s, k, b: messages.append(json.loads(b.get_data().decode())))
    except GLib.Error as error:
        failures.append(str(error))
    loop.quit()

def connect(origin):
    global sock
    sock = None
    messages.clear()
    session.websocket_connect_async(Soup.Message.new('GET', f'http://127.0.0.1:{port}/dashboard'),
                                    origin, None, GLib.PRIORITY_DEFAULT, None, finish)
    timer = GLib.timeout_add(2000, lambda: (loop.quit(), False)[1])
    loop.run()
    GLib.source_remove(timer)

def pump():
    until = time.monotonic() + .12
    while time.monotonic() < until:
        while GLib.MainContext.default().pending():
            GLib.MainContext.default().iteration(False)
        time.sleep(.005)

def send(message):
    sock.send_text(json.dumps(message))
    pump()

def authenticate():
    seed, hello = session_hello()
    send(hello)
    channel = session_welcome(seed, hello, messages.pop(0))
    send(channel.seal({'type': 'confirm'}))
    assert output.get(timeout=2)['type'] == 'connected'
    assert channel.open(messages.pop(0))['action'] == 'refresh'
    return channel

try:
    time.sleep(.15)
    connect('https://example.org')
    assert failures and sock is None, 'foreign origin accepted'
    connect('https://xpui.app.spotify.com')
    assert sock is not None
    assert output.empty(), 'unverified socket reported connected'
    send({'type': 'state', 'uri': 'spotify:track:1234567890123456789012', 'liked': False})
    assert sock.get_state() == Soup.WebsocketState.CLOSED, 'legacy plaintext accepted'
    assert output.empty()
    connect('https://xpui.app.spotify.com')
    channel = authenticate()
    uri = 'spotify:track:1234567890123456789012'
    state = channel.seal({'type': 'state', 'uri': uri, 'liked': False})
    send(state)
    assert output.get(timeout=2)['canLike']
    p.stdin.write(json.dumps({'action': 'like', 'uri': uri, 'id': 1}) + '\n'); p.stdin.flush(); pump()
    command = channel.open(messages.pop(0))
    assert command['uri'] == uri and command['action'] == 'like'
    assert uri not in json.dumps(state), 'track leaked outside encryption'
    p.stdin.write('{broken}\n'); p.stdin.flush()
    assert output.get(timeout=2)['id'] is None
    p.stdin.write(json.dumps({'action': 'like', 'uri': 'spotify:track:abcdefghijklmnopqrstuv', 'id': 2}) + '\n'); p.stdin.flush()
    assert output.get(timeout=2)['ok'] is False
    send(channel.seal({'type': 'state', 'uri': uri, 'liked': True, 'ad': True}))
    assert output.get(timeout=2)['canLike'] is False
    send(state)
    assert sock.get_state() == Soup.WebsocketState.CLOSED, 'replay accepted'
    assert output.get(timeout=2)['type'] == 'disconnected'
    connect('https://xpui.app.spotify.com')
    channel = authenticate()
    send(state)
    assert sock.get_state() == Soup.WebsocketState.CLOSED, 'previous-session frame accepted'
    assert output.get(timeout=2)['type'] == 'disconnected'
    print('Real bridge authentication, plaintext rejection, encrypted actions, replay, reconnect and origin checks passed')
finally:
    p.terminate(); p.wait(timeout=3)
    errors = p.stderr.read()
    if errors:
        print(errors)
    runtime.cleanup()
