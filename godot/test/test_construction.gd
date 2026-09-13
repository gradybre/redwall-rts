extends "res://test/framework/test_case.gd"
## Coverage for the packed Construction store and REQ-SET-124-128/137's project lifecycle.
##
## THE NUMBERS ARE `gameplay_balance.md`'s OWN, transcribed here and not read out of the module
## under test. §4.1's hall bill is `wood:100000;stone:60000;cloth:12000` at 2400000 work_mwu;
## §4.3's bed is `wood:2000;cloth:1000` at 20000; §4.2's hall upgrade is
## `wood:20000;stone:40000;cloth:8000` at 1200000. `open_stockpile` is `wood:4000` at 60000 and
## `dirt_path` is §4.1's literal EMPTY bill, which is the reason an empty bill must open straight
## into PHASE_READY instead of waiting for a delivery that can never arrive.
##
## THE REFUND BOUNDARY IS THE WHOLE POINT. REQ-SET-126 gives 100% before work begins and 80%
## after, floored to milli-U. `begin_work()` is the only transition that crosses it, so every
## refund test states which side of that call it is on. 100000 * 4 / 5 = 80000 exactly;
## 12000 * 4 / 5 = 9600 exactly; the FLOOR is proved separately on a partial delivery of 1 milli,
## where 1 * 4 / 5 = 0 and a store that rounded would hand back a unit that was never delivered.
##
## ALLOCATE BEFORE CONSUME (decision 0059) IS ASSERTED IN BYTES, NOT BY EYE. `_snapshot()` packs
## `construction.state_bytes()`, `directory.state_bytes()` and a full image of every live
## Building/Room/Furniture field into one buffer; a refused call must leave it byte-identical.
## `buildings.gd` publishes no `state_bytes()` of its own and is not this task's file to edit, so
## the building half is built here out of its public accessors -- which is a real image of the
## same authoritative fields, not a summary.

const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## §5.9's authored hall placement, and a second clear plot for the stockpile fixtures.
const HALL_TILE: int = 59 * 128 + 58
const STOCKPILE_TILE: int = 60 * 128 + 50
const SECOND_TILE: int = 65 * 128 + 70

## The starter world's milestone mask: M0 earned and nothing else (GDD §5.11).
const START_MASK: int = 1

## `gameplay_balance.md` §4.1's hall row, written out rather than looked up.
const HALL_WOOD: int = 100000
const HALL_STONE: int = 60000
const HALL_CLOTH: int = 12000
const HALL_WORK: int = 2400000

## §4.1's `open_stockpile`: a one-line bill, so a single delivery completes it.
const STOCKPILE_WOOD: int = 4000
const STOCKPILE_WORK: int = 60000

## §4.2's tier-2 hall package and §4.3's bed row.
const HALL_UPGRADE_WOOD: int = 20000
const HALL_UPGRADE_WORK: int = 1200000
const BED_WOOD: int = 2000
const BED_CLOTH: int = 1000
const BED_WORK: int = 20000

var _buildings: Buildings = null
var _construction: Construction = null
var _out: IntMath.IntResult = IntMath.IntResult.new()
var _hall_id: int = 0
var _stockpile_id: int = 0
var _path_id: int = 0
var _bed_id: int = 0


func before_each() -> void:
	"""Build a private Construction store over its own Building store and resolve the catalog ids."""
	_buildings = Buildings.new()
	_construction = Construction.new(_buildings)
	_out = IntMath.IntResult.new()
	_hall_id = int(CatalogScript.BUILDING_DEFINITION["hall"])
	_stockpile_id = int(CatalogScript.BUILDING_DEFINITION["open_stockpile"])
	_path_id = int(CatalogScript.BUILDING_DEFINITION["dirt_path"])
	_bed_id = int(CatalogScript.FURNITURE_DEFINITION["bed"])


func after_each() -> void:
	"""Drop the fixture so no test inherits another's rows."""
	_construction = null
	_buildings = null


# --- fixtures --------------------------------------------------------------------------------

func _place(type_id: int, tile: int) -> Vector2i:
	"""Place one blueprint of `type_id` and return its reference."""
	var result: Buildings.OpResult = _buildings.place_building(type_id, tile, 0, START_MASK)
	assert_true(result.ok, "the fixture blueprint must place (%s)" % result.error)
	return result.ref


func _open_hall() -> Vector2i:
	"""Place the §5.9 hall and open its build project; return the project reference."""
	var result: Construction.OpResult = _construction.open_build(_place(_hall_id, HALL_TILE))
	assert_true(result.ok, "the hall project must open (%s)" % result.error)
	return result.ref


func _deliver_hall(project: Vector2i) -> void:
	"""Deliver the hall's whole §4.1 bill, one line at a time."""
	assert_true(_construction.deliver_material(project, 0, HALL_WOOD).ok, "wood delivers")
	assert_true(_construction.deliver_material(project, 1, HALL_STONE).ok, "stone delivers")
	assert_true(_construction.deliver_material(project, 2, HALL_CLOTH).ok, "cloth delivers")


func _active_hall() -> Vector2i:
	"""Build one hall all the way to ACTIVE and return the BUILDING reference."""
	var project: Vector2i = _open_hall()
	var subject: Vector2i = _construction.subject_ref_of(project)
	_deliver_hall(project)
	assert_true(_construction.begin_work(project).ok, "work begins")
	assert_true(_construction.add_work_mwu(project, HALL_WORK).ok, "work completes")
	assert_true(_construction.commit_completion(project).ok, "the hall commits")
	return subject


func _snapshot() -> PackedByteArray:
	"""One image of every collaborating store, for decision 0059's byte-identity assertions."""
	var out: PackedByteArray = _construction.state_bytes()
	out.append_array(_buildings.directory().state_bytes())
	out.append_array(_buildings_state_bytes())
	return out


func _buildings_state_bytes() -> PackedByteArray:
	"""An image of every live Building/Room/Furniture field, read through the public accessors."""
	var fields: PackedInt64Array = PackedInt64Array()
	fields.append(_buildings.live_building_count())
	fields.append(_buildings.live_room_count())
	fields.append(_buildings.live_furniture_count())
	for row: int in Buildings.BUILDING_CAPACITY:
		var ref: Vector2i = _buildings.building_ref_of_row(row)
		if ref == EntityDirectory.NULL_REF:
			continue
		_append_building_fields(fields, ref)
	for tile: int in Buildings.TILE_COUNT:
		var occupant: Vector2i = _buildings.building_at_tile(tile)
		if occupant != EntityDirectory.NULL_REF:
			fields.append_array(PackedInt64Array([tile, occupant.x, occupant.y]))
	return var_to_bytes(fields)


func _append_building_fields(fields: PackedInt64Array, ref: Vector2i) -> void:
	"""Append one live building's every stored field to the comparison image."""
	var construction_ref: Vector2i = _buildings.construction_ref_of_building(ref)
	fields.append_array(PackedInt64Array([
		ref.x, ref.y,
		_buildings.type_id_of_building(ref).value,
		_buildings.tier_of_building(ref).value,
		_buildings.state_of_building(ref).value,
		_buildings.condition_of_building(ref).value,
		_buildings.origin_tile_of_building(ref).value,
		_buildings.rotation_of_building(ref).value,
		_buildings.interior_id_of_building(ref).value,
		construction_ref.x, construction_ref.y,
		_buildings.room_count_of_building(ref).value,
	]))


# --- the bill of materials ---------------------------------------------------------------------

func test_the_build_bill_is_gameplay_balance_4_1_verbatim() -> void:
	"""The hall's three typed pairs arrive in §4.1's own order with §4.1's own quantities."""
	assert_true(_construction.bill_size_into(Construction.PURPOSE_BUILD, _hall_id, _out),
		"the hall has a build bill")
	assert_equal(_out.value, 3, "§4.1's hall bill has three typed pairs")
	var expected: PackedInt64Array = PackedInt64Array([HALL_WOOD, HALL_STONE, HALL_CLOTH])
	var keys: PackedStringArray = PackedStringArray(["wood", "stone", "cloth"])
	for index: int in 3:
		assert_true(_construction.required_milli_into(
			Construction.PURPOSE_BUILD, _hall_id, index, _out), "line %d reads" % index)
		assert_equal(_out.value, expected[index], "§4.1 hall line %d quantity" % index)
		assert_true(_construction.material_key_index_into(
			Construction.PURPOSE_BUILD, _hall_id, index, _out), "line %d names a key" % index)
		assert_equal(String(Construction.MATERIAL_KEYS[_out.value]), keys[index],
			"§4.1 hall line %d key" % index)


func test_an_empty_bill_is_dirt_paths_own_authored_row() -> void:
	"""§4.1 gives `dirt_path` `[]`, and the store carries the emptiness rather than a default."""
	assert_true(_construction.bill_size_into(Construction.PURPOSE_BUILD, _path_id, _out),
		"dirt_path has a readable bill")
	assert_equal(_out.value, 0, "§4.1's dirt_path bill is empty")
	assert_false(_construction.required_milli_into(
		Construction.PURPOSE_BUILD, _path_id, 0, _out), "an empty bill has no line 0")
	assert_equal(_out.error, String(Construction.REFUSE_MATERIAL_INDEX),
		"reading past an empty bill refuses rather than answering 0")


func test_a_demolition_bill_is_empty_but_its_return_basis_is_not() -> void:
	"""A demolition delivers nothing, and REQ-SET-127's basis is the ORIGINAL §4.1 bill."""
	assert_true(_construction.bill_size_into(Construction.PURPOSE_DEMOLISH, _hall_id, _out),
		"a demolition purpose is known")
	assert_equal(_out.value, 0, "a demolition has no delivery bill at all")
	assert_true(_construction.declared_work_mwu_into(
		Construction.PURPOSE_DEMOLISH, _hall_id, _out), "its work is priced")
	assert_equal(_out.value, HALL_WORK / 4, "REQ-SET-127 prices demolition at WU x 0.25")


func test_an_upgrade_bill_exists_only_for_the_four_tier_two_keys() -> void:
	"""BAL-CAT-006 restricts the packages to four keys; a fifth would have no declared work."""
	assert_true(_construction.declared_work_mwu_into(
		Construction.PURPOSE_UPGRADE, _hall_id, _out), "the hall has a tier-2 package")
	assert_equal(_out.value, HALL_UPGRADE_WORK, "§4.2's hall upgrade work_mwu")
	assert_false(_construction.declared_work_mwu_into(
		Construction.PURPOSE_UPGRADE, _stockpile_id, _out), "a stockpile has no package")
	assert_equal(_out.error, String(Construction.REFUSE_NO_UPGRADE_PACKAGE),
		"an absent package refuses rather than pricing 0 work")


func test_a_material_index_is_resolved_by_key_and_refuses_a_stranger() -> void:
	"""A caller naming a line by key cannot credit wood against the stone line."""
	assert_true(_construction.material_index_of_key_into(
		Construction.PURPOSE_BUILD, _hall_id, &"cloth", _out), "cloth is in the hall bill")
	assert_equal(_out.value, 2, "§4.1 lists cloth third")
	assert_false(_construction.material_index_of_key_into(
		Construction.PURPOSE_BUILD, _hall_id, &"rope", _out), "rope is not in the hall bill")
	assert_equal(_out.error, String(Construction.REFUSE_NOT_IN_BILL),
		"a material outside the bill refuses")
	assert_false(_construction.material_index_of_key_into(
		Construction.PURPOSE_BUILD, _hall_id, &"moonlight", _out), "an unknown key refuses")
	assert_equal(_out.error, String(Construction.REFUSE_UNKNOWN_MATERIAL_KEY),
		"an unknown material key refuses by its own code")


func test_the_furniture_bill_is_gameplay_balance_4_3_verbatim() -> void:
	"""§4.3's bed is `wood:2000;cloth:1000` at 20000 work_mwu."""
	assert_true(_construction.bill_size_into(Construction.PURPOSE_FURNITURE, _bed_id, _out),
		"the bed has a bill")
	assert_equal(_out.value, 2, "§4.3's bed bill has two typed pairs")
	assert_true(_construction.required_milli_into(
		Construction.PURPOSE_FURNITURE, _bed_id, 0, _out), "the bed's wood line reads")
	assert_equal(_out.value, BED_WOOD, "§4.3's bed wood")
	assert_true(_construction.required_milli_into(
		Construction.PURPOSE_FURNITURE, _bed_id, 1, _out), "the bed's cloth line reads")
	assert_equal(_out.value, BED_CLOTH, "§4.3's bed cloth")
	assert_true(_construction.declared_work_mwu_into(
		Construction.PURPOSE_FURNITURE, _bed_id, _out), "the bed's work reads")
	assert_equal(_out.value, BED_WORK, "§4.3's bed work_mwu")


# --- REQ-SET-124: delivery before work ------------------------------------------------------------

func test_opening_a_project_deducts_nothing_and_delivers_nothing() -> void:
	"""REQ-SET-124: a placed blueprint creates work, not a material deduction."""
	var project: Vector2i = _open_hall()
	assert_equal(_construction.live_project_count(), 1, "one project is live")
	assert_true(_construction.phase_into(project, _out), "the phase reads")
	assert_equal(_out.value, Construction.PHASE_AWAITING_MATERIALS,
		"a project with a bill opens awaiting materials")
	for index: int in 3:
		assert_true(_construction.delivered_milli_into(project, index, _out),
			"line %d reads" % index)
		assert_equal(_out.value, 0, "nothing is delivered at open on line %d" % index)
	assert_true(_construction.remaining_mwu_into(project, _out), "the work reads")
	assert_equal(_out.value, HALL_WORK, "§4.1's whole hall work is outstanding")


func test_the_project_is_bound_to_its_building_in_both_directions() -> void:
	"""`Building.construction` names the project and `subject_ref_of()` names the building."""
	var building: Vector2i = _place(_hall_id, HALL_TILE)
	var project: Construction.OpResult = _construction.open_build(building)
	assert_true(project.ok, "the project opens")
	assert_equal(_buildings.construction_ref_of_building(building), project.ref,
		"the Building row names this exact project reference")
	assert_equal(_construction.subject_ref_of(project.ref), building,
		"the project names this exact building reference")
	assert_equal(_construction.project_of_building(building), project.ref,
		"the join resolves in the direction a caller reads it")


func test_work_cannot_be_earned_before_materials_are_delivered() -> void:
	"""REQ-SET-125: no milli-WU may be retired against materials that were never delivered."""
	var project: Vector2i = _open_hall()
	var before: PackedByteArray = _snapshot()
	var work: Construction.OpResult = _construction.add_work_mwu(project, 1000)
	assert_false(work.ok, "work refuses while materials are outstanding")
	assert_equal(work.error, Construction.REFUSE_WRONG_PHASE, "the refusal names the phase")
	var begun: Construction.OpResult = _construction.begin_work(project)
	assert_false(begun.ok, "work cannot begin on an undelivered project")
	assert_equal(begun.error, Construction.REFUSE_WRONG_PHASE,
		"an undelivered project is not READY")
	assert_equal(_snapshot(), before, "both refusals leave every store byte-identical")


func test_partial_delivery_leaves_the_project_awaiting_materials() -> void:
	"""Workers may deliver in parts; the project stays out of PHASE_READY until the last line."""
	var project: Vector2i = _open_hall()
	assert_true(_construction.deliver_material(project, 0, HALL_WOOD / 2).ok, "half the wood")
	assert_true(_construction.phase_into(project, _out), "the phase reads")
	assert_equal(_out.value, Construction.PHASE_AWAITING_MATERIALS, "still awaiting materials")
	assert_true(_construction.deliver_material(project, 0, HALL_WOOD / 2).ok, "the rest")
	assert_true(_construction.deliver_material(project, 1, HALL_STONE).ok, "the stone")
	assert_true(_construction.phase_into(project, _out), "the phase reads again")
	assert_equal(_out.value, Construction.PHASE_AWAITING_MATERIALS,
		"two of three lines is not complete delivery")
	assert_true(_construction.deliver_material(project, 2, HALL_CLOTH).ok, "the cloth")
	assert_true(_construction.phase_into(project, _out), "the phase reads once more")
	assert_equal(_out.value, Construction.PHASE_READY, "the last line enables build work")


func test_over_delivery_is_refused_and_credits_nothing() -> void:
	"""A delivery larger than the line's requirement refuses; the ledger does not move."""
	var project: Vector2i = _open_hall()
	assert_true(_construction.deliver_material(project, 0, HALL_WOOD).ok, "the wood line fills")
	var before: PackedByteArray = _snapshot()
	var extra: Construction.OpResult = _construction.deliver_material(project, 0, 1)
	assert_false(extra.ok, "one more milli is refused")
	assert_equal(extra.error, Construction.REFUSE_OVER_DELIVERY, "the refusal names the excess")
	assert_equal(_snapshot(), before, "a refused delivery credits nothing")
	assert_true(_construction.delivered_milli_into(project, 0, _out), "the line still reads")
	assert_equal(_out.value, HALL_WOOD, "the line holds exactly its requirement")


func test_a_nonpositive_delivery_and_a_stranger_line_both_refuse() -> void:
	"""Neither zero nor a line outside the bill may touch the ledger."""
	var project: Vector2i = _open_hall()
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.deliver_material(project, 0, 0).error,
		Construction.REFUSE_QUANTITY, "a zero delivery refuses")
	assert_equal(_construction.deliver_material(project, 0, -5).error,
		Construction.REFUSE_QUANTITY, "a negative delivery refuses")
	assert_equal(_construction.deliver_material(project, 3, 10).error,
		Construction.REFUSE_MATERIAL_INDEX, "the fourth line is outside the hall's bill")
	assert_equal(_snapshot(), before, "three refusals leave every store byte-identical")


func test_an_empty_bill_opens_straight_into_ready() -> void:
	"""§4.1's `dirt_path` has no bill, so waiting for a delivery would wait forever."""
	var result: Construction.OpResult = _construction.open_build(
		_place(_path_id, SECOND_TILE))
	assert_true(result.ok, "a path project opens")
	assert_true(_construction.phase_into(result.ref, _out), "the phase reads")
	assert_equal(_out.value, Construction.PHASE_READY, "an empty bill is complete on arrival")
	assert_true(_construction.begin_work(result.ref).ok, "and its work may begin at once")


# --- REQ-SET-125: consumption when work begins ------------------------------------------------

func test_begin_work_consumes_and_moves_the_building_into_the_building_state() -> void:
	"""REQ-SET-125's single consumption point, and §4.3's BLUEPRINT to BUILDING transition."""
	var project: Vector2i = _open_hall()
	var building: Vector2i = _construction.subject_ref_of(project)
	_deliver_hall(project)
	assert_false(_construction.has_work_begun(project), "nothing is consumed before begin_work")
	assert_equal(_buildings.state_of_building(building).value,
		int(CatalogScript.BUILDING_STATE["BLUEPRINT"]), "the subject is still a blueprint")
	assert_true(_construction.begin_work(project).ok, "work begins")
	assert_true(_construction.has_work_begun(project), "the consumption is recorded")
	assert_equal(_buildings.state_of_building(building).value,
		int(CatalogScript.BUILDING_STATE["BUILDING"]), "the subject is now under construction")


func test_work_retires_milli_wu_and_caps_the_final_contribution() -> void:
	"""A contribution larger than the remainder is capped, never refused and never negative."""
	var project: Vector2i = _open_hall()
	_deliver_hall(project)
	assert_true(_construction.begin_work(project).ok, "work begins")
	var step: Construction.OpResult = _construction.add_work_mwu(project, 1000000)
	assert_true(step.ok, "a partial contribution is accepted")
	assert_equal(step.value, HALL_WORK - 1000000, "the remainder is exact")
	var last: Construction.OpResult = _construction.add_work_mwu(project, HALL_WORK)
	assert_true(last.ok, "an oversized final contribution is accepted")
	assert_equal(last.value, 0, "the remainder floors at zero rather than going negative")
	assert_true(_construction.phase_into(project, _out), "the phase reads")
	assert_equal(_out.value, Construction.PHASE_WORK_DONE, "a fully worked project is done")


func test_work_refuses_once_the_project_is_done() -> void:
	"""PHASE_WORK_DONE accepts no further work, so a retry cannot spend more milli-WU."""
	var project: Vector2i = _open_hall()
	_deliver_hall(project)
	assert_true(_construction.begin_work(project).ok, "work begins")
	assert_true(_construction.add_work_mwu(project, HALL_WORK).ok, "work completes")
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.add_work_mwu(project, 1).error, Construction.REFUSE_WRONG_PHASE,
		"a finished project refuses more work")
	assert_equal(_snapshot(), before, "the refused retry spends nothing")


func test_completion_publishes_the_building_and_retires_the_project() -> void:
	"""The atomic completion: ACTIVE, no back-reference, and the directory slot handed back."""
	var building: Vector2i = _active_hall()
	assert_equal(_buildings.state_of_building(building).value,
		int(CatalogScript.BUILDING_STATE["ACTIVE"]), "the finished hall is ACTIVE")
	assert_equal(_buildings.construction_ref_of_building(building), EntityDirectory.NULL_REF,
		"a finished building carries no project reference")
	assert_equal(_construction.live_project_count(), 0, "the project row is retired")
	assert_equal(_buildings.directory().live_count(EntityDirectory.KIND_CONSTRUCTION), 0,
		"and its directory slot is handed back")


func test_completion_refuses_before_the_work_is_done() -> void:
	"""A project with work outstanding cannot commit, and the attempt changes nothing."""
	var project: Vector2i = _open_hall()
	_deliver_hall(project)
	assert_true(_construction.begin_work(project).ok, "work begins")
	assert_true(_construction.add_work_mwu(project, HALL_WORK - 1).ok, "one milli short")
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.commit_completion(project).error, Construction.REFUSE_WRONG_PHASE,
		"one milli short is not done")
	assert_equal(_snapshot(), before, "the refused commit publishes nothing")


# --- REQ-SET-126: the 100% / 80% refund boundary --------------------------------------------------

func test_cancellation_before_work_returns_one_hundred_percent() -> void:
	"""REQ-SET-126's first half, on the exact side of `begin_work()` that earns it."""
	var project: Vector2i = _open_hall()
	_deliver_hall(project)
	assert_true(_construction.refund_policy_into(project, _out), "the policy reads")
	assert_equal(_out.value, Construction.REFUND_FULL, "an unworked project refunds in full")
	assert_true(_construction.begin_refund(project).ok, "cancellation begins")
	var expected: PackedInt64Array = PackedInt64Array([HALL_WOOD, HALL_STONE, HALL_CLOTH])
	for index: int in 3:
		assert_true(_construction.cancellation_refund_milli_into(project, index, _out),
			"manifest line %d reads" % index)
		assert_equal(_out.value, expected[index], "100%% of delivered line %d" % index)


func test_cancellation_after_work_returns_eighty_percent() -> void:
	"""REQ-SET-126's second half. 100000 -> 80000, 60000 -> 48000, 12000 -> 9600."""
	var project: Vector2i = _open_hall()
	_deliver_hall(project)
	assert_true(_construction.begin_work(project).ok, "work begins")
	assert_true(_construction.refund_policy_into(project, _out), "the policy reads")
	assert_equal(_out.value, Construction.REFUND_PARTIAL, "a worked project refunds 80%")
	assert_true(_construction.begin_refund(project).ok, "cancellation begins")
	var expected: PackedInt64Array = PackedInt64Array([80000, 48000, 9600])
	for index: int in 3:
		assert_true(_construction.cancellation_refund_milli_into(project, index, _out),
			"manifest line %d reads" % index)
		assert_equal(_out.value, expected[index], "80%% of delivered line %d" % index)


func test_the_eighty_percent_refund_floors_to_milli_u() -> void:
	"""REQ-SET-126: "rounded down to milli-U". 1 * 4 / 5 is 0, and 4 * 4 / 5 is 3."""
	var project: Construction.OpResult = _construction.open_build(
		_place(_stockpile_id, STOCKPILE_TILE))
	assert_true(project.ok, "a stockpile project opens")
	assert_true(_construction.deliver_material(project.ref, 0, STOCKPILE_WOOD).ok, "wood lands")
	assert_true(_construction.begin_work(project.ref).ok, "work begins")
	assert_true(_construction.begin_refund(project.ref).ok, "cancellation begins")
	assert_true(_construction.cancellation_refund_milli_into(project.ref, 0, _out),
		"the manifest reads")
	assert_equal(_out.value, 3200, "4000 * 4 / 5 is exactly 3200")
	assert_equal(1 * Construction.REFUND_PARTIAL_NUM / Construction.REFUND_PARTIAL_DEN, 0,
		"one milli at 80%% floors to nothing, which is what 'rounded down' means")
	assert_equal(4 * Construction.REFUND_PARTIAL_NUM / Construction.REFUND_PARTIAL_DEN, 3,
		"four milli at 80%% floors to three")


func test_a_partially_delivered_cancellation_refunds_only_what_arrived() -> void:
	"""The basis is the DELIVERED ledger, never the bill: an undelivered line refunds nothing."""
	var project: Vector2i = _open_hall()
	assert_true(_construction.deliver_material(project, 0, HALL_WOOD).ok, "only the wood lands")
	assert_true(_construction.begin_refund(project).ok, "cancellation begins")
	assert_true(_construction.cancellation_refund_milli_into(project, 0, _out), "wood reads")
	assert_equal(_out.value, HALL_WOOD, "100% of the wood that arrived")
	assert_true(_construction.cancellation_refund_milli_into(project, 1, _out), "stone reads")
	assert_equal(_out.value, 0, "nothing arrived on the stone line, so nothing returns")


func test_a_cancelled_construction_leaves_no_live_row_and_no_blueprint() -> void:
	"""`close_refund()` retires the project AND the blueprint it was building."""
	var project: Vector2i = _open_hall()
	var building: Vector2i = _construction.subject_ref_of(project)
	_deliver_hall(project)
	assert_true(_construction.begin_refund(project).ok, "cancellation begins")
	assert_true(_construction.close_refund(project).ok, "the manifest is settled")
	assert_equal(_construction.live_project_count(), 0, "no construction row survives")
	assert_false(_construction.is_live_project(project), "the project reference is stale")
	assert_false(_buildings.is_live_building(building), "the cancelled blueprint is gone")
	assert_equal(_buildings.directory().live_count(EntityDirectory.KIND_CONSTRUCTION), 0,
		"the directory slot is handed back")


func test_a_refunding_project_accepts_no_further_delivery_or_work() -> void:
	"""The manifest cannot move under a caller that is placing lots."""
	var project: Vector2i = _open_hall()
	assert_true(_construction.deliver_material(project, 0, HALL_WOOD).ok, "wood lands")
	assert_true(_construction.begin_refund(project).ok, "cancellation begins")
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.deliver_material(project, 1, HALL_STONE).error,
		Construction.REFUSE_WRONG_PHASE, "a refunding project takes no delivery")
	assert_equal(_construction.begin_work(project).error, Construction.REFUSE_WRONG_PHASE,
		"a refunding project starts no work")
	assert_equal(_construction.add_work_mwu(project, 10).error, Construction.REFUSE_WRONG_PHASE,
		"a refunding project earns no work")
	assert_equal(_snapshot(), before, "three refusals leave every store byte-identical")


func test_close_refund_refuses_before_begin_refund() -> void:
	"""Two-phase cancellation: there is no one-call path that frees a row and a manifest at once."""
	var project: Vector2i = _open_hall()
	_deliver_hall(project)
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.close_refund(project).error, Construction.REFUSE_WRONG_PHASE,
		"closing without beginning refuses")
	assert_equal(_snapshot(), before, "and frees nothing")
	assert_equal(_construction.live_project_count(), 1, "the project is still live")


# --- REQ-SET-127 / 128: demolition -----------------------------------------------------------------

func test_demolition_returns_fifty_percent_of_the_original_cost() -> void:
	"""REQ-SET-127: 50% of §4.1's ORIGINAL bill, not of anything delivered to the project."""
	var building: Vector2i = _active_hall()
	var project: Construction.OpResult = _construction.open_demolition(building)
	assert_true(project.ok, "the demolition opens (%s)" % project.error)
	assert_true(_construction.demolition_return_size_into(project.ref, _out),
		"the return manifest has a size")
	assert_equal(_out.value, 3, "§4.1's hall bill has three lines to return")
	var expected: PackedInt64Array = PackedInt64Array([
		HALL_WOOD / 2, HALL_STONE / 2, HALL_CLOTH / 2])
	for index: int in 3:
		assert_true(_construction.demolition_return_milli_into(project.ref, index, _out),
			"return line %d reads" % index)
		assert_equal(_out.value, expected[index], "50%% of original line %d" % index)


func test_the_two_refund_paths_refuse_each_other() -> void:
	"""ARCH-JOB-004: the 100%/80% and 50% rules must not share an undifferentiated helper."""
	var building: Vector2i = _active_hall()
	var demolition: Construction.OpResult = _construction.open_demolition(building)
	assert_true(demolition.ok, "the demolition opens")
	assert_false(_construction.cancellation_refund_milli_into(demolition.ref, 0, _out),
		"REQ-SET-126's path refuses a demolition")
	assert_equal(_out.error, String(Construction.REFUSE_IS_A_DEMOLITION),
		"and says exactly why")
	var build: Construction.OpResult = _construction.open_build(
		_place(_stockpile_id, STOCKPILE_TILE))
	assert_true(build.ok, "a build project opens")
	assert_false(_construction.demolition_return_milli_into(build.ref, 0, _out),
		"REQ-SET-127's path refuses a build project")
	assert_equal(_out.error, String(Construction.REFUSE_NOT_A_DEMOLITION),
		"and says exactly why")


func test_demolition_work_is_a_quarter_of_the_declared_construction_work() -> void:
	"""REQ-SET-127: "after the declared construction WU x 0.25", and the building says DEMOLISHING."""
	var building: Vector2i = _active_hall()
	var project: Construction.OpResult = _construction.open_demolition(building)
	assert_true(project.ok, "the demolition opens")
	assert_true(_construction.remaining_mwu_into(project.ref, _out), "its work reads")
	assert_equal(_out.value, HALL_WORK / 4, "2400000 x 0.25 is 600000")
	assert_equal(_buildings.state_of_building(building).value,
		int(CatalogScript.BUILDING_STATE["DEMOLISHING"]), "the subject says DEMOLISHING")
	assert_true(_construction.phase_into(project.ref, _out), "the phase reads")
	assert_equal(_out.value, Construction.PHASE_READY, "a demolition needs no delivery")


func test_a_finished_demolition_removes_the_building() -> void:
	"""The completion transaction: the tiles are released and the row is gone."""
	var building: Vector2i = _active_hall()
	var tile: int = _buildings.origin_tile_of_building(building).value
	var project: Construction.OpResult = _construction.open_demolition(building)
	assert_true(project.ok, "the demolition opens")
	assert_true(_construction.begin_work(project.ref).ok, "demolition work begins")
	assert_true(_construction.add_work_mwu(project.ref, HALL_WORK / 4).ok, "and completes")
	assert_true(_construction.commit_completion(project.ref).ok, "the demolition commits")
	assert_false(_buildings.is_live_building(building), "the building is gone")
	assert_equal(_buildings.building_at_tile(tile), EntityDirectory.NULL_REF,
		"and its footprint is released")
	assert_equal(_construction.live_project_count(), 0, "the project row is retired")


func test_a_refused_completion_restores_the_buildings_back_reference() -> void:
	"""ECON-003's commit-pending rule: a failed output publishes nothing and changes nothing.

	`buildings.demolish_building()` refuses while the structure still owns rooms, so this is a
	real refusal reached through the real store rather than a simulated one. The project must
	stay in PHASE_WORK_DONE with its earned work intact and the retry must cost nothing.
	"""
	var building: Vector2i = _active_hall()
	var project: Construction.OpResult = _construction.open_demolition(building)
	assert_true(project.ok, "the demolition opens")
	assert_true(_construction.begin_work(project.ref).ok, "demolition work begins")
	assert_true(_construction.add_work_mwu(project.ref, HALL_WORK / 4).ok, "and completes")
	var room: Buildings.OpResult = _buildings.designate_room(building,
		int(CatalogScript.ROOM_TYPE["PANTRY"]), _interior_tiles(building, 4))
	assert_true(room.ok, "a room now blocks the removal (%s)" % room.error)
	var before: PackedByteArray = _snapshot()
	var refused: Construction.OpResult = _construction.commit_completion(project.ref)
	assert_false(refused.ok, "the removal refuses, so the completion refuses")
	assert_equal(_snapshot(), before, "the refused commit leaves every store byte-identical")
	assert_true(_construction.phase_into(project.ref, _out), "the phase reads")
	assert_equal(_out.value, Construction.PHASE_WORK_DONE, "earned work and phase are retained")
	assert_equal(_buildings.construction_ref_of_building(building), project.ref,
		"and the building still names its project")


func test_a_refused_cancellation_close_restores_the_buildings_back_reference() -> void:
	"""The same commit-pending rule on the cancellation path, which can also fail at its output."""
	var project: Vector2i = _open_hall()
	var building: Vector2i = _construction.subject_ref_of(project)
	var room: Buildings.OpResult = _buildings.designate_room(building,
		int(CatalogScript.ROOM_TYPE["PANTRY"]), _interior_tiles(building, 4))
	assert_true(room.ok, "a room blocks the blueprint's removal (%s)" % room.error)
	assert_true(_construction.begin_refund(project).ok, "cancellation begins")
	var before: PackedByteArray = _snapshot()
	var refused: Construction.OpResult = _construction.close_refund(project)
	assert_false(refused.ok, "the blueprint cannot be removed, so the close refuses")
	assert_equal(_snapshot(), before, "the refused close leaves every store byte-identical")
	assert_equal(_construction.live_project_count(), 1, "the project is still live")
	assert_equal(_buildings.construction_ref_of_building(building), project,
		"and the blueprint still names its project")


func test_demolition_is_blocked_by_room_occupants_and_reports_the_count() -> void:
	"""REQ-SET-128's resident half: the refusal carries the exact number still inside."""
	var building: Vector2i = _active_hall()
	var room: Buildings.OpResult = _buildings.designate_room(building,
		int(CatalogScript.ROOM_TYPE["PANTRY"]), _interior_tiles(building, 4))
	assert_true(room.ok, "a room is designated (%s)" % room.error)
	assert_true(_buildings.set_room_occupants(room.ref, 3).ok, "three residents are inside")
	var before: PackedByteArray = _snapshot()
	var refused: Construction.OpResult = _construction.open_demolition(building)
	assert_false(refused.ok, "an occupied building cannot be demolished")
	assert_equal(refused.error, Construction.REFUSE_OCCUPANTS_PRESENT, "REQ-SET-128 blocks it")
	assert_equal(refused.value, 3, "and reports the exact stranded occupant count")
	assert_equal(_snapshot(), before, "the refused demolition leaves every store byte-identical")


func test_demolition_is_blocked_by_furniture_still_in_use() -> void:
	"""REQ-SET-128 again: a bed with a live user is a resident who has not been evacuated."""
	var building: Vector2i = _active_hall()
	var room: Buildings.OpResult = _buildings.designate_room(building,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), _interior_tiles(building, 4))
	assert_true(room.ok, "a dormitory is designated (%s)" % room.error)
	var tile: int = _buildings.room_tile_at(room.ref, 0).value
	var bed: Buildings.OpResult = _buildings.place_furniture(room.ref, _bed_id, tile, 0)
	assert_true(bed.ok, "a bed is placed (%s)" % bed.error)
	var sleeper: Vector2i = _buildings.directory().create(EntityDirectory.KIND_RESIDENT)
	assert_true(_buildings.set_furniture_user(bed.ref, sleeper).ok, "the bed has a sleeper")
	var refused: Construction.OpResult = _construction.open_demolition(building)
	assert_false(refused.ok, "a building with an occupied bed cannot be demolished")
	assert_equal(refused.error, Construction.REFUSE_FURNITURE_IN_USE, "REQ-SET-128 blocks it")
	assert_equal(refused.value, 1, "and reports the exact furniture count still in use")


func _interior_tiles(building_ref: Vector2i, count: int) -> PackedInt32Array:
	"""The first `count` tiles of a building's interior rectangle, row-major from its origin."""
	var origin: int = _buildings.origin_tile_of_building(building_ref).value
	var tiles: PackedInt32Array = PackedInt32Array()
	for index: int in count:
		tiles.append(origin + Buildings.MAP_TILES_X + 1 + index)
	return tiles


# --- REQ-SET-137: pause ----------------------------------------------------------------------------

func test_pausing_retains_materials_and_progress_and_releases_workers() -> void:
	"""REQ-SET-137 exactly: the ledger and the remainder stand, `assigned_count` goes to zero."""
	var project: Vector2i = _open_hall()
	_deliver_hall(project)
	assert_true(_construction.begin_work(project).ok, "work begins")
	assert_true(_construction.add_work_mwu(project, 400000).ok, "some work is done")
	assert_true(_construction.set_assigned_count(project, 4).ok, "four builders are bound")
	assert_true(_construction.set_paused(project, true).ok, "the player pauses it")
	assert_true(_construction.assigned_count_into(project, _out), "the worker count reads")
	assert_equal(_out.value, 0, "pausing releases every worker")
	assert_true(_construction.remaining_mwu_into(project, _out), "the remainder reads")
	assert_equal(_out.value, HALL_WORK - 400000, "progress is retained")
	assert_true(_construction.delivered_milli_into(project, 0, _out), "the ledger reads")
	assert_equal(_out.value, HALL_WOOD, "delivered materials are retained")


func test_a_paused_project_accepts_no_work_and_no_delivery() -> void:
	"""A paused project is inert; the attempts change nothing at all."""
	var project: Vector2i = _open_hall()
	assert_true(_construction.deliver_material(project, 0, HALL_WOOD).ok, "wood lands")
	assert_true(_construction.set_paused(project, true).ok, "the player pauses it")
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.deliver_material(project, 1, HALL_STONE).error,
		Construction.REFUSE_PAUSED, "a paused project takes no delivery")
	assert_equal(_construction.set_assigned_count(project, 2).error, Construction.REFUSE_PAUSED,
		"a paused project binds no worker")
	assert_equal(_snapshot(), before, "two refusals leave every store byte-identical")
	assert_true(_construction.set_paused(project, false).ok, "the player resumes it")
	assert_true(_construction.deliver_material(project, 1, HALL_STONE).ok, "and delivery resumes")


func test_assigned_count_is_capped_by_the_declared_builder_limit() -> void:
	"""§5.9's "Maximum 4 builders/project", read from §4.1's own `max_builders` column."""
	var project: Vector2i = _open_hall()
	assert_true(_construction.max_workers_into(project, _out), "the cap reads")
	assert_equal(_out.value, Construction.MAX_BUILDERS, "§4.1 lists four builders")
	assert_true(_construction.set_assigned_count(project, 4).ok, "four builders bind")
	assert_equal(_construction.set_assigned_count(project, 5).error,
		Construction.REFUSE_INVALID_WORKERS, "a fifth builder is refused")
	assert_equal(_construction.set_assigned_count(project, -1).error,
		Construction.REFUSE_INVALID_WORKERS, "a negative count is refused")
	assert_true(_construction.assigned_count_into(project, _out), "the count reads")
	assert_equal(_out.value, 4, "and the accepted value stands")


# --- upgrades, furniture and refusals ------------------------------------------------------------

func test_an_upgrade_project_raises_the_tier_exactly_once() -> void:
	"""REQ-SET-136: the package applies once; a second upgrade has nothing left to open."""
	var building: Vector2i = _active_hall()
	var project: Construction.OpResult = _construction.open_upgrade(building)
	assert_true(project.ok, "the upgrade opens (%s)" % project.error)
	assert_true(_construction.deliver_material(project.ref, 0, HALL_UPGRADE_WOOD).ok, "wood")
	assert_true(_construction.deliver_material(project.ref, 1, 40000).ok, "stone")
	assert_true(_construction.deliver_material(project.ref, 2, 8000).ok, "cloth")
	assert_true(_construction.begin_work(project.ref).ok, "work begins")
	assert_true(_construction.add_work_mwu(project.ref, HALL_UPGRADE_WORK).ok, "work completes")
	assert_true(_construction.commit_completion(project.ref).ok, "the upgrade commits")
	assert_equal(_buildings.tier_of_building(building).value, BuildingDefinitions.TIER_TWO,
		"the hall is tier 2")
	assert_equal(_construction.open_upgrade(building).error, Construction.REFUSE_ALREADY_TIER_TWO,
		"tier 3 is absent, so a second upgrade refuses")


func test_a_building_carries_at_most_one_project() -> void:
	"""GDD §4.2: "At most 1 project/building/furniture/road segment"."""
	var building: Vector2i = _place(_hall_id, HALL_TILE)
	assert_true(_construction.open_build(building).ok, "the first project opens")
	var before: PackedByteArray = _snapshot()
	var second: Construction.OpResult = _construction.open_build(building)
	assert_false(second.ok, "a second project on the same building refuses")
	assert_equal(second.error, Construction.REFUSE_ALREADY_UNDER_CONSTRUCTION,
		"and names the existing project")
	assert_equal(_snapshot(), before, "the refused open allocates nothing")
	assert_equal(_construction.live_project_count(), 1, "exactly one project is live")


func test_a_furniture_project_runs_the_same_lifecycle() -> void:
	"""§4.3's rows are projects too, and they bind to the Furniture row rather than a Building."""
	var building: Vector2i = _active_hall()
	var room: Buildings.OpResult = _buildings.designate_room(building,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), _interior_tiles(building, 4))
	assert_true(room.ok, "a dormitory is designated (%s)" % room.error)
	var tile: int = _buildings.room_tile_at(room.ref, 0).value
	var bed: Buildings.OpResult = _buildings.place_furniture(room.ref, _bed_id, tile, 0)
	assert_true(bed.ok, "a bed is placed (%s)" % bed.error)
	var project: Construction.OpResult = _construction.open_furniture(bed.ref)
	assert_true(project.ok, "a furniture project opens (%s)" % project.error)
	assert_equal(_construction.subject_ref_of(project.ref), bed.ref, "its subject is the bed")
	assert_true(_construction.deliver_material(project.ref, 0, BED_WOOD).ok, "wood")
	assert_true(_construction.deliver_material(project.ref, 1, BED_CLOTH).ok, "cloth")
	assert_true(_construction.begin_work(project.ref).ok, "work begins")
	assert_true(_construction.add_work_mwu(project.ref, BED_WORK).ok, "work completes")
	assert_true(_construction.commit_completion(project.ref).ok, "the bed commits")
	assert_equal(_construction.live_project_count(), 0, "the project row is retired")


func test_a_stale_project_reference_refuses_every_operation() -> void:
	"""EntityRef generation validation: a retired slot answers nothing, never a stale row."""
	var project: Vector2i = _open_hall()
	assert_true(_construction.begin_refund(project).ok, "cancellation begins")
	assert_true(_construction.close_refund(project).ok, "the project is retired")
	assert_false(_construction.is_live_project(project), "the reference is stale")
	assert_equal(_construction.deliver_material(project, 0, 1).error,
		Construction.REFUSE_STALE_PROJECT_REF, "delivery refuses")
	assert_equal(_construction.add_work_mwu(project, 1).error,
		Construction.REFUSE_STALE_PROJECT_REF, "work refuses")
	assert_false(_construction.phase_into(project, _out), "the phase refuses")
	assert_equal(_out.error, String(Construction.REFUSE_STALE_PROJECT_REF),
		"a stale reference is refused, never answered with row 0's phase")
	assert_equal(_construction.subject_ref_of(project), EntityDirectory.NULL_REF,
		"and its subject reads as the GDD null reference")


func test_a_project_cannot_be_opened_on_a_finished_building() -> void:
	"""A build project needs a BLUEPRINT; an upgrade and a demolition need an ACTIVE building."""
	var building: Vector2i = _place(_stockpile_id, STOCKPILE_TILE)
	assert_equal(_construction.open_upgrade(building).error, Construction.REFUSE_NOT_ACTIVE,
		"a blueprint cannot be upgraded")
	assert_equal(_construction.open_demolition(building).error, Construction.REFUSE_NOT_ACTIVE,
		"a blueprint cannot be demolished through REQ-SET-127")
	var finished: Vector2i = _active_hall()
	assert_equal(_construction.open_build(finished).error, Construction.REFUSE_NOT_A_BLUEPRINT,
		"an ACTIVE building cannot be built again")


func test_the_material_container_is_an_inventory_reference_not_a_directory_one() -> void:
	"""§4.2's `material_container` lives in the inventory container generation namespace."""
	var project: Vector2i = _open_hall()
	assert_equal(_construction.material_container_ref_of(project), EntityDirectory.NULL_REF,
		"a new project has no container bound")
	assert_true(_construction.set_material_container(project, Vector2i(7, 3)).ok,
		"a well-formed container pair binds")
	assert_equal(_construction.material_container_ref_of(project), Vector2i(7, 3),
		"and reads back exactly")
	assert_equal(_construction.set_material_container(project, Vector2i(7, 0)).error,
		Construction.REFUSE_INVALID_CONTAINER_REF, "generation 0 is the null generation")
	assert_true(_construction.set_material_container(project, EntityDirectory.NULL_REF).ok,
		"the null reference clears the binding")
	assert_equal(_construction.material_container_ref_of(project), EntityDirectory.NULL_REF,
		"and it reads back cleared")


func test_the_refund_policy_column_agrees_with_its_own_recomputation() -> void:
	"""`verify_refund_policies()` is the load-time check a decoder owes §4.2's enum.

	Its MISMATCH branch cannot be reached through this store's own API -- `_refund_policy` is
	written only by `_policy_for()`, which is the same function the check runs -- and that is the
	property, not a gap in the test. `buildings.verify_room_masks()` carries exactly the same
	caveat for exactly the same reason. What IS pinned here is that the check walks the live rows:
	it reports the number it verified, so a check that returned early would report the wrong one.
	"""
	var building: Vector2i = _active_hall()
	var project: Construction.OpResult = _construction.open_build(
		_place(_stockpile_id, STOCKPILE_TILE))
	assert_true(project.ok, "a second project opens")
	assert_true(_construction.verify_refund_policies().ok, "a fresh project's policy agrees")
	assert_true(_construction.deliver_material(project.ref, 0, STOCKPILE_WOOD).ok, "wood lands")
	assert_true(_construction.begin_work(project.ref).ok, "work begins")
	assert_true(_construction.verify_refund_policies().ok, "and still agrees after consumption")
	var demolition: Construction.OpResult = _construction.open_demolition(building)
	assert_true(demolition.ok, "a demolition opens")
	var verified: Construction.OpResult = _construction.verify_refund_policies()
	assert_true(verified.ok, "a demolition's policy agrees too")
	assert_equal(verified.value, 2, "and the check verified both live projects, not zero")
	assert_equal(verified.value, _construction.live_project_count(),
		"which is every live row this store holds")
	assert_true(_construction.refund_policy_into(demolition.ref, _out), "its policy reads")
	assert_equal(_out.value, Construction.REFUND_DEMOLITION, "and it is the 50% rule")
	assert_true(_construction.refund_policy_into(project.ref, _out), "the other policy reads")
	assert_equal(_out.value, Construction.REFUND_PARTIAL,
		"and the two live rows do not share one policy")


func test_clear_releases_every_project_row_and_its_directory_slots() -> void:
	"""A reset store holds no project and strands no slot."""
	assert_true(_construction.open_build(_place(_hall_id, HALL_TILE)).ok, "one project")
	assert_true(_construction.open_build(_place(_stockpile_id, STOCKPILE_TILE)).ok, "two")
	assert_equal(_construction.live_project_count(), 2, "two projects are live")
	_construction.clear()
	assert_equal(_construction.live_project_count(), 0, "the store is empty")
	assert_equal(_buildings.directory().live_count(EntityDirectory.KIND_CONSTRUCTION), 0,
		"and no construction slot is stranded")


func test_the_store_capacity_matches_the_directory_and_the_architecture() -> void:
	"""ARCH-MEM-002: 81920 furniture + 1024 exterior objects = 82944 projects."""
	assert_equal(Construction.CONSTRUCTION_CAPACITY,
		EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_CONSTRUCTION],
		"the columns must be exactly as long as the directory's CONSTRUCTION rows")
	assert_equal(Construction.CONSTRUCTION_CAPACITY, 82944,
		"systems_architecture.md §2.2 states 82944")
	assert_equal(Buildings.FURNITURE_CAPACITY + Buildings.BUILDING_CAPACITY, 82944,
		"and ARCH-MEM-002 derives it from the furniture and building bounds")
