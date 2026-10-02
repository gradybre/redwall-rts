extends CanvasLayer
## THE PAUSE CARD: why the village is paused, and the one Resume. Decision 0471 (review UX-022). DEMO UI in the
## woodland skin, in UI-SET-086's place (the HUD's "Paused: PLAYER" label, top centre, which it stands in for: the
## shell's label is hidden while the demo runs, time_control.gd).
##
## WHAT IT SAYS: "Paused — " and every standing reason in the ledger's words, most urgent first (pause_ledger.gd:
## "Critical: Mouse keeper is in difficulty in the water · Planning: the Pantry is open · You paused"), and, after a
## "Run until..." ended at this pause, what became of it. Then RESUME (Space): the ledger's Resume, which clears the
## player's, the planning and the critical-incident pause and never the game menu's or a stall's -- disabled, with the
## reason as its tooltip, while only those stand ("Close the game menu to resume").
##
## WHERE: centred on the HUD's alert column, at its top (under the HUD's alert cards when they show), one row so it
## stays inside the alert zone; it steps below the incident card if the two would meet. WHILE A POP-UP IS OPEN (the
## Pantry, the Work screen, the object list: `modal_open`) it rises above the pop-ups' layer and moves to the bottom
## centre, so a planning pause is said beside the panel that holds it, and its Resume runs the village with the panel
## still open. Hidden while the village runs, while the stall banner shows (that banner is the stall's surface and its
## Resume), while the game menu is open (the menu says the village is paused), and until the village has opened.
## Refreshed a few times a second on real time; it takes the mouse only on itself.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const LedgerScript := preload("res://demo/session/pause_ledger.gd")

## Above the HUD (1, earlier in the tree), with the incident card; under the modals (2) -- above them while one is
## open (MODAL_LAYER, under the stall banner's 3).
const LAYER: int = 1
const MODAL_LAYER: int = 2
const MAX_W: float = 440.0
const GAP: float = 6.0
const PX: int = 15
const RESUME_TEXT: String = "Resume (Space)"
const RESUME_TIP: String = "Clears %s; the village runs on at %dx"
const PAUSED_PREFIX: String = "Paused — "
const REFRESH_S: float = 0.1
const MARGINS: PackedFloat32Array = [12.0, 6.0, 8.0, 6.0]
## The row's gap and Resume's width (logical px): the words wrap in what is left, from the start.
const ROW_GAP: float = 10.0
const RESUME_W: float = 132.0
const CLEARS_WORDS: Array[String] = ["your pause", "the planning pause", "the critical pause"]
const CLEARS_KINDS: PackedInt32Array = [LedgerScript.KIND_PLAYER, LedgerScript.KIND_PLANNING, LedgerScript.KIND_CRITICAL]

## `() -> bool` each: hide while any is true (the stall banner shown; the village not yet open).
var hide_while: Array[Callable] = []
## `() -> String`: a line about the last "Run until..." that ended at this pause ("" none).
var run_note: Callable = Callable()
## `() -> Rect2`: something drawn under the alert zone to keep clear of, in viewport px (the incident card).
var avoid: Callable = Callable()
## `() -> bool`: whether the HUD's own alert cards are showing (the card then sits under them).
var hud_cards_shown: Callable = Callable()
## `() -> bool`: whether a demo pop-up is open (the card then sits above it, bottom centre).
var modal_open: Callable = Callable()
## The Resume itself, `() -> int` (the ledger's `resume`).
var on_resume: Callable = Callable()

var _ledger: LedgerScript = null
var _speed: Callable = Callable()
var _frame: PanelContainer = null
var _text: Label = null
var _resume: Button = null
var _reasons: PackedStringArray = PackedStringArray()
var _refresh_in: float = 0.0
## The kinds shown at the last refresh (a change is shown the same frame, not a refresh later).
var _shown_kinds: int = -1
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func _init() -> void:
	"""Hidden: one row, the reasons and Resume."""
	name = "DemoPauseCard"
	layer = LAYER
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_NOTICE, MARGINS))
	_frame.visible = false
	add_child(_frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", int(ROW_GAP))
	_frame.add_child(row)
	_text = FarmUi.label("", PX, Palette.text_on(Palette.SURFACE_LACQUER))
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_text)
	_resume = FarmUi.button(RESUME_TEXT)
	_resume.custom_minimum_size.x = RESUME_W
	_resume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_resume.pressed.connect(_on_resume)
	row.add_child(_resume)


func configure(ledger: LedgerScript, speed: Callable) -> void:
	"""Read this ledger's reasons; `speed() -> int` is the speed Resume runs on at."""
	_ledger = ledger
	_speed = speed


func _ready() -> void:
	"""Follow the viewport's size; keep reading while anything pauses."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_place)


func _process(delta: float) -> void:
	"""A few times a second, and at once when the kinds standing change: show the reasons, or hide."""
	_refresh_in -= delta
	if _refresh_in > 0.0 and (_ledger == null or _ledger.kinds() == _shown_kinds):
		return
	_refresh_in = REFRESH_S
	refresh()


func refresh() -> bool:
	"""Show the standing reasons and Resume's state, or hide; returns whether shown."""
	_shown_kinds = _ledger.kinds() if _ledger != null else 0
	var shown: bool = _shown_kinds != 0 and not _hidden()
	if shown:
		_ledger.reasons_into(_reasons)
		var note: String = String(run_note.call()) if run_note.is_valid() else ""
		if not note.is_empty():
			_reasons.append(note)
		var line: String = PAUSED_PREFIX + " · ".join(_reasons)
		if line != _text.text:
			_text.text = line
			_place.call_deferred()
		_paint_resume()
	var over: bool = shown and modal_open.is_valid() and bool(modal_open.call())
	if (layer == MODAL_LAYER) != over:
		layer = MODAL_LAYER if over else LAYER
		_place.call_deferred()
	if shown != _frame.visible:
		_frame.visible = shown
		_place.call_deferred()
	return shown


func _hidden() -> bool:
	"""Whether something asks the card to stay hidden."""
	for query: Callable in hide_while:
		if query.is_valid() and bool(query.call()):
			return true
	return false


func _paint_resume() -> void:
	"""Resume enabled with what it clears, or disabled with why not."""
	var why: String = _ledger.resume_refusal()
	FarmUi.set_enabled(_resume, why.is_empty(), why)
	if why.is_empty():
		_resume.tooltip_text = RESUME_TIP % [clears_words(_ledger.kinds()), int(_speed.call()) if _speed.is_valid() else 1]


static func clears_words(kinds: int) -> String:
	"""What Resume clears, in words: 'your pause and the planning pause'."""
	var words := PackedStringArray()
	for k: int in CLEARS_KINDS.size():
		if kinds & CLEARS_KINDS[k] != 0:
			words.append(CLEARS_WORDS[k])
	return " and ".join(words)


func _on_resume() -> void:
	"""The button: the ledger's Resume, then repaint at once."""
	if on_resume.is_valid():
		on_resume.call()
	refresh()


# --- checks -----------------------------------------------------------------------------------------------

func is_shown() -> bool:
	"""Whether the card is up."""
	return _frame.visible


func text() -> String:
	"""What the card says."""
	return _text.text


func resume_button() -> Button:
	"""The card's Resume."""
	return _resume


func frame_rect() -> Rect2:
	"""Where the card is drawn, in viewport pixels."""
	return Rect2(_frame.position, _frame.size * _frame.scale)


func _place() -> void:
	"""Top centre on the alert column (under the HUD's cards when they show; under the incident card if they meet)."""
	if not is_inside_tree():
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var alerts: Rect2 = _geometry.alerts
	var width: float = minf(MAX_W, alerts.size.x)
	var top: float = alerts.position.y
	if hud_cards_shown.is_valid() and bool(hud_cards_shown.call()):
		top = alerts.end.y + GAP
	_text.custom_minimum_size.x = width - MARGINS[0] - MARGINS[2] - ROW_GAP - RESUME_W
	FarmUi.place(_frame, Rect2(alerts.get_center().x - width / 2.0, top, width, 0.0), _geometry.scale)
	_frame.reset_size()
	if layer == MODAL_LAYER:
		_frame.position.y = get_viewport().get_visible_rect().size.y - (_frame.size.y + GAP) * _geometry.scale
		return
	var clear: Rect2 = avoid.call() if avoid.is_valid() else Rect2()
	if clear.has_area() and frame_rect().intersects(clear):
		_frame.position.y = clear.end.y + GAP * _geometry.scale
