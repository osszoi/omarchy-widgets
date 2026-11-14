import QtQuick
import QtQuick.Effects
import "lib/layout.js" as Layout
import "widgets"

// Every tile on one screen, plus the editing an iPhone home screen has: hold a tile to start, drag to
// move, pull the corner to resize, minus to remove, plus to add.
Item {
  id: board

  required property var theme
  property url glass: ""
  property real inset: 0
  property bool lifted: false
  property bool editing: false
  property bool live: true
  property bool shielded: false

  readonly property var grid: Layout.metrics(width, height, theme.unit, theme.gap, 40, inset)
  property string selected: ""
  property var hint: null
  property bool picking: false
  property bool full: false

  signal edited()
  signal editWanted()
  signal dismissed()

  ListModel { id: tiles }

  function load(items) {
    tiles.clear()
    for (var i = 0; i < items.length; i++) {
      var item = items[i]
      tiles.append({ uid: item.id, type: item.type, col: item.col, row: item.row, w: item.w, h: item.h, cfg: JSON.stringify(item.cfg || {}) })
    }
  }

  function items(skipUid) {
    var out = []
    for (var i = 0; i < tiles.count; i++) {
      var tile = tiles.get(i)
      if (tile.uid === skipUid) continue
      out.push({ id: tile.uid, type: tile.type, col: tile.col, row: tile.row, w: tile.w, h: tile.h, cfg: JSON.parse(tile.cfg) })
    }
    return out
  }

  function spotFor(index, x, y) {
    var tile = tiles.get(index)
    var cell = Layout.cellAt(grid, x, y)
    var wanted = { col: Math.max(0, Math.min(grid.cols - tile.w, cell.col)), row: Math.max(0, Math.min(grid.rows - tile.h, cell.row)), w: tile.w, h: tile.h }
    var others = items(tile.uid)
    return Layout.free(grid, others, wanted) ? wanted : Layout.nearestFree(grid, others, wanted)
  }

  function drop(index, x, y) {
    var spot = spotFor(index, x, y)
    if (spot) {
      tiles.setProperty(index, "col", spot.col)
      tiles.setProperty(index, "row", spot.row)
      edited()
    }
    hint = null
  }

  function sizeFor(index, width, height) {
    var tile = tiles.get(index)
    var size = Layout.snapSize(tile.type, Math.max(1, Math.round((width + grid.gap) / grid.pitch)), Math.max(1, Math.round((height + grid.gap) / grid.pitch)))
    var wanted = { col: tile.col, row: tile.row, w: size.w, h: size.h }
    return Layout.free(grid, items(tile.uid), wanted) ? wanted : null
  }

  function resize(index, width, height) {
    var size = sizeFor(index, width, height)
    if (size) {
      tiles.setProperty(index, "w", size.w)
      tiles.setProperty(index, "h", size.h)
      edited()
    }
    hint = null
  }

  function remove(index) {
    tiles.remove(index)
    selected = ""
    edited()
  }

  function add(type) {
    var size = Layout.TYPES[type].sizes[0]
    var all = items("")
    var spot = Layout.nearestFree(grid, all, { col: Math.floor((grid.cols - size[0]) / 2), row: Math.floor((grid.rows - size[1]) / 2), w: size[0], h: size[1] })
    if (!spot) { full = true; return }
    var taken = {}
    for (var i = 0; i < all.length; i++) taken[all[i].id] = true
    var uid = Layout.nextId(type, taken)
    tiles.append({ uid: uid, type: type, col: spot.col, row: spot.row, w: size[0], h: size[1], cfg: "{}" })
    selected = uid
    picking = false
    edited()
  }

  onEditingChanged: {
    hint = null
    picking = false
    full = false
    if (!editing) selected = ""
  }

  Rectangle {
    anchors.fill: parent
    color: "#05040a"
    opacity: board.lifted ? 0.42 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (board.picking) board.picking = false
        else if (board.editing) board.selected = ""
        else board.dismissed()
      }
    }
  }

  // where the tile being dragged or resized will land
  Rectangle {
    visible: board.hint !== null
    x: board.hint ? Layout.rect(board.grid, board.hint).x : 0
    y: board.hint ? Layout.rect(board.grid, board.hint).y : 0
    width: board.hint ? Layout.rect(board.grid, board.hint).width : 0
    height: board.hint ? Layout.rect(board.grid, board.hint).height : 0
    radius: board.theme.radius
    color: Qt.rgba(1, 1, 1, 0.07)
    border.width: 2
    border.color: Qt.rgba(1, 1, 1, 0.55)
  }

  Repeater {
    model: tiles

    Item {
      id: slot

      required property int index
      required property string uid
      required property string type
      required property int col
      required property int row
      required property int w
      required property int h
      required property string cfg

      // what a widget sees of its tile
      readonly property var theme: board.theme
      readonly property int cols: w
      readonly property int rows: h
      readonly property var options: JSON.parse(cfg)
      readonly property bool editing: board.editing
      readonly property bool shielded: board.shielded && Layout.TYPES[type].guarded === true
      readonly property bool live: board.live && !shielded && !dragging

      readonly property var spot: Layout.rect(board.grid, { col: col, row: row, w: w, h: h })
      readonly property bool picked: board.selected === uid
      property bool dragging: false
      property real dragX: 0
      property real dragY: 0
      property bool entered: false

      x: dragging ? dragX : spot.x
      y: dragging ? dragY : spot.y
      width: spot.width
      height: spot.height
      z: dragging ? 30 : picked ? 20 : 1
      opacity: entered ? 1 : 0
      scale: !entered ? 0.92 : dragging ? 1.04 : hover.hovered && !board.editing ? 1.012 : 1

      Behavior on x { enabled: !slot.dragging; NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
      Behavior on y { enabled: !slot.dragging; NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
      Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

      Timer { interval: 40 + slot.index * 45; running: true; onTriggered: slot.entered = true }

      SequentialAnimation on rotation {
        running: board.editing && !slot.dragging
        loops: Animation.Infinite
        onRunningChanged: if (!running) slot.rotation = 0
        NumberAnimation { from: slot.index % 2 ? -0.7 : 0.7; to: slot.index % 2 ? 0.7 : -0.7; duration: 150 + (slot.index % 3) * 14; easing.type: Easing.InOutSine }
        NumberAnimation { from: slot.index % 2 ? 0.7 : -0.7; to: slot.index % 2 ? -0.7 : 0.7; duration: 150 + (slot.index % 3) * 14; easing.type: Easing.InOutSine }
      }

      HoverHandler { id: hover }

      MouseArea {
        anchors.fill: parent
        enabled: !board.editing
        pressAndHoldInterval: 650
        onPressAndHold: { board.selected = slot.uid; board.editWanted() }
      }

      Component { id: agenda; Agenda { host: slot } }
      Component { id: cams; Cams { host: slot } }
      Component { id: playing; Playing { host: slot } }
      Component { id: gpu; Gpu { host: slot } }
      Component { id: budget; Budget { host: slot } }
      Component { id: home; Home { host: slot } }
      Component { id: printer; Printer { host: slot } }
      Component { id: system; System { host: slot } }
      readonly property var parts: ({ agenda: agenda, cams: cams, playing: playing, gpu: gpu, budget: budget, home: home, printer: printer, system: system })

      Tile {
        anchors.fill: parent
        theme: board.theme
        glass: board.glass
        screenX: slot.x
        screenY: slot.y
        screenSize: Qt.size(board.width, board.height)
        flush: slot.type === "cams"

        Loader {
          anchors.fill: parent
          visible: !slot.shielded
          sourceComponent: slot.parts[slot.type]
        }

        Column {
          visible: slot.shielded
          anchors.centerIn: parent
          spacing: 6
          Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 26
            tone: Qt.rgba(1, 1, 1, 0.6)
            d: "M12 2a5 5 0 0 0-5 5v3H5v12h14V10h-2V7a5 5 0 0 0-5-5zm-3 8V7a3 3 0 0 1 6 0v3z"
          }
          Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Hidden while sharing"; tone: 1; font.pixelSize: 11 }
        }
      }

      Rectangle {
        visible: slot.picked && board.editing
        anchors.fill: parent
        anchors.margins: -3
        radius: board.theme.radius + 3
        color: "transparent"
        border.width: 2.5
        border.color: "#ffffff"
      }

      MouseArea {
        anchors.fill: parent
        enabled: board.editing
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real grabX: 0
        property real grabY: 0

        onPressed: mouse => {
          board.selected = slot.uid
          board.picking = false
          var at = mapToItem(board, mouse.x, mouse.y)
          grabX = at.x - slot.x
          grabY = at.y - slot.y
          slot.dragX = slot.x
          slot.dragY = slot.y
          slot.dragging = true
        }
        onPositionChanged: mouse => {
          if (!slot.dragging) return
          var at = mapToItem(board, mouse.x, mouse.y)
          slot.dragX = at.x - grabX
          slot.dragY = at.y - grabY
          board.hint = board.spotFor(slot.index, slot.dragX, slot.dragY)
        }
        onReleased: {
          if (!slot.dragging) return
          board.drop(slot.index, slot.dragX, slot.dragY)
          slot.dragging = false
        }
        onCanceled: { slot.dragging = false; board.hint = null }
      }

      Rectangle {
        visible: board.editing
        x: -9
        y: -9
        width: 26
        height: 26
        radius: 13
        color: Qt.rgba(0.92, 0.92, 0.96, 0.95)
        Rectangle { anchors.centerIn: parent; width: 12; height: 2.5; radius: 1.25; color: "#1c1c1e" }
        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: board.remove(slot.index) }
      }

      Item {
        visible: slot.picked && board.editing && Layout.TYPES[slot.type].sizes.length > 1
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: -10; bottomMargin: -10 }
        width: 34
        height: 34

        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 5; height: 24; radius: 2.5; color: "#ffffff" }
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 24; height: 5; radius: 2.5; color: "#ffffff" }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -8
          cursorShape: Qt.SizeFDiagCursor
          property real startX: 0
          property real startY: 0

          function wanted(mouse) {
            var at = mapToItem(board, mouse.x, mouse.y)
            return { width: slot.width + at.x - startX, height: slot.height + at.y - startY }
          }
          onPressed: mouse => { var at = mapToItem(board, mouse.x, mouse.y); startX = at.x; startY = at.y }
          onPositionChanged: mouse => { var size = wanted(mouse); board.hint = board.sizeFor(slot.index, size.width, size.height) }
          onReleased: mouse => { var size = wanted(mouse); board.resize(slot.index, size.width, size.height) }
          onCanceled: board.hint = null
        }
      }
    }
  }

  component Pill: Rectangle {
    id: pill
    property string text: ""
    property bool strong: false
    signal pressed()
    width: pillLabel.width + 34
    height: 36
    radius: 18
    color: strong ? "#ffffff" : Qt.rgba(0.16, 0.15, 0.22, 0.86)
    border.width: strong ? 0 : 1
    border.color: board.theme.hair
    scale: pillArea.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 120 } }
    Label { id: pillLabel; anchors.centerIn: parent; text: pill.text; color: pill.strong ? "#16141f" : "#ffffff"; font.pixelSize: 13; font.weight: Font.DemiBold }
    MouseArea { id: pillArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pill.pressed() }
  }

  Row {
    visible: board.editing
    anchors.horizontalCenter: parent.horizontalCenter
    y: board.inset + 14
    z: 50
    spacing: 10

    Pill { text: board.full ? "No room left" : "+ Add widget"; onPressed: { board.full = false; board.picking = !board.picking } }
    Pill { text: "Done"; strong: true; onPressed: board.dismissed() }
  }

  Rectangle {
    id: gallery
    visible: board.picking
    anchors.horizontalCenter: parent.horizontalCenter
    y: board.inset + 62
    z: 60
    width: 560
    height: choices.height + 24
    radius: 26
    color: Qt.rgba(0.11, 0.10, 0.17, 0.96)
    border.width: 1
    border.color: board.theme.hair

    MouseArea { anchors.fill: parent }

    Grid {
      id: choices
      x: 12
      y: 12
      columns: 2
      spacing: 8

      Repeater {
        model: Object.keys(Layout.TYPES)

        Rectangle {
          required property string modelData
          readonly property var kind: Layout.TYPES[modelData]
          width: 264
          height: 58
          radius: 16
          color: Qt.rgba(1, 1, 1, pick.containsMouse ? 0.16 : 0.08)

          Label { x: 14; y: 11; text: parent.kind.name; font.pixelSize: 14; font.weight: Font.DemiBold }
          Label { x: 14; y: 31; width: parent.width - 28; text: parent.kind.blurb; tone: 1; font.pixelSize: 11 }
          MouseArea { id: pick; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: board.add(parent.modelData) }
        }
      }
    }
  }
}
