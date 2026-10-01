extends Node
## The map layers' readout and compare outlines, wired to the village (decision 0581). Presentation only: it reads the
## layers' probes and writes nothing to the simulation.
##
## WHAT IT OWNS. The hover readout (demo/ui/demo_lens_readout.gd) and the compare outlines (lens_contours.gd); the
## probes of the village's own layers (bed_lens_probe.gd for the three Growing layers, water_lens_probe.gd for the
## Water range, woods_lens_probe.gd for the Woods), given to their rows by group and label; and their legend scales
## (lens_scales.gd). Routes and Underground have no probe: no readout, not comparable. A layer added later as a
## record (lens_def.gd) brings its own probe and needs nothing here.
##
## THE THROTTLE. Ten times a second on real time (it reads while paused) -- never per frame -- it asks the shown
## layer's probe, and the compared one's, what lies under the pointer, and re-words the readout only when a Reading
## (or a probe's field revision) changed. Per frame it only moves the readout with the pointer and spends the
## outlines' slice (lens_contours.gd `step`, about a millisecond while a trace runs). Neither allocates: the Readings
## are kept, the pick is a ray against the ground plane (demo_layers.gd `pick_ground`), and words are formatted only
## on a change.
##
## THE COMPARED LAYER (map_lenses.gd `compare`) is traced when it is chosen and again when its probe's field revision
## moves (a bed changing colour, another body painted, a zone marked); off, its outline is cleared at once.

const LensesScript := preload("res://demo/map_lenses.gd")
const ProbeScript := preload("res://demo/lenses/lens_probe.gd")
const BedProbe := preload("res://demo/lenses/bed_lens_probe.gd")
const WaterProbe := preload("res://demo/lenses/water_lens_probe.gd")
const WoodsProbe := preload("res://demo/lenses/woods_lens_probe.gd")
const Scales := preload("res://demo/lenses/lens_scales.gd")
const ContoursScript := preload("res://demo/lenses/lens_contours.gd")
const ReadoutScript := preload("res://demo/ui/demo_lens_readout.gd")
const Layers := preload("res://demo/demo_layers.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterOverlayScript := preload("res://demo/water/water_overlay.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")

## How often the pointer is read (real seconds).
const READ_USEC: int = 100000
## Where the compared layer's words start in the readout.
const COMPARE_WORDS: String = "Outlined, %s:\n%s"

var readout: ReadoutScript = null
var contours: ContoursScript = null
## Readout re-wordings so far (checks: the throttle and "only on a change").
var rewords: int = 0

var _lenses: LensesScript = null
## Where the pointer last moved, viewport px (from its motion events: a headless window reports no position of its own).
var _pointer: Vector2 = Vector2.INF
var _next_read_usec: int = 0
## The lenses' revision last seen: a change (another layer shown or compared) is read at once, not on the next tick.
var _seen_revision: int = -1
var _main: ProbeScript.Reading = ProbeScript.Reading.new()
var _main_seen: ProbeScript.Reading = ProbeScript.Reading.new()
var _second: ProbeScript.Reading = ProbeScript.Reading.new()
var _second_seen: ProbeScript.Reading = ProbeScript.Reading.new()
## What the words were last made for: the two lenses, whether each read anything, and their field revisions.
var _seen_key: PackedInt64Array = PackedInt64Array([-1, -1, -1, -1, -1, -1])
var _key: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])
var _traced_lens: int = LensesScript.OFF
var _traced_field: int = -1
## Per lens, the field revision its legend's ticks were last taken at.
var _ticks_seen: PackedInt64Array = PackedInt64Array()


func attach(lenses: LensesScript, sim: SimScript, water_map: WaterMapScript, water_overlay: WaterOverlayScript,
		stand: StandScript, zones: ZonesScript) -> void:
	"""Give the village's layers their probes and scales, and build the readout and the outlines."""
	name = "DemoLensKit"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lenses = lenses
	Scales.apply(lenses)
	_probe_for("Growing", "Soil moisture", BedProbe.new(sim, BedProbe.MODE_MOISTURE) if sim != null else null)
	_probe_for("Growing", "Ripeness", BedProbe.new(sim, BedProbe.MODE_RIPENESS) if sim != null else null)
	_probe_for("Growing", "Water service", BedProbe.new(sim, BedProbe.MODE_SERVICE) if sim != null else null)
	var water: ProbeScript = WaterProbe.new(water_map, water_overlay) if water_map != null and water_overlay != null else null
	_probe_for("Getting there", "Water range", water)
	_probe_for("Woods", "Zones and trees", WoodsProbe.new(stand, zones) if stand != null and zones != null else null)
	readout = ReadoutScript.new()
	add_child(readout)
	contours = ContoursScript.new()
	add_child(contours)
	follow_ticks()


func _probe_for(group: String, label: String, probe: ProbeScript) -> void:
	"""Give the layer with this group and label its probe (when the village has that layer and the probe)."""
	var lens: int = _lenses.find(group, label)
	if lens != LensesScript.OFF and probe != null:
		_lenses.set_probe(lens, probe)


func _input(event: InputEvent) -> void:
	"""Follow the pointer (it is never consumed here)."""
	var motion := event as InputEventMouseMotion
	if motion != null:
		_pointer = motion.position


func _process(_delta: float) -> void:
	"""Per frame: the outlines' slice and the readout at the pointer; ten times a second, the probes."""
	if _lenses == null:
		return
	if contours.is_working():
		contours.step()
	var viewport: Viewport = get_viewport()
	if readout.shown() and _pointer != Vector2.INF:
		readout.place(_pointer, viewport.get_visible_rect().size)
	var now: int = Time.get_ticks_usec()
	if now < _next_read_usec and _lenses.revision == _seen_revision:
		return
	_seen_revision = _lenses.revision
	_next_read_usec = now + READ_USEC
	follow_compare()
	follow_ticks()
	var over_ui: bool = viewport.gui_get_hovered_control() != null
	update_readout(_pointer, viewport.get_visible_rect().size, over_ui)


func follow_compare() -> void:
	"""Trace the compared layer when it changes or its areas may have; clear the outline when there is none."""
	var lens: int = _lenses.compare
	if lens == LensesScript.OFF:
		if _traced_lens != LensesScript.OFF:
			_traced_lens = LensesScript.OFF
			contours.clear_outline()
		return
	var probe: ProbeScript = _lenses.probe_of(lens)
	var field: int = probe.field_revision()
	if lens != _traced_lens or field != _traced_field:
		_traced_lens = lens
		_traced_field = field
		contours.start(probe, _lenses.swatches_of(lens))


func follow_ticks() -> void:
	"""A legend whose thresholds follow a subject (the Water range's depths) takes them when its probe's field moves."""
	if _ticks_seen.size() < _lenses.count():
		var was: int = _ticks_seen.size()
		_ticks_seen.resize(_lenses.count())
		for k: int in range(was, _ticks_seen.size()):
			_ticks_seen[k] = -1
	for lens: int in range(1, _lenses.count()):
		var probe: ProbeScript = _lenses.probe_of(lens)
		if probe == null or probe.field_revision() == _ticks_seen[lens]:
			continue
		_ticks_seen[lens] = probe.field_revision()
		var ticks: PackedStringArray = probe.legend_ticks()
		if not ticks.is_empty():
			_lenses.set_ticks(lens, ticks, probe.legend_caption())


func update_readout(pointer: Vector2, viewport_size: Vector2, over_ui: bool) -> void:
	"""Read the shown and the compared layer under `pointer` and re-word the readout on a change; hide it over a
	panel, off the window, off the ground, or where neither layer has anything to say."""
	var main: ProbeScript = _lenses.probe_of(_lenses.active)
	var second: ProbeScript = _lenses.probe_of(_lenses.compare)
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if not may_read(main != null or second != null, over_ui, camera != null, pointer, viewport_size):
		readout.hide_readout()
		return
	var point: Vector2 = Layers.pick_ground(camera.project_ray_origin(pointer), camera.project_ray_normal(pointer), 0.0)
	read_point(point, main, second)
	readout.place(pointer, viewport_size)


static func may_read(has_probe: bool, over_ui: bool, has_camera: bool, pointer: Vector2, viewport_size: Vector2) -> bool:
	"""Whether the pointer may be read: some layer to read, not over a panel, a camera, a pointer inside the window."""
	return has_probe and not over_ui and has_camera and pointer != Vector2.INF \
		and Rect2(Vector2.ZERO, viewport_size).has_point(pointer)


func read_point(point: Vector2, main: ProbeScript, second: ProbeScript) -> bool:
	"""Read both layers at a ground point (x, z m; INF: off the ground) into the readout; returns whether it shows."""
	var has_main: bool = point != Vector2.INF and main != null and main.read_into(point, _main)
	var has_second: bool = point != Vector2.INF and second != null and second.read_into(point, _second)
	if not has_main and not has_second:
		readout.hide_readout()
		return false
	_key[0] = _lenses.active
	_key[1] = _lenses.compare
	_key[2] = int(has_main) + 2 * int(has_second)
	_key[3] = main.field_revision() if main != null else 0
	_key[4] = second.field_revision() if second != null else 0
	_key[5] = 0
	if _key == _seen_key and _main.same_as(_main_seen) and _second.same_as(_second_seen):
		readout.show_again()
		return true
	_reword(main, second, has_main, has_second)
	return true


func _reword(main: ProbeScript, second: ProbeScript, has_main: bool, has_second: bool) -> void:
	"""New words for what the layers read now; remember what they were made for."""
	for k: int in _key.size():
		_seen_key[k] = _key[k]
	_main_seen.copy_from(_main)
	_second_seen.copy_from(_second)
	var main_words: String = main.describe(_main) if has_main else ""
	var second_words: String = ""
	if has_second:
		second_words = COMPARE_WORDS % [_lenses.label_of(_lenses.compare), second.describe(_second)]
	readout.set_words(main_words, second_words)
	rewords += 1
