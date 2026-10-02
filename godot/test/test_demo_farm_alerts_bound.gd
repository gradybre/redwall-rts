extends "res://test/framework/test_case.gd"
## The farm's alert lines are said once a day (or once a season, a forecast's) and the keys of the days before are let
## go (farm_alerts.gd `_said`; decision 0923). Kept for good they grew a few keys every game day for as long as the
## village ran (found by the soak test, decision 0921). Letting them go must change no line said.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const AlertsScript := preload("res://demo/farm/farm_alerts.gd")

const HOUR_USEC: int = 25000000
const DAYS: int = 30
const BED_EMPTY_CLAY: int = 1
const WHEAT: int = 13


## A farm whose forecast and day the test sets.
class ForecastSim extends SimScript:
	var event: int = -1
	var day: int = 1

	func forecast_event() -> int:
		"""As set."""
		return event

	func absolute_day() -> int:
		"""As set."""
		return day


## The alerts as they were: no key ever let go (the reference the bounded one must match line for line).
class KeepEverything extends AlertsScript:
	func _forget_before(_day: int) -> void:
		"""Never let a key go."""
		pass


func test_letting_old_keys_go_says_the_same_lines_and_stays_bounded() -> void:
	"""Thirty game days hour by hour, the same events to both: identical lines every hour; the kept keys stay within a
	day's worth while the old way's grow."""
	var sim := SimScript.new()
	sim.choose(BED_EMPTY_CLAY, WHEAT)
	assert_true(sim.sow_start(BED_EMPTY_CLAY).ok and sim.sow_finish(BED_EMPTY_CLAY).ok, "wheat sown")
	var bounded := AlertsScript.new()
	var reference := KeepEverything.new()
	var events := PackedInt32Array()
	var said: int = 0
	var most: int = 0
	for hour: int in 24 * DAYS:
		sim.advance_usec(HOUR_USEC)
		events.clear()
		sim.take_events_into(events)
		var lines := PackedStringArray()
		var expected := PackedStringArray()
		bounded.collect_into(sim, events, PackedInt32Array(), lines)
		reference.collect_into(sim, events, PackedInt32Array(), expected)
		if lines != expected:
			fail("hour %d: %s, the old way %s" % [hour, lines, expected])
			return
		said += lines.size()
		most = maxi(most, bounded.said_count())
	assert_true(said > DAYS, "lines were said (%d)" % said)
	assert_true(most <= 40, "at most a day's keys kept: %d" % most)
	assert_true(reference.said_count() > 2 * most, "the old way kept %d" % reference.said_count())


func test_a_forecast_is_said_once_a_season_and_again_the_next() -> void:
	"""The same forecast hour after hour is said once; another event the same season is said; the first event comes
	round again in the next season and is said again; two seasons' keys are never kept at once."""
	var sim := ForecastSim.new()
	var alerts := AlertsScript.new()
	sim.event = 1
	assert_equal(_forecasts(alerts, sim), 1, "said")
	assert_equal(_forecasts(alerts, sim), 0, "not again the same season")
	sim.event = 2
	assert_equal(_forecasts(alerts, sim), 1, "another event: said")
	sim.day = 13
	sim.event = 1
	assert_equal(_forecasts(alerts, sim), 1, "the next season: said again")
	assert_equal(alerts.said_count(), 1, "only this season's kept")


func _forecasts(alerts: AlertsScript, sim: SimScript) -> int:
	"""How many forecast lines one hourly pass says."""
	var out := PackedStringArray()
	alerts._forecast_line(sim, out)
	return out.size()
