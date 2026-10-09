extends RefCounted
## A loaded Placement's installed parts, proved against the restored Space (ADR 1228's open point).
##
## ADR 1228 restored the connector Placements and let their installed parts' geometry stand as the
## restored Space's own image. This closes that: after a load has restored Space, Placements and
## Locations, every installed part of every live Placement must be PRESENT in the restored Space.
##
## WHAT AN INSTALLED PART LEAVES BEHIND. The entry composition's timber installation
## (`underground_entry_bindings.gd::_stage_timber_part`) adds, for each part of an installed group, one
## region whose box is the part's prism (`Locations.installed_prism_into`), owned by the Placement's
## permanent Corridor, with no claim, at the Placement's level plus the part's level offset, and the
## SUPPORT role for a tread, riser, post or ramp deck (OBSTACLE otherwise). It first cuts every air
## region out of that prism. Installed parts are never removed (`retirement_refusal`).
##
## THE PROOF, IN THE DIRECTION THAT CANNOT FALSE-MATCH. It starts from the Placements, never from
## Space: a confirmed Room's reserved cuts share the Corridor's ownership (the mistake ADR 1228
## records), but carry a Room claim, and are never asked to cover anything here. For each part:
##   1. the union of the Space regions with exactly that owner, level, role and no claim covers the
##      prism (union, not one equal box, so a region later split along its own faces still proves);
##   2. no unclaimed air region (SUPPORTED_VOID or UNFINISHED) overlaps it.
## A Space image that lost a part, or a Placement image claiming a group never installed, refuses.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const ConnectorCatalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")

const REFUSE_NONE: StringName = &""
const REFUSE_PRISM: StringName = &"SAVE_INSTALLED_PART_PRISM"
const REFUSE_MISSING: StringName = &"SAVE_INSTALLED_PART_MISSING"
const REFUSE_AIR: StringName = &"SAVE_INSTALLED_PART_IN_AIR"
## The part kinds whose region is SUPPORT (`_stage_timber_part`); every other part is OBSTACLE.
const SUPPORT_KINDS: Array[int] = [ConnectorCatalog.Geometry.TREAD, ConnectorCatalog.Geometry.RISER,
	ConnectorCatalog.Geometry.POST, ConnectorCatalog.Geometry.RAMP_DECK]


class Expected:
	"""One installed part's prism and the region identity that must cover it."""
	var box: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var owner: Vector2i = Vector2i(-1, 0)
	var level: int = 0
	var role: int = 0


static func refusal(placements: Placements) -> StringName:
	"""Every installed part of every live Placement is present in `placements`' restored Space."""
	var part: Expected = Expected.new()
	for row: int in placements._capacity:
		if placements._live.present[row] != 1:
			continue
		var installed: int = placements._get32(placements._live, Placements.INSTALLED, row)
		for group: int in installed:
			var code: StringName = _group_refusal(placements, row, group, part)
			if code != REFUSE_NONE:
				return code
	return REFUSE_NONE


static func _group_refusal(placements: Placements, row: int, group: int, part: Expected) -> StringName:
	"""Every part of one installed group."""
	var groups: RefCounted = placements._assemblies
	var first: int = groups._first_part[group]
	for ordinal: int in range(first, first + groups._part_count[group]):
		if Locations.installed_prism_into(placements, row, ordinal, part.box) != REFUSE_NONE:
			return REFUSE_PRISM
		_expect(placements, row, ordinal, part)
		var code: StringName = part_refusal(placements._space, part)
		if code != REFUSE_NONE:
			return code
	return REFUSE_NONE


static func _expect(placements: Placements, row: int, ordinal: int, out: Expected) -> void:
	"""The owner, level and role `_stage_timber_part` gives this part's region."""
	var catalog: ConnectorCatalog = placements._catalog
	var at: int = catalog._live.variants[ConnectorCatalog.V_PART_START * ConnectorCatalog.MAX_VARIANTS \
		+ placements._live.header[Placements.H_CATALOG_ROW]] + ordinal
	out.owner = placements._pair(placements._live, Placements.ROOM_SLOT, row)
	out.level = placements._get32(placements._live, Placements.LEVEL, row) \
		+ catalog._live.parts[2 * ConnectorCatalog.MAX_PARTS + at]
	out.role = Space.SUPPORT if SUPPORT_KINDS.has(catalog._live.parts[at]) else Space.OBSTACLE


static func part_refusal(space: Owner, part: Expected) -> StringName:
	"""1: the matching regions cover the prism; 2: no unclaimed air overlaps it."""
	var remaining: PackedInt32Array = part.box.duplicate()
	var box: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	for region: int in space._region_capacity:
		if space._r_present[region] != 1 or space._r_claim_kind[region] != Owner.CLAIM_NONE:
			continue
		_box_of(space, region, box)
		if not Space.overlaps(box, part.box):
			continue
		var role: int = space._r_role[region]
		if role == Space.SUPPORTED_VOID or role == Space.UNFINISHED:
			return REFUSE_AIR
		if _matches(space, region, part):
			remaining = subtract(remaining, box)
	return REFUSE_NONE if remaining.is_empty() else REFUSE_MISSING


static func _matches(space: Owner, region: int, part: Expected) -> bool:
	"""The region carries the installed part's owner, level and role."""
	return space._r_role[region] == part.role and space._r_level[region] == part.level \
		and Vector2i(space._r_owner_slot[region], space._r_owner_generation[region]) == part.owner


static func _box_of(space: Owner, region: int, out: PackedInt32Array) -> void:
	"""One live region's box: low x, y, z then high x, y, z."""
	out[0] = space._r_lo_x[region]
	out[1] = space._r_lo_y[region]
	out[2] = space._r_lo_z[region]
	out[3] = space._r_hi_x[region]
	out[4] = space._r_hi_y[region]
	out[5] = space._r_hi_z[region]


static func subtract(boxes: PackedInt32Array, cover: PackedInt32Array) -> PackedInt32Array:
	"""`boxes` (six ints each) minus `cover`, as disjoint boxes; positive volumes only."""
	var out: PackedInt32Array = PackedInt32Array()
	var box: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	@warning_ignore("integer_division") var count: int = boxes.size() / 6
	for index: int in count:
		for axis: int in 6:
			box[axis] = boxes[index * 6 + axis]
		if not Space.overlaps(box, cover):
			out.append_array(box)
			continue
		_carve(box, cover, out)
	return out


static func _carve(box: PackedInt32Array, cover: PackedInt32Array, out: PackedInt32Array) -> void:
	"""Append the up-to-six slabs of `box` outside `cover`, axis by axis; `box` shrinks to the overlap."""
	for axis: int in 3:
		if box[axis] < cover[axis]:
			var low: PackedInt32Array = box.duplicate()
			low[axis + 3] = cover[axis]
			out.append_array(low)
			box[axis] = cover[axis]
		if box[axis + 3] > cover[axis + 3]:
			var high: PackedInt32Array = box.duplicate()
			high[axis] = cover[axis + 3]
			out.append_array(high)
			box[axis + 3] = cover[axis + 3]
