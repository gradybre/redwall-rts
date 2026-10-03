extends "res://test/framework/test_case.gd"
## Actual Layout→RoomOrders→Router→Directory/Buildings/Construction/Space composition.
## Only finished-shell/profile/contact facts are SYNTHETIC; no production activation is claimed.

const Fixture := preload("res://test/test_underground_furniture_work.gd")
const Layout := preload("res://scripts/core/room_layout.gd")
const Sources := preload("res://scripts/core/underground_layout_sources.gd")
const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const SpaceOwner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const BENCH: int = 5
const HEARTH: int = 2
const NULL_REF: Vector2i = Vector2i(-1, 0)
const GEOMETRY: int = 16
const PLACEMENTS: int = 8

class SyntheticLayoutBindings extends Fixture.SyntheticBindings:

	## Actual finite Budget and source geometry; only the author's shape/contact certification is synthetic.
	var budget: Budget = Budget.new()
	var budget_available: bool = true
	var scope: int = 0
	var scope_room: Vector2i = NULL_REF
	var planner_bytes: int = 0
	var batch_bytes: int = 0
	var begin_calls: int = 0
	var end_calls: int = 0
	var snapshot_calls: int = 0
	var layout_publications: int = 0
	var layout_discards: int = 0
	var floor_ref: Vector2i = NULL_REF
	var catalog: RoomCatalog = RoomCatalog.new()
	var snapshot: Layout.Snapshot = null
	var selected: Layout.Batch = null
	var candidates: Directory.CreateBatch = null
	var input_request: Layout.Batch = null
	var plan_error: StringName = &""
	var prepared_error: StringName = &""
	var mutation: int = 0
	var mutate_scope: bool = false
	var reenter: bool = false
	var reentry_results: PackedByteArray = PackedByteArray()
	var clear_published_packet: bool = false
	var revoke_in_plan: bool = false
	var foreign_token: int = 0
	var accepted_refs: PackedInt32Array = PackedInt32Array()
	var accepted_entries: PackedInt32Array = PackedInt32Array()

	func layout_budget_owner() -> Budget:
		"""Expose this fixture's actual arena so stale numeric tokens cannot certify copied packets."""
		return budget if budget_available else null

	func begin_layout_cold(room: Vector2i, bytes: int, _geometry: int,
			_placements: int, extra: int) -> int:
		"""Admit explicit fixture native/image allowance along with both production packed bounds."""
		begin_calls += 1
		if not cold_allowed or scope != 0:
			return 0
		scope = budget.acquire(bytes + extra + 16384)
		if scope > 0:
			scope_room = room
			planner_bytes = bytes
			batch_bytes = extra
		return scope

	func layout_cold_refusal() -> StringName:
		"""No lease is fabricated when another actual operation owns the arena."""
		return Budget.REFUSE_BUSY if cold_allowed else Budget.REFUSE_BYTES

	func layout_scope_refusal(token: int, room: Vector2i, bytes: int, extra: int) -> StringName:
		"""Check real token/charge; deliberately adversarial callback changes remain observable."""
		if mutate_scope and input_request != null:
			mutate_scope = false
			input_request.entries[3] = 1
		if reenter:
			_attempt_reentry()
		return &"" if token == scope and room == scope_room and bytes == planner_bytes \
			and extra == batch_bytes and budget.covers(token, bytes + extra + 16384) else Layout.REFUSE_SCOPE

	func _attempt_reentry() -> void:
		"""Each real coordinator entry must refuse while the provider callback owns the exclusive command."""
		reenter = false
		var actual: RoomOrders = orders.get_ref() as RoomOrders
		reentry_results.append(int(actual.begin_layout_operation(scope_room, planner_bytes, GEOMETRY, PLACEMENTS) == 0))
		reentry_results.append(int(actual.end_layout_operation(scope, scope_room) != &""))
		reentry_results.append(int(not actual.accept_layout(input_request, scope).ok))
		reentry_results.append(int(not actual.confirm_room(RoomOrders.RoomPlan.new()).ok))

	func layout_snapshot(token: int, room: Vector2i, _geometry: int, _placements: int) -> Layout.Snapshot:
		"""Borrow a synthetic completed 4x4 shell while preserving actual Room/type and accepted identities."""
		if token != scope or room != scope_room or not budget.covers(token, planner_bytes + batch_bytes):
			return null
		snapshot_calls += 1
		snapshot = Layout.Snapshot.new()
		snapshot.room_ref = room
		snapshot.room_type = construction.buildings().type_of_room(room).value
		snapshot.revision = space.revision()
		snapshot.pitch_units = 2048
		snapshot.shell_complete = shell_complete
		snapshot.allowed_types_mask = catalog.allowed_types_mask(snapshot.room_type)
		_fill_floor(snapshot)
		_fill_profiles(snapshot)
		snapshot.object_refs = accepted_refs.duplicate()
		snapshot.object_entries = accepted_entries.duplicate()
		@warning_ignore("integer_division") var object_count: int = accepted_refs.size() / 2
		snapshot.object_kinds.resize(object_count)
		snapshot.object_kinds.fill(Layout.DOMAIN_FURNITURE)
		return snapshot

	func _fill_floor(out: Layout.Snapshot) -> void:
		"""This is an explicitly authored test floor and connected approach, not production terrain permission."""
		for z: int in 4:
			for x: int in 4:
				var row: int = z * 4 + x
				out.floor_xy.append_array(PackedInt32Array([x, z]))
				out.floor_height.append(-4096)
				out.ceiling_height.append(0)
				out.room_cells.append(row)
				if x == 0:
					out.protected_cells.append(row)
				if x > 0:
					out.walk_links.append_array(PackedInt32Array([row - 1, row]))
				if z > 0:
					out.walk_links.append_array(PackedInt32Array([row - 4, row]))
		out.entries = PackedInt32Array([0])

	func _fill_profiles(out: Layout.Snapshot) -> void:
		"""All allowed catalog types retain separately authored fixture height and install/use contacts."""
		out.profiles.resize(RoomCatalog.FURNITURE_COUNT)
		for type_id: int in RoomCatalog.FURNITURE_COUNT:
			var profile: Layout.Profile = Layout.Profile.new()
			profile.height_units = 1024
			profile.install_xy = PackedInt32Array([0, 1])
			profile.use_xy = PackedInt32Array([0, 1])
			out.profiles[type_id] = profile

	func layout_plan_refusal(token: int, request: Layout.Batch, packet: Directory.CreateBatch,
			space_token: int) -> StringName:
		"""Retain current source-backed pending obstacles; no installation or service is published here."""
		if token != scope or request.expected_revision != space.revision() or not shell_complete:
			return &"SYNTHETIC_LAYOUT_STALE_OR_UNFINISHED"
		selected = request
		candidates = packet
		@warning_ignore("integer_division") var count: int = packet.count / 2
		for index: int in count:
			var code: StringName = _stage_piece(space_token, packet.ref_at(index * 2), request, index)
			if code != &"":
				return code
		if mutation == 1:
			request.entries[3] = 1
		if mutation == 2:
			packet.generations[packet.count - 1] += 1
		if revoke_in_plan:
			budget.release(scope)
			foreign_token = budget.acquire(planner_bytes + batch_bytes + 16384)
		return plan_error

	func _stage_piece(token: int, piece: Vector2i, request: Layout.Batch, index: int) -> StringName:
		"""Actual pending geometry uses the rotated protected catalog floor footprint and full section identity."""
		var offset: int = index * Layout.ENTRY_STRIDE
		var facts: RoomCatalog.FurnitureFacts = catalog.furniture(request.entries[offset], request.entries[offset + 3])
		if not facts.ok:
			return facts.error
		var x: int = request.entries[offset + 1] * request.pitch_units
		var z: int = request.entries[offset + 2] * request.pitch_units
		var region: SpaceOwner.Region = SpaceOwner.Region.new()
		region.owner = piece
		region.role = Space.OBSTACLE
		region.section = floor_ref
		region.level = request.level
		region.box = PackedInt32Array([x, -4096, z, x + facts.footprint_units.x, -3072, z + facts.footprint_units.y])
		return space.stage_add(token, region).error

	func layout_prepared_refusal(token: int, request: Layout.Batch, packet: Directory.CreateBatch,
			_space_token: int) -> StringName:
		"""Final callback is still preallocation; changing even its last tuple must refuse all pairs."""
		if token != scope or selected != request or candidates != packet:
			return &"SYNTHETIC_LAYOUT_CANDIDATE"
		if mutation == 3:
			packet.persistent_ids[packet.count - 1] += 1
		if mutation == 4:
			request.level += 1
		return prepared_error

	func publish_layout(token: int, request: Layout.Batch, packet: Directory.CreateBatch,
			_space_token: int) -> void:
		"""Companion sees real pending typed rows and one exact publication, then drops borrowed candidate input."""
		assert(token == scope and request == selected and packet == candidates, "same prepared physical candidate")
		var actual: RoomOrders = orders.get_ref() as RoomOrders
		assert(actual.is_publishing_furniture_admissions(request.room_ref, packet), "real synchronous permit")
		@warning_ignore("integer_division") var count: int = packet.count / 2
		for index: int in count:
			var piece: Vector2i = packet.ref_at(index * 2)
			assert(construction.buildings().is_live_furniture(piece), "actual typed Furniture precedes companion")
			accepted_refs.append_array(PackedInt32Array([piece.x, piece.y]))
		accepted_entries.append_array(request.entries)
		layout_publications += 1
		if clear_published_packet:
			request.entries.clear()
			packet.reset()
		selected = null
		candidates = null

	func discard_layout(_token: int, _room: Vector2i, _space_token: int) -> void:
		"""Dropping one unpublished companion never changes accepted real claims or another cold operation."""
		layout_discards += 1
		selected = null
		candidates = null

	func end_layout_cold(token: int, room: Vector2i) -> StringName:
		"""Drop borrowed snapshot before releasing only the actual original token; observe no live candidate."""
		if token != scope or room != scope_room:
			return Layout.REFUSE_SCOPE
		assert(not space.has_prepared(), "all candidate geometry dropped before scope release")
		assert(selected == null and candidates == null, "all companion input dropped before scope release")
		snapshot = null
		var code: StringName = budget.release(token)
		scope = 0
		end_calls += 1
		return code

var _f: Fixture.Fixture = null
var _bindings: SyntheticLayoutBindings = null
var _sources: Sources = null
var _token: int = 0


func before_each() -> void:
	"""Use actual shared accounting and geometry from the paid-installation fixture, not a synthetic Router."""
	_bindings = SyntheticLayoutBindings.new()
	_f = Fixture.Fixture.new(self, true, _bindings)
	_f.make_room()
	_bindings.floor_ref = _f.floor_ref
	_sources = Sources.new(_f.orders)


func after_each() -> void:
	"""Every test returns actual ownership to quiescence and checks material/claim conservation."""
	if _token > 0 and _bindings.scope > 0:
		_sources.end_operation(_token, _f.room)
	if _bindings.foreign_token > 0:
		_bindings.budget.release(_bindings.foreign_token)
	assert_true(_bindings.budget.is_quiescent(), "no held shared arena")
	_f.audit()
	_sources = null
	_f = null
	_bindings = null
	_token = 0


func _begin() -> void:
	"""Acquire the exact same actual arena before any packet/image copy."""
	_token = _sources.begin_operation(_f.room, Layout.cold_packed_bytes(GEOMETRY, PLACEMENTS), GEOMETRY, PLACEMENTS)
	assert_true(_token > 0, "actual shared lease")


func _request() -> Layout.Batch:
	"""Select two compatible catalog footprints on separated rows; callers choose no prices or work."""
	var request: Layout.Batch = Layout.Batch.new()
	request.room_ref = _f.room
	request.room_type = Buildings.ROOM_TYPE_KITCHEN
	request.level = 0
	request.pitch_units = 2048
	request.expected_revision = _f.space.revision()
	request.entries = PackedInt32Array([BENCH, 1, 0, 0, HEARTH, 1, 2, 0])
	return request


func _image() -> PackedByteArray:
	"""Include allocator generation/heaps along with every actual physical, paid, equipment and worker byte."""
	var image: PackedByteArray = _f.image()
	image.append_array(_f.buildings.directory().state_bytes())
	return image


func _refused(request: Layout.Batch) -> void:
	"""No refusal may publish a prefix, consume identity history, pay material or create installed services."""
	var before: PackedByteArray = _image()
	var result: Layout.Submission = _sources.submit(request, _token)
	assert_true(result != null and not result.ok, "whole layout refused")
	assert_true(_image() == before, "all actual owner bytes unchanged")
	assert_equal(_f.buildings.live_furniture_count(), 0, "no Furniture prefix")
	assert_equal(_f.construction.live_project_count(), 0, "no Project prefix")
	assert_false(_f.space.has_prepared(), "no retained candidate")


func test_actual_batch_reserves_pending_furniture_projects_and_exact_geometry_together() -> void:
	"""A complete empty shell can accept furnishings despite having no installed service prerequisites."""
	_begin()
	assert_false(_f.buildings.room_is_valid(_f.room), "unfurnished Kitchen is not a ready service")
	var result: Layout.Submission = _sources.submit(_request(), _token)
	assert_true(result.ok, "actual paired acceptance: %s" % result.error)
	assert_equal(result.project_refs.size(), 4, "one full real project per selected piece")
	assert_equal(_bindings.layout_publications, 1, "one actual companion publication")
	for index: int in 2:
		var project: Vector2i = Vector2i(result.project_refs[index * 2], result.project_refs[index * 2 + 1])
		var piece: Vector2i = _f.construction.subject_ref_of(project)
		assert_true(_f.construction.is_live_project(project), "actual Project generation")
		assert_true(_f.buildings.is_live_furniture(piece), "actual Furniture generation")
		assert_false(_f.buildings.is_furniture_installed(piece), "no unpaid installation")
		assert_equal(_f.space.source_refusal(piece), &"", "sealed real pending geometry")
		assert_false(_f.funding.is_funded(project), "acceptance consumes no materials")
		assert_false(_f.construction.has_work_begun(project), "acceptance grants no productive work")
	assert_equal(_f.buildings.furniture_mask_of(_f.room).value, 0, "pending grants no service mask")


func test_final_publication_may_discard_borrowed_inputs_without_losing_the_receipt() -> void:
	"""Receipt storage is filled before a legitimate final companion clears its mutable borrowed packet."""
	_begin()
	_bindings.clear_published_packet = true
	var result: Layout.Submission = _sources.submit(_request(), _token)
	assert_true(result.ok, "committed acceptance stays truthful")
	assert_equal(result.project_refs.size(), 4, "complete preallocated receipt survives cleanup")
	for index: int in 2:
		assert_true(_f.construction.is_live_project(Vector2i(result.project_refs[index * 2], result.project_refs[index * 2 + 1])), "real accepted identity")
	assert_equal(_f.construction.live_project_count(), 2, "exactly once actual Project count")


func test_full_catalog_bill_and_real_work_remain_required_after_layout_acceptance() -> void:
	"""A batch-generated subject enters the same actual paid installation path as individual admission."""
	_begin()
	var result: Layout.Submission = _sources.submit(_request(), _token)
	assert_true(result.ok, "paired accepted projects")
	var project: Vector2i = Vector2i(result.project_refs[0], result.project_refs[1])
	var piece: Vector2i = _f.construction.subject_ref_of(project)
	assert_equal(_sources.end_operation(_token, _f.room), &"", "release before worker simulation")
	_token = 0
	var job: Vector2i = _f.bind_job(project)
	_f.start(project)
	_f.finish(project, job)
	assert_true(_f.router.complete_order(project).ok, "actual funded work publishes installation")
	assert_true(_f.buildings.is_furniture_installed(piece), "only earned work installs presence")
	assert_equal(_f.space.source_refusal(piece), &"", "actual installed facts and geometry agree")


func test_purpose_shell_and_late_geometry_refusals_spend_no_identity_prefix() -> void:
	"""Room semantics, unfinished physical shell and late companion rejection all refuse the entire batch."""
	_begin()
	var request: Layout.Batch = _request()
	request.entries[0] = int(Catalog.FURNITURE_DEFINITION["bed"])
	_refused(request)
	_bindings.shell_complete = false
	_refused(_request())
	_bindings.shell_complete = true
	_bindings.prepared_error = &"SYNTHETIC_LATE_CONTACT"
	_refused(_request())


func test_every_provider_mutation_of_entries_or_directory_tuples_refuses_all_pairs() -> void:
	"""Pinned observations cover early geometry callbacks and the final source/owner preflight callback."""
	_begin()
	for value: int in [1, 2, 3, 4]:
		_bindings.mutation = value
		_refused(_request())


func test_initial_scope_callback_cannot_change_the_original_unpinned_request() -> void:
	"""The request and exact allocator observations are copied before the first acceptance callback."""
	_begin()
	var request: Layout.Batch = _request()
	_bindings.input_request = request
	_bindings.mutate_scope = true
	_refused(request)
	assert_equal(request.entries[3], 1, "adversarial callback actually changed caller input")


func test_provider_reentry_cannot_end_or_replace_the_running_layout_scope() -> void:
	"""Exclusivity precedes every nested provider invocation and protects the actual operation token."""
	_begin()
	_bindings.input_request = _request()
	_bindings.reenter = true
	var result: Layout.Submission = _sources.submit(_bindings.input_request, _token)
	assert_true(result.ok, "outer whole batch succeeds")
	assert_equal(_bindings.reentry_results, PackedByteArray([1, 1, 1, 1]), "all nested entry paths refuse")
	assert_true(_bindings.budget.covers(_token, _bindings.planner_bytes + _bindings.batch_bytes), "original token retained")


func test_reacquired_foreign_budget_token_cannot_authorize_future_source_publication() -> void:
	"""A remembered local held flag cannot stand in for the exact actual live Budget token."""
	_begin()
	_bindings.revoke_in_plan = true
	_refused(_request())
	assert_true(_bindings.foreign_token != _token, "actual new ownership token")
	assert_true(_bindings.budget.covers(_bindings.foreign_token, 1), "foreign scope retained")
	assert_true(_sources.end_operation(_token, _f.room) != &"", "cannot release a foreign reacquisition")
	assert_true(_bindings.budget.covers(_bindings.foreign_token, 1), "cleanup preserves foreign lease")
	_token = 0


func test_refused_or_busy_cold_admission_never_enters_snapshot_or_sparse_copy() -> void:
	"""Actual memory permission is checked before the first provider image or Space candidate allocation."""
	var stages: int = _f.space.stage_calls
	_bindings.cold_allowed = false
	assert_equal(_sources.begin_operation(_f.room, Layout.cold_packed_bytes(GEOMETRY, PLACEMENTS), GEOMETRY, PLACEMENTS), 0, "budget refusal")
	_bindings.cold_allowed = true
	_bindings.foreign_token = _bindings.budget.acquire(64)
	assert_equal(_sources.begin_operation(_f.room, Layout.cold_packed_bytes(GEOMETRY, PLACEMENTS), GEOMETRY, PLACEMENTS), 0, "already-owned arena")
	assert_equal(_bindings.snapshot_calls, 0, "no snapshot copy")
	assert_equal(_f.space.stage_calls, stages, "no sparse bank copy")


func test_missing_actual_budget_owner_refuses_before_any_provider_acquisition_or_copy() -> void:
	"""A successful exact-binding boolean cannot substitute for an actual shared arena owner."""
	_bindings.budget_available = false
	var stages: int = _f.space.stage_calls
	assert_equal(_sources.begin_operation(_f.room, Layout.cold_packed_bytes(GEOMETRY, PLACEMENTS), GEOMETRY, PLACEMENTS), 0, "missing actual arena")
	assert_equal(_bindings.begin_calls, 0, "never invoke acquiring provider without exact Budget")
	assert_equal(_bindings.snapshot_calls, 0, "no snapshot copy")
	assert_equal(_f.space.stage_calls, stages, "no staged world copy")


func test_stale_room_revision_and_generation_refuse_without_changed_owner_bytes() -> void:
	"""Fine coordinates and actual Room identity remain pinned to the observed real source revision."""
	_begin()
	var request: Layout.Batch = _request()
	request.expected_revision -= 1
	_refused(request)
	request = _request()
	request.room_ref.y += 1
	_refused(request)


func test_direct_requests_cannot_bypass_planner_pitch_level_or_shape_bounds() -> void:
	"""No malformed direct Batch may enter provider arithmetic or allocate an identity prefix."""
	_begin()
	for pitch: int in [0, 3, 2049, 9223372036854775807]:
		var malformed: Layout.Batch = _request()
		malformed.pitch_units = pitch
		_refused(malformed)
	var request: Layout.Batch = _request()
	request.level = Space.I32_MAX + 1
	_refused(request)
	request = _request()
	request.entries.resize(7)
	_refused(request)


func test_layout_scope_and_receipt_end_before_the_next_simulation_or_input_operation() -> void:
	"""Synchronous release drops accepted receipt buffers and the actual shared cold lease together."""
	_begin()
	var result: Layout.Submission = _sources.submit(_request(), _token)
	assert_true(result.ok, "whole batch accepted")
	assert_equal(_sources.end_operation(_token, _f.room), &"", "same-input release")
	assert_true(result.project_refs.is_empty(), "borrowed receipt dropped before shared release")
	assert_true(_bindings.budget.is_quiescent(), "worker simulation can resume")
	assert_false(_f.orders.has_layout_scope(), "coordinator returned to idle")
	_token = 0


func test_one_scope_cannot_retain_multiple_accepted_receipt_buffers() -> void:
	"""Even direct typed Sources use cannot accumulate another simultaneous receipt under the same cold charge."""
	_begin()
	var result: Layout.Submission = _sources.submit(_request(), _token)
	assert_true(result.ok, "first complete batch")
	var before: PackedByteArray = _image()
	assert_false(_sources.can_submit(_token), "accepted scope has no second receipt allowance")
	assert_false(_sources.submit(_request(), _token).ok, "second submission requires a new input scope")
	assert_true(_image() == before, "no repeated state mutation")
	assert_equal(result.project_refs.size(), 4, "original live receipt retained for consumption")
