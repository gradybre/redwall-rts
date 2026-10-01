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
## the open history, which lists every card) -- and narrowed to the gap between the party panel's column and the
## right column where it would cover one (`card_span`, decision 0391). It takes the mouse only on itself; the HUD
## is not modified.
##
## It refreshes a few times a second on real time (paused too), and sweeps the incidents' watches first, so
## an incident's state is current wherever it is read.
##
## DETAILS (decision 0461, review P5's rescue card). An owner may give its incidents more than one line: `add_details`
## registers a provider for keys beginning with a prefix -- the water's rescues, "water:rescue:" -- which fills an
## `Extra` each refresh: lines (the phase; an approximate time, or the blockage), shown as one line under the text, and
## up to MAX_TARGETS targets, each a button at the front of the verbs' row that selects and centres it (a resident,
## through the news's jump) or centres the camera on a point (a landing). Read on real time, so it keeps working while
## the village is paused.

const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const JumpScript := preload("res://demo/ui/demo_news_jump.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const PartyScript := preload("res://demo/control/demo_party_panel.gd")

## The card's History button was pressed.
signal history_wanted

## Above the HUD (its CanvasLayer is 1 and comes first in the tree), under the demo's modals (2).
const LAYER: int = 1
const WIDTH: float = 460.0
const GAP: float = 10.0
const TITLE_PX: int = 14
const BODY_PX: int = 14
const BUTTON_PX: int = 14
const REFRESH_S: float = 0.25
const MARGINS: PackedFloat32Array = [16.0, 10.0, 16.0, 12.0]
const GO_TO: String = "Go to"
const PIN: String = "Pin"
const UNPIN: String = "Unpin"
const SNOOZE: String = "Snooze 2 min"
const DISMISS: String = "Dismiss"
const HISTORY: String = "All news (N)"
## Targets a card's details may offer (see DETAILS).
const MAX_TARGETS: int = 3


## An incident's extra lines and targets (see DETAILS), filled by its provider; reused.
class Extra:
	extends RefCounted
	var lines: PackedStringArray = PackedStringArray()
	var labels: PackedStringArray = PackedStringArray()
	var kinds: PackedInt32Array = PackedInt32Array()
	var ids: PackedInt32Array = PackedInt32Array()
	var points: PackedVector2Array = PackedVector2Array()

	func clear() -> void:
		"""Nothing extra."""
		lines.clear()
		labels.clear()
		kinds.clear()
		ids.clear()
		points.clear()

	func add_target(label: String, kind: int, id: int, point: Vector2) -> void:
		"""A target button: a target the news can jump to (`kind`, `id`), or with kind TARGET_NONE a point to centre."""
		labels.append(label)
		kinds.append(kind)
		ids.append(id)
		points.append(point)

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
## See DETAILS: the providers by key prefix, the camera's centring, and the details shown now.
var _detail_prefixes: PackedStringArray = PackedStringArray()
var _detail_providers: Array[Callable] = []
var _centre: Callable = Callable()
var _extra: Extra = Extra.new()
var _extra_label: Label = null
var _targets: Array[Button] = []
var _target_row: HFlowContainer = null


func configure(incidents: IncidentsScript, jump: JumpScript) -> void:
	"""Show these incidents' queue; "Go to" through `jump` (none: no Go to)."""
	_incidents = incidents
	_jump = jump
	build()


func hide_while(query: Callable) -> void:
	"""Draw no card while `query()` is true (the stall banner, the open history)."""
	_yield_to.append(query)


func add_details(prefix: String, provider: Callable) -> void:
	"""Incidents whose key begins with `prefix` show `provider(key: String, out: Extra) -> bool`'s details (see
	DETAILS)."""
	_detail_prefixes.append(prefix)
	_detail_providers.append(provider)


func set_centre(centre: Callable) -> void:
	"""How a point target centres the camera: `centre(point: Vector3)` (demo_camera.gd `centre_on`)."""
	_centre = centre


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
	_build_details(column)
	_build_verbs(column)
	_build_targets()


func _build_details(column: VBoxContainer) -> void:
	"""The details' line (see DETAILS), hidden until an incident has some."""
	_extra_label = FarmUi.label("", BODY_PX, Palette.UMBER)
	_extra_label.custom_minimum_size.x = WIDTH - MARGINS[0] - MARGINS[2]
	_extra_label.visible = false
	column.add_child(_extra_label)


func _build_targets() -> void:
	"""The details' target buttons, first in the verbs' row (see DETAILS), hidden until an incident has some."""
	for k: int in MAX_TARGETS:
		var button: Button = _verb(_target_row, "", go_to_target.bind(k))
		_target_row.move_child(button, k)
		button.visible = false
		_targets.append(button)


func _build_verbs(column: VBoxContainer) -> void:
	"""The card's five buttons in a row, a button that does not fit the card going to the next line."""
	var verbs := HFlowContainer.new()
	verbs.add_theme_constant_override(&"h_separation", 6)
	verbs.add_theme_constant_override(&"v_separation", 6)
	column.add_child(verbs)
	_target_row = verbs
	_go = _verb(verbs, GO_TO, go_to)
	_pin = _verb(verbs, PIN, toggle_pin)
	_snooze = _verb(verbs, SNOOZE, snooze)
	_dismiss = _verb(verbs, DISMISS, dismiss)
	_history = _verb(verbs, HISTORY, func() -> void: history_wanted.emit())


func _verb(row: HFlowContainer, words: String, act: Callable) -> Button:
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
	_fill_details(front)
	return _frame.visible


func _fill_details(serial: int) -> void:
	"""The shown incident's details (see DETAILS), every refresh: its time moves while its text may not."""
	_extra.clear()
	var key: String = _incidents.key_of(serial) if serial != IncidentsScript.NO_SERIAL else ""
	var shown: bool = false
	for k: int in _detail_prefixes.size():
		if not key.is_empty() and key.begins_with(_detail_prefixes[k]) and _detail_providers[k].is_valid():
			shown = bool(_detail_providers[k].call(key, _extra))
			break
	var text: String = " · ".join(_extra.lines) if shown else ""
	if _extra_label.text != text:
		_extra_label.text = text
		_place.call_deferred()
	_extra_label.visible = not text.is_empty()
	for k: int in MAX_TARGETS:
		var on: bool = shown and k < _extra.labels.size()
		_targets[k].visible = on
		if on and _targets[k].text != _extra.labels[k]:
			_targets[k].text = _extra.labels[k]


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


func details_text() -> String:
	"""The details' lines shown now (checks)."""
	return _extra_label.text if _extra_label != null and _extra_label.visible else ""


func target_labels() -> PackedStringArray:
	"""The details' target buttons shown now (checks)."""
	return _extra.labels.duplicate()


func go_to_target(k: int) -> bool:
	"""A details target (see DETAILS): select and centre a resident, or centre a point."""
	if k < 0 or k >= _extra.labels.size():
		return false
	if _extra.kinds[k] != NoticesScript.TARGET_NONE:
		return _jump != null and _jump.jump(_extra.kinds[k], _extra.ids[k])
	if not _centre.is_valid():
		return false
	_centre.call(Vector3(_extra.points[k].x, 0.0, _extra.points[k].y))
	return true


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
	var span: Rect2 = card_span(_geometry)
	_body.custom_minimum_size.x = span.size.x - MARGINS[0] - MARGINS[2]
	FarmUi.place(_frame, Rect2(span.position.x, _geometry.alerts.end.y + GAP, span.size.x, 0.0), _geometry.scale)


static func card_span(geometry: UiLayout.Geometry) -> Rect2:
	"""The card's x and width, logical px: WIDTH centred on the alert zone -- narrowed, where it would reach them,
	to the gap between the party panel's column and the right column (the narrow profile, 125 % on 1280x720:
	decision 0391), so the card never covers either."""
	var left_limit: float = UiLayout.SAFE_INSET + 2.0 * PartyScript.FRAME_EXPAND + PartyScript.WIDTH + GAP
	var right_limit: float = geometry.detail.position.x - GAP
	var width: float = minf(WIDTH, geometry.logical_width - 2.0 * GAP)
	var x: float = clampf(geometry.alerts.get_center().x - width / 2.0, GAP, geometry.logical_width - GAP - width)
	if x < left_limit or x + width > right_limit:
		width = minf(width, maxf(right_limit - left_limit, 0.0))
		x = clampf(geometry.alerts.get_center().x - width / 2.0, left_limit, right_limit - width)
	return Rect2(x, 0.0, width, 0.0)


func frame_rect() -> Rect2:
	"""Where the card is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
