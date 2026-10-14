"""Check private key provisioning and cryptographic session boundaries."""
import base64
import os
from pathlib import Path
import secrets
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'integrations/spotify'))
from spotify_auth import Channel, OAEP, load_key, public_pin

def rejects(call):
    try:
        call()
    except (ValueError, OSError):
        return
    raise AssertionError('Unsafe input accepted')

with tempfile.TemporaryDirectory(prefix='prism-auth-') as directory:
    path = Path(directory) / 'identity/key.pem'
    key = load_key(path, create=True)
    assert path.stat().st_mode & 0o777 == 0o600
    assert path.parent.stat().st_mode & 0o777 == 0o700
    assert public_pin(load_key(path)) == public_pin(key)
    os.chmod(path, 0o644); rejects(lambda: load_key(path)); os.chmod(path, 0o600)
    link = path.with_name('link.pem'); link.symlink_to(path); rejects(lambda: load_key(link))
    os.chmod(path.parent, 0o755); rejects(lambda: load_key(path)); os.chmod(path.parent, 0o700)
    seed = secrets.token_bytes(32)
    hello = {'type': 'hello', 'version': 1, 'nonce': secrets.token_hex(32),
             'key': base64.b64encode(key.public_key().encrypt(seed, OAEP)).decode()}
    server, welcome = Channel.accept(hello, key)
    client = Channel(seed, hello['nonce'], welcome['nonce'], server=False)
    assert client.open(welcome)['type'] == 'ready'
    packet = client.seal({'type': 'confirm'})
    assert server.open(packet)['type'] == 'confirm'
    rejects(lambda: server.open(packet))
    frame = server.seal({'action': 'like', 'uri': 'spotify:track:1234567890123456789012'})
    damaged = dict(frame, data=base64.b64encode(b'bad tag').decode())
    rejects(lambda: client.open(damaged))
    assert client.open(frame)['action'] == 'like'
    other, other_welcome = Channel.accept(hello, key)
    assert other_welcome['nonce'] != welcome['nonce'], 'replayed hello reused a session key'
    other_client = Channel(seed, hello['nonce'], other_welcome['nonce'], server=False)
    assert other_client.open(other_welcome)['type'] == 'ready'
    rejects(lambda: other_client.open(frame))
    rejects(lambda: Channel.accept(dict(hello, nonce='invalid'), key))
    rejects(lambda: Channel.accept({'type': 'state'}, key))
print('Private identity, tampering, replay and fresh-session checks passed')
