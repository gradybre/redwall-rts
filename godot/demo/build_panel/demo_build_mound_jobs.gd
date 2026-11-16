extends RefCounted
## THE MOUND BUILDER'S NEXT JOB (decision 2002; demo_build_mounds.gd THE JOBS). Pure and static over the Mounds and
## the confirmed furniture. A job is a Dictionary:
##   kind   demo_build_mounds.gd JOB_*
##   group  the Mound it is on (its index in `groups`), door  the door row the builder works from
##   cell   the cell it changes (or the door or window's first cell), row  the door/window or furniture row (-1: none)
##   edge   for a door or window, its first edge: rows shift when one is removed, so it is found again by its edge
##   path   for a job done inside the hill, the open cells walked from the door's cell to where the builder stands
##          (Array[Vector2i]; empty for a job done from the yard)
## Heap and top are done from the door's yard (the hill is drawn over unchanged ground: nobody climbs it, P-2001-7
## (a)); dig, frame and furniture from inside, reached through the door.

const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")

## A guard on a search's length (cells), not a tuning.
const SEARCH_LIMIT: int = 65536
## No builder inside.
const NOWHERE: Vector2i = Vector2i(-1048576, -1048576)


static func next_job(mounds: Mounds, fittings: Fittings, from: Vector2i = NOWHERE) -> Dictionary:
	"""The first Mound's next job (see the header), or {} when none has work left and a door. A builder inside stands
	at `from` (NOWHERE: outside), and a job inside its Mound is searched from there, breadth first, as the proof of
	concept's mole searches from where it stands (decision 1912 E12); else from the door's cell."""
	var all: Array[PackedInt32Array] = mounds.groups()
	for group: int in all.size():
		var door: int = mounds.door_of(group)
		if door < 0:
			continue
		var start: Vector2i = from if from != NOWHERE and mounds.group_of(from) == group and mounds.is_open(from) \
			else mounds.edge_cell(door)
		var job: Dictionary = _job_in(mounds, fittings, group, door, start)
		if not job.is_empty():
			return job
	return {}


static func _job_in(mounds: Mounds, fittings: Fittings, group: int, door: int, start: Vector2i) -> Dictionary:
	"""Mound `group`'s next job, worked from door row `door`, a job inside searched from `start` ({} for none)."""
	var least: int = mounds.least_stage(group)
	if least < Mounds.TOPPED:
		return _stage_job(mounds, group, least, door, start)
	var row: int = _edge_waiting(mounds, group)
	if row >= 0:
		var job: Dictionary = _job(Mounds.JOB_FIT_EDGE, group, door, mounds.edge_cell(row), row, [])
		job["edge"] = mounds.edges_of(row)[0]
		return job
	return _piece_job(mounds, fittings, group, door, start)


static func _job(kind: int, group: int, door: int, cell: Vector2i, row: int, path: Array[Vector2i]) -> Dictionary:
	"""One job's Dictionary."""
	return {"kind": kind, "group": group, "door": door, "cell": cell, "row": row, "path": path}


static func _stage_job(mounds: Mounds, group: int, least: int, door: int, start: Vector2i) -> Dictionary:
	"""Taking the Mound's least-built cells one stage on: heap and top the nearest to the door from its yard; dig and
	frame from inside, breadth first through the dug cells from `start` -- a dug cell framed before the next is dug
	(P-2001-14 (a): each quantum is braced and cut, and its braces are drawn as the frame once the cell is open)."""
	var stage: int = least
	if least == Mounds.HEAPED and has_stage(mounds, group, Mounds.DUG):
		stage = Mounds.DUG
	var kind: int = stage - Mounds.ORDERED
	if not Mounds.JOB_INSIDE[kind]:
		var cell: Vector2i = nearest_at(mounds, group, least, mounds.edge_cell(door))
		return _job(kind, group, door, cell, -1, [])
	var found: Array[Vector2i] = walk_to_stage(mounds, start, stage)
	if found.is_empty():
		return {}
	var target: Vector2i = found.pop_back()
	return _job(kind, group, door, target, -1, found)


static func has_stage(mounds: Mounds, group: int, stage: int) -> bool:
	"""Whether a cell of Mound `group` stands at `stage`."""
	var cells: PackedInt32Array = mounds.groups()[group]
	for at: int in range(0, cells.size(), 2):
		if mounds.stage_of(Vector2i(cells[at], cells[at + 1])) == stage:
			return true
	return false


static func nearest_at(mounds: Mounds, group: int, stage: int, start: Vector2i) -> Vector2i:
	"""Mound `group`'s cell at `stage` nearest `start` (in whole cells each way; the first in row order on a tie)."""
	var cells: PackedInt32Array = mounds.groups()[group]
	var best: Vector2i = Vector2i(cells[0], cells[1])
	var best_d: int = -1
	for at: int in range(0, cells.size(), 2):
		var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
		var d: int = absi(cell.x - start.x) + absi(cell.y - start.y)
		if mounds.stage_of(cell) == stage and (best_d < 0 or d < best_d or (d == best_d and _before(cell, best))):
			best = cell
			best_d = d
	return best


static func _before(a: Vector2i, b: Vector2i) -> bool:
	"""Whether `a` comes before `b` in row order."""
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func walk_to_stage(mounds: Mounds, start: Vector2i, stage: int) -> Array[Vector2i]:
	"""Breadth first from `start` through open cells: the cells walked to stand beside (or on) the nearest cell at
	`stage`, then that cell last; `start` itself when it is at `stage`; empty when none can be reached."""
	if mounds.stage_of(start) == stage:
		return [start, start]
	var came: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size() and head < SEARCH_LIMIT:
		var at: Vector2i = queue[head]
		head += 1
		if not mounds.is_open(at):
			continue
		for step: Vector2i in Mound.SIDE_STEPS:
			var next: Vector2i = at + step
			if came.has(next) or mounds.stage_of(next) == Mounds.NONE:
				continue
			came[next] = at
			if mounds.stage_of(next) == stage:
				var path: Array[Vector2i] = _walk(came, at)
				path.append(next)
				return path
			queue.append(next)
	return []


static func _walk(came: Dictionary, end: Vector2i) -> Array[Vector2i]:
	"""The cells from the search's start to `end`, in walking order."""
	var out: Array[Vector2i] = []
	var at: Vector2i = end
	while true:
		out.push_front(at)
		var back: Vector2i = came[at]
		if back == at:
			break
		at = back
	return out


static func _edge_waiting(mounds: Mounds, group: int) -> int:
	"""The first door or window on Mound `group` waiting to be fitted, or -1."""
	for row: int in mounds.edge_count():
		if not mounds.edge_fitted(row) and mounds.group_of(mounds.edge_cell(row)) == group:
			return row
	return -1


static func _piece_job(mounds: Mounds, fittings: Fittings, group: int, door: int, start: Vector2i) -> Dictionary:
	"""Fitting the nearest piece of furniture waiting on Mound `group`'s floor, from inside ({} for none)."""
	var goals: Dictionary = {}
	for row: int in fittings.count():
		if fittings.level_of(row) != Mound.SURFACE or fittings.state_of(row) != Fittings.ORDERED:
			continue
		for cell: Vector2i in fittings.work_cells(row):
			if mounds.group_of(cell) == group and mounds.is_open(cell) and not goals.has(cell):
				goals[cell] = row
	if goals.is_empty():
		return {}
	var path: Array[Vector2i] = walk_to_any(mounds, start, goals)
	if path.is_empty():
		return {}
	var at: Vector2i = path[path.size() - 1]
	return _job(Mounds.JOB_FIT_PIECE, group, door, at, int(goals[at]), path)


static func walk_to_any(mounds: Mounds, start: Vector2i, goals: Dictionary) -> Array[Vector2i]:
	"""Breadth first from `start` through open cells to the nearest of `goals` (keys: cells): the cells walked, both
	ends included; empty when none can be reached."""
	if goals.has(start):
		return [start]
	var came: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size() and head < SEARCH_LIMIT:
		var at: Vector2i = queue[head]
		head += 1
		for step: Vector2i in Mound.SIDE_STEPS:
			var next: Vector2i = at + step
			if came.has(next) or not mounds.is_open(next):
				continue
			came[next] = at
			if goals.has(next):
				return _walk(came, next)
			queue.append(next)
	return []


static func words(job: Dictionary, mounds: Mounds) -> String:
	"""What the builder is doing, in words ("Digging", "Fitting the front door")."""
	if job.is_empty():
		return ""
	var kind: int = int(job["kind"])
	if kind == Mounds.JOB_FIT_EDGE:
		var row: int = mounds.row_at(job["edge"])
		return Mounds.JOB_WORDS[kind] % Mound.kind_name(mounds.edge_kind(row)).to_lower() if row >= 0 else ""
	return Mounds.JOB_WORDS[kind]
