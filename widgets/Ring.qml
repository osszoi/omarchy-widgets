import QtQuick
import QtQuick.Shapes

Shape {
  id: ring

  property real value: 0
  property real thickness: 9
  property color tone: "#7fa6ff"
  readonly property real shown: Math.max(0, Math.min(1, value))

  preferredRendererType: Shape.CurveRenderer

  Behavior on value { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

  ShapePath {
    strokeWidth: ring.thickness
    strokeColor: Qt.rgba(1, 1, 1, 0.14)
    fillColor: "transparent"
    PathAngleArc {
      centerX: ring.width / 2; centerY: ring.height / 2
      radiusX: (ring.width - ring.thickness) / 2; radiusY: (ring.height - ring.thickness) / 2
      startAngle: 0; sweepAngle: 360
    }
  }

  ShapePath {
    strokeWidth: ring.thickness
    strokeColor: ring.shown > 0 ? ring.tone : "transparent"
    fillColor: "transparent"
    capStyle: ShapePath.RoundCap
    PathAngleArc {
      centerX: ring.width / 2; centerY: ring.height / 2
      radiusX: (ring.width - ring.thickness) / 2; radiusY: (ring.height - ring.thickness) / 2
      startAngle: -90; sweepAngle: 360 * ring.shown
    }
  }
}
