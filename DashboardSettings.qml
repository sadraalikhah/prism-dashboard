import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "Preferences.js" as Prefs

Item {
  id: root
  property var settings: ({})
  property QtObject bar: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  signal saved(string key, var value)
  signal resetRequested()
  signal locationRequested()
  signal dismissed()
  objectName: "dashboardSettings"
  onVisibleChanged: if (visible) { scroll.contentY = 0; forceActiveFocus() }
  Keys.onEscapePressed: root.dismissed()

  function reveal(item) {
    var y = item.mapToItem(content, 0, 0).y
    if (y < scroll.contentY) scroll.contentY = y
    else if (y + item.height > scroll.contentY + scroll.height)
      scroll.contentY = y + item.height - scroll.height
  }

  component Label: Text {
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  Row {
    id: header
    width: parent.width
    height: Style.space(38)
    Label { text: "Settings"; font.pixelSize: Style.font.heading; width: parent.width - done.width; anchors.verticalCenter: parent.verticalCenter }
    Button { id: done; text: "Done"; focusable: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.dismissed() }
  }

  Flickable {
    id: scroll
    anchors.top: header.bottom
    anchors.bottom: reset.top
    anchors.bottomMargin: Style.space(10)
    width: parent.width
    clip: true
    contentWidth: width
    contentHeight: content.height
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar {
      policy: Controls.ScrollBar.AsNeeded
      active: true
      visible: scroll.contentHeight > scroll.height
      width: Style.space(6)
      padding: 0
      contentItem: Rectangle {
        implicitWidth: Style.space(6)
        implicitHeight: Style.space(30)
        color: Qt.alpha(root.foreground, 0.4)
        radius: width / 2
      }
    }

    Column {
      id: content
      width: scroll.width - Style.space(12)
      spacing: Style.space(10)

      Repeater {
        model: ["Music", "Clock"]
        Column {
          required property string modelData
          width: content.width
          spacing: Style.space(8)
          Label { text: modelData.toUpperCase(); font.pixelSize: Style.font.caption; color: Qt.darker(root.foreground, 1.5); font.letterSpacing: 1 }
          Repeater {
            model: Prefs.controls.filter(function(s) { return s.group === modelData })
            Loader {
              required property var modelData
              width: parent.width
              property var descriptor: modelData
              sourceComponent: toggleControl
            }
          }
        }
      }

      Label { text: "WEATHER"; font.pixelSize: Style.font.caption; color: Qt.darker(root.foreground, 1.5); font.letterSpacing: 1 }
      Row {
        width: parent.width
        spacing: Style.space(8)
        Repeater {
          model: [{value:"celsius", label:"°C"}, {value:"fahrenheit", label:"°F"}]
          Button {
            required property var modelData
            text: modelData.label
            focusable: true
            selected: Prefs.value(root.settings, "weatherUnit") === modelData.value
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.saved("weatherUnit", modelData.value)
            onActiveFocusChanged: if (activeFocus) root.reveal(this)
          }
        }
        Button { text: "Location"; focusable: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.locationRequested(); onActiveFocusChanged: if (activeFocus) root.reveal(this) }
      }
    }
  }

  Button {
    id: reset
    anchors.bottom: parent.bottom
    text: "Reset appearance"
    focusable: true
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: root.resetRequested()
  }

  Component {
    id: toggleControl
    Toggle {
      property var descriptor: parent.descriptor
      objectName: "setting-" + descriptor.key
      width: parent.width
      label: descriptor.label
      checked: Prefs.value(root.settings, descriptor.key)
      foreground: root.foreground
      fontFamily: root.fontFamily
      titleSize: Style.font.body
      implicitHeight: Style.space(42)
      onClicked: root.saved(descriptor.key, !checked)
      onActiveFocusChanged: if (activeFocus) root.reveal(this)
    }
  }

}
