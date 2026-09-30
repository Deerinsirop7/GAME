extends Node2D
## Питомец: кадры покоя, моргание, прогулки, еда, сон, эмоции.
## Начало координат — нижний центр (для рыбки — низ подставки аквариума).
## Кадры в листе: 0/1 — покой, 2 — глаза закрыты, 3 — ест.

var type := "dog"
var can_walk := true
var show_emotes := false
var walk_range := Vector2(196, 250)
var face_left := true

var _body: Node2D          # всё, что прыгает/трясётся
var _sprite: Sprite2D
var _bowl: Sprite2D
var _emote: Sprite2D
var _frame_t := 0.0
var _idle_frame := 0
var _blink := 0.0
var _blink_t := 3.0
var _eat := 0.0
var _eat_t := 0.0
var _sleeping := false
var _target_x := -1.0
var _walk_wait := 3.0
var _hop_wait := 4.0
var _fish_target := Vector2.ZERO
var _fish_wait := 0.0
var _t := 0.0


func setup(pet_type: String) -> void:
	type = pet_type
	for c in get_children():
		c.queue_free()
	_body = Node2D.new()
	add_child(_body)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.tex("pets/" + type)
	_sprite.hframes = 4
	_body.add_child(_sprite)
	if type == "fish":
		_sprite.position = Vector2(0, -16)
		_fish_target = _sprite.position
		_bowl = Art.bottom_sprite("pets/fish_bowl")
		_body.add_child(_bowl)
		can_walk = false
	else:
		_sprite.position = Vector2(0, -8)
	_emote = Sprite2D.new()
	_emote.position = Vector2(0, -38 if type == "fish" else -26)
	_emote.visible = false
	add_child(_emote)
	_apply_facing()


func _apply_facing() -> void:
	if _sprite:
		_sprite.flip_h = face_left


func set_sleeping(on: bool) -> void:
	_sleeping = on
	_target_x = -1.0


func play_eat(duration := 1.6) -> void:
	_eat = duration


## Точка над головой (в координатах родителя) — для сердечек, монет и т.п.
func head() -> Vector2:
	if type == "fish":
		return position + Vector2(0, -32)
	return position + Vector2(0, -18)


func hit(p: Vector2) -> bool:
	if type == "fish":
		return Rect2(position + Vector2(-14, -30), Vector2(28, 30)).has_point(p)
	return Rect2(position + Vector2(-10, -18), Vector2(20, 19)).has_point(p)


func happy_jump(times := 2) -> void:
	var tw := create_tween()
	for i in times:
		tw.tween_property(_body, "position:y", -7.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_body, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func shake() -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_body, "rotation", 0.18, 0.06)
		tw.tween_property(_body, "rotation", -0.18, 0.06)
	tw.tween_property(_body, "rotation", 0.0, 0.06)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_t += delta
	_animate_frames(delta)
	if type == "fish":
		_swim(delta)
	elif can_walk and not _sleeping and _eat <= 0.0:
		_wander(delta)
	elif type == "parrot" and not _sleeping:
		_parrot_hop(delta)
	_update_emote()


func _animate_frames(delta: float) -> void:
	_frame_t += delta
	if _frame_t > 0.45:
		_frame_t = 0.0
		_idle_frame = 1 - _idle_frame
	if _sleeping:
		_sprite.frame = 2
		return
	if _eat > 0.0:
		_eat -= delta
		_eat_t += delta
		_sprite.frame = 3 if int(_eat_t / 0.18) % 2 == 0 else 0
		return
	if _blink > 0.0:
		_blink -= delta
		_sprite.frame = 2
		return
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.5, 6.0)
		_blink = 0.14
	_sprite.frame = _idle_frame


func _wander(delta: float) -> void:
	if _target_x < 0.0:
		_walk_wait -= delta
		if _walk_wait <= 0.0:
			_walk_wait = randf_range(3.0, 8.0)
			if randf() < 0.65:
				_target_x = randf_range(walk_range.x, walk_range.y)
		if type == "parrot":
			_parrot_hop(delta)
		return
	var dir := signf(_target_x - position.x)
	face_left = dir < 0.0
	_apply_facing()
	var speed := 14.0 if type == "parrot" else 20.0
	position.x += dir * speed * delta
	# лёгкое покачивание при ходьбе
	_body.position.y = -1.0 if int(_t * 8.0) % 2 == 0 else 0.0
	if absf(_target_x - position.x) < 1.0:
		position.x = roundf(_target_x)
		_target_x = -1.0
		_body.position.y = 0.0
		face_left = true   # смотрим на хозяина
		_apply_facing()


func _parrot_hop(delta: float) -> void:
	_hop_wait -= delta
	if _hop_wait <= 0.0:
		_hop_wait = randf_range(2.0, 5.0)
		happy_jump(1)


func _swim(delta: float) -> void:
	if _sleeping:
		_sprite.position.y = lerpf(_sprite.position.y, -12.0, delta)
		return
	_fish_wait -= delta
	if _fish_wait <= 0.0:
		_fish_wait = randf_range(1.5, 3.5)
		_fish_target = Vector2(randf_range(-4.0, 4.0), randf_range(-19.0, -13.0))
	var d := _fish_target - _sprite.position
	if d.length() > 0.3:
		var step := d.normalized() * 6.0 * delta
		if step.length() > d.length():
			step = d
		_sprite.position += step
		if absf(d.x) > 0.5:
			_sprite.flip_h = d.x < 0.0


func _update_emote() -> void:
	if not show_emotes or GameState.data.is_empty() or _sleeping:
		_emote.visible = false
		return
	var k := GameState.lowest_need()
	if float(GameState.data["needs"][k]) >= 30.0:
		_emote.visible = false
		return
	_emote.texture = Art.tex("fx/emote_" + k)
	_emote.visible = true
	_emote.position.y = (-38.0 if type == "fish" else -26.0) + (-1.0 if int(_t * 2.0) % 2 == 0 else 0.0)
