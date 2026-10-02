extends RefCounted
## THE CHRONICLE'S PAGES (decision 0631): one page a season, written once at its end (chronicle_writer.gd), never
## rewritten. Pure data in packed columns: per page its absolute season and title and where its lines start; per line
## its words, its STYLE (opening, heading, text, closing), its SECTION and -- for a deed -- the people's deed serial.
##
## THE PLAYER'S CURATION IS READ WHEN SHOWN. A page keeps every deed of its season it might tell (up to
## chronicle_writer.gd MAX_DEED_LINES, best first), each with its deed serial. `lines_into` shows a deed only while the
## player has not kept it PRIVATE or DISMISSED it (people_ledger.gd CURATION_*, SOC-028), the PINNED first, at most
## DEEDS_SHOWN, and drops the Deeds heading when none is left -- so the season's reflection, answered after the page was
## written, still decides what the page tells. Reading a page changes nothing (setting_bible.md §16: "Reopening a
## codex/chronicle entry must not mutate simulation").

const Ledger := preload("res://demo/people/people_ledger.gd")

const STYLE_OPENING: int = 0
const STYLE_HEADING: int = 1
const STYLE_TEXT: int = 2
const STYLE_CLOSING: int = 3
const STYLE_NOTE: int = 4

const SECTION_OPENING: int = 0
const SECTION_TABLE: int = 1
const SECTION_WEATHER: int = 2
const SECTION_DEEDS: int = 3
const SECTION_FRIENDS: int = 4
const SECTION_SONGS: int = 5
const SECTION_CLOSING: int = 6

const NO_DEED: int = -1
## Deeds a page shows at most.
const DEEDS_SHOWN: int = 3
## Pages kept at most (twelve years of seasons); the oldest goes first.
const MAX_PAGES: int = 48

## Bumped whenever a page is added or dropped.
var revision: int = 0

var page_season: PackedInt32Array = PackedInt32Array()
var page_title: PackedStringArray = PackedStringArray()
var page_first: PackedInt32Array = PackedInt32Array()
var page_lines: PackedInt32Array = PackedInt32Array()
var line_text: PackedStringArray = PackedStringArray()
var line_style: PackedByteArray = PackedByteArray()
var line_section: PackedByteArray = PackedByteArray()
var line_deed: PackedInt32Array = PackedInt32Array()

var _open_page: int = -1
var _shown_deeds: PackedInt32Array = PackedInt32Array()


func clear() -> void:
	"""No pages."""
	for column: PackedInt32Array in [page_season, page_first, page_lines, line_deed]:
		column.clear()
	page_title.clear()
	line_text.clear()
	line_style.clear()
	line_section.clear()
	_open_page = -1
	revision += 1


func page_count() -> int:
	"""Pages kept."""
	return page_season.size()


func begin_page(absolute_season: int, title: String) -> int:
	"""Start a new last page (the oldest dropped past MAX_PAGES); its index. Lines follow with `add_line`."""
	if page_season.size() >= MAX_PAGES:
		_drop_first_page()
	page_season.append(absolute_season)
	page_title.append(title)
	page_first.append(line_text.size())
	page_lines.append(0)
	_open_page = page_season.size() - 1
	revision += 1
	return _open_page


func add_line(words: String, style: int, section: int, deed: int = NO_DEED) -> bool:
	"""One line on the page begun last. Refuses empty words, no page begun, or a style or section out of range."""
	if _open_page < 0 or words.is_empty() or style < STYLE_OPENING or style > STYLE_NOTE \
			or section < SECTION_OPENING or section > SECTION_CLOSING:
		return false
	line_text.append(words)
	line_style.append(style)
	line_section.append(section)
	line_deed.append(deed)
	page_lines[_open_page] += 1
	return true


func _drop_first_page() -> void:
	"""Forget the oldest page and its lines; every later page's lines move up."""
	var lines: int = page_lines[0]
	for k: int in lines:
		line_text.remove_at(0)
		line_style.remove_at(0)
		line_section.remove_at(0)
		line_deed.remove_at(0)
	page_season.remove_at(0)
	page_title.remove_at(0)
	page_first.remove_at(0)
	page_lines.remove_at(0)
	for p: int in page_first.size():
		page_first[p] -= lines
	_open_page -= 1


func index_of_season(absolute_season: int) -> int:
	"""The page of an absolute season (-1: none written)."""
	return page_season.find(absolute_season)


func title_of(page: int) -> String:
	"""Page `page`'s title ("" out of range)."""
	return page_title[page] if page >= 0 and page < page_title.size() else ""


func season_of(page: int) -> int:
	"""Page `page`'s absolute season (-1 out of range)."""
	return page_season[page] if page >= 0 and page < page_season.size() else -1


func lines_into(page: int, ledger: Ledger, out_text: PackedStringArray, out_style: PackedByteArray) -> int:
	"""Page `page` as shown now (see THE PLAYER'S CURATION IS READ WHEN SHOWN): its lines and styles in order. Returns
	how many (0 out of range)."""
	out_text.clear()
	out_style.clear()
	if page < 0 or page >= page_season.size():
		return 0
	_choose_deeds(page, ledger)
	var first: int = page_first[page]
	for at: int in range(first, first + page_lines[page]):
		if line_section[at] == SECTION_DEEDS and not _deed_shown(at):
			continue
		out_text.append(line_text[at])
		out_style.append(line_style[at])
	return out_text.size()


func _deed_shown(at: int) -> bool:
	"""Whether line `at` of the Deeds section is shown: its heading while any deed is, a deed when chosen."""
	if line_style[at] == STYLE_HEADING:
		return not _shown_deeds.is_empty()
	return _shown_deeds.has(at)


func _choose_deeds(page: int, ledger: Ledger) -> void:
	"""The deed lines shown on `page`: the pinned first, then the uncurated, at most DEEDS_SHOWN (`lines_into` draws them in
	page order)."""
	_shown_deeds.clear()
	var first: int = page_first[page]
	for want: int in [Ledger.CURATION_PINNED, Ledger.CURATION_NONE]:
		for at: int in range(first, first + page_lines[page]):
			if _shown_deeds.size() >= DEEDS_SHOWN:
				break
			if line_section[at] != SECTION_DEEDS or line_style[at] != STYLE_TEXT or _shown_deeds.has(at):
				continue
			if _curation(ledger, line_deed[at]) == want:
				_shown_deeds.append(at)


static func _curation(ledger: Ledger, deed: int) -> int:
	"""The player's curation of a deed (NONE with no ledger, no deed, or a deed forgotten)."""
	if ledger == null or deed == NO_DEED:
		return Ledger.CURATION_NONE
	return ledger.curation_of(deed)


func page_text(page: int, ledger: Ledger) -> String:
	"""Page `page` as one text, title first (checks and the tapestry's summary)."""
	var words := PackedStringArray()
	var styles := PackedByteArray()
	lines_into(page, ledger, words, styles)
	return "%s\n%s" % [title_of(page), "\n".join(words)]
