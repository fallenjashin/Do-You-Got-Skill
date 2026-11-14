extends SceneTree
## Parity test: replays every reference run recorded from the browser prototype
## (tests/golden_runs.json) through the Godot physics and checks they match.
## Run:  godot --headless --path . -s tests/test_parity.gd

const Sim := preload("res://scripts/sim.gd")
const TOL := 1e-6


func _init() -> void:
	var cases: Array = JSON.parse_string(FileAccess.open("res://tests/golden_runs.json", FileAccess.READ).get_as_text())
	var failed := 0
	var worst := 0.0
	var by_result := {}
	for c in cases:
		var sim = Sim.new(int(c.level), c.diff)
		sim.started = true
		var acts: Array = c.acts
		var ai := 0
		var trace_i := 0
		var res := ""
		var err := 0.0
		for f in 6000:
			while ai < acts.size() and int(acts[ai][0]) == sim.t:
				sim.fire(float(acts[ai][1]), float(acts[ai][2]))
				ai += 1
			res = sim.tick()
			if res == "dead" and sim.respawn():   # screens 2+: back to the screen's start, like the game
				res = ""
			sim.events.clear()
			if sim.t % 10 == 0 and trace_i < c.trace.size():
				var tr: Array = c.trace[trace_i]
				if int(tr[0]) == sim.t:
					err = maxf(err, maxf(absf(sim.px - float(tr[1])), absf(sim.py - float(tr[2]))))
					trace_i += 1
			if res != "":
				break
		var want: String = c.result
		var got := res if res != "" else "timeout"
		var fin: Array = c.final
		err = maxf(err, maxf(absf(sim.px - float(fin[0])), absf(sim.py - float(fin[1]))))
		worst = maxf(worst, err)
		by_result[got] = by_result.get(got, 0) + 1
		var room_ok: bool = fin.size() < 8 or sim.room == int(fin[7])
		if got != want or sim.t != int(c.t) or sim.shots != int(c.shots) or err > TOL or not room_ok:
			failed += 1
			if failed <= 10:
				print("MISMATCH level %d %s %s: want %s@%d got %s@%d shots %d/%d err %s" % [
					int(c.level) + 1, c.diff, c.kind, want, int(c.t), got, sim.t, sim.shots, int(c.shots), err])
	print("parity: %d/%d runs match the prototype (outcomes %s), worst position error %s px" % [
		cases.size() - failed, cases.size(), by_result, worst])
	quit(1 if failed > 0 else 0)
