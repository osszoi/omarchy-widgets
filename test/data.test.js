const fs = require("fs")
const path = require("path")
const vm = require("vm")
const assert = require("assert")

const D = {}
vm.createContext(D)
vm.runInContext(fs.readFileSync(path.join(__dirname, "..", "lib", "data.js"), "utf8"), D)
const plain = value => JSON.parse(JSON.stringify(value))
const at = (d, h, m) => new Date(2026, 10, d, h, m || 0)
const sec = date => date.getTime() / 1000

assert.strictEqual(D.money(74200, "EUR"), "€742")
assert.strictEqual(D.money(200000, "EUR"), "€2,000")
assert.strictEqual(D.money(-1250, "USD"), "-$13")
assert.strictEqual(D.money(500, "CHF"), "CHF 5")
assert.strictEqual(D.span(25 * 60), "25 min")
assert.strictEqual(D.span(125 * 60), "2 h 5 m")
assert.strictEqual(D.span(7200), "2 h")
assert.strictEqual(D.clock(92), "1:32")

// budget
const snapshot = { currency: "EUR", months: { "2026-11": { spentCents: 130000, reversedCents: 4200, incomeCents: 0, transactions: [
  { id: "x1", kind: "expense", amountCents: -10000 },
  { id: "x2", kind: "reversal", amountCents: 1200 },
  { id: "x3", kind: "income", amountCents: 99999 }
] } } }
let b = D.budget(snapshot, { months: { "2026-09": 2000 } }, [], 1500, at(14, 10))
assert.strictEqual(b.totalCents, 200000, "budget carries over from the last month that set one")
assert.strictEqual(b.remainingCents, 200000 - 130000 + 4200)
assert.strictEqual(b.daysLeft, 17)
assert.strictEqual(b.month, "November")
b = D.budget(snapshot, null, ["x1", "x2", "x3"], 1500, at(14, 10))
assert.strictEqual(b.totalCents, 150000, "falls back to the default budget")
assert.strictEqual(b.spentCents, (130000 - 10000) - (4200 - 1200), "excluded rows leave the math, income never counts")
assert.strictEqual(D.budget(null, null, [], 1500, at(14, 10)).known, false)
assert.strictEqual(D.budget({ months: {} }, null, [], 1000, at(14, 10)).remainingCents, 100000, "a month without rows is all budget")

// agenda
const events = [
  { title: "Gone", start: sec(at(14, 8)), end: sec(at(14, 9)), priority: 1 },
  { title: "Running", start: sec(at(14, 9, 30)), end: sec(at(14, 10, 30)), priority: 1, color: "#fff", account: "work" },
  { title: "Soon", start: sec(at(14, 10, 25)), end: sec(at(14, 11)), priority: 2 },
  { title: "Dropped", start: sec(at(14, 12)), end: sec(at(14, 13)), status: "cancelled" },
  { title: "Holiday", start: sec(at(15, 0)), end: sec(at(16, 0)), allDay: true },
  { title: "Late", start: sec(at(15, 17)), end: sec(at(15, 18)) },
  { title: "Far", start: sec(at(20, 9)), end: sec(at(20, 10)) }
]
let a = D.agenda(events, at(14, 10), 6)
assert.deepStrictEqual(plain(a.rows.map(r => r.kind === "day" ? "# " + r.label : r.title)), ["Running", "Soon", "# Tomorrow", "Holiday", "Late"], "a day header and its event need two rows, so Friday stays out")
assert.deepStrictEqual(plain(D.agenda(events, at(14, 10), 8).rows.map(r => r.title || r.label)), ["Running", "Soon", "Tomorrow", "Holiday", "Late", "Friday 20", "Far"])
assert.strictEqual(a.rows[0].live, true)
assert.strictEqual(a.rows[0].when, "09:30 – 10:30")
assert.strictEqual(a.rows[3].when, "All day")
assert.strictEqual(a.next, "now")
assert.strictEqual(a.weekday, "SATURDAY")
assert.strictEqual(a.day, 14)
assert.strictEqual(D.agenda(events, at(14, 10, 40), 6).next, "now", "the second meeting is still on")
assert.strictEqual(D.agenda(events, at(14, 11, 5), 6).next, "", "nothing else today")
assert.strictEqual(D.agenda(events.slice(2), at(14, 10), 6).next, "in 25 min")
a = D.agenda(events, at(14, 10), 3)
assert.deepStrictEqual(plain(a.rows.map(r => r.title || r.label)), ["Running", "Soon"], "a day header never ends the list")
assert.strictEqual(a.hidden, 3)
a = D.agenda(events, at(16, 12), 6)
assert.deepStrictEqual(plain(a.rows.map(r => r.title || r.label)), ["Friday 20", "Far"], "an empty two days shows the next thing coming")
assert.strictEqual(D.agenda([], at(14, 10), 6).rows.length, 0)

// machine
const s1 = D.cpuTimes("cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 1 2 3")
const s2 = D.cpuTimes("cpu  150 0 150 900 0 0 0 0 0 0\n")
assert.strictEqual(D.cpuUse(s1, s2), 0.5)
assert.strictEqual(D.cpuUse(s2, s2), 0)
assert.strictEqual(D.cpuTimes("garbage"), null)
const mem = D.memory("MemTotal:       67108864 kB\nMemFree: 1 kB\nMemAvailable:   50331648 kB\n")
assert.strictEqual(mem.totalGb, 64)
assert.strictEqual(mem.usedGb, 16)
assert.strictEqual(D.memory(""), null)
assert.strictEqual(D.processTicks("561119 (quick shell) S 1 2 3 0 -1 4194304 10 0 0 0 700 300 0 0 20 0 30 0 100 200 300"), 1000)
assert.strictEqual(D.disk("        1B-blocks        Avail\n1000000000000 400000000000\n").used, 0.6)
assert.deepStrictEqual(plain(D.history([1, 2, 3], 4, 3)), [2, 3, 4])

let g = D.gpu("NVIDIA GeForce RTX 5080, 38, 38, 70.16, 4831, 16303, P1, 14801, 6")
assert.strictEqual(g.name, "5080")
assert.strictEqual(g.temp, 38)
assert.strictEqual(g.clock, "ok")
assert.strictEqual(Math.round(g.memUsedGb * 10), 47)
assert.strictEqual(D.gpu("NVIDIA GeForce RTX 5080, 39, 4, 18.0, 4000, 16303, P8, 405, 52").clock, "starved")
assert.strictEqual(D.gpu("NVIDIA GeForce RTX 5080, 39, 0, 18.0, 4000, 16303, P8, 405, 1").clock, "low")
assert.strictEqual(D.gpu("No devices were found"), null)

assert.deepStrictEqual(plain(D.camGrid(4, 324, 324)), { cols: 2, rows: 2 })
assert.deepStrictEqual(plain(D.camGrid(4, 684, 144)), { cols: 4, rows: 1 })
assert.deepStrictEqual(plain(D.camGrid(4, 684, 324)), { cols: 2, rows: 2 })
assert.deepStrictEqual(plain(D.camGrid(1, 324, 324)), { cols: 1, rows: 1 })
assert.deepStrictEqual(plain(D.camGrid(6, 684, 504)), { cols: 2, rows: 3 }, "six cameras on a 4x3 tile")
assert.deepStrictEqual(plain(D.camGrid(5, 684, 504)), { cols: 2, rows: 3 })
assert.deepStrictEqual(plain(D.camGrid(5, 324, 864)), { cols: 1, rows: 5 }, "a 2x5 tile shows one camera a row")
assert.deepStrictEqual(plain(D.camGrid(4, 324, 864)), { cols: 1, rows: 4 })
assert.deepStrictEqual(plain(D.camGrid(3, 324, 144)), { cols: 2, rows: 2 }, "wide cells beat tall slivers, even with a hole")
assert.strictEqual(D.camName("puerta_principal"), "Puerta principal")
assert.strictEqual(D.stamp(at(14, 20, 31).getTime(), at(14, 21, 5).getTime()), "20:31")
assert.strictEqual(D.stamp(at(13, 9, 5).getTime(), at(14, 21, 5).getTime()), "YDAY 09:05")
assert.strictEqual(D.stamp(at(2, 9, 5).getTime(), at(14, 21, 5).getTime()), "2 NOV 09:05")

const lines = [{ t: 1000, text: "a" }, { t: 5000, text: "b" }, { t: 9000, text: "c" }]
assert.strictEqual(D.lyricLine(lines, 0), -1)
assert.strictEqual(D.lyricLine(lines, 5000), 1)
assert.strictEqual(D.lyricLine(lines, 99999), 2)
assert.strictEqual(D.lyricWait(lines, 4000), 1000)
assert.strictEqual(D.lyricWait(lines, 9500), -1)
console.log("data ok")

// printer
let p = D.printer({
  "sensor.a1_print_progress": { s: "62", u: "%" },
  "sensor.a1_print_status": { s: "running" },
  "sensor.a1_task_name": { s: "cable_clip_v3.3mf " },
  "sensor.a1_remaining_time": { s: "72", u: "min" },
  "sensor.a1_current_layer": { s: "148" },
  "sensor.a1_total_layer_count": { s: "240" },
  "sensor.a1_nozzle_temperature": { s: "220.4", u: "°C" },
  "sensor.a1_bed_temperature": { s: "unavailable" },
  "sensor.a1_ams_tray_2": { s: "PLA", a: { color: "#FF453AFF", active: true } },
  "sensor.a1_ams_tray_1": { s: "Empty", a: { color: "#00000000" } },
  "binary_sensor.a1_online": { s: "on" }
})
assert.strictEqual(p.found, true)
assert.strictEqual(p.progress, 0.62)
assert.strictEqual(p.label, "Printing")
assert.strictEqual(p.task, "cable_clip_v3.3mf", "names come with stray spaces")
assert.strictEqual(p.busy, true)
assert.strictEqual(p.remaining, 72 * 60)
assert.strictEqual(p.layer, 148)
assert.strictEqual(p.nozzle, 220.4)
assert.strictEqual(p.bed, null, "an unavailable sensor is no reading, not zero")
assert.deepStrictEqual(plain(p.trays), [{ color: "#000000", active: false, empty: true }, { color: "#FF453A", active: true, empty: false }])
assert.strictEqual(D.printer({ "sensor.a1_remaining_time": { s: "1.2", u: "h" } }).remaining, 4320)
assert.strictEqual(D.printer({ "sensor.a1_ams_1_tray_1": { s: "Bambu PLA Basic", a: { color: "#FFFFFFFF", active: false, empty: true } } }).trays[0].empty, true)
assert.strictEqual(D.printer({}).found, false)
assert.strictEqual(D.printer({ "sensor.a1_print_status": { s: "finish" } }).busy, false)
console.log("printer ok")
