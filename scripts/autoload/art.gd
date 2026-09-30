extends Node
## Загрузка и кэш текстур из assets/sprites.

var _cache := {}


func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load("res://assets/sprites/%s.png" % path)
	return _cache[path]


## Спрайт с якорем в центре нижнего края.
func bottom_sprite(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(path)
	s.centered = true
	s.offset = Vector2(0, -s.texture.get_height() / 2.0)
	return s


## Текстура, увеличенная в k раз без размытия (для иконок интерфейса).
func scaled(path: String, k: int) -> Texture2D:
	var key := "%s@%d" % [path, k]
	if not _cache.has(key):
		var img := tex(path).get_image()
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]
