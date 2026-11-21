extends SceneTree
## Marketing capture: plays the real game scene through scripted beats and either saves screenshots
## or records a trailer (use Godot's movie mode so it renders frame by frame, then mix music with ffmpeg).
##
##   Screenshots (1920x1080 PNGs into <outdir>):
##     godot --path . --resolution 1920x1080 --fixed-fps 60 -s tools/marketing/trailer.gd -- shots runs.json <outdir>
##   Trailer video (silent music, game sound effects only; add music afterwards, see make_trailer.sh):
##     godot --path . --resolution 1920x1080 --write-movie trailer.avi --fixed-fps 60 \
##           -s tools/marketing/trailer.gd -- trailer runs.json <outdir>
##
## runs.json comes from tools/marketing/best_run.js: {"<level>": {acts: [[tick, dx, dy], ...]}}.
## Runs are replayed shot for shot through game.press(), so sound, particles and the cursor are the real ones.

const TRAILER_BEATS := [
	{"k": "run", "level": 0, "cap": "You can't walk.  You can only fire."},
	{"k": "run", "level": 5, "cap": "Swing."},
	{"k": "run", "level": 10, "cap": "Phase through walls."},
	{"k": "run", "level": 15, "cap": "Teleport."},
	{"k": "run", "level": 20, "cap": "Flip gravity."},
	{"k": "run", "level": 40, "cap": "Time the lasers."},
	{"k": "run", "level": 45, "cap": "Dodge gunships."},
	{"k": "run", "level": 51, "cap": "Finals: three screens, two teleporters.", "stop_room": 1},
	{"k": "view", "v": "menu", "n": 190, "cap": "60 levels.  Race your own ghost."},
	{"k": "view", "v": "title", "n": 200},
]

const SHOT_BEATS := [
	{"k": "view", "v": "title", "n": 100, "shot": "01_title"},
	{"k": "view", "v": "main", "n": 100, "shot": "02_main_menu"},
	{"k": "view", "v": "menu", "n": 60, "shot": "03_level_select"},
	{"k": "run", "level": 0, "pred": "fired2", "shot": "04_first_levels"},
	{"k": "run", "level": 5, "pred": "rope", "shot": "05_swing"},
	{"k": "run", "level": 10, "pred": "phase", "shot": "06_phase"},
	{"k": "run", "level": 15, "pred": "tp", "shot": "07_teleport"},
	{"k": "run", "level": 20, "pred": "grav", "shot": "08_gravity"},
	{"k": "run", "level": 45, "pred": "ship", "shot": "09_gunship"},
	{"k": "run", "level": 51, "pred": "portal", "shot": "10_final_exit_teleporter", "stop_room": 1},
	{"k": "run", "level": 51, "pred": "room2", "shot": "11_final_screen_two", "stop_room": 1},
]


class Driver extends Node:
	var game: Node
	var mode := "trailer"
	var runs := {}
	var outdir := "/tmp"
	var beats: Array = []
	var bi := -1
	var bf := 0
	var acts: Array = []
	var ai := 0
	var fired_at := -999
	var finish := 0
	var shot_wait := -1
	var pending_shot := ""
	var cap: Label
	var fade: ColorRect
	var layer: CanvasLayer

	func _ready() -> void:
		process_physics_priority = -100   # run before the game's own tick, so shots land on the right tick
		layer = CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		fade = ColorRect.new()
		fade.color = Color.BLACK
		fade.size = Vector2(960, 540)
		fade.modulate.a = 0.0
		layer.add_child(fade)
		cap = Label.new()
		cap.size = Vector2(960, 60)
		cap.position = Vector2(0, 452)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_override("font", load("res://assets/fonts/inter-display-extrabold.otf"))
		cap.add_theme_font_size_override("font_size", 26)
		cap.add_theme_color_override("font_color", Color("#e8f0ff"))
		cap.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08, 0.95))
		cap.add_theme_constant_override("outline_size", 8)
		cap.modulate.a = 0.0
		layer.add_child(cap)
		RenderingServer.frame_post_draw.connect(_post_draw)

	func _post_draw() -> void:
		if pending_shot != "":
			var img := get_viewport().get_texture().get_image()
			var path := "%s/%s.png" % [outdir, pending_shot]
			img.save_png(path)
			print("saved ", path, " ", img.get_size())
			pending_shot = ""

	func _next_beat() -> void:
		bi += 1
		if bi >= beats.size():
			print("DONE after ", Engine.get_frames_drawn(), " frames")
			get_tree().quit()
			return
		bf = 0; ai = 0; finish = 0; shot_wait = -1; fired_at = -999
		var b: Dictionary = beats[bi]
		cap.text = b.get("cap", "") if mode == "trailer" else ""
		if b.k == "view":
			game.view = b.v
		else:
			var key := str(int(b.level))
			if not runs.has(key):
				push_warning("no run for level " + key); _next_beat(); return
			acts = runs[key].acts
			game.set_diff(runs[key].get("diff", "medium"))
			game.load_level(int(b.level))
			game.view = "play"
			game.sim.started = true   # the search timed every run from tick 0
		print("beat ", bi, " ", b.k, " ", b.get("level", b.get("v", "")))

	func _pred(p: String) -> bool:
		var s = game.sim
		match p:
			"fired2": return s.shots >= 2 and bf - fired_at == 9
			"rope": return s.rope != null and s.shots >= 1
			"phase": return s.phased
			"tp": return s.last_tp.size() > 0 and bf - fired_at > 4
			"grav": return s.g < 0.0 and bf - fired_at > 8
			"ship":
				for sh in s.ships:
					if sh.firing or sh.lock != null:
						return true
				return false
			"portal":
				return s.room == 0 and Vector2(s.px, s.py).distance_to(Vector2(float(s.L.goal[0]), float(s.L.goal[1]))) < 150.0
			"room2": return s.room == 1 and bf > 0 and s.t > 0 and finish == 20
		return false

	func _physics_process(_d: float) -> void:
		if bi < 0 or bi >= beats.size() or (bi >= 0 and _beat_over()):
			_next_beat()
			if bi >= beats.size(): return
		var b: Dictionary = beats[bi]
		bf += 1
		if b.k == "run":
			while ai < acts.size() and int(acts[ai][0]) == game.sim.t:
				var p := Vector2(game.sim.px, game.sim.py)
				var dir := Vector2(float(acts[ai][1]), float(acts[ai][2]))
				game.aim = p - dir * 140.0   # the game fires opposite the cursor
				game.using_pad = false
				game.press()
				fired_at = bf
				ai += 1
			if game.sim.dead:
				push_warning("replay died on level %d at tick %d" % [b.level, game.sim.t]); finish = 9999
			var stop_room: int = b.get("stop_room", 99)
			if game.sim.done or game.sim.room >= stop_room:
				finish += 1
			if mode == "shots" and b.has("pred") and shot_wait < 0 and _pred(b.pred) and pending_shot == "":
				shot_wait = 0
		if mode == "shots" and b.has("shot"):
			if b.k == "view" and bf == int(b.n) - 1:
				pending_shot = b.shot
			elif shot_wait >= 0:
				shot_wait += 1
				if shot_wait == 2:
					pending_shot = b.shot
		# caption + dip to black between beats (trailer only)
		if mode == "trailer":
			var n_end := _frames_left(b)
			cap.modulate.a = clampf(minf(float(bf - 12), float(n_end - 6)) / 14.0, 0.0, 1.0)
			fade.modulate.a = clampf(maxf(1.0 - float(bf) / 8.0, 1.0 - float(n_end) / 8.0), 0.0, 1.0)

	func _frames_left(b: Dictionary) -> int:
		if b.k == "view":
			return int(b.n) - bf
		return 62 - finish if finish > 0 else 9999

	func _beat_over() -> bool:
		var b: Dictionary = beats[bi]
		if mode == "shots":
			if b.k == "view": return bf >= int(b.n) + 2
			return (shot_wait >= 3 and pending_shot == "") or finish > 60 or bf > 3000
		if b.k == "view": return bf >= int(b.n)
		return finish >= 62 or bf > 3000


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var game: Node = null
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for n in [scene] + scene.find_children("*", "", true, false):
		if n.has_method("load_level"):
			game = n
			break
	game.save_path = "user://marketing_capture.json"
	var d := Driver.new()
	d.game = game
	d.mode = args[0]
	d.runs = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	d.outdir = args[2]
	d.beats = TRAILER_BEATS if d.mode == "trailer" else SHOT_BEATS
	if d.mode == "trailer":
		game.set_music_volume(0.0)   # music is mixed in afterwards so it doesn't restart with every level
	DirAccess.make_dir_recursive_absolute(d.outdir)
	root.add_child(d)
