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
## the commands run under the right column, that is narrower; where that would leave less than MIN_W (the
## narrow profile, 125 % on 1280x720) it takes the whole gap instead (decision 0391). The command strip moves left when the
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
##
## FEWER TOASTS (decision 0471, the Quiet focus preset): with `quiet` on the strip toasts warnings only, one at a
## time; notes are still in the history, and the count still shows.
##
## TIERS, GO TO AND DISMISS (decision 0591, feature #39). Each line is drawn at its tier's weight (demo_notices.gd
## TIERS): URGENT in the heading face, clay, "Urgent:"; NORMAL clay, "Warning:"; INFO in ink, unworded --
## and an urgent toast lasts URGENT_MSEC. Beside each line, Go to (the HUD's own centre-view crosshair, GO_TO_ICON,
## with "Go to" as its tooltip and name: an icon keeps the narrow band's lines from wrapping; shown when the subject can
## be found, it selects it and centres the camera, demo_news_jump.gd) and × (dismiss that one notice: off the strip,
## kept in the history). The buttons are the only parts of the strip that take the mouse, and take no keyboard focus
## (Space stays the HUD's).
## A line the feed kept quiet -- held back by the toast budget at 4x, of a snoozed kind, dismissed -- is not drawn;
## the title counts what was held back lately ("· 3 more (N)": N, the history's key). THE STRIP KEEPS TO ITS BAND: where its
## lines (wrapped, with their 32 px buttons) would make it taller than the band (1280x720: it would cover the Map
## layer picker), it draws fewer of them -- the most urgent kept, then the newest -- and the rest are in the history.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")
const JumpScript := preload("res://demo/ui/demo_news_jump.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")

## The strip's history button was pressed: open the village-news history.
signal history_wanted

const TITLE: String = "Village news (demo)"
const LINES: int = 3
const NOTE_MSEC: int = 12000
const WARNING_MSEC: int = 30000
## An urgent toast's life (see TIERS, GO TO AND DISMISS).
const URGENT_MSEC: int = 60000
## The strip's urgent size: the body size (the heading face is the weight; a larger size wraps the narrow band more).
const URGENT_PX: int = 14
const GO_TO: String = "Go to"
const GO_TO_ICON: String = "res://ui/icons/center_view.svg"
const GO_TO_ICON_PX: int = 18
const DISMISS: String = "×"
const HELD_WORDS: String = "%s · %d more (N)"
const MAX_W: float = 640.0
## Narrower than this about the commands' centre (the NARROW profile: 125 % on 1280x720, where the commands run
## under the right column), the band is the whole gap between the minimap and the right column (decision 0391).
const MIN_W: float = 280.0
const GAP: float = 12.0
const TITLE_PX: int = 14
const LINE_PX: int = 14
const REFRESH_S: float = 0.25
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 8.0, 14.0, 10.0]
const HISTORY_PX: int = 14
const HISTORY_WORDS: String = "Village news history (N)"
const ATTENTION_WORDS: String = "%d need%s attention — Village news history (N)"

var _notices: NoticesScript = null
var _frame: PanelContainer = null
var _lines: Array[Label] = []
## Per line (see TIERS, GO TO AND DISMISS): its row, its Go to and ×, the entry id it shows and the tier it is drawn at.
var _rows: Array[HBoxContainer] = []
var _go: Array[Button] = []
var _close: Array[Button] = []
var _shown_id: PackedInt32Array = PackedInt32Array()
var _drawn_tier: PackedInt32Array = PackedInt32Array()
var _title: Label = null
var _held: int = 0
var _jump: JumpScript = null
## How many lines fit the band (see THE STRIP KEEPS TO ITS BAND): LINES again whenever the news or the band changes.
var _fit_lines: int = LINES
## The entries the lines are chosen from (reused), and the news time they were last chosen at.
var _candidates: PackedInt32Array = PackedInt32Array()
var _last_now: int = 0
## A line's width beside its × alone, and the Go to's share of it (logical px; set by `_place`).
var _text_w: float = 0.0
var _go_w: float = 0.0
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
## Fewer toasts: warnings only, one line (see FEWER TOASTS).
var quiet: bool = false


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


func bind_jump(jump: JumpScript) -> void:
	"""Each line's Go to jumps through `jump` (none: no Go to)."""
	_jump = jump


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
	get_viewport().size_changed.connect(_on_resized)
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
	_title = _label(TITLE, TITLE_PX, Palette.UMBER, Styles.heading_font())
	column.add_child(_title)
	for k: int in LINES:
		_build_line(column, k)
	_build_history_button(column)


func _build_line(column: VBoxContainer, slot: int) -> void:
	"""Line `slot`: its words, its Go to and its × (see TIERS, GO TO AND DISMISS), hidden."""
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	row.visible = false
	column.add_child(row)
	_lines.append(_label("", LINE_PX, Palette.INK, null))
	_lines[slot].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines[slot].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_lines[slot])
	_go.append(_line_button(row, "", "Go to what this notice is about and select it", go_to.bind(slot)))
	_go[slot].name = "GoTo"
	_go[slot].set(&"accessibility_name", GO_TO)
	if ResourceLoader.exists(GO_TO_ICON):
		_go[slot].icon = load(GO_TO_ICON) as Texture2D
		_go[slot].add_theme_constant_override(&"icon_max_width", GO_TO_ICON_PX)
	else:
		_go[slot].text = GO_TO
	_close.append(_line_button(row, DISMISS, "Dismiss this notice (it stays in the history)", dismiss.bind(slot)))
	_rows.append(row)
	_shown_id.append(0)
	_drawn_tier.append(-1)


func _line_button(row: HBoxContainer, words: String, tip: String, act: Callable) -> Button:
	"""A line's wood button: the mouse only, never the keyboard focus (Space and Enter stay the HUD's)."""
	var button: Button = FarmUi.button(words, LINE_PX)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = tip
	button.pressed.connect(act)
	row.add_child(button)
	return button


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
	_history_button.custom_minimum_size.y = FarmUi.BUTTON_H
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
		_fit_lines = LINES
		_place.call_deferred()
	if _notices.revision != _seen_revision:
		_fit_lines = LINES
	var shown: int = _draw_lines(now_msec)
	var attention: int = _incidents.unresolved_count() if _incidents != null else 0
	var held: int = _notices.held_back(now_msec, NOTE_MSEC)
	if shown != _shown or _notices.revision != _seen_revision or attention != _attention or held != _held:
		_shown = shown
		_seen_revision = _notices.revision
		_show_attention(attention)
		_show_held(held)
		_frame.visible = shown > 0 or attention > 0
		_place.call_deferred()
	return shown


func _draw_lines(now_msec: int) -> int:
	"""Write the chosen entries into the lines, newest on top, and hide the rest; returns how many are drawn."""
	_last_now = now_msec
	_choose(now_msec, mini(1 if quiet else LINES, _fit_lines))
	for slot: int in _candidates.size():
		_show_line(slot, _candidates[slot])
	for rest: int in range(_candidates.size(), LINES):
		_rows[rest].visible = false
		_lines[rest].visible = false
	return _candidates.size()


func _choose(now_msec: int, most: int) -> void:
	"""The newest LINES fresh, unquiet entries (warnings only while `quiet`), newest first; past `most` of them, the
	lowest tier goes first, the oldest of it first (see THE STRIP KEEPS TO ITS BAND)."""
	_candidates.resize(0)
	for k: int in _notices.count():
		if _candidates.size() >= LINES:
			break
		var tier: int = _notices.tier(k)
		if (quiet and tier == NoticesScript.TIER_INFO) or _notices.is_quiet(k) \
				or _notices.age_msec(k, now_msec) > lifetime_msec(tier, _notices.level(k)):
			continue
		_candidates.append(k)
	while _candidates.size() > most:
		var drop: int = _candidates.size() - 1
		for at: int in range(_candidates.size() - 2, -1, -1):
			if _notices.tier(_candidates[at]) < _notices.tier(_candidates[drop]):
				drop = at
		_candidates.remove_at(drop)


static func lifetime_msec(tier: int, level: int) -> int:
	"""How long a toast stays (news-clock milliseconds): URGENT_MSEC urgent, WARNING_MSEC a warning, else NOTE_MSEC."""
	if tier == NoticesScript.TIER_URGENT:
		return URGENT_MSEC
	return WARNING_MSEC if level == NoticesScript.LEVEL_WARNING else NOTE_MSEC


func _show_held(held: int) -> void:
	"""The title, with how many recent notices were held back (see TIERS, GO TO AND DISMISS)."""
	_held = held
	_title.text = TITLE if held == 0 else HELD_WORDS % [TITLE, held]


func held_shown() -> int:
	"""How many held-back notices the title last counted (checks)."""
	return _held


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
	"""Write entry `k` into line `slot`: its short form at its tier's weight, its Go to when its subject is found."""
	var label: Label = _lines[slot]
	var text: String = _notices.short_line(k)
	if label.text != text:
		label.text = text
	var tier: int = _notices.tier(k)
	if _drawn_tier[slot] != tier:
		_drawn_tier[slot] = tier
		paint_tier(label, tier, LINE_PX, URGENT_PX)
	_shown_id[slot] = _notices.entry_id(k)
	_go[slot].visible = _jump != null and _jump.can_jump(_notices.target_kind(k), _notices.target_id(k))
	_size_line(slot)
	label.visible = true
	_rows[slot].visible = true


static func paint_tier(label: Label, tier: int, px: int, urgent_px: int) -> void:
	"""A notice line at its tier's weight (see TIERS, GO TO AND DISMISS): urgent in the heading face at `urgent_px`
	and clay; normal clay; info ink -- each at `px` but the urgent."""
	var urgent: bool = tier == NoticesScript.TIER_URGENT
	label.add_theme_color_override(&"font_color", Palette.INK if tier == NoticesScript.TIER_INFO else Palette.CLAY)
	label.add_theme_font_size_override(&"font_size", urgent_px if urgent else px)
	if urgent:
		label.add_theme_font_override(&"font", Styles.heading_font())
	else:
		label.remove_theme_font_override(&"font")


func go_to(slot: int) -> bool:
	"""Line `slot`'s Go to: select what its notice is about and centre the camera on it (false: nothing found)."""
	var k: int = _entry_at(slot)
	return k >= 0 and _jump != null and _jump.jump(_notices.target_kind(k), _notices.target_id(k))


func dismiss(slot: int) -> bool:
	"""Line `slot`'s ×: dismiss its notice (kept in the history), and redraw."""
	var k: int = _entry_at(slot)
	if k < 0 or not _notices.dismiss(k):
		return false
	refresh(_notices.now_msec())
	return true


func _entry_at(slot: int) -> int:
	"""The feed entry line `slot` shows now (-1: hidden, or its entry gone)."""
	if _notices == null or slot < 0 or slot >= LINES or not _rows[slot].visible:
		return -1
	return _notices.index_of(_shown_id[slot])


func line_can_go(slot: int) -> bool:
	"""Whether line `slot` offers Go to (checks)."""
	return _rows[slot].visible and _go[slot].visible


func line_button(slot: int, close: bool) -> Button:
	"""Line `slot`'s × (`close`) or Go to (checks)."""
	return _close[slot] if close else _go[slot]


func line_tier(slot: int) -> int:
	"""The tier line `slot` is drawn at (-1: never drawn; checks)."""
	return _drawn_tier[slot]


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
	_go_w = _go[0].get_combined_minimum_size().x + 6.0
	_text_w = band.size.x - CONTENT_MARGINS[0] - CONTENT_MARGINS[2] - _close[0].get_combined_minimum_size().x - 6.0
	for slot: int in LINES:
		_size_line(slot)
	var height: float = _fit(band.size.y)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.custom_minimum_size = Vector2(band.size.x, 0.0)
	_frame.size = Vector2(band.size.x, 0.0)
	_frame.position = Vector2(band.position.x, band.end.y - height) * _geometry.scale


func _size_line(slot: int) -> void:
	"""Line `slot` as wide as the band leaves beside its buttons (its Go to's room given back while it is hidden), and
	that wide now, before its row is next laid out: a wrapped label is measured at the width it has, so the height `_fit`
	measures is the height it is drawn at."""
	var width: float = maxf(_text_w - (_go_w if _go[slot].visible else 0.0), 0.0)
	if not is_equal_approx(_lines[slot].custom_minimum_size.x, width):
		_lines[slot].custom_minimum_size.x = width
	if not is_equal_approx(_lines[slot].size.x, width):
		_lines[slot].size.x = width
		_lines[slot].update_minimum_size()


func _fit(band_h: float) -> float:
	"""Hide the oldest drawn lines, never the first, while the strip is taller than `band_h` logical px (see THE STRIP
	KEEPS TO ITS BAND), and remember how many fit; returns the strip's height."""
	var height: float = _frame.get_combined_minimum_size().y
	while height > band_h and _shown > 1 and _notices != null:
		_fit_lines = _shown - 1
		_shown = _draw_lines(_last_now)
		height = _frame.get_combined_minimum_size().y
	return height


func _on_resized() -> void:
	"""The window changed: every line may fit again; redraw and place."""
	_fit_lines = LINES
	_refresh_in = 0.0
	_place()


func lines_fitting() -> int:
	"""How many lines the band holds now (checks)."""
	return _fit_lines


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
			DemoUiScale.percent, journal_open, geometry):
		geometry.scale = 1.0
	var centre: float = geometry.commands.get_center().x
	var half: float = minf(centre - (geometry.minimap.end.x + GAP), geometry.detail.position.x - GAP - centre)
	var band_w: float = minf(MAX_W, 2.0 * maxf(half, 0.0))
	var top: float = geometry.minimap.position.y
	var left: float = centre - band_w / 2.0
	if band_w < MIN_W:
		left = geometry.minimap.end.x + GAP
		band_w = minf(MAX_W, maxf(geometry.detail.position.x - GAP - left, 0.0))
	return Rect2(left, top, band_w, geometry.commands.position.y - GAP - top)


func frame_rect() -> Rect2:
	"""Where the strip is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
