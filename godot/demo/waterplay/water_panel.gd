extends CanvasLayer
## The "Water (demo)" panel: the right column's fourth tab. Decision 0196 (live demo). DEMO UI -- not a
## game panel, and titled so. Its buttons order the demo cast, never the simulation.
##
## PLACEMENT is the woods panel's (demo/forestry/forest_panel.gd): the HUD's detail zone below the tab
## strip, shown or hidden by demo/ui/demo_detail_zone.gd (`set_zone`), yielding to the resident journal
## (UI-SET-036), at the HUD's scale (the interface scale included), scrolling when the zone is short.
##
## WHAT IT SHOWS, in the order a player needs it (decision 0391, review F12):
##   PINNED above the scroll, always in view: the title; every resident in difficulty -- the rescue incident's
##   own line (waterplay_text.gd `alert_line`, decision 0331), in clay; and the SELECTED residents' swimming
##   (what each can do, what the water is doing to it, breath and stamina), the first two of them and a button
##   for the rest that opens the full list.
##   SWIMMERS: how many are in the water; the water today (flow, cold, flood); Dive and Swim shortcuts; and
##   "All residents", FOLDED by default -- a row per resident that selects it and centres the camera on it
##   (`resident_picked`). Healthy residents on land never stand between the player and an action.
##   BRIDGES: the site chosen, its span, each kind's cost and, directly under the two, their Build buttons (each
##   one's tooltip is its ACTION CARD, decision 0332, `set_card`) -- shown only for a kind that can be built now
##   (decision 0461: "Build appears only when it can commit"); then the PROJECT lines (what is missing and the source
##   button that leads to the saw or haul that supplies it; a planned bridge's materials delivered or reserved; an open
##   one's route and condition) and the BENEFIT estimate (demo/routes/, `show_routes`); then ◀ / ▶ / Span two banks…
##   to choose another site, every bridge planned or open, the village stores and the water's latest news.
## Buttons emit `action(name)` (ACTION_*); nothing here decides anything. Text is at least 14 px (UI §2.1)
## and every button at least 32 px tall (UX-T03); a caption cut by the column ends in an ellipsis and is whole
## in its tooltip.

const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const PickRow := preload("res://demo/ui/demo_pick_row.gd")
const TextScript := preload("res://demo/waterplay/waterplay_text.gd")

signal action(name: StringName)
## A resident's row in "All residents" was pressed: select it alone and centre on it (demo_command.gd `pick_member`).
signal resident_picked(who: int)

const TITLE: String = "Water (demo)"
const ACTION_PREV_SITE: StringName = &"prev_site"
const ACTION_NEXT_SITE: StringName = &"next_site"
const ACTION_SPAN_TOOL: StringName = &"span_tool"
const ACTION_BUILD_PLANK: StringName = &"build_plank"
const ACTION_BUILD_LOG: StringName = &"build_log"
const ACTION_DIVE: StringName = &"dive"
const ACTION_CONSENT: StringName = &"consent"
const ACTION_CRAMP: StringName = &"cramp"
## The project's source button (decision 0461): its caption is set with the link (`set_source`).
const ACTION_SOURCE: StringName = &"source"
const BUTTON_TEXT: Dictionary = {
	&"prev_site": "◀ Site", &"next_site": "Site ▶", &"span_tool": "Span two banks…",
	&"build_plank": "Build footbridge", &"build_log": "Build log bridge", &"source": "Source ▸",
	&"dive": "Dive in the pond", &"consent": "Swim shortcuts: on",
}
## What a button does, where its action card does not say it (decision 0391: every action has a hover text).
const BUTTON_TIPS: Dictionary = {
	&"prev_site": "The previous bridge site on the stream", &"next_site": "The next bridge site on the stream",
	&"span_tool": "Choose a site yourself: click one bank, then the other (Esc drops it)",
	&"consent": "Swim shortcuts: whether the selected residents (everyone, with nobody selected) may swim across instead of walking round",
}
const SITE_ACTIONS: Array[StringName] = [&"prev_site", &"next_site", &"span_tool", &"build_plank", &"build_log"]
## The two Build buttons, side by side under their kinds' costs.
const BUILD_ACTIONS: Array[StringName] = [&"build_plank", &"build_log"]
## The site's way-finding buttons, in one row.
const NAV_ACTIONS: Array[StringName] = [&"prev_site", &"next_site", &"span_tool"]
## ACTION_CRAMP is a test trigger: its button is the Demo Lab's (demo/ui/demo_lab.gd, decision 0261).
const SWIM_ACTIONS: Array[StringName] = [&"dive", &"consent"]
const LINE_KEYS: Array[StringName] = [&"conditions", &"alert", &"swimmers_title", &"swimmers"]
const DETAIL_NAME: String = "UI-SET-036"
const FRAME_EXPAND: float = 10.0
const TITLE_PX: int = 19
const HEADING_PX: int = 16
const BODY_PX: int = 15
## UI §2.1's minimum rendered text (12 px before decision 0391).
const SMALL_PX: int = 14
const BUTTON_H: float = 32.0
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 10.0, 14.0, 12.0]
const BUTTON_MARGINS: PackedFloat32Array = [8.0, 5.0, 8.0, 6.0]
const SEPARATION: int = 5
## A wrapped line's least width leaves this much for the scroll bar.
const SCROLLBAR_ALLOWANCE: float = 16.0
## How many selected residents are pinned before "n more selected" (which opens All residents).
const PINNED_MAX: int = 2
const ROSTER_SHOW: String = "All residents (%d) ▸"
const ROSTER_HIDE: String = "All residents (%d) ▾"
const ROSTER_TIP: String = "Every resident's swimming, breath and stamina: click one to select it and centre on it"
const MORE_SELECTED: String = "%d more selected — show all residents"
## The sections never get less than this (Dive and Swim shortcuts, or the Builds, in view): where the pinned part
## would leave less, the selected residents' lines fold away into All residents (decision 0391).
const MIN_BODY_H: float = 2.0 * BUTTON_H + 3.0 * SEPARATION
## The residents in difficulty are pinned up to this many lines; the whole text is in its tooltip (and on the
## rescue's incident card, decision 0331).
const ALERT_MAX_LINES: int = 4

var _frame: PanelContainer = null
var _outer: VBoxContainer = null
var _pinned: VBoxContainer = null
var _picked: VBoxContainer = null
var _more: Button = null
var _body: DemoScroll = null
var _column: VBoxContainer = null
var _lines: Dictionary = {}
## Each line as it was given (`line`), whatever part of it a label shows.
var _texts: Dictionary = {}
var _buttons: Dictionary = {}
var _roster_toggle: Button = null
var _roster: VBoxContainer = null
var _roster_open: bool = false
var _swimmer_lines: PackedStringArray = PackedStringArray()
var _selected: PackedInt32Array = PackedInt32Array()
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _hud_root: Control = null
var _detail: Control = null
var _detail_open: bool = false
var _width: float = 316.0
var _zone_shown: bool = false
var _zone_inset: float = 0.0
var _place_queued: bool = false
## Whether the pinned selection was folded away to leave the sections MIN_BODY_H (see _place).
var _picked_folded: bool = false
## How many selected residents' lines are pinned, and whether "n more selected" is wanted (_fill_picked).
var _picked_shown: int = 0
var _more_wanted: bool = false


func _ready() -> void:
	"""Build, place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""Build the widgets (also out of the tree, for checks): the pinned top, then the scrolling sections."""
	if _frame != null:
		return
	layer = 0
	name = "WaterPanel"
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, CONTENT_MARGINS))
	_frame.theme = CardScript.tooltip_theme()
	add_child(_frame)
	_outer = VBoxContainer.new()
	_outer.add_theme_constant_override(&"separation", SEPARATION)
	_frame.add_child(_outer)
	_build_pinned()
	_body = DemoScroll.new()
	_body.name = "Sections"
	_outer.add_child(_body)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override(&"separation", SEPARATION)
	_body.add_child(_column)
	_build_swimmers()
	_build_bridges()
	_pinned.minimum_size_changed.connect(_queue_place)
	_column.minimum_size_changed.connect(_queue_place)


func _build_pinned() -> void:
	"""The title, the residents in difficulty and the selected residents: never scrolled away."""
	_pinned = VBoxContainer.new()
	_pinned.name = "Pinned"
	_pinned.add_theme_constant_override(&"separation", SEPARATION)
	_outer.add_child(_pinned)
	_pinned.add_child(_label(TITLE, TITLE_PX, Palette.INK, Styles.heading_font()))
	_add_line(_pinned, &"alert", BODY_PX, Palette.CLAY, null)
	var alert := _lines[&"alert"] as Label
	alert.max_lines_visible = ALERT_MAX_LINES
	alert.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	alert.mouse_filter = Control.MOUSE_FILTER_PASS
	_picked = VBoxContainer.new()
	_picked.add_theme_constant_override(&"separation", 2)
	_pinned.add_child(_picked)
	_more = _wood_button(MORE_SELECTED % 0, func() -> void: set_roster_open(true))
	_more.visible = false
	_pinned.add_child(_more)


func _build_swimmers() -> void:
	"""Swimmers: the count in the water, the water today, the swim verbs, and All residents (folded)."""
	_add_line(_column, &"swimmers_title", HEADING_PX, Palette.INK, Styles.heading_font())
	_add_line(_column, &"conditions", SMALL_PX, Palette.INK, null)
	_column.add_child(_row(SWIM_ACTIONS))
	_roster_toggle = _wood_button(ROSTER_SHOW % 0, toggle_roster)
	_roster_toggle.tooltip_text = ROSTER_TIP
	_column.add_child(_roster_toggle)
	_roster = VBoxContainer.new()
	_roster.name = "AllResidents"
	_roster.add_theme_constant_override(&"separation", 1)
	_roster.visible = false
	_column.add_child(_roster)
	_texts[&"swimmers"] = ""


func _build_bridges() -> void:
	"""Bridges: the site, each kind's cost over the Build buttons, the way to another site, then the bridges, stores
	and news."""
	_add_line(_column, &"site_title", HEADING_PX, Palette.INK, Styles.heading_font())
	_add_line(_column, &"site", SMALL_PX, Palette.UMBER, null)
	_add_line(_column, &"plank_cost", SMALL_PX, Palette.INK, null)
	_add_line(_column, &"log_cost", SMALL_PX, Palette.INK, null)
	_column.add_child(_row(BUILD_ACTIONS))
	_add_line(_column, &"project", SMALL_PX, Palette.INK, null)
	var source := _row([ACTION_SOURCE] as Array[StringName])
	source.visible = false
	_column.add_child(source)
	_add_line(_column, &"routes", SMALL_PX, Palette.UMBER, null)
	_column.add_child(_row(NAV_ACTIONS))
	_add_line(_column, &"bridges", SMALL_PX, Palette.UMBER, null)
	_add_line(_column, &"stores", SMALL_PX, Palette.INK, null)
	_add_line(_column, &"log", SMALL_PX, Palette.UMBER, null)


func _queue_place() -> void:
	"""Place the frame again at the end of this frame, once (a content change re-measures its parts)."""
	if not _place_queued:
		_place_queued = true
		_place.call_deferred()


func _add_line(parent: Container, key: StringName, px: int, colour: Color, font: Font) -> void:
	"""A wrapped line of text kept under `key`."""
	_lines[key] = _label("", px, colour, font)
	_texts[key] = ""
	parent.add_child(_lines[key])


func _row(keys: Array[StringName]) -> HFlowContainer:
	"""Wood buttons side by side sharing the column's width, a button that does not fit going to the next line
	(whole: a row's captions are never cut)."""
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 6)
	row.add_theme_constant_override(&"v_separation", 6)
	for key: StringName in keys:
		var made: Button = _action_button(key)
		made.clip_text = false
		made.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.add_child(made)
	return row


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One wrapped label in the panel's type."""
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = _width - CONTENT_MARGINS[0] - CONTENT_MARGINS[2] - SCROLLBAR_ALLOWANCE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _action_button(key: StringName) -> Button:
	"""A wood button that emits `action(key)`, with its hover text."""
	var button := _wood_button(BUTTON_TEXT[key], func() -> void: action.emit(key))
	button.tooltip_text = BUTTON_TIPS.get(key, BUTTON_TEXT[key])
	_buttons[key] = button
	return button


func _wood_button(text: String, pressed: Callable) -> Button:
	"""A wood button at least BUTTON_H tall, its caption cut with an ellipsis where the column is too narrow;
	takes keyboard focus (decision 0261)."""
	var button := Button.new()
	button.text = text
	Styles.focusable(button, BUTTON_MARGINS)
	button.custom_minimum_size.y = BUTTON_H
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override(&"font_size", SMALL_PX)
	button.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"disabled", Styles.box(Styles.PIECE_WOOD_DISABLED, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		button.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	button.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	button.add_theme_color_override(&"font_disabled_color", Palette.text_on(Palette.SURFACE_WOOD_DISABLED))
	button.pressed.connect(pressed)
	return button


func button(key: StringName) -> Button:
	"""The button for an action (checks and scripted runs)."""
	return _buttons[key]


func line(key: StringName) -> String:
	"""A line's text as given: conditions, alert, swimmers_title, swimmers, site_title, site, project, routes, bridges,
	stores or log."""
	return String(_texts.get(key, ""))


# --- what it shows ------------------------------------------------------------------------------------

func show_water(conditions: String, alert: String, swimmers_title: String, swimmers: String) -> void:
	"""The water today, any rescue, the swimmers' heading, and every resident's swimming (a line each, in cast
	order: the pinned selection and All residents read them)."""
	_set_line(&"conditions", conditions)
	_set_line(&"alert", alert)
	(_lines[&"alert"] as Label).visible = not alert.is_empty()
	(_lines[&"alert"] as Label).tooltip_text = alert
	_set_line(&"swimmers_title", swimmers_title)
	if _texts[&"swimmers"] != swimmers:
		_texts[&"swimmers"] = swimmers
		_swimmer_lines = swimmers.split("\n", false)
		_fill_roster()
		_fill_picked()


func set_selected(members: PackedInt32Array) -> void:
	"""The selected residents (cast indices): their lines are pinned (PINNED_MAX, then a button for the rest)."""
	if members == _selected:
		return
	_selected = members.duplicate()
	_fill_picked()


func _fill_picked() -> void:
	"""The pinned selection: each of the first PINNED_MAX selected residents' lines, and "n more selected"."""
	var shown: int = 0
	for who: int in _selected:
		if who >= 0 and who < _swimmer_lines.size() and shown < PINNED_MAX:
			_line_at(_picked, shown, _swimmer_lines[who])
			shown += 1
	for k: int in _picked.get_child_count():
		(_picked.get_child(k) as Control).visible = k < shown
	var rest: int = _selected.size() - shown
	_picked_shown = shown
	_more_wanted = rest > 0
	_more.text = MORE_SELECTED % rest
	_set_folded(_picked_folded)


func _line_at(parent: VBoxContainer, k: int, text: String) -> void:
	"""Line `k` of `parent` reads `text` (made when missing)."""
	while parent.get_child_count() <= k:
		parent.add_child(_label("", SMALL_PX, Palette.INK, null))
	var label := parent.get_child(k) as Label
	if label.text != text:
		label.text = text


func _fill_roster() -> void:
	"""All residents: a row per resident (made once, re-worded in place so a hovered tooltip stays)."""
	for who: int in _swimmer_lines.size():
		if who >= _roster.get_child_count():
			var row: Button = PickRow.make(_swimmer_lines[who], Color(0, 0, 0, 0), SMALL_PX, Palette.INK)
			row.pressed.connect(resident_picked.emit.bind(who))
			_roster.add_child(row)
		PickRow.set_text(_roster.get_child(who) as Button, _swimmer_lines[who])
	for k: int in _roster.get_child_count():
		(_roster.get_child(k) as Control).visible = k < _swimmer_lines.size()
	_paint_roster_toggle()


func toggle_roster() -> void:
	"""Fold or unfold All residents."""
	set_roster_open(not _roster_open)


func set_roster_open(open: bool) -> void:
	"""Show All residents (`open`) or fold it; opened from the pinned "n more", it is scrolled into view."""
	_roster_open = open
	_roster.visible = open
	_paint_roster_toggle()
	if open and is_inside_tree():
		_reveal_roster.call_deferred()


func _reveal_roster() -> void:
	"""Scroll the least distance that shows the All residents toggle (demo_scroll.gd `reveal`)."""
	if _roster_toggle != null and _roster_toggle.is_inside_tree():
		_body.reveal(_roster_toggle)


func _paint_roster_toggle() -> void:
	"""The toggle's words: how many residents, and folded or open."""
	_roster_toggle.text = (ROSTER_HIDE if _roster_open else ROSTER_SHOW) % _swimmer_lines.size()


func roster_open() -> bool:
	"""Whether All residents is unfolded."""
	return _roster_open


func roster_toggle() -> Button:
	"""The All residents toggle (checks)."""
	return _roster_toggle


func roster_row(who: int) -> Button:
	"""Resident `who`'s All residents row (null before the swimmers are shown)."""
	return _roster.get_child(who) as Button if who >= 0 and who < _roster.get_child_count() else null


func picked_texts() -> PackedStringArray:
	"""The pinned selection's lines as pinned (folded away or not; checks)."""
	var out := PackedStringArray()
	for k: int in _picked_shown:
		out.append((_picked.get_child(k) as Label).text)
	return out


func more_button() -> Button:
	"""The pinned "n more selected" button (checks)."""
	return _more


func show_site(title: String, text: String, enabled: Dictionary) -> void:
	"""The bridge site chosen, and which of the site buttons can be pressed ({action: bool}). `text`'s cost lines
	(waterplay_text.gd PLANK_LINE, LOG_LINE) go each on its own line over the Build buttons; the rest stays
	together above them."""
	_set_line(&"site_title", title)
	_texts[&"site"] = text
	var site := PackedStringArray()
	var plank: String = ""
	var log: String = ""
	for part: String in text.split("\n", false):
		if part.begins_with(TextScript.PLANK_LINE):
			plank = part
		elif part.begins_with(TextScript.LOG_LINE):
			log = part
		else:
			site.append(part)
	_show_label(&"site", "\n".join(site))
	_show_label(&"plank_cost", plank)
	_show_label(&"log_cost", log)
	for key: StringName in SITE_ACTIONS:
		(_buttons[key] as Button).disabled = not bool(enabled.get(key, true))
	for key: StringName in BUILD_ACTIONS:
		(_buttons[key] as Button).visible = bool(enabled.get(key, true))


func _show_label(key: StringName, text: String) -> void:
	"""A shown part of a line: its label reads `text`, hidden when empty."""
	var label := _lines[key] as Label
	if label.text != text:
		label.text = text
	label.visible = not text.is_empty()


func set_card(key: StringName, card_text: String, enabled: bool) -> void:
	"""An action's card (decision 0332, demo/ui/action_card.gd) as its button's tooltip, the button pressable only
	when the card allows it."""
	var b := _buttons[key] as Button
	CardScript.dress(b)
	if b.tooltip_text != card_text:
		b.tooltip_text = card_text
	b.disabled = not enabled


func show_routes(project: String, benefit: String) -> void:
	"""The site's project lines (missing material, a planned bridge's materials, an open one's route and condition) and
	its benefit estimate (decision 0461), each hidden when empty."""
	_texts[&"project"] = project
	_texts[&"routes"] = benefit
	_show_label(&"project", project)
	_show_label(&"routes", benefit)


func set_source(caption: String, tip: String, shown: bool) -> void:
	"""The project's source button: the saw or haul that supplies what is missing, or the bridge's own task."""
	var b := _buttons[ACTION_SOURCE] as Button
	b.get_parent().visible = shown
	if b.text != caption:
		b.text = caption
	b.tooltip_text = tip


func show_status(bridges: String, stores: String, log: String) -> void:
	"""The bridges planned and open, the stores and the water's news."""
	_set_line(&"bridges", bridges)
	_set_line(&"stores", stores)
	_set_line(&"log", log)


func set_swim_buttons(consent_on: bool, enabled: Dictionary) -> void:
	"""The swim verbs: consent's state on its button, and which can be pressed."""
	(_buttons[ACTION_CONSENT] as Button).text = "Swim shortcuts: %s" % ("on" if consent_on else "off")
	for key: StringName in SWIM_ACTIONS:
		(_buttons[key] as Button).disabled = not bool(enabled.get(key, true))


func set_tool_armed(on: bool) -> void:
	"""Show the span tool armed (its button says how to finish)."""
	(_buttons[ACTION_SPAN_TOOL] as Button).text = "Other bank… (Esc)" if on else BUTTON_TEXT[ACTION_SPAN_TOOL]


func _set_line(key: StringName, text: String) -> void:
	"""Set a line when its text changed (its label re-measures, and the frame is placed again)."""
	_texts[key] = text
	var label := _lines[key] as Label
	if label.text != text:
		label.text = text


# --- placement ----------------------------------------------------------------------------------------

func watch_hud(hud_root: Control) -> void:
	"""Yield to the HUD's resident journal (found by its UI id under `hud_root`)."""
	_hud_root = hud_root


func follow_hud() -> void:
	"""Hide while the journal is open; show again once it closes. Cheap; call a few times a second."""
	if _detail == null and _hud_root != null and is_instance_valid(_hud_root):
		_detail = _hud_root.find_child(DETAIL_NAME, true, false) as Control
	var open := _detail != null and is_instance_valid(_detail) and _detail.is_visible_in_tree()
	if open != _detail_open:
		_detail_open = open
		_place()


func set_zone(shown: bool, top_inset: float) -> void:
	"""The detail zone's owner (demo_detail_zone.gd): show this panel or not, `top_inset` logical pixels
	below the zone's top -- and fit it again once its content has laid out."""
	_zone_shown = shown
	_zone_inset = top_inset
	_place()
	_queue_place()


func _place() -> void:
	"""Lay the frame out in the detail zone at the HUD's scale: the pinned part as tall as it is, the sections
	scrolling in the rest (the woods panel's rule)."""
	_place_queued = false
	if _frame == null:
		return
	if not is_inside_tree():
		_frame.visible = _zone_shown and not _detail_open
		return
	var size_px := get_viewport().get_visible_rect().size
	var rect := DetailZone.panel_placement(int(size_px.x), int(size_px.y), FRAME_EXPAND, _zone_inset, _layout, _geometry)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = rect.position * _geometry.scale
	_frame.custom_minimum_size = Vector2(rect.size.x, 0.0)
	var avail: float = rect.size.y - CONTENT_MARGINS[1] - CONTENT_MARGINS[3] - float(SEPARATION)
	var bare: float = _pinned_bare_height()
	var picked: float = _picked_height()
	_set_folded(avail - bare - picked < MIN_BODY_H)
	var room: float = avail - bare - (0.0 if _picked_folded else picked)
	_body.custom_minimum_size.y = clampf(_column.get_combined_minimum_size().y, 0.0, maxf(room, MIN_BODY_H))
	_frame.size = Vector2(rect.size.x, 0.0)
	_frame.visible = _zone_shown and not _detail_open


func _pinned_bare_height() -> float:
	"""The pinned part without the selection: the title and the residents in difficulty (capped, ALERT_MAX_LINES)."""
	var total: float = 0.0
	var shown: int = 0
	for child: Node in _pinned.get_children():
		var control := child as Control
		if control == _picked or control == _more or not control.visible:
			continue
		total += control.get_combined_minimum_size().y
		shown += 1
	return total + float(SEPARATION * maxi(shown - 1, 0))


func _picked_height() -> float:
	"""What the pinned selection adds when shown: its lines and, with more selected, its button -- each with the
	separation before it."""
	var total: float = 0.0
	if _picked_shown > 0:
		total += _picked.get_combined_minimum_size().y + float(SEPARATION)
	if _more_wanted:
		total += _more.get_combined_minimum_size().y + float(SEPARATION)
	return total


func _set_folded(folded: bool) -> void:
	"""Fold the pinned selection away (its residents stay in All residents) or show it."""
	_picked_folded = folded
	_picked.visible = not folded and _picked_shown > 0
	_more.visible = not folded and _more_wanted


func picked_folded() -> bool:
	"""Whether the pinned selection is folded away to leave the sections their room (checks)."""
	return _picked_folded


func sections() -> ScrollContainer:
	"""The scrolling sections (checks)."""
	return _body


func is_shown() -> bool:
	"""Whether the frame is drawn."""
	return _frame != null and _frame.visible


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
