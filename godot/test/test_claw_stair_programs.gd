extends "res://test/framework/test_case.gd"
## ADR 1229 increment 3: content 10's claw program successor (rows 42-50, 56-64), its stair program (rows 51-55) and
## the claw stair motion tables, against the actual content-10 rows loaded through the Profiles loader.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd")
const Claw9 := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/claw_program.gd")
const Stair := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/stair_program.gd")
const StairMotion := preload("res://scripts/core/underground_stair_motion.gd")
const MotionPins := preload("res://data/underground/mole-worker/qualified-claw-stair-motion-v1/catalog_source.gd")
const WIRE: String = "res://data/underground/mole-worker/qualified-claw-stairs-v11/mole-worker.ugprof"
const TEMP: String = "user://claw-stair-motion-negative.ugstair"
const ONE: int = 65536
var _profiles: Profiles = null
var _motion: StairMotion = null


func before_each() -> void:
	"""Content 10 and the stair tables through their actual loaders."""
	_profiles = Profiles.new()
	var packed: int = 2 * (67 * Profiles.PROFILE_WIRE_BYTES + 547 * 28 + 6 * 32 + 32)
	assert_equal(_profiles.configure(67, 547, 6, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	assert_equal(_profiles.load_file(WIRE, Pins.WIRE_SHA, 10), &"", "content 10")
	_motion = StairMotion.new()
	assert_equal(_motion.load_file(MotionPins.WIRE_PATH, MotionPins.WIRE_SHA), &"", "stair tables")


func after_each() -> void:
	"""Drop the stores and the negative wire."""
	_profiles = null
	_motion = null
	if FileAccess.file_exists(TEMP): DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))


func test_content_ten_rows_are_split_between_the_claw_and_stair_programs() -> void:
	"""42-50 and 56-64 are the claw program's, 51-55 the stair program's; content 9's program owns none."""
	for row: int in range(42, 65):
		var stair: bool = row >= 51 and row <= 55
		assert_equal(Claw.owns(_profiles, row), not stair, "claw row %d" % row)
		assert_equal(Stair.owns(_profiles, row), stair, "stair row %d" % row)
		var code: StringName = Stair.profile_refusal(_profiles, row, 1, 10) if stair \
			else Claw.profile_refusal(_profiles, row, 1, 10)
		assert_equal(code, &"", "row %d exact" % row)
		assert_false(Claw9.owns(_profiles, row), "the content-9 program sees another claw image")
	for row: int in [2, 30, 41, 65, 66]:
		assert_false(Claw.owns(_profiles, row) or Stair.owns(_profiles, row), "row %d is neither" % row)
	assert_equal([Claw.yaw_of(56), Claw.yaw_of(59), Claw.yaw_of(63), Claw.yaw_of(64)], [0, 16384, 49152, 0], "headings")
	assert_equal([Claw.is_tap(57), Claw.is_tap(58), Claw.is_tap(64), Claw.clip(64, Claw.ENTRY), Claw.clip(57, Claw.WORK)],
		[true, false, true, 8, 6], "tap rows and the tread tap's clips")
	assert_equal(Stair.profile_refusal(_profiles, 53, 1, 9), &"ROUTE_SOURCE_PROFILE", "content 10 only")


func test_stair_tables_end_where_the_approved_motions_end() -> void:
	"""Root displacement, headings, decks and clips of the five programs."""
	var ends: Array = []
	for row: int in range(51, 56):
		var program: int = _motion.program_of(row)
		assert_true(program >= 0, "row %d has a program" % row)
		ends.append([_motion.end_of(program), _motion.start_yaw(program), _motion.end_yaw(program),
			_motion.key_count(program), _motion.deck_count(program), _motion.clip_of(program)])
	assert_equal(ends, [
		[Vector3i(0, 0, 141), 0, 0, 2, 1, 11], [Vector3i(0, 0, -141), 0, 0, 2, 1, 12],
		[Vector3i(0, -128, -512), 0, 0, 91, 2, 13], [Vector3i(0, 128, 512), 32768, 32768, 91, 2, 14],
		[Vector3i(0, 0, 174), 0, 32768, 271, 1, 15]], "the five programs")
	var turn: int = _motion.program_of(55)
	assert_equal([_motion.heading_at(turn, 0), _motion.heading_at(turn, 135), _motion.heading_at(turn, 270)],
		[0, _motion.heading_at(turn, 135), 32768], "the half-turn's table runs 0 -> 32768")
	var deck: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	assert_true(_motion.deck_into(_motion.program_of(53), 1, Vector3i(10, 20, 30), deck), "lower deck")
	assert_equal(deck, PackedInt32Array([-1014, -172, -651, 1034, -108, -139]), "translated to the start root")
	assert_false(_motion.deck_into(turn, 1, Vector3i.ZERO, deck), "the turn stands on one deck")


func test_dec_050_paces_land_on_whole_keys() -> void:
	"""30 ticks a tread (528 u at 528 u/s), 45 a half-turn (174 u at 116 u/s), two movement ticks a step."""
	assert_equal(Stair.ticks_for(528, 528), 30, "a tread")
	assert_equal(Stair.ticks_for(174, 116), 45, "a half-turn")
	assert_equal(Stair.ticks_for(141, 3277), 2, "a short step")
	assert_equal([Stair.key_step(90, 30), Stair.key_step(270, 45), Stair.key_step(Stair.STEP_CLIP_INTERVALS, 2)],
		[3, 6, 2], "keys per tick")
	assert_equal([Stair.key_step(90, 31), Stair.key_step(90, 0), Stair.ticks_for(0, 528)], [-1, -1, -1], "refused")


func test_stair_clock_admits_only_ready_and_whole_crossing_keys() -> void:
	"""READY at key 0; WALK on a whole key short of the clip end; progress agrees with the occupied edge."""
	var ready: int = Stair.word(0, Stair.READY)
	var walk: int = Stair.word(2, Stair.WALK)
	assert_equal(Stair.clock_refusal(ready, 0, 53), &"", "ready")
	assert_equal(Stair.clock_refusal(walk, Stair.clock(33), 53), &"", "crossing")
	for bad: Array in [[ready, ONE], [walk, ONE + 1], [walk, Stair.clock(270)], [walk, 1 << 32],
			[Stair.word(0, Stair.Step.Parent.FADE_READY), 0]]:
		assert_equal(Stair.clock_refusal(bad[0], bad[1], 53), &"ROUTE_SOURCE_CLOCK", "refused %s" % str(bad))
	assert_equal(Stair.clock_refusal(ready, 0, 56), &"ROUTE_SOURCE_CLOCK", "not a stair row")
	assert_equal(Stair.progress_refusal(walk, Stair.clock(33), 11, 0, true), &"", "on an edge")
	assert_equal(Stair.progress_refusal(walk, 0, 0, 0, false), &"", "between two queued crossings")
	assert_equal(Stair.progress_refusal(walk, Stair.clock(33), 0, 0, true), &"ROUTE_SOURCE_STEP_PROGRESS", "no ticks")
	assert_equal(Stair.progress_refusal(ready, 0, 3, 0, false), &"ROUTE_SOURCE_STEP_PROGRESS", "ready with ticks")
	assert_equal([Stair.stationary(Stair.READY, 0, true), Stair.ready_request(Stair.WALK, 3 * ONE)],
		[Vector3i(Stair.WALK, 0, 0), Vector3i(Stair.WALK, 3 * ONE, 0)], "a crossing is never cut short")


func test_a_changed_wire_is_refused() -> void:
	"""Only the pinned bytes load; a refused load keeps nothing."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(MotionPins.WIRE_PATH)
	bytes[100] ^= 1
	var file: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var other: StairMotion = StairMotion.new()
	assert_equal(other.load_file(TEMP, MotionPins.WIRE_SHA), &"STAIR_MOTION_SOURCE", "hash")
	assert_equal([other.is_loaded(), other.packed_memory_bytes(), other.program_of(53)], [false, 0, -1], "empty")
	assert_equal(_motion.load_file(MotionPins.WIRE_PATH, MotionPins.WIRE_SHA), &"STAIR_MOTION_SOURCE", "loads once")
	assert_equal(_motion.packed_memory_bytes(), 4 * (60 + 5 * 457 + 6 * 7) + 32, "every retained column")
