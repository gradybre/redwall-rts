extends Node3D
## The farm as drawn: the beds at their stages, the map overlays, and the tunnel
## spoil heaps shrinking as spoil is carried off. Decision 0196. Presentation only.
##
## The world's own crop pieces (world/world_layout.gd CROPS, always drawn ripe) are hidden and the
## beds are drawn here instead, by farm_bed_visual.gd, from the sim's state. A bed is redrawn only
## when what it shows changes -- its stage, item, growth step, moisture band, ripeness band -- so
## the per-frame work is a comparison of a few integers per bed.
##
## OVERLAYS (V cycles them): OFF; MOISTURE, a disc over each bed in its band's colour; RIPENESS, a
## disc growing -> ripe -> past its grace. Heaps: the tunnel overlay draws each heap at the size of
## all the spoil ever heaped there; for a heap spoil has been taken from, this redraws it every
## frame, after the tunnel overlay (process_priority), at the size of what is LEFT, and hides it
## when it is empty.
##
## THE UNDERGROUND VIEW does not draw the beds, their labels or their plants: they are on the surface
## layers (decision 0206). Nothing here fades or hides for it.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Look := preload("res://demo/farm/farm_look.gd")
const AssetsScript := preload("res://demo/farm/farm_assets.gd")
const BedVisualScript := preload("res://demo/farm/farm_bed_visual.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const StockViewScript := preload("res://demo/farm/farm_stock_view.gd")

const OVERLAY_OFF: int = 0
const OVERLAY_MOISTURE: int = 1
const OVERLAY_RIPENESS: int = 2
## The garden leat's service per bed (decision 0441).
const OVERLAY_WATER: int = 3
const OVERLAY_NAMES: Array[String] = ["off", "moisture", "ripeness", "water service"]
## The world pieces this close to a bed centre are the bed (hidden).
const WORLD_PIECE_MATCH_M: float = 0.05
## A kitchen-garden site not laid out is labelled so (decision 0883).
const SITE_TITLE: String = "Garden site"
const SITE_STATUS: String = "click to lay out a bed"

var assets: AssetsScript = AssetsScript.new()
var beds: Array[BedVisualScript] = []
var overlay_mode: int = OVERLAY_OFF
## The stores' shelves (demo_farm.gd configures and refreshes it).
var stock: StockViewScript = StockViewScript.new()

var _sim: SimScript = null
var _tunnels: TunnelsScript = null
var _network: GraphScript = null
var _heap_overlay: OverlayScript = null
var _shown: PackedInt64Array = PackedInt64Array()
## Per heap: the earth taken from it when it was last drawn here (decision 0401: earth carried back is drawn again).
var _drawn_taken: PackedInt64Array = PackedInt64Array()
var _selected: int = -1
## The bed panel's Compare view's marks, one a bed ('' unmarked; decision 0451): a cream ring and the rank under the label.
var _compare: PackedStringArray = PackedStringArray()
## What the beds were last drawn for: the sim's revision and the marks (selection, overlay).
var _seen_revision: int = -1
var _seen_marks: int = -1
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""Redraw heaps after the tunnel overlay has placed them this frame."""
	process_priority = 20


func build(manifest: Dictionary, sim: SimScript) -> void:
	"""Load the staged bed art and build every bed (and site) and the pond."""
	name = "FarmView"
	_sim = sim
	assets.load_from(manifest)
	for bed: int in Catalog.BED_COUNT:
		var visual := BedVisualScript.new()
		visual.build(bed, assets)
		add_child(visual)
		beds.append(visual)
	_shown.resize(Catalog.BED_COUNT)
	_shown.fill(-1)
	add_child(stock)
	refresh()


func follow_tunnels(tunnels: TunnelsScript, network: GraphScript, heap_overlay: OverlayScript) -> void:
	"""Shrink heaps drawn by `heap_overlay`."""
	_tunnels = tunnels
	_network = network
	_heap_overlay = heap_overlay
	_drawn_taken.resize(TunnelsScript.HEAPS)
	_drawn_taken.fill(0)


static func hide_world_beds(village: Node) -> int:
	"""Hide the world's own crop pieces (always ripe) where the farm draws its beds. Returns how many."""
	var hidden: int = 0
	for child: Node in village.get_children():
		var piece := child as Node3D
		if piece == null:
			continue
		var at := Vector2(piece.position.x, piece.position.z)
		for bed: int in Catalog.BED_COUNT:
			if at.distance_to(Catalog.bed_centre_m(bed)) <= WORLD_PIECE_MATCH_M:
				piece.visible = false
				hidden += 1
	return hidden


func _process(_delta: float) -> void:
	"""Redraw beds that changed, and shrink the heaps."""
	refresh()
	_shrink_heaps()


func refresh() -> void:
	"""Redraw every bed whose shown state changed -- looked at only when the sim changed (its
	revision) or the marks did, so an unchanged frame costs two integer comparisons."""
	if _sim == null:
		return
	var marks: int = (_selected + 1) * 8 + overlay_mode
	if _sim.revision == _seen_revision and marks == _seen_marks:
		return
	_seen_revision = _sim.revision
	_seen_marks = marks
	for bed: int in Catalog.BED_COUNT:
		var key: int = _state_key(bed)
		if key != _shown[bed]:
			_shown[bed] = key
			_draw(bed)


func _ripe_hours(bed: int) -> int:
	"""Hours a ripe bed has stood (0 when not ripe)."""
	return _read.value if _sim.ripe_hours_into(bed, _read) else 0


func _state_key(bed: int) -> int:
	"""Everything a bed's drawing depends on, packed into one integer."""
	var stage: int = _sim.stage_of(bed)
	var item: int = _sim.item_of(bed) + 1
	var chosen: int = _sim.chosen_of(bed) + 1
	var growth: int = _sim.growth_permille(bed) / BedVisualScript.GROWTH_STEP
	var ripe: int = _ripe_hours(bed) / 24
	var marks: int = (1 if _selected == bed else 0) + 2 * overlay_mode
	var works: int = (1 if _sim.is_covered(bed) else 0) + (2 if _sim.is_raised(bed) else 0) \
		+ (4 if _sim.is_banked(bed) else 0) + (8 if _sim.is_ditched(bed) else 0)
	var key: int = (((((stage * 32 + item) * 32 + chosen) * 64 + growth) * 8 + _sim.band_of(bed)) * 16 + ripe)
	var laid: int = 1 if _sim.is_laid(bed) else 0
	return (((key * 16 + works) * 4 + _sim.leat_service_of(bed)) * 2 + laid) * 8 + marks


func _draw(bed: int) -> void:
	"""Draw one bed from the sim."""
	var stage: int = _sim.stage_of(bed)
	var item: int = _sim.item_of(bed)
	var growth: int = _sim.growth_permille(bed)
	var band: int = _sim.band_of(bed)
	var ripe_hours: int = _ripe_hours(bed)
	var visual: BedVisualScript = beds[bed]
	var status: String = Look.status(stage, _sim.chosen_of(bed), growth, band, ripe_hours)
	var mark: String = _compare[bed] if bed < _compare.size() else ""
	var title: String = Look.title(item, _sim.chosen_of(bed), stage)
	if not _sim.is_laid(bed):
		title = SITE_TITLE
		status = SITE_STATUS
	visual.show_state(stage, item, growth, band, ripe_hours, title, status if mark.is_empty() else "%s\n%s" % [status, mark])
	visual.show_site(not _sim.is_laid(bed))
	visual.set_selected(_selected == bed)
	visual.set_compared(not mark.is_empty())
	var laid: bool = _sim.is_laid(bed)
	visual.show_works(_sim.is_covered(bed) and laid, _sim.is_raised(bed) and laid, _sim.is_banked(bed) and laid,
		_sim.is_ditched(bed) and laid)
	visual.show_overlay(_overlay_colour(stage, band, ripe_hours, _sim.leat_service_of(bed)))


func _overlay_colour(stage: int, band: int, ripe_hours: int, service: int) -> Color:
	"""The overlay disc's colour in the current mode (clear when off)."""
	match overlay_mode:
		OVERLAY_MOISTURE:
			return Look.BAND_OVERLAY[band]
		OVERLAY_RIPENESS:
			return Look.ripeness_overlay(stage, ripe_hours)
		OVERLAY_WATER:
			return Look.SERVICE_OVERLAY[service]
	return Color(0, 0, 0, 0)


func select_bed(bed: int) -> void:
	"""Ring one bed (-1: none)."""
	_selected = bed


func set_compare(marks: PackedStringArray) -> void:
	"""The Compare view's marks, a bed each ('' for none; an empty array clears them): every bed redraws."""
	if marks == _compare:
		return
	_compare = marks.duplicate()
	_shown.fill(-1)
	_seen_marks = -1


func compare_mark(bed: int) -> String:
	"""A bed's Compare mark as drawn ('' none; checks)."""
	return _compare[bed] if bed < _compare.size() else ""


func cycle_overlay() -> int:
	"""Off -> moisture -> ripeness -> off. Returns the new mode."""
	return set_overlay((overlay_mode + 1) % OVERLAY_NAMES.size())


func set_overlay(mode: int) -> int:
	"""Show overlay `mode` (OVERLAY_*; anything else: off). Returns the mode shown."""
	overlay_mode = mode if mode > OVERLAY_OFF and mode < OVERLAY_NAMES.size() else OVERLAY_OFF
	return overlay_mode


func _shrink_heaps() -> void:
	"""Draw each heap earth was taken from at the size of what is left (hidden when empty) -- every frame while some is
	taken (the overlay redraws a heap at all it was tipped), and once more when what was taken has all come back (an
	earth return, decision 0401), so it stands whole again."""
	if _heap_overlay == null or _network == null:
		return
	for heap: int in TunnelsScript.HEAPS:
		var taken: int = _tunnels.taken_milli(_network, heap)
		if taken <= 0 and _drawn_taken[heap] == taken:
			continue
		_drawn_taken[heap] = taken
		var node: MeshInstance3D = _heap_overlay.heap(heap)
		var left: int = _tunnels.spoil_left(_network, heap)
		node.visible = left > 0
		if left > 0:
			var r: float = OverlayScript.heap_radius_m(left)
			node.scale = Vector3(r, r * OverlayScript.HEAP_ASPECT, r)
