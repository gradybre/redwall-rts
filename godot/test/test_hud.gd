extends "res://test/framework/test_case.gd"
## Coverage for the last mile of the counter path: what the HUD actually paints into its labels.
##
## Every other suite in this repository stops one call short of the screen. It checks that
## EconomySystem computed "5.48" and that it refuses fuel-days, and then trusts the renderer.
## That trust was misplaced: rounding the caller's string, redefining the UNPOPULATED marker as
## "0.00", or halving every integer counter are all invisible to a suite that never reads a
## Label. Each assertion below reads `Root/ResourceZone/ResourceLabel.text` and compares it to a
## string this file builds itself, so a fabricated figure has nowhere to hide.
##
## The renderer's contract, restated from hud.gd: `set_counter_text()` prints the caller's
## string byte for byte and `set_counter()` prints the caller's integer unaltered. The HUD
## derives nothing.
##
## WHY `_ready()` IS CALLED BY HAND. The headless runner is a SceneTree `_initialize()`, and at
## that point `SceneTree.root` is itself not yet inside the tree: `root.add_child(hud)` leaves
## `hud.is_inside_tree()` false and NOTIFICATION_READY never fires, so every `@onready` label
## stays null. Invoking `_ready()` directly runs the same generated `@onready` initialisation
## against the instantiated scene's own children, which `$Root/...` resolves off-tree. This is a
## property of the runner, not of the HUD.

const HudScript := preload("res://scripts/ui/hud.gd")
const EconomySystemScript := preload("res://scripts/systems/economy_system.gd")

const HUD_SCENE_PATH: String = "res://scenes/ui/hud.tscn"

## UI §1.1 counter order and the separator between counters, restated here rather than read back
## out of hud.gd, so a reordered or re-joined line cannot rewrite this suite's expectation.
const EXPECTED_COUNTER_ORDER: Array[StringName] = [
	&"Food-days", &"Ready NP", &"Fuel-days", &"Wood", &"Stone", &"Residents", &"Beds",
]
const EXPECTED_SEPARATOR: String = "   "

## The honesty marker itself, stated independently. It is the whole point of the UNPOPULATED
## contract that this is not a number.
const EXPECTED_UNPOPULATED: String = "--"

## Strings a formatting renderer would mangle: a two-decimal food-days figure, a significant
## trailing zero, a value that is already an integer, and a leading-zero fraction.
const VERBATIM_TEXTS: Array[String] = ["5.48", "5.40", "0.07", "12", "1000.05", "4.56"]

var _hud: HudScript = null


func before_each() -> void:
	"""Instantiate the real hud.tscn and run its ready hook, so the labels exist."""
	var scene: PackedScene = load(HUD_SCENE_PATH) as PackedScene
	_hud = scene.instantiate() as HudScript
	_hud._ready()


func after_each() -> void:
	"""Free the HUD instantiated for the test, children included."""
	if _hud != null:
		_hud.free()
		_hud = null


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


func _expected_counters(supplied: Dictionary) -> String:
	"""Build the counter line this suite expects: supplied values, then the marker for the rest."""
	var parts: PackedStringArray = PackedStringArray()
	for label: StringName in EXPECTED_COUNTER_ORDER:
		var text: String = supplied.get(label, EXPECTED_UNPOPULATED)
		parts.append("%s %s" % [label, text])
	return EXPECTED_SEPARATOR.join(parts)


# --- set_counter_text: the caller's string, byte for byte -------------------------------------

func test_counter_text_is_rendered_verbatim() -> void:
	"""GDD §5.8's two-decimal food-days figure reaches the label exactly as it was supplied."""
	_hud.set_counter_text(&"Food-days", "5.48")
	assert_equal(_rendered_counters(), _expected_counters({&"Food-days": "5.48"}),
		"the whole counter line renders with food-days verbatim")
	assert_true(_rendered_counters().contains("Food-days 5.48"),
		"the supplied string is on screen unchanged")


func test_no_supplied_string_is_reformatted_rounded_or_truncated() -> void:
	"""Every shape of value survives the renderer: trailing zeros, integers and long fractions."""
	for text: String in VERBATIM_TEXTS:
		_hud.clear_counters()
		_hud.set_counter_text(&"Food-days", text)
		assert_equal(_rendered_counters(), _expected_counters({&"Food-days": text}),
			"'%s' renders verbatim" % text)


func test_unsupplied_counters_render_the_unpopulated_marker() -> void:
	"""A counter nobody supplied is marked unpopulated, never filled in with a zero."""
	assert_equal(_rendered_counters(), _expected_counters({}),
		"a fresh HUD marks all seven counters unpopulated")
	assert_equal(HudScript.UNPOPULATED, EXPECTED_UNPOPULATED,
		"the marker is the honesty marker, not a number")
	assert_false(_rendered_counters().contains("0"),
		"no digit appears anywhere on a line with no supplied value")


func test_supplying_one_counter_leaves_the_others_unpopulated() -> void:
	"""Fuel-days, Residents and Beds stay marked while food-days is populated."""
	_hud.set_counter_text(&"Food-days", "5.48")
	_hud.set_counter(&"Ready NP", 408000, "NP")
	assert_true(_rendered_counters().contains("Fuel-days %s" % EXPECTED_UNPOPULATED),
		"fuel-days is still unpopulated")
	assert_true(_rendered_counters().contains("Residents %s" % EXPECTED_UNPOPULATED),
		"residents is still unpopulated")
	assert_true(_rendered_counters().contains("Beds %s" % EXPECTED_UNPOPULATED),
		"beds is still unpopulated")


func test_clear_counters_returns_the_line_to_unpopulated() -> void:
	"""Dropping recorded values restores the marker rather than freezing the last figure."""
	_hud.set_counter_text(&"Food-days", "5.48")
	_hud.set_counter(&"Wood", 180, "U")
	_hud.clear_counters()
	assert_equal(_rendered_counters(), _expected_counters({}),
		"every counter returned to the unpopulated marker")


# --- the marker agrees with the system that refuses ------------------------------------------

func test_hud_marker_matches_the_economy_systems_marker() -> void:
	"""A refusal from EconomySystem and an unsupplied HUD counter must read identically."""
	assert_equal(HudScript.UNPOPULATED, EconomySystemScript.UNPOPULATED_TEXT,
		"one unpopulated marker, not two")


func test_a_refused_food_days_figure_renders_as_the_marker() -> void:
	"""An economy with no residents bound refuses food-days, and that refusal reaches the label."""
	var economy: EconomySystemScript = EconomySystemScript.new()
	assert_false(economy.has_residents(), "nothing supplies the divisor")
	var refused_text: String = economy.food_days_text()
	_hud.set_counter_text(&"Food-days", refused_text)
	assert_equal(_rendered_counters(), _expected_counters({&"Food-days": EXPECTED_UNPOPULATED}),
		"the refusal renders as the marker, not as a zero")
	economy.free()


# --- set_counter: the caller's integer, unaltered ---------------------------------------------

func test_integer_counters_render_the_supplied_value_unmodified() -> void:
	"""Odd and even magnitudes alike are printed as given, with UI §2.2 comma grouping only."""
	var samples: Dictionary = {
		0: "0", 7: "7", 12: "12", 999: "999", 1000: "1,000",
		12345: "12,345", 180: "180", 408000: "408,000", 1234567: "1,234,567",
	}
	for value: int in samples:
		_hud.clear_counters()
		_hud.set_counter(&"Ready NP", value, "NP")
		var expected: String = "%s NP" % samples[value]
		assert_equal(_rendered_counters(), _expected_counters({&"Ready NP": expected}),
			"%d renders as '%s'" % [value, expected])


func test_negative_integer_counters_keep_their_sign_and_grouping() -> void:
	"""A negative counter is rendered as a negative number, not as an absolute value."""
	_hud.set_counter(&"Wood", -4200, "U")
	assert_equal(_rendered_counters(), _expected_counters({&"Wood": "-4,200 U"}),
		"the sign and the grouping both survive")


func test_an_empty_unit_renders_the_bare_number() -> void:
	"""Counters with no unit (Residents, Beds) render the integer with no trailing space."""
	_hud.set_counter(&"Residents", 12, "")
	assert_equal(_rendered_counters(), _expected_counters({&"Residents": "12"}),
		"no unit means no unit suffix")


func test_the_starter_fixture_numerator_reaches_the_label_intact() -> void:
	"""GDD §7.1's 408000 ready NP must appear on screen as 408,000, not a scaled figure."""
	_hud.set_counter(&"Ready NP", 408000, "NP")
	assert_true(_rendered_counters().contains("Ready NP 408,000 NP"),
		"the §7.1 numerator is rendered unscaled")
	assert_false(_rendered_counters().contains("204,000"), "the value was not halved")


# --- status and alert zones -------------------------------------------------------------------

func test_status_zone_renders_state_speed_and_calendar() -> void:
	"""The top-right readout is state, selected speed and the offset-calendar date."""
	_hud.set_status("playing", 4, "Y1 spring 1")
	assert_equal(_rendered_status(), "Playing  x4  Y1 spring 1", "the status line renders in full")


func test_alert_is_shown_then_expires_after_its_hold_time() -> void:
	"""An alert holds for ALERT_HOLD_SECONDS of process time and then clears itself."""
	_hud.show_alert("Out of ration!")
	assert_equal(_rendered_alert(), "Out of ration!", "the alert is on screen")
	_hud._process(HudScript.ALERT_HOLD_SECONDS / 2.0)
	assert_equal(_rendered_alert(), "Out of ration!", "it is still held at half its hold time")
	_hud._process(HudScript.ALERT_HOLD_SECONDS)
	assert_equal(_rendered_alert(), "", "it expired once the hold time elapsed")
