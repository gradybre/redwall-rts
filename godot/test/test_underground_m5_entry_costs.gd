extends "res://test/framework/test_case.gd"
## Decision 2044: the measured M5 fixes in the entry's work area and confirmation, at their pure arithmetic: the cube
## index key (it overflowed 64 bits, so every lookup missed), terrain windows charged by the tiles they read, the
## per-row station footing (the SurfaceAnchor refresh was quadratic over one shared strip) and the cut-station batches
## (an installation requalified sixteen paths to stations whose cuts were done).

const Bindings := preload("res://scripts/core/underground_entry_bindings.gd")
const WorkArea := preload("res://scripts/core/underground_entry_work_area.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const World := preload("res://scripts/core/world_init.gd")
const DATUM: Vector3i = Vector3i(0, 512, 0)
const ORIGIN: Vector3i = Vector3i(122880, 512, 102400)


func test_cube_keys_survive_the_mask_shift_across_the_domain() -> void:
	"""A key shifted left by the three mask bits and back is unchanged, at the Domain's far corners too: the old 21-bit
	fields put the x field at bit 62, so `key << 3` lost it and no indexed cube was ever found."""
	for corner: Vector3i in [Vector3i(0, -32 * 1024, 0), Vector3i(255 * 1024, 15 * 1024, 255 * 1024),
			Vector3i(122880, -4608, 74752), Vector3i(-1024, -40 * 1024, -1024)]:
		var key: int = Bindings._cube_key(corner + DATUM, DATUM)
		assert_true(key > 0, "positive key at %s" % corner)
		assert_equal(((key << 3) | 7) >> 3, key, "the mask shift keeps the key at %s" % corner)


func test_cube_keys_name_cubes_not_points() -> void:
	"""Every point of one cube shares its key; neighbours on each axis differ and sort in lattice order."""
	var cube: Vector3i = Vector3i(121856, -4608, 74752)
	var key: int = Bindings._cube_key(cube, DATUM)
	assert_equal(Bindings._cube_key(cube + Vector3i(1023, 1023, 1023), DATUM), key, "the far corner")
	for axis: int in 3:
		var step: Vector3i = Vector3i.ZERO
		step[axis] = 1024
		assert_true(Bindings._cube_key(cube + step, DATUM) > key, "next cube on axis %d sorts after" % axis)
		assert_true(Bindings._cube_key(cube - step, DATUM) < key, "previous cube on axis %d sorts before" % axis)
	assert_true(Bindings._cube_key(cube + Vector3i(0, 0, 1024 * 300), DATUM)
		< Bindings._cube_key(cube + Vector3i(0, 1024, 0), DATUM), "z never carries into y")


func test_a_terrain_window_is_charged_by_the_tiles_it_reads() -> void:
	"""Sixteen checks a tile plus one, so a full 8x8 window costs LOCAL_QUERY_CHECKS and one tile seventeen."""
	var tile: int = World.TILE_SIZE_UNITS
	assert_equal(Bindings._entry_window_checks(PackedInt32Array([10, 0, 10, 138, 128, 138])), 17, "a 128 u bearing")
	assert_equal(Bindings._entry_window_checks(PackedInt32Array([tile - 1, 0, 0, tile + 1, 1, 1])), 33, "two tiles")
	assert_equal(Bindings._entry_window_checks(PackedInt32Array([0, 0, 0, 8 * tile, 1, 8 * tile])),
		Terrain.LOCAL_QUERY_CHECKS, "a whole window is the old flat charge")
	assert_equal(Bindings.TERRAIN_TILE_CHECKS * Terrain.LOCAL_TILE_LIMIT + 1, Terrain.LOCAL_QUERY_CHECKS,
		"the per-tile share is exact")


func test_cut_stations_after_the_first_pair_stand_on_their_own_rows() -> void:
	"""The first pair keeps the full outer strip; every later cut station's footing is its row's slice of the same
	strip, holding its root, so no two later stations on one side share footing."""
	for index: int in [3, 4]:
		var full: PackedInt32Array = WorkArea.foot(ORIGIN, index)
		assert_equal(full[2], ORIGIN.z - 1024 * (WorkArea.CUT_ROWS + 1), "station %d's strip reaches past row 26" % index)
	for index: int in range(5, WorkArea.ENDPOINTS):
		if index == WorkArea.STAND_M or index == WorkArea.STAND_R: continue
		var at: Vector3i = WorkArea.point(ORIGIN, index)
		var box: PackedInt32Array = WorkArea.foot(ORIGIN, index)
		assert_equal([box[2], box[5]], [at.z - 512, at.z + 512], "station %d's row slice" % index)
		assert_true(Locations.support_covers_root(at, box), "station %d stands on its slice" % index)
		var strip: Array[int] = WorkArea.LEFT_FOOT if at.x < ORIGIN.x else WorkArea.RIGHT_FOOT
		assert_equal([box[0], box[3]], [strip[0] + ORIGIN.x, strip[3] + ORIGIN.x], "station %d keeps the strip's x" % index)
		if index + 2 < WorkArea.ENDPOINTS and index + 2 != WorkArea.STAND_M and index + 2 != WorkArea.STAND_R \
				and index != 7 and index != 8:
			assert_true(WorkArea.foot(ORIGIN, index + 2)[5] <= box[2], "station %d's next row does not overlap" % index)


func test_the_cut_stations_fall_into_disjoint_batches() -> void:
	"""Batch 0 is stage 0's four, batch 1 stage 1's pair, batch 2 ADR1229's DEEP_WORK, then eights to the last
	station; together they hold every cut station once, and the work area publishes only H and batch 0."""
	assert_equal(WorkArea.batch_stations(0), [3, 4, 5, 6], "stage 0's stations")
	assert_equal(WorkArea.batch_stations(1), [7, 8], "stage 1's pair")
	assert_equal(WorkArea.batch_stations(2), WorkArea.DEEP_WORK, "the descent's first eight")
	var seen: Array[int] = []
	for batch: int in WorkArea.BATCHES:
		for index: int in WorkArea.batch_stations(batch):
			assert_false(index in seen, "station %d in one batch only" % index)
			seen.append(index)
	seen.sort()
	var expected: Array[int] = [3, 4, 5, 6, 7, 8]
	for index: int in range(WorkArea.FIRST_DEEP_STATION, WorkArea.ENDPOINTS): expected.append(index)
	assert_equal(seen, expected, "every cut station")
	assert_equal(WorkArea.WORK, [0, 3, 4, 5, 6], "published with the work area")


func test_batch_of_reads_the_published_handles() -> void:
	"""A handle's batch is the batch of its work-area index; H, the storages and the stands are in none."""
	var published: WorkArea.Published = WorkArea.Published.new()
	for index: int in WorkArea.ENDPOINTS: published.endpoints.append(Vector2i(100 + index, 1))
	assert_equal(WorkArea.batch_of(published, Vector2i(105, 1)), 0, "station 5")
	assert_equal(WorkArea.batch_of(published, Vector2i(108, 1)), 1, "station 8")
	assert_equal(WorkArea.batch_of(published, Vector2i(111, 1)), 2, "station 11")
	assert_equal(WorkArea.batch_of(published, Vector2i(100 + WorkArea.ENDPOINTS - 1, 1)), WorkArea.BATCHES - 1,
		"the last station")
	for index: int in [0, 1, 2, WorkArea.STAND_M, WorkArea.STAND_R]:
		assert_equal(WorkArea.batch_of(published, Vector2i(100 + index, 1)), -1, "endpoint %d is in no batch" % index)
	assert_equal(WorkArea.batch_of(published, Vector2i(105, 2)), -1, "a stale generation")
