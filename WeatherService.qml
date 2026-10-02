import QtQuick
import Quickshell
import Quickshell.Io
import "WeatherModel.js" as WeatherModel

Item {
  id: root
  property bool active: false
  property string unit: "celsius"
  property string locationPath: (Quickshell.env("HOME") || "") + "/.local/state/omarchy/settings/weather.json"
  property string locationSaveProgram: "omarchy-weather-location"
  property var location: ({ name: "", latitude: null, longitude: null })
  readonly property string locationKey: WeatherModel.locationKey(location)
  property var report: null
  property double receivedAt: 0
  property double now: Date.now()
  property string error: ""
  readonly property bool loading: forecastProc.running
  readonly property bool stale: !!report && (error !== "" || now - receivedAt > 30 * 60 * 1000)
  property string requestKey: ""
  property string searchText: ""
  property var suggestions: []
  property string searchError: ""
  property string activeQuery: ""
  readonly property bool searching: searchDelay.running || searchProc.running
  readonly property bool saving: saveProc.running
  signal locationSaved()

  function refresh(force) {
    now = Date.now()
    if (!active || !locationKey || forecastProc.running) return
    if (!force && report && now - receivedAt < 15 * 60 * 1000) return
    requestKey = locationKey + "|" + unit
    forecastProc.command = ["curl", "-fsS", "--connect-timeout", "5", "--max-time", "12",
      WeatherModel.forecastUrl(location, unit)]
    forecastProc.running = true
  }

  function resetForecast() {
    requestKey = ""
    forecastProc.running = false
    report = null
    receivedAt = 0
    error = ""
    Qt.callLater(function() { root.refresh(false) })
  }

  function saveLocation(choice) {
    if (saving) return
    saveProc.command = [root.locationSaveProgram, "--set", choice.label,
      choice.latitude + "," + choice.longitude]
    saveProc.running = true
  }

  function cancelSearch() {
    searchText = ""
    searchDelay.stop()
    searchProc.running = false
    suggestions = []
    searchError = ""
  }

  onLocationKeyChanged: resetForecast()
  onUnitChanged: resetForecast()
  onActiveChanged: if (active) { locationFile.reload(); refresh(false) }
  onSearchTextChanged: {
    searchDelay.stop()
    activeQuery = ""
    searchProc.running = false
    suggestions = []
    searchError = ""
    if (searchText.trim().length >= 2) searchDelay.restart()
  }

  FileView {
    id: locationFile
    path: root.locationPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.location = WeatherModel.location(text()) }
      catch (e) { root.location = { name: "", latitude: null, longitude: null } }
    }
    onLoadFailed: root.location = { name: "", latitude: null, longitude: null }
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.active
    onTriggered: { root.now = Date.now(); root.refresh(false) }
  }

  Process {
    id: forecastProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!root.requestKey || root.requestKey !== root.locationKey + "|" + root.unit) return
        try {
          root.report = WeatherModel.parseForecast(text)
          root.receivedAt = Date.now()
          root.now = root.receivedAt
          root.error = ""
        } catch (e) {
          root.error = "Couldn't update weather. Check your connection and retry."
        }
      }
    }
    stderr: StdioCollector {}
  }

  Timer {
    id: searchDelay
    interval: 700
    onTriggered: {
      root.activeQuery = root.searchText.trim()
      searchProc.command = ["curl", "-fsS", "--connect-timeout", "5", "--max-time", "12",
        "https://photon.komoot.io/api/?q=" + encodeURIComponent(root.activeQuery)
        + "&limit=8&lang=en"]
      searchProc.running = true
    }
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!root.activeQuery || root.activeQuery !== root.searchText.trim()) return
        try {
          root.suggestions = WeatherModel.searchResults(text)
          root.searchError = root.suggestions.length ? "" : "No matches. Try another spelling or add the country."
        } catch (e) {
          root.searchError = "Couldn't search locations. Check your connection and try again."
        }
      }
    }
    stderr: StdioCollector {}
  }

  Process {
    id: saveProc
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code === 0) { locationFile.reload(); root.locationSaved() }
      else root.searchError = "Couldn't save this location. Please try again."
    }
  }
}
