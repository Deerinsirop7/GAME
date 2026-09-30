extends Node
## Музыка (день/ночь с плавной сменой) и звуковые эффекты.

const MUSIC := ["music_day", "music_night"]
const SFX := ["sfx_click", "sfx_coin", "sfx_buy", "sfx_error", "sfx_eat", "sfx_play", "sfx_wash",
	"sfx_sleep", "sfx_pet", "sfx_levelup", "pet_dog", "pet_cat", "pet_parrot", "pet_fish"]
const FADE := 2.5

var streams := {}
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _sfx: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _check := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in MUSIC + SFX:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for n in MUSIC:
		var s := streams[n] as AudioStreamWAV
		if s:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		update_music()


func _music_db() -> float:
	return linear_to_db(maxf(0.0001, float(GameState.settings["music_volume"]) * 0.8))


func update_music(force := false) -> void:
	if not GameState.settings["music"]:
		if _current != "":
			for p in _music:
				p.stop()
			_current = ""
		return
	var wanted := "music_night" if TimeWeather.is_night() else "music_day"
	if wanted == _current and not force:
		_music[_active].volume_db = _music_db()
		return
	var old := _music[_active]
	_active = 1 - _active
	var new_p := _music[_active]
	new_p.stream = streams[wanted]
	new_p.volume_db = -40.0
	new_p.play()
	_current = wanted
	var tw := create_tween().set_parallel(true)
	tw.tween_property(new_p, "volume_db", _music_db(), FADE)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, FADE)
		tw.chain().tween_callback(old.stop)


func set_music_enabled(on: bool) -> void:
	GameState.settings["music"] = on
	GameState.save_settings()
	update_music(true)


func play(sfx_name: String, pitch_var := 0.06, volume := 1.0) -> void:
	if not streams.has(sfx_name):
		return
	var p := _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	p.stream = streams[sfx_name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = linear_to_db(maxf(0.0001, float(GameState.settings["sfx_volume"]) * volume))
	p.play()
