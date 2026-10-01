extends Node
## Выбор питомца, его окраса и имени.

const WorldScene = preload("res://scripts/world/world_scene.gd")
const PetView = preload("res://scripts/world/pet_view.gd")

var selected := "dog"
var coat := 0
var ws: Node
var _ui: Control
var _cards := {}
var _views := {}
var _coat_row: HBoxContainer
var _coat_label: Label
var _name_edit: LineEdit
var _auto_name := true


func _ready() -> void:
	ws = WorldScene.new()
	ws.show_house = false
	add_child(ws)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = UIKit.root_control()
	layer.add_child(_ui)

	var header := UIKit.label("Выбери питомца", 24, Color("fff1c9"), 8)
	header.position = Vector2(20, 8)
	_ui.add_child(header)

	var row := HBoxContainer.new()
	row.position = Vector2(36, 48)
	row.add_theme_constant_override("separation", 12)
	_ui.add_child(row)
	for t in Catalog.PET_ORDER:
		var card := Button.new()
		card.custom_minimum_size = Vector2(132, 150)
		card.focus_mode = Control.FOCUS_NONE
		var type_id: String = t
		card.pressed.connect(func(): _select(type_id))
		row.add_child(card)
		var pv := PetView.new()
		pv.setup(t, 0)
		pv.scale = Vector2(4, 4) if t != "fish" else Vector2(2.5, 2.5)
		pv.position = Vector2(66, 120)
		card.add_child(pv)
		var l := UIKit.label(Catalog.PETS[t]["name"], 16)
		l.position = Vector2(0, 122)
		l.size = Vector2(132, 24)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(l)
		_cards[t] = card
		_views[t] = pv

	var bottom := PanelContainer.new()
	bottom.position = Vector2(36, 210)
	bottom.custom_minimum_size = Vector2(564, 0)
	_ui.add_child(bottom)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	bottom.add_child(v)

	var coat_line := HBoxContainer.new()
	coat_line.add_theme_constant_override("separation", 8)
	v.add_child(coat_line)
	var cl := UIKit.label("Окрас:", 15)
	cl.custom_minimum_size = Vector2(110, 0)
	coat_line.add_child(cl)
	_coat_row = HBoxContainer.new()
	_coat_row.add_theme_constant_override("separation", 6)
	coat_line.add_child(_coat_row)
	_coat_label = UIKit.label("", 14, Color("8a5a5a"))
	coat_line.add_child(_coat_label)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var nl := UIKit.label("Имя питомца:", 15)
	nl.custom_minimum_size = Vector2(110, 0)
	h.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 12
	_name_edit.custom_minimum_size = Vector2(180, 28)
	_name_edit.text_changed.connect(_on_name_typed)
	h.add_child(_name_edit)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UIKit.button("← Назад", "", _back))
	h.add_child(UIKit.button("Начать!", "", _start))

	var tip := UIKit.label("Питомец не заболеет и не убежит — просто заботься о нём, когда захочется.", 13, Color.WHITE, 5)
	tip.position = Vector2(36, 300)
	_ui.add_child(tip)
	_select("dog")


func _on_name_typed(_t: String) -> void:
	_auto_name = false


func _back() -> void:
	GameState.screen_requested.emit("title")


func _select(t: String) -> void:
	if t != selected:
		coat = 0
	selected = t
	for k in _cards:
		var on: bool = k == t
		var b: Button = _cards[k]
		var bg := Color("fff1c9") if on else Color("fff6e3")
		var border := UIKit.ACCENT if on else UIKit.DARK
		var w := 4 if on else 2
		b.add_theme_stylebox_override("normal", UIKit.box(bg, border, w, 4, 0))
		b.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.3), border, w, 4, 0))
		b.add_theme_stylebox_override("pressed", UIKit.box(bg.darkened(0.05), border, w, 4, 0))
	if _auto_name:
		_name_edit.text = Catalog.PETS[t]["default"]
	_build_coats()
	Audio.play(Catalog.PETS[t]["sound"], 0.05, 0.7)


func _build_coats() -> void:
	for c in _coat_row.get_children():
		c.queue_free()
	var colors: Array = Catalog.PETS[selected]["coat_colors"]
	for i in colors.size():
		var idx := i
		_coat_row.add_child(UIKit.swatch(colors[i], i == coat, func(): _pick_coat(idx)))
	_coat_label.text = Catalog.PETS[selected]["coats"][coat]
	_views[selected].setup(selected, coat)


func _pick_coat(i: int) -> void:
	coat = i
	_build_coats()


func _start() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = Catalog.PETS[selected]["default"]
	GameState.new_game({"type": selected, "name": n, "coat": coat})
	GameState.screen_requested.emit("home")
