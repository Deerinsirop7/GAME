extends Node
## Основной экран: мир, панель нужд, монеты, действия, магазин, настройки.

const WorldScene = preload("res://scripts/world/world_scene.gd")
const NeedBar = preload("res://scripts/ui/need_bar.gd")
const Shop = preload("res://scripts/ui/shop.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

const ACTIONS := [
	{"id": "feed", "text": "Кормить", "icon": "ui/act_feed", "key": KEY_1},
	{"id": "play", "text": "Играть", "icon": "ui/act_play", "key": KEY_2},
	{"id": "wash", "text": "Мыть", "icon": "ui/act_wash", "key": KEY_3},
	{"id": "sleep", "text": "Спать", "icon": "ui/act_sleep", "key": KEY_4},
	{"id": "pet", "text": "Гладить", "icon": "ui/act_pet", "key": KEY_5},
]
const NEED_COLORS := {
	"hunger": Color("f0a45a"), "joy": Color("f07aa0"), "energy": Color("f5d05a"), "clean": Color("6ab8f0"),
}
const WEATHER_TOASTS := {
	"sunny": "Выглянуло солнышко", "cloudy": "Набежали облака", "rain": "Пошёл дождь",
}

var ws: Node
var busy := false
var _ui: Control
var _bars := {}
var _name_label: Label
var _level_label: Label
var _coins_label: Label
var _time_label: Label
var _comfort_label: Label
var _action_btns := {}
var _shop_btn: Button
var _home_btn: Button
var _music_btn: Button
var _toast: Label
var _toast_queue: Array[String] = []
var _toast_busy := false
var _overlay = null
var _zzz_t := 0.0


func _ready() -> void:
	ws = WorldScene.new()
	add_child(ws)
	ws.add_actors(GameState.data["player"], GameState.pet_type())
	ws.pet.show_emotes = true
	ws.pet.set_sleeping(GameState.data["sleeping"])
	if GameState.data["interior"] and int(GameState.data["house"]) >= 2:
		ws.set_interior(true)
	GameState.playing = true

	_build_ui()
	GameState.needs_changed.connect(_update_hud)
	GameState.coins_changed.connect(_on_coins)
	GameState.state_changed.connect(_on_state)
	GameState.pet_woke.connect(_on_woke)
	GameState.friendship_up.connect(_on_friendship)
	TimeWeather.weather_changed.connect(_on_weather)
	_update_hud()
	_refresh_buttons()

	var rep := GameState.offline_report
	if not rep.is_empty() and int(rep["minutes"]) > 0:
		var msg := "С возвращением! Тебя не было %s." % _minutes_text(int(rep["minutes"]))
		toast(msg)
		if int(rep["coins"]) > 0:
			toast("Пока ты отдыхал(а), накопилось монет: %d" % int(rep["coins"]))
		GameState.offline_report = {}
	elif int(GameState.data["total_coins"]) == 0:
		toast("Добро пожаловать домой, %s!" % GameState.data["player"]["name"])
		toast("Нажми на питомца, чтобы погладить")
	Audio.play(Catalog.PETS[GameState.pet_type()]["sound"], 0.05, 0.6)


func _exit_tree() -> void:
	GameState.playing = false
	GameState.save_game()


func _minutes_text(m: int) -> String:
	if m >= 60:
		return "%d ч %d мин" % [m / 60, m % 60]
	return "%d мин" % m


# ------------------------------------------------------------ интерфейс
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = UIKit.root_control()
	layer.add_child(_ui)

	# верхняя строка
	var top := HBoxContainer.new()
	top.position = Vector2(6, 6)
	top.size = Vector2(628, 0)
	top.custom_minimum_size = Vector2(628, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(top)

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UIKit.box(Color(1, 0.965, 0.89, 0.92), UIKit.DARK, 2, 4, 6))
	top.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 0)
	left.add_child(lv)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	lv.add_child(name_row)
	_name_label = UIKit.label(GameState.pet_name(), 16)
	name_row.add_child(_name_label)
	name_row.add_child(UIKit.icon("fx/heart", 2.0))
	_level_label = UIKit.label("", 13, Color("8a5a7a"))
	name_row.add_child(_level_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 0)
	lv.add_child(grid)
	for k in GameState.NEEDS:
		var bar := NeedBar.new()
		bar.setup(k, NEED_COLORS[k])
		grid.add_child(bar)
		_bars[k] = bar

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UIKit.box(Color(1, 0.965, 0.89, 0.92), UIKit.DARK, 2, 4, 6))
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 0)
	right.add_child(rv)
	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_END
	rv.add_child(coin_row)
	coin_row.add_child(UIKit.icon("fx/coin", 2.0))
	_coins_label = UIKit.label("0", 18)
	coin_row.add_child(_coins_label)
	_time_label = UIKit.label("", 13)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(_time_label)
	_comfort_label = UIKit.label("", 13, Color("8a5a7a"))
	_comfort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(_comfort_label)

	# нижняя панель действий
	var bar_box := HBoxContainer.new()
	bar_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_box.offset_left = 4
	bar_box.offset_right = -4
	bar_box.offset_top = -60
	bar_box.offset_bottom = -4
	bar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_box.add_theme_constant_override("separation", 4)
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(bar_box)
	for a in ACTIONS:
		var id: String = a["id"]
		var b := _bar_button(a["text"], a["icon"], func(): act(id))
		b.tooltip_text = "%s  [%s]" % [a["text"], OS.get_keycode_string(a["key"])]
		bar_box.add_child(b)
		_action_btns[id] = b
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	bar_box.add_child(gap)
	_shop_btn = _bar_button("Магазин", "ui/act_shop", open_shop)
	_shop_btn.tooltip_text = "Магазин  [B]"
	bar_box.add_child(_shop_btn)
	_home_btn = _bar_button("Войти", "ui/act_home", toggle_interior)
	_home_btn.tooltip_text = "Дом / двор  [H]"
	bar_box.add_child(_home_btn)
	_music_btn = _bar_button("Музыка", "ui/act_music", toggle_music)
	_music_btn.tooltip_text = "Музыка  [M]"
	bar_box.add_child(_music_btn)
	var menu := _bar_button("Меню", "ui/act_gear", open_settings)
	menu.tooltip_text = "Настройки  [Esc]"
	bar_box.add_child(menu)

	# всплывающие сообщения
	_toast = UIKit.label("", 16, Color.WHITE, 6)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 96
	_toast.offset_bottom = 124
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_ui.add_child(_toast)


func _bar_button(text: String, icon_path: String, cb: Callable) -> Button:
	var b := UIKit.button(text, icon_path, cb, true)
	b.custom_minimum_size = Vector2(62, 56)
	b.add_theme_font_size_override("font_size", 12)
	return b


func _update_hud() -> void:
	var n: Dictionary = GameState.data["needs"]
	for k in _bars:
		_bars[k].set_value(float(n[k]))
	_coins_label.text = str(GameState.data["coins"])
	_level_label.text = "дружба %d" % GameState.friendship_level()
	_comfort_label.text = "Уют: %d" % GameState.comfort()
	if GameState.data["sleeping"] != (_action_btns["sleep"].text == "Разбудить"):
		_refresh_buttons()


func _refresh_buttons() -> void:
	var sleeping: bool = GameState.data["sleeping"]
	_action_btns["sleep"].text = "Разбудить" if sleeping else "Спать"
	for id in _action_btns:
		_action_btns[id].disabled = busy
	var tier := int(GameState.data["house"])
	_home_btn.visible = tier >= 2
	_home_btn.text = "Во двор" if ws.interior else "Войти"
	_home_btn.icon = Art.scaled("ui/act_tree" if ws.interior else "ui/act_home", 2)
	_music_btn.modulate = Color.WHITE if GameState.settings["music"] else Color(1, 1, 1, 0.45)


func _process(delta: float) -> void:
	_time_label.text = "%s · %s" % [TimeWeather.time_text(), TimeWeather.weather_name()]
	if GameState.data["sleeping"]:
		_zzz_t += delta
		if _zzz_t > 1.3:
			_zzz_t = 0.0
			ws.float_sprite("fx/zzz", ws.pet.head() + Vector2(4, 0), 14.0, 1.4, 6.0)


# ------------------------------------------------------------ сообщения
func toast(text: String) -> void:
	_toast_queue.append(text)
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	_toast.text = _toast_queue.pop_front()
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_next_toast)


func _float_text(text: String, world_pos: Vector2, col: Color) -> void:
	var l := UIKit.label(text, 14, col, 5)
	l.position = world_pos * 2.0 + Vector2(10, -16)
	_ui.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 26.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------ события
func _on_coins(_total: int, delta: int) -> void:
	_update_hud()
	if delta > 0:
		ws.float_sprite("fx/coin", ws.pet.head() + Vector2(-8, 0), 18.0, 1.0)
		_float_text("+%d" % delta, ws.pet.head() + Vector2(-8, 0), Color("ffe08a"))
		Audio.play("sfx_coin", 0.04, 0.45)


func _on_state() -> void:
	ws.refresh()
	_update_hud()
	_refresh_buttons()


func _on_woke() -> void:
	ws.pet.set_sleeping(false)
	ws.pet.happy_jump(2)
	toast("Сон окончен — сил снова полно!")
	Audio.play(Catalog.PETS[GameState.pet_type()]["sound"], 0.05, 0.7)
	_refresh_buttons()


func _on_friendship(level: int) -> void:
	toast("Дружба крепнет! Уровень %d" % level)
	Audio.play("sfx_levelup", 0.0, 0.8)
	for i in 5:
		ws.float_sprite("fx/heart", ws.pet.head() + Vector2(randf_range(-10, 10), randf_range(-4, 4)), 22.0, 1.3, randf_range(-8, 8))


func _on_weather(w: String) -> void:
	toast(WEATHER_TOASTS.get(w, ""))


# ------------------------------------------------------------ действия
func act(kind: String) -> void:
	if busy or is_instance_valid(_overlay):
		return
	var r := GameState.do_action(kind)
	if not r["ok"]:
		toast(r["msg"])
		Audio.play("sfx_error", 0.02, 0.7)
		return
	busy = true
	_refresh_buttons()
	match kind:
		"feed":
			await _anim_feed()
		"play":
			await _anim_play()
		"wash":
			await _anim_wash()
		"sleep":
			await _anim_sleep(r.get("woke", false))
		"pet":
			await _anim_pet()
	busy = false
	_refresh_buttons()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _anim_feed() -> void:
	var pet = ws.pet
	ws.character.hop()
	if pet.type == "fish":
		for i in 6:
			var x := randf_range(-6.0, 6.0)
			ws.drop_sprite("fx/crumb", pet.position + Vector2(x, -30), pet.position + Vector2(x * 0.5, -14 - randf() * 4.0), 0.8)
			await _wait(0.08)
	else:
		var side := -9.0 if pet.face_left else 9.0
		ws.temp_sprite("fx/food_bowl", pet.position + Vector2(side, 2), 1.8)
	pet.play_eat(1.6)
	Audio.play("sfx_eat")
	for i in 4:
		await _wait(0.35)
		ws.float_sprite("fx/crumb", pet.head() + Vector2(randf_range(-4, 4), 6), 5.0, 0.4, randf_range(-5, 5))
	await _wait(0.3)
	ws.float_sprite("fx/heart", pet.head(), 14.0)


func _anim_play() -> void:
	var pet = ws.pet
	var ch = ws.character
	Audio.play("sfx_play")
	match pet.type:
		"dog", "cat":
			ch.hop()
			var tw: Tween = ws.arc_sprite("fx/ball", ch.position + Vector2(6, -12), pet.position + Vector2(0, -4), 26.0, 0.55)
			await tw.finished
			pet.happy_jump(2)
			Audio.play(Catalog.PETS[pet.type]["sound"], 0.08, 0.7)
			await _wait(0.5)
			tw = ws.arc_sprite("fx/ball", pet.position + Vector2(0, -6), ch.position + Vector2(6, -12), 20.0, 0.5)
			await tw.finished
			ch.hop()
		"parrot":
			ch.hop(4.0, 2)
			for i in 4:
				ws.float_sprite("fx/note", pet.head() + Vector2(randf_range(-6, 6), 0), 20.0, 1.2, randf_range(-8, 8))
				ws.float_sprite("fx/note", ch.position + Vector2(0, -28), 16.0, 1.2, randf_range(-6, 6))
				if i % 2 == 0:
					pet.happy_jump(1)
				await _wait(0.3)
			Audio.play("pet_parrot", 0.1, 0.7)
		"fish":
			ch.hop()
			for i in 8:
				ws.float_sprite("fx/bubble", pet.position + Vector2(randf_range(-6, 6), -14), 14.0, 0.9, randf_range(-2, 2))
				await _wait(0.1)
			pet.happy_jump(2)
			Audio.play("pet_fish", 0.1, 0.7)
	await _wait(0.3)


func _anim_wash() -> void:
	var pet = ws.pet
	Audio.play("sfx_wash")
	for i in 12:
		ws.float_sprite("fx/bubble", pet.position + Vector2(randf_range(-10, 10), randf_range(-16, -2)), randf_range(8, 16), 0.9, randf_range(-4, 4))
		if i % 3 == 0:
			ws.drop_sprite("fx/drop", pet.position + Vector2(randf_range(-8, 8), -24), pet.position + Vector2(randf_range(-8, 8), 0), 0.5)
		await _wait(0.07)
	pet.shake()
	await _wait(0.55)
	for i in 3:
		ws.float_sprite("fx/sparkle", pet.head() + Vector2(randf_range(-10, 10), randf_range(-4, 8)), 8.0, 0.7)
	await _wait(0.2)


func _anim_sleep(woke: bool) -> void:
	var pet = ws.pet
	if woke:
		pet.set_sleeping(false)
		pet.happy_jump(1)
		toast("Доброе утро!")
		await _wait(0.4)
		return
	pet.set_sleeping(true)
	Audio.play("sfx_sleep")
	_zzz_t = 1.0
	await _wait(0.5)


func _anim_pet() -> void:
	var pet = ws.pet
	Audio.play("sfx_pet", 0.05, 0.8)
	for i in 3:
		ws.float_sprite("fx/heart", pet.head() + Vector2(randf_range(-6, 6), 0), 18.0, 1.1, randf_range(-5, 5))
		await _wait(0.12)
	if not GameState.data["sleeping"]:
		pet.happy_jump(1)
		Audio.play(Catalog.PETS[pet.type]["sound"], 0.08, 0.5)
	await _wait(0.2)


# ------------------------------------------------------------ окна и переключатели
func open_shop() -> void:
	if is_instance_valid(_overlay):
		return
	var s := Shop.new()
	s.closed.connect(_on_overlay_closed)
	_overlay = s
	_ui.add_child(s)


func open_settings() -> void:
	if is_instance_valid(_overlay):
		return
	var s := SettingsPanel.new()
	s.in_game = true
	s.closed.connect(_on_overlay_closed)
	_overlay = s
	_ui.add_child(s)


func _on_overlay_closed() -> void:
	_overlay = null
	_refresh_buttons()


func toggle_interior() -> void:
	if int(GameState.data["house"]) < 2 or busy:
		return
	ws.set_interior(not ws.interior)
	GameState.data["interior"] = ws.interior
	_refresh_buttons()


func toggle_music() -> void:
	Audio.set_music_enabled(not GameState.settings["music"])
	_refresh_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if is_instance_valid(_overlay):
			if event.keycode == KEY_ESCAPE or (event.keycode == KEY_B and _overlay is Shop):
				_overlay.close()
				get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_1, KEY_KP_1:
				act("feed")
			KEY_2, KEY_KP_2:
				act("play")
			KEY_3, KEY_KP_3:
				act("wash")
			KEY_4, KEY_KP_4:
				act("sleep")
			KEY_5, KEY_KP_5:
				act("pet")
			KEY_B:
				open_shop()
			KEY_H:
				toggle_interior()
			KEY_M:
				toggle_music()
			KEY_ESCAPE:
				open_settings()
			KEY_F2:
				if OS.is_debug_build():
					TimeWeather.cycle_weather()
			KEY_F3:
				if OS.is_debug_build():
					TimeWeather.skip_hour()
					toast("Время: " + TimeWeather.time_text())
			KEY_F4:
				if OS.is_debug_build():
					GameState.add_coins(100)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(_overlay):
			return
		var p: Vector2 = ws.world.get_local_mouse_position()
		if ws.pet.hit(p):
			act("pet")
		elif ws.character.hit(p):
			ws.character.hop(5.0, 2)
			Audio.play("sfx_click", 0.1, 0.5)
