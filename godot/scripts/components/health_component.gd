class_name HealthComponent
extends "res://scripts/components/component.gd"
## Hit points for anything that can be damaged or killed.
##
## PROTOTYPE ECS DATA. THIS IS NOT THE SETTLEMENT HEALTH MODEL. Settlement health, status and
## death live in `scripts/core/needs.gd` as packed integer columns (`health_of`, `status_of`,
## `apply_health_event`), and nothing in the settlement build reads this class.
##
## It stayed in `scripts/components/` when ARCH-MIG-006 step 7 moved
## `scripts/legacy_battle/combat_system.gd` out of the autoload list, because it does NOT belong
## to that module alone: `test/test_entity_manager.gd` uses it in twelve places as its sample
## component for add/get/remove/query coverage of the prototype EntityManager. Moving it would
## have edited a file this task does not own to no benefit. Its two remaining readers are that
## suite and the legacy battle module.
##
## It violates the GDD the same way decision 0006 row 4 records for every file in this
## directory -- one Resource per entity rather than a packed column -- and `health_fraction()`
## returns a float, which authoritative state may not do. Do not extend it.

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
