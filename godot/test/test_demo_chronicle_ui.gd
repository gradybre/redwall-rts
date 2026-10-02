extends "res://test/framework/test_case.gd"
## The village chronicle's book and its two doors (decision 0631): the book's pages by season and the season under way,
## its paging, its type and button floors (UI §2.1; decision 0391), and the "Chronicle" buttons of Village news and the
## village guide, each closing its own window first. Off-tree: the real-input and layout checks are the live harness's
## (test_demo_chronicle_live.gd).

const ChronicleScript := preload("res://demo/chronicle/demo_chronicle.gd")
const WindowScript := preload("res://demo/chronicle/chronicle_window.gd")
const BookScript := preload("res://demo/chronicle/chronicle_book.gd")
const TallyScript := preload("res://demo/chronicle/chronicle_tally.gd")
const Text := preload("res://demo/chronicle/chronicle_text.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const HistoryScript := preload("res://demo/ui/demo_news_history.gd")
const GuideWindowScript := preload("res://demo/guide/guide_window.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const SUMMER_TICK: int = 12 * SimClock.TICKS_PER_DAY - SimClock.CALENDAR_OFFSET_TICKS

var _nodes: Array[Node] = []
var _calendar: CalendarScript = null
var _feed: NoticesScript = null


func after_each() -> void:
	"""Free what was built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


func _chronicle(seasons_written: int) -> ChronicleScript:
	"""A chronicle on a fresh calendar and feed (no record), with this many seasons' pages written."""
	_calendar = CalendarScript.new()
	_feed = NoticesScript.new()
	_feed.bind_calendar(_calendar)
	var ledger := Ledger.new()
	ledger.setup(3)
	var chronicle := _keep(ChronicleScript.new()) as ChronicleScript
	chronicle.configure(_feed, _calendar, null, ledger, PackedStringArray(["Ann", "Bo", "Cy"]))
	for season: int in seasons_written:
		_feed.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, "Chronicle: gathering %d" % season)
		chronicle.poll()
		_calendar.tick = SUMMER_TICK + season * 12 * SimClock.TICKS_PER_DAY
		chronicle.poll()
	return chronicle


func _window(chronicle: ChronicleScript) -> WindowScript:
	"""The book over `chronicle`, built off-tree."""
	var book := _keep(WindowScript.new()) as WindowScript
	book.configure(chronicle)
	return book


func test_the_book_opens_on_the_newest_page_and_pages_by_season() -> void:
	"""Two seasons written: it opens on summer's page, a tab per page and one for the season under way; Earlier and
	Later move, and stop at each end."""
	var chronicle := _chronicle(2)
	assert_equal(chronicle.book.page_count(), 2, "spring and summer written")
	var book := _window(chronicle)
	book.open()
	assert_true(book.is_open(), "open")
	assert_equal(book.page_shown(), 1, "the newest written page")
	assert_true(book.shown_text().begins_with(Text.page_title(1, false)), book.shown_text())
	assert_true(book.shown_text().contains("Gathering 1."), "summer's own gathering")
	assert_equal([book.tab_button(0).text, book.tab_button(1).text, book.tab_button(2).text],
		["Spring Y1", "Summer Y1", WindowScript.DRAFT_TAB], "the tabs")
	assert_true(book.tab_button(1).button_pressed and not book.tab_button(0).button_pressed, "summer's tab pressed")
	book.earlier_button().pressed.emit()
	assert_equal(book.page_shown(), 0, "earlier")
	assert_true(book.earlier_button().disabled, "the first page: no earlier")
	book.later_button().pressed.emit()
	book.later_button().pressed.emit()
	assert_equal(book.page_shown(), book.draft_index(), "the season under way")
	assert_true(book.later_button().disabled, "nothing later")
	assert_true(book.shown_text().contains("being written"), "the draft")
	book.close()
	assert_false(book.is_open(), "closed")


func test_with_no_page_written_it_opens_on_the_season_so_far() -> void:
	"""Before the first season ends: the draft, with the note that no page is written yet."""
	var book := _window(_chronicle(0))
	book.open()
	assert_equal([book.page_shown(), book.draft_index(), book.newest_page()], [0, 0, 0], "the draft")
	assert_true(book.shown_text().begins_with(Text.page_title(0, true)), book.shown_text())
	assert_true(book.find_child("*", true, false) != null, "built")
	var notes: int = 0
	for label: Node in book.find_children("*", "Label", true, false):
		notes += 1 if (label as Label).text == WindowScript.NO_PAGES and (label as Label).visible else 0
	assert_equal(notes, 1, "the no-pages note shows")


func test_a_tab_shows_its_page_and_a_new_page_adds_a_tab() -> void:
	"""Pressing a tab shows its page; a page written while open adds its tab at the next refresh."""
	var chronicle := _chronicle(1)
	var book := _window(chronicle)
	book.open(0)
	book.tab_button(1).pressed.emit()
	assert_equal(book.page_shown(), 1, "the draft's tab")
	book.show_page(99)
	assert_equal(book.page_shown(), book.draft_index(), "clamped to the draft")
	book.show_page(-3)
	assert_equal(book.page_shown(), 0, "clamped to the first")
	_calendar.tick = SUMMER_TICK + 12 * SimClock.TICKS_PER_DAY
	chronicle.poll()
	book.refresh()
	assert_equal(book.tab_button(1).text, "Summer Y1", "summer's tab")
	assert_equal(book.tab_button(2).text, WindowScript.DRAFT_TAB, "the draft moves along")


func test_the_book_s_type_and_buttons_meet_the_floors() -> void:
	"""Every line and button at least 14 px (UI §2.1), every button at least 32 px tall (decision 0391)."""
	var book := _window(_chronicle(1))
	book.open(0)
	for node: Node in book.find_children("*", "Control", true, false):
		var control := node as Control
		if control is Label or control is Button:
			assert_true(control.get_theme_font_size(&"font_size") >= 14, "%s at %d px" % [control.name,
				control.get_theme_font_size(&"font_size")])
		if control is Button:
			assert_true(control.custom_minimum_size.y >= 32.0, "%s 32 px tall" % control.name)


func test_headings_wear_the_heading_face_and_the_facts_ink() -> void:
	"""A section heading in the heading face, a fact in ink, the opening in umber."""
	var book := _window(_chronicle(1))
	book.open(0)
	var lines: Array[Label] = book.shown_lines()
	var styles: Dictionary = {}
	for line: Label in lines:
		styles[line.text] = line
	var heading: Label = styles.get(Text.SECTION_TITLES[BookScript.SECTION_SONGS])
	assert_not_null(heading, "the songs heading")
	assert_true(heading.has_theme_font_override(&"font"), "heading face")
	var fact: Label = styles.get("Gathering 0.")
	assert_not_null(fact, "the fact")
	assert_false(fact.has_theme_font_override(&"font"), "body face")
	assert_equal(fact.get_theme_color(&"font_color"), WindowScript.Palette.INK, "ink")
	assert_equal(lines[0].get_theme_color(&"font_color"), WindowScript.Palette.UMBER, "the opening in umber")


func test_village_news_has_a_chronicle_button_that_closes_it_first() -> void:
	"""Hidden until set; pressed, the news window closes and the chronicle opens."""
	var history := _keep(HistoryScript.new()) as HistoryScript
	var feed := NoticesScript.new()
	history.configure(feed, IncidentsScript.new(), null)
	var button := history.find_child("Chronicle", true, false) as Button
	assert_not_null(button, "the button")
	assert_false(button.visible, "hidden until set")
	var opened: Array[int] = []
	history.set_chronicle(func() -> void: opened.append(1))
	assert_true(button.visible, "shown once set")
	history.open()
	button.pressed.emit()
	assert_false(history.is_open(), "the news closed first")
	assert_equal(opened.size(), 1, "the chronicle opened")


func test_the_village_guide_has_a_chronicle_button_that_closes_it_first() -> void:
	"""Hidden until set; pressed, the guide closes (its pause let go) and the chronicle opens."""
	var guide := _keep(GuideWindowScript.new()) as GuideWindowScript
	assert_false(guide.chronicle_button().visible, "hidden until set")
	var opened: Array[int] = []
	guide.set_chronicle(func() -> void: opened.append(1))
	assert_true(guide.chronicle_button().visible, "shown once set")
	guide.visible = true
	guide.chronicle_button().pressed.emit()
	assert_false(guide.visible, "the guide closed first")
	assert_equal(opened.size(), 1, "the chronicle opened")
	guide.set_chronicle(Callable())
	assert_false(guide.chronicle_button().visible, "unset: hidden again")
