extends Node2D

const SLIDE_RESPONSE = preload("res://scripts/DiagonalSlideResponse.gd")
const IMPACT_DAMAGE = preload("res://scripts/ImpactDamage.gd")

const VIEW_SIZE := Vector2(960.0, 540.0)
const GRAVITY := 1150.0
const MAX_FALL_SPEED := 2000.0
const BODY_RADIUS := 15.0
const SLOPE_SIZE := Vector2(560.0, 26.0)
const SLOPE_CENTER := Vector2(480.0, 330.0)
const SLIDE_SPEED_RETENTION := 0.78
const SCENARIO_DURATION := 3.4
const RESET_DELAY := 0.65

const SCENARIOS := [
	{
		"name": "저속 · 우하향 경사",
		"initial_speed": 700.0,
		"slope_degrees": 32.0,
		"spawn_x": 350.0,
	},
	{
		"name": "중속 · 좌하향 경사",
		"initial_speed": 1250.0,
		"slope_degrees": -32.0,
		"spawn_x": 610.0,
	},
	{
		"name": "고속 · 우하향 경사",
		"initial_speed": 1800.0,
		"slope_degrees": 32.0,
		"spawn_x": 350.0,
	},
]

var _slope: StaticBody2D
var _body: CharacterBody2D
var _body_visual: Polygon2D
var _trail: Line2D
var _scenario_label: Label
var _metrics_label: Label
var _result_label: Label
var _scenario_index := 0
var _scenario_time := 0.0
var _reset_timer := -1.0
var _has_impacted := false
var completed_pass_count := 0


func _ready() -> void:
	_build_background()
	_build_trail()
	_build_slope()
	_build_test_body()
	_build_hud()
	_start_scenario(0)


func _physics_process(delta: float) -> void:
	if _reset_timer >= 0.0:
		_reset_timer -= delta
		if _reset_timer <= 0.0:
			_start_scenario((_scenario_index + 1) % SCENARIOS.size())
		return

	_scenario_time += delta
	_body.velocity.y = minf(_body.velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	var incoming_velocity := _body.velocity
	_body.move_and_slide()

	for collision_index in _body.get_slide_collision_count():
		var collision := _body.get_slide_collision(collision_index)
		if collision.get_collider() == _slope and not _has_impacted:
			_resolve_slope_contact(incoming_velocity, collision.get_normal())

	_append_trail_point()
	if _scenario_time >= SCENARIO_DURATION:
		_schedule_next_scenario()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_SPACE:
			_start_scenario((_scenario_index + 1) % SCENARIOS.size())
		elif key_event.keycode == KEY_R:
			_start_scenario(_scenario_index)


func _resolve_slope_contact(incoming_velocity: Vector2, surface_normal: Vector2) -> void:
	_has_impacted = true
	var normal_speed: float = SLIDE_RESPONSE.impact_speed(incoming_velocity, surface_normal)
	var outgoing_velocity: Vector2 = SLIDE_RESPONSE.slide_velocity(
		incoming_velocity,
		surface_normal,
		SLIDE_SPEED_RETENTION
	)
	var damage: int = IMPACT_DAMAGE.damage_for_speed(normal_speed)
	_body.velocity = outgoing_velocity
	_body_visual.color = Color.html("#ff7a68")

	var normal_residual := absf(outgoing_velocity.dot(surface_normal.normalized()))
	var slowed := outgoing_velocity.length() < incoming_velocity.length()
	var redirected := absf(outgoing_velocity.x) > 20.0
	var passed := slowed and redirected and normal_residual < 0.1
	if passed:
		completed_pass_count += 1
	var scenario: Dictionary = SCENARIOS[_scenario_index]
	print(
		"DiagonalSlideTest | %s | incoming=%d normal=%d outgoing=%d damage=%d | %s"
		% [
			str(scenario["name"]),
			int(round(incoming_velocity.length())),
			int(round(normal_speed)),
			int(round(outgoing_velocity.length())),
			damage,
			"PASS" if passed else "CHECK",
		]
	)

	_metrics_label.text = (
		"진입 속도  %4d\n법선 충격  %4d\n이탈 속도  %4d\n접촉 피해  -%d"
		% [
			int(round(incoming_velocity.length())),
			int(round(normal_speed)),
			int(round(outgoing_velocity.length())),
			damage,
		]
	)
	_result_label.text = "PASS · 감속 후 경사 방향으로 이탈" if passed else "CHECK · 응답 조건 불일치"
	_result_label.modulate = Color.html("#8ee88e") if passed else Color.html("#ff8f8f")


func _start_scenario(index: int) -> void:
	_scenario_index = index
	_scenario_time = 0.0
	_reset_timer = -1.0
	_has_impacted = false
	_trail.clear_points()

	var scenario: Dictionary = SCENARIOS[_scenario_index]
	_slope.rotation = deg_to_rad(float(scenario["slope_degrees"]))
	_body.global_position = Vector2(float(scenario["spawn_x"]), 42.0)
	_body.velocity = Vector2(0.0, float(scenario["initial_speed"]))
	_body_visual.color = Color.html("#f5d06f")

	_scenario_label.text = (
		"%d / %d  %s  ·  초기 낙하 %d"
		% [
			_scenario_index + 1,
			SCENARIOS.size(),
			str(scenario["name"]),
			int(scenario["initial_speed"]),
		]
	)
	_metrics_label.text = "경사면 접촉 대기 중…"
	_result_label.text = "자동 반복 · Space 다음 · R 다시"
	_result_label.modulate = Color.WHITE
	_append_trail_point()


func _schedule_next_scenario() -> void:
	if _reset_timer < 0.0:
		_reset_timer = RESET_DELAY


func _append_trail_point() -> void:
	if _trail.get_point_count() > 0:
		var last_point := _trail.get_point_position(_trail.get_point_count() - 1)
		if last_point.distance_squared_to(_body.global_position) < 16.0:
			return
	_trail.add_point(_body.global_position)
	if _trail.get_point_count() > 220:
		_trail.remove_point(0)


func _build_background() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.position = Vector2.ZERO
	background.size = VIEW_SIZE
	background.color = Color.html("#171d24")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	for x in range(0, int(VIEW_SIZE.x) + 1, 80):
		_add_guide_line(Vector2(x, 0), Vector2(x, VIEW_SIZE.y))
	for y in range(0, int(VIEW_SIZE.y) + 1, 60):
		_add_guide_line(Vector2(0, y), Vector2(VIEW_SIZE.x, y))


func _add_guide_line(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 1.0
	line.default_color = Color(0.34, 0.42, 0.5, 0.14)
	line.add_point(from)
	line.add_point(to)
	add_child(line)


func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.name = "TrajectoryTrail"
	_trail.width = 4.0
	_trail.default_color = Color(0.45, 0.82, 1.0, 0.72)
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)


func _build_slope() -> void:
	_slope = StaticBody2D.new()
	_slope.name = "DiagonalDamageSurface"
	_slope.position = SLOPE_CENTER
	_slope.collision_layer = 1
	_slope.collision_mask = 0
	add_child(_slope)

	var shape := RectangleShape2D.new()
	shape.size = SLOPE_SIZE
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	_slope.add_child(collision_shape)

	var visual := Polygon2D.new()
	var half_size := SLOPE_SIZE * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	visual.color = Color.html("#b64343")
	_slope.add_child(visual)


func _build_test_body() -> void:
	_body = CharacterBody2D.new()
	_body.name = "AutoDropBody"
	_body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_body.collision_layer = 2
	_body.collision_mask = 1
	add_child(_body)

	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = circle
	_body.add_child(collision_shape)

	_body_visual = Polygon2D.new()
	var points := PackedVector2Array()
	for point_index in 16:
		points.append(Vector2.RIGHT.rotated(TAU * float(point_index) / 16.0) * BODY_RADIUS)
	_body_visual.polygon = points
	_body_visual.color = Color.html("#f5d06f")
	_body.add_child(_body_visual)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(18.0, 16.0)
	panel.size = Vector2(445.0, 184.0)
	panel.color = Color(0.025, 0.035, 0.045, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)

	var title := Label.new()
	title.position = Vector2(32.0, 26.0)
	title.size = Vector2(420.0, 28.0)
	title.text = "대각선 피해 완충면 · 실행 가능한 의도"
	title.add_theme_font_size_override("font_size", 20)
	canvas.add_child(title)

	var intent := Label.new()
	intent.position = Vector2(32.0, 56.0)
	intent.size = Vector2(420.0, 42.0)
	intent.text = "안전한 착지점이 아니라, 고속이면 피해를 받고\n속도를 줄이며 경로가 꺾이는 완충 루트"
	intent.modulate = Color.html("#c7d2dd")
	canvas.add_child(intent)

	_scenario_label = Label.new()
	_scenario_label.position = Vector2(32.0, 105.0)
	_scenario_label.size = Vector2(420.0, 24.0)
	canvas.add_child(_scenario_label)

	_metrics_label = Label.new()
	_metrics_label.position = Vector2(710.0, 22.0)
	_metrics_label.size = Vector2(225.0, 104.0)
	_metrics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	canvas.add_child(_metrics_label)

	_result_label = Label.new()
	_result_label.position = Vector2(32.0, 148.0)
	_result_label.size = Vector2(420.0, 28.0)
	canvas.add_child(_result_label)
