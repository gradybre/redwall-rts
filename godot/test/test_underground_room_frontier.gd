extends "res://test/framework/test_case.gd"
## Real ordinary Room/Sites geometry and paid history;1156 source certificate remains diagnostic, never production qualification.

const Frontier := preload("res://scripts/core/underground_room_frontier.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Face := preload("res://scripts/core/underground_work_face.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
var _h: Phase.SourceFixture = null
var _room: Vector2i = NULL_REF
var _site: Vector2i = NULL_REF
var _cold: int = 0
var _candidate: Frontier.Candidate = null
var _request: Face.Request = null


func _fixture(stock: bool = false) -> void:
	"""Reuse the accepted actual composition by object, including its explicitly pre-existing corridor boundary."""
	_h = Phase.SourceFixture.new(); _h._actual_fixture(); _h.connect_source_paths()
	if stock: _h.finite_stock_and_worker()
	if not _h.failures.is_empty(): return
	var made: Phase.Buildings.OpResult = _h.orders.confirm_room(_h.room_request())
	assert_true(made.ok, "actual ordinary Kitchen confirmation: %s" % made.error)
	_room = made.ref
	_site = _h.sites.site_at(Vector3i(Phase.X + 2048, Phase.FLOOR, Phase.Z))


func _begin_query(bytes: int = Frontier.COLD_BYTES) -> void:
	"""Caller packets are created only after their complete original cold lifetime is admitted."""
	_cold = _h._budget.acquire(bytes)
	assert_true(_cold > 0, "one original cold lease")
	_candidate = Frontier.Candidate.new(); _request = Face.Request.new()


func _drop_query() -> void:
	"""No derived output survives to consume the next phase's nearly-full cold image."""
	_candidate = null; _request = null
	if _cold > 0:
		assert_equal(_h._budget.release(_cold), &"", "caller and private packets dropped before release")
		_cold = 0


func after_each() -> void:
	"""Propagate actual fixture assertions and remove all test-only strong ownership before teardown."""
	if _h != null:
		_drop_query(); _h.after_each()
		assert_true(_h.failures.is_empty(), "actual inherited fixture: %s" % _h.failures)
	_h = null; _room = NULL_REF; _site = NULL_REF


func _next(after_key: int = -1) -> StringName:
	"""Derive only identity/history; every test still calls the separate contact boundary."""
	return Frontier.next_site_into(_h.provider, _room, after_key, _cold, Space.MAX_CHECKS, _candidate)


func _contact() -> StringName:
	"""Actual v3 forward5 and provider's backward9 are separate directed source requirements."""
	return Frontier.contact_into(_h.provider, _candidate, _h._first, 5, 1, _cold, Space.MAX_CHECKS, _request)


func _candidate_image() -> PackedInt64Array:
	"""Test-only complete caller output snapshot; no production image or extra canonical ledger."""
	return PackedInt64Array([_candidate.room.x, _candidate.room.y, _candidate.site.x, _candidate.site.y,
		_candidate.project.x, _candidate.project.y, _candidate.key, _candidate.operation, _candidate.physical_phase,
		_candidate.project_phase, _candidate.earned_mwu, _candidate.room_revision, _candidate.geometry_revision,
		_candidate.qualification_revision, _candidate.cold_token, int(_candidate.installed), int(_candidate.ever_cut), int(_candidate.paused)])


func _request_image() -> PackedInt64Array:
	"""Sentinel output comparison covers every scalar and both coordinates on any refusal."""
	return PackedInt64Array([_request.location.x, _request.location.y, _request.target_origin.x,
		_request.target_origin.y, _request.target_origin.z, _request.face, _request.profile_id,
		_request.profile_revision, _request.content_revision, _request.geometry_revision, _request.yaw])


func _locations_image() -> PackedByteArray:
	"""The actual Location wire API keeps its required original cold lease; there is no state_bytes convenience API."""
	var image: PackedByteArray = PackedByteArray()
	assert_equal(_h.endpoints.capture_state_into(_cold, image), &"", "actual cold Location wire")
	return image


func test_two_stage_query_proves_existing_actual_contact_and_directed_paths_without_phase_permission() -> void:
	"""The actual first frontier is useful, but even its complete observation creates no paid or spatial state."""
	_fixture()
	if not _h.failures.is_empty(): return
	_begin_query()
	var sites: PackedByteArray = _h.sites.state_bytes()
	var geometry: PackedByteArray = _h._owner.state_bytes()
	var locations: PackedByteArray = _locations_image()
	var retained_request: Face.Request = _h.provider._ordinary_query
	assert_equal(_next(), &"", "exact current canonical Site")
	assert_equal(_candidate.site, _site, "first incomplete Kitchen quantum")
	assert_equal(_candidate.operation, Contract.OP_BRACE, "actual natural unpaid history")
	assert_equal(_candidate.project, NULL_REF, "no project created by identity scan")
	assert_equal(_contact(), &"", "real complete work source plus forward/backward certificates")
	assert_equal(_request.location, _h._last, "full existing WORK endpoint")
	assert_equal(_request.profile_id, 24, "exact complete FRONT source")
	assert_equal(_request.target_origin, _h.sites.origin_of(_site), "original canonical physical cube")
	assert_true(_h.sites.state_bytes() == sites and _h._owner.state_bytes() == geometry, "no free physical/paid state")
	assert_equal(_locations_image(), locations, "no hidden endpoint publication")
	assert_true(_h.provider._ordinary_query == retained_request, "no second retained provider packet")


func test_bad_lease_full_generation_and_capacity_preserve_both_caller_outputs() -> void:
	"""Refusals are exact and unchanged, including a valid-looking Site with the wrong generation."""
	_fixture()
	if not _h.failures.is_empty(): return
	_begin_query()
	_candidate.key = 876; _request.yaw = 123
	var candidate: PackedInt64Array = _candidate_image()
	var request: PackedInt64Array = _request_image()
	assert_equal(Frontier.next_site_into(_h.provider, _room, -1, _cold + 1, Space.MAX_CHECKS, _candidate), Frontier.REFUSE_LEASE, "wrong original token")
	assert_equal(_candidate_image(), candidate, "identity output untouched")
	assert_equal(Frontier.next_site_into(_h.provider, _room, -1, _cold, 1, _candidate), Frontier.REFUSE_CAPACITY, "finite work refuses before scan")
	assert_equal(_candidate_image(), candidate, "capacity keeps original output")
	assert_equal(_next(), &"", "actual identity")
	_candidate.site.y += 1
	assert_equal(_contact(), Frontier.REFUSE_STALE, "stale full Site")
	assert_equal(_request_image(), request, "contact output unchanged")
	_candidate.site.y -= 1; _candidate.room.y += 1
	assert_equal(_contact(), Frontier.REFUSE_STALE, "stale full Room")
	assert_equal(_request_image(), request, "Room refusal preserves every field")


func test_candidate_cannot_cross_cold_lifetimes_or_independent_source_reload() -> void:
	"""A copied canonical key is no receipt across leases or immutable source revisions."""
	_fixture()
	if not _h.failures.is_empty(): return
	_begin_query(); assert_equal(_next(), &"", "original query")
	var request: PackedInt64Array = _request_image()
	assert_equal(_h._budget.release(_cold), &"", "negative-only retain a stale caller packet")
	_cold = _h._budget.acquire(Frontier.COLD_BYTES)
	assert_equal(_contact(), Frontier.REFUSE_STALE, "new same-size lease is not original")
	assert_equal(_request_image(), request, "stale lease output preserved")
	assert_equal(_next(), &"", "fresh packet under new lease")
	assert_equal(_h._load_catalog(2), &"", "actual independent Catalog reload")
	assert_equal(_contact(), Frontier.REFUSE_STALE, "old qualification cannot survive source change")
	assert_equal(_request_image(), request, "reload output preserved")


func test_actual_existing_paused_project_is_reported_and_never_reopened() -> void:
	"""Selection preserves the user's actual pause and leaves the original Job/Project/work intact."""
	_fixture(true)
	if not _h.failures.is_empty(): return
	var job: Vector2i = _h.open_phase_job(_site, Contract.OP_BRACE)
	if job == NULL_REF or not _h.failures.is_empty(): return
	var project: Vector2i = _h.sites.project_of(_site)
	assert_true(_h._construction.set_paused(project, true).ok, "actual user pause")
	_begin_query()
	var original: PackedByteArray = _h._construction.state_bytes()
	assert_equal(_next(), &"", "active identity remains visible")
	assert_equal(_candidate.project, project, "same exact full Project")
	assert_true(_candidate.paused, "actual pause is preserved")
	var request: PackedInt64Array = _request_image()
	assert_equal(_contact(), Frontier.REFUSE_ACTIVE, "host must resume original Project, never reopen")
	assert_equal(_request_image(), request, "existing project grants no new contact output")
	assert_equal(_h._construction.state_bytes(), original, "no phase/work/pause mutation")


func test_complete_actual_paid_cube_selects_next_identity_but_missing_new_contact_stays_closed() -> void:
	"""Canonical progression is real; one paid cube must not be reported as full Kitchen completion."""
	_fixture(true)
	if not _h.failures.is_empty(): return
	for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
		if not _h.complete_source_phase(_site, operation, operation == Contract.OP_BRACE): return
	_h.retreat_after_settlement()
	if not _h.failures.is_empty(): return
	_begin_query()
	assert_equal(_next(), &"", "completed paid cube skipped")
	assert_true(_candidate.site != _site and _candidate.key > _h.sites._site_key[_site.x], "next exact canonical incomplete Site")
	assert_equal(_candidate.operation, Contract.OP_BRACE, "no neighbor support granted")
	var output: PackedInt64Array = _request_image()
	var before: PackedByteArray = _h._owner.state_bytes()
	assert_equal(_contact(), Frontier.REFUSE_CONTACT, "next station/path needs actual new publication")
	assert_equal(_request_image(), output, "no fabricated successor contact")
	assert_equal(_h._owner.state_bytes(), before, "no free topology")
	assert_equal(_h.sites._ever_cut.count(1), 1, "only the genuinely completed cube was cut")
	assert_equal(_h._construction.live_project_count(), 0, "selection opens no neighbor Project")


func test_actual_route_removal_and_distinct_contact_ambiguity_are_not_permission() -> void:
	"""A source-derived anchor alone never supplies a missing directed return certificate."""
	_fixture()
	if not _h.failures.is_empty(): return
	var token: int = _h._begin()
	var reverse: Vector2i = Vector2i(1, _h._routes._edge_i32(_h._routes._live, Routes.E_GENERATION, 1))
	assert_equal(_h._routes.stage_remove(token, reverse), &"", "actual unoccupied return edge removed")
	assert_equal(_h._binding.seal(token), &"", "actual remaining forward geometry")
	assert_equal(_h._binding.publish(token), &"", "actual graph publication")
	_h._end(token)
	_begin_query(); assert_equal(_next(), &"", "current candidate after graph change")
	var output: PackedInt64Array = _request_image()
	assert_true(_contact() != &"", "no inferred mirrored edge")
	assert_equal(_request_image(), output, "path refusal keeps output")
	_drop_query()
	_h._endpoint(Vector3i(Phase.X + 1280, Phase.FLOOR, Phase.Z + 640), Phase.Locations.ROLE_WORK)
	_begin_query(); assert_equal(_next(), &"", "current source identity")
	assert_equal(_contact(), Frontier.REFUSE_AMBIGUOUS, "two declared source contacts cannot silently select first")
	assert_equal(_request_image(), output, "ambiguous contact output unchanged")


func test_insufficient_complete_cold_charge_refuses_before_private_query_allocation() -> void:
	"""The identity-only packet can be useful at its smaller charge but cannot silently allocate full motion proof."""
	_fixture()
	if not _h.failures.is_empty(): return
	_begin_query(Frontier.CONTROL_BYTES)
	assert_equal(_next(), &"", "bounded identity scan under its admitted cold slice")
	var output: PackedInt64Array = _request_image()
	assert_equal(_contact(), Frontier.REFUSE_LEASE, "no full WorkFace allocation before complete admission")
	assert_equal(_request_image(), output, "admission refusal keeps output")
	assert_equal(_h._budget.used_bytes(), Frontier.CONTROL_BYTES, "no implicit reservation increase")


func test_cancelled_real_paid_work_stays_on_the_same_physical_frontier_key() -> void:
	"""Cancel uses real refund/publication, preserving canonical earned WU instead of creating a parallel progress ledger."""
	_fixture(true)
	if not _h.failures.is_empty(): return
	var job: Vector2i = _h.open_phase_job(_site, Contract.OP_BRACE)
	_h.walk_to_work(job); _h.enter_work(job); _h.start_phase(_site, Contract.OP_BRACE, job)
	if not _h.failures.is_empty(): return
	_h.tick += 1
	assert_equal(_h._routes.advance_tick(_h.tick), 1, "actual WORK source tick")
	var earned: Phase.WorldFixture.Work.TickResult = _h._work.tick_solo(_h._residents.directory().get_typed_row(job))
	assert_true(earned.ok and earned.accepted_mwu > 0 and earned.accepted_mwu < Contract.BRACE_WORK_MWU, "actual partial paid work")
	assert_equal(_h._routes.request_source_ready(_h._worker, job), &"", "actual recovery before user cancellation")
	_h.wait_ready(job, 24)
	if not _h.failures.is_empty(): return
	var cancelled: Construction.OpResult = _h.sites.cancel_phase(_site, _h.material)
	assert_true(cancelled.ok, "actual current-phase refund: %s" % cancelled.error)
	if not cancelled.ok: return
	_begin_query()
	assert_equal(_next(), &"", "retained physical history remains current")
	assert_equal(_candidate.site, _site, "same full permanent Site")
	assert_equal(_candidate.project, NULL_REF, "cancelled Project retired normally")
	assert_equal(_candidate.operation, Contract.OP_BRACE, "support was never completed")
	assert_equal(_candidate.earned_mwu, earned.accepted_mwu, "exact real paid progress retained")
	assert_equal(_contact(), &"", "fresh complete physical contact still required to resume")
	assert_equal(_h.sites.support_conservation_refusal(), &"", "actual support/refund conserved")


func test_scan_end_means_only_the_callers_search_position_not_finished_room_permission() -> void:
	"""A caller may inspect beyond the current index; exhaustion cannot certify the Room's physical completion."""
	_fixture()
	if not _h.failures.is_empty(): return
	_begin_query(); assert_equal(_next(), &"", "first exact incomplete identity")
	var original: PackedInt64Array = _candidate_image()
	var last_key: int = _h.sites._ordered_key[_h.sites._count - 1]
	assert_equal(_next(last_key), Frontier.REFUSE_END, "end of only this bounded canonical scan")
	assert_equal(_candidate_image(), original, "scan end preserves original identity output")
	assert_equal(_h.sites._room_slot.count(_room.x), 8, "all actual 2×2×2 Kitchen claims exist (DEC-054 height)")
	assert_equal(_h.sites._ever_cut.count(1), 0, "none gained free completion from scan exhaustion")
