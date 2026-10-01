extends "res://test/framework/test_case.gd"
## The map layers' legend, hover readout and compare outlines (decision 0581): a layer added as one record, its scale
## and areas; the compared layer's rules (only another outlining layer, dropped when it becomes the shown one or none
## is shown, followed through U); the outlines traced by marching squares, sliced by a budget, drawn on the inside of
## each area; the readout's words, place, fade and reduced motion; the legend's ramp rows, thresholds and compact
## outlined form; the kit's throttle -- words only on a change, outlines redrawn only when the compared field moves, a
## subject's depths taken into the legend -- and the picker's compare row.
##
## No scene tree: everything is built off-tree with small test probes, or the farm sim's.

const LensesScript := preload("res://demo/map_lenses.gd")
const DefScript := preload("res://demo/lenses/lens_def.gd")
const ProbeScript := preload("res://demo/lenses/lens_probe.gd")
const ContoursScript := preload("res://demo/lenses/lens_contours.gd")
const ReadoutScript := preload("res://demo/ui/demo_lens_readout.gd")
const LegendScript := preload("res://demo/ui/demo_lens_legend.gd")
const KitScript := preload("res://demo/lenses/demo_lens_kit.gd")
const PickerScript := preload("res://demo/ui/demo_lens_picker.gd")
const BedProbe := preload("res://demo/lenses/bed_lens_probe.gd")
const LensPalette := preload("res://demo/lenses/lens_palette.gd")
const Access := preload("res://demo/access/demo_access.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const WaterOverlayScript := preload("res://demo/water/water_overlay.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")


class SquareProbe extends "res://demo/lenses/lens_probe.gd":
	## A test layer: area `inner` inside a square, `outer` in a ring round it, nothing past that.
	var square: Rect2 = Rect2(-1.0, -1.0, 2.0, 2.0)
	var ring_m: float = 1.0
	var inner: int = 0
	var outer: int = -1
	var bounds: Rect2 = Rect2(-3.0, -3.0, 6.0, 6.0)
	var cell: float = 0.5
	var revision: int = 0
	var reads: int = 0

	func read_into(point_m: Vector2, out: Reading) -> bool:
		"""The square's class, the ring's, or nothing."""
		out.clear()
		reads += 1
		if square.has_point(point_m):
			out.area = inner
		elif square.grow(ring_m).has_point(point_m) and outer >= 0:
			out.area = outer
		else:
			return false
		out.entry = out.area
		out.value = out.area * 10
		out.who = 1
		return true

	func describe(reading: Reading) -> String:
		"""Its class in words."""
		return "class %d" % reading.area

	func can_outline() -> bool:
		"""While it has a field."""
		return bounds.has_area()

	func field_bounds_m() -> Rect2:
		"""Round the square."""
		return bounds

	func field_cell_m() -> float:
		"""As set."""
		return cell

	func field_revision() -> int:
		"""As set."""
		return revision


var _nodes: Array[Node] = []
var _said: PackedStringArray = PackedStringArray()
var _under_on: bool = false


func after_each() -> void:
	"""Free every node a test built; reduced motion back off."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_said.clear()
	_under_on = false
	Access.set_flag(Access.SET_MOTION, false)


func _keep(node: Node) -> Node:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _show(on: bool, lens: String) -> void:
	"""A test layer's switch."""
	_said.append("%s:%s" % [lens, "on" if on else "off"])


func _lenses() -> LensesScript:
	"""Three probed layers (the first two outline), one without a probe, and an Underground followed by its switch."""
	var lenses := LensesScript.new()
	for k: int in 3:
		var lens: int = lenses.add("Group", "Layer %d" % k, "Question %d?" % k, _show.bind("l%d" % k))
		lenses.set_legend(lens, PackedColorArray([LensPalette.WADE, LensPalette.SWIM, LensPalette.DIVE]),
			PackedStringArray(["a", "b", "c"]))
		lenses.set_scale(lens, 0, 2, PackedStringArray(["up to 1 m", "past 1 m"]), "Depth in metres")
		var probe := SquareProbe.new()
		if k == 2:
			probe.bounds = Rect2()
		lenses.set_probe(lens, probe)
	lenses.add("Group", "Plain", "No probe?", _show.bind("plain"))
	var under: int = lenses.add("Underground", "Tunnels", "Below?", func(on: bool) -> void: _under_on = on)
	lenses.follow_state(under, func() -> bool: return _under_on)
	return lenses


# --- the layers as data -----------------------------------------------------------------------------------

func test_a_layer_added_as_a_record_carries_everything() -> void:
	"""add_def: on V's cycle after the rest, its legend, scale, areas, ground, probe and subject; with a follow switch,
	off V's cycle."""
	var lenses := _lenses()
	var def := DefScript.new()
	def.group = "Woods"
	def.label = "Leaf fall"
	def.question = "Which trees are bare?"
	def.show = _show.bind("leaf")
	def.swatches = PackedColorArray([LensPalette.GROWING, LensPalette.RIPE, Color(0, 0, 0, 0)])
	def.words = PackedStringArray(["green", "turning", "note"])
	def.ramp_from = 0
	def.ramp_count = 2
	def.ticks = PackedStringArray(["under 20%", "20% and over"])
	def.caption = "Leaf cover %"
	def.areas = PackedInt32Array([1])
	def.over = LensPalette.OVER_GRASS
	def.probe = SquareProbe.new()
	var lens: int = lenses.add_def(def)
	assert_equal(lens, lenses.count() - 1, "the last row")
	assert_equal(lenses.find("Woods", "Leaf fall"), lens, "found by group and label")
	assert_equal(lenses.find("Woods", "Nothing"), LensesScript.OFF, "nothing else")
	assert_true(lenses.is_on_cycle(lens), "V reaches it")
	assert_equal(lenses.words_of(lens), def.words, "its words")
	assert_equal([lenses.ramp_from_of(lens), lenses.ramp_count_of(lens)], [0, 2], "its ramp")
	assert_equal(lenses.ticks_of(lens), def.ticks, "its thresholds")
	assert_equal(lenses.caption_of(lens), "Leaf cover %", "its caption")
	assert_equal(lenses.area_colours(lens), PackedColorArray([LensPalette.RIPE]), "its area colours, as set")
	assert_equal(lenses.area_words(lens), PackedStringArray(["turning"]), "and words")
	var other := DefScript.new()
	other.group = "Growing"
	other.label = "Leaf fall"
	other.show = _show.bind("other")
	var second: int = lenses.add_def(other)
	assert_equal(lenses.find("Growing", "Leaf fall"), second, "the same label in another group is another layer")
	assert_equal(lenses.find("Woods", "Leaf fall"), lens, "and the first still its own")
	assert_true(lenses.probe_of(lens) == def.probe and lenses.can_compare(lens), "its probe")
	var followed := DefScript.new()
	followed.follow = func() -> bool: return false
	followed.show = _show.bind("f")
	assert_false(lenses.is_on_cycle(lenses.add_def(followed)), "a followed layer is off V's cycle")


func test_areas_default_to_the_ramp_and_skip_missing_swatches() -> void:
	"""No areas set: the ramp's swatches; set: those, past the swatches skipped."""
	var lenses := _lenses()
	assert_equal(lenses.area_entries(1), PackedInt32Array([0, 1]), "the ramp")
	lenses.set_areas(1, PackedInt32Array([1, 3]))
	assert_equal(lenses.area_colours(1), PackedColorArray([LensPalette.SWIM]), "one past the swatches skipped")
	lenses.set_areas(1, PackedInt32Array([2, 0, 9]))
	assert_equal(lenses.area_colours(1), PackedColorArray([LensPalette.DIVE, LensPalette.WADE]), "set, 9 skipped")
	assert_equal(lenses.area_words(1), PackedStringArray(["c", "a"]), "their words")
	assert_true(lenses.probe_of(-1) == null and lenses.probe_of(99) == null, "no row, no probe")


func test_set_ticks_moves_the_revision_only_on_a_change() -> void:
	"""A subject's own depths: re-set only when they differ."""
	var lenses := _lenses()
	var before: int = lenses.revision
	lenses.set_ticks(1, PackedStringArray(["up to 1 m", "past 1 m"]), "Depth in metres")
	assert_equal(lenses.revision, before, "the same: nothing")
	lenses.set_ticks(1, PackedStringArray(["up to 2 m", "past 2 m"]), "Depth in metres")
	assert_equal(lenses.revision, before + 1, "new depths")
	lenses.set_ticks(1, PackedStringArray(["up to 2 m", "past 2 m"]), "Another caption")
	assert_equal(lenses.revision, before + 2, "a new caption")


# --- the compared layer -----------------------------------------------------------------------------------

func test_only_another_outlining_layer_may_be_compared() -> void:
	"""Nothing shown: none; the shown one, a probe that cannot outline, a layer without a probe, OFF: none."""
	var lenses := _lenses()
	assert_equal(lenses.set_compare(2), LensesScript.OFF, "nothing shown")
	lenses.select(1)
	assert_equal(lenses.set_compare(1), LensesScript.OFF, "not the shown one")
	assert_equal(lenses.set_compare(3), LensesScript.OFF, "a probe with no field")
	assert_equal(lenses.set_compare(4), LensesScript.OFF, "no probe")
	assert_equal(lenses.set_compare(2), 2, "another that outlines")
	assert_true(lenses.is_compare_candidate(2) and not lenses.is_compare_candidate(1), "the candidates")
	assert_equal(lenses.set_compare(LensesScript.OFF), LensesScript.OFF, "off")


func test_the_compared_layer_follows_the_shown_one() -> void:
	"""Kept when V moves to another layer; dropped when the shown layer becomes it, when none is shown, when U shows
	the underground, and when its probe goes."""
	var lenses := _lenses()
	lenses.select(1)
	lenses.set_compare(2)
	assert_equal(lenses.cycle(), 2, "V to the compared one")
	assert_equal(lenses.compare, LensesScript.OFF, "dropped: it is shown now")
	lenses.select(1)
	lenses.set_compare(2)
	lenses.select(3)
	assert_equal(lenses.compare, 2, "kept for another")
	lenses.turn_off()
	assert_equal(lenses.compare, LensesScript.OFF, "none shown: none compared")
	lenses.select(1)
	lenses.set_compare(2)
	_under_on = true
	assert_true(lenses.sync(), "U")
	assert_equal(lenses.compare, LensesScript.OFF, "the underground has nothing to compare with")
	lenses.select(1)
	lenses.set_compare(2)
	lenses.set_probe(2, null)
	assert_equal(lenses.compare, LensesScript.OFF, "its probe gone")


# --- the outlines ---------------------------------------------------------------------------------------------

func _contours() -> ContoursScript:
	"""Outlines off-tree."""
	return _keep(ContoursScript.new()) as ContoursScript


static func _near(a: Color, b: Color) -> bool:
	"""Two colours equal to the mesh's 8-bit vertex colour."""
	return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006 and absf(a.a - b.a) < 0.006


func test_one_corner_is_cut_off_by_four_segments() -> void:
	"""A 3x3 corner grid with only the middle in the class: four cells, one segment each, a strip and a core each."""
	var probe := SquareProbe.new()
	probe.square = Rect2(0.4, 0.4, 0.2, 0.2)
	probe.bounds = Rect2(0.0, 0.0, 1.0, 1.0)
	var contours := _contours()
	contours.start(probe, PackedColorArray([LensPalette.RIPE]))
	assert_true(contours.is_working(), "under way")
	contours.finish()
	assert_false(contours.is_working(), "done")
	assert_equal(contours.segments, 4, "a diamond")
	assert_equal(contours.vertex_count(), 4 * 2 * 6, "two quads a segment")
	assert_equal(contours.traces, 1, "one trace")
	var colours: PackedColorArray = contours.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_true(_near(colours[0], Color(LensPalette.RIPE, 1.0)), "the strip in its class's colour, opaque: %s" % colours[0])
	assert_true(_near(colours[6], Color(LensPalette.OUTLINE_INK, 1.0)), "the core in ink: %s" % colours[6])


func test_the_strip_lies_on_the_area_s_side() -> void:
	"""Every strip vertex of the diamond lies nearer the in-class corner than the segment it leaves from."""
	var probe := SquareProbe.new()
	probe.square = Rect2(0.4, 0.4, 0.2, 0.2)
	probe.bounds = Rect2(0.0, 0.0, 1.0, 1.0)
	var contours := _contours()
	contours.start(probe, PackedColorArray([LensPalette.RIPE]))
	contours.finish()
	var vertices: PackedVector3Array = contours.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var centre := Vector2(0.5, 0.5)
	for segment: int in 4:
		var base: int = segment * 12
		var edge: float = Vector2(vertices[base].x, vertices[base].z).distance_to(centre)
		var strip: float = Vector2(vertices[base + 2].x, vertices[base + 2].z).distance_to(centre)
		assert_true(strip < edge, "segment %d: inside (%.3f < %.3f)" % [segment, strip, edge])
	assert_almost_equal(vertices[0].y, ProbeScript.DRAW_Y_M, "at the probe's height")


func test_saddles_cut_each_in_class_corner_off_alone() -> void:
	"""Shared corners of adjacent edges; both saddle cases give two segments, each nearer its own corner."""
	assert_equal(ContoursScript.shared_corner(3, 0), 0, "left and top: corner 0")
	assert_equal(ContoursScript.shared_corner(0, 1), 1, "top and right: corner 1")
	assert_equal(ContoursScript.shared_corner(2, 1), 2, "right and bottom: corner 2")
	assert_equal(ContoursScript.shared_corner(2, 3), 3, "bottom and left: corner 3")
	for case_index: int in 16:
		var segments: int = 0
		for s: int in 2:
			segments += int(ContoursScript.CASES[case_index * 4 + s * 2] >= 0)
		var expected: int = 0 if case_index == 0 or case_index == 15 else (2 if case_index == 5 or case_index == 10 else 1)
		assert_equal(segments, expected, "case %d" % case_index)
	var contours := _contours()
	assert_equal(contours._inside_of(0, 0, ContoursScript.SADDLE_A, 3, 0), contours._corner(0, 0, 0), "case 5: corner 0")
	assert_equal(contours._inside_of(0, 0, ContoursScript.SADDLE_B, 2, 3), contours._corner(0, 0, 3), "case 10: corner 3")


func test_two_classes_meet_as_a_two_colour_line() -> void:
	"""A square of class 0 in a ring of class 1: both traced, class 1 twice round (outside and inside)."""
	var probe := SquareProbe.new()
	probe.outer = 1
	var contours := _contours()
	contours.start(probe, PackedColorArray([LensPalette.WADE, LensPalette.SWIM]))
	contours.finish()
	var colours: PackedColorArray = contours.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var wade: int = 0
	var swim: int = 0
	for k: int in range(0, colours.size(), 12):
		wade += int(_near(colours[k], Color(LensPalette.WADE, 1.0)))
		swim += int(_near(colours[k], Color(LensPalette.SWIM, 1.0)))
	assert_true(wade > 0 and swim > wade, "wade %d, swim %d (inner and outer edges)" % [wade, swim])


func test_a_trace_is_sliced_and_the_old_outline_stays_until_done() -> void:
	"""With a one-microsecond slice the trace takes a step a row (at least the grid's rows); the outline drawn before
	stays until the new one is committed; clearing empties it."""
	var probe := SquareProbe.new()
	var contours := _contours()
	contours.start(probe, PackedColorArray([LensPalette.RIPE]))
	contours.finish()
	var drawn: int = contours.vertex_count()
	probe.square = Rect2(-2.0, -2.0, 4.0, 4.0)
	contours.start(probe, PackedColorArray([LensPalette.RIPE]))
	var steps: int = 0
	while contours.step(1):
		steps += 1
		assert_equal(contours.vertex_count(), drawn, "the old outline still drawn")
	assert_true(steps >= 12, "%d slices for a 13-row grid" % steps)
	assert_true(contours.vertex_count() > drawn, "the bigger square drawn")
	contours.clear_outline()
	assert_equal(contours.vertex_count(), 0, "cleared")
	assert_false(contours.is_working(), "nothing running")


func test_a_huge_field_is_sampled_coarser_and_an_empty_one_not_at_all() -> void:
	"""No more than MAX_CORNERS reads; an empty field clears and stops."""
	var probe := SquareProbe.new()
	probe.bounds = Rect2(-500.0, -500.0, 1000.0, 1000.0)
	var contours := _contours()
	contours.start(probe, PackedColorArray([LensPalette.RIPE]))
	contours.finish()
	assert_true(probe.reads <= ContoursScript.MAX_CORNERS + 2 * 1000, "%d reads" % probe.reads)
	probe.bounds = Rect2()
	contours.start(probe, PackedColorArray([LensPalette.RIPE]))
	assert_false(contours.is_working(), "nothing to trace")
	assert_equal(contours.vertex_count(), 0, "and nothing drawn")


func test_the_outline_material_reads_at_night() -> void:
	"""Unshaded, fog off, no depth test, sRGB vertex colours, on the surface's marks layer."""
	var material: StandardMaterial3D = ContoursScript.make_material()
	assert_equal(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "unshaded")
	assert_true(material.disable_fog and material.no_depth_test, "no fog, no depth test")
	assert_true(material.vertex_color_use_as_albedo and material.vertex_color_is_srgb, "its colours as given")
	assert_equal(_contours().layers, preload("res://demo/demo_layers.gd").SURFACE_MARKS, "the surface's marks")


func test_an_idle_outline_allocates_nothing() -> void:
	"""Stepping with no trace running creates nothing."""
	var contours := _contours()
	contours.step()
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory: int = OS.get_static_memory_usage()
	for k: int in 500:
		contours.step()
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object")
	assert_equal(OS.get_static_memory_usage(), memory, "no memory")


# --- the readout ------------------------------------------------------------------------------------------

func _readout() -> ReadoutScript:
	"""A readout off-tree."""
	return _keep(ReadoutScript.new()) as ReadoutScript


func test_the_readout_words_fade_and_go() -> void:
	"""Words shown fade in over 80 ms; with no second layer that line is hidden; hidden, it fades out."""
	var readout := _readout()
	assert_false(readout.shown(), "hidden at first")
	readout.set_words("Soil moisture 62% · good", "")
	assert_true(readout.shown(), "shown")
	assert_equal([readout.main_text(), readout.second_text()], ["Soil moisture 62% · good", ""], "one line")
	readout._process(0.04)
	assert_almost_equal(readout.opacity(), 0.5, "half way after 40 ms")
	readout._process(0.04)
	assert_almost_equal(readout.opacity(), 1.0, "in after 80 ms")
	readout.set_words("", "Outlined, Water range:\nWater 0.42 m deep · swim")
	assert_equal(readout.main_text(), "", "no main words")
	assert_true(readout.second_text().begins_with("Outlined"), "the second layer's")
	readout.set_words("a", "b")
	assert_true(readout.second_line_shown(), "a second line")
	readout.set_words("a", "")
	assert_false(readout.second_line_shown(), "no second line takes no room")
	readout.hide_readout()
	assert_false(readout.shown(), "going")
	readout._process(0.08)
	assert_almost_equal(readout.opacity(), 0.0, "gone")


func test_reduced_motion_shows_and_hides_the_readout_at_once() -> void:
	"""UI §2.2: no fade with reduced motion."""
	Access.set_flag(Access.SET_MOTION, true)
	var readout := _readout()
	readout.set_words("Water 1.40 m deep · dive", "")
	readout._process(0.001)
	assert_almost_equal(readout.opacity(), 1.0, "at once")
	readout.hide_readout()
	readout._process(0.001)
	assert_almost_equal(readout.opacity(), 0.0, "gone at once")
	readout.show_again()
	readout._process(0.001)
	assert_almost_equal(readout.opacity(), 1.0, "back at once")


func test_the_readout_stays_in_the_window() -> void:
	"""Below right of the pointer; flipped left at the right edge and up at the bottom."""
	var readout := _readout()
	readout.set_words("Soil moisture 62% · good", "")
	var size := Vector2(1920.0, 1080.0)
	readout.place(Vector2(200.0, 200.0), size)
	var rect: Rect2 = readout.panel_rect()
	assert_true(rect.position.x > 200.0 and rect.position.y > 200.0, "below right: %s" % rect)
	readout.place(Vector2(1910.0, 1075.0), size)
	rect = readout.panel_rect()
	assert_true(rect.end.x <= 1910.0 and rect.end.y <= 1075.0, "flipped: %s" % rect)
	assert_true(Rect2(Vector2.ZERO, size).encloses(rect), "inside")


# --- the legend --------------------------------------------------------------------------------------------

func _legend(lenses: LensesScript, lens: int, outlined: bool) -> LegendScript:
	"""A legend off-tree."""
	var legend := LegendScript.new()
	_keep(legend)
	legend.build(lenses, lens, outlined)
	return legend


func test_the_legend_draws_the_ramp_with_thresholds_and_the_keys() -> void:
	"""A short ramp as one bar with its thresholds, the caption, the rest as keys; every word in swatch order."""
	var lenses := _lenses()
	var legend := _legend(lenses, 1, false)
	assert_equal(legend.ramp_rows(), 2, "two ramp entries")
	assert_true(legend.is_bar(), "drawn as a bar")
	assert_equal(legend.ticks(), PackedStringArray(["up to 1 m", "past 1 m"]), "their thresholds")
	assert_equal(legend.caption_text(), "Depth in metres", "the caption")
	assert_equal(legend.words(), PackedStringArray(["a", "b", "c"]), "every word, in order")
	lenses.set_ticks(1, PackedStringArray(["up to 2 m", "past 2 m"]), "")
	legend.retext()
	assert_equal(legend.ticks(), PackedStringArray(["up to 2 m", "past 2 m"]), "re-texted")
	assert_equal(legend.caption_text(), "", "no caption: hidden")


func test_a_long_ramp_flows_rather_than_widening_the_card() -> void:
	"""Long thresholds: still one bar, its segments flowing; a narrow card is not pushed wider."""
	var lenses := _lenses()
	lenses.set_scale(1, 0, 3, PackedStringArray(["a very long threshold indeed", "and another long one", "and a third"]),
		"Long")
	var legend := _legend(lenses, 1, false)
	assert_true(legend.is_bar(), "a bar")
	assert_equal(legend.ramp_rows(), 3, "a segment each")
	assert_equal(legend.ticks()[2], "and a third", "their thresholds")
	assert_true(legend.get_combined_minimum_size().x < 260.0, "no wider than its widest segment: %.0f" %
		legend.get_combined_minimum_size().x)


func test_the_outlined_legend_is_compact() -> void:
	"""Every entry a chip; no caption, no thresholds."""
	var legend := _legend(_lenses(), 1, true)
	assert_equal(legend.ramp_rows(), 0, "no ramp")
	assert_false(legend.is_bar(), "no bar")
	assert_equal(legend.caption_text(), "", "no caption")
	assert_equal(legend.words(), PackedStringArray(["a", "b", "c"]), "its words")


func test_the_legend_is_rebuilt_when_its_scale_arrives_later() -> void:
	"""A layer given its scale after the picker built its legend: the next re-text rebuilds it."""
	var lenses := _lenses()
	var legend := _legend(lenses, 1, false)
	lenses.set_scale(1, 0, 3, PackedStringArray(["x", "y", "z"]), "Now three")
	legend.retext()
	assert_equal(legend.ramp_rows(), 3, "three rows")
	assert_equal(legend.ticks(), PackedStringArray(["x", "y", "z"]), "their thresholds")
	assert_equal(legend.caption_text(), "Now three", "the caption")


# --- the kit ---------------------------------------------------------------------------------------------

func _kit(lenses: LensesScript) -> KitScript:
	"""A kit over `lenses` with no village behind it (no probes of its own)."""
	var kit := KitScript.new()
	_keep(kit)
	kit.attach(lenses, null, null, null, null, null)
	return kit


func test_the_kit_words_the_readout_only_on_a_change() -> void:
	"""The same reading again: the same words, no re-wording; another class, or the compared layer: new words."""
	var lenses := _lenses()
	var kit := _kit(lenses)
	lenses.select(1)
	var main: ProbeScript = lenses.probe_of(1)
	assert_true(kit.read_point(Vector2.ZERO, main, null), "inside the square")
	assert_equal(kit.readout.main_text(), "class 0", "its words")
	assert_equal(kit.rewords, 1, "worded once")
	kit.read_point(Vector2(0.2, 0.1), main, null)
	assert_equal(kit.rewords, 1, "the same reading: not again")
	assert_false(kit.read_point(Vector2(9.0, 9.0), main, null), "outside: nothing")
	assert_false(kit.readout.shown(), "hidden")
	assert_true(kit.read_point(Vector2.ZERO, main, null), "back")
	assert_equal(kit.rewords, 1, "back on the same reading: the same words")
	lenses.set_compare(2)
	kit.read_point(Vector2.ZERO, main, lenses.probe_of(2))
	assert_equal(kit.rewords, 2, "a compared layer: new words")
	assert_equal(kit.readout.second_text(), "Outlined, Layer 1:\nclass 0", "its words")
	assert_false(kit.read_point(Vector2.INF, main, null), "off the ground")
	lenses.set_compare(LensesScript.OFF)
	kit.read_point(Vector2.ZERO, main, null)
	var before: int = kit.rewords
	lenses.select(2)
	kit.read_point(Vector2.ZERO, lenses.probe_of(2), null)
	assert_equal(kit.rewords, before + 1, "another layer reading the same: its own words")


func test_the_pointer_is_read_only_over_the_world_inside_the_window() -> void:
	"""A layer to read, no panel under the pointer, a camera, and the pointer inside the window: each needed."""
	var size := Vector2(1280.0, 720.0)
	assert_true(KitScript.may_read(true, false, true, Vector2(10.0, 10.0), size), "all there")
	assert_false(KitScript.may_read(false, false, true, Vector2(10.0, 10.0), size), "no layer to read")
	assert_false(KitScript.may_read(true, true, true, Vector2(10.0, 10.0), size), "over a panel")
	assert_false(KitScript.may_read(true, false, false, Vector2(10.0, 10.0), size), "no camera")
	assert_false(KitScript.may_read(true, false, true, Vector2.INF, size), "no pointer yet")
	assert_false(KitScript.may_read(true, false, true, Vector2(1280.0, 10.0), size), "past the right edge")
	assert_false(KitScript.may_read(true, false, true, Vector2(-1.0, 10.0), size), "past the left")


func test_the_kit_hides_the_readout_off_the_ground_over_a_panel_or_off_tree() -> void:
	"""No camera (off-tree), the pointer over a panel or off the window: hidden."""
	var lenses := _lenses()
	var kit := _kit(lenses)
	lenses.select(1)
	kit.read_point(Vector2.ZERO, lenses.probe_of(1), null)
	kit.update_readout(Vector2(100.0, 100.0), Vector2(1280.0, 720.0), true)
	assert_false(kit.readout.shown(), "over a panel")
	kit.read_point(Vector2.ZERO, lenses.probe_of(1), null)
	kit.update_readout(Vector2(100.0, 100.0), Vector2(1280.0, 720.0), false)
	assert_false(kit.readout.shown(), "no camera off-tree")
	lenses.select(4)
	kit.update_readout(Vector2(100.0, 100.0), Vector2(1280.0, 720.0), false)
	assert_false(kit.readout.shown(), "a layer without a probe")


func test_the_kit_traces_the_compared_layer_when_it_or_its_field_moves() -> void:
	"""Chosen: traced; its field revision moves: traced again; unchanged: not; off: cleared."""
	var lenses := _lenses()
	var kit := _kit(lenses)
	lenses.select(1)
	lenses.set_compare(2)
	kit.follow_compare()
	assert_true(kit.contours.is_working(), "traced")
	kit.contours.finish()
	var traces: int = kit.contours.traces
	kit.follow_compare()
	assert_false(kit.contours.is_working(), "unchanged: not again")
	(lenses.probe_of(2) as SquareProbe).revision += 1
	kit.follow_compare()
	assert_true(kit.contours.is_working(), "its field moved")
	kit.contours.finish()
	assert_equal(kit.contours.traces, traces + 1, "once more")
	lenses.set_compare(LensesScript.OFF)
	kit.follow_compare()
	assert_equal(kit.contours.vertex_count(), 0, "off: cleared")


func test_the_kit_gives_the_village_layers_their_probes_and_scales() -> void:
	"""With the farm sim: the three Growing layers probed and scaled; the Water range's depths taken from its probe
	for the painted body, and again when another is painted."""
	var lenses := LensesScript.new()
	var noop := func(_on: bool) -> void: pass
	for label: String in ["Soil moisture", "Ripeness", "Water service"]:
		lenses.add("Growing", label, "?", noop)
	var water: int = lenses.add("Getting there", "Water range", "?", noop)
	var overlay := WaterOverlayScript.new()
	_keep(overlay)
	var kit := KitScript.new()
	_keep(kit)
	kit.attach(lenses, SimScript.new(), WaterLayout.make_map(), overlay, null, null)
	for lens: int in range(1, 4):
		assert_true(lenses.probe_of(lens) is BedProbe, "%s probed" % lenses.label_of(lens))
	assert_equal((lenses.probe_of(2) as BedProbe).mode, BedProbe.MODE_RIPENESS, "ripeness by its mode")
	assert_equal(lenses.ramp_count_of(1), 5, "moisture's scale")
	assert_equal(lenses.ticks_of(water)[0], "≤0.25 m", "the mouse's depths")
	overlay.body_height_u = 2611
	kit.follow_ticks()
	assert_equal(lenses.ticks_of(water)[0], "≤0.64 m", "the badger's")
	assert_true(lenses.probe_of(lenses.add("Woods", "Zones and trees", "?", noop)) == null, "no woods without a stand")


func test_a_steady_reading_allocates_nothing() -> void:
	"""The pointer over the same bed: reading both layers and keeping the words creates nothing."""
	var lenses := LensesScript.new()
	var noop := func(_on: bool) -> void: pass
	lenses.add("Growing", "Soil moisture", "?", noop)
	lenses.add("Growing", "Water service", "?", noop)
	var kit := KitScript.new()
	_keep(kit)
	kit.attach(lenses, SimScript.new(), null, null, null, null)
	lenses.select(1)
	lenses.set_compare(2)
	var at: Vector2 = Catalog.bed_centre_m(2)
	kit.read_point(at, lenses.probe_of(1), lenses.probe_of(2))
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory: int = OS.get_static_memory_usage()
	for k: int in 300:
		kit.read_point(at + Vector2(0.001 * float(k % 5), 0.0), lenses.probe_of(1), lenses.probe_of(2))
	assert_equal(kit.rewords, 1, "worded once")
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object")
	assert_equal(OS.get_static_memory_usage(), memory, "no memory")


# --- the picker's compare row ------------------------------------------------------------------------------

func _picker(lenses: LensesScript) -> PickerScript:
	"""The picker off-tree."""
	var picker := PickerScript.new()
	_keep(picker)
	picker.configure(lenses)
	return picker


func test_the_picker_offers_compare_and_turns_it_on_and_off() -> void:
	"""The header's compare button is usable while a layer is shown and another can be outlined over it; its list
	offers only those; a pick presses it, names the layer on the Outlined line and shows its outlined legend; the same
	again, or ✕, turns it off."""
	var lenses := _lenses()
	var picker := _picker(lenses)
	assert_false(picker.compare_offered(), "no layer shown: nothing to compare with")
	assert_true(picker.compare_button().disabled, "the button disabled")
	picker.choose(4)
	assert_true(picker.compare_offered(), "a layer without a probe of its own may still have another outlined over it")
	picker.choose(1)
	assert_true(picker.compare_offered(), "offered")
	assert_equal(picker.compare_text(), "", "no Outlined line yet")
	picker.compare_button().pressed.emit()
	assert_true(picker.compare_list_shown(), "the list")
	assert_true(picker.compare_lens_button(2).visible, "another that outlines")
	assert_false(picker.compare_lens_button(1).visible or picker.compare_lens_button(3).visible
		or picker.compare_lens_button(4).visible, "not itself, not one without a field or a probe")
	picker.choose_compare(2)
	assert_equal(lenses.compare, 2, "compared")
	assert_false(picker.compare_list_shown(), "the list folds")
	assert_true(picker.compare_button().button_pressed, "the button stays pressed")
	assert_equal(picker.compare_text(), "Outlined: Group: Layer 1", "the Outlined line")
	assert_true(picker.outline_legend(2).visible and picker.compare_lens_button(2).button_pressed, "its legend, pressed")
	picker.choose_compare(2)
	assert_equal(lenses.compare, LensesScript.OFF, "the same again: off")
	assert_false(picker.compare_button().button_pressed, "released")
	picker.choose_compare(2)
	picker.compare_off_button().pressed.emit()
	assert_equal(lenses.compare, LensesScript.OFF, "✕: off")
	assert_equal(picker.compare_text(), "", "the line gone")
	assert_not_null(PickerScript.compare_icon(), "the button's glyph")


func test_the_picker_legend_shows_the_ramp_of_the_shown_layer() -> void:
	"""The picker's legend for a layer is the ramp-and-keys legend; the outlined ones are hidden until compared."""
	var lenses := _lenses()
	var picker := _picker(lenses)
	picker.choose(1)
	assert_true(picker.legend_shown(1) and not picker.legend_shown(2), "the shown layer's")
	assert_equal(picker.legend(1).ramp_rows(), 2, "its ramp")
	assert_equal(picker.legend_words(1), PackedStringArray(["a", "b", "c"]), "its words")
	assert_false(picker.outline_legend(2).visible, "nothing compared")
