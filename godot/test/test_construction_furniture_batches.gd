extends "res://test/framework/test_case.gd"
## Decision1089: actual paired identities/accounting; only geometric admission is synthetic here.

const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const PhysicalFixture := preload("res://test/test_excavation_physical.gd")
const BuildingsFixture := preload("res://test/test_buildings_spatial.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class SyntheticAuthority extends BuildingsFixture.Authority:
	## Explicit component permission, never a production RoomOrders substitute.
	var batch_owner: WeakRef = null

	func furniture_candidates_refusal(room: Vector2i, batch: Directory.CreateBatch,
			entries: PackedInt32Array) -> StringName:
		"""Compare a pinned fixture packet; the real coordinator also seals actual spatial owners."""
		var target: SyntheticOwner = batch_owner.get_ref() as SyntheticOwner if batch_owner != null else null
		return target.packet_refusal(room, batch, entries) if target != null else Buildings.REFUSE_SPATIAL_COMMAND

	func is_publishing_furniture_admissions(room: Vector2i, batch: Directory.CreateBatch) -> bool:
		"""Grant no direct publication outside the actual Router's exclusive synchronous bracket."""
		var target: SyntheticOwner = batch_owner.get_ref() as SyntheticOwner if batch_owner != null else null
		return target != null and target.is_publishing(room, batch)

class SyntheticOwner extends Contract.Owner:
	## Geometry proof is deliberately synthetic; actual identity allocation and prices are not.
	var construction: Construction = null
	var world: Vector2i = NULL_REF
	var route: WeakRef = null
	var room: Vector2i = NULL_REF
	var packet: Directory.CreateBatch = null
	var entries_pin: PackedInt32Array = PackedInt32Array()
	var tuples_pin: PackedByteArray = PackedByteArray()
	var refusal: StringName = &""
	var mutation: int = 0
	var attempt_reentry: bool = false
	var early_reentry: bool = false
	var publications: int = 0
	var discards: int = 0
	var nested_error: StringName = &""
	var publish_saw_rows: bool = false
	var clear_after_publication: bool = false
	var unsupported: bool = false
	var math: IntMath.IntResult = IntMath.IntResult.new()

	func construction_owner() -> RefCounted:
		"""Bind to the exact real accounting object, not coincident numeric refs."""
		return construction

	func world_ref() -> Vector2i:
		"""Use the real Directory World generation."""
		return world

	func purpose() -> int:
		"""Furniture keeps its existing separate purpose namespace."""
		if early_reentry and route != null:
			early_reentry = false
			var router: Router = route.get_ref() as Router
			nested_error = router.open_furniture_batch(self, room, packet, entries_pin).error
		return Construction.PURPOSE_SPATIAL_FURNITURE

	func project_facts_into(project: Vector2i, out: Contract.Quote) -> StringName:
		"""Read actual immutable pending Furniture facts; quantities come only from the protected catalog."""
		if not construction.is_live_project(project):
			return Contract.REFUSE_QUOTE
		var piece: Vector2i = construction.subject_ref_of(project)
		var type_id: Buildings.OpResult = construction.buildings().type_id_of_furniture(piece)
		if not type_id.ok or construction.buildings().is_furniture_installed(piece):
			return Contract.REFUSE_QUOTE
		out.reset()
		out.subject = piece
		out.operation = type_id.value
		construction.declared_work_mwu_into(Construction.PURPOSE_FURNITURE, type_id.value, math)
		out.total_mwu = math.value
		construction.remaining_mwu_into(project, math)
		out.remaining_mwu = math.value
		out.job_kind = Jobs.JOB_KIND_BUILD
		out.max_workers = Construction.MAX_BUILDERS
		construction.bill_size_into(Construction.PURPOSE_FURNITURE, type_id.value, math)
		out.input_count = math.value
		for line: int in out.input_count:
			out.input_keys[line] = construction.material_key_at(Construction.PURPOSE_FURNITURE, type_id.value, line)
			construction.required_milli_into(Construction.PURPOSE_FURNITURE, type_id.value, line, math)
			out.input_milli[line] = math.value
		return out.refusal()

	func prepare(actual_room: Vector2i, batch: Directory.CreateBatch, entries: PackedInt32Array) -> void:
		"""Pin a component-test observation before any mutable permission callback."""
		room = actual_room
		packet = batch
		entries_pin = entries.duplicate()
		tuples_pin = _tuples(batch)

	func _tuples(batch: Directory.CreateBatch) -> PackedByteArray:
		"""Diagnostic fixture allocation only; production uses separately admitted packed pins."""
		return var_to_bytes([batch.count, batch.slots, batch.generations, batch.kinds,
			batch.typed_rows, batch.persistent_ids]) if batch != null else PackedByteArray()

	func packet_refusal(actual_room: Vector2i, batch: Directory.CreateBatch,
			entries: PackedInt32Array) -> StringName:
		"""A mutable observation cannot acquire permission after changing any accepted entry/tuple."""
		return &"" if actual_room == room and batch != null and batch == packet \
			and entries == entries_pin and _tuples(batch) == tuples_pin else &"SYNTHETIC_BATCH_CHANGED"

	func furniture_batch_refusal(actual_room: Vector2i, batch: Directory.CreateBatch,
			entries: PackedInt32Array) -> StringName:
		"""Inject late provider changes, then recheck the private packet before actual allocation."""
		if unsupported:
			return super.furniture_batch_refusal(actual_room, batch, entries)
		var router: Router = route.get_ref() as Router
		if attempt_reentry:
			nested_error = router.open_furniture_batch(self, actual_room, batch, entries).error
		if mutation == 1:
			batch.generations[batch.count - 1] += 1
		elif mutation == 2:
			entries[3] = (entries[3] + 1) % 4
		var code: StringName = packet_refusal(actual_room, batch, entries)
		if code == &"" and not construction.buildings().room_is_valid(actual_room):
			code = &"SYNTHETIC_SHELL_INCOMPLETE"
		return refusal if code == &"" else code

	func is_publishing(actual_room: Vector2i, batch: Directory.CreateBatch) -> bool:
		"""A future-source publication window is separate from ordinary individual project actions."""
		var router: Router = route.get_ref() as Router if route != null else null
		return router != null and router.is_publishing_furniture_admissions(actual_room, batch, self)

	func publish_furniture_batch(actual_room: Vector2i, batch: Directory.CreateBatch,
			entries: PackedInt32Array) -> void:
		"""Observe actual pending rows and protected projects after the one real identity commit."""
		if not is_publishing(actual_room, batch) or packet_refusal(actual_room, batch, entries) != &"":
			return
		publish_saw_rows = true
		for index: int in range(0, batch.count, 2):
			publish_saw_rows = publish_saw_rows and construction.buildings().is_live_furniture(batch.ref_at(index)) \
				and construction.is_live_project(batch.ref_at(index + 1)) \
				and not construction.buildings().is_furniture_installed(batch.ref_at(index))
		publications += 1
		if clear_after_publication:
			batch.reset()
			entries.clear()

	func discard_furniture_batch(_room: Vector2i, _batch: Directory.CreateBatch) -> void:
		"""Fixture cleanup has no accounting writes, nor authority to release caller cold leases."""
		if unsupported:
			super.discard_furniture_batch(_room, _batch)
			return
		discards += 1

var _residents: Residents = null
var _priorities: Priorities = null
var _schedule: Schedule = null
var _jobs: Jobs = null
var _work: Work = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _gear: Gear = null
var _buildings: Buildings = null
var _construction: Construction = null
var _physical: PhysicalFixture.SpatialFixture = null
var _sites: Sites = null
var _router: Router = null
var _authority: SyntheticAuthority = null
var _owner: SyntheticOwner = null
var _world: Vector2i = NULL_REF
var _room: Vector2i = NULL_REF
var _batch: Directory.CreateBatch = null
var _entries: PackedInt32Array = PackedInt32Array()
var _math: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Bind actual payment, worker, identity and catalog owners; no admission spends material or labor."""
	_residents = Residents.new()
	_world = _residents.directory().create(Directory.KIND_WORLD)
	_priorities = Priorities.new()
	_schedule = Schedule.new(_residents.needs())
	_jobs = Jobs.new(_residents, _priorities, _schedule)
	_work = Work.new(_jobs)
	_inventory = Inventory.new(4, 16)
	_pool = Reservations.new()
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual item catalog")
	_gear = Gear.new(4)
	assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual equipment")
	assert_true(_work.bind_gear(_gear).ok, "actual tool owner")
	_buildings = Buildings.new(_residents.directory())
	_construction = Construction.new(_buildings)
	_physical = PhysicalFixture.SpatialFixture.new()
	_physical.world = _world
	_sites = Sites.new(_construction, _inventory, _pool, _items, _jobs, _work, _physical, 8, 4)
	_router = Router.new(_construction, _inventory, _pool, _items, _jobs, _work, _sites)
	assert_equal(_router.initialization_refusal(), &"", "actual router initializes")
	_bind_fixture()
	_prepare()


func _bind_fixture() -> void:
	"""Only completed-shell/geometric permission is explicitly synthetic in this component suite."""
	_authority = SyntheticAuthority.new()
	_authority.owner = weakref(_buildings)
	assert_true(_buildings.bind_spatial_authority(_authority).ok, "one actual Buildings authority")
	_authority.allow(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, Buildings.ROOM_TYPE_KITCHEN)
	_room = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_KITCHEN).ref
	_authority.allow(Buildings.SPATIAL_ROOM_VALID, _room, NULL_REF, 1)
	assert_true(_buildings.set_room_valid(_room, true).ok, "synthetic complete shell")
	_authority.reset()
	_authority.service_room = _room
	_owner = SyntheticOwner.new()
	_owner.construction = _construction
	_owner.world = _world
	_owner.route = weakref(_router)
	_authority.batch_owner = weakref(_owner)
	assert_true(_router.bind_owner(_owner).ok, "actual single Furniture purpose owner")


func after_each() -> void:
	"""All reverse owner/authority links are weak; no fixture publication cycle survives."""
	_batch = null
	_owner = null
	_authority = null
	_router = null
	_sites = null
	_physical = null
	_construction = null
	_buildings = null
	_gear = null
	_work = null
	_jobs = null
	_schedule = null
	_priorities = null
	_residents = null
	_pool = null
	_items = null
	_inventory = null


func _prepare() -> void:
	"""Observe alternating actual kinds and pin a mixed type/rotation player request."""
	_entries = PackedInt32Array([Catalog.FURNITURE_DEFINITION["hearth"], 1, 2, 3,
		Catalog.FURNITURE_DEFINITION["kitchen_bench"], 4, 2, 1,
		Catalog.FURNITURE_DEFINITION["shelf"], 6, 2, 0])
	_batch = Directory.CreateBatch.new(6)
	assert_equal(_residents.directory().peek_create_batch_into(PackedInt32Array([
		Directory.KIND_FURNITURE, Directory.KIND_CONSTRUCTION, Directory.KIND_FURNITURE,
		Directory.KIND_CONSTRUCTION, Directory.KIND_FURNITURE, Directory.KIND_CONSTRUCTION]), _batch), &"", "actual candidate")
	_owner.prepare(_room, _batch, _entries)


func _image() -> PackedByteArray:
	"""Compare all actual packed owner columns, raw allocator heaps and numerical state, including tails."""
	var image: PackedByteArray = PackedByteArray()
	for owner: RefCounted in [_residents.directory(), _buildings, _construction]:
		for property: Dictionary in owner.get_property_list():
			var field: Variant = owner.get(property["name"])
			if field is PackedByteArray or field is PackedInt32Array or field is PackedInt64Array \
					or field is int or field is StringName:
				image.append_array(var_to_bytes(field))
	image.append_array(_inventory.state_bytes())
	image.append_array(_pool.state_bytes())
	image.append_array(_router.state_bytes())
	image.append_array(_sites.funding_owner(_construction, _inventory, _pool, _items, _jobs, _work).state_bytes())
	image.append_array(_jobs.state_bytes())
	image.append_array(_work.state_bytes())
	image.append_array(_gear.state_bytes())
	return image


func _refused_unchanged() -> void:
	"""A whole command refusal creates no partial real rows, spends no identities and pays no bill."""
	var before: PackedByteArray = _image()
	var result: Construction.OpResult = _router.open_furniture_batch(_owner, _room, _batch, _entries)
	assert_false(result.ok, "whole batch refuses")
	assert_true(_image() == before, "all owner bytes unchanged")
	assert_equal(_owner.publications, 0, "no physical publication")
	assert_equal(_buildings.live_furniture_count(), 0, "no furniture prefix")
	assert_equal(_construction.live_project_count(), 0, "no project prefix")
	assert_equal(_router.furniture_batch_preparation_refusal(_room, _batch), Contract.REFUSE_AUTHORITY, "context closed")


func test_actual_mixed_pending_rows_and_protected_catalog_projects_publish_together() -> void:
	"""One accepted request creates all real pairs but no installed masks, usage, funding or progress."""
	var result: Construction.OpResult = _router.open_furniture_batch(_owner, _room, _batch, _entries)
	assert_true(result.ok, "actual batch publishes: %s" % result.error)
	assert_equal(result.value, 3, "whole accepted count")
	assert_equal(result.ref, _batch.ref_at(1), "actual first project receipt")
	assert_equal(_buildings.live_furniture_count(), 3, "all pending identities reserved")
	assert_equal(_construction.live_project_count(), 3, "all real projects reserved")
	assert_equal(_owner.publications, 1, "one sealed companion publication")
	assert_true(_owner.publish_saw_rows, "both actual typed stores preceded companion publication")
	assert_equal(_buildings.furniture_mask_of(_room).value, 0, "no installed service mask")
	for index: int in range(0, _batch.count, 2):
		_assert_pair(index)
	assert_false(_router.is_publishing_furniture_admissions(_room, _batch, _owner), "same-stack permit ended")
	assert_equal(_router.furniture_batch_publication_refusal(_room, _batch), Contract.REFUSE_AUTHORITY, "closed publication")


func _assert_pair(index: int) -> void:
	"""Check full identity/type/rotation, zero service and every protected recipe/work fact."""
	var piece: Vector2i = _batch.ref_at(index)
	var project: Vector2i = _batch.ref_at(index + 1)
	var type_id: int = _entries[index * 2]
	assert_equal(_buildings.room_ref_of_furniture(piece), _room, "actual full Room parent")
	assert_equal(_buildings.type_id_of_furniture(piece).value, type_id, "selected catalog type")
	assert_equal(_buildings.rotation_of_furniture(piece).value, _entries[index * 2 + 3], "selected rotation")
	assert_false(_buildings.is_furniture_installed(piece), "no premature installation")
	assert_equal(_buildings.user_ref_of_furniture(piece), NULL_REF, "no premature use claim")
	assert_equal(_buildings.origin_tile_of_furniture(piece).error, Buildings.REFUSE_SPATIAL_COORDINATE, "no ground alias")
	assert_equal(_buildings.count_furniture_of_kind(_room, type_id).value, 0, "pending is not service capacity")
	assert_equal(_construction.subject_ref_of(project), piece, "paired full actual subject")
	assert_true(_construction.purpose_into(project, _math), "actual purpose reads")
	assert_equal(_math.value, Construction.PURPOSE_SPATIAL_FURNITURE, "separate purpose")
	assert_true(_construction.max_workers_into(project, _math), "actual worker limit reads")
	assert_equal(_math.value, 4, "adopted finite workers")
	assert_true(_construction.declared_work_mwu_into(Construction.PURPOSE_FURNITURE, type_id, _math), "protected WU")
	var work: int = _math.value
	assert_true(_construction.remaining_mwu_into(project, _math), "actual remaining")
	assert_equal(_math.value, work, "no free work")
	_assert_bill(project, type_id)


func _assert_bill(project: Vector2i, type_id: int) -> void:
	"""Every project uses the existing immutable catalog, with no WIP, input claims or material credit."""
	assert_true(_construction.bill_size_into(Construction.PURPOSE_FURNITURE, type_id, _math), "protected bill")
	var count: int = _math.value
	assert_true(_construction.project_bill_size_into(project, _math), "actual project bill count")
	assert_equal(_math.value, count, "entire adopted recipe")
	for line: int in count:
		var key: StringName = _construction.material_key_at(Construction.PURPOSE_FURNITURE, type_id, line)
		assert_equal(_construction.project_material_key_at(project, line), key, "exact protected material key")
		assert_true(_construction.required_milli_into(Construction.PURPOSE_FURNITURE, type_id, line, _math), "protected quantity")
		var quantity: int = _math.value
		assert_true(_construction.project_required_milli_into(project, line, _math), "actual project quantity")
		assert_equal(_math.value, quantity, "exact protected material amount")
		assert_true(_construction.delivered_milli_into(project, line, _math), "actual deliveries")
		assert_equal(_math.value, 0, "nothing paid at confirmation")
	assert_equal(_construction.material_container_ref_of(project), NULL_REF, "no invented delivery")
	assert_false(_construction.has_work_begun(project), "no work before real job/delivery")


func test_direct_preparation_or_publication_never_allocates_any_identity() -> void:
	"""A caller's observed packet is not a prepared actual Router window."""
	var before: PackedByteArray = _image()
	assert_equal(_construction.spatial_furniture_batch_refusal(_room, _batch, _entries), Contract.REFUSE_AUTHORITY, "no router prepare")
	assert_true(_buildings.publish_spatial_furniture_batch(_room, _batch, _entries) != &"", "no actual identity/publication")
	assert_equal(_construction.publish_spatial_furniture_batch(_room, _batch, _entries), Contract.REFUSE_AUTHORITY, "no project publication")
	assert_false(_owner.is_publishing(_room, _batch), "no global true permit")
	assert_true(_image() == before, "direct APIs cannot spend or publish")


func test_null_and_foreign_owner_cannot_open_the_real_batch() -> void:
	"""Actual owner identity is required even if all numeric subject and World refs coincide."""
	var before: PackedByteArray = _image()
	var foreign: SyntheticOwner = SyntheticOwner.new()
	foreign.construction = _construction
	foreign.world = _world
	assert_false(_router.open_furniture_batch(null, _room, _batch, _entries).ok, "null owner")
	assert_false(_router.open_furniture_batch(foreign, _room, _batch, _entries).ok, "unbound same-number owner")
	assert_true(_image() == before, "wrong owner leaves both stores unchanged")
	assert_false(_router.is_publishing_furniture_admissions(_room, _batch, foreign), "no foreign permit")


func test_unfinished_shell_and_late_geometry_refusal_leave_all_owner_bytes_unchanged() -> void:
	"""Actual coordinator qualification must precede allocation, including a late physical refusal."""
	_authority.service_room = NULL_REF
	_refused_unchanged()
	_authority.service_room = _room
	_owner.refusal = &"SYNTHETIC_CONTACT_BLOCKED"
	_refused_unchanged()
	_owner.refusal = &""
	assert_true(_router.open_furniture_batch(_owner, _room, _batch, _entries).ok, "same unspent observation retries")


func test_wrong_room_generation_and_foreign_packet_are_rejected() -> void:
	"""Neither a numeric Room alias nor another allocator's coincident choices are accepted."""
	_room.y += 1
	_refused_unchanged()
	_room.y -= 1
	var foreign: Directory = Directory.new()
	var kinds: PackedInt32Array = _batch.kinds.duplicate()
	assert_equal(foreign.peek_create_batch_into(kinds, _batch), &"", "foreign candidate reads")
	_owner.prepare(_room, _batch, _entries)
	_refused_unchanged()
	assert_equal(foreign.total_live_count(), 0, "foreign owner also unchanged")


func test_wrong_kind_order_or_tuple_shape_never_publishes_a_prefix() -> void:
	"""A Room/Job tuple and truncated columns are not Furniture/Construction pairs."""
	_batch.kinds[4] = Directory.KIND_ROOM
	_owner.prepare(_room, _batch, _entries)
	_refused_unchanged()
	_prepare()
	_batch.typed_rows.resize(5)
	_refused_unchanged()
	_prepare()
	_entries.resize(11)
	_refused_unchanged()
	_batch = null
	_refused_unchanged()


func test_actual_surface_room_cannot_enter_underground_pair_admission() -> void:
	"""An ordinary managed interior remains on its unchanged surface construction path."""
	var hall: Buildings.OpResult = _buildings.place_building(Catalog.BUILDING_DEFINITION["hall"], 0, 0, 1)
	assert_true(hall.ok, "actual surface Building")
	var room: Buildings.OpResult = _buildings.designate_room(hall.ref, Buildings.ROOM_TYPE_DORMITORY,
		PackedInt32Array([129, 130, 131]))
	assert_true(room.ok, "actual managed Room")
	_room = room.ref
	_prepare()
	_refused_unchanged()


func test_unknown_type_edge_piece_and_rotation_refuse_the_whole_layout() -> void:
	"""The final invalid row cannot leave earlier valid pieces; edge openings have their own owner."""
	for invalid: int in [-1, 99, Catalog.FURNITURE_DEFINITION["interior_door"]]:
		_prepare()
		_entries[8] = invalid
		_owner.prepare(_room, _batch, _entries)
		_refused_unchanged()
	_prepare()
	_entries[11] = 4
	_owner.prepare(_room, _batch, _entries)
	_refused_unchanged()


func test_stale_single_allocation_and_retirement_never_roll_back_generations() -> void:
	"""Even allocating then freeing an unrelated kind invalidates the exact observed sequence."""
	var other: Vector2i = _residents.directory().create(Directory.KIND_JOB)
	assert_true(_residents.directory().destroy(other), "unrelated identity retired")
	_refused_unchanged()
	_prepare()
	assert_equal(_batch.generations[0], other.y + 1, "new full generation observed")
	assert_true(_router.open_furniture_batch(_owner, _room, _batch, _entries).ok, "fresh candidate accepted")


func test_duplicate_observation_cannot_allocate_again_or_invent_pending_services() -> void:
	"""A retained batch is a receipt after publication, not another permission to spend."""
	assert_true(_router.open_furniture_batch(_owner, _room, _batch, _entries).ok, "first whole publication")
	var before: PackedByteArray = _image()
	assert_false(_router.open_furniture_batch(_owner, _room, _batch, _entries).ok, "spent observations refuse")
	assert_true(_image() == before, "duplicate refusal preserves both owners")
	assert_equal(_owner.publications, 1, "exactly one geometry publication")
	assert_equal(_buildings.furniture_mask_of(_room).value, 0, "no installed service")


func test_publication_cleanup_cannot_erase_the_committed_scalar_receipt() -> void:
	"""A legitimate companion drops borrowed scratch after observing actual rows, before Router returns."""
	var first_project: Vector2i = _batch.ref_at(1)
	_owner.clear_after_publication = true
	var result: Construction.OpResult = _router.open_furniture_batch(_owner, _room, _batch, _entries)
	assert_true(result.ok, "committed command remains successful")
	assert_true(_owner.publish_saw_rows, "cleanup followed both real typed publications")
	assert_equal(_batch.count, 0, "callback legitimately invalidates cold observations")
	assert_true(_entries.is_empty(), "callback drops borrowed entries")
	assert_equal(result.value, 3, "accepted count pinned before cleanup")
	assert_equal(result.ref, first_project, "actual full project ref pinned before cleanup")
	assert_true(_construction.is_live_project(result.ref), "receipt still names actual work")
	var before: PackedByteArray = _image()
	assert_false(_router.open_furniture_batch(_owner, _room, _batch, _entries).ok, "cleared packet cannot retry")
	assert_true(_image() == before, "no duplicate identity prefix")
	assert_equal(_buildings.live_furniture_count(), 3, "exactly one actual Furniture set")
	assert_equal(_construction.live_project_count(), 3, "exactly one actual project set")


func test_bound_owner_without_batch_implementation_cleanly_refuses_the_new_operation() -> void:
	"""An existing individual-purpose owner may lack batches; base cleanup owns and mutates nothing."""
	_owner.unsupported = true
	_refused_unchanged()
	assert_equal(_owner.discards, 0, "unimplemented base holds no candidate to discard")


func test_mutation_in_final_provider_callback_refuses_without_an_identity_prefix() -> void:
	"""Separate private pins catch late mutable entries and full-generation tuple changes."""
	for mutation: int in [1, 2]:
		_prepare()
		_owner.mutation = mutation
		_refused_unchanged()
	_owner.mutation = 0
	_prepare()
	assert_true(_router.open_furniture_batch(_owner, _room, _batch, _entries).ok, "fresh sealed packet retries")


func test_callback_reentry_is_closed_before_any_provider_runs() -> void:
	"""A nested confirmation cannot spend the same free tuple prefix inside final qualification."""
	_owner.attempt_reentry = true
	assert_true(_router.open_furniture_batch(_owner, _room, _batch, _entries).ok, "outer batch accepted")
	assert_equal(_owner.nested_error, Router.REFUSE_BUSY, "nested operation refuses before owner callbacks")
	assert_equal(_buildings.live_furniture_count(), 3, "only one Furniture set")
	assert_equal(_construction.live_project_count(), 3, "only one project set")


func test_initial_owner_purpose_callback_is_already_inside_exclusive_bracket() -> void:
	"""Even the first owner identity check cannot reenter before the router is marked busy."""
	_owner.early_reentry = true
	assert_true(_router.open_furniture_batch(_owner, _room, _batch, _entries).ok, "outer batch accepted")
	assert_equal(_owner.nested_error, Router.REFUSE_BUSY, "initial owner callback cannot recursively admit")
	assert_equal(_buildings.live_furniture_count(), 3, "one actual batch")


func test_missing_typed_row_capacity_and_pid_capacity_refuse_before_first_write() -> void:
	"""Actual allocator capacity checks re-run after observation; neither final shortage has a prefix."""
	var ids: Directory = _residents.directory()
	var available: int = ids._kind_free_count[Directory.KIND_CONSTRUCTION]
	ids._kind_free_count[Directory.KIND_CONSTRUCTION] = 2
	_refused_unchanged()
	ids._kind_free_count[Directory.KIND_CONSTRUCTION] = available
	ids._next_persistent_id = Directory.MAX_INT32 - 4
	_refused_unchanged()


func test_live_typed_owner_mirror_conflict_refuses_in_either_store() -> void:
	"""An inconsistent typed row cannot be overwritten even if its Directory observation is free."""
	_buildings._f_present[_batch.typed_rows[4]] = 1
	_refused_unchanged()
	_buildings._f_present[_batch.typed_rows[4]] = 0
	_construction._present[_batch.typed_rows[5]] = 1
	_refused_unchanged()


func test_reused_free_typed_rows_reset_all_paid_delivery_and_installed_flags() -> void:
	"""Retained inactive bytes cannot leak services or paid progress into a new full-generation row."""
	for index: int in range(0, _batch.count, 2):
		var piece_row: int = _batch.typed_rows[index]
		var project_row: int = _batch.typed_rows[index + 1]
		_buildings._f_installed[piece_row] = 1
		_buildings._f_condition[piece_row] = 10
		_construction._remaining_mwu[project_row] = 1
		_construction._work_begun[project_row] = 1
		_construction._paused[project_row] = 1
		_construction._paid_base_type[project_row] = 1
		_construction._paid_upgrade_mask[project_row] = 7
		for line: int in Construction.MATERIAL_SLOTS_PER_PROJECT:
			_construction._delivered_milli[project_row * Construction.MATERIAL_SLOTS_PER_PROJECT + line] = 8000
	assert_true(_router.open_furniture_batch(_owner, _room, _batch, _entries).ok, "free rows initialize completely")
	for index: int in range(0, _batch.count, 2):
		_assert_pair(index)
		assert_false(_construction.is_paused(_batch.ref_at(index + 1)), "old pause cleared")
		assert_equal(_construction._paid_base_type[_batch.typed_rows[index + 1]], Construction.NO_PAID_PACKAGE, "old paid package cleared")
		assert_equal(_construction._paid_upgrade_mask[_batch.typed_rows[index + 1]], 0, "old upgrade receipts cleared")
