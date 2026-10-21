extends "res://test/framework/test_case.gd"
## Decision 2052 §2.3 (slice D2 phase 1): the build panel's readers of the real way down. The foot and the standing
## shape follow from the entry origin and the flight's own geometry, and equal D1's Stair-head at that anchor.

const Landings := preload("res://scripts/core/underground_way_landings.gd")
const Flight := preload("res://data/underground/full-level-flight-v1/flight_geometry.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
## The chain fixture's entry origin (`underground_entry_chain.gd` NEAR, snapped to the cube grid) and a zero datum.
const ORIGIN: Vector3i = Vector3i(122880, 512, 102400)
const DATUM: Vector3i = Vector3i.ZERO


func test_m5_reaches_level_1_and_m2_does_not() -> void:
	"""M5's last row is one whole level down; M2's interim floor (2,048 u) reaches no level; no layout reaches none."""
	assert_true(Landings.reaches_level(Flight.LAYOUT_M5), "M5")
	assert_false(Landings.reaches_level(Flight.LAYOUT_M2), "M2 interim")
	assert_false(Landings.reaches_level(-1), "no layout")


func test_the_flight_and_d1s_stair_head_have_the_same_rows() -> void:
	"""The panel's Stair-head row count and width are the flight's (a drift between the two is caught here)."""
	assert_equal(Flight.layout_row_count(Flight.LAYOUT_M5), Families.ALONG[Families.EARTH_TIMBER], "27 rows")
	assert_equal(Flight.WIDTH_CUBES, Families.ACROSS[Families.EARTH_TIMBER], "2 cells across")
	assert_equal(Landings.CELL_U, Families.QUANTUM_U, "1 m cells")


func test_the_anchor_is_the_last_rows_west_cell() -> void:
	"""The slot's west cell (origin x - 1024) on row 26 (z from origin - 27,648)."""
	var anchor: Vector2i = Landings.anchor_of(Flight.LAYOUT_M5, ORIGIN, DATUM)
	assert_equal(anchor, Vector2i(119, 73), "north-west cell: (122,880 - 1,024) / 1,024 and (102,400 - 27,648) / 1,024")


func test_the_foot_on_level_1_is_d1s_stair_head_landing() -> void:
	"""The landing cells equal `build_connector_families.gd`'s for a Stair-head at turn 0 at the derived anchor."""
	var anchor: Vector2i = Landings.anchor_of(Flight.LAYOUT_M5, ORIGIN, DATUM)
	var out: PackedInt32Array = PackedInt32Array()
	assert_true(Landings.landings_into(Flight.LAYOUT_M5, 1, ORIGIN, DATUM, out), "level 1")
	assert_equal(out, Families.landing_cells(Families.EARTH_TIMBER, 0, anchor), "D1's landing")
	assert_equal(out.size(), 4, "two cells")


func test_no_landing_on_other_levels_or_for_m2() -> void:
	"""Only level 1, and only a layout that reaches it; a refusal leaves the output untouched."""
	var out: PackedInt32Array = PackedInt32Array([7])
	for level: int in [0, 2, 3, 4]:
		assert_false(Landings.landings_into(Flight.LAYOUT_M5, level, ORIGIN, DATUM, out), "level %d" % level)
	assert_false(Landings.landings_into(Flight.LAYOUT_M2, 1, ORIGIN, DATUM, out), "M2")
	assert_equal(out, PackedInt32Array([7]), "untouched")


func test_the_shape_is_a_turn_0_stair_head_on_the_surface() -> void:
	"""(x, z, family, turn) on the surface, and its standing cells are the whole 2 × 27 strip from the origin."""
	var out: PackedInt32Array = PackedInt32Array()
	assert_true(Landings.shape_into(Flight.LAYOUT_M5, 0, ORIGIN, DATUM, out), "surface")
	var anchor: Vector2i = Landings.anchor_of(Flight.LAYOUT_M5, ORIGIN, DATUM)
	assert_equal(out, PackedInt32Array([anchor.x, anchor.y, Connectors.EARTH_TIMBER, 0]), "the quad")
	var standing: PackedInt32Array = Families.standing_cells(Families.EARTH_TIMBER, 0, anchor)
	assert_equal(Vector2i(standing[standing.size() - 2], standing[standing.size() - 1]),
		Vector2i(120, 99), "row 0's east cell touches the origin (x 122,880, z 101,376)")


func test_no_shape_below_the_surface_or_for_no_layout() -> void:
	"""The real way stands only on the surface."""
	var out: PackedInt32Array = PackedInt32Array()
	assert_false(Landings.shape_into(Flight.LAYOUT_M5, 1, ORIGIN, DATUM, out), "level 1")
	assert_false(Landings.shape_into(-1, 0, ORIGIN, DATUM, out), "no layout")
	assert_true(out.is_empty(), "untouched")


func test_cells_west_and_north_of_the_datum_round_down() -> void:
	"""Below the datum the anchor still names the cell the point lies in (floor division)."""
	var origin: Vector3i = Vector3i(-512, 512, -1)
	var anchor: Vector2i = Landings.anchor_of(Flight.LAYOUT_M5, origin, DATUM)
	assert_equal(anchor, Vector2i(-2, -28), "x -1,536 is cell -2; z -27,649 is cell -28")
	assert_equal(Landings.anchor_of(Flight.LAYOUT_M5, Vector3i(0, 512, 0), DATUM), Vector2i(-1, -27),
		"an exact negative multiple: x -1,024 is cell -1, z -27,648 is cell -27")
	var datum: Vector3i = Vector3i(1024, 0, 2048)
	assert_equal(Landings.anchor_of(Flight.LAYOUT_M5, ORIGIN, datum), Landings.anchor_of(Flight.LAYOUT_M5, ORIGIN,
		DATUM) - Vector2i(1, 2), "a datum shifts the cells")
