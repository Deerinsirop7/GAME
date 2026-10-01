extends Node
## Основной экран. Курсор — рука игрока: гладить, кормить, мыть, играть.

const WorldScene = preload("res://scripts/world/world_scene.gd")
const NeedBar = preload("res://scripts/ui/need_bar.gd")
const Shop = preload("res://scripts/ui/shop.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

const TOY_CURSOR := {"dog": "fx/ball", "cat": "fx/cur_feather", "parrot": "fx/cur_rattle", "fish": "fx/cur_finger"}
const HOTSPOT := {
	"fx/cur_hand": Vector2(6, 5), "fx/cur_hand_pet": Vector2(7, 6), "fx/cur_scoop": Vector2(3, 8),
	"fx/cur_sponge": Vector2(7, 5), "fx/ball": Vector2(5, 5), "fx/cur_feather": Vector2(1, 1),
	"fx/cur_rattle": Vector2(6, 8), "fx/cur_finger": Vector2(3, 1),
}
const TOOL_HINTS := {
	"hand": "Зажми кнопку мыши и води по питомцу — погладить",
	"food": "Кликни по миске, чтобы насыпать корм",
	"sponge": "Три питомца губкой, потом отпусти — он отряхнётся",
}
const TOY_HINTS := {
	"dog": "Зажми мячик и брось — собака принесёт его обратно",
	"cat": "Води пёрышком у самой земли — кот начнёт охоту",
	"parrot": "Зажми и потряси колокольчиком рядом с попугаем",
	"fish": "Води пальцем по стеклу — рыбка поплывёт следом",
}
const NEED_COLORS := {
	"hunger": Color("e8a05a"), "joy": Color("ec7f9c"), "energy": Color("f2cd5a"), "clean": Color("6cb6e6"),
}
const WEATHER_TOASTS := {
	"sunny": "Выглянуло солнышко", "cloudy": "Набежали облака", "rain": "Пошёл дождь",
}

var ws: Node
var tool := "hand"
var _ui: Control
var _bars := {}
var _level_label: Label
var _coins_label: Label
var _time_label: Label
var _comfort_label: Label
var _tool_btns := {}
var _sleep_btn: Button
var _home_btn: Button
var _music_btn: Button
var _toast: Label
var _toast_queue: Array[String] = []
var _toast_busy := false
var _overlay = null
var _cursor: Sprite2D
var _hinted := {}

var _pressed := false
var _last_m := Vector2.ZERO
var _stroke_acc := 0.0
var _scrub_acc := 0.0
var _toy_acc := 0.0
var _voice_cd := 0.0
var _scrub_cd := 0.0
var _bell_cd := 0.0
var _pounce_cd := 0.0
var _tired_cd := 0.0
var _zzz_t := 0.0
# мячик для собаки
var _ball: Sprite2D = null
var _ball_state := "hand"   # hand, held, flying, ground, carried
var _ball_vel := Vector2.ZERO
var _ball_hist: Array = []


func _ready() -> void:
	ws = WorldScene.new()
	add_child(ws)
	ws.add_pet(GameState.pet_type(), int(GameState.data["pet"]["coat"]))
	ws.pet.show_emotes = true
	ws.pet.bite.connect(_on_bite)
	if GameState.data["interior"]:
		ws.set_interior(true)
	GameState.playing = true
	Audio.ambient_muffle = 1.0 if ws.interior else 0.0

	_build_ui()
	_build_cursor()
	GameState.needs_changed.connect(_update_hud)
	GameState.coins_changed.connect(_on_coins)
	GameState.state_changed.connect(_on_state)
	GameState.pet_woke.connect(_on_woke)
	GameState.sleep_changed.connect(_on_sleep_changed)
	GameState.friendship_up.connect(_on_friendship)
	TimeWeather.weather_changed.connect(_on_weather)
	_update_hud()
	_refresh_buttons()

	var rep := GameState.offline_report
	if not rep.is_empty() and int(rep["minutes"]) > 0:
		toast("С возвращением! Тебя не было %s." % _minutes_text(int(rep["minutes"])))
		if int(rep["coins"]) > 0:
			toast("За это время накопилось монет: %d" % int(rep["coins"]))
		GameState.offline_report = {}
	elif int(GameState.data["total_coins"]) == 0:
		toast("Добро пожаловать домой!")
		toast(TOOL_HINTS["hand"])
		_hinted["hand"] = true
	Audio.play(Catalog.PETS[GameState.pet_type()]["sound"], 0.05, 0.6)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	GameState.playing = false
	GameState.save_game()
	Audio.ambient_muffle = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and _cursor:
		_cursor.visible = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER and _cursor:
		_cursor.visible = true


func _minutes_text(m: int) -> String:
	if m >= 60:
		return "%d ч %d мин" % [m / 60, m % 60]
	return "%d мин" % m


# ------------------------------------------------------------ интерфейс
func _panel_box() -> StyleBoxFlat:
	return UIKit.box(Color(1, 0.965, 0.89, 0.92), UIKit.DARK, 2, 4, 6)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = UIKit.root_control()
	layer.add_child(_ui)

	var top := HBoxContainer.new()
	top.position = Vector2(6, 6)
	top.custom_minimum_size = Vector2(628, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(top)

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _panel_box())
	top.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 0)
	left.add_child(lv)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	lv.add_child(name_row)
	name_row.add_child(UIKit.label(GameState.pet_name(), 16))
	name_row.add_child(UIKit.icon("fx/heart", 2.0))
	_level_label = UIKit.label("", 13, Color("8a5a5a"))
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
	right.add_theme_stylebox_override("panel", _panel_box())
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
	_comfort_label = UIKit.label("", 13, Color("8a5a5a"))
	_comfort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(_comfort_label)

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

	var pt := GameState.pet_type()
	var tools := [
		["hand", "Гладить", "fx/cur_hand"],
		["food", "Корм", "fx/cur_scoop"],
		["sponge", "Мыть", "fx/cur_sponge"],
		["toy", Catalog.PETS[pt]["toy"], TOY_CURSOR[pt]],
	]
	var i := 1
	for t in tools:
		var id: String = t[0]
		var b := _bar_button(t[1], t[2], func(): set_tool(id))
		b.tooltip_text = "%s  [%d]" % [t[1], i]
		bar_box.add_child(b)
		_tool_btns[id] = b
		i += 1
	_sleep_btn = _bar_button("Спать", "ui/act_sleep", _toggle_sleep)
	_sleep_btn.tooltip_text = "Уложить спать / разбудить  [5]"
	bar_box.add_child(_sleep_btn)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	bar_box.add_child(gap)
	var shop := _bar_button("Магазин", "ui/act_shop", open_shop)
	shop.tooltip_text = "Магазин  [B]"
	bar_box.add_child(shop)
	_home_btn = _bar_button("В дом", "ui/act_home", toggle_interior)
	_home_btn.tooltip_text = "Дом / двор  [H]"
	bar_box.add_child(_home_btn)
	_music_btn = _bar_button("Музыка", "ui/act_music", toggle_music)
	_music_btn.tooltip_text = "Музыка  [M]"
	bar_box.add_child(_music_btn)
	var menu := _bar_button("Меню", "ui/act_gear", open_settings)
	menu.tooltip_text = "Настройки  [Esc]"
	bar_box.add_child(menu)

	_toast = UIKit.label("", 16, Color.WHITE, 6)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 96
	_toast.offset_bottom = 124
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_ui.add_child(_toast)


func _bar_button(text: String, icon_path: String, cb: Callable) -> Button:
	var b := UIKit.button(text, icon_path, cb, true)
	b.custom_minimum_size = Vector2(62, 56)
	b.add_theme_font_size_override("font_size", 12)
	return b


func _build_cursor() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_cursor = Sprite2D.new()
	_cursor.centered = false
	_cursor.scale = Vector2(2, 2)
	layer.add_child(_cursor)


func _cursor_tex() -> String:
	match tool:
		"hand":
			return "fx/cur_hand_pet" if _pressed else "fx/cur_hand"
		"food":
			return "fx/cur_scoop"
		"sponge":
			return "fx/cur_sponge"
		"toy":
			if GameState.pet_type() == "dog" and _ball_state != "hand":
				return "fx/cur_hand"
			return TOY_CURSOR[GameState.pet_type()]
	return "fx/cur_hand"


func _update_cursor() -> void:
	var tex_name := _cursor_tex()
	if is_instance_valid(_overlay):
		tex_name = "fx/cur_hand"
	_cursor.texture = Art.tex(tex_name)
	var hot: Vector2 = HOTSPOT.get(tex_name, Vector2.ZERO)
	_cursor.offset = -hot
	_cursor.position = _ui.get_local_mouse_position()


func _update_hud() -> void:
	var n: Dictionary = GameState.data["needs"]
	for k in _bars:
		_bars[k].set_value(float(n[k]))
	_coins_label.text = str(GameState.data["coins"])
	_level_label.text = "дружба %d" % GameState.friendship_level()
	_comfort_label.text = "Уют: %d" % GameState.comfort()
	ws.update_bowl()


func _refresh_buttons() -> void:
	for id in _tool_btns:
		var b: Button = _tool_btns[id]
		if id == tool:
			b.add_theme_stylebox_override("normal", UIKit.box(UIKit.ACCENT))
			b.add_theme_stylebox_override("hover", UIKit.box(UIKit.ACCENT.lightened(0.15)))
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
	_sleep_btn.text = "Разбудить" if GameState.data["sleeping"] else "Спать"
	_home_btn.text = "Во двор" if ws.interior else "В дом"
	_home_btn.icon = Art.scaled("ui/act_tree" if ws.interior else "ui/act_home", 2)
	_music_btn.modulate = Color.WHITE if GameState.settings["music"] else Color(1, 1, 1, 0.45)


func set_tool(id: String) -> void:
	_reset_toys()
	tool = id
	if not _hinted.has(id):
		_hinted[id] = true
		var pt := GameState.pet_type()
		if id == "toy":
			toast(TOY_HINTS[pt])
		elif id == "food" and pt == "fish":
			toast("Кликни по аквариуму, чтобы насыпать хлопья")
		else:
			toast(TOOL_HINTS[id])
	_refresh_buttons()


func _reset_toys() -> void:
	if _ball:
		_ball.queue_free()
		_ball = null
	_ball_state = "hand"
	var pet = ws.pet
	pet.set_carry(false)
	pet.external = false
	pet.follow_point = Vector2.INF
	if pet.state == "walk":
		pet.stop()


# ------------------------------------------------------------ сообщения
func toast(text: String) -> void:
	if text == "":
		return
	if _toast_queue.has(text) or (_toast_busy and _toast.text == text):
		return
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
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_next_toast)


func _float_text(text: String, world_pos: Vector2, col: Color) -> void:
	var l := UIKit.label(text, 14, col, 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = world_pos * 2.0 + Vector2(10, -16)
	_ui.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 26.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------ события игры
func _on_coins(_total: int, delta: int) -> void:
	_update_hud()
	if delta > 0:
		ws.float_sprite("fx/coin", ws.pet.head() + Vector2(-8, 0), 18.0, 1.0)
		_float_text("+%d" % delta, ws.pet.head() + Vector2(-8, 0), Color("ffe08a"))
		Audio.play("sfx_coin", 0.04, 0.4)


func _on_state() -> void:
	ws.refresh()
	_update_hud()
	_refresh_buttons()


func _on_woke() -> void:
	toast("Сон окончен — сил снова полно!")
	Audio.play(Catalog.PETS[GameState.pet_type()]["sound"], 0.05, 0.7)


func _on_sleep_changed(sleeping: bool) -> void:
	if sleeping:
		_reset_toys()
	else:
		ws.pet.happy_jump(1)
	_refresh_buttons()


func _on_friendship(level: int) -> void:
	toast("Дружба крепнет! Уровень %d" % level)
	Audio.play("sfx_levelup", 0.0, 0.7)
	for i in 5:
		ws.float_sprite("fx/heart", ws.pet.head() + Vector2(randf_range(-10, 10), randf_range(-4, 4)), 22.0, 1.3, randf_range(-8, 8))


func _on_weather(w: String) -> void:
	toast(WEATHER_TOASTS.get(w, ""))


func _on_bite() -> void:
	Audio.play("sfx_eat", 0.12, 0.45)
	if GameState.pet_type() == "fish":
		ws.float_sprite("fx/bubble", ws.pet.center() + Vector2(4, -2), 10.0, 0.8)
	else:
		var bp: Vector2 = ws.bowl_pos()
		for i in 2:
			ws.float_sprite("fx/crumb", bp + Vector2(randf_range(-5, 5), -6), 5.0, 0.4, randf_range(-6, 6))


# ------------------------------------------------------------ кадр
func _process(delta: float) -> void:
	_update_cursor()
	_voice_cd -= delta
	_scrub_cd -= delta
	_bell_cd -= delta
	_pounce_cd -= delta
	_tired_cd -= delta
	_time_label.text = "%s · %s" % [TimeWeather.time_text(), TimeWeather.weather_name()]
	if GameState.data["sleeping"]:
		_zzz_t += delta
		if _zzz_t > 1.4:
			_zzz_t = 0.0
			ws.float_sprite("fx/zzz", ws.pet.head() + Vector2(4, 6), 14.0, 1.4, 6.0)
	var m: Vector2 = ws.world.get_local_mouse_position()
	var mv := m - _last_m
	_last_m = m
	if _pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_release()
	if tool == "toy" and GameState.pet_type() == "dog":
		_ball_process(delta, m)
	if is_instance_valid(_overlay):
		return
	var pet = ws.pet
	match tool:
		"hand":
			if _pressed and mv.length() > 0.0 and pet.hit(m):
				_stroke(mv.length())
			if pet.type == "fish":
				pet.follow_point = m if (_pressed and pet.hit(m)) else Vector2.INF
		"sponge":
			if _pressed and mv.length() > 0.0 and pet.hit(m):
				_scrub(mv.length(), m)
		"toy":
			_toy_process(m, mv)


func _too_tired() -> void:
	if _tired_cd <= 0.0:
		_tired_cd = 4.0
		toast("Нет сил играть — пора отдохнуть")


# ------------------------------------------------------------ рука: гладить
func _stroke(length: float) -> void:
	var pet = ws.pet
	var sleeping: bool = GameState.data["sleeping"]
	_stroke_acc += length
	pet.pet_happy(0.3)
	if _stroke_acc < 26.0:
		return
	_stroke_acc -= 26.0
	GameState.stroke(1.0 if sleeping else 2.5)
	ws.float_sprite("fx/heart", pet.head() + Vector2(randf_range(-5, 5), 0), 16.0, 1.0, randf_range(-6, 6))
	if _voice_cd <= 0.0 and not sleeping:
		match pet.type:
			"cat":
				Audio.play("sfx_purr", 0.05, 0.8)
				_voice_cd = 2.5
			"dog":
				Audio.play("pet_dog", 0.1, 0.35)
				_voice_cd = 4.0
			"parrot":
				Audio.play("pet_parrot", 0.15, 0.45)
				_voice_cd = 3.5
			"fish":
				ws.float_sprite("fx/bubble", pet.center(), 12.0, 0.9)
				_voice_cd = 0.8


# ------------------------------------------------------------ губка: мыть
func _scrub(length: float, m: Vector2) -> void:
	if GameState.data["sleeping"]:
		if _tired_cd <= 0.0:
			_tired_cd = 3.0
			toast("Тсс… питомец спит")
		return
	_scrub_acc += length
	if _scrub_acc < 20.0:
		return
	_scrub_acc -= 20.0
	var pet = ws.pet
	if pet.type == "fish":
		GameState.scrub(4.0)
		ws.float_sprite("fx/sparkle", m + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 6.0, 0.5)
	else:
		pet.add_foam()
		pet.pet_happy(0.2)
		GameState.scrub(3.5)
	if _scrub_cd <= 0.0:
		_scrub_cd = 0.22
		Audio.play("sfx_scrub", 0.15, 0.6)


func _shake_off() -> void:
	var pet = ws.pet
	var c: Vector2 = pet.center()
	pet.clear_foam()
	pet.shake()
	Audio.play("sfx_shake", 0.05, 0.8)
	for i in 6:
		ws.float_sprite("fx/foam", c + Vector2(randf_range(-8, 8), randf_range(-6, 4)), 8.0, 0.5, randf_range(-6, 6))
	for i in 10:
		var dir := Vector2.from_angle(randf_range(PI * 1.05, PI * 1.95))
		ws.drop_sprite("fx/drop", c, c + dir * randf_range(12.0, 24.0) + Vector2(0, 10), 0.45)
	for i in 3:
		ws.float_sprite("fx/sparkle", c + Vector2(randf_range(-10, 10), randf_range(-10, 2)), 8.0, 0.7)


# ------------------------------------------------------------ корм
func _feed_click(m: Vector2) -> void:
	var pet = ws.pet
	if pet.type == "fish":
		if not pet.hit(m):
			toast("Кликни по аквариуму, чтобы насыпать хлопья")
			return
		if GameState.data["sleeping"]:
			toast("Тсс… рыбка спит")
			return
		if float(GameState.data["needs"]["hunger"]) >= 95.0:
			toast("Пока не хочется есть")
			return
		Audio.play("sfx_pour", 0.1, 0.6)
		for i in 3:
			var f := Sprite2D.new()
			f.texture = Art.tex("fx/flake")
			f.position = Vector2(pet.position.x + randf_range(-8.0, 8.0), pet.position.y - 38.0).round()
			ws.fx.add_child(f)
			var tw := f.create_tween()
			tw.tween_property(f, "position:y", pet.position.y - randf_range(14.0, 18.0), 3.0)
			tw.tween_interval(8.0)
			tw.tween_callback(f.queue_free)
			pet.flakes.append(f)
		return
	var bp: Vector2 = ws.bowl_pos()
	if not Rect2(bp + Vector2(-14, -16), Vector2(28, 20)).has_point(m):
		toast("Кликни по миске, чтобы насыпать корм")
		return
	var err := GameState.pour_food()
	if err != "":
		toast(err)
		Audio.play("sfx_error", 0.02, 0.5)
		return
	Audio.play("sfx_pour", 0.08, 0.8)
	for i in 7:
		ws.drop_sprite("fx/kibble", m + Vector2(randf_range(-3, 3), -4), bp + Vector2(randf_range(-6, 6), -4), randf_range(0.25, 0.45))


# ------------------------------------------------------------ игрушки
func _toy_process(m: Vector2, mv: Vector2) -> void:
	var pet = ws.pet
	var sleeping: bool = GameState.data["sleeping"]
	match pet.type:
		"cat":
			if sleeping:
				return
			var gy: float = ws.ground_y()
			var near_ground := m.y > gy - 30.0 and m.y < gy + 6.0
			var in_range := absf(m.x - pet.position.x) < 120.0
			if not near_ground or not in_range:
				if pet.external and pet.state != "pounce":
					pet.external = false
				return
			if not GameState.can_play():
				_too_tired()
				return
			pet.external = true
			var dx: float = m.x - pet.position.x
			if absf(dx) > 22.0:
				if pet.state != "pounce":
					pet.walk_to(m.x - signf(dx) * 16.0, 30.0)
			elif _pounce_cd <= 0.0 and pet.state != "pounce":
				_pounce_cd = 1.3
				pet.pounce_to(m.x)
				Audio.play("sfx_play", 0.1, 0.5)
				if GameState.play(6.0):
					ws.float_sprite("fx/heart", pet.head(), 14.0)
		"parrot":
			if sleeping:
				return
			if _pressed and mv.length() > 0.0 and (m - pet.center()).length() < 40.0:
				_toy_acc += mv.length()
				if _bell_cd <= 0.0:
					_bell_cd = 0.25
					Audio.play("sfx_bell", 0.15, 0.45)
				if _toy_acc >= 110.0:
					_toy_acc = 0.0
					if GameState.play(5.0):
						pet.pet_happy(0.6)
						pet.happy_jump(1)
						for i in 2:
							ws.float_sprite("fx/note", pet.head() + Vector2(randf_range(-6, 6), 0), 18.0, 1.1, randf_range(-8, 8))
						Audio.play("pet_parrot", 0.12, 0.6)
					else:
						_too_tired()
		"fish":
			if not sleeping and pet.hit(m):
				pet.follow_point = m
				_toy_acc += mv.length()
				if _toy_acc >= 80.0:
					_toy_acc = 0.0
					if GameState.play(4.0):
						pet.pet_happy(0.4)
						ws.float_sprite("fx/bubble", pet.center(), 14.0, 0.9)
					else:
						_too_tired()
			else:
				pet.follow_point = Vector2.INF


func _ball_press(m: Vector2) -> void:
	if GameState.data["sleeping"]:
		toast("Тсс… питомец спит")
		return
	if _ball_state == "hand":
		_ball = Sprite2D.new()
		_ball.texture = Art.tex("fx/ball")
		_ball.position = m
		ws.fx.add_child(_ball)
		_ball_state = "held"
		_ball_hist.clear()
	elif _ball_state == "ground" and _ball and _ball.position.distance_to(m) < 12.0:
		_ball_state = "held"
		ws.pet.external = false
		ws.pet.stop()
		_ball_hist.clear()


func _throw_ball() -> void:
	var v := Vector2.ZERO
	if _ball_hist.size() >= 2:
		var a: Array = _ball_hist[0]
		var b: Array = _ball_hist[_ball_hist.size() - 1]
		var dt: float = b[0] - a[0]
		if dt > 0.001:
			v = (b[1] - a[1]) / dt
	_ball_vel = v.limit_length(320.0)
	_ball_state = "flying"


func _ball_process(delta: float, m: Vector2) -> void:
	if _ball == null:
		return
	var pet = ws.pet
	var gy: float = ws.ground_y() - 4.0
	match _ball_state:
		"held":
			_ball.position = m
			var now := Time.get_ticks_msec() / 1000.0
			_ball_hist.append([now, m])
			while _ball_hist.size() > 2 and now - float(_ball_hist[0][0]) > 0.12:
				_ball_hist.pop_front()
		"flying", "ground":
			if _ball_state == "flying":
				_ball_vel.y += 420.0 * delta
				_ball.position += _ball_vel * delta
				_ball.rotation += _ball_vel.x * delta * 0.15
				if _ball.position.x < 8.0 or _ball.position.x > 312.0:
					_ball.position.x = clampf(_ball.position.x, 8.0, 312.0)
					_ball_vel.x = -_ball_vel.x * 0.6
				if _ball.position.y < 4.0:
					_ball.position.y = 4.0
					_ball_vel.y = absf(_ball_vel.y) * 0.5
				if _ball.position.y >= gy:
					_ball.position.y = gy
					if absf(_ball_vel.y) > 50.0:
						_ball_vel.y = -_ball_vel.y * 0.45
						_ball_vel.x *= 0.75
						Audio.play("sfx_bounce", 0.1, 0.5)
					else:
						_ball_vel.y = 0.0
						_ball_vel.x *= pow(0.05, delta)
						if absf(_ball_vel.x) < 3.0:
							_ball_state = "ground"
			if GameState.data["sleeping"]:
				return
			if not GameState.can_play():
				pet.external = false
				_too_tired()
				return
			pet.external = true
			if _ball.position.y > gy - 30.0:
				pet.walk_to(_ball.position.x, 64.0)
			if absf(pet.position.x - _ball.position.x) < 8.0 and _ball.position.y >= gy - 8.0:
				_ball_state = "carried"
				_ball.visible = false
				pet.set_carry(true)
				var rng: Vector2 = pet.walk_range
				pet.walk_to(clampf(m.x, rng.x, rng.y), 44.0)
				Audio.play("sfx_bounce", 0.1, 0.6)
		"carried":
			if pet.state == "idle":
				pet.set_carry(false)
				_ball.queue_free()
				_ball = null
				_ball_state = "hand"
				pet.external = false
				if GameState.play(10.0):
					pet.happy_jump(2)
					Audio.play("pet_dog", 0.08, 0.6)
					for i in 2:
						ws.float_sprite("fx/heart", pet.head() + Vector2(randf_range(-5, 5), 0), 16.0, 1.0, randf_range(-6, 6))
				else:
					_too_tired()


# ------------------------------------------------------------ ввод
func _on_press(m: Vector2) -> void:
	var pet = ws.pet
	match tool:
		"hand":
			if pet.hit(m):
				_stroke(26.0)
		"food":
			_feed_click(m)
		"toy":
			if pet.type == "dog":
				_ball_press(m)


func _on_release() -> void:
	_pressed = false
	match tool:
		"sponge":
			if ws.pet.foam_count() > 0:
				_shake_off()
		"toy":
			if _ball_state == "held":
				_throw_ball()
		"hand":
			ws.pet.follow_point = Vector2.INF


func _toggle_sleep() -> void:
	var err := GameState.toggle_sleep()
	if err != "":
		toast(err)
		Audio.play("sfx_error", 0.02, 0.5)
		return
	if GameState.data["sleeping"]:
		Audio.play("sfx_sleep", 0.0, 0.7)
		_zzz_t = 1.0


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
	_reset_toys()
	ws.set_interior(not ws.interior)
	GameState.data["interior"] = ws.interior
	Audio.ambient_muffle = 1.0 if ws.interior else 0.0
	_refresh_buttons()


func toggle_music() -> void:
	Audio.set_music_enabled(not GameState.settings["music"])
	_refresh_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not is_instance_valid(_overlay):
			_pressed = true
			var m: Vector2 = ws.world.get_local_mouse_position()
			_last_m = m
			_on_press(m)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if is_instance_valid(_overlay):
		if key == KEY_ESCAPE or (key == KEY_B and _overlay is Shop):
			_overlay.close()
			get_viewport().set_input_as_handled()
		return
	match key:
		KEY_1, KEY_KP_1:
			set_tool("hand")
		KEY_2, KEY_KP_2:
			set_tool("food")
		KEY_3, KEY_KP_3:
			set_tool("sponge")
		KEY_4, KEY_KP_4:
			set_tool("toy")
		KEY_5, KEY_KP_5:
			_toggle_sleep()
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
