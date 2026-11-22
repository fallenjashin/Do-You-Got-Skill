extends SceneTree
## Gameplay smoke test: drives the real game scene the way a player would.
## Run:  godot --headless --path . -s tests/test_game.gd

var game
var failures := 0


func check(cond: bool, what: String) -> void:
	print(("ok    " if cond else "FAIL  ") + what)
	if not cond: failures += 1


func ticks(n: int) -> void:
	for i in n: game._physics_process(1.0 / 60.0)


func center(r: Rect2) -> Vector2: return r.get_center()


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	return e


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://test_save.json"   # never touch the player's real progress
	if FileAccess.file_exists(game.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	root.add_child(game)
	await process_frame

	# ---- start screen and main menu
	var t: Node2D = game.title
	check(game.view == "splash", "the game opens on the creator splash")
	check(game.music.current == "00_title_pink_bloom" and game.music.is_playing(), "the title song starts with the creator splash, no level song first")
	t._unhandled_input(_key(KEY_X))
	check(game.view == "splash", "the splash ignores a keypress in its first instant")
	for i in 10: t._process(0.05)    # the splash clock advances at most 0.05 s a frame
	t._unhandled_input(_key(KEY_X))
	check(game.view == "title", "any key skips the splash to the start screen")
	game.view = "splash"; t.splash_t = 0.0
	for i in 20: t._process(0.05)
	check(game.view == "splash", "the splash is still showing after 1 s")
	for i in 50: t._process(0.05)
	check(game.view == "title", "the splash hands over to the start screen by itself")
	check(game.view == "title", "the game opens on the start screen")
	t._unhandled_input(_key(KEY_X))
	check(game.view == "main", "any key opens the main menu")
	t._process(1.5)
	check(t.trans == 1.0 and t.pop > 0.0, "the sign finishes sliding and the ball appears")
	check(game.music.current == "00_title_pink_bloom", "Pink Bloom plays on the start screen and menu")
	var ids: Array = t.items().map(func(it): return it.id)
	check(ids.slice(0, 11) == ["play", "select", "fullrun", "difficulty", "leaderboard", "music", "neon", "stats", "settings", "feedback", "credits"], "menu lists play, levels, full run, difficulty, leaderboard, music, neon, stats, settings, feedback, credits")
	var beeps_before: int = game.sfx._next
	t._unhandled_input(_key(KEY_DOWN))
	check(t.sel == 1 and t.hop < 1.0, "down arrow moves the ball to the next item")
	check(game.sfx._next == beeps_before, "moving through the menu makes no sound")
	t._process(0.5)
	t._unhandled_input(_key(KEY_ENTER))
	check(game.view == "menu", "Select Level opens the level grid")
	game._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "main", "Esc on the level grid goes back to the main menu")
	t.sel = ids.find("leaderboard"); t._unhandled_input(_key(KEY_ENTER))
	check(game.view == "leaderboard", "Leaderboard opens its placeholder screen")
	t._unhandled_input(_key(KEY_RIGHT))
	check(t.lb_level == posmod(game.last_level + 1, 60), "left/right browse levels on the leaderboard")
	t._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "main", "Esc leaves the leaderboard")
	t.sel = ids.find("credits"); t._unhandled_input(_key(KEY_ENTER))
	check(game.view == "credits", "Credits opens from the main menu")
	game.press()
	check(game.view == "main", "closing credits returns to the main menu")
	game.set_music_volume(0.5)
	t.sel = ids.find("music"); t._unhandled_input(_key(KEY_RIGHT))
	check(is_equal_approx(game.music_volume, 0.51), "right arrow raises the volume by 1%")
	var held := _key(KEY_LEFT); held.echo = true
	t._unhandled_input(held); t._unhandled_input(held)
	check(is_equal_approx(game.music_volume, 0.49), "holding left keeps lowering it 1% at a time")
	var big := _key(KEY_RIGHT); big.shift_pressed = true
	t._unhandled_input(big)
	check(is_equal_approx(game.music_volume, 0.59), "shift + right raises it by 10%")
	var bar: Rect2 = t.slider_rect(ids.find("music"))
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	click.position = bar.position + Vector2(bar.size.x * 0.25, bar.size.y / 2)
	t._unhandled_input(click)
	check(is_equal_approx(game.music_volume, 0.25), "clicking the volume bar sets it (25%)")
	var drag := InputEventMouseMotion.new(); drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = bar.position + Vector2(bar.size.x * 0.8, bar.size.y / 2)
	t._unhandled_input(drag)
	check(is_equal_approx(game.music_volume, 0.8), "dragging the bar slides the volume (80%)")
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false
	t._unhandled_input(up)
	var d0: String = game.diff
	t.sel = ids.find("difficulty")
	var held2 := _key(KEY_RIGHT); held2.echo = true
	t._unhandled_input(held2)
	check(game.diff == d0, "holding a key doesn't spin through other settings")
	t.sel = ids.find("difficulty"); t._unhandled_input(_key(KEY_RIGHT))
	check(game.diff != "medium" and game.view == "main", "left/right change the difficulty")
	game.set_diff("medium")
	var player_before = game.music._active
	t.sel = 0; t._unhandled_input(_key(KEY_ENTER))
	check(game.view == "play" and game.li == game.last_level, "Play continues from the last level")
	check(game.music._active != player_before and game.music._active.get_playback_position() < 0.5, "starting from the menu restarts the song")
	player_before = game.music._active
	game.load_level(game.li)
	check(game.music._active == player_before, "retrying a level keeps the song going")
	game.view = "menu"; game.aim = game.menu_box(game.li).get_center(); game.press()
	check(game.music._active != player_before, "picking a level on the grid restarts the song")
	game._process(0.016)
	check(game.cursor_hidden, "the normal mouse pointer is hidden while playing")
	game._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "pause", "Esc during play opens the pause menu")
	game._process(0.016)
	check(not game.cursor_hidden, "and the mouse pointer comes back in the pause menu")
	game.pause_sel = game.pause_rows().find("menu"); game._unhandled_input(_key(KEY_ENTER))
	check(game.view == "main", "pause menu: Main menu opens the title menu")
	t._process(0.1)
	check(game.music.current == "00_title_pink_bloom", "opening the menu mid-game brings the title song back")
	t._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "play", "Esc in the main menu goes back to the game")
	check(game.music.current == game.music.track_for_level(game.li), "going back to the game brings the level's song back")

	game.set_diff("medium"); game.load_level(0)

	# aiming "where you go": click up-right of the ball -> it moves up and right
	var start := Vector2(game.sim.px, game.sim.py)
	game.aim = start + Vector2(100, -150); game.press(); ticks(15)
	check(game.sim.shots == 1 and game.sim.py < start.y - 40 and game.sim.px > start.x, "aim-where-you-go launches up and right")

	check(not "aim" in game.title.items().map(func(it): return it.id) and not "aim_mode" in game, "the 'aim where you fire' option is gone")

	# winning records time + shots
	game.load_level(0); game.aim = Vector2(game.sim.px, 0); game.press()
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; ticks(1)
	check(game.sim.done and game.new_best and game.best.has("medium:0") and game.best["s:medium:0"] == 1, "win saves best time and fewest shots")

	# results screen buttons
	game.aim = center(game.BTN_NEXT); game.press()
	check(game.li == 1 and not game.sim.done, "Next button loads level 2")

	# level select + difficulty buttons
	game.view = "menu"; game.aim = center(game.diff_box(0)); game.press()
	check(game.diff == "easy", "difficulty button switches to Easy")
	game.aim = center(game.menu_box(5)); game.press()
	check(game.li == 5 and game.view == "play" and game.sim.ammo_max == 3, "level box opens level 6 with Easy's extra shot")

	# Easy preview uses a copy of the run; copying must not disturb the real one and must predict it exactly
	game.aim = Vector2(game.sim.px + 80, game.sim.py - 200)
	var c = game.sim.clone(); var dir: Vector2 = game.fire_dir()
	c.fire(dir.x, dir.y)
	for i in 40: c.tick()
	game.press(); ticks(40)
	check(absf(c.px - game.sim.px) < 1e-9 and absf(c.py - game.sim.py) < 1e-9, "Easy preview predicts the shot exactly")

	# God mode: one life
	game.view = "menu"; game.aim = center(game.diff_box(4)); game.press()
	game.aim = center(game.menu_box(10)); game.press()
	check(game.diff == "god" and game.li == 0, "God mode always starts at level 1")
	game.aim = Vector2(game.sim.px, 0); game.press()
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; ticks(1)
	game.press()
	check(game.li == 1 and game.god.total > 0, "God mode advances and keeps run time")
	var k: Array = game.sim.L.k[0]
	game.aim = Vector2(game.sim.px, 0); game.press()
	game.sim.px = k[0] + k[2] / 2.0; game.sim.py = k[1] + 4.0; ticks(1)
	check(game.li == 0 and game.god.total == 0 and game.god.flash > 0, "dying in God mode sends you back to level 1")

	# controller
	game.set_diff("medium"); game.load_level(0)
	game._pad_button(JOY_BUTTON_START)
	check(game.view == "menu", "Start opens level select")
	game._pad_button(JOY_BUTTON_DPAD_RIGHT); game._pad_button(JOY_BUTTON_DPAD_DOWN)
	check(game.menu_sel == 11, "D-pad moves the selection (right 1, down a row of 10)")
	game._pad_button(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.diff == "hard", "RB changes difficulty")
	game._pad_button(JOY_BUTTON_A)
	check(game.view == "play" and game.li == 11 and game.diff == "hard", "A starts the selected level")
	game.aim = Vector2(game.sim.px, game.sim.py - 120)
	game._pad_button(JOY_BUTTON_A)
	check(game.sim.shots == 1, "A fires")

	# new hazards through the real game
	game.set_diff("medium"); game.load_level(30)   # 7-1 Lift
	var plat: Array = game.sim.L.mv[0]
	game.sim.started = true
	game.sim.px = float(plat[0]) + 60.0; game.sim.py = float(plat[1]) - 11.5
	var y0: float = game.sim.py
	for i in 40: game.sim.tick()
	check(not game.sim.dead and game.sim.py < y0 - 60.0, "elevator carries the player")
	var deaths_before: int = game.deaths
	game.load_level(40)                         # 9-1 Gate (laser at x 480)
	game.aim = Vector2(game.sim.px, 0); game.press()
	game.sim.px = 480.0; game.sim.py = 300.0; game.sim.vx = 0.0; game.sim.vy = 0.0
	ticks(3)
	check(game.deaths == deaths_before + 1 and game.li == 40 and game.sim.shots == 0, "laser kills and the level restarts")
	game.load_level(45)                         # 10-1 Sentry
	game.sim.started = true
	for i in 200:
		if game.sim.tick() != "": break
	check(game.sim.ships[0].lock != null, "gunship locks on to the player")
	check(game.level_code(12) == "3-3" and game.level_code(55) == "F6", "level codes read world-level")

	# music: every world its own DavidKBD track; finals and God Mode have their own
	game.set_diff("medium")
	var expect := {0: "01_underbeat", 7: "02_behind_the_darkness", 12: "09_ghost_steps", 17: "10_space_echoes",
		22: "05_into_the_code_abyss", 27: "04_secret_dissonance", 32: "03_synthetic_whisper", 37: "12_faceless_crowd",
		42: "06_electric_inferno", 47: "08_sentinel_cloud", 52: "07_binary_chaos", 57: "11_i_a_s_growl", 59: "13_between_everyone_and_anyone"}
	var all_ok := true
	for lvl in expect:
		game.load_level(lvl)
		if game.music.current != expect[lvl] or not game.music.is_playing(): all_ok = false
	check(all_ok, "each world, the finals and Final Exam play their own track")
	game.load_level(43)
	check(game.music.current == "06_electric_inferno", "levels in the same world keep the same track")
	check(game.music._active.stream.loop, "music loops")
	game.set_diff("god"); game.start_god()
	check(game.music.current == "14_theres_someone_here", "God Mode has its own track")
	game.set_diff("medium"); game.load_level(0)
	game.view = "menu"; game.aim = game.CREDITS_BOX.get_center(); game.press()
	check(game.view == "credits", "Credits button opens the credits screen")
	game.press()
	check(game.view == "menu", "clicking closes credits")
	game.set_music_volume(0.73)
	game._unhandled_input(_key(KEY_V))
	check(game.music_volume == 0.0, "V mutes the music")
	game._unhandled_input(_key(KEY_V))
	check(game.music_volume == 0.73, "V again brings back the same volume")
	game.view = "menu"; game.aim = game.MUSIC_BOX.get_center(); game.press()
	check(game.music_volume == 0.0, "level-grid Music button mutes")
	game.press()
	check(game.music_volume == 0.73, "and unmutes")
	var sv = JSON.parse_string(FileAccess.open("user://test_save.json", FileAccess.READ).get_as_text())
	check(float(sv.get("music", -1)) == 0.73, "music volume is saved")
	game.view = "play"

	# neon wall colour: follows difficulty by default, or the level's world
	game.neon_mode = "difficulty"; game.set_diff("master"); game.load_level(0)
	check(game.neon() == game.NEON_BY_DIFF["master"], "neon walls follow difficulty")
	game.toggle_neon(); game.load_level(16)
	check(game.neon_mode == "world" and game.neon() == game.world_color(16), "T switches neon to per-world colours")
	game.view = "menu"; game.aim = game.NEON_BOX.get_center(); game.press()
	check(game.neon_mode == "difficulty", "level-screen button switches it back")
	var saved = JSON.parse_string(FileAccess.open("user://test_save.json", FileAccess.READ).get_as_text())
	check(saved.get("neon", "") == "difficulty", "neon choice is saved")
	game.load_level(17)
	var sv2 = JSON.parse_string(FileAccess.open("user://test_save.json", FileAccess.READ).get_as_text())
	check(int(sv2.get("last", -1)) == 17, "the last level played is saved for Play/continue")
	check(FileAccess.file_exists("user://test_save.json"), "progress saved to disk")
	# multi-screen finals: exit teleporter -> next screen; shots carry; speed only on Hard+
	var finals := []
	for i in game.level_total():
		if game.data.levels[i].has("rooms"): finals.append(i)
	check(finals.size() == 10 and finals.all(func(i): return game.data.levels[i].rooms.size() == 2), "all 10 finals have 3 screens")
	var fi: int = finals[0]
	game.set_diff("medium"); game.load_level(fi); game.sim.started = true
	var ex: Array = game.sim.L.goal
	game.sim.px = float(ex[0]); game.sim.py = float(ex[1]); game.sim.vx = 6.0; game.sim.vy = -3.0; game.sim.ammo = 1
	ticks(1)
	var r1: Dictionary = game.sim.rooms[1]
	check(game.sim.room == 1 and not game.sim.done, "touching the exit teleporter goes to screen 2, not the finish")
	check(game.sim.px == float(r1.start[0]) and game.sim.vx == 0.0 and game.sim.vy == 0.0, "on Medium you arrive standing still at the screen's start")
	check(game.sim.ammo == 1, "shots carry over to the next screen")
	game.set_diff("hard"); game.load_level(fi); game.sim.started = true
	game.sim.px = float(ex[0]); game.sim.py = float(ex[1]); game.sim.vx = 6.0; game.sim.vy = -3.0
	ticks(1)
	check(game.sim.room == 1 and game.sim.vx > 5.0, "on Hard your speed carries into the next screen")
	var deaths0: int = game.deaths
	game.sim.px = 500.0; game.sim.py = 508.0; game.sim.vx = 0.0; game.sim.vy = 2.0   # into the floor spikes
	ticks(1)
	check(game.li == fi and game.sim.room == 1 and not game.sim.dead and game.deaths == deaths0 + 1, "dying on screen 2 respawns on screen 2")
	check(game.sim.px == float(r1.start[0]) and game.sim.t > 0, "back at the screen's start, clock still running")
	game.sim._enter_room(2, false)
	check(game.sim.is_last_room(), "screen 3 is the last screen")
	var gl: Array = game.sim.L.goal
	game.sim.px = float(gl[0]); game.sim.py = float(gl[1]); game.sim.vx = 0.0; game.sim.vy = 0.0
	ticks(1)
	check(game.sim.done and game.best.has("hard:%d:3s" % fi), "the green dot on screen 3 finishes; record goes in the 3-screen slot")
	game.set_diff("medium")

	# ---- Full Run: all 60 levels on one clock
	game.set_diff("medium")
	game.start_run()
	check(game.in_run() and game.li == 0 and game.run.t == 0, "Full Run starts on level 1 with the clock at 0")
	ticks(30)
	check(game.run.t == 0, "the run clock waits for your first shot")
	game.aim = Vector2(game.sim.px, 0); game.press(); ticks(10)
	check(game.run.t == 10, "the run clock counts ticks once you've fired")
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0
	ticks(1)
	check(game.sim.done and game.run.splits.size() == 1 and game.run.splits[0] == game.run.t, "beating a level records a split")
	var clock_done: int = game.run.t
	ticks(20)
	check(game.run.t == clock_done, "the clock stops between levels")
	game._unhandled_input(_key(KEY_B))
	check(game.li == 0, "B can't skip back during a Full Run")
	game._unhandled_input(_key(KEY_N))
	check(game.li == 1 and game.in_run(), "N goes on to level 2 inside the run")
	game.aim = Vector2(game.sim.px, 0); game.press(); ticks(5)
	var k2: Array = game.sim.L.k[0]
	game.sim.px = k2[0] + k2[2] / 2.0; game.sim.py = k2[1] + 4.0; ticks(1)
	check(game.run.deaths == 1 and game.li == 1 and game.run.t > clock_done, "dying keeps the clock running and counts the death")
	game._unhandled_input(_key(KEY_F))
	check(game.li == 0 and game.run.t == 0 and game.run.splits.is_empty() and game.run.deaths == 0, "F restarts the whole run")
	game.view = "menu"; game.aim = game.menu_box(5).get_center(); game.press()
	check(not game.in_run() and game.li == 5, "picking a level from the grid leaves the run")
	# finish a run: win each level in turn
	game.start_run()
	for lvl in 60:
		game.aim = Vector2(game.sim.px, 0); game.press()
		game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0
		if game.sim.rooms.size() > 1: game.sim._enter_room(game.sim.rooms.size() - 1, false)
		game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]
		ticks(2)
		if lvl < 59: game._unhandled_input(_key(KEY_N))
	check(game.run.finished and game.run.splits.size() == 60 and game.li == 59, "beating level 60 finishes the run with 60 splits")
	check(game.best.has("run:medium") and game.best["runs:medium"].size() == 60 and game.run.new_best, "the first finished run becomes the best run, with all splits")
	game.start_run()
	game.aim = Vector2(game.sim.px, 0); game.press(); ticks(40)
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0
	ticks(1)
	check(game.run.delta != null and game.run.delta == game.run.t - int(game.best["runs:medium"][0]), "splits compare against your best run")
	check(game.fmt_run(65.0 * 60.0 + 12.0) == "1:05.20" and game.fmt_run(3725.0 * 60.0) == "1:02:05.00" and game.fmt_run(213.0) == "3.55", "run times format as m:ss.cc / h:mm:ss.cc")
	game.set_diff("god")
	check(not game.in_run(), "God Mode is its own category, not a Full Run")
	game.set_diff("medium")

	# ---- career stats
	game.stats = {"ticks": 0, "deaths": 0, "shots": 0, "clears": 0, "clear_ticks": 0, "runs": 0, "by_level": {}}
	game.set_diff("medium"); game.load_level(3)
	ticks(30)
	check(game.stats.ticks == 30, "career time counts ticks spent in a level")
	game.aim = Vector2(game.sim.px, 0); game.press(); ticks(5)
	check(game.stats.shots == 1, "career counts shots fired (jumps)")
	game.press()   # no ammo left or a blocked shot must not count if sim refuses
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0
	ticks(1)
	check(game.stats.clears == 1 and game.stats.clear_ticks == game.sim.t, "career counts clears and their time")
	var ticks_done: int = game.stats.ticks
	ticks(30)
	check(game.stats.ticks == ticks_done, "career time stops on the clear screen")
	game.load_level(3); game.aim = Vector2(game.sim.px, 0); game.press()
	var kk: Array = game.sim.L.k[0]
	game.sim.px = kk[0] + kk[2] / 2.0; game.sim.py = kk[1] + 4.0; ticks(1)
	check(game.stats.deaths == 1 and game.stats.by_level["3"] == 1, "career counts deaths, per level")
	game._save()
	var sv_stats = JSON.parse_string(FileAccess.open(game.save_path, FileAccess.READ).get_as_text())
	check(sv_stats.stats.deaths == 1 and sv_stats.stats.clears == 1, "career stats are saved")
	game.stats = {"ticks": 0, "deaths": 0, "shots": 0, "clears": 0, "clear_ticks": 0, "runs": 0, "by_level": {}}
	game._load_save()
	check(game.stats.deaths == 1 and game.stats.by_level["3"] == 1, "career stats load back from the save")
	game.credits_back = "main"; game.view = "stats"
	game.press()
	check(game.view == "main", "clicking closes the stats screen")
	check(game.fmt_play(3725.0 * 60.0) == "1h 02m" and game.fmt_play(95.0 * 60.0) == "1m 35s" and game.fmt_play(42.0 * 60.0) == "42s", "play time formats")

	# ---- demo build: the first 15 levels, the rest locked
	game.set_diff("medium"); game.demo = true
	check(game.playable_total() == 15, "the demo has 15 playable levels")
	game.start_from_menu(15)
	check(game.li != 15, "a locked level doesn't start in the demo")
	game.load_level(14)
	check(game.li == 14, "the last demo level loads")
	game.aim = Vector2(game.sim.px, 0); game.press()
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0
	ticks(2)
	game._unhandled_input(_key(KEY_N))
	check(game.view == "demo_end", "Next after the last demo level shows the demo ending")
	game._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "menu", "Esc leaves the demo ending for the level grid")
	game.load_level(14)
	check(game.li == 14, "the demo ending doesn't break the level")
	var best_before: int = game.best.size()
	game.start_run()
	for lvl in 15:
		game.aim = Vector2(game.sim.px, 0); game.press()
		game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0
		if game.sim.rooms.size() > 1: game.sim._enter_room(game.sim.rooms.size() - 1, false)
		game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]
		ticks(2)
		if lvl < 14: game._unhandled_input(_key(KEY_N))
	check(game.run.finished and not game.best.has("run:medium_demo") and game.run.splits.size() == 15, "a demo run ends after 15 levels")
	game.demo = false
	check(game.playable_total() == 60, "the full game has all 60 levels")

	# ---- settings: accessibility toggles and key rebinding
	game.set_diff("medium"); game.load_level(0); game.view = "play"
	game.credits_back = "play"; game.view = "settings"; game.set_sel = 0
	game._unhandled_input(_key(KEY_ENTER))
	check(game.reduce_flash, "Settings: Enter toggles reduce flashing on")
	game.set_sel = 1; game._unhandled_input(_key(KEY_ENTER))
	check(game.hc_hazards, "Settings: Enter toggles high-contrast hazards on")
	game.set_sel = 4; game._unhandled_input(_key(KEY_ENTER))
	check(game.listening == "fire", "Settings: choosing the fire row starts listening")
	game._unhandled_input(_key(KEY_T))
	check(game.listening == "fire" and int(game.keys.fire) == KEY_SPACE, "Settings: reserved keys (T) are refused")
	game._unhandled_input(_key(KEY_X))
	check(game.listening == "" and int(game.keys.fire) == KEY_X, "Settings: fire is rebound to X")
	game.set_sel = 5; game._unhandled_input(_key(KEY_ENTER)); game._unhandled_input(_key(KEY_X))
	check(int(game.keys.retry) == KEY_X and int(game.keys.fire) == KEY_R, "Settings: taking a used key swaps the two actions")
	game._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "play", "Settings: Esc returns where it came from")
	var shots_before: int = game.sim.shots
	game.aim = Vector2(game.sim.px + 100, game.sim.py - 100)
	game._unhandled_input(_key(KEY_R))
	check(game.sim.shots == shots_before + 1, "the rebound fire key (R) fires")
	game.view = "settings"; game.set_sel = 10; game._unhandled_input(_key(KEY_ENTER)); game.view = "play"
	check(int(game.keys.fire) == KEY_SPACE and int(game.keys.retry) == KEY_R, "Settings: reset restores the default keys")
	game.reduce_flash = false; game.hc_hazards = false

	# ---- pause menu, practice mode, stars, ball colours
	game.set_diff("medium"); game.run.on = false; game.practice = false; game.load_level(0); game.view = "play"
	game._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "pause", "Esc during play opens the pause menu")
	var px0: float = game.sim.px
	ticks(30)
	check(game.sim.t == 0 and game.sim.px == px0, "the game is frozen while paused")
	game._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "play", "Esc again resumes")
	game.view = "pause"; game.pause_sel = game.pause_rows().find("practice"); game._unhandled_input(_key(KEY_ENTER))
	check(game.practice and game.view == "play", "pause menu: Practice turns practice mode on and restarts the level")
	game.aim = Vector2(game.sim.px + 100, game.sim.py - 60)
	game.best = {}
	var clears0: int = game.stats.clears; var shots0: int = game.stats.shots
	for i in 6: game.press()
	check(game.sim.shots == 6 and game.sim.ammo > 0, "practice mode: shots are unlimited")
	check(game.stats.shots == shots0, "practice mode: shots are not counted in career stats")
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0
	ticks(3)
	check(game.sim.done and game.stats.clears == clears0 and not game.best.has("st:" + game.key(0)), "practice clear saves nothing")
	game.practice = false; game.load_level(0)
	game.best = {}
	game.flawless = true
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0; game.sim.started = true
	ticks(3)
	check(game.last_stars == 2 and int(game.best["st:" + game.key(0)]) == 2, "a first flawless clear earns 2 stars (3 needs a record to match)")
	game.load_level(0); game.flawless = true; game.sim.shots = 0
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0; game.sim.started = true
	ticks(3)
	check(game.last_stars == 3, "flawless again with no more shots than your fewest earns 3 stars")
	game.load_level(0); game.flawless = false
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0; game.sim.started = true
	ticks(3)
	check(game.last_stars == 1 and int(game.best["st:" + game.key(0)]) == 3, "after dying a clear is 1 star, and the best stars are kept")
	game.best = {}
	check(game.cleared_levels() == 0 and not game.skin_unlocked(1) and game.skin_unlocked(0), "ball colours: only Classic at the start")
	for i in 5: game.best["medium:%d" % i] = 1000
	check(game.cleared_levels() == 5 and game.skin_unlocked(1) and not game.skin_unlocked(2), "ball colours: Mint unlocks at 5 levels cleared")
	game.best = {}; game.load_level(0)

	# ---- coaching tips
	game.hints_seen = {}; game.toast = {}; game.set_diff("medium"); game.load_level(0); game.view = "play"
	game.aim = Vector2(game.sim.px + 200, game.sim.py - 120); game.press()
	ticks(50)
	check(game.hints_seen.has("arc") or game.hint_queue.has("arc"), "first shot on level 1 queues or shows the gravity tip")
	ticks(900)
	check(game.hints_seen.has("arc") and game.toast.is_empty(), "queued tips show in turn, then fade away by themselves")
	game.load_level(1); game.hints_seen = {}
	game.sim.px = 300.0; game.sim.py = 200.0; game.sim.vx = 6.0; game.sim.vy = 0.0; game.sim.grounded = false; game.sim.started = true; game.sim.ammo = 2
	game.aim = Vector2(game.sim.px + 100, game.sim.py)
	game.press()
	check(game.hints_seen.has("chain"), "firing the same way mid-air shows the chain tip")
	game.toast = {}
	game.sim.vx = 6.0; game.sim.ammo = 2
	game.aim = Vector2(game.sim.px - 100, game.sim.py)
	game.press()
	check(game.hints_seen.has("brake"), "firing against your motion shows the brake tip")
	game.hints_seen = {}; game.toast = {}; game.load_level(0)

	# ---- level-complete celebration tiers
	var T = game.get_script()
	check(T.celebration_tier(false, false, false, 0) == 1, "a plain clear is tier 1")
	check(T.celebration_tier(true, false, false, 0) == 2 and T.celebration_tier(false, true, false, 0) == 2, "a new best time or fewest shots is tier 2")
	check(T.celebration_tier(true, true, true, 0) == 3 and T.celebration_tier(true, true, false, 0) == 2, "beating both old records is tier 3; a first clear (both new, nothing beaten) stays tier 2")
	check(T.celebration_tier(true, true, true, 7) == 4 and T.celebration_tier(false, false, false, 10) == 4, "a top-10 rank is tier 4, over everything below")
	check(T.celebration_tier(false, false, false, 1) == 5, "first place is tier 5")
	check(T.celebration_tier(false, false, false, 11) == 1, "rank 11 is not top 10")
	game.set_diff("medium"); game.demo = false; game.load_level(0)
	game.aim = Vector2(game.sim.px, 0); game.press()
	game.sim.px = game.sim.L.goal[0]; game.sim.py = game.sim.L.goal[1]; game.sim.vx = 0.0; game.sim.vy = 0.0
	ticks(2)
	check(game.cel != null and game.cel.tier >= 1, "winning a level starts a celebration")
	game.load_level(0)
	check(game.cel == null, "starting a level clears the celebration")
	for tr in [1, 2, 3, 4, 5]:
		game.start_celebration(tr)
		check(game.cel.tier == tr, "tier %d celebration starts" % tr)
		for i in 360: game.cel.update(1.0 / 60.0)
		check(game.cel.t > 5.9, "tier %d celebration runs for 6 s without errors" % tr)
	check(game.cel.parts.size() < 900, "the biggest celebration stays under 900 particles")
	game.load_level(0)

	print("game test: %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	game.free()
	quit(1 if failures else 0)
