extends "res://test/framework/test_case.gd"
## Decision 2044 (P-2044-11 (a), Brendan 2026-10-17): before any M5 floor station is built, a fixture proves that
## retiring a floor station's route edges, its Location and the Room's SUPPORT strip under it frees the cube below for
## its own Room's paid cut. Two real-owner fixtures, reused as helpers:
## - the paid cycle (`test_underground_space_authority.gd`): the real Space owner, Space authority, Sites, Construction,
##   Inventory and Work around one claimed Room cube, with synthetic contacts (a 1 m side approach and its reach);
## - the endpoint layer (`test_underground_work_face.gd`'s corridor at an authored level-1 floor): real Locations,
##   Routes, WorldRoutes and Sites over a Room SUPPORT strip, the floor a station stands on.
## The cube below a station holds the strip's lower part; a strip is the Room's claim-free SUPPORT, as decision 1972's
## natural retention stages it.

const AuthorityCase := preload("res://test/test_underground_space_authority.gd")
const FaceCase := preload("res://test/test_underground_work_face.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## The paid fixture's claimed cube is [0, 1024)^3; its synthetic reach enters it by 1 u on -x.
const CUBE: PackedInt32Array = [0, 0, 0, 1024, 1024, 1024]
## A strip in the cube's top 128 u across the whole cube, so it meets the reach.
const STRIP_IN_REACH: Array[int] = [0, 896, 0, 1024, 1024, 1024]
## The same strip clear of the reach (x 512..1024).
const STRIP_CLEAR: Array[int] = [512, 896, 0, 1024, 1024, 1024]

var _paid: AuthorityCase = null
var _face: FaceCase = null


func after_each() -> void:
	"""Each helper fixture releases its own owners and reports its own nested assertion failures."""
	if _paid != null:
		_paid.after_each()
		assert_true(_paid.failures.is_empty(), "paid fixture: %s" % _paid.failures)
	if _face != null:
		_face.after_each()
		assert_true(_face.failures.is_empty(), "endpoint fixture: %s" % _face.failures)
	_paid = null
	_face = null


func _paid_fixture(strip: Array[int]) -> Vector2i:
	"""The real paid cycle around one claimed cube, with the Room's SUPPORT strip published in it; the strip's handle."""
	_paid = AuthorityCase.new()
	_paid.before_each()
	var token: int = _paid._owner.begin_stage(_paid._owner.revision()).token
	assert_equal(_paid._owner.stage_source(token, _paid._room), &"", "the Room's source")
	var handle: Vector2i = _paid._add(token, strip, Space.SUPPORT, _paid._room)
	assert_equal(_paid._owner.seal(token), &"", "the strip seals beside the claim and the solid")
	_paid._owner.publish(token)
	return handle


func _retire_strip(handle: Vector2i) -> void:
	"""Remove the strip's exact row in one sealed Space transaction, as its retiring issuer stages it."""
	var token: int = _paid._owner.begin_stage(_paid._owner.revision()).token
	assert_equal(_paid._owner.stage_remove(token, handle), &"", "the strip's exact generation")
	assert_equal(_paid._owner.seal(token), &"", "the Space seals without the strip")
	_paid._owner.publish(token)
	assert_false(_paid._owner.is_live_region(handle), "the strip is gone")


func _support_rows_in_cube() -> int:
	"""Live SUPPORT rows meeting the paid cube."""
	var image: Space.Snapshot = Space.Snapshot.new()
	assert_equal(_paid._owner.snapshot_into(image), &"", "full survey")
	var count: int = 0
	for row: int in image.volumes.role.size():
		if image.volumes.role[row] == Space.SUPPORT and Space.overlaps(image.volumes.box_at(row), CUBE): count += 1
	return count


func test_a_live_strip_in_the_cubes_reach_refuses_its_paid_brace_and_pays_nothing() -> void:
	"""The Room's own SUPPORT in the work reach is a contact obstruction: the BRACE does not even open, and nothing
	moves or is spent."""
	_paid_fixture(STRIP_IN_REACH)
	var geometry: PackedByteArray = _paid._owner.state_bytes()
	var goods: PackedByteArray = _paid._inventory.state_bytes()
	var physical: PackedByteArray = _paid._sites.state_bytes()
	var opened: RefCounted = _paid._sites.open_phase(_paid._site, Contract.OP_BRACE)
	assert_false(opened.ok, "the paid BRACE does not open")
	assert_equal(opened.error, &"SPACE_WORK_CONTACT_OBSTRUCTED", "the strip in its reach obstructs the contact")
	assert_equal(_paid._owner.state_bytes(), geometry, "no geometry moves")
	assert_equal(_paid._inventory.state_bytes(), goods, "nothing is consumed")
	assert_equal(_paid._sites.state_bytes(), physical, "no phase is recorded")


func test_a_retired_strip_frees_the_cube_for_its_own_rooms_whole_cut() -> void:
	"""P-2044-11: once the strip is retired, BRACE, CUT and FINISH all complete for the cube's own Room; it ends as the
	Room's supported void with no SUPPORT left in it and one cube of earth out."""
	var strip: Vector2i = _paid_fixture(STRIP_IN_REACH)
	assert_false(_paid._sites.open_phase(_paid._site, Contract.OP_BRACE).ok, "refused while the strip stands")
	_retire_strip(strip)
	_paid._complete(Contract.OP_BRACE)
	_paid._complete(Contract.OP_CUT)
	assert_equal(_paid._target_role(), Space.UNFINISHED, "the cut opens the cube")
	_paid._complete(Contract.OP_FINISH)
	assert_equal(_paid._target_role(), Space.SUPPORTED_VOID, "the finished cube is the Room's supported void")
	assert_equal(_support_rows_in_cube(), 0, "no SUPPORT is left inside it")
	assert_equal(_paid._inventory.total_live_milli(_paid._items.compiled_id(&"excavated_earth")), 2000, "one cube of earth")


func test_a_strip_clear_of_the_reach_is_not_refused_but_survives_the_cut_inside_the_void() -> void:
	"""Why retirement must come first: a strip the reach does not meet is not refused, and the cut leaves it standing
	inside the dug void (SUPPORT over nothing), so the station's footing would be a lie. Never left to the cut."""
	_paid_fixture(STRIP_CLEAR)
	_paid._complete(Contract.OP_BRACE)
	_paid._complete(Contract.OP_CUT)
	assert_equal(_paid._target_role(), Space.UNFINISHED, "the cut is admitted")
	assert_equal(_support_rows_in_cube(), 1, "and the strip still stands inside the unfinished cube")


func _face_fixture() -> void:
	"""The corridor at the level-1 floor: its SUPPORT strip under the floor, two stations on it, one WALK edge between
	them on the base fixture's synthetic WALK content."""
	_face = FaceCase.new()
	_face._actual = FaceCase.UndergroundFixture.new()
	_face._actual._actual_fixture(0)
	assert_true(_face._actual.failures.is_empty(), "corridor fixture: %s" % _face._actual.failures)


func _walk_edge(first: Vector2i, last: Vector2i) -> Routes.Edge:
	"""One straight WALK edge along the corridor floor between two of its stations."""
	var f: FaceCase.UndergroundFixture = _face._actual
	var a: Locations.Record = _record(first)
	var b: Locations.Record = _record(last)
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = first
	edge.to_location = last
	edge.section = f._floor
	edge.room = f.room
	edge.level = 1
	edge.family = -1
	edge.variant = 0
	edge.mode = Profiles.MODE_WALK
	edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = f._profiles.content_revision()
	edge.geometry_revision = f._owner.revision()
	edge.point_count = 2
	edge.points = PackedInt32Array([a.point.x, a.point.y, a.point.z, b.point.x, b.point.y, b.point.z])
	edge.length_u = absi(b.point.x - a.point.x) + absi(b.point.z - a.point.z)
	return edge


func _record(location: Vector2i) -> Locations.Record:
	"""A live Location's record."""
	var out: Locations.Record = Locations.Record.new()
	out.envelope.resize(6)
	out.support.resize(6)
	assert_equal(_face._actual._locations.read_location_into(location, out), &"", "live station")
	return out


func _publish_edge(edge: Routes.Edge) -> Vector2i:
	"""Publish one edge through WorldRoutes' real proof; its handle."""
	var f: FaceCase.UndergroundFixture = _face._actual
	var token: int = f._begin()
	var added: Routes.Result = f._routes.stage_add(token, edge)
	assert_equal(added.error, &"", "the floor walk is proved")
	assert_equal(f._binding.seal(token), &"", "sealed")
	assert_equal(f._binding.publish(token), &"", "published")
	f._end(token)
	return added.ref


func _remove_edge(edge: Vector2i) -> StringName:
	"""Retire one edge through WorldRoutes; its refusal."""
	var f: FaceCase.UndergroundFixture = _face._actual
	var token: int = f._begin()
	var code: StringName = f._routes.stage_remove(token, edge)
	if code == &"": code = f._binding.seal(token)
	if code == &"": code = f._binding.publish(token)
	f._end(token)
	return code


func _remove_location(location: Vector2i) -> StringName:
	"""Retire one station through Locations' own preparation; its refusal."""
	var f: FaceCase.UndergroundFixture = _face._actual
	var cold: int = f._budget.acquire(Budget.COLD_BYTES)
	var token: int = f._locations.begin_prepare(cold).token
	var code: StringName = f._locations.stage_remove(token, location)
	if code == &"": code = f._locations.seal(token)
	if code == &"" and not f._locations.publish(token): code = &"TEST_LOCATION_PUBLISH"
	f._locations.abort(token)
	assert_equal(f._budget.release(cold), &"", "lease returned")
	return code


func _refresh_location(location: Vector2i) -> StringName:
	"""Re-prove one live station against the current Space (discarded, never published)."""
	var f: FaceCase.UndergroundFixture = _face._actual
	var cold: int = f._budget.acquire(Budget.COLD_BYTES)
	var token: int = f._locations.begin_prepare(cold).token
	var code: StringName = f._locations.stage_refresh(token, location)
	if code == &"": code = f._locations.seal(token)
	f._locations.abort(token)
	assert_equal(f._budget.release(cold), &"", "lease returned")
	return code


func _retire_strip_under(cube: PackedInt32Array) -> void:
	"""Replace the corridor's SUPPORT strip by what lies outside `cube`, in one sealed Space transaction."""
	var f: FaceCase.UndergroundFixture = _face._actual
	var handles: PackedInt32Array = PackedInt32Array()
	assert_equal(f._owner.overlapping_regions_into(cube, handles), &"", "the regions meeting the cube")
	var token: int = f._owner.begin_stage(f._owner.revision()).token
	var region: Owner.Region = Owner.Region.new()
	var retired: int = 0
	for at: int in range(0, handles.size(), 2):
		assert_equal(f._owner.region_into(Vector2i(handles[at], handles[at + 1]), region), &"", "live region")
		if region.role != Space.SUPPORT or region.claim_kind != Owner.CLAIM_NONE or region.owner != f.room: continue
		assert_equal(f._owner.stage_remove(token, Vector2i(handles[at], handles[at + 1])), &"", "the strip row")
		var outside: PackedInt32Array = region.box.duplicate()
		outside[3] = cube[0] # The fixture's strip spans x X..X+2048; the station's cube is its +x half.
		region.box = outside
		assert_equal(f._owner.stage_add(token, region).error, &"", "the strip outside the cube stays")
		retired += 1
	assert_equal(retired, 1, "one strip met the cube")
	assert_equal(f._owner.seal(token), &"", "sealed")
	f._owner.publish(token)


func test_a_station_retires_edges_first_then_its_location_then_the_strip_under_it() -> void:
	"""P-2044-11, the endpoint side: a station on the floor above the cube is held by its route edge, leaves once the
	edge has gone, and only then may the strip under it go. The station left beside it, on the strip outside the cube,
	still re-proves its footing; a station left standing on the retired strip would not."""
	_face_fixture()
	var f: FaceCase.UndergroundFixture = _face._actual
	var floor: int = FaceCase.FLOOR
	var cube: PackedInt32Array = PackedInt32Array([FaceCase.X + 1024, floor - 1024, FaceCase.Z,
		FaceCase.X + 2048, floor, FaceCase.Z + 1024])
	var station: Vector2i = f._last
	assert_true(Space.contains_box(cube, _record(station).support), "the station's footing lies in the cube below")
	var edge: Vector2i = _publish_edge(_walk_edge(f._first, station))
	assert_equal(_remove_location(station), &"LOCATION_ROUTE_RETAINED", "a station its edge still names cannot leave")
	assert_equal(_remove_edge(edge), &"", "the edge retires first")
	assert_equal(_remove_location(station), &"", "then the station")
	assert_false(f._locations.is_live_location(station), "the station is gone")
	_retire_strip_under(cube)
	assert_equal(_refresh_location(f._first), &"", "the station on the strip outside the cube still stands")


func test_a_station_left_on_a_retired_strip_no_longer_proves_its_footing() -> void:
	"""The order is load-bearing: retiring the strip under a live station leaves it unsupported, and its next proof
	refuses."""
	_face_fixture()
	var f: FaceCase.UndergroundFixture = _face._actual
	var cube: PackedInt32Array = PackedInt32Array([FaceCase.X + 1024, FaceCase.FLOOR - 1024, FaceCase.Z,
		FaceCase.X + 2048, FaceCase.FLOOR, FaceCase.Z + 1024])
	_retire_strip_under(cube)
	assert_equal(_refresh_location(f._last), &"LOCATION_COVERAGE_MISSING", "the station over the retired strip")
	assert_equal(_refresh_location(f._first), &"", "its neighbour outside the cube")
