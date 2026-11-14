# omarchy-widgets

iPhone-style widgets on the Omarchy desktop: frosted glass tiles on a grid, under the windows.

| Widget | Shows | Reads |
|---|---|---|
| Agenda | today's date and the next meetings of every account | `~/.cache/omarchy-calendar/events.json` (eduardo.calendar) |
| Cameras | a still per camera, about one a second; click opens the stream in mpv | Frigate, `latest.jpg` of frames it already decoded |
| Now Playing | cover, title, progress, controls, synced lyrics | MPRIS; lyrics from `$XDG_RUNTIME_DIR/eduardo.youtube-music/now.json` |
| GPU | temperature, load, power, VRAM, memory clock | one `nvidia-smi -l 3` |
| System | CPU, memory, disk | `/proc`, one `df` a minute |
| Budget | what is left of the month | `~/.cache/omarchy-budget/state.json` (eduardo.budget) |
| Home | lights, scenes, doors, who is home | Home Assistant |
| 3D Printer | progress, time left, layers, AMS | Home Assistant's `bambu_lab` integration |

## Install

    ./install.sh

Links the folder as `eduardo.widgets` and enables it.

## Using it

- `omarchy-shell widgets peek` lifts the tiles above the windows and puts them back; Esc or a click outside also
  closes it. Bind it to a key in your Hyprland config, the global shortcut spawns no process:

      o.bind("SUPER + grave", "Widgets", hl.dsp.global("eduardo:widgets.peek"))

- **Edit** in the lifted view, `omarchy-shell widgets edit`, or holding a tile for a moment: the tiles wiggle. Drag to
  move, pull the corner of the selected one to resize, minus to remove, **+ Add widget** to add. **Done** or Esc saves.
- `omarchy-shell widgets status` says what it is doing.

To have the lifted view blur what is behind it, add a layer rule and tell the plugin about it in
`~/.config/omarchy-widgets/settings.json` (`{ "blurBehind": true }`), so the tiles turn into see-through glass there:

    hl.layer_rule({ match = { namespace = "^eduardo-widgets$" }, blur = true, ignore_alpha = 0.3 })

The layout is `~/.config/omarchy-widgets/layout.json`. Each item can carry a `cfg` object for its widget:

| Widget | `cfg` |
|---|---|
| Cameras | `frigate` (default `http://localhost:5000`), `fps` (0.2 to 5, default 1), `names` `{ id: "Name" }`, `skip` `[ids]`, `stream` (default `rtsp://localhost:8554/{cam}`), `streams` `[{ id, name, url }]` |
| Home | `tiles` `[{ entity, name, hold, icon }]`, `chips` `[{ entity, label, quiet }]` |

`streams` are cameras Frigate does not decode, such as an on-demand one in its restreamer. One `ffmpeg` per stream
writes a still a second, and only once the tile has been in view for two seconds; it stops the moment the tile is
out of sight. The last picture stays in `~/.cache/omarchy-widgets/cams`, so the cell shows it (marked LAST) until
a fresh one arrives.

## Home Assistant

`~/.config/omarchy-widgets/home-assistant.json`, readable only by you:

    { "url": "http://localhost:8123", "token": "<long-lived access token>" }

A tile marked `hold` only fires after a one second press, so a stray click on the desktop cannot open a door.

## What it costs

Nothing updates while the tiles cannot be seen: a tiled window on the workspace, 90 seconds without input, or the screen
being shared (then the agenda, cameras and budget also hide). Animations run on a change, never in a loop. Everything
is read from files other plugins already keep fresh, or from one long-lived helper, not polled with new processes.
The camera stills slow themselves down when the shell is busy.

## Adding a widget

1. `widgets/Name.qml`: an `Item` with `property var host`. `host` gives `theme`, `cols`, `rows`, `options`, `live`,
   `editing` and `shielded`. Update only while `host.live`.
2. A line in `TYPES` in `lib/layout.js` (name, blurb, the sizes it supports) and a `Component` in `Board.qml`.
3. What it shows goes in `lib/data.js` with a test.

## Tests

    node test/layout.test.js && node test/data.test.js
