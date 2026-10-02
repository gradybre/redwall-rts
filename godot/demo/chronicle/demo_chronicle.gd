extends Node
## THE VILLAGE CHRONICLE (decision 0631, feature #10): at each season's end, one page in a record-keeper's voice -- the
## harvest and the table, the weather and trouble, the deeds, friendships, songs and gatherings -- drawn ONLY from what
## the village already recorded (the news, the incidents' lines, the farm's after-action record, the people's ledger,
## the songs). Presentation only: it reads those owners and writes its own pages, one Village news line a page, and
## nothing else.
##
## EACH FRAME (`poll`, on the one calendar; paused, nothing moves):
##   1. the season changed -> the season just ended is CLOSING: its tally takes its end snapshots (chronicle_tally.gd
##      `finish`) and a new tally opens for the new season;
##   2. new rows in the news (by entry id, `is_new_since`) are read into the tally of the season each was first said in;
##   3. a closing season's page is WRITTEN once the farm's record has closed its last day (farm_record.gd closes a day
##      at the farm hour after its midnight, once the kitchen has tallied its supper), so the page's harvest and meals
##      are the season's whole; a day past that it is written with what is kept. Written, it posts a Village news line
##      (an info note, kind `chronicle_page`) and calls THE TAPESTRY HOOK.
## When nothing has changed a frame reads two integers and makes nothing.
##
## THE DRAFT. `write_draft` writes the season still under way into a separate book (`draft()`), the same way, saying it
## is being written. The book view shows it beside the written pages, so a session that ends before its first season
## does still has a page to read. A draft uses up no village first.
##
## THE TAPESTRY HOOK. `page_written: (absolute_season: int, title: String, summary: String) -> void`, called once for
## each page written (never for a draft). The village sets it to weave the page into the great hall's tapestry
## (`demo_village.gd _weave_page`: tapestry.gd `add_entry(KIND_CHRONICLE, ...)`, decision 0902); unset, nothing is called.

const NoticesScript := preload("res://demo/demo_notices.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const RecordText := preload("res://demo/farm/farm_record_text.gd")
const FarmSim := preload("res://demo/farm/farm_sim.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const CircleScript := preload("res://demo/songs/song_circle.gd")
const BookScript := preload("res://demo/chronicle/chronicle_book.gd")
const TallyScript := preload("res://demo/chronicle/chronicle_tally.gd")
const WriterScript := preload("res://demo/chronicle/chronicle_writer.gd")
const Text := preload("res://demo/chronicle/chronicle_text.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## THE TAPESTRY HOOK (see above).
var page_written: Callable = Callable()
## The written pages, and the writer (its record, ledger, names, titles, seed and the village's firsts).
var book: BookScript = BookScript.new()
var writer: WriterScript = WriterScript.new()
## Bumped when a page is written (the book view redraws on it).
var revision: int = 0
var pages_written: int = 0

var _notices: NoticesScript = null
var _calendar: CalendarScript = null
var _circle: CircleScript = null
var _open: TallyScript = null
var _closing: TallyScript = null
var _seen_rows: int = 0
var _draft: BookScript = BookScript.new()


func configure(notices: NoticesScript, calendar: CalendarScript, record: RecordScript, people_ledger: Ledger,
		names: PackedStringArray, circle: CircleScript = null, song_titles: PackedStringArray = PackedStringArray(),
		seed_value: int = FarmSim.WEATHER_SEED) -> void:
	"""Read this feed on this calendar, the farm's record, the people's ledger and names, the songs (none: no songs),
	and write in the voice this seed picks. The season under way opens now; the feed's kept rows are read from the
	first (those of an earlier season are not this one's)."""
	name = "DemoChronicle"
	_notices = notices
	_calendar = calendar
	_circle = circle
	writer.record = record
	writer.ledger = people_ledger
	writer.names = names
	writer.song_titles = song_titles
	writer.seed_value = seed_value
	_seen_rows = 0
	_open = TallyScript.new(TallyScript.season_of_tick(calendar.tick) if calendar != null else 0)
	_open.begin(people_ledger, circle)
	_closing = null


func _process(_delta: float) -> void:
	"""One frame (see EACH FRAME)."""
	poll()


func poll() -> void:
	"""Roll the season, read the news's new rows, write a closing season's page when its record is whole."""
	if _calendar == null or _open == null:
		return
	var season: int = TallyScript.season_of_tick(_calendar.tick)
	if season != _open.season:
		_roll(season)
	if _notices != null and _notices.rows_posted != _seen_rows:
		_scan()
	if _closing != null and _closing_ready():
		_write(_closing)
		_closing = null


func _roll(season: int) -> void:
	"""The season ended: it closes (a page still waiting is written now, with what is kept), a new tally opens."""
	if _closing != null:
		_write(_closing)
	_open.finish(writer.ledger, _circle)
	_closing = _open
	_open = TallyScript.new(season)
	_open.begin(writer.ledger, _circle)


func _scan() -> void:
	"""Every row the feed wrote since the last look, into the tally of the season it was first said in."""
	for k: int in _notices.count():
		if not _notices.is_new_since(k, _seen_rows):
			continue
		var tally: TallyScript = tally_of(TallyScript.season_of_tick(_notices.first_tick(k)))
		if tally != null:
			tally.read_row(_notices, k)
	_seen_rows = _notices.rows_posted


func tally_of(season: int) -> TallyScript:
	"""The open or closing tally of an absolute season (null: neither -- an earlier season's row)."""
	if _open != null and _open.season == season:
		return _open
	return _closing if _closing != null and _closing.season == season else null


func _closing_ready() -> bool:
	"""Whether the closing season's record is whole: its last day closed, no record kept, or a day past its end."""
	var record: RecordScript = writer.record
	var next_first_day: int = (_closing.season + 1) * SimClock.DAYS_PER_SEASON
	if record == null or record.open_day() == RecordScript.NO_DAY or record.open_day() >= next_first_day:
		return true
	return TallyScript.day_of_tick(_calendar.tick) > next_first_day


func _write(tally: TallyScript) -> void:
	"""Write a season's page, keep its firsts, say so in the news and call the tapestry hook."""
	var page: int = writer.write(tally, book, false)
	writer.firsts = writer.firsts_after
	pages_written += 1
	revision += 1
	if _notices != null:
		_notices.notify(NoticesScript.SOURCE_VILLAGE, NoticesScript.TIER_INFO, Text.PAGE_KIND,
			Text.PAGE_NOTICE % RecordText.season_name(tally.season), "", Text.PAGE_NOTICE_BRIEF)
	if page_written.is_valid():
		page_written.call(tally.season, book.title_of(page), book.line_text[book.page_first[page]])


# --- reading ------------------------------------------------------------------------------------------------------

func write_draft() -> BookScript:
	"""The season under way written as a draft (see THE DRAFT) into the draft book, which is returned."""
	_draft.clear()
	if _open == null:
		return _draft
	writer.knows_now = _circle.knows if _circle != null else PackedInt32Array()
	writer.write(_open, _draft, true)
	return _draft


func draft_key() -> Vector4i:
	"""What a page view depends on: pages written, the news rows read, the record's closes, the people's changes (the
	book view redraws when it moves)."""
	var record_revision: int = writer.record.revision if writer.record != null else 0
	var ledger_revision: int = writer.ledger.revision if writer.ledger != null else 0
	return Vector4i(revision, _seen_rows, record_revision, ledger_revision)


func draft() -> BookScript:
	"""The draft book (as last written by `write_draft`)."""
	return _draft


func ledger() -> Ledger:
	"""The people's ledger (a page's deeds are shown by its curation)."""
	return writer.ledger


func open_season() -> int:
	"""The absolute season under way (-1 before `configure`)."""
	return _open.season if _open != null else -1


func open_tally() -> TallyScript:
	"""The season under way's tally (checks)."""
	return _open


func closing_tally() -> TallyScript:
	"""The ended season's tally waiting for its record (null: none)."""
	return _closing


func seen_rows() -> int:
	"""The feed's rows read so far (by entry id)."""
	return _seen_rows
