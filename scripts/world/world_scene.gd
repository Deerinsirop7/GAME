extends Node
## Игровой мир 320x180 (масштаб x2): небо, двор или комната, питомец, миска,
## погода, ночное освещение и всплывающие эффекты.

const SkyView = preload("res://scripts/world/sky.gd")
const WeatherFX = preload("res://scripts/world/weather_fx.gd")
const PetView = preload("res://scripts/world/pet_view.gd")

const HOUSE_POS := Vector2(70, 140)
const PET_OUT := Vector2(205, 146)
const PET_IN := Vector2(196, 150)
const BOWL_OUT := Vector2(164, 148)
const BOWL_IN := Vector2(134, 152)
const RANGE_OUT := Vector2(150, 300)
const RANGE_IN := Vector2(126, 252)

var show_house := true
var interior := false
var sky: Node2D
var world: Node2D
var fx: Node2D
var pet
var bowl: Sprite2D

var _sky_layer: CanvasLayer
var _mod: CanvasModulate
var _outside: Node2D
var _out_sort: Node2D
var _inside: Node2D
var _in_bg: Sprite2D
var _in_flat: Node2D
var _in_sort: Node2D
var _rain
var _glow_layer: CanvasLayer
var _glow_root: Node2D
var _glow_out: Node2D
var _glow_in: Node2D
var _spawned: Array[Node] = []
var _glow_tex: Texture2D


func _ready() -> void:
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -10
	add_child(_sky_layer)
	sky = SkyView.new()
	sky.scale = Vector2(2, 2)
	_sky_layer.add_child(sky)

	_mod = CanvasModulate.new()
	add_child(_mod)
	world = Node2D.new()
	world.scale = Vector2(2, 2)
	add_child(world)

	_outside = Node2D.new()
	world.add_child(_outside)
	_build_outside_static()
	_out_sort = Node2D.new()
	_out_sort.y_sort_enabled = true
	_outside.add_child(_out_sort)

	_inside = Node2D.new()
	_inside.visible = false
	world.add_child(_inside)
	_in_bg = Sprite2D.new()
	_in_bg.centered = false
	_inside.add_child(_in_bg)
	_in_flat = Node2D.new()
	_inside.add_child(_in_flat)
	_in_sort = Node2D.new()
	_in_sort.y_sort_enabled = true
	_inside.add_child(_in_sort)

	_rain = WeatherFX.new()
	_rain.mode = "rain"
	_rain.z_index = 50
	world.add_child(_rain)
	fx = Node2D.new()
	fx.z_index = 60
	world.add_child(fx)

	_glow_layer = CanvasLayer.new()
	_glow_layer.layer = 5
	add_child(_glow_layer)
	_glow_root = Node2D.new()
	_glow_root.scale = Vector2(2, 2)
	_glow_layer.add_child(_glow_root)
	_glow_out = Node2D.new()
	_glow_root.add_child(_glow_out)
	_glow_in = Node2D.new()
	_glow_in.visible = false
	_glow_root.add_child(_glow_in)
	var flies := WeatherFX.new()
	flies.mode = "flies"
	_glow_out.add_child(flies)

	_glow_tex = _make_glow_tex()
	refresh()


func _build_outside_static() -> void:
	var hills := Sprite2D.new()
	hills.texture = Art.tex("world/hills")
	hills.centered = false
	hills.position = Vector2(0, 68)
	_outside.add_child(hills)
	for t in [["world/tree_round", Vector2(176, 136)], ["world/tree_pine", Vector2(310, 134)],
			["world/tree_pine", Vector2(10, 132)], ["world/bush", Vector2(244, 138)]]:
		var s := Art.bottom_sprite(t[0])
		s.position = t[1]
		_outside.add_child(s)
	var ground := Sprite2D.new()
	ground.texture = Art.tex("world/ground")
	ground.centered = false
	ground.position = Vector2(0, 132)
	_outside.add_child(ground)
	var path := Sprite2D.new()
	path.texture = Art.tex("world/path")
	path.centered = false
	path.position = Vector2(HOUSE_POS.x - 22, HOUSE_POS.y)
	_outside.add_child(path)
	var fence := Art.bottom_sprite("world/fence")
	fence.position = Vector2(290, 139)
	_outside.add_child(fence)


func _make_glow_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.86, 0.55, 0.6))
	g.set_color(1, Color(1.0, 0.75, 0.4, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func _add_glow(parent: Node2D, pos: Vector2, radius: float) -> void:
	var s := Sprite2D.new()
	s.texture = _glow_tex
	s.position = pos
	s.scale = Vector2.ONE * (radius / 32.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	parent.add_child(s)
	_spawned.append(s)


## Перестроить дом и предметы по текущему состоянию игры.
func refresh() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	var has_game := not GameState.data.is_empty()
	var tier := int(GameState.data.get("house", 0)) if has_game else 0
	if show_house:
		var house := Art.bottom_sprite("house/house_%d" % tier)
		house.position = HOUSE_POS
		_out_sort.add_child(house)
		_spawned.append(house)
		for w in Catalog.HOUSES[tier]["windows"]:
			_add_glow(_glow_out, HOUSE_POS + w, 20.0 if tier == 0 else 14.0)
	_in_bg.texture = Art.tex("house/interior_%d" % tier)
	if has_game:
		for id in GameState.data["items"]:
			var it: Dictionary = Catalog.ITEMS[id]
			var s := Art.bottom_sprite("items/" + id)
			s.position = it["pos"]
			var inside: bool = it["scene"] == "in"
			var parent: Node2D
			if inside:
				parent = _in_flat if it.get("flat", false) else _in_sort
			else:
				parent = _outside if it.get("flat", false) else _out_sort
			parent.add_child(s)
			_spawned.append(s)
			if it.has("glow"):
				_add_glow(_glow_in if inside else _glow_out, it["pos"] + it["glow"], 22.0)
	_update_pet_spots()


func add_pet(pet_type: String, coat: int) -> void:
	pet = PetView.new()
	pet.setup(pet_type, coat)
	if pet_type != "fish":
		bowl = Sprite2D.new()
		bowl.centered = true
		update_bowl()
	_place_actors()


func update_bowl() -> void:
	if bowl == null or GameState.data.is_empty():
		return
	bowl.texture = Art.tex("fx/bowl_%d" % clampi(int(GameState.data["bowl"]), 0, 3))
	bowl.offset = Vector2(0, -bowl.texture.get_height() / 2.0)


func bowl_pos() -> Vector2:
	return BOWL_IN if interior else BOWL_OUT


func ground_y() -> float:
	return PET_IN.y if interior else PET_OUT.y


func _update_pet_spots() -> void:
	if pet == null:
		return
	pet.walk_range = RANGE_IN if interior else RANGE_OUT
	pet.bowl_x = bowl_pos().x if bowl else -1.0
	pet.bed_x = -1.0
	if interior and GameState.has_item("pet_bed"):
		pet.bed_x = Catalog.ITEMS["pet_bed"]["pos"].x


func _place_actors() -> void:
	if pet == null:
		return
	var target := _in_sort if interior else _out_sort
	for a in [pet, bowl]:
		if a == null:
			continue
		if a.get_parent():
			a.get_parent().remove_child(a)
		target.add_child(a)
	pet.position = PET_IN if interior else PET_OUT
	pet.state = "idle"
	pet.external = false
	if bowl:
		bowl.position = bowl_pos()
	_update_pet_spots()


func set_interior(on: bool) -> void:
	interior = on
	_outside.visible = not on
	_inside.visible = on
	_glow_out.visible = not on
	_glow_in.visible = on
	# дождь в комнате виден только в окне — переносим его за стены, в слой неба
	_rain.get_parent().remove_child(_rain)
	if on:
		sky.add_child(_rain)
	else:
		world.add_child(_rain)
	_rain.splashes = not on
	_place_actors()


func _process(_delta: float) -> void:
	var night := TimeWeather.night_factor()
	var c := Color.WHITE.lerp(Color(0.42, 0.46, 0.72), night)
	c = c * Color.WHITE.lerp(Color(1.0, 0.9, 0.82), TimeWeather.dusk_factor())
	match TimeWeather.weather:
		"rain":
			c = c * Color(0.8, 0.83, 0.92)
		"cloudy":
			c = c * Color(0.93, 0.94, 0.97)
	if interior:
		c = c.lerp(Color.WHITE, 0.35)
	if not GameState.data.is_empty() and GameState.data["sleeping"]:
		c = c * Color(0.78, 0.78, 0.9)
	c.a = 1.0
	_mod.color = c
	_glow_root.modulate.a = clampf(night * 1.2, 0.0, 1.0)


# ------------------------------------------------------------ эффекты
## Всплывающий спрайт (сердечко, монетка, нота…).
func float_sprite(tex: String, pos: Vector2, rise := 16.0, dur := 1.0, drift := 0.0) -> void:
	var s := Sprite2D.new()
	s.texture = Art.tex(tex)
	s.position = pos.round()
	fx.add_child(s)
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "position", pos + Vector2(drift, -rise), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.chain().tween_callback(s.queue_free)


## Спрайт, который падает сверху вниз (корм в аквариум, капли).
func drop_sprite(tex: String, from: Vector2, to: Vector2, dur := 0.6) -> void:
	var s := Sprite2D.new()
	s.texture = Art.tex(tex)
	s.position = from
	fx.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)


## Спрайт, летящий по дуге (мячик). Возвращает твин — его можно дождаться через await.
func arc_sprite(tex: String, from: Vector2, to: Vector2, height := 24.0, dur := 0.6) -> Tween:
	var s := Sprite2D.new()
	s.texture = Art.tex(tex)
	s.position = from
	fx.add_child(s)
	var move := func(t: float) -> void:
		s.position = from.lerp(to, t) + Vector2(0, -sin(t * PI) * height)
		s.rotation = t * TAU
	var tw := s.create_tween()
	tw.tween_method(move, 0.0, 1.0, dur)
	tw.tween_property(s, "modulate:a", 0.0, 0.2)
	tw.tween_callback(s.queue_free)
	return tw


## Временный спрайт на месте (миска), исчезает через dur секунд.
func temp_sprite(tex: String, pos: Vector2, dur := 1.8) -> void:
	var s := Art.bottom_sprite(tex)
	s.position = pos
	fx.add_child(s)
	var tw := s.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)
