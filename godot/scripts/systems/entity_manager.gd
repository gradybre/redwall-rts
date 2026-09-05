extends Node
## ECS core: entity lifetime and component storage.
##
## Entities are plain integer ids, never scene-tree nodes. Components are held
## in one dictionary per component type keyed by entity id, so a system can walk
## a single component type without traversing the tree. Ids are monotonic and
## are never reused within a session, so a stale id can never alias a live
## entity.
##
## Systems iterate entities via query(), which returns a snapshot. The internal
## stores are deliberately not exposed: destroying an entity erases rows from
## them, and a caller iterating a live store would silently skip entities.

const ComponentBase := preload("res://scripts/components/component.gd")

const INVALID_ENTITY: int = 0

var _next_entity_id: int = 1
var _alive: Dictionary = {}
var _storage: Dictionary = {}


func _ready() -> void:
	"""Report readiness at boot."""
	print("[EntityManager] ready")


func create_entity() -> int:
	"""Allocate and return a new live entity id."""
	var entity_id: int = _next_entity_id
	_next_entity_id += 1
	_alive[entity_id] = true
	return entity_id


func destroy_entity(entity_id: int) -> bool:
	"""Remove an entity and every component attached to it. False when not alive."""
	if not _alive.has(entity_id):
		return false
	for component_name: StringName in _storage:
		var store: Dictionary = _storage[component_name]
		store.erase(entity_id)
	_alive.erase(entity_id)
	return true


func is_alive(entity_id: int) -> bool:
	"""True when the id has been created and not yet destroyed."""
	return _alive.has(entity_id)


func entity_count() -> int:
	"""Number of live entities."""
	return _alive.size()


func add_component(entity_id: int, component: ComponentBase) -> bool:
	"""Attach a component, replacing any existing component of the same type."""
	if component == null or not _alive.has(entity_id):
		return false
	var component_name: StringName = component.get_component_name()
	if component_name == &"":
		return false
	if not _storage.has(component_name):
		_storage[component_name] = {}
	_storage[component_name][entity_id] = component
	return true


func get_component(entity_id: int, component_name: StringName) -> ComponentBase:
	"""Return the entity's component of that type, or null when it has none."""
	if not _storage.has(component_name):
		return null
	var store: Dictionary = _storage[component_name]
	return store.get(entity_id, null)


func has_component(entity_id: int, component_name: StringName) -> bool:
	"""True when the entity owns a component of that type."""
	if not _storage.has(component_name):
		return false
	var store: Dictionary = _storage[component_name]
	return store.has(entity_id)


func remove_component(entity_id: int, component_name: StringName) -> bool:
	"""Detach one component type from an entity. False when it was not attached."""
	if not has_component(entity_id, component_name):
		return false
	var store: Dictionary = _storage[component_name]
	store.erase(entity_id)
	return true


func get_component_count(component_name: StringName) -> int:
	"""How many live entities currently carry a component of that type."""
	if not _storage.has(component_name):
		return 0
	var store: Dictionary = _storage[component_name]
	return store.size()


func query(component_names: Array[StringName]) -> PackedInt64Array:
	"""Return a snapshot of every live entity id owning all the given component types.

	The result is a copy, so the caller may destroy entities while iterating it.
	"""
	var results: PackedInt64Array = PackedInt64Array()
	if component_names.is_empty():
		return results
	var stores: Array[Dictionary] = _resolve_stores(component_names)
	if stores.is_empty():
		return results
	var pivot: Dictionary = stores.pop_back()
	for entity_id: int in pivot:
		if _in_every_store(entity_id, stores):
			results.append(entity_id)
	return results


func clear() -> void:
	"""Drop every entity and component. Used on scene load and between tests."""
	_alive.clear()
	_storage.clear()
	_next_entity_id = 1


func _resolve_stores(component_names: Array[StringName]) -> Array[Dictionary]:
	"""Stores for the requested types, smallest last, or empty if any type is unused."""
	var stores: Array[Dictionary] = []
	for component_name: StringName in component_names:
		if not _storage.has(component_name):
			return []
		stores.append(_storage[component_name])
	var smallest_index: int = 0
	for index: int in stores.size():
		if stores[index].size() < stores[smallest_index].size():
			smallest_index = index
	var last_index: int = stores.size() - 1
	var smallest: Dictionary = stores[smallest_index]
	stores[smallest_index] = stores[last_index]
	stores[last_index] = smallest
	return stores


func _in_every_store(entity_id: int, stores: Array[Dictionary]) -> bool:
	"""True when the entity appears in all of the already-resolved stores."""
	for store: Dictionary in stores:
		if not store.has(entity_id):
			return false
	return true
