extends Node
## Background music: "Code Injection Dark Techno Music Pack" by DavidKBD (CC BY 4.0, see CREDITS.md).
## Every world has its own track; the finals and God Mode have their own too.
## The .ogg files are the artist's originals (designed to loop). Loudness differences between
## tracks are evened out here with GAIN_DB rather than by editing the audio.

const DIR := "res://assets/music/"
const WORLD_TRACKS := [
	"01_underbeat",               # 1 Fire Blast
	"02_behind_the_darkness",     # 2 Swing
	"09_ghost_steps",             # 3 Phase (walking through walls)
	"10_space_echoes",            # 4 Teleport
	"05_into_the_code_abyss",     # 5 Gravity
	"04_secret_dissonance",       # 6 Moving spikes
	"03_synthetic_whisper",       # 7 Elevators
	"12_faceless_crowd",          # 8 Pushers
	"06_electric_inferno",        # 9 Lasers
	"08_sentinel_cloud",          # 10 Gunships
]
const FINALS_EARLY := "07_binary_chaos"                # F1-F5
const FINALS_LATE := "11_i_a_s_growl"                  # F6-F9
const FINAL_EXAM := "13_between_everyone_and_anyone"   # F10
const GOD_MODE := "14_theres_someone_here"             # whole God Mode run
const TITLE := "00_title_pink_bloom"                   # start screen, main menu, leaderboard (itch.io; see CREDITS.md)

# Measured integrated loudness (LUFS) -> gain that brings each track to about -14.5 LUFS.
const GAIN_DB := {
	"01_underbeat": -3.2, "02_behind_the_darkness": -3.0, "03_synthetic_whisper": -2.8,
	"04_secret_dissonance": -0.3, "05_into_the_code_abyss": -2.4, "06_electric_inferno": -2.8,
	"07_binary_chaos": -2.8, "08_sentinel_cloud": -0.9, "09_ghost_steps": -1.1,
	"10_space_echoes": -0.6, "11_i_a_s_growl": -2.0, "12_faceless_crowd": -1.3,
	"13_between_everyone_and_anyone": -3.0, "14_theres_someone_here": 0.2, "00_title_pink_bloom": -3.1,
}
const FADE := 1.2  # seconds

var volume := 0.7          # 0..1, changed from the level screen or with V
var current := ""          # track name currently playing
var _active: AudioStreamPlayer
var _idle: AudioStreamPlayer
var _cache := {}


func _ready() -> void:
	_active = AudioStreamPlayer.new()
	_idle = AudioStreamPlayer.new()
	add_child(_active)
	add_child(_idle)


static func track_for_level(i: int, god_mode := false) -> String:
	if god_mode: return GOD_MODE
	if i >= 59: return FINAL_EXAM
	if i >= 55: return FINALS_LATE
	if i >= 50: return FINALS_EARLY
	return WORLD_TRACKS[i / 5]


func _db() -> float:
	if volume <= 0.001:
		return -80.0
	return linear_to_db(volume) + float(GAIN_DB.get(current, 0.0))


func _load(track: String) -> AudioStream:
	if not _cache.has(track):
		var path := DIR + track + ".ogg"
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis or s is AudioStreamMP3:
			s.loop = true
		_cache[track] = s
	return _cache[track]


## Start a track, crossfading from whatever is playing. Same track keeps playing,
## unless restart is true, then it crossfades into the same track from the beginning.
func play(track: String, restart := false) -> void:
	if track == current and not restart:
		return
	var stream := _load(track)
	if stream == null:
		push_warning("Music file not found: " + DIR + track + ".ogg")
		return
	current = track
	var old := _active
	_active = _idle
	_idle = old
	_active.stream = stream
	_active.volume_db = -80.0
	_active.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_active, "volume_db", _db(), FADE)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, FADE)
		tw.chain().tween_callback(old.stop)


func play_for_level(i: int, god_mode := false, restart := false) -> void:
	play(track_for_level(i, god_mode), restart)


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_active.volume_db = _db()


func is_playing() -> bool:
	return _active.playing


func _exit_tree() -> void:
	_active.stop()
	_idle.stop()
	_active.stream = null
	_idle.stream = null
	_cache.clear()
