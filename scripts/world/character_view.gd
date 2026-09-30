extends Node2D
## Персонаж, собранный из слоёв. Начало координат — между ступнями.

const LAYERS := ["hair_back", "body", "clothes", "face", "eyes_iris", "eyes_base", "eyes_closed", "hair_front"]

var _jump: Node2D
var _bob: Node2D
var _layers := {}
var _bob_t := 0.0
var _blink_t := 2.0
var _blinking := 0.0
var animate := true


func _ready() -> void:
	if _jump == null:
		_build()


func _build() -> void:
	_jump = Node2D.new()
	add_child(_jump)
	_bob = Node2D.new()
	_jump.add_child(_bob)
	for l in LAYERS:
		var s := Sprite2D.new()
		s.centered = false
		s.position = Vector2(-10, -26)
		_bob.add_child(s)
		_layers[l] = s


## p — словарь персонажа: gender, hair_style, hair_color, eye_color, skin (индексы).
func setup(p: Dictionary) -> void:
	if _jump == null:
		_build()
	var style: String = Catalog.HAIR_STYLES[int(p["hair_style"])]
	var gender: String = Catalog.GENDERS[int(p["gender"])]
	var hair: Color = Catalog.HAIR_COLORS[int(p["hair_color"])]
	_apply_layer("hair_back", "character/hair_%s_back" % style, hair)
	_apply_layer("body", "character/body", Catalog.SKIN_TONES[int(p["skin"])])
	_apply_layer("clothes", "character/clothes_%s" % gender, Color.WHITE)
	_apply_layer("face", "character/face", Color.WHITE)
	_apply_layer("eyes_iris", "character/eyes_iris", Catalog.EYE_COLORS[int(p["eye_color"])])
	_apply_layer("eyes_base", "character/eyes_base", Color.WHITE)
	_apply_layer("eyes_closed", "character/eyes_closed", Color.WHITE)
	_apply_layer("hair_front", "character/hair_%s_front" % style, hair)
	_layers["eyes_closed"].visible = false


func _apply_layer(layer: String, path: String, col: Color) -> void:
	var s: Sprite2D = _layers[layer]
	s.texture = Art.tex(path)
	s.modulate = col


func _process(delta: float) -> void:
	if not animate or _bob == null:
		return
	_bob_t += delta
	if _bob_t > 0.55:
		_bob_t = 0.0
		_bob.position.y = -1.0 if _bob.position.y == 0.0 else 0.0
	if _blinking > 0.0:
		_blinking -= delta
		if _blinking <= 0.0:
			_set_eyes(true)
	else:
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blink_t = randf_range(2.0, 5.0)
			_blinking = 0.13
			_set_eyes(false)


func _set_eyes(open: bool) -> void:
	_layers["eyes_iris"].visible = open
	_layers["eyes_base"].visible = open
	_layers["eyes_closed"].visible = not open


func hop(height := 5.0, times := 1) -> void:
	var tw := create_tween()
	for i in times:
		tw.tween_property(_jump, "position:y", -height, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_jump, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-9, -26), Vector2(18, 26)).has_point(p)
