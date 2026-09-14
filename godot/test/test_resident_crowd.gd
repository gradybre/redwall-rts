extends "res://test/framework/test_case.gd"
## Coverage for REQ-SET-163's crowd tier: `scripts/presentation/resident_crowd.gd`.
##
## Four properties are worth more than the rest put together, because each of them can break
## while the crowd still looks entirely healthy:
##
##   1. THE ALPHA IS ACTUALLY USED. A renderer that reads the current pose and ignores the
##      fraction draws every resident in the right PLACE and snaps between ticks. Nothing static
##      catches it, so `test_the_alpha_is_applied_between_the_two_committed_poses` pins three
##      alphas against a midpoint computed here.
##   2. AN INSTANCE CARRIES ITS OWN RESIDENT. Instance `i` must hold the `i`-th LIVE resident,
##      not resident `i`. Every test below that places more than one resident gives each a
##      DIFFERENT coordinate for exactly this reason; equal coordinates would make an off-by-one
##      indistinguishable from correct.
##   3. THE COUNT FOLLOWS THE LIVING. `visible_instance_count` is the only thing standing between
##      512 preallocated instances and 500 ghosts drawn at the world origin.
##   4. DRAWING CHANGES NOTHING. `authoritative_digest()` over the whole Transform store is taken
##      before and after a thousand refreshes at varied alphas and must be identical.
##
## Every expected coordinate is computed in this file from integers restated here, never read
## back out of the module under test.

const ResidentCrowdScript := preload("res://scripts/presentation/resident_crowd.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

## AGENTS.md: "Positions are int32 in 1/1024 m units".
const METRE: int = 1024

## `MultiMesh.buffer` stride for TRANSFORM_3D with no colour and no custom data, restated.
const FLOATS_PER_INSTANCE: int = 12

## GDD §4.1 resident ROW capacity, restated from `entity_directory.gd`'s KIND_CAPACITY.
const ROW_CAPACITY: int = 512

var _residents: ResidentsScript = null
var _transforms: TransformsScript = null
var _crowd: ResidentCrowdScript = null
var _result: IntMathScript.IntResult = null


func before_each() -> void:
	"""Build a resident store, a Transform store over ITS directory, and a fresh crowd node."""
	_residents = ResidentsScript.new()
	_transforms = TransformsScript.new(_residents.directory())
	_crowd = ResidentCrowdScript.new()
	_result = IntMathScript.IntResult.new()


func after_each() -> void:
	"""Free the crowd node; it is a Node and the runner never enters a tree."""
	if _crowd != null:
		_crowd.free()
		_crowd = null
	_residents = null
	_transforms = null
	_result = null


# --- helpers --------------------------------------------------------------------------------------

func _spawn(count: int) -> void:
	"""Spawn `count` adult mice into ascending resident rows."""
	for index: int in count:
		_residents.spawn(&"mouse")


func _place(slot: int, x_metres: int, z_metres: int) -> void:
	"""Place one resident at whole-metre coordinates, previous = current."""
	_transforms.place(_residents.ref_of(slot), x_metres * METRE, 0, z_metres * METRE, 0)


func _refresh(numerator: int, denominator: int) -> bool:
	"""Refresh the crowd at one alpha fraction and return whether it drew."""
	return _crowd.refresh_into(numerator, denominator, _result)


func _bind() -> void:
	"""Bind the crowd to this test's two stores."""
	_crowd.bind_stores(_residents, _transforms)


# --- allocation ------------------------------------------------------------------------------------

func test_the_buffer_is_sized_once_to_the_resident_row_capacity() -> void:
	"""ARCH-MEM-001: one instance per resident ROW, allocated in `_init()` and never resized."""
	assert_equal(ResidentCrowdScript.INSTANCE_CAPACITY, ROW_CAPACITY, "512 instances, one per row")
	assert_equal(_crowd.multimesh.instance_count, ROW_CAPACITY, "the MultiMesh holds all 512")
	assert_equal(_crowd.buffer_bytes(), ROW_CAPACITY * FLOATS_PER_INSTANCE * 4 + ROW_CAPACITY * 4,
		"24576 bytes of instance transforms plus 2048 of instance->slot")


func test_nothing_is_visible_before_the_first_refresh() -> void:
	"""A crowd that has never refreshed draws nobody, rather than 512 residents at the origin."""
	assert_equal(_crowd.visible_instance_count(), 0, "no instance is visible yet")
	assert_equal(_crowd.drawn_count(), 0, "and none has been drawn")


func test_every_instance_starts_with_an_identity_basis_and_no_owner() -> void:
	"""The basis is written once at construction; a refresh only ever touches three origin floats."""
	assert_true(_crowd.instance_basis(0).is_equal_approx(Basis.IDENTITY), "instance 0 is identity")
	assert_true(_crowd.instance_basis(ROW_CAPACITY - 1).is_equal_approx(Basis.IDENTITY),
		"the last instance is identity too")
	_crowd.slot_at_instance(0, _result)
	assert_equal(_result.value, ResidentCrowdScript.NO_SLOT, "instance 0 names no resident yet")


# --- binding ---------------------------------------------------------------------------------------

func test_an_unbound_crowd_refuses_rather_than_drawing_nobody() -> void:
	"""Zero residents drawn and no store to draw from are different answers."""
	assert_false(_crowd.is_bound(), "nothing is bound yet")
	assert_false(_refresh(0, 1000), "an unbound refresh refuses")
	assert_false(_result.ok, "and the result carries the refusal")
	assert_equal(_crowd.last_refusal(), ResidentCrowdScript.REFUSE_NOT_BOUND, "named exactly")


func test_binding_refuses_a_missing_store_rather_than_half_binding() -> void:
	"""Either store absent leaves the crowd unbound; neither is optional."""
	assert_false(_crowd.bind_stores(null, _transforms), "no resident store")
	assert_false(_crowd.bind_stores(_residents, null), "no Transform store")
	assert_false(_crowd.is_bound(), "and the crowd stayed unbound")
	assert_equal(_crowd.last_refusal(), ResidentCrowdScript.REFUSE_NOT_BOUND, "named exactly")


func test_unbinding_stops_drawing_without_touching_a_store() -> void:
	"""`detach` is a presentation operation: the poses it stops reading are still there."""
	_spawn(2)
	_place(0, 10, 20)
	_place(1, 11, 20)
	_bind()
	_refresh(0, 1000)
	var digest: int = _transforms.authoritative_digest()
	_crowd.unbind_stores()
	assert_equal(_crowd.visible_instance_count(), 0, "nothing is drawn once unbound")
	assert_false(_crowd.is_bound(), "and the crowd reports itself unbound")
	assert_equal(_transforms.authoritative_digest(), digest, "every committed pose is untouched")


# --- the alpha -------------------------------------------------------------------------------------

func test_an_alpha_outside_its_own_fraction_is_refused() -> void:
	"""A fraction below 0, above 1, or over a non-positive denominator is refused, never clamped."""
	_spawn(1)
	_place(0, 10, 10)
	_bind()
	assert_false(_refresh(-1, 1000), "a negative numerator")
	assert_equal(_crowd.last_refusal(), ResidentCrowdScript.REFUSE_INVALID_ALPHA, "named exactly")
	assert_false(_refresh(1001, 1000), "a numerator above the denominator")
	assert_false(_refresh(0, 0), "a zero denominator")
	assert_false(_result.ok, "and every one of them refuses through the result")


func test_the_alpha_is_applied_between_the_two_committed_poses() -> void:
	"""THE SNAP TEST. A renderer that ignores the fraction passes every other test in this file."""
	_spawn(1)
	_place(0, 10, 0)
	_transforms.advance(_residents.ref_of(0), 20 * METRE, 0, 0)
	_bind()
	_refresh(0, 1000)
	assert_almost_equal(_crowd.instance_origin(0).x, 10.0, "alpha 0 draws the previous pose")
	_refresh(1000, 1000)
	assert_almost_equal(_crowd.instance_origin(0).x, 20.0, "alpha 1 draws the current pose")
	_refresh(250, 1000)
	assert_almost_equal(_crowd.instance_origin(0).x, 12.5, "alpha 0.25 draws a quarter of the way")
	_refresh(500, 1000)
	assert_almost_equal(_crowd.instance_origin(0).x, 15.0, "alpha 0.5 draws the midpoint")


func test_the_alpha_interpolates_all_three_axes() -> void:
	"""Y and Z are as interpolated as X; a renderer that blends one axis drags bodies sideways."""
	_spawn(1)
	_transforms.place(_residents.ref_of(0), 4 * METRE, 2 * METRE, 8 * METRE, 0)
	_transforms.advance(_residents.ref_of(0), 8 * METRE, 6 * METRE, 16 * METRE)
	_bind()
	_refresh(500, 1000)
	assert_almost_equal(_crowd.instance_origin(0).x, 6.0, "x at the midpoint")
	assert_almost_equal(_crowd.instance_origin(0).y, 4.0, "y at the midpoint")
	assert_almost_equal(_crowd.instance_origin(0).z, 12.0, "z at the midpoint")


# --- one instance per living resident ----------------------------------------------------------------

func test_one_instance_is_drawn_for_each_living_resident() -> void:
	"""The count is the living count, not the row capacity and not the spawned-row count."""
	_spawn(3)
	_place(0, 1, 1)
	_place(1, 2, 1)
	_place(2, 3, 1)
	_bind()
	assert_true(_refresh(0, 1000), "the refresh succeeded")
	assert_equal(_result.value, 3, "three residents drawn")
	assert_equal(_crowd.drawn_count(), 3, "and the crowd agrees")
	assert_equal(_crowd.visible_instance_count(), 3, "and the MultiMesh draws exactly three")


func test_the_instance_count_follows_the_living_count_down() -> void:
	"""A despawned resident stops being drawn on the very next frame."""
	_spawn(3)
	_place(0, 1, 1)
	_place(1, 2, 1)
	_place(2, 3, 1)
	_bind()
	_refresh(0, 1000)
	_residents.despawn(_residents.ref_of(1))
	_refresh(0, 1000)
	assert_equal(_crowd.drawn_count(), 2, "two residents remain")
	assert_equal(_crowd.visible_instance_count(), 2, "and only two instances are drawn")
	assert_equal(_result.value, 2, "reported through the caller's result")


func test_the_instance_count_follows_the_living_count_up() -> void:
	"""A resident that arrives is drawn without the buffer being resized."""
	_spawn(1)
	_place(0, 1, 1)
	_bind()
	_refresh(0, 1000)
	assert_equal(_crowd.drawn_count(), 1, "one to begin with")
	_spawn(1)
	_place(1, 2, 1)
	_refresh(0, 1000)
	assert_equal(_crowd.drawn_count(), 2, "two after the arrival")
	assert_equal(_crowd.multimesh.instance_count, ROW_CAPACITY, "and nothing was reallocated")


func test_a_living_resident_with_no_placed_pose_is_counted_not_drawn() -> void:
	"""An unplaced resident is a blocked composition, not an empty crowd; it is reported."""
	_spawn(3)
	_place(0, 1, 1)
	_place(2, 3, 1)
	_bind()
	_refresh(0, 1000)
	assert_equal(_crowd.drawn_count(), 2, "only the two placed residents are drawn")
	assert_equal(_crowd.skipped_unplaced_count(), 1, "and the unplaced one is counted")


func test_a_dead_but_still_present_resident_is_not_drawn() -> void:
	"""`is_alive` and `is_present` differ for a resident who has died and not been despawned.

	A crowd keyed on presence keeps drawing the dead, and every despawn-based test above passes
	while it does, because a despawn clears both.
	"""
	_spawn(2)
	_place(0, 10, 0)
	_place(1, 20, 0)
	_bind()
	_residents.needs().apply_health_event(1, -100000)
	_refresh(0, 1000)
	assert_true(_residents.is_present(1), "the row is still occupied")
	assert_false(_residents.is_alive(1), "by a resident who has died")
	assert_equal(_crowd.drawn_count(), 1, "and only the living one is drawn")


func test_the_filled_buffer_reaches_the_multimesh_itself() -> void:
	"""Read back through `MultiMesh.buffer`: a crowd that fills a private array draws nothing."""
	_spawn(2)
	_place(0, 10, 20)
	_place(1, 30, 40)
	_bind()
	_refresh(1000, 1000)
	var buffer: PackedFloat32Array = _crowd.multimesh.buffer
	assert_equal(buffer.size(), ROW_CAPACITY * FLOATS_PER_INSTANCE, "the whole buffer was handed over")
	assert_almost_equal(buffer[3], 10.0, "instance 0's x reached the MultiMesh")
	assert_almost_equal(buffer[11], 20.0, "instance 0's z reached the MultiMesh")
	assert_almost_equal(buffer[FLOATS_PER_INSTANCE + 3], 30.0, "instance 1's x too")


# --- an instance carries its own resident -------------------------------------------------------------

func test_each_instance_holds_its_own_residents_pose() -> void:
	"""THE WRONG-ROW TEST. Distinct coordinates, so an off-by-one cannot look like a success."""
	_spawn(3)
	_place(0, 10, 100)
	_place(1, 20, 200)
	_place(2, 30, 300)
	_bind()
	_refresh(1000, 1000)
	assert_almost_equal(_crowd.instance_origin(0).x, 10.0, "instance 0 is resident 0")
	assert_almost_equal(_crowd.instance_origin(1).x, 20.0, "instance 1 is resident 1")
	assert_almost_equal(_crowd.instance_origin(2).x, 30.0, "instance 2 is resident 2")
	assert_almost_equal(_crowd.instance_origin(2).z, 300.0, "and on the other axis too")


func test_instances_compact_over_a_gap_in_the_resident_rows() -> void:
	"""Rows 0 and 2 live, row 1 does not: instance 1 must be resident 2, not an empty row."""
	_spawn(3)
	_place(0, 10, 0)
	_place(2, 30, 0)
	_residents.despawn(_residents.ref_of(1))
	_bind()
	_refresh(1000, 1000)
	assert_equal(_crowd.drawn_count(), 2, "two residents are alive")
	assert_almost_equal(_crowd.instance_origin(0).x, 10.0, "instance 0 is resident row 0")
	assert_almost_equal(_crowd.instance_origin(1).x, 30.0, "instance 1 is resident row 2")
	_crowd.slot_at_instance(1, _result)
	assert_equal(_result.value, 2, "and instance 1 names row 2 explicitly")


func test_the_instance_to_slot_column_records_who_was_drawn() -> void:
	"""A picking path needs to get from an instance back to a resident; this is that column."""
	_spawn(2)
	_place(0, 10, 0)
	_place(1, 20, 0)
	_bind()
	_refresh(0, 1000)
	assert_true(_crowd.slot_at_instance(0, _result), "instance 0 answers")
	assert_equal(_result.value, 0, "with resident row 0")
	assert_true(_crowd.slot_at_instance(1, _result), "instance 1 answers")
	assert_equal(_result.value, 1, "with resident row 1")


func test_an_instance_outside_the_buffer_is_refused_not_answered() -> void:
	"""`does not exist` and `is not drawn` are different facts and share no answer."""
	assert_false(_crowd.slot_at_instance(-1, _result), "below the buffer")
	assert_equal(_result.error, String(ResidentCrowdScript.REFUSE_INVALID_INSTANCE), "named exactly")
	assert_false(_crowd.slot_at_instance(ROW_CAPACITY, _result), "one past the buffer")
	assert_false(_result.ok, "and neither is answered")


# --- facing ------------------------------------------------------------------------------------------

func test_yaw_is_never_turned_into_a_rotation() -> void:
	"""MOVE-G01/G04: the yaw zero-reference and handedness are unauthored, so no basis derives one."""
	_spawn(1)
	_transforms.place(_residents.ref_of(0), 0, 0, 0, TransformsScript.YAW_UNITS_PER_TURN / 4)
	_bind()
	_refresh(1000, 1000)
	assert_true(_crowd.instance_basis(0).is_equal_approx(Basis.IDENTITY),
		"a quarter turn of yaw leaves the drawn basis identity")


# --- drawing changes nothing ----------------------------------------------------------------------------

func test_a_thousand_refreshes_change_no_authoritative_field() -> void:
	"""THE WRITE-BACK TEST. `transforms.gd`: calling this cannot change one authoritative field."""
	_spawn(4)
	for slot: int in 4:
		_place(slot, slot + 1, slot + 2)
		_transforms.advance(_residents.ref_of(slot), (slot + 5) * METRE, 0, (slot + 6) * METRE)
	_bind()
	var before: int = _transforms.authoritative_digest()
	for step: int in 1000:
		_refresh(step % 1001, 1000)
	assert_equal(_transforms.authoritative_digest(), before, "every committed field is unchanged")
	assert_equal(_residents.living_count(), 4, "and no resident was disturbed")


func test_a_thousand_refreshes_move_no_byte_of_any_column() -> void:
	"""The digest above scans BOUND rows only, and a stray write can land on an unbound one.

	`state_bytes()` covers all nine columns at full capacity, so a renderer writing into a row it
	does not own -- which no digest and no per-resident read-back would notice -- is caught here.
	The store is also proved to be the BORROWED one rather than a copy the crowd made.
	"""
	_spawn(4)
	for slot: int in 4:
		_place(slot, slot + 1, slot + 2)
	_bind()
	assert_true(_crowd.transforms() == _transforms, "the crowd borrowed this exact store")
	var before: PackedByteArray = _transforms.state_bytes()
	for step: int in 1000:
		_refresh(step % 1001, 1000)
	assert_equal(_transforms.state_bytes(), before, "and moved not one byte of any column")


func test_an_invisible_view_and_a_drawn_one_commit_the_same_state() -> void:
	"""Two identical stores, one drawn a hundred times and one never, must agree byte for byte."""
	var other_residents: ResidentsScript = ResidentsScript.new()
	var other: TransformsScript = TransformsScript.new(other_residents.directory())
	_spawn(2)
	other_residents.spawn(&"mouse")
	other_residents.spawn(&"mouse")
	for slot: int in 2:
		_place(slot, slot + 3, slot + 4)
		other.place(other_residents.ref_of(slot), (slot + 3) * METRE, 0, (slot + 4) * METRE, 0)
	_bind()
	for step: int in 100:
		_refresh(step * 10, 1000)
	assert_equal(_transforms.authoritative_digest(), other.authoritative_digest(),
		"the drawn store and the undrawn one hold identical committed state")


# --- the mesh ------------------------------------------------------------------------------------------

func test_a_null_crowd_mesh_is_refused() -> void:
	"""A crowd with no mesh occupies no pixels; that is refused rather than silently accepted."""
	assert_false(_crowd.has_crowd_mesh(), "no mesh to begin with")
	assert_false(_crowd.set_crowd_mesh(null), "null is refused")
	assert_equal(_crowd.last_refusal(), ResidentCrowdScript.REFUSE_NO_MESH, "named exactly")


func test_a_mesh_is_adopted_by_the_multimesh_itself() -> void:
	"""The mesh goes onto the MultiMesh, so one draw call covers every instance."""
	var box: BoxMesh = BoxMesh.new()
	assert_true(_crowd.set_crowd_mesh(box), "the mesh is adopted")
	assert_true(_crowd.has_crowd_mesh(), "and the crowd reports it")
	assert_equal(_crowd.multimesh.mesh, box, "on the MultiMesh, not on the node")
