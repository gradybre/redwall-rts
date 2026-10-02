extends RefCounted
## THE GOAL BOOK (decision 0781): the village's optional goals and the GDD's milestones, as DATA ENTRIES each measured by
## a small evaluator over the village's existing state. Pure logic, no nodes: demo_goals.gd owns one, the village guide's
## Goals tab (goals_page.gd) shows it, and a suite drives it alone.
##
## A GOAL is an id, a title, a short WHY, a group (the GDD's MILESTONES, or the demo's VILLAGE goals) and one or more
## PARTS. A part is a key, a label, a target, a unit and a MEASURE: a `() -> int` Callable bound by whoever registered
## the goal, read at least-or-more against its target ("Residents: 9 of 12"). A part registered WITHOUT a measure is a
## condition the demo does not model yet ("Fuel for 18 winter days: not in this demo yet"): it is shown, never met, so
## its goal cannot be reached until a later feature binds a measure to it (`bind_measure`). A goal is REACHED when every
## part is met; reached, it stays reached (a goal is an achievement, as the GDD's milestone awards are monotonic) and its
## values go on being shown as they stand.
##
## EVALUATED ON THE GAME HOUR, never per frame: `update(hour_index)` does nothing unless the calendar's hour index has
## changed since the last look (an integer compare: the per-frame cost), and then reads every unreached goal's measures
## once. A reached goal is posted ONCE through `reached` (the owner's: a Village news note, which is the notice and the
## history entry). Nothing here grants a resource, an unlock or a fact.
##
## THE REGISTRATION API (for later features -- winter fuel, dishes, the cellar):
##     var parts: Array[GoalBook.Part] = [GoalBook.part(&"chilled", "Winters with no one chilled", 1,
##         GoalBook.UNIT_COUNT, my_model.unchilled_winters)]
##     book.register(&"winter_no_one_chilled", "A warm first winter", "Why it matters...", parts)
##     book.bind_measure(&"m4_hearth_charter", &"fuel", my_model.fuel_winter_days_milli)
## `register` returns "" when taken, else why not (a duplicate id, no title, no parts, a part without a positive target
## or with an unknown unit). A measure must be cheap and allocation-free: it is read once a game hour.

const UNIT_COUNT: int = 0
## Thousandths of a unit, shown "12.0 U".
const UNIT_MILLI: int = 1
## Thousandths of a day, shown "2.5 days".
const UNIT_DAYS: int = 2
## A yes-or-no condition (a measure of 1 or more is yes), shown "yes" / "not yet".
const UNIT_FLAG: int = 3
const UNIT_LIMIT: int = 4
const GROUP_MILESTONE: int = 0
const GROUP_VILLAGE: int = 1
const GROUP_COUNT: int = 2
## A part's value before its first reading, or while it has no measure.
const UNREAD: int = -1
const REFUSE_ID: String = "A goal needs an id."
const REFUSE_DUPLICATE: String = "A goal with that id is already registered."
const REFUSE_TITLE: String = "A goal needs a title."
const REFUSE_PARTS: String = "A goal needs at least one part."
const REFUSE_TARGET: String = "Every part needs a target above zero."
const REFUSE_UNIT: String = "A part's unit is unknown."
const REFUSE_GROUP: String = "A goal's group is unknown."
const REFUSE_KEY: String = "Two parts of one goal share a key."


## One condition of a goal.
class Part extends RefCounted:
	var key: StringName = &""
	var label: String = ""
	var target: int = 0
	var unit: int = 0
	## `() -> int`; invalid while the demo does not model the condition.
	var measure: Callable = Callable()
	## Its value at the last evaluation (UNREAD before one, or unmeasured).
	var value: int = -1

	func is_measured() -> bool:
		"""Whether the condition has a measure."""
		return measure.is_valid()

	func is_met() -> bool:
		"""Whether its last reading reached its target."""
		return measure.is_valid() and value >= target


## One goal.
class Goal extends RefCounted:
	var id: StringName = &""
	var title: String = ""
	var why: String = ""
	var group: int = GROUP_VILLAGE
	var parts: Array[Part] = []
	## What the news says when it is reached (after "Goal reached: <title> -- ").
	var said: String = ""
	var done: bool = false
	## The calendar hour index it was reached at (-1: not yet).
	var done_hour: int = -1

	func met_parts() -> int:
		"""How many of its parts are met now."""
		var met: int = 0
		for each: Part in parts:
			if each.is_met():
				met += 1
		return met

	func is_measured() -> bool:
		"""Whether every part has a measure (else it cannot be reached in this build)."""
		for each: Part in parts:
			if not each.is_measured():
				return false
		return true


var goals: Array[Goal] = []
## `(goal: Goal) -> void`: called once when a goal is reached (the owner posts its news).
var reached: Callable = Callable()
## Bumped whenever a goal is registered, bound or reached.
var revision: int = 0
## Bumped at every evaluation (the page redraws its figures on a change).
var evaluations: int = 0

var _hour: int = UNREAD
## The objects whose methods measure parts, held for the book's life (a Callable does not keep its object alive).
var _owners: Array[RefCounted] = []


static func part(key: StringName, label: String, target: int, unit: int = UNIT_COUNT,
		measure: Callable = Callable()) -> Part:
	"""A goal's part: `key` names it within its goal (for `bind_measure`); no measure = not modelled yet."""
	var made := Part.new()
	made.key = key
	made.label = label
	made.target = target
	made.unit = unit
	made.measure = measure
	return made


func register(id: StringName, title: String, why: String, parts: Array[Part], group: int = GROUP_VILLAGE,
		said: String = "") -> String:
	"""Add a goal (see THE REGISTRATION API). Returns '' when taken, else why not. It is first measured at the next
	evaluation."""
	var refused: String = _refusal(id, title, parts, group)
	if not refused.is_empty():
		return refused
	var made := Goal.new()
	made.id = id
	made.title = title
	made.why = why
	made.group = group
	made.parts = parts
	made.said = said
	goals.append(made)
	revision += 1
	return ""


func _refusal(id: StringName, title: String, parts: Array[Part], group: int) -> String:
	"""Why a goal cannot be registered ('' when it can)."""
	if id == &"":
		return REFUSE_ID
	if index_of(id) >= 0:
		return REFUSE_DUPLICATE
	if title.strip_edges().is_empty():
		return REFUSE_TITLE
	if parts.is_empty():
		return REFUSE_PARTS
	if group < 0 or group >= GROUP_COUNT:
		return REFUSE_GROUP
	var keys: Array[StringName] = []
	for each: Part in parts:
		if each.target <= 0:
			return REFUSE_TARGET
		if each.unit < 0 or each.unit >= UNIT_LIMIT:
			return REFUSE_UNIT
		if keys.has(each.key):
			return REFUSE_KEY
		keys.append(each.key)
	return ""


func keep(owner: RefCounted) -> void:
	"""Hold `owner` -- an evaluator whose methods measure parts -- as long as the book lives."""
	if owner != null and not _owners.has(owner):
		_owners.append(owner)


func bind_measure(id: StringName, key: StringName, measure: Callable) -> bool:
	"""Give goal `id`'s part `key` its measure (a later feature modelling a condition declared unmodelled). False when
	there is no such goal or part, the measure is invalid, or the goal is already reached."""
	var found: Part = part_of(id, key)
	if found == null or not measure.is_valid() or goal(id).done:
		return false
	found.measure = measure
	revision += 1
	return true


func index_of(id: StringName) -> int:
	"""Goal `id`'s row (-1: none)."""
	for k: int in goals.size():
		if goals[k].id == id:
			return k
	return -1


func goal(id: StringName) -> Goal:
	"""Goal `id` (null: none)."""
	var k: int = index_of(id)
	return goals[k] if k >= 0 else null


func part_of(id: StringName, key: StringName) -> Part:
	"""Goal `id`'s part `key` (null: none)."""
	var found: Goal = goal(id)
	if found == null:
		return null
	for each: Part in found.parts:
		if each.key == key:
			return each
	return null


# --- evaluation ------------------------------------------------------------------------------------------------------

func update(hour_index: int) -> bool:
	"""THE HOUR TICK: evaluate when the calendar's hour index differs from the last one evaluated (the first call always
	does). Returns whether it evaluated."""
	if hour_index == _hour:
		return false
	_hour = hour_index
	_evaluate()
	return true


func _evaluate() -> void:
	"""Read every goal's measures; an unreached goal with every part met is reached now, and said once."""
	evaluations += 1
	for each: Goal in goals:
		_read(each)
		if each.done or each.met_parts() < each.parts.size():
			continue
		each.done = true
		each.done_hour = _hour
		revision += 1
		if reached.is_valid():
			reached.call(each)


static func _read(each: Goal) -> void:
	"""Each part's value now (UNREAD for one without a measure)."""
	for one: Part in each.parts:
		one.value = int(one.measure.call()) if one.measure.is_valid() else UNREAD


func hour_seen() -> int:
	"""The hour index last evaluated (UNREAD before the first)."""
	return _hour


func done_count(group: int) -> int:
	"""How many goals of `group` are reached."""
	var n: int = 0
	for each: Goal in goals:
		if each.group == group and each.done:
			n += 1
	return n


func count(group: int) -> int:
	"""How many goals `group` has."""
	var n: int = 0
	for each: Goal in goals:
		if each.group == group:
			n += 1
	return n


# --- words -----------------------------------------------------------------------------------------------------------

static func amount_text(unit: int, value: int) -> String:
	"""A value as the player reads it: '12', '12.0 U', '2.5 days', 'yes' / 'not yet'."""
	if unit == UNIT_FLAG:
		return "yes" if value > 0 else "not yet"
	var shown: int = maxi(value, 0)
	@warning_ignore("integer_division")
	var whole: int = shown / 1000
	@warning_ignore("integer_division")
	var tenth: int = (shown % 1000) / 100
	match unit:
		UNIT_MILLI: return "%d.%d U" % [whole, tenth]
		UNIT_DAYS: return "%d.%d days" % [whole, tenth]
	return str(shown)
