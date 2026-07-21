@tool
class_name GrabPoint
extends Node2D

@export var radius: float = 10.0:
	set(value):
		radius = maxf(1.0, value)
		_rebuild()
@export var grab_reach: float = 42.0:
	set(value):
		grab_reach = maxf(1.0, value)
		_rebuild()
@export var color: Color = Color.html("#6ad7f0"):
	set(value):
		color = value
		_rebuild()
@export var highlight_color: Color = Color.html("#f0c75e"):
	set(value):
		highlight_color = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func get_grab_data() -> Dictionary:
	return {
		"type": "point",
		"position": global_position,
		"radius": radius,
		"reach": grab_reach,
	}


func _rebuild() -> void:
	if not is_inside_tree():
		return

	var reach_visual: Polygon2D = _get_or_create_visual("ReachHighlight")
	reach_visual.color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.18)
	reach_visual.polygon = _circle_polygon(grab_reach, 32)
	reach_visual.z_index = 1

	var point_visual: Polygon2D = _get_or_create_visual("PointVisual")
	point_visual.color = color
	point_visual.polygon = _circle_polygon(radius, 24)
	point_visual.z_index = 2


func _get_or_create_visual(node_name: String) -> Polygon2D:
	var existing: Polygon2D = get_node_or_null(node_name) as Polygon2D
	if existing != null:
		return existing

	var visual: Polygon2D = Polygon2D.new()
	visual.name = node_name
	add_child(visual)
	return visual


func _circle_polygon(circle_radius: float, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for point_index in point_count:
		var angle: float = TAU * float(point_index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * circle_radius)
	return points
