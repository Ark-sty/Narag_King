class_name MainMenu
extends CanvasLayer

signal play_requested
signal controls_requested

const TITLE_BACKGROUND = preload("res://sprite/Narag_King_Title.png")
const PLAY_BUTTON_TEXTURE = preload("res://sprite/play.png")
const SETTINGS_BUTTON_TEXTURE = preload("res://sprite/setting.png")

var _root: Control


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	get_tree().paused = true


func hide_menu() -> void:
	_root.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MainMenuRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var background: ColorRect = ColorRect.new()
	background.color = Color.html("#08090b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var title_background: TextureRect = TextureRect.new()
	title_background.name = "TitleBackground"
	title_background.texture = TITLE_BACKGROUND
	title_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(title_background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.anchor_top = 0.65
	center.anchor_bottom = 0.98
	_root.add_child(center)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	center.add_child(layout)

	var play_button: TextureButton = TextureButton.new()
	play_button.texture_normal = PLAY_BUTTON_TEXTURE
	play_button.ignore_texture_size = true
	play_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	play_button.focus_mode = Control.FOCUS_NONE
	play_button.custom_minimum_size = Vector2(210.0, 88.0)
	play_button.pressed.connect(_on_play_pressed)
	layout.add_child(play_button)

	var controls_button: TextureButton = TextureButton.new()
	controls_button.texture_normal = SETTINGS_BUTTON_TEXTURE
	controls_button.ignore_texture_size = true
	controls_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	controls_button.focus_mode = Control.FOCUS_NONE
	controls_button.custom_minimum_size = Vector2(210.0, 64.0)
	controls_button.pressed.connect(_on_controls_pressed)
	layout.add_child(controls_button)


func _on_play_pressed() -> void:
	play_requested.emit()


func _on_controls_pressed() -> void:
	controls_requested.emit()
