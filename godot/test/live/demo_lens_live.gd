extends SceneTree
## The map layers' legend, hover readout, compare outlines and colour check on the REAL village (decision 0581). Not
## discovered by the runner: test/test_demo_lens_live.gd runs it in its own process, as the other live harnesses are
## (decisions 0261, 0391), because only an in-tree village has a camera, a pointer and laid-out panels.
##
##     godot --headless --path godot --script res://test/live/demo_lens_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs, and a night stand-in)
##
## Paused as the player pauses (the readout reads while paused), it checks: each layer's legend (a ramp row per entry
## with its threshold, a caption with units, 14 px text); the hover readout over a bed for the three Growing layers,
## over the stream for the Water range and over a tree for the Woods, worded from the sim's own numbers, hidden over a
## panel and re-worded only on a change; the compare outlines (traced, drawn, named on the picker and in the
## readout, kept when V moves on, dropped when the shown layer becomes the compared one, gone with ✕); reduced motion
## (the readout appears at once); and every layer's area colours against the colour-blind check. Prints
## `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const Access := preload("res://demo/access/demo_access.gd")
const ColourCheck := preload("res://demo/lenses/lens_colour_check.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
## The readout reads ten times a second; it must have answered well inside this.
const READ_FRAMES: int = 600
## Bed 2: on the garden leat (weir_sluice.gd ZONE_BEDS).
const BED: int = 1

var _village: Node = null
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and run the checks."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size() - 1:
		if args[k] == "--size":
			var parts: PackedStringArray = args[k + 1].split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
		elif args[k] == "--capture":
			_capture_dir = args[k + 1]
	root.size = _size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_run.call_deferred()


func _run() -> void:
	"""Every part, then the summary."""
	await _frames(BOOT_FRAMES)
	_manager().call(&"pause_game")
	# The pause card covers the middle of the map, where the frames look: hidden for this check (it is not the layers').
	(_village.get("_card").get("hide_while") as Array).append(func() -> bool: return true)
	await _legends()
	await _readouts()
	await _compare()
	await _motion()
	_colours()
	await _night()
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers ------------------------------------------------------------------------------------------

func _frames(count: int) -> void:
	"""Wait `count` frames, holding the window size (the headless server sizes the root to 64x64 at first)."""
	for k: int in count:
		if root.size != _size:
			root.size = _size
		await process_frame


func _until(done: Callable, frames: int) -> bool:
	"""Wait until `done()` (at most `frames` frames); whether it came."""
	for k: int in frames:
		if bool(done.call()):
			return true
		await _frames(1)
	return bool(done.call())


func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail.replace("\n", " / ")])


func _capture(file_name: String) -> void:
	"""Save the frame once what was just set is drawn (only when asked for, and never headless)."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(6)
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [file_name, _size.x, _size.y]))
	_manager().set("_last_host_usec", Time.get_ticks_usec())


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _lenses() -> RefCounted:
	"""The village's map layers."""
	return _village.get("_farm").get("lenses")


func _picker() -> CanvasLayer:
	"""The Map layer picker."""
	return _village.call(&"lens_picker")


func _kit() -> Node:
	"""The readout and outlines' kit."""
	return _village.call(&"lens_kit")


func _readout() -> CanvasLayer:
	"""The hover readout."""
	return _kit().get("readout")


func _lens(group: String, label: String) -> int:
	"""A layer's row."""
	return int(_lenses().call(&"find", group, label))


func _look_at(point: Vector2) -> void:
	"""Centre the camera on a ground point -- then, while the point is behind the picker (it grows up the left side),
	look further left so the point stands right of it -- and snap there."""
	var rig: Node = _village.get("_camera")
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	var picker: Rect2 = _picker().call(&"frame_rect")
	var frame: Rect2 = Rect2(picker.position.x, 0.0, picker.size.x, picker.end.y).grow(40.0)
	for k: int in 4:
		rig.call(&"centre_on", Vector3(point.x - 6.0 * float(k), 0.0, point.y))
		rig.call(&"snap")
		await _frames(2)
		if not frame.has_point(camera.unproject_position(Vector3(point.x, 0.0, point.y))):
			return


func _hover(point: Vector2, lift_m: float = 0.0) -> Vector2:
	"""Move the pointer over a ground point (seen `lift_m` up, where its marks are drawn); its screen position."""
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	var at: Vector2 = camera.unproject_position(Vector3(point.x, lift_m, point.y))
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	await _frames(1)
	return at


func _words_after(lens: int, point: Vector2, lift_m: float = 0.0) -> String:
	"""Show `lens`, look at and hover a ground point, and wait for the readout's new words ('' if none came)."""
	_picker().call(&"choose", 0)
	await _look_at(point)
	await _hover(point, lift_m)
	await _frames(2)
	var before: int = int(_kit().get("rewords"))
	_picker().call(&"choose", lens)
	var said: bool = await _until(func() -> bool: return bool(_readout().call(&"shown")) \
		and int(_kit().get("rewords")) > before and not String(_readout().call(&"main_text")).is_empty(), READ_FRAMES)
	return String(_readout().call(&"main_text")) if said else ""


# --- the legends --------------------------------------------------------------------------------------

func _legends() -> void:
	"""The Growing and Water legends: a ramp row per entry with its threshold, a caption with units, 14 px text."""
	var moisture: int = _lens("Growing", "Soil moisture")
	_picker().call(&"choose", moisture)
	await _frames(SETTLE_FRAMES)
	var legend: Node = _picker().call(&"legend", moisture)
	var ticks: PackedStringArray = legend.call(&"ticks")
	_check("moisture: a five-segment bar, each with its threshold", int(legend.call(&"ramp_rows")) == 5
		and bool(legend.call(&"is_bar")) and not ticks.has(""), ", ".join(ticks))
	_check("moisture: the caption gives the units", String(legend.call(&"caption_text")).contains("Points of moisture"),
		legend.call(&"caption_text"))
	_check("moisture: legend text at least 14 px", _smallest_text(legend) >= 14, "%d px" % _smallest_text(legend))
	await _capture("lens_legend_moisture")
	var water: int = _lens("Getting there", "Water range")
	_picker().call(&"choose", water)
	await _frames(SETTLE_FRAMES)
	var water_legend: Node = _picker().call(&"legend", water)
	var depths: PackedStringArray = water_legend.call(&"ticks")
	_check("water: the ramp's thresholds are depths in metres", depths.size() == 3 and depths[0].ends_with(" m"),
		", ".join(depths))
	_check("water: the caption says what the depths are", String(water_legend.call(&"caption_text")).begins_with(
		"Water depth"), water_legend.call(&"caption_text"))
	await _capture("lens_legend_water")


func _smallest_text(under: Node) -> int:
	"""The smallest font size of any shown label under `under`."""
	var smallest: int = 1000
	for node: Node in under.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and not label.text.is_empty():
			smallest = mini(smallest, label.get_theme_font_size(&"font_size"))
	return smallest


# --- the hover readout --------------------------------------------------------------------------------

func _readouts() -> void:
	"""Each probed layer read under the pointer, from the sim's own numbers; hidden over a panel; worded once."""
	var sim: RefCounted = _village.get("_farm").get("sim")
	var bed: Vector2 = Catalog.bed_centre_m(BED)
	var moisture_words: String = await _words_after(_lens("Growing", "Soil moisture"), bed)
	var percent: String = "%d%%" % _percent(int(sim.call(&"moisture_of", BED)), int(sim.call(&"band_max_of", BED)))
	_check("readout: the bed's moisture, to the percent", moisture_words.begins_with("Soil moisture " + percent),
		moisture_words)
	_check("readout: the bed's own thresholds", moisture_words.contains("Bed 2") and moisture_words.contains("low <"),
		moisture_words)
	await _capture("lens_readout_moisture")
	var ripeness_words: String = await _words_after(_lens("Growing", "Ripeness"), bed)
	_check("readout: the bed's ripeness", ripeness_words.begins_with("Bed 2"), ripeness_words)
	var service_words: String = await _words_after(_lens("Growing", "Water service"), bed)
	_check("readout: what the leat brings the bed", service_words.begins_with("Bed 2 · "), service_words)
	await _stream_readout()
	await _tree_readout()
	await _over_a_panel()
	await _worded_once()


func _percent(moisture: int, band_max: int) -> int:
	"""farm_text.gd `moisture_percent`: floored, rounded up above the band's top."""
	@warning_ignore("integer_division")
	var shown: int = (moisture + 99) / 100 if moisture > band_max else moisture / 100
	return shown


func _deep_point() -> Vector2:
	"""The middle of the water map's deepest measured station (metres)."""
	var map: RefCounted = _village.get("_water").call(&"map")
	var best: int = 0
	for s: int in int(map.call(&"station_count")):
		if int(map.call(&"station_depth_u", s)) > int(map.call(&"station_depth_u", best)):
			best = s
	var a: Vector2i = map.call(&"station_a", best)
	var b: Vector2i = map.call(&"station_b", best)
	return Vector2(WaterRules.to_m(a.x + b.x), WaterRules.to_m(a.y + b.y)) * 0.5


func _stream_readout() -> void:
	"""The Water range over the deepest station: its depth, to the centimetre, and its zone for the 1.0 m mouse."""
	var point: Vector2 = _deep_point()
	var words: String = await _words_after(_lens("Getting there", "Water range"), point)
	_check("readout: the water's depth and zone", words.begins_with("Water ") and words.contains(" m deep · "), words)
	_check("readout: the painted body's thresholds", words.contains("wade ≤0.25 m · swim ≤1.00 m"), words)
	await _capture("lens_readout_water")


func _tree_readout() -> void:
	"""The Woods over the first tree: what stands there."""
	var stand: RefCounted = _village.get("_forestry").get("stand")
	if int(stand.call(&"count")) == 0:
		_check("readout: a tree (none in this village)", true)
		return
	var at: Vector2 = (stand.get("at") as PackedVector2Array)[0]
	var words: String = await _words_after(_lens("Woods", "Zones and trees"), at)
	_check("readout: the tree under the pointer", words.begins_with(String(stand.call(&"label_of", 0))), words)
	await _capture("lens_readout_tree")


func _over_a_panel() -> void:
	"""Over the picker, the readout goes."""
	var frame: Rect2 = _picker().call(&"frame_rect")
	var motion := InputEventMouseMotion.new()
	motion.position = frame.get_center()
	root.push_input(motion)
	var gone: bool = await _until(func() -> bool: return not bool(_readout().call(&"shown")), READ_FRAMES)
	_check("readout: hidden over a panel", gone)


func _worded_once() -> void:
	"""Moving the pointer within one bed re-words nothing."""
	var bed: Vector2 = Catalog.bed_centre_m(BED)
	await _words_after(_lens("Growing", "Soil moisture"), bed)
	var before: int = int(_kit().get("rewords"))
	for k: int in 12:
		await _hover(bed + Vector2(0.08 * float(k % 4), 0.06 * float(k % 3)))
		await _frames(8)
	_check("readout: worded once while the reading holds", int(_kit().get("rewords")) == before,
		"%d -> %d" % [before, int(_kit().get("rewords"))])


# --- compare ------------------------------------------------------------------------------------------

func _compare() -> void:
	"""Soil moisture with the leat's service outlined: traced and drawn, named on the picker and in the readout; kept
	when V moves on, dropped when the shown layer becomes the compared one, gone with ✕."""
	var moisture: int = _lens("Growing", "Soil moisture")
	var service: int = _lens("Growing", "Water service")
	var bed: Vector2 = Catalog.bed_centre_m(BED)
	await _words_after(moisture, bed)
	_check("compare: offered", bool(_picker().call(&"compare_offered")))
	(_picker().call(&"compare_button") as Button).emit_signal(&"pressed")
	_check("compare: the list offers the leat's service", (_picker().call(&"compare_lens_button", service) as Button).visible)
	_check("compare: and not the shown layer", not (_picker().call(&"compare_lens_button", moisture) as Button).visible)
	_picker().call(&"choose_compare", service)
	var contours: Node = _kit().get("contours")
	var drawn: bool = await _until(func() -> bool: return int(contours.call(&"vertex_count")) > 0, READ_FRAMES)
	_check("compare: the beds are outlined", drawn, "%d vertices" % int(contours.call(&"vertex_count")))
	_check("compare: the picker names it", String(_picker().call(&"compare_text")) == "Outlined: Growing: Water service",
		_picker().call(&"compare_text"))
	await _hover(bed + Vector2(0.1, 0.0))
	var both: bool = await _until(func() -> bool: return String(_readout().call(&"second_text")).begins_with(
		"Outlined, Water service"), READ_FRAMES)
	_check("compare: the readout says both", both, _readout().call(&"second_text"))
	await _capture("lens_compare_beds")
	await _compare_water()
	await _compare_rules(moisture, service)


func _compare_water() -> void:
	"""The Water range with the moisture outlined over the garden, from further out (the frames)."""
	var water: int = _lens("Getting there", "Water range")
	_picker().call(&"choose", water)
	_picker().call(&"choose_compare", _lens("Growing", "Soil moisture"))
	var contours: Node = _kit().get("contours")
	await _until(func() -> bool: return not bool(contours.call(&"is_working")), READ_FRAMES)
	var rig: Node = _village.get("_camera")
	rig.set("_target_distance", 46.0)
	await _look_at((Catalog.bed_centre_m(BED) + _deep_point()) * 0.5)
	await _capture("lens_compare_water_moisture")
	rig.call(&"reset_view")


func _compare_rules(moisture: int, service: int) -> void:
	"""Kept when the shown layer changes to another; dropped when it changes to the compared one; ✕ turns it off."""
	_picker().call(&"choose", moisture)
	_picker().call(&"choose_compare", service)
	_lenses().call(&"select", _lens("Growing", "Ripeness"))
	_check("compare: kept when another layer is shown", int(_lenses().get("compare")) == service)
	_lenses().call(&"select", service)
	_check("compare: dropped when it becomes the shown layer", int(_lenses().get("compare")) == 0)
	_picker().call(&"choose", moisture)
	_picker().call(&"choose_compare", service)
	(_picker().call(&"compare_off_button") as Button).emit_signal(&"pressed")
	var cleared: bool = await _until(func() -> bool: return int(_kit().get("contours").call(&"vertex_count")) == 0, READ_FRAMES)
	_check("compare: ✕ turns it off and clears the outline", int(_lenses().get("compare")) == 0 and cleared)


# --- reduced motion -----------------------------------------------------------------------------------

func _motion() -> void:
	"""With reduced motion the readout appears at once (no fade)."""
	var was: bool = Access.is_on(Access.SET_MOTION)
	Access.set_flag(Access.SET_MOTION, true)
	var readout: CanvasLayer = _readout()
	readout.call(&"hide_readout")
	await _frames(1)
	_check("reduced motion: gone at once", is_zero_approx(float(readout.call(&"opacity"))), "%.2f" % float(readout.call(&"opacity")))
	readout.call(&"show_again")
	await _frames(1)
	_check("reduced motion: back at once", is_equal_approx(float(readout.call(&"opacity")), 1.0),
		"%.2f" % float(readout.call(&"opacity")))
	Access.set_flag(Access.SET_MOTION, was)


# --- colours ------------------------------------------------------------------------------------------

func _colours() -> void:
	"""Every layer's area colours stay apart for deuteranopia and protanopia, by day and by night."""
	var lenses: RefCounted = _lenses()
	for lens: int in range(1, int(lenses.call(&"count"))):
		var colours: PackedColorArray = lenses.call(&"area_colours", lens)
		if colours.size() < 2:
			continue
		var failing: PackedStringArray = ColourCheck.failures(colours, lenses.call(&"over_of", lens),
			lenses.call(&"area_words", lens))
		_check("colours: %s" % String(lenses.call(&"title_of", lens)), failing.is_empty(), "; ".join(failing))


# --- the night stand-in (frames only) -----------------------------------------------------------------

func _night() -> void:
	"""The layers under a stand-in for the lighting cycle's full night (its grade, haze and moonlight; decision 0541 is
	on another branch): frames only."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	for node: Node in root.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (node as WorldEnvironment).environment
		env.adjustment_enabled = true
		env.adjustment_saturation = 0.74
		env.fog_light_color = Color(0.1, 0.12, 0.19)
		env.fog_density = 0.0026
		env.background_energy_multiplier = 0.55
		env.ambient_light_energy = 0.62
	for node: Node in root.find_children("*", "DirectionalLight3D", true, false):
		(node as DirectionalLight3D).light_energy = 0.34
		(node as DirectionalLight3D).light_color = Color(0.6, 0.7, 1.0)
	var bed: Vector2 = Catalog.bed_centre_m(BED)
	await _words_after(_lens("Growing", "Soil moisture"), bed)
	_picker().call(&"choose_compare", _lens("Growing", "Water service"))
	await _until(func() -> bool: return int(_kit().get("contours").call(&"vertex_count")) > 0, READ_FRAMES)
	await _capture("lens_night_moisture_service")
	await _words_after(_lens("Getting there", "Water range"), _deep_point())
	await _capture("lens_night_water")
