import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../lib/data.js" as Data

// Whatever player is on the session bus. Lyrics come from the file eduardo.youtube-music writes for its
// current song, when there is one.
Item {
  id: widget

  property var host
  readonly property bool tall: host.rows > 1
  readonly property var player: {
    var list = Mpris.players.values
    var paused = null
    for (var i = 0; i < list.length; i++) {
      if (list[i].isPlaying) return list[i]
      if (!paused && list[i].trackTitle) paused = list[i]
    }
    return paused
  }
  readonly property bool playing: !!player && player.isPlaying
  readonly property real length: player && player.lengthSupported ? player.length : 0
  property real position: 0

  property var song: null
  readonly property var lines: song && player && song.title === player.trackTitle && Array.isArray(song.lines) ? song.lines : []
  readonly property int line: Data.lyricLine(lines, position * 1000 + 250)

  function sync() {
    position = player && player.positionSupported ? player.position : 0
  }

  onPlayerChanged: sync()

  Timer {
    interval: 1000
    repeat: true
    running: widget.host.live && widget.playing
    triggeredOnStart: true
    onTriggered: widget.sync()
  }

  // sleeps until the next line is due instead of ticking
  Timer {
    interval: 400
    running: widget.host.live && widget.playing && widget.lines.length > 0
    onTriggered: {
      widget.sync()
      var wait = Data.lyricWait(widget.lines, widget.position * 1000 + 250)
      interval = wait > 0 ? Math.min(wait, 8000) : 4000
      restart()
    }
  }

  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/" + Quickshell.env("UID")) + "/eduardo.youtube-music/now.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { widget.song = JSON.parse(text()) } catch (error) { widget.song = null }
    }
    onLoadFailed: widget.song = null
  }

  component Control: Item {
    id: control
    property string d: ""
    property real size: 18
    signal pressed()
    width: 26
    height: 26
    opacity: area.pressed ? 0.5 : 1
    Glyph { anchors.centerIn: parent; d: control.d; size: control.size }
    MouseArea { id: area; anchors.fill: parent; enabled: !widget.host.editing; cursorShape: Qt.PointingHandCursor; onClicked: control.pressed() }
  }

  ClippingRectangle {
    id: art
    width: 128
    height: 128
    radius: 18
    color: Qt.rgba(1, 1, 1, 0.08)

    Rectangle {
      anchors.fill: parent
      visible: cover.status !== Image.Ready
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.rgba(widget.host.theme.accent.r, widget.host.theme.accent.g, widget.host.theme.accent.b, 0.55) }
        GradientStop { position: 1; color: Qt.rgba(0.2, 0.12, 0.35, 0.6) }
      }
      Glyph { anchors.centerIn: parent; size: 44; tone: Qt.rgba(1, 1, 1, 0.7); d: "M9 3v10.6A4 4 0 1 0 11 17V7h6V3z" }
    }

    Image {
      id: cover
      anchors.fill: parent
      source: widget.player ? widget.player.trackArtUrl : ""
      sourceSize: Qt.size(256, 256)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }
  }

  Label {
    id: title
    anchors { left: art.right; leftMargin: 14; right: parent.right; top: parent.top; topMargin: 1 }
    text: widget.player ? (widget.player.trackTitle || "Unknown") : "Nothing playing"
    font.pixelSize: 15
    font.weight: Font.DemiBold
  }

  Label {
    id: artist
    anchors { left: title.left; right: parent.right; top: title.bottom; topMargin: 1 }
    text: widget.player ? (widget.player.trackArtist || widget.player.identity || "") : "Start something and it shows up here"
    tone: 1
    font.pixelSize: 12
  }

  Column {
    id: words
    anchors.left: widget.tall ? parent.left : title.left
    anchors.right: parent.right
    anchors.top: widget.tall ? art.bottom : artist.bottom
    anchors.topMargin: widget.tall ? 16 : 8
    spacing: widget.tall ? 7 : 2

    Repeater {
      model: widget.lines.length === 0 ? 0 : widget.tall ? 5 : 2

      Label {
        required property int index
        readonly property int at: Math.max(0, widget.line) + index - (widget.tall && widget.line > 0 ? 1 : 0)
        readonly property bool current: at === widget.line
        width: words.width
        text: at < widget.lines.length ? (widget.lines[at].text || "♪") : ""
        tone: current ? 0 : 2
        font.pixelSize: widget.tall ? 15 : 13
        font.weight: current ? Font.DemiBold : Font.Medium
      }
    }
  }

  Meter {
    id: progress
    anchors.left: widget.tall ? parent.left : title.left
    anchors.right: parent.right
    anchors.bottom: controls.top
    anchors.bottomMargin: 5
    value: widget.length > 0 ? widget.position / widget.length : 0
  }

  Row {
    id: controls
    visible: widget.player !== null
    anchors.left: progress.left
    anchors.leftMargin: -4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -4
    spacing: 6

    Control { d: "M11 5v14L2 12zM22 5v14l-9-7z"; onPressed: if (widget.player.canGoPrevious) widget.player.previous() }
    Control { size: 20; d: widget.playing ? "M6 4h4.5v16H6zM13.5 4H18v16h-4.5z" : "M7 4v16l13-8z"; onPressed: if (widget.player.canTogglePlaying) widget.player.togglePlaying() }
    Control { d: "M13 5v14l9-7zM2 5v14l9-7z"; onPressed: if (widget.player.canGoNext) widget.player.next() }
  }

  Label {
    visible: widget.length > 0
    anchors.right: parent.right
    anchors.verticalCenter: controls.verticalCenter
    tone: 1
    font.pixelSize: 11
    text: Data.clock(widget.position) + " / " + Data.clock(widget.length)
  }
}
