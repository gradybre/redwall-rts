extends CanvasLayer
## THE PEOPLE'S OFFER CARD (decision 0491; review SOC-001, SOC-028): the optional spotlight after a distinctive deed,
## and the season's reflection. DEMO UI over demo_people.gd; it writes nothing but the player's own answers.
##
## ONE card at a time, top centre under the HUD's alert zone, in the incident card's own span (demo_incident_cards.gd
## `card_span`) -- and it YIELDS to it (`hide_while`): a resident in difficulty or a threat always comes first, as do
## the stall banner and the open news history. The reflection comes before a spotlight.
##   reflection   "Spring's end: moments to remember", up to three committed moments, each with Pin to chronicle,
##                Keep private and Dismiss, and Go to (its resident); Later closes it, the rest left uncurated.
##   spotlight    what happened ("Corra Netley brought Tobit Highbough ashore.") and the offer to mark the resident
##                notable -- "It changes nothing about the work" -- with Spotlight ★, Go to and Not now.
## Nothing here is a notification sound or a toast: the card waits, quietly, until answered.

const PeopleScript := preload("res://demo/people/demo_people.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const IncidentCards := preload("res://demo/ui/demo_incident_cards.gd")
const JumpScript := preload("res://demo/ui/demo_news_jump.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

const LAYER: int = 1
const GAP: float = 10.0
const TITLE_PX: int = 14
const BODY_PX: int = 14
const REFRESH_S: float = 0.25
const MARGINS: PackedFloat32Array = [16.0, 10.0, 16.0, 12.0]
const SPOTLIGHT_TITLE: String = "Spotlight"
const SPOTLIGHT: String = "Spotlight ★"
const NOT_NOW: String = "Not now"
const GO_TO: String = "Go to"
const PIN: String = "Pin to chronicle"
const PRIVATE: String = "Keep private"
const DISMISS: String = "Dismiss"
const LATER: String = "Later"
const MODE_NONE: int = 0
const MODE_REFLECTION: int = 1
const MODE_SPOTLIGHT: int = 2

var _people: PeopleScript = null
var _jump: JumpScript = null
var _frame: PanelContainer = null
var _title: Label = null
var _body: Label = null
var _moments: VBoxContainer = null
var _moment_text: Array[Label] = []
var _moment_buttons: Array[HFlowContainer] = []
var _verbs: HFlowContainer = null
var _yes: Button = null
var _go: Button = null
var _no: Button = null
var _mode: int = MODE_NONE
var _drawn_revision: int = -1
var _yield_to: Array[Callable] = []
var _was_yielding: bool = false
var _refresh_in: float = 0.0
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func configure(people: PeopleScript, jump: JumpScript) -> void:
	"""Offer these people's spotlights and reflections; Go to through `jump` (none: no Go to)."""
	_people = people
	_jump = jump
	build()


func hide_while(query: Callable) -> void:
	"""Draw no card while `query()` is true (the incident card, the stall banner, the open history)."""
	_yield_to.append(query)


func _ready() -> void:
	"""Place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The hidden card (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = LAYER
	name = "PeopleCard"
	_frame = FarmUi.frame()
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, MARGINS))
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	_title = FarmUi.label("", TITLE_PX, Palette.UMBER, true)
	column.add_child(_title)
	_body = FarmUi.label("", BODY_PX, Palette.INK)
	column.add_child(_body)
	_moments = VBoxContainer.new()
	_moments.add_theme_constant_override(&"separation", 6)
	column.add_child(_moments)
	for k: int in Ledger.REFLECTION_SIZE:
		_add_moment(k)
	_verbs = _flow()
	column.add_child(_verbs)
	_yes = _verb(_verbs, SPOTLIGHT, accept)
	_go = _verb(_verbs, GO_TO, go_to)
	_no = _verb(_verbs, NOT_NOW, decline)


func _flow() -> HFlowContainer:
	"""A row of buttons that wraps."""
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 6)
	flow.add_theme_constant_override(&"v_separation", 6)
	return flow


func _verb(row: HFlowContainer, words: String, act: Callable) -> Button:
	"""One wood button that calls `act`."""
	var button: Button = FarmUi.button(words, BODY_PX)
	button.pressed.connect(func() -> void: act.call())
	row.add_child(button)
	return button


func _add_moment(k: int) -> void:
	"""Reflection moment `k`: its words and its four answers."""
	var text: Label = FarmUi.label("", BODY_PX, Palette.INK)
	_moments.add_child(text)
	var buttons: HFlowContainer = _flow()
	_verb(buttons, PIN, curate.bind(k, Ledger.CURATION_PINNED))
	_verb(buttons, PRIVATE, curate.bind(k, Ledger.CURATION_PRIVATE))
	_verb(buttons, DISMISS, curate.bind(k, Ledger.CURATION_DISMISSED))
	_verb(buttons, GO_TO, go_to_moment.bind(k))
	_moments.add_child(buttons)
	_moment_text.append(text)
	_moment_buttons.append(buttons)


func _process(delta: float) -> void:
	"""Refresh a few times a second on real time (it reads while paused), at once when what it yields to changed."""
	var yielding: bool = _yielding()
	if yielding != _was_yielding:
		_was_yielding = yielding
		_refresh_in = 0.0
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	refresh()


func _yielding() -> bool:
	"""Whether something the card yields to is up."""
	for query: Callable in _yield_to:
		if query.is_valid() and bool(query.call()):
			return true
	return false


func refresh() -> bool:
	"""Draw the front offer (the reflection first), or hide; returns whether the card shows."""
	if _people == null or _frame == null:
		return false
	var mode: int = MODE_NONE
	if not _yielding():
		mode = MODE_REFLECTION if _people.has_reflection() else (MODE_SPOTLIGHT if _people.has_offer() else MODE_NONE)
	if mode != _mode or _people.revision != _drawn_revision:
		_mode = mode
		_drawn_revision = _people.revision
		_draw()
	return _frame.visible


func _draw() -> void:
	"""Write the card for its mode."""
	_frame.visible = _mode != MODE_NONE
	if not _frame.visible:
		return
	var reflecting: bool = _mode == MODE_REFLECTION
	_title.text = _people.reflection_title() if reflecting else SPOTLIGHT_TITLE
	_body.text = "" if reflecting else _people.offer_text()
	_body.visible = not reflecting
	for k: int in _moment_text.size():
		var line: String = _people.reflection_line(k) if reflecting else ""
		_moment_text[k].text = line
		_moment_text[k].visible = not line.is_empty()
		_moment_buttons[k].visible = not line.is_empty()
	_yes.visible = not reflecting
	_go.visible = not reflecting
	_no.text = LATER if reflecting else NOT_NOW
	_place.call_deferred()


func accept() -> bool:
	"""Spotlight ★: the front offer's resident is marked notable."""
	var done: bool = _people != null and _people.accept_offer()
	refresh()
	return done


func decline() -> bool:
	"""Not now (a spotlight) or Later (the reflection)."""
	if _people == null:
		return false
	if _mode == MODE_REFLECTION:
		_people.close_reflection()
	else:
		_people.decline_offer()
	refresh()
	return true


func go_to() -> bool:
	"""The spotlight's resident: selected, the camera over it."""
	return _jump != null and _people != null and _people.has_offer() \
		and _jump.jump(NoticesScript.TARGET_RESIDENT, _people.offer_who[0])


func curate(k: int, curation: int) -> bool:
	"""Reflection moment `k`: pinned, kept private or dismissed."""
	var done: bool = _people != null and _people.curate_reflection(k, curation)
	refresh()
	return done


func go_to_moment(k: int) -> bool:
	"""Reflection moment `k`'s resident: selected, the camera over it."""
	if _jump == null or _people == null or k >= _people.reflection_deeds.size():
		return false
	return _jump.jump(NoticesScript.TARGET_RESIDENT, _people.ledger.lead_of(_people.reflection_deeds[k]))


func _place() -> void:
	"""Top centre under the HUD's alert zone, in the incident card's span, at the HUD's scale."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var span: Rect2 = IncidentCards.card_span(_geometry)
	var inner: float = span.size.x - MARGINS[0] - MARGINS[2]
	_body.custom_minimum_size.x = inner
	for text: Label in _moment_text:
		text.custom_minimum_size.x = inner
	FarmUi.place(_frame, Rect2(span.position.x, _geometry.alerts.end.y + GAP, span.size.x, 0.0), _geometry.scale)


# --- checks -----------------------------------------------------------------------------------------------

func is_shown() -> bool:
	"""Whether the card is drawn."""
	return _frame != null and _frame.visible


func mode() -> int:
	"""MODE_*: what the card shows."""
	return _mode if is_shown() else MODE_NONE


func title_text() -> String:
	"""The card's title."""
	return _title.text


func body_text() -> String:
	"""The spotlight's words."""
	return _body.text


func moment_text(k: int) -> String:
	"""Reflection moment `k`'s words ("" when not shown)."""
	return _moment_text[k].text if k < _moment_text.size() and _moment_text[k].visible else ""


func frame_rect() -> Rect2:
	"""Where the card is drawn, in viewport pixels."""
	return Rect2(_frame.position, _frame.size * _frame.scale)


func spotlight_button() -> Button:
	"""Spotlight ★ (checks)."""
	return _yes
