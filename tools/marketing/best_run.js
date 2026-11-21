// Finds a clean, efficient winning run for trailers and screenshots: fewest shots first, then fastest.
// Usage: node best_run.js <difficulty> <seconds per level> <out.json> <level[:room]>...
//   "51:room" for a multi-screen level means: stop as soon as the first exit teleporter is taken.
// Output: {"<level>": {diff, shots, t, acts: [[tick, dx, dy], ...]}}  (replayed by trailer.gd)
const C = require('../bot/core_loader.js');
const fs = require('fs');
const [diff, secs, out, ...targets] = process.argv.slice(2);
function key(r) { const p = r.p; return [r.room, Math.floor(p.x / 30), Math.floor(p.y / 30), r.phased ? 1 : 0, r.g, r.rope ? 1 : 0, p.ammo, Math.floor(r.t / 40) % 4, r.shots].join(','); }
function search(i, untilRoom, ms) {
  const s0 = C.newRun(i, diff); s0.started = true; s0.acts = [];
  const arch = new Map([[key(s0), { s: structuredClone(s0), v: 0 }]]); const keys = [...arch.keys()];
  let best = null; const end = Date.now() + ms;
  while (Date.now() < end) {
    let k = keys[Math.floor(Math.random() * keys.length)];
    for (let j = 0; j < 3; j++) { const k2 = keys[Math.floor(Math.random() * keys.length)]; const a = arch.get(k2).s, b = arch.get(k).s; if (a.shots < b.shots || (a.shots === b.shots && a.t < b.t)) k = k2; }
    const e = arch.get(k); e.v++; const r = structuredClone(e.s); let next = Math.floor(Math.random() * 30);
    if (best && r.shots >= best.shots + (best ? 1 : 0) && r.shots > best.shots) continue;
    for (let f = 0; f < 160; f++) {
      if (f >= next && r.p.ammo > 0) { const a = Math.random() * 6.283, dx = Math.cos(a), dy = Math.sin(a); if (C.fire(r, dx, dy)) r.acts.push([r.t, dx, dy]); next = f + 6 + Math.floor(Math.random() * (r.rope ? 80 : 50)); }
      const res = C.tick(r); r.events.length = 0;
      const won = untilRoom ? r.room >= 1 : res === 'win';
      if (won) { if (!best || r.shots < best.shots || (r.shots === best.shots && r.t < best.t)) best = { diff, shots: r.shots, t: r.t, acts: r.acts.slice() }; break; }
      if (res === 'dead' || res === 'win') break;
      const ck = key(r); if (!arch.has(ck)) { arch.set(ck, { s: structuredClone(r), v: 0 }); keys.push(ck); }
    }
  }
  return best;
}
const result = fs.existsSync(out) ? JSON.parse(fs.readFileSync(out)) : {};
for (const t of targets) {
  const [i, mode] = t.split(':'); const b = search(+i, mode === 'room', +secs * 1000);
  console.log(i, C.LEVELS[+i].name, b ? `shots ${b.shots} ticks ${b.t}` : 'NO WIN FOUND');
  if (b) { result[i] = b; fs.writeFileSync(out, JSON.stringify(result)); }
}
