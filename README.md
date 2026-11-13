# Recoil (working title)

You can't walk. You only move by firing a blast, which pushes you the opposite way.
24 levels, six mechanics, five difficulties, time + fewest-shot records, ghosts and a one-life God Mode.

This is the Godot port of the browser prototype. The physics are an exact match:
`tests/test_parity.gd` replays 288 recorded prototype runs and all of them land on
the same frame, with the same shot count, within 0.0000000000005 px.

## Open it

1. Godot **4.7 or newer** → Project Manager → **Import** → pick `project.godot` in this folder.
2. Press **F5** (Run Project).

## Controls

| | Mouse / keyboard | Controller |
|---|---|---|
| Aim | Mouse (default: point where you want to **go**) | Either stick |
| Fire | Click, tap or Space | A, RT or RB |
| Restart | R | Y |
| Next / previous level | N / B | — |
| Level select | L or Esc, or the "☰ Levels" button | Start |
| Switch aim style | M (or the button on the level screen) | — |
| Neon wall colour: by difficulty / by world | T (or the button on the level screen) | — |
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

## Project layout

```
project.godot
data/levels.json          ← every level, difficulty setting, par and physics constant
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
node par.js medium       # fewest-shot search for one difficulty (par)
node golden.js           # re-record tests/golden_runs.json after an intentional physics change
```

If you change physics on purpose: change `sim.gd` **and** the prototype's core the same way,
then re-run `golden.js` and the parity test.

## Editing levels

For now levels live in `data/levels.json`. Each level:

```
{ "name": "Swing", "tip": "...", "start": [x, y], "goal": [x, y], "ammo": 2,
  "s":   [[x, y, w, h], ...],                 walls
  "k":   [[x, y, w, h], ...],                 spikes; moving: [x, y, w, h, dx, dy, period]
  "o":   [[x, y], ...],                       yellow orbs
  "red": [[x, y], ...], "pur": [...], "grav": [...],
  "tp":  [[ax, ay, bx, by], ...] }            teleport pairs
```

The play area is 960×540; the outer wall is 20 px thick. After editing, run
`node tools/bot/solve.js` to confirm every level can still be beaten.

## Next steps

1. **Visual level editor:** place walls, spikes and orbs in the Godot editor instead of typing coordinates.
2. **Theme, name and art:** "Recoil" is already used by other Steam games.
3. **Steam integration:** GodotSteam for leaderboards (time and fewest shots), plus replay upload so records can be verified.
4. **More levels:** a commercial release needs roughly 60–100.
