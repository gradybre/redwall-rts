extends "res://test/framework/test_case.gd"
## Coverage for ARCH-SYS-001 Transform storage: the derived row, the eight integer fields including
## previous state, and the one presentation boundary where a float is allowed.
##
## The sharpest test here is `test_a_typed_row_inherited_from_another_slot_reads_as_unbound`. It is
## the case a per-slot generation stamp gets WRONG: directory slots and typed rows come from
## separate free heaps, so a new entity can inherit a typed row from a predecessor that lived in a
## different slot carrying the same generation number. Anything weaker than a never-reused
## persistent ID hands back the predecessor's coordinates and looks entirely healthy doing it.

const TransformsScript := preload("res://scripts/core/transforms.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

const METRE: int = 1024

var _directory: EntityDirectoryScript = null
var _transforms: TransformsScript = null
var _result: IntMathScript.IntResult = null
var _pose: TransformsScript.Pose = null


func before_each() -> void:
	"""Build a fresh directory and Transform store with every column allocated to capacity."""
	_directory = EntityDirectoryScript.new()
	_transforms = TransformsScript.new(_directory)
	_result = IntMathScript.IntResult.new()
	_pose = TransformsScript.Pose.new()


func after_each() -> void:
	"""Drop the per-test stores."""
	_directory = null
	_transforms = null
	_result = null
	_pose = null


func _resident() -> Vector2i:
	"""A live resident reference, the positioned kind this slice actually moves."""
	return _directory.create(EntityDirectoryScript.KIND_RESIDENT)


# --- the derived row ----------------------------------------------------------------------------

func test_capacity_is_the_sum_of_the_four_positioned_kinds() -> void:
	"""systems_architecture.md 2.1: `P = 512 + 1024 + 81920 + 4096 = 87552`."""
	assert_equal(TransformsScript.TRANSFORM_CAPACITY, 87552, "P is 87552 rows")
	var total: int = 0
	for kind: int in EntityDirectoryScript.KIND_COUNT:
		if TransformsScript.kind_is_positioned(kind):
			total += EntityDirectoryScript.KIND_CAPACITY[kind]
	assert_equal(total, 87552, "the positioned kinds' capacities sum to P exactly")
	assert_equal(TransformsScript.TRANSFORM_CAPACITY * 8 * 4, 2801664, "matching the budgeted bytes")


func test_exactly_four_kinds_are_positioned() -> void:
	"""Buildings, furniture, residents and resource nodes own Transform rows; nothing else does."""
	assert_true(TransformsScript.kind_is_positioned(EntityDirectoryScript.KIND_BUILDING), "building")
	assert_true(TransformsScript.kind_is_positioned(EntityDirectoryScript.KIND_FURNITURE), "furniture")
	assert_true(TransformsScript.kind_is_positioned(EntityDirectoryScript.KIND_RESIDENT), "resident")
	assert_true(
		TransformsScript.kind_is_positioned(EntityDirectoryScript.KIND_RESOURCE_NODE), "resource node")
	assert_false(TransformsScript.kind_is_positioned(EntityDirectoryScript.KIND_JOB), "not a job")
	assert_false(TransformsScript.kind_is_positioned(EntityDirectoryScript.KIND_ROOM), "not a room")
	assert_false(TransformsScript.kind_is_positioned(-1), "not an out-of-range kind")


func test_the_row_is_the_kind_base_plus_the_typed_row() -> void:
	"""No second allocator: the Transform row is a pure function of the directory row."""
	var resident: Vector2i = _resident()
	assert_true(_transforms.transform_row_into(resident, _result), "the row derives")
	assert_equal(
		_result.value, 82944 + _directory.get_typed_row(resident),
		"residents start at base 82944, after buildings and furniture")
	var node: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESOURCE_NODE)
	assert_true(_transforms.transform_row_into(node, _result), "the row derives")
	assert_equal(_result.value, 83456 + _directory.get_typed_row(node), "resource nodes at 83456")


func test_the_row_refuses_an_unpositioned_kind_and_a_dead_reference() -> void:
	"""Both failure modes refuse by their own name; neither reports row 0."""
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_false(_transforms.transform_row_into(job, _result), "a job owns no Transform row")
	assert_equal(
		_transforms.last_refusal(), TransformsScript.REFUSE_NOT_POSITIONED, "refusal is named")
	var resident: Vector2i = _resident()
	assert_true(_directory.destroy(resident), "retire it")
	assert_false(_transforms.transform_row_into(resident, _result), "a dead reference has no row")
	assert_equal(_transforms.last_refusal(), TransformsScript.REFUSE_STALE_REF, "refusal is named")
	assert_equal(_result.value, 0, "and the refused result carries no row")


# --- place, advance and binding --------------------------------------------------------------------

func test_place_sets_previous_equal_to_current() -> void:
	"""Task 05.2's "Initialize previous=current": a spawn has no history to interpolate from."""
	var resident: Vector2i = _resident()
	assert_false(_transforms.is_bound(resident), "an unplaced entity is not bound")
	assert_true(_transforms.place(resident, 3 * METRE, 512, 7 * METRE, 16384), "place it")
	assert_true(_transforms.is_bound(resident), "now it is bound")
	assert_true(_transforms.read_into(resident, _pose), "its pose reads")
	assert_equal(_pose.x, 3 * METRE, "x is what was written")
	assert_equal(_pose.y, 512, "y is what was written")
	assert_equal(_pose.z, 7 * METRE, "z is what was written")
	assert_equal(_pose.yaw, 16384, "yaw is what was written")
	assert_true(_pose.matches_previous(), "and previous equals current after a placement")


func test_advance_rolls_current_into_previous() -> void:
	"""ARCH-SYS-001's snapshot: the tick-start pose becomes `previous`, the new pose becomes current."""
	var resident: Vector2i = _resident()
	assert_true(_transforms.place(resident, 1000, 512, 2000, 4096), "place it")
	assert_true(_transforms.advance(resident, 1100, 512, 2050), "advance it")
	assert_true(_transforms.read_into(resident, _pose), "its pose reads")
	assert_equal(_pose.prev_x, 1000, "previous x is the tick-start x")
	assert_equal(_pose.prev_z, 2000, "previous z is the tick-start z")
	assert_equal(_pose.x, 1100, "current x is the new x")
	assert_equal(_pose.z, 2050, "current z is the new z")
	assert_equal(_pose.yaw, 4096, "advance does not touch yaw")
	assert_equal(_pose.prev_yaw, 4096, "so previous yaw follows it unchanged")
	assert_false(_pose.matches_previous(), "and the entity now has a history")


func test_advance_refuses_an_entity_that_was_never_placed() -> void:
	"""A body with no pose cannot be moved from one; that refuses rather than starting at origin."""
	var resident: Vector2i = _resident()
	assert_false(_transforms.advance(resident, 10, 20, 30), "advancing an unplaced entity refuses")
	assert_equal(_transforms.last_refusal(), TransformsScript.REFUSE_NOT_BOUND, "refusal is named")
	assert_false(_transforms.read_into(resident, _pose), "and reading it refuses too")
	assert_equal(_transforms.bound_count(), 0, "nothing became bound by the refusal")


func test_a_typed_row_inherited_from_another_slot_reads_as_unbound() -> void:
	"""THE case a per-slot generation stamp gets wrong; see this file's header.

	The successor takes the predecessor's TYPED ROW but a DIFFERENT directory slot, and that slot's
	first use carries generation 1 -- exactly the predecessor's generation. A generation stamp
	would match and report the predecessor's coordinates as the successor's live position.
	"""
	var blocker: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	var first: Vector2i = _resident()
	assert_equal(first.y, 1, "the first occupant's slot is on its first generation")
	assert_true(_transforms.place(first, 5 * METRE, 512, 5 * METRE, 0), "place the predecessor")
	var row: int = _directory.get_typed_row(first)
	assert_true(_directory.destroy(first), "retire it, freeing both its slot and its typed row")
	assert_true(_directory.create(EntityDirectoryScript.KIND_RESOURCE_NODE).x == first.x,
		"an unrelated entity takes the freed directory slot")
	var second: Vector2i = _resident()
	assert_equal(_directory.get_typed_row(second), row, "the successor inherits the typed row")
	assert_true(second.x != first.x, "from a different directory slot")
	assert_equal(second.y, first.y, "whose generation happens to be identical")
	assert_false(_transforms.is_bound(second), "and it still reads as never placed")
	assert_false(_transforms.read_into(second, _pose), "reading it refuses")
	assert_equal(_transforms.last_refusal(), TransformsScript.REFUSE_NOT_BOUND, "by name")
	assert_true(blocker.x >= 0, "the blocker kept the slot order deterministic")


func test_a_successor_placing_the_row_replaces_the_pose_without_double_counting() -> void:
	"""Reusing a bound row is legal; it must not inflate the bound count."""
	var first: Vector2i = _resident()
	var row: int = _directory.get_typed_row(first)
	assert_true(_transforms.place(first, 1000, 512, 1000, 0), "place the predecessor")
	assert_equal(_transforms.bound_count(), 1, "one row is bound")
	assert_true(_directory.destroy(first), "retire it")
	var second: Vector2i = _resident()
	assert_equal(_directory.get_typed_row(second), row, "the successor inherits the same typed row")
	assert_true(_transforms.place(second, 2000, 512, 2000, 0), "the successor places it")
	assert_equal(_transforms.bound_count(), 1, "still exactly one bound row, not two")
	assert_true(_transforms.read_into(second, _pose), "its pose reads")
	assert_equal(_pose.x, 2000, "and it is the successor's pose, not the predecessor's")


func test_unbind_clears_the_row_and_the_count() -> void:
	"""Retiring an owner releases its row, and a later read refuses rather than reporting zeros."""
	var resident: Vector2i = _resident()
	assert_true(_transforms.place(resident, 1000, 512, 2000, 0), "place it")
	assert_equal(_transforms.bound_count(), 1, "one row is bound")
	assert_true(_transforms.unbind(resident), "unbind it")
	assert_equal(_transforms.bound_count(), 0, "no rows are bound")
	assert_false(_transforms.is_bound(resident), "the entity is no longer bound")
	assert_false(_transforms.read_into(resident, _pose), "reading refuses")
	assert_false(_transforms.unbind(resident), "and unbinding twice refuses")


func test_place_refuses_a_field_that_does_not_fit_int32() -> void:
	"""The columns are int32; an oversized field refuses instead of being truncated into the map."""
	var resident: Vector2i = _resident()
	assert_false(
		_transforms.place(resident, IntMathScript.INT32_MAX + 1, 0, 0, 0), "x beyond int32 refuses")
	assert_equal(
		_transforms.last_refusal(), TransformsScript.REFUSE_OUT_OF_INT32, "refusal is named")
	assert_false(_transforms.is_bound(resident), "and nothing was bound")
	assert_true(_transforms.place(resident, IntMathScript.INT32_MAX, 0, 0, 0), "the bound itself fits")


func test_set_yaw_rolls_the_previous_yaw() -> void:
	"""A facing change has history too, so a renderer can interpolate the turn."""
	var resident: Vector2i = _resident()
	assert_true(_transforms.place(resident, 0, 0, 0, 1000), "place it facing 1000")
	assert_true(_transforms.set_yaw(resident, 5000), "turn it")
	assert_true(_transforms.read_into(resident, _pose), "its pose reads")
	assert_equal(_pose.prev_yaw, 1000, "previous yaw is the old facing")
	assert_equal(_pose.yaw, 5000, "current yaw is the new facing")
	assert_equal(_pose.x, 0, "and the position did not move")


# --- yaw: the settled scale, and the unsettled convention -------------------------------------------

func test_yaw_scale_is_the_contracted_65536_units_per_turn() -> void:
	"""ARCH-AUTH-002 fixes the SCALE. It fixes neither the zero direction nor the sign of a turn."""
	assert_equal(TransformsScript.YAW_UNITS_PER_TURN, 65536, "one turn is 65536 units")
	assert_equal(TransformsScript.YAW_HALF_TURN, 32768, "half a turn is 32768")


func test_shortest_yaw_delta_takes_the_short_way_round() -> void:
	"""Interpolating a turn past the wrap must not spin the long way; the arc is signed and shortest."""
	assert_equal(TransformsScript.shortest_yaw_delta(0, 1000), 1000, "a small turn is itself")
	assert_equal(TransformsScript.shortest_yaw_delta(1000, 0), -1000, "and it signs the other way")
	assert_equal(
		TransformsScript.shortest_yaw_delta(64536, 1000), 2000,
		"crossing the wrap forwards is 2000, not -63536")
	assert_equal(
		TransformsScript.shortest_yaw_delta(1000, 64536), -2000, "and backwards is -2000")
	assert_equal(TransformsScript.shortest_yaw_delta(0, 32768), 32768, "an exact half turn is +")


# --- the presentation boundary ----------------------------------------------------------------------

func test_interpolation_returns_metres_from_the_two_committed_ticks() -> void:
	"""crowd 12.1: divide by 1024 only at extraction. The integers are the truth."""
	var resident: Vector2i = _resident()
	var view: TransformsScript.PresentationPose = TransformsScript.PresentationPose.new()
	assert_true(_transforms.place(resident, 0, 0, 0, 0), "place it at the origin")
	assert_true(_transforms.advance(resident, 2 * METRE, 512, 4 * METRE), "move it")
	assert_true(_transforms.presentation_interpolate_into(resident, 0, 1, view), "alpha 0 reads")
	assert_almost_equal(view.x_metres, 0.0, "alpha 0 is the previous tick exactly")
	assert_true(_transforms.presentation_interpolate_into(resident, 1, 1, view), "alpha 1 reads")
	assert_almost_equal(view.x_metres, 2.0, "alpha 1 is the current tick exactly")
	assert_true(_transforms.presentation_interpolate_into(resident, 1, 2, view), "alpha 1/2 reads")
	assert_almost_equal(view.x_metres, 1.0, "and half way is one metre")
	assert_almost_equal(view.z_metres, 2.0, "with z following the same rule")
	assert_almost_equal(view.y_metres, 0.25, "and y in metres too: 512/1024")


func test_interpolation_refuses_an_alpha_outside_the_tick() -> void:
	"""The alpha is an integer fraction, bounds-checked; no extrapolation past a committed tick."""
	var resident: Vector2i = _resident()
	var view: TransformsScript.PresentationPose = TransformsScript.PresentationPose.new()
	assert_true(_transforms.place(resident, 0, 0, 0, 0), "place it")
	assert_false(_transforms.presentation_interpolate_into(resident, 2, 1, view), "alpha > 1 refuses")
	assert_equal(
		_transforms.last_refusal(), TransformsScript.REFUSE_INVALID_ALPHA, "refusal is named")
	assert_false(_transforms.presentation_interpolate_into(resident, -1, 1, view), "negative refuses")
	assert_false(_transforms.presentation_interpolate_into(resident, 0, 0, view), "zero denominator")


func test_interpolation_cannot_change_one_authoritative_field() -> void:
	"""The invisible-view rule at its source: a reader is structurally unable to write."""
	var resident: Vector2i = _resident()
	var view: TransformsScript.PresentationPose = TransformsScript.PresentationPose.new()
	assert_true(_transforms.place(resident, 1024, 512, 2048, 100), "place it")
	assert_true(_transforms.advance(resident, 1124, 512, 2148), "move it")
	var before: int = _transforms.authoritative_digest()
	for numerator: int in 17:
		assert_true(
			_transforms.presentation_interpolate_into(resident, numerator, 16, view),
			"every alpha in the tick reads")
	assert_equal(
		_transforms.authoritative_digest(), before,
		"seventeen presentation reads left the authoritative digest identical")


func test_interpolation_refuses_an_unplaced_or_dead_entity() -> void:
	"""A renderer cannot conjure a pose for something that has none."""
	var resident: Vector2i = _resident()
	var view: TransformsScript.PresentationPose = TransformsScript.PresentationPose.new()
	assert_false(
		_transforms.presentation_interpolate_into(resident, 0, 1, view), "unplaced refuses")
	assert_true(_transforms.place(resident, 0, 0, 0, 0), "place it")
	assert_true(_directory.destroy(resident), "retire it")
	assert_false(
		_transforms.presentation_interpolate_into(resident, 0, 1, view), "a dead reference refuses")
	assert_equal(_transforms.last_refusal(), TransformsScript.REFUSE_STALE_REF, "refusal is named")


# --- the verification digest --------------------------------------------------------------------------

func test_identical_stores_digest_identically_and_a_changed_field_does_not() -> void:
	"""The digest has to notice a single unit of difference, or it proves nothing about parity."""
	var other_directory: EntityDirectoryScript = EntityDirectoryScript.new()
	var other: TransformsScript = TransformsScript.new(other_directory)
	var here: Vector2i = _resident()
	var there: Vector2i = other_directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(_transforms.place(here, 1000, 512, 2000, 300), "place one")
	assert_true(other.place(there, 1000, 512, 2000, 300), "place the other identically")
	assert_equal(
		_transforms.authoritative_digest(), other.authoritative_digest(),
		"two stores holding the same pose digest the same")
	assert_true(other.advance(there, 1001, 512, 2000), "move the second by one unit")
	assert_true(
		_transforms.authoritative_digest() != other.authoritative_digest(),
		"and a single unit of difference changes the digest")


func test_an_empty_store_digests_to_zero_and_a_placement_changes_it() -> void:
	"""An empty store must be distinguishable from one holding a body at the origin."""
	assert_equal(_transforms.authoritative_digest(), 0, "nothing placed digests to zero")
	var resident: Vector2i = _resident()
	assert_true(_transforms.place(resident, 0, 0, 0, 0), "place a body at the very origin")
	assert_true(
		_transforms.authoritative_digest() != 0,
		"a body at the origin is not the same state as no body at all")
