extends RefCounted
## THE ORDER LIST'S ENTRIES (decision 0411, review UX-002): what a Shift+right-click appends to a resident's list
## (resident_brain.gd THE ORDER LIST) -- a board task to take up (QueuedTask) or a walk to a spot (QueuedWalk) -- and
## the list's words, Now -> Next -> then its routine. Presentation only.
##
## Neither entry holds the work board itself, only a weak reference: the board holds every brain, and a brain holds its
## list, so a strong reference back would be a cycle never freed (the brain's DigBack rule, decision 0205).

const WorkIds := preload("res://demo/work/work_ids.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")

## How the list reads (the party panel's and the Work screen's line).
const NEXT: String = "Next: %s"
const BACK_TO: String = "back to %s"
const THEN_ROUTINE: String = "then its routine"
const JOINER: String = " → "


## A board task queued for a resident: taken up by the board's `take_back_task` while it still waits.
class QueuedTask extends RefCounted:
	var board: WeakRef = null
	var source: int = -1
	var row: int = -1
	var key: int = 0

	func _init(owner: RefCounted, task_source: int, task_row: int, task_key: int) -> void:
		"""Task (source, row, key) of `owner`, the work board."""
		board = weakref(owner)
		source = task_source
		row = task_row
		key = task_key

	func take_back(brain: RefCounted) -> bool:
		"""Give the task to this resident, if the board is still there and the task still waits."""
		var owner: RefCounted = board.get_ref() as RefCounted
		if owner == null:
			return false
		return bool(owner.call(&"take_back_task", brain, source, row, key))


## A walk queued for a resident: ordered when its turn comes; the board ends it on arrival (or when it is given up).
class QueuedWalk extends RefCounted:
	var board: WeakRef = null
	var goal: Vector2 = Vector2.ZERO

	func _init(owner: RefCounted, to: Vector2) -> void:
		"""A walk to `to`, tracked by `owner`, the work board."""
		board = weakref(owner)
		goal = to

	func take_back(brain: RefCounted) -> bool:
		"""Walk there now; the board watches for the end of the walk."""
		var owner: RefCounted = board.get_ref() as RefCounted
		if owner == null:
			return false
		var walker := brain as BrainScript
		walker.order_move(goal)
		owner.call(&"track_walk", walker.index, goal)
		return true


static func task_entry(owner: RefCounted, task_source: int, row: int, task_key: int, words: String) -> UnfinishedScript:
	"""An order-list entry for a board task (it names the task, so the board's claims leave it to this resident)."""
	var queued := QueuedTask.new(owner, task_source, row, task_key)
	return UnfinishedScript.new(queued.take_back, words, task_source, task_key)


static func walk_entry(owner: RefCounted, to: Vector2) -> UnfinishedScript:
	"""An order-list entry for a walk to `to`."""
	var walk := QueuedWalk.new(owner, to)
	return UnfinishedScript.new(walk.take_back, "Walk to %.1f, %.1f" % [to.x, to.y], WorkIds.SOURCE_WALK, -1)


static func entry_words(brain: BrainScript, k: int) -> String:
	"""Entry `k` (take order) in the list's words: a queued order as it is, a job kept from an interruption "back to
	..."."""
	var entry: UnfinishedScript = brain.queue_entry(k)
	if entry == null:
		return ""
	return entry.label() if entry.queued else BACK_TO % entry.label()


static func items_into(brain: BrainScript, out: PackedStringArray) -> PackedStringArray:
	"""Every entry's words, in take order, into `out` (cleared first)."""
	out.clear()
	for k: int in brain.queue_size():
		out.append(entry_words(brain, k))
	return out


static func ribbon(items: PackedStringArray) -> String:
	"""The list as one line: "Next: Harvest, bed 3 → back to Brace, tunnel 2" ("" for an empty list)."""
	if items.is_empty():
		return ""
	return NEXT % JOINER.join(items)
