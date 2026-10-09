extends "res://test/framework/test_case.gd"
## ADR 1217 step 4e: the claw endpoint certificate's source facts against the actual content-9 rows. Only the
## source-bound leaves are exercised; the runtime installation context waits for the switch (step 5).

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Cert := preload("res://data/underground/mole-worker/qualified-claw-certificate-v1/endpoint_certificate.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-approach-v10/catalog_source.gd")
const Split := preload("res://data/underground/mole-worker/qualified-claw-split-v9/catalog_source.gd")
const Source := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const WIRE: String = "res://data/underground/mole-worker/qualified-claw-approach-v10/mole-worker.ugprof"
const SPLIT_WIRE: String = "res://data/underground/mole-worker/qualified-claw-split-v9/mole-worker.ugprof"
var _profiles: Profiles = null


func before_each() -> void:
	"""Content 9 through the actual loader."""
	_profiles = _loaded(WIRE, Pins.WIRE_SHA, 9, Vector3i(60, 517, 6))


func after_each() -> void:
	"""Drop the store."""
	_profiles = null


func _loaded(path: String, digest: String, revision: int, counts: Vector3i) -> Profiles:
	"""One store with the publication loaded and validated."""
	var store: Profiles = Profiles.new()
	var packed: int = 2 * (counts.x * Profiles.PROFILE_WIRE_BYTES + counts.y * 28 + counts.z * 32 + 32)
	assert_equal(store.configure(counts.x, counts.y, counts.z, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	assert_equal(store.load_file(path, digest, revision), &"", "actual loader")
	return store


func _row_union(rows: Array, roles: Array, above_floor: bool) -> Array:
	"""Union of every box of the given roles over the given rows."""
	var result: Array = [2147483647, 2147483647, 2147483647, -2147483648, -2147483648, -2147483648]
	for row: int in rows:
		var first: int = _profiles._live.fields[Profiles.F_FIRST_BOX * _profiles._profile_capacity + row]
		var count: int = _profiles._live.fields[Profiles.F_BOX_COUNT * _profiles._profile_capacity + row]
		for box: int in range(first, first + count):
			var role: int = _profiles._live.boxes[6 * _profiles._box_capacity + box]
			if role not in roles or (above_floor and _profiles._live.boxes[_profiles._box_capacity + box] < 0):
				continue
			for axis: int in 6:
				var value: int = _profiles._live.boxes[axis * _profiles._box_capacity + box]
				result[axis] = mini(result[axis], value) if axis < 3 else maxi(result[axis], value)
	return result


func test_every_certified_row_and_both_images_match_content_nine() -> void:
	"""Rows 43/47/52/59 word for word and the split image digests: the leaf accepts content 9 only."""
	assert_equal(Cert._profiles_refusal(_profiles, 9), &"", "content 9")
	assert_equal(Cert._profiles_refusal(_profiles, 8), Cert.REFUSE, "another revision")
	var split: Profiles = _loaded(SPLIT_WIRE, Split.WIRE_SHA, 8, Vector3i(52, 477, 6))
	assert_equal(Cert._profiles_refusal(split, 8), Cert.REFUSE, "content 8's rows do not qualify")


func test_envelope_and_support_words_are_the_row_unions() -> void:
	"""The certified envelope is the union of the four rows' above-floor BODY/TURN boxes; support of their stances."""
	var rows: Array = [Pins.CLAW_APPROACH_ROWS[0], Pins.CLAW_RETREAT_ROWS[0], Pins.CLAW_TAP_ROWS[0], Pins.PAW_HANDLING_ROW]
	var envelope: Array = []
	var support: Array = []
	for axis: int in 6:
		envelope.append(Cert._envelope_word(axis))
		support.append(Cert._support_word(axis))
	assert_equal(envelope, _row_union(rows, [Profiles.BODY_HELD_LOAD, Profiles.TURN_RECOVERY], true), "envelope")
	assert_equal(support, _row_union(rows, [Profiles.STANCE_SUPPORT], false), "support")


func test_span_descriptor_admits_only_the_yaw_zero_narrow_rows() -> void:
	"""The approach and retreat at yaw 0 qualify; canonical ground, other headings and pick rows do not."""
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	for pair: Array in [[Pins.CLAW_APPROACH_ROWS[0], true], [Pins.CLAW_RETREAT_ROWS[0], true],
			[Pins.CLAW_WALK_ROW, false], [Pins.CLAW_APPROACH_ROWS[1], false], [2, false]]:
		assert_equal(_profiles.descriptor_into(pair[0], 9, descriptor), &"", "descriptor")
		assert_equal(Cert._span_descriptor_matches(descriptor, 9), pair[1], "row %d" % pair[0])


func test_span_points_follow_direction_and_span() -> void:
	"""Forward approaches toward the root, backward leaves it, both within 4,096 u behind the station."""
	var root: Vector3i = Vector3i(-832, 0, 512)
	var forward: int = Pins.CLAW_APPROACH_ROWS[0]
	var backward: int = Pins.CLAW_RETREAT_ROWS[0]
	assert_true(Cert._span_points_match(forward, root, root + Vector3i(0, 0, 1024), root), "approach")
	assert_true(Cert._span_points_match(backward, root, root, root + Vector3i(0, 0, 1024)), "retreat")
	assert_false(Cert._span_points_match(forward, root, root, root + Vector3i(0, 0, 1024)), "wrong direction")
	assert_false(Cert._span_points_match(forward, root, root + Vector3i(0, 0, 5000), root), "beyond the span")
	assert_false(Cert._span_points_match(2, root, root + Vector3i(0, 0, 1024), root), "pick row")


func test_bearer_words_are_the_published_prisms() -> void:
	"""The bearer words still agree with the assembly source's prisms for both installations."""
	for assembly: int in 2:
		var bounds: PackedInt32Array = PackedInt32Array()
		for axis: int in 6:
			bounds.append(Cert._bearer_word(assembly, axis))
		assert_equal(Source.bearer_refusal(assembly, Vector3i.ZERO, bounds), &"", "assembly %d" % assembly)
