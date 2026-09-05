class_name PositionComponent
extends "res://scripts/components/component.gd"
## World placement and heading for an entity.

const COMPONENT_NAME: StringName = &"position"

@export var position: Vector3 = Vector3.ZERO
@export var facing_radians: float = 0.0


func get_component_name() -> StringName:
	"""Return the storage key for position data."""
	return COMPONENT_NAME
