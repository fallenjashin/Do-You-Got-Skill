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


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://test_save.json"   # never touch the player's real progress
	if FileAccess.file_exists(game.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	root.add_child(game)
	await process_frame
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

	# music: right track per world group, looping, volume steps saved
	game.set_diff("medium"); game.load_level(3)
	check(game.music.current.ends_with("neon_drive.ogg") and game.music.is_playing(), "worlds 1-5 play Neon Drive")
	game.load_level(30)
	check(game.music.current.ends_with("overclock.ogg"), "worlds 6-10 switch to Overclock")
	game.load_level(31)
	check(game.music.current.ends_with("overclock.ogg"), "same world group keeps the same track")
	game.load_level(55)
	check(game.music.current.ends_with("final_exam.ogg") and game.music._active.stream.loop, "finals play Final Exam, looping")
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
	check(FileAccess.file_exists("user://test_save.json"), "progress saved to disk")
	print("game test: %s" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	game.free()
	quit(1 if failures else 0)
