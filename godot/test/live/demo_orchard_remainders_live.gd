extends SceneTree
## Review group Y's remainders on the REAL scene with REAL Viewport input (decision 1721; Brendan's ruling on Q-D7): a
## planted sapling selected by a click, its Move sapling button (scrolled into the panel at 1280x720) ordering the move,
## the sapling lifted, carried and replanted in game time at 4x; a built cart standing by the east baskets, the baskets'
## panel saying so and offering no second; the beech hollow's stone selecting the second grove, its section and its ring;
## and the Woods panel's Foraging section with its Kit and Lead and a card that says home by dusk. Kept apart from
## demo_orchard_live.gd so that harness's timed tending never shares its clock. Not discovered by the runner:
## test/test_demo_orchard_remainders_live.gd runs it in its own process.
##
##     godot --headless --path godot --script res://test/live/demo_orchard_remainders_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on a failure.

const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const Rules := preload("res://demo/orchard/orchard_rules.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 3
## How many frames the move may take in game time at 4x (decision 1721: 20 WU, a short carry, 40 WU).
const MOVE_FRAMES: int = 4800
## The move is ordered once breakfast is over (meal_rules.gd: served until 08:59), so no meal call takes the mover.
const AFTER_BREAKFAST_HOUR: int = 9
## How many frames the morning may take at 4x to reach it.
const MORNING_FRAMES: int = 6000
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
var _move_frames: int = 0
var _morning_frames: int = 0
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
	_steps = [_resume_at_4x, _run_past_breakfast, _pause, _build_the_east_cart, _plant_the_sapling, _look_at_the_east_orchard, _the_cart_stands_by_the_baskets,
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


func _pause() -> void:
	"""Pause as the player (orders are carried out on resume)."""
	root.get_node(^"GameManager").call(&"pause_game")


func _build_the_east_cart() -> void:
	"""The east orchard's cart built (its building is the suite's: test_demo_orchard_remainders.gd)."""
	_check("the east orchard's cart is built", bool(_orchard().get("model").call(&"add_cart", 1)))
	_check("the old orchard's cart is built", bool(_orchard().get("model").call(&"add_cart", 0)))


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
	_steps.push_front(_look_at_the_old_cart)


func _look_at_the_old_cart() -> void:
	"""The old orchard's cart by its baskets (a frame to look at)."""
	var camera: Node = _village.get("_camera")
	camera.set("_target_focus", Vector3(Rules.CART_PARK_AT[0].x, 0.0, Rules.CART_PARK_AT[0].y))
	camera.set("_target_distance", 14.0)
	camera.set("_target_pitch", deg_to_rad(50.0))
	camera.set("_target_yaw", deg_to_rad(180.0))
	camera.call(&"snap")
	var cart: Node3D = _orchard().get("view").call(&"cart_node", 0)
	_check("the old orchard's cart is drawn", cart != null and cart.visible)
	_capture("orchard_old_cart")
	_steps.push_front(_look_at_the_east_orchard)


func _look_at_the_beech_hollow() -> void:
	"""The camera over the beech hollow's stone, the second grove's (nobody selected)."""
	_village.get("_command").call(&"select", PackedInt32Array())
	var camera: Node = _village.get("_camera")
	camera.set("_target_focus", Vector3(Rules.GROVE_STONES[1].x, 0.0, Rules.GROVE_STONES[1].y))
	camera.set("_target_distance", 40.0)
	camera.set("_target_pitch", deg_to_rad(68.0))
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


func _run_past_breakfast() -> void:
	"""Run at 4x until AFTER_BREAKFAST_HOUR (bounded)."""
	root.get_node(^"GameManager").call(&"acknowledge_overload")
	_morning_frames += STEP_FRAMES
	var hour: int = int(_village.get("_services").get("calendar").call(&"now").get("hour"))
	if hour < AFTER_BREAKFAST_HOUR and _morning_frames < MORNING_FRAMES:
		_steps.push_front(_run_past_breakfast)
		return
	_check("the morning is past breakfast", hour >= AFTER_BREAKFAST_HOUR, "%02d:00 after %d frames" % [hour, _morning_frames])


func _wait_for_the_move() -> void:
	"""Run until the sapling stands on its new site (bounded)."""
	root.get_node(^"GameManager").call(&"acknowledge_overload")
	_move_frames += STEP_FRAMES
	if not bool(_orchard().get("model").call(&"has_tree", MOVE_TO)) and _move_frames < MOVE_FRAMES:
		_steps.push_front(_wait_for_the_move)


func _the_sapling_is_moved() -> void:
	"""The resident lifted, carried and replanted it: on east site 2, moved once, settling; east site 1 empty."""
	var model: RefCounted = _orchard().get("model")
	var jobs: RefCounted = _orchard().get("jobs")
	var j: int = int(jobs.call(&"find", JobsScript.K_MOVE, MOVE_FROM))
	_check("the sapling is replanted in game time", bool(model.call(&"has_tree", MOVE_TO)), "after %d frames (job %d%s)" % [
		_move_frames, j, ": worker %s, '%s'" % [jobs.get("worker")[j], jobs.get("words")[j]] if j >= 0 else ""])
	_check("its old block is empty", not bool(model.call(&"has_tree", MOVE_FROM)))
	_check("it settles", int(model.get("settle_days")[MOVE_TO]) > 0 and int(model.get("moved")[MOVE_TO]) == 1)
	var camera: Node = _village.get("_camera")
	var site: Vector2 = Rules.site_centre_m(MOVE_TO)
	camera.set("_target_focus", Vector3(site.x, 0.0, site.y))
	camera.call(&"snap")
	_capture("orchard_moved")


func _free_resident() -> int:
	"""The first resident with no orchard job (the routine's work may hold some while paused)."""
	var jobs: RefCounted = _orchard().get("jobs")
	var cast: Node = _village.get("_cast")
	for who: int in int(cast.call(&"actor_count")):
		if int(jobs.call(&"job_of_worker", who)) < 0:
			return who
	return 0
