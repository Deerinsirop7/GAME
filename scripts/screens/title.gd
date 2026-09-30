extends Node
## Титульный экран.

const WorldScene = preload("res://scripts/world/world_scene.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

var ws: Node
var _ui: Control
var _new_btn: Button
var _confirm_new := false


func _ready() -> void:
	if GameState.data.is_empty():
		GameState.load_game()
	ws = WorldScene.new()
	add_child(ws)
	if not GameState.data.is_empty():
		ws.add_actors(GameState.data["player"], GameState.pet_type())
		ws.pet.can_walk = true

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = UIKit.root_control()
	layer.add_child(_ui)

	var col := VBoxContainer.new()
	col.position = Vector2(320 - 150, 34)
	col.custom_minimum_size = Vector2(300, 0)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 6)
	_ui.add_child(col)

	var title := UIKit.label("Pixel Pet", 44, Color("fff1c9"), 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UIKit.label("уютный домик для тебя и питомца", 15, Color.WHITE, 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.custom_minimum_size = Vector2(200, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(buttons)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	buttons.add_child(spacer)
	if not GameState.data.is_empty():
		var cont := UIKit.button("Продолжить", "", _on_continue)
		buttons.add_child(cont)
	_new_btn = UIKit.button("Новая игра", "", _on_new)
	buttons.add_child(_new_btn)
	buttons.add_child(UIKit.button("Настройки", "", _on_settings))
	buttons.add_child(UIKit.button("Выход", "", func(): get_tree().quit()))

	var hint := UIKit.label("F11 — полный экран", 11, Color.WHITE, 4)
	hint.position = Vector2(8, 340)
	_ui.add_child(hint)


func _on_continue() -> void:
	GameState.screen_requested.emit("home")


func _on_new() -> void:
	if GameState.has_save() and not _confirm_new:
		_confirm_new = true
		_new_btn.text = "Точно? Прогресс сотрётся"
		return
	GameState.delete_save()
	GameState.screen_requested.emit("creator")


func _on_settings() -> void:
	var p := SettingsPanel.new()
	p.in_game = false
	_ui.add_child(p)
