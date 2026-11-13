class_name Sfx
extends Node
## Tiny synth: makes the same placeholder beeps as the prototype, no audio files needed.
## Replace with real sound effects later (AudioStreamPlayer + .wav/.ogg).

const RATE := 22050
const VOICES := 10

var _players: Array[AudioStreamPlayer] = []
var _cache := {}
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## freq Hz, dur seconds, wave "square" | "sawtooth" | "triangle" | "sine", vol 0..1, slide = end freq (0 = none)
func beep(freq: float, dur := 0.06, wave := "square", vol := 0.05, slide := 0.0) -> void:
	var key := "%d|%.3f|%s|%.3f|%d" % [int(freq), dur, wave, vol, int(slide)]
	if not _cache.has(key):
		_cache[key] = _make(freq, dur, wave, vol, slide)
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _cache[key]
	p.play()


func _make(freq: float, dur: float, wave: String, vol: float, slide: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		var f := freq * pow(slide / freq, k) if slide > 0.0 else freq
		phase = fmod(phase + f / RATE, 1.0)
		var s: float
		match wave:
			"square": s = 1.0 if phase < 0.5 else -1.0
			"sawtooth": s = phase * 2.0 - 1.0
			"triangle": s = 1.0 - 4.0 * absf(phase - 0.5)
			_: s = sin(phase * TAU)
		var env := vol * pow(0.0001 / vol, k)  # exponential fade, like the prototype
		bytes.encode_s16(i * 2, int(clampf(s * env * 3.0, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
