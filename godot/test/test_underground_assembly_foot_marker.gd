extends "res://test/framework/test_case.gd"
## ADR 1202 (Brendan, option 1): a handling foot inside the station's proved SUPPORT may overlap only the
## station Room's own reservation marker. Every other claim, Room, solid, body and unsupported foot still refuses.

const Physical := preload("res://data/underground/mole-worker/qualified-assembly-v1/physical_certificate.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const ROOM: Vector2i = Vector2i(1, 1)
const OTHER_ROOM: Vector2i = Vector2i(2, 1)
const MARKER_BOX: Array[int] = [-1024, -1024, -2048, 1024, 0, 0]
const FOOT_BOX: Array[int] = [-274, -1, -1705, 299, 0, -1362]
const DECK_SUPPORT: Array[int] = [-1024, -128, -2048, 1024, 0, 0]


class Box extends RefCounted:
	## The certificate's three fixed scratch boxes, as WorldRoutes carries them.
	var _bounds: PackedInt32Array = PackedInt32Array()
	@warning_ignore("unused_private_class_variable")
	var _support: PackedInt32Array = PackedInt32Array()
	@warning_ignore("unused_private_class_variable")
	var _scratch: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])


class Graph extends RefCounted:
	## The operation budget and Space owner the certificate reads.
	var _owner: Owner = null
	@warning_ignore("unused_private_class_variable")
	var _remaining: int = 100000
	@warning_ignore("unused_private_class_variable")
	var _operation_error: StringName = &""


var _owner: Owner = null
var _box: Box = null
var _graph: Graph = null


func before_each() -> void:
	"""A bare Region bank: only the columns the certificate reads, no live World."""
	_owner = Owner.new(null)
	_box = Box.new()
	_box._bounds = PackedInt32Array(FOOT_BOX)
	_box._support = PackedInt32Array(DECK_SUPPORT)
	_graph = Graph.new()
	_graph._owner = _owner


func after_each() -> void:
	"""Release the fixture."""
	_owner = null
	_box = null
	_graph = null


func _add_region(role: int, kind: int, claim: Vector2i, owner: Vector2i, box: PackedInt32Array) -> void:
	"""Append one present Region row with explicit role, claim and owner."""
	var row: int = _owner._region_capacity
	_owner._region_capacity += 1
	_owner._r_present.append(1); _owner._r_role.append(role); _owner._r_claim_kind.append(kind)
	_owner._r_claim_slot.append(claim.x); _owner._r_claim_generation.append(claim.y)
	_owner._r_owner_slot.append(owner.x); _owner._r_owner_generation.append(owner.y)
	_owner._r_lo_x.append(box[0]); _owner._r_lo_y.append(box[1]); _owner._r_lo_z.append(box[2])
	_owner._r_hi_x.append(box[3]); _owner._r_hi_y.append(box[4]); _owner._r_hi_z.append(box[5])
	assert_equal(_owner._region_capacity, row + 1, "one Region row")


func _foot(room: Vector2i) -> StringName:
	"""Run the shared foot Region proof at the station Room."""
	return Physical._regions_refusal(_box, _graph, null, -1, true, room)


func test_foot_inside_support_may_share_only_its_room_marker() -> void:
	"""The installed deck lies inside the cut cavity, so its contact layer is also the Room's own marker."""
	_add_region(Space.OBSTACLE, Owner.CLAIM_ROOM, ROOM, ROOM, PackedInt32Array(MARKER_BOX))
	assert_equal(_foot(ROOM), &"", "the Room's own reservation marker is not matter")
	assert_true(Physical.own_room_marker(_owner, 0, ROOM), "exact own marker")


func test_foot_over_another_rooms_marker_refuses() -> void:
	"""A different Room's reservation is not this station's."""
	_add_region(Space.OBSTACLE, Owner.CLAIM_ROOM, OTHER_ROOM, OTHER_ROOM, PackedInt32Array(MARKER_BOX))
	assert_equal(_foot(ROOM), &"ASSEMBLY_FOREIGN_SOLID", "another Room's marker blocks the foot")


func test_foot_over_a_mismatched_or_construction_claim_refuses() -> void:
	"""Claim and owner must both be the station Room, and only a Room claim qualifies."""
	_add_region(Space.OBSTACLE, Owner.CLAIM_ROOM, ROOM, OTHER_ROOM, PackedInt32Array(MARKER_BOX))
	assert_equal(_foot(ROOM), &"ASSEMBLY_FOREIGN_SOLID", "Room claim owned by another Room")
	before_each()
	_add_region(Space.OBSTACLE, Owner.CLAIM_CONSTRUCTION, ROOM, ROOM, PackedInt32Array(MARKER_BOX))
	assert_equal(_foot(ROOM), &"ASSEMBLY_FOREIGN_SOLID", "a Construction claim is never a Room marker")


func test_unroomed_station_or_physical_obstacle_still_refuses() -> void:
	"""A surface station has no own marker; real unclaimed obstacles block beside the marker."""
	_add_region(Space.OBSTACLE, Owner.CLAIM_ROOM, ROOM, ROOM, PackedInt32Array(MARKER_BOX))
	assert_equal(_foot(NULL_REF), &"ASSEMBLY_FOREIGN_SOLID", "no station Room, no exception")
	_add_region(Space.OBSTACLE, Owner.CLAIM_NONE, NULL_REF, ROOM, PackedInt32Array([-100, -1, -1500, 100, 1, -1400]))
	assert_equal(_foot(ROOM), &"ASSEMBLY_FOREIGN_SOLID", "physical obstacle under the foot still blocks")


func test_foot_outside_support_refuses_even_over_its_marker() -> void:
	"""The exception never replaces the proved SUPPORT containment."""
	_add_region(Space.OBSTACLE, Owner.CLAIM_ROOM, ROOM, ROOM, PackedInt32Array(MARKER_BOX))
	_box._support = PackedInt32Array([-1024, -128, -2048, 1024, 0, -1500])
	assert_equal(_foot(ROOM), &"ASSEMBLY_FOOTING", "foot partly beyond the deck support")


func test_body_over_its_own_room_marker_refuses() -> void:
	"""Bodies and tools keep the unchanged rule: every claim blocks them."""
	_add_region(Space.OBSTACLE, Owner.CLAIM_ROOM, ROOM, ROOM, PackedInt32Array(MARKER_BOX))
	assert_equal(Physical._regions_refusal(_box, _graph, null, -1, false, ROOM), &"ASSEMBLY_FOREIGN_SOLID",
		"a body inside the Room's own marker still refuses")
