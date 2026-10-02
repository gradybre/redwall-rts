extends CanvasLayer
## "Village news": the demo's notification history. Decision 0331 (review F11, UX-011; the review's P1 "Village
## news / chronicle" row). DEMO UI over the one feed (demo_notices.gd) and the incidents (demo_incidents.gd).
##
## WHY. The news strip shows the newest three lines for a few seconds; the farm's, the woods' and the water's
## panels show their own latest few. A warning that came while the player read another panel, or that a
## burst of reports pushed off the strip, could not be found again, and the shell's notification history
## (N) does not hold demo notices. This window holds everything the feed keeps (CAPACITY entries) and every
## incident still open, and is what N and the HUD's history trigger open in the demo.
##
## WHAT, top to bottom:
##   * the title, "Settlement notices" (the shell's own history, for the HUD's settlement conditions), "Chronicle" (the
##     village chronicle's book, decision 0631) and ×;
##   * the FILTERS: by place (All, or any of Farm, Woods, Tunnels, Water, Village -- demo_notices.gd GROUP_*;
##     the first place chosen from All shows that place alone, later ones add to it, the last one taken off
##     shows All again) and by tier (All, Urgent, Normal, Info: see TIERS, SNOOZE AND DISMISS);
##   * NEEDS ATTENTION: every unresolved or pinned incident (filtered by place), most urgent first, each with
##     its severity word, state, count and date, its text, and Go to / Pin / Snooze / Dismiss. "No active
##     problems" when there are none -- which erases nothing below;
##   * HISTORY: every kept entry passing the filters, newest first, "<date> · <place> · Warning: <text>",
##     with Go to where the entry names a target. "Still open" marks an entry whose incident is unresolved.
## Go to (demo_news_jump.gd) selects the target and centres the camera on it, and closes this window so the
## target is not under it. Nothing here expires: it is the place where nothing actionable is lost.
##
## TIERS, SNOOZE AND DISMISS (decision 0591, feature #39). The severity filter is the TIER filter: All, or any of
## Urgent, Normal and Info (demo_notices.gd TIERS; picked like the places). Each history row is drawn at its tier's
## weight (the news strip's `paint_tier`) and has, beside Go to, SNOOZE -- quiet that kind of notice for
## demo_notices.gd SNOOZE_HOURS game hours, "Wake" while it is quiet; never on an urgent one -- and DISMISS (that one
## notice off the strip; the row stays, "— dismissed"). While any kind is snoozed a line under the filters names them
## with the hours left, and "Wake all".
##
## WHERE: top centre, below the HUD's alert zone, centred on it (UI §1: "Notification history expands from
## top-center"), as wide as MAX_W allows, down to just above the command strip; its body scrolls. It is not
## modal (UI §3 layer 30: an expansion, the latest opened takes focus): the world outside it still takes
## clicks. Esc closes it; N toggles it (read before the HUD's own handler) and so does the HUD's trigger
## (demo_village.gd routes the shell's command here, `take_trigger`).
## Rows are pooled and only grow; a refresh rewrites text, a few times a second, only when something changed.

const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const JumpScript := preload("res://demo/ui/demo_news_jump.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const StripScript := preload("res://demo/ui/demo_news_strip.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const LAYER: int = 1
const TITLE: String = "Village news"
const MAX_W: float = 680.0
const MAX_H: float = 600.0
const GAP: float = 10.0
const TITLE_PX: int = 18
const SECTION_PX: int = 15
const ROW_PX: int = 14
const BUTTON_PX: int = 14
const REFRESH_S: float = 0.25
const NO_PROBLEMS: String = "No active problems."
const NO_MATCHES: String = "No notices match these filters."
const STILL_OPEN: String = " — still open"
const DISMISSED: String = " — dismissed"
const SNOOZE: String = "Snooze %d h"
const WAKE: String = "Wake"
const DISMISS: String = "Dismiss"
const SNOOZED_WORDS: String = "Snoozed: %s"
## An urgent history row's size (the rest are ROW_PX).
const URGENT_PX: int = 15
## History rows drawn at first, and added by each "Show older" (a redraw rewrites only rows that changed).
const PAGE: int = 40
const UNDRAWN: int = 255

var _notices: NoticesScript = null
var _incidents: IncidentsScript = null
var _jump: JumpScript = null
var _settlement: Callable = Callable()
## What "Chronicle" opens: the village chronicle's book (decision 0631; unset: the button is hidden).
var _chronicle: Callable = Callable()
var _defer_to: Array[Callable] = []
## The history's rows: what each shows (target kind and id, two per row; the level drawn), and how many may be
## drawn (PAGE more each "Show older").
var _history_target: PackedInt32Array = PackedInt32Array()
## The tier each history row was last painted at (UNDRAWN: never), so a redraw repaints only a changed row.
var _history_level: PackedByteArray = PackedByteArray()
## The entry id each history row shows (its Snooze and Dismiss act on it).
var _history_id: PackedInt32Array = PackedInt32Array()
var _history_limit: int = PAGE
var _older: Button = null
var _frame: PanelContainer = null
var _body: VBoxContainer = null
var _attention_title: Label = null
var _attention_empty: Label = null
var _history_title: Label = null
var _history_empty: Label = null
var _group_buttons: Array[Button] = []
var _show_buttons: Array[Button] = []
var _attention_rows: Array[VBoxContainer] = []
var _history_rows: Array[HBoxContainer] = []
## What each pooled row shows: an incident serial, a feed entry index.
var _attention_serial: PackedInt32Array = PackedInt32Array()
var _attention_list: PackedInt32Array = PackedInt32Array()
var _history_list: PackedInt32Array = PackedInt32Array()
var _group_mask: int = NoticesScript.ALL_GROUPS
var _tier_mask: int = NoticesScript.ALL_TIERS
var _drawn_key: Vector3i = Vector3i(-1, -1, -1)
## The game hour the snoozed line was drawn in (its hours left change with it; -1: none drawn).
var _drawn_hour: int = -1
var _snoozed_row: HBoxContainer = null
var _snoozed_label: Label = null
var _snoozed_kinds: PackedStringArray = PackedStringArray()
var _snoozed_words: PackedStringArray = PackedStringArray()
var _refresh_in: float = 0.0
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func configure(notices: NoticesScript, incidents: IncidentsScript, jump: JumpScript) -> void:
	"""Show this feed and these incidents; Go to through `jump` (none: no Go to)."""
	_notices = notices
	_incidents = incidents
	_jump = jump
	build()


func set_settlement(open_settlement: Callable) -> void:
	"""What "Settlement notices" opens: the HUD shell's own history (none: the button is hidden)."""
	_settlement = open_settlement
	if _frame != null:
		_frame.find_child("Settlement", true, false).visible = open_settlement.is_valid()


func set_chronicle(open_chronicle: Callable) -> void:
	"""What "Chronicle" opens: the village chronicle (decision 0631; none: the button is hidden)."""
	_chronicle = open_chronicle
	if _frame != null:
		_frame.find_child("Chronicle", true, false).visible = open_chronicle.is_valid()


func _ready() -> void:
	"""Place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The hidden window: header, filters and the scrolling body (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = LAYER
	name = "DemoNewsHistory"
	_frame = FarmUi.frame()
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	_build_header(column)
	_build_filters(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_body)
	_build_sections()


func _build_header(column: VBoxContainer) -> void:
	"""The title, "Settlement notices" and the close."""
	var row := HBoxContainer.new()
	column.add_child(row)
	var title: Label = FarmUi.label(TITLE, TITLE_PX, Palette.UMBER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var settlement: Button = FarmUi.button("Settlement notices", BUTTON_PX)
	settlement.name = "Settlement"
	settlement.tooltip_text = "The HUD's own notification history: the settlement's conditions"
	settlement.visible = false
	settlement.pressed.connect(_on_settlement)
	row.add_child(settlement)
	var chronicle: Button = FarmUi.button("Chronicle", BUTTON_PX)
	chronicle.name = "Chronicle"
	chronicle.tooltip_text = "The village chronicle: a page for each season, from what the village recorded"
	chronicle.visible = _chronicle.is_valid()
	chronicle.pressed.connect(_on_chronicle)
	row.add_child(chronicle)
	var close: Button = FarmUi.button("×", BUTTON_PX + 2)
	close.name = "Close"
	close.tooltip_text = "Close the village news (Esc or N)"
	close.pressed.connect(close_window)
	row.add_child(close)


func _build_filters(column: VBoxContainer) -> void:
	"""The place filter (All + GROUP_NAMES), the tier filter (All + TIER_NAMES, urgent first) as toggle buttons, and the
	snoozed line."""
	var places := HBoxContainer.new()
	places.add_theme_constant_override(&"separation", 4)
	column.add_child(places)
	places.add_child(_caption("Show:"))
	for group: int in range(-1, NoticesScript.GROUP_NAMES.size()):
		var words: String = "All" if group < 0 else NoticesScript.GROUP_NAMES[group]
		_group_buttons.append(_toggle(places, words, set_group_filter.bind(group)))
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override(&"separation", 4)
	column.add_child(levels)
	levels.add_child(_caption("Tier:"))
	for tier: int in [-1, NoticesScript.TIER_URGENT, NoticesScript.TIER_NORMAL, NoticesScript.TIER_INFO]:
		var words: String = "All" if tier < 0 else NoticesScript.TIER_NAMES[tier]
		_show_buttons.append(_toggle(levels, words, set_tier_filter.bind(tier)))
	_sync_filter_buttons()
	_build_snoozed(column)


func _build_snoozed(column: VBoxContainer) -> void:
	"""The snoozed kinds' line and its Wake all, hidden until a kind is snoozed."""
	_snoozed_row = HBoxContainer.new()
	_snoozed_row.add_theme_constant_override(&"separation", 6)
	_snoozed_row.visible = false
	column.add_child(_snoozed_row)
	_snoozed_label = FarmUi.label("", ROW_PX, Palette.UMBER)
	_snoozed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_snoozed_row.add_child(_snoozed_label)
	var wake: Button = FarmUi.button("Wake all", BUTTON_PX)
	wake.name = "WakeAll"
	wake.tooltip_text = "Let every snoozed kind of notice show and chime again"
	wake.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wake.pressed.connect(wake_all)
	_snoozed_row.add_child(wake)


func _caption(words: String) -> Label:
	"""A filter row's caption, on one line."""
	var caption: Label = FarmUi.label(words, BUTTON_PX, Palette.UMBER)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return caption


func _toggle(row: HBoxContainer, words: String, act: Callable) -> Button:
	"""One filter button (a toggle the filters set; pressing it calls `act`)."""
	var button: Button = FarmUi.button(words, BUTTON_PX)
	button.toggle_mode = true
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(act)
	row.add_child(button)
	return button


func _build_sections() -> void:
	"""The two section headings and their empty lines (rows are pooled between them as needed)."""
	_attention_title = FarmUi.label("", SECTION_PX, Palette.CLAY, true)
	_body.add_child(_attention_title)
	_attention_empty = FarmUi.label(NO_PROBLEMS, ROW_PX, Palette.UMBER)
	_body.add_child(_attention_empty)
	_history_title = FarmUi.label("", SECTION_PX, Palette.UMBER, true)
	_body.add_child(_history_title)
	_history_empty = FarmUi.label(NO_MATCHES, ROW_PX, Palette.UMBER)
	_body.add_child(_history_empty)
	_older = FarmUi.button("Show older", BUTTON_PX)
	_older.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_older.pressed.connect(show_older)
	_older.visible = false
	_body.add_child(_older)


# --- opening and closing ------------------------------------------------------------------------------

func open() -> void:
	"""Show the window, current."""
	build()
	_frame.visible = true
	_history_limit = PAGE
	_drawn_key = Vector3i(-1, -1, -1)
	refresh()
	_place.call_deferred()


func close_window() -> void:
	"""Hide the window."""
	if _frame != null:
		_frame.visible = false


func toggle() -> void:
	"""Open it, or close it."""
	if is_open():
		close_window()
	else:
		open()


func is_open() -> bool:
	"""Whether the window is shown."""
	return _frame != null and _frame.visible


func take_trigger(shell_opened: bool) -> bool:
	"""The HUD's history command (its trigger, N) as the demo routes it: the shell's history just OPENED --
	this window stands in for it in the top-centre zone, so it toggles and true says "close the shell's"; the
	shell's history just CLOSED (it had been opened from a settlement card) -- this window closes too."""
	if shell_opened:
		toggle()
		return true
	close_window()
	return false


func defer_keys_while(query: Callable) -> void:
	"""Leave N and Esc to the HUD while `query()` is true: the shell's own history is open (its N closes it,
	and the trigger routing then closes this window too -- one expansion in the zone), or a HUD workspace's
	scrim holds the input (it is the top of the dismissal ladder; the shell's N is withheld there too)."""
	_defer_to.append(query)


func _deferring() -> bool:
	"""Whether N is the HUD's now."""
	for query: Callable in _defer_to:
		if query.is_valid() and bool(query.call()):
			return true
	return false


func _on_settlement() -> void:
	"""Close, and open the shell's own history."""
	close_window()
	if _settlement.is_valid():
		_settlement.call()


func _on_chronicle() -> void:
	"""Close, and open the village chronicle (decision 0631)."""
	close_window()
	if _chronicle.is_valid():
		_chronicle.call()


func _input(event: InputEvent) -> void:
	"""Esc closes the open window before any world handler reads it (the top of UI §5's dismissal ladder),
	unless the HUD holds the keys (`defer_keys_while`). A demo modal over it (the input gate, read first)
	takes its own Esc before this sees it."""
	if is_open() and event.is_action_pressed(&"ui_cancel") and not event.is_echo() and not _deferring():
		close_window()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	"""N (`open_history`, the HUD's history shortcut) toggles this window -- read here, before the HUD's own
	handler (this node comes later in the tree), so the shell's history is not opened and shut again under
	it, which would leave the HUD's keyboard-focus description on its trigger."""
	if _notices != null and event.is_action_pressed(&"open_history") and not event.is_echo() and not _deferring():
		toggle()
		get_viewport().set_input_as_handled()


# --- filters ------------------------------------------------------------------------------------------

func set_group_filter(group: int) -> void:
	"""Press a place filter (-1: All). From All, a place shows that place alone; later places are added or
	taken off; the last one taken off shows All again."""
	if group < 0:
		_group_mask = NoticesScript.ALL_GROUPS
	elif _group_mask == NoticesScript.ALL_GROUPS:
		_group_mask = 1 << group
	else:
		_group_mask ^= 1 << group
		if _group_mask == 0:
			_group_mask = NoticesScript.ALL_GROUPS
	_filters_changed()


func set_severity_filter(wanted: int) -> void:
	"""Set the tier filter from a severity filter (SHOW_*: all; warnings -- urgent and normal; notes -- info)."""
	_tier_mask = NoticesScript.tier_mask_of(clampi(wanted, NoticesScript.SHOW_ALL, NoticesScript.SHOW_NOTES))
	_filters_changed()


func set_tier_filter(tier: int) -> void:
	"""Press a tier filter (-1: All), picked as the places are: from All a tier shows that tier alone, later ones are
	added or taken off, the last one taken off shows All again."""
	if tier < NoticesScript.TIER_INFO or tier > NoticesScript.TIER_URGENT:
		_tier_mask = NoticesScript.ALL_TIERS
	elif _tier_mask == NoticesScript.ALL_TIERS:
		_tier_mask = 1 << tier
	else:
		_tier_mask ^= 1 << tier
		if _tier_mask == 0:
			_tier_mask = NoticesScript.ALL_TIERS
	_filters_changed()


func tier_mask() -> int:
	"""The tier filter as a bit mask of TIER_* (checks)."""
	return _tier_mask


func group_mask() -> int:
	"""The place filter as a GROUP_* bit mask (checks)."""
	return _group_mask


func _filters_changed() -> void:
	"""Redraw at once with the buttons showing the filters."""
	_sync_filter_buttons()
	_history_limit = PAGE
	_drawn_key = Vector3i(-1, -1, -1)
	refresh()


func _sync_filter_buttons() -> void:
	"""Each filter button pressed exactly when its filter is on."""
	_group_buttons[0].set_pressed_no_signal(_group_mask == NoticesScript.ALL_GROUPS)
	for group: int in NoticesScript.GROUP_NAMES.size():
		_group_buttons[group + 1].set_pressed_no_signal(_group_mask != NoticesScript.ALL_GROUPS
			and _group_mask & (1 << group) != 0)
	_show_buttons[0].set_pressed_no_signal(_tier_mask == NoticesScript.ALL_TIERS)
	for slot: int in range(1, _show_buttons.size()):
		var tier: int = NoticesScript.TIER_URGENT + 1 - slot
		_show_buttons[slot].set_pressed_no_signal(_tier_mask != NoticesScript.ALL_TIERS and _tier_mask & (1 << tier) != 0)


# --- drawing ------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""Refresh a few times a second while open (real time: it reads while paused)."""
	if not is_open():
		return
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	refresh()


func refresh() -> bool:
	"""Rewrite both sections when the feed, the incidents or the filters changed. Returns whether it redrew."""
	if _notices == null or _incidents == null or _frame == null:
		return false
	var key := Vector3i(_notices.revision, _incidents.revision, _group_mask * 8 + _tier_mask)
	var hour: int = _snooze_hour()
	if key == _drawn_key and hour == _drawn_hour:
		return false
	_drawn_key = key
	_drawn_hour = hour
	_draw_attention()
	_draw_history()
	_draw_snoozed()
	return true


func _snooze_hour() -> int:
	"""The game hour now while any kind is snoozed (the snoozed line's hours left change with it), else -1. Integer
	division: whole hours, by intent."""
	if _notices.snoozes.count(_notices.now_tick()) == 0:
		return -1
	@warning_ignore("integer_division")
	return _notices.now_tick() / SimClock.TICKS_PER_HOUR


func _draw_snoozed() -> void:
	"""The snoozed kinds in words with their hours left, waking soonest first; hidden while none is."""
	var n: int = _notices.snoozes.kinds_into(_notices.now_tick(), _snoozed_kinds)
	_snoozed_row.visible = n > 0
	if n == 0:
		return
	_snoozed_words.clear()
	for kind: String in _snoozed_kinds:
		_snoozed_words.append("%s (%d h)" % [_notices.kind_title(StringName(kind)),
			_notices.snooze_hours_left(StringName(kind))])
	_snoozed_label.text = SNOOZED_WORDS % "; ".join(_snoozed_words)


func wake_all() -> int:
	"""Wake every snoozed kind (the snoozed line's button); returns how many were snoozed."""
	var woken: int = _notices.wake_all()
	refresh()
	return woken


func snoozed_text() -> String:
	"""The snoozed line's words ("" while hidden; checks)."""
	return _snoozed_label.text if _snoozed_row.visible else ""


func _draw_attention() -> void:
	"""The "Needs attention" rows: the open and pinned incidents in the place filter."""
	_incidents.attention_into(_attention_list)
	var shown: int = 0
	for serial: int in _attention_list:
		if _group_mask & (1 << NoticesScript.SOURCE_GROUP[_incidents.source_of(serial)]) == 0:
			continue
		_attention_row(shown, serial)
		shown += 1
	for rest: int in range(shown, _attention_rows.size()):
		_attention_rows[rest].visible = false
	_attention_title.text = "Needs attention (%d)" % shown
	_attention_empty.visible = shown == 0


func _attention_row(slot: int, serial: int) -> void:
	"""Write incident `serial` into pooled attention row `slot` (built when first needed)."""
	while _attention_rows.size() <= slot:
		_attention_rows.append(_new_attention_row(_attention_rows.size()))
		_attention_serial.append(IncidentsScript.NO_SERIAL)
	_attention_serial[slot] = serial
	var row: VBoxContainer = _attention_rows[slot]
	var title := row.get_child(0) as Label
	title.text = "%s · %s" % [_incidents.card_title(serial), _incidents.stamp_of(serial)]
	var critical: bool = _incidents.severity_of(serial) == IncidentsScript.SEVERITY_CRITICAL
	title.add_theme_color_override(&"font_color", Palette.CLAY if critical else Palette.UMBER)
	(row.get_child(1) as Label).text = _incidents.text_of(serial)
	var verbs := row.get_child(2) as HBoxContainer
	(verbs.get_child(0) as Button).visible = _can_jump(_incidents.target_kind_of(serial), _incidents.target_id_of(serial))
	(verbs.get_child(1) as Button).text = "Unpin" if _incidents.is_pinned(serial) else "Pin"
	(verbs.get_child(2) as Button).visible = _incidents.can_queue(serial)
	row.visible = true


func _new_attention_row(slot: int) -> VBoxContainer:
	"""A pooled attention row: title, text, and Go to / Pin / Snooze / Dismiss, placed before the history."""
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	row.add_child(FarmUi.label("", ROW_PX, Palette.UMBER, true))
	row.add_child(FarmUi.label("", ROW_PX, Palette.INK))
	var verbs := HBoxContainer.new()
	verbs.add_theme_constant_override(&"separation", 4)
	row.add_child(verbs)
	for words: String in ["Go to", "Pin", "Snooze 2 min", "Dismiss"]:
		var button: Button = FarmUi.button(words, BUTTON_PX)
		button.pressed.connect(_on_attention_verb.bind(slot, words))
		verbs.add_child(button)
	_body.add_child(row)
	_body.move_child(row, _attention_empty.get_index())
	return row


func _on_attention_verb(slot: int, verb: String) -> void:
	"""An attention row's button: Go to, Pin / Unpin, Snooze or Dismiss its incident."""
	var serial: int = _attention_serial[slot]
	match verb:
		"Go to":
			go_to(_incidents.target_kind_of(serial), _incidents.target_id_of(serial))
		"Pin":
			_incidents.pin(serial, not _incidents.is_pinned(serial))
		"Snooze 2 min":
			_incidents.snooze(serial)
		"Dismiss":
			_incidents.acknowledge(serial)
	refresh()


func _draw_history() -> void:
	"""The history rows: the kept entries passing the filters, newest first, the first `_history_limit` of them."""
	var total: int = _notices.tiers_into(_group_mask, _tier_mask, _history_list)
	var drawn: int = mini(total, _history_limit)
	for slot: int in drawn:
		_history_row(slot, _history_list[slot])
	for rest: int in range(drawn, _history_rows.size()):
		_history_rows[rest].visible = false
	_history_title.text = "History — %d of %d notices" % [total, _notices.count()]
	_history_empty.visible = total == 0
	_older.visible = total > drawn
	_older.text = "Show older (%d more)" % (total - drawn)


func _history_row(slot: int, k: int) -> void:
	"""Write feed entry `k` into pooled history row `slot` (built when first needed), touching only what changed;
	the row keeps the entry's target, so a Go to after newer posts still goes where the row says."""
	while _history_rows.size() <= slot:
		_history_rows.append(_new_history_row(_history_rows.size()))
		_history_target.append_array([NoticesScript.TARGET_NONE, -1])
		_history_level.append(UNDRAWN)
		_history_id.append(0)
	var row: HBoxContainer = _history_rows[slot]
	var line := row.get_child(0) as Label
	var words: String = entry_text(k)
	if line.text != words:
		line.text = words
	if _history_level[slot] != _notices.tier(k):
		_history_level[slot] = _notices.tier(k)
		StripScript.paint_tier(line, _notices.tier(k), ROW_PX, URGENT_PX)
	_history_target[2 * slot] = _notices.target_kind(k)
	_history_target[2 * slot + 1] = _notices.target_id(k)
	_history_id[slot] = _notices.entry_id(k)
	(row.get_child(1) as Button).visible = _can_jump(_notices.target_kind(k), _notices.target_id(k))
	_history_verbs(row, k)
	row.visible = true


func _history_verbs(row: HBoxContainer, k: int) -> void:
	"""A history row's Snooze (Wake while its kind sleeps; none on an urgent entry) and Dismiss (none once dismissed)."""
	var snooze := row.get_child(2) as Button
	snooze.visible = _notices.tier(k) != NoticesScript.TIER_URGENT
	var words: String = WAKE if _notices.is_kind_snoozed(_notices.kind(k)) else SNOOZE % NoticesScript.SNOOZE_HOURS
	if snooze.text != words:
		snooze.text = words
	(row.get_child(3) as Button).visible = not _notices.is_dismissed(k)


func _new_history_row(slot: int) -> HBoxContainer:
	"""A pooled history row: its line and its Go to, at the end of the body."""
	var row := HBoxContainer.new()
	var line: Label = FarmUi.label("", ROW_PX, Palette.INK)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	var go: Button = FarmUi.button("Go to", BUTTON_PX)
	go.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(_on_history_go.bind(slot))
	row.add_child(go)
	var snooze: Button = FarmUi.button(SNOOZE % NoticesScript.SNOOZE_HOURS, BUTTON_PX)
	snooze.tooltip_text = "Quiet this kind of notice for %d game hours: kept here, not shown or chimed" \
		% NoticesScript.SNOOZE_HOURS
	snooze.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	snooze.pressed.connect(snooze_row.bind(slot))
	row.add_child(snooze)
	var dismiss: Button = FarmUi.button(DISMISS, BUTTON_PX)
	dismiss.tooltip_text = "Take this notice off the news strip (it stays here)"
	dismiss.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dismiss.pressed.connect(dismiss_row.bind(slot))
	row.add_child(dismiss)
	_body.add_child(row)
	_body.move_child(_older, -1)
	return row


func _on_history_go(slot: int) -> void:
	"""A history row's Go to: the target the row was drawn with."""
	go_to(_history_target[2 * slot], _history_target[2 * slot + 1])


func snooze_row(slot: int) -> bool:
	"""History row `slot`'s Snooze: quiet its entry's kind for SNOOZE_HOURS game hours -- or, while it is quiet,
	wake it. False when its entry is gone or urgent."""
	var k: int = _notices.index_of(_history_id[slot])
	if k < 0:
		return false
	var done: bool = _notices.wake_kind(_notices.kind(k)) if _notices.is_kind_snoozed(_notices.kind(k)) \
		else _notices.snooze_entry(k)
	refresh()
	return done


func dismiss_row(slot: int) -> bool:
	"""History row `slot`'s Dismiss: its entry off the strip, kept here."""
	var done: bool = _notices.dismiss_id(_history_id[slot])
	refresh()
	return done


func show_older() -> void:
	"""Draw PAGE more history rows."""
	_history_limit += PAGE
	_drawn_key = Vector3i(-1, -1, -1)
	refresh()


func entry_text(k: int) -> String:
	"""Feed entry `k` as a history line: '<date> · <place> · Warning: <text> (×2)', and STILL_OPEN while the
	incident it reports is unresolved."""
	var still: String = STILL_OPEN if _incidents.is_unresolved(_notices.incident(k)) else ""
	still += DISMISSED if _notices.is_dismissed(k) else ""
	var place: String = NoticesScript.GROUP_NAMES[_notices.group(k)]
	var line: String = _notices.line(k)
	var cut: int = line.find(" · ")
	return "%s · %s%s%s" % [line.substr(0, cut), place, line.substr(cut), still]


func _can_jump(kind: int, id: int) -> bool:
	"""Whether a Go to would find this target."""
	return _jump != null and _jump.can_jump(kind, id)


func go_to(kind: int, id: int) -> bool:
	"""Select and centre a target, closing the window so it is not under it. False when it cannot be found."""
	if not _can_jump(kind, id):
		return false
	close_window()
	return _jump.jump(kind, id)


# --- reading (checks) ---------------------------------------------------------------------------------

func attention_count() -> int:
	"""How many attention rows are shown."""
	var n: int = 0
	for row: VBoxContainer in _attention_rows:
		n += 1 if row.visible else 0
	return n


func attention_serial(slot: int) -> int:
	"""The incident attention row `slot` shows."""
	return _attention_serial[slot]


func attention_can_snooze(slot: int) -> bool:
	"""Whether attention row `slot` offers Snooze."""
	return ((_attention_rows[slot].get_child(2) as HBoxContainer).get_child(2) as Button).visible


func history_count() -> int:
	"""How many history entries pass the filters (at most `_history_limit` of them drawn)."""
	return _history_list.size()


func drawn_count() -> int:
	"""How many history rows are drawn."""
	var n: int = 0
	for row: HBoxContainer in _history_rows:
		n += 1 if row.visible else 0
	return n


func history_text(slot: int) -> String:
	"""History row `slot`'s line."""
	return (_history_rows[slot].get_child(0) as Label).text


func history_can_go(slot: int) -> bool:
	"""Whether history row `slot` offers Go to."""
	return (_history_rows[slot].get_child(1) as Button).visible


func history_verb(slot: int, verb: int) -> Button:
	"""History row `slot`'s button `verb`: 1 Go to, 2 Snooze, 3 Dismiss (checks)."""
	return _history_rows[slot].get_child(verb) as Button


func history_tier(slot: int) -> int:
	"""The tier history row `slot` is drawn at (checks)."""
	return _history_level[slot]


func press_history_go(slot: int) -> void:
	"""Press history row `slot`'s Go to, as a click does."""
	(_history_rows[slot].get_child(1) as Button).pressed.emit()


# --- placing ------------------------------------------------------------------------------------------

func _place() -> void:
	"""Top centre under the alert zone, as wide as MAX_W allows, down to just above the command strip."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var width: float = minf(MAX_W, _geometry.logical_width - 2.0 * GAP)
	var x: float = clampf(_geometry.alerts.get_center().x - width / 2.0, GAP, _geometry.logical_width - GAP - width)
	var top: float = _geometry.alerts.end.y + GAP
	var height: float = minf(MAX_H, _geometry.commands.position.y - GAP - top)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = Vector2(x, top) * _geometry.scale
	_frame.custom_minimum_size = Vector2(width, height)
	_frame.size = Vector2(width, height)


func frame_rect() -> Rect2:
	"""Where the window is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
