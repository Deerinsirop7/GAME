extends Node
## Выбор питомца и его имени.

const WorldScene = preload("res://scripts/world/world_scene.gd")
const PetView = preload("res://scripts/world/pet_view.gd")

var selected := "dog"
var ws: Node
var _ui: Control
var _cards := {}
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
	header.position = Vector2(20, 10)
	_ui.add_child(header)

	var row := HBoxContainer.new()
	row.position = Vector2(36, 56)
	row.add_theme_constant_override("separation", 12)
	_ui.add_child(row)
	for t in Catalog.PET_ORDER:
		var card := Button.new()
		card.custom_minimum_size = Vector2(132, 160)
		card.focus_mode = Control.FOCUS_NONE
		var type_id: String = t
		card.pressed.connect(func(): _select(type_id))
		row.add_child(card)
		var pv := PetView.new()
		pv.setup(t)
		pv.can_walk = false
		pv.scale = Vector2(4, 4) if t != "fish" else Vector2(3, 3)
		pv.position = Vector2(66, 128)
		card.add_child(pv)
		var l := UIKit.label(Catalog.PETS[t]["name"], 16)
		l.position = Vector2(0, 132)
		l.size = Vector2(132, 24)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(l)
		_cards[t] = card

	var bottom := PanelContainer.new()
	bottom.position = Vector2(36, 236)
	bottom.custom_minimum_size = Vector2(564, 0)
	_ui.add_child(bottom)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bottom.add_child(h)
	h.add_child(UIKit.label("Имя питомца:", 15))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 12
	_name_edit.custom_minimum_size = Vector2(180, 28)
	_name_edit.text_changed.connect(func(_t): _auto_name = false)
	h.add_child(_name_edit)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UIKit.button("← Назад", "", func(): GameState.screen_requested.emit("creator")))
	h.add_child(UIKit.button("Начать!", "", _start))

	var tip := UIKit.label("Питомец не заболеет и не убежит — просто заботься о нём, когда захочется.", 13, Color.WHITE, 5)
	tip.position = Vector2(36, 290)
	_ui.add_child(tip)
	_select("dog")


func _select(t: String) -> void:
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
		_auto_name = true
	Audio.play(Catalog.PETS[t]["sound"], 0.05, 0.7)


func _start() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = Catalog.PETS[selected]["default"]
	var player := GameState.pending_player
	if player.is_empty():
		player = {"gender": 0, "hair_style": 0, "hair_color": 0, "eye_color": 0, "skin": 1, "name": "Миша"}
	GameState.new_game(player, {"type": selected, "name": n})
	GameState.screen_requested.emit("home")
