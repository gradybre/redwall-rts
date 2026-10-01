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
##
## TIERS, KINDS, SUBJECTS (decision 0591, feature #39). Every entry also has:
##   * a TIER -- TIER_URGENT, TIER_NORMAL or TIER_INFO -- its visual weight and its sound. A poster may name it;
##     otherwise it is INFERRED: a WARNING is normal, a NOTE is info, and an incident's line takes its severity
##     (demo_incidents.gd `report`: critical is urgent). The tier never pauses anything: a critical INCIDENT
##     pauses, through the pause ledger, as it always did.
##   * a KIND -- the GDD's notice `code` (§2, Notice): what sort of notice it is ("crows", "cold_home"). A poster
##     may name it; an incident's line takes its key's leading words ("farm:wet:3" -> "farm:wet"); any other line's
##     kind is its source and words, so "Snooze" on it quiets that exact line.
##   * a SUBJECT -- what it is about ("bed:3"): the poster's, else its target's (TARGET_NAMES[kind]:id), else none.
## GROUPING. A post that NAMES its kind (and reports no incident: an incident is its own group, and the history
## keeps each date it was said, decision 0331) joins the newest entry of the same kind and subject said within
## GROUP_WINDOW_TICKS of game time, wherever it is in the feed: the entry counts it ("Crows at the barley (×3)"),
## takes the new words, tier, date and time, and moves to the newest place. It writes no new row, so it does not
## chime again (UI §7). A new row gets a new ENTRY ID (`entry_id`, 1, 2, 3...; never reused); a grouped repeat
## keeps its id, so a reader counting new rows reads ids (`is_new_since`), never "the newest N".
## SNOOZE AND DISMISS. `snooze_kind` quiets a kind for N game hours (demo_notice_snoozes.gd); `dismiss` takes one
## entry off the strip. Either way the entry is KEPT here -- nothing is ever deleted but by overflow -- and an
## URGENT entry is never quiet: its own incident card has Snooze and Dismiss.
## THROTTLE. A new row is ANNOUNCED (toasted on the strip, and chimed) only while its tier's toast budget allows: at
## most TOAST_BURST at once, one more each TOAST_REFILL_MSEC of the news clock (unpaused real time). Info and normal
## rows have a budget each, so a burst of reports never silences a warning. At 4x the village says four times as much
## a real second; what a budget holds back is still kept here, and the strip counts it. Urgent rows always announce.
## A grouped repeat updates its row in place and spends nothing.
## THE HOOK. `notice_posted(entry_id, tier, kind, text)` is emitted for every accepted post, grouped and folded
## repeats included (the crash log's breadcrumbs). It is a signal for diagnostics; nothing in the game listens.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")
const SnoozesScript := preload("res://demo/demo_notice_snoozes.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## Every accepted post (see THE HOOK).
signal notice_posted(entry_id: int, tier: int, kind: StringName, text: String)

const SOURCE_FARM: int = 0
const SOURCE_TUNNELS: int = 1
const SOURCE_WEATHER: int = 2
const SOURCE_EVENTS: int = 3
const SOURCE_CREW: int = 4
const SOURCE_WOODS: int = 5
const SOURCE_WATER: int = 6
## The village's own chronicle: a finished first-village guide, a completed player-named project (decision 0481).
const SOURCE_VILLAGE: int = 7
const SOURCE_NAMES: Array[String] = ["Farm", "Tunnels", "Weather", "Threat", "Crew", "Woods", "Water", "Village"]
const LEVEL_NOTE: int = 0
const LEVEL_WARNING: int = 1
## §7: "severity word+icon" -- the word, so colour never states the level alone.
const LEVEL_WORDS: Array[String] = ["", "Warning: "]
const CAPACITY: int = 128
const UNDATED: String = "—"

## The tiers (see TIERS): visual weight and sound. TIER_AUTO asks `post` to infer one.
const TIER_AUTO: int = -1
const TIER_INFO: int = 0
const TIER_NORMAL: int = 1
const TIER_URGENT: int = 2
const TIER_NAMES: Array[String] = ["Info", "Normal", "Urgent"]
## Every tier (a filter mask with all three bits set).
const ALL_TIERS: int = 7
## The urgent tier's word before its text (a normal or info entry keeps its level's word).
const URGENT_WORD: String = "Urgent: "
## No kind named (the feed infers one, and the post does not group).
const NO_KIND: StringName = &""
## A named kind's repeat about the same subject groups within this much game time: one game day.
const GROUP_WINDOW_TICKS: int = 24 * SimClock.TICKS_PER_HOUR
## The history's Snooze: this many game hours.
const SNOOZE_HOURS: int = 6
## The toast budget (see THROTTLE).
const TOAST_BURST: int = 4
const TOAST_REFILL_MSEC: int = 2500

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
	GROUP_WOODS, GROUP_WATER, GROUP_VILLAGE]
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

## Bumped by every post, snooze, wake and dismissal.
var revision: int = 0
## Rows ever written: bumped by every post that is not folded into the newest (a reader counts new rows by it;
## the demo's sound, decision 0351). The newest row's entry id is this number (see GROUPING).
var rows_posted: int = 0
## New rows the toast budget held back (see THROTTLE), and new rows a snooze kept quiet; only ever count up.
var throttled: int = 0
var snoozed_quiet: int = 0
## The snoozed kinds (see SNOOZE AND DISMISS).
var snoozes: SnoozesScript = SnoozesScript.new()

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
## See TIERS, GROUPING, SNOOZE AND DISMISS, THROTTLE: the tier, kind (named or inferred), whether the poster named
## it, the subject, the entry id, the game ticks first and last said, announced, dismissed.
var _tier: PackedByteArray = PackedByteArray()
var _kind: PackedStringArray = PackedStringArray()
var _named: PackedByteArray = PackedByteArray()
var _subject: PackedStringArray = PackedStringArray()
var _id: PackedInt32Array = PackedInt32Array()
var _first_tick: PackedInt64Array = PackedInt64Array()
var _said_tick: PackedInt64Array = PackedInt64Array()
var _announced: PackedByteArray = PackedByteArray()
var _dismissed: PackedByteArray = PackedByteArray()
## The info and normal toast budgets (by TIER_*), in news-clock milliseconds of credit (TOAST_REFILL_MSEC a toast),
## and when they were last topped up (-1: never).
var _credit_msec: PackedInt32Array = [TOAST_BURST * TOAST_REFILL_MSEC, TOAST_BURST * TOAST_REFILL_MSEC]
var _credit_at: int = -1


func bind_calendar(calendar: CalendarScript) -> void:
	"""Stamp entries with this calendar's date (unbound: UNDATED), and time grouping and snoozes on its ticks."""
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


func now_tick() -> int:
	"""The game tick now: the bound calendar's (0 unbound: then grouping never times out and a snooze lasts until
	woken)."""
	return _calendar.tick if _calendar != null else 0


# --- posting ------------------------------------------------------------------------------------------

func post(from_source: int, at_level: int, words: String, brief: String = "", to_kind: int = TARGET_NONE,
		to_id: int = -1, serial: int = NO_INCIDENT, as_tier: int = TIER_AUTO, as_kind: StringName = NO_KIND,
		about_subject: String = "") -> bool:
	"""Add one notice, stamped with the demo date now -- or, when it repeats the newest entry, count it there
	(see REPEATS FOLD), or when it names a kind, group it (see GROUPING). `to_kind` / `to_id` name its target
	(TARGET_*), `serial` the incident it reports, `as_tier` its TIER_* (TIER_AUTO: inferred), `as_kind` and
	`about_subject` what sort of notice it is and what about (see TIERS). Refuses (false, nothing kept) empty words, or a
	source, level, target or tier outside SOURCE_* / LEVEL_* / TARGET_* / TIER_*. The parameters are named apart from
	the accessors (`text`, `kind`, ...), which they would shadow; GDScript passes them by position, so callers are
	unaffected."""
	if not _valid(from_source, at_level, words, to_kind, as_tier):
		return false
	var said: int = infer_tier(at_level) if as_tier == TIER_AUTO else as_tier
	var about: String = subject_of(about_subject, to_kind, to_id)
	var row: int = _row(0)
	var groups: bool = as_kind != NO_KIND and serial == NO_INCIDENT
	var grouped: int = _group_row(String(as_kind), about) if groups else -1
	if not groups and _source.size() > 0 and repeats_newest(from_source, at_level, words, brief) \
			and _target_kind[row] == to_kind and _target_id[row] == to_id and _incident[row] == serial:
		_repeats[row] += 1
		_dismissed[row] = 0
	elif grouped >= 0:
		row = _regroup(grouped, from_source, at_level, words, brief, to_kind, to_id, said)
	else:
		row = _new_row(from_source, at_level, words, brief, to_kind, to_id, serial)
		_tag(row, said, as_kind, about)
	_stamp[row] = _calendar.date_text() if _calendar != null else UNDATED
	_posted_msec[row] = now_msec()
	_said_tick[row] = now_tick()
	revision += 1
	notice_posted.emit(_id[row], _tier[row], StringName(_kind[row]), words)
	return true


func notify(from_source: int, as_tier: int, as_kind: StringName, words: String, about_subject: String = "",
		brief: String = "", to_kind: int = TARGET_NONE, to_id: int = -1) -> bool:
	"""The short form for a new kind of notice (see TIERS): `post` at a WARNING for an urgent or normal `as_tier`, a
	NOTE for info, naming its `as_kind` and `about_subject` (so its repeats group). Refuses TIER_AUTO and an empty
	kind."""
	if as_tier < TIER_INFO or as_tier > TIER_URGENT or as_kind == NO_KIND:
		return false
	var at_level: int = LEVEL_NOTE if as_tier == TIER_INFO else LEVEL_WARNING
	return post(from_source, at_level, words, brief, to_kind, to_id, NO_INCIDENT, as_tier, as_kind, about_subject)


func _valid(from_source: int, at_level: int, words: String, to_kind: int, as_tier: int) -> bool:
	"""Whether a post's text, source, level, target and tier are in range."""
	return not words.is_empty() and from_source >= 0 and from_source < SOURCE_NAMES.size() and at_level >= LEVEL_NOTE \
		and at_level <= LEVEL_WARNING and to_kind >= TARGET_NONE and to_kind < TARGET_NAMES.size() \
		and as_tier >= TIER_AUTO and as_tier <= TIER_URGENT


static func infer_tier(at_level: int) -> int:
	"""The tier a post that names none takes (see TIERS): a WARNING is normal, a NOTE info."""
	return TIER_NORMAL if at_level == LEVEL_WARNING else TIER_INFO


static func subject_of(about_subject: String, to_kind: int, to_id: int) -> String:
	"""What a post is about (see TIERS): `subject` when given, else its target "bed:3", else ""."""
	if not about_subject.is_empty():
		return about_subject
	if to_kind <= TARGET_NONE or to_kind >= TARGET_NAMES.size():
		return ""
	return "%s:%d" % [TARGET_NAMES[to_kind], to_id]


func _new_row(from_source: int, at_level: int, words: String, brief: String, to_kind: int, to_id: int,
		serial: int) -> int:
	"""A new newest row (overflow letting the oldest unheld one go), with a new entry id; returns its index."""
	if _source.size() >= CAPACITY:
		_remove(_victim())
	_append(from_source, at_level, words, brief, to_kind, to_id, serial)
	rows_posted += 1
	var row: int = _source.size() - 1
	_id[row] = rows_posted
	_first_tick[row] = now_tick()
	return row


func _tag(row: int, said: int, as_kind: StringName, about: String) -> void:
	"""A new row's tier, kind (named, or inferred: see TIERS), subject, and whether it is announced (see THROTTLE)."""
	_tier[row] = said
	_named[row] = 0 if as_kind == NO_KIND else 1
	_kind[row] = String(as_kind) if as_kind != NO_KIND else _inferred_kind(row)
	_subject[row] = about
	_announced[row] = _admit(said, _kind[row])


func _inferred_kind(row: int) -> String:
	"""The kind of a row whose poster named none: its source and its words ("farm:Bed 4 is dry")."""
	var words: String = _summary[row] if not _summary[row].is_empty() else _text[row]
	return "%s:%s" % [SOURCE_NAMES[_source[row]].to_lower(), words]


func _group_row(as_kind: String, about: String) -> int:
	"""The storage index of the newest entry a post naming `kind` about `about` joins (see GROUPING; -1: none)."""
	var now: int = now_tick()
	for i: int in range(_source.size() - 1, -1, -1):
		if _named[i] == 1 and _kind[i] == as_kind and _subject[i] == about and _incident[i] == NO_INCIDENT:
			return i if now - _said_tick[i] <= GROUP_WINDOW_TICKS else -1
	return -1


func _regroup(i: int, from_source: int, at_level: int, words: String, brief: String, to_kind: int, to_id: int,
		said: int) -> int:
	"""Fold a grouped repeat into storage index `i` and move it to the newest place (see GROUPING): counted, its id,
	kind, subject and first tick kept, the new words, level, tier and target taken; shown again unless snoozed (one
	the budget held back asks the budget again). Returns its new index."""
	var kept := Vector4i(_id[i], _repeats[i] + 1, _named[i], _announced[i])
	var first: int = _first_tick[i]
	var as_kind: String = _kind[i]
	var about: String = _subject[i]
	_remove(i)
	_append(from_source, at_level, words, brief, to_kind, to_id, NO_INCIDENT)
	var row: int = _source.size() - 1
	_id[row] = kept.x
	_repeats[row] = kept.y
	_named[row] = kept.z
	_first_tick[row] = first
	_kind[row] = as_kind
	_subject[row] = about
	_tier[row] = said
	_announced[row] = 1 if kept.w == 1 and not _snoozed(as_kind, said) else _admit(said, as_kind)
	return row


func _admit(said: int, as_kind: String) -> int:
	"""Whether a new row is announced (1) or kept quiet (0): urgent always; a snoozed kind never; else while its
	tier's toast budget allows (see THROTTLE)."""
	if said == TIER_URGENT:
		return 1
	if _snoozed(as_kind, said):
		snoozed_quiet += 1
		return 0
	_refill()
	if _credit_msec[said] < TOAST_REFILL_MSEC:
		throttled += 1
		return 0
	_credit_msec[said] -= TOAST_REFILL_MSEC
	return 1


func _refill() -> void:
	"""Top both toast budgets up by the news-clock time since they last were, to TOAST_BURST toasts each."""
	var now: int = now_msec()
	if _credit_at >= 0 and now > _credit_at:
		for said: int in _credit_msec.size():
			_credit_msec[said] = mini(_credit_msec[said] + (now - _credit_at), TOAST_BURST * TOAST_REFILL_MSEC)
	_credit_at = now


func _append(from_source: int, at_level: int, words: String, brief: String, to_kind: int, to_id: int,
		serial: int) -> void:
	"""One new newest entry (stamped and timed by `post`, tagged by `_tag` or `_regroup`)."""
	_stamp.append(UNDATED)
	_text.append(words)
	_summary.append(brief)
	_source.append(from_source)
	_level.append(at_level)
	_posted_msec.append(0)
	_repeats.append(1)
	_target_kind.append(to_kind)
	_target_id.append(to_id)
	_incident.append(serial)
	for column: PackedByteArray in [_tier, _named, _announced, _dismissed]:
		column.append(0)
	for column: PackedStringArray in [_kind, _subject]:
		column.append("")
	_id.append(0)
	_first_tick.append(0)
	_said_tick.append(0)


func _remove(i: int) -> void:
	"""Drop the entry at storage index `i` (0: the oldest)."""
	for column: PackedStringArray in [_stamp, _text, _summary, _kind, _subject]:
		column.remove_at(i)
	for column: PackedByteArray in [_source, _level, _target_kind, _tier, _named, _announced, _dismissed]:
		column.remove_at(i)
	for column: PackedInt32Array in [_repeats, _target_id, _incident, _id]:
		column.remove_at(i)
	for column: PackedInt64Array in [_posted_msec, _first_tick, _said_tick]:
		column.remove_at(i)


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


func repeats_newest(from_source: int, at_level: int, words: String, brief: String) -> bool:
	"""Whether a post says exactly what the newest entry says (see REPEATS FOLD). An empty feed has no newest
	entry, so the first post never matches."""
	if _source.is_empty():
		return false
	var newest: int = _row(0)
	return _source[newest] == from_source and _level[newest] == at_level and _text[newest] == words \
			and _summary[newest] == brief


func poster(from_source: int, at_level: int) -> Callable:
	"""A `(text: String) -> void` that posts at this source and level (for a module's notice hook)."""
	return func(words: String) -> void: post(from_source, at_level, words)


# --- snooze and dismiss -------------------------------------------------------------------------------

func snooze_kind(as_kind: StringName, hours: int = SNOOZE_HOURS) -> bool:
	"""Quiet `kind` for `hours` game hours from now (see SNOOZE AND DISMISS). Refuses an empty kind or hours < 1."""
	if as_kind == NO_KIND or hours < 1:
		return false
	var now: int = now_tick()
	if not snoozes.snooze(String(as_kind), now + hours * SimClock.TICKS_PER_HOUR, now):
		return false
	revision += 1
	return true


func snooze_entry(k: int, hours: int = SNOOZE_HOURS) -> bool:
	"""Snooze entry `k`'s kind. Refuses an urgent entry (see SNOOZE AND DISMISS) or `k` out of range."""
	if k < 0 or k >= count() or tier(k) == TIER_URGENT:
		return false
	return snooze_kind(kind(k), hours)


func wake_kind(as_kind: StringName) -> bool:
	"""End `kind`'s snooze (false: it was not snoozed)."""
	if not snoozes.wake(String(as_kind)):
		return false
	revision += 1
	return true


func wake_all() -> int:
	"""End every snooze; returns how many there were."""
	var woken: int = snoozes.wake_all()
	revision += 1 if woken > 0 else 0
	return woken


func is_kind_snoozed(as_kind: StringName) -> bool:
	"""Whether `kind` is snoozed now."""
	return snoozes.is_snoozed(String(as_kind), now_tick())


func snooze_hours_left(as_kind: StringName) -> int:
	"""Whole game hours until `as_kind` wakes, rounded up (0: not snoozed). Integer division: whole hours, by intent."""
	var left: int = snoozes.until(String(as_kind)) - now_tick()
	if left <= 0:
		return 0
	@warning_ignore("integer_division")
	return (left + SimClock.TICKS_PER_HOUR - 1) / SimClock.TICKS_PER_HOUR


func _snoozed(as_kind: String, said: int) -> bool:
	"""Whether an entry of `kind` at tier `said` is kept quiet by a snooze now (never an urgent one)."""
	return said != TIER_URGENT and snoozes.is_snoozed(as_kind, now_tick())


func dismiss(k: int) -> bool:
	"""Take entry `k` off the strip; it stays in the history (false: out of range or already dismissed)."""
	if k < 0 or k >= count() or _dismissed[_row(k)] == 1:
		return false
	_dismissed[_row(k)] = 1
	revision += 1
	return true


func dismiss_id(wanted_id: int) -> bool:
	"""`dismiss` the entry with this id (false: gone, or already dismissed)."""
	return dismiss(index_of(wanted_id))


# --- reading ------------------------------------------------------------------------------------------

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


func tier(k: int) -> int:
	"""Entry `k`'s TIER_* (see TIERS)."""
	return _tier[_row(k)]


func kind(k: int) -> StringName:
	"""Entry `k`'s kind: the one its poster named, else the one inferred (see TIERS)."""
	return StringName(_kind[_row(k)])


func kind_named(k: int) -> bool:
	"""Whether entry `k`'s poster named its kind (an incident's line is named from its key). Only a named line that
	reports no incident groups."""
	return _named[_row(k)] == 1


func subject(k: int) -> String:
	"""What entry `k` is about ("bed:3"; "" when nothing)."""
	return _subject[_row(k)]


func entry_id(k: int) -> int:
	"""Entry `k`'s id: 1 for the first row ever written, never reused (see GROUPING)."""
	return _id[_row(k)]


func index_of(wanted_id: int) -> int:
	"""The entry `k` with this id (-1: none kept)."""
	for k: int in count():
		if _id[_row(k)] == wanted_id:
			return k
	return -1


func is_new_since(k: int, seen_rows: int) -> bool:
	"""Whether entry `k` is a row written after `rows_posted` was `seen_rows` (a grouped repeat is not)."""
	return _id[_row(k)] > seen_rows


func first_tick(k: int) -> int:
	"""The game tick entry `k` was first said at."""
	return _first_tick[_row(k)]


func said_tick(k: int) -> int:
	"""The game tick entry `k` was last said at."""
	return _said_tick[_row(k)]


func is_announced(k: int) -> bool:
	"""Whether entry `k` was toasted and chimed rather than kept quiet (see THROTTLE)."""
	return _announced[_row(k)] == 1


func is_dismissed(k: int) -> bool:
	"""Whether entry `k` was dismissed."""
	return _dismissed[_row(k)] == 1


func is_quiet(k: int) -> bool:
	"""Whether the strip leaves entry `k` out: held back, dismissed, or of a kind snoozed now (never urgent)."""
	var row: int = _row(k)
	return _announced[row] == 0 or _dismissed[row] == 1 or _snoozed(_kind[row], _tier[row])


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


func tiers_into(group_mask: int, tier_mask: int, out: PackedInt32Array) -> int:
	"""Fill `out` with the entries in `group_mask`'s places whose tier's bit is set in `tier_mask` (ALL_TIERS: any),
	newest first; returns how many."""
	out.clear()
	for k: int in count():
		if group_mask & (1 << group(k)) != 0 and tier_mask & (1 << tier(k)) != 0:
			out.append(k)
	return out.size()


static func tier_mask_of(show: int) -> int:
	"""The tiers a SHOW_* severity filter wants: all; urgent and normal (warnings); info (notes)."""
	if show == SHOW_WARNINGS:
		return (1 << TIER_URGENT) | (1 << TIER_NORMAL)
	return 1 << TIER_INFO if show == SHOW_NOTES else ALL_TIERS


func _times(k: int) -> String:
	"""" (×3)" after an entry said three times in a row; "" after one said once."""
	return " (×%d)" % repeats(k) if repeats(k) > 1 else ""


func _word(k: int) -> String:
	"""Entry `k`'s word before its text: URGENT_WORD for an urgent one, else its level's (§7: never colour alone)."""
	return URGENT_WORD if tier(k) == TIER_URGENT else LEVEL_WORDS[level(k)]


func age_msec(k: int, now: int) -> int:
	"""How long ago entry `k` was posted, in the milliseconds `now` is in (`now_msec()`'s)."""
	return now - _posted_msec[_row(k)]


func held_back(now: int, within_msec: int) -> int:
	"""How many entries posted within `within_msec` of `now` the strip leaves out (`is_quiet`, but not dismissed)."""
	var n: int = 0
	for k: int in count():
		if age_msec(k, now) > within_msec:
			continue
		n += 1 if is_quiet(k) and not is_dismissed(k) else 0
	return n


func line(k: int) -> String:
	"""Entry `k` as one readable line: 'Y1 Spring 3, 14:00 · Warning: Frost tonight! …'."""
	return "%s · %s%s%s" % [stamp(k), _word(k), text(k), _times(k)]


func short_line(k: int) -> String:
	"""Entry `k` in its short form: its summary when one was authored, else its text."""
	var shown: String = summary(k) if not summary(k).is_empty() else text(k)
	return "%s · %s%s%s" % [stamp(k), _word(k), shown, _times(k)]


func kind_title(wanted: StringName) -> String:
	"""A kind in words: the summary of its newest entry, else that entry's text (the kind itself when none is kept)."""
	for k: int in count():
		if _kind[_row(k)] == String(wanted):
			return summary(k) if not summary(k).is_empty() else text(k)
	return String(wanted)


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
