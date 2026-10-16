extends RefCounted
## THE PENDING DOORS AND WINDOWS OF MOUND ROOMS in the build panel's batch (decision 2002; BUILD-MOUND-010, -013,
## -018, -020, -029, -030). A row is one door (two outer edges) or window (one) placed by the player on a Mound room's
## outer edge (build_mound.gd), with the door's colour (oak by default, P-2001-8 (a)); or a REMOVAL of a confirmed one,
## named by its first edge, which Confirm all carries out. Presentation-side and never saved, like the rest of the
## batch: packed columns, one row per placement, `live` cleared by Undo and set by Redo.
##
## WHERE ONE MAY STAND (`judge`, every refusal "X Not possible" in words):
##   off the Surface      a window has no hill face beyond any underground wall (BUILD-MOUND-020); a front door is
##                        a Mound room's (BUILD-MOUND-030)
##   off an outer edge    "doors and windows go on a room's outer edge" (BUILD-MOUND-030)
##   a door's second edge not outer, or not free: "A door needs two free outer edges side by side" (BUILD-MOUND-029)
##   an edge taken        another door or window, pending or confirmed, on it (a PROPOSAL)
##   a door's yard        a room in or beside it would open that room's wall (`yard_keep`); and no window looks out
##                        in or beside a yard, nor a door's yard takes a window's slope (`yard_window_zone`; a window
##                        lies on the turf slope: both PROPOSALS)
##   no hill face         a window with another room within the berm beyond it (the hill never falls there)
## THE HOST'S READERS (`bind_host`): `rooms(level, cell) -> bool`, whether a cell is a Mound room's, pending or
## confirmed; `confirmed(level, edge) -> Vector4i`, the confirmed door or window on an edge as (kind, x, z, side) of
## its first edge, kind -1 for none; `listed(kind) -> Array`, the first edges (Vector3i) of every confirmed door or
## window of `kind`.

const Mound := preload("res://scripts/ui/build_mound.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")

const NONE: Vector4i = Vector4i(-1, 0, 0, 0)

var _levels: PackedInt32Array = PackedInt32Array()
var _xs: PackedInt32Array = PackedInt32Array()
var _zs: PackedInt32Array = PackedInt32Array()
var _sides: PackedByteArray = PackedByteArray()
var _kinds: PackedByteArray = PackedByteArray()
var _colours: PackedByteArray = PackedByteArray()
var _removals: PackedByteArray = PackedByteArray()
var _live: PackedByteArray = PackedByteArray()
var _rooms: Callable = Callable()
var _confirmed: Callable = Callable()
var _listed: Callable = Callable()


func bind_host(rooms: Callable, confirmed: Callable, listed: Callable = Callable()) -> void:
	"""The host's readers (see THE HOST'S READERS)."""
	_rooms = rooms
	_confirmed = confirmed
	_listed = listed


func add(level: int, cell: Vector2i, side: int, kind: int, colour: int, removal: bool) -> int:
	"""A live row; its index."""
	_levels.append(level)
	_xs.append(cell.x)
	_zs.append(cell.y)
	_sides.append(posmod(side, Mound.SIDES))
	_kinds.append(kind)
	_colours.append(colour)
	_removals.append(1 if removal else 0)
	_live.append(1)
	return _levels.size() - 1


func set_live(row: int, live: bool) -> void:
	"""Row `row` pending (Redo) or not (Undo, taken back, or ordered)."""
	_live[row] = 1 if live else 0


func is_live(row: int) -> bool:
	"""Whether row `row` is pending."""
	return row >= 0 and row < _live.size() and _live[row] == 1


func count() -> int:
	"""Rows, live or not."""
	return _levels.size()


func live_count() -> int:
	"""Pending rows."""
	return _live.count(1)


func level_of(row: int) -> int:
	"""The level row `row` is on."""
	return _levels[row]


func cell_of(row: int) -> Vector2i:
	"""Row `row`'s first cell."""
	return Vector2i(_xs[row], _zs[row])


func side_of(row: int) -> int:
	"""Row `row`'s side (0 north ... 3 west)."""
	return _sides[row]


func kind_of(row: int) -> int:
	"""Row `row`'s kind (build_mound.gd KIND_*)."""
	return _kinds[row]


func colour_of(row: int) -> int:
	"""Row `row`'s door colour (build_mound.gd COLOUR_*)."""
	return _colours[row]


func is_removal(row: int) -> bool:
	"""Whether row `row` takes a confirmed door or window away."""
	return _removals[row] == 1


func edges_of(row: int) -> Array[Vector3i]:
	"""Row `row`'s edges."""
	return Mound.edges_of(_kinds[row], cell_of(row), _sides[row])


func clear() -> void:
	"""Every row dropped (Discard all)."""
	_levels.clear()
	_xs.clear()
	_zs.clear()
	_sides.clear()
	_kinds.clear()
	_colours.clear()
	_removals.clear()
	_live.clear()


func row_at(level: int, edge: Vector3i, removals: bool) -> int:
	"""The live row on `level` with `edge` among its edges -- a placement, or with `removals` a removal -- or -1."""
	for row: int in _levels.size():
		if _live[row] == 0 or _levels[row] != level or is_removal(row) != removals:
			continue
		for own: Vector3i in edges_of(row):
			if Mound.same_edge(own, edge):
				return row
	return -1


func confirmed_at(level: int, edge: Vector3i) -> Vector4i:
	"""The confirmed door or window on `edge` that no pending row removes: (kind, x, z, side), or NONE."""
	var found: Vector4i = Vector4i(_confirmed.call(level, edge)) if _confirmed.is_valid() else NONE
	if found.x < 0:
		return NONE
	return NONE if row_at(level, Vector3i(found.y, found.z, found.w), true) >= 0 else found


# --- judging ---------------------------------------------------------------------------------------------------------

func judge(level: int, cell: Vector2i, side: int, kind: int, own_row: int) -> Array:
	"""[kind, reason] for a door or window (`own_row`: its own pending row, -1 for a new one; see WHERE ONE MAY
	STAND)."""
	if kind != Mound.KIND_DOOR and kind != Mound.KIND_WINDOW:
		return [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_OFF_OUTER]
	if level != Mound.SURFACE:
		return [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_NO_HILL_FACE if kind == Mound.KIND_WINDOW else Mound.TEXT_OFF_OUTER]
	var edges: Array[Vector3i] = Mound.edges_of(kind, cell, side)
	for at: int in edges.size():
		var refusal: String = _edge_refusal(level, edges[at], own_row)
		if not refusal.is_empty():
			return [Validity.KIND_NOT_POSSIBLE, refusal if at == 0 else Mound.TEXT_DOOR_PAIR]
	if kind == Mound.KIND_DOOR and not Mound.yard_clear(cell, side, _room_reader(level)):
		return [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_YARD_BLOCKED]
	if _yard_meets_window(level, cell, side, kind, own_row):
		return [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_WINDOW_YARD]
	if kind == Mound.KIND_WINDOW and _room_close_beyond(level, Vector3i(cell.x, cell.y, side)):
		return [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_NO_HILL_FACE]
	return [Validity.KIND_CAN_BUILD, ""]


func _room_close_beyond(level: int, edge: Vector3i) -> bool:
	"""Whether another room stands within the berm beyond `edge` (a gap too narrow for the hill to fall to a window's
	height: BUILD-MOUND-020, the hill there has no face)."""
	for far: int in range(1, Mound.BERM_CELLS):
		if _is_room(Mound.outside_of(edge) + Mound.step_of(edge.z) * far, level):
			return true
	return false


func _yard_meets_window(level: int, cell: Vector2i, side: int, kind: int, own_row: int) -> bool:
	"""Whether a window would look out in or beside a door's yard (`yard_window_zone`): this window by any door's, or
	any window by this door's."""
	var yards: Dictionary = {}
	var faces: Array[Vector2i] = []
	for first: Vector3i in placed(level, Mound.KIND_DOOR, own_row):
		yards.merge(Mound.set_of(Mound.yard_window_zone(Mound.cell_of(first), first.z)))
	for first: Vector3i in placed(level, Mound.KIND_WINDOW, own_row):
		faces.append(Mound.outside_of(first))
	if kind == Mound.KIND_WINDOW:
		return yards.has(Mound.outside_of(Vector3i(cell.x, cell.y, side)))
	var mine: Dictionary = Mound.set_of(Mound.yard_window_zone(cell, side))
	for face: Vector2i in faces:
		if mine.has(face):
			return true
	return false


func placed(level: int, kind: int, own_row: int) -> Array[Vector3i]:
	"""The first edges of every `kind` on `level` that will stand: pending placements (not `own_row`) and the host's
	confirmed ones no pending removal takes."""
	var out: Array[Vector3i] = []
	for row: int in _levels.size():
		if row != own_row and _live[row] == 1 and not is_removal(row) and _kinds[row] == kind and _levels[row] == level:
			out.append(Vector3i(_xs[row], _zs[row], _sides[row]))
	var listed: Array = _listed.call(kind) if _listed.is_valid() and level == Mound.SURFACE else []
	for first: Vector3i in listed:
		if not removed(level, first):
			out.append(first)
	return out


func _edge_refusal(level: int, edge: Vector3i, own_row: int) -> String:
	"""Why a door or window cannot take `edge` ("" when it can): not an outer edge, or taken."""
	if not Mound.is_outer(edge, _room_reader(level)):
		return Mound.TEXT_OFF_OUTER
	var other: int = row_at(level, edge, false)
	if other >= 0 and other != own_row:
		return Mound.edge_taken(_kinds[other])
	var there: Vector4i = confirmed_at(level, edge)
	return Mound.edge_taken(there.x) if there.x >= 0 else ""


func _room_reader(level: int) -> Callable:
	"""`is_room(cell) -> bool` on `level`, through the host."""
	return _is_room.bind(level)


func _is_room(cell: Vector2i, level: int) -> bool:
	"""Whether `cell` on `level` is a Mound room's (false with no host)."""
	return _rooms.is_valid() and bool(_rooms.call(level, cell))


func row_judgement(row: int) -> Array:
	"""[kind, reason] for pending row `row` where it stands now (a removal: ✓ while its door or window stands)."""
	if is_removal(row):
		var there: Vector4i = Vector4i(_confirmed.call(_levels[row], edges_of(row)[0])) if _confirmed.is_valid() else NONE
		return [Validity.KIND_CAN_BUILD, ""] if there.x >= 0 else [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_OFF_OUTER]
	return judge(_levels[row], cell_of(row), _sides[row], _kinds[row], row)


func doors_into(level: int, out: PackedInt32Array) -> void:
	"""The first cells of every pending door on `level` that can be built (pairs), into `out` (cleared first): the
	ways in a Mound's rooms will have (BUILD-MOUND-012)."""
	out.clear()
	for row: int in _levels.size():
		if _live[row] == 1 and not is_removal(row) and _kinds[row] == Mound.KIND_DOOR and _levels[row] == level \
				and int(row_judgement(row)[0]) == Validity.KIND_CAN_BUILD:
			out.append(_xs[row])
			out.append(_zs[row])


func removed(level: int, edge: Vector3i) -> bool:
	"""Whether a pending removal takes away the confirmed door or window whose first edge is `edge`."""
	return row_at(level, edge, true) >= 0
