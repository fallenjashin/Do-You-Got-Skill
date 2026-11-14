// Fewest-shots search ("par"), with the winning moves recorded so the game can replay them.
//
// Exploration search (Go-Explore style): keep an archive of distinct moments reached, keyed by a
// rough description of the state; repeatedly restart from a promising moment (fewest shots, least
// explored) and play random shots from there. Every moment stores the full game state, so a
// restart continues exactly where that moment was, velocity and all.
//
// Version 2 fixes three flaws of version 1:
//  1. The run starts frozen, like the game: hazards only start moving on the first shot, so the
//     bot can't wait for a lucky hazard timing no player could get.
//  2. Moments are only skipped when they can't beat the best (shots >= best). Version 1 skipped at
//     best-1, which threw away moments that could still win without firing again.
//  3. The state label includes a rough velocity (8 directions x slow/medium/fast), so arriving at
//     the same spot fast is kept separately from arriving slowly.
//
// Usage:  node par.js <difficulty> [from-to] [out.jsonl]
// Prints one JSON line per level: {"diff","level","par","path":[[tick, dx, dy], ...]}
// (par/path null if no win was found). Every path is re-played from scratch before it's reported.
const C = require('./core_loader.js');
const fs = require('fs');

const TRIES = 3, BUDGET = 25000, FIND_BUDGET = 80000;

// withShots=false is the "just find any win" label: no shot count, finer time slots.
function key(r, withShots = true) {
  const p = r.p, sp = Math.sqrt(p.vx * p.vx + p.vy * p.vy);
  const spd = sp < 2 ? 0 : sp < 6 ? 1 : 2;
  const dir = spd === 0 ? 0 : Math.floor((Math.atan2(p.vy, p.vx) + Math.PI) / (2 * Math.PI) * 8) % 8;
  const base = [Math.floor(p.x / 30), Math.floor(p.y / 30), r.phased ? 1 : 0, r.g, r.rope ? 1 : 0, p.ammo, spd, dir];
  return (withShots ? [...base, Math.floor(r.t / 40) % 4, r.shots] : [...base, Math.floor(r.t / 20) % 8]).join(',');
}

// Exactly how the game replays a path: run starts frozen; fire when the run's tick matches.
function replay(i, diff, path) {
  const r = C.newRun(i, diff); let k = 0;
  for (let f = 0; f < 6000; f++) {
    while (k < path.length && path[k][0] === r.t) { C.fire(r, path[k][1], path[k][2]); k++; }
    if (!r.started) return null;                 // a path must start with a shot
    const res = C.tick(r); r.events.length = 0;
    if (res === 'win') return r.shots;
    if (res === 'dead') return null;
  }
  return null;
}

// opts.withShots: label includes shots (par search) or not (find-any-win search)
// opts.init: {best, path} from an earlier search, so only cheaper routes are explored
function search(i, diff, budget, opts = {}) {
  const withShots = opts.withShots !== false;
  const s0 = C.newRun(i, diff); s0.acts = [];
  const arch = new Map([[key(s0, withShots), { s: structuredClone(s0), v: 0 }]]); const keys = [...arch.keys()];
  let best = opts.init ? opts.init.best : Infinity, bestPath = opts.init ? opts.init.path : null;
  for (let it = 0; it < budget; it++) {
    let k = keys[Math.floor(Math.random() * keys.length)];
    for (let j = 0; j < 3; j++) {
      const k2 = keys[Math.floor(Math.random() * keys.length)], a = arch.get(k2), b = arch.get(k);
      if (a.s.shots < b.s.shots || (a.s.shots === b.s.shots && a.v < b.v)) k = k2;
    }
    const e = arch.get(k); e.v++;
    if (e.s.shots >= best) continue;                          // fix 2: can't beat the best from here
    const r = structuredClone(e.s);
    let next = r.started ? Math.floor(Math.random() * 40) : 0; // fix 1: frozen until the first shot
    for (let f = 0; f < 160; f++) {
      if (f >= next && r.p.ammo > 0) {
        const a = Math.random() * 6.283, dx = Math.cos(a), dy = Math.sin(a);
        if (C.fire(r, dx, dy)) r.acts.push([r.t, dx, dy]);
        next = f + 6 + Math.floor(Math.random() * (r.rope ? 80 : 60));
        if (r.shots >= best) break;
      }
      const res = C.tick(r); r.events.length = 0;
      if (res === 'win') { if (r.shots < best) { best = r.shots; bestPath = r.acts.slice(); } break; }
      if (res === 'dead') break;
      const ck = key(r, withShots);
      if (!arch.has(ck)) { arch.set(ck, { s: structuredClone(r), v: 0 }); keys.push(ck); }
    }
  }
  return { best, path: bestPath };
}

function parFor(i, diff) {
  let best = null, path = null;
  const take = res => {
    if (res.path && (best === null || res.best < best) && replay(i, diff, res.path) === res.best) { best = res.best; path = res.path; }
  };
  for (let t = 0; t < TRIES; t++) take(search(i, diff, BUDGET));
  if (best === null) {
    // hard level: first find any win, then search for cheaper routes than it
    for (let t = 0; t < 2 && best === null; t++) take(search(i, diff, FIND_BUDGET, { withShots: false }));
    for (let t = 0; t < 2 && best !== null; t++) take(search(i, diff, BUDGET, { init: { best, path } }));
  }
  return { diff, level: i, par: best, path };
}

if (require.main === module) {
  const diff = process.argv[2];
  const [lo, hi] = (process.argv[3] || `0-${C.LEVELS.length - 1}`).split('-').map(Number);
  const out = process.argv[4];
  for (let i = lo; i <= hi; i++) {
    const line = JSON.stringify(parFor(i, diff));
    console.log(line);
    if (out) fs.appendFileSync(out, line + '\n');
  }
}
module.exports = { search, replay, parFor, key };
