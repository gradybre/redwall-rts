extends "res://test/framework/test_case.gd"
## Coverage for `scripts/core/presentation_extract.gd`: ARCH-SYS-023 PresentationExtract.
##
## TASK 04.4's SENTENCE IS THE TEST LIST. "Extract read-only UI/render snapshots at ARCH-SYS-023.
## Rendering floats interpolate committed integer state only; hiding layers does not change
## truth." Each clause has named methods below:
##
##   READ-ONLY           -- no accessor hands back a store or a column, every read fills a record
##                          the CALLER owns, and mutating that record changes nothing here.
##   COMMITTED INTEGERS  -- every interpolation endpoint is a captured integer, asserted BY VALUE
##                          against the store it was read from.
##   HIDING CHANGES NO TRUTH -- a hidden layer refuses, and the store, the captured value and the
##                          next capture are all untouched by the hiding.
##
## THE INTERPOLATION ARITHMETIC IS RESTATED HERE rather than read back out of the module: a
## field at alpha a/1000 between committed p and c is `p + (c - p) * a / 1000`, computed in the
## test in float from integers the test itself chose.

const PresentationExtractScript := preload("res://scripts/core/presentation_extract.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")

## GDD §5.1's offset calendar, restated: the day runs 18000 ticks and opens at 06:00, so tick 0 is
## hour 6 of absolute day 1 and the first midnight is tick 13500.
const TICKS_PER_DAY: int = 18000
const TICKS_PER_HOUR: int = 750
const FIRST_MIDNIGHT_TICK: int = 13500
const OPENING_HOUR: int = 6

## §5.5's five forage items, any distinct storable ids.
const PATCH_ITEM_IDS: Array[int] = [10, 11, 12, 13, 14]

var _residents: ResidentsScript = null
var _jobs: JobsScript = null
var _forage: ForageScript = null
var _planner: JobPlannerScript = null
var _clock: SimClockScript = null
var _queue: CommandsScript = null
var _dispatch: CommandDispatchScript = null
var _weather: WeatherScript = null
var _extract: PresentationExtractScript = null
var _read: IntMath.IntResult = null
var _float: PresentationExtractScript.FloatRead = null


func before_each() -> void:
	"""Compose one settlement's worth of stores and the extract that reads them."""
	_residents = ResidentsScript.new()
	_jobs = JobsScript.new(_residents)
	_forage = ForageScript.new(_jobs.directory(), _jobs)
	_planner = JobPlannerScript.new(null, _jobs, _forage)
	_clock = SimClockScript.new()
	_queue = CommandsScript.new(_clock, _jobs.directory())
	_dispatch = CommandDispatchScript.new(_queue, _residents, null, null, _jobs, _forage, _planner)
	_weather = WeatherScript.new()
	_extract = PresentationExtractScript.new(_residents, _jobs, _dispatch, _forage, _planner,
		_weather)
	_read = IntMath.IntResult.new()
	_float = PresentationExtractScript.FloatRead.new()


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_extract = null
	_weather = null
	_dispatch = null
	_queue = null
	_clock = null
	_planner = null
	_forage = null
	_jobs = null
	_residents = null


func _value(field: int) -> int:
	"""The captured integer of one field, failing loudly rather than returning a stale number."""
	if not _extract.value_into(field, _read):
		fail("field %d refused with %s" % [field, _read.error])
		return -1
	return _read.value


func _spawn(count: int) -> void:
	"""Put `count` residents in the store, so the population fields have something to report."""
	for index: int in count:
		assert_true(_residents.spawn(&"mouse").ok, "the resident spawns")


# --- construction and the field domain ----------------------------------------------------------

func test_a_fresh_extract_has_captured_nothing() -> void:
	"""Before the first capture there is no frame, and reading one REFUSES rather than answering 0."""
	assert_equal(_extract.capture_count(), 0, "no frame captured")
	assert_false(_extract.captured_tick().ok, "and no captured tick to report")
	assert_false(_extract.value_into(PresentationExtractScript.FIELD_TICK, _read),
		"a field read refuses")
	assert_equal(_read.error, String(PresentationExtractScript.REFUSE_NO_CAPTURE),
		"naming the absent capture, not returning tick 0")


func test_every_field_names_a_real_layer_and_a_real_source() -> void:
	"""The two tables are the schema; a field pointing at nothing would be an invisible hole."""
	assert_equal(PresentationExtractScript.FIELD_LAYER.size(),
		PresentationExtractScript.FIELD_COUNT, "one layer entry per field")
	assert_equal(PresentationExtractScript.FIELD_SOURCE.size(),
		PresentationExtractScript.FIELD_COUNT, "one source entry per field")
	for field: int in PresentationExtractScript.FIELD_COUNT:
		assert_true(_extract.layer_of(field).ok, "field %d names a layer" % field)
		assert_true(_extract.layer_of(field).value < PresentationExtractScript.LAYER_COUNT,
			"and that layer exists")
	assert_false(_extract.layer_of(PresentationExtractScript.FIELD_COUNT).ok,
		"one past the last field names no layer")


func test_an_unbound_source_refuses_instead_of_reading_zero() -> void:
	"""A settlement with no planner has no standing-demand count, and 0 would be a lie."""
	var lone: PresentationExtractScript = PresentationExtractScript.new()
	assert_true(lone.capture(0), "the clock fields still capture")
	assert_false(lone.is_field_available(PresentationExtractScript.FIELD_STANDING_DEMANDS),
		"the planner field is unavailable")
	assert_false(lone.value_into(PresentationExtractScript.FIELD_STANDING_DEMANDS, _read),
		"and reading it refuses")
	assert_equal(_read.error, String(PresentationExtractScript.REFUSE_SOURCE_NOT_BOUND),
		"naming the unbound source")
	assert_true(lone.value_into(PresentationExtractScript.FIELD_TICK, _read),
		"while the clock field, which needs no store, answers")


# --- the capture itself -------------------------------------------------------------------------

func test_a_capture_copies_the_committed_integers_by_value() -> void:
	"""Every field is asserted against the store it came from, not against another field."""
	_spawn(3)
	assert_true(_extract.capture(TICKS_PER_HOUR * 2), "the capture runs")
	assert_equal(_value(PresentationExtractScript.FIELD_POPULATION), 3, "three resident rows")
	assert_equal(_value(PresentationExtractScript.FIELD_LIVING), _residents.living_count(),
		"the living count the store holds")
	assert_equal(_value(PresentationExtractScript.FIELD_JOB_COUNT), _jobs.job_count(),
		"the live job count the store holds")
	assert_equal(_value(PresentationExtractScript.FIELD_HARVEST_ZONES), _forage.zone_count(),
		"the zone count the store holds")
	assert_equal(_value(PresentationExtractScript.FIELD_TEMPERATURE_TENTHS),
		_weather.temperature_tenths(), "and §5.10's committed temperature in tenths")


func test_the_clock_fields_decode_the_offset_calendar() -> void:
	"""The four clock fields are §5.1's calendar, restated here rather than read back."""
	assert_true(_extract.capture(0), "tick 0 captures")
	assert_equal(_value(PresentationExtractScript.FIELD_TICK), 0, "the captured tick")
	assert_equal(_value(PresentationExtractScript.FIELD_ABSOLUTE_DAY), 1, "day 1")
	assert_equal(_value(PresentationExtractScript.FIELD_HOUR), OPENING_HOUR, "opening at 06:00")
	assert_true(_extract.capture(FIRST_MIDNIGHT_TICK), "the first midnight captures")
	assert_equal(_value(PresentationExtractScript.FIELD_HOUR), 0, "which is hour 0")
	assert_equal(_value(PresentationExtractScript.FIELD_ABSOLUTE_DAY), 2, "of day 2")


func test_a_capture_never_writes_a_store() -> void:
	"""ARCH-SYS-023: "never writes simulation". Every observable store value survives a capture."""
	_spawn(2)
	var zones: int = _forage.zone_count()
	var jobs: int = _jobs.job_count()
	var living: int = _residents.living_count()
	var committed: int = _dispatch.committed_count()
	for tick: int in 20:
		assert_true(_extract.capture(tick), "capture %d runs" % tick)
	assert_equal(_forage.zone_count(), zones, "the forage store is unchanged")
	assert_equal(_jobs.job_count(), jobs, "the job store is unchanged")
	assert_equal(_residents.living_count(), living, "the resident store is unchanged")
	assert_equal(_dispatch.committed_count(), committed, "the command ledger is unchanged")


func test_a_repeated_tick_refuses_so_the_baseline_cannot_be_rolled_away() -> void:
	"""A second capture of one tick would make the renderer interpolate from a frame to itself."""
	assert_true(_extract.capture(10), "the first capture runs")
	assert_true(_extract.capture(11), "and the next tick's")
	assert_false(_extract.capture(11), "the same tick again refuses")
	assert_equal(_extract.last_refusal(),
		PresentationExtractScript.REFUSE_TICK_ALREADY_CAPTURED, "naming the repeat")
	assert_false(_extract.capture(10), "and so does an earlier one")
	assert_equal(_extract.capture_count(), 2, "neither refusal was counted as a frame")
	assert_equal(_extract.previous_captured_tick().value, 10, "the baseline still holds tick 10")


func test_a_negative_tick_refuses() -> void:
	"""There is no tick before 0, and capturing one would stamp a frame that cannot exist."""
	assert_false(_extract.capture(-1), "a negative tick refuses")
	assert_equal(_extract.last_refusal(), PresentationExtractScript.REFUSE_INVALID_TICK,
		"naming the tick")
	assert_equal(_extract.capture_count(), 0, "and no frame was taken")


func test_clear_drops_both_frames() -> void:
	"""A world reset must not leave the previous world's frame available to interpolate from."""
	assert_true(_extract.capture(1), "one frame")
	assert_true(_extract.capture(2), "and another")
	_extract.clear()
	assert_equal(_extract.capture_count(), 0, "no frames survive")
	assert_false(_extract.captured_tick().ok, "and no captured tick is reported")
	assert_true(_extract.capture(1), "tick 1 may be captured again in the new world")


# --- the float boundary -------------------------------------------------------------------------

func test_interpolation_is_between_two_committed_integers() -> void:
	"""The one legal float: both endpoints are captured integers and the alpha is an integer."""
	_spawn(2)
	assert_true(_extract.capture(1), "the first frame captures two residents")
	_spawn(6)
	assert_true(_extract.capture(2), "the second captures eight")
	var field: int = PresentationExtractScript.FIELD_POPULATION
	assert_true(_extract.previous_value_into(field, _read), "the previous frame is readable")
	assert_equal(_read.value, 2, "and holds the committed 2")
	assert_equal(_value(field), 8, "while the current frame holds the committed 8")
	assert_true(_extract.interpolate_into(field, 0, _float), "alpha 0 interpolates")
	assert_almost_equal(_float.value, 2.0, "to the previous committed integer exactly")
	assert_true(_extract.interpolate_into(field, 1000, _float), "alpha 1000 interpolates")
	assert_almost_equal(_float.value, 8.0, "to the current committed integer exactly")
	assert_true(_extract.interpolate_into(field, 250, _float), "a quarter of the way interpolates")
	assert_almost_equal(_float.value, 2.0 + (8.0 - 2.0) * 0.25, "to p + (c - p) * a / 1000")


func test_interpolation_refuses_an_alpha_outside_one_tick() -> void:
	"""Extrapolation would draw a state the simulation never committed."""
	assert_true(_extract.capture(1), "one frame")
	assert_true(_extract.capture(2), "and another")
	assert_false(_extract.interpolate_into(PresentationExtractScript.FIELD_TICK, -1, _float),
		"a negative alpha refuses")
	assert_equal(_float.error, PresentationExtractScript.REFUSE_INVALID_ALPHA, "naming the alpha")
	assert_false(_extract.interpolate_into(PresentationExtractScript.FIELD_TICK, 1001, _float),
		"and so does one past a whole tick")
	assert_almost_equal(_float.value, 0.0, "a refusal carries no value to mistake for one")


func test_interpolation_refuses_with_only_one_frame_behind_it() -> void:
	"""A first frame has nothing to come from, and 0.0 would be indistinguishable from a reading."""
	assert_true(_extract.capture(1), "the only frame")
	assert_false(_extract.interpolate_into(PresentationExtractScript.FIELD_TICK, 500, _float),
		"interpolation refuses")
	assert_equal(_float.error, PresentationExtractScript.REFUSE_NO_PREVIOUS_CAPTURE,
		"naming the missing baseline")
	assert_false(_extract.previous_value_into(PresentationExtractScript.FIELD_TICK, _read),
		"and so does the previous-frame read")


func test_an_interpolated_float_changes_no_captured_integer() -> void:
	"""The float is a drawing instruction; nothing writes it back into the snapshot."""
	_spawn(4)
	assert_true(_extract.capture(1), "the first frame")
	assert_true(_extract.capture(2), "and the second")
	var before: int = _value(PresentationExtractScript.FIELD_POPULATION)
	for step: int in 11:
		assert_true(_extract.interpolate_into(PresentationExtractScript.FIELD_POPULATION,
			step * 100, _float), "alpha %d interpolates" % (step * 100))
	assert_equal(_value(PresentationExtractScript.FIELD_POPULATION), before,
		"and eleven interpolations left the committed integer exactly where it was")
	assert_equal(_residents.population(), 4, "as they left the store itself")


# --- read-only: nothing that escapes can change anything ---------------------------------------

func test_a_read_fills_a_record_the_caller_owns() -> void:
	"""Mutating the record a read filled cannot reach back into the snapshot."""
	_spawn(5)
	assert_true(_extract.capture(1), "the capture runs")
	assert_true(_extract.value_into(PresentationExtractScript.FIELD_POPULATION, _read),
		"the read succeeds")
	_read.succeed(9999)
	assert_equal(_value(PresentationExtractScript.FIELD_POPULATION), 5,
		"the snapshot still holds the committed 5")
	assert_equal(_residents.population(), 5, "and so does the store")


func test_the_extract_publishes_no_store_and_no_column() -> void:
	"""A presentation layer holding this object holds numbers, not a handle to the simulation."""
	var published: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _extract.get_method_list():
		var name: String = String(entry["name"])
		if name.begins_with("_") or entry["return"]["type"] != TYPE_OBJECT:
			continue
		published.append(name)
	for name: String in published:
		assert_true(name in ["value_of", "layer_of", "captured_tick", "previous_captured_tick"],
			"%s returns an object, and only result records may" % name)
	assert_true(published.size() >= 4, "the four result-returning readers are still published")


# --- hiding a layer changes what is reported, never what is true -------------------------------

func test_hiding_a_layer_refuses_its_fields_and_leaves_every_store_untouched() -> void:
	"""04.4: "hiding layers does not change truth". The store is asserted after the hiding."""
	_spawn(7)
	assert_true(_extract.capture(1), "the capture runs")
	assert_equal(_value(PresentationExtractScript.FIELD_POPULATION), 7, "seven are reported")
	assert_true(_extract.set_layer_visible(PresentationExtractScript.LAYER_POPULATION, false),
		"the population layer is hidden")
	assert_false(_extract.is_layer_visible(PresentationExtractScript.LAYER_POPULATION),
		"and reports itself hidden")
	assert_false(_extract.value_into(PresentationExtractScript.FIELD_POPULATION, _read),
		"its field refuses")
	assert_equal(_read.error, String(PresentationExtractScript.REFUSE_LAYER_HIDDEN),
		"naming the hidden layer")
	assert_equal(_residents.population(), 7, "THE STORE STILL HOLDS SEVEN")
	assert_equal(_residents.living_count(), 7, "and every living resident is still living")


func test_a_hidden_layer_hides_only_its_own_fields() -> void:
	"""A filter that leaked across layers would make a hidden panel blank an unrelated one."""
	_spawn(2)
	assert_true(_extract.capture(1), "the capture runs")
	assert_true(_extract.set_layer_visible(PresentationExtractScript.LAYER_ECOLOGY, false),
		"the ecology layer is hidden")
	assert_false(_extract.value_into(PresentationExtractScript.FIELD_HARVEST_ZONES, _read),
		"an ecology field refuses")
	assert_true(_extract.value_into(PresentationExtractScript.FIELD_POPULATION, _read),
		"a population field still answers")
	assert_equal(_read.value, 2, "with its committed value")
	assert_true(_extract.value_into(PresentationExtractScript.FIELD_TICK, _read),
		"and so does a clock field")


func test_unhiding_shows_the_same_number_that_was_there_all_along() -> void:
	"""Hiding must not zero the column: the value is retained, merely not reported."""
	_spawn(3)
	assert_true(_extract.capture(1), "the capture runs")
	assert_true(_extract.set_layer_visible(PresentationExtractScript.LAYER_POPULATION, false),
		"the layer is hidden")
	assert_true(_extract.set_layer_visible(PresentationExtractScript.LAYER_POPULATION, true),
		"and shown again")
	assert_equal(_value(PresentationExtractScript.FIELD_POPULATION), 3,
		"the same committed three, never zeroed by the hiding")


func test_a_capture_taken_while_a_layer_is_hidden_still_records_the_truth() -> void:
	"""The filter is on reporting, not on recording: a hidden layer keeps capturing real values."""
	_spawn(1)
	assert_true(_extract.capture(1), "the first capture")
	assert_true(_extract.set_layer_visible(PresentationExtractScript.LAYER_POPULATION, false),
		"the layer is hidden")
	_spawn(4)
	assert_true(_extract.capture(2), "a capture is taken while it is hidden")
	assert_true(_extract.set_layer_visible(PresentationExtractScript.LAYER_POPULATION, true),
		"and the layer is shown again")
	assert_equal(_value(PresentationExtractScript.FIELD_POPULATION), 5,
		"the hidden capture recorded all five residents")
	assert_true(_extract.previous_value_into(PresentationExtractScript.FIELD_POPULATION, _read),
		"and the frame before it is readable")
	assert_equal(_read.value, 1, "still holding the committed one")


func test_hiding_an_unknown_layer_refuses() -> void:
	"""An index outside the six layers is refused rather than silently ignored."""
	assert_false(_extract.set_layer_visible(PresentationExtractScript.LAYER_COUNT, false),
		"one past the last layer refuses")
	assert_equal(_extract.last_refusal(), PresentationExtractScript.REFUSE_INVALID_LAYER,
		"naming the layer")
	assert_false(_extract.set_layer_visible(-1, false), "and so does a negative index")
	for layer: int in PresentationExtractScript.LAYER_COUNT:
		assert_true(_extract.is_layer_visible(layer), "no real layer was hidden by the refusal")


func test_interpolation_refuses_on_a_hidden_layer_too() -> void:
	"""The filter covers the float path as well, or a hidden panel could still be drawn."""
	_spawn(2)
	assert_true(_extract.capture(1), "one frame")
	assert_true(_extract.capture(2), "and another")
	assert_true(_extract.set_layer_visible(PresentationExtractScript.LAYER_POPULATION, false),
		"the layer is hidden")
	assert_false(_extract.interpolate_into(PresentationExtractScript.FIELD_POPULATION, 500,
		_float), "interpolating it refuses")
	assert_equal(_float.error, PresentationExtractScript.REFUSE_LAYER_HIDDEN, "naming the layer")
	assert_false(_extract.previous_value_into(PresentationExtractScript.FIELD_POPULATION, _read),
		"and so does the previous-frame read")


# --- the field domain's own bounds --------------------------------------------------------------

func test_an_unknown_field_refuses() -> void:
	"""A field index outside the fourteen is refused rather than read off the end of a column."""
	assert_true(_extract.capture(1), "the capture runs")
	assert_false(_extract.value_into(PresentationExtractScript.FIELD_COUNT, _read),
		"one past the last field refuses")
	assert_equal(_read.error, String(PresentationExtractScript.REFUSE_INVALID_FIELD),
		"naming the field")
	assert_false(_extract.value_into(-1, _read), "and so does a negative index")
	assert_false(_extract.is_field(PresentationExtractScript.FIELD_COUNT), "which is no field")


func test_the_snapshot_reports_its_own_budgeted_size() -> void:
	"""The ARCH-MEM row for this store is arithmetic over its own declared shape."""
	assert_equal(_extract.snapshot_bytes(),
		PresentationExtractScript.FIELD_COUNT * 8 * 2 + PresentationExtractScript.FIELD_COUNT
		+ PresentationExtractScript.LAYER_COUNT,
		"two i64 frames plus one availability byte per field and one visibility byte per layer")
	assert_equal(_extract.snapshot_bytes(), 244, "which is 224 + 14 + 6 bytes")


func test_the_value_of_form_agrees_with_the_into_form() -> void:
	"""The allocating convenience reader must not answer differently from the hot-path one."""
	_spawn(2)
	assert_true(_extract.capture(1), "the capture runs")
	for field: int in PresentationExtractScript.FIELD_COUNT:
		var allocated: IntMath.IntResult = _extract.value_of(field)
		var into: bool = _extract.value_into(field, _read)
		assert_equal(allocated.ok, into, "field %d agrees on success" % field)
		assert_equal(allocated.value, _read.value, "field %d agrees on value" % field)
