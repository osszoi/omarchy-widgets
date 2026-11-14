import QtQuick

// A few things from Home Assistant. Anything marked "hold" needs a one second press, so a stray click
// on the desktop cannot open a door.
Item {
  id: widget

  property var host
  readonly property var options: host.options
  // which entities to show is per tile, in the layout's cfg: tiles [{ entity, name, hold, icon }], chips [{ entity, label, quiet }]
  readonly property var tiles: Array.isArray(options.tiles) ? options.tiles : []
  readonly property var chips: Array.isArray(options.chips) ? options.chips : []
  readonly property int across: host.cols >= 4 ? 4 : 2
  readonly property int down: host.rows > 1 ? 2 : 1
  readonly property var shown: tiles.slice(0, across * down)
  readonly property var answer: hass.result || ({})
  readonly property string notice: hass.problem === "token" ? "Add a Home Assistant token in\n~/.config/omarchy-widgets/home-assistant.json"
    : hass.problem === "offline" ? "Home Assistant is not answering"
    : hass.problem !== "" ? "Home Assistant refused the request"
    : tiles.length === 0 ? "Pick what to show: add tiles to this widget's cfg in\n~/.config/omarchy-widgets/layout.json" : ""

  readonly property var icons: ({
    light: "M12 2a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2zM9 19h6v2H9z",
    garage: "M12 3 2 10v11h20V10zm-5 9h10v2H7zm0 4h10v2H7z",
    scene: "M12 2l2.2 6.3L20 10l-5.8 1.7L12 18l-2.2-6.3L4 10l5.8-1.7zM19 16l.9 2.1L22 19l-2.1.9L19 22l-.9-2.1L16 19l2.1-.9z",
    switch: "M7 7h10a5 5 0 0 1 0 10H7A5 5 0 0 1 7 7zm10 2a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"
  })

  function safe(id) {
    return String(id || "").replace(/[^a-z0-9_.]/g, "")
  }

  function stateOf(entity) {
    var list = answer.tiles || []
    for (var i = 0; i < list.length; i++) if (list[i].id === entity) return list[i]
    return null
  }

  function fire(entity) {
    var domain = entity.split(".")[0]
    if (domain === "scene" || domain === "script") hass.call(domain, "turn_on", { entity_id: entity })
    else if (domain === "button" || domain === "input_button") hass.call(domain, "press", { entity_id: entity })
    else hass.call("homeassistant", "toggle", { entity_id: entity })
  }

  Hass {
    id: hass
    live: widget.host.live
    template: {
      var ids = widget.shown.map(function(tile) { return "'" + widget.safe(tile.entity) + "'" }).join(",")
      var chips = widget.chips.map(function(chip) {
        var id = widget.safe(chip.entity)
        return "{\"id\":\"" + id + "\",\"state\":{{ states('" + id + "')|tojson }},\"unit\":{{ (state_attr('" + id + "','unit_of_measurement') or '')|tojson }}}"
      }).join(",")
      return "{% set ids = [" + ids + "] %}{\"tiles\":[{% for e in ids %}{\"id\":{{ e|tojson }},\"state\":{{ states(e)|tojson }},\"brightness\":{{ (state_attr(e,'brightness') or 0)|tojson }}}"
        + "{% if not loop.last %},{% endif %}{% endfor %}],\"home\":{{ states.person|selectattr('state','eq','home')|list|count }},\"chips\":[" + chips + "]}"
    }
  }

  Label { id: cap; text: "Home"; caps: true; tone: 1; font.pixelSize: 11 }

  Row {
    id: strip
    visible: widget.down > 1 && widget.notice === ""
    anchors.top: cap.bottom
    anchors.topMargin: 9
    spacing: 6

    component Chip: Rectangle {
      property string text: ""
      property color dot: "#ffffff"
      width: chipRow.width + 18
      height: 24
      radius: 12
      color: Qt.rgba(1, 1, 1, 0.11)
      Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 6
        Rectangle { width: 7; height: 7; radius: 3.5; color: parent.parent.dot; anchors.verticalCenter: parent.verticalCenter }
        Label { text: parent.parent.text; font.pixelSize: 11; font.weight: Font.DemiBold }
      }
    }

    Chip {
      visible: widget.answer.home !== undefined
      text: (widget.answer.home || 0) + " home"
      dot: widget.answer.home > 0 ? widget.host.theme.green : Qt.rgba(1, 1, 1, 0.4)
    }

    Repeater {
      model: widget.chips

      Chip {
        required property var modelData
        required property int index
        readonly property var reading: (widget.answer.chips || [])[index] || null
        readonly property string value: reading ? String(reading.state) : ""
        visible: value !== "" && value !== "unknown" && value !== "unavailable" && (modelData.quiet || []).indexOf(value.toLowerCase()) === -1
        text: modelData.label + " " + value.toLowerCase() + (reading && reading.unit ? " " + reading.unit : "")
        dot: widget.host.theme.teal
      }
    }
  }

  Grid {
    id: grid
    visible: widget.notice === ""
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    anchors.top: strip.visible ? strip.bottom : cap.bottom
    anchors.topMargin: strip.visible ? 11 : 9
    columns: widget.across
    spacing: 8

    Repeater {
      model: widget.shown

      Rectangle {
        id: accessory

        required property var modelData
        readonly property var reading: widget.stateOf(modelData.entity)
        readonly property string domain: modelData.entity.split(".")[0]
        readonly property string value: reading ? String(reading.state) : "unavailable"
        readonly property bool reachable: value !== "unavailable" && value !== "unknown"
        readonly property bool on: ["on", "open", "opening", "unlocked", "playing"].indexOf(value) !== -1
        readonly property bool tappable: reachable && ["sensor", "binary_sensor", "person"].indexOf(domain) === -1
        readonly property string note: !reachable ? "Unavailable"
          : modelData.hold ? (on ? "On" : "Hold to trigger")
          : domain === "scene" || domain === "script" ? "Run"
          : domain === "light" && on && reading.brightness > 0 ? Math.round(reading.brightness / 2.55) + " %"
          : on ? "On" : value === "off" ? "Off" : value.charAt(0).toUpperCase() + value.slice(1)
        property real held: 0

        width: (grid.width - grid.spacing * (widget.across - 1)) / widget.across
        height: (grid.height - grid.spacing * (widget.down - 1)) / widget.down
        radius: 18
        color: on ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(1, 1, 1, press.pressed && tappable ? 0.16 : 0.09)
        opacity: reachable ? 1 : 0.55
        clip: true

        Behavior on color { ColorAnimation { duration: 180 } }

        Rectangle {
          visible: accessory.held > 0
          width: parent.width * accessory.held
          height: parent.height
          color: Qt.rgba(widget.host.theme.accent.r, widget.host.theme.accent.g, widget.host.theme.accent.b, 0.55)
        }

        Rectangle {
          x: 11
          y: 10
          width: 26
          height: 26
          radius: 13
          color: accessory.on ? widget.host.theme.yellow : Qt.rgba(1, 1, 1, 0.14)
          Glyph {
            anchors.centerIn: parent
            size: 14
            tone: accessory.on ? "#16141f" : "#ffffff"
            d: widget.icons[accessory.modelData.icon] || widget.icons[accessory.domain] || widget.icons.switch
          }
        }

        Label {
          anchors { left: parent.left; leftMargin: 11; right: parent.right; rightMargin: 8; bottom: sub.top; bottomMargin: 1 }
          text: accessory.modelData.name || accessory.modelData.entity
          color: accessory.on ? "#16141f" : "#ffffff"
          font.pixelSize: 12
          font.weight: Font.DemiBold
        }

        Label {
          id: sub
          anchors { left: parent.left; leftMargin: 11; right: parent.right; rightMargin: 8; bottom: parent.bottom; bottomMargin: 9 }
          text: accessory.note
          color: accessory.on ? Qt.rgba(0.09, 0.08, 0.12, 0.6) : Qt.rgba(1, 1, 1, 0.62)
          font.pixelSize: 11
        }

        NumberAnimation {
          id: holding
          target: accessory
          property: "held"
          from: 0
          to: 1
          duration: 1000
          onFinished: { widget.fire(accessory.modelData.entity); accessory.held = 0 }
        }

        MouseArea {
          id: press
          anchors.fill: parent
          enabled: accessory.tappable && !widget.host.editing
          cursorShape: Qt.PointingHandCursor
          onPressed: if (accessory.modelData.hold) holding.restart()
          onReleased: { holding.stop(); accessory.held = 0 }
          onCanceled: { holding.stop(); accessory.held = 0 }
          onClicked: if (!accessory.modelData.hold) widget.fire(accessory.modelData.entity)
        }
      }
    }
  }

  Label {
    visible: widget.notice !== ""
    anchors { left: parent.left; right: parent.right; top: cap.bottom; topMargin: 10 }
    text: widget.notice
    tone: 1
    font.pixelSize: 12
    wrapMode: Text.WordWrap
    maximumLineCount: 4
    lineHeight: 1.25
  }
}
