import QtQuick
import qs.Commons
import qs.Ui
import "WeatherModel.js" as WeatherModel

Item {
  id: root
  required property var service
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  signal editLocation()
  readonly property var current: service.report ? service.report.current : null
  readonly property var conditions: current ? WeatherModel.conditions(current.weather_code, current.is_day === 0) : null
  readonly property var hours: WeatherModel.hours(service.report, service.now)
  readonly property var range: WeatherModel.range(service.report, service.now)
  readonly property color muted: Qt.darker(foreground, 1.5)

  Rectangle {
    width: parent.width
    height: Style.spacing.hairline
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
  }

  Item {
    id: header
    y: Style.space(6)
    width: parent.width
    height: Style.space(25)
    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - actions.width - Style.space(4)
      text: root.service.locationKey ? root.service.location.name : "WEATHER"
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editLocation() }
    }
    Row {
      id: actions
      anchors.right: parent.right
      spacing: Style.space(2)
      PanelActionButton {
        size: Style.space(24)
        iconText: "󰑐"
        foreground: root.foreground
        fontFamily: root.fontFamily
        tooltipText: root.service.loading ? "Updating weather" : "Refresh weather"
        enabled: !!root.service.locationKey && !root.service.loading
        onClicked: root.service.refresh(true)
      }
      PanelActionButton {
        objectName: "weatherLocationButton"
        size: Style.space(24)
        iconText: "󰍎"
        foreground: root.foreground
        fontFamily: root.fontFamily
        tooltipText: "Change weather location"
        onClicked: root.editLocation()
      }
    }
  }

  Item {
    id: conditionsBody
    anchors.top: header.bottom
    anchors.topMargin: Style.space(8)
    anchors.bottom: footer.top
    anchors.bottomMargin: Style.space(8)
    width: parent.width
    visible: !!root.current

    Column {
      id: currentConditions
      width: (parent.width - Style.space(24)) * 0.56
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(3)
      Row {
        width: parent.width
        height: Style.space(44)
        spacing: Style.space(8)
        OpticalGlyph {
          width: Style.space(42)
          height: parent.height
          text: root.conditions ? root.conditions.icon : ""
          color: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.space(36)
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.current ? WeatherModel.temperature(root.current.temperature_2m) : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.space(38)
        }
      }
      Text {
        width: parent.width
        text: root.conditions ? root.conditions.text : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: root.current ? "Feels " + WeatherModel.temperature(root.current.apparent_temperature)
          + " · H " + WeatherModel.temperature(root.range.high) + " / L " + WeatherModel.temperature(root.range.low) : ""
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Rectangle {
      anchors.left: currentConditions.right
      anchors.leftMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.spacing.hairline
      height: parent.height - Style.space(8)
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
    }

    Column {
      anchors.left: currentConditions.right
      anchors.leftMargin: Style.space(24)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)
      Repeater {
        model: root.hours
        Item {
          required property var modelData
          width: parent.width
          height: Style.space(24)
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.time
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          OpticalGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: Style.space(6)
            width: Style.space(24)
            height: parent.height
            text: WeatherModel.conditions(modelData.code, modelData.night).icon
            fontFamily: root.fontFamily
            fontSize: Style.space(22)
            color: root.foreground
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: WeatherModel.temperature(modelData.temperature)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }
      }
    }
  }

  Column {
    anchors.top: header.bottom
    anchors.topMargin: Style.space(8)
    width: parent.width
    spacing: Style.space(8)
    visible: !root.current
    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: !root.service.locationKey ? "Choose your city for local weather."
        : root.service.loading ? "Loading weather…" : root.service.error || "Weather is unavailable."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Button {
      text: root.service.locationKey ? "Retry" : "Choose location"
      foreground: root.foreground
      fontFamily: root.fontFamily
      bordered: true
      focusable: true
      onClicked: root.service.locationKey ? root.service.refresh(true) : root.editLocation()
    }
  }

  Text {
    id: footer
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    text: "Open-Meteo" + (root.service.stale ? " · Offline / last update " + Qt.formatTime(new Date(root.service.receivedAt), "HH:mm") : "")
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Math.max(9, Style.font.caption - 1)
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: Qt.openUrlExternally("https://open-meteo.com/")
    }
  }
  Text {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    text: root.service.unit === "fahrenheit" ? "°F" : "°C"
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
