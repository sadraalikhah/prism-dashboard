const assert = require("assert")
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const paletteCode = fs.readFileSync(path.join(__dirname, "Palette.js"), "utf8")
const paletteApi = {}
vm.createContext(paletteApi)
vm.runInContext(paletteCode, paletteApi)

const size = 32
const pixels = new Uint8ClampedArray(size * size * 4)
for (let y = 0; y < size; y++) {
  for (let x = 0; x < size; x++) {
    const offset = (y * size + x) * 4
    const sample = x < 23 ? [39, 53, 79] : [177, 132, 66]
    pixels[offset] = sample[0]
    pixels[offset + 1] = sample[1]
    pixels[offset + 2] = sample[2]
    pixels[offset + 3] = 255
  }
}

const palette = paletteApi.extract(pixels, size, size)
const hue = paletteApi.rgbToHsl(palette.text.r, palette.text.g, palette.text.b).h
const backdrop = paletteApi.mix(palette.deep, palette.base, 0.4)
assert(hue >= 24 && hue <= 68, `expected the warm cover hue, got ${hue}`)
assert(paletteApi.contrast(palette.text, backdrop) >= 4.5, "text color must remain readable")
