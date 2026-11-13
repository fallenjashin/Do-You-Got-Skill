extends Node2D
## Recoil — game layer: input, drawing, menus, difficulties, God mode, saving.
## All rules/physics live in sim.gd. Everything is drawn with shapes for now;
## swap in sprites once the art direction is decided.

const Sim := preload("res://scripts/sim.gd")
const SfxScript := preload("res://scripts/sfx.gd")
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
const NEON_BY_WORLD := [
	"#22e6ff","#22e6ff","#22e6ff","#22e6ff","#22e6ff",    # basics: cyan
	"#ff3df2","#ff3df2","#ff3df2",                        # swing: magenta
	"#9d6bff","#9d6bff","#9d6bff",                        # phase: violet
	"#ffd447",                                            # finale: gold
	"#ff9f2e","#ff9f2e",                                  # teleport: orange
	"#3d7bff","#3d7bff",                                  # gravity: electric blue
	"#b6ff3b",                                            # moving spikes: lime
	"#22e6ff","#ff3df2","#b6ff3b","#ff9f2e","#9d6bff","#3d7bff","#ffd447"]  # combos: a new colour each level
const GROUP_COLOR := ["#e8ecff","#e8ecff","#e8ecff","#e8ecff","#e8ecff","#ff6b6b","#ff6b6b","#ff6b6b",
	"#b388ff","#b388ff","#b388ff","#ffd166","#ff9f43","#ff9f43","#4dabf7","#4dabf7","#ff4d6d",
	"#2ed573","#2ed573","#2ed573","#2ed573","#2ed573","#2ed573","#2ed573"]

var data: Dictionary
var sim: Sim
var li := 0
var view := "play"            # "play" | "menu"
var diff := "medium"
var aim_mode := "go"          # "go" = point where you want to fly, "fire" = point where the blast goes
var neon_mode := "difficulty" # wall colour follows "difficulty" or "world" (level group)
var aim := Vector2(W / 2, H / 2)
var deaths := 0
var rec: Array = []           # this attempt's path, for the ghost
var ghost = null
var gi := 0
var shake := 0.0
var parts: Array = []
var new_best := false
var new_fewest := false
var best := {}                # "diff:i" -> ticks, "s:diff:i" -> shots, "god:run", "god:shots"
var ghosts := {}
var god := {"total": 0, "shots": 0, "flash": 0, "finished": false}
var menu_sel := 0             # controller selection on the level grid
var using_pad := false
var trigger_was_down := false
var ui_alpha := 1.0          # HUD fades when the goal or the ball is underneath it

var font: SystemFont
var font_bold: SystemFont
var sfx: Node  # scripts/sfx.gd (typed loosely so a fresh clone runs before Godot builds its class index)


func _ready() -> void:
	data = Sim.load_data()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Inter", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
	font_bold = font.duplicate()
	font_bold.font_weight = 750
	sfx = SfxScript.new()
	add_child(sfx)
	_load_save()
	load_level(0)


# ---------------------------------------------------------------- save / load

func _load_save() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed = JSON.parse_string(FileAccess.open(save_path, FileAccess.READ).get_as_text())
	if parsed is Dictionary:
		best = parsed.get("best", {})
		if parsed.get("diff", "") in DIFFS: diff = parsed.diff
		if parsed.get("aim", "") in ["go", "fire"]: aim_mode = parsed.aim
		if parsed.get("neon", "") in ["difficulty", "world"]: neon_mode = parsed.neon


func _save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"best": best, "diff": diff, "aim": aim_mode, "neon": neon_mode}))


# ---------------------------------------------------------------- helpers

func key(i: int) -> String: return diff + ":" + str(i)
func skey(i: int) -> String: return "s:" + diff + ":" + str(i)
func one_life() -> bool: return data.difficulties[diff].get("oneLife", false)
func fmt(ticks: float) -> String: return "%.2fs" % (ticks / 60.0)
func level_total() -> int: return data.levels.size()

func par(i: int):
	var table: Array = data.par.get("master" if diff == "god" else diff, [])
	return int(table[i]) if i < table.size() else null


func load_level(i: int) -> void:
	li = posmod(i, level_total())
	sim = Sim.new(li, diff)
	view = "play"
	rec = []
	gi = 0
	ghost = ghosts.get(key(li), null)
	new_best = false
	new_fewest = false


func start_god() -> void:
	god.total = 0; god.shots = 0; god.finished = false
	load_level(0)


func set_diff(dname: String) -> void:
	diff = dname
	_save()


func toggle_neon() -> void:
	neon_mode = "world" if neon_mode == "difficulty" else "difficulty"
	_save()


func neon() -> Color:
	return Color(NEON_BY_WORLD[li]) if neon_mode == "world" else NEON_BY_DIFF[diff]


func toggle_aim() -> void:
	aim_mode = "fire" if aim_mode == "go" else "go"
	_save()


func god_next() -> void:
	if li == level_total() - 1: god.finished = true
	else: load_level(li + 1)


## Direction the blast fires (you get pushed the opposite way).
func fire_dir() -> Vector2:
	var p := Vector2(sim.px, sim.py)
	return (p - aim) if aim_mode == "go" else (aim - p)


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
const AIM_BOX := Rect2(770, 26, 170, 30)
const NEON_BOX := Rect2(20, 26, 200, 30)

func menu_box(i: int) -> Rect2: return Rect2(85 + (i % 6) * 135, 178 + (i / 6) * 80, 120, 68)
func diff_box(i: int) -> Rect2: return Rect2(140 + i * 140, 78, 128, 34)
func hit(r: Rect2) -> bool: return r.has_point(aim)


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		aim = e.position; using_pad = false
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		aim = e.position; using_pad = false; press()
	elif e is InputEventScreenTouch and e.pressed:
		aim = e.position; using_pad = false; press()
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE: press()
			KEY_R: start_god() if one_life() else load_level(li)
			KEY_N:
				if not one_life(): load_level(li + 1)
				elif sim.done: god_next()
			KEY_B: if not one_life(): load_level(li - 1)
			KEY_L, KEY_ESCAPE: view = "play" if view == "menu" else "menu"
			KEY_M: toggle_aim()
			KEY_T: toggle_neon()
	elif e is InputEventJoypadButton and e.pressed:
		using_pad = true
		_pad_button(e.button_index)


func _pad_button(b: int) -> void:
	if view == "menu":
		match b:
			JOY_BUTTON_DPAD_LEFT: menu_sel = posmod(menu_sel - 1, level_total())
			JOY_BUTTON_DPAD_RIGHT: menu_sel = posmod(menu_sel + 1, level_total())
			JOY_BUTTON_DPAD_UP: menu_sel = posmod(menu_sel - 6, level_total())
			JOY_BUTTON_DPAD_DOWN: menu_sel = posmod(menu_sel + 6, level_total())
			JOY_BUTTON_LEFT_SHOULDER: set_diff(DIFFS[posmod(DIFFS.find(diff) - 1, DIFFS.size())])
			JOY_BUTTON_RIGHT_SHOULDER: set_diff(DIFFS[posmod(DIFFS.find(diff) + 1, DIFFS.size())])
			JOY_BUTTON_A: start_god() if one_life() else load_level(menu_sel)
			JOY_BUTTON_START, JOY_BUTTON_B: view = "play"
		return
	match b:
		JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER:
			if sim.done:
				if one_life():
					if god.finished: start_god()
					else: god_next()
				else: load_level(li + 1)
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
	if view == "menu":
		if hit(AIM_BOX): toggle_aim(); return
		if hit(NEON_BOX): toggle_neon(); return
		for i in DIFFS.size():
			if hit(diff_box(i)): set_diff(DIFFS[i]); return
		for i in level_total():
			if hit(menu_box(i)):
				if one_life(): start_god()
				else: load_level(i)
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
		if hit(BTN_RETRY): load_level(li)
		elif hit(BTN_LEVELS): view = "menu"
		elif hit(BTN_NEXT): load_level(li + 1)
		return
	var dir := fire_dir()
	if not sim.fire(dir.x, dir.y):
		sfx.beep(120, 0.05, "square", 0.03); return
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
	if view != "play":
		return
	var res := sim.tick()
	if sim.started and not sim.done and not sim.dead:
		rec.append(sim.px); rec.append(sim.py)
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
			"grav":
				sfx.beep(700 if sim.g > 0 else 300, 0.22, "sine", 0.07, 300 if sim.g > 0 else 700)
				burst(sim.px, sim.py, C_BLUE, 18, 4); shake = 4.0
			"tp":
				if sim.last_tp.size() == 4: burst(sim.last_tp[0], sim.last_tp[1], C_ORANGE, 16, 4)
				burst(sim.px, sim.py, C_ORANGE, 16, 4); sfx.beep(1200, 0.1, "triangle", 0.06, 500)
	sim.events.clear()
	if god.flash > 0: god.flash -= 1

	if res == "dead":
		deaths += 1; sfx.beep(90, 0.25, "sawtooth", 0.07); shake = 10.0
		burst(sim.px, sim.py, C_SPIKE, 30)
		if one_life():
			god.flash = 150
			start_god()
		else:
			load_level(li)
	elif res == "win":
		sfx.beep(660, 0.1, "sine", 0.08)
		get_tree().create_timer(0.1).timeout.connect(func(): sfx.beep(990, 0.18, "sine", 0.08))
		if not best.has(skey(li)) or sim.shots < best[skey(li)]:
			best[skey(li)] = sim.shots; new_fewest = true
		if one_life():
			god.total += sim.t; god.shots += sim.shots
			if not best.has(key(li)) or sim.t < best[key(li)]:
				best[key(li)] = sim.t; ghosts[key(li)] = rec.duplicate()
			if li == level_total() - 1:
				god.finished = true
				if not best.has("god:run") or god.total < best["god:run"]:
					best["god:run"] = god.total; new_best = true
				if not best.has("god:shots") or god.shots < best["god:shots"]:
					best["god:shots"] = god.shots; new_fewest = true
		elif not best.has(key(li)) or sim.t < best[key(li)]:
			best[key(li)] = sim.t; ghosts[key(li)] = rec.duplicate(); new_best = true
		_save()


func _process(_delta: float) -> void:
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
	draw_rect(Rect2(0, 0, W, H), C_BG)
	if shake > 0.3:
		draw_set_transform(Vector2((randf() - 0.5) * shake, (randf() - 0.5) * shake))
	_draw_world()
	draw_set_transform(Vector2.ZERO)
	# fade the HUD if something important is underneath it
	var goal_y := float(sim.L.goal[1])
	ui_alpha = 0.3 if view == "play" and not sim.done and (goal_y < 75.0 or sim.py < 75.0) else 1.0
	_draw_hud()
	ui_alpha = 1.0
	if sim.done and view == "play":
		_draw_done()
	if view == "menu":
		_draw_menu()


func _draw_world() -> void:
	var L: Dictionary = sim.L
	var now := Time.get_ticks_msec() / 1000.0
	var p := Vector2(sim.px, sim.py)

	var nc := neon()
	var breathe := 0.88 + 0.12 * sin(now * 2.2)   # slow neon "hum"
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
			glow(r.get_center(), maxf(r.size.x, r.size.y) * 0.4, C_SPIKE, 0.6)
			draw_rect(r, C_SPIKE)
			var tooth := 6.0
			var i := 0.0
			while i < r.size.x:
				var x2 := minf(i + 10, r.size.x)
				draw_colored_polygon(PackedVector2Array([r.position + Vector2(i, 0), r.position + Vector2(i + 5, -tooth), r.position + Vector2(x2, 0)]), C_SPIKE)
				draw_colored_polygon(PackedVector2Array([r.position + Vector2(i, r.size.y), r.position + Vector2(i + 5, r.size.y + tooth), r.position + Vector2(x2, r.size.y)]), C_SPIKE)
				i += 10
			var j := 0.0
			while j < r.size.y:
				var y2 := minf(j + 10, r.size.y)
				draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, j), r.position + Vector2(-tooth, j + 5), r.position + Vector2(0, y2)]), C_SPIKE)
				draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x, j), r.position + Vector2(r.size.x + tooth, j + 5), r.position + Vector2(r.size.x, y2)]), C_SPIKE)
				j += 10
		else:
			var r := rect_of(k)
			draw_rect(r.grow(3), Color(C_SPIKE, 0.10))
			var up := r.position.y >= 60
			if r.size.x >= r.size.y:
				var n := maxi(1, roundi(r.size.x / 16.0))
				var sw := r.size.x / n
				for i in n:
					var bx := r.position.x + i * sw
					if up:
						draw_colored_polygon(PackedVector2Array([Vector2(bx, r.end.y), Vector2(bx + sw / 2, r.position.y), Vector2(bx + sw, r.end.y)]), C_SPIKE)
					else:
						draw_colored_polygon(PackedVector2Array([Vector2(bx, r.position.y), Vector2(bx + sw / 2, r.end.y), Vector2(bx + sw, r.position.y)]), C_SPIKE)
			else:
				draw_rect(r, C_SPIKE)

	# goal
	var gp := Vector2(float(L.goal[0]), float(L.goal[1]))
	if sim.phased:
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

	# ghost of your best run
	if ghost != null and sim.started and gi < ghost.size():
		draw_circle(Vector2(ghost[gi], ghost[gi + 1]), 11, Color(Color("#9fb4ff"), 0.35))

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
		if aim_mode == "go":
			var e := p + dir * 66
			var nrm := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([e + dir * 8, e + nrm * 5, e - nrm * 5]), Color(col, 0.8 if sim.ammo > 0 else 0.15))

	# player
	if sim.phased:
		glow(p, 11, C_PURPLE); draw_circle(p, 11, Color(Color("#c9b3ff"), 0.55))
	else:
		glow(p, 11, Color("#7aa2ff")); draw_circle(p, 11, C_TEXT)
	for i in sim.ammo_max:
		draw_circle(Vector2(p.x - (sim.ammo_max - 1) * 5 + i * 10, p.y - 22), 3.5, C_SHOT if i < sim.ammo else Color(1, 1, 1, 0.15))


func _draw_hud() -> void:
	draw_rect(HUD_LEVELS, Color(C_PANEL_HI if hit(HUD_LEVELS) else Color(0.15, 0.17, 0.23, 0.9), ui_alpha))
	text("☰ Levels", HUD_LEVELS.get_center().x, HUD_LEVELS.position.y + 20, 13, Color("#c6cde8"), "c", true)
	text("%d/%d  %s" % [li + 1, level_total(), sim.L.name], 126, 39, 15, Color("#c6cde8"), "l", true)
	text(data.difficulties[diff].label.to_upper(), 126, 58, 12, DIFF_COLOR[diff], "l", true)
	if one_life():
		text("run %s   best run %s" % [fmt(god.total + (0 if sim.done else sim.t)), fmt(best["god:run"]) if best.has("god:run") else "—"], W - 34, 39, 15, Color("#c6cde8"), "r", true)
		text("shots %d   fewest run %s" % [god.shots + (0 if sim.done else sim.shots), str(best["god:shots"]) if best.has("god:shots") else "—"], W - 34, 58, 13, C_SHOT, "r", true)
	else:
		text("%s   best %s   deaths %d" % [fmt(sim.t), fmt(best[key(li)]) if best.has(key(li)) else "—", deaths], W - 34, 39, 15, Color("#c6cde8"), "r", true)
		var pr = par(li)
		var over: bool = pr != null and sim.shots > pr
		text("shots %d   par %s   fewest %s" % [sim.shots, str(pr) if pr != null else "—", str(best[skey(li)]) if best.has(skey(li)) else "—"], W - 34, 58, 13, C_RED if over else C_SHOT, "r", true)
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
	if not sim.started and view == "play":
		var tip: String = sim.L.tip
		if li == 0:
			tip = "Click where you want to fly. The blast fires the opposite way." if aim_mode == "go" else "Click BELOW you to launch up. You fly away from where you fire."
		text(tip, W / 2, 80, 15, C_SUB)
		var controls := "stick = aim · A / RT = fire · Y restart · Start levels" if using_pad else \
			"click / tap / space = fire  ·  aim: %s (M)  ·  T neon colour  ·  R restart  ·  N / B  ·  L levels" % ("where you go" if aim_mode == "go" else "where you fire")
		text(controls, W / 2, 102, 13, C_DIM)


func _draw_done() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.78))
	if one_life():
		if god.finished:
			text("GOD MODE CLEARED", W / 2, 200, 22, C_ORB, "c", true)
			text(fmt(god.total), W / 2, 260, 48, C_GOAL if new_best else C_TEXT, "c", true)
			var line := ("New best run time!" if new_best else "Best run %s" % fmt(best["god:run"])) + \
				"   ·   %d shots" % god.shots + (" (new fewest!)" if new_fewest else "  (fewest %s)" % str(best["god:shots"]))
			text(line, W / 2, 295, 17, C_SUB)
			button("Run again (R)", BTN_RETRY); button("Levels (L)", BTN_LEVELS)
		else:
			text("%d / %d cleared" % [li + 1, level_total()], W / 2, 250, 40, C_TEXT, "c", true)
			text("run time %s  ·  %d shots  ·  click to continue" % [fmt(god.total), god.shots], W / 2, 290, 17, C_SUB)
		return
	var pr = par(li)
	var sh := sim.shots
	text(fmt(sim.t), W / 2 - 110, 235, 44, C_GOAL if new_best else C_TEXT, "c", true)
	text("%d shot%s" % [sh, "" if sh == 1 else "s"], W / 2 + 110, 235, 44, C_GOAL if new_fewest else C_SHOT, "c", true)
	text("NEW BEST TIME" if new_best else "best %s" % fmt(best[key(li)]), W / 2 - 110, 262, 13, C_SUB, "c", true)
	text("NEW FEWEST SHOTS" if new_fewest else "fewest %s  ·  par %s" % [str(best[skey(li)]), str(pr) if pr != null else "—"], W / 2 + 110, 262, 13, C_SUB, "c", true)
	if pr != null and sh <= pr:
		text("★ " + ("UNDER PAR — you beat the bot" if sh < pr else "PAR"), W / 2, 300, 16, C_ORB, "c", true)
	button("Retry (R)", BTN_RETRY); button("Levels (L)", BTN_LEVELS); button("Next (N)", BTN_NEXT)


func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.08, 0.92))
	text("Levels", W / 2, 60, 28, C_TEXT, "c", true)
	draw_rect(NEON_BOX, C_PANEL_HI if hit(NEON_BOX) else C_PANEL)
	text("Neon: by %s ⇄" % neon_mode, NEON_BOX.get_center().x, NEON_BOX.position.y + 20, 13, neon(), "c", true)
	draw_rect(AIM_BOX, C_PANEL_HI if hit(AIM_BOX) else C_PANEL)
	text("Aim: %s ⇄" % ("where you go" if aim_mode == "go" else "where you fire"), AIM_BOX.get_center().x, AIM_BOX.position.y + 20, 13, C_SHOT, "c", true)
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
		"god": "Master rules · ONE LIFE for all 24 levels · die and restart from 1   (best run %s, fewest shots %s)" % [
			fmt(best["god:run"]) if best.has("god:run") else "—", str(best["god:shots"]) if best.has("god:shots") else "—"],
	}
	text(blurbs[diff], W / 2, 140, 13, C_SUB)
	if one_life():
		text("Click any level to start a God run from level 1", W / 2, 160, 13, C_ORB, "c", true)
	for i in level_total():
		var b := menu_box(i)
		var selected := using_pad and i == menu_sel
		draw_rect(b, C_PANEL_HI if hit(b) or selected else C_PANEL)
		if selected: draw_rect(b, C_TEXT, false, 2.0)
		draw_rect(Rect2(b.position, Vector2(b.size.x, 3)), Color(GROUP_COLOR[i]))
		text("%d. %s" % [i + 1, data.levels[i].name], b.get_center().x, b.position.y + 28, 14, C_TEXT, "c", true)
		var bt = best.get(key(i), null)
		var bs = best.get(skey(i), null)
		var pr = par(i)
		var line := "%s · %d shot%s" % [fmt(bt), int(bs), "" if int(bs) == 1 else "s"] if bt != null and bs != null else "not cleared"
		text(line, b.get_center().x, b.position.y + 47, 12, C_GOAL if bt != null else C_DIM)
		var mark := ""
		if bs != null and pr != null:
			mark = " ★" if bs < pr else (" ✓" if bs == pr else "")
		text("par %s%s" % [str(pr) if pr != null else "—", mark], b.get_center().x, b.position.y + 61, 11, C_ORB if mark != "" else C_DIM)
	var legend := "LB / RB difficulty · D-pad pick · A play" if using_pad else \
		"white basics · red swing · purple phase · orange teleport · blue gravity · pink moving spikes · green combos"
	text(legend, W / 2, 514, 13, C_DIM)
