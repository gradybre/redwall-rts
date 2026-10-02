extends "res://test/framework/test_case.gd"
## Coverage for SET_STORE_FILTER and SET_STORE_MINIMUM in `scripts/core/command_dispatch.gd`
## (decision 1031): a player's per-item store filter and minimum reach `store_policy.gd` through
## the one command path, atomically, and refuse by name.
##
## Kind ids 21 and 22 are transcribed from ARCH-CMD-003's sorted list, not read from `catalog.gd`.
## The payload schemas are decision 1031's: an i32 count, then `(item_id:i32, allowed:i32)` or
## `(item_id:i32, minimum_milli:i64)` rows in ascending item order, at most 256 of them.

const Buildings := preload("res://scripts/core/buildings.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const StorePolicy := preload("res://scripts/core/store_policy.gd")

const KIND_SET_STORE_FILTER: int = 21
const KIND_SET_STORE_MINIMUM: int = 22
const COMMIT_TICK: int = 1
const ITEM_KEYS: int = 256

const ITEM_GRAIN: int = 10
const ITEM_ROOTS: int = 11
const ITEM_WOOD: int = 20
const ITEM_UNREGISTERED: int = 99
const START_MASK: int = 1
const ORIGIN: int = 30 * 128 + 20
## More than int32 can hold, so a minimum truncated to 32 bits would be caught.
const LARGE_MINIMUM: int = 5000000000

var _buildings: Buildings = null
var _inventory: InventoryScript = null
var _policy: StorePolicy = null
var _clock: SimClockScript = null
var _queue: CommandsScript = null
var _dispatch: CommandDispatchScript = null
var _submission: CommandsScript.Command = null
var _submit_result: CommandsScript.SubmitResult = null
var _report: CommandDispatchScript.TickReport = null
var _row: CommandDispatchScript.ResultRow = null
var _stockpile: Vector2i = Vector2i(-1, 0)
var _store: Vector2i = Vector2i(-1, 0)


func before_each() -> void:
	"""A stockpile with its main store, one shared directory, and a dispatcher bound to the policy."""
	_buildings = Buildings.new()
	_inventory = InventoryScript.new()
	for item: int in [ITEM_GRAIN, ITEM_ROOTS, ITEM_WOOD]:
		assert_true(_inventory.register_item(item, 1000, 0).ok, "item %d registers" % item)
	_policy = StorePolicy.new(_buildings, _inventory)
	_clock = SimClockScript.new()
	_queue = CommandsScript.new(_clock, _buildings.directory())
	_dispatch = CommandDispatchScript.new(_queue)
	assert_true(_dispatch.bind_store_policy(_policy), "the store policy binds")
	_submission = CommandsScript.Command.new()
	_submit_result = CommandsScript.SubmitResult.new()
	_report = CommandDispatchScript.TickReport.new()
	_row = CommandDispatchScript.ResultRow.new()
	var placed: Buildings.OpResult = _buildings.place_building(
		int(CatalogScript.BUILDING_DEFINITION["open_stockpile"]), ORIGIN, 0, START_MASK)
	assert_true(placed.ok, "the stockpile places (%s)" % placed.error)
	_stockpile = placed.ref
	var made: InventoryScript.OpResult = _inventory.create_container(_stockpile, 400000,
		InventoryScript.FILTERS_ACCEPT_ALL, InventoryScript.UNSET_POLICY, true, ORIGIN)
	assert_true(made.ok, "its main store is created (%s)" % made.error)
	_store = made.ref


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_dispatch = null
	_queue = null
	_policy = null
	_inventory = null
	_buildings = null


# --- fixture helpers ------------------------------------------------------------------------------

func _filter_payload(items: Array, values: Array) -> PackedByteArray:
	"""Count first, then `(item_id:i32, allowed:i32)` rows."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4 + 8 * items.size())
	bytes.encode_s32(0, items.size())
	for index: int in items.size():
		bytes.encode_s32(4 + index * 8, items[index])
		bytes.encode_s32(8 + index * 8, values[index])
	return bytes


func _minimum_payload(items: Array, values: Array) -> PackedByteArray:
	"""Count first, then `(item_id:i32, minimum_milli:i64)` rows."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4 + 12 * items.size())
	bytes.encode_s32(0, items.size())
	for index: int in items.size():
		bytes.encode_s32(4 + index * 12, items[index])
		bytes.encode_s64(8 + index * 12, values[index])
	return bytes


func _run(kind: int, target: Vector2i, payload: PackedByteArray, arg0: int = 0,
		arg1: int = 0) -> int:
	"""Submit one command, run one CommandCommit stage, and return its result id."""
	_submission.reset()
	_submission.kind = kind
	_submission.target_slot = target.x
	_submission.target_generation = target.y
	_submission.arg0 = arg0
	_submission.arg1 = arg1
	_submission.payload = payload
	assert_true(_queue.submit_into(_submission, _submit_result),
		"the envelope is admitted (%s)" % _submit_result.error)
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK, _report), "the stage runs")
	assert_true(_dispatch.last_result_into(_row), "an outcome is ledgered")
	return _row.code_id


func _assert_untouched(context: String) -> void:
	"""The stockpile's policy is exactly the defaults: nothing was written."""
	assert_false(_policy.is_policy_bound(_stockpile), "%s: no row was bound" % context)
	for item: int in [ITEM_GRAIN, ITEM_ROOTS, ITEM_WOOD]:
		assert_true(_policy.store_admits(_store, item), "%s: item %d still admitted" % [context, item])
		assert_equal(_policy.minimum_milli_of(_stockpile, item), 0, "%s: no minimum" % context)


# --- the two kinds commit --------------------------------------------------------------------------

func test_a_filter_command_filters_the_main_store() -> void:
	"""Submit -> drain -> commit: the store stops admitting exactly the rows set to 0."""
	var code: int = _run(KIND_SET_STORE_FILTER, _stockpile,
		_filter_payload([ITEM_GRAIN, ITEM_ROOTS, ITEM_WOOD], [0, 1, 0]))
	assert_equal(code, CommandDispatchScript.RESULT_COMMITTED, "the filter commits")
	assert_equal(_row.value, 3, "three rows were written")
	assert_equal(_row.store_code, &"", "with no store code")
	assert_false(_policy.store_admits(_store, ITEM_GRAIN), "grain is filtered out")
	assert_true(_policy.store_admits(_store, ITEM_ROOTS), "roots stay in")
	assert_false(_policy.store_admits(_store, ITEM_WOOD), "wood is filtered out")


func test_a_minimum_command_keeps_a_full_int64_reserve() -> void:
	"""BuildingItemMinimum's I64 survives the payload: a value past int32 is stored exactly."""
	var code: int = _run(KIND_SET_STORE_MINIMUM, _stockpile,
		_minimum_payload([ITEM_GRAIN, ITEM_WOOD], [LARGE_MINIMUM, 2500]))
	assert_equal(code, CommandDispatchScript.RESULT_COMMITTED, "the minimum commits")
	assert_equal(_row.value, 2, "two rows were written")
	assert_equal(_policy.store_minimum_milli(_store, ITEM_GRAIN), LARGE_MINIMUM, "exactly")
	assert_equal(_policy.store_minimum_milli(_store, ITEM_WOOD), 2500, "and the second row")
	assert_equal(_policy.store_minimum_milli(_store, ITEM_ROOTS), 0, "an unnamed item is untouched")


func test_a_full_256_row_group_commits() -> void:
	"""The ceiling is ARCH-STATE-004's 256-key envelope, and the whole envelope fits one command."""
	var items: Array = []
	var values: Array = []
	for item: int in ITEM_KEYS:
		if not _inventory.is_item_registered(item):
			assert_true(_inventory.register_item(item, 1, 0).ok, "item %d registers" % item)
		items.append(item)
		values.append(item)
	assert_equal(_run(KIND_SET_STORE_MINIMUM, _stockpile, _minimum_payload(items, values)),
		CommandDispatchScript.RESULT_COMMITTED, "256 rows commit")
	assert_equal(_policy.store_minimum_milli(_store, ITEM_KEYS - 1), ITEM_KEYS - 1, "the last row")


# --- refusals are atomic and named -----------------------------------------------------------------

func test_one_bad_row_refuses_the_whole_group_with_the_stores_code() -> void:
	"""Every row is validated before the first write: a bad LAST row leaves the first ones unwritten."""
	var cases: Array = [
		[KIND_SET_STORE_FILTER, _filter_payload([ITEM_GRAIN, ITEM_UNREGISTERED], [0, 0]),
			StorePolicy.REFUSE_UNKNOWN_ITEM],
		[KIND_SET_STORE_FILTER, _filter_payload([ITEM_GRAIN, ITEM_WOOD], [0, 2]),
			StorePolicy.REFUSE_ALLOWED_DOMAIN],
		[KIND_SET_STORE_FILTER, _filter_payload([ITEM_GRAIN, ITEM_KEYS], [0, 0]),
			StorePolicy.REFUSE_UNKNOWN_ITEM],
		[KIND_SET_STORE_MINIMUM, _minimum_payload([ITEM_GRAIN, ITEM_WOOD], [5, -1]),
			StorePolicy.REFUSE_NEGATIVE_MINIMUM],
		[KIND_SET_STORE_MINIMUM, _minimum_payload([ITEM_GRAIN, ITEM_UNREGISTERED], [5, 5]),
			StorePolicy.REFUSE_UNKNOWN_ITEM],
	]
	for entry: Array in cases:
		var code: int = _run(entry[0], _stockpile, entry[1])
		assert_equal(code, CommandDispatchScript.RESULT_STORE_REFUSED, "%s refuses" % entry[2])
		assert_equal(_row.store_code, entry[2], "naming the store's own rule")
		assert_equal(_row.value, 0, "and carrying no value")
		_assert_untouched(String(entry[2]))


func test_rows_out_of_ascending_item_order_refuse_the_schema() -> void:
	"""ARCH-CMD-003's owner-sorted rows: a repeat or a descent is refused, never resolved."""
	var cases: Array = [
		[KIND_SET_STORE_FILTER, _filter_payload([ITEM_WOOD, ITEM_GRAIN], [0, 0])],
		[KIND_SET_STORE_FILTER, _filter_payload([ITEM_GRAIN, ITEM_GRAIN], [0, 1])],
		[KIND_SET_STORE_MINIMUM, _minimum_payload([ITEM_WOOD, ITEM_GRAIN], [1, 1])],
		[KIND_SET_STORE_MINIMUM, _minimum_payload([ITEM_GRAIN, ITEM_GRAIN], [1, 2])],
	]
	for entry: Array in cases:
		assert_equal(_run(entry[0], _stockpile, entry[1]),
			CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "an unsorted group refuses")
		_assert_untouched("unsorted")


func test_a_malformed_group_refuses_the_schema() -> void:
	"""Empty, short, long and over-ceiling groups are all PAYLOAD_SCHEMA, and none writes."""
	var empty: PackedByteArray = _filter_payload([], [])
	var short: PackedByteArray = _filter_payload([ITEM_GRAIN], [0])
	short.resize(short.size() - 1)
	var minimum_as_filter: PackedByteArray = _minimum_payload([ITEM_GRAIN], [0])
	var over: PackedByteArray = PackedByteArray()
	over.resize(4 + 8 * (ITEM_KEYS + 1))
	over.encode_s32(0, ITEM_KEYS + 1)
	for payload: PackedByteArray in [empty, short, minimum_as_filter, over, PackedByteArray()]:
		assert_equal(_run(KIND_SET_STORE_FILTER, _stockpile, payload),
			CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "%d bytes refuse" % payload.size())
	assert_equal(_run(KIND_SET_STORE_MINIMUM, _stockpile, _filter_payload([ITEM_GRAIN], [0])),
		CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "a filter row is not a minimum row")
	assert_equal(_run(KIND_SET_STORE_MINIMUM, _stockpile, _minimum_payload([], [])),
		CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "an empty minimum group refuses")
	_assert_untouched("malformed")


func test_a_nonzero_argument_is_refused_rather_than_ignored() -> void:
	"""Neither kind names a use for arg0 or arg1."""
	var payload: PackedByteArray = _filter_payload([ITEM_GRAIN], [0])
	assert_equal(_run(KIND_SET_STORE_FILTER, _stockpile, payload, 1, 0),
		CommandDispatchScript.RESULT_ARGUMENT_RANGE, "arg0")
	assert_equal(_run(KIND_SET_STORE_FILTER, _stockpile, payload, 0, -1),
		CommandDispatchScript.RESULT_ARGUMENT_RANGE, "arg1")
	assert_equal(_run(KIND_SET_STORE_MINIMUM, _stockpile, _minimum_payload([ITEM_GRAIN], [1]), 0, 1),
		CommandDispatchScript.RESULT_ARGUMENT_RANGE, "a minimum's arg1")
	_assert_untouched("arguments")


# --- the target is revalidated at commit ------------------------------------------------------------

func test_a_target_demolished_after_admission_refuses_stale() -> void:
	"""Task 04.2: commit revalidates. A stockpile gone by the commit tick is not edited."""
	_submission.reset()
	_submission.kind = KIND_SET_STORE_FILTER
	_submission.target_slot = _stockpile.x
	_submission.target_generation = _stockpile.y
	_submission.payload = _filter_payload([ITEM_GRAIN], [0])
	assert_true(_queue.submit_into(_submission, _submit_result), "admitted while it stands")
	assert_true(_inventory.destroy_container(_store).ok, "its store is retired")
	assert_true(_buildings.demolish_building(_stockpile).ok, "and it is demolished")
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK, _report), "the stage runs")
	assert_true(_dispatch.last_result_into(_row), "an outcome is ledgered")
	assert_equal(_row.code_id, CommandDispatchScript.RESULT_TARGET_STALE, "it refuses stale")


func test_a_target_that_is_not_a_building_is_refused_by_kind() -> void:
	"""A resident, or the null ref, is not a store's owner."""
	var resident: Vector2i = _buildings.directory().create(EntityDirectory.KIND_RESIDENT)
	assert_equal(_run(KIND_SET_STORE_FILTER, resident, _filter_payload([ITEM_GRAIN], [0])),
		CommandDispatchScript.RESULT_TARGET_KIND, "a resident target refuses by kind")
	assert_equal(_run(KIND_SET_STORE_MINIMUM, EntityDirectory.NULL_REF,
		_minimum_payload([ITEM_GRAIN], [1])), CommandDispatchScript.RESULT_TARGET_REQUIRED,
		"the null target refuses as required")


func test_a_directory_building_the_building_store_does_not_hold_is_refused_by_the_store() -> void:
	"""The directory can attest a BUILDING the Building store never placed; the store says no."""
	var orphan: Vector2i = _buildings.directory().create(EntityDirectory.KIND_BUILDING)
	assert_equal(_run(KIND_SET_STORE_FILTER, orphan, _filter_payload([ITEM_GRAIN], [0])),
		CommandDispatchScript.RESULT_STORE_REFUSED, "the store refuses it")
	assert_equal(_row.store_code, StorePolicy.REFUSE_STALE_BUILDING, "as a stale building")


# --- binding ---------------------------------------------------------------------------------------

func test_an_unbound_policy_refuses_and_a_foreign_one_never_binds() -> void:
	"""Unbound kinds refuse STORE_NOT_BOUND; a store over another directory is refused at bind."""
	var foreign: StorePolicy = StorePolicy.new(Buildings.new(), _inventory)
	assert_false(_dispatch.bind_store_policy(foreign), "another directory's store is refused")
	assert_equal(_dispatch.last_refusal(), CommandDispatchScript.REFUSE_SHARED_DIRECTORY, "by name")
	assert_true(_dispatch.bind_store_policy(null), "unbinding is accepted")
	assert_equal(_dispatch.last_refusal(), &"", "and clears the refusal")
	assert_equal(_run(KIND_SET_STORE_FILTER, _stockpile, _filter_payload([ITEM_GRAIN], [0])),
		CommandDispatchScript.RESULT_STORE_NOT_BOUND, "an unbound filter refuses")
	assert_equal(_run(KIND_SET_STORE_MINIMUM, _stockpile, _minimum_payload([ITEM_GRAIN], [1])),
		CommandDispatchScript.RESULT_STORE_NOT_BOUND, "and so does a minimum")
	_assert_untouched("unbound")


func test_both_kinds_are_supported_and_name_no_missing_store() -> void:
	"""The two kinds moved out of the unsupported set, by name."""
	for kind: int in [KIND_SET_STORE_FILTER, KIND_SET_STORE_MINIMUM]:
		assert_true(_dispatch.is_supported_kind(kind), "kind %d is implemented" % kind)
		assert_equal(_dispatch.unsupported_reason(kind), &"", "and names no gap")
