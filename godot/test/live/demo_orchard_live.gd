extends SceneTree
## The orchard on the REAL scene with REAL Viewport input (decisions 0671-0677): a left click on the old apple brings
## the tab-less Orchard panel into the right column (inside the window, no tab lit); its verbs and their cards; the Tend
## button and a right click on the pear give the selected residents the work; a tab takes the zone back; the work board
## lists the orchard's jobs; the grove stops the woods felling; the fruit trees wear the season; and a resident tends the
## apple in game time. Decision 1721 (its steps after the tending, so they never share that check's clock): a
## sapling's Move button orders the move and it is replanted in game time; a built
## cart stands by the east baskets; the beech hollow's stone selects the second grove; the Woods panel's Foraging section
## has its Kit and Lead and its card says home by dusk. Not discovered by the runner: test/test_demo_orchard_live.gd
## runs it in its own process.
##
##     godot --headless --path godot --script res://test/live/demo_orchard_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on a failure.

const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const Rules := preload("res://demo/orchard/orchard_rules.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const LookScript := preload("res://demo/seasons/season_look.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const ForestCrew := preload("res://demo/forestry/forest_crew.gd")
const ForestStand := preload("res://demo/forestry/forest_stand.gd")

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 3
## How many frames the tending may take in game time at 4x (bounded: the walk is ~30 m, the work 20 WU).
const TEND_FRAMES: int = 2400
## And the move (decision 1721: 20 WU, a short carry, 40 WU).
const MOVE_FRAMES: int = 4800
## The sapling planted for the move, and its new site (orchard_rules.gd: east site 1 to east site 2).
const MOVE_FROM: int = 2
const MOVE_TO: int = 3

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _pending_capture: String = ""
var _tend_frames: int = 0
var _move_frames: int = 0
var _mover: int = 0


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and list the steps."""
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
	_steps = [_pause, _the_orchard_is_wired, _look_at_the_old_orchard, _click_the_old_apple, _its_verbs_and_cards,
		_tend_with_a_resident_selected, _right_click_the_pear, _a_tab_takes_the_zone_back, _the_board_lists_the_jobs,
		_the_grove_stops_the_felling, _the_trees_wear_the_season, _run_at_4x, _the_apple_is_tended,
		_pause, _build_the_east_cart, _plant_the_sapling, _look_at_the_east_orchard, _the_cart_stands_by_the_baskets,
		_click_the_sapling, _scroll_to_move, _press_move, _resume_at_4x, _wait_for_the_move, _the_sapling_is_moved, _pause,
		_look_at_the_beech_hollow, _click_the_beech_stone, _the_foraging_outing]


func _process(_delta: float) -> bool:
	"""One step each time the wait runs out; quit after the last (the root's size held: decision 0261's note)."""
	if root.size != _size:
		root.size = _size
	_wait -= 1
	if _wait > 0:
		return false
	if not _pending_capture.is_empty():
		_save_capture()
	if _steps.is_empty():
		print("LIVE-SUMMARY %d %d" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return false
	var step: Callable = _steps.pop_front()
	step.call()
	_wait = STEP_FRAMES
	return false


func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %s: %s %s" % [check_name, "PASS" if ok else "FAIL", detail])


func _click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	"""A click at `at` with `button`."""
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = at
		event.pressed = down
		event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if down else 0
		root.push_input(event)


func _centre(control: Control) -> Vector2:
	"""A control's centre on screen."""
	return control.get_global_transform_with_canvas() * (control.size / 2.0)


func _capture(file_name: String) -> void:
	"""Save this state's frame at the next step (only with --capture, never headless)."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		_pending_capture = file_name


func _save_capture() -> void:
	"""Write the pending frame, and forgive the clock the read-back's time (docs/ENVIRONMENT.md's stall note)."""
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_pending_capture = ""
	root.get_node(^"GameManager").set("_last_host_usec", Time.get_ticks_usec())


func _orchard() -> Node:
	"""The village's orchard."""
	return _village.call(&"orchard")


func _zone() -> DetailZone:
	"""The right column."""
	return _village.get("_zone")


func _screen_of(at: Vector2, height: float) -> Vector2:
	"""Where a ground point `height` m up is on screen."""
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	return camera.unproject_position(Vector3(at.x, height, at.y))


func _fits(rect: Rect2) -> bool:
	"""Whether a rectangle lies inside the window."""
	return Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0).encloses(rect)


# --- the steps ----------------------------------------------------------------------------------------------------------

func _pause() -> void:
	"""Pause as the player (orders are carried out on resume)."""
	root.get_node(^"GameManager").call(&"pause_game")


func _the_orchard_is_wired() -> void:
	"""The node, its stands among the pantry's stores, its trees as real rows."""
	_check("the orchard is built", _orchard() != null)
	var storage: RefCounted = _village.get("_farm").get("pantry").get("storage")
	var read := preload("res://scripts/core/int_math.gd").IntResult.new()
	_check("its stands are pantry stores", storage.call(&"index_of_id_into", Rules.STAND_IDS[0], read) \
		and bool(storage.call(&"is_staging", read.value)))
	_check("the old trees are real rows", int(_orchard().get("model").get("store").call(&"orchard_count")) == 2)


func _look_at_the_old_orchard() -> void:
	"""The camera over the old orchard from the north."""
	var camera: Node = _village.get("_camera")
	camera.set("_target_focus", Vector3(-12.0, 0.0, 30.0))
	camera.set("_target_distance", 24.0)
	camera.set("_target_pitch", deg_to_rad(48.0))
	camera.set("_target_yaw", deg_to_rad(180.0))
	camera.call(&"snap")


func _click_the_old_apple() -> void:
	"""A left click on the apple's trunk: selected, the Orchard panel in the right column, inside the window, no tab lit."""
	_click(_screen_of(Rules.site_centre_m(0), 0.3))
	var panel: CanvasLayer = _orchard().get("panel")
	_check("a click on the apple selects it", int(_orchard().get("selected_kind")) == 1 and int(_orchard().get("selected_id")) == 0,
		"%s %s" % [_orchard().get("selected_kind"), _orchard().get("selected_id")])
	_check("the Orchard panel is shown", bool(panel.call(&"is_shown")))
	_check("it holds the right column", _zone().shown == DetailZone.PANEL_ORCHARD)
	var lit: bool = false
	for k: int in 4:
		lit = lit or _zone().tab(k).button_pressed
	_check("no tab is lit", not lit)
	_check("the panel fits the window", _fits(panel.call(&"frame_rect")), str(panel.call(&"frame_rect")))
	_capture("orchard_panel")


func _its_verbs_and_cards() -> void:
	"""Tend and Harvest shown; in spring Tend may be pressed and Harvest says why not."""
	var panel: CanvasLayer = _orchard().get("panel")
	_orchard().call(&"refresh_panel")
	_check("the panel names the tree", String(panel.call(&"line", &"title")) == "The old apple", panel.call(&"line", &"title"))
	var tend: Button = panel.call(&"button", &"tend")
	var harvest: Button = panel.call(&"button", &"harvest")
	_check("Tend may be pressed", tend.visible and not tend.disabled)
	_check("Harvest is refused in spring", harvest.visible and harvest.disabled)
	_check("its card says why", harvest.tooltip_text.contains("Can't now"), harvest.tooltip_text)


func _tend_with_a_resident_selected() -> void:
	"""Resident 0 selected, the Tend button clicked: the tending is hers."""
	_village.get("_command").call(&"select", PackedInt32Array([0]))
	_orchard().call(&"refresh_panel")
	var tend: Button = _orchard().get("panel").call(&"button", &"tend")
	_click(_centre(tend))
	var jobs: RefCounted = _orchard().get("jobs")
	var j: int = int(jobs.call(&"find", JobsScript.K_TEND, 0))
	_check("Tend orders the selected resident", j >= 0 and int(jobs.get("worker")[j]) == 0, "job %d" % j)


func _right_click_the_pear() -> void:
	"""Resident 1 selected, a right click on the pear: its most pressing work (spring: tending) is hers."""
	_village.get("_command").call(&"select", PackedInt32Array([1]))
	_click(_screen_of(Rules.site_centre_m(1), 0.3), MOUSE_BUTTON_RIGHT)
	var jobs: RefCounted = _orchard().get("jobs")
	var j: int = int(jobs.call(&"find", JobsScript.K_TEND, 1))
	_check("a right click gives her the pear's tending", j >= 0 and int(jobs.get("worker")[j]) == 1, "job %d" % j)
	_check("the selection follows the click", int(_orchard().get("selected_id")) == 1)


func _a_tab_takes_the_zone_back() -> void:
	"""The Woods tab clicked: the Orchard panel goes, the woods' comes."""
	_click(_centre(_zone().tab(DetailZone.PANEL_WOODS)))
	_check("the Woods tab takes the zone", _zone().shown == DetailZone.PANEL_WOODS)
	_check("the Orchard panel is hidden", not bool(_orchard().get("panel").call(&"is_shown")))


func _the_board_lists_the_jobs() -> void:
	"""The work board's source 11 is the orchard's, with its jobs."""
	var board: RefCounted = _village.get("_work").get("board")
	var source: RefCounted = board.call(&"source", WorkIds.SOURCE_ORCHARD)
	_check("the board has the orchard's source", source != null)
	var live: int = 0
	for row: int in JobsScript.MAX_JOBS:
		live += 1 if source != null and bool(source.call(&"live", row)) else 0
	_check("its jobs are listed", live >= 2, "%d" % live)


func _the_grove_stops_the_felling() -> void:
	"""A mature woods tree in the protected grove: a fell is refused."""
	var forestry: Node = _village.get("_forestry")
	var stand: RefCounted = forestry.get("stand")
	var refused: int = 0
	for t: int in int(stand.call(&"count")):
		var at: Vector2 = stand.get("at")[t]
		if at.distance_to(Rules.GROVE_AT) <= Rules.GROVE_RADIUS_M and int(stand.call(&"state_of", t)) == ForestStand.STATE_MATURE:
			var code: String = forestry.get("crew").call(&"refusal_for", ForestJobs.KIND_FELL, t, 0)
			refused += 1 if code == ForestCrew.REFUSE_GROVE else 0
	_check("the grove's trees are never felled", refused >= 1, "%d refused" % refused)


func _the_trees_wear_the_season() -> void:
	"""The fruit trees are among the season's trees (staged: their meshes dressed as KIND_FRUIT)."""
	var seasons: Node = _village.call(&"seasons")
	var fruit: int = 0
	for i: int in int(seasons.call(&"dressed_count")):
		fruit += 1 if int(seasons.call(&"kind_of", i)) == LookScript.KIND_FRUIT else 0
	var staged: bool = ResourceLoader.exists("res://demo/assets/world/oak_mature.glb")
	_check("the fruit trees wear the season", fruit >= 4 or not staged, "%d fruit meshes" % fruit)


func _run_at_4x() -> void:
	"""Resume at 4x."""
	root.get_node(^"GameManager").call(&"resume_game")
	root.get_node(^"GameManager").call(&"set_speed", 4)
	_steps.push_front(_wait_for_tending)


func _wait_for_tending() -> void:
	"""Run until the apple is tended (bounded)."""
	root.get_node(^"GameManager").call(&"acknowledge_overload")
	_tend_frames += STEP_FRAMES
	if not bool(_orchard().get("model").call(&"tended_today", 0)) and _tend_frames < TEND_FRAMES:
		_steps.push_front(_wait_for_tending)


func _the_apple_is_tended() -> void:
	"""The selected resident walked to the apple and did its 20 WU."""
	_check("the apple is tended in game time", bool(_orchard().get("model").call(&"tended_today", 0)),
		"after %d frames" % _tend_frames)


# --- decision 1721: the move, the cart, the second grove and the outing ------------------------------------------------

func _build_the_east_cart() -> void:
	"""The east orchard's cart built (its building is the suite's: test_demo_orchard_remainders.gd)."""
	_check("the east orchard's cart is built", bool(_orchard().get("model").call(&"add_cart", 1)))


func _plant_the_sapling() -> void:
	"""Compost for the move, and a free apple sapling planted on east site 1 today."""
	_village.get("_farm").get("sim").set("compost_milli", 20000)
	var model: RefCounted = _orchard().get("model")
	var today: int = int(model.get("today_hint"))
	_check("a sapling is planted", bool(model.call(&"take_sapling", MOVE_FROM, Rules.APPLE, false)) \
		and bool(model.call(&"plant", MOVE_FROM, Rules.APPLE, today)))


func _look_at_the_east_orchard() -> void:
	"""The camera over the east orchard and its baskets from the north, east site 1 in the middle (clear of the lens
	picker's panel, which sits below the middle)."""
	var camera: Node = _village.get("_camera")
	var site: Vector2 = Rules.site_centre_m(MOVE_FROM)
	camera.set("_target_focus", Vector3(site.x, 0.0, site.y))
	camera.set("_target_distance", 20.0)
	camera.set("_target_pitch", deg_to_rad(50.0))
	camera.set("_target_yaw", deg_to_rad(180.0))
	camera.call(&"snap")


func _click_the_sapling() -> void:
	"""A click on the sapling (nobody selected), then a resident with no orchard job selected: its Move sapling button
	may be pressed, and its card names the new site."""
	_village.get("_command").call(&"select", PackedInt32Array())
	_click(_screen_of(Rules.site_centre_m(MOVE_FROM), 0.2))
	_check("a click selects the sapling", int(_orchard().get("selected_id")) == MOVE_FROM, str(_orchard().get("selected_id")))
	_mover = _free_resident()
	_village.get("_command").call(&"select", PackedInt32Array([_mover]))
	_orchard().call(&"refresh_panel")
	var move: Button = _orchard().get("panel").call(&"button", &"move")
	_check("Move sapling may be pressed", move.visible and not move.disabled, move.tooltip_text)
	_check("its card names the new site", move.tooltip_text.replace("\n  ", " ").contains("east site 2"), move.tooltip_text)
	_capture("orchard_move_panel")


func _scroll_to_move() -> void:
	"""The panel scrolled to its Move sapling button, as a player scrolls at 1280x720 (the panel scrolls inside a short
	zone): the button inside the panel's frame."""
	var panel: CanvasLayer = _orchard().get("panel")
	var move: Button = panel.call(&"button", &"move")
	(panel.get("_body") as ScrollContainer).ensure_control_visible(move)


func _press_move() -> void:
	"""The Move sapling button, scrolled into the panel's frame, pressed: the move is the selected resident's, east site 2
	spoken for."""
	var mover: int = _mover
	var panel: CanvasLayer = _orchard().get("panel")
	var move: Button = panel.call(&"button", &"move")
	_check("the Move button is in view", Rect2(panel.call(&"frame_rect")).encloses(move.get_global_rect()),
		"%s in %s" % [move.get_global_rect(), panel.call(&"frame_rect")])
	_click(_centre(move))
	var jobs: RefCounted = _orchard().get("jobs")
	var j: int = int(jobs.call(&"find", JobsScript.K_MOVE, MOVE_FROM))
	_check("Move orders the selected resident", j >= 0 and int(jobs.get("worker")[j]) == mover, "mover %d job %d worker %s why '%s'" % [mover,
		j, jobs.get("worker")[j] if j >= 0 else -1, jobs.call(&"eligibility", j, mover) if j >= 0 else ""])
	_check("the new site is spoken for", bool(_orchard().get("model").call(&"is_move_dest", MOVE_TO)))


func _the_cart_stands_by_the_baskets() -> void:
	"""The east orchard's cart drawn by its baskets; the baskets' panel says so and offers no second cart."""
	var cart: Node3D = _orchard().get("view").call(&"cart_node", 1)
	_check("the cart is drawn", cart != null and cart.visible)
	_check("by its baskets", cart != null and Vector2(cart.position.x, cart.position.z).distance_to(Rules.CART_PARK_AT[1]) < 0.01)
	_click(_screen_of(Rules.STAND_AT[1], 0.3))
	_orchard().call(&"refresh_panel")
	var panel: CanvasLayer = _orchard().get("panel")
	var build: Button = panel.call(&"button", &"cart")
	_check("the baskets' panel has its cart", String(panel.call(&"line", &"text")).contains("a handcart"),
		panel.call(&"line", &"text"))
	_check("no second cart", build.visible and build.disabled and build.tooltip_text.contains("cart already"))
	_check("the share's button", String((panel.call(&"button", &"dest") as Button).text) == "Share: fresh 0%")
	_capture("orchard_cart")


func _look_at_the_beech_hollow() -> void:
	"""The camera over the beech hollow's stone, the second grove's (nobody selected)."""
	_village.get("_command").call(&"select", PackedInt32Array())
	var camera: Node = _village.get("_camera")
	camera.set("_target_focus", Vector3(Rules.GROVE_STONES[1].x, 0.0, Rules.GROVE_STONES[1].y))
	camera.set("_target_distance", 22.0)
	camera.set("_target_pitch", deg_to_rad(52.0))
	camera.set("_target_yaw", deg_to_rad(180.0))
	camera.call(&"snap")


func _click_the_beech_stone() -> void:
	"""A click on the beech hollow's stone: the second grove selected, its section, its ring while protected."""
	_click(_screen_of(Rules.GROVE_STONES[1], 0.2))
	_orchard().call(&"refresh_panel")
	var panel: CanvasLayer = _orchard().get("panel")
	_check("the stone selects the beech hollow", int(_orchard().get("selected_kind")) == 5 and int(_orchard().get("selected_id")) == 1,
		"%s %s" % [_orchard().get("selected_kind"), _orchard().get("selected_id")])
	_check("its grove section", String(panel.call(&"line", &"grove_title")) == "The beech hollow")
	_check("its reserve said", String(panel.call(&"line", &"grove")).contains("mushrooms a reserve"), panel.call(&"line", &"grove"))
	var ring: MeshInstance3D = _orchard().get("view").call(&"ring_of", 1)
	_check("its ring is drawn", ring.visible)
	_capture("beech_hollow")


func _the_foraging_outing() -> void:
	"""The Woods tab: the Foraging section's Kit and Lead buttons, and its trip card's home-by-dusk rule."""
	_click(_centre(_zone().tab(DetailZone.PANEL_WOODS)))
	var forage: Node = _village.call(&"forage")
	forage.call(&"refresh_section")
	var section: Control = forage.get("section")
	var kit: Button = section.call(&"button", &"forage_kit")
	var lead: Button = section.call(&"button", &"forage_lead")
	_check("Kit and Lead are offered", kit.is_visible_in_tree() and lead.is_visible_in_tree(), "%s %s" % [kit.text, lead.text])
	var authorise: Button = section.call(&"button", &"forage_authorise")
	var card: String = authorise.tooltip_text.replace("\n  ", " ")
	_check("the trip's card says home by dusk", card.contains("Home by dusk") and card.contains("turns back"), card)
	_capture("forage_outing")


func _resume_at_4x() -> void:
	"""Resume at 4x for the move."""
	root.get_node(^"GameManager").call(&"resume_game")
	root.get_node(^"GameManager").call(&"set_speed", 4)


func _wait_for_the_move() -> void:
	"""Run until the sapling stands on its new site (bounded)."""
	root.get_node(^"GameManager").call(&"acknowledge_overload")
	_move_frames += STEP_FRAMES
	if not bool(_orchard().get("model").call(&"has_tree", MOVE_TO)) and _move_frames < MOVE_FRAMES:
		_steps.push_front(_wait_for_the_move)


func _the_sapling_is_moved() -> void:
	"""The resident lifted, carried and replanted it: on east site 2, moved once, settling; east site 1 empty."""
	var model: RefCounted = _orchard().get("model")
	_check("the sapling is replanted in game time", bool(model.call(&"has_tree", MOVE_TO)), "after %d frames" % _move_frames)
	_check("its old block is empty", not bool(model.call(&"has_tree", MOVE_FROM)))
	_check("it settles", int(model.get("settle_days")[MOVE_TO]) > 0 and int(model.get("moved")[MOVE_TO]) == 1)
	_capture("orchard_moved")


func _free_resident() -> int:
	"""The first resident with no orchard job (the routine's work may hold some while paused)."""
	var jobs: RefCounted = _orchard().get("jobs")
	var cast: Node = _village.get("_cast")
	for who: int in int(cast.call(&"actor_count")):
		if int(jobs.call(&"job_of_worker", who)) < 0:
			return who
	return 0
