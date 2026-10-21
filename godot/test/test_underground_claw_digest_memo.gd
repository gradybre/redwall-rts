extends "res://test/framework/test_case.gd"
## Decision 1970 (F4): the claw programs' image digest verdicts, remembered on the Profiles store against its bank and
## load revision. Answered as the live compare; a poisoned verdict is followed with the checks off (so it really
## answers) and reported with them on; a moved token, a swapped bank or a loading store reads afresh.

const ClawTests := preload("res://test/test_underground_room_claw_kitchen.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Claw2 := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd")
const Claw1 := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/claw_program.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _h: ClawTests.ClawKitchen = null


func before_each() -> void:
	"""This suite tests the answered path, so the framework's live cross-check is off unless a case turns it on."""
	Profiles.CacheChecks.enabled = false


func after_each() -> void:
	"""Free the fixture; the framework's cache checks are back on for the next suite."""
	Profiles.CacheChecks.enabled = true
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % [_h.failures])
	_h = null


func _profiles() -> Profiles:
	"""The claw Kitchen's store, the mounted content-12 wire loaded."""
	_h = ClawTests.ClawKitchen.new()
	_h.stocked = true
	if _h.confirmed_room() == NULL_REF: return null
	return _h._profiles


func test_the_verdicts_answer_as_the_live_compare() -> void:
	"""Both programs, read cold, then answered: the live verdict each time, and remembered at the store's token."""
	var profiles: Profiles = _profiles()
	if profiles == null: return
	for round: int in 2:
		assert_equal(Claw2._digest_matches(profiles), Claw2._digest_live(profiles), "v2, round %d" % round)
		assert_equal(Claw1._digest_matches(profiles), Claw1._digest_live(profiles), "v1, round %d" % round)
	assert_equal(profiles.remembered_digest(Profiles.CLAW_DIGEST_V2), 1 if Claw2._digest_live(profiles) else 0, "v2 kept")
	assert_equal(profiles.remembered_digest(Profiles.CLAW_DIGEST_V1), 1 if Claw1._digest_live(profiles) else 0, "v1 kept")
	assert_true(Claw2._digest_live(profiles), "content 12's source 4 is the claw v2 image")


func test_a_poisoned_verdict_is_followed_then_retired_by_a_moved_token() -> void:
	"""Checks off, a remembered verdict answers (poisoned, it is followed); a moved load token reads afresh."""
	var profiles: Profiles = _profiles()
	if profiles == null: return
	var live: bool = Claw2._digest_matches(profiles)
	profiles._claw_digest_memo[Profiles.CLAW_DIGEST_V2 * Profiles.CLAW_DIGEST_STRIDE + 2] = 0 if live else 1
	assert_equal(Claw2._digest_matches(profiles), not live, "the remembered verdict answers")
	profiles.invalidate_runtime_caches()
	assert_equal(Claw2._digest_matches(profiles), live, "a moved token reads afresh")
	profiles._claw_digest_memo[Profiles.CLAW_DIGEST_V2 * Profiles.CLAW_DIGEST_STRIDE + 1] = 1
	assert_equal(profiles.remembered_digest(Profiles.CLAW_DIGEST_V2), -1, "another bank is never answered")
	profiles._loading = true
	assert_equal(profiles.remembered_digest(Profiles.CLAW_DIGEST_V2), -1, "a loading store is never answered")
	profiles._loading = false


func test_with_checks_on_a_poisoned_verdict_is_reported_and_the_live_one_answers() -> void:
	"""Checks on: the live compare answers, and a remembered verdict that differs is reported."""
	var profiles: Profiles = _profiles()
	if profiles == null: return
	var live: bool = Claw2._digest_matches(profiles)
	Profiles.CacheChecks.enabled = true
	assert_equal(Claw2._digest_matches(profiles), live, "agreeing: checked and silent")
	profiles._claw_digest_memo[Profiles.CLAW_DIGEST_V2 * Profiles.CLAW_DIGEST_STRIDE + 2] = 0 if live else 1
	expect_diagnostic("RUNTIME_CACHE_STALE claw digest")
	assert_equal(Claw2._digest_matches(profiles), live, "the live verdict, reported")


func test_an_unannounced_source_edit_is_caught_with_checks_on() -> void:
	"""The contract: a bank edited in place must announce itself. Without the announcement the remembered verdict is
	stale; with checks on it is reported, and with the announcement it is read afresh."""
	var profiles: Profiles = _profiles()
	if profiles == null: return
	assert_true(Claw2._digest_matches(profiles), "matched")
	var at: int = Claw2.SOURCE * 32
	var was: int = profiles._live.sources[at]
	profiles._live.sources[at] = (was + 1) % 256
	assert_true(Claw2._digest_matches(profiles), "unannounced, checks off: the stale verdict answers")
	Profiles.CacheChecks.enabled = true
	expect_diagnostic("RUNTIME_CACHE_STALE claw digest")
	assert_false(Claw2._digest_matches(profiles), "checks on: the live verdict, reported")
	Profiles.CacheChecks.enabled = false
	profiles.invalidate_runtime_caches()
	assert_false(Claw2._digest_matches(profiles), "announced: read afresh")
	profiles._live.sources[at] = was
	profiles.invalidate_runtime_caches()
	assert_true(Claw2._digest_matches(profiles), "restored and announced")
