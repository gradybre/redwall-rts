extends VBoxContainer
## THE GOALS' PAGE (decision 0781) in the village guide: the goal book's goals in its two groups -- the demo's village
## goals, which this village can reach, then the GDD's milestones, the road ahead -- each its mark and title (with the date it was reached), its short why and its parts'
## progress ("Residents: 9 of 12"; "Recipes mastered (3): not in this demo yet"). It shows; the book decides and the
## village's own figures measure, once a game hour. The rows are built when the goals change (one registered later) and
## their words rewritten when the book has evaluated since the last look. DEMO UI in the woodland skin.

const BookScript := preload("res://demo/goals/goal_book.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const GuideUi := preload("res://demo/guide/guide_ui.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const INTRO: String = "Goals to aim for once the first village stands. Each is reached only by what really happens in the village, checked every game hour; reaching one is noted in Village news, and nothing else is granted."
const GROUP_HEADS: Array[String] = ["Milestones (the full game's): %d of %d met", "Village goals: %d of %d reached"]
## Said once under a group's heading.
const GROUP_NOTES: Array[String] = ["The GDD's milestones, measured on this village. The demo has no arrivals, so their resident counts are out of reach: they show the road ahead, and reaching one here would grant nothing.", ""]
## The groups in the order drawn: the goals this village can reach first, then the milestones' road ahead.
const DISPLAY_ORDER: Array[int] = [BookScript.GROUP_VILLAGE, BookScript.GROUP_MILESTONE]
const EMPTY: String = "No goals yet."
const MARK_DONE: String = "✓ %s -- reached %s"
const MARK_OPEN: String = "◻ %s"
const PART_LINE: String = "  · %s: %s of %s"
const PART_MET: String = "  ✓ %s: %s"
const PART_FLAG: String = "  · %s: %s"
const PART_UNMODELLED: String = "  · %s (%s): not in this demo yet"
const NOT_YET_READ: String = "  · %s: not checked yet"

var book: BookScript = null

## Per goal (in book order): its title line, its why, its parts' lines.
var _titles: Array[Label] = []
var _whys: Array[Label] = []
var _parts: Array[Label] = []
var _heads: Array[Label] = []
var _intro: Label = null
var _built: int = -1
var _drawn: Vector2i = Vector2i(-1, -1)
var _width: float = 520.0


func _init() -> void:
	"""The intro line; the rows come with the book."""
	name = "GoalsPage"
	add_theme_constant_override(&"separation", 6)
	_intro = GuideUi.line(INTRO, FarmUi.SMALL_PX, Palette.UMBER, _width)
	add_child(_intro)


func refresh() -> void:
	"""Rebuild the rows when the goals changed, rewrite their words when the book has evaluated or changed."""
	if book == null:
		return
	if book.goals.size() != _built:
		_build()
	var now := Vector2i(book.evaluations, book.revision)
	if now == _drawn:
		return
	_drawn = now
	_write()


func _build() -> void:
	"""One heading a group and three lines a goal, in group order (the book's order within a group)."""
	for child: Node in get_children():
		if child != _intro:
			remove_child(child)
			child.queue_free()
	_titles.clear()
	_whys.clear()
	_parts.clear()
	_heads.clear()
	_built = book.goals.size()
	_drawn = Vector2i(-1, -1)
	if book.goals.is_empty():
		add_child(GuideUi.line(EMPTY, FarmUi.SMALL_PX, Palette.UMBER, _width))
	for group: int in DISPLAY_ORDER:
		_build_group(group)


func _build_group(group: int) -> void:
	"""A group's heading and its goals' lines (none for an empty group)."""
	if book.count(group) == 0:
		return
	var head: Label = GuideUi.line("", FarmUi.BODY_PX, Palette.LEAF, _width, true)
	head.set_meta(&"group", group)
	add_child(head)
	_heads.append(head)
	if not GROUP_NOTES[group].is_empty():
		add_child(GuideUi.line(GROUP_NOTES[group], FarmUi.SMALL_PX, Palette.UMBER, _width))
	for goal: BookScript.Goal in book.goals:
		if goal.group != group:
			continue
		var title: Label = GuideUi.line("", FarmUi.BODY_PX, Palette.INK, _width, true)
		title.set_meta(&"goal", goal.id)
		add_child(title)
		_titles.append(title)
		var why: Label = GuideUi.line(goal.why, FarmUi.SMALL_PX, Palette.UMBER, _width)
		add_child(why)
		_whys.append(why)
		var parts: Label = GuideUi.line("", FarmUi.SMALL_PX, Palette.INK, _width)
		add_child(parts)
		_parts.append(parts)


func _write() -> void:
	"""Every heading's count and every goal's mark and progress as the book stands."""
	for head: Label in _heads:
		var group: int = int(head.get_meta(&"group"))
		head.text = GROUP_HEADS[group] % [book.done_count(group), book.count(group)]
	for k: int in _titles.size():
		var goal: BookScript.Goal = book.goal(StringName(_titles[k].get_meta(&"goal")))
		if goal == null:
			continue
		_titles[k].text = MARK_DONE % [goal.title, date_of_hour(goal.done_hour)] if goal.done \
			else MARK_OPEN % goal.title
		_parts[k].text = "\n".join(part_lines(goal))


static func part_lines(goal: BookScript.Goal) -> PackedStringArray:
	"""A goal's parts as lines: met, its progress, not modelled, or not read yet."""
	var lines := PackedStringArray()
	for part: BookScript.Part in goal.parts:
		var target: String = BookScript.amount_text(part.unit, part.target)
		if not part.is_measured():
			lines.append(PART_UNMODELLED % [part.label, target if part.unit != BookScript.UNIT_FLAG else "yes"])
		elif part.value == BookScript.UNREAD:
			lines.append(NOT_YET_READ % part.label)
		elif part.is_met():
			lines.append(PART_MET % [part.label, BookScript.amount_text(part.unit, part.value)])
		elif part.unit == BookScript.UNIT_FLAG:
			lines.append(PART_FLAG % [part.label, BookScript.amount_text(part.unit, part.value)])
		else:
			lines.append(PART_LINE % [part.label, BookScript.amount_text(part.unit, part.value), target])
	return lines


static func date_of_hour(hour_index: int) -> String:
	"""The demo's date of a calendar hour index: 'Y1 Spring 3, 14:00' (as demo_calendar.gd `date_text`)."""
	@warning_ignore("integer_division")
	var day: int = maxi(hour_index, 0) / SimClock.HOURS_PER_DAY
	@warning_ignore("integer_division")
	var year: int = day / SimClock.DAYS_PER_YEAR + 1
	@warning_ignore("integer_division")
	var season: int = (day % SimClock.DAYS_PER_YEAR) / SimClock.DAYS_PER_SEASON
	return "Y%d %s, %02d:00" % [year, CalendarScript.day_text(season, day % SimClock.DAYS_PER_SEASON + 1),
		maxi(hour_index, 0) % SimClock.HOURS_PER_DAY]


func set_text_width(width: float) -> void:
	"""Wrap at `width`."""
	_width = width
	for child: Node in get_children():
		if child is Label:
			(child as Label).custom_minimum_size.x = width


func goal_text(id: StringName) -> String:
	"""Goal `id`'s title and parts as drawn (checks; '' when it has no row)."""
	for k: int in _titles.size():
		if StringName(_titles[k].get_meta(&"goal")) == id:
			return _titles[k].text + "\n" + _parts[k].text
	return ""


func heading_text(group: int) -> String:
	"""Group `group`'s heading as drawn (checks; '' when it has none)."""
	for head: Label in _heads:
		if int(head.get_meta(&"group")) == group:
			return head.text
	return ""
