import QtQuick

Text {
  property int tone: 0
  property bool caps: false

  color: tone === 0 ? "#ffffff" : tone === 1 ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(1, 1, 1, 0.38)
  font.family: "Adwaita Sans"
  font.pixelSize: 12
  font.features: { "tnum": 1 }
  font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
  font.letterSpacing: caps ? 0.7 : 0
  font.weight: caps ? Font.Bold : Font.Normal
  textFormat: Text.PlainText
  elide: Text.ElideRight
  maximumLineCount: 1
}
