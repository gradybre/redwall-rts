extends RefCounted
## One host-lifetime foundation over the actual settlement. No identity, stock, paid entry or route is created.
## ADR1146: private initialization, no external authority binding, 1536B within existing PROFILE_BYTES.

const World := preload("res://scripts/core/world_init.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Carry := preload("res://scripts/core/haul_carry.gd")
const Piles := preload("res://scripts/core/ground_piles.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Catalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
# Complete actual cached consumer set required by the immutable production catalog.
const WorkFace := preload("res://scripts/core/underground_work_face.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const LEVEL_PATH: String = "res://data/underground/initial_level_pack.uglvl"
const LEVEL_SHA: String = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"
const LEVEL_REVISION: int = 1
const PROFILE_SOURCE_COUNT: int = 1
const ACTOR_PATH: String = "res://data/underground/mole-worker/evidence/contact-qualification/install-program-compile-v3/result/mole-worker.ugactor"
const PRESENTATION_BYTES: int = 7141920
const CONTROL_BYTES: int = 1024
const HELPER_BYTES: int = 512
const RESERVED_BYTES: int = CONTROL_BYTES + HELPER_BYTES
const FOUNDATION_PROFILE_BYTES: int = Catalog.PAIRED_BANK_BYTES + Catalog.CONTROL_RESERVE + Levels.RESERVED_BYTES + RESERVED_BYTES
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _world: World = null
var _directory: Directory = null
var _buildings: Buildings = null
var _construction: Construction = null
var _inventory: Inventory = null
var _items: Items = null
var _residents: Residents = null
var _jobs: Jobs = null
var _work: Work = null
var _reservations: Reservations = null
var _transforms: Transforms = null
var _gear: Gear = null
var _carry: Carry = null
var _piles: Piles = null
var _content: Content = null
var _budget: Budget = null
var _routes: Routes = null
var _sources: Owner.CoreSources = null
var _space: Owner = null
var _terrain: Terrain = null
var _levels: Levels = null
var _profiles: Profiles = null
var _domain: Space.Domain = null
var _profile_bank: Profiles.Bank = null
var _world_ref: Vector2i = NULL_REF
var _world_pid: int = 0
var _seed: int = 0
var _ready: bool = false
var _busy: bool = false
var _poisoned: bool = false


func configure(world: World, full_world: Vector2i, buildings: Buildings, construction: Construction,
		inventory: Inventory, items: Items, residents: Residents, jobs: Jobs, work: Work,
		reservations: Reservations, transforms: Transforms, gear: Gear, carry: Carry, piles: Piles,
		actual_content: Content) -> StringName:
	"""Borrow the actual host owners before privately preparing their one source-qualified foundation."""
	if _busy:
		_poisoned = true
		return &"UNDERGROUND_SESSION_REENTRANT"
	if _ready:
		return &"UNDERGROUND_SESSION_ALREADY_BOUND"
	_busy = true
	_poisoned = false
	_borrow(world, full_world, buildings, construction, inventory, items, residents, jobs, work,
		reservations, transforms, gear, carry, piles, actual_content)
	var code: StringName = _input_refusal()
	if code == &"":
		_world_pid = _directory._persistent_id[_world_ref.x]
		_seed = _world._published_seed
		code = _prepare()
	if code == &"":
		code = _initial_authority_refusal()
	return _finish(code)


func _borrow(world: World, full_world: Vector2i, buildings: Buildings, construction: Construction,
		inventory: Inventory, items: Items, residents: Residents, jobs: Jobs, work: Work,
		reservations: Reservations, transforms: Transforms, gear: Gear, carry: Carry, piles: Piles,
		actual_content: Content) -> void:
	"""Keep the original object tuple; equal capacities and coincident EntityRefs cannot substitute owners."""
	_world = world
	_world_ref = full_world
	_directory = world._directory if world != null else null
	_buildings = buildings
	_construction = construction
	_inventory = inventory
	_items = items
	_residents = residents
	_jobs = jobs
	_work = work
	_reservations = reservations
	_transforms = transforms
	_gear = gear
	_carry = carry
	_piles = piles
	_content = actual_content


func _input_refusal() -> StringName:
	"""Reject absent, foreign or active borrowed stores before any foundation bank is allocated."""
	if _world == null or _directory == null or _buildings == null or _construction == null \
			or _inventory == null or _items == null or _residents == null or _jobs == null or _work == null \
			or _reservations == null or _transforms == null or _gear == null or _carry == null \
			or _piles == null or _content == null:
		return &"UNDERGROUND_SESSION_INPUT"
	if FOUNDATION_PROFILE_BYTES > Budget.PROFILE_BYTES:
		return &"UNDERGROUND_SESSION_CAPACITY"
	var code: StringName = _owners_refusal()
	return _initial_authority_refusal() if code == &"" else code


func _owners_refusal(allow_prepared_world: bool = false) -> StringName:
	"""Direct actual owner fields close every earlier observing collaborator method."""
	if _world_identity_refusal(allow_prepared_world) != &"" or _world._directory != _directory or _world._jobs != _jobs \
			or _world._nodes == null or _world._nodes._directory != _directory \
			or _buildings._directory != _directory or _construction._directory != _directory \
			or _construction._buildings != _buildings or _residents._directory != _directory \
			or _jobs._directory != _directory or _jobs._residents != _residents \
			or _transforms._directory != _directory or _work._directory != _directory \
			or _work._jobs != _jobs or _work._residents != _residents or _work._gear != _gear:
		return &"UNDERGROUND_SESSION_OWNER"
	if not _items._loaded or _items._registered_inventory == null \
			or _items._registered_inventory.get_ref() != _inventory \
			or _inventory._tx_open or _inventory._attesting or _reservations._haul_active:
		return &"UNDERGROUND_SESSION_INVENTORY"
	return _equipment_refusal()


func _equipment_refusal() -> StringName:
	"""Preserve the real Gear/Carry/Piles and Inventory authorities without registering another owner."""
	if _gear._inventory != _inventory or _gear._directory_binding != _directory or _gear._residents != _residents \
			or _carry._inventory != _inventory or _carry._reservations != _reservations \
			or _carry._residents != _residents or _carry._piles != _piles \
			or _piles._inventory != _inventory or _piles._buildings != _buildings or _piles._world_ref != _world_ref:
		return &"UNDERGROUND_SESSION_EQUIPMENT"
	if _inventory._equipment_authority == null or _inventory._equipment_authority.get_ref() != _gear \
			or _inventory._ground_pile_authority == null or _inventory._ground_pile_authority.get_ref() != _piles:
		return &"UNDERGROUND_SESSION_EQUIPMENT"
	if _reservations._bound_inventory != null and _reservations._bound_inventory.get_ref() != _inventory:
		return &"UNDERGROUND_SESSION_RESERVATIONS"
	if _reservations._bound_inventory == null and _reservations._active_count != 0:
		return &"UNDERGROUND_SESSION_RESERVATIONS"
	return &""


func _world_identity_refusal(allow_prepared_world: bool = false) -> StringName:
	"""Check the full current World generation, row, reverse owner and persistent identity directly."""
	var slot: int = _world_ref.x
	if slot < 0 or slot >= Directory.DIRECTORY_CAPACITY or _world_ref.y <= 0 \
			or not _world._published or (_world._prepared and not allow_prepared_world) or _directory._active[slot] != 1 \
			or _directory._generation[slot] != _world_ref.y or _directory._kind[slot] != Directory.KIND_WORLD \
			or _directory._typed_row[slot] != 0 or _directory._persistent_id[slot] <= 0 \
			or _directory._typed_owner_slot[_directory._kind_base[Directory.KIND_WORLD]] != slot:
		return &"UNDERGROUND_SESSION_WORLD"
	return &""


func _initial_authority_refusal() -> StringName:
	"""Expired weak authorities are still one-way lifetime bindings and cannot be privately replaced."""
	if _buildings._spatial_authority != null or _construction._modular_authority != null \
			or _construction._excavation_authority != null or _inventory._spatial_authority != null:
		return &"UNDERGROUND_SESSION_AUTHORITY_LIFETIME"
	return &""


func _prepare() -> StringName:
	"""Observe current immutable source before allocating the existing configured foundation banks."""
	_domain = Space.Domain.new()
	var code: StringName = _domain.configure(_world_ref, Terrain.DATUM, Terrain.MIN_QUANTUM,
		Terrain.SIZE_QUANTA, Budget.PHASE_VOLUME_CAPACITY, Budget.REGION_CAPACITY, Space.MAX_CHECKS)
	if code == &"":
		code = _content_refusal()
	if code == &"":
		code = _original_refusal()
	if code == &"":
		code = _prepare_space()
	if code == &"":
		code = _prepare_catalogs()
	if code == &"":
		code = _observe_current()
	return code


func _prepare_space() -> StringName:
	"""Routes is the permanent real ResidentLocations receiver, with no configured graph or actor permission."""
	_budget = Budget.new()
	_routes = Routes.new(_residents, _transforms)
	_sources = Owner.CoreSources.new(_directory, _buildings, _construction, _routes)
	var code: StringName = _original_refusal()
	if code != &"":
		return code
	_space = Owner.new(_sources)
	code = _space.configure(_domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY)
	if code != &"":
		return code
	_domain = _space._domain # Borrow the Owner's copy; do not retain a second Domain image.
	code = _original_refusal()
	if code != &"":
		return code
	_terrain = Terrain.new()
	return _terrain.configure(_world, _world._nodes, _space, _sources, _items, _budget)


func _prepare_catalogs() -> StringName:
	"""Load the real immutable engineering menu and current production geometry, with no fixture source."""
	var code: StringName = _original_refusal()
	if code != &"":
		return code
	_levels = Levels.new()
	code = _levels.load_file(LEVEL_PATH, LEVEL_SHA, LEVEL_REVISION)
	if code == &"":
		code = _levels.bind_domain(_domain, _directory, _domain.descriptor(), Space.VERSION)
	if code == &"":
		code = _original_refusal()
	if code != &"":
		return code
	_profiles = Profiles.new()
	code = _profiles.configure(Catalog.PROFILE_COUNT, Catalog.BOX_COUNT, PROFILE_SOURCE_COUNT,
		Catalog.PAIRED_BANK_BYTES + Catalog.CONTROL_RESERVE)
	if code == &"":
		code = _profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _reservations, _piles)
	if code == &"":
		code = Catalog.load_into(_profiles, _content, _domain)
	if code == &"":
		_profile_bank = _profiles._live
	return code


func _content_refusal() -> StringName:
	"""The existing catalog's cached-script closure and exact actual image remain mandatory."""
	var code: StringName = Catalog.runtime_sources_refusal()
	return Catalog.content_refusal(_content, _domain) if code == &"" else code


func _original_refusal(allow_prepared_world: bool = false) -> StringName:
	"""No callbacks: retain the captured World/PID/seed and actual original collaborator tuple."""
	if _poisoned:
		return &"UNDERGROUND_SESSION_REENTRANT"
	var code: StringName = _owners_refusal(allow_prepared_world)
	if code != &"":
		return code
	if _directory._persistent_id[_world_ref.x] != _world_pid or _world._published_seed != _seed:
		return &"UNDERGROUND_SESSION_WORLD"
	return &""


func _observe_current(allow_prepared_world: bool = false) -> StringName:
	"""All bounded cold observations finish before the original direct field checks."""
	var code: StringName = _content_refusal()
	if code == &"" and not _levels.binding_matches(_domain, _directory, Space.VERSION):
		code = &"UNDERGROUND_SESSION_LEVELS"
	if code == &"":
		code = _terrain.binding_refusal()
	if code == &"":
		code = _original_refusal(allow_prepared_world)
	return _foundation_refusal() if code == &"" else code


func _foundation_refusal() -> StringName:
	"""Actual private/source objects remain exact; source revision equality alone cannot replace a bank."""
	if _space._sources != _sources or _space._domain != _domain or _sources._directory != _directory \
			or _sources._buildings != _buildings or _sources._construction != _construction \
			or _sources._locations != _routes or _routes._ids != _directory \
			or _routes._residents != _residents or _routes._transforms != _transforms:
		return &"UNDERGROUND_SESSION_SOURCE"
	if _terrain._world != _world or _terrain._nodes != _world._nodes or _terrain._items != _items \
			or _terrain._buildings != _buildings or _terrain._space.get_ref() != _space \
			or _terrain._sources.get_ref() != _sources or _terrain._budget != _budget \
			or _terrain._world_ref != _world_ref or _terrain._seed != _seed or not _terrain._ready:
		return &"UNDERGROUND_SESSION_TERRAIN"
	if _levels._directory != _directory or _levels._revision != LEVEL_REVISION:
		return &"UNDERGROUND_SESSION_LEVELS"
	return _profile_refusal()


func _profile_refusal() -> StringName:
	"""Retain exact configured banks, current immutable revision and real dynamic owner wiring."""
	if _profiles._live != _profile_bank or _profiles._loading or _profile_bank == null \
			or _profile_bank.header[0] != Catalog.CONTENT_REVISION \
			or _profiles._profile_capacity != Catalog.PROFILE_COUNT or _profiles._box_capacity != Catalog.BOX_COUNT \
			or _profiles._source_capacity != PROFILE_SOURCE_COUNT or _profiles._residents != _residents \
			or _profiles._transforms != _transforms or _profiles._inventory != _inventory or _profiles._gear != _gear \
			or _profiles._carry != _carry or _profiles._work != _work or _profiles._reservations != _reservations \
			or _profiles._piles != _piles or _content._loading or _content._digest != Catalog.Pins.ACTOR_SHA:
		return &"UNDERGROUND_SESSION_PROFILES"
	return &""


func _finish(code: StringName) -> StringName:
	"""Publish only readiness; failure drops private references without mutating a borrowed owner."""
	if code == &"" and _poisoned:
		code = &"UNDERGROUND_SESSION_REENTRANT"
	if code != &"":
		_drop_foundations()
		_drop_borrowed()
	_ready = code == &""
	_busy = false
	return code


func _drop_foundations() -> void:
	"""Unexposed candidates have no host authority links and can safely die on refused initialization."""
	_profile_bank = null
	_profiles = null
	_levels = null
	_terrain = null
	_space = null
	_sources = null
	_routes = null
	_budget = null
	_domain = null


func _drop_borrowed() -> void:
	"""Release only this failed attempt's strong borrows, never clear any host data or weak authority."""
	_content = null
	_piles = null
	_carry = null
	_gear = null
	_transforms = null
	_reservations = null
	_work = null
	_jobs = null
	_residents = null
	_items = null
	_inventory = null
	_construction = null
	_buildings = null
	_directory = null
	_world = null
	_world_ref = NULL_REF
	_world_pid = 0
	_seed = 0


func current_refusal() -> StringName:
	"""Cold current binding/source observation; success creates no operational authority or permission."""
	return _current_refusal(false)


func _current_refusal(allow_prepared_world: bool) -> StringName:
	"""Only explicit whole-world retirement may observe an unchanged live World with a staged replacement."""
	if _busy:
		_poisoned = true
		return &"UNDERGROUND_SESSION_UNAVAILABLE"
	if not _ready:
		return &"UNDERGROUND_SESSION_UNAVAILABLE"
	_busy = true
	_poisoned = false
	var code: StringName = _observe_current(allow_prepared_world)
	_busy = false
	return &"UNDERGROUND_SESSION_REENTRANT" if _poisoned else code


func reset_refusal(allow_prepared_world: bool = false) -> StringName:
	"""Prove quiescent unbound foundations before the host retires them and clears its actual stores."""
	var code: StringName = _current_refusal(allow_prepared_world)
	if code != &"":
		return code
	if not _budget.is_quiescent() or _space.has_prepared() or _routes._edge_capacity != 0 \
			or _space._region_free_count != Budget.REGION_CAPACITY \
			or _space._source_free_count != Budget.SOURCE_CAPACITY - 1 or _space._header[17] != 1:
		return &"UNDERGROUND_SESSION_NOT_QUIESCENT"
	return _initial_authority_refusal()


func retire_foundation(allow_prepared_world: bool = false) -> StringName:
	"""Retire only this Session's unbound foundation; never clear a borrowed store or authority link."""
	if not _ready and not _busy and _world == null and _budget == null:
		return &""
	var code: StringName = reset_refusal(allow_prepared_world)
	if code != &"":
		return code
	_ready = false
	_drop_foundations()
	_drop_borrowed()
	return &""


func space_owner() -> Owner:
	"""Borrow the published actual Owner; caller still needs each operation's original token proofs."""
	return _space if current_refusal() == &"" else null


func source_owner() -> Owner.CoreSources:
	"""Borrow the permanent actual source receiver, including its refusing unconfigured Routes shell."""
	return _sources if current_refusal() == &"" else null


func terrain_owner() -> Terrain:
	"""Borrow the exact same-world Terrain; no successful local survey is implied."""
	return _terrain if current_refusal() == &"" else null


func level_catalog() -> Levels:
	"""Borrow the immutable initial engineering menu without creating any level's physical floor."""
	return _levels if current_refusal() == &"" else null


func profile_catalog() -> Profiles:
	"""Borrow complete current source geometry; support, paid contact and renderer checks remain separate."""
	return _profiles if current_refusal() == &"" else null


func route_owner() -> Routes:
	"""Borrow the real identity shell for later root-owned graph composition, with no default edges."""
	return _routes if current_refusal() == &"" else null


func cold_budget() -> Budget:
	"""Borrow the one actual synchronous arena; a second Session or caller arena cannot replace it."""
	return _budget if current_refusal() == &"" else null
