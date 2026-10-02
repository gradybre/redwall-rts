extends CanvasLayer
## THE CHRONICLE BOOK (decision 0631): the village chronicle's pages, one a season, read like a book. DEMO UI in the
## woodland skin (farm_ui.gd's carved frame, parchment face, heading face, wood buttons).
##
## WHAT, top to bottom: the title, which page this is, and ×; a row of the pages by season ("Spring Y1", ...) and "This
## season" (the season under way, written so far: demo_chronicle.gd THE DRAFT); the page -- its title, then its lines
## in their styles (the opening and closing in umber, the section headings in the heading face, the facts in ink); and
## "Earlier page" / "Later page". A page with deeds shows the player's curation as it stands (chronicle_book.gd).
##
## WHERE AND HOW. Centred in the HUD's modal rectangle at the HUD's scale, at most MAX_W wide, the page scrolling in what
## is left, so it reads at 1280x720 as at 4K. A modal of the input gate (demo_village.gd: Esc or × closes it, focus
## stays inside) and a planning surface (with "Pause while planning" on, the village waits while it is open). It has no
## key of its own: Village news (N) and the village guide (O) each have a "Chronicle" button that opens it.
## Reading it changes nothing. Labels are pooled and only grow; a draft is rewritten only when something it reads moved.
##
## THE PAGE ART (art pass 2, decision 0951; docs/art-reference/art_pass2_mapping.md "Chronicle page"). With the
## parchment page staged (`set_art`: the shared props table), the page body -- its title, note and lines, the SHEET in
## the scroll -- lies on it: a nine-patch scaled as one to the drawn page (the page's own `size` across the sheet's
## width), its margins those of `text_area_ltrb`, so the words stay inside the page's text area at any width; the sheet is
## at least the page's own height, and a longer page stretches its sides. With nothing staged (CI, a fresh clone) the
## sheet has no box and the book is drawn as above.

const ChronicleScript := preload("res://demo/chronicle/demo_chronicle.gd")
const BookScript := preload("res://demo/chronicle/chronicle_book.gd")
const Text := preload("res://demo/chronicle/chronicle_text.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const LAYER: int = 2
const MAX_W: float = 720.0
const MIN_BODY_H: float = 160.0
const HEADING_PX: int = 17
const PAGE_TITLE_PX: int = 19
const REFRESH_S: float = 0.5
const DRAFT_TAB: String = "This season"
const WHERE_PAGE: String = "Page %d of %d"
const WHERE_DRAFT: String = "The season under way"
const EARLIER: String = "◀ Earlier page"
const LATER: String = "Later page ▶"
const CLOSE_TIP: String = "Close the chronicle (Esc)"
## The page art's manifest row, and the room kept for the scroll's bar beside the sheet without it.
const PAGE_ROW: String = "chronicle_page"
const SCROLLBAR_W: float = 16.0
const NO_PAGES: String = "No season has ended yet: the first page is written when this one does. Here is this season so far."

var _chronicle: ChronicleScript = null
var _frame: PanelContainer = null
var _where: Label = null
var _close: Button = null
var _tab_row: HFlowContainer = null
var _tabs: Array[Button] = []
var _scroll: DemoScroll = null
var _page_title: Label = null
var _empty_note: Label = null
var _lines: Array[Label] = []
var _earlier: Button = null
var _later: Button = null
## The page shown: a written page's index, or the draft (`draft_index()`).
var _page: int = 0
var _drawn_key: Vector4i = Vector4i(-1, -1, -1, -1)
var _drawn_page: int = -1
var _words: PackedStringArray = PackedStringArray()
var _styles: PackedByteArray = PackedByteArray()
var _text_w: float = 600.0
## The page body's width (the sheet's), and the text's inside it (`_text_w`: the same without the page art).
var _sheet_w: float = 600.0
var _refresh_in: float = 0.0
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
## The page body's sheet; with the page art staged, its box, the page's own texture (scaled by a size override), its
## size in pixels and its text area (l, t, r, b) in the page's pixels.
var _sheet: PanelContainer = null
var _page_box: StyleBoxTexture = null
var _page_texture: ImageTexture = null
var _page_size: Vector2 = Vector2.ZERO
var _text_area: Rect2 = Rect2()


func configure(chronicle: ChronicleScript) -> void:
	"""Show this chronicle's pages; built hidden."""
	_chronicle = chronicle
	build()


func build() -> void:
	"""The hidden book: header, the pages' row, the page and its footer (also out of the tree, for checks)."""
	if _frame != null:
		return
	name = "ChronicleWindow"
	layer = LAYER
	visible = false
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	column.add_child(_header())
	_tab_row = HFlowContainer.new()
	_tab_row.add_theme_constant_override(&"h_separation", 6)
	_tab_row.add_theme_constant_override(&"v_separation", 4)
	column.add_child(_tab_row)
	_build_page(column)
	column.add_child(_footer())


func _header() -> HBoxContainer:
	"""The title, which page, and ×."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var title: Label = FarmUi.label(Text.BOOK_TITLE, FarmUi.TITLE_PX, Palette.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	_where = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	_where.autowrap_mode = TextServer.AUTOWRAP_OFF
	_where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_where)
	_close = FarmUi.button("×", FarmUi.BODY_PX + 2)
	_close.name = "Close"
	_close.tooltip_text = CLOSE_TIP
	_close.pressed.connect(close)
	row.add_child(_close)
	return row


func _build_page(column: VBoxContainer) -> void:
	"""The scrolling page: its title, the no-pages note and the pooled lines."""
	_scroll = DemoScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = MIN_BODY_H
	column.add_child(_scroll)
	var page := VBoxContainer.new()
	page.name = "Page"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override(&"separation", 5)
	_sheet = PanelContainer.new()
	_sheet.name = "Sheet"
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_scroll.add_child(_sheet)
	_sheet.add_child(page)
	_empty_note = FarmUi.label(NO_PAGES, FarmUi.SMALL_PX, Palette.UMBER)
	page.add_child(_empty_note)
	_page_title = FarmUi.label("", PAGE_TITLE_PX, Palette.INK, true)
	page.add_child(_page_title)


func _footer() -> HBoxContainer:
	"""Earlier page, Later page."""
	var row := HBoxContainer.new()
	_earlier = FarmUi.button(EARLIER, FarmUi.SMALL_PX)
	_earlier.pressed.connect(func() -> void: show_page(_page - 1))
	row.add_child(_earlier)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	_later = FarmUi.button(LATER, FarmUi.SMALL_PX)
	_later.pressed.connect(func() -> void: show_page(_page + 1))
	row.add_child(_later)
	return row


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


# --- opening, closing, paging --------------------------------------------------------------------------------------

func open(page: int = -1) -> void:
	"""Show the book on `page` (-1: the newest written page, or the season under way when none is written)."""
	build()
	visible = true
	_drawn_key = Vector4i(-1, -1, -1, -1)
	show_page(page if page >= 0 else newest_page())
	_place.call_deferred()
	_focus_later(_close)


func close() -> void:
	"""Hide the book (the gate's Esc, and ×)."""
	visible = false


func is_open() -> bool:
	"""Whether the book is open (the planning pause's question)."""
	return visible


func newest_page() -> int:
	"""The newest written page, or the draft when none is written."""
	var written: int = _written_count()
	return written - 1 if written > 0 else written


func draft_index() -> int:
	"""The draft's place: after every written page."""
	return _written_count()


func _written_count() -> int:
	"""Pages written."""
	return _chronicle.book.page_count() if _chronicle != null else 0


func show_page(page: int) -> void:
	"""Show written page `page` or the draft (`draft_index()`), clamped."""
	_page = clampi(page, 0, draft_index())
	_drawn_key = Vector4i(-1, -1, -1, -1)
	refresh()


func page_shown() -> int:
	"""The page shown (a written page's index, or `draft_index()`)."""
	return _page


func _process(delta: float) -> void:
	"""While open, keep it current a few times a second."""
	if not visible:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_S
		refresh()


func refresh() -> void:
	"""The tabs, the page and the footer -- redrawn only when the page or what it reads changed."""
	if _chronicle == null:
		return
	var key: Vector4i = _chronicle.draft_key()
	if key == _drawn_key and _page == _drawn_page:
		return
	_drawn_key = key
	_drawn_page = _page
	_draw_tabs()
	_draw_page()


# --- drawing --------------------------------------------------------------------------------------------------------

func _draw_tabs() -> void:
	"""One toggle a written page, then the season under way; the shown one pressed."""
	var count: int = draft_index() + 1
	while _tabs.size() < count:
		var tab: Button = FarmUi.button("", FarmUi.SMALL_PX)
		tab.toggle_mode = true
		tab.pressed.connect(show_page.bind(_tabs.size()))
		_tab_row.add_child(tab)
		_tabs.append(tab)
	for k: int in _tabs.size():
		_tabs[k].visible = k < count
		if k < count:
			_tabs[k].text = DRAFT_TAB if k == draft_index() else Text.short_name(_chronicle.book.season_of(k))
			_tabs[k].set_pressed_no_signal(k == _page)


func _draw_page() -> void:
	"""The shown page's title and lines in their styles, the note, which page, and the footer."""
	var draft: bool = _page == draft_index()
	var book: BookScript = _chronicle.write_draft() if draft else _chronicle.book
	var at: int = 0 if draft else _page
	book.lines_into(at, _chronicle.ledger(), _words, _styles)
	_page_title.text = book.title_of(at)
	_empty_note.visible = draft and _written_count() == 0
	for k: int in _words.size():
		_paint(_line(k), _words[k], _styles[k])
	for k: int in range(_words.size(), _lines.size()):
		_lines[k].visible = false
	_where.text = WHERE_DRAFT if draft else WHERE_PAGE % [_page + 1, _written_count()]
	FarmUi.set_enabled(_earlier, _page > 0, "This is the first page")
	FarmUi.set_enabled(_later, not draft, "This is the season under way")


func _line(k: int) -> Label:
	"""Pooled line `k` (made when first needed)."""
	while _lines.size() <= k:
		var made: Label = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
		made.custom_minimum_size.x = _text_w
		_page_title.get_parent().add_child(made)
		_lines.append(made)
	return _lines[k]


static func _paint(line: Label, words: String, style: int) -> void:
	"""One line in its style (chronicle_book.gd STYLE_*)."""
	line.visible = true
	line.text = words
	var heading: bool = style == BookScript.STYLE_HEADING
	var px: int = HEADING_PX if heading else (FarmUi.SMALL_PX if style == BookScript.STYLE_NOTE else FarmUi.BODY_PX)
	line.add_theme_font_size_override(&"font_size", px)
	var ink: bool = style == BookScript.STYLE_TEXT or heading
	line.add_theme_color_override(&"font_color", Palette.INK if ink else Palette.UMBER)
	if heading:
		line.add_theme_font_override(&"font", FarmUi.Styles.heading_font())
	else:
		line.remove_theme_font_override(&"font")


# --- the page art ----------------------------------------------------------------------------------------------------

func set_art(props: PropsScript) -> void:
	"""Lay the page body on the staged parchment page from `props` (see THE PAGE ART); with none staged (or no props),
	the page drawn as before -- also after a page was laid."""
	build()
	var row: Variant = props.ui_row(PAGE_ROW) if props != null else null
	var source: Texture2D = null
	if row is Dictionary:
		source = props.ui_texture(String((row as Dictionary).get("path", "")))
	var area: Array = (row as Dictionary).get("text_area_ltrb", []) if row is Dictionary else []
	if source == null or area.size() != 4:
		_plain_page()
		return
	_page_size = source.get_size()
	_text_area = Rect2(float(area[0]), float(area[1]), float(area[2]) - float(area[0]), float(area[3]) - float(area[1]))
	_page_texture = ImageTexture.create_from_image(source.get_image())
	_page_box = StyleBoxTexture.new()
	_page_box.texture = _page_texture
	_sheet.add_theme_stylebox_override(&"panel", _page_box)
	_apply_width()
	_place()


func _plain_page() -> void:
	"""The page body as drawn before the art: no box, no minimum height, the text the whole sheet."""
	_page_box = null
	_page_texture = null
	_sheet.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_sheet.custom_minimum_size.y = 0.0
	_apply_width()
	_place()


func has_page_art() -> bool:
	"""Whether the page body lies on the staged parchment page (checks)."""
	return _page_box != null


func _fit_page(sheet_w: float) -> float:
	"""Scale the page art to a sheet `sheet_w` wide: its margins the text area's, the sheet at least the page's height.
	The text width inside it (all of `sheet_w` without the art)."""
	if _page_box == null or sheet_w <= 0.0:
		return sheet_w
	var s: float = sheet_w / _page_size.x
	_page_texture.set_size_override(Vector2i(roundi(_page_size.x * s), roundi(_page_size.y * s)))
	var ltrb := PackedFloat32Array([_text_area.position.x, _text_area.position.y, _page_size.x - _text_area.end.x,
		_page_size.y - _text_area.end.y])
	for side: int in 4:
		_page_box.set_texture_margin(side as Side, ltrb[side] * s)
		_page_box.set_content_margin(side as Side, ltrb[side] * s)
	_sheet.custom_minimum_size.y = _page_size.y * s
	return _text_area.size.x * s


func _apply_width() -> void:
	"""The text's width inside the sheet (the page art fitted to it), on every line."""
	_text_w = _fit_page(_sheet_w)
	for label: Label in _lines:
		label.custom_minimum_size.x = _text_w
	for label: Label in [_page_title, _empty_note]:
		label.custom_minimum_size.x = _text_w


func text_area_rect() -> Rect2:
	"""Where the page's text area is drawn on the sheet, in the sheet's own pixels (empty without the art; checks)."""
	if _page_box == null:
		return Rect2()
	var at := Vector2(_page_box.texture_margin_left, _page_box.texture_margin_top)
	return Rect2(at, _sheet.size - at - Vector2(_page_box.texture_margin_right, _page_box.texture_margin_bottom))


func sheet() -> PanelContainer:
	"""The page body's sheet (checks)."""
	return _sheet


# --- placement and checks ------------------------------------------------------------------------------------------

func _place() -> void:
	"""Centred in the HUD's modal rectangle at the HUD's scale, at most MAX_W wide, the whole height; the page scrolls."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var width: float = minf(MAX_W, zone.size.x - 2.0 * FarmUi.FRAME_EXPAND)
	var height: float = zone.size.y - 2.0 * FarmUi.FRAME_EXPAND
	_sheet_w = width - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2] - _bar_w()
	_apply_width()
	var at := Vector2(zone.position.x + (zone.size.x - width) / 2.0, zone.position.y + FarmUi.FRAME_EXPAND)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = at * _geometry.scale
	_frame.custom_minimum_size = Vector2(width, height)
	_frame.size = Vector2(width, height)


func _bar_w() -> float:
	"""The room beside the sheet for the scroll's bar: the drawn bar's own width under the page art (whose page always
	outgrows the view), SCROLLBAR_W as before without it."""
	if _page_box == null:
		return SCROLLBAR_W
	return _scroll.get_v_scroll_bar().get_combined_minimum_size().x


static func _focus_later(control: Control) -> void:
	"""Give `control` the focus once the frame has laid out (if it is still shown by then)."""
	var held: WeakRef = weakref(control)
	var take: Callable = func() -> void:
		var target := held.get_ref() as Control
		if target != null and target.is_inside_tree() and target.is_visible_in_tree():
			target.grab_focus()
	take.call_deferred()


func frame() -> PanelContainer:
	"""The carved frame (the gate's focus root)."""
	return _frame


func close_button() -> Button:
	"""The ×."""
	return _close


func tab_button(k: int) -> Button:
	"""Page tab `k` (checks)."""
	return _tabs[k] if k >= 0 and k < _tabs.size() else null


func earlier_button() -> Button:
	"""Earlier page."""
	return _earlier


func later_button() -> Button:
	"""Later page."""
	return _later


func shown_text() -> String:
	"""The page as shown: its title and every visible line (checks)."""
	var parts := PackedStringArray([_page_title.text])
	for line: Label in _lines:
		if line.visible:
			parts.append(line.text)
	return "\n".join(parts)


func shown_lines() -> Array[Label]:
	"""The visible line labels (checks)."""
	var out: Array[Label] = []
	for line: Label in _lines:
		if line.visible:
			out.append(line)
	return out
