extends RefCounted
## THE VILLAGE GOALS' OWNER (decision 0781): the goal book (goal_book.gd) filled with the built-in goals
## (village_goals.gd) and the ledger they read (goals_ledger.gd), ticked on the GAME HOUR. Made and driven by the
## first-village guide (demo_guide.gd: `update()` each frame, which costs an integer compare until the calendar's hour
## changes); shown in the village guide's Goals tab (goals_page.gd).
##
## A REACHED GOAL is said once in Village news (`post`, the guide's own chronicle: demo_notices.gd SOURCE_VILLAGE, a
## NOTE) -- the news strip shows it while fresh and the history keeps it: that is the goal's whole reward. Nothing is
## granted: no resource, no unlock, no mood (decision 0781).
##
## AFTER THE GUIDE. Once the first-village guide is complete (`guide_done`), one note -- at the next game hour, after the
## guide's own completion line -- points the player at the Goals tab, so play has something to aim for when the guide's
## four objectives are done. The guide itself is not changed.
##
## LATER FEATURES add their own goals through `book` (goal_book.gd THE REGISTRATION API; godot/demo/README.md).

const BookScript := preload("res://demo/goals/goal_book.gd")
const LedgerScript := preload("res://demo/goals/goals_ledger.gd")
const VillageScript := preload("res://demo/goals/village_goals.gd")
const WorldScript := preload("res://demo/guide/guide_world.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")

const REACHED: String = "Goal reached: %s -- %s"
const MILESTONE_MET: String = "Milestone conditions met: %s -- %s"
const AFTER_GUIDE: String = "What next: the village guide's Goals tab (O) holds goals to aim for now the first village stands."

var book: BookScript = BookScript.new()
var ledger: LedgerScript = LedgerScript.new()
var village: VillageScript = null
## `(text: String) -> void`: a Village news note (the guide's chronicle).
var post: Callable = Callable()
## `() -> bool`: whether the first-village guide is complete.
var guide_done: Callable = Callable()
## Whether the after-the-guide note has been said.
var pointed: bool = false

var _world: WorldScript = null


func configure(world: WorldScript, record: RecordScript = null) -> void:
	"""Measure the built-in goals over `world` (the guide's read-only view of the village) and the seasonal planner's
	`record` (null: the record's goals stay at nothing)."""
	_world = world
	village = VillageScript.new(world, ledger, record)
	village.register_all(book)
	book.reached = _on_reached


func update() -> bool:
	"""Each frame: on a new game hour, the ledger's look and the book's evaluation (returns whether it evaluated); and,
	the guide complete, the one note pointing at the goals -- at the hour too, so the guide's own completion line has
	the news strip to itself first."""
	var hour: int = hour_index()
	if hour == book.hour_seen():
		return false
	if village != null:
		village.observe()
	var evaluated: bool = book.update(hour)
	_point()
	return evaluated


func hour_index() -> int:
	"""The calendar's hour index now (0 unbound)."""
	return _world.calendar.hour_index() if _world != null and _world.calendar != null else 0


func _point() -> void:
	"""Say AFTER_GUIDE once, when the guide is complete."""
	if pointed or not guide_done.is_valid() or not bool(guide_done.call()):
		return
	pointed = true
	_say(AFTER_GUIDE)


func _on_reached(goal: BookScript.Goal) -> void:
	"""A goal reached: its line in Village news. (The Great Hall's tapestry, when it lands, records it here too.)"""
	var form: String = MILESTONE_MET if goal.group == BookScript.GROUP_MILESTONE else REACHED
	_say(form % [goal.title, goal.said])


func _say(text: String) -> void:
	"""A Village news note."""
	if post.is_valid():
		post.call(text)
