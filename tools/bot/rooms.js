// Usage: node rooms.js [diff] [levels e.g. 50-59] [tries] [budget]
// Checks multi-screen levels screen by screen: each screen is loaded on its own (standing at its
// start with full shots, which is exactly how you arrive on Easy/Medium and how you respawn) and
// the exploration solver must beat it. Then the whole level is solved end to end, which on
// Hard and up includes arriving with the speed you left the previous screen with.
const C = require('./core_loader.js');
const diff = process.argv[2] || 'medium';
const sel = (process.argv[3] || `0-${C.LEVELS.length - 1}`).split(',').flatMap(p => {
  const [a, b] = p.split('-').map(Number); return b === undefined ? [a] : Array.from({ length: b - a + 1 }, (_, k) => a + k); });
const TRIES = +(process.argv[4] || 2), BUDGET = +(process.argv[5] || 60000);
const MECH = { latch: 'swing', phase: 'phase', tp: 'teleport', grav: 'gravity', knock: 'pusher', orb: 'orb', room: 'exit' };
function key(r) { const p = r.p; return [r.room, Math.floor(p.x / 30), Math.floor(p.y / 30), r.phased ? 1 : 0, r.g, r.rope ? 1 : 0, p.ammo, Math.floor(r.t / 20) % 8].join(','); }
function solve(i, budget) {
  const s0 = C.newRun(i, diff); s0.started = true; s0.used = {};
  const arch = new Map([[key(s0), { s: structuredClone(s0), v: 0 }]]); const keys = [...arch.keys()];
  for (let it = 0; it < budget; it++) {
    let k = keys[Math.floor(Math.random() * keys.length)];
    for (let j = 0; j < 3; j++) { const k2 = keys[Math.floor(Math.random() * keys.length)]; if (arch.get(k2).v < arch.get(k).v) k = k2; }
    const e = arch.get(k); e.v++; const r = structuredClone(e.s); let next = Math.floor(Math.random() * 15);
    for (let f = 0; f < 120; f++) {
      if (f >= next && r.p.ammo > 0) { const a = Math.random() * 6.283; C.fire(r, Math.cos(a), Math.sin(a)); next = f + 4 + Math.floor(Math.random() * (r.rope ? 70 : 35)); }
      const res = C.tick(r); for (const ev of r.events) if (MECH[ev]) r.used[MECH[ev]] = 1; if (r.plat >= 0) r.used.elevator = 1; r.events.length = 0;
      if (res === 'win') return { it, t: r.t, shots: r.shots, used: Object.keys(r.used).filter(x => x !== 'exit').sort().join('+') || '-' };
      if (res === 'dead') break;
      const ck = key(r); if (!arch.has(ck)) { arch.set(ck, { s: structuredClone(r), v: 0 }); keys.push(ck); }
    }
  }
  return { it: budget, t: null };
}
function report(label, i) {
  const res = []; for (let k = 0; k < TRIES; k++) res.push(solve(i, BUDGET));
  const ok = res.filter(x => x.t !== null);
  console.log(`  ${label.padEnd(10)} ${ok.length}/${TRIES}  search ${res.map(x => x.it).join(',').padEnd(13)} ${ok.map(x => x.used).join(' | ')}`);
  return ok.length;
}
const base = C.LEVELS.slice();
for (const i of sel) {
  const L = base[i]; if (!L.rooms) continue;
  console.log(`${String(i + 1).padStart(2)} ${L.name}  (${diff})`);
  const screens = [L].concat(L.rooms);
  screens.forEach((room, k) => {
    const lv = Object.assign({}, room, { name: `${L.name} ${k + 1}`, ammo: L.ammo });
    delete lv.rooms; C.LEVELS[i] = lv;
    report(`screen ${k + 1}`, i);
  });
  C.LEVELS[i] = L;
  report('full run', i);
}
