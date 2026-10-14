# Setup and preferences

## Requirements

Use a current Omarchy Shell with the `qs.Commons` and `qs.Ui` components,
Quickshell with MPRIS support, `curl`, and a Nerd Font. Weather needs an internet
connection. Compiled `.qsb` shaders ship with the plugin.

Optional integrations:

| Feature | Requirement |
|---|---|
| Audio spectrum and bass response | CAVA with PipeWire input support |
| Spotify Liked Songs | Desktop Spotify with Spicetify applied, Python 3, PyGObject, Soup 3, Python cryptography |
| Browser page action | A browser MPRIS source exposing an HTTP or HTTPS media URL |
| Podcast skips | An episode URI or podcast content type, duration, and MPRIS seeking |

The plugin depends on Omarchy's UI components and is not a standalone
Quickshell configuration.

## Put Prism on the bar

After the [installation commands](../README.md#install), run:

```bash
omarchy plugin enable io.github.sadraalikhah.prism-dashboard --section center
```

## Migrate from another clock

Prism installs separately from `omarchy.clock` and `cucu0628.dashboard`. To
replace one of them, back up `~/.config/omarchy/shell.json`, then replace only
that clock entry's `id` with `io.github.sadraalikhah.prism-dashboard`. Preserve
its format, appearance switches, units, placement, and other fields. For example:

```json
{"id": "io.github.sadraalikhah.prism-dashboard", "format": "dddd HH:mm"}
```

If you already enabled Prism, remove its extra entry before replacing the old
clock entry. Update `centerAnchor` only if it points at the old clock. The
shared weather location remains in Omarchy's existing weather state file.

For a stale plugin generation:

```bash
omarchy-shell shell rescanPlugins
omarchy restart shell
```

This installation does not migrate or overwrite another plugin's preferences.

## Preferences

Open the gear inside Prism. The appearance switches save immediately.

| Setting | Default | Effect |
|---|---|---|
| `dynamicCoverColors` | `true` | Extract artwork colors; use the Omarchy theme when off |
| `displayDots` | `true` | Show the drifting dots and hover bubble |
| `displayWaves` | `true` | Show the ambient waves |
| `clockSpectrum` | `true` | Display CAVA bands behind the clock |
| `weatherUnit` | `celsius` | Choose `celsius` or `fahrenheit` |
| `format` | `dddd HH:mm` | Horizontal Qt date/time format |
| `verticalFormat` | `HH\n—\nmm` | Stacked Qt date/time format |

CAVA can remain active while the panel is open if dots need audio energy,
even with the clock visualizer off. It stops when neither effect needs it.

Right-click cycles through the stock clock presets and any configured custom
or alternate format. `formatAlt` and `verticalFormatAlt` can extend the ring.
`ww` is substituted with the ISO week number.

Reset appearance resets the four visual switches. Clock formats, weather
units, and the selected location are retained.

## Weather location

Click the map pin or select Location in settings. Search a city, confirm its
region and country, then select it. Up/Down and Enter also work. Escape cancels.
No location is saved until you choose a result.

The shared state file is `~/.local/state/omarchy/settings/weather.json`.
Name-only settings need a confirmed coordinate pair. For a script:

```bash
omarchy-weather-location --set "Paris, France" "48.8566,2.3522"
```

Forecasts refresh every 15 minutes while the panel is open. Reopening refreshes
older data. The refresh button requests an immediate update. Forecast times
and daily ranges use the chosen location's timezone.

## Spotify heart

First install Spicetify and apply it to desktop Spotify. Install the bridge's
cryptography dependency:

```bash
omarchy pkg add python-cryptography
```

If you cannot install system packages, use Python pip to install the dependency
beside the bridge instead:

```bash
python3 -m pip install --target integrations/spotify/.python -r integrations/spotify/requirements.txt
```

From the installed Prism checkout, pair the extension and enable it:

```bash
python3 integrations/spotify/pair-spotify.py
spicetify config extensions dashboard-spotify.js- extensions dashboard-spotify-auth.js
spicetify apply
```

Restart Spotify if the extension has not loaded. The
[Spicetify CLI reference](https://spicetify.app/docs/cli) explains these commands.

The dashboard starts `spotify_bridge.py` while Spotify is selected. It listens
on `127.0.0.1:9154`, accepts Spotify's app origin, and receives widget commands
through private process input. Pairing creates a private bridge key under
`~/.config/prism-dashboard/spotify/bridge-key.pem` with directory mode 0700
and file mode 0600. The installed extension contains its public key only.
Spotify verifies the bridge before sending track information or accepting
commands. Messages are encrypted and replayed messages are rejected.
Spotify keeps its own login and credentials.
No API key, OAuth developer application, or access token is entered into Prism.
The pairing script reuses your bridge key. Do not copy the unpaired source
extension directly: it deliberately disables the heart. To rotate the identity,
remove the private key, rerun pairing, then apply Spicetify again. Custom
Spicetify paths can use `pair-spotify.py --output /path/to/Extensions/dashboard-spotify-auth.js`.
See [Spotify bridge authentication](spotify-security.md) for the protocol and
its limits.

The heart appears only when Spotify reports a saved-song state for the same
track shown by MPRIS. Ads and unsupported content hide it. Saving errors appear
as desktop notifications. No action removes a song from Liked Songs.

To disable the extension:

```bash
spicetify config extensions dashboard-spotify-auth.js-
spicetify apply
```

## Troubleshooting

| Symptom | Check |
|---|---|
| Plugin missing or old behavior | Rescan plugins, enable its ID, then restart the shell |
| No player | `busctl --user list --no-pager` should show an `org.mpris.MediaPlayer2.*` service |
| Seek or volume disabled | The selected source must report that capability |
| No clock bars | Check CAVA is installed with PipeWire support and the selected player is playing |
| Spotify heart missing | Check pairing, the cryptography dependency, extension activation, private key permissions, port 9154, and a regular Spotify track |
| Weather missing | Choose a result with coordinates and check the network connection |

Read live diagnostics with the current shell:

```bash
qs ipc -p /usr/share/omarchy/shell/shell.qml call io.github.sadraalikhah.prism-dashboard musicStatus
qs ipc -p /usr/share/omarchy/shell/shell.qml call io.github.sadraalikhah.prism-dashboard contextStatus
qs ipc -p /usr/share/omarchy/shell/shell.qml call io.github.sadraalikhah.prism-dashboard weatherStatus
qs ipc -p /usr/share/omarchy/shell/shell.qml call io.github.sadraalikhah.prism-dashboard spectrumStatus
qs log -p /usr/share/omarchy/shell/shell.qml -t 50 --no-color
```

The same IPC target supports `open`, `close`, `toggle`, `cycleFormat`,
`openSettings`, `editWeather`, `refreshWeather`, `settingsStatus`, and
`animationStatus`.

## Remove Prism

```bash
omarchy plugin remove io.github.sadraalikhah.prism-dashboard
```

If it replaced the stock clock, restore `omarchy.clock` in your bar layout and
`centerAnchor`. Disable the Spicetify extension separately if you enabled it.
