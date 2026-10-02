import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "cucu0628.dashboard"
  ipcTarget: "cucu0628.dashboard"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property date today: new Date()
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  property real sampledPosition: 0
  property string selectedPlayerKey: ""

  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var sourcePlayers: {
    var direct = []
    for (var i = 0; i < players.length; i++) {
      var candidate = players[i]
      if (candidate && String(candidate.dbusName || "").toLowerCase().indexOf("playerctld") === -1)
        direct.push(candidate)
    }
    // Per-tab MPRIS bridges (browser-mpris2) expose every media tab as its own
    // player. When those are active, the browsers' own merged players — zen/
    // firefox native and the plasma bridge — only duplicate one of those tabs,
    // so hide them.
    var hasPerTab = direct.some(function(p) {
      return /^org\.mpris\.MediaPlayer2\.chrome(\.tab\d+)?$/.test(String(p.dbusName || ""))
    })
    if (hasPerTab) {
      direct = direct.filter(function(p) {
        return !/^org\.mpris\.MediaPlayer2\.(firefox|plasma-browser-integration)/.test(String(p.dbusName || ""))
      })
    }
    return direct.length > 0 ? direct : players
  }
  readonly property var player: {
    for (var i = 0; i < sourcePlayers.length; i++)
      if (playerKey(sourcePlayers[i]) === selectedPlayerKey) return sourcePlayers[i]
    for (var j = 0; j < sourcePlayers.length; j++)
      if (sourcePlayers[j] && sourcePlayers[j].isPlaying) return sourcePlayers[j]
    return sourcePlayers.length > 0 ? sourcePlayers[0] : null
  }
  readonly property var sourceOptions: {
    // Instances of one app (see playerBaseKey) would otherwise render as
    // identical "Zen / Zen" entries. Track how many instances each app has so
    // the labels below can be disambiguated.
    var counts = {}
    var titleSets = {}
    for (var i = 0; i < sourcePlayers.length; i++) {
      var source = sourcePlayers[i]
      var key = playerBaseKey(source)
      counts[key] = (counts[key] || 0) + 1
      if (titleSets[key] === undefined) titleSets[key] = []
      titleSets[key].push(String(source.trackTitle || "").trim())
    }

    var options = []
    var indexes = {}
    for (var j = 0; j < sourcePlayers.length; j++) {
      var player = sourcePlayers[j]
      var baseKey = playerBaseKey(player)
      var nth = indexes[baseKey] = (indexes[baseKey] || 0) + 1
      var label = playerLabel(player)
      var title = String(player.trackTitle || "").trim()
      if (counts[baseKey] > 1) {
        var titles = titleSets[baseKey]
        var titlesUsable = true
        for (var k = 0; k < titles.length; k++) {
          if (titles[k] === "" || titles.indexOf(titles[k]) !== k) { titlesUsable = false; break }
        }
        // Several instances of this app: prefer the track title — it tells
        // which instance is playing what. When titles are missing or collide,
        // number the instances instead.
        if (titlesUsable) label += " — " + title
        else label += " #" + nth
      } else if (sourcePlayers.length > 1 && title !== "") {
        // Browsers expose ONE MPRIS player for all their tabs and just swap
        // its metadata to whichever tab is currently dominant, so two playing
        // tabs still show up here as a single entry. Surface the live track
        // title so it's obvious which media this entry points at.
        label += " — " + title
      }
      options.push({ value: playerKey(player), label: label })
    }
    return options
  }
  readonly property real appVolume: player && player.volumeSupported ? player.volume : 0
  readonly property string trackIdentity: playerKey(player) + "|"
    + (player ? String(player.trackTitle || "") + "|" + String(player.trackArtist || "")
      + "|" + String(player.trackAlbum || "") + "|" + String(player.trackArtUrl || "") : "")
  // Length is latched below: browser MPRIS (Zen/Firefox) briefly reports zero
  // length mid-seek, which used to disable the slider mid-drag and corrupt its
  // range. A stale value is only replaced by a positive one.
  property real cachedLength: 0
  readonly property real trackLength: player && player.lengthSupported && player.length > 0 ? player.length : cachedLength
  readonly property bool seekAvailable: player && player.canSeek && player.positionSupported && trackLength > 0
  readonly property real trackPosition: seekAvailable ? Math.max(0, Math.min(sampledPosition, trackLength)) : 0
  readonly property var calendarCells: Model.monthCells(viewYear, viewMonth, today)
  readonly property url coverArt: {
    var activePlayer = root.player
    if (!activePlayer) return ""
    if (activePlayer.trackArtUrl) return activePlayer.trackArtUrl

    var metadata = activePlayer.metadata || ({})
    var mediaUrl = String(metadata["xesam:url"] || "")
    var match = mediaUrl.match(/(?:[?&]v=|youtu\.be\/|youtube\.com\/(?:shorts|embed)\/)([A-Za-z0-9_-]{11})/)
    return match ? "https://i.ytimg.com/vi/" + match[1] + "/hqdefault.jpg" : ""
  }
  readonly property color playerInk: Qt.rgba(1, 1, 1, 0.97)
  readonly property color playerInkMuted: Qt.rgba(1, 1, 1, 0.82)
  // Album-derived control accent (extracted with the background palette —
  // see CoverStage.qml / Palette.js). Contrast-guaranteed against the
  // ambient background the controls sit on.
  readonly property color playerAccent: coverStage.accent
  readonly property color playerMetadataInk: playerInk
  // Localized dark overlay behind text: the near-black variant of the
  // album-derived base.
  function scrim(alpha) {
    return Qt.rgba(coverStage.deep.r, coverStage.deep.g, coverStage.deep.b, alpha)
  }

  onTrackIdentityChanged: {
    root.cachedLength = root.player && root.player.lengthSupported && root.player.length > 0
      ? root.player.length : 0
    root.sampledPosition = root.player && root.player.positionSupported ? root.player.position : 0
    seekSettle.stop()
  }

  function open() {
    today = new Date()
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
    controller.show()
    // The cover may have loaded while the panel was closed — its palette
    // could not be sampled before the content reached the scene graph.
    coverStage.wake()
  }

  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  function moveMonth(delta) {
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    viewYear = next.year
    viewMonth = next.month
  }

  function mediaAction(action) {
    if (!player) return
    if (action === "previous" && player.canGoPrevious) player.previous()
    else if (action === "next" && player.canGoNext) player.next()
    else if (action === "playPause") {
      if (player.isPlaying && player.canPause) player.pause()
      else if (!player.isPlaying && player.canPlay) player.play()
      else if (player.canTogglePlaying) player.togglePlaying()
    }
  }

  function playerKey(source) {
    if (!source) return ""
    return String(source.dbusName || source.desktopEntry || source.identity || "")
  }

  // One app can expose several MPRIS instances (two browser windows playing
  // videos, several mpv processes). They share identity/desktopEntry but each
  // registers its own bus name with an ".instance" suffix, so strip that to
  // group instances of the same app together. Also handle ".tab<N>" suffixes,
  // which per-tab MPRIS bridges (browser-mpris2) append per media tab.
  function playerBaseKey(source) {
    if (!source) return ""
    var name = String(source.dbusName || "")
    if (name !== "") return name.split(".instance")[0].replace(/\.tab\d+$/, "")
    return String(source.desktopEntry || source.identity || "")
  }

  function playerLabel(source) {
    if (!source) return "Media source"
    return String(source.identity || source.desktopEntry || "Media source")
  }

  function selectPlayer(key) {
    selectedPlayerKey = String(key || "")
  }

  function seekTo(value) {
    if (!seekAvailable || !player) return
    // Clamp against trackLength (the latched length), not player.length:
    // quickshell's length getter falls back to the *current position* when a
    // player doesn't expose mpris:length, which used to clamp every forward
    // seek back down to where playback already was.
    var target = Math.max(0, Math.min(Number(value), trackLength))
    if (!isFinite(target)) return
    sampledPosition = target
    player.position = target
    seekSettle.restart()
  }

  function setAppVolume(value) {
    if (!player || !player.volumeSupported) return
    player.volume = Math.max(0, Math.min(1, Number(value)))
  }

  function formatDuration(seconds) {
    var value = Math.max(0, Math.floor(Number(seconds) || 0))
    var minutes = Math.floor(value / 60)
    var remainder = value % 60
    return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
  }

  component LabelText: Text {
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  component MutedText: Text {
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component Card: BorderSurface {
    color: Style.normalFillFor(root.foreground, Color.accent)
    borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
    radius: Style.cornerRadius
    padding: Style.space(14)
  }

  Timer {
    id: seekSettle
    interval: 700
    onTriggered: {
      if (root.player && root.player.positionSupported)
        root.sampledPosition = root.player.position
    }
  }

  Timer {
    interval: 500
    running: root.opened && root.player && root.player.positionSupported
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.player && root.player.lengthSupported && root.player.length > 0)
        root.cachedLength = root.player.length
      if (!overviewSeekSlider.dragging && !seekSettle.running && root.player)
        root.sampledPosition = root.player.position
    }
  }

  SystemClock {
    precision: SystemClock.Minutes
    onDateChanged: root.today = date
  }

  KeyboardPanel {
    id: dashboardPanel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    // 690 = calendar (380) + gap (14) + player card (296) — the player card
    // keeps its original width now that the calendar is narrower.
    contentWidth: dashboardPanel.fittedContentWidth(Style.space(690))
    // 452 = the player card height with the enlarged album art (was 411);
    // the calendar card keeps its content and just gets more room.
    contentHeight: dashboardPanel.fittedContentHeight(Style.space(452))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        anchors.fill: parent

        Item {
          width: parent.width
          height: parent.height

          Column {
            anchors.fill: parent
            spacing: Style.space(14)

            Row {
              width: parent.width
              height: parent.height
              spacing: Style.space(14)

              Card {
                width: Style.space(380)
                height: parent.height

                Column {
                  anchors.fill: parent
                  anchors.margins: parent.contentLeftInset
                  spacing: Style.space(7)

                  Row {
                    width: parent.width
                    height: Style.space(42)
                    Column {
                      width: parent.width - monthNavigation.implicitWidth
                      spacing: Style.space(1)
                      LabelText {
                        text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                        font.pixelSize: Style.font.heading
                        font.bold: true
                      }
                      MutedText {
                        text: Qt.formatDate(root.today, "dddd, MMMM d").toUpperCase()
                        font.pixelSize: Style.font.caption
                        font.letterSpacing: 1
                      }
                    }
                    Row {
                      id: monthNavigation
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)
                      PanelActionButton {
                        size: Style.space(28)
                        iconText: "󰅁"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        tooltipText: "Previous month"
                        onClicked: root.moveMonth(-1)
                      }
                      PanelActionButton {
                        size: Style.space(28)
                        iconText: "󰅂"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        tooltipText: "Next month"
                        onClicked: root.moveMonth(1)
                      }
                    }
                  }

                  Grid {
                    width: parent.width
                    columns: 7
                    rowSpacing: Style.space(3)
                    columnSpacing: Style.space(3)
                    Repeater {
                      model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                      MutedText {
                        required property string modelData
                        width: (parent.width - Style.space(18)) / 7
                        height: Style.space(20)
                        text: modelData
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Style.font.caption
                        font.letterSpacing: 1
                      }
                    }
                    Repeater {
                      model: root.calendarCells
                      Rectangle {
                        required property var modelData
                        width: (parent.width - Style.space(18)) / 7
                        height: Style.space(32)
                        radius: Style.cornerRadius
                        color: modelData.today ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"
                        border.width: modelData.today ? Style.spacing.hairline : 0
                        border.color: Style.selectedBorderFor(root.foreground, Color.accent)
                        LabelText {
                          anchors.centerIn: parent
                          text: modelData.day
                          color: modelData.inMonth
                            ? (modelData.weekend ? Qt.darker(root.foreground, 1.4) : root.foreground)
                            : Qt.darker(root.foreground, 2.1)
                          font.bold: modelData.today
                        }
                      }
                    }
                  }
                }
              }

              BorderSurface {
                id: playerCard
                width: parent.width - Style.space(394)
                height: parent.height
                radius: Style.cornerRadius
                padding: Style.space(14)
                color: coverStage.base
                borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

                // Full-card artwork with cover-colored shading under the controls.
                CoverStage {
                  id: coverStage
                  anchors.fill: parent
                  anchors.topMargin: playerCard.borderTop
                  anchors.bottomMargin: playerCard.borderBottom
                  anchors.leftMargin: playerCard.borderLeft
                  anchors.rightMargin: playerCard.borderRight
                  radius: Math.max(0, Style.cornerRadius - playerCard.borderTop)
                  coverUrl: root.coverArt
                  hasTrack: !!root.player && !!(root.player.trackTitle || root.player.trackArtist || root.player.trackAlbum)
                  playing: root.opened && !!root.player && root.player.isPlaying
                  effectHost: auroraLayer
                  artTopInset: playerCard.topPadding + Style.spacing.controlHeight + Style.space(4)
                  artBottomInset: playerCard.bottomPadding + mediaBlock.height - Style.space(112)
                }

                // Localized dark overlays behind the header and the track
                // block keep every label readable on any cover without
                // dimming the artwork in between.
                Rectangle {
                  anchors.left: coverStage.left
                  anchors.right: coverStage.right
                  anchors.top: coverStage.top
                  height: coverStage.artTopInset + Style.space(26)
                  gradient: Gradient {
                    GradientStop { position: 0.0; color: root.scrim(0.72) }
                    GradientStop { position: 0.55; color: root.scrim(0.38) }
                    GradientStop { position: 1.0; color: root.scrim(0) }
                  }
                }

                Rectangle {
                  anchors.left: coverStage.left
                  anchors.right: coverStage.right
                  anchors.bottom: coverStage.bottom
                  height: mediaBlock.height + Style.space(80)
                  gradient: Gradient {
                    GradientStop { position: 0.0; color: root.scrim(0) }
                    GradientStop { position: 0.25; color: root.scrim(0.58) }
                    GradientStop { position: 0.65; color: root.scrim(0.82) }
                    GradientStop { position: 1.0; color: root.scrim(0.9) }
                  }
                }

                // Keep animated light above the text scrims but below controls.
                Item {
                  id: auroraLayer
                  anchors.fill: coverStage
                }

                Item {
                  width: parent.width
                  height: Style.spacing.controlHeight
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.topMargin: playerCard.contentTopInset
                  anchors.leftMargin: playerCard.contentLeftInset
                  anchors.rightMargin: playerCard.contentRightInset
                  MutedText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NOW PLAYING"
                    color: root.playerInk
                    font.letterSpacing: 1
                  }
                  MediaDropdown {
                    id: sourceDropdown
                    visible: root.sourcePlayers.length > 1
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(140)
                    showLabel: false
                    value: root.playerKey(root.player)
                    options: root.sourceOptions
                    foreground: root.playerInk
                    background: root.scrim(0.96)
                    popupBorder: Qt.rgba(root.playerAccent.r, root.playerAccent.g, root.playerAccent.b, 0.4)
                    accent: root.playerAccent
                    fontFamily: root.fontFamily
                    onChanged: function(value) { root.selectPlayer(value) }
                  }
                }

                Column {
                  id: mediaBlock
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.leftMargin: playerCard.contentLeftInset
                  anchors.rightMargin: playerCard.contentRightInset
                  anchors.bottomMargin: playerCard.contentBottomInset
                  spacing: Style.space(10)

                  Column {
                    width: parent.width
                    spacing: Style.space(4)
                    LabelText {
                      width: parent.width
                      text: root.player ? (root.player.trackTitle || "Unknown title") : "Nothing playing"
                      horizontalAlignment: Text.AlignHCenter
                      color: root.playerMetadataInk
                      font.pixelSize: Math.max(18, Style.font.heading)
                      font.bold: true
                      elide: Text.ElideRight
                    }
                    MutedText {
                      width: parent.width
                      text: root.player ? (root.player.trackArtist || root.player.identity || "") : "Start a media player"
                      horizontalAlignment: Text.AlignHCenter
                      color: root.playerMetadataInk
                      font.pixelSize: Math.max(14, Style.font.subtitle)
                      elide: Text.ElideRight
                    }
                  }
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    OpticalGlyph {
                      width: Style.space(18)
                      height: Style.space(18)
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰕿"
                      color: root.playerAccent
                      fontFamily: root.fontFamily
                      fontSize: Style.font.iconLarge
                    }
                    PanelSlider {
                      id: volumeSlider
                      width: parent.width - Style.space(52)
                      bar: root.bar
                      trackColor: Qt.rgba(1, 1, 1, 0.22)
                      fillColor: root.playerAccent
                      knobColor: root.playerAccent
                      minimum: 0
                      maximum: 1
                      step: 0.05
                      value: root.appVolume
                      enabled: !!root.player && root.player.volumeSupported
                      opacity: enabled ? 1 : 0.35
                      onMoved: function(value) { root.setAppVolume(value) }
                    }
                    OpticalGlyph {
                      width: Style.space(18)
                      height: Style.space(18)
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰕾"
                      color: root.playerAccent
                      fontFamily: root.fontFamily
                      fontSize: Style.font.title
                    }
                  }
                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(14)
                    PanelActionButton {
                      size: Style.space(36)
                      anchors.verticalCenter: parent.verticalCenter
                      fontSize: Style.font.icon
                      iconText: "󰒮"
                      foreground: root.playerInkMuted
                      hoverColor: root.playerAccent
                      fontFamily: root.fontFamily
                      tooltipText: "Previous"
                      enabled: root.player && root.player.canGoPrevious
                      onClicked: root.mediaAction("previous")
                    }
                    PanelActionButton {
                      size: Style.space(46)
                      anchors.verticalCenter: parent.verticalCenter
                      fontSize: Style.font.display
                      iconText: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                      foreground: root.playerAccent
                      hoverColor: root.playerAccent
                      fontFamily: root.fontFamily
                      bordered: true
                      tooltipText: root.player && root.player.isPlaying ? "Pause" : "Play"
                      enabled: !!root.player
                      onClicked: root.mediaAction("playPause")
                    }
                    PanelActionButton {
                      size: Style.space(36)
                      anchors.verticalCenter: parent.verticalCenter
                      fontSize: Style.font.icon
                      iconText: "󰒭"
                      foreground: root.playerInkMuted
                      hoverColor: root.playerAccent
                      fontFamily: root.fontFamily
                      tooltipText: "Next"
                      enabled: root.player && root.player.canGoNext
                      onClicked: root.mediaAction("next")
                    }
                  }
                  Column {
                    width: parent.width
                    spacing: Style.space(4)
                    Item {
                      width: parent.width
                      height: Style.space(14)
                      MutedText {
                        anchors.left: parent.left
                        text: root.seekAvailable ? root.formatDuration(overviewSeekSlider.dragging ? overviewSeekSlider.liveValue : root.trackPosition) : "--:--"
                        color: root.playerInkMuted
                        font.pixelSize: Math.max(12, Style.font.body)
                      }
                      MutedText {
                        anchors.right: parent.right
                        text: root.seekAvailable ? root.formatDuration(root.trackLength) : "--:--"
                        color: root.playerInkMuted
                        font.pixelSize: Math.max(12, Style.font.body)
                      }
                    }
                    PanelSlider {
                      id: overviewSeekSlider
                      width: parent.width
                      bar: root.bar
                      trackColor: Qt.rgba(1, 1, 1, 0.22)
                      fillColor: root.playerAccent
                      knobColor: root.playerAccent
                      minimum: 0
                      maximum: root.trackLength
                      step: 5
                      value: root.trackPosition
                      enabled: root.seekAvailable || dragging
                      opacity: enabled ? 1 : 0.35
                      // PanelSlider clears `dragging` before emitting `released`.
                      // `value` depends on `dragging`, so the binding chain
                      // re-evaluates synchronously and resets `liveValue` to the
                      // pre-drag position before `released` fires — seeking with
                      // its argument would snap straight back. Track the last
                      // dragged value via `moved` and seek with that instead.
                      property real dragValue: -1
                      onMoved: function(value) { dragValue = value }
                      onReleased: function(value) {
                        root.seekTo(dragValue >= 0 ? dragValue : value)
                        dragValue = -1
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
