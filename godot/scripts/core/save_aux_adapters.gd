extends RefCounted
## Section 6 AUXILIARY_STATE owner adapters (ADR 1222 build step 4b).
##
## Each adapter is bound to one live store and exposes `capture(block)`, `validate(block)` and
## `apply(block)` returning a `SaveHeader.Refusal`, the interface `save_section_auxiliary.gd`'s
## `Adapters` registry requires. `validate()` is pure over the block and the store's own static
## predicate; `apply()` re-runs the owner's checks and writes nothing on refusal.
##
##   * `CropWeatherAdapter`, `EcologyAdapter` -- the run latches.
##   * `CommandDispatchAdapter` -- the zone-designation intent dedup table.
##   * `ColumnsAdapter` -- an owner whose `save_columns()` / `restore_columns(Array)` /
##     `columns_valid(Array)` move all of its section 6 columns in registry order
##     (demolition_admissions, demolition_work, store_policy).
##   * `HaulPlannerAdapter` -- ADR 1221's UHPL admission wire, re-sliced into the five columns.
##   * `JointAdapter` -- a block filled and installed by an owner's JOINT bridge (buildings'
##     flags, construction's extension and paid ledger), which this registry only shape-checks.
## Owners still without a codec use `save_section_auxiliary.gd`'s `UnsupportedAdapter`.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

## Self-preload: inner classes resolve outer constants but not outer static functions.
const SaveAux := preload("res://scripts/core/save_aux_adapters.gd")
const Section := preload("res://scripts/core/save_section_auxiliary.gd")
const Schema := preload("res://scripts/core/save_auxiliary_state_schema.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const CropWeatherScript := preload("res://scripts/core/crop_weather.gd")
const EcologyScript := preload("res://scripts/core/ecology.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const HaulPlannerScript := preload("res://scripts/core/haul_planner.gd")

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_OWNER_STATE: StringName = &"SAVE_S6_OWNER_STATE"


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


static func _owner_refusal(block: Section.Block, key: String) -> SaveHeader.Refusal:
	"""The block belongs to `key` and is well shaped."""
	if block == null or not Schema.owner_valid(block.owner) \
			or Schema.OWNER_KEYS[block.owner] != key:
		return _no(Section.REFUSE_OWNER_KEY, "a section 6 '%s' block is required" % key)
	var detail: String = block.shape_detail()
	if detail != "":
		return _no(Section.REFUSE_ELEMENT_COUNT, detail)
	return _ok()


static func _first_refusal(refusals: Array) -> SaveHeader.Refusal:
	"""The first non-accepted refusal in `refusals`, or accepted."""
	for refusal: SaveHeader.Refusal in refusals:
		if not refusal.is_ok():
			return refusal
	return _ok()


class CropWeatherAdapter:
	"""`crop_weather`: `_last_day` (i32) and `_last_hour_tick` (i64)."""
	var _store: CropWeatherScript = null

	func _init(p_store: CropWeatherScript) -> void:
		"""Bind the live store."""
		_store = p_store

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""Write both latches."""
		var latches: PackedInt64Array = _store.save_latches()
		return SaveAux._first_refusal([block.set_scalar(0, latches[0]),
			block.set_scalar(1, latches[1])])

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Owner, shape and both latch domains."""
		var owner: SaveHeader.Refusal = SaveAux._owner_refusal(block, "crop_weather")
		if not owner.is_ok():
			return owner
		if block.scalar(0) < CropWeatherScript.NO_DAY_RUN \
				or block.scalar(1) < CropWeatherScript.NO_HOUR_RUN:
			return SaveAux._no(REFUSE_OWNER_STATE, "crop_weather latches out of domain")
		return SaveAux._ok()

	func apply(block: Section.Block) -> SaveHeader.Refusal:
		"""Install both latches."""
		if not _store.restore_latches(block.scalar(0), block.scalar(1)):
			return SaveAux._no(REFUSE_OWNER_STATE, "crop_weather refused its latches")
		return SaveAux._ok()


class EcologyAdapter:
	"""`ecology`: `_last_day` (i32)."""
	var _store: EcologyScript = null

	func _init(p_store: EcologyScript) -> void:
		"""Bind the live store."""
		_store = p_store

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""Write the day latch."""
		return block.set_scalar(0, _store.save_last_day())

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Owner, shape and the latch domain."""
		var owner: SaveHeader.Refusal = SaveAux._owner_refusal(block, "ecology")
		if owner.is_ok() and block.scalar(0) < EcologyScript.NO_DAY_RUN:
			return SaveAux._no(REFUSE_OWNER_STATE, "ecology latch out of domain")
		return owner

	func apply(block: Section.Block) -> SaveHeader.Refusal:
		"""Install the day latch."""
		if not _store.restore_last_day(block.scalar(0)):
			return SaveAux._no(REFUSE_OWNER_STATE, "ecology refused its latch")
		return SaveAux._ok()


class CommandDispatchAdapter:
	"""`command_dispatch`: the four intent columns."""
	var _store: CommandDispatchScript = null

	func _init(p_store: CommandDispatchScript) -> void:
		"""Bind the live store."""
		_store = p_store

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""Write the four intent columns."""
		var columns: Array[PackedInt32Array] = []
		for index: int in 4:
			var column: PackedInt32Array = PackedInt32Array()
			column.resize(CommandDispatchScript.INTENT_CAPACITY)
			columns.append(column)
		if not _store.copy_intent_columns_into(columns[0], columns[1], columns[2], columns[3]):
			return SaveAux._no(REFUSE_OWNER_STATE, "command_dispatch refused its intent copy")
		var refusals: Array = []
		for ordinal: int in 4:
			refusals.append(block.set_i32_column(ordinal, columns[ordinal]))
		return SaveAux._first_refusal(refusals)

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Owner, shape and the intent table's own rule."""
		var owner: SaveHeader.Refusal = SaveAux._owner_refusal(block, "command_dispatch")
		if owner.is_ok() and not CommandDispatchScript.intent_columns_valid(block.i32_column(0),
				block.i32_column(1), block.i32_column(2), block.i32_column(3)):
			return SaveAux._no(REFUSE_OWNER_STATE, "command_dispatch intents out of domain")
		return owner

	func apply(block: Section.Block) -> SaveHeader.Refusal:
		"""Install the four intent columns."""
		if not _store.restore_intent_columns(block.i32_column(0), block.i32_column(1),
				block.i32_column(2), block.i32_column(3)):
			return SaveAux._no(REFUSE_OWNER_STATE, "command_dispatch refused its intents")
		return SaveAux._ok()


class ColumnsAdapter:
	"""An owner exposing `save_columns()`, `restore_columns(Array)` and `columns_valid(Array)`."""
	var _store: Object = null
	var _key: String = ""

	func _init(p_store: Object, p_key: String) -> void:
		"""Bind the live store and its section 6 owner key."""
		_store = p_store
		_key = p_key

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""Write every column through the block's typed setters."""
		var columns: Array = _store.save_columns()
		var refusals: Array = []
		for ordinal: int in columns.size():
			refusals.append(SaveAux._set_column(block, ordinal, columns[ordinal]))
		return SaveAux._first_refusal(refusals)

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Owner, shape and the owner's own static predicate."""
		var owner: SaveHeader.Refusal = SaveAux._owner_refusal(block, _key)
		if owner.is_ok() and not _store.columns_valid(SaveAux._columns_of(block)):
			return SaveAux._no(REFUSE_OWNER_STATE, "'%s' columns out of domain" % _key)
		return owner

	func apply(block: Section.Block) -> SaveHeader.Refusal:
		"""Install every column."""
		if not _store.restore_columns(SaveAux._columns_of(block)):
			return SaveAux._no(REFUSE_OWNER_STATE, "'%s' refused its columns" % _key)
		return SaveAux._ok()


static func _set_column(block: Section.Block, ordinal: int, column: Variant) -> SaveHeader.Refusal:
	"""Dispatch one packed column to the block's setter of its declared type."""
	var type_code: int = Schema.field_type_of(block.owner, ordinal)
	if type_code == Schema.TYPE_U8:
		return block.set_u8_column(ordinal, column)
	if type_code == Schema.TYPE_I64:
		return block.set_i64_column(ordinal, column)
	return block.set_i32_column(ordinal, column)


static func _columns_of(block: Section.Block) -> Array:
	"""Every column of a block decoded to its declared packed type, in ordinal order."""
	var columns: Array = []
	for ordinal: int in Schema.field_count_of(block.owner):
		var type_code: int = Schema.field_type_of(block.owner, ordinal)
		if type_code == Schema.TYPE_U8:
			columns.append(block.u8_column(ordinal))
		elif type_code == Schema.TYPE_I64:
			columns.append(block.i64_column(ordinal))
		else:
			columns.append(block.i32_column(ordinal))
	return columns


class HaulPlannerAdapter:
	"""`haul_planner`: ADR 1221's UHPL wire, whose body is exactly the five columns column-major."""
	var _store: HaulPlannerScript = null

	func _init(p_store: HaulPlannerScript) -> void:
		"""Bind the live planner."""
		_store = p_store

	func capture(block: Section.Block) -> SaveHeader.Refusal:
		"""Capture the wire, then slice its body into the five columns."""
		var wire: PackedByteArray = PackedByteArray()
		var code: StringName = _store.capture_admissions_into(wire)
		if code != REFUSE_NONE:
			return SaveAux._no(code, "haul_planner refused its admission capture")
		var rows: int = HaulPlannerScript.JOB_CAPACITY
		var refusals: Array = []
		for ordinal: int in 4:
			var at: int = 12 + ordinal * 4 * rows
			var column: PackedInt32Array = wire.slice(at, at + 4 * rows).to_int32_array()
			refusals.append(block.set_i32_column(ordinal, column))
		var grams: int = 12 + 16 * rows
		var reserved: PackedInt64Array = wire.slice(grams, grams + 8 * rows).to_int64_array()
		refusals.append(block.set_i64_column(4, reserved))
		return SaveAux._first_refusal(refusals)

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Owner and shape; every row is proved by the planner itself at apply."""
		return SaveAux._owner_refusal(block, "haul_planner")

	func apply(block: Section.Block) -> SaveHeader.Refusal:
		"""Rebuild the UHPL wire from the five columns and hand it to the planner's restore."""
		var wire: PackedByteArray = PackedByteArray()
		wire.resize(12)
		wire.encode_s32(0, HaulPlannerScript.ADMISSION_WIRE_MAGIC)
		wire.encode_s32(4, HaulPlannerScript.ADMISSION_WIRE_SCHEMA)
		wire.encode_s32(8, HaulPlannerScript.JOB_CAPACITY)
		for ordinal: int in 4:
			wire.append_array(block.i32_column(ordinal).to_byte_array())
		wire.append_array(block.i64_column(4).to_byte_array())
		var code: StringName = _store.restore_admissions(wire)
		if code != REFUSE_NONE:
			return SaveAux._no(code, "haul_planner refused its admissions")
		return SaveAux._ok()


class JointAdapter:
	"""A block captured and installed by its owner's joint bridge; this only shape-checks it."""
	var _key: String = ""

	func _init(p_key: String) -> void:
		"""Bind the section 6 owner key."""
		_key = p_key

	func capture(_block: Section.Block) -> SaveHeader.Refusal:
		"""Nothing: the joint bridge fills this block with its section 4 record."""
		return SaveAux._ok()

	func validate(block: Section.Block) -> SaveHeader.Refusal:
		"""Owner and shape; the joint bridge's restore judges the values."""
		return SaveAux._owner_refusal(block, _key)

	func apply(_block: Section.Block) -> SaveHeader.Refusal:
		"""Nothing: the joint bridge installs this block with its section 4 record."""
		return SaveAux._ok()
