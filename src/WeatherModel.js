function numeric(value) {
  return typeof value === "number" && isFinite(value)
}

function location(raw) {
  var value = typeof raw === "string" ? JSON.parse(raw || "{}") : raw
  if (!value || typeof value !== "object") throw new Error("Invalid location")
  var name = typeof value.name === "string" ? value.name.trim() : ""
  var valid = numeric(value.latitude) && numeric(value.longitude)
    && Math.abs(value.latitude) <= 90 && Math.abs(value.longitude) <= 180
  return { name: name, latitude: valid ? value.latitude : null, longitude: valid ? value.longitude : null }
}

function locationKey(value) {
  return value.latitude === null ? "" : value.latitude + "," + value.longitude
}

function searchResults(raw) {
  var data = JSON.parse(raw)
  if (data.error) throw new Error("Location search is unavailable")
  if (!Array.isArray(data.features)) throw new Error("Invalid location results")
  var values = data.features.filter(function(feature) {
    return feature && feature.properties && feature.geometry
      && feature.geometry.type === "Point" && Array.isArray(feature.geometry.coordinates)
  }).map(function(feature) {
    var props = feature.properties
    return { name: props.name || props.city || props.postcode,
      admin1: props.state || props.county, country: props.country || props.countrycode,
      latitude: feature.geometry.coordinates[1], longitude: feature.geometry.coordinates[0] }
  })
  return values.filter(function(value) {
    return value && typeof value.name === "string" && value.name.trim()
      && numeric(value.latitude) && Math.abs(value.latitude) <= 90
      && numeric(value.longitude) && Math.abs(value.longitude) <= 180
  }).map(function(value) {
    var parts = [value.name, value.admin1, value.country || value.country_code]
      .filter(function(part, index, source) { return part && source.indexOf(part) === index })
    return { name: value.name, description: parts.slice(1).join(", "),
      label: parts.join(", "), latitude: value.latitude, longitude: value.longitude,
      timezone: value.timezone || "" }
  })
}

function forecastUrl(value, unit) {
  return "https://api.open-meteo.com/v1/forecast?latitude=" + value.latitude
    + "&longitude=" + value.longitude
    + "&current=temperature_2m,apparent_temperature,weather_code,is_day"
    + "&hourly=temperature_2m,weather_code,is_day"
    + "&daily=temperature_2m_max,temperature_2m_min"
    + "&forecast_days=2&timezone=auto&temperature_unit=" + unit
}

function parseForecast(raw) {
  var value = JSON.parse(raw)
  if (value.error || !value.current || !numeric(value.current.temperature_2m)
      || !numeric(value.current.weather_code) || !numeric(value.utc_offset_seconds)
      || !value.hourly || !Array.isArray(value.hourly.time)
      || !Array.isArray(value.hourly.temperature_2m) || !Array.isArray(value.hourly.weather_code))
    throw new Error("Weather service returned incomplete data")
  return value
}

function localTime(now, offset) {
  return new Date(now + offset * 1000).toISOString().slice(0, 16)
}

function hours(report, now) {
  if (!report) return []
  var after = localTime(now, report.utc_offset_seconds)
  var out = []
  var nextIndex = 0
  for (var i = 0; i < report.hourly.time.length && out.length < 3; i++) {
    var time = report.hourly.time[i]
    if (typeof time !== "string" || time <= after || i < nextIndex
        || !numeric(report.hourly.temperature_2m[i]) || !numeric(report.hourly.weather_code[i])) continue
    out.push({ time: time.slice(11, 16), date: time.slice(0, 10),
      temperature: report.hourly.temperature_2m[i], code: report.hourly.weather_code[i],
      night: report.hourly.is_day && report.hourly.is_day[i] === 0 })
    nextIndex = i + 3
  }
  return out
}

function range(report, now) {
  if (!report || !report.daily || !Array.isArray(report.daily.time)) return { high: null, low: null }
  var index = report.daily.time.indexOf(localTime(now, report.utc_offset_seconds).slice(0, 10))
  return { high: index >= 0 && report.daily.temperature_2m_max ? report.daily.temperature_2m_max[index] : null,
    low: index >= 0 && report.daily.temperature_2m_min ? report.daily.temperature_2m_min[index] : null }
}

function temperature(value) { return numeric(value) ? Math.round(value) + "°" : "—" }

function conditions(code, night) {
  if (code === 0) return { text: night ? "Clear night" : "Clear sky", icon: night ? "" : "" }
  if (code === 1 || code === 2) return { text: "Partly cloudy", icon: night ? "" : "" }
  if (code === 3) return { text: "Overcast", icon: "" }
  if (code === 45 || code === 48) return { text: "Fog", icon: "" }
  if ([51, 53, 55, 56, 57].indexOf(code) !== -1) return { text: "Drizzle", icon: "" }
  if ([61, 63, 65, 66, 67, 80, 81, 82].indexOf(code) !== -1) return { text: "Rain", icon: "" }
  if ([71, 73, 75, 77, 85, 86].indexOf(code) !== -1) return { text: "Snow", icon: "" }
  if ([95, 96, 99].indexOf(code) !== -1) return { text: "Thunderstorm", icon: "" }
  return { text: "Unknown conditions", icon: "󰖐" }
}

if (typeof module !== "undefined") module.exports = {
  location: location, locationKey: locationKey, searchResults: searchResults,
  forecastUrl: forecastUrl, parseForecast: parseForecast, localTime: localTime,
  hours: hours, range: range, temperature: temperature, conditions: conditions
}
