extends "res://test/framework/test_case.gd"
## Actual published source geometry and actual World/Level identity, never synthetic travel flags.

const Motion := preload("res://scripts/core/underground_motion_catalog.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Catalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const Pins := preload("res://data/underground/mole-worker/profile-publication-v2/catalog_source.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const SOURCE_ROOT: String = "res://data/underground/mole-worker/evidence/contact-qualification/"
const ACTOR_PATHS: Array[String] = ["stair-motion-v15/mole-worker.ugactor", "stair-descent-v7/mole-worker.ugactor",
	"stair-handoffs-v1/candidate-6/result/mole-worker.ugactor"]
const WIRE: String = "res://data/underground/mole-worker/evidence/contact-qualification/motion-catalog-v1/candidate-2/motion.ugmotion"
const LEVEL_PATH: String = "res://data/underground/initial_level_pack.uglvl"
const LEVEL_SHA: String = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"
const TEMP: String = "user://motion-catalog-mutant.bin"
var _profiles: Profiles = null
var _levels: Levels = null
var _ids: Directory = null
var _world: Vector2i = Vector2i(-1, 0)
var _domain: Space.Domain = null
var _motion: Motion = null


func before_each() -> void:
	"""Geometry-only use of exact published bytes; no fabricated current Catalog approval."""
	for path: String in Pins.PATHS:
		assert_not_null(ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REUSE), "actual cached source")
	_ids = Directory.new()
	_world = _ids.create(Directory.KIND_WORLD)
	_domain = Space.Domain.new()
	assert_equal(_domain.configure(_world, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 6144, Space.MAX_CHECKS), &"", "actual finite Domain")
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(18, 194, 1, 47288), &"", "actual small configured capacity")
	assert_equal(_profiles.load_file(Catalog.WIRE_PATH, Pins.WIRE_SHA, 1), &"", "exact immutable published geometry")
	_levels = Levels.new()
	assert_equal(_levels.load_file(LEVEL_PATH, LEVEL_SHA, 1), &"", "actual engineering source")
	assert_equal(_levels.bind_domain(_domain, _ids, _domain.descriptor(), Space.VERSION), &"", "actual full World")
	_motion = Motion.new()


func after_each() -> void:
	"""Release only this fixture's acyclic owners and its isolated corruption file."""
	_motion = null
	_profiles = null
	_levels = null
	_domain = null
	_ids = null
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))


func _load() -> void:
	"""Every positive uses both original actual sources and the concrete joint capacity check."""
	assert_equal(_motion.configure(_profiles, _levels, 262144), &"", "joint source admission")
	assert_equal(_motion.load_file(WIRE, Motion.SOURCE_WIRE_SHA, 1), &"", "complete motion source")


func _array(size: int, value: int = 0) -> PackedInt32Array:
	"""Test-owned caller scratch, no retained production arena or per-resident allocation."""
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(size)
	out.fill(value)
	return out


func _write(bytes: PackedByteArray) -> void:
	"""Only the dedicated isolated user-directory image is mutated."""
	var file: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func test_actual_joint_banks_and_activation_refusal() -> void:
	"""The concrete three-column banks preserve the full70860-byte schema twice."""
	_load()
	assert_equal(_motion.packed_memory_bytes(), 141720, "paired numeric banks")
	assert_equal(_motion.admitted_bytes(), 232436, "Profiles/Levels/banks/decode/caller/controls counted")
	assert_equal(_motion._live.ints.size(), 17421, "all I32 columns")
	assert_equal(_motion._live.longs.size(), 67, "all I64 columns")
	assert_equal(_motion._live.bytes.size(), 640, "all digest columns")
	assert_equal(_motion._stage.ints.size(), 17421, "candidate retained")
	assert_equal(_motion.content_revision(), 1, "source revision")
	assert_equal(_motion.activation_refusal(), &"MOTION_SOURCE_ONLY", "no permission from source metadata")


func test_independent_profile_maxima_refuse_before_bank_allocation() -> void:
	"""Current18-row content in oversized actual configured banks cannot hide their allocation."""
	var maximum: Profiles = Profiles.new()
	assert_equal(maximum.configure(256, 3072, 64, 262144), &"", "legacy independent maxima stay legal alone")
	assert_equal(maximum.load_file(Catalog.WIRE_PATH, Pins.WIRE_SHA, 1), &"", "same smaller content")
	assert_equal(_motion.configure(maximum, _levels, 262144), &"MOTION_JOINT_CAPACITY", "full coexistence refuses")
	assert_equal(_motion._live.ints.size(), 0, "no live bank copy")
	assert_equal(_motion._stage.ints.size(), 0, "no stage bank copy")
	assert_equal(_motion.configure(_profiles, _levels, 232435), &"MOTION_JOINT_CAPACITY", "one byte below required peak")
	_load()
	assert_equal(_motion.configure(maximum, _levels, 262144), &"MOTION_ALREADY_CONFIGURED", "no rebinding")


func test_all_five_exact_terminal_roots_and_frame_offsets() -> void:
	"""Source joins retain the half-turn and each actual clip's absolute presentation frame offset."""
	_load()
	var expected: Array[PackedInt32Array] = [
		PackedInt32Array([0, 0, -1705, 32768, 0, 0, 90, 90, 0]),
		PackedInt32Array([0, -128, -2391, 0, 1, 0, 90, 90, 0]),
		PackedInt32Array([0, 0, -1879, 0, 2, 0, 90, 90, 0]),
		PackedInt32Array([0, -128, -2217, 32768, 2, 1, 361, 361, 0]),
		PackedInt32Array([0, 0, -1536, 32768, 2, 2, 452, 452, 0]),
	]
	var out: PackedInt32Array = _array(9)
	for program: int in 5:
		var last: int = 270 if program == 3 else 90
		assert_equal(_motion.phase_into(program, 1, last * 65536, out), &"", "exact nonloop terminal")
		assert_equal(out, expected[program], "same source frame pair and fixed fixture root")
		assert_equal(_motion.phase_into(program, 1, last * 65536 + 1, out), &"MOTION_PHASE", "no clamped surplus time")
		assert_equal(out, expected[program], "failed phase leaves full output")


func test_stationary_intervals_and_local_ceil_before_halfturn() -> void:
	"""Equal roots retain distinct source frames; orientation must follow signed local ceil."""
	_load()
	var first: PackedInt32Array = _array(9)
	var next: PackedInt32Array = _array(9)
	assert_equal(_motion.phase_into(0, 1, 0, first), &"", "first frame")
	assert_equal(_motion.phase_into(0, 1, 65536, next), &"", "stationary lift still advances phase")
	assert_equal(first.slice(0, 3), next.slice(0, 3), "stationary root")
	assert_true(first[6] != next[6], "actual source pose changes")
	assert_equal(_motion.phase_into(0, 1, 2 * 65536 + 1, first), &"", "negative local substep")
	assert_equal(first[2], -2216, "ceil(-1-epsilon) then negate, not ceil(positive interpolation)")
	assert_equal(first[8], 1, "exact Q16 share preserved")


func test_all_complete_intervals_and_primitive_census() -> void:
	"""Every source interval provides both complete boxes and at least one full-foot record."""
	_load()
	var box: PackedInt32Array = _array(6)
	var support: PackedInt32Array = _array(8)
	var intervals: int = 0
	for program: int in 5:
		var last: int = 270 if program == 3 else 90
		for interval: int in last:
			intervals += 1
			for role: int in 2:
				assert_equal(_motion.interval_box_into(program, 1, interval, role, box), &"", "complete body/tool")
				assert_true(box[0] < box[3] and box[1] < box[4] and box[2] < box[5], "positive full volume")
			var count: int = _motion.interval_support_count(program, 1, interval)
			assert_true(count > 0 and count <= 2, "full-foot obligations")
			for ordinal: int in count:
				assert_equal(_motion.interval_support_into(program, 1, interval, ordinal, support), &"", "actual source support")
				assert_true(support[1] == 0 or support[1] == 7, "exact canonical L0/T0 deck")
				assert_true(support[3] < support[5] and support[4] < support[6], "complete XZ enclosure")
	assert_equal(intervals, 630, "no stationary or intermediate interval omitted")
	_check_primitives()


func _check_primitives() -> void:
	"""Original local/fixed frames all resolve to the same22 full canonical solids."""
	var expected_box: PackedInt32Array = _array(6)
	var actual: PackedInt32Array = _array(6)
	for primitive: int in 22:
		assert_equal(_motion.primitive_into(2, 1, primitive, expected_box), &"", "fixed fixture")
		for program: int in 5:
			assert_equal(_motion.primitive_into(program, 1, primitive, actual), &"", "source primitive")
			assert_equal(actual, expected_box, "exact source transform preserves canonical part")


func test_unbound_future_profiles_rates_and_exact_image_identity() -> void:
	"""A source manifest cannot create actual Profile/variant/rate authority."""
	_load()
	var ints: PackedInt32Array = _array(20)
	var longs: PackedInt64Array = PackedInt64Array()
	longs.resize(7)
	for program: int in 5:
		assert_equal(_motion.program_into(program, 1, ints, longs), &"", "bounded descriptor")
		assert_equal(ints[9], -1, "missing qualifying traversal profile")
		assert_equal(ints[10], -1, "missing actual installed Catalog variant")
		assert_equal(longs[4] + longs[5] + longs[6], 0, "no rate adopted")
	var source: PackedInt64Array = PackedInt64Array()
	source.resize(4)
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	for image: int in 3:
		assert_equal(_motion.source_into(image, 1, source, digest), &"", "actual image identity")
		assert_equal(digest.hex_encode(), Motion.ACTOR_HASHES[image], "no index-only source substitution")
		assert_equal(source[2] + source[3], 0, "no certificate manufactured")


func test_wire_drift_and_matching_forged_digest_do_not_publish() -> void:
	"""Only the pinned exact source may load; a recomputed caller digest does not bless changed boxes."""
	assert_equal(_motion.configure(_profiles, _levels, 262144), &"", "empty admitted source")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(WIRE)
	bytes[1000] ^= 1
	_write(bytes)
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	assert_equal(_motion.load_file(TEMP, hashing.finish().hex_encode(), 1), &"MOTION_LOAD_UNAVAILABLE", "caller hash is not source publication")
	assert_equal(_motion.load_file(TEMP, Motion.SOURCE_WIRE_SHA, 1), &"MOTION_SOURCE_HASH", "exact source changed")
	assert_equal(_motion.content_revision(), 0, "no partial source")
	assert_equal(_motion.load_file(WIRE, Motion.SOURCE_WIRE_SHA, 1), &"", "same-owner valid retry")


func test_oversized_column_truncated_and_reload_refuse() -> void:
	"""Fixed wire counts refuse without allocation; successful content is load-once."""
	assert_equal(_motion.configure(_profiles, _levels, 262144), &"", "joint admission")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(WIRE)
	bytes.encode_u32(40, 2147483647)
	_write(bytes)
	assert_equal(_motion.load_file(TEMP, Motion.SOURCE_WIRE_SHA, 1), &"MOTION_WIRE_COLUMN", "hostile row count")
	_write(bytes.slice(0, bytes.size() - 1))
	assert_equal(_motion.load_file(TEMP, Motion.SOURCE_WIRE_SHA, 1), &"MOTION_WIRE_SIZE", "exact finite stream size")
	assert_equal(_motion._stage.ints.size(), 17421, "no hostile resize")
	assert_equal(_motion.content_revision(), 0, "refusals remain empty")
	assert_equal(_motion.load_file(WIRE, Motion.SOURCE_WIRE_SHA, 1), &"", "retry")
	assert_equal(_motion.load_file(WIRE, Motion.SOURCE_WIRE_SHA, 1), &"MOTION_LOAD_UNAVAILABLE", "no unreviewed replacement")


func test_source_revision_and_busy_refusals_preserve_output() -> void:
	"""A real newer Profiles image and borrowed scratch both invalidate the original source window."""
	_load()
	var out: PackedInt32Array = _array(9, 77)
	_motion._busy = true
	assert_equal(_motion.phase_into(0, 1, 0, out), &"MOTION_QUERY", "scratch in use")
	assert_equal(out, _array(9, 77), "busy output unchanged")
	_motion._busy = false
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(Catalog.WIRE_PATH)
	bytes.encode_s64(12, 2)
	_write(bytes)
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	assert_equal(_profiles.load_file(TEMP, hashing.finish().hex_encode(), 2), &"", "actual source advances")
	assert_equal(_motion.phase_into(0, 1, 0, out), &"MOTION_SOURCE_STALE", "old program cannot repin itself")
	assert_equal(out, _array(9, 77), "stale output unchanged")


func test_retired_and_reused_world_refuses_geometry_reads() -> void:
	"""Equal slot with a new generation/PID cannot borrow the original numerical World binding."""
	_load()
	var out: PackedInt32Array = _array(6, 81)
	assert_true(_ids.destroy(_world), "retire actual World")
	var replacement: Vector2i = _ids.create(Directory.KIND_WORLD)
	assert_equal(replacement.x, _world.x, "deterministic slot reuse")
	assert_true(replacement.y != _world.y, "new full identity")
	assert_equal(_motion.primitive_into(0, 1, 0, out), &"MOTION_WORLD_STALE", "original full World still pinned")
	assert_equal(out, _array(6, 81), "full output preserved")


func test_exact_source_metadata_and_four_join_payloads() -> void:
	"""Explicit identities stay readable while absent runtime qualification remains zero."""
	_load()
	var header: PackedInt64Array = PackedInt64Array()
	header.resize(20)
	assert_equal(_motion.identity_into(1, header), &"", "whole source header")
	assert_equal(header[9] + header[10] + header[18] + header[19], 0, "no presentation/consumer/backend/permission grant")
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	assert_equal(_motion.digest_into(0, 1, digest), &"", "actual published Profile geometry")
	assert_equal(digest.hex_encode(), Pins.WIRE_SHA, "exact wire pin")
	assert_equal(_motion.digest_into(2, 1, digest), &"", "unbound actual connector Catalog")
	assert_equal(digest, PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]), "zero is unbound")
	var join: PackedInt32Array = _array(4)
	var first: PackedInt32Array = _array(9)
	var last: PackedInt32Array = _array(9)
	for ordinal: int in 4:
		assert_equal(_motion.join_into(ordinal, 1, join), &"", "one exact source join")
		assert_equal(_motion.phase_into(join[0], 1, join[2] * 65536, first), &"", "actual source terminal")
		assert_equal(_motion.phase_into(join[1], 1, join[3] * 65536, last), &"", "actual destination entry")
		assert_equal(first.slice(0, 4), last.slice(0, 4), "same fixed root and heading; no hidden reset")


func test_actual_actor_content_uses_same_phase_and_terminal_frames() -> void:
	"""Sequential presentation test owners stay separate from the motion reserve and never activate an Actor."""
	_load()
	for source: int in 3:
		var content: Content = Content.new()
		assert_equal(content.load_file(SOURCE_ROOT + ACTOR_PATHS[source], Motion.ACTOR_HASHES[source], 10000000),
			&"", "actual immutable palette and clip image, separately reserved in this test")
		for program: int in 5:
			if mini(program, 2) == source:
				_check_actual_clip(content, program)


func _check_actual_clip(content: Content, program: int) -> void:
	"""Every interval's first/middle/last share matches the real Content reader, including stationary roots."""
	var metadata: PackedInt32Array = _array(4)
	var phase: PackedInt32Array = _array(9)
	var actual: PackedInt32Array = _array(3)
	assert_equal(_motion.clip_metadata_into(program, 1, metadata), &"", "exact clip metadata")
	var clip: int = 0 if program < 2 else program - 2
	var timing: PackedInt32Array = _array(2)
	assert_true(content.clip_timing_into(clip, timing), "actual nonloop timing")
	assert_equal(timing, PackedInt32Array([metadata[3], metadata[2]]), "same authored duration/loop flag")
	for interval: int in metadata[1] - 1:
		for share: int in [0, 1, 32768, 65535]:
			var elapsed: int = interval * 65536 + share
			assert_equal(_motion.phase_into(program, 1, elapsed, phase), &"", "source sample")
			assert_equal(content.clip_into(clip, elapsed, actual), &"", "actual presentation sample")
			assert_equal(phase.slice(6, 9), actual, "one exact source phase")
	assert_equal(_motion.phase_into(program, 1, metadata[3], phase), &"", "source terminal")
	assert_equal(content.clip_into(clip, metadata[3], actual), &"", "actual terminal")
	assert_equal(phase.slice(6, 9), actual, "last,last,0")


func test_primitive_mapping_preserves_authored_identity_and_output_is_copied() -> void:
	"""Source ordinals remain source-only and never impersonate a live full Region reference."""
	_load()
	var out: PackedInt32Array = _array(6)
	for program: int in 5:
		for ordinal: int in 22:
			assert_equal(_motion.primitive_mapping_into(program, 1, ordinal, out), &"", "complete source mapping")
			assert_equal(out[2], ordinal, "canonical source primitive")
			assert_equal(out[3], int(ordinal >= 14), "natural/timber remains explicit")
			assert_true(out[4] >= 0 and out[4] < 14 and out[5] >= 0 and out[5] <= 1, "source part and assembly")
	assert_equal(_motion.primitive_into(0, 1, 0, out), &"", "read original")
	out.fill(123)
	assert_equal(_motion.primitive_into(0, 1, 0, out), &"", "independent read")
	assert_equal(out, PackedInt32Array([-1024, -64, -2048, 1024, 0, 0]), "caller write cannot alter source bank")


func test_changed_actual_level_and_cached_source_refuse_before_banks() -> void:
	"""A valid but different Level image cannot borrow the original numerical/source contract."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(LEVEL_PATH)
	bytes.encode_s64(12, 2)
	_write(bytes)
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var changed: Levels = Levels.new()
	assert_equal(changed.load_file(TEMP, hashing.finish().hex_encode(), 2), &"", "actual independently valid Level source")
	assert_equal(changed.bind_domain(_domain, _ids, _domain.descriptor(), Space.VERSION), &"", "same full World is insufficient")
	assert_equal(_motion.configure(_profiles, changed, 262144), &"MOTION_LEVEL_SOURCE", "exact original image required")
	assert_equal(_motion._live.ints.size() + _motion._stage.ints.size(), 0, "no large allocation after wrong source")
	var cached: Script = ResourceLoader.load(Pins.PATHS[0], "Script", ResourceLoader.CACHE_MODE_REUSE) as Script
	var original: String = cached.get_source_code()
	cached.source_code = original + "\n# explicit source-drift regression\n"
	var refused: StringName = _motion.configure(_profiles, _levels, 262144)
	cached.source_code = original
	assert_equal(refused, &"MOLE_CATALOG_SOURCE_DRIFT", "actual cached consumer text drift refuses")
	assert_equal(_motion.packed_memory_bytes(), 0, "refusal did not publish admission")
	_load()


func test_query_shape_range_busy_and_stale_windows_preserve_all_outputs() -> void:
	"""Failed immutable reads never expose a partially copied packet or borrow a busy load window."""
	_load()
	var phase: PackedInt32Array = _array(9, 73)
	assert_equal(_motion.phase_into(5, 1, 0, phase), &"MOTION_QUERY", "no sixth program")
	assert_equal(_motion.phase_into(0, 2, 0, phase), &"MOTION_QUERY", "exact content revision")
	assert_equal(_motion.phase_into(0, 1, -1, phase), &"MOTION_PHASE", "no negative source time")
	assert_equal(phase, _array(9, 73), "all refused phase fields preserved")
	var box: PackedInt32Array = _array(6, 41)
	assert_equal(_motion.interval_box_into(0, 1, 90, 0, box), &"MOTION_INTERVAL", "terminal has no next interval")
	assert_equal(_motion.interval_box_into(0, 1, 0, 2, box), &"MOTION_OUTPUT_SIZE", "role exact")
	assert_equal(box, _array(6, 41), "full box unchanged")
	_motion._busy = true
	assert_equal(_motion.load_file(WIRE, Motion.SOURCE_WIRE_SHA, 1), &"MOTION_BUSY", "no reentrant load")
	assert_true(_motion._poisoned, "active operation is poisoned by reentry")
	_motion._busy = false
	assert_equal(_motion.phase_into(0, 1, 0, phase), &"", "synthetic control probe releases original load window")
