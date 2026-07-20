class_name InputBindings
extends RefCounted

const CONFIG_PATH := "user://input_bindings.cfg"

const ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"grab",
	&"charge_launch",
	&"restart",
]

const ACTION_LABELS := {
	&"move_left": "왼쪽 이동",
	&"move_right": "오른쪽 이동",
	&"move_up": "위쪽 조준",
	&"move_down": "아래쪽 조준",
	&"grab": "잡기",
	&"charge_launch": "충전 / 발사",
	&"restart": "재시작",
}

static var _default_input_events: Dictionary = {}
static var _initialized := false


static func initialize() -> void:
	if _initialized:
		return

	_capture_default_input_events()
	_initialized = true
	_load_user_bindings()


static func get_action_label(action: StringName) -> String:
	return String(ACTION_LABELS.get(action, action))


static func get_binding_text(action: StringName) -> String:
	initialize()
	var event := _get_primary_input_event(action)
	if event == null:
		return "미지정"
	return event.as_text()


static func rebind_action(action: StringName, source_event: InputEvent) -> StringName:
	initialize()
	var new_event := _copy_input_event(source_event)
	if new_event == null:
		return &""
	var previous_event := _get_primary_input_event(action)
	var conflicting_action := _find_conflicting_action(action, new_event)

	if conflicting_action != &"" and previous_event != null:
		_replace_input_events(conflicting_action, previous_event)
	_replace_input_events(action, new_event)
	_save_bindings()
	return conflicting_action


static func reset_to_defaults() -> void:
	initialize()
	for action: StringName in ACTIONS:
		_remove_remappable_events(action)
		var defaults: Array = _default_input_events.get(action, [])
		for event: InputEvent in defaults:
			InputMap.action_add_event(action, event.duplicate(true) as InputEvent)
	_save_bindings()


static func _capture_default_input_events() -> void:
	for action: StringName in ACTIONS:
		var defaults: Array[InputEvent] = []
		if InputMap.has_action(action):
			for event: InputEvent in InputMap.action_get_events(action):
				if _is_remappable_event(event):
					defaults.append(event.duplicate(true) as InputEvent)
		_default_input_events[action] = defaults


static func _load_user_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return

	for action: StringName in ACTIONS:
		var saved: Variant = config.get_value("bindings", String(action), null)
		if not saved is Dictionary:
			continue
		var event := _dictionary_to_event(saved as Dictionary)
		if event != null:
			_replace_input_events(action, event)


static func _save_bindings() -> void:
	var config := ConfigFile.new()
	for action: StringName in ACTIONS:
		var event := _get_primary_input_event(action)
		if event != null:
			config.set_value("bindings", String(action), _event_to_dictionary(event))
	config.save(CONFIG_PATH)


static func _get_primary_input_event(action: StringName) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event: InputEvent in InputMap.action_get_events(action):
		if _is_remappable_event(event):
			return event
	return null


static func _replace_input_events(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	_remove_remappable_events(action)
	InputMap.action_add_event(action, event)


static func _remove_remappable_events(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		if _is_remappable_event(event):
			InputMap.action_erase_event(action, event)


static func _find_conflicting_action(action: StringName, new_event: InputEvent) -> StringName:
	for candidate: StringName in ACTIONS:
		if candidate == action:
			continue
		var current_event := _get_primary_input_event(candidate)
		if current_event != null and _input_events_match(current_event, new_event):
			return candidate
	return &""


static func _input_events_match(first: InputEvent, second: InputEvent) -> bool:
	if first is InputEventKey and second is InputEventKey:
		return _key_events_match(first as InputEventKey, second as InputEventKey)
	if first is InputEventMouseButton and second is InputEventMouseButton:
		var first_mouse := first as InputEventMouseButton
		var second_mouse := second as InputEventMouseButton
		return (
			first_mouse.button_index == second_mouse.button_index
			and first_mouse.alt_pressed == second_mouse.alt_pressed
			and first_mouse.ctrl_pressed == second_mouse.ctrl_pressed
			and first_mouse.meta_pressed == second_mouse.meta_pressed
			and first_mouse.shift_pressed == second_mouse.shift_pressed
		)
	return false


static func _key_events_match(first: InputEventKey, second: InputEventKey) -> bool:
	var first_code: Key = first.physical_keycode if first.physical_keycode != KEY_NONE else first.keycode
	var second_code: Key = second.physical_keycode if second.physical_keycode != KEY_NONE else second.keycode
	return (
		first_code == second_code
		and first.alt_pressed == second.alt_pressed
		and first.ctrl_pressed == second.ctrl_pressed
		and first.meta_pressed == second.meta_pressed
		and first.shift_pressed == second.shift_pressed
	)


static func _copy_input_event(source: InputEvent) -> InputEvent:
	if source is InputEventKey:
		var source_key := source as InputEventKey
		var key_event := InputEventKey.new()
		key_event.keycode = source_key.keycode
		key_event.physical_keycode = source_key.physical_keycode
		key_event.key_label = source_key.key_label
		key_event.location = source_key.location
		_copy_modifiers(source_key, key_event)
		return key_event
	if source is InputEventMouseButton:
		var source_mouse := source as InputEventMouseButton
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = source_mouse.button_index
		_copy_modifiers(source_mouse, mouse_event)
		return mouse_event
	return null


static func _copy_modifiers(source: InputEventWithModifiers, target: InputEventWithModifiers) -> void:
	target.alt_pressed = source.alt_pressed
	target.ctrl_pressed = source.ctrl_pressed
	target.meta_pressed = source.meta_pressed
	target.shift_pressed = source.shift_pressed


static func _event_to_dictionary(event: InputEvent) -> Dictionary:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return {
			"type": "mouse_button",
			"button_index": int(mouse_event.button_index),
			"alt": mouse_event.alt_pressed,
			"ctrl": mouse_event.ctrl_pressed,
			"meta": mouse_event.meta_pressed,
			"shift": mouse_event.shift_pressed,
		}

	var key_event := event as InputEventKey
	return {
		"type": "key",
		"keycode": int(key_event.keycode),
		"physical_keycode": int(key_event.physical_keycode),
		"key_label": int(key_event.key_label),
		"location": int(key_event.location),
		"alt": key_event.alt_pressed,
		"ctrl": key_event.ctrl_pressed,
		"meta": key_event.meta_pressed,
		"shift": key_event.shift_pressed,
	}


static func _dictionary_to_event(data: Dictionary) -> InputEvent:
	if String(data.get("type", "key")) == "mouse_button":
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = int(data.get("button_index", 0))
		_apply_saved_modifiers(data, mouse_event)
		if mouse_event.button_index == MOUSE_BUTTON_NONE:
			return null
		return mouse_event

	var key_event := InputEventKey.new()
	key_event.keycode = int(data.get("keycode", 0))
	key_event.physical_keycode = int(data.get("physical_keycode", 0))
	key_event.key_label = int(data.get("key_label", 0))
	key_event.location = int(data.get("location", 0))
	_apply_saved_modifiers(data, key_event)
	if key_event.keycode == KEY_NONE and key_event.physical_keycode == KEY_NONE:
		return null
	return key_event


static func _apply_saved_modifiers(data: Dictionary, event: InputEventWithModifiers) -> void:
	event.alt_pressed = bool(data.get("alt", false))
	event.ctrl_pressed = bool(data.get("ctrl", false))
	event.meta_pressed = bool(data.get("meta", false))
	event.shift_pressed = bool(data.get("shift", false))


static func _is_remappable_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton
