class_name PlayerCharacter
extends CharacterBody2D

var body_visual: Polygon2D
var camera: Camera2D
var radius: float = 18.0


func setup(player_radius: float, camera_zoom: float, world_width: float, world_height: float) -> void:
	radius = player_radius
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(20.0)
	_build_collision()
	_build_visual()
	_build_camera(camera_zoom, world_width, world_height)


func aim_visual_at(direction: Vector2) -> void:
	if body_visual != null:
		body_visual.rotation = direction.angle() + PI * 0.5


func reset_visual() -> void:
	if body_visual != null:
		body_visual.rotation = 0.0


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
