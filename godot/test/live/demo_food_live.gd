extends SceneTree
## The food lanes on the REAL scene with REAL Viewport input (decision 1601 onward): the apiary's skep and bees beside the
## old orchard, a left click on the skep bringing the Orchard panel with the apiary's readout and verbs; the preserving
## table by the kitchen and the Water panel's Preserves (decision 1611); the brewery and its Brewing section (decision
## 1621); the new recipes' buttons (decision 1625), and the crop picker's Uses naming the stations' rows. Not discovered by
## the runner: test/test_demo_food_live.gd runs it in its own process.
##
##     godot --headless --path godot --script res://test/live/demo_food_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on a failure.

const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const HiveRules := preload("res://demo/hives/hive_rules.gd")
const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
## ui_shell.gd ID_FOOD and ID_LEDGER (named here: its script needs the autoloads a --script run has not registered yet).
const ID_FOOD: int = 2
const ID_LEDGER: int = 9
## demo_orchard.gd SEL_APIARY (named here: its script needs the autoloads a --script run has not registered yet).
const SEL_APIARY: int = 6

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 3

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _pending_capture: String = ""


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
	_steps = [_pause, _the_apiary_is_wired, _look_at_the_apiary, _click_the_skep, _its_readout_and_verbs,
		_close_on_the_bees, _look_at_the_preserving_table, _open_the_preserves, _look_at_the_brewery, _open_the_brewing,
		_the_new_recipes, _a_deep_drink_warns, _the_cordial_is_a_table_drink, _the_reserve_row, _press_keep_more, _keep_more_pressed,
		_keep_fewer_pressed, _release_pressed, _press_keep_again, _keep_again_pressed, _open_the_ledger, _ready_food_says_eaten_raw,
		_select_a_bed, _open_the_crop_picker, _the_picker_lists_the_stations]


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
	"""The village's orchard (the apiary's owner)."""
	return _village.call(&"orchard")


func _zone() -> DetailZone:
	"""The right column."""
	return _village.get("_zone")


func _screen_of(at: Vector2, height: float) -> Vector2:
	"""Where a ground point `height` m up is on screen."""
	return root.get_viewport().get_camera_3d().unproject_position(Vector3(at.x, height, at.y))


func _fits(rect: Rect2) -> bool:
	"""Whether a rectangle lies inside the window."""
	return Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0).encloses(rect)


func _look_at(at: Vector3, distance: float, pitch_deg: float, yaw_deg: float) -> void:
	"""The camera on `at` from `distance` m."""
	var camera: Node = _village.get("_camera")
	camera.set("_target_focus", at)
	camera.set("_target_distance", distance)
	camera.set("_target_pitch", deg_to_rad(pitch_deg))
	camera.set("_target_yaw", deg_to_rad(yaw_deg))
	camera.call(&"snap")


# --- the steps ----------------------------------------------------------------------------------------------------------

func _pause() -> void:
	"""Pause as the player."""
	root.get_node(^"GameManager").call(&"pause_game")


func _the_apiary_is_wired() -> void:
	"""Decision 1601: the hive is a real row in the orchard's store, its skep drawn, its bees out in spring."""
	var model: RefCounted = _orchard().get("model")
	_check("the hive is a real row", int(model.get("store").call(&"hive_count")) == HiveRules.APIARY_COUNT)
	var view: Node3D = _orchard().get("apiary_view")
	_check("the skep is drawn", view != null and (view.get("skeps") as Array).size() == HiveRules.APIARY_COUNT)
	_check("the bees are out in spring", view != null and ((view.get("swarms") as Array)[0] as Node3D).visible)
	var staged: bool = ResourceLoader.exists("res://demo/assets/world/bee_skep.glb") \
		or ResourceLoader.exists("res://demo/assets/props/bee_skep.glb")
	_check("the field's beans are joined to the apiary", (_village.get("_farm").get("sim").get("pollinate") as Callable).is_valid())
	_check("the keeper reads the pantry's honey", _orchard().call(&"free_honey") == _village.call(&"kitchen").get("kitchen").get(
		"takes").call(&"free_milli_of_crop", _village.get("_farm").get("pantry"), 8))
	_check("the old trees are pollinated", _old_apple_factor() == 1100, "factor %d (skep staged: %s)" % [_old_apple_factor(),
		staged])


func _old_apple_factor() -> int:
	"""REQ-SET-082's factor on the old apple, read from the store."""
	var model: RefCounted = _orchard().get("model")
	var read := preload("res://scripts/core/int_math.gd").IntResult.new()
	var ok: bool = model.get("store").call(&"orchard_pollination_factor_into", int(model.call(&"slot_of", 0)), read)
	return read.value if ok else -1


func _look_at_the_apiary() -> void:
	"""The camera over the skep and the old orchard behind it, from the north."""
	var at: Vector2 = HiveRules.centre_m(0)
	_look_at(Vector3(at.x, 0.0, at.y + 3.0), 16.0, 42.0, 180.0)
	_capture("apiary")


func _click_the_skep() -> void:
	"""A left click on the skep: the apiary selected, the Orchard panel in the right column, inside the window."""
	_click(_screen_of(HiveRules.centre_m(0), 0.4))
	var panel: CanvasLayer = _orchard().get("panel")
	_check("a click on the skep selects the apiary", int(_orchard().get("selected_kind")) == SEL_APIARY,
		"%s" % _orchard().get("selected_kind"))
	_check("the Orchard panel is shown", bool(panel.call(&"is_shown")))
	_check("it holds the right column", _zone().shown == DetailZone.PANEL_ORCHARD)
	_check("the panel fits the window", _fits(panel.call(&"frame_rect")), str(panel.call(&"frame_rect")))
	_capture("apiary_panel")


func _its_readout_and_verbs() -> void:
	"""The apiary's title, its readout (ECO-011's crops, ECO-012's feed), its verbs with their cards."""
	var panel: CanvasLayer = _orchard().get("panel")
	_orchard().call(&"refresh_panel")
	_check("the panel names the apiary", String(panel.call(&"line", &"title")) == "The apiary", panel.call(&"line", &"title"))
	var text: String = panel.call(&"line", &"text")
	_check("it says which crops benefit", text.contains("the old apple") and text.contains("beans in bed"), text)
	_check("it shows the winter feed", text.contains("winter feed"), text)
	var service: Button = panel.call(&"button", &"service")
	_check("Tend the bees is shown", service.visible)
	_check("its card says why not on the founding day", service.disabled and service.tooltip_text.contains("tended today"),
		service.tooltip_text)
	_check("Feed and Recolonise are refused", (panel.call(&"button", &"feed") as Button).disabled \
		and (panel.call(&"button", &"recolonize") as Button).disabled)


func _close_on_the_bees() -> void:
	"""Close on the skep: the swarm about it."""
	var at: Vector2 = HiveRules.centre_m(0)
	_look_at(Vector3(at.x, 0.4, at.y), 4.5, 30.0, 20.0)
	_capture("bees")


func _look_at_the_preserving_table() -> void:
	"""The preserving table west of the kitchen: its shelf of jars and its crock (decision 1611)."""
	_look_at(Vector3(Recipes.TABLE_AT.x, 0.4, Recipes.TABLE_AT.y), 7.0, 32.0, 200.0)
	var view: Node = _village.get("_fishery").get("view")
	_check("the shelf of jars is drawn", view != null and view.has_node(NodePath("Preserves_jar_shelf")))
	_check("the crock is drawn", view != null and view.has_node(NodePath("Preserves_crock_stoneware")))
	_capture("preserving_table")


func _open_the_preserves() -> void:
	"""The Water tab: the Preserves section, Dry fruit and Pack rations each with its card (the village opens with no fruit
	or flour in store: both say what they need)."""
	_click(_zone().tab(DetailZone.PANEL_WATER).get_global_transform_with_canvas() * (_zone().tab(DetailZone.PANEL_WATER).size / 2.0))
	_check("the Water tab takes the zone", _zone().shown == DetailZone.PANEL_WATER)
	var panel: CanvasLayer = _village.get("_waterplay").get("panel")
	_village.get("_fishery").call(&"refresh_panel")
	panel.call(&"scroll_to_line", &"preserves")
	_check("the Preserves line is filled", String(panel.call(&"line", &"preserves")).contains("dried fruit"),
		panel.call(&"line", &"preserves"))
	for key: StringName in [&"dry_fruit", &"pack_rations"]:
		var button: Button = panel.call(&"button", key)
		_check("%s is shown with its card" % key, button != null and button.visible and button.tooltip_text.contains("Can't now"),
			button.tooltip_text.replace("\n", " / ") if button != null else "")
	_capture("preserves_panel")


func _look_at_the_brewery() -> void:
	"""The brewery east of the kitchen: its mash vat and conditioning cask (decision 1621)."""
	_click(_zone().tab(DetailZone.PANEL_FARM).get_global_transform_with_canvas() * (_zone().tab(DetailZone.PANEL_FARM).size / 2.0))
	_look_at(Vector3(Recipes.BREWERY_AT.x, 0.4, Recipes.BREWERY_AT.y - 0.6), 7.0, 32.0, 160.0)
	var view: Node = _village.get("_fishery").get("view")
	_check("the mash vat is drawn", view != null and view.has_node(NodePath("Preserves_brew_vat")))
	_check("the cask is drawn", view != null and view.has_node(NodePath("Preserves_ale_cask")))
	_capture("brewery")


func _open_the_brewing() -> void:
	"""The Water tab's Brewing section: Brew mead and Make cordial, each with its card (no honey yet: both say so)."""
	_click(_zone().tab(DetailZone.PANEL_WATER).get_global_transform_with_canvas() * (_zone().tab(DetailZone.PANEL_WATER).size / 2.0))
	var panel: CanvasLayer = _village.get("_waterplay").get("panel")
	_village.get("_fishery").call(&"refresh_panel")
	panel.call(&"scroll_to_line", &"brewing")
	_check("the Brewing line is filled", String(panel.call(&"line", &"brewing")).contains("vats in use"),
		panel.call(&"line", &"brewing"))
	for key: StringName in [&"brew_mead", &"make_cordial"]:
		var button: Button = panel.call(&"button", key)
		_check("%s is shown with its card" % key, button != null and button.visible and button.tooltip_text.to_lower().contains("honey"),
			button.tooltip_text.replace("\n", " / ") if button != null else "")
	_capture("brewing_panel")


func _the_new_recipes() -> void:
	"""Decision 1625: Make jam, Make cheese, Make vinegar and Make pickles under the Preserves, Brew ale and Make cider
	under the Brewing, each with its card (the village opens with none of their inputs: each says what it needs)."""
	var panel: CanvasLayer = _village.get("_waterplay").get("panel")
	_village.get("_fishery").call(&"refresh_panel")
	panel.call(&"scroll_to_line", &"preserves")
	for key: StringName in [&"make_jam", &"make_cheese", &"brew_ale", &"make_cider", &"make_vinegar", &"make_pickles"]:
		var button: Button = panel.call(&"button", key)
		_check("%s is shown with its card" % key, button != null and button.visible and button.tooltip_text.contains("Can't now"),
			button.tooltip_text.replace("\n", " / ") if button != null else "")
	_check("the preserves line counts jam and cheese", String(panel.call(&"line", &"preserves")).contains("cheese"))
	var vinegar_card: String = (panel.call(&"button", &"make_vinegar") as Button).tooltip_text
	_check("the vinegar card keeps it for pickling", vinegar_card.contains("pickling") and not vinegar_card.contains("feasts"), vinegar_card.replace("\n", " / "))
	_check("the preserves line counts vinegar and pickles", String(panel.call(&"line", &"preserves")).contains("pickles"))
	_capture("new_recipes_panel")


func _stock(item: int, milli: int) -> void:
	"""Put `milli` of `item` in the village's pantry (a setup for the tuning's checks)."""
	var read: RefCounted = load("res://scripts/core/int_math.gd").IntResult.new()
	_check("%s stocked" % Catalog.ITEM_KEYS[item], bool(_village.get("_farm").get("pantry").call(&"add_into", item, milli, 0,
		read)))


static func _flat(text: String) -> String:
	"""A card's text on one line: its wrapped lines joined, runs of spaces made one."""
	var flat: String = text.replace("\n", " ")
	while flat.contains("  "):
		flat = flat.replace("  ", " ")
	return flat


func _a_deep_drink_warns() -> void:
	"""Decision 1734: with 8 U of mead in store (over two feasts' worth, 6 U) and honey for a batch, Brew mead's card
	notes it and the order's answer says so -- a warning, the batch still ordered."""
	_stock(Catalog.ITEM_MEAD, 8000)
	_stock(Catalog.ITEM_HONEY, 6000)
	_village.call(&"services").get("stores").set("water_milli_u", 20000)
	var panel: CanvasLayer = _village.get("_waterplay").get("panel")
	_village.get("_fishery").call(&"refresh_panel")
	panel.call(&"scroll_to_line", &"brewing")
	var card: String = _flat((panel.call(&"button", &"brew_mead") as Button).tooltip_text)
	_check("the Brew mead card notes the stock", card.contains("Note: the stores already hold 8 jugs of mead"),
		card.replace("\n", " / "))
	var said: String = _village.get("_fishery").call(&"batch_answer", Recipes.R_MEAD, PackedInt32Array())
	_check("the order is placed and warned of", said.begins_with("Brew mead: on the work board — the stores already hold"),
		said)
	_capture("brew_warning")


func _the_cordial_is_a_table_drink() -> void:
	"""Decision 1733: Make cordial's card says it keeps 240 h and is poured at supper; the kitchen's table drink is on."""
	var panel: CanvasLayer = _village.get("_waterplay").get("panel")
	_village.get("_fishery").call(&"refresh_panel")
	var card: String = _flat((panel.call(&"button", &"make_cordial") as Button).tooltip_text)
	_check("the cordial card: 240 h, poured at supper", card.contains("keeps 240 h") and card.contains("poured at supper"),
		card.replace("\n", " / "))
	var fishery: RefCounted = _village.get("_fishery").get("fishery")
	_check("the rack reads the kitchen's fish beyond its next meal (decision 1739)",
		(fishery.get("spare_fish") as Callable).is_valid() and (fishery.get("free_spare_fish") as Callable).is_valid())
	var spare: Callable = fishery.get("spare_fish")
	var give: Callable = fishery.get("free_spare_fish")
	fishery.call(&"bind_spare_fish", func() -> int: return 3000, func(_m: int) -> int: return 0)
	var dry: RefCounted = _village.get("_fishery").call(&"dry_card", PackedInt32Array())
	var have: int = int((dry.get("cost_have") as PackedInt64Array)[0])
	var expected: int = int(fishery.call(&"input_available_milli", Recipes.IN_FIRST[Recipes.R_DRY_FISH]))
	_check("the Dry fish card counts the kitchen's fish too", have == expected and have >= 3000, "%d of %d" % [have, expected])
	fishery.call(&"bind_spare_fish", spare, give)
	var kitchen: RefCounted = _village.call(&"kitchen").get("kitchen")
	var kept: int = int(kitchen.call(&"raw_kept_milli", Catalog.CAT_DRIED_FISH))
	_check("the kitchen keeps the rations' dried fish from raw eating as the fishery says (decision 1740)",
		(kitchen.get("raw_keep") as Callable).is_valid()
		and kept == int(fishery.call(&"ration_keep_milli", Catalog.CAT_DRIED_FISH))
		and int(kitchen.call(&"raw_kept_milli", Catalog.CAT_NUTS)) == 0, "kept %d" % kept)
	_check("the mill reads the kitchen's grain beyond its next meal (decision 1741)",
		(fishery.get("spare_grain") as Callable).is_valid() and (fishery.get("free_spare_grain") as Callable).is_valid()
		and int(fishery.call(&"grain_available_milli")) == int(fishery.get("takes").call(&"free_milli_of_crop",
		fishery.get("pantry"), 3)) + int(kitchen.call(&"beyond_next_meal_milli", 3)))
	_check("the mill's grain pair is bound to grain", (fishery.get("spare_grain") as Callable).get_bound_arguments()
		== [3] and (fishery.get("free_spare_grain") as Callable).get_bound_arguments() == [3])
	var reserve: RefCounted = fishery.get("ration_reserve")
	_check("the village keeps a ration reserve of 6 U, drawing on the kitchen's later meals (decision 1742)",
		int(reserve.get("target_milli")) == 6000 and (reserve.get("kitchen_give") as Callable).is_valid()
		and int(reserve.get("take")) != 0)
	var grain_spare: Callable = fishery.get("spare_grain")
	var grain_give: Callable = fishery.get("free_spare_grain")
	fishery.call(&"bind_spare_grain", func() -> int: return 3000, func(_m: int) -> int: return 0)
	var mill: RefCounted = _village.get("_fishery").call(&"mill_card", PackedInt32Array())
	var grain: int = int((mill.get("cost_have") as PackedInt64Array)[0])
	_check("the Mill grain card counts the kitchen's grain too", grain == int(fishery.call(&"grain_available_milli"))
		and grain >= 3000, "%d" % grain)
	fishery.call(&"bind_spare_grain", grain_spare, grain_give)
	var drink: RefCounted = _village.call(&"kitchen").get("table_drink")
	_check("the table drink watches the kitchen", drink != null and drink.get("_kitchen") != null)


func _reserve_panel() -> CanvasLayer:
	"""The Water panel, refreshed, its reserve line at the top of the view."""
	var panel: CanvasLayer = _village.get("_waterplay").get("panel")
	_village.get("_fishery").call(&"refresh_panel")
	panel.call(&"scroll_to_line", &"reserve")
	return panel


func _press(key: StringName) -> void:
	"""A real click on the Water panel's `key` button."""
	var button: Button = _reserve_panel().call(&"button", key)
	_click(button.get_global_transform_with_canvas() * (button.size / 2.0))


func _reserve() -> RefCounted:
	"""The fishery's ration reserve."""
	return _village.get("_fishery").get("fishery").get("ration_reserve")


func _the_reserve_row() -> void:
	"""Decision 1742, Brendan's R5: the Preserves section's reserve line, its stepper and Release, each shown (the view
	scrolled to it, settling before the first click). Dried fish is stocked and the reserve tops up, so it holds some."""
	_stock(Catalog.ITEM_DRIED_FISH, 1000)
	_village.get("_fishery").get("fishery").call(&"top_up_ration_reserve")
	var panel: CanvasLayer = _reserve_panel()
	var text: String = panel.call(&"line", &"reserve")
	_check("the reserve line says what it keeps and holds", text.begins_with("Ration reserve: keep 6 rations (")
		and text.contains("a string of dried fish"), text.replace("\n", " / "))
	for key: StringName in [&"reserve_fewer", &"reserve_more", &"reserve_release"]:
		var button: Button = panel.call(&"button", key)
		_check("%s is shown" % key, button != null and button.is_visible_in_tree() and not button.text.is_empty(),
			button.text if button != null else "")
	var release: Button = panel.call(&"button", &"reserve_release")
	_check("Release's card says what it frees", release.tooltip_text.contains("Frees") and not release.disabled,
		release.tooltip_text.replace("\n", " / "))
	var label: Label = (panel.get("_lines") as Dictionary)[&"reserve"]
	_check("the reserve line holds three lines, so the row does not jump", label.get_line_height() > 0
		and label.custom_minimum_size.y >= 3.0 * label.get_line_height(), str(label.custom_minimum_size.y))
	_capture("reserve_row")


func _press_keep_more() -> void:
	"""Keep more is clicked."""
	_press(&"reserve_more")


func _keep_more_pressed() -> void:
	"""Keep more stepped the target a batch up, and the panel's own refresh (its _process, not this harness) shows it;
	Keep fewer is clicked."""
	_check("Keep more: 9 U", int(_reserve().get("target_milli")) == 9000, str(_reserve().get("target_milli")))
	var line: String = _village.get("_waterplay").get("panel").call(&"line", &"reserve")
	_check("the panel's own refresh shows it", line.begins_with("Ration reserve: keep 9 rations ("), line.replace("\n", " / "))
	_press(&"reserve_fewer")


func _keep_fewer_pressed() -> void:
	"""Keep fewer stepped it back; Release is clicked."""
	_check("Keep fewer: 6 U", int(_reserve().get("target_milli")) == 6000, str(_reserve().get("target_milli")))
	_press(&"reserve_release")


func _release_pressed() -> void:
	"""Released: nothing held, the line and the caption say so (the frame captured before the next press)."""
	var panel: CanvasLayer = _reserve_panel()
	_check("Release: released", bool(_reserve().get("released")))
	_check("the line says released", String(panel.call(&"line", &"reserve")).contains("Released: nothing held"),
		panel.call(&"line", &"reserve"))
	_check("the caption offers to keep them again",
		(panel.call(&"button", &"reserve_release") as Button).text == "Keep food reserves again")
	_capture("reserve_released")


func _press_keep_again() -> void:
	"""Keep food reserves again is clicked."""
	_press(&"reserve_release")


func _keep_again_pressed() -> void:
	"""Kept again."""
	_check("kept again", not bool(_reserve().get("released")))


func _open_the_ledger() -> void:
	"""Click the Ready food counter: the resource ledger opens on it."""
	var shell: Node = _village.call(&"_shell")
	var cell: Control = shell.call(&"control_for", ID_FOOD)
	_click(cell.get_global_transform_with_canvas() * (cell.size / 2.0))


func _ready_food_says_eaten_raw() -> void:
	"""Decision 1736: the ledger's food line and the cell's tooltip carry the raw reserve beside Ready food (the honey
	stocked is raw-edible food Ready food does not count)."""
	var shell: Node = _village.call(&"_shell")
	var ledger: Control = shell.call(&"control_for", ID_LEDGER)
	var line: String = (shell.call(&"ledger_label") as Label).text
	_check("the ledger is open", ledger.visible)
	_check("the food line says raw", line.contains("Ready food: ") and line.contains(" · raw "), line.replace("\n", " / "))
	_check("the ledger keeps its eight lines", line.split("\n").size() == 8, str(line.split("\n").size()))
	var shown: int = (shell.call(&"ledger_label") as Label).get_line_count()
	_check("no ledger line wraps (decision 1801: natural measures are longer)", shown == 8, str(shown))
	var tip: String = (shell.call(&"control_for", ID_FOOD) as Control).tooltip_text
	_check("the tooltip says eaten raw", tip.contains("Eaten raw: "), tip)
	_check("the ledger fits the window", _fits(ledger.get_global_rect()), str(ledger.get_global_rect()))
	_capture("ready_food_ledger")


func _select_a_bed() -> void:
	"""Select bed 1, as a player would before Plant… (decision 1625's Uses, read from the recipe rows)."""
	_village.get("_farm").call(&"select_bed", 0)


func _open_the_crop_picker() -> void:
	"""Open bed 1's crop picker."""
	(_village.get("_farm").get("bed_panel") as CanvasLayer).call(&"open_picker")


func _the_picker_lists_the_stations() -> void:
	"""The roots' role line names the pickles, barley's the ale: the picker reads the stations' rows."""
	var bed: CanvasLayer = _village.get("_farm").get("bed_panel")
	var radish: String = bed.call(&"picker_role", 0)
	var barley: String = bed.call(&"picker_role", 14)
	_check("the radish's Uses name the pickles", radish.contains("the preserving table (pickles)"), radish)
	_check("barley's Uses name the ale", barley.contains("the brewery (ale)"), barley)
	_capture("crop_picker")
