extends Node2D
## Дождь (mode = "rain") или светлячки (mode = "flies").

var mode := "rain"
var splashes := true       # брызги у земли — только на улице
var ground_y := 150.0

var _drops: Array[Vector2] = []
var _splash: Array = []    # [Vector2, время жизни]
var _flies: Array = []     # [база, фаза, скорость]
var _t := 0.0


func _ready() -> void:
	for i in 10:
		_flies.append([Vector2(randf_range(10, 310), randf_range(100, 145)), randf() * TAU, randf_range(0.5, 1.2)])


func _process(delta: float) -> void:
	_t += delta
	if mode == "rain":
		var target := 140 if TimeWeather.weather == "rain" else 0
		if _drops.size() < target and randf() < 0.9:
			for i in 3:
				_drops.append(Vector2(randf_range(-20, 330), randf_range(-40, -2)))
		for i in range(_drops.size() - 1, -1, -1):
			var d := _drops[i] + Vector2(35, 190) * delta
			var limit := ground_y + randf_range(-6, 30) if splashes else 185.0
			if d.y > limit:
				if splashes and d.y < 175.0:
					_splash.append([d, 0.2])
				if _drops.size() > target:
					_drops.remove_at(i)
					continue
				d = Vector2(randf_range(-20, 330), randf_range(-20, -2))
			_drops[i] = d
		for s in _splash.duplicate():
			s[1] -= delta
			if s[1] <= 0.0:
				_splash.erase(s)
	queue_redraw()


func _draw() -> void:
	if mode == "rain":
		var col := Color(0.78, 0.85, 1.0, 0.65)
		for d in _drops:
			var p := d.floor()
			draw_rect(Rect2(p, Vector2(1, 3)), col)
		for s in _splash:
			var p: Vector2 = (s[0] as Vector2).floor()
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(1, 1)), col)
			draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), col)
		return
	# светлячки: ночью и без дождя
	var a := TimeWeather.night_factor()
	if TimeWeather.weather == "rain":
		a = 0.0
	if a < 0.05:
		return
	for f in _flies:
		var base: Vector2 = f[0]
		var ph: float = f[1]
		var sp: float = f[2]
		var p := base + Vector2(sin(_t * 0.4 * sp + ph) * 18.0, sin(_t * 0.9 * sp + ph * 2.0) * 6.0)
		p = p.floor()
		var glow := (0.5 + 0.5 * sin(_t * 3.0 * sp + ph)) * a
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(0.9, 1.0, 0.5, glow * 0.25))
		draw_rect(Rect2(p, Vector2.ONE), Color(0.95, 1.0, 0.65, glow))
