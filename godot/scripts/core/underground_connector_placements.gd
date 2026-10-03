extends RefCounted
## Actual World-local connector identity and paid assembly prefix. No duplicate cuts, WU or escrow.
## The mandatory construction/frontier authority denies by default. Decision1105 owns this boundary.

const Directory := preload("res://scripts/core/entity_directory.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const FinalFacts := preload("res://scripts/core/underground_final_facts.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const SourceFacts := preload("res://scripts/core/underground_connector_source_facts.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const VERSION: int = 1
const MAX_PLACEMENTS: int = 256
const MAX_OPENINGS: int = 512
const I32_FIELDS: int = 18
const I64_FIELDS: int = 2
const OPENING_FIELDS: int = 8
const BANK_HEADER_BYTES: int = 256
const STREAM_BYTES: int = 4096
const CONTROL_BYTES: int = 2048
const NATIVE_BYTES: int = 8192 # Provisional reserve; actual headers and native peaks still require measurement.
const REFUSE_BINDING: StringName = &"PLACEMENT_BINDING"
const REFUSE_CAPACITY: StringName = &"PLACEMENT_CAPACITY"
const REFUSE_SOURCE: StringName = &"PLACEMENT_SOURCE"
const REFUSE_STALE: StringName = &"PLACEMENT_STALE"
const REFUSE_BUSY: StringName = &"PLACEMENT_BUSY"
const REFUSE_ORDER: StringName = &"PLACEMENT_ORDER"
const REFUSE_AUTHORITY: StringName = &"PLACEMENT_FRONTIER_AUTHORITY_UNBOUND"
const REFUSE_BUDGET: StringName = &"PLACEMENT_BUDGET"
const GENERATION: int = 0
const ROOM_SLOT: int = 1
const CATALOG_ROW: int = 3
const X: int = 4
const ROTATION: int = 7
const LEVEL: int = 8
const INSTALLED: int = 9
const PROJECT_SLOT: int = 10
const SECTION_SLOT: int = 12
const ANCHOR_SLOT: int = 14
const OPENING_HEAD: int = 16
const OPENING_COUNT: int = 17
const PAYLOAD_REVISION: int = 0
const ROOM_REVISION: int = 1
const O_PARENT: int = 0
const O_ORDINAL: int = 2
const O_NEXT: int = 3
const O_ROOM: int = 4
const O_SECTION: int = 6
const H_VERSION: int = 0
const H_PLACEMENTS: int = 1
const H_OPENINGS: int = 2
const H_WORLD_SLOT: int = 3
const H_REVISION: int = 5
const H_COUNT: int = 6
const H_OPEN_COUNT: int = 7
const H_CATALOG_REV: int = 8
const H_VARIANT_REV: int = 9
const H_GROUP_REV: int = 10
const H_RECIPE_REV: int = 11
const H_CATALOG_ROW: int = 12
const H_GROUP_COUNT: int = 13
const H_FRONTIER_REV: int = 14
const H_ACTIVE_ORDERS: int = 15

class OrderRecord extends RefCounted:

	## Caller-owned96 logical bytes; no transform, part list, bill or worker state is duplicated.
	var placement: Vector2i = NULL_REF
	var world: Vector2i = NULL_REF
	var corridor: Vector2i = NULL_REF
	var project: Vector2i = NULL_REF
	var payload_revision: int = 0
	var catalog_row: int = -1
	var variant_revision: int = 0
	var catalog_revision: int = 0
	var grouping_revision: int = 0
	var recipe_revision: int = 0
	var installed_count: int = 0
	var assembly_count: int = 0

class Request extends RefCounted:

	## Cold fixed request. Opening targets are Catalog-ordinal ordered Room/section full pairs.
	var corridor: Vector2i = NULL_REF
	var section: Vector2i = NULL_REF
	var anchor: Vector2i = NULL_REF
	var origin: Vector3i = Vector3i.ZERO
	var rotation: int = 0
	var level: int = 0
	var targets: PackedInt32Array = PackedInt32Array()

class Result extends RefCounted:

	var error: StringName = &""
	var placement: Vector2i = NULL_REF

	func _init(code: StringName, ref: Vector2i = NULL_REF) -> void:
		"""Refusals never expose a future or partially published identity."""
		error = code
		placement = ref

class Publisher extends RefCounted:

	func exact_binding(_placements: RefCounted, _world: Vector2i, _construction: Construction) -> bool:
		"""An observer only; actual Router/Construction leaves still decide every mutation."""
		return false

	func project_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int) -> StringName:
		"""Preflight the exact purpose-specific operation without recursively asking for its bill."""
		return REFUSE_BINDING

	func publication_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int, _action: int) -> StringName:
		"""Observe requested intent BEFORE Funding; this is never called inside paid publication."""
		return REFUSE_BINDING

class Authority extends RefCounted:

	func exact_binding(_placements: RefCounted, _space: Owner, _locations: Locations,
			_routes: Routes, _budget: Budget) -> bool:
		"""The actual physical composition supplies the immutable frontier and all concrete companions."""
		return false

	func admission_refusal(_placement: Vector2i, _request: Request, _cold_token: int) -> StringName:
		"""Prove the permanent Corridor's actual reserved footprint and complete opening targets."""
		return REFUSE_AUTHORITY

	func installation_cold_bytes(_placement: Vector2i, _assembly: int) -> int:
		"""Return a source-counted simultaneous requirement; the base cannot allocate or authorize a frontier."""
		return 0

	func stage_installation(_placement: Vector2i, _project: Vector2i, _assembly: int,
			_space_token: int, _cold_token: int) -> StringName:
		"""Stage the exact installed assembly geometry into the actual caller-owned Space candidate."""
		return REFUSE_AUTHORITY

	func stage_locations(_placement: Vector2i, _project: Vector2i, _assembly: int,
			_location_token: int, _cold_token: int) -> StringName:
		"""Refresh every existing endpoint and add only physically completed supported endpoints."""
		return REFUSE_AUTHORITY

	func stage_routes(_placement: Vector2i, _project: Vector2i, _assembly: int,
			_route_token: int, _cold_token: int) -> StringName:
		"""Refresh the actual graph and compile complete current profile certificates before payment."""
		return REFUSE_AUTHORITY

	func discard_completion(_placement: Vector2i, _project: Vector2i, _cold_token: int) -> void:
		"""The base owns no candidates; concrete authority may discard only its exact prepared tokens."""
		pass

	func completion_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int,
			_cold_token: int) -> StringName:
		"""Finish contact/frontier observations before Funding's callback-free settlement boundary."""
		return REFUSE_AUTHORITY

	func retirement_refusal(_placement: Vector2i, _cold_token: int) -> StringName:
		"""Require actual structural cleanup; installed parts never vanish by retiring their identity."""
		return REFUSE_AUTHORITY

	func restoration_refusal(_cold_token: int) -> StringName:
		"""Validate the complete staged physical-prefix image during coordinated settlement restoration."""
		return REFUSE_AUTHORITY

class Bank extends RefCounted:

	var header: PackedInt64Array = PackedInt64Array()
	var digests: PackedByteArray = PackedByteArray()
	var i32: PackedInt32Array = PackedInt32Array()
	var i64: PackedInt64Array = PackedInt64Array()
	var present: PackedByteArray = PackedByteArray()
	var retired: PackedByteArray = PackedByteArray()
	var openings: PackedInt32Array = PackedInt32Array()
	var opening_revision: PackedInt64Array = PackedInt64Array()
	var free_rows: PackedInt32Array = PackedInt32Array()
	var free_openings: PackedInt32Array = PackedInt32Array()
	var free_count: int = 0
	var opening_free_count: int = 0

	func allocate(placements: int, targets: int) -> void:
		"""Only the admitted actual capacities allocate; no independent maximum is a default."""
		header.resize(16)
		digests.resize(128)
		i32.resize(I32_FIELDS * placements)
		i64.resize(I64_FIELDS * placements)
		present.resize(placements)
		retired.resize(placements)
		openings.resize(OPENING_FIELDS * targets)
		opening_revision.resize(targets)
		free_rows.resize(placements)
		free_openings.resize(targets)
		free_count = placements
		opening_free_count = targets
		for row: int in placements:
			free_rows[row] = row
		for row: int in targets:
			free_openings[row] = row

var _live: Bank = Bank.new()
var _stage: Bank = Bank.new()
var _capacity: int = 0
var _opening_capacity: int = 0
var _marks: PackedByteArray = PackedByteArray()
var _stream: PackedByteArray = PackedByteArray()
var _request: Request = Request.new()
var _configured: bool = false
var _ready: bool = false
var _busy: bool = false
var _poisoned: bool = false
var _world: Vector2i = NULL_REF
var _ids: Directory = null
var _buildings: Buildings = null
var _construction: Construction = null
var _space: Owner = null
var _locations: Locations = null
var _routes: Routes = null
var _world_routes: WorldRoutes = null
var _sources: Owner.CoreSources = null
var _inventory: Inventory = null
var _transforms: Transforms = null
var _residents: Residents = null
var _jobs: Jobs = null
var _work: Work = null
var _profiles: Profiles = null
var _gear: RefCounted = null
var _carry: RefCounted = null
var _reservations: RefCounted = null
var _piles: RefCounted = null
var _budget: Budget = null
var _catalog: Catalog = null
var _assemblies: Assemblies = null
var _recipes: Recipes = null
var _authority: WeakRef = null
var _publisher: WeakRef = null
var _router: WeakRef = null
var _paid_owner: WeakRef = null
var _prepared_placement: Vector2i = NULL_REF
var _prepared_project: Vector2i = NULL_REF
var _prepared_assembly: int = -1
var _cold_token: int = 0
var _cold_bytes: int = 0
var _space_token: int = 0
var _location_token: int = 0
var _route_token: int = 0
var _payload_revision: int = 0
var _base_geometry_revision: int = 0
var _target_geometry_revision: int = 0
var _reading_state: bool = false
var _last_state_hash: String = ""
var _context: Locations.InstallationContext = Locations.InstallationContext.new()


static func required_bytes(placements: int, openings: int) -> int:
	"""Count both banks/heaps, audit, bounded stream, fixed controls and explicit provisional native reserve."""
	if placements < 1 or placements > MAX_PLACEMENTS or openings < 1 or openings > MAX_OPENINGS:
		return 0
	return 189 * placements + 89 * openings + 14848


func configure(placements: int, openings: int, arena_bytes: int) -> StringName:
	"""Prove complete constructor admission before any packed resize; configured capacities never grow implicitly."""
	if _configured or required_bytes(placements, openings) == 0 or arena_bytes != required_bytes(placements, openings):
		return REFUSE_CAPACITY
	_capacity = placements
	_opening_capacity = openings
	_live.allocate(placements, openings)
	_stage.allocate(placements, openings)
	_marks.resize(placements + openings)
	_request.targets.resize(4 * Catalog.MAX_OPENINGS_PER_VARIANT)
	_clear_bank(_live)
	_clear_bank(_stage)
	_configured = true
	return &""


func _clear_bank(bank: Bank) -> void:
	"""Canonical inactive rows keep only their explicit generation/retirement history."""
	bank.header.fill(0)
	bank.digests.fill(0)
	bank.i32.fill(0)
	bank.i64.fill(0)
	bank.present.fill(0)
	bank.retired.fill(0)
	bank.openings.fill(0)
	bank.opening_revision.fill(0)
	bank.header[H_VERSION] = VERSION
	bank.header[H_PLACEMENTS] = _capacity
	bank.header[H_OPENINGS] = _opening_capacity
	for row: int in _capacity:
		_set32(bank, OPENING_HEAD, row, -1)
	for row: int in _opening_capacity:
		_set_opening(bank, O_PARENT, row, -1)
		_set_opening(bank, O_NEXT, row, -1)


func bind_actual(space: Owner, locations: Locations, routes: Routes, budget: Budget,
		catalog: Catalog, assemblies: Assemblies, recipes: Recipes, construction: Construction) -> StringName:
	"""Bind one actual World and immutable variant without accepting copied identity or caller source hashes."""
	if _reentry() or not _configured or _ready or space == null or locations == null or routes == null \
			or budget == null or catalog == null or assemblies == null or recipes == null or construction == null:
		return REFUSE_BINDING
	if not budget.is_quiescent() or space.has_prepared() or locations._token != 0 or routes._token != 0:
		return REFUSE_BUSY
	_set_binding(space, locations, routes, budget, catalog, assemblies, recipes, construction)
	var code: StringName = _initial_source_refusal()
	if code != &"":
		_clear_binding()
		return code
	_pin_source(_live)
	_copy_bank(_live, _stage)
	_ready = true
	return &""


func _set_binding(space: Owner, locations: Locations, routes: Routes, budget: Budget,
		catalog: Catalog, assemblies: Assemblies, recipes: Recipes, construction: Construction) -> void:
	"""Hold concrete owner lifetimes while validating their reciprocal identity."""
	_space = space
	_locations = locations
	_routes = routes
	_world_routes = routes._bindings as WorldRoutes
	_sources = space._sources as Owner.CoreSources
	_inventory = locations._inventory
	_transforms = locations._transforms
	_residents = routes._residents
	_jobs = routes._jobs
	_work = routes._work
	_profiles = routes._profiles
	_gear = _profiles._gear if _profiles != null else null
	_carry = _profiles._carry if _profiles != null else null
	_reservations = _profiles._reservations if _profiles != null else null
	_piles = _profiles._piles if _profiles != null else null
	_budget = budget
	_catalog = catalog
	_assemblies = assemblies
	_recipes = recipes
	_construction = construction
	_ids = construction._directory
	_buildings = construction._buildings
	_world = space._domain._world if space._domain != null else NULL_REF


func _clear_binding() -> void:
	"""A refused first composition leaves the configured empty bank reusable."""
	_space = null
	_locations = null
	_routes = null
	_world_routes = null
	_sources = null
	_inventory = null
	_transforms = null
	_residents = null
	_jobs = null
	_work = null
	_profiles = null
	_gear = null
	_carry = null
	_reservations = null
	_piles = null
	_budget = null
	_catalog = null
	_assemblies = null
	_recipes = null
	_construction = null
	_ids = null
	_buildings = null
	_world = NULL_REF


func _initial_source_refusal() -> StringName:
	"""Static leaf reads validate the real loaded immutable tuple before pinning any source bytes."""
	if not _owners_current() or not _assemblies._loaded or _assemblies._busy or not _recipes._loaded \
			or _recipes._busy or _assemblies._header.size() != 7 or _assemblies._digests.size() != 96:
		return REFUSE_SOURCE
	if _assemblies._catalog != _catalog or _assemblies._recipes != _recipes \
			or _assemblies._inventory != _locations._inventory or _recipes._catalog != _catalog \
			or _recipes._inventory != _locations._inventory or _assemblies._items != _recipes._items:
		return REFUSE_SOURCE
	return _immutable_tuple_refusal()


func _immutable_tuple_refusal() -> StringName:
	"""Compare real headers/digests directly; no virtual source reader is the final authority."""
	if _recipes._header.size() != 4 or _recipes._digests.size() != 96 or _recipes._items == null \
			or not _recipes._items._loaded or _recipes._items._registered_inventory == null \
			or _recipes._items._registered_inventory.get_ref() != _locations._inventory:
		return REFUSE_SOURCE
	if _assemblies._header[5] < 1 or _assemblies._header[5] > _assemblies._capacity \
			or _recipes._header[0] != _assemblies._header[2] or _recipes._header[1] != _assemblies._header[1] \
			or _recipes._header[2] != _assemblies._header[0] or _recipes._header[3] != _assemblies._header[5] \
			or _recipes._catalog_row != _assemblies._header[3] or _recipes._variant_revision != _assemblies._header[4]:
		return REFUSE_SOURCE
	for index: int in 32:
		if _recipes._digests[index] != _assemblies._digests[64 + index] \
				or _recipes._digests[32 + index] != _assemblies._digests[32 + index] \
				or _recipes._digests[64 + index] != _assemblies._digests[index]:
			return REFUSE_SOURCE
	return SourceFacts.refusal(_catalog, _assemblies._header[3], _assemblies._header[4],
		_assemblies._header[1], _assemblies._digests, 32)


func _owners_current() -> bool:
	"""Actual owner identity and complete World generation precede all local-handle reads."""
	if _ids == null or _buildings == null or _world == NULL_REF or _space == null \
			or _locations == null or _routes == null or _budget == null or _construction == null \
			or not _ids.is_valid_of_kind(_world, Directory.KIND_WORLD) or _space._domain == null:
		return false
	var sources: Owner.CoreSources = _space._sources as Owner.CoreSources
	return sources != null and sources == _sources and sources._directory == _ids and sources._buildings == _buildings \
		and sources._construction == _construction and sources._locations == _routes \
		and _construction._directory == _ids and _construction._buildings == _buildings \
		and _buildings._directory == _ids and _space._domain._world == _world \
		and _locations._owner == _space and _locations._sources == sources and _locations._cold == _budget \
		and _locations._ids == _ids and _locations._buildings == _buildings and _locations._world == _world \
		and _routes._owner == _space and _routes._sources == sources and _routes._locations == _locations \
		and _routes._cold == _budget and _routes._world == _world and _routes._ids == _ids \
		and _routes._buildings == _buildings and _routes._transforms == _transforms \
		and _locations._inventory == _inventory and _locations._transforms == _transforms \
		and _routes._residents == _residents and _routes._jobs == _jobs and _routes._work == _work \
		and _routes._profiles == _profiles and _routes._bindings == _world_routes and _world_routes != null \
		and _catalog._profiles == _profiles and _catalog._residents == _residents and _catalog._transforms == _transforms \
		and _profile_owners_current() and _route_catalog_current()


func _route_catalog_current() -> bool:
	"""The billed immutable tuple and installed route certificates must share the same actual content owners."""
	return _world_routes._catalog == _catalog and _world_routes._profiles == _profiles \
		and _world_routes._levels == _catalog._levels and _world_routes._movement == _catalog._movement \
		and _world_routes._residents == _residents and _world_routes._transforms == _transforms \
		and _world_routes._budget == _budget and _world_routes._routes_ref != null \
		and _world_routes._routes_ref.get_ref() == _routes and _world_routes._owner_ref != null \
		and _world_routes._owner_ref.get_ref() == _space and _world_routes._sources_ref != null \
		and _world_routes._sources_ref.get_ref() == _sources and _world_routes._locations_ref != null \
		and _world_routes._locations_ref.get_ref() == _locations \
		and FinalFacts._same_domain(_world_routes._domain, _space._domain) \
		and FinalFacts._same_domain(_routes._domain, _space._domain) \
		and FinalFacts._same_domain(_locations._domain, _space._domain)


func _profile_owners_current() -> bool:
	"""Original complete actual pose/tool/load stores cannot be replaced by same-Directory lookalikes."""
	return _profiles != null and _profiles._residents == _residents and _profiles._transforms == _transforms \
		and _profiles._inventory == _inventory and _profiles._work == _work and _profiles._gear == _gear \
		and _profiles._carry == _carry and _profiles._reservations == _reservations and _profiles._piles == _piles \
		and _transforms != null and _transforms._directory == _ids and _residents != null and _residents._directory == _ids \
		and _jobs != null and _jobs._directory == _ids and _jobs._residents == _residents \
		and _work != null and _work._directory == _ids and _work._jobs == _jobs and _work._residents == _residents


func _pin_source(bank: Bank) -> void:
	"""Persist only exact current source bytes and full World identity after the callback-free proof."""
	bank.header[H_WORLD_SLOT] = _world.x
	bank.header[H_WORLD_SLOT + 1] = _world.y
	bank.header[H_REVISION] = 1
	bank.header[H_CATALOG_REV] = _assemblies._header[1]
	bank.header[H_VARIANT_REV] = _assemblies._header[4]
	bank.header[H_GROUP_REV] = _assemblies._header[0]
	bank.header[H_RECIPE_REV] = _assemblies._header[2]
	bank.header[H_CATALOG_ROW] = _assemblies._header[3]
	bank.header[H_GROUP_COUNT] = _assemblies._header[5]
	for index: int in 32:
		bank.digests[index] = _assemblies._digests[32 + index]
		bank.digests[32 + index] = _assemblies._digests[index]
		bank.digests[64 + index] = _assemblies._digests[64 + index]


func _source_refusal() -> StringName:
	"""Bound source replacement never normalizes or silently upgrades an existing Placement."""
	if not _ready or _initial_source_refusal() != &"":
		return REFUSE_SOURCE
	if _live.header[H_CATALOG_REV] != _assemblies._header[1] \
			or _live.header[H_VARIANT_REV] != _assemblies._header[4] \
			or _live.header[H_GROUP_REV] != _assemblies._header[0] \
			or _live.header[H_RECIPE_REV] != _assemblies._header[2] \
			or _live.header[H_CATALOG_ROW] != _assemblies._header[3] \
			or _live.header[H_GROUP_COUNT] != _assemblies._header[5]:
		return REFUSE_SOURCE
	for index: int in 32:
		if _live.digests[index] != _assemblies._digests[32 + index] \
				or _live.digests[32 + index] != _assemblies._digests[index] \
				or _live.digests[64 + index] != _assemblies._digests[64 + index]:
			return REFUSE_SOURCE
	return &""


func _reentry() -> bool:
	"""Preserve the first callback fault; an independent operation may retry only after cleanup."""
	if _busy:
		_poisoned = true
		return true
	return false


func _get32(bank: Bank, field: int, row: int) -> int:
	"""Field-major packed access never allocates per-placement objects."""
	return bank.i32[field * _capacity + row]


func _set32(bank: Bank, field: int, row: int, value: int) -> void:
	"""Store only values checked before authoritative narrowing."""
	bank.i32[field * _capacity + row] = value


func _pair(bank: Bank, field: int, row: int) -> Vector2i:
	"""Each adjacent pair stays in its declared owner namespace."""
	return Vector2i(_get32(bank, field, row), _get32(bank, field + 1, row))


func _set_pair(bank: Bank, field: int, row: int, value: Vector2i) -> void:
	"""Write both validated halves together inside the already-preflighted owner operation."""
	_set32(bank, field, row, value.x)
	_set32(bank, field + 1, row, value.y)


func _get64(bank: Bank, field: int, row: int) -> int:
	"""Revisions remain exact signed64-bit integers."""
	return bank.i64[field * _capacity + row]


func _set64(bank: Bank, field: int, row: int, value: int) -> void:
	"""Refuse overflow before callers advance a revision."""
	bank.i64[field * _capacity + row] = value


func _opening(bank: Bank, field: int, row: int) -> int:
	"""Internal opening links are bounded pool indices, never public handles."""
	return bank.openings[field * _opening_capacity + row]


func _set_opening(bank: Bank, field: int, row: int, value: int) -> void:
	"""Store an already-validated internal opening fact."""
	bank.openings[field * _opening_capacity + row] = value


func _copy_bank(from: Bank, to: Bank) -> void:
	"""Copy into preallocated inactive storage; do not duplicate arrays or allocate a third image."""
	for index: int in 16:
		to.header[index] = from.header[index]
	for index: int in 128:
		to.digests[index] = from.digests[index]
	for index: int in I32_FIELDS * _capacity:
		to.i32[index] = from.i32[index]
	for index: int in I64_FIELDS * _capacity:
		to.i64[index] = from.i64[index]
	for row: int in _capacity:
		to.present[row] = from.present[row]
		to.retired[row] = from.retired[row]
		to.free_rows[row] = from.free_rows[row]
	for index: int in OPENING_FIELDS * _opening_capacity:
		to.openings[index] = from.openings[index]
	for row: int in _opening_capacity:
		to.opening_revision[row] = from.opening_revision[row]
		to.free_openings[row] = from.free_openings[row]
	to.free_count = from.free_count
	to.opening_free_count = from.opening_free_count


func _is_live(bank: Bank, ref: Vector2i) -> bool:
	"""Local generation, presence and bounds are mandatory even when the Directory has coincident slots."""
	return ref.x >= 0 and ref.x < _capacity and ref.y > 0 and bank.present[ref.x] == 1 \
		and _get32(bank, GENERATION, ref.x) == ref.y


func placement_into(ref: Vector2i, out: OrderRecord) -> StringName:
	"""Copy a complete paid-order view only after actual source and full-handle proof; refusals preserve output."""
	if out == null or _busy or _source_refusal() != &"" or not _is_live(_live, ref):
		return REFUSE_STALE
	if _room_refusal(_live, ref.x) != &"":
		return REFUSE_STALE
	_fill_order(ref, out)
	return &""


func _fill_order(ref: Vector2i, out: OrderRecord) -> void:
	"""The fixed caller packet contains no borrowed packed storage."""
	out.placement = ref
	out.world = _world
	out.corridor = _pair(_live, ROOM_SLOT, ref.x)
	out.project = _pair(_live, PROJECT_SLOT, ref.x)
	out.payload_revision = _get64(_live, PAYLOAD_REVISION, ref.x)
	out.catalog_row = _get32(_live, CATALOG_ROW, ref.x)
	out.variant_revision = _live.header[H_VARIANT_REV]
	out.catalog_revision = _live.header[H_CATALOG_REV]
	out.grouping_revision = _live.header[H_GROUP_REV]
	out.recipe_revision = _live.header[H_RECIPE_REV]
	out.installed_count = _get32(_live, INSTALLED, ref.x)
	out.assembly_count = _live.header[H_GROUP_COUNT]


func _room_refusal(bank: Bank, row: int) -> StringName:
	"""The lasting geometry owner is the actual underground permanent Corridor, never its transient Project."""
	var room: Vector2i = _pair(bank, ROOM_SLOT, row)
	if not _ids.is_valid_of_kind(room, Directory.KIND_ROOM):
		return REFUSE_STALE
	var actual: int = _ids.get_typed_row(room)
	if actual < 0 or actual >= _buildings._r_present.size() or _buildings._r_present[actual] != 1 \
			or _buildings._r_ref_slot[actual] != room.x or _buildings._r_ref_generation[actual] != room.y \
			or _buildings._r_type[actual] != Buildings.ROOM_TYPE_CORRIDOR \
			or _buildings._r_spatial_kind[actual] != Buildings.ROOM_SPACE_UNDERGROUND:
		return REFUSE_STALE
	return &""


func cold_budget_owner() -> Budget:
	"""Identity only; neither this borrowed arena nor a token authorizes a frontier."""
	return _budget if _ready and _owners_current() else null


func world_ref() -> Vector2i:
	"""Return only this actual live World namespace."""
	return _world if _ready and _owners_current() else NULL_REF


func construction_owner() -> Construction:
	"""The paid adapter must use the exact same Construction owner."""
	return _construction if _ready and _owners_current() else null


func packed_memory_bytes() -> int:
	"""Count actual allocated arrays, not provisional native/control reservation or unallocated stream capacity."""
	return 189 * _capacity + 89 * _opening_capacity + 512 \
		+ _request.targets.size() * 4 + _stream.size() if _configured else 0


func assemblies_owner() -> Assemblies:
	"""Identity only; the caller still revalidates immutable source revisions before quoting."""
	return _assemblies if _ready else null


func recipes_owner() -> Recipes:
	"""The paid adapter must quote the exact Recipes bound to this immutable grouping."""
	return _recipes if _ready else null


func publisher_binding_refusal(publisher: Publisher, router: Router, paid_owner: Contract.Owner) -> StringName:
	"""Cold reciprocal observation is followed by actual source/Router identity, never a virtual success flag."""
	if _reentry() or _source_refusal() != &"" or publisher == null or router == null or paid_owner == null:
		return REFUSE_BINDING
	if _publisher != null and (_publisher.get_ref() != publisher or _router.get_ref() != router \
			or _paid_owner.get_ref() != paid_owner):
		return REFUSE_BINDING
	_busy = true
	_poisoned = false
	var accepted: bool = publisher.exact_binding(self, _world, _construction)
	var valid: bool = not _poisoned and accepted and _router_identity(router) and _source_refusal() == &""
	_busy = false
	return &"" if valid else REFUSE_BINDING


func bind_publisher(publisher: Publisher, router: Router, paid_owner: Contract.Owner) -> StringName:
	"""Pure half of an explicitly preflighted binding; no observer may follow the other owner's link write."""
	if _reentry() or publisher == null or paid_owner == null or _source_refusal() != &"" \
			or not _router_identity(router) or (router._connector_owner != null and router._connector_owner.get_ref() != paid_owner):
		return REFUSE_BINDING
	if _publisher != null and (_publisher.get_ref() != publisher or _router.get_ref() != router or _paid_owner.get_ref() != paid_owner):
		return REFUSE_BINDING
	if _publisher == null:
		_configure_context(router, paid_owner)
		if Owner.installation_binding_refusal(_space, _context) != &"" \
				or Locations.installation_binding_leaf_refusal(_locations, _context) != &"" \
				or WorldRoutes.installation_binding_leaf_refusal(_world_routes, _context) != &"":
			return REFUSE_BINDING
		_publisher = weakref(publisher)
		_router = weakref(router)
		_paid_owner = weakref(paid_owner)
		_space._installation_context = weakref(_context)
		_locations._installation = _context
		_world_routes._installation = _context
	return &""


func _configure_context(router: Router, paid_owner: Contract.Owner) -> void:
	"""Only exact once-bound owners enter the shared packet; weak backreferences avoid owner cycles."""
	_context.issuer = weakref(self)
	_context.router = weakref(router)
	_context.paid_owner = weakref(paid_owner)
	_context.space = weakref(_space)
	_context.locations = weakref(_locations)
	_context.construction = _construction
	_context.budget = _budget
	_context.world = _world


func _router_identity(router: Router) -> bool:
	"""Direct actual owner equality closes reciprocal-binding callbacks without calling project_facts."""
	return router != null and router._ready_error == &"" and router._construction == _construction \
		and router._world == _world and router._inventory == _inventory and router._items == _recipes._items \
		and router._jobs == _jobs and router._work == _work and _construction._modular_authority != null \
		and _construction._modular_authority.get_ref() == router


func _publisher_leaf() -> bool:
	"""The actual Router must currently retain this exact purpose8 owner; no Publisher callback is invoked."""
	var router: Router = _router.get_ref() as Router if _router != null else null
	var paid: Contract.Owner = _paid_owner.get_ref() as Contract.Owner if _paid_owner != null else null
	return _publisher != null and _publisher.get_ref() != null and paid != null and _router_identity(router) \
		and router._connector_owner != null and router._connector_owner.get_ref() == paid


func bind_authority(authority: Authority) -> StringName:
	"""Bind one actual progression owner at complete quiescence; replacement requires a new composition."""
	if _reentry() or _authority != null or authority == null or _source_refusal() != &"" \
			or not _quiescent() or not _budget.is_quiescent():
		return REFUSE_BINDING
	_busy = true
	_poisoned = false
	var accepted: bool = authority.exact_binding(self, _space, _locations, _routes, _budget)
	var valid: bool = not _poisoned and accepted and _quiescent() and _budget.is_quiescent() \
		and _source_refusal() == &""
	if valid:
		_authority = weakref(authority)
	_busy = false
	return &"" if valid else REFUSE_BINDING


func _actual_authority() -> Authority:
	"""Hold a strong typed borrow around every callback, without inventing success when the owner expires."""
	return _authority.get_ref() as Authority if _authority != null else null


func _quiescent() -> bool:
	"""Cold registration/streaming cannot overlap physical or endpoint/graph candidates."""
	return _cold_token == 0 and not _reading_state and _space._stage_token == 0 \
		and _locations._token == 0 and _routes._token == 0 and _world_routes._route_token == 0


func register(request: Request, cold_token: int) -> Result:
	"""Create only a real Corridor-owned, uninstalled Placement; no part, route or void is published."""
	if _reentry() or _source_refusal() != &"" or not _quiescent() \
			or not _budget.covers(cold_token, CONTROL_BYTES) or _actual_authority() == null:
		return Result.new(REFUSE_BINDING)
	var code: StringName = _request_refusal(request)
	if code != &"":
		return Result.new(code)
	if _live.free_count == 0 or _live.opening_free_count < _opening_count():
		return Result.new(REFUSE_CAPACITY)
	_busy = true
	_poisoned = false
	_pin_request(request)
	var ref: Vector2i = Vector2i(_live.free_rows[0], _get32(_live, GENERATION, _live.free_rows[0]) + 1)
	var revision: int = _space._header[17]
	var authority: Authority = _actual_authority()
	code = authority.admission_refusal(ref, request, cold_token)
	if code == &"":
		code = _registration_final(request, ref, revision, cold_token)
	if code == &"":
		_copy_bank(_live, _stage)
		_insert_request(ref)
		_swap()
	_busy = false
	return Result.new(code, ref if code == &"" else NULL_REF)


func _registration_final(request: Request, ref: Vector2i, revision: int, cold_token: int) -> StringName:
	"""All observers finish before the original lease, private request, sources and free rows are checked again."""
	if _poisoned or not _request_matches(request) or not _budget.covers(cold_token, CONTROL_BYTES) \
			or not _quiescent() or _space._header[17] != revision or _source_refusal() != &"":
		return REFUSE_STALE
	if _live.free_count == 0 or _live.free_rows[0] != ref.x \
			or _get32(_live, GENERATION, ref.x) + 1 != ref.y or _live.opening_free_count < _opening_count():
		return REFUSE_CAPACITY
	return _request_refusal(_request)


func _opening_count() -> int:
	"""The immutable variant supplies exact target count, never a caller-chosen prefix."""
	return _catalog._live.variants[Catalog.V_OPENING_COUNT * Catalog.MAX_VARIANTS + _live.header[H_CATALOG_ROW]]


func _request_refusal(request: Request) -> StringName:
	"""Exact references and integer content bounds precede every private request copy."""
	if request == null or request.targets.size() != 4 * _opening_count() or _revision_refusal(_live, 1) != &"":
		return REFUSE_CAPACITY
	if request.rotation < 0 or request.rotation > 3 or request.level < 0 \
			or (_catalog._live.variants[Catalog.V_ROTATIONS * Catalog.MAX_VARIANTS + _live.header[H_CATALOG_ROW]] \
			& (1 << request.rotation)) == 0:
		return REFUSE_SOURCE
	for axis: int in 3:
		if request.origin[axis] < _space._domain._bounds[axis] or request.origin[axis] >= _space._domain._bounds[axis + 3]:
			return REFUSE_SOURCE
	if _section_refusal(request.corridor, request.section, request.level, true) != &"" \
			or not _locations._live_ref(_locations._live, request.anchor):
		return REFUSE_STALE
	if _locations._get64(_locations._live, Locations.GEOMETRY_REVISION, request.anchor.x) != _space._header[17] \
			or _locations._ref_at(_locations._live, Locations.ROOM_SLOT, request.anchor.x) != NULL_REF \
			or _locations._get32(_locations._live, Locations.LEVEL, request.anchor.x) != 0:
		return REFUSE_STALE
	for ordinal: int in _opening_count():
		var room: Vector2i = Vector2i(request.targets[4 * ordinal], request.targets[4 * ordinal + 1])
		var section: Vector2i = Vector2i(request.targets[4 * ordinal + 2], request.targets[4 * ordinal + 3])
		if _section_refusal(room, section, -1, false) != &"":
			return REFUSE_STALE
	return &""


func _section_refusal(room: Vector2i, section: Vector2i, level: int, corridor: bool) -> StringName:
	"""Metadata identity never supplies actual support, paid excavation or an installation contact."""
	if not _ids.is_valid_of_kind(room, Directory.KIND_ROOM) or not _space._region_live(section, false):
		return REFUSE_STALE
	var row: int = _ids.get_typed_row(room)
	if row < 0 or row >= _buildings._r_present.size() or _buildings._r_present[row] != 1 \
			or _buildings._r_ref_slot[row] != room.x or _buildings._r_ref_generation[row] != room.y \
			or _buildings._r_spatial_kind[row] != Buildings.ROOM_SPACE_UNDERGROUND \
			or (corridor and _buildings._r_type[row] != Buildings.ROOM_TYPE_CORRIDOR):
		return REFUSE_STALE
	if _space._r_role[section.x] != Space.FLOOR_DATUM or _space._r_owner_slot[section.x] != room.x \
			or _space._r_owner_generation[section.x] != room.y \
			or (level >= 0 and _space._r_level[section.x] != level):
		return REFUSE_STALE
	return &""


func _pin_request(request: Request) -> void:
	"""Copy mutable observations into fixed owned scratch before the first observer."""
	_request.corridor = request.corridor
	_request.section = request.section
	_request.anchor = request.anchor
	_request.origin = request.origin
	_request.rotation = request.rotation
	_request.level = request.level
	_request.targets.resize(request.targets.size())
	for index: int in request.targets.size():
		_request.targets[index] = request.targets[index]


func _request_matches(request: Request) -> bool:
	"""Reject callback edits to either exact caller packet or the pinned private request."""
	return request != null and request.corridor == _request.corridor and request.section == _request.section \
		and request.anchor == _request.anchor and request.origin == _request.origin \
		and request.rotation == _request.rotation and request.level == _request.level and request.targets == _request.targets


func _insert_request(ref: Vector2i) -> void:
	"""The preflighted inactive bank contains the entire request before a single swap publishes it."""
	_pop_free(_stage.free_rows, _stage.free_count)
	_stage.free_count -= 1
	_set32(_stage, GENERATION, ref.x, ref.y)
	_set_pair(_stage, ROOM_SLOT, ref.x, _request.corridor)
	_set32(_stage, CATALOG_ROW, ref.x, _live.header[H_CATALOG_ROW])
	for axis: int in 3:
		_set32(_stage, X + axis, ref.x, _request.origin[axis])
	_set32(_stage, ROTATION, ref.x, _request.rotation)
	_set32(_stage, LEVEL, ref.x, _request.level)
	_set_pair(_stage, PROJECT_SLOT, ref.x, NULL_REF)
	_set_pair(_stage, SECTION_SLOT, ref.x, _request.section)
	_set_pair(_stage, ANCHOR_SLOT, ref.x, _request.anchor)
	_set64(_stage, PAYLOAD_REVISION, ref.x, 1)
	_set64(_stage, ROOM_REVISION, ref.x, _space._r_owner_revision[_request.section.x])
	_set32(_stage, OPENING_COUNT, ref.x, _opening_count())
	_insert_openings(ref)
	_stage.present[ref.x] = 1
	_stage.header[H_COUNT] += 1
	_stage.header[H_REVISION] += 1


func _insert_openings(ref: Vector2i) -> void:
	"""Catalog ordinal order is retained without a duplicate geometry or variable per-placement array."""
	var previous: int = -1
	for ordinal: int in _opening_count():
		var row: int = _pop_free(_stage.free_openings, _stage.opening_free_count)
		_stage.opening_free_count -= 1
		_set_opening(_stage, O_PARENT, row, ref.x)
		_set_opening(_stage, O_PARENT + 1, row, ref.y)
		_set_opening(_stage, O_ORDINAL, row, ordinal)
		for field: int in 4:
			_set_opening(_stage, O_ROOM + field, row, _request.targets[4 * ordinal + field])
		_stage.opening_revision[row] = _space._r_owner_revision[_request.targets[4 * ordinal + 2]]
		if previous < 0:
			_set32(_stage, OPENING_HEAD, ref.x, row)
		else:
			_set_opening(_stage, O_NEXT, previous, row)
		previous = row
		_stage.header[H_OPEN_COUNT] += 1


static func _pop_free(rows: PackedInt32Array, count: int) -> int:
	"""Finite sorted free rows retain deterministic minimum-slot allocation without another index."""
	var row: int = rows[0]
	for index: int in count - 1:
		rows[index] = rows[index + 1]
	rows[count - 1] = -1
	return row


func _swap() -> void:
	"""Publish the complete prevalidated Placement image without callbacks, rebuilding or allocation."""
	var old: Bank = _live
	_live = _stage
	_stage = old


func candidate_order_refusal(ref: Vector2i, assembly: int) -> StringName:
	"""Pure finite admission facts; no Recipe/Grouping observer or per-placement scan runs on this path."""
	if _source_refusal() != &"" or not _publisher_leaf() or not _is_live(_live, ref):
		return REFUSE_BINDING
	if _revision_refusal(_live, 2) != &"" or _get64(_live, PAYLOAD_REVISION, ref.x) == 9223372036854775807:
		return REFUSE_CAPACITY
	if assembly != _get32(_live, INSTALLED, ref.x) or assembly < 0 or assembly >= _live.header[H_GROUP_COUNT] \
			or _pair(_live, PROJECT_SLOT, ref.x) != NULL_REF or _cold_token != 0:
		return REFUSE_ORDER
	return _placement_leaf(_live, ref.x)


func order_refusal(ref: Vector2i, project: Vector2i, assembly: int) -> StringName:
	"""Hot actual project scope uses constant row/hash work and never invokes a physical or recipe observer."""
	if _source_refusal() != &"" or not _publisher_leaf() or not _is_live(_live, ref):
		return REFUSE_BINDING
	if _revision_refusal(_live, 0) != &"" or _live.header[H_ACTIVE_ORDERS] <= 0:
		return REFUSE_CAPACITY
	if _pair(_live, PROJECT_SLOT, ref.x) != project or assembly != _get32(_live, INSTALLED, ref.x) \
			or assembly < 0 or assembly >= _live.header[H_GROUP_COUNT]:
		return REFUSE_ORDER
	var code: StringName = _project_leaf(ref, project, assembly)
	return _placement_leaf(_live, ref.x) if code == &"" else code


func _revision_refusal(bank: Bank, extra: int) -> StringName:
	"""Reserve one terminal increment per actual active Project before any unrelated mutation consumes capacity."""
	if bank.header[H_REVISION] < 1 or bank.header[H_ACTIVE_ORDERS] < 0 \
			or bank.header[H_ACTIVE_ORDERS] > _capacity or extra < 0 \
			or 9223372036854775807 - bank.header[H_REVISION] < bank.header[H_ACTIVE_ORDERS] + extra:
		return REFUSE_CAPACITY
	return &""


func _placement_leaf(bank: Bank, row: int) -> StringName:
	"""Full section identity gives an O(1) current Corridor source pin; geometry changes require cold refresh."""
	var section: Vector2i = _pair(bank, SECTION_SLOT, row)
	var code: StringName = _section_refusal(_pair(bank, ROOM_SLOT, row), section, _get32(bank, LEVEL, row), true)
	if code != &"":
		return code
	if _space._r_owner_revision[section.x] != _get64(bank, ROOM_REVISION, row) \
			or not _locations._live_ref(_locations._live, _pair(bank, ANCHOR_SLOT, row)):
		return REFUSE_STALE
	return &""


func _project_leaf(ref: Vector2i, project: Vector2i, assembly: int) -> StringName:
	"""Only actual Construction can provide purpose8/subject/operation in this World namespace."""
	if not _ids.is_valid_of_kind(project, Directory.KIND_CONSTRUCTION):
		return REFUSE_ORDER
	var row: int = _ids.get_typed_row(project)
	if row < 0 or row >= Construction.CONSTRUCTION_CAPACITY or _construction._present[row] != 1 \
			or _construction._ref_slot[row] != project.x or _construction._ref_generation[row] != project.y \
			or _construction._purpose[row] != Construction.PURPOSE_CONNECTOR_INSTALL \
			or _construction._type_id[row] != assembly or _construction._subject_slot[row] != ref.x \
			or _construction._subject_generation[row] != ref.y:
		return REFUSE_ORDER
	return &""


func _publication_leaf(project: Vector2i, action: int) -> StringName:
	"""Nonvirtual actual Router window is the sole paid publication authority; no observer dispatch occurs."""
	if not _publisher_leaf():
		return REFUSE_BINDING
	var router: Router = _router.get_ref() as Router
	var paid: Contract.Owner = _paid_owner.get_ref() as Contract.Owner
	if not router._busy or router._publishing_project != project or router._publishing_action != action \
			or router._publishing_owner != paid:
		return REFUSE_ORDER
	return &""


func attach_order(ref: Vector2i, project: Vector2i, assembly: int) -> StringName:
	"""Attach once in the actual Router ADMIT window; no quote, worker or receipt state is copied."""
	if _reentry():
		return REFUSE_BUSY
	var code: StringName = candidate_order_refusal(ref, assembly)
	if code == &"":
		code = _project_leaf(ref, project, assembly)
	if code == &"":
		code = _publication_leaf(project, Contract.ADMIT)
	if code != &"" or _live.header[H_REVISION] == 9223372036854775807:
		return code if code != &"" else REFUSE_CAPACITY
	var row: int = _ids.get_typed_row(project)
	if _construction._phase[row] != Construction.PHASE_AWAITING_MATERIALS:
		return REFUSE_ORDER
	_set_pair(_live, PROJECT_SLOT, ref.x, project)
	_live.header[H_REVISION] += 1
	_live.header[H_ACTIVE_ORDERS] += 1
	return &""


func cancellation_refusal(ref: Vector2i, project: Vector2i, assembly: int) -> StringName:
	"""Cancellation never promises demolition, reclaim or retirement of already installed parts."""
	if _cold_token != 0:
		return REFUSE_BUSY
	return order_refusal(ref, project, assembly)


func publish_cancellation(ref: Vector2i, project: Vector2i, assembly: int) -> StringName:
	"""Clear only the actual refunded Project, retaining the installed prefix and every physical companion."""
	if _reentry() or _cold_token != 0:
		return REFUSE_BUSY
	var code: StringName = cancellation_refusal(ref, project, assembly)
	if code == &"":
		code = _publication_leaf(project, Contract.CANCEL)
	if code != &"" or _live.header[H_REVISION] == 9223372036854775807:
		return code if code != &"" else REFUSE_CAPACITY
	if _construction._phase[_ids.get_typed_row(project)] != Construction.PHASE_REFUNDING:
		return REFUSE_ORDER
	_set_pair(_live, PROJECT_SLOT, ref.x, NULL_REF)
	_live.header[H_REVISION] += 1
	_live.header[H_ACTIVE_ORDERS] -= 1
	return &""


func installation_cold_bytes(ref: Vector2i, assembly: int) -> int:
	"""Observe one finite physical requirement before the caller acquires; a base or invalid source returns zero."""
	if _reentry() or _source_refusal() != &"" or not _is_live(_live, ref) or not _quiescent() \
			or assembly != _get32(_live, INSTALLED, ref.x) or assembly >= _live.header[H_GROUP_COUNT]:
		return 0
	var authority: Authority = _actual_authority()
	if authority == null:
		return 0
	_busy = true
	_poisoned = false
	var bytes: int = authority.installation_cold_bytes(ref, assembly)
	var valid: bool = not _poisoned and _quiescent() and _source_refusal() == &"" \
		and bytes == Budget.COLD_BYTES and _placement_leaf(_live, ref.x) == &""
	_busy = false
	return bytes if valid else 0


func prepared_token(ref: Vector2i, project: Vector2i) -> int:
	"""Return only the retained original lease, never the arena's currently active replacement token."""
	return _cold_token if ref == _prepared_placement and project == _prepared_project and _cold_token > 0 \
		and _budget.covers(_cold_token, _cold_bytes) else 0


func prepare_completion(ref: Vector2i, project: Vector2i, original_token: int) -> StringName:
	"""Own all actual companion tokens; no provider may substitute an unrelated prepared transaction."""
	if _reentry() or _cold_token != 0 or not _quiescent():
		return REFUSE_BUSY
	if not _budget.covers(original_token, Budget.COLD_BYTES):
		return REFUSE_BUDGET
	var assembly: int = _get32(_live, INSTALLED, ref.x) if _is_live(_live, ref) else -1
	var code: StringName = order_refusal(ref, project, assembly)
	if code != &"" or not _done_project(project):
		return code if code != &"" else REFUSE_ORDER
	if _live.header[H_REVISION] == 9223372036854775807 or _space._header[17] == 9223372036854775807 \
			or _get64(_live, PAYLOAD_REVISION, ref.x) == 9223372036854775807:
		return REFUSE_CAPACITY
	var authority: Authority = _actual_authority()
	if authority == null:
		return REFUSE_AUTHORITY
	_busy = true
	_poisoned = false
	_pin_completion(ref, project, assembly, original_token)
	code = _prepare_space(authority)
	if code == &"":
		code = _prepare_locations(authority)
	if code == &"":
		code = _prepare_routes(authority)
	if code == &"":
		code = prepared_installation_leaf_refusal(ref, project, assembly, original_token)
	if code != &"":
		_discard_owned_completion(authority)
	_busy = false
	return code


func _done_project(project: Vector2i) -> bool:
	"""Only the actual completed paid work phase can prepare installed support; no worker is fabricated."""
	if not _ids.is_valid_of_kind(project, Directory.KIND_CONSTRUCTION):
		return false
	var row: int = _ids.get_typed_row(project)
	return _construction._phase[row] == Construction.PHASE_WORK_DONE and _construction._remaining_mwu[row] == 0


func _pin_completion(ref: Vector2i, project: Vector2i, assembly: int, original_token: int) -> void:
	"""Keep original numeric identities independent from the mutable shared companion packet."""
	_prepared_placement = ref
	_prepared_project = project
	_prepared_assembly = assembly
	_cold_token = original_token
	_cold_bytes = Budget.COLD_BYTES
	_payload_revision = _get64(_live, PAYLOAD_REVISION, ref.x)
	_base_geometry_revision = _space._header[17]
	_target_geometry_revision = _base_geometry_revision + 1
	_copy_bank(_live, _stage)
	_stage.header[H_REVISION] += 1
	_stage.header[H_ACTIVE_ORDERS] -= 1
	_set32(_stage, INSTALLED, ref.x, assembly + 1)
	_set_pair(_stage, PROJECT_SLOT, ref.x, NULL_REF)
	_set64(_stage, PAYLOAD_REVISION, ref.x, _payload_revision + 1)
	_context.placement = ref
	_context.project = project
	_context.assembly = assembly
	_context.cold_token = original_token
	_context.base_revision = _base_geometry_revision
	_context.target_revision = _target_geometry_revision
	_context.profile_revision = _profiles._live.header[0]
	_context.catalog_revision = _catalog._live.header[0]
	_context.placement_revision = _live.header[H_REVISION]
	_context.payload_revision = _payload_revision


func _prepare_space(authority: Authority) -> StringName:
	"""The actual Placement mints the generic candidate; a frontier may only stage within its original token."""
	var result: Owner.Result = _space.begin_stage(_base_geometry_revision)
	if result.error != &"":
		return result.error
	_space_token = result.token
	_context.space_token = _space_token
	var code: StringName = authority.stage_installation(_prepared_placement, _prepared_project,
		_prepared_assembly, _space_token, _cold_token)
	if code == &"":
		code = _completion_context_refusal()
	if code == &"":
		code = _space.seal(_space_token)
	if code == &"" and (not _space.prepared_has_changes(_space_token) or _space._s_header[17] != _target_geometry_revision):
		code = REFUSE_AUTHORITY
	if code == &"":
		code = _update_staged_source_pins()
	return code


func _prepare_locations(authority: Authority) -> StringName:
	"""Endpoint preparation follows sealed geometry, and all its allocating proof drops before route preparation."""
	var result: Locations.Result = _locations.begin_installation_prepare(_context)
	if result.error != &"":
		return result.error
	_location_token = result.token
	var code: StringName = authority.stage_locations(_prepared_placement, _prepared_project,
		_prepared_assembly, _location_token, _cold_token)
	if code == &"":
		code = _completion_context_refusal()
	if code == &"":
		code = _locations.seal(_location_token)
	return code


func _prepare_routes(authority: Authority) -> StringName:
	"""Actual WorldRoutes owns profile certificates; no topology-only candidate can advance the paid prefix."""
	var result: Routes.Result = _world_routes.begin_prepare(_cold_token, _space_token, _location_token)
	if result.error != &"":
		return result.error
	_route_token = result.token
	_context.route_token = _route_token
	var code: StringName = authority.stage_routes(_prepared_placement, _prepared_project,
		_prepared_assembly, _route_token, _cold_token)
	if code == &"":
		code = _completion_context_refusal()
	if code == &"":
		code = _world_routes.seal(_route_token)
	return code


func _completion_context_refusal() -> StringName:
	"""Pure original pins precede each next allocating companion and follow every external observer."""
	if _poisoned or _cold_token <= 0 or not _budget.covers(_cold_token, _cold_bytes) \
			or not _publisher_leaf() or _source_refusal() != &"" or not _is_live(_live, _prepared_placement):
		return REFUSE_BUDGET if not _poisoned else REFUSE_BUSY
	if _context.placement != _prepared_placement or _context.project != _prepared_project \
			or _context.assembly != _prepared_assembly or _context.cold_token != _cold_token \
			or _context.space_token != _space_token or _context.location_token != _location_token \
			or _context.route_token != _route_token or _context.base_revision != _base_geometry_revision \
			or _context.target_revision != _target_geometry_revision or _context.payload_revision != _payload_revision \
			or _context.placement_revision != _live.header[H_REVISION] \
			or _context.profile_revision != _profiles._live.header[0] or _context.catalog_revision != _catalog._live.header[0]:
		return REFUSE_ORDER
	if _space._stage_token != _space_token or _space._header[17] != _base_geometry_revision \
			or _get64(_live, PAYLOAD_REVISION, _prepared_placement.x) != _payload_revision:
		return REFUSE_STALE
	return order_refusal(_prepared_placement, _prepared_project, _prepared_assembly)


func _update_staged_source_pins() -> StringName:
	"""A shared Corridor/source edit refreshes every retained Placement and opening, not only the active order."""
	if 64 * (_capacity + _opening_capacity) > _space._domain._checks:
		return &"PLACEMENT_SOURCE_CHECK_CAPACITY"
	for row: int in _capacity:
		if _stage.present[row] != 0:
			var code: StringName = _update_row_source_pins(row)
			if code != &"":
				return code
	return &""


func _update_row_source_pins(row: int) -> StringName:
	"""Stage exact changed source revisions only after proving every retained full section still exists."""
	if _placement_leaf(_live, row) != &"":
		return REFUSE_STALE
	var section: Vector2i = _pair(_stage, SECTION_SLOT, row)
	if not _space._region_live(section, true) or _space._s_r_role[section.x] != Space.FLOOR_DATUM \
			or section != _pair(_live, SECTION_SLOT, row) \
			or _space._s_r_level[section.x] != _get32(_live, LEVEL, row) \
			or Vector2i(_space._s_r_owner_slot[section.x], _space._s_r_owner_generation[section.x]) != _pair(_live, ROOM_SLOT, row):
		return REFUSE_STALE
	_set64(_stage, ROOM_REVISION, row, _space._s_r_owner_revision[section.x])
	var opening: int = _get32(_stage, OPENING_HEAD, row)
	for ordinal: int in _get32(_stage, OPENING_COUNT, row):
		var code: StringName = _update_opening_pin(row, ordinal, opening)
		if code != &"":
			return code
		opening = _opening(_stage, O_NEXT, opening)
	return &"" if opening == -1 else REFUSE_STALE


func _update_opening_pin(row: int, ordinal: int, opening: int) -> StringName:
	"""A candidate may advance a current retained source, never normalize an already stale opening."""
	if opening < 0 or opening >= _opening_capacity or _opening(_live, O_ORDINAL, opening) != ordinal \
			or _opening(_live, O_PARENT, opening) != row \
			or _opening(_live, O_PARENT + 1, opening) != _get32(_live, GENERATION, row):
		return REFUSE_STALE
	for field: int in OPENING_FIELDS:
		if _opening(_stage, field, opening) != _opening(_live, field, opening):
			return REFUSE_STALE
	var room: Vector2i = Vector2i(_opening(_live, O_ROOM, opening), _opening(_live, O_ROOM + 1, opening))
	var section: Vector2i = Vector2i(_opening(_live, O_SECTION, opening), _opening(_live, O_SECTION + 1, opening))
	if _section_refusal(room, section, -1, false) != &"" \
			or _live.opening_revision[opening] != _space._r_owner_revision[section.x]:
		return REFUSE_STALE
	if not _space._region_live(section, true) or _space._s_r_role[section.x] != Space.FLOOR_DATUM \
			or _space._s_r_owner_slot[section.x] != room.x or _space._s_r_owner_generation[section.x] != room.y \
			or _space._s_r_level[section.x] != _space._r_level[section.x]:
		return REFUSE_STALE
	_stage.opening_revision[opening] = _space._s_r_owner_revision[section.x]
	return &""


func completion_refusal(ref: Vector2i, project: Vector2i, assembly: int, original_token: int) -> StringName:
	"""Finish every physical/Publisher/source observation BEFORE irreversible Funding settlement."""
	if _reentry() or prepared_token(ref, project) != original_token or assembly != _prepared_assembly:
		return REFUSE_ORDER
	var authority: Authority = _actual_authority()
	var publisher: Publisher = _publisher.get_ref() as Publisher if _publisher != null else null
	if authority == null or publisher == null:
		return REFUSE_AUTHORITY
	_busy = true
	_poisoned = false
	var code: StringName = publisher.publication_refusal(ref, project, assembly, Contract.COMMIT)
	if code == &"":
		code = _completion_context_refusal()
	if code == &"":
		code = authority.completion_refusal(ref, project, assembly, original_token)
	if code == &"":
		code = _completion_context_refusal()
	if code == &"":
		code = _routes.prepared_refusal(_route_token)
	if code == &"":
		code = _locations.prepared_refusal(_location_token)
	if code == &"":
		code = _space.prepared_refusal(_space_token)
	if code == &"":
		code = prepared_installation_leaf_refusal(ref, project, assembly, original_token)
	_busy = false
	return code


func prepared_installation_leaf_refusal(ref: Vector2i, project: Vector2i, assembly: int,
		original_token: int) -> StringName:
	"""Close late recipe/contact observations with actual source and sealed companion state, never a callback."""
	if original_token <= 0 or ref != _prepared_placement or project != _prepared_project \
			or assembly != _prepared_assembly or original_token != _cold_token or not _done_project(project):
		return REFUSE_ORDER
	var code: StringName = _prepared_work_refusal()
	if code == &"":
		code = _completion_context_refusal()
	if code == &"":
		code = Owner.generic_commit_refusal(_space, _space_token, _base_geometry_revision, _target_geometry_revision)
	if code == &"":
		code = _prepared_sources_leaf()
	if code == &"":
		code = Locations.installation_prepared_leaf_refusal(_locations, _context)
	return WorldRoutes.installation_prepared_leaf_refusal(_world_routes, _context) if code == &"" else code


func _prepared_work_refusal() -> StringName:
	"""Precharge the census itself before scans, then actual source leaves and complete companion row checks."""
	var required: int = 1024 + 2 * (_space._source_capacity + _space._region_capacity) \
		+ 28 * _locations._capacity + 56 * _routes._edge_capacity + 3 * _routes._vertex_capacity
	if required > _space._domain._checks:
		return &"PLACEMENT_SOURCE_CHECK_CAPACITY"
	for row: int in _space._source_capacity:
		if _space._s_o_present[row] != 0:
			required += 256 if _space._s_o_kind[row] == Directory.KIND_RESIDENT else 64
	for row: int in _space._region_capacity:
		if _space._s_r_present[row] != 0 and _space._s_r_claim_kind[row] != Owner.CLAIM_NONE:
			required += 64
	if required > _space._domain._checks:
		return &"PLACEMENT_SOURCE_CHECK_CAPACITY"
	return &""


func _prepared_sources_leaf() -> StringName:
	"""The admitted fixed census precedes actual source/claim reads; no future-Facts exception applies."""
	var code: StringName = _prepared_source_rows()
	return _prepared_claims_leaf() if code == &"" else code


func _prepared_source_rows() -> StringName:
	"""Retain ordinary full-generation, kind, format and source-fact checks through static leaf dispatch."""
	for row: int in _space._source_capacity:
		if _space._s_o_present[row] == 0:
			continue
		var ref: Vector2i = Vector2i(_space._s_o_slot[row], _space._s_o_generation[row])
		if _space._s_o_present[row] != 1 or not _ids.is_valid_of_kind(ref, _space._s_o_kind[row]):
			return &"SPACE_SOURCE_STALE"
		var code: StringName = FinalFacts._resident_into(_routes, _locations, ref, _space._facts) \
			if _space._s_o_kind[row] == Directory.KIND_RESIDENT else Owner.CoreSources.read_leaf_into(_sources, ref, _space._facts)
		if code == &"":
			code = FinalFacts._facts_refusal(_sources, ref, _space._facts)
		if code != &"" or not _space._facts_match(row, true):
			return code if code != &"" else &"SPACE_SOURCE_DRIFT"
	return &""


func _prepared_claims_leaf() -> StringName:
	"""Full Room/Project claims remain evidence even when traversal observations omit ownership markers."""
	for row: int in _space._region_capacity:
		if _space._s_r_present[row] == 0:
			continue
		if _space._s_r_present[row] != 1:
			return &"SPACE_REGION_FORMAT"
		var kind: int = _space._s_r_claim_kind[row]
		if kind == Owner.CLAIM_NONE:
			continue
		if kind != Owner.CLAIM_ROOM and kind != Owner.CLAIM_CONSTRUCTION:
			return &"SPACE_RESERVATION_FORMAT"
		var ref: Vector2i = Vector2i(_space._s_r_claim_slot[row], _space._s_r_claim_generation[row])
		var expected: int = Directory.KIND_ROOM if kind == Owner.CLAIM_ROOM else Directory.KIND_CONSTRUCTION
		if not _ids.is_valid_of_kind(ref, expected):
			return &"SPACE_SOURCE_STALE"
		var code: StringName = Owner.CoreSources.read_leaf_into(_sources, ref, _space._facts)
		if code == &"":
			code = FinalFacts._facts_refusal(_sources, ref, _space._facts)
		if code != &"":
			return code
		if kind == Owner.CLAIM_ROOM and ref != Vector2i(_space._s_r_owner_slot[row], _space._s_r_owner_generation[row]):
			return &"SPACE_ROOM_CLAIM_IDENTITY"
	return &""


func publish_completion(ref: Vector2i, project: Vector2i, assembly: int, original_token: int) -> StringName:
	"""The paid tail contains only static commit kernels; Project/prefix remains old until all companions swap."""
	if _reentry():
		return REFUSE_BUSY
	var code: StringName = _publication_leaf(project, Contract.COMMIT)
	if code == &"" and (ref != _prepared_placement or project != _prepared_project \
			or assembly != _prepared_assembly or original_token != _cold_token):
		code = REFUSE_ORDER
	if code == &"":
		code = _completion_context_refusal()
	if code != &"":
		return code
	_busy = true
	var space_ok: bool = Owner.commit_preflighted(_space, _space_token, _base_geometry_revision, _target_geometry_revision)
	assert(space_ok, "Already-checked exact generic Space transaction must publish without observers")
	var locations_ok: bool = Locations.publish_installation(_locations, _context)
	assert(locations_ok, "Already-checked immutable endpoint companion must publish without observers")
	var routes_ok: bool = WorldRoutes.publish_installation(_world_routes, _context)
	assert(routes_ok, "Already-checked route/certificate companion must publish without observers")
	_swap()
	_clear_completion()
	_busy = false
	return &""


func discard_completion(ref: Vector2i, project: Vector2i, original_token: int) -> void:
	"""Discard only original owned candidates; unrelated replacement leases/candidates are left intact."""
	if _reentry() or ref != _prepared_placement or project != _prepared_project or original_token != _cold_token:
		return
	_busy = true
	_discard_owned_completion(_actual_authority())
	_busy = false


func _discard_owned_completion(authority: Authority) -> void:
	"""Provider scratch is discarded before shared original candidates and before the caller releases its arena."""
	if authority != null:
		authority.discard_completion(_prepared_placement, _prepared_project, _cold_token)
	if _route_token > 0 and _world_routes._route_token == _route_token:
		_world_routes.abort(_route_token)
	if _location_token > 0 and _locations._token == _location_token:
		_locations.abort(_location_token)
	if _space_token > 0 and _space._stage_token == _space_token:
		_space.abort(_space_token)
	_clear_completion()


func _clear_completion() -> void:
	"""Keep immutable binding refs, but never retain another operation's token or source scope."""
	_prepared_placement = NULL_REF
	_prepared_project = NULL_REF
	_prepared_assembly = -1
	_cold_token = 0
	_cold_bytes = 0
	_space_token = 0
	_location_token = 0
	_route_token = 0
	_payload_revision = 0
	_base_geometry_revision = 0
	_target_geometry_revision = 0
	_context.placement = NULL_REF
	_context.project = NULL_REF
	_context.assembly = -1
	_context.cold_token = 0
	_context.space_token = 0
	_context.location_token = 0
	_context.route_token = 0
	_context.base_revision = 0
	_context.target_revision = 0
	_context.profile_revision = 0
	_context.catalog_revision = 0
	_context.placement_revision = 0
	_context.payload_revision = 0


func wire_bytes() -> int:
	"""One canonical field image excludes derived heaps and never needs to coexist as a retained packed copy."""
	return BANK_HEADER_BYTES + 90 * _capacity + 40 * _opening_capacity if _configured else 0


func state_hash(cold_token: int) -> String:
	"""Hash canonical fields through a reused eight-byte window; no full state image is allocated."""
	if _reentry() or _source_refusal() != &"" or not _quiescent() or not _budget.covers(cold_token, CONTROL_BYTES + STREAM_BYTES):
		return ""
	_busy = true
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	_stream_bank(_live, null, digest)
	var result: String = digest.finish().hex_encode()
	_busy = false
	return result


func capture_file(path: String, cold_token: int) -> StringName:
	"""Create a canonical streamed save only at actual quiescence; an existing destination is never overwritten."""
	if _reentry() or _source_refusal() != &"" or not _quiescent() or not _budget.covers(cold_token, CONTROL_BYTES + STREAM_BYTES):
		return REFUSE_BUDGET
	if FileAccess.file_exists(path):
		return &"PLACEMENT_CAPTURE_EXISTS"
	var code: StringName = _audit_bank(_live)
	if code != &"":
		return code
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return &"PLACEMENT_CAPTURE_IO"
	_busy = true
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	_stream_bank(_live, file, digest)
	var accepted: bool = file.get_position() == wire_bytes() and file.get_error() == OK
	file.close()
	_last_state_hash = digest.finish().hex_encode() if accepted else ""
	_busy = false
	if not accepted:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return &"" if accepted else &"PLACEMENT_CAPTURE_IO"


func captured_hash() -> String:
	"""Return only the last successful capture digest; this read grants no source or restore permission."""
	return _last_state_hash


func _stream_bank(bank: Bank, file: FileAccess, digest: HashingContext) -> void:
	"""Fixed schema order is identical for capture and hash, with no variable object or JSON encoding."""
	for value: int in bank.header:
		_stream_value(value, 8, file, digest)
	for value: int in bank.digests:
		_stream_value(value, 1, file, digest)
	for value: int in bank.i32:
		_stream_value(value, 4, file, digest)
	for value: int in bank.i64:
		_stream_value(value, 8, file, digest)
	for value: int in bank.present:
		_stream_value(value, 1, file, digest)
	for value: int in bank.retired:
		_stream_value(value, 1, file, digest)
	for value: int in bank.openings:
		_stream_value(value, 4, file, digest)
	for value: int in bank.opening_revision:
		_stream_value(value, 8, file, digest)


func _stream_value(value: int, width: int, file: FileAccess, digest: HashingContext) -> void:
	"""Only one bounded window is live; FileAccess and HashingContext native buffers remain in the native reserve."""
	_stream.resize(width)
	if width == 8:
		_stream.encode_s64(0, value)
	elif width == 4:
		_stream.encode_s32(0, value)
	else:
		_stream[0] = value
	digest.update(_stream)
	if file != null:
		file.store_buffer(_stream)


func restore_file(path: String, expected_hash: String, cold_token: int) -> StringName:
	"""Restore only through actual physical-state authority; failed decoding or observation leaves live rows unchanged."""
	if _reentry() or _source_refusal() != &"" or not _quiescent() or _actual_authority() == null \
			or not _budget.covers(cold_token, CONTROL_BYTES + STREAM_BYTES) or expected_hash.length() != 64:
		return REFUSE_BUDGET
	var authority: Authority = _actual_authority()
	_busy = true
	_poisoned = false
	_reading_state = true
	var revision: int = _space._header[17]
	var code: StringName = _read_file(path, expected_hash)
	if code == &"":
		code = _audit_bank(_stage)
	if code == &"":
		code = authority.restoration_refusal(cold_token)
	if code == &"" and (_poisoned or not _budget.covers(cold_token, CONTROL_BYTES + STREAM_BYTES) \
			or _space._stage_token != 0 or _locations._token != 0 or _routes._token != 0 \
			or _space._header[17] != revision or _source_refusal() != &""):
		code = REFUSE_STALE
	if code == &"":
		code = _audit_bank(_stage)
	if code == &"":
		_rebuild_free(_stage)
		_swap()
	_reading_state = false
	_busy = false
	return code


func _read_file(path: String, expected_hash: String) -> StringName:
	"""Decode one scalar at a time into the existing inactive bank; no raw-file or third-bank copy exists."""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != wire_bytes():
		return &"PLACEMENT_LOAD_SIZE"
	_read_bank(_stage, file)
	var valid: bool = file.get_position() == wire_bytes() and file.get_error() == OK
	file.close()
	if not valid:
		return &"PLACEMENT_LOAD_IO"
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	_stream_bank(_stage, null, digest)
	return &"" if digest.finish().hex_encode() == expected_hash else &"PLACEMENT_LOAD_HASH"


func _read_bank(bank: Bank, file: FileAccess) -> void:
	"""Sizes are fixed by configure; hostile wire values cannot resize any destination column."""
	for index: int in bank.header.size():
		bank.header[index] = file.get_64()
	for index: int in bank.digests.size():
		bank.digests[index] = file.get_8()
	for index: int in bank.i32.size():
		bank.i32[index] = _read_i32(file)
	for index: int in bank.i64.size():
		bank.i64[index] = file.get_64()
	for index: int in bank.present.size():
		bank.present[index] = file.get_8()
	for index: int in bank.retired.size():
		bank.retired[index] = file.get_8()
	for index: int in bank.openings.size():
		bank.openings[index] = _read_i32(file)
	for index: int in bank.opening_revision.size():
		bank.opening_revision[index] = file.get_64()


static func _read_i32(file: FileAccess) -> int:
	"""Decode the signed canonical wire without floating narrowing."""
	var value: int = file.get_32()
	return value - 4294967296 if value >= 2147483648 else value


func audit() -> StringName:
	"""Cold full internal/source audit is unavailable during another operation's scratch use."""
	if _reentry() or _source_refusal() != &"" or not _quiescent():
		return REFUSE_BUSY
	return _audit_bank(_live)


func _audit_bank(bank: Bank) -> StringName:
	"""Bounded row/opening scans reject mismatched source headers, linked cycles and noncanonical inactive fields."""
	if bank.header[H_REVISION] < 1 or bank.digests != _live.digests:
		return &"PLACEMENT_STATE_SOURCE"
	for index: int in 16:
		if index != H_REVISION and index != H_COUNT and index != H_OPEN_COUNT \
				and index != H_ACTIVE_ORDERS and bank.header[index] != _live.header[index]:
			return &"PLACEMENT_STATE_HEADER"
	if _revision_refusal(bank, 0) != &"":
		return &"PLACEMENT_STATE_REVISION"
	_marks.fill(0)
	var count: int = 0
	var openings: int = 0
	var active: int = 0
	for row: int in _capacity:
		var code: StringName = _audit_row(bank, row)
		if code != &"":
			return code
		if bank.present[row] != 0:
			count += 1
			openings += _get32(bank, OPENING_COUNT, row)
			active += 1 if _pair(bank, PROJECT_SLOT, row) != NULL_REF else 0
	for row: int in _opening_capacity:
		if _marks[_capacity + row] == 0 and not _empty_opening(bank, row):
			return &"PLACEMENT_OPENING_ORPHAN"
	return &"" if count == bank.header[H_COUNT] and openings == bank.header[H_OPEN_COUNT] \
		and active == bank.header[H_ACTIVE_ORDERS] else &"PLACEMENT_STATE_COUNT"


func _audit_row(bank: Bank, row: int) -> StringName:
	"""Local generation and actual Room/Project state are validated before following any internal opening link."""
	var generation: int = _get32(bank, GENERATION, row)
	if bank.present[row] > 1 or bank.retired[row] > 1 or generation < 0 \
			or (bank.retired[row] != 0 and (bank.present[row] != 0 or generation != 2147483647)) \
			or (bank.present[row] == 0 and generation == 2147483647 and bank.retired[row] == 0):
		return &"PLACEMENT_STATE_GENERATION"
	if bank.present[row] == 0:
		return _empty_row_refusal(bank, row)
	if generation == 0 or _get64(bank, PAYLOAD_REVISION, row) <= 0 or _get32(bank, CATALOG_ROW, row) != _live.header[H_CATALOG_ROW] \
			or _get32(bank, INSTALLED, row) < 0 or _get32(bank, INSTALLED, row) > _live.header[H_GROUP_COUNT]:
		return &"PLACEMENT_STATE_ROW"
	var code: StringName = _placement_leaf(bank, row)
	if code == &"":
		code = _audit_transform(bank, row)
	var project: Vector2i = _pair(bank, PROJECT_SLOT, row)
	if project != NULL_REF and _get64(bank, PAYLOAD_REVISION, row) == 9223372036854775807:
		return &"PLACEMENT_STATE_REVISION"
	if code == &"" and project != NULL_REF:
		code = _project_leaf(Vector2i(row, generation), project, _get32(bank, INSTALLED, row))
	return _audit_openings(bank, row) if code == &"" else code


func _audit_transform(bank: Bank, row: int) -> StringName:
	"""Decoded placement transforms obey the same immutable finite content and Domain predicates as admission."""
	var rotation: int = _get32(bank, ROTATION, row)
	if rotation < 0 or rotation > 3 or _get32(bank, LEVEL, row) < 0 \
			or (_catalog._live.variants[Catalog.V_ROTATIONS * Catalog.MAX_VARIANTS + _live.header[H_CATALOG_ROW]] & (1 << rotation)) == 0:
		return &"PLACEMENT_STATE_TRANSFORM"
	for axis: int in 3:
		var value: int = _get32(bank, X + axis, row)
		if value < _space._domain._bounds[axis] or value >= _space._domain._bounds[axis + 3]:
			return &"PLACEMENT_STATE_TRANSFORM"
	return &""


func _empty_row_refusal(bank: Bank, row: int) -> StringName:
	"""Inactive data never hides a ghost Project, prefix, geometry source or opening claim."""
	for field: int in I32_FIELDS:
		if field != GENERATION and _get32(bank, field, row) != (-1 if field == OPENING_HEAD else 0):
			return &"PLACEMENT_INACTIVE_DATA"
	return &"" if _get64(bank, PAYLOAD_REVISION, row) == 0 and _get64(bank, ROOM_REVISION, row) == 0 else &"PLACEMENT_INACTIVE_DATA"


func _audit_openings(bank: Bank, row: int) -> StringName:
	"""One exact bounded group contains every immutable ordinal and every target's full source generation."""
	var opening: int = _get32(bank, OPENING_HEAD, row)
	if _get32(bank, OPENING_COUNT, row) != _opening_count():
		return &"PLACEMENT_OPENING_COUNT"
	for ordinal: int in _opening_count():
		if opening < 0 or opening >= _opening_capacity or _marks[_capacity + opening] != 0 \
				or _opening(bank, O_PARENT, opening) != row or _opening(bank, O_PARENT + 1, opening) != _get32(bank, GENERATION, row) \
				or _opening(bank, O_ORDINAL, opening) != ordinal:
			return &"PLACEMENT_OPENING_IDENTITY"
		_marks[_capacity + opening] = 1
		var room: Vector2i = Vector2i(_opening(bank, O_ROOM, opening), _opening(bank, O_ROOM + 1, opening))
		var section: Vector2i = Vector2i(_opening(bank, O_SECTION, opening), _opening(bank, O_SECTION + 1, opening))
		var code: StringName = _section_refusal(room, section, -1, false)
		if code != &"" or bank.opening_revision[opening] != _space._r_owner_revision[section.x]:
			return REFUSE_STALE
		opening = _opening(bank, O_NEXT, opening)
	return &"" if opening == -1 else &"PLACEMENT_OPENING_CYCLE"


func _empty_opening(bank: Bank, row: int) -> bool:
	"""Canonical free opening rows do not retain hidden target/source facts."""
	for field: int in OPENING_FIELDS:
		if _opening(bank, field, row) != (-1 if field == O_PARENT or field == O_NEXT else 0):
			return false
	return bank.opening_revision[row] == 0


func _rebuild_free(bank: Bank) -> void:
	"""Ascending free rows form a deterministic min-heap and require no serialized redundant allocator copy."""
	bank.free_count = 0
	bank.opening_free_count = 0
	for row: int in _capacity:
		if bank.present[row] == 0 and bank.retired[row] == 0:
			bank.free_rows[bank.free_count] = row
			bank.free_count += 1
	for row: int in _opening_capacity:
		if _opening(bank, O_PARENT, row) == -1:
			bank.free_openings[bank.opening_free_count] = row
			bank.opening_free_count += 1


func retire(ref: Vector2i, cold_token: int) -> StringName:
	"""Only actual completed structural cleanup may retire a Placement; paid installed geometry is never inferred gone."""
	if _reentry() or _source_refusal() != &"" or not _quiescent() or not _budget.covers(cold_token, CONTROL_BYTES) \
			or not _is_live(_live, ref) or _pair(_live, PROJECT_SLOT, ref.x) != NULL_REF or _actual_authority() == null:
		return REFUSE_ORDER
	if _revision_refusal(_live, 1) != &"":
		return REFUSE_CAPACITY
	var authority: Authority = _actual_authority()
	var revision: int = _space._header[17]
	_busy = true
	_poisoned = false
	var code: StringName = authority.retirement_refusal(ref, cold_token)
	if code == &"" and (_poisoned or not _budget.covers(cold_token, CONTROL_BYTES) or not _quiescent() \
			or _source_refusal() != &"" or _space._header[17] != revision or not _is_live(_live, ref) \
			or _pair(_live, PROJECT_SLOT, ref.x) != NULL_REF or _revision_refusal(_live, 1) != &""):
		code = REFUSE_STALE
	if code == &"":
		_copy_bank(_live, _stage)
		_retire_row(ref.x)
		_rebuild_free(_stage)
		_swap()
	_busy = false
	return code


func _retire_row(row: int) -> void:
	"""Clear only the already-audited bounded linked group; generation exhaustion permanently retires its slot."""
	var opening: int = _get32(_stage, OPENING_HEAD, row)
	for ordinal: int in _get32(_stage, OPENING_COUNT, row):
		var next: int = _opening(_stage, O_NEXT, opening)
		for field: int in OPENING_FIELDS:
			_set_opening(_stage, field, opening, -1 if field == O_PARENT or field == O_NEXT else 0)
		_stage.opening_revision[opening] = 0
		opening = next
	_stage.header[H_OPEN_COUNT] -= _get32(_stage, OPENING_COUNT, row)
	for field: int in I32_FIELDS:
		if field != GENERATION:
			_set32(_stage, field, row, -1 if field == OPENING_HEAD else 0)
	_set64(_stage, PAYLOAD_REVISION, row, 0)
	_set64(_stage, ROOM_REVISION, row, 0)
	_stage.present[row] = 0
	_stage.retired[row] = 1 if _get32(_stage, GENERATION, row) == 2147483647 else 0
	_stage.header[H_COUNT] -= 1
	_stage.header[H_REVISION] += 1
