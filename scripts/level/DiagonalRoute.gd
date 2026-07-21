@tool
class_name DiagonalRoute
extends StaticBody2D

const DIAGONAL_SLIDE_GROUP := &"diagonal_slide_surface"

@export var surface_size: Vector2 = Vector2(320.0, 28.0):
	set(value):
		surface_size = value
		_rebuild()
@export var angle_degrees: float = 32.0:
	set(value):
		angle_degrees = value
		_rebuild()
@export var surface_color: Color = Color.html("#b64343"):
	set(value):
		surface_color = value
		_rebuild()
@export var handle_enabled: bool = true:
	set(value):
		handle_enabled = value
		_rebuild()
@export var handle_offset: float = 30.0:
	set(value):
		handle_offset = value
		_rebuild()
@export var handle_length: float = 72.0:
	set(value):
		handle_length = value
		_rebuild()
@export var handle_reach: float = 30.0
@export var handle_width: float = 14.0:
	set(value):
		handle_width = value
		_rebuild()
@export var handle_color: Color = Color.html("#f0c75e"):
	set(value):
		handle_color = value
		_rebuild()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group(DIAGONAL_SLIDE_GROUP)
	_rebuild()


func get_grab_handle() -> Array:
	if not handle_enabled:
		return []

	var angle_radians: float = deg_to_rad(angle_degrees)
	var tangent: Vector2 = Vector2.RIGHT.rotated(angle_radians)
	var downhill_direction: Vector2 = tangent
	if tangent.y <= 0.0:
		downhill_direction = -tangent

	var handle_bottom: Vector2 = global_position + downhill_direction * handle_offset
	var handle_top: Vector2 = handle_bottom + Vector2.UP * handle_length
	return [handle_top, handle_bottom, handle_reach]


func _rebuild() -> void:
	if not is_inside_tree():
		return

	var angle_radians: float = deg_to_rad(angle_degrees)
	var collision_shape: CollisionShape2D = _get_or_create_collision_shape()
	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rect_shape == null:
		rect_shape = RectangleShape2D.new()
		collision_shape.shape = rect_shape
	rect_shape.size = surface_size
	collision_shape.rotation = angle_radians

	var visual: Polygon2D = _get_or_create_visual()
	visual.color = surface_color
	visual.rotation = angle_radians
	visual.polygon = _rect_polygon(surface_size)

	var handle_visual: Polygon2D = _get_or_create_handle_visual()
	handle_visual.visible = handle_enabled
	if not handle_enabled:
		return
	handle_visual.color = handle_color
	handle_visual.polygon = _handle_polygon()


func _get_or_create_collision_shape() -> CollisionShape2D:
	var existing: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if existing != null:
		return existing

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	add_child(collision_shape)
	return collision_shape


func _get_or_create_visual() -> Polygon2D:
	var existing: Polygon2D = get_node_or_null("Visual") as Polygon2D
	if existing != null:
		return existing

	var visual: Polygon2D = Polygon2D.new()
	visual.name = "Visual"
	add_child(visual)
	return visual


func _get_or_create_handle_visual() -> Polygon2D:
	var existing: Polygon2D = get_node_or_null("GrabHandleVisual") as Polygon2D
	if existing != null:
		return existing

	var visual: Polygon2D = Polygon2D.new()
	visual.name = "GrabHandleVisual"
	add_child(visual)
	return visual


func _rect_polygon(rect_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-rect_size.x * 0.5, -rect_size.y * 0.5),
		Vector2(rect_size.x * 0.5, -rect_size.y * 0.5),
		Vector2(rect_size.x * 0.5, rect_size.y * 0.5),
		Vector2(-rect_size.x * 0.5, rect_size.y * 0.5),
	])


func _handle_polygon() -> PackedVector2Array:
	var handle: Array = get_grab_handle()
	var handle_top: Vector2 = (handle[0] as Vector2) - global_position
	var handle_bottom: Vector2 = (handle[1] as Vector2) - global_position
	var half_width: float = handle_width * 0.5
	return PackedVector2Array([
		handle_top + Vector2(-half_width, 0.0),
		handle_top + Vector2(half_width, 0.0),
		handle_bottom + Vector2(half_width, 0.0),
		handle_bottom + Vector2(-half_width, 0.0),
	])
