# Development

## Layout

| Files | Responsibility |
|---|---|
| `BarWidget.qml`, `Model.js` | Clock, format cycling, shared sampler, IPC |
| `Panel.qml` | Calendar, player selection, capabilities, dashboard composition |
| `CoverStage.qml`, `Palette.js`, `CoverBlend.frag` | Artwork, color extraction, shared palette, diagonal glow |
| `Aurora.frag` | Dots, drifting clusters, waves, liquid bubble and trail |
| `ClockSpectrum.qml` | CAVA process and spectrum rendering |
| `MediaSlider.qml`, `MediaDropdown.qml` | Seeking, volume, source picker |
| `Preferences.js`, `DashboardSettings.qml` | Preference validation, persistence, simple settings |
| `WeatherModel.js`, `WeatherService.qml`, `WeatherWidget.qml`, `WeatherLocation.qml` | Weather parsing, requests, location search and UI |
| `MediaContext.js`, `SpotifyActions.qml` | Provider actions and Spotify bridge state |
| `spotify_bridge.py`, `dashboard-spotify.js` | Local Spotify transport and confirmed add-only saves |

## Checks

From the repository root:

```bash
node test_Palette.js
node test_WeatherModel.js tools/demo-fixtures/paris-forecast.json
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
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 -o Aurora.frag.qsb Aurora.frag
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 -o CoverBlend.frag.qsb CoverBlend.frag
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
