import QtQuick
import "../lib/data.js" as Data

// Read from Home Assistant's bambu_lab integration, whatever the printer is called there.
Item {
  id: widget

  property var host
  readonly property bool wide: host.cols > 1
  readonly property var view: Data.printer(hass.result)
  readonly property string notice: hass.problem === "token" ? "Home Assistant token missing"
    : hass.problem === "offline" ? "Home Assistant is not answering"
    : hass.problem !== "" ? "Home Assistant refused the request"
    : !view.found ? "No printer in Home Assistant yet" : ""

  Hass {
    id: hass
    live: widget.host.live
    every: 10000
    template: "{ {% for e in integration_entities('bambu_lab') %}{{ e|tojson }}:{\"s\":{{ states(e)|tojson }},\"u\":{{ (state_attr(e,'unit_of_measurement') or '')|tojson }},"
      + "\"a\":{\"color\":{{ state_attr(e,'color')|tojson }},\"active\":{{ state_attr(e,'active')|tojson }}}}{% if not loop.last %},{% endif %}{% endfor %} }"
  }

  Item {
    id: dial
    width: widget.wide ? 112 : parent.width
    height: widget.wide ? 112 : parent.width
    anchors.verticalCenter: parent.verticalCenter

    Ring {
      anchors.fill: parent
      value: widget.view.progress
      tone: widget.view.state === "failed" ? widget.host.theme.red : widget.view.state === "finish" ? widget.host.theme.green : "#7fa6ff"
    }

    Label {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -6
      text: widget.view.found ? Math.round(widget.view.progress * 100) + "%" : "—"
      font.pixelSize: 26
      font.weight: Font.DemiBold
      font.letterSpacing: -0.5
    }

    Label {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 15
      text: widget.view.label
      caps: true
      tone: 1
      font.pixelSize: 10
    }
  }

  Column {
    visible: widget.wide
    anchors { left: dial.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
    spacing: 3

    Label { text: "3D Printer"; caps: true; tone: 1; font.pixelSize: 11 }

    Label {
      width: parent.width
      topPadding: 2
      text: widget.notice !== "" ? widget.notice : widget.view.task !== "" ? widget.view.task : widget.view.label
      font.pixelSize: widget.notice !== "" ? 12 : 15
      font.weight: widget.notice !== "" ? Font.Normal : Font.DemiBold
      tone: widget.notice !== "" ? 1 : 0
      wrapMode: widget.notice !== "" ? Text.WordWrap : Text.NoWrap
      maximumLineCount: widget.notice !== "" ? 3 : 1
    }

    Label {
      visible: widget.notice === "" && widget.view.busy
      width: parent.width
      tone: 1
      text: Data.span(widget.view.remaining) + " left  ·  ends " + Data.hhmm(new Date(Date.now() + widget.view.remaining * 1000))
    }

    Label {
      visible: widget.notice === "" && (widget.view.layers !== null || widget.view.nozzle !== null)
      width: parent.width
      tone: 1
      text: (widget.view.layers !== null ? "Layer " + (widget.view.layer || 0) + " / " + widget.view.layers : "")
        + (widget.view.layers !== null && widget.view.nozzle !== null ? "  ·  " : "")
        + (widget.view.nozzle !== null ? Math.round(widget.view.nozzle) + "°" + (widget.view.bed !== null ? " / " + Math.round(widget.view.bed) + "°" : "") : "")
    }

    Row {
      visible: widget.notice === "" && widget.view.trays.length > 0
      topPadding: 6
      spacing: 7

      Repeater {
        model: widget.view.trays

        Rectangle {
          required property var modelData
          width: 16
          height: 16
          radius: 8
          color: modelData.empty || modelData.color === "" ? "transparent" : modelData.color
          border.width: modelData.active ? 2 : 1.5
          border.color: modelData.active ? "#ffffff" : Qt.rgba(1, 1, 1, 0.35)
        }
      }
    }
  }
}
