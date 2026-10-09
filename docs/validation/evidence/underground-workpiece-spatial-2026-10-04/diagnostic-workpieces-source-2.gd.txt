extends RefCounted
## Static paid workpieces, never another material, hauling or labor ledger (decision1134).
## No Placement/ConnectorWork/Contacts preload: Placement owns the one concrete spatial publication tail.

const Directory := preload("res://scripts/core/entity_directory.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Geometry := preload("res://scripts/core/connector_geometry.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const SourceFacts := preload("res://scripts/core/underground_connector_source_facts.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const MAX_PLACEMENTS: int = 256
const MAX_ASSEMBLIES: int = Catalog.MAX_PARTS
const ROW_BYTES: int = 21
const SOURCE_ROW_BYTES: int = 32
const SOURCE_HEADER_BYTES: int = 232
const CONTROL_BYTES: int = 2048
const STREAM_BYTES: int = 512
const NATIVE_RESERVE: int = 8192 # Reservation only; native allocation remains unmeasured.
const DESIGN_CEILING: int = 32768
const WIRE_HEADER_BYTES: int = 212
const REFUSE_BINDING: StringName = &"WORKPIECE_BINDING"
const REFUSE_CAPACITY: StringName = &"WORKPIECE_CAPACITY"
const REFUSE_SOURCE: StringName = &"WORKPIECE_SOURCE"
const REFUSE_FORMAT: StringName = &"WORKPIECE_FORMAT"
const REFUSE_PROFILE: StringName = &"WORKPIECE_SET_DOWN_SOURCE_REQUIRED"
const REFUSE_PROJECT: StringName = &"WORKPIECE_PROJECT"
const REFUSE_STAGE: StringName = &"WORKPIECE_STAGE"
const REFUSE_BUDGET: StringName = &"WORKPIECE_ORIGINAL_LEASE"
const REFUSE_OUTPUT: StringName = &"WORKPIECE_OUTPUT_SHAPE"
const REFUSE_REGION: StringName = &"WORKPIECE_OBSTACLE"
const GENERATION: int = 0
const PROJECT_SLOT: int = 1
const REGION_SLOT: int = 3
const PART: int = 0
const ROTATION: int = 1
const X: int = 2
const PROFILE: int = 5
const H_REVISION: int = 0
const H_CATALOG: int = 1
const H_VARIANT: int = 2
const H_GROUP: int = 3
const H_RECIPE: int = 4
const H_PROFILES: int = 5
const H_COUNT: int = 6
const H_ROW: int = 7
const H_PROGRAM: int = 8

class Bank extends RefCounted:
	## Slot-indexed by the actual Placement; no new reference namespace, free list or paid quantity.
	var fields: PackedInt32Array = PackedInt32Array()
	var present: PackedByteArray = PackedByteArray()

	func allocate(capacity: int) -> void:
		"""Allocate only after both banks, source and fixed simultaneous peak are admitted."""
		fields.resize(5 * capacity)
		present.resize(capacity)
		fields.fill(0)
		present.fill(0)

var _live: Bank = Bank.new()
var _stage: Bank = Bank.new()
var _header: PackedInt64Array = PackedInt64Array()
var _digests: PackedByteArray = PackedByteArray() # own / Catalog / Grouping / Recipe / set-down program.
var _parts: PackedInt32Array = PackedInt32Array() # six field-major source columns.
var _profile_revisions: PackedInt64Array = PackedInt64Array()
var _capacity: int = 0
var _assembly_capacity: int = 0
var _configured: bool = false
var _loaded: bool = false
var _busy: bool = false
var _placements: RefCounted = null
var _router: Router = null
var _paid_owner: WeakRef = null
var _budget: Budget = null
var _catalog: Catalog = null
var _assemblies: Assemblies = null
var _recipes: Recipes = null
var _profiles: Profiles = null
var _stage_placement: Vector2i = NULL_REF
var _stage_project: Vector2i = NULL_REF
var _stage_action: int = -1
var _cold_token: int = 0
var _cold_bytes: int = 0
var _stage_assembly: int = -1
var _stage_payload: int = 0
var _context: RefCounted = null
var _bounds: PackedInt32Array = PackedInt32Array()
var _scratch: PackedInt32Array = PackedInt32Array()


static func required_bytes(placements: int, assemblies: int) -> int:
	"""All declared live, restore, immutable source, stream, control and provisional native bytes coexist."""
	if placements < 1 or placements > MAX_PLACEMENTS or assemblies < 1 or assemblies > MAX_ASSEMBLIES:
		return 0
	return 2 * ROW_BYTES * placements + SOURCE_ROW_BYTES * assemblies + SOURCE_HEADER_BYTES \
		+ CONTROL_BYTES + STREAM_BYTES + NATIVE_RESERVE


func configure(placements: int, assemblies: int, arena_bytes: int) -> StringName:
	"""Reject an unadmitted whole arena before any variable bank allocation; no implicit capacity reduction."""
	var required: int = required_bytes(placements, assemblies)
	if _configured or required == 0 or required > DESIGN_CEILING or arena_bytes != required:
		return REFUSE_CAPACITY
	_capacity = placements
	_assembly_capacity = assemblies
	_live.allocate(placements)
	_stage.allocate(placements)
	_header.resize(9)
	_digests.resize(160)
	_parts.resize(6 * assemblies)
	_profile_revisions.resize(assemblies)
	_bounds.resize(6)
	_scratch.resize(6)
	_clear_source()
	_configured = true
	return &""


func bind_actual(placements: RefCounted, router: Router, paid_owner: RefCounted) -> StringName:
	"""Bind real initialized stores once; reciprocal activation is separately mandatory before preparation."""
	if not _configured or _placements != null or placements == null or router == null or paid_owner == null \
			or not ("_capacity" in placements) or placements._capacity != _capacity \
			or placements._paid_owner == null or placements._paid_owner.get_ref() != paid_owner \
			or router._connector_owner == null or router._connector_owner.get_ref() != paid_owner:
		return REFUSE_BINDING
	_placements = placements
	_router = router
	_paid_owner = weakref(paid_owner)
	_budget = placements._budget
	_catalog = placements._catalog
	_assemblies = placements._assemblies
	_recipes = placements._recipes
	_profiles = placements._profiles
	return _binding_leaf(self)


static func _binding_leaf(a: RefCounted) -> StringName:
	"""Exact real store references precede every source, Project or Region access; equal foreign IDs refuse."""
	if a == null or not a._configured or a._placements == null or a._router == null or a._paid_owner == null \
			or a._paid_owner.get_ref() == null or a._budget == null: return REFUSE_BINDING
	var p: RefCounted = a._placements
	var r: Router = a._router
	if not p._configured or p._capacity != a._capacity or p._budget != a._budget \
			or p._catalog != a._catalog or p._assemblies != a._assemblies or p._recipes != a._recipes \
			or p._profiles != a._profiles or p._construction != r._construction or p._inventory != r._inventory \
			or p._jobs != r._jobs or p._world != r._world or p._ids != r._construction._directory \
			or r._ready_error != &"" or r._connector_owner == null or r._connector_owner.get_ref() != a._paid_owner.get_ref() \
			or p._paid_owner == null or p._paid_owner.get_ref() != a._paid_owner.get_ref() \
			or p._router == null or p._router.get_ref() != r:
		return REFUSE_BINDING
	return &"" if _directory_row(p._ids, p._world, Directory.KIND_WORLD) >= 0 else REFUSE_BINDING


static func _directory_row(ids: Directory, ref: Vector2i, kind: int) -> int:
	"""Validate full generation, kind, typed row and reverse ownership without public observation hooks."""
	if ids == null or ref.x < 0 or ref.x >= Directory.DIRECTORY_CAPACITY or ids._active[ref.x] != 1 \
			or ids._generation[ref.x] != ref.y or ids._kind[ref.x] != kind: return -1
	var row: int = ids._typed_row[ref.x]
	return row if row >= 0 and row < Directory.KIND_CAPACITY[kind] \
		and ids._typed_owner_slot[ids._kind_base[kind] + row] == ref.x else -1


func exact_binding(placements: RefCounted, router: Router) -> bool:
	"""Allocation-free initialization read; it does not grant a source or transaction permission."""
	return placements == _placements and router == _router and _binding_leaf(self) == &""


func _clear_source() -> void:
	"""A failed streamed source load leaves no privately retained partial template."""
	_header.fill(0)
	_digests.fill(0)
	_parts.fill(0)
	_profile_revisions.fill(0)
	_loaded = false


func load_file(path: String, expected_sha256: String, revision: int) -> StringName:
	"""Read one immutable bounded template bank; no active production set-down source is supplied here."""
	if _busy or _loaded or _binding_leaf(self) != &"" or revision < 1 \
			or expected_sha256.length() != 64 or not expected_sha256.is_valid_hex_number(false): return REFUSE_SOURCE
	_busy = true
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_busy = false
		return REFUSE_SOURCE
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var code: StringName = _decode_header(_read(file, digest, WIRE_HEADER_BYTES), revision, file.get_length())
	if code == &"": code = _decode_rows(file, digest)
	var actual: PackedByteArray = digest.finish()
	file.close()
	if code == &"" and actual.hex_encode() != expected_sha256.to_lower(): code = REFUSE_SOURCE
	if code == &"": code = _sources_leaf(self)
	if code == &"":
		for index: int in 32: _digests[index] = actual[index]
		_loaded = true
	else:
		_clear_source()
	_busy = false
	return code


static func _read(file: FileAccess, digest: HashingContext, size: int) -> PackedByteArray:
	"""Hash the exact streamed bytes, with at most the fixed header or one32-byte row alive."""
	var bytes: PackedByteArray = file.get_buffer(size)
	digest.update(bytes)
	return bytes


func _decode_header(bytes: PackedByteArray, revision: int, length: int) -> StringName:
	"""Pin the actual catalog/variant/group/bill/profile/program tuple before decoding rows."""
	if bytes.size() != WIRE_HEADER_BYTES or bytes.slice(0, 8).get_string_from_ascii() != "UGWIPC01" \
			or bytes.decode_u32(8) != 1: return REFUSE_FORMAT
	for index: int in 9: _header[index] = bytes.decode_s64(12 + 8 * index)
	if _header[H_REVISION] != revision or _header[H_COUNT] < 1 or _header[H_COUNT] > _assembly_capacity \
			or length != WIRE_HEADER_BYTES + SOURCE_ROW_BYTES * _header[H_COUNT] + 8: return REFUSE_CAPACITY
	for index: int in 128: _digests[32 + index] = bytes[84 + index]
	return _sources_leaf(self)


func _decode_rows(file: FileAccess, digest: HashingContext) -> StringName:
	"""One exact included part and one independently authored set-down profile belong to each whole bill."""
	for row: int in _header[H_COUNT]:
		var bytes: PackedByteArray = _read(file, digest, SOURCE_ROW_BYTES)
		if bytes.size() != SOURCE_ROW_BYTES: return REFUSE_FORMAT
		for field: int in 6: _parts[field * _assembly_capacity + row] = bytes.decode_s32(4 * field)
		_profile_revisions[row] = bytes.decode_s64(24)
		var code: StringName = _template_leaf(self, row)
		if code != &"": return code
	return &"" if _read(file, digest, 8).get_string_from_ascii() == "UGWEND01" else REFUSE_FORMAT


static func _sources_leaf(a: RefCounted) -> StringName:
	"""Every mutable underlying binding/revision/hash is attested directly after the final ordinary observer."""
	if _binding_leaf(a) != &"" or a._header.size() != 9 or a._digests.size() != 160: return REFUSE_SOURCE
	var g: Assemblies = a._assemblies
	var r: Recipes = a._recipes
	if g == null or r == null or not g._loaded or g._busy or not r._loaded or r._busy \
			or g._catalog != a._catalog or g._recipes != r or g._inventory != a._router._inventory \
			or r._catalog != a._catalog or r._inventory != a._router._inventory or g._items != r._items \
			or r._items != a._router._items or r._items._registered_inventory == null \
			or r._items._registered_inventory.get_ref() != a._router._inventory: return REFUSE_SOURCE
	if g._header[0] != a._header[H_GROUP] or r._header[0] != a._header[H_RECIPE] \
			or g._header[5] != a._header[H_COUNT] or g._header[3] != a._header[H_ROW] \
			or g._header[4] != a._header[H_VARIANT] or r._catalog_row != a._header[H_ROW] \
			or r._variant_revision != a._header[H_VARIANT]: return REFUSE_SOURCE
	for index: int in 32:
		if g._digests[index] != a._digests[64 + index] or r._digests[index] != a._digests[96 + index] \
				or g._digests[32 + index] != a._digests[32 + index] or r._digests[32 + index] != a._digests[32 + index] \
				or r._digests[64 + index] != g._digests[index]: return REFUSE_SOURCE
	if SourceFacts.refusal(a._catalog, a._header[H_ROW], a._header[H_VARIANT], a._header[H_CATALOG], a._digests, 32) != &"":
		return REFUSE_SOURCE
	return _program_leaf(a)


static func _program_leaf(a: RefCounted) -> StringName:
	"""A set-down row is bound to the current immutable program, never merely a matching numeric profile ID."""
	var p: Profiles = a._profiles
	var source: int = a._header[H_PROGRAM]
	if p == null or p._loading or p._live.header[0] != a._header[H_PROFILES] or source < 0 \
			or source >= p._live.header[3] or p != a._catalog._profiles or p._inventory != a._router._inventory \
			or p._work != a._router._work or p._residents != a._placements._residents \
			or p._transforms != a._placements._transforms: return REFUSE_SOURCE
	for index: int in 32:
		if p._live.sources[source * 32 + index] != a._digests[128 + index]: return REFUSE_SOURCE
	return &""


static func _template_leaf(a: RefCounted, assembly: int) -> StringName:
	"""Included-part ownership and positive exact source geometry are required independently of the whole bill."""
	if assembly < 0 or assembly >= a._header[H_COUNT] or a._parts.size() != 6 * a._assembly_capacity \
			or a._profile_revisions.size() != a._assembly_capacity: return REFUSE_SOURCE
	var part: int = a._parts[PART * a._assembly_capacity + assembly]
	var first: int = a._assemblies._first_part[assembly]
	if part < first or part >= first + a._assemblies._part_count[assembly] \
			or a._parts[ROTATION * a._assembly_capacity + assembly] < 0 \
			or a._parts[ROTATION * a._assembly_capacity + assembly] > 3: return REFUSE_SOURCE
	var code: StringName = _part_leaf(a, part)
	return _profile_leaf(a, assembly) if code == &"" else code


static func _part_leaf(a: RefCounted, ordinal: int) -> StringName:
	"""Only a complete positive rectangular top polygon extruded downward is supported by this v1 owner."""
	var c: Catalog = a._catalog
	var at: int = c._live.variants[Catalog.V_PART_START * Catalog.MAX_VARIANTS + a._header[H_ROW]] + ordinal
	if at < 0 or at >= c._live.header[4] or c._live.parts[Catalog.MAX_PARTS + at] <= 0 \
			or (c._live.parts[at] != Geometry.TREAD and c._live.parts[at] != Geometry.POST) \
			or c._live.parts[8 * Catalog.MAX_PARTS + at] != 4: return REFUSE_SOURCE
	var first: int = c._live.parts[7 * Catalog.MAX_PARTS + at]
	if first < 0 or first > c._live.header[5] - 4: return REFUSE_SOURCE
	var low: Vector3i = Vector3i(c._live.vertices[first], c._live.vertices[Catalog.MAX_VERTICES + first], c._live.vertices[2 * Catalog.MAX_VERTICES + first])
	var high: Vector3i = low
	for index: int in range(first, first + 4):
		if c._live.vertices[Catalog.MAX_VERTICES + index] != low.y: return REFUSE_SOURCE
		low.x = mini(low.x, c._live.vertices[index])
		low.z = mini(low.z, c._live.vertices[2 * Catalog.MAX_VERTICES + index])
		high.x = maxi(high.x, c._live.vertices[index])
		high.z = maxi(high.z, c._live.vertices[2 * Catalog.MAX_VERTICES + index])
	if int(low.y) - c._live.parts[Catalog.MAX_PARTS + at] < -2147483648: return REFUSE_SOURCE
	return &"" if Locations._installed_rectangle(c, first, low, high) else REFUSE_SOURCE


static func _profile_leaf(a: RefCounted, assembly: int) -> StringName:
	"""The distinct source-authored set-down BUILD profile must retain complete certified motion and contact roles."""
	var p: Profiles = a._profiles
	var row: int = a._parts[PROFILE * a._assembly_capacity + assembly]
	if row < 0 or row >= p._live.header[1] or p._live.quantities[row] != a._profile_revisions[assembly] \
			or a._profile_revisions[assembly] <= 0 or p._live.flags[row] != Profiles.CERT_REQUIRED: return REFUSE_PROFILE
	var capacity: int = p._profile_capacity
	if p._live.fields[Profiles.F_SOURCE * capacity + row] != a._header[H_PROGRAM] \
			or p._live.fields[Profiles.F_MODE * capacity + row] != Profiles.MODE_WORK \
			or p._live.fields[Profiles.F_WORK_KIND * capacity + row] != Jobs.JOB_KIND_BUILD \
			or p._live.fields[Profiles.F_CONTACT_KIND * capacity + row] != Profiles.CONTACT_ANCHOR_AND_PATCH:
		return REFUSE_PROFILE
	var states: int = Profiles.STATE_WORK | Profiles.STATE_ENTRY | Profiles.STATE_RECOVERY | Profiles.STATE_REVERSAL
	return &"" if (p._live.fields[Profiles.F_STATES * capacity + row] & states) == states else REFUSE_PROFILE


static func _placement_leaf(a: RefCounted, placement: Vector2i) -> StringName:
	"""Use exact actual Placement generation and retained source header, including a real permanent Corridor."""
	var p: RefCounted = a._placements
	if placement.x < 0 or placement.x >= a._capacity or placement.y <= 0 or p._live.present[placement.x] != 1 \
			or p._live.i32[p.GENERATION * p._capacity + placement.x] != placement.y: return REFUSE_PROJECT
	if p._live.header[p.H_CATALOG_REV] != a._header[H_CATALOG] \
			or p._live.header[p.H_VARIANT_REV] != a._header[H_VARIANT] \
			or p._live.header[p.H_GROUP_REV] != a._header[H_GROUP] \
			or p._live.header[p.H_RECIPE_REV] != a._header[H_RECIPE]: return REFUSE_SOURCE
	var room: Vector2i = Vector2i(p._live.i32[p.ROOM_SLOT * p._capacity + placement.x],
		p._live.i32[(p.ROOM_SLOT + 1) * p._capacity + placement.x])
	return &"" if _directory_row(p._ids, room, Directory.KIND_ROOM) >= 0 else REFUSE_PROJECT


static func _project_row(a: RefCounted, placement: Vector2i, project: Vector2i, after_commit: bool = false) -> int:
	"""Full actual Project identity remains live through every bank swap and the final row-clear tail."""
	var p: RefCounted = a._placements
	var c: Construction = a._router._construction
	var row: int = _directory_row(p._ids, project, Directory.KIND_CONSTRUCTION)
	if row < 0 or c._present[row] != 1 or c._ref_slot[row] != project.x or c._ref_generation[row] != project.y \
			or c._purpose[row] != Construction.PURPOSE_CONNECTOR_INSTALL or c._subject_slot[row] != placement.x \
			or c._subject_generation[row] != placement.y: return -1
	var prefix: int = p._live.i32[p.INSTALLED * p._capacity + placement.x]
	if c._type_id[row] != prefix - int(after_commit): return -1
	if not after_commit and (p._live.i32[p.PROJECT_SLOT * p._capacity + placement.x] != project.x \
			or p._live.i32[(p.PROJECT_SLOT + 1) * p._capacity + placement.x] != project.y): return -1
	return row


static func source_leaf_refusal(a: RefCounted, placement: Vector2i, project: Vector2i) -> StringName:
	"""Concrete static final source/identity read; no virtual provider observation follows it."""
	if a == null or not a._loaded: return REFUSE_SOURCE
	var code: StringName = _sources_leaf(a)
	if code == &"": code = _placement_leaf(a, placement)
	if code != &"": return code
	var row: int = _project_row(a, placement, project)
	return _template_leaf(a, a._router._construction._type_id[row]) if row >= 0 else REFUSE_PROJECT


static func candidate_leaf_refusal(a: RefCounted, placement: Vector2i, assembly: int) -> StringName:
	"""Prospective bounds prove only immutable feasibility; they create no Project, target or payment permission."""
	if a == null or not a._loaded: return REFUSE_SOURCE
	var code: StringName = _sources_leaf(a)
	if code == &"": code = _placement_leaf(a, placement)
	if code != &"": return code
	var p: RefCounted = a._placements
	if p._live.i32[p.INSTALLED * p._capacity + placement.x] != assembly: return REFUSE_PROJECT
	return _template_leaf(a, assembly)


static func candidate_bounds_into(a: RefCounted, placement: Vector2i, assembly: int, out: PackedInt32Array) -> StringName:
	"""A fixed caller packet receives the full source part only after source, identity and overflow validation."""
	if a == null or out.size() != 6: return REFUSE_OUTPUT
	var code: StringName = candidate_leaf_refusal(a, placement, assembly)
	if code == &"": code = _bounds_into(a, placement, assembly, a._scratch)
	if code == &"":
		for axis: int in 6: out[axis] = a._scratch[axis]
	return code


func bounds_into(placement: Vector2i, project: Vector2i, out: PackedInt32Array) -> StringName:
	"""Return the complete transformed included part; refused outputs are unchanged and no snapshot is allocated."""
	if _busy or out.size() != 6: return REFUSE_OUTPUT
	var code: StringName = source_leaf_refusal(self, placement, project)
	if code != &"": return code
	var assembly: int = _router._construction._type_id[_project_row(self, placement, project)]
	code = _bounds_into(self, placement, assembly, _scratch)
	if code == &"":
		for axis: int in 6: out[axis] = _scratch[axis]
	return code


static func _bounds_into(a: RefCounted, placement: Vector2i, assembly: int, out: PackedInt32Array) -> StringName:
	"""Compute the exact rectangle under two proper cardinal transforms, keeping arithmetic int64 until narrowing."""
	var c: Catalog = a._catalog
	var part: int = a._parts[PART * a._assembly_capacity + assembly]
	var at: int = c._live.variants[Catalog.V_PART_START * Catalog.MAX_VARIANTS + a._header[H_ROW]] + part
	var first: int = c._live.parts[7 * Catalog.MAX_PARTS + at]
	for axis: int in 3:
		var low: int = 9223372036854775807
		var high: int = -9223372036854775807
		for index: int in range(first, first + 4):
			var x: int = c._live.vertices[index]
			var y: int = c._live.vertices[Catalog.MAX_VERTICES + index]
			var z: int = c._live.vertices[2 * Catalog.MAX_VERTICES + index]
			var top: int = _coordinate(a, placement.x, assembly, x, y, z, axis)
			var bottom: int = _coordinate(a, placement.x, assembly, x, y - c._live.parts[Catalog.MAX_PARTS + at], z, axis)
			low = mini(low, mini(top, bottom))
			high = maxi(high, maxi(top, bottom))
		if low < -2147483648 or high > 2147483647 or low >= high: return REFUSE_SOURCE
		out[axis] = low
		out[axis + 3] = high
	return &""


static func _coordinate(a: RefCounted, row: int, assembly: int, x: int, y: int, z: int, axis: int) -> int:
	"""Source part turn then authored translation then actual Placement turn/origin, applied exactly once."""
	var rotation: int = a._parts[ROTATION * a._assembly_capacity + assembly]
	var sx: int = x if rotation == 0 else -z if rotation == 1 else -x if rotation == 2 else z
	var sz: int = z if rotation == 0 else x if rotation == 1 else -z if rotation == 2 else -x
	sx += a._parts[X * a._assembly_capacity + assembly]
	y += a._parts[(X + 1) * a._assembly_capacity + assembly]
	sz += a._parts[(X + 2) * a._assembly_capacity + assembly]
	var p: RefCounted = a._placements
	rotation = p._live.i32[p.ROTATION * p._capacity + row]
	var value: int = y if axis == 1 else (sx if rotation == 0 else -sz if rotation == 1 else -sx if rotation == 2 else sz) \
		if axis == 0 else (sz if rotation == 0 else sx if rotation == 1 else -sz if rotation == 2 else -sx)
	return value + p._live.i32[(p.X + axis) * p._capacity + row]


func workpiece_region(placement: Vector2i, project: Vector2i) -> Vector2i:
	"""A stale or foreign full identity never borrows a live row's Project-owned obstacle."""
	if source_leaf_refusal(self, placement, project) != &"" or not _row_matches(self, placement, project): return NULL_REF
	var region: Vector2i = _row_region(_live, placement.x, _capacity)
	return region if _region_leaf(self, placement, project, region) == &"" else NULL_REF


static func _row_region(bank: Bank, row: int, capacity: int) -> Vector2i:
	"""Read the sole canonical obstacle pair from a validated present row."""
	return Vector2i(bank.fields[REGION_SLOT * capacity + row], bank.fields[(REGION_SLOT + 1) * capacity + row])


static func _row_matches(a: RefCounted, placement: Vector2i, project: Vector2i) -> bool:
	"""The whole Placement generation and whole Project pair are required; slot equality grants nothing."""
	return placement.x >= 0 and placement.x < a._capacity and a._live.present[placement.x] == 1 \
		and a._live.fields[GENERATION * a._capacity + placement.x] == placement.y \
		and a._live.fields[PROJECT_SLOT * a._capacity + placement.x] == project.x \
		and a._live.fields[(PROJECT_SLOT + 1) * a._capacity + placement.x] == project.y


static func _region_leaf(a: RefCounted, placement: Vector2i, project: Vector2i, region: Vector2i) -> StringName:
	"""Paid WIP is a non-supporting Project obstacle with exactly the immutable complete-part bounds."""
	var s: RefCounted = a._placements._space
	if region.x < 0 or region.x >= s._region_capacity or s._r_present[region.x] != 1 \
			or s._r_generation[region.x] != region.y or s._r_owner_slot[region.x] != project.x \
			or s._r_owner_generation[region.x] != project.y or s._r_role[region.x] != Space.OBSTACLE:
		return REFUSE_REGION
	var p: RefCounted = a._placements
	if s._r_claim_kind[region.x] != s.CLAIM_NONE or s._r_claim_slot[region.x] != -1 \
			or s._r_claim_generation[region.x] != 0 \
			or s._r_section_slot[region.x] != p._live.i32[p.SECTION_SLOT * p._capacity + placement.x] \
			or s._r_section_generation[region.x] != p._live.i32[(p.SECTION_SLOT + 1) * p._capacity + placement.x] \
			or s._r_level[region.x] != p._live.i32[p.LEVEL * p._capacity + placement.x]: return REFUSE_REGION
	var row: int = _project_row(a, placement, project)
	if row < 0 or _bounds_into(a, placement, a._router._construction._type_id[row], a._scratch) != &"": return REFUSE_REGION
	for axis: int in 6:
		if _region_axis(s, region.x, axis) != a._scratch[axis]: return REFUSE_REGION
	return &""


static func _region_axis(space: RefCounted, row: int, axis: int) -> int:
	"""Read all six actual live bounds directly without a Region provider callback."""
	match axis:
		0: return space._r_lo_x[row]
		1: return space._r_lo_y[row]
		2: return space._r_lo_z[row]
		3: return space._r_hi_x[row]
		4: return space._r_hi_y[row]
		_: return space._r_hi_z[row]


func is_quiescent() -> bool:
	"""No synchronous workpiece request or borrowed companion packet may escape a composed save boundary."""
	return not _busy and _stage_action == -1 and _context == null and _cold_token == 0


static func _activation_leaf(a: RefCounted) -> StringName:
	"""Only reciprocal actual owners can activate physical operations; initialization alone grants nothing."""
	if _binding_leaf(a) != &"": return REFUSE_BINDING
	var paid: RefCounted = a._paid_owner.get_ref()
	var p: RefCounted = a._placements
	return &"" if "_workpieces" in paid and paid._workpieces == a and "_workpieces" in p \
		and p._workpieces != null and p._workpieces.get_ref() == a else REFUSE_BINDING


func prepare_start(placement: Vector2i, project: Vector2i, original_cold: int) -> StringName:
	"""Prepare one complete paid obstacle before payment; actual spatial companions own clearance and exits."""
	var code: StringName = _begin_request(placement, project, Contract.START, original_cold)
	if code != &"": return code
	if _live.present[placement.x] != 0: return _failed_request(REFUSE_STAGE)
	var row: int = _project_row(self, placement, project)
	var c: Construction = _router._construction
	if c._phase[row] != Construction.PHASE_READY or c._paused[row] != 0 or c._work_begun[row] != 0 \
			or _funded(self, project, row): return _failed_request(REFUSE_PROJECT)
	code = _placements.prepare_workpiece_start(self, placement, project, _bounds, original_cold)
	return _finish_preparation(code)


func prepare_cancel(placement: Vector2i, project: Vector2i, original_cold: int) -> StringName:
	"""A blocked refund retains the exact paid obstacle; no row is removed before actual settlement."""
	var code: StringName = _begin_request(placement, project, Contract.CANCEL, original_cold)
	if code != &"": return code
	if not _row_matches(self, placement, project): return _failed_request(REFUSE_STAGE)
	var region: Vector2i = _row_region(_live, placement.x, _capacity)
	code = _region_leaf(self, placement, project, region)
	if code == &"": code = _placements.prepare_workpiece_cancel(self, placement, project, region, original_cold)
	return _finish_preparation(code)


func prepare_completion(placement: Vector2i, project: Vector2i, original_cold: int) -> StringName:
	"""Capture the exact live piece before Placement stages its removal and the completed billable assembly."""
	var code: StringName = _begin_request(placement, project, Contract.COMMIT, original_cold)
	if code == &"" and not _row_matches(self, placement, project): code = REFUSE_STAGE
	if code == &"": code = _region_leaf(self, placement, project, _row_region(_live, placement.x, _capacity))
	return code if code == &"" else _failed_request(code)


func bind_prepared_completion(placement: Vector2i, project: Vector2i, original_cold: int) -> StringName:
	"""Borrow the one sealed Placement context after its ordinary complete-group preparation succeeds."""
	if placement != _stage_placement or project != _stage_project or original_cold != _cold_token \
			or _stage_action != Contract.COMMIT: return REFUSE_STAGE
	return _finish_preparation(&"")


func _begin_request(placement: Vector2i, project: Vector2i, action: int, original_cold: int) -> StringName:
	"""Capture the original actual arena/tuple before a private bounds write or any spatial observer."""
	if not is_quiescent() or _activation_leaf(self) != &"": return REFUSE_BINDING
	var code: StringName = source_leaf_refusal(self, placement, project)
	if code != &"": return code
	if original_cold <= 0 or _budget._token != original_cold or _budget._used < 1: return REFUSE_BUDGET
	_stage_placement = placement
	_stage_project = project
	_stage_action = action
	_cold_token = original_cold
	_cold_bytes = _budget._used
	_stage_assembly = _router._construction._type_id[_project_row(self, placement, project)]
	_stage_payload = _placements._live.i64[_placements.PAYLOAD_REVISION * _capacity + placement.x]
	_busy = true
	code = _bounds_into(self, placement, _stage_assembly, _bounds)
	return code if code == &"" else _failed_request(code)


func _finish_preparation(code: StringName) -> StringName:
	"""The original context must be borrowed after seals; no token number by itself is a receipt."""
	if code == &"":
		_context = _placements.workpiece_context(_stage_placement, _stage_project, _cold_token)
		code = prepared_leaf_refusal(self, _stage_placement, _stage_project, _stage_action, _cold_token)
	_busy = false
	return code


func _failed_request(code: StringName) -> StringName:
	"""A failure before spatial preparation owns no companion bank; leave real payment and geometry untouched."""
	_clear_request()
	return code


func _clear_request() -> void:
	"""Drop synchronous controls only; canonical rows and another owner's original lease are never released here."""
	_clear_request_preflighted(self)


static func _clear_request_preflighted(a: RefCounted) -> void:
	"""The paid publication tail clears concrete fields without dispatching a virtual cleanup observer."""
	a._stage_placement = NULL_REF
	a._stage_project = NULL_REF
	a._stage_action = -1
	a._stage_assembly = -1
	a._stage_payload = 0
	a._cold_token = 0
	a._cold_bytes = 0
	a._context = null
	a._busy = false


static func prepared_bounds_leaf_refusal(a: RefCounted, placement: Vector2i, project: Vector2i,
		action: int, original_cold: int, bounds: PackedInt32Array) -> StringName:
	"""Valid before the first companion copy and after observers; no sealed context is required at this boundary."""
	if a == null or _activation_leaf(a) != &"" or a._stage_placement != placement or a._stage_project != project \
			or a._stage_action != action or a._cold_token != original_cold or original_cold <= 0 \
			or a._budget._token != original_cold or a._budget._used < a._cold_bytes or a._cold_bytes < 1:
		return REFUSE_BUDGET
	var code: StringName = source_leaf_refusal(a, placement, project)
	if code != &"": return code
	var p: RefCounted = a._placements
	if p._live.i64[p.PAYLOAD_REVISION * p._capacity + placement.x] != a._stage_payload \
			or p._live.i32[p.INSTALLED * p._capacity + placement.x] != a._stage_assembly \
			or bounds.size() != 6 or a._bounds.size() != 6: return REFUSE_STAGE
	code = _bounds_into(a, placement, a._stage_assembly, a._scratch)
	if code != &"": return code
	for axis: int in 6:
		if bounds[axis] != a._scratch[axis] or a._bounds[axis] != a._scratch[axis]: return REFUSE_SOURCE
	return &""


static func prepared_leaf_refusal(a: RefCounted, placement: Vector2i, project: Vector2i,
		action: int, original_cold: int) -> StringName:
	"""Pin the one exact shared sealed packet after source/current-identity checks; Geometry proves its banks."""
	var code: StringName = prepared_bounds_leaf_refusal(a, placement, project, action, original_cold, a._bounds)
	if code != &"": return code
	var context: RefCounted = a._context
	if context == null or context != a._placements._context or context.issuer == null \
			or context.issuer.get_ref() != a._placements or context.router == null or context.router.get_ref() != a._router \
			or context.paid_owner == null or context.paid_owner.get_ref() != a._paid_owner.get_ref() \
			or context.budget != a._budget or context.placement != placement or context.project != project \
			or context.world != a._placements._world or context.assembly != a._stage_assembly \
			or context.cold_token != original_cold or not ("action" in context) or context.action != action \
			or context.space_token <= 0 or context.location_token <= 0 or context.route_token <= 0:
		return REFUSE_STAGE
	return &""


func discard(placement: Vector2i, project: Vector2i, original_cold: int) -> void:
	"""Discard only this exact request; the caller drops companions first and releases its original arena last."""
	if placement == _stage_placement and project == _stage_project and original_cold == _cold_token:
		_clear_request()


static func _funded(a: RefCounted, project: Vector2i, row: int) -> bool:
	"""Read the actual shared receipt identity without calling an overridable Funding query after payment."""
	var funding: RefCounted = a._router._funding
	return funding != null and funding._construction == a._router._construction \
		and funding._inventory == a._router._inventory and funding._project_slot[row] == project.x \
		and funding._project_generation[row] == project.y


static func _publication_leaf(a: RefCounted, project: Vector2i, action: int) -> StringName:
	"""Only the actual retained Router window and exact after-swap context authorize a canonical row tail."""
	if a == null or _activation_leaf(a) != &"" or a._stage_project != project or a._stage_action != action \
			or a._context == null or a._context != a._placements._context: return REFUSE_STAGE
	var r: Router = a._router
	var context: RefCounted = a._context
	if not r._busy or r._publishing_project != project or r._publishing_action != action \
			or r._publishing_owner != a._paid_owner.get_ref() or context.action != action \
			or context.project != project or context.placement != a._stage_placement \
			or context.budget != a._budget or context.cold_token != a._cold_token or a._cold_token <= 0 \
			or a._budget._token != a._cold_token or a._budget._used < a._cold_bytes:
		return REFUSE_STAGE
	if _sources_leaf(a) != &"" or _placement_leaf(a, a._stage_placement) != &"": return REFUSE_SOURCE
	var space: RefCounted = a._placements._space
	if space._stage_token != 0 or space._header[17] != context.target_revision: return REFUSE_STAGE
	return &""


static func publish_start_preflighted(a: RefCounted, project: Vector2i) -> bool:
	"""Called by the single static spatial kernel after all swaps, before it clears the shared context."""
	var code: StringName = _publication_leaf(a, project, Contract.START)
	if code != &"": return false
	var row: int = _project_row(a, a._stage_placement, project)
	var c: Construction = a._router._construction
	if row < 0 or a._live.present[a._stage_placement.x] != 0 or not _funded(a, project, row) \
			or c._phase[row] != Construction.PHASE_WORKING or c._work_begun[row] != 1: return false
	code = _region_leaf(a, a._stage_placement, project, a._context.obstacle)
	if code != &"": return false
	_write_row(a._live, a._capacity, a._stage_placement, project, a._context.obstacle)
	_clear_request_preflighted(a)
	return true


static func _write_row(bank: Bank, capacity: int, placement: Vector2i, project: Vector2i, region: Vector2i) -> void:
	"""One21-byte full-identity row is the only newly published gameplay state."""
	bank.fields[GENERATION * capacity + placement.x] = placement.y
	bank.fields[PROJECT_SLOT * capacity + placement.x] = project.x
	bank.fields[(PROJECT_SLOT + 1) * capacity + placement.x] = project.y
	bank.fields[REGION_SLOT * capacity + placement.x] = region.x
	bank.fields[(REGION_SLOT + 1) * capacity + placement.x] = region.y
	bank.present[placement.x] = 1


static func clear_preflighted(a: RefCounted, project: Vector2i, action: int) -> bool:
	"""Refund/completion already settled and spatial removal already published; no late observer can run."""
	if action != Contract.COMMIT and action != Contract.CANCEL: return false
	var code: StringName = _publication_leaf(a, project, action)
	if code != &"": return false
	var p: RefCounted = a._placements
	var placement: Vector2i = a._stage_placement
	var c: Construction = a._router._construction
	var row: int = _directory_row(p._ids, project, Directory.KIND_CONSTRUCTION)
	if row < 0 or c._present[row] != 1 or c._ref_slot[row] != project.x or c._ref_generation[row] != project.y \
			or c._purpose[row] != Construction.PURPOSE_CONNECTOR_INSTALL or c._subject_slot[row] != placement.x \
			or c._subject_generation[row] != placement.y or c._type_id[row] != a._stage_assembly \
			or _funded(a, project, row) or not _row_matches(a, placement, project): return false
	if p._live.i32[p.INSTALLED * p._capacity + placement.x] != a._stage_assembly + int(action == Contract.COMMIT) \
			or _removed_leaf(a, project, _row_region(a._live, placement.x, a._capacity)) != &"": return false
	for field: int in 5: a._live.fields[field * a._capacity + placement.x] = 0
	a._live.present[placement.x] = 0
	_clear_request_preflighted(a)
	return true


static func _removed_leaf(a: RefCounted, project: Vector2i, region: Vector2i) -> StringName:
	"""The exact old obstacle and every Project source row must retire before the actual Project does."""
	var s: RefCounted = a._placements._space
	if region.x < 0 or region.x >= s._region_capacity or (s._r_present[region.x] == 1 \
			and s._r_generation[region.x] == region.y): return REFUSE_REGION
	for row: int in s._source_capacity:
		if s._o_present[row] == 1 and s._o_slot[row] == project.x and s._o_generation[row] == project.y: return REFUSE_REGION
	return &""


func capture_into(file: FileAccess) -> StringName:
	"""Stream quiescent canonical identity rows; no full wire image or copied stock account is retained."""
	if file == null or not is_quiescent() or not _loaded or _sources_leaf(self) != &"": return REFUSE_STAGE
	var code: StringName = _bank_leaf(_live)
	if code != &"": return code
	_busy = true
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(60)
	for index: int in 8: bytes[index] = "UGWIPS01".unicode_at(index)
	bytes.encode_u32(8, 1)
	bytes.encode_s32(12, _placements._world.x)
	bytes.encode_s32(16, _placements._world.y)
	bytes.encode_u32(20, _capacity)
	bytes.encode_u32(24, ROW_BYTES)
	for index: int in 32: bytes[28 + index] = _digests[index]
	file.store_buffer(bytes)
	for row: int in _capacity: _write_wire_row(file, row)
	_busy = false
	return &"" if file.get_error() == OK else REFUSE_FORMAT


func _write_wire_row(file: FileAccess, row: int) -> void:
	"""One bounded row temporary is released before the next is constructed."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(ROW_BYTES)
	bytes[0] = _live.present[row]
	for field: int in 5: bytes.encode_s32(1 + 4 * field, _live.fields[field * _capacity + row])
	file.store_buffer(bytes)


func restore_from(file: FileAccess) -> StringName:
	"""Validate a streamed inactive bank against restored actual owners, then swap once; refusal preserves live rows."""
	if file == null or not is_quiescent() or not _loaded or _sources_leaf(self) != &"": return REFUSE_STAGE
	_busy = true
	var code: StringName = _read_capture_header(file)
	if code == &"": code = _read_capture_rows(file)
	if code == &"": code = _bank_leaf(_stage)
	if code == &"": code = _sources_leaf(self)
	if code == &"":
		var previous: Bank = _live
		_live = _stage
		_stage = previous
	_stage.fields.fill(0)
	_stage.present.fill(0)
	_busy = false
	return code


func _read_capture_header(file: FileAccess) -> StringName:
	"""Exact World, capacity, row width, source digest and total length prevent namespace or truncation adoption."""
	var bytes: PackedByteArray = file.get_buffer(60)
	if bytes.size() != 60 or bytes.slice(0, 8).get_string_from_ascii() != "UGWIPS01" \
			or bytes.decode_u32(8) != 1 or bytes.decode_s32(12) != _placements._world.x \
			or bytes.decode_s32(16) != _placements._world.y or bytes.decode_u32(20) != _capacity \
			or bytes.decode_u32(24) != ROW_BYTES or file.get_length() != 60 + ROW_BYTES * _capacity:
		return REFUSE_FORMAT
	for index: int in 32:
		if bytes[28 + index] != _digests[index]: return REFUSE_SOURCE
	return &""


func _read_capture_rows(file: FileAccess) -> StringName:
	"""Decode at most21 bytes at once; absent rows have a unique all-zero encoding."""
	for row: int in _capacity:
		var bytes: PackedByteArray = file.get_buffer(ROW_BYTES)
		if bytes.size() != ROW_BYTES or bytes[0] > 1: return REFUSE_FORMAT
		_stage.present[row] = bytes[0]
		for field: int in 5:
			var value: int = bytes.decode_s32(1 + 4 * field)
			if bytes[0] == 0 and value != 0: return REFUSE_FORMAT
			_stage.fields[field * _capacity + row] = value
	return &""


func _bank_leaf(bank: Bank) -> StringName:
	"""Every restored identity names actual live paid WIP and its exact current non-supporting obstacle."""
	if bank.fields.size() != 5 * _capacity or bank.present.size() != _capacity: return REFUSE_FORMAT
	for row: int in _capacity:
		var parity: StringName = _bank_payment_leaf(bank, row)
		if parity != &"": return parity
		if bank.present[row] == 0: continue
		var placement: Vector2i = Vector2i(row, bank.fields[GENERATION * _capacity + row])
		var project: Vector2i = Vector2i(bank.fields[PROJECT_SLOT * _capacity + row], bank.fields[(PROJECT_SLOT + 1) * _capacity + row])
		var code: StringName = source_leaf_refusal(self, placement, project)
		if code != &"": return code
		var typed: int = _project_row(self, placement, project)
		if typed < 0 or not _funded(self, project, typed): return REFUSE_PROJECT
		code = _region_leaf(self, placement, project, _row_region(bank, row, _capacity))
		if code != &"": return code
	return &""


func _bank_payment_leaf(bank: Bank, row: int) -> StringName:
	"""An omitted capture row cannot orphan actual paid WIP, and an unfunded order cannot invent an obstacle."""
	var p: RefCounted = _placements
	if p._live.present[row] == 0:
		return &"" if bank.present[row] == 0 else REFUSE_PROJECT
	var placement: Vector2i = Vector2i(row, p._live.i32[p.GENERATION * _capacity + row])
	var project: Vector2i = Vector2i(p._live.i32[p.PROJECT_SLOT * _capacity + row],
		p._live.i32[(p.PROJECT_SLOT + 1) * _capacity + row])
	if project == NULL_REF: return &"" if bank.present[row] == 0 else REFUSE_PROJECT
	var typed: int = _project_row(self, placement, project)
	if typed < 0: return REFUSE_PROJECT
	return &"" if (bank.present[row] == 1) == _funded(self, project, typed) else REFUSE_PROJECT
