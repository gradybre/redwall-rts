extends "res://test/framework/test_case.gd"
## Atomic next-contact publication; actual paid/source fixture is kept separate from malformed-input checks.

const Publication := preload("res://scripts/core/underground_room_frontier_publication.gd")
const Frontier := preload("res://scripts/core/underground_room_frontier.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const LocationFixture := preload("res://test/test_underground_locations.gd")
const Published := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
class ObservedBuildings extends Phase.Buildings:
	## A real public Room reader can mutate only the candidate after its graph seals; all normal facts still run.
	var route_owner: WeakRef = null
	var face_owner: WeakRef = null
	var probe: Callable = Callable()
	var calls: int = 0

	func room_identity_into(ref: Vector2i, out: PackedInt32Array) -> StringName:
		"""The callback executes after a successful actual source copy and before the new direct publication guard."""
		var code: StringName = super.room_identity_into(ref, out)
		var binding: WorldRoutes = route_owner.get_ref() as WorldRoutes if route_owner != null else null
		var face: Publication.Face = face_owner.get_ref() as Publication.Face if face_owner != null else null
		if code == &"" and binding != null and (binding._sealed or (face != null and face._reading)) and probe.is_valid():
			var callback: Callable = probe
			probe = Callable(); calls += 1
			callback.call()
		return code

class LateralFixture extends Phase.SourceFixture:
	## This diagnostic adds only actual inherited ground rates for automatic WALK1; source boxes remain immutable.
	var parking: Vector2i = NULL_REF

	func _actual_profiles() -> void:
		"""Choose the observed actual Buildings owner while it is empty, before binding any World/Room authority."""
		_buildings = ObservedBuildings.new(_residents.directory())
		_construction = Phase.WorldFixture.Construction.new(_buildings)
		super._actual_profiles()

	func after_each() -> void:
		"""No callback or original borrower outlives the actual fixture stores."""
		(_buildings as ObservedBuildings).probe = Callable()
		(_buildings as ObservedBuildings).route_owner = null
		(_buildings as ObservedBuildings).face_owner = null
		super.after_each()

	func _load_catalog(revision: int) -> StringName:
		"""All three ground selectors inherit the same existing Movement rate; no invented speed or source flag."""
		var bytes: PackedByteArray = Phase.GroupFixture._catalog_wire(4, revision)
		bytes.encode_u32(44, 3); bytes.encode_s64(48, 2); bytes.resize(bytes.size() - 80)
		for profile: int in [1, 5, 9]:
			Phase.GroupFixture.Fixture._append_row(bytes, PackedInt32Array([profile, -1, 0, 1, 1, 0, Phase.WorldFixture.Catalog.RATE_GROUND_CAP]), 1)
		var digest: PackedByteArray = PackedByteArray(); digest.resize(32)
		assert_true(_profiles.source_hash_into(0, 2, digest), "actual actor source")
		for index: int in 32: bytes[72 + index] = digest[index]
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(Phase.WorldFixture.TEMP, _write(Phase.WorldFixture.TEMP, bytes), revision)

	func connect_source_paths() -> void:
		"""An actual existing-corridor parking contact lets the worker clear future station occupancy by real travel."""
		parking = _endpoint(Vector3i(Phase.X - 3072, Phase.FLOOR, Phase.Z + 512), Locations.ROLE_TRANSIT)
		super.connect_source_paths()
		var token: int = _begin()
		for reverse: bool in [false, true]:
			var edge: Routes.Edge = _edge()
			edge.from_location = parking if reverse else _first; edge.to_location = _first if reverse else parking
			edge.points = PackedInt32Array([Phase.X - 3072 if reverse else Phase.X - 1024, Phase.FLOOR, Phase.Z + 512,
				Phase.X - 1024 if reverse else Phase.X - 3072, Phase.FLOOR, Phase.Z + 512]); edge.length_u = 2048
			assert_equal(_routes.stage_add(token, edge).error, &"", "complete real parking span")
		assert_equal(_binding.seal(token), &"", "parking certificates")
		assert_equal(_binding.publish(token), &"", "parking graph publication")
		_end(token)

	func park_after_settlement() -> void:
		"""The actual source-ready backward actor moves into the existing corridor, preserving full paid history."""
		assert_equal(_routes.request_route(_worker, parking, tick), &"", "actual continued backward parking")
		wait_ready(NULL_REF, 9)
		var actor: Routes.Actor = Routes.Actor.new()
		assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual parked actor")
		assert_equal(actor.location, parking, "exact parked full endpoint")

var _h: Phase.SourceFixture = null
var _local: LocationFixture = null
var _cold: int = 0
var _context: Locations.FrontierContext = null
var _records: Array[Locations.Record] = []
var _heap_patch: PackedInt32Array = PackedInt32Array()
var _mutation: int = -1
var _pending_output: Publication.Result = null


func after_each() -> void:
	"""Drop exact private candidates, then release only the test's original cold lease."""
	if _local != null:
		if _local._locations._token > 0: _local._locations.abort(_local._locations._token)
		_local._locations._frontier = null; _context = null
		if _cold > 0: assert_equal(_local._cold.release(_cold), &"", "original component lease")
		_local.after_each(); assert_true(_local.failures.is_empty(), "actual Location fixture: %s" % _local.failures)
	if _h != null:
		if _cold > 0: assert_equal(_h._budget.release(_cold), &"", "original phase lease")
		_h.after_each(); assert_true(_h.failures.is_empty(), "actual paid fixture: %s" % _h.failures)
	_h = null; _local = null; _cold = 0; _context = null; _records.clear(); _heap_patch.clear()
	_pending_output = null


func _location_scope() -> void:
	"""Actual stores with explicitly synthetic surface geometry test transaction ownership, never production permission."""
	_local = LocationFixture.new(); _local.before_each()
	_cold = _local._cold.acquire(Budget.COLD_BYTES)
	assert_true(_cold > 0, "complete original cold admission")
	_context = Locations.FrontierContext.new(); _context.count = 2
	_context.refs.resize(6); _context.edges.resize(12); _records.resize(3)
	_heap_patch.resize(Locations.FRONTIER_HEAP_WORDS)
	_context.locations = _local._locations; _context.owner = _local._owner; _context.budget = _local._cold
	_context.live = _local._locations._live; _context.candidate = _local._locations._stage
	_context.world = _local._world; _context.revision = _local._owner.revision(); _context.cold = _cold


func _sealed_locations() -> void:
	"""Two prospective rows are genuine fully checked metadata in the actual inactive Location bank."""
	_location_scope()
	assert_equal(_local._locations.hold_frontier(_context), &"", "original synchronous owner")
	var begun: Locations.Result = _local._locations.begin_frontier_prepare(_context)
	assert_equal(begun.error, &"", "exact held preparation")
	_records[0] = _local._record(-512); _records[0].role = Locations.ROLE_TRANSIT
	_records[1] = _local._record(512); _records[1].role = Locations.ROLE_WORK
	for row: Locations.Record in [_records[0], _records[1]]:
		row.world = _local._world; row.geometry_revision = _context.revision
		var added: Locations.Result = _local._locations.stage_add(begun.token, row)
		assert_equal(added.error, &"", "full actual support and air")
		row.payload_revision = added.location.y
		var index: int = 0 if row == _records[0] else 1
		_context.refs[index * 2] = added.location.x; _context.refs[index * 2 + 1] = added.location.y
	assert_equal(_local._locations.seal(begun.token), &"", "real sealed two-row candidate")


func _component_ref(index: int) -> Vector2i:
	"""Read only the test's actual allocated full generation; no slot-only identity escapes."""
	return Vector2i(_context.refs[index * 2], _context.refs[index * 2 + 1])


func _sentinel_record() -> Locations.Record:
	"""One fixed caller packet makes refused copy behavior observable."""
	var out: Locations.Record = Locations.Record.new()
	out.envelope = PackedInt32Array([1, 2, 3, 4, 5, 6]); out.support = PackedInt32Array([7, 8, 9, 10, 11, 12])
	out.point = Vector3i(77, 88, 99); out.room = Vector2i(71, 9)
	return out


func test_cross_section_long_spans_refuse_and_four_directed_spans_fit() -> void:
	"""The actual fixture's section extents require a boundary endpoint in both directions."""
	var old_section: PackedInt32Array = PackedInt32Array([-4096, -4608, -2048, 2048, -4607, 4096])
	var paid_section: PackedInt32Array = PackedInt32Array([2048, -4608, 0, 4096, -4607, 2048])
	var gateway: Vector3i = Vector3i(1280, -4608, 512)
	var boundary: Vector3i = Vector3i(2048, -4608, 512)
	var work: Vector3i = Vector3i(2304, -4608, 512)
	assert_equal(Publication.section_span_refusal(gateway, work, old_section), Publication.REFUSE_SECTION, "old section cannot own the interior in Kitchen")
	assert_equal(Publication.section_span_refusal(work, gateway, paid_section), Publication.REFUSE_SECTION, "Kitchen cannot own old corridor interior")
	assert_equal(Publication.section_span_refusal(gateway, boundary, old_section), &"", "forward outer")
	assert_equal(Publication.section_span_refusal(boundary, work, paid_section), &"", "forward inner")
	assert_equal(Publication.section_span_refusal(work, boundary, paid_section), &"", "reverse inner")
	assert_equal(Publication.section_span_refusal(boundary, gateway, old_section), &"", "reverse outer")
	assert_equal(Publication.section_span_refusal(boundary, Vector3i(2048, -4608, 1024), old_section), Publication.REFUSE_SECTION, "exclusive far boundary cannot own a parallel interior")


func test_unbound_publication_and_direct_tail_preserve_output() -> void:
	"""No caller-created packet or context substitutes for actual owners and the retained publication window."""
	var out: Publication.Result = Publication.Result.new()
	out.work = Vector2i(71, 9)
	assert_equal(Publication.publish_into(null, Frontier.Candidate.new(), Publication.Request.new(), 1, 1000, out), Frontier.REFUSE_BINDING, "unbound coordinator refuses")
	assert_equal(out.work, Vector2i(71, 9), "unchanged refused output")
	assert_false(WorldRoutes.commit_frontier_preflighted(null, Locations.FrontierContext.new()), "no detached static publication")


func test_held_scope_blocks_generic_preparation_before_first_candidate() -> void:
	"""An observer cannot open a generic candidate while the coordinator is still reading original inputs."""
	_location_scope()
	var original: Locations.Bank = _local._locations._live
	assert_equal(_local._locations.hold_frontier(_context), &"", "actual original hold")
	assert_equal(_local._locations.begin_prepare(_cold).error, &"LOCATION_FRONTIER_CONTEXT", "generic door refuses and poisons original")
	assert_equal(_local._locations.begin_frontier_prepare(_context).error, &"LOCATION_FRONTIER_CONTEXT", "poison is not reset by the private preparation")
	assert_true(_local._locations._live == original and original.count == 0, "no live publication")
	assert_equal(_local._locations._token, 0, "no candidate allocated")
	assert_equal(_local._cold._token, _cold, "no original lease release")


func test_actual_prospective_rows_do_not_gain_generic_publication_permission() -> void:
	"""Real support and sealed metadata remain private until the coupled graph/certificate tail is owned."""
	_sealed_locations()
	assert_equal(Locations.frontier_rows_refusal(_local._locations, _context, _records, _heap_patch), &"", "full add-only candidate")
	var out: Locations.Record = _sentinel_record()
	assert_equal(Locations.frontier_location_into(_local._locations, _context, _component_ref(1), out), &"", "exact prospective observation")
	assert_equal(out.point, Vector3i(512, 0, 512), "complete candidate copied")
	assert_false(_local._locations.is_live_location(_component_ref(1)), "prospective full ref is not live")
	assert_false(_local._locations.publish(_context.location_token), "generic one-bank publication refuses")
	assert_equal(Locations.frontier_rows_refusal(_local._locations, _context, _records, _heap_patch), &"LOCATION_FRONTIER_CONTEXT", "publication attempt invalidates the candidate")
	assert_equal(_local._locations._live.count, 0, "both new rows remain absent")


func test_prospective_observation_preserves_output_for_foreign_context_stale_generation_and_lost_lease() -> void:
	"""Matching numbers cannot replace the original held packet, full handle or actual arena generation."""
	_sealed_locations()
	var out: Locations.Record = _sentinel_record()
	var foreign: Locations.FrontierContext = Locations.FrontierContext.new()
	foreign.location_token = _context.location_token; foreign.cold = _cold
	assert_equal(Locations.frontier_location_into(_local._locations, foreign, _component_ref(1), out), &"LOCATION_FRONTIER_CONTEXT", "coincident foreign tokens")
	var stale: Vector2i = Vector2i(_component_ref(1).x, _component_ref(1).y + 1)
	assert_equal(Locations.frontier_location_into(_local._locations, _context, stale, out), &"LOCATION_FRONTIER_CONTEXT", "wrong full handle")
	assert_equal(_local._cold.release(_cold), &"", "expire original lease")
	_cold = _local._cold.acquire(Budget.COLD_BYTES)
	assert_equal(Locations.frontier_location_into(_local._locations, _context, _component_ref(1), out), &"LOCATION_FRONTIER_CONTEXT", "same-size replacement refuses")
	assert_equal(out.point, Vector3i(77, 88, 99), "no partial scalar write")
	assert_equal(out.envelope, PackedInt32Array([1, 2, 3, 4, 5, 6]), "no partial packed write")
	assert_equal(_local._locations._live.count, 0, "no stale publication")


func test_discard_keeps_original_hold_until_coordinator_cleanup() -> void:
	"""Aborting the transient candidate never hands a half transaction's publication authority to a callback."""
	_sealed_locations()
	assert_true(_local._locations.abort(_context.location_token), "discard actual candidate")
	assert_true(_local._locations._frontier == _context, "original independent hold remains")
	assert_equal(_local._locations.restore_state_bytes(_cold, PackedByteArray()), &"LOCATION_FRONTIER_CONTEXT", "restore cannot replace original scope")
	assert_equal(_local._locations.begin_prepare(_cold).error, &"LOCATION_FRONTIER_CONTEXT", "generic replacement remains refused")
	assert_equal(_local._locations._live.count, 0, "discard and reentry preserve live bytes")


func _paid_first_cube(lateral: bool = false) -> Vector2i:
	"""Unchanged current wire through actual paid owners; mounted consumer qualification remains a separate gate."""
	_h = LateralFixture.new() if lateral else Phase.SourceFixture.new()
	_h._actual_fixture(); _h.connect_source_paths(); _h.finite_stock_and_worker()
	if not _h.failures.is_empty(): return NULL_REF
	var made: Phase.Buildings.OpResult = _h.orders.confirm_room(_h.room_request())
	assert_true(made.ok, "actual Kitchen confirmation: %s" % made.error)
	if not made.ok: return NULL_REF
	var site: Vector2i = _h.sites.site_at(Vector3i(Phase.X + 2048, Phase.FLOOR, Phase.Z))
	for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
		if not _h.complete_source_phase(site, operation, operation == Contract.OP_BRACE): return NULL_REF
	_h.retreat_after_settlement()
	return made.ref if _h.failures.is_empty() else NULL_REF


func _next_request(room: Vector2i) -> Publication.Request:
	"""The exact current first opening has no silently widened section or authored air grant."""
	var request: Publication.Request = Publication.Request.new()
	request.gateway = _h._last; request.count = 2; request.sections.resize(6)
	request.points = PackedInt32Array([Phase.X + 2048, Phase.FLOOR, Phase.Z + 512,
		Phase.X + 2304, Phase.FLOOR, Phase.Z + 512, 0, 0, 0])
	request.profiles = PackedInt64Array([5, 1, 9, 1, 5, 1, 9, 1, 0, 0, 0, 0])
	request.work_profile = 24; request.work_revision = 1; request.face = 0; request.yaw = 49152
	var section: Vector2i = NULL_REF
	for row: int in _h._owner._region_capacity:
		if _h._owner._r_present[row] == 1 and _h._owner._r_role[row] == Space.FLOOR_DATUM \
				and Vector2i(_h._owner._r_owner_slot[row], _h._owner._r_owner_generation[row]) == room:
			assert_equal(section, NULL_REF, "one actual Kitchen full section")
			section = Vector2i(row, _h._owner._r_generation[row])
	request.sections[0] = section.x; request.sections[1] = section.y
	request.sections[2] = section.x; request.sections[3] = section.y
	return request


func _publication_output() -> Publication.Result:
	"""The fixed caller output is admitted with all other packets under the test's original lease."""
	var out: Publication.Result = Publication.Result.new()
	out.locations.resize(6); out.edges.resize(12); out.locations.fill(77); out.edges.fill(88)
	out.work = Vector2i(71, 9)
	return out


func _assert_refused_output(out: Publication.Result) -> void:
	"""The whole fixed output stays unchanged, not only its primary WORK handle."""
	assert_equal(out.work, Vector2i(71, 9), "refused full handle unchanged")
	assert_equal(out.count, 0, "refused count unchanged")
	assert_equal(out.locations, PackedInt32Array([77, 77, 77, 77, 77, 77]), "refused Location array unchanged")
	assert_equal(out.edges, PackedInt32Array([88, 88, 88, 88, 88, 88, 88, 88, 88, 88, 88, 88]), "refused edge array unchanged")


func _paid_live_image() -> Array[PackedByteArray]:
	"""Test-only snapshots cover all paid, contact, graph, certificate and actual actor columns."""
	var locations: PackedByteArray = PackedByteArray()
	assert_equal(_h.endpoints.capture_state_into(_cold, locations), &"", "original cold Location capture")
	var result: Array[PackedByteArray] = [_h._owner.state_bytes(), _h.sites.state_bytes(),
		_h._construction.state_bytes(), _h._inventory.state_bytes(), _h._jobs.state_bytes(), locations]
	for field: StringName in [&"fields", &"longs", &"present", &"retired", &"free_rows", &"ordered", &"vertices"]:
		result.append(_h._routes._live.get(field).to_byte_array() if field not in [&"present", &"retired"] else _h._routes._live.get(field).duplicate())
	for field: StringName in [&"resident", &"resident_long", &"links", &"free_links"]:
		result.append(_h._routes._motion.get(field).to_byte_array())
	result.append(_h._binding._live.masks.duplicate()); result.append(_h._binding._live.generations.to_byte_array())
	result.append(_h._binding._live.geometry.to_byte_array()); result.append(_h._binding._live.content.to_byte_array())
	result.append(PackedInt64Array([_h._routes._live.free_count, _h._routes._live.edge_count,
		_h._routes._live.vertex_count, _h._routes._live.revision, _h._routes._motion.free_count]).to_byte_array())
	return result


func test_actual_paid_first_cube_preserves_full_geometry_refusal_and_every_live_owner() -> void:
	"""One1024u cube cannot admit full1355u-wide/1036u-high travel and1131u work recovery, even after payment."""
	assert_equal(Published.runtime_sources_refusal(), &"MOLE_CATALOG_SOURCE_DRIFT", "unreviewed changed consumers cannot activate mounted publication")
	var room: Vector2i = _paid_first_cube()
	if room == NULL_REF: return
	_cold = _h._budget.acquire(Budget.COLD_BYTES)
	assert_true(_cold > 0, "one complete original publication lease")
	var candidate: Frontier.Candidate = Frontier.Candidate.new()
	assert_equal(Frontier.next_site_into(_h.provider, room, -1, _cold, Space.MAX_CHECKS, candidate), &"", "derive actual next unpaid Site")
	var request: Publication.Request = _next_request(room)
	var out: Publication.Result = _publication_output()
	var before: Array[PackedByteArray] = _paid_live_image()
	var code: StringName = Publication.publish_into(_h.provider, candidate, request, _cold, Space.MAX_CHECKS, out)
	print("FRONTIER-FIRST-CUBE-REFUSAL ", code)
	assert_equal(code, &"LOCATION_COVERAGE_MISSING", "complete original profile air refuses before graph publication")
	assert_equal(out.work, Vector2i(71, 9), "refused caller output unchanged")
	assert_true(_paid_live_image() == before, "all paid/physical/Location/graph/masks/actors unchanged")
	assert_equal(_h.sites._ever_cut.count(1), 1, "only the genuinely paid cube is cut")
	assert_equal(_h._construction.live_project_count(), 0, "no free next Project")
	assert_equal(_h.endpoints._token, 0, "original private Location candidate dropped")
	assert_true(_h.endpoints._frontier == null, "synchronous hold released")


func _lateral_request() -> Publication.Request:
	"""Each actual old-Corridor station has its distinct root, with the Kitchen target retained independently."""
	var request: Publication.Request = Publication.Request.new()
	request.gateway = _h._first; request.count = 2
	request.sections = PackedInt32Array([_h._floor.x, _h._floor.y, _h._floor.x, _h._floor.y, -1, 0])
	request.points = PackedInt32Array([Phase.X - 1024, Phase.FLOOR, Phase.Z + 1536,
		Phase.X + 1280, Phase.FLOOR, Phase.Z + 1536, 0, 0, 0])
	request.profiles = PackedInt64Array([1, 1, 1, 1, 5, 1, 9, 1, 0, 0, 0, 0])
	request.work_profile = 24; request.work_revision = 1; request.face = 0; request.yaw = 49152
	return request


func _lateral_candidate(room: Vector2i) -> Frontier.Candidate:
	"""Select the exact actual adjacent claimed key; earlier blocked keys stay unpaid and unchanged."""
	var site: Vector2i = _h.sites.site_at(Vector3i(Phase.X + 2048, Phase.FLOOR, Phase.Z + 1024))
	assert_true(site != NULL_REF, "actual lateral Site")
	var out: Frontier.Candidate = Frontier.Candidate.new()
	assert_equal(Frontier.next_site_into(_h.provider, room, _h.sites._site_key[site.x] - 1, _cold,
		Space.MAX_CHECKS, out), &"", "exact existing lateral candidate")
	assert_equal(out.site, site, "same full Site")
	return out


func test_actual_paid_first_cube_adds_lateral_corridor_contact_without_movement_or_free_work() -> void:
	"""Actual wire geometry may prove metadata here; source handoff and changed-consumer activation remain refused."""
	assert_equal(Published.runtime_sources_refusal(), &"MOLE_CATALOG_SOURCE_DRIFT", "labelled geometry diagnostic only")
	var room: Vector2i = _paid_first_cube(true)
	if room == NULL_REF: return
	(_h as LateralFixture).park_after_settlement()
	if not _h.failures.is_empty(): return
	_cold = _h._budget.acquire(Budget.COLD_BYTES)
	var candidate: Frontier.Candidate = _lateral_candidate(room)
	var before: Array[PackedByteArray] = _paid_live_image()
	var old_locations: Locations.Bank = _h.endpoints._live
	var old_graph: Routes.EdgeBank = _h._routes._live
	var old_masks: WorldRoutes.Certificates = _h._binding._live
	var result: Publication.Result = _publication_output()
	var code: StringName = Publication.publish_into(_h.provider, candidate, _lateral_request(), _cold, Space.MAX_CHECKS, result)
	print("FRONTIER-LATERAL-PUBLICATION ", code)
	assert_equal(code, &"", "real coupled Location/graph/certificate publication")
	if code != &"": return
	assert_equal(_h.endpoints._live.count, old_locations.count + 2, "two genuinely supported endpoints")
	assert_equal(_h._routes._live.edge_count, old_graph.edge_count + 4, "four directed section-contained spans")
	var after: Array[PackedByteArray] = _paid_live_image()
	for index: int in 5: assert_equal(after[index], before[index], "paid owner%d unchanged" % index)
	for index: int in range(13, 17): assert_equal(after[index], before[index], "original actor/queue columns unchanged")
	assert_equal(_h.sites._ever_cut.count(1), 1, "publication creates no extra physical cut")
	assert_equal(_h._construction.live_project_count(), 0, "publication grants no next paid Project")
	assert_true(_h.endpoints.is_live_location(result.work), "actual published full WORK ref")
	_assert_retained_locations(old_locations)
	_assert_retained_graph(old_graph, old_masks)
	_assert_lateral_spans(result)


func _assert_retained_locations(before: Locations.Bank) -> void:
	"""Every old full row and both support/air envelopes survive the one add-only swap byte-for-byte."""
	for row: int in _h.endpoints._capacity:
		if before.present[row] != 1: continue
		assert_equal(_h.endpoints._live.present[row], 1, "old Location still present")
		for field: int in Locations.I32_FIELDS:
			var at: int = field * _h.endpoints._capacity + row
			assert_equal(_h.endpoints._live.i32[at], before.i32[at], "old exact Location field")
		for field: int in Locations.I64_FIELDS:
			var at: int = field * _h.endpoints._capacity + row
			assert_equal(_h.endpoints._live.i64[at], before.i64[at], "old Location revision")


func _assert_retained_graph(before: Routes.EdgeBank, masks: WorldRoutes.Certificates) -> void:
	"""All old full paths and each certificate bit survive, including selectors not requested by this publication."""
	for row: int in _h._routes._edge_capacity:
		if before.present[row] != 1: continue
		for field: int in Routes.EDGE_FIELDS:
			var at: int = field * _h._routes._edge_capacity + row
			assert_equal(_h._routes._live.fields[at], before.fields[at], "old graph field")
		for field: int in Routes.EDGE_LONGS:
			var at: int = field * _h._routes._edge_capacity + row
			assert_equal(_h._routes._live.longs[at], before.longs[at], "old graph long")
		assert_equal(_h._binding._live.generations[row], masks.generations[row], "old mask full generation")
		assert_equal(_h._binding._live.geometry[row], masks.geometry[row], "old mask geometry")
		assert_equal(_h._binding._live.content[row], masks.content[row], "old mask source")
		for byte: int in WorldRoutes.MASK_BYTES:
			var at: int = row * WorldRoutes.MASK_BYTES + byte
			assert_equal(_h._binding._live.masks[at], masks.masks[at], "every retained mask bit")
	for at: int in 3 * before.vertex_count:
		assert_equal(_h._routes._live.vertices[at], before.vertices[at], "every original path vertex")


func _assert_lateral_spans(result: Publication.Result) -> void:
	"""Each new full span uses its real Corridor section and exact requested per-leg source bit."""
	for ordinal: int in 4:
		var row: int = result.edges[ordinal * 2]
		assert_equal(_h._routes._live.fields[Routes.E_GENERATION * _h._routes._edge_capacity + row], result.edges[ordinal * 2 + 1], "new edge generation")
		assert_equal(_h._routes._edge_pair(_h._routes._live, Routes.E_SECTION_SLOT, row), _h._floor, "exact Corridor section")
		var profile: int = 1 if ordinal % 2 == 0 else (5 if ordinal == 1 else 9)
		assert_true((_h._binding._live.masks[row * WorldRoutes.MASK_BYTES + (profile >> 3)] & (1 << (profile % 8))) != 0, "actual selected mask bit")
	var work: Locations.Record = _sentinel_record()
	assert_equal(_h.endpoints.read_location_into(result.work, work), &"", "actual full WORK payload")
	assert_equal(work.room, _h.corridor, "physical root remains in Corridor")
	assert_equal(work.role, Locations.ROLE_WORK, "new actual WORK role")


func test_late_location_free_heap_changes_refuse_without_rewriting_candidate() -> void:
	"""A duplicate valid free row or reordered allocation tail cannot corrupt the next actual allocation."""
	_sealed_locations()
	var heap: PackedInt32Array = _local._locations._stage.free_rows.duplicate()
	_local._locations._stage.free_rows[1] = heap[0]
	assert_equal(Locations.frontier_rows_refusal(_local._locations, _context, _records, _heap_patch), &"FRONTIER_ALLOCATION_CHANGED", "duplicate valid free row")
	_local._locations._stage.free_rows[1] = heap[1]
	_local._locations._stage.free_rows[0] = heap[1]; _local._locations._stage.free_rows[1] = heap[0]
	assert_equal(Locations.frontier_rows_refusal(_local._locations, _context, _records, _heap_patch), &"FRONTIER_ALLOCATION_CHANGED", "same free set with changed allocation order")
	_local._locations._stage.free_rows[0] = heap[0]; _local._locations._stage.free_rows[1] = heap[1]
	assert_equal(Locations.frontier_rows_refusal(_local._locations, _context, _records, _heap_patch), &"", "unchanged exact candidate retry")
	assert_equal(_local._locations._live.count, 0, "no intermediate live publication")


func _mutate_sealed_candidate() -> void:
	"""Real late observers exercise the exact candidate arrays; no false source success is injected."""
	var context: Locations.FrontierContext = _h.endpoints._frontier
	match _mutation:
		0: _h.endpoints._stage.free_rows[1] = _h.endpoints._stage.free_rows[0]
		1: _h._routes._stage.free_rows[1] = _h._routes._stage.free_rows[0]
		2: _h._routes._stage.ordered[1] = _h._routes._stage.ordered[0]
		3: _h._routes._stage.fields[Routes.E_PATH_START * _h._routes._edge_capacity + context.edges[2]] = _h._routes._live.vertex_count
		4: context.count = 1
		5: context.graph_live = context.graph_candidate
		6: _h._binding._stage.masks[0] ^= 1
		7: _h.endpoints.abort(context.location_token)
		8: _h._routes.cancel_route(_h._worker)
		9:
			_h.endpoints.abort(context.location_token)
			_h.endpoints.begin_frontier_prepare(context)
		10: _h.endpoints._stage.i32.resize(1)
		11: _h._routes._stage.vertices.resize(1)
		12: _h._binding._stage.masks.resize(1)
		13: assert_true(_h._transforms.place(_h._worker, Phase.X + 1280, Phase.FLOOR, Phase.Z + 1536, 49152), "actual worker enters prospective station")


func _restore_candidate_shape_and_pose() -> void:
	"""Test corruption repairs only inactive capacity; late actual worker movement is explicitly restored through its owner."""
	_h.endpoints._stage.i32.resize(Locations.I32_FIELDS * _h.endpoints._capacity)
	_h._routes._stage.vertices.resize(3 * _h._routes._vertex_capacity)
	_h._binding._stage.masks.resize(WorldRoutes.EDGE_CAPACITY * WorldRoutes.MASK_BYTES)
	if _mutation == 13:
		assert_true(_h._transforms.place(_h._worker, Phase.X - 3072, Phase.FLOOR, Phase.Z + 512, 49152), "restore actual original parking pose")


func test_actual_final_room_observer_cannot_publish_corrupt_indices_or_escape_original_scope() -> void:
	"""Each rejected candidate preserves actual paid owners, masks and actor state; an exact fresh retry still publishes."""
	var room: Vector2i = _paid_first_cube(true)
	if room == NULL_REF: return
	(_h as LateralFixture).park_after_settlement()
	if not _h.failures.is_empty(): return
	_cold = _h._budget.acquire(Budget.COLD_BYTES)
	var candidate: Frontier.Candidate = _lateral_candidate(room)
	var original: Array[PackedByteArray] = _paid_live_image()
	var observed: ObservedBuildings = _h._buildings as ObservedBuildings
	observed.route_owner = weakref(_h._binding)
	for variant: int in 14:
		_mutation = variant; observed.probe = _mutate_sealed_candidate
		var refused: Publication.Result = _publication_output()
		var code: StringName = Publication.publish_into(_h.provider, candidate, _lateral_request(), _cold, Space.MAX_CHECKS, refused)
		assert_true(code != &"", "late variant%d refuses" % variant)
		assert_equal(observed.calls, variant + 1, "actual successful Room observer executed")
		_assert_refused_output(refused)
		assert_true(_paid_live_image() == original, "all live owners/actors/masks unchanged%d" % variant)
		assert_true(_h.endpoints._frontier == null and _h.endpoints._token == 0 and _h._routes._token == 0, "only original candidates cleared")
		_restore_candidate_shape_and_pose()
	var out: Publication.Result = _publication_output()
	assert_equal(Publication.publish_into(_h.provider, candidate, _lateral_request(), _cold, Space.MAX_CHECKS, out), &"", "fresh genuine coupled retry")


func _heap_replay_case(capacity: int, graph: bool) -> void:
	"""The actual existing allocator is the independent oracle, including last-pop and full-depth heap behavior."""
	var locations: Locations = Locations.new()
	var bank: Locations.Bank = Locations.Bank.new()
	bank.free_rows.resize(capacity); bank.free_count = capacity
	for index: int in capacity: bank.free_rows[index] = index
	var before: PackedInt32Array = bank.free_rows.duplicate()
	var refs: PackedInt32Array = PackedInt32Array(); refs.resize(12)
	var patch: PackedInt32Array = PackedInt32Array(); patch.resize(Locations.FRONTIER_HEAP_WORDS)
	var removals: int = mini(6, capacity)
	for index: int in removals:
		refs[2 * index] = Routes._pop_free(bank.free_rows, capacity - index) if graph else locations._pop_free(bank)
	assert_equal(Locations.frontier_heap_refusal(before, bank.free_rows, capacity, refs, removals, patch, graph), &"", "exact actual allocator parity")
	var changed: PackedInt32Array = bank.free_rows.duplicate()
	changed[capacity - 1] ^= 1
	assert_equal(Locations.frontier_heap_refusal(before, changed, capacity, refs, removals, patch, graph), &"FRONTIER_ALLOCATION_CHANGED", "entire unused tail remains exact")
	assert_equal(before[0], 0, "sparse verifier never writes original heap")


func test_sparse_heap_replay_covers_existing_allocator_extremes_without_a_second_bank() -> void:
	"""Technical-capacity test only: the producer uses its fixed672-byte patch at the actual maximum heap depth."""
	for capacity: int in [1, 3, Routes.MAX_EDGES, Locations.MAX_LOCATIONS]:
		_heap_replay_case(capacity, false)
		_heap_replay_case(capacity, true)


func _replace_original_cold_lease() -> void:
	"""A legitimate owner releases and reacquires the same-sized arena during the last ordinary observation."""
	var original: int = _cold
	assert_equal(_h._budget.release(original), &"", "late actual original release")
	_cold = _h._budget.acquire(Budget.COLD_BYTES)
	assert_true(_cold > original, "same-size distinct original token")


func test_late_same_size_lease_replacement_refuses_and_preserves_the_new_lease() -> void:
	"""Cleanup abandons its stale candidates without releasing the unrelated new arena; a newly derived retry works."""
	var room: Vector2i = _paid_first_cube(true)
	if room == NULL_REF: return
	(_h as LateralFixture).park_after_settlement()
	if not _h.failures.is_empty(): return
	_cold = _h._budget.acquire(Budget.COLD_BYTES)
	var candidate: Frontier.Candidate = _lateral_candidate(room)
	var before: Array[PackedByteArray] = _paid_live_image()
	var observed: ObservedBuildings = _h._buildings as ObservedBuildings
	observed.route_owner = weakref(_h._binding); observed.probe = _replace_original_cold_lease
	var out: Publication.Result = _publication_output()
	assert_true(Publication.publish_into(_h.provider, candidate, _lateral_request(), _cold, Space.MAX_CHECKS, out) != &"", "lost original lease refuses")
	_assert_refused_output(out)
	assert_equal(observed.calls, 1, "actual late successful Room read")
	assert_true(_paid_live_image() == before, "all original paid and graph bytes remain exact")
	assert_equal(_h._budget._token, _cold, "new unrelated token remains owned")
	assert_equal(_h._budget._used, Budget.COLD_BYTES, "new unrelated reservation remains held")
	assert_true(_h.endpoints._frontier == null and _h._routes._token == 0, "stale original candidates discarded")
	assert_equal(Publication.publish_into(_h.provider, _lateral_candidate(room), _lateral_request(), _cold, Space.MAX_CHECKS, out), &"", "new original identity retry")


func _reenter_actual_face() -> void:
	"""An earlier ordinary Room observation calls the same actual WorkFace while its prospective query is active."""
	var face: Publication.Face = _h.provider._ordinary_face.get_ref() as Publication.Face
	assert_true(face._reading, "actual prospective read is active")
	assert_equal(face.solid_face_refusal(null, null, _cold), Publication.Face.REFUSE_BUSY, "same actual owner refuses reentry")


func test_actual_work_face_reentry_poison_preserves_all_live_state_and_retry() -> void:
	"""The prospective entry retains the ordinary WorkFace reentry contract across its complete source proof."""
	var room: Vector2i = _paid_first_cube(true)
	if room == NULL_REF: return
	(_h as LateralFixture).park_after_settlement()
	if not _h.failures.is_empty(): return
	_cold = _h._budget.acquire(Budget.COLD_BYTES)
	var candidate: Frontier.Candidate = _lateral_candidate(room)
	var before: Array[PackedByteArray] = _paid_live_image()
	var observed: ObservedBuildings = _h._buildings as ObservedBuildings
	observed.route_owner = weakref(_h._binding); observed.face_owner = _h.provider._ordinary_face
	observed.probe = _reenter_actual_face
	var out: Publication.Result = _publication_output()
	assert_equal(Publication.publish_into(_h.provider, candidate, _lateral_request(), _cold, Space.MAX_CHECKS, out), Publication.Face.REFUSE_BUSY, "complete original prospective proof is poisoned")
	assert_equal(observed.calls, 1, "successful actual source observer reentered once")
	_assert_refused_output(out)
	assert_true(_paid_live_image() == before, "no partial publication after reentry")
	assert_equal(Publication.publish_into(_h.provider, candidate, _lateral_request(), _cold, Space.MAX_CHECKS, out), &"", "fresh full query retry")


func _shorten_original_result() -> void:
	"""The caller-owned output is mutable during a successful actual Room observation, just like the input packet."""
	if _mutation == 0: _pending_output.locations.resize(1)
	else: _pending_output.edges.resize(1)


func test_late_original_output_resize_refuses_before_every_bank_swap() -> void:
	"""Only the callback's explicit output mutation survives; publication cannot partly write a too-short Result."""
	var room: Vector2i = _paid_first_cube(true)
	if room == NULL_REF: return
	(_h as LateralFixture).park_after_settlement()
	if not _h.failures.is_empty(): return
	_cold = _h._budget.acquire(Budget.COLD_BYTES)
	var candidate: Frontier.Candidate = _lateral_candidate(room)
	var before: Array[PackedByteArray] = _paid_live_image()
	var observed: ObservedBuildings = _h._buildings as ObservedBuildings
	observed.route_owner = weakref(_h._binding)
	for variant: int in 2:
		_mutation = variant; _pending_output = _publication_output(); observed.probe = _shorten_original_result
		assert_equal(Publication.publish_into(_h.provider, candidate, _lateral_request(), _cold, Space.MAX_CHECKS, _pending_output), Publication.REFUSE_SCOPE, "late output shape refuses before swap")
		assert_equal(observed.calls, variant + 1, "actual successful Room output observer")
		assert_equal(_pending_output.work, Vector2i(71, 9), "no coordinator handle write")
		assert_equal(_pending_output.count, 0, "no coordinator count write")
		assert_equal(_pending_output.locations.size(), 1 if variant == 0 else 6, "only observer Location resize")
		assert_equal(_pending_output.edges.size(), 1 if variant == 1 else 12, "only observer edge resize")
		for item: int in _pending_output.locations: assert_equal(item, 77, "no partial Location output")
		for item: int in _pending_output.edges: assert_equal(item, 88, "no partial graph output")
		assert_true(_paid_live_image() == before, "all coupled banks and paid owners unchanged")
	assert_equal(Publication.publish_into(_h.provider, candidate, _lateral_request(), _cold, Space.MAX_CHECKS, _publication_output()), &"", "fresh full output succeeds")
