extends Node
## Background music: one looping track per group of worlds, crossfading when the group changes.
##
## To use your own music, save it over one of the files below (same name), or change the
## paths here. Godot plays .ogg (best), .mp3 and .wav. Make sure you have a license that
## covers games, trailers and streaming.

const TRACKS := [
	"res://assets/music/neon_drive.ogg",   # worlds 1-5   (levels 1-25)
	"res://assets/music/overclock.ogg",    # worlds 6-10  (levels 26-50)
	"res://assets/music/final_exam.ogg",   # finals       (levels 51-60)
]
const FADE := 1.2  # seconds

var volume := 0.7          # 0..1, changed from the level screen or with V
var current := ""
var _active: AudioStreamPlayer
var _idle: AudioStreamPlayer
var _cache := {}


func _ready() -> void:
	_active = AudioStreamPlayer.new()
	_idle = AudioStreamPlayer.new()
	add_child(_active)
	add_child(_idle)


static func track_for_level(i: int) -> String:
	if i < 25: return TRACKS[0]
	if i < 50: return TRACKS[1]
	return TRACKS[2]


func _db(v: float) -> float:
	return linear_to_db(v) if v > 0.001 else -80.0


func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis or s is AudioStreamMP3:
			s.loop = true
		elif s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		_cache[path] = s
	return _cache[path]


## Start a track (crossfading from whatever is playing). Same track = keep playing.
func play(path: String) -> void:
	if path == current:
		return
	var stream := _load(path)
	if stream == null:
		push_warning("Music file not found: " + path)
		return
	current = path
	var old := _active
	_active = _idle
	_idle = old
	_active.stream = stream
	_active.volume_db = -80.0
	_active.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_active, "volume_db", _db(volume), FADE)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, FADE)
		tw.chain().tween_callback(old.stop)


func play_for_level(i: int) -> void:
	play(track_for_level(i))


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_active.volume_db = _db(volume)


func is_playing() -> bool:
	return _active.playing


func _exit_tree() -> void:
	_active.stop()
	_idle.stop()
	_active.stream = null
	_idle.stream = null
	_cache.clear()
