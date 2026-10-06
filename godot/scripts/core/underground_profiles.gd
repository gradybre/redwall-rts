extends RefCounted
## Source-bound integer envelopes. This is a geometry lookup, never permission to move/work.
## Two admitted packed banks and one streamed row; no sampled or caller-invented profile fallback.

const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Carry := preload("res://scripts/core/haul_carry.gd")
const Work := preload("res://scripts/core/work.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Piles := preload("res://scripts/core/ground_piles.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const MAX_PROFILES: int = 256
const MAX_BOXES: int = 3072
const MAX_SOURCES: int = 64
const MAX_SELECTION_BOXES: int = 12
const MAX_KEY_VARIANTS: int = 16
const ARENA_BYTES: int = 262144
const CONTROL_RESERVE: int = 32768
const I32_FIELDS: int = 18
const I64_FIELDS: int = 3
const BYTE_FIELDS: int = 2
const PROFILE_WIRE_BYTES: int = 98
const BODY_HELD_LOAD: int = 0
const STANCE_SUPPORT: int = 1
const TURN_RECOVERY: int = 2
const WORK_APPROACH: int = 3
const WORK_STROKE: int = 4
const CONTACT_POINT: int = 5
const CONTACT_PATCH: int = 6
const CONTACT_NONE: int = 0
const CONTACT_ANCHOR_ONLY: int = 1
const CONTACT_ANCHOR_AND_PATCH: int = 2
const CONTACT_ASSEMBLY_PALM: int = 3
const MODE_STAND: int = 0
const MODE_WALK: int = 1
const MODE_CARRY: int = 2
const MODE_WORK: int = 3
const MODE_CLIMB: int = 4
const POSTURE_UPRIGHT: int = 0
const POSTURE_STOOPED: int = 1
const YAW_EXACT: int = 0
const YAW_ALL: int = 1
const STATE_IDLE: int = 1
const STATE_WALK: int = 2
const STATE_CARRY: int = 4
const STATE_WORK: int = 8
const STATE_CROUCH: int = 16
const STATE_CLIMB: int = 32
const STATE_ENTRY: int = 64
const STATE_REVERSAL: int = 128
const STATE_RECOVERY: int = 256
const CERT_SOURCE: int = 1
const CERT_CONTINUOUS: int = 2
const CERT_NUMERICAL: int = 4
const CERT_PRESENTATION: int = 8
const CERT_REQUIRED: int = 15
const POLICY_AUTOMATIC: int = 0
const POLICY_READY_FORWARD: int = 1
const POLICY_READY_BACKWARD: int = 2
const POLICY_SOURCE_WORK: int = 3
const POLICY_SHORT_FORWARD: int = 4
const POLICY_SHORT_BACKWARD: int = 5
const POLICY_CANONICAL_GROUND: int = 6
const POLICY_ASSEMBLY_HANDLING: int = 7
# Field-major columns, not one record/object per profile.
const F_SOURCE: int = 0
const F_SPECIES: int = 1
const F_STAGE: int = 2
const F_RIG: int = 3
const F_MODE: int = 4
const F_POSTURE: int = 5
const F_TOOL: int = 6
const F_TOOL_VARIANT: int = 7
const F_CARGO: int = 8
const F_CARGO_VARIANT: int = 9
const F_YAW_KIND: int = 10
const F_YAW: int = 11
const F_FAMILIES: int = 12
const F_STATES: int = 13
const F_FIRST_BOX: int = 14
const F_BOX_COUNT: int = 15
const F_WORK_KIND: int = 16
const F_CONTACT_KIND: int = 17
const L_REVISION: int = 0
const L_QUANTITY_MIN: int = 1
const L_QUANTITY_MAX: int = 2


class Selection extends RefCounted:
	## Caller scratch: successful reads fill every field; refusals leave it unchanged.
	var profile_id: int = -1
	var profile_revision: int = 0
	var content_revision: int = 0
	var source_id: int = -1
	var species: int = -1
	var life_stage: int = -1
	var rig: int = -1
	var mode: int = -1
	var posture: int = -1
	var x: int = 0
	var y: int = 0
	var z: int = 0
	var yaw: int = 0
	var orientation: int = -1
	var box_count: int = 0
	var worker: Vector2i = NULL_REF
	var job: Vector2i = NULL_REF
	var tool: Vector2i = NULL_REF
	var satchel: Vector2i = NULL_REF
	var cargo: Vector2i = NULL_REF
	var cargo_quantity_milli: int = 0


class Box extends RefCounted:
	## Position-relative integer AABB at the selected yaw (already oriented, never rotate again).
	## CONTACT_POINT is exact. CONTACT_PATCH is closed on its face plane with two positive spans.
	## All volume roles are half-open. A patch grants no occupied volume or clearance.
	var role: int = -1
	var low: Vector3i = Vector3i.ZERO
	var high: Vector3i = Vector3i.ZERO


class Descriptor extends RefCounted:
	## Cold authored geometry only: no worker, Job, equipped claim or movement permission.
	## Caller-owned 23 integer fields; no new retained catalog image or module scratch.
	var profile_id: int = -1
	var profile_revision: int = 0
	var content_revision: int = 0
	var source_id: int = -1
	var species: int = -1
	var life_stage: int = -1
	var rig: int = -1
	var mode: int = -1
	var posture: int = -1
	var tool_item: int = -1
	var tool_variant: int = -1
	var cargo_item: int = -1
	var cargo_variant: int = -1
	var quantity_min_milli: int = 0
	var quantity_max_milli: int = 0
	var yaw_kind: int = -1
	var yaw: int = 0
	var family_mask: int = 0
	var state_mask: int = 0
	var work_kind: int = -1
	var contact_kind: int = -1
	var box_count: int = 0
	var certificate_flags: int = 0


class Bank extends RefCounted:
	var header: PackedInt64Array = PackedInt64Array([0, 0, 0, 0]) # revision, profiles, boxes, sources
	var fields: PackedInt32Array = PackedInt32Array()
	var quantities: PackedInt64Array = PackedInt64Array()
	var flags: PackedByteArray = PackedByteArray()
	var boxes: PackedInt32Array = PackedInt32Array() # low XYZ, high XYZ, role; field-major.
	var sources: PackedByteArray = PackedByteArray()

	func allocate(profiles: int, volumes: int, bundles: int) -> void:
		"""Called only after the complete two-bank arena is admitted."""
		fields.resize(profiles * I32_FIELDS)
		quantities.resize(profiles * I64_FIELDS)
		flags.resize(profiles * BYTE_FIELDS)
		boxes.resize(volumes * 7)
		sources.resize(bundles * 32)


var _live: Bank = Bank.new()
var _stage: Bank = Bank.new()
var _profile_capacity: int = 0
var _box_capacity: int = 0
var _source_capacity: int = 0
var _residents: Residents = null
var _transforms: Transforms = null
var _inventory: Inventory = null
var _gear: Gear = null
var _carry: Carry = null
var _work: Work = null
var _reservations: Reservations = null
var _piles: Piles = null
var _identity: PackedInt32Array = PackedInt32Array()
var _pose: Transforms.Pose = Transforms.Pose.new()
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _candidate: Selection = Selection.new()
var _query_values: PackedInt64Array = PackedInt64Array() # tool, variant, cargo, variant, kind
var _loading: bool = false
var _worker_row: int = -1


func _init() -> void:
	"""Fixed reusable hot scratch has one explicit small allocation, independent of resident count."""
	_identity.resize(3)
	_query_values.resize(5)


func configure(profiles: int, boxes: int, sources: int, arena_bytes: int) -> StringName:
	"""Admit the complete simultaneous two-bank peak before allocation, once only."""
	if _profile_capacity != 0:
		return &"PROFILE_ALREADY_CONFIGURED"
	if profiles < 1 or profiles > MAX_PROFILES or boxes < 1 or boxes > MAX_BOXES \
			or sources < 1 or sources > MAX_SOURCES:
		return &"PROFILE_CAPACITY"
	var packed: int = 2 * (profiles * PROFILE_WIRE_BYTES + boxes * 28 + sources * 32 + 32)
	if arena_bytes > ARENA_BYTES or arena_bytes < packed + CONTROL_RESERVE:
		return &"PROFILE_ARENA_CAPACITY"
	_profile_capacity = profiles
	_box_capacity = boxes
	_source_capacity = sources
	_live.allocate(profiles, boxes, sources)
	_stage.allocate(profiles, boxes, sources)
	return &""


func packed_memory_bytes() -> int:
	"""Both admitted banks including fixed headers; query/native control uses the stated reserve."""
	return 2 * (_profile_capacity * PROFILE_WIRE_BYTES + _box_capacity * 28 + _source_capacity * 32 + 32)


func content_revision() -> int:
	"""An empty store has no valid content revision."""
	return _live.header[0]


func bind_actual(residents: Residents, transforms: Transforms, inventory: Inventory, gear: Gear,
		carry: Carry, work: Work, reservations: Reservations, piles: Piles) -> StringName:
	"""Bind one exact actual composition; no empty/fake authority callback can bless dimensions."""
	if _residents != null:
		return &"PROFILE_ALREADY_BOUND"
	if residents == null or transforms == null or inventory == null or gear == null \
			or carry == null or work == null or reservations == null or piles == null:
		return &"PROFILE_OWNER_UNBOUND"
	if not transforms.is_bound_directory(residents.directory()) \
			or not gear.equipment_binding_matches(inventory, residents.directory(), residents) \
			or not carry.binding_matches(inventory, reservations, residents, piles) \
			or work.residents() != residents or work.gear() != gear or work.jobs() == null:
		return &"PROFILE_OWNER_MISMATCH"
	if work.jobs().residents() != residents or work.jobs().directory() != residents.directory() \
			or reservations.inventory_binding_refusal(inventory) != &"":
		return &"PROFILE_OWNER_MISMATCH"
	_residents = residents
	_transforms = transforms
	_inventory = inventory
	_gear = gear
	_carry = carry
	_work = work
	_reservations = reservations
	_piles = piles
	return &""


func binding_matches(residents: Residents, transforms: Transforms, inventory: Inventory, gear: Gear,
		carry: Carry, work: Work, reservations: Reservations, piles: Piles) -> bool:
	"""Exact borrowed owners, never equal capacities or coincident numeric references."""
	return _residents != null and _residents == residents and _transforms == transforms \
		and _inventory == inventory and _gear == gear and _carry == carry and _work == work \
		and _reservations == reservations and _piles == piles


func load_file(path: String, expected_sha256: String, revision: int) -> StringName:
	"""Stream one row at a time into the inactive bank, verify exact bytes, then swap atomically."""
	if _profile_capacity == 0 or _loading:
		return &"PROFILE_LOAD_UNAVAILABLE"
	if revision <= content_revision() or expected_sha256.length() != 64 \
			or not expected_sha256.is_valid_hex_number(false):
		return &"PROFILE_SOURCE_IDENTITY"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return &"PROFILE_SOURCE_MISSING"
	_loading = true
	var digest_context: HashingContext = HashingContext.new()
	digest_context.start(HashingContext.HASH_SHA256)
	var code: StringName = _decode(file, digest_context, revision)
	if code == &"" and digest_context.finish().hex_encode() != expected_sha256.to_lower():
		code = &"PROFILE_SOURCE_HASH"
	file.close()
	if code == &"":
		code = _validate_stage()
	if code == &"":
		var old: Bank = _live
		_live = _stage
		_stage = old
	_loading = false
	return code


func _read(file: FileAccess, digest_context: HashingContext, count: int) -> PackedByteArray:
	"""The digest_context sees exactly the decoded bytes; no second full input image or TOCTOU digest_context pass."""
	var bytes: PackedByteArray = file.get_buffer(count)
	digest_context.update(bytes)
	return bytes


func _decode(file: FileAccess, digest_context: HashingContext, revision: int) -> StringName:
	"""Bound all counts and exact total bytes before reading profile/source/volume records."""
	var head: PackedByteArray = _read(file, digest_context, 32)
	if head.size() != 32 or head.slice(0, 8).get_string_from_ascii() != "UGPROF01" \
			or (head.decode_u32(8) != 1 and head.decode_u32(8) != 2) or head.decode_s64(12) != revision:
		return &"PROFILE_SOURCE_FORMAT"
	var count: int = head.decode_u32(20)
	var boxes: int = head.decode_u32(24)
	var sources: int = head.decode_u32(28)
	if count < 1 or count > _profile_capacity or boxes < 1 or boxes > _box_capacity \
			or sources < 1 or sources > _source_capacity:
		return &"PROFILE_CAPACITY"
	if file.get_length() != 40 + sources * 32 + count * PROFILE_WIRE_BYTES + boxes * 28:
		return &"PROFILE_SOURCE_FORMAT"
	_stage.header[0] = revision
	_stage.header[1] = count
	_stage.header[2] = boxes
	_stage.header[3] = sources
	var code: StringName = _decode_rows(file, digest_context, head.decode_u32(8))
	if code != &"":
		return code
	var end: PackedByteArray = _read(file, digest_context, 8)
	return &"" if end.get_string_from_ascii() == "UGPEND01" else &"PROFILE_SOURCE_FORMAT"


func _decode_rows(file: FileAccess, digest_context: HashingContext, version: int) -> StringName:
	"""Copy bounded source digests, then field-major columns; the live bank remains untouched."""
	for row: int in _stage.header[3]:
		var source: PackedByteArray = _read(file, digest_context, 32)
		if source.size() != 32 or source.count(0) == 32:
			return &"PROFILE_SOURCE_FORMAT"
		for byte: int in 32:
			_stage.sources[row * 32 + byte] = source[byte]
	for row: int in _stage.header[1]:
		var bytes: PackedByteArray = _read(file, digest_context, PROFILE_WIRE_BYTES)
		if bytes.size() != PROFILE_WIRE_BYTES:
			return &"PROFILE_SOURCE_FORMAT"
		if version == 1 and bytes[97] != POLICY_AUTOMATIC:
			return &"PROFILE_CERTIFICATE_REQUIRED"
		for field: int in I32_FIELDS:
			_stage.fields[field * _profile_capacity + row] = bytes.decode_s32(field * 4)
		for field: int in I64_FIELDS:
			_stage.quantities[field * _profile_capacity + row] = bytes.decode_s64(72 + field * 8)
		_stage.flags[row] = bytes[96]
		_stage.flags[_profile_capacity + row] = bytes[97]
	for row: int in _stage.header[2]:
		var bytes: PackedByteArray = _read(file, digest_context, 28)
		if bytes.size() != 28:
			return &"PROFILE_SOURCE_FORMAT"
		for field: int in 7:
			_stage.boxes[field * _box_capacity + row] = bytes.decode_s32(field * 4)
	return &""


func _field(bank: Bank, row: int, field: int) -> int:
	"""All callers first bound the row; fixed columns cannot alias caller-owned scratch."""
	return bank.fields[field * _profile_capacity + row]


func _long(bank: Bank, row: int, field: int) -> int:
	"""Read an int64 quantity/revision without converting or narrowing its value."""
	return bank.quantities[field * _profile_capacity + row]


func _validate_stage() -> StringName:
	"""Cold O(P²) admission keeps movement unique; WORK contacts require an explicit choice if ambiguous."""
	var next_box: int = 0
	# ADR1198: rows are key-sorted within each source; an appended source never renumbers earlier rows.
	var last_of: PackedInt32Array = PackedInt32Array()
	last_of.resize(_stage.header[3])
	last_of.fill(-1)
	var same_key: PackedInt32Array = PackedInt32Array()
	same_key.resize(_stage.header[3])
	for row: int in _stage.header[1]:
		var code: StringName = _profile_refusal(row, next_box)
		if code != &"":
			return code
		next_box += _field(_stage, row, F_BOX_COUNT)
		var source: int = _field(_stage, row, F_SOURCE)
		var order: int = _compare_rows(last_of[source], row) if last_of[source] >= 0 else -1
		if order > 0:
			return &"PROFILE_KEY_ORDER"
		same_key[source] = same_key[source] + 1 if order == 0 else 1
		last_of[source] = row
		var same_key_count: int = same_key[source]
		# Automatic lookup still sees every eligible row in its original16-row
		# window. Only one explicit nonproductive handling tail may follow it.
		if same_key_count > MAX_KEY_VARIANTS and (same_key_count != MAX_KEY_VARIANTS + 1 \
				or _stage.flags[_profile_capacity + row] != POLICY_ASSEMBLY_HANDLING):
			return &"PROFILE_KEY_CAPACITY"
		for previous: int in row:
			if _field(_stage, row, F_MODE) != MODE_WORK and _overlap_keys(previous, row):
				return &"PROFILE_AMBIGUOUS_KEY"
	return &"" if next_box == _stage.header[2] else &"PROFILE_BOX_CENSUS"


func _profile_refusal(row: int, next_box: int) -> StringName:
	"""Qualification is an explicit source certificate requirement, not inferred from positive bounds."""
	if _stage.flags[row] != CERT_REQUIRED or _stage.flags[_profile_capacity + row] > POLICY_ASSEMBLY_HANDLING \
			or _long(_stage, row, L_REVISION) <= 0:
		return &"PROFILE_CERTIFICATE_REQUIRED"
	if _field(_stage, row, F_SOURCE) < 0 or _field(_stage, row, F_SOURCE) >= _stage.header[3] \
			or _field(_stage, row, F_SPECIES) < 0 or _field(_stage, row, F_STAGE) < 0 \
			or _field(_stage, row, F_RIG) < 0:
		return &"PROFILE_IDENTITY_FORMAT"
	var mode: int = _field(_stage, row, F_MODE)
	var policy: int = _stage.flags[_profile_capacity + row]
	if policy != POLICY_AUTOMATIC and (_field(_stage, row, F_YAW_KIND) != (YAW_ALL if policy == POLICY_CANONICAL_GROUND else YAW_EXACT) \
			or _field(_stage, row, F_YAW) % 16384 != 0 \
			or mode != (MODE_WORK if policy == POLICY_SOURCE_WORK or policy == POLICY_ASSEMBLY_HANDLING else MODE_WALK)):
		return &"PROFILE_POLICY_FORMAT"
	var states: int = _field(_stage, row, F_STATES)
	if mode < MODE_STAND or mode > MODE_CLIMB or states < 1 or states > 511 \
			or (states & _required_states(mode)) != _required_states(mode):
		return &"PROFILE_STATE_MISSING"
	if _field(_stage, row, F_POSTURE) < 0 or _field(_stage, row, F_POSTURE) > POSTURE_STOOPED \
			or (_field(_stage, row, F_POSTURE) == POSTURE_STOOPED and (states & STATE_CROUCH) == 0):
		return &"PROFILE_POSTURE_MISSING"
	var code: StringName = _key_refusal(row)
	if code != &"":
		return code
	var count: int = _field(_stage, row, F_BOX_COUNT)
	if count < 3 or count > MAX_SELECTION_BOXES or _field(_stage, row, F_FIRST_BOX) != next_box \
			or next_box + count > _stage.header[2]:
		return &"PROFILE_BOX_CENSUS"
	return _roles_refusal(row, next_box, count)


func _key_refusal(row: int) -> StringName:
	"""Absent objects use exact -1 keys and zero quantity; no wildcard masks a live item."""
	var yaw_kind: int = _field(_stage, row, F_YAW_KIND)
	var yaw: int = _field(_stage, row, F_YAW)
	if yaw_kind < YAW_EXACT or yaw_kind > YAW_ALL or yaw < 0 or yaw >= 65536 \
			or (yaw_kind == YAW_ALL and yaw != 0):
		return &"PROFILE_ORIENTATION"
	if _field(_stage, row, F_MODE) == MODE_WORK and yaw_kind != YAW_EXACT:
		return &"PROFILE_CONTACT_ORIENTATION"
	if _field(_stage, row, F_FAMILIES) < 0 or _field(_stage, row, F_FAMILIES) > 31:
		return &"PROFILE_CONNECTOR_FAMILY"
	for item_field: int in [F_TOOL, F_CARGO]:
		var item: int = _field(_stage, row, item_field)
		var variant: int = _field(_stage, row, item_field + 1)
		if item < -1 or (item == -1 and variant != -1) \
				or (item_field == F_TOOL and item >= 0 and variant < 0):
			return &"PROFILE_ITEM_IDENTITY"
	var minimum: int = _long(_stage, row, L_QUANTITY_MIN)
	var maximum: int = _long(_stage, row, L_QUANTITY_MAX)
	if minimum < 0 or maximum < minimum:
		return &"PROFILE_QUANTITY"
	if (_field(_stage, row, F_CARGO) == -1 and maximum != 0) \
			or (_field(_stage, row, F_CARGO) >= 0 and minimum < 1):
		return &"PROFILE_QUANTITY"
	if _field(_stage, row, F_WORK_KIND) < -1 or _field(_stage, row, F_WORK_KIND) >= 12 \
			or _field(_stage, row, F_CONTACT_KIND) < CONTACT_NONE \
			or _field(_stage, row, F_CONTACT_KIND) > CONTACT_ASSEMBLY_PALM:
		return &"PROFILE_WORK_IDENTITY"
	if (_stage.flags[_profile_capacity + row] == POLICY_ASSEMBLY_HANDLING) \
			!= (_field(_stage, row, F_CONTACT_KIND) == CONTACT_ASSEMBLY_PALM):
		return &"PROFILE_WORK_IDENTITY"
	return &""


func _roles_refusal(profile: int, first: int, count: int) -> StringName:
	"""Require whole-body, stance and recovery; productive profiles also need explicit contact roles."""
	var mask: int = 0
	var points: int = 0
	var patches: int = 0
	var point_row: int = -1
	var patch_row: int = -1
	for row: int in range(first, first + count):
		var role: int = _stage.boxes[6 * _box_capacity + row]
		var code: StringName = _box_shape_refusal(row, role)
		if code != &"":
			return code
		mask |= 1 << role
		points += int(role == CONTACT_POINT)
		patches += int(role == CONTACT_PATCH)
		if role == CONTACT_POINT:
			point_row = row
		elif role == CONTACT_PATCH:
			patch_row = row
	var working: bool = _field(_stage, profile, F_MODE) == MODE_WORK
	if _stage.flags[_profile_capacity + profile] == POLICY_ASSEMBLY_HANDLING:
		# Curved source contact is a separate certificate, never a made-up point,
		# planar patch or productive stroke. Exact source matching remains required.
		return &"" if working and mask == 15 and _field(_stage, profile, F_WORK_KIND) == Work.JobsScript.JOB_KIND_BUILD \
			and (_field(_stage, profile, F_STATES) & STATE_REVERSAL) != 0 else &"PROFILE_ROLE_MISSING"
	if (mask & 7) != 7 or (working and ((mask & 56) != 56 or points != 1 \
			or _field(_stage, profile, F_WORK_KIND) < 0 or _field(_stage, profile, F_CONTACT_KIND) == CONTACT_NONE)):
		return &"PROFILE_ROLE_MISSING"
	if not working and (_field(_stage, profile, F_WORK_KIND) != -1 or _field(_stage, profile, F_CONTACT_KIND) != 0):
		return &"PROFILE_WORK_IDENTITY"
	return _contact_patch_refusal(profile, patches, point_row, patch_row)


func _box_shape_refusal(row: int, role: int) -> StringName:
	"""Planar contact patches are explicit data, never silently treated as empty body boxes."""
	if role < BODY_HELD_LOAD or role > CONTACT_PATCH:
		return &"PROFILE_BOX_ROLE"
	var zero_axes: int = 0
	for axis: int in 3:
		var low: int = _stage.boxes[axis * _box_capacity + row]
		var high: int = _stage.boxes[(axis + 3) * _box_capacity + row]
		if low > high:
			return &"PROFILE_BOX_FORMAT"
		zero_axes += int(low == high)
	var expected: int = 3 if role == CONTACT_POINT else (1 if role == CONTACT_PATCH else 0)
	return &"" if zero_axes == expected else &"PROFILE_BOX_FORMAT"


func _contact_patch_refusal(profile: int, count: int, point: int, patch: int) -> StringName:
	"""The stronger contact kind requires one source patch and its exact coplanar anchor."""
	if _field(_stage, profile, F_CONTACT_KIND) != CONTACT_ANCHOR_AND_PATCH:
		return &"" if count == 0 else &"PROFILE_CONTACT_PATCH_KIND"
	if count != 1 or point < 0 or patch < 0:
		return &"PROFILE_CONTACT_PATCH_MISSING"
	for axis: int in 3:
		var value: int = _stage.boxes[axis * _box_capacity + point]
		if value < _stage.boxes[axis * _box_capacity + patch] \
				or value > _stage.boxes[(axis + 3) * _box_capacity + patch]:
			return &"PROFILE_CONTACT_PATCH_ANCHOR"
	return &""


func _overlap_keys(a: int, b: int) -> bool:
	"""Two matching exact physical keys with intersecting quantity/yaw are ambiguous even off connectors."""
	if _stage.flags[_profile_capacity + a] != _stage.flags[_profile_capacity + b]:
		return false
	for field: int in range(F_SPECIES, F_CARGO_VARIANT + 1):
		if _field(_stage, a, field) != _field(_stage, b, field):
			return false
	if _field(_stage, a, F_WORK_KIND) != _field(_stage, b, F_WORK_KIND):
		return false
	if _long(_stage, a, L_QUANTITY_MIN) > _long(_stage, b, L_QUANTITY_MAX) \
			or _long(_stage, b, L_QUANTITY_MIN) > _long(_stage, a, L_QUANTITY_MAX):
		return false
	return _field(_stage, a, F_YAW_KIND) == YAW_ALL or _field(_stage, b, F_YAW_KIND) == YAW_ALL \
		or _field(_stage, a, F_YAW) == _field(_stage, b, F_YAW)


func query_into(worker: Vector2i, job: Vector2i, mode: int, posture: int, connector_family: int,
		equipped_tool_hint: Vector2i, out: Selection) -> StringName:
	"""Read the unique current match; multiple WORK contacts never select by file order."""
	var code: StringName = _prepare_query(worker, job, mode, posture, connector_family, equipped_tool_hint, out)
	if code != &"":
		return code
	# ADR1198: per-source sorted blocks may interleave, so automatic lookup scans every row (<= MAX_PROFILES);
	# any second automatic match anywhere is ambiguous rather than file-order selected.
	var selected: int = -1
	for row: int in _live.header[1]:
		if _field(_live, row, F_MODE) != mode or _live.flags[_profile_capacity + row] != POLICY_AUTOMATIC: continue
		if _matches(row, mode, posture, connector_family):
			if selected >= 0:
				return &"PROFILE_SELECTION_AMBIGUOUS"
			selected = row
	if selected < 0:
		return &"PROFILE_VARIANT_UNAUTHORED"
	_write_selection(selected, worker, job, out)
	return &""


func selection_policy_of(profile_id: int, profile_revision: int, revision: int) -> int:
	"""Read this exact immutable row's versioned selection policy; no source phase or motion is granted."""
	return selection_policy_leaf(self, profile_id, profile_revision, revision)


static func selection_policy_leaf(actual: RefCounted, profile_id: int, profile_revision: int, revision: int) -> int:
	"""The final boundary reads stored columns directly, never a caller-overridable catalog getter."""
	if actual == null or actual._loading or revision <= 0 or revision != actual._live.header[0] \
			or profile_id < 0 or profile_id >= actual._live.header[1] \
			or profile_revision <= 0 or profile_revision != actual._live.quantities[L_REVISION * actual._profile_capacity + profile_id]:
		return -1
	var policy: int = actual._live.flags[actual._profile_capacity + profile_id]
	return policy if policy <= POLICY_ASSEMBLY_HANDLING else -1


func query_travel_profile_into(worker: Vector2i, job: Vector2i, profile_id: int, profile_revision: int,
		revision: int, posture: int, connector_family: int, equipped_tool_hint: Vector2i, out: Selection) -> StringName:
	"""Explicit source travel still proves the actual current actor, Job, tool, cargo and orientation."""
	var policy: int = selection_policy_leaf(self, profile_id, profile_revision, revision)
	if policy < POLICY_READY_FORWARD or policy > POLICY_CANONICAL_GROUND or policy == POLICY_SOURCE_WORK:
		return &"PROFILE_TRAVEL_SELECTION_REQUIRED"
	var code: StringName = _prepare_query(worker, job, MODE_WALK, posture, connector_family, equipped_tool_hint, out)
	if code != &"":
		return code
	if not _matches(profile_id, MODE_WALK, posture, connector_family):
		return &"PROFILE_VARIANT_UNAUTHORED"
	_write_selection(profile_id, worker, job, out)
	return &""


func query_work_profile_into(worker: Vector2i, job: Vector2i, profile_id: int, profile_revision: int,
		revision: int, posture: int, connector_family: int, equipped_tool_hint: Vector2i, out: Selection) -> StringName:
	"""Choose an exact authored WORK contact while rechecking the actual assigned Job, tool, load and yaw."""
	if revision <= 0 or revision != content_revision() or profile_id < 0 \
			or profile_id >= _live.header[1] or profile_revision != _long(_live, profile_id, L_REVISION):
		return &"PROFILE_SELECTION_STALE"
	if _field(_live, profile_id, F_MODE) != MODE_WORK:
		return &"PROFILE_WORK_SELECTION_REQUIRED"
	var code: StringName = _prepare_query(worker, job, MODE_WORK, posture, connector_family, equipped_tool_hint, out)
	if code != &"":
		return code
	if not _matches(profile_id, MODE_WORK, posture, connector_family):
		return &"PROFILE_VARIANT_UNAUTHORED"
	_write_selection(profile_id, worker, job, out)
	return &""


func _prepare_query(worker: Vector2i, job: Vector2i, mode: int, posture: int, connector_family: int,
		equipped_tool_hint: Vector2i, out: Selection) -> StringName:
	"""Both selection paths use the same actual owners and reusable scratch; no output writes on refusal."""
	if out == null or _residents == null or content_revision() == 0 or not _owners_current():
		return &"PROFILE_OWNER_UNBOUND"
	if mode < MODE_STAND or mode > MODE_CLIMB or posture < 0 or posture > POSTURE_STOOPED \
			or connector_family < -1 or connector_family >= 5:
		return &"PROFILE_QUERY_FORMAT"
	if not _residents.spatial_profile_identity_into(worker, _identity) \
			or not _transforms.read_into(worker, _pose):
		return &"PROFILE_WORKER_STALE"
	_worker_row = _residents.directory().get_typed_row(worker)
	if not _residents.is_alive(_worker_row):
		return &"PROFILE_WORKER_STALE"
	if _pose.yaw < 0 or _pose.yaw >= 65536:
		return &"PROFILE_ORIENTATION"
	return _read_dynamic(worker, job, mode, equipped_tool_hint)


func _read_dynamic(worker: Vector2i, job: Vector2i, mode: int, hint: Vector2i) -> StringName:
	"""Scratch only: exact Job pairing, actual Work tool and actual carried lot are not caller fields."""
	_query_values.fill(-1)
	_candidate.tool = NULL_REF
	_candidate.satchel = NULL_REF
	_candidate.cargo = NULL_REF
	_candidate.cargo_quantity_milli = 0
	if job != NULL_REF:
		var ids: Directory = _residents.directory()
		if not ids.is_valid_of_kind(job, Directory.KIND_JOB):
			return &"PROFILE_JOB_STALE"
		var row: int = ids.get_typed_row(job)
		if _work.jobs().ref_of(row) != job or _work.jobs().job_of(_worker_row) != job \
				or _work.jobs().worker_of(row) != worker:
			return &"PROFILE_JOB_STALE"
		if mode == MODE_WORK:
			if not _work.jobs().kind_into(row, _math):
				return &"PROFILE_JOB_STALE"
			_query_values[4] = _math.value
	elif mode == MODE_WORK:
		return &"PROFILE_JOB_REQUIRED"
	var code: StringName = _read_tool(worker, job, mode, hint)
	return _read_cargo(worker) if code == &"" else code


func _read_tool(worker: Vector2i, job: Vector2i, mode: int, hint: Vector2i) -> StringName:
	"""A hint only locates an actual equipped record; null cannot hide resident equipment."""
	var tool: Vector2i = _work.tool_lot_of(_worker_row)
	if tool != NULL_REF and hint != NULL_REF and tool != hint:
		return &"PROFILE_TOOL_MISMATCH"
	if tool == NULL_REF:
		tool = hint
	if tool == NULL_REF:
		return &"PROFILE_TOOL_REQUIRED" if _residents.has_equipped_tool(_worker_row) else &""
	if not _gear.is_equipped_record(tool) or _gear.owner_of(tool) != worker \
			or not _inventory.is_lot_equipped(tool) or not _gear.item_id_into(tool, _math):
		return &"PROFILE_TOOL_STALE"
	_query_values[0] = _math.value
	if not _residents.equipped_tool_item_id_into(_worker_row, _math) or _math.value != _query_values[0] \
			or not _gear.manufacture_into(tool, _math):
		return &"PROFILE_TOOL_MISMATCH"
	_query_values[1] = _math.value
	if mode == MODE_WORK and (_work.tool_job_of(_worker_row) != job \
			or _gear.equipped_work_claim_refusal(tool, worker, job) != &""):
		return &"PROFILE_TOOL_CLAIM"
	_candidate.tool = tool
	return &""


func _read_cargo(_worker: Vector2i) -> StringName:
	"""Retain real quantity/recipe and full satchel/lot identities; stale or multiple lots refuse."""
	var stored: Vector2i = _residents.satchel_of(_worker_row)
	var satchel: Vector2i = _carry.satchel_of(_worker_row)
	if stored != satchel:
		return &"PROFILE_CARGO_STALE"
	_candidate.satchel = satchel
	if satchel == NULL_REF:
		return &""
	var count: int = _inventory.container_lot_count(satchel)
	if count == 0:
		return &""
	if count != 1:
		return &"PROFILE_CARGO_MULTIPLE"
	var lot: Vector2i = _carry.carried_lot(_worker_row)
	if not _inventory.is_lot_valid(lot) or _inventory.lot_container(lot) != satchel \
			or _inventory.container_next_lot(lot) != NULL_REF or _inventory.lot_quantity_milli(lot) < 1:
		return &"PROFILE_CARGO_STALE"
	_candidate.cargo = lot
	_candidate.cargo_quantity_milli = _inventory.lot_quantity_milli(lot)
	_query_values[2] = _inventory.lot_item_id(lot)
	_query_values[3] = _inventory.lot_recipe_id(lot)
	return &""


func _matches(row: int, mode: int, posture: int, family: int) -> bool:
	"""Bounded exact integer selection; all-yaw certificates explicitly cover continuous turns."""
	for index: int in 3:
		if _field(_live, row, F_SPECIES + index) != _identity[index]:
			return false
	if _field(_live, row, F_MODE) != mode or _field(_live, row, F_POSTURE) != posture:
		return false
	for index: int in 4:
		if _field(_live, row, F_TOOL + index) != _query_values[index]:
			return false
	if _field(_live, row, F_WORK_KIND) != _query_values[4]:
		return false
	var quantity: int = _candidate.cargo_quantity_milli
	if quantity < _long(_live, row, L_QUANTITY_MIN) or quantity > _long(_live, row, L_QUANTITY_MAX):
		return false
	if _field(_live, row, F_YAW_KIND) == YAW_EXACT and _field(_live, row, F_YAW) != _pose.yaw:
		return false
	return family == -1 or (_field(_live, row, F_FAMILIES) & (1 << family)) != 0


func _write_selection(row: int, worker: Vector2i, job: Vector2i, out: Selection) -> void:
	"""Publish all scratch only after a complete matching current-owner read."""
	out.profile_id = row
	out.profile_revision = _long(_live, row, L_REVISION)
	out.content_revision = content_revision()
	out.source_id = _field(_live, row, F_SOURCE)
	out.species = _identity[0]
	out.life_stage = _identity[1]
	out.rig = _identity[2]
	out.mode = _field(_live, row, F_MODE)
	out.posture = _field(_live, row, F_POSTURE)
	out.x = _pose.x
	out.y = _pose.y
	out.z = _pose.z
	out.yaw = _pose.yaw
	out.orientation = _field(_live, row, F_YAW_KIND)
	out.box_count = _field(_live, row, F_BOX_COUNT)
	out.worker = worker
	out.job = job
	out.tool = _candidate.tool
	out.satchel = _candidate.satchel
	out.cargo = _candidate.cargo
	out.cargo_quantity_milli = _candidate.cargo_quantity_milli


func box_into(profile_id: int, profile_revision: int, revision: int, ordinal: int, out: Box) -> StringName:
	"""No allocation or narrowing before full profile/content identity and ordinal checks."""
	if out == null or revision != content_revision() or revision <= 0 or profile_id < 0 \
			or profile_id >= _live.header[1] or profile_revision != _long(_live, profile_id, L_REVISION):
		return &"PROFILE_SELECTION_STALE"
	if ordinal < 0 or ordinal >= _field(_live, profile_id, F_BOX_COUNT):
		return &"PROFILE_BOX_ORDINAL"
	var row: int = _field(_live, profile_id, F_FIRST_BOX) + ordinal
	out.low = Vector3i(_live.boxes[row], _live.boxes[_box_capacity + row], _live.boxes[2 * _box_capacity + row])
	out.high = Vector3i(_live.boxes[3 * _box_capacity + row], _live.boxes[4 * _box_capacity + row],
		_live.boxes[5 * _box_capacity + row])
	out.role = _live.boxes[6 * _box_capacity + row]
	return &""


func profile_count(revision: int) -> int:
	"""Bound a cold admission search in this exact content version; -1 means absent or stale."""
	return int(_live.header[1]) if revision > 0 and revision == content_revision() else -1


func descriptor_into(profile_id: int, revision: int, out: Descriptor) -> StringName:
	"""Read immutable content before a Job exists; actual START/WORK still require query_into."""
	if out == null or revision <= 0 or revision != content_revision() \
			or profile_id < 0 or profile_id >= _live.header[1]:
		return &"PROFILE_SELECTION_STALE"
	out.profile_id = profile_id
	out.profile_revision = _long(_live, profile_id, L_REVISION)
	out.content_revision = revision
	out.source_id = _field(_live, profile_id, F_SOURCE)
	out.species = _field(_live, profile_id, F_SPECIES)
	out.life_stage = _field(_live, profile_id, F_STAGE)
	out.rig = _field(_live, profile_id, F_RIG)
	out.mode = _field(_live, profile_id, F_MODE)
	out.posture = _field(_live, profile_id, F_POSTURE)
	out.tool_item = _field(_live, profile_id, F_TOOL)
	out.tool_variant = _field(_live, profile_id, F_TOOL_VARIANT)
	out.cargo_item = _field(_live, profile_id, F_CARGO)
	out.cargo_variant = _field(_live, profile_id, F_CARGO_VARIANT)
	out.quantity_min_milli = _long(_live, profile_id, L_QUANTITY_MIN)
	out.quantity_max_milli = _long(_live, profile_id, L_QUANTITY_MAX)
	_write_descriptor_geometry(profile_id, out)
	return &""


func _write_descriptor_geometry(row: int, out: Descriptor) -> void:
	"""All output checks precede the first write; these are authored constraints, not live facts."""
	out.yaw_kind = _field(_live, row, F_YAW_KIND)
	out.yaw = _field(_live, row, F_YAW)
	out.family_mask = _field(_live, row, F_FAMILIES)
	out.state_mask = _field(_live, row, F_STATES)
	out.work_kind = _field(_live, row, F_WORK_KIND)
	out.contact_kind = _field(_live, row, F_CONTACT_KIND)
	out.box_count = _field(_live, row, F_BOX_COUNT)
	out.certificate_flags = _live.flags[row]


func source_hash_into(source_id: int, revision: int, out: PackedByteArray) -> bool:
	"""Fill exact digest scratch only for this immutable content version; no caller aliases a bank."""
	if revision <= 0 or revision != content_revision() or source_id < 0 \
			or source_id >= _live.header[3] or out.size() != 32:
		return false
	for index: int in 32:
		out[index] = _live.sources[source_id * 32 + index]
	return true


func body_extent_into(revision: int, out: PackedInt32Array) -> StringName:
	"""Cold broadphase union of every body/load and recovery variant; this grants no selection permission."""
	if out.size() != 6:
		return &"PROFILE_EXTENT_FORMAT"
	if revision <= 0 or revision != content_revision():
		return &"PROFILE_SELECTION_STALE"
	var low: Vector3i = Vector3i(2147483647, 2147483647, 2147483647)
	var high: Vector3i = Vector3i(-2147483648, -2147483648, -2147483648)
	var found: bool = false
	var row: int = 0
	while row < _live.header[2]:
		var role: int = _live.boxes[6 * _box_capacity + row]
		if role == BODY_HELD_LOAD or role == TURN_RECOVERY:
			found = true
			for axis: int in 3:
				low[axis] = mini(low[axis], _live.boxes[axis * _box_capacity + row])
				high[axis] = maxi(high[axis], _live.boxes[(axis + 3) * _box_capacity + row])
		row += 1
	if not found:
		return &"PROFILE_ROLE_MISSING"
	for axis: int in 3:
		out[axis] = low[axis]
		out[axis + 3] = high[axis]
	return &""


func _owners_current() -> bool:
	"""Refuse collaborator rebinding immediately, including worlds with equal reference numbers."""
	return _transforms.is_bound_directory(_residents.directory()) \
		and _gear.equipment_binding_matches(_inventory, _residents.directory(), _residents) \
		and _carry.binding_matches(_inventory, _reservations, _residents, _piles) \
		and _work.residents() == _residents and _work.gear() == _gear \
		and _work.jobs() != null and _work.jobs().residents() == _residents \
		and _work.jobs().directory() == _residents.directory() \
		and _reservations.inventory_binding_refusal(_inventory) == &""


func _key_field(index: int) -> int:
	"""Fixed exact selection prefix; authored sorted rows keep hot lookup bounded."""
	return F_SPECIES + index if index < 9 else F_WORK_KIND


func _compare_rows(a: int, b: int) -> int:
	"""Lexicographic physical identity before quantity/orientation variants."""
	for index: int in 10:
		var field: int = _key_field(index)
		var left: int = _field(_stage, a, field)
		var right: int = _field(_stage, b, field)
		if left != right:
			return -1 if left < right else 1
	return 0


func _required_states(mode: int) -> int:
	"""The certificate must close entry, reversal and recovery for a moving selection."""
	if mode == MODE_STAND:
		return STATE_IDLE | STATE_RECOVERY
	if mode == MODE_WORK:
		return STATE_IDLE | STATE_WORK | STATE_ENTRY | STATE_RECOVERY
	var main: int = STATE_CLIMB if mode == MODE_CLIMB else (1 << mode)
	return STATE_IDLE | main | STATE_ENTRY | STATE_REVERSAL | STATE_RECOVERY
