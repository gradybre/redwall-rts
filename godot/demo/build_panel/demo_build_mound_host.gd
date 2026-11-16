extends Node
## THE BUILD PANEL'S MOUND HOMES IN THE DEMO (decision 2002, the proof of concept of decision 2001; Brendan's
## P-2001-11 (a): in the demo, free, drawn over unchanged ground, unsaved, like decision 1912's). demo_build.gd mounts
## this and hands it what it owns:
##   THE STORE     demo_build_mounds.gd: what Confirm all ordered and how far each Mound is built; read by the batch
##                 (`bind_mound_host`: its cells, doors, doors and windows on an edge) with the ways down (the works')
##                 and what a hill would cover (demo_build_mound_ground.gd, over the village's water and placements);
##   THE DRAWING   demo_build_mound_view.gd (whole, or cut away while the panel shows the Surface) and the edges'
##                 marks while a door or window is placed (demo_build_mound_marks.gd); scenery and ground cover under a
##                 risen hill are hidden as it rises;
##   THE BUILDER   one resident at a time (demo_build_mound_task.gd), sent when a Mound has work and none is at it,
##                 again every SEND_EVERY_S while work waits; why nobody went is said once;
##   THE WALKERS   from Confirm all on, every Mound stands as obstacle circles round its rooms and their first cells out
##                 (`hill_circles`; a door's yard left open), so residents walk round it and in only at a door.
## Picking an edge: the ground point under the pointer, the nearest side of its cell that is (or faces) a Mound room's
## outer edge; a door runs on from it along the wall, or back from it when that fits instead. Nothing is saved.

const Mound := preload("res://scripts/ui/build_mound.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const MoundEdges := preload("res://scripts/ui/build_mound_edges.gd")
const Furniture := preload("res://scripts/ui/build_furniture.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Jobs := preload("res://demo/build_panel/demo_build_mound_jobs.gd")
const View := preload("res://demo/build_panel/demo_build_mound_view.gd")
const Marks := preload("res://demo/build_panel/demo_build_mound_marks.gd")
const Ground := preload("res://demo/build_panel/demo_build_mound_ground.gd")
const Task := preload("res://demo/build_panel/demo_build_mound_task.gd")
const Front := preload("res://demo/build_panel/demo_build_mound_front.gd")
const Figure := preload("res://demo/build_panel/demo_build_figure.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")

const SEND_EVERY_S: float = 2.0
## The circles residents walk round: one every CIRCLE_STEP cells over a hill's rooms and first cells out, this wide.
const CIRCLE_STEP: int = 3
const CIRCLE_RADIUS_M: float = 2.1
const SENT: String = "%s goes to the Mound to build it"
const NOBODY: String = "Nobody can build the Mound: its work waits"
const PLACE_LINE: String = "Place %s, %s\n%s"
const NO_EDGE: Vector3i = Marks.NO_EDGE

var mounds: Mounds = Mounds.new()
var ground: Ground = Ground.new()
var view: View = null
var marks: Marks = null
## The builder's trip (null: none), its resident and its figure inside.
var worker: Task = null
var _actor: int = -1
var _figure: Figure = null
var _batch: Batch = null
var _works: Works = null
var _fittings: Fittings = null
var _datum_m: Vector2 = Vector2.ZERO
var _cast: Node = null
var _pick: Callable = Callable()
var _say: Callable = Callable()
var _is_day: Callable = Callable()
var _send_in: float = 0.0
var _said: String = ""
var _seen: int = -1
var _hidden_upto: Dictionary = {}
var _circles_key: Array = []
## The edge under the pointer while a door or window is armed (NO_EDGE: none), and its judgement.
var hover: Vector3i = NO_EDGE
var hover_kind: int = Validity.KIND_CAN_BUILD
var hover_words: String = ""


func configure(batch: Batch, works: Works, fittings: Fittings, bounds: Rect2i, datum_m: Vector2) -> void:
	"""Over the planning area `bounds` from `datum_m` (m): the store, its readers bound to the batch, the drawing."""
	name = "BuildMoundHost"
	_batch = batch
	_works = works
	_fittings = fittings
	_datum_m = datum_m
	mounds.configure(bounds)
	_seen = mounds.revision
	batch.bind_mound_host(mounds.all_cells, works.ways_on, ground.thing_at, mounds.doors, mounds.edge_at, mounds.listed)
	view = View.new()
	add_child(view)
	view.configure(mounds, works, fittings, datum_m)
	view.threaded = true
	marks = Marks.new()
	add_child(marks)
	marks.configure(batch, mounds, datum_m)
	_figure = Figure.new()
	add_child(_figure)


func bind_village(world: Object, water: Object, is_day: Callable) -> void:
	"""The village's placements and water (what a hill would cover, the scenery it hides) and its daylight."""
	ground.configure(world, water, _datum_m)
	_is_day = is_day
	_batch.host_changed()


func bind_cast(cast: Node, pick: Callable, say: Callable) -> void:
	"""The residents, `pick() -> int` choosing who builds (-1: nobody), and the notice line."""
	_cast = cast
	_pick = pick
	_say = say


func use_props(props: Object) -> void:
	"""The staged earth textures on the hill."""
	view.use_props(props)


# --- per frame -------------------------------------------------------------------------------------------------------

func tick(delta: float, surface_shown: bool, armed: int) -> void:
	"""Every frame: the batch told when the Mounds moved, scenery hidden under new hill, the drawing (cut away while
	the panel shows the Surface), the edges' marks, and every SEND_EVERY_S a builder sent when work waits and nobody is
	at it (the job search runs only then)."""
	if mounds.revision != _seen:
		_seen = mounds.revision
		_batch.host_changed()
		_hide_under_hills()
		_stand_hills()
	view.refresh(surface_shown, bool(_is_day.call()) if _is_day.is_valid() else true)
	_figure.visible = surface_shown and working() and worker.inside()
	marks.refresh(surface_shown, armed, hover if armed >= 0 else NO_EDGE, hover_kind, hover_words)
	_send_in -= delta
	if _send_in <= 0.0:
		_send_in = SEND_EVERY_S
		send_worker()


func _hide_under_hills() -> void:
	"""The scenery and ground cover under each heaped hill's cells, its berm and its yards, hidden once."""
	var heaped: PackedInt32Array = PackedInt32Array()
	mounds.cells_into(Mounds.HEAPED, heaped)
	var covered: Dictionary = {}
	Mound.footprint_into(heaped, covered)
	for cell: Vector2i in Mound.set_of(heaped):
		covered[cell] = true
	for cell: Vector2i in _hidden_upto:
		covered.erase(cell)
	if covered.is_empty():
		return
	ground.hide_covered(covered)
	_hidden_upto.merge(covered)


func _stand_hills() -> void:
	"""The hills as the residents' obstacles, rebuilt only when the Mound cells or the cut yards changed."""
	var key: Array = [mounds.all_cells(), mounds.yards()]
	if key == _circles_key or _cast == null or not _cast.has_method(&"space"):
		return
	_circles_key = key
	(_cast.call(&"space") as Object).call(&"set_build_mounds", hill_circles())


func hill_circles() -> PackedVector3Array:
	"""Circles (x, radius, z) over every confirmed Mound's rooms and the cells just outside them, a cut yard left
	out: one every CIRCLE_STEP cells of that ground, CIRCLE_RADIUS_M wide, and one more for any cell they leave
	uncovered."""
	var cells: PackedInt32Array = mounds.all_cells()
	var solid: Dictionary = Mound.set_of(cells)
	for at: int in range(0, cells.size(), 2):
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			solid[Vector2i(cells[at], cells[at + 1]) + step] = true
	for door: Vector3i in mounds.yards():
		var yard: PackedInt32Array = Mound.yard_cells(Mound.cell_of(door), door.z)
		for at: int in range(0, yard.size(), 2):
			solid.erase(Vector2i(yard[at], yard[at + 1]))
	var out: PackedVector3Array = PackedVector3Array()
	for cell: Vector2i in solid:
		if posmod(cell.x, CIRCLE_STEP) == 1 and posmod(cell.y, CIRCLE_STEP) == 1:
			out.append(_circle_at(cell))
	for cell: Vector2i in solid:
		if not _within(out, _circle_at(cell)):
			out.append(_circle_at(cell))
	return out


func _circle_at(cell: Vector2i) -> Vector3:
	"""A circle (x, radius, z) on `cell`'s middle."""
	return Vector3(_datum_m.x + cell.x + 0.5, CIRCLE_RADIUS_M, _datum_m.y + cell.y + 0.5)


static func _within(circles: PackedVector3Array, at: Vector3) -> bool:
	"""Whether `at`'s middle lies well inside one of `circles` (half a metre in)."""
	for circle: Vector3 in circles:
		if Vector2(circle.x, circle.z).distance_to(Vector2(at.x, at.z)) <= circle.y - 0.5:
			return true
	return false


func shown_tags(out: Array[Label3D]) -> void:
	"""Append the Mounds' shown words to `out`, in the order they give way: the builder's name, the edges' words, then
	each Mound's state (demo_build_tags.gd keeps them off each other)."""
	if _figure.visible:
		out.append(_figure.tag())
	marks.shown_tags(out)
	view.shown_tags(out)


# --- the builder -----------------------------------------------------------------------------------------------------

func working() -> bool:
	"""Whether a resident is on its Mound trip now."""
	return worker != null and _cast != null and _actor >= 0 \
		and (_cast.call(&"actor", _actor) as Node).get(&"brain").get(&"task") == worker


func works_with(i: int) -> bool:
	"""Whether resident `i` is the Mound's builder now."""
	return working() and _actor == i


func send_worker() -> bool:
	"""A resident to the Mound with work (see THE BUILDER); false, saying why once, when nobody can go."""
	if working() or _cast == null or Jobs.next_job(mounds, _fittings).is_empty():
		return false
	var who: int = int(_pick.call()) if _pick.is_valid() else -1
	if who < 0:
		_say_once(NOBODY)
		return false
	var name_words: String = String((_cast.call(&"actor", who) as Node).get(&"display_name"))
	worker = Task.new(mounds, _works, _fittings, _figure, _datum_m, name_words)
	_actor = who
	(_cast.call(&"actor", who) as Node).get(&"brain").call(&"order_task", worker)
	if not working():
		_say_once(NOBODY)
		return false
	_said = ""
	if _say.is_valid():
		_say.call(SENT % name_words)
	return true


func _say_once(words: String) -> void:
	"""Say `words` unless they were the last thing said about the builder."""
	if words != _said and _say.is_valid():
		_said = words
		_say.call(words)


# --- Confirm all's routes ---------------------------------------------------------------------------------------------

func submit_room(cells: PackedInt32Array, room_type: int) -> bool:
	"""A Mound room ordered: its cells wait for their heap (the works hold its type, not dug yet)."""
	if not mounds.order_cells(cells):
		return false
	return _works.order_room(Mound.SURFACE, cells, room_type)


func submit_edge(cell: Vector2i, side: int, kind: int, colour: int, removal: bool) -> Dictionary:
	"""A door, window or removal ordered (free for now)."""
	var ok: bool = mounds.remove_edge(Vector3i(cell.x, cell.y, side)) if removal \
		else mounds.order_edge(cell, side, kind, colour)
	return {"ok": ok, "error": Mound.TEXT_OFF_OUTER}


# --- picking and placing an edge ---------------------------------------------------------------------------------------

func edge_near(point: Vector2) -> Vector3i:
	"""The Mound room's outer edge nearest `point` (world x, z) among its cell's sides, or the sides of the rooms beside
	it facing it (NO_EDGE: none)."""
	var q: Vector2 = point - _datum_m
	var home: Vector2i = Vector2i(floori(q.x), floori(q.y))
	var f: Vector2 = q - Vector2(home)
	var to_side: PackedFloat32Array = PackedFloat32Array([f.y, 1.0 - f.x, 1.0 - f.y, f.x])
	var best: Vector3i = NO_EDGE
	var best_d: float = INF
	var own: bool = _batch.is_mound_room(Mound.SURFACE, home)
	for side: int in Mound.SIDES:
		var edge: Vector3i = Vector3i(home.x, home.y, side)
		if not own:
			var beside: Vector2i = home + Mound.step_of(side)
			edge = Vector3i(beside.x, beside.y, posmod(side + 2, Mound.SIDES))
		if Mound.is_outer(edge, _batch.is_surface_room) and to_side[side] < best_d:
			best_d = to_side[side]
			best = edge
	return best


func anchor_for(edge: Vector3i, kind: int, point: Vector2) -> Vector3i:
	"""Where a `kind` placed at `edge` starts: a window there; a door on it and the next along, or on the one before
	and it when that fits and the pointer is on its near half (or only that fits)."""
	if kind != Mound.KIND_DOOR:
		return edge
	var back: Vector3i = Vector3i(edge.x - Mound.along(edge.z).x, edge.y - Mound.along(edge.z).y, edge.z)
	var q: Vector2 = point - _datum_m - Vector2(Mound.cell_of(edge))
	var near_half: bool = (q.x if Mound.along(edge.z).x != 0 else q.y) < 0.5
	var ahead_ok: bool = _fits(edge, kind)
	var back_ok: bool = _fits(back, kind)
	return back if back_ok and (near_half or not ahead_ok) else edge


func _fits(edge: Vector3i, kind: int) -> bool:
	"""Whether `kind` could be placed from `edge` now."""
	var judged: Array = _batch.mound_edges().judge(Mound.SURFACE, Mound.cell_of(edge), edge.z, kind, -1)
	return int(judged[0]) == Validity.KIND_CAN_BUILD


func taken(level: int, edge: Vector3i) -> bool:
	"""Whether a door or window stands on `edge`, pending or built (a click there takes it away)."""
	var edges: MoundEdges = _batch.mound_edges()
	return edges.row_at(level, edge, false) >= 0 or edges.row_at(level, edge, true) >= 0 \
		or edges.confirmed_at(level, edge).x >= 0


func set_hover(level: int, edge: Vector3i, kind: int, colour: int, point: Vector2) -> void:
	"""The edge under the pointer and its judgement in words, for the marks and the label."""
	hover = edge
	if edge == NO_EDGE:
		hover_kind = Validity.KIND_CAN_BUILD
		hover_words = ""
		return
	if taken(level, edge):
		hover_kind = Validity.KIND_CAN_BUILD
		hover_words = "Click to remove it"
		return
	var anchor: Vector3i = anchor_for(edge, kind, point)
	var judged: Array = _batch.mound_edges().judge(level, Mound.cell_of(anchor), anchor.z, kind, -1)
	hover_kind = int(judged[0])
	var named: String = Mound.kind_name(kind) + (", %s" % Mound.colour_name(colour).to_lower() if kind == Mound.KIND_DOOR else "")
	hover_words = PLACE_LINE % [named, Furniture.SIDE_WORDS[anchor.z], Validity.line(hover_kind, String(judged[1]))]


func place(level: int, edge: Vector3i, kind: int, colour: int, point: Vector2) -> int:
	"""A click with a door or window armed on `edge`: taken away when one stands there, else placed (see
	`anchor_for`); returns the batch's kind (build_batch.gd `toggle_mound_edge`)."""
	if edge == NO_EDGE:
		return Validity.KIND_NOT_POSSIBLE
	var anchor: Vector3i = edge if taken(level, edge) else anchor_for(edge, kind, point)
	return _batch.toggle_mound_edge(level, Mound.cell_of(anchor), anchor.z, kind, colour)


# --- the way in to a hatch ---------------------------------------------------------------------------------------------

func hatch_ready(cell: Vector2i) -> bool:
	"""Whether a way down standing at `cell` on a Mound's floor can be reached: its cell dug, its Mound's door fitted
	(a way down off the Mounds always can)."""
	if mounds.stage_of(cell) == Mounds.NONE:
		return true
	var door: int = mounds.door_of(mounds.group_of(cell))
	return mounds.is_open(cell) and door >= 0 and mounds.edge_fitted(door)


func hatch_site(cell: Vector2i) -> Vector2:
	"""Where a resident walks to go down a way at `cell`: its Mound's door yard (INF off the Mounds: the way itself)."""
	if mounds.stage_of(cell) == Mounds.NONE:
		return Vector2.INF
	var door: int = mounds.door_of(mounds.group_of(cell))
	return Front.station_of(mounds.edges_of(door)[0], _datum_m) if door >= 0 else Vector2.INF
