import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// The glass every widget sits on: a blurred copy of the wallpaper cut to the tile, a tint, a hairline.
Item {
  id: tile

  required property var theme
  property url glass: ""
  // where the tile is on the screen, so its piece of wallpaper lines up with the real one
  property real screenX: 0
  property real screenY: 0
  property size screenSize: Qt.size(0, 0)
  property bool flush: false
  // the compositor blurs what is behind the tile, so the wallpaper copy stays out of the way
  property bool clear: false
  default property alias content: body.data

  RectangularShadow {
    anchors.fill: parent
    radius: tile.theme.radius
    offset: Qt.vector2d(0, 14)
    blur: 34
    spread: -8
    color: Qt.rgba(0, 0, 0, 0.42)
  }

  ClippingRectangle {
    anchors.fill: parent
    radius: tile.theme.radius
    color: tile.clear ? tile.theme.veil : frost.status === Image.Ready ? "transparent" : tile.theme.solid

    Image {
      id: frost
      x: -tile.screenX
      y: -tile.screenY
      width: tile.screenSize.width
      height: tile.screenSize.height
      source: tile.glass
      visible: !tile.clear
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
    }

    Rectangle {
      anchors.fill: parent
      visible: !tile.clear && frost.status === Image.Ready
      color: tile.theme.tint
    }

    Item {
      id: body
      anchors.fill: parent
      anchors.margins: tile.flush ? 8 : tile.theme.pad
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: tile.theme.radius
    color: "transparent"
    border.width: 1
    border.color: tile.theme.hair
  }
}
