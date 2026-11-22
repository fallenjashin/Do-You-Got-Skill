# Do You Got Skill

You can't walk. You only move by firing a blast, which pushes you the opposite way.
60 levels: 10 worlds of 5 (each world teaches one mechanic and ramps up), then 10 finals that combine
at least 3 mechanics each. Five difficulties, time + fewest-shot records, ghosts and a one-life God Mode.

This is the Godot port of the browser prototype. The physics are an exact match:
`tests/test_parity.gd` replays 288 recorded prototype runs and all of them land on
the same frame, with the same shot count, within 0.0000000000005 px.

## Open it

1. Godot **4.7 or newer** → Project Manager → **Import** → pick `project.godot` in this folder.
2. Press **F5** (Run Project).

## Start screen and menu

The game opens on a neon "Do You Got Skill" sign over a starry sky. Press any key: the sign glides
left, the menu slides in, and the neon ball pops in and hops between items as you choose.

Menu: **Play** (continues your last level) · **Select Level** · **Difficulty** · **Leaderboard**
(placeholder until Steam) · **Music** · **Neon** · **Credits** · **Quit** (desktop only).
Keyboard ↑↓ choose, ←→ change, Enter select, Esc back to the game · mouse hover/click ·
controller D-pad, A, B. During play, **Esc** opens this menu and **L** opens the level grid.

Code: `scripts/title.gd`. Images of the sign for store pages / social posts are in `marketing/`
(full title screen, and the sign alone on a transparent background).

## Controls

| | Mouse / keyboard | Controller |
|---|---|---|
| Aim | Mouse: point where you want to **go** (the neon arrow) | Either stick |
| Fire | Click, tap or Space | A, RT or RB |
| Restart | R | Y |
| Next / previous level | N / B | — |
| Level select | L, or the "☰ Levels" button | Start |
| Main menu | Esc | B (from the level grid) |
| Neon wall colour: by difficulty / by world | T (or the button on the level screen) | — |
| Music volume | Main menu → Music: ←/→ = 1%, Shift = 10%, or click/drag the bar | D-pad 1%, LB/RB 10% |
| Mute / unmute music | V (or the Music button on the level grid) | — |
| Credits | C (or the button on the level screen) | — |
| Level screen | click a difficulty, then a level | LB/RB difficulty, D-pad pick, A play |

## Mechanics

| Orb | What it does |
|---|---|
| Yellow | Refills your shots in mid-air |
| Red | Fly inside its dotted ring to grab it and swing. Fire to let go, keeping your swing speed |
| Purple | Pass through walls. The goal is locked until you touch purple again |
| Orange (pairs A, B…) | Teleport to the partner orb, same speed and direction |
| Blue | Flip gravity. Landing on the ceiling refills your shots |
| Red spikes / spiked blocks | Instant death. Moving ones start moving on your first shot |
| Cyan filled platforms | Elevators: move on a track, carry you, refill your shots when you stand on them |
| Amber filled blocks with arrows | Pushers: knock you away. Pinned between a pusher and a wall = crushed |
| Red beams with square emitters | Timed lasers: flicker as a warning, then switch on |
| Red ships | Gunships: lock onto where you are, show a charge line, then fire. Walls block the beam; touching a ship kills |

Rule of thumb on screen: anything **filled** moves; outlined neon is a static wall; anything **red** kills.

## Worlds

| # | World | | # | World |
|---|---|---|---|---|
| 1 | Fire Blast (basics, yellow orbs) | | 6 | Moving spikes |
| 2 | Swing | | 7 | Elevators |
| 3 | Phase | | 8 | Pushers |
| 4 | Teleport | | 9 | Lasers |
| 5 | Gravity | | 10 | Gunships |
| F | Finals: 10 levels, 3+ mechanics each, 3 screens each (exit teleporter → next screen → green dot) | | | |

## Project layout

```
project.godot
data/levels.json          ← every level, difficulty setting and physics constant
scripts/sim.gd            ← rules + physics only (deterministic; no drawing, no input)
scripts/game.gd           ← input, drawing, menus, difficulties, God Mode, saving
scripts/sfx.gd            ← placeholder beeps synthesised in code
scenes/main.tscn          ← the one scene
tests/test_parity.gd      ← proves sim.gd matches the prototype exactly
tests/test_game.gd        ← plays the real game: aiming, menus, God Mode, controller, neon, saving
tests/golden_runs.json    ← the 288 recorded reference runs
tools/prototype/          ← the original browser prototype (open recoil.html in a browser)
tools/bot/                ← the level-testing bots (need Node.js)
```

**Rule of thumb:** gameplay changes go in `sim.gd` (and must keep the tests green);
anything visual goes in `game.gd`.

## Music

**"Code Injection Dark Techno Music Pack" by DavidKBD** (CC BY 4.0: credit required; see
CREDITS.md and the in-game Credits screen). Each of the 10 worlds has its own track; Finals 1–5,
Finals 6–9, the Final Exam and God Mode each have their own too. The files in `assets/music/`
are the artist's untouched loops; loudness differences are evened out in `scripts/music.gd`
(`GAIN_DB`). Tracks crossfade when the track changes. Volume: main menu → Music, in 1% steps
(←/→, Shift for 10%, or click/drag the bar); **V** mutes/unmutes. It's saved.

**To change which track plays where:** edit `WORLD_TRACKS` (and the finals / God Mode constants)
at the top of `scripts/music.gd`.

## Share / play in a browser

Every push to `main` runs both tests, exports the web version and publishes it to
**https://fallenjashin.github.io/Do-You-Got-Skill/** (see `.github/workflows/web.yml`).
One-time setup: repo **Settings → Pages → Source: GitHub Actions**.

To build locally: Godot → Project → Export → pick "Web" or "Windows" → Export Project
(needs Godot's export templates: Editor → Manage Export Templates → Download).

## Run the tests

From this folder (replace `godot` with the path to your Godot executable):

```
godot --headless --path . -s tests/test_parity.gd
godot --headless --path . -s tests/test_game.gd
```

Both print a summary and exit with code 0 on success. The game test uses its own save
file, so it never touches your real progress.

## The bots (optional, needs Node.js)

They read `data/levels.json` directly, so they always test the current levels.

```
cd tools/bot
node solve.js            # can every level be beaten, and which mechanics did the solution use?
node solve.js 5,23       # just levels 6 and 24 (0-based)
node rates.js 8000       # random-play win rate per difficulty (a rough difficulty measure)
node golden.js           # re-record tests/golden_runs.json after an intentional physics change
```

If you change physics on purpose: change `sim.gd` **and** the prototype's core the same way,
then re-run `golden.js` and the parity test.

## Editing levels

Levels are generated by `tools/levels/build_levels.py` (it writes `data/levels.json`). Edit the
Python file, run it, then run the solver. The key reference is at the top of that file. Each level:

```
{ "name": "Swing", "tip": "...", "start": [x, y], "goal": [x, y], "ammo": 2,
  "s":   [[x, y, w, h], ...],                 walls
  "k":   [[x, y, w, h], ...],                 spikes; moving: [x, y, w, h, dx, dy, period]
  "o":   [[x, y], ...],                       yellow orbs
  "red": [[x, y], ...], "pur": [...], "grav": [...],
  "tp":  [[ax, ay, bx, by], ...],             teleport pairs
  "mv":  [[x, y, w, h, dx, dy, period, knock, phase], ...]   elevators (knock 0) / pushers (knock > 0)
  "lz":  [[x1, y1, x2, y2, on, off, offset], ...]           timed lasers (ticks; 60 = 1 s)
  "ship":[[x, y, dx, dy, period, every, offset], ...] }     gunships
```

The play area is 960×540; the outer wall is 20 px thick. After editing:

```
python3 tools/levels/build_levels.py
cd tools/bot
node check.js medium            # every level: beatable? search effort? which mechanics did wins use?
node check.js master 40-44 3    # a range, 3 attempts each
node golden.js                  # re-record the reference runs, then run tests/test_parity.gd
```

## Next steps

1. **Visual level editor:** place walls, spikes and orbs in the Godot editor instead of typing coordinates.
2. **Name check:** the game is "Do You Got Skill" (internal project name renamed from "Recoil", which other Steam games use). Search Steam for the name before making a store page.
3. **Steam integration:** GodotSteam for leaderboards (time and fewest shots), plus replay upload so records can be verified.
4. **More levels:** a commercial release needs roughly 60–100.
