extends "res://test/framework/test_case.gd"
## Coverage for the routing layer between the systems and the HUD.
##
## UIManager is the last place a derived figure can be altered before a player reads it. Every
## test here therefore asserts on the HUD's rendered Label text after a real UIManager call, and
## compares it against a value this file states independently -- the GDD §7.1 starter fixture,
## or the GDD §5.8 unpopulated marker. Asserting that a forwarding method "was called" would
## pass against a UIManager that forwards a constant.
##
## THIS SUITE DRIVES THE REAL AUTOLOADS. `ui_manager.gd` reads the EconomySystem and GameManager
## singletons directly, which is correct for a UI router and untestable through a private
## instance. The runner loads suites at runtime, after the autoload globals are registered, so
## the singletons resolve here. `EconomySystem.reset()` runs in both hooks, which empties the
## stores AND drops the residents binding, so no state crosses a test boundary or leaves this
## suite. GameManager is only read, never mutated.
##
## The UIManager under test is never added to the scene tree, so its `_ready()` -- and the
## system-signal wiring inside it -- does not run. Each test drives the handler it means to
## exercise directly, which is also why no signal connection is left dangling on an autoload.
##
## hud.tscn's `_ready()` is called by hand for the reason documented at the top of test_hud.gd:
## in the runner's `_initialize()` the SceneTree root is not yet inside the tree.

const UIManagerScript := preload("res://scripts/systems/ui_manager.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const UiCommandBridgeScript := preload("res://scripts/ui/ui_command_bridge.gd")
const UiWorldSessionScript := preload("res://scripts/ui/ui_world_session.gd")
const UiShellScript := preload("res://scripts/ui/ui_shell.gd")
const UiNoticesScript := preload("res://scripts/ui/ui_notices.gd")

const HUD_SCENE_PATH: String = "res://scenes/ui/hud.tscn"

const MILLI: int = 1000

## GDD §5.1 "Initial inventory U", restated here rather than imported from main.gd.
const STARTING_INVENTORY_U: Dictionary = {
	&"wood": 180, &"stone": 100, &"iron": 20, &"rope": 20, &"tool": 24, &"cloth": 24,
	&"water": 60, &"grain": 80, &"roots": 80, &"berries": 40, &"nuts": 40,
	&"dried_fish": 60, &"ration": 60, &"seed_grain": 32, &"seed_roots": 32,
	&"seed_beans": 16, &"seed_cabbage": 16, &"seed_flax": 16, &"herb": 12, &"compost": 32,
}

## GDD §7.1 starter fixture: 408000 ready NP over 74400 NP/day is 5.48 food-days. These are the
## numbers a player sees at boot, stated here so a hardcoded counter cannot reproduce them.
const STARTER_FOOD_DAYS_TEXT: String = "5.48"
const STARTER_READY_NP_TEXT: String = "408,000 NP"
const STARTER_WOOD_TEXT: String = "180 U"
const STARTER_STONE_TEXT: String = "100 U"

## GDD §5.8's unpopulated marker, stated independently of both hud.gd and economy_system.gd.
const UNPOPULATED: String = "--"

## GDD §5.1's starting cohort: "IDs 1-12".
const STARTER_COHORT: int = 12

## GameManager's PLAYING state and §3's PLAYER pause reason, stated independently.
const STATE_PLAYING: int = 1
const PLAYER_REASON: String = "PLAYER"

## UI-SET-085, the accessible refusal display.
const ERROR_PANEL_ID: int = 85

## Task 04.3's recorded output of one §5.1 generation, and §4.3's second architecture.
const GENERATED_RESOURCE_NODES: int = 1695
const ARCHITECTURE_HOLT: int = 1

## UI-SET-036's panel, UI-SET-037's detail title and UI-SET-039's need row.
const DETAIL_ID: int = 36
const DETAIL_TITLE_ID: int = 37
const NEED_ROW_ID: int = 39
## GDD §4.2 fixes five need columns, and UXV-020 requires five rows for them.
const NEED_ROW_COUNT: int = 5

var _ui: UIManagerScript = null
var _hud: HudScript = null
var _residents: ResidentsScript = null


func before_each() -> void:
	"""Build a HUD and an off-tree UIManager over freshly reset autoload stores."""
	EconomySystem.reset()
	var scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	_hud = scene.instantiate() as HudScript
	_hud._ready()
	_ui = UIManagerScript.new()
	_residents = null


func after_each() -> void:
	"""Free everything this test built and return the shared economy autoload to empty."""
	_residents = null
	if _ui != null:
		_ui.free()
		_ui = null
	if _hud != null:
		_hud.free()
		_hud = null
	EconomySystem.reset()


# --- helpers ----------------------------------------------------------------------------------

func _rendered_counters() -> String:
	"""The exact text currently painted into UI-SET-009's resource ledger line.

	The §4 shell replaced the placeholder top-left panel this suite used to read. The line is
	the same one, built by the same `_render_counters()` and joined by the same separator, so
	every assertion below is unchanged; only the node it is painted into moved.
	"""
	return _hud.shell().ledger_label().text


func _rendered_alert() -> String:
	"""The exact text currently painted into UI-SET-011's alert card."""
	return _hud.shell().alert_label().text


func _rendered_status() -> String:
	"""The exact text currently painted into UI-SET-101's date trigger."""
	return _hud.shell().status_label().text


func _seed_starting_settlement() -> void:
	"""Reproduce the whole GDD §7.1 starter fixture on the shared economy autoload."""
	for item_key: StringName in STARTING_INVENTORY_U:
		var units: int = STARTING_INVENTORY_U[item_key]
		if not EconomySystem.deposit(item_key, units * MILLI):
			fail("starting inventory refused for %s: %s" % [item_key, EconomySystem.last_refusal()])
	_residents = ResidentsScript.new()
	if not _residents.spawn_initial_settlement().ok:
		fail("the §5.1 starting cohort was refused")
	EconomySystem.bind_residents(_residents)


# --- the derived figures reach the screen unaltered -------------------------------------------

func test_food_days_reaches_the_label_exactly_as_the_economy_derived_it() -> void:
	"""The §7.1 fixture must read 5.48 on screen: not rounded, not substituted, not invented."""
	_seed_starting_settlement()
	_ui.register_hud(_hud)
	assert_true(_rendered_counters().contains("Food-days %s" % STARTER_FOOD_DAYS_TEXT),
		"the label shows the computed 5.48, got '%s'" % _rendered_counters())
	assert_equal(EconomySystem.food_days_text(), STARTER_FOOD_DAYS_TEXT,
		"the economy derived the same figure independently")


func test_every_supplied_counter_matches_the_starter_fixture() -> void:
	"""Six supplied counters render the §7.1/§5.1 figures; the seventh stays unpopulated.

	`Residents` MOVED from unpopulated to supplied in the task-04.4 UI shell: the residents
	store publishes a living count, so refusing to show it was under-reporting rather than
	honesty. §5.1's cohort is twelve, asserted as a literal here and cross-checked against the
	store the counter is derived from. `Beds` still has no Building, Furniture or Room store and
	is still unpopulated.
	"""
	_seed_starting_settlement()
	_ui.register_hud(_hud)
	var line: String = _rendered_counters()
	assert_true(line.contains("Ready NP %s" % STARTER_READY_NP_TEXT), "ready NP is 408,000 NP")
	assert_true(line.contains("Wood %s" % STARTER_WOOD_TEXT), "wood is 180 U")
	assert_true(line.contains("Stone %s" % STARTER_STONE_TEXT), "stone is 100 U")
	assert_true(line.contains("Fuel-days %s" % UNPOPULATED), "fuel-days stays unpopulated")
	assert_true(line.contains("Residents %d" % STARTER_COHORT), "residents is §5.1's twelve")
	assert_equal(_residents.living_count(), STARTER_COHORT, "and the store agrees")
	assert_true(line.contains("Beds %s" % UNPOPULATED), "beds stays unpopulated")


func test_an_unpopulated_food_days_reaches_the_label_as_the_marker() -> void:
	"""With no residents bound the divisor is refused, and the screen must say so."""
	_ui.register_hud(_hud)
	assert_false(EconomySystem.has_residents(), "nothing supplies the §5.8 divisor")
	assert_true(_rendered_counters().contains("Food-days %s" % UNPOPULATED),
		"food-days renders the marker, got '%s'" % _rendered_counters())
	assert_false(_rendered_counters().contains("Food-days 0"),
		"a refused figure never renders as a zero")


func test_the_counters_track_the_stores_rather_than_a_constant() -> void:
	"""Two different stock states must produce two different lines through the same code path."""
	_seed_starting_settlement()
	_ui.register_hud(_hud)
	var before: String = _rendered_counters()
	assert_true(EconomySystem.withdraw(&"ration", 60 * MILLI), "the rations are eaten")
	_ui._on_stocks_changed()
	var after: String = _rendered_counters()
	assert_true(before != after, "the repaint followed the stores")
	assert_false(after.contains("Food-days %s" % STARTER_FOOD_DAYS_TEXT),
		"the stale 5.48 is gone from the label")
	assert_true(after.contains("Food-days %s" % EconomySystem.food_days_text()),
		"the new figure is the one the economy now derives")


func test_a_lost_population_returns_the_label_to_the_marker() -> void:
	"""Unbinding the divisor must degrade the counter to "--", never freeze the last figure."""
	_seed_starting_settlement()
	_ui.register_hud(_hud)
	assert_true(_rendered_counters().contains("Food-days %s" % STARTER_FOOD_DAYS_TEXT),
		"food-days starts populated")
	EconomySystem.bind_residents(null)
	_ui._on_stocks_changed()
	assert_true(_rendered_counters().contains("Food-days %s" % UNPOPULATED),
		"the counter returned to unpopulated, got '%s'" % _rendered_counters())


func test_status_readout_forwards_the_game_managers_own_values() -> void:
	"""State, speed and calendar reach the top-right zone as GameManager reports them."""
	_ui.register_hud(_hud)
	var expected: String = "%s  x%d  %s" % [
		GameManager.get_state_name().capitalize(),
		GameManager.get_speed(),
		GameManager.get_calendar_text(),
	]
	assert_equal(_rendered_status(), expected, "the status line is GameManager's, unedited")


# --- binding lifecycle -------------------------------------------------------------------------

func test_register_hud_refuses_null_and_stays_unbound() -> void:
	"""A null HUD is refused explicitly; a later push_alert must not act on it.

	The refusal is a push_error, so this test deliberately prints one ERROR line to the runner.
	"""
	_ui.register_hud(null)
	_ui.push_alert("Mossflower stirs.")
	assert_equal(_rendered_alert(), "", "nothing was painted into an unbound HUD")


func test_unregister_hud_stops_further_repaints() -> void:
	"""After the HUD scene leaves, a stock change must not reach the departed interface."""
	assert_true(EconomySystem.deposit(&"wood", 180 * MILLI), "the §5.1 wood arrives")
	_ui.register_hud(_hud)
	assert_true(_rendered_counters().contains("Wood %s" % STARTER_WOOD_TEXT), "wood is painted")
	_ui.unregister_hud()
	assert_true(EconomySystem.deposit(&"wood", 20 * MILLI), "more wood arrives")
	_ui._on_stocks_changed()
	assert_true(_rendered_counters().contains("Wood %s" % STARTER_WOOD_TEXT),
		"the unregistered HUD kept its last painted line")


func test_a_freed_hud_is_never_written_to() -> void:
	"""A freed Object still compares != null, so the guard must use is_instance_valid()."""
	var scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	var doomed: HudScript = scene.instantiate() as HudScript
	doomed._ready()
	_ui.register_hud(doomed)
	doomed.free()
	_ui.push_alert("Out of ration!")
	_ui._on_stocks_changed()
	assert_true(true, "writing to a freed HUD did not crash the router")


func test_depletion_and_diagnostics_reach_the_alert_zone() -> void:
	"""Both alert sources name their subject rather than showing a generic message.

	CHANGED BY R-UI-ALERT-001. The alert zone used to be a single label that the next message
	overwrote, so this asserted that each message in turn was the one painted. It is now a
	retained notice record under §7's ordering -- "severity descending, then earliest tick" --
	so the earlier of two equal-severity conditions keeps the card and the later one is retained
	beside it rather than destroying it. The property this test exists for is unchanged and is
	asserted harder: each source's own sentence survives BYTE FOR BYTE, and neither is replaced
	by a generic line. `test_ui_shell.gd` covers which of the two the card shows.
	"""
	_ui.register_hud(_hud)
	_ui._on_stock_depleted(&"ration")
	assert_equal(_rendered_alert(), "Out of ration!", "the depleted item is named")
	_ui._on_clock_diagnostic("Scheduler overloaded; speed reduced to 2x.")
	var notices: UiNoticesScript = _hud.shell().notices()
	assert_equal(notices.count(), 2, "both conditions are retained, not overwritten")
	assert_true(_retained_messages(notices).has("Out of ration!"),
		"the depleted item is still named in full")
	assert_true(_retained_messages(notices).has("Scheduler overloaded; speed reduced to 2x."),
		"and the diagnostic is retained verbatim")


func _retained_messages(notices: UiNoticesScript) -> PackedStringArray:
	"""Every retained notice's ORIGINAL message, in §7's display order."""
	var order: PackedInt32Array = PackedInt32Array()
	order.resize(notices.capacity())
	var written: int = notices.order_into(order)
	var out: PackedStringArray = PackedStringArray()
	var notice: UiNoticesScript.Notice = UiNoticesScript.Notice.new()
	for index: int in written:
		if notices.notice_into(order[index], 0, notice):
			out.append(notice.message)
	return out


# --- UI-SET-103's paused opening ----------------------------------------------------------------

func test_the_world_opens_paused_for_inspection_with_the_player_reason() -> void:
	"""§4.3: "Generation succeeds into paused world inspection with PLAYER pause"."""
	var manager: GameManagerScript = GameManagerScript.new()
	_ui.bind_time_source(manager)
	manager.start_game()
	assert_false(manager.is_paused(), "the clock's own start leaves the world running")
	_ui._on_state_changed(STATE_PLAYING)
	assert_true(manager.is_paused(), "the interface holds the opening inspection pause")
	assert_true(manager.get_pause_reason_names().has(PLAYER_REASON), "and it is the PLAYER reason")
	assert_equal(manager.get_effective_speed(), 0, "so no tick advances")
	manager.free()


func test_the_opening_pause_retains_the_requested_speed() -> void:
	"""A pause is not a speed change: §3 keeps "Requested 1x/2x/4x speed ... separately"."""
	var manager: GameManagerScript = GameManagerScript.new()
	_ui.bind_time_source(manager)
	manager.start_game()
	manager.set_speed(4)
	_ui._on_state_changed(STATE_PLAYING)
	assert_equal(manager.get_speed(), 4, "the requested speed survives the pause")
	assert_equal(manager.get_effective_speed(), 0, "while nothing is actually simulated")
	manager.free()


func test_the_first_resume_hands_time_to_the_player_and_is_not_undone() -> void:
	"""§4.3: "the first Resume starts tick advancement", and nothing re-pauses behind them."""
	var manager: GameManagerScript = GameManagerScript.new()
	_ui.bind_time_source(manager)
	manager.start_game()
	_ui._on_state_changed(STATE_PLAYING)
	assert_false(_ui.player_has_resumed(), "the player has not resumed yet")
	manager.resume_game()
	_ui._on_state_changed(STATE_PLAYING)
	assert_true(_ui.player_has_resumed(), "the interface records the player's resume")
	assert_false(manager.is_paused(), "and does not pause the world a second time")
	assert_equal(manager.get_effective_speed(), 1, "ticks advance at the requested speed")
	manager.free()


func test_the_opening_pause_refuses_before_the_clock_has_started() -> void:
	"""`pause_game()` does nothing on an unstarted clock, so claiming success would be false."""
	var manager: GameManagerScript = GameManagerScript.new()
	_ui.bind_time_source(manager)
	assert_false(_ui.apply_opening_pause(), "pausing a BOOT clock refuses")
	assert_equal(_ui.last_refusal(), &"UI_CLOCK_NOT_STARTED", "with a named code")
	assert_false(_ui.opening_pause_applied(), "and no inspection pause is claimed")
	manager.free()


# --- every action leaves through the command queue -------------------------------------------

func test_the_interface_exposes_a_command_bridge_and_starts_with_no_orders() -> void:
	"""04.4 opens with "empty initial orders"; a pending entry at boot would be invented intent."""
	var bridge: UiCommandBridgeScript = _ui.command_bridge()
	assert_not_null(bridge, "the interface has a command bridge")
	assert_equal(bridge.submitted_count(), 0, "no player action has been issued")
	assert_equal(bridge.pending_count(), 0, "and nothing is queued")


func test_a_refusal_reaches_the_accessible_error_display_with_its_code() -> void:
	"""04.4: "accessible refusal display". The code must survive to the screen reader."""
	_ui.register_hud(_hud)
	_ui.push_refusal(&"COMMAND_JOB_NOT_CANCELLABLE")
	var panel: Control = _hud.shell().control_for(ERROR_PANEL_ID)
	assert_true(panel.visible, "the error panel is shown")
	assert_true(panel.accessibility_description.contains("COMMAND_JOB_NOT_CANCELLABLE"),
		"the exact refusal code is in the accessible description")
	assert_true(panel.accessibility_description.length() > 40, "alongside its plain reading")


func test_an_unknown_refusal_code_is_still_displayed_rather_than_swallowed() -> void:
	"""A code this milestone does not recognise is more useful on screen than an apology."""
	_ui.register_hud(_hud)
	_ui.push_refusal(&"SOME_CODE_FROM_A_LATER_TASK")
	var panel: Control = _hud.shell().control_for(ERROR_PANEL_ID)
	assert_true(panel.accessibility_description.contains("SOME_CODE_FROM_A_LATER_TASK"),
		"the unknown code is shown verbatim")
	_ui.push_refusal(&"")
	assert_false(panel.visible, "and no refusal closes the panel")


# --- UI-SET-103's Create runs the real generator into the running settlement --------------------

func test_the_create_action_generates_the_authored_world_into_the_live_stores() -> void:
	"""04.4 bullet 1's first clause: New Settlement wired to real state, not to a mock.

	This drives the SettlementSystem autoload, which is the running game's own store set, and
	then returns it to the empty state the runner started it in.
	"""
	assert_equal(SettlementSystem.ecology().resource_nodes().count(), 0, "the world starts empty")
	assert_true(_ui.create_world(), "Create succeeds (error: %s)" % _ui.world_session().last_refusal())
	var report: UiWorldSessionScript.Report = _ui.world_session().last_report()
	assert_equal(report.resource_nodes, GENERATED_RESOURCE_NODES, "§5.1's 1695 resource nodes")
	assert_equal(SettlementSystem.ecology().resource_nodes().count(), GENERATED_RESOURCE_NODES,
		"and they are in the running settlement's own store")
	assert_true(_ui.world_session().has_world(), "the session holds the published map")
	SettlementSystem.reset()


func test_a_generated_world_is_populated_and_beds_stay_unpopulated() -> void:
	"""REPLACES test_a_generated_world_has_no_residents_and_the_counter_says_so.

	That test asserted `living_count() == 0` after Create -- it PINNED THE DEFECT. Decision 0071
	made generation and the cohort one operation at boot, and UI-SET-103's Create kept the
	poorer path, so pressing it emptied the settlement it had just generated. The old assertion
	is retired because the behaviour it described was wrong, not because it became inconvenient.

	Beds are still UNPOPULATED, and that half is unchanged: no Building, Furniture or Room store
	exists, so a bed count would be a fabricated zero. Residents and Beds are a §1.1 pair and
	only one of them has an owner."""
	_ui.register_hud(_hud)
	assert_true(_ui.create_world(), "Create succeeds")
	assert_equal(SettlementSystem.residents().living_count(), 12,
		"and §5.1's twelve residents live in the world it generated")
	assert_true(_rendered_counters().contains("Beds %s" % UNPOPULATED),
		"while beds stay unpopulated, not drawn as a zero nothing measured")
	SettlementSystem.reset()


func test_the_generation_report_reaches_the_player_with_its_own_counts() -> void:
	"""The player is told what was made, in the generator's own figures."""
	_ui.register_hud(_hud)
	assert_true(_ui.create_world(), "Create succeeds")
	assert_true(_rendered_alert().contains("1695"), "the node count is reported: '%s'"
		% _rendered_alert())
	assert_true(_rendered_alert().contains("20260905"), "and the accepted seed")
	SettlementSystem.reset()


func test_a_refused_generation_reports_the_generators_own_code() -> void:
	"""An unauthored architecture must refuse visibly, not quietly produce the abbey."""
	_ui.register_hud(_hud)
	_ui.world_session().set_architecture(ARCHITECTURE_HOLT)
	assert_false(_ui.create_world(), "Create refuses")
	var panel: Control = _hud.shell().control_for(ERROR_PANEL_ID)
	assert_true(panel.visible, "the refusal is shown")
	assert_true(panel.accessibility_description.contains("UI_ARCHITECTURE_NOT_AUTHORED"),
		"with the exact code: '%s'" % panel.accessibility_description)
	assert_equal(SettlementSystem.ecology().resource_nodes().count(), 0, "and nothing was made")
	SettlementSystem.reset()


# --- the roster and the resident detail read real residents -------------------------------------

func test_the_roster_lists_the_living_residents_from_the_store() -> void:
	"""FP-01's resident selection: the rows are the settlement's own residents, not a fixture."""
	_ui.register_hud(_hud)
	assert_true(SettlementSystem.create_initial_settlement(),
		"the §5.1 cohort is created: %s" % SettlementSystem.last_refusal())
	assert_true(_ui.refresh_roster(), "the roster fills")
	var shell: UiShellScript = _hud.shell()
	assert_equal(shell.roster_shown(), STARTER_COHORT, "all twelve rows are shown")
	## UPDATED: the row now formats health through `ui_resident_card.gd`, the same function the
	## journal uses, so its wording is "Health 100 / 100" rather than a second lowercase copy
	## of the same rule. The property asserted is unchanged -- the row carries a real health
	## figure from the store -- and it is now checked against the store's own value.
	var health: int = SettlementSystem.needs().health_of(0).value
	assert_true(shell.roster_row(0).text.contains("Health %d / 100" % health),
		"a row carries the facts the stores publish: '%s'" % shell.roster_row(0).text)
	SettlementSystem.reset()


func test_choosing_a_roster_row_opens_that_residents_real_detail() -> void:
	"""REQ-UX-013: the row resolves to a resident identity, not to a render index.

	UPDATED for UXV-019/020/021, and both changes are behaviour this suite previously pinned
	the WRONG way round. §4.1: "A name is a heading, not a dense concatenation of
	name/species/health in one line", so the title is no longer the roster row's whole text and
	the species moved to its own line. And the need row printed `Hunger 7500 of 10000`, which
	UXV-020 names as the exact failure -- "never expose 7500 as the player-facing 75% value" --
	while UXV-021 fixes the visible label as `Fullness`. The old assertions REQUIRED both
	defects, so they are replaced rather than relaxed: the row must now carry the percent and
	must not carry the basis points.
	"""
	_ui.register_hud(_hud)
	assert_true(SettlementSystem.create_initial_settlement(), "the cohort is created")
	assert_true(_ui.refresh_roster(), "the roster fills")
	var shell: UiShellScript = _hud.shell()
	shell.roster_row(2).emit_signal(&"pressed")
	var title: Label = shell.control_for(DETAIL_TITLE_ID) as Label
	assert_true(shell.roster_row(2).text.begins_with(title.text),
		"the heading is that same resident's name: '%s'" % title.text)
	assert_true(shell.detail_identity_label().text.contains("mouse"),
		"the species is its own line: '%s'" % shell.detail_identity_label().text)
	var fullness: String = shell.need_row_text(0)
	assert_true(fullness.contains("Fullness"), "UXV-021's visible label: '%s'" % fullness)
	assert_false(fullness.contains("Hunger"), "and never the raw field name")
	assert_true(fullness.contains("75%"), "UXV-020's exact percent of 7500 basis points")
	assert_false(fullness.contains("7500"), "and never the basis points themselves")
	assert_false(fullness.contains("10000"), "nor the scale they are measured against")
	SettlementSystem.reset()


func test_all_five_need_rows_reach_the_card_for_a_real_resident() -> void:
	"""UXV-020 requires five rows on screen, not five rows composed and one routed."""
	_ui.register_hud(_hud)
	assert_true(SettlementSystem.create_initial_settlement(), "the cohort is created")
	assert_true(_ui.refresh_roster(), "the roster fills")
	var shell: UiShellScript = _hud.shell()
	shell.roster_row(0).emit_signal(&"pressed")
	assert_equal(shell.need_rows_shown(), NEED_ROW_COUNT, "all five rows are filled and shown")
	var labels: PackedStringArray = PackedStringArray()
	for index: int in NEED_ROW_COUNT:
		labels.append(shell.need_row_text(index))
	assert_true(labels[1].contains("Rest"), "row 2 is Rest: '%s'" % labels[1])
	assert_true(labels[2].contains("Comfort"), "row 3 is Comfort: '%s'" % labels[2])
	assert_true(labels[3].contains("Social"), "row 4 is Social: '%s'" % labels[3])
	assert_true(labels[4].contains("Purpose"), "row 5 is Purpose: '%s'" % labels[4])
	SettlementSystem.reset()


func test_the_four_rows_with_no_published_rate_say_so_on_screen() -> void:
	"""§5: "If rate isn't published, say Rate unavailable" -- and never a fabricated 0.00."""
	_ui.register_hud(_hud)
	assert_true(SettlementSystem.create_initial_settlement(), "the cohort is created")
	assert_true(_ui.refresh_roster(), "the roster fills")
	var shell: UiShellScript = _hud.shell()
	shell.roster_row(0).emit_signal(&"pressed")
	assert_true(shell.need_row_text(0).contains("pp/h"),
		"Fullness carries its published rate: '%s'" % shell.need_row_text(0))
	for index: int in [1, 2, 3, 4]:
		var text: String = shell.need_row_text(index)
		assert_true(text.contains("Rate unavailable"), "row %d says so: '%s'" % [index, text])
		assert_false(text.contains("0.00"), "row %d prints no invented zero" % index)
	SettlementSystem.reset()


func test_a_real_residents_species_medallion_is_loaded_and_identified_as_generic() -> void:
	"""ART-UI-06/UXV-019: the roundel is loaded from the store's species and named as generic."""
	_ui.register_hud(_hud)
	assert_true(SettlementSystem.create_initial_settlement(), "the cohort is created")
	assert_true(_ui.refresh_roster(), "the roster fills")
	var shell: UiShellScript = _hud.shell()
	shell.roster_row(0).emit_signal(&"pressed")
	assert_true(shell.detail_emblem().visible, "the medallion is shown")
	assert_not_null(shell.detail_emblem().texture, "with a real texture behind it")
	assert_true(shell.control_for(DETAIL_ID).accessibility_description.contains("not a portrait"),
		"and the panel says it is not a portrait")
	assert_true(shell.detail_note_label().text.contains("generic mark"),
		"as does the visible note: '%s'" % shell.detail_note_label().text)
	SettlementSystem.reset()


func test_the_card_states_that_age_is_unavailable_rather_than_inventing_one() -> void:
	"""UXV-019 asks for age; `residents.gd` has no age or birth column, so the card says so."""
	_ui.register_hud(_hud)
	assert_true(SettlementSystem.create_initial_settlement(), "the cohort is created")
	assert_true(_ui.refresh_roster(), "the roster fills")
	var shell: UiShellScript = _hud.shell()
	shell.roster_row(0).emit_signal(&"pressed")
	assert_true(shell.detail_note_label().text.contains("Age unavailable"),
		"the absence is stated: '%s'" % shell.detail_note_label().text)
	SettlementSystem.reset()


func test_health_and_activity_reach_their_own_lines_from_the_stores() -> void:
	"""UXV-019/022: health is its own row and activity uses the published status."""
	_ui.register_hud(_hud)
	assert_true(SettlementSystem.create_initial_settlement(), "the cohort is created")
	assert_true(_ui.refresh_roster(), "the roster fills")
	var shell: UiShellScript = _hud.shell()
	shell.roster_row(0).emit_signal(&"pressed")
	assert_equal(shell.detail_health_label().text, "Health 100 / 100",
		"health is on the GDD's own 0-100 scale")
	assert_true(shell.detail_activity_label().text.contains("Active"),
		"and the activity line is the published status: '%s'"
		% shell.detail_activity_label().text)
	SettlementSystem.reset()


func test_an_empty_settlement_shows_no_roster_rows_rather_than_placeholders() -> void:
	"""A settlement with nobody in it must show nothing, not twelve blank rows."""
	_ui.register_hud(_hud)
	assert_equal(SettlementSystem.residents().living_count(), 0, "nobody lives here")
	assert_true(_ui.refresh_roster(), "the roster refreshes")
	assert_equal(_hud.shell().roster_shown(), 0, "and shows no rows at all")


# --- a true zero is not an undefined value -----------------------------------------------------

func test_an_absent_residents_store_is_unpopulated_and_an_empty_one_is_zero() -> void:
	"""The visual direction: "do not display zero food-days when the value is undefined".

	Three different absences must read differently. With NO residents store bound the population
	is undefined and renders the marker; with an EMPTY store bound it is a measured zero and
	renders 0. A single renderer that printed 0 for both would pass every other test here.
	"""
	_ui.register_hud(_hud)
	assert_false(EconomySystem.has_residents(), "no residents store is bound")
	assert_true(_rendered_counters().contains("Residents %s" % UNPOPULATED),
		"an absent store is unpopulated, got '%s'" % _rendered_counters())
	assert_false(_rendered_counters().contains("Residents 0"), "and never a fabricated zero")
	_residents = ResidentsScript.new()
	EconomySystem.bind_residents(_residents)
	assert_equal(_residents.living_count(), 0, "the bound store really is empty")
	_ui._on_stocks_changed()
	assert_true(_rendered_counters().contains("Residents 0"),
		"a measured zero is shown as 0, got '%s'" % _rendered_counters())


# --- R-UI-ALERT-001: every routed condition names itself ------------------------------------------

func test_a_refused_generation_becomes_an_error_notice_with_the_ruling_s_title() -> void:
	"""R-UI-ALERT-001 names this condition: severity `Error`, title `Generation failed`.

	The refusal is raised through the real router, not by calling the shell directly, so a change
	that routed the failure to the error panel alone -- leaving the alert card showing the last
	SUCCESS -- would fail here. The generator's own code and detail must survive into the record.
	"""
	_ui.register_hud(_hud)
	var report: UiWorldSessionScript.Report = UiWorldSessionScript.Report.new()
	report.error = &"WORLD_OCCUPIED"
	report.detail = "the settlement already has living residents."
	_ui._report_generation(false, report)
	var notice: UiNoticesScript.Notice = UiNoticesScript.Notice.new()
	assert_true(_hud.shell().card_notice_into(notice), "a notice reached the card")
	assert_equal(notice.severity_word, "Error", "with the ruling's severity")
	assert_equal(notice.title, "Generation failed", "and the ruling's compact title")
	assert_true(notice.message.contains("WORLD_OCCUPIED"), "the generator's own code is in the message")
	assert_true(notice.message.contains(report.detail), "and its own detail")
	assert_equal(notice.code, "WORLD_OCCUPIED", "the validation code is recorded as the code")
	assert_true(notice.recovery.length() > 0, "and a recovery action is published")


func test_the_refusal_still_fills_the_error_panel_as_well_as_the_card() -> void:
	"""§4 keeps UI-SET-085's "Error code+plain reason+recovery action" for a fault."""
	_ui.register_hud(_hud)
	var report: UiWorldSessionScript.Report = UiWorldSessionScript.Report.new()
	report.error = &"WORLD_OCCUPIED"
	report.detail = "the settlement already has living residents."
	_ui._report_generation(false, report)
	var panel: Control = _hud.shell().control_for(ERROR_PANEL_ID)
	assert_true(panel.visible, "the error panel opens for the fault")
	assert_true(panel.accessibility_description.contains("WORLD_OCCUPIED"),
		"and carries the exact code, as it did before the ruling")


func test_a_command_refusal_is_retained_as_a_retrievable_error_notice() -> void:
	"""UI-SET-085 is cleared by the next accepted action; the notice is what outlives it."""
	_ui.register_hud(_hud)
	_ui.push_refusal(&"COMMAND_JOB_NOT_CANCELLABLE")
	var notice: UiNoticesScript.Notice = UiNoticesScript.Notice.new()
	assert_true(_hud.shell().card_notice_into(notice), "the refusal reached the card")
	assert_equal(notice.title, "Action refused", "with its own authored title")
	assert_equal(notice.code, "COMMAND_JOB_NOT_CANCELLABLE", "and the exact refusal code")
	assert_true(notice.message.length() > 0, "and the bridge's plain sentence")


func test_a_depletion_names_the_item_as_its_source_so_two_items_stay_two_notices() -> void:
	"""§7 groups on code AND source; the item is the source, so ration and grain do not merge."""
	_ui.register_hud(_hud)
	_ui._on_stock_depleted(&"ration")
	_ui._on_stock_depleted(&"grain")
	_ui._on_stock_depleted(&"ration")
	assert_equal(_hud.shell().notices().count(), 2,
		"two items are two conditions and the repeat groups onto the first")
	assert_true(_retained_messages(_hud.shell().notices()).has("Out of grain!"),
		"and each item is named in its own message")


func test_the_create_button_gives_the_cohort_persistent_ids_one_to_twelve() -> void:
	"""R-INIT-ID-001 through UI-SET-103's Create, not only through boot.

	THE DEFECT THIS PINS. `create_world()` used `_session.create_into()`, which runs
	`world_init.generate()` -- the standalone wrapper whose `_publish()` calls `_reset_stores()`,
	clearing the directory and the persistent-id counter, and then publishes 1713 world entities
	before any resident exists. So pressing Create gave Warden Rowan id 1714 while booting gave
	her 1: the same seed and the same authored scenario producing two different identities, which
	§5.3's `hash(persistent_id, world_seed)` naming and any future state digest hang off.

	`world_init.gd` states the contract the old path violated -- the reset wrapper is kept "for
	isolated controls" and the composed initializer must not use it, "which is exactly how ids
	1-12 were lost". `create_world()` is a composed initializer.

	The old tests asserted node counts and `living_count() == 12` and never asserted an id, which
	is why the divergence was invisible to the suite. This asserts the id.
	"""
	_ui.register_hud(_hud)
	assert_true(_ui.create_world(), "Create succeeds")
	var residents: ResidentsScript = SettlementSystem.residents()
	var warden: IntMath.IntResult = residents.persistent_id_of(ResidentsScript.WARDEN_INDEX)
	assert_true(warden.ok, "the Warden has a persistent id")
	assert_equal(warden.value, 1, "and it is 1, exactly as booting gives her")
	for index: int in ResidentsScript.INITIAL_POPULATION:
		var id: IntMath.IntResult = residents.persistent_id_of(index)
		assert_true(id.ok, "cohort row %d has an id" % index)
		assert_equal(id.value, index + 1, "cohort row %d is persistent id %d" % [index, index + 1])
	SettlementSystem.reset()
