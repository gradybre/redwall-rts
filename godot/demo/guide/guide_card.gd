extends CanvasLayer
## THE OBJECTIVE CARD (UI-SET-072, "Tutorial card": top centre below the alerts, 280x120 to 420x192, one card, Next and
## Skip, never intercepting the world outside itself). Decision 0481; review F49, P7. DEMO UI in the woodland skin.
##
## ONE CARD, ONE OBJECTIVE. It shows the current objective only: "Guide 2 of 4 · Bring in a harvest", its teaching
## (what and why), the CAUSE or BLOCKER now, the NEXT legal action, and -- for the fourth -- its three ways with where
## each stands. Once the objective's real outcome happens, the card CONFIRMS it with the real figures ("5.1 U of carrot
## came into store"), then moves on. Its verbs: Show me (the camera to the brass marker, and the target's own panel),
## Help (this step's how-to in the village guide), Hide guide (skip: reopen from the game menu or Objectives, O);
## while confirming, Next.
##
## It only shows and asks: every verb is a signal demo_guide.gd answers. It yields to what `hide_while` names (the stall
## banner, the open history, a critical incident's card -- one card at the top centre, the most urgent), and takes the
## mouse on itself only.
##
## ROOM. It stands under the alert zone, between the side columns, and never reaches the Map layer picker below it
## (`set_avoid`): where the whole card would, it drops its teaching and the fourth objective's three ways (COMPACT --
## the next action stays), then its next action too (MINIMAL: what it is and where it stands, and its verbs). Where even
## that cannot fit -- 125 % on 1280x720 with a layer's legend unfolded -- it waits until there is room; the village
## guide (O) still lists every objective's state.

const StatusScript := preload("res://demo/guide/guide_status.gd")
const StepsScript := preload("res://demo/guide/guide_steps.gd")
const Text := preload("res://demo/guide/guide_text.gd")
const GuideUi := preload("res://demo/guide/guide_ui.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const CardsScript := preload("res://demo/ui/demo_incident_cards.gd")

signal show_me_pressed
signal help_pressed
signal hide_pressed
signal next_pressed
signal close_pressed

## With the incident card (1), under the demo's modals (2).
const LAYER: int = 1
## UI-SET-072's widest.
const MAX_WIDTH: float = 420.0
const GAP: float = 10.0
const TITLE_PX: int = 15
const BODY_PX: int = 14
const MARGINS: PackedFloat32Array = [16.0, 10.0, 16.0, 12.0]
const DENSITY_FULL: int = 0
const DENSITY_COMPACT: int = 1
const DENSITY_MINIMAL: int = 2

var _frame: PanelContainer = null
var _title: Label = null
var _teach: Label = null
var _state: Label = null
var _next: Label = null
var _choices: Label = null
var _show: Button = null
var _help: Button = null
var _hide: Button = null
var _go_next: Button = null
var _close: Button = null
var _yield_to: Array[Callable] = []
## `avoid() -> Rect2`: what the card must stay above (the Map layer picker), viewport px; empty when none.
var _avoid: Callable = Callable()
var _last_avoid: Rect2 = Rect2()
var _wanted: bool = false
## The card's density (DENSITY_*), whether even MINIMAL found no room, and whether the teaching line is optional
## (it is while teaching; confirming or complete it carries the message).
var _density: int = 0
var _cramped: bool = false
var _teach_optional: bool = true
var _replace_queued: bool = false
var _width: float = MAX_WIDTH
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func _init() -> void:
	"""Built hidden, above the HUD."""
	name = "GuideCard"
	layer = LAYER
	_build()


func _ready() -> void:
	"""Place, and follow the viewport's size and the frame's content."""
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	"""The frame: title, teaching, state, next, the fourth objective's ways, the verbs."""
	_frame = FarmUi.frame()
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, MARGINS))
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	_frame.add_child(column)
	var inner: float = MAX_WIDTH - MARGINS[0] - MARGINS[2]
	_title = GuideUi.line("", TITLE_PX, Palette.INK, inner, true)
	_teach = GuideUi.line("", BODY_PX, Palette.UMBER, inner)
	_state = GuideUi.line("", BODY_PX, Palette.INK, inner)
	_next = GuideUi.line("", BODY_PX, Palette.LEAF, inner)
	_choices = GuideUi.line("", BODY_PX, Palette.INK, inner)
	for line: Label in [_title, _teach, _state, _next, _choices]:
		column.add_child(line)
	_build_verbs(column)


func _build_verbs(column: VBoxContainer) -> void:
	"""Show me, Help, Hide guide; Next while confirming; Close once complete."""
	var verbs: HFlowContainer = GuideUi.row(6)
	column.add_child(verbs)
	_show = _verb(verbs, Text.SHOW_ME, Text.SHOW_TIP, show_me_pressed)
	_go_next = _verb(verbs, Text.NEXT, Text.NEXT_TIP, next_pressed)
	_help = _verb(verbs, Text.HELP, Text.HELP_TIP, help_pressed)
	_hide = _verb(verbs, Text.HIDE, Text.HIDE_TIP, hide_pressed)
	_close = _verb(verbs, Text.CLOSE, Text.HIDE_TIP, close_pressed)


func _verb(row: HFlowContainer, words: String, tip: String, said: Signal) -> Button:
	"""One wood button that emits `said`."""
	var made: Button = FarmUi.button(words, BODY_PX)
	made.tooltip_text = tip
	made.pressed.connect(func() -> void: said.emit())
	row.add_child(made)
	return made


func hide_while(query: Callable) -> void:
	"""Draw no card while `query()` is true."""
	_yield_to.append(query)


func set_avoid(query: Callable) -> void:
	"""`query() -> Rect2`: what to stay above (viewport px; empty: nothing)."""
	_avoid = query


# --- what it shows -----------------------------------------------------------------------------------

func show_trying(step: int, status: StatusScript.Status) -> void:
	"""The current objective, teaching: title, why, the cause or blocker, the next action, the ways (objective 4)."""
	_title.text = Text.CARD_TITLE % [step + 1, StepsScript.STEP_COUNT, status.title]
	_put(_teach, status.teach, Palette.UMBER)
	_put(_state, status.state, Palette.INK)
	_put(_next, "Next: " + status.next if not status.next.is_empty() else "", Palette.LEAF)
	_put(_choices, "\n".join(status.choices), Palette.INK)
	_teach_optional = true
	_show_verbs(status.target_point != Vector3.INF, false, false)


func show_confirming(step: int, title: String, said: String, already: bool) -> void:
	"""The objective just done, with what really happened (prefixed 'Already done:' when it was done first)."""
	_title.text = Text.CARD_TITLE % [step + 1, StepsScript.STEP_COUNT, title]
	_put(_teach, (Text.ALREADY_DONE if already else "") + said, Palette.INK)
	_put(_state, "", Palette.INK)
	_put(_next, "", Palette.LEAF)
	_put(_choices, "", Palette.INK)
	_teach_optional = false
	_show_verbs(false, true, false)


func show_complete() -> void:
	"""The guide's end: the community acknowledged, free play goes on."""
	_title.text = Text.COMPLETE_TITLE
	_put(_teach, Text.COMPLETE_TEXT, Palette.INK)
	for line: Label in [_state, _next, _choices]:
		_put(line, "", Palette.INK)
	_teach_optional = false
	_show_verbs(false, false, true)


func _put(line: Label, words: String, colour: Color) -> void:
	"""A line's text and colour; an empty line takes no room. New words place the card again (its density may change)."""
	if line.text != words:
		line.text = words
		if not _replace_queued:
			_replace_queued = true
			_place.call_deferred()
	if line.get_theme_color(&"font_color") != colour:
		line.add_theme_color_override(&"font_color", colour)
	_apply_density()


func _show_verbs(can_show: bool, confirming: bool, complete: bool) -> void:
	"""Which verbs stand: Show me (with a target), Next (confirming), Help and Hide (not at the end), Close (at it)."""
	_show.visible = can_show and not confirming and not complete
	_go_next.visible = confirming
	_help.visible = not complete
	_hide.visible = not complete
	_close.visible = complete


func set_wanted(wanted: bool) -> void:
	"""Whether the guide wants the card shown (hidden by the player, or nothing to show)."""
	_wanted = wanted
	_apply_visibility()


func _apply_visibility() -> void:
	"""Shown when wanted and nothing it yields to is up."""
	var yielding: bool = false
	for query: Callable in _yield_to:
		if query.is_valid() and bool(query.call()):
			yielding = true
	var shown: bool = _wanted and not yielding and not _cramped
	if _frame.visible != shown:
		_frame.visible = shown
		_place.call_deferred()


func _process(_delta: float) -> void:
	"""Follow what the card yields to, and what it stays above (placed again only when that moved)."""
	if _avoid.is_valid():
		var below: Rect2 = _avoid.call() as Rect2
		if below != _last_avoid:
			_last_avoid = below
			_place()
	_apply_visibility()


func _apply_density() -> void:
	"""Each line shown when it has words and the density keeps it (see ROOM)."""
	_title.visible = true
	_teach.visible = not _teach.text.is_empty() and (_density == DENSITY_FULL or not _teach_optional)
	_state.visible = not _state.text.is_empty()
	_next.visible = not _next.text.is_empty() and _density != DENSITY_MINIMAL
	_choices.visible = not _choices.text.is_empty() and _density == DENSITY_FULL


# --- placement ---------------------------------------------------------------------------------------

func _place() -> void:
	"""Top centre under the alert zone at the HUD's scale, between the side columns (the incident card's span, at most
	UI-SET-072's 420 wide), as dense as the room above the Map layer picker allows (see ROOM)."""
	_replace_queued = false
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var span: Rect2 = CardsScript.card_span(_geometry)
	_width = minf(span.size.x, MAX_WIDTH)
	var x: float = span.position.x + (span.size.x - _width) / 2.0
	var y: float = _geometry.alerts.end.y + GAP
	var inner: float = _width - MARGINS[0] - MARGINS[2]
	for line: Label in [_title, _teach, _state, _next, _choices]:
		line.custom_minimum_size.x = inner
	var limit: float = _limit_px(x, _width)
	var was_cramped: bool = _cramped
	_cramped = true
	for density: int in [DENSITY_FULL, DENSITY_COMPACT, DENSITY_MINIMAL]:
		_density = density
		_apply_density()
		if (y + _measure()) * _geometry.scale <= limit:
			_cramped = false
			break
	FarmUi.place(_frame, Rect2(x, y, _width, 0.0), _geometry.scale)
	if was_cramped != _cramped:
		_apply_visibility()


func _measure() -> float:
	"""The card's height, logical px, as its lines stand now. A container's minimum size is refreshed only at the end
	of the frame after a child changes, so every level is told first -- or a density just chosen would be measured
	as the one before it."""
	for control: Control in [_title, _teach, _state, _next, _choices, _title.get_parent() as Control, _frame]:
		control.update_minimum_size()
	return _frame.get_combined_minimum_size().y


func _limit_px(x: float, width: float) -> float:
	"""How far down the card may reach, viewport px: above what it avoids where that is under its span, else the
	window's foot."""
	var bottom: float = get_viewport().get_visible_rect().size.y
	var below: Rect2 = _avoid.call() as Rect2 if _avoid.is_valid() else Rect2()
	var mine := Rect2(x * _geometry.scale, 0.0, width * _geometry.scale, bottom)
	if below.has_area() and below.intersects(mine):
		return below.position.y - GAP * _geometry.scale
	return bottom


# --- checks ------------------------------------------------------------------------------------------

func frame() -> PanelContainer:
	"""The card's frame (the input gate's region root)."""
	return _frame


func is_shown() -> bool:
	"""Whether the card is drawn now."""
	return _frame.visible


func frame_rect() -> Rect2:
	"""Where the card is drawn, viewport px."""
	return Rect2(_frame.position, _frame.size * _frame.scale)


func text() -> String:
	"""Every visible line, one per line (checks)."""
	var lines := PackedStringArray()
	for line: Label in [_title, _teach, _state, _next, _choices]:
		if line.visible:
			lines.append(line.text)
	return "\n".join(lines)


func button(which: String) -> Button:
	"""A verb's button by its words (checks): Show me, Help, Hide guide, Next ▸, Close."""
	for candidate: Button in [_show, _help, _hide, _go_next, _close]:
		if candidate.text == which:
			return candidate
	return null
