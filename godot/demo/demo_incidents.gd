extends RefCounted
## The live demo's INCIDENTS: unresolved, actionable conditions that stay until they resolve or the player
## acknowledges them. Decision 0331 (review UX-011, F11, F37). Presentation only: it reads the modules'
## state through the watches they hand it and writes nothing back.
##
## WHY. A notice is a dated line that says something happened; it scrolls away. A waterlogged bed, a
## flooded tunnel or a resident in difficulty is not something that happened once but something that is
## still TRUE until somebody deals with it. The feed (demo_notices.gd) had only the first kind, so the
## truth went with the toast. An incident is the second kind -- UI §7's "active-condition store".
##
## WHAT AN INCIDENT IS: a KEY naming the condition ("farm:wet:1", "tunnel:flooded:4:2", "water:rescue:7"),
## its source (demo_notices.gd SOURCE_*), a SEVERITY (ROUTINE, WARNING or CRITICAL), its STATE (needs a
## decision, assigned, recovering, resolved), its latest text and date, a jump TARGET (demo_notices.gd
## TARGET_*), and how many times it has been raised (COUNT). Rows are packed columns, MAX_INCIDENTS of
## them; an incident is named outside by its SERIAL, which no other incident ever reuses.
##
## RAISING (`raise`, or `report`, which also posts the feed line).
##   * Raised while still unresolved: a REPEAT. It MERGES into the same card -- the count goes up, the text
##     and date are the newest -- and is not announced again (UI §7: "Repeated same code/source updates
##     count/last-seen tick without replaying chime"). An acknowledged card stays acknowledged.
##   * Raised after it RESOLVED: a RECURRENCE (review F37: wet, drained, wet again). The same card comes
##     back needing a decision, its count up, unacknowledged and unsnoozed, and it IS announced again.
##   * The source decides what "resolved" means and any cooldown before a recurrence counts (farm_alerts.gd
##     STANDING CONDITIONS waits REARM_HOURS of the condition being gone).
## STATE. A source may hand `raise` a WATCH, `() -> int`, which `sweep()` asks a few times a second for the
## incident's state now: a Drain job queued is ASSIGNED, a victim being towed RECOVERING; RESOLVED resolves
## it. Or the source says so itself (`update`, `resolve`).
##
## WHO SEES WHAT (demo/ui/demo_incident_cards.gd, demo/ui/demo_news_history.gd, demo/ui/demo_news_strip.gd):
##   * CRITICAL incidents QUEUE in the top-centre alert zone, ONE card drawn, "1 of 3" -- not the old two
##     HUD cards for good (decision 0196) -- until resolved (then RESOLVED_LINGER_MSEC more, saying so), or
##     acknowledged, or while snoozed. A PINNED card of any severity joins the front of that queue and stays,
##     resolved or not, until unpinned or dismissed.
##   * ROUTINE and WARNING incidents go to the history's "Needs attention" list, and the news strip counts
##     every unresolved one (UI §7's "badge persists until resolved").
## Snoozes and lingers run on the news clock (demo_news_clock.gd): they do not count down while paused.
##
## THE SOUND HOOK. `incident_cue(cue, serial, severity)` is emitted when a CRITICAL incident is raised or
## recurs (CUE_CRITICAL_RAISED) and when any incident resolves (CUE_RESOLVED) -- once each, never for a
## merged repeat. It is a UI signal for a cue (review group R); nothing in the game listens to it.

const NoticesScript := preload("res://demo/demo_notices.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")

## A critical incident was raised or came back (CUE_CRITICAL_RAISED), or an incident resolved (CUE_RESOLVED).
signal incident_cue(cue: int, serial: int, severity: int)

const CUE_CRITICAL_RAISED: int = 0
const CUE_RESOLVED: int = 1

const SEVERITY_ROUTINE: int = 0
const SEVERITY_WARNING: int = 1
const SEVERITY_CRITICAL: int = 2
const SEVERITY_WORDS: Array[String] = ["Routine", "Warning", "Critical"]

const STATE_NEEDS_DECISION: int = 0
const STATE_ASSIGNED: int = 1
const STATE_RECOVERING: int = 2
const STATE_RESOLVED: int = 3
const STATE_WORDS: Array[String] = ["Needs a decision", "Assigned", "Recovering", "Resolved"]

## What the last `raise` did.
const RAISE_REFUSED: int = -1
const RAISE_NEW: int = 0
const RAISE_AGAIN: int = 1
const RAISE_MERGED: int = 2

const MAX_INCIDENTS: int = 48
const NO_SERIAL: int = -1
## A resolved critical card's last look in the queue, saying "Resolved", in news-clock milliseconds.
const RESOLVED_LINGER_MSEC: int = 6000
## The cards' Snooze: two minutes of unpaused real time.
const SNOOZE_MSEC: int = 120000

## Bumped by every change a reader would draw.
var revision: int = 0
## RAISE_* of the most recent `raise`.
var last_raise: int = RAISE_REFUSED
## Incidents raised new or come back so far (a merged repeat is not counted): what "Run until the next warning or
## incident" watches (decision 0471). Only ever counts up.
var occurrences: int = 0

var _clock: NewsClockScript = null
var _calendar: CalendarScript = null
var _feed: NoticesScript = null
var _next_serial: int = 1
var _used: PackedByteArray = PackedByteArray()
var _serial: PackedInt32Array = PackedInt32Array()
var _key: PackedStringArray = PackedStringArray()
var _text: PackedStringArray = PackedStringArray()
var _stamp: PackedStringArray = PackedStringArray()
var _source: PackedByteArray = PackedByteArray()
var _severity: PackedByteArray = PackedByteArray()
var _state: PackedByteArray = PackedByteArray()
var _target_kind: PackedByteArray = PackedByteArray()
var _target_id: PackedInt32Array = PackedInt32Array()
var _count: PackedInt32Array = PackedInt32Array()
var _pinned: PackedByteArray = PackedByteArray()
var _acked: PackedByteArray = PackedByteArray()
var _snoozed_until: PackedInt64Array = PackedInt64Array()
## News-clock time of the latest occurrence (not of a merged repeat), and of the resolution.
var _raised_msec: PackedInt64Array = PackedInt64Array()
var _resolved_msec: PackedInt64Array = PackedInt64Array()
var _watch: Array[Callable] = []
## Scratch rows for ordering a list (reused).
var _rows: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""Size every column once."""
	for column: PackedStringArray in [_key, _text, _stamp]:
		column.resize(MAX_INCIDENTS)
	for column: PackedByteArray in [_used, _source, _severity, _state, _target_kind, _pinned, _acked]:
		column.resize(MAX_INCIDENTS)
	for column: PackedInt32Array in [_serial, _target_id, _count]:
		column.resize(MAX_INCIDENTS)
	for column: PackedInt64Array in [_snoozed_until, _raised_msec, _resolved_msec]:
		column.resize(MAX_INCIDENTS)
	_watch.resize(MAX_INCIDENTS)


func bind(feed: NoticesScript, calendar: CalendarScript, clock: NewsClockScript) -> void:
	"""Post through this feed (`report`), date by this calendar and time by this news clock; and have the feed
	keep each unresolved or pinned incident's newest entry when it overflows."""
	_feed = feed
	_calendar = calendar
	_clock = clock
	if feed != null:
		feed.bind_holds(holds)


func now_msec() -> int:
	"""The news clock's time (0 unbound: then nothing lingers or wakes on its own)."""
	return _clock.now_msec() if _clock != null else 0


# --- raising and resolving ---------------------------------------------------------------------------

func raise(key: String, source: int, severity: int, text: String, target_kind: int = NoticesScript.TARGET_NONE,
		target_id: int = -1, watch: Callable = Callable()) -> int:
	"""Raise the condition `key` (see RAISING); returns its serial (NO_SERIAL, nothing kept, for an empty key or
	text, a source or severity out of range, or no free row). `last_raise` says whether it was new, a
	recurrence or a merged repeat."""
	last_raise = RAISE_REFUSED
	if key.is_empty() or text.is_empty() or source < 0 or source >= NoticesScript.SOURCE_NAMES.size() \
			or severity < SEVERITY_ROUTINE or severity > SEVERITY_CRITICAL:
		return NO_SERIAL
	var row: int = _row_of_key(key)
	if row >= 0 and _state[row] != STATE_RESOLVED:
		last_raise = RAISE_MERGED
	elif row >= 0:
		last_raise = RAISE_AGAIN
		_reopen(row)
	else:
		row = _free_row()
		if row < 0:
			return NO_SERIAL
		last_raise = RAISE_NEW
		_open(row, key, source)
	_count[row] += 1
	_set_details(row, severity, text, target_kind, target_id, watch)
	revision += 1
	if last_raise != RAISE_MERGED:
		occurrences += 1
	if last_raise != RAISE_MERGED and severity == SEVERITY_CRITICAL:
		incident_cue.emit(CUE_CRITICAL_RAISED, _serial[row], severity)
	return _serial[row]


func _open(row: int, key: String, source: int) -> void:
	"""A fresh incident in a free row."""
	_used[row] = 1
	_serial[row] = _next_serial
	_next_serial += 1
	_key[row] = key
	_source[row] = source
	_count[row] = 0
	_pinned[row] = 0
	_reopen(row)


func _reopen(row: int) -> void:
	"""A new occurrence: needing a decision, unacknowledged, unsnoozed, raised now."""
	_state[row] = STATE_NEEDS_DECISION
	_acked[row] = 0
	_snoozed_until[row] = 0
	_raised_msec[row] = now_msec()


func _set_details(row: int, severity: int, text: String, target_kind: int, target_id: int, watch: Callable) -> void:
	"""The latest occurrence's words, date, severity, target and watch (a new occurrence takes the watch it is
	given, none included: a reused row never keeps another incident's; a merged repeat keeps its watch unless given
	one)."""
	_severity[row] = severity
	_text[row] = text
	_stamp[row] = _calendar.date_text() if _calendar != null else NoticesScript.UNDATED
	_target_kind[row] = clampi(target_kind, NoticesScript.TARGET_NONE, NoticesScript.TARGET_NAMES.size() - 1)
	_target_id[row] = target_id
	if watch.is_valid() or last_raise != RAISE_MERGED:
		_watch[row] = watch


func report(key: String, source: int, severity: int, text: String, summary: String = "",
		target_kind: int = NoticesScript.TARGET_NONE, target_id: int = -1, watch: Callable = Callable()) -> int:
	"""`raise`, and post its line to the bound feed with its target and serial (a WARNING unless routine) --
	a merged repeat too, so the history keeps every date it was said. Refused by a full table, the line is still
	posted (with no incident): a warning is never lost because the incidents are. The line's tier is the severity's
	(`tier_of`), its kind and subject the key's (`kind_of_key`, `subject_of_key`; decision 0591). Returns the
	serial."""
	var serial: int = raise(key, source, severity, text, target_kind, target_id, watch)
	if serial == NO_SERIAL:
		push_warning("incident table full or raise refused: %s" % key)
	if _feed != null:
		var level: int = NoticesScript.LEVEL_NOTE if severity == SEVERITY_ROUTINE else NoticesScript.LEVEL_WARNING
		_feed.post(source, level, text, summary, target_kind, target_id, serial, tier_of(severity),
			StringName(kind_of_key(key)), subject_of_key(key))
	return serial


static func tier_of(severity: int) -> int:
	"""The feed tier an incident's line takes (decision 0591): critical is urgent, warning normal, routine info."""
	if severity == SEVERITY_CRITICAL:
		return NoticesScript.TIER_URGENT
	return NoticesScript.TIER_NORMAL if severity == SEVERITY_WARNING else NoticesScript.TIER_INFO


static func kind_of_key(key: String) -> String:
	"""A key's KIND: its words up to the first whole number ("tunnel:flooded:4:2" -> "tunnel:flooded")."""
	var cut: int = _number_at(key)
	return key if cut < 0 else key.substr(0, maxi(cut - 1, 0))


static func subject_of_key(key: String) -> String:
	"""A key's SUBJECT: its words from the first whole number on ("tunnel:flooded:4:2" -> "4:2"; "" with none)."""
	var cut: int = _number_at(key)
	return "" if cut < 0 else key.substr(cut)


static func _number_at(key: String) -> int:
	"""Where a key's first all-digit part starts (-1: none)."""
	var at: int = 0
	for part: String in key.split(":"):
		if part.is_valid_int():
			return at
		at += part.length() + 1
	return -1


func resolve(key: String) -> bool:
	"""The condition `key` is over: RESOLVED now (false when there is no such unresolved incident)."""
	return _resolve_row(_row_of_key(key))


func _resolve_row(row: int) -> bool:
	"""Resolve the incident in `row`, once, and cue it."""
	if row < 0 or _state[row] == STATE_RESOLVED:
		return false
	_state[row] = STATE_RESOLVED
	_resolved_msec[row] = now_msec()
	revision += 1
	incident_cue.emit(CUE_RESOLVED, _serial[row], _severity[row])
	return true


func update(key: String, state: int, text: String = "") -> bool:
	"""The source's own word on an unresolved incident: its STATE_* now (RESOLVED resolves it), and its
	text in place when given. False when there is no such unresolved incident."""
	var row: int = _row_of_key(key)
	if row < 0 or _state[row] == STATE_RESOLVED or state < STATE_NEEDS_DECISION or state > STATE_RESOLVED:
		return false
	if not text.is_empty() and text != _text[row]:
		_text[row] = text
		revision += 1
	if state == STATE_RESOLVED:
		return _resolve_row(row)
	if state != _state[row]:
		_state[row] = state
		revision += 1
	return true


func sweep() -> int:
	"""Ask every unresolved incident's watch for its state now (see STATE); returns how many changed."""
	var changed: int = 0
	for row: int in MAX_INCIDENTS:
		if _used[row] == 0 or _state[row] == STATE_RESOLVED or not _watch[row].is_valid():
			continue
		var state: int = int(_watch[row].call())
		if state == _state[row] or state < STATE_NEEDS_DECISION or state > STATE_RESOLVED:
			continue
		if state == STATE_RESOLVED:
			_resolve_row(row)
		else:
			_state[row] = state
			revision += 1
		changed += 1
	return changed


# --- the player's verbs -------------------------------------------------------------------------------

func acknowledge(serial: int) -> bool:
	"""Dismiss a card: out of the queue (and unpinned) until its condition resolves and comes back. An
	unresolved one stays in the history's list and the strip's count."""
	var row: int = row_of(serial)
	if row < 0:
		return false
	_acked[row] = 1
	_pinned[row] = 0
	revision += 1
	return true


func pin(serial: int, on: bool) -> bool:
	"""Pin a card to the front of the queue (it stays, resolved or not), or unpin it."""
	var row: int = row_of(serial)
	if row < 0:
		return false
	_pinned[row] = 1 if on else 0
	if on:
		_acked[row] = 0
	revision += 1
	return true


func snooze(serial: int, msec: int = SNOOZE_MSEC) -> bool:
	"""Hide a card from the queue for `msec` of the news clock; it comes back if still unresolved (or pinned)."""
	var row: int = row_of(serial)
	if row < 0 or msec <= 0:
		return false
	_snoozed_until[row] = now_msec() + msec
	revision += 1
	return true


# --- reading ------------------------------------------------------------------------------------------

func holds(serial: int) -> bool:
	"""Whether an incident is still unresolved or pinned (what feed overflow keeps)."""
	var row: int = row_of(serial)
	return row >= 0 and (_state[row] != STATE_RESOLVED or _pinned[row] == 1)


func row_of(serial: int) -> int:
	"""The row incident `serial` lives in (-1: none, or its row reused)."""
	if serial == NO_SERIAL:
		return -1
	for row: int in MAX_INCIDENTS:
		if _used[row] == 1 and _serial[row] == serial:
			return row
	return -1


func serial_of(key: String) -> int:
	"""The serial of the incident named `key` (NO_SERIAL: none)."""
	var row: int = _row_of_key(key)
	return _serial[row] if row >= 0 else NO_SERIAL


func _row_of_key(key: String) -> int:
	"""The row of the incident named `key` (-1: none)."""
	for row: int in MAX_INCIDENTS:
		if _used[row] == 1 and _key[row] == key:
			return row
	return -1


func _free_row() -> int:
	"""An unused row, else the row of the incident resolved longest ago and not pinned (-1: none)."""
	var best: int = -1
	for row: int in MAX_INCIDENTS:
		if _used[row] == 0:
			return row
		if _state[row] == STATE_RESOLVED and _pinned[row] == 0 \
				and (best < 0 or _resolved_msec[row] < _resolved_msec[best]):
			best = row
	return best


func is_unresolved(serial: int) -> bool:
	"""Whether incident `serial` is still open."""
	var row: int = row_of(serial)
	return row >= 0 and _state[row] != STATE_RESOLVED


func unresolved_count() -> int:
	"""How many open incidents still ask for attention (the strip's count; see `_needs_attention`)."""
	var n: int = 0
	for row: int in MAX_INCIDENTS:
		n += 1 if _needs_attention(row) else 0
	return n


func _needs_attention(row: int) -> bool:
	"""Whether `row` holds an open incident still asking for attention: a dismissed ROUTINE one does not (UI §7:
	an advisory's acknowledgement hides it until the condition changes); a dismissed warning or critical one does
	until it resolves (the badge persists)."""
	return _used[row] == 1 and _state[row] != STATE_RESOLVED \
		and not (_acked[row] == 1 and _severity[row] == SEVERITY_ROUTINE)


func in_queue(serial: int) -> bool:
	"""Whether a card for `serial` is in the top-centre queue now (see WHO SEES WHAT)."""
	var row: int = row_of(serial)
	if row < 0 or _snoozed_until[row] > now_msec():
		return false
	if _pinned[row] == 1:
		return true
	if _acked[row] == 1 or _severity[row] != SEVERITY_CRITICAL:
		return false
	return _state[row] != STATE_RESOLVED or now_msec() - _resolved_msec[row] <= RESOLVED_LINGER_MSEC


func queue_into(out: PackedInt32Array) -> int:
	"""Fill `out` with the queued cards' serials, front first: pinned, then by severity, then the earliest
	raised, then the oldest serial. Returns how many."""
	_rows.clear()
	for row: int in MAX_INCIDENTS:
		if _used[row] == 1 and in_queue(_serial[row]):
			_insert_sorted(row)
	return _serials_into(out)


func attention_into(out: PackedInt32Array) -> int:
	"""Fill `out` with the history's "Needs attention" list: every open incident still asking for attention and
	every pinned one, in the queue's order. Returns how many."""
	_rows.clear()
	for row: int in MAX_INCIDENTS:
		if _needs_attention(row) or (_used[row] == 1 and _pinned[row] == 1):
			_insert_sorted(row)
	return _serials_into(out)


func _insert_sorted(row: int) -> void:
	"""Insert `row` into the scratch rows in the queue's order."""
	var at: int = _rows.size()
	while at > 0 and _before(row, _rows[at - 1]):
		at -= 1
	_rows.insert(at, row)


func _serials_into(out: PackedInt32Array) -> int:
	"""Copy the scratch rows' serials into `out`; returns how many."""
	out.clear()
	for row: int in _rows:
		out.append(_serial[row])
	return out.size()


func _before(a: int, b: int) -> bool:
	"""Whether row `a` comes before row `b` in the queue."""
	if _pinned[a] != _pinned[b]:
		return _pinned[a] > _pinned[b]
	if _severity[a] != _severity[b]:
		return _severity[a] > _severity[b]
	if _raised_msec[a] != _raised_msec[b]:
		return _raised_msec[a] < _raised_msec[b]
	return _serial[a] < _serial[b]


func key_of(serial: int) -> String:
	"""Incident `serial`'s key ("" when gone)."""
	var row: int = row_of(serial)
	return _key[row] if row >= 0 else ""


func text_of(serial: int) -> String:
	"""Incident `serial`'s latest text ("" when gone)."""
	var row: int = row_of(serial)
	return _text[row] if row >= 0 else ""


func stamp_of(serial: int) -> String:
	"""The demo date incident `serial` was last raised."""
	var row: int = row_of(serial)
	return _stamp[row] if row >= 0 else NoticesScript.UNDATED


func state_of(serial: int) -> int:
	"""Incident `serial`'s STATE_* (RESOLVED when gone)."""
	var row: int = row_of(serial)
	return _state[row] if row >= 0 else STATE_RESOLVED


func severity_of(serial: int) -> int:
	"""Incident `serial`'s SEVERITY_*."""
	var row: int = row_of(serial)
	return _severity[row] if row >= 0 else SEVERITY_ROUTINE


func source_of(serial: int) -> int:
	"""Incident `serial`'s demo_notices.gd SOURCE_*."""
	var row: int = row_of(serial)
	return _source[row] if row >= 0 else NoticesScript.SOURCE_CREW


func count_of(serial: int) -> int:
	"""How many times incident `serial` has been raised (merged repeats and recurrences; 0 when gone)."""
	var row: int = row_of(serial)
	return _count[row] if row >= 0 else 0


func target_kind_of(serial: int) -> int:
	"""Incident `serial`'s demo_notices.gd TARGET_*."""
	var row: int = row_of(serial)
	return _target_kind[row] if row >= 0 else NoticesScript.TARGET_NONE


func target_id_of(serial: int) -> int:
	"""Incident `serial`'s target id (-1: none)."""
	var row: int = row_of(serial)
	return _target_id[row] if row >= 0 else -1


func is_pinned(serial: int) -> bool:
	"""Whether incident `serial` is pinned."""
	var row: int = row_of(serial)
	return row >= 0 and _pinned[row] == 1


func is_acknowledged(serial: int) -> bool:
	"""Whether incident `serial` was dismissed for this occurrence."""
	var row: int = row_of(serial)
	return row >= 0 and _acked[row] == 1


func can_queue(serial: int) -> bool:
	"""Whether incident `serial` is one the top-centre card would show (critical, or pinned): what Snooze is for."""
	var row: int = row_of(serial)
	return row >= 0 and (_severity[row] == SEVERITY_CRITICAL or _pinned[row] == 1)


func is_snoozed(serial: int) -> bool:
	"""Whether incident `serial` is snoozed now."""
	var row: int = row_of(serial)
	return row >= 0 and _snoozed_until[row] > now_msec()


func card_title(serial: int) -> String:
	"""'Critical · Water · Needs a decision (×2)': severity WORD (colour never says it alone), source,
	state, and the count when raised more than once."""
	var row: int = row_of(serial)
	if row < 0:
		return ""
	var times: String = " (×%d)" % _count[row] if _count[row] > 1 else ""
	return "%s · %s · %s%s" % [SEVERITY_WORDS[_severity[row]], NoticesScript.SOURCE_NAMES[_source[row]],
		STATE_WORDS[_state[row]], times]
