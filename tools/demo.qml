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
    anchors { top: true; left: true; right: true }
    implicitWidth: 170
    implicitHeight: 26
    color: Color.background
    exclusionMode: ExclusionMode.Ignore
  }
  Component.onCompleted: {
    var component = Qt.createComponent(Quickshell.env("DASHBOARD_BAR"))
    if (component.status !== Component.Ready) throw new Error(component.errorString())
    widget = component.createObject(window.contentItem, {bar: fakeBar})
    widget.x=(window.width-widget.width)/2
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
  function stage() { return matching(panel(), function(o) { return "paletteCache" in o && "wake" in o }) }
  function popupWindow() {
    var p=panel()
    for (var i=0;i<p.data.length;i++) if ("cardOrigin" in p.data[i]) return p.data[i]
    throw new Error("Popup missing")
  }
  function weather() { return named("dashboardWeatherService") }
  function reset() {
    var p=panel()
    p.closeContextMenu(); p.closeSettings(); p.closeWeatherLocation()
    widget.settings = {format:"ddd d MMM HH:mm"}
    p.selectPlayer("org.mpris.MediaPlayer2.music_test")
    var w=weather();w.active=false
    w.locationPath=Quickshell.env("PRISM_DEMO_FIXTURES") + "/location.json"
    w.location={name:"Paris, Île-de-France, France", latitude:48.8566, longitude:2.3522}
    w.report=JSON.parse(forecast.text());w.receivedAt=Date.now();w.error=""
    w.now=Date.now()
    p.open()
  }
  FileView { id: forecast; path: Quickshell.env("PRISM_DEMO_FIXTURES") + "/paris-forecast.json" }
  FileView { id: cities; path: Quickshell.env("PRISM_DEMO_FIXTURES") + "/cities.json" }
  property real t: 0
  property string mode: ""
  Timer {
    interval: 16;repeat:true;running:test.mode==="hover"
    onTriggered: { test.t+=.016; var s=test.stage(); s.pointerX=.5+.32*Math.sin(test.t*1.25);s.pointerY=.48+.22*Math.sin(test.t*1.9);s.pointerStrength=1 }
  }
  Timer {
    interval:33;repeat:true;running:test.mode==="clock-preview"
    onTriggered: {
      test.t+=.033
      var s=test.spectrum();s.failed=false
      var levels=[]
      for(var i=0;i<22;i++) levels.push(Math.max(.05, Math.min(.95, .25 + .24*Math.sin(test.t*3+i*.36) + .24*Math.sin(test.t*5-i*.62))))
      s.levels=levels
    }
  }
  TestCase {
    id: controls
    when:false
    function click(name) { mouseClick(test.named(name)) }
    function menu() { mouseClick(test.named("mediaContextRight")); mouseMove(test.named("mediaContextMenu").contentItem, 90, 20) }
    function rightClick() { mouseClick(test.widget, test.widget.width/2, test.widget.height/2, Qt.RightButton) }
  }
  IpcHandler {
    target:"prism-demo"
    function ready(): string { return test.panel().musicStatus() }
    function reset(): void { test.reset() }
    function settings(): void { test.panel().editSettings() }
    function toggle(key:string): void {
      if (test.panel().editingSettings) controls.click("setting-"+key)
      else test.widget.setPreference(key, test.widget.settings[key] === false)
    }
    function month(delta:int): void { test.panel().moveMonth(delta) }
    function hover(): void { test.mode="hover";test.t=0 }
    function stopHover(): void { test.mode="";test.stage().pointerStrength=0 }
    function colors(): string { return JSON.stringify({accent:String(test.stage().accent), clock:String(test.spectrum().accent)}) }
    function select(key:string): void { test.panel().selectPlayer("org.mpris.MediaPlayer2."+key) }
    function menu(): void { controls.menu() }
    function menuState(): string { return JSON.stringify({opened:test.named("mediaContextMenu").opened}) }
    function like(): void { controls.click("mediaContextLeft") }
    function clock(): void { controls.rightClick() }
    function location(): void {
      test.panel().editWeatherLocation()
      var field=test.named("weatherLocationSearch")
      if (field) field.text="Paris"
      test.weather().cancelSearch()
      test.weather().searchError=""
      test.weather().suggestions=JSON.parse(cities.text())
    }
    function ensureOpen(): void { if (!test.widget.opened) test.widget.open() }
    function capture(path:string): void { test.captureCard(path) }
    function clockPreview(): void {
      var p=test.matching(test.spectrum(), function(o) { return "command" in o && String(o.command).indexOf("exec cava")>=0 })
      if(p) p.running=false
      test.mode="clock-preview";test.t=0
    }
    function captureClock(path:string): void { test.widget.grabToImage(function(r) { r.saveToFile(path) }) }
    function geom(): string {
      var w=test.popupWindow(),card=w.contentItem[0].parent.parent
      return JSON.stringify({x:w.cardOrigin.x,y:w.cardOrigin.y,w:card.width,h:card.height,screenW:w.screenW,screenH:w.screenH})
    }
    function state(): string { return test.panel().contextStatus() }
    function spectrum(): string { return test.spectrum().status() }
    function quit(): void { test.widget.close();Qt.quit() }
  }
}
