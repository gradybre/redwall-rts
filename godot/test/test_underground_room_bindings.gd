extends "res://test/framework/test_case.gd"
## Actual identity/accounting/geometry owners. Only unstarted fixture Room/Site admission is synthetic.
## No test grants productive profiles, supports, contacts, physical completion or usable room service.

const Masks := preload("res://scripts/core/underground_room_bindings.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
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
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Work := preload("res://scripts/core/work.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const X: int = 60 * 2048
const Z: int = 50 * 2048
const FLOOR_Y: int = -4608
const ORIGIN: Vector3i = Vector3i(X, -1536, Z)


class SyntheticRooms extends Buildings.SpatialAuthority:
	## Registration only. These tests cannot install furniture or invent a completed room.
	var actual: WeakRef = null
	var registering: bool = false

	func buildings_owner() -> RefCounted:
		"""Borrow the actual Buildings namespace without a cycle."""
		return actual.get_ref()

	func mutation_refusal(action: int, subject: Vector2i, related: Vector2i,
			value: int, rotation: int) -> StringName:
		"""Only the explicit test registration bracket creates a real Kitchen identity."""
		return &"" if registering and action == Buildings.SPATIAL_ROOM_CREATE and subject == NULL_REF \
			and related == NULL_REF and value == Buildings.ROOM_TYPE_KITCHEN and rotation == 0 \
			else Buildings.REFUSE_SPATIAL_COMMAND


class SyntheticSpatial extends Contract.SpatialAuthority:
	## Allows only registration and release of unstarted real Sites, never simulated paid work.
	var domain: Space.Domain = null
	var buildings: Buildings = null
	var nested: WeakRef = null
	var nested_site: Vector2i = NULL_REF
	var nested_room: Vector2i = NULL_REF
	var nested_token: int = 0
	var nested_output: PackedInt32Array = PackedInt32Array()
	var nested_code: StringName = &""

	func domain_into(out: Contract.Domain) -> bool:
		"""Read the authored test domain and optionally attempt synchronous reentry at this first callback."""
		out.world_ref = domain._world
		out.datum_u = domain._datum
		out.minimum_quantum = domain._min_quantum
		out.size_quanta = domain._size_quanta
		if nested != null:
			var target: Masks = nested.get_ref() as Masks
			nested = null
			nested_code = target.finish_mask_into(nested_site, nested_room, nested_token, 8, nested_output)
		return true

	func room_refusal(room: Vector2i) -> StringName:
		"""Even synthetic admission requires the full actual Room generation."""
		return &"" if buildings.is_live_room(room) else &"SYNTHETIC_ROOM_STALE"

	func retirement_refusal(room: Vector2i) -> StringName:
		"""Release only this unstarted fixture claim; no evacuation permission is certified."""
		return room_refusal(room)

	func operation_refusal(_origin: Vector3i, _operation: int, _stage: int, room: Vector2i) -> StringName:
		"""A scope-change regression may allocate an unfunded real project, never complete it."""
		return room_refusal(room)


class ObservedOwner extends Owner:
	## All reads call their real implementation; hooks only expire the admitted lease afterward.
	var surveys: int = 0
	var region_reads: int = 0
	var boundary: int = 0
	var remaining_events: int = 1
	var arena: Budget = null
	var token: int = 0
	var reacquire: bool = false
	var replacement: int = 0

	func domain_copy() -> Space.Domain:
		"""Expiry after the bounded descriptor must prevent the first handle image."""
		var result: Space.Domain = super.domain_copy()
		_event(1)
		return result

	func overlapping_regions_into(box: PackedInt32Array, out: PackedInt32Array) -> StringName:
		"""Observe actual query allocation and optionally expire its exact lease."""
		surveys += 1
		var code: StringName = super.overlapping_regions_into(box, out)
		_event(2)
		return code

	func region_into_reused(handle: Vector2i, out: Owner.Region) -> StringName:
		"""A count-pass expiry must not reach output resize or the fill pass."""
		region_reads += 1
		var code: StringName = super.region_into_reused(handle, out)
		_event(3)
		return code

	func snapshot_revision_refusal(expected_revision: int) -> StringName:
		"""Exercise a final proof callback without replacing actual source or claim validation."""
		var code: StringName = super.snapshot_revision_refusal(expected_revision)
		_event(4)
		return code

	func _event(selected: int) -> void:
		"""Spend the original real token once; a replacement never grants the caller its old lifetime."""
		if selected != boundary:
			return
		remaining_events -= 1
		if remaining_events != 0:
			return
		boundary = 0
		var code: StringName = arena.release(token)
		assert(code == &"", "Test hook releases exactly the admitted token")
		if reacquire:
			replacement = arena.acquire(Budget.COLD_BYTES)
			assert(replacement > 0 and replacement != token, "Replacement identity is distinct")


class ObservedMasks extends Masks:
	## An expired count pass must not enter the actual allocating output fill path.
	var fills: int = 0

	func _fill_mask(handles: PackedInt32Array, room: Vector2i, section: Vector2i,
			level: int, out: PackedInt32Array) -> StringName:
		"""Keep actual exact claim logic, merely counting whether output publication began."""
		fills += 1
		return super._fill_mask(handles, room, section, level, out)


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
var _terrain: Terrain = null
var _world_bindings: WorldBindings = null
var _masks: ObservedMasks = null
var _spatial: SyntheticSpatial = null
var _rooms: SyntheticRooms = null
var _sites: Sites = null
var _world_ref: Vector2i = NULL_REF
var _room: Vector2i = NULL_REF
var _site: Vector2i = NULL_REF
var _section: Vector2i = NULL_REF
var _lease: int = 0


func before_each() -> void:
	"""Compose actual stores and the full admitted region/source capacities before each independent test."""
	_residents = Residents.new()
	_jobs = Jobs.new(_residents)
	_nodes = Nodes.new(_jobs.directory())
	var forage: Forage = Forage.new(_jobs.directory(), _jobs)
	var fishing: Fishing = Fishing.new(_jobs.directory(), forage, _jobs)
	_world = World.new(_jobs.directory(), _nodes, forage, fishing, Rng.new(), null, null, _jobs)
	_inventory = Inventory.new()
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual adopted catalog")
	assert_true(_world.generate(World.bound_request(_items).request).ok, "actual World")
	_world_ref = _jobs.directory().create(Directory.KIND_WORLD)
	_buildings = Buildings.new(_jobs.directory())
	_construction = Construction.new(_buildings)
	_sources = Owner.CoreSources.new(_jobs.directory(), _buildings, _construction)
	_budget = Budget.new()
	_bind_space(Space.MAX_CHECKS)
	_rooms = SyntheticRooms.new()
	_rooms.actual = weakref(_buildings)
	assert_true(_buildings.bind_spatial_authority(_rooms).ok, "actual Buildings authority")
	_room = _create_room()
	_bind_sites()
	_claims_fixture()
	_masks = ObservedMasks.new()
	assert_equal(_masks.configure(_world_bindings, _sites, _budget), &"", "actual mask wiring")
	_open_scope()


func after_each() -> void:
	"""All returned arrays leave test scope before the exact lease and owner graph are released."""
	_owner.boundary = 0
	_spatial.nested_output.clear()
	_world_bindings.end_cold_operation(_lease)
	if _owner.replacement > 0:
		assert_equal(_budget.release(_owner.replacement), &"", "test-only replacement lease")
	_masks = null
	_sites = null
	_spatial = null
	_rooms = null
	_world_bindings = null
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
	_lease = 0


func _domain(checks: int = Space.MAX_CHECKS) -> Space.Domain:
	"""Keep an explicit1m paid lattice distinct from the256u fine claimed Room outline."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 8192, checks), &"", "same finite immutable World")
	return domain


func _bind_space(checks: int) -> void:
	"""Recreate a separate exact geometry namespace only before its Room/Sites rows are referenced."""
	_owner = ObservedOwner.new(_sources)
	assert_equal(_owner.configure(_domain(checks), Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "actual finite owner")
	_terrain = Terrain.new()
	assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "real original terrain")
	_world_bindings = WorldBindings.new()
	assert_equal(_world_bindings.configure(_world, _terrain, _owner, _sources, _budget), &"", "real composer")


func _create_room() -> Vector2i:
	"""Only allocation is synthetic permission; the identity and its source facts are actual owners."""
	_rooms.registering = true
	var made: Buildings.OpResult = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_KITCHEN)
	_rooms.registering = false
	assert_true(made.ok, "actual permanent Kitchen")
	var token: int = _owner.begin_stage(_owner.revision()).token
	assert_equal(_owner.stage_source(token, made.ref), &"", "actual Room source")
	_publish(token)
	return made.ref


func _bind_sites() -> void:
	"""Real Construction/Work/Gear/Inventory own an unstarted Site; no paid phase is mocked."""
	var work: Work = Work.new(_jobs)
	var gear: Gear = Gear.new(8)
	assert_true(gear.bind_equipment(_inventory, _jobs.directory(), _residents).ok, "actual equipped namespace")
	assert_true(work.bind_gear(gear).ok, "actual Work")
	_spatial = SyntheticSpatial.new()
	_spatial.domain = _domain()
	_spatial.buildings = _buildings
	_sites = Sites.new(_construction, _inventory, Reservations.new(), _items, _jobs, work, _spatial, 32, 8)
	assert_equal(_sites.initialization_refusal(), &"", "real physical history owner")
	var claimed: Construction.OpResult = _sites.claim_quantum(ORIGIN, _room)
	assert_true(claimed.ok, "actual paid quantum identity, still unstarted")
	_site = claimed.ref


func _claims_fixture() -> void:
	"""Four disjoint exact strips surround a fine hole; their metadata envelope encloses the whole cube."""
	var token: int = _owner.begin_stage(_owner.revision()).token
	_section = _put(token, PackedInt32Array([X, FLOOR_Y, Z, X + 1024, FLOOR_Y + 1, Z + 1024]), Space.FLOOR_DATUM)
	_put(token, PackedInt32Array([X, FLOOR_Y, Z, X + 1024, 512, Z + 256]), Space.OBSTACLE, true)
	_put(token, PackedInt32Array([X, FLOOR_Y, Z + 768, X + 1024, 512, Z + 1024]), Space.OBSTACLE, true)
	_put(token, PackedInt32Array([X, FLOOR_Y, Z + 256, X + 256, 512, Z + 768]), Space.OBSTACLE, true)
	_put(token, PackedInt32Array([X + 768, FLOOR_Y, Z + 256, X + 1024, 512, Z + 768]), Space.OBSTACLE, true)
	_publish(token)


func _put(token: int, box: PackedInt32Array, role: int, claim: bool = false,
		room: Vector2i = NULL_REF, section: Vector2i = NULL_REF) -> Vector2i:
	"""Author exact synthetic bounds through real sparse validation and generation allocation."""
	var region: Owner.Region = Owner.Region.new()
	region.box = box
	region.role = role
	region.level = 1
	region.owner = _room if room == NULL_REF else room
	region.section = _section if section == NULL_REF and role != Space.FLOOR_DATUM else section
	if claim:
		region.claim_kind = Owner.CLAIM_ROOM
		region.claim_ref = region.owner
	var result: Owner.Result = _owner.stage_add(token, region)
	assert_equal(result.error, &"", "real staged region")
	return result.handle


func _publish(token: int) -> void:
	"""Every fixture region/source passes real finite staging validation."""
	assert_equal(_owner.seal(token), &"", "sealed actual geometry")
	_owner.publish(token)


func _open_scope() -> void:
	"""The provider never accepts a bare caller-acquired token in place of actual phase scope."""
	_lease = _world_bindings.begin_cold_operation(_owner, _site, Contract.OP_BRACE, Contract.STAGE_ADMIT)
	assert_true(_lease > 0, "actual full World-owned phase lease")


func _restart_scope() -> void:
	"""Finish all test-local output before observing a changed actual spatial revision."""
	_world_bindings.end_cold_operation(_lease)
	_open_scope()


func _mask(limit: int = 8) -> PackedInt32Array:
	"""Retain returned scratch only inside the currently admitted test call stack."""
	var result: PackedInt32Array = PackedInt32Array()
	assert_equal(_masks.finish_mask_into(_site, _room, _lease, limit, result), &"", "actual exact fine mask")
	return result


func _section_scratch() -> Owner.Region:
	"""Sentinel fields prove all-or-nothing metadata output on every refused query."""
	var result: Owner.Region = Owner.Region.new()
	result.box = PackedInt32Array([71, 72, 73, 74, 75, 76])
	result.owner = _world_ref
	result.section = Vector2i(77, 78)
	result.role = Space.WATER
	return result


func _mask_volume(mask: PackedInt32Array) -> int:
	"""Independent integer volume oracle distinguishes the exact outline from its enclosing cube."""
	var volume: int = 0
	for at: int in range(0, mask.size(), 6):
		volume += int(mask[at + 3] - mask[at]) * int(mask[at + 4] - mask[at + 1]) * int(mask[at + 5] - mask[at + 2])
	return volume


func test_fine_hole_and_upper_cube_use_actual_section_without_changing_any_owner() -> void:
	"""Paid history remains untouched; exact fine strips, not the floor envelope, supply usable candidates."""
	var directory_before: PackedByteArray = _jobs.directory().state_bytes()
	var geometry_before: PackedByteArray = _owner.state_bytes()
	var sites_before: PackedByteArray = _sites.state_bytes()
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	var out: Owner.Region = _section_scratch()
	assert_equal(_masks.phase_section_into(_site, _room, _lease, out), &"", "exact owning floor")
	assert_equal(out.section, _section, "full generation")
	assert_equal(out.box[1], FLOOR_Y, "no floor inferred from upper cut height")
	var mask: PackedInt32Array = _mask()
	assert_equal(mask.size(), 24, "four exact strips")
	assert_equal(_mask_volume(mask), 1024 * 1024 * 1024 - 512 * 1024 * 512, "central hole remains unusable")
	for at: int in range(0, mask.size(), 6):
		assert_equal(mask[at + 1], ORIGIN.y, "each claim clipped at this cube base")
		assert_equal(mask[at + 4], ORIGIN.y + 1024, "each claim clipped at this cube roof")
	assert_equal(_jobs.directory().state_bytes(), directory_before, "no identity allocation")
	assert_equal(_owner.state_bytes(), geometry_before, "no geometry or revision writes")
	assert_equal(_sites.state_bytes(), sites_before, "no progress, yield or paid history writes")
	assert_equal(_inventory.state_bytes(), inventory_before, "no receipt or goods writes")
	assert_true(_budget.covers(_lease, Budget.COLD_BYTES), "caller retains the output lifetime")


func test_actual_binding_is_once_only_and_unqualified_gates_still_refuse() -> void:
	"""Actual metadata wiring is not a completed Room, layout, support, service or paid-work permission."""
	var fresh: Masks = Masks.new()
	assert_equal(fresh.configure(null, _sites, _budget), Masks.REFUSE_MASK_BINDING, "missing composer")
	assert_equal(fresh.configure(_world_bindings, _sites, Budget.new()), Masks.REFUSE_MASK_BINDING, "foreign same numeric token")
	assert_equal(fresh.configure(_world_bindings, _sites, _budget), &"", "failed bind leaves retry possible")
	assert_equal(fresh.configure(_world_bindings, _sites, _budget), Masks.REFUSE_MASK_BINDING, "immutable wiring")
	assert_true(_masks.exact_binding(_buildings, _owner, _construction, _world_ref), "actual composition")
	assert_false(_masks.exact_binding(Buildings.new(), _owner, _construction, _world_ref), "foreign same-ref Buildings")
	assert_false(_masks.exact_binding(_buildings, _owner, _construction, Vector2i(_world_ref.x, _world_ref.y + 1)), "full World")
	assert_true(_masks.layout_budget_owner() == _budget, "actual shared arena")
	assert_equal(_masks.begin_room_cold(Orders.RoomPlan.new()), Orders.REFUSE_BINDING, "unqualified room admission")
	assert_equal(_masks.begin_layout_cold(_room, 1, 1, 1, 1), 0, "unqualified furnishing contacts")


func test_invalid_scope_and_underfunded_or_bare_tokens_refuse_before_surveys() -> void:
	"""Another actual Site in the same Room and a bare equally funded token cannot borrow this phase."""
	var other: Construction.OpResult = _sites.claim_quantum(ORIGIN + Vector3i(1024, 0, 0), _room)
	assert_true(other.ok, "another actual Site")
	var out: PackedInt32Array = PackedInt32Array([1, 2, 3])
	for wrong: Vector2i in [other.ref, Vector2i(_site.x, _site.y + 1), NULL_REF]:
		assert_true(_masks.finish_mask_into(wrong, _room, _lease, 8, out) != &"", "full current Site required")
		assert_true(out.is_empty(), "refusal clears old mask")
	assert_true(_masks.finish_mask_into(_site, Vector2i(_room.x, _room.y + 1), _lease, 8, out) != &"", "full Room required")
	_world_bindings.end_cold_operation(_lease)
	var bare: int = _budget.acquire(Budget.COLD_BYTES)
	assert_true(_masks.finish_mask_into(_site, _room, bare, 8, out) != &"", "bare token lacks owner scope")
	assert_equal(_budget.release(bare), &"", "caller releases its own bare token")
	assert_equal(_owner.surveys, 0, "no handle survey entered")
	_open_scope()


func test_limits_are_exact_and_metadata_output_is_unchanged_on_refusal() -> void:
	"""Output capacity cannot truncate a shape or silently enlarge a caller's metadata packet."""
	var out: PackedInt32Array = PackedInt32Array([7])
	for limit: int in [-1, 0, 3, Budget.REGION_CAPACITY + 1]:
		assert_equal(_masks.finish_mask_into(_site, _room, _lease, limit, out), Masks.REFUSE_MASK_CAPACITY, "whole requested outline or refusal")
		assert_true(out.is_empty(), "no partial shape")
	assert_equal(_masks.fills, 0, "count refusal never grows output")
	assert_equal(_mask(4).size(), 24, "exact capacity succeeds")
	var section: Owner.Region = _section_scratch()
	section.box.resize(5)
	assert_equal(_masks.phase_section_into(_site, _room, _lease, section), Masks.REFUSE_MASK_OUTPUT, "no implicit resize")
	assert_equal(section.box.size(), 5, "caller size preserved")
	assert_equal(section.owner, _world_ref, "caller metadata preserved")
	assert_equal(_masks.phase_section_into(_site, _room, _lease, null), Masks.REFUSE_MASK_OUTPUT, "null never crashes")


func test_duplicate_claims_refuse_instead_of_double_counting_paid_usable_volume() -> void:
	"""The actual store may retain overlapping same-Room markers; a disjoint mask cannot hide that ambiguity."""
	_world_bindings.end_cold_operation(_lease)
	var token: int = _owner.begin_stage(_owner.revision()).token
	_put(token, PackedInt32Array([X, FLOOR_Y, Z, X + 256, 512, Z + 256]), Space.OBSTACLE, true)
	_publish(token)
	_open_scope()
	var before: PackedByteArray = _owner.state_bytes()
	var out: PackedInt32Array = PackedInt32Array([99])
	assert_equal(_masks.finish_mask_into(_site, _room, _lease, 8, out), Masks.REFUSE_MASK_OVERLAP, "duplicate positive volume refuses")
	assert_true(out.is_empty(), "partial mask removed")
	assert_equal(_owner.state_bytes(), before, "no ad-hoc marker normalization")


func test_foreign_room_and_physical_cavity_never_fill_the_exact_room_hole() -> void:
	"""Metadata envelopes may overlap; unrelated Room claims and nontraversable physical rows remain distinct."""
	_world_bindings.end_cold_operation(_lease)
	var foreign: Vector2i = _create_room()
	var token: int = _owner.begin_stage(_owner.revision()).token
	var floor_ref: Vector2i = _put(token, PackedInt32Array([X + 256, FLOOR_Y, Z + 256, X + 768, FLOOR_Y + 1, Z + 768]),
		Space.FLOOR_DATUM, false, foreign)
	_put(token, PackedInt32Array([X + 256, FLOOR_Y, Z + 256, X + 768, 512, Z + 768]), Space.OBSTACLE, true, foreign, floor_ref)
	_put(token, PackedInt32Array([X + 256, ORIGIN.y, Z + 256, X + 768, ORIGIN.y + 1024, Z + 768]), Space.UNFINISHED)
	_publish(token)
	_open_scope()
	var mask: PackedInt32Array = _mask()
	assert_equal(mask.size(), 24, "only own four exact claims")
	assert_equal(_mask_volume(mask), 805306368, "no free usable volume from paid cavity or another Room")


func test_ambiguous_section_and_real_geometry_revision_change_refuse() -> void:
	"""A second actual section intersecting the same cube is never collapsed into the first."""
	_world_bindings.end_cold_operation(_lease)
	var token: int = _owner.begin_stage(_owner.revision()).token
	var second: Vector2i = _put(token, PackedInt32Array([X + 256, FLOOR_Y, Z + 256, X + 768, FLOOR_Y + 1, Z + 768]), Space.FLOOR_DATUM)
	_put(token, PackedInt32Array([X + 256, FLOOR_Y, Z + 256, X + 768, 512, Z + 768]), Space.OBSTACLE, true, _room, second)
	_publish(token)
	_open_scope()
	var out: Owner.Region = _section_scratch()
	assert_equal(_masks.phase_section_into(_site, _room, _lease, out), &"SPACE_SECTION_AMBIGUOUS", "all exact claims need one full section")
	assert_equal(out.section, Vector2i(77, 78), "metadata output preserved")
	var mask: PackedInt32Array = PackedInt32Array([1])
	assert_equal(_masks.finish_mask_into(_site, _room, _lease, 8, mask), &"SPACE_SECTION_AMBIGUOUS", "same ambiguity in mask")
	assert_true(mask.is_empty(), "no partial output")
	token = _owner.begin_stage(_owner.revision()).token
	_publish(token)
	assert_true(_masks.finish_mask_into(_site, _room, _lease, 8, mask) != &"", "even empty actual publication changes retained revision")


func test_expired_or_reacquired_lease_never_reaches_a_later_copy_boundary() -> void:
	"""Descriptor, handle survey and count-pass callbacks cannot smuggle work under another lease."""
	for boundary: int in [1, 2, 3]:
		for reacquire: bool in [false, true]:
			_owner.arena = _budget
			_owner.token = _lease
			_owner.boundary = boundary
			_owner.remaining_events = 2 if boundary == 3 else 1
			_owner.reacquire = reacquire
			_mask_reset_counts()
			var out: PackedInt32Array = PackedInt32Array([91])
			assert_true(_masks.finish_mask_into(_site, _room, _lease, 8, out) != &"", "expired exact token refuses")
			assert_true(out.is_empty(), "no escaped output")
			assert_equal(_masks.fills, 0, "no output fill after expired boundary")
			assert_equal(_owner.surveys, 0 if boundary == 1 else 1, "no later handle copy")
			_recover_lease()
	assert_equal(_mask().size(), 24, "fresh exact phase retries normally")


func _mask_reset_counts() -> void:
	"""Reset only test instrumentation, never source identities, budgets or physical columns."""
	_owner.surveys = 0
	_owner.region_reads = 0
	_masks.fills = 0


func _recover_lease() -> void:
	"""The real provider clears its stale scope without releasing a foreign replacement token."""
	_owner.boundary = 0
	_world_bindings.end_cold_operation(_lease)
	if _owner.replacement > 0:
		assert_true(_budget.covers(_owner.replacement, Budget.COLD_BYTES), "stale cleanup preserves replacement")
		assert_equal(_budget.release(_owner.replacement), &"", "replacement owner releases it")
		_owner.replacement = 0
	_open_scope()


func test_final_validation_expiry_clears_filled_output_and_allows_exact_retry() -> void:
	"""A fully written mask is still unusable if its last actual source proof loses the arena."""
	_owner.arena = _budget
	_owner.token = _lease
	_owner.boundary = 4
	_owner.remaining_events = 7
	_owner.reacquire = true
	var out: PackedInt32Array = PackedInt32Array()
	assert_true(_masks.finish_mask_into(_site, _room, _lease, 8, out) != &"", "final boundary refuses")
	assert_equal(_masks.fills, 1, "expiry was after fill, not a vacuous early refusal")
	assert_true(out.is_empty(), "already copied output discarded")
	_recover_lease()
	assert_equal(_mask().size(), 24, "fresh current source and token work")


func test_initial_domain_callback_reentry_is_exclusive_without_clearing_outer_scratch() -> void:
	"""The local guard is established before any actual provider/domain callback can call back into it."""
	_spatial.nested = weakref(_masks)
	_spatial.nested_site = _site
	_spatial.nested_room = _room
	_spatial.nested_token = _lease
	_spatial.nested_output = PackedInt32Array([81, 82])
	var out: PackedInt32Array = _mask()
	assert_equal(_spatial.nested_code, Masks.REFUSE_MASK_BUSY, "initial domain callback cannot recurse")
	assert_equal(_spatial.nested_output, PackedInt32Array([81, 82]), "busy refusal does not erase borrowed output")
	assert_equal(out.size(), 24, "outer query retains truthful complete result")


func test_changed_site_claim_project_and_world_lifetime_refuse_without_reusing_old_proof() -> void:
	"""Current real identities, not cached numeric coordinates, determine every read."""
	var out: PackedInt32Array = PackedInt32Array([1])
	assert_true(_sites.release_room_claim(_site).ok, "actual unstarted Room claim retired")
	assert_true(_masks.finish_mask_into(_site, _room, _lease, 8, out) != &"", "released Room claim refuses")
	assert_true(out.is_empty(), "old mask cleared")
	assert_true(_sites.claim_quantum(ORIGIN, _room).ok, "history reclaims same actual quantum")
	_restart_scope()
	assert_true(_sites.open_phase(_site, Contract.OP_BRACE).ok, "actual current project changed")
	assert_true(_masks.finish_mask_into(_site, _room, _lease, 8, out) != &"", "old pre-project scope refuses")
	_restart_scope()
	_world.clear()
	assert_true(_masks.finish_mask_into(_site, _room, _lease, 8, out) != &"", "retired actual World refuses")
	assert_true(out.is_empty(), "no retired-World mask")


func test_actual_domain_wiring_cannot_follow_changed_synthetic_geometry_numbers() -> void:
	"""The explicit same-Domain proof prevents a same Site/Room lease from crossing a different datum."""
	var changed: Space.Domain = Space.Domain.new()
	assert_equal(changed.configure(_world_ref, Vector3i(0, 0, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 8192, Space.MAX_CHECKS), &"", "different authored datum")
	_spatial.domain = changed
	var out: PackedInt32Array = PackedInt32Array([9])
	assert_equal(_masks.finish_mask_into(_site, _room, _lease, 8, out), &"SPACE_SITE_DOMAIN", "no coincident numeric remapping")
	assert_true(out.is_empty(), "foreign domain output empty")
	assert_equal(_owner.surveys, 0, "no survey before exact Domain proof")
	_spatial.domain = _domain()
	assert_equal(_mask().size(), 24, "correct immutable Domain restores observation")


func test_complete_scan_allowance_is_admitted_before_handle_or_mask_growth() -> void:
	"""An authored work ceiling below the complete boundary cost refuses rather than omitting validation."""
	_world_bindings.end_cold_operation(_lease)
	_mask_reset_counts()
	_bind_space(Masks.SCAN_CHECKS - 1)
	var token: int = _owner.begin_stage(_owner.revision()).token
	assert_equal(_owner.stage_source(token, _room), &"", "same actual Room in new sparse composition")
	_publish(token)
	_claims_fixture()
	_masks = ObservedMasks.new()
	assert_equal(_masks.configure(_world_bindings, _sites, _budget), &"", "same actual owners and smaller work limit")
	_open_scope()
	var out: PackedInt32Array = PackedInt32Array([3])
	assert_equal(_masks.finish_mask_into(_site, _room, _lease, 8, out), Masks.REFUSE_MASK_BUDGET, "complete scan precharge")
	assert_true(out.is_empty(), "no partial output")
	assert_equal(_owner.surveys, 0, "work denied before handle image")
	var section: Owner.Region = _section_scratch()
	assert_equal(_masks.phase_section_into(_site, _room, _lease, section), Masks.REFUSE_MASK_BUDGET, "section path also charges complete proof")
	assert_equal(section.box[0], 71, "refused metadata remains unchanged")


func test_nested_pair_work_exhaustion_clears_the_complete_partial_mask() -> void:
	"""A finite valid operation ceiling pays for both repeated row reads and growing pair comparisons."""
	_world_bindings.end_cold_operation(_lease)
	_bind_space(Masks.SCAN_CHECKS + 32)
	var token: int = _owner.begin_stage(_owner.revision()).token
	assert_equal(_owner.stage_source(token, _room), &"", "actual same Room")
	_section = _put(token, PackedInt32Array([X, FLOOR_Y, Z, X + 1024, FLOOR_Y + 1, Z + 1024]), Space.FLOOR_DATUM)
	for index: int in 10:
		_put(token, PackedInt32Array([X + index * 64, FLOOR_Y, Z, X + (index + 1) * 64, 512, Z + 1024]), Space.OBSTACLE, true)
	_publish(token)
	_masks = ObservedMasks.new()
	assert_equal(_masks.configure(_world_bindings, _sites, _budget), &"", "real bounded composition")
	_open_scope()
	var before: PackedByteArray = _owner.state_bytes()
	var out: PackedInt32Array = PackedInt32Array([33])
	assert_equal(_masks.finish_mask_into(_site, _room, _lease, 10, out), Masks.REFUSE_MASK_BUDGET, "all ten rows fit; nested comparisons exhaust work")
	assert_equal(_masks.fills, 1, "actual partial fill was entered")
	assert_true(out.is_empty(), "partial output cannot escape")
	assert_equal(_owner.state_bytes(), before, "refusal cannot normalize authoritative rows")


func test_numerically_equal_foreign_sites_cannot_bind_actual_construction_namespace() -> void:
	"""Two real owner graphs can allocate identical Room/Site numbers without sharing any authority."""
	var foreign: GDScript = get_script() as GDScript
	var other: RefCounted = foreign.new()
	other.before_each()
	assert_true(other.failures.is_empty(), "second actual fixture setup succeeded")
	assert_equal(other._room, _room, "same numeric Room fixture")
	assert_equal(other._site, _site, "same numeric Site fixture")
	var candidate: Masks = Masks.new()
	assert_equal(candidate.configure(_world_bindings, other._sites, _budget), Masks.REFUSE_MASK_BINDING, "actual Construction/Sites pairing is mandatory")
	assert_true(candidate._cube.is_empty() and candidate._clip.is_empty(), "refusal precedes reusable packed allocation")
	assert_false(_masks.exact_binding(other._buildings, other._owner, other._construction, other._world_ref), "foreign complete owner graph")
	other.after_each()
	assert_true(other.failures.is_empty(), "second actual fixture cleanup succeeded")


func test_retired_actual_room_preserves_prior_metadata_and_clears_prior_mask() -> void:
	"""Keeping stale Buildings columns after Directory retirement is not a live Room identity."""
	var section: Owner.Region = _section_scratch()
	var out: PackedInt32Array = _mask()
	assert_true(_jobs.directory().destroy(_room), "real full Room lifetime ended")
	assert_true(_masks.phase_section_into(_site, _room, _lease, section) != &"", "retired Room cannot resolve floor")
	assert_equal(section.section, Vector2i(77, 78), "previous metadata preserved")
	assert_true(_masks.finish_mask_into(_site, _room, _lease, 8, out) != &"", "retired Room mask refused")
	assert_true(out.is_empty(), "old usable candidate cleared")
