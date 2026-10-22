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
const MISS: int = -2
## Decision 1953: the most budgets one compile is replayed at (its whole spend, which is about 1,800 checks).
const SHORT_BUDGETS: int = 4096

var _h: StationTests.StepFixture = null


func before_each() -> void:
	"""Decision 1952: this suite tests the answered path itself, so the framework's live cross-check is off here."""
	WorldRoutes.Profiles.CacheChecks.enabled = false


func after_each() -> void:
	"""Free the fixture's owners; the framework's cache checks are back on for the next suite."""
	WorldRoutes.Profiles.CacheChecks.enabled = true
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


func _memo_answer(actual: WorldRoutes, graph: Routes, edge: int, anchor: int) -> int:
	"""The production pair: the slot that answers (edge_memo_hit), then its replay; MISS when no slot answers."""
	var at: int = WorldRoutes.edge_memo_hit(actual, graph, edge, anchor)
	return WorldRoutes.replay_edge_profile(actual, graph, at) if at >= 0 else MISS


func test_the_memo_answers_only_its_own_edge_anchor_and_a_clean_search() -> void:
	"""Same slot, other anchor: miss. A recorded fault: miss, and a faulted choice is never remembered."""
	if not _fixture(): return
	_memo(true)
	_memo_call_ready()
	var epoch: int = WorldRoutes.edge_memo_epoch(_h._binding, _h._routes)
	WorldRoutes.remember_edge_profile(_h._binding, _h._routes, 3, 5, 7, 100, false, epoch)
	assert_equal(_memo_answer(_h._binding, _h._routes, 3, 5), 7, "its own edge and anchor")
	assert_equal(_memo_answer(_h._binding, _h._routes, 3, 5 + WorldRoutes.EDGE_MEMO_SLOTS),
		MISS, "the same slot for another anchor")
	_h._routes._operation_error = &"ROUTE_OPERATION_BUDGET"
	assert_equal(_memo_answer(_h._binding, _h._routes, 3, 5), MISS, "a recorded fault")
	WorldRoutes.remember_edge_profile(_h._binding, _h._routes, 4, 5, 9, 100, false, epoch)
	_h._routes._operation_error = &""
	assert_equal(_memo_answer(_h._binding, _h._routes, 4, 5), MISS, "not remembered")
	_h._routes._remaining = 99
	assert_equal(_memo_answer(_h._binding, _h._routes, 3, 5), MISS, "budget short")
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
	assert_equal(_memo_answer(_h._binding, _h._routes, 3, 5), -1, "answered")
	assert_equal(descriptor.profile_id, 12, "no write replayed")
	descriptor.posture = 3
	descriptor.mode = 2
	WorldRoutes.remember_edge_profile(_h._binding, _h._routes, 3, 5, 6, 10, true, epoch)
	descriptor.profile_id = 13
	descriptor.posture = 4
	descriptor.mode = 1
	assert_equal(_memo_answer(_h._binding, _h._routes, 3, 5), 6, "answered")
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


func _edit_edge(edge: int, change: int, step: int) -> void:
	"""Negative-only in-place edits of one edge's inputs, undone by the opposite step."""
	var bank: WorldRoutes.Certificates = _h._binding._live
	match change:
		0: bank.masks[edge * WorldRoutes.MASK_BYTES] ^= 0xFF
		1: bank.generations[edge] += step
		2: bank.geometry[edge] += step
		3: bank.content[edge] += step
		4: _h._routes._live.fields[Routes.E_GENERATION * _h._routes._edge_capacity + edge] += step



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
	WorldRoutes.Profiles.CacheChecks.enabled = true
	assert_equal(_search(_h._first, _h.parking, 5, Space.MAX_CHECKS), plain, "agreeing slots: checked and silent")
	assert_true(_poison_filled_slots() > 0, "slots to poison")
	expect_diagnostic("RUNTIME_CACHE_STALE itinerary edge profile")
	assert_equal(_search(_h._first, _h.parking, 5, Space.MAX_CHECKS), plain, "a stale slot is reported, never followed")


func test_with_checks_on_a_slot_with_the_wrong_spend_is_reported() -> void:
	"""Decision 1952: a slot with the right choice but another spend is reported with checks on."""
	if not _fixture(): return
	_memo(false)
	var plain: Array = _search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	_memo(true)
	_search(_h._first, _h.parking, 5, Space.MAX_CHECKS)
	var memo: PackedInt64Array = _h._binding._edge_memo
	var spent: int = 0
	for slot: int in WorldRoutes.EDGE_MEMO_SLOTS:
		var at: int = slot * WorldRoutes.EDGE_MEMO_STRIDE
		if memo[at] == _h._binding._edge_memo_epoch and memo[at + 4] > 0:
			memo[at + 4] -= 1
			spent += 1
	_h._binding._edge_memo = memo
	assert_true(spent > 0, "slots with a spend to change")
	WorldRoutes.Profiles.CacheChecks.enabled = true
	expect_diagnostic("RUNTIME_CACHE_STALE itinerary edge profile")
	assert_equal(_search(_h._first, _h.parking, 5, Space.MAX_CHECKS), plain, "same choice, other spend: reported")


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
	WorldRoutes.Profiles.CacheChecks.enabled = true
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


func _endpoint_run(location: Vector2i, _profile: int, checks: int) -> Array:
	"""One endpoint box proof for the described profile at budget `checks`: its answer, remaining budget and fault."""
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


func _endpoint_budgets(spent: int, chunk: int) -> PackedInt64Array:
	"""Every chunk boundary up to the whole spend and one check either side of it, plus zero."""
	var budgets: PackedInt64Array = PackedInt64Array([0, maxi(spent - 1, 0), spent, spent + 1])
	for boundary: int in range(chunk, spent + 1, chunk):
		budgets.append(boundary - 1)
		budgets.append(boundary)
	return budgets


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
			for checks: int in _endpoint_budgets(spent, 1 + _h._binding._descriptor.box_count):
				_endpoint_memo(false)
				var short: Array = _endpoint_run(location, profile, checks)
				_endpoint_memo(true)
				_endpoint_run(location, profile, Space.MAX_CHECKS)
				assert_equal(_endpoint_run(location, profile, checks), short, "budget %d %s/%d" % [checks, location, profile])
	assert_true(answered > 0, "proofs were remembered and answered")
	_h._binding._proof = null


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
	WorldRoutes.Profiles.CacheChecks.enabled = true
	expect_diagnostic("RUNTIME_CACHE_STALE endpoint proof")
	assert_equal(_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS), filled[1], "checks on: reported, answered live")
	WorldRoutes.Profiles.CacheChecks.enabled = false
	assert_equal(_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS), filled[1], "the checked word was refreshed")
	_h._binding._proof = null


func test_with_checks_on_a_word_with_the_wrong_spend_is_reported() -> void:
	"""Decision 1952: a remembered word with the right answer but another number of boxes checked is reported."""
	if not _fixture(): return
	var filled: Array = _endpoint_filled()
	assert_equal(filled.size(), 2, "observed and filled")
	if filled.size() != 2: return
	var binding: WorldRoutes = _h._binding
	var at: int = binding._endpoint_entry(_h.parking, binding._endpoint.point) * WorldRoutes.Profiles.MAX_PROFILES + filled[0]
	var boxes: int = (binding._endpoint_memo[at] >> 4) & 0xFFF
	binding._endpoint_memo[at] = (binding._endpoint_memo[at] & ~0xFFF0) | (((boxes + 1) & 0xFFF) << 4)
	WorldRoutes.Profiles.CacheChecks.enabled = true
	expect_diagnostic("RUNTIME_CACHE_STALE endpoint proof")
	assert_equal(_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS), filled[1], "same answer, other spend: reported")
	binding._proof = null


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
	binding._endpoint_memo_serial = WorldRoutes.ENDPOINT_SERIAL_MAX
	binding._endpoint.support[0] -= 1
	assert_equal(binding._endpoint_entry(_h.parking, binding._endpoint.point), -1, "a saturated serial fills nothing")
	binding._endpoint.support[0] += 1
	assert_true(binding._endpoint_entry(_h.parking, binding._endpoint.point) >= 0, "the unchanged entry still matches")
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
	binding._descriptor.box_count += 1
	assert_equal(binding._endpoint_entry(_h.parking, binding._endpoint.point), -1, "a stale box count is not answered")
	binding._descriptor.box_count -= 1
	assert_true(_endpoint_remembered(), "remembered")
	binding._endpoint.envelope[0] -= 1
	assert_false(_endpoint_remembered(), "another envelope: refilled")
	binding._endpoint.envelope[0] += 1
	binding._proof = null


func test_every_observed_word_retires_an_endpoint_entry() -> void:
	"""Decision 1952: each of the entry's words (point, envelope, support, air count, each air word) is compared."""
	if not _fixture(): return
	var filled: Array = _endpoint_filled()
	assert_equal(filled.size(), 2, "observed and filled")
	if filled.size() != 2: return
	var record: WorldRoutes.Locations.Record = _h._binding._endpoint
	record.air_count = 3
	_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS)
	for word: int in 34:
		assert_true(_endpoint_remembered(), "filled before word %d" % word)
		_shift_endpoint_word(record, word, 1)
		assert_false(_endpoint_remembered(), "word %d is compared" % word)
		_shift_endpoint_word(record, word, -1)
		_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS)
	_h._binding._proof = null


func _shift_endpoint_word(record: WorldRoutes.Locations.Record, word: int, step: int) -> void:
	"""Move one of the 34 entry words of `record` by `step` (point 0-2, envelope 3-8, support 9-14, air count 15, air
	16-33)."""
	if word < 3: record.point[word] += step
	elif word < 9: record.envelope[word - 3] += step
	elif word < 15: record.support[word - 9] += step
	elif word == 15: record.air_count += -step # 3 -> 2 and back: still a legal count.
	else: record.air[word - 16] += step


func test_with_checks_on_a_short_budget_answer_is_checked_without_a_false_report() -> void:
	"""Decision 1952: with checks on, a remembered word replayed at a budget that runs out part way agrees with the
	live checks (no report); a poisoned word that refuses at its first box is reported."""
	if not _fixture(): return
	var filled: Array = _endpoint_filled()
	assert_equal(filled.size(), 2, "observed and filled")
	if filled.size() != 2: return
	var spent: int = Space.MAX_CHECKS - int(filled[1][1])
	assert_true(spent >= 2 * (1 + _h._binding._descriptor.box_count), "the proof checks at least two boxes")
	_endpoint_memo(false)
	var plain: Array = _endpoint_run(_h.parking, filled[0], spent - 1)
	_endpoint_memo(true)
	_endpoint_run(_h.parking, filled[0], Space.MAX_CHECKS)
	WorldRoutes.Profiles.CacheChecks.enabled = true
	assert_equal(_endpoint_run(_h.parking, filled[0], spent - 1), plain, "short budget, agreeing: silent")
	var binding: WorldRoutes = _h._binding
	var at: int = binding._endpoint_entry(_h.parking, binding._endpoint.point) * WorldRoutes.Profiles.MAX_PROFILES + filled[0]
	binding._endpoint_memo[at] = (binding._endpoint_memo[at] & ~0xFFFF) | (1 << 4) | 3 # One box checked, then BODY.
	expect_diagnostic("RUNTIME_CACHE_STALE endpoint proof")
	assert_equal(_endpoint_run(_h.parking, filled[0], spent - 1), plain, "short budget, stale: reported, live used")
	binding._proof = null


func test_an_observation_is_kept_only_inside_its_compile() -> void:
	"""Decision 1953: inside one edge compile a successful prepared observation is kept (key: serial, Location,
	point) and copied back; another compile serial, another point, the live path or a compile that is over keeps
	nothing; the copy holds every field a prepared observation writes."""
	if not _fixture(): return
	var binding: WorldRoutes = _h._binding
	assert_true(binding._locations().read_location_into(_h.parking, binding._endpoint) == &"", "a real record")
	binding._endpoint.air_count = 2
	binding._endpoint.air[7] = 99
	var point: Vector3i = binding._endpoint.point
	binding._compiling = true
	binding._location_token = 1
	binding._remember_observation(_h.parking, point)
	var slot: int = binding._observed_slot(_h.parking, point)
	assert_true(slot >= 0, "kept for this compile")
	assert_equal(binding._observed_slot(_h.parking, point + Vector3i(1, 0, 0)), -1, "another point")
	assert_equal(binding._observed_slot(Vector2i(_h.parking.x, _h.parking.y + 1), point), -1, "another generation")
	var copy: WorldRoutes.Locations.Record = WorldRoutes.Locations.Record.new()
	copy.envelope.resize(6)
	copy.support.resize(6)
	WorldRoutes._copy_record(binding._observed[slot], copy)
	assert_true(WorldRoutes._records_equal(copy, binding._endpoint), "every field copied")
	copy.air[7] = 98
	assert_false(WorldRoutes._records_equal(copy, binding._endpoint), "and compared")
	binding._location_token = 0
	assert_equal(binding._observed_slot(_h.parking, point), -1, "the live (unprepared) path is never answered")
	binding._location_token = 1
	var serial: int = binding._observe_serial
	assert_equal(binding._compile_edge(null), WorldRoutes.REFUSE_CONTEXT, "a compile, refused at once")
	assert_true(binding._observe_serial == WorldRoutes._next_revision(serial), "still moves the serial")
	assert_equal(binding._observed_slot(_h.parking, point), -1, "the next compile keeps nothing")
	binding._location_token = 0
	binding._remember_observation(_h.parking, point)
	binding._location_token = 1
	assert_equal(binding._observed_slot(_h.parking, point), -1, "the live (unprepared) path is never kept")
	binding._remember_observation(_h.parking, point)
	assert_true(binding._observed_slot(_h.parking, point) >= 0, "kept on the prepared path")
	binding._compiling = false
	assert_equal(binding._observed_slot(_h.parking, point), -1, "a compile that is over answers nothing")
	binding._remember_observation(_h.parking, point + Vector3i(0, 0, 1))
	binding._compiling = true
	assert_equal(binding._observed_slot(_h.parking, point + Vector3i(0, 0, 1)), -1, "and keeps nothing")
	binding._observe_serial = 0
	assert_equal(binding._observed_slot(_h.parking, point), -1, "a saturated serial keeps nothing")
	binding._compiling = false
	binding._location_token = 0


func test_an_answered_observation_spends_first_and_leaves_exactly_what_was_kept() -> void:
	"""Decision 1953: a repeat inside one compile spends before it answers, refuses when the spend does not fit, and
	leaves `_endpoint` exactly as the kept observation left it. Decision 2045 (P-2045-4 (a)): it spends what answering
	does, ANSWERED_OBSERVATION_CHECKS, the same with the cache checks on or off."""
	if not _fixture(): return
	var binding: WorldRoutes = _h._binding
	assert_true(binding._locations().read_location_into(_h.parking, binding._endpoint) == &"", "a real record")
	var point: Vector3i = binding._endpoint.point
	binding._proof = WorldRoutes.Clearance.new()
	binding._proof.allocate(Space.Snapshot.new(), Space.MAX_CHECKS)
	binding._compiling = true
	binding._location_token = 1
	binding._remember_observation(_h.parking, point)
	var kept: WorldRoutes.Locations.Record = WorldRoutes.Locations.Record.new()
	kept.envelope.resize(6)
	kept.support.resize(6)
	WorldRoutes._copy_record(binding._endpoint, kept)
	binding._endpoint.point = Vector3i(-1, -1, -1)
	binding._endpoint.payload_revision = 0
	binding._endpoint.air[0] = -5
	var before: int = binding._proof.remaining
	assert_equal(binding._endpoint_observation_refusal(_h.parking, point), &"", "answered")
	assert_equal(before - binding._proof.remaining, WorldRoutes.ANSWERED_OBSERVATION_CHECKS, "an answer's spend")
	assert_true(WorldRoutes._records_equal(binding._endpoint, kept), "left exactly as kept")
	binding._proof.remaining = WorldRoutes.ANSWERED_OBSERVATION_CHECKS - 1
	assert_true(binding._endpoint_observation_refusal(_h.parking, point) != &"", "a spend that does not fit refuses")
	binding._compiling = false
	binding._location_token = 0
	binding._proof = null


func test_a_compile_answered_from_the_caches_leaves_what_a_checked_compile_leaves() -> void:
	"""Decision 1953: in a real route preparation, each published edge compiled with the framework's checks on (every
	cache recomputed live) and again with them off (the caches answering, the pace memo filled by the first) gives
	the same code, spend, proof error, certificate row, descriptor, endpoint record and pace."""
	if not _fixture(): return
	var binding: WorldRoutes = _h._binding
	var graph: Routes = _h._routes
	var cold: int = _h._budget.acquire(StationTests.Budget.COLD_BYTES)
	var token: int = binding.begin_prepare(cold).token
	assert_true(token != 0, "a real preparation")
	var compared: int = 0
	for index: int in (graph._live.edge_count if token != 0 else 0):
		var edge: Routes.Edge = graph._edge
		graph._read_edge(graph._live, graph._live.ordered[index], edge)
		var checked: Array = _compiled(edge, token, true)
		assert_equal(_compiled(edge, token, false), checked, "edge %d" % edge.ref.x)
		compared += 1 if checked[0] == &"" else 0
	assert_true(compared > 0, "some edges qualify")
	if token != 0: _assert_short_budgets_leave_the_same(token)
	if token != 0: assert_true(binding.abort(token), "the preparation is abandoned")
	assert_equal(_h._budget.release(cold), &"", "the lease is released")


func _assert_short_budgets_leave_the_same(token: int) -> void:
	"""The first edge again at every budget up to its whole spend (at most SHORT_BUDGETS), so the budget runs out after
	each profile in turn, including after profiles refused on kind."""
	var binding: WorldRoutes = _h._binding
	var graph: Routes = _h._routes
	var edge: Routes.Edge = graph._edge
	graph._read_edge(graph._live, graph._live.ordered[0], edge)
	var full: int = binding._proof.remaining
	var spent: int = _compiled(edge, token, true)[1]
	assert_true(spent > 0 and spent <= SHORT_BUDGETS, "the whole spend is replayed")
	for budget: int in range(1, mini(spent, SHORT_BUDGETS) + 1):
		binding._proof.remaining = budget
		var checked: Array = _compiled(edge, token, true)
		binding._proof.remaining = budget
		assert_equal(_compiled(edge, token, false), checked, "budget %d" % budget)
	binding._proof.remaining = full


func _compiled(edge: Routes.Edge, token: int, checks: bool) -> Array:
	"""One compile and everything it leaves, from a poisoned descriptor and pace so nothing is inherited from the
	compile before; the proof's budget and error are put back for the next."""
	var binding: WorldRoutes = _h._binding
	var remaining: int = binding._proof.remaining
	binding._descriptor.profile_id = -9
	binding._descriptor.mode = -9
	binding._pace.succeed(-9)
	WorldRoutes.Profiles.CacheChecks.enabled = checks
	var code: StringName = binding.edge_refusal(edge, token, 0, 0)
	WorldRoutes.Profiles.CacheChecks.enabled = false
	var row: int = edge.ref.x
	var left: Array = [code, remaining - binding._proof.remaining, binding._proof.error,
		binding._stage.masks.slice(row * WorldRoutes.MASK_BYTES, (row + 1) * WorldRoutes.MASK_BYTES),
		binding._stage.generations[row], binding._stage.geometry[row], binding._stage.content[row],
		_fields(binding._descriptor), _fields(binding._endpoint), [binding._pace.ok, binding._pace.value]]
	binding._proof.remaining = remaining
	binding._proof.error = &""
	return left


func _fields(object: Object) -> Array:
	"""Every script variable of `object`, packed arrays copied."""
	var values: Array = []
	for property: Dictionary in object.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = object.get(property["name"])
			values.append(value.duplicate() if value is PackedInt32Array or value is PackedInt64Array else value)
	return values


func test_a_kept_pace_is_read_afresh_when_what_pace_into_reads_moves() -> void:
	"""Decision 1953: a kept pace answers only while Profiles' load token and every Movement profile's revision and
	speed equal the preparation's stamp; any of them moving sends the next call to `pace_into`."""
	if not _fixture(): return
	var binding: WorldRoutes = _h._binding
	binding._content_revision = _h._profiles._live.header[0]
	binding._catalog_revision = binding._catalog._live.header[0]
	binding._compiling = true
	binding._pace_serial = WorldRoutes._next_revision(binding._pace_serial)
	var profile: int = _pacing_profile(binding)
	assert_true(profile >= 0, "a pacing profile")
	var slot: int = posmod(profile * 31 - 7, WorldRoutes.PACE_SLOTS)
	var movement: WorldRoutes.Movement = binding._catalog._movement
	for move: int in 3:
		assert_true(binding._pace_inputs_hold(true), "stamped")
		binding._compile_pace(profile, -1, 0)
		binding._pace_codes[slot] = &"POISON"
		assert_equal(binding._compile_pace(profile, -1, 0), &"POISON", "move %d: answered while nothing moved" % move)
		match move:
			0: _h._profiles.invalidate_runtime_caches()
			1: movement._profile_speed_u_per_s[0] += 1
			2: assert_true(movement.revise_profile(0), "a Movement profile revised")
		assert_true(binding._compile_pace(profile, -1, 0) != &"POISON", "move %d: read afresh" % move)
		if move == 1: movement._profile_speed_u_per_s[0] -= 1
	binding._compiling = false


func _pacing_profile(binding: WorldRoutes) -> int:
	"""The first profile that paces with no family, its descriptor left in the binding."""
	for row: int in _h._profiles._live.header[1]:
		if _h._profiles.descriptor_into(row, binding._content_revision, binding._descriptor) != &"": continue
		if binding._catalog.pace_into(row, binding._descriptor.profile_revision, binding._content_revision, -1, 0,
				binding._catalog_revision, binding._pace) == &"": return row
	return -1


func test_a_pace_is_kept_only_inside_its_preparation() -> void:
	"""Decision 1953: inside one preparation `_compile_pace` answers as `pace_into` for every profile (refusals
	leave `_pace` alone), answers a repeat from the memo, keeps nothing outside a compile or across preparations, and
	is reported stale with checks on."""
	if not _fixture(): return
	var binding: WorldRoutes = _h._binding
	binding._content_revision = _h._profiles._live.header[0]
	binding._catalog_revision = binding._catalog._live.header[0]
	binding._compiling = true
	var answered: int = 0
	for profile: int in _h._profiles._live.header[1]:
		if _h._profiles.descriptor_into(profile, binding._content_revision, binding._descriptor) != &"": continue
		for family: int in [-1, 0]:
			binding._pace.succeed(-7)
			var live: StringName = binding._catalog.pace_into(profile, binding._descriptor.profile_revision,
				binding._content_revision, family, 0, binding._catalog_revision, binding._pace)
			var live_value: int = binding._pace.value
			binding._pace.succeed(-7)
			assert_equal(binding._compile_pace(profile, family, 0), live, "filling %d/%d" % [profile, family])
			binding._pace.succeed(-7)
			assert_equal(binding._compile_pace(profile, family, 0), live, "answered %d/%d" % [profile, family])
			assert_equal(binding._pace.value, live_value if live == &"" else -7, "the pace left as the call leaves it")
			answered += 1 if live == &"" else 0
	assert_true(answered > 0, "some profiles pace")
	_assert_pace_memo_retires(binding)


func _assert_pace_memo_retires(binding: WorldRoutes) -> void:
	"""A poisoned kept answer is followed; a new preparation, or a call outside a compile, is read afresh; checks on
	report the poison."""
	var profile: int = -1
	for row: int in _h._profiles._live.header[1]:
		_h._profiles.descriptor_into(row, binding._content_revision, binding._descriptor)
		if binding._compile_pace(row, -1, 0) == &"": profile = row
		if profile >= 0: break
	assert_true(profile >= 0, "a pacing profile")
	var slot: int = posmod(profile * 31 - 7, WorldRoutes.PACE_SLOTS)
	binding._pace_codes[slot] = &"POISON"
	assert_equal(binding._compile_pace(profile, -1, 0), &"POISON", "answered from the memo")
	assert_true(binding._compile_pace(profile, WorldRoutes.PACE_SLOTS - 1, 0) != &"POISON",
		"a family one slot period away, at the same variant, is read afresh")
	assert_true(binding._compile_pace(profile, 0, -7) != &"POISON", "the same slot for another family is read afresh")
	binding._pace_codes[slot] = &"POISON"
	binding._descriptor.profile_revision += 1
	assert_true(binding._compile_pace(profile, -1, 0) != &"POISON", "another profile revision is read afresh")
	binding._descriptor.profile_revision -= 1
	assert_equal(binding._compile_pace(profile, -1, 0), &"", "refilled at the true revision")
	binding._pace_codes[slot] = &"POISON"
	binding._compiling = false
	assert_equal(binding._compile_pace(profile, -1, 0), &"", "outside a compile: read afresh")
	binding._compiling = true
	binding._pace_codes[slot] = &"POISON"
	WorldRoutes.Profiles.CacheChecks.enabled = true
	expect_diagnostic("RUNTIME_CACHE_STALE pace")
	assert_equal(binding._compile_pace(profile, -1, 0), &"", "checks on: reported and read live")
	WorldRoutes.Profiles.CacheChecks.enabled = false
	binding._pace_codes[slot] = &"POISON"
	var serial: int = binding._pace_serial
	binding._begin_proof()
	assert_true(binding._pace_serial == WorldRoutes._next_revision(serial), "every preparation moves the serial")
	assert_equal(binding._compile_pace(profile, -1, 0), &"", "a new preparation keeps nothing")
	binding._compiling = false


func test_other_kind_profiles_are_refused_as_the_full_proof_refuses_them() -> void:
	"""Decision 1953: for every profile and every published edge, `_other_kind` is true exactly when the full proof's
	descriptor succeeds and `_kind_matches` fails; a skipped last profile's descriptor is written back."""
	if not _fixture(): return
	var binding: WorldRoutes = _h._binding
	binding._content_revision = _h._profiles._live.header[0]
	var graph: Routes = _h._routes
	var compared: int = 0
	for index: int in graph._live.edge_count:
		var row: int = graph._live.ordered[index]
		var edge: Routes.Edge = graph._edge
		graph._read_edge(graph._live, row, edge)
		for profile: int in _h._profiles._live.header[1] + 1:
			var full: bool = _h._profiles.descriptor_into(profile, binding._content_revision, binding._descriptor) == &"" \
				and not binding._kind_matches(edge)
			assert_equal(binding._other_kind(profile, edge), full, "edge %d profile %d" % [row, profile])
			compared += 1 if full else 0
	assert_true(compared > 0, "some profiles are of another kind")
	binding._descriptor.profile_id = -9
	assert_equal(binding._restored_descriptor(3, &"X"), &"X", "the code passes through")
	assert_equal(binding._descriptor.profile_id, 3, "the skipped profile's descriptor is written")
	binding._descriptor.profile_id = -9
	binding._restored_descriptor(-1, &"")
	assert_equal(binding._descriptor.profile_id, -9, "nothing skipped, nothing written")


func test_with_checks_on_a_kept_observation_is_observed_live_and_compared() -> void:
	"""Decision 1953: with the framework's checks on, a kept observation is never followed: the endpoint is observed
	live (here outside any transaction, so it refuses) and the difference is reported."""
	if not _fixture(): return
	var binding: WorldRoutes = _h._binding
	assert_true(binding._locations().read_location_into(_h.parking, binding._endpoint) == &"", "a real record")
	var point: Vector3i = binding._endpoint.point
	binding._proof = WorldRoutes.Clearance.new()
	binding._proof.allocate(Space.Snapshot.new(), Space.MAX_CHECKS)
	binding._compiling = true
	binding._location_token = 1
	binding._remember_observation(_h.parking, point)
	WorldRoutes.Profiles.CacheChecks.enabled = true
	expect_diagnostic("RUNTIME_CACHE_STALE endpoint observation")
	assert_true(binding._endpoint_observation_refusal(_h.parking, point) != &"", "observed live: refused")
	binding._compiling = false
	binding._location_token = 0
	binding._proof = null


func test_the_kind_fast_path_tests_every_condition_of_kind_matches() -> void:
	"""Decision 1953: for one certified profile, an edge of its own mode and posture, with no family or one its mask
	holds, is of its kind; changing the mode, the posture, the family to one outside the mask, or the profile's
	certificate flags, makes it of another kind, and the full proof agrees each time."""
	if not _fixture(): return
	var binding: WorldRoutes = _h._binding
	binding._content_revision = _h._profiles._live.header[0]
	var profile: int = _certified_profile(binding)
	assert_true(profile >= 0, "a certified profile")
	var mask: int = binding._descriptor.family_mask
	var edge: Routes.Edge = _h._routes._edge
	edge.mode = binding._descriptor.mode
	edge.posture = binding._descriptor.posture
	edge.family = -1
	assert_false(binding._other_kind(profile, edge), "its own kind, with no family")
	var outside: int = 0
	while (mask & (1 << outside)) != 0: outside += 1
	for family: int in 62:
		edge.family = family
		assert_equal(binding._other_kind(profile, edge), (mask & (1 << family)) == 0, "family %d" % family)
	edge.family = -1
	for change: int in 4:
		_change_kind(profile, edge, change, outside, 1)
		var full: bool = _h._profiles.descriptor_into(profile, binding._content_revision, binding._descriptor) == &"" \
			and not binding._kind_matches(edge)
		assert_true(full and binding._other_kind(profile, edge), "change %d: another kind" % change)
		_change_kind(profile, edge, change, -1, -1)
	assert_false(binding._other_kind(profile, edge), "every change undone")
	_h._profiles.invalidate_runtime_caches()


func _certified_profile(binding: WorldRoutes) -> int:
	"""The first profile whose certificate is the required one, its descriptor left in the binding."""
	for row: int in _h._profiles._live.header[1]:
		_h._profiles.descriptor_into(row, binding._content_revision, binding._descriptor)
		if binding._descriptor.certificate_flags == WorldRoutes.Profiles.CERT_REQUIRED: return row
	return -1


func _change_kind(profile: int, edge: Routes.Edge, change: int, family: int, direction: int) -> void:
	"""Apply (direction 1) or undo (direction -1) one kind change; the certificate flags change is negative-only and
	restored."""
	match change:
		0: edge.mode += direction
		1: edge.posture += direction
		2: edge.family = family
		3: _h._profiles._live.flags[profile] = 0 if direction > 0 else WorldRoutes.Profiles.CERT_REQUIRED
