# Prism Dashboard

**Your music sets the mood of your desktop.**

Album artwork colors the player, the controls, and the clock. Dots drift across
its cover, soft waves flow behind it, and a liquid bubble chases your cursor.
Open the clock to bring your music, calendar, and local weather into one panel.

![Prism Dashboard with Poison Girl by HIM and Paris weather](docs/media/overview.png)

## See it move

![Artwork colors changing across the music card](docs/media/dynamic-colors.gif)

- **Colors from your cover.** Artwork sets the accent and the diagonal glow.
  The clock and player share the same palette, so they change together.
- **Motion you can feel.** Drifting dots, soft waves, and a spring-driven hover
  bubble with a trailing tail. Animations stop when playback pauses.
- **A clock that listens.** A CAVA spectrum reacts to your audio output behind
  the time. Right-click to cycle clock formats.
- **Controls for what is playing.** Spotify Liked Songs, supported shuffle and
  repeat, podcast skips, and links back to browser media.
- **Weather where you choose.** City search with region and country, current
  conditions, feels-like temperature, daily highs and lows, and upcoming hours.
- **Simple settings.** Switch cover colors, dots, waves, and the clock visualizer
  on or off. Choose weather units and location. Changes save immediately.

[Explore every feature with screenshots and recordings](docs/features.md)

## Install

Prism runs inside the current Omarchy Shell. It needs Quickshell, `curl`, and an
Omarchy font with Nerd Font icons. The compiled shaders are included.

From this checkout:

```bash
plugin="$HOME/.config/omarchy/plugins/cucu0628.dashboard"
mkdir -p "$plugin"
cp -- *.qml *.js *.py manifest.json *.frag *.qsb LICENSE README.md preview.png "$plugin/"
cp -R docs "$plugin/"
omarchy-shell shell rescanPlugins
omarchy plugin enable cucu0628.dashboard --section center
```

This edition retains `cucu0628.dashboard` so existing placement and preferences
continue to work. It replaces an existing installation with that ID. Back up
your existing plugin before copying if you want to keep both versions.

CAVA is optional for the audio spectrum. The Spotify heart additionally needs
Spicetify, Python, PyGObject, and Soup 3. Playback and weather work without those
optional integrations.

[Setup, Spotify installation, preferences, and troubleshooting](docs/setup.md)

## Use it

Click the clock to open Prism. Right-click it to change the format. Use the
month arrows for the calendar and the map pin for your weather location. The
player's source selector appears when several media sources are available.
The gear opens settings. Escape closes the panel.

## Built on Omarchy

Prism Dashboard is Sadra Alikhah's edition of
[cucu0628's Omarchy Dashboard](https://github.com/cucu0628/omarchy-dashboard).
It uses Omarchy's own typography, borders, and theme colors. Turn dynamic cover
colors off to use your desktop accent throughout the player and clock.

The source is [MIT licensed](LICENSE). Weather comes from
[Open-Meteo](https://open-meteo.com/), and location search uses
[Photon](https://github.com/komoot/photon) and
[OpenStreetMap contributors](https://www.openstreetmap.org/copyright).
See [data and capture credits](docs/credits.md).

[Development and checks](docs/development.md) · [Changes](CHANGELOG.md)
