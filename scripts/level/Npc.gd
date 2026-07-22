@tool
class_name Npc
extends Node2D

const DEFAULT_TEXTURE := preload("uid://cfqbscwif3exu")
const PLAYER_COLLISION_LAYER := 2
const LABEL_WIDTH := 240.0
const DIALOGUE_FONT_SIZE := 16
const NAME_FONT_SIZE := 12
const NAME_DIALOGUE_GAP := 2.0
const HEAD_GAP := 16.0
const RANGE_HIGHLIGHT_COLOR := Color(0.41568628, 0.84313726, 0.9411765, 0.16)

@export var texture: Texture2D = DEFAULT_TEXTURE:
	set(value):
		texture = value
		_rebuild()
@export var sprite_scale: float = 1.0:
	set(value):
		sprite_scale = maxf(0.01, value)
		_rebuild()
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		_rebuild()
@export var interact_radius: float = 100.0:
	set(value):
		interact_radius = maxf(1.0, value)
		_rebuild()
@export_multiline var dialogue_text: String = "(대사를 입력하세요)":
	set(value):
		dialogue_text = value
		_rebuild()
@export var npc_name: String = "":
	set(value):
		npc_name = value
		_rebuild()

var body_visual: Sprite2D
var interact_area: Area2D
var dialogue_label: Label
var name_label: Label
var _range_highlight: Polygon2D
var _player_in_range: bool = false


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_build_visual()
	_build_interact_area()
	_build_dialogue_label()
	_build_name_label()
	_layout_labels()


func _build_visual() -> void:
	body_visual = get_node_or_null("Visual") as Sprite2D
	if body_visual == null:
		body_visual = Sprite2D.new()
		body_visual.name = "Visual"
		add_child(body_visual)

	body_visual.texture = texture
	body_visual.centered = true
	body_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_visual.scale = Vector2.ONE * sprite_scale
	body_visual.flip_h = flip_h
	if texture != null:
		body_visual.offset = Vector2(0.0, -texture.get_height() * 0.5)


func _build_interact_area() -> void:
	interact_area = get_node_or_null("InteractArea") as Area2D
	if interact_area == null:
		interact_area = Area2D.new()
		interact_area.name = "InteractArea"
		interact_area.collision_layer = 0
		interact_area.collision_mask = PLAYER_COLLISION_LAYER
		add_child(interact_area)

	var shape: CollisionShape2D = interact_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		interact_area.add_child(shape)

	var circle: CircleShape2D = shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape.shape = circle
	circle.radius = interact_radius

	_range_highlight = interact_area.get_node_or_null("RangeHighlight") as Polygon2D
	if _range_highlight == null:
		_range_highlight = Polygon2D.new()
		_range_highlight.name = "RangeHighlight"
		_range_highlight.z_index = -1
		interact_area.add_child(_range_highlight)
	_range_highlight.color = RANGE_HIGHLIGHT_COLOR
	_range_highlight.polygon = _circle_polygon(interact_radius, 32)
	_range_highlight.visible = Engine.is_editor_hint()


func _build_dialogue_label() -> void:
	dialogue_label = get_node_or_null("DialogueLabel") as Label
	if dialogue_label == null:
		dialogue_label = Label.new()
		dialogue_label.name = "DialogueLabel"
		add_child(dialogue_label)

	dialogue_label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	dialogue_label.size = Vector2(LABEL_WIDTH, 0.0)
	dialogue_label.visible = false
	dialogue_label.z_index = 10
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", DIALOGUE_FONT_SIZE)
	dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dialogue_label.add_theme_constant_override("outline_size", 4)
	dialogue_label.text = dialogue_text
	dialogue_label.size = Vector2(LABEL_WIDTH, _measure_text_height(dialogue_label, dialogue_text, LABEL_WIDTH))


func _build_name_label() -> void:
	name_label = get_node_or_null("NameLabel") as Label
	if name_label == null:
		name_label = Label.new()
		name_label.name = "NameLabel"
		add_child(name_label)

	name_label.text = npc_name
	name_label.visible = false
	name_label.z_index = 10
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.size = Vector2(LABEL_WIDTH, _measure_text_height(name_label, npc_name, -1.0))


func _layout_labels() -> void:
	var sprite_top_y: float = 0.0
	if texture != null:
		sprite_top_y = -texture.get_height() * sprite_scale

	dialogue_label.position = Vector2(-LABEL_WIDTH * 0.5, sprite_top_y - HEAD_GAP - dialogue_label.size.y)

	if npc_name.is_empty():
		name_label.position = dialogue_label.position
		return
	name_label.position = Vector2(-LABEL_WIDTH * 0.5, dialogue_label.position.y - NAME_DIALOGUE_GAP - name_label.size.y)


func _measure_text_height(label: Label, text: String, wrap_width: float) -> float:
	if text.is_empty():
		return 0.0
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, wrap_width, font_size).y


func _on_body_entered(_body: Node2D) -> void:
	_player_in_range = true
	_update_dialogue_visibility()


func _on_body_exited(_body: Node2D) -> void:
	_player_in_range = false
	_update_dialogue_visibility()


func _update_dialogue_visibility() -> void:
	dialogue_label.visible = _player_in_range
	name_label.visible = _player_in_range and not npc_name.is_empty()


func _circle_polygon(circle_radius: float, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for point_index in point_count:
		var angle: float = TAU * float(point_index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * circle_radius)
	return points
