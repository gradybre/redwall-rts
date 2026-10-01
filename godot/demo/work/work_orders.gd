extends RefCounted
## SHIFT+RIGHT-CLICK: append an order to the selection's order lists (decision 0411, review UX-002; UI §3's
## `command_queue`, "Append up to 8 manual tasks per resident; needs still preempt"). Presentation only.
##
## What was clicked decides the order, as a plain right-click does: a bed its most pressing verb (demo_farm.gd
## `pressing_kind_into`), a tree, trunk, deadfall pile or the sawhorse the woods' verb for it, open ground a walk there.
## A board task is put on the board first (the owner's own `order` with nobody selected: queued, or found queued), then
## appended to the order list of the NEAREST selected resident -- one worker a job, as a plain order sends the nearest
## -- through the work board (`queue_task`), which leaves it to that resident; a walk is appended to every selected
## resident's list. A resident with nothing to do takes its first entry up at once. Clearing a spoil heap is given by
## order only (spoil_crew.gd keeps no waiting rows): Shift on a heap says so.

const WorkIds := preload("res://demo/work/work_ids.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const FarmScript := preload("res://demo/farm/demo_farm.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const PickScript := preload("res://demo/forestry/forest_pick.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const SpoilScript := preload("res://demo/spoil/demo_spoil.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

const AnswerScript := preload("res://demo/work/queue_answer.gd")

const QUEUED: String = "%s queued for %s (%d on its list)"
const NOT_TAKEN: String = "%s cannot be taken now"
const TAKEN: String = "%s: %s is on it now (it had nothing else to do)"
const CANT: String = "Can't queue: %s"
const UNDER_WAY: String = "%s is under way already: %s is on it"
const WALK_QUEUED: String = "Walk queued for %d"
const HEAP_BY_ORDER: String = "Can't queue: a spoil heap is cleared by order — right-click it without Shift"
const NOTHING_ON_BED: String = "Can't queue: nothing to do on bed %d now"
const YOUNG_TREE: String = "Can't queue: a young tree is left to grow"

var _board: BoardScript = null
var _farm: FarmScript = null
var _forestry: ForestryScript = null
var _spoil: SpoilScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _task: TaskScript = TaskScript.new()
## Whether the call under way queued something (`queue_at`'s answer).
var _ok: bool = false


func configure(board: BoardScript, farm: FarmScript, forestry: ForestryScript, spoil: SpoilScript) -> void:
	"""Queue through this board, onto these owners' boards (any may be null)."""
	_board = board
	_farm = farm
	_forestry = forestry
	_spoil = spoil


func queue_at(screen: Vector2, ground: Vector2, members: PackedInt32Array) -> AnswerScript:
	"""Shift+right-click at screen point `screen`, over ground point `ground` (x z metres; INF off the ground), with
	`members` selected: append the order to their lists. Whether one was queued, and what to say (nothing with nobody
	selected or off the ground)."""
	_ok = false
	var said: String = _queue_at(screen, ground, members)
	return AnswerScript.new(_ok, said)


func _queue_at(screen: Vector2, ground: Vector2, members: PackedInt32Array) -> String:
	"""`queue_at`'s words (`_ok` set when something was queued)."""
	if members.is_empty():
		return ""
	if _farm != null and _farm.bed_at_into(screen, _read):
		return _queue_bed(_read.value, members)
	if _forestry != null:
		var kind: int = _forestry.pick_at(screen)
		if kind != PickScript.KIND_NONE:
			return _queue_woods(kind, _forestry.picker.index, members)
	if not ground.is_finite():
		return ""
	if _spoil != null and _spoil.heap_at_point(ground) != SpoilScript.NOTHING:
		return HEAP_BY_ORDER
	return queue_walks(ground, members)


func queue_walks(ground: Vector2, members: PackedInt32Array) -> String:
	"""A walk to `ground` on every member's list (`_ok` when at least one took it)."""
	var queued: int = 0
	var refused: String = ""
	for who: int in members:
		var why: String = _board.queue_walk(who, ground)
		if why.is_empty():
			queued += 1
		else:
			refused = why
	_ok = queued > 0
	return CANT % refused if queued == 0 else WALK_QUEUED % queued


func _queue_bed(bed: int, members: PackedInt32Array) -> String:
	"""The bed's most pressing verb, put on the farm's board and queued for the nearest member -- whose list must have
	room first, so nothing is put on the board for nobody."""
	if not _farm.pressing_kind_into(bed, _read):
		return NOTHING_ON_BED % (bed + 1)
	var kind: int = _read.value
	var who: int = nearest(members, Catalog.bed_centre_m(bed))
	if not _board.brain_of(who).can_queue():
		return CANT % (BoardScript.LIST_FULL % [_board.name_of(who), BrainScript.QUEUE_MAX])
	var said: String = _farm.crew.order(kind, bed, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	if not _farm.crew.jobs.job_on_bed_into(kind, bed, _read):
		return said
	return queue_task(WorkIds.SOURCE_FARM, _read.value, who)


func _queue_woods(picked: int, index: int, members: PackedInt32Array) -> String:
	"""The woods' verb for what was clicked, put on the woods' board and queued for the nearest member (its list's room
	checked first)."""
	var kind: int = woods_kind(picked, index)
	if kind < 0:
		return YOUNG_TREE
	var target: int = ForestJobs.NO_TARGET if kind == ForestJobs.KIND_SAW else index
	var gen: int = _forestry.deadfall.generation[index] if kind == ForestJobs.KIND_GATHER else 0
	var who: int = nearest(members, _forestry.crew.point_of(kind, target))
	if not _board.brain_of(who).can_queue():
		return CANT % (BoardScript.LIST_FULL % [_board.name_of(who), BrainScript.QUEUE_MAX])
	var said: String = _forestry.crew.order(kind, target, gen, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	var row: int = waiting_row(kind, target)
	if row < 0:
		return said
	return queue_task(WorkIds.SOURCE_WOODS, row, who)


func woods_kind(picked: int, index: int) -> int:
	"""The woods job a click on `picked` (PickScript.KIND_*) at `index` stands for (-1: none -- a young tree)."""
	match picked:
		PickScript.KIND_TRUNK:
			return ForestJobs.KIND_HAUL
		PickScript.KIND_PILE:
			return ForestJobs.KIND_GATHER
		PickScript.KIND_SAW:
			return ForestJobs.KIND_SAW
	match _forestry.stand.state_of(index):
		StandScript.STATE_MATURE:
			return ForestJobs.KIND_HAUL if _forestry.crew.jobs.on_target(ForestJobs.KIND_FELL, index) > 0 \
				else ForestJobs.KIND_FELL
		StandScript.STATE_STUMP:
			return ForestJobs.KIND_GRUB
		StandScript.STATE_CLEARED:
			return ForestJobs.KIND_PLANT
	return -1


func waiting_row(kind: int, target: int) -> int:
	"""The newest job of `kind` on `target` nobody is on (-1: none) -- the one an order with nobody selected left."""
	var jobs: ForestJobs = _forestry.crew.jobs
	var best: int = -1
	for row: int in ForestJobs.MAX_JOBS:
		if jobs.is_live(row) and jobs.kind[row] == kind and jobs.target[row] == target \
				and jobs.worker[row] == ForestJobs.NOBODY and (best < 0 or jobs.serial[row] > jobs.serial[best]):
			best = row
	return best


func queue_task(task_source: int, row: int, who: int) -> String:
	"""Queue board task (source, row) for `who`; says what happened -- queued, or taken up at once by an idle `who`
	(`_ok` either way), or why not."""
	if not _board.fill(task_source, row, _task):
		return CANT % WorkIds.NOT_FOUND
	var words: String = "%s %s" % [_task.action, _task.target]
	if _task.worker >= 0:
		return CANT % (UNDER_WAY % [words, _board.name_of(_task.worker)])
	var why: String = _board.queue_task(task_source, row, who)
	if not why.is_empty():
		return CANT % why
	var brain: BrainScript = _board.brain_of(who)
	if brain.promises(task_source, _task.key):
		_ok = true
		return QUEUED % [words, _board.name_of(who), brain.queue_size()]
	if _board.source(task_source).worker(row) == who:
		_ok = true
		return TAKEN % [words, _board.name_of(who)]
	return CANT % (NOT_TAKEN % words)


func nearest(members: PackedInt32Array, to: Vector2) -> int:
	"""The member standing nearest `to` (on the surface, or the mouth it comes up at)."""
	var best: int = members[0]
	var best_d: float = INF
	for who: int in members:
		var d: float = _board.brain_of(who).surface_point().distance_squared_to(to)
		if d < best_d:
			best_d = d
			best = who
	return best
