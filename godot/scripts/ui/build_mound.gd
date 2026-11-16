extends RefCounted
## MOUND HOMES' RULES in the build panel (decision 2002, the proof of concept of decision 2001; SET-BUILD-001 §12,
## BUILD-MOUND-001..031). A MOUND ROOM is a room painted on the Surface (level 0) in the Mound style: a hill is heaped
## to fit the rooms, they are dug into it, framed and topped. Pure and static: cells, cell edges and words, read
## through the caller's own `is_room(cell) -> bool`. Nothing here is saved or decides a game outcome.
##
## CELL EDGES. An edge is Vector3i(x, z, side): cell (x, z)'s side 0 north (-z), 1 east (+x), 2 south (+z), 3 west
## (-x) -- the Furnish tab's quarter turns (build_furniture.gd). An OUTER EDGE is a Mound room cell's side whose other
## cell is in no room (BUILD-MOUND §12 "Terms"). A DOOR takes two neighbouring outer edges facing the same way, from
## its cell along the side (east for north and south, south for east and west, as an edge item's two edges are); a
## WINDOW takes one. Both are placed by the player, never generated (BUILD-MOUND-010, -013).
##
## THE HEAP'S FOOTPRINT (BUILD-MOUND-003, P-2001-4 (a) as amended by Brendan on 2026-10-16: "Rounder, like the mockup",
## about 4 cells): every cell within BERM_CELLS of a Mound room cell, measured between the cells' squares (a cell is
## covered when its gap to some room cell, in whole cells each way, has gx² + gz² < BERM_CELLS²): the berm falls in a
## rounded curve from the outer walls to the ground there, so no earth margin is left beyond it.
## THE YARD (P-2001-5 (a)): in front of a door, its two cells and YARD_SIDE_CELLS more each side (6 cells wide), out
## BERM_CELLS cells to the berm's foot, kept at ground height and never heaped. Round it the ground falls to the yard:
## its sides slope down to it past its first cell, and the cell beyond its foot looks onto it. So no room stands in a
## door's YARD KEEP -- the yard, a cell beyond its foot and YARD_KEEP_CELLS either side (a wall there would open onto
## the cut) -- and no window looks out within YARD_WINDOW_CELLS of a yard's side (the slope there is cut below the
## wall's top metre, and the garden stands there). Both PROPOSALS (decision 2002).

const STYLE_BUILT: int = 0
const STYLE_MOUND: int = 1
const STYLE_COUNT: int = 2
const STYLE_NAMES: Array[String] = ["Built", "Mound"]
## The Surface: the only level Mound rooms are painted on (BUILD-MOUND-001, -028).
const SURFACE: int = 0
## DEC-054's 2026-10-15 addendum: a dug room is 4096 u high; P-2001-4 (a): a 1024 u cover over it.
const ROOM_HEIGHT_U: int = 4096
const COVER_U: int = 1024
## The berm's footprint, in cells beyond an outer wall: P-2001-4 (a)'s 3, widened to about 4 by Brendan's ruling of
## 2026-10-16 ("Rounder, like the mockup"; decision 2002).
const BERM_CELLS: int = 4
## P-2001-5 (a): a door's yard is its 2 cells and this many more each side.
const YARD_SIDE_CELLS: int = 2
## A yard's sides slope 2 m a metre past its first cell (demo_build_mound_field.gd), so the hill there stands below the
## wall's top (4 m) for two cells beside the yard, and below a window's height (3.5 m) and in the garden's reach for
## three.
const YARD_KEEP_CELLS: int = 2
const YARD_WINDOW_CELLS: int = 3
const DOOR_EDGES: int = 2
const SIDES: int = 4
const SIDE_STEPS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const KIND_DOOR: int = 0
const KIND_WINDOW: int = 1
const KIND_NAMES: Array[String] = ["Front door", "Window"]
## P-2001-8 (a), "Our own, oak default": oak first; green, red and blue stay as choices.
const COLOUR_OAK: int = 0
const COLOUR_NAMES: Array[String] = ["Oak", "Green", "Red", "Blue"]

## The ruled words (SET-BUILD-001 §12), each the reason a validity line carries after its glyph and word.
## BUILD-MOUND-028 (X).
const TEXT_SURFACE_ONLY: String = "Mound rooms are painted on the Surface"
## BUILD-MOUND-002 (X).
const TEXT_NO_JOIN: String = "a Mound room cannot join a built room; leave a cell between them"
## BUILD-MOUND-008 (X): "the hill would cover " + thing.
const FORMAT_HILL_COVERS: String = "the hill would cover %s"
## BUILD-MOUND-012 (!).
const TEXT_NO_DOOR: String = "No way in: place a door on an outer edge"
## BUILD-MOUND-029 (X).
const TEXT_DOOR_PAIR: String = "A door needs two free outer edges side by side"
## BUILD-MOUND-030 (X).
const TEXT_OFF_OUTER: String = "doors and windows go on a room's outer edge"
## BUILD-MOUND-020 (X).
const TEXT_NO_HILL_FACE: String = "a window needs a mound or hill face beyond this wall"
## PROPOSALS (decision 2002), in the ruled rules' own manner:
## BUILD-MOUND-026 has no words: a way down on the berm or the cover (X).
const TEXT_ON_HILL: String = "nothing is dug into or built on a Mound's hill"
## A way down across a room's edge onto the hill (X).
const TEXT_SPLIT_WAY: String = "a way down stands wholly on one room's floor or off the hill"
## BUILD-MOUND-018's removal review stands in as a refusal until slice F's review (X).
const FORMAT_COVERS_EDGE_ITEM: String = "this would cover the %s on a room's outer edge; remove it first"
## A door whose yard a room stands in would open that room's wall to the air (X).
const TEXT_YARD_BLOCKED: String = "a room stands in or beside this door's yard; the yard must be clear ground"
## A room stroke into or beside a door's yard (X).
const TEXT_IN_YARD: String = "a door's yard and the ground beside it stay clear of rooms"
## A window facing into or beside a door's yard: it lies on the turf slope, cut away there (X).
const TEXT_WINDOW_YARD: String = "a window lies on the turf slope, never in or beside a door's yard"
## BUILD-MOUND-021's words over a way down on a Mound room's floor.
const TEXT_HATCH: String = "Way down, connects to Underground level 1"
## An edge already holding a door or window (X).
const FORMAT_EDGE_TAKEN: String = "this edge already holds a %s; click it to remove it"
## The surface the batch refuses Built rooms on, until slice G (!).
const LATER_BUILT_SURFACE: String = "built rooms on the surface come in a later update; choose the Mound style"


static func valid_style(style: int) -> bool:
	"""Whether `style` is Built or Mound."""
	return style >= 0 and style < STYLE_COUNT


static func step_of(side: int) -> Vector2i:
	"""The cell step out through `side` (0 north ... 3 west)."""
	return SIDE_STEPS[posmod(side, SIDES)]


static func along(side: int) -> Vector2i:
	"""The step along an edge on `side`: east for a north or south edge, south for an east or west one."""
	return Vector2i(1, 0) if posmod(side, 2) == 0 else Vector2i(0, 1)


static func cell_of(edge: Vector3i) -> Vector2i:
	"""The room cell an edge belongs to."""
	return Vector2i(edge.x, edge.y)


static func outside_of(edge: Vector3i) -> Vector2i:
	"""The cell beyond an edge."""
	return cell_of(edge) + step_of(edge.z)


static func is_outer(edge: Vector3i, is_room: Callable) -> bool:
	"""Whether `edge` is an outer edge: its cell is a Mound room's and the cell beyond it is in no room."""
	return bool(is_room.call(cell_of(edge))) and not bool(is_room.call(outside_of(edge)))


static func edges_of(kind: int, cell: Vector2i, side: int) -> Array[Vector3i]:
	"""A door's two edges or a window's one, from `cell` on `side` (a door runs along the side, see the header)."""
	var out: Array[Vector3i] = [Vector3i(cell.x, cell.y, posmod(side, SIDES))]
	if kind == KIND_DOOR:
		var next: Vector2i = cell + along(side)
		out.append(Vector3i(next.x, next.y, posmod(side, SIDES)))
	return out


static func same_edge(a: Vector3i, b: Vector3i) -> bool:
	"""Whether two edges are one line between two cells (named from either side)."""
	if a == b:
		return true
	var beyond: Vector2i = outside_of(a)
	return Vector3i(beyond.x, beyond.y, posmod(a.z + 2, SIDES)) == b


static func yard_cells(cell: Vector2i, side: int) -> PackedInt32Array:
	"""A door's yard (see the header): YARD_SIDE_CELLS each side of its two cells, out BERM_CELLS cells; pairs."""
	return yard_zone(cell, side, 0, 0)


static func yard_keep(cell: Vector2i, side: int) -> PackedInt32Array:
	"""Where no room may stand round a door's yard (see the header): the yard, YARD_KEEP_CELLS either side, and a cell
	beyond its foot; pairs."""
	return yard_zone(cell, side, YARD_KEEP_CELLS, 1)


static func yard_window_zone(cell: Vector2i, side: int) -> PackedInt32Array:
	"""Where no window may look out round a door's yard (see the header): the yard and YARD_WINDOW_CELLS either side;
	pairs."""
	return yard_zone(cell, side, YARD_WINDOW_CELLS, 0)


static func yard_zone(cell: Vector2i, side: int, beside: int, beyond: int) -> PackedInt32Array:
	"""A door's yard widened by `beside` cells each side and `beyond` cells past its foot; pairs, row by row out."""
	var out: PackedInt32Array = PackedInt32Array()
	var tangent: Vector2i = along(side)
	var outward: Vector2i = step_of(side)
	for out_step: int in range(1, BERM_CELLS + beyond + 1):
		for t: int in range(-YARD_SIDE_CELLS - beside, DOOR_EDGES + YARD_SIDE_CELLS + beside):
			var at: Vector2i = cell + tangent * t + outward * out_step
			out.append(at.x)
			out.append(at.y)
	return out


static func covered(gap: Vector2i) -> bool:
	"""Whether a cell `gap` whole cells away each way from a room cell (0: touching or the same) is under the heap."""
	return gap.x * gap.x + gap.y * gap.y < BERM_CELLS * BERM_CELLS


static func gap_between(a: Vector2i, b: Vector2i) -> Vector2i:
	"""The whole cells between two cells' squares, each way (0 when they touch or are one)."""
	return Vector2i(maxi(absi(a.x - b.x) - 1, 0), maxi(absi(a.y - b.y) - 1, 0))


static func footprint_into(rooms: PackedInt32Array, out: Dictionary) -> void:
	"""The heap's footprint (see the header) over the Mound room cells `rooms` (pairs): every covered cell that is no
	room cell, as keys of `out` (cleared first; value true)."""
	out.clear()
	var lookup: Dictionary = set_of(rooms)
	for at: int in range(0, rooms.size(), 2):
		var room: Vector2i = Vector2i(rooms[at], rooms[at + 1])
		for dz: int in range(-BERM_CELLS, BERM_CELLS + 1):
			for dx: int in range(-BERM_CELLS, BERM_CELLS + 1):
				var cell: Vector2i = room + Vector2i(dx, dz)
				if not lookup.has(cell) and not out.has(cell) and covered(gap_between(room, cell)):
					out[cell] = true


static func set_of(cells: PackedInt32Array) -> Dictionary:
	"""`cells` (pairs) as a lookup: Vector2i -> true."""
	var out: Dictionary = {}
	for at: int in range(0, cells.size(), 2):
		out[Vector2i(cells[at], cells[at + 1])] = true
	return out


static func components(cells: PackedInt32Array) -> Array[PackedInt32Array]:
	"""The 4-connected groups of `cells` (pairs), each a Mound's rooms under one hill reached through one another, in
	the order of their first cells."""
	var lookup: Dictionary = set_of(cells)
	var seen: Dictionary = {}
	var out: Array[PackedInt32Array] = []
	for at: int in range(0, cells.size(), 2):
		var start: Vector2i = Vector2i(cells[at], cells[at + 1])
		if not seen.has(start):
			out.append(_flood(start, lookup, seen))
	return out


static func _flood(start: Vector2i, lookup: Dictionary, seen: Dictionary) -> PackedInt32Array:
	"""The cells of `lookup` 4-connected to `start` (each marked in `seen`), pairs."""
	var group: PackedInt32Array = PackedInt32Array()
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		group.append(cell.x)
		group.append(cell.y)
		for step: Vector2i in SIDE_STEPS:
			var next: Vector2i = cell + step
			if lookup.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return group


static func outer_edges_into(cells: PackedInt32Array, is_room: Callable, out: Array[Vector3i]) -> void:
	"""Every outer edge of the Mound room cells `cells` (pairs), cell by cell north, east, south, west, into `out`
	(cleared first)."""
	out.clear()
	for at: int in range(0, cells.size(), 2):
		for side: int in SIDES:
			var edge: Vector3i = Vector3i(cells[at], cells[at + 1], side)
			if is_outer(edge, is_room):
				out.append(edge)


static func yard_clear(cell: Vector2i, side: int, is_room: Callable) -> bool:
	"""Whether a door's yard keep holds no room cell (a room there would open its wall onto the yard)."""
	var yard: PackedInt32Array = yard_keep(cell, side)
	for at: int in range(0, yard.size(), 2):
		if bool(is_room.call(Vector2i(yard[at], yard[at + 1]))):
			return false
	return true


static func kind_name(kind: int) -> String:
	"""A door's or window's name ("Front door", "Window"; "" for neither)."""
	return KIND_NAMES[kind] if kind >= 0 and kind < KIND_NAMES.size() else ""


static func colour_name(colour: int) -> String:
	"""A door colour's name ("Oak" ...; oak for an unknown one)."""
	return COLOUR_NAMES[colour] if colour >= 0 and colour < COLOUR_NAMES.size() else COLOUR_NAMES[COLOUR_OAK]


static func hill_covers(thing: String) -> String:
	"""BUILD-MOUND-008's words: "the hill would cover water"."""
	return FORMAT_HILL_COVERS % thing


static func covers_edge_item(kind: int) -> String:
	"""The stand-in for BUILD-MOUND-018's removal review (a PROPOSAL)."""
	return FORMAT_COVERS_EDGE_ITEM % kind_name(kind)


static func edge_taken(kind: int) -> String:
	"""An edge already holding a door or window (a PROPOSAL)."""
	return FORMAT_EDGE_TAKEN % kind_name(kind).to_lower()
