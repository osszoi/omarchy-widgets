// Grid math for the board. Qt-free so node can run it (test/layout.test.js).

var TYPES = {
  agenda: { name: "Agenda", blurb: "Next meetings from every calendar account", sizes: [[2, 2], [2, 1]], guarded: true },
  cams: { name: "Cameras", blurb: "Stills from Frigate, about one a second", sizes: [[2, 2], [4, 2], [4, 3], [4, 4], [2, 3], [2, 4], [2, 5], [2, 6], [4, 1], [2, 1]], guarded: true },
  playing: { name: "Now Playing", blurb: "Whatever is playing, with lyrics from YouTube Music", sizes: [[2, 1], [2, 2]] },
  gpu: { name: "GPU", blurb: "Temperature, load, memory and the memory clock", sizes: [[1, 1], [2, 1]] },
  budget: { name: "Budget", blurb: "What is left of the month", sizes: [[1, 1], [2, 1]], guarded: true },
  home: { name: "Home", blurb: "Lights, scenes and doors from Home Assistant", sizes: [[2, 2], [4, 2], [2, 1]] },
  printer: { name: "3D Printer", blurb: "Print progress from Home Assistant", sizes: [[2, 1], [1, 1]] },
  system: { name: "System", blurb: "CPU, memory and disk", sizes: [[2, 1], [1, 1]] }
}

var STARTER = [
  { type: "agenda", col: 0, row: 0, w: 2, h: 2 },
  { type: "cams", col: 2, row: 0, w: 2, h: 2 },
  { type: "playing", col: 4, row: 0, w: 2, h: 1 },
  { type: "printer", col: 4, row: 1, w: 2, h: 1 },
  { type: "gpu", col: 6, row: 0, w: 1, h: 1 },
  { type: "budget", col: 7, row: 0, w: 1, h: 1 },
  { type: "system", col: 6, row: 1, w: 2, h: 1 },
  { type: "home", col: 8, row: 0, w: 2, h: 2 }
]

function metrics(width, height, unit, gap, margin, top) {
  var pitch = unit + gap
  var cols = Math.max(1, Math.floor((width - 2 * margin + gap) / pitch))
  var rows = Math.max(1, Math.floor((height - top - 2 * margin + gap) / pitch))
  return {
    unit: unit, gap: gap, pitch: pitch, cols: cols, rows: rows,
    x: Math.round((width - (cols * pitch - gap)) / 2),
    y: top + Math.round((height - top - (rows * pitch - gap)) / 2)
  }
}

function rect(m, item) {
  return {
    x: m.x + item.col * m.pitch, y: m.y + item.row * m.pitch,
    width: item.w * m.pitch - m.gap, height: item.h * m.pitch - m.gap
  }
}

function cellAt(m, px, py) {
  // + 0 turns a -0 into 0
  return { col: Math.round((px - m.x) / m.pitch) + 0, row: Math.round((py - m.y) / m.pitch) + 0 }
}

function inside(m, item) {
  return item.col >= 0 && item.row >= 0 && item.col + item.w <= m.cols && item.row + item.h <= m.rows
}

function overlaps(a, b) {
  return a.col < b.col + b.w && b.col < a.col + a.w && a.row < b.row + b.h && b.row < a.row + a.h
}

function free(m, items, item, ignoreId) {
  if (!inside(m, item)) return false
  for (var i = 0; i < items.length; i++) {
    if (items[i].id !== ignoreId && overlaps(items[i], item)) return false
  }
  return true
}

// closest free spot to where the tile was dropped, null when the board is full
function nearestFree(m, items, item, ignoreId) {
  var best = null
  var bestDistance = Infinity
  for (var row = 0; row + item.h <= m.rows; row++) {
    for (var col = 0; col + item.w <= m.cols; col++) {
      var distance = (col - item.col) * (col - item.col) + (row - item.row) * (row - item.row)
      if (distance >= bestDistance) continue
      if (!free(m, items, { col: col, row: row, w: item.w, h: item.h }, ignoreId)) continue
      best = { col: col, row: row }
      bestDistance = distance
    }
  }
  return best
}

function allowed(type, w, h) {
  var sizes = TYPES[type] ? TYPES[type].sizes : []
  for (var i = 0; i < sizes.length; i++) if (sizes[i][0] === w && sizes[i][1] === h) return true
  return false
}

// the size a widget supports that is closest to what the grip was dragged to
function snapSize(type, w, h) {
  var sizes = TYPES[type] ? TYPES[type].sizes : [[1, 1]]
  var best = sizes[0]
  var bestDistance = Infinity
  for (var i = 0; i < sizes.length; i++) {
    var distance = (sizes[i][0] - w) * (sizes[i][0] - w) + (sizes[i][1] - h) * (sizes[i][1] - h)
    if (distance < bestDistance) { best = sizes[i]; bestDistance = distance }
  }
  return { w: best[0], h: best[1] }
}

function starter(m) {
  var width = 10, height = 2
  var col = Math.max(0, Math.floor((m.cols - width) / 2))
  var row = Math.max(0, Math.floor((m.rows - height) / 2))
  return place(m, STARTER.map(function(item, index) {
    return { id: item.type + "-" + (index + 1), type: item.type, col: item.col + col, row: item.row + row, w: item.w, h: item.h, cfg: {} }
  }))
}

// whatever the file says, what comes out fits the board: known types, allowed sizes, no overlaps
function place(m, wanted) {
  var placed = []
  var seen = {}
  for (var i = 0; i < wanted.length; i++) {
    var raw = wanted[i]
    if (!raw || !TYPES[raw.type]) continue
    var size = allowed(raw.type, raw.w, raw.h) ? { w: raw.w, h: raw.h } : snapSize(raw.type, Number(raw.w) || 1, Number(raw.h) || 1)
    var id = raw.id && !seen[raw.id] ? String(raw.id) : nextId(raw.type, seen)
    var item = { id: id, type: raw.type, col: Math.round(Number(raw.col) || 0), row: Math.round(Number(raw.row) || 0), w: size.w, h: size.h, cfg: raw.cfg && typeof raw.cfg === "object" ? raw.cfg : {} }
    item.col = Math.max(0, Math.min(m.cols - item.w, item.col))
    item.row = Math.max(0, Math.min(m.rows - item.h, item.row))
    if (!free(m, placed, item)) {
      var spot = nearestFree(m, placed, item)
      if (!spot) continue
      item.col = spot.col
      item.row = spot.row
    }
    seen[id] = true
    placed.push(item)
  }
  return placed
}

function nextId(type, seen) {
  var n = 1
  while (seen[type + "-" + n]) n++
  return type + "-" + n
}

function parse(text) {
  try {
    var parsed = JSON.parse(text)
    return parsed && Array.isArray(parsed.items) ? parsed.items : null
  } catch (error) {
    return null
  }
}

function serialize(items) {
  return JSON.stringify({ version: 1, items: items }, null, 2) + "\n"
}
