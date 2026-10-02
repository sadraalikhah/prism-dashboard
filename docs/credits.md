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

The user selected [Poison Girl by HIM](https://open.spotify.com/track/1wfDvLRSQVFEWC7nfE6C4L)
for the gallery. The Razorblade Romance artwork comes from Spotify's artwork
CDN. Song and album artwork belong to their respective rights holders; they
are not relicensed under the project's MIT license. No song audio is included.

The captures record the real Prism Dashboard QML scene in Quickshell, with
private MPRIS demo metadata. Paris is a demonstration location and does not
identify the user's location. The weather and search displays use cached
public API responses for Paris. Podcast and browser examples use controlled
capabilities with the same selected song artwork.

The Spotify save demonstration uses a fake extension, so it changes no real
library. The clock clip uses deterministic demo band levels in the real clock
renderer; the installed plugin uses CAVA and PipeWire. The hover recording
feeds a repeatable cursor path through the same spring and trail code used by
normal pointer movement.

`media/capture-info.json` records the capture method. The reproduction tool is
[`tools/capture-demo.py`](../tools/capture-demo.py).
