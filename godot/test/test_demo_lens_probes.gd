extends "res://test/framework/test_case.gd"
## The map layers' probes, scales, colour tokens and colour-blind check (decision 0581): what each layer says about a
## ground point, from the simulation's own integers (a bed's moisture against its own band, its ripeness hours, the
## leat's service; the water's depth against the painted body's thresholds, the pond's ice; a tree and its zone), at
## every boundary; that reading a point allocates nothing; that the legends' figures are the rules' own; and that
## every layer's area colours stay apart for deuteranopia and protanopia, by day and by night.
##
## No scene tree and no staged assets: the farm sim, the village's water map and a stand are built as their own suites
## build them.

const ProbeScript := preload("res://demo/lenses/lens_probe.gd")
const BedProbe := preload("res://demo/lenses/bed_lens_probe.gd")
const WaterProbe := preload("res://demo/lenses/water_lens_probe.gd")
const WoodsProbe := preload("res://demo/lenses/woods_lens_probe.gd")
const Scales := preload("res://demo/lenses/lens_scales.gd")
const LensPalette := preload("res://demo/lenses/lens_palette.gd")
const ColourCheck := preload("res://demo/lenses/lens_colour_check.gd")
const LensesScript := preload("res://demo/map_lenses.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Look := preload("res://demo/farm/farm_look.gd")
const Sluice := preload("res://demo/water/weir_sluice.gd")
const Farming := preload("res://scripts/core/farming.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterOverlayScript := preload("res://demo/water/water_overlay.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const ForestMarks := preload("res://demo/forestry/forest_marks.gd")
const WoodlandPalette := preload("res://demo/ui/woodland_palette.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC

## test_demo_farm.gd's beds: an empty loam bed, carrots (roots, 2500-7000), radish.
const BED_EMPTY: int = 0
const BED_CLAY: int = 1
const BED_CARROTS: int = 2
const WOOD: int = 60
const MOUSE_U: int = 1024
const CALLS: int = 500

static var _map_cache: WaterMapScript = null

var _nodes: Array[Node] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _reading: ProbeScript.Reading = ProbeScript.Reading.new()


func after_each() -> void:
	"""Free every node a test made."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


static func _map() -> WaterMapScript:
	"""The village's water, built once (immutable once finalised)."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	return _map_cache


func _overlay() -> WaterOverlayScript:
	"""An unbuilt water overlay: only its body and ice fields are read."""
	var overlay := WaterOverlayScript.new()
	_nodes.append(overlay)
	return overlay


func _deep_point(map: WaterMapScript) -> Vector2:
	"""The middle of the deepest measured station (metres)."""
	var best: int = 0
	for s: int in map.station_count():
		if map.station_depth_u(s) > map.station_depth_u(best):
			best = s
	var a: Vector2i = map.station_a(best)
	var b: Vector2i = map.station_b(best)
	return Vector2(WaterRules.to_m(a.x + b.x), WaterRules.to_m(a.y + b.y)) * 0.5


# --- the base probe -------------------------------------------------------------------------------------

func test_the_base_probe_says_nothing_and_cannot_outline() -> void:
	"""A layer without a probe of its own: no reading, no words, no field."""
	var probe := ProbeScript.new()
	_reading.entry = 3
	assert_false(probe.read_into(Vector2.ZERO, _reading), "nothing to say")
	assert_equal(_reading.entry, -1, "the reading cleared")
	assert_equal(probe.describe(_reading), "", "no words")
	assert_false(probe.can_outline(), "not comparable")
	assert_false(probe.field_bounds_m().has_area(), "no field")
	assert_equal(probe.field_cell_m(), ProbeScript.CELL_M, "the default cell")
	assert_equal(probe.draw_y_m(), ProbeScript.DRAW_Y_M, "drawn just over the ground")
	assert_equal(probe.field_revision(), 0, "never moves")
	assert_true(probe.legend_ticks().is_empty() and probe.legend_caption().is_empty(), "fixed legend")


func test_a_reading_compares_and_copies_every_field() -> void:
	"""Two readings are the same only when entry, area, value and who all agree."""
	var a := ProbeScript.Reading.new()
	var b := ProbeScript.Reading.new()
	a.entry = 1
	a.area = 2
	a.value = 3
	a.who = 4
	assert_false(a.same_as(b), "different")
	b.copy_from(a)
	assert_true(a.same_as(b), "copied")
	for field: StringName in [&"entry", &"area", &"value", &"who"]:
		b.copy_from(a)
		b.set(field, 99)
		assert_false(a.same_as(b), "differs in %s" % field)
	a.clear()
	assert_equal([a.entry, a.area, a.value, a.who], [-1, -1, 0, -1], "cleared")


# --- the beds ---------------------------------------------------------------------------------------------

func test_a_bed_is_read_inside_its_square_and_nowhere_else() -> void:
	"""The bed's square (farm_catalog.gd's 1.5 m half side), edge included; just past it, nothing."""
	var probe := BedProbe.new(SimScript.new(), BedProbe.MODE_MOISTURE)
	var centre: Vector2 = Catalog.bed_centre_m(BED_CARROTS)
	assert_equal(probe.bed_at(centre), BED_CARROTS, "the centre")
	assert_equal(probe.bed_at(centre + Vector2(Catalog.BED_HALF_M, -Catalog.BED_HALF_M)), BED_CARROTS, "the corner")
	assert_equal(probe.bed_at(centre + Vector2(Catalog.BED_HALF_M + 0.01, 0.0)), -1, "just outside")
	assert_true(probe.read_into(centre, _reading), "read")
	assert_equal([_reading.who, _reading.entry, _reading.area], [BED_CARROTS, SimScript.BAND_GOOD, SimScript.BAND_GOOD],
		"carrots, good")
	assert_equal(_reading.value, 6000, "§5.1's opening moisture, exactly")
	assert_false(probe.read_into(Vector2(500.0, 500.0), _reading), "off the garden")
	assert_true(probe.can_outline() and probe.field_bounds_m().has_point(centre), "the garden is its field")
	assert_equal(probe.draw_y_m(), BedProbe.DISC_Y_M, "over the beds' discs")
	assert_equal(probe.field_cell_m(), BedProbe.BED_CELL_M, "a finer grid")


func test_the_moisture_words_give_the_bed_s_own_band_edges() -> void:
	"""Carrots (roots 25-70%, ±20): 'dry <5% · low <25% · wet ≤90% · waterlogged >90%'; the empty bed's 40-80% reaches
	the scale's top, so it says 'wet above 80%' and no waterlogged edge."""
	var sim := SimScript.new()
	var carrot: String = Catalog.ITEM_LABELS[sim.item_of(BED_CARROTS)]
	assert_equal(BedProbe.moisture_text(sim, BED_CARROTS), "Soil moisture 60%% · good\nBed 3, %s: good 25–70%%\n" % carrot
		+ "dry <5% · low <25% · wet ≤90% · waterlogged >90%", "carrots")
	assert_equal(BedProbe.moisture_text(sim, BED_EMPTY), "Soil moisture 60% · good\nBed 1, empty: good 40–80%\n"
		+ "dry <20% · low <40% · wet above 80%", "the empty bed")
	assert_equal(BedProbe.band_edges(2000, 7000), PackedStringArray(["low <20%", "wet ≤90% · waterlogged >90%"]),
		"a band whose dry edge is at 0: no dry")
	assert_equal(BedProbe.band_edges(2500, 7999), PackedStringArray(["dry <5%", "low <25%", "wet ≤99% · waterlogged >99%"]),
		"the top one unit short of the scale's: waterlogging still possible")
	assert_equal(BedProbe.band_edges(2500, 8000), PackedStringArray(["dry <5%", "low <25%", "wet above 80%"]),
		"the top at the scale's: none")
	var probe := BedProbe.new(sim, BedProbe.MODE_MOISTURE)
	probe.read_into(Catalog.bed_centre_m(BED_CARROTS), _reading)
	assert_equal(probe.describe(_reading), BedProbe.moisture_text(sim, BED_CARROTS), "the probe's words")


func test_the_reading_follows_the_sim_and_the_field_moves_only_on_a_new_colour() -> void:
	"""A flood down the open leat lifts a bed past its band: its entry changes and the field revision moves; an hour
	that changes no bed's band moves the value, not the field."""
	var sim := SimScript.new()
	var probe := BedProbe.new(sim, BedProbe.MODE_MOISTURE)
	var field: int = probe.field_revision()
	sim.advance_usec(HOUR_USEC)
	assert_equal(probe.field_revision(), field, "an hour, no band changed: the outline stands")
	sim.set_leat_service(BED_CLAY, Sluice.SERVICE_WET)
	assert_true(sim.apply_flood_surge(BED_CLAY) > 0, "the flood rose")
	assert_true(probe.read_into(Catalog.bed_centre_m(BED_CLAY), _reading), "read")
	assert_equal(_reading.entry, sim.band_of(BED_CLAY), "the band now")
	assert_true(_reading.entry >= SimScript.BAND_WET, "wet or waterlogged")
	assert_equal(_reading.value, sim.moisture_of(BED_CLAY), "the moisture now")
	assert_true(probe.field_revision() > field, "the outline is redrawn")


func test_choosing_a_crop_re_words_the_bed_with_its_moisture_unchanged() -> void:
	"""Bed 1 empty, then carrots chosen: same moisture, same band, new band edges -- the words revision moves."""
	var sim := SimScript.new()
	var probe := BedProbe.new(sim, BedProbe.MODE_MOISTURE)
	probe.read_into(Catalog.bed_centre_m(BED_EMPTY), _reading)
	var words: int = probe.words_revision()
	var field: int = probe.field_revision()
	assert_true(sim.choose(BED_EMPTY, sim.item_of(BED_CARROTS)).ok, "carrots chosen")
	var after := ProbeScript.Reading.new()
	probe.read_into(Catalog.bed_centre_m(BED_EMPTY), after)
	assert_true(after.same_as(_reading), "the same reading")
	assert_true(probe.words_revision() != words, "the words revision moved")
	assert_equal(probe.field_revision(), field, "the outline stands")
	assert_true(probe.describe(after).contains("good 25–70%"), probe.describe(after))


func test_ripeness_entries_split_at_the_grace_and_the_loss() -> void:
	"""Growing; ripe under 48 h; at 48 h past its best; withered and blighted lost; empty."""
	assert_equal(BedProbe.ripeness_entry(SimScript.STAGE_GROWING, 0), BedProbe.RIPENESS_GROWING, "growing")
	assert_equal(BedProbe.ripeness_entry(SimScript.STAGE_SOWN, 0), BedProbe.RIPENESS_GROWING, "sown")
	assert_equal(BedProbe.ripeness_entry(SimScript.STAGE_RIPE, Look.GRACE_HOURS - 1), BedProbe.RIPENESS_RIPE, "47 h")
	assert_equal(BedProbe.ripeness_entry(SimScript.STAGE_RIPE, Look.GRACE_HOURS), BedProbe.RIPENESS_LATE, "48 h")
	assert_equal(BedProbe.ripeness_entry(SimScript.STAGE_WITHERED, 0), BedProbe.RIPENESS_LATE, "withered")
	assert_equal(BedProbe.ripeness_entry(SimScript.STAGE_BLIGHTED, 0), BedProbe.RIPENESS_LATE, "blighted")
	assert_equal(BedProbe.ripeness_entry(SimScript.STAGE_EMPTY, 0), BedProbe.RIPENESS_EMPTY, "empty")
	assert_equal(BedProbe.LOST_HOURS, 120, "lost at 120 h (farming.gd RIPE_WITHER_HOURS)")


func test_the_ripeness_words_give_growth_hours_or_hours_ripe() -> void:
	"""Carrots 80% grown with the sim's own hours to ripen; ripe a day later with hours ripe; stalled and lost words."""
	var sim := SimScript.new()
	var probe := BedProbe.new(sim, BedProbe.MODE_RIPENESS)
	var carrot: String = Catalog.ITEM_LABELS[sim.item_of(BED_CARROTS)]
	probe.read_into(Catalog.bed_centre_m(BED_CARROTS), _reading)
	assert_true(sim.hours_to_ripe_into(BED_CARROTS, _read), "growing")
	assert_equal(probe.describe(_reading), "Bed 3, %s · 80%% grown\nripe in about %d h at this hour's rate" % [carrot,
		_read.value], "growing")
	sim.advance_usec(25 * HOUR_USEC)
	probe.read_into(Catalog.bed_centre_m(BED_CARROTS), _reading)
	assert_equal(_reading.entry, BedProbe.RIPENESS_RIPE, "ripe")
	assert_true(sim.ripe_hours_into(BED_CARROTS, _read), "hours ripe")
	assert_equal(probe.describe(_reading), "Bed 3, %s · ripe %d h\nbest within 48 h · lost at 120 h" % [carrot, _read.value],
		"ripe")
	var late: int = SimScript.STAGE_RIPE * BedProbe.STAGE_SPAN + 1000 * BedProbe.HOURS_SPAN + 60
	assert_true(BedProbe.ripeness_text(sim, BED_CARROTS, late).ends_with("past its best · lost at 120 h"), "60 h")
	var stalled: int = SimScript.STAGE_GROWING * BedProbe.STAGE_SPAN + 500 * BedProbe.HOURS_SPAN + BedProbe.STALLED
	assert_true(BedProbe.ripeness_text(sim, BED_CARROTS, stalled).ends_with("50% grown\nnot growing now (stalled)"), "stalled")
	for stage: int in [SimScript.STAGE_EMPTY, SimScript.STAGE_WITHERED, SimScript.STAGE_BLIGHTED]:
		var words: String = BedProbe.ripeness_text(sim, BED_EMPTY, stage * BedProbe.STAGE_SPAN)
		assert_true(words.begins_with("Bed 1") and words.contains("\n"), "stage %d: %s" % [stage, words])


func test_the_service_words_quote_the_leat_s_figures() -> void:
	"""Not served, dry, normal (15 points a day to the middle) and wet (15 a day, to 10 over)."""
	var sim := SimScript.new()
	var probe := BedProbe.new(sim, BedProbe.MODE_SERVICE)
	sim.set_leat_service(BED_CLAY, Sluice.SERVICE_NORMAL)
	probe.read_into(Catalog.bed_centre_m(BED_CLAY), _reading)
	assert_equal([_reading.entry, _reading.value], [Sluice.SERVICE_NORMAL, Sluice.SERVICE_NORMAL], "normal")
	assert_equal(probe.describe(_reading), "Bed 2 · leat: normal\nup to 15 points a day toward its good range's middle", "normal")
	assert_equal(BedProbe.service_text(1, Sluice.SERVICE_WET), "Bed 2 · leat: wet\nup to 15 points a day, to 10 over its good range", "wet")
	assert_equal(BedProbe.service_text(1, Sluice.SERVICE_DRY), "Bed 2 · leat: dry\nthe leat runs empty: it adds nothing", "dry")
	assert_true(BedProbe.service_text(0, Sluice.SERVICE_NONE).begins_with("Bed 1 · not on the garden leat"), "none")


func test_reading_a_bed_allocates_nothing() -> void:
	"""After the hour's re-read, a pointer read is a lookup."""
	var probe := BedProbe.new(SimScript.new(), BedProbe.MODE_RIPENESS)
	var at: Vector2 = Catalog.bed_centre_m(BED_CARROTS)
	probe.read_into(at, _reading)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory: int = OS.get_static_memory_usage()
	for k: int in CALLS:
		probe.read_into(at + Vector2(0.001 * float(k % 7), 0.0), _reading)
		probe.field_revision()
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object")
	assert_equal(OS.get_static_memory_usage(), memory, "no memory")


# --- the water --------------------------------------------------------------------------------------------

func test_the_water_is_read_to_the_unit_with_its_zone() -> void:
	"""The deepest station: its depth from the map itself, a dive for the mouse; dry land reads nothing."""
	var map: WaterMapScript = _map()
	var probe := WaterProbe.new(map, _overlay())
	var deep: Vector2 = _deep_point(map)
	assert_true(probe.read_into(deep, _reading), "in the water")
	var at := Vector2i(WaterRules.to_u(deep.x), WaterRules.to_u(deep.y))
	assert_equal(_reading.value, map.depth_at(at), "the map's own depth")
	assert_equal(_reading.entry, WaterRules.zone_for_depth(_reading.value, MOUSE_U) - WaterRules.ZONE_WADE, "its zone")
	assert_equal(_reading.area, _reading.entry, "its area")
	assert_false(probe.read_into(Vector2(-200.0, -200.0), _reading), "far from the water")
	assert_true(probe.can_outline() and probe.field_bounds_m().has_point(deep), "the water is its field")


func test_the_pond_reads_as_its_ice_and_the_stream_as_water() -> void:
	"""Thin ice over the pond: the pond's landing reads thin ice (safe ice when safe); the stream still reads its zone."""
	var map: WaterMapScript = _map()
	var overlay := _overlay()
	var probe := WaterProbe.new(map, overlay)
	var pond := Vector2.INF
	for k: int in map.landing_count():
		if map.body_kind(map.landing_body(k)) == WaterMapScript.KIND_POND:
			var water := Vector2(WaterRules.to_m(map.landing_water(k).x), WaterRules.to_m(map.landing_water(k).y))
			var land := Vector2(WaterRules.to_m(map.landing_land(k).x), WaterRules.to_m(map.landing_land(k).y))
			pond = water + (water - land).normalized() * 1.5
	assert_true(pond != Vector2.INF, "the village has a pond landing")
	assert_true(probe.read_into(pond, _reading) and _reading.entry <= 2, "open water: a zone")
	overlay.ice_state = WaterProbe.ICE_THIN
	assert_true(probe.read_into(pond, _reading), "iced")
	assert_equal([_reading.entry, _reading.area], [WaterProbe.ENTRY_THIN_ICE, WaterProbe.ENTRY_THIN_ICE], "thin ice")
	overlay.ice_state = WaterProbe.ICE_SAFE
	probe.read_into(pond, _reading)
	assert_equal(_reading.entry, WaterProbe.ENTRY_SAFE_ICE, "safe ice")
	probe.read_into(_deep_point(map), _reading)
	assert_true(_reading.entry <= 2, "the stream is not iced")


func test_the_water_words_hold_the_shallower_zone_at_a_threshold() -> void:
	"""0.25 m exactly is wading for the mouse, one unit more is swimming; 1.00 m swimming, one more diving."""
	var overlay := _overlay()
	var probe := WaterProbe.new(_map(), overlay)
	var reading := ProbeScript.Reading.new()
	reading.entry = 0
	for row: Array in [[256, "wade"], [257, "swim"], [1024, "swim"], [1025, "dive"]]:
		reading.value = row[0]
		assert_true(probe.describe(reading).begins_with("Water %.2f m deep · %s\n" % [WaterRules.to_m(row[0]), row[1]]),
			"%d u: %s" % [row[0], probe.describe(reading)])
	reading.value = 300
	assert_true(probe.describe(reading).ends_with("for a 1.0 m mouse: wade ≤0.25 m · swim ≤1.00 m · dive deeper"), "the thresholds")
	overlay.body_height_u = 2611
	assert_equal(WaterProbe.thresholds_text(2611), "wade ≤0.64 m · swim ≤2.55 m · dive deeper", "a badger's")


func test_the_water_legend_and_field_follow_the_painted_body_and_the_ice() -> void:
	"""The ramp's depths are the painted body's; the field revision moves with the body and the ice; ice reads as
	ice over the pond."""
	var overlay := _overlay()
	var probe := WaterProbe.new(_map(), overlay)
	assert_equal(probe.legend_ticks(), PackedStringArray(["≤0.25 m", "≤1.00 m", ">1.00 m"]),
		"the mouse")
	assert_false(probe.legend_caption().is_empty(), "a caption")
	var field: int = probe.field_revision()
	overlay.body_height_u = 1126
	assert_true(probe.field_revision() != field, "another body")
	field = probe.field_revision()
	overlay.ice_state = WaterProbe.ICE_THIN
	overlay.ice_mm = 40
	assert_true(probe.field_revision() != field, "the ice")
	field = probe.field_revision()
	var words: int = probe.words_revision()
	overlay.ice_mm = 41
	assert_equal(probe.field_revision(), field, "a millimetre more: no outline redrawn")
	assert_true(probe.words_revision() != words, "but new words")
	words = probe.words_revision()
	overlay.body_label = "Mouse keeper (1.00 m)"
	assert_true(probe.words_revision() != words, "another body of the same height: new words")
	overlay.ice_mm = 40
	var reading := ProbeScript.Reading.new()
	reading.entry = WaterProbe.ENTRY_THIN_ICE
	assert_equal(probe.describe(reading), "Pond ice 40 mm · thin\nkeep off", "thin ice")
	reading.entry = WaterProbe.ENTRY_SAFE_ICE
	assert_true(probe.describe(reading).begins_with("Pond ice 40 mm · safe"), "safe ice")
	assert_false(WaterProbe.shore_bounds_m(WaterMapScript.new(4096)).has_area(), "a map with no water has no field")


func test_reading_the_water_allocates_nothing() -> void:
	"""One field evaluation into the probe's own sample."""
	var probe := WaterProbe.new(_map(), _overlay())
	var deep: Vector2 = _deep_point(_map())
	probe.read_into(deep, _reading)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory: int = OS.get_static_memory_usage()
	for k: int in CALLS:
		probe.read_into(deep + Vector2(0.01 * float(k % 11), 0.0), _reading)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object")
	assert_equal(OS.get_static_memory_usage(), memory, "no memory")


# --- the woods ----------------------------------------------------------------------------------------------

func _woods() -> Array:
	"""An oak, a beech and a sapling, and a forestry zone round the oak; [stand, zones]."""
	var stand := StandScript.new()
	assert_true(stand.bind_into([
		{"key": &"oak_mature", "at": Vector2(-10.0, -24.0), "yaw": 0.0, "size": 1.0},
		{"key": &"beech_mature", "at": Vector2(0.0, -24.0), "yaw": 0.5, "size": 1.1},
		{"key": &"oak_sapling", "at": Vector2(10.0, -24.0), "yaw": 0.0, "size": 1.0},
	] as Array[Dictionary], WOOD, 1, _read), "bound")
	var zones := ZonesScript.new()
	assert_true(ForestRules.tile_of_into(Vector2(-10.0, -24.0), _read), "the oak's tile")
	@warning_ignore("integer_division")
	var tz: int = _read.value / 128
	var tx: int = _read.value % 128
	assert_true(zones.add_into(ZonesScript.KIND_FORESTRY, Vector2i(tx - 1, tz - 1), Vector2i(tx + 1, tz + 1), "Oak copse",
		_read), "zoned")
	return [stand, zones]


func test_a_tree_and_its_zone_are_read() -> void:
	"""Over the oak: the oak, in its forestry zone; beside it in the zone: the zone; the beech outside any zone: the
	beech; open ground: nothing."""
	var woods: Array = _woods()
	var probe := WoodsProbe.new(woods[0], woods[1])
	assert_true(probe.read_into(Vector2(-10.0, -24.0), _reading), "the oak")
	assert_equal([_reading.entry, _reading.area, _reading.who], [2, WoodsProbe.ENTRY_FORESTRY, 0],
		"a mature tree (the legend's third entry) in a forestry zone")
	assert_true(probe.describe(_reading).begins_with("Oak · mature tree\nforestry zone Oak copse: "), probe.describe(_reading))
	assert_true(probe.read_into(Vector2(-11.5, -25.5), _reading), "in the zone, no tree in reach")
	assert_equal([_reading.entry, _reading.who], [WoodsProbe.ENTRY_FORESTRY, WoodsProbe.ZONE_WHO], "the zone")
	assert_true(probe.describe(_reading).begins_with("Forestry zone Oak copse\n"), probe.describe(_reading))
	assert_true(probe.read_into(Vector2(0.0, -24.0), _reading), "the beech")
	assert_equal(_reading.area, -1, "in no zone")
	assert_true(probe.describe(_reading).ends_with("in no zone: the woods' own"), probe.describe(_reading))
	assert_true(probe.read_into(Vector2(10.0, -24.0), _reading), "the sapling")
	assert_equal(probe.describe(_reading).get_slice("\n", 0), "Young oak", "a young tree by its own name")
	assert_equal(_reading.entry, 3, "the legend's young tree")
	assert_false(probe.read_into(Vector2(40.0, 40.0), _reading), "open ground")


func test_the_woods_outline_samples_zones_only_and_a_fell_re_words() -> void:
	"""`area_at_into` over the oak: its zone's class, no tree; a fell moves the words revision, not the field."""
	var woods: Array = _woods()
	var stand: StandScript = woods[0]
	var probe := WoodsProbe.new(stand, woods[1])
	assert_true(probe.area_at_into(Vector2(-10.0, -24.0), _reading), "in the zone")
	assert_equal([_reading.area, _reading.entry, _reading.who], [WoodsProbe.ENTRY_FORESTRY, -1, -1], "the zone only")
	assert_false(probe.area_at_into(Vector2(0.0, -24.0), _reading), "the beech: no zone")
	var field: int = probe.field_revision()
	var words: int = probe.words_revision()
	assert_true(stand.fell_into(0, 2, Vector2(1.0, 0.0), false, _read), "the oak felled")
	assert_equal(probe.field_revision(), field, "the zones stand")
	assert_true(probe.words_revision() != words, "the words move")


func test_the_woods_field_is_its_zones() -> void:
	"""No zones: nothing to outline; a zone: its ground with a margin; the field revision is the zones'."""
	var woods: Array = _woods()
	var zones: ZonesScript = woods[1]
	var probe := WoodsProbe.new(woods[0], ZonesScript.new())
	assert_false(probe.can_outline(), "no zones")
	probe = WoodsProbe.new(woods[0], zones)
	assert_true(probe.can_outline(), "a zone")
	assert_true(probe.field_bounds_m().encloses(zones.rect_m(0)), "round the zone")
	assert_equal(probe.field_revision(), zones.revision, "the zones' revision")


# --- the scales and the colours -----------------------------------------------------------------------------

func test_the_scales_reach_their_layers_and_quote_the_rules() -> void:
	"""Each row finds its layer by group and label and writes its ramp, ticks, caption, ground and areas; the words'
	figures are the rules' own."""
	var lenses := LensesScript.new()
	var noop := func(_on: bool) -> void: pass
	var moisture: int = lenses.add("Growing", "Soil moisture", "?", noop)
	var water: int = lenses.add("Getting there", "Water range", "?", noop)
	lenses.add("Somewhere", "Else", "?", noop)
	assert_equal(Scales.apply(lenses), 2, "two of the rows' layers here")
	assert_equal([lenses.ramp_from_of(moisture), lenses.ramp_count_of(moisture)], [0, 5], "five moisture bands")
	assert_equal(lenses.ticks_of(moisture).size(), 5, "a threshold each")
	assert_equal(lenses.over_of(moisture), LensPalette.OVER_SOIL, "over soil")
	assert_equal(lenses.area_entries(water), PackedInt32Array([0, 1, 2, 7, 8]), "the water's zones and the ice")
	assert_true(Scales.check_figures().is_empty(), ", ".join(Scales.check_figures()))


func test_the_overlays_paint_with_the_tokens() -> void:
	"""The bed discs and the water's zones read lens_palette.gd: one colour per thing everywhere."""
	assert_equal(Look.BAND_OVERLAY, LensPalette.MOISTURE, "moisture")
	assert_equal([Look.UNRIPE_OVERLAY, Look.RIPE_OVERLAY, Look.LATE_OVERLAY, Look.NO_OVERLAY],
		[LensPalette.GROWING, LensPalette.RIPE, LensPalette.LATE, LensPalette.EMPTY], "ripeness")
	assert_equal(Look.SERVICE_OVERLAY, LensPalette.SERVICE, "service")
	assert_equal([WaterOverlayScript.WADE_COLOUR, WaterOverlayScript.SWIM_COLOUR, WaterOverlayScript.DIVE_COLOUR],
		[LensPalette.WADE, LensPalette.SWIM, LensPalette.DIVE], "water")
	var logged: Color = LensPalette.MOISTURE[SimScript.BAND_WATERLOGGED]
	assert_true(logged.a < 0.5 and logged.b - logged.r < 0.3, "waterlogged stays a calm tint")


func test_every_ramp_passes_the_colour_blind_check() -> void:
	"""Moisture, ripeness, service and the water's zones and ice: no pair under the floors, any vision, day or night."""
	var water: PackedColorArray = [LensPalette.WADE, LensPalette.SWIM, LensPalette.DIVE,
		WaterOverlayScript.ICE_SAFE_COLOUR, WaterOverlayScript.ICE_THIN_COLOUR]
	var ripeness: PackedColorArray = [LensPalette.GROWING, LensPalette.RIPE, LensPalette.LATE, LensPalette.EMPTY]
	for row: Array in [[PackedColorArray(LensPalette.MOISTURE), LensPalette.OVER_SOIL, "moisture"],
			[ripeness, LensPalette.OVER_SOIL, "ripeness"], [PackedColorArray(LensPalette.SERVICE), LensPalette.OVER_SOIL,
			"service"], [water, LensPalette.OVER_WATER, "water"]]:
		var failing: PackedStringArray = ColourCheck.failures(row[0], row[1], PackedStringArray())
		assert_true(failing.is_empty(), "%s: %s" % [row[2], "; ".join(failing)])


func test_the_woods_marks_pass_the_colour_blind_check() -> void:
	"""The Woods layer's six marks -- two zones, four tree states -- clear decision 0581's floors over the grass, any
	vision, in the legend, by day and by night (decision 1044), and each tree state draws its legend entry's colour."""
	var failing: PackedStringArray = ColourCheck.failures(PackedColorArray(ForestMarks.LEGEND_COLOURS),
		LensPalette.OVER_GRASS, PackedStringArray(ForestMarks.LEGEND_NAMES))
	assert_true(failing.is_empty(), "; ".join(failing))
	assert_equal(ForestMarks.STATE_COLOURS[StandScript.STATE_MATURE], ForestMarks.MATURE_COLOUR, "mature")
	assert_equal(ForestMarks.STATE_COLOURS[StandScript.STATE_YOUNG], ForestMarks.YOUNG_COLOUR, "young")
	assert_equal(ForestMarks.STATE_COLOURS[StandScript.STATE_STUMP], ForestMarks.STUMP_COLOUR, "stump")
	assert_equal(ForestMarks.STATE_COLOURS[StandScript.STATE_CLEARED], ForestMarks.CLEARED_COLOUR, "cleared")
	assert_equal(ForestMarks.LEGEND_COLOURS.size(), ForestMarks.LEGEND_NAMES.size(), "a name for each colour")


func test_the_old_woods_marks_fail_where_decision_0581_measured() -> void:
	"""The check is not vacuous for the woods: the marks before decision 1044 (brass zone and young tree alike, an umber
	stump) fail it -- the two brasses everywhere, mature and stump with deuteranopia at 8.6 by day and 7.8 by night."""
	var old: PackedColorArray = [WoodlandPalette.BRASS, WoodlandPalette.SAGE, WoodlandPalette.LEAF, WoodlandPalette.BRASS,
		WoodlandPalette.UMBER, WoodlandPalette.CLAY]
	var trees: PackedColorArray = old.slice(2)
	assert_equal(ColourCheck.failures(old, LensPalette.OVER_GRASS, PackedStringArray()).size(),
		ColourCheck.SEEN_COUNT * ColourCheck.VISION_COUNT, "the shared brass fails every viewing")
	var day: Vector3 = ColourCheck.closest(trees, LensPalette.OVER_GRASS, ColourCheck.SEEN_DAY, ColourCheck.VISION_DEUTAN)
	var night: Vector3 = ColourCheck.closest(trees, LensPalette.OVER_GRASS, ColourCheck.SEEN_NIGHT, ColourCheck.VISION_DEUTAN)
	assert_true(int(day.y) == 0 and int(day.z) == 2 and absf(day.x - 8.6) < 0.05, "mature and stump by day: %.2f" % day.x)
	assert_true(absf(night.x - 7.8) < 0.05, "and by night: %.2f" % night.x)


func test_the_old_ramps_fail_the_check_that_the_new_ones_pass() -> void:
	"""The check is not vacuous: the moisture and ripeness colours before decision 0581 fail it where measured."""
	var old_moisture: PackedColorArray = [Color(0.85, 0.45, 0.2, 0.55), Color(0.9, 0.72, 0.3, 0.5),
		Color(0.3, 0.62, 0.32, 0.45), Color(0.36, 0.47, 0.58, 0.38), Color(0.24, 0.32, 0.47, 0.46)]
	var old_ripeness: PackedColorArray = [Color(0.32, 0.6, 0.3, 0.45), Color(0.93, 0.74, 0.25, 0.6), Color(0.85, 0.35, 0.2, 0.6)]
	var worst: Vector3 = ColourCheck.closest(old_ripeness, LensPalette.OVER_SOIL, ColourCheck.SEEN_DAY, ColourCheck.VISION_PROTAN)
	assert_true(worst.x < 4.0 and int(worst.y) == 0 and int(worst.z) == 2, "growing and past-its-best by protanopia: %.1f" % worst.x)
	var failing: PackedStringArray = ColourCheck.failures(old_moisture, LensPalette.OVER_SOIL,
		PackedStringArray(["dry", "low", "good", "wet", "waterlogged"]))
	assert_true(failing.size() >= 4, "the old moisture ramp: %s" % "; ".join(failing))
	assert_true(failing[0].begins_with("wet and waterlogged by day with normal vision"), failing[0])


func test_the_colour_maths_matches_its_references() -> void:
	"""Lab of white and black, delta E of black and white, the simulations keeping grey grey and confusing red with
	green, compositing at alpha, the night's grade, and the floors."""
	assert_true(ColourCheck.lab(Color.WHITE).distance_to(Vector3(100.0, 0.0, 0.0)) < 0.1, "white")
	assert_true(ColourCheck.lab(Color.BLACK).length() < 0.01, "black")
	assert_almost_equal(ColourCheck.delta_e(Color.BLACK, Color.WHITE), 100.0, "black to white")
	for vision: int in ColourCheck.VISION_COUNT:
		var grey: Color = ColourCheck.simulate(Color(0.5, 0.5, 0.5), vision)
		assert_true(absf(grey.r - grey.g) < 0.01 and absf(grey.g - grey.b) < 0.01, "grey stays grey (%d)" % vision)
	var red_green: float = ColourCheck.delta_e(ColourCheck.simulate(Color(0.8, 0.2, 0.2), ColourCheck.VISION_DEUTAN),
		ColourCheck.simulate(Color(0.4, 0.5, 0.2), ColourCheck.VISION_DEUTAN))
	assert_true(red_green < ColourCheck.delta_e(Color(0.8, 0.2, 0.2), Color(0.4, 0.5, 0.2)), "deuteranopia brings them closer")
	assert_equal(ColourCheck.seen(Color(1, 0, 0, 0.5), Color.BLACK, ColourCheck.SEEN_DAY), Color(0.5, 0, 0), "half over black")
	assert_equal(ColourCheck.seen(Color(1, 0, 0, 0.5), Color.BLACK, ColourCheck.SEEN_LEGEND), Color(1, 0, 0), "opaque in the legend")
	var night: Color = ColourCheck.seen(Color.WHITE, Color.BLACK, ColourCheck.SEEN_NIGHT)
	assert_true(night.r < 1.0 and night.b > night.r - 0.2, "graded and hazed")
	assert_equal(ColourCheck.floor_for(ColourCheck.SEEN_NIGHT), ColourCheck.MIN_DE_NIGHT, "the night's floor")
	assert_equal(ColourCheck.floor_for(ColourCheck.SEEN_DAY), ColourCheck.MIN_DE_DAY, "the day's")
	assert_equal(ColourCheck.closest(PackedColorArray([Color.RED]), Color.BLACK, 0, 0), Vector3(INF, -1.0, -1.0), "one colour")
	assert_true(ColourCheck.failures(PackedColorArray([Color.RED]), Color.BLACK, PackedStringArray()).is_empty(), "nothing to fail")
	var same: PackedStringArray = ColourCheck.failures(PackedColorArray([Color.RED, Color.RED]), Color.BLACK, PackedStringArray())
	assert_equal(same.size(), ColourCheck.SEEN_COUNT * ColourCheck.VISION_COUNT, "a pair the same fails everywhere")
	assert_true(same[0].begins_with("colour 0 and colour 1 in the legend with normal vision: 0.0"), same[0])
