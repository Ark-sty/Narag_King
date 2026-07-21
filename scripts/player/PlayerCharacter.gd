class_name PlayerCharacter
extends CharacterBody2D

const STRETCH_RATE := 3.6
const STRETCH_MAX_SCALE := 0.28
const LANDING_SQUASH_SCALE := 0.34
const LANDING_SQUASH_DURATION := 0.22
const SHAKE_DECAY_RATE := 2.0
const SHAKE_MAX_OFFSET := 14.0
const SHAKE_TRAUMA_DEADZONE := 0.08
const BASE_VISUAL_SCALE := 1.0
const COLLISION_HEIGHT_MARGIN := 8.0
const LAUNCH_BURST_FRAME_DURATION := 0.1

const BODY_TEXTURE := preload("uid://nh7754r286wo")
const LAUNCH_CHARGE_TEXTURES: Array[Texture2D] = [
	preload("uid://dgbkem2bgnvde"),
	preload("uid://b5xxf4njb7dep"),
	preload("uid://c1lmuse3whya7"),
]
const LAUNCH_BURST_TEXTURES: Array[Texture2D] = [
	preload("uid://krth4lyry8er"),
	preload("uid://b4t8xy26hnl24"),
	preload("uid://0o6kn154dj3r"),
]

var body_visual: Sprite2D
var camera: Camera2D
var radius: float = 18.0

var _target_fall_ratio: float = 0.0
var _displayed_fall_ratio: float = 0.0
var _squash_scale: Vector2 = Vector2.ONE
var _squash_tween: Tween
var _camera_trauma: float = 0.0
var _launch_burst_elapsed: float = -1.0


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
	_camera_trauma = move_toward(_camera_trauma, 0.0, SHAKE_DECAY_RATE * delta)
	_apply_camera_shake()
	_advance_launch_burst(delta)


func aim_visual_at(direction: Vector2) -> void:
	if body_visual == null:
		return
	if direction.x > 0.01:
		body_visual.flip_h = false
	elif direction.x < -0.01:
		body_visual.flip_h = true


func set_charge_visual(charge_ratio: float) -> void:
	if body_visual == null:
		return
	if charge_ratio <= 0.0:
		body_visual.texture = BODY_TEXTURE
		return
	var index: int = clampi(int(charge_ratio * LAUNCH_CHARGE_TEXTURES.size()), 0, LAUNCH_CHARGE_TEXTURES.size() - 1)
	body_visual.texture = LAUNCH_CHARGE_TEXTURES[index]


func play_launch_burst() -> void:
	if body_visual == null:
		return
	_launch_burst_elapsed = 0.0
	body_visual.texture = LAUNCH_BURST_TEXTURES[0]


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


func add_camera_trauma(amount: float) -> void:
	if amount < SHAKE_TRAUMA_DEADZONE:
		return
	_camera_trauma = clampf(_camera_trauma + amount, 0.0, 1.0)


func reset_visual() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_target_fall_ratio = 0.0
	_displayed_fall_ratio = 0.0
	_squash_scale = Vector2.ONE
	_camera_trauma = 0.0
	_launch_burst_elapsed = -1.0
	if body_visual != null:
		body_visual.flip_h = false
		body_visual.scale = Vector2.ONE * BASE_VISUAL_SCALE
		body_visual.texture = BODY_TEXTURE
	if camera != null:
		camera.offset = Vector2.ZERO


func _apply_visual_scale() -> void:
	if body_visual == null:
		return
	var stretch: Vector2 = Vector2(1.0 - STRETCH_MAX_SCALE * _displayed_fall_ratio * 0.5, 1.0 + STRETCH_MAX_SCALE * _displayed_fall_ratio)
	body_visual.scale = _squash_scale * stretch * BASE_VISUAL_SCALE


func _apply_camera_shake() -> void:
	if camera == null:
		return
	var shake_strength: float = _camera_trauma * _camera_trauma
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAX_OFFSET * shake_strength


func _advance_launch_burst(delta: float) -> void:
	if _launch_burst_elapsed < 0.0:
		return
	_launch_burst_elapsed += delta
	var index: int = int(_launch_burst_elapsed / LAUNCH_BURST_FRAME_DURATION)
	if index >= LAUNCH_BURST_TEXTURES.size():
		_launch_burst_elapsed = -1.0
		if body_visual != null:
			body_visual.texture = BODY_TEXTURE
		return
	if body_visual != null:
		body_visual.texture = LAUNCH_BURST_TEXTURES[index]


func _collision_half_height() -> float:
	return radius + COLLISION_HEIGHT_MARGIN * 0.5


func _build_collision() -> void:
	var player_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_shape == null:
		player_shape = CollisionShape2D.new()
		player_shape.name = "CollisionShape2D"
		add_child(player_shape)

	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = radius * 2.0 + COLLISION_HEIGHT_MARGIN
	player_shape.shape = capsule


func _build_visual() -> void:
	body_visual = get_node_or_null("Visual") as Sprite2D
	if body_visual == null:
		body_visual = Sprite2D.new()
		body_visual.name = "Visual"
		add_child(body_visual)

	body_visual.texture = BODY_TEXTURE
	body_visual.centered = true
	body_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_visual.position = Vector2(0.0, _collision_half_height())
	body_visual.offset = Vector2(0.0, -BODY_TEXTURE.get_height() * 0.5)


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
