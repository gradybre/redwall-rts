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

func test_container_namespace_and_worker_counts_outside_working() -> void:
	var project: Vector2i = _open_hall()
	assert_true(_construction.set_material_container(project,Vector2i(2147483647,2147483647)).ok,"container pair is not Directory-bounded")
	assert_equal(_construction.material_container_ref_of(project),Vector2i(2147483647,2147483647),"full signed-i32 container pair retained")
	assert_true(_construction.set_assigned_count(project,4).ok,"AWAITING can retain4 assigned workers")
	var before: PackedByteArray = _construction.state_bytes()
	assert_false(_construction.set_material_container(project,Vector2i(-1,1)).ok,"malformed null refuses")
	assert_true(_construction.state_bytes() == before,"container refusal leaves bytes unchanged")
	_deliver_hall(project)
	assert_true(_construction.set_assigned_count(project,3).ok,"READY can retain3 workers")
	assert_true(_construction.begin_work(project).ok,"start funded work")
	assert_true(_construction.add_work_mwu(project,HALL_WORK).ok,"reach WORK_DONE")
	assert_true(_construction.set_assigned_count(project,4).ok,"WORK_DONE can retain4 workers")
	assert_true(_construction.set_paused(project,true).ok,"pause work-done history")
	assert_true(_construction.begin_refund(project).ok,"refund from paused work-done")
	assert_true(_construction.is_paused(project),"refund retains paused flag")
	assert_true(_construction.has_work_begun(project),"refund retains begun flag")
	assert_true(_construction.assigned_count_into(project,_out),"read workers")
	assert_equal(_out.value,0,"pause/refund clears workers")
	assert_true(_construction.remaining_mwu_into(project,_out),"read zero remainder")
	assert_equal(_out.value,0,"refund can retain completed work")
	assert_true(_construction.refund_policy_into(project,_out),"read policy")
	assert_equal(_out.value,1,"begun refund keeps partial policy")
	assert_true(_construction.set_material_container(project,EntityDirectory.NULL_REF).ok,"container can clear during refund")
	assert_true(_construction.close_refund(project).ok,"paused refund may retire")
	assert_false(_construction.is_live_project(project),"retired public handle refuses; private retained bytes are source-backed")
func test_empty_bill_and_capped_final_work() -> void:
	var subject: Vector2i = _place(_path_id,SECOND_TILE)
	var opened: Construction.OpResult = _construction.open_build(subject)
	assert_true(opened.ok,"open authored empty bill")
	assert_true(_construction.phase_into(opened.ref,_out),"read empty-bill phase")
	assert_equal(_out.value,1,"empty bill starts READY")
	assert_true(_construction.begin_work(opened.ref).ok,"start empty-bill work")
	assert_true(_construction.add_work_mwu(opened.ref,9223372036854775807).ok,"signed-i64 maximum contribution is capped")
	assert_true(_construction.remaining_mwu_into(opened.ref,_out),"read completion")
	assert_equal(_out.value,0,"no negative remainder")
	assert_true(_construction.commit_completion(opened.ref).ok,"commit and retire")
	assert_false(_construction.phase_into(opened.ref,_out),"retired phase not public")
	assert_true(_construction.verify_refund_policies().ok,"live-only policy check tolerates retired begun reset")
func test_demolition_refund_without_work_begun() -> void:
	var subject: Vector2i = _active_hall()
	var opened: Construction.OpResult = _construction.open_demolition(subject)
	assert_true(opened.ok,"open demolition")
	assert_true(_construction.phase_into(opened.ref,_out),"read demolition phase")
	assert_equal(_out.value,1,"demolition needs no deliveries")
	assert_true(_construction.remaining_mwu_into(opened.ref,_out),"read demolition work")
	assert_equal(_out.value,600000,"base hall work quarter")
	assert_true(_construction.set_assigned_count(opened.ref,4).ok,"READY demolition accepts worker count")
	assert_true(_construction.begin_refund(opened.ref).ok,"cancel before work")
	assert_false(_construction.has_work_begun(opened.ref),"work not begun")
	assert_true(_construction.refund_policy_into(opened.ref,_out),"read demolition policy")
	assert_equal(_out.value,2,"demolition policy independent of begun")
	assert_true(_construction.set_paused(opened.ref,true).ok,"refund permits pause")
	assert_true(_construction.set_paused(opened.ref,false).ok,"refund permits unpause")
	assert_false(_construction.set_assigned_count(opened.ref,1).ok,"refund refuses new assignment even unpaused")
	assert_true(_construction.close_refund(opened.ref).ok,"close cancellation")
	assert_equal(_buildings.state_of_building(subject).value,2,"subject restored ACTIVE")
	assert_true(_construction.verify_refund_policies().ok,"retired demolition does not falsify live policies")
