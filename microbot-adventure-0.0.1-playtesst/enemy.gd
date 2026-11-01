extends CharacterBody2D
## СКРИПТ ВРАГА — гриб-киборг v2.0
## Шляпка-купол рисуется процедурно (циклом в коде), кибер-глаз светится,
## антенна мигает. Патрулирует платформу, плющится как гумба при стомпе.

@export var speed: float = 70.0
@export var gravity: float = 1300.0

var direction: int = 1
var walk_phase: float = 0.0
var turn_cooldown: float = 0.0
var is_dying: bool = false

var visual: Node2D
var body_root: Node2D
var foot_l: Polygon2D
var foot_r: Polygon2D
var cyber_eye: Polygon2D
var antenna_light: Polygon2D

func _ready() -> void:
	_build_collision()
	_build_visual()
	_build_sensors()

	set_collision_layer_value(1, false)
	set_collision_layer_value(3, true) # слой 3 = враг
	set_collision_mask_value(1, true)  # сталкивается только с миром

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

# Шляпка гриба: верхняя половина эллипса, считается циклом (процедурно!)
func _dome_poly(rx: float, ry: float, base_y: float, segments: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		var a := PI + PI * float(i) / float(segments)
		pts.append(Vector2(cos(a) * rx, base_y + sin(a) * ry))
	pts.append(Vector2(rx, base_y + 6))
	pts.append(Vector2(-rx, base_y + 6))
	return pts

func _build_collision() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 32)
	shape.shape = rect
	call_deferred("add_child", shape)

func _build_visual() -> void:
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	body_root = Node2D.new()
	visual.add_child(body_root)

	var c_cap := Color(0.55, 0.35, 0.2)   # коричневая шляпка
	var c_dark := Color(0.2, 0.15, 0.1)
	var c_metal := Color(0.6, 0.62, 0.66)

	# Ножки-пеньки (топают по очереди)
	foot_l = _poly(body_root, _rect_poly(-6, 0, 6, 7), c_dark, Vector2(-8, 9))
	foot_r = _poly(body_root, _rect_poly(-6, 0, 6, 7), c_dark, Vector2(8, 9))

	# Шляпка-купол
	_poly(body_root, _dome_poly(20, 20, 6), c_cap)

	# Кибер-пластина с заклёпками (половина гриба механическая)
	_poly(body_root, _rect_poly(2, -12, 13, -5), c_metal)
	_poly(body_root, _rect_poly(3.5, -10.5, 5.5, -8.5), Color(0.3, 0.3, 0.35))
	_poly(body_root, _rect_poly(9.5, -10.5, 11.5, -8.5), Color(0.3, 0.3, 0.35))

	# Глаза: левый — органический, правый — светящийся кибер-глаз
	_poly(body_root, _rect_poly(-10, -6, -3, 0), Color(0.95, 0.95, 0.9))
	_poly(body_root, _rect_poly(-8, -4, -5, -1), Color(0.1, 0.1, 0.1))
	cyber_eye = _poly(body_root, _rect_poly(3, -4, 10, 1), Color(1.0, 0.15, 0.15))

	# Злые брови
	var brow_l := _poly(body_root, _rect_poly(-11, -9, -3, -7), c_dark)
	brow_l.rotation = 0.35
	var brow_r := _poly(body_root, _rect_poly(3, -9, 11, -7), c_dark)
	brow_r.rotation = -0.35

	# Зубки-кланги как у гумбы
	_poly(body_root, PackedVector2Array([
		Vector2(-9, 6), Vector2(-4, 6), Vector2(-6.5, 11)
	]), Color(0.95, 0.95, 0.9))
	_poly(body_root, PackedVector2Array([
		Vector2(4, 6), Vector2(9, 6), Vector2(6.5, 11)
	]), Color(0.95, 0.95, 0.9))

	# Антенна с мигающим огоньком
	_poly(body_root, _rect_poly(-1, -20, 1, -13), c_metal)
	antenna_light = _poly(body_root, _rect_poly(-2.5, -24, 2.5, -20), Color(1.0, 0.8, 0.2))

func _build_sensors() -> void:
	# Зона обнаружения (игрок проверяет группу "enemy")
	var hit_area := Area2D.new()
	hit_area.name = "HitArea"
	hit_area.add_to_group("enemy")
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(34, 30)
	hit_shape.shape = hit_rect
	hit_area.add_child(hit_shape)
	hit_area.set_collision_layer_value(4, true)
	hit_area.set_collision_mask_value(4, true)
	call_deferred("add_child", hit_area)

	# Луч-датчик "есть ли пол впереди"
	var ray := RayCast2D.new()
	ray.name = "FloorAhead"
	ray.target_position = Vector2(0, 40)
	ray.set_collision_mask_value(1, true)
	ray.enabled = true
	add_child(ray)

# ========== ПАТРУЛИРОВАНИЕ ==========

func _physics_process(delta: float) -> void:
	if is_dying:
		return
	turn_cooldown -= delta

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	velocity.x = direction * speed
	move_and_slide()

	var ray := $FloorAhead
	ray.position = Vector2(direction * 22, 0)
	ray.force_raycast_update()

	# Разворот у стены/обрыва (только на земле + защита от дёргания)
	if is_on_floor() and turn_cooldown <= 0.0:
		if is_on_wall() or not ray.is_colliding():
			direction *= -1
			turn_cooldown = 0.25
			visual.scale.x = direction

	_animate(delta)

# ========== АНИМАЦИИ ==========

func _animate(delta: float) -> void:
	walk_phase += delta * 10.0
	visual.rotation = sin(walk_phase) * 0.08 # покачивание гумбы
	foot_l.position.y = 9 - max(0.0, sin(walk_phase)) * 3.0
	foot_r.position.y = 9 - max(0.0, sin(walk_phase + PI)) * 3.0
	cyber_eye.color = Color(1.0, 0.15, 0.15, 0.65 + 0.35 * sin(walk_phase * 2.0))
	antenna_light.color = Color(1.0, 0.8, 0.2, 0.5 + 0.5 * sin(walk_phase * 3.0))

# ========== СМЕРТЬ ==========

func die() -> void:
	if is_dying:
		return
	is_dying = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0) # отключаем коллизию безопасно
	var hit_area := get_node_or_null("HitArea")
	if hit_area:
		hit_area.set_deferred("monitoring", false)
	# Плющится как гумба из Марио!
	var tw := create_tween()
	tw.tween_property(body_root, "scale", Vector2(1.4, 0.15), 0.12)
	tw.tween_callback(queue_free)
