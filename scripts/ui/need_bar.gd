extends Control
## Полоска нужды: иконка + пиксельная шкала из делений.

const DARK := Color("2b2036")

var need := "hunger"
var value := 100.0
var color := Color.WHITE
var _icon: Texture2D
var _t := 0.0


func setup(need_key: String, col: Color) -> void:
	need = need_key
	color = col
	_icon = Art.scaled("ui/need_" + need_key, 2)
	custom_minimum_size = Vector2(126, 30)
	tooltip_text = GameState.NEED_NAMES[need_key]
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_value(v: float) -> void:
	if absf(v - value) > 0.05:
		value = v
		queue_redraw()


func _process(delta: float) -> void:
	if value < 25.0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	draw_texture(_icon, Vector2(0, 1))
	var r := Rect2(32, 9, 90, 12)
	draw_rect(r.grow(2), DARK)
	draw_rect(r, Color("4a3d58"))
	var segs := 15
	var seg_w := r.size.x / segs
	var filled := int(ceil(value / 100.0 * segs - 0.001))
	var c := color
	if value < 25.0 and int(_t * 3.0) % 2 == 0:
		c = c.lightened(0.35)
	for i in filled:
		var x := r.position.x + i * seg_w
		draw_rect(Rect2(x, r.position.y, seg_w - 1, r.size.y), c)
		draw_rect(Rect2(x, r.position.y, seg_w - 1, 3), c.lightened(0.3))
