extends Control
## Магазин: жильё, предметы для двора и для комнаты.

signal closed

const TABS := [["house", "Жильё"], ["out", "Двор"], ["in", "Дом"]]

var _tab := "house"
var _list: VBoxContainer
var _coins: Label
var _tab_btns := {}
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.dimmer())
	var panel := PanelContainer.new()
	panel.position = Vector2(50, 18)
	panel.custom_minimum_size = Vector2(540, 324)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(UIKit.label("Магазин", 20))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UIKit.icon("fx/coin", 2.0))
	_coins = UIKit.label("", 18)
	head.add_child(_coins)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10, 0)
	head.add_child(gap)
	head.add_child(UIKit.button("Закрыть", "", close))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for t in TABS:
		var id: String = t[0]
		var b := UIKit.button(t[1], "", func(): _set_tab(id))
		b.custom_minimum_size = Vector2(100, 0)
		tabs.add_child(b)
		_tab_btns[id] = b

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 238)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)

	GameState.coins_changed.connect(_on_coins)
	_rebuild()


func close() -> void:
	closed.emit()
	queue_free()


func _on_coins(_total: int, _delta: int) -> void:
	_rebuild()


func _set_tab(id: String) -> void:
	_tab = id
	_scroll.scroll_vertical = 0
	_rebuild()


func _rebuild() -> void:
	_coins.text = str(GameState.data["coins"])
	for id in _tab_btns:
		var on: bool = id == _tab
		var b: Button = _tab_btns[id]
		b.add_theme_stylebox_override("normal", UIKit.box(UIKit.ACCENT if on else UIKit.BTN))
	for c in _list.get_children():
		c.queue_free()
	if _tab == "house":
		for tier in range(1, Catalog.HOUSES.size()):
			var h: Dictionary = Catalog.HOUSES[tier]
			var st := GameState.house_status(tier)
			var lock_text := "Сначала: " + str(Catalog.HOUSES[tier - 1]["name"])
			_list.add_child(_row("house/house_%d" % tier, h["name"], h["desc"], int(h["price"]), st, lock_text,
				func(): _buy_house(tier)))
	else:
		for id in Catalog.ITEM_ORDER:
			var it: Dictionary = Catalog.ITEMS[id]
			if it["scene"] != _tab:
				continue
			var st := GameState.item_status(id)
			var lock_text := "Нужен: " + str(Catalog.HOUSES[int(it["req"])]["name"])
			var item_id: String = id
			_list.add_child(_row("items/" + id, it["name"], it["desc"], int(it["price"]), st, lock_text,
				func(): _buy_item(item_id)))


func _row(icon_path: String, title: String, desc: String, price: int, status: String, lock_text: String, cb: Callable) -> Control:
	var row := PanelContainer.new()
	var bg := Color("f3e6c8") if status != "owned" else Color("e3efd2")
	row.add_theme_stylebox_override("panel", UIKit.box(bg, Color("c9b48f"), 2, 3, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	h.add_child(UIKit.icon_fit(icon_path, Vector2(72, 52)))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	h.add_child(mid)
	mid.add_child(UIKit.label(title, 16))
	var d := UIKit.label(desc, 12, Color("5a4a66"))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(250, 0)
	mid.add_child(d)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(130, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(right)
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(price_row)
	price_row.add_child(UIKit.icon("fx/coin", 1.0))
	var price_col := Color("c0392b") if status == "poor" else UIKit.DARK
	price_row.add_child(UIKit.label(str(price), 14, price_col))
	var btn: Button
	match status:
		"owned":
			btn = UIKit.button("Уже есть", "", Callable())
			btn.disabled = true
		"locked":
			btn = UIKit.button("Закрыто", "", Callable())
			btn.disabled = true
			btn.tooltip_text = lock_text
			var l := UIKit.label(lock_text, 11, Color("8a5a7a"))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			right.add_child(l)
		"poor":
			btn = UIKit.button("Купить", "", Callable())
			btn.disabled = true
			btn.tooltip_text = "Не хватает монет"
		_:
			btn = UIKit.button("Купить", "", cb)
	right.add_child(btn)
	return row


func _buy_item(id: String) -> void:
	if GameState.buy_item(id):
		Audio.play("sfx_buy", 0.0, 0.8)
	else:
		Audio.play("sfx_error", 0.0, 0.7)
	_rebuild()


func _buy_house(tier: int) -> void:
	if GameState.buy_house(tier):
		Audio.play("sfx_buy", 0.0, 0.8)
		Audio.play("sfx_levelup", 0.0, 0.6)
	else:
		Audio.play("sfx_error", 0.0, 0.7)
	_rebuild()
