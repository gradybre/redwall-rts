extends "res://test/framework/test_case.gd"
## Actual surface and underground Room identities; no service or geometry grant is inferred.

const Buildings := preload("res://scripts/core/buildings.gd")
const SpatialFixture := preload("res://test/test_buildings_spatial.gd")
const SurfaceFixture := preload("res://test/test_buildings.gd")

var _spatial: SpatialFixture = null


func before_each() -> void:
	"""Use a real store with an explicitly scoped synthetic registration authority only."""
	_spatial = SpatialFixture.new()
	_spatial.before_each()
	assert_true(_spatial.failures.is_empty(), "actual spatial store initialized")


func after_each() -> void:
	"""Release only this test's fixture and observe any nested fixture assertion failures."""
	assert_true(_spatial.failures.is_empty(), "actual registration and teardown assertions passed")
	_spatial.after_each()
	_spatial = null


func _output() -> PackedInt32Array:
	"""Distinct sentinel values make every refused output modification observable."""
	return PackedInt32Array([31, 32, 33, 34, 35, 36])


func test_underground_identity_has_permanent_purpose_without_tile_or_service_claim() -> void:
	"""An unfurnished, unfinished Kitchen is already a Kitchen, with no exterior Building or flat tile area."""
	var room: Vector2i = _spatial._room(Buildings.ROOM_TYPE_KITCHEN)
	var before: PackedByteArray = _spatial._image()
	var out: PackedInt32Array = _output()
	assert_equal(_spatial._store.room_identity_into(room, out), &"", "actual registered Room")
	assert_equal(out, PackedInt32Array([1, 2, -1, 0, 0, 0]), "underground Kitchen identity only")
	assert_false(_spatial._store.room_is_valid(room), "identity never grants a furnished service")
	assert_equal(_spatial._image(), before, "all actual store and Directory bytes preserved")


func test_surface_identity_keeps_full_parent_and_real_tile_links() -> void:
	"""GDD's starter hall still owns its four exact Room extents; underground has not replaced the surface model."""
	var surface: SurfaceFixture = SurfaceFixture.new()
	surface.before_each()
	surface._place_hall()
	surface._designate_starter_rooms()
	assert_true(surface.failures.is_empty(), "actual authored starter fixture")
	var out: PackedInt32Array = _output()
	assert_equal(surface._store.room_identity_into(surface._dormitory, out), &"", "live surface Dormitory")
	assert_equal(out, PackedInt32Array([0, 0, surface._hall.x, surface._hall.y, 0, 40]), "full parent and 40 actual links")
	assert_equal(surface._store.room_identity_into(surface._kitchen, out), &"", "live surface Kitchen")
	assert_equal(out, PackedInt32Array([0, 2, surface._hall.x, surface._hall.y, 40, 10]), "next 10 actual links")
	surface._store = null
	surface = null


func test_refused_output_sizes_preserve_the_original_caller_array() -> void:
	"""No resize or partial write may escape a wrong caller contract."""
	var room: Vector2i = _spatial._room()
	for size: int in [0, 5, 7]:
		var out: PackedInt32Array = PackedInt32Array()
		out.resize(size)
		out.fill(83)
		var before: PackedInt32Array = out.duplicate()
		assert_equal(_spatial._store.room_identity_into(room, out), &"ROOM_IDENTITY_OUTPUT", "exact fixed shape")
		assert_equal(out, before, "refusal preserves size and contents")


func test_retired_generation_and_reused_slot_never_return_previous_identity() -> void:
	"""A reused local row or global slot cannot revive the removed Room's purpose."""
	var old: Vector2i = _spatial._room(Buildings.ROOM_TYPE_KITCHEN)
	_spatial._remove_room(old)
	var replacement: Vector2i = _spatial._room(Buildings.ROOM_TYPE_DORMITORY)
	assert_true(replacement != old, "new full identity")
	var out: PackedInt32Array = _output()
	assert_equal(_spatial._store.room_identity_into(old, out), Buildings.REFUSE_STALE_ROOM_REF, "retired generation")
	assert_equal(out, _output(), "stale output untouched")
	assert_equal(_spatial._store.room_identity_into(replacement, out), &"", "actual replacement")
	assert_equal(out, PackedInt32Array([1, 0, -1, 0, 0, 0]), "new Room has its own purpose")


func test_wrong_kind_and_invalid_room_fields_preserve_previous_output() -> void:
	"""The fixed reader rejects corrupt domain/purpose instead of publishing an unknown gameplay namespace."""
	var room: Vector2i = _spatial._room(Buildings.ROOM_TYPE_KITCHEN)
	var row: int = _spatial._store.directory().get_typed_row(room)
	var out: PackedInt32Array = _output()
	_spatial._store._r_spatial_kind[row] = 255
	assert_equal(_spatial._store.room_identity_into(room, out), Buildings.REFUSE_SPATIAL_KIND, "unknown spatial domain")
	assert_equal(out, _output(), "domain failure preserves output")
	_spatial._store._r_spatial_kind[row] = Buildings.ROOM_SPACE_UNDERGROUND
	_spatial._store._r_type[row] = Buildings.ROOM_TYPE_COUNT
	assert_equal(_spatial._store.room_identity_into(room, out), Buildings.REFUSE_UNKNOWN_ROOM_TYPE, "unknown purpose")
	assert_equal(out, _output(), "purpose failure preserves output")
	_spatial._store._r_type[row] = Buildings.ROOM_TYPE_KITCHEN
	assert_equal(_spatial._store.room_identity_into(Vector2i(-1, 0), out), Buildings.REFUSE_STALE_ROOM_REF, "null identity")
	assert_equal(out, _output(), "null failure preserves output")
	var wrong_kind: Vector2i = _spatial._store.directory().create(SpatialFixture.Directory.KIND_RESIDENT)
	assert_true(_spatial._store.directory().is_valid(wrong_kind), "actual live identity of another kind")
	assert_equal(_spatial._store.room_identity_into(wrong_kind, out), Buildings.REFUSE_STALE_ROOM_REF, "live wrong kind")
	assert_equal(out, _output(), "wrong-kind failure preserves output")
