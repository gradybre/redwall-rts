extends RefCounted
## The demo's forestry and conservation zones. Decision 0196 (live demo). Presentation only: the
## HUD's Zone tool places the SETTLEMENT's zones, which the demo never writes, so these are the
## demo's own, marked from the Woods panel.
##
## A zone is a rectangle of GDD §5.1 exterior tiles with a GDD §4.3 ZoneType: FORESTRY (5) or
## CONSERVATION (8). Zones never overlap, so every tree answers to at most one.
##
## THE RETENTION FLOOR (§5.9): "A forestry zone retains at least 20% mature trees by default;
## intensive override retains 10%." INTERPRETATION (recorded for decision 0196): the share is of the
## zone's TREES -- every live row standing in it, mature, young or stump; a cleared spot has none --
## and a fell is allowed only while the mature trees left after it, less the fells already ordered
## in the zone, still make up that share. So a zone of 6 keeps ceil(6 x 20%) = 2 standing.
## CONSERVATION zones are never cut, by order or by routine ("Protected tiles are never
## automatically harvested", §5.9's forage rule, read for trees too); their deadfall may be gathered.
##
## AUTO-FELL: a forestry zone may be worked by the routine forestry crew, down to its floor, when the
## player switches it on (off by default). Conservation zones cannot be switched on.

const IntMath := preload("res://scripts/core/int_math.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")

## GDD §4.3 ZoneType values.
const KIND_NONE: int = -1
const KIND_FORESTRY: int = 5
const KIND_CONSERVATION: int = 8
const MAX_ZONES: int = 8
const MIN_SIDE_TILES: int = 2

const REFUSE_BAD_KIND: String = "NOT_A_WOODS_ZONE"
const REFUSE_TOO_SMALL: String = "ZONE_TOO_SMALL"
const REFUSE_OVERLAP: String = "OVERLAPS_A_ZONE"
const REFUSE_FULL: String = "NO_MORE_ZONES"
const REFUSE_NONE_HERE: String = "NO_ZONE_HERE"
const REFUSE_PROTECTED: String = "PROTECTED"
const REFUSE_FLOOR: String = "RETENTION_FLOOR"
const REFUSE_NOT_FORESTRY: String = "NOT_A_FORESTRY_ZONE"

var kind: PackedInt32Array = PackedInt32Array()
## Inclusive tile bounds per zone.
var x0: PackedInt32Array = PackedInt32Array()
var z0: PackedInt32Array = PackedInt32Array()
var x1: PackedInt32Array = PackedInt32Array()
var z1: PackedInt32Array = PackedInt32Array()
var intensive: PackedByteArray = PackedByteArray()
var auto_fell: PackedByteArray = PackedByteArray()
var names: PackedStringArray = PackedStringArray()
var revision: int = 0

var _made: int = 0
var _tally: PackedInt32Array = PackedInt32Array()
var _scratch: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""Size every column once; no zones."""
	for column: PackedInt32Array in [kind, x0, z0, x1, z1]:
		column.resize(MAX_ZONES)
	intensive.resize(MAX_ZONES)
	auto_fell.resize(MAX_ZONES)
	names.resize(MAX_ZONES)
	kind.fill(KIND_NONE)
	_tally.resize(4)


func is_zone(z: int) -> bool:
	"""Whether `z` names a live zone."""
	return z >= 0 and z < MAX_ZONES and kind[z] != KIND_NONE


func add_into(zone_kind: int, a: Vector2i, b: Vector2i, zone_name: String, out: IntMath.IntResult) -> bool:
	"""Mark a zone over the tiles from `a` to `b` (either corner first). `out.value` is its row.
	Refuses a kind that is not FORESTRY or CONSERVATION, a side under MIN_SIDE_TILES, an overlap with
	another zone, or a full list."""
	if zone_kind != KIND_FORESTRY and zone_kind != KIND_CONSERVATION:
		return out.refuse(REFUSE_BAD_KIND)
	var code: String = placement_refusal(a, b)
	if not code.is_empty():
		return out.refuse(code)
	var row: int = kind.find(KIND_NONE)
	if row < 0:
		return out.refuse(REFUSE_FULL)
	_write(row, zone_kind, a.min(b), a.max(b), zone_name)
	return out.succeed(row)


func placement_refusal(a: Vector2i, b: Vector2i) -> String:
	"""Why a zone over the tiles from `a` to `b` cannot be marked ("" when it can): a side under
	MIN_SIDE_TILES, or an overlap with a zone already marked."""
	var lo: Vector2i = a.min(b)
	var hi: Vector2i = a.max(b)
	if hi.x - lo.x + 1 < MIN_SIDE_TILES or hi.y - lo.y + 1 < MIN_SIDE_TILES:
		return REFUSE_TOO_SMALL
	for z: int in MAX_ZONES:
		if is_zone(z) and lo.x <= x1[z] and hi.x >= x0[z] and lo.y <= z1[z] and hi.y >= z0[z]:
			return REFUSE_OVERLAP
	return ""


func _write(row: int, zone_kind: int, lo: Vector2i, hi: Vector2i, zone_name: String) -> void:
	"""Fill one zone row."""
	_made += 1
	kind[row] = zone_kind
	x0[row] = lo.x
	z0[row] = lo.y
	x1[row] = hi.x
	z1[row] = hi.y
	intensive[row] = 0
	auto_fell[row] = 0
	var fallback: String = "%s %d" % ["Forestry zone" if zone_kind == KIND_FORESTRY else "Conservation zone", _made]
	names[row] = zone_name if not zone_name.is_empty() else fallback
	revision += 1


func remove(z: int) -> bool:
	"""Unmark a zone. False when there is none."""
	if not is_zone(z):
		return false
	kind[z] = KIND_NONE
	revision += 1
	return true


func set_intensive(z: int, on: bool) -> bool:
	"""§5.9's intensive override (retain 10%) on a forestry zone. False on anything else."""
	if not is_zone(z) or kind[z] != KIND_FORESTRY:
		return false
	intensive[z] = 1 if on else 0
	revision += 1
	return true


func set_auto(z: int, on: bool) -> bool:
	"""Let the routine crew fell a forestry zone down to its floor. False on anything else."""
	if not is_zone(z) or kind[z] != KIND_FORESTRY:
		return false
	auto_fell[z] = 1 if on else 0
	revision += 1
	return true


func zone_at_tile_into(tile: int, out: IntMath.IntResult) -> bool:
	"""The zone covering exterior tile `tile`, into `out`; refuses NO_ZONE_HERE."""
	var tx: int = tile % ResourceNodes.MAP_TILES_X
	var tz: int = tile / ResourceNodes.MAP_TILES_X
	for z: int in MAX_ZONES:
		if is_zone(z) and tx >= x0[z] and tx <= x1[z] and tz >= z0[z] and tz <= z1[z]:
			return out.succeed(z)
	return out.refuse(REFUSE_NONE_HERE)


func retain_percent(z: int) -> int:
	"""The share of its trees zone `z` keeps mature: 20%, or 10% intensive (§5.9)."""
	return Rules.INTENSIVE_RETAIN_PERCENT if intensive[z] == 1 else Rules.RETAIN_PERCENT


func tally_into(stand: StandScript, z: int, out: PackedInt32Array) -> void:
	"""Zone `z`'s trees by StandScript.STATE_* into `out` (4 entries)."""
	out.resize(4)
	out.fill(0)
	for t: int in stand.count():
		if zone_at_tile_into(stand.tile[t], _scratch) and _scratch.value == z:
			out[stand.state_of(t)] += 1


func fell_refusal(stand: StandScript, t: int, pending_in_zone: int) -> String:
	"""Why tree `t` may not be felled now ("" when it may): a conservation zone protects it; a forestry
	zone keeps its floor, counting `pending_in_zone` fells already ordered there."""
	if not zone_at_tile_into(stand.tile[t], _scratch):
		return ""
	var z: int = _scratch.value
	if kind[z] == KIND_CONSERVATION:
		return REFUSE_PROTECTED
	tally_into(stand, z, _tally)
	var total: int = _tally[StandScript.STATE_MATURE] + _tally[StandScript.STATE_YOUNG] + _tally[StandScript.STATE_STUMP]
	var after: int = _tally[StandScript.STATE_MATURE] - 1 - pending_in_zone
	return "" if Rules.retention_allows(after, total, retain_percent(z)) else REFUSE_FLOOR


func floor_text(stand: StandScript, z: int) -> String:
	"""e.g. "5 of 6 trees mature, keeps 2 (20%)"."""
	tally_into(stand, z, _tally)
	var total: int = _tally[StandScript.STATE_MATURE] + _tally[StandScript.STATE_YOUNG] + _tally[StandScript.STATE_STUMP]
	if kind[z] == KIND_CONSERVATION:
		return "%d trees, never cut" % total
	return "%d of %d trees mature, keeps %d (%d%%)" % [_tally[StandScript.STATE_MATURE], total,
		Rules.floor_mature(total, retain_percent(z)), retain_percent(z)]


func rect_m(z: int) -> Rect2:
	"""Zone `z`'s area in demo metres (presentation)."""
	return tiles_rect_m(Vector2i(x0[z], z0[z]), Vector2i(x1[z], z1[z]))


static func tiles_rect_m(lo: Vector2i, hi: Vector2i) -> Rect2:
	"""The ground covered by the tiles from `lo` to `hi` inclusive, in demo metres (presentation)."""
	var half := Vector2.ONE * float(ResourceNodes.TILE_CENTER_OFFSET_UNITS) / float(Rules.UNITS_PER_M)
	var a: Vector2 = Rules.tile_centre_m(lo.y * ResourceNodes.MAP_TILES_X + lo.x) - half
	var b: Vector2 = Rules.tile_centre_m(hi.y * ResourceNodes.MAP_TILES_X + hi.x) + half
	return Rect2(a, b - a)


func kind_name(z: int) -> String:
	"""The zone's kind in words: forestry or conservation."""
	return "forestry" if kind[z] == KIND_FORESTRY else "conservation"
