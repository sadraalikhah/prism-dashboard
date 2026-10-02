import QtQuick
import Quickshell.Io

Item {
  id: root
  property bool active: false
  property var state: ({})
  property bool connected: false
  property bool busy: false
  property string error: ""
  property int requestId: 0
  signal saved(string uri)
  signal saveFailed(string message)
  function like(uri) {
    if (!connected || busy || state.uri !== uri || !state.canLike || state.liked) return
    busy = true
    error = ""
    process.write(JSON.stringify({action:"like", uri:uri, id:++requestId}) + "\n")
    timeout.restart()
  }
  function clear() { connected = false; state = {}; busy = false; timeout.stop() }
  onActiveChanged: if (!active) clear()
  Process {
    id: process
    running: root.active
    command: ["python3", Qt.resolvedUrl("spotify_bridge.py").toString().replace("file://", "")]
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var message = JSON.parse(line)
          if (message.type === "connected") { root.connected = true; root.error = "" }
          else if (message.type === "disconnected") root.clear()
          else if (message.type === "state") root.state = message
          else if (message.type === "result" && message.id === root.requestId) {
            root.busy = false; timeout.stop()
            root.error = message.ok ? "" : message.error
            if (message.ok) root.saved(message.uri)
            else root.saveFailed(root.error)
          } else if (message.type === "error") root.error = message.error
        } catch (e) { root.error = "Invalid Spotify bridge response" }
      }
    }
    stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn("Spotify actions:", text.trim()) }
    onExited: root.clear()
  }
  Timer { id: timeout; interval: 10000; onTriggered: { root.busy = false; root.error = "Spotify did not respond"; root.saveFailed(root.error) } }
}
