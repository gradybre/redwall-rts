extends RefCounted
## Typed site authority and immutable ECON-001/002/005 operation facts.
## The base authority refuses. Only a concrete physical-site store may authorize projects.
## Production spatial validation is a separate binding; economic cubes prove no route or support.

const IntMath := preload("res://scripts/core/int_math.gd")
const QUANTUM_SIDE_U: int = 1024
const BRACE_WORK_MWU: int = 2000
const CUT_WORK_MWU: int = 4000
const FINISH_WORK_MWU: int = 3000
const REMOVE_SUPPORT_WORK_MWU: int = 1250
const BACKFILL_WORK_MWU: int = 3000
const BRACE_WOOD_MILLI: int = 250
const BRACE_STONE_MILLI: int = 250
const EARTH_MILLI: int = 2000
const SALVAGE_WOOD_MILLI: int = 125
const SALVAGE_STONE_MILLI: int = 125
const MAX_PROJECT_BUILDERS: int = 4
const MAX_QUANTUM_WORKERS: int = 1
const NULL_REF: Vector2i = Vector2i(-1, 0)
const ACTION_DELIVER: int = 0
const ACTION_BEGIN_WORK: int = 1
const ACTION_WORK: int = 2
const ACTION_CANCEL: int = 3
const ACTION_RETIRE: int = 4
const ACTION_CONTAINER: int = 5
const ACTION_WIP: int = 6
const ACTION_OUTPUT: int = 7
const ACTION_REFUND: int = 8
const STAGE_ADMIT: int = 0
const STAGE_START: int = 1
const STAGE_COMMIT: int = 2
const STAGE_CANCEL: int = 3
const STAGE_WORK: int = 4

class Domain extends RefCounted:
	## Whole-world immutable lattice descriptor, supplied by an actual geometry owner.
	var world_ref: Vector2i = Vector2i(-1, 0)
	var datum_u: Vector3i = Vector3i.ZERO
	var minimum_quantum: Vector3i = Vector3i.ZERO
	var size_quanta: Vector3i = Vector3i.ZERO

class SpatialAuthority extends RefCounted:
	## Fail-closed typed adapter. UG08/09 must bind actual geometry, room, route and contact owners.
	func domain_into(_out: Domain) -> bool:
		"""Describe the immutable world domain; the abstract authority supplies no geometry."""
		return false

	func room_refusal(_room: Vector2i) -> StringName:
		"""Validate a full owning room/project generation in the actual room namespace."""
		return &"EXCAVATION_SPATIAL_UNBOUND"

	func retirement_refusal(_room: Vector2i) -> StringName:
		"""Prove safe room retirement through actual room, item, route and support owners."""
		return &"EXCAVATION_SPATIAL_UNBOUND"

	func operation_refusal(_origin_u: Vector3i, _operation: int, _stage: int,
			_room: Vector2i) -> StringName:
		"""ADMIT/WORK prove only; START/COMMIT/CANCEL may stage a finite no-fail publication."""
		return &"EXCAVATION_SPATIAL_UNBOUND"

	func material_refusal(_origin_u: Vector3i, _room: Vector2i,
			_container: Vector2i, _job: Vector2i) -> StringName:
		"""Prove actual delivered material location and legal access, never a caller boolean."""
		return &"EXCAVATION_SPATIAL_UNBOUND"

	func output_refusal(_origin_u: Vector3i, _operation: int, _room: Vector2i,
			_container: Vector2i, _job: Vector2i, _promotion_tile: int) -> StringName:
		"""Prove local output contact, full container identity and any held first-pile tile lease."""
		return &"EXCAVATION_SPATIAL_UNBOUND"

	func worker_refusal(_origin_u: Vector3i, _operation: int, _room: Vector2i,
			_job: Vector2i, _worker: Vector2i) -> StringName:
		"""Prove the live worker's legal route/work contact from the actual movement owner."""
		return &"EXCAVATION_SPATIAL_UNBOUND"

	func final_start_observation_refusal(_origin_u: Vector3i, _operation: int, _room: Vector2i) -> StringName:
		"""Reobserve the exact prepared START after staged Inventory observers, before payment."""
		return &"EXCAVATION_SPATIAL_UNBOUND"

	func final_start_leaf_refusal(_origin_u: Vector3i, _operation: int, _room: Vector2i) -> StringName:
		"""Reattest that same candidate without callbacks, allocation or live publication."""
		return &"EXCAVATION_SPATIAL_UNBOUND"

	func discard_transition(_origin_u: Vector3i, _operation: int, _stage: int,
			_room: Vector2i) -> void:
		"""Drop only operation scratch after refusal; never release lasting phase/contact ownership."""
		assert(false, "Unbound geometry cannot own a prepared transition")

	func publish_transition(_origin_u: Vector3i, _operation: int, _stage: int,
			_room: Vector2i) -> void:
		"""Non-failing publication after immediate preflight and the physical transaction commit."""
		assert(false, "Unbound geometry cannot publish a physical transition")

## ASCII order in this owner domain; not BuildingState or a repurposed furniture catalog ID.
const OP_BACKFILL_CLOSE: int = 0
const OP_BRACE: int = 1
const OP_CUT: int = 2
const OP_FINISH: int = 3
const OP_UNOPENED_SUPPORT_CLOSE: int = 4
const OP_COUNT: int = 5
const OP_KEYS: Array[StringName] = [
	&"BACKFILL_CLOSE", &"BRACE", &"CUT", &"FINISH", &"UNOPENED_SUPPORT_CLOSE",
]
const REFUSE_AUTHORITY: StringName = &"EXCAVATION_AUTHORITY_UNBOUND"


static func valid_operation(operation: int) -> bool:
	"""The economic operation domain is separate from a physical site's current phase."""
	return operation >= 0 and operation < OP_COUNT


static func work_mwu(operation: int) -> int:
	"""Return adopted work; invalid operation returns -1, never a free phase."""
	match operation:
		OP_BACKFILL_CLOSE:
			return REMOVE_SUPPORT_WORK_MWU + BACKFILL_WORK_MWU
		OP_BRACE:
			return BRACE_WORK_MWU
		OP_CUT:
			return CUT_WORK_MWU
		OP_FINISH:
			return FINISH_WORK_MWU
		OP_UNOPENED_SUPPORT_CLOSE:
			return REMOVE_SUPPORT_WORK_MWU
	return -1


static func input_count(operation: int) -> int:
	"""Price only the current phase; installed bracing is never delivered again for finishing."""
	if operation == OP_BRACE:
		return 2
	if operation == OP_BACKFILL_CLOSE:
		return 1
	return 0 if valid_operation(operation) else -1


static func input_key(operation: int, index: int) -> StringName:
	"""Named keys resolve through the real ItemDefinitions; no compiled numeric item IDs here."""
	if index < 0 or index >= input_count(operation):
		return &""
	if operation == OP_BACKFILL_CLOSE:
		return &"excavated_earth"
	return &"wood" if index == 0 else &"stone"


static func input_milli(operation: int, index: int) -> int:
	"""Return the exact authored quantity for one valid input line, or -1 for invalid input."""
	if index < 0 or index >= input_count(operation):
		return -1
	if operation == OP_BACKFILL_CLOSE:
		return EARTH_MILLI
	return BRACE_WOOD_MILLI if index == 0 else BRACE_STONE_MILLI


func is_live_site(_site: Vector2i) -> bool:
	"""The unbound base never attests a site identity."""
	return false


func project_open_refusal(_site: Vector2i, _operation: int) -> StringName:
	"""Concrete sites validate lifecycle, real spatial binding and conflicting projects."""
	return REFUSE_AUTHORITY


func remaining_work_into(_site: Vector2i, _operation: int, out: IntMath.IntResult) -> bool:
	"""A retained-work amount must come from the physical owner, not a caller's integer."""
	return out.refuse(REFUSE_AUTHORITY)


func attach_project(_site: Vector2i, _operation: int, _project: Vector2i) -> void:
	"""Non-failing publication hook, reachable only after this authority's admission succeeded."""
	assert(false, "An unbound excavation authority cannot publish a project")


func mutation_refusal(_project: Vector2i, _action: int) -> StringName:
	"""Only an active physical-owner transaction may mutate generic phase accounting."""
	return REFUSE_AUTHORITY


func excavation_inputs_refusal(_project: Vector2i, _job: Vector2i,
		_inventory: RefCounted, _pool: RefCounted) -> StringName:
	"""Only the actual original Sites/Funding START scope can settle purpose5 inputs."""
	return REFUSE_AUTHORITY


func final_input_refusal(_project: Vector2i, _job: Vector2i,
		_inventory: RefCounted, _pool: RefCounted, _output: Vector2i, _mass: int) -> StringName:
	"""The abstract owner cannot approve staged payment after Inventory observers."""
	return REFUSE_AUTHORITY


func work_tick_refusal(_job: Vector2i) -> StringName:
	"""Validate bound productive work before Work mutates carries, XP, durability or Job WU."""
	return REFUSE_AUTHORITY


func accept_work_tick(_job: Vector2i) -> void:
	"""Read actual Work/Job progress after a successful tick; no caller work amount is accepted."""
	assert(false, "Unbound excavation authority cannot accept productive work")
