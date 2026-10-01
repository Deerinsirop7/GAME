extends Node
## Всё состояние игры, нужды питомца, экономика и сохранения.

signal needs_changed
signal coins_changed(total: int, delta: int)
signal state_changed          # куплен дом или предмет
signal pet_woke
signal sleep_changed(sleeping: bool)
signal friendship_up(level: int)
signal screen_requested(screen: String)

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const NEEDS := ["hunger", "joy", "energy", "clean"]
const NEED_NAMES := {"hunger": "Сытость", "joy": "Радость", "energy": "Энергия", "clean": "Чистота"}
## Базовое падение нужд, единиц в минуту реального времени.
const BASE_DECAY := {"hunger": 0.7, "joy": 0.6, "energy": 0.5, "clean": 0.4}
const SLEEP_REGEN := 20.0          # энергии в минуту во сне
const COIN_INTERVAL := 15.0        # секунд на монету, когда питомец доволен
const OFFLINE_CAP_HOURS := 8.0
const OFFLINE_FLOOR := 20.0        # оффлайн нужды не падают ниже этого

var data: Dictionary = {}
var settings := {
	"music": true, "music_volume": 0.4, "sfx_volume": 0.8,
	"fullscreen": false, "fast_time": false,
}
var playing := false               # true, пока открыт основной экран
var offline_report: Dictionary = {}

var _coin_acc := 0.0
var _save_acc := 0.0
var _emit_acc := 0.0


# ------------------------------------------------------------ жизненный цикл
func _process(delta: float) -> void:
	if not playing or data.is_empty():
		return
	var minutes := delta / 60.0
	var n: Dictionary = data["needs"]
	var sleeping: bool = data["sleeping"]
	for k in NEEDS:
		if sleeping and k == "energy":
			n[k] = minf(100.0, float(n[k]) + sleep_regen() * minutes)
		else:
			n[k] = maxf(0.0, float(n[k]) - decay_rate(k) * minutes)
	if sleeping and float(n["energy"]) >= 100.0:
		data["sleeping"] = false
		pet_woke.emit()
		sleep_changed.emit(false)
	if is_content():
		_coin_acc += delta * coin_rate()
		if _coin_acc >= COIN_INTERVAL:
			_coin_acc -= COIN_INTERVAL
			add_coins(1)
	_emit_acc += delta
	if _emit_acc >= 0.1:
		_emit_acc = 0.0
		needs_changed.emit()
	_save_acc += delta
	if _save_acc >= 30.0:
		_save_acc = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		save_settings()


# ------------------------------------------------------------ новая игра / сохранения
func new_game(pet: Dictionary) -> void:
	data = {
		"version": 2,
		"pet": pet,
		"needs": {"hunger": 70.0, "joy": 70.0, "energy": 90.0, "clean": 85.0},
		"coins": 20, "total_coins": 0, "house": 0, "items": [],
		"xp": 0, "sleeping": false, "interior": false, "bowl": 1,
		"last_time": Time.get_unix_time_from_system(),
	}
	offline_report = {}
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if data.is_empty():
		return
	data["last_time"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("pet"):
		return false
	data = parsed
	_fix_types()
	_apply_offline()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	data = {}


## JSON хранит все числа как float — возвращаем целые там, где нужно.
func _fix_types() -> void:
	for k in ["coins", "total_coins", "house", "xp"]:
		data[k] = int(data.get(k, 0))
	data["bowl"] = int(data.get("bowl", 1))
	var pet: Dictionary = data["pet"]
	pet["coat"] = int(pet.get("coat", 0))
	data.erase("player")
	var items: Array[String] = []
	for it in data.get("items", []):
		if Catalog.ITEMS.has(str(it)):
			items.append(str(it))
	data["items"] = items
	data["sleeping"] = bool(data.get("sleeping", false))
	data["interior"] = bool(data.get("interior", false))
	for k in NEEDS:
		data["needs"][k] = float(data["needs"].get(k, 70.0))
	data["version"] = 2


func _apply_offline() -> void:
	var now := Time.get_unix_time_from_system()
	var elapsed := clampf(now - float(data.get("last_time", now)), 0.0, OFFLINE_CAP_HOURS * 3600.0)
	var minutes := elapsed / 60.0
	offline_report = {}
	if minutes < 2.0:
		return
	var was_content := is_content()
	var n: Dictionary = data["needs"]
	for k in NEEDS:
		var v: float = n[k]
		if data["sleeping"] and k == "energy":
			n[k] = minf(100.0, v + sleep_regen() * minutes)
			continue
		var floor_v := minf(v, OFFLINE_FLOOR)
		n[k] = maxf(floor_v, v - decay_rate(k) * minutes)
	if data["sleeping"] and float(n["energy"]) >= 100.0:
		data["sleeping"] = false
	var earned := 0
	if was_content:
		earned = int(minf(minutes * 0.5, 120.0))
		if earned > 0:
			add_coins(earned)
	offline_report = {"minutes": int(minutes), "coins": earned}


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			for k in parsed:
				settings[k] = parsed[k]
	apply_display()


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))


func apply_display() -> void:
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ------------------------------------------------------------ вычисления
func pet_type() -> String:
	return str(data["pet"]["type"])


func pet_name() -> String:
	return str(data["pet"]["name"])


func has_item(id: String) -> bool:
	return not data.is_empty() and data["items"].has(id)


func comfort() -> int:
	var c := 0
	for id in data.get("items", []):
		c += int(Catalog.ITEMS[id]["comfort"])
	return c + int(data.get("house", 0))


func friendship_level() -> int:
	return int(sqrt(float(data.get("xp", 0)) / 4.0)) + 1


func friendship_progress() -> float:
	var lvl := friendship_level()
	var lo := 4.0 * pow(lvl - 1, 2)
	var hi := 4.0 * pow(lvl, 2)
	return clampf((float(data["xp"]) - lo) / (hi - lo), 0.0, 1.0)


func decay_rate(k: String) -> float:
	var r: float = BASE_DECAY[k] * float(Catalog.PETS[pet_type()]["decay"][k])
	if data["sleeping"]:
		if k == "joy":
			return 0.0
		r *= 0.5
	match k:
		"joy":
			r /= 1.0 + 0.06 * comfort()
		"energy":
			if has_item("pet_bed"):
				r *= 0.75
		"clean":
			if TimeWeather.weather == "rain" and int(data["house"]) == 0:
				r *= 1.4
	return r


func sleep_regen() -> float:
	var r := SLEEP_REGEN
	if has_item("pet_bed"):
		r *= 1.25
	if has_item("bed"):
		r *= 1.2
	return r


func mood() -> float:
	var s := 0.0
	for k in NEEDS:
		s += float(data["needs"][k])
	return s / NEEDS.size()


func is_content() -> bool:
	return float(data["needs"]["hunger"]) > 50.0 and mood() >= 70.0


func coin_rate() -> float:
	return 1.0 + 0.04 * comfort() + 0.05 * (friendship_level() - 1)


func lowest_need() -> String:
	var best := "hunger"
	for k in NEEDS:
		if float(data["needs"][k]) < float(data["needs"][best]):
			best = k
	return best


# ------------------------------------------------------------ забота (вызывается из мышиных взаимодействий)
var _care_acc := 0.0


## Общая награда: когда питомцу действительно была нужна забота — монеты и дружба.
func _care(need_before: float, gain: float) -> void:
	if need_before < 70.0 and gain > 0.0:
		_care_acc += gain
		while _care_acc >= 20.0:
			_care_acc -= 20.0
			add_coins(2)
			add_xp(1)


func _bump(k: String, delta_v: float) -> float:
	var n: Dictionary = data["needs"]
	var before: float = n[k]
	n[k] = clampf(before + delta_v, 0.0, 100.0)
	return before


## Насыпать корм в миску. Возвращает текст ошибки или "".
func pour_food() -> String:
	if int(data["bowl"]) >= 3:
		return "Миска уже полная"
	data["bowl"] = int(data["bowl"]) + 1
	needs_changed.emit()
	return ""


## Питомец съел порцию из миски.
func eat_portion() -> void:
	if int(data["bowl"]) <= 0:
		return
	data["bowl"] = int(data["bowl"]) - 1
	var before := _bump("hunger", 18.0)
	_bump("clean", -1.5)
	_care(before, 18.0)
	needs_changed.emit()


## Рыбка съела хлопья.
func eat_flake() -> void:
	var before := _bump("hunger", 4.0)
	_care(before, 4.0)
	needs_changed.emit()


func stroke(amount: float) -> void:
	var n: Dictionary = data["needs"]
	if float(n["joy"]) > 90.0:
		amount *= 0.3
	var before := _bump("joy", amount)
	_care(before, amount)
	needs_changed.emit()


func scrub(amount: float) -> void:
	var before := _bump("clean", amount)
	if not Catalog.PETS[pet_type()]["likes_water"]:
		_bump("joy", -amount * 0.15)
	_care(before, amount)
	needs_changed.emit()


## Игра. Возвращает false, если питомец слишком устал.
func play(amount: float) -> bool:
	var n: Dictionary = data["needs"]
	if float(n["energy"]) < 12.0:
		return false
	if has_item("toy_box"):
		amount *= 1.5
	var before := _bump("joy", amount)
	_bump("energy", -amount * 0.3)
	_bump("hunger", -amount * 0.12)
	_bump("clean", -amount * 0.12)
	_care(before, amount)
	needs_changed.emit()
	return true


func can_play() -> bool:
	return float(data["needs"]["energy"]) >= 12.0


## Уложить спать или разбудить. Возвращает текст ошибки или "".
func toggle_sleep() -> String:
	if data["sleeping"]:
		data["sleeping"] = false
		sleep_changed.emit(false)
		return ""
	if float(data["needs"]["energy"]) >= 85.0:
		return "Спать ещё не хочется"
	var before: float = data["needs"]["energy"]
	data["sleeping"] = true
	if before < 50.0:
		add_coins(2)
		add_xp(1)
	sleep_changed.emit(true)
	return ""


func add_coins(amount: int) -> void:
	data["coins"] = int(data["coins"]) + amount
	if amount > 0:
		data["total_coins"] = int(data["total_coins"]) + amount
	coins_changed.emit(int(data["coins"]), amount)


func add_xp(amount: int) -> void:
	var before := friendship_level()
	data["xp"] = int(data["xp"]) + amount
	var after := friendship_level()
	if after > before:
		friendship_up.emit(after)


# ------------------------------------------------------------ покупки
## Статус: "owned", "locked" (нужен дом получше), "poor" (не хватает монет), "ok".
func item_status(id: String) -> String:
	var it: Dictionary = Catalog.ITEMS[id]
	if has_item(id):
		return "owned"
	if int(data["house"]) < int(it["req"]):
		return "locked"
	if int(data["coins"]) < int(it["price"]):
		return "poor"
	return "ok"


func buy_item(id: String) -> bool:
	if item_status(id) != "ok":
		return false
	add_coins(-int(Catalog.ITEMS[id]["price"]))
	data["items"].append(id)
	state_changed.emit()
	save_game()
	return true


func house_status(tier: int) -> String:
	var cur := int(data["house"])
	if tier <= cur:
		return "owned"
	if tier > cur + 1:
		return "locked"
	if int(data["coins"]) < int(Catalog.HOUSES[tier]["price"]):
		return "poor"
	return "ok"


func buy_house(tier: int) -> bool:
	if house_status(tier) != "ok":
		return false
	add_coins(-int(Catalog.HOUSES[tier]["price"]))
	data["house"] = tier
	state_changed.emit()
	save_game()
	return true
