extends "res://test/framework/test_case.gd"
## Coverage for the ECS core: entity lifetime, component storage, and queries.

const EntityManagerScript := preload("res://scripts/systems/entity_manager.gd")
const PositionComponentScript := preload("res://scripts/components/position_component.gd")
const HealthComponentScript := preload("res://scripts/components/health_component.gd")
const PerfTimerScript := preload("res://scripts/utils/perf_timer.gd")

const PERF_ENTITY_COUNT: int = 1000
const PERF_BUDGET_MSEC: float = 16.0

var _entities: EntityManagerScript = null


func before_each() -> void:
	"""Build a fresh entity manager outside the scene tree."""
	_entities = EntityManagerScript.new()


func after_each() -> void:
	"""Free the entity manager built for the test."""
	if _entities != null:
		_entities.free()
		_entities = null


func test_create_entity_returns_unique_ids() -> void:
	"""Successive creates never hand out the same id."""
	var first: int = _entities.create_entity()
	var second: int = _entities.create_entity()
	assert_true(first != second, "ids are unique")
	assert_true(first != EntityManagerScript.INVALID_ENTITY, "id is not the invalid sentinel")
	assert_equal(_entities.entity_count(), 2, "two entities are live")


func test_is_alive_tracks_lifetime() -> void:
	"""An entity is alive from create until destroy, and never after."""
	var entity_id: int = _entities.create_entity()
	assert_true(_entities.is_alive(entity_id), "entity is alive after create")
	assert_true(_entities.destroy_entity(entity_id), "destroy reports success")
	assert_false(_entities.is_alive(entity_id), "entity is dead after destroy")
	assert_equal(_entities.entity_count(), 0, "no entities remain")


func test_destroy_rejects_unknown_id() -> void:
	"""Destroying an id that was never created is a no-op returning false."""
	assert_false(_entities.destroy_entity(42), "unknown id cannot be destroyed")


func test_destroyed_ids_are_never_reused() -> void:
	"""A recycled id would let a stale reference alias a new entity."""
	var first: int = _entities.create_entity()
	_entities.destroy_entity(first)
	var second: int = _entities.create_entity()
	assert_true(second != first, "new entity does not reuse the destroyed id")


func test_add_and_get_component() -> void:
	"""A component added to a live entity comes back by type name."""
	var entity_id: int = _entities.create_entity()
	var position := PositionComponentScript.new()
	position.position = Vector3(3.0, 0.0, -7.0)
	assert_true(_entities.add_component(entity_id, position), "add reports success")
	assert_true(_entities.has_component(entity_id, PositionComponentScript.COMPONENT_NAME), "has_component sees it")
	var stored := _entities.get_component(entity_id, PositionComponentScript.COMPONENT_NAME) as PositionComponentScript
	assert_not_null(stored, "component is retrievable")
	assert_equal(stored.position, Vector3(3.0, 0.0, -7.0), "component data survives storage")


func test_get_component_returns_null_when_absent() -> void:
	"""Asking for a component the entity does not own yields null, not an error."""
	var entity_id: int = _entities.create_entity()
	assert_null(_entities.get_component(entity_id, PositionComponentScript.COMPONENT_NAME), "absent component is null")
	assert_false(_entities.has_component(entity_id, PositionComponentScript.COMPONENT_NAME), "has_component is false")


func test_add_component_rejects_dead_entity() -> void:
	"""Components cannot be attached to an id that is not live."""
	var entity_id: int = _entities.create_entity()
	_entities.destroy_entity(entity_id)
	assert_false(_entities.add_component(entity_id, PositionComponentScript.new()), "add fails on a dead entity")


func test_add_component_replaces_same_type() -> void:
	"""Adding a second component of one type overwrites the first."""
	var entity_id: int = _entities.create_entity()
	var first := HealthComponentScript.new()
	first.current_health = 10
	var second := HealthComponentScript.new()
	second.current_health = 99
	_entities.add_component(entity_id, first)
	_entities.add_component(entity_id, second)
	var stored := _entities.get_component(entity_id, HealthComponentScript.COMPONENT_NAME) as HealthComponentScript
	assert_equal(stored.current_health, 99, "the later component wins")
	assert_equal(_entities.get_component_count(HealthComponentScript.COMPONENT_NAME), 1, "storage holds one entry")


func test_remove_component() -> void:
	"""Removing a component detaches it and reports whether it was there."""
	var entity_id: int = _entities.create_entity()
	_entities.add_component(entity_id, PositionComponentScript.new())
	assert_true(_entities.remove_component(entity_id, PositionComponentScript.COMPONENT_NAME), "remove reports success")
	assert_false(_entities.has_component(entity_id, PositionComponentScript.COMPONENT_NAME), "component is gone")
	assert_false(_entities.remove_component(entity_id, PositionComponentScript.COMPONENT_NAME), "second remove is a no-op")


func test_destroy_entity_clears_its_components() -> void:
	"""Destroying an entity must not leave orphaned rows in component storage."""
	var entity_id: int = _entities.create_entity()
	_entities.add_component(entity_id, PositionComponentScript.new())
	_entities.add_component(entity_id, HealthComponentScript.new())
	_entities.destroy_entity(entity_id)
	assert_equal(_entities.get_component_count(PositionComponentScript.COMPONENT_NAME), 0, "position storage is empty")
	assert_equal(_entities.get_component_count(HealthComponentScript.COMPONENT_NAME), 0, "health storage is empty")


func test_query_returns_entities_owning_every_type() -> void:
	"""A multi-type query is an intersection, not a union."""
	var both: int = _entities.create_entity()
	_entities.add_component(both, PositionComponentScript.new())
	_entities.add_component(both, HealthComponentScript.new())
	var position_only: int = _entities.create_entity()
	_entities.add_component(position_only, PositionComponentScript.new())
	var types: Array[StringName] = [PositionComponentScript.COMPONENT_NAME, HealthComponentScript.COMPONENT_NAME]
	var results: PackedInt64Array = _entities.query(types)
	assert_equal(results.size(), 1, "only the entity with both types matches")
	assert_equal(results[0], both, "the matching entity is returned")


func test_query_with_unused_type_is_empty() -> void:
	"""Querying a component type nothing owns yields no entities."""
	var entity_id: int = _entities.create_entity()
	_entities.add_component(entity_id, PositionComponentScript.new())
	var types: Array[StringName] = [PositionComponentScript.COMPONENT_NAME, HealthComponentScript.COMPONENT_NAME]
	var results: PackedInt64Array = _entities.query(types)
	assert_equal(results.size(), 0, "no entity owns the unused type")


func test_query_with_no_types_is_empty() -> void:
	"""An empty query matches nothing rather than every entity."""
	_entities.create_entity()
	var empty: Array[StringName] = []
	assert_equal(_entities.query(empty).size(), 0, "empty query returns no results")


func test_clear_resets_the_manager() -> void:
	"""clear() drops entities, components and the id counter together."""
	var entity_id: int = _entities.create_entity()
	_entities.add_component(entity_id, PositionComponentScript.new())
	_entities.clear()
	assert_equal(_entities.entity_count(), 0, "no entities remain")
	assert_equal(_entities.get_component_count(PositionComponentScript.COMPONENT_NAME), 0, "no components remain")
	assert_false(_entities.is_alive(entity_id), "the old id is not alive")


func test_thousand_entity_lifecycle_within_frame_budget() -> void:
	"""Create, query and destroy 1000 entities inside a single 16ms frame."""
	var timer := PerfTimerScript.new()
	var ids: PackedInt64Array = PackedInt64Array()
	timer.start()
	for index: int in PERF_ENTITY_COUNT:
		var entity_id: int = _entities.create_entity()
		_entities.add_component(entity_id, PositionComponentScript.new())
		_entities.add_component(entity_id, HealthComponentScript.new())
		ids.append(entity_id)
	var types: Array[StringName] = [PositionComponentScript.COMPONENT_NAME, HealthComponentScript.COMPONENT_NAME]
	var matched: PackedInt64Array = _entities.query(types)
	for entity_id: int in ids:
		_entities.destroy_entity(entity_id)
	var elapsed_msec: float = timer.stop() / 1000.0
	assert_equal(matched.size(), PERF_ENTITY_COUNT, "every entity matched the query")
	assert_equal(_entities.entity_count(), 0, "every entity was destroyed")
	assert_less_than(elapsed_msec, PERF_BUDGET_MSEC, "1000-entity lifecycle stays under the frame budget")


func test_query_snapshot_survives_destruction_while_iterating() -> void:
	"""Destroying entities while walking a query result must visit every entity."""
	var ids: Array[int] = []
	for index: int in 10:
		var entity_id: int = _entities.create_entity()
		_entities.add_component(entity_id, HealthComponentScript.new())
		ids.append(entity_id)
	var types: Array[StringName] = [HealthComponentScript.COMPONENT_NAME]
	var visited: int = 0
	for entity_id: int in _entities.query(types):
		visited += 1
		_entities.destroy_entity(entity_id)
	assert_equal(visited, 10, "every entity was visited")
	assert_equal(_entities.entity_count(), 0, "every entity was destroyed")
	assert_equal(_entities.get_component_count(HealthComponentScript.COMPONENT_NAME), 0, "no orphaned component rows")


func test_component_count_is_zero_for_unused_type() -> void:
	"""Counting a component type nothing owns is zero, not an error."""
	assert_equal(_entities.get_component_count(&"nonexistent"), 0, "unused type counts zero")
