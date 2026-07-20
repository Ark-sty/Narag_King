class_name SpeedEdgeEffect
extends CanvasLayer

const EDGE_SHADER = preload("res://shaders/speed_edge.gdshader")

const EFFECT_LAYER := 10
const INTENSITY_RISE_RATE := 3.6
const INTENSITY_RELEASE_RATE := 2.4
const FLASH_MIN_ALPHA := 0.16
const FLASH_MAX_ALPHA := 0.36
const FLASH_HOLD_DURATION := 0.08
const FLASH_FADE_DURATION := 0.55

var _edge_rect: ColorRect
var _edge_material: ShaderMaterial
var _damage_overlay: ColorRect
var _flash_tween: Tween
var _target_intensity := 0.0
var _displayed_intensity := 0.0


func _ready() -> void:
	layer = EFFECT_LAYER
	_build_edge_overlay()
	_build_damage_overlay()


func _process(delta: float) -> void:
	var rate := INTENSITY_RISE_RATE
	if _target_intensity < _displayed_intensity:
		rate = INTENSITY_RELEASE_RATE

	_displayed_intensity = move_toward(
		_displayed_intensity,
		_target_intensity,
		rate * delta
	)
	_edge_material.set_shader_parameter("intensity", _displayed_intensity)
	_edge_rect.visible = _displayed_intensity > 0.001


func set_speed_ratio(speed_ratio: float) -> void:
	_target_intensity = clampf(speed_ratio, 0.0, 1.0)


func flash_damage(damage_ratio: float) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	var strength := clampf(damage_ratio, 0.0, 1.0)
	var flash_alpha := lerpf(FLASH_MIN_ALPHA, FLASH_MAX_ALPHA, strength)
	_damage_overlay.color = Color(1.0, 0.06, 0.03, flash_alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(FLASH_HOLD_DURATION)
	_flash_tween.tween_property(
		_damage_overlay,
		"color:a",
		0.0,
		FLASH_FADE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _build_edge_overlay() -> void:
	_edge_material = ShaderMaterial.new()
	_edge_material.shader = EDGE_SHADER

	_edge_rect = ColorRect.new()
	_edge_rect.name = "SpeedEdgeOverlay"
	_edge_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_rect.color = Color.WHITE
	_edge_rect.material = _edge_material
	_edge_rect.visible = false
	add_child(_edge_rect)


func _build_damage_overlay() -> void:
	_damage_overlay = ColorRect.new()
	_damage_overlay.name = "ImpactDamageFlash"
	_damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_damage_overlay)
