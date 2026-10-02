import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Preferences.js" as Prefs

BarWidget {
  id: root
  moduleName: "cucu0628.dashboard"

  property date displayDate: clock.date
  readonly property var paletteSource: clockPalette.item
  readonly property real bassEnergy: {
    if (!spectrum.active || !spectrum.levels.length) return 0
    var sum = 0, count = Math.min(6, spectrum.levels.length)
    for (var i = 0; i < count; i++) sum += spectrum.levels[i]
    return sum / count
  }
  readonly property string configuredFormat: vertical
    ? setting("verticalFormat", "HH\n—\nmm")
    : setting("format", "dddd HH:mm")
  readonly property string configuredAltFormat: vertical
    ? setting("verticalFormatAlt", "dd\nMMM\n'W'ww\n''yy")
    : setting("formatAlt", "d MMMM 'W'ww yyyy")
  readonly property var formatRing: Model.clockFormatRing(configuredFormat, configuredAltFormat, Model.clockFormats(vertical))
  readonly property string activeFormat: configuredFormat
  readonly property string displayText: Qt.formatDateTime(displayDate,
    activeFormat.replace(/ww/g, Model.isoWeekLiteral(displayDate.getFullYear(), displayDate.getMonth(), displayDate.getDate())))
  readonly property var verticalLines: displayText.split("\n")
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: root.verticalLines.length * Style.bar.iconSlot
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function cycleFormat() {
    var next = Model.nextClockFormat(formatRing, String(configuredFormat))
    if (next === "" || next === configuredFormat) return
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry[vertical ? "verticalFormat" : "format"] = next
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function applyPreferences(entry, persist) {
    entry.id = root.moduleName
    root.settings = entry
    if (persist && root.bar && root.bar.shell)
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }
  function setPreference(key, value) {
    var entry = Prefs.updated(root.settings, key, value)
    if (entry) applyPreferences(entry, true)
  }
  function resetVisualSettings() { applyPreferences(Prefs.resetVisual(root.settings), true) }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.displayDate = date
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "cucu0628.dashboard"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function cycleFormat(): void { root.cycleFormat() }
    function editWeather(): void { root.open(); if (panelLoader.item) panelLoader.item.editWeatherLocation() }
    function refreshWeather(): void { if (panelLoader.item) panelLoader.item.refreshWeather() }
    function musicStatus(): string { return panelLoader.item ? panelLoader.item.musicStatus() : "{}" }
    function animationStatus(): string { return panelLoader.item ? panelLoader.item.animationStatus() : "{}" }
    function openSettings(): void { root.open(); if (panelLoader.item) panelLoader.item.editSettings() }
    function settingsStatus(): string { return JSON.stringify(root.settings) }
    function spectrumStatus(): string {
      var state = JSON.parse(spectrum.status())
      state.accent = String(spectrum.accent)
      state.paletteKey = clockPalette.item ? clockPalette.item.sampledKey : ""
      return JSON.stringify(state)
    }
    function weatherStatus(): string { return panelLoader.item ? panelLoader.item.weatherStatus() : "{}" }
  }

  // Attach the existing artwork sampler to the bar's scene so colors are
  // ready even before the dashboard's popup has been opened.
  Loader {
    id: clockPalette
    visible: false
    active: true
    sourceComponent: Component {
      CoverStage {
        width: 32
        height: 32
        coverUrl: panelLoader.item ? panelLoader.item.coverArt : ""
        hasTrack: !!panelLoader.item && !!panelLoader.item.player
        dynamicColors: Prefs.value(root.settings, "dynamicCoverColors")
        playing: false
      }
    }
  }

  ClockSpectrum {
    id: spectrum
    anchors.fill: parent
    anchors.leftMargin: 3
    anchors.rightMargin: 3
    showBars: Prefs.value(root.settings, "clockSpectrum")
    active: (showBars || (root.opened && Prefs.value(root.settings, "displayDots"))) && root.visible && !!panelLoader.item
      && !!panelLoader.item.player && panelLoader.item.player.isPlaying
    accent: clockPalette.item ? clockPalette.item.accent : Color.accent
    ink: button.foreground
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.displayText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.cycleFormat()
      else if (mouseButton === Qt.LeftButton) root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3 ? button.fontSize * 0.9 : button.fontSize
          color: button.foreground
        }
      }
    }
  }
}
