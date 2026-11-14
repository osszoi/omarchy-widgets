const fs = require("fs")
const path = require("path")
const vm = require("vm")
const assert = require("assert")

const L = {}
vm.createContext(L)
vm.runInContext(fs.readFileSync(path.join(__dirname, "..", "lib", "layout.js"), "utf8"), L)
const plain = value => JSON.parse(JSON.stringify(value))

const m = L.metrics(5120, 1440, 160, 20, 40, 35)
assert.strictEqual(m.cols, 28)
assert.strictEqual(m.rows, 7)
assert.strictEqual(m.x + m.cols * m.pitch - m.gap + m.x, 5120, "grid is centred")
assert(m.y >= 35 + 40, "grid stays under the bar")

const big = L.rect(m, { col: 0, row: 0, w: 2, h: 2 })
assert.deepStrictEqual([big.width, big.height], [340, 340])
assert.deepStrictEqual(plain(L.cellAt(m, big.x + 70, big.y - 60)), { col: 0, row: 0 }, "drops snap to the nearest cell")
assert.deepStrictEqual(plain(L.cellAt(m, big.x + 100, big.y + 100)), { col: 1, row: 1 })

const items = L.starter(m)
assert.strictEqual(items.length, 8)
for (const a of items) {
  assert(L.inside(m, a), a.id + " is on the board")
  assert(L.allowed(a.type, a.w, a.h), a.id + " has a size its widget supports")
  for (const b of items) if (a !== b) assert(!L.overlaps(a, b), a.id + " overlaps " + b.id)
}
assert.strictEqual(new Set(items.map(i => i.id)).size, 8, "ids are unique")

const agenda = items[0]
assert(!L.free(m, items, { col: agenda.col + 1, row: agenda.row, w: 1, h: 1 }), "occupied cell is not free")
assert(L.free(m, items, { col: agenda.col + 1, row: agenda.row, w: 2, h: 2 }, items[1].id) === false)
assert(L.free(m, items, agenda, agenda.id), "a tile does not block itself")
const spot = L.nearestFree(m, items, { col: agenda.col, row: agenda.row, w: 1, h: 1 })
assert(spot && L.free(m, items, { col: spot.col, row: spot.row, w: 1, h: 1 }), "nearest free spot is really free")
assert(Math.abs(spot.col - agenda.col) + Math.abs(spot.row - agenda.row) <= 2, "and it is close by")

assert.deepStrictEqual(plain(L.snapSize("cams", 3, 2)), { w: 2, h: 2 }, "a tie goes to the first size listed")
assert.deepStrictEqual(plain(L.snapSize("cams", 4, 2)), { w: 4, h: 2 })
assert.deepStrictEqual(plain(L.snapSize("cams", 4, 3)), { w: 4, h: 3 }, "cameras can grow taller")
assert.deepStrictEqual(plain(L.snapSize("cams", 2, 5)), { w: 2, h: 5 }, "or become one column")
assert.deepStrictEqual(plain(L.snapSize("gpu", 5, 5)), { w: 2, h: 1 })
assert.deepStrictEqual(plain(L.snapSize("budget", 1, 3)), { w: 1, h: 1 })

const messy = L.place(m, [
  { id: "a", type: "gpu", col: -4, row: 99, w: 1, h: 1 },
  { id: "a", type: "gpu", col: 0, row: 6, w: 1, h: 1 },
  { type: "nope", col: 0, row: 0, w: 1, h: 1 },
  { type: "cams", col: 27, row: 6, w: 9, h: 9 },
  null
])
assert.strictEqual(messy.length, 3, "unknown types and junk are dropped")
assert.strictEqual(new Set(messy.map(i => i.id)).size, 3, "duplicate ids get a new one")
for (const a of messy) {
  assert(L.inside(m, a) && L.allowed(a.type, a.w, a.h))
  for (const b of messy) if (a !== b) assert(!L.overlaps(a, b))
}

const tiny = L.metrics(400, 300, 160, 20, 40, 0)
assert.strictEqual(L.place(tiny, items).every(i => L.inside(tiny, i)), true, "a small screen keeps only what fits")

assert.strictEqual(L.parse("not json"), null)
assert.strictEqual(L.parse('{"items": 3}'), null)
assert.deepStrictEqual(plain(L.parse(L.serialize(items))), plain(items))
console.log("layout ok")
