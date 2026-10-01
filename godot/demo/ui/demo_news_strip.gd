extends CanvasLayer
## "Village news (demo)": the newest demo notices, readable at a glance. Decision 0196 (live demo).
## DEMO UI. It shows the demo's ONE notice feed (demo_notices.gd) and nothing else.
##
## WHAT: the newest LINES entries still fresh -- a NOTE for NOTE_MSEC and a WARNING for WARNING_MSEC of
## REAL time (UI §7 gives INFO 12 real seconds; a demo warning gets longer, and the bed and tunnel
## panels keep their own source's lines for good) -- newest on top, each "<demo date> · Warning: <what>"
## with the date the HUD shows, warnings in clay AND worded (colour never says it alone). An entry's
## authored short summary is shown when it has one. Nothing fresh: the strip hides.
##
## WHERE: bottom centre, over the world, just above the command strip and CENTRED ON IT (playtest
## 2026-09-29: "center the news bar with the action bar" -- it was centred on the gap between the
## minimap and the right column, 176 px left of the commands at 1280x720 and 200 px at 1920x1080). It
## stays clear of the minimap and the right column -- the one band UI §1.2 leaves free at every
## profile -- so it is as wide as it can be about that centre, no wider than MAX_W; at 1280x720, where
## the commands run under the right column, that is narrower. The command strip moves left when the
## resident journal takes the right column; the strip follows it (`follow_journal`). Geometry is the
## HUD's own (`scripts/ui/ui_layout.gd`, read, never modified) in LOGICAL pixels at the HUD's scale.
## It ignores the mouse, so a click through it still reaches the world; it draws below the HUD.
##
## Refreshed a few times a second on real time (it must read while the village is paused); it
## rebuilds nothing, only rewrites LINES labels.
##
## THE NEWS DOES NOT RUN OUT WHILE PAUSED (decision 0331, review F11). With the news bound (`bind_news`) a
## toast's age is counted on the news clock (demo_news_clock.gd), which this strip advances every frame
## and which stands still while the village is paused: a warning read paused is still there when play
## resumes. A toast is only the transient view: every entry stays in the village-news history, and an
## unresolved condition stays an incident (demo_incidents.gd) until it resolves or is acknowledged. So
## while any incident is unresolved the strip stays up with its count ("2 need attention"), and its one
## button -- the only part of the strip that takes the mouse -- opens the history (`history_wanted`).

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")

## The strip's history button was pressed: open the village-news history.
signal history_wanted

const TITLE: String = "Village news (demo)"
const LINES: int = 3
const NOTE_MSEC: int = 12000
const WARNING_MSEC: int = 30000
const MAX_W: float = 640.0
const GAP: float = 12.0
const TITLE_PX: int = 13
const LINE_PX: int = 14
const REFRESH_S: float = 0.25
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 8.0, 14.0, 10.0]
const HISTORY_PX: int = 13
const HISTORY_WORDS: String = "Village news history (N)"
const ATTENTION_WORDS: String = "%d need%s attention — Village news history (N)"

var _notices: NoticesScript = null
var _frame: PanelContainer = null
var _lines: Array[Label] = []
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _refresh_in: float = 0.0
var _seen_revision: int = -1
var _shown: int = 0
## Answers whether the resident journal holds the right column (demo_detail_zone.gd `journal_open`).
var _journal_query: Callable = Callable()
var _journal_open: bool = false
var _incidents: IncidentsScript = null
var _clock: NewsClockScript = null
## Answers whether the village is paused (the news clock stands still then).
var _paused_query: Callable = Callable()
var _history_button: Button = null
var _attention: int = 0


func configure(notices: NoticesScript) -> void:
	"""Show this feed, and build."""
	_notices = notices
	build()


func bind_news(incidents: IncidentsScript, clock: NewsClockScript, paused: Callable) -> void:
	"""Count the unresolved `incidents`, and advance `clock` every frame unless `paused()` (see THE NEWS DOES
	NOT RUN OUT WHILE PAUSED)."""
	_incidents = incidents
	_clock = clock
	_paused_query = paused


func follow_journal(journal_open: Callable) -> void:
	"""Follow the command strip when the right column yields to the resident journal (the HUD lays
	its commands out for an open journal then): `journal_open` answers whether it does."""
	_journal_query = journal_open
	_place()


func _journal_is_open() -> bool:
	"""Whether the resident journal holds the right column now (false while nothing is followed)."""
	return _journal_query.is_valid() and bool(_journal_query.call())


func journal_followed() -> bool:
	"""The journal state the strip last laid itself out for (checks)."""
	return _journal_open


func _ready() -> void:
	"""Place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The frame, its title and LINES lines (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = 0
	name = "DemoNewsStrip"
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL_TIGHT, CONTENT_MARGINS))
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(column)
	column.add_child(_label(TITLE, TITLE_PX, Palette.UMBER, Styles.heading_font()))
	for k: int in LINES:
		_lines.append(_label("", LINE_PX, Palette.INK, null))
		column.add_child(_lines[k])
	_build_history_button(column)


func _build_history_button(column: VBoxContainer) -> void:
	"""The strip's one control: the history, with the count of what needs attention."""
	_history_button = Button.new()
	_history_button.name = "History"
	_history_button.text = HISTORY_WORDS
	_history_button.flat = true
	_history_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	## No focus: a clicked button keeping it would take the HUD's Space (pause) and Enter.
	_history_button.focus_mode = Control.FOCUS_NONE
	_history_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_history_button.tooltip_text = "Every notice, filtered by place and severity, and what still needs attention"
	_history_button.add_theme_font_size_override(&"font_size", HISTORY_PX)
	_history_button.add_theme_color_override(&"font_color", Palette.UMBER)
	_history_button.pressed.connect(_on_history_pressed)
	column.add_child(_history_button)


func tick_news(real_msec: int) -> void:
	"""Advance the bound news clock to `real_msec` (real milliseconds), counting nothing while paused."""
	if _clock != null:
		_clock.sync(real_msec, _paused_query.is_valid() and bool(_paused_query.call()))


func _on_history_pressed() -> void:
	"""Ask for the history."""
	history_wanted.emit()


func history_button() -> Button:
	"""The strip's history button (checks)."""
	return _history_button


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One wrapped, mouse-transparent line."""
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(delta: float) -> void:
	"""Advance the news clock (every frame), and refresh a few times a second (real time) at the feed's time."""
	tick_news(Time.get_ticks_msec())
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	refresh(_notices.now_msec() if _notices != null else Time.get_ticks_msec())


func refresh(now_msec: int) -> int:
	"""Show the fresh entries as of `now_msec` (the feed's milliseconds: `NoticesScript.now_msec()`), and the
	count of unresolved incidents; returns how many entries are shown."""
	if _notices == null or _frame == null:
		return 0
	if _journal_is_open() != _journal_open:
		_journal_open = not _journal_open
		_place.call_deferred()
	var shown: int = 0
	for k: int in _notices.count():
		if shown >= LINES:
			break
		var life: int = WARNING_MSEC if _notices.level(k) == NoticesScript.LEVEL_WARNING else NOTE_MSEC
		if _notices.age_msec(k, now_msec) > life:
			continue
		_show_line(shown, k)
		shown += 1
	for rest: int in range(shown, LINES):
		_lines[rest].visible = false
	var attention: int = _incidents.unresolved_count() if _incidents != null else 0
	if shown != _shown or _notices.revision != _seen_revision or attention != _attention:
		_shown = shown
		_seen_revision = _notices.revision
		_show_attention(attention)
		_frame.visible = shown > 0 or attention > 0
		_place.call_deferred()
	return shown


func _show_attention(attention: int) -> void:
	"""The history button's words: how many incidents need attention, clay while any do."""
	_attention = attention
	var words: String = HISTORY_WORDS if attention == 0 else ATTENTION_WORDS % [attention, "s" if attention == 1 else ""]
	_history_button.text = words
	_history_button.add_theme_color_override(&"font_color", Palette.CLAY if attention > 0 else Palette.UMBER)


func attention_shown() -> int:
	"""How many unresolved incidents the strip last counted (checks)."""
	return _attention


func _show_line(slot: int, k: int) -> void:
	"""Write entry `k` into line `slot`: its short form, clay when it is a warning."""
	var label: Label = _lines[slot]
	var text: String = _notices.short_line(k)
	if label.text != text:
		label.text = text
	var warning: bool = _notices.level(k) == NoticesScript.LEVEL_WARNING
	label.add_theme_color_override(&"font_color", Palette.CLAY if warning else Palette.INK)
	label.visible = true


func line_text(slot: int) -> String:
	"""Line `slot`'s text ("" when hidden; checks)."""
	return _lines[slot].text if _lines[slot].visible else ""


func is_shown() -> bool:
	"""Whether the strip is drawn."""
	return _frame != null and _frame.visible


func _place() -> void:
	"""Bottom centre, between the minimap and the right column, above the command strip (see WHERE)."""
	if not is_inside_tree() or _frame == null:
		return
	var band: Rect2 = band_in(get_viewport().get_visible_rect().size)
	for label: Label in _lines:
		label.custom_minimum_size.x = band.size.x - CONTENT_MARGINS[0] - CONTENT_MARGINS[2]
	var height: float = _frame.get_combined_minimum_size().y
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.custom_minimum_size = Vector2(band.size.x, 0.0)
	_frame.size = Vector2(band.size.x, 0.0)
	_frame.position = Vector2(band.position.x, band.end.y - height) * _geometry.scale


func band_in(viewport_size: Vector2) -> Rect2:
	"""The band for this viewport, in logical pixels, laid out for the journal as it is now (fills the
	strip's own geometry, whose scale the frame is drawn at)."""
	_journal_open = _journal_is_open()
	return band_placement(int(viewport_size.x), int(viewport_size.y), _layout, _geometry, _journal_open)


static func band_placement(width: int, height: int, layout: UiLayout, geometry: UiLayout.Geometry,
		journal_open: bool = false) -> Rect2:
	"""The band the strip may fill, in the HUD's logical pixels: centred on the command strip (as the
	HUD lays it out with the journal open or closed), as wide as it can be about that centre while
	clear of the minimap and the right column, no wider than MAX_W, from the top of the minimap down to
	just above the command strip (the strip sits on its bottom edge, as tall as its lines). Fills
	`geometry`."""
	if not layout.compute_into(maxi(width, UiLayout.SUPPORTED_MIN_WIDTH), maxi(height, UiLayout.SUPPORTED_MIN_HEIGHT),
			UiLayout.USER_SCALE_100, journal_open, geometry):
		geometry.scale = 1.0
	var centre: float = geometry.commands.get_center().x
	var half: float = minf(centre - (geometry.minimap.end.x + GAP), geometry.detail.position.x - GAP - centre)
	var band_w: float = minf(MAX_W, 2.0 * maxf(half, 0.0))
	var top: float = geometry.minimap.position.y
	return Rect2(centre - band_w / 2.0, top, band_w, geometry.commands.position.y - GAP - top)


func frame_rect() -> Rect2:
	"""Where the strip is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
