import QtQuick
import Quickshell.Io
import "../lib/data.js" as Data

// One nvidia-smi that keeps printing a line every few seconds, and only while the tile can be seen.
Item {
  id: widget

  property var host
  readonly property bool wide: host.cols > 1
  property var gpu: null
  property var past: []
  readonly property var states: ({
    ok: { text: "mem clock ok", ink: "#7ef0a0", fill: Qt.rgba(0.19, 0.82, 0.35, 0.18), dot: host.theme.green },
    low: { text: "mem clock low", ink: "#ffd27a", fill: Qt.rgba(1, 0.62, 0.04, 0.2), dot: host.theme.orange },
    starved: { text: "mem clock starved", ink: "#ffb3ad", fill: Qt.rgba(1, 0.27, 0.23, 0.26), dot: host.theme.red }
  })
  readonly property var clock: states[gpu ? gpu.clock : "ok"]

  Process {
    running: widget.host.live
    command: ["nvidia-smi", "--query-gpu=name,temperature.gpu,utilization.gpu,power.draw,memory.used,memory.total,pstate,clocks.mem,utilization.memory",
              "--format=csv,noheader,nounits", "-l", "3"]
    stdout: SplitParser {
      onRead: line => {
        var sample = Data.gpu(line)
        if (!sample) return
        widget.gpu = sample
        widget.past = Data.history(widget.past, sample.use, 40)
      }
    }
  }

  Label { id: cap; text: "GPU"; caps: true; tone: 1; font.pixelSize: 11 }
  Label { anchors.right: widget.wide ? left.right : parent.right; text: widget.gpu ? widget.gpu.name : ""; caps: true; tone: 2; font.pixelSize: 11 }

  Item {
    id: left
    width: widget.wide ? parent.width / 2 - 8 : parent.width
    height: parent.height

    Label {
      id: temp
      anchors.top: parent.top
      anchors.topMargin: 21
      text: widget.gpu ? widget.gpu.temp + "°" : "—"
      font.pixelSize: 30
      font.weight: Font.DemiBold
      font.letterSpacing: -0.6
    }

    Label {
      anchors.top: temp.bottom
      anchors.topMargin: 1
      tone: 1
      font.pixelSize: 11
      text: widget.gpu ? Math.round(widget.gpu.use * 100) + " %  ·  " + Math.round(widget.gpu.watts) + " W" : "no reading"
    }

    Rectangle {
      id: pill
      anchors.bottom: parent.bottom
      visible: widget.gpu !== null
      width: pillRow.width + 16
      height: 19
      radius: 10
      color: widget.clock.fill

      Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 5
        Rectangle { width: 6; height: 6; radius: 3; color: widget.clock.dot; anchors.verticalCenter: parent.verticalCenter }
        Label { text: widget.clock.text; color: widget.clock.ink; font.pixelSize: 10; font.weight: Font.DemiBold }
      }
    }

    Meter {
      id: vram
      anchors { left: parent.left; right: parent.right; bottom: pill.top; bottomMargin: 9 }
      value: widget.gpu && widget.gpu.memTotalGb > 0 ? widget.gpu.memUsedGb / widget.gpu.memTotalGb : 0
      fill: widget.host.theme.teal
    }

    Label {
      anchors.bottom: vram.top
      anchors.bottomMargin: 5
      tone: 1
      font.pixelSize: 11
      text: widget.gpu ? "VRAM " + widget.gpu.memUsedGb.toFixed(1) + " / " + Math.round(widget.gpu.memTotalGb) + " GB" : ""
    }
  }

  Item {
    visible: widget.wide
    anchors { left: left.right; leftMargin: 16; right: parent.right; top: parent.top; bottom: parent.bottom }

    Label { text: "Load"; caps: true; tone: 1; font.pixelSize: 11 }
    Label { anchors.right: parent.right; tone: 2; font.pixelSize: 11; text: widget.gpu ? widget.gpu.pstate + "  ·  " + widget.gpu.memClock + " MHz" : "" }
    Spark {
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: parent.top; topMargin: 26 }
      values: widget.past
      line: widget.host.theme.teal
    }
  }
}
