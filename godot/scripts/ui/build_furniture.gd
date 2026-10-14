extends RefCounted
## THE PENDING FURNITURE in the build panel's batch (decision 1921; Brendan's rulings of 2026-10-13 on the Furnish tab:
## "A resident fits it", "Room becomes valid", "Footprint + rotation"). A piece is one FurnitureDefinition item on one
## underground level, at a north-west ANCHOR cell, turned 0-3 quarter turns (R / Shift+R). Presentation-side and never
## saved, like the rest of the batch: packed columns, one row per placement, `live` cleared by Undo and set by Redo.
##
## FOOTPRINTS ARE READ, NOT AUTHORED HERE (SET-BUILD-001 §3 and §6): room_catalog.gd `furniture` gives GDD §5.9's
## footprint in 2 m tiles, so a 1 × 1-tile bed is 2 × 2 cells and the 2 × 1-tile kitchen bench and hearth are 4 × 2
## cells (2 × 4 turned). The two EDGE items (interior door, interior partition: GDD "tile edge", 0 × 0 floor) are 2 cell
## edges, on the side of the cursor cell the rotation names: 0 north, 1 east, 2 south, 3 west (each 2 cells long, from
## the cursor cell east for north/south and south for east/west).
##
## WHERE A PIECE MAY STAND (Brendan's "Footprint + rotation"): on DUG cells of ONE room whose type uses it
## (room_catalog.gd `compatibility_error`), overlapping no other piece -- pending here, or confirmed and waiting to be
## fitted or fitted already (the host's) -- and no way down's cells (pending: the batch's `bind_ways`; confirmed: the
## host reads them as ROOM_BARE). An edge item needs dug floor on both sides of each of its cell edges, a room that uses
## it on at least one (the other may be a landing: SET-BUILD-001 §6 asks walk cells either side of a door), shares no
## cell edge with another edge item, and never cuts through one floor piece; edge items take no floor (GDD: "no floor
## occupation"). Every refusal
## is "X Not possible" in words (build_validity.gd). NOT HERE, knowingly: access tiles and the wall-behind rule
## (SET-BUILD-001 §6, BUILD-REQ-010's full rule: slice E), and any payment ("Free for now": the ledger shows the bill).
##
## THE HOST'S READERS (`bind_host`): `room_at(level, cell) -> int` -- a dug room cell's RoomType ordinal, else
## ROOM_EARTH, ROOM_WAITING (ordered, not dug yet) or ROOM_BARE (dug, but no room: a way's landing);
## `occupant(level, cell) -> int` -- the item type of the confirmed piece covering a floor cell, or -1;
## `edge_occupant(level, edge: Vector3i) -> int` -- the item type of the confirmed edge item on a cell edge, or -1;
## `piece_at(level, cell) -> int` -- which confirmed floor piece covers a cell (any id, the same for all its cells), or -1.
## With none bound, every cell reads as earth and every piece is refused (the off-tree suites bind their own).

const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")

## SET-BUILD-001 §3: one cell is 1 m, 1024 u.
const CELL_U: int = 1024
const ROTATIONS: int = 4
const ROOM_EARTH: int = -1
const ROOM_WAITING: int = -2
const ROOM_BARE: int = -3
## A cell edge (orient, x, z): ACROSS runs along x between rows z - 1 and z; DOWN runs along z between columns x - 1
## and x.
const EDGE_ACROSS: int = 0
const EDGE_DOWN: int = 1
## The quarter-turn names, for the label and the ledger.
const TURN_WORDS: Array[String] = ["", "turned once", "turned twice", "turned three times"]
const SIDE_WORDS: Array[String] = ["north side", "east side", "south side", "west side"]

var _rooms: RoomCatalog = RoomCatalog.new()
## Per item type: its footprint in cells unturned (Vector2i.ZERO for an edge item).
var _sizes: Array[Vector2i] = []
var _levels: PackedInt32Array = PackedInt32Array()
var _xs: PackedInt32Array = PackedInt32Array()
var _zs: PackedInt32Array = PackedInt32Array()
var _turns: PackedInt32Array = PackedInt32Array()
var _items: PackedInt32Array = PackedInt32Array()
var _live: PackedByteArray = PackedByteArray()
var _room_at: Callable = Callable()
var _occupant: Callable = Callable()
var _edge_occupant: Callable = Callable()
var _piece_at: Callable = Callable()
var _ways: Callable = Callable()


func _init() -> void:
	"""Each item's footprint in cells, read once from room_catalog.gd (GDD §5.9's tiles × 2)."""
	for item: int in RoomCatalog.FURNITURE_COUNT:
		var facts: RoomCatalog.FurnitureFacts = _rooms.furniture(item)
		@warning_ignore("integer_division") var x: int = facts.footprint_units.x / CELL_U
		@warning_ignore("integer_division") var z: int = facts.footprint_units.y / CELL_U
		_sizes.append(Vector2i.ZERO if facts.edge_placement else Vector2i(x, z))


func bind_host(room_at: Callable, occupant: Callable, edge_occupant: Callable, piece_at: Callable = Callable()) -> void:
	"""The host's readers (see THE HOST'S READERS)."""
	_room_at = room_at
	_occupant = occupant
	_edge_occupant = edge_occupant
	_piece_at = piece_at


func bind_ways(ways: Callable) -> void:
	"""`ways(level) -> PackedInt32Array`: the cells (pairs) pending ways down take on `level` -- where they stand and
	where they land (the batch's own; confirmed ones are the host's ROOM_BARE)."""
	_ways = ways


static func name_of(item: int) -> String:
	"""An item's player-facing name ("Kitchen bench"), as its card shows it."""
	var key: Variant = Catalog.FURNITURE_DEFINITION.find_key(item)
	return String(BuildCatalog.ITEM_NAMES.get(String(key), String(key))) if key != null else ""


func is_item(item: int) -> bool:
	"""Whether `item` is a FurnitureDefinition."""
	return item >= 0 and item < _sizes.size()


func is_edge(item: int) -> bool:
	"""Whether `item` stands on cell edges (a door or partition)."""
	return is_item(item) and _sizes[item] == Vector2i.ZERO


func size_of(item: int, turn: int) -> Vector2i:
	"""The footprint in cells turned `turn` quarter turns (x and z swapped on an odd turn); ZERO for an edge item."""
	if not is_item(item):
		return Vector2i.ZERO
	var size: Vector2i = _sizes[item]
	return Vector2i(size.y, size.x) if posmod(turn, 2) == 1 else size


func anchor_for(item: int, turn: int, cursor: Vector2i) -> Vector2i:
	"""The north-west cell that puts the cursor cell at the footprint's middle (rounded north-west); an edge item's
	anchor is the cursor cell itself."""
	var size: Vector2i = size_of(item, turn)
	@warning_ignore("integer_division") var half: Vector2i = Vector2i((size.x - 1) / 2, (size.y - 1) / 2)
	return cursor - half.max(Vector2i.ZERO)


func cells_of(item: int, turn: int, anchor: Vector2i) -> PackedInt32Array:
	"""The floor cells a piece covers, canonical `[x, z]` pairs row by row (empty for an edge item)."""
	var size: Vector2i = size_of(item, turn)
	var out: PackedInt32Array = PackedInt32Array()
	for z: int in range(anchor.y, anchor.y + size.y):
		for x: int in range(anchor.x, anchor.x + size.x):
			out.append(x)
			out.append(z)
	return out


static func edges_of(turn: int, anchor: Vector2i) -> Array[Vector3i]:
	"""An edge item's two cell edges on the cursor cell's side `turn` names (see the header)."""
	match posmod(turn, ROTATIONS):
		0:
			return [Vector3i(EDGE_ACROSS, anchor.x, anchor.y), Vector3i(EDGE_ACROSS, anchor.x + 1, anchor.y)]
		1:
			return [Vector3i(EDGE_DOWN, anchor.x + 1, anchor.y), Vector3i(EDGE_DOWN, anchor.x + 1, anchor.y + 1)]
		2:
			return [Vector3i(EDGE_ACROSS, anchor.x, anchor.y + 1), Vector3i(EDGE_ACROSS, anchor.x + 1, anchor.y + 1)]
	return [Vector3i(EDGE_DOWN, anchor.x, anchor.y), Vector3i(EDGE_DOWN, anchor.x, anchor.y + 1)]


static func edge_sides(edge: Vector3i) -> Array[Vector2i]:
	"""The two cells a cell edge lies between (north then south, or west then east)."""
	if edge.x == EDGE_ACROSS:
		return [Vector2i(edge.y, edge.z - 1), Vector2i(edge.y, edge.z)]
	return [Vector2i(edge.y - 1, edge.z), Vector2i(edge.y, edge.z)]


static func turn_words(item_is_edge: bool, turn: int) -> String:
	"""How a piece is turned, in words: "", "turned once" ...; an edge item's side ("north side")."""
	return SIDE_WORDS[posmod(turn, ROTATIONS)] if item_is_edge else TURN_WORDS[posmod(turn, ROTATIONS)]


# --- the rows -------------------------------------------------------------------------------------------------------

func add(level: int, anchor: Vector2i, turn: int, item: int) -> int:
	"""A live piece; its row."""
	_levels.append(level)
	_xs.append(anchor.x)
	_zs.append(anchor.y)
	_turns.append(posmod(turn, ROTATIONS))
	_items.append(item)
	_live.append(1)
	return _levels.size() - 1


func set_live(row: int, live: bool) -> void:
	"""Row `row` pending (Redo) or not (Undo, or ordered)."""
	_live[row] = 1 if live else 0


func is_live(row: int) -> bool:
	"""Whether row `row` is pending."""
	return row >= 0 and row < _live.size() and _live[row] == 1


func count() -> int:
	"""Rows, live or not."""
	return _levels.size()


func live_count() -> int:
	"""Pending pieces."""
	return _live.count(1)


func level_of(row: int) -> int:
	"""The level row `row` stands on."""
	return _levels[row]


func anchor_of(row: int) -> Vector2i:
	"""Row `row`'s north-west cell (an edge item's cursor cell)."""
	return Vector2i(_xs[row], _zs[row])


func turn_of(row: int) -> int:
	"""Row `row`'s quarter turns, 0-3."""
	return _turns[row]


func item_of(row: int) -> int:
	"""Row `row`'s item type."""
	return _items[row]


func clear() -> void:
	"""Every row dropped (Discard all)."""
	_levels.clear()
	_xs.clear()
	_zs.clear()
	_turns.clear()
	_items.clear()
	_live.clear()


# --- judging ---------------------------------------------------------------------------------------------------------

func judge(level: int, anchor: Vector2i, turn: int, item: int, own_row: int) -> Array:
	"""[kind, reason] for a piece (`own_row`: its own pending row, -1 for a new one). Cold: on placement, on a cursor
	move, and once per judgement of the batch."""
	if not is_item(item):
		return [Validity.KIND_NOT_POSSIBLE, Validity.not_on_room()]
	if is_edge(item):
		return _judge_edge(level, edges_of(turn, anchor), item, own_row)
	return _judge_floor(level, cells_of(item, turn, anchor), item, own_row)


func _judge_floor(level: int, cells: PackedInt32Array, item: int, own_row: int) -> Array:
	"""A floor piece: every cell dug, of one room, a room that uses it, and no other piece on any cell."""
	var room: int = ROOM_EARTH
	for at: int in range(0, cells.size(), 2):
		var here: int = _room(level, Vector2i(cells[at], cells[at + 1]))
		if here < 0:
			return [Validity.KIND_NOT_POSSIBLE, _not_floor_words(here)]
		if at > 0 and here != room:
			return [Validity.KIND_NOT_POSSIBLE, Validity.two_rooms()]
		room = here
	if _rooms.compatibility_error(room, item) != &"":
		return [Validity.KIND_NOT_POSSIBLE, Validity.wrong_room(name_of(item), allowed_words(item))]
	if _ways.is_valid() and _shares(cells, PackedInt32Array(_ways.call(level))):
		return [Validity.KIND_NOT_POSSIBLE, Validity.on_way_down()]
	var other: int = _floor_clash(level, cells, own_row)
	if other >= 0:
		return [Validity.KIND_NOT_POSSIBLE, Validity.piece_overlaps(name_of(other))]
	return [Validity.KIND_CAN_BUILD, ""]


func _judge_edge(level: int, edges: Array[Vector3i], item: int, own_row: int) -> Array:
	"""An edge item: each edge between dug floors with a room that uses it on one side at least, cutting no piece; no
	other edge item there."""
	for edge: Vector3i in edges:
		var refusal: String = _edge_refusal(level, edge, item)
		if not refusal.is_empty():
			return [Validity.KIND_NOT_POSSIBLE, refusal]
	var other: int = _edge_clash(level, edges, own_row)
	if other >= 0:
		return [Validity.KIND_NOT_POSSIBLE, Validity.piece_overlaps(name_of(other))]
	return [Validity.KIND_CAN_BUILD, ""]


func _edge_refusal(level: int, edge: Vector3i, item: int) -> String:
	"""Why `item` cannot stand on `edge` ("" when it can): earth or undug floor on a side, no room on either side, a
	room that does not use it, or one floor piece on both sides."""
	var sides: Array[Vector2i] = edge_sides(edge)
	var rooms_seen: int = 0
	for side: Vector2i in sides:
		var here: int = _room(level, side)
		if here < 0 and here != ROOM_BARE:
			return Validity.not_between_floors(name_of(item))
		if here >= 0 and _rooms.compatibility_error(here, item) != &"":
			return Validity.wrong_room(name_of(item), allowed_words(item))
		rooms_seen += 1 if here >= 0 else 0
	if rooms_seen == 0:
		return Validity.not_between_floors(name_of(item))
	var cut: int = _piece_across(level, sides[0], sides[1])
	return Validity.cuts_piece(name_of(cut)) if cut >= 0 else ""


func _piece_across(level: int, a: Vector2i, b: Vector2i) -> int:
	"""The item type of a floor piece (pending, then the host's) covering both `a` and `b`, or -1."""
	var pair: PackedInt32Array = PackedInt32Array([a.x, a.y])
	var other: PackedInt32Array = PackedInt32Array([b.x, b.y])
	for row: int in _levels.size():
		if _live[row] == 0 or _levels[row] != level or is_edge(_items[row]):
			continue
		var cells: PackedInt32Array = cells_of(_items[row], _turns[row], anchor_of(row))
		if _shares(pair, cells) and _shares(other, cells):
			return _items[row]
	if not _piece_at.is_valid():
		return -1
	var piece: int = int(_piece_at.call(level, a))
	return int(_occupant.call(level, a)) if piece >= 0 and piece == int(_piece_at.call(level, b)) else -1


func floor_taken(level: int, cells: PackedInt32Array) -> int:
	"""The item type of the first piece, pending or confirmed, on any of `cells` on `level`, or -1 (a way down placed
	over furniture is refused by it: the batch's `judge_item`)."""
	return _floor_clash(level, cells, -1)


func _room(level: int, cell: Vector2i) -> int:
	"""The host's room reading for a cell (ROOM_EARTH with no host)."""
	return int(_room_at.call(level, cell)) if _room_at.is_valid() else ROOM_EARTH


static func _not_floor_words(code: int) -> String:
	"""Why a cell is no room floor: not dug yet, or not in a room."""
	return Validity.not_dug() if code == ROOM_WAITING else Validity.not_on_room()


func allowed_words(item: int) -> String:
	"""The room types that use `item`, in words ("Dormitory or Bedroom"; build_catalog.gd `users_in`)."""
	return BuildCatalog.users_in(_rooms, item)


func _floor_clash(level: int, cells: PackedInt32Array, own_row: int) -> int:
	"""The item type of the first piece (pending, then the host's) on any of `cells`, or -1."""
	for row: int in _levels.size():
		if row == own_row or _live[row] == 0 or _levels[row] != level or is_edge(_items[row]):
			continue
		if _shares(cells, cells_of(_items[row], _turns[row], anchor_of(row))):
			return _items[row]
	for at: int in range(0, cells.size(), 2):
		var there: int = int(_occupant.call(level, Vector2i(cells[at], cells[at + 1]))) if _occupant.is_valid() else -1
		if there >= 0:
			return there
	return -1


func _edge_clash(level: int, edges: Array[Vector3i], own_row: int) -> int:
	"""The item type of the first edge item (pending, then the host's) on any of `edges`, or -1."""
	for row: int in _levels.size():
		if row == own_row or _live[row] == 0 or _levels[row] != level or not is_edge(_items[row]):
			continue
		for edge: Vector3i in edges_of(_turns[row], anchor_of(row)):
			if edges.has(edge):
				return _items[row]
	for edge: Vector3i in edges:
		var there: int = int(_edge_occupant.call(level, edge)) if _edge_occupant.is_valid() else -1
		if there >= 0:
			return there
	return -1


static func _shares(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	"""Whether two cell lists (pairs) share a cell."""
	for i: int in range(0, a.size(), 2):
		for j: int in range(0, b.size(), 2):
			if a[i] == b[j] and a[i + 1] == b[j + 1]:
				return true
	return false


func row_judgement(row: int) -> Array:
	"""[kind, reason] for pending row `row` where it stands now."""
	return judge(_levels[row], anchor_of(row), _turns[row], _items[row], row)


# --- the ledger's reads -----------------------------------------------------------------------------------------------

func bill_into(goods: PackedStringArray, milli: PackedInt64Array) -> int:
	"""Every pending piece's bill (balance §4.3, Construction's rows), summed per good into `goods` / `milli` (cleared
	first, in order of first appearance); returns the work in milli-WU. Free for now: shown, never deducted."""
	goods.clear()
	milli.clear()
	var work: int = 0
	for row: int in _levels.size():
		if _live[row] == 0:
			continue
		var facts: RoomCatalog.FurnitureFacts = _rooms.furniture(_items[row])
		work += facts.work_mwu
		for at: int in facts.material_keys.size():
			var slot: int = goods.find(facts.material_keys[at])
			if slot < 0:
				goods.append(facts.material_keys[at])
				milli.append(0)
				slot = goods.size() - 1
			milli[slot] += facts.quantity_milli[at]
	return work
