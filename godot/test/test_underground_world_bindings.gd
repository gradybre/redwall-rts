extends "res://test/framework/test_case.gd"
## Real World/catalog/source owners at the production allocation pack.
## Retained fixture extents test composition only; they do not qualify a productive dig or route.

const Bindings := preload("res://scripts/core/underground_world_bindings.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const World := preload("res://scripts/core/world_init.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Forage := preload("res://scripts/core/forage.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const Rng := preload("res://scripts/core/rng.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const X: int = 60 * 2048
const Z: int = 50 * 2048


class LeaseAttack extends RefCounted:
	## Deliberately violate caller retention at a provider boundary to prove fail-closed cleanup.
	var arena: Budget = null
	var token: int = 0
	var reacquire: bool = false
	var replacement: int = 0

	func trigger() -> void:
		"""A newer equally funded token is still foreign to the active operation."""
		assert(arena.release(token) == &"")
		if reacquire:
			replacement = arena.acquire(Budget.COLD_BYTES)
			assert(replacement != 0 and replacement != token)


class ObservedBindings extends Bindings:
	## Count output-copy entry without substituting any geometry or admission decisions.
	var copies: int = 0

	func _copy_retained(bounds: PackedInt32Array, retained: Space.Snapshot,
			out: Space.Snapshot) -> StringName:
		"""An expired callback lease must refuse before this first output growth boundary."""
		copies += 1
		return super._copy_retained(bounds, retained, out)


class ObservedOwner extends Owner:
	## Count the real snapshot boundary without substituting any snapshot/source facts.
	var reads: int = 0
	var revision_reads: int = 0
	var refusal_reads: int = 0
	var lease_attack: LeaseAttack = null
	var expire_on_validation: bool = false

	func snapshot_into(out: Space.Snapshot) -> StringName:
		"""A refused lease must not even enter this real allocating reader."""
		reads += 1
		var code: StringName = super.snapshot_into(out)
		if lease_attack != null and not expire_on_validation:
			lease_attack.trigger()
		return code

	func snapshot_revision_refusal(expected_revision: int) -> StringName:
		"""Exercise expiry after the final actual identity/claim proof, before metadata publication."""
		var code: StringName = super.snapshot_revision_refusal(expected_revision)
		if lease_attack != null and expire_on_validation:
			lease_attack.trigger()
		return code

	func source_revision(ref: Vector2i) -> int:
		"""Count full-table source searches independently of how many natural rows were emitted."""
		revision_reads += 1
		return super.source_revision(ref)

	func source_refusal(ref: Vector2i) -> StringName:
		"""Include the actual binding's other linear lookup in the fixed search allowance."""
		refusal_reads += 1
		return super.source_refusal(ref)


class ObservedTerrain extends Terrain:
	## Adversarial hooks exercise operation-boundary guards; the survey remains the real implementation.
	var reads: int = 0
	var retire_world: bool = false
	var publish_geometry: bool = false
	var lease_attack: LeaseAttack = null
	var reentrant: WeakRef = null
	var reentry_code: StringName = &""
	var reentry_output: Space.Snapshot = null

	func natural_survey_into(bounds: PackedInt32Array, rows: int, out: Space.Volumes,
			token: int) -> StringName:
		"""Only test code can synchronously expire an actual World or attempt this nested call."""
		reads += 1
		var code: StringName = super.natural_survey_into(bounds, rows, out, token)
		if reentrant != null:
			var provider: Bindings = reentrant.get_ref() as Bindings
			reentry_code = provider.composed_snapshot_into(bounds, reentry_output, token)
		if lease_attack != null:
			lease_attack.trigger()
		if publish_geometry:
			_publish_test_geometry()
		if retire_world:
			_world.clear()
		return code


	func _publish_test_geometry() -> void:
		"""Exercise a real geometry revision change during the test-only reader hook."""
		var actual: Owner = _space.get_ref() as Owner
		var begun: Owner.Result = actual.begin_stage(actual.revision())
		var piece: Owner.Region = Owner.Region.new()
		piece.box = PackedInt32Array([X, -1400, Z, X + 1, -1399, Z + 1])
		piece.role = Space.SUPPORTED_VOID
		piece.level = 1
		piece.owner = _world_ref
		assert(begun.error == &"" and actual.stage_add(begun.token, piece).error == &"")
		assert(actual.seal(begun.token) == &"")
		actual.publish(begun.token)


var _residents: Residents = null
var _jobs: Jobs = null
var _nodes: Nodes = null
var _world: World = null
var _items: Items = null
var _inventory: Inventory = null
var _buildings: Buildings = null
var _construction: Construction = null
var _sources: Owner.CoreSources = null
var _owner: ObservedOwner = null
var _budget: Budget = null
var _terrain: ObservedTerrain = null
var _bindings: ObservedBindings = null
var _lease: int = 0
var _world_ref: Vector2i = NULL_REF


func before_each() -> void:
	"""Create actual generated land and finite sparse state; all capacity limits match the admitted pack."""
	_residents = Residents.new()
	_jobs = Jobs.new(_residents)
	_nodes = Nodes.new(_jobs.directory())
	var forage: Forage = Forage.new(_jobs.directory(), _jobs)
	var fishing: Fishing = Fishing.new(_jobs.directory(), forage, _jobs)
	_world = World.new(_jobs.directory(), _nodes, forage, fishing, Rng.new(), null, null, _jobs)
	_inventory = Inventory.new()
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual item catalog")
	assert_true(_world.generate(World.bound_request(_items).request).ok, "actual generated world")
	_world_ref = _jobs.directory().create(Directory.KIND_WORLD)
	_buildings = Buildings.new(_jobs.directory())
	_construction = Construction.new(_buildings)
	_sources = Owner.CoreSources.new(_jobs.directory(), _buildings, _construction)
	_owner = ObservedOwner.new(_sources)
	assert_equal(_owner.configure(_domain(), Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "full real pack")
	_budget = Budget.new()
	_terrain = ObservedTerrain.new()
	assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual terrain")
	_bindings = ObservedBindings.new()
	assert_equal(_bindings.configure(_world, _terrain, _owner, _sources, _budget), &"", "actual composition")
	_lease = _budget.acquire(Budget.COLD_BYTES)
	assert_true(_lease > 0, "one actual shared lease retained through all local outputs")


func after_each() -> void:
	"""Release all output lifetimes before the single arena and all actual owner references."""
	_terrain.reentry_output = null
	_terrain.reentrant = null
	_bindings = null
	if _lease != 0:
		assert_equal(_budget.release(_lease), &"", "fixture output lifetime ended")
	_lease = 0
	_terrain = null
	_owner = null
	_sources = null
	_construction = null
	_buildings = null
	_world = null
	_nodes = null
	_jobs = null
	_residents = null
	_items = null
	_inventory = null
	_budget = null


func _domain(checks: int = Space.MAX_CHECKS, regions: int = Budget.PHASE_VOLUME_CAPACITY) -> Space.Domain:
	"""The finite base pack is explicitly authored, with test-only smaller operation ceilings when requested."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, regions, checks), &"", "finite actual datum/domain")
	return domain


func _box(low_y: int = -1536, high_y: int = 512) -> PackedInt32Array:
	"""One2m land tile; these literal integer extents are independent of the composition algorithm."""
	return PackedInt32Array([X, low_y, Z, X + 2048, high_y, Z + 2048])


func _publish(boxes: Array[PackedInt32Array], roles: PackedInt32Array, levels: PackedInt32Array) -> void:
	"""Publish explicitly synthetic extents through the actual sparse transaction, never a fake snapshot."""
	var begun: Owner.Result = _owner.begin_stage(_owner.revision())
	assert_equal(begun.error, &"", "actual full-pack stage")
	for index: int in boxes.size():
		var piece: Owner.Region = Owner.Region.new()
		piece.box = boxes[index]
		piece.role = roles[index]
		piece.level = levels[index]
		piece.owner = _world_ref
		assert_equal(_owner.stage_add(begun.token, piece).error, &"", "fixture extent added")
	assert_equal(_owner.seal(begun.token), &"", "full-pack real validation")
	_owner.publish(begun.token)


func _query(bounds: PackedInt32Array) -> Space.Snapshot:
	"""Retain the actual lease through the returned observation's complete test-local lifetime."""
	var out: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_bindings.composed_snapshot_into(bounds, out, _lease), &"", "complete actual observation")
	return out


func _volume(box: PackedInt32Array) -> int:
	"""Integer physical volume supplies an independent conservation oracle for arbitrary fragments."""
	return int(box[3] - box[0]) * int(box[4] - box[1]) * int(box[5] - box[2])


func _role_volume(out: Space.Volumes, role: int) -> int:
	"""Compare volume, not implementation-specific fragment count or subtraction order."""
	var total: int = 0
	for row: int in out.role.size():
		if out.role[row] == role:
			total += _volume(out.box_at(row))
	return total


func _assert_empty(out: Space.Snapshot) -> void:
	"""A refusal cannot leave either identity metadata or a partial volume column prefix."""
	assert_equal(out.world_ref, NULL_REF, "no retained World")
	assert_equal(out.revision, 0, "no usable geometry revision")
	assert_equal(out.live_refs.size() + out.live_revisions.size(), 0, "no stale sources")
	assert_equal(out.volumes.lo_x.size() + out.volumes.lo_y.size() + out.volumes.lo_z.size()
		+ out.volumes.hi_x.size() + out.volumes.hi_y.size() + out.volumes.hi_z.size()
		+ out.volumes.role.size() + out.volumes.level.size() + out.volumes.owner_slot.size()
		+ out.volumes.owner_generation.size() + out.volumes.owner_revision.size(), 0, "all eleven columns empty")


func test_actual_owner_budget_and_one_time_binding() -> void:
	"""Numerically equal tokens and references from unrelated objects never establish a composed World."""
	var fresh: Bindings = Bindings.new()
	assert_equal(fresh.binding_refusal(), Bindings.REFUSE_BINDING, "unbound refuses")
	assert_equal(fresh.composition_peak_bytes(), 0, "unbound has no admitted allocation")
	assert_equal(fresh.configure(_world, _terrain, _owner, _sources, Budget.new()), Bindings.REFUSE_BINDING, "foreign arena")
	var foreign: Owner.CoreSources = Owner.CoreSources.new(_jobs.directory(), _buildings, _construction)
	assert_equal(fresh.configure(_world, _terrain, _owner, foreign, _budget), Bindings.REFUSE_BINDING, "foreign source owner")
	assert_equal(_bindings.configure(_world, _terrain, _owner, _sources, _budget), &"WORLD_COMPOSITION_ALREADY_BOUND", "immutable wiring")
	assert_true(_bindings.sources() == _sources, "actual reader returned")
	assert_true(_bindings.is_bound_budget(_budget), "actual arena returned")
	assert_false(_bindings.is_bound_budget(null), "null arena refuses")
	assert_equal(_bindings.composition_peak_bytes(), 975488, "independently summed conservative pack")
	assert_true(_bindings.composition_peak_bytes() <= Budget.COLD_BYTES, "existing shared ceiling retained")
	assert_equal(_bindings.allocation_refusal(_owner, 256, 17724), &"", "exact existing proof cache")
	assert_equal(_bindings.allocation_refusal(_owner, 256, 17723), Bindings.REFUSE_CAPACITY, "undercharged proof refuses")
	assert_equal(_bindings.allocation_refusal(_owner, 257, 17793), Bindings.REFUSE_CAPACITY, "overfull proof refuses")
	assert_equal(_bindings.qualification_revision(), 0, "observation is not production qualification")
	assert_true(_bindings.room_refusal(_world_ref) != &"", "observation cannot invent a productive Room")


func test_original_land_and_exterior_remain_exact_and_read_only() -> void:
	"""Surface Y is actual512u; a query does not alter source revisions or the sparse owner."""
	var before: PackedByteArray = _owner.state_bytes()
	var out: Space.Snapshot = _query(_box(-1024, 2048))
	assert_equal(out.world_ref, _world_ref, "actual World generation")
	assert_equal(out.revision, _owner.revision(), "actual geometry revision")
	assert_equal(out.volumes.role, PackedInt32Array([Space.DRY_SOLID, Space.FLOOR_DATUM, Space.SUPPORTED_VOID]), "actual dry/floor/exterior")
	assert_equal(out.volumes.hi_y[0], 512, "real land height")
	assert_equal(out.volumes.lo_y[1], 512, "real floor metadata")
	assert_equal(out.volumes.lo_y[2], 512, "real open exterior")
	assert_equal(_owner.state_bytes(), before, "no preview publication or revision increment")


func test_interior_paid_void_preserves_every_unexcavated_sliver() -> void:
	"""Off-grid interior void leaves six-sided soil; exact union conservation catches rectangular fill shortcuts."""
	var hole: PackedInt32Array = PackedInt32Array([X + 137, -1207, Z + 19, X + 1851, 103, Z + 1973])
	_publish([hole], PackedInt32Array([Space.SUPPORTED_VOID]), PackedInt32Array([7]))
	var before: PackedByteArray = _owner.state_bytes()
	var out: Space.Snapshot = _query(_box())
	assert_equal(_role_volume(out.volumes, Space.SUPPORTED_VOID), _volume(hole), "retained void exactly once")
	assert_equal(_role_volume(out.volumes, Space.DRY_SOLID), _volume(_box()) - _volume(hole), "all surrounding natural matter retained")
	assert_equal(out.volumes.level[0], 7, "actual layer copied, never inferred from Y")
	assert_equal(out.volumes.owner_revision[0], _owner.source_revision(_world_ref), "actual retained revision")
	for row: int in out.volumes.role.size():
		if out.volumes.role[row] == Space.DRY_SOLID:
			assert_false(Space.overlaps(out.volumes.box_at(row), hole), "no refilled paid hole")
			assert_true(Space.contains_box(_box(), out.volumes.box_at(row)), "no extension past query boundary")
	assert_equal(_owner.state_bytes(), before, "composition never edits paid geometry")


func test_different_vertical_levels_do_not_erase_intervening_earth() -> void:
	"""Two retained rooms sharing XZ have separate levels and natural ground between their ceilings/floors."""
	var lower: PackedInt32Array = _box(-6200, -5100)
	var upper: PackedInt32Array = _box(-2300, -1000)
	_publish([lower, upper], PackedInt32Array([Space.SUPPORTED_VOID, Space.UNFINISHED]), PackedInt32Array([9, 4]))
	var out: Space.Snapshot = _query(_box(-7000, 512))
	assert_equal(out.volumes.level[0], 9, "lower authored level")
	assert_equal(out.volumes.level[1], 4, "upper authored level")
	assert_equal(_role_volume(out.volumes, Space.DRY_SOLID), _volume(_box(-7000, 512)) - _volume(lower) - _volume(upper), "interlevel soil preserved")
	assert_equal(_role_volume(out.volumes, Space.UNFINISHED), _volume(upper), "unfinished does not become safe void")


func test_blocker_and_support_are_not_evidence_that_soil_was_excavated() -> void:
	"""Protected occupancy and support metadata remain blockers but cannot erase unworked ground."""
	var obstacle: PackedInt32Array = PackedInt32Array([X, -1000, Z, X + 200, -500, Z + 200])
	var support: PackedInt32Array = PackedInt32Array([X + 300, -1000, Z, X + 500, -500, Z + 200])
	_publish([obstacle, support], PackedInt32Array([Space.OBSTACLE, Space.SUPPORT]), PackedInt32Array([2, 2]))
	var out: Space.Snapshot = _query(_box())
	assert_equal(_role_volume(out.volumes, Space.DRY_SOLID), _volume(_box()), "claims cannot create free excavation")
	assert_equal(_role_volume(out.volumes, Space.OBSTACLE), _volume(obstacle), "blocker retained")
	assert_equal(_role_volume(out.volumes, Space.SUPPORT), _volume(support), "support retained")


func test_clipping_and_face_contact_do_not_overwrite_neighbors() -> void:
	"""Half-open bounds clip actual retained state and touching boxes have no overlap volume."""
	var crossing: PackedInt32Array = PackedInt32Array([X - 10, -2000, Z + 100, X + 1, -1000, Z + 101])
	var touching: PackedInt32Array = PackedInt32Array([X + 2048, -1536, Z, X + 2200, 512, Z + 2048])
	_publish([crossing, touching], PackedInt32Array([Space.SUPPORTED_VOID, Space.SUPPORTED_VOID]), PackedInt32Array([1, 1]))
	var out: Space.Snapshot = _query(_box())
	assert_equal(_role_volume(out.volumes, Space.SUPPORTED_VOID), 536, "one-unit-wide exact intersection")
	assert_equal(_role_volume(out.volumes, Space.DRY_SOLID), _volume(_box()) - 536, "touching neighbor removes nothing")
	for row: int in out.volumes.role.size():
		assert_true(Space.contains_box(_box(), out.volumes.box_at(row)), "every returned role clipped")


func test_unfinished_water_and_shell_cannot_become_natural_dry_or_free_space() -> void:
	"""Physical history keeps its role, even inside a region originally authored as dry ground."""
	var roles: PackedInt32Array = PackedInt32Array([Space.UNFINISHED, Space.WATER, Space.OPENABLE_SHELL, Space.DRY_SOLID])
	var boxes: Array[PackedInt32Array] = []
	for index: int in roles.size():
		boxes.append(PackedInt32Array([X + index * 400, -900, Z, X + index * 400 + 200, -600, Z + 200]))
	_publish(boxes, roles, PackedInt32Array([3, 3, 3, 3]))
	var out: Space.Snapshot = _query(_box())
	for index: int in roles.size():
		assert_equal(out.volumes.role[index], roles[index], "exact retained role")
		assert_equal(out.volumes.box_at(index), boxes[index], "exact retained box")
	assert_equal(_role_volume(out.volumes, Space.DRY_SOLID), _volume(_box()) - 3 * _volume(boxes[0]), "retained dry counted once")
	assert_equal(_role_volume(out.volumes, Space.SUPPORTED_VOID), 0, "no invented complete room")


func test_exact_retained_floor_metadata_replaces_only_duplicate_natural_floor() -> void:
	"""One real floor section retains its source and actual floor label without removing adjacent soil."""
	_publish([_box(512, 513)], PackedInt32Array([Space.FLOOR_DATUM]), PackedInt32Array([11]))
	var out: Space.Snapshot = _query(_box(0, 1024))
	assert_equal(_role_volume(out.volumes, Space.FLOOR_DATUM), 2048 * 2048, "floor extent exactly once")
	assert_equal(out.volumes.level[0], 11, "actual floor layer retained")
	assert_equal(_role_volume(out.volumes, Space.DRY_SOLID), 512 * 2048 * 2048, "underlying ground unchanged")
	assert_equal(_role_volume(out.volumes, Space.SUPPORTED_VOID), 512 * 2048 * 2048, "exterior remains separately observable")


func test_lease_and_bounds_refuse_before_real_snapshot_allocation() -> void:
	"""An insufficient or stale token cannot allocate a partial snapshot before returning refusal."""
	var out: Space.Snapshot = _query(_box())
	var before: int = _owner.reads
	assert_equal(_bindings.composed_snapshot_into(_box(), out, _lease + 1), Bindings.REFUSE_BUDGET, "foreign token")
	_assert_empty(out)
	assert_equal(_owner.reads, before, "no snapshot entered")
	assert_equal(_budget.release(_lease), &"", "release original arena")
	_lease = _budget.acquire(Bindings.COMPOSITION_BYTES - 1)
	assert_equal(_bindings.composed_snapshot_into(_box(), out, _lease), Bindings.REFUSE_BUDGET, "one byte undercharged")
	assert_equal(_owner.reads, before, "undercharge rejected before reader")
	assert_equal(_bindings.composed_snapshot_into(PackedInt32Array([0, 0, 0, 0, 1, 1]), out, _lease), Bindings.REFUSE_BOUNDS, "zero width")
	assert_equal(_bindings.composed_snapshot_into(_box(-40000, -39000), out, _lease), Bindings.REFUSE_BOUNDS, "outside finite depth")
	assert_equal(_bindings.composed_snapshot_into(_box(), null, _lease), &"WORLD_COMPOSITION_OUTPUT", "null caller output")
	_assert_empty(out)


func test_natural_capacity_exhaustion_clears_prior_output_and_keeps_owner_unchanged() -> void:
	"""Broad queries fail as a bounded operation rather than silently omitting terrain tiles."""
	var out: Space.Snapshot = _query(_box())
	var before: PackedByteArray = _owner.state_bytes()
	var broad: PackedInt32Array = PackedInt32Array([0, -31000, 0, 17 * 2048, -30000, 31 * 2048])
	assert_equal(_bindings.composed_snapshot_into(broad, out, _lease), Terrain.REFUSE_CAPACITY, "527 natural tiles exceed512")
	_assert_empty(out)
	assert_equal(_owner.state_bytes(), before, "refused observation cannot publish any prefix")


func test_actual_world_change_after_observation_refuses_the_whole_output() -> void:
	"""Revision/lifetime revalidation cannot accept a completed survey from an expired actual World."""
	var out: Space.Snapshot = _query(_box())
	_terrain.retire_world = true
	assert_equal(_bindings.composed_snapshot_into(_box(), out, _lease), Terrain.REFUSE_BINDING, "actual source expires during callback")
	_assert_empty(out)


func test_reentrant_observation_refuses_without_corrupting_active_caller() -> void:
	"""A nested call cannot erase the output owned by the still-active outer composition."""
	var out: Space.Snapshot = Space.Snapshot.new()
	_terrain.reentrant = weakref(_bindings)
	_terrain.reentry_output = out
	assert_equal(_bindings.composed_snapshot_into(_box(), out, _lease), &"", "outer remains valid")
	assert_equal(_terrain.reentry_code, Bindings.REFUSE_BUSY, "nested call refused")
	assert_equal(_role_volume(out.volumes, Space.DRY_SOLID), _volume(_box()), "complete original observation")
	_terrain.reentry_output = null
	_terrain.reentrant = null


func test_dead_actual_source_owner_cannot_be_replaced_by_numeric_identity() -> void:
	"""Weak wiring prevents observations from extending or reviving the retired spatial World."""
	var out: Space.Snapshot = _query(_box())
	_owner = null
	assert_equal(_bindings.composed_snapshot_into(_box(), out, _lease), Bindings.REFUSE_BINDING, "expired owner")
	_assert_empty(out)


func test_full_source_scan_cost_is_admitted_before_first_snapshot() -> void:
	"""A finite domain that cannot afford both real scans refuses before allocating even sparse output."""
	_bindings = null
	_terrain = null
	_owner = ObservedOwner.new(_sources)
	assert_equal(_owner.configure(_domain(45071), Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "smaller explicit comparison budget")
	_terrain = ObservedTerrain.new()
	assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "same finite terrain")
	_bindings = ObservedBindings.new()
	assert_equal(_bindings.configure(_world, _terrain, _owner, _sources, _budget), &"", "same bounded allocations")
	var out: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_bindings.composed_snapshot_into(_box(), out, _lease), Bindings.REFUSE_CAPACITY, "one scan check short")
	assert_equal(_owner.reads, 0, "no copying reader entered")
	assert_equal(_terrain.reads, 0, "no base survey entered")
	_assert_empty(out)


func test_geometry_publication_during_observation_invalidates_the_whole_image() -> void:
	"""Fresh source facts alone cannot validate an image whose actual sparse revision changed."""
	var out: Space.Snapshot = _query(_box())
	var before: int = _owner.revision()
	_terrain.publish_geometry = true
	assert_equal(_bindings.composed_snapshot_into(_box(), out, _lease), &"SPACE_REVISION_STALE", "actual geometry changed during read")
	assert_true(_owner.revision() > before, "adversary published actual geometry")
	_assert_empty(out)
	_terrain.publish_geometry = false
	out = _query(_box())
	assert_equal(_role_volume(out.volumes, Space.SUPPORTED_VOID), 1, "fresh retry observes the one-unit paid-history fixture")


func test_malformed_output_refuses_without_allocating_replacement_storage() -> void:
	"""A caller-cleared nested table cannot crash native release or obtain allocation before its lease."""
	var out: Space.Snapshot = Space.Snapshot.new()
	out.world_ref = _world_ref
	out.revision = _owner.revision()
	out.live_refs = PackedInt32Array([_world_ref.x, _world_ref.y])
	out.live_revisions = PackedInt64Array([1])
	out.volumes = null
	assert_equal(_bindings.composed_snapshot_into(_box(), out, 0), &"WORLD_COMPOSITION_OUTPUT", "malformed nested output")
	assert_null(out.volumes, "no replacement table allocated before lease")
	assert_equal(out.world_ref, NULL_REF, "stale metadata cleared")
	assert_equal(out.live_refs.size() + out.live_revisions.size(), 0, "old source identity cleared")
	assert_equal(_owner.reads + _terrain.reads, 0, "no source copying entered")


func test_actual_domain_output_capacity_refuses_instead_of_truncating_a_surface() -> void:
	"""The provider honors a smaller valid Domain's output bound in addition to its own finite maximum."""
	_bindings = null
	_terrain = null
	_owner = ObservedOwner.new(_sources)
	assert_equal(_owner.configure(_domain(Space.MAX_CHECKS, 1), 1, 1), &"", "one-region sparse fixture")
	_terrain = ObservedTerrain.new()
	assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "same actual terrain")
	_bindings = ObservedBindings.new()
	assert_equal(_bindings.configure(_world, _terrain, _owner, _sources, _budget), &"", "bounded composition")
	var out: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_bindings.composed_snapshot_into(_box(-1, 514), out, _lease), Bindings.REFUSE_CAPACITY, "three surface roles cannot fit one row")
	_assert_empty(out)


func _expire_query_lease(boundary: int, reacquire: bool) -> void:
	"""Snapshot, terrain and final-validation hooks all expire the exact shared arena token."""
	var attack: LeaseAttack = LeaseAttack.new()
	attack.arena = _budget
	attack.token = _lease
	attack.reacquire = reacquire
	if boundary == 1:
		_terrain.lease_attack = attack
	else:
		_owner.lease_attack = attack
		_owner.expire_on_validation = boundary == 2
	var out: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_bindings.composed_snapshot_into(_box(), out, _lease), Bindings.REFUSE_BUDGET, "expired original lease refuses")
	_lease = attack.replacement
	assert_equal(_bindings.copies, 1 if boundary == 2 else 0, "no output-copy entry after expiry")
	_assert_empty(out)
	_terrain.lease_attack = null
	_owner.lease_attack = null
	if _lease == 0:
		_lease = _budget.acquire(Budget.COLD_BYTES)
	assert_true(_lease > 0, "fixture recovers a valid separate operation")


func test_expired_or_reacquired_lease_refuses_at_every_provider_boundary() -> void:
	"""No returned source proof can outlive the actual cold reservation which funded its image."""
	for boundary: int in 3:
		for reacquire: bool in [false, true]:
			_bindings.copies = 0
			_expire_query_lease(boundary, reacquire)


func _restore_world_source_in_last_row() -> void:
	"""Build a valid same-schema wire with its sole World source at the last actual source row."""
	var bytes: PackedByteArray = _owner.state_bytes()
	var offset: int = 18 * 8 + 68 * Budget.REGION_CAPACITY
	for width: int in [1, 1, 4, 4, 8, 4, 4, 4, 4, 4, 4]:
		for byte: int in width:
			var last: int = offset + (Budget.SOURCE_CAPACITY - 1) * width + byte
			var first: int = bytes[offset + byte]
			bytes[offset + byte] = bytes[last]
			bytes[last] = first
		offset += width * Budget.SOURCE_CAPACITY
	assert_equal(offset, bytes.size(), "independent fixed wire layout covers every source column")
	assert_equal(_owner.restore_state_bytes(bytes), &"", "real loader accepts equivalent reordered source rows")


func test_restored_world_source_lookup_is_fixed_per_survey_not_per_tile() -> void:
	"""512 natural tiles must not multiply2048-row searches merely because save order changed."""
	_restore_world_source_in_last_row()
	_owner.revision_reads = 0
	_owner.refusal_reads = 0
	var bounds: PackedInt32Array = PackedInt32Array([0, -31000, 0, 16 * 2048, -30000, 32 * 2048])
	var out: Space.Snapshot = _query(bounds)
	assert_equal(out.volumes.role.size(), 512, "entire bounded survey returned")
	assert_true(_owner.revision_reads + _owner.refusal_reads <= 10, "all owner lookups fit fixed charged allowance")
	assert_equal(Terrain.natural_survey_checks(bounds), 8192, "both512-tile walks explicitly charged")
	assert_equal(Terrain.natural_survey_checks(PackedInt32Array()), 0, "malformed bounds grant no probe budget")
	assert_equal(Terrain.natural_survey_checks(PackedInt32Array([-1, -1, 0, 2, 2, 2])), 0, "outside-map bounds grant no probe budget")
