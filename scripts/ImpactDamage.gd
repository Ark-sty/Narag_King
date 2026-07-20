class_name ImpactDamage
extends RefCounted

const WARNING_IMPACT_SPEED := 850.0
const SAFE_IMPACT_SPEED := 1200.0
const LETHAL_IMPACT_SPEED := 1850.0
const MAX_DAMAGE := 100
const DAMAGE_QUANTUM := 8
const DAMAGE_CURVE_EXPONENT := 1.4


static func damage_for_speed(impact_speed: float) -> int:
	var damage_ratio := get_damage_ratio(impact_speed)
	if damage_ratio <= 0.0:
		return 0

	var curved_damage := pow(damage_ratio, DAMAGE_CURVE_EXPONENT) * float(MAX_DAMAGE)
	var quantized_damage := ceili(curved_damage / float(DAMAGE_QUANTUM)) * DAMAGE_QUANTUM
	return clampi(quantized_damage, DAMAGE_QUANTUM, MAX_DAMAGE)


static func get_damage_ratio(impact_speed: float) -> float:
	return clampf(
		inverse_lerp(SAFE_IMPACT_SPEED, LETHAL_IMPACT_SPEED, impact_speed),
		0.0,
		1.0
	)


static func get_warning_ratio(impact_speed: float) -> float:
	return clampf(
		inverse_lerp(WARNING_IMPACT_SPEED, LETHAL_IMPACT_SPEED, impact_speed),
		0.0,
		1.0
	)
