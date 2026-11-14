import QtQuick
import QtQuick.Shapes

// values between 0 and 1, oldest first. redrawn only when a sample comes in
Shape {
  id: spark

  property var values: []
  property color line: "#ffffff"
  property int slots: 40

  preferredRendererType: Shape.CurveRenderer

  function points(closed) {
    var out = []
    var n = values.length
    // a short history is stretched over the whole width, it only scrolls once it is full
    var step = width / Math.max(1, Math.min(slots, Math.max(2, n)) - 1)
    var first = 0
    for (var i = 0; i < n; i++) out.push(Qt.point(first + i * step, height - 2 - Math.max(0, Math.min(1, values[i])) * (height - 4)))
    if (n === 0) out.push(Qt.point(0, height - 2), Qt.point(width, height - 2))
    if (n === 1) out.unshift(Qt.point(Math.max(0, first - step), out[0].y))
    if (closed) {
      out.push(Qt.point(out[out.length - 1].x, height), Qt.point(out[0].x, height), out[0])
    }
    return out
  }

  ShapePath {
    strokeWidth: -1
    fillColor: Qt.rgba(spark.line.r, spark.line.g, spark.line.b, 0.24)
    PathPolyline { path: spark.points(true) }
  }

  ShapePath {
    strokeWidth: 1.6
    strokeColor: spark.line
    fillColor: "transparent"
    capStyle: ShapePath.RoundCap
    joinStyle: ShapePath.RoundJoin
    PathPolyline { path: spark.points(false) }
  }
}
