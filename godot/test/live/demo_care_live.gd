extends SceneTree
## The infirmary (decision 0622) on the REAL scene: the Demo Lab's test injury on a selected resident, the resident
## card's lines, the herbalist walking over and treating it, the news, the herb patch drawn, and a burrow home made the
## sickbay from its section in the Tunnels panel -- in view, clicked, a serious patient lying in its bed at the
## infirmary's rate. Not discovered by the runner: test/test_demo_care_live.gd runs it in its own process, as the other
## live harnesses are (decisions 0261, 0391), because only an in-tree scene lays its Controls out and takes input.
##
##     godot --headless --path godot --script res://test/live/demo_care_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## The home is laid by the room tool's own `place` and its dig finished and fitted out at once (the night suite's way):
## the dig is the tunnels' feature, checked by theirs; here the sickbay is. Prints `LIVE <name>: PASS|FAIL <detail>` per
## check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const Rules := preload("res://demo/infirmary/care_rules.gd")
const Tasks := preload("res://demo/infirmary/care_tasks.gd")
const ZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const Injury := preload("res://scripts/core/injury.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
const FULL: float = 0.99
## Frames allowed for the healer to arrive and treat at 4x, and for the patient to reach the sickbay's bed.
const TREAT_FRAMES: int = 6000
## Where the sickbay home is laid (m): the open ground west of the hall's apron, tried on rings round it.
const HOME_AT: Vector2 = Vector2(-13.0, -14.0)
const HOME_RINGS: int = 6
const HOME_RING_M: float = 2.0

var _village: Node = null
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _checks: int = 0
var _failures: int = 0


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
	"""Every step, then the summary."""
	await _frames(BOOT_FRAMES)
	_manager().call(&"pause_game")
	await _built()
	await _the_test_injury()
	await _treated()
	await _the_herb_patch()
	await _the_sickbay()
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers ------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail])


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _command() -> Node:
	"""The command layer."""
	return _village.get("_command")


func _care() -> Node:
	"""The village's infirmary."""
	return _village.call(&"care")


func _desk() -> RefCounted:
	"""The infirmary's desk."""
	return _care().get("desk")


func _cast() -> Node:
	"""The cast."""
	return _village.get("_cast")


func _index_of(key: StringName) -> int:
	"""The cast index of the resident with cast key `key` (-1: none)."""
	for who: int in int(_cast().call(&"actor_count")):
		if _cast().call(&"actor", who).get("creature_key") == key:
			return who
	return -1


func _brain(who: int) -> Object:
	"""Resident `who`'s brain."""
	return _cast().call(&"actor", who).get("brain")


func _until(done: Callable, frames: int) -> int:
	"""Wait until `done()` (at most `frames` frames), keeping the village running at 4x (a pause another owner raises
	is released); the frames it took (-1: never)."""
	for k: int in frames:
		if bool(done.call()):
			return k
		if int(_manager().call(&"get_effective_speed")) == 0:
			_manager().call(&"resume_game")
		_manager().call(&"set_speed", 4)
		await _frames(1)
	return -1 if not bool(done.call()) else frames


func _hold() -> void:
	"""Back to 1x and paused (as the player)."""
	_manager().call(&"set_speed", 1)
	_manager().call(&"pause_game")


func _fraction(control: Control) -> float:
	"""How much of `control` is on screen: its rect cut by the window and every clipping ancestor."""
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


func _reveal(control: Control) -> void:
	"""Scroll `control`'s scroll to it (the way focus does), and wait for it to move."""
	var at: Node = control.get_parent()
	while at != null and not at is ScrollContainer:
		at = at.get_parent()
	if at != null:
		if at.has_method(&"reveal"):
			at.call(&"reveal", control)
		else:
			(at as ScrollContainer).ensure_control_visible(control)
	await _frames(2)


func _click(control: Control) -> void:
	"""A left click at `control`'s centre, through the Viewport."""
	var at: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event)


func _floors(what: String, layer: Node) -> void:
	"""Every shown label and button under `layer` at least 14 px; every shown button at least 32 px tall."""
	var bad := PackedStringArray()
	for node: Node in layer.find_children("*", "Control", true, false):
		var control := node as Control
		if not (control is Label or control is Button) or not control.is_visible_in_tree():
			continue
		if String(control.get(&"text")).is_empty():
			continue
		if control.get_theme_font_size(&"font_size") < 14 or (control is Button and control.size.y < 32.0 - 0.01):
			bad.append("%s %dpx %.0f" % [control.name, control.get_theme_font_size(&"font_size"), control.size.y])
	_check("%s: text 14 px, buttons 32 px" % what, bad.is_empty(), ", ".join(bad))


func _label_with(layer: Node, prefix: String) -> Label:
	"""The first shown label under `layer` whose text begins with `prefix` (null: none)."""
	for node: Node in layer.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.begins_with(prefix):
			return label
	return null


func _capture(file_name: String) -> void:
	"""Save the frame now (only when asked for, and never headless)."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(2)
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [file_name, _size.x, _size.y]))
	_manager().set("_last_host_usec", Time.get_ticks_usec())


func _look_at(at: Vector2, distance: float) -> void:
	"""Frame the camera on `at` (m) from `distance`."""
	var rig: Node = _village.get("_camera")
	rig.set("_target_distance", distance)
	rig.call(&"centre_on", Vector3(at.x, 0.0, at.y))
	rig.call(&"snap")


func _select(who: int) -> void:
	"""Select `who` alone and let the panel redraw."""
	_command().call(&"select", PackedInt32Array([who]))
	_command().call(&"_refresh_panel")
	await _frames(SETTLE_FRAMES)


# --- the steps ------------------------------------------------------------------------------------------------

func _built() -> void:
	"""The infirmary is in the village: its factor on the work pace, the herb patch drawn, nobody hurt."""
	_check("the infirmary is built", _care() != null)
	var pace: RefCounted = _village.get("_services").get("work_pace")
	_check("its health factor on the village's work pace", pace.call(&"name_of", 0) == "health", str(pace.call(&"count")))
	var patch: Node = _care().get("patch_view")
	_check("the herb patch drawn at its stock", int(patch.call(&"shown_clumps")) == 10, str(patch.call(&"shown_clumps")))
	var hurt: int = 0
	for who: int in int(_cast().call(&"actor_count")):
		hurt += 1 if bool(_desk().get("state").call(&"is_hurt", who)) else 0
	_check("nobody hurt at the start", hurt == 0, str(hurt))


func _the_test_injury() -> void:
	"""The Lab's Injury: disabled with nobody selected; on the fisher, a bite (−20), said in the news; the card's lines."""
	var lab: CanvasLayer = _village.call(&"lab")
	var index: int = -1
	for k: int in int(lab.call(&"trigger_count")):
		if (lab.call(&"trigger_button", k) as Button).text == "Injury":
			index = k
	_check("the Lab has the test injury", index >= 0)
	_command().call(&"select", PackedInt32Array())
	_check("disabled with nobody selected", not bool(lab.call(&"can_fire", index)))
	var fisher: int = maxi(_index_of(&"otter_fisher"), 0)
	await _select(fisher)
	lab.call(&"trigger", index)
	await _frames(SETTLE_FRAMES)
	var state: RefCounted = _desk().get("state")
	_check("the fisher is bitten", int(state.call(&"kind", fisher)) == Injury.KIND_BITE, str(state.call(&"kind", fisher)))
	_check("health 80", int(state.call(&"health", fisher)) == 80, str(state.call(&"health", fisher)))
	var notices: RefCounted = _village.get("_services").get("notices")
	var name: String = String(_cast().call(&"actor", fisher).get("display_name"))
	_check("said in the news", bool(notices.call(&"has_summary", "%s hurt (bite) — needs treatment" % name)))
	await _the_card(fisher)


func _the_card(fisher: int) -> void:
	"""The fisher's card: its injury line in view, the floors; the frame."""
	_command().call(&"_refresh_panel")
	await _frames(SETTLE_FRAMES)
	var panel: CanvasLayer = _command().call(&"panel")
	var line: Label = _label_with(panel, "Hurt: a bite (minor)")
	_check("the card says it", line != null, "" if line == null else line.text)
	if line != null:
		await _reveal(line)
		_check("its line in view", _fraction(line) >= FULL, str(line.get_global_rect()))
	_floors("the card", panel)
	_look_at(_brain(fisher).get("position"), 14.0)
	await _capture("care_hurt_card")


func _treated() -> void:
	"""At 4x: the fisher rests, the herbalist comes and treats it; said; the card says it is well."""
	var fisher: int = maxi(_index_of(&"otter_fisher"), 0)
	var herbalist: int = _index_of(Rules.HERBALIST_KEY)
	var state: RefCounted = _desk().get("state")
	var working: int = await _until(func() -> bool:
		var h: int = int(_desk().call(&"healer_of", fisher))
		return h >= 0 and _brain(h).get("task") is Tasks.Treat and (_brain(h).get("task") as Tasks.Treat).working(),
		TREAT_FRAMES)
	_check("a healer tends the fisher", working >= 0, "%d frames" % working)
	_check("the herbalist first", herbalist < 0 or int(_desk().call(&"healer_of", fisher)) == herbalist,
		str(_desk().call(&"healer_of", fisher)))
	_hold()
	var rest: Object = _brain(fisher).get("task")
	_check("no large bed: the fisher lies at its field-care spot", rest is Tasks.BedRest
		and (rest as Tasks.BedRest).where == Tasks.WHERE_FIELD and bool(_brain(fisher).get("lying")))
	_look_at(_brain(fisher).get("position"), 14.0)
	await _select(maxi(_desk().call(&"healer_of", fisher), 0))
	await _capture("care_treating")
	var done: int = await _until(func() -> bool: return not bool(state.call(&"is_hurt", fisher)), TREAT_FRAMES)
	_hold()
	_check("treated", done >= 0, "%d frames" % done)
	_check("health back up", int(state.call(&"health", fisher)) >= 90, str(state.call(&"health", fisher)))
	_check("herb and cloth paid once", int(state.get("herb_milli")) == 11000 and int(state.get("cloth_milli")) == 23500,
		"%d %d" % [state.get("herb_milli"), state.get("cloth_milli")])
	await _after_treatment(fisher, herbalist)


func _after_treatment(fisher: int, herbalist: int) -> void:
	"""Said in the news; the incident resolved once the fisher is up again; the frame."""
	var state: RefCounted = _desk().get("state")
	var notices: RefCounted = _village.get("_services").get("notices")
	_check("the treatment in the news", bool(notices.call(&"has_text", "%s treated %s's bite (herb 1 U, cloth 0.5 U): health %d"
		% [_name(herbalist), _name(fisher), int(state.call(&"health", fisher))])) or herbalist < 0)
	var incidents: RefCounted = _village.get("_services").get("incidents")
	var serial: int = int(incidents.call(&"serial_of", "care:hurt:%d" % fisher))
	await _until(func() -> bool:
		incidents.call(&"sweep")
		return int(incidents.call(&"state_of", serial)) == IncidentsScript.STATE_RESOLVED, 200)
	_hold()
	_check("its incident resolved: up again", int(incidents.call(&"state_of", serial)) == IncidentsScript.STATE_RESOLVED,
		str(incidents.call(&"state_of", serial)))
	_look_at(_brain(fisher).get("position"), 14.0)
	await _select(fisher)
	await _capture("care_treated")


func _name(who: int) -> String:
	"""Resident `who`'s name."""
	return String(_cast().call(&"actor", maxi(who, 0)).get("display_name"))


func _the_herb_patch() -> void:
	"""The herb patch by the south road, drawn on the woods' floor."""
	_look_at(Rules.HERB_PATCH_AT, 10.0)
	await _frames(SETTLE_FRAMES)
	var patch: Node3D = _care().get("patch_view")
	var camera: Camera3D = root.get_camera_3d()
	var at: Vector2 = camera.unproject_position(patch.global_position)
	_check("the herb patch is in view", Rect2(Vector2.ZERO, Vector2(_size)).has_point(at), str(at))
	await _capture("care_herb_patch")


func _the_sickbay() -> void:
	"""A home laid, dug and fitted (bed, hearth, hanging stores); selected, its section in the Tunnels panel offers to
	make it the sickbay; clicked, it is; a serious patient lies in its bed at the infirmary's rate."""
	var r: int = _lay_home()
	_check("a home laid for the sickbay", r >= 0)
	if r < 0:
		return
	var ext: Node = _command().call(&"tunnels").get("ext")
	ext.set("selected_room", r)
	ext.set("selected_room_gen", _graph().get("rooms").get("generation")[r])
	_village.get("_zone").call(&"show_panel", ZoneScript.PANEL_TUNNELS)
	ext.call(&"refresh_panel")
	_care().call(&"refresh_section")
	_look_at(_graph().get("rooms").call(&"centre_m", r), 14.0)
	await _frames(SETTLE_FRAMES)
	var section: Control = _care().get("section")
	var button: Button = section.call(&"button")
	_check("the section shows for the home", section.is_visible_in_tree())
	_check("it offers to make it the sickbay", button.text == "Make it the sickbay" and not button.disabled, button.text)
	await _reveal(button)
	_check("its button in view", _fraction(button) >= FULL, str(button.get_global_rect()))
	_floors("the Tunnels panel with the section", ext.get("panel"))
	await _capture("care_sickbay_section")
	_click(button)
	await _frames(SETTLE_FRAMES)
	_care().call(&"refresh_section")
	_check("clicked: it is the sickbay", int(_desk().get("sickbay")) == r and bool(_desk().call(&"sickbay_valid")))
	_check("the button now stops it", button.text == "Stop using it as the sickbay", button.text)
	await _sickbay_patient(r)


func _sickbay_patient(r: int) -> void:
	"""The badger takes the serious test injury and lies in a sickbay bed; there it mends at the infirmary's rate."""
	var who: int = maxi(_index_of(&"mouse_fieldworker"), 0)
	_desk().call(&"test_hurt", PackedInt32Array([who]), true)
	var lying: int = await _until(func() -> bool: return bool(_desk().get("state").call(&"in_infirmary", who)), TREAT_FRAMES)
	_hold()
	_check("the patient lies in the sickbay", lying >= 0, "%d frames" % lying)
	var rest: Object = _brain(who).get("task")
	_check("in the sickbay's bed", rest is Tasks.BedRest and (rest as Tasks.BedRest).room == r)
	_village.call(&"show_underground", true)
	_look_at(_brain(who).get("position"), 10.0)
	await _select(who)
	_check("serious and untreated in the sickbay: −4 an hour, no recovery yet",
		int(_desk().get("state").call(&"rate_per_hour", who)) == -4, str(_desk().get("state").call(&"rate_per_hour", who)))
	await _capture("care_sickbay_patient")


func _graph() -> RefCounted:
	"""The network."""
	return _cast().call(&"space").get("tunnels")


func _lay_home() -> int:
	"""Lay a burrow home by the room tool on the first legal spot round HOME_AT, finish its dig and fit a bed, the
	hearth and the hanging stores (the night suite's way); its room (-1: none laid)."""
	var control: Node = _command().call(&"tunnels")
	var tool: Object = control.get("room")
	if tool == null or not bool(control.call(&"begin_room", RoomsScript.TEMPLATE_HOME)):
		return -1
	var graph: RefCounted = _graph()
	var laid: bool = false
	for ring: int in HOME_RINGS:
		for k: int in (1 if ring == 0 else 8):
			tool.call(&"move_to", HOME_AT + Vector2.from_angle(TAU * k / 8.0) * HOME_RING_M * ring)
			if bool(tool.call(&"place", true)):
				laid = true
				break
		if laid:
			break
	control.call(&"cancel_plan")
	return _finish_home(graph) if laid else -1


func _finish_home(graph: RefCounted) -> int:
	"""The newest home dug out at once and fitted (see `_lay_home`)."""
	var rooms: RefCounted = graph.get("rooms")
	var r: int = -1
	for k: int in RoomsScript.MAX_ROOMS:
		if rooms.call(&"is_room", k) and int(rooms.get("template")[k]) == RoomsScript.TEMPLATE_HOME:
			r = k
	if r < 0:
		return -1
	var chain := PackedInt32Array()
	graph.call(&"piece_segments_into", int(rooms.get("piece")[r]), chain)
	for slot: int in chain:
		var gen: int = int(graph.get("generation")[slot])
		graph.call(&"start_dig", slot, gen, 0)
		graph.call(&"advance", slot, gen, 1000000000)
	var fit: RefCounted = graph.get("fit")
	for f: int in [0, 1, 3, 7]:
		fit.call(&"phase_of", graph, r, f)
		var phase: PackedByteArray = fit.get("phase")
		phase[r * FixturesScript.PLACES + f] = FixturesScript.INSTALLED
		fit.set("phase", phase)
	fit.set("revision", int(fit.get("revision")) + 1)
	return r
