extends "res://test/framework/test_case.gd"
## Decision 2044: the measured M5 fixes in the entry's work area and confirmation, at their pure arithmetic: the cube
## index key (it overflowed 64 bits, so every lookup missed), terrain windows charged by the tiles they read, the
## per-row station footing (the SurfaceAnchor refresh was quadratic over one shared strip) and the cut-station batches
## (an installation requalified sixteen paths to stations whose cuts were done).

const Bindings := preload("res://scripts/core/underground_entry_bindings.gd")
const WorkArea := preload("res://scripts/core/underground_entry_work_area.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const World := preload("res://scripts/core/world_init.gd")
const Installer := preload("res://scripts/core/underground_entry_installer.gd")
const Progress := preload("res://scripts/core/underground_entry_progress.gd")
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


func test_the_work_area_cuts_the_flights_rows() -> void:
	"""The literal CUT_ROWS is the tread geometry's ROWS, and the endpoint count follows it (decision 2044)."""
	assert_equal(WorkArea.CUT_ROWS, Tread.ROWS, "the flight's cube rows")
	assert_equal(WorkArea.ENDPOINTS, WorkArea.FIRST_DEEP_STATION + 2 * (WorkArea.CUT_ROWS - 3), "a pair a row from row 3")


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


func test_region_scans_visit_present_rows_only() -> void:
	"""Decision 2044 (P-2044-15, exact cost fixes): the bindings' region scans step from one present row to the next,
	in the staged bank or the live one, and end at the capacity."""
	var bank: Owner = Owner.new(null) # Only the Region presence banks `_next_region_row` reads.
	bank._region_capacity = 9
	bank._s_r_present = PackedByteArray([0, 0, 1, 1, 0, 0, 0, 1, 0])
	bank._r_present = PackedByteArray([1, 0, 0, 0, 0, 0, 0, 0, 1])
	for staged: bool in [true, false]:
		var seen: Array[int] = []
		var row: int = Bindings._next_region_row(bank, 0, staged)
		while row < bank._region_capacity:
			seen.append(row)
			row = Bindings._next_region_row(bank, row + 1, staged)
		assert_equal(seen, [2, 3, 7] if staged else [0, 8], "present rows of the %s bank" % ("staged" if staged else "live"))
	assert_equal(Bindings._next_region_row(bank, 9, true), 9, "past the end")


func test_prisms_are_ordered_by_their_tops_for_the_height_search() -> void:
	"""Decision 2044 (P-2044-15): `_order_prisms` keys each prism by its biased top and its index (signed keys already
	order a negative top first; the bias keeps every key non-negative), the rest of the table sorts last, and it costs
	sixteen checks a prism."""
	var locations: Locations = Locations.new()
	locations._prism_boxes.resize(6 * 4)
	locations._prism_tops.resize(4)
	for prism: int in 3: locations._prism_boxes[prism * 6 + 4] = [100, -924, 100][prism]
	locations._remaining = 48
	assert_true(locations._order_prisms(3), "three prisms ordered within 48 checks")
	assert_equal(locations._remaining, 0, "sixteen checks a prism")
	var tops: Array = []
	for at: int in 3: tops.append([(locations._prism_tops[at] >> 16) - Locations.TOP_BIAS, locations._prism_tops[at] & 0xFFFF])
	assert_equal(tops, [[-924, 1], [100, 0], [100, 2]], "lowest top first; equal tops by index")
	assert_equal(locations._prism_tops[3], 0x7FFFFFFFFFFFFFFF, "the unused slot sorts last")
	assert_equal(locations._prism_tops.bsearch((100 + Locations.TOP_BIAS) << 16), 1, "a height finds its first prism")
	locations._remaining = 47
	assert_false(locations._order_prisms(3), "refused without the whole charge")


func test_the_installers_progress_marker_fits_its_saved_field_and_tells_legs_apart() -> void:
	"""Decision 2045: the marker counts the installer's stage and stair leg and its haul's leg, stage and trips, so a long
	climb through the landings is progress at every leg; it is saved as the foreman's `_last_install_stage`, a signed
	32-bit field, so its largest value still fits. The leg fields cover every saved list (the review's H3: a 56-leg
	climb must not freeze the marker past leg 31)."""
	assert_true(Progress.MAX_STAIR_LEGS <= 64 and Progress.MAX_HAUL_LEGS <= 128, "the leg fields cover the saved lists")
	assert_equal(Installer.marker_of(15, 63, 127, 7, 1023), 1073741823, "the largest marker fits the field")
	assert_equal(Installer.marker_of(99, 99, 999, 99, 99999), 1073741823, "every part is clamped to its width")
	var seen: Dictionary = {}
	for stage: int in [0, 10, 15]:
		for stair: int in [0, 31, 32, 55]:
			for leg: int in [0, 31, 32, 56]:
				for haul: int in [0, 6]:
					for trips: int in [0, 1, 9]:
						seen[Installer.marker_of(stage, stair, leg, haul, trips)] = true
	assert_equal(seen.size(), 3 * 4 * 4 * 2 * 3, "each part changes the marker, past leg 31 too")
