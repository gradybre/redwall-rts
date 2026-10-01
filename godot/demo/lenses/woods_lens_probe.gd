extends "res://demo/lenses/lens_probe.gd"
## What the Woods layer says about a point (decision 0581): the tree there, if one stands within reach, and the zone
## the point lies in -- what may be felled and what must stay. Presentation only: reads forest_stand.gd and
## forest_zones.gd, writes nothing.
##
## THE RULES are the zones' own (§5.9 as decision 0196 reads it, forest_zones.gd): a forestry zone keeps at least 20%
## of its trees mature (10% intensive), and a fell is refused at that floor (`fell_refusal`); a conservation zone is
## never cut. The zones are the AREAS the compare outlines trace; a tree is a point, said by the readout only.

const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## The Woods legend's entries (demo_village.gd's order): forestry zone, conservation zone, then the trees.
const ENTRY_FORESTRY: int = 0
const ENTRY_CONSERVATION: int = 1
## A tree's entry by forest_stand.gd STATE_* (cleared, mature, stump, young).
const TREE_ENTRY: PackedInt32Array = [5, 2, 4, 3]
## How near the pointer a tree is read (m): about a tree mark's own reach.
const TREE_REACH_M: float = 1.0
## A zone's `who`, past every tree's row.
const ZONE_WHO: int = 100000
const MARGIN_M: float = 1.0

var _stand: StandScript = null
var _zones: ZonesScript = null
var _bounds: Rect2 = Rect2()
var _bounds_revision: int = -1
var _tree: IntMath.IntResult = IntMath.IntResult.new()
var _tile: IntMath.IntResult = IntMath.IntResult.new()
var _zone: IntMath.IntResult = IntMath.IntResult.new()


func _init(stand: StandScript, zones: ZonesScript) -> void:
	"""Read `stand`'s trees and `zones`."""
	_stand = stand
	_zones = zones


func zone_at(point_m: Vector2) -> int:
	"""The zone the point lies in, -1 for none."""
	if not ForestRules.tile_of_into(point_m, _tile) or not _zones.zone_at_tile_into(_tile.value, _zone):
		return -1
	return _zone.value


func read_into(point_m: Vector2, out: Reading) -> bool:
	"""The tree within reach (else the zone) and the zone's area class; false off every tree and zone."""
	out.clear()
	var zone: int = zone_at(point_m)
	if zone >= 0:
		out.area = ENTRY_FORESTRY if _zones.kind[zone] == ZonesScript.KIND_FORESTRY else ENTRY_CONSERVATION
		out.entry = out.area
		out.who = ZONE_WHO + zone
	if _stand.nearest_into(point_m, TREE_REACH_M, -1, _tree):
		out.entry = TREE_ENTRY[_stand.state_of(_tree.value)]
		out.who = _tree.value
	if out.entry < 0:
		return false
	out.value = 0
	return true


func area_at_into(point_m: Vector2, out: Reading) -> bool:
	"""The zone's class only (the outlines trace zones; no tree search per grid corner)."""
	out.clear()
	var zone: int = zone_at(point_m)
	if zone < 0:
		return false
	out.area = ENTRY_FORESTRY if _zones.kind[zone] == ZonesScript.KIND_FORESTRY else ENTRY_CONSERVATION
	return true


func can_outline() -> bool:
	"""The zones can be outlined while there are any."""
	return field_bounds_m().has_area()


func field_bounds_m() -> Rect2:
	"""Every zone's ground, with a margin (re-measured when the zones change)."""
	if _bounds_revision != _zones.revision:
		_bounds_revision = _zones.revision
		_bounds = Rect2()
		for z: int in ZonesScript.MAX_ZONES:
			if _zones.is_zone(z):
				_bounds = _zones.rect_m(z) if not _bounds.has_area() else _bounds.merge(_zones.rect_m(z))
		_bounds = _bounds.grow(MARGIN_M) if _bounds.has_area() else Rect2()
	return _bounds


func field_revision() -> int:
	"""Moves when the zones change."""
	return _zones.revision


func words_revision() -> int:
	"""Moves also when a tree changes (a fell moves a zone's floor and what may still be felled)."""
	return _zones.revision * 1000003 + _stand.revision


func describe(reading: Reading) -> String:
	"""A tree and what its zone allows, or a zone and its floor."""
	if reading.who >= ZONE_WHO:
		var z: int = reading.who - ZONE_WHO
		return "%s zone %s\n%s" % [_zones.kind_name(z).capitalize(), _zones.names[z], _zones.floor_text(_stand, z)]
	var t: int = reading.who
	var what: String = _stand.label_of(t)
	if _stand.state_of(t) == StandScript.STATE_MATURE:
		what = "%s · mature tree" % what
	return "%s\n%s" % [what, tree_rule_text(t)]


func tree_rule_text(t: int) -> String:
	"""What the tree's zone allows it: never cut, or felled while the zone keeps its floor."""
	if not ForestRules.tile_of_into(_stand.at[t], _tile) or not _zones.zone_at_tile_into(_tile.value, _zone):
		return "in no zone: the woods' own"
	var z: int = _zone.value
	if _zones.kind[z] == ZonesScript.KIND_CONSERVATION:
		return "conservation zone %s: never cut" % _zones.names[z]
	if _stand.state_of(t) != StandScript.STATE_MATURE:
		return "forestry zone %s" % _zones.names[z]
	var refusal: String = _zones.fell_refusal(_stand, t, 0)
	return "forestry zone %s: %s (keeps %d%% mature)" % [_zones.names[z],
		"may be felled" if refusal.is_empty() else "at its floor, keep it", _zones.retain_percent(z)]
