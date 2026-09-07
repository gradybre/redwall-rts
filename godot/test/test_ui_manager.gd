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

const HUD_SCENE_PATH: String = "res://scenes/ui/hud.tscn"
const RESOURCE_LABEL_PATH: String = "Root/ResourceZone/ResourceLabel"
const ALERT_LABEL_PATH: String = "Root/AlertZone/AlertLabel"
const STATUS_LABEL_PATH: String = "Root/StatusZone/StatusLabel"

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
	"""The exact text currently painted into the top-left resource label."""
	return (_hud.get_node(RESOURCE_LABEL_PATH) as Label).text


func _rendered_alert() -> String:
	"""The exact text currently painted into the top-centre alert label."""
	return (_hud.get_node(ALERT_LABEL_PATH) as Label).text


func _rendered_status() -> String:
	"""The exact text currently painted into the top-right status label."""
	return (_hud.get_node(STATUS_LABEL_PATH) as Label).text


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
	"""All five supplied counters render the §7.1/§5.1 figures; the other two stay unpopulated."""
	_seed_starting_settlement()
	_ui.register_hud(_hud)
	var line: String = _rendered_counters()
	assert_true(line.contains("Ready NP %s" % STARTER_READY_NP_TEXT), "ready NP is 408,000 NP")
	assert_true(line.contains("Wood %s" % STARTER_WOOD_TEXT), "wood is 180 U")
	assert_true(line.contains("Stone %s" % STARTER_STONE_TEXT), "stone is 100 U")
	assert_true(line.contains("Fuel-days %s" % UNPOPULATED), "fuel-days stays unpopulated")
	assert_true(line.contains("Residents %s" % UNPOPULATED), "residents stays unpopulated")
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
	"""Both alert sources name their subject rather than showing a generic message."""
	_ui.register_hud(_hud)
	_ui._on_stock_depleted(&"ration")
	assert_equal(_rendered_alert(), "Out of ration!", "the depleted item is named")
	_ui._on_clock_diagnostic("Scheduler overloaded; speed reduced to 2x.")
	assert_equal(_rendered_alert(), "Scheduler overloaded; speed reduced to 2x.",
		"the diagnostic is surfaced verbatim")
