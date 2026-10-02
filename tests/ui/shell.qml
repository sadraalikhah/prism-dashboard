import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons

ShellRoot {
  id: test
  property var widget: null
  property var accentChanges: []
  QtObject {
    id: fakeShell
    property var saved: ({})
    property int saves: 0
    function updateEntryInline(id, entry) { saved = JSON.parse(JSON.stringify(entry)); saves++ }
  }
  QtObject {
    id: fakeBar
    property QtObject shell: fakeShell
    property color foreground: Color.foreground
    property color barForeground: Color.foreground
    property color background: Color.background
    property color urgent: Color.urgent
    property bool foregroundAnimationEnabled: false
    property string fontFamily: Style.font.family
    property string position: "top"
    property bool vertical: false
    property int barSize: 26
    property var activePopout: null
    function registerClickTarget(target) {}
    function unregisterClickTarget(target) {}
    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function requestPopout(owner) { activePopout = owner }
    function releasePopout(owner) { activePopout = null }
  }
  PanelWindow {
    id: window
    anchors { bottom: true; left: true }
    implicitWidth: 170
    implicitHeight: 26
    color: Color.background
    exclusionMode: ExclusionMode.Ignore
  }
  Component.onCompleted: {
    var component = Qt.createComponent(Quickshell.env("DASHBOARD_BAR"))
    if (component.status !== Component.Ready) throw new Error(component.errorString())
    widget = component.createObject(window.contentItem, {bar: fakeBar})
    if (!widget) throw new Error(component.errorString())
    console.log("SPECTRUM_READY")
  }
  function spectrum() {
    for (var i = 0; i < widget.children.length; i++)
      if ("levels" in widget.children[i]) return widget.children[i]
    throw new Error("Spectrum missing")
  }
  function panel() {
    for (var i = 0; i < widget.children.length; i++) {
      var item = widget.children[i].item
      if (item && typeof item.musicStatus === "function") return item
    }
    throw new Error("Panel missing")
  }

  function matching(item, predicate) {
    if (predicate(item)) return item
    var children = []
    if (item.children) for (var c = 0; c < item.children.length; c++) children.push(item.children[c])
    if (item.data) for (var d = 0; d < item.data.length; d++) if (children.indexOf(item.data[d]) < 0) children.push(item.data[d])
    for (var i = 0; i < children.length; i++) { var result = matching(children[i], predicate); if (result) return result }
    return null
  }
  function named(name) { return matching(panel(), function(o) { return o.objectName === name }) }
  function captureCard(path) {
    var p = panel()
    for (var i = 0; i < p.data.length; i++) {
      var o = p.data[i]
      if ("cardOrigin" in o) o.contentItem[0].parent.parent.grabToImage(function(r) { r.saveToFile(path) })
    }
  }
  function scenario(value) {
    Quickshell.execDetached(["busctl", "--address=" + Quickshell.env("DBUS_SESSION_BUS_ADDRESS"), "call",
      "org.mpris.MediaPlayer2.spotify", "/org/mpris/MediaPlayer2", "org.example.MusicTest", "Scenario", "s", value])
  }
  TestCase {
    id: checks
    when: false
    function run(output) {
      try {
        compare(test.widget.moduleName, "io.github.sadraalikhah.prism-dashboard")
        test.widget.setPreference("displayWaves", false)
        compare(fakeShell.saved.id, "io.github.sadraalikhah.prism-dashboard")
        compare(fakeShell.saved.displayWaves, false)
        test.widget.resetVisualSettings()
        verify(!Object.prototype.hasOwnProperty.call(fakeShell.saved, "displayWaves"))
        test.widget.cycleFormat()
        compare(fakeShell.saved.id, "io.github.sadraalikhah.prism-dashboard")
        test.widget.open()
        wait(250)
        var p = test.panel()
        compare(p.moduleName, test.widget.moduleName)
        compare(p.ipcTarget, test.widget.moduleName)
        compare(p.leftAction, "shuffle")
        var left = test.named("mediaContextLeft"), right = test.named("mediaContextRight")
        verify(left.visible && right.visible)
        verify(left.x + left.width < left.parent.width / 2 - 73)
        verify(right.x > right.parent.width / 2 + 73)
        mouseClick(left)
        tryCompare(p.player, "shuffle", true, 2000)
        mouseClick(right)
        wait(100)
        verify(test.named("mediaContextMenu").opened)
        test.captureCard(output + "/options.png")
        mouseClick(test.matching(test.named("mediaContextMenu").contentItem, function(o) { return o.objectName === "mediaOption-repeat" }))
        tryCompare(p.player, "loopState", 2, 2000)
        verify(!test.named("mediaContextMenu").opened)
        mouseClick(right);wait(100);mouseClick(test.matching(test.named("mediaContextMenu").contentItem, function(o) { return o.objectName === "mediaOption-repeat" }))
        tryCompare(p.player, "loopState", 1, 2000)
        mouseClick(right);wait(100);mouseClick(test.matching(test.named("mediaContextMenu").contentItem, function(o) { return o.objectName === "mediaOption-repeat" }))
        tryCompare(p.player, "loopState", 0, 2000)
        p.selectPlayer("org.mpris.MediaPlayer2.chrome")
        wait(100)
        compare(p.leftAction, "page")
        verify(p.pageUrl.indexOf("https:") === 0)
        p.selectPlayer("org.mpris.MediaPlayer2.spotify")
        tryVerify(function() { return p.canLike }, 5000)
        compare(p.leftAction, "like")
        test.captureCard(output + "/spotify-unliked.png")
        mouseClick(left)
        tryVerify(function() { return JSON.parse(p.contextStatus()).liked === true }, 3000)
        verify(!JSON.parse(p.contextStatus()).busy)
        mouseClick(left)
        verify(!JSON.parse(p.contextStatus()).busy)
        test.captureCard(output + "/spotify-liked.png")
        wait(200)
        test.scenario("ad")
        tryCompare(p, "spotifyUri", "", 2000)
        verify(!left.visible && !p.canLike)
        test.scenario("episode")
        tryCompare(p, "podcast", true, 2000)
        compare(p.leftAction, "back15")
        mouseClick(left)
        tryCompare(p, "sampledPosition", 30, 2000)
        mouseClick(right)
        tryCompare(p, "sampledPosition", 60, 2000)
        test.captureCard(output + "/podcast.png")
        test.scenario("noControls")
        tryCompare(p, "seekAvailable", false, 2000)
        verify(!left.visible && !right.visible)
        console.log("CONTEXT_CHECKS_PASS")
      } catch (error) { console.error("CONTEXT_CHECKS_FAIL " + error.stack); throw error }
    }
  }

  Connections {
    target: test.widget ? test.widget.paletteSource : null
    function onPaletteChanged() {
      test.accentChanges = test.accentChanges.concat([String(test.widget.paletteSource.accent)])
    }
  }
  IpcHandler {
    target: "spectrum-smoke"
    function checks(output: string): void { checks.run(output) }
    function settings(): void { test.widget.open(); test.panel().editSettings() }
    function captureCard(path: string): void { test.captureCard(path) }
    function state(): string { return test.spectrum().status() }
    function colors(): string {
      var p = test.panel()
      return JSON.stringify({music:String(p.playerAccent), spectrum:String(test.spectrum().accent),
        key: test.widget.paletteSource.sampledKey, cover:String(p.coverArt),
        shared: p.paletteSource === test.widget.paletteSource, changes: test.accentChanges})
    }
    function clearChanges(): void { test.accentChanges = [] }
    function select(): void { test.panel().selectPlayer("org.mpris.MediaPlayer2.music_test") }
    function open(): void { test.widget.open() }
    function close(): void { test.widget.close() }
    function disable(): void { test.widget.settings = {clockSpectrum: false} }
    function enable(): void { test.widget.settings = {clockSpectrum: true} }
    function vertical(): void { fakeBar.vertical = !fakeBar.vertical }
    function capture(path: string): void {
      test.widget.grabToImage(function(result) { result.saveToFile(path) })
    }
  }
}
