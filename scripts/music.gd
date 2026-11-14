extends Node
## Background music: one looping track per group of worlds, crossfading when the group changes.
##
## Tracks are from itch.io (commercial use allowed; see CREDITS.md). They were trimmed of
## leading silence, loudness-matched to -15 LUFS and converted to .ogg so they loop without gaps.
## To change a track, save a new .ogg over the same file name, or edit TRACKS / track_for_level().

const TRACKS := [
	"res://assets/music/electronic_ambient.ogg",   # worlds 1-2   Recoil, Swing (learning; calmest)
	"res://assets/music/cosmic_journey.ogg",       # worlds 3-4   Phase, Teleport
	"res://assets/music/pink_bloom.ogg",           # worlds 5-6   Gravity, Moving Spikes
	"res://assets/music/code_injection.ogg",       # worlds 7-10  Elevators, Pushers, Lasers, Gunships
	"res://assets/music/electric_pulse.ogg",       # finals       (fastest, most intense)
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
	if i >= 50: return TRACKS[4]   # finals
	var world := i / 5             # 0-based world
	if world <= 1: return TRACKS[0]
	if world <= 3: return TRACKS[1]
	if world <= 5: return TRACKS[2]
	return TRACKS[3]


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
