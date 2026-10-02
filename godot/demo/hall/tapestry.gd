extends RefCounted
## THE VILLAGE TAPESTRY (decision 0771): the village's own history, woven in the hall. Presentation only; session only
## (the demo cannot save). An ORIGINAL community tapestry: LORE-R07 (docs/setting_bible.md) -- "do not install the
## canonical tapestry in an unrelated settlement by default" -- and the bible's rule that an original memorial is not
## to be casually identified as Martin's. Nothing here names, quotes or depicts a book's tapestry.
##
## THE API (for the chronicle, #10, and the milestones, #57; the hall's own entries use it too):
##
##     var tapestry = village.tapestry()            # demo_village.gd; null before the hall is built
##     var at: int = tapestry.add_entry(Tapestry.KIND_MILESTONE, "The first bridge", "Linnet built it", &"bridge_1")
##     if at < 0: print(Tapestry.refusal_text(at))  # REFUSED_*: empty title, unknown kind, full, or the key woven
##
##   add_entry(kind, title, text = "", once_key = &"") -> int
##       Weave one entry dated NOW (the demo calendar's tick). `kind` is a KIND_*; `title` is required, one line, cut
##       at TITLE_MAX characters; `text` is optional, cut at TEXT_MAX. `once_key`, when given, makes it once-only: a
##       second entry with the same key is refused (REFUSED_DUPLICATE), so a caller may post on every check without
##       counting. Returns the entry's index (entries stay in date order; a later entry never moves an earlier one).
##   add_entry_at(at_tick, kind, title, text = "", once_key = &"") -> int
##       The same, dated `at_tick` (>= 0), woven in among the others by date (ties after the ones already there).
##   count(), kind_of(i), title_of(i), text_of(i), tick_of(i), date_of(i), has_key(key), index_of_key(key)
##       Reading, oldest first. `revision` is bumped by every entry woven: a reader redraws when it changed.
##   refusal_text(code) -> String
##       A refused code (< 0) in words.
##
## CAPACITY entries at most; past that, entries are refused (REFUSED_FULL), never overwritten: the tapestry keeps the
## village's beginning. KIND_COLOURS give each kind its thread in the woodland palette.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const KIND_FOUNDING: int = 0
const KIND_STAGE: int = 1
const KIND_HARVEST: int = 2
const KIND_WINTER: int = 3
const KIND_DRESSING: int = 4
const KIND_MILESTONE: int = 5
const KIND_CHRONICLE: int = 6
const KIND_EVENT: int = 7
const KIND_COUNT: int = 8
const KIND_NAMES: Array[String] = ["founding", "the hall", "harvest", "winter", "dressing", "milestone", "chronicle",
	"event"]
## Each kind's thread colour (the knot on the timeline and its date).
const KIND_COLOURS: Array[Color] = [Palette.UMBER, Palette.BRASS, Palette.LEAF, Palette.SAGE, Palette.CLAY,
	Palette.EMBER, Palette.TIMBER, Palette.INK]

const CAPACITY: int = 128
const TITLE_MAX: int = 60
const TEXT_MAX: int = 240

const REFUSED_EMPTY: int = -1
const REFUSED_KIND: int = -2
const REFUSED_FULL: int = -3
const REFUSED_DUPLICATE: int = -4
const REFUSED_TICK: int = -5
const REFUSAL_WORDS: Array[String] = ["", "an entry needs a title", "no such kind of entry",
	"the tapestry is full (%d entries)" % CAPACITY, "that has been woven already",
	"an entry cannot be dated before tick 0"]

## Bumped by every entry woven.
var revision: int = 0

var _calendar: CalendarScript = null
var _tick: PackedInt64Array = PackedInt64Array()
var _kind: PackedByteArray = PackedByteArray()
var _title: PackedStringArray = PackedStringArray()
var _text: PackedStringArray = PackedStringArray()
var _key: Array[StringName] = []


func _init(calendar: CalendarScript) -> void:
	"""A tapestry dated by this calendar (none: every entry is dated tick 0)."""
	_calendar = calendar


func add_entry(kind: int, title: String, text: String = "", once_key: StringName = &"") -> int:
	"""Weave an entry dated now (see THE API): its index, or a REFUSED_* code."""
	var now: int = _calendar.tick if _calendar != null else 0
	return add_entry_at(now, kind, title, text, once_key)


func add_entry_at(at_tick: int, kind: int, title: String, text: String = "", once_key: StringName = &"") -> int:
	"""Weave an entry dated `at_tick` among the others by date (see THE API): its index, or a REFUSED_* code."""
	var why: int = _refusal(at_tick, kind, title, once_key)
	if why < 0:
		return why
	var at: int = _tick.size()
	while at > 0 and _tick[at - 1] > at_tick:
		at -= 1
	_tick.insert(at, at_tick)
	_kind.insert(at, kind)
	_title.insert(at, title.strip_edges().left(TITLE_MAX))
	_text.insert(at, text.strip_edges().left(TEXT_MAX))
	_key.insert(at, once_key)
	revision += 1
	return at


func _refusal(at_tick: int, kind: int, title: String, once_key: StringName) -> int:
	"""Why an entry would be refused (0: it would not)."""
	if title.strip_edges().is_empty():
		return REFUSED_EMPTY
	if kind < 0 or kind >= KIND_COUNT:
		return REFUSED_KIND
	if at_tick < 0:
		return REFUSED_TICK
	if once_key != &"" and _key.has(once_key):
		return REFUSED_DUPLICATE
	if _tick.size() >= CAPACITY:
		return REFUSED_FULL
	return 0


static func refusal_text(code: int) -> String:
	"""A REFUSED_* code in words ("" for an index)."""
	if code >= 0 or -code >= REFUSAL_WORDS.size():
		return ""
	return REFUSAL_WORDS[-code]


func count() -> int:
	"""How many entries are woven."""
	return _tick.size()


func kind_of(i: int) -> int:
	"""Entry `i`'s KIND_*."""
	return _kind[i]


func title_of(i: int) -> String:
	"""Entry `i`'s title."""
	return _title[i]


func text_of(i: int) -> String:
	"""Entry `i`'s text ("" none)."""
	return _text[i]


func tick_of(i: int) -> int:
	"""The demo calendar tick entry `i` is dated."""
	return _tick[i]


func date_of(i: int) -> String:
	"""Entry `i`'s date, as the village news dates a day: "Y1 Spring 3" (allocates: for drawing, not per frame)."""
	if _calendar == null:
		return "Y1 %s" % CalendarScript.day_text(0, 1)
	var at: SimClock.Calendar = _calendar.calendar_at(_tick[i])
	return "Y%d %s" % [at.year, CalendarScript.day_text(at.season, at.season_day)]


func has_key(once_key: StringName) -> bool:
	"""Whether an entry with this once-only key is woven."""
	return once_key != &"" and _key.has(once_key)


func index_of_key(once_key: StringName) -> int:
	"""The entry woven with this once-only key (-1: none)."""
	return _key.find(once_key) if once_key != &"" else -1
