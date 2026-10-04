extends "res://test/framework/test_case.gd"
## Actual shared Inventory/Reservation/WIP transactions; operation permission is explicitly synthetic.

const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Excavation := preload("res://scripts/core/excavation_contract.gd")
const Funding := preload("res://scripts/core/excavation_inventory.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const AccountingFixture := preload("res://test/test_construction_modular.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const JOB: Vector2i = Vector2i(3, 1)
const OTHER_JOB: Vector2i = Vector2i(4, 1)

class Router extends AccountingFixture.SyntheticRouter:
	var output_items: PackedInt32Array = PackedInt32Array()
	var output_quantities: PackedInt64Array = PackedInt64Array()
	var provenance: int = Catalog.PROVENANCE_SPOIL_RECLAIM
	var observed_inventory: Inventory = null
	var observed_refund_item: int = -1
	var observed_refund_quantity: int = 0
	var refund_quotes_after_commit: int = 0
	var input_funding: WeakRef = null

	func _fill(out: Quote) -> void:
		"""The isolated source fixture supplies exact metadata; no actual tip stock is claimed here."""
		super._fill(out)
		if observed_inventory != null and observed_refund_item >= 0 \
				and not observed_inventory.is_transaction_open() \
				and observed_inventory.total_live_milli(observed_refund_item) >= observed_refund_quantity:
			refund_quotes_after_commit += 1
		out.output_count = output_items.size()
		for index: int in output_items.size():
			out.output_item[index] = output_items[index]
			out.output_milli[index] = output_quantities[index]
			out.output_quality[index] = int(Catalog.QUALITY["PLAIN"])
			out.output_provenance[index] = provenance

	func final_funding_refusal(project: Vector2i, action: int) -> StringName:
		"""This store test supplies explicit synthetic source proof within the exact existing test permit."""
		return mutation_refusal(project, action)

	func connector_inputs_refusal(project: Vector2i, job: Vector2i,
			inventory: RefCounted, pool: RefCounted) -> StringName:
		"""The isolated permission fixture still requires actual Funding's exact original settlement."""
		var funding: Funding = input_funding.get_ref() as Funding if input_funding != null else null
		if funding == null or job != JOB or not funding.is_settling_connector_inputs(
				project, job, inventory as Inventory, pool as Reservations):
			return REFUSE_AUTHORITY
		return mutation_refusal(project, ACTION_WIP)

	func final_input_refusal(project: Vector2i, job: Vector2i,
			inventory: RefCounted, pool: RefCounted) -> StringName:
		"""Repeat the exact synthetic fixture scope at the real precommit point."""
		return connector_inputs_refusal(project, job, inventory, pool)

class PaidSite extends Excavation:
	var input_funding: WeakRef = null
	var attached_project: Vector2i = NULL_REF

	func is_live_site(site: Vector2i) -> bool:
		"""Synthetic physical subject for testing one receipt arena across actual project purposes."""
		return site == Vector2i(19, 1)

	func project_open_refusal(_site: Vector2i, _operation: int) -> StringName:
		"""This fixture supplies no production geometry permission."""
		return &""

	func remaining_work_into(_site: Vector2i, operation: int, out: IntMath.IntResult) -> bool:
		"""Actual adopted brace/cut prices, without fake timed progress."""
		return out.succeed(Excavation.work_mwu(operation))

	func attach_project(_site: Vector2i, _operation: int, project: Vector2i) -> void:
		"""Retain only this accounting fixture's exact actual Project; no map or paid history is published."""
		attached_project = project

	func mutation_refusal(_project: Vector2i, _action: int) -> StringName:
		"""Synthetic store-level permission is confined to this test's actual accounting owners."""
		return &""

	func excavation_inputs_refusal(project: Vector2i, job: Vector2i,
			inventory: RefCounted, pool: RefCounted) -> StringName:
		"""Synthetic physical permission is confined to the actual original shared Funding input bracket."""
		var funding: Funding = input_funding.get_ref() as Funding if input_funding != null else null
		return &"" if funding != null and project == attached_project and job == OTHER_JOB \
			and funding.is_settling_connector_inputs(project, job, inventory as Inventory, pool as Reservations) \
			else REFUSE_AUTHORITY

	func final_input_refusal(project: Vector2i, job: Vector2i, inventory: RefCounted,
			pool: RefCounted, _output: Vector2i, _mass: int) -> StringName:
		"""The accounting-only source repeats its exact bracket at the real final Inventory guard."""
		return excavation_inputs_refusal(project, job, inventory, pool)

class PileContact extends RefCounted:
	var world: Vector2i = NULL_REF
	var blocked: bool = false

	func ground_pile_tile_refusal(tile: int) -> StringName:
		"""Only one explicitly synthetic contact exists; production needs the actual space owner."""
		return &"SYNTHETIC_CONTACT_BLOCKED" if blocked or tile != 20 else &""

	func ground_pile_owner_ref() -> Vector2i:
		"""Use the actual fixture's World identity."""
		return world

var _construction: Construction = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _funding: Funding = null
var _router: Router = null
var _spatial: AccountingFixture.SyntheticSpatial = null
var _site: PaidSite = null
var _pile: PileContact = null
var _input: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF


func before_each() -> void:
	"""One real shared receipt arena, exact catalog, Inventory and Reservation owner per test."""
	_construction = Construction.new()
	_router = Router.new()
	_router.owner = weakref(_construction)
	_router.world = _construction.directory().create(Directory.KIND_WORLD)
	assert_true(_construction.bind_modular_authority(_router).ok, "actual modular binding")
	_inventory = Inventory.new(16, 32)
	_pool = Reservations.new(16)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual catalog registers")
	_funding = Funding.new(_construction, _inventory, _pool, _items, 16)
	_router.input_funding = weakref(_funding)
	_input = _inventory.create_container(_router.world, 100000, -1, 0, true).ref
	_output = _inventory.create_container(_router.world, 100000, -1, 0, true).ref


func after_each() -> void:
	"""All actual material and claim owners remain auditable after success, refusal or rollback."""
	assert_true(_inventory.audit().ok, "Inventory conservation audit")
	assert_true(_pool.audit(_inventory).ok, "Reservation ownership audit")
	_funding = null
	_router = null
	_site = null
	_spatial = null
	_pile = null
	_items = null
	_pool = null
	_inventory = null
	_construction = null


func _open(purpose: int = Construction.PURPOSE_SPOIL_TIP) -> Vector2i:
	"""Allocate the actual project from the prepared synthetic operation quote."""
	_router.prepared = true
	var made: Construction.OpResult = _construction.open_modular_phase(purpose, _router.subject, _router.operation)
	assert_true(made.ok, "real project opens: %s" % made.error)
	_router.allow(made.ref, Contract.ACTION_CONTAINER)
	assert_true(_construction.set_material_container(made.ref, _input).ok, "actual delivery container binding")
	_router.allow(NULL_REF, -1)
	return made.ref


func _input_lot(key: StringName, quantity: int, job: Vector2i = JOB,
		purpose: int = Reservations.PURPOSE_MODULAR_INPUT, expiry: int = 900) -> Vector2i:
	"""Preserve observable source quality, provenance, recipe and age through the real claims."""
	var made: Inventory.OpResult = _inventory.create_lot(_input, _items.compiled_id(key),
		quantity, 2, Catalog.PROVENANCE_ORDINARY, 23, 4123, 19)
	assert_true(made.ok, "real source lot")
	var claim: PackedInt64Array = PackedInt64Array([made.ref.x, made.ref.y, purpose, quantity, expiry])
	assert_true(_pool.claim_batch(job, claim, 1, _inventory).ok, "real full-generation input claim")
	return made.ref


func _deliver(project: Vector2i, index: int, quantity: int) -> void:
	"""Credit only the test's matching real delivery, through its explicit accounting permit."""
	_router.allow(project, Contract.ACTION_DELIVER)
	assert_true(_construction.deliver_material(project, index, quantity).ok, "actual claimed input credited")
	_router.allow(NULL_REF, -1)


func _start(project: Vector2i, output: Vector2i = NULL_REF, now_tick: int = 100) -> Inventory.OpResult:
	"""Perform the actual atomic consume-and-reserve transaction under the owner permit."""
	_router.allow(project, Contract.ACTION_WIP)
	var result: Inventory.OpResult = _funding.consume_to_wip(project, JOB, now_tick, output)
	_router.allow(NULL_REF, -1)
	return result


func _begin(project: Vector2i) -> void:
	"""Mark actual consumed WIP begun; real productive Work is the following router increment."""
	_router.allow(project, Contract.ACTION_BEGIN_WORK)
	assert_true(_construction.begin_work(project).ok, "actual funded phase begins")
	_router.allow(NULL_REF, -1)


func _complete_labor(project: Vector2i) -> void:
	"""This accounting fixture credits exact declared work; it is not a live worker simulation."""
	_router.allow(project, Contract.ACTION_WORK)
	assert_true(_construction.add_work_mwu(project, _router.total).ok, "declared labor accounting complete")
	_router.allow(NULL_REF, -1)


func _cancel(project: Vector2i, destination: Vector2i = NULL_REF) -> Inventory.OpResult:
	"""Freeze then refund through the same shared actual receipt owner."""
	_router.allow(project, Contract.ACTION_CANCEL)
	assert_true(_construction.begin_refund(project).ok, "owner freezes project")
	_router.allow(project, Contract.ACTION_REFUND)
	var result: Inventory.OpResult = _funding.refund_wip(project, destination)
	_router.allow(NULL_REF, -1)
	return result


func _commit(project: Vector2i, tile: int = -1) -> Inventory.OpResult:
	"""Call the actual shared output transaction, never manually reproduce its Inventory writes."""
	_router.allow(project, Contract.ACTION_OUTPUT)
	var result: Inventory.OpResult = _funding.commit_modular_outputs(project, tile)
	_router.allow(NULL_REF, -1)
	return result


func _receipt_image() -> PackedByteArray:
	"""Capture every authoritative material/claim/WIP owner before a refusal or retry."""
	var image: PackedByteArray = _inventory.state_bytes()
	image.append_array(_pool.state_bytes())
	image.append_array(_funding.state_bytes())
	return image


func _bench() -> Vector2i:
	"""Allocate real pending Kitchen Furniture, then read its unchanged protected recipe."""
	var buildings: Buildings = _construction.buildings()
	_spatial = AccountingFixture.SyntheticSpatial.new()
	_spatial.owner = weakref(buildings)
	assert_true(buildings.bind_spatial_authority(_spatial).ok, "actual spatial fixture binds")
	_spatial.action = Buildings.SPATIAL_ROOM_CREATE
	_spatial.value = Buildings.ROOM_TYPE_KITCHEN
	var room: Vector2i = buildings.designate_spatial_room(_spatial.value).ref
	_spatial.action = Buildings.SPATIAL_FURNITURE_CREATE
	_spatial.related = room
	_spatial.value = int(Catalog.FURNITURE_DEFINITION["kitchen_bench"])
	_router.subject = buildings.stage_spatial_furniture(room, _spatial.value, 0).ref
	_spatial.action = -1
	_router.operation = _spatial.value
	_router.quantity = 0
	_router.total = _construction.definitions().furniture_work_mwu_of(_router.operation)
	_router.remaining = _router.total
	_router.keys = [&"wood", &"stone", &"iron"]
	_router.amounts = PackedInt64Array([4000, 4000, 1000])
	return _open(Construction.PURPOSE_SPATIAL_FURNITURE)


func _reclaim_quote() -> void:
	"""An explicitly synthetic source authorizes one actual 1001-milli output candidate."""
	_router.operation = 3
	_router.total = 501
	_router.remaining = 501
	_router.keys = []
	_router.amounts = PackedInt64Array()
	_router.output_items = PackedInt32Array([_items.compiled_id(&"excavated_earth")])
	_router.output_quantities = PackedInt64Array([1001])


func test_three_line_catalog_bill_consumes_all_inputs_and_refunds_exact_metadata() -> void:
	"""The bench's third input cannot disappear in the old excavation two-line special case."""
	var project: Vector2i = _bench()
	for index: int in 3:
		_input_lot(_router.keys[index], _router.amounts[index])
		_deliver(project, index, _router.amounts[index])
	assert_true(_start(project).ok, "one shared real WIP transaction consumes every line")
	for index: int in 3:
		var item: int = _items.compiled_id(_router.keys[index])
		assert_equal(_inventory.total_live_milli(item), 0, "actual loose input consumed")
		assert_equal(_funding.wip_milli(project, item), _router.amounts[index], "every receipt retained")
	_begin(project)
	assert_true(_cancel(project, _output).ok, "exact refund returns all three inputs")
	for index: int in 3:
		var item: int = _items.compiled_id(_router.keys[index])
		@warning_ignore("integer_division")
		assert_equal(_inventory.total_live_milli(item), _router.amounts[index] * 4 / 5, "whole-item 80 percent")
		@warning_ignore("integer_division")
		assert_equal(_funding.purpose_cancellation_loss_milli(6, item), _router.amounts[index] / 5, "furniture-only loss")
		assert_equal(_funding.purpose_cancellation_loss_milli(5, item), 0, "brace account untouched")
	var lot: Vector2i = _inventory.container_first_lot(_output)
	while lot != NULL_REF:
		assert_equal(_inventory.lot_quality(lot), 2, "quality preserved")
		assert_equal(_inventory.lot_recipe_id(lot), 23, "recipe preserved")
		assert_equal(_inventory.lot_age_milli_hours(lot), 4123, "actual captured age preserved")
		assert_equal(_inventory.lot_age_remainder(lot), 19, "age remainder preserved")
		lot = _inventory.container_next_lot(lot)


func test_extra_input_wrong_purpose_and_expired_claims_refuse_without_consumption() -> void:
	"""Matching total mass does not replace exact item/purpose/absolute lease ownership."""
	var project: Vector2i = _open()
	_input_lot(&"excavated_earth", 1001, JOB, Reservations.PURPOSE_MODULAR_INPUT, 100)
	_deliver(project, 0, 1001)
	var before: PackedByteArray = _receipt_image()
	assert_equal(_start(project).error, Reservations.REFUSE_INPUT_CLAIM_EXPIRED, "absolute expiry refuses")
	assert_equal(_receipt_image(), before, "expired refusal changes no owner")
	assert_true(_pool.release_job_claims(JOB, _inventory).ok, "release expired actual claim")
	_input_lot(&"excavated_earth", 1001, JOB, Reservations.PURPOSE_EXCAVATION_INPUT)
	before = _receipt_image()
	assert_equal(_start(project).error, Funding.REFUSE_INPUTS, "site purpose cannot fund tip")
	assert_equal(_receipt_image(), before, "wrong purpose changes no owner")
	assert_true(_pool.release_job_claims(JOB, _inventory).ok, "release wrong actual claim")
	_input_lot(&"excavated_earth", 1001)
	_input_lot(&"wood", 1)
	before = _receipt_image()
	assert_equal(_start(project).error, Funding.REFUSE_INPUTS, "extra material cannot silently vanish")
	assert_equal(_receipt_image(), before, "extra line changes no owner")


func test_direct_output_calls_cannot_clear_paid_wip_and_no_output_completion_is_once_only() -> void:
	"""A material-only operation has a real funded record even when it creates no loose output."""
	var project: Vector2i = _open()
	_input_lot(&"excavated_earth", 1001)
	_deliver(project, 0, 1001)
	assert_true(_start(project).ok, "actual paid inputs consumed")
	_begin(project)
	_complete_labor(project)
	var before: PackedByteArray = _receipt_image()
	assert_false(_funding.commit_modular_outputs(project).ok, "no direct output permission")
	assert_false(_funding.commit_outputs(project, Catalog.PROVENANCE_ORDINARY).ok, "excavation door cannot reinterpret modular op")
	assert_equal(_receipt_image(), before, "paid WIP remains intact")
	assert_true(_commit(project).ok, "actual no-output commit retires consumed WIP once")
	assert_false(_funding.is_funded(project), "record released after commit")
	before = _receipt_image()
	assert_false(_commit(project).ok, "duplicate output completion refuses")
	assert_equal(_receipt_image(), before, "duplicate cannot alter quantities")


func test_first_pile_refusal_rolls_back_outputs_reservation_and_wip_before_retry() -> void:
	"""Actual first-pile publication retains its complete funded operation when contact is blocked."""
	_reclaim_quote()
	_pile = PileContact.new()
	_pile.world = _router.world
	assert_true(_inventory.set_ground_pile_authority(_pile).ok, "explicit pile contact fixture")
	_output = _inventory.create_container(_router.world, Inventory.GROUND_PILE_MAX_MASS_G, -1, Inventory.UNSET_POLICY, true).ref
	assert_true(_inventory.set_container_anchor(_output, 20).ok, "actual output contact staged")
	var project: Vector2i = _open()
	assert_true(_start(project, _output).ok, "first material-free operation reserves real staging")
	_begin(project)
	_complete_labor(project)
	_pile.blocked = true
	var before: PackedByteArray = _receipt_image()
	assert_false(_commit(project, 20).ok, "blocked promotion refuses")
	assert_equal(_receipt_image(), before, "Inventory, claims and WIP are byte identical")
	assert_equal(_inventory.container_reserved_mass_g(_output), 1001, "owned finite headroom retained")
	_pile.blocked = false
	assert_true(_commit(project, 20).ok, "same paid candidate retries without more work")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 1001, "exact source output once")
	assert_equal(_inventory.ground_pile_at_tile(20), _output, "actual ground map published")
	assert_false(_commit(project, 20).ok, "duplicate cannot mint earth")


func test_shared_container_keeps_another_projects_output_claim_and_source_claim() -> void:
	"""The shared arena never releases or consumes a neighboring project's finite claims."""
	_reclaim_quote()
	_site = PaidSite.new()
	_site.input_funding = weakref(_funding)
	assert_true(_construction.bind_excavation_authority(_site).ok, "actual second purpose binds")
	var phase: Vector2i = _construction.open_excavation_phase(Vector2i(19, 1), Excavation.OP_CUT).ref
	assert_true(_funding.consume_to_wip(phase, OTHER_JOB, 100, _output).ok, "same arena reserves actual cut output")
	var untouched: Vector2i = _input_lot(&"wood", 17, OTHER_JOB, Reservations.PURPOSE_HAUL_SOURCE)
	var project: Vector2i = _open()
	assert_true(_start(project, _output).ok, "same container reserves separate modular output")
	assert_equal(_inventory.container_reserved_mass_g(_output), 3001, "both finite reservations coexist")
	_begin(project)
	_complete_labor(project)
	assert_true(_commit(project).ok, "one actual output settles")
	assert_equal(_inventory.container_reserved_mass_g(_output), 2000, "other phase reservation survives")
	assert_equal(_inventory.lot_reserved_milli(untouched), 17, "other source claim survives")
	assert_equal(_pool.job_claim_count(OTHER_JOB), 1, "other claim row survives")
	assert_true(_funding.is_funded(phase), "same shared receipt owner keeps other project")


func test_second_output_allocation_failure_rolls_back_first_output_and_every_receipt() -> void:
	"""A two-output candidate is atomic even when only the second allocation fails."""
	_reclaim_quote()
	_router.provenance = Catalog.PROVENANCE_ORDINARY
	_router.output_items = PackedInt32Array([_items.compiled_id(&"wood"), _items.compiled_id(&"stone")])
	_router.output_quantities = PackedInt64Array([125, 125])
	var project: Vector2i = _open()
	assert_true(_start(project, _output).ok, "real output mass reserved")
	_begin(project)
	_complete_labor(project)
	for index: int in _inventory.canonical_capacities().y - 1:
		assert_true(_inventory.create_lot(_input, _items.compiled_id(&"wood"), 1, 1, 0, -1, 0, 0).ok, "occupy actual lot row")
	var before: PackedByteArray = _receipt_image()
	assert_equal(_commit(project).error, Inventory.REFUSE_CAPACITY_INVENTORY_LOT, "second output has no row")
	assert_equal(_receipt_image(), before, "first lot, reservation release and WIP all roll back")
	assert_true(_funding.is_funded(project), "earned operation remains funded")
	var released: Vector2i = _inventory.container_first_lot(_input)
	assert_true(_inventory.sink_lot_quantity(released, 1).ok, "one actual lot row frees")
	assert_true(_commit(project).ok, "complete output pair retries together")
	assert_equal(_inventory.container_lot_count(_output), 2, "both real outputs publish exactly once")
	assert_equal(_inventory.container_reserved_mass_g(_output), 0, "owned output reservation settles")


func test_zero_input_cancel_requires_no_destination_and_does_not_debit_source_stock() -> void:
	"""No fabricated refund capacity is required for a material-free source operation."""
	_reclaim_quote()
	var project: Vector2i = _open()
	assert_true(_start(project, _output).ok, "real output reservation")
	_begin(project)
	assert_true(_cancel(project).ok, "empty receipts cancel without a destination")
	assert_equal(_inventory.container_reserved_mass_g(_output), 0, "actual owned output reservation releases")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 0, "cancellation creates no source output")
	assert_equal(_funding.cancellation_loss_milli(_items.compiled_id(&"excavated_earth")), 0, "no material means no loss")


func test_output_provenance_and_overflow_refuse_before_reserving_or_consuming() -> void:
	"""The typed quote cannot put an earth-only label on wood or overflow finite mass arithmetic."""
	_reclaim_quote()
	_router.output_items[0] = _items.compiled_id(&"wood")
	var project: Vector2i = _open()
	var before: PackedByteArray = _receipt_image()
	assert_false(_start(project, _output).ok, "invalid item/provenance pair refuses")
	assert_equal(_receipt_image(), before, "invalid output consumes nothing")
	_router.provenance = Catalog.PROVENANCE_ORDINARY
	_router.output_quantities[0] = 9223372036854775807
	assert_false(_start(project, _output).ok, "checked mass multiplication refuses overflow")
	assert_equal(_receipt_image(), before, "overflow reserves no output")


func test_foreign_inventory_composition_is_rejected_even_with_matching_numeric_lots() -> void:
	"""The shared receipt getter and late catalog rewire must reject another actual Inventory."""
	var project: Vector2i = _open()
	_input_lot(&"excavated_earth", 1001)
	_deliver(project, 0, 1001)
	assert_true(_funding.composition_matches(_construction, _inventory, _pool, _items), "actual shared arena owner")
	var foreign: Inventory = Inventory.new(16, 32)
	assert_false(_funding.composition_matches(_construction, foreign, _pool, _items), "foreign actual Inventory refuses")
	assert_true(_items.load_default(foreign).ok, "catalog can legitimately register into another owner")
	var before: PackedByteArray = _receipt_image()
	assert_false(_start(project).ok, "late catalog rewire refuses before payment")
	assert_equal(_receipt_image(), before, "original physical stores remain unchanged")


func test_blocked_modular_refund_retains_wip_and_books_loss_once_after_retry() -> void:
	"""A full refund destination must not destroy paid receipts or pre-book historical loss."""
	var project: Vector2i = _open()
	_input_lot(&"excavated_earth", 1001)
	_deliver(project, 0, 1001)
	assert_true(_start(project).ok, "actual full bill consumed")
	_begin(project)
	var blocked: Vector2i = _inventory.create_container(_router.world, 1, -1, 0, true).ref
	var before: PackedByteArray = _receipt_image()
	assert_equal(_cancel(project, blocked).error, Inventory.REFUSE_CAPACITY_EXCEEDED, "physical refund cannot fit")
	assert_equal(_receipt_image(), before, "every receipt, claim and material survives")
	assert_equal(_funding.purpose_cancellation_loss_milli(7, _items.compiled_id(&"excavated_earth")), 0, "loss is not booked early")
	_router.allow(project, Contract.ACTION_REFUND)
	assert_true(_funding.refund_wip(project, _output).ok, "same frozen cancellation retries")
	assert_false(_funding.refund_wip(project, _output).ok, "already-settled cancellation refuses")
	_router.allow(project, Contract.ACTION_RETIRE)
	assert_true(_construction.retire_modular_phase(project, _router).ok, "actual project retires")
	_router.allow(NULL_REF, -1)
	var earth: int = _items.compiled_id(&"excavated_earth")
	assert_equal(_inventory.total_live_milli(earth), 800, "actual integer refund returned once")
	assert_equal(_funding.purpose_cancellation_loss_milli(7, earth), 201, "loss survives full project retirement")
	assert_equal(_funding.purpose_cancellation_loss_milli(5, earth), 0, "excavation sink remains separate")
	assert_equal(_funding.purpose_wip_milli(7, earth), 0, "retired receipt account is empty")


func test_connector_refund_has_its_own_persistent_loss_domain_and_exact_retry() -> void:
	"""New purpose uses real existing receipts and preserves loss after actual project retirement."""
	_router.keys = [&"wood"]
	_router.amounts = PackedInt64Array([1001])
	var project: Vector2i = _open(Construction.PURPOSE_CONNECTOR_INSTALL)
	_input_lot(&"wood", 1001)
	_deliver(project, 0, 1001)
	assert_true(_start(project).ok, "actual full input consumed")
	_begin(project)
	_router.observed_inventory = _inventory
	_router.observed_refund_item = _items.compiled_id(&"wood")
	_router.observed_refund_quantity = 800
	var blocked: Vector2i = _inventory.create_container(_router.world, 1, -1, 0, true).ref
	var before: PackedByteArray = _receipt_image()
	assert_equal(_cancel(project, blocked).error, Inventory.REFUSE_CAPACITY_EXCEEDED, "refund cannot fit")
	assert_equal(_receipt_image(), before, "actual inputs and WIP unchanged")
	_router.allow(project, Contract.ACTION_REFUND)
	assert_true(_funding.refund_wip(project, _output).ok, "same WIP retries once")
	assert_equal(_router.refund_quotes_after_commit, 0, "committed refund never invokes another fallible bill observer")
	assert_false(_funding.refund_wip(project, _output).ok, "duplicate refund refused")
	_router.allow(project, Contract.ACTION_RETIRE)
	assert_true(_construction.retire_modular_phase(project, _router).ok, "real project retires")
	_router.allow(NULL_REF, -1)
	var wood: int = _items.compiled_id(&"wood")
	assert_equal(_inventory.total_live_milli(wood), 800, "ordinary construction80percent refund")
	assert_equal(_funding.purpose_cancellation_loss_milli(8, wood), 201, "connector loss retained")
	for purpose: int in [5, 6, 7]:
		assert_equal(_funding.purpose_cancellation_loss_milli(purpose, wood), 0, "other history namespace untouched")
	assert_equal(_funding.cancellation_loss_milli(wood), 201, "whole-world loss includes connector once")


func test_excavation_support_and_furniture_receipts_remain_separate_in_one_arena() -> void:
	"""Furnishing materials and losses must never enter the physical brace conservation ledger."""
	var project: Vector2i = _bench()
	_site = PaidSite.new()
	_site.input_funding = weakref(_funding)
	assert_true(_construction.bind_excavation_authority(_site).ok, "same actual Construction binds excavation")
	var brace: Vector2i = _construction.open_excavation_phase(Vector2i(19, 1), Excavation.OP_BRACE).ref
	assert_true(_construction.set_material_container(brace, _input).ok, "brace delivery contact")
	for index: int in 2:
		var key: StringName = [&"wood", &"stone"][index]
		_input_lot(key, 250, OTHER_JOB, Reservations.PURPOSE_EXCAVATION_INPUT)
		assert_true(_construction.deliver_material(brace, index, 250).ok, "actual brace inputs delivered")
	assert_true(_funding.consume_to_wip(brace, OTHER_JOB, 100, NULL_REF).ok, "brace inputs enter the one arena")
	for index: int in 3:
		_input_lot(_router.keys[index], _router.amounts[index])
		_deliver(project, index, _router.amounts[index])
	assert_true(_start(project).ok, "furniture inputs enter that same arena")
	var wood: int = _items.compiled_id(&"wood")
	assert_equal(_funding.purpose_wip_milli(5, wood), 250, "only real brace WIP")
	assert_equal(_funding.purpose_wip_milli(6, wood), 4000, "only real furniture WIP")
	_begin(project)
	assert_true(_cancel(project, _output).ok, "furniture cancels independently")
	assert_equal(_funding.purpose_wip_milli(5, wood), 250, "brace remains paid")
	assert_equal(_funding.purpose_wip_milli(6, wood), 0, "furniture receipt releases")
	assert_equal(_funding.purpose_cancellation_loss_milli(5, wood), 0, "brace loss is unchanged")
	assert_equal(_funding.purpose_cancellation_loss_milli(6, wood), 800, "furniture loss is explicit")
	assert_equal(_funding.total_wip_milli(wood), 250, "global shared receipt sum counts once")
