extends Node2D
## Небо: градиент по времени суток, солнце, луна, звёзды и облака.
## Живёт в отдельном CanvasLayer, поэтому ночное затемнение мира его не трогает.

const W := 320.0
const H := 180.0
## [час, цвет верха, цвет низа]
const KEYS := [
	[0.0, Color("161a3a"), Color("2c3260")],
	[4.5, Color("1c2248"), Color("3a3a6c")],
	[6.0, Color("6a6aac"), Color("f4b896")],
	[7.5, Color("78b4ec"), Color("d2ecff")],
	[17.0, Color("74b0ea"), Color("d0eaff")],
	[18.8, Color("7a74b8"), Color("f8b48a")],
	[20.3, Color("262a58"), Color("54467c")],
	[24.0, Color("161a3a"), Color("2c3260")],
]
const CLOUD_TEX := ["world/cloud_a", "world/cloud_b", "world/cloud_c"]
const CLOUD_COUNT := {"sunny": 3, "cloudy": 7, "rain": 9}

var _stars: Array = []
var _clouds: Array[Sprite2D] = []
var _sun: Sprite2D
var _moon: Sprite2D
var _t := 0.0
var _top := Color.BLACK
var _bottom := Color.BLACK


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 45:
		_stars.append([Vector2(rng.randi_range(0, 319), rng.randi_range(0, 110)), rng.randf() * TAU, rng.randf() < 0.2])
	_sun = Sprite2D.new()
	_sun.texture = Art.tex("world/sun")
	add_child(_sun)
	_moon = Sprite2D.new()
	_moon.texture = Art.tex("world/moon")
	add_child(_moon)
	for i in CLOUD_COUNT[TimeWeather.weather]:
		_spawn_cloud(randf_range(-20.0, W))


func _spawn_cloud(x: float) -> void:
	var c := Sprite2D.new()
	c.texture = Art.tex(CLOUD_TEX[randi() % CLOUD_TEX.size()])
	c.position = Vector2(x, randf_range(10.0, 70.0)).round()
	c.set_meta("speed", randf_range(2.0, 6.0))
	add_child(c)
	_clouds.append(c)


func _sky_colors() -> Array:
	var h := TimeWeather.hour
	for i in range(KEYS.size() - 1):
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var t: float = (h - a[0]) / (b[0] - a[0])
			return [(a[1] as Color).lerp(b[1], t), (a[2] as Color).lerp(b[2], t)]
	return [KEYS[0][1], KEYS[0][2]]


func _process(delta: float) -> void:
	_t += delta
	var cols := _sky_colors()
	var top: Color = cols[0]
	var bottom: Color = cols[1]
	var night := TimeWeather.night_factor()
	var gray := Color("8e9aae").darkened(night * 0.75)
	match TimeWeather.weather:
		"cloudy":
			top = top.lerp(gray, 0.4)
			bottom = bottom.lerp(gray, 0.35)
		"rain":
			gray = Color("6c7688").darkened(night * 0.7)
			top = top.lerp(gray, 0.65)
			bottom = bottom.lerp(gray, 0.6)
	_top = top
	_bottom = bottom

	# солнце и луна по дуге
	var h := TimeWeather.hour
	var sun_t := (h - 6.0) / 13.5
	_sun.visible = sun_t > 0.0 and sun_t < 1.0
	_sun.position = Vector2(20.0 + sun_t * 280.0, 75.0 - sin(sun_t * PI) * 58.0).round()
	var hh := h + 24.0 if h < 7.0 else h
	var moon_t := (hh - 19.0) / 12.0
	_moon.visible = moon_t > 0.0 and moon_t < 1.0
	_moon.position = Vector2(20.0 + moon_t * 280.0, 75.0 - sin(moon_t * PI) * 55.0).round()
	var veil := 0.15 if TimeWeather.weather == "rain" else (0.55 if TimeWeather.weather == "cloudy" else 1.0)
	_sun.modulate.a = veil
	_moon.modulate.a = veil

	# облака
	var target: int = CLOUD_COUNT[TimeWeather.weather]
	var tint := Color.WHITE
	if TimeWeather.weather == "cloudy":
		tint = Color(0.86, 0.88, 0.93)
	elif TimeWeather.weather == "rain":
		tint = Color(0.58, 0.61, 0.69)
	tint = tint.lerp(Color(0.3, 0.33, 0.5), night * 0.8)
	tint = tint.lerp(Color(1.0, 0.8, 0.75), TimeWeather.dusk_factor() * 0.35)
	for c in _clouds.duplicate():
		c.position.x += float(c.get_meta("speed")) * delta
		c.modulate = tint
		if c.position.x - c.texture.get_width() / 2.0 > W:
			_clouds.erase(c)
			c.queue_free()
			if _clouds.size() < target:
				_spawn_cloud(-30.0)
	if _clouds.size() < target and randf() < delta * 0.5:
		_spawn_cloud(-30.0)
	queue_redraw()


func _draw() -> void:
	var step := 4.0
	var y := 0.0
	while y < H:
		draw_rect(Rect2(0, y, W, step), _top.lerp(_bottom, y / H))
		y += step
	var night := TimeWeather.night_factor()
	if TimeWeather.weather == "rain":
		night *= 0.2
	elif TimeWeather.weather == "cloudy":
		night *= 0.6
	if night > 0.02:
		for s in _stars:
			var tw := 0.6 + 0.4 * sin(_t * 1.7 + float(s[1]))
			var c := Color(1, 1, 0.9, night * tw)
			var p: Vector2 = s[0]
			draw_rect(Rect2(p, Vector2.ONE), c)
			if s[2]:
				draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(c, c.a * 0.4))
				draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), Color(c, c.a * 0.4))
