extends RefCounted
## Typed accounting seam for actual spatial furniture and World-owned spoil operations.
## Quotes are finite cold scratch, never authoritative per-project storage or caller prices.
## The base router and operation owner refuse every admission and publication.

const BatchDirectory := preload("res://scripts/core/entity_directory.gd")
const ItemDefinitions := preload("res://scripts/core/item_definitions.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const INPUT_CAPACITY: int = 4
const OUTPUT_CAPACITY: int = 2
const MAX_WORKERS: int = 4
const REFUSE_AUTHORITY: StringName = &"MODULAR_OPERATION_OWNER_UNBOUND"
const REFUSE_QUOTE: StringName = &"MODULAR_OPERATION_FACTS_INVALID"
const REFUSE_PROJECT_CONTEXT: StringName = &"MODULAR_BILL_REQUIRES_PROJECT"
## Construction's owned-accounting actions. Kept separate from physical operation IDs.
const ACTION_DELIVER: int = 0
const ACTION_BEGIN_WORK: int = 1
const ACTION_WORK: int = 2
const ACTION_CANCEL: int = 3
const ACTION_RETIRE: int = 4
const ACTION_CONTAINER: int = 5
const ACTION_WIP: int = 6
const ACTION_OUTPUT: int = 7
const ACTION_REFUND: int = 8
## Exact synchronous owner-publication windows; ASCII order matches the tip store.
const ADMIT: int = 0
const CANCEL: int = 1
const COMMIT: int = 2
const PRODUCTIVE: int = 3
## Contact/material preparation before payment; no physical source/installation publication.
const START: int = 4

class Quote extends RefCounted:
	## Two or three component-owned reusable quotes suffice; no entity owns one.
	var subject: Vector2i = Vector2i(-1, 0)
	var operation: int = -1
	var quantity_milli: int = 0
	var total_mwu: int = 0
	var remaining_mwu: int = 0
	var job_kind: int = -1
	var max_workers: int = 0
	var input_count: int = 0
	var input_keys: Array[StringName] = [&"", &"", &"", &""]
	var input_milli: PackedInt64Array = PackedInt64Array()
	var output_count: int = 0
	var output_item: PackedInt32Array = PackedInt32Array()
	var output_milli: PackedInt64Array = PackedInt64Array()
	var output_quality: PackedInt32Array = PackedInt32Array()
	var output_provenance: PackedInt32Array = PackedInt32Array()
	var output_recipe: PackedInt32Array = PackedInt32Array()
	var output_age: PackedInt64Array = PackedInt64Array()
	var output_remainder: PackedInt64Array = PackedInt64Array()


	func _init() -> void:
		"""Allocate exactly 112 packed scratch bytes once for this component-owned quote."""
		input_milli.resize(INPUT_CAPACITY)
		output_item.resize(OUTPUT_CAPACITY)
		output_milli.resize(OUTPUT_CAPACITY)
		output_quality.resize(OUTPUT_CAPACITY)
		output_provenance.resize(OUTPUT_CAPACITY)
		output_recipe.resize(OUTPUT_CAPACITY)
		output_age.resize(OUTPUT_CAPACITY)
		output_remainder.resize(OUTPUT_CAPACITY)
		reset()

	func reset() -> void:
		"""Erase old scratch so a partial owner reply cannot borrow an earlier contract."""
		subject = Vector2i(-1, 0)
		operation = -1
		quantity_milli = 0
		total_mwu = 0
		remaining_mwu = 0
		job_kind = -1
		max_workers = 0
		input_count = 0
		input_keys.fill(&"")
		input_milli.fill(0)
		output_count = 0
		output_item.fill(-1)
		output_milli.fill(0)
		output_quality.fill(0)
		output_provenance.fill(0)
		output_recipe.fill(-1)
		output_age.fill(0)
		output_remainder.fill(0)

	func refusal() -> StringName:
		"""Validate finite shape and integer amounts; the actual owner still proves adopted prices."""
		var code: StringName = _scalar_refusal()
		if code == &"":
			code = _shape_refusal()
		if code == &"":
			code = _input_refusal()
		return _output_refusal() if code == &"" else code

	func _scalar_refusal() -> StringName:
		"""References, operation counts and retained work must fit their explicit integer domains."""
		if subject.x < 0 or subject.y <= 0 or operation < 0 or quantity_milli < 0 \
				or total_mwu <= 0 or remaining_mwu < 0 or remaining_mwu > total_mwu \
				or job_kind < 0 or max_workers < 1 or max_workers > MAX_WORKERS \
				or input_count < 0 or input_count > INPUT_CAPACITY \
				or output_count < 0 or output_count > OUTPUT_CAPACITY:
			return REFUSE_QUOTE
		return &""

	func _shape_refusal() -> StringName:
		"""A caller cannot grow, shrink or replace one bounded quote column before validation."""
		if input_keys.size() != INPUT_CAPACITY or input_milli.size() != INPUT_CAPACITY \
				or output_item.size() != OUTPUT_CAPACITY or output_milli.size() != OUTPUT_CAPACITY \
				or output_quality.size() != OUTPUT_CAPACITY or output_provenance.size() != OUTPUT_CAPACITY \
				or output_recipe.size() != OUTPUT_CAPACITY or output_age.size() != OUTPUT_CAPACITY \
				or output_remainder.size() != OUTPUT_CAPACITY:
			return REFUSE_QUOTE
		return &""

	func _input_refusal() -> StringName:
		"""Used lines are distinct positive quantities; unused lines cannot hide a second recipe."""
		for index: int in INPUT_CAPACITY:
			if index >= input_count:
				if input_keys[index] != &"" or input_milli[index] != 0:
					return REFUSE_QUOTE
				continue
			if input_keys[index] == &"" or input_milli[index] <= 0:
				return REFUSE_QUOTE
			for previous: int in index:
				if input_keys[index] == input_keys[previous]:
					return REFUSE_QUOTE
		return &""

	func _output_refusal() -> StringName:
		"""Validate complete output metadata and canonical unused entries before Inventory sees it."""
		for index: int in OUTPUT_CAPACITY:
			if index >= output_count:
				if output_item[index] != -1 or output_milli[index] != 0 \
						or output_quality[index] != 0 or output_provenance[index] != 0 \
						or output_recipe[index] != -1 or output_age[index] != 0 \
						or output_remainder[index] != 0:
					return REFUSE_QUOTE
			elif output_item[index] < 0 or output_milli[index] <= 0 \
					or output_quality[index] < 0 or output_provenance[index] < 0 \
					or output_recipe[index] < -1 or output_age[index] < 0 \
					or output_remainder[index] < 0:
				return REFUSE_QUOTE
		return &""

class Owner extends RefCounted:
	## One actual purpose owner per World. It owns immutable q/type and subject lifecycle.
	func construction_owner() -> RefCounted:
		"""Return the actual Construction object, never a numerically similar world."""
		return null

	func world_ref() -> Vector2i:
		"""Return the actual live World generation in that Construction's Directory."""
		return Vector2i(-1, 0)

	func purpose() -> int:
		"""Select the separate Construction purpose namespace, not an excavation operation."""
		return -1

	func prepared_order_into(_subject: Vector2i, _operation: int, _out: Quote) -> StringName:
		"""Read a cold, owner-validated pending order; no caller supplies a bill or q here."""
		return REFUSE_AUTHORITY

	func furniture_batch_refusal(_room: Vector2i, _batch: BatchDirectory.CreateBatch,
			_entries: PackedInt32Array) -> StringName:
		"""Finish all current token/source/catalog/tuple proof before the one paired identity allocation."""
		return REFUSE_AUTHORITY

	func publish_furniture_batch(_room: Vector2i, _batch: BatchDirectory.CreateBatch,
			_entries: PackedInt32Array) -> void:
		"""Publish only the sealed prepared physical companion after actual pending/project rows exist."""
		assert(false, "Unbound owner cannot publish a furniture batch")

	func discard_furniture_batch(_room: Vector2i, _batch: BatchDirectory.CreateBatch) -> void:
		"""The refusing base owns no candidate; unsupported batch cleanup cannot grant permission or mutate state."""
		pass

	func project_facts_into(_project: Vector2i, _out: Quote) -> StringName:
		"""Read immutable full-generation project facts and its actual retained work."""
		return REFUSE_AUTHORITY

	func transition_refusal(_project: Vector2i, _action: int) -> StringName:
		"""Prepare ADMIT/CANCEL/COMMIT/PRODUCTIVE or START, never Construction ACTION_* values."""
		return REFUSE_AUTHORITY

	func material_refusal(_project: Vector2i, _container: Vector2i, _job: Vector2i) -> StringName:
		"""Prove this phase's actual delivered material contact and route."""
		return REFUSE_AUTHORITY

	func output_refusal(_project: Vector2i, _container: Vector2i, _job: Vector2i,
			_promotion_tile: int) -> StringName:
		"""Prove the exact output contact and any first-pile staging lease."""
		return REFUSE_AUTHORITY

	func worker_refusal(_project: Vector2i, _job: Vector2i, _worker: Vector2i) -> StringName:
		"""Prove a real worker's current route and operation contact."""
		return REFUSE_AUTHORITY

	func discard_transition(_project: Vector2i, _action: int) -> void:
		"""Discard prepared scratch after failure, retaining real ownership and earned work."""
		assert(false, "Unbound modular owner cannot own transition scratch")

	func publish_open(_project: Vector2i) -> void:
		"""Attach the real project during the router's exact ADMIT publication window."""
		assert(false, "Unbound modular owner cannot admit a project")

	func publish_work(_project: Vector2i) -> void:
		"""Retain only actual Construction progress during the PRODUCTIVE window."""
		assert(false, "Unbound modular owner cannot publish work")

	func publish_completion(_project: Vector2i) -> void:
		"""Publish physical output/install only after actual Inventory commit."""
		assert(false, "Unbound modular owner cannot publish completion")

	func publish_cancellation(_project: Vector2i) -> void:
		"""Retain work and release source claims only after actual refunds commit."""
		assert(false, "Unbound modular owner cannot publish cancellation")

	func embedded_earth_milli() -> int:
		"""Return the actual owner's retained earth stock; unavailable is -1, never zero."""
		return -1


func construction_owner() -> RefCounted:
	"""The bound router must identify its actual accounting owner."""
	return null


func world_ref() -> Vector2i:
	"""The router belongs to one actual live World generation."""
	return NULL_REF


func item_definitions_owner() -> ItemDefinitions:
	"""The actual shared catalog instance, never a coincident item-number namespace."""
	return null


func owner_binding_refusal(_owner: Owner) -> StringName:
	"""Preflight exact purpose/world ownership without binding either collaborating owner."""
	return REFUSE_AUTHORITY


func is_bound_owner(_owner: Owner) -> bool:
	"""Only the real router may attest its current exact purpose owner."""
	return false


func is_publishing(_project: Vector2i, _action: int, _owner: Owner) -> bool:
	"""Only the exact synchronous physical publication window qualifies; base refuses."""
	return false


func furniture_batch_preparation_refusal(_room: Vector2i, _batch: BatchDirectory.CreateBatch) -> StringName:
	"""The actual Router alone owns the exclusive furniture-specific preallocation context."""
	return REFUSE_AUTHORITY


func furniture_batch_publication_refusal(_room: Vector2i, _batch: BatchDirectory.CreateBatch) -> StringName:
	"""Pure publication-window comparison after identity commit; no new physical proof callback."""
	return REFUSE_AUTHORITY


func is_publishing_furniture_admissions(_room: Vector2i, _batch: BatchDirectory.CreateBatch, _owner: Owner) -> bool:
	"""Expose exact actual batch/room/purpose-owner identity only during its synchronous publication."""
	return false


func project_open_into(_purpose: int, _subject: Vector2i, _operation: int,
		_out: Quote) -> StringName:
	"""Only the exact prepared router admission can supply immutable operation facts."""
	return REFUSE_AUTHORITY


func attach_project(_purpose: int, _subject: Vector2i, _operation: int,
		_project: Vector2i) -> void:
	"""Non-failing publication after accounting allocation; the actual router owns the window."""
	assert(false, "Unbound modular router cannot attach a project")


func project_facts_into(_project: Vector2i, _out: Quote) -> StringName:
	"""Read the actual bound purpose owner's immutable bill and remaining physical work."""
	return REFUSE_AUTHORITY


func mutation_refusal(_project: Vector2i, _action: int) -> StringName:
	"""Generic Construction/Funding calls require the router's exact active transaction."""
	return REFUSE_AUTHORITY


func work_tick_refusal(_job: Vector2i) -> StringName:
	"""Prove real Job/project/worker/tool identity before Work changes any state."""
	return REFUSE_AUTHORITY


func accept_work_tick(_job: Vector2i) -> void:
	"""Read accepted real Work progress synchronously; callers cannot supply labor amounts."""
	assert(false, "Unbound modular router cannot accept work")


func discard_work_tick(_job: Vector2i) -> void:
	"""Drop only the exact prepared productive candidate when real Work refuses or accepts zero."""
	pass


func embedded_earth_milli() -> int:
	"""Read actual typed source stock for whole-world conservation; unavailable refuses."""
	return -1
