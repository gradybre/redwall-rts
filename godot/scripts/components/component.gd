class_name Component
extends Resource
## Base class for all ECS component data.
##
## Components are pure typed data — behaviour lives in the autoloaded systems
## under `scripts/systems/`. Every subclass declares its own COMPONENT_NAME
## constant and returns it from `get_component_name()`; EntityManager uses that
## StringName as the storage key.


func get_component_name() -> StringName:
	"""Return the StringName key this component is stored under. Subclasses must override."""
	push_error("Component subclass did not override get_component_name().")
	return &""
