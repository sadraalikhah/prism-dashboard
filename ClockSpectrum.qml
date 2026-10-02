import QtQuick
import Quickshell.Io

Item {
  id: root
  property bool active: false
  property bool showBars: true
  property color accent: "transparent"
  property color ink: "transparent"
  property var levels: []
  property bool available: false
  property bool failed: false
  property string error: ""
  property int frames: 0
  readonly property int bands: 22
  readonly property string config: [
    "[general]", "bars = 22", "framerate = 60", "autosens = 1",
    "[input]", "method = pipewire", "source = auto",
    "[output]", "method = raw", "raw_target = /dev/stdout",
    "data_format = ascii", "ascii_max_range = 100", "channels = mono",
    "bar_delimiter = 59", "frame_delimiter = 10",
    "[smoothing]", "noise_reduction = 70", ""
  ].join("\n")

  opacity: showBars && active && available && !failed ? 0.48 : 0
  visible: opacity > 0
  clip: true
  Behavior on opacity { NumberAnimation { duration: 120 } }

  function status() {
    return JSON.stringify({ active: active, available: available, running: cava.running,
      failed: failed, error: error, frames: frames, levels: levels, opacity: opacity })
  }

  onActiveChanged: {
    if (active) { clear.stop(); levels = []; failed = false; error = "" }
    else clear.restart()
  }
  onLevelsChanged: canvas.requestPaint()
  onAccentChanged: canvas.requestPaint()
  onInkChanged: canvas.requestPaint()

  Timer { id: clear; interval: 130; onTriggered: root.levels = [] }
  Process {
    command: ["sh", "-c", "command -v cava >/dev/null 2>&1"]
    running: true
    onExited: function(code) { root.available = code === 0 }
  }
  Process {
    id: cava
    command: ["bash", "-c", "exec cava -p <(printf '%s' \"$1\")", "_", root.config]
    running: root.active && root.available && !root.failed
    stdout: SplitParser {
      onRead: function(line) {
        var parts = line.split(";")
        if (parts.length < root.bands) return
        var next = []
        for (var i = 0; i < root.bands; i++) {
          var n = Number(parts[i])
          if (!isFinite(n)) return
          next.push(Math.max(0, Math.min(1, n / 100)))
        }
        root.levels = next
        root.frames++
      }
    }
    stderr: StdioCollector { onStreamFinished: root.error = text.trim() }
    onExited: function(code) {
      if (root.active && code !== 0) {
        root.failed = true
        root.levels = []
        console.warn("Dashboard clock spectrum: CAVA exited", code, root.error)
      }
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var gradient = ctx.createLinearGradient(0, height, 0, 0)
      gradient.addColorStop(0, String(root.accent))
      gradient.addColorStop(1, String(root.ink))
      ctx.fillStyle = gradient
      var step = width / root.bands
      for (var i = 0; i < root.levels.length; i++) {
        var h = Math.round(root.levels[i] * (height - 2))
        for (var y = height - 3; y >= height - h; y -= 4)
          ctx.fillRect(i * step, y, Math.max(1, step - 1.5), 3)
      }
    }
  }
}
