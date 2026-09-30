extends Node
## Время суток и погода.
## По умолчанию время берётся с часов компьютера; в настройках можно включить
## ускоренный режим (1 игровой час = 1 реальная минута).

signal weather_changed(weather: String)

const WEATHERS := ["sunny", "cloudy", "rain"]
const WEATHER_NAMES := {"sunny": "Солнечно", "cloudy": "Облачно", "rain": "Дождь"}
const TRANSITIONS := {
	"sunny": {"sunny": 0.3, "cloudy": 0.7},
	"cloudy": {"sunny": 0.45, "cloudy": 0.15, "rain": 0.4},
	"rain": {"cloudy": 0.8, "rain": 0.2},
}

var hour := 12.0
var weather := "sunny"
var _timer := 600.0
var _offset := 0.0
var _fast_hour := 12.0


func _ready() -> void:
	randomize()
	hour = real_hour()
	_fast_hour = hour
	weather = "sunny" if randf() < 0.6 else "cloudy"
	_timer = randf_range(300.0, 700.0)


func _process(delta: float) -> void:
	if GameState.settings.get("fast_time", false):
		_fast_hour = fmod(_fast_hour + delta / 60.0, 24.0)
		hour = _fast_hour
	else:
		hour = fmod(real_hour() + _offset, 24.0)
		_fast_hour = hour
	_timer -= delta
	if _timer <= 0.0:
		_next_weather()


func real_hour() -> float:
	var t := Time.get_time_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0 + float(t["second"]) / 3600.0


func _next_weather() -> void:
	var roll := randf()
	var acc := 0.0
	var opts: Dictionary = TRANSITIONS[weather]
	var picked: String = weather
	for w in opts:
		acc += float(opts[w])
		if roll <= acc:
			picked = w
			break
	set_weather(picked)


func set_weather(w: String) -> void:
	_timer = randf_range(420.0, 900.0)
	if w != weather:
		weather = w
		weather_changed.emit(w)


## Отладка: следующая погода по кругу.
func cycle_weather() -> void:
	set_weather(WEATHERS[(WEATHERS.find(weather) + 1) % WEATHERS.size()])


## Отладка: прокрутить час вперёд.
func skip_hour() -> void:
	if GameState.settings.get("fast_time", false):
		_fast_hour = fmod(_fast_hour + 1.0, 24.0)
	else:
		_offset = fmod(_offset + 1.0, 24.0)


## 1 — глубокая ночь, 0 — день.
func night_factor() -> float:
	var h := hour
	if h < 5.0 or h >= 20.5:
		return 1.0
	if h < 7.0:
		return 1.0 - (h - 5.0) / 2.0
	if h >= 18.5:
		return (h - 18.5) / 2.0
	return 0.0


## Тёплый оттенок рассвета и заката (0..1).
func dusk_factor() -> float:
	var a := 1.0 - clampf(absf(hour - 6.5) / 1.5, 0.0, 1.0)
	var b := 1.0 - clampf(absf(hour - 18.8) / 1.5, 0.0, 1.0)
	return maxf(a, b)


func is_night() -> bool:
	return night_factor() > 0.6


func time_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%02d:%02d" % [h, m]


func weather_name() -> String:
	return WEATHER_NAMES[weather]
