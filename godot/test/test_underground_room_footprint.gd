extends "res://test/framework/test_case.gd"
## Decision 1933 (C2.1), ECON-001: a room builder's footprint over the mounted content-12 rows (decision 1972; rows 0-66 are content 10's): the standing body,
## swept legs in short pieces, the cached row extents and the half-open overlap test the foreman's set-off rule uses.

const Footprint := preload("res://scripts/core/underground_room_footprint.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-stairs-v10/catalog_source.gd")
const Catalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const WALK: int = 42 # claw WALK, all yaws: boxes (-712, 0, -712)..(712, 930, 712) and (-402, -1, -402)..(402, 0, 402)
const TAP: int = 63 # the paw seating tap: stance support, body, recovery, approach, stroke, point and patch

var _profiles: Profiles = null
var _foot: Footprint = null


func before_each() -> void:
	"""The mounted content's rows, and a fresh footprint over them."""
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(Catalog.PROFILE_COUNT, Catalog.BOX_COUNT, Catalog.SOURCE_COUNT,
		Catalog.PAIRED_BANK_BYTES + Catalog.CONTROL_RESERVE), &"", "profile bank")
	assert_equal(_profiles.load_file(Bundle.PROFILE_PATH, Bundle.PROFILE_SHA, Bundle.CONTENT_REVISION), &"", "content 12")
	_foot = Footprint.new()
	_foot.configure(_profiles)


func after_each() -> void:
	"""Drop the owners."""
	_foot = null
	_profiles = null


func test_a_fresh_footprint_claims_nothing() -> void:
	"""No claim, a zero body, serial 0."""
	assert_equal(_foot.claim().size(), 0, "no claim")
	assert_equal(_foot.body(), PackedInt32Array([0, 0, 0, 0, 0, 0]), "zero body")
	assert_equal(_foot.serial(), 0, "unchanged")


func test_standing_writes_the_rows_extent_around_the_point_in_place() -> void:
	"""The body is the point plus the row's body/recovery/approach/stroke union."""
	_foot.stand(Vector3i(1000, 50, 2000), WALK)
	assert_equal(_foot.body(), PackedInt32Array([288, 49, 1288, 1712, 980, 2712]), "the walk row's union")
	assert_equal(_foot.serial(), 1, "a change")
	_foot.stand(Vector3i.ZERO, TAP)
	var extent: PackedInt32Array = _foot.body()
	assert_equal(extent, PackedInt32Array([-234, -1, -478, 578, 840, 443]), "row 63: the union of every box")


func test_a_leg_is_swept_in_short_pieces() -> void:
	"""1,024 u along x is four 256 u pieces; a standing sweep is one box; each sweep is a change."""
	_foot.sweep(Vector3i(0, 0, 0), Vector3i(1024, 0, 0), WALK)
	assert_equal(_foot.claim().size(), 4 * 6, "four pieces")
	assert_equal(_foot.claim().slice(0, 6), PackedInt32Array([-712, -1, -712, 968, 930, 712]), "first piece")
	assert_equal(_foot.claim().slice(18, 24), PackedInt32Array([56, -1, -712, 1736, 930, 712]), "last piece")
	_foot.sweep(Vector3i(5, 0, 5), Vector3i(5, 0, 5), WALK)
	assert_equal(_foot.claim().size(), 5 * 6, "a standing sweep is one box")
	assert_equal(_foot.serial(), 2, "two changes")
	_foot.sweep(Vector3i(0, 0, 0), Vector3i(-300, 0, 600), WALK)
	assert_equal(_foot.claim().size(), 8 * 6, "the longer axis sets the pieces: 600 u is three")
	_foot.clear_claim()
	assert_equal(_foot.claim().size(), 0, "cleared")
	assert_equal(_foot.serial(), 4, "clearing is a change")


func test_overlap_is_half_open_and_any_pair_counts() -> void:
	"""Shared volume overlaps; touching faces and empty lists do not; one meeting pair among many is enough."""
	var a: PackedInt32Array = PackedInt32Array([0, 0, 0, 10, 10, 10])
	assert_true(Footprint.overlap(a, PackedInt32Array([9, 9, 9, 20, 20, 20])), "shared corner volume")
	assert_false(Footprint.overlap(a, PackedInt32Array([10, 0, 0, 20, 10, 10])), "touching on x")
	assert_false(Footprint.overlap(a, PackedInt32Array([0, 10, 0, 10, 20, 10])), "touching on y")
	assert_false(Footprint.overlap(a, PackedInt32Array([0, 0, 10, 10, 10, 20])), "touching on z")
	assert_false(Footprint.overlap(a, PackedInt32Array()), "nothing to meet")
	assert_false(Footprint.overlap(PackedInt32Array(), a), "nothing claimed")
	var many: PackedInt32Array = PackedInt32Array([100, 0, 0, 110, 10, 10, -20, 0, 0, -10, 10, 10, 5, 5, 5, 6, 6, 6])
	assert_true(Footprint.overlap(many, a), "the third box meets")
	assert_false(Footprint.overlap(many.slice(0, 12), a), "the hulls meet, no pair does")
	assert_false(Footprint.overlap(PackedInt32Array([0, 0, 50, 10, 10, 60]), a), "hulls apart")
	var touching: PackedInt32Array = PackedInt32Array([10, 0, 0, 20, 10, 10, -20, 0, 0, -10, 10, 10])
	assert_false(Footprint.overlap(touching, a), "hulls meet, and the near box only touches the face")


func test_a_rows_extent_is_read_once_and_cached() -> void:
	"""The extent is cached on first use: a later change in the bank is not re-read (rows are immutable per content
	revision, so the cache never goes stale in play)."""
	_foot.stand(Vector3i.ZERO, WALK)
	var first: PackedInt32Array = _foot.body().duplicate()
	var cap: int = _profiles._box_capacity
	var box: int = _profiles._live.fields[Profiles.F_FIRST_BOX * _profiles._profile_capacity + WALK]
	var saved: int = _profiles._live.boxes[3 * cap + box]
	_profiles._live.boxes[3 * cap + box] = 5000 # Negative-only: widen the first box's high x.
	_foot.stand(Vector3i.ZERO, WALK)
	_profiles._live.boxes[3 * cap + box] = saved
	assert_equal(_foot.body(), first, "the cached extent")
	var fresh: Footprint = Footprint.new()
	fresh.configure(_profiles)
	fresh.stand(Vector3i.ZERO, WALK)
	assert_equal(fresh.body(), first, "a fresh cache reads the same rows")
