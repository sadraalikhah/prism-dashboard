# Changes

## Prism Dashboard 1.0.0, 2026-10-02

This edition adds local weather, artwork-driven colors and motion, a clock
spectrum, simple settings, and provider-aware music controls. It retains the
original authorship credits. The first public release uses the independent
plugin ID `io.github.sadraalikhah.prism-dashboard`.

### Focused commit history

- `ac762e77` feat(media): add full-card artwork, cover palettes, and source selection
- `cbdadd2a` feat(weather): add forecasts and multilingual location selection
- `e6e82f4d` style(weather): arrange conditions and hourly forecasts without growing the card
- `f94ba498` fix(media): stabilize seeking, source labels, and artwork color updates
- `760879c3` feat(animation): add a spring-driven hover bubble with a liquid trail
- `515f22ec` style(animation): slow bubble tracking and let it catch up naturally
- `1e608b3a` feat(clock): cycle persistent clock formats on right click
- `b871b979` feat(clock): add a CAVA spectrum behind the clock
- `f7fd2a39` fix(colors): share one artwork palette between clock and dashboard
- `c2a337ea` feat(animation): add drifting ambient bubbles and audio-reactive motion
- `610525d2` style(animation): fill the player with a denser drifting dot field
- `63635ccd` feat(settings): add persistent appearance toggles and weather preferences
- `8288cf65` fix(settings): keep controls clear of the scrolling pane border
- `645961bb` style(media): add diagonal cover-colored glow and readable text shading
- `98862f3e` style(sliders): tint thumb outlines from the current cover accent
- `0256c671` feat(media): add provider-aware actions and confirmed Spotify likes

- `690c2b3` chore: name the edition Prism Dashboard and credit its authors
- `ea04b40` test: package reproducible dashboard interaction checks

The documentation commit adds the feature gallery, setup and development
guides, credits, screenshots, recordings, and reproducible capture tools.
