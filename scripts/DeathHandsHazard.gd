class_name DeathHandsHazard
extends Node2D

const HAND_TEXTURE = preload("res://sprite/망자의_손길.png")

@export var world_width: float = 960.0
@export var world_height: float = 7800.0
@export var horizontal_padding: float = 320.0
@export var start_y: float = 0.0
@export var descend_speed: float = 18.0
@export var catch_up_when_above_screen: bool = true
@export var catch_up_speed: float = 120.0
@export var offscreen_top_margin: float = 160.0
@export var damage_per_tick: int = 6
@export var damage_tick_msec: int = 700
@export var sprite_scale: float = 0.45
@export var cover_extra_top: float = 10000.0
@export var cover_color: Color = Color(0.0, 0.0, 0.0, 0.94)
@export var cover_z_index: int = -30
@export var hands_z_index: int = 60

var front_y: float = 0.0
var next_damage_msec: int = 0
var camera_top_y: float = 0.0
var has_camera_top: bool = false
var cover_visual: Polygon2D
var hand_container: Node2D


func _ready() -> void:
	z_index = 0
	front_y = start_y
	_build_visuals()
	_update_visuals()


func _process(delta: float) -> void:
	var next_front_y: float = front_y + descend_speed * delta
	if catch_up_when_above_screen and has_camera_top:
		var minimum_visible_front_y: float = camera_top_y - offscreen_top_margin
		if next_front_y < minimum_visible_front_y:
			next_front_y = minf(minimum_visible_front_y, next_front_y + catch_up_speed * delta)

	front_y = minf(next_front_y, world_height)
	_update_visuals()


func reset() -> void:
	front_y = start_y
	next_damage_msec = 0
	_update_visuals()


func set_camera_top(camera_top_world_y: float) -> void:
	camera_top_y = camera_top_world_y
	has_camera_top = true


func configure(config_world_width: float, config_world_height: float) -> void:
	world_width = config_world_width
	world_height = config_world_height
	if hand_container != null:
		remove_child(hand_container)
		hand_container.queue_free()
	if cover_visual != null:
		remove_child(cover_visual)
		cover_visual.queue_free()
	_build_visuals()
	_update_visuals()


func get_damage_if_player_in_danger(player_position: Vector2) -> int:
	if player_position.y > front_y:
		return 0

	var now: int = Time.get_ticks_msec()
	if now < next_damage_msec:
		return 0

	next_damage_msec = now + damage_tick_msec
	return damage_per_tick


func _build_visuals() -> void:
	cover_visual = Polygon2D.new()
	cover_visual.name = "DeathCover"
	cover_visual.color = cover_color
	cover_visual.z_as_relative = false
	cover_visual.z_index = cover_z_index
	add_child(cover_visual)

	hand_container = Node2D.new()
	hand_container.name = "Hands"
	hand_container.z_as_relative = false
	hand_container.z_index = hands_z_index
	add_child(hand_container)

	var texture_width: float = float(HAND_TEXTURE.get_width()) * sprite_scale
	var needed_width: float = world_width + horizontal_padding * 2.0
	var sprite_count: int = maxi(1, int(ceil(needed_width / texture_width)))
	for i in sprite_count:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "HandSprite%d" % i
		sprite.texture = HAND_TEXTURE
		sprite.scale = Vector2.ONE * sprite_scale
		sprite.centered = false
		sprite.position = Vector2(-horizontal_padding + texture_width * float(i), 0.0)
		hand_container.add_child(sprite)


func _update_visuals() -> void:
	if cover_visual == null or hand_container == null:
		return

	var needed_width: float = world_width + horizontal_padding * 2.0
	var texture_height: float = float(HAND_TEXTURE.get_height()) * sprite_scale
	var sprite_top_y: float = front_y - texture_height
	cover_visual.polygon = PackedVector2Array([
		Vector2(-horizontal_padding, -cover_extra_top),
		Vector2(-horizontal_padding + needed_width, -cover_extra_top),
		Vector2(-horizontal_padding + needed_width, sprite_top_y),
		Vector2(-horizontal_padding, sprite_top_y),
	])
	hand_container.position = Vector2(0.0, sprite_top_y)
