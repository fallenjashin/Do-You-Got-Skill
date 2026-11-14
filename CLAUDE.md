# Notes for Claude: Do You Got Skill

Read this first in a new session. It's the handoff from the session that built the game.

## The project

A Godot 4.7 precision platformer: you can't walk, you only move by firing a blast that pushes you
the opposite way. 60 levels (10 worlds × 5, each teaching one mechanic, plus 10 finals using 3+
mechanics), five difficulties incl. one-life God Mode, time + fewest-shot records, ghosts of your
best run, neon look, DavidKBD music. Owner: fallenjashin. Goal: an original, fair, skill-based,
competitive game; eventually Steam.

**How the owner wants to work:** be a mentor, give straight answers backed by data, push back
when they're wrong, point out hidden risks (licensing, store issues, scope). They are new to game
development: explain Godot / GitHub steps plainly. Push finished, tested work to `main`; they pull
with GitHub Desktop and press F5 in Godot.

## Layout

- `scripts/sim.gd`: rules and physics only. Deterministic (fixed 60 Hz, 4 sub-steps). No drawing.
- `scripts/game.gd`: input, drawing, HUD, level grid, difficulties, God Mode, saving, cursor, credits.
- `scripts/title.gd`: start screen (neon sign, starfield), animated main menu, neon ball character, leaderboard placeholder.
- `scripts/music.gd`: per-world tracks + title track, crossfades, per-track gain. `scripts/sfx.gd`: synthesized beeps.
- `data/levels.json`: generated. **Edit `tools/levels/build_levels.py`, then run it.**
- `tools/prototype/recoil.html`: the original browser prototype. Its `<script id="core">` is a JS
  copy of the physics used by the bots; it **must stay identical to `sim.gd`**.
- `tools/bot/`: Node bots that read `data/levels.json`. `check.js` (solver: beatable? which mechanics
  used?), `par.js` (fewest-shot par), `rates.js` (random-play difficulty), `golden.js` (reference runs).
- `tests/test_parity.gd` (replays 598 JS reference runs in Godot; must all match) and
  `tests/test_game.gd` (drives the real scene; 67 checks). CI runs both on every push.
- `.github/workflows/web.yml`: tests, then exports Web and deploys GitHub Pages
  (https://fallenjashin.github.io/Do-You-Got-Skill/).
- `marketing/`: title screen and transparent neon sign PNGs. `CREDITS.md`: required attributions.

## Rules that matter

1. **Physics changes go in both** `sim.gd` and the prototype core, then `node tools/bot/golden.js`
   and the parity test. Use plain `sqrt(x*x+y*y)` (not hypot) so both engines match bit-for-bit.
2. **New or changed levels:** run `python3 tools/levels/build_levels.py`, then
   `node tools/bot/check.js <difficulty> <range>` on easy/medium/hard/master. Every level must be
   beatable on every difficulty, and each world's mechanic must actually be used by winning runs.
3. **Run both Godot tests before pushing**; take screenshots (xvfb + `--rendering-driver opengl3`) of visual changes and look at them.
4. **Credits are legal requirements:** music is DavidKBD (Code Injection pack: CC BY 4.0; Pink
   Bloom pack: "credit DavidKBD"); Godot (MIT); Inter (OFL); DejaVu. Keep the in-game Credits screen and `CREDITS.md` in sync.
5. Fonts are bundled (Inter + DejaVu symbol subset) so the browser build looks identical; new
   symbols need adding to the subset in `assets/fonts/` (`pyftsubset`).
6. Commit messages end with the Co-Authored-By / Claude-Session lines from the system reminder.

## Getting Godot in a fresh cloud session

```
curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip && unzip -q g.zip
G=./Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import
$G --headless --path . -s tests/test_parity.gd
$G --headless --path . -s tests/test_game.gd
```
Export templates (for web/Windows builds): the `Godot_v4.7.2-stable_export_templates.tpz` release asset.

## Decisions already made (don't undo without asking)

- Aiming is only "point where you want to go" (neon arrow cursor). "Aim where you fire" was removed on purpose.
- Moving objects are drawn filled; static walls are neon outlines; anything red kills.
- Music volume is in 1% steps (main-menu slider); V mutes. Starting a level from a menu restarts its song; retrying doesn't.
- Leaderboard is a placeholder until there's a Steam app.

## Open items / next steps

- **Par is empty** for the 60-level set (shows "—"): run `node tools/bot/par.js <diff>` for
  easy/medium/hard/master (slow; ~30+ min each) and put the results in `data/levels.json` → `par`.
- Playtesting with strangers; tune any level people find unfair.
- Same-screen multiplayer race mode (recommended first multiplayer step), then Steam page,
  Steam leaderboards with replay-verified records and downloadable ghosts.
- Possible: hazards moving to the music's beat.
