extends RefCounted
## WRITES A SEASON'S PAGE (decision 0631) from what was recorded, and nothing else. Reads, never writes: the farm's
## after-action record (farm_record.gd: food stored, portions eaten, who went without, crops lost, each day's weather
## event), the people's ledger (people_ledger.gd: the season's committed deeds, friendships, hours worked together), the
## season's tally of the news (chronicle_tally.gd: troubles, occasions, supper songs; the songs learned) -- and words it
## through chronicle_text.gd. Short by construction: each section has a line cap, and a section with nothing recorded
## is left out, heading and all.
##
## THE SECTIONS, in order (chronicle_book.gd SECTION_*):
##   opening   one line in the season's MOOD, the first that holds: an occasion (a "Chronicle:" line), hunger (somebody
##             went without, a day had no meal), crops lost, hard weather (an adverse §5.10 event or a weather trouble),
##             other trouble, steady (anything else recorded) or bare (nothing at all). Each mood's wordings claim no
##             more than its own condition (review of decision 0631: an opening once claimed hunger for a lost crop).
##   table     food into store and its three largest items, portions eaten, who went without, crops lost -- and, once in
##             the village's life, its first food into store and first cooked meals.
##   weather   the season's §5.10 event and its days, then the troubles counted, at most MAX_WEATHER_LINES.
##   deeds     the season's committed deeds (rescues; bridges, tunnels, rooms; first harvests; meals; skills -- the
##             reflection's own order, people_ledger.gd REFLECT_RANK), up to MAX_DEED_LINES kept, each with its serial so
##             the page shows the player's curation (chronicle_book.gd). A first rescue, bridge, tunnel or room in the
##             village's life says so. Deed kinds outside TOLD_KINDS (a later feature's own deed, as the regatta's) are
##             that feature's to tell, through its "Chronicle:" line.
##   friends   friendships made and lapsed in the season (REQ-SET-037's flag, start against end), and the pair who worked
##             side by side most (at least WORKED_LEAST hours). The demo records no quarrel -- affinity only grows, and
##             fades without contact -- so "falling out" is told only as a friendship lapsed, never invented.
##   songs     the season's occasions (the regatta's feast and any later gathering, the first village standing, a
##             project done), songs learned, and the evenings the supper table sang.
##   closing   one line, on a written page only.
## The draft (the season still under way) is written the same way from what is recorded so far, with a note saying so.
##
## VILLAGE FIRSTS are bits of `firsts` (FIRST_*). `write` tells a first only if its bit is clear, and leaves the bits it
## would set in `firsts_after`; the owner commits them only for a written page, so a draft never uses one up.

const RecordScript := preload("res://demo/farm/farm_record.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const PeopleText := preload("res://demo/people/people_text.gd")
const BookScript := preload("res://demo/chronicle/chronicle_book.gd")
const TallyScript := preload("res://demo/chronicle/chronicle_tally.gd")
const Text := preload("res://demo/chronicle/chronicle_text.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const MOOD_OCCASION: int = 0
const MOOD_HARD: int = 1
const MOOD_LOSS: int = 2
const MOOD_WEATHER: int = 3
const MOOD_TROUBLE: int = 4
const MOOD_STEADY: int = 5
const MOOD_BARE: int = 6
## The §5.10 events that are hard weather (scripts/core/weather.gd ids): blight, drought, early frost, hard freeze,
## heavy rain -- not calm days or an ideal spell.
const ADVERSE_EVENTS: PackedInt32Array = [0, 2, 3, 4, 5]
## The troubles that are weather's (chronicle_tally.gd TROUBLE_*): wind, the garden flooded, a tunnel flooded, frost.
const WEATHER_TROUBLES: PackedInt32Array = [TallyScript.TROUBLE_WINDTHROW, TallyScript.TROUBLE_GARDEN_FLOOD,
	TallyScript.TROUBLE_TUNNEL_FLOODED, TallyScript.TROUBLE_FROST]

const MAX_WEATHER_LINES: int = 4
const MAX_DEED_LINES: int = 8
const MAX_FRIEND_LINES: int = 3
const MAX_SONG_LINES: int = 5
const MAX_FRIENDSHIPS: int = 2
const TOP_ITEMS: int = 3
## The pair who worked together most is told from this many shared hours in the season.
const WORKED_LEAST: int = 3
## The §5.10 events (scripts/core/weather.gd EVENT_COUNT).
const WEATHER_EVENT_COUNT: int = 7

## Which wording slot each kind of line varies in (chronicle_text.gd `pick`).
const SLOT_OPENING: int = 0
const SLOT_HARVEST: int = 1
const SLOT_PORTIONS: int = 2
const SLOT_CLOSING: int = 3
const SLOT_WORKED: int = 4
const SLOT_SUPPER: int = 5
const SLOT_FRIENDS: int = 16

## The village's firsts (see VILLAGE FIRSTS): food into store, cooked meals, and one bit per deed kind after them.
const FIRST_FOOD: int = 1
const FIRST_MEALS: int = 2
const FIRST_DEED_SHIFT: int = 2
## The deed kinds the page tells, and those whose first in the village's life it marks.
const TOLD_KINDS: PackedInt32Array = [Ledger.KIND_RESCUE, Ledger.KIND_BRIDGE, Ledger.KIND_TUNNEL, Ledger.KIND_ROOM,
	Ledger.KIND_FIRST_HARVEST, Ledger.KIND_SKILL, Ledger.KIND_MEAL]
const FIRST_KINDS: PackedInt32Array = [Ledger.KIND_RESCUE, Ledger.KIND_BRIDGE, Ledger.KIND_TUNNEL, Ledger.KIND_ROOM]
const MAX_RANK: int = 4

var record: RecordScript = null
var ledger: Ledger = null
## Every resident's name, by cast index; every song's title, by song.
var names: PackedStringArray = PackedStringArray()
var song_titles: PackedStringArray = PackedStringArray()
var seed_value: int = 0
## The village's firsts already told (see VILLAGE FIRSTS), and those the last `write` would add.
var firsts: int = 0
var firsts_after: int = 0
## The songs each resident knows NOW (song_circle.gd `knows`), for a draft: a written page reads its tally's end.
var knows_now: PackedInt32Array = PackedInt32Array()

var _lines: PackedStringArray = PackedStringArray()
var _deeds: PackedInt32Array = PackedInt32Array()


func write(tally: TallyScript, book: BookScript, draft: bool) -> int:
	"""The page of `tally`'s season into `book` (see THE SECTIONS); returns its index."""
	var s: int = tally.season
	firsts_after = firsts
	var page: int = book.begin_page(s, Text.page_title(s, draft))
	book.add_line(opening(tally), BookScript.STYLE_OPENING, BookScript.SECTION_OPENING)
	if draft:
		book.add_line(Text.DRAFT_NOTE % _days_words(s), BookScript.STYLE_NOTE, BookScript.SECTION_OPENING)
	_table_lines(s)
	_section(book, BookScript.SECTION_TABLE)
	_weather_lines(tally)
	_section(book, BookScript.SECTION_WEATHER)
	_deed_lines(s)
	_section(book, BookScript.SECTION_DEEDS)
	_friend_lines(tally)
	_section(book, BookScript.SECTION_FRIENDS)
	_song_lines(tally)
	_section(book, BookScript.SECTION_SONGS)
	if not draft:
		var closing: String = Text.CLOSINGS[Text.pick(seed_value, s, SLOT_CLOSING, Text.CLOSINGS.size())]
		book.add_line(closing % Text.season_word(s), BookScript.STYLE_CLOSING, BookScript.SECTION_CLOSING)
	return page


func _section(book: BookScript, section: int) -> void:
	"""The lines gathered for `section`, under its heading (nothing when none), each deed with its serial."""
	if _lines.is_empty():
		return
	book.add_line(Text.SECTION_TITLES[section], BookScript.STYLE_HEADING, section)
	for k: int in _lines.size():
		var deed: int = _deeds[k] if k < _deeds.size() else BookScript.NO_DEED
		book.add_line(_lines[k], BookScript.STYLE_TEXT, section, deed)


func _days_words(s: int) -> String:
	"""'4 days recorded' (or 'no day of it closed yet'): the draft's note."""
	var days: int = record.season_days(s) if record != null else 0
	if days == 0:
		return Text.DRAFT_NO_DAYS
	return Text.DAYS_RECORDED % Text.count_words(days, Text.DAYS_RECORDED_NOUNS)


# --- the opening ---------------------------------------------------------------------------------------------------

func opening(tally: TallyScript) -> String:
	"""The season's opening line, in its mood (see THE SECTIONS)."""
	var words: Array = Text.OPENINGS[mood(tally)]
	return String(words[Text.pick(seed_value, tally.season, SLOT_OPENING, words.size())])


func mood(tally: TallyScript) -> int:
	"""MOOD_* of the season, from what was recorded (see THE SECTIONS)."""
	var s: int = tally.season
	if tally.occasion_kind.has(TallyScript.OCCASION_CHRONICLE):
		return MOOD_OCCASION
	if _total(s, RecordScript.F_WITHOUT) > 0 or tally.troubles[TallyScript.TROUBLE_NO_MEAL] > 0:
		return MOOD_HARD
	if _total(s, RecordScript.F_LOST) > 0:
		return MOOD_LOSS
	if _hard_weather(tally):
		return MOOD_WEATHER
	if tally.any_trouble():
		return MOOD_TROUBLE
	if _anything_recorded(tally):
		return MOOD_STEADY
	return MOOD_BARE


func _hard_weather(tally: TallyScript) -> bool:
	"""Whether the season saw an adverse §5.10 event or a weather trouble."""
	for trouble: int in WEATHER_TROUBLES:
		if tally.troubles[trouble] > 0:
			return true
	var days := PackedInt32Array()
	_event_days_into(tally.season, days)
	for event: int in ADVERSE_EVENTS:
		if days[event] > 0:
			return true
	return false


func _anything_recorded(tally: TallyScript) -> bool:
	"""Whether the season left any fact a section would tell."""
	var s: int = tally.season
	if _total(s, RecordScript.F_HARVESTED) > 0 or _total(s, RecordScript.F_PORTIONS) > 0:
		return true
	if _event_days_into(s, PackedInt32Array()) > 0:
		return true
	if tally.occasion_count() > 0 or tally.supper_song_days > 0 or _season_deeds(s) > 0:
		return true
	return false


func _total(s: int, field: int) -> int:
	"""A record field's season total (0 without a record)."""
	return record.season_total(s, field) if record != null else 0


func _season_deeds(s: int) -> int:
	"""How many told deeds the ledger keeps from season `s`."""
	var n: int = 0
	if ledger == null:
		return 0
	for d: int in ledger.deed_kind.size():
		n += 1 if ledger.deed_season[d] == s and TOLD_KINDS.has(ledger.deed_kind[d]) else 0
	return n


func _first(bit: int) -> bool:
	"""Whether a village first is still to be told (and now counted told, in `firsts_after`)."""
	if firsts_after & bit != 0:
		return false
	firsts_after |= bit
	return true


# --- the harvest and the table -------------------------------------------------------------------------------------

func _table_lines(s: int) -> void:
	"""Food into store, portions, who went without, crops lost (see THE SECTIONS)."""
	_begin_lines()
	if record == null or record.season_days(s) == 0:
		return
	var stored: int = record.season_total(s, RecordScript.F_HARVESTED)
	if stored > 0:
		if _first(FIRST_FOOD):
			_lines.append(Text.FIRST_HARVEST)
		var words: String = Text.HARVEST[Text.pick(seed_value, s, SLOT_HARVEST, Text.HARVEST.size())]
		_lines.append(Text.capitalised(words % [FarmText.units_text(stored), top_items(s)]))
	else:
		_lines.append(Text.HARVEST_NONE)
	var portions: int = record.season_total(s, RecordScript.F_PORTIONS)
	if portions > 0:
		if _first(FIRST_MEALS):
			_lines.append(Text.FIRST_MEALS)
		var served: String = Text.PORTIONS[Text.pick(seed_value, s, SLOT_PORTIONS, Text.PORTIONS.size())]
		_lines.append(Text.capitalised(served % Text.count_words(portions, Text.PORTION_NOUNS)))
	_hunger_lines(s, portions)


func _hunger_lines(s: int, portions: int) -> void:
	"""Who went without (or that nobody did, when the kitchen served), and the crops lost."""
	var without: int = record.season_total(s, RecordScript.F_WITHOUT)
	if without > 0:
		_lines.append(Text.WENT_WITHOUT_ONCE if without == 1 else Text.WENT_WITHOUT % without)
	elif portions > 0:
		_lines.append(Text.NONE_WITHOUT)
	var lost: int = record.season_total(s, RecordScript.F_LOST)
	if lost > 0:
		_lines.append(Text.CROPS_LOST % Text.count_words(lost, Text.CROP_NOUNS))


func top_items(s: int) -> String:
	"""'carrot 12.0 U, barley 9.5 U and turnip 6.2 U' -- the season's largest stores by item (and how many more)."""
	var amounts := PackedInt64Array()
	var kinds: int = 0
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		var milli: int = record.season_item_total(s, RecordScript.G_HARVESTED, item)
		amounts.append(milli)
		kinds += 1 if milli > 0 else 0
	var parts := PackedStringArray()
	for _n: int in mini(TOP_ITEMS, kinds):
		var best: int = 0
		for item: int in amounts.size():
			best = item if amounts[item] > amounts[best] else best
		parts.append("%s %s" % [Catalog.ITEM_LABELS[best].to_lower(), FarmText.units_text(amounts[best])])
		amounts[best] = -1
	if kinds > TOP_ITEMS:
		parts.append(Text.MORE_KINDS % (kinds - TOP_ITEMS))
	return Text.list_words(parts)


# --- weather and trouble -------------------------------------------------------------------------------------------

func _weather_lines(tally: TallyScript) -> void:
	"""The season's §5.10 events and their days, then its troubles, at most MAX_WEATHER_LINES."""
	_begin_lines()
	var days := PackedInt32Array()
	_event_days_into(tally.season, days)
	for event: int in days.size():
		if days[event] > 0 and _lines.size() < MAX_WEATHER_LINES:
			_lines.append(Text.WEATHER_EVENTS[event] % Text.count_words(days[event], Text.DAY_NOUNS))
	for trouble: int in TallyScript.TROUBLE_COUNT:
		var count: int = tally.troubles[trouble]
		if count > 0 and _lines.size() < MAX_WEATHER_LINES:
			var what: String = Text.count_words(count, Text.TROUBLE_NOUNS[trouble])
			_lines.append(Text.capitalised(Text.TROUBLES[trouble] % what))


func _event_days_into(s: int, out: PackedInt32Array) -> int:
	"""Days of season `s` the record saw each §5.10 event on, by event id, into `out`; returns the days in all."""
	out.resize(WEATHER_EVENT_COUNT)
	out.fill(0)
	var all_days: int = 0
	if record == null:
		return 0
	for k: int in record.day_count():
		@warning_ignore("integer_division")
		var of_season: bool = record.value(k, RecordScript.F_DAY) / SimClock.DAYS_PER_SEASON == s
		var event: int = record.value(k, RecordScript.F_EVENT)
		if of_season and record.value(k, RecordScript.F_WEATHER_SEEN) == 1 and event >= 0 and event < out.size():
			out[event] += 1
			all_days += 1
	return all_days


# --- deeds ---------------------------------------------------------------------------------------------------------

func _deed_lines(s: int) -> void:
	"""The season's told deeds, best first (REFLECT_RANK, then earliest), at most MAX_DEED_LINES, with their serials."""
	_begin_lines()
	if ledger == null:
		return
	for rank: int in MAX_RANK + 1:
		for d: int in ledger.deed_kind.size():
			if _lines.size() >= MAX_DEED_LINES:
				return
			var kind: int = ledger.deed_kind[d]
			if ledger.deed_season[d] != s or not TOLD_KINDS.has(kind) or Ledger.REFLECT_RANK[kind] != rank:
				continue
			_tell_deed(ledger.deed_base + d, kind)


func _tell_deed(deed: int, kind: int) -> void:
	"""One deed's line, told of its lead, marked when it is the village's first of its kind."""
	var e: int = ledger.event_of_deed(deed)
	if e < 0:
		return
	var words: String = PeopleText.deed_text(ledger.ev_kind[e], _name(ledger.lead_of(deed)), ledger.ev_subject[e],
		_name(ledger.ev_other[e]), ledger.ev_amount[e])
	if words.is_empty():
		return
	var marked: bool = FIRST_KINDS.has(kind) and _first(1 << (FIRST_DEED_SHIFT + kind))
	_lines.append(Text.VILLAGE_FIRST % words if marked else Text.DEED % words)
	_deeds.append(deed)


func _name(who: int) -> String:
	"""Resident `who`'s name ("" out of range: the people's words say "someone")."""
	return names[who] if who >= 0 and who < names.size() else ""


# --- friends and neighbours ----------------------------------------------------------------------------------------

func _friend_lines(tally: TallyScript) -> void:
	"""Friendships made, then lapsed, then the pair who worked together most (see THE SECTIONS)."""
	_begin_lines()
	if ledger == null:
		return
	var end: PackedByteArray = tally.friend_end if tally.ended else ledger.friend
	var made: int = 0
	for want: int in [1, 0]:
		for p: int in end.size():
			var before: int = tally.friend_start[p] if p < tally.friend_start.size() else 0
			if end[p] != want or before == want or _lines.size() >= MAX_FRIEND_LINES - 1 or made >= MAX_FRIENDSHIPS:
				continue
			_tell_pair(tally.season, p, want == 1)
			made += 1
	_worked_line(tally)


func _tell_pair(s: int, p: int, became: bool) -> void:
	"""Pair row `p` became friends, or let a friendship lapse."""
	var n: int = ledger.resident_count()
	@warning_ignore("integer_division")
	var a: int = p / n
	var b: int = p % n
	if not became:
		_lines.append(Text.DRIFTED % [_name(a), _name(b)])
		return
	var words: String = Text.BECAME_FRIENDS[Text.pick(seed_value, s, SLOT_FRIENDS + p, Text.BECAME_FRIENDS.size())]
	_lines.append(words % [_name(a), _name(b)])


func _worked_line(tally: TallyScript) -> void:
	"""The pair with the most hours worked together this season, from WORKED_LEAST."""
	var end: PackedInt32Array = tally.hours_end if tally.ended else ledger.shared_hours
	var best: int = -1
	var most: int = WORKED_LEAST - 1
	for p: int in end.size():
		var gained: int = end[p] - (tally.hours_start[p] if p < tally.hours_start.size() else 0)
		if gained > most:
			most = gained
			best = p
	if best < 0 or _lines.size() >= MAX_FRIEND_LINES:
		return
	var n: int = ledger.resident_count()
	@warning_ignore("integer_division")
	var a: int = best / n
	var words: String = Text.WORKED_TOGETHER[Text.pick(seed_value, tally.season, SLOT_WORKED, Text.WORKED_TOGETHER.size())]
	_lines.append(words % [_name(a), _name(best % n), most])


# --- songs and gatherings ------------------------------------------------------------------------------------------

func _song_lines(tally: TallyScript) -> void:
	"""The season's occasions, songs learned and supper songs, at most MAX_SONG_LINES."""
	_begin_lines()
	for k: int in tally.occasion_count():
		if _lines.size() < MAX_SONG_LINES:
			_lines.append(occasion_line(tally.occasion_kind[k], tally.occasion_text[k]))
	var end: PackedInt32Array = tally.knows_end if tally.ended else knows_now
	for who: int in mini(end.size(), tally.knows_start.size()):
		var learned: int = end[who] & ~tally.knows_start[who]
		for song: int in song_titles.size():
			if learned & (1 << song) != 0 and _lines.size() < MAX_SONG_LINES:
				_lines.append(Text.LEARNED_SONG % [_name(who), song_titles[song]])
	if tally.supper_song_days > 0 and _lines.size() < MAX_SONG_LINES:
		var words: String = Text.SUPPER_SONGS[Text.pick(seed_value, tally.season, SLOT_SUPPER, Text.SUPPER_SONGS.size())]
		_lines.append(words % Text.count_words(tally.supper_song_days, Text.EVENING_NOUNS))


static func occasion_line(kind: int, words: String) -> String:
	"""An occasion in the record's words: a chronicle line as its owner wrote it, the first village, a project done."""
	match kind:
		TallyScript.OCCASION_GUIDE:
			return Text.GUIDE_DONE
		TallyScript.OCCASION_PROJECT:
			return Text.PROJECT_DONE % words
	var line: String = Text.capitalised(words.strip_edges())
	return line if line.ends_with(".") or line.ends_with("!") else line + "."


func _begin_lines() -> void:
	"""A section's lines start empty."""
	_lines.clear()
	_deeds.clear()
