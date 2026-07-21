class_name PlayerCharacter
extends CharacterBody2D

const STRETCH_RATE := 3.6
const STRETCH_MAX_SCALE := 0.28
const LANDING_SQUASH_SCALE := 0.34
const LANDING_SQUASH_DURATION := 0.22

var body_visual: Polygon2D
var camera: Camera2D
var radius: float = 18.0

var _target_fall_ratio: float = 0.0
var _displayed_fall_ratio: float = 0.0
var _squash_scale: Vector2 = Vector2.ONE
var _squash_tween: Tween


func setup(player_radius: float, camera_zoom: float, world_width: float, world_height: float) -> void:
	radius = player_radius
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(20.0)
	_build_collision()
	_build_visual()
	_build_camera(camera_zoom, world_width, world_height)


func _process(delta: float) -> void:
	_displayed_fall_ratio = move_toward(_displayed_fall_ratio, _target_fall_ratio, STRETCH_RATE * delta)
	_apply_visual_scale()


func aim_visual_at(direction: Vector2) -> void:
	if body_visual != null:
		body_visual.rotation = direction.angle() + PI * 0.5


func set_fall_stretch(ratio: float) -> void:
	_target_fall_ratio = clampf(ratio, 0.0, 1.0)


func trigger_landing_squash(strength: float) -> void:
	if body_visual == null:
		return
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()

	var pulse: float = clampf(strength, 0.0, 1.0)
	_squash_scale = Vector2(1.0 + LANDING_SQUASH_SCALE * pulse, 1.0 - LANDING_SQUASH_SCALE * pulse)
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "_squash_scale", Vector2.ONE, LANDING_SQUASH_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func reset_visual() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_target_fall_ratio = 0.0
	_displayed_fall_ratio = 0.0
	_squash_scale = Vector2.ONE
	if body_visual != null:
		body_visual.rotation = 0.0
		body_visual.scale = Vector2.ONE


func _apply_visual_scale() -> void:
	if body_visual == null:
		return
	var stretch: Vector2 = Vector2(1.0 - STRETCH_MAX_SCALE * _displayed_fall_ratio * 0.5, 1.0 + STRETCH_MAX_SCALE * _displayed_fall_ratio)
	body_visual.scale = _squash_scale * stretch


func _build_collision() -> void:
	var player_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_shape == null:
		player_shape = CollisionShape2D.new()
		player_shape.name = "CollisionShape2D"
		add_child(player_shape)

	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	player_shape.shape = circle


func _build_visual() -> void:
	body_visual = get_node_or_null("Visual") as Polygon2D
	if body_visual == null:
		body_visual = Polygon2D.new()
		body_visual.name = "Visual"
		add_child(body_visual)

	body_visual.color = Color.html("#f5d06f")
	body_visual.polygon = PackedVector2Array([
		Vector2(0.0, -24.0),
		Vector2(18.0, -6.0),
		Vector2(13.0, 20.0),
		Vector2(-13.0, 20.0),
		Vector2(-18.0, -6.0),
	])


func _build_camera(camera_zoom: float, world_width: float, world_height: float) -> void:
	camera = get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)

	camera.enabled = true
	camera.zoom = Vector2.ONE * camera_zoom
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_right = int(world_width)
	camera.limit_top = 0
	camera.limit_bottom = int(world_height)
