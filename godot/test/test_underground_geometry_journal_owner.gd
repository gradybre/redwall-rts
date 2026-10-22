extends "res://test/framework/test_case.gd"
## Decision 2045 (P-2045-2 (a), P-2044-18): the geometry journal sees an owner change. A SUPPORT row removed and
## re-added in its reused slot with the same box and role but another owner, inside one stage, is a changed row:
## WorldRoutes' carried stair form reads SUPPORT owners and may carry an edge only over unchanged rows.

const Journal := preload("res://scripts/core/underground_geometry_journal.gd")
const Space := preload("res://scripts/core/room_space.gd")
const BOX: Array[int] = [0, -1024, 0, 1024, 0, 1024]


@warning_ignore_start("unused_private_class_variable") # Read only by the journal, through duck typing.
class FakeOwner extends RefCounted:
	## The SpaceOwner columns the journal reads, live (`_r_`) and staged (`_s_r_`), for one region slot.
	var _region_capacity: int = 1
	var _r_present: PackedByteArray = PackedByteArray([1])
	var _s_r_present: PackedByteArray = PackedByteArray([1])
	var _r_role: PackedInt32Array = PackedInt32Array([Space.SUPPORT])
	var _s_r_role: PackedInt32Array = PackedInt32Array([Space.SUPPORT])
	var _r_claim_kind: PackedInt32Array = PackedInt32Array([0])
	var _s_r_claim_kind: PackedInt32Array = PackedInt32Array([0])
	var _r_claim_slot: PackedInt32Array = PackedInt32Array([-1])
	var _s_r_claim_slot: PackedInt32Array = PackedInt32Array([-1])
	var _r_claim_generation: PackedInt32Array = PackedInt32Array([0])
	var _s_r_claim_generation: PackedInt32Array = PackedInt32Array([0])
	var _r_owner_slot: PackedInt32Array = PackedInt32Array([7])
	var _s_r_owner_slot: PackedInt32Array = PackedInt32Array([7])
	var _r_owner_generation: PackedInt32Array = PackedInt32Array([3])
	var _s_r_owner_generation: PackedInt32Array = PackedInt32Array([3])
	var _r_lo_x: PackedInt32Array = PackedInt32Array([BOX[0]])
	var _r_lo_y: PackedInt32Array = PackedInt32Array([BOX[1]])
	var _r_lo_z: PackedInt32Array = PackedInt32Array([BOX[2]])
	var _r_hi_x: PackedInt32Array = PackedInt32Array([BOX[3]])
	var _r_hi_y: PackedInt32Array = PackedInt32Array([BOX[4]])
	var _r_hi_z: PackedInt32Array = PackedInt32Array([BOX[5]])
	var _s_r_lo_x: PackedInt32Array = PackedInt32Array([BOX[0]])
	var _s_r_lo_y: PackedInt32Array = PackedInt32Array([BOX[1]])
	var _s_r_lo_z: PackedInt32Array = PackedInt32Array([BOX[2]])
	var _s_r_hi_x: PackedInt32Array = PackedInt32Array([BOX[3]])
	var _s_r_hi_y: PackedInt32Array = PackedInt32Array([BOX[4]])
	var _s_r_hi_z: PackedInt32Array = PackedInt32Array([BOX[5]])
@warning_ignore_restore("unused_private_class_variable")


func _changes(owner: FakeOwner) -> int:
	"""The staged sides the journal reports for the stage."""
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(Journal.STAGED_STRIDE * 4)
	return Journal.staged_changes_into(owner, out, 4)


func test_an_unchanged_row_is_not_a_change() -> void:
	"""Same presence, role, owner and box in both banks: no side is reported."""
	var owner: FakeOwner = FakeOwner.new()
	assert_false(Journal._row_changed(owner, 0), "traversal view")
	assert_false(Journal._row_changed(owner, 0, true), "full view")
	assert_equal(_changes(owner), 0, "no staged side")


func test_a_reused_slot_with_a_new_owner_is_a_change() -> void:
	"""The slot's SUPPORT row was removed and another Room's added in the same slot, same box and role."""
	var owner: FakeOwner = FakeOwner.new()
	owner._s_r_owner_slot[0] = 9
	assert_true(Journal._row_changed(owner, 0), "a new owner slot is a change")
	assert_true(Journal._row_changed(owner, 0, true), "and in the full view")
	assert_equal(_changes(owner), 2, "both sides are reported")


func test_a_new_owner_generation_is_a_change() -> void:
	"""The same owner slot reused by a later generation is another owner."""
	var owner: FakeOwner = FakeOwner.new()
	owner._s_r_owner_generation[0] = 4
	assert_true(Journal._row_changed(owner, 0), "a new owner generation is a change")
	assert_equal(_changes(owner), 2, "both sides are reported")


func test_the_box_and_role_still_count() -> void:
	"""The earlier comparisons are unchanged."""
	var owner: FakeOwner = FakeOwner.new()
	owner._s_r_hi_x[0] = 2048
	assert_true(Journal._row_changed(owner, 0), "a moved box")
	owner = FakeOwner.new()
	owner._s_r_role[0] = Space.OBSTACLE
	assert_true(Journal._row_changed(owner, 0), "another role")
	owner = FakeOwner.new()
	owner._s_r_present[0] = 0
	assert_true(Journal._row_changed(owner, 0), "a removed row")
