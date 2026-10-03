extends RefCounted
## Paid excavation WIP receipts. Inventory owns loose goods; these columns own consumed inputs.
## Receipt capacity is an explicit world budget, never a room-size or input-lot truncation rule.
## All cold transactions either publish the entire receipt/account change or none of it.

const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const NO_ROW: int = -1
const REFUSE_WIP: StringName = &"EXCAVATION_WIP_STATE"
const REFUSE_RECEIPTS: StringName = &"CAPACITY_EXCAVATION_RECEIPTS"
const REFUSE_INPUTS: StringName = &"EXCAVATION_INPUT_OWNERSHIP"
const REFUSE_ITEM: StringName = &"EXCAVATION_ITEM_CATALOG"

var _construction: Construction = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _capacity: int = 0
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


func _init(construction: Construction, inventory: Inventory, pool: Reservations,
		items: Items, receipt_capacity: int) -> void:
	"""Allocate the declared world receipt budget; no hidden per-phase lot limit is introduced."""
	_construction = construction
	_inventory = inventory
	_pool = pool
	_items = items
	_capacity = maxi(0, receipt_capacity)
	_free_count = _capacity
	_allocate_projects()
	_allocate_receipts()
	_allocate_scratch()
	_lost_milli.resize(Inventory.ITEM_CAPACITY)
	for row: int in _capacity:
		_free[row] = _capacity - row - 1


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
	var row: int = _project_row(project)
	return row != NO_ROW and _project_slot[row] == project.x and _project_generation[row] == project.y


func consume_to_wip(project: Vector2i, job: Vector2i, now_tick: int,
		output: Vector2i) -> Inventory.OpResult:
	"""Capture actual owned delivered inputs, consume once, and reserve the operation's output."""
	var refusal: StringName = _start_refusal(project, job)
	if refusal != &"":
		return _refuse(refusal)
	var operation: int = _operation(project)
	refusal = _stage_inputs(project, job, operation)
	if refusal != &"":
		return _refuse(refusal)
	var mass: int = output_mass_g(operation)
	if mass < 0:
		return _refuse(REFUSE_ITEM)
	var consumed: Inventory.OpResult = _pool.consume_job_inputs(job,
		Reservations.PURPOSE_EXCAVATION_INPUT, now_tick, output, mass, _inventory)
	if not consumed.ok:
		return consumed
	_publish_wip(project, output, mass)
	return Inventory.OpResult.new(true, &"", project, _s_count)


func _start_refusal(project: Vector2i, job: Vector2i) -> StringName:
	"""Do not publish receipts against a wrong phase, reused owner, or external transaction."""
	var authority: Contract = _construction.excavation_authority()
	if authority == null or authority.mutation_refusal(project, Contract.ACTION_WIP) != &"":
		return Construction.REFUSE_COORDINATOR_ONLY
	if _capacity <= 0:
		return REFUSE_RECEIPTS
	if _inventory.is_transaction_open():
		return Inventory.REFUSE_TRANSACTION_OPEN
	if _project_row(project) == NO_ROW or _operation(project) < 0 or is_funded(project):
		return REFUSE_WIP
	if not _construction.phase_into(project, _math) or _math.value != Construction.PHASE_READY:
		return REFUSE_WIP
	if _construction.is_paused(project):
		return Construction.REFUSE_PAUSED
	if job.x < 0 or job.x >= _pool.job_capacity() or job.y <= 0:
		return Reservations.REFUSE_JOB_OUT_OF_RANGE
	return &""


func _stage_inputs(project: Vector2i, job: Vector2i, operation: int) -> StringName:
	"""Read all matching claims in their canonical pool order and prove the exact full bill."""
	_s_count = 0
	_s_totals.fill(0)
	var container: Vector2i = _construction.material_container_ref_of(project)
	var row: int = _pool.first_job_row(job)
	while row != Reservations.NULL_ROW:
		if not _pool.row_purpose_into(row, _math):
			return REFUSE_INPUTS
		if _math.value != Reservations.PURPOSE_EXCAVATION_INPUT:
			return REFUSE_INPUTS
		var code: StringName = _stage_one(row, container)
		if code != &"":
			return code
		row = _pool.next_job_row(row)
	return _exact_bill_refusal(project, operation)


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


func _exact_bill_refusal(project: Vector2i, operation: int) -> StringName:
	"""The physical claim totals must equal both the authored bill and Construction deliveries."""
	var first: int = -1
	var second: int = -1
	for line: int in Contract.input_count(operation):
		var item: int = _items.compiled_id(Contract.input_key(operation, line))
		if item < 0 or not _inventory.is_item_registered(item):
			return REFUSE_ITEM
		if _s_totals[item] != Contract.input_milli(operation, line):
			return REFUSE_INPUTS
		if not _construction.delivered_milli_into(project, line, _math) or _math.value != _s_totals[item]:
			return REFUSE_INPUTS
		if first == -1:
			first = item
		else:
			second = item
	for item: int in Inventory.ITEM_CAPACITY:
		if item != first and item != second and _s_totals[item] != 0:
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
	var authority: Contract = _construction.excavation_authority()
	if authority == null or authority.mutation_refusal(project, Contract.ACTION_REFUND) != &"":
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
	code = _refund_inventory(project, destination)
	if code == &"" and promotion_tile >= 0:
		code = _finish_cancelled_staging(project, promotion_tile)
	if code != &"":
		_inventory.abort()
		return _refuse(code)
	var committed: Inventory.OpResult = _inventory.commit()
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
	var operation: int = _operation(project)
	for line: int in Contract.input_count(operation):
		var item: int = _items.compiled_id(Contract.input_key(operation, line))
		if not _construction.cancellation_refund_milli_into(project, line, _math):
			return REFUSE_WIP
		_s_returned[item] = _math.value
		_s_totals[item] = wip_milli(project, item)
		if not _construction.delivered_milli_into(project, line, _math) \
				or _math.value != _s_totals[item] or _s_returned[item] > _s_totals[item]:
			return REFUSE_WIP
		if not IntMath.checked_add_into(_lost_milli[item], _s_totals[item] - _s_returned[item], _math):
			return Inventory.REFUSE_OVERFLOW
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
	"""Book cancellation loss only once, after exact returned goods committed."""
	var operation: int = _operation(project)
	for line: int in Contract.input_count(operation):
		var item: int = _items.compiled_id(Contract.input_key(operation, line))
		_construction.cancellation_refund_milli_into(project, line, _math)
		_lost_milli[item] += _s_totals[item] - _math.value
	_clear_wip(project)


func _finish_cancelled_staging(project: Vector2i, tile: int) -> StringName:
	"""Cancel the real pending output row, or publish refunded goods there as a nonempty pile."""
	var output: Vector2i = output_container(project)
	var finished: Inventory.OpResult = _inventory.destroy_container(output) \
		if _inventory.container_lot_count(output) == 0 else _inventory.promote_to_ground_pile(output, tile)
	return &"" if finished.ok else finished.error


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
	var committed: Inventory.OpResult = _inventory.commit()
	if not committed.ok:
		return committed
	_clear_wip(project)
	return Inventory.OpResult.new(true, &"", project, 0)


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
	if code == &"" and tile >= 0:
		var promoted: Inventory.OpResult = _inventory.promote_to_ground_pile(output, tile)
		code = &"" if promoted.ok else promoted.error
	return code


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
	return _lost_milli[item] if item >= 0 and item < Inventory.ITEM_CAPACITY else 0


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
