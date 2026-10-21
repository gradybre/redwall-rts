extends "res://test/framework/test_case.gd"
## Decision 2044 (P-2044-6 (a)): decision 1972's P-1972-8 natural-floor witness, reinstated with a never-cut check.
## A stop no installed prism top holds stands on natural earth (an M5 landing's floor); Locations witnesses it only by
## the completed paid cube of its own Room whose floor it stands on, and only while the cube under that floor was never
## cut. One test per guard, on the work-face fixture's real Locations and Sites (its level-1 corridor at FLOOR).

const FaceCase := preload("res://test/test_underground_work_face.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _face: FaceCase = null
## The cube the stop stands in (on its floor) and the one under it.
var _cube: Vector3i = Vector3i.ZERO
var _below: Vector3i = Vector3i.ZERO


func before_each() -> void:
	"""The corridor fixture; its first cube is the stop's cube, made a completed paid Site; the cube under it a Site."""
	_face = FaceCase.new()
	_face._actual = FaceCase.UndergroundFixture.new()
	_face._actual._actual_fixture(0)
	assert_true(_face._actual.failures.is_empty(), "corridor fixture: %s" % _face._actual.failures)
	_cube = Vector3i(FaceCase.X, FaceCase.FLOOR, FaceCase.Z)
	_below = _cube - Vector3i(0, 1024, 0)
	var sites: Sites = _face._actual.physical.sites
	_sites_row(_cube) # Claimed by the fixture already.
	assert_true(sites.claim_quantum(_below, _face._actual.room).ok, "a Site under the stop's floor")
	sites._phase[_sites_row(_cube)] = Sites.SUPPORTED_VOID
	_face._actual._locations._remaining = 1 << 20
	# The corridor fixture builds its Sites on an Inventory of its own; production Locations and Sites share one, which
	# the installed-Site lookup proves before it reads a row.
	_face._actual._locations._inventory = sites._inventory


func after_each() -> void:
	"""Release the fixture."""
	if _face != null:
		_face.after_each()
		assert_true(_face.failures.is_empty(), "fixture cleanup: %s" % _face.failures)
	_face = null


func _sites_row(origin: Vector3i) -> int:
	"""The Sites row of one claimed cube."""
	var site: Vector2i = _face._actual.physical.sites.site_at(origin)
	assert_true(site != NULL_REF, "a Site at %s" % origin)
	return site.x


func _record(point: Vector3i, room: Vector2i) -> Locations.Record:
	"""A stop record at `point` in `room`."""
	var record: Locations.Record = Locations.Record.new()
	record.point = point
	record.room = room
	return record


func _witness(point: Vector3i, room: Vector2i) -> Vector2i:
	"""The witness Locations gives a stop with no prism under it."""
	return _face._actual._locations._natural_floor_site(_face._actual.physical.sites, _record(point, room))


func test_a_stop_on_a_completed_cubes_floor_over_never_cut_earth_is_witnessed_by_that_cube() -> void:
	"""The positive case: the stop's own cube, completed, of its Room, with never-cut earth under its floor."""
	var point: Vector3i = _cube + Vector3i(512, 0, 512)
	assert_equal(_witness(point, _face._actual.room), Vector2i(_sites_row(_cube), Sites.SITE_GENERATION),
		"witnessed by the cube it stands in")


func test_a_cube_not_yet_completed_is_no_witness() -> void:
	"""Guard 1, the phase: an unfinished (or never cut) cube does not witness a stop on its floor."""
	_face._actual.physical.sites._phase[_sites_row(_cube)] = Sites.OPEN_UNFINISHED
	assert_equal(_witness(_cube + Vector3i(512, 0, 512), _face._actual.room), NULL_REF, "not completed")


func test_another_rooms_cube_is_no_witness() -> void:
	"""Guard 2, the Room: a stop of another Room is not witnessed by this Room's cube."""
	var commands: RefCounted = _face._actual.commands
	commands.permit(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, Buildings.ROOM_TYPE_CORRIDOR)
	var other: Vector2i = _face._actual._buildings.designate_spatial_room(Buildings.ROOM_TYPE_CORRIDOR).ref
	assert_equal(_witness(_cube + Vector3i(512, 0, 512), other), NULL_REF, "a foreign Room")


func test_a_point_off_the_cubes_floor_is_no_witness() -> void:
	"""Guard 3, the floor plane: a point inside the cube but above its floor is not standing on that floor."""
	assert_equal(_witness(_cube + Vector3i(512, 1, 512), _face._actual.room), NULL_REF, "one unit above the floor")


func test_earth_below_the_floor_that_was_cut_is_no_witness() -> void:
	"""Guard 4, the never-cut check (P-2044-6 (a)): once the cube under the floor has been cut, the floor is gone and
	the stop would stand over a dug cube; the witness refuses."""
	var point: Vector3i = _cube + Vector3i(512, 0, 512)
	_face._actual.physical.sites._ever_cut[_sites_row(_below)] = 1
	assert_equal(_witness(point, _face._actual.room), NULL_REF, "cut below")


func test_an_unclaimed_cube_below_counts_as_never_cut() -> void:
	"""Natural earth with no Site at all under the floor is never cut, so it does not stop the witness."""
	var point: Vector3i = _cube + Vector3i(1536, 0, 512)
	_face._actual.physical.sites._phase[_sites_row(_cube + Vector3i(1024, 0, 0))] = Sites.SUPPORTED_VOID
	assert_equal(_witness(point, _face._actual.room).x, _sites_row(_cube + Vector3i(1024, 0, 0)), "no Site below")

