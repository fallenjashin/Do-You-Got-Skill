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
	check(game.view == "title", "the game opens on the start screen")
	t._unhandled_input(_key(KEY_X))
	check(game.view == "main", "any key opens the main menu")
	t._process(1.5)
	check(t.trans == 1.0 and t.pop > 0.0, "the sign finishes sliding and the ball appears")
	check(game.music.current == "00_title_pink_bloom", "Pink Bloom plays on the start screen and menu")
	var ids: Array = t.items().map(func(it): return it.id)
	check(ids.slice(0, 8) == ["play", "select", "difficulty", "leaderboard", "music", "neon", "aim", "credits"], "menu lists play, levels, difficulty, leaderboard, music, neon, aim, credits")
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
	var mv: float = game.music_volume
	t.sel = ids.find("music"); t._unhandled_input(_key(KEY_LEFT))
	check(game.music_volume != mv, "left/right change the music volume")
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
	game._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "main", "Esc during play opens the main menu")
	t._process(0.1)
	check(game.music.current == "00_title_pink_bloom", "opening the menu mid-game brings the title song back")
	t._unhandled_input(_key(KEY_ESCAPE))
	check(game.view == "play", "Esc in the main menu goes back to the game")
	check(game.music.current == game.music.track_for_level(game.li), "going back to the game brings the level's song back")

	game.set_diff("medium"); game.aim_mode = "go"; game.load_level(0)

	# aiming "where you go": click up-right of the ball -> it moves up and right
	var start := Vector2(game.sim.px, game.sim.py)
	game.aim = start + Vector2(100, -150); game.press(); ticks(15)
	check(game.sim.shots == 1 and game.sim.py < start.y - 40 and game.sim.px > start.x, "aim-where-you-go launches up and right")

	# old style: aim far below the ball (even outside the play area) -> launches up
	game.aim_mode = "fire"; game.load_level(0)
	game.aim = Vector2(game.sim.px, 900); game.press(); ticks(12)
	check(game.sim.py < start.y - 40, "aim-where-you-fire works with the cursor below the play area")
	game.aim_mode = "go"

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
	game.music_volume = 0.7; game.cycle_music()
	check(game.music_volume == 0.4, "V lowers music 70% -> 40%")
	game.view = "menu"; game.aim = game.MUSIC_BOX.get_center(); game.press(); game.press()
	check(game.music_volume == 1.0, "level-screen button cycles 40% -> off -> 100%")
	var sv = JSON.parse_string(FileAccess.open("user://test_save.json", FileAccess.READ).get_as_text())
	check(float(sv.get("music", -1)) == 1.0, "music volume is saved")
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
	print("game test: %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	game.free()
	quit(1 if failures else 0)
