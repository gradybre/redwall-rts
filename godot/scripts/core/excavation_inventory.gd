extends RefCounted
## Shared paid-operation WIP receipts. Inventory owns loose goods; these columns own consumed inputs.
## Receipt capacity is an explicit world budget, never a room-size or input-lot truncation rule.
## All cold transactions either publish the entire receipt/account change or none of it.

const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const ModularContract := preload("res://scripts/core/modular_project_contract.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const DirectoryScript := preload("res://scripts/core/entity_directory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const NO_ROW: int = -1
## Explicit concurrent-receipt engineering envelope, not a per-room or historical-input limit.
const MAX_RECEIPT_CAPACITY: int = Reservations.ROW_CAPACITY
const LOSS_DOMAIN_COUNT: int = 4
const LOSS_CELL_CAPACITY: int = LOSS_DOMAIN_COUNT * Inventory.ITEM_CAPACITY
const REFUSE_WIP: StringName = &"EXCAVATION_WIP_STATE"
const REFUSE_RECEIPTS: StringName = &"CAPACITY_EXCAVATION_RECEIPTS"
const REFUSE_INPUTS: StringName = &"EXCAVATION_INPUT_OWNERSHIP"
const REFUSE_ITEM: StringName = &"EXCAVATION_ITEM_CATALOG"

var _construction: Construction = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _capacity: int = 0
var _ready_error: StringName = REFUSE_RECEIPTS
var _free_count: int = 0
var _free: PackedInt32Array = PackedInt32Array()
var _project_slot: PackedInt32Array = PackedInt32Array()
var _project_generation: PackedInt32Array = PackedInt32Array()
var _head: PackedInt32Array = PackedInt32Array()
var _output_slot: PackedInt32Array = PackedInt32Array()
var _output_generation: PackedInt32Array = PackedInt32Array()
var _output_mass_g: PackedInt64Array = PackedInt64Array()
var _r_next: PackedInt32Array = PackedInt32Array()
var _r_item: PackedInt32Array = PackedInt32Array()
var _r_quality: PackedInt32Array = PackedInt32Array()
var _r_provenance: PackedInt32Array = PackedInt32Array()
var _r_recipe: PackedInt32Array = PackedInt32Array()
var _r_quantity: PackedInt64Array = PackedInt64Array()
var _r_age: PackedInt64Array = PackedInt64Array()
var _r_remainder: PackedInt64Array = PackedInt64Array()
var _lost_milli: PackedInt64Array = PackedInt64Array()
## Transaction scratch is preallocated at the same explicitly budgeted receipt capacity.
var _s_item: PackedInt32Array = PackedInt32Array()
var _s_quality: PackedInt32Array = PackedInt32Array()
var _s_provenance: PackedInt32Array = PackedInt32Array()
var _s_recipe: PackedInt32Array = PackedInt32Array()
var _s_quantity: PackedInt64Array = PackedInt64Array()
var _s_age: PackedInt64Array = PackedInt64Array()
var _s_remainder: PackedInt64Array = PackedInt64Array()
var _s_count: int = 0
var _s_totals: PackedInt64Array = PackedInt64Array()
var _s_returned: PackedInt64Array = PackedInt64Array()
var _s_carry: PackedInt64Array = PackedInt64Array()
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _quote: ModularContract.Quote = ModularContract.Quote.new()
## Same-stack settlement scope; never authoritative, saved or retained after a call returns.
var _settling_project: Vector2i = NULL_REF
var _settling_job: Vector2i = NULL_REF


func _init(construction: Construction, inventory: Inventory, pool: Reservations,
		items: Items, receipt_capacity: int) -> void:
	"""Allocate the declared world receipt budget; no hidden per-phase lot limit is introduced."""
	_construction = construction
	_inventory = inventory
	_pool = pool
	_items = items
	_capacity = clampi(receipt_capacity, 0, MAX_RECEIPT_CAPACITY)
	if not valid_receipt_budget(receipt_capacity, pool):
		return
	_ready_error = &""
	_free_count = _capacity
	_allocate_projects()
	_allocate_receipts()
	_allocate_scratch()
	_lost_milli.resize(LOSS_CELL_CAPACITY)
	for row: int in _capacity:
		_free[row] = _capacity - row - 1


static func valid_receipt_budget(requested: int, pool: Reservations) -> bool:
	"""Refuse invalid or oversized configuration before allocation; never silently truncate inputs."""
	return pool != null and requested > 0 and requested <= MAX_RECEIPT_CAPACITY \
		and requested <= pool.row_capacity()


func initialization_refusal() -> StringName:
	"""Report refused capacity explicitly; callers cannot mistake empty storage for funded work."""
	return _ready_error


func composition_matches(construction: Construction, inventory: Inventory,
		pool: Reservations, items: Items) -> bool:
	"""Expose existing arena ownership without allowing a second or foreign receipt account."""
	return _ready_error == &"" and construction == _construction and inventory == _inventory \
		and pool == _pool and items == _items and items != null and items.registered_into(inventory) \
		and pool != null and pool.composition_refusal(inventory) == &""


func _owner_mutation_refusal(project: Vector2i, action: int) -> StringName:
	"""Both paid purposes retain their own exact coordinator permit and live composition checks."""
	if not composition_matches(_construction, _inventory, _pool, _items) or _construction == null \
			or not _construction.purpose_into(project, _math):
		return Construction.REFUSE_COORDINATOR_ONLY
	if _math.value == Construction.PURPOSE_EXCAVATION:
		var site: Contract = _construction.excavation_authority()
		return site.mutation_refusal(project, action) if site != null else Construction.REFUSE_COORDINATOR_ONLY
	if Construction.is_modular(_math.value):
		var modular: ModularContract = _construction.modular_authority()
		return modular.mutation_refusal(project, action) if modular != null else Construction.REFUSE_COORDINATOR_ONLY
	return Construction.REFUSE_COORDINATOR_ONLY


func _commit_guarded_transaction(project: Vector2i, action: int) -> Inventory.OpResult:
	"""Dispatch only the current actual purpose; connector observations stay inside Inventory's barrier."""
	var row: int = _construction._directory.get_typed_row(project)
	if row < 0 or row >= Construction.CONSTRUCTION_CAPACITY or _construction._present[row] != 1 \
			or _construction._ref_slot[row] != project.x or _construction._ref_generation[row] != project.y:
		_inventory.abort()
		return _refuse(REFUSE_WIP)
	if _construction._purpose[row] == Construction.PURPOSE_EXCAVATION:
		var site: Contract = _construction._excavation_authority.get_ref() as Contract \
			if _construction._excavation_authority != null else null
		return _inventory.commit_excavation_settlement(site, project, action)
	if _construction._purpose[row] != Construction.PURPOSE_CONNECTOR_INSTALL:
		return _inventory.commit()
	var owner: ModularContract = _construction._modular_authority.get_ref() as ModularContract \
		if _construction._modular_authority != null else null
	return _inventory.commit_connector_settlement(owner, project, action)


func _claim_purpose(project: Vector2i) -> int:
	"""Never reinterpret another Construction purpose's material claims as a paid phase."""
	if not _construction.purpose_into(project, _math):
		return -1
	if _math.value == Construction.PURPOSE_EXCAVATION:
		return Reservations.PURPOSE_EXCAVATION_INPUT
	return Reservations.PURPOSE_MODULAR_INPUT if Construction.is_modular(_math.value) else -1


static func _loss_domain(purpose: int) -> int:
	"""Historical loss domains survive project retirement; excavation support counts only its own."""
	if purpose == Construction.PURPOSE_EXCAVATION:
		return 0
	if purpose == Construction.PURPOSE_SPATIAL_FURNITURE:
		return 1
	if purpose == Construction.PURPOSE_SPOIL_TIP:
		return 2
	return 3 if purpose == Construction.PURPOSE_CONNECTOR_INSTALL else -1


func _loss_domain_of(project: Vector2i) -> int:
	"""Resolve a live project's purpose before any loss entry is read or written."""
	return _loss_domain(_math.value) if _construction.purpose_into(project, _math) else -1


func _allocate_projects() -> void:
	"""Project identity and output claims use the existing Construction typed-row capacity."""
	for column: PackedInt32Array in [_project_slot, _project_generation, _head,
			_output_slot, _output_generation]:
		column.resize(Construction.CONSTRUCTION_CAPACITY)
	_project_slot.fill(-1)
	_head.fill(-1)
	_output_slot.fill(-1)
	_output_mass_g.resize(Construction.CONSTRUCTION_CAPACITY)


func _allocate_receipts() -> void:
	"""One SoA receipt retains every input lot attribute needed for an honest refund."""
	for column: PackedInt32Array in [_free, _r_next, _r_item, _r_quality,
			_r_provenance, _r_recipe]:
		column.resize(_capacity)
	for column: PackedInt64Array in [_r_quantity, _r_age, _r_remainder]:
		column.resize(_capacity)
	_r_next.fill(-1)


func _allocate_scratch() -> void:
	"""Copies are temporary until the real Inventory transaction commits."""
	for column: PackedInt32Array in [_s_item, _s_quality, _s_provenance, _s_recipe]:
		column.resize(_capacity)
	for column: PackedInt64Array in [_s_quantity, _s_age, _s_remainder]:
		column.resize(_capacity)
	_s_totals.resize(Inventory.ITEM_CAPACITY)
	_s_returned.resize(Inventory.ITEM_CAPACITY)
	_s_carry.resize(Inventory.ITEM_CAPACITY)


func is_funded(project: Vector2i) -> bool:
	"""Only the exact live Construction generation can own retained material WIP."""
	if _ready_error != &"":
		return false
	var row: int = _project_row(project)
	return row != NO_ROW and _project_slot[row] == project.x and _project_generation[row] == project.y


func consume_to_wip(project: Vector2i, job: Vector2i, now_tick: int,
		output: Vector2i) -> Inventory.OpResult:
	"""Capture actual owned delivered inputs, consume once, and reserve the operation's output."""
	if _settling_project != NULL_REF:
		return _refuse(REFUSE_WIP)
	var guarded: bool = _ready_error == &"" and _construction.purpose_into(project, _math) \
		and (_math.value == Construction.PURPOSE_CONNECTOR_INSTALL or _math.value == Construction.PURPOSE_EXCAVATION)
	if guarded:
		_settling_project = project
	var result: Inventory.OpResult = _consume_to_wip(project, job, now_tick, output)
	if guarded:
		_settling_project = NULL_REF
		_settling_job = NULL_REF
	return result


func _consume_to_wip(project: Vector2i, job: Vector2i, now_tick: int,
		output: Vector2i) -> Inventory.OpResult:
	"""Guarded owners enter exclusive preparation before any bill or Inventory observer."""
	var refusal: StringName = _start_refusal(project, job)
	if refusal != &"":
		return _refuse(refusal)
	var purpose: int = _claim_purpose(project)
	refusal = _stage_inputs(project, job, purpose)
	if refusal != &"":
		return _refuse(refusal)
	var mass: int = project_output_mass_g(project)
	if mass < 0:
		return _refuse(REFUSE_ITEM)
	if mass > 0:
		refusal = output_placement_refusal(output)
		if refusal != &"":
			return _refuse(refusal)
	var consumed: Inventory.OpResult = _consume_inputs(project, job, purpose, now_tick, output, mass)
	if not consumed.ok:
		return consumed
	_publish_wip(project, output, mass)
	return Inventory.OpResult.new(true, &"", project, _s_count)


func _consume_inputs(project: Vector2i, job: Vector2i, purpose: int,
		now_tick: int, output: Vector2i, mass: int) -> Inventory.OpResult:
	"""Guarded settlement brackets the exact owner call, not earlier bill observations."""
	if not _construction.purpose_into(project, _math):
		return _refuse(REFUSE_WIP)
	var excavation: bool = _math.value == Construction.PURPOSE_EXCAVATION
	if not excavation and _math.value != Construction.PURPOSE_CONNECTOR_INSTALL:
		return _pool.consume_job_inputs(job, purpose, now_tick, output, mass, _inventory)
	if _settling_project != project or _settling_job != NULL_REF:
		return _refuse(REFUSE_WIP)
	_settling_job = job
	var result: Inventory.OpResult
	if excavation:
		result = _pool.consume_excavation_inputs(job, now_tick, output, mass,
			_inventory, _construction.excavation_authority(), project)
	else:
		result = _pool.consume_connector_inputs(job, now_tick, output, mass,
			_inventory, _construction.modular_authority(), project)
	_settling_job = NULL_REF
	return result


func is_settling_connector_inputs(project: Vector2i, job: Vector2i,
		inventory: Inventory, pool: Reservations) -> bool:
	"""Exact original input scope only; a prepayment Recipe callback cannot manufacture this bracket."""
	return _ready_error == &"" and project != NULL_REF and job != NULL_REF \
		and _settling_project == project and _settling_job == job \
		and inventory == _inventory and pool == _pool


func _start_refusal(project: Vector2i, job: Vector2i) -> StringName:
	"""Do not publish receipts against a wrong phase, reused owner, or external transaction."""
	if _ready_error != &"":
		return REFUSE_RECEIPTS
	if _owner_mutation_refusal(project, Contract.ACTION_WIP) != &"":
		return Construction.REFUSE_COORDINATOR_ONLY
	if _inventory.is_transaction_open():
		return Inventory.REFUSE_TRANSACTION_OPEN
	if _project_row(project) == NO_ROW or _claim_purpose(project) < 0 or is_funded(project):
		return REFUSE_WIP
	if not _construction.phase_into(project, _math) or _math.value != Construction.PHASE_READY:
		return REFUSE_WIP
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if job.x < 0 or job.x >= _pool.job_capacity() or job.y <= 0:
		return Reservations.REFUSE_JOB_OUT_OF_RANGE
	return &""


func _stage_inputs(project: Vector2i, job: Vector2i, purpose: int) -> StringName:
	"""Read all matching claims in their canonical pool order and prove the exact full bill."""
	_s_count = 0
	_s_totals.fill(0)
	var container: Vector2i = _construction.material_container_ref_of(project)
	var row: int = _pool.first_job_row(job)
	while row != Reservations.NULL_ROW:
		if not _pool.row_purpose_into(row, _math):
			return REFUSE_INPUTS
		if _math.value != purpose:
			return REFUSE_INPUTS
		var code: StringName = _stage_one(row, container)
		if code != &"":
			return code
		row = _pool.next_job_row(row)
	return _exact_bill_refusal(project)


func _stage_one(claim: int, container: Vector2i) -> StringName:
	"""Copy metadata before consumption can retire the source lot and reuse its identity."""
	if _s_count >= _free_count:
		return REFUSE_RECEIPTS
	var lot: Vector2i = _pool.row_lot_ref(claim)
	if not _inventory.is_lot_valid(lot) or _inventory.lot_container(lot) != container:
		return REFUSE_INPUTS
	var item: int = _inventory.lot_item_id(lot)
	var quantity: int = _pool.row_quantity_milli(claim)
	_s_item[_s_count] = item
	_s_quality[_s_count] = _inventory.lot_quality(lot)
	_s_provenance[_s_count] = _inventory.lot_provenance(lot)
	_s_recipe[_s_count] = _inventory.lot_recipe_id(lot)
	_s_quantity[_s_count] = quantity
	_s_age[_s_count] = _inventory.lot_age_milli_hours(lot)
	_s_remainder[_s_count] = _inventory.lot_age_remainder(lot)
	if not IntMath.checked_add_into(_s_totals[item], quantity, _math):
		return Inventory.REFUSE_OVERFLOW
	_s_totals[item] = _math.value
	_s_count += 1
	return &""


func _exact_bill_refusal(project: Vector2i) -> StringName:
	"""Every physical claim equals the immutable full bill and delivered ledger, including extras."""
	_s_returned.fill(0)
	if not _construction.project_bill_size_into(project, _math):
		return REFUSE_WIP
	var count: int = _math.value
	for line: int in count:
		var item: int = _items.compiled_id(_construction.project_material_key_at(project, line))
		if item < 0 or not _inventory.is_item_registered(item):
			return REFUSE_ITEM
		if not _construction.project_required_milli_into(project, line, _math):
			return REFUSE_WIP
		_s_returned[item] = _math.value
		if not _construction.delivered_milli_into(project, line, _math) or _math.value != _s_totals[item]:
			return REFUSE_INPUTS
	for item: int in Inventory.ITEM_CAPACITY:
		if _s_totals[item] != _s_returned[item]:
			return REFUSE_INPUTS
	return &""


func _publish_wip(project: Vector2i, output: Vector2i, mass: int) -> void:
	"""Publish only after the actual consumed quantities and output claim have committed."""
	var row: int = _project_row(project)
	_project_slot[row] = project.x
	_project_generation[row] = project.y
	_output_slot[row] = output.x
	_output_generation[row] = output.y
	_output_mass_g[row] = mass
	var tail: int = NO_ROW
	for index: int in _s_count:
		_free_count -= 1
		var receipt: int = _free[_free_count]
		_copy_staged_receipt(index, receipt)
		if tail == NO_ROW:
			_head[row] = receipt
		else:
			_r_next[tail] = receipt
		tail = receipt


func _copy_staged_receipt(source: int, receipt: int) -> void:
	"""Copy one fully staged SoA receipt with no remaining failing or allocating operations."""
	_r_next[receipt] = NO_ROW
	_r_item[receipt] = _s_item[source]
	_r_quality[receipt] = _s_quality[source]
	_r_provenance[receipt] = _s_provenance[source]
	_r_recipe[receipt] = _s_recipe[source]
	_r_quantity[receipt] = _s_quantity[source]
	_r_age[receipt] = _s_age[source]
	_r_remainder[receipt] = _s_remainder[source]


func output_mass_g(operation: int) -> int:
	"""Exact per-lot rounded inventory mass for the adopted operation outputs, or refusal -1."""
	if operation == Contract.OP_CUT:
		return _mass(&"excavated_earth", Contract.EARTH_MILLI)
	if operation == Contract.OP_BACKFILL_CLOSE or operation == Contract.OP_UNOPENED_SUPPORT_CLOSE:
		var wood: int = _mass(&"wood", Contract.SALVAGE_WOOD_MILLI)
		var stone: int = _mass(&"stone", Contract.SALVAGE_STONE_MILLI)
		return wood + stone if wood >= 0 and stone >= 0 else -1
	return 0 if Contract.valid_operation(operation) else -1


func project_output_mass_g(project: Vector2i) -> int:
	"""Reserve per-lot rounded real output mass from this exact immutable project contract."""
	if not _construction.purpose_into(project, _math):
		return -1
	if _math.value == Construction.PURPOSE_EXCAVATION:
		return output_mass_g(_operation(project))
	if _read_modular_quote(project) != &"":
		return -1
	var total: int = 0
	for index: int in _quote.output_count:
		var item: int = _quote.output_item[index]
		if not IntMath.checked_mul_into(_quote.output_milli[index], _inventory.item_mass_g(item), _math) \
				or not IntMath.ceil_div_into(_math.value, 1000, _math):
			return -1
		if not IntMath.checked_add_into(total, _math.value, _math):
			return -1
		total = _math.value
	return total


func _read_modular_quote(project: Vector2i) -> StringName:
	"""Fresh owner facts must match actual purpose/subject/op and the registered output catalog."""
	if not _construction.purpose_into(project, _math) or not Construction.is_modular(_math.value):
		return REFUSE_WIP
	var authority: ModularContract = _construction.modular_authority()
	if authority == null:
		return Construction.REFUSE_COORDINATOR_ONLY
	_quote.reset()
	var code: StringName = authority.project_facts_into(project, _quote)
	if code != &"" or _quote.refusal() != &"" or _quote.subject != _construction.subject_ref_of(project) \
			or not _construction.type_id_into(project, _math) or _math.value != _quote.operation:
		return REFUSE_WIP
	for index: int in _quote.output_count:
		var item: int = _quote.output_item[index]
		if not _inventory.is_item_registered(item) or _quote.output_age[index] > Inventory.MAX_AGE_MILLI_HOURS:
			return REFUSE_ITEM
		var provenance: Catalog.EnumLookup = Catalog.inventory_provenance_key_of(_quote.output_provenance[index])
		if not provenance.ok:
			return Inventory.REFUSE_INVALID_PROVENANCE
		if Catalog.PROVENANCE_REQUIRED_ITEM_KEY.has(String(provenance.key)):
			var key: StringName = StringName(Catalog.PROVENANCE_REQUIRED_ITEM_KEY[String(provenance.key)])
			if item != _items.compiled_id(key):
				return Inventory.REFUSE_INVALID_PROVENANCE
	return &""


func _mass(key: StringName, quantity: int) -> int:
	"""Resolve current authored item mass rather than duplicating the material catalog."""
	var item: int = _items.compiled_id(key)
	if item < 0 or not _inventory.is_item_registered(item):
		return -1
	if not IntMath.ceil_div_into(quantity * _inventory.item_mass_g(item), 1000, _math):
		return -1
	return _math.value


func _project_row(project: Vector2i) -> int:
	"""Validate the complete live Construction identity before indexing its typed row."""
	return _construction.directory().get_typed_row(project) if _construction.is_live_project(project) else NO_ROW


func _operation(project: Vector2i) -> int:
	"""Require an actual excavation purpose before interpreting the operation column."""
	if not _construction.purpose_into(project, _math) or _math.value != Construction.PURPOSE_EXCAVATION:
		return -1
	if not _construction.type_id_into(project, _math):
		return -1
	return _math.value if Contract.valid_operation(_math.value) else -1


func wip_milli(project: Vector2i, item: int) -> int:
	"""Read the remaining consumed input account; this is never loose Inventory stock."""
	if not is_funded(project):
		return 0
	var quantity: int = 0
	var row: int = _head[_project_row(project)]
	while row != NO_ROW:
		if _r_item[row] == item:
			quantity += _r_quantity[row]
		row = _r_next[row]
	return quantity


func refund_wip(project: Vector2i, destination: Vector2i, promotion_tile: int = -1) -> Inventory.OpResult:
	"""Return exact metadata-preserving refunds; blocked capacity retains every WIP receipt."""
	if _owner_mutation_refusal(project, Contract.ACTION_REFUND) != &"":
		return _refuse(Construction.REFUSE_COORDINATOR_ONLY)
	if not is_funded(project) or not _construction.phase_into(project, _math) \
			or _math.value != Construction.PHASE_REFUNDING:
		return _refuse(REFUSE_WIP)
	var code: StringName = _prepare_refund(project)
	if code != &"":
		return _refuse(code)
	if _has_returned_goods() and not _inventory.container_reachable(destination):
		return _refuse(Inventory.REFUSE_INVALID_CONTAINER)
	var opened: Inventory.OpResult = _inventory.begin()
	if not opened.ok:
		return opened
	code = _refund_and_finish_staging(project, destination, promotion_tile)
	if code != &"":
		_inventory.abort()
		return _refuse(code)
	var committed: Inventory.OpResult = _commit_guarded_transaction(project, ModularContract.ACTION_REFUND)
	if not committed.ok:
		return committed
	_publish_refund(project)
	return Inventory.OpResult.new(true, &"", project, 0)


func _has_returned_goods() -> bool:
	"""Material-free cancellation needs no invented destination capacity for nonexistent goods."""
	for quantity: int in _s_returned:
		if quantity > 0:
			return true
	return false


func _prepare_refund(project: Vector2i) -> StringName:
	"""Pin per-item totals to Construction's authored refund and preflight loss overflow."""
	_s_totals.fill(0)
	_s_returned.fill(0)
	_s_carry.fill(0)
	var domain: int = _loss_domain_of(project)
	if domain < 0 or not _construction.project_bill_size_into(project, _math):
		return REFUSE_WIP
	var count: int = _math.value
	for line: int in count:
		var item: int = _items.compiled_id(_construction.project_material_key_at(project, line))
		if item < 0 or not _inventory.is_item_registered(item):
			return REFUSE_ITEM
		if not _construction.cancellation_refund_milli_into(project, line, _math):
			return REFUSE_WIP
		_s_returned[item] = _math.value
		_s_totals[item] = wip_milli(project, item)
		if not _construction.delivered_milli_into(project, line, _math) \
				or _math.value != _s_totals[item] or _s_returned[item] > _s_totals[item]:
			return REFUSE_WIP
		var loss: int = _s_totals[item] - _s_returned[item]
		var previous: int = cancellation_loss_milli(item)
		if previous < 0 or not IntMath.checked_add_into(previous, loss, _math):
			return Inventory.REFUSE_OVERFLOW
		if not IntMath.checked_add_into(_lost_milli[domain * Inventory.ITEM_CAPACITY + item], loss, _math):
			return Inventory.REFUSE_OVERFLOW
		_s_totals[item] = loss
	return &""


func _refund_inventory(project: Vector2i, destination: Vector2i) -> StringName:
	"""Publish no rows until all returned lots and release of the owned output claim commit."""
	var code: StringName = _release_output(project)
	if code != &"":
		return code
	var numerator: int = 800 if _construction.has_work_begun(project) else 1000
	var row: int = _head[_project_row(project)]
	while row != NO_ROW:
		code = _return_receipt(row, destination, numerator)
		if code != &"":
			return code
		row = _r_next[row]
	for remaining: int in _s_returned:
		if remaining != 0:
			return REFUSE_WIP
	return &""


func _return_receipt(row: int, destination: Vector2i, numerator: int) -> StringName:
	"""Carry integer rounding per item in stable claim order, never floor every tiny lot away."""
	var item: int = _r_item[row]
	var scaled: int = _r_quantity[row] * numerator + _s_carry[item]
	@warning_ignore("integer_division") var quantity: int = scaled / 1000
	_s_carry[item] = scaled % 1000
	_s_returned[item] -= quantity
	if quantity == 0:
		return &""
	var made: Inventory.OpResult = _inventory.create_lot(destination, item, quantity,
		_r_quality[row], _r_provenance[row], _r_recipe[row], _r_age[row], _r_remainder[row])
	return &"" if made.ok else made.error


func _publish_refund(project: Vector2i) -> void:
	"""Publish preflighted loss once without a fallible bill/source callback after Inventory committed."""
	var domain: int = _loss_domain_of(project)
	for item: int in Inventory.ITEM_CAPACITY:
		_lost_milli[domain * Inventory.ITEM_CAPACITY + item] += _s_totals[item]
	_clear_wip(project)


func _finish_cancelled_staging(project: Vector2i, tile: int) -> StringName:
	"""Retire only an empty unreserved staging row; another project's capacity stays owned."""
	var output: Vector2i = output_container(project)
	var code: StringName = output_placement_refusal(output, tile)
	if code != &"" or output == NULL_REF:
		return code
	var spatial: bool = not _inventory.container_anchor_tile_into(output, _math)
	if not spatial and tile < 0 or _inventory.container_policy(output) == Inventory.POLICY_GROUND_PILE:
		return &""
	if _inventory.container_lot_count(output) > 0:
		return _promote_output(output, tile)
	if _inventory.container_reserved_mass_g(output) > 0:
		return &""
	var finished: Inventory.OpResult = _inventory.destroy_container(output)
	return &"" if finished.ok else finished.error


func _refund_and_finish_staging(project: Vector2i, destination: Vector2i, tile: int) -> StringName:
	"""Refund goods and endpoint publication share the output-release transaction and rollback."""
	var positive: bool = _has_returned_goods()
	var code: StringName = output_placement_refusal(destination) if positive else &""
	if code == &"":
		code = _refund_inventory(project, destination)
	if code == &"" and positive:
		code = _promote_output(destination, -1)
	return _finish_cancelled_staging(project, tile) if code == &"" else code


func output_placement_refusal(output: Vector2i, tile: int = -1) -> StringName:
	"""An unavailable multilevel endpoint never aliases a flat tile or an unplaced container."""
	if _ready_error != &"" or _inventory == null:
		return REFUSE_RECEIPTS
	if not Inventory.is_anchor_tile_in_domain(tile):
		return Inventory.REFUSE_INVALID_ANCHOR_TILE
	if output == NULL_REF:
		return &"" if tile == -1 else Inventory.REFUSE_INVALID_CONTAINER
	if _inventory.container_anchor_tile_into(output, _math):
		return &"" if tile < 0 or _math.value == tile else Inventory.REFUSE_GROUND_PILE_STAGING
	if _math.error != String(Inventory.REFUSE_SPATIAL_REQUIRED):
		return StringName(_math.error)
	if tile != -1:
		return Inventory.REFUSE_SPATIAL_REQUIRED
	if _inventory.spatial_location_of(output) == NULL_REF \
			or _inventory.spatial_location_revision_of(output) <= 0:
		return Inventory.REFUSE_SPATIAL_LOCATION
	return &""


func _promote_output(output: Vector2i, tile: int) -> StringName:
	"""Publish the actual nonempty endpoint in the current transaction, never caller coordinates."""
	var code: StringName = output_placement_refusal(output, tile)
	if code != &"" or output == NULL_REF:
		return code
	if _inventory.container_anchor_tile_into(output, _math):
		if tile < 0:
			return &""
		var surface: Inventory.OpResult = _inventory.promote_to_ground_pile(output, tile)
		return &"" if surface.ok else surface.error
	if _inventory.container_policy(output) == Inventory.POLICY_GROUND_PILE:
		return &""
	var location: Vector2i = _inventory.spatial_location_of(output)
	var spatial: Inventory.OpResult = _inventory.promote_to_spatial_ground_pile(output, location)
	return &"" if spatial.ok else spatial.error


func commit_outputs(project: Vector2i, cut_provenance: int,
		promotion_tile: int = -1) -> Inventory.OpResult:
	"""Settle work-ready phase outputs once; a refusal preserves funding and earned work."""
	var authority: Contract = _construction.excavation_authority()
	if authority == null or authority.mutation_refusal(project, Contract.ACTION_OUTPUT) != &"":
		return _refuse(Construction.REFUSE_COORDINATOR_ONLY)
	if not is_funded(project) or not _construction.phase_into(project, _math) \
			or _math.value != Construction.PHASE_WORK_DONE:
		return _refuse(REFUSE_WIP)
	var operation: int = _operation(project)
	if operation < 0:
		return _refuse(REFUSE_WIP)
	if operation == Contract.OP_CUT and cut_provenance != Catalog.PROVENANCE_EXCAVATION \
			and cut_provenance != Catalog.PROVENANCE_BACKFILL_RECLAIM:
		return _refuse(Inventory.REFUSE_INVALID_PROVENANCE)
	var opened: Inventory.OpResult = _inventory.begin()
	if not opened.ok:
		return opened
	var code: StringName = _output_inventory(project, operation, cut_provenance, promotion_tile)
	if code != &"":
		_inventory.abort()
		return _refuse(code)
	var committed: Inventory.OpResult = _commit_guarded_transaction(project, Contract.ACTION_OUTPUT)
	if not committed.ok:
		return committed
	_clear_wip(project)
	return Inventory.OpResult.new(true, &"", project, 0)


func commit_modular_outputs(project: Vector2i, promotion_tile: int = -1) -> Inventory.OpResult:
	"""Atomically settle actual router-priced outputs; blocked publication retains all paid WIP."""
	if _owner_mutation_refusal(project, ModularContract.ACTION_OUTPUT) != &"":
		return _refuse(Construction.REFUSE_COORDINATOR_ONLY)
	if not is_funded(project) or not _construction.phase_into(project, _math) \
			or _math.value != Construction.PHASE_WORK_DONE or _construction.is_paused(project):
		return _refuse(REFUSE_WIP)
	var code: StringName = _read_modular_quote(project)
	if code != &"":
		return _refuse(code)
	var mass: int = project_output_mass_g(project)
	if mass < 0 or mass != _output_mass_g[_project_row(project)] \
			or promotion_tile >= 0 and _quote.output_count == 0:
		return _refuse(REFUSE_WIP)
	var opened: Inventory.OpResult = _inventory.begin()
	if not opened.ok:
		return opened
	code = _modular_output_inventory(project, promotion_tile)
	if code != &"":
		_inventory.abort()
		return _refuse(code)
	var committed: Inventory.OpResult = _commit_guarded_transaction(project, ModularContract.ACTION_OUTPUT)
	if not committed.ok:
		return committed
	_clear_wip(project)
	return Inventory.OpResult.new(true, &"", project, 0)


func _modular_output_inventory(project: Vector2i, promotion_tile: int) -> StringName:
	"""Post the bounded owner candidate inside the active Inventory journal, without clearing WIP."""
	var code: StringName = _release_output(project)
	for index: int in _quote.output_count:
		if code != &"":
			break
		var made: Inventory.OpResult = _inventory.create_lot(output_container(project),
			_quote.output_item[index], _quote.output_milli[index], _quote.output_quality[index],
			_quote.output_provenance[index], _quote.output_recipe[index], _quote.output_age[index],
			_quote.output_remainder[index])
		code = &"" if made.ok else made.error
	return _promote_output(output_container(project), promotion_tile) if code == &"" else code


func _output_inventory(project: Vector2i, operation: int, provenance: int, tile: int) -> StringName:
	"""Release only this phase's finite headroom, post adopted outputs and optionally promote."""
	var code: StringName = _release_output(project)
	if code != &"":
		return code
	var output: Vector2i = output_container(project)
	if operation == Contract.OP_CUT:
		code = _make_output(output, &"excavated_earth", Contract.EARTH_MILLI, provenance)
	elif operation == Contract.OP_BACKFILL_CLOSE or operation == Contract.OP_UNOPENED_SUPPORT_CLOSE:
		code = _make_output(output, &"wood", Contract.SALVAGE_WOOD_MILLI, Catalog.PROVENANCE_ORDINARY)
		if code == &"":
			code = _make_output(output, &"stone", Contract.SALVAGE_STONE_MILLI, Catalog.PROVENANCE_ORDINARY)
	return _promote_output(output, tile) if code == &"" else code


func _make_output(container: Vector2i, key: StringName, quantity: int, provenance: int) -> StringName:
	"""Create one adopted output with the established ordinary material/earth metadata."""
	var made: Inventory.OpResult = _inventory.create_lot(container, _items.compiled_id(key),
		quantity, int(Catalog.QUALITY["PLAIN"]), provenance, -1, 0, 0)
	return &"" if made.ok else made.error


func _release_output(project: Vector2i) -> StringName:
	"""Convert a real owned output reservation inside the surrounding Inventory transaction."""
	var row: int = _project_row(project)
	if _output_mass_g[row] == 0:
		return &""
	var released: Inventory.OpResult = _inventory.release_container_mass(output_container(project), _output_mass_g[row])
	return &"" if released.ok else released.error


func output_container(project: Vector2i) -> Vector2i:
	"""Read the actual output's full Inventory identity, with no fallback container."""
	if not is_funded(project):
		return NULL_REF
	var row: int = _project_row(project)
	return Vector2i(_output_slot[row], _output_generation[row])


func reserved_output_mass_g(project: Vector2i) -> int:
	"""Read this paid owner's retained mass in O(1); unavailable is never assumed zero output."""
	return _output_mass_g[_project_row(project)] if is_funded(project) else -1


func _clear_wip(project: Vector2i) -> void:
	"""Retire receipt rows only after their physical transition or returned goods committed."""
	var row: int = _project_row(project)
	var receipt: int = _head[row]
	while receipt != NO_ROW:
		var next: int = _r_next[receipt]
		_clear_receipt(receipt)
		_free[_free_count] = receipt
		_free_count += 1
		receipt = next
	_project_slot[row] = -1
	_project_generation[row] = 0
	_head[row] = -1
	_output_slot[row] = -1
	_output_generation[row] = 0
	_output_mass_g[row] = 0


func _clear_receipt(row: int) -> void:
	"""Canonicalize a retired receipt so no source metadata leaks into a reused owner."""
	_r_next[row] = -1
	_r_item[row] = 0
	_r_quality[row] = 0
	_r_provenance[row] = 0
	_r_recipe[row] = 0
	_r_quantity[row] = 0
	_r_age[row] = 0
	_r_remainder[row] = 0


func cancellation_loss_milli(item: int) -> int:
	"""Physical per-item loss, independent of generic Inventory source/sink bookkeeping."""
	if item < 0 or item >= Inventory.ITEM_CAPACITY or _ready_error != &"":
		return 0
	var total: int = 0
	for domain: int in LOSS_DOMAIN_COUNT:
		if not IntMath.checked_add_into(total, _lost_milli[domain * Inventory.ITEM_CAPACITY + item], _math):
			return -1
		total = _math.value
	return total


func purpose_cancellation_loss_milli(purpose: int, item: int) -> int:
	"""Cold purpose-qualified historical sink, independent of retired Construction rows."""
	var domain: int = _loss_domain(purpose)
	if _ready_error != &"" or domain < 0 or item < 0 or item >= Inventory.ITEM_CAPACITY:
		return -1
	return _lost_milli[domain * Inventory.ITEM_CAPACITY + item]


func purpose_wip_milli(purpose: int, item: int) -> int:
	"""Cold conservation query over actual full project generations, never a tick-path scan."""
	if _ready_error != &"" or _loss_domain(purpose) < 0 or item < 0 or item >= Inventory.ITEM_CAPACITY:
		return -1
	var total: int = 0
	for row: int in Construction.CONSTRUCTION_CAPACITY:
		if _project_slot[row] < 0:
			continue
		var project: Vector2i = Vector2i(_project_slot[row], _project_generation[row])
		if not _construction.purpose_into(project, _math):
			return -1
		if _math.value == purpose:
			if not IntMath.checked_add_into(total, wip_milli(project, item), _math):
				return -1
			total = _math.value
	return total


func total_wip_milli(item: int) -> int:
	"""Cold conservation query; cleared receipts have zero quantities and cannot count twice."""
	var total: int = 0
	for row: int in _capacity:
		if _r_item[row] == item:
			total += _r_quantity[row]
	return total


func state_bytes() -> PackedByteArray:
	"""Local canonical accounting image for refusal/retry tests; not a production save codec."""
	var out: PackedByteArray = PackedInt64Array([_capacity, _free_count]).to_byte_array()
	for column: PackedInt32Array in [_free, _project_slot, _project_generation, _head,
			_output_slot, _output_generation, _r_next, _r_item, _r_quality, _r_provenance, _r_recipe]:
		out.append_array(column.to_byte_array())
	for column: PackedInt64Array in [_output_mass_g, _r_quantity, _r_age, _r_remainder, _lost_milli]:
		out.append_array(column.to_byte_array())
	return out


func _refuse(code: StringName) -> Inventory.OpResult:
	"""Use the actual inventory transaction result shape throughout the composed boundary."""
	return Inventory.OpResult.new(false, code, NULL_REF, 0)


# --- ADR 1228: section 6 owner `excavation_inventory` ---------------------------------------------

## Section 6 column count, in registry ordinal order.
const SAVE_COLUMN_COUNT: int = 18


func save_columns() -> Array:
	"""Copies of the eighteen registry columns in ordinal order; the free stack only up to its count."""
	return [PackedInt32Array([_capacity]), PackedInt32Array([_free_count]), _free.slice(0, _free_count),
		_project_slot.duplicate(), _project_generation.duplicate(), _head.duplicate(),
		_output_slot.duplicate(), _output_generation.duplicate(), _output_mass_g.duplicate(),
		_r_next.duplicate(), _r_item.duplicate(), _r_quality.duplicate(), _r_provenance.duplicate(),
		_r_recipe.duplicate(), _r_quantity.duplicate(), _r_age.duplicate(), _r_remainder.duplicate(),
		_lost_milli.duplicate()]


func restore_columns(columns: Array) -> bool:
	"""Install the columns after `columns_valid()`; false writes nothing. Scratch stays untouched."""
	if not columns_valid(columns):
		return false
	_free_count = (columns[1] as PackedInt32Array)[0]
	_free.fill(-1)
	for index: int in _free_count:
		_free[index] = (columns[2] as PackedInt32Array)[index]
	_install_project_columns(columns)
	_install_receipt_columns(columns)
	_lost_milli = (columns[17] as PackedInt64Array).duplicate()
	return true


func _install_project_columns(columns: Array) -> void:
	"""Private copies of the six project-indexed columns."""
	_project_slot = (columns[3] as PackedInt32Array).duplicate()
	_project_generation = (columns[4] as PackedInt32Array).duplicate()
	_head = (columns[5] as PackedInt32Array).duplicate()
	_output_slot = (columns[6] as PackedInt32Array).duplicate()
	_output_generation = (columns[7] as PackedInt32Array).duplicate()
	_output_mass_g = (columns[8] as PackedInt64Array).duplicate()


func _install_receipt_columns(columns: Array) -> void:
	"""Private copies of the eight receipt columns."""
	_r_next = (columns[9] as PackedInt32Array).duplicate()
	_r_item = (columns[10] as PackedInt32Array).duplicate()
	_r_quality = (columns[11] as PackedInt32Array).duplicate()
	_r_provenance = (columns[12] as PackedInt32Array).duplicate()
	_r_recipe = (columns[13] as PackedInt32Array).duplicate()
	_r_quantity = (columns[14] as PackedInt64Array).duplicate()
	_r_age = (columns[15] as PackedInt64Array).duplicate()
	_r_remainder = (columns[16] as PackedInt64Array).duplicate()


func columns_valid(columns: Array) -> bool:
	"""Types and extents against this composed owner, then free rows, project rows and chains."""
	if _ready_error != &"" or not _column_types_ok(columns):
		return false
	if (columns[0] as PackedInt32Array)[0] != _capacity:
		return false
	var free_count: int = (columns[1] as PackedInt32Array)[0]
	if free_count < 0 or free_count > _capacity or (columns[2] as PackedInt32Array).size() != free_count:
		return false
	for ordinal: int in range(3, 9):
		if columns[ordinal].size() != Construction.CONSTRUCTION_CAPACITY:
			return false
	for ordinal: int in range(9, 17):
		if columns[ordinal].size() != _capacity:
			return false
	if (columns[17] as PackedInt64Array).size() != LOSS_CELL_CAPACITY or not _nonnegative(columns[17]):
		return false
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(_capacity)
	return _free_rows_valid(columns, seen) and _project_rows_valid(columns, seen) and seen.count(0) == 0


static func _nonnegative(column: PackedInt64Array) -> bool:
	"""Every value is at least zero."""
	for value: int in column:
		if value < 0:
			return false
	return true


static func _column_types_ok(columns: Array) -> bool:
	"""Eighteen columns of the registry's packed types; both scalars one element."""
	if columns.size() != SAVE_COLUMN_COUNT:
		return false
	for ordinal: int in SAVE_COLUMN_COUNT:
		var wide: bool = ordinal == 8 or ordinal == 17 or (ordinal >= 14 and ordinal <= 16)
		if typeof(columns[ordinal]) != (TYPE_PACKED_INT64_ARRAY if wide else TYPE_PACKED_INT32_ARRAY):
			return false
	return columns[0].size() == 1 and columns[1].size() == 1


static func _free_rows_valid(columns: Array, seen: PackedByteArray) -> bool:
	"""Each free receipt is distinct, in range and canonically cleared."""
	for row: int in columns[2]:
		if row < 0 or row >= seen.size() or seen[row] == 1 or not _receipt_clear(columns, row):
			return false
		seen[row] = 1
	return true


static func _receipt_clear(columns: Array, row: int) -> bool:
	"""`_clear_receipt()`'s canon: no link, item metadata or quantity."""
	return columns[9][row] == -1 and columns[10][row] == 0 and columns[11][row] == 0 \
		and columns[12][row] == 0 and columns[13][row] == 0 and columns[14][row] == 0 \
		and columns[15][row] == 0 and columns[16][row] == 0


static func _project_rows_valid(columns: Array, seen: PackedByteArray) -> bool:
	"""A free project row is the clear row; a funded one owns an acyclic receipt chain."""
	for row: int in Construction.CONSTRUCTION_CAPACITY:
		var slot: int = columns[3][row]
		if slot == -1:
			if columns[4][row] != 0 or columns[5][row] != -1 or columns[6][row] != -1 \
					or columns[7][row] != 0 or columns[8][row] != 0:
				return false
			continue
		if slot < 0 or slot >= DirectoryScript.DIRECTORY_CAPACITY or columns[4][row] < 1 \
				or columns[8][row] < 0 or (columns[6][row] == -1) != (columns[7][row] == 0) \
				or not _chain_valid(columns, columns[5][row], seen):
			return false
	return true


static func _chain_valid(columns: Array, head: int, seen: PackedByteArray) -> bool:
	"""Walk one receipt chain: every row in range, not free, visited once, with a nonnegative quantity."""
	var receipt: int = head
	while receipt != NO_ROW:
		if receipt < 0 or receipt >= seen.size() or seen[receipt] == 1 or columns[14][receipt] < 0 \
				or columns[15][receipt] < 0 or columns[16][receipt] < 0:
			return false
		seen[receipt] = 1
		receipt = columns[9][receipt]
	return true
