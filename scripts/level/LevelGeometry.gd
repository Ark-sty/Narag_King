@tool
class_name LevelGeometry
extends Node2D

const NO_FRICTION_WALL_GROUP := &"no_friction_wall"

@export var world_width: float = 960.0:
	set(value):
		world_width = value
		_rebuild_generated()
@export var world_height: float = 7800.0:
	set(value):
		world_height = value
		_rebuild_generated()
@export var section_count: int = 5:
	set(value):
		section_count = maxi(1, value)
		_rebuild_generated()
@export var background_horizontal_padding: float = 240.0:
	set(value):
		background_horizontal_padding = value
		_rebuild_generated()
@export var section_colors: Array[Color] = [
	Color.html("#1d2730"),
	Color.html("#26322d"),
	Color.html("#302c3b"),
	Color.html("#342c28"),
	Color.html("#202b3d"),
]:
	set(value):
		section_colors = value
		_rebuild_generated()


func _ready() -> void:
	_rebuild_generated()


func get_section_height() -> float:
	return world_height / float(section_count)


func get_grab_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var nodes: Array[Node] = _find_nodes_with_method(self, &"get_grab_data")
	for node: Node in nodes:
		if node.has_method(&"get_world_rect") and not bool(node.get("solid")):
			continue
		if node.has_method(&"get_world_rect") and not bool(node.get("grabbable")):
			continue
		var data: Dictionary = node.call("get_grab_data") as Dictionary
		if not data.is_empty():
			targets.append(data)
	return targets


func get_grabbable_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var targets: Array[Dictionary] = get_grab_targets()
	for target: Dictionary in targets:
		if String(target.get("type", "")) == "rect":
			rects.append(target["rect"] as Rect2)
	return rects


func get_slope_grab_handles() -> Array[Array]:
	var handles: Array[Array] = []
	var routes: Array[Node] = _find_nodes_with_method(self, &"get_grab_handle")
	for route: Node in routes:
		handles.append(route.get_grab_handle())
	return handles


func _rebuild_generated() -> void:
	if not is_inside_tree():
		return

	var old_generated: Node = get_node_or_null("Generated")
	if old_generated != null:
		remove_child(old_generated)
		old_generated.queue_free()

	var generated: Node2D = Node2D.new()
	generated.name = "Generated"
	generated.z_index = -30
	add_child(generated)

	var section_height: float = get_section_height()
	for section in section_count:
		var top: float = float(section) * section_height
		var color: Color = Color.html("#1d2730")
		if section < section_colors.size():
			color = section_colors[section]
		_add_generated_rect(
			generated,
			"Section%dBackground" % (section + 1),
			Vector2(world_width * 0.5, top + section_height * 0.5),
			Vector2(world_width + background_horizontal_padding * 2.0, section_height),
			color,
			false,
			-20
		)
		_add_label_marker(generated, section, top)

	_add_generated_rect(generated, "LeftWall", Vector2(-16.0, world_height * 0.5), Vector2(32.0, world_height), Color.html("#56616b"), true, 0, 0.0, NO_FRICTION_WALL_GROUP)
	_add_generated_rect(generated, "RightWall", Vector2(world_width + 16.0, world_height * 0.5), Vector2(32.0, world_height), Color.html("#56616b"), true, 0, 0.0, NO_FRICTION_WALL_GROUP)
	_add_generated_rect(generated, "StartCeiling", Vector2(world_width * 0.5, -16.0), Vector2(world_width, 32.0), Color.html("#56616b"), true, 0)
	_add_generated_rect(generated, "FinishFloor", Vector2(world_width * 0.5, world_height + 18.0), Vector2(world_width, 36.0), Color.html("#8fbf6a"), true, 0)


func _add_generated_rect(parent: Node, node_name: String, center: Vector2, size: Vector2, color: Color, solid: bool, z: int, friction: float = -1.0, group: StringName = &"") -> void:
	var body: Node2D
	if solid:
		var static_body: StaticBody2D = StaticBody2D.new()
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		if friction >= 0.0:
			var material: PhysicsMaterial = PhysicsMaterial.new()
			material.friction = friction
			static_body.physics_material_override = material
		if group != &"":
			static_body.add_to_group(group)
		body = static_body
	else:
		body = Node2D.new()

	body.name = node_name
	body.position = center
	body.z_index = z
	parent.add_child(body)

	if solid:
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = size
		collision_shape.shape = rect_shape
		body.add_child(collision_shape)

	var visual: Polygon2D = Polygon2D.new()
	visual.color = color
	visual.polygon = _rect_polygon(size)
	body.add_child(visual)


func _add_label_marker(parent: Node, section: int, top: float) -> void:
	var label: Label = Label.new()
	label.text = "PART %d" % (section + 1)
	label.position = Vector2(34.0, top + 34.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.38)
	label.z_index = -5
	parent.add_child(label)


func _find_nodes_with_method(root: Node, method_name: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in root.get_children():
		if child.has_method(method_name):
			found.append(child)
		found.append_array(_find_nodes_with_method(child, method_name))
	return found


func _rect_polygon(rect_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-rect_size.x * 0.5, -rect_size.y * 0.5),
		Vector2(rect_size.x * 0.5, -rect_size.y * 0.5),
		Vector2(rect_size.x * 0.5, rect_size.y * 0.5),
		Vector2(-rect_size.x * 0.5, rect_size.y * 0.5),
	])
