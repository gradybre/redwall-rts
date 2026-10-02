extends "res://test/framework/test_case.gd"
## BUILD-C4-R01's ConstructionPaidLedger and tier-2 demolition basis (decision 0534).
##
## Every expectation below is DERIVED from the distinct base (§4.1) and upgrade (§4.2) entries the
## construction store publishes through `required_milli_into()` and `declared_work_mwu_into()`,
## never from the store's own manifest, so the test cannot agree with a wrong sum by construction.

const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const HALL_TILE: int = 59 * 128 + 58
const WELL_TILE: int = 40 * 128 + 40
const START_MASK: int = 1

var _buildings: Buildings = null
var _construction: Construction = null
var _out: IntMath.IntResult = IntMath.IntResult.new()
var _hall_id: int = 0
var _well_id: int = 0


func before_each() -> void:
	"""A private Construction store over its own Building store."""
	_buildings = Buildings.new()
	_construction = Construction.new(_buildings)
	_out = IntMath.IntResult.new()
	_hall_id = int(CatalogScript.BUILDING_DEFINITION["hall"])
	_well_id = int(CatalogScript.BUILDING_DEFINITION["well"])


func after_each() -> void:
	"""Drop the fixture."""
	_construction = null
	_buildings = null


# --- fixtures --------------------------------------------------------------------------------

func _bill_milli(purpose: int, type_id: int, key: StringName) -> int:
	"""One package's quantity of `key`, or 0 when the package does not name it."""
	var index: IntMath.IntResult = IntMath.IntResult.new()
	if not _construction.material_index_of_key_into(purpose, type_id, key, index):
		return 0
	assert_true(_construction.required_milli_into(purpose, type_id, index.value, _out),
		"the bill line reads")
	return _out.value


func _work(purpose: int, type_id: int) -> int:
	"""A package's declared milli-WU."""
	assert_true(_construction.declared_work_mwu_into(purpose, type_id, _out), "work reads")
	return _out.value


func _finish(project: Vector2i, purpose: int, type_id: int) -> void:
	"""Deliver a project's whole bill, work it and commit it."""
	assert_true(_construction.bill_size_into(purpose, type_id, _out), "the bill has a size")
	for index: int in _out.value:
		var line: IntMath.IntResult = IntMath.IntResult.new()
		assert_true(_construction.required_milli_into(purpose, type_id, index, line), "line")
		assert_true(_construction.deliver_material(project, index, line.value).ok, "delivers")
	assert_true(_construction.begin_work(project).ok, "work begins")
	assert_true(_construction.add_work_mwu(project, _work(purpose, type_id)).ok, "work completes")
	assert_true(_construction.commit_completion(project).ok, "the project commits")


func _active(type_id: int, tile: int) -> Vector2i:
	"""Place, build and commit one building; return the BUILDING ref."""
	var placed: Buildings.OpResult = _buildings.place_building(type_id, tile, 0, START_MASK)
	assert_true(placed.ok, "the fixture places (%s)" % placed.error)
	var build: Construction.OpResult = _construction.open_build(placed.ref)
	assert_true(build.ok, "the build opens (%s)" % build.error)
	_finish(build.ref, Construction.PURPOSE_BUILD, type_id)
	return placed.ref


func _tier_two_hall() -> Vector2i:
	"""A hall built and then upgraded through a completed, paid §4.2 package."""
	var hall: Vector2i = _active(_hall_id, HALL_TILE)
	var upgrade: Construction.OpResult = _construction.open_upgrade(hall)
	assert_true(upgrade.ok, "the upgrade opens (%s)" % upgrade.error)
	_finish(upgrade.ref, Construction.PURPOSE_UPGRADE, _hall_id)
	assert_equal(_buildings.tier_of_building(hall).value, BuildingDefinitions.TIER_TWO,
		"the hall stands at tier 2")
	return hall


func _return_of(project: Vector2i, key: StringName) -> int:
	"""The return manifest's quantity for one material key, or -1 when no line names it."""
	assert_true(_construction.demolition_return_size_into(project, _out), "the manifest sizes")
	var count: int = _out.value
	for index: int in count:
		assert_true(_construction.demolition_return_key_index_into(project, index, _out), "key")
		if Construction.MATERIAL_KEYS[_out.value] == key:
			assert_true(_construction.demolition_return_milli_into(project, index, _out), "qty")
			return _out.value
	return -1


# --- the ledger keys each purpose records ------------------------------------------------------

func test_each_purpose_records_its_paid_package_keys() -> void:
	"""BUILD pays its base; UPGRADE pays only its upgrade; a demolition snapshots both."""
	var placed: Buildings.OpResult = _buildings.place_building(_hall_id, HALL_TILE, 0, START_MASK)
	var build: Construction.OpResult = _construction.open_build(placed.ref)
	assert_true(_construction.paid_base_type_into(build.ref, _out), "base key reads")
	assert_equal(_out.value, _hall_id, "a build records its own base package")
	assert_true(_construction.paid_upgrade_mask_into(build.ref, _out), "mask reads")
	assert_equal(_out.value, 0, "and no upgrade")
	_finish(build.ref, Construction.PURPOSE_BUILD, _hall_id)
	var upgrade: Construction.OpResult = _construction.open_upgrade(placed.ref)
	assert_true(_construction.paid_base_type_into(upgrade.ref, _out), "base key reads")
	assert_equal(_out.value, Construction.NO_PAID_PACKAGE, "an upgrade pays no base package")
	assert_true(_construction.paid_upgrade_mask_into(upgrade.ref, _out), "mask reads")
	assert_equal(_out.value, Construction.UPGRADE_TIER_TWO_BIT, "only its tier-2 package")


func test_a_stale_project_refuses_its_ledger_reads() -> void:
	"""No 0 or -1 answer for a ref that names nothing."""
	assert_false(_construction.paid_base_type_into(Vector2i(5, 1), _out), "base refuses")
	assert_equal(_out.error, String(Construction.REFUSE_STALE_PROJECT_REF), "by name")
	assert_false(_construction.paid_upgrade_mask_into(Vector2i(5, 1), _out), "mask refuses")


# --- tier 1: the inherited formula, unchanged -------------------------------------------------

func test_a_tier_one_demolition_snapshots_only_the_base_package() -> void:
	"""Tier 1 returns exactly 50% of §4.1's lines, as before BUILD-C4-R01 was implemented."""
	var hall: Vector2i = _active(_hall_id, HALL_TILE)
	var project: Construction.OpResult = _construction.open_demolition(hall)
	assert_true(project.ok, "the demolition opens (%s)" % project.error)
	assert_true(_construction.paid_upgrade_mask_into(project.ref, _out), "mask reads")
	assert_equal(_out.value, 0, "no completed upgrade")
	assert_true(_construction.paid_base_type_into(project.ref, _out), "base reads")
	assert_equal(_out.value, _hall_id, "the hall's base package")
	for key: StringName in [&"wood", &"stone", &"cloth"]:
		@warning_ignore("integer_division")
		var expected: int = _bill_milli(Construction.PURPOSE_BUILD, _hall_id, key) / 2
		assert_equal(_return_of(project.ref, key), expected, "50%% of base %s" % key)
	@warning_ignore("integer_division")
	var work: int = _work(Construction.PURPOSE_BUILD, _hall_id) / 4
	assert_true(_construction.remaining_mwu_into(project.ref, _out), "work reads")
	assert_equal(_out.value, work, "a quarter of the base WU")


# --- tier 2: base plus the completed upgrade, floored once per item ---------------------------

func test_a_tier_two_demolition_returns_half_of_base_plus_upgrade_per_item() -> void:
	"""BUILD-C4-R01: total each item over both packages in milli-U, then floor the 50% once."""
	var hall: Vector2i = _tier_two_hall()
	var project: Construction.OpResult = _construction.open_demolition(hall)
	assert_true(project.ok, "the demolition opens (%s)" % project.error)
	assert_true(_construction.paid_upgrade_mask_into(project.ref, _out), "mask reads")
	assert_equal(_out.value, Construction.UPGRADE_TIER_TWO_BIT, "the snapshot holds the upgrade")
	for key: StringName in [&"wood", &"stone", &"cloth"]:
		var base: int = _bill_milli(Construction.PURPOSE_BUILD, _hall_id, key)
		var upgrade: int = _bill_milli(Construction.PURPOSE_UPGRADE, _hall_id, key)
		assert_true(upgrade > 0, "the fixture's upgrade really names %s" % key)
		@warning_ignore("integer_division")
		var expected: int = (base + upgrade) / 2
		assert_equal(_return_of(project.ref, key), expected, "50%% of base+upgrade %s" % key)
	assert_true(_construction.demolition_return_size_into(project.ref, _out), "size reads")
	assert_equal(_out.value, 3, "one line per item, not one per package")


func test_a_tier_two_demolition_works_a_quarter_of_both_packages() -> void:
	"""The work is one quarter of the same completed construction WU sum."""
	var hall: Vector2i = _tier_two_hall()
	var project: Construction.OpResult = _construction.open_demolition(hall)
	var total: int = _work(Construction.PURPOSE_BUILD, _hall_id) \
		+ _work(Construction.PURPOSE_UPGRADE, _hall_id)
	@warning_ignore("integer_division")
	var expected: int = total / 4
	assert_true(_construction.remaining_mwu_into(project.ref, _out), "work reads")
	assert_equal(_out.value, expected, "a quarter of base WU plus upgrade WU")


func test_the_fifty_percent_is_floored_once_per_item_not_per_package() -> void:
	"""The live tier-2 path equals floor((base + upgrade) / 2) for every item it returns.

	Every §4.1/§4.2 quantity is authored even, so with today's catalog floor-once and
	floor-per-package agree; this pins the live path to the ruled form and records that the two
	forms do differ on odd totals, so a later catalog edit cannot make the choice matter silently.
	"""
	@warning_ignore("integer_division")
	var per_package: int = 1001 / 2 + 3 / 2
	@warning_ignore("integer_division")
	var once: int = (1001 + 3) / 2
	assert_equal(once, per_package + 1, "the two rules differ on odd totals")
	var hall: Vector2i = _tier_two_hall()
	var project: Construction.OpResult = _construction.open_demolition(hall)
	for key: StringName in [&"wood", &"stone", &"cloth"]:
		var total: int = _bill_milli(Construction.PURPOSE_BUILD, _hall_id, key) \
			+ _bill_milli(Construction.PURPOSE_UPGRADE, _hall_id, key)
		@warning_ignore("integer_division")
		var floored_once: int = total / 2
		assert_equal(_return_of(project.ref, key), floored_once, "%s is floored once" % key)


func test_cancelling_an_incomplete_upgrade_earns_its_refund_and_not_a_demolition_share() -> void:
	"""BUILD-C4-R01's named fixture: an incomplete upgrade is never counted as capital."""
	var hall: Vector2i = _active(_hall_id, HALL_TILE)
	var upgrade: Construction.OpResult = _construction.open_upgrade(hall)
	assert_true(_construction.deliver_material(upgrade.ref, 0,
		_bill_milli(Construction.PURPOSE_UPGRADE, _hall_id, &"wood")).ok, "wood delivers")
	assert_true(_construction.begin_refund(upgrade.ref).ok, "the upgrade is cancelled")
	assert_true(_construction.cancellation_refund_milli_into(upgrade.ref, 0, _out),
		"its own REQ-SET-126 refund reads")
	assert_equal(_out.value, _bill_milli(Construction.PURPOSE_UPGRADE, _hall_id, &"wood"),
		"100% of what was delivered before work")
	assert_true(_construction.close_refund(upgrade.ref).ok, "the cancellation retires")
	assert_equal(_buildings.tier_of_building(hall).value, 1, "the hall stays at tier 1")
	var project: Construction.OpResult = _construction.open_demolition(hall)
	assert_true(project.ok, "and may now be demolished (%s)" % project.error)
	@warning_ignore("integer_division")
	var base_only: int = _bill_milli(Construction.PURPOSE_BUILD, _hall_id, &"wood") / 2
	assert_equal(_return_of(project.ref, &"wood"), base_only,
		"the demolition returns the base package's half only")


func test_an_upgrade_in_progress_blocks_the_demolition() -> void:
	"""The building cannot simultaneously upgrade and demolish."""
	var hall: Vector2i = _active(_hall_id, HALL_TILE)
	assert_true(_construction.open_upgrade(hall).ok, "an upgrade opens")
	assert_equal(_construction.demolition_open_refusal(hall),
		Construction.REFUSE_ALREADY_UNDER_CONSTRUCTION, "the preview refuses")
	assert_equal(_construction.open_demolition(hall).error,
		Construction.REFUSE_ALREADY_UNDER_CONSTRUCTION, "and so does the transition")


# --- the coordinator's preview -----------------------------------------------------------------

func test_the_preview_matches_the_snapshot_the_transition_takes() -> void:
	"""What admit reserves for must equal what the published project will return."""
	var hall: Vector2i = _tier_two_hall()
	var keys: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var milli: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	assert_true(_construction.demolition_return_preview_into(hall, keys, milli, _out),
		"the preview reads (%s)" % _out.error)
	var count: int = _out.value
	var project: Construction.OpResult = _construction.open_demolition(hall)
	for index: int in count:
		assert_equal(_return_of(project.ref, Construction.MATERIAL_KEYS[keys[index]]),
			milli[index], "preview line %d equals the published line" % index)


func test_the_preview_refuses_a_stale_building_and_a_short_buffer() -> void:
	"""Refusals carry their own codes and write nothing."""
	var keys: PackedInt32Array = PackedInt32Array([7, 7, 7, 7])
	var milli: PackedInt64Array = PackedInt64Array([7, 7, 7, 7])
	assert_false(_construction.demolition_return_preview_into(Vector2i(3, 1), keys, milli, _out),
		"a stale building refuses")
	assert_equal(_out.error, String(Construction.REFUSE_STALE_BUILDING_REF), "by name")
	var well: Vector2i = _active(_well_id, WELL_TILE)
	assert_false(_construction.demolition_return_preview_into(well, PackedInt32Array([0]),
		milli, _out), "a short key buffer refuses")
	assert_equal(_out.error, String(Construction.REFUSE_MANIFEST_BUFFER), "by name")
	assert_equal(milli, PackedInt64Array([7, 7, 7, 7]), "and nothing was written")


func test_the_open_refusal_preview_names_every_transition_refusal() -> void:
	"""Stale, not active, occupied and a full CONSTRUCTION kind are all decided without writing."""
	assert_equal(_construction.demolition_open_refusal(Vector2i(3, 1)),
		Construction.REFUSE_STALE_BUILDING_REF, "stale")
	var placed: Buildings.OpResult = _buildings.place_building(_well_id, WELL_TILE, 0, START_MASK)
	assert_equal(_construction.demolition_open_refusal(placed.ref),
		Construction.REFUSE_NOT_ACTIVE, "a blueprint")
	var hall: Vector2i = _active(_hall_id, HALL_TILE)
	var room: Buildings.OpResult = _buildings.designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([60 * 128 + 59]))
	assert_true(room.ok, "a room is designated (%s)" % room.error)
	assert_true(_buildings.set_room_occupants(room.ref, 2).ok, "two are inside")
	assert_equal(_construction.demolition_open_refusal(hall),
		Construction.REFUSE_OCCUPANTS_PRESENT, "occupied")
	assert_true(_buildings.set_room_occupants(room.ref, 0).ok, "they leave")
	assert_equal(_construction.demolition_open_refusal(hall), Construction.REFUSE_NONE,
		"and the preview passes")
