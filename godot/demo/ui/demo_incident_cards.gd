extends CanvasLayer
## The top-centre incident card: the queue of critical and pinned incidents, ONE card at a time. Decision 0331
## (review UX-011, F11). DEMO UI over the demo's incidents (demo_incidents.gd); it writes nothing back but the
## player's own verbs on the card (pin, snooze, dismiss).
##
## WHY ONE. The HUD's alert zone once showed the two earliest demo lines for good (decision 0196), and they
## crowded out everything after them. A critical incident -- a resident in difficulty, a threat -- does need
## the top centre (UI §1: "Active alerts / Warning / critical") and must not vanish with a toast. So the
## critical and pinned incidents QUEUE (demo_incidents.gd `queue_into`: pinned first, then severity, then the
## earliest) and ONE card is drawn, saying "1 of 3"; the rest wait their turn, and every incident is also in
## the village-news history. Warnings and routine incidents never take this card unless pinned: they are in
## the history's "Needs attention" and the news strip's count.
##
## WHAT A CARD SAYS: severity WORD, source, state and count ("Critical · Water · Assigned (×2)"), the date
## and the incident's latest text, and the verbs: Go to (its target, demo_news_jump.gd), Pin / Unpin, Snooze
## (two minutes of unpaused time), Dismiss (acknowledge: gone until the condition resolves and recurs), and
## the history. A resolved critical card stays RESOLVED_LINGER_MSEC saying "Resolved", then goes.
##
## WHERE: the top centre, just under the HUD's alert zone, centred on it, as the stall banner (which it
## yields to: one surface for the most urgent thing) -- `hide_while` names what it yields to (the banner,
## the open history, which lists every card). It takes the mouse only on itself; the HUD is not modified.
##
## It refreshes a few times a second on real time (paused too), and sweeps the incidents' watches first, so
## an incident's state is current wherever it is read.

const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const JumpScript := preload("res://demo/ui/demo_news_jump.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

## The card's History button was pressed.
signal history_wanted

## Above the HUD (its CanvasLayer is 1 and comes first in the tree), under the demo's modals (2).
const LAYER: int = 1
const WIDTH: float = 460.0
const GAP: float = 10.0
const TITLE_PX: int = 14
const BODY_PX: int = 14
const BUTTON_PX: int = 13
const REFRESH_S: float = 0.25
const MARGINS: PackedFloat32Array = [16.0, 10.0, 16.0, 12.0]
const GO_TO: String = "Go to"
const PIN: String = "Pin"
const UNPIN: String = "Unpin"
const SNOOZE: String = "Snooze 2 min"
const DISMISS: String = "Dismiss"
const HISTORY: String = "All news (N)"

var _incidents: IncidentsScript = null
var _jump: JumpScript = null
var _frame: PanelContainer = null
var _title: Label = null
var _place_in_queue: Label = null
var _body: Label = null
var _go: Button = null
var _pin: Button = null
var _snooze: Button = null
var _dismiss: Button = null
var _history: Button = null
var _queue: PackedInt32Array = PackedInt32Array()
## The serial the card shows (NO_SERIAL: none), and the revision it was drawn at.
var _shown: int = IncidentsScript.NO_SERIAL
var _drawn_revision: int = -1
var _drawn_count: int = 0
var _yield_to: Array[Callable] = []
var _was_yielding: bool = false
var _refresh_in: float = 0.0
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func configure(incidents: IncidentsScript, jump: JumpScript) -> void:
	"""Show these incidents' queue; "Go to" through `jump` (none: no Go to)."""
	_incidents = incidents
	_jump = jump
	build()


func hide_while(query: Callable) -> void:
	"""Draw no card while `query()` is true (the stall banner, the open history)."""
	_yield_to.append(query)


func _ready() -> void:
	"""Place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The hidden card: its title row, its text and its verbs (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = LAYER
	name = "DemoIncidentCards"
	_frame = FarmUi.frame()
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, MARGINS))
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_frame.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	_title = FarmUi.label("", TITLE_PX, Palette.CLAY, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	_place_in_queue = FarmUi.label("", BUTTON_PX, Palette.UMBER)
	_place_in_queue.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_place_in_queue)
	_body = FarmUi.label("", BODY_PX, Palette.INK)
	_body.custom_minimum_size.x = WIDTH - MARGINS[0] - MARGINS[2]
	column.add_child(_body)
	_build_verbs(column)


func _build_verbs(column: VBoxContainer) -> void:
	"""The card's five buttons in one row."""
	var verbs := HBoxContainer.new()
	verbs.add_theme_constant_override(&"separation", 6)
	column.add_child(verbs)
	_go = _verb(verbs, GO_TO, go_to)
	_pin = _verb(verbs, PIN, toggle_pin)
	_snooze = _verb(verbs, SNOOZE, snooze)
	_dismiss = _verb(verbs, DISMISS, dismiss)
	_history = _verb(verbs, HISTORY, func() -> void: history_wanted.emit())


func _verb(row: HBoxContainer, words: String, act: Callable) -> Button:
	"""One wood button that calls `act`."""
	var button: Button = FarmUi.button(words, BUTTON_PX)
	button.pressed.connect(act)
	row.add_child(button)
	return button


func _process(delta: float) -> void:
	"""Refresh a few times a second (real time: it must read while paused) -- at once when something it yields to
	has just come up or gone."""
	var yielding: bool = _yielding()
	if yielding != _was_yielding:
		_was_yielding = yielding
		_refresh_in = 0.0
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	refresh()


func refresh() -> bool:
	"""Sweep the incidents' watches and draw the front of the queue (hidden with nothing queued, or while
	yielding). Returns whether a card is shown."""
	if _incidents == null or _frame == null:
		return false
	_incidents.sweep()
	var queued: int = _incidents.queue_into(_queue)
	var front: int = _queue[0] if queued > 0 and not _yielding() else IncidentsScript.NO_SERIAL
	if front != _shown or _incidents.revision != _drawn_revision or queued != _drawn_count:
		_shown = front
		_drawn_revision = _incidents.revision
		_drawn_count = queued
		_draw(front, queued)
	return _frame.visible


func _yielding() -> bool:
	"""Whether something the card yields to is up."""
	for query: Callable in _yield_to:
		if query.is_valid() and bool(query.call()):
			return true
	return false


func _draw(serial: int, queued: int) -> void:
	"""Write the card for `serial` ("1 of `queued`"), or hide it."""
	_frame.visible = serial != IncidentsScript.NO_SERIAL
	if not _frame.visible:
		return
	_title.text = _incidents.card_title(serial)
	var critical: bool = _incidents.severity_of(serial) == IncidentsScript.SEVERITY_CRITICAL
	_title.add_theme_color_override(&"font_color", Palette.CLAY if critical else Palette.UMBER)
	_place_in_queue.text = "1 of %d" % queued if queued > 1 else ""
	_body.text = "%s · %s" % [_incidents.stamp_of(serial), _incidents.text_of(serial)]
	_pin.text = UNPIN if _incidents.is_pinned(serial) else PIN
	var target: bool = _jump != null and _jump.can_jump(_incidents.target_kind_of(serial), _incidents.target_id_of(serial))
	FarmUi.set_enabled(_go, target, "Nothing to go to")
	_place.call_deferred()


func shown_serial() -> int:
	"""The incident the card shows (NO_SERIAL: none; checks)."""
	return _shown if _frame != null and _frame.visible else IncidentsScript.NO_SERIAL


func title_text() -> String:
	"""The card's title line (checks)."""
	return _title.text


func queue_text() -> String:
	"""The card's "1 of 3" (checks)."""
	return _place_in_queue.text


func body_text() -> String:
	"""The card's date and text (checks)."""
	return _body.text


func is_shown() -> bool:
	"""Whether the card is drawn."""
	return _frame != null and _frame.visible


func go_to() -> bool:
	"""The card's Go to: select and centre its target."""
	return _shown != IncidentsScript.NO_SERIAL and _jump != null \
		and _jump.jump(_incidents.target_kind_of(_shown), _incidents.target_id_of(_shown))


func toggle_pin() -> bool:
	"""Pin the card (or unpin it)."""
	return _shown != IncidentsScript.NO_SERIAL and _act(_incidents.pin(_shown, not _incidents.is_pinned(_shown)))


func snooze() -> bool:
	"""Snooze the card for two minutes of unpaused time; the next in the queue shows."""
	return _shown != IncidentsScript.NO_SERIAL and _act(_incidents.snooze(_shown))


func dismiss() -> bool:
	"""Acknowledge the card; the next in the queue shows."""
	return _shown != IncidentsScript.NO_SERIAL and _act(_incidents.acknowledge(_shown))


func _act(done: bool) -> bool:
	"""Redraw at once after a verb."""
	refresh()
	return done


func _place() -> void:
	"""Top centre, just under the HUD's alert zone, at the HUD's scale."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var alerts: Rect2 = _geometry.alerts
	var width: float = minf(WIDTH, _geometry.logical_width - 2.0 * GAP)
	var x: float = clampf(alerts.get_center().x - width / 2.0, GAP, _geometry.logical_width - GAP - width)
	FarmUi.place(_frame, Rect2(x, alerts.end.y + GAP, width, 0.0), _geometry.scale)


func frame_rect() -> Rect2:
	"""Where the card is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
