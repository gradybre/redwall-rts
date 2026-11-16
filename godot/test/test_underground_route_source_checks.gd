extends "res://test/underground_host_case.gd"
## Decision 1951: Routes' source-program checks read the step closure (`ShortStep.uses`) once instead of up to three
## times. Both rewritten checks are compared with the pre-1951 code, copied here as the oracle, over every profile
## row, revision and content of the content-6 step rows and of the mounted content-12 claw, stair and handling rows,
## every program phase word and several clocks, with the step closure intact and broken.

const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Stair := Routes.Stair
const ShortStep := Routes.ShortStep
const SourceProgram := Routes.SourceProgram

var _h: StationTests.StepFixture = null
var _routes: Routes = null
var _profiles: Profiles = null


func after_each() -> void:
	"""Free the fixture's owners, then the host case's."""
	_routes = null
	_profiles = null
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null
	super.after_each()


func _fixture() -> bool:
	"""The content-6 step rows, and a Routes whose row 0 the cases write directly."""
	_h = StationTests.StepFixture.new()
	_h._actual_fixture()
	if not _h.failures.is_empty(): return false
	_routes = Routes.new(_h._residents, _h._transforms)
	_routes._allocate()
	_routes._edge_capacity = 1
	_profiles = _h._profiles
	_routes._profiles = _profiles
	return true


func _mounted_fixture() -> bool:
	"""The mounted content-12 rows (claw, stair, handling) of an actual Session, with its stair tables."""
	var session: Session = _generate_and_mount()
	if not failures.is_empty(): return false
	var o: Session.Retirement.Owners = session._retirement_owners
	_routes = Routes.new(o.residents, o.transforms)
	_routes._allocate()
	_routes._edge_capacity = 1
	_profiles = session._profiles if session._profiles != null else o.profiles
	_routes._profiles = _profiles
	if o.routes != null: _routes._stair_motion = o.routes._stair_motion
	return _profiles != null and _profiles.content_revision() > 0


static func _oracle_profile(profiles: Profiles, profile: int, profile_revision: int, content: int) -> StringName:
	"""Pre-1951 `_source_profile_refusal`."""
	if Routes.Handling.is_handling(profile, content):
		return Routes.Handling.profile_refusal(profiles, profile, profile_revision, content)
	if Routes.Stair.owns(profiles, profile): return Routes.Stair.profile_refusal(profiles, profile, profile_revision, content)
	if Routes.Claw2.owns(profiles, profile): return Routes.Claw2.profile_refusal(profiles, profile, profile_revision, content)
	if Routes.Claw.owns(profiles, profile): return Routes.Claw.profile_refusal(profiles, profile, profile_revision, content)
	return ShortStep.profile_refusal(profiles, profile, profile_revision, content) if ShortStep.uses(profiles) \
		else SourceProgram.profile_refusal(profiles, profile, profile_revision, content)


func _oracle_clock(row: int) -> StringName:
	"""Pre-1951 `_source_clock_leaf` past its automatic-policy checks (which are unchanged)."""
	var profiles: Profiles = _routes._profiles
	var profile: int = _routes._motion.resident[Routes.R_PROFILE * Routes.RESIDENT_CAPACITY + row]
	var revision: int = _routes._motion.resident_long[Routes.R_PROFILE_REVISION * Routes.RESIDENT_CAPACITY + row]
	var content: int = _routes._motion.resident_long[Routes.R_CONTENT_REVISION * Routes.RESIDENT_CAPACITY + row]
	var phase: int = _routes._motion.resident[Routes.R_PHASE * Routes.RESIDENT_CAPACITY + row]
	var clock: int = _routes._motion.resident_long[Routes.R_REQUEST_TICK * Routes.RESIDENT_CAPACITY + row]
	var code: StringName = _oracle_profile(profiles, profile, revision, content)
	if code != &"": return code
	if Routes.Handling.is_handling(profile, content): return Routes.Handling.clock_refusal(phase, clock, profile, content)
	if Routes.Stair.owns(profiles, profile): return Routes._stair_clock_leaf(_routes, row, phase, profile)
	if Routes.Claw2.owns(profiles, profile): return Routes.Claw2.clock_refusal(phase, clock, profile)
	if Routes.Claw.owns(profiles, profile): return Routes.Claw.clock_refusal(phase, clock, profile)
	if not ShortStep.uses(profiles): return SourceProgram.clock_refusal(phase, clock, profile)
	code = ShortStep.clock_refusal(phase, clock, profile)
	if code == &"" and ShortStep.is_short(profile):
		code = ShortStep.progress_refusal(phase, clock,
			_routes._motion.resident_long[Routes.R_PROGRESS * Routes.RESIDENT_CAPACITY + row],
			_routes._motion.resident_long[Routes.R_REMAINDER * Routes.RESIDENT_CAPACITY + row],
			_routes._motion.resident[Routes.R_EDGE_SLOT * Routes.RESIDENT_CAPACITY + row] >= 0)
	return code


func _assert_profiles_match(label: String) -> void:
	"""Every row (and two past the end), revisions 0-2 and contents around the live one."""
	var live: int = _profiles.content_revision()
	for profile: int in range(-1, _profiles._live.header[1] + 2):
		for revision: int in 3:
			for content: int in [0, live, live + 1]:
				assert_equal(Routes._source_profile_refusal(_profiles, profile, revision, content),
					_oracle_profile(_profiles, profile, revision, content), "%s: %d/%d/%d" % [label, profile, revision, content])


func test_the_profile_check_equals_the_pre_1951_code_with_the_closure_whole_or_broken() -> void:
	"""Rows the step program owns pass as before; with the closure broken the parent program decides, as before."""
	if not _fixture(): return
	assert_true(ShortStep.uses(_profiles), "content 6 extends the step program")
	_assert_profiles_match("whole")
	_profiles._live.sources[32] ^= 1 # Negative-only: the appended handling source digest no longer matches.
	_profiles.invalidate_runtime_caches() # Decision 1952: an in-place bank edit must move the load token.
	assert_false(ShortStep.uses(_profiles), "the closure is broken")
	_assert_profiles_match("broken")
	_profiles._live.sources[32] ^= 1
	_profiles.invalidate_runtime_caches()


func _words() -> PackedInt64Array:
	"""Every route phase with every source phase of both programs, and the bare route phases."""
	var out: PackedInt64Array = PackedInt64Array()
	for route: int in 4:
		out.append(route)
		for source: int in 10:
			out.append(ShortStep.word(route, source))
			out.append(SourceProgram.word(route, source))
	return out


func _set_row(profile: int, revision: int, content: int, phase: int, clock: int) -> void:
	"""Write row 0's source columns."""
	_routes._motion.resident[Routes.R_PROFILE * Routes.RESIDENT_CAPACITY] = profile
	_routes._motion.resident_long[Routes.R_PROFILE_REVISION * Routes.RESIDENT_CAPACITY] = revision
	_routes._motion.resident_long[Routes.R_CONTENT_REVISION * Routes.RESIDENT_CAPACITY] = content
	_routes._motion.resident[Routes.R_PHASE * Routes.RESIDENT_CAPACITY] = phase
	_routes._motion.resident_long[Routes.R_REQUEST_TICK * Routes.RESIDENT_CAPACITY] = clock


func _assert_clocks_match(label: String) -> int:
	"""Rows past their automatic-policy checks give the old answer for every word and clock; returns how many passed."""
	var live: int = _profiles.content_revision()
	var passed: int = 0
	var clocks: PackedInt64Array = PackedInt64Array([0, -1, SourceProgram.clock(0, 0), SourceProgram.clock(65536, 0),
		SourceProgram.clock(3 * 65536, 65536)])
	for profile: int in range(0, _profiles._live.header[1] + 1):
		var policy: int = Profiles.selection_policy_leaf(_profiles, profile, 1, live)
		for phase: int in _words():
			if (phase >= Routes.PHASE_IDLE and phase <= Routes.PHASE_HELD) or policy == Profiles.POLICY_AUTOMATIC: continue
			for clock: int in clocks:
				_set_row(profile, 1, live, phase, clock)
				var expected: StringName = _oracle_clock(0)
				passed += 1 if expected == &"" else 0
				assert_equal(Routes._source_clock_leaf(_routes, 0), expected, "%s: row %d word %d clock %d" % [
					label, profile, phase, clock])
	return passed


func test_the_clock_check_equals_the_pre_1951_code_with_the_closure_whole_or_broken() -> void:
	"""Owned rows, step rows and parent-program rows all answer as before, whole or broken."""
	if not _fixture(): return
	assert_true(_assert_clocks_match("whole") > 0, "some step-program clocks pass, so the pass path is compared")
	_profiles._live.sources[32] ^= 1 # Negative-only, restored below.
	_profiles.invalidate_runtime_caches()
	assert_true(_assert_clocks_match("broken") >= 0, "the broken closure compared")
	_profiles._live.sources[32] ^= 1
	_profiles.invalidate_runtime_caches()


func test_mounted_claw_stair_and_handling_rows_answer_as_before() -> void:
	"""The mounted content's owned rows (content 12 since decision 1972) go through their own programs, as before."""
	if not _mounted_fixture():
		assert_true(false, "mounted content")
		return
	var owned: int = 0
	for profile: int in _profiles._live.header[1]:
		if Routes.Handling.is_handling(profile, _profiles.content_revision()) or Stair.owns(_profiles, profile) \
				or Routes.Claw2.owns(_profiles, profile) or Routes.Claw.owns(_profiles, profile):
			owned += 1
	assert_true(owned > 0, "the mounted content has owned rows: %d" % owned)
	_assert_profiles_match("mounted")
	assert_true(_assert_clocks_match("mounted") > 0, "some owned-program clocks pass")


func test_the_step_closure_is_remembered_per_bank_and_load_revision() -> void:
	"""Decision 1952: Routes reads ShortStep.uses() once per Profiles bank and load revision; a bank swap, an in-place
	edit announced by invalidate_runtime_caches() and a poisoned revision each read it afresh."""
	if not _fixture(): return
	assert_true(_profiles.load_revision() > 0, "a loaded store has a live token")
	assert_equal(Routes._step_closure(_profiles), ShortStep.uses(_profiles), "first read")
	var revision: int = _profiles.load_revision()
	assert_equal(_profiles._step_closure_revision, revision, "remembered at this revision")
	_profiles._live.sources[32] ^= 1 # Negative-only, restored below.
	Profiles.CacheChecks.enabled = false
	assert_true(Routes._step_closure(_profiles), "the contract: an edit that does not announce itself is not seen")
	Profiles.CacheChecks.enabled = true
	expect_diagnostic("RUNTIME_CACHE_STALE step closure")
	assert_false(Routes._step_closure(_profiles), "with checking on (every suite) it is answered live and reported")
	assert_false(Routes._step_closure(_profiles), "the reported memo now holds the live answer")
	_profiles.invalidate_runtime_caches()
	assert_true(_profiles.load_revision() > revision, "the token moved")
	assert_false(Routes._step_closure(_profiles), "an announced edit is read afresh")
	_profiles._live.sources[32] ^= 1
	_profiles.invalidate_runtime_caches()
	assert_true(Routes._step_closure(_profiles), "and its repair")


func test_another_bank_or_a_poisoned_token_reads_the_step_closure_afresh() -> void:
	"""Decision 1952: a substituted bank and a saturated (zero) load revision are never answered from the memo."""
	if not _fixture(): return
	assert_true(Routes._step_closure(_profiles), "the whole closure, remembered")
	var bank: Profiles.Bank = _profiles._live
	_profiles._live = Profiles.Bank.new() # Negative-only bank substitution, restored below.
	assert_false(Routes._step_closure(_profiles), "another bank is read afresh")
	_profiles._live = bank
	assert_true(Routes._step_closure(_profiles), "and the original again")
	_profiles._load_revision = Routes.I64_MAX
	assert_equal(_profiles.load_revision(), 0, "saturated is zero")
	_profiles._live.sources[32] ^= 1
	assert_false(Routes._step_closure(_profiles), "a poisoned token always reads afresh")
	_profiles._live.sources[32] ^= 1


func test_configure_and_every_load_move_the_profiles_token() -> void:
	"""configure() and a successful load_file() swap each move load_revision()."""
	var profiles: Profiles = Profiles.new()
	var before: int = profiles.load_revision()
	assert_equal(profiles.configure(StationTests.CONTENT_6_PROFILES, StationTests.CONTENT_6_BOXES,
		StationTests.CONTENT_6_SOURCES, StationTests.CONTENT_6_BANK_BYTES + Profiles.CONTROL_RESERVE), &"", "configured")
	assert_true(profiles.load_revision() > before, "configure moves it")
	if not _fixture(): return
	before = _h._profiles.load_revision()
	var fresh: Profiles = Profiles.new()
	assert_equal(fresh.configure(StationTests.CONTENT_6_PROFILES, StationTests.CONTENT_6_BOXES, StationTests.CONTENT_6_SOURCES,
		StationTests.CONTENT_6_BANK_BYTES + Profiles.CONTROL_RESERVE), &"", "a second store")
	assert_equal(fresh.bind_actual(_h._residents, _h._transforms, _h._inventory, _h._gear, _h._carry, _h._work, _h._pool,
		_h._piles), &"", "bound")
	var configured: int = fresh.load_revision()
	assert_equal(fresh.load_file(StationTests.CONTENT_6_WIRE, StationTests.StonePins.WIRE_SHA, StationTests.CONTENT), &"",
		"loaded")
	assert_true(fresh.load_revision() > configured, "a load moves it")
	configured = fresh.load_revision()
	assert_false(fresh.load_file(StationTests.CONTENT_6_WIRE, StationTests.StonePins.WIRE_SHA, StationTests.CONTENT) == &"",
		"a refused reload")
	assert_equal(fresh.load_revision(), configured, "a refused load leaves the bank and the token")
	assert_true(before > 0, "the fixture's store is live")
	assert_equal(_h._profiles.load_revision(), before, "another store's loads leave this store's token alone")

