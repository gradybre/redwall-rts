extends "res://test/framework/test_case.gd"
## Actual Terrain, Levels, Room, Sites, Work, Inventory and structural rows. The fixture's body,
## reach, entry approach and service/route companion remain explicit synthetic inputs, never qualification.

const Structure := preload("res://scripts/core/underground_phase_structure.gd")
const Fixture := preload("res://test/test_underground_space_authority.gd")
const Authority := preload("res://scripts/core/underground_space_authority.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const World := preload("res://scripts/core/world_init.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Forage := preload("res://scripts/core/forage.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const Rng := preload("res://scripts/core/rng.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const X: int = 60 * 2048
const Z: int = 50 * 2048
const FLOOR_Y: int = -4608
const ROOF_Y: int = -512
const ORIGIN: Vector3i = Vector3i(X, FLOOR_Y, Z)
const LEVEL_PACK: String = "res://data/underground/initial_level_pack.uglvl"
const LEVEL_HASH: String = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"


class ActualScope extends Structure.Scope:
	## Actual WorldBindings owns the scope; only operation/stage dispatch is fixture composition.
	var bindings: WeakRef = null
	var levels: Levels = null
	var owner: WeakRef = null
	var terrain: WeakRef = null
	var sites: WeakRef = null
	var arena: Budget = null
	var operation: int = -1
	var stage: int = -1
	var deny: bool = false
	var exact_reads: int = 0
	var release_keepers: Array[Structure.Scope] = []
	var reenter: WeakRef = null
	var nested_code: StringName = &""

	func phase_world_owner() -> RefCounted:
		"""Return the actual reciprocal composer identity without granting a scope."""
		return bindings.get_ref()

	func exact_binding(store: Owner, earth: Terrain, authored: Levels, physical: Sites, budget: Budget) -> bool:
		"""Full actual object identities select one World; no numeric full-ref coincidence suffices."""
		exact_reads += 1
		release_keepers.clear()
		return owner.get_ref() == store and terrain.get_ref() == earth and sites.get_ref() == physical \
			and authored == levels and budget == arena and (bindings.get_ref() as WorldBindings).space_owner() == store

	func phase_refusal(token: int, site: Vector2i, op: int, step: int, room: Vector2i) -> StringName:
		"""Check the real held site/project/geometry lease plus exact fixture dispatch before every boundary."""
		if reenter != null:
			var value: Structure = reenter.get_ref() as Structure
			reenter = null
			nested_code = value.structure_refusal(site, op, step, room, token)
		if deny or op != operation or step != stage:
			return &"FIXTURE_STRUCTURE_SCOPE"
		return (bindings.get_ref() as WorldBindings).cold_site_refusal(token, site, room)


class ObservedStructure extends Structure:
	## Instrument only whether a refused preallocation boundary entered the actual allocating branch.
	var banks_before_drop: int = -1
	var handles_before_drop: int = -1
	var remaining_before_drop: int = -1

	func _drop_cold() -> void:
		"""Preserve raw lengths before the real provider discards its owned images."""
		banks_before_drop = _front.size() + _back.size()
		handles_before_drop = _handles.size()
		remaining_before_drop = _remaining
		super._drop_cold()


class StructuralBindings extends Fixture.SyntheticBindings:
	## Reuse actual paid worker fixture, replacing its structural permission with the real provider.
	var composer: WorldBindings = null
	var structure: ObservedStructure = null
	var scope: ActualScope = null
	var held_site: Vector2i = NULL_REF
	var held_room: Vector2i = NULL_REF
	var held_operation: int = -1
	var held_stage: int = -1
	var held_owner_token: int = 0
	var last_structure_code: StringName = &""

	func allocation_refusal(store: Owner, rows: int, cache_bytes: int) -> StringName:
		"""The full admitted pack requires the actual joint capacity gate, not the older small fixture limit."""
		return composer.allocation_refusal(store, rows, cache_bytes)

	func begin_cold_operation(store: Owner, site: Vector2i, operation: int, stage: int) -> int:
		"""Acquire the exact real shared Budget before plans/surveys; production geometry is not mocked."""
		cold_active = composer.begin_cold_operation(store, site, operation, stage)
		if cold_active == 0:
			return 0
		cold_opened += 1
		held_site = site
		held_room = sites.room_of(site)
		held_operation = operation
		held_stage = stage
		scope.operation = operation
		scope.stage = stage
		last_plan = null
		(owner as Fixture.ObservedSpace).last_snapshot = null
		(owner as Fixture.ObservedSpace).observed_token = cold_active
		return cold_active

	func cold_operation_refusal(token: int) -> StringName:
		"""All provider mutations remain under the actual World's current exclusive lease."""
		return composer.cold_operation_refusal(token)

	func end_cold_operation(token: int) -> void:
		"""The real World releases only its exact token; a replacement reservation is left untouched."""
		composer.end_cold_operation(token)
		cold_active = 0
		cold_closed += 1

	func phase_plan_row_limit(store: Owner, token: int) -> int:
		"""Use the actual existing finite phase allowance, not a second independent permission."""
		return composer.phase_plan_row_limit(store, token)

	func phase_snapshot_into(store: Owner, physical: Sites, site: Vector2i, operation: int,
			stage: int, room: Vector2i, plan: Space.Plan, out: Space.Snapshot, token: int) -> StringName:
		"""Actual natural terrain and paid history both contribute to the synthetic contact fixture."""
		(owner as Fixture.ObservedSpace).last_snapshot = weakref(out)
		return composer.phase_snapshot_into(store, physical, site, operation, stage, room, plan, out, token)

	func phase_qualification_refusal(domain: Space.Domain, snapshot: Space.Snapshot,
			plan: Space.Plan, site: Vector2i, operation: int, stage: int) -> StringName:
		"""Only the body/approach remains synthetic; exact natural support comes from real content and state."""
		var code: StringName = super.phase_qualification_refusal(domain, snapshot, plan, site, operation, stage)
		if code == &"":
			code = structure.structure_refusal(site, operation, stage, sites.room_of(site), cold_active)
		last_structure_code = code
		return code

	func stage_physical_geometry(store: Owner, token: int, site: Vector2i,
			operation: int, stage: int, room: Vector2i, _plan: Space.Plan) -> StringName:
		"""No caller plan supplies natural bearing earth or substitute installed-support state."""
		if store != owner:
			return &"FIXTURE_FOREIGN_SPACE"
		held_owner_token = token
		last_structure_code = structure.stage_geometry(token, site, operation, stage, room, cold_active)
		return last_structure_code

	func prepare_companions(token: int, site: Vector2i, operation: int,
			stage: int, room: Vector2i, _plan: Space.Plan) -> int:
		"""The actual structural future qualifies; this fixture publishes no production service or route."""
		last_structure_code = structure.prepared_refusal(token, site, operation, stage, room, cold_active)
		pending = last_structure_code == &""
		return 1 if pending else 0

	func prepared_refusal(token: int) -> StringName:
		"""Revalidate the exact natural future before Inventory commits real physical outputs."""
		if token != 1 or not pending:
			return &"FIXTURE_NO_COMPANION"
		return structure.prepared_refusal(held_owner_token, held_site, held_operation, held_stage, held_room, cold_active)


class ActualHarness extends Fixture:
	## Reuse the actual worker/economy setup; only the original synthetic domain and structural binding change.
	var world_map: World = null
	var nodes: Nodes = null
	var terrain: Terrain = null
	var composer: WorldBindings = null
	var levels: Levels = null
	var budget: Budget = null
	var structure: ObservedStructure = null
	var scope: ActualScope = null
	var region_rows: int = Budget.REGION_CAPACITY
	var source_rows: int = Budget.SOURCE_CAPACITY

	func before_each() -> void:
		"""Generate World before allocating any foreign identity; then compose the same real worker stores."""
		_residents = Residents.new()
		_priorities = Priorities.new()
		_schedule = Schedule.new(_residents.needs())
		_jobs = Jobs.new(_residents, _priorities, _schedule)
		_inventory = Inventory.new(16, 512)
		_items = Items.new()
		assert_true(_items.load_default(_inventory).ok, "actual item catalog")
		_generate_world()
		_world = _residents.directory().create(Directory.KIND_WORLD)
		_work = Work.new(_jobs)
		_pool = Reservations.new()
		_gear = Gear.new(8)
		assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
		assert_true(_work.bind_gear(_gear).ok, "actual Work")
		_store = _inventory.create_container(_world, 100000, -1, 0, true).ref
		_output = _inventory.create_container(_world, 100000, -1, 0, true).ref
		_buildings = Buildings.new(_residents.directory())
		_construction = Construction.new(_buildings)
		_create_room_and_geometry()
		_bind_space()
		_resident = _worker()

	func _generate_world() -> void:
		"""Use real node/forage/fishing generation and its actual shared Directory."""
		nodes = Nodes.new(_jobs.directory())
		var forage: Forage = Forage.new(_jobs.directory(), _jobs)
		var fishing: Fishing = Fishing.new(_jobs.directory(), forage, _jobs)
		world_map = World.new(_jobs.directory(), nodes, forage, fishing, Rng.new(), null, null, _jobs)
		var generated: World.GenerateResult = world_map.generate(World.bound_request(_items).request)
		assert_true(generated.ok, "real authored map: %s" % generated.error)

	func _create_room_and_geometry() -> void:
		"""Real map and authored level content surround exact fine claims and an explicitly synthetic approach."""
		_room_commands = SyntheticRoomCommands.new()
		_room_commands.owner = weakref(_buildings)
		assert_true(_buildings.bind_spatial_authority(_room_commands).ok, "registration-only fixture authority")
		_room_commands.registering = true
		_room = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_DORMITORY).ref
		_room_commands.registering = false
		_sources = Owner.CoreSources.new(_buildings.directory(), _buildings, _construction)
		_owner = ObservedSpace.new(_sources)
		var domain: Space.Domain = Space.Domain.new()
		assert_equal(domain.configure(_world, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
			Vector3i(256, 48, 256), 8192, 8192, Space.MAX_CHECKS), &"", "actual immutable domain")
		assert_equal(_owner.configure(domain, region_rows, source_rows), &"", "actual admitted pack")
		budget = Budget.new()
		terrain = Terrain.new()
		assert_equal(terrain.configure(world_map, nodes, _owner, _sources, _items, budget), &"", "actual terrain")
		composer = WorldBindings.new()
		assert_equal(composer.configure(world_map, terrain, _owner, _sources, budget), &"", "actual cold compositor")
		levels = Levels.new()
		assert_equal(levels.load_file(LEVEL_PACK, LEVEL_HASH, 1), &"", "actual level source")
		assert_equal(levels.bind_domain(domain, _jobs.directory(), domain.descriptor(), Space.VERSION), &"", "actual level domain")
		_claims()

	func _claims() -> void:
		"""Two disjoint L-shaped claim strips, with a known unpaid corner; no floor envelope grants usable area."""
		var token: int = _owner.begin_stage(_owner.revision()).token
		assert_equal(_owner.stage_source(token, _room), &"", "actual registered Room")
		_floor = _add(token, [X - 1024, FLOOR_Y, Z, X + 1024, FLOOR_Y + 1, Z + 1024], Space.FLOOR_DATUM, _room)
		_add(token, [X - 1024, FLOOR_Y, Z, X, FLOOR_Y + 4096, Z + 1024], Space.SUPPORTED_VOID, _room)
		_add(token, [X, FLOOR_Y, Z, X + 1024, ROOF_Y, Z + 256], Space.OBSTACLE, _room, Owner.CLAIM_ROOM)
		_add(token, [X, FLOOR_Y, Z + 256, X + 256, ROOF_Y, Z + 1024], Space.OBSTACLE, _room, Owner.CLAIM_ROOM)
		assert_equal(_owner.seal(token), &"", "actual fine Room claims")
		_owner.publish(token)

	func _bind_space() -> void:
		"""Use actual paid Sites and real geometry adapter, with explicit synthetic worker/profile companion only."""
		var bindings: StructuralBindings = StructuralBindings.new()
		_bindings = bindings
		bindings.source_reader = _sources
		bindings.owner = _owner
		bindings.buildings = _buildings
		bindings.jobs = _jobs
		bindings.inventory = _inventory
		bindings.floor_ref = _floor
		bindings.composer = composer
		_authority = Authority.new()
		assert_equal(_authority.configure(_owner, bindings, 1), &"", "actual paid adapter")
		_sites = Sites.new(_construction, _inventory, _pool, _items, _jobs, _work, _authority, 512, 8)
		bindings.sites = _sites
		assert_equal(_sites.initialization_refusal(), &"", "actual Sites")
		assert_equal(_authority.bind_sites(_sites), &"", "actual paid Site identity")
		var claimed: Construction.OpResult = _sites.claim_quantum(Vector3i(X, FLOOR_Y, Z), _room)
		_site = claimed.ref
		assert_true(claimed.ok, "actual paid cube: %s" % claimed.error)
		_configure_structure(bindings)

	func _configure_structure(bindings: StructuralBindings) -> void:
		"""Bind weak actual identity links only after the physical ledger is initialized, before cold work."""
		scope = ActualScope.new()
		scope.bindings = weakref(composer)
		scope.levels = levels
		scope.owner = weakref(_owner)
		scope.terrain = weakref(terrain)
		scope.sites = weakref(_sites)
		scope.arena = budget
		structure = ObservedStructure.new()
		assert_equal(structure.configure(scope, _owner, terrain, levels, _sites, budget), &"", "actual natural structure")
		bindings.structure = structure
		bindings.scope = scope

	func after_each() -> void:
		"""Release only the actual objects owned by this fixture; every weak composition link remains acyclic."""
		super.after_each()
		structure = null
		scope = null
		composer = null
		terrain = null
		world_map = null
		nodes = null
		levels = null
		budget = null


var _h: ActualHarness = null


func before_each() -> void:
	"""A reusable actual worker fixture feeds these separate structural regression assertions."""
	_h = ActualHarness.new()
	_h.before_each()
	assert_equal(_h.failures, PackedStringArray(), "actual fixture setup")


func after_each() -> void:
	"""All nested actual worker/accounting assertions remain visible to the outer strict suite."""
	_h.after_each()
	assert_equal(_h.failures, PackedStringArray(), "actual fixture worker and cleanup checks")
	_h = null


func test_real_pack_cold_estimates_and_unbound_provider() -> void:
	"""The largest actual pack admits every complete simultaneous lifetime, not independent maxima."""
	assert_equal(Structure.cold_peak_bytes(Structure.CHECK, 6144), 1048528, "two surveys and two plans, no banks")
	assert_equal(Structure.cold_peak_bytes(Structure.STAGE, 6144), 917456, "original survey, two plans and flat banks")
	assert_equal(Structure.cold_peak_bytes(Structure.PREPARED, 6144), 524240, "future survey, plans and handles")
	assert_equal(Structure.cold_peak_bytes(Structure.STAGE, 0), -1, "unconfigured capacity refused")
	assert_equal(Structure.cold_peak_bytes(999, 6144), -1, "unknown lifetime refused")
	var unbound: Structure = Structure.new()
	assert_equal(unbound.structure_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT, _h._room, 1),
		Structure.REFUSE_BINDING, "a bare token never grants actual structure")
	assert_equal(unbound.configure(Structure.Scope.new(), _h._owner, _h.terrain, _h.levels, _h._sites, _h.budget),
		Structure.REFUSE_BINDING, "base actual Scope remains unavailable")


func test_paid_brace_protects_exact_fine_floor_and_roof() -> void:
	"""Real Work and consumed brace inputs precede natural protection; no cut/void is fabricated."""
	_h._complete(Contract.OP_BRACE)
	assert_true(_h._sites.installed_support(_h._site), "actual paid support bit")
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_h._owner.snapshot_into(image), &"", "actual retained geometry")
	var support_rows: int = 0
	var support_volume: int = 0
	for row: int in image.volumes.role.size():
		if image.volumes.role[row] != Space.SUPPORT:
			continue
		support_rows += 1
		var box: PackedInt32Array = image.volumes.box_at(row)
		assert_true(box[4] <= FLOOR_Y or box[1] >= ROOF_Y, "clear room height unchanged")
		assert_equal(image.volumes.ref_at(row), _h._room, "natural support belongs to exact Room")
		support_volume += (box[3] - box[0]) * (box[4] - box[1]) * (box[5] - box[2])
	assert_equal(support_rows, 4, "two exact disjoint strips times floor and roof")
	assert_equal(support_volume, (1024 * 256 + 256 * 768) * 2048, "fine missing corner stays unprotected")
	assert_equal(_h._sites.embedded_earth_milli(_h._site), 0, "brace did not cut or backfill earth")
	assert_true(_h.structure.remaining_before_drop > 0, "actual 6144/2048 pass remains bounded")


func test_paid_cut_and_fine_finish_retain_natural_protections() -> void:
	"""Paid full-cube earth output remains separate from exact fine finished shell and retained natural bands."""
	_h._complete(Contract.OP_BRACE)
	_h._complete(Contract.OP_CUT)
	_h._complete(Contract.OP_FINISH)
	assert_true(_h._sites.installed_support(_h._site), "real brace still retained")
	assert_equal(_h._sites.earth_conservation_refusal(), &"", "real earth ledger conserves")
	assert_equal(_h._sites.support_conservation_refusal(), &"", "real paid inputs remain accounted")
	assert_equal((_h._bindings as StructuralBindings).last_structure_code, &"", "actual natural provider composed")


func _scope(operation: int, stage: int, site: Vector2i = NULL_REF) -> int:
	"""Open the real cold lease for one exact physical context, without changing paid state."""
	if site == NULL_REF:
		site = _h._site
	var token: int = _h._bindings.begin_cold_operation(_h._owner, site, operation, stage)
	assert_true(token > 0, "actual exact World lease")
	return token


func _check(operation: int, stage: int = Contract.STAGE_ADMIT) -> StringName:
	"""Cold query success/refusal must leave its own large arrays dropped before the caller releases."""
	var token: int = _scope(operation, stage)
	var code: StringName = _h.structure.structure_refusal(_h._site, operation, stage, _h._room, token)
	assert_true(_h.structure._handles.is_empty() and _h.structure._front.is_empty() and _h.structure._back.is_empty(), "no retained image")
	_h._bindings.end_cold_operation(token)
	return code


func _commit_geometry(token: int) -> void:
	"""Only fixture-authored initial corruption/protection rows bypass economic construction, never paid completion."""
	assert_equal(_h._owner.seal(token), &"", "exact fixture geometry validates")
	_h._owner.publish(token)


func _row_handles(role: int) -> PackedInt32Array:
	"""Test-only full metadata inspection uses actual public generation-qualified handles."""
	var handles: PackedInt32Array = PackedInt32Array()
	assert_equal(_h._owner.overlapping_regions_into(PackedInt32Array([X, FLOOR_Y - 1024, Z, X + 1024, 512, Z + 1024]), handles), &"", "actual handles")
	var result: PackedInt32Array = PackedInt32Array()
	var row: Owner.Region = Owner.Region.new()
	row.box.resize(6)
	for at: int in range(0, handles.size(), 2):
		var ref: Vector2i = Vector2i(handles[at], handles[at + 1])
		assert_equal(_h._owner.region_into_reused(ref, row), &"", "actual complete region")
		if row.role == role:
			result.append_array(PackedInt32Array([ref.x, ref.y]))
	return result


func test_identity_only_provider_readers_and_exact_scope() -> void:
	"""Reciprocal bindings expose actual identity but never manufacture a shared cold or room permission."""
	assert_true(_h.structure.scope_owner() == _h.scope, "actual borrowed scope")
	assert_true(_h.structure.is_bound_to(_h._owner, _h.terrain, _h.levels, _h._sites, _h.budget), "exact actual owners")
	assert_false(_h.structure.is_bound_to(_h._owner, _h.terrain, _h.levels, _h._sites, Budget.new()), "foreign arena refuses")
	assert_null(Structure.Scope.new().phase_world_owner(), "base scope names no World")
	var token: int = _scope(Contract.OP_BRACE, Contract.STAGE_ADMIT)
	var before: PackedByteArray = _h._owner.state_bytes()
	assert_true(_h.structure.structure_refusal(_h._site, Contract.OP_CUT, Contract.STAGE_ADMIT, _h._room, token) != &"", "different operation")
	assert_true(_h.structure.structure_refusal(Vector2i(_h._site.x, _h._site.y + 1), Contract.OP_BRACE,
		Contract.STAGE_ADMIT, _h._room, token) != &"", "full Site generation")
	assert_true(_h.structure.structure_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT,
		Vector2i(_h._room.x, _h._room.y + 1), token) != &"", "full Room generation")
	assert_true(_h._owner.state_bytes() == before, "no structure from identity-only queries")
	_h._bindings.end_cold_operation(token)


func test_material_free_query_allocates_no_fragment_banks_and_checks_budget_before_handles() -> void:
	"""Actual full-pack qualification stays inside the dual-survey lifetime; work exhaustion refuses before growth."""
	assert_equal(_check(Contract.OP_BRACE), &"", "actual dry natural bands before brace")
	assert_equal(_h.structure.banks_before_drop, 0, "CHECK cannot overlap fragment banks with both surveys")
	assert_true(_h.structure.handles_before_drop > 0, "real fine claims were observed")
	_h.structure._domain._checks = 100
	assert_equal(_check(Contract.OP_BRACE), Structure.REFUSE_BUDGET, "finite engineering budget")
	assert_equal(_h.structure.handles_before_drop, 0, "refusal before handle image")
	assert_false(_h._sites.installed_support(_h._site), "query cannot fabricate paid support")


func test_existing_paid_cavity_cannot_be_mistaken_for_original_natural_earth() -> void:
	"""The generated map remains dirt, but actual removed bearing earth blocks the structural proof."""
	var token: int = _h._owner.begin_stage(_h._owner.revision()).token
	_h._add(token, [X, FLOOR_Y - 1024, Z, X + 128, FLOOR_Y, Z + 128], Space.UNFINISHED, _h._room)
	_commit_geometry(token)
	var bytes: PackedByteArray = _h._owner.state_bytes()
	assert_equal(_h.terrain.natural_support_refusal(PackedInt32Array([X, FLOOR_Y - 1024, Z, X + 128, FLOOR_Y, Z + 128])), &"", "original map is still naturally dry")
	assert_equal(_check(Contract.OP_BRACE), Structure.REFUSE_BAND, "retained cavity wins")
	assert_true(_h._owner.state_bytes() == bytes, "refusal changes no matter")
	assert_false(_h._sites.installed_support(_h._site), "no input-free installed support")


func test_another_confirmed_section_protects_its_footing_before_any_brace() -> void:
	"""Metadata grants no usable void, while the actual fine neighboring footprint retains its required earth."""
	var token: int = _h._owner.begin_stage(_h._owner.revision()).token
	var section: Vector2i = _h._add(token, [X, FLOOR_Y + 1024, Z, X + 1024, FLOOR_Y + 1025, Z + 1024], Space.FLOOR_DATUM, _h._room)
	var claim: Owner.Region = Owner.Region.new()
	claim.box = PackedInt32Array([X, FLOOR_Y + 1024, Z, X + 256, ROOF_Y, Z + 1024])
	claim.role = Space.OBSTACLE
	claim.level = 1
	claim.owner = _h._room
	claim.section = section
	claim.claim_kind = Owner.CLAIM_ROOM
	claim.claim_ref = _h._room
	assert_true(_h._owner.stage_add(token, claim).ok(), "exact raised neighboring section")
	_commit_geometry(token)
	assert_equal(_check(Contract.OP_BRACE), Structure.REFUSE_PROTECTED, "whole paid cube would remove its footing")
	assert_false(_h._sites.installed_support(_h._site), "required natural earth is distinct from paid supports")


func test_unauthored_clear_height_is_not_silently_shortened_or_inferred() -> void:
	"""Exact section content owns ceiling/footing geometry; a similar-looking claim does not alter that contract."""
	var claims: PackedInt32Array = _row_handles(Space.OBSTACLE)
	var handle: Vector2i = Vector2i(claims[0], claims[1])
	var row: Owner.Region = Owner.Region.new()
	assert_equal(_h._owner.region_into(handle, row), &"", "actual initial fine strip")
	row.box[4] -= 1
	var token: int = _h._owner.begin_stage(_h._owner.revision()).token
	assert_equal(_h._owner.stage_remove(token, handle), &"", "replace fixture clear height")
	assert_true(_h._owner.stage_add(token, row).ok(), "integer claim remains valid geometry")
	_commit_geometry(token)
	assert_equal(_check(Contract.OP_BRACE), Structure.REFUSE_SECTION, "one-unit unauthored ceiling refuses")


func test_same_column_braces_reuse_room_protection_and_one_close_cannot_release_it() -> void:
	"""Two actual paid Sites have distinct salvage accounts while natural protection has Room lifetime."""
	_h._complete(Contract.OP_BRACE)
	var first_support: PackedInt32Array = _row_handles(Space.SUPPORT)
	var lower: Vector2i = _h._site
	var upper: Construction.OpResult = _h._sites.claim_quantum(ORIGIN + Vector3i(0, 1024, 0), _h._room)
	assert_true(upper.ok, "second full quantum in same Room column")
	_h._site = upper.ref
	_h._complete(Contract.OP_BRACE)
	assert_equal(_row_handles(Space.SUPPORT), first_support, "no duplicate natural rows")
	_h._complete(Contract.OP_UNOPENED_SUPPORT_CLOSE)
	assert_false(_h._sites.installed_support(upper.ref), "this actual support account salvaged")
	assert_true(_h._sites.installed_support(lower), "other real support account retained")
	assert_equal(_row_handles(Space.SUPPORT), first_support, "another Site cannot release Room protection")
	_h._site = lower
	assert_equal(_check(Contract.OP_CUT), &"", "remaining actual phase still sees complete natural support")


func test_sealed_candidate_cannot_remove_protection_or_exact_claims() -> void:
	"""Current terrain truth alone cannot approve a future that deletes an existing room obligation."""
	_h._complete(Contract.OP_BRACE)
	_h._open(Contract.OP_CUT)
	var supports: PackedInt32Array = _row_handles(Space.SUPPORT)
	var before: PackedByteArray = _h._owner.state_bytes()
	var cold: int = _scope(Contract.OP_CUT, Contract.STAGE_START)
	var token: int = _h._owner.begin_stage(_h._owner.revision()).token
	assert_equal(_h._owner.stage_remove(token, Vector2i(supports[0], supports[1])), &"", "fixture removes one required band")
	assert_equal(_h._owner.seal(token), &"", "schema alone does not grant natural support")
	assert_equal(_h.structure.prepared_refusal(token, _h._site, Contract.OP_CUT, Contract.STAGE_START, _h._room, cold),
		Structure.REFUSE_SUPPORT, "future coverage required")
	_h._owner.abort(token)
	_h._bindings.end_cold_operation(cold)
	assert_true(_h._owner.state_bytes() == before, "failed future leaves actual protections intact")


func test_original_token_replaced_after_handles_prevents_bank_allocation_and_payment() -> void:
	"""An actual same-arena replacement is not the caller's admitted lifetime, even if it reserves the same bytes."""
	var job: int = _h._start(Contract.OP_BRACE)
	_h._finish_work(job)
	var before: PackedByteArray = _h._owner.state_bytes()
	var inventory: PackedByteArray = _h._inventory.state_bytes()
	var cold: int = _scope(Contract.OP_BRACE, Contract.STAGE_COMMIT)
	var token: int = _h._owner.begin_stage(_h._owner.revision()).token
	var observed: Fixture.ObservedSpace = _h._owner as Fixture.ObservedSpace
	observed.observed_budget = _h.budget
	observed.replace_at_read = observed.handle_reads + 1
	assert_true(_h.structure.stage_geometry(token, _h._site, Contract.OP_BRACE, Contract.STAGE_COMMIT, _h._room, cold) != &"", "stale lifetime refuses")
	assert_equal(_h.structure.banks_before_drop, 0, "no flat banks allocated under replaced token")
	_h._owner.abort(token)
	assert_true(_h._owner.state_bytes() == before, "no live geometry change after candidate abort")
	assert_true(_h._inventory.state_bytes() == inventory, "no material change")
	_h._bindings.end_cold_operation(cold)
	assert_true(_h.budget.covers(observed.replacement_token, Budget.COLD_BYTES), "foreign replacement survives cleanup")
	assert_equal(_h.budget.release(observed.replacement_token), &"", "test explicitly releases its replacement")
	observed.observed_budget = null
	assert_true(_h._sites.settle_phase(_h._site).ok, "same paid work retries successfully")
	assert_true(_h._sites.installed_support(_h._site), "real brace publishes only after retry")


func test_split_support_union_passes_but_duplicate_volume_cannot_hide_a_hole() -> void:
	"""Coverage is geometric union, not a sum vulnerable to overlaps with equal missing volume."""
	_h._complete(Contract.OP_BRACE)
	var handles: PackedInt32Array = _row_handles(Space.SUPPORT)
	var handle: Vector2i = Vector2i(handles[0], handles[1])
	var row: Owner.Region = Owner.Region.new()
	assert_equal(_h._owner.region_into(handle, row), &"", "actual support band")
	var right: int = row.box[3]
	var middle: int = row.box[0] + ((right - row.box[0]) >> 1)
	var token: int = _h._owner.begin_stage(_h._owner.revision()).token
	assert_equal(_h._owner.stage_remove(token, handle), &"", "replace one band with two exact halves")
	row.box[3] = middle
	var left: Vector2i = _h._owner.stage_add(token, row).handle
	row.box[0] = middle
	row.box[3] = right
	assert_true(_h._owner.stage_add(token, row).ok(), "right half")
	_commit_geometry(token)
	assert_equal(_check(Contract.OP_CUT), &"", "complete disjoint union")
	token = _h._owner.begin_stage(_h._owner.revision()).token
	assert_equal(_h._owner.stage_remove(token, left), &"", "remove left half")
	assert_true(_h._owner.stage_add(token, row).ok(), "duplicate right half, deliberately corrupt physical ownership")
	_commit_geometry(token)
	assert_equal(_check(Contract.OP_CUT), Structure.REFUSE_OVERLAP, "equal-volume duplicate cannot hide missing earth protection")


func test_reentry_poison_refuses_outer_observation_and_clean_retry_remains_possible() -> void:
	"""A typed collaborator cannot reuse the same provider scratch during an active pass."""
	var before: PackedByteArray = _h._owner.state_bytes()
	_h.scope.reenter = weakref(_h.structure)
	assert_equal(_check(Contract.OP_BRACE), Structure.REFUSE_BUSY, "outer observation refuses after nested call")
	assert_equal(_h.scope.nested_code, Structure.REFUSE_BUSY, "nested query is refused before shared scratch")
	assert_equal(_h.structure.handles_before_drop, 0, "no allocation after poisoned first callback")
	assert_true(_h._owner.state_bytes() == before, "no state side effect")
	assert_equal(_check(Contract.OP_BRACE), &"", "fresh query can retry")


func test_late_sparse_capacity_refusal_keeps_real_paid_work_and_retries_without_double_inputs() -> void:
	"""Partial stage additions are discarded when the actual small technical arena fills."""
	_h.after_each()
	assert_equal(_h.failures, PackedStringArray(), "first fixture cleanup")
	_h = ActualHarness.new()
	_h.region_rows = 8
	_h.source_rows = 8
	_h.before_each()
	assert_equal(_h.failures, PackedStringArray(), "small actual configured pack")
	var token: int = _h._owner.begin_stage(_h._owner.revision()).token
	var expendable: Vector2i = _h._add(token, [X + 2048, FLOOR_Y, Z, X + 3072, FLOOR_Y + 1024, Z + 1024], Space.DRY_SOLID, _h._world)
	_commit_geometry(token)
	var job: int = _h._start(Contract.OP_BRACE)
	_h._finish_work(job)
	var before: PackedByteArray = _h._owner.state_bytes()
	var inventory: PackedByteArray = _h._inventory.state_bytes()
	var failed: Construction.OpResult = _h._sites.settle_phase(_h._site)
	assert_false(failed.ok, "actual region exhaustion refuses")
	assert_true(_h._owner.state_bytes() == before, "partial SUPPORT additions abort")
	assert_true(_h._inventory.state_bytes() == inventory, "paid materials unchanged")
	assert_false(_h._sites.installed_support(_h._site), "paid completion not published early")
	token = _h._owner.begin_stage(_h._owner.revision()).token
	assert_equal(_h._owner.stage_remove(token, expendable), &"", "explicit fixture frees one unrelated row")
	_commit_geometry(token)
	assert_true(_h._sites.settle_phase(_h._site).ok, "same completed work retries")
	assert_true(_h._sites.installed_support(_h._site), "one actual paid support account")
	assert_equal(_h._sites.support_conservation_refusal(), &"", "no second input or salvage account")


func test_prepared_claim_removal_refuses_without_reinterpreting_floor_envelope_as_footprint() -> void:
	"""The exact accepted claim must survive sealed publication; a larger metadata rectangle cannot replace it."""
	_h._complete(Contract.OP_BRACE)
	_h._open(Contract.OP_CUT)
	var handles: PackedInt32Array = _row_handles(Space.OBSTACLE)
	var before: PackedByteArray = _h._owner.state_bytes()
	var cold: int = _scope(Contract.OP_CUT, Contract.STAGE_START)
	var token: int = _h._owner.begin_stage(_h._owner.revision()).token
	assert_equal(_h._owner.stage_remove(token, Vector2i(handles[0], handles[1])), &"", "fixture deletes exact shape strip")
	assert_equal(_h._owner.seal(token), &"", "remaining generic geometry is still valid")
	assert_equal(_h.structure.prepared_refusal(token, _h._site, Contract.OP_CUT, Contract.STAGE_START, _h._room, cold),
		Structure.REFUSE_CLAIM, "exact claim is required in the sealed future")
	_h._owner.abort(token)
	_h._bindings.end_cold_operation(cold)
	assert_true(_h._owner.state_bytes() == before, "failed candidate preserves actual painted shape")


func test_content_and_actual_world_retirement_refuse_rebinding_or_publication() -> void:
	"""A once-configured provider cannot outlive its actual terrain World or substitute another catalog."""
	var unbound_levels: Levels = Levels.new()
	assert_false(_h.structure.is_bound_to(_h._owner, _h.terrain, unbound_levels, _h._sites, _h.budget), "exact actual content owner")
	assert_equal(_h.structure.configure(_h.scope, _h._owner, _h.terrain, _h.levels, _h._sites, _h.budget), Structure.REFUSE_BINDING, "once-bound provider")
	var cold: int = _scope(Contract.OP_BRACE, Contract.STAGE_ADMIT)
	_h.world_map.clear()
	assert_false(_h.structure.is_bound_to(_h._owner, _h.terrain, _h.levels, _h._sites, _h.budget), "actual World lifetime")
	assert_true(_h.structure.structure_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT, _h._room, cold) != &"", "retired natural content refuses")
	assert_equal(_h.structure.handles_before_drop, 0, "no image allocated for expired World")
	_h._bindings.end_cold_operation(cold)


func test_direct_start_or_commit_requires_current_actual_paid_work_phase() -> void:
	"""A matching scoped operation cannot restart working inputs or publish unfinished work."""
	var job: int = _h._start(Contract.OP_BRACE)
	var cold: int = _scope(Contract.OP_BRACE, Contract.STAGE_START)
	assert_equal(_h.structure.structure_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_START, _h._room, cold),
		Structure.REFUSE_SCOPE, "funded phase is no longer READY")
	_h._bindings.end_cold_operation(cold)
	cold = _scope(Contract.OP_BRACE, Contract.STAGE_COMMIT)
	assert_equal(_h.structure.structure_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_COMMIT, _h._room, cold),
		Structure.REFUSE_SCOPE, "actual work has not completed")
	_h._bindings.end_cold_operation(cold)
	_h._finish_work(job)
	assert_true(_h._sites.settle_phase(_h._site).ok, "real completed work still commits once")


func test_bad_token_mode_or_capacity_refuses_before_allocating_scope_identity_callback() -> void:
	"""Actual Scope may allocate a bounded Level identity packet, so its very first call needs admission."""
	var calls: int = _h.scope.exact_reads
	assert_equal(_h.structure.structure_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT, _h._room, 123456),
		Structure.REFUSE_COLD, "unissued lease")
	assert_equal(_h.scope.exact_reads, calls, "no allocating exact-binding callback for invalid token")
	var cold: int = _scope(Contract.OP_BRACE, Contract.STAGE_ADMIT)
	assert_equal(_h.structure._run(999, 0, _h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT, _h._room, cold),
		Structure.REFUSE_SCOPE, "unrecognized lifetime")
	assert_equal(_h.scope.exact_reads, calls, "mode rejected before callback")
	_h.structure._capacity = Budget.REGION_CAPACITY + 1
	assert_equal(_h.structure.structure_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT, _h._room, cold),
		Structure.REFUSE_COLD, "over-budget configured count corruption")
	assert_equal(_h.scope.exact_reads, calls, "capacity rejected before callback")
	_h.structure._capacity = Budget.REGION_CAPACITY
	_h._bindings.end_cold_operation(cold)
	assert_equal(_h.structure.structure_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT, _h._room, cold),
		Structure.REFUSE_COLD, "closed token")
	assert_equal(_h.scope.exact_reads, calls, "closed token rejected before callback")


func test_scope_lifetime_is_borrowed_for_complete_run_then_expires_without_a_cycle() -> void:
	"""A callback may release its external keeper; the active run must not dereference an expired weak Scope."""
	var cold: int = _scope(Contract.OP_BRACE, Contract.STAGE_ADMIT)
	var weak_scope: WeakRef = weakref(_h.scope)
	var keepers: Array[Structure.Scope] = [_h.scope]
	_h.scope.release_keepers = keepers
	_h.scope = null
	(_h._bindings as StructuralBindings).scope = null
	assert_equal(_h.structure.structure_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT, _h._room, cold),
		&"", "active run holds exact configured Scope through every later callback")
	assert_true(keepers.is_empty(), "first callback released the last external keeper")
	assert_null(weak_scope.get_ref(), "run borrows do not form a permanent cycle")
	assert_null(_h.structure.scope_owner(), "expired configured scope becomes unavailable")
	_h._bindings.end_cold_operation(cold)
