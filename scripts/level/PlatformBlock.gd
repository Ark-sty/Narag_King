@tool
class_name PlatformBlock
extends StaticBody2D

const GRAB_BOTH := 0
const GRAB_LEFT_ONLY := 1
const GRAB_RIGHT_ONLY := 2
const SIDE_LEFT := 1
const SIDE_RIGHT := 2

@export var size: Vector2 = Vector2(240.0, 32.0):
	set(value):
		size = value
		_rebuild()
@export var color: Color = Color.html("#9aa6b2"):
	set(value):
		color = value
		_rebuild()
@export var grabbable: bool = true:
	set(value):
		grabbable = value
		_rebuild()
@export_enum("Both", "Left Only", "Right Only") var grab_sides: int = GRAB_BOTH:
	set(value):
		grab_sides = value
		_rebuild()
@export var grab_highlight_color: Color = Color.html("#f0c75e"):
	set(value):
		grab_highlight_color = value
		_rebuild()
@export var grab_highlight_width: float = 6.0:
	set(value):
		grab_highlight_width = value
		_rebuild()
@export var solid: bool = true:
	set(value):
		solid = value
		_rebuild()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()


func get_world_rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func get_grab_data() -> Dictionary:
	return {
		"type": "rect",
		"rect": get_world_rect(),
		"sides": _grab_side_mask(),
	}


func _rebuild() -> void:
	if not is_inside_tree():
		return

	var collision_shape: CollisionShape2D = _get_or_create_collision_shape()
	var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rect_shape == null:
		rect_shape = RectangleShape2D.new()
		collision_shape.shape = rect_shape
	rect_shape.size = size
	collision_shape.disabled = not solid

	var visual: Polygon2D = _get_or_create_visual()
	visual.color = color
	visual.polygon = _rect_polygon(size)

	_rebuild_grab_highlights()


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


func _rebuild_grab_highlights() -> void:
	var left_highlight: Polygon2D = _get_or_create_highlight("LeftGrabHighlight")
	var right_highlight: Polygon2D = _get_or_create_highlight("RightGrabHighlight")
	var side_mask: int = _grab_side_mask()

	left_highlight.visible = grabbable and (side_mask & SIDE_LEFT) != 0
	right_highlight.visible = grabbable and (side_mask & SIDE_RIGHT) != 0

	left_highlight.color = grab_highlight_color
	right_highlight.color = grab_highlight_color
	left_highlight.polygon = _side_highlight_polygon(-1.0)
	right_highlight.polygon = _side_highlight_polygon(1.0)


func _get_or_create_highlight(node_name: String) -> Polygon2D:
	var existing: Polygon2D = get_node_or_null(node_name) as Polygon2D
	if existing != null:
		return existing

	var highlight: Polygon2D = Polygon2D.new()
	highlight.name = node_name
	highlight.z_index = 3
	add_child(highlight)
	return highlight


func _grab_side_mask() -> int:
	if not grabbable:
		return 0
	if grab_sides == GRAB_LEFT_ONLY:
		return SIDE_LEFT
	if grab_sides == GRAB_RIGHT_ONLY:
		return SIDE_RIGHT
	return SIDE_LEFT | SIDE_RIGHT


func _side_highlight_polygon(side_direction: float) -> PackedVector2Array:
	var side_x: float = size.x * 0.5 * side_direction
	var inner_x: float = side_x - grab_highlight_width * side_direction
	return PackedVector2Array([
		Vector2(inner_x, -size.y * 0.5),
		Vector2(side_x, -size.y * 0.5),
		Vector2(side_x, size.y * 0.5),
		Vector2(inner_x, size.y * 0.5),
	])


func _rect_polygon(rect_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-rect_size.x * 0.5, -rect_size.y * 0.5),
		Vector2(rect_size.x * 0.5, -rect_size.y * 0.5),
		Vector2(rect_size.x * 0.5, rect_size.y * 0.5),
		Vector2(-rect_size.x * 0.5, rect_size.y * 0.5),
	])
