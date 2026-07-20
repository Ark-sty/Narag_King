class_name DiagonalSlideResponse
extends RefCounted


static func impact_speed(incoming_velocity: Vector2, surface_normal: Vector2) -> float:
	var normal := surface_normal.normalized()
	return maxf(0.0, -incoming_velocity.dot(normal))


static func slide_velocity(
	incoming_velocity: Vector2,
	surface_normal: Vector2,
	speed_retention: float
) -> Vector2:
	var normal := surface_normal.normalized()
	return incoming_velocity.slide(normal) * clampf(speed_retention, 0.0, 1.0)
