extends "res://test/framework/test_case.gd"
## Decision 1972 (P-1972-1 (a)): content 10's programs and certificates serve content 12 (`qualified-stair-carry-v13`)
## through one predicate; the claw program owns the wall rows 67-70 and the stair program the rooted rows 71-84; the
## stair motion owner appends the stair-carry tables; the stair path classifies and plans the carry from H to the sill
## (Brendan, 2026-10-17: "Switch on without floor end"; the floor end waits for F40).
## Fixture stores only, through the actual Profiles loader: nothing here is the mounted catalog.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Carry := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const Wall := preload("res://data/underground/mole-worker/qualified-claw-wall-v12/catalog_source.gd")
const Stairs := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd")
const Stair := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/stair_program.gd")
const Paw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/paw_program.gd")
const Handling := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/handling_programs.gd")
const Endpoints := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/endpoint_certificates.gd")
const Endpoint10 := preload("res://data/underground/mole-worker/qualified-claw-certificate-v2/endpoint_certificate.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const ClawPresenter := preload("res://data/underground/mole-worker/mole_claw_program.gd")
const StairMotion := preload("res://scripts/core/underground_stair_motion.gd")
const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const MotionPins := preload("res://data/underground/mole-worker/qualified-claw-stair-motion-v1/catalog_source.gd")
const CarryMotion := preload("res://data/underground/mole-worker/qualified-stair-carry-motion-v1/catalog_source.gd")
const CARRY_WIRE: String = "res://data/underground/mole-worker/qualified-stair-carry-v13/mole-worker.ugprof"
const WALL_WIRE: String = "res://data/underground/mole-worker/qualified-claw-wall-v12/mole-worker.ugprof"
const STAIRS_WIRE: String = "res://data/underground/mole-worker/qualified-claw-stairs-v11/mole-worker.ugprof"
var _carry: Profiles = null
var _wall: Profiles = null
var _ten: Profiles = null


func before_each() -> void:
	"""Contents 12, 11 and 10 through the actual loader."""
	_carry = _loaded(CARRY_WIRE, Carry.WIRE_SHA, 12, Vector3i(85, 637, 8))
	_wall = _loaded(WALL_WIRE, Wall.WIRE_SHA, 11, Vector3i(71, 595, 6))
	_ten = _loaded(STAIRS_WIRE, Stairs.WIRE_SHA, 10, Vector3i(67, 547, 6))


func after_each() -> void:
	"""Drop the stores."""
	_carry = null
	_wall = null
	_ten = null


func _loaded(path: String, digest: String, revision: int, counts: Vector3i) -> Profiles:
	"""One configured store with the publication loaded and validated."""
	var store: Profiles = Profiles.new()
	var packed: int = 2 * (counts.x * Profiles.PROFILE_WIRE_BYTES + counts.y * 28 + counts.z * 32 + 32)
	assert_equal(store.configure(counts.x, counts.y, counts.z, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	assert_equal(store.load_file(path, digest, revision), &"", "actual loader")
	return store


func _field(store: Profiles, field: int, row: int) -> int:
	"""One stored descriptor word."""
	return store._live.fields[field * store._profile_capacity + row]


func test_one_predicate_serves_contents_ten_and_twelve() -> void:
	"""Content 12 carries content 10's rows 0-66 and sources 0-5; content 11 is never loaded at runtime."""
	assert_equal([Claw.serves(10), Claw.serves(12)], [true, true], "10 and its successor 12")
	assert_equal([Claw.serves(9), Claw.serves(11), Claw.serves(13), Claw.serves(0)], [false, false, false, false],
		"no other content")


func test_the_claw_program_owns_the_wall_rows_on_content_twelve() -> void:
	"""Rows 67-70: owned, refusal-free, yaws 0..49152, M1's dig clips, never a tap; content 10 has no such rows."""
	for index: int in 4:
		var row: int = Carry.CLAW_WALL_ROWS[index]
		assert_true(Claw.owns(_carry, row) and Claw.in_block(row) and Claw.is_wall(row), "row %d owned" % row)
		assert_equal(Claw.profile_refusal(_carry, row, 1, 12), &"", "row %d qualifies" % row)
		assert_equal(Claw.yaw_of(row), index * 16384, "row %d heading" % row)
		assert_equal(Claw.yaw_of(row), _field(_carry, Profiles.F_YAW, row), "published heading")
		assert_false(Claw.is_tap(row) or Claw.is_travel(row), "a dig row")
		assert_equal([Claw.clip(row, Claw.ENTRY), Claw.clip(row, Claw.WORK), Claw.clip(row, Claw.RECOVERY)],
			[Claw.CLIP_DIG_ENTRY, Claw.CLIP_DIG_ENTRY + 1, Claw.CLIP_DIG_ENTRY + 2], "M1's clips")
	assert_false(Claw.owns(_ten, 67), "content 10 ends at row 66")
	assert_false(Claw.in_block(Carry.PAW_HANDLING_ROW) or Claw.in_block(Carry.PAW_TREAD_HANDLING_ROW), "paw rows")
	assert_false(Claw.in_block(Carry.CLAW_DESCENT_ROW) or Claw.in_block(71), "stair and rooted rows")
	for row: int in [42, 47, 56, 57, 64]:
		assert_equal(Claw.profile_refusal(_carry, row, 1, 12), &"", "content 10's claw row %d on 12" % row)


func test_the_claw_presenter_dispatches_content_twelve_and_the_wall_rows() -> void:
	"""The presented frame of a wall row on content 12 is the v2 program's, as content 10's rows are."""
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
	var state: PackedInt64Array = PackedInt64Array([Claw.WORK, 0, 0])
	assert_equal(ClawPresenter.frames_into(null, 67, state, pose, out, 12), &"MOLE_CLAW_PROGRAM_INPUT",
		"input checks still hold (no content image)")
	assert_true(Claw.serves(12) and Claw.in_block(67), "the presenter's two conditions for row 67")


func test_the_stair_program_owns_the_rooted_rows_on_content_twelve() -> void:
	"""Rows 71-84: owned by their image digests, the published words, and refusal-free; their content must be 12."""
	for row: int in range(71, 85):
		assert_true(Stair.owns(_carry, row) and Stair.is_rooted(row) and Stair.is_carry_row(row), "row %d" % row)
		assert_equal(Stair.profile_refusal(_carry, row, 1, 12), &"", "row %d qualifies" % row)
		assert_equal(Stair.policy_of(row), _carry._live.flags[_carry._profile_capacity + row], "row %d policy" % row)
		assert_equal(Stair.yaw_of(row), _field(_carry, Profiles.F_YAW, row), "row %d heading" % row)
		assert_equal(Stair.mode_of(row), _field(_carry, Profiles.F_MODE, row), "row %d mode" % row)
		assert_equal(Stair.source_of(row), _field(_carry, Profiles.F_SOURCE, row), "row %d source" % row)
		assert_equal(Stair.family_mask_of(row), 1, "row %d serves EARTH_TIMBER" % row)
	assert_equal(Stair.profile_refusal(_carry, 71, 1, 10), &"ROUTE_SOURCE_PROFILE", "a rooted row is content 12's")
	for row: int in range(51, 56):
		assert_equal(Stair.profile_refusal(_carry, row, 1, 12), &"", "content 10's stair row %d on 12" % row)
	assert_false(Stair.owns(_carry, 85) or Stair.owns(_carry, 70) or Stair.owns(_ten, 71), "outside the blocks")


func test_a_rooted_row_refuses_any_edited_word() -> void:
	"""A cargo, mode, heading or image change of one rooted row refuses it, through the actual live columns."""
	var cases: Array[Vector3i] = [Vector3i(Profiles.F_CARGO, 74, -1), Vector3i(Profiles.F_CARGO, 71, 7),
		Vector3i(Profiles.F_MODE, 74, Profiles.MODE_WALK), Vector3i(Profiles.F_YAW, 77, 0),
		Vector3i(Profiles.F_TOOL, 80, 3), Vector3i(Profiles.F_FAMILIES, 83, 3)]
	for edit: Vector3i in cases:
		var at: int = edit.x * _carry._profile_capacity + edit.y
		var kept: int = _carry._live.fields[at]
		_carry._live.fields[at] = edit.z
		assert_equal(Stair.profile_refusal(_carry, edit.y, 1, 12), &"ROUTE_SOURCE_PROFILE", "edit %s" % edit)
		_carry._live.fields[at] = kept
	var stone: int = 32 * Stair.STONE_SOURCE
	_carry._live.sources[stone] = (_carry._live.sources[stone] + 1) % 256
	assert_false(Stair.owns(_carry, 80) or Stair.owns(_carry, 74), "a changed stone image owns no rooted row")
	_carry._live.sources[stone] = (_carry._live.sources[stone] + 255) % 256
	assert_true(Stair.owns(_carry, 80), "restored")


func test_the_rooted_clock_and_tick_rule() -> void:
	"""Rooted rows keep the stair program's two phases; a 271-key half-turn stays inside MAX_KEY."""
	assert_equal(Stair.clock_refusal(Stair.word(0, Stair.READY), 0, 76), &"", "READY")
	assert_equal(Stair.clock_refusal(Stair.word(2, Stair.WALK), 269 * Stair.ONE, 76), &"", "the last whole key")
	assert_equal(Stair.clock_refusal(Stair.word(2, Stair.WALK), Stair.ONE, 85), &"ROUTE_SOURCE_CLOCK", "no row 85")
	assert_equal(Stair.clock_refusal(Stair.word(2, Stair.WALK), Stair.ONE, 70), &"ROUTE_SOURCE_CLOCK", "no wall row")
	assert_equal(Stair.ticks_for(169, 56334), 90, "the 169 u retreat")


func test_paw_handling_serves_content_twelve_at_its_own_census() -> void:
	"""The paw rows on content 12 at 85/637/8; content 11's census is neither 10's nor 12's."""
	assert_true(Paw.uses(_carry) and Paw.uses(_ten), "contents 12 and 10")
	assert_false(Paw.uses(_wall), "content 11 never loads")
	assert_equal(Paw.profile_refusal(_carry, Carry.PAW_HANDLING_ROW, 1, 10), &"ASSEMBLY_SOURCE_PROFILE", "stale content")
	assert_true(Handling.is_handling(65, 12) and Handling.is_handling(66, 12), "65 and 66 on content 12")
	assert_false(Handling.is_handling(59, 12), "content 9's paw row is not content 12's")
	assert_equal([Handling.source_of(65, 12), Handling.role_count(65, 12)], [Paw.SOURCE, Paw.ROLE_COUNT], "paw v2")
	assert_equal(Handling.profile_refusal(_carry, 65, 1, 12), &"", "the selector's refusal on 12")


func test_the_certificates_serve_content_twelve() -> void:
	"""The endpoint and grip certificates take content 12 as content 10; content 11 stays unadmitted."""
	assert_true(Endpoints.is_claw(12) and Endpoints.is_claw(10) and Endpoints.is_claw(9), "claw certificates")
	assert_false(Endpoints.is_claw(11), "content 11")
	assert_true(Endpoints.excuses_pending(Carry.CLAW_APPROACH_ROWS[0], 12), "the narrow approach on 12")
	assert_equal(Endpoint10._digests_refusal(_carry, 12), &"", "the v2 images on content 12")
	assert_equal(Endpoint10._digests_refusal(_carry, 10), Endpoint10.REFUSE, "a stale revision")
	assert_true(Grip.uses(_carry) and Grip.uses(_ten), "grip hauling on 12 and 10")
	assert_false(Grip.uses(_wall), "content 11")


func test_the_stair_motion_owner_appends_the_carry_tables() -> void:
	"""The carry bank follows the claw bank: rows 71-84, rooted, their retained bytes; refusals leave the claw bank."""
	var motion: StairMotion = StairMotion.new()
	assert_equal(motion.load_carry_file(CarryMotion.WIRE_PATH, CarryMotion.WIRE_SHA), StairMotion.REFUSE_SOURCE,
		"never before the claw bank")
	assert_equal(motion.load_file(MotionPins.WIRE_PATH, MotionPins.WIRE_SHA), &"", "claw tables")
	assert_equal([motion.program_of(71), motion.packed_memory_bytes()], [-1, StairMotion.RESERVED_BYTES], "claw only")
	assert_equal(motion.load_carry_file(CarryMotion.WIRE_PATH, MotionPins.WIRE_SHA), StairMotion.REFUSE_SOURCE,
		"a wrong pin")
	assert_equal(motion.load_carry_file(CarryMotion.WIRE_PATH, CarryMotion.WIRE_SHA), &"", "carry tables")
	assert_true(motion.is_carry_loaded(), "appended")
	assert_equal(motion.load_carry_file(CarryMotion.WIRE_PATH, CarryMotion.WIRE_SHA), StairMotion.REFUSE_SOURCE, "once")
	assert_equal(motion.packed_memory_bytes(), StairMotion.RESERVED_BYTES + StairMotion.CARRY_RESERVED_BYTES, "bytes")
	for row: int in range(71, 85):
		var program: int = motion.program_of(row)
		assert_equal(program, StairMotion.PROGRAMS + row - 71, "row %d's program" % row)
		assert_true(motion.rooted(program), "row %d rooted" % row)
	assert_equal(motion.end_of(motion.program_of(77)), Vector3i(0, 0, 169), "the retreat's 169 u")
	assert_equal([motion.key_count(motion.program_of(76)), motion.end_yaw(motion.program_of(76))], [271, 32768], "turn")
	assert_equal(motion.program_of(53), 2, "the claw descent is still program 2")


func test_the_stair_path_classifies_h_the_sill_and_the_first_landing() -> void:
	"""H is 343 u before A on L0; the sill (T6) is module 0's last level. Decision 2044 (M2): the floor below the sill
	is landing 1, whose F, U (UF) and F' are stops (F40's "no floor stop" held only while the flight was one module);
	a point on the sill F' would take is still none."""
	assert_equal(StairPath.classify(Vector3i(0, 0, -1536)), Vector2i(StairPath.KIND_H, -1), "H")
	assert_equal(StairPath.classify(Vector3i(0, -896, -5463)), Vector2i(StairPath.KIND_A, 6), "A on the sill")
	assert_equal(StairPath.classify(Vector3i(0, -896, -5289)), Vector2i(StairPath.KIND_U, 6), "U on the sill")
	assert_equal(StairPath.classify(Vector3i(0, -1024, -5975)), Vector2i(StairPath.KIND_F, 1), "F on landing 1")
	assert_equal(StairPath.classify(Vector3i(0, -1024, -5801)), Vector2i(StairPath.KIND_UF, 1), "the floor ascent start")
	assert_equal(StairPath.classify(Vector3i(0, -1024, -6318)), Vector2i(StairPath.KIND_FP, 1), "F' on landing 1")
	assert_equal(StairPath.classify(Vector3i(0, -896, -5806)), Vector2i(-1, 0), "no F' on the sill")


func test_the_stair_path_plans_the_sill_and_the_carry_after_the_descent() -> void:
	"""Six words an edge; the descent's 33 WALK edges first, then the sill's 2 WALK edges and 17 CARRY edges, which
	wait for the sill's arrival A(T6). Decision 2044 (M2): landing 1's twelve floor edges, module 1's P' -> A(L0'), 30
	tread and 2 sill edges, and landing 2's five floor edges follow. Decision 2045 (M5): landings 1-4 each add five floor
	edges and seven ground joins (R', P-2045-11), then the next module's P' -> A, 30 tread and 2 sill edges; landing 5
	ends it with five floor edges (237 in all)."""
	var plan: PackedInt32Array = StairPath.edge_plan()
	assert_equal(plan.size(), StairPath.PLAN_WORDS * (33 + 2 + 17 + 4 * (5 + 7 + 1 + 30 + 2) + 5), "edge census")
	assert_equal(StairPath.descent_words(), StairPath.PLAN_WORDS * 33, "the descent's words")
	var carry: int = 0
	for at: int in range(0, plan.size(), StairPath.PLAN_WORDS):
		if plan[at + 5] == Profiles.MODE_CARRY:
			carry += 1
			assert_equal(plan[at + 4], 0, "every CARRY edge is EARTH_TIMBER")
			assert_true(plan[at + 1] <= StairPath.SILL_LEVEL and plan[at + 3] <= StairPath.SILL_LEVEL, "never below T6")
	assert_equal(carry, 17, "H -> A, seven descents, the turn on T6, seven ascents and U -> H")
	var stops: StairPath.Stops = StairPath.Stops.new()
	StairPath.record(stops, Vector2i(StairPath.KIND_H, -1), Vector2i(1, 1))
	stops.a[0] = Vector2i(2, 1)
	var first_carry: int = StairPath.descent_words() + StairPath.PLAN_WORDS * 2
	assert_false(StairPath._planned(stops, plan, first_carry), "H -> A(L0) waits for the sill")
	stops.a[StairPath.SILL_LEVEL + 1] = Vector2i(3, 1)
	assert_true(StairPath._planned(stops, plan, first_carry), "planned once A(T6) exists")


func test_a_malformed_carry_bank_is_refused_and_cut_back_to_the_claw_bank() -> void:
	"""The carry tables are validated after they are appended: a program naming another row, or a key whose deck is
	outside its program's span, refuses, and the columns are cut back to the claw bank exactly."""
	var good: PackedByteArray = FileAccess.get_file_as_bytes(CarryMotion.WIRE_PATH)
	var key_deck: int = StairMotion.HEADER_BYTES + 4 * StairMotion.PROGRAM_FIELDS * StairMotion.CARRY_PROGRAMS \
		+ 4 * StairMotion.K_DECK
	for fault: Vector2i in [Vector2i(StairMotion.HEADER_BYTES + 4 * StairMotion.P_ROW, 70), Vector2i(key_deck, 999)]:
		var motion: StairMotion = StairMotion.new()
		assert_equal(motion.load_file(MotionPins.WIRE_PATH, MotionPins.WIRE_SHA), &"", "claw tables")
		var bad: PackedByteArray = good.duplicate()
		bad.encode_s32(fault.x, fault.y)
		assert_equal(motion._append_carry(bad), StairMotion.REFUSE_FORMAT, "fault at %d refused" % fault.x)
		assert_equal([motion.program_of(71), motion.packed_memory_bytes()], [-1, StairMotion.RESERVED_BYTES],
			"cut back to the claw bank")
		assert_equal(motion.program_of(53), 2, "the claw descent untouched")
