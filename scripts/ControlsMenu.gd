extends CanvasLayer

const InputBindingsService = preload("res://scripts/InputBindings.gd")

var _overlay: ColorRect
var _open_button: Button
var _status_label: Label
var _binding_buttons: Dictionary = {}
var _waiting_action: StringName = &""
var _was_paused := false
var _launcher_enabled: bool = true


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindingsService.initialize()
	_build_ui()


func _input(event: InputEvent) -> void:
	if _waiting_action != &"":
		_capture_binding(event)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_F10:
			get_viewport().set_input_as_handled()
			if _overlay.visible:
				_close_menu()
			else:
				_open_menu()
		elif _overlay.visible and key_event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_menu()


func _exit_tree() -> void:
	if is_instance_valid(_overlay) and _overlay.visible:
		get_tree().paused = _was_paused


func open_menu() -> void:
	_open_menu()


func set_launcher_enabled(enabled: bool) -> void:
	_launcher_enabled = enabled
	if _open_button != null:
		_open_button.visible = enabled and not _overlay.visible


func _build_ui() -> void:
	_open_button = Button.new()
	_open_button.name = "OpenControlsButton"
	_open_button.text = "키 설정  [F10]"
	_open_button.focus_mode = Control.FOCUS_NONE
	_open_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_open_button.offset_left = -156.0
	_open_button.offset_top = 16.0
	_open_button.offset_right = -16.0
	_open_button.offset_bottom = 50.0
	_open_button.pressed.connect(_open_menu)
	add_child(_open_button)

	_overlay = ColorRect.new()
	_overlay.name = "ControlsOverlay"
	_overlay.color = Color(0.015, 0.02, 0.025, 0.86)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "키 설정"
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)

	var help := Label.new()
	help.text = "바꿀 항목을 누른 뒤 새 키나 마우스 버튼을 입력하세요. F10과 Esc는 메뉴 전용입니다."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(help)

	var separator := HSeparator.new()
	layout.add_child(separator)

	for action: StringName in InputBindingsService.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		layout.add_child(row)

		var action_label := Label.new()
		action_label.text = InputBindingsService.get_action_label(action)
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(action_label)

		var binding_button := Button.new()
		binding_button.custom_minimum_size = Vector2(190.0, 34.0)
		binding_button.focus_mode = Control.FOCUS_NONE
		binding_button.pressed.connect(_begin_rebind.bind(action))
		row.add_child(binding_button)
		_binding_buttons[action] = binding_button

	_status_label = Label.new()
	_status_label.text = "F10 또는 Esc로 닫을 수 있습니다."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.y = 40.0
	layout.add_child(_status_label)

	var actions_row := HBoxContainer.new()
	actions_row.alignment = BoxContainer.ALIGNMENT_END
	actions_row.add_theme_constant_override("separation", 10)
	layout.add_child(actions_row)

	var reset_button := Button.new()
	reset_button.text = "기본값 복원"
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_reset_bindings)
	actions_row.add_child(reset_button)

	var close_button := Button.new()
	close_button.text = "닫기"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close_menu)
	actions_row.add_child(close_button)

	_refresh_binding_buttons()
	_overlay.visible = false


func _open_menu() -> void:
	if _overlay.visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_waiting_action = &""
	_status_label.text = "F10 또는 Esc로 닫을 수 있습니다."
	_overlay.visible = true
	_open_button.visible = false


func _close_menu() -> void:
	if not _overlay.visible:
		return
	_waiting_action = &""
	_refresh_binding_buttons()
	_overlay.visible = false
	_open_button.visible = _launcher_enabled
	get_tree().paused = _was_paused


func _begin_rebind(action: StringName) -> void:
	_waiting_action = action
	_refresh_binding_buttons()
	var button := _binding_buttons[action] as Button
	button.text = "입력을 기다리는 중..."
	_status_label.text = "%s 입력을 기다리는 중 · Esc로 취소" % InputBindingsService.get_action_label(action)


func _capture_binding(event: InputEvent) -> void:
	var is_key_press: bool = false
	var is_mouse_press: bool = false
	if event is InputEventKey:
		var pressed_key := event as InputEventKey
		is_key_press = pressed_key.pressed and not pressed_key.echo
	elif event is InputEventMouseButton:
		is_mouse_press = (event as InputEventMouseButton).pressed
	if not is_key_press and not is_mouse_press:
		return

	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			_waiting_action = &""
			_refresh_binding_buttons()
			_status_label.text = "입력 변경을 취소했습니다."
			return
		if key_event.keycode == KEY_F10:
			_status_label.text = "F10은 키 설정 메뉴 전용입니다. 다른 입력을 눌러주세요."
			return
		if key_event.keycode == KEY_NONE and key_event.physical_keycode == KEY_NONE:
			return

	var changed_action := _waiting_action
	var conflicting_action: StringName = InputBindingsService.rebind_action(changed_action, event)
	_waiting_action = &""
	_refresh_binding_buttons()
	if conflicting_action == &"":
		_status_label.text = "%s 입력을 저장했습니다." % InputBindingsService.get_action_label(changed_action)
	else:
		_status_label.text = "%s와 %s의 입력을 서로 바꿨습니다." % [
			InputBindingsService.get_action_label(changed_action),
			InputBindingsService.get_action_label(conflicting_action),
		]


func _reset_bindings() -> void:
	_waiting_action = &""
	InputBindingsService.reset_to_defaults()
	_refresh_binding_buttons()
	_status_label.text = "모든 키를 기본값으로 복원했습니다."


func _refresh_binding_buttons() -> void:
	for action: StringName in InputBindingsService.ACTIONS:
		var button := _binding_buttons.get(action) as Button
		if button != null:
			button.text = InputBindingsService.get_binding_text(action)
