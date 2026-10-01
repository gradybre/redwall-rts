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
const CAPACITY: int = 32
const UNDATED: String = "—"

## Bumped by every post.
var revision: int = 0
## Rows ever written: bumped by every post that is not folded into the newest (a reader counts new rows by it;
## the demo's sound, decision 0351).
var rows_posted: int = 0

var _calendar: CalendarScript = null
var _stamp: PackedStringArray = PackedStringArray()
var _text: PackedStringArray = PackedStringArray()
var _summary: PackedStringArray = PackedStringArray()
var _source: PackedByteArray = PackedByteArray()
var _level: PackedByteArray = PackedByteArray()
var _posted_msec: PackedInt64Array = PackedInt64Array()
## How many times each entry was said in a row (1: once; see REPEATS FOLD).
var _repeats: PackedInt32Array = PackedInt32Array()
var _count: int = 0
## The row the next post writes.
var _head: int = 0


func _init() -> void:
	"""Size the ring once."""
	for column: PackedStringArray in [_stamp, _text, _summary]:
		column.resize(CAPACITY)
	_source.resize(CAPACITY)
	_level.resize(CAPACITY)
	_posted_msec.resize(CAPACITY)
	_repeats.resize(CAPACITY)


func bind_calendar(calendar: CalendarScript) -> void:
	"""Stamp entries with this calendar's date (unbound: UNDATED)."""
	_calendar = calendar


func post(source: int, level: int, text: String, summary: String = "") -> bool:
	"""Add one notice, stamped with the demo date now -- or, when it repeats the newest entry, count it there
	(see REPEATS FOLD). Refuses (false, nothing kept) empty text, or a source or level outside SOURCE_* /
	LEVEL_*."""
	if text.is_empty() or source < 0 or source >= SOURCE_NAMES.size() or level < LEVEL_NOTE \
			or level > LEVEL_WARNING:
		return false
	var row := _head
	if repeats_newest(source, level, text, summary):
		row = _row(0)
		_repeats[row] += 1
	else:
		_text[row] = text
		_summary[row] = summary
		_source[row] = source
		_level[row] = level
		_repeats[row] = 1
		_head = (_head + 1) % CAPACITY
		_count = mini(_count + 1, CAPACITY)
		rows_posted += 1
	_stamp[row] = _calendar.date_text() if _calendar != null else UNDATED
	_posted_msec[row] = Time.get_ticks_msec()
	revision += 1
	return true


func repeats_newest(source: int, level: int, text: String, summary: String) -> bool:
	"""Whether a post says exactly what the newest entry says (see REPEATS FOLD). An empty feed's rows hold no text,
	and no post is empty, so the first post never matches."""
	var newest := _row(0)
	return _source[newest] == source and _level[newest] == level and _text[newest] == text \
			and _summary[newest] == summary


func poster(source: int, level: int) -> Callable:
	"""A `(text: String) -> void` that posts at this source and level (for a module's notice hook)."""
	return func(text: String) -> void: post(source, level, text)


func count() -> int:
	"""How many entries are kept (at most CAPACITY)."""
	return _count


func _row(k: int) -> int:
	"""The ring row of entry `k`, 0 being the newest."""
	return posmod(_head - 1 - k, CAPACITY)


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


func _times(k: int) -> String:
	"""" (×3)" after an entry said three times in a row; "" after one said once."""
	return " (×%d)" % repeats(k) if repeats(k) > 1 else ""


func age_msec(k: int, now_msec: int) -> int:
	"""How long ago entry `k` was posted, in real milliseconds."""
	return now_msec - _posted_msec[_row(k)]


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
	for k: int in _count:
		if found >= most:
			break
		if source(k) == wanted_source:
			out.append(line(k))
			found += 1
	return found


func has_summary(wanted: String) -> bool:
	"""Whether any kept entry carries this summary (checks)."""
	for k: int in _count:
		if summary(k) == wanted:
			return true
	return false


func has_text(wanted: String) -> bool:
	"""Whether any kept entry carries this full text (checks)."""
	for k: int in _count:
		if text(k) == wanted:
			return true
	return false
