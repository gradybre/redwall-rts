extends "res://test/framework/test_case.gd"
## Decision 1952 (P-1951-1): the room itinerary's per-edge profile memo. A search answered from the memo must leave
## everything a search leaves, not only its answer: the code and remaining-work output, Routes' search scratch
## (distances, predecessors, heap, proposed chain, budget, fault, path serial step) and WorldRoutes' search descriptor.
## Each case runs the same search with the memo off, then on (filling it) and on again (answered from it).

const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Itinerary := StationTests.Itinerary
const Routes := StationTests.Routes
const Space := StationTests.Space
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _h: StationTests.StepFixture = null


func before_each() -> void:
	"""Decision 1952: this suite tests the answered path itself, so the framework's live cross-check is off here."""
	WorldRoutes.Profiles.check_runtime_caches = false


func after_each() -> void:
	"""Free the fixture's owners; the framework's cache checks are back on for the next suite."""
	WorldRoutes.Profiles.check_runtime_caches = true
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _fixture() -> bool:
	"""The confirmed Kitchen with its first cube dug, so the graph holds a published station chain."""
	_h = StationTests.StepFixture.new()
	var room: Vector2i = _h.confirmed_room()
	if room == NULL_REF or not _h.failures.is_empty(): return false
	_h.room_loop(room, 1)
	return _h.failures.is_empty()


func _search(from: Vector2i, to: Vector2i, anchor: int, checks: int) -> Array:
	"""One search and everything it leaves behind; the path serial is reported as its step."""
	var graph: Routes = _h._routes
	var serial: int = graph._path_serial
	var out: PackedInt32Array = PackedInt32Array([0])
	var code: StringName = Itinerary.reachability_refusal(_h._binding, from, to, anchor, 1, StationTests.CONTENT, checks, out)
	var descriptor: StationTests.Profiles.Descriptor = _h._binding._descriptor
	return [code, out[0], graph._remaining, graph._operation_error, graph._proposed_count,
		graph._proposed_edges.slice(0, 2 * maxi(graph._proposed_count, 0)), graph._distance.duplicate(),
		graph._predecessor.duplicate(), graph._search_state.duplicate(), graph._heap_count, graph._path_serial - serial,
		[descriptor.profile_id, descriptor.profile_revision, descriptor.content_revision, descriptor.mode,
		descriptor.posture], _h._binding._witness_serial]


func _memo(on: bool) -> void:
	"""Turn the memo off (no slots: unusable) or on (empty slots)."""
	var size: int = WorldRoutes.EDGE_MEMO_SLOTS * WorldRoutes.EDGE_MEMO_STRIDE if on else 0
	_h._binding._edge_memo = PackedInt64Array()
	_h._binding._edge_memo.resize(size)


func _assert_same_three_ways(from: Vector2i, to: Vector2i, anchor: int, checks: int, label: String) -> Array:
	"""Off, filling and answered: the three searches leave identical state. Returns the answered run."""
	_memo(false)
	var plain: Array = _search(from, to, anchor, checks)
	_memo(true)
	var filling: Array = _search(from, to, anchor, checks)
	var answered: Array = _search(from, to, anchor, checks)
	assert_equal(filling, plain, "%s: the filling search leaves what a plain search leaves" % label)
	assert_equal(answered, plain, "%s: the answered search leaves what a plain search leaves" % label)
	return answered


func test_answered_searches_leave_exactly_what_a_search_leaves() -> void:
	"""Both directions, both anchors, a refused anchor and an unreachable pair, at the full budget."""
	if not _fixture(): return
	var stations: Array[Vector2i] = [_h._first, _h.parking, _h.contact_location]
	var answered: int = 0
	for anchor: int in [5, 9, 1, 27]:
		for from: Vector2i in stations:
			for to: Vector2i in stations:
				var result: Array = _assert_same_three_ways(from, to, anchor, Space.MAX_CHECKS, "%s>%s@%d" % [from, to, anchor])
				answered += 1 if result[0] == &"" else 0
	assert_true(answered > 0, "some searches succeed, so chains and spends are compared")


func test_a_budget_too_small_for_the_remembered_spend_is_searched_live() -> void:
	"""Every budget from the full search's own spend downwards gives the plain search's exact refusal and state."""
	if not _fixture(): return
	_memo(false)
	var full: Array = _search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	assert_equal(full[0], &"", "the reference search succeeds")
	var spent: int = Space.MAX_CHECKS - int(full[1])
	for checks: int in range(maxi(spent - 4000, 2 * WorldRoutes.REACH_SCOPE_CHECKS), spent + 1, 37):
		_memo(true)
		_search(_h._first, _h.parking, 5, Space.MAX_CHECKS) # Fill the memo at the full budget.
		var answered: Array = _search(_h._first, _h.parking, 5, checks)
		_memo(false)
		var plain: Array = _search(_h._first, _h.parking, 5, checks)
		assert_equal(answered, plain, "budget %d" % checks)


func test_every_input_change_starts_a_new_epoch() -> void:
	"""A Profiles edit, a certificate swap, a geometry revision and a graph publication each retire every slot."""
	if not _fixture(): return
	_memo(true)
	_search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	var epoch: int = _h._binding._edge_memo_epoch
	_h._profiles.invalidate_runtime_caches()
	_search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	assert_true(_h._binding._edge_memo_epoch > epoch, "a Profiles edit")
	epoch = _h._binding._edge_memo_epoch
	_h._binding._certificate_revision = WorldRoutes._next_revision(_h._binding._certificate_revision)
	_search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	assert_true(_h._binding._edge_memo_epoch > epoch, "a certificate swap")
	epoch = _h._binding._edge_memo_epoch
	_h._routes._owner._header[17] += 1
	assert_equal(WorldRoutes.edge_memo_epoch(_h._binding, _h._routes), epoch + 1, "a geometry revision")
	_h._routes._owner._header[17] -= 1
	epoch = _h._binding._edge_memo_epoch
	_h._routes._last_published_token += 1
	assert_equal(WorldRoutes.edge_memo_epoch(_h._binding, _h._routes), epoch + 1, "a graph publication")
	_h._routes._last_published_token -= 1
	_h._routes._last_published_token = 0
	assert_equal(WorldRoutes.edge_memo_epoch(_h._binding, _h._routes), 0, "a restored (unpublished) graph is unusable")


func test_tokens_saturate_to_unusable() -> void:
	"""A saturated certificate revision or epoch reads as zero and disables the memo."""
	assert_equal(WorldRoutes._next_revision(9223372036854775807), 0, "saturated")
	assert_equal(WorldRoutes._next_revision(0), 0, "stays unusable")
	assert_equal(WorldRoutes._next_revision(41), 42, "otherwise the next value")
	if not _fixture(): return
	_memo(true)
	_h._binding._certificate_revision = 0
	assert_equal(WorldRoutes.edge_memo_epoch(_h._binding, _h._routes), 0, "an unusable certificate revision")


func test_a_real_publication_moves_the_certificate_revision() -> void:
	"""WorldRoutes.publish() (the parking span) and the preflighted station publications each swap the certificate banks."""
	_h = StationTests.StepFixture.new()
	_h.location_capacity = 64
	_h.edge_capacity = 128
	_h._actual_fixture()
	if not _h.failures.is_empty(): return
	var before: int = _h._binding._certificate_revision
	_h.connect_source_paths()
	assert_true(_h._binding._certificate_revision > before, "publish() swapped the banks")
	_h.finite_stock_and_worker()
	var room: Vector2i = _h.orders.confirm_room(_h.room_request()).ref
	before = _h._binding._certificate_revision
	_h.room_loop(room, 1)
	assert_true(_h._binding._certificate_revision > before, "the first cube's publications swapped the banks")


func _memo_call_ready() -> void:
	"""Put WorldRoutes and Routes in the original search state the memo requires."""
	_h._binding._reading = true
	_h._routes._searching = true
	_h._routes._operation_error = &""
	_h._routes._remaining = Space.MAX_CHECKS


func _memo_call_done() -> void:
	"""Leave the search state."""
	_h._binding._reading = false
	_h._routes._searching = false


func test_the_memo_answers_only_its_own_edge_anchor_and_a_clean_search() -> void:
	"""Same slot, other anchor: miss. A recorded fault: miss, and a faulted choice is never remembered."""
	if not _fixture(): return
	_memo(true)
	_memo_call_ready()
	var epoch: int = WorldRoutes.edge_memo_epoch(_h._binding, _h._routes)
	WorldRoutes.remember_edge_profile(_h._binding, _h._routes, 3, 5, 7, 100, false, epoch)
	assert_equal(WorldRoutes.edge_profile_memo(_h._binding, _h._routes, 3, 5), 7, "its own edge and anchor")
	assert_equal(WorldRoutes.edge_profile_memo(_h._binding, _h._routes, 3, 5 + WorldRoutes.EDGE_MEMO_SLOTS),
		WorldRoutes.EDGE_MEMO_MISS, "the same slot for another anchor")
	_h._routes._operation_error = &"ROUTE_OPERATION_BUDGET"
	assert_equal(WorldRoutes.edge_profile_memo(_h._binding, _h._routes, 3, 5), WorldRoutes.EDGE_MEMO_MISS, "a recorded fault")
	WorldRoutes.remember_edge_profile(_h._binding, _h._routes, 4, 5, 9, 100, false, epoch)
	_h._routes._operation_error = &""
	assert_equal(WorldRoutes.edge_profile_memo(_h._binding, _h._routes, 4, 5), WorldRoutes.EDGE_MEMO_MISS, "not remembered")
	_h._routes._remaining = 99
	assert_equal(WorldRoutes.edge_profile_memo(_h._binding, _h._routes, 3, 5), WorldRoutes.EDGE_MEMO_MISS, "budget short")
	_memo_call_done()


func test_a_choice_that_wrote_no_descriptor_leaves_the_descriptor_alone() -> void:
	"""Only a remembered write is replayed; otherwise the caller's descriptor stays as it is."""
	if not _fixture(): return
	_memo(true)
	_memo_call_ready()
	var epoch: int = WorldRoutes.edge_memo_epoch(_h._binding, _h._routes)
	var descriptor: StationTests.Profiles.Descriptor = _h._binding._descriptor
	descriptor.profile_id = 11
	WorldRoutes.remember_edge_profile(_h._binding, _h._routes, 3, 5, -1, 10, false, epoch)
	descriptor.profile_id = 12
	assert_equal(WorldRoutes.edge_profile_memo(_h._binding, _h._routes, 3, 5), -1, "answered")
	assert_equal(descriptor.profile_id, 12, "no write replayed")
	descriptor.posture = 3
	descriptor.mode = 2
	WorldRoutes.remember_edge_profile(_h._binding, _h._routes, 3, 5, 6, 10, true, epoch)
	descriptor.profile_id = 13
	descriptor.posture = 4
	descriptor.mode = 1
	assert_equal(WorldRoutes.edge_profile_memo(_h._binding, _h._routes, 3, 5), 6, "answered")
	assert_equal([descriptor.profile_id, descriptor.posture, descriptor.mode], [12, 3, 2], "the remembered write replayed")
	_memo_call_done()


func test_an_itinerary_choice_with_no_descriptor_write_replays_none() -> void:
	"""Through the itinerary: a choice that wrote nothing leaves a later caller's descriptor alone when answered."""
	if not _fixture(): return
	_memo(true)
	_memo_call_ready()
	var descriptor: StationTests.Profiles.Descriptor = _h._binding._descriptor
	var edge: int = _h._routes._live.ordered[0]
	descriptor.profile_id = 31
	var writes: int = _h._binding._descriptor_writes
	var row: int = Itinerary._edge_profile(_h._binding, edge, 0)
	assert_equal(_h._binding._descriptor_writes, writes, "anchor 0 is compatible with no row, so nothing is written")
	descriptor.profile_id = 32
	assert_equal(Itinerary._edge_profile(_h._binding, edge, 0), row, "answered the same")
	assert_equal(descriptor.profile_id, 32, "and nothing replayed")
	_memo_call_done()


func test_a_starved_search_fills_nothing_a_full_search_could_borrow() -> void:
	"""Budgets that run out inside the search, then the full budget: every run leaves what a plain run leaves."""
	if not _fixture(): return
	_memo(false)
	var full: Array = _search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	var spent: int = Space.MAX_CHECKS - int(full[1])
	var checks: int = 2 * WorldRoutes.REACH_SCOPE_CHECKS
	while checks < spent:
		_memo(true)
		var starved: Array = _search(_h._first, _h.parking, 5, checks)
		var then_full: Array = _search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
		_memo(false)
		assert_equal(starved, _search(_h._first, _h.parking, 5, checks), "starved at %d" % checks)
		assert_equal(then_full, full, "full after starving at %d" % checks)
		checks += 997


func test_an_edge_certificate_edited_in_place_is_read_again() -> void:
	"""Each chain edge's mask bytes, certificate generation, geometry and content, and its graph generation, edited in
	place without any revision moving, are read again: the answer equals a plain search over the edited bytes."""
	if not _fixture(): return
	_memo(false)
	var plain: Array = _search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	assert_equal(plain[0], &"", "the reference search succeeds")
	var chain: PackedInt32Array = plain[5]
	for index: int in range(0, chain.size(), 2):
		var edge: int = chain[index]
		for change: int in 5:
			_memo(true)
			_search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
			_edit_edge(edge, change, 1)
			var answered: Array = _search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
			_memo(false)
			assert_equal(answered, _search(_h._first, _h.parking, 5, Space.MAX_CHECKS), "edge %d change %d" % [edge, change])
			_edit_edge(edge, change, -1)


func _edit_edge(edge: int, change: int, sign: int) -> void:
	"""Negative-only in-place edits of one edge's inputs, undone by the opposite sign."""
	var bank: WorldRoutes.Certificates = _h._binding._live
	match change:
		0: bank.masks[edge * WorldRoutes.MASK_BYTES] ^= 0xFF
		1: bank.generations[edge] += sign
		2: bank.geometry[edge] += sign
		3: bank.content[edge] += sign
		4: _h._routes._live.fields[Routes.E_GENERATION * _h._routes._edge_capacity + edge] += sign



func _poison_filled_slots() -> int:
	"""Make every slot of the current epoch answer "no profile" (row -1) for its edge; returns how many there were."""
	var memo: PackedInt64Array = _h._binding._edge_memo
	var epoch: int = _h._binding._edge_memo_epoch
	var filled: int = 0
	for slot: int in WorldRoutes.EDGE_MEMO_SLOTS:
		var at: int = slot * WorldRoutes.EDGE_MEMO_STRIDE
		if epoch > 0 and memo[at] == epoch:
			memo[at + 3] = -1
			filled += 1
	_h._binding._edge_memo = memo
	return filled


func test_answered_searches_read_their_choices_from_the_memo() -> void:
	"""A filled memo really answers: with every remembered choice poisoned and no input changed, the next search
	follows the poisoned answers, so it no longer equals the plain search."""
	if not _fixture(): return
	_memo(false)
	var plain: Array = _search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	assert_equal(plain[0], &"", "the reference search succeeds")
	_memo(true)
	assert_equal(_search(_h._first, _h.parking, 5, Space.MAX_CHECKS), plain, "filling")
	assert_true(_poison_filled_slots() > 0, "the filling search remembered its chain's choices")
	assert_true(_search(_h._first, _h.parking, 5, Space.MAX_CHECKS) != plain, "the answers came from the memo")


func test_with_checks_on_a_stale_slot_is_reported_and_the_search_runs_live() -> void:
	"""Decision 1952: with the framework's checks on, every slot that would answer is compared with a live choice; a
	slot that disagrees is reported, and the search leaves exactly what a plain search leaves."""
	if not _fixture(): return
	_memo(false)
	var plain: Array = _search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	_memo(true)
	_search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	WorldRoutes.Profiles.check_runtime_caches = true
	assert_equal(_search(_h._first, _h.parking, 5, Space.MAX_CHECKS), plain, "agreeing slots: checked and silent")
	assert_true(_poison_filled_slots() > 0, "slots to poison")
	expect_diagnostic("RUNTIME_CACHE_STALE itinerary edge profile")
	assert_equal(_search(_h._first, _h.parking, 5, Space.MAX_CHECKS), plain, "a stale slot is reported, never followed")


func test_the_anchor_memo_answers_as_the_live_check_and_reads_afresh_on_a_new_token() -> void:
	"""Decision 1952: every anchor and revision answers as the live check, filling and answered; an answered check
	really comes from the memo; a moved token or another bank is read afresh; with checks on a stale slot is reported."""
	if not _fixture(): return
	var profiles: StationTests.Profiles = _h._profiles
	var content: int = profiles._live.header[0]
	for anchor: int in range(-1, profiles._live.header[1] + 1):
		for revision: int in [0, 1, 2]:
			var live: StringName = Itinerary._anchor_refusal_live(profiles, anchor, revision, content)
			assert_equal(Itinerary._anchor_refusal(profiles, anchor, revision, content), live, "filling %d/%d" % [anchor, revision])
			assert_equal(Itinerary._anchor_refusal(profiles, anchor, revision, content), live, "answered %d/%d" % [anchor, revision])
	assert_equal(Itinerary._anchor_refusal(profiles, 5, 1, content), &"", "anchor 5 passes")
	var at: int = Itinerary._anchor_memo_at(profiles, 5, 1, content)
	assert_true(at >= 0, "remembered")
	profiles._anchor_memo[at + 5] = 1 # Poison: the memo, not a live read, answers.
	assert_equal(Itinerary._anchor_refusal(profiles, 5, 1, content), Itinerary.REFUSE_FAMILY, "answered from the memo")
	profiles.invalidate_runtime_caches()
	assert_equal(Itinerary._anchor_memo_at(profiles, 5, 1, content), -1, "a moved token retires the slot")
	assert_equal(Itinerary._anchor_refusal(profiles, 5, 1, content), &"", "and the check is read afresh")
	at = Itinerary._anchor_memo_at(profiles, 5, 1, content)
	profiles._anchor_memo[at + 1] += 1
	assert_equal(Itinerary._anchor_memo_at(profiles, 5, 1, content), -1, "another bank is not answered")
	assert_equal(Itinerary._anchor_refusal(profiles, 5, 1, content), &"", "refilled")
	profiles._anchor_memo[Itinerary._anchor_memo_at(profiles, 5, 1, content) + 5] = 1
	WorldRoutes.Profiles.check_runtime_caches = true
	expect_diagnostic("RUNTIME_CACHE_STALE anchor check")
	assert_equal(Itinerary._anchor_refusal(profiles, 5, 1, content), &"", "checks on: reported and answered live")
	profiles._loading = true
	assert_equal(Itinerary._anchor_memo_at(profiles, 5, 1, content), -1, "a loading store is never answered")
	profiles._loading = false


func _endpoint_ready(location: Vector2i, checks: int) -> bool:
	"""Observe `location` into WorldRoutes' endpoint record under a fresh proof budget and the compiled content."""
	var binding: WorldRoutes = _h._binding
	binding._content_revision = _h._profiles._live.header[0]
	binding._proof = WorldRoutes.Clearance.new()
	binding._proof.allocate(Space.Snapshot.new(), checks)
	return binding._locations().read_location_into(location, binding._endpoint) == &""


func _endpoint_run(location: Vector2i, profile: int, checks: int) -> Array:
	"""One endpoint box proof for `profile` at budget `checks`: its answer, remaining budget and fault."""
	var binding: WorldRoutes = _h._binding
	binding._proof.remaining = checks
	binding._proof.error = &""
	var code: StringName = binding._endpoint_boxes_refusal(location, binding._endpoint.point)
	return [code, binding._proof.remaining, binding._proof.error]


func _endpoint_memo(on: bool) -> void:
	"""Turn the endpoint memo off (no results: unusable) or on (empty)."""
	_h._binding._endpoint_memo = PackedInt64Array()
	_h._binding._endpoint_memo.resize(WorldRoutes.ENDPOINT_MEMO_ENTRIES * WorldRoutes.Profiles.MAX_PROFILES if on else 0)


func _endpoint_profiles() -> PackedInt32Array:
	"""Every profile row the bank describes at the compiled content."""
	var rows: PackedInt32Array = PackedInt32Array()
	for profile: int in _h._profiles._live.header[1]:
		if _h._profiles.descriptor_into(profile, _h._profiles._live.header[0], _h._binding._descriptor) == &"":
			rows.append(profile)
	return rows


func test_endpoint_proofs_answer_as_the_live_checks_at_every_budget() -> void:
	"""Decision 1952: for every station endpoint and profile, a filling and an answered proof leave the answer, budget
	and fault a plain proof leaves, at the full budget and at every budget that runs out part way."""
	if not _fixture(): return
	var answered: int = 0
	for location: Vector2i in [_h._first, _h.parking, _h.contact_location]:
		assert_true(_endpoint_ready(location, Space.MAX_CHECKS), "observed %s" % location)
		for profile: int in _endpoint_profiles():
			_h._profiles.descriptor_into(profile, _h._profiles._live.header[0], _h._binding._descriptor)
			_endpoint_memo(false)
			var plain: Array = _endpoint_run(location, profile, Space.MAX_CHECKS)
			var spent: int = Space.MAX_CHECKS - int(plain[1])
			_endpoint_memo(true)
			assert_equal(_endpoint_run(location, profile, Space.MAX_CHECKS), plain, "filling %s/%d" % [location, profile])
			assert_equal(_endpoint_run(location, profile, Space.MAX_CHECKS), plain, "answered %s/%d" % [location, profile])
			answered += 1 if _h._binding._endpoint_word(_h._binding._endpoint_entry(location, _h._binding._endpoint.point)) != 0 else 0
			for checks: int in range(0, spent + 1, maxi(1, spent >> 3)):
				_endpoint_memo(false)
				var short: Array = _endpoint_run(location, profile, checks)
				_endpoint_memo(true)
				_endpoint_run(location, profile, Space.MAX_CHECKS)
				assert_equal(_endpoint_run(location, profile, checks), short, "budget %d %s/%d" % [checks, location, profile])
	assert_true(answered > 0, "proofs were remembered and answered")


func _endpoint_filled() -> Array:
	"""Observe the parking endpoint, prove its first profile with the memo off (plain) and on (filling)."""
	var binding: WorldRoutes = _h._binding
	if not _endpoint_ready(_h.parking, Space.MAX_CHECKS): return []
	var rows: PackedInt32Array = _endpoint_profiles()
	_h._profiles.descriptor_into(rows[0], _h._profiles._live.header[0], binding._descriptor)
	_endpoint_memo(false)
	var plain: Array = _endpoint_run(_h.parking, rows[0], Space.MAX_CHECKS)
	_endpoint_memo(true)
	_endpoint_run(_h.parking, rows[0], Space.MAX_CHECKS)
	return [rows[0], plain]


func _endpoint_poison(profile: int) -> void:
	"""Make the remembered word for `profile` at the parking endpoint give another answer."""
	var binding: WorldRoutes = _h._binding
	var at: int = binding._endpoint_entry(_h.parking, binding._endpoint.point) * WorldRoutes.Profiles.MAX_PROFILES + profile
	binding._endpoint_memo[at] = (binding._endpoint_memo[at] & ~0xF) | (4 if (binding._endpoint_memo[at] & 0xF) != 4 else 1)


func _endpoint_remembered() -> bool:
	"""Whether the parking endpoint's current profile has a live word."""
	var binding: WorldRoutes = _h._binding
	return binding._endpoint_word(binding._endpoint_entry(_h.parking, binding._endpoint.point)) != 0


func test_endpoint_memo_answers_from_its_words_and_reports_a_stale_one() -> void:
	"""Decision 1952: an answered proof follows a poisoned word; another observed box reads afresh and retires the old
	word; with the framework's checks on a stale word is reported and never followed."""
	if not _fixture(): return
	var filled: Array = _endpoint_filled()
	assert_equal(filled.size(), 2, "observed and filled")
	if filled.size() != 2: return
	assert_true(_endpoint_remembered(), "remembered")
	_endpoint_poison(filled[0])
	assert_true(_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS) != filled[1], "answered from the memo")
	_h._binding._endpoint.support[0] -= 1
	assert_false(_endpoint_remembered(), "other boxes: refilled")
	_h._binding._endpoint.support[0] += 1
	assert_false(_endpoint_remembered(), "and the old word retired")
	_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS)
	_endpoint_poison(filled[0])
	WorldRoutes.Profiles.check_runtime_caches = true
	expect_diagnostic("RUNTIME_CACHE_STALE endpoint proof")
	assert_equal(_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS), filled[1], "checks on: reported, answered live")
	_h._binding._proof = null


func test_endpoint_memo_retires_on_every_stamped_input() -> void:
	"""Decision 1952: a moved Profiles token, other Domain bounds and another content revision each read afresh."""
	if not _fixture(): return
	var filled: Array = _endpoint_filled()
	assert_equal(filled.size(), 2, "observed and filled")
	if filled.size() != 2: return
	var binding: WorldRoutes = _h._binding
	for change: int in 3:
		_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS)
		assert_true(_endpoint_remembered(), "refilled before change %d" % change)
		match change:
			0: _h._profiles.invalidate_runtime_caches()
			1: binding._domain._bounds[3] += 1
			2: binding._descriptor.content_revision += 1
		assert_false(_endpoint_remembered(), "input %d moved" % change)
		if change == 1: binding._domain._bounds[3] -= 1
		if change == 2: binding._descriptor.content_revision -= 1
	binding._proof = null


func test_endpoint_memo_keeps_no_fault_and_reads_only_its_own_descriptor_and_boxes() -> void:
	"""Decision 1952: a proof that ran out of budget leaves nothing a full proof could borrow; a descriptor that is not
	the bank's current row is never answered; another envelope refills the entry."""
	if not _fixture(): return
	var filled: Array = _endpoint_filled()
	assert_equal(filled.size(), 2, "observed and filled")
	if filled.size() != 2: return
	var binding: WorldRoutes = _h._binding
	var spent: int = Space.MAX_CHECKS - int(filled[1][1])
	assert_true(spent > 1, "the proof spends")
	_endpoint_memo(true)
	var starved: Array = _endpoint_run(_h.parking, filled[0], spent - 1)
	assert_true(starved[2] != &"", "a starved proof faults")
	assert_equal(_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS), filled[1], "then a full proof is the plain one")
	binding._descriptor.profile_revision += 1
	assert_equal(binding._endpoint_entry(_h.parking, binding._endpoint.point), -1, "a stale descriptor row is not answered")
	binding._descriptor.profile_revision -= 1
	assert_true(_endpoint_remembered(), "remembered")
	binding._endpoint.envelope[0] -= 1
	assert_false(_endpoint_remembered(), "another envelope: refilled")
	binding._endpoint.envelope[0] += 1
	binding._proof = null
