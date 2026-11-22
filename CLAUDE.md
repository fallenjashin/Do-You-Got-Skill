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
- **Finals are 3 screens** (`rooms` in build_levels.py `ROOMS`). Screen 1 is the original layout; its
  goal is an exit teleporter (green rings), the last screen ends on the green dot. Shots carry over
  between screens; speed carries over on Hard/Master/God (`"keep": true` in difficulties), not on
  Easy/Medium. Dying on screen 2+ respawns at that screen's start, clock keeps running (God Mode: still
  one life). Every screen starts on safe floor (x < 200) so a respawn can't trap you. Finals records
  use new slots (`key()` adds `:3s`), so old one-screen times don't count. Ghosts store
  `x + 2000 * screen`. Check screens with `node tools/bot/rooms.js <diff> 50-59`.

- **Full Run** (Easy..Master; God Mode is its own one-life run): all 60 levels in order on one clock.
  The clock counts ticks after the first shot of each attempt, deaths included, stopping between
  levels; menus pause it. Splits are cumulative; best run is `best["run:<diff>"]`, its splits
  `best["runs:<diff>"]`, shots `best["run:s:<diff>"]`. Start: main menu "Full Run", level-grid button, or F.
  B (back) is disabled inside a run; picking a level from the grid or changing difficulty leaves it.
  Pausing is free, so a future Steam leaderboard must verify runs by replay, not trust the clock.
- **Career stats** (main menu → Career Stats, `game.stats`, saved in save.json): time played (ticks in a
  level, aiming included, not on the clear screen), deaths (and per level), shots ("jumps"), clears and their
  summed time, finished runs. Counted from the day it was added; no back-fill. Saved every 10 s of play.
- **Creator splash**: the game opens on view `"splash"` (assets/brand/creator_logo.png: fallenjashin logo,
  rendered from the design canvas with Chakra Petch + Noto Sans JP, both OFL), 3.1 s, any key skips, then the
  click-to-start title. Drawn in title.gd `_draw_splash`; the smoke test skips it with Space.
- **Web build is a demo**: the Web export preset has custom feature `demo`, so `game.demo` is true there:
  only the first `DEMO_LEVELS` (15 = worlds 1-3) are playable, the rest show a padlock, and the end of level 15
  shows "DEMO COMPLETE". Steam/Windows builds and the editor are the full game. Demo runs aren't saved as
  records. Set `STEAM_URL` in game.gd once the store page exists (adds a Wishlist button).
- **Level-complete celebrations** (`scripts/celebrate.gd`, purely cosmetic): tier 1 clear, 2 personal best,
  3 beat the bot (shots < par), 4 top 10, 5 first place. `Game.celebration_tier()` picks it; tiers 4-5 need
  `game.leaderboard_rank` (1-10 / 1), which nothing sets until Steam leaderboards exist. In the editor (debug
  build only) F1-F5 preview the five tiers.
- **Animated backdrop** (`_draw_backdrop` in game.gd, cosmetic, uses wall-clock time): drifting glow orbs, a slow light sweep and twinkling dust in the level's neon colour, drawn behind the grid.
- `tools/marketing/`: Steam asset tools. `make_capsules.py <outdir>` (capsule art), `best_run.js` (records
  short winning runs), `trailer.gd` (replays them in movie mode for the trailer and screenshots).
  Store copy and checklist: `marketing/STEAM_STORE_COPY.md`.

## Open items / next steps

- **Finals par is empty** ("—"): par.js's budget is too small for 3 screens. On Easy/Medium you
  arrive standing, so finals par = sum of per-screen pars (run par on each screen as its own level,
  like rooms.js does). Hard+ can do better by carrying speed, so set it by hand from good runs.
- **Par:** easy/medium/hard are filled for levels 1-50; **master (also used by God Mode) is still empty**, and a few
  levels have no par yet (search found no win): 25, 43, 44, 45, 50 on some difficulties. Par is stored
  in `tools/levels/par.json` keyed by a fingerprint of level + difficulty + tuning (editing a level drops
  only its par). Run `node tools/bot/par.js master 0-29` (and `30-59`) — about 1 h per half on 2 cores;
  a cloud background job is killed at 2 h, so run halves — then
  `python3 tools/levels/build_levels.py --par master '<the printed array>'`. Re-runs only ever lower par.
- **Web deploy:** `tools/web/cachebust.sh` (unique game-data name) and `tools/web/smoke.py` (headless
  Chrome must load the build, reach a level and fire; nothing deploys otherwise). Run both locally
  after a web export if you touch the export or the HTML.
- Playtesting with strangers; tune any level people find unfair.
- Same-screen multiplayer race mode (recommended first multiplayer step), then Steam page,
  Steam leaderboards with replay-verified records and downloadable ghosts.
- Possible: hazards moving to the music's beat.
