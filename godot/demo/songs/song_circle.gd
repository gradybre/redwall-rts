extends RefCounted
## Who sings what, and when: the village's singing, decided from each resident's context and nothing else. Decision
## 0442 (review SOC-026, UX-030). Presentation only: it reads the contexts it is handed and writes nothing into any
## resident, job, meal or schedule -- songs never block work or meals; they follow them.
##
## CONTEXTS (song_book.gd CONTEXT_*, worked out per resident by demo_songs.gd): WORK while actually working, SUPPER
## while seated at the supper table, EVENING in the quiet hour between supper and bed, NONE otherwise. A song is sung
## only in its own context, and stops the moment its singer leaves it.
## WHO SINGS. The otters know every song from the start. Anyone else LEARNS a song by hearing it sung to its end
## HEARINGS_TO_LEARN times within HEAR_M of the singer; from then on they sing it too, in its context. Learning is a
## routine village news line, once per resident and song.
## HOW. A LEAD sings a song a line at a time, LINE_USEC each, then rests REST_USEC (staggered per resident) before
## another. At most MAX_LEADS sing at once. SUPPER is one table: a single lead at a time, and everyone else seated who
## knows that song JOINS (a "♪" over them, not the words again); the first supper song of a day is a routine news line.
## TIME is real microseconds while the game runs (`step`'s `usec`: 0 while paused, so a song stops where it is); the
## singing is the player's to read, so it does not speed up at 2x or 4x.
## SONGS OFF (`enabled` false, the Settings' toggle): nobody sings, learns or makes news, and every song stops.

const BookScript := preload("res://demo/songs/song_book.gd")

const NOBODY: int = -1
const NO_SONG: int = -1
const LINE_USEC: int = 3200000
const REST_USEC: int = 40000000
## Up to this much more rest, by resident (so the village does not sing in step).
const REST_SPREAD_USEC: int = 20000000
## A song cut short (its singer left its context): a shorter rest.
const CUT_REST_USEC: int = 8000000
## Before anyone's first song, by resident row.
const FIRST_REST_STEP_USEC: int = 5000000
const MAX_LEADS: int = 2
const HEAR_M: float = 6.0
const HEARINGS_TO_LEARN: int = 2
const SUPPER_LINE: String = "At supper %s led “%s”, and the table joined in."
const SUPPER_ALONE_LINE: String = "At supper %s sang “%s”."
const LEARNED_LINE: String = "%s has learned “%s” from the otters."
const LEARNED_FROM_LINE: String = "%s has learned “%s” from %s."

## Whether anyone sings (the Settings' songs toggle).
var enabled: bool = true
## Per resident: the song led (NO_SONG), its line now, the lead joined (NOBODY), and what each knows (a bit per song).
var song: PackedInt32Array = PackedInt32Array()
var line: PackedInt32Array = PackedInt32Array()
var joining: PackedInt32Array = PackedInt32Array()
var knows: PackedInt32Array = PackedInt32Array()
## Per resident: 1 for an otter (who knows every song from the start).
var otter: PackedByteArray = PackedByteArray()
## Bumped whenever a bubble's words change (the view redraws on it).
var revision: int = 0

var _book: BookScript = null
var _names: PackedStringArray = PackedStringArray()
var _line_left: PackedInt64Array = PackedInt64Array()
var _rest_left: PackedInt64Array = PackedInt64Array()
var _heard: PackedByteArray = PackedByteArray()
var _sung: PackedInt32Array = PackedInt32Array()
var _deed: PackedStringArray = PackedStringArray()
var _context: PackedByteArray = PackedByteArray()
var _at: PackedVector2Array = PackedVector2Array()
## `(text: String) -> void`: a routine village news line (unset: none).
var _news: Callable = Callable()
## `() -> PackedStringArray`: the deeds the village has recorded (unset: none; the songs' fallbacks are sung).
var _deeds: Callable = Callable()
var _supper_news_day: int = -1
var _choices: PackedInt32Array = PackedInt32Array()
var _known: PackedInt32Array = PackedInt32Array()
## How many lead now, and who leads the supper table (NOBODY): kept as songs start and stop, so a frame's starts
## cost no scan of the village.
var _lead_count: int = 0
var _table_lead: int = NOBODY


func configure(book: BookScript, names: PackedStringArray, otters: PackedByteArray, news: Callable = Callable(),
		deeds: Callable = Callable()) -> void:
	"""Sing from `book` among residents `names` (in cast order); `otters[i]` 1 for an otter, who knows every song."""
	_book = book
	_names = names
	_news = news
	_deeds = deeds
	var followed: int = names.size()
	for column: PackedInt32Array in [song, line, joining, knows, _sung]:
		column.resize(followed)
	song.fill(NO_SONG)
	joining.fill(NOBODY)
	line.fill(0)
	_sung.fill(0)
	_line_left.resize(followed)
	_rest_left.resize(followed)
	_deed.resize(followed)
	_heard.resize(followed * BookScript.MAX_SONGS)
	_heard.fill(0)
	otter.resize(followed)
	for i: int in followed:
		otter[i] = 1 if i < otters.size() and otters[i] == 1 else 0
		knows[i] = book.all_mask() if otter[i] == 1 else 0
		_rest_left[i] = FIRST_REST_STEP_USEC * (i + 1)


func count() -> int:
	"""How many residents the circle follows."""
	return song.size()


func is_otter(i: int) -> bool:
	"""Whether resident `i` is an otter."""
	return otter[i] == 1


func knows_song(i: int, s: int) -> bool:
	"""Whether resident `i` knows song `s`."""
	return (knows[i] >> s) & 1 == 1


func step(usec: int, contexts: PackedByteArray, positions: PackedVector2Array, day: int) -> void:
	"""Advance the singing by `usec` real microseconds (0 while paused) with each resident's context and place now,
	on game day `day` (see the header)."""
	_context = contexts
	_at = positions
	if not enabled:
		_silence()
		return
	for i: int in count():
		if song[i] != NO_SONG:
			_sing(i, usec)
		else:
			_rest_left[i] = maxi(0, _rest_left[i] - usec)
	_follow_joiners()
	for i: int in count():
		if song[i] == NO_SONG and joining[i] == NOBODY and _rest_left[i] == 0:
			_try_start(i, day)


func _sing(i: int, usec: int) -> void:
	"""A lead's song goes on, or stops: cut when it left the song's context, ended after its last line."""
	if _context_of(i) != _book.contexts[song[i]]:
		_stop(i, CUT_REST_USEC)
		return
	_line_left[i] -= usec
	if _line_left[i] > 0:
		return
	if line[i] + 1 < _book.line_count(song[i]):
		line[i] += 1
		_line_left[i] = LINE_USEC
		revision += 1
		return
	_heard_to_the_end(i)
	_stop(i, REST_USEC + (i * 7919 * 1000) % REST_SPREAD_USEC)


func _try_start(i: int, day: int) -> void:
	"""Resident `i`, rested, in a context, may lead a song it knows -- within MAX_LEADS, and at supper only when no one
	leads there; at a supper already sung it joins instead."""
	var context: int = _context_of(i)
	if context == BookScript.CONTEXT_NONE:
		return
	if context == BookScript.CONTEXT_SUPPER:
		var lead: int = _supper_lead()
		if lead != NOBODY and lead != i:
			if knows_song(i, song[lead]):
				joining[i] = lead
				revision += 1
			return
	if leads() >= MAX_LEADS:
		return
	var choice: int = _choose(i, context)
	if choice == NO_SONG:
		return
	song[i] = choice
	line[i] = 0
	_line_left[i] = LINE_USEC
	_lead_count += 1
	if context == BookScript.CONTEXT_SUPPER:
		_table_lead = i
	_deed[i] = _pick_deed(day + choice)
	_sung[i] += 1
	revision += 1
	if context == BookScript.CONTEXT_SUPPER:
		_supper_news(i, day)


func _choose(i: int, context: int) -> int:
	"""The song of `context` resident `i` sings next: of those it knows, the next after its last (NO_SONG: none)."""
	_book.songs_for(context, _choices)
	_known.clear()
	for s: int in _choices:
		if knows_song(i, s):
			_known.append(s)
	if _known.is_empty():
		return NO_SONG
	return _known[(_sung[i] + i) % _known.size()]


func _follow_joiners() -> void:
	"""A joiner stops when its lead stops or either leaves the table."""
	for i: int in count():
		var lead: int = joining[i]
		if lead == NOBODY:
			continue
		if song[lead] == NO_SONG or _context_of(i) != BookScript.CONTEXT_SUPPER \
				or _context_of(lead) != BookScript.CONTEXT_SUPPER:
			joining[i] = NOBODY
			_rest_left[i] = CUT_REST_USEC
			revision += 1


func _heard_to_the_end(i: int) -> void:
	"""Song `song[i]` was sung to its end: everyone else in earshot who does not know it heard it once more, and
	learns it at HEARINGS_TO_LEARN (a news line)."""
	var s: int = song[i]
	for j: int in count():
		if j == i or knows_song(j, s) or _context_of(j) == BookScript.CONTEXT_NONE \
				or _at[j].distance_to(_at[i]) > HEAR_M:
			continue
		var k: int = j * BookScript.MAX_SONGS + s
		_heard[k] = mini(_heard[k] + 1, 255)
		if _heard[k] >= HEARINGS_TO_LEARN:
			knows[j] |= 1 << s
			_say(LEARNED_LINE % [_names[j], _book.titles[s]] if is_otter(i)
				else LEARNED_FROM_LINE % [_names[j], _book.titles[s], _names[i]])


func _stop(i: int, rest: int) -> void:
	"""Lead `i` stops (its joiners follow on the next pass) and rests `rest`."""
	if song[i] != NO_SONG:
		_lead_count -= 1
	if _table_lead == i:
		_table_lead = NOBODY
	song[i] = NO_SONG
	line[i] = 0
	_rest_left[i] = rest
	revision += 1


func _silence() -> void:
	"""Songs off: every song and every joiner stops at once."""
	for i: int in count():
		if song[i] != NO_SONG or joining[i] != NOBODY:
			song[i] = NO_SONG
			joining[i] = NOBODY
			_rest_left[i] = CUT_REST_USEC
			revision += 1
	_lead_count = 0
	_table_lead = NOBODY


func _supper_lead() -> int:
	"""Who leads the supper table's song now (NOBODY: no one)."""
	return _table_lead


func _supper_news(i: int, day: int) -> void:
	"""The first supper song of day `day` is a routine news line."""
	if day == _supper_news_day:
		return
	_supper_news_day = day
	var others: int = 0
	for j: int in count():
		if j != i and _context_of(j) == BookScript.CONTEXT_SUPPER and knows_song(j, song[i]):
			others += 1
	_say((SUPPER_LINE if others > 0 else SUPPER_ALONE_LINE) % [_names[i], _book.titles[song[i]]])


func _pick_deed(seed_value: int) -> String:
	"""A recorded deed for a song's slot ("" for none: the song's fallback is sung)."""
	if not _deeds.is_valid():
		return ""
	var all: PackedStringArray = _deeds.call() as PackedStringArray
	return all[absi(seed_value) % all.size()] if not all.is_empty() else ""


func _say(text: String) -> void:
	"""A routine news line, when a news feed is bound."""
	if _news.is_valid():
		_news.call(text)


func _context_of(i: int) -> int:
	"""Resident `i`'s context as last stepped (NONE beyond the handed columns)."""
	return _context[i] if i < _context.size() else BookScript.CONTEXT_NONE


func leads() -> int:
	"""How many lead a song now."""
	return _lead_count


func bubble_text(i: int) -> String:
	"""What resident `i`'s bubble says now: '♪ ' and the line it sings, '♪ ♪' joining, '' for none."""
	if song[i] != NO_SONG:
		return "♪ " + _book.line_text(song[i], line[i], _deed[i])
	if joining[i] != NOBODY:
		return "♪ ♪"
	return ""
