extends RefCounted
## Level-complete celebration. Five tiers, each bigger than the last:
##   1  cleared a level            green ring + sparks
##   2  new personal best          rings, sparks, "NEW BEST" banner, rising notes
##   3  beat the bot (under par)   gold: stars, confetti, flash, banner, short fanfare
##   4  top 10 on the leaderboard  confetti rain, three fireworks, bigger banner, long fanfare
##   5  #1 on the leaderboard      non-stop fireworks and gold confetti, crown, "#1", bass drop
## game.gd decides the tier (see Game.celebration_tier) and calls start(); this class only animates.
## Everything here is cosmetic: it never touches the simulation.

const W := 960.0
const H := 540.0
const GREEN := Color("#2ed573")
const CYAN := Color("#7df9ff")
const GOLD := Color("#ffd447")
const PINK := Color("#ff3df2")
const ORANGE := Color("#ffb347")
const PURPLE := Color("#b388ff")
const WHITE := Color("#ffffff")
const INK := Color("#0b0d14")

var tier := 0
var t := 0.0
var origin := Vector2.ZERO
var title := ""
var subtitle := ""
var parts: Array = []
var rings: Array = []
var events: Array = []
var cues: Array = []
var flash := 0.0
var game                      # for sound and screen shake
var font: Font


func start(p_game, p_tier: int, p_origin: Vector2, p_title: String, p_subtitle: String) -> void:
	game = p_game
	font = game.font_bold
	tier = p_tier
	origin = p_origin
	title = p_title
	subtitle = p_subtitle
	match tier:
		1: _tier1()
		2: _tier2()
		3: _tier3()
		4: _tier4()
		_: _tier5()
	events.sort_custom(func(a, b): return a.at < b.at)
	cues.sort_custom(func(a, b): return a.at < b.at)


# ---------------------------------------------------------------- the five tiers

func _tier1() -> void:
	events.append({"at": 0.0, "k": "ring", "p": origin, "c": GREEN, "r": 70.0, "d": 0.6})
	events.append({"at": 0.0, "k": "burst", "p": origin, "n": 24, "cols": [GREEN, WHITE], "sp": 190.0})


func _tier2() -> void:
	events.append({"at": 0.0, "k": "ring", "p": origin, "c": CYAN, "r": 110.0, "d": 0.7})
	events.append({"at": 0.12, "k": "ring", "p": origin, "c": GREEN, "r": 150.0, "d": 0.8})
	events.append({"at": 0.0, "k": "burst", "p": origin, "n": 52, "cols": [GREEN, CYAN, WHITE], "sp": 260.0})
	events.append({"at": 0.0, "k": "shake", "v": 4.0})
	_notes([[0.0, 523.0, 0.12], [0.09, 659.0, 0.12], [0.18, 784.0, 0.3]], "triangle", 0.07)
	cues.append({"at": 0.32, "f": 1568.0, "d": 0.2, "w": "sine", "v": 0.03, "s": 0.0})


func _tier3() -> void:
	events.append({"at": 0.0, "k": "flash", "v": 0.35})
	for i in 3:
		events.append({"at": i * 0.1, "k": "ring", "p": origin, "c": GOLD, "r": 120.0 + i * 55.0, "d": 0.8 + i * 0.1})
	events.append({"at": 0.0, "k": "burst", "p": origin, "n": 90, "cols": [GOLD, ORANGE, WHITE], "sp": 320.0})
	events.append({"at": 0.05, "k": "stars", "p": origin, "n": 14})
	events.append({"at": 0.1, "k": "confetti_up", "p": origin, "n": 60, "cols": [GOLD, ORANGE, CYAN, PINK]})
	events.append({"at": 0.0, "k": "shake", "v": 7.0})
	_notes([[0.0, 523.0, 0.1], [0.08, 659.0, 0.1], [0.16, 784.0, 0.1], [0.24, 1047.0, 0.45]], "triangle", 0.08)
	cues.append({"at": 0.24, "f": 262.0, "d": 0.5, "w": "sawtooth", "v": 0.03, "s": 0.0})
	cues.append({"at": 0.4, "f": 2093.0, "d": 0.25, "w": "sine", "v": 0.03, "s": 0.0})


func _tier4() -> void:
	events.append({"at": 0.0, "k": "flash", "v": 0.5})
	events.append({"at": 0.0, "k": "ring", "p": origin, "c": CYAN, "r": 200.0, "d": 1.0})
	events.append({"at": 0.0, "k": "shake", "v": 8.0})
	events.append({"at": 0.0, "k": "rain", "until": 3.2, "rate": 55.0, "cols": [CYAN, PINK, GOLD, GREEN, PURPLE]})
	var spots := [Vector2(250, 190), Vector2(710, 170), Vector2(480, 120)]
	var cols := [CYAN, PINK, GOLD]
	for i in 3:
		events.append({"at": 0.1 + i * 0.45, "k": "firework", "p": spots[i], "c": cols[i]})
	_notes([[0.0, 523.0, 0.09], [0.07, 659.0, 0.09], [0.14, 784.0, 0.09], [0.21, 1047.0, 0.09], [0.28, 1319.0, 0.09], [0.35, 1568.0, 0.2]], "triangle", 0.08)
	_chord(0.5, [523.0, 659.0, 784.0], 1.0, 0.05)


func _tier5() -> void:
	events.append({"at": 0.0, "k": "flash", "v": 0.85})
	events.append({"at": 0.0, "k": "shake", "v": 12.0})
	events.append({"at": 0.0, "k": "ring", "p": origin, "c": GOLD, "r": 260.0, "d": 1.2})
	events.append({"at": 0.15, "k": "ring", "p": origin, "c": WHITE, "r": 340.0, "d": 1.3})
	events.append({"at": 0.0, "k": "rain", "until": 5.5, "rate": 75.0, "cols": [GOLD, GOLD, ORANGE, WHITE]})
	var cols := [GOLD, WHITE, ORANGE, CYAN, PINK]
	for i in 12:
		events.append({"at": 0.1 + i * 0.4, "k": "firework", "p": Vector2(120.0 + fmod(i * 197.0, 720.0), 90.0 + fmod(i * 83.0, 150.0)), "c": cols[i % cols.size()]})
	events.append({"at": 0.5, "k": "flash", "v": 0.4})
	events.append({"at": 1.4, "k": "shake", "v": 6.0})
	cues.append({"at": 0.0, "f": 110.0, "d": 0.7, "w": "sine", "v": 0.12, "s": 40.0})
	_notes([[0.35, 523.0, 0.09], [0.42, 659.0, 0.09], [0.49, 784.0, 0.09], [0.56, 1047.0, 0.09], [0.63, 1319.0, 0.09], [0.70, 1568.0, 0.2]], "triangle", 0.09)
	_chord(0.85, [523.0, 659.0, 784.0, 1047.0], 1.2, 0.05)
	_notes([[1.6, 784.0, 0.09], [1.67, 1047.0, 0.09], [1.74, 1319.0, 0.09], [1.81, 1568.0, 0.09], [1.88, 2093.0, 0.4]], "triangle", 0.07)


func _notes(list: Array, wave: String, vol: float) -> void:
	for n in list:
		cues.append({"at": n[0], "f": n[1], "d": n[2], "w": wave, "v": vol, "s": 0.0})


func _chord(at: float, freqs: Array, dur: float, vol: float) -> void:
	for f in freqs:
		cues.append({"at": at, "f": f, "d": dur, "w": "triangle", "v": vol, "s": 0.0})


# ---------------------------------------------------------------- update (called at 60 Hz)

func update(dt: float) -> void:
	t += dt
	while not events.is_empty() and events[0].at <= t:
		_run(events.pop_front())
	while not cues.is_empty() and cues[0].at <= t:
		var c: Dictionary = cues.pop_front()
		game.sfx.beep(c.f, c.d, c.w, c.v, c.s)
	for e in rains:
		if t < e.until:
			e.acc += e.rate * dt
			while e.acc >= 1.0:
				e.acc -= 1.0
				_confetti(Vector2(randf_range(-20.0, W + 20.0), randf_range(-40.0, -5.0)), Vector2(randf_range(-30.0, 30.0), randf_range(60.0, 150.0)), e.cols)
	for q in parts:
		q.life -= dt
		q.v.y += q.g * dt
		q.v *= pow(q.drag, dt * 60.0)
		q.p += q.v * dt
		q.rot += q.spin * dt
		if q.kind == "conf":
			q.p.x += sin(t * 4.0 + q.ph) * 24.0 * dt
	parts = parts.filter(func(q): return q.life > 0.0 and q.p.y < H + 40.0)
	for r in rings:
		r.life -= dt
	rings = rings.filter(func(r): return r.life > 0.0)
	flash = maxf(0.0, flash - dt * 1.6)


var rains: Array = []


func _run(e: Dictionary) -> void:
	match e.k:
		"ring":
			rings.append({"p": e.p, "c": e.c, "r": e.r, "d": e.d, "life": e.d})
		"burst":
			for i in e.n:
				var a := randf() * TAU
				var s: float = randf_range(0.35, 1.0) * float(e.sp)
				parts.append(_part("spark", e.p, Vector2(cos(a), sin(a)) * s, randf_range(0.5, 1.1), e.cols[randi() % e.cols.size()], randf_range(1.6, 3.2), 140.0, 0.93))
		"stars":
			for i in e.n:
				var a := randf() * TAU
				parts.append(_part("star", e.p, Vector2(cos(a), sin(a)) * randf_range(120.0, 330.0), randf_range(0.9, 1.6), GOLD if i % 3 else WHITE, randf_range(6.0, 11.0), 60.0, 0.96))
		"confetti_up":
			for i in e.n:
				_confetti(e.p, Vector2(randf_range(-190.0, 190.0), randf_range(-420.0, -160.0)), e.cols)
		"rain":
			rains.append({"until": e.until, "rate": e.rate, "cols": e.cols, "acc": 0.0})
		"firework":
			rings.append({"p": e.p, "c": e.c, "r": 70.0, "d": 0.5, "life": 0.5})
			for i in 46:
				var a := TAU * i / 46.0 + randf() * 0.1
				var s := randf_range(150.0, 230.0)
				parts.append(_part("spark", e.p, Vector2(cos(a), sin(a)) * s, randf_range(0.9, 1.5), e.c if i % 4 else WHITE, randf_range(1.8, 3.0), 90.0, 0.95))
			game.sfx.beep(randf_range(700.0, 1000.0), 0.12, "square", 0.03, 200.0)
		"flash":
			flash = maxf(flash, e.v)
		"shake":
			game.shake = maxf(game.shake, e.v)


func _part(kind: String, p: Vector2, v: Vector2, life: float, c: Color, size: float, g: float, drag: float) -> Dictionary:
	return {"kind": kind, "p": p, "v": v, "life": life, "max": life, "c": c, "size": size, "g": g, "drag": drag,
		"rot": randf() * TAU, "spin": randf_range(-8.0, 8.0), "ph": randf() * TAU}


func _confetti(p: Vector2, v: Vector2, cols: Array) -> void:
	parts.append(_part("conf", p, v, randf_range(3.0, 5.0), cols[randi() % cols.size()], randf_range(3.0, 6.0), 190.0, 0.985))


# ---------------------------------------------------------------- drawing

func draw(c: CanvasItem) -> void:
	for r in rings:
		var k: float = 1.0 - r.life / r.d
		var e: float = 1.0 - pow(1.0 - k, 3.0)
		c.draw_arc(r.p, r.r * e, 0.0, TAU, 56, Color(r.c, (1.0 - k) * 0.9), 4.0 * (1.0 - k) + 1.0, true)
	for q in parts:
		var a: float = clampf(q.life / q.max * 1.6, 0.0, 1.0)
		match q.kind:
			"spark":
				c.draw_line(q.p, q.p - q.v * 0.035, Color(q.c, a * 0.6), q.size * 0.9)
				c.draw_circle(q.p, q.size, Color(q.c, a))
			"star":
				c.draw_colored_polygon(_star(q.p, q.size * (0.6 + 0.4 * a), q.rot), Color(q.c, a))
			_:
				var sx: float = absf(cos(q.rot * 0.7 + q.ph))   # tumbling: width flips as it turns
				var w: float = q.size * (0.25 + 0.75 * sx)
				var h: float = q.size * 1.7
				var d := Vector2(cos(q.rot), sin(q.rot))
				var n := Vector2(-d.y, d.x)
				c.draw_colored_polygon(PackedVector2Array([q.p + d * h - n * w, q.p + d * h + n * w, q.p - d * h + n * w, q.p - d * h - n * w]), Color(q.c, minf(1.0, a * 1.4)))
	if flash > 0.01:
		c.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, flash * 0.55))
	if tier >= 2 and t > 0.2:
		_draw_banner(c)


## Banner: pops in with an overshoot, with the crown above it for #1.
func _draw_banner(c: CanvasItem) -> void:
	var k := clampf((t - 0.2) / 0.35, 0.0, 1.0)
	var s: float = 1.0 + 2.2 * pow(k - 1.0, 3.0) + 1.2 * pow(k - 1.0, 2.0)   # ease-out-back
	var size: int = [0, 0, 38, 46, 54, 78][tier]
	var cy: float = [0.0, 0.0, 130.0, 130.0, 128.0, 142.0][tier]
	var col: Color = [WHITE, WHITE, CYAN, GOLD, WHITE, GOLD][tier]
	if tier == 4: col = Color.from_hsv(fmod(t * 0.35, 1.0), 0.35, 1.0)
	c.draw_set_transform(Vector2(W / 2, cy), 0.0, Vector2(s, s))
	if tier == 5:
		_draw_crown(c, Vector2(0, -size - 6.0))
	for g in [[10.0, 0.10], [6.0, 0.18]]:
		c.draw_string_outline(font, Vector2(-480, size * 0.35), title, HORIZONTAL_ALIGNMENT_CENTER, 960, size, int(g[0] * size / 40.0) + 2, Color(col, g[1]))
	c.draw_string_outline(font, Vector2(-480, size * 0.35), title, HORIZONTAL_ALIGNMENT_CENTER, 960, size, 6, Color(INK, 0.85))
	c.draw_string(font, Vector2(-480, size * 0.35), title, HORIZONTAL_ALIGNMENT_CENTER, 960, size, col)
	if subtitle != "":
		c.draw_string_outline(font, Vector2(-480, size * 0.35 + 24.0), subtitle, HORIZONTAL_ALIGNMENT_CENTER, 960, 16, 4, Color(INK, 0.85))
		c.draw_string(font, Vector2(-480, size * 0.35 + 24.0), subtitle, HORIZONTAL_ALIGNMENT_CENTER, 960, 16, Color("#e8ecff"))
	c.draw_set_transform(Vector2.ZERO)


func _draw_crown(c: CanvasItem, at: Vector2) -> void:
	var pts := PackedVector2Array([at + Vector2(-34, 20), at + Vector2(-34, -6), at + Vector2(-17, 8), at + Vector2(0, -22),
		at + Vector2(17, 8), at + Vector2(34, -6), at + Vector2(34, 20)])
	var shimmer := 0.75 + 0.25 * sin(t * 6.0)
	c.draw_colored_polygon(pts, Color(GOLD, 0.25 * shimmer))
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(GOLD, 0.35), 8.0, true)
	c.draw_colored_polygon(pts, GOLD)
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#fff3b0"), 2.0, true)
	for jewel in [Vector2(-34, -6), Vector2(0, -22), Vector2(34, -6)]:
		c.draw_circle(at + jewel, 4.5, Color("#fff3b0"))


static func _star(p: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot + PI * i / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	return pts
