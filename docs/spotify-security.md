# Spotify bridge authentication

The optional Spotify extension pins a public key for your local bridge. A
process that occupies port 9154 without the matching private key cannot
authenticate itself, receive track or saved-song information, or issue a
library action. This addresses the port-impersonation report in
[marketplace submission #9726](https://github.com/omacom/omarchy-plugin-marketplace/issues/9726#issuecomment-6085838517).

## Identity storage

`pair-spotify.py` creates a 2048-bit RSA identity in
`$XDG_CONFIG_HOME/prism-dashboard/spotify/bridge-key.pem`, or under `~/.config`
when the variable is unset. Its directory must be owned by the current user
with mode 0700. The key must be a regular, user-owned file with mode 0600;
the loader rejects symlinks and access by other users.

Pairing writes the public SPKI key into the installed Spicetify extension.
Its installed name is `dashboard-spotify-auth.js`. The setup disables the
older `dashboard-spotify.js` entry so cached legacy code cannot remain enabled.
There is no shared secret in the extension or Spotify's application files.
The repository's unpaired extension does not connect. Missing or mismatched
keys disable the integration rather than falling back to plaintext.

`PRISM_SPOTIFY_KEY_FILE` overrides the identity path for isolated tests. The
same ownership and permission checks apply. Test and demo identities are
temporary and never use the user's private key.

## Connection protocol

1. The extension creates a random 32-byte seed and client nonce. It encrypts
   the seed to the pinned RSA key using OAEP with SHA-256 and the protocol
   label `prism-spotify-v1`. The initial hello contains no track metadata.
2. The bridge decrypts the seed and creates a fresh server nonce. Both sides
   derive a 256-bit AES key with HKDF-SHA256, using the client and server
   nonces as salt and the protocol label as context.
3. The bridge sends an AES-GCM encrypted ready message. Only the private-key
   holder can produce a valid response to that client's encrypted seed.
4. The extension verifies the ready message, then sends an encrypted
   confirmation. The bridge replaces its active socket only after confirmation.
5. All state, refresh, like, and result messages use AES-GCM. Each direction
   uses a separate 32-bit IV prefix followed by a 64-bit sequence number.
   Receivers require the exact next sequence. Sessions expire before 2³²
   messages. Tampered, reordered, replayed, and plaintext frames close the socket.

Every reconnect gets a new seed. A replayed hello also gets a fresh server
nonce, so it cannot reuse the old AES key and IV sequence. Serial message
queues preserve order across asynchronous WebCrypto operations.

## Boundaries

The bridge binds IPv4 loopback and retains the Spotify Origin restriction.
Origin checks alone do not authenticate a local server; the pinned key and
encrypted ready message provide that proof. Encryption also prevents a
relaying process from reading state or forging commands.

Only the dashboard's private process input supplies like commands. The
extension checks the current track again after its asynchronous library query,
adds only unsaved regular tracks, and verifies the saved state afterward.

This authenticates the bridge to Spotify, not a local process as Spotify.
A local process can still occupy the port or compete for connections and
cause denial of service. It cannot use that position to read the extension's
encrypted state or forge a library action. Processes running as your user
that can read your private key, or malicious code inside Spotify, are outside
this boundary.

The implementation uses browser WebCrypto and Python cryptography's
[RSA-OAEP](https://cryptography.io/en/latest/hazmat/primitives/asymmetric/rsa/)
and [AES-GCM](https://cryptography.io/en/latest/hazmat/primitives/aead/)
implementations. Authentication handshakes expire after five seconds; the
server limits pending connections and frame size.
