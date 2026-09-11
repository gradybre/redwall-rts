extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/gear.gd` — the GearInstance store and its lowest-free-row allocator.
##
## Every acceptance item ruling §4 names is a test below, under its own name:
##   * allocation reaches row 16383 (`test_allocates_through_slot_16383`);
##   * a full pool refuses atomically, before anything is consumed
##     (`test_full_pool_creation_refuses_atomically`);
##   * the lowest freed row is reused deterministically
##     (`test_lowest_freed_row_is_reused_deterministically`);
##   * stale lot, owner and job handles fail (`test_stale_*_handle_fails`);
##   * two Jobs cannot claim one gear object (`test_two_jobs_cannot_claim_one_gear_object`);
##   * exact wear starts and one below refuses (`test_exact_wear_starts_and_one_below_refuses`);
##   * repeated completion and cancellation cannot double-debit or double-release;
##   * repair clamps to the correct cap, per wear model, and is not a reset.
##
## Two structural cases go beyond the list because the ruling's wording depends on them:
## `test_eligibility_predicate_is_not_the_gear_category` pins `candle` -- category GEAR, NOT
## instance-required -- as the counter-example that makes the broad category test wrong, and
## `test_no_row_is_published_before_it_is_initialised` walks the private columns to prove that a
## live row is never half-written and a freed row is never half-blanked.
##
## Where a test must observe the ALLOCATOR rather than the gear, it reads the store's private
## columns through `get()`, exactly as `test_reservations.gd` does. That is deliberate: the row
## index is not part of the public surface -- no raw gear-row index may escape as a durable
## handle -- so the only honest way to assert which row was reused is to look at the column.
##
## Item ids and masses come from the real compiled catalog through `item_definitions.gd`, never
## from a hand-written second copy of §3.1.

const GearScript := preload("res://scripts/core/gear.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

const CONTAINER_OWNER: Vector2i = Vector2i(7, 1)
const BIG_MASS: int = 9000000000
const TEST_PROVENANCE: int = 3
const TEST_POLICY: int = 0
const SMALL_POOL: int = 64
## GDD §5.7, restated: "tool 1000g". The mass an equipped tool stops charging its container.
const TOOL_MASS_G: int = 1000

## Job references. Job liveness lives in the Job store, which `gear.gd` deliberately does not
## depend on, so these are plain in-range `(slot, generation)` pairs.
const JOB_A: Vector2i = Vector2i(3, 1)
const JOB_B: Vector2i = Vector2i(9, 2)
## Same slot as JOB_A, later generation: the stale-handle case.
const JOB_A_STALE: Vector2i = Vector2i(3, 2)

var _inv: InventoryScript = null
var _defs: ItemDefinitionsScript = null
var _store: GearScript = null
var _container: Vector2i = Vector2i(-1, 0)
var _out: IntMathScript.IntResult = null
var _wear: GearScript.WearOutcome = null
## Built only by the equipped-gear tests below; every other test leaves it null.
var _residents: ResidentsScript = null


func before_each() -> void:
	"""Build a small inventory with the real catalog loaded and a 64-row gear store."""
	_inv = InventoryScript.new(8, 256)
	_defs = ItemDefinitionsScript.new()
	var loaded: ItemDefinitionsScript.LoadResult = _defs.load_default(_inv)
	assert_true(loaded.ok, "the real item catalog must load: %s" % loaded.error)
	_store = GearScript.new(SMALL_POOL)
	_container = _inv.create_container(CONTAINER_OWNER, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true).ref
	_out = IntMathScript.IntResult.new()
	_wear = GearScript.WearOutcome.new()
	_residents = null


func _id(key: StringName) -> int:
	"""Compiled catalog id of an item key."""
	return _defs.compiled_id(key)


func _lot(key: StringName, quantity_milli: int = GearScript.GEAR_LOT_QUANTITY_MILLI) -> Vector2i:
	"""Create one indivisible lot of `key` in the shared container."""
	return _inv.create_lot(_container, _id(key), quantity_milli, 0, TEST_PROVENANCE, 0, 0, 0).ref


func _gear(key: StringName,
		manufacture: int = GearScript.MANUFACTURE_BASIC) -> Vector2i:
	"""Create a lot of `key` and its gear instance; return the lot reference."""
	var lot_ref: Vector2i = _lot(key)
	var made: InventoryScript.OpResult = _store.create_gear(_inv, _defs, lot_ref, manufacture)
	assert_true(made.ok, "creating %s gear must succeed: %s" % [key, made.error])
	return lot_ref


func _durability(lot_ref: Vector2i) -> int:
	"""Current durability of a gear instance, asserting the read itself succeeded."""
	assert_true(_store.durability_into(lot_ref, _out), "durability must be readable")
	return _out.value


func _run_cycle(lot_ref: Vector2i, job_ref: Vector2i) -> int:
	"""Claim, complete one fishing cycle, and return the wear that was applied."""
	var claimed: InventoryScript.OpResult = _store.claim_for_job(lot_ref, job_ref)
	assert_true(claimed.ok, "cycle claim must succeed: %s" % claimed.error)
	var done: InventoryScript.OpResult = _store.complete_cycle(lot_ref, job_ref)
	assert_true(done.ok, "cycle completion must succeed: %s" % done.error)
	return done.value


func _retire_lot(lot_ref: Vector2i) -> void:
	"""Consume a lot to zero so its slot retires and its generation advances."""
	var sunk: InventoryScript.OpResult = _inv.sink_lot_quantity(lot_ref,
		_inv.lot_quantity_milli(lot_ref))
	assert_true(sunk.ok, "sinking a lot to zero must succeed: %s" % sunk.error)
	assert_false(_inv.is_lot_valid(lot_ref), "a fully consumed lot must retire")


# --- Budget ------------------------------------------------------------------------------------

func test_allocator_and_claim_bytes_match_the_ruling() -> void:
	"""The three ledger figures are re-derived from the columns actually allocated."""
	var full: GearScript = GearScript.new()
	assert_equal(full.allocator_bytes(), GearScript.BUDGET_ALLOCATOR_BYTES,
		"allocator payload must be 81924 bytes")
	assert_equal(full.claim_bytes(), GearScript.BUDGET_CLAIM_BYTES,
		"exclusive-claim payload must be 131072 bytes")
	assert_equal(full.allocator_bytes() + full.claim_bytes(),
		GearScript.BUDGET_ADDITIONAL_BYTES, "additional packed payload must be 212996 bytes")
	assert_equal(full.payload_bytes(), GearScript.BUDGET_PAYLOAD_BYTES,
		"the pre-existing fixed-field payload must still be 540672 bytes")
	assert_equal(full.row_capacity(), 16384, "the store keeps the already-budgeted 16384 rows")


# --- Instance eligibility ----------------------------------------------------------------------

func test_eligibility_predicate_is_not_the_gear_category() -> void:
	"""The five named keys are instance-required; `candle` shares their category and is not.

	This is the case that makes `category == GEAR` the wrong predicate, so it is asserted
	independently of the category rather than through it.
	"""
	for key: StringName in GearScript.INSTANCE_REQUIRED_KEYS:
		assert_true(_store.is_instance_required_item(_defs, _id(key)),
			"%s must be instance-required" % key)
	assert_false(_store.is_instance_required_item(_defs, _id(&"candle")),
		"candle must stay stackable consumable inventory")
	var gear_category: int = _defs.category_compiled_id(&"GEAR")
	assert_equal(_inv.item_category(_id(&"candle")), gear_category,
		"candle's category really is GEAR -- that is the whole point")
	assert_equal(_inv.item_category(_id(&"tool")), gear_category,
		"tool shares candle's category, so the category cannot separate them")
	assert_false(_store.is_instance_required_item(_defs, _id(&"wood")),
		"an ordinary material is not instance-required")
	assert_equal(GearScript.INSTANCE_REQUIRED_KEYS.size(), 5, "there are exactly five keys")


func test_candle_cannot_be_given_a_gear_instance() -> void:
	"""The predicate is enforced at creation, not merely reported."""
	var lot_ref: Vector2i = _lot(&"candle")
	var made: InventoryScript.OpResult = _store.create_gear(_inv, _defs, lot_ref,
		GearScript.MANUFACTURE_BASIC)
	assert_false(made.ok, "candle must be refused a gear instance")
	assert_equal(made.error, GearScript.REFUSE_NOT_INSTANCE_REQUIRED,
		"the refusal names the predicate, not the category")
	assert_equal(_store.active_gear_count(), 0, "a refused create allocates no row")


func test_wear_models_are_assigned_per_item() -> void:
	"""tool is GENERAL, net/trap/ice_kit are FISHING, outfit_tier2 is NONE."""
	assert_true(_store.wear_model_for_item_into(_defs, _id(&"tool"), _out), "tool has a model")
	assert_equal(_out.value, GearScript.WEAR_MODEL_GENERAL, "tool wears by the general rule")
	for key: StringName in [&"net", &"trap", &"ice_kit"]:
		assert_true(_store.wear_model_for_item_into(_defs, _id(key), _out), "%s has a model" % key)
		assert_equal(_out.value, GearScript.WEAR_MODEL_FISHING, "%s wears per cycle" % key)
	assert_true(_store.wear_model_for_item_into(_defs, _id(&"outfit_tier2"), _out),
		"outfit_tier2 has a model")
	assert_equal(_out.value, GearScript.WEAR_MODEL_NONE, "a tier-2 outfit does not wear")
	assert_false(_store.wear_model_for_item_into(_defs, _id(&"candle"), _out),
		"candle has no wear model at all")


func test_cycle_wear_matches_the_gear_table() -> void:
	"""GDD §5.4 Wear/cycle: net 20, trap 10, ice kit 20. General tools have no cycle wear."""
	assert_true(_store.cycle_wear_for_item_into(_defs, _id(&"net"), _out), "net has cycle wear")
	assert_equal(_out.value, 20, "hand net wears 20 per cycle")
	assert_true(_store.cycle_wear_for_item_into(_defs, _id(&"trap"), _out), "trap has cycle wear")
	assert_equal(_out.value, 10, "trap wears 10 per cycle")
	assert_true(_store.cycle_wear_for_item_into(_defs, _id(&"ice_kit"), _out), "ice kit wears")
	assert_equal(_out.value, 20, "ice kit wears 20 per cycle, same as the net cycle it modifies")
	assert_false(_store.cycle_wear_for_item_into(_defs, _id(&"tool"), _out),
		"a general tool has no per-cycle wear")
	assert_equal(_out.error, String(GearScript.REFUSE_WRONG_WEAR_MODEL),
		"and says so by naming the wrong model")


func test_durability_caps_follow_manufacture_and_model() -> void:
	"""Basic 1000, iron 1500, fishing 1000, tier-2 outfit 0."""
	assert_true(_store.durability_cap_for_into(_defs, _id(&"tool"),
		GearScript.MANUFACTURE_BASIC, _out), "basic tool has a cap")
	assert_equal(_out.value, 1000, "a basic tool caps at 1000")
	assert_true(_store.durability_cap_for_into(_defs, _id(&"tool"),
		GearScript.MANUFACTURE_IRON, _out), "iron tool has a cap")
	assert_equal(_out.value, 1500, "an iron tool caps at 1500")
	assert_true(_store.durability_cap_for_into(_defs, _id(&"net"),
		GearScript.MANUFACTURE_BASIC, _out), "net has a cap")
	assert_equal(_out.value, 1000, "fishing gear caps at 1000")
	assert_true(_store.durability_cap_for_into(_defs, _id(&"outfit_tier2"),
		GearScript.MANUFACTURE_BASIC, _out), "outfit has a cap")
	assert_equal(_out.value, 0, "a tier-2 outfit's canonical cap is 0")


func test_iron_manufacture_belongs_to_tool_alone() -> void:
	"""`tool` is the only §5.7 output with two recipes, so only it may be iron."""
	assert_true(_store.is_manufacture_valid_for_item(_defs, _id(&"tool"),
		GearScript.MANUFACTURE_IRON), "iron_tool is a real recipe")
	assert_false(_store.is_manufacture_valid_for_item(_defs, _id(&"net"),
		GearScript.MANUFACTURE_IRON), "there is no iron net recipe")
	var lot_ref: Vector2i = _lot(&"net")
	var made: InventoryScript.OpResult = _store.create_gear(_inv, _defs, lot_ref,
		GearScript.MANUFACTURE_IRON)
	assert_false(made.ok, "an iron net must be refused")
	assert_equal(made.error, GearScript.REFUSE_INVALID_MANUFACTURE, "and named as such")
	var iron_tool: Vector2i = _gear(&"tool", GearScript.MANUFACTURE_IRON)
	assert_true(_store.durability_cap_into(iron_tool, _out), "the iron tool exists")
	assert_equal(_out.value, 1500, "and carries the 1500 cap its recipe specifies")


# --- Creation ----------------------------------------------------------------------------------

func test_new_gear_starts_at_its_cap_and_unclaimed() -> void:
	"""§5.7's iron_tool produces "tool 1 at 1500 durability"; §4.2's starter tools are at 1000."""
	var basic: Vector2i = _gear(&"tool")
	assert_equal(_durability(basic), 1000, "a fresh basic tool is at 1000")
	assert_true(_store.durability_cap_into(basic, _out), "its cap is readable")
	assert_equal(_out.value, 1000, "and is 1000")
	assert_false(_store.is_claimed(basic), "fresh gear is unclaimed")
	assert_equal(_store.claim_job_of(basic), GearScript.NULL_REF, "and names no Job")
	assert_equal(_store.owner_of(basic), GearScript.NULL_REF, "and no owner")
	assert_true(_store.manufacture_into(basic, _out), "its manufacture is readable")
	assert_equal(_out.value, GearScript.MANUFACTURE_BASIC, "and is the basic method")
	assert_equal(_store.active_gear_count(), 1, "exactly one row is live")


func test_gear_lot_must_be_indivisible() -> void:
	"""ARCH-STATE-001: a gear lot is exactly one unit; stacking partly used tools is forbidden."""
	var lot_ref: Vector2i = _lot(&"tool", 2000)
	var made: InventoryScript.OpResult = _store.create_gear(_inv, _defs, lot_ref,
		GearScript.MANUFACTURE_BASIC)
	assert_false(made.ok, "a two-unit tool lot cannot carry one instance")
	assert_equal(made.error, GearScript.REFUSE_LOT_NOT_INDIVISIBLE, "and says why")
	assert_equal(_store.active_gear_count(), 0, "nothing was allocated")


func test_one_lot_carries_at_most_one_instance() -> void:
	"""A second instance on the same live lot is refused, not silently added."""
	var lot_ref: Vector2i = _gear(&"tool")
	var again: InventoryScript.OpResult = _store.create_gear(_inv, _defs, lot_ref,
		GearScript.MANUFACTURE_BASIC)
	assert_false(again.ok, "a lot cannot carry two gear instances")
	assert_equal(again.error, GearScript.REFUSE_GEAR_ALREADY_EXISTS, "and is named as a duplicate")
	assert_equal(_store.active_gear_count(), 1, "still exactly one row")


func test_create_refuses_inside_an_open_inventory_transaction() -> void:
	"""A gear row written against an uncommitted lot would survive the rollback that erased it."""
	var lot_ref: Vector2i = _lot(&"tool")
	assert_true(_inv.begin().ok, "the transaction opens")
	var made: InventoryScript.OpResult = _store.create_gear(_inv, _defs, lot_ref,
		GearScript.MANUFACTURE_BASIC)
	assert_false(made.ok, "creation must wait for the transaction to close")
	assert_equal(made.error, GearScript.REFUSE_INVENTORY_TRANSACTION_OPEN, "and says so")
	_inv.abort()
	assert_equal(_store.active_gear_count(), 0, "nothing was allocated")


# --- Allocator ---------------------------------------------------------------------------------

func test_allocates_through_slot_16383() -> void:
	"""Every one of the 16384 already-budgeted rows is reachable, up to and including 16383."""
	var big_inventory: InventoryScript = InventoryScript.new(4, InventoryScript.LOT_CAPACITY)
	var definitions: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(definitions.load_default(big_inventory).ok, "the catalog loads")
	var store: GearScript = GearScript.new()
	var container: Vector2i = big_inventory.create_container(CONTAINER_OWNER, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true).ref
	var tool_id: int = definitions.compiled_id(&"tool")
	var failures_seen: int = 0
	for index: int in range(GearScript.ROW_CAPACITY):
		var lot_ref: Vector2i = big_inventory.create_lot(container, tool_id,
			GearScript.GEAR_LOT_QUANTITY_MILLI, 0, TEST_PROVENANCE, 0, 0, 0).ref
		if not store.create_gear(big_inventory, definitions, lot_ref,
				GearScript.MANUFACTURE_BASIC).ok:
			failures_seen += 1
	assert_equal(failures_seen, 0, "all 16384 creations must succeed")
	assert_equal(store.active_gear_count(), 16384, "every budgeted row is live")
	assert_equal(store.free_row_count(), 0, "and none is left free")
	var occupied: PackedByteArray = store.get("_occupied")
	assert_equal(occupied[16383], 1, "row 16383 itself is occupied")
	assert_true(store.audit().ok, "the full pool still audits clean")


func test_full_pool_creation_refuses_atomically() -> void:
	"""A full pool refuses before anything is consumed, and leaves no partial record behind."""
	var lots: Array[Vector2i] = []
	for index: int in range(SMALL_POOL):
		lots.append(_gear(&"tool"))
	assert_equal(_store.free_row_count(), 0, "the pool is full")
	var wood_before: int = _inv.total_live_milli(_id(&"wood"))
	var preflight: InventoryScript.OpResult = _store.preflight_create(_defs, _id(&"tool"),
		GearScript.MANUFACTURE_BASIC)
	assert_false(preflight.ok, "the preflight refuses BEFORE materials are consumed")
	assert_equal(preflight.error, GearScript.REFUSE_CAPACITY_GEAR_INSTANCE, "with the capacity code")
	var overflow_lot: Vector2i = _lot(&"tool")
	var made: InventoryScript.OpResult = _store.create_gear(_inv, _defs, overflow_lot,
		GearScript.MANUFACTURE_BASIC)
	assert_false(made.ok, "creation refuses too")
	assert_equal(made.error, GearScript.REFUSE_CAPACITY_GEAR_INSTANCE, "with the same code")
	assert_equal(_store.active_gear_count(), SMALL_POOL, "no row was half-taken")
	assert_equal(_inv.total_live_milli(_id(&"wood")), wood_before, "and no material moved")
	assert_true(_store.audit().ok, "the store still audits clean")
	assert_false(_store.has_gear(overflow_lot), "the refused lot carries no instance")


func test_lowest_freed_row_is_reused_deterministically() -> void:
	"""Freeing rows 3 then 1 must hand row 1 back first, not the most recently freed row.

	Reads the private columns because no raw gear-row index escapes through the public API.
	"""
	var lots: Array[Vector2i] = []
	for index: int in range(5):
		lots.append(_gear(&"tool"))
	var lot_slots: PackedInt32Array = _store.get("_lot_slot")
	assert_equal(lot_slots[1], lots[1].x, "creation filled rows in ascending order")
	assert_equal(lot_slots[3], lots[3].x, "row 3 holds the fourth gear object")
	_retire_lot(lots[3])
	assert_true(_store.destroy_gear(_inv, _defs, lots[3]).ok, "row 3 is released first")
	_retire_lot(lots[1])
	assert_true(_store.destroy_gear(_inv, _defs, lots[1]).ok, "row 1 is released second")
	var heap: PackedInt32Array = _store.get("_free_heap")
	assert_equal(heap[0], 1, "the min-heap's top is the LOWEST freed row, not the newest")
	var reused: Vector2i = _gear(&"tool")
	lot_slots = _store.get("_lot_slot")
	assert_equal(lot_slots[1], reused.x, "the next allocation takes row 1")
	var second: Vector2i = _gear(&"tool")
	lot_slots = _store.get("_lot_slot")
	assert_equal(lot_slots[3], second.x, "and the one after that takes row 3")


func test_no_row_is_published_before_it_is_initialised() -> void:
	"""Every live row is fully written and every free row is fully blank.

	Occupancy is published last on creation and the row is blanked before it returns to the
	heap, so neither a half-written live row nor a half-blanked free row can exist.
	"""
	var keep: Vector2i = _gear(&"net")
	var recycled: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(recycled, JOB_A).ok, "the doomed row is claimed")
	assert_true(_store.cancel_claim(recycled, JOB_A).ok, "and released")
	_retire_lot(recycled)
	assert_true(_store.destroy_gear(_inv, _defs, recycled).ok, "then destroyed")
	_check_row_integrity()
	var fresh: Vector2i = _gear(&"trap")
	assert_false(_store.is_claimed(fresh), "a recycled row carries no stale claim")
	assert_equal(_store.claim_job_of(fresh), GearScript.NULL_REF, "and no stale Job reference")
	assert_equal(_durability(fresh), 1000, "and no stale durability")
	assert_equal(_durability(keep), 1000, "the untouched row is unaffected")
	_check_row_integrity()


func _check_row_integrity() -> void:
	"""Assert every row is either fully initialised and occupied, or fully blank and free."""
	var occupied: PackedByteArray = _store.get("_occupied")
	var lot_slots: PackedInt32Array = _store.get("_lot_slot")
	var item_ids: PackedInt32Array = _store.get("_item_id")
	var durability: PackedInt32Array = _store.get("_durability")
	var claims: PackedInt32Array = _store.get("_claim_job_slot")
	var live: int = 0
	var blank: int = 0
	for row: int in range(SMALL_POOL):
		if occupied[row] == 1:
			live += 1
			if lot_slots[row] < 0 or item_ids[row] < 0:
				fail("live row %d is missing its identity" % row)
			continue
		blank += 1
		if lot_slots[row] != -1 or item_ids[row] != -1 or durability[row] != 0 or claims[row] != -1:
			fail("free row %d was not fully blanked" % row)
	assert_equal(live, _store.active_gear_count(), "occupancy agrees with the live count")
	assert_equal(blank, _store.free_row_count(), "and the rest are free")


# --- Stale handles -----------------------------------------------------------------------------

func test_stale_lot_handle_fails() -> void:
	"""A reused lot slot with a new generation resolves to no gear at all."""
	var original: Vector2i = _gear(&"tool")
	_retire_lot(original)
	var replacement: Vector2i = _lot(&"tool")
	assert_equal(replacement.x, original.x, "the lot slot really was reused")
	assert_true(replacement.y > original.y, "with a later generation")
	assert_false(_store.has_gear(replacement), "the new reference resolves to no gear")
	assert_false(_store.durability_into(replacement, _out), "and reads nothing")
	assert_equal(_out.error, String(GearScript.REFUSE_NO_SUCH_GEAR), "naming the missing record")
	var made: InventoryScript.OpResult = _store.create_gear(_inv, _defs, replacement,
		GearScript.MANUFACTURE_BASIC)
	assert_false(made.ok, "and the stale record blocks a silent second row on that slot")
	assert_equal(made.error, GearScript.REFUSE_GEAR_STALE_RECORD, "which is named explicitly")
	assert_equal(_store.recorded_lot_ref_at_lot_slot(original.x), original,
		"the stale record's own reference is recoverable for cleanup")


func test_stale_job_handle_fails() -> void:
	"""Completion and cancellation compare the full `(slot, generation)` claim key."""
	var net: Vector2i = _gear(&"net")
	assert_true(_store.claim_for_job(net, JOB_A).ok, "the claim is taken")
	var completed: InventoryScript.OpResult = _store.complete_cycle(net, JOB_A_STALE)
	assert_false(completed.ok, "a reused Job slot cannot complete another Job's cycle")
	assert_equal(completed.error, GearScript.REFUSE_GEAR_CLAIM_MISMATCH, "and is named a mismatch")
	var cancelled: InventoryScript.OpResult = _store.cancel_claim(net, JOB_A_STALE)
	assert_false(cancelled.ok, "nor cancel it")
	assert_equal(cancelled.error, GearScript.REFUSE_GEAR_CLAIM_MISMATCH, "with the same code")
	assert_equal(_durability(net), 1000, "and no wear was applied")
	assert_equal(_store.claim_job_of(net), JOB_A, "the real claimant still holds it")


func test_stale_owner_handle_fails() -> void:
	"""An owner reference is checked against the directory, generation included."""
	var directory: EntityDirectoryScript = EntityDirectoryScript.new()
	var resident: Vector2i = directory.create(EntityDirectoryScript.KIND_RESIDENT)
	var net: Vector2i = _gear(&"net")
	assert_true(_store.set_owner(directory, net, resident).ok, "a live resident may own gear")
	assert_equal(_store.owner_of(net), resident, "and is recorded")
	assert_true(_store.has_live_owner(directory, net), "and resolves")
	assert_true(directory.destroy(resident), "the resident then dies")
	assert_false(_store.has_live_owner(directory, net), "so the recorded owner no longer resolves")
	var stale: InventoryScript.OpResult = _store.set_owner(directory, net, resident)
	assert_false(stale.ok, "and the dead reference cannot be re-bound")
	assert_equal(stale.error, GearScript.REFUSE_INVALID_OWNER, "which is named explicitly")


func test_installed_owner_kinds_are_refused_not_guessed() -> void:
	"""The boat/weir owner discriminator is unresolved, so a non-resident owner is refused."""
	var directory: EntityDirectoryScript = EntityDirectoryScript.new()
	var building: Vector2i = directory.create(EntityDirectoryScript.KIND_BUILDING)
	var net: Vector2i = _gear(&"net")
	var bound: InventoryScript.OpResult = _store.set_owner(directory, net, building)
	assert_false(bound.ok, "an installed owner is not settled and is not guessed at")
	assert_equal(bound.error, GearScript.REFUSE_OWNER_KIND_UNSUPPORTED, "and says which gap")
	assert_equal(_store.owner_of(net), GearScript.NULL_REF, "the gear stays unowned")


# --- Claims ------------------------------------------------------------------------------------

func test_two_jobs_cannot_claim_one_gear_object() -> void:
	"""REQ-SET-044's reservation is exclusive: the second claimant is refused, whoever it is."""
	var net: Vector2i = _gear(&"net")
	var first: InventoryScript.OpResult = _store.claim_for_job(net, JOB_A)
	assert_true(first.ok, "the first Job claims it")
	assert_equal(first.value, 20, "against the net's 20-per-cycle wear")
	var second: InventoryScript.OpResult = _store.claim_for_job(net, JOB_B)
	assert_false(second.ok, "a second Job cannot claim the same gear")
	assert_equal(second.error, GearScript.REFUSE_GEAR_ALREADY_CLAIMED, "and is named as such")
	var again: InventoryScript.OpResult = _store.claim_for_job(net, JOB_A)
	assert_false(again.ok, "and neither can the holder claim it twice")
	assert_equal(again.error, GearScript.REFUSE_GEAR_ALREADY_CLAIMED, "with the same code")
	assert_equal(_store.claim_job_of(net), JOB_A, "the original claim is untouched")


func test_exact_wear_starts_and_one_below_refuses() -> void:
	"""§5.4: "A cycle cannot start with durability below wear" -- exactly at wear is allowed."""
	var net: Vector2i = _gear(&"net")
	for cycle: int in range(49):
		_run_cycle(net, JOB_A)
	assert_equal(_durability(net), 20, "49 cycles of 20 leave exactly one cycle's wear")
	assert_true(_store.claim_for_job(net, JOB_A).ok, "exact wear starts")
	assert_equal(_store.complete_cycle(net, JOB_A).value, 20, "and debits its 20")
	assert_equal(_durability(net), 0, "leaving the net broken")
	var empty: InventoryScript.OpResult = _store.claim_for_job(net, JOB_A)
	assert_false(empty.ok, "a broken net cannot start a cycle")
	assert_equal(empty.error, GearScript.REFUSE_INSUFFICIENT_DURABILITY, "and says why")
	assert_true(_store.repair(net, 19).ok, "repaired to one below the wear")
	assert_equal(_durability(net), 19, "durability is 19")
	var short: InventoryScript.OpResult = _store.claim_for_job(net, JOB_A)
	assert_false(short.ok, "19 is below 20, so the cycle refuses")
	assert_equal(short.error, GearScript.REFUSE_INSUFFICIENT_DURABILITY, "with the same code")
	assert_true(_store.repair(net, 1).ok, "one more point")
	assert_true(_store.claim_for_job(net, JOB_A).ok, "and 20 starts again")


func test_repeated_completion_cannot_double_debit() -> void:
	"""Completion applies wear once; the claim it consumed is gone for the second attempt."""
	var trap: Vector2i = _gear(&"trap")
	assert_true(_store.claim_for_job(trap, JOB_A).ok, "the cycle claims the trap")
	assert_equal(_store.complete_cycle(trap, JOB_A).value, 10, "and completes for 10 wear")
	assert_equal(_durability(trap), 990, "durability drops exactly once")
	var again: InventoryScript.OpResult = _store.complete_cycle(trap, JOB_A)
	assert_false(again.ok, "a repeated completion finds no claim")
	assert_equal(again.error, GearScript.REFUSE_GEAR_NOT_CLAIMED, "and is named as such")
	assert_equal(_durability(trap), 990, "and debits nothing further")
	var third: InventoryScript.OpResult = _store.complete_cycle(trap, JOB_A)
	assert_false(third.ok, "however many times it is repeated")
	assert_equal(_durability(trap), 990, "durability is still 990")


func test_repeated_cancellation_cannot_double_release() -> void:
	"""Cancellation before completion releases the claim and applies nothing, exactly once."""
	var net: Vector2i = _gear(&"net")
	assert_true(_store.claim_for_job(net, JOB_A).ok, "the cycle claims the net")
	assert_true(_store.cancel_claim(net, JOB_A).ok, "and is cancelled")
	assert_equal(_durability(net), 1000, "cancellation applies no wear")
	assert_false(_store.is_claimed(net), "and leaves the gear free")
	var again: InventoryScript.OpResult = _store.cancel_claim(net, JOB_A)
	assert_false(again.ok, "a second cancellation finds no claim")
	assert_equal(again.error, GearScript.REFUSE_GEAR_NOT_CLAIMED, "and is named as such")
	assert_true(_store.claim_for_job(net, JOB_B).ok, "another Job may now take it")
	var stale_cancel: InventoryScript.OpResult = _store.cancel_claim(net, JOB_A)
	assert_false(stale_cancel.ok, "and the old holder cannot release the new claim")
	assert_equal(_store.claim_job_of(net), JOB_B, "which still stands")


func test_repair_and_ownership_change_refused_while_claimed() -> void:
	"""A claimed cycle's gear contract cannot be moved out from under it."""
	var directory: EntityDirectoryScript = EntityDirectoryScript.new()
	var resident: Vector2i = directory.create(EntityDirectoryScript.KIND_RESIDENT)
	var net: Vector2i = _gear(&"net")
	assert_equal(_run_cycle(net, JOB_A), 20, "one cycle wears it to 980")
	assert_true(_store.claim_for_job(net, JOB_B).ok, "and a new cycle claims it")
	var repaired: InventoryScript.OpResult = _store.repair(net, 200)
	assert_false(repaired.ok, "repair is refused while claimed")
	assert_equal(repaired.error, GearScript.REFUSE_GEAR_CLAIMED, "and named as such")
	assert_equal(_durability(net), 980, "durability is unchanged")
	var owned: InventoryScript.OpResult = _store.set_owner(directory, net, resident)
	assert_false(owned.ok, "an equipment swap is refused while claimed")
	assert_equal(owned.error, GearScript.REFUSE_GEAR_CLAIMED, "with the same code")
	assert_false(_store.clear_owner(net).ok, "and so is dropping the owner")


func test_outfit_tier2_keeps_identity_but_never_wears() -> void:
	"""Tier-2 outfits are instance-required for transfers, with canonical 0/0 and no degradation."""
	var outfit: Vector2i = _gear(&"outfit_tier2")
	assert_true(_store.has_gear(outfit), "a tier-2 outfit keeps its own identity")
	assert_equal(_durability(outfit), 0, "its canonical durability is 0")
	assert_true(_store.durability_cap_into(outfit, _out), "its cap is readable")
	assert_equal(_out.value, 0, "and is 0")
	var claimed: InventoryScript.OpResult = _store.claim_for_job(outfit, JOB_A)
	assert_false(claimed.ok, "there is no durability to reserve, so it is not claimable")
	assert_equal(claimed.error, GearScript.REFUSE_GEAR_NOT_CLAIMABLE, "and says so")
	var repaired: InventoryScript.OpResult = _store.repair(outfit, 200)
	assert_false(repaired.ok, "repair is inapplicable")
	assert_equal(repaired.error, GearScript.REFUSE_REPAIR_INAPPLICABLE, "and named inapplicable")
	assert_false(_store.repair_wood_milli_into(outfit, _out), "it has no repair recipe")
	assert_equal(_durability(outfit), 0, "and it never degrades")


# --- Wear models ------------------------------------------------------------------------------

func test_a_broken_general_tool_cannot_start_work() -> void:
	"""§5.7: "Broken tools block tool-required work" -- 0 durability IS the broken state.

	A general claim's bar is one point, not zero: the actual wear is not known until the task
	finishes, so the check at start is that the tool is not already broken.
	"""
	var tool: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "a whole tool claims fine")
	assert_true(_store.apply_general_wear_into(tool, JOB_A, 20000 * GearScript.MWU_PER_WU, 0,
		_wear), "then is worn to nothing")
	assert_equal(_durability(tool), 0, "the tool is broken")
	var blocked: InventoryScript.OpResult = _store.claim_for_job(tool, JOB_A)
	assert_false(blocked.ok, "a broken tool cannot be claimed for tool-required work")
	assert_equal(blocked.error, GearScript.REFUSE_INSUFFICIENT_DURABILITY, "and says why")
	assert_false(_store.is_claimed(tool), "and no claim was left behind")
	assert_true(_store.repair(tool, 1).ok, "one point of repair")
	var allowed: InventoryScript.OpResult = _store.claim_for_job(tool, JOB_A)
	assert_true(allowed.ok, "makes it usable again")
	assert_equal(allowed.value, 1, "against the one-point minimum a general claim requires")


func test_general_wear_is_one_point_per_ten_work_units() -> void:
	"""§5.7: 1 equipped tool durability per completed 10 WU."""
	var tool: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "the job claims the tool")
	assert_true(_store.apply_general_wear_into(tool, JOB_A, 30 * GearScript.MWU_PER_WU, 0, _wear),
		"30 WU of work applies")
	assert_equal(_wear.durability_spent, 3, "30 WU costs exactly 3 durability")
	assert_equal(_wear.remainder_after, 0, "with no remainder")
	assert_equal(_wear.durability_after, 997, "leaving 997")
	assert_false(_wear.broke, "and the tool is fine")
	assert_false(_store.is_claimed(tool), "the completion released the claim")


func test_general_wear_preserves_its_remainder_across_tasks() -> void:
	""""preserve remainder across tasks": two 5 WU tasks cost one point, not zero and not two."""
	var tool: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "first task claims")
	assert_true(_store.apply_general_wear_into(tool, JOB_A, 5 * GearScript.MWU_PER_WU, 0, _wear),
		"5 WU applies")
	assert_equal(_wear.durability_spent, 0, "5 WU alone costs nothing")
	assert_equal(_wear.remainder_after, 5000, "but leaves 5000 milli-WU carried")
	assert_equal(_durability(tool), 1000, "durability is untouched")
	assert_true(_store.claim_for_job(tool, JOB_B).ok, "the next task claims")
	assert_true(_store.apply_general_wear_into(tool, JOB_B, 5 * GearScript.MWU_PER_WU,
		_wear.remainder_after, _wear), "and carries the remainder in")
	assert_equal(_wear.durability_spent, 1, "the second 5 WU completes the tenth")
	assert_equal(_wear.remainder_after, 0, "and clears the remainder")
	assert_equal(_durability(tool), 999, "durability falls by exactly one")


func test_repeated_general_wear_cannot_double_debit() -> void:
	"""The claim is consumed by the application, so replaying it debits nothing."""
	var tool: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "claimed")
	assert_true(_store.apply_general_wear_into(tool, JOB_A, 100 * GearScript.MWU_PER_WU, 0, _wear),
		"100 WU applies")
	assert_equal(_durability(tool), 990, "10 points spent")
	assert_false(_store.apply_general_wear_into(tool, JOB_A, 100 * GearScript.MWU_PER_WU, 0, _wear),
		"a replay finds no claim")
	assert_equal(_wear.error, GearScript.REFUSE_GEAR_NOT_CLAIMED, "and is named as such")
	assert_equal(_wear.durability_spent, 0, "a refusal reports no spend")
	assert_equal(_durability(tool), 990, "and durability is unchanged")


func test_general_wear_floors_at_zero_and_reports_breaking() -> void:
	"""Demanding more than remains debits to exactly 0 and says so, rather than going negative."""
	var tool: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "claimed")
	assert_true(_store.apply_general_wear_into(tool, JOB_A, 20000 * GearScript.MWU_PER_WU, 0,
		_wear), "an enormous task applies")
	assert_equal(_wear.durability_spent, 1000, "it spends every remaining point")
	assert_true(_wear.broke, "and reports the shortfall as a break")
	assert_equal(_wear.durability_after, 0, "durability floors at 0")
	assert_equal(_durability(tool), 0, "never below it")
	assert_true(_store.audit().ok, "and the store still audits clean")


func test_the_two_wear_models_never_cross() -> void:
	"""A fishing cycle cannot be completed on a general tool, or vice versa."""
	var tool: Vector2i = _gear(&"tool")
	var net: Vector2i = _gear(&"net")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "the tool is claimed")
	var wrong_cycle: InventoryScript.OpResult = _store.complete_cycle(tool, JOB_A)
	assert_false(wrong_cycle.ok, "a general tool has no per-cycle wear to complete")
	assert_equal(wrong_cycle.error, GearScript.REFUSE_WRONG_WEAR_MODEL, "and says which model")
	assert_true(_store.claim_for_job(net, JOB_B).ok, "the net is claimed")
	assert_false(_store.apply_general_wear_into(net, JOB_B, 100 * GearScript.MWU_PER_WU, 0, _wear),
		"and fishing gear does not take the 10-WU remainder rule")
	assert_equal(_wear.error, GearScript.REFUSE_WRONG_WEAR_MODEL, "with the same code")
	assert_equal(_durability(net), 1000, "neither piece of gear moved")
	assert_equal(_durability(tool), 1000, "at all")


func test_general_wear_rejects_an_out_of_range_remainder() -> void:
	"""A remainder is a sub-point fraction; anything at or past a whole point is a caller bug."""
	var tool: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "claimed")
	assert_false(_store.apply_general_wear_into(tool, JOB_A, 0,
		GearScript.GENERAL_WEAR_MWU_PER_POINT, _wear), "a whole point of remainder is refused")
	assert_equal(_wear.error, GearScript.REFUSE_INVALID_REMAINDER, "and named")
	assert_false(_store.apply_general_wear_into(tool, JOB_A, -1, 0, _wear),
		"and so is negative work")
	assert_equal(_wear.error, GearScript.REFUSE_INVALID_WORK, "with its own code")
	assert_true(_store.is_claimed(tool), "a refusal leaves the claim standing")


# --- Repair -----------------------------------------------------------------------------------

func test_repair_clamps_to_the_basic_general_cap() -> void:
	"""§5.7: 200 points per repair, up to the basic tool's 1000 cap -- and no further."""
	var tool: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "claimed")
	assert_true(_store.apply_general_wear_into(tool, JOB_A, 1000 * GearScript.MWU_PER_WU, 0,
		_wear), "100 points of wear apply")
	assert_equal(_durability(tool), 900, "leaving 900")
	var repaired: InventoryScript.OpResult = _store.repair(tool,
		GearScript.REPAIR_DURABILITY_PER_JOB)
	assert_true(repaired.ok, "the repair succeeds")
	assert_equal(repaired.value, 1000, "and clamps at the 1000 cap, not 1100")
	assert_equal(_durability(tool), 1000, "the stored durability agrees")


func test_repair_clamps_to_the_iron_general_cap() -> void:
	"""An iron tool's cap is 1500, so the same repair clamps 100 points higher."""
	var tool: Vector2i = _gear(&"tool", GearScript.MANUFACTURE_IRON)
	assert_equal(_durability(tool), 1500, "an iron tool starts at 1500")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "claimed")
	assert_true(_store.apply_general_wear_into(tool, JOB_A, 1000 * GearScript.MWU_PER_WU, 0,
		_wear), "100 points of wear apply")
	assert_equal(_durability(tool), 1400, "leaving 1400")
	assert_equal(_store.repair(tool, GearScript.REPAIR_DURABILITY_PER_JOB).value, 1500,
		"and the repair clamps at 1500, not 1000 and not 1600")


func test_repair_clamps_to_the_fishing_cap() -> void:
	"""§5.4 fishing gear caps at 1000 whatever its manufacture."""
	var net: Vector2i = _gear(&"net")
	for cycle: int in range(5):
		_run_cycle(net, JOB_A)
	assert_equal(_durability(net), 900, "five cycles of 20 leave 900")
	assert_equal(_store.repair(net, GearScript.REPAIR_DURABILITY_PER_JOB).value, 1000,
		"and 200 points of repair clamp at the fishing cap of 1000")


func test_repair_is_not_a_durability_reset() -> void:
	"""A badly worn tool repaired by 200 ends at 240, not back at its cap."""
	var tool: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(tool, JOB_A).ok, "claimed")
	assert_true(_store.apply_general_wear_into(tool, JOB_A, 9600 * GearScript.MWU_PER_WU, 0,
		_wear), "960 points of wear apply")
	assert_equal(_durability(tool), 40, "leaving 40")
	assert_equal(_store.repair(tool, GearScript.REPAIR_DURABILITY_PER_JOB).value, 240,
		"one repair restores 200 points and stops there")
	assert_equal(_store.repair(tool, GearScript.REPAIR_DURABILITY_PER_JOB).value, 440,
		"a second restores another 200")
	assert_false(_store.repair(tool, 0).ok, "and a zero-point repair is refused, not ignored")


func test_the_two_repair_recipes_stay_distinct() -> void:
	"""General tools take wood 1 + stone 0.5; fishing gear takes wood 1 + rope 0.25."""
	var tool: Vector2i = _gear(&"tool")
	var net: Vector2i = _gear(&"net")
	assert_true(_store.repair_wood_milli_into(tool, _out), "the tool recipe has a wood cost")
	assert_equal(_out.value, 1000, "of one unit")
	assert_true(_store.repair_secondary_item_into(_defs, tool, _out), "and a second material")
	assert_equal(_out.value, _id(&"stone"), "which is stone")
	assert_true(_store.repair_secondary_milli_into(tool, _out), "in a stated quantity")
	assert_equal(_out.value, 500, "of half a unit")
	assert_true(_store.repair_wood_milli_into(net, _out), "the net recipe has a wood cost")
	assert_equal(_out.value, 1000, "also one unit")
	assert_true(_store.repair_secondary_item_into(_defs, net, _out), "and a second material")
	assert_equal(_out.value, _id(&"rope"), "which is rope, not stone")
	assert_true(_store.repair_secondary_milli_into(net, _out), "in a stated quantity")
	assert_equal(_out.value, 250, "of a quarter unit, not a half")
	assert_equal(GearScript.REPAIR_WORK_MWU, 30000, "both recipes cost 30 WU")


# --- Destruction, restore, image ---------------------------------------------------------------

func test_destroy_refuses_while_the_lot_is_still_live() -> void:
	"""Gear records die with their lot; they cannot be stripped off gear somebody still holds."""
	var tool: Vector2i = _gear(&"tool")
	var early: InventoryScript.OpResult = _store.destroy_gear(_inv, _defs, tool)
	assert_false(early.ok, "the record cannot outlive-proof itself while the lot lives")
	assert_equal(early.error, GearScript.REFUSE_LOT_STILL_LIVE, "and says why")
	assert_true(_store.has_gear(tool), "so the record stands")
	_retire_lot(tool)
	assert_true(_store.destroy_gear(_inv, _defs, tool).ok, "once the lot retires it may go")
	assert_false(_store.has_gear(tool), "and it is gone")
	assert_equal(_store.free_row_count(), SMALL_POOL, "its row is back in the heap")


func test_destroy_refuses_while_claimed() -> void:
	"""Releasing a Job's claim is that Job's business, not the destroyer's."""
	var net: Vector2i = _gear(&"net")
	assert_true(_store.claim_for_job(net, JOB_A).ok, "claimed")
	_retire_lot(net)
	var blocked: InventoryScript.OpResult = _store.destroy_gear(_inv, _defs, net)
	assert_false(blocked.ok, "a claimed record cannot be destroyed out from under its Job")
	assert_equal(blocked.error, GearScript.REFUSE_GEAR_CLAIMED, "and says so")
	assert_true(_store.cancel_claim(net, JOB_A).ok, "the Job releases it")
	assert_true(_store.destroy_gear(_inv, _defs, net).ok, "and now it may go")


func test_restore_rebuilds_the_free_heap_ascending() -> void:
	"""Occupancy and fields are saved; the heap is derived, ascending, on load."""
	assert_true(_store.begin_restore(_defs).ok, "the restore window opens")
	assert_true(_store.is_restoring(), "and is open")
	var blocked: InventoryScript.OpResult = _store.preflight_create(_defs, _id(&"tool"),
		GearScript.MANUFACTURE_BASIC)
	assert_false(blocked.ok, "creation is refused while the heap is not derived")
	assert_equal(blocked.error, GearScript.REFUSE_RESTORE_OPEN, "and named")
	assert_true(_store.restore_row(5, Vector2i(11, 3), _id(&"net"), 640, 1000,
		GearScript.NULL_REF, GearScript.MANUFACTURE_BASIC, GearScript.NULL_REF).ok,
		"a worn net is restored at row 5")
	assert_true(_store.restore_row(2, Vector2i(4, 1), _id(&"tool"), 1500, 1500,
		GearScript.NULL_REF, GearScript.MANUFACTURE_IRON, GearScript.NULL_REF).ok,
		"an iron tool is restored at row 2")
	assert_equal(_store.finish_restore().value, SMALL_POOL - 2, "two rows are taken")
	var heap: PackedInt32Array = _store.get("_free_heap")
	assert_equal(heap[0], 0, "the heap begins at the lowest free row")
	assert_equal(heap[1], 1, "then 1")
	assert_equal(heap[2], 3, "skipping the restored row 2")
	assert_equal(_durability(Vector2i(11, 3)), 640, "the restored wear survived")
	assert_true(_store.audit().ok, "and the restored store audits clean")


func test_restore_refuses_an_impossible_row() -> void:
	"""A save that fails validation is a load failure, never a silent repair."""
	assert_false(_store.restore_row(0, Vector2i(1, 1), 0, 10, 10, GearScript.NULL_REF,
		GearScript.MANUFACTURE_BASIC, GearScript.NULL_REF).ok, "no restore outside the window")
	assert_true(_store.begin_restore(_defs).ok, "the window opens")
	var over_cap: InventoryScript.OpResult = _store.restore_row(0, Vector2i(1, 1), _id(&"net"),
		1200, 1000, GearScript.NULL_REF, GearScript.MANUFACTURE_BASIC, GearScript.NULL_REF)
	assert_false(over_cap.ok, "durability above the cap is refused")
	assert_equal(over_cap.error, GearScript.REFUSE_INVALID_DURABILITY, "and named")
	assert_true(_store.restore_row(0, Vector2i(1, 1), _id(&"net"), 1000, 1000,
		GearScript.NULL_REF, GearScript.MANUFACTURE_BASIC, GearScript.NULL_REF).ok, "a legal row")
	var duplicate: InventoryScript.OpResult = _store.restore_row(1, Vector2i(1, 2), _id(&"net"),
		500, 1000, GearScript.NULL_REF, GearScript.MANUFACTURE_BASIC, GearScript.NULL_REF)
	assert_false(duplicate.ok, "two records cannot share a lot slot")
	assert_equal(duplicate.error, GearScript.REFUSE_GEAR_ALREADY_EXISTS, "and named")
	assert_true(_store.finish_restore().ok, "the window closes")


func test_a_row_is_never_published_without_its_identity() -> void:
	"""Publication is guarded, not merely ordered: an uninitialised row is refused, not shown."""
	assert_true(_store.begin_restore(_defs).ok, "the restore window opens")
	var broken: InventoryScript.OpResult = _store.restore_row(0, Vector2i(1, 1), -1, 0, 0,
		GearScript.NULL_REF, GearScript.MANUFACTURE_BASIC, GearScript.NULL_REF)
	assert_false(broken.ok, "a row with no item identity is never published")
	assert_equal(broken.error, GearScript.REFUSE_ROW_NOT_INITIALISED, "and is named explicitly")
	assert_equal(_store.active_gear_count(), 0, "so the live count never counted it")
	assert_true(_store.finish_restore().ok, "the window closes")
	assert_equal(_store.free_row_count(), SMALL_POOL, "and every row is free again")
	assert_true(_store.audit().ok, "with a clean audit")


func test_state_image_is_row_history_independent() -> void:
	"""Two stores holding the same gear compare equal whichever rows they used."""
	var first_lot: Vector2i = _gear(&"tool")
	var second_lot: Vector2i = _gear(&"net")
	var reference: PackedByteArray = _store.state_bytes()
	var other: GearScript = GearScript.new(SMALL_POOL)
	assert_true(other.begin_restore(_defs).ok, "build the same gear at different rows")
	assert_true(other.restore_row(40, second_lot, _id(&"net"), 1000, 1000, GearScript.NULL_REF,
		GearScript.MANUFACTURE_BASIC, GearScript.NULL_REF).ok, "net at row 40")
	assert_true(other.restore_row(7, first_lot, _id(&"tool"), 1000, 1000, GearScript.NULL_REF,
		GearScript.MANUFACTURE_BASIC, GearScript.NULL_REF).ok, "tool at row 7")
	assert_true(other.finish_restore().ok, "and close the window")
	assert_equal(other.state_bytes(), reference, "the canonical images match")
	assert_true(_store.claim_for_job(second_lot, JOB_A).ok, "a claim is runtime state")
	assert_equal(_store.state_bytes(), reference, "so it does not move the image")


func test_a_created_gear_row_is_not_equipped_and_keeps_its_container() -> void:
	"""Creation never equips. DECISION 0061 REPLACED THIS TEST'''S ORIGINAL CLAIM.

	It used to assert that `equip`/`unequip` did not exist at all, which was true while ADR 0038
	deliberately deferred the inventory amendment. That amendment has now landed, so the entry
	points exist and the two `has_method` assertions were removed as obsolete. What the test
	still pins is the part that did NOT change: `create_gear()` publishes an unequipped row whose
	lot stays in a real container, so no null-container lot appears without an explicit equip.
	"""
	var tool: Vector2i = _gear(&"tool")
	assert_false(_store.is_equipped(tool), "a freshly created gear row is not equipped")
	assert_false(_store.is_equipped_record(tool), "and it attests nothing to the inventory")
	assert_equal(_inv.lot_container(tool), _container,
		"the lot keeps a real container: creation makes no null-container lot")
	assert_equal(_store.equipped_count(), 0, "and the equipped-row count stays at zero")
# --- Equipped gear (decision 0061; ruling §4; READY_07 §7.2 step 5) ---------------------------
#
# ADR 0038 listed "equip/unequip preserves identity, age/provenance, quantity and durability" as
# an acceptance item it could not complete, because the inventory amendment was deferred. These
# are that item, plus the defect the ruling names in the same paragraph: a lot must never be
# counted once as equipped and again in storage.


class RefusingDetachInventory extends InventoryScript:
	"""An inventory whose detach always refuses, while its preflight still passes.

	The only way to reach `_apply_equip()`'s rollback: every honest refusal happens during the
	check, so without this the undo path would be unreachable code claiming to be tested.
	"""
	func detach_lot_to_equipment(_lot_ref: Vector2i) -> InventoryScript.OpResult:
		"""Always refuse, after the preflight has already said yes."""
		return InventoryScript.OpResult.new(false, &"FORCED_DETACH_REFUSAL", Vector2i(-1, 0), 0)


class RefusingAttachInventory extends InventoryScript:
	"""An inventory whose attach always refuses, while its preflight still passes."""
	func attach_equipped_lot(_lot_ref: Vector2i, _dest_ref: Vector2i,
			_from_reserved: bool) -> InventoryScript.OpResult:
		"""Always refuse, after the preflight has already said yes."""
		return InventoryScript.OpResult.new(false, &"FORCED_ATTACH_REFUSAL", Vector2i(-1, 0), 0)


func _bind_residents() -> void:
	"""Attach a residents store, its directory and this inventory to the gear store."""
	_residents = ResidentsScript.new()
	var bound: InventoryScript.OpResult = _store.bind_equipment(_inv, _residents.directory(),
		_residents)
	assert_true(bound.ok, "binding the equip collaborators must succeed: %s" % bound.error)


func _resident() -> Vector2i:
	"""Spawn one mouse and return its directory reference."""
	var spawned: ResidentsScript.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "spawning a resident must succeed: %s" % spawned.error)
	return spawned.ref


func _mirror_durability(owner_ref: Vector2i) -> int:
	"""The Equipment mirror's tool durability for a resident, asserting the read succeeded."""
	var slot: int = _residents.directory().get_typed_row(owner_ref)
	assert_true(_residents.equipped_tool_durability_into(slot, _out),
		"the mirror must carry a durability for an equipped resident")
	return _out.value


func test_equip_preserves_identity_age_provenance_quantity_and_durability() -> void:
	"""ADR 0038's deferred acceptance item, now completable. Nothing is cloned or re-rolled."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var lot_ref: Vector2i = _inv.create_lot(_container, _id(&"tool"), 1000, 4,
		TEST_PROVENANCE, 6, 24000, 500).ref
	assert_true(_store.create_gear(_inv, _defs, lot_ref, GearScript.MANUFACTURE_BASIC).ok, "made")
	var lots_before: int = _inv.live_lot_count()
	var equipped: InventoryScript.OpResult = _store.equip(lot_ref, owner)
	assert_true(equipped.ok, "equipping a stored tool must succeed: %s" % equipped.error)
	assert_equal(equipped.ref, lot_ref, "the SAME lot reference comes back")
	assert_equal(_inv.live_lot_count(), lots_before, "no second lot was created")
	assert_equal(_inv.lot_quantity_milli(lot_ref), 1000, "quantity is untouched")
	assert_equal(_inv.lot_quality(lot_ref), 4, "quality is untouched")
	assert_equal(_inv.lot_provenance(lot_ref), TEST_PROVENANCE, "provenance is untouched")
	assert_equal(_inv.lot_recipe_id(lot_ref), 6, "recipe id is untouched")
	assert_equal(_inv.lot_age_milli_hours(lot_ref), 24000, "age is not reset")
	assert_equal(_inv.lot_age_remainder(lot_ref), 500, "nor its remainder")
	assert_equal(_durability(lot_ref), GearScript.CAP_GENERAL_BASIC, "durability is untouched")


func test_an_equipped_lot_has_a_null_container_and_charges_no_mass() -> void:
	"""The ruling's exclusion, on the real stores rather than a stub authority."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var lot_ref: Vector2i = _gear(&"tool")
	assert_equal(_inv.container_used_mass_g(_container), TOOL_MASS_G, "stored, it charges mass")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	assert_equal(_inv.lot_container(lot_ref), InventoryScript.NULL_REF, "container is null")
	assert_equal(_inv.container_used_mass_g(_container), 0, "and it charges no container mass")
	assert_equal(_inv.container_lot_count(_container), 0, "it is in no container list")
	assert_equal(_inv.total_loose_milli(_id(&"tool")), 0, "it is not loose stock")
	assert_equal(_inv.total_equipped_milli(_id(&"tool")), 1000, "it is equipment")
	assert_equal(_inv.total_live_milli(_id(&"tool")), 1000, "counted exactly once in the live sum")
	assert_true(_inv.audit().ok, "and the inventory audits clean with the gear store attesting")


func test_unequip_returns_the_same_lot_without_resetting_durability() -> void:
	"""Worn gear comes home worn. A repair is the only thing that raises durability."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var lot_ref: Vector2i = _gear(&"tool")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	assert_true(_store.claim_for_job(lot_ref, JOB_A).ok, "claim for work")
	assert_true(_store.apply_general_wear_into(lot_ref, JOB_A, 200000, 0, _wear), "wear 20")
	assert_equal(_durability(lot_ref), 980, "20 points of durability were spent")
	var freed: InventoryScript.OpResult = _store.unequip(lot_ref, _container, false)
	assert_true(freed.ok, "unequipping into a valid container must succeed: %s" % freed.error)
	assert_equal(freed.ref, lot_ref, "the SAME lot reference comes back")
	assert_equal(_durability(lot_ref), 980, "durability was NOT reset by the unequip")
	assert_equal(_inv.lot_container(lot_ref), _container, "and the lot is shelved again")
	assert_equal(_inv.container_used_mass_g(_container), TOOL_MASS_G, "charging its mass again")
	assert_equal(_inv.total_equipped_milli(_id(&"tool")), 0, "and counting as equipment no more")


func test_equip_and_unequip_move_the_equipment_mirror_together() -> void:
	"""Ruling §4: equip/unequip atomically change ownership AND the Equipment mirrors."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var slot: int = _residents.directory().get_typed_row(owner)
	var lot_ref: Vector2i = _gear(&"tool")
	assert_false(_residents.has_equipped_tool(slot), "the resident starts with no tool")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	assert_true(_residents.has_equipped_tool(slot), "the mirror now names a tool")
	assert_true(_residents.equipped_tool_item_id_into(slot, _out), "and its item id reads")
	assert_equal(_out.value, _id(&"tool"), "which is the catalog tool id")
	assert_equal(_mirror_durability(owner), GearScript.CAP_GENERAL_BASIC, "at full durability")
	assert_equal(_store.owner_of(lot_ref), owner, "and the gear row records the owner")
	assert_true(_store.unequip(lot_ref, _container, false).ok, "unequip")
	assert_false(_residents.has_equipped_tool(slot), "the mirror is emptied again")
	assert_equal(_store.owner_of(lot_ref), GearScript.NULL_REF, "and the ownership is released")


func test_wear_and_repair_write_through_to_the_equipment_mirror() -> void:
	"""A mirror that can silently disagree is the double count wearing a different hat."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var lot_ref: Vector2i = _gear(&"tool")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	assert_true(_store.claim_for_job(lot_ref, JOB_A).ok, "claim")
	assert_true(_store.apply_general_wear_into(lot_ref, JOB_A, 1000000, 0, _wear), "wear 100")
	assert_equal(_durability(lot_ref), 900, "the instance is the authority")
	assert_equal(_mirror_durability(owner), 900, "and the mirror followed it exactly")
	assert_true(_store.repair(lot_ref, 200).ok, "repair 200, clamped at the 1000 cap")
	assert_equal(_durability(lot_ref), 1000, "the instance clamps at its cap")
	assert_equal(_mirror_durability(owner), 1000, "and the mirror followed that too")
	assert_true(_store.audit_equipment_mirror().ok, "so the mirror audit is clean")


func test_the_mirror_audit_catches_a_hand_written_mirror() -> void:
	"""Writing the mirror from anywhere but gear.gd produces a state the audit rejects."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var slot: int = _residents.directory().get_typed_row(owner)
	var lot_ref: Vector2i = _gear(&"tool")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	assert_true(_store.audit_equipment_mirror().ok, "the honest mirror audits clean")
	assert_true(_residents.set_equipped_tool_durability(slot, 17).ok, "hand-write a durability")
	var audited: InventoryScript.OpResult = _store.audit_equipment_mirror()
	assert_false(audited.ok, "a mirror that disagrees with the instance is refused")
	assert_equal(audited.error, GearScript.REFUSE_AUDIT_MIRROR, "named explicitly")


func test_the_mirror_audit_catches_a_mirror_with_no_equipped_instance() -> void:
	"""The other direction: a resident claiming a tool that no gear row backs."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var slot: int = _residents.directory().get_typed_row(owner)
	assert_true(_residents.set_equipped_tool(slot, _id(&"tool"), 1000).ok, "invent a mirror")
	var audited: InventoryScript.OpResult = _store.audit_equipment_mirror()
	assert_false(audited.ok, "an unbacked mirror entry is refused")
	assert_equal(audited.error, GearScript.REFUSE_AUDIT_MIRROR, "named explicitly")


func test_a_refused_equip_leaves_every_store_byte_identical() -> void:
	"""Allocate before consume: each refusal below happens before the first write, every time."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var second: Vector2i = _resident()
	var net_lot: Vector2i = _gear(&"net")
	var tool_lot: Vector2i = _gear(&"tool")
	assert_true(_store.equip(tool_lot, owner).ok, "one honest equip first")
	var spare: Vector2i = _gear(&"tool")
	var inventory_before: PackedByteArray = _inv.state_bytes()
	var gear_before: PackedByteArray = _store.state_bytes()
	var mirror_before: PackedByteArray = _residents.equipment_state_bytes()
	assert_equal(_store.equip(net_lot, second).error, GearScript.REFUSE_EQUIP_KIND_UNSUPPORTED,
		"a net has no Equipment mirror field, so equipping one refuses")
	assert_equal(_store.equip(spare, owner).error, GearScript.REFUSE_OWNER_ALREADY_EQUIPPED,
		"a resident carries one tool, not two")
	assert_equal(_store.equip(tool_lot, second).error, GearScript.REFUSE_GEAR_EQUIPPED,
		"already equipped gear cannot be equipped again")
	assert_equal(_store.equip(spare, CONTAINER_OWNER).error, GearScript.REFUSE_INVALID_OWNER,
		"a reference that is not in the directory is not an owner")
	assert_equal(_inv.state_bytes(), inventory_before, "the inventory is byte-identical")
	assert_equal(_store.state_bytes(), gear_before, "the gear store is byte-identical")
	assert_equal(_residents.equipment_state_bytes(), mirror_before, "the mirror is byte-identical")


func test_an_equip_that_fails_after_the_mirror_write_rolls_all_three_back() -> void:
	"""The undo path inside `_apply_equip()`, driven by a detach that refuses after preflight."""
	_inv = RefusingDetachInventory.new(8, 256)
	var loaded: ItemDefinitionsScript.LoadResult = _defs.load_default(_inv)
	assert_true(loaded.ok, "the catalog reloads into the substitute inventory: %s" % loaded.error)
	_container = _inv.create_container(CONTAINER_OWNER, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true).ref
	_bind_residents()
	var owner: Vector2i = _resident()
	var slot: int = _residents.directory().get_typed_row(owner)
	var lot_ref: Vector2i = _gear(&"tool")
	var inventory_before: PackedByteArray = _inv.state_bytes()
	var gear_before: PackedByteArray = _store.state_bytes()
	var mirror_before: PackedByteArray = _residents.equipment_state_bytes()
	var equipped: InventoryScript.OpResult = _store.equip(lot_ref, owner)
	assert_false(equipped.ok, "the forced detach refusal fails the equip")
	assert_equal(equipped.error, &"FORCED_DETACH_REFUSAL", "carrying the inventory's own reason")
	assert_false(_residents.has_equipped_tool(slot), "the mirror write was undone")
	assert_false(_store.is_equipped(lot_ref), "the equipped byte was undone")
	assert_equal(_store.equipped_count(), 0, "and so was the equipped-row count")
	assert_equal(_inv.state_bytes(), inventory_before, "the inventory is byte-identical")
	assert_equal(_store.state_bytes(), gear_before, "the gear store is byte-identical")
	assert_equal(_residents.equipment_state_bytes(), mirror_before, "the mirror is byte-identical")


func test_an_unequip_that_fails_to_shelve_restores_the_equipped_relation() -> void:
	"""The undo path inside `_apply_unequip()`, driven by an attach that refuses after preflight."""
	_inv = RefusingAttachInventory.new(8, 256)
	var loaded: ItemDefinitionsScript.LoadResult = _defs.load_default(_inv)
	assert_true(loaded.ok, "the catalog reloads into the substitute inventory: %s" % loaded.error)
	_container = _inv.create_container(CONTAINER_OWNER, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true).ref
	_bind_residents()
	var owner: Vector2i = _resident()
	var lot_ref: Vector2i = _gear(&"tool")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	var gear_before: PackedByteArray = _store.state_bytes()
	var freed: InventoryScript.OpResult = _store.unequip(lot_ref, _container, false)
	assert_false(freed.ok, "the forced attach refusal fails the unequip")
	assert_equal(freed.error, &"FORCED_ATTACH_REFUSAL", "carrying the inventory's own reason")
	assert_true(_store.is_equipped(lot_ref), "the gear is equipped again")
	assert_equal(_store.owner_of(lot_ref), owner, "by the same owner")
	assert_equal(_store.equipped_count(), 1, "and the equipped-row count is back")
	assert_equal(_store.state_bytes(), gear_before, "the gear store is byte-identical")


func test_equip_and_unequip_refuse_while_a_job_holds_the_claim() -> void:
	"""Ruling §4 refuses equipment swaps while claimed, whichever direction they go."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var lot_ref: Vector2i = _gear(&"tool")
	assert_true(_store.claim_for_job(lot_ref, JOB_A).ok, "a job claims the tool")
	assert_equal(_store.equip(lot_ref, owner).error, GearScript.REFUSE_GEAR_CLAIMED,
		"so it cannot be equipped out from under that job")
	assert_true(_store.cancel_claim(lot_ref, JOB_A).ok, "release the claim")
	assert_true(_store.equip(lot_ref, owner).ok, "and now it equips")
	assert_true(_store.claim_for_job(lot_ref, JOB_A).ok, "the equipped tool is claimed for work")
	assert_equal(_store.unequip(lot_ref, _container, false).error, GearScript.REFUSE_GEAR_CLAIMED,
		"and cannot be taken off mid-cycle")


func test_set_owner_clear_owner_and_destroy_refuse_while_equipped() -> void:
	"""The ownership relation an equipped lot's null container is validated against is frozen."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var other: Vector2i = _resident()
	var lot_ref: Vector2i = _gear(&"tool")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	assert_equal(_store.set_owner(_residents.directory(), lot_ref, other).error,
		GearScript.REFUSE_GEAR_EQUIPPED, "the owner may not be re-pointed while equipped")
	assert_equal(_store.clear_owner(lot_ref).error, GearScript.REFUSE_GEAR_EQUIPPED,
		"nor cleared")
	assert_equal(_store.destroy_gear(_inv, _defs, lot_ref).error,
		GearScript.REFUSE_LOT_STILL_LIVE, "and the record cannot be destroyed under a live lot")
	assert_equal(_store.owner_of(lot_ref), owner, "the owner is exactly who it was")


func test_a_dead_owner_stops_attesting_and_the_inventory_audit_reports_the_orphan() -> void:
	"""The proof is re-derived every time it is asked for, so it cannot go stale unnoticed.

	This state is reachable today because no death handler unequips gear yet -- that integration
	is a named dependency of decision 0061, not something this store may invent. What the test
	pins is that the state is LOUD: the attestation fails and the audit refuses, rather than a
	null-container lot quietly surviving its owner.
	"""
	_bind_residents()
	var owner: Vector2i = _resident()
	var lot_ref: Vector2i = _gear(&"tool")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	assert_true(_store.is_equipped_record(lot_ref), "a live owner attests")
	assert_true(_inv.audit().ok, "and the inventory audits clean")
	assert_true(_residents.despawn(owner).ok, "the owner dies")
	assert_false(_store.is_equipped_record(lot_ref), "the proof is withdrawn at once")
	var audited: InventoryScript.OpResult = _inv.audit()
	assert_false(audited.ok, "so the null-container lot is now an orphan")
	assert_equal(audited.error, InventoryScript.REFUSE_AUDIT_ORPHAN_LOT, "named explicitly")
	assert_true(_store.unequip(lot_ref, _container, false).ok, "and unequipping is the way out")
	assert_true(_inv.audit().ok, "which restores a clean audit")


func test_only_the_general_tool_may_be_equipped() -> void:
	"""§4.2's Equipment row has one tool field and no field for carried gear. The rest refuse."""
	_bind_residents()
	var owner: Vector2i = _resident()
	for key: StringName in [&"net", &"trap", &"ice_kit", &"outfit_tier2"]:
		var lot_ref: Vector2i = _gear(key)
		assert_equal(_store.equip(lot_ref, owner).error,
			GearScript.REFUSE_EQUIP_KIND_UNSUPPORTED,
			"%s has no Equipment mirror field, so equipping it refuses" % key)
		assert_equal(_inv.lot_container(lot_ref), _container, "and its lot keeps its container")
	assert_equal(_store.equipped_count(), 0, "nothing was equipped")


func test_equipping_refuses_an_owner_who_is_not_a_live_resident() -> void:
	"""A null container is only ever permitted for a LIVE owner."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var lot_ref: Vector2i = _gear(&"tool")
	assert_true(_residents.despawn(owner).ok, "the resident leaves before the equip")
	var equipped: InventoryScript.OpResult = _store.equip(lot_ref, owner)
	assert_false(equipped.ok, "a stale owner reference cannot hold equipment")
	assert_equal(equipped.error, GearScript.REFUSE_INVALID_OWNER, "named explicitly")
	assert_equal(_inv.lot_container(lot_ref), _container, "and the lot never left its container")


func test_equip_refuses_without_its_bindings() -> void:
	"""With no residents store and no directory there is no mirror and no proof to be had."""
	var lot_ref: Vector2i = _gear(&"tool")
	var equipped: InventoryScript.OpResult = _store.equip(lot_ref, Vector2i(1, 1))
	assert_false(equipped.ok, "an unbound gear store cannot equip anything")
	assert_equal(equipped.error, GearScript.REFUSE_NOT_BOUND, "named explicitly")
	assert_false(_store.is_equipped_record(lot_ref), "and it attests for nothing")


func test_unequip_lands_in_a_reserved_destination() -> void:
	"""Ruling §4's "valid reserved destination", end to end through the gear store."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var small: Vector2i = _inv.create_container(CONTAINER_OWNER, TOOL_MASS_G,
		InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true).ref
	var lot_ref: Vector2i = _lot(&"tool")
	assert_true(_store.create_gear(_inv, _defs, lot_ref, GearScript.MANUFACTURE_BASIC).ok, "made")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	assert_true(_inv.reserve_container_mass(small, TOOL_MASS_G).ok, "reserve the shelf space")
	assert_equal(_inv.container_free_mass_g(small), 0, "which leaves no free mass at all")
	assert_false(_store.unequip(lot_ref, small, false).ok, "an unreserved unequip cannot fit")
	var freed: InventoryScript.OpResult = _store.unequip(lot_ref, small, true)
	assert_true(freed.ok, "but the reserved one lands exactly: %s" % freed.error)
	assert_equal(_inv.container_used_mass_g(small), TOOL_MASS_G, "as used mass")
	assert_equal(_inv.container_reserved_mass_g(small), 0, "spending the reservation once")


func test_rebinding_the_equip_collaborators_refuses_while_gear_is_equipped() -> void:
	"""The bindings are what the proof is answered from; they may not move underneath it."""
	_bind_residents()
	var owner: Vector2i = _resident()
	var lot_ref: Vector2i = _gear(&"tool")
	assert_true(_store.equip(lot_ref, owner).ok, "equip")
	var rebound: InventoryScript.OpResult = _store.bind_equipment(_inv,
		_residents.directory(), ResidentsScript.new())
	assert_false(rebound.ok, "rebinding under a live equipped record refuses")
	assert_equal(rebound.error, GearScript.REFUSE_GEAR_EQUIPPED, "named explicitly")
	assert_true(_store.is_equipped_record(lot_ref), "and the proof still answers the same way")


# --- GDD §5.9 starter tool seeding -------------------------------------------------------------

func _twelve_owners() -> Array[Vector2i]:
	"""Spawn the twelve residents §5.9's "one per resident" allots a tool to."""
	var owners: Array[Vector2i] = []
	for index: int in range(GearScript.STARTER_TOOL_EQUIPPED):
		owners.append(_resident())
	return owners


func test_the_starter_allotment_constants_are_the_gdd_numbers() -> void:
	"""§5.9: 24 initial tool units, 12 equipped, 12 stored, initial tool durability 1000."""
	assert_equal(GearScript.STARTER_TOOL_TOTAL, 24, "24 initial tool units")
	assert_equal(GearScript.STARTER_TOOL_EQUIPPED, 12, "12 of them equipped, one per resident")
	assert_equal(GearScript.STARTER_TOOL_STORED, 12, "and 12 stored")
	assert_equal(GearScript.STARTER_TOOL_EQUIPPED + GearScript.STARTER_TOOL_STORED,
		GearScript.STARTER_TOOL_TOTAL, "they are not duplicated: the two halves are the total")
	assert_equal(GearScript.STARTER_TOOL_DURABILITY, 1000, "at durability 1000")


func test_seeding_creates_24_tools_with_12_equipped_and_12_stored() -> void:
	"""The seeding contract, counted from the stores rather than from its own return value."""
	_bind_residents()
	var owners: Array[Vector2i] = _twelve_owners()
	var seeded: InventoryScript.OpResult = _store.seed_starter_tools(_defs, _container, owners,
		0, TEST_PROVENANCE)
	assert_true(seeded.ok, "seeding the starter tools must succeed: %s" % seeded.error)
	assert_equal(seeded.value, 24, "24 tools were made")
	assert_equal(_store.active_gear_count(), 24, "24 gear instances exist")
	assert_equal(_store.equipped_count(), 12, "twelve of them are equipped")
	assert_equal(_inv.container_lot_count(_container), 12, "and twelve lots are in the container")
	assert_equal(_inv.total_live_milli(_id(&"tool")), 24000, "24 tool units exist in total")
	assert_equal(_inv.total_equipped_milli(_id(&"tool")), 12000, "twelve units are equipment")
	assert_equal(_inv.total_loose_milli(_id(&"tool")), 12000, "twelve units are loose stock")
	assert_equal(_inv.container_used_mass_g(_container), 12 * TOOL_MASS_G,
		"and only the stored twelve charge container mass")


func test_every_seeded_tool_starts_at_durability_1000() -> void:
	"""§5.9: "Initial tool durability 1000" -- equipped and stored alike."""
	_bind_residents()
	var owners: Array[Vector2i] = _twelve_owners()
	assert_true(_store.seed_starter_tools(_defs, _container, owners, 0, TEST_PROVENANCE).ok,
		"seeding must succeed")
	for owner: Vector2i in owners:
		assert_equal(_mirror_durability(owner), 1000, "each equipped tool is at 1000")
	var lot_ref: Vector2i = _inv.container_first_lot(_container)
	var counted: int = 0
	while lot_ref != InventoryScript.NULL_REF:
		assert_equal(_durability(lot_ref), 1000, "each stored tool is at 1000 too")
		counted += 1
		lot_ref = _inv.container_next_lot(lot_ref)
	assert_equal(counted, 12, "and exactly twelve tools were walked in the container")
	assert_true(_store.audit_equipment_mirror().ok, "with every mirror agreeing")
	assert_true(_inv.audit().ok, "and the inventory conserved and unorphaned")


func test_starter_seeding_mints_no_outfit_tier2_item() -> void:
	"""§7.2 step 5: tier-1 clothing is spawn equipment, NOT twelve invented outfit items."""
	_bind_residents()
	var owners: Array[Vector2i] = _twelve_owners()
	assert_true(_store.seed_starter_tools(_defs, _container, owners, 0, TEST_PROVENANCE).ok,
		"seeding must succeed")
	assert_equal(_inv.total_live_milli(_id(&"outfit_tier2")), 0,
		"not one tier-2 outfit was created")
	assert_equal(_inv.total_sourced_milli(_id(&"outfit_tier2")), 0, "not even and then consumed")
	assert_equal(_store.active_gear_count(), GearScript.STARTER_TOOL_TOTAL,
		"the 24 instances are all tools")


func test_seeding_refuses_a_cohort_that_is_not_twelve_residents() -> void:
	"""One tool per resident is an exact allotment, not a lower bound."""
	_bind_residents()
	var owners: Array[Vector2i] = [_resident(), _resident()]
	var seeded: InventoryScript.OpResult = _store.seed_starter_tools(_defs, _container, owners,
		0, TEST_PROVENANCE)
	assert_false(seeded.ok, "two owners are not the §5.9 cohort")
	assert_equal(seeded.error, GearScript.REFUSE_INVALID_OWNER_COUNT, "named explicitly")
	assert_equal(_store.active_gear_count(), 0, "and nothing was created")


func test_seeding_refuses_a_repeated_owner() -> void:
	"""Twelve entries naming eleven residents would leave one of them with two tools."""
	_bind_residents()
	var owners: Array[Vector2i] = _twelve_owners()
	owners[11] = owners[0]
	var seeded: InventoryScript.OpResult = _store.seed_starter_tools(_defs, _container, owners,
		0, TEST_PROVENANCE)
	assert_false(seeded.ok, "a repeated owner is refused")
	assert_equal(seeded.error, GearScript.REFUSE_DUPLICATE_OWNER, "named explicitly")
	assert_equal(_store.active_gear_count(), 0, "and nothing was created")


func test_a_seeding_that_runs_out_of_container_space_undoes_itself_whole() -> void:
	"""Inventory capacity is refused by inventory, mid-seed. The rollback must undo it whole.

	NOT byte-identical on the inventory side, and deliberately not asserted to be: creating and
	retiring a lot advances that slot's generation, and `_advance_generations()` exists precisely
	so a reference taken before can never validate after. What IS asserted is everything that
	rollback actually owes -- no gear rows, no equipped rows, no lots, no charged mass, an
	untouched Equipment mirror, and conservation still balancing under a full audit.
	"""
	_bind_residents()
	var owners: Array[Vector2i] = _twelve_owners()
	var tight: Vector2i = _inv.create_container(CONTAINER_OWNER, 4 * TOOL_MASS_G,
		InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true).ref
	var gear_before: PackedByteArray = _store.state_bytes()
	var mirror_before: PackedByteArray = _residents.equipment_state_bytes()
	var seeded: InventoryScript.OpResult = _store.seed_starter_tools(_defs, tight, owners, 0,
		TEST_PROVENANCE)
	assert_false(seeded.ok, "a container that holds four tools cannot take twelve stored ones")
	assert_equal(seeded.error, InventoryScript.REFUSE_CAPACITY_EXCEEDED, "named explicitly")
	assert_equal(_store.active_gear_count(), 0, "every gear row it made was destroyed")
	assert_equal(_store.equipped_count(), 0, "every equip it made was undone")
	assert_equal(_inv.container_lot_count(tight), 0, "every lot it made was sunk")
	assert_equal(_inv.container_used_mass_g(tight), 0, "and the container charges nothing")
	assert_equal(_inv.live_lot_count(), 0, "no lot survives anywhere")
	assert_equal(_inv.equipped_lot_count(), 0, "and no null-container lot was left behind")
	assert_equal(_store.state_bytes(), gear_before, "the gear store is byte-identical")
	assert_equal(_residents.equipment_state_bytes(), mirror_before, "the mirror is byte-identical")
	assert_true(_inv.audit().ok, "and conservation still balances after the undo")


func test_seeding_refuses_whole_when_the_gear_pool_cannot_hold_24() -> void:
	"""Allocate before consume: a pool one row short spends nothing at all."""
	_store = GearScript.new(23)
	_bind_residents()
	var owners: Array[Vector2i] = _twelve_owners()
	var seeded: InventoryScript.OpResult = _store.seed_starter_tools(_defs, _container, owners,
		0, TEST_PROVENANCE)
	assert_false(seeded.ok, "23 rows cannot hold 24 starter tools")
	assert_equal(seeded.error, GearScript.REFUSE_CAPACITY_GEAR_INSTANCE, "named explicitly")
	assert_equal(_inv.live_lot_count(), 0, "and not one lot was created before the refusal")


