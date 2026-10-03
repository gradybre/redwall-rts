extends RefCounted
## Sparse actual underground geometry. Identity, paid work and profile qualification remain with
## their real owners. A prepared image is invisible until its synchronous, non-failing publication.
## Region handles are internal (row,generation) values, NEVER global EntityRefs. Decision 1064.

const Space := preload("res://scripts/core/room_space.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const ModularContract := preload("res://scripts/core/modular_project_contract.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const MAX_REGIONS: int = Space.MAX_REGIONS
const HEADER_FIELDS: int = 18
const SCHEMA: int = 1
const I32_MAX: int = 2147483647
const I64_MAX: int = 9223372036854775807
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REGION_BYTES: int = 68
const SOURCE_BYTES: int = 42
const CLAIM_NONE: int = 0
const CLAIM_CONSTRUCTION: int = 1
const CLAIM_ROOM: int = 2
const LOOKUP_BUDGET: int = -2
const SNAPSHOT_COPY_CONTROL_BYTES: int = 256

class Facts extends RefCounted:
	## Exact source-kind facts; one caller-owned scratch object, not one object per entity.
	var kind: int = -1
	var parent: Vector2i = NULL_REF
	var a: int = 0
	var b: int = 0
	var c: int = 0
	var d: int = 0

	func clear() -> void:
		"""Canonical absence prevents a refused source read from retaining another owner's facts."""
		kind = -1
		parent = NULL_REF
		a = 0
		b = 0
		c = 0
		d = 0

class Sources extends RefCounted:
	## Trusted identity boundary, never a UI callback. The base has no permissive implementation.
	func directory() -> Directory:
		"""Return the actual global directory, or no binding."""
		return null

	func construction_owner() -> Construction:
		"""No project/physical-site owner is bound by the abstract source reader."""
		return null

	func read_into(_ref: Vector2i, out: Facts) -> StringName:
		"""Supply exact owner-kind facts from actual stores; absent bindings refuse."""
		out.clear()
		return &"SPACE_SOURCE_UNBOUND"

class ResidentLocations extends RefCounted:
	## Actual multilevel movement/containment reader. Flat tile location is insufficient.
	func directory() -> Directory:
		"""Return the actual shared directory; an unbound location owner supplies none."""
		return null

	func read_into(_resident: Vector2i, out: Facts) -> StringName:
		"""Read real XYZ, mode and containing Room into exact facts; no guessed Y or posture."""
		out.clear()
		return &"SPACE_RESIDENT_LOCATION_UNBOUND"

class CoreSources extends Sources:
	## Actual core records, including explicit UG07 Room domain and paid installation status.
	var _directory: Directory = null
	var _buildings: Buildings = null
	var _construction: Construction = null
	var _locations: ResidentLocations = null
	var _number: IntMath.IntResult = IntMath.IntResult.new()
	var _room_identity: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])

	func _init(ids: Directory, buildings: Buildings, construction: Construction = null,
			locations: ResidentLocations = null) -> void:
		"""Borrow matching actual stores; an inconsistent binding stays unavailable."""
		if ids != null and buildings != null and buildings.directory() == ids \
				and (construction == null or (construction.directory() == ids and construction.buildings() == buildings)) \
				and (locations == null or locations.directory() == ids):
			_directory = ids
			_buildings = buildings
			_construction = construction
			_locations = locations

	func directory() -> Directory:
		"""The directory owns every global generation used by this source reader."""
		return _directory

	func construction_owner() -> Construction:
		"""Borrow the actual Construction instance, never infer it from coincident ref numbers."""
		return _construction

	func resident_locations_owner() -> ResidentLocations:
		"""Borrow the exact multilevel location owner; an absent or rejected binding remains null."""
		return _locations

	func read_into(ref: Vector2i, out: Facts) -> StringName:
		"""Normal observations retain the actual multilevel Resident callback boundary."""
		if _directory != null and _directory.is_valid_of_kind(ref, Directory.KIND_RESIDENT):
			out.clear()
			out.kind = Directory.KIND_RESIDENT
			return _locations.read_into(ref, out) if _locations != null else &"SPACE_RESIDENT_LOCATION_UNBOUND"
		return read_leaf_into(self, ref, out)

	static func read_leaf_into(reader: CoreSources, ref: Vector2i, out: Facts) -> StringName:
		"""Read actual non-Resident stores without invoking Sources or Resident observation hooks."""
		out.clear()
		if reader == null or reader._directory == null or not reader._directory.is_valid(ref):
			return &"SPACE_SOURCE_STALE"
		out.kind = reader._directory.get_kind(ref)
		match out.kind:
			Directory.KIND_WORLD:
				return &""
			Directory.KIND_BUILDING:
				return _building(reader, ref, out)
			Directory.KIND_ROOM:
				return _room(reader, ref, out)
			Directory.KIND_FURNITURE:
				return _furniture(reader, ref, out)
			Directory.KIND_CONSTRUCTION:
				return _project(reader, ref, out)
		return &"SPACE_SOURCE_KIND_UNBOUND"

	static func _building(reader: CoreSources, ref: Vector2i, out: Facts) -> StringName:
		"""Ground tile facts are identity guards, never underground coordinates."""
		if not reader._buildings.is_live_building(ref):
			return &"SPACE_SOURCE_STALE"
		out.a = reader._buildings.type_id_of_building(ref).value
		out.b = reader._buildings.origin_tile_of_building(ref).value
		out.c = reader._buildings.rotation_of_building(ref).value
		out.d = reader._buildings.interior_id_of_building(ref).value
		return &""

	static func _room(reader: CoreSources, ref: Vector2i, out: Facts) -> StringName:
		"""Preserve immutable purpose/domain; underground identity never borrows a flat tile address."""
		if not reader._buildings.is_live_room(ref):
			return &"SPACE_SOURCE_STALE"
		if reader._buildings.room_identity_into(ref, reader._room_identity) != &"":
			return &"SPACE_SOURCE_FACTS"
		out.parent = Vector2i(reader._room_identity[2], reader._room_identity[3])
		out.a = reader._room_identity[1]
		out.d = reader._room_identity[0]
		if out.d == Buildings.ROOM_SPACE_SURFACE:
			out.b = reader._room_identity[4]
			out.c = reader._room_identity[5]
		return &""

	static func _furniture(reader: CoreSources, ref: Vector2i, out: Facts) -> StringName:
		"""Pin actual installation and orientation; only surface pieces have a tile-origin fact."""
		if not reader._buildings.is_live_furniture(ref):
			return &"SPACE_SOURCE_STALE"
		out.parent = reader._buildings.room_ref_of_furniture(ref)
		var domain: Buildings.OpResult = reader._buildings.spatial_kind_of_room(out.parent)
		if not domain.ok:
			return &"SPACE_SOURCE_FACTS"
		out.a = reader._buildings.type_id_of_furniture(ref).value
		out.b = Buildings.NO_LINK
		if domain.value == Buildings.ROOM_SPACE_SURFACE:
			var origin: Buildings.OpResult = reader._buildings.origin_tile_of_furniture(ref)
			if not origin.ok:
				return &"SPACE_SOURCE_FACTS"
			out.b = origin.value
		out.c = reader._buildings.rotation_of_furniture(ref).value
		out.d = 1 if reader._buildings.is_furniture_installed(ref) else 0
		return &""

	static func _project(reader: CoreSources, ref: Vector2i, out: Facts) -> StringName:
		"""Construction subject remains in its own documented namespace, including physical sites."""
		if reader._construction == null or not reader._construction.is_live_project(ref):
			return &"SPACE_SOURCE_STALE"
		out.parent = reader._construction.subject_ref_of(ref)
		reader._construction.purpose_into(ref, reader._number)
		out.a = reader._number.value
		reader._construction.type_id_into(ref, reader._number)
		out.b = reader._number.value
		return &""

class Region extends RefCounted:
	## Caller-owned input/output packet; the actual store contains only packed columns.
	var box: PackedInt32Array = PackedInt32Array()
	var role: int = -1
	var level: int = -1
	var owner: Vector2i = NULL_REF
	var section: Vector2i = NULL_REF
	var claim_ref: Vector2i = NULL_REF
	var claim_kind: int = CLAIM_NONE

class Result extends RefCounted:
	var error: StringName = &""
	var token: int = 0
	var handle: Vector2i = NULL_REF

	func _init(code: StringName = &"", stage_token: int = 0, ref: Vector2i = NULL_REF) -> void:
		"""Separate transaction token, internal region handle and explicit refusal."""
		error = code
		token = stage_token
		handle = ref

	func ok() -> bool:
		"""No partial result is usable after refusal."""
		return error == &""

var _sources: Sources = null
var _domain: Space.Domain = null
var _region_capacity: int = 0
var _source_capacity: int = 0
var _ready_error: StringName = &"SPACE_WORLD_UNBOUND"
var _region_free_count: int = 0
var _source_free_count: int = 0
var _s_region_free_count: int = 0
var _s_source_free_count: int = 0
var _next_token: int = 1
var _stage_token: int = 0
var _last_published_token: int = 0
var _installation_context: WeakRef = null
var _sealed: bool = false
var _remaining: int = 0
var _changed_count: int = 0
## During cold validation only, staged heap storage holds compact region/source indexes.
var _validation_regions: int = -1
var _validation_sources: int = -1
var _changed_rows: PackedInt32Array = PackedInt32Array()
var _changed_mask: PackedByteArray = PackedByteArray()
var _facts: Facts = Facts.new()
var _header: PackedInt64Array = PackedInt64Array()
var _s_header: PackedInt64Array = PackedInt64Array()
var _region_free_heap: PackedInt32Array = PackedInt32Array()
var _source_free_heap: PackedInt32Array = PackedInt32Array()
var _s_region_free_heap: PackedInt32Array = PackedInt32Array()
var _s_source_free_heap: PackedInt32Array = PackedInt32Array()
var _r_present: PackedByteArray = PackedByteArray()
var _r_retired: PackedByteArray = PackedByteArray()
var _r_role: PackedByteArray = PackedByteArray()
var _r_claim_kind: PackedByteArray = PackedByteArray()
var _r_generation: PackedInt32Array = PackedInt32Array()
var _r_lo_x: PackedInt32Array = PackedInt32Array()
var _r_lo_y: PackedInt32Array = PackedInt32Array()
var _r_lo_z: PackedInt32Array = PackedInt32Array()
var _r_hi_x: PackedInt32Array = PackedInt32Array()
var _r_hi_y: PackedInt32Array = PackedInt32Array()
var _r_hi_z: PackedInt32Array = PackedInt32Array()
var _r_level: PackedInt32Array = PackedInt32Array()
var _r_section_slot: PackedInt32Array = PackedInt32Array()
var _r_section_generation: PackedInt32Array = PackedInt32Array()
var _r_owner_slot: PackedInt32Array = PackedInt32Array()
var _r_owner_generation: PackedInt32Array = PackedInt32Array()
var _r_owner_revision: PackedInt64Array = PackedInt64Array()
var _r_claim_slot: PackedInt32Array = PackedInt32Array()
var _r_claim_generation: PackedInt32Array = PackedInt32Array()
var _o_present: PackedByteArray = PackedByteArray()
var _o_kind: PackedByteArray = PackedByteArray()
var _o_slot: PackedInt32Array = PackedInt32Array()
var _o_generation: PackedInt32Array = PackedInt32Array()
var _o_revision: PackedInt64Array = PackedInt64Array()
var _o_parent_slot: PackedInt32Array = PackedInt32Array()
var _o_parent_generation: PackedInt32Array = PackedInt32Array()
var _o_a: PackedInt32Array = PackedInt32Array()
var _o_b: PackedInt32Array = PackedInt32Array()
var _o_c: PackedInt32Array = PackedInt32Array()
var _o_d: PackedInt32Array = PackedInt32Array()
var _s_r_present: PackedByteArray = PackedByteArray()
var _s_r_retired: PackedByteArray = PackedByteArray()
var _s_r_role: PackedByteArray = PackedByteArray()
var _s_r_claim_kind: PackedByteArray = PackedByteArray()
var _s_r_generation: PackedInt32Array = PackedInt32Array()
var _s_r_lo_x: PackedInt32Array = PackedInt32Array()
var _s_r_lo_y: PackedInt32Array = PackedInt32Array()
var _s_r_lo_z: PackedInt32Array = PackedInt32Array()
var _s_r_hi_x: PackedInt32Array = PackedInt32Array()
var _s_r_hi_y: PackedInt32Array = PackedInt32Array()
var _s_r_hi_z: PackedInt32Array = PackedInt32Array()
var _s_r_level: PackedInt32Array = PackedInt32Array()
var _s_r_section_slot: PackedInt32Array = PackedInt32Array()
var _s_r_section_generation: PackedInt32Array = PackedInt32Array()
var _s_r_owner_slot: PackedInt32Array = PackedInt32Array()
var _s_r_owner_generation: PackedInt32Array = PackedInt32Array()
var _s_r_owner_revision: PackedInt64Array = PackedInt64Array()
var _s_r_claim_slot: PackedInt32Array = PackedInt32Array()
var _s_r_claim_generation: PackedInt32Array = PackedInt32Array()
var _s_o_present: PackedByteArray = PackedByteArray()
var _s_o_kind: PackedByteArray = PackedByteArray()
var _s_o_slot: PackedInt32Array = PackedInt32Array()
var _s_o_generation: PackedInt32Array = PackedInt32Array()
var _s_o_revision: PackedInt64Array = PackedInt64Array()
var _s_o_parent_slot: PackedInt32Array = PackedInt32Array()
var _s_o_parent_generation: PackedInt32Array = PackedInt32Array()
var _s_o_a: PackedInt32Array = PackedInt32Array()
var _s_o_b: PackedInt32Array = PackedInt32Array()
var _s_o_c: PackedInt32Array = PackedInt32Array()
var _s_o_d: PackedInt32Array = PackedInt32Array()

## One synchronous pending->installed source candidate, never per-Furniture persistent state.
var _install_row: int = -1
var _install_project: Vector2i = NULL_REF
var _install_router: WeakRef = null
var _install_owner: WeakRef = null
var _install_number: IntMath.IntResult = IntMath.IntResult.new()
## One exact future Room observation; its mutable caller packet is never the pinned identity.
var _room_candidate: Directory.CreateCandidate = Directory.CreateCandidate.new()
var _room_input: WeakRef = null
var _room_authority: WeakRef = null
var _room_row: int = -1
var _room_type: int = -1
var _room_callback: bool = false
var _room_reentered: bool = false
## One admitted cold batch: private5-column paired tuples, layout entries and source-row index.
var _furniture_count: int = 0
var _furniture_room: Vector2i = NULL_REF
var _furniture_input: WeakRef = null
var _furniture_authority: WeakRef = null
var _furniture_input_entries: PackedInt32Array = PackedInt32Array()
var _furniture_pins: PackedInt32Array = PackedInt32Array()
var _furniture_entries: PackedInt32Array = PackedInt32Array()
var _furniture_rows: PackedInt32Array = PackedInt32Array()
const FURNITURE_GEOMETRY_SEEN: int = 1073741824



func _init(sources: Sources) -> void:
	"""Borrow one trusted source reader; configuration performs every finite allocation."""
	_sources = sources


func configure(domain: Space.Domain, region_rows: int, source_capacity: int) -> StringName:
	"""Register one immutable actual domain; no inferred floor count or permissive source defaults."""
	if _domain != null:
		return &"SPACE_WORLD_ALREADY_BOUND"
	if domain == null or _sources == null or _sources.directory() == null:
		return _ready_error
	var binding: Dictionary = domain.descriptor()
	if binding.bounds_u.is_empty() or region_rows < 1 or region_rows > binding.max_regions \
			or source_capacity < 1 or source_capacity > binding.max_regions:
		return &"SPACE_WORLD_CAPACITY"
	var code: StringName = _read_source(binding.world_ref)
	if code != &"" or _facts.kind != Directory.KIND_WORLD:
		return &"SPACE_WORLD_IDENTITY"
	_region_capacity = region_rows
	_source_capacity = source_capacity
	_allocate_columns()
	_write_header(binding)
	_domain = _copy_domain(binding)
	_initialize_free_rows()
	_bind_initial_world(binding.world_ref)
	_ready_error = &""
	return &""


func initialization_refusal() -> StringName:
	"""Expose missing actual bindings without pretending the empty world is safe."""
	return _ready_error


func allocation_within(region_limit: int, source_limit: int) -> bool:
	"""Attest actual finite allocations before a composer reserves any capacity-dependent cold copy."""
	return _ready_error == &"" and _region_capacity > 0 and _source_capacity > 0 \
		and _region_capacity <= region_limit and _source_capacity <= source_limit


func is_bound_sources(candidate: Sources) -> bool:
	"""An adapter must share this exact source reader, not merely coincident numeric references."""
	return candidate != null and candidate == _sources and _ready_error == &""


func domain_copy() -> Space.Domain:
	"""No caller can modify the cached domain that guards future transactions."""
	return _copy_domain(_domain.descriptor()) if _domain != null else null


static func _copy_domain(binding: Dictionary) -> Space.Domain:
	"""Build a derived immutable value from a validated domain descriptor."""
	var out: Space.Domain = Space.Domain.new()
	var code: StringName = out.configure(binding.world_ref, binding.datum_u, binding.min_quantum,
		binding.size_quanta, binding.max_cells, binding.max_regions, binding.max_checks)
	assert(code == &"", "validated domain must copy exactly")
	return out


func _write_header(binding: Dictionary) -> void:
	"""Eighteen int64 slots have a fixed wire/hash order; no reserved fields hide future state."""
	_header[0] = SCHEMA
	_header[1] = _region_capacity
	_header[2] = _source_capacity
	_header[3] = binding.world_ref.x
	_header[4] = binding.world_ref.y
	for axis: int in 3:
		_header[5 + axis] = binding.datum_u[axis]
		_header[8 + axis] = binding.min_quantum[axis]
		_header[11 + axis] = binding.size_quanta[axis]
	_header[14] = binding.max_cells
	_header[15] = binding.max_regions
	_header[16] = binding.max_checks
	_header[17] = 1


func _initialize_free_rows() -> void:
	"""Ascending arrays are valid min-heaps; new generations begin at zero until first allocation."""
	for row: int in _region_capacity:
		_region_free_heap[row] = row
		_clear_region(row, false)
		_clear_region(row, true)
	for row: int in _source_capacity:
		_source_free_heap[row] = row
		_clear_source(row, false)
		_clear_source(row, true)
	_region_free_count = _region_capacity
	_source_free_count = _source_capacity


func _bind_initial_world(ref: Vector2i) -> void:
	"""The real world identity is always represented even before any terrain is surveyed."""
	var row: int = _heap_pop(_source_free_heap, _source_free_count)
	_source_free_count -= 1
	_o_present[row] = 1
	_o_slot[row] = ref.x
	_o_generation[row] = ref.y
	_o_revision[row] = 1
	_o_kind[row] = Directory.KIND_WORLD


func revision() -> int:
	"""A proof token compares the world revision, never a frame or elapsed wall time."""
	return _header[17] if _ready_error == &"" else 0


func last_published_token() -> int:
	"""Identify this owner's exact completed candidate; a successful load invalidates this unsaved receipt."""
	return _last_published_token


func region_capacity() -> int:
	"""Expose the actual admitted sparse row count for bounded cold scratch, never a gameplay room limit."""
	return _region_capacity if _ready_error == &"" else 0


func has_prepared() -> bool:
	"""Saving and other geometry writers must wait until this synchronous transaction ends."""
	return _stage_token != 0


func begin_stage(expected_revision: int) -> Result:
	"""Copy only after every finite/counter preflight; failed preparation leaves live bytes intact."""
	if _reject_room_reentry():
		return Result.new(&"SPACE_ROOM_ADMISSION_REENTRY")
	if _ready_error != &"":
		return Result.new(_ready_error)
	if has_prepared() or _validation_sources >= 0:
		return Result.new(&"SPACE_TRANSACTION_BUSY")
	if expected_revision != revision():
		return Result.new(&"SPACE_REVISION_STALE")
	if revision() == I64_MAX or _next_token == I64_MAX:
		return Result.new(&"SPACE_REVISION_EXHAUSTED")
	_remaining = _header[16]
	if not _spend(_region_capacity + _source_capacity):
		return Result.new(&"SPACE_OPERATION_BUDGET")
	_copy_into_stage()
	_changed_count = 0
	_changed_mask.fill(0)
	_stage_token = _next_token
	_next_token += 1
	_sealed = false
	return Result.new(&"", _stage_token)


func abort(token: int) -> bool:
	"""Drop only transient preparation; confirmed live reservations and geometry are untouched."""
	if _reject_room_reentry() or _validation_sources >= 0 or token == 0 or token != _stage_token:
		return false
	_stage_token = 0
	_sealed = false
	_clear_installation()
	_clear_room_admission()
	_clear_furniture_admissions()
	return true


func stage_furniture_install(token: int, project: Vector2i, router: ModularContract,
		owner: ModularContract.Owner) -> StringName:
	"""Anticipate exactly one actual pending Furniture's paid installation, never caller-supplied facts."""
	var code: StringName = _editable(token)
	if code != &"":
		return code
	if _install_row != -1 or _room_row != -1 or _furniture_count > 0:
		return &"SPACE_INSTALLATION_BUSY"
	code = _installation_project_refusal(project, router, owner)
	if code != &"":
		return code
	code = _pending_installation_source_into(project, _install_number)
	if code != &"":
		return code
	var row: int = _install_number.value
	code = _bump_source(row)
	if code != &"":
		return code
	_s_o_d[row] = 1
	_install_row = row
	_install_project = project
	_install_router = weakref(router)
	_install_owner = weakref(owner)
	return &""


func _pending_installation_source_into(project: Vector2i, out: IntMath.IntResult) -> StringName:
	"""Read the exact still-pending actual source row into existing caller scratch before staging d=1."""
	var piece: Vector2i = _sources.construction_owner().subject_ref_of(project)
	var row: int = _find_source(piece, true, true)
	var live: int = _find_source(piece, false, true)
	if row == LOOKUP_BUDGET or live == LOOKUP_BUDGET:
		return &"SPACE_OPERATION_BUDGET"
	if row < 0 or live != row:
		return &"SPACE_INSTALLATION_SOURCE"
	var code: StringName = _read_source(piece)
	if code != &"":
		return code
	if _facts.kind != Directory.KIND_FURNITURE or _facts.d != 0 or _facts.b != Buildings.NO_LINK \
			or not _facts_match(row, false) or not _facts_match(row, true):
		return &"SPACE_INSTALLATION_BEFORE_FACTS"
	var domain: Buildings.OpResult = _sources.construction_owner().buildings().spatial_kind_of_room(_facts.parent)
	if not domain.ok or domain.value != Buildings.ROOM_SPACE_UNDERGROUND:
		return &"SPACE_INSTALLATION_ROOM"
	out.succeed(row)
	return &""


func _installation_project_refusal(project: Vector2i, router: ModularContract,
		owner: ModularContract.Owner) -> StringName:
	"""Only the actual completed paid Furniture project can prepare its exact bound purpose owner."""
	if not _sources is CoreSources or router == null or owner == null:
		return &"SPACE_INSTALLATION_BINDING"
	var construction: Construction = _sources.construction_owner()
	if construction == null or construction.modular_authority() != router \
			or router.construction_owner() != construction or not router.is_bound_owner(owner) \
			or router.world_ref() != _domain._world or owner.purpose() != Construction.PURPOSE_SPATIAL_FURNITURE:
		return &"SPACE_INSTALLATION_BINDING"
	if not construction.purpose_into(project, _install_number) \
			or _install_number.value != Construction.PURPOSE_SPATIAL_FURNITURE:
		return &"SPACE_INSTALLATION_PROJECT"
	var piece: Vector2i = construction.subject_ref_of(project)
	if not construction.buildings().is_live_furniture(piece) \
			or not construction.type_id_into(project, _install_number) \
			or _install_number.value != construction.buildings().type_id_of_furniture(piece).value:
		return &"SPACE_INSTALLATION_PROJECT"
	if not construction.phase_into(project, _install_number) or _install_number.value != Construction.PHASE_WORK_DONE \
			or not construction.remaining_mwu_into(project, _install_number) or _install_number.value != 0:
		return &"SPACE_INSTALLATION_NOT_COMPLETED"
	return &""


func _clear_installation() -> void:
	"""Release only transient binding controls, leaving both packed source images untouched."""
	_install_row = -1
	_install_project = NULL_REF
	_install_router = null
	_install_owner = null


func stage_room_admission(token: int, candidate: Directory.CreateCandidate, room_type: int,
		authority: Buildings.SpatialAuthority) -> StringName:
	"""Stage only the actual next Room identity and permanent purpose, never caller-created source facts."""
	var code: StringName = _editable(token)
	if code != &"":
		return code
	if _install_row >= 0 or _room_row >= 0 or _furniture_count > 0:
		return &"SPACE_ROOM_ADMISSION_BUSY"
	code = _observe_room_candidate(candidate)
	if code == &"":
		code = _prepare_room_authority(candidate, room_type, authority)
	if code != &"":
		return code
	code = _editable(token)
	if code != &"":
		return code
	var staged: int = _find_source(candidate.ref, true, true)
	var live: int = _find_source(candidate.ref, false, true)
	if staged == LOOKUP_BUDGET or live == LOOKUP_BUDGET:
		return &"SPACE_OPERATION_BUDGET"
	if staged >= 0 or live >= 0:
		return &"SPACE_ROOM_SOURCE_EXISTS"
	if _s_source_free_count == 0:
		return &"SPACE_SOURCE_CAPACITY"
	_room_input = weakref(candidate)
	_room_authority = weakref(authority)
	_room_type = room_type
	_stage_room_source()
	return &""


func _observe_room_candidate(candidate: Directory.CreateCandidate) -> StringName:
	"""Pin the actual current tuple before invoking any virtual authority attestation."""
	if not _sources is CoreSources:
		return &"SPACE_ROOM_ADMISSION_BINDING"
	var code: StringName = _sources.directory().candidate_refusal(candidate)
	if code != &"":
		return code
	code = _sources.directory().peek_create_into(Directory.KIND_ROOM, _room_candidate)
	return &"" if code == &"" and _same_room_candidate(candidate) else &"SPACE_ROOM_CANDIDATE"


func _prepare_room_authority(candidate: Directory.CreateCandidate, room_type: int,
		authority: Buildings.SpatialAuthority) -> StringName:
	"""No callback can replace the previously pinned observation or quietly change the stage token."""
	var code: StringName = _room_binding_refusal(authority)
	if code == &"":
		code = _room_authority_refusal(candidate, room_type)
	if code == &"" and not _same_room_candidate(candidate):
		return &"SPACE_ROOM_CANDIDATE"
	return code


func _room_binding_refusal(authority: Buildings.SpatialAuthority) -> StringName:
	"""A future source belongs to this actual World, Directory, Buildings and its one bound authority."""
	if not _sources is CoreSources or authority == null or _sources.construction_owner() == null:
		return &"SPACE_ROOM_ADMISSION_BINDING"
	var buildings: Buildings = _sources.construction_owner().buildings()
	if buildings.directory() != _sources.directory() or buildings.spatial_authority() != authority:
		return &"SPACE_ROOM_ADMISSION_BINDING"
	if not _begin_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	var actual: RefCounted = authority.buildings_owner()
	if _end_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if actual != buildings or buildings.spatial_authority() != authority:
		return &"SPACE_ROOM_ADMISSION_BINDING"
	return &"" if _read_source(_domain._world) == &"" and _facts.kind == Directory.KIND_WORLD \
		else &"SPACE_WORLD_IDENTITY"


func _reject_room_reentry() -> bool:
	"""Virtual authority proofs may read owners, but cannot mutate this transaction on the same call stack."""
	if _room_callback:
		_room_reentered = true
	return _room_callback


func _begin_room_callback() -> bool:
	"""Guard exactly one side-effect-free authority call; recursive proofs poison the outer result."""
	if _reject_room_reentry():
		return false
	_room_callback = true
	_room_reentered = false
	return true


func _end_room_callback() -> bool:
	"""Return the attempted-reentry flag and leave no persistent busy/poison latch after refusal."""
	var refused: bool = _room_reentered
	_room_callback = false
	_room_reentered = false
	return refused


func _room_authority_refusal(candidate: Directory.CreateCandidate, room_type: int) -> StringName:
	"""Protect both Buildings callbacks, then recheck the actual allocator after their return."""
	if not _begin_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	var code: StringName = _sources.construction_owner().buildings().spatial_room_candidate_refusal(room_type, candidate)
	if _end_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	return _sources.directory().candidate_refusal(candidate) if code == &"" else code


func _same_room_candidate(candidate: Directory.CreateCandidate) -> bool:
	"""Every observed scalar and the exact Directory must equal the privately rederived observation."""
	return candidate != null and candidate.directory_owner() == _sources.directory() \
		and _room_candidate.directory_owner() == _sources.directory() \
		and candidate.ref == _room_candidate.ref and candidate.kind == Directory.KIND_ROOM \
		and candidate.kind == _room_candidate.kind and candidate.typed_row == _room_candidate.typed_row \
		and candidate.persistent_id == _room_candidate.persistent_id


func _stage_room_source() -> void:
	"""Publish a source only in the inactive bank after every finite capacity/identity preflight."""
	_room_row = _heap_pop(_s_source_free_heap, _s_source_free_count)
	_s_source_free_count -= 1
	_s_o_present[_room_row] = 1
	_s_o_slot[_room_row] = _room_candidate.ref.x
	_s_o_generation[_room_row] = _room_candidate.ref.y
	_s_o_revision[_room_row] = 1
	_room_facts_into()
	_write_source_facts(_room_row)


func _room_facts_into() -> void:
	"""Only permanent purpose and the actual underground domain differ from empty Room defaults."""
	_facts.clear()
	_facts.kind = Directory.KIND_ROOM
	_facts.a = _room_type
	_facts.d = Buildings.ROOM_SPACE_UNDERGROUND


func _room_before_refusal() -> StringName:
	"""Seal and immediate preflight recheck the same retained mutable packet without reserving an ID."""
	var candidate: Directory.CreateCandidate = _room_input.get_ref() as Directory.CreateCandidate \
		if _room_input != null else null
	var authority: Buildings.SpatialAuthority = _room_authority.get_ref() as Buildings.SpatialAuthority \
		if _room_authority != null else null
	if _room_row < 0 or not _same_room_candidate(candidate):
		return &"SPACE_ROOM_CANDIDATE"
	var code: StringName = _room_binding_refusal(authority)
	if code == &"":
		code = _room_authority_refusal(candidate, _room_type)
	if code == &"" and not _same_room_candidate(candidate):
		return &"SPACE_ROOM_CANDIDATE"
	return code


func _room_source_refusal() -> StringName:
	"""The only future source row retains the exact observed full identity and derived Room facts."""
	if _room_row < 0 or _room_row >= _source_capacity or _s_o_present[_room_row] != 1 \
			or Vector2i(_s_o_slot[_room_row], _s_o_generation[_room_row]) != _room_candidate.ref:
		return &"SPACE_ROOM_CANDIDATE"
	_room_facts_into()
	return &"" if _facts_match(_room_row, true) else &"SPACE_ROOM_CANDIDATE"


func _clear_room_admission() -> void:
	"""Abort/publication erases only transient observations; no Directory generation or PID is spent."""
	_room_candidate.reset()
	_room_input = null
	_room_authority = null
	_room_row = -1
	_room_type = -1


func stage_source(token: int, ref: Vector2i) -> StringName:
	"""Register actual source facts; changed facts require removing all old geometry first."""
	var code: StringName = _editable(token)
	if code != &"":
		return code
	code = _read_source(ref)
	if code != &"":
		return code
	var row: int = _find_source(ref, true, true)
	if row == LOOKUP_BUDGET:
		return &"SPACE_OPERATION_BUDGET"
	if row >= 0:
		if _facts_match(row, true):
			return &""
		code = _source_unused_refusal(ref)
		if code != &"":
			return code
		code = _bump_source(row)
		if code != &"":
			return code
	else:
		row = _allocate_source(ref)
		if row == LOOKUP_BUDGET:
			return &"SPACE_OPERATION_BUDGET"
		if row < 0:
			return &"SPACE_SOURCE_CAPACITY" if _s_source_free_count == 0 else &"SPACE_REVISION_EXHAUSTED"
	_write_source_facts(row)
	return &""

func _allocate_source(ref: Vector2i) -> int:
	"""Re-registering the same live identity cannot reset its revision by forgetting and reallocating it."""
	if _s_source_free_count == 0:
		return -1
	var previous: int = -1
	if _source_free_count < _source_capacity - 1:
		previous = _find_source(ref, false, true)
	if previous == LOOKUP_BUDGET:
		return LOOKUP_BUDGET
	if previous >= 0 and _o_revision[previous] == I64_MAX:
		return -1
	var row: int = _heap_pop(_s_source_free_heap, _s_source_free_count)
	_s_source_free_count -= 1
	_s_o_present[row] = 1
	_s_o_slot[row] = ref.x
	_s_o_generation[row] = ref.y
	_s_o_revision[row] = _o_revision[previous] + 1 if previous >= 0 else 1
	return row


func stage_add(token: int, region: Region) -> Result:
	"""Allocate an internal region handle; it remains invisible until sealed publication."""
	var code: StringName = _editable(token)
	if code == &"":
		code = _region_input_error(region)
	if code != &"":
		return Result.new(code)
	if _s_region_free_count == 0:
		return Result.new(&"SPACE_REGION_CAPACITY")
	var owner: int = _find_source(region.owner, true, true)
	if owner == LOOKUP_BUDGET:
		return Result.new(&"SPACE_OPERATION_BUDGET")
	if owner < 0:
		return Result.new(&"SPACE_SOURCE_NOT_REGISTERED")
	code = _bump_source(owner)
	if code != &"":
		return Result.new(code)
	var row: int = _heap_pop(_s_region_free_heap, _s_region_free_count)
	_s_region_free_count -= 1
	_s_r_generation[row] += 1
	_write_region(row, region, _s_o_revision[owner])
	_mark_changed(row)
	return Result.new(&"", token, Vector2i(row, _s_r_generation[row]))


func stage_remove(token: int, handle: Vector2i) -> StringName:
	"""Remove an exact generation in scratch; section dependents are checked before sealing."""
	var code: StringName = _editable(token)
	if code != &"":
		return code
	if not _region_live(handle, true):
		return &"SPACE_REGION_STALE"
	var row: int = handle.x
	var source: int = _find_source(Vector2i(_s_r_owner_slot[row], _s_r_owner_generation[row]), true, true)
	if source == LOOKUP_BUDGET:
		return &"SPACE_OPERATION_BUDGET"
	code = _bump_source(source)
	if code != &"":
		return code
	_clear_region(row, true)
	_mark_changed(row)
	if _s_r_generation[row] == I32_MAX:
		_s_r_retired[row] = 1
	else:
		_heap_push(_s_region_free_heap, _s_region_free_count, row)
		_s_region_free_count += 1
	return &""


func stage_forget_source(token: int, ref: Vector2i) -> StringName:
	"""A source record may retire only after all physical and reservation rows release it."""
	var code: StringName = _editable(token)
	if code != &"":
		return code
	var row: int = _find_source(ref, true, true)
	if row == LOOKUP_BUDGET:
		return &"SPACE_OPERATION_BUDGET"
	if row < 0 or ref == Vector2i(_header[3], _header[4]):
		return &"SPACE_SOURCE_STALE"
	code = _source_unused_refusal(ref)
	if code != &"":
		return &"SPACE_SOURCE_IN_USE" if code == &"SPACE_SOURCE_REBUILD_REQUIRED" else code
	_clear_source(row, true)
	_heap_push(_s_source_free_heap, _s_source_free_count, row)
	_s_source_free_count += 1
	return &""

func seal(token: int) -> StringName:
	"""Prove all staged facts, references and exact extents before any physical payment commits."""
	var code: StringName = _editable(token)
	if code != &"":
		return code
	code = _validate_stage(true)
	if code != &"":
		return code
	_s_header[17] = revision() + 1
	_sealed = true
	return &""


func prepared_refusal(token: int) -> StringName:
	"""Immediate final preflight rechecks real source generations and facts without copying geometry."""
	if token == 0 or token != _stage_token or not _sealed:
		return &"SPACE_TRANSACTION_UNSEALED"
	if _s_header[17] != revision() + 1:
		return &"SPACE_REVISION_STALE"
	var code: StringName = _sources_refusal(true)
	return _claims_refusal(true) if code == &"" else code


func prepared_has_changes(token: int) -> bool:
	"""A sealed no-op need not invalidate every worker's static proof; source changes still count."""
	if token == 0 or token != _stage_token or not _sealed:
		return false
	return _changed_count > 0 or _o_present != _s_o_present or _o_kind != _s_o_kind \
		or _o_slot != _s_o_slot or _o_generation != _s_o_generation or _o_revision != _s_o_revision \
		or _o_parent_slot != _s_o_parent_slot or _o_parent_generation != _s_o_parent_generation \
		or _o_a != _s_o_a or _o_b != _s_o_b or _o_c != _s_o_c or _o_d != _s_o_d


func prepared_region_into(token: int, handle: Vector2i, out: Region) -> StringName:
	"""Cold copied facts from this owner's exact sealed candidate; never a caller's future plan."""
	var code: StringName = prepared_refusal(token)
	if code != &"":
		return code
	if out == null or not _region_live(handle, true):
		return &"SPACE_REGION_STALE"
	var row: int = handle.x
	out.box = _box(row, true)
	out.role = _s_r_role[row]
	out.level = _s_r_level[row]
	out.owner = Vector2i(_s_r_owner_slot[row], _s_r_owner_generation[row])
	out.section = Vector2i(_s_r_section_slot[row], _s_r_section_generation[row])
	out.claim_ref = Vector2i(_s_r_claim_slot[row], _s_r_claim_generation[row])
	out.claim_kind = _s_r_claim_kind[row]
	return &""


func prepared_region_observation_into(token: int, handle: Vector2i, out: Region) -> StringName:
	"""Copy sealed fixed scratch only; bracket an entire batch with full prepared_refusal before and after."""
	if _ready_error != &"" or token <= 0 or token != _stage_token or not _sealed \
			or _s_header[17] != revision() + 1:
		return &"SPACE_TRANSACTION_UNSEALED"
	if not _sources.directory().is_valid_of_kind(Vector2i(_header[3], _header[4]), Directory.KIND_WORLD):
		return &"SPACE_SOURCE_STALE"
	if out == null or not _region_live(handle, true):
		return &"SPACE_REGION_STALE"
	if out.box.size() != 6:
		return &"SPACE_REGION_OUTPUT_SHAPE"
	var row: int = handle.x
	out.box[0] = _s_r_lo_x[row]
	out.box[1] = _s_r_lo_y[row]
	out.box[2] = _s_r_lo_z[row]
	out.box[3] = _s_r_hi_x[row]
	out.box[4] = _s_r_hi_y[row]
	out.box[5] = _s_r_hi_z[row]
	out.role = _s_r_role[row]
	out.level = _s_r_level[row]
	out.owner = Vector2i(_s_r_owner_slot[row], _s_r_owner_generation[row])
	out.section = Vector2i(_s_r_section_slot[row], _s_r_section_generation[row])
	out.claim_ref = Vector2i(_s_r_claim_slot[row], _s_r_claim_generation[row])
	out.claim_kind = _s_r_claim_kind[row]
	return &""


func prepared_snapshot_into(token: int, out: Space.Snapshot) -> StringName:
	"""Cold complete candidate survey, including all claims; callers budget its isolated copy."""
	var code: StringName = prepared_refusal(token)
	if code != &"":
		return code
	return _copy_prepared_snapshot_into(out, NULL_REF, NULL_REF)


func prepared_snapshot_for_traversal_into(token: int, out: Space.Snapshot) -> StringName:
	"""Observe sealed physical traversal truth; omit only typed Room-owned OBSTACLE reservation markers."""
	var code: StringName = prepared_refusal(token)
	if code != &"":
		return code
	return _copy_prepared_snapshot_into(out, NULL_REF, NULL_REF, true)


func prepared_snapshot_for_site_into(token: int, out: Space.Snapshot,
		sites: Sites, site: Vector2i) -> StringName:
	"""Apply the same exact actual Sites/Room/phase proof to sealed future geometry, not a fake plan."""
	var code: StringName = prepared_refusal(token)
	if code == &"":
		code = _site_scope_refusal(sites, site)
	if code != &"":
		return code
	return _copy_prepared_snapshot_into(out, sites.room_of(site), sites.project_of(site))


func prepared_snapshot_leased_into(token: int, out: Space.Snapshot, budget: Budget, cold_token: int) -> StringName:
	"""Copy the exact sealed full-claim image only while the original caller lease still covers all live output."""
	var bytes: int = 48 * _region_capacity + 16 * _source_capacity + SNAPSHOT_COPY_CONTROL_BYTES + _snapshot_output_bytes(out)
	var code: StringName = _prepared_copy_refusal(token, out, budget, cold_token, bytes)
	if code != &"":
		return code
	var expected_revision: int = revision()
	if not _begin_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	code = prepared_refusal(token)
	if _end_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if code != &"":
		return code
	if revision() != expected_revision or token != _stage_token or not _sealed or _validation_sources >= 0:
		return &"SPACE_REVISION_STALE"
	bytes = 48 * _region_capacity + 16 * _source_capacity + SNAPSHOT_COPY_CONTROL_BYTES + _snapshot_output_bytes(out)
	if not budget.covers(cold_token, bytes):
		return Budget.REFUSE_TOKEN
	return _copy_prepared_snapshot_into(out, NULL_REF, NULL_REF)


func _prepared_copy_refusal(token: int, out: Space.Snapshot, budget: Budget, cold_token: int, bytes: int) -> StringName:
	"""Refuse missing sealed context, unaffordable copies and validation reentry before source observers."""
	if _reject_room_reentry():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if out == null or _ready_error != &"":
		return &"SPACE_WORLD_UNBOUND"
	if token <= 0 or token != _stage_token or not _sealed or _validation_sources >= 0:
		return &"SPACE_TRANSACTION_UNSEALED"
	if budget == null or not budget.covers(cold_token, bytes):
		return Budget.REFUSE_TOKEN
	if 2 * (_region_capacity + _source_capacity) > _header[16]:
		return &"SPACE_OPERATION_BUDGET"
	return &""


func prepared_snapshot_for_traversal_leased_into(token: int, out: Space.Snapshot,
		budget: Budget, cold_token: int) -> StringName:
	"""Copy sealed traversal truth with the original lease checked after every source observer, before allocation."""
	var bytes: int = 48 * _region_capacity + 16 * _source_capacity + SNAPSHOT_COPY_CONTROL_BYTES + _snapshot_output_bytes(out)
	var code: StringName = _prepared_copy_refusal(token, out, budget, cold_token, bytes)
	if code != &"":
		return code
	var expected: int = revision()
	if not _begin_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	code = prepared_refusal(token)
	if _end_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if code == &"":
		code = _prepared_lease_tail(token, expected, out, budget, cold_token)
	return _copy_prepared_snapshot_into(out, NULL_REF, NULL_REF, true) if code == &"" else code


func prepared_snapshot_for_site_leased_into(token: int, out: Space.Snapshot, sites: Sites,
		site: Vector2i, budget: Budget, cold_token: int) -> StringName:
	"""Keep exact actual Site marker scope; no callback can replace the admitted original copy lease."""
	var bytes: int = 48 * _region_capacity + 16 * _source_capacity + SNAPSHOT_COPY_CONTROL_BYTES + _snapshot_output_bytes(out)
	var code: StringName = _prepared_copy_refusal(token, out, budget, cold_token, bytes)
	if code != &"":
		return code
	if sites == null or sites._construction == null or sites._ready_error != &"" \
			or site.x < 0 or site.x >= sites._count or site.y != Sites.SITE_GENERATION or sites._present[site.x] != 1:
		return &"SPACE_SITE_STALE"
	var room: Vector2i = Vector2i(sites._room_slot[site.x], sites._room_generation[site.x])
	var project: Vector2i = Vector2i(sites._project_slot[site.x], sites._project_generation[site.x])
	var expected: int = revision()
	code = _prepared_site_observers(token, sites, site)
	if code == &"" and not _prepared_site_pins(sites, site, room, project):
		code = &"SPACE_SITE_STALE"
	if code == &"":
		code = _prepared_lease_tail(token, expected, out, budget, cold_token)
	return _copy_prepared_snapshot_into(out, room, project) if code == &"" else code


func _prepared_site_observers(token: int, sites: Sites, site: Vector2i) -> StringName:
	"""Complete existing source/claim/actual Site observations inside the mutation poison bracket."""
	if not _begin_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	var code: StringName = _site_scope_refusal(sites, site)
	if code == &"":
		code = prepared_refusal(token)
	if code == &"":
		code = _site_scope_refusal(sites, site)
	return &"SPACE_ROOM_ADMISSION_REENTRY" if _end_room_callback() else code


func _prepared_site_pins(sites: Sites, site: Vector2i, room: Vector2i, project: Vector2i) -> bool:
	"""Only actual CoreSources/Construction and the same immutable physical key may omit these markers."""
	var actual: CoreSources = _sources as CoreSources
	if actual == null or actual._construction == null or sites._construction == null or sites._domain == null \
			or actual._construction != sites._construction or actual._directory == null \
			or sites._construction._excavation_authority == null \
			or sites._construction._excavation_authority.get_ref() != sites or sites._ready_error != &"" \
			or site.x < 0 or site.x >= sites._count or site.y != Sites.SITE_GENERATION or sites._present[site.x] != 1:
		return false
	if sites._domain.world_ref != _domain._world or sites._domain.datum_u != _domain._datum \
			or sites._domain.minimum_quantum != _domain._min_quantum or sites._domain.size_quanta != _domain._size_quanta:
		return false
	return Vector2i(sites._room_slot[site.x], sites._room_generation[site.x]) == room \
		and Vector2i(sites._project_slot[site.x], sites._project_generation[site.x]) == project \
		and actual._directory.is_valid_of_kind(room, Directory.KIND_ROOM) \
		and actual._directory.is_valid_of_kind(_domain._world, Directory.KIND_WORLD) \
		and (project == NULL_REF or actual._construction.is_live_project(project))


func _prepared_lease_tail(token: int, expected: int, out: Space.Snapshot, budget: Budget, cold_token: int) -> StringName:
	"""No observer lies between this original-token/output coexistence check and the caller's image allocation."""
	if revision() != expected or token != _stage_token or not _sealed or _validation_sources >= 0:
		return &"SPACE_REVISION_STALE"
	var bytes: int = 48 * _region_capacity + 16 * _source_capacity + SNAPSHOT_COPY_CONTROL_BYTES + _snapshot_output_bytes(out)
	return &"" if budget.covers(cold_token, bytes) else Budget.REFUSE_TOKEN


func _copy_prepared_snapshot_into(out: Space.Snapshot, room: Vector2i,
		project: Vector2i, traversal: bool = false) -> StringName:
	"""Build one isolated complete survey; only already-proved exact reservation markers may omit."""
	if out == null:
		return &"SPACE_WORLD_UNBOUND"
	var image: Space.Snapshot = Space.Snapshot.new()
	image.world_ref = Vector2i(_s_header[3], _s_header[4])
	image.revision = _s_header[17]
	for row: int in _source_capacity:
		if _s_o_present[row] != 0:
			image.live_refs.append_array(PackedInt32Array([_s_o_slot[row], _s_o_generation[row]]))
			image.live_revisions.append(_s_o_revision[row])
	for row: int in _region_capacity:
		if _s_r_present[row] == 0 or _exempt_prepared_claim(row, room, project) \
				or (traversal and _traversal_marker(row, true)):
			continue
		var role: int = Space.OBSTACLE if _s_r_claim_kind[row] != CLAIM_NONE else _s_r_role[row]
		image.volumes.append(_box(row, true), role, _s_r_level[row],
			Vector2i(_s_r_owner_slot[row], _s_r_owner_generation[row]), _s_r_owner_revision[row])
	out.version = image.version
	out.world_ref = image.world_ref
	out.revision = image.revision
	out.live_refs = image.live_refs
	out.live_revisions = image.live_revisions
	out.volumes = image.volumes
	return &""


func _exempt_prepared_claim(row: int, room: Vector2i, project: Vector2i) -> bool:
	"""Existing exact Sites scope never grants a general traversal or placement exemption."""
	var claim: Vector2i = Vector2i(_s_r_claim_slot[row], _s_r_claim_generation[row])
	return (_s_r_claim_kind[row] == CLAIM_ROOM and room != NULL_REF and claim == room) \
		or (_s_r_claim_kind[row] == CLAIM_CONSTRUCTION and project != NULL_REF and claim == project)


func _traversal_marker(row: int, staged: bool) -> bool:
	"""Only a Room's own typed reservation is nonphysical; same-Room walls and unfinished matter remain."""
	if staged:
		return _s_r_claim_kind[row] == CLAIM_ROOM and _s_r_role[row] == Space.OBSTACLE \
			and _s_r_owner_slot[row] == _s_r_claim_slot[row] \
			and _s_r_owner_generation[row] == _s_r_claim_generation[row]
	return _r_claim_kind[row] == CLAIM_ROOM and _r_role[row] == Space.OBSTACLE \
		and _r_owner_slot[row] == _r_claim_slot[row] and _r_owner_generation[row] == _r_claim_generation[row]


func publish(token: int) -> void:
	"""A coordinator calls this synchronously after successful payment; there are no fallible callbacks."""
	if _reject_room_reentry() or _validation_sources >= 0:
		return
	if _installation_context != null and _installation_owns_token(self, token):
		return # Only the static actual paid window can publish this installation-owned token.
	if _install_row >= 0 or _room_row >= 0 or _furniture_count > 0:
		return # Future source publication requires its exact actual owner callback, even with a sealed token.
	assert(token != 0 and token == _stage_token and _sealed, "only a preflighted transaction may publish")
	_swap_banks()
	_stage_token = 0
	_sealed = false


static func generic_commit_refusal(actual: RefCounted, token: int, base_revision: int,
		target_revision: int) -> StringName:
	"""Pure identity gate only; the caller must finish every source/claim proof before irreversible payment."""
	if actual == null or actual._ready_error != &"" or token <= 0 or token != actual._stage_token \
			or not actual._sealed or actual._room_callback or actual._room_reentered \
			or actual._validation_sources >= 0 or actual._validation_regions >= 0:
		return &"SPACE_TRANSACTION_UNSEALED"
	if actual._install_row >= 0 or actual._room_row >= 0 or actual._furniture_count > 0:
		return &"SPACE_SPECIAL_PUBLICATION_REQUIRED"
	if base_revision <= 0 or base_revision == I64_MAX or target_revision != base_revision + 1 \
			or actual._header[17] != base_revision or actual._s_header[17] != target_revision:
		return &"SPACE_REVISION_STALE"
	return &""


static func commit_preflighted(actual: RefCounted, token: int, base_revision: int,
		target_revision: int) -> bool:
	"""Commit a previously fully proved generic candidate without virtual dispatch, source reads or allocation."""
	if generic_commit_refusal(actual, token, base_revision, target_revision) != &"":
		return false
	if _installation_owns_token(actual, token) and installation_commit_refusal(actual, token) != &"":
		return false
	_commit_preflighted_columns(actual, token)
	return true


static func _commit_preflighted_columns(actual: RefCounted, token: int) -> void:
	"""Only a fully preflighted concrete publication path enters the shared callback-free bank swap."""
	_commit_columns_0(actual)
	_commit_columns_1(actual)
	_commit_columns_2(actual)
	_commit_columns_3(actual)
	_commit_columns_4(actual)
	var count: int = actual._region_free_count
	actual._region_free_count = actual._s_region_free_count
	actual._s_region_free_count = count
	count = actual._source_free_count
	actual._source_free_count = actual._s_source_free_count
	actual._s_source_free_count = count
	actual._last_published_token = token
	actual._stage_token = 0
	actual._sealed = false


static func installation_binding_refusal(actual: RefCounted, context: RefCounted) -> StringName:
	"""Once-bind only the actual sibling composition; no interface or source observer is invoked."""
	if actual == null or actual._domain == null or actual._ready_error != &"":
		return &"SPACE_INSTALLATION_BINDING"
	var old: RefCounted = actual._installation_context.get_ref() if actual._installation_context != null else null
	if context == null or (actual._installation_context != null and old != context) or actual._stage_token != 0 \
			or context.space == null or context.space.get_ref() != actual or context.issuer == null \
			or context.issuer.get_ref() == null or context.world != actual._domain._world \
			or context.budget == null or not context.budget.is_quiescent():
		return &"SPACE_INSTALLATION_BINDING"
	return &""


static func _installation_owns_token(actual: RefCounted, token: int) -> bool:
	"""The issuer's independent original token also blocks publication after a mutable context is tampered with."""
	var context: RefCounted = actual._installation_context.get_ref() if actual._installation_context != null else null
	if context == null or token <= 0:
		return false
	var issuer: RefCounted = context.issuer.get_ref() if context.issuer != null else null
	return context.space_token == token or (issuer != null and issuer._space == actual and issuer._space_token == token)


static func installation_commit_refusal(actual: RefCounted, token: int) -> StringName:
	"""Exact direct actual Router COMMIT and original issuer/lease pins close the public paid kernel."""
	var context: RefCounted = actual._installation_context.get_ref() if actual._installation_context != null else null
	var issuer: RefCounted = context.issuer.get_ref() if context != null and context.issuer != null else null
	var router: RefCounted = context.router.get_ref() if context != null and context.router != null else null
	var paid: RefCounted = context.paid_owner.get_ref() if context != null and context.paid_owner != null else null
	if issuer == null or router == null or paid == null or issuer._context != context or issuer._space != actual \
			or issuer._space_token != token or context.space_token != token or context.world != actual._domain._world \
			or issuer._cold_token != context.cold_token or issuer._budget != context.budget \
			or issuer._prepared_project != context.project or issuer._prepared_placement != context.placement \
			or issuer._prepared_assembly != context.assembly or not context.budget.covers(context.cold_token, Budget.COLD_BYTES):
		return &"SPACE_INSTALLATION_CONTEXT"
	if not router._busy or router._publishing_project != context.project or router._publishing_owner != paid \
			or router._publishing_action != ModularContract.COMMIT or router._connector_owner == null \
			or router._connector_owner.get_ref() != paid or router._construction != issuer._construction \
			or router._world != context.world or router._inventory != issuer._inventory:
		return &"SPACE_INSTALLATION_WINDOW"
	return &""


func publish_furniture_install(token: int, project: Vector2i, router: ModularContract,
		owner: ModularContract.Owner) -> StringName:
	"""Publish only after the real installed flag changed inside the exact paid Router COMMIT callback."""
	if _reject_room_reentry():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if token == 0 or token != _stage_token or not _sealed or _install_row < 0 \
			or project != _install_project or _install_router == null or _install_router.get_ref() != router \
			or _install_owner == null or _install_owner.get_ref() != owner:
		return &"SPACE_INSTALLATION_TOKEN"
	var code: StringName = _installation_project_refusal(project, router, owner)
	if code != &"":
		return code
	if not router.is_publishing(project, ModularContract.COMMIT, owner):
		return &"SPACE_INSTALLATION_PUBLICATION"
	if _s_header[17] != revision() + 1:
		return &"SPACE_REVISION_STALE"
	code = _sources_refusal(true, false)
	if code == &"":
		code = _claims_refusal(true)
	if code != &"":
		return code
	_swap_banks()
	_stage_token = 0
	_sealed = false
	_clear_installation()
	return &""


func publish_room_admission(token: int, candidate: Directory.CreateCandidate, room_type: int,
		authority: Buildings.SpatialAuthority) -> StringName:
	"""Publish the already-sealed claim only after exact real Room allocation inside its authority window."""
	if _reject_room_reentry():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if token == 0 or token != _stage_token or not _sealed or _room_row < 0 \
			or _room_input == null or _room_input.get_ref() != candidate or not _same_room_candidate(candidate) \
			or room_type != _room_type or _room_authority == null or _room_authority.get_ref() != authority:
		return &"SPACE_ROOM_ADMISSION_TOKEN"
	var code: StringName = _room_after_refusal(authority)
	if code != &"":
		return code
	if not _same_room_candidate(candidate):
		return &"SPACE_ROOM_CANDIDATE"
	if _s_header[17] != revision() + 1:
		return &"SPACE_REVISION_STALE"
	code = _sources_refusal(true, false)
	if code == &"":
		code = _claims_refusal(true, false)
	if code != &"":
		return code
	_swap_banks()
	_stage_token = 0
	_sealed = false
	_clear_room_admission()
	return &""


static func room_prepared_leaf_refusal(actual: RefCounted, token: int, candidate: Directory.CreateCandidate,
		room_type: int, authority: Buildings.SpatialAuthority) -> StringName:
	"""Local sealed future-Room identity only; typed Orders/source/lease preflight remains mandatory before allocation."""
	if actual == null or actual._ready_error != &"" or token <= 0 or actual._stage_token != token \
			or not actual._sealed or actual._room_callback or actual._room_reentered \
			or actual._validation_sources >= 0 or actual._validation_regions >= 0 \
			or actual._install_row >= 0 or actual._furniture_count != 0:
		return &"SPACE_ROOM_ADMISSION_TOKEN"
	if candidate == null or authority == null or actual._room_input == null or actual._room_authority == null \
			or actual._room_input.get_ref() != candidate or actual._room_authority.get_ref() != authority \
			or room_type != actual._room_type or not actual._sources is CoreSources:
		return &"SPACE_ROOM_ADMISSION_BINDING"
	var sources: CoreSources = actual._sources as CoreSources
	var pinned: Directory.CreateCandidate = actual._room_candidate
	if candidate._directory == null or pinned._directory == null or sources._directory == null \
			or candidate._directory.get_ref() != sources._directory or pinned._directory.get_ref() != sources._directory \
			or candidate.ref != pinned.ref or candidate.kind != Directory.KIND_ROOM or candidate.kind != pinned.kind \
			or candidate.typed_row != pinned.typed_row or candidate.persistent_id != pinned.persistent_id:
		return &"SPACE_ROOM_CANDIDATE"
	if actual._header[17] <= 0 or actual._header[17] == I64_MAX or actual._s_header[17] != actual._header[17] + 1:
		return &"SPACE_REVISION_STALE"
	return _room_source_leaf_refusal(actual, candidate, room_type)


static func _room_source_leaf_refusal(actual: RefCounted, candidate: Directory.CreateCandidate, room_type: int) -> StringName:
	"""The only future row has exact derived Room facts; no public source reader or mutable Facts is consulted."""
	var row: int = actual._room_row
	if row < 0 or row >= actual._source_capacity or actual._s_o_present[row] != 1 \
			or actual._s_o_kind[row] != Directory.KIND_ROOM or actual._s_o_slot[row] != candidate.ref.x \
			or actual._s_o_generation[row] != candidate.ref.y or actual._s_o_revision[row] <= 0 \
			or actual._s_o_parent_slot[row] != NULL_REF.x or actual._s_o_parent_generation[row] != NULL_REF.y \
			or actual._s_o_a[row] != room_type or actual._s_o_b[row] != 0 or actual._s_o_c[row] != 0 \
			or actual._s_o_d[row] != Buildings.ROOM_SPACE_UNDERGROUND:
		return &"SPACE_ROOM_CANDIDATE"
	return &""


static func room_commit_preflighted(actual: RefCounted, token: int, candidate: Directory.CreateCandidate,
		room_type: int, authority: Buildings.SpatialAuthority, budget: Budget, cold_token: int) -> bool:
	"""Actual Orders must prove its pure publication scope; only the exact after-allocation receipt can swap here."""
	if budget == null or not budget.covers(cold_token, Budget.COLD_BYTES) \
			or room_prepared_leaf_refusal(actual, token, candidate, room_type, authority) != &"" \
			or not _room_issuer_leaf_matches(actual, token, candidate, authority, budget, cold_token) \
			or not _room_after_leaf_matches(actual, candidate, room_type, authority):
		return false
	_commit_preflighted_columns(actual, token)
	actual._room_candidate.ref = NULL_REF
	actual._room_candidate.kind = Directory.KIND_ANY
	actual._room_candidate.typed_row = -1
	actual._room_candidate.persistent_id = 0
	actual._room_candidate._directory = null
	actual._room_input = null
	actual._room_authority = null
	actual._room_row = -1
	actual._room_type = -1
	return true


static func _room_issuer_leaf_matches(actual: RefCounted, token: int, candidate: Directory.CreateCandidate,
		issuer: RefCounted, budget: Budget, cold_token: int) -> bool:
	"""Only the concrete retained entry publication bracket can consume the bank; interface overrides grant nothing."""
	if not "_entry_mode" in issuer or not "_room_candidate" in issuer or not "_room_budget" in issuer \
			or not "_room_cold_token" in issuer or not "_entry_plan" in issuer:
		return false
	return issuer._entry_mode and issuer._publishing and issuer._cold_held \
		and issuer._stage_action == issuer.ROOM_ADMISSION_STAGE and issuer._stage_room == candidate.ref \
		and issuer._stage_token == token and issuer._room_candidate == candidate and issuer._space == actual \
		and issuer._room_budget == budget and issuer._room_cold_token == cold_token \
		and issuer._world == actual._domain._world and issuer._entry_plan != null \
		and issuer._entry_plan.world == actual._domain._world \
		and issuer._sources == actual._sources and issuer._construction == actual._sources._construction \
		and issuer._buildings == actual._sources._buildings


static func _room_after_leaf_matches(actual: RefCounted, candidate: Directory.CreateCandidate,
		room_type: int, authority: Buildings.SpatialAuthority) -> bool:
	"""Read exact actual Directory/Buildings identity after allocation, without dispatching authority callbacks."""
	var sources: CoreSources = actual._sources as CoreSources
	var ids: Directory = sources._directory
	var buildings: Buildings = sources._buildings
	if buildings == null or buildings._directory != ids or buildings._spatial_authority == null \
			or buildings._spatial_authority.get_ref() != authority \
			or not ids.is_valid_of_kind(actual._domain._world, Directory.KIND_WORLD) \
			or not ids.is_valid_of_kind(candidate.ref, Directory.KIND_ROOM) \
			or ids.get_typed_row(candidate.ref) != candidate.typed_row \
			or ids.get_persistent_id(candidate.ref) != candidate.persistent_id:
		return false
	var row: int = candidate.typed_row
	return row >= 0 and row < buildings._r_present.size() and buildings._r_present[row] == 1 \
		and buildings._r_ref_slot[row] == candidate.ref.x and buildings._r_ref_generation[row] == candidate.ref.y \
		and buildings._r_type[row] == room_type and buildings._r_spatial_kind[row] == Buildings.ROOM_SPACE_UNDERGROUND \
		and buildings._r_building_slot[row] == NULL_REF.x and buildings._r_building_generation[row] == NULL_REF.y \
		and buildings._r_tile_offset[row] == 0 and buildings._r_tile_count[row] == 0


func _room_after_refusal(authority: Buildings.SpatialAuthority) -> StringName:
	"""Allocation must have consumed the exact observed row and PID; an ordinary live Room is insufficient."""
	var code: StringName = _room_binding_refusal(authority)
	if code != &"":
		return code
	if not _begin_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	var publishing: bool = authority.is_publishing_room_admission(_room_candidate.ref, _room_type)
	if _end_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if not publishing:
		return &"SPACE_ROOM_ADMISSION_PUBLICATION"
	var ids: Directory = _sources.directory()
	if not ids.is_valid_of_kind(_room_candidate.ref, Directory.KIND_ROOM) \
			or ids.get_typed_row(_room_candidate.ref) != _room_candidate.typed_row \
			or ids.get_persistent_id(_room_candidate.ref) != _room_candidate.persistent_id:
		return &"SPACE_ROOM_AFTER_IDENTITY"
	return _room_source_refusal()


func is_live_region(handle: Vector2i) -> bool:
	"""Validate the internal namespace without comparing it to a directory EntityRef."""
	return _region_live(handle, false)


func region_into(handle: Vector2i, out: Region) -> StringName:
	"""Return copied physical facts; a caller cannot rewrite an authoritative packed column."""
	if out == null or not is_live_region(handle):
		return &"SPACE_REGION_STALE"
	var row: int = handle.x
	out.box = _box(row, false)
	_copy_region_metadata(row, out)
	return &""


func region_into_reused(handle: Vector2i, out: Region) -> StringName:
	"""Overwrite a caller's fixed six-int scratch, including aliases; duplicate explicitly to retain a prior box."""
	if out == null or not is_live_region(handle):
		return &"SPACE_REGION_STALE"
	if out.box.size() != 6:
		return &"SPACE_REGION_OUTPUT_SHAPE"
	var row: int = handle.x
	out.box[0] = _r_lo_x[row]
	out.box[1] = _r_lo_y[row]
	out.box[2] = _r_lo_z[row]
	out.box[3] = _r_hi_x[row]
	out.box[4] = _r_hi_y[row]
	out.box[5] = _r_hi_z[row]
	_copy_region_metadata(row, out)
	return &""


func _copy_region_metadata(row: int, out: Region) -> void:
	"""Copy fixed fields only after either allocating or reusable reader validates the full local handle."""
	out.role = _r_role[row]
	out.level = _r_level[row]
	out.owner = Vector2i(_r_owner_slot[row], _r_owner_generation[row])
	out.section = Vector2i(_r_section_slot[row], _r_section_generation[row])
	out.claim_ref = Vector2i(_r_claim_slot[row], _r_claim_generation[row])
	out.claim_kind = _r_claim_kind[row]


func source_revision(ref: Vector2i) -> int:
	"""A missing source never supplies an implicit revision one."""
	var row: int = _find_source(ref, false)
	return _o_revision[row] if row >= 0 else 0


func source_refusal(ref: Vector2i) -> StringName:
	"""Read actual source facts again; a live generation alone does not prove unchanged placement."""
	var row: int = _find_source(ref, false)
	if row < 0:
		return &"SPACE_SOURCE_NOT_REGISTERED"
	var code: StringName = _read_source(ref)
	if code != &"":
		return code
	return &"" if _facts_match(row, false) else &"SPACE_SOURCE_DRIFT"


func overlapping_regions_into(box: PackedInt32Array, out: PackedInt32Array) -> StringName:
	"""Copy full internal handles for a bounded cold edit; this query grants no placement permission."""
	if _ready_error != &"" or not Space.valid_box(box) or not Space.contains_box(_domain._bounds, box):
		return &"SPACE_REGION_BOUNDS"
	if _region_capacity > _header[16]:
		return &"SPACE_OPERATION_BUDGET"
	out.clear()
	for row: int in _region_capacity:
		if _r_present[row] != 0 and Space.overlaps(box, _box(row, false)):
			out.append(row)
			out.append(_r_generation[row])
	return &""


func section_for_paid_cube_into(room: Vector2i, origin_u: Vector3i,
		expected_revision: int, out: Region) -> StringName:
	"""Resolve actual claim metadata, never cut/clearance permission; overwrite only fixed unaliased scratch."""
	var code: StringName = _section_query_input_refusal(origin_u, out)
	if code == &"":
		code = snapshot_revision_refusal(expected_revision)
	if code != &"":
		return code
	var source: int = _find_source(room, false)
	if source < 0 or _o_kind[source] != Directory.KIND_ROOM:
		return &"SPACE_SECTION_ROOM"
	var row: int = _claimed_floor_row(room, origin_u, _o_revision[source])
	match row:
		-1: return &"SPACE_SECTION_MISSING"
		-2: return &"SPACE_SECTION_AMBIGUOUS"
		-3: return &"SPACE_SECTION_STALE"
	var section: Vector2i = Vector2i(row, _r_generation[row])
	code = snapshot_revision_refusal(expected_revision)
	if code != &"":
		return code
	if revision() != expected_revision or not _sources.directory().is_valid_of_kind(room, Directory.KIND_ROOM):
		return &"SPACE_REVISION_STALE"
	return region_into_reused(section, out)


func _section_query_input_refusal(origin_u: Vector3i, out: Region) -> StringName:
	"""Admit both complete validations and scalar scans before reading or allocating any candidate output."""
	if _ready_error != &"":
		return _ready_error
	if out == null or out.box.size() != 6:
		return &"SPACE_REGION_OUTPUT_SHAPE"
	if 4 * _region_capacity + 3 * _source_capacity > _header[16]:
		return &"SPACE_OPERATION_BUDGET"
	for axis: int in 3:
		var far: int = int(origin_u[axis]) + Space.QUANTUM_U
		if (int(origin_u[axis]) - _header[5 + axis]) % Space.QUANTUM_U != 0 \
				or not Space.int32(far) or origin_u[axis] < _domain._bounds[axis] \
				or far > _domain._bounds[axis + 3]:
			return &"SPACE_SITE_DOMAIN"
	return &""


func _claimed_floor_row(room: Vector2i, origin_u: Vector3i, source_revision_value: int) -> int:
	"""All intersecting exact Room claims must retain one full section, regardless of the cube's height."""
	var found: int = -1
	for row: int in _region_capacity:
		if not _room_claim_intersects_cube(row, room, origin_u):
			continue
		var section: Vector2i = Vector2i(_r_section_slot[row], _r_section_generation[row])
		if not _region_live(section, false) or _r_role[section.x] != Space.FLOOR_DATUM \
				or _r_claim_kind[section.x] != CLAIM_NONE or _r_level[section.x] != _r_level[row] \
				or Vector2i(_r_owner_slot[section.x], _r_owner_generation[section.x]) != room \
				or Vector2i(_r_section_slot[section.x], _r_section_generation[section.x]) != section \
				or _r_owner_revision[row] != source_revision_value \
				or _r_owner_revision[section.x] != source_revision_value:
			return -3
		if found >= 0 and found != section.x:
			return -2
		found = section.x
	return found


func _room_claim_intersects_cube(row: int, room: Vector2i, origin_u: Vector3i) -> bool:
	"""Half-open full 3D overlap excludes touching claims and every physical/non-Room row without box copies."""
	return _r_present[row] == 1 and _r_claim_kind[row] == CLAIM_ROOM \
		and Vector2i(_r_claim_slot[row], _r_claim_generation[row]) == room \
		and Vector2i(_r_owner_slot[row], _r_owner_generation[row]) == room \
		and _r_lo_x[row] < int(origin_u.x) + Space.QUANTUM_U and origin_u.x < _r_hi_x[row] \
		and _r_lo_y[row] < int(origin_u.y) + Space.QUANTUM_U and origin_u.y < _r_hi_y[row] \
		and _r_lo_z[row] < int(origin_u.z) + Space.QUANTUM_U and origin_u.z < _r_hi_z[row]


func snapshot_into(out: Space.Snapshot) -> StringName:
	"""Copy the complete survey including every confirmed claim as an obstacle; no generic exemption."""
	return _copy_snapshot_into(out, NULL_REF, NULL_REF)


func snapshot_for_traversal_into(out: Space.Snapshot) -> StringName:
	"""Observe actual physical traversal truth; this does not authorize digging, placement or unsupported travel."""
	return _copy_snapshot_into(out, NULL_REF, NULL_REF, true)


func snapshot_for_traversal_leased_into(out: Space.Snapshot, budget: Budget, cold_token: int) -> StringName:
	"""Require the caller's exact bound arena before observers and again immediately before the live copy."""
	var bytes: int = 48 * _region_capacity + 16 * _source_capacity + SNAPSHOT_COPY_CONTROL_BYTES + _snapshot_output_bytes(out)
	var code: StringName = _leased_snapshot_refusal(out, budget, cold_token, bytes)
	if code != &"":
		return code
	var expected_revision: int = revision()
	if not _begin_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	code = _snapshot_refusal()
	if _end_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if code != &"":
		return code
	if revision() != expected_revision or has_prepared() or _validation_sources >= 0:
		return &"SPACE_REVISION_STALE"
	bytes = 48 * _region_capacity + 16 * _source_capacity + SNAPSHOT_COPY_CONTROL_BYTES + _snapshot_output_bytes(out)
	if not budget.covers(cold_token, bytes):
		return Budget.REFUSE_TOKEN
	var image: Space.Snapshot = _snapshot_image(NULL_REF, NULL_REF, true)
	out.version = image.version
	out.world_ref = image.world_ref
	out.revision = image.revision
	out.live_refs = image.live_refs
	out.live_revisions = image.live_revisions
	out.volumes = image.volumes
	return &""


func _leased_snapshot_refusal(out: Space.Snapshot, budget: Budget, token: int, bytes: int) -> StringName:
	"""Reject incompatible state, an unaffordable full copy or a missing original lease before source callbacks."""
	if _reject_room_reentry():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if out == null or _ready_error != &"":
		return &"SPACE_WORLD_UNBOUND"
	if has_prepared() or _validation_sources >= 0:
		return &"SPACE_SNAPSHOT_BUSY"
	if budget == null or not budget.covers(token, bytes):
		return Budget.REFUSE_TOKEN
	if 2 * (_region_capacity + _source_capacity) > _header[16]:
		return &"SPACE_OPERATION_BUDGET"
	return &""


func _snapshot_output_bytes(out: Space.Snapshot) -> int:
	"""Count caller-retained packed columns which coexist with the new image, including a replaced output table."""
	if out == null:
		return 0
	var bytes: int = 4 * out.live_refs.size() + 8 * out.live_revisions.size()
	var rows: Space.Volumes = out.volumes
	if rows == null:
		return bytes
	return bytes + 4 * (rows.lo_x.size() + rows.lo_y.size() + rows.lo_z.size() + rows.hi_x.size()
		+ rows.hi_y.size() + rows.hi_z.size() + rows.role.size() + rows.level.size()
		+ rows.owner_slot.size() + rows.owner_generation.size()) + 8 * rows.owner_revision.size()


func snapshot_revision_refusal(expected_revision: int) -> StringName:
	"""Revalidate retained live survey evidence without allocating another snapshot or repeated owner lookups."""
	if _ready_error != &"":
		return _ready_error
	if expected_revision != revision():
		return &"SPACE_REVISION_STALE"
	return _snapshot_refusal()


func snapshot_for_site_into(out: Space.Snapshot, sites: Sites, site: Vector2i) -> StringName:
	"""Exempt only exact Room/phase claims after proving actual Sites ownership in this world."""
	var code: StringName = _site_scope_refusal(sites, site)
	if code != &"":
		return code
	return _copy_snapshot_into(out, sites.room_of(site), sites.project_of(site))


func site_scope_refusal(sites: Sites, site: Vector2i) -> StringName:
	"""Validate the complete actual Sites/Room/domain scope without allocating an unused snapshot."""
	return _site_scope_refusal(sites, site)


func _site_scope_refusal(sites: Sites, site: Vector2i) -> StringName:
	"""A real construction owner, immutable domain and exact physical key bind the claim scope."""
	if _ready_error != &"" or sites == null or _sources.construction_owner() == null \
			or _sources.construction_owner().excavation_authority() != sites:
		return &"SPACE_SITE_OWNER_MISMATCH"
	if sites.initialization_refusal() != &"" or not sites.is_live_site(site):
		return &"SPACE_SITE_STALE"
	var room: Vector2i = sites.room_of(site)
	var code: StringName = _claim_refusal(CLAIM_ROOM, room, room)
	if code != &"":
		return code
	if sites.site_at(sites.origin_of(site)) != site or Space.quantum_box(_domain, sites.origin_of(site)).is_empty():
		return &"SPACE_SITE_DOMAIN"
	return _site_domain_refusal(sites)


func _site_domain_refusal(sites: Sites) -> StringName:
	"""Claim scope cannot transfer between worlds that happen to allocate the same reference numbers."""
	var spatial: Contract.SpatialAuthority = sites.bound_spatial_authority()
	var actual: Contract.Domain = Contract.Domain.new()
	if spatial == null or not spatial.domain_into(actual):
		return &"SPACE_SITE_DOMAIN"
	var binding: Dictionary = _domain.descriptor()
	return &"" if actual.world_ref == binding.world_ref and actual.datum_u == binding.datum_u \
		and actual.minimum_quantum == binding.min_quantum and actual.size_quanta == binding.size_quanta \
		else &"SPACE_SITE_DOMAIN"


func _copy_snapshot_into(out: Space.Snapshot, room: Vector2i, project: Vector2i,
		traversal: bool = false) -> StringName:
	"""Allocate only after all source/claim truth is checked; actual geometry is never filtered."""
	if out == null or _ready_error != &"":
		return &"SPACE_WORLD_UNBOUND"
	var code: StringName = _snapshot_refusal()
	if code != &"":
		return code
	var image: Space.Snapshot = _snapshot_image(room, project, traversal)
	out.version = Space.VERSION
	out.world_ref = image.world_ref
	out.revision = image.revision
	out.live_refs = image.live_refs
	out.live_revisions = image.live_revisions
	out.volumes = image.volumes
	return &""


func _snapshot_image(room: Vector2i, project: Vector2i, traversal: bool) -> Space.Snapshot:
	"""Build one finite image; only markers with a proven exact kind/ref pair may be omitted."""
	var image: Space.Snapshot = Space.Snapshot.new()
	image.world_ref = Vector2i(_header[3], _header[4])
	image.revision = revision()
	for row: int in _source_capacity:
		if _o_present[row] != 0:
			image.live_refs.append_array(PackedInt32Array([_o_slot[row], _o_generation[row]]))
			image.live_revisions.append(_o_revision[row])
	for row: int in _region_capacity:
		if _r_present[row] == 0 or _exempt_claim(row, room, project) or (traversal and _traversal_marker(row, false)):
			continue
		var role: int = Space.OBSTACLE if _r_claim_kind[row] != CLAIM_NONE else _r_role[row]
		image.volumes.append(_box(row, false), role, _r_level[row],
			Vector2i(_r_owner_slot[row], _r_owner_generation[row]), _r_owner_revision[row])
	return image


func _exempt_claim(row: int, room: Vector2i, project: Vector2i) -> bool:
	"""No Room exemption removes furniture, occupants, exits, actual matter or another phase's claim."""
	var ref: Vector2i = Vector2i(_r_claim_slot[row], _r_claim_generation[row])
	return (_r_claim_kind[row] == CLAIM_ROOM and room != NULL_REF and ref == room) \
		or (_r_claim_kind[row] == CLAIM_CONSTRUCTION and project != NULL_REF and ref == project)


func packed_memory_bytes() -> int:
	"""Two fixed banks, derived heaps and five-byte change scratch; excludes native/caller memory."""
	return 149 * _region_capacity + 92 * _source_capacity + 288 if _domain != null else 0


func persisted_bytes() -> int:
	"""Exact owner payload; wire serialization and live-row semantics use the same field order."""
	return REGION_BYTES * _region_capacity + SOURCE_BYTES * _source_capacity + HEADER_FIELDS * 8 if _domain != null else 0



func state_bytes() -> PackedByteArray:
	"""Canonical local payload at a completed boundary; shared save/hash registration is separate."""
	if _ready_error != &"" or has_prepared():
		return PackedByteArray()
	var out: PackedByteArray = PackedByteArray()
	out.resize(persisted_bytes())
	_write_wire(out, _wire_columns(false))
	return out


func restore_state_bytes(bytes: PackedByteArray) -> StringName:
	"""Validate a complete same-schema/domain image in the staging bank; refusal preserves live bytes."""
	if _reject_room_reentry():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if _ready_error != &"" or has_prepared() or _validation_sources >= 0:
		return &"SPACE_LOAD_BOUNDARY"
	var code: StringName = _wire_header_refusal(bytes)
	if code != &"":
		return code
	var begun: Result = begin_stage(revision())
	if not begun.ok():
		return begun.error
	if not _spend(_region_capacity):
		abort(begun.token)
		return &"SPACE_OPERATION_BUDGET"
	_read_wire(bytes, _wire_columns(true))
	_mark_loaded_changes()
	code = _loaded_columns_refusal()
	if code == &"":
		code = _validate_stage()
	if code != &"":
		abort(begun.token)
		return code
	_sealed = true
	publish(begun.token)
	_last_published_token = 0
	return &""


func _wire_header_refusal(bytes: PackedByteArray) -> StringName:
	"""Check exact declared size and immutable binding before copying any incoming column."""
	if bytes.size() != persisted_bytes():
		return &"SPACE_LOAD_SIZE"
	for index: int in HEADER_FIELDS - 1:
		if bytes.decode_s64(index * 8) != _header[index]:
			return &"SPACE_LOAD_DOMAIN"
	return &"" if bytes.decode_s64((HEADER_FIELDS - 1) * 8) > 0 else &"SPACE_LOAD_REVISION"


static func _write_wire(out: PackedByteArray, columns: Array) -> void:
	"""Explicit signed little-endian values avoid host-native array serialization assumptions."""
	var offset: int = 0
	for column: Variant in columns:
		var width: int = _column_width(column)
		for row: int in column.size():
			if width == 1:
				out[offset] = column[row]
			elif width == 4:
				out.encode_s32(offset, column[row])
			else:
				out.encode_s64(offset, column[row])
			offset += width


static func _read_wire(bytes: PackedByteArray, columns: Array) -> void:
	"""Only a preflighted exact-size image reaches these fixed preallocated columns."""
	var offset: int = 0
	for column: Variant in columns:
		var width: int = _column_width(column)
		for row: int in column.size():
			if width == 1:
				column[row] = bytes[offset]
			elif width == 4:
				column[row] = bytes.decode_s32(offset)
			else:
				column[row] = bytes.decode_s64(offset)
			offset += width


static func _column_width(column: Variant) -> int:
	"""The fixed wire schema admits only the three authoritative packed integer column types."""
	if column is PackedByteArray:
		return 1
	return 4 if column is PackedInt32Array else 8


func _wire_columns(staged: bool) -> Array:
	"""Borrow the fixed thirty-one column resources privately; callers never receive these arrays."""
	if staged:
		return [_s_header, _s_r_present, _s_r_retired, _s_r_role, _s_r_claim_kind, _s_r_generation,
			_s_r_lo_x, _s_r_lo_y, _s_r_lo_z, _s_r_hi_x, _s_r_hi_y, _s_r_hi_z, _s_r_level,
			_s_r_section_slot, _s_r_section_generation, _s_r_owner_slot, _s_r_owner_generation,
			_s_r_owner_revision, _s_r_claim_slot, _s_r_claim_generation, _s_o_present, _s_o_kind,
			_s_o_slot, _s_o_generation, _s_o_revision, _s_o_parent_slot, _s_o_parent_generation,
			_s_o_a, _s_o_b, _s_o_c, _s_o_d]
	return [_header, _r_present, _r_retired, _r_role, _r_claim_kind, _r_generation,
		_r_lo_x, _r_lo_y, _r_lo_z, _r_hi_x, _r_hi_y, _r_hi_z, _r_level,
		_r_section_slot, _r_section_generation, _r_owner_slot, _r_owner_generation,
		_r_owner_revision, _r_claim_slot, _r_claim_generation, _o_present, _o_kind,
		_o_slot, _o_generation, _o_revision, _o_parent_slot, _o_parent_generation,
		_o_a, _o_b, _o_c, _o_d]


func _loaded_columns_refusal() -> StringName:
	"""Presence, retirement and canonical free data are part of the saved deterministic allocator."""
	if not _spend(_region_capacity + _source_capacity):
		return &"SPACE_OPERATION_BUDGET"
	for row: int in _region_capacity:
		if _s_r_present[row] > 1 or _s_r_retired[row] > 1 or _s_r_generation[row] < 0:
			return &"SPACE_LOAD_LIFECYCLE"
		if _s_r_present[row] != 0:
			if _s_r_retired[row] != 0 or _s_r_generation[row] < 1:
				return &"SPACE_LOAD_LIFECYCLE"
		elif not _unused_region_canonical(row):
			return &"SPACE_LOAD_UNUSED"
		elif (_s_r_retired[row] != 0) != (_s_r_generation[row] == I32_MAX):
			return &"SPACE_LOAD_LIFECYCLE"
	for row: int in _source_capacity:
		var code: StringName = _loaded_source_refusal(row)
		if code != &"":
			return code
	return &"" # Exact World presence and duplicate source slots are checked through the sealed index.


func _unused_region_canonical(row: int) -> bool:
	"""Unused rows cannot carry hidden geometry or claims that differ after a deterministic load."""
	return _s_r_role[row] == 0 and _s_r_claim_kind[row] == 0 and _s_r_level[row] == 0 \
		and _s_r_lo_x[row] == 0 and _s_r_lo_y[row] == 0 and _s_r_lo_z[row] == 0 \
		and _s_r_hi_x[row] == 0 and _s_r_hi_y[row] == 0 and _s_r_hi_z[row] == 0 \
		and _s_r_section_slot[row] == -1 and _s_r_section_generation[row] == 0 \
		and _s_r_owner_slot[row] == -1 and _s_r_owner_generation[row] == 0 \
		and _s_r_owner_revision[row] == 0 and _s_r_claim_slot[row] == -1 and _s_r_claim_generation[row] == 0


func _loaded_source_refusal(row: int) -> StringName:
	"""Global slots have one live source record, and inactive source rows have no retained facts."""
	if _s_o_present[row] > 1:
		return &"SPACE_LOAD_LIFECYCLE"
	if _s_o_present[row] == 0:
		return &"" if _unused_source_canonical(row) else &"SPACE_LOAD_UNUSED"
	if _s_o_revision[row] < 1 or not Space.valid_ref(Vector2i(_s_o_slot[row], _s_o_generation[row])):
		return &"SPACE_LOAD_SOURCE"
	return &""


func _unused_source_canonical(row: int) -> bool:
	"""A retired source is forgotten only after every physical and reserved row has released it."""
	return _s_o_kind[row] == 0 and _s_o_slot[row] == -1 and _s_o_generation[row] == 0 \
		and _s_o_revision[row] == 0 and _s_o_parent_slot[row] == -1 and _s_o_parent_generation[row] == 0 \
		and _s_o_a[row] == 0 and _s_o_b[row] == 0 and _s_o_c[row] == 0 and _s_o_d[row] == 0


func _rebuild_stage_heaps() -> void:
	"""Ascending free indices rebuild deterministic heaps without persisting heap layout scratch."""
	_s_region_free_count = 0
	_s_source_free_count = 0
	_s_region_free_heap.fill(-1)
	_s_source_free_heap.fill(-1)
	for row: int in _region_capacity:
		if _s_r_present[row] == 0 and _s_r_retired[row] == 0:
			_s_region_free_heap[_s_region_free_count] = row
			_s_region_free_count += 1
	for row: int in _source_capacity:
		if _s_o_present[row] == 0:
			_s_source_free_heap[_s_source_free_count] = row
			_s_source_free_count += 1


func _editable(token: int) -> StringName:
	"""Never mutate a sealed publication candidate or another operation's staging image."""
	if _reject_room_reentry():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if _validation_sources >= 0:
		return &"SPACE_VALIDATION_BUSY"
	if token == 0 or token != _stage_token:
		return &"SPACE_TRANSACTION_STALE"
	return &"SPACE_TRANSACTION_SEALED" if _sealed else &""


func _spend(amount: int) -> bool:
	"""One finite cold operation cannot expand into an unbounded geometry or source search."""
	if amount < 0 or amount > _remaining:
		return false
	_remaining -= amount
	return true


func _find_source(ref: Vector2i, staged: bool, charged: bool = false) -> int:
	"""A mutating cold lookup charges each visited row; public readers do not consume a transaction."""
	for row: int in _source_capacity:
		if charged and not _spend(1):
			return LOOKUP_BUDGET
		if staged and _s_o_present[row] != 0 and _s_o_slot[row] == ref.x and _s_o_generation[row] == ref.y:
			return row
		if not staged and _o_present[row] != 0 and _o_slot[row] == ref.x and _o_generation[row] == ref.y:
			return row
	return -1

func _source_unused_refusal(ref: Vector2i) -> StringName:
	"""Charge actual visited rows before retirement/rebinding can orphan retained extents."""
	for row: int in _region_capacity:
		if not _spend(1):
			return &"SPACE_OPERATION_BUDGET"
		if _s_r_present[row] != 0 and _s_r_owner_slot[row] == ref.x and _s_r_owner_generation[row] == ref.y:
			return &"SPACE_SOURCE_REBUILD_REQUIRED"
	return &""

func _region_live(ref: Vector2i, staged: bool) -> bool:
	"""Every floor link and region result uses the exact live internal generation."""
	if ref.x < 0 or ref.x >= _region_capacity or ref.y < 1:
		return false
	return (_s_r_present[ref.x] == 1 and _s_r_generation[ref.x] == ref.y) if staged \
		else (_r_present[ref.x] == 1 and _r_generation[ref.x] == ref.y)


func _box(row: int, staged: bool) -> PackedInt32Array:
	"""Copy one actual half-open XYZ extent for cold validation or caller output."""
	if staged:
		return PackedInt32Array([_s_r_lo_x[row], _s_r_lo_y[row], _s_r_lo_z[row], _s_r_hi_x[row], _s_r_hi_y[row], _s_r_hi_z[row]])
	return PackedInt32Array([_r_lo_x[row], _r_lo_y[row], _r_lo_z[row], _r_hi_x[row], _r_hi_y[row], _r_hi_z[row]])


func _region_input_error(region: Region) -> StringName:
	"""Validate integer/scalar bounds before any byte or int32 narrowing."""
	if region == null or not Space.valid_box(region.box) or not Space.contains_box(_domain._bounds, region.box):
		return &"SPACE_REGION_BOUNDS"
	if region.role < 0 or region.role >= Space.WORLD_ROLE_COUNT or not Space.int32(region.level) or region.level < 0:
		return &"SPACE_REGION_FORMAT"
	if not Space.valid_ref(region.owner) or not _nullable_ref(region.section):
		return &"SPACE_REGION_FORMAT"
	var code: StringName = _room_region_refusal(region.role, region.owner, region.claim_kind,
		region.claim_ref, region.section)
	return _claim_refusal(region.claim_kind, region.claim_ref, region.owner, true) if code == &"" else code



func _read_source(ref: Vector2i) -> StringName:
	"""Typed adapters cannot bypass the actual directory or narrow out-of-range source facts."""
	if _sources == null or _sources.directory() == null or not _sources.directory().is_valid(ref):
		return &"SPACE_SOURCE_STALE"
	var code: StringName = _sources.read_into(ref, _facts)
	if code != &"":
		return code
	if _facts.kind != _sources.directory().get_kind(ref) or not _nullable_ref(_facts.parent):
		return &"SPACE_SOURCE_FORMAT"
	if not Space.int32(_facts.a) or not Space.int32(_facts.b) or not Space.int32(_facts.c) or not Space.int32(_facts.d):
		return &"SPACE_SOURCE_FORMAT"
	if _facts.kind not in [Directory.KIND_WORLD, Directory.KIND_BUILDING, Directory.KIND_ROOM,
			Directory.KIND_FURNITURE, Directory.KIND_CONSTRUCTION, Directory.KIND_RESIDENT]:
		return &"SPACE_SOURCE_KIND_UNBOUND"
	if _facts.kind == Directory.KIND_WORLD and (_facts.parent != NULL_REF or _facts.a != 0 
			or _facts.b != 0 or _facts.c != 0 or _facts.d != 0):
		return &"SPACE_SOURCE_FORMAT"
	if _facts.kind == Directory.KIND_RESIDENT and (_facts.d < 0 or (_facts.parent != NULL_REF \
			and not _sources.directory().is_valid_of_kind(_facts.parent, Directory.KIND_ROOM))):
		return &"SPACE_RESIDENT_LOCATION_INVALID"
	return &""


func _snapshot_refusal() -> StringName:
	"""A full cold survey rechecks actual identities and long-lived claims before allocating copies."""
	if _region_capacity + _source_capacity > _header[16]:
		return &"SPACE_OPERATION_BUDGET"
	var code: StringName = _sources_refusal(false)
	if code != &"":
		return code
	return _claims_refusal(false)


func _claims_refusal(staged: bool, allow_prepared: bool = true) -> StringName:
	"""Long-lived Room and temporary Construction claim identities retain distinct exact namespaces."""
	for row: int in _region_capacity:
		if staged and (_s_r_present[row] == 0 or _s_r_claim_kind[row] == CLAIM_NONE):
			continue
		if not staged and (_r_present[row] == 0 or _r_claim_kind[row] == CLAIM_NONE):
			continue
		var ref: Vector2i = Vector2i(_s_r_claim_slot[row], _s_r_claim_generation[row]) if staged \
			else Vector2i(_r_claim_slot[row], _r_claim_generation[row])
		var owner: Vector2i = Vector2i(_s_r_owner_slot[row], _s_r_owner_generation[row]) if staged \
			else Vector2i(_r_owner_slot[row], _r_owner_generation[row])
		var kind: int = _s_r_claim_kind[row] if staged else _r_claim_kind[row]
		var code: StringName = _claim_refusal(kind, ref, owner, staged and allow_prepared)
		if code != &"":
			return code
	return &""


func _claim_refusal(kind: int, ref: Vector2i, owner: Vector2i, staged: bool = false) -> StringName:
	"""Check kind before narrowing; a confirmed Room claim must name that same actual Room owner."""
	if kind == CLAIM_NONE:
		return &"" if ref == NULL_REF else &"SPACE_RESERVATION_FORMAT"
	if kind == CLAIM_CONSTRUCTION:
		return _project_refusal(ref)
	if kind != CLAIM_ROOM:
		return &"SPACE_RESERVATION_FORMAT"
	if staged and _room_row >= 0 and ref == _room_candidate.ref and owner == ref:
		return _room_before_refusal()
	var code: StringName = _read_source(ref)
	if code != &"":
		return code
	return &"" if _facts.kind == Directory.KIND_ROOM and ref == owner else &"SPACE_ROOM_CLAIM_IDENTITY"


func _project_refusal(ref: Vector2i) -> StringName:
	"""A reservation names real Construction, never an arbitrary directory slot or inventory ref."""
	var code: StringName = _read_source(ref)
	if code != &"":
		return code
	return &"" if _facts.kind == Directory.KIND_CONSTRUCTION else &"SPACE_PROJECT_IDENTITY"


static func _nullable_ref(ref: Vector2i) -> bool:
	"""The only null spelling is (-1,0); half-null and negative generations refuse."""
	return ref == NULL_REF or Space.valid_ref(ref)


func _bump_source(row: int) -> StringName:
	"""One changed source gets one transaction revision; seal updates all its retained rows together."""
	if not _spend(1):
		return &"SPACE_OPERATION_BUDGET"
	if row < 0:
		return &"SPACE_REVISION_EXHAUSTED"
	if _o_present[row] == 0 or _o_slot[row] != _s_o_slot[row] \
			or _o_generation[row] != _s_o_generation[row] or _o_revision[row] != _s_o_revision[row]:
		return &""
	if _s_o_revision[row] == I64_MAX:
		return &"SPACE_REVISION_EXHAUSTED"
	_s_o_revision[row] += 1
	return &""

func _write_region(row: int, region: Region, owner_revision: int) -> void:
	"""All fields are initialized before presence is published, including a new floor's self-link."""
	_s_r_lo_x[row] = region.box[0]
	_s_r_lo_y[row] = region.box[1]
	_s_r_lo_z[row] = region.box[2]
	_s_r_hi_x[row] = region.box[3]
	_s_r_hi_y[row] = region.box[4]
	_s_r_hi_z[row] = region.box[5]
	_s_r_role[row] = region.role
	_s_r_level[row] = region.level
	_s_r_owner_slot[row] = region.owner.x
	_s_r_owner_generation[row] = region.owner.y
	_s_r_owner_revision[row] = owner_revision
	var section: Vector2i = Vector2i(row, _s_r_generation[row]) if region.role == Space.FLOOR_DATUM else region.section
	_s_r_section_slot[row] = section.x
	_s_r_section_generation[row] = section.y
	_s_r_claim_slot[row] = region.claim_ref.x
	_s_r_claim_generation[row] = region.claim_ref.y
	_s_r_claim_kind[row] = region.claim_kind
	_s_r_present[row] = 1


func _write_source_facts(row: int) -> void:
	"""Copy exact typed facts; no digest collision can preserve a changed source."""
	_s_o_kind[row] = _facts.kind
	_s_o_parent_slot[row] = _facts.parent.x
	_s_o_parent_generation[row] = _facts.parent.y
	_s_o_a[row] = _facts.a
	_s_o_b[row] = _facts.b
	_s_o_c[row] = _facts.c
	_s_o_d[row] = _facts.d


func _facts_match(row: int, staged: bool) -> bool:
	"""Temperature and material progress are deliberately absent from structural source identity."""
	if staged:
		return _facts.kind == _s_o_kind[row] and _facts.parent == Vector2i(_s_o_parent_slot[row], _s_o_parent_generation[row]) \
			and _facts.a == _s_o_a[row] and _facts.b == _s_o_b[row] and _facts.c == _s_o_c[row] and _facts.d == _s_o_d[row]
	return _facts.kind == _o_kind[row] and _facts.parent == Vector2i(_o_parent_slot[row], _o_parent_generation[row]) \
		and _facts.a == _o_a[row] and _facts.b == _o_b[row] and _facts.c == _o_c[row] and _facts.d == _o_d[row]


func _sources_refusal(staged: bool, allow_prepared: bool = true) -> StringName:
	"""Check every actual external owner, allowing only the one typed staged transition before publication."""
	if staged and _install_row >= 0:
		var code: StringName = _installation_source_refusal()
		if code != &"":
			return code
	if staged and allow_prepared and _furniture_count > 0:
		var code: StringName = _furniture_before_refusal()
		if code != &"":
			return code
	if staged and allow_prepared and _room_row >= 0:
		var code: StringName = _room_before_refusal()
		if code != &"":
			return code
	for row: int in _source_capacity:
		if (staged and _s_o_present[row] == 0) or (not staged and _o_present[row] == 0):
			continue
		var code: StringName = _source_row_refusal(row, staged, allow_prepared)
		if code != &"":
			return code
	return _room_source_refusal() if staged and allow_prepared and _room_row >= 0 else &""


func _installation_source_refusal() -> StringName:
	"""Keep the reviewed paid Furniture owner/subject preflight separate from the future Room path."""
	var router: ModularContract = _install_router.get_ref() as ModularContract if _install_router != null else null
	var owner: ModularContract.Owner = _install_owner.get_ref() as ModularContract.Owner if _install_owner != null else null
	var code: StringName = _installation_project_refusal(_install_project, router, owner)
	if code != &"":
		return code
	if _install_row >= _source_capacity or _s_o_present[_install_row] != 1 \
			or Vector2i(_s_o_slot[_install_row], _s_o_generation[_install_row]) \
			!= _sources.construction_owner().subject_ref_of(_install_project):
		return &"SPACE_INSTALLATION_SOURCE"
	return &""


func _source_row_refusal(row: int, staged: bool, allow_prepared: bool) -> StringName:
	"""Ordinary rows always read real current facts; only exact typed transition rows have before-facts."""
	if staged and allow_prepared and _furniture_count > 0:
		var ordinal: int = _furniture_ordinal(row)
		if ordinal == LOOKUP_BUDGET:
			return &"SPACE_OPERATION_BUDGET"
		if ordinal >= 0:
			return _furniture_source_refusal(ordinal)
	if staged and allow_prepared and row == _room_row:
		return _room_source_refusal()
	var ref: Vector2i = Vector2i(_s_o_slot[row], _s_o_generation[row]) if staged \
		else Vector2i(_o_slot[row], _o_generation[row])
	var code: StringName = _read_source(ref)
	if code != &"":
		return code
	if staged and allow_prepared and row == _install_row:
		return &"" if _installation_before_matches(row) else &"SPACE_INSTALLATION_BEFORE_FACTS"
	return &"" if _facts_match(row, staged) else &"SPACE_SOURCE_DRIFT"


func _installation_before_matches(row: int) -> bool:
	"""Only d=0->1 differs: actual full identity, Room, type and rotation still match live before-facts."""
	return _o_present[row] == 1 and _s_o_present[row] == 1 \
		and _o_slot[row] == _s_o_slot[row] and _o_generation[row] == _s_o_generation[row] \
		and _o_kind[row] == Directory.KIND_FURNITURE and _s_o_kind[row] == _o_kind[row] \
		and _o_parent_slot[row] == _s_o_parent_slot[row] and _o_parent_generation[row] == _s_o_parent_generation[row] \
		and _o_a[row] == _s_o_a[row] and _o_b[row] == _s_o_b[row] and _o_c[row] == _s_o_c[row] \
		and _o_d[row] == 0 and _s_o_d[row] == 1 and _facts_match(row, false)


func _validate_stage(refresh_revisions: bool = false) -> StringName:
	"""Borrow staged heaps only while edits are locked, reserving their unconditional reconstruction."""
	if not _spend(_region_capacity + _source_capacity + _furniture_count):
		return &"SPACE_OPERATION_BUDGET"
	_validation_regions = 0
	_validation_sources = 0
	for index: int in _furniture_count:
		_furniture_rows[index] &= ~FURNITURE_GEOMETRY_SEEN
	var code: StringName = _index_validation_rows()
	if code == &"":
		code = _sort_validation_sources()
	if code == &"":
		code = _validate_indexed_stage(refresh_revisions)
	_rebuild_stage_heaps()
	_validation_regions = -1
	_validation_sources = -1
	return code


func _index_validation_rows() -> StringName:
	"""Compact present rows in existing scratch without charging capacity products or allocating."""
	if not _spend(_region_capacity + _source_capacity):
		return &"SPACE_OPERATION_BUDGET"
	for row: int in _region_capacity:
		if _s_r_present[row] != 0:
			_s_region_free_heap[_validation_regions] = row
			_validation_regions += 1
	for row: int in _source_capacity:
		if _s_o_present[row] != 0:
			_s_source_free_heap[_validation_sources] = row
			_validation_sources += 1
	return &""


func _sort_validation_sources() -> StringName:
	"""Deterministic in-place heapsort joins sparse rows by exact global slot, including hole/reuse cases."""
	@warning_ignore("integer_division") var root: int = _validation_sources / 2 - 1
	while root >= 0:
		if not _sift_validation_sources(root, _validation_sources):
			return &"SPACE_OPERATION_BUDGET"
		root -= 1
	var end: int = _validation_sources - 1
	while end > 0:
		var old: int = _s_source_free_heap[end]
		_s_source_free_heap[end] = _s_source_free_heap[0]
		_s_source_free_heap[0] = old
		if not _sift_validation_sources(0, end):
			return &"SPACE_OPERATION_BUDGET"
		end -= 1
	for index: int in _validation_sources:
		if not _spend(1):
			return &"SPACE_OPERATION_BUDGET"
		if index > 0 and _s_o_slot[_s_source_free_heap[index - 1]] == _s_o_slot[_s_source_free_heap[index]]:
			return &"SPACE_LOAD_SOURCE_DUPLICATE"
	return &""


func _sift_validation_sources(root: int, count: int) -> bool:
	"""Charge every slot comparison before advancing the bounded source-index heap."""
	while root * 2 + 1 < count:
		var child: int = root * 2 + 1
		if child + 1 < count:
			if not _spend(1):
				return false
			if _s_o_slot[_s_source_free_heap[child]] < _s_o_slot[_s_source_free_heap[child + 1]]:
				child += 1
		if not _spend(1):
			return false
		if _s_o_slot[_s_source_free_heap[root]] >= _s_o_slot[_s_source_free_heap[child]]:
			break
		var old: int = _s_source_free_heap[root]
		_s_source_free_heap[root] = _s_source_free_heap[child]
		_s_source_free_heap[child] = old
		root = child
	return true


func _indexed_source(ref: Vector2i) -> int:
	"""Only the locked validation interval can use the sorted scratch, with full generation checking."""
	var first: int = 0
	var limit: int = _validation_sources
	while first < limit:
		if not _spend(1):
			return LOOKUP_BUDGET
		@warning_ignore("integer_division") var middle: int = (first + limit) / 2
		var row: int = _s_source_free_heap[middle]
		if _s_o_slot[row] == ref.x:
			return row if _s_o_generation[row] == ref.y else -1
		if _s_o_slot[row] < ref.x:
			first = middle + 1
		else:
			limit = middle
	return -1


func _validate_indexed_stage(refresh_revisions: bool) -> StringName:
	"""All source/section evidence remains mandatory; only trusted staged edits propagate revisions."""
	var world: int = _indexed_source(Vector2i(_header[3], _header[4]))
	if world == LOOKUP_BUDGET or not _spend(_source_capacity):
		return &"SPACE_OPERATION_BUDGET"
	if world < 0:
		return &"SPACE_LOAD_WORLD"
	var code: StringName = _sources_refusal(true)
	if code != &"":
		return code
	for index: int in _validation_regions:
		if not _spend(1):
			return &"SPACE_OPERATION_BUDGET"
		code = _staged_region_refusal(_s_region_free_heap[index], refresh_revisions)
		if code != &"":
			return code
	code = _room_markers_refusal()
	if code == &"":
		code = _furniture_markers_refusal()
	return _overlap_refusal() if code == &"" else code

func _room_region_refusal(role: int, ref: Vector2i, kind: int, claim: Vector2i, section: Vector2i) -> StringName:
	"""Confirmation reserves only Room metadata and blocking claims; it grants no excavation or usable void."""
	if _room_row < 0 or ref != _room_candidate.ref:
		return &""
	if role == Space.FLOOR_DATUM and kind == CLAIM_NONE and claim == NULL_REF:
		return &""
	return &"" if role == Space.OBSTACLE and kind == CLAIM_ROOM and claim == ref and section != NULL_REF \
		else &"SPACE_ROOM_ADMISSION_REGION"


func _room_markers_refusal() -> StringName:
	"""A confirmed future Room needs both datum metadata and a blocking footprint, never an empty source."""
	if _room_row < 0:
		return &""
	if not _spend(_validation_regions):
		return &"SPACE_OPERATION_BUDGET"
	var floor_found: bool = false
	var claim_found: bool = false
	for index: int in _validation_regions:
		var row: int = _s_region_free_heap[index]
		if Vector2i(_s_r_owner_slot[row], _s_r_owner_generation[row]) != _room_candidate.ref:
			continue
		floor_found = floor_found or _s_r_role[row] == Space.FLOOR_DATUM
		claim_found = claim_found or _s_r_claim_kind[row] == CLAIM_ROOM
	return &"" if floor_found and claim_found else &"SPACE_ROOM_ADMISSION_FOOTPRINT"


func _staged_region_refusal(row: int, refresh_revisions: bool) -> StringName:
	"""Actual extents retain complete owner, section and project generations at every height."""
	if not Space.valid_box(_box(row, true)) or not Space.contains_box(_domain._bounds, _box(row, true)):
		return &"SPACE_REGION_BOUNDS"
	if _s_r_role[row] >= Space.WORLD_ROLE_COUNT or _s_r_level[row] < 0 or _s_r_claim_kind[row] > CLAIM_ROOM:
		return &"SPACE_REGION_FORMAT"
	if _s_r_claim_kind[row] == 0 and Vector2i(_s_r_claim_slot[row], _s_r_claim_generation[row]) != NULL_REF:
		return &"SPACE_RESERVATION_FORMAT"
	var owner: int = _indexed_source(Vector2i(_s_r_owner_slot[row], _s_r_owner_generation[row]))
	if owner == LOOKUP_BUDGET:
		return &"SPACE_OPERATION_BUDGET"
	if owner < 0:
		return &"SPACE_SOURCE_STALE"
	if refresh_revisions:
		_s_r_owner_revision[row] = _s_o_revision[owner]
	if _s_r_owner_revision[row] != _s_o_revision[owner]:
		return &"SPACE_SOURCE_STALE"
	var code: StringName = _room_region_refusal(_s_r_role[row],
		Vector2i(_s_r_owner_slot[row], _s_r_owner_generation[row]), _s_r_claim_kind[row],
		Vector2i(_s_r_claim_slot[row], _s_r_claim_generation[row]),
		Vector2i(_s_r_section_slot[row], _s_r_section_generation[row]))
	if code == &"":
		code = _section_refusal(row, owner)
	return _furniture_region_refusal(row, owner) if code == &"" else code


func _section_refusal(row: int, owner: int) -> StringName:
	"""A floor link retains exact generation and actual room ownership, independent of level labels."""
	var section: Vector2i = Vector2i(_s_r_section_slot[row], _s_r_section_generation[row])
	if not _nullable_ref(section):
		return &"SPACE_SECTION_STALE"
	if _s_r_role[row] == Space.FLOOR_DATUM:
		if section != Vector2i(row, _s_r_generation[row]):
			return &"SPACE_SECTION_STALE"
	elif section != NULL_REF:
		if not _region_live(section, true) or _s_r_role[section.x] != Space.FLOOR_DATUM \
				or _s_r_level[section.x] != _s_r_level[row] or _s_r_claim_kind[section.x] != 0:
			return &"SPACE_SECTION_STALE"
	return _section_owner_refusal(row, owner, section)


func _section_owner_refusal(row: int, owner: int, section: Vector2i) -> StringName:
	"""Furniture and residents retain their real containing room; coordinates still decide collision."""
	if _s_o_kind[owner] == Directory.KIND_FURNITURE and section == NULL_REF:
		return &"SPACE_SECTION_MISSING"
	if section != NULL_REF and _s_o_kind[owner] in [Directory.KIND_FURNITURE, Directory.KIND_RESIDENT]:
		if Vector2i(_s_r_owner_slot[section.x], _s_r_owner_generation[section.x]) \
				!= Vector2i(_s_o_parent_slot[owner], _s_o_parent_generation[owner]):
			return &"SPACE_SECTION_OWNER"
	if _s_o_kind[owner] == Directory.KIND_RESIDENT:
		var code: StringName = _resident_region_refusal(row, owner, section)
		if code != &"":
			return code
	if owner == _room_row and section != NULL_REF and Vector2i(_s_r_owner_slot[section.x],
			_s_r_owner_generation[section.x]) != _room_candidate.ref:
		return &"SPACE_SECTION_OWNER"
	if _s_r_claim_kind[row] != 0:
		return _claim_refusal(_s_r_claim_kind[row], Vector2i(_s_r_claim_slot[row], _s_r_claim_generation[row]),
			Vector2i(_s_r_owner_slot[row], _s_r_owner_generation[row]), true)
	return &""


func _resident_region_refusal(row: int, owner: int, section: Vector2i) -> StringName:
	"""Resident envelopes contain the actual XYZ anchor; no mode, room or level is guessed."""
	if _s_r_role[row] != Space.OCCUPANT or _s_r_claim_kind[row] != 0:
		return &"SPACE_RESIDENT_REGION_ROLE"
	if _s_o_parent_slot[owner] != -1 and section == NULL_REF:
		return &"SPACE_SECTION_MISSING"
	if _s_o_a[owner] < _s_r_lo_x[row] or _s_o_a[owner] >= _s_r_hi_x[row] \
			or _s_o_b[owner] < _s_r_lo_y[row] or _s_o_b[owner] >= _s_r_hi_y[row] \
			or _s_o_c[owner] < _s_r_lo_z[row] or _s_o_c[owner] >= _s_r_hi_z[row]:
		return &"SPACE_RESIDENT_POSITION"
	return &""


func _mark_changed(row: int) -> void:
	"""One finite scratch index per edited row avoids revalidating already-proven unchanged pairs."""
	if _changed_mask[row] == 0:
		_changed_mask[row] = 1
		_changed_rows[_changed_count] = row
		_changed_count += 1


func _mark_loaded_changes() -> void:
	"""A decoded image compares exact geometry against the current already-validated live image."""
	for row: int in _region_capacity:
		if not _same_spatial_row(row):
			_mark_changed(row)


func _same_spatial_row(row: int) -> bool:
	"""Load differences include lifecycle, owner and section identities as well as exact spatial facts."""
	return _r_present[row] == _s_r_present[row] and _r_role[row] == _s_r_role[row] \
		and _r_generation[row] == _s_r_generation[row] and _r_retired[row] == _s_r_retired[row] \
		and _r_level[row] == _s_r_level[row] and _r_section_slot[row] == _s_r_section_slot[row] \
		and _r_section_generation[row] == _s_r_section_generation[row] \
		and _r_owner_slot[row] == _s_r_owner_slot[row] and _r_owner_generation[row] == _s_r_owner_generation[row] \
		and _r_owner_revision[row] == _s_r_owner_revision[row] \
		and _r_claim_kind[row] == _s_r_claim_kind[row] \
		and _r_lo_x[row] == _s_r_lo_x[row] and _r_lo_y[row] == _s_r_lo_y[row] and _r_lo_z[row] == _s_r_lo_z[row] \
		and _r_hi_x[row] == _s_r_hi_x[row] and _r_hi_y[row] == _s_r_hi_y[row] and _r_hi_z[row] == _s_r_hi_z[row] \
		and _r_claim_slot[row] == _s_r_claim_slot[row] and _r_claim_generation[row] == _s_r_claim_generation[row]


func _overlap_refusal() -> StringName:
	"""Only changed-versus-present pairs need checks; empty capacity rows never multiply the charge."""
	for index: int in _changed_count:
		if not _spend(1):
			return &"SPACE_OPERATION_BUDGET"
		var first: int = _changed_rows[index]
		if _s_r_present[first] == 0:
			continue
		for other: int in _validation_regions:
			if not _spend(1):
				return &"SPACE_OPERATION_BUDGET"
			var second: int = _s_region_free_heap[other]
			if second == first or (_changed_mask[second] != 0 and second < first):
				continue
			if not _rows_overlap(first, second):
				continue
			var code: StringName = _pair_refusal(first, second)
			if code != &"":
				return code
	return &""

func _rows_overlap(first: int, second: int) -> bool:
	"""Exact half-open scalar overlap avoids allocating two six-column boxes for every pair."""
	return _s_r_lo_x[first] < _s_r_hi_x[second] and _s_r_lo_x[second] < _s_r_hi_x[first] \
		and _s_r_lo_y[first] < _s_r_hi_y[second] and _s_r_lo_y[second] < _s_r_hi_y[first] \
		and _s_r_lo_z[first] < _s_r_hi_z[second] and _s_r_lo_z[second] < _s_r_hi_z[first]


func _pair_refusal(first: int, second: int) -> StringName:
	"""Actual conflicting matter or foreign claims cannot win by allocation or mutation order."""
	if _s_r_claim_kind[first] != CLAIM_NONE and _s_r_claim_kind[second] != CLAIM_NONE:
		var a: Vector2i = Vector2i(_s_r_claim_slot[first], _s_r_claim_generation[first])
		var b: Vector2i = Vector2i(_s_r_claim_slot[second], _s_r_claim_generation[second])
		if _s_r_claim_kind[first] == _s_r_claim_kind[second] and a == b:
			return &""
		if _s_r_claim_kind[first] == CLAIM_ROOM and _s_r_claim_kind[second] == CLAIM_CONSTRUCTION \
				and _phase_belongs_to_room(b, a):
			return &""
		if _s_r_claim_kind[second] == CLAIM_ROOM and _s_r_claim_kind[first] == CLAIM_CONSTRUCTION \
				and _phase_belongs_to_room(a, b):
			return &""
		return &"SPACE_RESERVATION_CONFLICT"
	if _s_r_claim_kind[first] == CLAIM_NONE and _s_r_claim_kind[second] == CLAIM_NONE \
			and _contradictory_roles(_s_r_role[first], _s_r_role[second]):
		return &"SPACE_SURVEY_CONTRADICTION"
	return &""


func _phase_belongs_to_room(project: Vector2i, room: Vector2i) -> bool:
	"""Only the real physical ledger may connect a transient paid phase to a persistent Room claim."""
	var construction: Construction = _sources.construction_owner()
	if construction == null or not construction.is_live_project(project):
		return false
	var sites: Sites = construction.excavation_authority() as Sites
	if sites == null:
		return false
	var site: Vector2i = construction.subject_ref_of(project)
	return _site_scope_refusal(sites, site) == &"" and sites.project_of(site) == project and sites.room_of(site) == room


static func _contradictory_roles(first: int, second: int) -> bool:
	"""Unfinished actual void is not solid; a reservation marker alone proves neither."""
	return (first == Space.DRY_SOLID and second in [Space.SUPPORTED_VOID, Space.UNFINISHED]) \
		or (second == Space.DRY_SOLID and first in [Space.SUPPORTED_VOID, Space.UNFINISHED])


static func _heap_pop(heap: PackedInt32Array, count: int) -> int:
	"""Remove the lowest available slot without allocating or relying on Dictionary order."""
	var result: int = heap[0]
	count -= 1
	var value: int = heap[count]
	var at: int = 0
	while at * 2 + 1 < count:
		var child: int = at * 2 + 1
		if child + 1 < count and heap[child + 1] < heap[child]:
			child += 1
		if heap[child] >= value:
			break
		heap[at] = heap[child]
		at = child
	heap[at] = value
	heap[count] = -1
	return result


static func _heap_push(heap: PackedInt32Array, count: int, value: int) -> void:
	"""Restore a free index in its deterministic min-heap."""
	var at: int = count
	while at > 0:
		@warning_ignore("integer_division") var parent: int = (at - 1) / 2
		if heap[parent] <= value:
			break
		heap[at] = heap[parent]
		at = parent
	heap[at] = value


func _allocate_columns() -> void:
	"""Every authoritative and staging buffer is allocated once to its explicit finite capacity."""
	_header.resize(HEADER_FIELDS)
	_s_header.resize(HEADER_FIELDS)
	_changed_rows.resize(_region_capacity)
	_changed_mask.resize(_region_capacity)
	_region_free_heap.resize(_region_capacity)
	_s_region_free_heap.resize(_region_capacity)
	_source_free_heap.resize(_source_capacity)
	_s_source_free_heap.resize(_source_capacity)
	_allocate_regions()
	_allocate_sources()


func _allocate_regions() -> void:
	"""Preallocate the live regions columns; never resize per resident or tick."""
	_r_present.resize(_region_capacity)
	_r_retired.resize(_region_capacity)
	_r_role.resize(_region_capacity)
	_r_claim_kind.resize(_region_capacity)
	_r_generation.resize(_region_capacity)
	_r_lo_x.resize(_region_capacity)
	_r_lo_y.resize(_region_capacity)
	_r_lo_z.resize(_region_capacity)
	_r_hi_x.resize(_region_capacity)
	_r_hi_y.resize(_region_capacity)
	_r_hi_z.resize(_region_capacity)
	_r_level.resize(_region_capacity)
	_r_section_slot.resize(_region_capacity)
	_r_section_generation.resize(_region_capacity)
	_r_owner_slot.resize(_region_capacity)
	_r_owner_generation.resize(_region_capacity)
	_r_owner_revision.resize(_region_capacity)
	_r_claim_slot.resize(_region_capacity)
	_r_claim_generation.resize(_region_capacity)
	_allocate_s_regions()


func _allocate_s_regions() -> void:
	"""Preallocate the s_regions columns; never resize per resident or tick."""
	_s_r_present.resize(_region_capacity)
	_s_r_retired.resize(_region_capacity)
	_s_r_role.resize(_region_capacity)
	_s_r_claim_kind.resize(_region_capacity)
	_s_r_generation.resize(_region_capacity)
	_s_r_lo_x.resize(_region_capacity)
	_s_r_lo_y.resize(_region_capacity)
	_s_r_lo_z.resize(_region_capacity)
	_s_r_hi_x.resize(_region_capacity)
	_s_r_hi_y.resize(_region_capacity)
	_s_r_hi_z.resize(_region_capacity)
	_s_r_level.resize(_region_capacity)
	_s_r_section_slot.resize(_region_capacity)
	_s_r_section_generation.resize(_region_capacity)
	_s_r_owner_slot.resize(_region_capacity)
	_s_r_owner_generation.resize(_region_capacity)
	_s_r_owner_revision.resize(_region_capacity)
	_s_r_claim_slot.resize(_region_capacity)
	_s_r_claim_generation.resize(_region_capacity)


func _allocate_sources() -> void:
	"""Preallocate the live sources columns; never resize per resident or tick."""
	_o_present.resize(_source_capacity)
	_o_kind.resize(_source_capacity)
	_o_slot.resize(_source_capacity)
	_o_generation.resize(_source_capacity)
	_o_revision.resize(_source_capacity)
	_o_parent_slot.resize(_source_capacity)
	_o_parent_generation.resize(_source_capacity)
	_o_a.resize(_source_capacity)
	_o_b.resize(_source_capacity)
	_o_c.resize(_source_capacity)
	_o_d.resize(_source_capacity)
	_allocate_s_sources()


func _allocate_s_sources() -> void:
	"""Preallocate the s_sources columns; never resize per resident or tick."""
	_s_o_present.resize(_source_capacity)
	_s_o_kind.resize(_source_capacity)
	_s_o_slot.resize(_source_capacity)
	_s_o_generation.resize(_source_capacity)
	_s_o_revision.resize(_source_capacity)
	_s_o_parent_slot.resize(_source_capacity)
	_s_o_parent_generation.resize(_source_capacity)
	_s_o_a.resize(_source_capacity)
	_s_o_b.resize(_source_capacity)
	_s_o_c.resize(_source_capacity)
	_s_o_d.resize(_source_capacity)


func _clear_region(row: int, staged: bool) -> void:
	"""Canonical unused fields preserve only the internal generation/retirement history."""
	if staged:
		_clear_s_region(row)
	else:
		_clear_live_region(row)


func _clear_live_region(row: int) -> void:
	"""Do not erase free-slot generations while clearing a previously used row."""
	_r_present[row] = 0
	_r_role[row] = 0
	_r_claim_kind[row] = 0
	_r_lo_x[row] = 0
	_r_lo_y[row] = 0
	_r_lo_z[row] = 0
	_r_hi_x[row] = 0
	_r_hi_y[row] = 0
	_r_hi_z[row] = 0
	_r_level[row] = 0
	_r_section_slot[row] = -1
	_r_section_generation[row] = 0
	_r_owner_slot[row] = -1
	_r_owner_generation[row] = 0
	_r_owner_revision[row] = 0
	_r_claim_slot[row] = -1
	_r_claim_generation[row] = 0


func _clear_s_region(row: int) -> void:
	"""Do not erase free-slot generations while clearing a previously used row."""
	_s_r_present[row] = 0
	_s_r_role[row] = 0
	_s_r_claim_kind[row] = 0
	_s_r_lo_x[row] = 0
	_s_r_lo_y[row] = 0
	_s_r_lo_z[row] = 0
	_s_r_hi_x[row] = 0
	_s_r_hi_y[row] = 0
	_s_r_hi_z[row] = 0
	_s_r_level[row] = 0
	_s_r_section_slot[row] = -1
	_s_r_section_generation[row] = 0
	_s_r_owner_slot[row] = -1
	_s_r_owner_generation[row] = 0
	_s_r_owner_revision[row] = 0
	_s_r_claim_slot[row] = -1
	_s_r_claim_generation[row] = 0


func _clear_source(row: int, staged: bool) -> void:
	"""Canonical unused fields preserve only the internal generation/retirement history."""
	if staged:
		_clear_s_source(row)
	else:
		_clear_live_source(row)


func _clear_live_source(row: int) -> void:
	"""Do not erase free-slot generations while clearing a previously used row."""
	_o_present[row] = 0
	_o_kind[row] = 0
	_o_slot[row] = -1
	_o_generation[row] = 0
	_o_revision[row] = 0
	_o_parent_slot[row] = -1
	_o_parent_generation[row] = 0
	_o_a[row] = 0
	_o_b[row] = 0
	_o_c[row] = 0
	_o_d[row] = 0


func _clear_s_source(row: int) -> void:
	"""Do not erase free-slot generations while clearing a previously used row."""
	_s_o_present[row] = 0
	_s_o_kind[row] = 0
	_s_o_slot[row] = -1
	_s_o_generation[row] = 0
	_s_o_revision[row] = 0
	_s_o_parent_slot[row] = -1
	_s_o_parent_generation[row] = 0
	_s_o_a[row] = 0
	_s_o_b[row] = 0
	_s_o_c[row] = 0
	_s_o_d[row] = 0


func _copy_into_stage() -> void:
	"""Fill the preallocated alternate bank without replacing it with an unbudgeted duplicate."""
	for index: int in HEADER_FIELDS:
		_s_header[index] = _header[index]
	_copy_regions_into_stage()
	_copy_sources_into_stage()
	_s_region_free_count = _region_free_count
	_s_source_free_count = _source_free_count


func _copy_regions_into_stage() -> void:
	"""Copy every live and unused packed slot, including generation history."""
	for row: int in _region_capacity:
		_s_r_present[row] = _r_present[row]
		_s_r_retired[row] = _r_retired[row]
		_s_r_role[row] = _r_role[row]
		_s_r_claim_kind[row] = _r_claim_kind[row]
		_s_r_generation[row] = _r_generation[row]
		_s_r_lo_x[row] = _r_lo_x[row]
		_s_r_lo_y[row] = _r_lo_y[row]
		_s_r_lo_z[row] = _r_lo_z[row]
		_s_r_hi_x[row] = _r_hi_x[row]
		_s_r_hi_y[row] = _r_hi_y[row]
		_s_r_hi_z[row] = _r_hi_z[row]
		_s_r_level[row] = _r_level[row]
		_s_r_section_slot[row] = _r_section_slot[row]
		_s_r_section_generation[row] = _r_section_generation[row]
		_s_r_owner_slot[row] = _r_owner_slot[row]
		_s_r_owner_generation[row] = _r_owner_generation[row]
		_s_r_owner_revision[row] = _r_owner_revision[row]
		_s_r_claim_slot[row] = _r_claim_slot[row]
		_s_r_claim_generation[row] = _r_claim_generation[row]
		_s_region_free_heap[row] = _region_free_heap[row]


func _copy_sources_into_stage() -> void:
	"""Copy every live and unused packed slot, including generation history."""
	for row: int in _source_capacity:
		_s_o_present[row] = _o_present[row]
		_s_o_kind[row] = _o_kind[row]
		_s_o_slot[row] = _o_slot[row]
		_s_o_generation[row] = _o_generation[row]
		_s_o_revision[row] = _o_revision[row]
		_s_o_parent_slot[row] = _o_parent_slot[row]
		_s_o_parent_generation[row] = _o_parent_generation[row]
		_s_o_a[row] = _o_a[row]
		_s_o_b[row] = _o_b[row]
		_s_o_c[row] = _o_c[row]
		_s_o_d[row] = _o_d[row]
		_s_source_free_heap[row] = _source_free_heap[row]


func _swap_banks() -> void:
	"""Swap complete prevalidated resources only; no copy, callback or allocation follows payment."""
	_swap_columns_0()
	_swap_columns_1()
	_swap_columns_2()
	_swap_columns_3()
	_swap_columns_4()
	var count: int = _region_free_count
	_region_free_count = _s_region_free_count
	_s_region_free_count = count
	count = _source_free_count
	_source_free_count = _s_source_free_count
	_s_source_free_count = count
	_last_published_token = _stage_token


func _swap_columns_0() -> void:
	"""Keep ordinary publication behavior while sharing the static field swap."""
	_commit_columns_0(self)


static func _commit_columns_0(actual: RefCounted) -> void:
	"""One fixed publication group in the declared packed-field order."""
	var saved_0: PackedInt64Array = actual._header
	actual._header = actual._s_header
	actual._s_header = saved_0
	var saved_1: PackedInt32Array = actual._region_free_heap
	actual._region_free_heap = actual._s_region_free_heap
	actual._s_region_free_heap = saved_1
	var saved_2: PackedInt32Array = actual._source_free_heap
	actual._source_free_heap = actual._s_source_free_heap
	actual._s_source_free_heap = saved_2
	var saved_3: PackedByteArray = actual._r_present
	actual._r_present = actual._s_r_present
	actual._s_r_present = saved_3
	var saved_4: PackedByteArray = actual._r_retired
	actual._r_retired = actual._s_r_retired
	actual._s_r_retired = saved_4
	var saved_5: PackedByteArray = actual._r_role
	actual._r_role = actual._s_r_role
	actual._s_r_role = saved_5
	var saved_6: PackedByteArray = actual._r_claim_kind
	actual._r_claim_kind = actual._s_r_claim_kind
	actual._s_r_claim_kind = saved_6


func _swap_columns_1() -> void:
	"""Keep ordinary publication behavior while sharing the static field swap."""
	_commit_columns_1(self)


static func _commit_columns_1(actual: RefCounted) -> void:
	"""One fixed publication group in the declared packed-field order."""
	var saved_0: PackedInt32Array = actual._r_generation
	actual._r_generation = actual._s_r_generation
	actual._s_r_generation = saved_0
	var saved_1: PackedInt32Array = actual._r_lo_x
	actual._r_lo_x = actual._s_r_lo_x
	actual._s_r_lo_x = saved_1
	var saved_2: PackedInt32Array = actual._r_lo_y
	actual._r_lo_y = actual._s_r_lo_y
	actual._s_r_lo_y = saved_2
	var saved_3: PackedInt32Array = actual._r_lo_z
	actual._r_lo_z = actual._s_r_lo_z
	actual._s_r_lo_z = saved_3
	var saved_4: PackedInt32Array = actual._r_hi_x
	actual._r_hi_x = actual._s_r_hi_x
	actual._s_r_hi_x = saved_4
	var saved_5: PackedInt32Array = actual._r_hi_y
	actual._r_hi_y = actual._s_r_hi_y
	actual._s_r_hi_y = saved_5
	var saved_6: PackedInt32Array = actual._r_hi_z
	actual._r_hi_z = actual._s_r_hi_z
	actual._s_r_hi_z = saved_6


func _swap_columns_2() -> void:
	"""Keep ordinary publication behavior while sharing the static field swap."""
	_commit_columns_2(self)


static func _commit_columns_2(actual: RefCounted) -> void:
	"""One fixed publication group in the declared packed-field order."""
	var saved_0: PackedInt32Array = actual._r_level
	actual._r_level = actual._s_r_level
	actual._s_r_level = saved_0
	var saved_1: PackedInt32Array = actual._r_section_slot
	actual._r_section_slot = actual._s_r_section_slot
	actual._s_r_section_slot = saved_1
	var saved_2: PackedInt32Array = actual._r_section_generation
	actual._r_section_generation = actual._s_r_section_generation
	actual._s_r_section_generation = saved_2
	var saved_3: PackedInt32Array = actual._r_owner_slot
	actual._r_owner_slot = actual._s_r_owner_slot
	actual._s_r_owner_slot = saved_3
	var saved_4: PackedInt32Array = actual._r_owner_generation
	actual._r_owner_generation = actual._s_r_owner_generation
	actual._s_r_owner_generation = saved_4
	var saved_5: PackedInt64Array = actual._r_owner_revision
	actual._r_owner_revision = actual._s_r_owner_revision
	actual._s_r_owner_revision = saved_5
	var saved_6: PackedInt32Array = actual._r_claim_slot
	actual._r_claim_slot = actual._s_r_claim_slot
	actual._s_r_claim_slot = saved_6


func _swap_columns_3() -> void:
	"""Keep ordinary publication behavior while sharing the static field swap."""
	_commit_columns_3(self)


static func _commit_columns_3(actual: RefCounted) -> void:
	"""One fixed publication group in the declared packed-field order."""
	var saved_0: PackedInt32Array = actual._r_claim_generation
	actual._r_claim_generation = actual._s_r_claim_generation
	actual._s_r_claim_generation = saved_0
	var saved_1: PackedByteArray = actual._o_present
	actual._o_present = actual._s_o_present
	actual._s_o_present = saved_1
	var saved_2: PackedByteArray = actual._o_kind
	actual._o_kind = actual._s_o_kind
	actual._s_o_kind = saved_2
	var saved_3: PackedInt32Array = actual._o_slot
	actual._o_slot = actual._s_o_slot
	actual._s_o_slot = saved_3
	var saved_4: PackedInt32Array = actual._o_generation
	actual._o_generation = actual._s_o_generation
	actual._s_o_generation = saved_4
	var saved_5: PackedInt64Array = actual._o_revision
	actual._o_revision = actual._s_o_revision
	actual._s_o_revision = saved_5
	var saved_6: PackedInt32Array = actual._o_parent_slot
	actual._o_parent_slot = actual._s_o_parent_slot
	actual._s_o_parent_slot = saved_6


func _swap_columns_4() -> void:
	"""Keep ordinary publication behavior while sharing the static field swap."""
	_commit_columns_4(self)


static func _commit_columns_4(actual: RefCounted) -> void:
	"""One fixed publication group in the declared packed-field order."""
	var saved_0: PackedInt32Array = actual._o_parent_generation
	actual._o_parent_generation = actual._s_o_parent_generation
	actual._s_o_parent_generation = saved_0
	var saved_1: PackedInt32Array = actual._o_a
	actual._o_a = actual._s_o_a
	actual._s_o_a = saved_1
	var saved_2: PackedInt32Array = actual._o_b
	actual._o_b = actual._s_o_b
	actual._s_o_b = saved_2
	var saved_3: PackedInt32Array = actual._o_c
	actual._o_c = actual._s_o_c
	actual._s_o_c = saved_3
	var saved_4: PackedInt32Array = actual._o_d
	actual._o_d = actual._s_o_d
	actual._s_o_d = saved_4


static func furniture_admission_cold_bytes(pair_count: int) -> int:
	"""Charge private tuples/entries/row indexes plus16 logical controls before the first batch copy."""
	return 60 * pair_count + 16 if pair_count > 0 and pair_count <= MAX_REGIONS else 0


func stage_furniture_admissions(token: int, candidates: Directory.CreateBatch, room: Vector2i,
		entries: PackedInt32Array, authority: Buildings.SpatialAuthority) -> StringName:
	"""Pin the actual coordinator's admitted paired observation; only pending Furniture facts may be future."""
	var code: StringName = _editable(token)
	if code != &"":
		return code
	if _install_row >= 0 or _room_row >= 0 or _furniture_count > 0:
		return &"SPACE_FURNITURE_ADMISSION_BUSY"
	code = _admit_furniture_packet(candidates, room, entries, authority)
	if code != &"":
		return code
	@warning_ignore("integer_division") var count: int = candidates.count / 2
	if count > _s_source_free_count or not _spend(64 * count + _source_capacity * 16):
		return &"SPACE_FURNITURE_ADMISSION_CAPACITY"
	_pin_furniture_packet(candidates, room, entries, authority)
	code = _furniture_before_refusal()
	if code == &"":
		code = _editable(token)
	if code == &"":
		code = _furniture_sources_absent()
	if code != &"":
		_clear_furniture_admissions()
		return code
	_stage_furniture_sources()
	return &""


func _admit_furniture_packet(candidates: Directory.CreateBatch, room: Vector2i,
		entries: PackedInt32Array, authority: Buildings.SpatialAuthority) -> StringName:
	"""The actual coordinator's pre-pinned canonical packet and exact cold lease precede our60N copy."""
	if candidates == null or candidates.storage_refusal() != &"" or candidates.count < 2 \
			or candidates.count != candidates.capacity() or candidates.count % 2 != 0 \
			or candidates.count > _source_capacity * 2 or entries.size() != candidates.count * 2:
		return &"SPACE_FURNITURE_PACKET"
	var code: StringName = _room_binding_refusal(authority)
	if code == &"":
		code = _furniture_authority_refusal(candidates, room, entries)
	return code


func _furniture_authority_refusal(candidates: Directory.CreateBatch, room: Vector2i,
		entries: PackedInt32Array) -> StringName:
	"""Reentrancy protection surrounds the actual Buildings/RoomOrders attestation, then rechecks allocation."""
	if not _begin_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	var code: StringName = _sources.construction_owner().buildings().spatial_furniture_batch_refusal(room, candidates, entries)
	if _end_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	return _sources.directory().batch_candidate_refusal(candidates) if code == &"" else code


func _pin_furniture_packet(candidates: Directory.CreateBatch, room: Vector2i,
		entries: PackedInt32Array, authority: Buildings.SpatialAuthority) -> void:
	"""Private copies total60N bytes; the original mutable observations remain separate and are compared."""
	@warning_ignore("integer_division") _furniture_count = candidates.count / 2
	_furniture_room = room
	_furniture_input = weakref(candidates)
	_furniture_authority = weakref(authority)
	_furniture_input_entries = entries
	_furniture_pins.resize(candidates.count * 5)
	_furniture_entries = entries.duplicate()
	_furniture_rows.resize(_furniture_count)
	_furniture_rows.fill(-1)
	for index: int in candidates.count:
		_furniture_pins[index * 5] = candidates.slots[index]
		_furniture_pins[index * 5 + 1] = candidates.generations[index]
		_furniture_pins[index * 5 + 2] = candidates.kinds[index]
		_furniture_pins[index * 5 + 3] = candidates.typed_rows[index]
		_furniture_pins[index * 5 + 4] = candidates.persistent_ids[index]


func _furniture_packet_matches(candidates: Directory.CreateBatch, entries: PackedInt32Array) -> bool:
	"""Every tuple, layout entry and actual namespace must equal the privately pinned admission."""
	if candidates == null or candidates.directory_owner() != _sources.directory() \
			or candidates.storage_refusal() != &"" or candidates.count != _furniture_count * 2 \
			or candidates.capacity() != candidates.count or entries.size() != _furniture_count * 4:
		return false
	for index: int in candidates.count:
		if candidates.slots[index] != _furniture_pins[index * 5] \
				or candidates.generations[index] != _furniture_pins[index * 5 + 1] \
				or candidates.kinds[index] != _furniture_pins[index * 5 + 2] \
				or candidates.typed_rows[index] != _furniture_pins[index * 5 + 3] \
				or candidates.persistent_ids[index] != _furniture_pins[index * 5 + 4]:
			return false
	return entries == _furniture_entries


func _furniture_before_refusal() -> StringName:
	"""No edited input, authority expiry or changed Directory cursor can retain prepared permission."""
	var candidates: Directory.CreateBatch = _furniture_input.get_ref() as Directory.CreateBatch \
		if _furniture_input != null else null
	var authority: Buildings.SpatialAuthority = _furniture_authority.get_ref() as Buildings.SpatialAuthority \
		if _furniture_authority != null else null
	if not _furniture_packet_matches(candidates, _furniture_input_entries):
		return &"SPACE_FURNITURE_PACKET"
	var code: StringName = _room_binding_refusal(authority)
	if code == &"":
		code = _furniture_authority_refusal(candidates, _furniture_room, _furniture_input_entries)
	if code == &"" and not _furniture_packet_matches(candidates, _furniture_input_entries):
		return &"SPACE_FURNITURE_PACKET"
	return code


func _furniture_sources_absent() -> StringName:
	"""Scan the existing source bank once; the actual Directory's globally ordered batch supplies lookup keys."""
	for row: int in _source_capacity:
		if _s_o_present[row] == 0:
			continue
		var first: int = 0
		var limit: int = _furniture_count
		while first < limit:
			@warning_ignore("integer_division") var middle: int = (first + limit) / 2
			var slot: int = _furniture_pins[middle * 10]
			if slot == _s_o_slot[row]:
				return &"SPACE_FURNITURE_SOURCE_EXISTS"
			if slot < _s_o_slot[row]:
				first = middle + 1
			else:
				limit = middle
	return &""


func _stage_furniture_sources() -> void:
	"""All finite/identity preflights finished before any inactive source row is allocated."""
	for index: int in _furniture_count:
		var row: int = _heap_pop(_s_source_free_heap, _s_source_free_count)
		_s_source_free_count -= 1
		_furniture_rows[index] = row
		_s_o_present[row] = 1
		_s_o_slot[row] = _furniture_pins[index * 10]
		_s_o_generation[row] = _furniture_pins[index * 10 + 1]
		_s_o_revision[row] = 1
		_furniture_facts_into(index)
		_write_source_facts(row)


func _furniture_facts_into(index: int) -> void:
	"""Only actual pending Furniture facts are derived: real Room, authored type/rotation, no tile, installed0."""
	_facts.clear()
	_facts.kind = Directory.KIND_FURNITURE
	_facts.parent = _furniture_room
	_facts.a = _furniture_entries[index * 4]
	_facts.b = Buildings.NO_LINK
	_facts.c = _furniture_entries[index * 4 + 3]


func _furniture_ordinal(row: int) -> int:
	"""Source rows were taken from a min-heap, so their private index remains sorted without another array."""
	var first: int = 0
	var limit: int = _furniture_count
	while first < limit:
		if _validation_sources >= 0 and not _spend(1):
			return LOOKUP_BUDGET
		@warning_ignore("integer_division") var middle: int = (first + limit) / 2
		var source: int = _furniture_rows[middle] & ~FURNITURE_GEOMETRY_SEEN
		if source == row:
			return middle
		if source < row:
			first = middle + 1
		else:
			limit = middle
	return -1


func _furniture_source_refusal(index: int) -> StringName:
	"""A private future source must still have its exact paired full identity and uninstalled derived facts."""
	var row: int = _furniture_rows[index] & ~FURNITURE_GEOMETRY_SEEN
	if row < 0 or row >= _source_capacity or _s_o_present[row] != 1 \
			or _s_o_slot[row] != _furniture_pins[index * 10] \
			or _s_o_generation[row] != _furniture_pins[index * 10 + 1]:
		return &"SPACE_FURNITURE_SOURCE"
	_furniture_facts_into(index)
	return &"" if _facts_match(row, true) else &"SPACE_FURNITURE_SOURCE"


func _furniture_region_refusal(row: int, owner: int) -> StringName:
	"""Pending admission can only block actual installation space; no services, free void or support is created."""
	var ordinal: int = _furniture_ordinal(owner)
	if ordinal == LOOKUP_BUDGET:
		return &"SPACE_OPERATION_BUDGET"
	if ordinal < 0:
		return &""
	if _s_r_role[row] != Space.OBSTACLE or _s_r_claim_kind[row] != CLAIM_NONE \
			or _s_r_section_slot[row] < 0:
		return &"SPACE_FURNITURE_ADMISSION_REGION"
	_furniture_rows[ordinal] |= FURNITURE_GEOMETRY_SEEN
	return &""


func _furniture_markers_refusal() -> StringName:
	"""Every accepted pending piece needs actual occupied geometry before source identities can publish."""
	if not _spend(_furniture_count):
		return &"SPACE_OPERATION_BUDGET"
	for index: int in _furniture_count:
		if (_furniture_rows[index] & FURNITURE_GEOMETRY_SEEN) == 0:
			return &"SPACE_FURNITURE_ADMISSION_GEOMETRY"
	return &""


func publish_furniture_admissions(token: int, candidates: Directory.CreateBatch, room: Vector2i,
		entries: PackedInt32Array, authority: Buildings.SpatialAuthority) -> StringName:
	"""Publish only exact sealed geometry after the real paired identity/row publication in its Router window."""
	if _reject_room_reentry():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if token == 0 or token != _stage_token or not _sealed or _furniture_count == 0 \
			or _furniture_input == null or _furniture_input.get_ref() != candidates or room != _furniture_room \
			or _furniture_authority == null or _furniture_authority.get_ref() != authority \
			or not _furniture_packet_matches(candidates, entries):
		return &"SPACE_FURNITURE_ADMISSION_TOKEN"
	var code: StringName = _furniture_after_refusal(candidates, authority)
	if code != &"":
		return code
	if not _furniture_packet_matches(candidates, entries) or _s_header[17] != revision() + 1:
		return &"SPACE_FURNITURE_PACKET"
	code = _sources_refusal(true, false)
	if code == &"":
		code = _claims_refusal(true, false)
	if code != &"":
		return code
	_swap_banks()
	_stage_token = 0
	_sealed = false
	_clear_furniture_admissions()
	return &""


func _furniture_after_refusal(candidates: Directory.CreateBatch, authority: Buildings.SpatialAuthority) -> StringName:
	"""A live coincident ref is insufficient; actual full row/PID tuples and exact publishing authority are required."""
	var code: StringName = _room_binding_refusal(authority)
	if code != &"":
		return code
	if not _begin_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	var publishing: bool = authority.is_publishing_furniture_admissions(_furniture_room, candidates)
	if _end_room_callback():
		return &"SPACE_ROOM_ADMISSION_REENTRY"
	if not publishing:
		return &"SPACE_FURNITURE_ADMISSION_PUBLICATION"
	var ids: Directory = _sources.directory()
	for index: int in _furniture_count * 2:
		var ref: Vector2i = Vector2i(_furniture_pins[index * 5], _furniture_pins[index * 5 + 1])
		if not ids.is_valid_of_kind(ref, _furniture_pins[index * 5 + 2]) \
				or ids.get_typed_row(ref) != _furniture_pins[index * 5 + 3] \
				or ids.get_persistent_id(ref) != _furniture_pins[index * 5 + 4]:
			return &"SPACE_FURNITURE_AFTER_IDENTITY"
	return _furniture_after_pairs_refusal()


func _furniture_after_pairs_refusal() -> StringName:
	"""Both typed rows must be the actual paired project and pending Furniture, never bare Directory allocations."""
	for index: int in _furniture_count:
		var project: Vector2i = Vector2i(_furniture_pins[index * 10 + 5], _furniture_pins[index * 10 + 6])
		var code: StringName = _read_source(project)
		if code != &"":
			return code
		if _facts.kind != Directory.KIND_CONSTRUCTION or _facts.parent != Vector2i(_furniture_pins[index * 10],
				_furniture_pins[index * 10 + 1]) or _facts.a != Construction.PURPOSE_SPATIAL_FURNITURE \
				or _facts.b != _furniture_entries[index * 4]:
			return &"SPACE_FURNITURE_AFTER_PROJECT"
	return &""


func _clear_furniture_admissions() -> void:
	"""Discard every charged private copy before the coordinator releases its shared cold lease."""
	_furniture_count = 0
	_furniture_room = NULL_REF
	_furniture_input = null
	_furniture_authority = null
	_furniture_input_entries = PackedInt32Array()
	_furniture_pins = PackedInt32Array()
	_furniture_entries = PackedInt32Array()
	_furniture_rows = PackedInt32Array()
