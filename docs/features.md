# A tour of Prism

The dashboard captures show the real Quickshell plugin; the clock recording
uses the interactive design preview with simulated audio. The main image stays
**Poison Girl by HIM**; the feature demos use different song palettes.
The weather location is **Paris, France**.
[Capture details and credits](credits.md) describe the demo data.

## Color that follows the artwork

The cover sets the player's accent, sliders, hover states, and clock spectrum.
A shared sampler keeps them in step. A diagonal glow draws color through the
artwork, while darker shading keeps the title and controls readable.

This recording moves between HIM, The Weeknd, Billie Eilish, and Tame Impala.
The artwork, controls, and clock palette update together as the song changes.

![Artwork colors change with the song](media/dynamic-colors.gif)

[Watch the MP4 recording](media/dynamic-colors.mp4)

## A field of drifting dots

Small dots form moving clusters across the player. They drift from different
places instead of repeatedly starting at the center. The denser field gives
motion to the whole cover.

![Drifting dots across the cover](media/dots.gif)

[Watch the MP4 recording](media/dots.mp4)

## Soft waves behind the music

Broad waves move through the cover's colors. Dots and waves have separate
switches, so you can choose either effect or combine them.

![Soft waves over the album artwork](media/waves.gif)

[Watch the MP4 recording](media/waves.mp4)

## A liquid trail that catches up

The hover bubble follows a spring. It lags behind, accelerates toward your
cursor, overshoots, and settles back. Two trailing points stretch it into a
fluid shape rather than a rigid pointer highlight.

![The liquid hover bubble and its trail](media/liquid-hover.gif)

[Watch the MP4 recording](media/liquid-hover.mp4)

Music animations freeze and fade away when the selected player pauses.

## The clock becomes a visualizer

CAVA reads the PipeWire audio output and draws 22 bands behind the clock. Its
accent follows the cover. Audio energy also feeds the player's moving dots.
The clock remains usable if CAVA is missing.

Right-click the clock to cycle Omarchy's formats. Your choice survives a
restart. Vertical bars have their own stacked formats.

![Clock preview with bass pulses and pause/resume fade](media/clock.gif)

[Watch the MP4 recording](media/clock.mp4)

The clock recording uses the interactive design preview with simulated audio
to show bass pulses and the pause/resume fade at 1600 × 400 and 30 fps.
The installed plugin reads real audio through CAVA.

## A calendar beside your music

The calendar starts weeks on Monday, highlights today, and lets you move
between months. Weather stays current when you browse another month.

The player supports previous, play/pause, next, per-app volume, and seeking.
Unavailable controls are disabled. The source selector distinguishes media
sources and hides duplicate browser aggregates when their URLs match.

![Calendar navigation and capability-aware playback controls](media/playback.gif)

[Watch the MP4 recording](media/playback.mp4)

## Spotify likes that stay liked

An outline heart adds the displayed song to Liked Songs. A filled heart means
it is already saved. Clicking it leaves the song saved. The dashboard checks
the track identity and waits for Spotify to confirm the save.

Ads, episodes, local files, and unsupported content have no Spotify heart.
The optional Spicetify extension uses Spotify's existing login.

![The heart changes after Spotify confirms the save](media/spotify-like.gif)

[Watch the MP4 recording](media/spotify-like.mp4) ·
[Enable the Spotify heart](setup.md#spotify-heart)

The side menu exposes supported shuffle and repeat, plus an action to open the
player. Repeat cycles through Off, All, and Song.

![Supported playback options beside the transport controls](media/playback-options.png)

## Buttons that match the provider

Podcasts get back 15 seconds and forward 30 seconds when seeking is available.
Browser media gets a button to open its original page. These actions depend on
what the source reports through MPRIS.

![Podcast skip controls](media/podcast.png)

![Browser media with an open-page action](media/browser.png)

## Weather for the right place

Current temperature, conditions, feels-like temperature, daily range, and
upcoming hours sit beneath the calendar. The layout leaves room for a large
weather icon without making the panel taller.

![Paris weather beneath the calendar](media/weather.png)

Choose Celsius or Fahrenheit in settings. A refresh button requests new data.
Failed updates retain the last successful forecast and mark it as stale.

## Choose a city with confidence

Search a city or postal code. Add a country to narrow it down. Results show
region and country so you can choose the correct place, and the picker saves
confirmed coordinates. Local scripts are supported where Photon has coverage.
The location is shared with Omarchy's weather settings.

![Paris search results with region and country](media/location.png)

[Watch the location-picker recording](media/location.mp4)

## Simple switches, immediate results

The gear beside the month arrows opens a scrolling settings pane. The music
card stays visible so you can see what each switch changes.

![Settings alongside the live player](media/settings.gif)

[Watch the MP4 recording](media/settings.mp4)

The switches control dynamic music cover colors, dots, waves, and the clock
visualizer. Weather units and location are here too. Reset appearance restores
the visual defaults and keeps your clock formats and weather preferences.
