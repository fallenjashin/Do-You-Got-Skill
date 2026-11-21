extends Node2D
## Start screen and main menu.
##   "title"       starry sky + slanted neon sign + "press any key"
##   "main"        the sign glides left, the menu slides in on the right, and the neon ball
##                 pops in as a character that hops between menu items
##   "leaderboard" placeholder screen (online leaderboards come with Steam)
## Draws on top of the game; the game itself is paused while any of these are showing.

const W := 960.0
const H := 540.0
const TRANSITION := 0.9   # seconds for the sign to glide over
const HOP := 0.28         # seconds for the ball to hop between items
const C_MAGENTA := Color("#ff3df2")
const C_CYAN := Color("#22e6ff")
const C_VIOLET := Color("#9d6bff")
const C_TEXT := Color("#e8ecff")
const C_SUB := Color("#8b93b5")
const C_DIM := Color("#5d6585")
const C_SHOT := Color("#ffb347")
const MENU_X := 600.0
const MENU_Y := 118.0
const ROW := 36.0

var game                      # scripts/game.gd
var time := 0.0
var trans := 0.0              # 0 = sign centred, 1 = sign on the left with the menu showing
var sel := 0
var ball := Vector2(-100, -100)
var ball_from := Vector2.ZERO
var ball_to := Vector2.ZERO
var hop := 1.0                # 0..1 progress of the current hop
var pop := 0.0                # 0..1 ball "appear" animation
var lb_level := 0
var stars: Array = []
var parts: Array = []
var still := false          # no flicker/hum (used when exporting the sign as an image)
var sign_only := false      # draw just the sign, no sky (transparent image export)
var dragging := false       # dragging the music volume bar


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 190:
		var depth := rng.randf_range(0.2, 1.0)
		stars.append({"p": Vector2(rng.randf_range(0, W + 80), rng.randf_range(0, H)), "r": 0.5 + depth * 1.3 * rng.randf(),
			"tw": rng.randf_range(0.6, 2.4), "ph": rng.randf() * TAU, "d": depth,
			"c": [Color("#ffffff"), Color("#c9d6ff"), Color("#ffd9f5"), Color("#d6fff9")][rng.randi() % 4]})


func showing() -> bool:
	return game != null and game.view in ["title", "main", "leaderboard"]


# ---------------------------------------------------------------- menu model

func items() -> Array:
	var d: Dictionary = game.data.difficulties[game.diff]
	var list := [
		{"id": "play", "label": "Play", "value": "%s  %s" % [game.level_code(game.last_level), game.data.levels[game.last_level].name] if game.diff != "god" else "God run", "c": C_CYAN},
		{"id": "select", "label": "Select Level", "value": "", "c": C_CYAN},
		{"id": "fullrun", "label": "Full Run", "value": "God run" if game.diff == "god" else (game.fmt_run(game.best["run:" + game.diff]) if game.best.has("run:" + game.diff) else "all 60"), "c": C_CYAN},
		{"id": "difficulty", "label": "Difficulty", "value": d.label, "opt": true, "c": game.DIFF_COLOR[game.diff]},
		{"id": "leaderboard", "label": "Leaderboard", "value": "soon", "c": C_VIOLET},
		{"id": "music", "label": "Music", "value": "muted" if game.music_volume <= 0.0 else "%d%%" % roundi(game.music_volume * 100), "opt": true, "c": C_MAGENTA, "slider": true},
		{"id": "neon", "label": "Neon", "value": "by " + game.neon_mode, "opt": true, "c": C_MAGENTA},
		{"id": "stats", "label": "Career Stats", "value": "", "c": C_VIOLET},
		{"id": "credits", "label": "Credits", "value": "", "c": C_VIOLET},
	]
	if not OS.has_feature("web"):
		list.append({"id": "quit", "label": "Quit", "value": "", "c": C_DIM})
	return list


func item_rect(i: int) -> Rect2:
	return Rect2(MENU_X, MENU_Y + i * ROW, 320, 34)


## The volume bar inside the Music row (click or drag to set; ←/→ = 1%, Shift = 10%).
func slider_rect(i: int) -> Rect2:
	var r := item_rect(i)
	return Rect2(r.position.x + 118, r.position.y + 13, 120, 8)


func ball_spot(i: int) -> Vector2:
	return Vector2(MENU_X - 24, MENU_Y + i * ROW + 17)


func open_main(instant := false) -> void:
	game.view = "main"
	if instant:
		trans = 1.0
		pop = 1.0
		ball = ball_spot(sel)
		hop = 1.0


func set_sel(i: int) -> void:
	var n := items().size()
	i = posmod(i, n)
	if i == sel and hop >= 1.0:
		return
	sel = i
	ball_from = ball
	ball_to = ball_spot(sel)
	hop = 0.0
	# little recoil puff: the blast goes opposite to where the ball hops
	var away := (ball_from - ball_to).normalized()
	for k in 8:
		var a := away.angle() + randf_range(-0.6, 0.6)
		var s := randf_range(1.5, 4.0)
		parts.append({"p": ball_from + away * 10, "v": Vector2(cos(a), sin(a)) * s, "life": 1.0, "c": C_SHOT})


func activate(i: int, dir := 1) -> void:
	var it: Dictionary = items()[i]
	match it.id:
		"play":
			game.start_from_menu(game.last_level)
		"select":
			game.menu_sel = game.li
			game.view = "menu"
		"fullrun":
			game.start_run()
		"leaderboard":
			lb_level = game.last_level
			game.view = "leaderboard"
		"stats":
			game.credits_back = "main"
			game.view = "stats"
		"credits":
			game.credits_back = "main"
			game.view = "credits"
		"quit":
			get_tree().quit()
		"music":
			game.toggle_mute()
		_:
			change(i, dir)
			return
	game.sfx.beep(660, 0.08, "sine", 0.06)


func _index_of(id: String) -> int:
	var list := items()
	for i in list.size():
		if list[i].id == id: return i
	return -1


func _set_from_slider(x: float) -> void:
	var r := slider_rect(_index_of("music"))
	game.set_music_volume((x - r.position.x) / r.size.x)


func change(i: int, dir: int) -> void:
	var it: Dictionary = items()[i]
	if it.id != "music":
		dir = signi(dir)   # big steps only matter for the volume slider
	match it.id:
		"difficulty":
			var k: int = game.DIFFS.find(game.diff)
			game.set_diff(game.DIFFS[posmod(k + dir, game.DIFFS.size())])
			game.load_level(game.last_level)   # reload so the run uses the new rules
			game.view = "main"
		"music": game.adjust_music(dir)
		"neon": game.toggle_neon()
		_: return
	game.sfx.beep(520, 0.05, "triangle", 0.05)


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if not showing():
		return
	get_viewport().set_input_as_handled()
	if game.view == "title":
		var pressed: bool = (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed) \
			or (e is InputEventJoypadButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
		if pressed:
			open_main()
			game.sfx.beep(330, 0.25, "sine", 0.06, 990)
		return
	if game.view == "leaderboard":
		_leaderboard_input(e)
		return
	# main menu
	if trans < 1.0:
		return
	var music_i := _index_of("music")
	if e is InputEventMouseMotion:
		if dragging and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_set_from_slider(e.position.x)
			return
		dragging = false
		for i in items().size():
			if item_rect(i).grow(4).has_point(e.position):
				set_sel(i)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if not e.pressed:
			dragging = false
			return
		if music_i >= 0 and slider_rect(music_i).grow_individual(6, 10, 6, 10).has_point(e.position):
			set_sel(music_i)
			dragging = true
			_set_from_slider(e.position.x)
			return
		for i in items().size():
			if item_rect(i).grow(4).has_point(e.position):
				set_sel(i)
				activate(i, 1)
	elif e is InputEventKey and e.pressed:
		if e.echo and items()[sel].id != "music":
			return   # holding a key only repeats on the volume slider
		var step := 10 if e.shift_pressed else 1
		match e.keycode:
			KEY_UP, KEY_W: set_sel(sel - 1)
			KEY_DOWN, KEY_S: set_sel(sel + 1)
			KEY_LEFT, KEY_A: change(sel, -step)
			KEY_RIGHT, KEY_D: change(sel, step)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: activate(sel)
			KEY_ESCAPE: game.resume_play()
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_DPAD_UP: set_sel(sel - 1)
			JOY_BUTTON_DPAD_DOWN: set_sel(sel + 1)
			JOY_BUTTON_DPAD_LEFT: change(sel, -1)
			JOY_BUTTON_DPAD_RIGHT: change(sel, 1)
			JOY_BUTTON_LEFT_SHOULDER: change(sel, -10)
			JOY_BUTTON_RIGHT_SHOULDER: change(sel, 10)
			JOY_BUTTON_A: activate(sel)
			JOY_BUTTON_B: game.resume_play()


func _leaderboard_input(e: InputEvent) -> void:
	var n: int = game.level_total()
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_LEFT, KEY_A: lb_level = posmod(lb_level - 1, n)
			KEY_RIGHT, KEY_D: lb_level = posmod(lb_level + 1, n)
			KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_BACKSPACE: game.view = "main"
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_DPAD_LEFT: lb_level = posmod(lb_level - 1, n)
			JOY_BUTTON_DPAD_RIGHT: lb_level = posmod(lb_level + 1, n)
			JOY_BUTTON_A, JOY_BUTTON_B: game.view = "main"
	elif e is InputEventMouseButton and e.pressed:
		if Rect2(560, 120, 40, 40).has_point(e.position): lb_level = posmod(lb_level - 1, n)
		elif Rect2(890, 120, 40, 40).has_point(e.position): lb_level = posmod(lb_level + 1, n)
		else: game.view = "main"


# ---------------------------------------------------------------- animation

func _process(delta: float) -> void:
	visible = showing()
	if not visible:
		return
	if game.music.current != game.music.TITLE:
		game.music.play(game.music.TITLE)
	time += delta
	if game.view != "title" and trans < 1.0:
		trans = minf(1.0, trans + delta / TRANSITION)
		if trans > 0.75 and pop == 0.0:
			ball = ball_spot(sel)
			ball_to = ball
			_burst(ball, C_CYAN, 22)
			game.sfx.beep(880, 0.12, "sine", 0.06, 1320)
		if trans > 0.75:
			pop = minf(1.0, pop + delta / 0.35)
	elif game.view != "title" and pop < 1.0:
		pop = minf(1.0, pop + delta / 0.35)
	if hop < 1.0:
		hop = minf(1.0, hop + delta / HOP)
		var k := _ease(hop)
		ball = ball_from.lerp(ball_to, k) + Vector2(0, -sin(k * PI) * 18)
	for q in parts:
		q.p += q.v
		q.v *= 0.93
		q.life -= delta * 2.2
	parts = parts.filter(func(q): return q.life > 0)
	queue_redraw()


func _burst(p: Vector2, c: Color, n: int) -> void:
	for k in n:
		var a := randf() * TAU
		parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * randf_range(1, 5), "life": 1.0, "c": c})


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)   # ease-out cubic


static func _rand(n: float) -> float:
	return fposmod(sin(n * 12.9898) * 43758.5453, 1.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not showing():
		return
	var k := _ease(trans)
	if sign_only:
		draw_neon_sign(Vector2(480, 270), 1.15, time)
		return
	_draw_sky(k)
	var sign_pos := Vector2(480, 222).lerp(Vector2(292, 262), k)
	var sign_scale := lerpf(1.0, 0.8, k)
	draw_neon_sign(sign_pos, sign_scale, time)
	if game.view == "title":
		var a := 0.45 + 0.45 * sin(time * 3.0)
		_text("press any key", W / 2, 452, 18, Color(C_TEXT, a), true)
	elif game.view == "main":
		_draw_menu(k)
	elif game.view == "leaderboard":
		_draw_leaderboard()
	for q in parts:
		draw_rect(Rect2(q.p - Vector2(2, 2), Vector2(4, 4)), Color(q.c, q.life))
	if game.view == "main" and pop > 0.0:
		_draw_ball()


func _draw_sky(k: float) -> void:
	# deep blue-violet night, a little lighter near the horizon
	var top := Color("#04040c")
	var bottom := Color("#120a26")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([top, top, bottom, bottom]))
	for s in stars:
		var x: float = fposmod(s.p.x - k * 60.0 * s.d - time * 2.0 * s.d, W + 80) - 40   # slow drift + pan
		var a: float = (0.35 + 0.65 * (0.5 + 0.5 * sin(time * s.tw + s.ph))) * (0.4 + 0.6 * s.d)
		draw_circle(Vector2(x, s.p.y), s.r, Color(s.c, a))
		if s.r > 1.4:
			draw_circle(Vector2(x, s.p.y), s.r * 3.0, Color(s.c, a * 0.08))
	# an occasional shooting star
	var cyc := fposmod(time, 7.0)
	if cyc < 0.9:
		var seed := floorf(time / 7.0)
		var start := Vector2(200 + _rand(seed) * 600, 30 + _rand(seed + 1.0) * 120)
		var head := start + Vector2(260, 90) * (cyc / 0.9)
		var fade := 1.0 - cyc / 0.9
		draw_line(head - Vector2(70, 24), head, Color(1, 1, 1, 0.5 * fade), 1.5)
		draw_circle(head, 1.6, Color(1, 1, 1, fade))


## The sign: two lines of slanted neon text inside a neon tube frame, with glow and flicker.
## Also used to export the marketing image.
func draw_neon_sign(pos: Vector2, s: float, t: float) -> void:
	var slant := 0.2
	draw_set_transform_matrix(Transform2D(Vector2(s, 0), Vector2(-slant * s, s), pos))
	var f: Font = game.font_sign
	# flicker: "Do You Got" occasionally stutters like a failing tube; "Skill" hums steadily
	var n := floorf(t * 14.0)
	var flick1 := 0.18 if _rand(n) < 0.035 or (_rand(n - 1.0) < 0.035 and _rand(n + 7.0) < 0.5) else 1.0
	var hum := 0.93 + 0.07 * sin(t * 2.3)
	if still:
		flick1 = 1.0
		hum = 1.0
	# light spill: the sign tints the night around it
	for i in 6:
		var rr := 330.0 - i * 40.0
		draw_circle(Vector2(-40, 0), rr, Color(C_MAGENTA, 0.012 * hum))
		draw_circle(Vector2(60, 40), rr * 0.8, Color(C_CYAN, 0.012 * hum))
	# frame
	_neon_round_rect(Rect2(-268, -120, 536, 244), 34.0, C_VIOLET, 0.85 * hum)
	_neon_text(f, "Do You Got", Vector2(0, -28), 66, C_MAGENTA, flick1 * hum)
	_neon_text(f, "Skill", Vector2(0, 82), 128, C_CYAN, hum)
	# little mounting brackets, like a real sign
	for x in [-180.0, 180.0]:
		draw_line(Vector2(x, -120), Vector2(x, -150), Color("#2a2f44"), 3.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _neon_text(f: Font, s: String, center: Vector2, size: int, c: Color, a: float) -> void:
	var p := Vector2(center.x - 500, center.y)
	for layer in [[46, 0.07], [30, 0.13], [18, 0.26], [9, 0.55]]:
		draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_CENTER, 1000, size, layer[0], Color(c, layer[1] * a))
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_CENTER, 1000, size, 3, Color(c, 0.95 * a))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_CENTER, 1000, size, Color(c.lightened(0.62), lerpf(0.35, 1.0, a)))


func _neon_round_rect(r: Rect2, rad: float, c: Color, a: float) -> void:
	var pts := PackedVector2Array()
	var corners := [[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI / 2],
		[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5]]
	for cr in corners:
		for i in 9:
			var ang: float = cr[1] + PI / 2 * i / 8.0
			pts.append(cr[0] + Vector2(cos(ang), sin(ang)) * rad)
	pts.append(pts[0])
	for layer in [[22.0, 0.07], [13.0, 0.15], [6.0, 0.45]]:
		draw_polyline(pts, Color(c, layer[1] * a), layer[0], true)
	draw_polyline(pts, Color(c.lightened(0.6), 0.9 * a), 2.0, true)


func _draw_menu(k: float) -> void:
	var list := items()
	var slide := (1.0 - k) * 90.0
	for i in list.size():
		var it: Dictionary = list[i]
		var r := item_rect(i)
		r.position.x += slide + (1.0 - k) * i * 12.0
		var a := clampf(k * 1.6 - i * 0.06, 0.0, 1.0)
		var on := i == sel
		var c: Color = it.c
		if on:
			draw_rect(r, Color(c, 0.10 * a))
			for layer in [[8.0, 0.08], [4.0, 0.2]]:
				draw_rect(r, Color(c, layer[1] * a), false, layer[0])
			draw_rect(r, Color(c.lightened(0.5), 0.9 * a), false, 1.5)
		var y := r.position.y + 23
		_text_l(it.label, r.position.x + 14, y, 18, Color(C_TEXT if on else C_SUB, a), on)
		if it.get("slider", false):
			var sr := slider_rect(i)
			sr.position.x = r.position.x + 118
			var v: float = game.music_volume
			draw_rect(sr, Color(C_DIM, 0.35 * a))
			draw_rect(Rect2(sr.position, Vector2(sr.size.x * v, sr.size.y)), Color(c, (0.9 if on else 0.5) * a))
			var knob := Vector2(sr.position.x + sr.size.x * v, sr.get_center().y)
			if on:
				draw_circle(knob, 9.0, Color(c, 0.18 * a))
			draw_circle(knob, 5.5, Color(C_TEXT if on else C_SUB, a))
			_text_r(("‹ %s ›" % it.value) if on else it.value, r.end.x - 12, y, 14, Color(c if on else C_DIM, a), on)
		elif it.value != "":
			var v: String = ("‹ %s ›" % it.value) if it.get("opt", false) and on else it.value
			_text_r(v, r.end.x - 12, y, 14, Color(c if on else C_DIM, a), on)
	var hint := "↑ ↓ choose   ← → change (shift ×10)   enter select   esc back to game"
	_text(hint, MENU_X + 160, MENU_Y + list.size() * ROW + 26, 11, Color(C_DIM, k))


func _draw_ball() -> void:
	var s := _ease(pop) * (1.0 + 0.25 * sin(pop * PI))   # overshoot pop-in
	var bob := Vector2(0, sin(time * 3.0) * 2.5) if hop >= 1.0 else Vector2.ZERO
	var p := ball + bob
	var r := 13.0 * s
	for layer in [[r + 14, 0.05], [r + 8, 0.10], [r + 3, 0.25]]:
		draw_circle(p, layer[0], Color("#7aa2ff", layer[1]))
	draw_circle(p, r, C_TEXT)
	# eyes look toward the menu text (or the mouse, when it's nearby)
	var look := (get_viewport().get_mouse_position() - p)
	look = look.normalized() if look.length() < 260 and look.length() > 1 else Vector2(1, 0)
	var blink := fposmod(time, 3.7) < 0.12
	for side in [-1.0, 1.0]:
		var e := p + Vector2(side * 4.2 * s, -2.0 * s) + look * 2.2 * s
		if blink:
			draw_line(e - Vector2(2.2 * s, 0), e + Vector2(2.2 * s, 0), Color("#1a1f33"), 1.6)
		else:
			draw_circle(e, 2.1 * s, Color("#1a1f33"))
	# shot pips, like in-game
	for i in 2:
		draw_circle(p + Vector2(-5 + i * 10, -r - 9), 3.0 * s, C_SHOT)


func _draw_leaderboard() -> void:
	var x0 := 560.0
	draw_rect(Rect2(x0, 70, 370, 420), Color(0.04, 0.05, 0.1, 0.85))
	draw_rect(Rect2(x0, 70, 370, 420), Color(C_VIOLET, 0.5), false, 1.5)
	_text("LEADERBOARD", x0 + 185, 104, 22, C_TEXT, true)
	var L: Dictionary = game.data.levels[lb_level]
	_text("‹", x0 + 20, 148, 26, C_SUB, true)
	_text("›", x0 + 350, 148, 26, C_SUB, true)
	_text("%s  %s" % [game.level_code(lb_level), L.name], x0 + 185, 146, 17, game.world_color(lb_level), true)
	_text(game.data.difficulties[game.diff].label.to_upper(), x0 + 185, 166, 11, game.DIFF_COLOR[game.diff], true)
	var cols := [x0 + 24, x0 + 62, x0 + 228, x0 + 300]
	for h in [["#", 0], ["PLAYER", 1], ["TIME", 2], ["SHOTS", 3]]:
		_text_l(h[0], cols[h[1]], 196, 11, C_DIM, true)
	var bt = game.best.get(game.diff + ":" + str(lb_level), null)
	var bs = game.best.get("s:" + game.diff + ":" + str(lb_level), null)
	for i in 8:
		var y := 222 + i * 26
		if i == 0 and bt != null:
			draw_rect(Rect2(x0 + 16, y - 17, 338, 24), Color(C_CYAN, 0.10))
			_text_l("—", cols[0], y, 13, C_CYAN)
			_text_l("You (this device)", cols[1], y, 13, C_CYAN, true)
			_text_l(game.fmt(bt), cols[2], y, 13, C_CYAN)
			_text_l(str(bs), cols[3], y, 13, C_CYAN)
		else:
			_text_l(str(i + 1), cols[0], y, 13, C_DIM)
			_text_l("· · ·", cols[1], y, 13, Color(C_DIM, 0.6))
			_text_l("—", cols[2], y, 13, Color(C_DIM, 0.6))
			_text_l("—", cols[3], y, 13, Color(C_DIM, 0.6))
	_text("Online rankings for time and fewest shots,", x0 + 185, 440, 12, C_SUB)
	_text("with ghosts of the top runs, arrive with the Steam release.", x0 + 185, 458, 12, C_SUB)
	_text("← → level   ·   esc back", x0 + 185, 480, 11, C_DIM)


func _text(s: String, x: float, y: float, size: int, c: Color, bold := false) -> void:
	draw_string(game.font_bold if bold else game.font, Vector2(x - 480, y), s, HORIZONTAL_ALIGNMENT_CENTER, 960, size, c)


func _text_l(s: String, x: float, y: float, size: int, c: Color, bold := false) -> void:
	draw_string(game.font_bold if bold else game.font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _text_r(s: String, x: float, y: float, size: int, c: Color, bold := false) -> void:
	draw_string(game.font_bold if bold else game.font, Vector2(x - 600, y), s, HORIZONTAL_ALIGNMENT_RIGHT, 600, size, c)
