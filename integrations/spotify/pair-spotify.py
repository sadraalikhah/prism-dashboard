#!/usr/bin/env python3
"""Provision the bridge identity and pin its public key in Spicetify."""
import argparse
import os
from pathlib import Path
import tempfile
from spotify_auth import load_key, public_pin

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, help='Installed extension path; defaults to the Spicetify Extensions directory')
args = parser.parse_args()
config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
output = args.output or config / 'spicetify/Extensions/dashboard-spotify-auth.js'
key = load_key(create=True)
source = Path(__file__).with_name('dashboard-spotify.js').read_text()
source = source.replace('const BRIDGE_PUBLIC_KEY = "";', f'const BRIDGE_PUBLIC_KEY = "{public_pin(key)}";')
output.parent.mkdir(parents=True, exist_ok=True)
fd, temporary = tempfile.mkstemp(prefix='.prism-spotify-', dir=output.parent)
try:
    with os.fdopen(fd, 'w') as stream:
        stream.write(source)
    os.replace(temporary, output)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
print(f'Paired extension written to {output}. Disable dashboard-spotify.js, enable dashboard-spotify-auth.js, then run spicetify apply.')
