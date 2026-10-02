// Album-art palette extraction and color math for the player card.
//
// Pure JavaScript (no QML globals) so the algorithm can be unit-tested with
// node and shared between components. Colors are plain { r, g, b } objects
// with channels in 0..1. `css()` turns one into an rgba() string for Canvas
// painting; QML callers wrap one with Qt.rgba().
//
// `extract()` takes the RGBA byte array of a small (32x32) downsample of the
// cover and builds the layered palette the player background is made of.
// It returns null when the buffer holds no drawable pixels yet — the caller
// is expected to sample again a beat later (a decoded Image is not always
// texture-backed the moment it reports Ready):
//
//   base      dominant dark color — the card's root fill
//   deep      near-black variant of base for scrims and the vignette
//   primary   vibrant hue with the most chromatic mass in the cover
//   secondary second vibrant hue (or a tonal variant of primary when the
//             cover lives on a single hue)
//   light     lighter accent sampled from the cover's bright areas
//   accent    control accent, contrast-guaranteed against the final
//             background (never blindly "the most saturated color")
//
// The vibrant entries carry a `focus` point (0..1 in cover space) so blooms
// can sit behind the part of the artwork that produced the color.

function clamp(v, lo, hi) {
  return v < lo ? lo : (v > hi ? hi : v)
}

function rgbToHsl(r, g, b) {
  var max = Math.max(r, g, b)
  var min = Math.min(r, g, b)
  var l = (max + min) / 2
  var h = 0
  var s = 0
  if (max !== min) {
    var d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    if (max === r) h = (g - b) / d + (g < b ? 6 : 0)
    else if (max === g) h = (b - r) / d + 2
    else h = (r - g) / d + 4
    h *= 60
  }
  return { h: h, s: s, l: l }
}

function hslToRgb(h, s, l) {
  var hp = (((h % 360) + 360) % 360) / 60
  var c = (1 - Math.abs(2 * l - 1)) * clamp(s, 0, 1)
  var x = c * (1 - Math.abs(hp % 2 - 1))
  var r = 0
  var g = 0
  var b = 0
  if (hp < 1) { r = c; g = x }
  else if (hp < 2) { r = x; g = c }
  else if (hp < 3) { g = c; b = x }
  else if (hp < 4) { g = x; b = c }
  else if (hp < 5) { r = x; b = c }
  else { r = c; b = x }
  var m = l - c / 2
  return { r: r + m, g: g + m, b: b + m }
}

function mix(a, b, t) {
  return {
    r: a.r + (b.r - a.r) * t,
    g: a.g + (b.g - a.g) * t,
    b: a.b + (b.b - a.b) * t,
  }
}

function lighten(c, t) {
  return mix(c, { r: 1, g: 1, b: 1 }, t)
}

function darken(c, t) {
  return mix(c, { r: 0, g: 0, b: 0 }, t)
}

// Shift a color's HSL channels into fixed bands — the workhorse for turning
// a sampled average into a role color ("vibrant primary", "light accent").
function tone(c, sMin, sMax, lMin, lMax) {
  var hsl = rgbToHsl(c.r, c.g, c.b)
  return hslToRgb(hsl.h, clamp(hsl.s, sMin, sMax), clamp(hsl.l, lMin, lMax))
}

function hueOf(c) {
  return rgbToHsl(c.r, c.g, c.b).h
}

function hueDistance(a, b) {
  var d = Math.abs(((a - b) % 360 + 360) % 360)
  return Math.min(d, 360 - d)
}

// WCAG relative luminance / contrast ratio. The accent gate uses these to
// keep sliders and transport icons readable over the ambient background.
function luminance(c) {
  function channel(v) {
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
  }
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
}

function contrast(a, b) {
  var la = luminance(a)
  var lb = luminance(b)
  var hi = Math.max(la, lb)
  var lo = Math.min(la, lb)
  return (hi + 0.05) / (lo + 0.05)
}

function css(c, alpha) {
  var a = (alpha === undefined || alpha === null) ? 1 : clamp(alpha, 0, 1)
  return "rgba(" + Math.round(clamp(c.r, 0, 1) * 255) + ","
    + Math.round(clamp(c.g, 0, 1) * 255) + ","
    + Math.round(clamp(c.b, 0, 1) * 255) + "," + a + ")"
}

// --------------------------------------------------------------- accents

// Minimum contrast for graphical controls (sliders, transport icons) against
// the reference background the controls sit on.
var ACCENT_CONTRAST = 3.0
// The accent must stay below this lightness so it reads as a color next to
// the near-white text instead of merging with it.
var ACCENT_L_MAX = 0.84

// The controls sit on the bottom scrim, which is `deep` laid over the
// ambient field. Blend both so contrast is checked against what the user
// actually sees behind a slider.
function controlBackdrop(p) {
  return mix(p.deep, mix(p.base, p.primary, 0.45), 0.35)
}

// Pick the control accent from the palette's vibrant colors: prefer the
// primary hue, fall back to the secondary and then the light accent. Each
// candidate is raised in lightness (and floor-saturated when washed out)
// until it clears ACCENT_CONTRAST against the backdrop.
function pickAccent(candidates, backdrop, sMin) {
  var chosen = null
  for (var i = 0; i < candidates.length; i++) {
    var c = candidates[i]
    if (!c) continue
    var hsl = rgbToHsl(c.r, c.g, c.b)
    var s = clamp(hsl.s, sMin, 0.9)
    for (var l = clamp(hsl.l, 0.5, 0.72); l <= ACCENT_L_MAX; l += 0.035) {
      var cand = hslToRgb(hsl.h, s, l)
      if (contrast(cand, backdrop) >= ACCENT_CONTRAST) {
        chosen = cand
        break
      }
    }
    if (chosen) break
  }
  if (!chosen) {
    // Nothing cleared the gate (very dark or very muddy palette): take the
    // brightest form of the primary hue instead of falling back to gray.
    var h = hueOf(candidates[0] || { r: 0.8, g: 0.8, b: 0.8 })
    chosen = hslToRgb(h, sMin, ACCENT_L_MAX)
  }
  return chosen
}

function readableTextColor(color, palette) {
  var hsl = rgbToHsl(color.r, color.g, color.b)
  var saturation = clamp(hsl.s, 0.18, 0.78)
  var backdrop = mix(palette.deep, palette.base, 0.4)
  for (var lightness = 0.62; lightness <= 0.82; lightness += 0.03) {
    var candidate = hslToRgb(hsl.h, saturation, lightness)
    if (contrast(candidate, backdrop) >= 4.5) return candidate
  }
  return hslToRgb(hsl.h, saturation, 0.82)
}

// ---------------------------------------------------------- extraction

var BIN_COUNT = 24
var VIBRANT_S_MIN = 0.18
var MONOCHROME_S_MAX = 0.13

function extract(data, width, height, opts) {
  var count = 0
  var sumS = 0
  var sumR = 0
  var sumG = 0
  var sumB = 0
  var darkN = 0
  var darkR = 0
  var darkG = 0
  var darkB = 0
  var lightN = 0
  var lightR = 0
  var lightG = 0
  var lightB = 0
  var bins = []
  for (var b = 0; b < BIN_COUNT; b++)
    bins.push({ weight: 0, r: 0, g: 0, b: 0, x: 0, y: 0, n: 0 })

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var i = (y * width + x) * 4
      if (data[i + 3] < 128) continue
      var r = data[i] / 255
      var g = data[i + 1] / 255
      var bl = data[i + 2] / 255
      var hsl = rgbToHsl(r, g, bl)

      count++
      sumS += hsl.s
      sumR += r
      sumG += g
      sumB += bl

      if (hsl.l <= 0.4) {
        // Weight the dominant-dark pool toward the darkest samples so the
        // card base tracks the cover's shadows, not its midtones.
        var dw = (1 - hsl.l) * (1 - hsl.l)
        darkN += dw
        darkR += r * dw
        darkG += g * dw
        darkB += bl * dw
      }

      if (hsl.s >= VIBRANT_S_MIN && hsl.l >= 0.1 && hsl.l <= 0.92) {
        // Chromatic mass = saturation squared, so a large muted area does
        // not outvote a small but genuinely vivid one.
        var w = hsl.s * hsl.s
        var idx = Math.floor(hsl.h / 360 * BIN_COUNT) % BIN_COUNT
        bins[idx].weight += w
        bins[idx].r += r * w
        bins[idx].g += g * w
        bins[idx].b += bl * w
        bins[idx].x += x / Math.max(1, width - 1)
        bins[idx].y += y / Math.max(1, height - 1)
        bins[idx].n++
      }

      if (hsl.l >= 0.55 && hsl.s >= 0.06) {
        var lw = hsl.l
        lightN += lw
        lightR += r * lw
        lightG += g * lw
        lightB += bl * lw
      }
    }
  }

  // No drawable pixels: the texture is not ready to sample yet (or the
  // artwork is fully transparent). Let the caller retry or fall back.
  if (count === 0) return null

  var mean = { r: sumR / count, g: sumG / count, b: sumB / count }
  var meanHsl = rgbToHsl(mean.r, mean.g, mean.b)

  var vibrantMass = 0
  for (var k = 0; k < BIN_COUNT; k++) vibrantMass += bins[k].weight
  var monochrome = (sumS / count) < MONOCHROME_S_MAX || vibrantMass < count * 0.02

  var sorted = bins.slice().sort(function (p, q) { return q.weight - p.weight })
  var primaryBin = sorted[0] && sorted[0].weight > 0 ? sorted[0] : null
  var secondaryBin = null
  if (primaryBin) {
    var primaryHue = hueOf({ r: primaryBin.r / primaryBin.weight, g: primaryBin.g / primaryBin.weight, b: primaryBin.b / primaryBin.weight })
    for (var s = 1; s < sorted.length; s++) {
      if (sorted[s].weight < primaryBin.weight * 0.15) break
      var hue = hueOf({ r: sorted[s].r / sorted[s].weight, g: sorted[s].g / sorted[s].weight, b: sorted[s].b / sorted[s].weight })
      if (hueDistance(hue, primaryHue) >= 45) {
        secondaryBin = sorted[s]
        break
      }
    }
  }

  function binColor(bin) {
    return { r: bin.r / bin.weight, g: bin.g / bin.weight, b: bin.b / bin.weight }
  }

  function binFocus(bin) {
    return { x: bin.n > 0 ? bin.x / bin.n : 0.5, y: bin.n > 0 ? bin.y / bin.n : 0.5 }
  }

  var warmBin = null
  var warmThreshold = Math.max(count * 0.008, vibrantMass * 0.04)
  for (var w = 0; w < sorted.length && sorted[w].weight >= warmThreshold; w++) {
    var warmHue = hueOf(binColor(sorted[w]))
    if (warmHue >= 24 && warmHue <= 68) {
      warmBin = sorted[w]
      break
    }
  }

  var palette = {}

  // Dominant dark: the cover's shadow color, pushed to a card-sized darkness
  // but keeping its hue so the base still belongs to the artwork.
  var dark = darkN > 0 ? { r: darkR / darkN, g: darkG / darkN, b: darkB / darkN } : mean
  var darkHsl = rgbToHsl(dark.r, dark.g, dark.b)
  palette.base = hslToRgb(darkHsl.h, clamp(darkHsl.s, 0.12, 0.5), clamp(darkHsl.l * 0.55, 0.04, 0.13))
  palette.deep = darken(palette.base, 0.55)

  if (monochrome) {
    // Controlled neutral gradient with a readable accent: keep the family
    // desaturated and let the accent carry a slight tint of whatever hue
    // the cover leans toward.
    palette.primary = hslToRgb(meanHsl.h, 0.1, 0.36)
    palette.secondary = hslToRgb(meanHsl.h, 0.08, 0.55)
    palette.light = hslToRgb(meanHsl.h, 0.1, 0.72)
    palette.primaryFocus = { x: 0.32, y: 0.3 }
    palette.secondaryFocus = { x: 0.75, y: 0.72 }
    palette.lightFocus = { x: 0.5, y: 0.12 }
    palette.monochrome = true
    palette.accent = pickAccent([palette.light, palette.secondary, palette.primary], controlBackdrop(palette), 0.14)
    palette.text = readableTextColor(palette.light, palette)
    return palette
  }

  if (primaryBin) {
    palette.primary = tone(binColor(primaryBin), 0.55, 0.9, 0.48, 0.66)
    palette.primaryFocus = binFocus(primaryBin)
  } else {
    palette.primary = tone(mean, 0.35, 0.8, 0.45, 0.62)
    palette.primaryFocus = { x: 0.5, y: 0.4 }
  }

  if (secondaryBin) {
    palette.secondary = tone(binColor(secondaryBin), 0.5, 0.85, 0.46, 0.7)
    palette.secondaryFocus = binFocus(secondaryBin)
  } else {
    // Single-hue cover: derive a tonal partner (lighter, calmer) instead of
    // inventing a hue the artwork does not have.
    var p = rgbToHsl(palette.primary.r, palette.primary.g, palette.primary.b)
    palette.secondary = hslToRgb(p.h, clamp(p.s * 0.8, 0.25, 0.7), clamp(p.l + 0.18, 0.5, 0.78))
    palette.secondaryFocus = { x: 0.78, y: 0.72 }
  }

  if (lightN > 0) {
    palette.light = tone({ r: lightR / lightN, g: lightG / lightN, b: lightB / lightN }, 0.2, 0.7, 0.6, 0.78)
  } else {
    var ph = rgbToHsl(palette.primary.r, palette.primary.g, palette.primary.b)
    palette.light = hslToRgb(ph.h, ph.s * 0.6, 0.72)
  }
  palette.lightFocus = { x: 0.5, y: 0.15 }

  palette.monochrome = false
  palette.accent = pickAccent([palette.primary, palette.secondary, palette.light], controlBackdrop(palette), 0.35)
  palette.text = readableTextColor(warmBin ? binColor(warmBin) : palette.secondary, palette)
  return palette
}

// Palette for the no-cover plate: built from the dashboard theme colors so
// the widget never drops back to an empty or broken visual area.
function themePalette(opts) {
  var tokens = opts || {}
  var accentToken = tokens.accent || { r: 0.79, g: 0.8, b: 0.8 }
  var background = tokens.background || { r: 0.063, g: 0.075, b: 0.083 }
  var foreground = tokens.foreground || { r: 0.79, g: 0.8, b: 0.8 }

  var palette = {}
  var bgHsl = rgbToHsl(background.r, background.g, background.b)
  var acHsl = rgbToHsl(accentToken.r, accentToken.g, accentToken.b)
  palette.base = hslToRgb(bgHsl.h, clamp(bgHsl.s, 0.05, 0.3), clamp(bgHsl.l, 0.04, 0.1))
  palette.deep = darken(palette.base, 0.55)
  palette.primary = hslToRgb(acHsl.h, clamp(acHsl.s, 0.2, 0.6), 0.34)
  palette.secondary = mix(darken(foreground, 0.45), palette.base, 0.35)
  palette.light = mix(lighten(foreground, 0.1), accentToken, 0.2)
  palette.primaryFocus = { x: 0.5, y: 0.42 }
  palette.secondaryFocus = { x: 0.8, y: 0.78 }
  palette.lightFocus = { x: 0.2, y: 0.16 }
  palette.monochrome = false
  palette.accent = pickAccent([accentToken, palette.light, palette.primary], controlBackdrop(palette), 0.2)
  palette.text = readableTextColor(accentToken, palette)
  return palette
}
