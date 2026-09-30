extends Node
## Экран создания персонажа.

const WorldScene = preload("res://scripts/world/world_scene.gd")
const CharacterView = preload("res://scripts/world/character_view.gd")

const BOY_NAMES := ["Миша", "Тёма", "Ваня", "Лёва", "Саша", "Костя"]
const GIRL_NAMES := ["Аня", "Соня", "Маша", "Лиза", "Ева", "Варя"]

var p := {"gender": 0, "hair_style": 0, "hair_color": 0, "eye_color": 0, "skin": 1, "name": ""}
var ws: Node
var _ui: Control
var _preview: Node2D
var _opts: VBoxContainer
var _name_edit: LineEdit


func _ready() -> void:
	ws = WorldScene.new()
	ws.show_house = false
	add_child(ws)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = UIKit.root_control()
	layer.add_child(_ui)

	var header := UIKit.label("Создай своего героя", 24, Color("fff1c9"), 8)
	header.position = Vector2(20, 10)
	_ui.add_child(header)

	# превью
	var prev_panel := PanelContainer.new()
	prev_panel.position = Vector2(24, 52)
	prev_panel.custom_minimum_size = Vector2(196, 250)
	_ui.add_child(prev_panel)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(180, 234)
	prev_panel.add_child(holder)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color("c9e3b0")
	floor_rect.position = Vector2(0, 196)
	floor_rect.size = Vector2(180, 38)
	holder.add_child(floor_rect)
	_preview = CharacterView.new()
	_preview.scale = Vector2(7, 7)
	_preview.position = Vector2(90, 214)
	holder.add_child(_preview)

	# настройки
	var panel := PanelContainer.new()
	panel.position = Vector2(236, 52)
	panel.custom_minimum_size = Vector2(380, 250)
	_ui.add_child(panel)
	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 5)
	panel.add_child(_opts)

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(236, 312)
	bottom.custom_minimum_size = Vector2(380, 0)
	bottom.add_theme_constant_override("separation", 8)
	_ui.add_child(bottom)
	bottom.add_child(UIKit.button("← Назад", "", func(): GameState.screen_requested.emit("title")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	bottom.add_child(UIKit.button("Случайно", "", _randomize))
	bottom.add_child(UIKit.button("Далее →", "", _next))

	_randomize()


func _randomize() -> void:
	p["gender"] = randi() % 2
	var girl_styles := [1, 2, 3, 4]
	var boy_styles := [0, 5, 3]
	p["hair_style"] = (girl_styles if p["gender"] == 1 else boy_styles).pick_random()
	p["hair_color"] = randi() % Catalog.HAIR_COLORS.size()
	p["eye_color"] = randi() % Catalog.EYE_COLORS.size()
	p["skin"] = randi() % Catalog.SKIN_TONES.size()
	_rebuild()


func _rebuild() -> void:
	var typed_name := _name_edit.text if _name_edit else ""
	for c in _opts.get_children():
		c.queue_free()
	_opts.add_child(_arrow_row("Пол", Catalog.GENDER_NAMES, "gender"))
	_opts.add_child(_arrow_row("Причёска", Catalog.HAIR_STYLE_NAMES, "hair_style"))
	_opts.add_child(_swatch_row("Цвет волос", Catalog.HAIR_COLORS, "hair_color"))
	_opts.add_child(_swatch_row("Цвет глаз", Catalog.EYE_COLORS, "eye_color"))
	_opts.add_child(_swatch_row("Кожа", Catalog.SKIN_TONES, "skin"))
	var row := HBoxContainer.new()
	var l := UIKit.label("Имя", 14)
	l.custom_minimum_size = Vector2(100, 0)
	row.add_child(l)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 12
	_name_edit.placeholder_text = "Как тебя зовут?"
	_name_edit.text = typed_name
	_name_edit.custom_minimum_size = Vector2(200, 28)
	row.add_child(_name_edit)
	_opts.add_child(row)
	_preview.setup(p)


func _arrow_row(title: String, names: Array, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := UIKit.label(title, 14)
	l.custom_minimum_size = Vector2(100, 0)
	row.add_child(l)
	row.add_child(UIKit.button(" < ", "", func(): _shift(key, -1, names.size())))
	var v := UIKit.label(names[int(p[key])], 14)
	v.custom_minimum_size = Vector2(110, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(v)
	row.add_child(UIKit.button(" > ", "", func(): _shift(key, 1, names.size())))
	return row


func _swatch_row(title: String, colors: Array, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var l := UIKit.label(title, 14)
	l.custom_minimum_size = Vector2(100, 0)
	row.add_child(l)
	for i in colors.size():
		var idx := i
		row.add_child(UIKit.swatch(colors[i], int(p[key]) == i, func(): _pick(key, idx)))
	return row


func _shift(key: String, d: int, count: int) -> void:
	p[key] = (int(p[key]) + d + count) % count
	_rebuild()


func _pick(key: String, idx: int) -> void:
	p[key] = idx
	_rebuild()


func _next() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = (GIRL_NAMES if p["gender"] == 1 else BOY_NAMES).pick_random()
	p["name"] = n
	GameState.pending_player = p.duplicate()
	GameState.screen_requested.emit("pet_select")
