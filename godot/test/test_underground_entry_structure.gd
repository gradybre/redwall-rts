extends "res://test/test_underground_first_prefix.gd"
## Actual entry Room/Site/source geometry. Inherited motion certificates remain explicitly synthetic.

const EntryStructure := preload("res://scripts/core/underground_entry_structure.gd")
const StructureScope := preload("res://scripts/core/underground_world_structure_scope.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")


class ObservedStructure extends EntryStructure:
	var late_prefix: bool = false
	var reenter: bool = false
	var nested: StringName = &""
	var history_row: int = -1
	var mutate_natural: Callable

	func _walk_claims() -> StringName:
		"""Adversarial observers run only after real natural earth and all retained geometry were examined."""
		var code: StringName = super._walk_claims()
		if code == &"" and late_prefix:
			late_prefix = false
			var placements: Placements = _entry_actual_placements()
			placements._set32(placements._live, Placements.INSTALLED, _entry_ref.x, _entry_prefix + 1)
		if code == &"" and reenter:
			reenter = false
			nested = structure_refusal(_site, _operation, _stage, _room, _cold_token)
		if code == &"" and history_row >= 0:
			_actual_sites()._ever_cut[history_row] = 1
			history_row = -1
		if code == &"" and mutate_natural.is_valid():
			var action: Callable = mutate_natural
			mutate_natural = Callable()
			action.call()
		return code


var _structure: ObservedStructure = null
var _structure_scope: StructureScope = null
var _entry_room: Vector2i = NULL_REF


func _bind_entry_and_installation() -> void:
	"""Reuse every real first-prefix owner, adding the concrete structural delegate and its original Scope."""
	super._bind_entry_and_installation()
	_structure_scope = StructureScope.new()
	assert_equal(_structure_scope.configure(_provider, _world._levels, _world._budget), &"", "original actual Scope")
	_structure = ObservedStructure.new()
	assert_equal(_structure.configure(_structure_scope, _world._owner, _world._terrain, _world._levels,
		_sites, _world._budget), &"", "actual physical structural owner")
	assert_equal(_structure.bind_entry_sources(_placements, _source, EntryStructure.ENTRY_CONTROL_BYTES), &"", "finite entry source packet")
	assert_equal(_provider.bind_phase_structure(_structure, _world._levels), &"", "same actual World dispatch")


func after_each() -> void:
	"""Weak adapter links do not retain the actual owner graph after fixture teardown."""
	_structure = null
	_structure_scope = null
	super.after_each()


func _confirm() -> Vector2i:
	"""Accept exact fine entry claims through the actual atomic Room order path, with no physical work."""
	var result: Variant = _orders.confirm_entry(_entry_plan())
	assert_true(result.ok, "actual first entry: %s" % result.error)
	_entry_room = result.ref
	return _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))


func _check(site: Vector2i, operation: int = Contract.OP_BRACE, stage: int = Contract.STAGE_ADMIT) -> StringName:
	"""Structural proof borrows the exact actual Site/Room/phase cold lease and always releases it."""
	var token: int = _provider.begin_cold_operation(_world._owner, site, operation, stage)
	assert_true(token > 0, "exact original phase lease")
	var code: StringName = _provider.structural_refusal(site, operation, stage, _entry_room)
	_provider.end_cold_operation(token)
	return code


func test_entry_proves_all_four_landing_cubes_without_a_flat_natural_roof() -> void:
	"""Post bearings are below the open pocket; no unsupported column roof or whole-cube room expansion is invented."""
	var first: Vector2i = _confirm()
	assert_true(first != NULL_REF, "actual first physical key")
	var before: PackedByteArray = _world._owner.state_bytes()
	for x: int in [-1024, 0]:
		for z: int in [-1024, -2048]:
			var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(x, -1024, z))
			assert_equal(_check(site), &"", "actual landing natural bearings")
			assert_false(_sites.installed_support(site), "query creates no paid support")
	assert_equal(_world._owner.state_bytes(), before, "no structural publication at admission")
	assert_equal(_sites.virgin_sourced_milli(), 0, "no earth is excavated")
	assert_equal(_world._construction.live_project_count(), 0, "no free construction")


func test_future_tread_cannot_borrow_the_landing_episode_or_early_prefix() -> void:
	"""T0 has distinct source footings and is not authorized until the actual L0 installation completes."""
	_confirm()
	var tread: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -3072))
	assert_equal(_check(tread), EntryStructure.REFUSE_ENTRY, "actual installed prefix0 cannot select episode1")
	assert_false(_sites.installed_support(tread), "no prefix or support advance")


func test_unpaid_start_commit_and_cut_remain_closed() -> void:
	"""Natural support is not a paid receipt, funded job, work completion, or installed structural protection."""
	var site: Vector2i = _confirm()
	assert_true(_check(site, Contract.OP_BRACE, Contract.STAGE_START) != &"", "no Project may start")
	assert_true(_check(site, Contract.OP_BRACE, Contract.STAGE_COMMIT) != &"", "no work may complete")
	assert_equal(_check(site, Contract.OP_CUT), EntryStructure.REFUSE_BRACE, "natural footing does not replace paid BRACE")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 6500, "no unpaid input disappearance")


func test_last_observer_prefix_change_refuses_and_original_tuple_can_retry() -> void:
	"""A successful geometry observer cannot publish stale permission after the actual Placement changed."""
	var site: Vector2i = _confirm()
	_structure.late_prefix = true
	assert_equal(_check(site), EntryStructure.REFUSE_ENTRY, "late actual prefix drift")
	_placements._set32(_placements._live, Placements.INSTALLED, 0, 0)
	assert_equal(_check(site), &"", "unchanged original tuple retries")
	assert_false(_sites.installed_support(site), "failed read never installs")


func test_reentry_poison_survives_successful_outer_natural_query() -> void:
	"""A nested provider observation cannot reuse scratch or leave the outer success in force."""
	var site: Vector2i = _confirm()
	_structure.reenter = true
	assert_equal(_check(site), EntryStructure.REFUSE_BUSY, "outer observer poisoned")
	assert_equal(_structure.nested, EntryStructure.REFUSE_BUSY, "nested read refused")
	assert_equal(_check(site), &"", "clean exact query may retry")


func test_placement_source_digest_change_refuses_without_rebinding() -> void:
	"""Coincident owner objects cannot hide a Placement published against different immutable geometry."""
	var site: Vector2i = _confirm()
	var previous: int = _placements._live.digests[96]
	_placements._live.digests[96] ^= 1
	assert_equal(_check(site), EntryStructure.REFUSE_ENTRY, "wrong exact frontier digest")
	_placements._live.digests[96] = previous
	assert_equal(_check(site), &"", "correct retained content retries")
	assert_equal(_structure.bind_entry_sources(_placements, _source, EntryStructure.ENTRY_CONTROL_BYTES),
		EntryStructure.REFUSE_BINDING, "production source cannot rebind")


func test_busy_placement_cannot_borrow_an_unrelated_structural_observation() -> void:
	"""Ordinary busy state never becomes permission to read frame or support from another operation."""
	var site: Vector2i = _confirm()
	_placements._busy = true
	assert_equal(_check(site), EntryStructure.REFUSE_ENTRY, "ordinary busy Placement refuses")
	_placements._busy = false
	assert_equal(_check(site), &"", "original quiescent tuple retries")


func test_phase_mode_without_the_exact_prepared_tuple_refuses_even_when_not_busy() -> void:
	"""A sealed companion is still an active phase after its copy returns; a flag alone cannot authorize CHECK."""
	var site: Vector2i = _confirm()
	_placements._phase_mode = true
	assert_false(_placements._busy, "fault fixture does not rely on busy")
	assert_equal(_check(site), EntryStructure.REFUSE_ENTRY, "active phase cannot be treated as quiescent")
	_placements._phase_mode = false
	assert_equal(_check(site), &"", "unchanged actual tuple retries")


func _footing_history_row() -> int:
	"""Fault-injection fixture: a retained key below L0 has no current cavity, like a previously backfilled site."""
	var key: int = _sites._key_at(ORIGIN + Vector3i(-1024, -2048, -1024))
	assert_true(key >= 0, "finite actual lattice history key")
	return _sites._claim_key(key, _sites._key_lower_bound(key))


func test_old_cut_history_cannot_be_relabelled_natural_by_a_filled_geometry_image() -> void:
	"""This negative history mutant has no sparse void; original Terrain alone must not authorize its footing."""
	var site: Vector2i = _confirm()
	var row: int = _footing_history_row()
	_sites._ever_cut[row] = 1
	assert_equal(_check(site), EntryStructure.REFUSE_HISTORY, "permanent ever-cut flag protects truthful bearing")
	assert_false(_sites.installed_support(site), "never paid by fault image")


func test_late_history_change_is_checked_after_last_geometry_observation() -> void:
	"""The same exact retained key becoming cut invalidates a prior natural success before any publication."""
	var site: Vector2i = _confirm()
	_structure.history_row = _footing_history_row()
	assert_equal(_check(site), EntryStructure.REFUSE_HISTORY, "late actual history drift")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 6500, "refusal spends nothing")


func _create_footing_resource() -> void:
	"""Add a real resource exclusion after the successful structural observer; no sparse fake box is involved."""
	var point: Vector3i = ORIGIN + Vector3i(-896, -1152, -256)
	@warning_ignore("integer_division") var tile: int = (point.z / 2048) * 128 + point.x / 2048
	assert_true(_world._nodes.create_at_tile(tile, _world._items.compiled_id(&"stone"), 1000, 4, 1).ok,
		"actual live resource exclusion")


func test_late_resource_exclusion_is_read_again_after_last_world_observer() -> void:
	"""A new live protected stone vein cannot hide behind the earlier original-earth or fine-room claim result."""
	var site: Vector2i = _confirm()
	_structure.mutate_natural = _create_footing_resource
	assert_true(_check(site) != &"", "late current exclusion refuses before publication")
	assert_false(_sites.installed_support(site), "no paid support installed")


func test_source_rotation_checks_int64_bounds_before_packed_narrowing() -> void:
	"""The geometry helper rotates source half-open bounds exactly; this pure test grants no rotated worker profile."""
	var bounds: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var expected: Array[PackedInt32Array] = [PackedInt32Array([-896, -1152, -256, -768, -1024, -128]),
		PackedInt32Array([128, -1152, -896, 256, -1024, -768]),
		PackedInt32Array([768, -1152, 128, 896, -1024, 256]),
		PackedInt32Array([-256, -1152, 768, -128, -1024, 896])]
	for rotation: int in 4:
		_structure._entry_frame[3] = rotation
		for axis: int in 3: _structure._entry_frame[axis] = ORIGIN[axis]
		assert_equal(_structure._entry_world_box(_source, Frontier.BEARING, 2, 3, bounds), &"", "source cardinal box")
		assert_equal(bounds, Source.world_box(expected[rotation]), "exact half-open cardinal bounds")
	_structure._entry_frame[3] = 1
	_structure._entry_frame[0] = 2147483647
	assert_equal(_structure._entry_world_box(_source, Frontier.BEARING, 2, 3, bounds), EntryStructure.REFUSE_ENTRY,
		"overflow refuses before an invalid narrowed bound can authorize geometry")


func test_asymmetric_episode_turns_match_the_existing_connector_frame_convention() -> void:
	"""A remote negative-X/Z cube turns toward positiveX for quarter1, with the opposite result for quarter3."""
	var placement: Connectors.Placement = Connectors.Placement.new()
	placement.origin = ORIGIN
	var bounds: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var quarter1: PackedInt32Array = PackedInt32Array([1024, -1024, -1024, 2048, 0, 0])
	var quarter3: PackedInt32Array = PackedInt32Array([-2048, -1024, 0, -1024, 0, 1024])
	for rotation: int in [1, 3]:
		placement.rotation = rotation
		_structure._entry_frame[3] = rotation
		for axis: int in 3: _structure._entry_frame[axis] = ORIGIN[axis]
		assert_equal(_structure._entry_world_box(_source, Frontier.EPISODE, 2, 0, bounds), &"", "exact asymmetric episode")
		assert_equal(bounds, Source.world_box(quarter1 if rotation == 1 else quarter3), "independent corner oracle")
		assert_equal(bounds, Connectors.transform_box(Source.cube(2), placement), "existing connector transform contract")
