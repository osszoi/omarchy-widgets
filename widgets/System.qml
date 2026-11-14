import QtQuick
import Quickshell.Io
import "../lib/data.js" as Data

// /proc is read in place, no helper process. The only command is one df a minute.
Item {
  id: widget

  property var host
  readonly property bool wide: host.cols > 1

  property var before: null
  property real cpu: 0
  property var cpuPast: []
  property var mem: null
  property var memPast: []
  property real load: 0
  property var disk: null

  function sample() {
    statFile.reload()
    memFile.reload()
    loadFile.reload()
  }

  Timer {
    interval: 3000
    repeat: true
    running: widget.host.live
    triggeredOnStart: true
    onTriggered: widget.sample()
  }

  Timer {
    interval: 60000
    repeat: true
    running: widget.host.live
    triggeredOnStart: true
    onTriggered: if (!df.running) df.running = true
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    printErrors: false
    onLoaded: {
      var now = Data.cpuTimes(text())
      if (widget.before && now) {
        widget.cpu = Data.cpuUse(widget.before, now)
        widget.cpuPast = Data.history(widget.cpuPast, widget.cpu, 40)
      }
      widget.before = now
    }
  }

  FileView {
    id: memFile
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: {
      widget.mem = Data.memory(text())
      if (widget.mem) widget.memPast = Data.history(widget.memPast, widget.mem.used, 40)
    }
  }

  FileView {
    id: loadFile
    path: "/proc/loadavg"
    printErrors: false
    onLoaded: widget.load = Number(String(text()).split(" ")[0]) || 0
  }

  Process {
    id: df
    command: ["df", "-B1", "--output=size,avail", "/"]
    stdout: StdioCollector { onStreamFinished: widget.disk = Data.disk(text) }
  }

  component Figure: Row {
    property string value: ""
    property string unit: ""
    spacing: 3
    Label { text: parent.value; font.pixelSize: 22; font.weight: Font.DemiBold; font.letterSpacing: -0.4 }
    Label { text: parent.unit; tone: 1; font.pixelSize: 11; font.weight: Font.DemiBold; anchors.baseline: parent.children[0].baseline }
  }

  Row {
    anchors.fill: parent
    spacing: 12

    Item {
      width: widget.wide ? (parent.width - 24) / 3 : parent.width
      height: parent.height

      Label { id: cpuCap; text: "CPU"; caps: true; tone: 1; font.pixelSize: 11 }
      Figure { id: cpuFigure; anchors.top: cpuCap.bottom; anchors.topMargin: 4; value: Math.round(widget.cpu * 100); unit: "%" }
      Label { anchors.top: cpuFigure.bottom; anchors.topMargin: 1; tone: 1; font.pixelSize: 11; text: "load " + widget.load.toFixed(2) }
      Spark {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 34
        values: widget.cpuPast
        line: "#9a8fff"
      }
    }

    Item {
      visible: widget.wide
      width: (parent.width - 24) / 3
      height: parent.height

      Label { id: memCap; text: "Memory"; caps: true; tone: 1; font.pixelSize: 11 }
      Figure {
        id: memFigure
        anchors.top: memCap.bottom; anchors.topMargin: 4
        value: widget.mem ? Math.round(widget.mem.usedGb) : "—"
        unit: widget.mem ? "/ " + Math.round(widget.mem.totalGb) + " GB" : ""
      }
      Label { anchors.top: memFigure.bottom; anchors.topMargin: 1; tone: 1; font.pixelSize: 11; text: widget.mem ? Math.round(widget.mem.used * 100) + " %" : "" }
      Spark {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 34
        values: widget.memPast
        line: widget.host.theme.teal
      }
    }

    Item {
      visible: widget.wide
      width: (parent.width - 24) / 3
      height: parent.height

      Label { id: diskCap; text: "Disk"; caps: true; tone: 1; font.pixelSize: 11 }
      Figure { id: diskFigure; anchors.top: diskCap.bottom; anchors.topMargin: 4; value: widget.disk ? Math.round(widget.disk.used * 100) : "—"; unit: "%" }
      Label { anchors.top: diskFigure.bottom; anchors.topMargin: 1; tone: 1; font.pixelSize: 11; text: widget.disk ? Math.round(widget.disk.freeGb) + " GB free" : "" }
      Meter {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 10 }
        height: 7
        value: widget.disk ? widget.disk.used : 0
        fill: widget.disk && widget.disk.used > 0.9 ? widget.host.theme.red : widget.host.theme.orange
      }
    }
  }
}
