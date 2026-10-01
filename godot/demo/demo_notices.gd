extends RefCounted
## The live demo's ONE notice feed. Decision 0196 (live demo). Presentation only.
##
## WHY. The farm and the tunnel works each raised their warnings through UIManager.push_alert(), which
## records an uncategorised settlement notice that nothing ever resolves -- and the HUD's alert zone
## shows the two EARLIEST unresolved notices (UI §7: "at most 2 cards"). After two demo lines the cards
## were stuck on them and every later warning -- tonight's frost, a flooding tunnel -- went unseen.
## UI §7 keeps those cards for the settlement's own conditions; demo notices are not settlement
## conditions (the demo writes nothing into the simulation). So every demo notice -- farm, tunnels,
## weather, threats, the crew's reports -- is posted HERE instead, and nothing in the demo raises a
## HUD card any more. The HUD is not modified.
##
## WHAT AN ENTRY IS: the demo DATE it was posted at (demo_calendar.gd `date_text()`, the very string the
## HUD's date trigger shows), its source, its level (a NOTE, or a WARNING that asks for a response),
## the full text, and an optional short SUMMARY (the one-line form the tunnel works author, e.g.
## "Tunnel 1 flooded — pump it out"). Entries are kept newest last in a ring of CAPACITY rows sized
## once; the oldest goes when it is full. Readers: the news strip (demo/ui/demo_news_strip.gd, the
## newest few while fresh) and the bed and tunnel panels (their own source's latest lines).
##
## Real time, not demo time, decides freshness (`posted_msec`): a paused village still shows what was
## just said, and a warning does not vanish faster at 4x.
##
## REPEATS FOLD (decision 0210). A post that says exactly what the newest entry says -- the same source,
## level, text and summary -- is not a new row: the newest entry counts it (`repeats`), takes the new
## date and time, and reads "... (×3)". A clay seam gave "Tunnel 10: Good sticky clay..." three times in a
## row, one per metre cut; the strip showed nothing else. Anything said in between keeps them apart.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")

const SOURCE_FARM: int = 0
const SOURCE_TUNNELS: int = 1
const SOURCE_WEATHER: int = 2
const SOURCE_EVENTS: int = 3
const SOURCE_CREW: int = 4
const SOURCE_WOODS: int = 5
const SOURCE_WATER: int = 6
const SOURCE_NAMES: Array[String] = ["Farm", "Tunnels", "Weather", "Threat", "Crew", "Woods", "Water"]
const LEVEL_NOTE: int = 0
const LEVEL_WARNING: int = 1
## §7: "severity word+icon" -- the word, so colour never states the level alone.
const LEVEL_WORDS: Array[String] = ["", "Warning: "]
const CAPACITY: int = 128
const UNDATED: String = "—"

## The history's source filters (review F11: Farm, Woods, Tunnels, Water, Village). The village is the
## weather, the threats and the crew's own reports (dusk, beds, the farm crew's jobs).
const GROUP_FARM: int = 0
const GROUP_WOODS: int = 1
const GROUP_TUNNELS: int = 2
const GROUP_WATER: int = 3
const GROUP_VILLAGE: int = 4
const GROUP_NAMES: Array[String] = ["Farm", "Woods", "Tunnels", "Water", "Village"]
## Every group (a filter mask with all five bits set).
const ALL_GROUPS: int = 31
## SOURCE_* -> GROUP_*.
const SOURCE_GROUP: PackedByteArray = [GROUP_FARM, GROUP_TUNNELS, GROUP_VILLAGE, GROUP_VILLAGE, GROUP_VILLAGE,
	GROUP_WOODS, GROUP_WATER]
## The history's severity filter.
const SHOW_ALL: int = 0
const SHOW_WARNINGS: int = 1
const SHOW_NOTES: int = 2
const SHOW_NAMES: Array[String] = ["All", "Warnings", "Notes"]

## What an entry is about, for the history's "Go to" (demo/ui/demo_news_jump.gd).
const TARGET_NONE: int = 0
const TARGET_BED: int = 1
const TARGET_TREE: int = 2
const TARGET_TUNNEL: int = 3
const TARGET_RESIDENT: int = 4
const TARGET_BRIDGE: int = 5
const TARGET_NAMES: Array[String] = ["", "bed", "tree", "tunnel", "resident", "bridge"]
const NO_INCIDENT: int = -1

## Bumped by every post.
var revision: int = 0
## Rows ever written: bumped by every post that is not folded into the newest (a reader counts new rows by it;
## the demo's sound, decision 0351).
var rows_posted: int = 0

var _calendar: CalendarScript = null
var _clock: NewsClockScript = null
## `(serial: int) -> bool`: whether an incident is still unresolved or pinned (demo_incidents.gd `holds`).
var _holds: Callable = Callable()
## Columns, oldest entry first, at most CAPACITY long.
var _stamp: PackedStringArray = PackedStringArray()
var _text: PackedStringArray = PackedStringArray()
var _summary: PackedStringArray = PackedStringArray()
var _source: PackedByteArray = PackedByteArray()
var _level: PackedByteArray = PackedByteArray()
var _posted_msec: PackedInt64Array = PackedInt64Array()
## How many times each entry was said in a row (1: once; see REPEATS FOLD).
var _repeats: PackedInt32Array = PackedInt32Array()
var _target_kind: PackedByteArray = PackedByteArray()
var _target_id: PackedInt32Array = PackedInt32Array()
## The incident serial an entry reports (NO_INCIDENT: none).
var _incident: PackedInt32Array = PackedInt32Array()


func bind_calendar(calendar: CalendarScript) -> void:
	"""Stamp entries with this calendar's date (unbound: UNDATED)."""
	_calendar = calendar


func bind_clock(clock: NewsClockScript) -> void:
	"""Time entries on this news clock (paused time not counted); unbound, on real time."""
	_clock = clock


func bind_holds(holds: Callable) -> void:
	"""`holds(serial) -> bool`: the incidents whose newest entry overflow must keep (see THE HISTORY)."""
	_holds = holds


func now_msec() -> int:
	"""The time entries are posted at: the news clock's when bound, else real milliseconds."""
	return _clock.now_msec() if _clock != null else Time.get_ticks_msec()


func post(from_source: int, at_level: int, message: String, brief: String = "", to_kind: int = TARGET_NONE,
		to_id: int = -1, serial: int = NO_INCIDENT) -> bool:
	"""Add one notice, stamped with the demo date now -- or, when it repeats the newest entry, count it there
	(see REPEATS FOLD). `to_kind` / `to_id` name its target (TARGET_*), `serial` the incident it reports. Refuses
	(false, nothing kept) an empty message, or a source, level or target outside SOURCE_* / LEVEL_* / TARGET_*."""
	if message.is_empty() or from_source < 0 or from_source >= SOURCE_NAMES.size() or at_level < LEVEL_NOTE \
			or at_level > LEVEL_WARNING or to_kind < TARGET_NONE or to_kind >= TARGET_NAMES.size():
		return false
	var row: int = _row(0)
	if _source.size() > 0 and repeats_newest(from_source, at_level, message, brief) and _target_kind[row] == to_kind \
			and _target_id[row] == to_id and _incident[row] == serial:
		_repeats[row] += 1
	else:
		if _source.size() >= CAPACITY:
			_remove(_victim())
		_append(from_source, at_level, message, brief, to_kind, to_id, serial)
		row = _source.size() - 1
		rows_posted += 1
	_stamp[row] = _calendar.date_text() if _calendar != null else UNDATED
	_posted_msec[row] = now_msec()
	revision += 1
	return true


func _append(from_source: int, at_level: int, message: String, brief: String, to_kind: int, to_id: int,
		serial: int) -> void:
	"""One new newest entry (stamped and timed by `post`)."""
	_stamp.append(UNDATED)
	_text.append(message)
	_summary.append(brief)
	_source.append(from_source)
	_level.append(at_level)
	_posted_msec.append(0)
	_repeats.append(1)
	_target_kind.append(to_kind)
	_target_id.append(to_id)
	_incident.append(serial)


func _remove(i: int) -> void:
	"""Drop the entry at storage index `i` (0: the oldest)."""
	for column: PackedStringArray in [_stamp, _text, _summary]:
		column.remove_at(i)
	_source.remove_at(i)
	_level.remove_at(i)
	_posted_msec.remove_at(i)
	_repeats.remove_at(i)
	_target_kind.remove_at(i)
	_target_id.remove_at(i)
	_incident.remove_at(i)


func _victim() -> int:
	"""The storage index overflow lets go (see THE HISTORY): the oldest entry that is not an unresolved or
	pinned incident's newest; the oldest of all if every one is."""
	for i: int in _source.size():
		if not _held(i):
			return i
	return 0


func _held(i: int) -> bool:
	"""Whether storage index `i` is the newest entry of an incident still held."""
	var serial: int = _incident[i]
	if serial == NO_INCIDENT or not _holds.is_valid() or not bool(_holds.call(serial)):
		return false
	for j: int in range(i + 1, _source.size()):
		if _incident[j] == serial:
			return false
	return true


func repeats_newest(from_source: int, at_level: int, message: String, brief: String) -> bool:
	"""Whether a post says exactly what the newest entry says (see REPEATS FOLD). An empty feed has no newest
	entry, so the first post never matches."""
	if _source.is_empty():
		return false
	var newest: int = _row(0)
	return _source[newest] == from_source and _level[newest] == at_level and _text[newest] == message \
			and _summary[newest] == brief


func poster(from_source: int, at_level: int) -> Callable:
	"""A `(message: String) -> void` that posts at this source and level (for a module's notice hook)."""
	return func(message: String) -> void: post(from_source, at_level, message)


func count() -> int:
	"""How many entries are kept (at most CAPACITY)."""
	return _source.size()


func _row(k: int) -> int:
	"""The storage index of entry `k`, 0 being the newest."""
	return _source.size() - 1 - k


func text(k: int) -> String:
	"""Entry `k`'s full text (0: newest)."""
	return _text[_row(k)]


func summary(k: int) -> String:
	"""Entry `k`'s short summary ("" when none was authored)."""
	return _summary[_row(k)]


func stamp(k: int) -> String:
	"""Entry `k`'s demo date."""
	return _stamp[_row(k)]


func source(k: int) -> int:
	"""Entry `k`'s SOURCE_*."""
	return _source[_row(k)]


func level(k: int) -> int:
	"""Entry `k`'s LEVEL_*."""
	return _level[_row(k)]


func repeats(k: int) -> int:
	"""How many times entry `k` was said in a row (1: once)."""
	return _repeats[_row(k)]


func target_kind(k: int) -> int:
	"""Entry `k`'s TARGET_* (TARGET_NONE: nothing to go to)."""
	return _target_kind[_row(k)]


func target_id(k: int) -> int:
	"""Entry `k`'s target id (a bed, tree, tunnel slot, resident or bridge row; -1 with no target)."""
	return _target_id[_row(k)]


func incident(k: int) -> int:
	"""The incident serial entry `k` reports (NO_INCIDENT: none)."""
	return _incident[_row(k)]


func group(k: int) -> int:
	"""Entry `k`'s history filter group (GROUP_*)."""
	return SOURCE_GROUP[source(k)]


func matches(k: int, group_mask: int, show: int) -> bool:
	"""Whether entry `k` passes the history's filters: its group's bit set in `group_mask`, and its level
	wanted by `show` (SHOW_*)."""
	if group_mask & (1 << group(k)) == 0:
		return false
	return show == SHOW_ALL or (show == SHOW_WARNINGS) == (level(k) == LEVEL_WARNING)


func filtered_into(group_mask: int, show: int, out: PackedInt32Array) -> int:
	"""Fill `out` with the entries passing the filters (`matches`), newest first; returns how many."""
	out.clear()
	for k: int in count():
		if matches(k, group_mask, show):
			out.append(k)
	return out.size()


func _times(k: int) -> String:
	"""" (×3)" after an entry said three times in a row; "" after one said once."""
	return " (×%d)" % repeats(k) if repeats(k) > 1 else ""


func age_msec(k: int, now: int) -> int:
	"""How long ago entry `k` was posted, in the milliseconds `now` is in (`now_msec()`'s)."""
	return now - _posted_msec[_row(k)]


func line(k: int) -> String:
	"""Entry `k` as one readable line: 'Y1 Spring 3, 14:00 · Warning: Frost tonight! …'."""
	return "%s · %s%s%s" % [stamp(k), LEVEL_WORDS[level(k)], text(k), _times(k)]


func short_line(k: int) -> String:
	"""Entry `k` in its short form: its summary when one was authored, else its text."""
	var shown: String = summary(k) if not summary(k).is_empty() else text(k)
	return "%s · %s%s%s" % [stamp(k), LEVEL_WORDS[level(k)], shown, _times(k)]


func latest_of_into(wanted_source: int, most: int, out: PackedStringArray) -> int:
	"""Append the newest `most` full lines from one source to `out`, newest first; returns how many."""
	var found: int = 0
	for k: int in count():
		if found >= most:
			break
		if source(k) == wanted_source:
			out.append(line(k))
			found += 1
	return found


func has_summary(wanted: String) -> bool:
	"""Whether any kept entry carries this summary (checks)."""
	for k: int in count():
		if summary(k) == wanted:
			return true
	return false


func has_text(wanted: String) -> bool:
	"""Whether any kept entry carries this full text (checks)."""
	for k: int in count():
		if text(k) == wanted:
			return true
	return false
