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
