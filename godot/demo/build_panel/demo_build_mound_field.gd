extends RefCounted
## THE HILL'S SHAPE (decision 2002; BUILD-MOUND-003, -004, -005, -011, -014, -015; P-2001-4 (a), P-2001-5 (a),
## P-2001-6 (a)). Presentation heights in metres over the Surface's unchanged ground (y = 0: the hill is drawn, not
## ground, until MOUND-TERRAIN), from the HEAPED Mound room cells and the yards cut before their doors:
##   OVER A ROOM    the wall's top (ROOM_TOP_M, DEC-054's 4096 u) and the ruled 1 m cover (COVER_M), plus the approved
##                  look's crown, rising CROWN_M more over the CROWN_REACH_M inside the outer walls, with a fixed
##                  wobble on the crown only (so the cover is never thinner than the rule);
##   BEYOND A WALL  the berm, rolling straight down: level for SHOULDER_M, then a smoothstep to the ground BERM_M out
##                  (P-2001-4 (a)'s 3 cells). So every room sits at the hill's edge (W13), the first cell outside a wall
##                  stands above the wall's top (P-2001-4: a wall is never open), and no earth lies beyond the berm;
##   IN A YARD      the ground, the yard's cells exactly; its sides, past the first cell out, sloped down to it at
##                  YARD_SLOPE (the first cell's cheeks stand behind the door's built front). Behind the front, across
##                  the yard's width, the turf is carried down over the eave (BUILD-MOUND-011): within EAVE_BACK_M of the
##                  front the hill falls to the eave's curve, EAVE_SLOPE a metre -- the one place the drawn cover is
##                  thinner than the rule's metre, for the built front's look (a PROPOSAL, decision 2002).
## Distances are exact to the union of the cells' squares (decision 1914 E1: a field over cells, never a smooth-min of
## room boxes, which ripples). Points are in world metres; cell (0, 0) starts at `datum_m`. A window lies where the
## slope outside its edge is at the middle of the wall's top metre (`window_spot`). Nothing here decides an outcome.

const Mound := preload("res://scripts/ui/build_mound.gd")

const UNITS_PER_M: float = 1024.0
const ROOM_TOP_M: float = Mound.ROOM_HEIGHT_U / UNITS_PER_M
const COVER_M: float = Mound.COVER_U / UNITS_PER_M
## The approved mockup's crown and wobble (decision 2001 §5: presentation, not a rule).
const CROWN_M: float = 1.0
const CROWN_REACH_M: float = 3.5
const WOBBLE_M: float = 0.12
const BERM_M: float = float(Mound.BERM_CELLS)
## How far the berm stays level before it rolls down (so the first cell out stands above the wall's top).
const SHOULDER_M: float = 0.35
## Where a window lies: the middle of the wall's top metre (P-2001-6 (a), "Wall's top metre").
const WINDOW_HEIGHT_M: float = ROOM_TOP_M - 0.5
## The rise a metre of a yard's sides past its first cell.
const YARD_SLOPE: float = 2.0
## The door's built front (demo_build_mound_front.gd): the plastered face's height, its eave's half-width and rise, the
## turf over it; how far behind the front the hill comes down to it, and how steeply it rises from it.
const FACE_HIGH_M: float = 2.9
const EAVE_R_M: float = 3.2
const EAVE_FLAT: float = 0.34
const EAVE_TURF_M: float = 0.35
const EAVE_BACK_M: float = 1.2
const EAVE_SLOPE: float = 1.6
## How far (cells) a distance is searched: past the berm, nothing is near.
const REACH: int = Mound.BERM_CELLS + 1
## The march outward from an edge looking for a window's place (m).
const WINDOW_STEP_M: float = 0.01
const NORMAL_STEP_M: float = 0.1
const NONE: Vector2i = Vector2i(-1048576, -1048576)
## A cell's neighbours' offsets each way (and itself).
const AROUND: Array[int] = [-1, 0, 1]

var datum_m: Vector2 = Vector2.ZERO
var _origin: Vector2i = Vector2i.ZERO
var _size: Vector2i = Vector2i.ZERO
var _rooms: PackedByteArray = PackedByteArray()
var _yards: PackedByteArray = PackedByteArray()
var _doors: Array[Vector3i] = []
## Per cell of the box: how many rings out (Chebyshev) the nearest room cell is, and the nearest cell that is no room
## (REACH + 1: further), so a search starts where its cells begin; and the cell the last room search found.
var _ring_room: PackedByteArray = PackedByteArray()
var _ring_out: PackedByteArray = PackedByteArray()
var _found: Vector2i = NONE


func setup(rooms: PackedInt32Array, doors: Array[Vector3i], datum: Vector2) -> void:
	"""Hold the heaped room cells `rooms` (pairs) and the doors whose yards are cut (their first edges), cells from
	`datum` (m)."""
	datum_m = datum
	_doors = doors.duplicate()
	var held: Rect2i = Rect2i()
	for at: int in range(0, rooms.size(), 2):
		var cell: Vector2i = Vector2i(rooms[at], rooms[at + 1])
		held = Rect2i(cell, Vector2i.ONE) if held.size == Vector2i.ZERO else held.expand(cell).expand(cell + Vector2i.ONE)
	held = held.grow(REACH)
	_origin = held.position
	_size = held.size
	_rooms.resize(_size.x * _size.y)
	_rooms.fill(0)
	_yards.resize(_size.x * _size.y)
	_yards.fill(0)
	for at: int in range(0, rooms.size(), 2):
		_mark(_rooms, Vector2i(rooms[at], rooms[at + 1]))
	for door: Vector3i in _doors:
		var yard: PackedInt32Array = Mound.yard_cells(Mound.cell_of(door), door.z)
		for at: int in range(0, yard.size(), 2):
			_mark(_yards, Vector2i(yard[at], yard[at + 1]))
	_ring_room = _rings(true)
	_ring_out = _rings(false)


func _rings(rooms: bool) -> PackedByteArray:
	"""Per cell, the Chebyshev rings out to the nearest room cell (`rooms`) or cell that is no room, capped at
	REACH + 1 (the box's own edge counts as no room beyond it)."""
	var out: PackedByteArray = PackedByteArray()
	out.resize(_size.x * _size.y)
	out.fill(REACH + 1)
	for at: int in out.size():
		if (_rooms[at] == 1) == rooms:
			out[at] = 0
	for ring: int in range(1, REACH + 1):
		for at: int in out.size():
			if out[at] > ring and _touches(out, at, ring - 1, rooms):
				out[at] = ring
	return out


func _touches(rings: PackedByteArray, at: int, ring: int, rooms: bool) -> bool:
	"""Whether a neighbour of cell index `at` (eight ways) is at `ring` (off the box: no room, at 0)."""
	@warning_ignore("integer_division") var z: int = at / _size.x
	var x: int = at - z * _size.x
	for dz: int in AROUND:
		for dx: int in AROUND:
			var nx: int = x + dx
			var nz: int = z + dz
			var off: bool = nx < 0 or nz < 0 or nx >= _size.x or nz >= _size.y
			if (off and not rooms and ring == 0) or (not off and rings[nz * _size.x + nx] == ring):
				return true
	return false


func _mark(column: PackedByteArray, cell: Vector2i) -> void:
	"""`cell` set in `column` (nothing off the box)."""
	var index: int = _index(cell)
	if index >= 0:
		column[index] = 1


func _index(cell: Vector2i) -> int:
	"""`cell`'s index in the box, or -1."""
	var local: Vector2i = cell - _origin
	if local.x < 0 or local.y < 0 or local.x >= _size.x or local.y >= _size.y:
		return -1
	return local.y * _size.x + local.x


func is_room(cell: Vector2i) -> bool:
	"""Whether `cell` is a heaped Mound room cell."""
	var index: int = _index(cell)
	return index >= 0 and _rooms[index] == 1


func is_yard(cell: Vector2i) -> bool:
	"""Whether `cell` lies in a cut yard (never a room cell)."""
	var index: int = _index(cell)
	return index >= 0 and _yards[index] == 1 and _rooms[index] == 0


func box() -> Rect2i:
	"""The cells held: every cell the hill can rise over."""
	return Rect2i(_origin, _size)


static func to_square(q: Vector2, cell: Vector2i) -> float:
	"""The distance from `q` (cell space) to `cell`'s closed square (0 inside it)."""
	var dx: float = maxf(maxf(cell.x - q.x, q.x - (cell.x + 1.0)), 0.0)
	var dz: float = maxf(maxf(cell.y - q.y, q.y - (cell.y + 1.0)), 0.0)
	return sqrt(dx * dx + dz * dz)


func _nearest(q: Vector2, rooms: bool) -> float:
	"""The distance from `q` (cell space) to the nearest room cell (`rooms`) or non-room cell, searched ring by ring
	from the first ring holding one out to REACH; INF beyond. A room search keeps the cell it found (`_found`)."""
	var home: Vector2i = Vector2i(floori(q.x), floori(q.y))
	var index: int = _index(home)
	var first: int = (_ring_room[index] if rooms else _ring_out[index]) if index >= 0 else (REACH + 1 if rooms else 0)
	if rooms:
		_found = home if first == 0 else NONE
	if first == 0:
		return 0.0
	var best: float = INF
	for ring: int in range(maxi(first, 1), REACH + 1):
		if float(ring - 1) >= best:
			break
		best = _ring_best(q, home, ring, rooms, best)
	return best


func _ring_best(q: Vector2, home: Vector2i, ring: int, rooms: bool, best: float) -> float:
	"""The nearest of `best` and the distances from `q` to ring `ring`'s room (or non-room) cells round `home`."""
	for k: int in 8 * ring:
		var cell: Vector2i = home + ring_cell(ring, k)
		if is_room(cell) == rooms:
			var d: float = to_square(q, cell)
			if d < best:
				best = d
				if rooms:
					_found = cell
	return best


static func ring_cell(ring: int, k: int) -> Vector2i:
	"""The `k`th of the 8 × `ring` cells on Chebyshev ring `ring` round (0, 0), going round from its north-west
	corner east, south, west and north."""
	var side: int = 2 * ring
	@warning_ignore("integer_division") var edge: int = k / side
	var along_edge: int = k - edge * side
	match edge:
		0:
			return Vector2i(-ring + along_edge, -ring)
		1:
			return Vector2i(ring, -ring + along_edge)
		2:
			return Vector2i(ring - along_edge, ring)
	return Vector2i(-ring, ring - along_edge)


func nearest_cell(point: Vector2) -> Vector2i:
	"""The heaped room cell nearest `point` (world m; its own cell when it is one), or NONE past the search."""
	_nearest(point - datum_m, true)
	return _found


func found_cell() -> Vector2i:
	"""The room cell the last height or room distance found nearest (NONE past the search): read straight after
	`height_m` to colour a point without searching again."""
	return _found


func room_distance(point: Vector2) -> float:
	"""How far `point` (world m) is from the nearest heaped room cell (0 on one; INF past the search)."""
	return _nearest(point - datum_m, true)


func inside_distance(point: Vector2) -> float:
	"""How far `point` (world m) on a room cell is from the nearest cell that is no room (0 off the rooms)."""
	return _nearest(point - datum_m, false)


static func berm(d: float) -> float:
	"""The berm's height as a share of the hill's at the walls, `d` metres out: 1 over the shoulder, a smoothstep down
	to 0 at BERM_M."""
	var t: float = clampf((d - SHOULDER_M) / (BERM_M - SHOULDER_M), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)


static func wobble(q: Vector2) -> float:
	"""The crown's fixed wobble at `q` (the mockup's, -WOBBLE_M to WOBBLE_M)."""
	return sin(q.x * 0.8 + 1.3) * cos(q.y * 0.7) * WOBBLE_M


func height_m(point: Vector2) -> float:
	"""The hill's height at `point` (world m) over the ground (see the header)."""
	var q: Vector2 = point - datum_m
	if is_yard(Vector2i(floori(q.x), floori(q.y))):
		_found = NONE
		return 0.0
	var d: float = _nearest(q, true)
	var h: float = 0.0
	if d <= 0.0:
		var s: float = smoothstep(0.0, CROWN_REACH_M, _nearest(q, false))
		h = ROOM_TOP_M + COVER_M + (CROWN_M + wobble(q)) * s
	elif d < BERM_M:
		h = (ROOM_TOP_M + COVER_M) * berm(d)
	return _yard_sides(q, h)


func _yard_sides(q: Vector2, h: float) -> float:
	"""`h` at `q` (cell space) held down beside each cut yard past its first cell (YARD_SLOPE a metre from its side),
	and behind its front down to the eave (see IN A YARD)."""
	for door: Vector3i in _doors:
		var corner: Vector2 = front_start(door)
		var out_m: float = (q - corner).dot(Vector2(Mound.step_of(door.z)))
		var along_m: float = (q - corner).dot(Vector2(Mound.along(door.z)))
		var lateral: float = maxf(-Mound.YARD_SIDE_CELLS - along_m, along_m - Mound.DOOR_EDGES - Mound.YARD_SIDE_CELLS)
		if out_m > 1.0 and out_m <= BERM_M + 1.0 and lateral >= 0.0:
			h = minf(h, YARD_SLOPE * lateral)
		elif out_m <= 0.0 and out_m > -EAVE_BACK_M and lateral < 0.0:
			h = minf(h, eave_top(along_m - Mound.DOOR_EDGES / 2.0) - out_m * EAVE_SLOPE)
	return h


func in_eave(point: Vector2) -> bool:
	"""Whether `point` (world m) lies behind a cut yard's front within EAVE_BACK_M, where the turf comes down over the
	eave (the drawn cover is thinner there: see IN A YARD)."""
	var q: Vector2 = point - datum_m
	for door: Vector3i in _doors:
		var corner: Vector2 = front_start(door)
		var out_m: float = (q - corner).dot(Vector2(Mound.step_of(door.z)))
		var along_m: float = (q - corner).dot(Vector2(Mound.along(door.z)))
		var inside: bool = along_m > -Mound.YARD_SIDE_CELLS and along_m < Mound.DOOR_EDGES + Mound.YARD_SIDE_CELLS
		if out_m <= 0.0 and out_m > -EAVE_BACK_M and inside:
			return true
	return false


static func eave_top(across: float) -> float:
	"""The turf's height on a door's eave `across` metres from the door's middle along the front (m)."""
	return FACE_HIGH_M + EAVE_FLAT * sqrt(maxf(EAVE_R_M * EAVE_R_M - across * across, 0.0)) + EAVE_TURF_M


static func front_start(door: Vector3i) -> Vector2:
	"""Where a door's front line starts (cell space): its first edge's end the door runs on from."""
	var cell: Vector2 = Vector2(Mound.cell_of(door))
	match posmod(door.z, Mound.SIDES):
		0:
			return cell
		1:
			return cell + Vector2(1.0, 0.0)
		2:
			return cell + Vector2(0.0, 1.0)
	return cell


static func edge_middle(edge: Vector3i) -> Vector2:
	"""The middle of an edge (cell space)."""
	return front_start(edge) + Vector2(Mound.along(edge.z)) * 0.5


func window_spot(edge: Vector3i) -> Dictionary:
	"""Where a window on `edge` lies: {point (world m, on the slope), normal (the slope's), out_m (how far out from the
	wall)}: the first point outward from the edge's middle where the hill has fallen to WINDOW_HEIGHT_M (P-2001-6 (a));
	{} when the hill never stands that high there."""
	var start: Vector2 = edge_middle(edge) + datum_m
	var outward: Vector2 = Vector2(Mound.step_of(edge.z))
	var out_m: float = 0.0
	while out_m <= BERM_M:
		var at: Vector2 = start + outward * out_m
		var h: float = height_m(at)
		if h <= WINDOW_HEIGHT_M:
			return {"point": Vector3(at.x, h, at.y), "normal": normal_at(at), "out_m": out_m} if out_m > 0.0 else {}
		out_m += WINDOW_STEP_M
	return {}


func normal_at(point: Vector2) -> Vector3:
	"""The hill's surface normal at `point` (world m), by central differences."""
	var e: float = NORMAL_STEP_M
	var dx: float = (height_m(point + Vector2(e, 0.0)) - height_m(point - Vector2(e, 0.0))) / (2.0 * e)
	var dz: float = (height_m(point + Vector2(0.0, e)) - height_m(point - Vector2(0.0, e))) / (2.0 * e)
	return Vector3(-dx, 1.0, -dz).normalized()
