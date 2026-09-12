extends RefCounted
## R-UI-ALERT-001's notice record: the whole condition, and the authored compact summary of it.
##
## The ruling settles a question §1.2's geometry cannot: `ALERT_H` is [48,96,96], so the NARROW
## alerts ZONE is 48 logical pixels -- one 44-high card and its padding. A full generation
## sentence wraps to three lines there, and growing the card is impossible by construction
## rather than by defect. The ruling's answer is that the compact card carries a SEPARATELY
## AUTHORED SUMMARY -- "a severity icon AND word, plus a short cause title" -- while "the exact
## detailed reason, validation code and recovery stay in the notice record". This file is that
## record and that authored table.
##
## ---------------------------------------------------------------------------------------
## NOTHING HERE SHORTENS A STRING. There is no ellipsis, no `substr`, no `left()`. A summary is
## an ENTRY IN `CATEGORY_TITLES`, written by hand against the condition it names, and
## `test_ui_notices.gd` measures every one of them in the real theme font against the real
## NARROW card interior. A title that does not fit is a title to be REWRITTEN -- that is what
## the ruling says, and it is the only reason a table of authored words is preferable to a
## formatting rule. The original message is never modified and never discarded: `notice_into()`
## returns it byte for byte alongside the summary.
##
## ---------------------------------------------------------------------------------------
## STORAGE IS COLUMNS, ALLOCATED ONCE. Each notice is an index into parallel packed columns, not
## an object; `_init()` sizes every column to §7's history cap and nothing resizes afterwards.
## This is presentation state and never decides a gameplay outcome, so no integer here is
## authoritative; the columns are integers because that is what the data is.
##
## ---------------------------------------------------------------------------------------
## `Error` IS NOT ONE OF §7's FOUR SEVERITIES, AND IS RAISED RATHER THAN RECONCILED. §7's table
## lists INFO, ADVISORY, WARNING and CRITICAL. The ruling names severity `Error` in terms, for
## the generation failure, so `Error` exists here. Its RANK -- above WARNING, below CRITICAL --
## is a reading, not a quotation: §7 puts "save integrity failure" in CRITICAL and UI-SET-085
## sends critical integrity faults to the stop modal instead of this card, which leaves a failed
## action below CRITICAL and above a food warning. The ordering decides which card is shown
## first and nothing else. The specification owner owns the reconciliation; ADR 0076 records it.

const IntMath := preload("res://scripts/core/int_math.gd")

# --- severities ---------------------------------------------------------------------------------

const SEVERITY_INFO: int = 0
const SEVERITY_ADVISORY: int = 1
const SEVERITY_WARNING: int = 2
const SEVERITY_ERROR: int = 3
const SEVERITY_CRITICAL: int = 4
const SEVERITY_COUNT: int = 5

## §7: "Each notice includes severity word+icon". The WORD, so colour never states it alone.
const SEVERITY_WORDS: Array[String] = ["Info", "Advisory", "Warning", "Error", "Critical"]

## The ICON, from the authored set in `godot/ui/icons/`. That directory is asset-owned and no
## new glyph is drawn here, so ADVISORY and WARNING share the warning mark and ERROR and
## CRITICAL share the cancel mark; the WORD and the colour token separate them, which is what
## §7 requires. A severity-specific glyph for each of the five is an asset request, not a
## reason to ship a notice with no icon at all.
const SEVERITY_ICONS: Array[String] = [
	"res://ui/icons/check.svg",
	"res://ui/icons/warning.svg",
	"res://ui/icons/warning.svg",
	"res://ui/icons/cancel.svg",
	"res://ui/icons/cancel.svg",
]

## §2.1 colour token per severity: SUCCESS, MUTED, WARNING, DANGER, DANGER.
const SEVERITY_TOKENS: Array[int] = [7, 5, 8, 9, 9]

# --- authored categories ------------------------------------------------------------------------

## One row per condition this interface can actually raise. A category is chosen BY THE CALLER
## that knows the condition; nothing here inspects a message string to guess what happened.
const CATEGORY_SETTLEMENT_NOTICE: int = 0
const CATEGORY_SETTLEMENT_CREATED: int = 1
const CATEGORY_GENERATION_FAILED: int = 2
const CATEGORY_ACTION_REFUSED: int = 3
const CATEGORY_STOCK_EMPTY: int = 4
const CATEGORY_CLOCK_OVERLOAD: int = 5
const CATEGORY_NO_WORLD: int = 6
const CATEGORY_ROSTER_STALE: int = 7
const CATEGORY_COUNT: int = 8

## The authored compact titles. Every one is measured by the suite against the real NARROW card
## interior in the real theme font, with the widest possible count suffix appended. "Generation
## failed" and its `Error` severity are the ruling's own words and are not editable here.
const CATEGORY_TITLES: Array[String] = [
	"Settlement notice",
	"Settlement created",
	"Generation failed",
	"Action refused",
	"Stores empty",
	"Clock overloaded",
	"No world yet",
	"Resident is gone",
]

const CATEGORY_SEVERITY: Array[int] = [
	SEVERITY_INFO,
	SEVERITY_INFO,
	SEVERITY_ERROR,
	SEVERITY_ERROR,
	SEVERITY_WARNING,
	SEVERITY_WARNING,
	SEVERITY_ADVISORY,
	SEVERITY_ADVISORY,
]

# --- retention ------------------------------------------------------------------------------------

## §7: "History cap 500 evicts oldest resolved INFO first, then oldest resolved higher severity".
const HISTORY_CAP: int = 500
## The largest "+N" this presentation can print, which is the cap less the card itself.
const MAX_OTHER_COUNT: int = HISTORY_CAP - 1

## How the summary line is composed. Two separators and nothing else; no formatting rule here
## can shorten an authored title.
const SUMMARY_SEPARATOR: String = ": "
const COUNT_OPEN: String = " (+"
const COUNT_CLOSE: String = ")"

## The action the accessible description names, so the disclosure route is discoverable
## without a pointer and without a tooltip. The ruling requires it in terms.
const OPEN_DETAILS_ACTION: String = "Open alert details."

## Printed in the expanded view where the raising system published no recovery action. An honest
## statement of absence, never an invented instruction.
const NO_RECOVERY: String = "No recovery action is published for this notice."
const NO_SOURCE: String = "No source is published for this notice."
const NO_CODE: String = "No validation code is published for this notice."

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_CATEGORY: StringName = &"UI_NOTICE_UNKNOWN_CATEGORY"
const REFUSE_UNKNOWN_INDEX: StringName = &"UI_NOTICE_UNKNOWN_INDEX"
const REFUSE_UNKNOWN_SEVERITY: StringName = &"UI_NOTICE_UNKNOWN_SEVERITY"
const REFUSE_EMPTY_MESSAGE: StringName = &"UI_NOTICE_EMPTY_MESSAGE"
const REFUSE_NONE_ACTIVE: StringName = &"UI_NOTICE_NONE_ACTIVE"
## Every retained row is unresolved, so §7's two stated eviction tiers both select nothing. The
## push is refused rather than evicting by a rule the specification does not state.
const REFUSE_HISTORY_FULL: StringName = &"UI_NOTICE_HISTORY_FULL_NO_EVICTION_RULE"


class Notice:
	"""One notice, expanded. Reused by the caller; `notice_into()` never allocates a new one."""

	var index: int = -1
	var id: int = 0
	var category: int = CATEGORY_SETTLEMENT_NOTICE
	var severity: int = SEVERITY_INFO
	var severity_word: String = ""
	var icon_path: String = ""
	var color_token: int = 0
	var title: String = ""
	## The authored compact line: severity word, title, and the count of other active notices.
	var summary: String = ""
	## The ORIGINAL message, byte for byte. Never shortened and never replaced by the summary.
	var message: String = ""
	var source: String = ""
	var code: String = ""
	var recovery: String = ""
	var occurrences: int = 0
	var first_tick: int = 0
	var last_tick: int = 0
	var resolved: bool = false

	func reset() -> void:
		"""Return every field to its empty state so a refused read leaves no stale notice."""
		index = -1
		id = 0
		category = CATEGORY_SETTLEMENT_NOTICE
		severity = SEVERITY_INFO
		severity_word = ""
		icon_path = ""
		color_token = 0
		title = ""
		summary = ""
		message = ""
		source = ""
		code = ""
		recovery = ""
		occurrences = 0
		first_tick = 0
		last_tick = 0
		resolved = false


var _category: PackedInt32Array = PackedInt32Array()
var _severity: PackedInt32Array = PackedInt32Array()
var _id: PackedInt32Array = PackedInt32Array()
var _occurrences: PackedInt32Array = PackedInt32Array()
var _first_tick: PackedInt64Array = PackedInt64Array()
var _last_tick: PackedInt64Array = PackedInt64Array()
var _resolved: PackedByteArray = PackedByteArray()
var _message: PackedStringArray = PackedStringArray()
var _source: PackedStringArray = PackedStringArray()
var _code: PackedStringArray = PackedStringArray()
var _recovery: PackedStringArray = PackedStringArray()
var _used: int = 0
var _next_id: int = 1
## Scratch for `order_into()`, sized once so ordering the history allocates nothing.
var _taken: PackedByteArray = PackedByteArray()
var _last_refusal: StringName = REFUSE_NONE


func _init() -> void:
	"""Size every column to §7's history cap once, and prove the authored tables line up."""
	_category.resize(HISTORY_CAP)
	_severity.resize(HISTORY_CAP)
	_id.resize(HISTORY_CAP)
	_occurrences.resize(HISTORY_CAP)
	_first_tick.resize(HISTORY_CAP)
	_last_tick.resize(HISTORY_CAP)
	_resolved.resize(HISTORY_CAP)
	_message.resize(HISTORY_CAP)
	_source.resize(HISTORY_CAP)
	_code.resize(HISTORY_CAP)
	_recovery.resize(HISTORY_CAP)
	_taken.resize(HISTORY_CAP)
	_assert_contracts()


func _assert_contracts() -> void:
	"""Every authored category must name its own title and severity; every severity its word."""
	assert(CATEGORY_TITLES.size() == CATEGORY_COUNT,
		"every authored category must carry a compact title")
	assert(CATEGORY_SEVERITY.size() == CATEGORY_COUNT,
		"every authored category must name its severity")
	assert(SEVERITY_WORDS.size() == SEVERITY_COUNT and SEVERITY_ICONS.size() == SEVERITY_COUNT,
		"every severity must carry §7's word and icon")
	assert(SEVERITY_TOKENS.size() == SEVERITY_COUNT,
		"every severity must name its §2.1 colour token")


static func is_category(category: int) -> bool:
	"""True for one of the authored categories in `CATEGORY_TITLES`."""
	return category >= 0 and category < CATEGORY_COUNT


static func is_severity(severity: int) -> bool:
	"""True for one of the five severity words this presentation prints."""
	return severity >= 0 and severity < SEVERITY_COUNT


static func summary_line(category: int, other_active: int) -> String:
	"""The authored compact line for a category: "Warning: Stores empty (+3)".

	Callers validate the category first; `notice_into()` is the checked route. The count is the
	number of OTHER active notices, which §7 requires narrow to show beside its single card, and
	is clamped to the store's own cap so the widest line the suite measures is the widest line
	that can ever be drawn.
	"""
	var line: String = "%s%s%s" % [SEVERITY_WORDS[CATEGORY_SEVERITY[category]],
		SUMMARY_SEPARATOR, CATEGORY_TITLES[category]]
	if other_active <= 0:
		return line
	return "%s%s%d%s" % [line, COUNT_OPEN, mini(other_active, MAX_OTHER_COUNT), COUNT_CLOSE]


static func widest_summary_line() -> String:
	"""The longest line this table can ever print, for a measured fit test."""
	var widest: String = ""
	for category: int in CATEGORY_COUNT:
		var line: String = summary_line(category, MAX_OTHER_COUNT)
		if line.length() > widest.length():
			widest = line
	return widest


func push(category: int, message: String, source: String, code: String, recovery: String,
		tick: int) -> bool:
	"""Record one notice, or group it onto the row §7 says it belongs with.

	§7: "Repeated same code/source updates count/last-seen tick without replaying chime." A
	notice carrying a validation code groups on that code and its source; one without a code
	groups on its category and its exact message, so two different sentences never overwrite
	each other just because neither published a code.
	"""
	if not is_category(category):
		return _refuse(REFUSE_UNKNOWN_CATEGORY)
	if message.is_empty():
		return _refuse(REFUSE_EMPTY_MESSAGE)
	var existing: int = _group_index(category, message, source, code)
	if existing >= 0:
		return _regroup(existing, tick)
	if _used >= HISTORY_CAP and not _evict():
		return _refuse(REFUSE_HISTORY_FULL)
	return _append(category, message, source, code, recovery, tick)


func _append(category: int, message: String, source: String, code: String, recovery: String,
		tick: int) -> bool:
	"""Write one new row at the end of the columns. The caller has already made room."""
	var slot: int = _used
	_category[slot] = category
	_severity[slot] = CATEGORY_SEVERITY[category]
	_id[slot] = _next_id
	_occurrences[slot] = 1
	_first_tick[slot] = tick
	_last_tick[slot] = tick
	_resolved[slot] = 0
	_message[slot] = message
	_source[slot] = source
	_code[slot] = code
	_recovery[slot] = recovery
	_used += 1
	_next_id += 1
	_last_refusal = REFUSE_NONE
	return true


func _regroup(index: int, tick: int) -> bool:
	"""§7's repeat rule: raise the occurrence count and the last-seen tick, add no row."""
	_occurrences[index] += 1
	_last_tick[index] = tick
	_resolved[index] = 0
	_last_refusal = REFUSE_NONE
	return true


func _group_index(category: int, message: String, source: String, code: String) -> int:
	"""The row a repeat of this condition belongs to, or -1 when it is a new condition."""
	for index: int in _used:
		if _category[index] != category:
			continue
		if not code.is_empty():
			if _code[index] == code and _source[index] == source:
				return index
			continue
		if _code[index].is_empty() and _message[index] == message:
			return index
	return -1


func _evict() -> bool:
	"""§7's two stated tiers: the oldest RESOLVED INFO, then the oldest RESOLVED of any severity.

	The section states no third tier, and a store of 500 unresolved conditions has no entry
	either tier selects. Inventing one would silently drop a live condition, so this returns
	false and `push()` refuses with a named code instead.
	"""
	var victim: int = _oldest_resolved(SEVERITY_INFO)
	if victim < 0:
		victim = _oldest_resolved(-1)
	if victim < 0:
		return false
	for index: int in range(victim, _used - 1):
		_copy_row(index + 1, index)
	_used -= 1
	return true


func _oldest_resolved(severity: int) -> int:
	"""The earliest resolved row of one severity, or of any severity when given -1."""
	var best: int = -1
	for index: int in _used:
		if _resolved[index] == 0:
			continue
		if severity >= 0 and _severity[index] != severity:
			continue
		if best < 0 or _first_tick[index] < _first_tick[best]:
			best = index
	return best


func _copy_row(from_index: int, to_index: int) -> void:
	"""Move one row's every column down by one slot, for the eviction compaction."""
	_category[to_index] = _category[from_index]
	_severity[to_index] = _severity[from_index]
	_id[to_index] = _id[from_index]
	_occurrences[to_index] = _occurrences[from_index]
	_first_tick[to_index] = _first_tick[from_index]
	_last_tick[to_index] = _last_tick[from_index]
	_resolved[to_index] = _resolved[from_index]
	_message[to_index] = _message[from_index]
	_source[to_index] = _source[from_index]
	_code[to_index] = _code[from_index]
	_recovery[to_index] = _recovery[from_index]


func resolve(index: int) -> bool:
	"""Mark one condition resolved. It stays in the history; only its active state changes."""
	if index < 0 or index >= _used:
		return _refuse(REFUSE_UNKNOWN_INDEX)
	_resolved[index] = 1
	_last_refusal = REFUSE_NONE
	return true


func resolve_all() -> int:
	"""Mark every retained condition resolved. Returns how many were still active."""
	var changed: int = 0
	for index: int in _used:
		if _resolved[index] == 0:
			_resolved[index] = 1
			changed += 1
	_last_refusal = REFUSE_NONE
	return changed


func top_active() -> IntMath.IntResult:
	"""§7's first card: highest severity, then earliest first tick, then lowest notice id.

	Refuses when nothing is active. It never answers with index 0, which would be a real row.
	"""
	var best: int = -1
	for index: int in _used:
		if _resolved[index] == 1:
			continue
		if best < 0 or _precedes(index, best):
			best = index
	if best < 0:
		_refuse(REFUSE_NONE_ACTIVE)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, best)


func _precedes(index: int, other: int) -> bool:
	"""§7's card order: severity descending, then earliest tick, then notice id."""
	if _severity[index] != _severity[other]:
		return _severity[index] > _severity[other]
	if _first_tick[index] != _first_tick[other]:
		return _first_tick[index] < _first_tick[other]
	return _id[index] < _id[other]


func order_into(out: PackedInt32Array) -> int:
	"""Write every retained row into `out` in §7's display order. Returns how many were written.

	Active conditions come first in severity order, then resolved ones; a selection sort over a
	bounded presentation store, run when the notice set changes rather than per frame.
	"""
	var written: int = 0
	for index: int in _used:
		_taken[index] = 0
	while written < _used and written < out.size():
		var best: int = -1
		for index: int in _used:
			if _taken[index] == 1:
				continue
			if best < 0 or _ranks_before(index, best):
				best = index
		_taken[best] = 1
		out[written] = best
		written += 1
	_last_refusal = REFUSE_NONE
	return written


func _ranks_before(index: int, other: int) -> bool:
	"""Display rank: unresolved before resolved, then §7's severity/tick/id order."""
	if _resolved[index] != _resolved[other]:
		return _resolved[index] < _resolved[other]
	return _precedes(index, other)


func notice_into(index: int, other_active: int, out: Notice) -> bool:
	"""Expand one row into `out`: its authored summary AND its whole original content.

	Both halves travel together deliberately. The summary is what the compact card draws; the
	message, source, code and recovery are what the expanded view and the accessible description
	must carry, and no caller can obtain one without the other.
	"""
	out.reset()
	if index < 0 or index >= _used:
		return _refuse(REFUSE_UNKNOWN_INDEX)
	out.index = index
	out.id = _id[index]
	out.category = _category[index]
	out.severity = _severity[index]
	out.severity_word = SEVERITY_WORDS[out.severity]
	out.icon_path = SEVERITY_ICONS[out.severity]
	out.color_token = SEVERITY_TOKENS[out.severity]
	out.title = CATEGORY_TITLES[out.category]
	out.summary = summary_line(out.category, other_active)
	out.message = _message[index]
	out.source = _source[index]
	out.code = _code[index]
	out.recovery = _recovery[index]
	out.occurrences = _occurrences[index]
	out.first_tick = _first_tick[index]
	out.last_tick = _last_tick[index]
	out.resolved = _resolved[index] == 1
	_last_refusal = REFUSE_NONE
	return true


func detail_text(notice: Notice) -> String:
	"""The expanded disclosure for one notice: severity, whole message, source, code, recovery.

	The message appears here unaltered. An absent source, code or recovery is STATED, so a
	player reading the expanded view can tell "nothing was published" from "nothing happened".
	"""
	return "\n".join(PackedStringArray([
		"%s%s%s" % [notice.severity_word, SUMMARY_SEPARATOR, notice.title],
		notice.message,
		"Source: %s" % (notice.source if not notice.source.is_empty() else NO_SOURCE),
		"Code: %s" % (notice.code if not notice.code.is_empty() else NO_CODE),
		"Recovery: %s" % (notice.recovery if not notice.recovery.is_empty() else NO_RECOVERY),
		"Seen %d time(s); first at tick %d, last at tick %d." % [notice.occurrences,
			notice.first_tick, notice.last_tick],
	]))


func accessible_text(notice: Notice) -> String:
	"""The card's accessible description: severity, the FULL original message, and the action.

	The ruling: "The accessible card name/description exposes severity and the full original
	message with an `Open alert details` action, even when hover tooltips are disabled." The
	whole message is here, not the summary, because a tooltip alone is not an access path.
	"""
	return "%s. %s %s" % [notice.severity_word, notice.message, OPEN_DETAILS_ACTION]


func active_count() -> int:
	"""How many retained conditions are still unresolved."""
	var active: int = 0
	for index: int in _used:
		if _resolved[index] == 0:
			active += 1
	return active


func count() -> int:
	"""How many notices are retained, active and resolved together."""
	return _used


func capacity() -> int:
	"""§7's history cap, which every column was sized to once."""
	return HISTORY_CAP


func clear() -> void:
	"""Drop every retained notice. Used when a new world replaces the one they described."""
	_used = 0
	_last_refusal = REFUSE_NONE


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false. No notice is invented on refusal."""
	_last_refusal = code
	return false
