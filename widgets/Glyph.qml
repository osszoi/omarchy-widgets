import QtQuick
import QtQuick.Shapes

// an icon from a 24x24 svg path
Shape {
  id: glyph

  property string d: ""
  property color tone: "#ffffff"
  property real size: 18

  width: size
  height: size
  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    strokeWidth: -1
    fillColor: glyph.tone
    scale: Qt.size(glyph.size / 24, glyph.size / 24)
    PathSvg { path: glyph.d }
  }
}
