extends Node2D
## Питомец: сам ходит, ест из миски, спит, грязнится; реагирует на руку игрока.
## Начало координат — нижний центр (для рыбки — низ тумбы аквариума).
## Кадры листа 12x(24x24): 0,1 покой · 2 моргание · 3-6 шаги · 7,8 ест · 9 радость · 10,11 сон.
## Рыбка: 4 кадра 14x10: 0,1 плывёт · 2 моргает · 3 ест.

signal bite     # откусил из миски / поймал хлопья — для звука и крошек

var type := "dog"
var coat := 0
var walk_range := Vector2(150, 300)
var bowl_x := -1.0        # где миска (<0 — миски нет)
var bed_x := -1.0         # где лежанка (<0 — спит на месте)
var show_emotes := false
var ai_enabled := true
var external := false     # true — питомцем управляет игра (мячик, пёрышко)
var face_left := true
var state := "idle"       # idle, walk, eat, sleep, pounce
var follow_point := Vector2.INF   # рыбка плывёт за пальцем (координаты родителя)
var flakes: Array = []            # хлопья корма в аквариуме (Sprite2D в координатах родителя)

var _body: Node2D
var _sprite: Sprite2D
var _glass: Sprite2D
var _marks: Node2D
var _foam: Node2D
var _carry: Sprite2D
var _emote: Sprite2D
var _t := 0.0
var _anim_t := 0.0
var _blink := 0.0
var _blink_t := 3.0
var _target_x := -1.0
var _speed := 22.0
var _after := "idle"
var _wait := 2.0
var _eat_t := 0.0
var _bite_t := 0.0
var _happy := 0.0
var _hop_t := 4.0
var _fish_target := Vector2(0, -24)
var _fish_wait := 0.0
var _fish_eat := 0.0
var _spots: Array[Vector2] = []
var _marks_t := 0.0
var _pounce_from := 0.0
var _pounce_to := 0.0


func setup(pet_type: String, coat_idx := 0) -> void:
	type = pet_type
	coat = coat_idx
	for c in get_children():
		c.queue_free()
	_body = Node2D.new()
	add_child(_body)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.tex("pets/%s_%d" % [type, coat])
	_marks = Node2D.new()
	_marks.draw.connect(_draw_marks)
	if type == "fish":
		_sprite.hframes = 4
		_sprite.position = Vector2(0, -24)
		_body.add_child(_sprite)
		_glass = Art.bottom_sprite("pets/fish_bowl")
		_body.add_child(_glass)
		_body.add_child(_marks)
	else:
		_sprite.hframes = 12
		_sprite.position = Vector2(0, -12)
		_body.add_child(_sprite)
		_body.add_child(_marks)
	_foam = Node2D.new()
	_body.add_child(_foam)
	_carry = Sprite2D.new()
	_carry.texture = Art.tex("fx/ball")
	_carry.visible = false
	_body.add_child(_carry)
	_emote = Sprite2D.new()
	_emote.visible = false
	add_child(_emote)
	_spots.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 8:
		if type == "fish":
			_spots.append(Vector2(rng.randf_range(-13, 10), rng.randf_range(-36, -14)).round())
		else:
			_spots.append(Vector2(rng.randf_range(-7, 4), rng.randf_range(-12, -6)).round())
	_apply_facing()


# ------------------------------------------------------------ команды
func walk_to(x: float, speed := 22.0, after := "idle") -> void:
	if type == "fish" or state == "sleep" or state == "pounce":
		return
	_target_x = clampf(x, 10.0, 310.0)
	_speed = speed
	_after = after
	state = "walk"


func stop() -> void:
	if state == "walk" or state == "eat":
		state = "idle"


## Питомца гладят: радостная мордочка, прогулки на паузе.
func pet_happy(t := 0.35) -> void:
	if state == "sleep" or state == "pounce":
		return
	if state == "walk" and not external:
		state = "idle"
	if state == "idle":
		_happy = maxf(_happy, t)


func happy_jump(times := 1) -> void:
	var node: Node2D = _sprite if type == "fish" else _body
	var base_y := -24.0 if type == "fish" else 0.0
	if type == "fish":
		base_y = node.position.y
	var tw := create_tween()
	for i in times:
		tw.tween_property(node, "position:y", base_y - 6.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "position:y", base_y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func shake() -> void:
	var tw := create_tween()
	for i in 5:
		tw.tween_property(_body, "rotation", 0.2, 0.05)
		tw.tween_property(_body, "rotation", -0.2, 0.05)
	tw.tween_property(_body, "rotation", 0.0, 0.05)


## Прыжок на пёрышко.
func pounce_to(x: float) -> void:
	if state == "sleep" or state == "pounce" or type == "fish":
		return
	state = "pounce"
	_pounce_from = position.x
	_pounce_to = clampf(x, 10.0, 310.0)
	face_left = _pounce_to < _pounce_from
	_apply_facing()
	_frame(9)
	var tw := create_tween()
	tw.tween_method(_pounce_step, 0.0, 1.0, 0.4)
	tw.tween_callback(_pounce_end)


func _pounce_step(t: float) -> void:
	position.x = lerpf(_pounce_from, _pounce_to, t)
	_body.position.y = -sin(t * PI) * 12.0


func _pounce_end() -> void:
	_body.position.y = 0.0
	state = "idle"


func add_foam() -> int:
	if _foam.get_child_count() >= 10:
		return 10
	var f := Sprite2D.new()
	f.texture = Art.tex("fx/foam")
	f.position = Vector2(randf_range(-8, 6), randf_range(-18, -6)).round()
	f.scale = Vector2(0.2, 0.2)
	_foam.add_child(f)
	f.create_tween().tween_property(f, "scale", Vector2.ONE, 0.15)
	return _foam.get_child_count()


func foam_count() -> int:
	return _foam.get_child_count()


func clear_foam() -> void:
	for f in _foam.get_children():
		f.queue_free()


func set_carry(on: bool) -> void:
	_carry.visible = on
	_carry.position = Vector2(-10 if face_left else 10, -9)


## Точка над головой (координаты родителя) — для сердечек, монет.
func head() -> Vector2:
	if type == "fish":
		return position + Vector2(0, -44)
	return position + Vector2(-6 if face_left else 6, -22)


func center() -> Vector2:
	if type == "fish":
		return position + _sprite.position
	return position + Vector2(0, -10)


func hit(p: Vector2) -> bool:
	if type == "fish":
		return Rect2(position + Vector2(-16, -40), Vector2(32, 40)).has_point(p)
	if state == "sleep":
		return Rect2(position + Vector2(-11, -14), Vector2(22, 15)).has_point(p)
	return Rect2(position + Vector2(-11, -22), Vector2(22, 23)).has_point(p)


func _apply_facing() -> void:
	if _sprite and type != "fish":
		_sprite.flip_h = face_left
	if _carry and _carry.visible:
		_carry.position = Vector2(-10 if face_left else 10, -9)


func _frame(i: int) -> void:
	_sprite.frame = i


# ------------------------------------------------------------ поведение
func _process(delta: float) -> void:
	if _sprite == null:
		return
	_t += delta
	_anim_t += delta
	if type == "fish":
		_fish(delta)
	else:
		_sync_sleep()
		match state:
			"idle":
				_st_idle(delta)
			"walk":
				_st_walk(delta)
			"eat":
				_st_eat(delta)
			"sleep":
				_frame(10 + int(_anim_t / 1.1) % 2)
			"pounce":
				_frame(9)
	_update_emote()
	_marks_t -= delta
	if _marks_t <= 0.0:
		_marks_t = 0.5
		_marks.queue_redraw()


func _playing_game() -> bool:
	return not GameState.data.is_empty() and GameState.playing


func _sync_sleep() -> void:
	if not _playing_game():
		return
	var sleeping: bool = GameState.data["sleeping"]
	var going_to_bed := state == "walk" and _after == "sleep"
	if sleeping and state != "sleep" and not going_to_bed and state != "pounce":
		external = false
		set_carry(false)
		if bed_x >= 0.0 and absf(position.x - bed_x) > 2.0:
			walk_to(bed_x, 24.0, "sleep")
		else:
			state = "sleep"
	elif not sleeping and (state == "sleep" or going_to_bed):
		state = "idle"
		_wait = 1.5


func _idle_frame(delta: float) -> void:
	if _happy > 0.0:
		_happy -= delta
		_frame(9)
		return
	if _blink > 0.0:
		_blink -= delta
		_frame(2)
		return
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.5, 6.0)
		_blink = 0.14
	_frame(int(_anim_t / 0.5) % 2)


func _st_idle(delta: float) -> void:
	_idle_frame(delta)
	if external or not ai_enabled or not _playing_game() or _happy > 0.0:
		return
	var n: Dictionary = GameState.data["needs"]
	if bowl_x >= 0.0 and int(GameState.data["bowl"]) > 0 and float(n["hunger"]) < 88.0:
		walk_to(bowl_x + 14.0, 26.0, "eat")
		return
	_wait -= delta
	if _wait <= 0.0:
		var tired := float(n["energy"]) < 25.0
		_wait = randf_range(3.0, 7.0) * (2.0 if tired else 1.0)
		if randf() < (0.3 if tired else 0.65):
			walk_to(randf_range(walk_range.x, walk_range.y), 16.0 if tired else 22.0)
	if type == "parrot":
		_hop_t -= delta
		if _hop_t <= 0.0:
			_hop_t = randf_range(3.0, 6.0)
			happy_jump(1)


func _st_walk(delta: float) -> void:
	var dx := _target_x - position.x
	if absf(dx) <= 1.0:
		position.x = roundf(_target_x)
		state = _after
		_after = "idle"
		if state == "eat":
			face_left = true
			_eat_t = 0.0
		_apply_facing()
		return
	face_left = dx < 0.0
	_apply_facing()
	position.x += signf(dx) * minf(absf(dx), _speed * delta)
	var step := 0.07 if _speed > 40.0 else 0.13
	_frame(3 + int(_anim_t / step) % 4)


func _st_eat(delta: float) -> void:
	if external or not _playing_game():
		state = "idle"
		return
	_frame(7 + int(_anim_t / 0.25) % 2)
	_bite_t += delta
	if _bite_t > 0.6:
		_bite_t = 0.0
		bite.emit()
	_eat_t += delta
	if _eat_t >= 2.4:
		_eat_t = 0.0
		GameState.eat_portion()
		if int(GameState.data["bowl"]) <= 0 or float(GameState.data["needs"]["hunger"]) >= 97.0:
			state = "idle"
			_happy = 0.8
			_wait = 2.0


# ------------------------------------------------------------ рыбка
func _fish(delta: float) -> void:
	var sleeping := _playing_game() and bool(GameState.data["sleeping"])
	if sleeping:
		_sprite.position = _sprite.position.lerp(Vector2(_sprite.position.x, -19.0), delta)
		_frame(2)
		return
	var target := _fish_target
	var speed := 10.0
	var flake: Sprite2D = null
	for f in flakes.duplicate():
		if not is_instance_valid(f):
			flakes.erase(f)
			continue
		if flake == null or (f.position - center()).length() < (flake.position - center()).length():
			flake = f
	if flake:
		target = flake.position - position
		speed = 24.0
	elif follow_point != Vector2.INF:
		target = follow_point - position
		speed = 26.0
	else:
		_fish_wait -= delta
		if _fish_wait <= 0.0:
			_fish_wait = randf_range(1.5, 3.5)
			_fish_target = Vector2(randf_range(-9.0, 8.0), randf_range(-31.0, -18.0))
		target = _fish_target
	target = Vector2(clampf(target.x, -9.0, 8.0), clampf(target.y, -31.0, -18.0))
	var d := target - _sprite.position
	if d.length() > 0.5:
		var step := d.normalized() * speed * delta
		if step.length() > d.length():
			step = d
		_sprite.position += step
		if absf(d.x) > 0.6:
			_sprite.flip_h = d.x < 0.0
	if flake and (flake.position - center()).length() < 4.0:
		flakes.erase(flake)
		flake.queue_free()
		GameState.eat_flake()
		bite.emit()
		_fish_eat = 0.3
	if _fish_eat > 0.0:
		_fish_eat -= delta
		_frame(3)
	elif _happy > 0.0:
		_happy -= delta
		_frame(3 if int(_anim_t / 0.1) % 2 == 0 else 0)
	else:
		_frame(int(_anim_t / (0.15 if speed > 20.0 else 0.3)) % 2)


# ------------------------------------------------------------ грязь и эмоции
func _draw_marks() -> void:
	if GameState.data.is_empty():
		return
	var clean := float(GameState.data["needs"]["clean"])
	var a := clampf((60.0 - clean) / 40.0, 0.0, 1.0)
	if a <= 0.0:
		return
	if type == "fish":
		var col := Color(0.36, 0.56, 0.26, 0.55 * a)
		for p in _spots:
			_marks.draw_rect(Rect2(p, Vector2(3, 2)), col)
			_marks.draw_rect(Rect2(p + Vector2(1, -1), Vector2(1, 1)), col)
		return
	var dirt := Color(0.45, 0.31, 0.2, 0.9 * a)
	for p in _spots:
		var q := p
		if face_left:
			q.x = -q.x - 2.0
		if state == "sleep":
			q.y += 4.0
		_marks.draw_rect(Rect2(q, Vector2(2, 1)), dirt)


func _update_emote() -> void:
	if not show_emotes or GameState.data.is_empty() or GameState.data["sleeping"]:
		_emote.visible = false
		return
	var k := GameState.lowest_need()
	if float(GameState.data["needs"][k]) >= 30.0:
		_emote.visible = false
		return
	_emote.texture = Art.tex("fx/emote_" + k)
	_emote.visible = true
	var base := -50.0 if type == "fish" else -32.0
	_emote.position = Vector2(0, base + (-1.0 if int(_t * 2.0) % 2 == 0 else 0.0))
