extends "res://test/framework/test_case.gd"
## `demolition_admissions.gd` (decision 0534): the coordinator's per-building admission record and
## the building contact's destination revision, against a standalone directory.

const Admissions := preload("res://scripts/core/demolition_admissions.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const SpatialWorld := preload("res://scripts/core/spatial_world.gd")

const STORE: Vector2i = Vector2i(7, 3)

var _directory: EntityDirectory = null
var _admissions: Admissions = null


func before_each() -> void:
	"""A fresh directory and record."""
	_directory = EntityDirectory.new()
	_admissions = Admissions.new(_directory)


func after_each() -> void:
	"""Drop them."""
	_admissions = null
	_directory = null


func _building() -> Vector2i:
	"""One live BUILDING directory row."""
	return _directory.create(EntityDirectory.KIND_BUILDING)


func _project() -> Vector2i:
	"""One live CONSTRUCTION directory row."""
	return _directory.create(EntityDirectory.KIND_CONSTRUCTION)


func test_a_new_building_publishes_the_first_destination_revision() -> void:
	"""MOVE-DEP-R05: a positive revision; 0 for a ref that names no building."""
	var building: Vector2i = _building()
	assert_equal(_admissions.destination_revision_of(building),
		SpatialWorld.FIRST_DESTINATION_REVISION, "the first revision")
	assert_equal(_admissions.destination_revision_of(Vector2i(900, 1)), 0, "a stale ref has none")
	assert_equal(_admissions.destination_revision_of(_project()), 0, "nor does another kind")


func test_recording_an_admission_advances_the_revision_and_keeps_the_binding() -> void:
	"""One admission: project, store, grams, and revision + 1."""
	var building: Vector2i = _building()
	var project: Vector2i = _project()
	assert_equal(_admissions.record(building, project, STORE, 75000), Admissions.REFUSE_NONE,
		"the admission records")
	assert_equal(_admissions.destination_revision_of(building),
		SpatialWorld.FIRST_DESTINATION_REVISION + 1, "the revision advanced")
	assert_equal(_admissions.project_of(building), project, "the project")
	assert_equal(_admissions.output_container_of(building), STORE, "the store")
	assert_equal(_admissions.output_reserved_g_of(building), 75000, "the grams")


func test_a_live_admission_refuses_a_second_and_a_retired_one_keeps_its_claim() -> void:
	"""ALREADY_ADMITTED while the project lives; once it retires the claim still blocks (review H1).

	A project retired WITHOUT its reservation being released must neither hide the claim nor be
	admitted again over it: the claim stays readable and refuses until `release()`.
	"""
	var building: Vector2i = _building()
	var project: Vector2i = _project()
	assert_equal(_admissions.record(building, project, STORE, 10), Admissions.REFUSE_NONE, "first")
	assert_equal(_admissions.admit_refusal(building), Admissions.REFUSE_ALREADY_ADMITTED, "live")
	var before: PackedByteArray = _admissions.state_bytes()
	assert_equal(_admissions.record(building, _project(), STORE, 10),
		Admissions.REFUSE_ALREADY_ADMITTED, "a second record refuses")
	assert_true(_admissions.state_bytes() == before, "writing nothing")
	assert_true(_directory.destroy(project), "the project retires")
	assert_equal(_admissions.project_of(building), EntityDirectory.NULL_REF, "the project lapses")
	assert_equal(_admissions.output_container_of(building), EntityDirectory.NULL_REF, "binding too")
	assert_equal(_admissions.unreleased_output_of(building), STORE, "but the claim is still named")
	assert_equal(_admissions.unreleased_reserved_g_of(building), 10, "with its grams")
	assert_equal(_admissions.admit_refusal(building), Admissions.REFUSE_RESERVATION_UNRELEASED,
		"and no new admission may reserve over it")
	assert_equal(_admissions.release(building), Admissions.REFUSE_NONE, "the claim is released")
	assert_equal(_admissions.admit_refusal(building), Admissions.REFUSE_NONE, "now a new one may")


func test_release_clears_the_record_advances_the_revision_and_refuses_nothing_to_release() -> void:
	"""`release()` is the cancellation's and D5's door; with no record it refuses by name."""
	var building: Vector2i = _building()
	assert_equal(_admissions.release(building), Admissions.REFUSE_NOTHING_TO_RELEASE, "empty row")
	assert_equal(_admissions.release(Vector2i(900, 1)), Admissions.REFUSE_STALE_BUILDING, "stale")
	assert_equal(_admissions.record(building, _project(), STORE, 10), Admissions.REFUSE_NONE, "ok")
	var revision: int = _admissions.destination_revision_of(building)
	assert_equal(_admissions.release(building), Admissions.REFUSE_NONE, "released")
	assert_equal(_admissions.destination_revision_of(building), revision + 1, "revision advanced")
	assert_equal(_admissions.unreleased_reserved_g_of(building), 0, "no claim recorded")
	assert_equal(_admissions.project_of(building), EntityDirectory.NULL_REF, "no project")


func test_record_refuses_a_stale_building_a_stale_project_and_a_bad_output_shape() -> void:
	"""Each refusal writes nothing."""
	var building: Vector2i = _building()
	var before: PackedByteArray = _admissions.state_bytes()
	assert_equal(_admissions.record(Vector2i(900, 1), _project(), STORE, 1),
		Admissions.REFUSE_STALE_BUILDING, "a stale building")
	assert_equal(_admissions.record(building, Vector2i(900, 1), STORE, 1),
		Admissions.REFUSE_STALE_PROJECT, "a stale project")
	assert_equal(_admissions.record(building, _project(), STORE, 0),
		Admissions.REFUSE_OUTPUT_SHAPE, "a store with no grams")
	assert_equal(_admissions.record(building, _project(), EntityDirectory.NULL_REF, 5),
		Admissions.REFUSE_OUTPUT_SHAPE, "grams with no store")
	assert_equal(_admissions.record(building, _project(), STORE, -1),
		Admissions.REFUSE_OUTPUT_SHAPE, "negative grams")
	assert_true(_admissions.state_bytes() == before, "nothing was written")
	assert_equal(_admissions.record(building, _project(), EntityDirectory.NULL_REF, 0),
		Admissions.REFUSE_NONE, "the ground-pile fallback's null store with 0 g records")


func test_the_revision_refuses_before_it_would_pass_int32() -> void:
	"""The column is I32: admit keeps room for its own release, then refuses rather than wrap."""
	var building: Vector2i = _building()
	var row: int = _directory.get_typed_row(building)
	_admissions._destination_revision[row] = Admissions.INT32_MAX - 2
	assert_equal(_admissions.record(building, _project(), STORE, 1), Admissions.REFUSE_NONE,
		"two below the limit still admits")
	assert_equal(_admissions.release_refusal(building), Admissions.REFUSE_NONE,
		"and its release always has room")
	assert_equal(_admissions.release(building), Admissions.REFUSE_NONE, "released")
	assert_equal(_admissions.destination_revision_of(building), Admissions.INT32_MAX, "to the max")
	assert_equal(_admissions.admit_refusal(building), Admissions.REFUSE_REVISION_EXHAUSTED,
		"and the next admission refuses rather than wrapping")


func test_clear_forgets_every_record_and_restarts_revisions() -> void:
	"""Settlement reset semantics."""
	var building: Vector2i = _building()
	assert_equal(_admissions.record(building, _project(), STORE, 9), Admissions.REFUSE_NONE, "ok")
	_admissions.clear()
	assert_equal(_admissions.project_of(building), EntityDirectory.NULL_REF, "no record")
	assert_equal(_admissions.destination_revision_of(building),
		SpatialWorld.FIRST_DESTINATION_REVISION, "the first revision again")


func test_both_revision_bounds_refuse_at_their_exact_edge() -> void:
	"""Admit refuses at INT32_MAX - 1 (no room for its release); release refuses at INT32_MAX."""
	var building: Vector2i = _building()
	var row: int = _directory.get_typed_row(building)
	_admissions._destination_revision[row] = Admissions.INT32_MAX - 1
	assert_equal(_admissions.admit_refusal(building), Admissions.REFUSE_REVISION_EXHAUSTED,
		"one below the limit leaves no room for the release, so admit refuses")
	_admissions._destination_revision[row] = Admissions.INT32_MAX - 2
	assert_equal(_admissions.record(building, _project(), STORE, 1), Admissions.REFUSE_NONE, "ok")
	_admissions._destination_revision[row] = Admissions.INT32_MAX
	assert_equal(_admissions.release_refusal(building), Admissions.REFUSE_REVISION_EXHAUSTED,
		"a release at the limit refuses instead of wrapping")
	assert_equal(_admissions.release(building), Admissions.REFUSE_REVISION_EXHAUSTED,
		"and so does the release itself")
	assert_equal(_admissions.unreleased_reserved_g_of(building), 1, "keeping the claim recorded")
