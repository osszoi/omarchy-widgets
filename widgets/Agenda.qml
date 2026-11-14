import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/data.js" as Data

// Reads the events eduardo.calendar keeps synced for every account. Nothing is fetched here.
Item {
  id: widget

  property var host
  readonly property bool tall: host.rows > 1
  property var events: []
  property bool synced: false
  property date now: new Date()
  readonly property var view: Data.agenda(events, now, tall ? 6 : 3)

  FileView {
    path: Quickshell.env("HOME") + "/.cache/omarchy-calendar/events.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        widget.events = JSON.parse(text()).events || []
        widget.synced = true
      } catch (error) {
        widget.events = []
      }
      widget.now = new Date()
    }
  }

  // "in 25 min" only has to be right to the minute
  Timer {
    interval: 30000
    repeat: true
    running: widget.host.live
    triggeredOnStart: true
    onTriggered: widget.now = new Date()
  }

  Item {
    id: head
    width: widget.tall ? parent.width : 92
    height: widget.tall ? 62 : parent.height

    Label { id: weekday; text: widget.view.weekday; color: widget.host.theme.red; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.6 }
    Label { id: day; anchors.top: weekday.bottom; anchors.topMargin: -2; text: widget.view.day; font.pixelSize: 40; font.weight: Font.DemiBold; font.letterSpacing: -0.8 }

    Rectangle {
      visible: widget.view.next !== ""
      anchors.right: widget.tall ? parent.right : undefined
      anchors.left: widget.tall ? undefined : parent.left
      anchors.top: widget.tall ? parent.top : undefined
      anchors.bottom: widget.tall ? undefined : parent.bottom
      width: next.width + 20
      height: 24
      radius: 12
      color: widget.view.next === "now" ? Qt.rgba(1, 0.27, 0.23, 0.3) : Qt.rgba(1, 1, 1, 0.12)
      Label { id: next; anchors.centerIn: parent; text: widget.view.next; font.pixelSize: 11; font.weight: Font.DemiBold }
    }
  }

  Column {
    anchors.left: widget.tall ? parent.left : head.right
    anchors.leftMargin: widget.tall ? 0 : 10
    anchors.right: parent.right
    anchors.top: widget.tall ? head.bottom : parent.top
    anchors.topMargin: widget.tall ? 6 : 0
    spacing: 9

    Repeater {
      model: widget.view.rows

      Item {
        required property var modelData
        readonly property bool heading: modelData.kind === "day"
        width: parent.width
        height: heading ? 16 : 34

        Label {
          visible: parent.heading
          anchors.bottom: parent.bottom
          text: parent.heading ? modelData.label : ""
          caps: true
          tone: 2
          font.pixelSize: 11
        }

        Rectangle {
          id: stripe
          visible: !parent.heading
          width: 4
          height: parent.height
          radius: 2
          color: modelData.color || widget.host.theme.blue
        }

        Label {
          visible: !parent.heading
          anchors { left: stripe.right; leftMargin: 9; right: parent.right; top: parent.top; topMargin: -1 }
          text: parent.heading ? "" : modelData.title
          font.pixelSize: 14
          font.weight: Font.DemiBold
        }

        Label {
          visible: !parent.heading
          anchors { left: stripe.right; leftMargin: 9; right: parent.right; bottom: parent.bottom; bottomMargin: -1 }
          text: parent.heading ? "" : (modelData.live ? "now  ·  " : "") + modelData.when + (modelData.account ? "  ·  " + modelData.account : "")
          tone: 1
          font.pixelSize: 11
        }
      }
    }
  }

  Label {
    visible: widget.view.rows.length === 0
    anchors.left: widget.tall ? parent.left : head.right
    anchors.leftMargin: widget.tall ? 0 : 10
    anchors.top: widget.tall ? head.bottom : parent.top
    anchors.topMargin: widget.tall ? 10 : 4
    tone: 1
    font.pixelSize: 12
    text: widget.synced ? "Nothing coming up" : "Calendar not synced"
  }
}
