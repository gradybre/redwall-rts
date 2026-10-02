extends "res://test/framework/test_case.gd"
## Review group E, "numbers and roster that tell the truth" (decision 0251): the demo's HUD read model and its
## counters and ledger (F10), the Residents roster and the village map (F14), and the farm's figures in player
## terms (F34).
##
## No scene tree and no staged assets: the shell is the real HUD shell built off-tree, the cast the placeholder
## cast, the stores, pantry and farm the real ones. Expected values are literals from the cited constants.
## Decision 0571 gave Fuel's slot back to UI-SET-003's Heating fuel (the winter's fuel-days); Planks are a ledger line
## and in the Wood cell's tooltip now.

const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const ModelScript := preload("res://demo/ui/demo_hud_model.gd")
const CountersScript := preload("res://demo/ui/demo_hud_counters.gd")
const RosterScript := preload("res://demo/ui/demo_roster.gd")
const MinimapScript := preload("res://demo/ui/demo_minimap.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const FarmHudScript := preload("res://demo/farm/farm_hud.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const ForestText := preload("res://demo/forestry/forest_text.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CameraScript := preload("res://demo/camera/demo_camera.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const MeterScript := preload("res://demo/farm/farm_moisture_meter.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
## The fuel-days the counters' fixture reads (hundredths): 2.5 days.
const FUEL_DAYS: int = 250
const BED_LOAM: int = 0
const BED_CARROTS: int = 2
const CARROT: int = 2

var _nodes: Array[Node] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


func _shell() -> UiShell:
	"""The real HUD shell, built off-tree and laid out for 1280x720."""
	var shell: UiShell = _keep(UiShell.new())
	shell.build()
	assert_true(shell.layout_for(1280, 720), "the standard layout computes")
	return shell


func _counters(shell: UiShell, stores: StoresScript, food: Array, residents: int, beds: int) -> CountersScript:
	"""Counters over these stores, a food total (milli-U) read from `food[0]`, this many residents and beds."""
	var counters := CountersScript.new()
	counters.model.stores = stores
	counters.model.food = func() -> int: return int(food[0])
	counters.model.residents = func() -> int: return residents
	counters.model.beds = func() -> int: return beds
	counters.model.homes = func() -> int: return 1
	counters.model.fuel = func() -> int: return FUEL_DAYS
	counters.bind(shell)
	return counters


func _value(shell: UiShell, id: int) -> String:
	"""A counter cell's drawn value."""
	return shell.counter_value_label(id).text


# --- F10: the top bar reads the village's own stores ----------------------------------------------------

func test_the_top_bar_reads_the_village_stores_pantry_cast_and_homes() -> void:
	"""Each cell its owner's figure, in its panel's words; Fuel's slot is Heating fuel; the unwired Heating fuel and Beds
	cells are painted with their captions and enabled; tooltips say where each figure is."""
	var shell := _shell()
	var stores := StoresScript.new()
	var counters := _counters(shell, stores, [12000], 9, 3)
	assert_true(counters.sync(), "painted")
	assert_equal(_value(shell, UiShell.ID_FOOD), "12.0 U", "the pantry's total")
	assert_equal(_value(shell, UiShell.ID_FUEL), "2.5 days", "the winter's fuel-days")
	assert_equal(shell.counter_caption_label(UiShell.ID_FUEL).text, "Heating fuel", "UI-SET-003's caption")
	assert_equal(_value(shell, UiShell.ID_WOOD), "40.0 U", "the stores' wood")
	assert_equal(_value(shell, UiShell.ID_STONE), "20.0 U", "the stores' stone")
	assert_equal(_value(shell, UiShell.ID_POPULATION), "9", "the cast")
	assert_equal(_value(shell, UiShell.ID_BEDS), "3", "the homes' beds")
	assert_equal(shell.counter_caption_label(UiShell.ID_BEDS).text, "Beds", "no longer 'Sim beds'")
	assert_false((shell.control_for(UiShell.ID_BEDS) as Button).disabled, "Beds opens the ledger like the others")
	assert_false((shell.control_for(UiShell.ID_FUEL) as Button).disabled, "and so does Heating fuel")
	assert_equal(shell.control_for(UiShell.ID_WOOD).tooltip_text,
		"Wood: 40.0 U in the village stores (planks: 0.0 U). Click for the ledger.", "says where the figure is")
	assert_equal(shell.control_for(UiShell.ID_WOOD).accessibility_description,
		shell.control_for(UiShell.ID_WOOD).tooltip_text, "and says it to a screen reader")
	assert_false(counters.sync(), "nothing changed: nothing painted")


func test_the_top_bar_equals_the_stores_after_spending_and_hauling() -> void:
	"""Bracing paid, a log hauled, sawing, a bridge's planks, a fixture paid and taken out: after each, the Wood,
	Stone and Planks cells print what the stores hold -- the same words as the Tunnels and Woods panels' lines."""
	var shell := _shell()
	var services := ServicesScript.new()
	var stores: StoresScript = services.stores
	var counters := _counters(shell, stores, [0], 9, 0)
	var woods := ForestText.new()
	woods.configure(null, null, null, null, services)
	var steps: Array[Callable] = [func() -> bool: return stores.pay(3700, 1300), func() -> bool:
		stores.add_wood(4250)
		return true, func() -> bool:
		var taken: bool = stores.take_wood(2000)
		stores.add_planks(1500)
		return taken, func() -> bool: return stores.pay_planks(900), func() -> bool: return stores.pay_all(500, 250, 100),
		func() -> bool:
		stores.refund(500, 250, 100)
		return true]
	for k: int in steps.size():
		assert_true(bool(steps[k].call()), "step %d happened" % k)
		counters.sync()
		for pair: Array in [[UiShell.ID_WOOD, stores.wood_milli_u], [UiShell.ID_STONE, stores.stone_milli_u]]:
			assert_equal(_value(shell, pair[0]), StoresScript.units_text(pair[1]), "step %d: cell %d" % [k, pair[0]])
		assert_true(stores.stock_line().contains("wood " + _value(shell, UiShell.ID_WOOD)), "step %d: the Tunnels line" % k)
		assert_true(stores.stock_line().contains("stone " + _value(shell, UiShell.ID_STONE)), "step %d: stone" % k)
		var planks: String = StoresScript.units_text(stores.plank_milli_u)
		assert_true(woods.stores_line().contains("planks " + planks), "step %d: the Woods line" % k)
		assert_true(counters.ledger_label().text.contains("· planks %s in store" % planks), "step %d: the ledger" % k)
	assert_equal(_value(shell, UiShell.ID_WOOD), "38.5 U", "40 - 3.7 + 4.25 - 2.0, floored to a tenth")
	assert_true(counters.ledger_label().text.contains("· planks 0.6 U in store"), "1.5 sawn - 0.9 for the bridge")


func test_the_food_cell_follows_the_pantry_total() -> void:
	"""The Ready food cell is the pantry's own total, as the Pantry's headline counts it (milli-U summed first,
	then the farm's one units form: decision 0222)."""
	var shell := _shell()
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	var counters := CountersScript.new()
	counters.model.food = pantry.total_milli
	counters.bind(shell)
	counters.sync()
	assert_equal(_value(shell, UiShell.ID_FOOD), "0 U", "an empty pantry is a real zero")
	assert_true(pantry.add_into(CARROT, 5400, 0, _read), "a harvest stored")
	assert_true(counters.sync(), "repainted")
	assert_equal(_value(shell, UiShell.ID_FOOD), FarmHudScript.food_text(pantry.total_milli()), "the pantry's figure")
	assert_equal(_value(shell, UiShell.ID_FOOD), "5.4 U", "5.4 U of carrot counts as the Pantry counts it")


func test_unavailable_never_masquerades_as_zero() -> void:
	"""A figure whose owner is absent is Unavailable in the cell, the tooltip and the ledger -- never 0."""
	var shell := _shell()
	var counters := CountersScript.new()
	counters.bind(shell)
	counters.sync()
	for id: int in UiShell.COUNTER_IDS:
		assert_equal(_value(shell, id), ModelScript.UNAVAILABLE, "cell %d unknown" % id)
	assert_equal(shell.control_for(UiShell.ID_WOOD).tooltip_text, "Wood: Unavailable", "the tooltip")
	assert_true(counters.ledger_label().text.contains("Beds: Unavailable"), "the ledger")
	assert_false(counters.ledger_label().text.contains(": 0"), "no zero anywhere")
	assert_false(counters.model.known(ModelScript.CELL_FOOD), "unknown")
	counters.model.food = func() -> int: return 0
	assert_true(counters.model.known(ModelScript.CELL_FOOD), "a pantry: known")
	assert_equal(counters.model.value_text(ModelScript.CELL_FOOD, 0), "0 U", "and its zero is a real one")


func test_the_counters_paint_back_over_the_settlement_figures() -> void:
	"""UIManager writing the settlement's Wood, the shell relabelling Beds or UIManager rewriting the ledger: the
	next sync paints the village's back; nothing else is repainted."""
	var shell := _shell()
	var counters := _counters(shell, StoresScript.new(), [7000], 9, 3)
	counters.sync()
	shell.set_counter_display(UiShell.ID_WOOD, "180 U")
	assert_true(counters.sync(), "noticed")
	assert_equal(_value(shell, UiShell.ID_WOOD), "40.0 U", "ours again")
	shell.counter_caption_label(UiShell.ID_BEDS).text = "Beds"
	shell.counter_value_label(UiShell.ID_BEDS).text = "Unavailable"
	assert_true(counters.sync(), "a relayout noticed")
	assert_equal(_value(shell, UiShell.ID_BEDS), "3", "the homes' beds again")
	shell.set_ledger_display("Food-days --   Wood 180 U")
	assert_true(counters.sync(), "the ledger noticed")
	assert_true(counters.ledger_label().text.begins_with(ModelScript.LEDGER_TITLE), "the village's ledger again")
	assert_false(counters.sync(), "and then quiet")
	shell.control_for(UiShell.ID_WOOD).accessibility_description = "Wood 40.0 U"
	assert_true(counters.sync(), "a relayout's accessible description noticed")
	assert_equal(shell.control_for(UiShell.ID_WOOD).accessibility_description,
		"Wood: 40.0 U in the village stores (planks: 0.0 U). Click for the ledger.", "ours again")


func test_the_ledger_says_the_same_figures_and_whose_they_are() -> void:
	"""The drill-down the counters open: a title, then each cell's figure with where it is."""
	var shell := _shell()
	var stores := StoresScript.new()
	stores.add_planks(2500)
	var counters := _counters(shell, stores, [12000], 9, 3)
	counters.sync()
	assert_equal(counters.ledger_label().text, "Village stores and residents\nReady food: 12.0 U in the Pantry (K)\n"
		+ "Heating fuel: 2.5 days\nWood: 40.0 U · planks 2.5 U in store\nStone: 20.0 U in the village stores\n"
		+ "Residents: 9 living in the village\nBeds: 3 in 1 burrow home", "the ledger")
	counters.model.homes = func() -> int: return 2
	assert_equal(counters.model.ledger_line(ModelScript.CELL_BEDS, 3), "Beds: 3 in 2 burrow homes", "plural")
	counters.model.homes = Callable()
	assert_equal(counters.model.ledger_line(ModelScript.CELL_BEDS, 3), "Beds: 3 in the burrow homes", "no count")


func test_a_value_that_does_not_fit_discloses_the_ledger() -> void:
	"""The demo's own cells keep the shell's rule: measured in the value face, `cell_width-8`, else See ledger."""
	var shell := _shell()
	var counters := _counters(shell, StoresScript.new(), [0], 9, 3)
	var font: Font = counters.role_font(UiShell.VALUE_VARIATION)
	var px: int = counters.role_px(UiShell.VALUE_VARIATION)
	var width: float = font.get_string_size("40.0 U", HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	assert_true(CountersScript.fits(font, px, "40.0 U", width + 8.0), "exactly fits")
	assert_false(CountersScript.fits(font, px, "40.0 U", width + 7.0), "a pixel short")
	assert_true(CountersScript.fits(font, px, "anything", 0.0), "not laid out yet: no judgement")
	assert_true(CountersScript.fits(null, px, "anything", 10.0), "no face: no judgement")
	counters.model.beds = func() -> int: return 123456789012345
	counters.sync()
	assert_equal(_value(shell, UiShell.ID_BEDS), UiShell.SEE_LEDGER, "a Beds figure too wide for its cell discloses the ledger")
	assert_equal(shell.counter_value_label(UiShell.ID_BEDS).get_theme_font_size(&"font_size"),
		counters.role_px(UiShell.DISCLOSURE_VARIATION), "in the disclosure role, as the shell draws it")
	assert_true(counters.ledger_label().text.contains("Beds: 123456789012345 "), "where the exact figure is")


func test_the_heating_fuel_cell_warns_under_two_days_and_says_no_demand() -> void:
	"""Decision 0571 (ruling 5): under 2 days the value is clay and the glyph the warning one; at 3 days plain again;
	with no heat demand the cell says so (its tooltip in UI-SET-003's full words)."""
	var shell := _shell()
	var counters := _counters(shell, StoresScript.new(), [0], 9, 3)
	var days: Array[int] = [150]
	counters.model.fuel = func() -> int: return days[0]
	counters.sync()
	var value: Label = shell.counter_value_label(UiShell.ID_FUEL)
	assert_equal(value.text, "1.5 days", "under 2 days")
	assert_equal(value.get_theme_color(&"font_color"), Palette.CLAY, "in clay")
	assert_equal(shell.counter_icon(UiShell.ID_FUEL).texture, CountersScript.WARNING_ICON, "the warning glyph")
	days[0] = 300
	counters.sync()
	assert_false(value.has_theme_color_override(&"font_color"), "3 days: plain")
	assert_equal(shell.counter_icon(UiShell.ID_FUEL).texture, CountersScript.FUEL_ICON, "the fuel glyph")
	days[0] = -1
	counters.sync()
	assert_equal(value.text, "No demand", "the cell's short words fit")
	assert_true(shell.control_for(UiShell.ID_FUEL).tooltip_text.begins_with("Heating fuel: No current heat demand"),
		shell.control_for(UiShell.ID_FUEL).tooltip_text)


# --- F14: the Residents roster --------------------------------------------------------------------------

func _village() -> Array:
	"""A command layer over the placeholder cast, a camera rig and a shell: [command, cast, rig, shell]."""
	var cast: DemoCastScript = _keep(DemoCastScript.new())
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var camera: Camera3D = _keep(Camera3D.new())
	var command: CommandScript = _keep(CommandScript.new())
	command.configure(cast, camera)
	var rig: CameraScript = _keep(CameraScript.new())
	rig.configure(AABB(Vector3(-20.0, 0.0, -34.0), Vector3(56.0, 4.0, 76.0)), Vector3.ZERO)
	return [command, cast, rig, _shell()]


func _roster(parts: Array) -> RosterScript:
	"""The roster over a _village()."""
	var roster: RosterScript = _keep(RosterScript.new())
	roster.configure(parts[3], parts[1], parts[0], parts[2])
	return roster


func test_the_residents_command_lists_the_cast() -> void:
	"""Residents (L) opens the roster on the cast, one row per resident in cast order, titled Residents; each row
	maps to its cast id; the population counter shows the same count."""
	var parts := _village()
	var shell: UiShell = parts[3]
	var cast: DemoCastScript = parts[1]
	var roster := _roster(parts)
	(shell.control_for(UiShell.ID_RESIDENTS) as Button).pressed.emit()
	assert_true(roster.is_open(), "the roster page is open")
	assert_equal(shell.roster_shown(), cast.actor_count(), "one row per resident")
	assert_equal(shell.workspace_title().text, "Residents", "titled")
	for row: int in shell.roster_shown():
		var actor := cast.actor(roster.actor_of(row)) as DemoActorScript
		assert_equal(roster.actor_of(row), row, "row %d is cast id %d" % [row, row])
		assert_true(shell.roster_row(row).text.begins_with(actor.display_name + " — "), "row %d names its resident" % row)
	assert_equal(roster.actor_of(-1), -1, "no row")
	assert_equal(roster.actor_of(cast.actor_count()), -1, "past the last row")
	var counters := CountersScript.new()
	counters.model.residents = cast.actor_count
	counters.bind(shell)
	counters.sync()
	assert_equal(_value(shell, UiShell.ID_POPULATION), "%d" % cast.actor_count(), "the counter counts the same cast")


func test_a_row_says_who_where_what_and_what_next() -> void:
	"""Name, species and trade, where, and what it is doing -- the party panel's own words -- and saved work."""
	var parts := _village()
	var command: CommandScript = parts[0]
	var roster := _roster(parts)
	var doing: String = command.activity_text(0)
	assert_equal(roster.row_text(0), "Placeholder 0 — placeholder · On the surface\n" + doing.left(1).to_upper()
		+ doing.substr(1), "no trade; species lower case (0491); line 2 the party panel's words")
	assert_equal(doing, "wandering", "a placeholder left to its routine")
	assert_equal(RosterScript.row_words("Mole digger", "Mole", "digger", "Underground, level 1", "digging tunnel — 43%",
		PackedStringArray(["back to Burrow home 1"])), "Mole digger — Mole, digger · Underground, level 1\n"
		+ "Digging tunnel — 43% · Next: back to Burrow home 1", "the whole row (its order list, decision 0411)")
	assert_equal(RosterScript.row_words("A", "B", "", "On the surface", "", PackedStringArray()), "A — B · On the surface",
		"nothing doing, nothing saved: one line")
	assert_equal(RosterScript.row_words("A", "B", "c", "In the water", "", PackedStringArray(["x", "y"])),
		"A — B, c · In the water\nNext: x → y", "saved work alone")
	assert_equal(RosterScript.trade_of(&"otter_boatwright"), "boatwright", "a trade")
	assert_equal(RosterScript.trade_of(&"badger_quarryman"), "quarryman", "another")
	assert_equal(RosterScript.trade_of(&"placeholder_3"), "", "a placeholder's")
	assert_equal(RosterScript.trade_of(&"hermit"), "", "a one-word key")


func test_where_a_resident_is() -> void:
	"""The surface, the water, indoors, and underground on the level its floor is on."""
	var brain := BrainScript.new()
	assert_equal(RosterScript.location_text(brain), "On the surface", "surface")
	brain.underground = true
	brain.ground_y_m = -Rules.to_m(Rules.BORE_FLOOR_DEPTH_U)
	assert_equal(RosterScript.location_text(brain), "Underground, level 1", "level 1")
	brain.ground_y_m = -Rules.to_m(Rules.LEVEL_2_FLOOR_DEPTH_U)
	assert_equal(RosterScript.location_text(brain), "Underground, level 2", "level 2")
	brain.indoors = true
	assert_equal(RosterScript.location_text(brain), "Indoors", "indoors")
	brain.in_water = true
	assert_equal(RosterScript.location_text(brain), "In the water", "in the water first")
	@warning_ignore("integer_division") var between: int = (Rules.BORE_FLOOR_DEPTH_U + Rules.LEVEL_2_FLOOR_DEPTH_U) / 2
	assert_equal(RosterScript.level_at_depth_u(0), 1, "a ramp's top is level 1's way down")
	assert_equal(RosterScript.level_at_depth_u(between), 1, "halfway: still level 1")
	assert_equal(RosterScript.level_at_depth_u(between + 1), 2, "past halfway: level 2")


func test_a_row_clicked_selects_centres_and_closes() -> void:
	"""A row picked selects exactly that resident (the party panel's selection), centres the camera on it and
	closes the roster; UIManager's settlement lookup no longer answers the shell's row picks."""
	var parts := _village()
	var command: CommandScript = parts[0]
	var cast: DemoCastScript = parts[1]
	var rig: CameraScript = parts[2]
	var shell: UiShell = parts[3]
	var elsewhere: Array = [0]
	shell.resident_row_picked.connect(UIManager._on_resident_row_picked)
	shell.resident_row_picked.connect(func(_row: int) -> void: elsewhere[0] += 1)
	var roster := _roster(parts)
	assert_false(shell.resident_row_picked.is_connected(UIManager._on_resident_row_picked), "UIManager's lookup let go")
	(shell.control_for(UiShell.ID_RESIDENTS) as Button).pressed.emit()
	(cast.actor(3) as DemoActorScript).brain.position = Vector2(6.5, -4.25)
	shell.roster_row(3).pressed.emit()
	assert_equal(command.selected(), PackedInt32Array([3]), "that resident alone")
	assert_true(command.is_selected(3) and not command.is_selected(2), "is_selected agrees")
	assert_equal(command.party_entries().size(), 1, "the party panel's selection")
	assert_equal(command.party_entries()[0]["name"], (cast.actor(3) as DemoActorScript).display_name, "the same one")
	assert_equal(rig.target_focus(), Vector3(6.5, 0.0, -4.25), "the camera heads for it")
	assert_false(roster.is_open(), "the roster closed so the resident is in view")
	assert_equal(elsewhere[0], 1, "any other listener is kept")
	roster.pick_row(99)
	assert_equal(command.selected(), PackedInt32Array([3]), "a row that lists no one changes nothing")


func test_the_roster_refreshes_only_on_a_change() -> void:
	"""Rewritten when UIManager's rows replaced it or a row's words changed; otherwise left alone."""
	var parts := _village()
	var shell: UiShell = parts[3]
	var roster := _roster(parts)
	assert_true(roster.refresh(), "first fill")
	assert_false(roster.refresh(), "unchanged")
	shell.set_roster(PackedStringArray(["Warden Rowan  mouse  Health 100 / 100"]), 1)
	assert_true(roster.refresh(), "UIManager's rows written over")
	assert_true(shell.roster_row(0).text.begins_with("Placeholder 0"), "the cast again")
	var same_count := PackedStringArray()
	for k: int in shell.roster_shown():
		same_count.append("Unnamed resident")
	shell.set_roster(same_count, same_count.size())
	assert_true(roster.refresh(), "as many rows, but not the cast's: written over")
	assert_equal(shell.roster_row(0).alignment, HORIZONTAL_ALIGNMENT_LEFT, "rows read from the left")
	assert_false(shell.roster_row(0).clip_text, "and are never cropped")


# --- F14: the village map ---------------------------------------------------------------------------------

func test_the_map_square_takes_in_the_camera_bounds() -> void:
	"""The map shows a square round the camera's ground box, as wide as its longer side plus the margin."""
	var rect: Rect2 = MinimapScript.map_rect_for(AABB(Vector3(-20.0, 0.0, -34.0), Vector3(56.0, 4.0, 76.0)), 2.0)
	assert_equal(rect, Rect2(-32.0, -36.0, 80.0, 80.0), "centred (8, 4), 76 + 4 m wide")
	var flat: Rect2 = MinimapScript.map_rect_for(AABB(Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 4.0)), 0.0)
	assert_equal(flat, Rect2(0.0, -3.0, 10.0, 10.0), "the wider side sets the square")


func test_world_to_map_and_back() -> void:
	"""North up and east right: the square's corners are the map's; map_to_world inverts world_to_map."""
	var world := Rect2(-32.0, -36.0, 80.0, 80.0)
	var size := Vector2(240.0, 240.0)
	assert_equal(MinimapScript.world_to_map(Vector2(-32.0, -36.0), world, size), Vector2.ZERO, "north-west corner")
	assert_equal(MinimapScript.world_to_map(Vector2(48.0, 44.0), world, size), size, "south-east corner")
	assert_equal(MinimapScript.world_to_map(Vector2(8.0, 4.0), world, size), Vector2(120.0, 120.0), "the centre")
	assert_equal(MinimapScript.world_to_map(Vector2(8.0, -36.0), world, size).y, 0.0, "-z (north) is up")
	for p: Vector2 in [Vector2(0.0, 0.0), Vector2(-17.5, 12.25), Vector2(40.0, -30.0)]:
		var back: Vector2 = MinimapScript.map_to_world(MinimapScript.world_to_map(p, world, size), world, size)
		assert_true(back.is_equal_approx(p), "%s round trips" % p)


func test_a_view_ray_meets_the_ground() -> void:
	"""A ray down meets y = 0; one above the horizon is followed FAR_M."""
	assert_equal(MinimapScript.ground_hit(Vector3(1.0, 10.0, 2.0), Vector3(0.0, -1.0, 0.0)), Vector2(1.0, 2.0), "straight down")
	var slanted: Vector2 = MinimapScript.ground_hit(Vector3(0.0, 10.0, 0.0), Vector3(0.0, -0.5, -0.5).normalized())
	assert_true(slanted.is_equal_approx(Vector2(0.0, -10.0)), "45 degrees: as far as it is high")
	var level: Vector2 = MinimapScript.ground_hit(Vector3(0.0, 10.0, 0.0), Vector3(0.0, 0.0, -1.0))
	assert_equal(level, Vector2(0.0, -MinimapScript.FAR_M), "never meets it: FAR_M on")
	var below: Vector2 = MinimapScript.ground_hit(Vector3(2.0, -1.0, 3.0), Vector3(1.0, -1.0, 0.0).normalized())
	assert_equal(below, Vector2(2.0, 3.0), "from under the ground: stops where it starts")


func test_a_click_on_the_map_centres_the_camera() -> void:
	"""The map's centre is the square's centre; a click there sends the camera; the map describes itself."""
	var parts := _village()
	var map: MinimapScript = _keep(MinimapScript.new())
	map.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map.size = Vector2(240.0, 240.0)
	map.configure(parts[1], parts[2], parts[0], null)
	assert_equal(map.world_rect, Rect2(-32.0, -36.0, 80.0, 80.0), "the rig's bounds")
	assert_equal(map.centre_camera_at(Vector2(120.0, 120.0)), Vector2(8.0, 4.0), "the ground under the click")
	assert_equal((parts[2] as CameraScript).target_focus(), Vector3(8.0, 0.0, 4.0), "the camera heads there")
	map.centre_camera_at(Vector2(0.0, 0.0))
	assert_equal((parts[2] as CameraScript).target_focus(), Vector3(-20.0, 0.0, -34.0), "held inside its ground box")
	var marks := map.get_node("Marks") as Control
	assert_equal(marks.mouse_filter, Control.MOUSE_FILTER_STOP, "the map takes the click (not the settlement tile)")
	assert_equal(marks.accessibility_description, MinimapScript.DESCRIPTION, "and says what it shows")


# --- F34: the farm in player terms --------------------------------------------------------------------

func test_moisture_reads_as_a_band_and_a_percentage() -> void:
	"""'Soil moisture: Good · 60%'; floored, but rounded up above the range so a wet bed never prints as its top;
	the range line under it."""
	assert_equal(Text.moisture_percent(6600, 7000), 66, "66%")
	assert_equal(Text.moisture_percent(6699, 7000), 66, "floored")
	assert_equal(Text.moisture_percent(7000, 7000), 70, "the top of the range is in it")
	assert_equal(Text.moisture_percent(7001, 7000), 71, "just over the top: 71, never 70")
	assert_equal(Text.moisture_percent(2499, 7000), 24, "just under 25%: 24")
	assert_equal(Text.moisture_percent(0, 7000), 0, "dry as dust")
	assert_equal(Text.moisture_percent(10000, 7000), 100, "sodden")
	assert_equal(Text.moisture_percent(9999, 7000), 100, "never over 100")
	var sim := SimScript.new()
	assert_equal(Text.moisture_line(sim, BED_CARROTS), "Soil moisture: Good · 60%", "the carrots")
	assert_equal(Text.range_line(sim, BED_CARROTS), "Suitable for this crop: 25–70%", "their range")


func test_fertility_and_health_read_as_percentages_and_changes() -> void:
	"""Whole percentages, floored and held to 0..100; factors as the change they make; points for treatments."""
	assert_equal(Text.percent_text(0), "0%", "none")
	assert_equal(Text.percent_text(99), "0%", "under one")
	assert_equal(Text.percent_text(6399), "63%", "floored")
	assert_equal(Text.percent_text(9999), "99%", "not yet full")
	assert_equal(Text.percent_text(10000), "100%", "full")
	assert_equal(Text.percent_text(12000), "100%", "held to the scale")
	assert_equal(Text.change_text(810), "−19%", "a loss")
	assert_equal(Text.change_text(815), "−18.5%", "a half")
	assert_equal(Text.change_text(1100), "+10%", "a gain")
	assert_equal(Text.change_text(1000), "±0%", "no change")
	assert_equal(Text.change_text(500), "−50%", "the floor")
	assert_equal(Text.points_text(50, true), "+0.5", "Rest's half point")
	assert_equal(Text.points_text(1500, true), "+15", "compost")
	assert_equal(Text.points_text(-800, true), "−8", "a crop's cost")
	assert_equal(Text.points_text(1550, false), "15.5", "unsigned")
	assert_equal(Text.points_text(9, false), "0", "under a tenth: floored")
	assert_equal(Text.factor_text(850), "0.85", "two places")
	assert_equal(Text.factor_text(815), "0.815", "three when it needs them")
	assert_equal(Text.factor_text(1000), "1.00", "one")
	var sim := SimScript.new()
	assert_equal(Text.fertility_effect_line(sim, BED_CARROTS), "Fertility effect on yield: −15%", "70% fertility")
	assert_equal(Text.health_line(sim, BED_CARROTS), "Crop health: 100%", "a healthy crop")
	assert_equal(Text.health_line(sim, BED_LOAM), "", "an empty bed has no crop health")


func test_one_expected_harvest_with_its_breakdown_on_demand() -> void:
	"""The panel's one figure; the Details view's multiplication equals it while growing, and names the daily loss
	that brings a ripe crop down to it past its grace."""
	var sim := SimScript.new()
	assert_equal(Text.yield_line(sim, BED_CARROTS, _read), "Expected harvest: 5.1 U of carrot", "one figure")
	assert_equal(Text.harvest_breakdown(sim, BED_CARROTS, _read),
		"Base 6.0 U × fertility 0.85 × health 1.00 × rotation 1.00 = 5.1 U", "its multiplication")
	assert_equal(Text.harvest_breakdown(sim, BED_LOAM, _read), "", "nothing standing: no breakdown")
	assert_equal(Text.yield_line(sim, BED_LOAM, _read), "", "nor a figure")
	sim.advance_usec(24 * HOUR_USEC)
	assert_equal(Text.yield_line(sim, BED_CARROTS, _read), "Harvest now: 5.1 U of carrot", "ripe, in its grace")
	sim.advance_usec(76 * HOUR_USEC)
	assert_true(sim.expected_yield_into(BED_CARROTS, _read), "a harvest")
	assert_equal(_read.value, 4590, "one day past the grace: 10% of 5.1 U lost")
	assert_equal(Text.harvest_breakdown(sim, BED_CARROTS, _read), "Base 6.0 U × fertility 0.85 × health 1.00 × rotation "
		+ "1.00 = 5.1 U; ripe 76 h: −10% a day after the first 2 days, so 4.5 U", "and why")
	assert_true(Text.raw_line(sim, BED_CARROTS).begins_with("Readings (of 10000): moisture "), "raw readings stay in Details")


func test_treatments_say_their_effect_in_points() -> void:
	"""Rest, Water, Drain and Compost say what they change in percentage points of the whole scale."""
	assert_equal(Text.rest_tip(), "Rest the bed fallow: nothing is sown; +0.5 fertility points a day (+1 a day for 12 days "
		+ "after a legume)", "Rest")
	var sim := SimScript.new()
	assert_equal(Text.verb_tip(sim, BED_CARROTS, JobsScript.KIND_COMPOST), "Compost: +15 fertility points", "compost")
	assert_equal(Text.verb_tip(sim, BED_CARROTS, JobsScript.KIND_DRAIN),
		"Drain: dig a ditch; the moisture drops to the top of this crop's range (70%)", "drain")
	assert_true(Text.verb_tip(sim, BED_CARROTS, JobsScript.KIND_WATER).begins_with("Water: +10 moisture points"), "water")
	assert_equal(Text.verb_tip(sim, BED_CARROTS, JobsScript.KIND_COVER), "", "no figure to state")
	assert_equal(Text.sown_estimate_milli(sim, BED_LOAM, CARROT), 5100, "6 U at 0.85 fertility, fresh rotation")
	assert_equal(Text.estimate_milli(6000, 850, 850), 4335, "the same family again: 6 x 0.85 x 0.85")
	assert_equal(Text.estimate_milli(7000, 1000, 1100), 7700, "a legume after a change, full fertility")
	sim.advance_usec(24 * HOUR_USEC)
	assert_true(sim.harvest(BED_CARROTS).ok, "the carrots harvested")
	var again: int = Text.sown_estimate_milli(sim, BED_CARROTS, CARROT)
	assert_equal(again, Text.estimate_milli(6000, sim.fertility_factor_of(BED_CARROTS), 850), "roots again: the 850 rotation")
	assert_true(Text.pick_row(sim, BED_CARROTS, CARROT).contains("this bed: about %s" % Text.units_text(again)), "in the picker")


func test_the_moisture_meter_bands_and_positions() -> void:
	"""Five bands split where the farm's bands change, held to the scale; a value's place along the bar."""
	assert_equal(MeterScript.band_edges(2500, 7000, 2000), PackedInt32Array([0, 500, 2500, 7000, 9000, 10000]), "carrots")
	assert_equal(MeterScript.band_edges(1000, 9000, 2000), PackedInt32Array([0, 0, 1000, 9000, 10000, 10000]), "clamped")
	assert_equal(MeterScript.x_of(0, 200.0), 0.0, "empty")
	assert_equal(MeterScript.x_of(6600, 200.0), 132.0, "66%")
	assert_equal(MeterScript.x_of(12000, 200.0), 200.0, "held to the bar")
	var meter: MeterScript = _keep(MeterScript.new())
	assert_true(meter.show_reading(6000, 2500, 7000, 2000), "a first reading")
	assert_false(meter.show_reading(6000, 2500, 7000, 2000), "unchanged: no redraw")
	assert_true(meter.show_reading(6100, 2500, 7000, 2000), "moved")


# --- the edges the mutation pass found untested ------------------------------------------------------

func test_the_residents_counter_and_an_open_roster_stay_the_casts() -> void:
	"""The Residents counter's click fills the rows too; while open, the roster keeps its title and follows a
	resident's words within REFRESH_S; closed, it does nothing."""
	var parts := _village()
	var shell: UiShell = parts[3]
	var cast: DemoCastScript = parts[1]
	var roster := _roster(parts)
	shell.set_roster(PackedStringArray(["Warden Rowan"]), 1)
	(shell.control_for(UiShell.ID_POPULATION) as Button).pressed.emit()
	assert_true(shell.roster_row(0).text.begins_with("Placeholder 0"), "the counter's click lists the cast")
	assert_true(shell.workspace_title().text != "Residents", "but renames no page: the roster is not open")
	(shell.control_for(UiShell.ID_RESIDENTS) as Button).pressed.emit()
	shell.workspace_title().text = "Resident row"
	roster._process(0.0)
	assert_equal(shell.workspace_title().text, "Residents", "a relayout's title written back")
	(cast.actor(0) as DemoActorScript).brain.underground = true
	(cast.actor(0) as DemoActorScript).brain.ground_y_m = -Rules.to_m(Rules.BORE_FLOOR_DEPTH_U)
	roster._process(RosterScript.REFRESH_S)
	assert_true(shell.roster_row(0).text.contains("Underground, level 1"), "followed within REFRESH_S")
	(shell.control_for(UiShell.ID_BACK) as Button).pressed.emit()
	shell.workspace_title().text = "Resident row"
	roster._process(1.0)
	assert_equal(shell.workspace_title().text, "Resident row", "closed: left alone")
	assert_false((parts[0] as CommandScript).is_selected(cast.actor_count()), "past the cast: not selected")
	(parts[0] as CommandScript).select(PackedInt32Array([cast.actor_count() - 1]))
	assert_false((parts[0] as CommandScript).is_selected(-1), "before it: not selected (not the last, wrapped)")


func test_the_map_on_a_non_square_view_and_its_pointer() -> void:
	"""The transforms hold for a view that is not square; a left click or left drag moves the camera, anything
	else does not; a ray barely below the horizon stops at FAR_M."""
	var world := Rect2(-10.0, -20.0, 40.0, 40.0)
	var size := Vector2(300.0, 150.0)
	for p: Vector2 in [Vector2(0.0, 0.0), Vector2(25.0, 15.0), Vector2(-9.0, -19.5)]:
		assert_true(MinimapScript.map_to_world(MinimapScript.world_to_map(p, world, size), world, size).is_equal_approx(p),
			"%s round trips on a 300x150 view" % p)
	assert_equal(MinimapScript.world_to_map(Vector2(30.0, 20.0), world, size), size, "the far corner")
	var shallow: Vector2 = MinimapScript.ground_hit(Vector3(0.0, 10.0, 0.0), Vector3(0.0, -0.001, -1.0).normalized())
	assert_true(is_equal_approx(shallow.y, -MinimapScript.FAR_M), "a grazing ray stops at FAR_M")
	var parts := _village()
	var rig: CameraScript = parts[2]
	var map: MinimapScript = _keep(MinimapScript.new())
	map.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map.size = Vector2(240.0, 240.0)
	map.configure(parts[1], rig, parts[0], null)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = Vector2(60.0, 60.0)
	map._on_marks_input(right)
	assert_equal(rig.target_focus(), Vector3.ZERO, "a right click moves nothing")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	left.position = Vector2(120.0, 120.0)
	map._on_marks_input(left)
	assert_equal(rig.target_focus(), Vector3(8.0, 0.0, 4.0), "a left click does")
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = Vector2(150.0, 120.0)
	map._on_marks_input(drag)
	assert_equal(rig.target_focus(), Vector3(18.0, 0.0, 4.0), "and a left drag")
	var hover := InputEventMouseMotion.new()
	hover.position = Vector2(30.0, 30.0)
	map._on_marks_input(hover)
	assert_equal(rig.target_focus(), Vector3(18.0, 0.0, 4.0), "a hover does not")


func test_the_farm_words_at_their_edges() -> void:
	"""Just over the range's top rounds up by whole percent; a chosen crop sets the range an empty bed is judged
	by; full fertility has no effect; a ripe crop in its grace shows no loss; a blighted crop still has a harvest."""
	assert_equal(Text.moisture_percent(7100, 7000), 71, "71.00 is 71")
	assert_equal(Text.moisture_percent(7101, 7000), 72, "71.01 rounds up")
	assert_equal(Text.fertility_effect_text(1000), "Fertility effect on yield: none", "full fertility")
	assert_equal(Text.fertility_effect_text(850), "Fertility effect on yield: −15%", "70% fertility")
	var sim := SimScript.new()
	assert_true(sim.choose(BED_LOAM, CARROT).ok, "carrot chosen for the empty loam bed")
	assert_equal(Text.range_line(sim, BED_LOAM), "Suitable for this crop: 25–70%", "judged by the chosen crop")
	sim.advance_usec(24 * HOUR_USEC)
	assert_false(Text.harvest_breakdown(sim, BED_CARROTS, _read).contains("; ripe"), "ripe in its grace: no loss yet")
	var fresh := SimScript.new()
	fresh.infect_for_test(BED_CARROTS)
	assert_equal(fresh.stage_of(BED_CARROTS), SimScript.STAGE_BLIGHTED, "blighted")
	assert_true(Text.yield_line(fresh, BED_CARROTS, _read).begins_with("Expected harvest: "), "still a harvest to take")


func test_the_meter_redraws_on_any_change_and_the_panel_shows_it_with_a_bed() -> void:
	"""A new band margin alone redraws; the bed panel shows the meter and Details only with a bed, the Details'
	text only when opened, and Rest's tooltip in points."""
	var meter: MeterScript = _keep(MeterScript.new())
	meter.show_reading(6000, 2500, 7000, 2000)
	assert_true(meter.show_reading(6000, 2500, 7000, 1500), "the margin moved")
	assert_true(meter.show_reading(6000, 2600, 7000, 1500), "the range's bottom moved")
	assert_true(meter.show_reading(6000, 2600, 7100, 1500), "its top moved")
	var BedPanelScript: GDScript = load("res://demo/farm/farm_bed_panel.gd")
	var CrewScript: GDScript = load("res://demo/farm/farm_crew.gd")
	var TunnelsScript: GDScript = load("res://demo/farm/farm_tunnels.gd")
	var FarmScript: GDScript = load("res://demo/farm/demo_farm.gd")
	var sim := SimScript.new()
	var cast: DemoCastScript = _village()[1]
	var crew: RefCounted = CrewScript.new()
	crew.configure(cast, sim, PantryScript.new(StorageScript.new(Vector2.ZERO)), TunnelsScript.new(),
		FarmScript.well_position(), func(_text: String) -> void: pass)
	var panel: CanvasLayer = _keep(BedPanelScript.new())
	panel.configure(sim, crew)
	assert_false(panel.meter().visible, "no bed: no meter")
	panel.show_bed(BED_CARROTS)
	assert_true(panel.meter().visible, "a bed: its meter")
	assert_equal(panel.meter().moisture, sim.moisture_of(BED_CARROTS), "reading the bed")
	assert_equal(panel.meter().band_min, sim.band_min_of(BED_CARROTS), "against its crop's range")
	assert_equal(panel.meter().band_max, sim.band_max_of(BED_CARROTS), "both ends")
	assert_equal(panel.meter().margin, FarmingScript.MOISTURE_NEAR_MARGIN, "and the farm's band margin")
	assert_equal(panel.details_text(), "", "Details closed")
	panel.toggle_details()
	assert_true(panel.details_text().begins_with("Base 6.0 U × fertility 0.85"), "opened: the breakdown")
	assert_true(panel.details_text().contains("\nReadings (of 10000): moisture "), "and the raw readings")
	assert_equal(panel.line_text(8), "Expected harvest: 5.1 U of carrot", "one expected harvest")
	assert_equal(panel._fallow.tooltip_text, Text.rest_tip(), "Rest says its effect in points")
	assert_true(panel.verb_button(JobsScript.KIND_COMPOST).tooltip_text.contains("Compost: +15 fertility points"),
		"an enabled verb says its effect (on its action card, decision 0332)")
	panel.toggle_details()
	assert_equal(panel.details_text(), "", "toggled again: closed")
	var meter_at: int = panel.meter().get_index()
	assert_equal((panel.meter().get_parent().get_child(meter_at - 1) as Label).text, panel.line_text(1),
		"the meter sits right under the moisture line")
	panel.toggle_details()
	panel.show_nothing()
	assert_equal(panel.details_text(), "", "no bed: no Details")


func test_the_model_reads_the_village_owners_it_is_bound_to() -> void:
	"""`bind_village` (demo_village.gd's wiring): the stores, the pantry's total, the cast's count, the network's
	installed beds and dug homes -- each cell its own owner, never another's."""
	var GraphScript: GDScript = load("res://demo/tunnel/underground_graph.gd")
	var network: RefCounted = GraphScript.new()
	var stores := StoresScript.new()
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	var cast: DemoCastScript = _village()[1]
	var model := ModelScript.new()
	model.bind_village(stores, pantry, cast, network)
	assert_equal(model.food.get_method(), &"total_milli", "food: the pantry's total")
	assert_equal(model.food.get_object(), pantry, "this pantry")
	assert_equal(model.residents.get_method(), &"actor_count", "residents: the cast's count")
	assert_equal(model.beds.get_method(), &"beds", "beds: the fit-out's installed beds")
	assert_equal(model.homes.get_method(), &"count_done", "homes: the dug homes")
	assert_equal(model.homes.get_bound_arguments(), [network, RoomsScript.TEMPLATE_HOME], "of the home template")
	assert_true(pantry.add_into(CARROT, 3000, 0, _read), "a harvest")
	stores.add_planks(1200)
	var figures := PackedInt64Array()
	figures.resize(ModelScript.CELL_COUNT)
	model.read_into(figures)
	assert_equal(figures, PackedInt64Array([3000, 0, 40000, 20000, cast.actor_count(), 0]), "every figure its owner's")
	assert_false(model.known(ModelScript.CELL_FUEL), "no winter bound: Heating fuel unknown, never the planks")
	assert_true(model.ledger_text(figures).contains("Wood: 40.0 U · planks 1.2 U in store"), "the planks in the ledger")
