# Credits and data

## Project

Prism Dashboard is maintained by Sadra Alikhah and builds on
[cucu0628's Omarchy Dashboard](https://github.com/cucu0628/omarchy-dashboard).
The original copyright notice is retained. The source and documentation are
[MIT licensed](../LICENSE), except third-party material identified below.

## Weather and location search

Forecasts use [Open-Meteo](https://open-meteo.com/). Weather data is available
under [CC BY 4.0](https://open-meteo.com/en/licence). Its
[free API terms](https://open-meteo.com/en/terms) permit non-commercial use.
The widget includes an Open-Meteo attribution.

City search uses the public [Photon](https://github.com/komoot/photon) geocoder
and [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).
The location picker credits both. The demo caches retain their API fields and
coordinates for Paris only.

Forecast requests send the selected coordinates to Open-Meteo. City queries
are sent to Photon. This edition uses a confirmed location, rather than
IP-based guesses. The shared location file belongs to Omarchy's weather
settings.

## Spotify integration

The optional extension uses [Spicetify](https://spicetify.app/) in the desktop
Spotify client. Spotify's own login handles account access. A local bridge
connects it to Prism. It checks whether a song is saved and adds it only when
absent. It never removes saved songs.

## Screenshots and recordings

The main image stays **Poison Girl by HIM**, in the overview. Other
examples use different songs and covers to make the palette differences clear.
Artwork and track names come from Spotify's official oEmbed metadata and
artwork CDN. The fixture index records each source URL.

| Song | Artist | Album | Cover colors |
|---|---|---|---|
| [Poison Girl](https://open.spotify.com/track/1wfDvLRSQVFEWC7nfE6C4L) | HIM | Razorblade Romance | pink |
| [Starboy](https://open.spotify.com/track/7MXVkk9YMctZqd1Srtv4MB) | The Weeknd, Daft Punk | Starboy | red and blue |
| [COPYCAT](https://open.spotify.com/track/0JFtuc0AtYSMV2lXL1A5Ki) | Billie Eilish | dont smile at me | yellow and red |
| [Let It Happen](https://open.spotify.com/track/2X485T9Z5Ly0xyaghN73ed) | Tame Impala | Currents | violet |
| [Blinding Lights](https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b) | The Weeknd | After Hours | warm amber and brown |
| [Yellow](https://open.spotify.com/track/3AJwUDP919kvQ9QcozQPxg) | Coldplay | Parachutes | amber |
| [Feel Good Inc.](https://open.spotify.com/track/0d28khcov6AiegSCpG5TuT) | Gorillaz | Demon Days | green and coral |
| [Cruel Summer](https://open.spotify.com/track/1BxfuPKGuaTgP7aM0Bbdwr) | Taylor Swift | Lover | pastel blue and pink |
| [Summertime Sadness](https://open.spotify.com/track/5dUYmMxjCF7PY9CU4swHuJ) | Lana Del Rey | Born To Die | green and blue |

Song and album artwork belong to their respective rights holders; they are not
relicensed under the project's MIT license. No song audio is included.

The dashboard captures record the real Prism Dashboard QML scene in
Quickshell, with private MPRIS demo metadata. The clock clip records the
interactive HTML design preview with simulated audio at 1600 × 400 and 30 fps. Paris is a demonstration location and does not
identify the user's location. The weather and search displays use cached
public API responses for Paris. Podcast and browser examples use controlled
capabilities with the selected showcase artwork.

The README embeds GitHub-hosted video attachments as inline players with
playback controls. Canonical attachment URLs are recorded in
`media/video-attachments.json`; downloadable MP4s and looping GIFs remain in
`media/` for local use.

The Spotify save demonstration uses a fake extension, so it changes no real
library. The clock preview simulates audio energy, bass pulses and a pause/resume fade;
the installed plugin uses CAVA and PipeWire. The hover recording
feeds a repeatable cursor path through the same spring and trail code used by
normal pointer movement.

`media/capture-info.json` records the capture method. The reproduction tool is
[`tools/capture-demo.py`](../tools/capture-demo.py).
