import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "lib/layout.js" as Layout

// Widgets on the desktop, under the windows. "peek" lifts them above the windows for a look,
// "edit" does the same with the tiles unlocked. Nothing updates while they cannot be seen.
Item {
  id: root

  // injected by omarchy-shell
  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/omarchy-widgets"
  readonly property string currentDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/current"
  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")).replace(/\/$/, "")

  property string mode: "desktop"
  property url glass: ""
  property string saved: ""
  property var stored: null
  property string placed: ""
  property bool storeRead: false
  property bool covered: false
  property bool sharing: false

  function finish() {
    if (mode === "edit") save()
    mode = "desktop"
  }

  function save() {
    if (!surface.item) return
    var text = Layout.serialize(surface.item.items(""))
    if (text === saved) return
    saved = text
    stored = Layout.parse(text)
    placed = JSON.stringify(surface.item.items(""))
    layoutFile.setText(text)
  }

  Theme { id: look }

  Process {
    running: true
    command: ["mkdir", "-p", root.configDir]
  }

  FileView {
    id: layoutFile
    path: root.configDir + "/layout.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var content = text()
      // our own save coming back
      if (root.storeRead && content === root.saved) return
      root.saved = content
      root.stored = Layout.parse(content)
      root.storeRead = true
      if (surface.item) surface.item.place()
    }
    onLoadFailed: {
      root.storeRead = true
      if (surface.item) surface.item.place()
    }
  }

  // the tiles' glass is a blurred copy of the wallpaper, made once per wallpaper
  Process {
    id: frost
    command: [root.pluginDir + "/bin/widgets-glass"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var path = String(text).trim()
        if (path !== "") root.glass = "file://" + path
      }
    }
  }

  FileView {
    path: root.currentDir
    watchChanges: true
    printErrors: false
    onFileChanged: if (!frost.running) frost.running = true
  }

  FileView {
    path: root.currentDir + "/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var found = /^accent\s*=\s*"(#[0-9a-fA-F]{6})"/m.exec(text())
      if (found) look.accent = found[1]
    }
  }

  IdleMonitor {
    id: away
    timeout: 90
    respectInhibitors: false
  }

  Timer { id: placing; interval: 80; onTriggered: if (surface.item) surface.item.place() }
  Timer { id: settle; interval: 150; onTriggered: { Hyprland.refreshToplevels(); assess.restart() } }
  Timer { id: assess; interval: 200; onTriggered: if (surface.item) surface.item.assess() }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "screencast") root.sharing = String(event.data).split(",")[0] === "1"
      else if (/^(openwindow|closewindow|movewindow|changefloatingmode|workspace|focusedmon|fullscreen|activespecial)/.test(event.name)) settle.restart()
    }
  }

  IpcHandler {
    target: "widgets"

    function peek(): void { root.mode === "desktop" ? root.mode = "peek" : root.finish() }
    function edit(): void { root.mode = "edit" }
    function hide(): void { root.finish() }
    function reload(): void { layoutFile.reload() }
    function status(): string {
      return JSON.stringify({ mode: root.mode, covered: root.covered, away: away.isIdle, sharing: root.sharing,
                              live: surface.item ? surface.item.live : false, tiles: surface.item ? surface.item.items("").length : 0 })
    }
  }

  LazyLoader {
    id: surface
    active: Quickshell.screens.length > 0

    PanelWindow {
      id: window

      readonly property var monitor: Hyprland.monitorFor(screen)
      readonly property bool lifted: root.mode !== "desktop"
      readonly property bool live: lifted || (!root.covered && !away.isIdle)
      readonly property real inset: monitor && monitor.lastIpcObject && monitor.lastIpcObject.reserved ? Number(monitor.lastIpcObject.reserved[1]) || 0 : 0

      function items(skip) { return board.items(skip) }

      // the window gets its size in steps, and tiles are only rebuilt when the result differs
      function place() {
        if (!root.storeRead || board.width <= 0) return
        var next = root.stored ? Layout.place(board.grid, root.stored) : Layout.starter(board.grid)
        var key = JSON.stringify(next)
        if (key === root.placed) return
        root.placed = key
        board.load(next)
      }

      // tiled windows fill the screen, so one of them means the tiles are out of sight
      function assess() {
        var workspace = monitor ? monitor.activeWorkspace : null
        var windows = workspace ? workspace.toplevels.values : []
        var tiled = 0
        for (var i = 0; i < windows.length; i++) {
          var info = windows[i].lastIpcObject
          if (!info || info.floating !== true) tiled++
        }
        root.covered = tiled > 0
      }

      screen: Quickshell.screens[0]
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.namespace: "eduardo-widgets"
      WlrLayershell.layer: lifted ? WlrLayer.Overlay : WlrLayer.Bottom
      WlrLayershell.keyboardFocus: lifted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      Component.onCompleted: { Hyprland.refreshMonitors(); settle.restart() }

      Board {
        id: board
        anchors.fill: parent
        theme: look
        glass: root.glass
        inset: window.inset
        lifted: window.lifted
        editing: root.mode === "edit"
        live: window.live
        shielded: root.sharing
        focus: true

        onWidthChanged: placing.restart()
        onHeightChanged: placing.restart()
        onInsetChanged: placing.restart()
        onEdited: root.save()
        onEditWanted: root.mode = "edit"
        onDismissed: root.finish()
        Keys.onEscapePressed: root.finish()
      }
    }
  }
}
