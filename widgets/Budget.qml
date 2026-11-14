import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/data.js" as Data

// Reads what eduardo.budget already syncs. Nothing is fetched here.
Item {
  id: widget

  property var host
  readonly property string home: Quickshell.env("HOME")
  readonly property bool wide: host.cols > 1

  property var snapshot: null
  property var budgets: null
  property var excluded: []
  property real fallback: 1500
  property date today: new Date()
  readonly property var view: Data.budget(snapshot, budgets, excluded, fallback, today)
  readonly property bool over: view.remainingCents < 0

  function parsed(text) {
    try { return JSON.parse(text) } catch (error) { return null }
  }

  Connections {
    target: widget.host
    function onLiveChanged() { if (widget.host.live) widget.today = new Date() }
  }

  FileView {
    path: widget.home + "/.cache/omarchy-budget/state.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { widget.snapshot = widget.parsed(text()); widget.today = new Date() }
  }

  FileView {
    path: widget.home + "/.config/omarchy-budget/budgets.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: widget.budgets = widget.parsed(text())
  }

  FileView {
    path: widget.home + "/.config/omarchy-budget/excluded.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { var file = widget.parsed(text()); widget.excluded = file && Array.isArray(file.ids) ? file.ids : [] }
  }

  FileView {
    path: widget.home + "/.config/omarchy-budget/config.json"
    printErrors: false
    onLoaded: { var file = widget.parsed(text()); if (file && Number(file.defaultBudget) > 0) widget.fallback = Number(file.defaultBudget) }
  }

  Label { id: month; text: widget.view.month; caps: true; tone: 1; font.pixelSize: 11 }

  Label {
    id: amount
    anchors.top: month.bottom
    anchors.topMargin: 7
    width: widget.wide ? parent.width / 2 : parent.width
    text: widget.view.known ? Data.money(Math.abs(widget.view.remainingCents), widget.view.currency) : "—"
    color: widget.over ? widget.host.theme.red : "#ffffff"
    font.pixelSize: 30
    font.weight: Font.DemiBold
    font.letterSpacing: -0.6
  }

  Label {
    anchors.top: amount.bottom
    anchors.topMargin: 1
    width: amount.width
    tone: 1
    font.pixelSize: 11
    text: !widget.view.known ? "Budget not synced" : (widget.over ? "over " : "left of ") + Data.money(widget.view.totalCents, widget.view.currency)
  }

  Column {
    visible: widget.wide && widget.view.known
    anchors.right: parent.right
    anchors.top: month.bottom
    anchors.topMargin: 9
    width: parent.width / 2 - 12
    spacing: 9

    Repeater {
      model: [
        { name: "Spent", value: Data.money(widget.view.spentCents, widget.view.currency) },
        { name: "A day", value: Data.money(Math.max(0, widget.view.remainingCents) / widget.view.daysLeft, widget.view.currency) }
      ]

      Item {
        required property var modelData
        width: parent.width
        height: 16
        Label { text: modelData.name; tone: 1; font.pixelSize: 11 }
        Label { anchors.right: parent.right; text: modelData.value; font.pixelSize: 12; font.weight: Font.DemiBold }
      }
    }
  }

  Meter {
    id: bar
    anchors { left: parent.left; right: parent.right; bottom: foot.top; bottomMargin: 8 }
    height: 7
    value: widget.view.known ? widget.view.used : 0
    fill: widget.over ? widget.host.theme.red : widget.view.used > 0.85 ? widget.host.theme.orange : widget.host.theme.green
    fillEnd: widget.over ? "#ff8a80" : widget.view.used > 0.85 ? "#ffd27a" : "#a4f06a"
  }

  Item {
    id: foot
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: 14
    Label { tone: 1; font.pixelSize: 11; text: widget.view.known ? Math.round(widget.view.used * 100) + " % spent" : "" }
    Label { anchors.right: parent.right; tone: 1; font.pixelSize: 11; text: widget.view.daysLeft + (widget.view.daysLeft === 1 ? " day" : " days") }
  }
}
