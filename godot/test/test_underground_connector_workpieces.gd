extends "res://test/framework/test_case.gd"
## Real finite owners and adopted bills. The additional set-down program below is explicitly SYNTHETIC.

const Workpieces := preload("res://scripts/core/underground_connector_workpieces.gd")
const Prefix := preload("res://test/test_underground_first_prefix.gd")
const EntryFixture := preload("res://test/test_underground_entry_world_bindings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const HaulPlanner := preload("res://scripts/core/haul_planner.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const ConnectorWork := preload("res://scripts/core/underground_connector_work.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const SOURCE_PATH: String = "user://workpiece-synthetic-source.bin"
const SAVE_PATH: String = "user://workpiece-capture.bin"
const PROGRAM_SHA: String = "5353535353535353535353535353535353535353535353535353535353535353"
const SET_DOWN_PROFILE: int = 5

class ObservedWorkpieceContacts extends EntryFixture.ObservedContacts:
	var prepass_probe: Callable = Callable()
	var final_probe: Callable = Callable()

	func prepare_workpiece_start(placement: Vector2i, project: Vector2i, assembly: int) -> StringName:
		"""A real successful prepass can be followed by changed actual facts before any spatial preparation."""
		var code: StringName = super.prepare_workpiece_start(placement, project, assembly)
		if code == &"" and prepass_probe.is_valid():
			var callback: Callable = prepass_probe
			prepass_probe = Callable()
			callback.call()
		return code

	func final_observation_refusal(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
		"""All real source/contact observers finish before the final adversarial mutation and direct payment guard."""
		var code: StringName = super.final_observation_refusal(placement, project, assembly, action)
		if code == &"" and final_probe.is_valid():
			var callback: Callable = final_probe
			final_probe = Callable()
			callback.call()
		return code

class HandlingWorld extends Prefix.ActualWorld:

	func _profile_image(identity: PackedInt32Array) -> PackedByteArray:
		"""Add a separate test-only set-down program/row; existing fastening rows retain their original IDs."""
		var source: PackedByteArray = Prefix.Source.profile_image(identity)
		_raise_fastening(source)
		var bytes: PackedByteArray = source.slice(0, 64)
		bytes.encode_u32(20, 7); bytes.encode_u32(24, 41); bytes.encode_u32(28, 2)
		bytes.append_array(PROGRAM_SHA.hex_decode())
		bytes.append_array(source.slice(64, 64 + 5 * Profiles.PROFILE_WIRE_BYTES))
		var row: PackedByteArray = source.slice(64 + Profiles.PROFILE_WIRE_BYTES, 64 + 2 * Profiles.PROFILE_WIRE_BYTES)
		row.encode_s32(Profiles.F_SOURCE * 4, 1)
		row.encode_s32(Profiles.F_FIRST_BOX * 4, 31)
		bytes.append_array(row)
		row = source.slice(64 + 5 * Profiles.PROFILE_WIRE_BYTES, 64 + 6 * Profiles.PROFILE_WIRE_BYTES)
		row.encode_s32(Profiles.F_FIRST_BOX * 4, 38)
		bytes.append_array(row)
		var boxes: int = 64 + 6 * Profiles.PROFILE_WIRE_BYTES
		bytes.append_array(source.slice(boxes, boxes + 31 * 28))
		bytes.append_array(source.slice(boxes + 3 * 28, boxes + 10 * 28))
		bytes.append_array(source.slice(boxes + 31 * 28, source.size()))
		return bytes

	func _raise_fastening(source: PackedByteArray) -> void:
		"""Only the synthetic yaw0 INSTALL row changes: its actual raised target is128u above the root plane."""
		var start: int = 64 + 6 * Profiles.PROFILE_WIRE_BYTES
		for role: int in [Profiles.WORK_STROKE, Profiles.CONTACT_POINT, Profiles.CONTACT_PATCH]:
			var bounds: PackedInt32Array = PackedInt32Array([112, 125, -459, 141, 128, -437])
			if role == Profiles.CONTACT_POINT: bounds = PackedInt32Array([128, 128, -448, 128, 128, -448])
			if role == Profiles.CONTACT_PATCH: bounds = PackedInt32Array([127, 128, -449, 129, 128, -447])
			for axis: int in 6: source.encode_s32(start + (3 + role) * 28 + 4 * axis, bounds[axis])

class Fixture extends EntryFixture:

	func _make_contacts() -> Contacts:
		"""The same actual packet is observed; the probe cannot supply a permission or skip its real proof."""
		return ObservedWorkpieceContacts.new()

	func _natural_surface() -> void:
		"""The workpiece pocket stays unoccupied; the later near-side transit endpoint is not precreated through it."""
		_anchor = Anchor.new()
		assert_equal(_anchor.configure(_world._world, _world._terrain, _world._owner, _world._sources,
			_world._locations, _world._budget, Anchor.RESERVED_BYTES), &"", "actual natural provider")
		var strips: Array[PackedInt32Array] = [PackedInt32Array([-1792, 0, 192, 1792, 1157, 832]),
			PackedInt32Array([-1792, 0, -3072, -1024, 1157, 192]), PackedInt32Array([1024, 0, -3072, 1792, 1157, 192])]
		var roots: Array[Vector3i] = [Vector3i(-832, 0, 512), Source.side_root(0), Source.side_root(1)]
		_endpoints.resize(9)
		var metadata: PackedInt32Array = Source.world_box(PackedInt32Array([-1792, 0, -3072, 1792, 1, 832]))
		for index: int in strips.size():
			var support: PackedInt32Array = strips[index].duplicate()
			support[1] = -128; support[4] = 0
			var created: Anchor.Result = _anchor.create(ORIGIN + roots[index], Source.world_box(strips[index]),
				Source.world_box(support), Locations.ROLE_WORK, metadata) if index == 0 else \
				_anchor.create_in_section(ORIGIN + roots[index], Source.world_box(strips[index]), Source.world_box(support), _section)
			assert_equal(created.error, &"", "actual natural strip %d" % index)
			_section = created.section
			_endpoints[0 if index == 0 else index + 2] = created.location


	func _make_world() -> Prefix.ActualWorld:
		"""The existing actual World/stock/phase/installation composition consumes the clearly synthetic program."""
		return HandlingWorld.new()

	func _handling_profile() -> int:
		"""The independent template names this fixture's exact synthetic set-down row."""
		return SET_DOWN_PROFILE

class DeliveryWorld extends HandlingWorld:
	## One explicit synthetic loaded-carry row supplements the actual finite source bank for the delivery test only.

	func _profile_image(identity: PackedInt32Array) -> PackedByteArray:
		"""Insert ordered CARRY with actual wood identity/quantity; every original complete role remains unchanged."""
		var source: PackedByteArray = super._profile_image(identity)
		var start: int = 96
		var bytes: PackedByteArray = source.slice(0, start + Profiles.PROFILE_WIRE_BYTES)
		bytes.encode_u32(20, 8); bytes.encode_u32(24, 44)
		var carry: PackedByteArray = source.slice(start, start + Profiles.PROFILE_WIRE_BYTES)
		carry.encode_s32(Profiles.F_SOURCE * 4, 0)
		carry.encode_s32(Profiles.F_MODE * 4, Profiles.MODE_CARRY)
		carry.encode_s32(Profiles.F_CARGO * 4, _items.compiled_id(&"wood"))
		carry.encode_s32(Profiles.F_FIRST_BOX * 4, 3)
		carry.encode_s64(80, 1); carry.encode_s64(88, 2400)
		bytes.append_array(carry)
		for profile: int in range(1, 7):
			var row: PackedByteArray = source.slice(start + profile * Profiles.PROFILE_WIRE_BYTES,
				start + (profile + 1) * Profiles.PROFILE_WIRE_BYTES)
			row.encode_s32(Profiles.F_FIRST_BOX * 4, row.decode_s32(Profiles.F_FIRST_BOX * 4) + 3)
			bytes.append_array(row)
		var boxes: int = start + 7 * Profiles.PROFILE_WIRE_BYTES
		bytes.append_array(source.slice(boxes, boxes + 3 * 28))
		bytes.append_array(source.slice(boxes, source.size()))
		return bytes

	func _load_catalog(revision: int) -> StringName:
		"""Author the explicit loaded ground pace from the existing cap; this is no inferred route or new rate."""
		var bytes: PackedByteArray = Prefix.Source.catalog_image(spec, revision)
		bytes.encode_u32(44, 2)
		bytes.resize(bytes.size() - 8)
		Prefix.CatalogTests._append_row(bytes, PackedInt32Array([1, -1, 0, 0, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(WorldTests.TEMP, _write(WorldTests.TEMP, bytes), revision)

class DeliveryFixture extends Fixture:
	## The same real owners, with finite wood split between actual source and destination at initialization.
	var remote_wood: Vector2i = NULL_REF

	func _make_world() -> Prefix.ActualWorld:
		"""Only this explicit delivery test authors an additional synthetic loaded-carry profile."""
		return DeliveryWorld.new()

	func _handling_profile() -> int:
		"""The added CARRY row shifts the exact synthetic WORK/set-down identifiers by one."""
		return SET_DOWN_PROFILE + 1

	func _frontier_stations(bytes: PackedByteArray) -> void:
		"""Preserve every authored root/face/role while naming the shifted actual WORK rows."""
		var start: int = bytes.size()
		super._frontier_stations(bytes)
		for station: int in 8:
			var offset: int = start + station * 80 + 20
			bytes.encode_s32(offset, bytes.decode_s32(offset) + 1)

	func _stock(key: StringName, quantity: int) -> Vector2i:
		"""The same6,500milli wood starts as2,500 near stock plus4,000 remote goods; hauling creates none."""
		if key != &"wood": return super._stock(key, quantity)
		var made: Inventory.OpResult = _world._inventory.create_lot(_output, _world._items.compiled_id(key),
			4000, 1, Provenance.PROVENANCE_ORDINARY, -1, 0, 0)
		assert_true(made.ok, "finite remote landing bill")
		remote_wood = made.ref
		return super._stock(key, quantity - 4000)

	func _surface_routes() -> void:
		"""Explicit loaded paths cover only source→anchor→store and reverse, with real whole-body/cargo certification."""
		super._surface_routes()
		var lease: int = _world._budget.acquire(Budget.COLD_BYTES)
		var begun: Routes.Result = _world._binding.begin_prepare(lease)
		assert_equal(begun.error, &"", "actual loaded graph preparation")
		for pair: Vector2i in [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 2)]:
			var edge: Routes.Edge = _surface_edge(pair.x, pair.y)
			edge.mode = Profiles.MODE_CARRY
			assert_equal(_world._routes.stage_add(begun.token, edge).error, &"", "explicit loaded span")
		assert_equal(_world._binding.seal(begun.token), &"", "actual complete loaded-body/support certificates")
		assert_equal(_world._binding.publish(begun.token), &"", "actual loaded graph publication")
		_world._binding.abort(begun.token)
		assert_equal(_world._budget.release(lease), &"", "loaded graph scratch released")

	func _select_phase_actor(job: int, ordinal: int) -> void:
		"""Exact source row remapping retains the original real movement and source-qualified phase selection."""
		var worker: int = _world._residents.directory().get_typed_row(_world._worker)
		var profile: int = 3 if ordinal % 2 == 0 else 5
		if _world._routes._resident_ref(worker) != NULL_REF:
			_move_existing_actor(job, _endpoints[3 + ordinal], 49152 if ordinal % 2 == 0 else 16384)
			if not failures.is_empty(): return
			assert_equal(_world._routes.refresh_work_actor(_world._worker, _world._jobs.ref_of(job), profile, 1, 2, 0, -1, _tool),
				&"", "same real actor and exact shifted WORK row")
			return
		var point: Vector3i = ORIGIN + Source.side_root(ordinal)
		assert_true(_world._transforms.place(_world._worker, point.x, point.y, point.z,
			49152 if ordinal % 2 == 0 else 16384), "explicit initial test arrival")
		assert_equal(_world._routes.admit_work_actor(_world._worker, _world._jobs.ref_of(job), _endpoints[3 + ordinal],
			profile, 1, 2, 0, -1, _tool), &"", "actual qualified idle WORK actor")

	func _installation_job(project: Vector2i, endpoint: Vector2i) -> int:
		"""The real grouped quote and worker/tool admission use the shifted exact INSTALL row, never a fake Job."""
		var quote: Modular.Quote = Modular.Quote.new()
		assert_equal(_router.project_facts_into(project, quote), &"", "actual complete assembly quote")
		var made: Jobs.OpResult = _world._jobs.create_job(quote.job_kind, 0, 0, quote.remaining_mwu, 0)
		assert_true(made.ok, "actual installation Job")
		if not made.ok: return -1
		assert_true(_world._jobs.set_requester(made.value, project).ok, "actual requester")
		assert_true(_world._jobs.set_tool_gate(made.value, Jobs.GATE_SATISFIED).ok, "actual tool requirement")
		assert_true(_router.bind_job(project, made.ref).ok, "exact primary Job")
		_assign_installation_worker(made.value, endpoint)
		return made.value

	func _assign_installation_worker(job: int, endpoint: Vector2i) -> void:
		"""Resume the same real installation Job after another capacity-limited shipment, without replacing its identity."""
		var worker: int = _world._residents.directory().get_typed_row(_world._worker)
		assert_true(_world._jobs.assign_worker(worker, job).ok, "same resident")
		assert_true(_world._work.claim_tool_for_work(worker, _tool).ok, "real equipped Gear claim")
		_move_existing_actor(job, endpoint, 0)
		if not failures.is_empty(): return
		assert_equal(_world._routes.refresh_work_actor(_world._worker, _world._jobs.ref_of(job), 2, 1, 2, 0, -1, _tool),
			&"", "exact shifted INSTALL profile")

	func _claim_delivery(project: Vector2i, job: int) -> int:
		"""Several actually delivered lots supply one immutable bill through the existing atomic claim batch."""
		var quote: Modular.Quote = Modular.Quote.new()
		assert_equal(_router.project_facts_into(project, quote), &"", "actual complete bill")
		assert_true(_router.bind_material_container(project, _storage).ok, "exact destination")
		var remaining: int = quote.input_milli[0]
		var batch: PackedInt64Array = PackedInt64Array()
		var count: int = 0
		var lot: Vector2i = _world._inventory.container_first_lot(_storage)
		while lot != NULL_REF and remaining > 0:
			if _world._inventory.lot_item_id(lot) == _world._items.compiled_id(&"wood"):
				var quantity: int = mini(remaining, _world._inventory.lot_available_milli(lot))
				if quantity > 0:
					batch.append_array(PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_MODULAR_INPUT, quantity, 100000]))
					count += 1
					remaining -= quantity
			lot = _world._inventory.container_next_lot(lot)
		assert_true(_world._pool.claim_batch(_world._jobs.ref_of(job), batch, count, _world._inventory).ok,
			"real delivered lots reserved once")
		assert_true(_router.record_deliveries(project).ok, "actual current claims supply delivery credit")
		return quote.input_milli[0] - remaining

	func _pay_installation(project: Vector2i, job: int) -> bool:
		"""A complete physically delivered multi-lot bill pays once through the unchanged Router transaction."""
		assert_equal(_claim_delivery(project, job), 4000, "one full L0 bill in actual destination")
		var started: Construction.OpResult = _router.start_work(project, 0)
		assert_true(started.ok, "actual multi-shipment paid START: %s" % started.error)
		return started.ok

var _fixture: Fixture = null
var _pieces: Workpieces = null


func before_each() -> void:
	"""Bind actual admitted finite sources without creating any Project, paid receipt or obstacle."""
	_fixture = Fixture.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "actual setup: %s" % _fixture.failures)
	_pieces = Workpieces.new()
	assert_equal(_pieces.configure(4, 2, Workpieces.required_bytes(4, 2)), &"", "complete admitted arena")
	assert_equal(_pieces.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), &"", "actual source and paid owners")


func after_each() -> void:
	"""No component may retain a synchronous lease or hide a real Inventory/Reservation audit failure."""
	assert_true(_pieces.is_quiescent(), "no escaped workpiece request")
	_pieces = null
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "actual cleanup: %s" % _fixture.failures)
	_fixture = null
	for path: String in [SOURCE_PATH, SAVE_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _source_image() -> PackedByteArray:
	"""An independent fixed wire names the reviewed whole bearer prisms and the distinct synthetic program."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Workpieces.WIRE_HEADER_BYTES)
	for index: int in 8: bytes[index] = "UGWIPC01".unicode_at(index)
	bytes.encode_u32(8, 1)
	var header: PackedInt64Array = PackedInt64Array([1, _fixture._world._catalog._live.header[0], 1,
		_fixture._groups._reader._header[0], _fixture._groups._recipes._header[0], 2, 2, 0, 1])
	for index: int in 9: bytes.encode_s64(12 + 8 * index, header[index])
	for index: int in 32:
		bytes[84 + index] = _fixture._world._catalog._live.digests[index]
		bytes[116 + index] = _fixture._groups._reader._digests[index]
		bytes[148 + index] = _fixture._groups._recipes._digests[index]
		bytes[180 + index] = PROGRAM_SHA.hex_decode()[index]
	_append_row(bytes, PackedInt32Array([1, 3, 1024, 192, -768, _fixture._handling_profile()]))
	_append_row(bytes, PackedInt32Array([8, 3, 2304, 320, -2816, _fixture._handling_profile()]))
	bytes.append_array("UGWEND01".to_ascii_buffer())
	return bytes


func _append_row(bytes: PackedByteArray, row: PackedInt32Array) -> void:
	"""Independent wire encoding writes six int32 source columns followed by exact profile revision."""
	var start: int = bytes.size()
	bytes.resize(start + 32)
	for field: int in 6: bytes.encode_s32(start + 4 * field, row[field])
	bytes.encode_s64(start + 24, 1)


func _load(bytes: PackedByteArray) -> StringName:
	"""Only the actual immutable source decoder can populate template rows."""
	var file: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return _pieces.load_file(SOURCE_PATH, FileAccess.get_sha256(SOURCE_PATH), 1)


func test_complete_finite_arena_and_once_bound_actual_owners() -> void:
	"""The design ceiling is explicit and refusal allocates no variable bank or foreign owner binding."""
	assert_equal(Workpieces.required_bytes(256, 256), 29928, "all rows, source, stream, controls and provisional native reserve")
	var refused: Workpieces = Workpieces.new()
	assert_equal(refused.configure(256, 256, 29927), Workpieces.REFUSE_CAPACITY, "one byte short refuses")
	assert_equal(refused._live.fields.size(), 0, "no private bank on refusal")
	assert_equal(Workpieces.required_bytes(257, 2), 0, "actual Placement maximum is explicit")
	assert_equal(_pieces.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), Workpieces.REFUSE_BINDING, "once bound")
	assert_true(_pieces.exact_binding(_fixture._placements, _fixture._router), "actual initialized objects")
	assert_false(_pieces.exact_binding(null, _fixture._router), "equal numeric identities never replace owner")


func test_distinct_set_down_program_and_complete_included_parts_load_once() -> void:
	"""Accepted synthetic content is not a production handling certificate and cannot be replaced in place."""
	assert_equal(_load(_source_image()), &"", "complete actual source closure")
	assert_equal(_pieces._parts[Workpieces.PART * 2], 1, "whole included L0 bearer")
	assert_equal(_pieces._parts[Workpieces.PART * 2 + 1], 8, "whole included T0 bearer")
	assert_equal(_pieces._header[Workpieces.H_PROGRAM], 1, "set-down program is separate from fastening source0")
	assert_equal(_pieces._parts[Workpieces.PROFILE * 2], SET_DOWN_PROFILE, "explicit new profile selection")
	assert_equal(_load(_source_image()), Workpieces.REFUSE_SOURCE, "successful source is immutable")
	assert_equal(_pieces._live.present.count(1), 0, "source loading creates no paid piece")


func test_base_or_foreign_contacts_refuse_before_binding_or_final_field_reads() -> void:
	"""Unsupported initialization and a later replacement both refuse cleanly; the original object is pinned once."""
	var candidate: Workpieces = Workpieces.new()
	assert_equal(candidate.configure(4, 2, Workpieces.required_bytes(4, 2)), &"", "admitted independent candidate")
	assert_equal(_load(_source_image()), &"", "existing original source")
	var original: WeakRef = _fixture._paid._contacts
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	for replacement: RefCounted in [ConnectorWork.Contacts.new(), Contacts.new()]:
		_fixture._paid._contacts = weakref(replacement)
		assert_equal(candidate.bind_actual(_fixture._placements, _fixture._router, _fixture._paid),
			Workpieces.REFUSE_BINDING, "base or unconfigured foreign Contacts cannot activate")
		assert_equal(candidate._placements, null, "refusal publishes no partial owner binding")
		assert_equal(candidate._contacts, null, "refusal pins no unsupported Contacts object")
		assert_equal(Workpieces._binding_leaf(_pieces), Workpieces.REFUSE_BINDING, "original identity checked first")
		assert_equal(_pieces.capture_into(file), Workpieces.REFUSE_STAGE, "late substitution refuses before capture")
		assert_equal(file.get_position(), 0, "refused capture leaves output unchanged")
	_fixture._paid._contacts = original
	assert_equal(candidate.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), &"", "exact initialization retry")
	assert_equal(_pieces.capture_into(file), &"", "original source and Contacts retry")
	file.close()


func test_foreign_frontier_refuses_initialization_and_current_source_without_diagnostics() -> void:
	"""A typed but foreign Frontier never becomes an immutable source merely by occupying the known Contacts field."""
	var candidate: Workpieces = Workpieces.new()
	assert_equal(candidate.configure(4, 2, Workpieces.required_bytes(4, 2)), &"", "admitted candidate")
	assert_equal(_load(_source_image()), &"", "existing actual source")
	var contacts: Contacts = _fixture._paid._contacts.get_ref() as Contacts
	var original: Frontier = contacts._frontier
	contacts._frontier = Frontier.new()
	assert_equal(candidate.bind_actual(_fixture._placements, _fixture._router, _fixture._paid),
		Workpieces.REFUSE_BINDING, "foreign source refuses at ordinary initialization")
	assert_equal(candidate._placements, null, "source failure leaves binding untouched")
	assert_equal(Workpieces._binding_leaf(_pieces), Workpieces.REFUSE_SOURCE, "current typed source checked directly")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert_equal(_pieces.capture_into(file), Workpieces.REFUSE_STAGE, "source replacement refuses current capture")
	assert_equal(file.get_position(), 0, "no bytes on source refusal")
	contacts._frontier = original
	assert_equal(candidate.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), &"", "original Frontier retry")
	assert_equal(_pieces.capture_into(file), &"", "exact actual source remains usable")
	file.close()


func test_final_initialization_refusal_retains_no_binding_and_allows_exact_retry() -> void:
	"""A concrete invalid owner tuple must not strand a configured candidate with partially published references."""
	var candidate: Workpieces = Workpieces.new()
	assert_equal(candidate.configure(4, 2, Workpieces.required_bytes(4, 2)), &"", "admitted unbound candidate")
	var original: Budget = _fixture._placements._budget
	_fixture._placements._budget = null
	var code: StringName = candidate.bind_actual(_fixture._placements, _fixture._router, _fixture._paid)
	var bindings: Array = [candidate._placements, candidate._router, candidate._paid_owner, candidate._contacts,
		candidate._budget, candidate._catalog, candidate._assemblies, candidate._recipes, candidate._profiles]
	_fixture._placements._budget = original
	assert_equal(code, Workpieces.REFUSE_BINDING, "actual missing Budget refuses final composition")
	assert_equal(bindings, [null, null, null, null, null, null, null, null, null], "every binding remains unpublished")
	assert_equal(candidate._live.present.count(1), 0, "no paid row is created")
	assert_equal(candidate._header.count(0), 9, "no immutable source was partially loaded")
	assert_true(candidate.is_quiescent(), "refusal retains no synchronous context")
	assert_equal(candidate.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), &"", "restored actual tuple retries")
	assert_true(candidate.exact_binding(_fixture._placements, _fixture._router), "successful retry retains real owners")


func test_second_bill_or_missing_actual_part_refuses_without_retained_source() -> void:
	"""A visual prism from the next assembly cannot be charged or owned by the current whole bill."""
	var bytes: PackedByteArray = _source_image()
	bytes.encode_s32(Workpieces.WIRE_HEADER_BYTES, 8)
	assert_equal(_load(bytes), Workpieces.REFUSE_SOURCE, "cross-group part is not included")
	assert_false(_pieces._loaded, "failed source unpublished")
	assert_equal(_pieces._parts.count(0), _pieces._parts.size(), "failed private rows cleared")
	bytes = _source_image()
	bytes.encode_s32(Workpieces.WIRE_HEADER_BYTES + 32, 14)
	assert_equal(_load(bytes), Workpieces.REFUSE_SOURCE, "nonexistent part cannot fabricate timber")
	assert_equal(_load(_source_image()), &"", "exact source retry")


func test_fastening_or_stale_profile_cannot_replace_distinct_handling_source() -> void:
	"""Neither an existing INSTALL row nor a same-ID stale revision can grant set-down permission."""
	var bytes: PackedByteArray = _source_image()
	bytes.encode_s32(Workpieces.WIRE_HEADER_BYTES + 20, 1)
	assert_equal(_load(bytes), Workpieces.REFUSE_PROFILE, "actual existing fastening row belongs to another program")
	bytes = _source_image()
	bytes.encode_s64(Workpieces.WIRE_HEADER_BYTES + 24, 2)
	assert_equal(_load(bytes), Workpieces.REFUSE_PROFILE, "exact handling revision required")
	bytes = _source_image()
	bytes.encode_s64(12 + 8 * Workpieces.H_PROGRAM, 0)
	for index: int in 32: bytes[180 + index] = 7
	for row: int in 2: bytes.encode_s32(Workpieces.WIRE_HEADER_BYTES + 32 * row + 20, 1)
	assert_equal(_load(bytes), Workpieces.REFUSE_PROFILE, "coherent header/digest/row cannot substitute the real fastening program")
	assert_equal(_load(_source_image()), &"", "exact profile source retry")


func test_live_source_drift_and_world_generation_refuse_even_empty_capture() -> void:
	"""Every read checks actual current profiles/source/World, not just a cached successful decoder result."""
	assert_equal(_load(_source_image()), &"", "source loaded")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var profiles: Profiles = _fixture._world._profiles
	profiles._live.header[0] += 1
	assert_equal(_pieces.capture_into(file), Workpieces.REFUSE_STAGE, "current content replacement refuses")
	assert_equal(file.get_position(), 0, "no capture bytes before validation")
	profiles._live.header[0] -= 1
	var original: int = _fixture._world._residents._directory._generation[_fixture._world._world_ref.x]
	_fixture._world._residents._directory._generation[_fixture._world._world_ref.x] += 1
	assert_equal(_pieces.capture_into(file), Workpieces.REFUSE_STAGE, "full World generation required")
	_fixture._world._residents._directory._generation[_fixture._world._world_ref.x] = original
	assert_equal(_pieces.capture_into(file), &"", "exact binding retry")
	file.close()


func test_streamed_empty_restore_preserves_live_bank_on_malformed_full_refs() -> void:
	"""Restore uses the already-admitted spare bank and refuses a fabricated paid row without publication."""
	assert_equal(_load(_source_image()), &"", "source loaded")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert_equal(_pieces.capture_into(file), &"", "streamed quiescent capture")
	file.close()
	file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	assert_equal(file.get_length(), 60 + 4 * 21, "exact wire, no full retained image")
	assert_equal(_pieces.restore_from(file), &"", "same complete actual owner composition")
	file.close()
	file = FileAccess.open(SAVE_PATH, FileAccess.READ_WRITE)
	file.seek(60); file.store_8(1); file.store_32(1)
	file.close()
	file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var old_bank: Workpieces.Bank = _pieces._live
	assert_equal(_pieces.restore_from(file), Workpieces.REFUSE_PROJECT, "full actual paid identities required")
	assert_true(_pieces._live == old_bank, "refused restore never swaps live bank")
	assert_equal(_pieces._live.present.count(1), 0, "no paid obstacle fabricated")
	file.close()


func test_absent_reciprocal_publication_context_cannot_create_paid_workpiece() -> void:
	"""Even a valid source and coincident cold number cannot impersonate actual initialized publication owners."""
	assert_equal(_load(_source_image()), &"", "valid source")
	var out: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5, 6])
	assert_equal(_pieces.bounds_into(NULL_REF, NULL_REF, out), Workpieces.REFUSE_PROJECT, "no invented future Project")
	assert_equal(out, PackedInt32Array([1, 2, 3, 4, 5, 6]), "refused output unchanged")
	var lease: int = _fixture._world._budget.acquire(Budget.COLD_BYTES)
	assert_equal(_pieces.prepare_start(NULL_REF, NULL_REF, lease), Workpieces.REFUSE_BINDING, "missing reciprocal concrete owners")
	assert_false(Workpieces.publish_start_preflighted(_pieces, NULL_REF), "no public publication permission boolean")
	assert_false(Workpieces.clear_preflighted(_pieces, NULL_REF, Contract.CANCEL), "no foreign cancel tail")
	assert_equal(_fixture._world._budget.release(lease), &"", "original lease still belongs to caller")


func test_adopted_wood_mass_and_payload_handling_are_not_repriced_per_visual_prism() -> void:
	"""Actual bill and item registration establish20kg/5kg assemblies; partial shipment policy remains existing hauling."""
	var quote: Contract.Quote = Contract.Quote.new()
	var groups: RefCounted = _fixture._groups._reader
	var recipes: RefCounted = _fixture._groups._recipes
	var item: int = _fixture._world._items.compiled_id(&"wood")
	assert_equal(_fixture._world._inventory.item_mass_g(item), 5000, "actual adopted wood mass")
	assert_equal(recipes.recipe_into(0, 1, groups._recipe_anchor[0], recipes._header[0], quote), &"", "one L0 assembly bill")
	assert_equal(quote.input_milli[0], 4000, "four wood units, no price for included bearer again")
	assert_equal(quote.input_milli[0] * _fixture._world._inventory.item_mass_g(item), 20000000, "exact grams numerator")
	assert_equal(recipes.recipe_into(0, 1, groups._recipe_anchor[1], recipes._header[0], quote), &"", "one T0 bill")
	assert_equal(quote.input_milli[0], 1000, "one wood unit")
	assert_equal(HaulPlanner.HAUL_LOAD_MILLI_WU, 2000, "actual load policy per payload")
	assert_equal(HaulPlanner.HAUL_UNLOAD_MILLI_WU, 2000, "actual unload policy per payload")


func _ready_l0() -> Vector2i:
	"""All four full cubes finish through real Sites/Funding/Work/companions before one real next-assembly order."""
	assert_equal(_load(_source_image()), &"", "distinct immutable set-down source")
	assert_equal(_fixture._paid.bind_workpieces(_pieces), &"", "actual reciprocal once-bound workpieces")
	var room: Vector2i = _fixture._confirm_prefix()
	if room == NULL_REF or not _fixture.failures.is_empty(): return NULL_REF
	if not _fixture._complete_l0_cubes(): return NULL_REF
	var project: Vector2i = _fixture._open_installation(0)
	assert_true(_fixture.failures.is_empty(), "actual four-cube lifecycle: %s" % _fixture.failures)
	return project


func test_actual_l0_start_publishes_one_paid_raised_non_supporting_workpiece() -> void:
	"""Real paid owners publish the complete included bearer only after full delivery and distinct synthetic handling proof."""
	var project: Vector2i = _ready_l0()
	if project == NULL_REF: return
	var job: int = _fixture._installation_job(project, _fixture._endpoints[0])
	if job < 0: return
	if not _fixture._pay_installation(project, job): return
	var placement: Vector2i = _fixture._world._construction.subject_ref_of(project)
	var region: Vector2i = _pieces.workpiece_region(placement, project)
	assert_true(region != NULL_REF, "one exact live Project-owned obstacle")
	assert_equal(_pieces._live.present.count(1), 1, "no separate quantity or per-part receipt")
	assert_true(_fixture._router._funding.is_funded(project), "actual original Funding receipt")
	assert_equal(_fixture._world._owner._r_role[region.x], Prefix.Space.OBSTACLE, "never support")
	assert_equal(_fixture._world._owner._r_lo_y[region.x], Prefix.ORIGIN.y, "piece bottom on actual floor")
	assert_equal(_fixture._world._owner._r_hi_y[region.x], Prefix.ORIGIN.y + 128, "real raised fastening top")
	assert_equal(_fixture._placements._get32(_fixture._placements._live, Prefix.Placements.INSTALLED, placement.x), 0,
		"START does not install the assembly")
	assert_true(_pieces.is_quiescent() and _fixture._world._budget.is_quiescent(), "original scratch released after publication")


func _started_l0() -> Vector2i:
	"""One complete real four-cube cut sequence, grouped wood delivery and actual paid raised-piece publication."""
	var project: Vector2i = _ready_l0()
	if project == NULL_REF: return NULL_REF
	var job: int = _fixture._installation_job(project, _fixture._endpoints[0])
	if job < 0 or not _fixture._pay_installation(project, job): return NULL_REF
	assert_true(_fixture.failures.is_empty(), "real paid START: %s" % _fixture.failures)
	return project


func test_real_work_completion_removes_piece_before_retiring_project_and_installs_once() -> void:
	"""The same genuine Funding receipt becomes the complete paid L0; temporary geometry never survives retirement."""
	var project: Vector2i = _started_l0()
	if project == NULL_REF: return
	var placement: Vector2i = _fixture._world._construction.subject_ref_of(project)
	var region: Vector2i = _pieces.workpiece_region(placement, project)
	var job: int = _fixture._router._primary_row(project)
	_fixture._earn_actual_phase(job)
	assert_true(_fixture.failures.is_empty(), "real productive contact and all remaining work: %s" % _fixture.failures)
	if not _fixture.failures.is_empty(): return
	var result: Construction.OpResult = _fixture._router.complete_order(project)
	assert_true(result.ok, "actual paid completion: %s" % result.error)
	if not result.ok: return
	assert_equal(_pieces._live.present.count(1), 0, "no WIP row remains")
	assert_equal(Workpieces._removed_leaf(_pieces, project, region), &"", "exact Region and Project source removed")
	assert_false(_fixture._world._construction._directory.is_valid(project), "Project retires only after physical cleanup")
	assert_equal(_fixture._placements._get32(_fixture._placements._live, Prefix.Placements.INSTALLED, placement.x), 1,
		"one whole billed group, no partial installed bearer")
	assert_equal(_fixture._world._inventory.lot_quantity_milli(_fixture._wood), 1500, "wood charged once including temporary bearer")
	_fixture._assert_timber_prisms(7)
	assert_true(_fixture.failures.is_empty(), "every actual included solid: %s" % _fixture.failures)


func test_blocked_real_refund_keeps_piece_and_receipt_then_partial_work_refunds_exactly() -> void:
	"""A refused destination cannot delete paid WIP; successful paused cancellation returns the actual proportional bill."""
	var project: Vector2i = _started_l0()
	if project == NULL_REF: return
	var placement: Vector2i = _fixture._world._construction.subject_ref_of(project)
	var region: Vector2i = _pieces.workpiece_region(placement, project)
	assert_true(_fixture._world._work.tick_solo(_fixture._router._primary_row(project)).ok, "actual partial useful work")
	var refund: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_fixture._world._construction.cancellation_refund_milli_into(project, 0, refund), "actual refund policy")
	assert_true(refund.value > 0 and refund.value < 4000, "partial progress incurs actual material loss")
	assert_true(_fixture._world._construction.set_paused(project, true).ok, "paused cancellation remains legal")
	assert_true(_fixture._world._inventory.set_container_reachable(_fixture._storage, false).ok, "real destination blocked")
	var funding: PackedByteArray = _fixture._router._funding.state_bytes()
	var geometry: PackedByteArray = _fixture._world._owner.state_bytes()
	assert_false(_fixture._router.cancel_order(project, _fixture._storage).ok, "refused physical refund")
	assert_equal(_pieces.workpiece_region(placement, project), region, "the same full obstacle stays live")
	assert_equal(_fixture._router._funding.state_bytes(), funding, "same actual receipt")
	assert_equal(_fixture._world._owner.state_bytes(), geometry, "no partial spatial removal")
	assert_true(_fixture._world._inventory.set_container_reachable(_fixture._storage, true).ok, "real destination restored")
	_assert_refund_result(project, placement, region, refund.value)


func _assert_refund_result(project: Vector2i, placement: Vector2i, region: Vector2i, refund: int) -> void:
	"""The successful shared settlement owns all returned goods and cancellation loss; Workpieces owns neither."""
	var item: int = _fixture._world._items.compiled_id(&"wood")
	var before: int = _fixture._world._inventory.total_live_milli(item)
	var result: Construction.OpResult = _fixture._router.cancel_order(project, _fixture._storage)
	assert_true(result.ok, "actual paid cancellation: %s" % result.error)
	if not result.ok: return
	assert_equal(_fixture._world._inventory.total_live_milli(item), before + refund, "only actual refund enters Inventory")
	assert_equal(_fixture._router._funding.purpose_cancellation_loss_milli(Construction.PURPOSE_CONNECTOR_INSTALL, item),
		4000 - refund, "actual shared loss domain, no duplicate escrow")
	assert_equal(_pieces._live.present.count(1), 0, "successful refund clears one row")
	assert_equal(Workpieces._removed_leaf(_pieces, project, region), &"", "physical and source retirement before Project")
	assert_equal(_fixture._placements._get32(_fixture._placements._live, Prefix.Placements.INSTALLED, placement.x), 0,
		"cancel preserves the original installed prefix")
	assert_false(_fixture._world._construction._directory.is_valid(project), "paid Project retired")


func test_paid_capture_refuses_omitted_row_and_restores_exact_live_obstacle() -> void:
	"""A syntactically empty row cannot orphan an existing receipt; streamed restore retains the same real handles."""
	var project: Vector2i = _started_l0()
	if project == NULL_REF: return
	var placement: Vector2i = _fixture._world._construction.subject_ref_of(project)
	var region: Vector2i = _pieces.workpiece_region(placement, project)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert_equal(_pieces.capture_into(file), &"", "real paid capture")
	file.close()
	file = FileAccess.open(SAVE_PATH, FileAccess.READ_WRITE)
	file.seek(60 + 21 * placement.x)
	for byte: int in 21: file.store_8(0)
	file.close()
	var bank: Workpieces.Bank = _pieces._live
	file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	assert_equal(_pieces.restore_from(file), Workpieces.REFUSE_PROJECT, "actual Funding requires its complete row")
	file.close()
	assert_true(_pieces._live == bank, "failed restore keeps original bank")
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert_equal(_pieces.capture_into(file), &"", "uncorrupted current identity capture")
	file.close()
	file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	assert_equal(_pieces.restore_from(file), &"", "exact real owner restore")
	file.close()
	assert_equal(_pieces.workpiece_region(placement, project), region, "same full obstacle after restore")


func test_first_productive_read_observes_new_terrain_revision_before_actual_worker_leaf() -> void:
	"""A successful stale-receipt observation cannot credit a worker moved by that same real observer."""
	var project: Vector2i = _started_l0()
	if project == NULL_REF: return
	var terrain: Prefix.WorldTests.ReenteringTerrain = _fixture._world._terrain as Prefix.WorldTests.ReenteringTerrain
	assert_true(terrain._checked_geometry_revision != _fixture._world._owner.revision(), "set-down really changed Space")
	terrain.binding_countdown = 1
	terrain.binding_probe = _move_worker_after_terrain
	_assert_refused_tick(project)
	assert_equal(terrain.binding_probe_count, 1, "one normal World-source attestation ran")
	assert_true(_fixture._world._transforms.place(_fixture._world._worker, Prefix.ORIGIN.x - 832,
		Prefix.ORIGIN.y, Prefix.ORIGIN.z + 512, 0), "restore actual arrived pose")
	assert_true(_fixture._world._work.tick_solo(_fixture._router._primary_row(project)).ok, "exact real retry earns work")
	assert_equal(terrain._checked_geometry_revision, _fixture._world._owner.revision(), "ordinary Terrain reader owns its receipt")


func _move_worker_after_terrain() -> void:
	"""The actual Transform mutates after a successful ordinary Terrain binding observation."""
	assert_true(_fixture._world._transforms.place(_fixture._world._worker, Prefix.ORIGIN.x - 832,
		Prefix.ORIGIN.y, Prefix.ORIGIN.z + 1024, 0), "real departed worker")


func _assert_refused_tick(project: Vector2i) -> void:
	"""An observer can mutate its own facts, but cannot earn WU, XP, wear or change the existing paid receipt."""
	var work: PackedByteArray = _fixture._world._work.state_bytes()
	var gear: PackedByteArray = _fixture._world._gear.state_bytes()
	var payment: PackedByteArray = _fixture._router._funding.state_bytes()
	var inventory: PackedByteArray = _fixture._world._inventory.state_bytes()
	var row: int = _fixture._world._residents.directory().get_typed_row(project)
	var remaining: int = _fixture._world._construction._remaining_mwu[row]
	assert_false(_fixture._world._work.tick_solo(_fixture._router._primary_row(project)).ok, "changed final facts refuse work")
	assert_equal(_fixture._world._work.state_bytes(), work, "no WU or XP")
	assert_equal(_fixture._world._gear.state_bytes(), gear, "no durability or wear")
	assert_equal(_fixture._router._funding.state_bytes(), payment, "no receipt change")
	assert_equal(_fixture._world._inventory.state_bytes(), inventory, "no quantity change")
	assert_equal(_fixture._world._construction._remaining_mwu[row], remaining,
		"Project labor unchanged")


func test_first_productive_terrain_observer_cannot_replace_actual_binding() -> void:
	"""An equal freshly configured Terrain object is still not the original once-bound Contacts reader."""
	var project: Vector2i = _started_l0()
	if project == NULL_REF: return
	var replacement: Prefix.ContactTests.Terrain = Prefix.ContactTests.Terrain.new()
	assert_equal(replacement.configure(_fixture._world._world, _fixture._world._nodes, _fixture._world._owner,
		_fixture._world._sources, _fixture._world._items, _fixture._world._budget), &"", "valid equal foreign reader")
	var terrain: Prefix.WorldTests.ReenteringTerrain = _fixture._world._terrain as Prefix.WorldTests.ReenteringTerrain
	terrain.binding_countdown = 1
	terrain.binding_probe = _replace_route_terrain.bind(replacement)
	_assert_refused_tick(project)
	assert_equal(terrain.binding_probe_count, 1, "late valid reader replacement happened")
	_fixture._world._binding._terrain = terrain
	assert_true(_fixture._world._work.tick_solo(_fixture._router._primary_row(project)).ok, "original binding retry succeeds")


func _replace_route_terrain(replacement: Prefix.ContactTests.Terrain) -> void:
	"""Only the injected observer rewires its provider; production Contacts must detect the changed owner."""
	_fixture._world._binding._terrain = replacement


func test_first_productive_terrain_observer_cannot_advance_original_geometry_revision() -> void:
	"""A successful actual Space publication after Terrain returns invalidates the original Contact observation."""
	var project: Vector2i = _started_l0()
	if project == NULL_REF: return
	var terrain: Prefix.WorldTests.ReenteringTerrain = _fixture._world._terrain as Prefix.WorldTests.ReenteringTerrain
	terrain.binding_countdown = 1
	terrain.binding_probe = _publish_new_geometry_after_terrain
	_assert_refused_tick(project)
	assert_equal(terrain.binding_probe_count, 1, "actual late geometry mutation ran")
	assert_true(terrain._checked_geometry_revision != _fixture._world._owner.revision(), "no silent receipt promotion")


func _publish_new_geometry_after_terrain() -> void:
	"""A real natural anchor updates Space and retained Inventory endpoint receipts together."""
	var owner: Prefix.Owner = _fixture._world._owner
	var before: int = owner.revision()
	var result: Prefix.Anchor.Result = _fixture._anchor.create_in_section(Prefix.ORIGIN + Vector3i(1280, 0, 512),
		Prefix.Source.world_box(PackedInt32Array([1152, 0, 384, 1408, 900, 640])),
		Prefix.Source.world_box(PackedInt32Array([1152, -128, 384, 1408, 0, 640])), _fixture._section)
	assert_equal(result.error, &"", "actual late natural anchor proof and publication")
	assert_equal(owner.revision(), before + 1, "actual late Space publication")


func _use_delivery_fixture() -> void:
	"""Compose another real source graph with explicit synthetic cargo geometry and the same finite total goods."""
	_pieces = null
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "prior empty setup remains clean")
	_fixture = DeliveryFixture.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "delivery source setup: %s" % _fixture.failures)
	_pieces = Workpieces.new()
	assert_equal(_pieces.configure(4, 2, Workpieces.required_bytes(4, 2)), &"", "one Workpieces packet only")
	assert_equal(_pieces.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), &"", "same actual owners")


func test_two_real_capacity_limited_payloads_supply_one_complete_landing_bill() -> void:
	"""Explicit source/destination dispatch tests real carrying and work; automatic planner spatial selection stays open."""
	_use_delivery_fixture()
	if not failures.is_empty(): return
	var project: Vector2i = _ready_l0()
	if project == NULL_REF: return
	var delivery: DeliveryFixture = _fixture as DeliveryFixture
	assert_equal(_fixture._world._inventory.lot_quantity_milli(_fixture._wood), 1500, "only local brace stock remains")
	var first: int = _deliver_payload(delivery.remote_wood, 4000)
	assert_equal(first, 2400, "actual mouse12kg limit splits20kg landing bill")
	if not failures.is_empty() or not _fixture.failures.is_empty(): return
	assert_equal(_delivered_wood(), 3900, "first shipment cannot fund4,000")
	var job: int = _partial_delivery_refusal(project, delivery)
	if job < 0 or not failures.is_empty(): return
	var second: int = _deliver_payload(delivery.remote_wood, 4000 - first)
	assert_equal(second, 1600, "second actual8kg payload supplies the remainder")
	if not failures.is_empty() or not _fixture.failures.is_empty(): return
	assert_equal(_delivered_wood(), 5500, "all original finite stock conserved")
	delivery._assign_installation_worker(job, _fixture._endpoints[0])
	assert_true(_fixture._pay_installation(project, job), "whole bill claims only physically delivered stock")
	assert_equal(_delivered_wood(), 1500, "one complete bill, no handling surcharge")
	assert_equal(_pieces._live.present.count(1), 1, "one paid static bearer after two actual shipments")


func _delivered_wood() -> int:
	"""Observe all real destination lots; unloading need not merge their full identities."""
	var total: int = 0
	var lot: Vector2i = _fixture._world._inventory.container_first_lot(_fixture._storage)
	while lot != NULL_REF:
		if _fixture._world._inventory.lot_item_id(lot) == _fixture._world._items.compiled_id(&"wood"):
			total += _fixture._world._inventory.lot_quantity_milli(lot)
		lot = _fixture._world._inventory.container_next_lot(lot)
	return total


func _partial_delivery_refusal(project: Vector2i, delivery: DeliveryFixture) -> int:
	"""The actual primary Job, worker, tool and partial claims cannot start an incompletely delivered assembly."""
	var job: int = delivery._installation_job(project, _fixture._endpoints[0])
	if job < 0: return -1
	assert_equal(delivery._claim_delivery(project, job), 3900, "actual partial destination claims")
	assert_equal(_fixture._router.start_work(project, 0).error, Construction.REFUSE_WRONG_PHASE,
		"real incomplete bill remains AWAITING_MATERIALS")
	assert_equal(_pieces._live.present.count(1), 0, "no workpiece before complete material admission")
	assert_false(_fixture._router._funding.is_funded(project), "no WIP receipt for partial stock")
	assert_true(_fixture._world._pool.release_job_claims(_fixture._world._jobs.ref_of(job), _fixture._world._inventory).ok,
		"release unchanged loose goods for next complete claim batch")
	var worker: int = _fixture._world._residents.directory().get_typed_row(_fixture._world._worker)
	assert_true(_fixture._world._work.release_tool_claim(worker).ok, "release productive claim for hauling")
	assert_true(_fixture._world._jobs.release_worker(worker).ok, "same resident can fetch the next payload")
	return job


func _deliver_payload(source: Vector2i, remaining: int) -> int:
	"""The unchanged policy sizes a real claim; actual Jobs/Work, satchel and graph carry it to the selected endpoint."""
	var worker: int = _fixture._world._residents.directory().get_typed_row(_fixture._world._worker)
	var limit: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_fixture._world._carry.carry_limit_g_into(worker, limit), "actual species carry limit")
	assert_equal(limit.value, 12000, "ordinary mouse, no large-worker prerequisite")
	assert_true(HaulPlanner.payload_milli_into(remaining, 5000, limit.value, 0, limit), "actual checked payload sizing")
	var quantity: int = limit.value
	var job: Prefix.Jobs.OpResult = _fixture._world._jobs.create_job(Prefix.Jobs.JOB_KIND_HAUL, 0, 0,
		HaulPlanner.handling_milli_wu(true, false), 0)
	assert_true(job.ok, "actual haul Job")
	assert_true(_fixture._world._jobs.assign_worker(worker, job.value).ok, "actual single hauler")
	var actor: Prefix.Routes.Actor = _fixture._walk_existing_ground(job.value, _fixture._endpoints[2])
	assert_equal(actor.location, _fixture._endpoints[2], "actual arrival at source before load")
	if not failures.is_empty() or not _fixture.failures.is_empty(): return 0
	var loaded: Vector2i = _load_payload(job, worker, source, quantity)
	if loaded == NULL_REF: return 0
	if not _carry_payload(job.value, loaded, quantity): return 0
	assert_true(_fixture._world._jobs.set_remaining_mwu(job.value, HaulPlanner.handling_milli_wu(false, false)).ok,
		"existing unload phase costs2,000mWU")
	_earn_handling(job.value, HaulPlanner.HAUL_UNLOAD_MILLI_WU)
	var unloaded: Prefix.Inventory.OpResult = _fixture._world._carry.unload_into_store(job.ref, worker, _fixture._storage, quantity * 5)
	assert_true(unloaded.ok, "actual spatial Inventory unload: %s" % unloaded.error)
	assert_equal(unloaded.value, quantity, "every claimed milli-unit arrives once")
	assert_equal(_fixture._world._carry.satchel_of(worker), NULL_REF, "one payload satchel retired")
	assert_true(_fixture._world._jobs.release_worker(worker).ok, "completed haul releases assignment")
	assert_true(_fixture._world._jobs.destroy_job(job.value).ok, "actual haul Job retired")
	return quantity


func _load_payload(job: Prefix.Jobs.OpResult, worker: int, source: Vector2i, quantity: int) -> Vector2i:
	"""Source goods enter one actual owned satchel only after load work and the real claim/headroom transaction."""
	assert_true(_fixture._world._inventory.reserve_container_mass(_fixture._storage, quantity * 5).ok, "actual destination headroom")
	var batch: PackedInt64Array = PackedInt64Array([source.x, source.y, Prefix.ContactTests.Reservations.PURPOSE_HAUL_SOURCE,
		quantity, 100000])
	assert_true(_fixture._world._pool.claim_batch(job.ref, batch, 1, _fixture._world._inventory).ok, "actual source reservation")
	_earn_handling(job.value, HaulPlanner.HAUL_LOAD_MILLI_WU)
	if not failures.is_empty(): return NULL_REF
	var result: Prefix.Inventory.OpResult = _fixture._world._carry.load_payload(job.ref, worker, source)
	assert_true(result.ok, "actual physical payload: %s" % result.error)
	assert_equal(result.value, quantity, "exact capacity-limited payload")
	assert_equal(_fixture._world._inventory.lot_container(result.ref), _fixture._world._carry.satchel_of(worker),
		"goods exist in the actual hauler's sole satchel")
	return result.ref if result.ok else NULL_REF


func _earn_handling(job: int, expected: int) -> void:
	"""Use the real Work owner until the exact existing load/unload phase is complete, without adding progress directly."""
	assert_true(_fixture._world._jobs.set_state(job, Prefix.Jobs.JOB_STATE_WORK).ok, "actual handling WORK state")
	var accepted: int = 0
	for tick: int in 600:
		var result: Prefix.ContactTests.Work.TickResult = _fixture._world._work.tick_solo(job)
		assert_true(result.ok, "actual handling tick: %s" % result.error)
		if not result.ok: return
		accepted += result.accepted_mwu
		if result.remaining_mwu == 0: break
	assert_equal(accepted, expected, "exact adopted handling work per payload phase")


func _carry_payload(job: int, lot: Vector2i, quantity: int) -> bool:
	"""Reachability alone is insufficient: actual cargo stays in its satchel throughout all route ticks."""
	assert_true(_fixture._world._jobs.set_state(job, Prefix.Jobs.JOB_STATE_HAUL_OUTPUT).ok, "actual carry phase")
	assert_equal(_fixture._world._routes.refresh_actor(_fixture._world._worker, _fixture._world._jobs.ref_of(job),
		Profiles.MODE_CARRY, Profiles.POSTURE_UPRIGHT, -1, _fixture._tool), &"", "exact synthetic loaded-body source")
	assert_equal(_fixture._world._routes.request_route(_fixture._world._worker, _fixture._endpoints[1], 0), &"",
		"actual certified ground path with the real payload")
	if not failures.is_empty(): return false
	var actor: Prefix.Routes.Actor = Prefix.Routes.Actor.new()
	for tick: int in 600:
		_fixture._world._routes.advance_tick(tick)
		assert_equal(_fixture._world._routes.read_actor_into(_fixture._world._worker, actor), &"", "current loaded actor")
		assert_equal(_fixture._world._inventory.lot_quantity_milli(lot), quantity, "cargo conserved during travel")
		if actor.phase == Prefix.Routes.PHASE_IDLE: break
		if actor.phase == Prefix.Routes.PHASE_HELD: break
	assert_equal(actor.location, _fixture._endpoints[1], "worker physically arrived before unload work")
	return actor.location == _fixture._endpoints[1]


func _ready_installation_bill() -> Vector2i:
	"""Prepare the original real whole bill and Job while leaving every irreversible START operation pending."""
	var project: Vector2i = _ready_l0()
	if project == NULL_REF: return NULL_REF
	var job: int = _fixture._installation_job(project, _fixture._endpoints[0])
	if job < 0: return NULL_REF
	assert_true(_fixture._router.bind_material_container(project, _fixture._storage).ok, "actual material destination")
	var batch: PackedInt64Array = PackedInt64Array([_fixture._wood.x, _fixture._wood.y,
		Prefix.ContactTests.Reservations.PURPOSE_MODULAR_INPUT, 4000, 100000])
	assert_true(_fixture._world._pool.claim_batch(_fixture._world._jobs.ref_of(job), batch, 1,
		_fixture._world._inventory).ok, "complete real destination bill claimed")
	assert_true(_fixture._router.record_deliveries(project).ok, "actual complete READY order")
	return project


func test_prepared_piece_translation_or_full_handle_replacement_cannot_escape_last_contact_guard() -> void:
	"""A once-valid raised target cannot be moved into body/approach space or replaced before actual payment."""
	var project: Vector2i = _ready_installation_bill()
	if project == NULL_REF: return
	var contacts: ObservedWorkpieceContacts = _fixture._contacts as ObservedWorkpieceContacts
	for mutation: int in 2:
		contacts.final_probe = _change_prepared_piece.bind(mutation)
		_assert_start_unchanged(project)
		assert_false(contacts.final_probe.is_valid(), "real final observer reached")
		assert_true(_pieces.is_quiescent() and _fixture._world._budget.is_quiescent(), "only original candidates dropped")
	assert_true(_fixture._router.start_work(project, 0).ok, "same untouched real order retries successfully")


func _change_prepared_piece(mutation: int) -> void:
	"""Test-only corruption changes the actual sealed bank after full proof; no caller box is accepted as authority."""
	assert_true(_fixture._contacts._valid, "complete real contact proof preceded injected mutation")
	var owner: Prefix.Owner = _fixture._world._owner
	var region: Vector2i = _pieces._context.obstacle
	assert_true(region != NULL_REF and owner._s_r_present[region.x] == 1, "exact original prepared obstacle")
	if mutation == 0:
		owner._s_r_lo_z[region.x] += 448
		owner._s_r_hi_z[region.x] += 448
	else:
		owner._s_r_generation[region.x] += 1


func _assert_start_unchanged(project: Vector2i) -> void:
	"""Refusal rolls back staged inputs and leaves all paid/work/geometry owners byte-identical."""
	var economy: Array[PackedByteArray] = _fixture._economic_image()
	var space: PackedByteArray = _fixture._world._owner.state_bytes()
	var funding: PackedByteArray = _fixture._router._funding.state_bytes()
	var work: PackedByteArray = _fixture._world._work.state_bytes()
	var gear: PackedByteArray = _fixture._world._gear.state_bytes()
	assert_false(_fixture._router.start_work(project, 0).ok, "changed final target/source refuses real START")
	_fixture._assert_economic_image(economy)
	assert_equal(_fixture._world._owner.state_bytes(), space, "no partial spatial publication")
	assert_equal(_fixture._router._funding.state_bytes(), funding, "no paid receipt")
	assert_equal(_fixture._world._work.state_bytes(), work, "no work or XP")
	assert_equal(_fixture._world._gear.state_bytes(), gear, "no tool wear")
	assert_equal(_pieces._live.present.count(1), 0, "no workpiece row")


func test_material_change_after_unprivileged_prepass_refuses_without_target_or_payment() -> void:
	"""A successful live endpoint/material prepass grants no target permission and cannot mask changed real reachability."""
	var project: Vector2i = _ready_installation_bill()
	if project == NULL_REF: return
	var contacts: ObservedWorkpieceContacts = _fixture._contacts as ObservedWorkpieceContacts
	contacts.prepass_probe = _block_prepass_material
	var funding: PackedByteArray = _fixture._router._funding.state_bytes()
	var space: PackedByteArray = _fixture._world._owner.state_bytes()
	assert_false(_fixture._router.start_work(project, 0).ok, "changed original material observation refuses")
	assert_false(contacts.prepass_probe.is_valid(), "successful prepass was observed")
	assert_equal(_fixture._router._funding.state_bytes(), funding, "no payment")
	assert_equal(_fixture._world._owner.state_bytes(), space, "no physical piece")
	assert_equal(_delivered_wood(), 5500, "all original loose goods stay at destination")
	assert_true(_fixture._world._inventory.set_container_reachable(_fixture._storage, true).ok, "restore real source fact")
	assert_true(_fixture._router.start_work(project, 0).ok, "same original full tuple retries")


func _block_prepass_material() -> void:
	"""Only the ordinary actual Inventory reachability setter changes, after endpoints were pinned but before staging."""
	assert_false(_fixture._contacts._valid, "prepass is explicitly unprivileged")
	assert_true(_pieces._context == null and _fixture._world._owner._stage_token == 0, "no premature private spatial image")
	assert_true(_fixture._world._inventory.set_container_reachable(_fixture._storage, false).ok, "actual material became unreachable")


func test_actual_profile_reload_after_prepass_cannot_prepare_or_pay_old_source() -> void:
	"""Equal geometry with a new actual content revision invalidates the unprivileged observed source tuple."""
	_assert_source_reload_prevents_start(false)


func test_actual_profile_reload_after_final_contact_cannot_pay_prepared_piece() -> void:
	"""The original sealed obstacle and successful contact observation cannot outlive an actual source reload."""
	_assert_source_reload_prevents_start(true)


func _assert_source_reload_prevents_start(prepared: bool) -> void:
	"""Use the actual immutable loader at the selected callback boundary and assert unchanged paid owners."""
	var project: Vector2i = _ready_installation_bill()
	if project == NULL_REF: return
	var contacts: ObservedWorkpieceContacts = _fixture._contacts as ObservedWorkpieceContacts
	if prepared: contacts.final_probe = _reload_observed_profiles.bind(prepared)
	else: contacts.prepass_probe = _reload_observed_profiles.bind(prepared)
	_assert_start_unchanged(project)
	assert_equal(_fixture._world._profiles.content_revision(), 3, "real source replacement was accepted")
	assert_false(contacts.final_probe.is_valid() or contacts.prepass_probe.is_valid(), "exact observer boundary ran")
	assert_true(_pieces.is_quiescent() and _fixture._world._budget.is_quiescent(), "only original scratch discarded")


func _reload_observed_profiles(prepared: bool) -> void:
	"""No copied permission flag changes: the real decoder loads equal geometry under a newer source revision."""
	assert_equal(_pieces._context != null, prepared, "requested before-copy or sealed-candidate boundary")
	assert_equal(_fixture._contacts._valid, prepared, "only prepared state had a complete physical contact proof")
	_fixture._replace_actual_profiles()
