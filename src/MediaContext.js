function spotifyUri(player) {
  if (!player) return ""
  var metadata = player.metadata || {}
  var candidates = [metadata["xesam:url"], metadata["mpris:trackid"], player.uniqueId]
  for (var i = 0; i < candidates.length; i++) {
    var match = String(candidates[i] || "").match(/(?:spotify:|\/)(track|episode)(?::|\/)([A-Za-z0-9]{22})(?:$|[?\/])/)
    if (match) return "spotify:" + match[1] + ":" + match[2]
  }
  return ""
}
function pageUrl(player) {
  var url = String(player && player.metadata ? player.metadata["xesam:url"] || "" : "")
  return /^https?:\/\//i.test(url) ? url : ""
}
function isSpotify(player) { return !!player && /^org\.mpris\.MediaPlayer2\.spotify(?:\.|$)/i.test(String(player.dbusName || "")) }
function isBrowser(player) { return !!player && /chrome|firefox|chromium|brave|browser|zen/i.test(String(player.dbusName || "") + " " + String(player.desktopEntry || "")) }
function isPodcast(player) {
  return spotifyUri(player).indexOf("spotify:episode:") === 0
    || !!(player && player.metadata && player.metadata["xesam:contentType"] === "podcast")
}
