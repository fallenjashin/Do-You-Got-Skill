class_name RecoilSim
extends RefCounted
## One attempt at one level: the game's rules and physics, with no drawing or input.
## Deterministic: the same inputs always give the same result, which is what makes
## ghosts, par and (later) replay-verified leaderboards possible.
## Keep this file in lockstep with the prototype; tests/test_parity.gd checks it.

const DATA_PATH := "res://data/levels.json"
const SUB := 4  # physics sub-steps per 60 Hz tick
const SHIP_CHARGE := 50.0
const SHIP_FIRE := 24.0
const SHIP_BODY := 13.0

static var data: Dictionary = {}

# --- run state ---
var level_index: int
var L: Dictionary          # level definition
var d: Dictionary          # difficulty settings
var diff: String
var ammo_max: int
var px: float
var py: float
var vx := 0.0
var vy := 0.0
var ammo: int
var grounded := false
var orbs: Array = []       # yellow refill orbs   {x, y, cd}
var reds: Array = []       # swing anchors        {x, y, cd}
var purs: Array = []       # phase toggles        {x, y, cd}
var gravs: Array = []      # gravity flips        {x, y, cd}
var tps: Array = []        # teleport pairs       {ax, ay, bx, by, cd}
var rope = null            # null or {o: Dictionary (a red orb), len: float}
var phased := false
var phase_cd := 0
var g := 1.0               # gravity direction: 1 down, -1 up
var grav_cd := 0
var last_tp: Array = []
var t := 0                 # ticks since the first shot
var shots := 0
var started := false
var done := false
var dead := false
var lock_warn := false
var plat := -1             # index of the elevator you're standing on
var knock_cd := 0
var death_by := ""
var ships: Array = []      # per gunship: {lock: null or {ox, oy, ex, ey}, firing: bool}
var events: Array[String] = []


static func load_data() -> Dictionary:
	if data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		data = JSON.parse_string(f.get_as_text())
	return data


static func level_count() -> int:
	return load_data().levels.size()


static func tune(key: String) -> float:
	return float(load_data().tuning[key])


static func len2(x: float, y: float) -> float:
	return sqrt(x * x + y * y)


func _init(index: int = 0, difficulty: String = "medium") -> void:
	load_data()
	level_index = index
	diff = difficulty
	L = data.levels[index]
	d = data.difficulties[difficulty]
	ammo_max = int(L.ammo) + int(d.ammo)
	ammo = ammo_max
	px = float(L.start[0])
	py = float(L.start[1])
	orbs = _pts(L.get("o", []))
	reds = _pts(L.get("red", []))
	purs = _pts(L.get("pur", []))
	gravs = _pts(L.get("grav", []))
	for sh in L.get("ship", []):
		ships.append({"lock": null, "firing": false})
	for tp in L.get("tp", []):
		tps.append({"ax": float(tp[0]), "ay": float(tp[1]), "bx": float(tp[2]), "by": float(tp[3]), "cd": 0.0})


static func _pts(arr: Array) -> Array:
	var out := []
	for a in arr:
		out.append({"x": float(a[0]), "y": float(a[1]), "cd": 0.0})
	return out


## Spike rect at time t. Moving spikes are [x, y, w, h, dx, dy, period, phase?].
static func spike_at(k: Array, time: float) -> Array:
	if k.size() < 7:
		return k
	var ph := float(k[7]) if k.size() > 7 else 0.0
	var o := sin(2.0 * PI * (time / float(k[6]) + ph))
	return [float(k[0]) + float(k[4]) * o, float(k[1]) + float(k[5]) * o, float(k[2]), float(k[3])]


## Moving solid (elevator / pusher): [x, y, w, h, dx, dy, period, knock, phase].
static func mv_at(m: Array, time: float) -> Array:
	var ph := float(m[8]) if m.size() > 8 else 0.0
	var o := sin(2.0 * PI * (time / float(m[6]) + ph))
	return [float(m[0]) + float(m[4]) * o, float(m[1]) + float(m[5]) * o, float(m[2]), float(m[3])]


## Gunship position: [x, y, dx, dy, period, every, offset].
static func ship_at(sh: Array, time: float) -> Vector2:
	if not (float(sh[4]) > 0.0):
		return Vector2(float(sh[0]), float(sh[1]))
	var o := sin(2.0 * PI * time / float(sh[4]))
	return Vector2(float(sh[0]) + float(sh[2]) * o, float(sh[1]) + float(sh[3]) * o)


## Timed laser [x1, y1, x2, y2, on, off, offset]: is it firing at time t?
static func laser_on(lz: Array, time: float) -> bool:
	return fmod(time + float(lz[6]), float(lz[4]) + float(lz[5])) < float(lz[4])


static func dist_seg(px_: float, py_: float, x1: float, y1: float, x2: float, y2: float) -> float:
	var vx_ := x2 - x1
	var vy_ := y2 - y1
	var wx := px_ - x1
	var wy := py_ - y1
	var l2 := vx_ * vx_ + vy_ * vy_
	var u := (wx * vx_ + wy * vy_) / l2 if l2 > 0.0 else 0.0
	u = maxf(0.0, minf(1.0, u))
	return len2(px_ - (x1 + u * vx_), py_ - (y1 + u * vy_))


## Distance along a ray to a box (INF if missed or starting inside).
static func ray_rect(ox: float, oy: float, dx: float, dy: float, rect: Array) -> float:
	var x := float(rect[0]); var y := float(rect[1]); var w := float(rect[2]); var h := float(rect[3])
	var t0 := -INF
	var t1 := INF
	if dx != 0.0:
		var a := (x - ox) / dx
		var b := (x + w - ox) / dx
		if a > b:
			var c := a; a = b; b = c
		t0 = maxf(t0, a); t1 = minf(t1, b)
	elif ox < x or ox > x + w:
		return INF
	if dy != 0.0:
		var a := (y - oy) / dy
		var b := (y + h - oy) / dy
		if a > b:
			var c := a; a = b; b = c
		t0 = maxf(t0, a); t1 = minf(t1, b)
	elif oy < y or oy > y + h:
		return INF
	if t1 < t0 or t0 < 0.0:
		return INF
	return t0


static func overlap(cx: float, cy: float, r: float, rect: Array) -> bool:
	var x := float(rect[0]); var y := float(rect[1]); var w := float(rect[2]); var h := float(rect[3])
	var nx := maxf(x, minf(cx, x + w))
	var ny := maxf(y, minf(cy, y + h))
	return (cx - nx) * (cx - nx) + (cy - ny) * (cy - ny) < r * r


func _resolve(rect: Array) -> void:
	var R := tune("R")
	var x := float(rect[0]); var y := float(rect[1]); var w := float(rect[2]); var h := float(rect[3])
	var cx := maxf(x, minf(px, x + w))
	var cy := maxf(y, minf(py, y + h))
	var dx := px - cx
	var dy := py - cy
	var d2 := dx * dx + dy * dy
	if d2 >= R * R:
		return
	var nx: float; var ny: float; var push: float
	if d2 > 1e-6:
		var dist := sqrt(d2)
		nx = dx / dist; ny = dy / dist; push = R - dist
	else:  # centre inside the box: push out along the shortest axis
		var l := px - x; var r := x + w - px; var tt := py - y; var b := y + h - py
		var m := minf(minf(l, r), minf(tt, b))
		if m == l: nx = -1.0; ny = 0.0
		elif m == r: nx = 1.0; ny = 0.0
		elif m == tt: nx = 0.0; ny = -1.0
		else: nx = 0.0; ny = 1.0
		push = m + R
	px += nx * push
	py += ny * push
	var vn := vx * nx + vy * ny
	if vn < 0.0:
		var bounce := tune("BOUNCE")
		vx -= (1.0 + bounce) * vn * nx
		vy -= (1.0 + bounce) * vn * ny
	if ny * g < -0.7:
		grounded = true


## Collide with a moving solid: relative-velocity bounce, pusher knock, elevator tracking.
func _resolve_mv(rect: Array, wvx: float, wvy: float, knock: float, j: int) -> void:
	var R := tune("R")
	var x := float(rect[0]); var y := float(rect[1]); var w := float(rect[2]); var h := float(rect[3])
	var cx := maxf(x, minf(px, x + w))
	var cy := maxf(y, minf(py, y + h))
	var dx := px - cx
	var dy := py - cy
	var d2 := dx * dx + dy * dy
	if d2 >= R * R:
		return
	var nx: float; var ny: float; var push: float
	if d2 > 1e-6:
		var dist := sqrt(d2)
		nx = dx / dist; ny = dy / dist; push = R - dist
	else:
		var l := px - x; var r := x + w - px; var tt := py - y; var b := y + h - py
		var m := minf(minf(l, r), minf(tt, b))
		if m == l: nx = -1.0; ny = 0.0
		elif m == r: nx = 1.0; ny = 0.0
		elif m == tt: nx = 0.0; ny = -1.0
		else: nx = 0.0; ny = 1.0
		push = m + R
	px += nx * push
	py += ny * push
	var vn := (vx - wvx) * nx + (vy - wvy) * ny
	if vn < 0.0:
		var bounce := tune("BOUNCE")
		vx -= (1.0 + bounce) * vn * nx
		vy -= (1.0 + bounce) * vn * ny
	if knock > 0.0 and knock_cd == 0 and wvx * nx + wvy * ny > 0.3:
		vx += nx * knock
		vy += ny * knock
		knock_cd = 12
		events.append("knock")
	if ny * g < -0.7:
		grounded = true
		plat = j


func _die(by: String) -> String:
	dead = true
	death_by = by
	events.append("dead")
	return "dead"


## Fire a blast in direction (dx, dy). You get pushed the opposite way.
func fire(dx: float, dy: float) -> bool:
	if done or dead or ammo <= 0:
		return false
	var dist := len2(dx, dy)
	if dist == 0.0:
		dist = 1.0
	dx /= dist; dy /= dist
	# letting go of a swing keeps ALL your momentum; a normal shot damps it
	var keep := 1.0 if rope != null else tune("KEEP")
	if rope != null:
		rope.o.cd = 40.0
		rope = null
		events.append("detach")
	var imp := tune("IMPULSE")
	vx = vx * keep - dx * imp
	vy = vy * keep - dy * imp
	ammo -= 1
	shots += 1
	grounded = false
	started = true
	return true


## Advance one 60 Hz tick. Returns "", "dead" or "win".
func tick() -> String:
	if not started or done or dead:
		return ""
	var R := tune("R")
	var orb_r := float(d.orb)
	t += 1
	for list in [orbs, reds, purs, gravs, tps]:
		for o in list:
			if o.cd > 0.0:
				o.cd -= 1.0
	if phase_cd > 0: phase_cd -= 1
	if grav_cd > 0: grav_cd -= 1
	if knock_cd > 0: knock_cd -= 1
	var sp := float(d.spike)
	var tau := t * sp
	var mv: Array = L.get("mv", [])
	var kill_r := R - float(d.hit)

	# gunships: lock on at the start of each cycle, charge, then fire a wall-blocked beam
	for j in ships.size():
		var sh: Array = L.ship[j]
		var st: Dictionary = ships[j]
		var cyc := fmod(tau + float(sh[6]), float(sh[5]))
		if cyc < sp:
			var o := ship_at(sh, tau)
			var dx := px - o.x
			var dy := py - o.y
			var dl := len2(dx, dy)
			if dl > 0.0:
				dx /= dl; dy /= dl
			else:
				dx = 0.0; dy = 1.0
			var tmin := INF
			for b in data.border: tmin = minf(tmin, ray_rect(o.x, o.y, dx, dy, b))
			for b in L.get("s", []): tmin = minf(tmin, ray_rect(o.x, o.y, dx, dy, b))
			if tmin == INF: tmin = 2000.0
			st.lock = {"ox": o.x, "oy": o.y, "ex": o.x + dx * tmin, "ey": o.y + dy * tmin}
			events.append("charge")
		st.firing = st.lock != null and cyc >= SHIP_CHARGE and cyc < SHIP_CHARGE + SHIP_FIRE
		if st.firing and cyc - sp < SHIP_CHARGE:
			events.append("beam")

	var grav := tune("GRAV")
	for i in SUB:
		var t_prev := (float(t) - 1.0 + float(i) / SUB) * sp
		var t_now := (float(t) - 1.0 + float(i + 1) / SUB) * sp
		if plat >= 0 and not phased:  # ride the elevator you're standing on
			var a := mv_at(mv[plat], t_prev)
			var b := mv_at(mv[plat], t_now)
			px += float(b[0]) - float(a[0])
			py += float(b[1]) - float(a[1])
		vy += grav * g / SUB
		px += vx / SUB
		py += vy / SUB
		if rope != null:  # rope: can go slack, can't stretch
			var o: Dictionary = rope.o
			var rdx: float = px - o.x
			var rdy: float = py - o.y
			var rd: float = len2(rdx, rdy)
			if rd > rope.len:
				var nx: float = rdx / rd
				var ny: float = rdy / rd
				px = o.x + nx * rope.len
				py = o.y + ny * rope.len
				var vr: float = vx * nx + vy * ny
				if vr > 0.0:
					vx -= vr * nx
					vy -= vr * ny
		var was := grounded
		grounded = false
		plat = -1
		for rect in data.border:
			_resolve(rect)
		if not phased:
			for rect in L.get("s", []):
				_resolve(rect)
			for j in mv.size():
				var a := mv_at(mv[j], t_prev)
				var b := mv_at(mv[j], t_now)
				var m: Array = mv[j]
				_resolve_mv(b, (float(b[0]) - float(a[0])) * SUB, (float(b[1]) - float(a[1])) * SUB, float(m[7]) if m.size() > 7 else 0.0, j)
			# crushed: still buried in something solid after every push-out
			var crushed := false
			for j in mv.size():
				if overlap(px, py, R - 5.0, mv_at(mv[j], t_now)): crushed = true
			for rect in L.get("s", []):
				if overlap(px, py, R - 5.0, rect): crushed = true
			for rect in data.border:
				if overlap(px, py, R - 5.0, rect): crushed = true
			if crushed:
				return _die("crush")
		if grounded and not was and ammo < ammo_max:
			events.append("land")
		if grounded:
			ammo = ammo_max
		for k in L.get("k", []):
			if overlap(px, py, kill_r, spike_at(k, tau)):
				return _die("spike")
		for lz in L.get("lz", []):
			if laser_on(lz, tau) and dist_seg(px, py, float(lz[0]), float(lz[1]), float(lz[2]), float(lz[3])) < kill_r + 2.0:
				return _die("laser")
		for j in ships.size():
			var st: Dictionary = ships[j]
			var spos := ship_at(L.ship[j], tau)
			if len2(px - spos.x, py - spos.y) < kill_r + SHIP_BODY:
				return _die("ship")
			if st.firing and dist_seg(px, py, st.lock.ox, st.lock.oy, st.lock.ex, st.lock.ey) < kill_r + 3.0:
				return _die("beam")
	vx *= tune("FRICTION") if grounded else tune("DRAG")

	for o in orbs:
		if o.cd == 0.0 and len2(px - o.x, py - o.y) < R + orb_r:
			o.cd = 1e9 if d.get("singleOrbs", false) else 90.0
			ammo = ammo_max
			events.append("orb")
	if rope == null:
		for o in reds:
			var dist := len2(px - o.x, py - o.y)
			if o.cd == 0.0 and dist < float(d.latch):
				rope = {"o": o, "len": maxf(dist, 30.0)}
				ammo = ammo_max
				events.append("latch")
				break
	if phase_cd == 0:
		for o in purs:
			if o.cd == 0.0 and len2(px - o.x, py - o.y) < R + orb_r:
				phased = not phased
				o.cd = 60.0
				phase_cd = 30
				ammo = ammo_max
				events.append("phase" if phased else "unphase")
				break
	if grav_cd == 0:
		for o in gravs:
			if o.cd == 0.0 and len2(px - o.x, py - o.y) < R + orb_r:
				g = -g
				o.cd = 60.0
				grav_cd = 30
				ammo = ammo_max
				events.append("grav")
				break
	for tp in tps:
		if tp.cd != 0.0:
			continue
		var da := len2(px - tp.ax, py - tp.ay)
		var db := len2(px - tp.bx, py - tp.by)
		if da < R + orb_r or db < R + orb_r:
			var tox: float = tp.bx if da < db else tp.ax
			var toy: float = tp.by if da < db else tp.ay
			last_tp = [px, py, tox, toy]
			px = tox; py = toy
			tp.cd = 45.0
			ammo = ammo_max
			if rope != null:
				rope.o.cd = 40.0
				rope = null
			events.append("tp")
			break
	var goal: Array = L.goal
	if len2(px - float(goal[0]), py - float(goal[1])) < R + 16.0:
		if phased:
			if not lock_warn:
				lock_warn = true
				events.append("locked")
		else:
			done = true
			events.append("win")
			return "win"
	else:
		lock_warn = false
	return ""


## Deep copy (used by Easy mode's trajectory preview).
func clone() -> RefCounted:
	var c = get_script().new(level_index, diff)  # works even before Godot builds its class index
	for prop in ["px", "py", "vx", "vy", "ammo", "grounded", "phased", "phase_cd", "g", "grav_cd",
			"t", "shots", "started", "done", "dead", "lock_warn", "plat", "knock_cd", "death_by"]:
		c.set(prop, get(prop))
	c.orbs = orbs.duplicate(true)
	c.reds = reds.duplicate(true)
	c.purs = purs.duplicate(true)
	c.gravs = gravs.duplicate(true)
	c.tps = tps.duplicate(true)
	c.ships = ships.duplicate(true)
	if rope != null:
		c.rope = {"o": c.reds[reds.find(rope.o)], "len": rope.len}
	return c
