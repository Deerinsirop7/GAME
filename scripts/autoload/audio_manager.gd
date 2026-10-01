extends Node
## Звук. Музыка играет как в Stardew: мелодия → минута-две тишины → следующая.
## Фоном всегда звучит природа: птицы днём, сверчки ночью, дождь.

const MUSIC_DAY := ["music_day_1", "music_day_2"]
const MUSIC_NIGHT := ["music_night_1", "music_night_2"]
const AMBIENT := ["ambient_day", "ambient_night", "ambient_rain"]
const SFX := ["sfx_click", "sfx_coin", "sfx_buy", "sfx_error", "sfx_eat", "sfx_play", "sfx_wash",
	"sfx_sleep", "sfx_pet", "sfx_levelup", "sfx_pour", "sfx_scrub", "sfx_shake", "sfx_bounce",
	"sfx_bell", "sfx_purr", "pet_dog", "pet_cat", "pet_parrot", "pet_fish"]
const GAP_MIN := 60.0
const GAP_MAX := 150.0

var streams := {}
## 0..1 — насколько приглушить фон (в доме тише).
var ambient_muffle := 0.0

var _music: AudioStreamPlayer
var _music_night := false
var _music_index := 0
var _gap := 4.0
var _amb: Array[AudioStreamPlayer] = []
var _amb_active := 0
var _amb_current := ""
var _sfx: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _check := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in MUSIC_DAY + MUSIC_NIGHT + AMBIENT + SFX:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for n in AMBIENT:
		var s := streams[n] as AudioStreamWAV
		if s:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(_on_music_finished)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_amb.append(p)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)


func _process(delta: float) -> void:
	# музыка
	if GameState.settings["music"]:
		var night := TimeWeather.is_night()
		if _music.playing and night != _music_night:
			var tw := create_tween()
			tw.tween_property(_music, "volume_db", -60.0, 3.0)
			tw.tween_callback(_music.stop)
			_music_night = night
			_gap = 8.0
		elif not _music.playing:
			_gap -= delta
			if _gap <= 0.0:
				_start_track()
	elif _music.playing:
		_music.stop()
	# фон
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_update_ambient()


func _db(linear: float) -> float:
	return linear_to_db(maxf(0.0001, linear))


func _start_track() -> void:
	_music_night = TimeWeather.is_night()
	var list: Array = MUSIC_NIGHT if _music_night else MUSIC_DAY
	_music_index = (_music_index + 1) % list.size()
	_music.stream = streams[list[_music_index]]
	_music.volume_db = _db(float(GameState.settings["music_volume"]) * 0.7)
	_music.play()


func _on_music_finished() -> void:
	_gap = randf_range(GAP_MIN, GAP_MAX)


func _update_ambient() -> void:
	var wanted := "ambient_day"
	if TimeWeather.weather == "rain":
		wanted = "ambient_rain"
	elif TimeWeather.night_factor() > 0.5:
		wanted = "ambient_night"
	var vol := float(GameState.settings["sfx_volume"]) * 0.45 * (1.0 - 0.6 * ambient_muffle)
	if wanted == _amb_current:
		_amb[_amb_active].volume_db = _db(vol)
		return
	var old := _amb[_amb_active]
	_amb_active = 1 - _amb_active
	var p := _amb[_amb_active]
	p.stream = streams[wanted]
	p.volume_db = -50.0
	p.play()
	_amb_current = wanted
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "volume_db", _db(vol), 3.0)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, 3.0)
		tw.chain().tween_callback(old.stop)


## Применить громкость музыки из настроек.
func update_music(_force := false) -> void:
	if not GameState.settings["music"]:
		_music.stop()
	elif _music.playing and _music_night == TimeWeather.is_night():
		_music.volume_db = _db(float(GameState.settings["music_volume"]) * 0.7)


func set_music_enabled(on: bool) -> void:
	GameState.settings["music"] = on
	GameState.save_settings()
	if on:
		_gap = 1.0
	else:
		_music.stop()


func play(sfx_name: String, pitch_var := 0.06, volume := 1.0) -> void:
	if not streams.has(sfx_name):
		return
	var p := _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	p.stream = streams[sfx_name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = _db(float(GameState.settings["sfx_volume"]) * volume)
	p.play()
