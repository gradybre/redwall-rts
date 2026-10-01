extends RefCounted
## The Woods panel's zone tool: drag a rectangle on the ground to mark a forestry or conservation
## zone. Decision 0196 (live demo). Presentation only; pure input logic, no nodes.
##
## Armed from the panel ("Mark forestry zone" / "Mark conservation zone"): the next left press on the
## ground starts the rectangle, motion grows it -- snapped to whole GDD §5.1 tiles and drawn brass,
## or clay where it would overlap a zone or be too small -- and the release marks it. Esc or a right
## click disarms it; so does pressing the same button again. While armed it takes every mouse button
## and Esc, so no drag becomes a box selection and no click an order.

const IntMath := preload("res://scripts/core/int_math.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")

const PHASE_OFF: int = 0
const PHASE_ARMED: int = 1
const PHASE_DRAGGING: int = 2

## ZonesScript.KIND_* being marked (KIND_NONE while off).
var zone_kind: int = ZonesScript.KIND_NONE
var phase: int = PHASE_OFF
var start_tile: Vector2i = Vector2i.ZERO
var end_tile: Vector2i = Vector2i.ZERO

var _read: IntMath.IntResult = IntMath.IntResult.new()


func arm(kind: int) -> bool:
	"""Arm the tool for `kind` -- or, pressed again for the same kind, disarm it. True when armed."""
	if phase != PHASE_OFF and zone_kind == kind:
		disarm()
		return false
	zone_kind = kind
	phase = PHASE_ARMED
	return true


func disarm() -> void:
	"""Put the tool away."""
	zone_kind = ZonesScript.KIND_NONE
	phase = PHASE_OFF


func is_armed() -> bool:
	"""Whether the tool is armed or dragging."""
	return phase != PHASE_OFF


func press(at: Vector2) -> bool:
	"""A left press on the ground at `at`: the rectangle starts there. False off the grid."""
	if phase != PHASE_ARMED or not tile_xz_into(at, _read):
		return false
	@warning_ignore("integer_division") start_tile = Vector2i(_read.value % ResourceNodes.MAP_TILES_X, _read.value / ResourceNodes.MAP_TILES_X)
	end_tile = start_tile
	phase = PHASE_DRAGGING
	return true


func move(at: Vector2) -> bool:
	"""The pointer moved to `at` while dragging: the rectangle's far corner follows (whole tiles)."""
	if phase != PHASE_DRAGGING or not tile_xz_into(at, _read):
		return false
	@warning_ignore("integer_division") end_tile = Vector2i(_read.value % ResourceNodes.MAP_TILES_X, _read.value / ResourceNodes.MAP_TILES_X)
	return true


func release(zones: ZonesScript, zone_name: String, out: IntMath.IntResult) -> bool:
	"""The release: mark the zone (its row into `out`) or refuse with the zones' reason; the tool is
	put away either way."""
	var kind: int = zone_kind
	disarm()
	return zones.add_into(kind, start_tile, end_tile, zone_name, out)


func rect_m() -> Rect2:
	"""The rectangle being dragged, in demo metres (presentation)."""
	return ZonesScript.tiles_rect_m(start_tile.min(end_tile), start_tile.max(end_tile))


func would_mark(zones: ZonesScript) -> bool:
	"""Whether the rectangle as dragged would be accepted (the preview's colour)."""
	return zones.placement_refusal(start_tile, end_tile).is_empty()


static func tile_xz_into(at: Vector2, out: IntMath.IntResult) -> bool:
	"""The tile index under a demo point (forest_rules.gd `tile_of_into`)."""
	return Rules.tile_of_into(at, out)
