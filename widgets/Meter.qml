import QtQuick

Item {
  id: meter

  property real value: 0
  property color fill: "#ffffff"
  property color fillEnd: fill

  implicitHeight: 4

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Qt.rgba(1, 1, 1, 0.16)
  }

  Rectangle {
    height: parent.height
    width: Math.max(height, parent.width * Math.max(0, Math.min(1, meter.value)))
    radius: height / 2
    visible: meter.value > 0
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: meter.fill }
      GradientStop { position: 1; color: meter.fillEnd }
    }

    Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
  }
}
