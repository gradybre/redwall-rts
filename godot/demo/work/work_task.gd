extends RefCounted
## One task as the Work screen reads it (decision 0411, review F32): filled by its source (work_source.gd `fill`), never
## kept between reads -- the board reuses one record a row. Presentation only.

const WorkIds := preload("res://demo/work/work_ids.gd")

## Which source and row it is, and the job's identity there (its serial; a reused row is a different task).
var source: int = -1
var row: int = -1
var key: int = 0
## "Harvest", "the carrot bed".
var action: String = ""
var target: String = ""
## The resident on it (-1: nobody).
var worker: int = -1
## WorkIds.STATE_*, and the reason in words when it is BLOCKED or PAUSED (or what it waits for).
var state: int = WorkIds.STATE_QUEUED
var reason: String = ""
## Demo microseconds of work left (-1: not known), and how far it is (0-100; -1: not known).
var remaining_usec: int = -1
var percent: int = -1
## WorkIds.ACT_*: which crews prefer it.
var activity: int = WorkIds.ACT_HAUL
## A load in hand (it is never paused or handed to someone else from afar).
var carrying: bool = false
## Where it is (presentation metres), and what the village's "Go to" calls it (demo_notices.gd TARGET_*, id).
var point: Vector2 = Vector2.ZERO
var target_kind: int = 0
var target_id: int = -1
## Why each command cannot be used on it now ("" when it can).
var pause_refusal: String = ""
var cancel_refusal: String = ""
var reassign_refusal: String = ""
## Whether the player paused it.
var paused: bool = false


func reset(task_source: int, task_row: int) -> void:
	"""Start filling for `task_row` of `task_source`: every field back to its default."""
	source = task_source
	row = task_row
	key = 0
	action = ""
	target = ""
	worker = -1
	state = WorkIds.STATE_QUEUED
	reason = ""
	remaining_usec = -1
	percent = -1
	activity = WorkIds.ACT_HAUL
	carrying = false
	point = Vector2.ZERO
	target_kind = 0
	target_id = -1
	pause_refusal = ""
	cancel_refusal = ""
	reassign_refusal = ""
	paused = false


func walking_state(issued: bool, carrying_load: bool) -> int:
	"""The state of a task whose worker is on a walk step: ASSIGNED before the walk is issued, then TRAVELLING, or
	HAULING with a load in hand."""
	if carrying_load:
		return WorkIds.STATE_HAULING
	return WorkIds.STATE_TRAVELLING if issued else WorkIds.STATE_ASSIGNED
