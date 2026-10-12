extends Node
## Sound effects pool and music player.

const SFX := {
	"money": "res://assets/sfx/money.wav",
	"nitro_pickup": "res://assets/sfx/nitro_pickup.wav",
	"nitro_fire": "res://assets/sfx/nitro_fire.wav",
	"menu_move": "res://assets/sfx/menu_move.wav",
	"menu_select": "res://assets/sfx/menu_select.wav",
	"error": "res://assets/sfx/error.wav",
	"lose": "res://assets/sfx/lose.wav",
	"fanfare": "res://assets/sfx/fanfare.wav",
	"buy": "res://assets/sfx/buy.wav",
	"land": "res://assets/sfx/land.wav",
	"crash": "res://assets/sfx/crash.wav",
	"beep": "res://assets/sfx/beep.wav",
	"beep_go": "res://assets/sfx/beep_go.wav",
	"bump": "res://assets/sfx/bump.ogg",
	"bump_light": "res://assets/sfx/bump_light.ogg",
	"splash": "res://assets/sfx/splash.ogg",
}
const MUSIC := {
	"title": "res://assets/music/title.wav",
	"race1": "res://assets/music/race1.wav",
	"race2": "res://assets/music/race2.wav",
	"race3": "res://assets/music/race3.wav",
	"ending": "res://assets/music/ending.wav",
}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_name := ""
var _cooldown := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for k in SFX:
		_streams[k] = load(SFX[k])
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -8.0
	_music.bus = "Music"
	add_child(_music)
	_music.finished.connect(func(): _music.play())


func _process(delta: float) -> void:
	for k in _cooldown.keys():
		_cooldown[k] -= delta
		if _cooldown[k] <= 0.0:
			_cooldown.erase(k)


## Plays an effect. `min_gap` prevents the same sound from stacking up.
func play(sfx_name: String, volume_db := 0.0, pitch := 1.0, min_gap := 0.05) -> void:
	if _cooldown.has(sfx_name) or not _streams.has(sfx_name):
		return
	_cooldown[sfx_name] = min_gap
	for p in _pool:
		if not p.playing:
			p.stream = _streams[sfx_name]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


func music(music_name: String) -> void:
	if music_name == _music_name and _music.playing:
		return
	_music_name = music_name
	if music_name == "":
		_music.stop()
		return
	_music.stream = load(MUSIC[music_name])
	_music.play()


## Volumes are linear 0..1.
func set_volumes(music_linear: float, sfx_linear: float) -> void:
	for pair in [["Music", music_linear], ["SFX", sfx_linear]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pair[1], 0.0001)))
			AudioServer.set_bus_mute(i, pair[1] <= 0.001)


## Returns a looping engine stream (shared resource).
func engine_stream() -> AudioStream:
	var s: AudioStreamWAV = load("res://assets/sfx/engine.wav")
	if s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate) - 1
	return s
