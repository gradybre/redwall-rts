extends "res://test/framework/test_case.gd"
## ADR 1217 step 5: the claw work program (source 4), the paw-handling program and clock (row 59, source 5) and the
## content-9 grip certificate, checked against the actual content-9 rows loaded through the Profiles loader and the
## actual claw and paw images loaded through ActorContent.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-approach-v10/catalog_source.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/claw_program.gd")
const Paw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/paw_program.gd")
const PawClock := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/paw_clock.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const PickGrip := preload("res://data/underground/mole-worker/qualified-stone-v7/grip_certificate.gd")
const Step := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")
const WIRE: String = "res://data/underground/mole-worker/qualified-claw-approach-v10/mole-worker.ugprof"
const CLAW_IMAGE: String = "res://data/underground/mole-worker/claw-work-v1/evidence/native-claw-split-v1/claw/compiled/claw.ugactor"
const PAW_IMAGE: String = "res://data/underground/mole-worker/claw-work-v1/evidence/native-claw-split-v1/paw/compiled/paw-handling.ugactor"
const CLAW_RESERVE: int = 6906492
const PAW_RESERVE: int = 6567544
const ONE: int = 65536
var _profiles: Profiles = null


func before_each() -> void:
	"""Content 9 through the actual loader and validator."""
	_profiles = Profiles.new()
	var packed: int = 2 * (60 * Profiles.PROFILE_WIRE_BYTES + 517 * 28 + 6 * 32 + 32)
	assert_equal(_profiles.configure(60, 517, 6, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	assert_equal(_profiles.load_file(WIRE, Pins.WIRE_SHA, 9), &"", "content 9")


func after_each() -> void:
	"""Drop the store."""
	_profiles = null


func _image(path: String, digest: String, reserve: int) -> Content:
	"""One actual image, loaded with its own exact reservation."""
	var content: Content = Content.new()
	assert_equal(content.load_file(path, digest, reserve), &"", "image %s" % path.get_file())
	return content


func _duration(content: Content, clip: int) -> int:
	"""A clip's exact Q16 duration."""
	var timing: PackedInt32Array = PackedInt32Array([0, 0])
	assert_true(content.clip_timing_into(clip, timing), "clip %d timing" % clip)
	return timing[0]


func test_claw_program_owns_exactly_the_source_four_rows() -> void:
	"""Rows 42-58 are the claw program's by their source word; pick, haul and paw rows are not."""
	for row: int in range(42, 59):
		assert_true(Claw.owns(_profiles, row), "row %d is source 4" % row)
		assert_equal(Claw.profile_refusal(_profiles, row, 1, 9), &"", "row %d exact" % row)
	for row: int in [2, 12, 13, 16, 29, 30, 31, 34, 59]:
		assert_false(Claw.owns(_profiles, row), "row %d is not a claw row" % row)
	assert_equal(Claw.profile_refusal(_profiles, 51, 2, 9), &"ROUTE_SOURCE_PROFILE", "revision 2 is not published")
	assert_equal([Claw.yaw_of(42), Claw.yaw_of(45), Claw.yaw_of(48), Claw.yaw_of(53), Claw.yaw_of(58)],
		[0, 32768, 16384, 16384, 49152], "headings by block")
	assert_equal([Claw.is_tap(52), Claw.is_tap(57), Claw.is_backward(47), Claw.is_backward(46)],
		[true, false, true, false], "row kinds")


func test_claw_clock_domain_is_the_claw_image_clips() -> void:
	"""Walk, transitions and work loops equal the actual claw image's clip durations."""
	var image: Content = _image(CLAW_IMAGE, Pins.CLAW_SOURCE_SHA, CLAW_RESERVE)
	assert_equal(_duration(image, Claw.CLIP_WALK), Claw.WALK_DURATION, "walk")
	for clip: int in [2, 4, 5, 7]:
		assert_equal(_duration(image, clip), Claw.TRANSITION_DURATION, "transition clip %d" % clip)
	for clip: int in [3, 6]:
		assert_equal(_duration(image, clip), Claw.WORK_DURATION, "work clip %d" % clip)
	assert_true(Claw.READY_TIME < _duration(image, Claw.CLIP_STAND), "ready key inside the stand")
	assert_equal([Claw.clip(51, Claw.ENTRY), Claw.clip(51, Claw.WORK), Claw.clip(51, Claw.RECOVERY)], [2, 3, 4], "dig")
	assert_equal([Claw.clip(52, Claw.ENTRY), Claw.clip(52, Claw.WORK), Claw.clip(52, Claw.RECOVERY)], [5, 6, 7], "tap")
	assert_equal([Claw.clip(43, Claw.WALK), Claw.clip(43, Claw.READY)], [1, 0], "travel")


func test_claw_clock_refuses_impossible_states() -> void:
	"""The clock domain is exact per row kind; a foreign tag or lane refuses."""
	var ready: int = Claw.word(0, Claw.READY)
	assert_equal(Claw.clock_refusal(ready, 0, 51), &"", "ready")
	assert_equal(Claw.clock_refusal(Claw.word(0, Claw.WORK), Claw.WORK_DURATION - ONE, 51), &"", "last work key")
	assert_equal(Claw.clock_refusal(Claw.word(0, Claw.WORK), Claw.WORK_DURATION, 51), &"ROUTE_SOURCE_CLOCK", "past work")
	assert_equal(Claw.clock_refusal(Claw.word(0, Claw.WALK), Claw.WALK_DURATION - ONE, 42), &"", "last walk key")
	assert_equal(Claw.clock_refusal(Claw.word(0, Claw.WALK), 0, 51), &"ROUTE_SOURCE_CLOCK", "no walk on a dig row")
	assert_equal(Claw.clock_refusal(ready ^ (1 << 20), 0, 51), &"ROUTE_SOURCE_CLOCK", "foreign tag")
	assert_equal(Claw.clock_refusal(Claw.word(0, Claw.FADE_READY), Claw.clock(0, 30 * ONE), 43),
		&"ROUTE_SOURCE_CLOCK", "no fade held on a blocked key")
	assert_equal(Claw.clock_refusal(Claw.word(0, Claw.FADE_READY), Claw.clock(0, 38 * ONE), 43), &"", "clear key")


func test_fade_window_walks_on_to_a_clear_key() -> void:
	"""Brendan's rule: arriving on keys 28-37 the walk plays on in place, and fades from key 38 (or 27 backward)."""
	var state: Vector3i = Claw.arrive(29 * ONE, 43)
	assert_equal(state, Vector3i(Claw.WALK, 30 * ONE, 0), "blocked arrival walks on")
	var ticks: int = 0
	while state.x == Claw.WALK:
		state = Claw.stationary(state.x, state.y, state.z, 43, false)
		ticks += 1
	assert_equal(state, Vector3i(Claw.FADE_READY, ONE, 38 * ONE), "fade starts from key 38")
	assert_equal(ticks, 9, "keys 30..38")
	assert_equal(Claw.arrive(26 * ONE, 43), Vector3i(Claw.FADE_READY, 0, 27 * ONE), "clear arrival fades")
	assert_true(Claw.fade_blocked(47, Claw.WALK_DURATION - 30 * ONE), "retreat shows key 30")
	assert_false(Claw.fade_blocked(47, Claw.WALK_DURATION - 27 * ONE), "retreat shows key 27")
	assert_equal(Claw.ready_request(Claw.WALK, 30 * ONE, 0, 43), Vector3i(Claw.WALK, 30 * ONE, 0), "blocked stop waits")
	assert_equal(Claw.ready_request(Claw.WALK, 12 * ONE, 0, 43), Vector3i(Claw.FADE_READY, 0, 12 * ONE), "clear stop")
	for key: int in 44:
		var blocked: bool = key >= Pins.CLAW_FADE_BLOCKED_FIRST and key <= Pins.CLAW_FADE_BLOCKED_LAST
		assert_equal(Claw.fade_blocked(43, key * ONE), blocked, "forward key %d" % key)


func test_claw_work_cycle_matches_the_pick_protocol_shape() -> void:
	"""ENTRY reaches WORK after 30 ticks, WORK loops, a stop finishes the loop and recovers to READY."""
	var state: Vector3i = Vector3i(Claw.ENTRY, 0, 0)
	for tick: int in 30:
		state = Claw.advance(state.x, state.y, state.z, 51)
	assert_equal(state, Vector3i(Claw.WORK, 0, 0), "entry done")
	state = Claw.advance(state.x, state.y, state.z, 51)
	state = Claw.ready_request(state.x, state.y, state.z, 51)
	assert_equal(state.x, Claw.RECOVERY_WAIT, "loop finishes first")
	var ticks: int = 0
	while state.x != Claw.READY:
		state = Claw.advance(state.x, state.y, state.z, 51)
		ticks += 1
	assert_equal(ticks, 31 + 30, "rest of the loop, then recovery")


func test_paw_program_is_row_fifty_nine_on_source_five() -> void:
	"""Every word, box and both split digests of row 59; the bearer prisms are the pick certificate's."""
	assert_true(Paw.uses(_profiles), "content 9 carries the paw handling row")
	assert_equal(Paw.profile_refusal(_profiles, Paw.PROFILE, 1, 9), &"", "exact row 59")
	assert_equal(Paw.profile_refusal(_profiles, 29, 1, 9), &"ASSEMBLY_SOURCE_PROFILE", "the pick row is not paw")
	var first: int = _profiles._live.fields[Profiles.F_FIRST_BOX * _profiles._profile_capacity + Paw.PROFILE]
	for ordinal: int in Paw.ROLE_COUNT:
		for field: int in 7:
			assert_equal(_profiles._live.boxes[field * _profiles._box_capacity + first + ordinal],
				Paw.box_word(ordinal, field), "box %d word %d" % [ordinal, field])
	for ordinal: int in Paw.ROLE_COUNT:
		var foot: bool = Paw.box_word(ordinal, 1) < 0
		for axis: int in 3:
			assert_true(Paw.box_word(ordinal, axis) >= Paw.volume_word(1 if foot else 0, axis), "inside low %d" % ordinal)
			assert_true(Paw.box_word(ordinal, axis + 3) <= Paw.volume_word(1 if foot else 0, axis + 3),
				"inside high %d" % ordinal)
	assert_equal(Paw.TAG, Paw.Parent.TAG, "the pick handling encoding")
	assert_equal(Paw.part_refusal(0, 1, 3, Vector3i(1024, 192, -768)), &"", "L0 bearer part")


func test_paw_clock_presents_the_paw_image() -> void:
	"""Entry and recovery cover the paw image's 30 intervals; handled READY holds the recovery's last key."""
	var image: Content = _image(PAW_IMAGE, Pins.PAW_SOURCE_SHA, PAW_RESERVE)
	assert_equal(_duration(image, PawClock.CLIP_ENTRY), PawClock.SOURCE_INTERVALS * ONE, "seat entry")
	assert_equal(_duration(image, PawClock.CLIP_RECOVERY), PawClock.SOURCE_INTERVALS * ONE, "seat recovery")
	var out: PackedInt32Array = PackedInt32Array([0, 0])
	assert_equal(PawClock.source_into(PawClock.ENTRY, 15 * ONE, out), &"", "mid entry")
	assert_equal(Array(out), [0, 15 * ONE], "entry key 15")
	assert_equal(PawClock.source_into(PawClock.HANDLED_READY, 0, out), &"", "handled")
	assert_equal(Array(out), [2, 30 * ONE], "recovery end")
	assert_equal(PawClock.advance(PawClock.ENTRY, PawClock.DURATION - ONE), Vector2i(PawClock.RECOVERY, 0), "seated")
	assert_equal(Paw.clock_refusal(Paw.word(0, PawClock.ENTRY), 3 * ONE, Paw.PROFILE), &"", "valid entry")
	assert_equal(Paw.clock_refusal(Paw.word(0, PawClock.ENTRY), 3 * ONE, 29), &"ASSEMBLY_SOURCE_CLOCK", "row 29")


func test_grip_certificate_renews_only_content_and_digests() -> void:
	"""Content 9's grip rows pass the renewed certificate and fail content 6's (its digests are v8/v9)."""
	assert_true(Grip.uses(_profiles), "content 9 grip rows")
	assert_false(PickGrip.uses(_profiles), "content 6 certificate refuses content 9")
	for row: int in range(Grip.FIRST, Grip.LAST + 1):
		assert_equal(Grip.profile_refusal(_profiles, row), &"", "row %d" % row)
	assert_equal([Grip.carry_row_for(60), Grip.carry_row_for(53)], [32, 37], "wood and stone")
	var stock: Vector3i = Vector3i(0, 0, -576)
	assert_equal(Grip.station_refusal(_profiles, 33, Vector3i.ZERO, 0, stock), &"", "wood lift station")
	assert_equal(Grip.station_refusal(_profiles, 33, Vector3i.ZERO, 0, stock + Vector3i(1, 0, 0)),
		&"HAUL_GRIP_STATION", "moved stock")
