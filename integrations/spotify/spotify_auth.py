"""Pinned bridge identity and encrypted, ordered WebSocket messages."""
import base64
import json
import os
from pathlib import Path
import secrets
import stat
import sys

# A private, optional dependency install supports hosts without system packages.
dependencies = Path(__file__).with_name('.python')
if dependencies.exists():
    info = dependencies.stat()
    if info.st_uid != os.getuid() or info.st_mode & 0o022:
        raise PermissionError('Unsafe Spotify dependency directory')
    sys.path.append(str(dependencies))

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

PROTOCOL = b'prism-spotify-v1'
OAEP = padding.OAEP(mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(), label=PROTOCOL)


def key_path():
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
    return Path(os.environ.get('PRISM_SPOTIFY_KEY_FILE', config / 'prism-dashboard/spotify/bridge-key.pem'))


def load_key(path=None, create=False):
    path = Path(path or key_path())
    if create:
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    parent = path.parent.stat()
    if path.parent.is_symlink() or parent.st_uid != os.getuid() or parent.st_mode & 0o077:
        raise PermissionError('Spotify key directory must be owned by you with mode 0700')
    if create and not path.exists():
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        encoded = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                    serialization.NoEncryption())
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(encoded)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise PermissionError('Spotify private key must be owned by you with mode 0600')
        key = serialization.load_pem_private_key(stream.read(16384), password=None)
    if not isinstance(key, rsa.RSAPrivateKey) or key.key_size < 2048:
        raise ValueError('Invalid Spotify bridge identity')
    return key


def public_pin(key):
    return base64.b64encode(key.public_key().public_bytes(
        serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)).decode('ascii')


def nonce(value):
    if not isinstance(value, str) or len(value) != 64:
        raise ValueError('Invalid handshake nonce')
    try:
        decoded = bytes.fromhex(value)
    except ValueError:
        raise ValueError('Invalid handshake nonce') from None
    if len(decoded) != 32:
        raise ValueError('Invalid handshake nonce')
    return decoded


class Channel:
    def __init__(self, seed, client_nonce, server_nonce, server=True):
        if len(seed) != 32:
            raise ValueError('Invalid session key')
        key = HKDF(algorithm=hashes.SHA256(), length=32,
                   salt=nonce(client_nonce) + nonce(server_nonce), info=PROTOCOL).derive(seed)
        self.cipher = AESGCM(key)
        self.send_direction = 1 if server else 0
        self.sent = self.received = 0

    @classmethod
    def accept(cls, message, key):
        if not isinstance(message, dict) or message.get('type') != 'hello' or message.get('version') != 1:
            raise ValueError('Authentication required')
        client_nonce = message.get('nonce')
        nonce(client_nonce)
        wrapped = message.get('key')
        if not isinstance(wrapped, str) or len(wrapped) > 1024:
            raise ValueError('Invalid handshake key')
        seed = key.decrypt(base64.b64decode(wrapped, validate=True), OAEP)
        server_nonce = secrets.token_hex(32)
        channel = cls(seed, client_nonce, server_nonce)
        welcome = channel.seal({'type': 'ready'})
        welcome.update(type='welcome', nonce=server_nonce)
        return channel, welcome

    def seal(self, message):
        self.sent += 1
        if self.sent >= 2**32:
            raise ValueError('Session expired')
        iv = self.send_direction.to_bytes(4, 'big') + self.sent.to_bytes(8, 'big')
        payload = json.dumps(message, separators=(',', ':')).encode()
        return {'seq': self.sent, 'data': base64.b64encode(self.cipher.encrypt(iv, payload, PROTOCOL)).decode('ascii')}

    def open(self, packet):
        if not isinstance(packet, dict) or type(packet.get('seq')) is not int or packet['seq'] != self.received + 1:
            raise ValueError('Replayed or unordered Spotify message')
        if packet['seq'] >= 2**32 or not isinstance(packet.get('data'), str) or len(packet['data']) > 16000:
            raise ValueError('Invalid encrypted Spotify message')
        iv = (1 - self.send_direction).to_bytes(4, 'big') + packet['seq'].to_bytes(8, 'big')
        try:
            clear = self.cipher.decrypt(iv, base64.b64decode(packet['data'], validate=True), PROTOCOL)
            message = json.loads(clear)
        except (InvalidTag, ValueError, UnicodeError):
            raise ValueError('Invalid encrypted Spotify message') from None
        if not isinstance(message, dict):
            raise ValueError('Invalid Spotify message')
        self.received = packet['seq']
        return message
