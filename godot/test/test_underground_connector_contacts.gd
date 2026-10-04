extends "res://test/framework/test_case.gd"
## Actual immutable/live stores and paid adapter. Test source motion and prospective geometry are explicitly synthetic.

const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const ConnectorWork := preload("res://scripts/core/underground_connector_work.gd")
const EntryTests := preload("res://test/test_underground_entry_placements.gd")
const PaidTests := preload("res://test/test_underground_connector_work.gd")
const PlacementTests := preload("res://test/test_underground_connector_placements.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const WorldTests := preload("res://test/test_underground_world_routes.gd")
const GroupTests := preload("res://test/test_underground_connector_assemblies.gd")
const CatalogTests := preload("res://test/test_underground_connector_catalog.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const EntrySource := preload("res://scripts/core/underground_entry_frontier.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const PhaseContract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const SOURCE_PATH: String = "user://test-actual-connector-contacts-frontier.bin"
const SOURCE_REVISION: int = 29
const ROOT_X: int = -3584
const ROOT_Z: int = 512

class Content extends RefCounted:
	## Source flags below qualify only this component fixture, never supplied rig/content or a playable entrance.

	static func profile_image(identity: PackedInt32Array) -> PackedByteArray:
		"""Four explicit generic-tool WORK headings and an equipped-tool WALK row feed actual source decoders."""
		var source: PackedByteArray = CatalogTests.synthetic_profile_image(identity, 2)
		var bytes: PackedByteArray = source.slice(0, 64 + Profiles.PROFILE_WIRE_BYTES)
		bytes.encode_u32(20, 6)
		bytes.encode_u32(24, 34)
		bytes.encode_s32(64 + Profiles.F_TOOL * 4, 54)
		bytes.encode_s32(64 + Profiles.F_TOOL_VARIANT * 4, Gear.MANUFACTURE_BASIC)
		for rotation: int in 4:
			_append_work(bytes, identity, rotation)
		var climb: PackedByteArray = source.slice(64 + Profiles.PROFILE_WIRE_BYTES, 64 + 2 * Profiles.PROFILE_WIRE_BYTES)
		climb.encode_s32(Profiles.F_FIRST_BOX * 4, 31)
		bytes.append_array(climb)
		var boxes: int = 64 + 2 * Profiles.PROFILE_WIRE_BYTES
		bytes.append_array(source.slice(boxes, boxes + 3 * 28))
		for rotation: int in 4:
			for role: int in 7:
				var box: PackedInt32Array = _rotate(_work_box(role), rotation)
				box.append(role)
				CatalogTests._append_row(bytes, box)
		bytes.append_array(source.slice(boxes + 3 * 28, source.size() - 8))
		bytes.append_array("UGPEND01".to_ascii_buffer())
		return bytes

	static func _append_work(bytes: PackedByteArray, identity: PackedInt32Array, rotation: int) -> void:
		"""The actual current equipment/Job query must match exact item54/basic, BUILD and selected world heading."""
		CatalogTests._append_row(bytes, PackedInt32Array([0, identity[0], identity[1], identity[2],
			Profiles.MODE_WORK, 0, 54, Gear.MANUFACTURE_BASIC, -1, -1, Profiles.YAW_EXACT,
			((4 - rotation) * 16384) % 65536, 31, 511, 3 + 7 * rotation, 7,
			Jobs.JOB_KIND_BUILD, Profiles.CONTACT_ANCHOR_AND_PATCH]), 1)
		bytes.resize(bytes.size() + 18)
		bytes[bytes.size() - 2] = Profiles.CERT_REQUIRED

	static func _work_box(role: int) -> PackedInt32Array:
		"""Only the productive tool box reaches retained earth; approach and recovery stay in completed air."""
		match role:
			Profiles.STANCE_SUPPORT: return PackedInt32Array([-128, -1, -128, 128, 0, 128])
			Profiles.WORK_STROKE: return PackedInt32Array([-16, -32, -224, 16, 300, -128])
			Profiles.CONTACT_POINT: return PackedInt32Array([0, 0, -192, 0, 0, -192])
			Profiles.CONTACT_PATCH: return PackedInt32Array([-8, 0, -208, 8, 0, -176])
		return PackedInt32Array([-128, -1, -128, 128, 900, 128])

	static func _rotate(source: PackedInt32Array, rotation: int) -> PackedInt32Array:
		"""Independent quarter-turn source geometry preserves planar contact and negative foot residual."""
		var out: PackedInt32Array = source.duplicate()
		for step: int in rotation:
			var lo: int = out[0]; var hi: int = out[3]
			out[0] = -out[5]; out[3] = -out[2]
			out[2] = lo; out[5] = hi
		return out

class PhaseContent extends RefCounted:
	## Explicit synthetic motion: full body/contact validation is real; this is no production digging certificate.

	static func profile_image(identity: PackedInt32Array) -> PackedByteArray:
		"""The test root stays on completed natural ground, outside its genuinely claimed whole paid cube."""
		var bytes: PackedByteArray = Content.profile_image(identity)
		for rotation: int in 4:
			for role: int in [Profiles.WORK_STROKE, Profiles.CONTACT_POINT, Profiles.CONTACT_PATCH]:
				var row: PackedInt32Array = PackedInt32Array([-16, -32, -688, 16, 0, -592])
				if role == Profiles.CONTACT_POINT: row = PackedInt32Array([0, 0, -640, 0, 0, -640])
				if role == Profiles.CONTACT_PATCH: row = PackedInt32Array([-8, 0, -656, 8, 0, -624])
				row = Content._rotate(row, rotation)
				var at: int = 64 + 6 * Profiles.PROFILE_WIRE_BYTES + (3 + 7 * rotation + role) * 28
				for field: int in 6: bytes.encode_s32(at + field * 4, row[field])
		return bytes

class ObservedTransforms extends Transforms:
	var probe: Callable = Callable()
	var gate: Callable = Callable()
	var probe_count: int = 0

	func read_into(ref: Vector2i, out: Pose) -> bool:
		"""Return a genuine copied pose, then let a negative observer mutate the actual placed row."""
		var accepted: bool = super.read_into(ref, out)
		if accepted and probe.is_valid() and (not gate.is_valid() or gate.call()):
			var pending: Callable = probe
			probe = Callable()
			probe_count += 1
			pending.call()
		return accepted

class ActualWorld extends EntryTests.Fixture:
	var reverse_edge: Vector2i = NULL_REF
	var two_parts: bool = false
	var phase_source: bool = false

	func _actual_profiles() -> void:
		"""Keep all actual runtime owners and replace only the explicitly synthetic immutable source image."""
		var pose: Transforms.Pose = Transforms.Pose.new()
		assert_true(_transforms.read_into(_worker, pose), "original actual bootstrap pose")
		_transforms = ObservedTransforms.new(_residents.directory())
		assert_true(_transforms.place(_worker, pose.x, pose.y, pose.z, pose.yaw), "actual observed store before any binding")
		super._actual_profiles()
		var identity: PackedInt32Array = PackedInt32Array([0, 0, 0])
		assert_true(_residents.spatial_profile_identity_into(_worker, identity), "actual resident identity")
		var bytes: PackedByteArray = PhaseContent.profile_image(identity) if phase_source else Content.profile_image(identity)
		assert_equal(_profiles.load_file(WorldTests.PROFILE_TEMP, _write(WorldTests.PROFILE_TEMP, bytes), 2), &"", "actual source decoder")

	func _load_catalog(revision: int) -> StringName:
		"""The unchanged actual variant pins the exact newly loaded profile source revision."""
		var bytes: PackedByteArray = CatalogTests.synthetic_image(revision, 2)
		if two_parts:
			bytes = GroupTests._catalog_wire(2, revision)
			bytes.encode_s64(48, 2)
		else:
			bytes.encode_s32(CatalogTests.PACE_BASE + 5 * 36, 5)
		return _catalog.load_file(WorldTests.TEMP, _write(WorldTests.TEMP, bytes), revision)

	func _publish_route() -> Vector2i:
		"""Delivery and retreat use explicitly published directed spans; no reverse path is invented."""
		var token: int = _begin()
		var added: Routes.Result = _routes.stage_add(token, _edge())
		assert_equal(added.error, &"", "real outward span")
		var back: Routes.Edge = _edge()
		back.from_location = _last; back.to_location = _first
		back.points = PackedInt32Array([WorldTests.X + 1536, 512, WorldTests.Z + 512,
			WorldTests.X + 512, 512, WorldTests.Z + 512])
		var reversed: Routes.Result = _routes.stage_add(token, back)
		assert_equal(reversed.error, &"", "real return span")
		reverse_edge = reversed.ref
		assert_equal(_binding.seal(token), &"", "actual bidirectional certificates")
		assert_equal(_binding.publish(token), &"", "actual bidirectional publication")
		_end(token)
		return added.ref

	func _location(point: Vector3i) -> Vector2i:
		"""WORK and STORAGE endpoints are real finite supported Locations, not caller flags."""
		var row: Locations.Record = Locations.Record.new()
		row.point = point
		row.section = _floor
		row.level = 0
		row.role = Locations.ROLE_WORK if point.x == WorldTests.X + 512 else Locations.ROLE_STORAGE
		row.envelope = PackedInt32Array([point.x - 256, 512, point.z - 256, point.x + 256, 1536, point.z + 256])
		row.support = PackedInt32Array([point.x - 256, 384, point.z - 256, point.x + 256, 512, point.z + 256])
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		var token: int = _locations.begin_prepare(cold).token
		var added: Locations.Result = _locations.stage_add(token, row)
		assert_equal(added.error, &"", "actual supported endpoint")
		assert_equal(_locations.seal(token), &"", "actual endpoint proof")
		assert_true(_locations.publish(token), "real endpoint publication")
		assert_equal(_budget.release(cold), &"", "endpoint scratch released")
		return added.location

class InstallationAuthority extends EntryTests.Frontier:
	## Only physical installation staging is synthetic; actual Contacts and every accounting owner are exercised.
	var exact_part: bool = false

	func installation_cold_bytes(_placement: Vector2i, _assembly: int) -> int:
		"""Real companion snapshots use their actual shared arena and original lease."""
		return Budget.COLD_BYTES

	func stage_installation(_placement: Vector2i, _project: Vector2i, _assembly: int, token: int, _cold: int) -> StringName:
		"""Publish one explicit paid test support fact, with the lasting actual Corridor source."""
		var f: ActualWorld = fixture.get_ref() as ActualWorld
		var row: Owner.Region = Owner.Region.new()
		row.owner = f.corridor
		row.section = f.corridor_floor
		row.level = 0
		row.role = Space.SUPPORT
		row.box = PackedInt32Array([WorldTests.X + 4096, 256, WorldTests.Z,
			WorldTests.X + 5120, 512, WorldTests.Z + 1024])
		if exact_part:
			row.box = PackedInt32Array([WorldTests.X + 3840, 384, WorldTests.Z - 1024,
				WorldTests.X + 4352, 512, WorldTests.Z])
		return f._owner.stage_add(token, row).error

	func stage_locations(_placement: Vector2i, _project: Vector2i, _assembly: int, token: int, _cold: int) -> StringName:
		"""The actual live endpoints both requalify; no new route or entrance endpoint appears."""
		var f: ActualWorld = fixture.get_ref() as ActualWorld
		var code: StringName = f._locations.stage_refresh(token, f._first)
		return f._locations.stage_refresh(token, f._last) if code == &"" else code

	func stage_routes(_placement: Vector2i, _project: Vector2i, _assembly: int, token: int, _cold: int) -> StringName:
		"""Refresh the real previously published graph edge and its actual derived profile mask."""
		return _refresh_routes(token)

	func refresh_admission_routes(_placement: Vector2i, token: int, _cold: int) -> StringName:
		"""Initial Room confirmation preserves both already-complete directions without inventing a path."""
		return _refresh_routes(token)

	func _refresh_routes(token: int) -> StringName:
		"""Both directed spans must pass the actual current source and geometry certificate builder."""
		var f: ActualWorld = fixture.get_ref() as ActualWorld
		var code: StringName = f._routes.stage_refresh(token, edge)
		return f._routes.stage_refresh(token, f.reverse_edge) if code == &"" else code

	func completion_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int, _cold: int) -> StringName:
		"""Test geometry is explicit; this grants no supplied motion or real entry progression certificate."""
		return &""

class SourceObserver extends EntrySource:
	var probe: Callable = Callable()

	func station_into(index: int, out: PackedInt32Array, revision: IntMath.IntResult, rotation: int = 0) -> StringName:
		"""Negative-only source observer retains actual decoded rows and can try reentry or late state changes."""
		var code: StringName = super.station_into(index, out, revision, rotation)
		if probe.is_valid():
			var pending: Callable = probe
			probe = Callable()
			pending.call()
		return code

class ActualContacts extends Contacts:
	## Negative-only observer; every physical decision and final leaf remains the actual implementation.
	var final_probe: Callable = Callable()
	var final_active: bool = false
	var observation_active: bool = false

	func final_observation_refusal(p: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
		"""A last successful callback must not let a changed actual worker, source or endpoint spend payment."""
		observation_active = true
		var code: StringName = super.final_observation_refusal(p, project, assembly, action)
		observation_active = false
		if final_probe.is_valid():
			var pending: Callable = final_probe
			final_probe = Callable()
			pending.call()
		return code

	func final_leaf_refusal(p: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
		"""Expose only the actual final phase to a negative reader; no permission result is altered."""
		final_active = true
		var code: StringName = super.final_leaf_refusal(p, project, assembly, action)
		final_active = false
		return code

class ContactFixture extends "res://test/framework/test_case.gd":
	var assembly_count: int = 1
	var _f: ActualWorld = null
	var _group: GroupTests = null
	var _placements: Placements = null
	var _frontier: InstallationAuthority = null
	var _edge: Vector2i = NULL_REF
	var _physical: EntryTests.PhysicalBinding = null
	var _sites: Sites = null
	var _router: Router = null
	var _orders: Orders = null
	var _bindings: EntryTests.Binding = null
	var source: SourceObserver = null
	var contacts: Contacts = null
	var paid: ConnectorWork = null
	var storage: Vector2i = NULL_REF
	var tool: Vector2i = NULL_REF
	var placement: Vector2i = NULL_REF
	var project: Vector2i = NULL_REF
	var job: Vector2i = NULL_REF
	var math: IntMath.IntResult = IntMath.IntResult.new()
	var storage_binding: Locations.InventoryLocations = null

	func before_each() -> void:
		"""Confirm actual permanent Room, SOLID keys and source-pinned Placement before any paid installation."""
		_f = _make_world()
		_f.two_parts = assembly_count == 2
		_f._actual_fixture()
		_edge = _f._publish_route()
		_group = GroupTests.new()
		_group._catalog = _f._catalog; _group._items = _f._items; _group._inventory = _f._inventory
		_group._bind_source(_group._group_wire(assembly_count, 1),
			PackedInt32Array([0, 1]) if assembly_count == 2 else PackedInt32Array([0]), false, 4)
		assert_equal(_group._load_source(), &"", "actual complete grouping and recipe")
		_bind_placement()
		_bind_orders()
		_load_source()
		contacts = ActualContacts.new()
		assert_equal(contacts.configure(_placements, _router, source, Contacts.CONTROL_BYTES), &"", "actual Contacts composition")
		paid = ConnectorWork.new()
		assert_equal(paid.configure(_placements, _router, contacts), &"", "actual reciprocal paid owner")
		_confirm_and_bind_storage()
		assert_true(_f.failures.is_empty() and _group.failures.is_empty(), "all actual fixture assertions")

	func _make_world() -> ActualWorld:
		"""The default source stays unchanged; phase tests replace only explicitly synthetic motion content."""
		return ActualWorld.new()

	func _confirm_and_bind_storage() -> void:
		"""Use actual atomic confirmation before binding the genuine supported finite storage endpoint."""
		var plan: EntryPlan.Request = _plan()
		plan.frontier_revision = SOURCE_REVISION
		for index: int in 32:
			plan.source_digests[96 + index] = source._digests[index]
		var confirmed: Buildings.OpResult = _orders.confirm_entry(plan)
		assert_true(confirmed.ok, "real atomic entry confirmation: %s" % confirmed.error)
		placement = _bindings.published
		_f.corridor = confirmed.ref; _f.corridor_floor = _bindings.published_section
		storage_binding = Locations.InventoryLocations.new(_f._locations)
		assert_true(_f._inventory.bind_spatial_locations(storage_binding, 4).ok, "actual Inventory endpoint adapter")
		storage = _f._inventory.create_spatial_ground_staging(_f._last).ref
		assert_true(storage != NULL_REF, "real finite material endpoint")

	func _bind_placement() -> void:
		"""One actual source and durable owner; future physical permission remains labelled synthetic."""
		_placements = Placements.new()
		assert_equal(_placements.configure(4, 8, Placements.required_bytes(4, 8)), &"", "finite actual Placement")
		assert_equal(_placements.bind_actual(_f._owner, _f._locations, _f._routes, _f._budget,
			_f._catalog, _group._reader, _group._recipes, _f._construction), &"", "exact source/store owners")
		_frontier = InstallationAuthority.new()
		_frontier.exact_part = assembly_count == 2
		_frontier.fixture = weakref(_f); _frontier.placements = weakref(_placements); _frontier.edge = _edge
		assert_equal(_placements.bind_authority(_frontier), &"", "synthetic installation geometry authority")

	func _make_physical() -> EntryTests.PhysicalBinding:
		"""Existing installation tests retain the same explicitly synthetic phase geometry provider."""
		return EntryTests.PhysicalBinding.new()

	func _bind_orders() -> void:
		"""The sole real Room authority owns the future candidate, immutable Domain and original whole cold lease."""
		var physical: EntryTests.PhysicalBinding = _make_physical()
		physical.space = _f._owner
		_physical = physical
		_physical.world = _f._world_ref
		_sites = Sites.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _physical, 64, 8)
		assert_equal(_sites.initialization_refusal(), &"", "actual physical Site/Funding owner")
		_router = Router.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _sites)
		assert_equal(_router.initialization_refusal(), &"", "actual shared Router")
		_orders = Orders.new()
		_bindings = EntryTests.Binding.new()
		_bindings.arena = _f._budget
		_bindings.construction = _f._construction
		_bindings.space = _f._owner
		_bindings.world = _f._world_ref
		_bindings.inventory = _f._inventory
		_bindings.orders = weakref(_orders)
		_bindings.placements = _placements
		_bindings.source = _f._sources as PlacementTests.ObservedSources
		assert_equal(_orders.configure(_router, _f._owner, _f._sources, RoomCatalog.new(), _bindings), &"", "actual RoomOrders")
		assert_equal(_f._locations.bind_room_orders(_orders), &"", "exact actual Room companion scope")

	func _plan(offset: int = 4096) -> EntryPlan.Request:
		"""A genuine source-pinned request uses synthetic non-flat excavation claims, not physical permission."""
		var result: EntryPlan.Request = EntryPlan.Request.new()
		result.world = _f._world_ref
		result.space_revision = _f._owner.revision()
		result.base_level = 0
		result.origin_u = Vector3i(WorldTests.X + offset, 512, WorldTests.Z)
		result.rotation = 0
		result.anchor = _f._first
		result.catalog_row = _placements._live.header[Placements.H_CATALOG_ROW]
		result.catalog_revision = _placements._live.header[Placements.H_CATALOG_REV]
		result.variant_revision = _placements._live.header[Placements.H_VARIANT_REV]
		result.grouping_revision = _placements._live.header[Placements.H_GROUP_REV]
		result.recipe_revision = _placements._live.header[Placements.H_RECIPE_REV]
		result.frontier_revision = 1
		result.source_digests = _placements._live.digests.duplicate()
		for index: int in 32:
			result.source_digests[96 + index] = 19
		result.claims = PackedInt32Array([result.origin_u.x, -512, result.origin_u.z,
			result.origin_u.x + 1024, 1536, result.origin_u.z + 1024])
		if assembly_count == 2:
			result.claims[0] -= 1024
			result.claims[2] -= 1024
		for ordinal: int in _placements._opening_count():
			result.opening_targets.append_array(PackedInt32Array([-1, 0, -1, 0]))
		return result

	func _load_source() -> void:
		"""Use the actual bounded immutable loader, with a unique test input rather than private bank injection."""
		source = SourceObserver.new()
		var capacities: PackedInt32Array = PackedInt32Array([assembly_count, 1, 1, assembly_count, 2, 1])
		assert_equal(source.configure(capacities, EntrySource.required_bytes(capacities)), &"", "exact source envelope")
		assert_equal(source.bind_actual(_f._catalog, _group._reader, _group._recipes, _f._profiles), &"", "actual source tuple")
		var bytes: PackedByteArray = _source_image()
		assert_equal(source.load_file(SOURCE_PATH, CatalogTests._write(SOURCE_PATH, bytes), SOURCE_REVISION), &"", "real frontier decoder")

	func _source_image() -> PackedByteArray:
		"""A single wood assembly has real preexisting approach/bearing and a separate exact claimed SOLID prerequisite."""
		var bytes: PackedByteArray = _source_header()
		CatalogTests._append_row(bytes, PackedInt32Array([0, 0, 0, 0, 1, 0, 1, 1, 0]))
		if assembly_count == 2:
			CatalogTests._append_row(bytes, PackedInt32Array([1, 0, 0, 0, 1, 1, 1, 1, 0]))
		CatalogTests._append_row(bytes, PackedInt32Array([0, ROOT_X, 0, ROOT_Z, 0, 1, 0, 3, Jobs.JOB_KIND_BUILD]), 1)
		for rotation: int in range(1, 4): CatalogTests._append_row(bytes, PackedInt32Array([rotation + 1]), 1)
		CatalogTests._append_row(bytes, PackedInt32Array([0, -1024, 0, 1024, 0, 1024, Sites.SOLID]))
		CatalogTests._append_row(bytes, PackedInt32Array([EntrySource.NATURAL, -1, -1,
			ROOT_X - 32, -64, ROOT_Z - 256, ROOT_X + 32, 0, ROOT_Z - 96]))
		if assembly_count == 2:
			CatalogTests._append_row(bytes, PackedInt32Array([EntrySource.INSTALLED_PART, 0, 0,
				-128, -64, -768, 128, 0, -512]))
		CatalogTests._append_row(bytes, PackedInt32Array([EntrySource.SURFACE_ANCHOR, -1, 0, Locations.ROLE_WORK, ROOT_X, 0, ROOT_Z, 0]), 1)
		CatalogTests._append_row(bytes, PackedInt32Array([EntrySource.SURFACE_CONTACT, -1, 0, Locations.ROLE_STORAGE, ROOT_X + 1024, 0, ROOT_Z, 0]), 1)
		CatalogTests._append_row(bytes, PackedInt32Array([0, -1024, 0, 1024, 0, 1024, 7, 0,
			0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 3]))
		bytes.append_array("UGFEND01".to_ascii_buffer())
		return bytes

	func _source_header() -> PackedByteArray:
		"""The independent wire pins all six counts and actual immutable source digests."""
		var bytes: PackedByteArray = "UGFRNT01".to_ascii_buffer(); bytes.resize(EntrySource.WIRE_HEADER_BYTES)
		bytes.encode_u32(8, 1)
		var revisions: PackedInt64Array = PackedInt64Array([SOURCE_REVISION, 1, 1, GroupTests.GROUP_REVISION, GroupTests.RECIPE_REVISION, 2])
		for index: int in 6: bytes.encode_s64(12 + 8 * index, revisions[index])
		for table: int in 6:
			bytes.encode_u32(68 + 4 * table, 2 if table == EntrySource.ENDPOINT else
				assembly_count if table == EntrySource.INSTALL or table == EntrySource.BEARING else 1)
		for index: int in 32:
			bytes[92 + index] = _group._reader._digests[32 + index]
			bytes[124 + index] = _group._reader._digests[index]
			bytes[156 + index] = _group._reader._digests[64 + index]
			bytes[188 + index] = 7
		return bytes

	func open_order() -> Vector2i:
		"""Only actual contact proof may create the real purpose8 Project and attach it to the next prefix."""
		var result: Construction.OpResult = _router.open_order(paid, placement, 0)
		assert_true(result.ok, "actual contact-gated order: %s" % result.error)
		project = result.ref
		return project

	func assign_worker() -> void:
		"""Actual resident assignment, equipped claimed tool and committed exact WORK actor precede earning labor."""
		var row: int = _f._residents.directory().get_typed_row(_f._worker)
		assert_true(_f._jobs.priorities().spawn(row).ok, "actual priorities")
		assert_true(_f._jobs.schedule().spawn(row, _f._jobs.schedule().default_template_id().value).ok, "actual schedule")
		assert_true(_f._jobs.schedule().resolve(row, 8, false).ok and _f._jobs.spawn_agent(row).ok, "actual work readiness")
		for need: int in Needs.NEED_COUNT:
			var value: int = _f._residents.needs().need_of(row, need).value
			assert_true(_f._residents.needs().apply_need_event(row, need, 5000 - value).ok, "ordinary actual mood")
		tool = stock(&"tool", 1000)
		assert_true(_f._gear.create_gear(_f._inventory, _f._items, tool, Gear.MANUFACTURE_BASIC).ok, "real durable tool")
		assert_true(_f._gear.equip(tool, _f._worker).ok, "real equipment")
		var quote: Contract.Quote = Contract.Quote.new()
		assert_equal(_router.project_facts_into(project, quote), &"", "actual wood-only bill")
		var made: Jobs.OpResult = _f._jobs.create_job(quote.job_kind, 1, 0, quote.remaining_mwu, 0)
		job = made.ref
		assert_true(made.ok and _f._jobs.set_requester(made.value, project).ok, "actual requested Job")
		assert_true(_f._jobs.set_tool_gate(made.value, Jobs.GATE_SATISFIED).ok and _router.bind_job(project, job).ok, "actual Job mapping")
		assert_true(_f._jobs.assign_worker(row, made.value).ok and _f._work.claim_tool_for_work(row, tool).ok, "actual worker/tool claim")
		assert_true(_f._transforms.place(_f._worker, WorldTests.X + 512, 512, WorldTests.Z + 512, 0), "exact source root")
		assert_equal(_f._routes.admit_work_actor(_f._worker, job, _f._first, 1, 1, 2, 0, -1, tool), &"", "actual exact WORK actor")

	func stock(key: StringName, quantity: int) -> Vector2i:
		"""Actual finite spatial Inventory receives ordinary source catalogue goods."""
		var made: Inventory.OpResult = _f._inventory.create_lot(storage, _f._items.compiled_id(key), quantity,
			1, Catalog.PROVENANCE_ORDINARY, -1, 0, 0)
		assert_true(made.ok, "actual stock: %s" % made.error)
		return made.ref

	func deliver() -> Vector2i:
		"""Actual stock claims and Construction delivery credits precede payment; no synthetic receipt is created."""
		var quote: Contract.Quote = Contract.Quote.new()
		assert_equal(_router.project_facts_into(project, quote), &"", "one immutable bill")
		var bound: Construction.OpResult = _router.bind_material_container(project, storage)
		assert_true(bound.ok, "actual selected storage: %s" % bound.error)
		var lot: Vector2i = stock(quote.input_keys[0], quote.input_milli[0])
		var claims: PackedInt64Array = PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_MODULAR_INPUT, quote.input_milli[0], 1000])
		assert_true(_f._pool.claim_batch(job, claims, 1, _f._inventory).ok, "real wood reservation")
		var result: Construction.OpResult = _router.record_deliveries(project)
		assert_true(result.ok, "actual delivery: %s" % result.error)
		return lot

	func start() -> Construction.OpResult:
		"""The real guarded shared settlement consumes actual wood and begins Construction only once."""
		return _router.start_work(project, 100)

	func finish_work() -> void:
		"""Only actual fixed Work ticks change remaining work, XP and tool wear."""
		for tick: int in 1000:
			_f._construction.remaining_mwu_into(project, math)
			if math.value == 0: return
			var result: Work.TickResult = _f._work.tick_solo(_f._residents.directory().get_typed_row(job))
			assert_true(result.ok, "actual labor: %s" % result.error)
			if not result.ok: return
		fail("actual work exceeded bounded test loop")

	func _cleanup_owners() -> void:
		"""Every failure leaves original scratch unowned; propagate inherited real fixture assertions and leaks."""
		assert_true(_f._budget.is_quiescent(), "no lease escaped actual RoomOrders cleanup")
		assert_equal(_placements._cold_token, 0, "no retained Placement operation")
		_bindings = null
		_orders = null
		_router = null
		_sites = null
		_physical = null
		_frontier = null
		_placements = null
		_group._reader = null
		_group._recipes = null
		_group._catalog = null
		_group._items = null
		_group._inventory = null
		_group = null
		_f.after_each()
		assert_true(_f.failures.is_empty(), "actual fixture helpers: %s" % _f.failures)
		_f = null
		for path: String in [GroupTests.GROUP_PATH, GroupTests.RECIPE_PATH, GroupTests.CATALOG_PATH]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	func after_each() -> void:
		"""Clear only local probes and current owned scratch, then run the inherited actual owner cleanup."""
		if source != null: source.probe = Callable()
		if contacts != null: (contacts as ActualContacts).final_probe = Callable()
		(_f._transforms as ObservedTransforms).probe = Callable()
		(_f._transforms as ObservedTransforms).gate = Callable()
		_f._terrain.binding_probe = Callable()
		_f._inventory.set_seed_expiry_authority(null)
		if paid != null and paid._stage_action >= 0:
			paid.discard_transition(paid._stage_project, paid._stage_action)
		assert_true(_f._inventory.audit().ok and _f._pool.audit(_f._inventory).ok, "actual conservation audits")
		paid = null; contacts = null; source = null; storage_binding = null
		_cleanup_owners()
		if FileAccess.file_exists(SOURCE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SOURCE_PATH))

class PhaseSpatialFixture extends EntryTests.PhysicalBinding:
	## Only the inherited phase geometry/publication is synthetic, explicitly limited to this contact unit fixture.
	var ids: Directory = null

	func room_refusal(room: Vector2i) -> StringName:
		"""Real created Room full identity replaces the old standalone economy fixture's invented70000 namespace."""
		return &"" if ids != null and ids.is_valid_of_kind(room, Directory.KIND_ROOM) else &"TEST_PHASE_ROOM_STALE"

	func final_start_leaf_refusal(_origin: Vector3i, _operation: int, room: Vector2i) -> StringName:
		"""Synthetic geometry retains its real created Room generation through the actual guarded Sites START."""
		if start_leaf_block != &"": return start_leaf_block
		if pending_stage != PhaseContract.STAGE_START or ids == null \
				or not ids.is_valid_of_kind(room, Directory.KIND_ROOM): return &"SYNTHETIC_START_STALE"
		if block_operation != &"": return block_operation
		return block_worker if block_worker != &"" else block_output

	func final_settlement_leaf_refusal(_origin: Vector3i, _operation: int,
			stage: int, room: Vector2i) -> StringName:
		"""The same actual full Room survives worker-free settlement; no generation1 fixture assumption is retained."""
		if pending_stage != stage or ids == null \
				or not ids.is_valid_of_kind(room, Directory.KIND_ROOM): return &"SYNTHETIC_SETTLEMENT_STALE"
		return block_operation

class PhaseFixture extends ContactFixture:
	## Actual Sites/accounting and actual Contacts; inherited geometry authority is explicitly synthetic in this unit fixture.

	func _make_world() -> ActualWorld:
		"""No observer fabricates a resident, current pose, Job or Site; only source motion is synthetic."""
		var world: ActualWorld = ActualWorld.new()
		world.phase_source = true
		return world

	func _make_physical() -> EntryTests.PhysicalBinding:
		"""Only component-test phase geometry remains synthetic; Room, Site, Project, Job and all payments are actual."""
		var physical: PhaseSpatialFixture = PhaseSpatialFixture.new()
		physical.ids = _f._residents.directory()
		return physical

	func _plan(offset: int = 4096) -> EntryPlan.Request:
		"""The exact real future claim is outside all preexisting surface support and the worker's root."""
		var request: EntryPlan.Request = super._plan(offset)
		request.claims = PackedInt32Array([WorldTests.X, -512, WorldTests.Z - 1024,
			WorldTests.X + 1024, 512, WorldTests.Z])
		return request

	func _source_image() -> PackedByteArray:
		"""The independent source wire selects the same exact cube and no invented completed-cut dependency."""
		var bytes: PackedByteArray = super._source_image()
		var cut: int = EntrySource.WIRE_HEADER_BYTES + EntrySource.wire_row_bytes(EntrySource.INSTALL) \
			+ EntrySource.wire_row_bytes(EntrySource.STATION)
		var episode: int = cut + EntrySource.wire_row_bytes(EntrySource.CUT) \
			+ EntrySource.wire_row_bytes(EntrySource.BEARING) + 2 * EntrySource.wire_row_bytes(EntrySource.ENDPOINT)
		var bounds: PackedInt32Array = PackedInt32Array([-4096, -1024, -1024, -3072, 0, 0])
		for field: int in 6:
			bytes.encode_s32(cut + 4 * field, bounds[field])
			bytes.encode_s32(episode + 4 * field, bounds[field])
		return bytes

	func site() -> Vector2i:
		"""Read the actual claim published by RoomOrders; never create or seed a physical Site."""
		return _sites.site_at(Vector3i(WorldTests.X, -512, WorldTests.Z - 1024))

	func open_phase(operation: int = PhaseContract.OP_BRACE) -> void:
		"""Actual Construction owns the phase Project; Placement continues to own no active INSTALL Project."""
		var opened: Construction.OpResult = _sites.open_phase(site(), operation)
		assert_true(opened.ok, "real claimed phase Project: %s" % opened.error)
		project = opened.ref

	func assign_worker() -> void:
		"""Actual single Site Job/worker/tool is distinct from the real modular Router Job map."""
		var row: int = _f._residents.directory().get_typed_row(_f._worker)
		assert_true(_f._jobs.priorities().spawn(row).ok, "actual priorities")
		assert_true(_f._jobs.schedule().spawn(row, _f._jobs.schedule().default_template_id().value).ok, "actual schedule")
		assert_true(_f._jobs.schedule().resolve(row, 8, false).ok and _f._jobs.spawn_agent(row).ok, "actual agent")
		for need: int in Needs.NEED_COUNT:
			var value: int = _f._residents.needs().need_of(row, need).value
			assert_true(_f._residents.needs().apply_need_event(row, need, 5000 - value).ok, "actual needs")
		tool = stock(&"tool", 1000)
		assert_true(_f._gear.create_gear(_f._inventory, _f._items, tool, Gear.MANUFACTURE_BASIC).ok, "actual tool")
		assert_true(_f._gear.equip(tool, _f._worker).ok, "actual equipment")
		assert_true(_f._construction.remaining_mwu_into(project, math), "real phase work")
		var made: Jobs.OpResult = _f._jobs.create_job(Jobs.JOB_KIND_BUILD, 1, 0, math.value, 0)
		job = made.ref
		assert_true(made.ok and _f._jobs.set_requester(made.value, project).ok, "actual requester")
		assert_true(_f._jobs.set_tool_gate(made.value, Jobs.GATE_SATISFIED).ok and _sites.bind_job(site(), job).ok, "actual Site Job")
		assert_true(_f._jobs.assign_worker(row, made.value).ok and _f._work.claim_tool_for_work(row, tool).ok, "actual assigned tool")
		assert_true(_f._transforms.place(_f._worker, WorldTests.X + 512, 512, WorldTests.Z + 512, 0), "exact root")
		assert_equal(_f._routes.admit_work_actor(_f._worker, job, _f._first, 1, 1, 2, 0, -1, tool), &"", "actual WORK actor")
		assert_true(_sites.bind_worker(site()).ok, "actual Site worker registration")

	func deliver() -> Vector2i:
		"""Exact adopted brace inputs are reserved and credited through the real shared inventory ledger."""
		assert_true(_sites.bind_material_container(site(), storage).ok, "actual material binding")
		var claims: PackedInt64Array = PackedInt64Array()
		var wood: Vector2i = NULL_REF
		for index: int in PhaseContract.input_count(PhaseContract.OP_BRACE):
			var lot: Vector2i = stock(PhaseContract.input_key(PhaseContract.OP_BRACE, index), PhaseContract.input_milli(PhaseContract.OP_BRACE, index))
			if index == 0: wood = lot
			claims.append_array(PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_EXCAVATION_INPUT,
				PhaseContract.input_milli(PhaseContract.OP_BRACE, index), 1000]))
		assert_true(_f._pool.claim_batch(job, claims, 2, _f._inventory).ok, "actual brace claims")
		assert_true(_sites.record_deliveries(site()).ok, "actual brace delivery")
		assert_true(_f._construction.phase_into(project, math), "actual delivered phase read")
		assert_equal(math.value, Construction.PHASE_READY, "all actual delivered lines ready")
		for index: int in 2:
			assert_true(_f._construction.delivered_milli_into(project, index, math), "actual delivered line")
			assert_equal(math.value, 250, "each actual line delivered")
		assert_false(_router._funding.is_funded(project), "no prepayment receipt")
		return wood

	func next_job(operation: int) -> void:
		"""Reuse the actual equipped adult after prior phase retirement, without another setup or free work."""
		open_phase(operation)
		var worker_row: int = _f._residents.directory().get_typed_row(_f._worker)
		assert_true(_f._construction.remaining_mwu_into(project, math), "actual next phase work")
		var made: Jobs.OpResult = _f._jobs.create_job(Jobs.JOB_KIND_BUILD, 1, 0, math.value, 0)
		job = made.ref
		assert_true(made.ok and _f._jobs.set_requester(made.value, project).ok, "actual next requester")
		assert_true(_f._jobs.set_tool_gate(made.value, Jobs.GATE_SATISFIED).ok and _sites.bind_job(site(), job).ok, "next Site Job")
		assert_true(_f._jobs.assign_worker(worker_row, made.value).ok and _f._work.claim_tool_for_work(worker_row, tool).ok, "reclaimed actual tool")
		assert_equal(_f._routes.refresh_work_actor(_f._worker, job, 1, 1, 2, 0, -1, tool), &"", "current actual actor Job")
		assert_true(_sites.bind_worker(site()).ok, "actual next worker registration")

var _fixture: ContactFixture = null


func before_each() -> void:
	"""Each case owns actual finite stores and a newly confirmed permanent Corridor."""
	_fixture = ContactFixture.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "actual bootstrap: %s" % _fixture.failures)


func after_each() -> void:
	"""Inherited setup and actual accounting assertions count in the strict suite."""
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "actual helper checks: %s" % _fixture.failures)
	_fixture = null


func test_actual_source_and_live_contacts_admit_and_pay_one_assembly() -> void:
	"""No synthetic Contacts remains: source rows, whole motion, exact endpoints, actual worker and paid stores all compose."""
	_fixture.open_order()
	_fixture.assign_worker()
	_fixture.deliver()
	var started: Construction.OpResult = _fixture.start()
	assert_true(started.ok, "actual paid START: %s" % started.error)
	if not started.ok: return
	_fixture.finish_work()
	var result: Construction.OpResult = _fixture._router.complete_order(_fixture.project)
	assert_true(result.ok, "actual prepared COMMIT: %s" % result.error)
	var record: Placements.OrderRecord = Placements.OrderRecord.new()
	assert_equal(_fixture._placements.placement_into(_fixture.placement, record), &"", "actual installed identity")
	assert_equal(record.installed_count, 1, "one paid assembly")
	assert_equal(record.project, NULL_REF, "settled actual Project detached")
	assert_true(_fixture._f._budget.is_quiescent(), "no Contact or companion lease retained")


func _unpaid_order() -> void:
	"""All negative paid-boundary tests start with genuine delivered stock and an actual arrived worker."""
	_fixture.open_order()
	_fixture.assign_worker()
	_fixture.deliver()
	assert_true(_fixture.failures.is_empty(), "actual unpaid order setup")


func _paid_order() -> void:
	"""Funding and Construction remain the sole authorities for earned labor and material consumption."""
	_unpaid_order()
	assert_true(_fixture.start().ok, "actual paid start")


func _payment_image() -> Array[PackedByteArray]:
	"""Independent owner state images detect partial payment, claim release or work-credit mutation."""
	return [_fixture._f._inventory.state_bytes(), _fixture._f._pool.state_bytes(),
		_fixture._router._funding.state_bytes(), _fixture._f._work.state_bytes(), _fixture._f._gear.state_bytes(),
		_fixture._f._residents.state_bytes()]


func _assert_payment_unchanged(before: Array[PackedByteArray]) -> void:
	"""A refused observer may change its own fixture fact, but never any paid owner byte."""
	var after: Array[PackedByteArray] = _payment_image()
	for index: int in before.size():
		assert_true(after[index] == before[index], "paid owner %d unchanged" % index)


func _pose(x_offset: int = 0, yaw: int = 0) -> void:
	"""Change the real mirrored Transform without altering the retained graph certificate or source rows."""
	assert_true(_fixture._f._transforms.place(_fixture._f._worker, WorldTests.X + 512 + x_offset,
		512, WorldTests.Z + 512, yaw), "actual current worker pose")


func _inside_final_contact() -> bool:
	"""The negative reader only fires within the actual final contact guard."""
	return (_fixture.contacts as ActualContacts).final_active


func _inside_contact_observation() -> bool:
	"""A genuine actual reader may mutate its owner only before the pure final phase starts."""
	return (_fixture.contacts as ActualContacts).observation_active


func test_final_start_pose_copy_cannot_hide_actual_worker_move() -> void:
	"""A copied old pose followed by real displacement must not settle wood or start work."""
	_unpaid_order()
	var transforms: ObservedTransforms = _fixture._f._transforms as ObservedTransforms
	transforms.gate = _inside_contact_observation
	transforms.probe = func() -> void: _pose(1)
	var before: Array[PackedByteArray] = _payment_image()
	var result: Construction.OpResult = _fixture.start()
	assert_false(result.ok, "actual departed worker cannot start")
	assert_equal(transforms.probe_count, 1, "successful actual reader ran its late mutation")
	_assert_payment_unchanged(before)
	_pose()
	assert_true(_fixture.start().ok, "exact returned worker retries with the same real stock")


func test_final_productive_pose_copy_cannot_hide_actual_worker_move() -> void:
	"""The same successful read cannot earn WU, XP, wear or labor after departing the station."""
	_paid_order()
	var transforms: ObservedTransforms = _fixture._f._transforms as ObservedTransforms
	transforms.probe = func() -> void: _pose(1)
	_fixture.source.probe = func() -> void:
		var copied: Transforms.Pose = Transforms.Pose.new()
		assert_true(transforms.read_into(_fixture._f._worker, copied), "successful late actual source observation")
		assert_equal(copied.x, WorldTests.X + 512, "ordinary observation copied the former station")
	var before: Array[PackedByteArray] = _payment_image()
	var work_before: PackedByteArray = _fixture._f._construction.state_bytes()
	var result: Work.TickResult = _fixture._f._work.tick_solo(_fixture._f._residents.directory().get_typed_row(_fixture.job))
	assert_false(result.ok, "actual departed worker cannot earn work")
	assert_equal(transforms.probe_count, 1, "successful actual reader ran its late mutation")
	_assert_payment_unchanged(before)
	assert_true(_fixture._f._construction.state_bytes() == work_before, "remaining work unchanged")
	_pose()
	assert_true(_fixture._f._work.tick_solo(_fixture._f._residents.directory().get_typed_row(_fixture.job)).ok,
		"exact returned worker earns a later actual tick")


func test_final_start_and_productive_never_dispatch_pose_observers() -> void:
	"""The original late-copy witness stays armed across successful payment/work because final reads are direct."""
	_unpaid_order()
	var transforms: ObservedTransforms = _fixture._f._transforms as ObservedTransforms
	transforms.gate = _inside_final_contact
	transforms.probe = func() -> void: _pose(1)
	var before: PackedByteArray = transforms.state_bytes()
	assert_true(_fixture.start().ok, "pure actual final START")
	assert_true(_fixture._f._work.tick_solo(_fixture._f._residents.directory().get_typed_row(_fixture.job)).ok,
		"pure actual productive proof")
	assert_equal(transforms.probe_count, 0, "no final public pose observer")
	assert_true(transforms.state_bytes() == before, "no invisible final displacement")
	assert_true(transforms.probe.is_valid(), "observer remains armed rather than suppressed by fixture")


func test_source_observer_cannot_rewrite_a_station_or_spend_identity() -> void:
	"""The actual decoder can return success and still mutate borrowed output; private source equality catches it."""
	var before: PackedByteArray = _fixture._f._residents.directory().state_bytes()
	_fixture.source.probe = func() -> void: _fixture.contacts._station[2] += 1
	var refused: Construction.OpResult = _fixture._router.open_order(_fixture.paid, _fixture.placement, 0)
	assert_equal(refused.error, Contacts.REFUSE_SOURCE, "authored source tuple remains exact")
	assert_true(_fixture._f._residents.directory().state_bytes() == before, "no Project identity spent")
	assert_true(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).ok, "fresh complete source retries")


func test_callback_resize_and_reentry_refuse_before_allocation() -> void:
	"""Malformed borrowed packets and a recursive request cannot overwrite the active contact observation."""
	var before: PackedByteArray = _fixture._f._residents.directory().state_bytes()
	_fixture.source.probe = func() -> void: _fixture.contacts._station.resize(2)
	assert_false(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).ok, "resized source packet refused")
	_fixture.contacts._station.resize(9)
	var nested: Array[StringName] = []
	_fixture.source.probe = func() -> void:
		nested.append(_fixture.contacts.admission_refusal(_fixture.placement, 0))
	assert_equal(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).error,
		Contacts.REFUSE_REENTRY, "outer observation poisoned")
	assert_equal(nested, [&"CONNECTOR_CONTACT_REENTRY"], "nested read did not replace scratch")
	assert_true(_fixture._f._residents.directory().state_bytes() == before, "both refusals preserve allocator")
	assert_true(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).ok, "clean synchronous retry")


func test_exact_current_cut_phase_and_room_identity_are_required() -> void:
	"""An existing paid key at the right coordinate cannot substitute another phase or Room generation."""
	var sites: Sites = _fixture._sites
	var row: int = sites._ordered_row[0]
	var phase: int = sites._phase[row]
	var generation: int = sites._room_generation[row]
	var before: PackedByteArray = _fixture._f._residents.directory().state_bytes()
	sites._phase[row] = Sites.CUTTING
	assert_equal(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).error,
		Contacts.REFUSE_CUT, "whole exact dependency phase")
	sites._phase[row] = phase
	sites._room_generation[row] = generation + 1
	assert_equal(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).error,
		Contacts.REFUSE_CUT, "full claimed Room identity")
	sites._room_generation[row] = generation
	assert_true(_fixture._f._residents.directory().state_bytes() == before, "no Project allocation on wrong actual Site")
	assert_true(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).ok, "restored actual dependency")


func test_catalog_source_drift_does_not_reuse_contact_permission() -> void:
	"""An actual immutable Profiles replacement leaves old Catalog/Frontier pins stale even at unchanged Space revision."""
	var before: PackedByteArray = _fixture._f._residents.directory().state_bytes()
	var identity: PackedInt32Array = PackedInt32Array([0, 0, 0])
	assert_true(_fixture._f._residents.spatial_profile_identity_into(_fixture._f._worker, identity), "actual identity")
	var bytes: PackedByteArray = Content.profile_image(identity)
	bytes.encode_s64(12, 3)
	assert_equal(_fixture._f._profiles.load_file(WorldTests.PROFILE_TEMP,
		CatalogTests._write(WorldTests.PROFILE_TEMP, bytes), 3), &"", "actual monotonic source replacement")
	assert_false(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).ok, "stale source closure refuses")
	assert_true(_fixture._f._residents.directory().state_bytes() == before, "no allocated identity after drift")


func test_material_requires_actual_selected_finite_spatial_storage() -> void:
	"""An ordinary reachable container at coincident surface metadata cannot stand in for the selected endpoint."""
	_fixture.open_order()
	_fixture.assign_worker()
	var ordinary: Vector2i = _fixture._f._inventory.create_container(_fixture._f._world_ref, 400000, -1, 0, true).ref
	var before: PackedByteArray = _fixture._f._construction.state_bytes()
	assert_false(_fixture._router.bind_material_container(_fixture.project, ordinary).ok, "no spatial alias or unlimited fallback")
	assert_true(_fixture._f._construction.state_bytes() == before, "delivery binding unchanged")
	assert_true(_fixture._router.bind_material_container(_fixture.project, _fixture.storage).ok, "exact finite STORAGE binds")


func test_late_inventory_worker_move_preserves_every_paid_byte_and_retries() -> void:
	"""The actual final Inventory observer runs after contact preparation; the last pure leaf sees current Transform."""
	_unpaid_order()
	var observer: PaidTests.SeedObserver = PaidTests.SeedObserver.new()
	observer.probe = func() -> void: _pose(1)
	assert_true(_fixture._f._inventory.set_seed_expiry_authority(observer).ok, "real final reserved-wood observer")
	var before: Array[PackedByteArray] = _payment_image()
	assert_false(_fixture.start().ok, "late actual worker move refuses payment")
	assert_true(observer.calls > 0, "last actual Inventory observer executed")
	_assert_payment_unchanged(before)
	assert_false(_fixture._f._construction.has_work_begun(_fixture.project), "no WIP/start publication")
	assert_true(_fixture._f._inventory.set_seed_expiry_authority(null).ok, "observer removed")
	_pose()
	assert_true(_fixture.start().ok, "same stock and reservations retry")


func test_productive_source_observer_pose_drift_earns_no_work_xp_or_tool_wear() -> void:
	"""A successful source observer does not preserve arrival when the real worker moves at unchanged graph revision."""
	_paid_order()
	var before: Array[PackedByteArray] = _payment_image()
	var jobs: PackedByteArray = _fixture._f._jobs.state_bytes()
	_fixture.source.probe = func() -> void: _pose(1)
	var row: int = _fixture._f._residents.directory().get_typed_row(_fixture.job)
	assert_false(_fixture._f._work.tick_solo(row).ok, "last actual pose drift refused")
	_assert_payment_unchanged(before)
	assert_true(_fixture._f._jobs.state_bytes() == jobs, "no Job labor credit")
	_pose()
	assert_true(_fixture._f._work.tick_solo(row).ok, "fresh actual arrival can earn work")


func test_last_productive_pause_and_wrong_heading_refuse_current_work() -> void:
	"""Phase and actual work heading remain live facts after the last source observer."""
	_paid_order()
	var row: int = _fixture._f._residents.directory().get_typed_row(_fixture.job)
	var before: Array[PackedByteArray] = _payment_image()
	_fixture.source.probe = func() -> void:
		assert_true(_fixture._f._construction.set_paused(_fixture.project, true).ok, "actual late pause")
	assert_equal(_fixture._f._work.tick_solo(row).error, Construction.REFUSE_PAUSED, "late phase refusal")
	_assert_payment_unchanged(before)
	assert_true(_fixture._f._construction.set_paused(_fixture.project, false).ok, "actual resume")
	_pose(0, 16384)
	assert_false(_fixture._f._work.tick_solo(row).ok, "wrong exact work heading")
	_pose()
	assert_true(_fixture._f._work.tick_solo(row).ok, "original qualified heading retries")


func test_late_commit_endpoint_change_retains_wip_and_original_arena() -> void:
	"""A receipt is insufficient when final source observation changes the real endpoint payload without a graph swap."""
	_paid_order()
	_fixture.finish_work()
	var locations: Locations = _fixture._f._locations
	var at: int = Locations.PAYLOAD_REVISION * locations._capacity + _fixture._f._first.x
	var payload: int = locations._live.i64[at]
	var before: Array[PackedByteArray] = _payment_image()
	var geometry: PackedByteArray = _fixture._f._owner.state_bytes()
	(_fixture.contacts as ActualContacts).final_probe = func() -> void: locations._live.i64[at] += 1
	assert_false(_fixture._router.complete_order(_fixture.project).ok, "late actual payload change refused")
	_assert_payment_unchanged(before)
	assert_true(_fixture._f._owner.state_bytes() == geometry, "no physical publication")
	assert_true(_fixture._f._budget.is_quiescent(), "prepared companions discarded before release")
	locations._live.i64[at] = payload
	assert_true(_fixture._router.complete_order(_fixture.project).ok, "exact original earned receipt retries")


func test_paused_cancellation_preserves_prefix_and_actual_refund() -> void:
	"""A missing installation worker does not prohibit the legal paused refund path."""
	_paid_order()
	assert_true(_fixture._f._construction.set_paused(_fixture.project, true).ok, "pause actual paid order")
	_pose(1)
	assert_true(_fixture._router.cancel_order(_fixture.project, _fixture.storage).ok, "actual paused cancellation")
	var record: Placements.OrderRecord = Placements.OrderRecord.new()
	assert_equal(_fixture._placements.placement_into(_fixture.placement, record), &"", "retained actual placement")
	assert_equal(record.installed_count, 0, "pending group never installed")
	assert_equal(record.project, NULL_REF, "refunded active order cleared")
	assert_equal(_fixture._router._funding.purpose_cancellation_loss_milli(Construction.PURPOSE_CONNECTOR_INSTALL,
		_fixture._f._items.compiled_id(&"wood")), 200, "one actual80 percent refund")


func test_complete_profile_motion_does_not_ignore_negative_foot_residual() -> void:
	"""An endpoint's air cannot excuse below-floor body outside its actual authored stance/support intersection."""
	assert_equal(_fixture.contacts.admission_refusal(_fixture.placement, 0), &"", "current actual proof")
	var actual: Contacts = _fixture.contacts
	actual._box.low = Vector3i(-128, -1, -129)
	actual._box.high = Vector3i(128, 900, 128)
	actual._box.role = Profiles.BODY_HELD_LOAD
	assert_equal(actual._profile_bounds(actual._box, actual._bounds), &"", "exact translated physical body")
	assert_equal(actual._role_geometry(Profiles.BODY_HELD_LOAD), Contacts.REFUSE_GEOMETRY,
		"one unit below floor outside actual stance is not free air")
	actual._box.low.z = -128
	assert_equal(actual._profile_bounds(actual._box, actual._bounds), &"", "restored source geometry")
	assert_equal(actual._role_geometry(Profiles.BODY_HELD_LOAD), &"", "actual exact support covers residual")


func test_positive_contact_patch_must_fit_whole_selected_face() -> void:
	"""A contained integer focus cannot authorize a patch extending beyond the actual bearing edge."""
	assert_equal(_fixture.contacts.admission_refusal(_fixture.placement, 0), &"", "real source/face proof")
	var actual: Contacts = _fixture.contacts
	actual._box.role = Profiles.CONTACT_PATCH
	actual._box.low = Vector3i(-33, 0, -208)
	actual._box.high = Vector3i(8, 0, -176)
	assert_equal(actual._contact_refusal(actual._box), Contacts.REFUSE_GEOMETRY, "whole planar patch exceeds bearing")
	actual._box.low.x = -32
	assert_equal(actual._contact_refusal(actual._box), &"", "inclusive exact selected face boundary")


func test_finite_fragment_union_matches_independent_small_cell_oracle() -> void:
	"""Every3x3 cover union is compared with integer cell membership, not another subtraction algorithm."""
	var fragments: Contacts.Fragments = Contacts.Fragments.new()
	fragments.allocate()
	var bounds: PackedInt32Array = PackedInt32Array([-1, -1, -1, 2, 0, 2])
	for mask: int in 512:
		fragments.remaining = 10000
		fragments.failed = false
		fragments.start(bounds)
		for cell: int in 9:
			if (mask & (1 << cell)) == 0: continue
			@warning_ignore("integer_division") var z: int = cell / 3 - 1
			var x: int = cell % 3 - 1
			assert_true(fragments.subtract(PackedInt32Array([x, -1, z, x + 1, 0, z + 1])), "finite exact subtraction")
		_assert_residual_cells(fragments, mask)
	fragments.remaining = 0
	fragments.failed = false
	fragments.start(bounds)
	assert_false(fragments.subtract(bounds), "exhaustion cannot claim complete coverage")


func _assert_residual_cells(fragments: Contacts.Fragments, mask: int) -> void:
	"""Each unit cell occurs exactly once iff no supplied box covered it; overlaps and missing holes both fail."""
	for cell: int in 9:
		@warning_ignore("integer_division") var z: int = cell / 3 - 1
		var x: int = cell % 3 - 1
		var count: int = 0
		for row: int in fragments.count:
			var at: int = row * 6
			if x >= fragments.first[at] and x < fragments.first[at + 3] \
					and z >= fragments.first[at + 2] and z < fragments.first[at + 5]:
				count += 1
		assert_equal(count, 0 if (mask & (1 << cell)) != 0 else 1, "exact disjoint residual cell")


func test_reflected_fixed_packets_fit_the_admitted_control_reserve() -> void:
	"""Count actual numeric/packed members, including nested records; native memory remains separately unmeasured."""
	var actual: Contacts = Contacts.new()
	assert_equal(actual.configure(_fixture._placements, _fixture._router, _fixture.source,
		Contacts.CONTROL_BYTES - 1), Contacts.REFUSE_BINDING, "insufficient controls refuse before packed allocation")
	assert_equal(actual._frame.size(), 0, "no packet allocated on refused configuration")
	assert_equal(actual.configure(_fixture._placements, _fixture._router, _fixture.source,
		Contacts.CONTROL_BYTES), &"", "exact real binding admits the fixed packet")
	var bytes: int = 0
	for source: RefCounted in [actual, actual._order, actual._location, actual._other, actual._descriptor,
			actual._selection, actual._box, actual._stance, actual._number, actual._fragments]:
		bytes += _packet_numeric_bytes(source)
	assert_equal(bytes, 3059, "source-derived reusable payload includes the sole original companion token, with no hidden per-placement bank")
	assert_true(bytes + 1024 <= Contacts.CONTROL_BYTES, "nested numeric helper ceiling fits the same reserve")
	assert_equal(_packet_numeric_bytes(actual._fragments), 1633, "both fragment banks coexist and are counted")


func _packet_numeric_bytes(source: RefCounted) -> int:
	"""Inspect runtime declarations independently of the production census constants or declared array widths."""
	var bytes: int = 0
	for property: Dictionary in source.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0: continue
		var value: Variant = source.get(String(property.name))
		if value is int or value is Vector2i: bytes += 8
		elif value is Vector3i: bytes += 12
		elif value is bool: bytes += 1
		elif value is PackedInt32Array: bytes += value.size() * 4
		elif value is PackedInt64Array: bytes += value.size() * 8
		elif value is PackedByteArray: bytes += value.size()
		assert_false(value is Array or value is Dictionary or value is PackedFloat32Array
			or value is PackedFloat64Array, "no uncounted container or authoritative floating packet")
	return bytes


func test_required_delivery_direction_uses_actual_committed_profile_certificate() -> void:
	"""An outward path does not grant the authored material-to-worker return direction."""
	var bank: RefCounted = _fixture._f._binding._live
	var at: int = _fixture._f.reverse_edge.x * 32
	var original: int = bank.masks[at]
	var before: PackedByteArray = _fixture._f._residents.directory().state_bytes()
	bank.masks[at] &= 254
	assert_false(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).ok,
		"a missing current delivery certificate refuses before a paid Project exists")
	assert_true(_fixture._f._residents.directory().state_bytes() == before, "no allocated identity on blocked route")
	bank.masks[at] = original
	assert_true(_fixture._router.open_order(_fixture.paid, _fixture.placement, 0).ok,
		"restored actual directed certificate is rechecked")


func test_retained_paid_history_never_becomes_natural_bearing() -> void:
	"""The permanent actual Site history is authoritative even after matter is backfilled and claims are released."""
	var origin: Vector3i = Vector3i(WorldTests.X, -512, WorldTests.Z)
	var key: int = _fixture._sites._key_at(origin)
	assert_true(key >= 0, "actual immutable paid key under the retained source bearing")
	var row: int = _fixture._sites._claim_key(key, _fixture._sites._key_lower_bound(key))
	_fixture._sites._ever_cut[row] = 1 # Controlled fixture for an already-released backfilled Site; no paid phase is invented.
	var before: PackedByteArray = _fixture._f._residents.directory().state_bytes()
	assert_equal(_fixture.contacts.admission_refusal(_fixture.placement, 0), Contacts.REFUSE_BEARING,
		"original Terrain cannot overwrite retained paid history")
	assert_true(_fixture._f._residents.directory().state_bytes() == before, "no new paid identity")
	assert_equal(_fixture._sites._ever_cut[row], 1, "read-only proof preserves permanent history")


func test_actual_prior_installed_part_refuses_later_world_exclusion() -> void:
	"""A genuine paid prefix cannot hide a new well outside the worker's motion but inside a required bearing."""
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "original finite fixture released")
	_fixture = ContactFixture.new()
	_fixture.assembly_count = 2
	_fixture.before_each()
	_paid_order()
	_fixture.finish_work()
	assert_true(_fixture._router.complete_order(_fixture.project).ok, "first real billed part installed")
	assert_equal(_fixture.contacts.admission_refusal(_fixture.placement, 1), &"", "actual prior installed bearing qualifies")
	var space_before: int = _fixture._f._owner.revision()
	var well: Buildings.OpResult = _fixture._f._buildings.place_building(int(Catalog.BUILDING_DEFINITION["well"]),
		49 * Buildings.MAP_TILES_X + 62, 0, 31)
	assert_true(well.ok, "actual later surface well over the remote installed bearing")
	var before: PackedByteArray = _fixture._f._residents.directory().state_bytes()
	var paid_before: Array[PackedByteArray] = _payment_image()
	assert_equal(_fixture.contacts.admission_refusal(_fixture.placement, 1), Terrain.REFUSE_FOUNDATION,
		"fresh actual exclusion blocks prior timber dependency outside station boxes")
	assert_false(_fixture._router.open_order(_fixture.paid, _fixture.placement, 1).ok, "no new paid Project")
	assert_true(_fixture._f._residents.directory().state_bytes() == before, "refusal spends no identity")
	_assert_payment_unchanged(paid_before)
	assert_equal(_fixture._f._owner.revision(), space_before, "unregistered world exclusion keeps the same sparse revision")
	assert_true(_fixture._f._buildings.demolish_building(well.ref).ok, "remove actual blocker")
	assert_equal(_fixture.contacts.admission_refusal(_fixture.placement, 1), &"", "unchanged actual prefix retries")


func test_unknown_actual_actor_cannot_be_omitted_from_productive_clearance() -> void:
	"""A living resident without a committed profile cannot disappear from the work motion's occupancy proof."""
	_unpaid_order()
	var other: Vector2i = _fixture._f._residents.spawn(&"mouse").ref
	assert_true(_fixture._f._transforms.place(other, WorldTests.X + 512, 512, WorldTests.Z + 512, 0), "real overlapping actor")
	var before: Array[PackedByteArray] = _payment_image()
	assert_equal(_fixture.start().error, &"CONNECTOR_CONTACT_ACTOR_UNBOUND", "unknown complete actor shape refuses")
	_assert_payment_unchanged(before)
	_bind_other_actor(other)
	assert_true(_fixture.start().ok, "both actual actors now have complete committed profiles and separated poses")
	before = _payment_image()
	_fixture.source.probe = func() -> void:
		assert_true(_fixture._f._transforms.place(other, WorldTests.X + 512, 512, WorldTests.Z + 512, 0), "late actual actor moved")
	assert_false(_fixture._f._work.tick_solo(_fixture._f._residents.directory().get_typed_row(_fixture.job)).ok,
		"late actor movement cannot reuse its old graph pose")
	_assert_payment_unchanged(before)


func _bind_other_actor(other: Vector2i) -> void:
	"""The real second actor is explicitly equipped and admitted at existing supported storage, without an installation Job."""
	var tool: Vector2i = _fixture.stock(&"tool", 1000)
	assert_true(_fixture._f._gear.create_gear(_fixture._f._inventory, _fixture._f._items, tool, Gear.MANUFACTURE_BASIC).ok,
		"actual second durable tool matches the authored travel profile")
	assert_true(_fixture._f._gear.equip(tool, other).ok, "actual second equipment")
	assert_true(_fixture._f._transforms.place(other, WorldTests.X + 1536, 512, WorldTests.Z + 512, 0), "separate actual root")
	assert_equal(_fixture._f._routes.admit_actor(other, NULL_REF, _fixture._f._last,
		Profiles.MODE_WALK, 0, -1, tool), &"", "actual second registered profile")


func _phase_fixture() -> PhaseFixture:
	"""Reuse actual owner bootstrap with explicit synthetic source/phase geometry; never seed paid Site bytes."""
	_fixture.after_each()
	_fixture = PhaseFixture.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "actual phase fixture: %s" % _fixture.failures)
	return _fixture as PhaseFixture


func _phase_observe(f: PhaseFixture, stage: int, operation: int = PhaseContract.OP_BRACE,
		cold: int = 0, space: int = 0) -> StringName:
	"""Only exact real source/Site arguments enter the shared contact packet."""
	return f.contacts.phase_observe_refusal(f.placement, f.site(), 0, operation, stage, cold, space)


func test_phase_admission_uses_real_episode_site_and_same_contact_packet() -> void:
	"""Read-only prospective facts use no Project or assigned worker and never masquerade as installation."""
	var f: PhaseFixture = _phase_fixture()
	var before: Array[PackedByteArray] = _payment_image()
	var sites: PackedByteArray = f._sites.state_bytes()
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT), &"", "actual live phase geometry")
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_ADMIT), &"", "current pure phase facts")
	assert_equal(f.contacts.final_leaf_refusal(f.placement, NULL_REF, 0, Contract.ADMIT),
		Contacts.REFUSE_SCOPE, "INSTALL cannot borrow phase observation")
	assert_equal(f.contacts._project, NULL_REF, "no fake Project")
	assert_equal(f.contacts._primary_job, NULL_REF, "no fake Job")
	assert_equal(f._sites.state_bytes(), sites, "all physical history unchanged")
	_assert_payment_unchanged(before)
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT, PhaseContract.OP_BACKFILL_CLOSE), Contacts.REFUSE_SCOPE, "closure unqualified")
	assert_equal(f.contacts.phase_observe_refusal(f.placement, Vector2i(f.site().x, 2), 0,
		PhaseContract.OP_BRACE, PhaseContract.STAGE_ADMIT), Contacts.REFUSE_SCOPE, "full Site generation")


func test_phase_original_cold_lease_and_prepared_context_refuse() -> void:
	"""Cold facts use the original actual Budget; no made-up Space token provides a companion permission."""
	var f: PhaseFixture = _phase_fixture()
	var token: int = f._f._budget.acquire(Budget.COLD_BYTES)
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT, PhaseContract.OP_BRACE, token), &"", "actual cold lease")
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT, PhaseContract.OP_BRACE, token, 1),
		Contacts.REFUSE_PHASE_PREPARED, "prepared phase contract remains closed")
	var replacement: PackedInt64Array = PackedInt64Array([0])
	f.source.probe = func() -> void:
		assert_equal(f._f._budget.release(token), &"", "observer releases original")
		replacement[0] = f._f._budget.acquire(Budget.COLD_BYTES)
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT, PhaseContract.OP_BRACE, token), Contacts.REFUSE_SCOPE, "replaced lease refuses")
	assert_true(f._f._budget.covers(replacement[0], Budget.COLD_BYTES), "refusal preserved replacement lease")
	assert_equal(f._f._budget.release(replacement[0]), &"", "test releases own replacement")
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT), &"", "actual fresh live retry")


func test_phase_source_reentry_and_private_episode_mutation_refuse() -> void:
	"""The same fixed packet cannot be overwritten by another Site or by mutable source output."""
	var f: PhaseFixture = _phase_fixture()
	var before: Array[PackedByteArray] = _payment_image()
	f.source.probe = func() -> void: f.contacts._episode[15] = 0
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT), Contacts.REFUSE_SOURCE, "selector mutation refused")
	var nested: Array[StringName] = []
	f.source.probe = func() -> void: nested.append(_phase_observe(f, PhaseContract.STAGE_ADMIT))
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT), Contacts.REFUSE_REENTRY, "outer attempt poisoned")
	assert_equal(nested, [Contacts.REFUSE_REENTRY], "no nested packet")
	_assert_payment_unchanged(before)
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT), &"", "fresh source retries")


func test_phase_job_material_and_start_worker_are_actual_full_refs() -> void:
	"""A real purpose5 Project and Site Job keep their separate identity while sharing actual contacts and stock."""
	var f: PhaseFixture = _phase_fixture()
	f.open_phase(); f.assign_worker()
	assert_equal(_phase_observe(f, Contacts.PHASE_CONTACT_ONLY), &"", "live contact facts before binding")
	assert_equal(f.contacts.phase_material_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		f.storage, f.job), &"", "actual selected storage")
	assert_equal(f.contacts.phase_worker_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		f.job, f._f._worker), &"", "actual assigned WORK actor")
	assert_equal(f.contacts.phase_worker_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		Vector2i(f.job.x, f.job.y + 1), f._f._worker), Contacts.REFUSE_SCOPE, "foreign Job generation")
	f.deliver()
	assert_equal(_phase_observe(f, PhaseContract.STAGE_START), &"", "actual ready delivered brace phase")
	assert_equal(f.contacts._order.project, NULL_REF, "Placement has no INSTALL order")
	assert_equal(f.contacts._project, f.project, "real purpose5 Project retained")
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_START), &"", "real current start leaf")
	assert_true(f.failures.is_empty(), "actual paid fixture checks")


func test_phase_final_worker_observer_move_and_pause_earn_nothing() -> void:
	"""A successful late pose copy cannot let an absent worker or paused phase pass the pure final guard."""
	var f: PhaseFixture = _phase_fixture()
	f.open_phase(); f.assign_worker(); f.deliver()
	assert_equal(_phase_observe(f, PhaseContract.STAGE_START), &"", "actual ready phase")
	var before: Array[PackedByteArray] = _payment_image()
	var transforms: ObservedTransforms = f._f._transforms as ObservedTransforms
	transforms.probe = func() -> void: _pose(1)
	assert_equal(f.contacts.phase_final_observation_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_START), &"", "observer copied the old pose")
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_START), Contacts.REFUSE_WORKER, "actual new pose refuses")
	_assert_payment_unchanged(before)
	_pose()
	assert_equal(_phase_observe(f, PhaseContract.STAGE_START), &"", "actual pose restored")
	assert_true(f._sites.set_paused(f.site(), true).ok, "actual phase pause")
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_START), Construction.REFUSE_PAUSED, "pause caught before payment")
	assert_equal(_phase_observe(f, PhaseContract.STAGE_CANCEL), &"", "paused cancellation contact remains legal")
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_CANCEL), &"", "paused cancellation does not require productive permission")


func test_phase_productive_leaf_follows_real_payment_and_rechecks_current_worker() -> void:
	"""Only actual Funding and Work create progress; live Contacts reuse never promotes a READY phase to productive."""
	var f: PhaseFixture = _phase_fixture()
	f.open_phase(); f.assign_worker(); f.deliver()
	assert_false(_phase_observe(f, PhaseContract.STAGE_WORK).is_empty(), "unpaid productive permission refused")
	assert_true(f._sites.begin_phase_work(f.site(), 100).ok, "actual reserved inputs become WIP")
	assert_equal(_phase_observe(f, PhaseContract.STAGE_WORK), &"", "paid current phase contact")
	var before: Array[PackedByteArray] = _payment_image()
	var transforms: ObservedTransforms = f._f._transforms as ObservedTransforms
	transforms.probe = func() -> void: _pose(1)
	assert_equal(f.contacts.phase_final_observation_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_WORK), &"", "last observation copied old pose")
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_WORK), Contacts.REFUSE_WORKER, "current departed worker refused")
	_assert_payment_unchanged(before)
	_pose()
	assert_equal(_phase_observe(f, PhaseContract.STAGE_WORK), &"", "actual returned worker retries")
	assert_true(f._f._jobs.set_tool_gate(f._f._residents.directory().get_typed_row(f.job), Jobs.GATE_BLOCKED).ok, "actual tool gate changes")
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_WORK), Contacts.REFUSE_WORKER, "late tool gate cannot retain permission")
	_assert_payment_unchanged(before)


func test_phase_cut_output_is_current_exact_spatial_storage_after_real_bracing() -> void:
	"""A real paid brace enables CUT; output is bound independently and surface aliases cannot select it."""
	var f: PhaseFixture = _phase_fixture()
	f.open_phase(); f.assign_worker(); f.deliver()
	assert_true(f._sites.begin_phase_work(f.site(), 100).ok, "real brace payment")
	f.finish_work()
	assert_true(f._sites.settle_phase(f.site()).ok, "actual earned brace publication")
	assert_equal(f._sites.support_conservation_refusal(), &"", "actual support account")
	f.next_job(PhaseContract.OP_CUT)
	assert_equal(_phase_observe(f, Contacts.PHASE_CONTACT_ONLY, PhaseContract.OP_CUT), &"", "real CUT source/contact scope")
	assert_equal(f.contacts.phase_output_refusal(f.placement, f.site(), PhaseContract.OP_CUT, f.storage, f.job, 0),
		Contacts.REFUSE_MATERIAL, "surface tile cannot alias actual endpoint")
	assert_equal(f.contacts.phase_output_refusal(f.placement, f.site(), PhaseContract.OP_CUT,
		Vector2i(f.storage.x, f.storage.y + 1), f.job, -1), Contacts.REFUSE_MATERIAL, "full container generation")
	assert_equal(f.contacts.phase_output_refusal(f.placement, f.site(), PhaseContract.OP_CUT, f.storage, f.job, -1), &"", "current exact output")
	assert_true(f._sites.bind_output(f.site(), f.storage).ok, "actual finite output binding")
	assert_equal(_phase_observe(f, PhaseContract.STAGE_START, PhaseContract.OP_CUT), &"", "ready real CUT and exact output")
	assert_equal(f.contacts._phase_output_container, f.storage, "output retained separately from no-input material")
	assert_equal(f.contacts._material_container, NULL_REF, "CUT invents no material delivery")
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_CUT,
		PhaseContract.STAGE_START), &"", "pure current output proof")
	assert_true(f.failures.is_empty(), "actual paid brace and next-phase helper checks")


func test_phase_discard_cannot_invalidate_a_different_mode_or_site() -> void:
	"""Local cleanup owns only its original tuple; unrelated callers cannot revoke another synchronous observation."""
	var f: PhaseFixture = _phase_fixture()
	assert_equal(_phase_observe(f, PhaseContract.STAGE_ADMIT), &"", "current phase observation")
	f.contacts.discard_transition(f.placement, NULL_REF, 0, Contract.ADMIT)
	f.contacts.discard_phase(f.placement, Vector2i(f.site().x, 2), PhaseContract.OP_BRACE, PhaseContract.STAGE_ADMIT)
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_ADMIT), &"", "unrelated cleanup leaves original proof current")
	f.contacts.discard_phase(f.placement, f.site(), PhaseContract.OP_BRACE, PhaseContract.STAGE_ADMIT)
	assert_equal(f.contacts.phase_final_leaf_refusal(f.placement, f.site(), PhaseContract.OP_BRACE,
		PhaseContract.STAGE_ADMIT), Contacts.REFUSE_SCOPE, "exact cleanup invalidates proof")
