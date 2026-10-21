extends "res://test/framework/test_case.gd"
## Decision 1970 (F2): the room itinerary's whole-search memo. A search answered from it must leave what a live search
## leaves and anything reads afterwards: the code and remaining-work output, Routes' budget, fault, path serial step and
## proposed chain, WorldRoutes' search descriptor and witness serial. (Routes' distance, predecessor, heap and state
## scratch is read outside a search only by WorldRoutes' witness, which the serial step keeps from matching; it is not
## replayed, and these cases do not compare it.) Each case runs a search with the memo off, then on twice.

const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Itinerary := StationTests.Itinerary
const Routes := StationTests.Routes
const Space := StationTests.Space
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const ANCHOR: int = 5

var _h: StationTests.StepFixture = null


func before_each() -> void:
	"""This suite tests the answered path itself, so the framework's live cross-check is off unless a case turns it on."""
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


func _memo(on: bool) -> void:
	"""Turn the search memo off (no slots: unusable) or on (empty slots)."""
	_h._binding._search_memo = PackedInt64Array()
	_h._binding._search_memo.resize(WorldRoutes.SEARCH_MEMO_SLOTS * WorldRoutes.SEARCH_MEMO_STRIDE if on else 0)


func _search(from: Vector2i, to: Vector2i, checks: int) -> Array:
	"""One search and everything it leaves that is read afterwards; the path serial is reported as its step."""
	var graph: Routes = _h._routes
	var serial: int = graph._path_serial
	var out: PackedInt32Array = PackedInt32Array([0])
	var code: StringName = Itinerary.reachability_refusal(_h._binding, from, to, ANCHOR, 1, StationTests.CONTENT, checks, out)
	var d: StationTests.Profiles.Descriptor = _h._binding._descriptor
	return [code, out[0], graph._remaining, graph._operation_error, graph._proposed_count,
		graph._proposed_edges.slice(0, 2 * maxi(graph._proposed_count, 0)), graph._path_serial - serial,
		[d.profile_id, d.profile_revision, d.content_revision, d.mode, d.posture], _h._binding._witness_serial]


func _slot(from: Vector2i, to: Vector2i) -> int:
	"""The offset of the slot this search uses."""
	return Itinerary._search_memo_slot(from, to, ANCHOR) * WorldRoutes.SEARCH_MEMO_STRIDE


func _three_ways(from: Vector2i, to: Vector2i, checks: int, label: String) -> Array:
	"""Off, filling and answered leave the same; returns the plain run."""
	_memo(false)
	var plain: Array = _search(from, to, checks)
	_memo(true)
	assert_equal(_search(from, to, checks), plain, "%s: filling" % label)
	assert_equal(_search(from, to, checks), plain, "%s: answered" % label)
	return plain


func test_answered_searches_leave_what_a_live_search_leaves() -> void:
	"""Both ways between the access and the parking, and from the parking to the station: answered as searched."""
	if not _fixture(): return
	var pairs: Array[Vector2i] = [_h._first, _h.parking, _h.parking, _h._first, _h.parking, _h._last]
	for index: int in range(0, pairs.size(), 2):
		var plain: Array = _three_ways(pairs[index], pairs[index + 1], Space.MAX_CHECKS, "pair %d" % index)
		assert_equal(plain[0], &"", "pair %d: a search that succeeds" % index)
		assert_true(_h._binding._search_memo[_slot(pairs[index], pairs[index + 1]) + Itinerary.S_SPENT] > 0,
			"pair %d: a remembered spend" % index)


func test_answers_come_from_the_memo() -> void:
	"""A remembered chain length and spend that are poisoned are followed: the memo really answers."""
	if not _fixture(): return
	var plain: Array = _three_ways(_h._first, _h.parking, Space.MAX_CHECKS, "reference")
	var at: int = _slot(_h._first, _h.parking)
	_h._binding._search_memo[at + Itinerary.S_SPENT] -= 1
	var answered: Array = _search(_h._first, _h.parking, Space.MAX_CHECKS)
	assert_equal(answered[2], plain[2] + 1, "the poisoned spend was replayed")
	_h._binding._search_memo[at + Itinerary.S_SPENT] += 1
	_h._binding._search_memo[at + Itinerary.S_DESCRIPTOR + 3] = 99
	assert_equal(_search(_h._first, _h.parking, Space.MAX_CHECKS)[7][3], 99, "the remembered descriptor was replayed")


func test_every_budget_is_answered_as_searched() -> void:
	"""At every budget around the whole spend (and a sweep below it) the answer equals the live search: a budget that
	cannot cover the remembered spend is searched live, so a fault happens exactly where it would."""
	if not _fixture(): return
	_memo(false)
	var full: Array = _search(_h._first, _h.parking, Space.MAX_CHECKS)
	var spend: int = Space.MAX_CHECKS - int(full[2])
	var budgets: Array[int] = []
	for checks: int in range(maxi(0, spend - 40), spend + 40): budgets.append(checks)
	for checks: int in range(0, spend, 97): budgets.append(checks)
	for checks: int in budgets:
		_memo(false)
		_search(_h._first, _h.parking, Space.MAX_CHECKS) # The same search before, so what a refusal leaves agrees.
		var plain: Array = _search(_h._first, _h.parking, checks)
		_memo(true)
		_search(_h._first, _h.parking, Space.MAX_CHECKS) # Fill at the full budget.
		assert_equal(_search(_h._first, _h.parking, checks), plain, "budget %d" % checks)


func test_every_receipt_and_query_word_retires_a_slot() -> void:
	"""A poisoned slot is followed only while the whole key holds: each receipt moving, or a restore's zero receipt,
	reads afresh (the poisoned spend is not replayed)."""
	if not _fixture(): return
	var plain: Array = _three_ways(_h._first, _h.parking, Space.MAX_CHECKS, "reference")
	var graph: Routes = _h._routes
	var cases: Array[Callable] = [
		func() -> void: graph._last_published_token += 1,
		func() -> void: _h._owner._last_published_token += 1,
		func() -> void: _h.endpoints._last_published_token += 1,
		func() -> void: _h._binding._certificate_revision += 1,
		func() -> void: _h._profiles.invalidate_runtime_caches(),
		func() -> void: _h.endpoints._last_published_token = 0]
	for index: int in cases.size():
		_memo(true)
		_search(_h._first, _h.parking, Space.MAX_CHECKS)
		var at: int = _slot(_h._first, _h.parking)
		_h._binding._search_memo[at + Itinerary.S_SPENT] -= 1
		var saved: int = _h.endpoints._last_published_token
		cases[index].call()
		var answered: Array = _search(_h._first, _h.parking, Space.MAX_CHECKS)
		assert_equal(answered[2], plain[2], "case %d: searched afresh, the poisoned slot not followed" % index)
		_h.endpoints._last_published_token = maxi(saved, _h.endpoints._last_published_token)


func test_a_changed_room_of_the_chain_is_searched_live() -> void:
	"""Buildings carries no publication receipt: a remembered chain whose section's Room no longer matches its source
	(the Room's type changed in place) is not answered, and the search refuses exactly as a live one."""
	if not _fixture(): return
	_three_ways(_h._first, _h.parking, Space.MAX_CHECKS, "reference")
	var row: int = _h._residents.directory().get_typed_row(_h.corridor)
	var buildings: RefCounted = _h._buildings
	var type_was: int = buildings._r_type[row]
	buildings._r_type[row] = type_was + 1
	_memo(false)
	var plain: Array = _search(_h._first, _h.parking, Space.MAX_CHECKS)
	assert_true(plain[0] != &"", "the live search refuses the changed Room")
	_memo(true)
	_search(_h._first, _h.parking, Space.MAX_CHECKS)
	buildings._r_type[row] = type_was
	_search(_h._first, _h.parking, Space.MAX_CHECKS) # Remember the good chain again.
	buildings._r_type[row] = type_was + 1
	assert_equal(_search(_h._first, _h.parking, Space.MAX_CHECKS), plain, "not answered: refused as live")
	buildings._r_type[row] = type_was


func test_with_checks_on_a_stale_slot_is_reported_and_the_search_runs_live() -> void:
	"""With the framework's checks on, a slot that would answer is replayed, put back and compared with the live
	search; a poisoned one is reported, and the search leaves exactly what a live one leaves."""
	if not _fixture(): return
	var plain: Array = _three_ways(_h._first, _h.parking, Space.MAX_CHECKS, "reference")
	WorldRoutes.Profiles.CacheChecks.enabled = true
	assert_equal(_search(_h._first, _h.parking, Space.MAX_CHECKS), plain, "agreeing: checked and silent")
	_h._binding._search_memo[_slot(_h._first, _h.parking) + Itinerary.S_SPENT] -= 1
	expect_diagnostic("RUNTIME_CACHE_STALE itinerary search")
	assert_equal(_search(_h._first, _h.parking, Space.MAX_CHECKS), plain, "a stale slot is reported, never followed")


func test_a_chain_longer_than_a_slot_is_not_kept() -> void:
	"""A successful search whose chain would not fit a slot leaves the slot as it was."""
	if not _fixture(): return
	_memo(true)
	var graph: Routes = _h._routes
	var at: int = _slot(_h._first, _h.parking)
	var count: int = graph._proposed_count
	graph._proposed_count = WorldRoutes.SEARCH_CHAIN_EDGES + 1
	Itinerary._remember_search(_h._binding, graph, _h._first, _h.parking, ANCHOR, 1, StationTests.CONTENT, 10, 0)
	graph._proposed_count = count
	assert_equal(_h._binding._search_memo[at + Itinerary.S_SPENT], 0, "nothing kept")


func test_every_key_input_and_query_word_reads_afresh() -> void:
	"""Each input the key reads beyond the receipts (the live geometry revision, the catalog and levels revisions) and
	each query word that shares the slot (the first and last generations, the revision and content) answers no slot."""
	if not _fixture(): return
	_three_ways(_h._first, _h.parking, Space.MAX_CHECKS, "reference")
	var graph: Routes = _h._routes
	var at: int = _slot(_h._first, _h.parking)
	assert_equal(Itinerary._search_memo_at(_h._binding, graph, _h._first, _h.parking, ANCHOR, 1, StationTests.CONTENT), at,
		"the slot answers its own search")
	var pokes: Array[Callable] = [
		func(d: int) -> void: _h._owner._header[17] += d,
		func(d: int) -> void: _h._binding._live_catalog_revision += d,
		func(d: int) -> void: _h._binding._levels._revision += d]
	for index: int in pokes.size():
		pokes[index].call(1)
		assert_equal(Itinerary._search_memo_at(_h._binding, graph, _h._first, _h.parking, ANCHOR, 1, StationTests.CONTENT),
			-1, "input %d moved: no answer" % index)
		pokes[index].call(-1)
	var first: Vector2i = _h._first
	var last: Vector2i = _h.parking
	var queries: Array = [[Vector2i(first.x, first.y + 1), last, 1, StationTests.CONTENT],
		[first, Vector2i(last.x, last.y + 1), 1, StationTests.CONTENT], [first, last, 2, StationTests.CONTENT],
		[first, last, 1, StationTests.CONTENT + 1]]
	for query: Array in queries:
		assert_equal(Itinerary._search_memo_at(_h._binding, graph, query[0], query[1], ANCHOR, query[2], query[3]), -1,
			"query %s: no answer" % [query])
	assert_equal(Itinerary._search_memo_at(_h._binding, graph, _h._first, _h.parking, ANCHOR, 1, StationTests.CONTENT), at,
		"unchanged again: answers")


func test_every_section_the_chain_crosses_is_read_again() -> void:
	"""`_sections_hold` re-reads the section of every edge of the chain, not only the first endpoint's: an edge whose
	section is no longer a live region fails it (the edge's section is poked in place, then put back)."""
	if not _fixture(): return
	_three_ways(_h._first, _h.parking, Space.MAX_CHECKS, "reference")
	var graph: Routes = _h._routes
	var at: int = _slot(_h._first, _h.parking)
	assert_true(Itinerary._sections_hold(_h._binding, graph, _h._first, at), "the chain's sections hold")
	@warning_ignore("integer_division") var chain: int = (at / WorldRoutes.SEARCH_MEMO_STRIDE) * 2 * WorldRoutes.SEARCH_CHAIN_EDGES
	var count: int = _h._binding._search_memo[at + Itinerary.S_COUNT]
	assert_true(count > 0, "a chain of edges")
	var row: int = _h._binding._search_chains[chain + (count - 1) * 2]
	var cap: int = graph._edge_capacity
	var was: Vector2i = Vector2i(graph._live.fields[Routes.E_SECTION_SLOT * cap + row], graph._live.fields[(Routes.E_SECTION_SLOT + 1) * cap + row])
	graph._live.fields[Routes.E_SECTION_SLOT * cap + row] = -1
	graph._live.fields[(Routes.E_SECTION_SLOT + 1) * cap + row] = 0
	assert_false(Itinerary._sections_hold(_h._binding, graph, _h._first, at), "an edge's dead section fails it")
	graph._live.fields[Routes.E_SECTION_SLOT * cap + row] = was.x
	graph._live.fields[(Routes.E_SECTION_SLOT + 1) * cap + row] = was.y
	assert_true(Itinerary._sections_hold(_h._binding, graph, _h._first, at), "restored")


func test_the_provider_reads_its_binding_once_with_the_same_revision() -> void:
	"""Decision 1970 (F3): the provider's bound revision equals `qualification_revision()` whenever the binding holds."""
	if not _fixture(): return
	var provider: RefCounted = _h.provider
	assert_true(provider != null and provider.get("_ordinary_routes") != null, "the room provider is bound")
	if not failures.is_empty(): return
	assert_equal(provider._ordinary_binding_leaf(), &"", "the binding holds")
	assert_equal(provider._ordinary_bound_revision(), provider.qualification_revision(), "the same revision")
	assert_true(provider._ordinary_bound_revision() > 0, "a usable revision")
