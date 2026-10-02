extends SceneTree
## The infirmary (decisions 0622, 0623) on the REAL scene: the Demo Lab's test injury on a selected resident, the
## resident card's lines, the herbalist walking over and treating it at the field-care spot (no infirmary yet), the
## news, the herb patch drawn, and the infirmary building placed from its section in the Tunnels panel -- in view,
## clicked, placed, fetched for by the work board's residents, built -- and a serious patient resting inside it. Not
## discovered by the runner: test/test_demo_care_live.gd runs it in its own process, as the other
## live harnesses are (decisions 0261, 0391), because only an in-tree scene lays its Controls out and takes input.
##
##     godot --headless --path godot --script res://test/live/demo_care_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Once its residents have fetched some of its materials the building is finished off at once (the whole round is
## test_demo_infirmary_building.gd's). Prints `LIVE <name>: PASS|FAIL <detail>` per
## check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const Rules := preload("res://demo/infirmary/care_rules.gd")
const Tasks := preload("res://demo/infirmary/care_tasks.gd")
const ZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const Injury := preload("res://scripts/core/injury.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
const FULL: float = 0.99
## Frames allowed for the healer to arrive and treat at 4x, and for the patient to reach the infirmary.
const TREAT_FRAMES: int = 6000
## Where the infirmary is placed (m): the open ground east of the square, tried on rings round it.
const INFIRMARY_AT: Vector2 = Vector2(14.0, 8.0)
const INFIRMARY_RINGS: int = 8
const INFIRMARY_RING_M: float = 2.0

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
	await _the_infirmary()
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
	var names: PackedStringArray = []
	for k: int in int(pace.call(&"count")):
		names.append(String(pace.call(&"name_of", k)))
	_check("its health factor on the village's work pace, with the winter's Chilled (decision 0902)",
		names.has("health") and names.has("chilled"), str(names))
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
	var desk: Object = _care().get("desk")
	_check("the foragers' herb feeds the same shelf", (desk.get("pantry_herb") as Callable).is_valid())
	await _capture("care_herb_patch")


func _the_infirmary() -> void:
	"""The Tunnels panel's infirmary section offers to build it; clicked, the placing tool is armed; placed on open ground
	it stands as an obstacle; with the stores topped up the work board's residents fetch for it; built, a serious patient
	goes in and mends at the infirmary's rate."""
	var ext: Node = _command().call(&"tunnels").get("ext")
	_village.get("_zone").call(&"show_panel", ZoneScript.PANEL_TUNNELS)
	ext.call(&"refresh_panel")
	_care().call(&"refresh_section")
	await _frames(SETTLE_FRAMES)
	var section: Control = _care().get("section")
	var button: Button = section.call(&"button")
	_check("the section shows in the Tunnels panel", section.is_visible_in_tree())
	_check("it offers to build the infirmary", button.text == "Build the infirmary…" and not button.disabled, button.text)
	await _reveal(button)
	_check("its button in view", _fraction(button) >= FULL, str(button.get_global_rect()))
	_floors("the Tunnels panel with the section", ext.get("panel"))
	await _capture("care_infirmary_section")
	_click(button)
	await _frames(SETTLE_FRAMES)
	var building: Node = _care().get("building")
	var place: Node = building.get("place")
	_check("clicked: the placing tool is armed", bool(place.get("armed")))
	var at: Vector2 = _placed(place)
	_check("placed on open ground", at.is_finite(), str(at))
	if not at.is_finite():
		return
	await _being_built(building, at)
	await _patient_inside(building, at)


func _placed(place: Node) -> Vector2:
	"""Move the ghost over rings round INFIRMARY_AT until a spot is allowed, and place it there (INF: none)."""
	for ring: int in INFIRMARY_RINGS:
		for k: int in (1 if ring == 0 else 8):
			var at: Vector2 = INFIRMARY_AT + Vector2.from_angle(TAU * k / 8.0) * INFIRMARY_RING_M * ring
			place.call(&"move_to", at)
			if String(place.get("refusal")).is_empty() and bool(place.call(&"place")):
				return at
	return Vector2.INF


func _being_built(building: Node, at: Vector2) -> void:
	"""Placed: an obstacle; the stores topped up, the board's residents fetch for it at 4x; then it is finished off (the
	whole round is the unit suite's) and stands built."""
	var project: RefCounted = building.get("project")
	await _frames(2)
	_check("an obstacle once placed", (_cast().call(&"space").call(&"structure_circles") as PackedVector3Array).size() == 1)
	var stores: RefCounted = _village.get("_services").get("stores")
	stores.set("wood_milli_u", 200000)
	stores.set("stone_milli_u", 200000)
	var fetched: int = await _until(func() -> bool:
		var got: int = 0
		for m: int in 3:
			got += int((project.get("delivered") as PackedInt64Array)[m])
		return got > 0, 9000)
	_hold()
	_check("the board's residents fetch its materials", fetched >= 0, "%d frames" % fetched)
	_look_at(at, 16.0)
	await _capture("care_infirmary_building")
	building.get("builders").call(&"release_all")
	for m: int in 3:
		var need: int = int(project.call(&"outstanding", m))
		project.call(&"reserve", m, need)
		project.call(&"deliver", m, project.call(&"lift", m, need))
	project.call(&"add_work", 1 << 40)
	await _frames(SETTLE_FRAMES)
	_check("built", bool(project.call(&"is_done")), str(project.get("state")))
	_care().call(&"refresh_section")
	var button: Button = _care().get("section").call(&"button")
	_check("the section says it is built", button.text == "The infirmary is built" and button.disabled, button.text)


func _patient_inside(building: Node, at: Vector2) -> void:
	"""A serious patient goes in and rests there at the infirmary's rate."""
	var who: int = maxi(_index_of(&"mouse_fieldworker"), 0)
	_desk().call(&"test_hurt", PackedInt32Array([who]), true)
	var inside: int = await _until(func() -> bool: return bool(_desk().get("state").call(&"in_infirmary", who)), TREAT_FRAMES)
	_hold()
	_check("the patient rests inside the infirmary", inside >= 0, "%d frames" % inside)
	_check("it has a bed there", bool(building.get("project").call(&"is_admitted", who)))
	_look_at(at, 16.0)
	await _select(who)
	var line: Label = _label_with(_command().call(&"panel"), "Resting in the infirmary")
	_check("its card says so", line != null)
	await _capture("care_infirmary_patient")
