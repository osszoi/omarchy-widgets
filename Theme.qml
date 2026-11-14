import QtQuick

QtObject {
  readonly property int unit: 160
  readonly property int gap: 20
  readonly property int radius: 30
  readonly property int pad: 16

  property color accent: "#7466fd"
  readonly property color ink: "#ffffff"
  readonly property color ink2: Qt.rgba(1, 1, 1, 0.62)
  readonly property color ink3: Qt.rgba(1, 1, 1, 0.38)
  readonly property color hair: Qt.rgba(1, 1, 1, 0.16)
  readonly property color well: Qt.rgba(1, 1, 1, 0.10)
  readonly property color track: Qt.rgba(1, 1, 1, 0.16)
  readonly property color tint: Qt.rgba(0.086, 0.078, 0.133, 0.5)
  // over windows the compositor has blurred
  readonly property color veil: Qt.rgba(0.086, 0.078, 0.133, 0.46)
  // what a tile falls back to before the blurred wallpaper is there
  readonly property color solid: Qt.rgba(0.11, 0.10, 0.17, 0.82)

  readonly property color red: "#ff453a"
  readonly property color green: "#30d158"
  readonly property color orange: "#ff9f0a"
  readonly property color yellow: "#ffd60a"
  readonly property color blue: "#0a84ff"
  readonly property color teal: "#64d2ff"
}
