class_name GameHud
extends CanvasLayer

signal restart_requested

var hp_bar: ProgressBar
var charge_bar: ProgressBar
var section_label: Label
var state_label: Label
var status_message_until_msec: int = 0
var clear_overlay: Control
var restart_button: Button


func _ready() -> void:
	layer = 20
	setup()


func setup() -> void:
	if hp_bar != null:
		return
	_build_ui()


func update_values(hp: int, charge: float, player_y: float, section_height: float, section_count: int, state: String) -> void:
	setup()
	hp_bar.value = hp
	charge_bar.value = charge * 100.0
	var section: int = clampi(int(player_y / section_height) + 1, 1, section_count)
	section_label.text = "%d / %d" % [section, section_count]
	if Time.get_ticks_msec() < status_message_until_msec:
		return

	if state == "grabbed":
		state_label.text = "잡는 중"
	elif state == "cleared":
		state_label.text = "클리어!"
	elif hp > 0:
		state_label.text = "낙하 중"


func show_status(message: String, duration_msec: int = 900) -> void:
	setup()
	status_message_until_msec = Time.get_ticks_msec() + duration_msec
	state_label.text = message


func clear_status() -> void:
	status_message_until_msec = 0


func show_cleared() -> void:
	setup()
	clear_overlay.visible = true


func hide_cleared() -> void:
	setup()
	clear_overlay.visible = false


func _build_ui() -> void:
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.04, 0.05, 0.06, 0.78)
	panel.position = Vector2(16.0, 14.0)
	panel.size = Vector2(300.0, 104.0)
	add_child(panel)

	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(28.0, 26.0)
	hp_bar.size = Vector2(180.0, 20.0)
	hp_bar.max_value = 100
	hp_bar.show_percentage = false
	add_child(hp_bar)

	charge_bar = ProgressBar.new()
	charge_bar.position = Vector2(28.0, 56.0)
	charge_bar.size = Vector2(180.0, 20.0)
	charge_bar.max_value = 100
	charge_bar.show_percentage = false
	add_child(charge_bar)

	section_label = Label.new()
	section_label.position = Vector2(224.0, 24.0)
	section_label.size = Vector2(76.0, 24.0)
	add_child(section_label)

	state_label = Label.new()
	state_label.position = Vector2(28.0, 84.0)
	state_label.size = Vector2(270.0, 22.0)
	add_child(state_label)

	_build_clear_overlay()


func _build_clear_overlay() -> void:
	clear_overlay = Control.new()
	clear_overlay.name = "ClearOverlay"
	clear_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	clear_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear_overlay.visible = false
	add_child(clear_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear_overlay.add_child(center)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	center.add_child(layout)

	var title := Label.new()
	title.text = "클리어!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	layout.add_child(title)

	restart_button = Button.new()
	restart_button.text = "다시 시작"
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.custom_minimum_size = Vector2(160.0, 44.0)
	restart_button.pressed.connect(_on_restart_pressed)
	layout.add_child(restart_button)


func _on_restart_pressed() -> void:
	restart_requested.emit()
