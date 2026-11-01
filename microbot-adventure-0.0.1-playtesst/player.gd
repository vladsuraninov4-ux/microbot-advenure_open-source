extends CharacterBody2D
## СКРИПТ ИГРОКА — добрый робот v2.2 (ФИНАЛЬНЫЙ)
## Всё тело, коллизии и анимации создаются кодом. Ноль текстур.
## Включено: койот-тайм, буфер прыжка, стомп грибов без камикадзе.

@export var speed: float = 260.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 650.0
@export var max_fall_speed: float = 900.0
@export var bounce_velocity: float = -300.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

signal died

# --- Узлы анимации ---
var visual: Node2D
var body_root: Node2D
var leg_l: Polygon2D
var leg_r: Polygon2D
var arm_l: Polygon2D
var arm_r: Polygon2D
var eye_l: Polygon2D
var eye_r: Polygon2D
var antenna_light: Polygon2D
var thruster: Polygon2D

# --- Состояние ---
var facing: float = 1.0
var squash := Vector2.ONE
var was_on_floor: bool = true
var walk_phase: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var blink_timer: float = 3.0
var time_alive: float = 0.0
var is_dead: bool = false

func _ready() -> void:
	add_to_group("player")
	_build_collision()
	_build_visual()
	_build_hit_area()
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)

# ========== СБОРКА ТЕЛА ИЗ КОДА ==========

func _rect_poly(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0),
		Vector2(x1, y1), Vector2(x0, y1)
	])

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

func _build_collision() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 48)
	shape.shape = rect
	add_child(shape)

func _build_visual() -> void:
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	body_root = Node2D.new()
	visual.add_child(body_root)

	var c_body := Color(0.25, 0.6, 0.95)
	var c_dark := Color(0.15, 0.4, 0.7)
	var c_metal := Color(0.75, 0.8, 0.85)

	# Ноги + ступни
	leg_l = _poly(body_root, _rect_poly(-4, 0, 4, 14), c_dark, Vector2(-7, 10))
	leg_r = _poly(body_root, _rect_poly(-4, 0, 4, 14), c_dark, Vector2(7, 10))
	_poly(leg_l, _rect_poly(-5, 12, 6, 16), c_metal)
	_poly(leg_r, _rect_poly(-6, 12, 5, 16), c_metal)

	# Руки
	arm_l = _poly(body_root, _rect_poly(-3, 0, 3, 13), c_dark, Vector2(-15, -8))
	arm_r = _poly(body_root, _rect_poly(-3, 0, 3, 13), c_dark, Vector2(15, -8))

	# Торс + панель с огоньком
	_poly(body_root, _rect_poly(-14, -12, 14, 12), c_body)
	_poly(body_root, _rect_poly(-6, -5, 6, 5), c_dark)
	_poly(body_root, _rect_poly(-3, -2, 3, 2), Color(1.0, 0.85, 0.2))

	# Голова + визор + глаза
	_poly(body_root, _rect_poly(-12, -30, 12, -12), c_body)
	_poly(body_root, _rect_poly(-9, -26, 9, -18), Color(0.1, 0.12, 0.2))
	eye_l = _poly(body_root, _rect_poly(-2, -3, 2, 3), Color(0.4, 1.0, 1.0), Vector2(-5, -22))
	eye_r = _poly(body_root, _rect_poly(-2, -3, 2, 3), Color(0.4, 1.0, 1.0), Vector2(5, -22))

	# Антенна с мигающей лампочкой
	_poly(body_root, _rect_poly(-1, -36, 1, -30), c_metal)
	antenna_light = _poly(body_root, _rect_poly(-3, -41, 3, -35), Color(1.0, 0.3, 0.3))

	# Пламя под ногами (только при взлёте)
	thruster = _poly(body_root, PackedVector2Array([
		Vector2(-6, 24), Vector2(6, 24), Vector2(0, 36)
	]), Color(1.0, 0.6, 0.1, 0.9))
	thruster.visible = false

func _build_hit_area() -> void:
	var hit_area := Area2D.new()
	hit_area.name = "HitArea"
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(34, 46)
	hit_shape.shape = hit_rect
	hit_area.add_child(hit_shape)
	hit_area.set_collision_layer_value(4, true)
	hit_area.set_collision_mask_value(4, true)
	add_child(hit_area)

# ========== ФИЗИКА И УПРАВЛЕНИЕ ==========

func _physics_process(delta: float) -> void:
	time_alive += delta

	# Гравитация
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)

	# Койот-тайм (прыжок чуть после края) и буфер прыжка
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	if coyote_timer > 0.0 and jump_buffer_timer > 0.0:
		velocity.y = jump_velocity
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		squash = Vector2(0.8, 1.2)

	# Отпустил кнопку раньше — прыжок ниже
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.55

	# Бег
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * speed
	if dir != 0.0:
		facing = sign(dir)

	move_and_slide()

	# Приземление — сплющивание
	if is_on_floor() and not was_on_floor:
		squash = Vector2(1.25, 0.8)
	was_on_floor = is_on_floor()

	# --- КОНТАКТ С ВРАГАМИ: опрос каждый кадр (надёжнее сигналов) ---
	var hit_area := get_node_or_null("HitArea")
	if hit_area != null and not is_dead:
		for area in hit_area.get_overlapping_areas():
			if area.is_in_group("enemy"):
				var enemy: Node = area.get_parent()
				if enemy != null and enemy.has_method("die"):
					_handle_enemy(enemy)
				break

	_animate(delta)

# ========== АНИМАЦИИ ==========

func _animate(delta: float) -> void:
	squash = squash.lerp(Vector2.ONE, 12.0 * delta)
	visual.scale = Vector2(facing * squash.x, squash.y)

	if is_on_floor():
		thruster.visible = false
		if abs(velocity.x) > 10.0:
			# Бег: ноги и руки качаются
			walk_phase += delta * 12.0 * (abs(velocity.x) / speed)
			var sw := sin(walk_phase) * 0.6
			leg_l.rotation = sw
			leg_r.rotation = -sw
			arm_l.rotation = -sw * 0.8
			arm_r.rotation = sw * 0.8
			body_root.position.y = -abs(cos(walk_phase)) * 1.5
		else:
			# Стоит: дышит
			leg_l.rotation = lerp(leg_l.rotation, 0.0, 10.0 * delta)
			leg_r.rotation = lerp(leg_r.rotation, 0.0, 10.0 * delta)
			arm_l.rotation = lerp(arm_l.rotation, 0.15, 10.0 * delta)
			arm_r.rotation = lerp(arm_r.rotation, 0.15, 10.0 * delta)
			body_root.position.y = sin(time_alive * 2.5) * 1.2
	else:
		# В воздухе: группировка + пламя
		leg_l.rotation = lerp(leg_l.rotation, 0.5, 12.0 * delta)
		leg_r.rotation = lerp(leg_r.rotation, -0.35, 12.0 * delta)
		arm_l.rotation = lerp(arm_l.rotation, -1.3, 12.0 * delta)
		arm_r.rotation = lerp(arm_r.rotation, 0.5, 12.0 * delta)
		thruster.visible = velocity.y < 0.0
		if thruster.visible:
			thruster.scale = Vector2(1.0, randf_range(0.7, 1.3))

	# Лампочка пульсирует
	antenna_light.color = Color(1.0, 0.3, 0.3, 0.5 + 0.5 * sin(time_alive * 6.0))

	# Моргание глаз
	blink_timer -= delta
	if blink_timer <= 0.0:
		blink_timer = randf_range(2.5, 4.5)
		var tw := create_tween()
		tw.tween_property(eye_l, "scale:y", 0.1, 0.06)
		tw.parallel().tween_property(eye_r, "scale:y", 0.1, 0.06)
		tw.tween_property(eye_l, "scale:y", 1.0, 0.06)
		tw.parallel().tween_property(eye_r, "scale:y", 1.0, 0.06)

# ========== БОЁВКА ==========

func _handle_enemy(enemy: Node) -> void:
	if is_dead:
		return
	# Гриб уже плющится — не трогаем труп (иначе камикадзе!)
	if enemy.get("is_dying") == true:
		return
	# Падаем сверху на голову — стомп!
	if velocity.y > 0.0 and global_position.y < enemy.global_position.y - 10.0:
		enemy.die()
		velocity.y = bounce_velocity
	else:
		# Касание сбоку или снизу — смерть
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	set_physics_process(false)
	hide()
	await get_tree().create_timer(0.6).timeout
	get_tree().reload_current_scene()
