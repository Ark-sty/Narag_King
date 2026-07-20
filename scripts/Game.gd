extends Node2D

const IMPACT_DAMAGE = preload("res://scripts/ImpactDamage.gd")
const DIAGONAL_SLIDE_RESPONSE = preload("res://scripts/DiagonalSlideResponse.gd")

const WORLD_WIDTH := 960.0
const WORLD_HEIGHT := 7800.0
const SECTION_COUNT := 5
const SECTION_HEIGHT := WORLD_HEIGHT / SECTION_COUNT
const BACKGROUND_HORIZONTAL_PADDING := 240.0
const PLAYER_START := Vector2(480.0, 120.0)
const PLAYER_RADIUS := 18.0
const CAMERA_ZOOM := 0.75
const GRAVITY := 1150.0
const AIR_CONTROL := 620.0
const AIR_MOVE_SPEED := 430.0
const GROUND_MOVE_SPEED := 520.0
const GROUND_ACCELERATION := 2200.0
const GROUND_BRAKE := 4200.0
const MAX_FALL_SPEED := 1850.0
const LAUNCH_MIN_SPEED := 130.0
const LAUNCH_MAX_SPEED := 490.0
const MAX_CHARGE_TIME := 1.15
const GRAB_SIDE_DISTANCE := 46.0
const GRAB_EDGE_DISTANCE := 54.0
const GRAB_EDGE_VERTICAL_DISTANCE := 16.0
const AUTO_GRAB_EDGE_DISTANCE := 108.0
const AUTO_GRAB_EDGE_VERTICAL_DISTANCE := 52.0
const AUTO_GRAB_COYOTE_MSEC := 180
const GRAB_SNAP_GAP := 1.5
const GRAB_MODE_SIDE := 0
const GRAB_MODE_EDGE := 1
const GRAB_MODE_AUTO_EDGE := 2
const DIAGONAL_SLIDE_GROUP := &"diagonal_slide_surface"
const DIAGONAL_SLIDE_SPEED_RETENTION := 0.78
const DIAGONAL_SURFACE_SIZE := Vector2(460.0, 28.0)
const DIAGONAL_SURFACE_COLOR := Color("#b64343")

@onready var speed_edge_effect: SpeedEdgeEffect = $SpeedEdgeEffect

var player: CharacterBody2D
var player_shape: CollisionShape2D
var player_body: Polygon2D
var camera: Camera2D
var hud_hp: ProgressBar
var hud_charge: ProgressBar
var hud_section: Label
var hud_state: Label
var grabbable_rects: Array[Rect2] = []
var hp: int = 100
var charge: float = 0.0
var is_charging_launch: bool = false
var state: String = "falling"
var last_damage_msec: int = -1000
var status_message_until_msec: int = 0
var auto_grab_until_msec: int = 0
var active_diagonal_surface: Object


func _ready() -> void:
	_build_world()
	_build_player()
	_build_hud()
	_reset_player()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_reset_player()

	if state == "grabbed":
		_update_grabbed(delta)
	else:
		_update_falling(delta)

	_update_hud()


func _build_world() -> void:
	var section_colors: Array[Color] = [
		Color.html("#1d2730"),
		Color.html("#26322d"),
		Color.html("#302c3b"),
		Color.html("#342c28"),
		Color.html("#202b3d"),
	]

	for section in SECTION_COUNT:
		var top: float = float(section) * SECTION_HEIGHT
		_add_rect(
			"Section%dBackground" % (section + 1),
			Vector2(WORLD_WIDTH * 0.5, top + SECTION_HEIGHT * 0.5),
			Vector2(WORLD_WIDTH + BACKGROUND_HORIZONTAL_PADDING * 2.0, SECTION_HEIGHT),
			section_colors[section],
			false,
			-20
		)
		_add_label_marker(section, top)

	_add_rect("LeftWall", Vector2(-16.0, WORLD_HEIGHT * 0.5), Vector2(32.0, WORLD_HEIGHT), Color.html("#56616b"), true, 0, false)
	_add_rect("RightWall", Vector2(WORLD_WIDTH + 16.0, WORLD_HEIGHT * 0.5), Vector2(32.0, WORLD_HEIGHT), Color.html("#56616b"), true, 0, false)
	_add_rect("StartCeiling", Vector2(WORLD_WIDTH * 0.5, -16.0), Vector2(WORLD_WIDTH, 32.0), Color.html("#56616b"), true, 0, false)
	_add_rect("FinishFloor", Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT + 18.0), Vector2(WORLD_WIDTH, 36.0), Color.html("#8fbf6a"), true, 0, false)

	var safe_platforms: Array[Array] = [
		[Vector2(370, 360), Vector2(380, 32)], [Vector2(420, 1390), Vector2(260, 32)],
		[Vector2(210, 1720), Vector2(250, 30)], [Vector2(650, 2920), Vector2(260, 30)],
		[Vector2(450, 3240), Vector2(300, 30)], [Vector2(260, 4380), Vector2(330, 30)],
		[Vector2(690, 4720), Vector2(260, 28)], [Vector2(560, 5900), Vector2(360, 28)],
		[Vector2(320, 6240), Vector2(280, 28)], [Vector2(585, 7460), Vector2(390, 28)],
	]

	for i in safe_platforms.size():
		var entry: Array = safe_platforms[i]
		var platform_position: Vector2 = entry[0] as Vector2
		var platform_size: Vector2 = entry[1] as Vector2
		_add_rect("SafePlatform%d" % i, platform_position, platform_size, _platform_color(platform_position.y), true, 1, true)

	var diagonal_surfaces: Array[Array] = [
		[Vector2(650, 660), 32.0], [Vector2(320, 1080), -32.0],
		[Vector2(330, 2050), 32.0], [Vector2(680, 2520), -32.0],
		[Vector2(700, 3570), -32.0], [Vector2(270, 4020), 32.0],
		[Vector2(650, 5070), -32.0], [Vector2(310, 5520), 32.0],
		[Vector2(300, 6590), 32.0], [Vector2(680, 7040), -32.0],
	]
	for i in diagonal_surfaces.size():
		var entry: Array = diagonal_surfaces[i]
		_add_diagonal_surface(
			"DiagonalSurface%d" % i,
			entry[0] as Vector2,
			float(entry[1])
		)

	var grip_posts: Array[Array] = [
		[Vector2(110, 1180), Vector2(40, 230)], [Vector2(850, 1660), Vector2(40, 260)], [Vector2(120, 3030), Vector2(40, 280)],
		[Vector2(850, 4210), Vector2(40, 260)], [Vector2(110, 5360), Vector2(40, 300)], [Vector2(840, 6980), Vector2(40, 320)],
	]
	for i in grip_posts.size():
		var entry: Array = grip_posts[i]
		var post_position: Vector2 = entry[0] as Vector2
		var post_size: Vector2 = entry[1] as Vector2
		_add_rect("GripPost%d" % i, post_position, post_size, Color.html("#78909c"), true, 1, true)


func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_max_angle = deg_to_rad(20.0)
	add_child(player)

	player_shape = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = PLAYER_RADIUS
	player_shape.shape = circle
	player.add_child(player_shape)

	player_body = Polygon2D.new()
	player_body.color = Color.html("#f5d06f")
	player_body.polygon = PackedVector2Array([
		Vector2(0, -24), Vector2(18, -6), Vector2(13, 20), Vector2(-13, 20), Vector2(-18, -6)
	])
	player.add_child(player_body)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_right = int(WORLD_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = int(WORLD_HEIGHT)
	player.add_child(camera)


func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "HUD"
	canvas.layer = 20
	add_child(canvas)

	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.04, 0.05, 0.06, 0.78)
	panel.position = Vector2(16, 14)
	panel.size = Vector2(300, 104)
	canvas.add_child(panel)

	hud_hp = ProgressBar.new()
	hud_hp.position = Vector2(28, 26)
	hud_hp.size = Vector2(180, 20)
	hud_hp.max_value = 100
	hud_hp.show_percentage = false
	canvas.add_child(hud_hp)

	hud_charge = ProgressBar.new()
	hud_charge.position = Vector2(28, 56)
	hud_charge.size = Vector2(180, 20)
	hud_charge.max_value = 100
	hud_charge.show_percentage = false
	canvas.add_child(hud_charge)

	hud_section = Label.new()
	hud_section.position = Vector2(224, 24)
	hud_section.size = Vector2(76, 24)
	canvas.add_child(hud_section)

	hud_state = Label.new()
	hud_state.position = Vector2(28, 84)
	hud_state.size = Vector2(270, 22)
	canvas.add_child(hud_state)


func _update_falling(delta: float) -> void:
	var was_on_floor: bool = player.is_on_floor()
	var axis_x: float = Input.get_axis("move_left", "move_right")
	var target_speed: float = AIR_MOVE_SPEED
	var acceleration: float = AIR_CONTROL
	if was_on_floor:
		target_speed = GROUND_MOVE_SPEED
		acceleration = GROUND_ACCELERATION
		if absf(axis_x) < 0.01:
			acceleration = GROUND_BRAKE
	player.velocity.x = move_toward(player.velocity.x, axis_x * target_speed, acceleration * delta)
	player.velocity.y = minf(player.velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	speed_edge_effect.set_speed_ratio(IMPACT_DAMAGE.get_warning_ratio(maxf(0.0, player.velocity.y)))

	var incoming_velocity: Vector2 = player.velocity
	player.move_and_slide()
	var diagonal_collision := _find_diagonal_slide_collision()
	if diagonal_collision:
		_handle_diagonal_slide(incoming_velocity, diagonal_collision)
		return
	active_diagonal_surface = null

	var is_on_floor: bool = player.is_on_floor()
	if is_on_floor:
		auto_grab_until_msec = 0
		if not was_on_floor:
			var landing_speed := _impact_speed_against_normal(incoming_velocity, player.get_floor_normal())
			if _apply_impact_damage("착지", landing_speed):
				return
		if Input.is_action_pressed("grab"):
			_try_side_grab(GRAB_MODE_EDGE, true)
		return

	if player.velocity.y > 0.0:
		if was_on_floor:
			auto_grab_until_msec = Time.get_ticks_msec() + AUTO_GRAB_COYOTE_MSEC

		if Input.is_action_pressed("grab") and _try_side_grab(GRAB_MODE_SIDE, true):
			return
		if Time.get_ticks_msec() <= auto_grab_until_msec and _try_side_grab(GRAB_MODE_AUTO_EDGE, false):
			return

	var collision_count: int = player.get_slide_collision_count()
	if collision_count > 0:
		var best_collision: KinematicCollision2D = player.get_slide_collision(0)
		for i in range(collision_count):
			var collision: KinematicCollision2D = player.get_slide_collision(i)
			if collision.get_normal().y < best_collision.get_normal().y:
				best_collision = collision

		if best_collision.get_normal().y > -0.65:
			var collision_speed := _impact_speed_against_normal(incoming_velocity, best_collision.get_normal())
			if _apply_impact_damage("충돌", collision_speed):
				return
			player.velocity = player.velocity.bounce(best_collision.get_normal()) * 0.28
			player.velocity.y = minf(player.velocity.y, 120.0)


func _update_grabbed(delta: float) -> void:
	active_diagonal_surface = null
	speed_edge_effect.set_speed_ratio(0.0)
	player.velocity = Vector2.ZERO

	var aim: Vector2 = _get_aim_direction()
	player_body.rotation = aim.angle() + PI * 0.5

	if Input.is_action_just_pressed("charge_launch"):
		is_charging_launch = true
		charge = 0.0

	if Input.is_action_pressed("charge_launch"):
		is_charging_launch = true
		charge = minf(charge + delta / MAX_CHARGE_TIME, 1.0)

	if is_charging_launch and Input.is_action_just_released("charge_launch"):
		var speed: float = lerpf(LAUNCH_MIN_SPEED, LAUNCH_MAX_SPEED, charge)
		player.velocity = aim * speed
		state = "falling"
		charge = 0.0
		is_charging_launch = false


func _try_side_grab(grab_mode: int, require_grab_key: bool) -> bool:
	if require_grab_key and not Input.is_action_pressed("grab"):
		return false

	var player_position: Vector2 = player.global_position
	for i in grabbable_rects.size():
		var rect: Rect2 = grabbable_rects[i]
		var left_side_x: float = rect.position.x
		var right_side_x: float = rect.end.x
		if _can_grab_side(rect, left_side_x, -1.0, player_position, grab_mode):
			_grab_terrain(rect, left_side_x, -1.0, grab_mode)
			return true
		if _can_grab_side(rect, right_side_x, 1.0, player_position, grab_mode):
			_grab_terrain(rect, right_side_x, 1.0, grab_mode)
			return true

	return false


func _can_grab_side(rect: Rect2, side_x: float, side_direction: float, player_position: Vector2, grab_mode: int) -> bool:
	var horizontal_gap: float = absf(player_position.x - side_x) - PLAYER_RADIUS
	var side_distance: float = GRAB_SIDE_DISTANCE
	if grab_mode == GRAB_MODE_EDGE:
		side_distance = GRAB_EDGE_DISTANCE
	elif grab_mode == GRAB_MODE_AUTO_EDGE:
		side_distance = AUTO_GRAB_EDGE_DISTANCE
	if horizontal_gap < -PLAYER_RADIUS * 0.35 or horizontal_gap > side_distance:
		return false

	var is_on_correct_side: bool = false
	if side_direction < 0.0:
		is_on_correct_side = player_position.x < side_x
	else:
		is_on_correct_side = player_position.x > side_x
	if not is_on_correct_side:
		return false

	var player_feet_y: float = player_position.y + PLAYER_RADIUS
	var is_beside_face: bool = player_position.y >= rect.position.y + minf(PLAYER_RADIUS * 0.35, rect.size.y * 0.5) and player_position.y <= rect.end.y + PLAYER_RADIUS * 0.35
	var edge_vertical_distance: float = GRAB_EDGE_VERTICAL_DISTANCE
	if grab_mode == GRAB_MODE_AUTO_EDGE:
		edge_vertical_distance = AUTO_GRAB_EDGE_VERTICAL_DISTANCE
	var is_near_top_edge: bool = grab_mode != GRAB_MODE_SIDE and absf(player_feet_y - rect.position.y) <= edge_vertical_distance
	if grab_mode != GRAB_MODE_SIDE:
		return is_near_top_edge
	return is_beside_face


func _grab_terrain(rect: Rect2, side_x: float, side_direction: float, grab_mode: int) -> void:
	var grab_speed := maxf(0.0, player.velocity.y)
	if _apply_impact_damage("잡기", grab_speed):
		return
	state = "grabbed"
	player.velocity = Vector2.ZERO
	auto_grab_until_msec = 0
	player.global_position.x = side_x + side_direction * (PLAYER_RADIUS + GRAB_SNAP_GAP)
	if grab_mode != GRAB_MODE_SIDE:
		player.global_position.y = rect.position.y + minf(PLAYER_RADIUS * 0.7, rect.size.y * 0.5)
	else:
		var min_y: float = rect.position.y + minf(4.0, rect.size.y * 0.25)
		var max_y: float = rect.end.y - minf(4.0, rect.size.y * 0.25)
		player.global_position.y = clampf(player.global_position.y, min_y, max_y)
	charge = 0.0
	is_charging_launch = false


func _impact_speed_against_normal(incoming_velocity: Vector2, surface_normal: Vector2) -> float:
	return maxf(0.0, -incoming_velocity.dot(surface_normal))


func _find_diagonal_slide_collision() -> KinematicCollision2D:
	for collision_index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(collision_index)
		var collider := collision.get_collider()
		if collider is Node and (collider as Node).is_in_group(DIAGONAL_SLIDE_GROUP):
			return collision
	return null


func _handle_diagonal_slide(
	incoming_velocity: Vector2,
	collision: KinematicCollision2D
) -> void:
	var collider := collision.get_collider()
	if collider == active_diagonal_surface:
		return

	active_diagonal_surface = collider
	auto_grab_until_msec = 0
	var surface_normal := collision.get_normal()
	var impact_speed: float = DIAGONAL_SLIDE_RESPONSE.impact_speed(
		incoming_velocity,
		surface_normal
	)
	if _apply_impact_damage("경사면", impact_speed):
		return
	player.velocity = DIAGONAL_SLIDE_RESPONSE.slide_velocity(
		incoming_velocity,
		surface_normal,
		DIAGONAL_SLIDE_SPEED_RETENTION
	)


func _apply_impact_damage(reason: String, impact_speed: float) -> bool:
	var damage: int = IMPACT_DAMAGE.damage_for_speed(impact_speed)
	if damage <= 0:
		return false

	var now: int = Time.get_ticks_msec()
	if now - last_damage_msec < 450:
		return false

	hp = maxi(0, hp - damage)
	last_damage_msec = now
	status_message_until_msec = now + 900
	hud_state.text = "%s 충격 %d · 피해 -%d" % [reason, int(round(impact_speed)), damage]
	speed_edge_effect.flash_damage(IMPACT_DAMAGE.get_damage_ratio(impact_speed))

	if hp <= 0:
		_reset_player()
		return true
	return false


func _get_aim_direction() -> Vector2:
	var direction: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN
	return direction.normalized()


func _reset_player() -> void:
	hp = 100
	charge = 0.0
	is_charging_launch = false
	state = "falling"
	last_damage_msec = -1000
	status_message_until_msec = 0
	auto_grab_until_msec = 0
	player.global_position = PLAYER_START
	player.velocity = Vector2(0.0, 80.0)
	player_body.rotation = 0.0
	speed_edge_effect.set_speed_ratio(0.0)
	active_diagonal_surface = null


func _update_hud() -> void:
	hud_hp.value = hp
	hud_charge.value = charge * 100.0
	var section: int = clampi(int(player.global_position.y / SECTION_HEIGHT) + 1, 1, SECTION_COUNT)
	hud_section.text = "%d / %d" % [section, SECTION_COUNT]
	if Time.get_ticks_msec() < status_message_until_msec:
		return

	if state == "grabbed":
		hud_state.text = "잡는 중"
	elif hp > 0:
		hud_state.text = "낙하 중"


func _add_rect(node_name: String, center: Vector2, size: Vector2, color: Color, solid: bool, z: int, grabbable: bool = false) -> void:
	var body: Node2D
	if solid:
		var static_body: StaticBody2D = StaticBody2D.new()
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		body = static_body
	else:
		body = Node2D.new()

	body.name = node_name
	body.position = center
	body.z_index = z
	add_child(body)

	if solid:
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = size
		collision_shape.shape = rect_shape
		body.add_child(collision_shape)
		if grabbable:
			grabbable_rects.append(Rect2(center - size * 0.5, size))

	var visual: Polygon2D = Polygon2D.new()
	visual.color = color
	visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	body.add_child(visual)


func _add_diagonal_surface(
	node_name: String,
	center: Vector2,
	angle_degrees: float
) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = center
	body.rotation = deg_to_rad(angle_degrees)
	body.collision_layer = 1
	body.collision_mask = 0
	body.z_index = 1
	body.add_to_group(DIAGONAL_SLIDE_GROUP)
	add_child(body)

	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = DIAGONAL_SURFACE_SIZE
	collision_shape.shape = rect_shape
	body.add_child(collision_shape)

	var half_size := DIAGONAL_SURFACE_SIZE * 0.5
	var visual := Polygon2D.new()
	visual.color = DIAGONAL_SURFACE_COLOR
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	body.add_child(visual)


func _add_label_marker(section: int, top: float) -> void:
	var label: Label = Label.new()
	label.text = "PART %d" % (section + 1)
	label.position = Vector2(34, top + 34)
	label.modulate = Color(1, 1, 1, 0.38)
	label.z_index = -5
	add_child(label)


func _platform_color(y: float) -> Color:
	var section: int = clampi(int(y / SECTION_HEIGHT), 0, SECTION_COUNT - 1)
	var colors: Array[Color] = [Color.html("#9aa6b2"), Color.html("#94a886"), Color.html("#a098b7"), Color.html("#b09180"), Color.html("#7fa2bd")]
	return colors[section]
