class_name GrabSystem
extends RefCounted

const MODE_SIDE := 0
const MODE_EDGE := 1
const MODE_GROUND_EDGE := 2
const SIDE_LEFT := 1
const SIDE_RIGHT := 2

var player: CharacterBody2D
var player_radius: float = 18.0
var grab_targets: Array[Dictionary] = []
var slope_grab_handles: Array[Array] = []
var side_distance: float = 46.0
var edge_distance: float = 54.0
var edge_vertical_distance: float = 16.0
var ground_edge_distance: float = 108.0
var ground_edge_vertical_distance: float = 52.0
var ground_edge_arm_msec: int = 180
var snap_gap: float = 1.5
var input_buffered_until_msec: int = -1
var ground_edge_rect_index: int = -1
var ground_edge_armed_until_msec: int = -1


func configure(target_player: CharacterBody2D, target_radius: float, target_grab_targets: Array[Dictionary], target_handles: Array[Array]) -> void:
	player = target_player
	player_radius = target_radius
	grab_targets = target_grab_targets
	slope_grab_handles = target_handles


func reset() -> void:
	input_buffered_until_msec = -1
	ground_edge_rect_index = -1
	ground_edge_armed_until_msec = -1


func buffer_input(duration_msec: int) -> void:
	input_buffered_until_msec = Time.get_ticks_msec() + duration_msec


func update_ground_edge_arm(was_on_floor: bool) -> void:
	if not Input.is_action_pressed("grab"):
		ground_edge_rect_index = -1
		ground_edge_armed_until_msec = -1
		return
	if not was_on_floor:
		return

	var supporting_rect_index: int = _find_supporting_grabbable_rect_index()
	if supporting_rect_index < 0:
		ground_edge_rect_index = -1
		ground_edge_armed_until_msec = -1
		return
	ground_edge_rect_index = supporting_rect_index
	ground_edge_armed_until_msec = Time.get_ticks_msec() + ground_edge_arm_msec


func try_side_grab(grab_mode: int) -> Variant:
	if not _has_buffered_input():
		return null

	var player_position: Vector2 = player.global_position
	for i in grab_targets.size():
		var target: Dictionary = grab_targets[i]
		var target_type: String = String(target.get("type", ""))
		if target_type == "point":
			if grab_mode != MODE_SIDE:
				continue
			var point_result: Variant = _try_point_target(target)
			if point_result != null:
				_consume_input()
				return point_result
			continue
		if target_type != "rect":
			continue

		var rect: Rect2 = target["rect"] as Rect2
		var side_mask: int = int(target.get("sides", SIDE_LEFT | SIDE_RIGHT))
		var left_side_x: float = rect.position.x
		var right_side_x: float = rect.end.x
		if _can_grab_side(rect, left_side_x, -1.0, player_position, grab_mode, side_mask):
			_consume_input()
			return _make_rect_grab_result(rect, left_side_x, -1.0, grab_mode)
		if _can_grab_side(rect, right_side_x, 1.0, player_position, grab_mode, side_mask):
			_consume_input()
			return _make_rect_grab_result(rect, right_side_x, 1.0, grab_mode)
	return null


func try_armed_ground_edge_grab() -> Variant:
	if not Input.is_action_pressed("grab"):
		return null
	if ground_edge_rect_index < 0:
		return null
	if Time.get_ticks_msec() > ground_edge_armed_until_msec:
		ground_edge_rect_index = -1
		return null

	var target: Dictionary = grab_targets[ground_edge_rect_index]
	if String(target.get("type", "")) != "rect":
		return null
	var rect: Rect2 = target["rect"] as Rect2
	var side_mask: int = int(target.get("sides", SIDE_LEFT | SIDE_RIGHT))
	var player_position: Vector2 = player.global_position
	var left_side_x: float = rect.position.x
	var right_side_x: float = rect.end.x
	if _can_grab_side(rect, left_side_x, -1.0, player_position, MODE_GROUND_EDGE, side_mask):
		return _make_rect_grab_result(rect, left_side_x, -1.0, MODE_GROUND_EDGE)
	if _can_grab_side(rect, right_side_x, 1.0, player_position, MODE_GROUND_EDGE, side_mask):
		return _make_rect_grab_result(rect, right_side_x, 1.0, MODE_GROUND_EDGE)
	return null


func try_slope_grab_handle(grab_speed: float) -> Variant:
	if not _has_buffered_input():
		return null

	for i in slope_grab_handles.size():
		var handle: Array = slope_grab_handles[i]
		var segment_start: Vector2 = handle[0] as Vector2
		var segment_end: Vector2 = handle[1] as Vector2
		var grab_reach: float = float(handle[2])
		var closest_point: Vector2 = _closest_point_on_segment(player.global_position, segment_start, segment_end)
		if player.global_position.distance_to(closest_point) > grab_reach:
			continue
		_consume_input()
		return _make_grab_result(player.global_position, grab_speed)
	return null


func _find_supporting_grabbable_rect_index() -> int:
	var player_position: Vector2 = player.global_position
	var player_feet_y: float = player_position.y + player_radius
	for rect_index in grab_targets.size():
		var target: Dictionary = grab_targets[rect_index]
		if String(target.get("type", "")) != "rect":
			continue
		var rect: Rect2 = target["rect"] as Rect2
		if player_position.x < rect.position.x - player_radius or player_position.x > rect.end.x + player_radius:
			continue
		if absf(player_feet_y - rect.position.y) <= 6.0:
			return rect_index
	return -1


func _can_grab_side(rect: Rect2, side_x: float, side_direction: float, player_position: Vector2, grab_mode: int, side_mask: int) -> bool:
	if side_direction < 0.0 and (side_mask & SIDE_LEFT) == 0:
		return false
	if side_direction > 0.0 and (side_mask & SIDE_RIGHT) == 0:
		return false

	var horizontal_gap: float = absf(player_position.x - side_x) - player_radius
	var target_side_distance: float = side_distance
	if grab_mode == MODE_EDGE:
		target_side_distance = edge_distance
	elif grab_mode == MODE_GROUND_EDGE:
		target_side_distance = ground_edge_distance
	if horizontal_gap < -player_radius * 0.35 or horizontal_gap > target_side_distance:
		return false

	var is_on_correct_side: bool = false
	if side_direction < 0.0:
		is_on_correct_side = player_position.x < side_x
	else:
		is_on_correct_side = player_position.x > side_x
	if not is_on_correct_side:
		return false

	var player_feet_y: float = player_position.y + player_radius
	var is_beside_face: bool = player_position.y >= rect.position.y + minf(player_radius * 0.35, rect.size.y * 0.5) and player_position.y <= rect.end.y + player_radius * 0.35
	var target_edge_vertical_distance: float = edge_vertical_distance
	if grab_mode == MODE_GROUND_EDGE:
		target_edge_vertical_distance = ground_edge_vertical_distance
	var is_near_top_edge: bool = grab_mode != MODE_SIDE and absf(player_feet_y - rect.position.y) <= target_edge_vertical_distance
	if grab_mode != MODE_SIDE:
		return is_near_top_edge
	return is_beside_face


func _try_point_target(target: Dictionary) -> Variant:
	var point_position: Vector2 = target["position"] as Vector2
	var reach: float = float(target.get("reach", 42.0))
	var radius: float = float(target.get("radius", 0.0))
	var distance: float = player.global_position.distance_to(point_position)
	if distance > reach + radius:
		return null
	return _make_grab_result(point_position, maxf(0.0, player.velocity.y))


func _make_rect_grab_result(rect: Rect2, side_x: float, side_direction: float, grab_mode: int) -> Variant:
	var snap_position: Vector2 = player.global_position
	snap_position.x = side_x + side_direction * (player_radius + snap_gap)
	if grab_mode != MODE_SIDE:
		snap_position.y = rect.position.y + minf(player_radius * 0.7, rect.size.y * 0.5)
	else:
		var min_y: float = rect.position.y + minf(4.0, rect.size.y * 0.25)
		var max_y: float = rect.end.y - minf(4.0, rect.size.y * 0.25)
		snap_position.y = clampf(player.global_position.y, min_y, max_y)
	return _make_grab_result(snap_position, maxf(0.0, player.velocity.y), -side_direction)


func _make_grab_result(snap_position: Vector2, impact_speed: float, face_direction: float = 0.0) -> Dictionary:
	return {
		"snap_position": snap_position,
		"impact_speed": impact_speed,
		"face_direction": face_direction,
	}


func _closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var segment: Vector2 = segment_end - segment_start
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.0001:
		return segment_start
	var progress: float = clampf((point - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
	return segment_start + segment * progress


func _has_buffered_input() -> bool:
	return input_buffered_until_msec >= Time.get_ticks_msec()


func _consume_input() -> void:
	input_buffered_until_msec = -1
	ground_edge_rect_index = -1
	ground_edge_armed_until_msec = -1
