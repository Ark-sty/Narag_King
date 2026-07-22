extends Node2D

const IMPACT_DAMAGE = preload("res://scripts/ImpactDamage.gd")
const DIAGONAL_SLIDE_RESPONSE = preload("res://scripts/DiagonalSlideResponse.gd")
const PLAYER_CHARACTER = preload("res://scripts/player/PlayerCharacter.gd")
const GAME_HUD = preload("res://scripts/ui/GameHud.gd")
const GRAB_SYSTEM = preload("res://scripts/player/GrabSystem.gd")

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
const GRAB_INPUT_BUFFER_MSEC := 120
const GRAB_MODE_SIDE := 0
const GRAB_MODE_EDGE := 1
const DIAGONAL_SLIDE_GROUP := &"diagonal_slide_surface"
const NO_FRICTION_WALL_GROUP := &"no_friction_wall"
const DIAGONAL_SLIDE_SPEED_RETENTION := 0.78
const GRAB_DAMAGE_MULTIPLIER := 0.5
const DEATH_HOLD_DURATION := 1.0

@onready var level: Node = $Level01
@onready var death_hands_hazard: Node = $DeathHandsHazard
@onready var speed_edge_effect: CanvasLayer = $SpeedEdgeEffect

var player: CharacterBody2D
var hud: CanvasLayer
var grab_system: RefCounted
var hp: int = 100
var charge: float = 0.0
var is_charging_launch: bool = false
var state: String = "falling"
var last_damage_msec: int = -1000
var active_diagonal_surface: Object = null
var death_hold_elapsed: float = 0.0


func _ready() -> void:
	death_hands_hazard.call("configure", float(level.get("world_width")), float(level.get("world_height")))
	_build_player()
	_build_hud()
	_build_grab_system()
	_reset_player()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_reset_player()
	if state != "grabbed" and Input.is_action_just_pressed("grab"):
		grab_system.call("buffer_input", GRAB_INPUT_BUFFER_MSEC)

	if state == "grabbed":
		_update_grabbed(delta)
	elif state == "dead":
		_update_dead(delta)
	else:
		_update_falling(delta)

	_update_death_hands_camera_tracking()
	_apply_death_hands_damage()
	_update_hud()


func _build_player() -> void:
	player = PLAYER_CHARACTER.new() as CharacterBody2D
	player.call("setup", PLAYER_RADIUS, CAMERA_ZOOM, float(level.get("world_width")), float(level.get("world_height")))
	add_child(player)


func _build_hud() -> void:
	hud = GAME_HUD.new() as CanvasLayer
	add_child(hud)
	hud.call("setup")


func _build_grab_system() -> void:
	grab_system = GRAB_SYSTEM.new() as RefCounted
	grab_system.call("configure", player, PLAYER_RADIUS, level.call("get_grab_targets"), level.call("get_slope_grab_handles"))


func _update_falling(delta: float) -> void:
	var was_on_floor: bool = player.is_on_floor()
	grab_system.call("update_ground_edge_arm", was_on_floor)

	var axis_x: float = Input.get_axis("move_left", "move_right")
	player.call("aim_visual_at", Vector2(axis_x, 0.0))
	var target_speed: float = AIR_MOVE_SPEED
	var acceleration: float = AIR_CONTROL
	if was_on_floor:
		target_speed = GROUND_MOVE_SPEED
		acceleration = GROUND_ACCELERATION
		if absf(axis_x) < 0.01:
			acceleration = GROUND_BRAKE

	player.velocity.x = move_toward(player.velocity.x, axis_x * target_speed, acceleration * delta)
	player.velocity.y = minf(player.velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	var fall_ratio: float = IMPACT_DAMAGE.get_warning_ratio(maxf(0.0, player.velocity.y))
	speed_edge_effect.call("set_speed_ratio", fall_ratio)
	player.call("set_fall_stretch", fall_ratio)

	var incoming_velocity: Vector2 = player.velocity
	player.move_and_slide()

	var grab_result: Variant = null
	if not player.is_on_floor():
		grab_result = grab_system.call("try_armed_ground_edge_grab")
	if grab_result != null:
		_enter_grab(grab_result)
		return
	if incoming_velocity.y > 0.0:
		grab_result = grab_system.call("try_slope_grab_handle", maxf(0.0, incoming_velocity.y))
		if grab_result != null:
			_enter_grab(grab_result)
			return

	var diagonal_collision: KinematicCollision2D = _find_diagonal_slide_collision()
	if diagonal_collision != null:
		_handle_diagonal_slide(incoming_velocity, diagonal_collision)
		return
	active_diagonal_surface = null

	var is_on_floor: bool = player.is_on_floor()
	if is_on_floor:
		if not was_on_floor:
			var landing_speed: float = _impact_speed_against_normal(incoming_velocity, player.get_floor_normal())
			var landing_ratio: float = landing_speed / IMPACT_DAMAGE.WARNING_IMPACT_SPEED
			player.call("trigger_landing_squash", landing_ratio)
			player.call("add_camera_trauma", IMPACT_DAMAGE.get_damage_ratio(landing_speed))
			if _apply_impact_damage("착지", landing_speed):
				return
		grab_result = grab_system.call("try_side_grab", GRAB_MODE_EDGE)
		if grab_result != null:
			_enter_grab(grab_result)
		return

	if player.velocity.y > 0.0:
		grab_result = grab_system.call("try_side_grab", GRAB_MODE_SIDE)
		if grab_result != null:
			_enter_grab(grab_result)
			return

	_handle_regular_collision(incoming_velocity)


func _update_grabbed(delta: float) -> void:
	active_diagonal_surface = null
	speed_edge_effect.call("set_speed_ratio", 0.0)
	player.call("set_fall_stretch", 0.0)
	player.velocity = Vector2.ZERO

	var aim: Vector2 = _get_aim_direction()

	if Input.is_action_just_pressed("charge_launch"):
		is_charging_launch = true
		charge = 0.0

	if Input.is_action_pressed("charge_launch"):
		is_charging_launch = true
		charge = minf(charge + delta / MAX_CHARGE_TIME, 1.0)

	player.call("set_charge_visual", charge)
	player.call("update_aim_indicator", aim, charge)

	if is_charging_launch and Input.is_action_just_released("charge_launch"):
		var speed: float = lerpf(LAUNCH_MIN_SPEED, LAUNCH_MAX_SPEED, charge)
		player.velocity = aim * speed
		player.call("play_launch_burst")
		player.call("hide_aim_indicator")
		state = "falling"
		charge = 0.0
		is_charging_launch = false


func _update_dead(delta: float) -> void:
	death_hold_elapsed += delta
	if death_hold_elapsed >= DEATH_HOLD_DURATION:
		_reset_player()


func _enter_grab(result: Variant) -> void:
	var result_dictionary: Dictionary = result as Dictionary
	var catch_speed: float = float(result_dictionary["impact_speed"])
	player.call("add_camera_trauma", IMPACT_DAMAGE.get_damage_ratio(catch_speed))
	if _apply_impact_damage("잡기", catch_speed, GRAB_DAMAGE_MULTIPLIER):
		return
	state = "grabbed"
	player.velocity = Vector2.ZERO
	player.global_position = result_dictionary["snap_position"] as Vector2
	active_diagonal_surface = null
	grab_system.call("reset")
	charge = 0.0
	is_charging_launch = false
	var face_direction: float = float(result_dictionary.get("face_direction", 0.0))
	if absf(face_direction) > 0.01:
		player.call("aim_visual_at", Vector2(face_direction, 0.0))
	player.call("play_grab_catch")


func _handle_regular_collision(incoming_velocity: Vector2) -> void:
	var collision_count: int = player.get_slide_collision_count()
	if collision_count <= 0:
		return

	var best_collision: KinematicCollision2D = player.get_slide_collision(0)
	for i in range(collision_count):
		var collision: KinematicCollision2D = player.get_slide_collision(i)
		if collision.get_normal().y < best_collision.get_normal().y:
			best_collision = collision

	if best_collision.get_normal().y <= -0.65:
		return

	var collision_speed: float = _impact_speed_against_normal(incoming_velocity, best_collision.get_normal())
	player.call("add_camera_trauma", IMPACT_DAMAGE.get_damage_ratio(collision_speed))
	if _apply_impact_damage("충돌", collision_speed):
		return

	var collider: Object = best_collision.get_collider()
	if collider is Node and (collider as Node).is_in_group(NO_FRICTION_WALL_GROUP):
		return

	player.velocity = player.velocity.bounce(best_collision.get_normal()) * 0.28
	player.velocity.y = minf(player.velocity.y, 120.0)


func _impact_speed_against_normal(incoming_velocity: Vector2, surface_normal: Vector2) -> float:
	return maxf(0.0, -incoming_velocity.dot(surface_normal))


func _find_diagonal_slide_collision() -> KinematicCollision2D:
	for collision_index in player.get_slide_collision_count():
		var collision: KinematicCollision2D = player.get_slide_collision(collision_index)
		var collider: Object = collision.get_collider()
		if collider is Node and (collider as Node).is_in_group(DIAGONAL_SLIDE_GROUP):
			return collision
	return null


func _handle_diagonal_slide(incoming_velocity: Vector2, collision: KinematicCollision2D) -> void:
	var collider: Object = collision.get_collider()
	if collider == active_diagonal_surface:
		return

	active_diagonal_surface = collider
	var surface_normal: Vector2 = collision.get_normal()
	var impact_speed: float = DIAGONAL_SLIDE_RESPONSE.impact_speed(incoming_velocity, surface_normal)
	player.call("add_camera_trauma", IMPACT_DAMAGE.get_damage_ratio(impact_speed))
	if _apply_impact_damage("경사면", impact_speed):
		return
	player.velocity = DIAGONAL_SLIDE_RESPONSE.slide_velocity(incoming_velocity, surface_normal, DIAGONAL_SLIDE_SPEED_RETENTION)


func _apply_impact_damage(reason: String, impact_speed: float, damage_multiplier: float = 1.0) -> bool:
	var damage: int = IMPACT_DAMAGE.damage_for_speed(impact_speed)
	if damage <= 0:
		return false
	damage = maxi(1, int(round(float(damage) * damage_multiplier)))

	var now: int = Time.get_ticks_msec()
	if now - last_damage_msec < 450:
		return false

	hp = maxi(0, hp - damage)
	last_damage_msec = now
	hud.call("show_status", "%s 충격 %d · 피해 -%d" % [reason, int(round(impact_speed)), damage])
	speed_edge_effect.call("flash_damage", IMPACT_DAMAGE.get_damage_ratio(impact_speed))

	if hp <= 0:
		_enter_death_hold()
		return true
	return false


func _apply_death_hands_damage() -> void:
	if state == "dead":
		return

	var player_top_position: Vector2 = player.global_position + Vector2.UP * PLAYER_RADIUS
	var damage: int = int(death_hands_hazard.call("get_damage_if_player_in_danger", player_top_position))
	if damage <= 0:
		return

	hp = maxi(0, hp - damage)
	hud.call("show_status", "망자의 손길 · 피해 -%d" % damage)
	speed_edge_effect.call("flash_damage", 0.45)

	if hp <= 0:
		_enter_death_hold()


func _update_death_hands_camera_tracking() -> void:
	var camera: Camera2D = player.get_node("Camera2D") as Camera2D
	if camera == null:
		return

	var viewport_height: float = get_viewport_rect().size.y
	var camera_top_y: float = player.global_position.y - viewport_height * camera.zoom.y * 0.5
	death_hands_hazard.call("set_camera_top", camera_top_y)


func _get_aim_direction() -> Vector2:
	var direction: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN
	return direction.normalized()


func _enter_death_hold() -> void:
	state = "dead"
	death_hold_elapsed = 0.0
	player.velocity = Vector2.ZERO
	charge = 0.0
	is_charging_launch = false
	speed_edge_effect.call("set_speed_ratio", 0.0)
	player.call("set_fall_stretch", 0.0)
	player.call("hide_aim_indicator")
	player.call("play_death_animation")


func _reset_player() -> void:
	hp = 100
	charge = 0.0
	is_charging_launch = false
	state = "falling"
	last_damage_msec = -1000
	death_hold_elapsed = 0.0
	grab_system.call("reset")
	player.global_position = PLAYER_START
	player.velocity = Vector2(0.0, 80.0)
	player.call("reset_visual")
	speed_edge_effect.call("set_speed_ratio", 0.0)
	death_hands_hazard.call("reset")
	active_diagonal_surface = null
	hud.call("clear_status")


func _update_hud() -> void:
	hud.call("update_values", hp, charge, player.global_position.y, float(level.call("get_section_height")), int(level.get("section_count")), state)
