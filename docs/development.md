# Development

## Layout

| Directory | Responsibility |
|---|---|
| `src/` | QML widgets, calendar, color extraction, preferences, provider actions, weather parsing and requests |
| `src/shaders/` | Dots, waves, liquid hover trail and cover glow; source and compiled Qt shaders |
| `integrations/spotify/` | Spicetify extension and the local Python bridge |
| `tests/unit/` | Artwork palette and weather model checks |
| `tests/context/` | Provider logic and real loopback bridge checks |
| `tests/ui/` | Actual QML interaction and plugin identity checks |
| `tools/` | Reproducible gallery capture scripts and private demo fixtures |
| `docs/` | Feature, setup, development, release and credit guides |
| `docs/media/` | Screenshots, MP4 recordings and looping GIF previews |

Omarchy loads `src/BarWidget.qml` through the root `manifest.json`. QML imports
stay within `src/`, shaders resolve relative to the widgets, and Spotify's
bridge resolves to `integrations/spotify/spotify_bridge.py`.

## Checks

From the repository root:

```bash
node tests/unit/palette.cjs
node tests/unit/weather.cjs tools/demo-fixtures/paris-forecast.json
node tests/context/logic.cjs
python3 tests/context/bridge.py
python3 tests/ui/run.py
```

The Node checks exercise parsing, provider matching, saved-song confirmation,
already-liked no-ops, advertisement handling, and track-change races. The
loopback test checks the real Soup WebSocket bridge, origin rejection,
malformed messages, URI checks, and disconnect handling.

The UI test needs a running Wayland desktop, `qs`, QtTest, `dbus-daemon`,
`busctl`, Python D-Bus bindings, PyGObject, and Soup 3. It starts private MPRIS
players and a fake Spotify extension. It tests side-button spacing, menus,
repeat cycling, shuffle, browser links, confirmed heart state, ads, podcast
seeking, and disabled capabilities. It does not operate real Spotify or alter
its library.

## Build shaders

Compiled shaders are tracked alongside their source so installs need no build.
With the Qt 6 shader tools installed:

```bash
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 -o src/shaders/Aurora.frag.qsb src/shaders/Aurora.frag
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 -o src/shaders/CoverBlend.frag.qsb src/shaders/CoverBlend.frag
```

When changing a shader, rebuild its `.qsb` and inspect the running plugin.

## Capture the feature guide

```bash
python3 tools/capture-demo.py
```

Run this on an Omarchy Wayland desktop. It needs FFmpeg and Grim in addition to the UI
test dependencies. The tool captures the real QML scene into PNG, MP4, and
looping GIF assets in `docs/media/`. Capturing the scene directly keeps other
applications out of the frames. The playback-menu screenshot uses a bounded
desktop capture because Qt renders its popup outside the card scene; inspect
that image before sharing it.

It uses private MPRIS fixtures for Poison Girl by HIM, cached Paris weather and
city-search responses, and deterministic clock demo bands. Preference writes
stay in a fake bar host. The like demonstration talks to a fake extension.
No user location, Spotify library, or real playback is modified. Recordings
contain no audio.

## Verify an installation

After a reload, inspect the actual dashboard and query `musicStatus`,
`contextStatus`, `weatherStatus`, `animationStatus`, and `spectrumStatus`.
A copied source file does not establish that the running shell loaded it.
The [setup guide](setup.md#troubleshooting) lists the commands.
