extends Node2D
## ГЕНЕРАТОР КОМНАТ v2.8 — ФИНАЛЬНАЯ СБОРКА
## Космос, лава, небесный мост, бесконечный портал и НЕЗАЛИПАЮЩИЕ мобильные кнопки.
## Всё из кода. Ноль ассетов.

@export var room_width: float = 1600.0
@export var room_height: float = 700.0
@export var force_mobile_ui: bool = true # true = кнопки видны на ПК для теста

var current_index: int = 0
var player: CharacterBody2D
var camera: Camera2D
var rooms: Array = []
var score_label: Label
var stars_far: Node2D
var stars_near: Node2D

# ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========

func _create_mobile_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	# toggle_mode УБРАН! Кнопка больше не залипает.
	btn.custom_minimum_size = Vector2(120, 120)
	btn.add_theme_font_size_override("font_size", 48)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1.0))
	
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1, 1, 1, 0.3)
	btn.add_theme_stylebox_override("normal", style)
	
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(color.r, color.g, color.b, 0.8)
	style_pressed.corner_radius_top_left = 60
	style_pressed.corner_radius_top_right = 60
	style_pressed.corner_radius_bottom_left = 60
	style_pressed.corner_radius_bottom_right = 60
	style_pressed.border_width_left = 3
	style_pressed.border_width_right = 3
	style_pressed.border_width_top = 3
	style_pressed.border_width_bottom = 3
	style_pressed.border_color = Color(1, 1, 1, 0.5)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	return btn

func _mobile_input_pressed(action: String) -> void:
	Input.action_press(action)

func _mobile_input_released(action: String) -> void:
	Input.action_release(action)

func _add_planet(parent: Node, pos: Vector2, r: float, color: Color) -> void:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	p.polygon = pts
	p.color = color
	p.position = pos
	parent.add_child(p)

func _on_lava_touched(body: Node) -> void:
	if body.has_method("die"):
		body.die()

func _on_exit_entered(body: Node, index: int) -> void:
	if not body.is_in_group("player"):
		return
	if index != current_index:
		return
	current_index += 1
	score_label.text = "КОСМОС-ЗАБЕГ | КОМНАТА: %d | ХАОС: %d%%" % [current_index + 1, current_index * 12]
	_generate_room(current_index + 1)
	if rooms.size() > 3:
		var old_room: Node2D = rooms.pop_front()
		old_room.queue_free()

# ========== НАСТРОЙКИ МИРА ==========

func _setup_background() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	add_child(bg_layer)

	stars_far = Node2D.new()
	stars_near = Node2D.new()
	add_child(stars_far)
	add_child(stars_near)
	for i in 120:
		var s := ColorRect.new()
		var sz := randf_range(1.0, 2.0)
		s.size = Vector2(sz, sz)
		s.position = Vector2(randf_range(-500, 30000), randf_range(-800, 1600))
		s.color = Color(1, 1, 1, randf_range(0.3, 0.9))
		stars_far.add_child(s)
	for i in 60:
		var s := ColorRect.new()
		var sz := randf_range(2.0, 3.5)
		s.size = Vector2(sz, sz)
		s.position = Vector2(randf_range(-500, 30000), randf_range(-800, 1600))
		s.color = Color(randf_range(0.7, 1.0), randf_range(0.7, 1.0), 1.0, randf_range(0.5, 1.0))
		stars_near.add_child(s)
	_add_planet(stars_far, Vector2(2500, 100), 90, Color(0.4, 0.2, 0.5))
	_add_planet(stars_far, Vector2(9000, 300), 140, Color(0.2, 0.4, 0.45))

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.text = "КОСМОС-ЗАБЕГ | КОМНАТА: 1 | ХАОС: 0%"
	layer.add_child(score_label)

# ========== МОБИЛЬНОЕ УПРАВЛЕНИЕ (НЕ ЗАЛИПАЕТ!) ==========

func _setup_mobile_ui() -> void:
	var is_touch := DisplayServer.is_touchscreen_available()
	if not is_touch and not force_mobile_ui:
		return
	
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var screen := get_viewport().get_visible_rect().size
	var btn_size := 120.0
	var margin := 40.0
	var y := screen.y - btn_size - margin

	var btn_left: Button = _create_mobile_button("◀", Color(0.3, 0.7, 1.0))
	btn_left.position = Vector2(margin, y)
	btn_left.button_down.connect(func(): _mobile_input_pressed("ui_left"))
	btn_left.button_up.connect(func(): _mobile_input_released("ui_left"))
	layer.add_child(btn_left)

	var btn_right: Button = _create_mobile_button("▶", Color(0.3, 0.7, 1.0))
	btn_right.position = Vector2(margin + btn_size + 20, y)
	btn_right.button_down.connect(func(): _mobile_input_pressed("ui_right"))
	btn_right.button_up.connect(func(): _mobile_input_released("ui_right"))
	layer.add_child(btn_right)

	var btn_jump: Button = _create_mobile_button("▲", Color(0.4, 1.0, 0.5))
	btn_jump.position = Vector2(screen.x - btn_size - margin, y)
	btn_jump.button_down.connect(func(): _mobile_input_pressed("ui_accept"))
	btn_jump.button_up.connect(func(): _mobile_input_released("ui_accept"))
	layer.add_child(btn_jump)
	
	print("✅ МОБИЛЬНЫЕ КНОПКИ СОЗДАНЫ!")

# ========== СПАВН ИГЕНЕРАЦИЯ ==========

func _spawn_player(pos: Vector2) -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load("res://player.gd"))
	player.position = pos
	add_child(player)

func _generate_room(index: int) -> Vector2:
	var room := Node2D.new()
	room.name = "Room_" + str(index)
	room.position.x = index * room_width
	add_child(room)
	rooms.append(room)

	_generate_lava(room)

	# НЕБЕСНЫЙ МОСТ: цепочка платформ у самого верха
	var x := 160.0
	var y := 240.0 # линия генерации — высоко над лавой
	var first_top := Vector2(x, y)
	_spawn_platform(room, Vector2(x, y), 240.0) # стартовая пошире
	var last_y := y
	while x < room_width - 260.0:
		x += randf_range(140.0, 230.0)
		y = clamp(y + randf_range(-100.0, 140.0), 140.0, 420.0)
		var w := randf_range(100.0, 180.0)
		_spawn_platform(room, Vector2(x, y), w)
		if randf() < 0.35:
			_spawn_enemy(room, Vector2(x, y - 30))
		last_y = y

	# Финишная платформа с порталом
	x = room_width - 140.0
	y = clamp(last_y + randf_range(-80.0, 80.0), 140.0, 420.0)
	_spawn_platform(room, Vector2(x, y), 200.0)
	_spawn_exit(room, index, Vector2(x, y - 80))

	return first_top - Vector2(0, 40)

func _generate_lava(room: Node2D) -> void:
	var lava := Area2D.new()
	lava.position = Vector2(room_width / 2, room_height + 60)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(room_width + 400, 160)
	shape.shape = rect
	lava.add_child(shape)
	lava.set_collision_mask_value(1, false)
	lava.set_collision_mask_value(2, true)
	lava.set_collision_mask_value(3, true)
	lava.body_entered.connect(_on_lava_touched)
	room.call_deferred("add_child", lava)

	var sea := ColorRect.new()
	sea.size = Vector2(room_width + 400, 200)
	sea.color = Color(0.9, 0.25, 0.05)
	sea.position = Vector2(-200, room_height)
	room.add_child(sea)
	var glow := ColorRect.new()
	glow.size = Vector2(room_width + 400, 12)
	glow.color = Color(1.0, 0.7, 0.1)
	glow.position = Vector2(-200, room_height - 6)
	room.add_child(glow)
	for i in range(int(room_width / 60)):
		var flame := Polygon2D.new()
		flame.polygon = PackedVector2Array([
			Vector2(-14, 0), Vector2(14, 0), Vector2(0, -randf_range(20, 46))
		])
		flame.color = Color(1.0, randf_range(0.4, 0.75), 0.1, 0.85)
		flame.position = Vector2(i * 60 + randf_range(0, 30), room_height + 2)
		room.add_child(flame)

func _spawn_platform(room: Node2D, pos: Vector2, w: float) -> void:
	var platform := StaticBody2D.new()
	platform.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 20)
	shape.shape = rect
	platform.add_child(shape)
	var visual := ColorRect.new()
	visual.size = Vector2(w, 20)
	visual.color = Color(0.25, 0.28, 0.35)
	visual.position = Vector2(-w / 2, -10)
	platform.add_child(visual)
	var neon := ColorRect.new()
	neon.size = Vector2(w, 4)
	neon.color = Color(0.3, 0.9, 1.0)
	neon.position = Vector2(-w / 2, -10)
	platform.add_child(neon)
	room.call_deferred("add_child", platform)

func _spawn_enemy(room: Node2D, pos: Vector2) -> void:
	var enemy := CharacterBody2D.new()
	enemy.set_script(load("res://enemy.gd"))
	enemy.position = pos
	room.call_deferred("add_child", enemy)

func _spawn_exit(room: Node2D, index: int, pos: Vector2) -> void:
	var exit_area := Area2D.new()
	exit_area.position = Vector2(pos.x, room_height / 2)
	var exit_shape := CollisionShape2D.new()
	var exit_rect := RectangleShape2D.new()
	exit_rect.size = Vector2(60, 10000)
	exit_shape.shape = exit_rect
	exit_area.add_child(exit_shape)
	exit_area.set_collision_layer_value(4, true)
	exit_area.set_collision_mask_value(2, true)
	exit_area.body_entered.connect(_on_exit_entered.bind(index))
	room.call_deferred("add_child", exit_area)

	var glow := ColorRect.new()
	glow.size = Vector2(40, 10000)
	glow.color = Color(0.2, 0.9, 0.3, 0.15)
	glow.position = Vector2(-20, -5000)
	exit_area.add_child(glow)

	var visual := ColorRect.new()
	visual.size = Vector2(12, 10000)
	visual.color = Color(0.3, 1.0, 0.4, 0.8)
	visual.position = Vector2(-6, -5000)
	exit_area.add_child(visual)

# ========== ГЛАВНАЯ ФУНКЦИЯ ==========

func _ready() -> void:
	randomize()
	_setup_background()
	_setup_camera()
	_setup_ui()
	_setup_mobile_ui()
	var spawn_point: Vector2 = _generate_room(0)
	_generate_room(1)
	_spawn_player(spawn_point)

func _process(_delta: float) -> void:
	if player and camera:
		var target := player.position
		target.y -= 80
		camera.position = camera.position.lerp(target, 0.12)
		stars_far.position = camera.position * 0.8
		stars_near.position = camera.position * 0.6
