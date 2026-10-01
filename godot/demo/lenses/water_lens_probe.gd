extends "res://demo/lenses/lens_probe.gd"
## What the Water range layer says about a point (decision 0581): how deep the water is there, to the unit, and which
## zone that is for the body the layer is painted for -- or the pond's ice. Presentation only.
##
## THE NUMBERS are the water map's own: `sample_into`'s integer depth (u, 1024 a metre; one field evaluation, nothing
## allocated) against water_rules.gd's thresholds for the painted body's height (`wade_max_u`: a quarter of it;
## `dive_min_u`: all of it; at a threshold the shallower zone holds, `zone_for_depth`). The body and the ice are the
## overlay's own (water_overlay.gd `body_height_u`, `body_label`, `ice_state`, `ice_mm`), so the readout and the legend
## always name what the paint shows -- the selected resident, a group by its shortest, or the 1.0 m mouse.

const Rules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const OverlayScript := preload("res://demo/water/water_overlay.gd")

## The Water range legend's entries (demo_village.gd's order): wade, swim, dive, ..., safe ice, thin ice.
const ENTRY_WADE: int = 0
const ENTRY_SAFE_ICE: int = 7
const ENTRY_THIN_ICE: int = 8
## pond_ice.gd's states, as the overlay is told them.
const ICE_THIN: int = 1
const ICE_SAFE: int = 2
## How far past the waterline the outlines' grid reaches (m).
const MARGIN_M: float = 1.0

var _map: WaterMapScript = null
var _overlay: OverlayScript = null
var _sample: WaterMapScript.Sample = WaterMapScript.Sample.new()
var _bounds: Rect2 = Rect2()


func _init(map: WaterMapScript, overlay: OverlayScript) -> void:
	"""Read `map`'s depths for whoever `overlay` paints."""
	_map = map
	_overlay = overlay
	_bounds = shore_bounds_m(map).grow(MARGIN_M)


static func shore_bounds_m(map: WaterMapScript) -> Rect2:
	"""The box round every waterline point (x, z metres); empty for a map with none."""
	if map.shore_count() == 0:
		return Rect2()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k: int in map.shore_count():
		var p := Vector2(Rules.to_m(map.shore_point(k).x), Rules.to_m(map.shore_point(k).y))
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


func read_into(point_m: Vector2, out: Reading) -> bool:
	"""The water at the point: its depth (u) and zone for the painted body, or the pond's ice; false on dry land."""
	out.clear()
	var at := Vector2i(Rules.to_u(point_m.x), Rules.to_u(point_m.y))
	if not _map.is_near_water(at) or not _map.sample_into(at, _sample) or _sample.depth_u <= 0:
		return false
	out.value = _sample.depth_u
	out.who = _sample.body
	out.entry = Rules.zone_for_depth(_sample.depth_u, _overlay.body_height_u) - Rules.ZONE_WADE + ENTRY_WADE
	if _overlay.ice_state > 0 and _map.body_kind(_sample.body) == WaterMapScript.KIND_POND:
		out.entry = ENTRY_SAFE_ICE if _overlay.ice_state == ICE_SAFE else ENTRY_THIN_ICE
	out.area = out.entry
	return true


func can_outline() -> bool:
	"""The zones can be outlined over another layer."""
	return _bounds.has_area()


func field_bounds_m() -> Rect2:
	"""The water and its banks."""
	return _bounds


func field_revision() -> int:
	"""Moves when the zones' areas change: another body height painted, the pond iced or open."""
	return _overlay.body_height_u * 3 + _overlay.ice_state


func words_revision() -> int:
	"""Moves also with the body's name and the ice's thickness (words only: no outline is redrawn for them)."""
	return (field_revision() * 10000 + _overlay.ice_mm) ^ _overlay.body_label.hash()


func describe(reading: Reading) -> String:
	"""'Water 0.42 m deep · swim' and the painted body's thresholds; or the ice."""
	if reading.entry == ENTRY_SAFE_ICE or reading.entry == ENTRY_THIN_ICE:
		var safe: bool = reading.entry == ENTRY_SAFE_ICE
		return "Pond ice %d mm · %s\n%s" % [_overlay.ice_mm, "safe" if safe else "thin",
			"walk out and fish through it; nobody swims" if safe else "keep off"]
	var zone: int = Rules.zone_for_depth(reading.value, _overlay.body_height_u)
	return "Water %.2f m deep · %s\nfor %s: %s" % [Rules.to_m(reading.value), String(Rules.ZONE_NAMES[zone]).to_lower(),
		_overlay.body_label, thresholds_text(_overlay.body_height_u)]


static func thresholds_text(height_u: int) -> String:
	"""'wade ≤0.25 m · swim ≤1.00 m · dive deeper' for a body `height_u` tall."""
	return "wade ≤%.2f m · swim ≤%.2f m · dive deeper" % [Rules.to_m(Rules.wade_max_u(height_u)),
		Rules.to_m(Rules.dive_min_u(height_u))]


func legend_ticks() -> PackedStringArray:
	"""The ramp's depths for the painted body: wade, swim, dive."""
	var wade: float = Rules.to_m(Rules.wade_max_u(_overlay.body_height_u))
	var dive: float = Rules.to_m(Rules.dive_min_u(_overlay.body_height_u))
	return PackedStringArray(["≤%.2f m" % wade, "≤%.2f m" % dive, ">%.2f m" % dive])


func legend_caption() -> String:
	"""What the ramp measures (whom it is for is the picker's subject line)."""
	return "Water depth for the body named above"
