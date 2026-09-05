class_name HealthComponent
extends "res://scripts/components/component.gd"
## Hit points for anything that can be damaged or killed.

const COMPONENT_NAME: StringName = &"health"

@export var max_health: int = 100
@export var current_health: int = 100


func get_component_name() -> StringName:
	"""Return the storage key for health data."""
	return COMPONENT_NAME


func is_dead() -> bool:
	"""True once current health has reached zero."""
	return current_health <= 0


func health_fraction() -> float:
	"""Current health as a 0.0-1.0 fraction of maximum, safe against a zero maximum."""
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)
