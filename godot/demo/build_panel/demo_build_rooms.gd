extends RefCounted
## THE DUG ROOMS' VALIDITY, IN WORDS (decision 1921; Brendan's ruling of 2026-10-13, "Room becomes valid": the room's
## line updates live, "Kitchen: needs a hearth" → "✓ Kitchen ready"; no resident sleeps or cooks there yet). Demo layer
## only, read from the proof of concept's works (demo_build_works.gd) and fitted furniture (demo_build_fittings.gd).
##
## A ROOM is a 4-connected set of ordered or dug cells of one type on a level (BUILD-REQ-003; joined rooms of one type
## are one, OPEN-06). Its line, in this order -- the canonical reasons of docs/ui_ux_controls.md's "Validity in words"
## where the table has one ("Needs ...", "Too small: ..."), the rest marked PROPOSAL in decision 1921:
##   "! Kitchen: Being dug (12 cells to go)"          while any of its cells waits for the mole;
##   "! Kitchen: Needs 1 hearth and 1 kitchen bench"  the FITTED pieces short of room_catalog.gd's minimum counts;
##   "! Dormitory: Too small: Dormitory needs at least 36 cells (has 24)"  SET-BUILD-001 §4's area in cells (GDD
##                                                    §5.9's tiles, per piece where the type counts area per piece);
##   "! Bedroom: Has 2 beds: a Bedroom takes at most 1"                     a maximum count;
##   "! Bedroom: Needs walls, partitions or doors where it meets the Passage"  PARTITIONED_ENCLOSURE: every edge it
##                                                    shares with another room (or a landing) holds a fitted partition
##                                                    or door; earth around a dug room is its generated wall;
##   "! Infirmary: Needs heat: a hearth in it or in a room joined to it"    HEATED_COMPONENT, below;
##   "✓ Kitchen ready"                                otherwise.
## Every number is room_catalog.gd's (`service_requirements`), never restated. HEAT (SET-BUILD-001 §4): a fitted hearth
## heats the rooms joined to its room through open boundaries or doors (a fitted partition closes an edge), up to
## HEARTH_HEATED_TILE_CAPACITY tiles (× 4 cells) a hearth, allotted in room order, a room heated only if all of it fits.
## There is no fuel in the proof of concept: a fitted hearth counts as lit. NOT JUDGED HERE, knowingly (slice E):
## access tiles and the walk paths to them (the Dormitory's "bed access connected to the exterior", GDD §5.9).
## Recounted only when the works, the furniture or the level read change.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Furniture := preload("res://scripts/ui/build_furniture.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")

## SET-BUILD-001 §3: a GDD tile is 2 × 2 cells.
const CELLS_PER_TILE: int = 4
## SET-BUILD-001 §4: a hearth heats up to 120 tiles, 480 cells.
const HEAT_CELLS: int = BuildingDefinitions.HEARTH_HEATED_TILE_CAPACITY * CELLS_PER_TILE
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const READY: String = "✓ %s ready"
const NOT_READY: String = "! %s: %s"
const BEING_DUG: String = "Being dug (%d cells to go)"
const BEING_DUG_ONE: String = "Being dug (1 cell to go)"
const TOO_MANY: String = "Has %d %s: a %s takes at most %d"
const OPEN_SIDE: String = "Needs walls, partitions or doors where it meets the %s"
const COLD: String = "Needs heat: a hearth in it or in a room joined to it"
const LANDING: String = "landing"
const PLURALS: Dictionary = {"shelf": "shelves"}
const BED: int = Catalog.FURNITURE_DEFINITION["bed"]
const HEARTH: int = Catalog.FURNITURE_DEFINITION["hearth"]
const PARTITION: int = Catalog.FURNITURE_DEFINITION["interior_partition"]

var _rooms: RoomCatalog = RoomCatalog.new()
var _seen: Vector3i = Vector3i(-1, -1, -1)
var _level: int = -1
var _box: Rect2i = Rect2i()
## Per cell of the level's box: the room it belongs to, or -1.
var _labels: PackedInt32Array = PackedInt32Array()
var _types: PackedInt32Array = PackedInt32Array()
var _cells: PackedInt32Array = PackedInt32Array()
var _waiting: PackedInt32Array = PackedInt32Array()
var _boxes: Array[Rect2i] = []
## Per room: the cell its flood began at (its first in scan order).
var _firsts: Array[Vector2i] = []
## Per room: its fitted pieces by item type.
var _counts: Array[PackedInt32Array] = []
var _lines: PackedStringArray = PackedStringArray()
## Every line joined, kept from the last recount (read every frame by the panel: no allocation then).
var _text: String = ""
var _ready: PackedByteArray = PackedByteArray()
## The level's fitted doors and partitions: cell edge (build_furniture.gd) → item type.
var _edges: Dictionary = {}
var _works: Works = null
var _fittings: Fittings = null


func refresh(works: Works, fittings: Fittings, level: int) -> bool:
	"""Recount `level`'s rooms when the works, the furniture or the level changed; true when it did."""
	var key: Vector3i = Vector3i(works.revision, fittings.revision, level)
	if key == _seen and works == _works and fittings == _fittings:
		return false
	_seen = key
	_works = works
	_fittings = fittings
	_level = level
	_clear()
	if level >= 0 and level < Works.LEVELS:
		_label_rooms(works, level)
		_count_pieces(fittings, level)
		for room: int in _types.size():
			_lines.append(_line(room))
			_ready.append(1 if _lines[room].begins_with("✓") else 0)
	_text = "\n".join(_lines)
	return true


func _clear() -> void:
	"""Every room forgotten."""
	_types.clear()
	_cells.clear()
	_waiting.clear()
	_boxes.clear()
	_firsts.clear()
	_counts.clear()
	_lines.clear()
	_ready.clear()
	_edges.clear()


func _label_rooms(works: Works, level: int) -> void:
	"""Each 4-connected set of same-type ordered or dug cells in the level's box, one room each, in scan order."""
	_box = works.box_of(level)
	_labels.resize(_box.size.x * _box.size.y)
	_labels.fill(-1)
	for z: int in range(_box.position.y, _box.end.y):
		for x: int in range(_box.position.x, _box.end.x):
			var cell: Vector2i = Vector2i(x, z)
			if _label_at(cell) < 0 and _room_type(works, level, cell) >= 0:
				_flood(works, level, cell)


static func _room_type(works: Works, level: int, cell: Vector2i) -> int:
	"""A cell's room type when it is ordered or dug and painted as a room, else -1."""
	var type: int = works.type_of(level, cell)
	return type if type != Works.TYPE_NONE and works.state(level, cell) != Works.EARTH else -1


func _flood(works: Works, level: int, start: Vector2i) -> void:
	"""A new room: every cell of `start`'s type 4-connected to it."""
	var room: int = _types.size()
	var type: int = _room_type(works, level, start)
	_types.append(type)
	_cells.append(0)
	_waiting.append(0)
	_boxes.append(Rect2i(start, Vector2i.ONE))
	_firsts.append(start)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(RoomCatalog.FURNITURE_COUNT)
	_counts.append(counts)
	var queue: Array[Vector2i] = [start]
	_set_label(start, room)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		_cells[room] += 1
		_waiting[room] += 1 if works.state(level, cell) == Works.ORDERED else 0
		_boxes[room] = _boxes[room].expand(cell).expand(cell + Vector2i.ONE)
		for side: Vector2i in SIDES:
			var next: Vector2i = cell + side
			if _box.has_point(next) and _label_at(next) < 0 and _room_type(works, level, next) == type:
				_set_label(next, room)
				queue.append(next)


func _label_at(cell: Vector2i) -> int:
	"""The room `cell` belongs to, or -1 (off the box too)."""
	if not _box.has_point(cell):
		return -1
	return _labels[(cell.y - _box.position.y) * _box.size.x + cell.x - _box.position.x]


func _set_label(cell: Vector2i, room: int) -> void:
	"""`cell` belongs to `room`."""
	_labels[(cell.y - _box.position.y) * _box.size.x + cell.x - _box.position.x] = room


func _count_pieces(fittings: Fittings, level: int) -> void:
	"""Each fitted floor piece counted in the room under its anchor; each fitted door or partition by its edges."""
	for row: int in fittings.count():
		if fittings.level_of(row) != level or fittings.state_of(row) != Fittings.FITTED:
			continue
		if fittings.shapes.is_edge(fittings.item_of(row)):
			for edge: Vector3i in fittings.edges_of(row):
				_edges[edge] = fittings.item_of(row)
			continue
		var room: int = _label_at(fittings.anchor_of(row))
		if room >= 0:
			_counts[room][fittings.item_of(row)] += 1


# --- the words -------------------------------------------------------------------------------------------------------

func _line(room: int) -> String:
	"""Room `room`'s line (see the header)."""
	var name: String = BuildCatalog.type_name(_types[room])
	if _waiting[room] > 0:
		return NOT_READY % [name, BEING_DUG_ONE if _waiting[room] == 1 else BEING_DUG % _waiting[room]]
	var reason: String = _reason(room)
	return READY % name if reason.is_empty() else NOT_READY % [name, reason]


func _reason(room: int) -> String:
	"""Why room `room` is not ready ("" when it is): the first of its missing pieces, area, a maximum, its walls,
	its heat."""
	var needs: RoomCatalog.ServiceRequirements = _rooms.service_requirements(_types[room])
	if not needs.ok:
		return ""
	var missing: String = _missing(room, needs)
	if not missing.is_empty():
		return Validity.needs(missing)
	var reason: String = _area_reason(room, needs)
	if reason.is_empty():
		reason = _maximum_reason(room, needs)
	if reason.is_empty() and needs.owner_gates.has("PARTITIONED_ENCLOSURE"):
		reason = _enclosure_reason(room)
	if reason.is_empty() and needs.owner_gates.has("HEATED_COMPONENT") and not heated(room):
		reason = COLD
	return reason


func _missing(room: int, needs: RoomCatalog.ServiceRequirements) -> String:
	"""The pieces short of the minimum counts, in words ("1 hearth and 1 kitchen bench", "4 seats (has 1)")."""
	var parts: PackedStringArray = PackedStringArray()
	for item: int in RoomCatalog.FURNITURE_COUNT:
		var least: int = needs.minimum_counts[item]
		var have: int = _counts[room][item]
		if have < least:
			parts.append(piece_words(item, least, have))
	return " and ".join(parts)


static func piece_words(item: int, least: int, have: int) -> String:
	""""1 hearth" for one wanted and none fitted (the canonical "Needs 1 hearth"); "4 seats (has 1)" otherwise."""
	if least == 1 and have == 0:
		return "1 %s" % Furniture.name_of(item).to_lower()
	return "%d %s (has %d)" % [least, plural(item), have]


static func plural(item: int) -> String:
	"""An item's plural in words ("seats", "shelves")."""
	var key: String = String(Catalog.FURNITURE_DEFINITION.find_key(item))
	return String(PLURALS.get(key, Furniture.name_of(item).to_lower() + "s"))


func _area_reason(room: int, needs: RoomCatalog.ServiceRequirements) -> String:
	"""SET-BUILD-001 §4's least area in cells, per piece where the type counts area per piece ("" when it fits)."""
	var tiles: int = needs.minimum_tiles
	if needs.area_per_kind >= 0:
		tiles = maxi(tiles, _counts[room][needs.area_per_kind] * needs.tiles_per_piece)
	var least: int = tiles * CELLS_PER_TILE
	var name: String = BuildCatalog.type_name(_types[room])
	return Validity.too_small(name, least, _cells[room]) if _cells[room] < least else ""


func _maximum_reason(room: int, needs: RoomCatalog.ServiceRequirements) -> String:
	"""A count past its maximum ("has 2 beds: a Bedroom takes at most 1"; "" when none is)."""
	for item: int in RoomCatalog.FURNITURE_COUNT:
		var most: int = needs.maximum_counts[item]
		if most != RoomCatalog.NO_MAXIMUM and _counts[room][item] > most:
			return TOO_MANY % [_counts[room][item], plural(item), BuildCatalog.type_name(_types[room]), most]
	return ""


func _enclosure_reason(room: int) -> String:
	"""Where the room meets another room or a landing with no fitted partition or door ("" when walled all round)."""
	var box: Rect2i = _boxes[room]
	for z: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var cell: Vector2i = Vector2i(x, z)
			if _label_at(cell) != room:
				continue
			for side: int in SIDES.size():
				var open: String = _open_side(room, cell, side)
				if not open.is_empty():
					return OPEN_SIDE % open
	return ""


func _open_side(room: int, cell: Vector2i, side: int) -> String:
	"""What `cell`'s side `side` opens onto without a partition or door ("" for earth, its own room, or a closed edge):
	the other room's name, or "landing"."""
	var next: Vector2i = cell + SIDES[side]
	var other: int = _label_at(next)
	if other == room or _edges.has(edge_of(cell, side)):
		return ""
	if other >= 0:
		return BuildCatalog.type_name(_types[other])
	return LANDING if _works.state(_level, next) != Works.EARTH else ""


static func edge_of(cell: Vector2i, side: int) -> Vector3i:
	"""The cell edge on `cell`'s side `side` (0 north, 1 east, 2 south, 3 west), as build_furniture.gd keys it."""
	match side:
		0:
			return Vector3i(Furniture.EDGE_ACROSS, cell.x, cell.y)
		1:
			return Vector3i(Furniture.EDGE_DOWN, cell.x + 1, cell.y)
		2:
			return Vector3i(Furniture.EDGE_ACROSS, cell.x, cell.y + 1)
	return Vector3i(Furniture.EDGE_DOWN, cell.x, cell.y)


# --- heat ------------------------------------------------------------------------------------------------------------

func heated(room: int) -> bool:
	"""Whether room `room` gets heat (see HEAT in the header): its group's hearths' cells allotted in room order."""
	var group: Dictionary = _group_of(room)
	var hearths: int = 0
	for other: int in group:
		hearths += _counts[other][HEARTH]
	var left: int = hearths * HEAT_CELLS
	for other: int in range(_types.size()):
		if not group.has(other):
			continue
		if _cells[other] <= left:
			left -= _cells[other]
			if other == room:
				return true
		elif other == room:
			return false
	return false


func _group_of(room: int) -> Dictionary:
	"""The rooms joined to `room` through open boundaries or doors (a fitted partition closes an edge): room → true."""
	var start: Vector2i = _firsts[room]
	var group: Dictionary = {room: true}
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for side: int in SIDES.size():
			var next: Vector2i = cell + SIDES[side]
			var other: int = _label_at(next)
			if other < 0 or seen.has(next) or _edges.get(edge_of(cell, side), -1) == PARTITION:
				continue
			seen[next] = true
			group[other] = true
			queue.append(next)
	return group


# --- reads -----------------------------------------------------------------------------------------------------------

func count() -> int:
	"""Rooms on the level last read."""
	return _types.size()


func read_level() -> int:
	"""The level last read."""
	return _level


func type_of(room: int) -> int:
	"""Room `room`'s type."""
	return _types[room]


func cells_of(room: int) -> int:
	"""Room `room`'s cells."""
	return _cells[room]


func box_of(room: int) -> Rect2i:
	"""The box round room `room`'s cells."""
	return _boxes[room]


func line_of(room: int) -> String:
	"""Room `room`'s line in words."""
	return _lines[room]


func is_ready(room: int) -> bool:
	"""Whether room `room` is ready ("✓ ... ready")."""
	return _ready[room] == 1


func room_at(cell: Vector2i) -> int:
	"""The room `cell` belongs to on the level last read, or -1."""
	return _label_at(cell)


func lines_text() -> String:
	"""Every room's line, one a line ("" with none), as the last recount joined them."""
	return _text


static func beds(fittings: Fittings) -> int:
	"""Fitted beds (not patient beds), for the HUD's Beds (Brendan's "Placed beds count in the HUD's Beds")."""
	return fittings.fitted_count(BED)
