"""Encrypted client fixture for real loopback and UI tests."""
import base64
import secrets
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'integrations/spotify'))
from spotify_auth import Channel, OAEP, load_key


def session_hello():
    seed = secrets.token_bytes(32)
    hello = {'type': 'hello', 'version': 1, 'nonce': secrets.token_hex(32),
             'key': base64.b64encode(load_key().public_key().encrypt(seed, OAEP)).decode()}
    return seed, hello


def session_welcome(seed, hello, packet):
    channel = Channel(seed, hello['nonce'], packet['nonce'], server=False)
    assert channel.open(packet)['type'] == 'ready'
    return channel
