// What the widgets show, worked out from what they read. Qt-free so node can run it (test/data.test.js).

var SYMBOLS = { USD: "$", EUR: "€", GBP: "£" }
var DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
var MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

function pad(n) {
  return n < 10 ? "0" + n : String(n)
}

function grouped(n) {
  return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

function money(cents, currency) {
  var symbol = SYMBOLS[currency] || (currency ? currency + " " : "")
  var whole = Math.round(Math.abs(cents) / 100)
  return (cents < 0 ? "-" : "") + symbol + grouped(whole)
}

function span(seconds) {
  var minutes = Math.max(0, Math.round(seconds / 60))
  if (minutes < 60) return minutes + " min"
  var hours = Math.floor(minutes / 60)
  return minutes % 60 === 0 ? hours + " h" : hours + " h " + (minutes % 60) + " m"
}

function clock(seconds) {
  var s = Math.max(0, Math.floor(seconds))
  return Math.floor(s / 60) + ":" + pad(s % 60)
}

function hhmm(date) {
  return pad(date.getHours()) + ":" + pad(date.getMinutes())
}

// ---- budget, same rules as eduardo.budget's Model.js

function monthKey(date) {
  return date.getFullYear() + "-" + pad(date.getMonth() + 1)
}

function toCents(value) {
  var n = Number(value)
  if (value === null || value === undefined || value === "" || !isFinite(n) || n < 0) return null
  return Math.round(n * 100)
}

// no value for the month -> last one set before it -> default
function budgetFor(budgets, key, fallback) {
  var months = (budgets && budgets.months) || {}
  if (months[key] !== undefined && toCents(months[key]) !== null) return toCents(months[key])
  var earlier = Object.keys(months).filter(function(k) { return k < key && toCents(months[k]) !== null }).sort()
  if (earlier.length > 0) return toCents(months[earlier[earlier.length - 1]])
  var cents = toCents(fallback)
  return cents === null ? 150000 : cents
}

function budget(snapshot, budgets, excludedIds, fallback, now) {
  var key = monthKey(now)
  var month = snapshot && snapshot.months ? snapshot.months[key] : null
  var listed = {}
  ;(excludedIds || []).forEach(function(id) { listed[id] = true })
  var spent = month ? Number(month.spentCents || 0) : 0
  var reversed = month ? Number(month.reversedCents || 0) : 0
  ;((month && month.transactions) || []).forEach(function(t) {
    if (!t.id || !listed[t.id] || t.kind === "income") return
    if (t.kind === "reversal") reversed -= Number(t.amountCents || 0)
    else spent -= -Number(t.amountCents || 0)
  })
  var total = budgetFor(budgets, key, fallback)
  var net = spent - reversed
  var lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
  return {
    known: !!snapshot && !!snapshot.months,
    month: MONTHS[now.getMonth()],
    totalCents: total,
    spentCents: net,
    remainingCents: total - net,
    used: total > 0 ? Math.max(0, Math.min(1, net / total)) : 1,
    daysLeft: lastDay - now.getDate() + 1,
    currency: (snapshot && snapshot.currency) || "EUR"
  }
}

// ---- agenda

function dayStart(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime() / 1000
}

function agenda(events, now, maxRows) {
  var nowSec = now.getTime() / 1000
  var today = dayStart(now)
  var tomorrow = dayStart(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1))
  var horizon = dayStart(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2))

  var upcoming = (events || []).filter(function(e) {
    return e && e.status !== "cancelled" && Number(e.end) > nowSec
  }).sort(function(a, b) { return a.start - b.start || a.priority - b.priority })

  var near = upcoming.filter(function(e) { return e.start < horizon })
  var shown = upcoming

  var rows = []
  var lastDay = today
  for (var i = 0; i < shown.length && rows.length < maxRows; i++) {
    var e = shown[i]
    var start = new Date(e.start * 1000)
    var day = Math.max(today, dayStart(start))
    if (day !== lastDay) {
      if (rows.length + 2 > maxRows) break
      rows.push({ kind: "day", label: day === tomorrow ? "Tomorrow" : DAYS[start.getDay()] + " " + start.getDate() })
      lastDay = day
    }
    rows.push({
      kind: "event",
      title: e.title || "(no title)",
      when: e.allDay ? "All day" : hhmm(start) + " – " + hhmm(new Date(e.end * 1000)),
      account: e.account || "",
      color: e.color || "",
      live: !e.allDay && e.start <= nowSec
    })
  }

  var next = ""
  for (var n = 0; n < near.length; n++) {
    if (near[n].allDay || near[n].start >= tomorrow) continue
    if (near[n].start <= nowSec) { next = "now"; break }
    next = "in " + span(near[n].start - nowSec)
    break
  }
  return { weekday: DAYS[now.getDay()].toUpperCase(), day: now.getDate(), rows: rows, next: next, hidden: Math.max(0, shown.length - rows.filter(function(r) { return r.kind === "event" }).length) }
}

// ---- machine

function cpuTimes(stat) {
  var line = String(stat || "").split("\n")[0].trim().split(/\s+/)
  if (line[0] !== "cpu") return null
  var total = 0
  for (var i = 1; i < line.length && i <= 8; i++) total += Number(line[i]) || 0
  return { total: total, idle: (Number(line[4]) || 0) + (Number(line[5]) || 0) }
}

function cpuUse(before, after) {
  if (!before || !after || after.total <= before.total) return 0
  return Math.max(0, Math.min(1, 1 - (after.idle - before.idle) / (after.total - before.total)))
}

function memory(meminfo) {
  var total = /MemTotal:\s+(\d+)/.exec(meminfo || "")
  var available = /MemAvailable:\s+(\d+)/.exec(meminfo || "")
  if (!total || !available) return null
  var totalKb = Number(total[1]), usedKb = totalKb - Number(available[1])
  return { totalGb: totalKb / 1048576, usedGb: usedKb / 1048576, used: usedKb / totalKb }
}

// own cpu time of a process in clock ticks, from /proc/<pid>/stat
function processTicks(stat) {
  var rest = String(stat || "").replace(/^.*\) /, "").split(" ")
  return rest.length > 13 ? (Number(rest[11]) || 0) + (Number(rest[12]) || 0) : -1
}

function disk(df) {
  // the header says "1B-blocks", so only the last line counts
  var rows = String(df || "").trim().split("\n")
  var numbers = rows[rows.length - 1].match(/\d+/g)
  if (!numbers || numbers.length < 2) return null
  var size = Number(numbers[0]), available = Number(numbers[1])
  return size > 0 ? { used: 1 - available / size, freeGb: available / 1073741824 } : null
}

function history(list, value, keep) {
  var next = list.concat([value])
  return next.length > keep ? next.slice(next.length - keep) : next
}

// nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,power.draw,memory.used,memory.total,pstate,clocks.mem,utilization.memory
function gpu(line) {
  var f = String(line || "").split(",").map(function(part) { return part.trim() })
  if (f.length < 9 || !isFinite(Number(f[1]))) return null
  var g = {
    name: f[0].replace(/^NVIDIA\s+/i, "").replace(/^GeForce\s+/i, "").replace(/^RTX\s+/i, ""),
    temp: Number(f[1]), use: (Number(f[2]) || 0) / 100, watts: Number(f[3]) || 0,
    memUsedGb: (Number(f[4]) || 0) / 1024, memTotalGb: (Number(f[5]) || 0) / 1024,
    pstate: f[6], memClock: Number(f[7]) || 0, memBus: (Number(f[8]) || 0) / 100
  }
  // parked memory clock with a busy memory bus is the scanout starvation that blanks the screen
  g.clock = g.memClock >= 2000 || g.memClock === 0 ? "ok" : g.memBus >= 0.25 ? "starved" : "low"
  return g
}

// ---- cameras: columns that keep the cells closest to 16:9

function camGrid(count, width, height) {
  var best = { cols: 1, rows: Math.max(1, count) }
  var bestError = Infinity
  for (var cols = 1; cols <= Math.max(1, count); cols++) {
    var rows = Math.ceil(count / cols)
    var error = Math.abs(Math.log((width / cols) / (height / rows) / (16 / 9))) + (cols * rows - count) * 0.35
    if (error < bestError) { best = { cols: cols, rows: rows }; bestError = error }
  }
  return best
}

function camName(id) {
  var words = String(id || "").replace(/[_-]+/g, " ").trim()
  return words.charAt(0).toUpperCase() + words.slice(1)
}

// ---- lyrics, lines as eduardo.youtube-music has them: { t: ms, text }. index of the line being sung, -1 before the first

function lyricLine(lines, ms) {
  var at = -1
  for (var i = 0; i < (lines || []).length; i++) {
    if (Number(lines[i].t) <= ms) at = i
    else break
  }
  return at
}

// ms until the line changes, so one timer can wait for exactly that
function lyricWait(lines, ms) {
  var at = lyricLine(lines, ms)
  var next = (lines || [])[at + 1]
  return next ? Math.max(30, Number(next.t) - ms) : -1
}

// ---- 3d printer, from the entities of Home Assistant's bambu_lab integration:
// { "sensor.a1_print_progress": { s: "62", u: "%", a: {...} }, ... }

var PRINT_STATES = { running: "Printing", pause: "Paused", finish: "Finished", failed: "Failed", idle: "Idle", prepare: "Preparing", slicing: "Slicing", offline: "Offline", init: "Starting" }

function reading(entity) {
  var n = Number(entity && entity.s)
  return entity && entity.s !== "" && isFinite(n) ? n : null
}

function printer(entities) {
  var out = { found: false, progress: 0, state: "", label: "", task: "", remaining: 0, layer: null, layers: null, nozzle: null, bed: null, trays: [] }
  var trays = {}
  for (var id in entities || {}) {
    var e = entities[id]
    var value = reading(e)
    out.found = true
    if (/_print_progress$/.test(id)) out.progress = (value || 0) / 100
    else if (/_print_status$/.test(id)) out.state = String(e.s || "").toLowerCase()
    else if (/_task_name$/.test(id)) out.task = /^(unknown|unavailable|)$/.test(String(e.s || "")) ? "" : String(e.s).trim()
    else if (/_remaining_time$/.test(id)) out.remaining = (value || 0) * (e.u === "h" ? 3600 : e.u === "s" ? 1 : 60)
    else if (/_current_layer$/.test(id)) out.layer = value
    else if (/_total_layer_count$/.test(id)) out.layers = value
    else if (/_nozzle_temperature$/.test(id)) out.nozzle = value
    else if (/_bed_temperature$/.test(id)) out.bed = value
    else {
      var tray = /_tray_(\d+)$/.exec(id)
      if (!tray) continue
      var color = e.a && typeof e.a.color === "string" ? e.a.color.slice(0, 7) : ""
      trays[tray[1]] = { color: /^#[0-9a-fA-F]{6}$/.test(color) ? color : "", active: !!(e.a && e.a.active), empty: !!(e.a && e.a.empty) || /^(empty|unknown|unavailable|)$/i.test(String(e.s || "")) }
    }
  }
  out.trays = Object.keys(trays).sort().map(function(key) { return trays[key] })
  out.label = PRINT_STATES[out.state] || (out.state ? out.state.charAt(0).toUpperCase() + out.state.slice(1) : "")
  out.busy = out.state === "running" || out.state === "pause" || out.state === "prepare" || out.state === "slicing"
  return out
}
