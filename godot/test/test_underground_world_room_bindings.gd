extends "res://test/framework/test_case.gd"
## Actual World/Room/Sites composition. Fixture registration remains explicitly unstarted test data.

const Fixture := preload("res://test/test_underground_room_bindings.gd")
const Masks := preload("res://scripts/core/underground_room_bindings.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const WorldComposer := preload("res://scripts/core/underground_world_bindings.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)


class ObservedMasks extends Masks:

	## Calls real observations first; adverse hooks only revoke or attempt nested access afterward.
	var composer: WorldComposer = null
	var arena: Budget = null
	var expire: bool = false
	var reenter: bool = false
	var replacement: int = 0
	var nested_mask: StringName = &""
	var nested_section: Vector2i = NULL_REF
	var nested_snapshot: StringName = &""
	var section_calls: int = 0
	var mask_calls: int = 0

	func phase_section_into(site: Vector2i, room: Vector2i, token: int, out: Owner.Region) -> StringName:
		"""Expiry after successful actual metadata observation must invalidate the wrapper's returned handle."""
		section_calls += 1
		var code: StringName = super.phase_section_into(site, room, token, out)
		if code == &"" and expire:
			_expire(token)
		return code

	func finish_mask_into(site: Vector2i, room: Vector2i, token: int,
			limit: int, out: PackedInt32Array) -> StringName:
		"""Keep all actual claim/Domain proofs, then try to invalidate their lifetime or reuse borrowed scratch."""
		mask_calls += 1
		var code: StringName = super.finish_mask_into(site, room, token, limit, out)
		if code == &"" and reenter:
			nested_mask = composer.finish_mask_into(site, room, token, limit, out)
			nested_section = composer.floor_section(site, room)
			var snapshot: Space.Snapshot = Space.Snapshot.new()
			nested_snapshot = composer.composed_snapshot_into(PackedInt32Array([0, 0, 0, 1, 1, 1]), snapshot, token)
		if code == &"" and expire:
			_expire(token)
		return code

	func _expire(token: int) -> void:
		"""The original actual phase ends; a newly funded operation is not its continuation."""
		expire = false
		composer.end_cold_operation(token)
		replacement = arena.acquire(Budget.COLD_BYTES)
		assert(replacement > 0 and replacement != token, "Negative fixture acquires its own different lifetime")


var _actual: Fixture = null
var _reader: ObservedMasks = null


func before_each() -> void:
	"""Reuse actual-store fixture setup without rerunning its test methods or replacing physical decisions."""
	_actual = Fixture.new()
	_actual.before_each()
	assert_true(_actual.failures.is_empty(), "actual fixture initialized")
	_actual._world_bindings.end_cold_operation(_actual._lease)
	_actual._lease = 0
	_actual._masks = null
	_reader = ObservedMasks.new()
	_reader.composer = _actual._world_bindings
	_reader.arena = _actual._budget
	assert_equal(_reader.configure(_actual._world_bindings, _actual._sites, _actual._budget), &"", "actual reader")
	assert_equal(_actual._world_bindings.bind_room_bindings(_reader), &"", "exact weak reciprocal wiring")
	_actual._open_scope()


func after_each() -> void:
	"""Only test-owned replacement leases are released; all actual collaborator cycles must be absent."""
	if _reader != null and _reader.replacement > 0:
		assert_true(_actual._budget.covers(_reader.replacement, Budget.COLD_BYTES), "replacement still owned by fixture")
		assert_equal(_actual._budget.release(_reader.replacement), &"", "release exact test replacement")
	_reader = null
	_actual.after_each()
	assert_true(_actual.failures.is_empty(), "actual fixture observations and cleanup passed")
	_actual = null


func _mask() -> PackedInt32Array:
	"""One synchronous caller output remains inside its exact actual phase lifetime."""
	var result: PackedInt32Array = PackedInt32Array()
	assert_equal(_actual._world_bindings.finish_mask_into(_actual._site, _actual._room,
		_actual._lease, 8, result), &"", "whole exact actual outline")
	return result


func _unbound_composer() -> WorldComposer:
	"""An independently configured composer sharing stores is still a different phase-scope owner."""
	var result: WorldComposer = WorldComposer.new()
	assert_equal(result.configure(_actual._world, _actual._terrain, _actual._owner,
		_actual._sources, _actual._budget), &"", "same stores, distinct composer")
	return result


func test_exact_section_and_fine_mask_are_delegated_without_changing_physical_state() -> void:
	"""The empty central hole and floor below an upper cut survive the actual Authority-facing seam."""
	var space_before: PackedByteArray = _actual._owner.state_bytes()
	var sites_before: PackedByteArray = _actual._sites.state_bytes()
	assert_equal(_actual._world_bindings.floor_section(_actual._site, _actual._room), _actual._section, "exact lower floor identity")
	var out: PackedInt32Array = _mask()
	assert_equal(out.size(), 24, "four fine disjoint strips")
	assert_equal(_actual._mask_volume(out), 805306368, "no usable central hole")
	assert_equal(_actual._owner.state_bytes(), space_before, "no physical role publication")
	assert_equal(_actual._sites.state_bytes(), sites_before, "no paid history or progress mutation")
	assert_equal(_reader.section_calls, 1, "actual metadata reader used")
	assert_equal(_reader.mask_calls, 1, "actual mask reader used")
	assert_true(_actual._budget.covers(_actual._lease, Budget.COLD_BYTES), "caller still owns output lifetime")


func test_terrain_identity_is_the_actual_configured_source_without_new_permission() -> void:
	"""The borrowing seam introduces no second terrain owner and does not keep a retired World valid."""
	assert_true(_actual._world_bindings.terrain_owner() == _actual._terrain, "same actual Terrain")
	assert_true(_actual._terrain.is_bound_world(_actual._world, _actual._owner, _actual._sources), "real World identity")
	assert_true(_actual._terrain.is_bound_budget(_actual._budget), "same actual arena")
	_actual._world.clear()
	assert_true(_actual._world_bindings.terrain_owner() == _actual._terrain, "identity is not lifetime attestation")
	assert_true(_actual._world_bindings.binding_refusal() != &"", "actual retired World refuses")
	assert_true(WorldComposer.new().terrain_owner() == null, "unbound identity reader is null")


func test_binding_requires_exact_composer_and_actual_provider_at_quiescence() -> void:
	"""Same stores/World/Budget cannot lend a different composer's retained phase token."""
	assert_equal(_actual._world_bindings.bind_room_bindings(_reader), WorldComposer.REFUSE_BUSY, "once-only binding")
	var fresh: WorldComposer = _unbound_composer()
	assert_equal(fresh.bind_room_bindings(_reader), WorldComposer.REFUSE_BUSY, "another actual operation blocks wiring")
	_actual._world_bindings.end_cold_operation(_actual._lease)
	_actual._lease = 0
	assert_equal(fresh.bind_room_bindings(null), WorldComposer.REFUSE_BINDING, "missing provider")
	assert_equal(fresh.bind_room_bindings(Orders.Bindings.new()), WorldComposer.REFUSE_BINDING, "unqualified base")
	assert_equal(fresh.bind_room_bindings(_reader), WorldComposer.REFUSE_BINDING, "different phase composer")
	assert_true(fresh._room_region == null, "refusal precedes scratch allocation")


func test_missing_provider_or_wrong_phase_never_returns_a_prior_room_result() -> void:
	"""Wrong full generations, another real Site and bare tokens cannot use cached metadata or masks."""
	assert_equal(_actual._world_bindings.floor_section(_actual._site, _actual._room), _actual._section, "seed reusable metadata")
	var out: PackedInt32Array = _mask()
	var other: Vector2i = _actual._sites.claim_quantum(Fixture.ORIGIN + Vector3i(1024, 0, 0), _actual._room).ref
	assert_true(other != NULL_REF, "another actual Site")
	assert_equal(_actual._world_bindings.floor_section(other, _actual._room), NULL_REF, "same Room different Site")
	assert_true(_actual._world_bindings.finish_mask_into(other, _actual._room, _actual._lease, 8, out) != &"", "wrong Site refuses")
	assert_true(out.is_empty(), "old exact mask cleared")
	assert_equal(_actual._world_bindings.floor_section(_actual._site,
		Vector2i(_actual._room.x, _actual._room.y + 1)), NULL_REF, "full Room generation")
	assert_true(_actual._world_bindings.finish_mask_into(_actual._site, _actual._room, _actual._lease + 1, 8, out) != &"", "exact cold token")


func test_mask_callback_expiry_discards_output_and_preserves_foreign_replacement_lease() -> void:
	"""A successful observed mask is unusable if its real final callback ends the operation."""
	_reader.expire = true
	var out: PackedInt32Array = PackedInt32Array([9])
	assert_true(_actual._world_bindings.finish_mask_into(_actual._site, _actual._room,
		_actual._lease, 8, out) != &"", "final lease loss refuses")
	assert_equal(_reader.mask_calls, 1, "real mask filled before expiry")
	assert_true(out.is_empty(), "no escaped observation")
	_actual._world_bindings.end_cold_operation(_actual._lease)
	assert_true(_actual._budget.covers(_reader.replacement, Budget.COLD_BYTES), "stale cleanup cannot release replacement")


func test_section_callback_expiry_discards_even_a_successfully_resolved_floor() -> void:
	"""A reused Region's retained full floor handle does not outlive its phase's actual lease."""
	_reader.expire = true
	assert_equal(_actual._world_bindings.floor_section(_actual._site, _actual._room), NULL_REF, "final expired scope")
	assert_equal(_reader.section_calls, 1, "real lower section was resolved first")
	assert_true(_actual._budget.covers(_reader.replacement, Budget.COLD_BYTES), "foreign replacement preserved")


func test_nested_mask_and_composition_cannot_clear_outer_output_or_grow_a_second_survey() -> void:
	"""The guard exists before provider callbacks and protects shared cold lifetime plus result scratch."""
	_reader.reenter = true
	var out: PackedInt32Array = _mask()
	assert_equal(_reader.nested_mask, WorldComposer.REFUSE_BUSY, "same output cannot reenter")
	assert_equal(_reader.nested_section, NULL_REF, "reused metadata protected")
	assert_equal(_reader.nested_snapshot, WorldComposer.REFUSE_BUSY, "no simultaneous compositor allocation")
	assert_equal(out.size(), 24, "outer fine outline preserved")
	assert_equal(_actual._mask_volume(out), 805306368, "outer result still exact")


func test_expired_weak_provider_refuses_without_recreating_or_retaining_it() -> void:
	"""WorldBindings must not form a permanent cycle with the actual Room phase reader."""
	var observed: WeakRef = weakref(_reader)
	_reader = null
	assert_true(observed.get_ref() == null, "reader lifetime really ended")
	assert_equal(_actual._world_bindings.floor_section(_actual._site, _actual._room), NULL_REF, "no implicit replacement")
	var out: PackedInt32Array = PackedInt32Array([7])
	assert_equal(_actual._world_bindings.finish_mask_into(_actual._site, _actual._room,
		_actual._lease, 8, out), WorldComposer.REFUSE_BINDING, "expired actual provider")
	assert_true(out.is_empty(), "old mask cleared")
