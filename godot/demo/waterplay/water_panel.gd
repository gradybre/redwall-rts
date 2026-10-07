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
##   FISHING (water part B, decision 0431): the trip being chosen -- its site, method and fish, each stepped with a
##   button -- with REQ-SET-055's figures before it is authorised (stock, quota, expected catch, gear condition,
##   closure dates, the numerical risk), Authorise trip (its card the order's own decision), the trips out (one
##   chosen, Cancel trip), and the gear locker: each piece's wear, Make net / trap / ice kit and Mend gear.
##   BOATS: each boat, where it is and its wear, the jetty, and the pond's ice.
##   DRYING RACK AND MILL: the rack's four slots, the mill, the pantry's fish, dried fish and flour; Dry fish and
##   Mill grain.
##
## Buttons emit `action(name)` (ACTION_*); nothing here decides anything. Text is at least 14 px (UI §2.1)
## and every button at least 32 px tall (UX-T03); a caption cut by the column ends in an ellipsis and is whole
## in its tooltip.

const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
## How many frames `scroll_to_line` keeps its line at the top while a panel just brought forward grows.
const SCROLL_SETTLE_FRAMES: int = 10
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
## Water part B's verbs (decision 0431): the trip's choice, Authorise, the trips, the gear, the rack and the mill.
const ACTION_FISH_SITE: StringName = &"fish_site"
const ACTION_FISH_METHOD: StringName = &"fish_method"
const ACTION_FISH_SPECIES: StringName = &"fish_species"
const ACTION_AUTHORISE: StringName = &"fish_authorise"
const ACTION_NEXT_TRIP: StringName = &"fish_next_trip"
const ACTION_CANCEL_TRIP: StringName = &"fish_cancel"
const ACTION_MAKE_NET: StringName = &"make_net"
const ACTION_MAKE_TRAP: StringName = &"make_trap"
const ACTION_MAKE_ICE_KIT: StringName = &"make_ice_kit"
const ACTION_MEND: StringName = &"mend"
const ACTION_DRY: StringName = &"dry_fish"
const ACTION_MILL: StringName = &"mill_grain"
## The preserves (decision 1611): fruit onto the rack, rations packed at the preserving table.
const ACTION_DRY_FRUIT: StringName = &"dry_fruit"
const ACTION_RATIONS: StringName = &"pack_rations"
## Brewing (decision 1621): mead into a vat, the cordial at the brewery's bench.
const ACTION_MEAD: StringName = &"brew_mead"
const ACTION_CORDIAL: StringName = &"make_cordial"
## The new recipes (decision 1625): jam and cheese at the preserving table, ale and cider at the brewery.
const ACTION_JAM: StringName = &"make_jam"
const ACTION_CHEESE: StringName = &"make_cheese"
const ACTION_ALE: StringName = &"brew_ale"
const ACTION_CIDER: StringName = &"make_cider"
## The Ferry section (decision 0437) and the Regatta section (decision 0438).
const ACTION_FERRY_GATHER: StringName = &"ferry_gather"
const ACTION_FERRY_SEND: StringName = &"ferry_send"
const ACTION_FERRY_CANCEL: StringName = &"ferry_cancel"
const ACTION_REGATTA_PREV_DAY: StringName = &"regatta_prev_day"
const ACTION_REGATTA_NEXT_DAY: StringName = &"regatta_next_day"
const ACTION_REGATTA_HOST: StringName = &"regatta_host"
const ACTION_REGATTA_HOLD: StringName = &"regatta_hold"
const ACTION_REGATTA_OVERRIDE: StringName = &"regatta_override"
const ACTION_REGATTA_SKIP: StringName = &"regatta_skip"
const BUTTON_TEXT: Dictionary = {
	&"prev_site": "◀ Site", &"next_site": "Site ▶", &"span_tool": "Span two banks…",
	&"build_plank": "Build footbridge", &"build_log": "Build log bridge", &"source": "Source ▸",
	&"dive": "Dive in the pond", &"consent": "Swim shortcuts: on",
	&"fish_site": "Site ▸", &"fish_method": "Method ▸", &"fish_species": "Fish ▸",
	&"fish_authorise": "Authorise trip", &"fish_next_trip": "Next trip ▸", &"fish_cancel": "Cancel trip",
	&"make_net": "Make net", &"make_trap": "Make trap", &"make_ice_kit": "Make ice kit", &"mend": "Mend gear",
	&"dry_fish": "Dry fish", &"mill_grain": "Mill grain", &"dry_fruit": "Dry fruit", &"pack_rations": "Pack rations",
	&"brew_mead": "Brew mead", &"make_cordial": "Make cordial", &"make_jam": "Make jam", &"make_cheese": "Make cheese",
	&"brew_ale": "Brew ale", &"make_cider": "Make cider",
	&"ferry_gather": "Gather the far copse", &"ferry_send": "Send the ferry", &"ferry_cancel": "Cancel crossing",
	&"regatta_prev_day": "◀ Day", &"regatta_next_day": "Day ▶", &"regatta_host": "Host ▸",
	&"regatta_hold": "Hold the regatta", &"regatta_override": "Override reserves", &"regatta_skip": "Skip this season",
}
## What a button does, where its action card does not say it (decision 0391: every action has a hover text).
const BUTTON_TIPS: Dictionary = {
	&"prev_site": "The previous bridge site on the stream", &"next_site": "The next bridge site on the stream",
	&"span_tool": "Choose a site yourself: click one bank, then the other (Esc drops it)",
	&"consent": "Swim shortcuts: whether the selected residents (everyone, with nobody selected) may swim across instead of walking round",
	&"fish_site": "The next fishing water: the run, the ford, the pond",
	&"fish_method": "The next method there: hand net, trap, boat, ice fishing",
	&"fish_species": "The next fish of that water",
	&"fish_next_trip": "Choose the next trip out (Cancel trip acts on it)",
	&"regatta_prev_day": "An earlier day for the regatta, this season", &"regatta_next_day": "A later day for the regatta, this season",
	&"regatta_host": "The next resident to host the regatta",
}
## The Fishing, Boats and rack-and-mill sections' button rows (decision 0431).
const CHOICE_ACTIONS: Array[StringName] = [&"fish_site", &"fish_method", &"fish_species"]
const TRIP_ACTIONS: Array[StringName] = [&"fish_authorise", &"fish_next_trip", &"fish_cancel"]
const GEAR_ACTIONS: Array[StringName] = [&"make_net", &"make_trap", &"make_ice_kit", &"mend"]
const STATION_ACTIONS: Array[StringName] = [&"dry_fish", &"mill_grain"]
const PRESERVE_ACTIONS: Array[StringName] = [&"dry_fruit", &"pack_rations"]
const BREW_ACTIONS: Array[StringName] = [&"brew_mead", &"make_cordial"]
const PRESERVE_ACTIONS_2: Array[StringName] = [&"make_jam", &"make_cheese"]
const BREW_ACTIONS_2: Array[StringName] = [&"brew_ale", &"make_cider"]
const FERRY_ACTIONS: Array[StringName] = [&"ferry_gather", &"ferry_send", &"ferry_cancel"]
const REGATTA_CHOICE_ACTIONS: Array[StringName] = [&"regatta_prev_day", &"regatta_next_day", &"regatta_host"]
const REGATTA_ACTIONS: Array[StringName] = [&"regatta_hold", &"regatta_override", &"regatta_skip"]
## The Ferry and Regatta sections' lines, in order (demo_ferry.gd and demo_regatta.gd fill them).
const FERRY_LINES: Array[StringName] = [&"ferry_status", &"ferry_cargo", &"ferry_copse", &"ferry_benefit"]
const REGATTA_LINES: Array[StringName] = [&"regatta_status", &"regatta_choice", &"regatta_preview"]
## Their lines, in order: what fishery.gd's panel text fills.
const FISHERY_LINES: Array[StringName] = [&"fish_choice", &"fish_preview", &"fish_trips", &"fish_gear", &"boats",
	&"stations", &"preserves", &"brewing"]
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
## The line `scroll_to_line` keeps at the top while the panel settles (none: &""), and until which process frame.
var _scroll_key: StringName = &""
var _scroll_until_frame: int = 0
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
	_build_fishery()
	_build_ferry()
	_build_regatta()
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


func _build_fishery() -> void:
	"""Fishing (the trip's choice and figures, Authorise, the trips, the gear), Boats, and the drying rack and mill
	(water part B, decision 0431): below the bridges, so the 0391 actions above stay in view at 1280x720."""
	_add_line(_column, &"fish_title", HEADING_PX, Palette.INK, Styles.heading_font())
	_set_line(&"fish_title", "Fishing")
	_add_line(_column, &"fish_choice", SMALL_PX, Palette.INK, null)
	_column.add_child(_row(CHOICE_ACTIONS))
	_add_line(_column, &"fish_preview", SMALL_PX, Palette.UMBER, null)
	_column.add_child(_row(TRIP_ACTIONS))
	_add_line(_column, &"fish_trips", SMALL_PX, Palette.INK, null)
	_add_line(_column, &"fish_gear", SMALL_PX, Palette.UMBER, null)
	_column.add_child(_row(GEAR_ACTIONS))
	_add_line(_column, &"boats_title", HEADING_PX, Palette.INK, Styles.heading_font())
	_set_line(&"boats_title", "Boats")
	_add_line(_column, &"boats", SMALL_PX, Palette.INK, null)
	_add_line(_column, &"stations_title", HEADING_PX, Palette.INK, Styles.heading_font())
	_set_line(&"stations_title", "Drying rack and mill")
	_add_line(_column, &"stations", SMALL_PX, Palette.INK, null)
	_column.add_child(_row(STATION_ACTIONS))
	_add_line(_column, &"preserves_title", HEADING_PX, Palette.INK, Styles.heading_font())
	_set_line(&"preserves_title", "Preserves")
	_add_line(_column, &"preserves", SMALL_PX, Palette.INK, null)
	_column.add_child(_row(PRESERVE_ACTIONS))
	_column.add_child(_row(PRESERVE_ACTIONS_2))
	_add_line(_column, &"brewing_title", HEADING_PX, Palette.INK, Styles.heading_font())
	_set_line(&"brewing_title", "Brewing")
	_add_line(_column, &"brewing", SMALL_PX, Palette.INK, null)
	_column.add_child(_row(BREW_ACTIONS))
	_column.add_child(_row(BREW_ACTIONS_2))


func _build_ferry() -> void:
	"""The Ferry (decision 0437): its state and timetable, the stacks, the far copse, its benefit; its orders."""
	_add_line(_column, &"ferry_title", HEADING_PX, Palette.INK, Styles.heading_font())
	_set_line(&"ferry_title", "Ferry")
	for key: StringName in FERRY_LINES:
		_add_line(_column, key, SMALL_PX, Palette.INK if key != &"ferry_benefit" else Palette.UMBER, null)
	_column.add_child(_row(FERRY_ACTIONS))


func _build_regatta() -> void:
	"""The Regatta (decision 0438): the season's occasion, its day and host, the feast's preview; hold, override, skip."""
	_add_line(_column, &"regatta_title", HEADING_PX, Palette.INK, Styles.heading_font())
	_set_line(&"regatta_title", "Regatta")
	_add_line(_column, &"regatta_status", SMALL_PX, Palette.INK, null)
	_add_line(_column, &"regatta_choice", SMALL_PX, Palette.INK, null)
	_column.add_child(_row(REGATTA_CHOICE_ACTIONS))
	_add_line(_column, &"regatta_preview", SMALL_PX, Palette.UMBER, null)
	_column.add_child(_row(REGATTA_ACTIONS))


func show_ferry(lines: Dictionary) -> void:
	"""The Ferry section: each FERRY_LINES key's text (missing keys keep theirs)."""
	for key: StringName in FERRY_LINES:
		if lines.has(key):
			_set_line(key, String(lines[key]))


func show_regatta(lines: Dictionary) -> void:
	"""The Regatta section: each REGATTA_LINES key's text (missing keys keep theirs)."""
	for key: StringName in REGATTA_LINES:
		if lines.has(key):
			_set_line(key, String(lines[key]))


func scroll_to_line(key: StringName) -> void:
	"""Scroll the sections so a line is at the top of the view (the HUD's Feast command brings the Regatta section).
	A panel just brought forward is still growing to its full height (its scroll clamped short), so the scroll is set
	again each time its range changes for SCROLL_SETTLE_FRAMES -- never after, so the player's own scrolling stands."""
	if not _lines.has(key):
		return
	_scroll_key = key
	_scroll_until_frame = Engine.get_process_frames() + SCROLL_SETTLE_FRAMES
	var bar: VScrollBar = _body.get_v_scroll_bar()
	if not bar.changed.is_connected(_settle_scroll):
		bar.changed.connect(_settle_scroll)
	_settle_scroll()


func _settle_scroll() -> void:
	"""Put the line asked for by `scroll_to_line` at the top, while its settling window lasts."""
	if _scroll_key == &"" or Engine.get_process_frames() > _scroll_until_frame:
		_scroll_key = &""
		return
	var top: float = _body.offset_in(_lines[_scroll_key] as Control)
	if top >= 0.0:
		_body.scroll_vertical = int(top)


func show_fishery(lines: Dictionary) -> void:
	"""Water part B's sections: each FISHERY_LINES key's text (missing keys keep theirs)."""
	for key: StringName in FISHERY_LINES:
		if lines.has(key):
			_set_line(key, String(lines[key]))


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
	var made := _wood_button(BUTTON_TEXT[key], func() -> void: action.emit(key))
	made.tooltip_text = BUTTON_TIPS.get(key, BUTTON_TEXT[key])
	_buttons[key] = made
	return made


func _wood_button(text: String, pressed: Callable) -> Button:
	"""A wood button at least BUTTON_H tall, its caption cut with an ellipsis where the column is too narrow;
	takes keyboard focus (decision 0261)."""
	var made := Button.new()
	made.text = text
	Styles.focusable(made, BUTTON_MARGINS)
	made.custom_minimum_size.y = BUTTON_H
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	made.clip_text = true
	made.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	made.add_theme_font_size_override(&"font_size", SMALL_PX)
	made.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	made.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	made.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	made.add_theme_stylebox_override(&"disabled", Styles.box(Styles.PIECE_WOOD_DISABLED, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		made.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	made.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	made.add_theme_color_override(&"font_disabled_color", Palette.text_on(Palette.SURFACE_WOOD_DISABLED))
	made.pressed.connect(pressed)
	return made


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
	var log_line: String = ""
	for part: String in text.split("\n", false):
		if part.begins_with(TextScript.PLANK_LINE):
			plank = part
		elif part.begins_with(TextScript.LOG_LINE):
			log_line = part
		else:
			site.append(part)
	_show_label(&"site", "\n".join(site))
	_show_label(&"plank_cost", plank)
	_show_label(&"log_cost", log_line)
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


func show_status(bridges: String, stores: String, log_line: String) -> void:
	"""The bridges planned and open, the stores and the water's news."""
	_set_line(&"bridges", bridges)
	_set_line(&"stores", stores)
	_set_line(&"log", log_line)


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
