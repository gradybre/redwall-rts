extends RefCounted
## ECON-002/004/005 tip source ledger. Local handles are not Directory EntityRefs.
## Only the bound real modular-operation publisher may commit physical state.
## The operation bridge owns actual work, shared Funding, hauling and spatial proof.

const Directory := preload("res://scripts/core/entity_directory.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Work := preload("res://scripts/core/work.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const WorldInit := preload("res://scripts/core/world_init.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const MAX_CAPACITY: int = WorldInit.TILE_COUNT
const CAPACITY_G: int = 400000
## Adopted excavated_earth mass is 1000g/U, so integer milli-U equals grams.
const MAX_QUANTITY_MILLI: int = CAPACITY_G
const FIXED_WORK_MWU: int = 4000
const I32_MAX: int = 2147483647
const CLOSE: int = 0
const COMPACT: int = 1
const PREPARE: int = 2
const RECLAIM: int = 3
const OP_COUNT: int = 4
const ADMIT: int = 0
const CANCEL: int = 1
const COMMIT: int = 2
const PRODUCTIVE: int = 3
const REFUSE_BINDING: StringName = &"SPOIL_OPERATION_OWNER_UNBOUND"
const REFUSE_TIP: StringName = &"SPOIL_TIP_IDENTITY"
const REFUSE_CAPACITY: StringName = &"SPOIL_TIP_CAPACITY"
const REFUSE_CONTRACT: StringName = &"SPOIL_RETAINED_CONTRACT_MISMATCH"
const REFUSE_BUSY: StringName = &"SPOIL_TIP_OPERATION_ACTIVE"
const REFUSE_PHASE: StringName = &"SPOIL_TIP_PHASE"
const REFUSE_QUANTITY: StringName = &"SPOIL_TIP_QUANTITY"
const REFUSE_PROGRESS: StringName = &"SPOIL_TIP_WORK_IDENTITY"
const REFUSE_CODEC: StringName = &"SPOIL_VERSIONED_CODEC_REQUIRED"

class Publisher extends RefCounted:
	## A cold component fixture may implement this interface explicitly; production requires
	## the actual SpoilWork/router/Funding transaction, never a UI callback or caller boolean.
	func exact_binding(_owner: RefCounted, _world: Vector2i,
			_construction: Construction) -> bool:
		"""Prove the actual ledger and World/Construction composition."""
		return false

	func project_refusal(_tip: Vector2i, _project: Vector2i,
			_operation: int, _quantity_milli: int) -> StringName:
		"""Prove purpose-specific subject, immutable bill and exact operation ownership."""
		return REFUSE_BINDING

	func publication_refusal(_tip: Vector2i, _project: Vector2i,
			_operation: int, _quantity_milli: int, _action: int) -> StringName:
		"""Attest only the exact synchronous actual work or Inventory publication window."""
		return REFUSE_BINDING

var _construction: Construction = null
var _directory: Directory = null
var _publisher: WeakRef = null
var _world: Vector2i = NULL_REF
var _capacity: int = 0
var _free_count: int = 0
var _count: int = 0
var _compacted_milli: int = 0
var _reclaimed_milli: int = 0
var _ready_error: StringName = REFUSE_BINDING
var _present: PackedByteArray = PackedByteArray()
var _retired: PackedByteArray = PackedByteArray()
var _prepared: PackedByteArray = PackedByteArray()
var _generation: PackedInt32Array = PackedInt32Array()
var _tile: PackedInt32Array = PackedInt32Array()
var _project_slot: PackedInt32Array = PackedInt32Array()
var _project_generation: PackedInt32Array = PackedInt32Array()
var _operation: PackedInt32Array = PackedInt32Array()
var _embedded_milli: PackedInt64Array = PackedInt64Array()
var _quantity_milli: PackedInt64Array = PackedInt64Array()
var _locked_milli: PackedInt64Array = PackedInt64Array()
var _incoming_milli: PackedInt64Array = PackedInt64Array()
var _earned_mwu: PackedInt64Array = PackedInt64Array()
var _retained_quantity: PackedInt64Array = PackedInt64Array()
var _free_heap: PackedInt32Array = PackedInt32Array()
var _tile_row: PackedInt32Array = PackedInt32Array()
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init(construction: Construction, world: Vector2i, capacity: int) -> void:
	"""Allocate only an explicit finite owner arena in the actual live World namespace."""
	if construction == null or capacity < 1 or capacity > MAX_CAPACITY:
		return
	var directory: Directory = construction.directory()
	if directory == null or not directory.is_valid_of_kind(world, Directory.KIND_WORLD):
		return
	_construction = construction
	_directory = directory
	_world = world
	_capacity = capacity
	_allocate()
	_ready_error = &""


func _allocate() -> void:
	"""Allocate the reviewed 103C persistent and 4C+65536 derived packed bytes once."""
	_present.resize(_capacity)
	_retired.resize(_capacity)
	_prepared.resize(_capacity)
	_generation.resize(_capacity)
	_tile.resize(_capacity)
	_project_slot.resize(_capacity)
	_project_generation.resize(_capacity)
	_operation.resize(_capacity)
	_embedded_milli.resize(_capacity)
	_quantity_milli.resize(_capacity)
	_locked_milli.resize(_capacity)
	_incoming_milli.resize(_capacity)
	_earned_mwu.resize(_capacity * OP_COUNT)
	_retained_quantity.resize(_capacity * 2)
	_free_heap.resize(_capacity)
	_tile_row.resize(MAX_CAPACITY)
	_tile.fill(-1)
	_project_slot.fill(-1)
	_operation.fill(-1)
	_tile_row.fill(-1)
	_free_count = _capacity
	for row: int in _capacity:
		_free_heap[row] = row


func initialization_refusal() -> StringName:
	"""Successful arena creation still requires the real operation publisher to bind."""
	return _ready_error


func publisher_binding_refusal(publisher: Publisher) -> StringName:
	"""Preflight a once-bound actual owner without publishing half of a composed binding."""
	if _ready_error != &"" or publisher == null \
			or not publisher.exact_binding(self, _world, _construction):
		return REFUSE_BINDING
	if _publisher != null and _publisher.get_ref() != publisher:
		return REFUSE_BINDING
	return &""


func bind_publisher(publisher: Publisher) -> StringName:
	"""Bind one actual owner weakly; expired or foreign bindings cannot be replaced."""
	var code: StringName = publisher_binding_refusal(publisher)
	if code != &"":
		return code
	_publisher = weakref(publisher)
	return &""


func _bound_publisher() -> Publisher:
	"""Recheck World liveness and exact owner composition at every mutating boundary."""
	if _ready_error != &"" or _construction.directory() != _directory \
			or not _directory.is_valid_of_kind(_world, Directory.KIND_WORLD):
		return null
	var publisher: Publisher = _publisher.get_ref() as Publisher if _publisher != null else null
	return publisher if publisher != null and publisher.exact_binding(self, _world, _construction) else null


func is_live_tip(tip: Vector2i) -> bool:
	"""Local generation and actual World both qualify a tip; slots alone never do."""
	return _ready_error == &"" and _directory.is_valid_of_kind(_world, Directory.KIND_WORLD) \
		and tip.x >= 0 and tip.x < _capacity and _present[tip.x] == 1 \
		and tip.y > 0 and _generation[tip.x] == tip.y


func candidate_tip_ref() -> Vector2i:
	"""Cold allocation preview only; publish must revalidate the full candidate before writing."""
	if _bound_publisher() == null or _free_count < 1:
		return NULL_REF
	var row: int = _free_heap[0]
	if row < 0 or row >= _capacity or _present[row] != 0 or _retired[row] != 0 \
			or _generation[row] < 0 or _generation[row] >= I32_MAX:
		return NULL_REF
	return Vector2i(row, _generation[row] + 1)


func tip_at(tile: int) -> Vector2i:
	"""Resolve one actual exterior tile through its derived index with reverse validation."""
	if _ready_error != &"" or tile < 0 or tile >= MAX_CAPACITY:
		return NULL_REF
	var row: int = _tile_row[tile]
	if row < 0 or row >= _capacity or _tile[row] != tile:
		return NULL_REF
	var tip: Vector2i = Vector2i(row, _generation[row])
	return tip if is_live_tip(tip) else NULL_REF


static func total_work_mwu(operation: int, quantity: int) -> int:
	"""Borrow Work's adopted rational tip prices; quantities are milli-U, never whole units."""
	if operation == PREPARE or operation == CLOSE:
		return FIXED_WORK_MWU if quantity == 0 else -1
	if quantity < 1 or quantity > MAX_QUANTITY_MILLI:
		return -1
	var denominator: int = Work.TIP_COMPACT_MWU_DENOMINATOR if operation == COMPACT \
		else Work.TIP_RECLAIM_MWU_DENOMINATOR
	var numerator: int = Work.TIP_COMPACT_MWU_NUMERATOR if operation == COMPACT \
		else Work.TIP_RECLAIM_MWU_NUMERATOR
	if operation != COMPACT and operation != RECLAIM:
		return -1
	@warning_ignore("integer_division")
	return (quantity * numerator + denominator - 1) / denominator


func candidate_prepare_refusal(tile: int) -> StringName:
	"""Check physical admission before allocating Construction; this grants no publication permission."""
	var tip: Vector2i = candidate_tip_ref()
	if tip == NULL_REF:
		return REFUSE_CAPACITY if _bound_publisher() != null else REFUSE_BINDING
	if tile < 0 or tile >= MAX_CAPACITY or _tile_row[tile] != -1:
		return REFUSE_TIP
	return &""


func prepare_order_refusal(tile: int, project: Vector2i) -> StringName:
	"""Revalidate physical admission and the actual allocated project before first designation."""
	var code: StringName = candidate_prepare_refusal(tile)
	if code == &"":
		code = _project_refusal(candidate_tip_ref(), project, PREPARE, 0)
	return _admission_progress_refusal(project, FIXED_WORK_MWU, 0) if code == &"" else code


func publish_prepare_order(tile: int, project: Vector2i) -> StringName:
	"""Publish only this exact admitted footprint after the operation owner completes preflight."""
	var code: StringName = prepare_order_refusal(tile, project)
	if code != &"":
		return code
	var tip: Vector2i = candidate_tip_ref()
	code = _publication_refusal(tip, project, PREPARE, 0, ADMIT)
	if code != &"":
		return code
	var row: int = _pop_free()
	assert(row == tip.x, "the synchronous allocation preflight must remain exact")
	_generation[row] = tip.y
	_present[row] = 1
	_tile[row] = tile
	_tile_row[tile] = row
	_count += 1
	_write_order(row, project, PREPARE, 0)
	return &""


func candidate_order_refusal(tip: Vector2i, operation: int, quantity: int) -> StringName:
	"""Validate phase, source and retained q before a real project exists, without reserving stock."""
	if _bound_publisher() == null:
		return REFUSE_BINDING
	if not is_live_tip(tip):
		return REFUSE_TIP
	if _project(tip.x) != NULL_REF:
		return REFUSE_BUSY
	return _operation_refusal(tip.x, operation, quantity)


func order_refusal(tip: Vector2i, project: Vector2i, operation: int, quantity: int) -> StringName:
	"""Revalidate physical claims and the exact real project before any source reservation."""
	var code: StringName = candidate_order_refusal(tip, operation, quantity)
	if code == &"":
		code = _project_refusal(tip, project, operation, quantity)
	if code != &"":
		return code
	return _admission_progress_refusal(project, total_work_mwu(operation, quantity),
		_earned_mwu[tip.x * OP_COUNT + operation])


func _admission_progress_refusal(project: Vector2i, total: int, earned: int) -> StringName:
	"""A new real project must inherit exactly this tip's retained work, not start a fresh counter."""
	if not _construction.remaining_mwu_into(project, _math):
		return REFUSE_PROGRESS
	return &"" if _math.value == total - earned else REFUSE_PROGRESS


func _operation_refusal(row: int, operation: int, quantity: int) -> StringName:
	"""Every permitted operation has an adopted nonnegative price and physically valid source."""
	if total_work_mwu(operation, quantity) < 0:
		return REFUSE_QUANTITY
	if operation == PREPARE:
		return &"" if _prepared[row] == 0 else REFUSE_PHASE
	if operation == CLOSE:
		return &"" if _embedded_milli[row] == 0 else REFUSE_PHASE
	if _prepared[row] != 1:
		return REFUSE_PHASE
	var index: int = _quantity_index(row, operation)
	if _retained_quantity[index] != 0 and _retained_quantity[index] != quantity:
		return REFUSE_CONTRACT
	if operation == COMPACT and quantity > MAX_QUANTITY_MILLI - _embedded_milli[row]:
		return REFUSE_CAPACITY
	if operation == RECLAIM and quantity > _embedded_milli[row]:
		return REFUSE_QUANTITY
	return &""


func publish_order(tip: Vector2i, project: Vector2i, operation: int, quantity: int) -> StringName:
	"""Pin the accepted project/q and its complete source or incoming reservation together."""
	var code: StringName = order_refusal(tip, project, operation, quantity)
	if code != &"":
		return code
	code = _publication_refusal(tip, project, operation, quantity, ADMIT)
	if code != &"":
		return code
	_write_order(tip.x, project, operation, quantity)
	return &""


func _write_order(row: int, project: Vector2i, operation: int, quantity: int) -> void:
	"""All predicates and capacities have already succeeded; no callback follows these writes."""
	_project_slot[row] = project.x
	_project_generation[row] = project.y
	_operation[row] = operation
	_quantity_milli[row] = quantity
	_locked_milli[row] = quantity if operation == RECLAIM else 0
	_incoming_milli[row] = quantity if operation == COMPACT else 0
	if operation == COMPACT or operation == RECLAIM:
		_retained_quantity[_quantity_index(row, operation)] = quantity


func work_refusal(tip: Vector2i, project: Vector2i) -> StringName:
	"""Read actual Construction progress and reject regression or a wrong project generation."""
	var code: StringName = _active_refusal(tip, project)
	if code != &"":
		return code
	if not _construction.remaining_mwu_into(project, _math):
		return REFUSE_PROGRESS
	var total: int = total_work_mwu(_operation[tip.x], _quantity_milli[tip.x])
	var earned: int = total - _math.value
	return &"" if _math.value >= 0 and earned >= _earned_mwu[tip.x * OP_COUNT + _operation[tip.x]] \
		and earned <= total else REFUSE_PROGRESS


func publish_work(tip: Vector2i, project: Vector2i) -> StringName:
	"""Accept only a same-stack real Work publication, with no caller-supplied WU amount."""
	var code: StringName = work_refusal(tip, project)
	if code != &"":
		return code
	code = _publication_refusal(tip, project, _operation[tip.x], _quantity_milli[tip.x], PRODUCTIVE)
	if code != &"":
		return code
	_construction.remaining_mwu_into(project, _math)
	_earned_mwu[tip.x * OP_COUNT + _operation[tip.x]] = total_work_mwu(
		_operation[tip.x], _quantity_milli[tip.x]) - _math.value
	return &""


func completion_refusal(tip: Vector2i, project: Vector2i) -> StringName:
	"""Validate the exact no-fail source publication before any actual Inventory commit."""
	var code: StringName = work_refusal(tip, project)
	if code != &"":
		return code
	var row: int = tip.x
	if _math.value != 0 or _earned_mwu[row * OP_COUNT + _operation[row]] != total_work_mwu(
			_operation[row], _quantity_milli[row]):
		return REFUSE_PROGRESS
	if _operation[row] == CLOSE:
		return &"" if _embedded_milli[row] == 0 and _locked_milli[row] == 0 \
			and _incoming_milli[row] == 0 else REFUSE_PHASE
	if _operation[row] == COMPACT:
		if _incoming_milli[row] != _quantity_milli[row] or _quantity_milli[row] > MAX_QUANTITY_MILLI - _embedded_milli[row]:
			return REFUSE_CAPACITY
		return &"" if IntMath.checked_add_into(_compacted_milli, _quantity_milli[row], _math) else &"SPOIL_OVERFLOW"
	if _operation[row] == RECLAIM:
		if _locked_milli[row] != _quantity_milli[row] or _quantity_milli[row] > _embedded_milli[row]:
			return REFUSE_QUANTITY
		return &"" if IntMath.checked_add_into(_reclaimed_milli, _quantity_milli[row], _math) else &"SPOIL_OVERFLOW"
	return &""


func publish_completion(tip: Vector2i, project: Vector2i) -> StringName:
	"""Commit embedded source once, only after the real Inventory/WIP transaction succeeds."""
	var code: StringName = completion_refusal(tip, project)
	if code != &"":
		return code
	var row: int = tip.x
	code = _publication_refusal(tip, project, _operation[row], _quantity_milli[row], COMMIT)
	if code != &"":
		return code
	if _operation[row] == CLOSE:
		_retire(row)
		return &""
	if _operation[row] == PREPARE:
		_prepared[row] = 1
	elif _operation[row] == COMPACT:
		_embedded_milli[row] += _quantity_milli[row]
		_compacted_milli += _quantity_milli[row]
	else:
		_embedded_milli[row] -= _quantity_milli[row]
		_reclaimed_milli += _quantity_milli[row]
	_clear_retained(row, _operation[row])
	_clear_order(row)
	return &""


func cancellation_refusal(tip: Vector2i, project: Vector2i) -> StringName:
	"""Before any refund, all actual earned work must already be retained in the physical owner."""
	var code: StringName = work_refusal(tip, project)
	if code != &"":
		return code
	var total: int = total_work_mwu(_operation[tip.x], _quantity_milli[tip.x])
	return &"" if total - _math.value == _earned_mwu[tip.x * OP_COUNT + _operation[tip.x]] \
		else REFUSE_PROGRESS


func publish_cancellation(tip: Vector2i, project: Vector2i) -> StringName:
	"""A successful actual refund unlocks claims but never retires or erases the tip/source."""
	var code: StringName = cancellation_refusal(tip, project)
	if code != &"":
		return code
	code = _publication_refusal(tip, project, _operation[tip.x], _quantity_milli[tip.x], CANCEL)
	if code != &"":
		return code
	_clear_order(tip.x)
	return &""


func _active_refusal(tip: Vector2i, project: Vector2i) -> StringName:
	"""An active operation resolves all complete identities before indexing its immutable bill."""
	if not is_live_tip(tip) or _project(tip.x) != project or project == NULL_REF:
		return REFUSE_TIP
	return _project_refusal(tip, project, _operation[tip.x], _quantity_milli[tip.x])


func _project_refusal(tip: Vector2i, project: Vector2i, operation: int, quantity: int) -> StringName:
	"""The real project directory plus the typed purpose owner must agree on the same subject."""
	var publisher: Publisher = _bound_publisher()
	if publisher == null:
		return REFUSE_BINDING
	if not _construction.is_live_project(project):
		return REFUSE_TIP
	return publisher.project_refusal(tip, project, operation, quantity)


func _publication_refusal(tip: Vector2i, project: Vector2i, operation: int,
		quantity: int, action: int) -> StringName:
	"""No public setter can fabricate a paid transition by merely supplying valid-looking refs."""
	var publisher: Publisher = _bound_publisher()
	return publisher.publication_refusal(tip, project, operation, quantity, action) \
		if publisher != null else REFUSE_BINDING


func _clear_order(row: int) -> void:
	"""Release only the finished/cancelled operation; physical state and earned history survive."""
	_project_slot[row] = -1
	_project_generation[row] = 0
	_operation[row] = -1
	_quantity_milli[row] = 0
	_locked_milli[row] = 0
	_incoming_milli[row] = 0


func _clear_retained(row: int, operation: int) -> void:
	"""Only a successfully committed operation consumes its own retained work contract."""
	_earned_mwu[row * OP_COUNT + operation] = 0
	if operation == COMPACT or operation == RECLAIM:
		_retained_quantity[_quantity_index(row, operation)] = 0


func _retire(row: int) -> void:
	"""Paid empty closure releases the tile without changing any ecological soil-history owner."""
	_tile_row[_tile[row]] = -1
	_present[row] = 0
	_prepared[row] = 0
	_tile[row] = -1
	_count -= 1
	_clear_order(row)
	for operation: int in OP_COUNT:
		_clear_retained(row, operation)
	if _generation[row] == I32_MAX:
		_retired[row] = 1
	else:
		_push_free(row)


static func _quantity_index(row: int, operation: int) -> int:
	"""Two distinct variable-q contracts, never shared between compaction and reclamation."""
	return row * 2 + (0 if operation == COMPACT else 1)


func _project(row: int) -> Vector2i:
	"""Read a real Construction reference; this is distinct from this owner's local tip handle."""
	return Vector2i(_project_slot[row], _project_generation[row])


func embedded_milli(tip: Vector2i) -> int:
	"""Embedded earth is world stock, not ready inventory or a second virgin source."""
	return _embedded_milli[tip.x] if is_live_tip(tip) else -1


func total_embedded_milli() -> int:
	"""Conservation reads actual lifetime commits; pending reclaim never releases embedded stock."""
	return _compacted_milli - _reclaimed_milli if _ready_error == &"" else -1


func world_ref() -> Vector2i:
	"""Return the exact namespace; composition must additionally prove its current Directory liveness."""
	return _world


func construction_owner() -> Construction:
	"""Expose exact owner identity for typed composition, never a permissive replacement callback."""
	return _construction


func tile_of(tip: Vector2i) -> int:
	"""The real designated exterior tile remains occupied through cancellation until paid closure."""
	return _tile[tip.x] if is_live_tip(tip) else -1


func is_prepared(tip: Vector2i) -> bool:
	"""Paid preparation alone unlocks compaction; a merely designated tile does not."""
	return is_live_tip(tip) and _prepared[tip.x] == 1


func operation_of(tip: Vector2i) -> int:
	"""Return the currently bound local operation, or -1 for idle/stale tips."""
	return _operation[tip.x] if is_live_tip(tip) else -1


func quantity_milli(tip: Vector2i) -> int:
	"""Return the immutable active quantity contract, never a client-proposed amount."""
	return _quantity_milli[tip.x] if is_live_tip(tip) else -1


func locked_milli(tip: Vector2i) -> int:
	"""Expose the actual reclaim source pin; it is neither loose inventory nor extra free capacity."""
	return _locked_milli[tip.x] if is_live_tip(tip) else -1


func incoming_milli(tip: Vector2i) -> int:
	"""Expose capacity already reserved for the whole active compaction contract."""
	return _incoming_milli[tip.x] if is_live_tip(tip) else -1


func retained_work_mwu(tip: Vector2i, operation: int, quantity: int = 0) -> int:
	"""Read retained work only under the exact requested source and quantity contract."""
	if not is_live_tip(tip) or total_work_mwu(operation, quantity) < 0:
		return -1
	if operation == COMPACT or operation == RECLAIM:
		var retained: int = _retained_quantity[_quantity_index(tip.x, operation)]
		if retained != 0 and retained != quantity:
			return -1
	return _earned_mwu[tip.x * OP_COUNT + operation]


func project_of(tip: Vector2i) -> Vector2i:
	"""Expose the generation-qualified actual operation project, or null for an idle/stale tip."""
	return _project(tip.x) if is_live_tip(tip) else NULL_REF


func packed_memory_bytes() -> int:
	"""Exact allocated packed payload; excludes separately recorded header/scalar/native overhead."""
	return 107 * _capacity + MAX_CAPACITY * 4 if _capacity > 0 else 0


func legacy_save_refusal() -> StringName:
	"""Old snapshots cannot erase tip stock, retained history or lifetime conservation counters."""
	if _ready_error != &"":
		return _ready_error
	if _count > 0 or _compacted_milli > 0 or _reclaimed_milli > 0:
		return REFUSE_CODEC
	for generation: int in _generation:
		if generation > 0:
			return REFUSE_CODEC
	return &""


func state_bytes() -> PackedByteArray:
	"""Cold diagnostic image; composed versioned capture/restore remains UG16's transaction."""
	var out: PackedByteArray = PackedInt64Array([_world.x, _world.y, _capacity, _count,
		_compacted_milli, _reclaimed_milli]).to_byte_array()
	for column: PackedByteArray in [_present, _retired, _prepared]:
		out.append_array(column)
	for column: Variant in [_generation, _tile, _project_slot, _project_generation, _operation,
		_embedded_milli, _quantity_milli, _locked_milli, _incoming_milli, _earned_mwu, _retained_quantity]:
		out.append_array(column.to_byte_array())
	return out


func audit_refusal() -> StringName:
	"""Cold two-way identity/stock audit; one C-byte visited buffer is released before returning."""
	if _bound_publisher() == null:
		return REFUSE_BINDING
	var code: StringName = _format_refusal()
	if code != &"":
		return code
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(_capacity)
	code = _heap_refusal(seen)
	if code != &"":
		return code
	var live: int = 0
	var embedded: int = 0
	for row: int in _capacity:
		code = _row_refusal(row, seen[row] == 1)
		if code != &"":
			return code
		live += _present[row]
		embedded += _embedded_milli[row]
	if live != _count or _compacted_milli < 0 or _reclaimed_milli < 0 \
			or embedded != _compacted_milli - _reclaimed_milli:
		return &"SPOIL_CONSERVATION"
	return _tile_index_refusal()


func _format_refusal() -> StringName:
	"""Check every column length before the cold audit reads potentially corrupt saved state."""
	for column: Variant in [_present, _retired, _prepared, _generation, _tile,
			_project_slot, _project_generation, _operation, _embedded_milli,
			_quantity_milli, _locked_milli, _incoming_milli, _free_heap]:
		if column.size() != _capacity:
			return &"SPOIL_COLUMN_FORMAT"
	if _earned_mwu.size() != _capacity * OP_COUNT or _retained_quantity.size() != _capacity * 2 \
			or _tile_row.size() != MAX_CAPACITY or _free_count < 0 or _free_count > _capacity:
		return &"SPOIL_COLUMN_FORMAT"
	return &""


func _heap_refusal(seen: PackedByteArray) -> StringName:
	"""The derived allocator must contain each reusable row once, in actual minimum-heap order."""
	for at: int in _free_count:
		var row: int = _free_heap[at]
		if row < 0 or row >= _capacity or seen[row] == 1:
			return &"SPOIL_FREE_INDEX"
		seen[row] = 1
		if at > 0:
			@warning_ignore("integer_division") var parent: int = (at - 1) / 2
			if _free_heap[parent] > row:
				return &"SPOIL_FREE_INDEX"
	return &""


func _row_refusal(row: int, free: bool) -> StringName:
	"""Verify reciprocal tile ownership, full project identity and physically bounded source claims."""
	if _present[row] > 1 or _retired[row] > 1 or _prepared[row] > 1 or _generation[row] < 0:
		return &"SPOIL_ROW_FORMAT"
	if _present[row] == 0:
		return _absent_row_refusal(row, free)
	if free or _retired[row] != 0 or _generation[row] == 0 or _tile[row] < 0 \
			or _tile[row] >= MAX_CAPACITY or _tile_row[_tile[row]] != row:
		return &"SPOIL_TILE_INDEX"
	if _embedded_milli[row] < 0 or _embedded_milli[row] > MAX_QUANTITY_MILLI \
			or (_prepared[row] == 0 and _embedded_milli[row] != 0):
		return &"SPOIL_SOURCE_QUANTITY"
	var code: StringName = _retained_refusal(row)
	if code != &"":
		return code
	if _project_slot[row] == -1:
		return _idle_refusal(row)
	var tip: Vector2i = Vector2i(row, _generation[row])
	code = _active_claim_refusal(row)
	return cancellation_refusal(tip, _project(row)) if code == &"" else code


func _absent_row_refusal(row: int, free: bool) -> StringName:
	"""Closed/reusable generations retain identity only; no source, retained labor or hidden claim survives."""
	if free != (_retired[row] == 0) or (_retired[row] == 1 and _generation[row] != I32_MAX) \
			or (free and _generation[row] == I32_MAX) \
			or _tile[row] != -1 or _prepared[row] != 0 or _embedded_milli[row] != 0 \
			or _project_slot[row] != -1:
		return &"SPOIL_FREE_INDEX"
	for operation: int in OP_COUNT:
		if _earned_mwu[row * OP_COUNT + operation] != 0:
			return &"SPOIL_RETAINED_WORK"
	if _retained_quantity[row * 2] != 0 or _retained_quantity[row * 2 + 1] != 0:
		return &"SPOIL_RETAINED_WORK"
	return _idle_refusal(row)


func _idle_refusal(row: int) -> StringName:
	"""An idle/absent tip cannot keep a partial project identity or claim for an unowned operation."""
	return &"" if _project_generation[row] == 0 and _operation[row] == -1 \
		and _quantity_milli[row] == 0 and _locked_milli[row] == 0 and _incoming_milli[row] == 0 \
		else &"SPOIL_IDLE_CLAIM"


func _active_claim_refusal(row: int) -> StringName:
	"""Each active operation owns precisely its full source/capacity contract, never anticipated free room."""
	var operation: int = _operation[row]
	var quantity: int = _quantity_milli[row]
	if _project_generation[row] < 1 or _operation_refusal(row, operation, quantity) != &"":
		return REFUSE_PHASE
	if _locked_milli[row] != (quantity if operation == RECLAIM else 0) \
			or _incoming_milli[row] != (quantity if operation == COMPACT else 0):
		return &"SPOIL_ACTIVE_CLAIM"
	if (operation == COMPACT or operation == RECLAIM) \
			and _retained_quantity[_quantity_index(row, operation)] != quantity:
		return REFUSE_CONTRACT
	return &""


func _retained_refusal(row: int) -> StringName:
	"""Each nonnegative earned amount belongs to its own fixed or exact-q operation contract."""
	for operation: int in OP_COUNT:
		var quantity: int = _retained_quantity[_quantity_index(row, operation)] \
			if operation == COMPACT or operation == RECLAIM else 0
		var earned: int = _earned_mwu[row * OP_COUNT + operation]
		var variable: bool = operation == COMPACT or operation == RECLAIM
		if variable and quantity == 0:
			if earned != 0:
				return &"SPOIL_RETAINED_WORK"
			continue
		var total: int = total_work_mwu(operation, quantity)
		if total < 0 or earned < 0 or earned > total or (variable and _prepared[row] == 0) \
				or (operation == PREPARE and _prepared[row] == 1 and earned != 0):
			return &"SPOIL_RETAINED_WORK"
	return &""


func _tile_index_refusal() -> StringName:
	"""Reverse lookup is a bijection: a duplicate/phantom indexed tile cannot be accepted by capture."""
	for tile: int in MAX_CAPACITY:
		var row: int = _tile_row[tile]
		if row != -1 and (row < 0 or row >= _capacity or _present[row] != 1 or _tile[row] != tile):
			return &"SPOIL_TILE_INDEX"
	return &""


func _pop_free() -> int:
	"""Choose the lowest available row without scanning the entire configured capacity."""
	var result: int = _free_heap[0]
	_free_count -= 1
	if _free_count == 0:
		return result
	var value: int = _free_heap[_free_count]
	var at: int = 0
	while at * 2 + 1 < _free_count:
		var child: int = at * 2 + 1
		if child + 1 < _free_count and _free_heap[child + 1] < _free_heap[child]:
			child += 1
		if _free_heap[child] >= value:
			break
		_free_heap[at] = _free_heap[child]
		at = child
	_free_heap[at] = value
	return result


func _push_free(row: int) -> void:
	"""Reinsert a safely closed reusable row; exhausted generations never reach this heap."""
	var at: int = _free_count
	_free_count += 1
	while at > 0:
		@warning_ignore("integer_division") var parent: int = (at - 1) / 2
		if _free_heap[parent] <= row:
			break
		_free_heap[at] = _free_heap[parent]
		at = parent
	_free_heap[at] = row
