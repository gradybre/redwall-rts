extends "res://test/framework/test_case.gd"
## Coverage for `scripts/presentation/resident_pose_scaffold.gd`, the presentation-private stand-in
## for poses the simulation does not hold.
##
## WHAT THIS SUITE IS REALLY GUARDING. The scaffold exists because two things are missing, and the
## danger is that it quietly grows into a third: an unofficial spawn layout that later code starts
## to depend on. So the tests below pin two separable things.
##
##   * THE GEOMETRY IS GDD §5.1's AND §5.9's. Tile pitch 2048, tile centre offset 1024, land
##     elevation 512, hall footprint origin (58,59) and extent 12x10. Every one is restated here
##     as a literal, so a change to `world_init.gd` that moved the hall would fail HERE rather
##     than silently relocating the cohort.
##   * THE ASSIGNMENT IS THIS FILE'S OWN CHOICE and is tested as an ordering property, not as a
##     specification: ascending resident rows fill the block left to right and then southward.
##
## And one invariant that matters however the layout is decided: `place()` writes previous =
## current, so a renderer interpolating a standing resident draws it exactly where it stands and
## never drags it out of the world origin on the first frame.

const ScaffoldScript := preload("res://scripts/presentation/resident_pose_scaffold.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")

## GDD §5.1, restated: "2048*x+1024" tile centres, 1024 units per metre, land surface at y=512.
const TILE_PITCH_UNITS: int = 2048
const TILE_CENTRE_UNITS: int = 1024
const LAND_Y_UNITS: int = 512

## GDD §5.9, restated: "place the hall at (58,59)" with §5.9's 12x10 extent.
const HALL_X: int = 58
const HALL_Z: int = 59
const HALL_SIZE_X: int = 12
const HALL_SIZE_Z: int = 10

## GDD §5.1's twelve-resident starting cohort.
const COHORT: int = 12

var _residents: ResidentsScript = null
var _scaffold: ScaffoldScript = null
var _pose: TransformsScript.Pose = null


func before_each() -> void:
	"""Build a resident store and a scaffold over its directory."""
	_residents = ResidentsScript.new()
	_scaffold = ScaffoldScript.new(_residents)
	_pose = TransformsScript.Pose.new()


func after_each() -> void:
	"""Drop the per-test objects."""
	_residents = null
	_scaffold = null
	_pose = null


func _spawn(count: int) -> void:
	"""Spawn `count` adult mice into ascending resident rows."""
	for index: int in count:
		_residents.spawn(&"mouse")


func _centre_units(tile: int) -> int:
	"""GDD §5.1's tile centre in simulation units, computed here rather than read back."""
	return TILE_PITCH_UNITS * tile + TILE_CENTRE_UNITS


# --- the block's geometry ------------------------------------------------------------------------

func test_the_block_starts_one_tile_south_of_the_authored_hall_footprint() -> void:
	"""§5.9's hall spans z=59..68, so the first apron row south of it is z=69."""
	assert_equal(ScaffoldScript.MUSTER_FIRST_X, HALL_X, "the block shares the hall's west edge")
	assert_equal(ScaffoldScript.MUSTER_FIRST_Z, HALL_Z + HALL_SIZE_Z, "the row just south of it")
	assert_equal(ScaffoldScript.MUSTER_ROW_TILES, HALL_SIZE_X, "and the hall's own width")


func test_the_cohort_fills_exactly_one_row() -> void:
	"""§5.1's twelve and §5.9's twelve-tile hall width are the same number; index 11 is the last."""
	assert_equal(ScaffoldScript.muster_tile_x(0), HALL_X, "the first stands at the west end")
	assert_equal(ScaffoldScript.muster_tile_z(0), HALL_Z + HALL_SIZE_Z, "on the first apron row")
	assert_equal(ScaffoldScript.muster_tile_x(COHORT - 1), HALL_X + HALL_SIZE_X - 1, "the twelfth")
	assert_equal(ScaffoldScript.muster_tile_z(COHORT - 1), HALL_Z + HALL_SIZE_Z, "same row")


func test_the_thirteenth_starts_a_new_row_southward() -> void:
	"""A settlement larger than the starting cohort grows away from the hall, not into it."""
	assert_equal(ScaffoldScript.muster_tile_x(COHORT), HALL_X, "back to the west end")
	assert_equal(ScaffoldScript.muster_tile_z(COHORT), HALL_Z + HALL_SIZE_Z + 1, "one row south")
	assert_equal(ScaffoldScript.muster_tile_z(COHORT * 2), HALL_Z + HALL_SIZE_Z + 2, "and again")


# --- placement -----------------------------------------------------------------------------------

func test_every_living_resident_is_placed() -> void:
	"""The whole cohort, in ascending resident rows."""
	_spawn(COHORT)
	assert_true(_scaffold.place_all(), "the cohort is placed")
	assert_equal(_scaffold.placed_count(), COHORT, "all twelve of them")
	for slot: int in COHORT:
		assert_true(_scaffold.transforms().is_bound(_residents.ref_of(slot)),
			"resident row %d holds a placed pose" % slot)


func test_a_resident_stands_at_its_own_tile_centre_on_land() -> void:
	"""GDD §5.1's `2048*x+1024` centre and its 512-unit land surface, computed independently."""
	_spawn(COHORT)
	_scaffold.place_all()
	_scaffold.transforms().read_into(_residents.ref_of(0), _pose)
	assert_equal(_pose.x, _centre_units(HALL_X), "the first resident's x")
	assert_equal(_pose.z, _centre_units(HALL_Z + HALL_SIZE_Z), "its z")
	assert_equal(_pose.y, LAND_Y_UNITS, "standing on §5.1's land surface")
	_scaffold.transforms().read_into(_residents.ref_of(COHORT - 1), _pose)
	assert_equal(_pose.x, _centre_units(HALL_X + HALL_SIZE_X - 1), "and the twelfth's x")


func test_a_placed_resident_has_no_history_to_interpolate_out_of() -> void:
	"""`place()` writes previous = current, so the first drawn frame is not a slide from nowhere."""
	_spawn(3)
	_scaffold.place_all()
	for slot: int in 3:
		_scaffold.transforms().read_into(_residents.ref_of(slot), _pose)
		assert_true(_pose.matches_previous(), "row %d has previous = current" % slot)


func test_no_facing_is_asserted() -> void:
	"""Yaw stays at the column's own empty value; MOVE-G01/G04 have not settled what a facing is."""
	_spawn(1)
	_scaffold.place_all()
	_scaffold.transforms().read_into(_residents.ref_of(0), _pose)
	assert_equal(_pose.yaw, 0, "yaw is untouched")
	assert_equal(_pose.prev_yaw, 0, "on both frames")


func test_an_empty_settlement_places_nobody_and_still_succeeds() -> void:
	"""Zero living residents is a real answer; it is not a refusal."""
	assert_true(_scaffold.place_all(), "an empty cohort is placed successfully")
	assert_equal(_scaffold.placed_count(), 0, "with nobody in it")


func test_a_dead_resident_is_not_placed() -> void:
	"""Only the living occupy the block; a despawned row keeps no pose of its own."""
	_spawn(3)
	_residents.despawn(_residents.ref_of(1))
	assert_true(_scaffold.place_all(), "the survivors are placed")
	assert_equal(_scaffold.placed_count(), 2, "two of the three")
	_scaffold.transforms().read_into(_residents.ref_of(2), _pose)
	assert_equal(_pose.x, _centre_units(HALL_X + 1), "row 2 took the SECOND tile, not the third")


# --- refusal --------------------------------------------------------------------------------------

func test_a_scaffold_without_a_resident_store_refuses() -> void:
	"""No store means no directory to derive Transform rows from; that refuses, it does not crash."""
	var empty: ScaffoldScript = ScaffoldScript.new(null)
	assert_false(empty.is_ready(), "the scaffold is not ready")
	assert_null(empty.transforms(), "and owns no Transform store")
	assert_false(empty.place_all(), "placing refuses")
	assert_equal(empty.last_refusal(), ScaffoldScript.REFUSE_NO_RESIDENTS, "named exactly")


func test_the_scaffold_shares_the_settlements_directory() -> void:
	"""A private directory would derive rows for entities that do not exist. Only poses are private."""
	assert_true(_scaffold.is_ready(), "the scaffold is ready")
	_spawn(1)
	_scaffold.place_all()
	assert_true(_scaffold.transforms().is_bound(_residents.ref_of(0)),
		"a reference minted by the resident store resolves in the scaffold's Transform store")
