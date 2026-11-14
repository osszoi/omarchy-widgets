import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../lib/data.js" as Data

// Stills of the frames Frigate has already decoded for detection, about one a second. No video is
// decoded here. A click opens the real stream in mpv.
Item {
  id: widget

  property var host
  readonly property var options: host.options
  readonly property string base: options.frigate || "http://localhost:5000"
  readonly property string stream: options.stream || "rtsp://localhost:8554/{cam}"
  readonly property real rate: Math.max(0.2, Math.min(5, Number(options.fps) || 1))
  readonly property bool rolling: host.live && !host.shielded && all.length > 0

  // cameras that are not Frigate's: a stream is only pulled while the tile has been in view for a moment,
  // and its last picture stays on disk so the cell is never blank
  readonly property var streams: Array.isArray(options.streams) ? options.streams : []
  readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/omarchy-widgets/cams"
  readonly property var all: cams.concat(streams.map(function(stream) {
    return { id: stream.id, name: stream.name || Data.camName(stream.id), online: true, pull: stream.url }
  }))
  property bool pulling: false

  onRollingChanged: if (!rolling) pulling = false

  Timer {
    interval: 2000
    running: widget.rolling && !widget.pulling && widget.streams.length > 0
    onTriggered: widget.pulling = true
  }

  Process {
    running: widget.streams.length > 0
    command: ["mkdir", "-p", widget.cacheDir]
  }

  property var cams: []
  property int frame: 0
  // grows while the shell itself is working hard, so the stills never become the load
  property int slowdown: 1
  property int lastTicks: -1
  property int busy: 0
  property int calm: 0
  readonly property var grid: Data.camGrid(all.length, width, height)

  property var asked: []

  function fetch(url, done) {
    var request = new XMLHttpRequest()
    request.onreadystatechange = function() {
      if (request.readyState === XMLHttpRequest.DONE) done(request.status === 200 ? request.responseText : "")
    }
    request.open("GET", url)
    request.send()
    asked = asked.filter(function(old) { return old.readyState !== XMLHttpRequest.DONE }).concat([request])
  }

  // an answer must not arrive for a tile that is already gone
  Component.onDestruction: asked.forEach(function(request) { request.abort() })

  function discover() {
    fetch(base + "/api/config", function(text) {
      var found = []
      try {
        var config = JSON.parse(text).cameras || {}
        var names = options.names || {}
        var skip = options.skip || []
        for (var id in config) {
          if (config[id].enabled === false || skip.indexOf(id) !== -1) continue
          found.push({ id: id, name: names[id] || Data.camName(id), online: true })
        }
      } catch (error) {
        found = []
      }
      cams = found
      if (found.length > 0) health()
    })
  }

  function health() {
    fetch(base + "/api/stats", function(text) {
      try {
        var stats = JSON.parse(text).cameras || {}
        var changed = false
        var next = cams.map(function(cam) {
          var online = !!stats[cam.id] && Number(stats[cam.id].camera_fps) > 0
          if (online !== cam.online) changed = true
          return { id: cam.id, name: cam.name, online: online }
        })
        if (changed) cams = next
      } catch (error) {
      }
    })
  }

  Timer {
    interval: Math.round(1000 / widget.rate) * widget.slowdown
    repeat: true
    running: widget.rolling
    triggeredOnStart: true
    onTriggered: widget.frame++
  }

  Timer {
    interval: 15000
    repeat: true
    running: widget.host.live
    triggeredOnStart: true
    onTriggered: widget.cams.length > 0 ? widget.health() : widget.discover()
  }

  Timer {
    interval: 5000
    repeat: true
    running: widget.rolling
    onTriggered: own.reload()
  }

  FileView {
    id: own
    path: "/proc/self/stat"
    printErrors: false
    onLoaded: {
      var ticks = Data.processTicks(text())
      // 100 ticks a second, 5 seconds between reads
      var cores = widget.lastTicks < 0 || ticks < 0 ? 0 : (ticks - widget.lastTicks) / 500
      widget.lastTicks = ticks
      widget.busy = cores > 0.15 ? widget.busy + 1 : 0
      widget.calm = cores < 0.06 ? widget.calm + 1 : 0
      if (widget.busy >= 2 && widget.slowdown < 8) { widget.slowdown *= 2; widget.busy = 0 }
      if (widget.calm >= 6 && widget.slowdown > 1) { widget.slowdown /= 2; widget.calm = 0 }
    }
  }

  Process { id: player }

  Repeater {
    model: widget.all

    Item {
      id: cell

      required property var modelData
      required property int index
      readonly property real gap: 6
      readonly property bool pulled: modelData.pull !== undefined
      readonly property string still: widget.cacheDir + "/" + modelData.id + ".jpg"
      readonly property bool wanted: pulled && widget.pulling
      // pictures that arrived since the stream was started, the first one is the one kept on disk
      property int fresh: 0
      readonly property bool current: !pulled || (wanted && puller.running && fresh > 2)
      property bool flip: false
      property bool seen: false
      readonly property int tall: Math.ceil(Math.max(height, width * 9 / 16) / 60) * 60

      x: (index % widget.grid.cols) * (width + gap)
      y: Math.floor(index / widget.grid.cols) * (height + gap)
      width: (widget.width - gap * (widget.grid.cols - 1)) / widget.grid.cols
      height: (widget.height - gap * (widget.grid.rows - 1)) / widget.grid.rows

      function load() {
        var back = flip ? first : second
        if (back.status === Image.Loading || !modelData.online) return
        if (pulled) {
          if (seen && !wanted) return
          back.source = "file://" + still + "?" + widget.frame
        } else {
          back.source = widget.base + "/api/" + modelData.id + "/latest.jpg?height=" + tall + "&quality=70&_=" + widget.frame
        }
      }

      function arrived(image) {
        if (image.status !== Image.Ready || image !== (flip ? first : second)) return
        flip = !flip
        seen = true
        if (wanted) fresh++
      }

      // true for a while after the far end hung up, so it is not hammered
      property bool resting: false

      onWantedChanged: fresh = 0

      Component.onCompleted: if (pulled) load()

      Process {
        id: puller
        // a binding, not a call: cells are rebuilt when the camera list changes and must pick the stream up again
        running: cell.wanted && !cell.resting
        // every frame is decoded: a ring cam sends a keyframe only every 10 to 20 seconds. 640x360 costs under 1% of a core
        command: ["ffmpeg", "-nostdin", "-loglevel", "error", "-rtsp_transport", "tcp", "-i", String(cell.modelData.pull || ""),
                  "-vf", "fps=" + widget.rate + ",scale=-2:360", "-q:v", "5", "-f", "image2", "-update", "1", "-atomic_writing", "1", "-y", cell.still]
        onExited: if (cell.wanted) { cell.resting = true; again.restart() }
      }

      Timer { id: again; interval: 10000; onTriggered: cell.resting = false }

      Connections {
        target: widget
        function onFrameChanged() { cell.load() }
      }

      ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "#14131c"

        Image {
          id: first
          anchors.fill: parent
          z: cell.flip ? 0 : 1
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          onStatusChanged: cell.arrived(first)
        }

        Image {
          id: second
          anchors.fill: parent
          z: cell.flip ? 1 : 0
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          onStatusChanged: cell.arrived(second)
        }

        Rectangle {
          z: 2
          anchors.fill: parent
          visible: !cell.modelData.online
          color: Qt.rgba(0.05, 0.05, 0.08, cell.seen ? 0.72 : 1)
        }

        Rectangle {
          z: 3
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: parent.height * 0.45
          gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) }
          }
        }

        Label {
          z: 4
          anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 8; bottom: parent.bottom; bottomMargin: 7 }
          text: cell.modelData.name
          font.pixelSize: 12
          font.weight: Font.DemiBold
        }

        Rectangle {
          z: 4
          anchors { right: parent.right; rightMargin: 8; top: parent.top; topMargin: 8 }
          width: badge.width + 14
          height: 17
          radius: 9
          color: !cell.modelData.online ? Qt.rgba(1, 0.27, 0.23, 0.85) : Qt.rgba(0, 0, 0, 0.45)

          Row {
            id: badge
            anchors.centerIn: parent
            spacing: 4
            Rectangle { visible: cell.modelData.online && cell.current; width: 6; height: 6; radius: 3; color: widget.host.theme.red; anchors.verticalCenter: parent.verticalCenter }
            Label { text: !cell.modelData.online ? "OFFLINE" : cell.current ? "LIVE" : "LAST"; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.5 }
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: !widget.host.editing
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          player.command = ["mpv", "--no-terminal", "--profile=low-latency", "--title=" + cell.modelData.name, cell.modelData.pull || widget.stream.replace("{cam}", cell.modelData.id)]
          player.startDetached()
        }
      }
    }
  }

  Label {
    visible: widget.all.length === 0
    anchors.centerIn: parent
    tone: 1
    font.pixelSize: 12
    text: "No cameras from Frigate"
  }
}
