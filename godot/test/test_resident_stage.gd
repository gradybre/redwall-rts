extends "res://test/framework/test_case.gd"
## Coverage for `scripts/presentation/resident_stage.gd`: the alpha derivation and the attachment.
##
## WHY `_ready()` IS CALLED BY HAND, and why this stage is built rather than loaded from
## `main.tscn`: the headless runner is a SceneTree `_initialize()`, so `SceneTree.root` is not
## itself inside the tree and NOTIFICATION_READY never fires for anything added to it.
## `test_hud.gd` records the same property. Building the two nodes here also keeps this suite off
## the boot scene, which resets three autoloads.
##
## THE ALPHA IS THE SHARP PART. `sim_clock.gd` charges `TICK_COST` = 1000000 debt units per tick
## and leaves the remainder; that remainder is the renderer's position between the last two
## committed ticks. Getting it wrong is invisible on a still frame and shows up only as motion
## that snaps or that runs a tick behind, so every expected value below is computed from 1000000
## restated here rather than read back out of the module.

const ResidentStageScript := preload("res://scripts/presentation/resident_stage.gd")
const ResidentCrowdScript := preload("res://scripts/presentation/resident_crowd.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")

## An explicit, valid pose for the fixtures below. INIT-POSE-R01 §4: a generic rendering test
## supplies its own transforms rather than invoking a production placement algorithm for an
## arbitrary population, so nothing here can be read as an authored spawn position.
const FIXTURE_X_UNITS: int = 4096
const FIXTURE_Y_UNITS: int = 512
const FIXTURE_Z_UNITS: int = 8192
const FIXTURE_X_STEP_UNITS: int = 2048

## `sim_clock.gd`'s `TICK_COST`, restated: "one tick costs 1000000 debt units".
const TICK_COST: int = 1000000

## GDD §5.1's twelve-resident starting cohort.
const COHORT: int = 12

var _stage: ResidentStageScript = null
var _residents: ResidentsScript = null
var _transforms: TransformsScript = null


func before_each() -> void:
	"""Build a stage with its crowd child and run the ready hook by hand. See the header."""
	_stage = ResidentStageScript.new()
	var crowd: ResidentCrowdScript = ResidentCrowdScript.new()
	crowd.name = "ResidentCrowd"
	_stage.add_child(crowd)
	_stage._ready()
	_residents = ResidentsScript.new()
	_transforms = TransformsScript.new(_residents.directory())


func after_each() -> void:
	"""Free the stage and the crowd child with it."""
	if _stage != null:
		_stage.free()
		_stage = null
	_residents = null
	_transforms = null


func _spawn(count: int) -> void:
	"""Spawn `count` adult mice into ascending resident rows and place each at its own pose.

	Each gets a DIFFERENT x, so an instance drawing the wrong resident is visible rather than
	hidden behind twelve identical coordinates.
	"""
	for index: int in count:
		var spawned: ResidentsScript.OpResult = _residents.spawn(&"mouse")
		assert_true(spawned.ok, "the fixture resident spawned")
		assert_true(_transforms.place(spawned.ref,
			FIXTURE_X_UNITS + FIXTURE_X_STEP_UNITS * index, FIXTURE_Y_UNITS, FIXTURE_Z_UNITS, 0),
			"and the fixture placed it at an explicit pose")


# --- the alpha ---------------------------------------------------------------------------------

func test_no_debt_draws_the_committed_tick_exactly() -> void:
	"""A paused game holds no sub-tick debt, so the frame is the last committed pose and not a blend."""
	assert_equal(ResidentStageScript.alpha_numerator_of(0), 0, "no debt is alpha zero")


func test_part_of_a_tick_is_that_part_of_the_way() -> void:
	"""Half a tick's debt is half the numerator; quarter is a quarter. No rounding, no scaling."""
	assert_equal(ResidentStageScript.alpha_numerator_of(TICK_COST / 2), 500000, "half a tick")
	assert_equal(ResidentStageScript.alpha_numerator_of(TICK_COST / 4), 250000, "a quarter")
	assert_equal(ResidentStageScript.alpha_numerator_of(1), 1, "one debt unit")
	assert_equal(ResidentStageScript.alpha_numerator_of(TICK_COST - 1), 999999, "one short of a tick")


func test_whole_owed_ticks_fall_out_of_the_numerator() -> void:
	"""An overloaded frame owes whole ticks; only the remainder is a position between two of them."""
	assert_equal(ResidentStageScript.alpha_numerator_of(TICK_COST), 0, "exactly one tick owed")
	assert_equal(ResidentStageScript.alpha_numerator_of(TICK_COST * 3 + 250000), 250000,
		"three whole ticks and a quarter is still a quarter of the way")


func test_a_numerator_can_never_be_negative() -> void:
	"""`transforms.gd` refuses a negative numerator; a whole frame must not be lost to one."""
	assert_equal(ResidentStageScript.alpha_numerator_of(-1), 0, "clamped, not passed on")


# --- attachment ---------------------------------------------------------------------------------

func test_a_stage_draws_nothing_until_it_is_attached() -> void:
	"""`main.gd` attaches after the settlement exists; before that there is nobody to draw."""
	assert_false(_stage.is_attached(), "nothing is attached yet")
	assert_equal(_stage.drawn_count(), 0, "and nothing is drawn")
	assert_equal(_stage.mesh_source(), ResidentStageScript.MESH_SOURCE_NONE, "no mesh resolved yet")


func test_attaching_without_a_resident_store_refuses() -> void:
	"""An unbound crowd and an empty settlement draw the same ground; only one is a defect."""
	assert_false(_stage.attach(null, _transforms), "attaching to nothing refuses")
	assert_equal(_stage.last_refusal(), ResidentStageScript.REFUSE_NO_RESIDENTS, "named exactly")
	assert_false(_stage.is_attached(), "and the stage stays detached")


func test_attaching_without_a_pose_store_refuses_instead_of_building_one() -> void:
	"""INIT-POSE-R01 §2: the settlement owns the Transform store and the renderer borrows it.

	A stage handed no store must REFUSE. The alternative -- constructing its own -- is the
	3151872-byte presentation-private duplicate this work exists to delete.
	"""
	_residents.spawn(&"mouse")
	assert_false(_stage.attach(_residents, null), "attaching without a pose store refuses")
	assert_equal(_stage.last_refusal(), ResidentStageScript.REFUSE_NO_TRANSFORMS, "named exactly")
	assert_false(_stage.is_attached(), "and the stage stays detached")
	assert_null(_stage.transforms(), "holding no pose store of any kind")


func test_attaching_borrows_the_exact_store_it_was_handed() -> void:
	"""Identity, not equality: the renderer must read the settlement's own object.

	Two stores that happen to agree today are two authorities tomorrow, so this asserts the same
	instance reaches both the stage and the crowd rather than comparing coordinates.
	"""
	_spawn(COHORT)
	assert_true(_stage.attach(_residents, _transforms), "the stage attached")
	assert_true(_stage.is_attached(), "and reports itself attached")
	assert_true(_stage.transforms() == _transforms, "the stage holds the store it was handed")
	assert_true(_stage.crowd().transforms() == _transforms, "and so does the crowd")
	assert_true(_stage.crowd().is_bound(), "which is bound and ready to draw")


func test_the_authored_crowd_mesh_is_the_one_that_ships() -> void:
	"""The shipped GLB, not the fallback box. A capture must never be read as the wrong asset."""
	_spawn(1)
	_stage.attach(_residents, _transforms)
	assert_equal(_stage.mesh_source(), ResidentStageScript.MESH_SOURCE_GLB,
		"species_mouse_body_a_lod0.glb is what the crowd draws")
	assert_true(_stage.crowd().has_crowd_mesh(), "and the MultiMesh holds it")


func test_a_frame_draws_one_instance_per_living_resident() -> void:
	"""End to end through the stage's own per-frame entry point."""
	_spawn(COHORT)
	_stage.attach(_residents, _transforms)
	_stage._process(0.0)
	assert_equal(_stage.drawn_count(), COHORT, "twelve residents drawn")
	assert_equal(_stage.crowd().visible_instance_count(), COHORT, "and twelve instances visible")
	assert_equal(_stage.crowd().skipped_unplaced_count(), 0, "none of them unplaced")


func test_a_frame_before_attachment_draws_nothing_and_does_not_refuse() -> void:
	"""`_process` runs on every frame from `_ready()`; an unattached one is a no-op, not an error."""
	_stage._process(0.0)
	assert_equal(_stage.drawn_count(), 0, "nothing drawn")
	assert_equal(_stage.crowd().last_refusal(), ResidentCrowdScript.REFUSE_NONE,
		"and the crowd was never asked to refuse")


func test_detaching_stops_drawing_and_drops_the_borrowed_store() -> void:
	"""A scene reload must not leave the crowd holding the previous run's residents.

	Dropping the reference must not touch the store: the settlement outlives the scene, so a
	detach that cleared a pose would erase authoritative state a reload then reads back.
	"""
	_spawn(COHORT)
	_stage.attach(_residents, _transforms)
	_stage._process(0.0)
	var before: PackedByteArray = _transforms.state_bytes()
	_stage.detach()
	assert_false(_stage.is_attached(), "the stage is detached")
	assert_null(_stage.transforms(), "the borrowed store is dropped")
	assert_equal(_stage.crowd().visible_instance_count(), 0, "and nothing is drawn")
	assert_equal(_transforms.state_bytes(), before, "the settlement's poses are byte-identical")


func test_the_fallback_box_is_anchored_on_the_one_metre_mouse() -> void:
	"""Crowd doc §9.1's scale anchor, restated: 1.0 m, deliberately not biological."""
	assert_equal(ResidentStageScript.MOUSE_ANCHOR_HEIGHT_M, 1.0, "the anchor is one metre")
	assert_equal(ResidentStageScript.FALLBACK_BOX_SIZE.y, 1.0, "and the fallback box matches it")
