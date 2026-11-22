extends Node2D
## Do You Got Skill — game layer: input, drawing, menus, difficulties, God mode, saving.
## All rules/physics live in sim.gd. Everything is drawn with shapes for now;
## swap in sprites once the art direction is decided.

const Sim := preload("res://scripts/sim.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const MusicScript := preload("res://scripts/music.gd")
const TitleScript := preload("res://scripts/title.gd")
const Celebrate := preload("res://scripts/celebrate.gd")
const TITLE_VIEWS := ["splash", "title", "main", "leaderboard"]
const W := 960.0
const H := 540.0
const DIFFS := ["easy", "medium", "hard", "master", "god"]
var save_path := "user://save.json"  # tests point this elsewhere

const C_BG := Color("#12151d")
const C_WALL := Color("#2a3042")
const C_WALL_TOP := Color("#3a4260")
const C_TEXT := Color("#e8ecff")
const C_SUB := Color("#8b93b5")
const C_DIM := Color("#5d6585")
const C_PANEL := Color("#20253a")
const C_PANEL_HI := Color("#3a4260")
const C_SPIKE := Color("#ff4d6d")
const C_GOAL := Color("#2ed573")
const C_ORB := Color("#ffd166")
const C_RED := Color("#ff6b6b")
const C_PURPLE := Color("#b388ff")
const C_ORANGE := Color("#ff9f43")
const C_BLUE := Color("#4dabf7")
const C_SHOT := Color("#ffb347")
const DIFF_COLOR := {"easy": Color("#2ed573"), "medium": Color("#4dabf7"), "hard": Color("#ff9f43"),
	"master": Color("#ff3df2"), "god": Color("#ffd166")}
# Neon wall colours. Kept away from the spike red so hazards always stand out.
const NEON_BY_DIFF := {"easy": Color("#39ff88"), "medium": Color("#22c8ff"), "hard": Color("#ff9f2e"),
	"master": Color("#ff3df2"), "god": Color("#ffd447")}
# One neon colour per world (5 levels each); every final gets its own.
const WORLD_NEON := ["#22e6ff", "#ff3df2", "#9d6bff", "#ff9f2e", "#3d7bff", "#b6ff3b", "#3dffd0", "#ffb020", "#ff5fa2", "#a0a8ff"]
const FINAL_NEON := ["#22e6ff", "#ff3df2", "#b6ff3b", "#ff9f2e", "#9d6bff", "#3dffd0", "#3d7bff", "#ffb020", "#ff5fa2", "#ffd447"]
const C_LASER := Color("#ff2a5a")
const C_ELEVATOR := Color("#7df9ff")
const C_PUSHER := Color("#ffb020")
const C_SHIP := Color("#ff4d6d")

var data: Dictionary
var sim: Sim
var li := 0
var view := "play"            # "play" | "menu" | "pause" | "credits" | "stats" | "settings" | "demo_end" (+ TITLE_VIEWS)
## The free web build is a demo: the first DEMO_LEVELS levels are playable, the rest show a lock.
## The Web export preset has the custom feature "demo"; Steam builds and the editor are the full game.
const DEMO_LEVELS := 15
const STEAM_URL := ""         # the store page; set it once the page exists and the demo ending gets a Wishlist button
var demo := OS.has_feature("demo")
var diff := "medium"
var neon_mode := "difficulty" # wall colour follows "difficulty" or "world" (level group)
var aim := Vector2(W / 2, H / 2)
var deaths := 0
var rec: Array = []           # this attempt's path, for the ghost: x + GHOST_ROOM * screen, y
const GHOST_ROOM := 2000.0
var ghost = null
var gi := 0
var shake := 0.0
var parts: Array = []
var death_face := {}          # X-eyed face that floats up from where you died: {x, y, g, life}
var new_best := false
var new_fewest := false
var best := {}                # "diff:i" -> ticks, "s:diff:i" -> shots, "god:run", "god:shots"
var ghosts := {}
var god := {"total": 0, "shots": 0, "flash": 0, "finished": false}
## Career stats, saved with the records. Counted from the update that added them; older play isn't known.
## ticks = time in a level (60 per second, aiming included), shots = blasts fired ("jumps"),
## clears = levels beaten (repeats count), clear_ticks = their summed times, runs = finished Full/God runs,
## by_level = deaths per level index.
var stats := {"ticks": 0, "deaths": 0, "shots": 0, "clears": 0, "clear_ticks": 0, "runs": 0, "by_level": {}}
## Full Run (Easy..Master): all 60 levels in order on one clock. The clock counts every tick after your
## first shot of an attempt, deaths included, and stops between levels. Menus pause it.
## Best time lives in best["run:<diff>"], the best run's cumulative splits in best["runs:<diff>"].
var run := {"on": false, "t": 0, "shots": 0, "deaths": 0, "splits": [], "finished": false, "new_best": false, "delta": null}
var menu_sel := 0             # controller selection on the level grid
var using_pad := false
var trigger_was_down := false
var ui_alpha := 1.0          # HUD fades when the goal or the ball is underneath it

var font: Font
var font_bold: Font
var font_sign: Font   # the neon logo
var music: Node  # scripts/music.gd
var title: Node2D  # scripts/title.gd (start screen + main menu)
var last_level := 0          # what "Play" continues from
var reduce_flash := false   # accessibility: no full-screen flashes, no screen shake, calmer backdrop and splash
var hc_hazards := false     # accessibility: hazards get a white outline so they don't rely on red alone
var keys := {"fire": KEY_SPACE, "retry": KEY_R, "next": KEY_N, "back": KEY_B, "levels": KEY_L, "run": KEY_F}
const KEY_ROWS := [["fire", "Fire"], ["retry", "Retry"], ["next", "Next level"], ["back", "Previous level"], ["levels", "Level select"], ["run", "Full Run"]]
var set_sel := 0
const FEEDBACK_URL := ""     # set to a Discord invite / form link: adds a "Send feedback" button to the menus
var practice := false        # practice mode: infinite shots, nothing is saved (not in Full Run / God Mode)
var pause_sel := 0
var flawless := true         # no deaths since you started this level (for star ratings)
var star_li := -1
var last_stars := 0
var skin := 0
const SKINS := [  # [name, body, glow, levels you must clear to unlock it]
	["Classic", Color("#e8ecff"), Color("#7aa2ff"), 0],
	["Mint", Color("#d8fff0"), Color("#2ed573"), 5],
	["Sunset", Color("#fff0d8"), Color("#ff9f43"), 15],
	["Violet", Color("#f0e6ff"), Color("#b388ff"), 25],
	["Gold", Color("#fff6cc"), Color("#ffd166"), 40],
	["Rainbow", Color("#ffffff"), Color("#ffffff"), 60],
]
# One-time coaching tips: shown the first time the situation happens, remembered in the save.
const HINTS := {
	"arc": "Gravity bends your path, so you won't land where you aimed. Aim a little higher.",
	"chain": "CHAIN: firing mid-air keeps 45% of your speed and adds a new push. Fire the same way twice to go farther.",
	"brake": "BRAKE: aiming against your motion cuts your speed fast. Use it to stop over a target.",
	"bounce": "Walls and floors give a small bounce (a quarter of your speed). Skim a wall to turn without spending a shot.",
}
var hints_seen := {}
var toast := {}             # {"text", "t"} while a tip is on screen
var arc_timer := 0
var hint_queue: Array = []   # tips waiting for the current one to fade
var listening := ""         # the key action waiting for a keypress in Settings ("" = none)
var set_note := ""
var credits_back := "menu"   # where closing the credits returns to
var cel = null                # the level-complete celebration being played (scripts/celebrate.gd)
## Your place on the level's online leaderboard after a win: 0 = unknown / not ranked.
## Nothing sets this until Steam leaderboards exist; when they do, set it before start_celebration() runs.
var beat_both := false   # this clear beat an existing best time AND an existing fewest-shots record
var leaderboard_rank := 0
var booting := false         # true while _ready builds the first level, so no level song starts
var restart_music := false   # set when a level is started from a menu
var music_volume := 0.7        # 0..1 in 1% steps
var music_unmuted := 0.7       # volume to come back to after unmuting
var cursor_hidden := false     # the OS pointer is hidden while playing (we draw our own)
var sfx: Node  # scripts/sfx.gd (typed loosely so a fresh clone runs before Godot builds its class index)


func _ready() -> void:
	data = Sim.load_data()
	# Bundled Inter (SIL OFL) so text looks identical on every PC and in the browser;
	# symbols (☰ ⇄ ★ ✓ ← → …) come from a tiny DejaVu subset as a fallback.
	font = load("res://assets/fonts/inter-regular.otf")
	font_bold = load("res://assets/fonts/inter-bold.otf")
	font_sign = load("res://assets/fonts/inter-display-extrabold.otf")
	font.fallbacks = [load("res://assets/fonts/symbols.ttf")]
	font_bold.fallbacks = [load("res://assets/fonts/symbols-bold.ttf")]
	font_sign.fallbacks = [load("res://assets/fonts/symbols-bold.ttf")]
	sfx = SfxScript.new()
	add_child(sfx)
	music = MusicScript.new()
	add_child(music)
	_load_save()
	music.set_volume(music_volume)
	booting = true
	title = TitleScript.new()
	title.game = self
	add_child(title)
	load_level(last_level)
	booting = false
	view = "splash"   # the creator logo, then the click-to-start title
	music.play(music.TITLE)   # one song from the logo through the title and main menu
	print("GAME READY: %d levels" % data.levels.size())   # the web smoke test waits for this line


# ---------------------------------------------------------------- save / load

func _load_save() -> void:
	_migrate_old_save()
	if not FileAccess.file_exists(save_path):
		return
	var parsed = JSON.parse_string(FileAccess.open(save_path, FileAccess.READ).get_as_text())
	if parsed is Dictionary:
		best = parsed.get("best", {})
		if parsed.get("diff", "") in DIFFS: diff = parsed.diff
		if parsed.get("neon", "") in ["difficulty", "world"]: neon_mode = parsed.neon
		if parsed.has("music"): music_volume = clampf(float(parsed.music), 0.0, 1.0)
		music_unmuted = clampf(float(parsed.get("music_on", music_volume if music_volume > 0.0 else 0.7)), 0.01, 1.0)
		reduce_flash = bool(parsed.get("reduce_flash", false))
		hc_hazards = bool(parsed.get("hc_hazards", false))
		skin = clampi(int(parsed.get("skin", 0)), 0, SKINS.size() - 1)
		var hs = parsed.get("hints", null)
		if hs is Dictionary:
			for k in hs:
				if HINTS.has(str(k)): hints_seen[str(k)] = true
		var ks = parsed.get("keys", null)
		if ks is Dictionary:
			for k in keys:
				if ks.has(k) and int(ks[k]) > 0: keys[k] = int(ks[k])
		var st = parsed.get("stats", null)
		if st is Dictionary:
			for k in ["ticks", "deaths", "shots", "clears", "clear_ticks", "runs"]:
				stats[k] = int(st.get(k, 0))
			var bl = st.get("by_level", {})
			if bl is Dictionary:
				for k in bl: stats.by_level[str(k)] = int(bl[k])
		if parsed.has("last"): last_level = clampi(int(parsed.last), 0, playable_total() - 1)


## The project used to be called "Recoil", and Godot keeps user:// in a folder named after the
## project. After the rename, copy the old save across once so nobody loses their records.
func _migrate_old_save() -> void:
	if save_path != "user://save.json" or FileAccess.file_exists(save_path):
		return
	var old := OS.get_user_data_dir().get_base_dir().path_join("Recoil").path_join("save.json")
	if FileAccess.file_exists(old):
		DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())   # may not exist yet
		DirAccess.copy_absolute(old, ProjectSettings.globalize_path(save_path))


func _save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"best": best, "diff": diff, "neon": neon_mode, "music": music_volume, "music_on": music_unmuted, "last": last_level, "stats": stats, "reduce_flash": reduce_flash, "hc_hazards": hc_hazards, "keys": keys, "hints": hints_seen, "skin": skin}))


# ---------------------------------------------------------------- helpers

func key(i: int) -> String: return diff + ":" + str(i) + _rv(i)
func skey(i: int) -> String: return "s:" + diff + ":" + str(i) + _rv(i)
## Multi-screen levels use new record slots, so times from the old one-screen versions don't count.
func _rv(i: int) -> String: return ":3s" if data.levels[i].has("rooms") else ""
func one_life() -> bool: return data.difficulties[diff].get("oneLife", false)
func fmt(ticks: float) -> String: return "%.2fs" % (ticks / 60.0)
func in_run() -> bool: return run.on and not one_life()
## Long times: 1:02:03.45 / 12:03.45 / 3.45
func fmt_run(ticks: float) -> String:
	var cs := int(roundf(ticks * 100.0 / 60.0))
	var h := cs / 360000
	var m := (cs / 6000) % 60
	var sec := (cs / 100) % 60
	if h > 0: return "%d:%02d:%02d.%02d" % [h, m, sec, cs % 100]
	if m > 0: return "%d:%02d.%02d" % [m, sec, cs % 100]
	return "%d.%02d" % [sec, cs % 100]
func fmt_delta(ticks: float) -> String:
	return "%s%s" % ["+" if ticks > 0 else "-" if ticks < 0 else "±", fmt_run(absf(ticks))]
func level_total() -> int: return data.levels.size()
## Levels you can actually play: all of them, or the demo's first DEMO_LEVELS.
func playable_total() -> int: return mini(DEMO_LEVELS, level_total()) if demo else level_total()

func load_level(i: int) -> void:
	li = posmod(i, playable_total())
	sim = Sim.new(li, diff)
	view = "play"
	rec = []
	gi = 0
	ghost = ghosts.get(key(li), null)
	new_best = false
	new_fewest = false
	beat_both = false
	cel = null
	toast = {}
	hint_queue = []
	arc_timer = 0
	if li != star_li:
		star_li = li; flawless = true
	if not booting:   # while the game starts up the title song plays, not this level's
		music.play_for_level(li, one_life(), restart_music)
	restart_music = false
	if not one_life() and li != last_level:
		last_level = li
		_save()


## Music volume steps: 100% → 70% → 40% → off → 100%
## Music volume, 0..1, kept to whole percents.
func set_music_volume(v: float) -> void:
	music_volume = clampf(roundf(v * 100.0) / 100.0, 0.0, 1.0)
	if music_volume > 0.0:
		music_unmuted = music_volume
	music.set_volume(music_volume)
	_save()


func adjust_music(percent: int) -> void:
	set_music_volume(music_volume + percent / 100.0)


## V / the level-grid Music button: mute, or come back to the last volume.
func toggle_mute() -> void:
	if music_volume > 0.0:
		music_unmuted = music_volume
		music_volume = 0.0
		music.set_volume(0.0)
		_save()
	else:
		set_music_volume(music_unmuted if music_unmuted > 0.0 else 0.7)


## Starting a level from a menu (Play, or a level on the grid) restarts its song from the top.
## Retrying after a death or pressing Next does not.
func start_from_menu(i: int) -> void:
	if i >= playable_total(): return   # locked in the demo
	restart_music = true
	run.on = false
	if one_life(): start_god()
	else: load_level(i)


## Full Run from level 1 (God Mode already is a full run: one life, same idea).
func start_run() -> void:
	practice = false
	restart_music = true
	if one_life():
		start_god()
		return
	run = {"on": true, "t": 0, "shots": 0, "deaths": 0, "splits": [], "finished": false, "new_best": false, "delta": null}
	load_level(0)


func next_level() -> void:
	if in_run() and run.finished: return
	if demo and li >= playable_total() - 1:
		credits_back = "menu"; view = "demo_end"
		return
	load_level(li + 1)


## Back to the level from the main menu (the level's song comes back in).
func resume_play() -> void:
	view = "play"
	music.play_for_level(li, one_life())


func practicing() -> bool:
	return practice and not one_life() and not in_run()


## How many different levels you have cleared (any difficulty): unlocks ball colours.
func cleared_levels() -> int:
	var seen := {}
	for k in best:
		var parts: PackedStringArray = str(k).split(":")
		if parts.size() >= 2 and parts[0] in DIFFS and parts[1].is_valid_int(): seen[int(parts[1])] = true
	return seen.size()


func skin_unlocked(i: int) -> bool:
	return cleared_levels() >= int(SKINS[i][3])


func open_main_menu() -> void:
	title.open_main(true)


func cycle_music() -> void:
	toggle_mute()


func start_god() -> void:
	practice = false
	god.total = 0; god.shots = 0; god.finished = false
	load_level(0)


func set_diff(dname: String) -> void:
	if dname != diff: run.on = false
	diff = dname
	_save()


func toggle_neon() -> void:
	neon_mode = "world" if neon_mode == "difficulty" else "difficulty"
	_save()


func neon() -> Color:
	return world_color(li) if neon_mode == "world" else NEON_BY_DIFF[diff]


func world_color(i: int) -> Color:
	return Color(WORLD_NEON[i / 5]) if i < 50 else Color(FINAL_NEON[(i - 50) % FINAL_NEON.size()])


## "3-2" for world 3 level 2, "F7" for the seventh final.
func level_code(i: int) -> String:
	return "%d-%d" % [i / 5 + 1, i % 5 + 1] if i < 50 else "F%d" % (i - 49)


func god_next() -> void:
	if li == playable_total() - 1: god.finished = true
	else: load_level(li + 1)


## Direction the blast fires (you get pushed the opposite way).
func fire_dir() -> Vector2:
	var p := Vector2(sim.px, sim.py)
	return p - aim   # you point where you want to go; the blast fires the opposite way


func burst(x: float, y: float, c: Color, n: int, sp := 6.0) -> void:
	for i in n:
		var a := randf() * TAU
		var s := randf() * sp
		parts.append({"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "life": 1.0, "c": c})


# ---------------------------------------------------------------- layout

const BTN_RETRY := Rect2(W / 2 - 215, 330, 130, 44)
const BTN_LEVELS := Rect2(W / 2 - 65, 330, 130, 44)
const BTN_NEXT := Rect2(W / 2 + 85, 330, 130, 44)
const HUD_LEVELS := Rect2(20, 18, 92, 30)
const NEON_BOX := Rect2(20, 26, 200, 30)
const MUSIC_BOX := Rect2(228, 26, 130, 30)
const RUN_BOX := Rect2(790, 26, 150, 30)
const BTN_WISHLIST := Rect2(W / 2 - 150, 380, 300, 48)
const CREDITS_BOX := Rect2(846, 508, 94, 24)

func menu_box(i: int) -> Rect2:
	var col := i % 10
	return Rect2(26 + col * 90 + (16 if col >= 5 else 0), 176 + (i / 10) * 55, 84, 47)
func diff_box(i: int) -> Rect2: return Rect2(140 + i * 140, 78, 128, 34)
func hit(r: Rect2) -> bool: return r.has_point(aim)


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if view in TITLE_VIEWS:
		return  # handled by title.gd
	if e is InputEventMouseMotion:
		aim = e.position; using_pad = false
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		aim = e.position; using_pad = false; press()
	elif e is InputEventScreenTouch and e.pressed:
		aim = e.position; using_pad = false; press()
	elif e is InputEventKey and e.pressed and not e.echo:
		if view == "settings":
			_settings_key(e.keycode)
			return
		if view == "pause":
			_pause_key(e.keycode)
			return
		var kc: int = e.keycode
		if kc == int(keys.fire): press()
		elif kc == int(keys.retry):
			if one_life(): start_god()
			elif in_run() and run.finished: start_run()
			else: load_level(li)
		elif kc == int(keys.run): start_run()
		elif kc == int(keys.next):
			if in_run():
				if sim.done: next_level()
			elif not one_life():
				next_level()
			elif sim.done:
				god_next()
		elif kc == int(keys.back):
			if not one_life() and not in_run(): load_level(li - 1)
		elif kc == int(keys.levels): view = "play" if view == "menu" else "menu"
		else:
			match kc:
				KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5:
					# Preview the five celebrations (only when running from the editor, never in a shipped build)
					if OS.is_debug_build(): start_celebration(kc - KEY_F1 + 1)
				KEY_ESCAPE:
					if view in ["credits", "stats", "demo_end"]: view = credits_back
					elif view == "play": pause_sel = 0; view = "pause"
					elif view == "pause": view = "play"
					else: open_main_menu()
				KEY_T: toggle_neon()
				KEY_V: toggle_mute()
				KEY_C:
					if view == "credits": view = credits_back
					else:
						credits_back = view
						view = "credits"
	elif e is InputEventJoypadButton and e.pressed:
		using_pad = true
		_pad_button(e.button_index)


func _pad_button(b: int) -> void:
	if view == "settings":
		if b == JOY_BUTTON_B and listening == "": view = credits_back; _save()
		return
	if view == "pause":
		if b == JOY_BUTTON_B or b == JOY_BUTTON_START: view = "play"
		elif b == JOY_BUTTON_DPAD_UP: pause_sel = posmod(pause_sel - 1, pause_rows().size())
		elif b == JOY_BUTTON_DPAD_DOWN: pause_sel = posmod(pause_sel + 1, pause_rows().size())
		elif b == JOY_BUTTON_A: _pause_activate(pause_sel)
		return
	if view == "menu":
		match b:
			JOY_BUTTON_DPAD_LEFT: menu_sel = posmod(menu_sel - 1, level_total())
			JOY_BUTTON_DPAD_RIGHT: menu_sel = posmod(menu_sel + 1, level_total())
			JOY_BUTTON_DPAD_UP: menu_sel = posmod(menu_sel - 10, level_total())
			JOY_BUTTON_DPAD_DOWN: menu_sel = posmod(menu_sel + 10, level_total())
			JOY_BUTTON_LEFT_SHOULDER: set_diff(DIFFS[posmod(DIFFS.find(diff) - 1, DIFFS.size())])
			JOY_BUTTON_RIGHT_SHOULDER: set_diff(DIFFS[posmod(DIFFS.find(diff) + 1, DIFFS.size())])
			JOY_BUTTON_A: start_from_menu(menu_sel)
			JOY_BUTTON_START: view = "play"
			JOY_BUTTON_B: open_main_menu()
		return
	match b:
		JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER:
			if sim.done:
				if one_life():
					if god.finished: start_god()
					else: god_next()
				else: next_level()
			else: press()
		JOY_BUTTON_Y: start_god() if one_life() else load_level(li)
		JOY_BUTTON_START: menu_sel = li; view = "menu"


func _pad_aim() -> void:
	# either stick aims; right trigger fires
	var r := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var l := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var s := r if r.length() >= l.length() else l
	if s.length() > 0.35:
		using_pad = true
		aim = Vector2(sim.px, sim.py) + s.normalized() * 120.0
	var trig := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.6
	if trig and not trigger_was_down and view == "play" and not sim.done:
		press()
	trigger_was_down = trig


func press() -> void:
	if view == "demo_end":
		if STEAM_URL != "" and hit(BTN_WISHLIST): OS.shell_open(STEAM_URL)
		else: view = credits_back
		return
	if view == "pause":
		_pause_click(); return
	if view == "settings":
		_settings_click(); return
	if view == "credits" or view == "stats":
		view = credits_back; return
	if view == "menu":
		if hit(CREDITS_BOX): credits_back = "menu"; view = "credits"; return
		if hit(NEON_BOX): toggle_neon(); return
		if hit(RUN_BOX) and not one_life(): start_run(); return
		if hit(MUSIC_BOX): toggle_mute(); return
		for i in DIFFS.size():
			if hit(diff_box(i)): set_diff(DIFFS[i]); return
		for i in level_total():
			if hit(menu_box(i)):
				start_from_menu(i)
				return
		if one_life(): start_god()
		else: load_level(li)
		return
	if hit(HUD_LEVELS):
		menu_sel = li; view = "menu"; return
	if sim.done:
		if one_life():
			if god.finished:
				if hit(BTN_RETRY): start_god()
				elif hit(BTN_LEVELS): view = "menu"
			else: god_next()
			return
		if in_run() and run.finished:
			if hit(BTN_RETRY): start_run()
			elif hit(BTN_LEVELS): view = "menu"
		elif hit(BTN_RETRY): load_level(li)
		elif hit(BTN_LEVELS): view = "menu"
		elif hit(BTN_NEXT): next_level()
		return
	var dir := fire_dir()
	var was_air: bool = not sim.grounded and sim.rope == null
	var vel := Vector2(sim.vx, sim.vy)
	if not sim.fire(dir.x, dir.y):
		sfx.beep(120, 0.05, "square", 0.03); return
	if was_air and vel.length() > 3.5:   # coaching: how momentum carries between shots
		var along := (-dir).normalized().dot(vel.normalized())
		if along > 0.5: _coach("chain")
		elif along < -0.4: _coach("brake")
	if li == 0 and sim.shots == 1: arc_timer = 45
	if practicing(): sim.ammo = sim.ammo_max
	else: stats.shots += 1
	shake = 5.0
	sfx.beep(180 + randf() * 40, 0.09, "sawtooth", 0.06)
	var n := dir.normalized() if dir.length() > 0 else Vector2.DOWN
	for i in 16:
		var a := n.angle() + (randf() - 0.5) * 0.7
		var s := 3.0 + randf() * 5.0
		parts.append({"x": sim.px + n.x * 11, "y": sim.py + n.y * 11, "vx": cos(a) * s, "vy": sin(a) * s, "life": 1.0, "c": C_SHOT})


# ---------------------------------------------------------------- simulation step (60 Hz)

func _physics_process(_delta: float) -> void:
	_pad_aim()
	for q in parts:
		q.x += q.vx; q.y += q.vy; q.vx *= 0.94; q.vy *= 0.94; q.life -= 0.03
	parts = parts.filter(func(q): return q.life > 0)
	if shake > 0: shake *= 0.85
	if not death_face.is_empty():
		death_face.life -= 1.0 / 40.0   # ~0.7 s; respawn stays instant, the face is just a ghost
		death_face.y -= 0.6 * death_face.g
		if death_face.life <= 0: death_face = {}
	if view != "play":
		return
	if practicing(): sim.ammo = sim.ammo_max
	if not sim.done and not practicing():
		stats.ticks += 1
		if stats.ticks % 600 == 0: _save()   # every 10 s of play, so a closed tab loses little
	if cel != null: cel.update(1.0 / 60.0)
	var counting: bool = in_run() and sim.started and not sim.done and not sim.dead and not run.finished
	var pv := Vector2(sim.vx, sim.vy)
	var res := sim.tick()
	if not toast.is_empty(): toast.t += 1.0 / 60.0
	if not toast.is_empty() and toast.t > 5.5:
		toast = {}
		if not hint_queue.is_empty(): _coach(hint_queue.pop_front())
	if arc_timer > 0 and not sim.done:
		arc_timer -= 1
		if arc_timer == 0: _coach("arc")
	if not sim.done and not sim.dead and res == "" and sim.rope == null:
		var nv := Vector2(sim.vx, sim.vy)
		if (absf(pv.x) > 4.0 and signf(nv.x) != signf(pv.x)) or (absf(pv.y) > 4.0 and signf(nv.y) != signf(pv.y)):
			_coach("bounce")
	if counting: run.t += 1
	if sim.started and not sim.done and not sim.dead:
		rec.append(sim.px + GHOST_ROOM * sim.room); rec.append(sim.py)
		if ghost != null: gi = mini(gi + 2, ghost.size() - 2)
	for ev in sim.events:
		match ev:
			"land": sfx.beep(520, 0.04, "triangle", 0.04)
			"orb": sfx.beep(880, 0.08, "sine", 0.07)
			"latch": sfx.beep(300, 0.12, "sine", 0.08, 600); burst(sim.px, sim.py, C_RED, 8, 3)
			"detach": sfx.beep(600, 0.08, "sine", 0.05, 300)
			"phase": sfx.beep(400, 0.25, "sine", 0.07, 900); burst(sim.px, sim.py, C_PURPLE, 20, 4)
			"unphase": sfx.beep(900, 0.2, "sine", 0.07, 400); burst(sim.px, sim.py, C_PURPLE, 20, 4)
			"locked": sfx.beep(150, 0.15, "square", 0.05)
			"knock": sfx.beep(110, 0.12, "square", 0.08, 60); shake = 7.0
			"charge": sfx.beep(220, 0.5, "sine", 0.03, 880)
			"beam": sfx.beep(1400, 0.25, "sawtooth", 0.04, 300)
			"grav":
				sfx.beep(700 if sim.g > 0 else 300, 0.22, "sine", 0.07, 300 if sim.g > 0 else 700)
				burst(sim.px, sim.py, C_BLUE, 18, 4); shake = 4.0
			"room":
				burst(sim.px, sim.py, C_GOAL, 26, 5); shake = 5.0
				sfx.beep(500, 0.18, "sine", 0.08, 1200)
			"tp":
				if sim.last_tp.size() == 4: burst(sim.last_tp[0], sim.last_tp[1], C_ORANGE, 16, 4)
				burst(sim.px, sim.py, C_ORANGE, 16, 4); sfx.beep(1200, 0.1, "triangle", 0.06, 500)
	sim.events.clear()
	if god.flash > 0: god.flash -= 1

	if res == "dead":
		deaths += 1; sfx.beep(90, 0.25, "sawtooth", 0.07); shake = 10.0
		if not practicing():
			stats.deaths += 1
			flawless = false
		stats.by_level[str(li)] = int(stats.by_level.get(str(li), 0)) + 1
		if in_run(): run.deaths += 1
		death_face = {"x": sim.px, "y": sim.py, "g": sim.g, "life": 1.0}
		burst(sim.px, sim.py, C_SPIKE, 30)
		if one_life():
			god.flash = 150
			start_god()
		elif not sim.respawn():
			load_level(li)
	elif res == "win":
		if practicing():
			sfx.beep(660, 0.1, "sine", 0.08)
			return
		stats.clears += 1; stats.clear_ticks += sim.t
		sfx.beep(660, 0.1, "sine", 0.08)
		get_tree().create_timer(0.1).timeout.connect(func(): sfx.beep(990, 0.18, "sine", 0.08))
		var had_records: bool = best.has(skey(li)) and best.has(key(li))
		var prev_fewest: int = int(best[skey(li)]) if best.has(skey(li)) else 9999
		if not best.has(skey(li)) or sim.shots < best[skey(li)]:
			best[skey(li)] = sim.shots; new_fewest = true
		if one_life():
			god.total += sim.t; god.shots += sim.shots
			if not best.has(key(li)) or sim.t < best[key(li)]:
				best[key(li)] = sim.t; ghosts[key(li)] = rec.duplicate()
			if li == playable_total() - 1:
				god.finished = true; stats.runs += 1
				if not demo:   # the demo's short run is not a record
					if not best.has("god:run") or god.total < best["god:run"]:
						best["god:run"] = god.total; new_best = true
					if not best.has("god:shots") or god.shots < best["god:shots"]:
						best["god:shots"] = god.shots; new_fewest = true
		elif not best.has(key(li)) or sim.t < best[key(li)]:
			best[key(li)] = sim.t; ghosts[key(li)] = rec.duplicate(); new_best = true
		beat_both = had_records and new_best and new_fewest and not one_life()
		last_stars = 1
		if flawless and not one_life():
			last_stars = 2
			if had_records and sim.shots <= int(prev_fewest): last_stars = 3
		if not one_life():
			var sk := "st:" + key(li)
			best[sk] = maxi(int(best.get(sk, 0)), last_stars)
		star_li = -1
		if in_run(): _run_level_won()
		start_celebration()
		_save()


## 1 cleared · 2 personal best · 3 double best (beat BOTH your old best time and old fewest shots; a first clear is not) · 4 top 10 · 5 first place.
static func celebration_tier(was_best: bool, was_fewest: bool, double_best: bool, rank: int) -> int:
	if rank == 1: return 5
	if rank >= 2 and rank <= 10: return 4
	if double_best: return 3
	if was_best or was_fewest: return 2
	return 1


## Pick the tier for the level just won and start its animation. force_tier (1-5) is for previews and tests.
func start_celebration(force_tier := 0) -> void:
	var tier := force_tier if force_tier > 0 else celebration_tier(new_best, new_fewest, beat_both, leaderboard_rank)
	var head := ""
	var sub := ""
	match tier:
		2:
			head = "NEW BEST TIME" if new_best else "FEWEST SHOTS"
			sub = "%s  ·  %d shot%s" % [fmt(sim.t), sim.shots, "" if sim.shots == 1 else "s"]
		3:
			head = "DOUBLE BEST"
			sub = "%s  ·  %d shot%s  ·  best time and fewest shots" % [fmt(sim.t), sim.shots, "" if sim.shots == 1 else "s"]
		4:
			head = "TOP 10"
			sub = "#%d on the leaderboard" % maxi(leaderboard_rank, 2)
		5:
			head = "#1"
			sub = "NEW RECORD  ·  top of the leaderboard"
	var goal := Vector2(float(sim.L.goal[0]), float(sim.L.goal[1]))
	cel = Celebrate.new()
	cel.start(self, tier, goal, head, sub)


## A level was beaten during a Full Run: record the split, compare with your best run, finish on level 60.
func _run_level_won() -> void:
	run.shots += sim.shots
	run.splits.append(run.t)
	var ref = best.get("runs:" + diff, null)
	run.delta = run.t - int(ref[li]) if ref is Array and ref.size() > li else null
	if li != playable_total() - 1: return
	run.finished = true; stats.runs += 1
	if demo: return   # the demo's short run is not a record
	var rk := "run:" + diff
	if not best.has(rk) or run.t < int(best[rk]):
		best[rk] = run.t; best["runs:" + diff] = run.splits.duplicate(); run.new_best = true
	var sk := "run:s:" + diff
	if not best.has(sk) or run.shots < int(best[sk]):
		best[sk] = run.shots


func _process(_delta: float) -> void:
	var hide := view == "play" and not sim.done
	if hide != cursor_hidden:
		cursor_hidden = hide
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE
	queue_redraw()


# ---------------------------------------------------------------- drawing helpers

func text(s: String, x: float, y: float, size: int, c: Color, align := "c", bold := false) -> void:
	var f: Font = font_bold if bold else font
	c = Color(c, c.a * ui_alpha)
	match align:
		"c": draw_string(f, Vector2(x - 480, y), s, HORIZONTAL_ALIGNMENT_CENTER, 960, size, c)
		"r": draw_string(f, Vector2(x - 900, y), s, HORIZONTAL_ALIGNMENT_RIGHT, 900, size, c)
		_: draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func glow(pos: Vector2, r: float, c: Color, strength := 1.0) -> void:
	for k in 3:
		draw_circle(pos, r + 3.0 + k * 4.0, Color(c, 0.10 * strength / (k + 1)))


## Glowing tube outline: soft wide halo, brighter inner band, near-white core line.
func neon_outline(r: Rect2, c: Color, a := 1.0) -> void:
	draw_rect(r, Color(c, 0.05 * a), false, 12.0)
	draw_rect(r, Color(c, 0.12 * a), false, 7.0)
	draw_rect(r, Color(c, 0.45 * a), false, 3.5)
	draw_rect(r, Color(c.lightened(0.55), 0.95 * a), false, 1.5)


## Tall spike strip: a thin core with teeth out to its edges, so what you see is exactly what kills.
func spike_column(r: Rect2) -> void:
	var inset := minf(5.0, r.size.x / 3.0)
	_spike_rect(Rect2(r.position.x + inset, r.position.y, r.size.x - 2 * inset, r.size.y))
	var j := 0.0
	while j + 10.0 <= r.size.y + 0.01:
		var y := r.position.y + j
		_spike(PackedVector2Array([Vector2(r.position.x + inset, y), Vector2(r.position.x, y + 5), Vector2(r.position.x + inset, y + 10)]))
		_spike(PackedVector2Array([Vector2(r.end.x - inset, y), Vector2(r.end.x, y + 5), Vector2(r.end.x - inset, y + 10)]))
		j += 10.0
	# a point on the free end (bottom if it hangs from the ceiling, top otherwise)
	if r.position.y < 60:
		_spike(PackedVector2Array([Vector2(r.position.x, r.end.y - 6), Vector2(r.get_center().x, r.end.y), Vector2(r.end.x, r.end.y - 6)]))
	else:
		_spike(PackedVector2Array([Vector2(r.position.x, r.position.y + 6), Vector2(r.get_center().x, r.position.y), Vector2(r.end.x, r.position.y + 6)]))


func dashed_circle(pos: Vector2, r: float, c: Color) -> void:
	var n := 48
	for i in n:
		if i % 2 == 0:
			var a0 := TAU * i / n
			draw_arc(pos, r, a0, a0 + TAU / n * 0.6, 3, c, 1.0)


func dashed_rect(r: Rect2, c: Color) -> void:
	draw_dashed_line(r.position, r.position + Vector2(r.size.x, 0), c, 1.0, 5.0)
	draw_dashed_line(r.position + Vector2(r.size.x, 0), r.end, c, 1.0, 5.0)
	draw_dashed_line(r.end, r.position + Vector2(0, r.size.y), c, 1.0, 5.0)
	draw_dashed_line(r.position + Vector2(0, r.size.y), r.position, c, 1.0, 5.0)


func rect_of(a: Array) -> Rect2: return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


func button(label: String, r: Rect2) -> void:
	draw_rect(r, C_PANEL_HI if hit(r) else Color("#262b3b"))
	text(label, r.get_center().x, r.position.y + r.size.y / 2 + 5, 15, C_TEXT, "c", true)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if view in TITLE_VIEWS:
		return  # title.gd draws the whole screen
	draw_rect(Rect2(0, 0, W, H), C_BG)
	if shake > 0.3 and not reduce_flash:
		draw_set_transform(Vector2((randf() - 0.5) * shake, (randf() - 0.5) * shake))
	_draw_world()
	draw_set_transform(Vector2.ZERO)
	# fade the HUD if something important is underneath it
	var goal_y := float(sim.L.goal[1])
	ui_alpha = 0.3 if view == "play" and not sim.done and (goal_y < 75.0 or sim.py < 75.0) else 1.0
	_draw_hud()
	ui_alpha = 1.0
	if view == "play" and not sim.done:
		_draw_toast()
		_draw_cursor()
	if sim.done and view == "play":
		_draw_done()
	if cel != null and view == "play":
		cel.draw(self)
	if view == "menu":
		_draw_menu()
	elif view == "credits":
		_draw_credits()
	elif view == "stats":
		_draw_stats()
	elif view == "settings":
		_draw_settings()
	elif view == "pause":
		_draw_pause()
	elif view == "demo_end":
		_draw_demo_end()


## Cosmetic animated backdrop (behind everything): drifting glow orbs, a slow light sweep and twinkling
## dust, all in the level's neon colour. Purely visual; never touches the sim.
func _draw_backdrop(nc: Color, now: float) -> void:
	var alt := Color.from_hsv(fposmod(nc.h + 0.12, 1.0), 0.7, 1.0)
	for i in 7:
		var k := float(i) + float(li) * 3.1
		var c := Vector2(W * (0.5 + 0.46 * sin(k * 12.9898 + now * (0.05 + 0.012 * i))),
				H * (0.5 + 0.46 * sin(k * 78.233 + now * (0.04 + 0.01 * i) + 1.7)))
		var rad := 110.0 + 18.0 * float(i % 4)
		var pulse := 0.65 + 0.35 * sin(now * (0.7 + 0.13 * i) + k)
		var col := nc if i % 2 == 0 else alt
		for j in 12:
			var f := float(j) / 11.0
			draw_circle(c, rad * (1.0 - f * 0.85), Color(col, 0.019 * pulse))
	# slow vertical light sweep (skipped when flashing is reduced)
	if not reduce_flash:
		_draw_sweep(nc, now)
	_draw_dust(nc, alt, now)


func _draw_sweep(nc: Color, now: float) -> void:
	var sx := fposmod(now * 70.0, W + 400.0) - 200.0
	for j in 14:
		var d := absf(float(j) - 6.5) / 6.5
		draw_rect(Rect2(sx + float(j) * 14.0 - 98.0, 0, 14, H), Color(nc, 0.06 * (1.0 - d)))


func _draw_dust(nc: Color, alt: Color, now: float) -> void:
	# twinkling dust
	for i in 36:
		var q := float(i) * 91.7 + float(li)
		var pos := Vector2(fposmod(q * 37.1, W), fposmod(q * 53.9, H))
		var tw := 0.5 + 0.5 * sin(now * (0.9 + fposmod(q, 1.7)) + q)
		draw_circle(pos, 1.5 + 1.5 * tw, Color(alt if i % 3 == 0 else nc, 0.1 + 0.5 * tw * tw))


func _coach(id: String) -> void:
	if hints_seen.has(id): return
	if not toast.is_empty():
		if id not in hint_queue: hint_queue.append(id)
		return
	hints_seen[id] = true
	toast = {"text": HINTS[id], "t": 0.0}
	_save()


func _draw_toast() -> void:
	if toast.is_empty(): return
	var t: float = toast.t
	var a := clampf(minf(t / 0.3, (5.5 - t) / 0.5), 0.0, 1.0)
	var r := Rect2(W / 2 - 400, 150, 800, 34)
	draw_rect(r, Color(0.08, 0.1, 0.16, 0.88 * a))
	draw_rect(r, Color(neon(), 0.7 * a), false, 1.5)
	text(toast.text, W / 2, r.position.y + 22, 14, Color(1, 1, 1, a), "c", true)


func _spike(poly: PackedVector2Array) -> void:
	draw_colored_polygon(poly, C_SPIKE)
	if hc_hazards:
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, Color.WHITE, 1.5)


func _spike_rect(r: Rect2) -> void:
	draw_rect(r, C_SPIKE)
	if hc_hazards:
		draw_rect(r, Color.WHITE, false, 1.5)


func _draw_world() -> void:
	var L: Dictionary = sim.L
	var now := Time.get_ticks_msec() / 1000.0
	var p := Vector2(sim.px, sim.py)

	var nc := neon()
	var breathe := 0.88 + 0.12 * sin(now * 2.2)   # slow neon "hum"
	_draw_backdrop(nc, now)
	for x in range(0, int(W), 40): draw_line(Vector2(x, 0), Vector2(x, H), Color(nc, 0.035))
	for y in range(0, int(H), 40): draw_line(Vector2(0, y), Vector2(W, y), Color(nc, 0.035))

	# outer frame: dark border, neon line along the inside edge
	for b in data.border: draw_rect(rect_of(b), Color("#07080c"))
	neon_outline(Rect2(20, 20, W - 40, H - 40), nc, breathe)
	# interior walls: dark fill + neon outline (ghostly and dashed while phased)
	for b in L.get("s", []):
		var r := rect_of(b)
		if sim.phased:
			draw_rect(r, Color(nc.darkened(0.85), 0.25))
			dashed_rect(r, C_PURPLE)
		else:
			draw_rect(r, nc.darkened(0.86))
			neon_outline(r, nc, breathe)

	# spikes
	for k in L.get("k", []):
		if k.size() >= 7:
			var r := rect_of(Sim.spike_at(k, sim.t * float(sim.d.spike)))
			_spike_rect(r)
			var tooth := 6.0
			var i := 0.0
			while i < r.size.x:
				var x2 := minf(i + 10, r.size.x)
				_spike(PackedVector2Array([r.position + Vector2(i, 0), r.position + Vector2(i + 5, -tooth), r.position + Vector2(x2, 0)]))
				_spike(PackedVector2Array([r.position + Vector2(i, r.size.y), r.position + Vector2(i + 5, r.size.y + tooth), r.position + Vector2(x2, r.size.y)]))
				i += 10
			var j := 0.0
			while j < r.size.y:
				var y2 := minf(j + 10, r.size.y)
				_spike(PackedVector2Array([r.position + Vector2(0, j), r.position + Vector2(-tooth, j + 5), r.position + Vector2(0, y2)]))
				_spike(PackedVector2Array([r.position + Vector2(r.size.x, j), r.position + Vector2(r.size.x + tooth, j + 5), r.position + Vector2(r.size.x, y2)]))
				j += 10
		else:
			var r := rect_of(k)
			var up := r.position.y >= 60
			if r.size.x >= r.size.y:
				var n := maxi(1, roundi(r.size.x / 16.0))
				var sw := r.size.x / n
				for i in n:
					var bx := r.position.x + i * sw
					if up:
						_spike(PackedVector2Array([Vector2(bx, r.end.y), Vector2(bx + sw / 2, r.position.y), Vector2(bx + sw, r.end.y)]))
					else:
						_spike(PackedVector2Array([Vector2(bx, r.position.y), Vector2(bx + sw / 2, r.end.y), Vector2(bx + sw, r.position.y)]))
			else:
				spike_column(r)

	_draw_moving_solids()
	_draw_lasers(now)

	# arrival teleporter (screens 2+): a faint ring where you came in
	if sim.room > 0:
		var ap := Vector2(float(L.start[0]), float(L.start[1]))
		draw_arc(ap, 17, 0, TAU, 32, Color(C_GOAL, 0.25), 2.0)
		draw_arc(ap, 17, now * 2.0, now * 2.0 + PI * 0.6, 12, Color(C_GOAL, 0.5), 2.0)
	# goal: a solid green dot on the last screen, an exit teleporter (green rings) before that
	var gp := Vector2(float(L.goal[0]), float(L.goal[1]))
	if not sim.is_last_room():
		_draw_exit_portal(gp, now)
	elif sim.phased:
		draw_circle(gp, 16, Color(0.47, 0.47, 0.55, 0.15)); draw_circle(gp, 9, Color("#555a70"))
		draw_arc(gp, 16, 0, TAU, 32, C_PURPLE, 2.0)
	else:
		draw_circle(gp, 16 * (1 + sin(now * 5) * 0.08), Color(C_GOAL, 0.18)); draw_circle(gp, 9, C_GOAL)

	# yellow orbs
	for o in sim.orbs:
		var op := Vector2(o.x, o.y)
		if o.cd == 0: glow(op, 8, C_ORB)
		draw_circle(op, 8, Color(C_ORB, 0.2 if o.cd > 0 else 1.0))

	# red swing orbs
	for o in sim.reds:
		var op := Vector2(o.x, o.y)
		dashed_circle(op, float(sim.d.latch), Color(C_RED, 0.08 if o.cd > 0 else 0.28))
		glow(op, 9, C_RED)
		draw_circle(op, 9, Color("#7a3b3b") if o.cd > 0 else C_RED)
		draw_circle(op, 3.5, Color.WHITE)
	if sim.rope != null:
		draw_line(Vector2(sim.rope.o.x, sim.rope.o.y), p, Color("#ff9a9a"), 2.0)

	# purple phase orbs
	for o in sim.purs:
		var op := Vector2(o.x, o.y)
		var s := 1 + sin(now * 6.6 + o.x) * 0.12
		var a := 0.3 if o.cd > 0 else 1.0
		glow(op, 10 * s, C_PURPLE, a)
		draw_circle(op, 10 * s, Color(Color("#9b6bff"), a)); draw_circle(op, 4, Color(Color("#e6d9ff"), a))

	# orange teleport pairs
	var n_tp := 0
	for tp in sim.tps:
		var a := Vector2(tp.ax, tp.ay)
		var b := Vector2(tp.bx, tp.by)
		var alpha := 0.35 if tp.cd > 0 else 1.0
		draw_dashed_line(a, b, Color(C_ORANGE, 0.08 if tp.cd > 0 else 0.25), 1.0, 3.0)
		for e in [a, b]:
			var sp := now * 3.3 + n_tp
			glow(e, 11, C_ORANGE, alpha)
			draw_circle(e, 11, Color(C_ORANGE, alpha))
			draw_arc(e, 15, sp, sp + 2, 12, Color(Color("#ffd8a8"), alpha), 2.0)
			text(char(65 + n_tp), e.x, e.y + 4, 11, Color("#3a1d00"), "c", true)
		n_tp += 1

	# blue gravity orbs
	for o in sim.gravs:
		var op := Vector2(o.x, o.y)
		var a := 0.3 if o.cd > 0 else 1.0
		glow(op, 11, C_BLUE, a)
		draw_circle(op, 11, Color(C_BLUE, a))
		text("⇅", op.x, op.y + 5, 13, Color("#0b2540"), "c", true)

	_draw_ships(now)

	# ghost of your best run
	if ghost != null and sim.started and gi < ghost.size():
		var groom := floori(float(ghost[gi]) / GHOST_ROOM)
		if groom == sim.room:
			draw_circle(Vector2(float(ghost[gi]) - GHOST_ROOM * groom, ghost[gi + 1]), 11, Color(Color("#9fb4ff"), 0.35))

	for q in parts:
		draw_rect(Rect2(q.x - 2, q.y - 2, 4, 4), Color(q.c, q.life))

	# Easy: preview where this shot would take you
	if sim.d.get("preview", false) and not sim.done and view == "play" and sim.ammo > 0:
		var ghost_sim = sim.clone()
		var dir := fire_dir()
		if ghost_sim.fire(dir.x, dir.y):
			for f in 75:
				var res: String = ghost_sim.tick()
				if f % 3 == 0:
					draw_circle(Vector2(ghost_sim.px, ghost_sim.py), 2.5, Color(C_SHOT, 0.5 * (1.0 - f / 75.0)))
				if res == "dead":
					text("✕", ghost_sim.px, ghost_sim.py + 5, 14, Color(C_SPIKE, 0.8), "c", true)
				if res != "":
					break

	# aim line (hidden on Master / God)
	if not sim.done and sim.d.get("aim", true):
		var dir := (aim - p).normalized() if (aim - p).length() > 0 else Vector2.UP
		var col := Color(C_SHOT, 0.6) if sim.ammo > 0 else Color(1, 1, 1, 0.15)
		draw_dashed_line(p + dir * 16, p + dir * 60, col, 1.0, 5.0)
		var e := p + dir * 66
		var nrm := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([e + dir * 8, e + nrm * 5, e - nrm * 5]), Color(col, 0.8 if sim.ammo > 0 else 0.15))

	# player
	if sim.phased:
		glow(p, 11, C_PURPLE); draw_circle(p, 11, Color(Color("#c9b3ff"), 0.55))
	else:
		var body: Color = SKINS[skin][1]
		var gl: Color = SKINS[skin][2]
		if skin == SKINS.size() - 1:   # Rainbow
			gl = Color.from_hsv(fposmod(now * 0.25, 1.0), 0.6, 1.0)
			body = Color.from_hsv(fposmod(now * 0.25, 1.0), 0.15, 1.0)
		glow(p, 11, gl); draw_circle(p, 11, body)
	_draw_eyes(p, now)
	_draw_death_face()
	for i in sim.ammo_max:
		draw_circle(Vector2(p.x - (sim.ammo_max - 1) * 5 + i * 10, p.y - 22), 3.5, C_SHOT if i < sim.ammo else Color(1, 1, 1, 0.15))


## Exit teleporter to the next screen: two counter-rotating green rings around a dark core.
## Hollow (not a dot) so it reads as "a way through", not "the finish".
func _draw_exit_portal(gp: Vector2, now: float) -> void:
	var col := Color("#555a70") if sim.phased else C_GOAL
	glow(gp, 18, col, 0.6)
	draw_circle(gp, 15, Color(C_BG, 0.9))
	for k in 3:
		var a := now * 2.4 + k * TAU / 3.0
		draw_arc(gp, 18, a, a + 1.4, 12, col, 2.5)
		var b := -now * 3.4 + k * TAU / 3.0
		draw_arc(gp, 11, b, b + 1.2, 10, Color(col, 0.75), 2.0)
	draw_circle(gp, 3.5 + sin(now * 6.0), Color(col, 0.9))
	if sim.phased:
		draw_arc(gp, 22, 0, TAU, 32, C_PURPLE, 2.0)


## Same face as the menu's neon ball: eyes look where you're aiming (where you want to go) and
## blink now and then. With gravity flipped the face sits on the other side, so it reads as upside down.
func _draw_eyes(p: Vector2, now: float) -> void:
	var look := aim - p
	look = look.normalized() if look.length() > 1 else Vector2(1, 0)
	var up := -1.7 * sim.g
	var ink := Color("#1a1f33")
	var blink := fposmod(now, 3.7) < 0.12
	for side in [-1.0, 1.0]:
		var e := p + Vector2(side * 3.6, up) + look * 1.9
		if blink:
			draw_line(e - Vector2(1.9, 0), e + Vector2(1.9, 0), ink, 1.4)
		else:
			draw_circle(e, 1.8, ink)


## When you die, a faded copy of the ball with X eyes floats away from the spot (you respawn instantly).
func _draw_death_face() -> void:
	if death_face.is_empty(): return
	var a: float = death_face.life
	var c := Vector2(death_face.x, death_face.y)
	var up: float = -1.7 * death_face.g
	var ink := Color(Color("#1a1f33"), a)
	draw_circle(c, 11, Color(C_TEXT, 0.55 * a))
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 3.6, up)
		draw_line(e - Vector2(1.8, 1.8), e + Vector2(1.8, 1.8), ink, 1.4)
		draw_line(e - Vector2(1.8, -1.8), e + Vector2(1.8, -1.8), ink, 1.4)
	# little "o" mouth
	draw_arc(c + Vector2(0, -up * 1.6), 1.6, 0, TAU, 12, ink, 1.2)


func _tau() -> float:
	return sim.t * float(sim.d.spike)


## Elevators (cyan, carry you) and pushers (amber with chevrons, knock you). A faint track shows their path.
func _draw_moving_solids() -> void:
	var tau := _tau()
	for m in sim.L.get("mv", []):
		var knock := float(m[7]) if m.size() > 7 else 0.0
		var c := C_PUSHER if knock > 0.0 else C_ELEVATOR
		var base := Rect2(float(m[0]), float(m[1]), float(m[2]), float(m[3]))
		var ext := Vector2(float(m[4]), float(m[5]))
		draw_dashed_line(base.get_center() - ext, base.get_center() + ext, Color(c, 0.18), 1.0, 4.0)
		var r := rect_of(Sim.mv_at(m, tau))
		if sim.phased:
			draw_rect(r, Color(c.darkened(0.8), 0.25)); dashed_rect(r, C_PURPLE)
			continue
		# moving things are FILLED; static walls are only outlined
		neon_outline(r, c, 1.0)
		draw_rect(r, Color(c, 0.88))
		if knock > 0.0:
			var ph := float(m[8]) if m.size() > 8 else 0.0
			var moving := cos(2.0 * PI * (tau / float(m[6]) + ph))
			var dir := ext.normalized() * (1.0 if moving >= 0.0 else -1.0)
			var perp := Vector2(-dir.y, dir.x)
			for k in [-1, 0, 1]:
				var q: Vector2 = r.get_center() + dir * (k * 11.0)
				draw_colored_polygon(PackedVector2Array([q + dir * 5, q - dir * 3 + perp * 6, q - dir * 3 - perp * 6]), Color("#2a1600"))
		else:
			draw_line(r.position + Vector2(2, 2), r.position + Vector2(r.size.x - 2, 2), Color(1, 1, 1, 0.9), 2.0)


## Timed lasers: dim dashes when off, flicker warning just before, bright beam when on.
func _draw_lasers(now: float) -> void:
	var tau := _tau()
	for lz in sim.L.get("lz", []):
		var a := Vector2(float(lz[0]), float(lz[1]))
		var b := Vector2(float(lz[2]), float(lz[3]))
		var period := float(lz[4]) + float(lz[5])
		var cyc := fmod(tau + float(lz[6]), period)
		if Sim.laser_on(lz, tau):
			beam(a, b, 1.0)
		elif cyc > period - 30.0:
			var flick := 0.25 if fmod(now * 18.0, 1.0) > 0.5 else 0.08
			draw_line(a, b, Color(C_LASER, flick), 1.5)
		else:
			draw_dashed_line(a, b, Color(C_LASER, 0.45 if hc_hazards else 0.10), 1.0, 6.0)
		for e in [a, b]:
			draw_rect(Rect2(e - Vector2(5, 5), Vector2(10, 10)), Color("#2a0a12"))
			draw_rect(Rect2(e - Vector2(5, 5), Vector2(10, 10)), C_LASER, false, 1.5)


func beam(a: Vector2, b: Vector2, scale: float) -> void:
	draw_line(a, b, Color(C_LASER, 0.12), 14.0 * scale)
	draw_line(a, b, Color(C_LASER, 0.45), 6.0 * scale)
	draw_line(a, b, Color(1, 0.85, 0.9, 0.95), 2.0 * scale)


## Gunships: turn toward their locked target, show a charge line, then fire.
func _draw_ships(now: float) -> void:
	var tau := _tau()
	var ships_def: Array = sim.L.get("ship", [])
	for j in ships_def.size():
		var sh: Array = ships_def[j]
		var st: Dictionary = sim.ships[j]
		var pos := Sim.ship_at(sh, tau)
		var cyc := fmod(tau + float(sh[6]), float(sh[5]))
		var dir := (Vector2(sim.px, sim.py) - pos).normalized()
		if st.lock != null:
			var a := Vector2(st.lock.ox, st.lock.oy)
			var b := Vector2(st.lock.ex, st.lock.ey)
			dir = (b - a).normalized()
			if st.firing:
				beam(a, b, 1.3)
			elif cyc < Sim.SHIP_CHARGE:
				var k: float = cyc / Sim.SHIP_CHARGE
				draw_line(a, b, Color(C_LASER, 0.08 + 0.4 * k), 1.0 + 2.0 * k)
		if dir == Vector2.ZERO:
			dir = Vector2.DOWN
		var perp := Vector2(-dir.y, dir.x)
		glow(pos, 14, C_SHIP, 0.8)
		draw_colored_polygon(PackedVector2Array([pos + dir * 18, pos - dir * 10 + perp * 13, pos - dir * 4, pos - dir * 10 - perp * 13]), C_SHIP)
		draw_circle(pos + dir * 3, 4.0, Color("#ffe0e6"))
		if st.lock != null and not st.firing and cyc < Sim.SHIP_CHARGE:
			draw_circle(pos + dir * 18, 2.0 + 5.0 * cyc / Sim.SHIP_CHARGE, Color(C_LASER, 0.8))


func _draw_hud() -> void:
	draw_rect(HUD_LEVELS, Color(C_PANEL_HI if hit(HUD_LEVELS) else Color(0.15, 0.17, 0.23, 0.9), ui_alpha))
	text("☰ Levels", HUD_LEVELS.get_center().x, HUD_LEVELS.position.y + 20, 13, Color("#c6cde8"), "c", true)
	var lv: Dictionary = sim.rooms[0]
	var screens := "   screen %d/%d" % [sim.room + 1, sim.rooms.size()] if sim.rooms.size() > 1 else ""
	text("%s  %s%s" % [level_code(li), lv.name, screens], 126, 39, 15, Color("#c6cde8"), "l", true)
	text(str(lv.get("world", "")).to_upper(), 126 + 90, 58, 12, world_color(li), "l", true)
	text(data.difficulties[diff].label.to_upper(), 126, 58, 12, DIFF_COLOR[diff], "l", true)
	if one_life():
		text("run %s   best run %s" % [fmt(god.total + (0 if sim.done else sim.t)), fmt(best["god:run"]) if best.has("god:run") else "—"], W - 34, 39, 15, Color("#c6cde8"), "r", true)
		text("shots %d   fewest run %s" % [god.shots + (0 if sim.done else sim.shots), str(best["god:shots"]) if best.has("god:shots") else "—"], W - 34, 58, 13, C_SHOT, "r", true)
	else:
		text("%s   best %s   deaths %d" % [fmt(sim.t), fmt(best[key(li)]) if best.has(key(li)) else "—", deaths], W - 34, 39, 15, Color("#c6cde8"), "r", true)
		if practicing(): text("PRACTICE", W - 34, 80, 12, C_ORB, "r", true)
		text("shots %d   fewest %s" % [sim.shots, str(best[skey(li)]) if best.has(skey(li)) else "—"], W - 34, 58, 13, C_SHOT, "r", true)
	if not sim.done and (sim.phased or sim.g < 0):
		if sim.phased and sim.g < 0:
			text("PHASED — touch purple to unlock goal", W / 2 - 60, 39, 14, C_PURPLE, "c", true)
			text("GRAVITY ↑", W / 2 + 170, 39, 14, C_BLUE, "c", true)
		elif sim.phased:
			text("PHASED — touch purple to unlock goal", W / 2, 39, 14, C_PURPLE, "c", true)
		else:
			text("GRAVITY ↑", W / 2, 39, 14, C_BLUE, "c", true)
	if god.flash > 0 and one_life():
		text("ONE LIFE — back to level 1", W / 2, 150, 26, Color(C_SPIKE, minf(1.0, god.flash / 40.0)), "c", true)
	var ty := 0
	if in_run():
		var clock := fmt_run(run.t)
		var bt = best.get("run:" + diff, null)
		var col := Color("#c6cde8")
		var extra := "best %s" % fmt_run(bt) if bt != null else "first run"
		if run.delta != null and not run.finished:
			col = C_GOAL if run.delta <= 0 else C_RED
			extra = "%s  (%s)" % [extra, fmt_delta(run.delta)]
		text("FULL RUN  %s   %d/%d   %s" % [clock, li + (1 if sim.done else 0), playable_total(), extra], W - 34, 78, 14, col, "r", true)
		ty = 24
	if not sim.started and view == "play":
		var tip: String = sim.rooms[0].tip
		if li == 0 and using_pad:
			tip = "Point the stick where you want to fly, then press A. You launch that way."
		text(tip, W / 2, 80 + ty, 15, C_SUB)
		var controls := "stick = aim · A / RT = fire · Y restart · Start levels" if using_pad else \
			"click / tap / %s = fire  ·  %s retry  ·  %s full run  ·  %s / %s next / back  ·  %s levels  ·  Esc menu" % [
				_key_name(int(keys.fire)).to_lower(), _key_name(int(keys.retry)), _key_name(int(keys.run)),
				_key_name(int(keys.next)), _key_name(int(keys.back)), _key_name(int(keys.levels))]
		text(controls, W / 2, 102 + ty, 13, C_DIM)


## In-game cursor: a neon arrow pointing straight away from the ball (the way you'll fly).
func _draw_cursor() -> void:
	var p := Vector2(sim.px, sim.py)
	var d := aim - p
	var dir := d.normalized() if d.length() > 0.5 else Vector2.UP
	var perp := Vector2(-dir.y, dir.x)
	var a := 1.0 if sim.ammo > 0 else 0.35
	var c := neon()
	var tip := aim
	var shape := PackedVector2Array([tip, tip - dir * 14 + perp * 10, tip - dir * 10 + perp * 3.5, tip - dir * 26 + perp * 3.5,
		tip - dir * 26 - perp * 3.5, tip - dir * 10 - perp * 3.5, tip - dir * 14 - perp * 10])
	var loop := shape.duplicate()
	loop.append(shape[0])
	for layer in [[9.0, 0.08], [5.0, 0.2]]:
		draw_polyline(loop, Color(c, layer[1] * a), layer[0], true)
	draw_colored_polygon(shape, Color(c.lightened(0.55), 0.92 * a))
	draw_polyline(loop, Color(c, a), 1.5, true)


func _draw_done() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.78))
	if practicing():
		text("PRACTICE CLEAR", W / 2, 200, 26, C_ORB, "c", true)
		text("%s  ·  %d shot%s  ·  nothing saved" % [fmt(sim.t), sim.shots, "" if sim.shots == 1 else "s"], W / 2, 250, 17, C_SUB, "c", true)
		button("Retry (R)", BTN_RETRY); button("Levels (L)", BTN_LEVELS); button("Next (N)", BTN_NEXT)
		return
	if one_life():
		if god.finished:
			text("GOD MODE CLEARED", W / 2, 200, 22, C_ORB, "c", true)
			text(fmt(god.total), W / 2, 260, 48, C_GOAL if new_best else C_TEXT, "c", true)
			var line := ("New best run time!" if new_best else "Best run %s" % fmt(best["god:run"])) + \
				"   ·   %d shots" % god.shots + (" (new fewest!)" if new_fewest else "  (fewest %s)" % str(best["god:shots"]))
			text(line, W / 2, 295, 17, C_SUB)
			button("Run again (R)", BTN_RETRY); button("Levels (L)", BTN_LEVELS)
			if demo: text("DEMO COMPLETE · the full game has %d levels" % level_total(), W / 2, 410, 15, C_ORB, "c", true)
		else:
			text("%d / %d cleared" % [li + 1, playable_total()], W / 2, 250, 40, C_TEXT, "c", true)
			text("run time %s  ·  %d shots  ·  click to continue" % [fmt(god.total), god.shots], W / 2, 290, 17, C_SUB)
		return
	if in_run() and run.finished:
		text("FULL RUN CLEARED · %s" % data.difficulties[diff].label.to_upper(), W / 2, 190, 22, C_ORB, "c", true)
		text(fmt_run(run.t), W / 2, 258, 54, C_GOAL if run.new_best else C_TEXT, "c", true)
		var bt = best["run:" + diff]
		var line := "New best run!" if run.new_best else "Best %s" % fmt_run(bt)
		text(line + "   ·   %d shots   ·   %d deaths" % [run.shots, run.deaths], W / 2, 295, 17, C_SUB)
		button("Run again (F)", BTN_RETRY); button("Levels (L)", BTN_LEVELS)
		return
	var sh := sim.shots
	if in_run():
		var d := "" if run.delta == null else "   %s vs best run" % fmt_delta(run.delta)
		text("run %s%s" % [fmt_run(run.t), d], W / 2, 318, 14, C_GOAL if run.delta != null and run.delta <= 0 else C_SUB, "c", true)
	text(fmt(sim.t), W / 2 - 110, 235, 44, C_GOAL if new_best else C_TEXT, "c", true)
	text("%d shot%s" % [sh, "" if sh == 1 else "s"], W / 2 + 110, 235, 44, C_GOAL if new_fewest else C_SHOT, "c", true)
	text("NEW BEST TIME" if new_best else "best %s" % fmt(best[key(li)]), W / 2 - 110, 262, 13, C_SUB, "c", true)
	text("NEW FEWEST SHOTS" if new_fewest else "fewest %s" % str(best[skey(li)]), W / 2 + 110, 262, 13, C_SUB, "c", true)
	var star_txt: String = ["", "CLEARED", "FLAWLESS: no deaths", "PERFECT: flawless and no more shots than your best"][last_stars]
	text("★".repeat(last_stars) + "  " + star_txt, W / 2, 292, 16, C_ORB, "c", true)
	button("Retry (R)", BTN_RETRY); button("Levels (L)", BTN_LEVELS); button("Next (N)", BTN_NEXT)


func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.92))
	text("Levels", W / 2, 60, 28, C_TEXT, "c", true)
	draw_rect(NEON_BOX, C_PANEL_HI if hit(NEON_BOX) else C_PANEL)
	text("Neon: by %s ⇄" % neon_mode, NEON_BOX.get_center().x, NEON_BOX.position.y + 20, 13, neon(), "c", true)
	draw_rect(MUSIC_BOX, C_PANEL_HI if hit(MUSIC_BOX) else C_PANEL)
	text("Music: %s" % ("muted" if music_volume <= 0.0 else "%d%%" % roundi(music_volume * 100)), MUSIC_BOX.get_center().x, MUSIC_BOX.position.y + 20, 13, C_TEXT, "c", true)
	if not one_life():
		draw_rect(RUN_BOX, C_PANEL_HI if hit(RUN_BOX) else C_PANEL)
		var rb = best.get("run:" + diff, null)
		text("Full run (F)  %s" % (fmt_run(rb) if rb != null else "—"), RUN_BOX.get_center().x, RUN_BOX.position.y + 20, 13, C_ORB, "c", true)
	for i in DIFFS.size():
		var b := diff_box(i)
		var on: bool = DIFFS[i] == diff
		draw_rect(b, DIFF_COLOR[DIFFS[i]] if on else (C_PANEL_HI if hit(b) else C_PANEL))
		text(data.difficulties[DIFFS[i]].label, b.get_center().x, b.position.y + 22, 14, Color("#0d0f14") if on else DIFF_COLOR[DIFFS[i]], "c", true)
	var blurbs := {
		"easy": "+1 shot · slow spikes · big grab zones · shows where you'll fly",
		"medium": "The game as designed.",
		"hard": "Yellow orbs work once · faster spikes · tighter grabs",
		"master": "Spike hitboxes bigger than they look · fastest spikes · no aim line",
		"god": "Master rules · ONE LIFE for all %d levels · die and restart from 1   (best run %s, fewest shots %s)" % [
			playable_total(), fmt(best["god:run"]) if best.has("god:run") else "—", str(best["god:shots"]) if best.has("god:shots") else "—"],
	}
	text(blurbs[diff], W / 2, 140, 13, C_SUB)
	if one_life():
		text("Click any level to start a God run from level 1", W / 2, 160, 13, C_ORB, "c", true)
	for i in level_total():
		var b := menu_box(i)
		var wc := world_color(i)
		var selected := using_pad and i == menu_sel
		if i % 5 == 0 and i < 50:  # world name above its first level
			text(data.worlds[i / 5].to_upper(), b.position.x, b.position.y - 3, 10, wc, "l", true)
		elif i == 50:
			text("FINALS — 3+ MECHANICS EACH", b.position.x, b.position.y - 3, 10, C_ORB, "l", true)
		draw_rect(b, C_PANEL_HI if hit(b) or selected else C_PANEL)
		if selected: draw_rect(b, C_TEXT, false, 2.0)
		draw_rect(Rect2(b.position, Vector2(b.size.x, 2)), wc)
		if i >= playable_total():   # locked in the demo: dimmed, with a padlock
			draw_rect(b, Color(0.05, 0.06, 0.08, 0.72))
			var c := b.get_center() + Vector2(0, 2)
			draw_rect(Rect2(c.x - 8, c.y - 3, 16, 12), C_DIM)
			draw_arc(Vector2(c.x, c.y - 3), 5.0, PI, TAU, 12, C_DIM, 2.0)
			text(level_code(i), b.position.x + 5, b.position.y + 15, 10, Color(wc, 0.5), "l", true)
			continue
		var nm: String = data.levels[i].name
		text(level_code(i), b.position.x + 5, b.position.y + 15, 10, wc, "l", true)
		text(nm, b.get_center().x, b.position.y + 28, 11 if nm.length() <= 11 else 9, C_TEXT, "c", true)
		var bt = best.get(key(i), null)
		var bs = best.get(skey(i), null)
		if bt != null and bs != null:
			text("%s  %d shots" % [fmt(bt), int(bs)], b.get_center().x, b.position.y + 42, 10, C_GOAL)
		var st := int(best.get("st:" + key(i), 0))
		if st > 0: text("★".repeat(st), b.end.x - 5, b.position.y + 15, 10, C_ORB, "r", true)
	var legend := "LB / RB difficulty · D-pad pick · A play" if using_pad else "cleared levels show  best time, fewest shots and stars (★ clear · ★★ flawless · ★★★ perfect)"
	if demo: legend = "DEMO · first %d of %d levels · the full game unlocks the rest" % [playable_total(), level_total()]
	text(legend, W / 2, 528, 11, C_DIM)
	draw_rect(CREDITS_BOX, C_PANEL_HI if hit(CREDITS_BOX) else C_PANEL)
	text("Credits (C)", CREDITS_BOX.get_center().x, CREDITS_BOX.position.y + 16, 11, C_SUB, "c", true)


## End of the demo: what the full game adds.
func _draw_demo_end() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.97))
	text("DEMO COMPLETE", W / 2, 120, 34, C_ORB, "c", true)
	text("You cleared the first %d levels." % playable_total(), W / 2, 168, 18, C_TEXT, "c", true)
	var lines := ["The full game adds", "%d levels in 10 worlds" % level_total(), "10 three-screen finals with teleporters",
		"Lasers, gunships, pushers and gravity flips", "God Mode: one life for the whole run"]
	for i in lines.size():
		text(lines[i], W / 2, 224 + i * 28, 15 if i > 0 else 13, C_SUB if i == 0 else C_TEXT, "c", i > 0)
	if STEAM_URL != "":
		draw_rect(BTN_WISHLIST, C_PANEL_HI if hit(BTN_WISHLIST) else C_PANEL)
		text("Wishlist on Steam", BTN_WISHLIST.get_center().x, BTN_WISHLIST.position.y + 30, 18, C_GOAL, "c", true)
	else:
		text("Coming to Steam", W / 2, 408, 20, C_GOAL, "c", true)
	text("click or press Esc to go back to the levels", W / 2, 512, 12, C_DIM)


func _cleared_any(i: int) -> bool:
	var rv := ":3s" if data.levels[i].has("rooms") else ""
	for d in DIFFS:
		if best.has(d + ":" + str(i) + rv): return true
	return false


func fmt_play(ticks: float) -> String:
	var sec := int(ticks / 60.0)
	if sec >= 3600: return "%dh %02dm" % [sec / 3600, (sec / 60) % 60]
	if sec >= 60: return "%dm %02ds" % [sec / 60, sec % 60]
	return "%ds" % sec


## Career stats: lifetime totals and averages.
func _draw_stats() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.97))
	text("CAREER STATS", W / 2, 66, 28, C_TEXT, "c", true)
	var clears: int = stats.clears
	var deaths: int = stats.deaths
	var worst := -1
	var worst_n := 0
	for k in stats.by_level:
		if int(stats.by_level[k]) > worst_n: worst_n = int(stats.by_level[k]); worst = int(k)
	var unique := 0
	for i in level_total():
		if _cleared_any(i): unique += 1
	var left := [
		["Time played", fmt_play(stats.ticks)],
		["Levels cleared (total clears)", str(clears)],
		["Unique levels cleared", "%d / %d" % [unique, playable_total()]],
		["Average clear time", fmt(float(stats.clear_ticks) / clears) if clears > 0 else "—"],
		["Full runs finished", str(stats.runs)],
	]
	var right := [
		["Total deaths", str(deaths)],
		["Deaths per level cleared", "%.1f" % (float(deaths) / clears) if clears > 0 else "—"],
		["Total jumps (shots fired)", str(stats.shots)],
		["Jumps per level cleared", "%.1f" % (float(stats.shots) / clears) if clears > 0 else "—"],
		["Deadliest level", "%s %s  ×%d" % [level_code(worst), data.levels[worst].name, worst_n] if worst >= 0 else "—"],
	]
	for col in 2:
		var rows: Array = left if col == 0 else right
		var x := 60.0 + col * 440.0
		for r in rows.size():
			var y := 130.0 + r * 46.0
			draw_rect(Rect2(x, y - 22, 400, 38), C_PANEL)
			text(rows[r][0], x + 14, y + 2, 14, C_SUB, "l")
			text(rows[r][1], x + 386, y + 3, 17, C_TEXT, "r", true)
	text("CLEARED BY DIFFICULTY", 60, 392, 12, C_ORB, "l", true)
	for i in DIFFS.size():
		var d: String = DIFFS[i]
		var n := 0
		for lv in level_total():
			var rv := ":3s" if data.levels[lv].has("rooms") else ""
			if best.has(d + ":" + str(lv) + rv): n += 1
		var bx := 60.0 + i * 176.0
		text(data.difficulties[d].label, bx, 418, 13, DIFF_COLOR[d], "l", true)
		text("%d / %d" % [n, playable_total()], bx, 440, 16, C_TEXT, "l", true)
		var rb = best.get("run:" + d, null) if d != "god" else best.get("god:run", null)
		text("best run " + (fmt_run(rb) if rb != null else "—"), bx, 458, 11, C_DIM, "l")
	text("Counted from the update that added Career Stats.  Click or press Esc to close.", W / 2, 512, 12, C_DIM)


## Required attributions: music (CC BY 4.0), engine (MIT), symbol font (Bitstream Vera).
# ---------------------------------------------------------------- pause menu

func pause_rows() -> Array:
	var rows := ["resume", "retry"]
	if not one_life() and not in_run(): rows.append("practice")
	rows.append_array(["settings", "menu"])
	if FEEDBACK_URL != "": rows.append("feedback")
	return rows


func pause_rect(i: int) -> Rect2:
	return Rect2(W / 2 - 150, 170 + i * 46, 300, 38)


func _pause_activate(i: int) -> void:
	match pause_rows()[i]:
		"resume": view = "play"
		"retry":
			view = "play"
			if one_life(): start_god()
			elif in_run() and run.finished: start_run()
			else: load_level(li)
		"practice":
			practice = not practice
			view = "play"; load_level(li)
		"settings":
			credits_back = "pause"; set_sel = 0; listening = ""; set_note = ""; view = "settings"
		"menu": open_main_menu()
		"feedback": OS.shell_open(FEEDBACK_URL)
	sfx.beep(520, 0.05, "triangle", 0.05)


func _pause_click() -> void:
	var rows := pause_rows()
	for i in rows.size():
		if hit(pause_rect(i)): pause_sel = i; _pause_activate(i); return
	view = "play"   # click outside the buttons resumes


func _pause_key(code: int) -> void:
	var n := pause_rows().size()
	match code:
		KEY_ESCAPE: view = "play"
		KEY_UP: pause_sel = posmod(pause_sel - 1, n)
		KEY_DOWN: pause_sel = posmod(pause_sel + 1, n)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _pause_activate(pause_sel)


func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.86))
	text("PAUSED", W / 2, 110, 30, C_TEXT, "c", true)
	var rows := pause_rows()
	for i in rows.size():
		var r := pause_rect(i)
		var on := hit(r) or i == pause_sel
		draw_rect(r, C_PANEL_HI if on else C_PANEL)
		var label := ""
		match rows[i]:
			"resume": label = "Resume"
			"retry": label = "Retry"
			"practice": label = "Practice mode: ON (tap to turn off)" if practice else "Practice mode (infinite shots)"
			"settings": label = "Settings"
			"menu": label = "Main menu"
			"feedback": label = "Send feedback"
		text(label, r.get_center().x, r.position.y + 25, 15, C_ORB if rows[i] == "practice" and practice else C_TEXT, "c", true)
	text("Esc resumes.  Practice mode saves no records or stats.", W / 2, 170 + rows.size() * 46 + 16, 12, C_DIM, "c")


# ---------------------------------------------------------------- settings (accessibility + controls)

const SET_ROWS := ["flash", "contrast", "hints", "skin", "key:fire", "key:retry", "key:next", "key:back", "key:levels", "key:run", "reset", "back"]

func set_row_rect(i: int) -> Rect2:
	return Rect2(210, 96 + i * 30 + (16 if i >= 4 else 0) + (12 if i >= 10 else 0), 540, 25)


func _key_name(code: int) -> String:
	return OS.get_keycode_string(code)


func _settings_activate(i: int) -> void:
	var id: String = SET_ROWS[i]
	set_note = ""
	if id == "flash": reduce_flash = not reduce_flash; shake = 0.0
	elif id == "contrast": hc_hazards = not hc_hazards
	elif id == "hints": hints_seen = {}; toast = {}; hint_queue = []
	elif id == "skin":
		for k in range(1, SKINS.size() + 1):   # next unlocked colour
			var n := (skin + k) % SKINS.size()
			if skin_unlocked(n): skin = n; break
	elif id.begins_with("key:"): listening = id.substr(4); set_note = "Press a key for \"%s\"  (Esc cancels)" % listening
	elif id == "reset":
		keys = {"fire": KEY_SPACE, "retry": KEY_R, "next": KEY_N, "back": KEY_B, "levels": KEY_L, "run": KEY_F}
	elif id == "back": view = credits_back; _save(); return
	sfx.beep(520, 0.05, "triangle", 0.05)
	_save()


func _settings_click() -> void:
	if listening != "":
		listening = ""; set_note = ""; return
	for i in SET_ROWS.size():
		if hit(set_row_rect(i)):
			set_sel = i; _settings_activate(i); return


func _settings_key(code: int) -> void:
	if listening != "":
		if code == KEY_ESCAPE:
			listening = ""; set_note = ""; return
		# keys that already mean something fixed (menus, mute, neon, credits, previews)
		var reserved := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_T, KEY_V, KEY_C, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5]
		if code in reserved:
			set_note = "%s is reserved. Pick another key." % _key_name(code); sfx.beep(150, 0.1, "square", 0.05); return
		for k in keys:   # taking a key from another action swaps the two
			if k != listening and int(keys[k]) == code: keys[k] = keys[listening]
		keys[listening] = code
		listening = ""; set_note = ""
		sfx.beep(660, 0.06, "sine", 0.06); _save()
		return
	match code:
		KEY_ESCAPE: view = credits_back; _save()
		KEY_UP: set_sel = posmod(set_sel - 1, SET_ROWS.size())
		KEY_DOWN: set_sel = posmod(set_sel + 1, SET_ROWS.size())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _settings_activate(set_sel)


func _draw_settings() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.97))
	text("SETTINGS", W / 2, 66, 28, C_TEXT, "c", true)
	text("ACCESSIBILITY", 210, 90, 11, C_DIM, "l")
	text("CONTROLS  (click a row, then press the new key)", 210, 96 + 30 * 4 + 16 - 5, 11, C_DIM, "l")
	for i in SET_ROWS.size():
		var id: String = SET_ROWS[i]
		var r := set_row_rect(i)
		var on := hit(r) or i == set_sel
		draw_rect(r, C_PANEL_HI if on else C_PANEL)
		var label := ""
		var value := ""
		var vcol := C_SUB
		if id == "flash":
			label = "Reduce flashing & shake"; value = "ON" if reduce_flash else "off"; vcol = C_GOAL if reduce_flash else C_DIM
		elif id == "contrast":
			label = "High-contrast hazards"; value = "ON" if hc_hazards else "off"; vcol = C_GOAL if hc_hazards else C_DIM
		elif id == "skin":
			label = "Ball colour"
			var nxt := -1
			for k in SKINS.size():
				if not skin_unlocked(k): nxt = k; break
			value = SKINS[skin][0] + ("" if nxt < 0 else "   (next: %s at %d cleared)" % [SKINS[nxt][0], SKINS[nxt][3]])
			vcol = SKINS[skin][2] if skin != SKINS.size() - 1 else C_ORB
		elif id == "hints":
			label = "Replay coaching tips"; value = "%d / %d seen" % [hints_seen.size(), HINTS.size()]
		elif id.begins_with("key:"):
			var k := id.substr(4)
			for row in KEY_ROWS:
				if row[0] == k: label = row[1]
			value = "press a key…" if listening == k else _key_name(int(keys[k]))
			vcol = C_ORB if listening == k else C_TEXT
		elif id == "reset": label = "Reset keys to default"
		else: label = "Back"
		text(label, r.position.x + 14, r.position.y + 17, 14, C_TEXT, "l", true)
		if value != "": text(value, r.end.x - 14, r.position.y + 17, 14, vcol, "r", true)
	if set_note != "": text(set_note, W / 2, 522, 13, C_ORB, "c", true)
	else: text("Up / Down + Enter, or click.   T neon · V mute · C credits · Esc are fixed keys.", W / 2, 522, 11, C_DIM, "c")


func _draw_credits() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.96))
	text("CREDITS", W / 2, 70, 28, C_TEXT, "c", true)
	text("MUSIC BY DAVIDKBD", W / 2, 112, 13, C_ORB, "c", true)
	text("\"Code Injection Dark Techno Music Pack\" by DavidKBD", W / 2, 136, 16, C_TEXT, "c", true)
	text("davidkbd.itch.io  ·  davidkbd.com  ·  cover art and track names by Naitsel", W / 2, 158, 12, C_SUB)
	text("Licensed under CC BY 4.0 (creativecommons.org/licenses/by/4.0). Tracks used unmodified; volume balanced in-game.", W / 2, 178, 12, C_SUB)
	var titles := ["01 Underbeat", "02 Behind the Darkness", "03 Synthetic Whisper", "04 Secret Dissonance",
		"05 Into the Code Abyss", "06 Electric Inferno", "07 Binary Chaos", "08 Sentinel Cloud", "09 Ghost Steps",
		"10 Space Echoes", "11 I.A.'s Growl", "12 Faceless Crowd", "13 Between Everyone and Anyone", "14 There's Someone Here"]
	for i in titles.size():
		text(titles[i], 200 + (i / 7) * 330, 210 + (i % 7) * 20, 12, C_DIM, "l")
	text("Title theme: \"Pink Bloom\" music track by DavidKBD, from the \"Pink Bloom Synthwave Music Pack\" (davidkbd.itch.io)", W / 2, 352, 12, C_SUB)
	text("ENGINE", W / 2, 378, 13, C_ORB, "c", true)
	text("Made with Godot Engine  ·  godotengine.org/license", W / 2, 398, 13, C_TEXT, "c")
	text("© 2014-present Godot Engine contributors; © 2007-2014 Juan Linietsky, Ariel Manzur. MIT license.", W / 2, 415, 11, C_SUB)
	text("FONT", W / 2, 442, 13, C_ORB, "c", true)
	text("Inter by The Inter Project Authors (SIL Open Font License 1.1)  ·  symbols: DejaVu Sans (Bitstream Vera license)", W / 2, 462, 12, C_SUB)
	text("click or press C to close", W / 2, 512, 12, C_DIM)
