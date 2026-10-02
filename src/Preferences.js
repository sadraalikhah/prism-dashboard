var controls = [
  { key: "dynamicCoverColors", label: "Dynamic music cover colors", type: "boolean", defaultValue: true, group: "Music" },
  { key: "displayDots", label: "Display dots animation", type: "boolean", defaultValue: true, group: "Music" },
  { key: "displayWaves", label: "Display waves animation", type: "boolean", defaultValue: true, group: "Music" },
  { key: "clockSpectrum", label: "Clock visualizer", type: "boolean", defaultValue: true, group: "Clock" },
  { key: "weatherUnit", label: "Weather units", type: "enum", defaultValue: "celsius", options: ["celsius", "fahrenheit"], group: "Weather" }
]

function spec(key) {
  for (var i = 0; i < controls.length; i++) if (controls[i].key === key) return controls[i]
  return null
}

function coerce(key, input) {
  var s = spec(key)
  if (!s) return undefined
  if (s.type === "boolean") return typeof input === "boolean" ? input : s.defaultValue
  return s.options.indexOf(input) >= 0 ? input : s.defaultValue
}

function value(settings, key) { return coerce(key, settings ? settings[key] : undefined) }

function updated(settings, key, input) {
  if (!spec(key)) return null
  var result = Object.assign({}, settings || {})
  result[key] = coerce(key, input)
  return result
}

function resetVisual(settings) {
  var result = Object.assign({}, settings || {})
  for (var i = 0; i < controls.length; i++) {
    var s = controls[i]
    if (s.group !== "Weather") delete result[s.key]
  }
  return result
}
