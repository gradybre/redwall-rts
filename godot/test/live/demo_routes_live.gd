extends SceneTree
## The route and infrastructure previews on the REAL scene (decision 0461; review P5, ECO-039, ECO-045). Not discovered
## by the runner: test/test_demo_routes_live.gd runs it in its own process, as the layout and input harnesses are
## (decisions 0261, 0391), because only an in-tree village has its desk's budget, its panels and its incident card.
##
##     godot --headless --path godot --script res://test/live/demo_routes_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Paused as the player pauses (estimates are worked paused too: the desk serves every frame), it checks: the Water
## panel's site -- the shortage and its source button, the Build shown only when it commits, the benefit worked one
## step a frame from "calculating…" to times; the source button bringing the Woods forward; the Routes layer with nobody
## selected (the public ways and the promise that nobody is made to swim) and with a group (each member's own words);
## a tunnel laid in the Dig tool (its benefit if dug) and then dug (its stages and next payoff); and a rescue's card
## (phase, time or blockage, Victim / Responder / Landing that select and centre, the same while paused). Prints
## `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const ZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const WaterPanel := preload("res://demo/waterplay/water_panel.gd")
## demo_routes.gd SOURCE_CAPTIONS[SOURCE_SAW] (not preloaded: its command layer needs the autoloads, which a --script
## main script is compiled before).
const SAW_CAPTION: String = "Saw planks ▸"
const TextScript := preload("res://demo/routes/route_text.gd")
const SubjectScript := preload("res://demo/routes/routes_subject.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const BOOT_FRAMES: int = 14
## On the pond's west shore, a few metres from the water (the pond_west landing's land side, water_layout.gd).
const POND_BANK: Vector2 = Vector2(19.0, 29.8)
const SETTLE_FRAMES: int = 4
## An estimate is a few steps, one a frame; it must finish well inside this.
const ESTIMATE_FRAMES: int = 120
## Candidate tunnels for the Dig tool (start, end, metres), the first the plan takes is laid.
const DIG_ROUTES: Array[Vector4] = [Vector4(-8.0, 4.5, -8.0, -3.0), Vector4(-16.5, 0.0, -16.5, 8.0),
	Vector4(6.0, 9.5, -2.0, 9.5), Vector4(17.0, -10.0, 17.0, -2.0)]

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
	"""Wait `count` frames, holding the window size and keeping a slow read-back from tripping the overload pause."""
	for k: int in count:
		if root.size != _size:
			root.size = _size
		_manager().set("_last_host_usec", Time.get_ticks_usec())
		await process_frame


func _run() -> void:
	"""Every step, then the summary."""
	await _frames(BOOT_FRAMES)
	_manager().call(&"pause_game")
	await _water_site()
	await _source_link()
	await _bridge_lifecycle()
	await _routes_public()
	await _routes_group()
	await _tunnel_project()
	await _rescue_card()
	var routes: Node = _routes()
	print("MEASURE longest step: bridge %d us, dig %d us, public %d us, shortcut %d us; %d steps refused" % [
		routes.bridge_estimate.max_step_usec, routes.dig_estimate.max_step_usec, routes.public_estimate.max_step_usec,
		routes.shortcut_estimate.max_step_usec, routes.bridge_estimate.steps_refused + routes.dig_estimate.steps_refused
		+ routes.public_estimate.steps_refused + routes.shortcut_estimate.steps_refused])
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail.replace("\n", " | ")])


func _capture(file_name: String) -> void:
	"""Save the frame once what was just set is drawn (only when asked for, and never headless)."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(3)
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [file_name, _size.x, _size.y]))
	_manager().set("_last_host_usec", Time.get_ticks_usec())


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _command() -> Node:
	"""The command layer."""
	return _village.get("_command")


func _water() -> Node:
	"""The water's gameplay."""
	return _village.get("_waterplay")


func _routes() -> Node:
	"""The previews."""
	return _village.call(&"routes")


func _until(done: Callable, frames: int) -> int:
	"""Wait until `done()` (at most `frames` frames); the frames it took (-1: never)."""
	for k: int in frames:
		if bool(done.call()):
			return k
		await _frames(1)
	return -1 if not bool(done.call()) else frames


# --- the Water panel's site ---------------------------------------------------------------------------

func _water_site() -> void:
	"""Resident 0 selected, the Water panel on the neck: the shortage, the Builds, the benefit worked to times."""
	_command().call(&"select", PackedInt32Array([0]))
	_village.get("_zone").call(&"show_panel", ZoneScript.PANEL_WATER)
	_water().call(&"refresh_panel")
	await _frames(SETTLE_FRAMES)
	var panel: CanvasLayer = _water().get("panel")
	var project: String = panel.call(&"line", &"project")
	_check("site: the plank shortage said", project.contains("Plank footbridge: missing") and project.contains("planks"), project)
	var source: Button = panel.call(&"button", WaterPanel.ACTION_SOURCE)
	_check("site: the source button leads to the saw", source.is_visible_in_tree() and source.text == SAW_CAPTION, source.text)
	var plank: Button = panel.call(&"button", WaterPanel.ACTION_BUILD_PLANK)
	var log: Button = panel.call(&"button", WaterPanel.ACTION_BUILD_LOG)
	_check("site: no Build for the footbridge it can't pay for", not plank.visible and log.visible, "plank %s, log %s" % [plank.visible, log.visible])
	var steps: int = _routes().steps
	var took: int = await _until(func() -> bool:
		_water().call(&"refresh_panel")
		return not String(panel.call(&"line", &"routes")).contains(TextScript.CALCULATING), ESTIMATE_FRAMES)
	var benefit: String = panel.call(&"line", &"routes")
	_check("site: the benefit worked to times", took >= 0 and benefit.contains(": now ") and benefit.contains(", after ") and benefit.contains("Estimate:"), "%d frames: %s" % [took, benefit])
	_check("site: one estimate step a frame at most", _routes().steps - steps <= took + 1, "%d steps in %d frames" % [_routes().steps - steps, took])
	_check("site: who can use it and the cost", benefit.contains(TextScript.BRIDGE_WHO) and benefit.contains("Cost ("), benefit)
	_reveal(panel, panel.call(&"button", WaterPanel.ACTION_SOURCE))
	await _capture("routes_water_site")


func _source_link() -> void:
	"""The source button: no saw task queued, so the Woods panel comes forward -- and nothing is ordered."""
	var panel: CanvasLayer = _water().get("panel")
	var board: Object = _village.call(&"work").get("board")
	(panel.call(&"button", WaterPanel.ACTION_SOURCE) as Button).pressed.emit()
	await _frames(SETTLE_FRAMES)
	_check("source: the Woods panel brought forward", int(_village.get("_zone").get("shown")) == ZoneScript.PANEL_WOODS)
	_check("source: nothing ordered", _routes().saw_task_row() < 0)
	await _capture("routes_source_woods")
	_village.get("_zone").call(&"show_panel", ZoneScript.PANEL_WATER)


func _bridge_lifecycle() -> void:
	"""A log bridge built at the site: planned, its materials paid and where they are, its task on the Work screen;
	opened, its route and condition and no construction controls."""
	var water: Node = _water()
	var panel: CanvasLayer = water.get("panel")
	print(water.call(&"build", 1, PackedInt32Array([0])))
	water.call(&"refresh_panel")
	await _frames(SETTLE_FRAMES)
	var project: String = panel.call(&"line", &"project")
	_check("bridge: planned, materials paid and where", project.begins_with("Materials: a 6.0 U log") and project.contains("nothing missing"), project)
	var source: Button = panel.call(&"button", WaterPanel.ACTION_SOURCE)
	_check("bridge: its task on the Work screen", source.is_visible_in_tree() and source.text.begins_with("Bridge task"), source.text)
	_reveal(panel, source)
	await _capture("routes_bridge_planned")
	source.pressed.emit()
	await _frames(SETTLE_FRAMES)
	var screen: CanvasLayer = _village.call(&"work").get("screen")
	_check("bridge: the Work screen opened on its tasks", screen.visible)
	await _capture("routes_bridge_task")
	screen.call(&"close")
	await _estimate_while_building(water, panel)
	water.call(&"refresh_panel")
	await _frames(SETTLE_FRAMES)
	project = panel.call(&"line", &"project")
	var builds: bool = (panel.call(&"button", WaterPanel.ACTION_BUILD_PLANK) as Button).visible \
		or (panel.call(&"button", WaterPanel.ACTION_BUILD_LOG) as Button).visible
	_check("bridge: open, its route and condition", project.begins_with("Route across:") and project.contains("Condition:"), project)
	_check("bridge: no construction controls once open", not builds and not source.is_visible_in_tree())
	await _until(func() -> bool:
		water.call(&"refresh_panel")
		return not String(panel.call(&"line", &"project")).contains(TextScript.CALCULATING), ESTIMATE_FRAMES)
	_reveal(panel, panel.call(&"button", WaterPanel.ACTION_NEXT_SITE))
	await _capture("routes_bridge_open")


func _wide_view(at: Vector3, distance: float) -> void:
	"""Frame the layer from further out (the frames only: the camera's own target distance, then snapped)."""
	var rig: Node = _village.get("_camera")
	rig.set("_target_distance", distance)
	rig.call(&"centre_on", at)
	rig.call(&"snap")


func _estimate_while_building(water: Node, panel: CanvasLayer) -> void:
	"""Unpaused at 4x while the bridge is built: the third site's benefit (the second's footings are blocked) still
	finishes; the bridge's work (which moves the bridges' revision ten times a second) does not start it again, its
	opening does -- the crew's finish bumps no crossings revision, so the controller's own key must (review H1). Leaves
	the bridge open."""
	water.call(&"select_candidate", 2)
	water.call(&"refresh_panel")
	_manager().call(&"resume_game")
	_manager().call(&"set_speed", 4)
	var took: int = await _until(func() -> bool:
		water.call(&"refresh_panel")
		return not String(panel.call(&"line", &"routes")).contains(TextScript.CALCULATING), 2 * ESTIMATE_FRAMES)
	_manager().call(&"set_speed", 1)
	_manager().call(&"pause_game")
	var benefit: String = panel.call(&"line", &"routes")
	_check("bridge: estimates finish while a bridge is built", took >= 0 and benefit.contains("far bank"), "%d frames: %s" % [took, benefit])
	var estimate: Object = _routes().get("bridge_estimate")
	var bridges: Object = water.get("bridges")
	var row: int = _bridge_row(bridges)
	var restarts: int = int(estimate.get("restarts"))
	for k: int in 6:
		bridges.call(&"add_work", row, 1)
		water.call(&"refresh_panel")
		await _frames(1)
	_check("bridge: its work does not start an estimate again", int(estimate.get("restarts")) == restarts,
		"%d restarts" % (int(estimate.get("restarts")) - restarts))
	for stage: int in 3:
		bridges.call(&"add_work", row, int(bridges.call(&"stage_left_wu", row, stage)))
	water.call(&"refresh_panel")
	_check("bridge: its opening does", int(estimate.get("restarts")) == restarts + 1 and bool(bridges.call(&"is_open", row)),
		"%d restarts" % (int(estimate.get("restarts")) - restarts))
	water.call(&"select_candidate", 0)
	water.call(&"refresh_panel")
	await _frames(SETTLE_FRAMES)


func _reveal(panel: CanvasLayer, control: Control) -> void:
	"""Scroll the Water panel's sections so `control` is in view (for the frames)."""
	(panel.call(&"sections") as ScrollContainer).ensure_control_visible(control)


func _bridge_row(bridges: Object) -> int:
	"""The first bridge row planned or open (-1: none)."""
	for row: int in 6:
		if int((bridges.get("phase") as PackedByteArray)[row]) != 0:
			return row
	return -1


# --- the Routes layer -------------------------------------------------------------------------------------

func _lenses() -> Object:
	"""The map layers."""
	return _village.get("_farm").get("lenses")


func _routes_public() -> void:
	"""Nobody selected, the Routes layer on: the public ways worked and labelled, the promise in the notes."""
	_command().call(&"clear_selection")
	var lens: int = int(_village.get("_routes_lens"))
	_lenses().call(&"select", lens)
	await _frames(SETTLE_FRAMES)
	var routes: Node = _routes()
	_check("layer: the Routes layer shown", routes.overlay.is_shown())
	var steps: int = int(routes.get("steps"))
	var took: int = await _until(func() -> bool: return routes.public_estimate.is_done() and routes.shortcut_estimate.is_done(), 4 * ESTIMATE_FRAMES)
	var stepped: int = int(routes.get("steps")) - steps
	await _until(func() -> bool: return routes.overlay.label_texts().size() >= 6, 60)
	var labels: PackedStringArray = routes.overlay.label_texts()
	_check("layer: the public ways worked", took >= 0, "%d frames" % took)
	_check("layer: one estimate step a frame across both", stepped <= took + 1, "%d steps in %d frames" % [stepped, took])
	var desk: Object = _village.get("_cast").call(&"space").get("routes")
	print("MEASURE public ways: %d steps, longest %d us, %d us; the desk's longest window %d us, its estimate %d us" % [
		stepped, routes.public_estimate.max_step_usec, routes.shortcut_estimate.max_step_usec,
		int(desk.get("max_window_usec")), int(desk.get("estimate_usec"))])
	_check("layer: every work district's public way labelled", labels.size() >= 6 and labels[0].begins_with("To ") and labels[0].contains("carrying"), str(labels.size()))
	_check("layer: nobody is made to swim (the notes)", routes.subject.notes().contains("nobody is made to swim"), routes.subject.notes())
	_wide_view(Vector3(10.0, 0.0, -4.0), 52.0)
	await _frames(20)
	await _capture("routes_public_ways")


func _routes_group() -> void:
	"""Three selected and sent across to the far bank: each member's own words in the layer's notes."""
	var routes: Node = _routes()
	_command().call(&"select", PackedInt32Array([0, 1, 2]))
	_manager().call(&"resume_game")
	_command().call(&"order_to", Vector3(30.0, 0.0, -1.0))
	await _frames(30)
	_manager().call(&"pause_game")
	await _frames(SETTLE_FRAMES + 8)
	var notes: String = routes.subject.notes()
	_check("layer: each member its own line", notes.split("\n").size() == 3, notes)
	_check("layer: the subject is the group", routes.subject.subject_line() == SubjectScript.GROUP % 3, routes.subject.subject_line())
	_check("layer: the routes drawn", routes.overlay.rebuilds > 0)
	_wide_view(Vector3(14.0, 0.0, -2.0), 40.0)
	await _frames(20)
	await _capture("routes_group")
	_lenses().call(&"select", 0)


# --- the Tunnels panel's project ----------------------------------------------------------------------------

func _tunnel_project() -> void:
	"""A tunnel laid in the Dig tool: its benefit if dug; then dug: its stages and next payoff."""
	var tool: Node = _command().call(&"tunnels")
	_command().call(&"select", PackedInt32Array([0]))
	_village.get("_zone").call(&"show_panel", ZoneScript.PANEL_TUNNELS)
	var laid: bool = await _lay_a_tunnel(tool)
	_check("dig: a tunnel laid", laid)
	if not laid:
		return
	var ext: Node = tool.get("ext")
	var took: int = await _until(func() -> bool:
		ext.call(&"refresh_panel")
		var text: String = ext.get("panel").call(&"line", &"project")
		return text.begins_with("If this piece is dug") and not text.contains(TextScript.CALCULATING), ESTIMATE_FRAMES)
	var text: String = ext.get("panel").call(&"line", &"project")
	_check("dig: its benefit if dug", took >= 0 and text.contains("one end to the other"), text)
	await _capture("routes_dig_laid")
	_check("dig: dug", bool(tool.call(&"confirm")))
	await _frames(SETTLE_FRAMES)
	ext.call(&"refresh_panel")
	text = ext.get("panel").call(&"line", &"project")
	_check("dig: its stages and next payoff", text.begins_with("Project:") and text.contains("Stage 1 of") and text.contains("Next payoff"), text)
	await _capture("routes_dig_project")
	tool.call(&"cancel_plan")


func _lay_a_tunnel(tool: Node) -> bool:
	"""Lay the first candidate tunnel the plan takes (start and end clicked on the ground)."""
	for route: Vector4 in DIG_ROUTES:
		if not bool(tool.get("planning")):
			tool.call(&"begin_plan")
		await _frames(2)
		tool.call(&"lay_ground", Vector2(route.x, route.y))
		tool.call(&"lay_ground", Vector2(route.z, route.w))
		await _frames(2)
		if int(tool.get("plan").get("count")) >= 2 and int(tool.call(&"laid_piece_reason")) == Rules.REFUSE_NONE:
			return true
		tool.get("plan").call(&"clear")
	return false


# --- the rescue card ------------------------------------------------------------------------------------------

func _rescue_card() -> void:
	"""A swimmer cramps in the pond: its card's phase, time or blockage and its three targets; Victim selects it; the
	same while paused."""
	var water: Node = _water()
	var who: int = _swimmer()
	_check("rescue: a swimmer to cramp (made one on placeholders)", who >= 0)
	if who < 0:
		return
	var brain: Object = water.call(&"brain_of", who)
	brain.call(&"release_slot")
	brain.call(&"start_at", POND_BANK, 0.0, -1, -1)
	_manager().call(&"resume_game")
	_manager().call(&"set_speed", 4)
	print(water.call(&"order_swim", PackedInt32Array([who]), water.call(&"pond_dive_spot") + Vector2(-2.0, 0.0)))
	var swam: int = await _until(func() -> bool: return bool(brain.get("in_water")), 4000)
	_manager().call(&"set_speed", 1)
	_check("rescue: in the water", swam >= 0, "%d frames" % swam)
	water.call(&"cramp", PackedInt32Array([who]))
	water.call(&"sync_incidents")
	await _frames(SETTLE_FRAMES)
	_manager().call(&"pause_game")
	var cards: CanvasLayer = _village.call(&"incident_cards")
	cards.call(&"refresh")
	var details: String = cards.call(&"details_text")
	var targets: PackedStringArray = cards.call(&"target_labels")
	_check("rescue: the card's phase and time or blockage", details.split(" · ").size() >= 2, details)
	_check("rescue: Victim, Responder or Landing to go to", targets.size() >= 2 and targets[0].begins_with("Victim"), str(targets))
	await _capture("routes_rescue_card")
	_command().call(&"clear_selection")
	_check("rescue: Victim selects the victim", bool(cards.call(&"go_to_target", 0)) and _command().call(&"selected") == PackedInt32Array([who]))
	var responder: int = int(water.get("rescue").call(&"victim_task", who).get("responder"))
	_check("rescue: Responder selects the responder", bool(cards.call(&"go_to_target", 1)) and _command().call(&"selected") == PackedInt32Array([responder]),
		"responder %d" % responder)
	await _frames(30)
	cards.call(&"refresh")
	_check("rescue: the same while paused", cards.call(&"details_text") == details, cards.call(&"details_text"))


func _swimmer() -> int:
	"""The village's first resident who swims -- on placeholders (no staged assets, nobody swims) resident 0 is made a
	0.60 m/s swimmer, as the water suite's rig does (-1: no resident at all)."""
	var state: Object = _water().get("state")
	var speeds: PackedInt32Array = state.get("swim_mm_s")
	for who: int in speeds.size():
		if speeds[who] > 0:
			return who
	if speeds.is_empty():
		return -1
	speeds[0] = 600
	state.set("swim_mm_s", speeds)
	return 0
