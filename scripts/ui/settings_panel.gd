extends Control
## Окно настроек (и меню паузы, если in_game = true).

signal closed


var in_game := true
var _save_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.dimmer())
	var panel := PanelContainer.new()
	panel.position = Vector2(160, 16)
	panel.custom_minimum_size = Vector2(320, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var title := UIKit.label("Меню" if in_game else "Настройки", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var s: Dictionary = GameState.settings
	v.add_child(_check("Музыка", s["music"], _on_music))
	v.add_child(_slider("Громкость музыки", s["music_volume"], _on_music_volume))
	v.add_child(_slider("Громкость звуков", s["sfx_volume"], _on_sfx_volume))
	v.add_child(_check("Полный экран (F11)", s["fullscreen"], _on_fullscreen))
	v.add_child(_check("Быстрое время: 1 час = 1 минута", s["fast_time"], _on_fast_time))

	var help := UIKit.label("1–5 — действия · B — магазин · H — дом/двор\nM — музыка · Esc — меню · клик по питомцу — погладить", 11, Color("5a4a66"))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	if in_game:
		_save_btn = UIKit.button("Сохранить", "", _on_save)
		row.add_child(_save_btn)
		row.add_child(UIKit.button("В главное меню", "", _on_menu))
	row.add_child(UIKit.button("Закрыть", "", close))


func _check(text: String, value: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	c.toggled.connect(func(_on: bool): Audio.play("sfx_click", 0.02, 0.6))
	return c


func _slider(text: String, value: float, cb: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(UIKit.label(text, 13))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.focus_mode = Control.FOCUS_NONE
	sl.custom_minimum_size = Vector2(280, 18)
	sl.value_changed.connect(cb)
	sl.drag_ended.connect(func(_changed: bool): Audio.play("sfx_click", 0.02, 0.8))
	box.add_child(sl)
	return box


func _on_music(on: bool) -> void:
	Audio.set_music_enabled(on)


func _on_music_volume(val: float) -> void:
	GameState.settings["music_volume"] = val
	Audio.update_music()


func _on_sfx_volume(val: float) -> void:
	GameState.settings["sfx_volume"] = val


func _on_fullscreen(on: bool) -> void:
	GameState.settings["fullscreen"] = on
	GameState.apply_display()


func _on_fast_time(on: bool) -> void:
	GameState.settings["fast_time"] = on


func close() -> void:
	GameState.save_settings()
	closed.emit()
	queue_free()


func _on_save() -> void:
	GameState.save_game()
	_save_btn.text = "Сохранено!"


func _on_menu() -> void:
	GameState.save_settings()
	GameState.save_game()
	GameState.screen_requested.emit("title")
