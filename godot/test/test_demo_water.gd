extends "res://test/framework/test_case.gd"
## Coverage for the live demo's water foundation (`godot/demo/water/`, decision 0196).
##
## The suite runs before the scene tree is live and CI stages no assets, so nothing here loads a
## model or needs a renderer. Every expected number is restated from its source -- the fixture's
## own authored integers, GDD §5.4's table and formulas, the authored village layout -- never read
## back out of the module under test:
##   * water_rules.gd: integer square root, the WADE / SWIM / DIVE thresholds for a mouse and a
##     badger at and either side of each boundary;
##   * water_map.gd on literal fixtures: trapezoid depth, zones, the bank and bed heights, flow,
##     the shoreline and nearest bank, landings, crossing candidates, the tunnel query, refusals;
##   * the authored village: the water stays outside the play square with flat, dry ground inside
##     it, the ford is wadeable, the run and the pond are dives, the weir meets GDD §5.4's width;
##   * dressing and spots: in bounds, clear of every obstacle, on dry ground, woods kept off water;
##   * the fishing driver against GDD §5.4: stocks, quotas, slots, expected catch, closures,
##     recovery, one shared river stock for run and ford, queueing, cycles and their lots;
##   * the drawn water: carved ground, surfaces, the flow clock, the underground view, the overlay.

const Rules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterSurfaceScript := preload("res://demo/water/water_surface.gd")
const DemoWater := preload("res://demo/water/demo_water.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const Overlay := preload("res://demo/water/water_overlay.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const DemoWorld := preload("res://demo/world/demo_world.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Dimensions := preload("res://assets/lookdev/lookdev_dimensions.gd")
const Scatter := preload("res://demo/world/world_scatter.gd")
const DemoCamera := preload("res://demo/camera/demo_camera.gd")
const Layers := preload("res://demo/demo_layers.gd")

## Fixture numbers, in u.
const DROP: int = 184
const BANK: int = 1024
const SPEED: int = 400
## The play square's half-extent, 20 m, in u.
const SQUARE_U: int = 20480
## GDD §5.4 compiled as the test's own literals.
const RIVER_QUOTA_MILLI: int = 52500   # floor((600 + 900 + 600) * 1000 / 40)
const LAKE_QUOTA_MILLI: int = 55000    # floor((900 + 700 + 600) * 1000 / 40)
const TICKS_PER_DAY: int = 18000
const FIRST_MIDNIGHT: int = 13500

var _map: WaterMapScript = null
var _out: IntMath.IntResult = null
var _bank: WaterMapScript.Bank = null
var _nodes: Array[Node] = []


func before_each() -> void:
	"""Fresh scratch for every test."""
	_map = null
	_out = IntMath.IntResult.new()
	_bank = WaterMapScript.Bank.new()
	_nodes.clear()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


# --- fixtures ----------------------------------------------------------------------------------

func _straight_stream() -> WaterMapScript:
	"""A 10 m stream along +z: half-width 1024, bed 1024, ramp 512, speed 400 u/s."""
	var map := WaterMapScript.new(BANK)
	assert_true(map.add_stream(&"s", PackedInt32Array([0, 0, 1024, 1024, 0, 10240, 1024, 1024]),
		DROP, 512, SPEED).ok, "fixture stream adds")
	assert_true(map.finalize().ok, "fixture stream finalizes")
	return map


func _pond() -> WaterMapScript:
	"""A still pond: one circle of radius 2048 and bed 2048 at the origin, ramp 1024."""
	var map := WaterMapScript.new(BANK)
	assert_true(map.add_pond(&"p", PackedInt32Array([0, 0, 2048, 2048]), DROP, 1024).ok, "pond adds")
	return map


func _crossing_stream() -> WaterMapScript:
	"""A stream with a 3072-wide neck at z=4096 and a ford exactly knee-deep (256 u) from z=8192 to
	12288 -- the wade threshold itself, so the ford is a ford only because 256 u still wades."""
	var map := WaterMapScript.new(BANK)
	var vertices := PackedInt32Array([0, 0, 2048, 1024, 0, 4096, 1536, 1024, 0, 8192, 3072, 256,
		0, 12288, 3072, 256, 0, 16384, 2048, 1024])
	assert_true(map.add_stream(&"c", vertices, DROP, 512, SPEED).ok, "crossing stream adds")
	assert_true(map.finalize().ok, "crossing stream finalizes")
	return map


# --- water_rules.gd ----------------------------------------------------------------------------

func test_isqrt_is_the_exact_floor_root() -> void:
	"""Squares and their neighbours, small and large."""
	var cases: Dictionary = {0: 0, 1: 1, 2: 1, 3: 1, 4: 2, 15: 3, 16: 4, 17: 4, 24: 4, 25: 5,
		9999999999: 99999, 10000000000: 100000, 10000200001: 100001}
	for n: int in cases:
		assert_equal(Rules.isqrt(n), cases[n], "isqrt(%d)" % n)


func test_mouse_zones_at_each_threshold() -> void:
	"""A 1.0 m mouse wades to 256 u (a quarter of its height), swims to 1024 u, dives beyond."""
	var cases: Dictionary = {0: Rules.ZONE_DRY, -5: Rules.ZONE_DRY, 1: Rules.ZONE_WADE,
		256: Rules.ZONE_WADE, 257: Rules.ZONE_SWIM, 1024: Rules.ZONE_SWIM, 1025: Rules.ZONE_DIVE}
	for depth: int in cases:
		assert_equal(Rules.zone_for_depth(depth, 1024), cases[depth], "mouse at %d u" % depth)


func test_badger_zones_scale_with_its_height() -> void:
	"""A 2611 u badger: wade while depth*1000 <= 250*2611 (652750), swim to 2611 u."""
	assert_equal(Rules.zone_for_depth(652, 2611), Rules.ZONE_WADE, "badger wades 652 u")
	assert_equal(Rules.zone_for_depth(653, 2611), Rules.ZONE_SWIM, "badger swims 653 u")
	assert_equal(Rules.zone_for_depth(2611, 2611), Rules.ZONE_SWIM, "badger swims its height")
	assert_equal(Rules.zone_for_depth(2612, 2611), Rules.ZONE_DIVE, "badger dives past it")
	assert_equal(Rules.wade_max_u(1024), 256, "mouse wade limit")
	assert_equal(Rules.dive_min_u(1024), 1024, "mouse dive threshold")


func test_mouse_anchor_is_the_lookdev_row() -> void:
	"""The mouse the zones are anchored on is lookdev_dimensions.gd's own 1.0 m mouse."""
	var row: int = Dimensions.SPECIES_KEY.find(&"mouse")
	assert_equal(Rules.MOUSE_HEIGHT_U, Dimensions.SPECIES_HEIGHT_U[row], "mouse height in u")
	assert_equal(Rules.MOUSE_HEIGHT_U, 1024, "1.0 m")


func test_direction_table_is_unit_length() -> void:
	"""Every one of the 64 shoreline directions is 1024 long to within rounding."""
	assert_equal(Rules.DIRECTIONS_1024.size(), 2 * Rules.DIRECTION_COUNT, "64 (x, z) pairs")
	for k: int in Rules.DIRECTION_COUNT:
		var length: int = Rules.isqrt(Rules.DIRECTIONS_1024[2 * k] ** 2 + Rules.DIRECTIONS_1024[2 * k + 1] ** 2)
		assert_true(length >= 1023 and length <= 1024, "direction %d has length %d" % [k, length])


# --- water_map.gd: depth, zones, ground, flow --------------------------------------------------

func test_trapezoid_depth_across_the_stream() -> void:
	"""Full 1024 on the flat bed, ramping over 512 u to the waterline at x = 1024, ceil'd."""
	var map := _straight_stream()
	assert_equal(map.depth_at(Vector2i(0, 5120)), 1024, "centre")
	assert_equal(map.depth_at(Vector2i(512, 5120)), 1024, "ramp foot: e = 512")
	assert_equal(map.depth_at(Vector2i(768, 5120)), 512, "e = 256: 1024 * 256 / 512")
	assert_equal(map.depth_at(Vector2i(1000, 5120)), 48, "e = 24: 1024 * 24 / 512")
	assert_equal(map.depth_at(Vector2i(1023, 5120)), 2, "e = 1: ceil(1024 / 512)")
	assert_equal(map.depth_at(Vector2i(1024, 5120)), 0, "waterline")
	assert_equal(map.depth_at(Vector2i(-1023, 5120)), 2, "the other bank mirrors it")
	assert_true(map.is_water(Vector2i(1023, 5120)), "just inside is water")
	assert_false(map.is_water(Vector2i(1024, 5120)), "the waterline is dry")


func test_tapered_primitive_interpolates_radius_and_bed() -> void:
	"""Half-way along a taper from (1024, 512) to (2048, 1536): radius 1536, bed 1024."""
	var map := WaterMapScript.new(BANK)
	map.add_stream(&"t", PackedInt32Array([0, 0, 1024, 512, 0, 10240, 2048, 1536]), DROP, 512, SPEED)
	assert_equal(map.depth_at(Vector2i(0, 5120)), 1024, "bed at t = 0.5")
	assert_equal(map.depth_at(Vector2i(1500, 5120)), 72, "e = 36: ceil(1024 * 36 / 512)")
	assert_equal(map.depth_at(Vector2i(1536, 5120)), 0, "radius 1536 at t = 0.5")
	assert_equal(map.depth_at(Vector2i(0, 0)), 512, "bed 512 at the upstream end")


func test_zone_at_uses_the_mouse() -> void:
	"""Centre 1024 u swims, 512 u swims, 200 u wades, the bank is dry."""
	var map := _straight_stream()
	assert_equal(map.zone_at(Vector2i(0, 5120)), Rules.ZONE_SWIM, "1024 u")
	assert_equal(map.zone_at(Vector2i(768, 5120)), Rules.ZONE_SWIM, "512 u")
	assert_equal(map.zone_at(Vector2i(924, 5120)), Rules.ZONE_WADE, "e = 100: 200 u")
	assert_equal(map.zone_at(Vector2i(2000, 5120)), Rules.ZONE_DRY, "bank")
	var pond := _pond()
	assert_equal(pond.zone_at(Vector2i.ZERO), Rules.ZONE_DIVE, "2048 u pond centre")


func test_zone_for_a_body_and_its_refusal() -> void:
	"""A badger wades the 512 u margin a mouse must swim; a zero height refuses."""
	var map := _straight_stream()
	assert_true(map.zone_for_body_into(Vector2i(768, 5120), 2611, _out), "badger zone")
	assert_equal(_out.value, Rules.ZONE_WADE, "512 u is a badger's wade")
	assert_false(map.zone_for_body_into(Vector2i(768, 5120), 0, _out), "zero height refuses")
	assert_equal(_out.error, String(WaterMapScript.REFUSE_BODY_HEIGHT), "the reason")


func test_ground_falls_down_the_bank_to_the_bed() -> void:
	"""Flat beyond the bank, linear to -184 at the waterline, the bed below the surface."""
	var map := _straight_stream()
	assert_equal(map.ground_height_at(Vector2i(0, 5120)), -(DROP + 1024), "bed at the centre")
	assert_equal(map.ground_height_at(Vector2i(768, 5120)), -(DROP + 512), "bed on the ramp")
	assert_equal(map.ground_height_at(Vector2i(1024, 5120)), -DROP, "waterline")
	assert_equal(map.ground_height_at(Vector2i(1536, 5120)), -92, "half-way up: 184 * 512 / 1024")
	assert_equal(map.ground_height_at(Vector2i(2047, 5120)), 0, "e = -1023: 184 * 1 / 1024 floors")
	assert_equal(map.ground_height_at(Vector2i(2048, 5120)), 0, "bank top")
	assert_equal(map.ground_height_at(Vector2i(9000, 5120)), 0, "far away")


func test_flow_follows_the_stream_and_stills_on_a_pond() -> void:
	"""Downstream at 400 u/s in the water; zero on dry land and on still water."""
	var map := _straight_stream()
	assert_equal(map.flow_at(Vector2i(0, 5120)), Vector2i(0, SPEED), "downstream")
	assert_equal(map.flow_at(Vector2i(1024, 5120)), Vector2i.ZERO, "dry waterline")
	var pond := _pond()
	assert_equal(pond.flow_at(Vector2i(10, 10)), Vector2i.ZERO, "a pond is still")
	var bent := WaterMapScript.new(BANK)
	bent.add_stream(&"b", PackedInt32Array([0, 0, 1024, 512, 3000, 4000, 1024, 512]), DROP, 512, 500)
	assert_equal(bent.flow_at(Vector2i(1500, 2000)), Vector2i(300, 400), "along a 3-4-5 leg")


func test_body_at_and_sample_agree() -> void:
	"""One sample carries margin, depth, body, ground and flow; body_at refuses dry land."""
	var map := _straight_stream()
	var sample := WaterMapScript.Sample.new()
	assert_true(map.sample_into(Vector2i(768, 5120), sample), "sampled")
	assert_equal(sample.margin_u, 256, "margin")
	assert_equal(sample.depth_u, 512, "depth")
	assert_equal(sample.ground_u, -(DROP + 512), "ground")
	assert_equal(sample.flow, Vector2i(0, SPEED), "flow")
	assert_true(map.body_at_into(Vector2i(0, 5120), _out), "in the stream")
	assert_equal(_out.value, 0, "body 0")
	assert_false(map.body_at_into(Vector2i(4000, 5120), _out), "dry refuses")
	assert_equal(_out.error, String(WaterMapScript.REFUSE_DRY), "the reason")
	assert_equal(map.inside_margin_u(Vector2i(4000, 5120)), -2976, "3000 u from the axis less 1024")


func test_empty_map_answers_dry_and_refuses_what_needs_water() -> void:
	"""No water: depth 0, flat ground, no flow, margin clamped far; sample and finalize refuse."""
	var map := WaterMapScript.new(BANK)
	assert_equal(map.depth_at(Vector2i.ZERO), 0, "depth")
	assert_equal(map.ground_height_at(Vector2i.ZERO), 0, "ground")
	assert_equal(map.flow_at(Vector2i.ZERO), Vector2i.ZERO, "flow")
	assert_equal(map.inside_margin_u(Vector2i.ZERO), -WaterMapScript.FAR_U, "far")
	assert_false(map.sample_into(Vector2i.ZERO, WaterMapScript.Sample.new()), "sample refuses")
	assert_false(map.nearest_bank(Vector2i.ZERO, _bank), "no shore yet")
	var done := map.finalize()
	assert_false(done.ok, "an empty map does not finalize")
	assert_equal(done.error, String(WaterMapScript.REFUSE_EMPTY), "the reason")


# --- water_map.gd: shoreline, banks, landings ---------------------------------------------------

func test_a_single_pond_circle_has_64_shore_samples_on_its_edge() -> void:
	"""Every direction of the table lands on the circle; none is inside it."""
	var map := _pond()
	assert_true(map.finalize().ok, "finalizes")
	assert_equal(map.shore_count(), 64, "one sample per direction")
	assert_equal(map.shore_point(0), Vector2i(2048, 0), "direction 0")
	assert_equal(map.shore_point(16), Vector2i(0, 2048), "direction 16")
	for k: int in map.shore_count():
		assert_true(absi(map.inside_margin_u(map.shore_point(k))) <= 2, "sample %d on the edge" % k)


func test_nearest_bank_scans_the_shore() -> void:
	"""From the centre every sample ties and the first wins; off-centre the nearest wins."""
	var map := _pond()
	map.finalize()
	assert_true(map.nearest_bank(Vector2i.ZERO, _bank), "found")
	assert_equal(_bank.point(), Vector2i(1702, 1138), "direction 6 (851, 569) rounds nearest; its "
		+ "three mirror images tie with it and the lowest index wins")
	assert_equal(_bank.distance_u, 2047, "isqrt(1702^2 + 1138^2)")
	map.nearest_bank(Vector2i(1000, 0), _bank)
	assert_equal(_bank.point(), Vector2i(2048, 0), "east")
	assert_equal(_bank.distance_u, 1048, "2048 - 1000")
	map.nearest_bank(Vector2i(0, 3000), _bank)
	assert_equal(_bank.point(), Vector2i(0, 2048), "south, from outside")
	assert_equal(_bank.distance_u, 952, "3000 - 2048")
	assert_equal(_bank.body, 0, "the pond")


func test_overlapping_circles_keep_only_the_union_edge() -> void:
	"""Two circles 1024 apart: a sample inside the other circle is not shore; the outer ones are."""
	var map := WaterMapScript.new(BANK)
	map.add_pond(&"two", PackedInt32Array([0, 0, 1024, 512, 1024, 0, 1024, 512]), DROP, 256)
	assert_true(map.finalize().ok, "finalizes")
	var points: Array[Vector2i] = []
	for k: int in map.shore_count():
		points.append(map.shore_point(k))
		assert_true(map.inside_margin_u(map.shore_point(k)) <= WaterMapScript.SHORE_TOLERANCE_U,
			"sample %s is not inside the union" % map.shore_point(k))
	assert_false(points.has(Vector2i(1024, 0)), "circle A's east point is inside B")
	assert_false(points.has(Vector2i(0, 0)), "circle B's west point is inside A")
	assert_true(points.has(Vector2i(-1024, 0)), "A's west point is shore")
	assert_true(points.has(Vector2i(2048, 0)), "B's east point is shore")


func test_a_landing_snaps_to_the_bank_and_sets_back_onto_dry_land() -> void:
	"""Near (3000, 0): the waterline at (2048, 0), the land 1024 u further out."""
	var map := _pond()
	assert_true(map.add_landing(&"east", Vector2i(3000, 0), 1024).ok, "authored")
	assert_true(map.finalize().ok, "finalizes")
	assert_true(map.landing_index_into(&"east", _out), "found by name")
	assert_equal(map.landing_water(_out.value), Vector2i(2048, 0), "waterline point")
	assert_equal(map.landing_land(_out.value), Vector2i(3072, 0), "land point")
	assert_equal(map.landing_body(_out.value), 0, "gives onto the pond")
	assert_false(map.landing_index_into(&"west", _out), "an unknown name refuses")


func test_landing_refusals() -> void:
	"""A duplicate name, a zero setback and a landing after finalize all refuse."""
	var map := _pond()
	assert_true(map.add_landing(&"a", Vector2i(3000, 0), 512).ok, "first")
	assert_false(map.add_landing(&"a", Vector2i(0, 3000), 512).ok, "duplicate name")
	assert_false(map.add_landing(&"b", Vector2i(0, 3000), 0).ok, "zero setback")
	map.finalize()
	var late := map.add_landing(&"c", Vector2i(0, 3000), 512)
	assert_false(late.ok, "after finalize")
	assert_equal(late.error, String(WaterMapScript.REFUSE_FINALIZED), "the reason")


func test_a_landing_that_never_reaches_dry_land_blocks_finalize() -> void:
	"""Its land point falls in a second stream 8 m wide: no dry ground within 64 steps."""
	var map := WaterMapScript.new(BANK)
	map.add_stream(&"a", PackedInt32Array([0, 0, 1024, 512, 0, 20480, 1024, 512]), DROP, 256, SPEED)
	map.add_stream(&"b", PackedInt32Array([8000, 0, 4000, 512, 8000, 20480, 4000, 512]), DROP, 256, SPEED)
	map.add_landing(&"trap", Vector2i(1100, 10240), 3000)
	var done := map.finalize()
	assert_false(done.ok, "refused")
	assert_equal(done.error, String(WaterMapScript.REFUSE_LANDING_UNRESOLVED), "the reason")
	assert_false(map.is_finalized(), "not finalized")


# --- water_map.gd: crossings -------------------------------------------------------------------

func test_crossings_are_the_ford_then_the_narrowest_spans() -> void:
	"""Ford at the first wadeable station (6144 wide, 256 deep); bridges at the 3072 neck, then at
	the narrowest station 6 m or more away (along 15872: half-width 3072 - 1024 * 7/8)."""
	var map := _crossing_stream()
	assert_equal(map.crossing_count(), 3, "one ford and two bridges")
	assert_equal(map.crossing_kind(0), WaterMapScript.CROSSING_FORD, "ford first")
	assert_equal(map.crossing_along_u(0), 8192, "the ford starts at z = 8192")
	assert_equal(map.crossing_width_u(0), 6144, "ford width")
	assert_equal(map.crossing_depth_u(0), 256, "ford depth")
	assert_equal(map.crossing_kind(1), WaterMapScript.CROSSING_BRIDGE, "then bridges")
	assert_equal(map.crossing_along_u(1), 4096, "the neck")
	assert_equal(map.crossing_width_u(1), 3072, "neck width")
	assert_equal(map.crossing_depth_u(1), 1024, "neck depth")
	assert_equal(map.crossing_a(1), Vector2i(-1536, 4096), "west bank end")
	assert_equal(map.crossing_b(1), Vector2i(1536, 4096), "east bank end")
	assert_equal(map.crossing_along_u(2), 15872, "second bridge")
	assert_equal(map.crossing_width_u(2), 4352, "2 * (3072 - 896)")
	assert_equal(map.crossing_depth_u(2), 928, "256 + 768 * 7/8")


func test_stream_width_at_a_point_is_the_nearest_station() -> void:
	"""Near the neck the width is the neck's; a pond-only map has no stations and refuses."""
	var map := _crossing_stream()
	assert_true(map.stream_width_at_into(Vector2i(0, 4200), _out), "measured")
	assert_equal(_out.value, 3072, "neck")
	assert_true(map.stream_width_at_into(Vector2i(0, 10000), _out), "measured")
	assert_equal(_out.value, 6144, "ford reach")
	var pond := _pond()
	pond.finalize()
	assert_false(pond.stream_width_at_into(Vector2i.ZERO, _out), "no stream")


# --- water_map.gd: tunnels ---------------------------------------------------------------------

func test_segment_crosses_water_with_clearance() -> void:
	"""A leg across the stream crosses; a parallel leg crosses only within radius + clearance."""
	var map := _straight_stream()
	assert_true(map.segment_crosses_water(Vector2i(-5000, 5120), Vector2i(5000, 5120), 0), "across")
	assert_false(map.segment_crosses_water(Vector2i(3000, 0), Vector2i(3000, 10240), 512), "3000 away")
	assert_true(map.segment_crosses_water(Vector2i(3000, 0), Vector2i(3000, 10240), 2000), "wide bore")
	assert_true(map.segment_crosses_water(Vector2i(1536, 0), Vector2i(1536, 10240), 512), "exactly 1536")
	assert_false(map.segment_crosses_water(Vector2i(1537, 0), Vector2i(1537, 10240), 512), "1 u beyond")
	assert_true(map.segment_crosses_water(Vector2i(0, 5000), Vector2i(0, 5000), 0), "a point in it")
	assert_false(map.segment_crosses_water(Vector2i(0, 12000), Vector2i(0, 13000), 512), "past the end")
	assert_true(map.segment_crosses_water(Vector2i(0, 11000), Vector2i(0, 13000), 0), "into the cap")


func test_segment_distance_cases() -> void:
	"""Crossing, parallel, point-to-point, collinear overlap, collinear gap, touching ends."""
	var cases: Array = [
		[Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, -5), Vector2i(5, 5), 0, "cross"],
		[Vector2i(0, 0), Vector2i(10, 0), Vector2i(0, 3), Vector2i(10, 3), 3, "parallel"],
		[Vector2i(0, 0), Vector2i(0, 0), Vector2i(3, 4), Vector2i(3, 4), 5, "points"],
		[Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 0), Vector2i(15, 0), 0, "overlap"],
		[Vector2i(0, 0), Vector2i(10, 0), Vector2i(12, 0), Vector2i(20, 0), 2, "gap"],
		[Vector2i(0, 0), Vector2i(10, 0), Vector2i(10, 0), Vector2i(10, 7), 0, "touch"],
		[Vector2i(0, 0), Vector2i(10, 0), Vector2i(4, 1), Vector2i(4, 1), 1, "a point above"],
	]
	for c: Array in cases:
		assert_equal(WaterMapScript.segment_distance_u(c[0], c[1], c[2], c[3]), c[4], c[5])
	assert_equal(WaterMapScript.point_segment_distance_u(Vector2i(13, 4), Vector2i(0, 0),
		Vector2i(10, 0)), 5, "beyond the end: 3-4-5")


# --- water_map.gd: authoring refusals -----------------------------------------------------------

func test_bad_bodies_are_refused_and_add_nothing() -> void:
	"""Ragged quads, one vertex, a repeated vertex, a zero width or depth, a zero ramp."""
	var map := WaterMapScript.new(BANK)
	var bad: Array[PackedInt32Array] = [
		PackedInt32Array([0, 0, 1024]), PackedInt32Array([0, 0, 1024, 512]),
		PackedInt32Array([0, 0, 1024, 512, 0, 0, 1024, 512]),
		PackedInt32Array([0, 0, 0, 512, 0, 100, 1024, 512]),
		PackedInt32Array([0, 0, 1024, 0, 0, 100, 1024, 512]),
	]
	for quads: PackedInt32Array in bad:
		assert_false(map.add_stream(&"x", quads, DROP, 512, SPEED).ok, "refused %s" % quads)
	assert_false(map.add_stream(&"x", PackedInt32Array([0, 0, 1, 1, 0, 9, 1, 1]), DROP, 0, SPEED).ok,
		"zero ramp")
	assert_false(map.add_pond(&"x", PackedInt32Array(), DROP, 512).ok, "no circles")
	assert_equal(map.body_count(), 0, "nothing was added")
	assert_equal(map.segment_count(), 0, "no primitive either")


func test_body_capacity_and_finalize_once() -> void:
	"""Eight bodies fit, a ninth refuses; a second finalize refuses; so does a body after it."""
	var map := WaterMapScript.new(BANK)
	for k: int in WaterMapScript.MAX_BODIES:
		assert_true(map.add_pond(&"p", PackedInt32Array([k * 10000, 0, 512, 256]), DROP, 256).ok,
			"pond %d" % k)
	var ninth := map.add_pond(&"p", PackedInt32Array([0, 90000, 512, 256]), DROP, 256)
	assert_equal(ninth.error, String(WaterMapScript.REFUSE_BODY_CAPACITY), "ninth body")
	assert_true(map.finalize().ok, "first finalize")
	assert_equal(map.finalize().error, String(WaterMapScript.REFUSE_FINALIZED), "second finalize")


# --- the authored village --------------------------------------------------------------------------

func _village() -> WaterMapScript:
	"""The demo's own water, built once per test that needs it."""
	if _map == null:
		_map = WaterLayout.make_map()
	return _map


func test_village_has_a_stream_and_a_pond() -> void:
	"""Two bodies, named and kinded as authored; the stream flows and the pond is still."""
	var map := _village()
	assert_true(map.is_finalized(), "finalized")
	assert_equal(map.body_count(), 2, "two bodies")
	assert_equal(map.body_name(0), &"stream", "stream first")
	assert_equal(map.body_kind(0), WaterMapScript.KIND_STREAM, "a stream")
	assert_equal(map.body_name(1), &"pond", "then the pond")
	assert_equal(map.body_kind(1), WaterMapScript.KIND_POND, "a pond")
	assert_equal(map.body_level_drop_u(0), 184, "0.18 m below the datum")
	assert_equal(map.landing_count(), 6, "six landings")


func test_nothing_inside_the_play_square_is_wet_or_carved() -> void:
	"""Every half metre inside the ±20 m square is flat (ground 0) and dry: nothing in the village
	moved, and residents kept inside the square never stand in water or on a bank."""
	var map := _village()
	var bad: int = 0
	for x: int in range(-SQUARE_U, SQUARE_U + 1, 512):
		for z: int in range(-SQUARE_U, SQUARE_U + 1, 512):
			if map.ground_height_at(Vector2i(x, z)) != 0 or map.is_water(Vector2i(x, z)):
				bad += 1
	assert_equal(bad, 0, "carved or wet points inside the square")


func test_no_tunnel_inside_the_square_can_reach_under_water() -> void:
	"""Every edge of the square, as a tunnel leg with half a 1024 u bore of clearance, is clear."""
	var map := _village()
	var corners: Array[Vector2i] = [Vector2i(-SQUARE_U, -SQUARE_U), Vector2i(SQUARE_U, -SQUARE_U),
		Vector2i(SQUARE_U, SQUARE_U), Vector2i(-SQUARE_U, SQUARE_U)]
	for k: int in 4:
		assert_false(map.segment_crosses_water(corners[k], corners[(k + 1) % 4], 512),
			"edge %s -> %s" % [corners[k], corners[(k + 1) % 4]])
	assert_true(map.segment_crosses_water(Vector2i(0, 0), Vector2i(30720, 0), 512),
		"a leg out east across the stream does cross it")


func test_the_ford_wades_and_the_run_and_pond_dive() -> void:
	"""At the east road the stream is 0.2-0.21 m deep (between its two ford vertices); the run
	vertex is 1434 u; the weir reach 1126 u; the pond's big circle 1946 u -- all authored."""
	var map := _village()
	var ford: int = map.depth_at(Vector2i(25702, -819))
	assert_true(ford >= 205 and ford <= 215, "ford depth %d between 205 and 215" % ford)
	assert_equal(map.zone_at(Vector2i(25702, -819)), Rules.ZONE_WADE, "the ford wades")
	assert_equal(map.depth_at(Vector2i(24986, 11264)), 1434, "the run")
	assert_equal(map.zone_at(Vector2i(24986, 11264)), Rules.ZONE_DIVE, "the run is a dive")
	assert_equal(map.depth_at(Vector2i(24371, -14336)), 1126, "the weir reach")
	assert_equal(map.depth_at(Vector2i(28467, 28672)), 1946, "the pond")
	assert_equal(map.flow_at(Vector2i(28467, 28672)), Vector2i.ZERO, "the pond is still")
	assert_true(map.flow_at(Vector2i(24986, 11264)).y > 0, "the run flows south")


func test_village_crossings_ford_at_the_road_and_bridge_at_the_neck() -> void:
	"""The first candidate is the ford, wadeable, in the authored ford reach (z -3.1 m .. 1.5 m);
	the narrowest bridge span is at the neck (3.4-3.5 m across, z -27 m .. -24 m)."""
	var map := _village()
	assert_equal(map.crossing_kind(0), WaterMapScript.CROSSING_FORD, "a ford")
	assert_true(map.crossing_depth_u(0) <= 256, "a mouse wades it")
	var ford_z: int = (map.crossing_a(0).y + map.crossing_b(0).y) / 2
	assert_true(ford_z >= -3174 and ford_z <= 1536, "ford z %d in the ford reach" % ford_z)
	assert_equal(map.crossing_kind(1), WaterMapScript.CROSSING_BRIDGE, "then a bridge")
	var neck: int = map.crossing_width_u(1)
	assert_true(neck >= 3400 and neck <= 3584, "neck span %d" % neck)
	var neck_z: int = (map.crossing_a(1).y + map.crossing_b(1).y) / 2
	assert_true(neck_z >= -27648 and neck_z <= -24576, "neck z %d" % neck_z)


func test_the_weir_reach_meets_the_gdd_width() -> void:
	"""GDD §5.4: a weir needs "flow 4-12 m wide" -- the stream at the weir is in range."""
	var map := _village()
	var weir: Vector2 = Layout.find_placement(WaterDressing.placements(), &"weir")["at"]
	assert_true(map.stream_width_at_into(Vector2i(Rules.to_u(weir.x), Rules.to_u(weir.y)), _out),
		"measured")
	assert_true(_out.value >= 4096 and _out.value <= 12288, "weir reach %d u" % _out.value)
	assert_true(map.is_water(Vector2i(Rules.to_u(weir.x), Rules.to_u(weir.y))), "the weir stands in it")


func test_every_landing_has_a_waterline_and_dry_flat_land() -> void:
	"""Each landing's water point is on the waterline and its land point is dry and flat."""
	var map := _village()
	for k: int in map.landing_count():
		var water: Vector2i = map.landing_water(k)
		var land: Vector2i = map.landing_land(k)
		assert_true(absi(map.inside_margin_u(water)) <= WaterMapScript.SHORE_TOLERANCE_U,
			"%s water point on the waterline" % map.landing_name(k))
		assert_false(map.is_water(land), "%s land is dry" % map.landing_name(k))
		assert_equal(map.ground_height_at(land), 0, "%s land is flat" % map.landing_name(k))


# --- dressing and spots --------------------------------------------------------------------------

func _all_obstacles() -> Array[Vector3]:
	"""World and water obstacles in world_layout.gd's (x, z, radius) form."""
	var world: DemoWorld = DemoWorld.new()
	_nodes.append(world)
	var out: Array[Vector3] = []
	for circle: Vector3 in world.obstacles():
		out.append(DemoWorld.layout_circle(circle))
	for circle: Vector3 in WaterDressing.obstacles():
		out.append(DemoWorld.layout_circle(circle))
	return out


func test_water_spots_are_in_bounds_clear_dry_and_apart() -> void:
	"""Each spot: inside the square, 0.3 m clear of every obstacle, on flat dry ground, 1.2 m
	from every other spot -- the same bar the world's own spots meet."""
	var map := _village()
	var circles: Array[Vector3] = _all_obstacles()
	var spots: Array[Dictionary] = (_nodes[0] as DemoWorld).points_of_interest()
	spots.append_array(WaterDressing.points_of_interest())
	for point: Dictionary in WaterDressing.points_of_interest():
		var at: Vector3 = point["position"]
		var flat := Vector2(at.x, at.z)
		assert_true(Layout.bounds().has_point(at), "%s in bounds" % point["name"])
		assert_true(Layout.clearance(flat, circles) >= 0.3, "%s clear" % point["name"])
		var u := Vector2i(Rules.to_u(at.x), Rules.to_u(at.z))
		assert_equal(map.ground_height_at(u), 0, "%s on flat ground" % point["name"])
		for other: Dictionary in spots:
			if other["name"] != point["name"]:
				assert_true(at.distance_to(other["position"]) >= 1.2, "%s apart from %s" % [point["name"], other["name"]])


func test_water_spots_are_well_formed() -> void:
	"""Unique names, unit horizontal faces, known activities, capacity, typed arrays."""
	var names: Array[StringName] = []
	for point: Dictionary in WaterDressing.points_of_interest():
		assert_false(names.has(point["name"]), "%s unique" % point["name"])
		names.append(point["name"])
		assert_almost_equal((point["face"] as Vector3).length(), 1.0, "%s unit face" % point["name"])
		assert_almost_equal((point["face"] as Vector3).y, 0.0, "%s horizontal" % point["name"])
		var activities: Array = point["activities"]
		assert_true(activities.is_typed() and activities.get_typed_builtin() == TYPE_STRING_NAME,
			"%s typed activities" % point["name"])
		for activity: StringName in activities:
			assert_true(Layout.ACTIVITIES.has(activity), "%s knows %s" % [point["name"], activity])
		assert_equal(int(point["capacity"]), 1, "%s capacity" % point["name"])
	assert_equal(names, [&"fishing_spot", &"weir_work", &"boat_landing"] as Array[StringName], "spots")


func test_dressing_obstacles_are_sane_and_reach_the_play_area() -> void:
	"""Published (x, radius, z), positive and under 3 m, each within the report margin."""
	var circles: Array[Vector3] = WaterDressing.obstacles()
	assert_true(circles.size() > 0, "the dressing has obstacles by the village")
	for circle: Vector3 in circles:
		assert_true(circle.y > 0.0 and circle.y < 3.0, "radius %.2f" % circle.y)
		assert_true(Layout.circle_reaches_play(DemoWorld.layout_circle(circle)), "reaches play")


func test_dressing_sizes_use_the_building_envelopes() -> void:
	"""Boathouse 5.0 m, weir 1.5 m, fisher shelter 3.5 m, mill 7.0 m (lookdev), creel 0.5 m."""
	var expected: Dictionary = {&"boathouse": 5.0, &"weir": 1.5, &"fisher_shelter": 3.5,
		&"mill": 7.0, &"fish_creel": 0.5}
	for key: StringName in expected:
		assert_almost_equal(WaterDressing.target_height_m(key), expected[key], "%s height" % key)
		var bound: Array = WaterDressing.native_bound(key)
		var drawn: float = WaterDressing.uniform_scale(key, bound[0], bound[1]) \
			* ((bound[1] as Vector3).y - (bound[0] as Vector3).y)
		assert_almost_equal(drawn, expected[key], "%s drawn height" % key)


func test_woods_blockers_cover_the_water_and_the_dressing() -> void:
	"""Every stream vertex, pond centre and dressing placement lies inside some blocker."""
	var blockers: Array[Vector3] = WaterDressing.woods_blockers()
	var probes: Array[Vector2] = []
	for k: int in WaterLayout.STREAM_VERTICES.size() / 4:
		probes.append(Vector2(Rules.to_m(WaterLayout.STREAM_VERTICES[k * 4]),
			Rules.to_m(WaterLayout.STREAM_VERTICES[k * 4 + 1])))
	for k: int in WaterLayout.POND_CIRCLES.size() / 4:
		probes.append(Vector2(Rules.to_m(WaterLayout.POND_CIRCLES[k * 4]),
			Rules.to_m(WaterLayout.POND_CIRCLES[k * 4 + 1])))
	for probe: Vector2 in probes:
		assert_true(Layout.clearance(probe, blockers) < 0.0, "%s is blocked for the woods" % probe)
	for p: Dictionary in WaterDressing.placements():
		assert_true(Layout.clearance(p["at"], blockers) < Scatter.TREE_BLOCKER_CLEARANCE_M,
			"no tree may stand on %s" % p["id"])


func test_no_tree_or_log_grows_in_the_water_or_on_its_banks() -> void:
	"""Build the placeholder world (before any water is laid): every placed piece -- the village,
	the woods, the forest debris -- stands beyond the bank top."""
	var world: DemoWorld = DemoWorld.new()
	_nodes.append(world)
	world.build({"world": {}, "cast": {}})
	var map := _village()
	var checked: int = 0
	for child: Node in world.get_node(^"Village").get_children():
		if not child is MeshInstance3D:
			continue
		var at: Vector3 = (child as Node3D).position
		checked += 1
		assert_true(map.inside_margin_u(Vector2i(Rules.to_u(at.x), Rules.to_u(at.z))) < -WaterLayout.BANK_RUN_U,
			"piece at (%.1f, %.1f) clear of the water and bank" % [at.x, at.z])
	assert_true(checked > 200, "%d pieces checked" % checked)


# --- the fishing driver (GDD §5.4) --------------------------------------------------------------

func _ids() -> PackedInt32Array:
	"""The nine species' compiled item ids, through the verified catalog boundary."""
	var ids: Driver.IdsResult = Driver.resolve_species_item_ids()
	assert_true(ids.ok, "species ids bind (error: %s)" % ids.error)
	return ids.ids


func _driver(start_tick: int = 0, weir_width_u: int = 4404) -> Driver:
	"""A driver on a fresh store, spring day 1 at tick 0 unless told otherwise."""
	var made: Driver.CreateResult = Driver.create(_ids(), start_tick, weir_width_u)
	assert_true(made.ok, "driver creates (error: %s)" % made.error)
	return made.driver as Driver


func _preview(driver: Driver, site: int, species: int, gear: int, skill: int = 0) -> Driver.Preview:
	"""A filled preview."""
	var out := Driver.Preview.new()
	assert_true(driver.preview_into(site, species, gear, skill, out), "preview fills")
	return out


func test_species_ids_bind_in_species_key_order() -> void:
	"""Nine distinct non-negative ids, one per fishing.gd SPECIES_KEYS row."""
	var ids := _ids()
	assert_equal(ids.size(), 9, "nine species")
	for k: int in ids.size():
		assert_true(ids[k] >= 0, "id %d is a catalog id" % k)
		for other: int in k:
			assert_true(ids[other] != ids[k], "ids %d and %d differ" % [other, k])


func test_sites_bind_river_and_lake_species() -> void:
	"""Run and ford fish the river's trout/dace/salmon; the pond the lake's perch/carp/whitefish."""
	var driver := _driver()
	var expected: Array = [[&"trout", &"dace", &"salmon"], [&"trout", &"dace", &"salmon"],
		[&"perch", &"carp", &"whitefish"]]
	for site: int in Driver.SITE_COUNT:
		for species: int in 3:
			assert_equal(driver.species_key_of(site, species), expected[site][species], "site %d/%d" % [site, species])
	assert_equal(driver.habitat_ref_of_site(Driver.SITE_RUN), driver.habitat_ref_of_site(Driver.SITE_FORD),
		"run and ford share ONE river habitat")
	assert_true(driver.habitat_ref_of_site(Driver.SITE_POND) != driver.habitat_ref_of_site(Driver.SITE_RUN),
		"the pond is its own lake habitat")


func test_create_refuses_bad_inputs() -> void:
	"""Eight ids, or a negative start tick, refuse with no driver."""
	var ids := _ids()
	var short: Driver.CreateResult = Driver.create(ids.slice(0, 8), 0, 4404)
	assert_false(short.ok, "eight ids")
	assert_equal(short.error, Driver.REFUSE_SPECIES_IDS, "the reason")
	assert_null(short.driver, "no driver")
	var early: Driver.CreateResult = Driver.create(ids, -1, 4404)
	assert_equal(early.error, Driver.REFUSE_NEGATIVE_TICK, "negative tick")


func test_initial_stocks_quotas_and_slots_are_the_gdd_table() -> void:
	"""80% of capacity; quota floor(K_total/40); river 4 slots, lake 6 (§5.4)."""
	var driver := _driver()
	var rows: Array = [[Driver.SITE_RUN, 0, 480000, 600000], [Driver.SITE_RUN, 1, 720000, 900000],
		[Driver.SITE_POND, 0, 720000, 900000], [Driver.SITE_POND, 1, 560000, 700000],
		[Driver.SITE_POND, 2, 480000, 600000]]
	for row: Array in rows:
		var preview := _preview(driver, row[0], row[1], Fishing.GEAR_HAND_NET)
		assert_equal(preview.stock_milli, row[2], "%s stock" % preview.species_key)
		assert_equal(preview.capacity_milli, row[3], "%s capacity" % preview.species_key)
	var river := _preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET)
	assert_equal(river.quota_milli, RIVER_QUOTA_MILLI, "river quota")
	assert_equal(river.slots_total, 4, "river slots")
	var lake := _preview(driver, Driver.SITE_POND, 0, Fishing.GEAR_HAND_NET)
	assert_equal(lake.quota_milli, LAKE_QUOTA_MILLI, "lake quota")
	assert_equal(lake.slots_total, 6, "lake slots")


func test_expected_catch_is_the_gdd_formula() -> void:
	"""floor(base * (1000 + 50 * skill) * A * S / 1e9): trout net skill 0 = 8000*1000*800*1000/1e9
	= 6400; skill 3 = 7360; perch spring S = 800 gives 5120; a weir's base 30 U gives 24000."""
	var driver := _driver()
	assert_equal(_preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET).expected_catch_milli, 6400, "trout")
	assert_equal(_preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET, 3).expected_catch_milli, 7360, "skill 3")
	assert_equal(_preview(driver, Driver.SITE_POND, 0, Fishing.GEAR_HAND_NET).expected_catch_milli, 5120, "perch")
	assert_equal(_preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_WEIR).expected_catch_milli, 24000, "weir")
	var boat := _preview(driver, Driver.SITE_POND, 1, Fishing.GEAR_BOAT)
	assert_equal(boat.expected_catch_milli, 28800, "carp by boat: 36000 * 1000 * 800 * 1000 / 1e9")
	assert_equal(boat.slots_needed, 2, "a boat takes two slots")
	assert_equal(boat.wear_per_cycle, 15, "boat wear")


func test_injury_risk_is_the_gdd_formula() -> void:
	"""max(1, base * (1 + danger) - 2 * skill - 4 * extra crew): net 12, boat 80-20-4, a floor of 1."""
	assert_equal(Driver.injury_per_10000(Fishing.GEAR_HAND_NET, 0, 0, 0), 12, "net")
	assert_equal(Driver.injury_per_10000(Fishing.GEAR_BOAT, 3, 10, 1), 56, "boat, danger 3")
	assert_equal(Driver.injury_per_10000(Fishing.GEAR_TRAP, 0, 10, 0), 1, "floored at 1")
	assert_equal(Driver.injury_per_10000(Fishing.GEAR_WEIR, 1, 0, 0), 10, "weir, danger 1")
	assert_equal(_preview(_driver(), Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET).injury_per_10000, 12, "shown")


func test_gear_access_follows_the_gdd_and_the_sites() -> void:
	"""Trap: dace/perch/carp/mussel only; net: not mackerel; weir only at the run; boat only on
	the pond; a weir is withdrawn when the run is outside 4-12 m wide."""
	assert_false(Driver.gear_takes_species(Fishing.GEAR_TRAP, Fishing.SPECIES_TROUT), "trap/trout")
	assert_true(Driver.gear_takes_species(Fishing.GEAR_TRAP, Fishing.SPECIES_DACE), "trap/dace")
	assert_false(Driver.gear_takes_species(Fishing.GEAR_HAND_NET, Fishing.SPECIES_MACKEREL), "net/mackerel")
	assert_true(Driver.gear_takes_species(Fishing.GEAR_HAND_NET, Fishing.SPECIES_TROUT), "net/trout")
	var driver := _driver()
	assert_equal(driver.refusal(Driver.SITE_FORD, 0, Fishing.GEAR_WEIR), Driver.REFUSE_GEAR_NOT_AT_SITE, "weir at ford")
	assert_equal(driver.refusal(Driver.SITE_RUN, 1, Fishing.GEAR_BOAT), Driver.REFUSE_GEAR_NOT_AT_SITE, "boat at run")
	assert_equal(driver.refusal(Driver.SITE_RUN, 0, Fishing.GEAR_TRAP), Driver.REFUSE_GEAR_SPECIES, "trap trout")
	assert_equal(driver.refusal(Driver.SITE_RUN, 0, Fishing.GEAR_WEIR), Driver.REFUSE_NONE, "weir at run")
	assert_true(_driver(0, 4096).gear_offered(Driver.SITE_RUN, Fishing.GEAR_WEIR), "4 m run")
	assert_true(_driver(0, 12288).gear_offered(Driver.SITE_RUN, Fishing.GEAR_WEIR), "12 m run")
	assert_false(_driver(0, 4095).gear_offered(Driver.SITE_RUN, Fishing.GEAR_WEIR), "too narrow")
	assert_false(_driver(0, 12289).gear_offered(Driver.SITE_RUN, Fishing.GEAR_WEIR), "too wide")


func test_invalid_site_species_or_gear_refuse() -> void:
	"""Each argument out of range refuses with its own reason; a preview writes nothing."""
	var driver := _driver()
	assert_equal(driver.refusal(3, 0, Fishing.GEAR_HAND_NET), Driver.REFUSE_INVALID_SITE, "site")
	assert_equal(driver.refusal(-1, 0, Fishing.GEAR_HAND_NET), Driver.REFUSE_INVALID_SITE, "site -1")
	assert_equal(driver.refusal(0, 3, Fishing.GEAR_HAND_NET), Fishing.REFUSE_INVALID_SPECIES_INDEX, "species")
	assert_equal(driver.refusal(0, 0, 5), Fishing.REFUSE_INVALID_GEAR, "gear")
	var out := Driver.Preview.new()
	assert_false(driver.preview_into(0, 0, 5, 0, out), "a bad gear previews nothing")
	assert_equal(out.stock_milli, 0, "untouched")


func test_salmon_is_shut_until_autumn() -> void:
	"""Salmon's spring availability is 0 (§5.4): unavailable, reopening autumn (2) day 1."""
	var preview := _preview(_driver(), Driver.SITE_RUN, 2, Fishing.GEAR_HAND_NET)
	assert_false(preview.ok, "may not start")
	assert_equal(preview.block, Fishing.REFUSE_SPECIES_UNAVAILABLE, "unavailable")
	assert_equal(preview.availability_per_1000, 0, "S = 0")
	assert_equal([preview.reopen_season, preview.reopen_day], [2, 1], "autumn day 1")
	assert_equal(preview.expected_catch_milli, 0, "nothing to catch")


func test_a_cycle_returns_a_species_lot_and_debits_the_stock() -> void:
	"""Trout by hand net at skill 3: 7360 milli-U of trout, from the fisher shelter's landing; the
	stock and the day's quota fall by exactly that; no claim is left open."""
	var ids := _ids()
	var driver := _driver()
	var caught: Driver.CatchResult = driver.resolve_cycle(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET, 3)
	assert_true(caught.ok, "caught (error: %s)" % caught.error)
	assert_equal(caught.quantity_milli, 7360, "the formula's catch")
	assert_equal(caught.lots.size(), 1, "one lot")
	var lot: Driver.CatchLot = caught.lots[0]
	assert_equal(lot.species_key, &"trout", "a trout lot, not generic fish")
	assert_equal(lot.species_row, Fishing.SPECIES_TROUT, "table row")
	assert_equal(lot.item_id, ids[0], "trout's catalog id")
	assert_equal(lot.quantity_milli, 7360, "lot quantity")
	assert_equal(lot.landing, &"fisher_shelter", "landed at the shelter")
	var after := _preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET)
	assert_equal(after.stock_milli, 480000 - 7360, "stock debited")
	assert_equal(after.remaining_quota_milli, RIVER_QUOTA_MILLI - 7360, "quota spent")
	assert_equal(driver.open_claims(), 0, "no open claim")


func test_run_and_ford_draw_on_one_river_stock() -> void:
	"""MOVE-TEST-07: fishing the ford after the run takes from the SAME trout stock -- A falls to
	floor(1000 * 472640 / 600000) = 787, so the ford's catch is floor(8000*1150*787*1000/1e9)."""
	var driver := _driver()
	driver.resolve_cycle(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET, 3)
	var ford: Driver.CatchResult = driver.resolve_cycle(Driver.SITE_FORD, 0, Fishing.GEAR_HAND_NET, 3)
	assert_equal(ford.quantity_milli, 7240, "the ford's catch reads the run's debit")
	assert_equal(ford.lots[0].landing, &"ford_west", "landed at the ford")
	var run := _preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET)
	assert_equal(run.stock_milli, 480000 - 7360 - 7240, "one stock, both debits")
	assert_equal(run.remaining_quota_milli, RIVER_QUOTA_MILLI - 7360 - 7240, "one quota")


func test_effort_slots_queue_further_fishers() -> void:
	"""REQ-SET-050: two weirs take the river's four slots; a net must then queue; freeing one
	weir lets it start. The lake's slots are untouched."""
	var driver := _driver()
	var first: Driver.Cycle = driver.begin_cycle(Driver.SITE_RUN, 1, Fishing.GEAR_WEIR)
	var second: Driver.Cycle = driver.begin_cycle(Driver.SITE_RUN, 0, Fishing.GEAR_WEIR)
	assert_true(first.ok and second.ok, "two weirs start")
	assert_equal(driver.open_claims(), 2, "two claims")
	var queued: Driver.Cycle = driver.begin_cycle(Driver.SITE_FORD, 1, Fishing.GEAR_HAND_NET)
	assert_false(queued.ok, "a net must wait")
	assert_equal(queued.error, Fishing.REFUSE_EFFORT_SLOTS_FULL, "queue: slots full")
	assert_true(_preview(driver, Driver.SITE_FORD, 1, Fishing.GEAR_HAND_NET).must_queue, "shown as queued")
	assert_equal(_preview(driver, Driver.SITE_POND, 0, Fishing.GEAR_HAND_NET).slots_free, 6, "lake free")
	assert_true(driver.complete_cycle(first, 0).ok, "one weir finishes")
	assert_true(driver.begin_cycle(Driver.SITE_FORD, 1, Fishing.GEAR_HAND_NET).ok, "the net starts")


func test_a_cycle_completes_once_and_cancels_cleanly() -> void:
	"""A second completion takes nothing; a cancelled cycle frees its slots and catches nothing."""
	var driver := _driver()
	var cycle: Driver.Cycle = driver.begin_cycle(Driver.SITE_POND, 1, Fishing.GEAR_BOAT)
	assert_true(cycle.ok, "a boat sets out")
	assert_equal(_preview(driver, Driver.SITE_POND, 1, Fishing.GEAR_BOAT).slots_free, 4, "two taken")
	assert_true(driver.complete_cycle(cycle, 0).ok, "completes")
	var again: Driver.CatchResult = driver.complete_cycle(cycle, 0)
	assert_false(again.ok, "a second completion")
	assert_equal(again.error, Driver.REFUSE_NOT_A_CYCLE, "is refused")
	var stock_before: int = _preview(driver, Driver.SITE_POND, 1, Fishing.GEAR_BOAT).stock_milli
	var dropped: Driver.Cycle = driver.begin_cycle(Driver.SITE_POND, 1, Fishing.GEAR_BOAT)
	assert_true(driver.cancel_cycle(dropped), "cancelled")
	assert_false(driver.cancel_cycle(dropped), "cancelled once")
	assert_equal(_preview(driver, Driver.SITE_POND, 1, Fishing.GEAR_BOAT).stock_milli, stock_before, "nothing taken")
	assert_equal(driver.open_claims(), 0, "no claim left")


func test_demo_time_becomes_whole_ticks_exactly() -> void:
	"""30 ticks a second, the remainder carried: 33333 us is 0 ticks, one more microsecond is 1."""
	var driver := _driver()
	assert_equal(driver.advance_usec(33333), 0, "no midnight")
	assert_equal(driver.completed_tick(), 0, "0.99999 of a tick")
	driver.advance_usec(1)
	assert_equal(driver.completed_tick(), 1, "the carried remainder made one tick")
	driver.advance_usec(0)
	assert_equal(driver.completed_tick(), 1, "paused: nothing")
	driver.advance_usec(1000000)
	assert_equal(driver.completed_tick(), 31, "one second is 30 ticks")


func test_midnight_recovers_stock_and_resets_the_quota() -> void:
	"""The first midnight (tick 13500) runs §5.4: trout 480000 + floor(80*480000*120000/(1000*
	600000)) + floor(600000/200) = 490680 (no catch that day), and the day's quota comes back."""
	var driver := _driver()
	driver.resolve_cycle(Driver.SITE_POND, 0, Fishing.GEAR_HAND_NET, 0)
	assert_equal(driver.advance_ticks(FIRST_MIDNIGHT - 1), 0, "not yet midnight")
	assert_equal(driver.advance_ticks(1), 1, "midnight")
	assert_equal([driver.season(), driver.season_day()], [0, 2], "spring day 2")
	assert_equal(_preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET).stock_milli, 490680, "trout recovered")
	assert_equal(_preview(driver, Driver.SITE_POND, 0, Fishing.GEAR_HAND_NET).remaining_quota_milli,
		LAKE_QUOTA_MILLI, "quota reset")


func test_the_trout_spawning_closure_and_its_reopening() -> void:
	"""Spring days 5-7 close trout (§5.4); on day 5 a cycle is refused and day 8 is shown."""
	var driver := _driver()
	assert_equal(driver.advance_ticks(FIRST_MIDNIGHT + 3 * TICKS_PER_DAY), 4, "four midnights")
	assert_equal(driver.season_day(), 5, "spring day 5")
	assert_equal(driver.refusal(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET), Fishing.REFUSE_SPECIES_CLOSED, "closed")
	var preview := _preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET)
	assert_true(preview.closed, "shown closed")
	assert_equal([preview.reopen_season, preview.reopen_day], [0, 8], "reopens spring day 8")
	assert_equal(driver.refusal(Driver.SITE_RUN, 1, Fishing.GEAR_HAND_NET), Driver.REFUSE_NONE, "dace stays open")


func test_depletion_latches_restocking_and_blocks_new_cycles() -> void:
	"""REQ-SET-048 through the store: under the visible intensive policy, fish trout below 30% K;
	the latch sets, and with the policy off a new cycle is refused RESTOCKING."""
	var driver := _driver()
	var ref: Vector2i = driver.habitat_ref_of_site(Driver.SITE_RUN)
	assert_true(driver.store().set_intensive_harvest(ref, true).ok, "intensive on")
	var preview := Driver.Preview.new()
	for day: int in 14:
		driver.preview_into(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET, 0, preview)
		var take: int = mini(preview.remaining_quota_milli, preview.stock_milli - 60000)
		if take > 0:
			driver.store().harvest(ref, 0, take, driver.season(), driver.season_day())
		driver.advance_ticks(TICKS_PER_DAY)
	driver.preview_into(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET, 0, preview)
	assert_true(preview.stock_milli * 100 < 30 * 600000, "below 30%% K: %d" % preview.stock_milli)
	assert_true(preview.depleted, "depleted")
	assert_true(preview.restocking, "restocking latched")
	driver.store().set_intensive_harvest(ref, false)
	assert_equal(driver.refusal(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET), Fishing.REFUSE_RESTOCKING, "blocked")


# --- the drawn water -----------------------------------------------------------------------------

func _built() -> Array:
	"""[world, water]: the placeholder world with the water laid into it."""
	var world: DemoWorld = DemoWorld.new()
	_nodes.append(world)
	world.build({"world": {}, "cast": {}})
	var water: DemoWater = DemoWater.new()
	_nodes.append(water)
	water.build({"world": {}, "cast": {}}, world)
	return [world, water]


func test_the_ground_is_carved_outside_the_square_only() -> void:
	"""Inside the square every ground vertex is exactly y = 0; the deepest is the pond's flat bed,
	-(184 + 1946) u; the ground keeps its node name and its own material."""
	var world: DemoWorld = _built()[0]
	var ground := world.get_node(^"Ground") as MeshInstance3D
	assert_not_null(ground, "the ground node survives by name")
	var vertices: PackedVector3Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lowest: float = 0.0
	var raised: int = 0
	for v: Vector3 in vertices:
		lowest = minf(lowest, v.y)
		if absf(v.x) <= 20.0 and absf(v.z) <= 20.0 and v.y != 0.0:
			raised += 1
	assert_equal(raised, 0, "carved vertices inside the square")
	assert_almost_equal(lowest, -2130.0 / 1024.0, "the pond bed")
	assert_true(ground.mesh.surface_get_material(0) is ShaderMaterial, "the ground shader stays")


func test_water_surfaces_one_per_body_at_the_water_level() -> void:
	"""A stream and a pond surface, each with its own material, flat at -184 u."""
	var water: DemoWater = _built()[1]
	var surface: WaterSurfaceScript = water.surface()
	assert_equal(surface.nodes.size(), 2, "two surfaces")
	assert_equal(surface.materials.size(), 2, "two materials")
	assert_true(surface.materials[0] != surface.materials[1], "one material per body")
	assert_equal(String(surface.nodes[0].name), "WaterSurface_stream", "stream surface")
	var vertices: PackedVector3Array = surface.nodes[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_almost_equal(vertices[0].y, -184.0 / 1024.0, "at the water level")
	assert_true(surface.nodes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() > 0, "stream has cells")


func test_flow_clock_freezes_when_paused_and_wraps_exactly() -> void:
	"""Integer microseconds: +1.5 s, +0 (paused), then +1 s wraps the 2 s cycle to 0.5 s; 4x
	frames move four times as far."""
	var surface := WaterSurfaceScript.new()
	surface.advance(1500000)
	assert_equal(surface.phase_usec(), 1500000, "one and a half seconds")
	surface.advance(0)
	assert_equal(surface.phase_usec(), 1500000, "paused: frozen")
	surface.advance(1000000)
	assert_equal(surface.phase_usec(), 500000, "wrapped at 2 s")
	var fast := WaterSurfaceScript.new()
	fast.advance(4 * 33333)
	assert_equal(fast.phase_usec(), 133332, "a 4x frame")


func test_the_water_follows_the_demo_clock() -> void:
	"""Bound to an unbound demo clock (1x): a 0.1 s frame moves the flow 100000 us and the fishery
	3 ticks; a paused frame moves neither."""
	var water: DemoWater = _built()[1]
	var clock := DemoWater.DemoClockScript.new()
	water.bind_clock(clock, 0)
	assert_not_null(water.fishing(), "the fishery started")
	clock.advance(0.1)
	water._process(0.1)
	assert_equal(water.surface().phase_usec(), 100000, "flow")
	assert_equal(water.fishing().completed_tick(), 3, "fishery ticks")
	clock.frame_usec = 0
	water._process(0.1)
	assert_equal(water.fishing().completed_tick(), 3, "paused")


func test_the_water_is_all_on_the_surface_layers() -> void:
	"""Decision 0206: the water has no underground hook -- its surfaces, bank film, dressing and labels
	are on the surface layers (the U view's cap draws the water as its no-dig band), each unfaded, and
	hiding the world's ground no longer touches it."""
	var built: Array = _built()
	var water: DemoWater = built[1]
	var drawn: Array[Node] = water.find_children("*", "GeometryInstance3D", true, false)
	assert_true(drawn.size() > 3, "surfaces, bank and overlay")
	for node: Node in drawn:
		var geometry := node as GeometryInstance3D
		assert_equal(geometry.layers & Layers.UNDERGROUND_VIEW, 0, "%s never in the U view" % geometry.name)
		assert_almost_equal(geometry.transparency, 0.0, "%s unfaded" % geometry.name)
	var ground := (built[0] as DemoWorld).get_node(^"Ground") as Node3D
	ground.visible = false
	assert_true((water.get_node(^"WaterBank") as Node3D).visible, "the bank does not follow the ground")
	assert_false(water.has_method(&"set_underground_view"), "no fade hook")
	ground.visible = true


func test_ground_cover_is_cleared_from_the_water_and_banks() -> void:
	"""Every tuft or mushroom standing in the water or on its bank has been hidden."""
	var built: Array = _built()
	var world: DemoWorld = built[0]
	var map: WaterMapScript = (built[1] as DemoWater).map()
	var near: int = 0
	for k: int in DemoWorld.MULTIMESH_KEYS.size():
		var at: PackedVector2Array = world.cover_positions(k)
		var hidden: PackedByteArray = world.cover_hidden(k)
		for i: int in at.size():
			if map.inside_margin_u(Vector2i(Rules.to_u(at[i].x), Rules.to_u(at[i].y))) > -WaterLayout.BANK_RUN_U:
				near += 1
				assert_equal(hidden[i], 1, "cover at %s hidden" % at[i])
	assert_true(near > 0, "%d cover pieces were by the water" % near)


func test_dressing_is_parented_under_the_village() -> void:
	"""So the underground view fades it with the village: boathouse, weir, shelter, mill, creels."""
	var world: DemoWorld = _built()[0]
	var village: Node = world.get_node(^"Village")
	for id: String in ["boathouse", "weir", "fisher_shelter", "mill", "creel_shelter", "creel_weir"]:
		assert_not_null(village.get_node_or_null(NodePath("Water_" + id)), "%s placed" % id)


func test_merged_lists_and_view_bounds() -> void:
	"""The cast gets the world's spots and circles plus the water's; the camera may look at the pond."""
	var built: Array = _built()
	var world: DemoWorld = built[0]
	var water: DemoWater = built[1]
	assert_equal(water.merged_points(world.points_of_interest()).size(),
		world.points_of_interest().size() + 3, "three water spots")
	assert_equal(water.merged_obstacles(world.obstacles()).size(),
		world.obstacles().size() + WaterDressing.obstacles().size(), "dressing circles")
	var view: AABB = DemoWater.view_bounds(Layout.bounds())
	assert_true(view.has_point(Vector3(27.8, 0.0, 28.0)) or view.end.z >= 28.0, "pond in view")
	assert_true(view.position.x <= -20.0 and view.end.x >= 36.0, "square and stream")


func test_the_overlay_has_no_key_of_its_own() -> void:
	"""V is the village's one overlay cycle (demo_farm.gd add_overlay), so the water takes no key:
	V, Shift+V and K leave it; set_overlay_shown shows and hides it, and says nothing twice."""
	var water: DemoWater = _built()[1]
	assert_false(water.overlay().visible, "hidden at first")
	assert_false(water.has_method(&"_unhandled_input"), "no key handler")
	water.set_overlay_shown(true)
	assert_true(water.overlay().visible, "shown")
	water.set_overlay_shown(true)
	assert_true(water.overlay().visible, "shown once, not toggled back")
	water.set_overlay_shown(false)
	assert_false(water.overlay().visible, "hidden")


func test_the_fishery_keeps_the_demo_calendar() -> void:
	"""Bound to the demo calendar, the fishery stands at the calendar's tick each frame -- the farm's
	and the HUD's day -- whatever the clock's microseconds; a paused frame moves nothing."""
	var water: DemoWater = _built()[1]
	var clock := DemoWater.DemoClockScript.new()
	var calendar := DemoWater.DemoCalendarScript.new()
	water.bind_clock(clock, calendar.tick)
	water.bind_calendar(calendar)
	calendar.tick = 18000 + 750
	clock.advance(0.1)
	water._process(0.1)
	assert_equal(water.fishing().completed_tick(), 18750, "a day and an hour: the calendar's tick")
	assert_equal(water.fishing().season_day(), 2, "the farm's day 2")
	clock.frame_usec = 0
	calendar.tick = 18750
	water._process(0.1)
	assert_equal(water.fishing().completed_tick(), 18750, "paused")


func test_a_flood_raises_the_stream_up_its_banks() -> void:
	"""set_flood_rise lifts the stream's surface (not the pond's) 900 permille of its 184 u drop at
	full flood, half that at half, and back to its level after."""
	var water: DemoWater = _built()[1]
	assert_equal(water.flood_rise_m(), 0.0, "at its level")
	water.set_flood_rise(1.0)
	assert_almost_equal(water.flood_rise_m(), Rules.to_m(184 * 900 / 1000), "brim-full")
	for node: MeshInstance3D in water.surface().nodes:
		var stream: bool = node.name == "WaterSurface_stream"
		assert_equal(node.position.y > 0.0, stream, "%s raised: %s" % [node.name, stream])
	water.set_flood_rise(0.5)
	assert_almost_equal(water.flood_rise_m(), Rules.to_m(184 * 900 / 1000) * 0.5, "half")
	water.set_flood_rise(0.0)
	assert_equal(water.flood_rise_m(), 0.0, "drained away")


func test_overlay_site_text_reads_the_fishery() -> void:
	"""The run's label is two short lines (decision 0205: five lines stacked over each other): the site, the
	river quota left and free slots; then each species' stock and state -- salmon shut until s2 d1."""
	var driver := _driver()
	var text: String = Overlay.site_text(driver, Driver.SITE_RUN, Driver.Preview.new())
	assert_equal(text.split("\n").size(), 2, "two lines: %s" % text)
	assert_equal(text.split("\n")[0], "stream_run  quota 52.5 / 52.5 U  slots 4 / 4", "site line")
	assert_true(text.split("\n")[1].begins_with("trout 480 open   "), "trout first: %s" % text)
	assert_true(text.split("\n")[1].ends_with("   salmon 480 shut to s2 d1"), "salmon shut: %s" % text)


# --- boundary cases the fixtures above cannot tell apart -------------------------------------------

func test_depth_rounds_up_so_any_water_is_wet() -> void:
	"""Bed 1000, ramp 512: 1 u inside is ceil(1000/512) = 2; bed 100 gives ceil(100/512) = 1, so a
	positive margin is always water."""
	var map := WaterMapScript.new(BANK)
	map.add_stream(&"r", PackedInt32Array([0, 0, 1024, 1000, 0, 10240, 1024, 1000]), DROP, 512, SPEED)
	assert_equal(map.depth_at(Vector2i(1023, 5120)), 2, "ceil(1000 / 512)")
	assert_equal(map.depth_at(Vector2i(1000, 5120)), 47, "ceil(1000 * 24 / 512) = ceil(46.875)")
	var shallow := WaterMapScript.new(BANK)
	shallow.add_stream(&"s", PackedInt32Array([0, 0, 1024, 100, 0, 10240, 1024, 100]), DROP, 512, SPEED)
	assert_equal(shallow.depth_at(Vector2i(1023, 5120)), 1, "ceil(100 / 512)")
	assert_true(shallow.is_water(Vector2i(1023, 5120)), "1 u inside is water")


func test_at_a_joint_the_upstream_leg_wins_the_tie() -> void:
	"""At the vertex shared by two legs both give the same margin; the lower index (upstream)
	decides the flow."""
	var map := WaterMapScript.new(BANK)
	map.add_stream(&"j", PackedInt32Array([0, 0, 1024, 512, 3000, 4000, 1024, 512, 8000, 4000, 1024, 512]),
		DROP, 256, 500)
	assert_equal(map.flow_at(Vector2i(3000, 4000)), Vector2i(300, 400), "upstream leg")
	assert_equal(map.flow_at(Vector2i(5000, 4000)), Vector2i(500, 0), "downstream leg")


func test_a_width_that_is_not_a_step_multiple_is_measured_to_the_unit() -> void:
	"""Half-width 1000 is not a multiple of the 64 u walk: bisection finds 2000 exactly."""
	var map := WaterMapScript.new(BANK)
	map.add_stream(&"w", PackedInt32Array([0, 0, 1000, 512, 0, 8192, 1000, 512]), DROP, 256, SPEED)
	assert_true(map.finalize().ok, "finalizes")
	assert_true(map.stream_width_at_into(Vector2i(0, 4096), _out), "measured")
	assert_equal(_out.value, 2000, "bank to bank")


func test_a_taper_is_judged_by_its_widest_end_for_tunnels() -> void:
	"""A leg widening from 512 to 2048: a tunnel 1500 u off its axis is refused (conservative)."""
	var map := WaterMapScript.new(BANK)
	map.add_stream(&"t", PackedInt32Array([0, 0, 512, 512, 0, 10240, 2048, 512]), DROP, 256, SPEED)
	assert_true(map.segment_crosses_water(Vector2i(1500, 0), Vector2i(1500, 1000), 0), "near the narrow end")
	assert_false(map.segment_crosses_water(Vector2i(2049, 0), Vector2i(2049, 1000), 0), "past the widest")


func test_a_leg_stopping_short_of_a_crossing_does_not_meet() -> void:
	"""(0,0)-(10,0) against a vertical leg at x = 12: they never meet, distance 2."""
	assert_equal(WaterMapScript.segment_distance_u(Vector2i(0, 0), Vector2i(10, 0), Vector2i(12, -5),
		Vector2i(12, 5)), 2, "T short of the crossing")


func test_salmon_gets_its_autumn_restock_on_the_new_day() -> void:
	"""The midnight into autumn day 1 (day 24, tick 24 * 18000 - 4500) runs on AUTUMN's calendar:
	salmon 480000 + 9600 + 3000 + 300000 is capped at K = 600000."""
	var driver := _driver(24 * TICKS_PER_DAY - 4500 - 1)
	assert_equal(driver.advance_ticks(1), 1, "one midnight")
	assert_equal([driver.season(), driver.season_day()], [2, 1], "autumn day 1")
	assert_equal(_preview(driver, Driver.SITE_RUN, 2, Fishing.GEAR_HAND_NET).stock_milli, 600000, "restocked")


func test_a_species_closed_mid_cycle_yields_a_true_zero() -> void:
	"""Trout set on spring day 4 and landed on day 5 (closed): the cycle completes with no lot."""
	var driver := _driver(3 * TICKS_PER_DAY + FIRST_MIDNIGHT - TICKS_PER_DAY + 1)
	assert_equal(driver.season_day(), 4, "spring day 4")
	var cycle: Driver.Cycle = driver.begin_cycle(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET)
	assert_true(cycle.ok, "set on day 4")
	driver.advance_ticks(TICKS_PER_DAY)
	var landed: Driver.CatchResult = driver.complete_cycle(cycle, 0)
	assert_true(landed.ok, "completes")
	assert_equal(landed.quantity_milli, 0, "nothing may be taken in the closure")
	assert_equal(landed.lots.size(), 0, "no lot")
	assert_equal(driver.open_claims(), 0, "slots freed")


func test_a_preview_shows_a_heavy_gear_must_queue_for_two_slots() -> void:
	"""With a weir (2) and a net (1) out, one river slot is free: a net may start, a weir must
	queue -- in the preview as well as at the start. A pond lot lands at the boathouse."""
	var driver := _driver()
	assert_true(driver.begin_cycle(Driver.SITE_RUN, 0, Fishing.GEAR_WEIR).ok, "a weir")
	assert_true(driver.begin_cycle(Driver.SITE_FORD, 1, Fishing.GEAR_HAND_NET).ok, "a net")
	var weir := _preview(driver, Driver.SITE_RUN, 1, Fishing.GEAR_WEIR)
	assert_equal(weir.slots_free, 1, "one slot left")
	assert_true(weir.must_queue, "a weir must queue")
	assert_equal(weir.block, Fishing.REFUSE_EFFORT_SLOTS_FULL, "and says why")
	assert_true(_preview(driver, Driver.SITE_FORD, 0, Fishing.GEAR_HAND_NET).ok, "a net may start")
	var pond: Driver.CatchResult = driver.resolve_cycle(Driver.SITE_POND, 1, Fishing.GEAR_TRAP, 0)
	assert_equal(pond.lots[0].landing, &"boathouse", "pond lots land at the boathouse")
	assert_equal(pond.lots[0].species_key, &"carp", "a carp lot")


func test_a_spent_quota_refuses_new_cycles() -> void:
	"""Take the river's whole 52500 milli-U day through the store: every river species then refuses
	QUOTA_REACHED, while the lake still fishes."""
	var driver := _driver()
	var ref: Vector2i = driver.habitat_ref_of_site(Driver.SITE_RUN)
	assert_true(driver.store().harvest(ref, 1, RIVER_QUOTA_MILLI, driver.season(), driver.season_day()).ok,
		"the day's quota taken as dace")
	assert_equal(driver.refusal(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET), Fishing.REFUSE_QUOTA_REACHED, "trout")
	assert_equal(driver.refusal(Driver.SITE_FORD, 1, Fishing.GEAR_HAND_NET), Fishing.REFUSE_QUOTA_REACHED, "dace")
	assert_equal(driver.refusal(Driver.SITE_POND, 0, Fishing.GEAR_HAND_NET), Driver.REFUSE_NONE, "the lake")


func test_a_cycle_whose_claim_was_released_elsewhere_cannot_complete() -> void:
	"""A Cycle object is not proof of a claim: once the store released it, completion refuses."""
	var driver := _driver()
	var cycle: Driver.Cycle = driver.begin_cycle(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET)
	assert_true(driver.store().release_effort_slots(cycle.expedition).ok, "released behind its back")
	var landed: Driver.CatchResult = driver.complete_cycle(cycle, 0)
	assert_false(landed.ok, "refused")
	assert_equal(landed.error, Driver.REFUSE_NOT_A_CYCLE, "the reason")
	assert_equal(_preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET).stock_milli, 480000, "nothing taken")


func test_ten_ids_are_refused_too() -> void:
	"""Exactly nine species: ten ids refuse as well as eight."""
	var ids := _ids()
	ids.append(ids[0] + 1000)
	assert_equal(Driver.create(ids, 0, 4404).error, Driver.REFUSE_SPECIES_IDS, "ten ids")


func test_each_lot_carries_its_own_species_item_id() -> void:
	"""A carp lot carries carp's catalog id (row 4), a dace lot dace's (row 1)."""
	var ids := _ids()
	var driver := _driver()
	var carp: Driver.CatchResult = driver.resolve_cycle(Driver.SITE_POND, 1, Fishing.GEAR_TRAP, 0)
	assert_equal(carp.lots[0].item_id, ids[Fishing.SPECIES_CARP], "carp")
	assert_equal(carp.quantity_milli, 9600, "trap: 12000 * 1000 * 800 * 1000 / 1e9")
	var dace: Driver.CatchResult = driver.resolve_cycle(Driver.SITE_FORD, 1, Fishing.GEAR_TRAP, 0)
	assert_equal(dace.lots[0].item_id, ids[Fishing.SPECIES_DACE], "dace")


func test_no_woodland_piece_stands_inside_the_dressing() -> void:
	"""The dressing's own footprints are woods blockers too: nothing the world scatters stands inside
	the boathouse, the weir, the shelter, the mill or a creel (the log behind the boathouse goes)."""
	var world: DemoWorld = DemoWorld.new()
	_nodes.append(world)
	world.build({"world": {}, "cast": {}})
	var footprints: Array[Vector3] = WaterDressing.footprint_circles()
	for child: Node in world.get_node(^"Village").get_children():
		if child is MeshInstance3D:
			var at: Vector3 = (child as Node3D).position
			assert_true(Layout.clearance(Vector2(at.x, at.z), footprints) >= 0.0,
				"piece at (%.1f, %.1f) is outside every dressing footprint" % [at.x, at.z])


func test_the_store_holds_each_stock_under_its_own_item_id() -> void:
	"""The estuary is generated habitat-major (fishing.gd HABITAT_SPECIES_ROWS), so the store's
	species_id column must read trout on the river's trout row and perch on the lake's perch row."""
	var ids := _ids()
	var driver := _driver()
	for site: int in [Driver.SITE_RUN, Driver.SITE_POND]:
		for species: int in 3:
			var row: int = driver.stock_row(site, species)
			assert_equal(driver.store().species_id_of(row).value, ids[driver.species_row_of(site, species)],
				"%s is stored under its own id" % driver.species_key_of(site, species))


func test_a_closure_ending_tonight_reopens_tomorrow() -> void:
	"""On spring day 7, the last closure day, trout reopens on day 8 -- the very next day."""
	var driver := _driver(6 * TICKS_PER_DAY - 4500 + 1)
	assert_equal(driver.season_day(), 7, "spring day 7 (day index 6 starts at 6 * 18000 - 4500)")
	var preview := _preview(driver, Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET)
	assert_true(preview.closed, "still closed")
	assert_equal([preview.reopen_season, preview.reopen_day], [0, 8], "tomorrow")


# --- the overlay's labels on screen (playtest 2026-09-29, decision 0205) -------------------------

func _shown_overlay() -> Overlay:
	"""The village water's overlay with its fishery bound and its labels texted, shown."""
	var water: DemoWater = _built()[1]
	var overlay: Overlay = water.overlay()
	overlay.set_driver(_driver(), water.map())
	overlay.toggle()
	overlay.refresh_text()
	return overlay


## The viewports the demo supports, smallest and project default (ui_ux_controls.md: 1280x720 up).
const VIEWPORTS: Array[Vector2] = [Vector2(1920.0, 1080.0), Vector2(1280.0, 720.0)]


func _eye_at(focus: Vector3, yaw_deg: float, distance: float) -> Transform3D:
	"""Where the demo's own camera rig puts its camera for this pose at its default pitch (the rig's
	transform times its camera's, out of the tree: the suite runs before the tree is live)."""
	var rig: DemoCamera = DemoCamera.new()
	_nodes.append(rig)
	rig.configure(AABB(Vector3(-60.0, 0.0, -60.0), Vector3(120.0, 1.0, 120.0)), focus)
	rig._target_yaw = deg_to_rad(yaw_deg)
	rig._target_distance = distance
	rig.snap()
	return rig.transform * rig.camera().transform


func _lay(overlay: Overlay, eye: Transform3D, view: Vector2) -> void:
	"""Lay the overlay out for the demo camera at `eye` over a `view`-sized viewport (the Camera3D's own
	projection: keep-height perspective at the rig's FOV and planes)."""
	var lens := Projection.create_perspective(DemoCamera.FOV_DEGREES, view.x / view.y, DemoCamera.NEAR_PLANE, DemoCamera.FAR_PLANE)
	overlay.lay_out_view(eye, lens, view, DemoCamera.FOV_DEGREES)


func _overlaps(overlay: Overlay, eye: Transform3D, view: Vector2) -> PackedStringArray:
	"""Every pair of laid-out labels whose screen rectangles overlap, after laying out for `eye`."""
	_lay(overlay, eye, view)
	var out := PackedStringArray()
	for a: int in overlay.laid_count():
		for b: int in range(a + 1, overlay.laid_count()):
			if overlay.label_shown(a) and overlay.label_shown(b) and overlay.screen_rect(a).intersects(overlay.screen_rect(b)):
				out.append("%d/%d %s %s" % [a, b, overlay.screen_rect(a), overlay.screen_rect(b)])
	return out


func _on_screen(overlay: Overlay, view: Vector2) -> int:
	"""How many laid-out labels have their rectangle's centre inside the viewport."""
	var count: int = 0
	for k: int in overlay.laid_count():
		count += 1 if overlay.label_shown(k) and Rect2(Vector2.ZERO, view).has_point(overlay.screen_rect(k).get_center()) else 0
	return count


func test_the_overlays_labels_never_overlap_on_screen() -> void:
	"""With the demo's real camera (Camera3D.unproject_position at the viewport's size): at the default
	pose, over the landings at the default zoom, zoomed right out, and zoomed out turned side-on (the
	landings then spread across the screen), no two labels' rectangles overlap -- and the three sites
	and the legend are all on screen zoomed out."""
	var overlay := _shown_overlay()
	var poses: Array[Array] = [[Vector3.ZERO, 0.0, DemoCamera.DISTANCE_DEFAULT],
		[Vector3(21.0, 0.0, 10.0), 0.0, DemoCamera.DISTANCE_DEFAULT], [Vector3.ZERO, 0.0, DemoCamera.DISTANCE_MAX],
		[Vector3(20.0, 0.0, 0.0), 90.0, DemoCamera.DISTANCE_MAX]]
	var lifted: float = 0.0
	for view: Vector2 in VIEWPORTS:
		for pose: Array in poses:
			var eye := _eye_at(pose[0], pose[1], pose[2])
			assert_equal(_overlaps(overlay, eye, view), PackedStringArray(), "overlaps at %s on %s" % [pose, view])
			for k: int in overlay.laid_count():
				lifted = maxf(lifted, overlay.lift_px(k))
		_lay(overlay, _eye_at(Vector3.ZERO, 0.0, DemoCamera.DISTANCE_MAX), view)
		assert_equal(_on_screen(overlay, view), 4, "the sites and the legend zoomed out on %s" % view)
		for k: int in overlay.laid_count():
			var rect: Rect2 = overlay.screen_rect(k)
			assert_true(rect.position.x >= 0.0 and rect.end.x <= view.x, "row %d kept inside %s: %s" % [k, view, rect])
	assert_true(lifted > 0.0, "side-on, a label had to rise to clear another")


func test_stacked_labels_rise_clear_of_each_other_lowest_first() -> void:
	"""stack_lifts_into on three 100 x 20 px rectangles at one spot and a hidden one there too: the lowest
	(largest y) stays, the next rises 20 + 6, the next 2 x 26; the hidden one is left at 0 and ignored;
	one far to the side never moves."""
	var centres := PackedVector2Array([Vector2(500, 300), Vector2(500, 298), Vector2(500, 296), Vector2(500, 300), Vector2(900, 300)])
	var sizes := PackedVector2Array([Vector2(100, 20), Vector2(100, 20), Vector2(100, 20), Vector2(100, 20), Vector2(100, 20)])
	var shown := PackedByteArray([1, 1, 1, 0, 1])
	var order := PackedInt32Array([0, 0, 0, 0, 0])
	var lifts := PackedFloat32Array([9.0, 9.0, 9.0, 9.0, 9.0])
	Overlay.stack_lifts_into(centres, sizes, shown, 6.0, order, lifts)
	assert_almost_equal(lifts[0], 0.0, "the lowest stays over its anchor")
	assert_almost_equal(300.0 - (298.0 - lifts[1]), 26.0, "the next sits 20 + 6 above it")
	assert_almost_equal(300.0 - (296.0 - lifts[2]), 52.0, "and the next above that")
	assert_almost_equal(lifts[3], 0.0, "a hidden one is not moved")
	assert_almost_equal(lifts[4], 0.0, "one clear to the side is not moved")


func test_a_site_whose_landing_the_map_lacks_is_not_labelled() -> void:
	"""A map with no landings: every site's label stays hidden and out of the layout -- none falls to the
	world origin (over the well) as it used to. On the village's map all three sit over their landings."""
	expect_diagnostic("WATER_UNKNOWN_LANDING")
	var overlay := Overlay.new()
	_nodes.append(overlay)
	overlay.set_driver(_driver(), _straight_stream())
	assert_equal(overlay.laid_count(), Driver.SITE_COUNT, "a row per site")
	for site: int in Driver.SITE_COUNT:
		assert_false(overlay.label_shown(overlay.site_row(site)), "site %d not laid out" % site)
		assert_false(overlay._labels[site].visible, "site %d hidden" % site)
	var village := _shown_overlay()
	for site: int in Driver.SITE_COUNT:
		assert_true(village.label_shown(village.site_row(site)), "village site %d laid out" % site)
		assert_true(village._labels[site].position.x > 20.0, "over the east bank: %s" % village._labels[site].position)


func test_a_label_is_drawn_from_its_anchor_and_over_the_zone_paint() -> void:
	"""A left-aligned Label3D starts its text at its anchor, so the layout's rectangle starts there too (a
	centred rectangle would test the wrong half of the screen); and every label draws after the zone
	paint, its outline first, so the translucent paint no longer washes the text out."""
	var overlay := _shown_overlay()
	var view := Vector2(1920.0, 1080.0)
	var eye := _eye_at(Vector3.ZERO, 0.0, DemoCamera.DISTANCE_MAX)
	_lay(overlay, eye, view)
	var lens := Projection.create_perspective(DemoCamera.FOV_DEGREES, view.x / view.y, DemoCamera.NEAR_PLANE, DemoCamera.FAR_PLANE)
	for k: int in overlay.laid_count():
		var anchor: Vector2 = Overlay.project_px(lens, eye.affine_inverse() * overlay._anchor[k], view)
		var width: float = overlay.screen_rect(k).size.x
		var nudge: float = Overlay.inside_nudge_px(anchor.x, width, view.x)
		assert_almost_equal(overlay.screen_rect(k).position.x, anchor.x + nudge, "row %d starts at its anchor, nudged %.1f" % [k, nudge])
		assert_almost_equal(overlay.screen_rect(k).get_center().y, anchor.y - overlay.lift_px(k), "row %d centred on it, lifted" % k)
	var scale: float = Overlay.screen_px_per_label_px(view.y, DemoCamera.FOV_DEGREES)
	for site: int in Driver.SITE_COUNT:
		var label: Label3D = overlay._labels[site]
		var row: int = overlay.site_row(site)
		assert_true(label.outline_render_priority > Overlay.RENDER_PRIORITY, "outline after the paint")
		assert_true(label.render_priority > label.outline_render_priority, "text after its outline")
		assert_true(overlay.screen_rect(row).size.is_equal_approx(Overlay.label_size_px(label) * scale), "site %d measured as texted" % site)
	_lay(overlay, _eye_at(Vector3(20.0, 0.0, 0.0), 90.0, DemoCamera.DISTANCE_MAX), view)
	var lifted: int = 0
	for k: int in overlay.laid_count():
		assert_almost_equal(overlay._laid[k].offset.y * scale, overlay.lift_px(k), "row %d drawn raised by its lift (offset +y is up)" % k)
		lifted += 1 if overlay.lift_px(k) > 1.0 else 0
	assert_true(lifted > 0, "side-on, some row is lifted (%d)" % lifted)


func test_a_label_pixel_covers_the_fixed_size_screen_share() -> void:
	"""A fixed-size Label3D pixel covers LABEL_PIXEL_SIZE x (height / 2) / tan(fov / 2) screen pixels: 0.6677
	at 1080 px and the demo's 40 degrees (restated: 0.00045 x 540 / tan 20); a label's block is its
	font's text size plus the outline on each side; and a new body re-measures the legend."""
	assert_almost_equal(Overlay.screen_px_per_label_px(1080.0, 40.0), 0.00045 * 540.0 / tan(deg_to_rad(20.0)), "pixel share")
	var label := Label3D.new()
	label.font_size = 26
	label.outline_size = 8
	label.text = "trout 480 open"
	var bare: Vector2 = ThemeDB.fallback_font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26)
	assert_true(Overlay.label_size_px(label).is_equal_approx(bare + Vector2(16.0, 16.0)), "text plus 8 px of outline a side")
	label.free()
	var overlay := _shown_overlay()
	var legend: int = overlay._laid.find(overlay._legend)
	var before: float = overlay._size_label_px[legend].x
	overlay.set_body("Badger quarryman %s (2.55 m)" % "x".repeat(120), 2611)
	assert_true(overlay._size_label_px[legend].x > before, "the legend re-measured for its first line, now its longest")
	assert_true(overlay._size_label_px[legend].is_equal_approx(Overlay.label_size_px(overlay._legend)), "as texted")


func test_a_label_is_nudged_inside_the_view_only_when_its_landing_is_on_screen() -> void:
	"""inside_nudge_px on a 1000 px view with a 6 px gap: a 300 px label starting at 800 slides 106 px left;
	one that fits is left; one whose anchor is off screen (either side) is left off it; one wider than the
	view keeps its left edge at the gap."""
	assert_almost_equal(Overlay.inside_nudge_px(800.0, 300.0, 1000.0), -106.0, "slid back inside")
	assert_almost_equal(Overlay.inside_nudge_px(100.0, 300.0, 1000.0), 0.0, "fits already")
	assert_almost_equal(Overlay.inside_nudge_px(1200.0, 300.0, 1000.0), 0.0, "anchor off to the right")
	assert_almost_equal(Overlay.inside_nudge_px(-50.0, 300.0, 1000.0), 0.0, "anchor off to the left")
	assert_almost_equal(Overlay.inside_nudge_px(200.0, 1200.0, 1000.0), -194.0, "too wide: left edge at the gap")
