import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui

Item {
  id: root
  required property var service
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  signal dismissed()
  property int selectedIndex: 0
  readonly property bool inputFocused: locationField.activeFocus
  Keys.onEscapePressed: root.dismissed()

  function start() {
    selectedIndex = 0
    locationField.text = root.service.location.name.split(",")[0]
    root.service.searchText = locationField.text
    Qt.callLater(function() { locationField.forceActiveFocus(); locationField.selectAll() })
  }

  function moveSelection(delta) {
    selectedIndex = Math.max(0, Math.min(service.suggestions.length - 1, selectedIndex + delta))
    results.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function pickSelected() {
    if (service.suggestions.length && !service.searching) service.saveLocation(service.suggestions[selectedIndex])
  }

  Row {
    id: heading
    width: parent.width
    height: Style.space(32)
    spacing: Style.space(6)
    PanelActionButton {
      size: Style.space(28)
      iconText: "󰅁"
      tooltipText: "Back to calendar"
      foreground: root.foreground
      onClicked: root.dismissed()
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "Choose location"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.heading
    }
  }

  Text {
    id: hint
    anchors.top: heading.bottom
    anchors.topMargin: Style.space(8)
    width: parent.width
    text: "Search a city or postal code. Add the country to narrow the results."
    wrapMode: Text.WordWrap
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  TextField {
    id: locationField
    objectName: "weatherLocationSearch"
    anchors.top: hint.bottom
    anchors.topMargin: Style.space(12)
    width: parent.width
    placeholderText: "City, country"
    foreground: root.foreground
    font.family: root.fontFamily
    maximumLength: 120
    enabled: !root.service.saving
    onTextChanged: if (root.visible) { root.selectedIndex = 0; root.service.searchText = text }
    onAccepted: root.pickSelected()
    Keys.onEscapePressed: root.dismissed()
    Keys.onDownPressed: root.moveSelection(1)
    Keys.onUpPressed: root.moveSelection(-1)
  }

  Text {
    id: status
    anchors.top: locationField.bottom
    anchors.topMargin: Style.space(8)
    width: parent.width
    text: root.service.saving ? "Saving location…" : root.service.searching ? "Searching…"
      : root.service.searchError || (root.service.suggestions.length ? "Select the correct region and country." : "Type at least two characters.")
    wrapMode: Text.WordWrap
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  ListView {
    id: results
    objectName: "weatherLocationResults"
    anchors.top: status.bottom
    anchors.topMargin: Style.space(8)
    anchors.bottom: attribution.top
    anchors.bottomMargin: Style.space(8)
    width: parent.width
    clip: true
    model: root.service.suggestions
    spacing: Style.space(4)
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
    delegate: Rectangle {
      required property var modelData
      required property int index
      width: results.width - Style.space(10)
      height: Style.space(56)
      radius: Style.cornerRadius
      color: index === root.selectedIndex || click.containsMouse
        ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
      Column {
        anchors.fill: parent
        anchors.margins: Style.space(7)
        spacing: Style.space(3)
        Text {
          text: modelData.name
          textFormat: Text.PlainText
          width: parent.width
          elide: Text.ElideRight
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          text: modelData.description
          textFormat: Text.PlainText
          width: parent.width
          elide: Text.ElideRight
          color: Qt.darker(root.foreground, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
      MouseArea {
        id: click
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.service.saving
        cursorShape: Qt.PointingHandCursor
        onClicked: root.service.saveLocation(modelData)
      }
    }
  }

  Text {
    id: attribution
    anchors.bottom: parent.bottom
    width: parent.width
    text: "Locations: Photon · © OpenStreetMap contributors"
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
