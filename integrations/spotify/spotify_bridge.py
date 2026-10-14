#!/usr/bin/env python3
"""Spotify-only loopback WebSocket bridge; commands arrive on private stdin."""
import json
import os
import re
import sys
import gi

gi.require_version('Soup', '3.0')
from gi.repository import GLib, Soup
from spotify_auth import Channel, load_key

TRACK = re.compile(r'^spotify:track:[A-Za-z0-9]{22}$')
connection = None
current_uri = ''
stdin_buffer = b''
loop = GLib.MainLoop()
sessions = {}
identity = None

def emit(message):
    print(json.dumps(message, separators=(',', ':')), flush=True)

def send(socket, message):
    socket.send_text(json.dumps(sessions[socket]['channel'].seal(message)))

def received(socket, kind, payload):
    global connection, current_uri
    if kind != Soup.WebsocketDataType.TEXT:
        socket.close(1008, 'Text messages required')
        return
    try:
        packet = json.loads(payload.get_data().decode('utf-8'))
        session = sessions[socket]
        if session['phase'] == 'hello':
            session['channel'], welcome = Channel.accept(packet, identity)
            session['phase'] = 'confirm'
            socket.send_text(json.dumps(welcome))
            return
        message = session['channel'].open(packet)
        if session['phase'] == 'confirm':
            if message.get('type') != 'confirm':
                raise ValueError('Authentication confirmation required')
            session['phase'] = 'ready'
            GLib.source_remove(session['deadline'])
            session['deadline'] = 0
            previous = connection
            connection = socket
            current_uri = ''
            if previous is not None:
                previous.close(1001, 'Replaced by Spotify connection')
            emit({'type': 'connected'})
            send(socket, {'action': 'refresh'})
            return
        if message.get('type') == 'state':
            uri = str(message.get('uri', ''))
            liked = message.get('liked')
            current_uri = uri
            emit({'type': 'state', 'uri': uri, 'liked': liked if isinstance(liked, bool) else None,
                  'canLike': bool(TRACK.fullmatch(uri)) and isinstance(liked, bool) and not message.get('ad', False),
                  'error': str(message.get('error', ''))[:240]})
        elif message.get('type') == 'result':
            emit({'type': 'result', 'id': message.get('id'), 'uri': message.get('uri', ''),
                  'ok': message.get('ok') is True, 'error': str(message.get('error', ''))[:240]})
    except (ValueError, UnicodeError, AttributeError, KeyError):
        socket.close(1008, 'Invalid or unauthenticated Spotify message')

def closed(socket):
    global connection, current_uri
    session = sessions.pop(socket, None)
    if session and session['deadline']:
        GLib.source_remove(session['deadline'])
    if connection is socket:
        connection = None
        current_uri = ''
        emit({'type': 'disconnected'})

def connected(server, message, path, socket):
    if len(sessions) >= 8:
        socket.close(1008, 'Too many connections')
        return
    session = {'phase': 'hello', 'channel': None, 'deadline': 0}
    sessions[socket] = session
    def expired():
        session['deadline'] = 0
        socket.close(1008, 'Authentication timed out')
        return False
    session['deadline'] = GLib.timeout_add(5000, expired)
    socket.set_max_incoming_payload_size(16384)
    socket.connect('message', received)
    socket.connect('closed', closed)

def stdin_ready(fd, condition):
    global stdin_buffer
    data = os.read(fd, 4096)
    if not data:
        loop.quit()
        return False
    stdin_buffer += data
    while b'\n' in stdin_buffer:
        line, stdin_buffer = stdin_buffer.split(b'\n', 1)
        command = {}
        try:
            command = json.loads(line)
            uri = command.get('uri', '')
            if command.get('action') != 'like' or not isinstance(uri, str) or not TRACK.fullmatch(uri):
                raise ValueError('Unsupported Spotify action')
            if connection is None or uri != current_uri:
                raise ValueError('Spotify track changed or disconnected')
            send(connection, {'action': 'like', 'uri': uri, 'id': command.get('id')})
        except (ValueError, UnicodeError, AttributeError) as error:
            emit({'type': 'result', 'id': command.get('id') if isinstance(command, dict) else None,
                  'ok': False, 'error': str(error)})
    if len(stdin_buffer) > 16384:
        loop.quit()
        return False
    return True

if __name__ == '__main__':
    server = Soup.Server()
    # Browser pages from other origins cannot connect or issue commands.
    server.add_websocket_handler('/dashboard', 'https://xpui.app.spotify.com', None, connected)
    try:
        identity = load_key()
        server.listen_local(int(os.environ.get('DASHBOARD_SPOTIFY_BRIDGE_PORT', '9154')), Soup.ServerListenOptions.IPV4_ONLY)
        GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, stdin_ready)
        loop.run()
    except (GLib.Error, OSError, ValueError) as error:
        emit({'type': 'error', 'error': str(error)})
        sys.exit(1)
