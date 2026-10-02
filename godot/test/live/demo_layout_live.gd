extends SceneTree
## The live demo's panels measured on the REAL scene at a window size and every interface scale (decision 0391;
## review F20, F31, F12, F36, F35). Not discovered by the runner: test/test_demo_layout_live.gd runs it in its own
## process, as the input harness is (decision 0261), because only an in-tree scene lays its Controls out.
##
##     godot --headless --path godot --script res://test/live/demo_layout_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Measurements are the review's layout probe's: real Control rects, visibility, and the clip of every
## clipping ancestor (a ScrollContainer's), as a fraction of the control left on screen. For each interface scale
## the window offers (100 %, 125 %, 150 %; a refused one is checked refused and the demo's own refit is followed),
## it selects one, six and nine residents with a notice, opens the Water panel and the crop picker, and checks
## what must be in view, what must be reachable by scrolling, the 14 px and 32 px floors, the scale every panel
## draws at, and that the bottom band, the incident card and the side columns keep apart. Prints `LIVE <name>:
## PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const WaterPanel := preload("res://demo/waterplay/water_panel.gd")
const ZoneScript := preload("res://demo/ui/demo_detail_zone.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
const SCALES: Array[int] = [100, 125, 150]
const NOTICE: String = "A tunnel notice for the selection, long enough to wrap onto a second line here"
const FULL: float = 0.99
## Party sizes checked: one resident, six (or as many as the cast has), the whole cast (nine staged, six on
## placeholders).
const PARTIES: Array[int] = [1, 6, 9]

var _village: Node = null
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _checks: int = 0
var _failures: int = 0
var _scale: int = 100


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and run the checks."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size() - 1:
		if args[k] == "--size":
			var parts: PackedStringArray = args[k + 1].split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
		elif args[k] == "--capture":
			_capture_dir = args[k + 1]
	root.size = _size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_run.call_deferred()


func _frames(count: int) -> void:
	"""Wait `count` frames, holding the window size (the headless server sizes the root to 64x64 at first)."""
	for k: int in count:
		if root.size != _size:
			root.size = _size
		await process_frame


func _run() -> void:
	"""Every scale, then the summary."""
	await _frames(BOOT_FRAMES)
	_manager().call(&"pause_game")
	for percent: int in SCALES:
		await _at_scale(percent)
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers ------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size and scale."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d@%d %s: %s %s" % [_size.x, _size.y, _scale, check_name, "PASS" if ok else "FAIL", detail])


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _command() -> Node:
	"""The command layer."""
	return _village.get("_command")


func _party() -> CanvasLayer:
	"""The party panel."""
	return _command().call(&"panel")


func _water() -> CanvasLayer:
	"""The Water panel."""
	return _village.get("_waterplay").get("panel")


func _farm() -> Node:
	"""The farm."""
	return _village.get("_farm")


func _fraction(control: Control) -> float:
	"""How much of `control` is on screen: its rect cut by the window and every clipping ancestor (the review's
	layout probe's measure); 0 when it is not visible in the tree."""
	if control == null or not control.is_visible_in_tree():
		return 0.0
	var rect: Rect2 = control.get_global_rect()
	var clip := Rect2(Vector2.ZERO, Vector2(_size))
	var at: Node = control.get_parent()
	while at != null:
		if at is Control and (at as Control).clip_contents:
			clip = clip.intersection((at as Control).get_global_rect())
		at = at.get_parent()
	return rect.intersection(clip).get_area() / maxf(rect.get_area(), 0.0001)


func _scroll_of(control: Control) -> ScrollContainer:
	"""The scroll `control` sits in (null: none)."""
	var at: Node = control.get_parent()
	while at != null:
		if at is ScrollContainer:
			return at
		at = at.get_parent()
	return null


func _reachable(control: Control) -> bool:
	"""Whether `control` comes fully into view -- or, taller than its scroll's view, fills it -- scrolling its scroll
	to it if it has one, the way focus does (demo_scroll.gd `reveal`; the scroll is put back; awaited: a scroll moves
	its content on the next frame)."""
	if _fraction(control) >= FULL:
		return true
	var scroll: ScrollContainer = _scroll_of(control)
	if scroll == null:
		return false
	var was: int = scroll.scroll_vertical
	if scroll.has_method(&"reveal"):
		scroll.call(&"reveal", control)
	else:
		scroll.ensure_control_visible(control)
	await _frames(2)
	var whole: float = minf(1.0, scroll.size.y / maxf(control.size.y, 1.0))
	var seen: bool = _fraction(control) >= whole * FULL
	scroll.scroll_vertical = was
	await _frames(1)
	return seen


func _floors(what: String, layer: Node) -> void:
	"""Every shown label and button under `layer` at least 14 px, and every shown button at least 32 logical px
	tall (UI §2.1, UX-T03)."""
	var small: PackedStringArray = PackedStringArray()
	var short: PackedStringArray = PackedStringArray()
	for node: Node in layer.find_children("*", "Control", true, false):
		var control := node as Control
		if not (control is Label or control is Button) or not control.is_visible_in_tree():
			continue
		if String(control.get(&"text")).is_empty():
			continue
		if control.get_theme_font_size(&"font_size") < 14:
			small.append("%s %dpx" % [control.name, control.get_theme_font_size(&"font_size")])
		if control is Button and control.size.y < 32.0 - 0.01:
			short.append("%s %.0f" % [control.name, control.size.y])
	_check("%s: text at least 14 px" % what, small.is_empty(), ", ".join(small))
	_check("%s: buttons at least 32 px" % what, short.is_empty(), ", ".join(short))


func _capture(file_name: String) -> void:
	"""Save the frame now (only when asked for, and never headless)."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d_%d.png" % [file_name, _size.x, _size.y, _scale]))
	_manager().set("_last_host_usec", Time.get_ticks_usec())


func _zone_foot() -> float:
	"""The foot of a right-column panel's rectangle, viewport px (demo_detail_zone.gd `panel_placement`)."""
	var geometry := UiLayout.Geometry.new()
	var rect: Rect2 = ZoneScript.panel_placement(_size.x, _size.y, 10.0, ZoneScript.STRIP_H + ZoneScript.STRIP_GAP,
		UiLayout.new(), geometry)
	return rect.end.y * geometry.scale


func _effective() -> float:
	"""The HUD's effective scale S for this window at the scale now."""
	return DemoUiScale.effective_scale(Vector2(_size))


# --- one scale ----------------------------------------------------------------------------------------

func _at_scale(percent: int) -> void:
	"""Choose `percent` as the menu would; where the window refuses it, check the refusal and the step down."""
	var offered: bool = bool(_village.call(&"ui_scale_fits", percent))
	_village.call(&"set_ui_scale", percent)
	await _frames(SETTLE_FRAMES)
	_scale = DemoUiScale.percent
	if not offered:
		_check("%d%% refused: steps down to one the window fits" % percent, _scale < percent
			and bool(_village.call(&"ui_scale_fits", _scale)), "now %d%%" % _scale)
		return
	_check("%d%% applied" % percent, _scale == percent)
	await _party_checks()
	await _water_checks()
	await _picker_checks()
	await _scale_checks()


# --- F20 / F31: the party panel ---------------------------------------------------------------------------

func _party_checks() -> void:
	"""One, six and nine selected, each with a notice: the frame, count, summary and actions; every member."""
	var cast: int = int(_village.get("_cast").call(&"actor_count"))
	for wanted: int in PARTIES:
		var n: int = mini(wanted, cast) if wanted < PARTIES.back() else cast
		_command().call(&"select", PackedInt32Array(range(n)))
		_command().call(&"_refresh_panel")
		await _frames(SETTLE_FRAMES)
		(_party().call(&"inspector") as ScrollContainer).scroll_vertical = 100000
		await _frames(1)
		_command().call(&"say", "%s (%d of %d)" % [NOTICE, n, wanted])
		await _frames(SETTLE_FRAMES)
		var party: CanvasLayer = _party()
		_check("party %d: a new notice scrolls the inspector back to it" % n,
			(party.call(&"inspector") as ScrollContainer).scroll_vertical == 0)
		var frame: Control = party.get("_frame")
		var what: String = "party %d" % n
		_check("%s: the frame is shown" % what, frame.is_visible_in_tree() and _fraction(frame) >= FULL,
			str(party.call(&"frame_rect")))
		var count: Label = party.get("_count")
		_check("%s: the count in view" % what, count.text == "%d selected" % n and _fraction(count) >= FULL, count.text)
		var summary: Label = party.get("_summary")
		_check("%s: the summary reachable" % what, not summary.text.is_empty() and await _reachable(summary), summary.text)
		var release: Button = party.call(&"release_button")
		var docked: bool = bool(party.call(&"docked"))
		_check("%s: Release in view (docked) or reachable" % what, _fraction(release) >= FULL if docked else await _reachable(release),
			"docked %s" % docked)
		if _scale == 100:
			_check("%s: at 100%% the actions are always in view" % what, docked and _fraction(release) >= FULL)
		await _members(party, n, what)
		_floors(what, party)
		_capture("party_%d" % n)


func _members(party: CanvasLayer, n: int, what: String) -> void:
	"""A group lists every member as a row, each reachable; one resident's orders are listed in full."""
	if n == 1:
		var orders: String = String(party.call(&"abilities_text"))
		_check("%s: the orders in full, each target kept" % what, orders.contains("— the ground, a work spot"), orders.left(60))
		var abilities: Label = party.get("_abilities")
		_check("%s: the orders reachable" % what, await _reachable(abilities))
		await _reveal_tall(party, abilities)
		return
	_check("%s: a row for every member" % what, int(party.call(&"member_row_count")) == n)
	if n == int(_village.get("_cast").call(&"actor_count")):
		await _reveal_checks(party, n)
	var unreachable: PackedStringArray = PackedStringArray()
	for k: int in n:
		var row: Button = party.call(&"member_row", k)
		if not await _reachable(row):
			unreachable.append(str(k))
	_check("%s: every member row reachable" % what, unreachable.is_empty(), ", ".join(unreachable))


func _reveal_checks(party: CanvasLayer, n: int) -> void:
	"""demo_scroll.gd at this scale: revealing the last row scrolls the least distance (the row's foot at the view's
	foot); revealing a row above scrolls up to it; keyboard focus on a row brings it into view; and a focused Release
	keeps its focus when the summary and actions move (`fit` to no room and back)."""
	var inspector: ScrollContainer = party.call(&"inspector")
	var last: Button = party.call(&"member_row", n - 1)
	inspector.scroll_vertical = 0
	await _frames(2)
	inspector.call(&"reveal", last)
	await _frames(2)
	var view: Rect2 = inspector.get_global_rect()
	var margin: float = 4.0 * inspector.get_global_transform().get_scale().y
	var foot_gap: float = view.end.y - last.get_global_rect().end.y
	_check("reveal: the least distance down", inspector.scroll_vertical == 0 or absf(foot_gap - margin) <= 1.5,
		"gap %.1f" % foot_gap)
	var first: Button = party.call(&"member_row", 0)
	inspector.call(&"reveal", first)
	await _frames(2)
	_check("reveal: back up to a row above", _fraction(first) >= FULL)
	inspector.scroll_vertical = 0
	await _frames(2)
	last.grab_focus()
	await _frames(2)
	_check("focus on a row brings it into view", _fraction(last) >= FULL, str(last.get_global_rect()))
	await _dock_keeps_focus(party)


func _reveal_tall(party: CanvasLayer, hint: Control) -> void:
	"""A control taller than the view (the orders list, where the column is short) is revealed from its top; a
	shorter one comes whole."""
	var inspector: ScrollContainer = party.call(&"inspector")
	if hint.size.y <= inspector.size.y:
		inspector.call(&"reveal", hint)
		await _frames(2)
		_check("reveal: a short one comes whole", _fraction(hint) >= FULL)
		return
	inspector.call(&"reveal", hint)
	await _frames(2)
	_check("reveal: a tall one from its top", absf(hint.get_global_rect().position.y - inspector.get_global_rect().position.y) <= 1.0)


func _dock_keeps_focus(party: CanvasLayer) -> void:
	"""A focused Release keeps its focus when the summary and actions move into the inspector and back."""
	var release: Button = party.call(&"release_button")
	release.grab_focus()
	var was: bool = bool(party.call(&"docked"))
	party.call(&"fit", 1.0)
	_check("undocking keeps Release's focus", root.gui_get_focus_owner() == release and not bool(party.call(&"docked")))
	party.call(&"fit", 4000.0)
	_check("docking again keeps it", root.gui_get_focus_owner() == release)
	release.release_focus()
	party.call(&"fit", 4000.0 if was else 1.0)
	# Back to the real column: fit(4000) left the inspector as tall as its content, past the window's foot (the
	# rows checked next would be measured against that; decision 0801's Follow (End) made the actions one row taller).
	party.call(&"_place")
	await _frames(SETTLE_FRAMES)


# --- F12: the Water panel ---------------------------------------------------------------------------------

func _water_checks() -> void:
	"""Resident 0 selected, the Water panel shown: its pinned line, the folded roster, the actions."""
	_command().call(&"select", PackedInt32Array([0]))
	_village.get("_zone").call(&"show_panel", ZoneScript.PANEL_WATER)
	_village.get("_waterplay").call(&"refresh_panel")
	await _frames(SETTLE_FRAMES)
	var water: CanvasLayer = _water()
	(water.call(&"sections") as ScrollContainer).scroll_vertical = 0
	await _frames(1)
	var pinned: PackedStringArray = water.call(&"picked_texts")
	var lines: PackedStringArray = String(water.call(&"line", &"swimmers")).split("\n", false)
	_check("water: the selected resident pinned", pinned.size() == 1 and not lines.is_empty() and pinned[0] == lines[0], str(pinned))
	_check("water: All residents folded", not bool(water.call(&"roster_open")) and not (water.call(&"roster_row", 0) as Control).is_visible_in_tree())
	var hidden: PackedStringArray = PackedStringArray()
	var lost: PackedStringArray = PackedStringArray()
	_builds_shown_only_when_they_commit(water)
	for key: StringName in _shown_actions(water, [WaterPanel.ACTION_DIVE, WaterPanel.ACTION_CONSENT, WaterPanel.ACTION_BUILD_PLANK,
			WaterPanel.ACTION_BUILD_LOG]):
		var button: Button = water.call(&"button", key)
		if _fraction(button) < FULL:
			hidden.append(String(key))
		if not await _reachable(button):
			lost.append(String(key))
	if _scale == 100:
		_check("water: swim and build actions in view without scrolling", hidden.is_empty(), ", ".join(hidden))
	_check("water: every action reachable", lost.is_empty(), ", ".join(lost))
	water.call(&"set_roster_open", true)
	await _frames(SETTLE_FRAMES)
	var last: int = int(_village.get("_cast").call(&"actor_count")) - 1
	_check("water: All residents rows reachable once unfolded", await _reachable(water.call(&"roster_row", last)))
	(water.call(&"roster_row", last) as Button).pressed.emit()
	_check("water: a row selects its resident", _command().call(&"selected") == PackedInt32Array([last]))
	_command().call(&"select", PackedInt32Array([0]))
	_floors("water", water)
	_captions_whole(water)
	_capture("water")
	water.call(&"set_roster_open", false)
	await _rescue_checks(water)


func _shown_actions(water: CanvasLayer, keys: Array[StringName]) -> Array[StringName]:
	"""The keys whose buttons are shown: a Build button shows only when it can commit (decision 0461)."""
	var out: Array[StringName] = []
	for key: StringName in keys:
		if (water.call(&"button", key) as Button).visible:
			out.append(key)
	return out


func _builds_shown_only_when_they_commit(water: CanvasLayer) -> void:
	"""Decision 0461: each Build button is shown exactly when its action card allows it (its tooltip's "Can't now" is
	the hidden one's reason), and a hidden one leaves the project line saying what is missing."""
	var wrong: PackedStringArray = PackedStringArray()
	for key: StringName in [WaterPanel.ACTION_BUILD_PLANK, WaterPanel.ACTION_BUILD_LOG]:
		var button: Button = water.call(&"button", key)
		if button.visible == button.tooltip_text.contains("Can't now"):
			wrong.append(String(key))
	_check("water: a Build shows only when it can commit", wrong.is_empty(), ", ".join(wrong))


func _captions_whole(water: CanvasLayer) -> void:
	"""The Water panel's action captions are whole: each shown button is at least as wide as its words."""
	var cut: PackedStringArray = PackedStringArray()
	for key: StringName in WaterPanel.BUTTON_TEXT:
		var button: Button = water.call(&"button", key)
		if not button.is_visible_in_tree():
			continue
		var font: Font = button.get_theme_font(&"font")
		var words: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			button.get_theme_font_size(&"font_size")).x
		if button.size.x < words:
			cut.append(button.text)
	_check("water: every action's caption whole", cut.is_empty(), ", ".join(cut))


func _rescue_checks(water: CanvasLayer) -> void:
	"""Two residents in difficulty and three selected (the code review's case): the alert is pinned, capped, whole in
	its tooltip; the sections keep MIN_BODY_H (the selection folds away where it must) and every action stays
	reachable; the frame stays inside the window. The panel's refresh beat is held meanwhile, so the water's own
	(calm) state does not overwrite the case."""
	var alert: String = "In difficulty: Otter fisher, underwater, breath 37% — Otter boatwright: diving to fetch them (the ford is nearer); Mouse keeper, at the surface, breath 64% — no rescuer free yet (the water brings it ashore in 80 s)"
	_village.get("_waterplay").set("_refresh_in", 1000.0)
	water.call(&"show_water", "Stream flowing 0.40 m/s · mild water", alert, "Swimmers — 2 in the water", water.call(&"line", &"swimmers"))
	water.call(&"set_selected", PackedInt32Array([0, 1, 2]))
	await _frames(2)
	var label: Label = (water.get("_lines") as Dictionary)[&"alert"]
	_check("rescue: the alert pinned", label.is_visible_in_tree() and _fraction(label) >= FULL)
	_check("rescue: the whole alert in its tooltip", label.tooltip_text == alert)
	var body: ScrollContainer = water.call(&"sections")
	_check("rescue: the sections keep their room", body.size.y >= float(WaterPanel.MIN_BODY_H) - 0.5,
		"%.0f, folded %s" % [body.size.y, water.call(&"picked_folded")])
	if _size.y == 720:
		_check("rescue: the selection folds only where it must", bool(water.call(&"picked_folded")) == (_scale > 100),
			"folded %s" % water.call(&"picked_folded"))
	var lost: PackedStringArray = PackedStringArray()
	for key: StringName in _shown_actions(water, [WaterPanel.ACTION_DIVE, WaterPanel.ACTION_BUILD_LOG]):
		if not await _reachable(water.call(&"button", key)):
			lost.append(String(key))
	_check("rescue: the actions reachable", lost.is_empty(), ", ".join(lost))
	var frame: Rect2 = water.call(&"frame_rect")
	_check("rescue: the frame inside its zone", frame.end.y <= _zone_foot() + 0.5, "%s, foot %.1f" % [frame, _zone_foot()])
	_capture("water_rescue")
	water.call(&"set_selected", PackedInt32Array([0]))
	_village.get("_waterplay").set("_refresh_in", 0.0)


# --- F36 / F12: the crop picker -----------------------------------------------------------------------------

func _picker_checks() -> void:
	"""Bed 1's crop picker: one scroll, its title and Back in view however far it is scrolled."""
	_farm().call(&"select_bed", 0)
	await _frames(SETTLE_FRAMES)
	var bed: CanvasLayer = _farm().get("bed_panel")
	bed.call(&"open_picker")
	await _frames(SETTLE_FRAMES)
	var scrolls: int = 0
	for node: Node in bed.find_children("*", "ScrollContainer", true, false):
		scrolls += 1 if (node as Control).is_visible_in_tree() else 0
	_check("picker: one scroll owner", scrolls == 1, "%d" % scrolls)
	var frame: Rect2 = bed.call(&"frame_rect")
	_check("picker: the frame inside its zone", frame.end.y <= _zone_foot() + 0.5, "%s, foot %.1f" % [frame, _zone_foot()])
	var back: Button = bed.call(&"back_button")
	_check("picker: Back in view", _fraction(back) >= FULL, str(back.get_global_rect()))
	var body: ScrollContainer = bed.call(&"body")
	body.scroll_vertical = 100000
	await _frames(2)
	_check("picker: Back still in view scrolled to the end", _fraction(back) >= FULL)
	_check("picker: its title still in view", _fraction(bed.get("_picker_title")) >= FULL)
	var rows: Node = bed.get("_picker_rows")
	body.scroll_vertical = 0
	await _frames(2)
	_check("picker: the last crop reachable", await _reachable(rows.get_child(rows.get_child_count() - 1).get_child(0)))
	_floors("picker", bed)
	_capture("picker")
	body.scroll_vertical = 0
	bed.call(&"close_picker")


# --- F35: every panel at the HUD's scale; the bottom band and the card apart -------------------------------

func _scale_checks() -> void:
	"""Each demo surface draws at S; the tooltips' type is TIP_PX x S; the bottom band, the card and the columns
	keep apart."""
	var s: float = _effective()
	var incidents: Object = _village.get("_services").get("incidents")
	_village.get("_lens_picker").call(&"choose", 1)
	await _frames(SETTLE_FRAMES)
	_guide_room()
	incidents.call(&"raise", "layout:card", 2, 2, "A layout check: the stream is rising fast at the weir")
	await _frames(SETTLE_FRAMES)
	var card_frame: Control = _village.get("_cards").get("_frame")
	for k: int in 240:
		if card_frame.is_visible_in_tree():
			break
		await _frames(1)
	var frames: Dictionary = {"party": _party().get("_frame"), "zone strip": _village.get("_zone").get("_strip"),
		"water": _water().get("_frame"), "bed": _farm().get("bed_panel").get("_frame"),
		"lens picker": _village.get("_lens_picker").get("_frame"), "card": _village.get("_cards").get("_frame"),
		"news strip": _village.get("_news").get("_frame"), "news window": _village.get("_history").get("_frame"),
		"pantry": _farm().get("pantry_panel").get("_frame"), "guide card": _village.call(&"guide").get("card").call(&"frame")}
	var off: PackedStringArray = PackedStringArray()
	for key: String in frames:
		var frame: Control = frames[key]
		if frame == null or not is_equal_approx(frame.scale.x, s):
			off.append("%s %s" % [key, frame.scale.x if frame != null else "none"])
	var indicator: float = float(_command().call(&"tunnels").get("view").call(&"indicator_scale"))
	if not is_equal_approx(indicator, s):
		off.append("level indicator %s" % indicator)
	_check("every demo surface at S=%.2f" % s, off.is_empty(), ", ".join(off))
	var tip: int = CardScript.tooltip_theme().get_font_size(&"font_size", &"TooltipLabel")
	_check("card tooltips at TIP_PX x S", tip == roundi(float(CardScript.TIP_PX) * s), "%d px" % tip)
	var geometry := UiLayout.Geometry.new()
	UiLayout.new().compute_into(_size.x, _size.y, DemoUiScale.percent, false, geometry)
	var top: float = (geometry.management_top + 10.0) * s
	_check("the picker inside its slot", (frames["lens picker"] as Control).get_global_rect().position.y >= top - 0.5)
	_village.get("_lens_picker").call(&"toggle_list")
	await _frames(SETTLE_FRAMES)
	_check("unfolded, the list scrolls inside its slot", (frames["lens picker"] as Control).get_global_rect().position.y >= top - 0.5)
	_village.get("_lens_picker").call(&"toggle_list")
	await _woods_and_tunnels()
	_apart(frames)
	_capture("scale")
	_village.get("_lens_picker").call(&"choose", 0)
	incidents.call(&"resolve", "layout:card")


func _woods_and_tunnels() -> void:
	"""The Woods and Tunnels panels meet the 14 px and 32 px floors too."""
	var zone: Node = _village.get("_zone")
	zone.call(&"show_panel", ZoneScript.PANEL_WOODS)
	await _frames(SETTLE_FRAMES)
	_floors("woods", _village.get("_forestry").get("panel"))
	zone.call(&"show_panel", ZoneScript.PANEL_TUNNELS)
	await _frames(SETTLE_FRAMES)
	_floors("tunnels", _command().call(&"tunnels").get("ext").get("panel"))
	zone.call(&"show_panel", ZoneScript.PANEL_FARM)


func _apart(frames: Dictionary) -> void:
	"""The Map layer picker clear of the right column, the party panel and the news strip; the incident card clear
	of the party panel and the right column's tab strip."""
	var picker: Rect2 = (frames["lens picker"] as Control).get_global_rect()
	var right: Rect2 = (frames["water"] as Control).get_global_rect() if (frames["water"] as Control).is_visible_in_tree() \
		else (frames["bed"] as Control).get_global_rect()
	var party: Rect2 = (frames["party"] as Control).get_global_rect()
	var strip: Rect2 = (frames["zone strip"] as Control).get_global_rect()
	_check("the picker clear of the right column", not picker.intersects(right), "%s %s" % [picker, right])
	_check("the picker clear of the party panel", not picker.intersects(party), "%s %s" % [picker, party])
	var news: Control = frames["news strip"]
	if news.is_visible_in_tree():
		_check("the picker clear of the news strip", not picker.intersects(news.get_global_rect()))
		_check("the news strip clear of the right column", not news.get_global_rect().intersects(right))
	var card: Control = frames["card"]
	_check("the incident card shows", card.is_visible_in_tree())
	_check("the card clear of the party panel and the tab strip", not card.get_global_rect().intersects(party)
		and not card.get_global_rect().intersects(strip), "%s" % card.get_global_rect())
	_guide_apart(frames, party, strip, right, picker)


func _guide_apart(frames: Dictionary, party: Rect2, strip: Rect2, right: Rect2, picker: Rect2) -> void:
	"""With a critical incident's card up, the guide's objective card (decision 0481) yields to it: one card at the top
	centre."""
	_check("the guide card yields to the incident card", not (frames["guide card"] as Control).is_visible_in_tree())


func _guide_room() -> void:
	"""With a map layer's legend unfolded, the guide's objective card is above the Map layer picker and clear of the
	side columns and the tab strip -- or, where no density of it fits, waits (never overlapping)."""
	var card: Control = _village.call(&"guide").get("card").call(&"frame")
	var picker: Rect2 = (_village.get("_lens_picker").get("_frame") as Control).get_global_rect()
	var party: Rect2 = (_party().get("_frame") as Control).get_global_rect()
	var strip: Rect2 = (_village.get("_zone").get("_strip") as Control).get_global_rect()
	var rect: Rect2 = card.get_global_rect()
	var shown: bool = card.is_visible_in_tree()
	var incident: bool = bool(_village.get("_cards").call(&"is_shown"))
	var cramped: bool = bool(_village.call(&"guide").get("card").get("_cramped"))
	var why: String = "shown" if shown else ("yielding to the incident card" if incident else "waiting for room")
	_check("the guide card clear of the Map layer picker", not shown or not rect.intersects(picker),
		"%s %s %s" % [why, rect, picker])
	_check("the guide card clear of the party panel and the tab strip", not shown or (not rect.intersects(party)
		and not rect.intersects(strip)), "%s" % rect)
	_check("the guide card hidden only to yield or for room", shown or incident or cramped, why)
	_check("the guide card shows at 100 %", shown or incident or DemoUiScale.percent != 100, why)
	_capture("guide_room")
