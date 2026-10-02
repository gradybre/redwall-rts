extends "res://test/framework/test_case.gd"
## The village chronicle (decision 0631, feature #10): a page at each season's end written only from what the village
## recorded -- the words and their deterministic variety, the season's tally of the news read by entry id, the book and
## the player's curation read when shown, the writer's sections, and the owner rolling the season on the one calendar
## and writing the page once the farm's record has closed its last day. No scene tree and no staged assets: the farm is
## test_demo_farm_ui.gd's off-tree village.

const Text := preload("res://demo/chronicle/chronicle_text.gd")
const TallyScript := preload("res://demo/chronicle/chronicle_tally.gd")
const BookScript := preload("res://demo/chronicle/chronicle_book.gd")
const WriterScript := preload("res://demo/chronicle/chronicle_writer.gd")
const ChronicleScript := preload("res://demo/chronicle/demo_chronicle.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const CircleScript := preload("res://demo/songs/song_circle.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const GuideText := preload("res://demo/guide/guide_text.gd")
const ProjectsScript := preload("res://demo/guide/projects.gd")
const FarmUiTest := preload("res://test/test_demo_farm_ui.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const NAMES: Array[String] = ["Wenna Tallowby", "Jory Whitethorn", "Linnet Whinberry", "Tobit Highbough",
	"Tegwin Slipstone", "Corra Netley", "Tuppen Clayholm", "Hulda Slatebrook", "Elstan Weirholt"]
const TITLES: Array[String] = ["The Long Pull", "Lift and Lay", "Set the Board", "The Heron's Hour"]
const DAY_TICKS: int = SimClock.TICKS_PER_DAY
## The first tick of season 1 (summer of year 1): day 12's 00:00.
const SUMMER_TICK: int = 12 * DAY_TICKS - SimClock.CALENDAR_OFFSET_TICKS
const CARROT: int = 2
const RADISH: int = 0
const WHEAT: int = 13
const SEED: int = 196


## A record whose season figures a test sets directly (season-blind: every season reads the same).
class FakeRecord extends "res://demo/farm/farm_record.gd":
	var totals: Dictionary = {}
	var items: Dictionary = {}
	var days: int = 12
	var events: PackedInt32Array = PackedInt32Array()
	## Days whose weather the record never saw.
	var unseen: PackedInt32Array = PackedInt32Array()

	func season_days(_absolute_season: int) -> int:
		"""The days kept: `days`."""
		return days

	func season_total(_absolute_season: int, field: int) -> int:
		"""`totals[field]` (0 unset)."""
		return int(totals.get(field, 0))

	func season_item_total(_absolute_season: int, group: int, item: int) -> int:
		"""`items[item]` for the harvested group (0 otherwise)."""
		return int(items.get(item, 0)) if group == G_HARVESTED else 0

	func day_count() -> int:
		"""One kept day per `events` entry."""
		return events.size()

	func value(k: int, field: int) -> int:
		"""Day `k` is calendar day k, seen unless in `unseen`, with event `events[k]`."""
		if field == F_DAY:
			return k
		if field == F_EVENT:
			return events[k]
		if field == F_WEATHER_SEEN:
			return 0 if unseen.has(k) else 1
		return 0


var _ui: FarmUiTest = null
var _nodes: Array[Node] = []
## The calendar `_feed()` stamps with (tests move its tick).
var _calendar: CalendarScript = null


func before_each() -> void:
	"""Nothing built yet."""
	_ui = null


func after_each() -> void:
	"""Free what was built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	if _ui != null:
		_ui.after_each()
		_ui = null


func _names() -> PackedStringArray:
	"""The nine residents' names."""
	return PackedStringArray(NAMES)


func _ledger() -> Ledger:
	"""People memory for the nine."""
	var ledger := Ledger.new()
	ledger.setup(NAMES.size())
	return ledger


func _feed() -> NoticesScript:
	"""A feed on a calendar at spring 1 (`_calendar`)."""
	var feed := NoticesScript.new()
	_calendar = CalendarScript.new()
	feed.bind_calendar(_calendar)
	return feed


func _writer(record: RecordScript = null, ledger: Ledger = null) -> WriterScript:
	"""A writer over these, the nine names and the four song titles, seeded."""
	var writer := WriterScript.new()
	writer.record = record
	writer.ledger = ledger
	writer.names = _names()
	writer.song_titles = PackedStringArray(TITLES)
	writer.seed_value = SEED
	return writer


func _page(writer: WriterScript, tally: TallyScript, draft: bool = false) -> String:
	"""The page `writer` writes of `tally`, as shown with its ledger's curation."""
	var book := BookScript.new()
	var page: int = writer.write(tally, book, draft)
	return book.page_text(page, writer.ledger)


func _harvest_record() -> FakeRecord:
	"""A season that stored 41.2 U (carrot, wheat, radish and a fourth item), ate 96 portions and lost nobody a meal."""
	var record := FakeRecord.new()
	record.totals = {RecordScript.F_HARVESTED: 41200, RecordScript.F_PORTIONS: 96}
	record.items = {CARROT: 20000, WHEAT: 12000, RADISH: 8000, 4: 1200}
	return record


# --- the words ------------------------------------------------------------------------------------------------------

func test_pick_is_deterministic_in_range_and_varies_by_season() -> void:
	"""The same seed, season and slot always pick the same wording; every pick is in range; seasons differ."""
	var seen := {}
	for season: int in 16:
		var first: int = Text.pick(SEED, season, 0, 3)
		assert_equal(Text.pick(SEED, season, 0, 3), first, "season %d picks the same twice" % season)
		assert_true(first >= 0 and first < 3, "in range")
		seen[first] = true
	assert_equal(seen.size(), 3, "sixteen seasons use all three wordings")
	assert_equal([Text.pick(SEED, 5, 0, 1), Text.pick(SEED, 5, 0, 0)], [0, 0], "one wording or none: the first")
	assert_true(Text.mix(-7, -3, -1) >= 0 and Text.mix(SEED, 3, 2) != Text.mix(SEED + 1, 3, 2), "non-negative, seeded")


func test_titles_years_and_season_names() -> void:
	"""'Spring, in the village's first year'; the tenth year in words, the eleventh as a number; tabs 'Summer Y2'."""
	assert_equal(Text.page_title(0, false), "Spring, in the village's first year", "the first page")
	assert_equal(Text.page_title(5, true), "Summer, in the village's second year — being written", "a draft")
	assert_equal([Text.year_word(39), Text.year_word(40), Text.year_word(-4)], ["tenth", "11th", "first"], "years")
	assert_equal([Text.short_name(0), Text.short_name(7), Text.season_word(-1)], ["Spring Y1", "Winter Y2", "Winter"],
		"tabs and names")


func test_counts_lists_and_capitals_in_words() -> void:
	"""'a day' / '3 days'; 'a', 'a and b', 'a, b and c'; a capital first letter."""
	assert_equal([Text.count_words(1, Text.DAY_NOUNS), Text.count_words(3, Text.DAY_NOUNS)], ["a day", "3 days"], "nouns")
	assert_equal([Text.list_words(PackedStringArray()), Text.list_words(PackedStringArray(["a"])),
		Text.list_words(PackedStringArray(["a", "b"])), Text.list_words(PackedStringArray(["a", "b", "c"]))],
		["", "a", "a and b", "a, b and c"], "lists")
	assert_equal([Text.capitalised("a tunnel"), Text.capitalised("")], ["A tunnel", ""], "capitals")


func test_the_words_carry_no_canon_name() -> void:
	"""Original wording only (the setting's lore rule): no book's place or name in any line the chronicle writes."""
	var all := PackedStringArray([Text.BOOK_TITLE, Text.PAGE_TITLE, Text.GUIDE_DONE, Text.PROJECT_DONE, Text.DRIFTED])
	for group: Array in Text.OPENINGS:
		for words: String in group:
			all.append(words)
	all.append_array(Text.CLOSINGS)
	all.append_array(Text.TROUBLES)
	all.append_array(Text.WEATHER_EVENTS)
	var text: String = " ".join(all).to_lower()
	for canon: String in ["redwall", "mossflower", "salamandastron", "abbey", "martin", "noonvale", "kotir"]:
		assert_false(text.contains(canon), "no '%s'" % canon)


# --- the tally ------------------------------------------------------------------------------------------------------

func test_a_tick_falls_in_its_season_and_day() -> void:
	"""Spring's last tick is season 0, summer's first is season 1; days by the offset calendar."""
	assert_equal([TallyScript.season_of_tick(0), TallyScript.season_of_tick(SUMMER_TICK - 1),
		TallyScript.season_of_tick(SUMMER_TICK)], [0, 0, 1], "the season boundary at summer 1, 00:00")
	assert_equal([TallyScript.day_of_tick(0), TallyScript.day_of_tick(13499), TallyScript.day_of_tick(13500)], [0, 0, 1],
		"spring 1 ends at midnight")
	assert_equal(TallyScript.season_of_tick(-99999), 0, "before the calendar: the first spring")


func test_the_owners_prefixes() -> void:
	"""The supper songs' and projects' lines are recognised by their owners' own constants."""
	assert_equal(TallyScript.supper_prefix(), "At supper ", "song_circle.gd SUPPER_LINE")
	assert_equal(TallyScript.project_prefix(), "Project complete: \"", "projects.gd CHRONICLE")


func test_troubles_count_once_per_subject_or_day() -> void:
	"""Two trees blown down and one twice: 2 trees. Frost said twice on spring 1 and once on spring 2: 2 nights. A
	routine line is not the chronicle's."""
	var feed := _feed()
	var incidents := IncidentsScript.new()
	incidents.bind(feed, _calendar, null)
	var tally := TallyScript.new(0)
	for key: String in ["woods:windthrow:4", "woods:windthrow:9", "woods:windthrow:4", "farm:frost", "farm:frost"]:
		incidents.report(key, NoticesScript.SOURCE_WOODS, IncidentsScript.SEVERITY_WARNING, "It happened: " + key)
		assert_true(tally.read_row(feed, 0), "%s is the chronicle's" % key)
	_calendar.tick = DAY_TICKS
	incidents.report("farm:frost", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Frost again")
	tally.read_row(feed, 0)
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Bed 3 is dry")
	assert_false(tally.read_row(feed, 0), "a routine line is not")
	assert_equal([tally.troubles[TallyScript.TROUBLE_WINDTHROW], tally.troubles[TallyScript.TROUBLE_FROST]], [2, 2],
		"two trees, two nights")
	assert_equal(tally.rows_read, 7, "every row offered was read")
	assert_true(tally.any_trouble(), "trouble counted")


func test_occasions_are_the_village_s_chronicle_lines() -> void:
	"""A Village 'Chronicle:' line, the guide's completion and a project done are kept; the crew's pinned 'Chronicle:'
	(the people's, read from the ledger) and any other Village line are not."""
	var feed := _feed()
	var tally := TallyScript.new(0)
	feed.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, "Chronicle: the summer regatta was held")
	assert_true(tally.read_row(feed, 0), "the regatta's line")
	feed.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, GuideText.CHRONICLE_COMPLETE % "with a bridge")
	assert_true(tally.read_row(feed, 0), "the first village")
	feed.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, ProjectsScript.CHRONICLE % ["Winter larder",
		"ready food", "0 U", "40 U", "40 U"])
	assert_true(tally.read_row(feed, 0), "a project")
	feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Chronicle: Corra Netley brought Tobit ashore (Spring 4)")
	assert_false(tally.read_row(feed, 0), "the people's pinned deed is the ledger's")
	feed.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, "The chronicle's page for Spring is written")
	assert_false(tally.read_row(feed, 0), "the chronicle's own notice is not an occasion")
	assert_equal(tally.occasion_kind, PackedByteArray([TallyScript.OCCASION_CHRONICLE, TallyScript.OCCASION_GUIDE,
		TallyScript.OCCASION_PROJECT]), "three occasions")
	assert_equal(tally.occasion_text, PackedStringArray(["the summer regatta was held", "", "Winter larder"]), "their words")


func test_occasions_are_capped_and_kinds_checked() -> void:
	"""At most MAX_OCCASIONS; an unknown kind is refused."""
	var tally := TallyScript.new(0)
	for k: int in TallyScript.MAX_OCCASIONS:
		assert_true(tally.add_occasion(TallyScript.OCCASION_CHRONICLE, "a day %d" % k), "occasion %d kept" % k)
	assert_false(tally.add_occasion(TallyScript.OCCASION_CHRONICLE, "one more"), "past the cap")
	assert_false(TallyScript.new(0).add_occasion(TallyScript.OCCASION_PROJECT + 1, "x"), "unknown kind")
	assert_false(TallyScript.new(0).add_occasion(-1, "x"), "negative kind")


func test_supper_songs_count_their_days() -> void:
	"""Two supper lines on spring 1 and one on spring 2: two evenings."""
	var feed := _feed()
	var tally := TallyScript.new(0)
	for day: int in [0, 0, 1]:
		_calendar.tick = day * DAY_TICKS
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, CircleScript.SUPPER_LINE % ["Corra Netley",
			"Set the Board %d" % feed.rows_posted])
		assert_true(tally.read_row(feed, 0), "a supper song")
	assert_equal(tally.supper_song_days, 2, "two evenings")


func test_distinct_keys_stop_at_max_seen() -> void:
	"""Past MAX_SEEN distinct keys a season counts nothing new (a bound, not a leak)."""
	var feed := _feed()
	var incidents := IncidentsScript.new()
	incidents.bind(feed, _calendar, null)
	var tally := TallyScript.new(0)
	for tree: int in TallyScript.MAX_SEEN + 3:
		feed.post(NoticesScript.SOURCE_WOODS, NoticesScript.LEVEL_WARNING, "Tree %d down" % tree, "",
			NoticesScript.TARGET_NONE, -1, NoticesScript.NO_INCIDENT, NoticesScript.TIER_NORMAL, &"woods:windthrow",
			"%d" % tree)
		tally.read_row(feed, 0)
	assert_equal(tally.seen_count(), TallyScript.MAX_SEEN, "the bound")
	assert_equal(tally.troubles[TallyScript.TROUBLE_WINDTHROW], TallyScript.MAX_SEEN, "counted to it")


func test_snapshots_are_copies() -> void:
	"""`begin` and `finish` copy the friend flags, hours and songs known; later changes do not reach a snapshot."""
	var ledger := _ledger()
	var circle := CircleScript.new()
	circle.knows = PackedInt32Array([15, 0, 0])
	var tally := TallyScript.new(0)
	tally.begin(ledger, circle)
	ledger.add_shared_work(1, 2, 2 * Ledger.SHARED_HOUR_TICKS, 0)
	circle.knows[1] = 2
	tally.finish(ledger, circle)
	ledger.add_shared_work(1, 2, Ledger.SHARED_HOUR_TICKS, 0)
	var p: int = ledger.pair(1, 2)
	assert_equal([tally.hours_start[p], tally.hours_end[p], ledger.shared_hours[p]], [0, 2, 3], "hours copied")
	assert_equal([tally.knows_start[1], tally.knows_end[1]], [0, 2], "songs copied")
	for k: int in 5:
		ledger.add_rescue(1, 2, 0)
	assert_equal([ledger.friend[p], tally.friend_end[p]], [1, 0], "friends copied, not shared")
	assert_true(tally.ended, "finished")
	var bare := TallyScript.new(0)
	bare.begin(null, null)
	bare.finish(null, null)
	assert_equal([bare.friend_start.size(), bare.knows_end.size()], [0, 0], "nothing to copy: empty")


# --- the book -------------------------------------------------------------------------------------------------------

func test_the_book_refuses_lines_out_of_place() -> void:
	"""No page begun, empty words, a style or section out of range: refused."""
	var book := BookScript.new()
	assert_false(book.add_line("a line", BookScript.STYLE_TEXT, BookScript.SECTION_TABLE), "no page begun")
	assert_equal(book.begin_page(3, "Winter"), 0, "page 0")
	assert_false(book.add_line("", BookScript.STYLE_TEXT, BookScript.SECTION_TABLE), "empty")
	assert_false(book.add_line("x", BookScript.STYLE_NOTE + 1, BookScript.SECTION_TABLE), "style")
	assert_false(book.add_line("x", BookScript.STYLE_OPENING - 1, BookScript.SECTION_TABLE), "style below")
	assert_false(book.add_line("x", BookScript.STYLE_TEXT, BookScript.SECTION_CLOSING + 1), "section")
	assert_false(book.add_line("x", BookScript.STYLE_TEXT, BookScript.SECTION_OPENING - 1), "section below")
	assert_true(book.add_line("x", BookScript.STYLE_CLOSING, BookScript.SECTION_CLOSING), "the closing")
	assert_equal([book.page_count(), book.page_lines[0], book.index_of_season(3), book.index_of_season(4)], [1, 1, 0, -1],
		"one page, one line")
	assert_equal([book.title_of(1), book.season_of(-1), book.lines_into(5, null, PackedStringArray(),
		PackedByteArray())], ["", -1, 0], "out of range")
	book.clear()
	assert_equal(book.page_count(), 0, "cleared")


func test_the_book_keeps_max_pages_and_moves_the_lines_up() -> void:
	"""Past MAX_PAGES the oldest page and its lines go; every later page still shows its own lines."""
	var book := BookScript.new()
	for season: int in BookScript.MAX_PAGES + 2:
		book.begin_page(season, "Page %d" % season)
		for k: int in season % 3 + 1:
			book.add_line("Season %d line %d" % [season, k], BookScript.STYLE_TEXT, BookScript.SECTION_TABLE)
	assert_equal([book.page_count(), book.season_of(0)], [BookScript.MAX_PAGES, 2], "the two oldest gone")
	var words := PackedStringArray()
	var styles := PackedByteArray()
	for page: int in book.page_count():
		var season: int = book.season_of(page)
		book.lines_into(page, null, words, styles)
		assert_equal([words.size(), words[0]], [season % 3 + 1, "Season %d line 0" % season], "page %d's lines" % page)
	assert_true(book.add_line("late line", BookScript.STYLE_TEXT, BookScript.SECTION_TABLE), "the last page takes more")
	book.lines_into(book.page_count() - 1, null, words, styles)
	assert_equal(words[words.size() - 1], "late line", "on the last page")


func test_deeds_show_the_player_s_curation() -> void:
	"""Pinned first, then uncurated, at most DEEDS_SHOWN; private and dismissed never; no deed left -- no heading."""
	var ledger := _ledger()
	var deeds := PackedInt32Array()
	for k: int in 5:
		deeds.append(ledger.record(Ledger.KIND_SKILL, k, 0, 0, Ledger.NOBODY, 0, -1, "Felling", 2))
	var book := BookScript.new()
	book.begin_page(0, "Spring")
	book.add_line("Deeds", BookScript.STYLE_HEADING, BookScript.SECTION_DEEDS)
	for k: int in 5:
		book.add_line("Deed %d" % k, BookScript.STYLE_TEXT, BookScript.SECTION_DEEDS, deeds[k])
	book.add_line("So ends", BookScript.STYLE_CLOSING, BookScript.SECTION_CLOSING)
	ledger.curate(deeds[0], Ledger.CURATION_PRIVATE)
	ledger.curate(deeds[1], Ledger.CURATION_DISMISSED)
	ledger.curate(deeds[4], Ledger.CURATION_PINNED)
	var words := PackedStringArray()
	var styles := PackedByteArray()
	book.lines_into(0, ledger, words, styles)
	assert_equal(words, PackedStringArray(["Deeds", "Deed 2", "Deed 3", "Deed 4", "So ends"]),
		"the pinned one kept, in page order")
	for k: int in [2, 3]:
		ledger.curate(deeds[k], Ledger.CURATION_PRIVATE)
	book.lines_into(0, ledger, words, styles)
	assert_equal(words, PackedStringArray(["Deeds", "Deed 4", "So ends"]), "the pinned one alone")
	ledger.curate(deeds[4], Ledger.CURATION_DISMISSED)
	book.lines_into(0, ledger, words, styles)
	assert_equal(words, PackedStringArray(["So ends"]), "no deed: no heading")
	assert_equal(styles, PackedByteArray([BookScript.STYLE_CLOSING]), "styles follow")


func test_deeds_shown_stop_at_the_cap_pinned_first() -> void:
	"""Five uncurated deeds and one pinned last: the pinned and the first two uncurated."""
	var ledger := _ledger()
	var book := BookScript.new()
	book.begin_page(0, "Spring")
	book.add_line("Deeds", BookScript.STYLE_HEADING, BookScript.SECTION_DEEDS)
	var last: int = -1
	for k: int in 6:
		last = ledger.record(Ledger.KIND_SKILL, k, 0, 0)
		book.add_line("Deed %d" % k, BookScript.STYLE_TEXT, BookScript.SECTION_DEEDS, last)
	ledger.curate(last, Ledger.CURATION_PINNED)
	var words := PackedStringArray()
	book.lines_into(0, ledger, words, PackedByteArray())
	assert_equal(words, PackedStringArray(["Deeds", "Deed 0", "Deed 1", "Deed 5"]), "DEEDS_SHOWN, pinned among them")
	book.lines_into(0, null, words, PackedByteArray())
	assert_equal(words.size(), 1 + BookScript.DEEDS_SHOWN, "no ledger: uncurated, capped")


# --- the writer -----------------------------------------------------------------------------------------------------

func test_a_bare_season_is_one_honest_line() -> void:
	"""Nothing recorded: the bare opening and the closing, no section at all."""
	var writer := _writer()
	var tally := TallyScript.new(0)
	assert_equal(writer.mood(tally), WriterScript.MOOD_BARE, "bare")
	var text: String = _page(writer, tally)
	assert_equal(text.split("\n").size(), 3, "title, opening, closing: %s" % text)
	assert_true(text.contains(Text.OPENINGS[WriterScript.MOOD_BARE][0]), "the bare opening")
	assert_false(text.contains("The harvest and the table"), "no section")


func test_the_harvest_and_the_table() -> void:
	"""Food into store with its three largest items and how many more, portions eaten, nobody went without; the
	village's first food and first meals told once."""
	var writer := _writer(_harvest_record())
	var text: String = _page(writer, TallyScript.new(0))
	assert_true(text.contains("41.2 U") and text.contains("carrot 20.0 U, wheat 12.0 U, radish 8.0 U and 1 more"), text)
	assert_true(text.contains(Text.FIRST_HARVEST) and text.contains(Text.FIRST_MEALS), "the firsts")
	assert_true(text.contains("96 portions") and text.contains(Text.NONE_WITHOUT), "the table")
	assert_equal(writer.firsts_after, WriterScript.FIRST_FOOD | WriterScript.FIRST_MEALS, "two firsts used")
	writer.firsts = writer.firsts_after
	var again: String = _page(writer, TallyScript.new(1))
	assert_false(again.contains(Text.FIRST_HARVEST) or again.contains(Text.FIRST_MEALS), "told once in the village's life")
	assert_equal(writer.mood(TallyScript.new(0)), WriterScript.MOOD_STEADY, "a steady season")


func test_a_hard_season_says_who_went_without_and_what_was_lost() -> void:
	"""Went without twice, one crop lost, nothing stored: said plainly, in the hard mood."""
	var record := FakeRecord.new()
	record.totals = {RecordScript.F_WITHOUT: 2, RecordScript.F_LOST: 1, RecordScript.F_PORTIONS: 30}
	var writer := _writer(record)
	var tally := TallyScript.new(0)
	var text: String = _page(writer, tally)
	assert_true(text.contains(Text.HARVEST_NONE), "nothing stored")
	assert_true(text.contains("A meal was missed 2 times, counting each resident who went without."), text)
	assert_true(text.contains("A crop withered in the beds."), text)
	assert_false(text.contains(Text.NONE_WITHOUT), "never 'nobody' when somebody did")
	assert_equal(writer.mood(tally), WriterScript.MOOD_HARD, "hard")
	record.totals = {RecordScript.F_LOST: 3}
	assert_equal(writer.mood(tally), WriterScript.MOOD_LOSS, "a crop lost alone is a loss, not hunger")
	for words: String in Text.OPENINGS[WriterScript.MOOD_LOSS]:
		assert_false(words.contains("bowl") or words.contains("hard"), "a loss claims no hunger: " + words)
	record.totals = {RecordScript.F_LOST: 3, RecordScript.F_WITHOUT: 1}
	var again: String = _page(writer, tally)
	assert_true(again.contains("3 crops withered in the beds.") and again.contains(Text.WENT_WITHOUT_ONCE), again)


func test_no_record_or_no_day_closed_has_no_table() -> void:
	"""Without a record, or before its first day closes, the table section is left out."""
	var record := FakeRecord.new()
	record.days = 0
	record.totals = {RecordScript.F_HARVESTED: 5000}
	assert_false(_page(_writer(record), TallyScript.new(0)).contains("The harvest and the table"), "no day closed")
	assert_false(_page(_writer(null), TallyScript.new(0)).contains("The harvest and the table"), "no record")


func test_weather_events_and_troubles() -> void:
	"""The season's event and its days, then the troubles, at most MAX_WEATHER_LINES, in the weather mood."""
	var record := FakeRecord.new()
	record.days = 3
	record.events = PackedInt32Array([WeatherScript.EVENT_NONE, WeatherScript.EVENT_HEAVY_RAIN,
		WeatherScript.EVENT_HEAVY_RAIN])
	var tally := TallyScript.new(0)
	tally.troubles[TallyScript.TROUBLE_WINDTHROW] = 1
	tally.troubles[TallyScript.TROUBLE_TUNNEL_FLOODED] = 2
	tally.troubles[TallyScript.TROUBLE_FROST] = 1
	tally.troubles[TallyScript.TROUBLE_NO_BED] = 4
	var writer := _writer(record)
	var text: String = _page(writer, tally)
	assert_true(text.contains("Heavy rain fell for 2 days."), text)
	assert_true(text.contains("The wind brought down a tree."), text)
	assert_true(text.contains("2 tunnels flooded."), text)
	assert_true(text.contains("Frost came on one night."), text)
	assert_false(text.contains("without a bed"), "the fifth line is past the cap")
	assert_equal(writer.mood(tally), WriterScript.MOOD_WEATHER, "weathered")
	tally.troubles.fill(0)
	assert_equal(writer.mood(tally), WriterScript.MOOD_WEATHER, "the event alone is weather")


func test_every_trouble_is_worded() -> void:
	"""Each TROUBLE_* has its line, singular and plural, starting with a capital."""
	for trouble: int in TallyScript.TROUBLE_COUNT:
		for count: int in [1, 3]:
			var words: String = Text.capitalised(Text.TROUBLES[trouble] % Text.count_words(count,
				Text.TROUBLE_NOUNS[trouble]))
			assert_true(words.substr(0, 1) == words.substr(0, 1).to_upper() and words.ends_with("."), words)
			assert_true(words.contains("3") == (count == 3), "%d in %s" % [count, words])


func test_deeds_best_first_with_village_firsts() -> void:
	"""A rescue before a bridge before a skill; the first bridge and rescue marked; other seasons' and untold kinds out."""
	var ledger := _ledger()
	ledger.record(Ledger.KIND_SKILL, 3, 0, 0, Ledger.NOBODY, 0, -1, "Felling", 3)
	ledger.record(Ledger.KIND_BRIDGE, 8, 0, 0, Ledger.NOBODY, 0, -1, "neck bridge")
	ledger.record(Ledger.KIND_RESCUE, 5, 0, 0, 6)
	ledger.record(Ledger.KIND_BRIDGE, 8, 0, 1, Ledger.NOBODY, 0, -1, "weir bridge")
	var writer := _writer(null, ledger)
	var book := BookScript.new()
	writer.write(TallyScript.new(0), book, false)
	var words := PackedStringArray()
	book.lines_into(0, ledger, words, PackedByteArray())
	var at: int = words.find("Deeds")
	assert_true(at > 0, "a Deeds section")
	assert_equal(words.slice(at + 1, at + 4), PackedStringArray([
		"Corra Netley brought Tuppen Clayholm ashore — the village's first.",
		"Elstan Weirholt built the neck bridge — the village's first.",
		"Tobit Highbough reached Felling · Level 3."]), "best first, firsts marked")
	writer.firsts = writer.firsts_after
	var summer: String = _page(writer, TallyScript.new(1))
	assert_true(summer.contains("Elstan Weirholt built the weir bridge."), summer)
	assert_false(summer.contains("the village's first."), "a second bridge is no first")


func test_friends_made_lapsed_and_working_side_by_side() -> void:
	"""Friendship made this season (REQ-SET-037's 40), one lapsed (below 25), and the pair with the most hours."""
	var ledger := _ledger()
	for k: int in 5:
		ledger.add_rescue(2, 7, 0)
	var tally := TallyScript.new(0)
	tally.begin(ledger, null)
	for day: int in range(3, 20):
		ledger.midnight(day)
	for k: int in 5:
		ledger.add_rescue(0, 1, 20)
	ledger.add_shared_work(3, 4, 6 * Ledger.SHARED_HOUR_TICKS, 20)
	ledger.add_shared_work(5, 6, 4 * Ledger.SHARED_HOUR_TICKS, 20)
	tally.finish(ledger, null)
	assert_true(ledger.are_friends(0, 1) and not ledger.are_friends(2, 7), "made and lapsed")
	var text: String = _page(_writer(null, ledger), tally)
	assert_true(text.contains("Wenna Tallowby") and text.contains("Jory Whitethorn"), text)
	assert_true(text.contains(Text.DRIFTED % ["Linnet Whinberry", "Hulda Slatebrook"]), text)
	assert_true(text.contains("Tobit Highbough") and text.contains("Tegwin Slipstone") and text.contains("6 hours"), text)
	assert_false(text.contains("Corra Netley"), "only the pair who worked most")


func test_working_together_needs_worked_least_hours() -> void:
	"""Two hours together is not told; the draft reads the ledger as it stands."""
	var ledger := _ledger()
	var tally := TallyScript.new(0)
	tally.begin(ledger, null)
	ledger.add_shared_work(3, 4, (WriterScript.WORKED_LEAST - 1) * Ledger.SHARED_HOUR_TICKS, 0)
	assert_false(_page(_writer(null, ledger), tally, true).contains("Friends and neighbours"), "too few hours")
	ledger.add_shared_work(3, 4, Ledger.SHARED_HOUR_TICKS, 0)
	assert_true(_page(_writer(null, ledger), tally, true).contains("%d hours" % WriterScript.WORKED_LEAST), "enough")


func test_songs_and_gatherings() -> void:
	"""Occasions as their owners wrote them, songs learned (start against end), supper evenings; a gathering mood."""
	var tally := TallyScript.new(0)
	tally.add_occasion(TallyScript.OCCASION_CHRONICLE, "the summer regatta was held. The moment: a close finish")
	tally.add_occasion(TallyScript.OCCASION_GUIDE, "")
	tally.add_occasion(TallyScript.OCCASION_PROJECT, "Winter larder")
	tally.knows_start = PackedInt32Array([0, 0, 0])
	tally.knows_end = PackedInt32Array([0, 0, 2])
	tally.ended = true
	tally.supper_song_days = 3
	var writer := _writer()
	var text: String = _page(writer, tally)
	assert_true(text.contains("The summer regatta was held. The moment: a close finish."), text)
	assert_true(text.contains(Text.GUIDE_DONE) and text.contains("“Winter larder”"), text)
	assert_true(text.contains("Linnet Whinberry learned “Lift and Lay”."), text)
	assert_true(text.contains("3 evenings"), text)
	assert_equal(writer.mood(tally), WriterScript.MOOD_OCCASION, "an occasion")
	assert_equal(WriterScript.occasion_line(TallyScript.OCCASION_CHRONICLE, "they sang!"), "They sang!", "no extra stop")


func test_a_draft_says_so_and_has_no_closing() -> void:
	"""The season under way: the draft title and note (days recorded), no closing; it uses up no first."""
	var record := _harvest_record()
	record.days = 4
	var writer := _writer(record)
	var book := BookScript.new()
	writer.write(TallyScript.new(0), book, true)
	var text: String = book.page_text(0, null)
	assert_true(text.begins_with(Text.page_title(0, true)), text)
	assert_true(text.contains(Text.DRAFT_NOTE % "4 days recorded"), text)
	assert_equal(book.line_style[book.line_style.size() - 1], BookScript.STYLE_TEXT, "no closing")
	assert_equal(writer.firsts, 0, "no first used")
	record.days = 0
	assert_true(_page(_writer(record), TallyScript.new(0), true).contains(Text.DRAFT_NOTE % Text.DRAFT_NO_DAYS), "none")


func test_the_same_village_writes_the_same_page() -> void:
	"""Deterministic per seed: two writers, one seed, the same page; another seed may word it differently."""
	var tally := TallyScript.new(2)
	tally.troubles[TallyScript.TROUBLE_FROST] = 2
	var first: String = _page(_writer(_harvest_record()), tally)
	assert_equal(_page(_writer(_harvest_record()), tally), first, "the same page")
	var differs: bool = false
	for seed_value: int in range(1, 12):
		var writer: WriterScript = _writer(_harvest_record())
		writer.seed_value = seed_value
		differs = differs or _page(writer, tally) != first
	assert_true(differs, "other seeds word it otherwise")


# --- the owner ------------------------------------------------------------------------------------------------------

func _farm_chronicle() -> Array:
	"""[farm, chronicle, ledger]: the off-tree farm's news, calendar and record, a ledger for the nine."""
	_ui = FarmUiTest.new()
	_ui.before_each()
	var farm: DemoFarmScript = _ui._farm()
	var ledger := _ledger()
	var chronicle := ChronicleScript.new()
	_nodes.append(chronicle)
	chronicle.configure(farm.services.notices, farm.services.calendar, farm.record, ledger, _names(), null,
		PackedStringArray(TITLES))
	return [farm, chronicle, ledger]


func _run_days(farm: DemoFarmScript, chronicle: ChronicleScript, days: int) -> void:
	"""Run the farm's calendar on a day at a time, the chronicle polling after each step."""
	for day: int in days:
		farm.advance_calendar(24 * CalendarScript.HOUR_USEC)
		chronicle.poll()


func test_a_page_is_written_once_the_season_s_record_is_whole() -> void:
	"""Spring ends at summer 1's midnight; its page waits for the farm's record to close spring 12, then is written once,
	posts its Village line and calls the tapestry hook with its season, title and opening."""
	var parts: Array = _farm_chronicle()
	var farm: DemoFarmScript = parts[0]
	var chronicle: ChronicleScript = parts[1]
	var called: Array = []
	chronicle.page_written = func(season: int, title: String, summary: String) -> void: called.append([season, title,
		summary])
	farm.services.incidents.report("woods:windthrow:3", NoticesScript.SOURCE_WOODS, IncidentsScript.SEVERITY_WARNING,
		"A tree came down")
	_run_days(farm, chronicle, 11)
	assert_equal([chronicle.pages_written, chronicle.open_season()], [0, 0], "spring 12 still")
	_run_days(farm, chronicle, 1)
	assert_equal(chronicle.open_season(), 1, "summer has begun")
	assert_equal(chronicle.book.page_count(), 1, "spring's page is written (its last day closed at the farm's hour)")
	var page: String = chronicle.book.page_text(0, null)
	assert_true(page.begins_with(Text.page_title(0, false)), page)
	assert_true(page.contains("The wind brought down a tree."), page)
	assert_true(page.contains("Heavy rain") or page.contains("fine growing weather"), "spring's §5.10 event: " + page)
	assert_equal(called.size(), 1, "the hook, once")
	assert_equal([called[0][0], called[0][1]], [0, Text.page_title(0, false)], "season and title")
	assert_true(farm.services.notices.has_text(Text.PAGE_NOTICE % "Spring, year 1"), "the Village line")
	_run_days(farm, chronicle, 2)
	assert_equal(chronicle.pages_written, 1, "written once")


func test_rows_go_to_the_season_they_were_said_in() -> void:
	"""A row said on spring 12 but read after the season rolled counts in spring; a row of summer in summer."""
	var parts: Array = _farm_chronicle()
	var farm: DemoFarmScript = parts[0]
	var chronicle: ChronicleScript = parts[1]
	_run_days(farm, chronicle, 11)
	farm.services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, "Chronicle: a spring gathering")
	farm.advance_calendar(24 * CalendarScript.HOUR_USEC)
	farm.services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, "Chronicle: a summer gathering")
	chronicle.poll()
	chronicle.poll()
	assert_true(chronicle.book.page_text(0, null).contains("A spring gathering."), "spring's")
	assert_false(chronicle.book.page_text(0, null).contains("summer gathering"), "not summer's")
	assert_equal(chronicle.open_tally().occasion_text, PackedStringArray(["a summer gathering"]), "summer's own")
	assert_equal(chronicle.seen_rows(), farm.services.notices.rows_posted, "every row read")


func test_a_grouped_repeat_is_not_read_twice() -> void:
	"""A named kind's repeat keeps its id and moves to the top: read once (by entry id), not again as 'newest'."""
	var parts: Array = _farm_chronicle()
	var chronicle: ChronicleScript = parts[1]
	var feed: NoticesScript = (parts[0] as DemoFarmScript).services.notices
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_NORMAL, &"village:no_bed", "Somebody has no bed", "x")
	chronicle.poll()
	var read: int = chronicle.open_tally().rows_read
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_NORMAL, &"village:no_bed", "Somebody has no bed again", "x")
	chronicle.poll()
	assert_equal(chronicle.open_tally().rows_read, read, "the grouped repeat wrote no new row")
	assert_equal(chronicle.open_tally().troubles[TallyScript.TROUBLE_NO_BED], 1, "one night")


func test_a_season_jump_writes_the_waiting_page_first() -> void:
	"""Two seasons end before the first's record is whole: the first page is written with what is kept, then the
	second waits for its own."""
	var parts: Array = _farm_chronicle()
	var farm: DemoFarmScript = parts[0]
	var chronicle: ChronicleScript = parts[1]
	farm.services.calendar.tick = SUMMER_TICK
	chronicle.poll()
	assert_true(chronicle.closing_tally() != null and chronicle.closing_tally().season == 0, "spring closing")
	farm.services.calendar.tick = SUMMER_TICK + 12 * DAY_TICKS
	chronicle.poll()
	assert_equal([chronicle.book.page_count(), chronicle.book.season_of(0)], [1, 0], "spring written on the jump")
	assert_equal(chronicle.closing_tally().season, 1, "summer closing now")
	farm.services.calendar.tick = SUMMER_TICK + 14 * DAY_TICKS
	chronicle.poll()
	assert_equal([chronicle.book.page_count(), chronicle.book.season_of(1)], [2, 1], "a day past its end: written")


func test_the_draft_is_the_season_so_far_and_writes_no_page() -> void:
	"""`write_draft` writes the season under way into its own book; the written pages and firsts are untouched."""
	var parts: Array = _farm_chronicle()
	var farm: DemoFarmScript = parts[0]
	var chronicle: ChronicleScript = parts[1]
	farm.pantry.add_into(CARROT, 5000, 0, IntMath.IntResult.new())
	_run_days(farm, chronicle, 3)
	var draft: BookScript = chronicle.write_draft()
	assert_true(draft.page_text(0, null).contains(Text.FIRST_HARVEST), "the draft tells the first food")
	assert_equal([draft.page_count(), draft.season_of(0), chronicle.book.page_count()], [1, 0, 0], "one draft page")
	assert_true(draft.page_text(0, null).contains("being written"), "it says so")
	assert_equal(chronicle.write_draft().page_count(), 1, "rewritten, not added to")
	assert_equal(chronicle.writer.firsts, 0, "no first used")
	_run_days(farm, chronicle, 10)
	assert_true(chronicle.book.page_text(0, null).contains(Text.FIRST_HARVEST), "the written page still tells it")
	var key: Vector4i = chronicle.draft_key()
	assert_equal(chronicle.draft_key(), key, "nothing moved")
	_run_days(farm, chronicle, 1)
	assert_true(chronicle.draft_key() != key, "a day closed: the key moved")


func test_an_unconfigured_chronicle_does_nothing() -> void:
	"""Before `configure`: no poll work, an empty draft, no season."""
	var chronicle := ChronicleScript.new()
	_nodes.append(chronicle)
	chronicle.poll()
	assert_equal([chronicle.open_season(), chronicle.write_draft().page_count(), chronicle.pages_written], [-1, 0, 0],
		"nothing")
	assert_null(chronicle.ledger(), "no ledger")


func test_polling_makes_no_object() -> void:
	"""The per-frame poll, idle and with rows to read, makes no Object."""
	var parts: Array = _farm_chronicle()
	var chronicle: ChronicleScript = parts[1]
	var feed: NoticesScript = (parts[0] as DemoFarmScript).services.notices
	chronicle.poll()
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for frame: int in 300:
		if frame % 60 == 0:
			feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, CircleScript.SUPPER_LINE % ["A", "B %d" % frame])
		chronicle.poll()
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), before, "no object made")
	assert_equal(chronicle.open_tally().supper_song_days, 1, "read (one day)")


func test_the_largest_items_ties_and_exactly_three() -> void:
	"""Equal stores keep the catalog's order; exactly three items name no 'more'; no portions says nothing of meals."""
	var record := FakeRecord.new()
	record.totals = {RecordScript.F_HARVESTED: 15000}
	record.items = {CARROT: 5000, RADISH: 5000, WHEAT: 5000}
	var writer := _writer(record)
	assert_equal(writer.top_items(0), "radish 5.0 U, carrot 5.0 U and wheat 5.0 U", "ties in catalog order, no more")
	var text: String = _page(writer, TallyScript.new(0))
	assert_false(text.contains(Text.NONE_WITHOUT), "no meal served: nothing said of going without")


func test_weather_lines_stop_at_the_cap_and_keep_to_their_season() -> void:
	"""Five events in spring: four lines. An event on summer's day is not spring's."""
	var record := FakeRecord.new()
	record.events = PackedInt32Array([WeatherScript.EVENT_BLIGHT, WeatherScript.EVENT_CALM_DAYS,
		WeatherScript.EVENT_DROUGHT, WeatherScript.EVENT_EARLY_FROST, WeatherScript.EVENT_HARD_FREEZE,
		-1, -1, -1, -1, -1, -1, -1, WeatherScript.EVENT_HEAVY_RAIN])
	var text: String = _page(_writer(record), TallyScript.new(0))
	var lines: int = 0
	for words: String in Text.WEATHER_EVENTS:
		lines += 1 if text.contains(words.get_slice("%s", 0)) else 0
	assert_equal(lines, WriterScript.MAX_WEATHER_LINES, "four lines: " + text)
	record.events = PackedInt32Array([WeatherScript.EVENT_DROUGHT, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		WeatherScript.EVENT_HEAVY_RAIN])
	var spring: String = _page(_writer(record), TallyScript.new(0))
	assert_true(spring.contains("Drought held for a day."), spring)
	assert_false(spring.contains("Heavy rain"), "summer's rain is summer's")


func test_a_song_known_before_the_season_is_not_learned_in_it() -> void:
	"""An otter who knew every song at the start learned none; a resident's new song is told."""
	var tally := TallyScript.new(0)
	tally.knows_start = PackedInt32Array([15, 0])
	tally.knows_end = PackedInt32Array([15, 1])
	tally.ended = true
	var text: String = _page(_writer(), tally)
	assert_false(text.contains("Wenna Tallowby learned"), "known already: " + text)
	assert_true(text.contains("Jory Whitethorn learned “The Long Pull”."), text)


func test_new_rows_are_read_by_id_not_as_the_newest_n() -> void:
	"""A grouped repeat moves an old row to the top as a new row arrives under it: the new row is read, the old not again."""
	var feed := _feed()
	var chronicle := ChronicleScript.new()
	_nodes.append(chronicle)
	chronicle.configure(feed, _calendar, null, _ledger(), _names())
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_INFO, &"crows", "Crows at the barley", "bed:1")
	chronicle.poll()
	feed.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, "Chronicle: a gathering")
	feed.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_INFO, &"crows", "Crows at the barley again", "bed:1")
	assert_equal(feed.entry_id(0), 1, "the crows' row moved to the top")
	chronicle.poll()
	assert_equal(chronicle.open_tally().occasion_text, PackedStringArray(["a gathering"]), "the new row read")
	assert_equal(chronicle.open_tally().rows_read, 2, "and the old one not again")


func test_the_owner_keeps_the_village_s_firsts_across_pages() -> void:
	"""A bridge in spring is the village's first; one in summer, on the next page, is not."""
	var feed := _feed()
	var ledger := _ledger()
	var chronicle := ChronicleScript.new()
	_nodes.append(chronicle)
	chronicle.configure(feed, _calendar, null, ledger, _names())
	ledger.record(Ledger.KIND_BRIDGE, 8, 0, 0, Ledger.NOBODY, 0, -1, "neck bridge")
	ledger.record(Ledger.KIND_BRIDGE, 8, 0, 1, Ledger.NOBODY, 0, -1, "weir bridge")
	_calendar.tick = SUMMER_TICK
	chronicle.poll()
	_calendar.tick = SUMMER_TICK + 12 * DAY_TICKS
	chronicle.poll()
	assert_equal(chronicle.book.page_count(), 2, "two pages")
	assert_true(chronicle.book.page_text(0, ledger).contains("neck bridge — the village's first."), "spring's first")
	assert_true(chronicle.book.page_text(1, ledger).contains("Elstan Weirholt built the weir bridge."), "summer's")
	assert_false(chronicle.book.page_text(1, ledger).contains("the village's first."), "not a first again")


func test_calm_or_ideal_weather_is_no_hard_weather() -> void:
	"""Calm days and an ideal spell alone are a steady season; other trouble alone is trouble, not weather."""
	var record := FakeRecord.new()
	record.events = PackedInt32Array([WeatherScript.EVENT_CALM_DAYS, WeatherScript.EVENT_IDEAL_SPELL])
	var writer := _writer(record)
	var tally := TallyScript.new(0)
	assert_equal(writer.mood(tally), WriterScript.MOOD_STEADY, "fair weather is steady")
	assert_false(_page(writer, tally).contains("weather tried"), "no hard weather claimed")
	tally.troubles[TallyScript.TROUBLE_NO_BED] = 1
	assert_equal(writer.mood(tally), WriterScript.MOOD_TROUBLE, "a night without a bed is trouble")
	tally.troubles[TallyScript.TROUBLE_FROST] = 1
	assert_equal(writer.mood(tally), WriterScript.MOOD_WEATHER, "frost is weather")


func test_a_day_whose_weather_was_not_seen_tells_no_event() -> void:
	"""A kept day the record never saw at its own hours has no weather to tell."""
	var record := FakeRecord.new()
	record.events = PackedInt32Array([WeatherScript.EVENT_DROUGHT])
	record.unseen = PackedInt32Array([0])
	assert_false(_page(_writer(record), TallyScript.new(0)).contains("Drought"), "not seen: not told")


func test_a_song_sung_alone_at_supper_is_not_the_table_singing() -> void:
	"""The solo supper line counts as singing at supper, and the page never says the table sang together."""
	var feed := _feed()
	var tally := TallyScript.new(0)
	feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, CircleScript.SUPPER_ALONE_LINE % ["Corra Netley",
		"Set the Board"])
	assert_true(tally.read_row(feed, 0), "a supper song")
	var text: String = _page(_writer(), tally)
	assert_true(text.contains("at supper on one evening."), text)
	assert_false(text.contains("together"), "no claim the table joined in")


func test_one_portion_and_a_project_name_with_a_quote() -> void:
	"""'one portion' in the singular; a project's name keeps its own quote marks."""
	var record := FakeRecord.new()
	record.totals = {RecordScript.F_PORTIONS: 1}
	var text: String = _page(_writer(record), TallyScript.new(0))
	assert_true(text.contains("one portion") and not text.contains("1 portions"), text)
	var feed := _feed()
	var tally := TallyScript.new(0)
	feed.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, ProjectsScript.CHRONICLE % ["The \"big\" larder",
		"ready food", "0 U", "40 U", "40 U"])
	tally.read_row(feed, 0)
	assert_equal(tally.occasion_text, PackedStringArray(["The \"big\" larder"]), "the whole name")
	feed.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, ProjectsScript.CHRONICLE % ["Path\" -- west",
		"bridges", "0", "1", "1"])
	tally.read_row(feed, 0)
	assert_equal(tally.occasion_text[1], "Path\" -- west", "cut at the line's own last separator")


func test_a_page_tells_the_season_s_end_not_what_came_after() -> void:
	"""Friendships and hours after the season ended, before its page was written, are not that season's."""
	var parts: Array = _farm_chronicle()
	var farm: DemoFarmScript = parts[0]
	var chronicle: ChronicleScript = parts[1]
	var ledger: Ledger = parts[2]
	farm.services.calendar.tick = SUMMER_TICK
	chronicle.poll()
	for k: int in 5:
		ledger.add_rescue(3, 4, 12)
	ledger.add_shared_work(5, 6, 6 * Ledger.SHARED_HOUR_TICKS, 12)
	farm.services.calendar.tick = SUMMER_TICK + 2 * DAY_TICKS
	chronicle.poll()
	var page: String = chronicle.book.page_text(0, ledger)
	assert_equal(chronicle.book.page_count(), 1, "spring written")
	assert_false(page.contains("Tobit Highbough") or page.contains("Corra Netley"), page)


func test_the_draft_tells_songs_learned_so_far() -> void:
	"""The draft reads what each resident knows now against the season's start."""
	_ui = FarmUiTest.new()
	_ui.before_each()
	var farm: DemoFarmScript = _ui._farm()
	var circle := CircleScript.new()
	circle.knows = PackedInt32Array([0, 0, 0])
	var chronicle := ChronicleScript.new()
	_nodes.append(chronicle)
	chronicle.configure(farm.services.notices, farm.services.calendar, farm.record, _ledger(), _names(), circle,
		PackedStringArray(TITLES))
	circle.knows[2] = 2
	assert_true(chronicle.write_draft().page_text(0, null).contains("Linnet Whinberry learned “Lift and Lay”."),
		"a song learned so far")
