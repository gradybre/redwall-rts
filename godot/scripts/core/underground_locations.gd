extends RefCounted
## Actual immutable multilevel endpoints. These local handles never stand in for Directory
## identities, paid cuts, a traversal profile or a surface tile. Decision 1075.

const Budget := preload("res://scripts/core/underground_budget.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const InventoryContract := preload("res://scripts/core/inventory_spatial_contract.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Modular := preload("res://scripts/core/modular_project_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Construction := preload("res://scripts/core/construction.gd")
const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const ConnectorCatalog := preload("res://scripts/core/underground_connector_catalog.gd")
const ConnectorFacts := preload("res://scripts/core/underground_connector_source_facts.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const SCHEMA: int = 1
const HEADER_FIELDS: int = 16
const I32_FIELDS: int = 22
const I64_FIELDS: int = 2
const ROW_BYTES: int = 106
const MAX_LOCATIONS: int = 4096 # An engineering allocation ceiling, not a player room limit.
const STORAGE_CELL_U: int = 2048 # Existing 2m placement-pile identity, with a real floor namespace.
const WORLD_COPY_CONTROL_BYTES: int = 256 # Private116B record plus guards coexist with the admitted observation.
const RESOLVE_CONTROL_BYTES: int = 512 # Caller frame36B/ref8B plus bounded scalar lookup frames; no image or array allocation.
const ROLE_TRANSIT: int = 0
const ROLE_STORAGE: int = 1
const ROLE_WORK: int = 2
const GENERATION: int = 0
const X: int = 1
const Y: int = 2
const Z: int = 3
const ROOM_SLOT: int = 4
const ROOM_GENERATION: int = 5
const SECTION_SLOT: int = 6
const SECTION_GENERATION: int = 7
const LEVEL: int = 8
const ROLE: int = 9
const ENVELOPE: int = 10
const SUPPORT: int = 16
const PAYLOAD_REVISION: int = 0
const GEOMETRY_REVISION: int = 1


class Record extends RefCounted:

	## Caller-owned packet only. Both envelopes are actual authored integer geometry.
	var point: Vector3i = Vector3i.ZERO
	var room: Vector2i = NULL_REF
	var section: Vector2i = NULL_REF
	var level: int = -1
	var role: int = -1
	var envelope: PackedInt32Array = PackedInt32Array()
	var support: PackedInt32Array = PackedInt32Array()
	var world: Vector2i = NULL_REF
	var payload_revision: int = 0
	var geometry_revision: int = 0


class Result extends RefCounted:
	var error: StringName = &""
	var token: int = 0
	var location: Vector2i = NULL_REF

	func _init(code: StringName = &"", next_token: int = 0, ref: Vector2i = NULL_REF) -> void:
		"""An explicit refusal never returns a partly usable local identity."""
		error = code
		token = next_token
		location = ref


class Bank extends RefCounted:
	## Two whole SoA banks, never one object per endpoint. Field-major indexing is columnar.
	var header: PackedInt64Array = PackedInt64Array()
	var i32: PackedInt32Array = PackedInt32Array()
	var i64: PackedInt64Array = PackedInt64Array()
	var present: PackedByteArray = PackedByteArray()
	var retired: PackedByteArray = PackedByteArray()
	var free_rows: PackedInt32Array = PackedInt32Array()
	var ordered: PackedInt32Array = PackedInt32Array()
	var free_count: int = 0
	var count: int = 0

	func allocate(capacity: int) -> void:
		"""Allocate exactly the admitted packed schema; all unused bytes start canonical."""
		header.resize(HEADER_FIELDS)
		i32.resize(I32_FIELDS * capacity)
		i64.resize(I64_FIELDS * capacity)
		present.resize(capacity)
		retired.resize(capacity)
		free_rows.resize(capacity)
		ordered.resize(capacity)
		ordered.fill(-1)
		for row: int in capacity:
			free_rows[row] = row
			for field: int in [ROOM_SLOT, SECTION_SLOT]:
				i32[field * capacity + row] = -1
		free_count = capacity

	func copy_from(other: Bank) -> void:
		"""Reuse reserved destination arrays, avoiding copy-on-write third-bank allocation."""
		for index: int in header.size():
			header[index] = other.header[index]
		for index: int in i32.size():
			i32[index] = other.i32[index]
		for index: int in i64.size():
			i64[index] = other.i64[index]
		for index: int in present.size():
			present[index] = other.present[index]
			retired[index] = other.retired[index]
			free_rows[index] = other.free_rows[index]
			ordered[index] = other.ordered[index]
		free_count = other.free_count
		count = other.count


class Retention extends RefCounted:
	## Optional weakly borrowed actual graph owner; once bound, expiration refuses retirement.
	func exact_binding(_locations: RefCounted) -> bool:
		"""A coincident local ref in another graph is not this endpoint namespace."""
		return false

	func retains(_location: Vector2i) -> bool:
		"""The actual graph must include live edges, occupied actors and retained path links."""
		return true


class WorldScope extends RefCounted:
	## Once-bound actual natural-surface publisher. No Site, Room or constructed floor is implied.
	func exact_binding(_locations: RefCounted, _space: Owner, _budget: Budget, _world: Vector2i) -> bool:
		"""Prove exact collaborators without publishing or manufacturing a natural-space observation."""
		return false

	func prepared_refusal(_space_token: int, _cold_token: int) -> StringName:
		"""Recheck the actual retained natural facts and original cold context before publication."""
		return &"LOCATION_WORLD_SCOPE"

	func is_publishing(_space_token: int, _cold_token: int) -> bool:
		"""Pure retained-window predicate: no observers, allocation or mutation may run here."""
		return false


class InstallationContext extends RefCounted:
	## One component-owned synchronous packet; issuer/Router/paid owner are exact weak identities.
	## Numeric payload112B; references/native headers stay in the Placement fixed/native reserve.
	var issuer: WeakRef = null
	var router: WeakRef = null
	var paid_owner: WeakRef = null
	var space: WeakRef = null
	var locations: WeakRef = null
	var construction: Construction = null
	var budget: Budget = null
	var world: Vector2i = NULL_REF
	var placement: Vector2i = NULL_REF
	var project: Vector2i = NULL_REF
	var assembly: int = -1
	var cold_token: int = 0
	var space_token: int = 0
	var location_token: int = 0
	var route_token: int = 0
	var base_revision: int = 0
	var target_revision: int = 0
	var profile_revision: int = 0
	var catalog_revision: int = 0
	var placement_revision: int = 0
	var payload_revision: int = 0


class RoomContext extends RefCounted:
	## One caller-owned80B admission packet; no future endpoint/edge or per-Room state is allocated here.
	var orders: WeakRef = null
	var space: WeakRef = null
	var locations: WeakRef = null
	var budget: Budget = null
	var world: Vector2i = NULL_REF
	var room: Vector2i = NULL_REF
	var cold_token: int = 0
	var space_token: int = 0
	var location_token: int = 0
	var route_token: int = 0
	var base_revision: int = 0
	var target_revision: int = 0
	var profile_revision: int = 0
	var catalog_revision: int = 0


class InventoryLocations extends InventoryContract:
	## Borrow the actual namespace weakly so Inventory cannot form an owner cycle.
	var _locations: WeakRef = null

	func _init(locations: RefCounted) -> void:
		"""This adapter grants no truth without its still-live actual owner."""
		_locations = weakref(locations) if locations != null else null

	func exact_binding(inventory: RefCounted, world: Vector2i) -> bool:
		"""Numeric coincidence in a foreign World never supplies an Inventory binding."""
		var locations: RefCounted = _locations.get_ref() if _locations != null else null
		return locations != null and locations.exact_inventory_binding(inventory, world)

	func world_ref() -> Vector2i:
		"""Read the retained actual World's full generation."""
		var locations: RefCounted = _locations.get_ref() if _locations != null else null
		return locations.world_ref() if locations != null else NULL_REF

	func storage_endpoint_refusal(location: Vector2i) -> StringName:
		"""All callbacks are read-only; stale support proofs refuse without refreshing state."""
		var locations: RefCounted = _locations.get_ref() if _locations != null else null
		return locations.storage_endpoint_refusal(location) if locations != null else REFUSE_AUTHORITY

	func location_revision(location: Vector2i) -> int:
		"""A stale geometric proof does not erase an otherwise retained payload identity."""
		var locations: RefCounted = _locations.get_ref() if _locations != null else null
		return locations.location_revision(location) if locations != null else 0

	func same_storage_cell(first: Vector2i, second: Vector2i) -> bool:
		"""Use the exact section and canonical 2m cell, including negative coordinates."""
		var locations: RefCounted = _locations.get_ref() if _locations != null else null
		return locations != null and locations.same_storage_cell(first, second)


var _ids: Directory = null
var _buildings: Buildings = null
var _transforms: Transforms = null
var _inventory: Inventory = null
var _owner: Owner = null
var _sources: Owner.CoreSources = null
var _sites: WeakRef = null
var _domain: Space.Domain = null
var _cold: Budget = null
var _capacity: int = 0
var _live: Bank = Bank.new()
var _stage: Bank = Bank.new()
var _world: Vector2i = NULL_REF
var _token: int = 0
var _next_token: int = 1
var _last_published_token: int = 0
var _cold_token: int = 0
var _owner_token: int = 0
var _site: Vector2i = NULL_REF
var _operation: int = -1
var _phase_stage: int = -1
var _base_geometry_revision: int = 0
var _target_geometry_revision: int = 0
var _sealed: bool = false
var _remaining: int = 0
var _snapshot: Space.Snapshot = null
var _region: Owner.Region = Owner.Region.new()
var _record: Record = Record.new()
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _retention: WeakRef = null
var _in_retention: bool = false
var _retention_reentered: bool = false
var _room_orders: WeakRef = null
var _room_admission: bool = false
var _admission_room: Vector2i = NULL_REF
var _admission_type: int = -1
var _world_scope: WeakRef = null
var _world_preparation: bool = false
var _installation: InstallationContext = null
var _resolve_source_ref: Vector2i = NULL_REF
var _resolve_source_hint: int = -1


func configure(ids: Directory, buildings: Buildings, transforms: Transforms,
		inventory: Inventory, owner: Owner, sources: Owner.CoreSources,
		cold: Budget, capacity: int, arena_bytes: int) -> StringName:
	"""Bind exact real stores and admit both banks before any allocation."""
	if _reject_retention_callback() or _capacity > 0:
		return &"LOCATION_ALREADY_BOUND"
	if capacity < 1 or capacity > MAX_LOCATIONS or arena_bytes < 228 * capacity + 256:
		return &"LOCATION_ARENA_CAPACITY"
	if ids == null or buildings == null or buildings.directory() != ids or transforms == null \
			or not transforms.is_bound_directory(ids) or inventory == null or owner == null \
			or sources == null or sources.directory() != ids or not owner.is_bound_sources(sources) or cold == null:
		return &"LOCATION_OWNER_MISMATCH"
	var domain: Space.Domain = owner.domain_copy()
	if domain == null or not ids.is_valid(domain._world) or ids.get_kind(domain._world) != Directory.KIND_WORLD:
		return &"LOCATION_WORLD_STALE"
	if sources.construction_owner() == null or sources.construction_owner().buildings() != buildings:
		return &"LOCATION_OWNER_MISMATCH"
	_ids = ids
	_buildings = buildings
	_transforms = transforms
	_inventory = inventory
	_owner = owner
	_sources = sources
	_domain = domain
	_cold = cold
	_capacity = capacity
	_world = domain._world
	_live.allocate(capacity)
	_stage.allocate(capacity)
	_write_header()
	return &""


func bind_sites(sites: Sites) -> StringName:
	"""Bind the actual permanent paid-key namespace after its same-world owner composition exists."""
	if _reject_retention_callback() or _capacity == 0 or _token != 0 or sites == null or sites.initialization_refusal() != &"" \
			or sites.construction_owner() != _sources.construction_owner() \
			or sites != _sources.construction_owner().excavation_authority():
		return &"LOCATION_SITE_OWNER"
	if _sites != null and _sites.get_ref() != sites:
		return &"LOCATION_SITE_OWNER"
	_sites = weakref(sites)
	return &""


func bind_room_orders(orders: RoomOrders) -> StringName:
	"""Bind the sole actual Room authority at quiescence; no candidate or endpoint is created."""
	if _reject_retention_callback() or _capacity == 0 or _token != 0 or _room_orders != null \
			or orders == null or not _cold.is_quiescent() or _owner.has_prepared():
		return &"LOCATION_ROOM_OWNER"
	_in_retention = true
	_retention_reentered = false
	var matches: bool = orders == _buildings.spatial_authority() and orders.buildings_owner() == _buildings \
		and orders.construction_owner() == _sources.construction_owner() and orders.world_ref() == world_ref()
	_in_retention = false
	if not matches or _retention_reentered or world_ref() == NULL_REF \
			or not _cold.is_quiescent() or _owner.has_prepared():
		return &"LOCATION_ROOM_OWNER"
	_room_orders = weakref(orders)
	return &""


func bind_world_scope(scope: WorldScope) -> StringName:
	"""Bind the actual natural-surface publisher once, including refusal to replace an expired scope."""
	if _reject_retention_callback() or _capacity == 0 or _token != 0 or _world_scope != null \
			or scope == null or world_ref() == NULL_REF or not _cold.is_quiescent() or _owner.has_prepared():
		return &"LOCATION_WORLD_SCOPE"
	_in_retention = true
	_retention_reentered = false
	var matches: bool = scope.exact_binding(self, _owner, _cold, _world)
	_in_retention = false
	if not matches or _retention_reentered or world_ref() == NULL_REF \
			or not _cold.is_quiescent() or _owner.has_prepared():
		return &"LOCATION_WORLD_SCOPE"
	_world_scope = weakref(scope)
	return &""


func _write_header() -> void:
	"""Sixteen I64 words retain exact immutable World/domain identity and wire shape."""
	_live.header[0] = SCHEMA
	_live.header[1] = _capacity
	_live.header[2] = _world.x
	_live.header[3] = _world.y
	for axis: int in 3:
		_live.header[4 + axis] = _domain._datum[axis]
		_live.header[7 + axis] = _domain._min_quantum[axis]
		_live.header[10 + axis] = _domain._size_quanta[axis]
	_live.header[13] = 1
	_live.header[14] = I32_FIELDS
	_live.header[15] = I64_FIELDS


func world_ref() -> Vector2i:
	"""A retired Directory World makes every endpoint unavailable."""
	return _world if _capacity > 0 and _ids.is_valid(_world) else NULL_REF


func exact_inventory_binding(inventory: RefCounted, world: Vector2i) -> bool:
	"""Do not infer shared namespaces from matching reference numbers."""
	return inventory != null and inventory == _inventory and world == world_ref() and world != NULL_REF


func is_bound_world(ids: Directory, world: Vector2i, owner: Owner) -> bool:
	"""Expose actual collaborator equality without allowing a rebind or state mutation."""
	return ids != null and ids == _ids and owner == _owner and world != NULL_REF and world == world_ref()


func is_bound_budget(candidate: Budget) -> bool:
	"""The actual World composer must give every cold consumer this same exact Budget instance."""
	return candidate != null and _capacity > 0 and candidate == _cold


func allocation_within(limit: int) -> bool:
	"""Compare actual endpoint capacity before a graph sizes its finite local-ref lookup namespace."""
	return _capacity > 0 and limit >= _capacity


func bind_retention(retention: Retention) -> StringName:
	"""Bind once without creating the Locations/Space/Routes ownership cycle."""
	if _reject_retention_callback() or _capacity == 0 or _token != 0 or _retention != null or retention == null:
		return &"LOCATION_RETENTION_BINDING"
	_in_retention = true
	_retention_reentered = false
	var matches: bool = retention.exact_binding(self)
	_in_retention = false
	if not matches or _retention_reentered:
		return &"LOCATION_RETENTION_BINDING"
	_retention = weakref(retention)
	return &""


func _reject_retention_callback() -> bool:
	"""Trusted retention callbacks inspect state; attempted reentrant mutations invalidate their answer."""
	if _in_retention:
		_retention_reentered = true
		return true
	return false


func _route_retention_refusal(location: Vector2i) -> StringName:
	"""An expired or foreign bound observer must never release an occupied endpoint."""
	if _retention == null:
		return &""
	var retention: Retention = _retention.get_ref() as Retention
	if retention == null or _in_retention:
		return &"LOCATION_RETENTION_BINDING"
	_in_retention = true
	_retention_reentered = false
	var matches: bool = retention.exact_binding(self)
	var retained: bool = retention.retains(location) if matches and not _retention_reentered else true
	_in_retention = false
	if not matches or _retention_reentered:
		return &"LOCATION_RETENTION_BINDING"
	return &"LOCATION_ROUTE_RETAINED" if retained else &""


func packed_memory_bytes() -> int:
	"""Both banks and their own heap/index arrays; caller cold outputs are separate."""
	return 228 * _capacity + 256 if _capacity > 0 else 0


func last_published_token() -> int:
	"""An exact successful bank swap has this unsaved receipt; a successful load clears it."""
	return _last_published_token


func wire_bytes() -> int:
	"""One explicit capture image, which must retain its cold lease until consumed."""
	return ROW_BYTES * _capacity + HEADER_FIELDS * 8 if _capacity > 0 else 0


func cold_peak_bytes() -> int:
	"""One complete snapshot plus two half-limit fragment arrays and bounded box scratch."""
	return 72 * _domain._regions + 16 * _domain._regions + 384 if _domain != null else 0


func is_live_location(location: Vector2i) -> bool:
	"""Retain full local generation even when support needs explicit cold revalidation."""
	return world_ref() != NULL_REF and _live_ref(_live, location)


func location_revision(location: Vector2i) -> int:
	"""Read immutable payload identity independently of unrelated geometric revisions."""
	return _get64(_live, PAYLOAD_REVISION, location.x) if is_live_location(location) else 0


func read_location_into(location: Vector2i, out: Record) -> StringName:
	"""Copy scalar fields into caller-owned fixed-size arrays; never allocate on a contact read."""
	if out == null or out.envelope.size() != 6 or out.support.size() != 6:
		return &"LOCATION_OUTPUT_SHAPE"
	if not is_live_location(location):
		return &"LOCATION_STALE"
	_read_row(_live, location.x, out)
	return &""


func resolve_existing_into(room: Vector2i, section: Vector2i, level: int, role: int, point: Vector3i,
		expected_revision: int, cold_token: int, max_checks: int, out: PackedInt32Array) -> StringName:
	"""Resolve one exact completed identity, never a prefix/contact/clearance permission; refusal preserves out[2]."""
	if out.size() != 2:
		return &"LOCATION_OUTPUT_SHAPE"
	var code: StringName = _resolve_scope_refusal(expected_revision, cold_token, max_checks)
	return code if code != &"" else _resolve_record_into(room, section, level, role, point,
		expected_revision, cold_token, out)


func resolve_existing_live_into(room: Vector2i, section: Vector2i, level: int, role: int, point: Vector3i,
		expected_revision: int, max_checks: int, out: PackedInt32Array) -> StringName:
	"""Hot exact live selector; reuse caller out[2], with no lease, observer, copy or endpoint authority."""
	if out.size() != 2:
		return &"LOCATION_OUTPUT_SHAPE"
	var code: StringName = _resolve_live_scope_refusal(expected_revision, max_checks)
	return code if code != &"" else _resolve_record_into(room, section, level, role, point,
		expected_revision, 0, out)


func _resolve_record_into(room: Vector2i, section: Vector2i, level: int, role: int, point: Vector3i,
		expected_revision: int, cold_token: int, out: PackedInt32Array) -> StringName:
	"""Both admitted entries share exact source/uniqueness proof; only the cold entry retains a lease."""
	if level < 0 or role < ROLE_TRANSIT or role > ROLE_WORK:
		return &"LOCATION_SELECTOR_FORMAT"
	var code: StringName = _resolve_section_refusal(room, section, level, point)
	if code != &"":
		return code
	var row: int = _resolve_unique_row(room, section, level, role, point)
	if row < 0:
		return &"LOCATION_SELECTOR_AMBIGUOUS" if row == -2 else &"LOCATION_SELECTOR_MISSING"
	if _get32(_live, GENERATION, row) <= 0 or _get64(_live, PAYLOAD_REVISION, row) <= 0 \
			or _get64(_live, GEOMETRY_REVISION, row) != expected_revision:
		return &"LOCATION_GEOMETRY_STALE"
	if cold_token != 0 and not _cold.covers(cold_token, RESOLVE_CONTROL_BYTES):
		return &"LOCATION_COLD_CAPACITY"
	out[0] = row
	out[1] = _get32(_live, GENERATION, row)
	return &""


func _resolve_scope_refusal(revision: int, cold_token: int, max_checks: int) -> StringName:
	"""Precharge the one endpoint/source scan before any read; all identity checks below avoid observation hooks."""
	if _cold == null or not _cold.covers(cold_token, RESOLVE_CONTROL_BYTES):
		return &"LOCATION_COLD_CAPACITY"
	return _resolve_live_scope_refusal(revision, max_checks)


func _resolve_live_scope_refusal(revision: int, max_checks: int) -> StringName:
	"""Precharge every finite live scan; current immutable namespace proof does not need a cold image."""
	if _capacity <= 0 or _owner == null or _owner._ready_error != &"" or _domain == null \
			or _owner._domain == null or _sources == null or _owner._sources != _sources:
		return &"LOCATION_OWNER_MISMATCH"
	if max_checks < 256 + 16 * _capacity + 4 * _owner._source_capacity \
			or max_checks > Space.MAX_CHECKS or max_checks > _domain._checks:
		return &"LOCATION_OPERATION_BUDGET"
	if _token != 0 or _in_retention or _owner._stage_token != 0 or _owner._room_callback \
			or _owner._validation_sources >= 0 or _owner._validation_regions >= 0:
		return &"LOCATION_SELECTOR_BUSY"
	if _ids == null or _buildings == null or _transforms == null or _inventory == null \
			or _sources._directory != _ids or _sources._buildings != _buildings \
			or _buildings._directory != _ids or _transforms._directory != _ids \
			or _sources._construction == null or _sources._construction._directory != _ids \
			or _sources._construction._buildings != _buildings or not _resolve_domain_matches():
		return &"LOCATION_OWNER_MISMATCH"
	if not _ids.is_valid_of_kind(_world, Directory.KIND_WORLD):
		return &"LOCATION_WORLD_STALE"
	return &"" if revision > 0 and _owner._header[17] == revision else &"LOCATION_GEOMETRY_STALE"


func _resolve_domain_matches(candidate: Space.Domain = null) -> bool:
	"""A copied Domain is an immutable namespace, not a substitute for the current actual World."""
	var actual: Space.Domain = _owner._domain if candidate == null else candidate
	return actual != null and _domain._world == _world and actual._world == _world and _domain._datum == actual._datum \
		and _domain._min_quantum == actual._min_quantum and _domain._size_quanta == actual._size_quanta \
		and _domain._bounds == actual._bounds \
		and _domain._cells == actual._cells and _domain._regions == actual._regions and _domain._checks == actual._checks


func _resolve_section_refusal(room: Vector2i, section: Vector2i, level: int, point: Vector3i) -> StringName:
	"""Null Room means only this World's surface floor; all other matches require that exact underground Room."""
	if not _owner._region_live(section, false) or _owner._r_role[section.x] != Space.FLOOR_DATUM \
			or _owner._r_claim_kind[section.x] != Owner.CLAIM_NONE or _owner._r_level[section.x] != level \
			or _owner._r_lo_y[section.x] != point.y or point.x < _owner._r_lo_x[section.x] \
			or point.x >= _owner._r_hi_x[section.x] or point.z < _owner._r_lo_z[section.x] \
			or point.z >= _owner._r_hi_z[section.x]:
		return &"LOCATION_SECTION_STALE"
	var source_ref: Vector2i = _world if room == NULL_REF else room
	if (room == NULL_REF and level != 0) or _owner._r_owner_slot[section.x] != source_ref.x \
			or _owner._r_owner_generation[section.x] != source_ref.y:
		return &"LOCATION_SECTION_STALE"
	var source: int = _resolve_source_row(source_ref)
	if source < 0 or _owner._o_revision[source] <= 0 \
			or _owner._r_owner_revision[section.x] != _owner._o_revision[source]:
		return &"LOCATION_SOURCE_STALE"
	if room == NULL_REF:
		return &"" if _owner._o_kind[source] == Directory.KIND_WORLD \
			and _owner._o_parent_slot[source] == -1 and _owner._o_parent_generation[source] == 0 \
			and _owner._o_a[source] == 0 and _owner._o_b[source] == 0 \
			and _owner._o_c[source] == 0 and _owner._o_d[source] == 0 else &"LOCATION_SOURCE_STALE"
	return _resolve_room_source_refusal(room, source)


func _resolve_source_row(ref: Vector2i) -> int:
	"""Reuse only an exact full-ref row; seal/load owns uniqueness, while every caller still rechecks source facts."""
	if _resolve_source_ref == ref and _resolve_source_hint >= 0 and _resolve_source_hint < _owner._source_capacity \
			and _owner._o_present[_resolve_source_hint] == 1 and _owner._o_slot[_resolve_source_hint] == ref.x \
			and _owner._o_generation[_resolve_source_hint] == ref.y:
		return _resolve_source_hint
	var found: int = -1
	for row: int in _owner._source_capacity:
		if _owner._o_present[row] == 0 or _owner._o_slot[row] != ref.x:
			continue
		if _owner._o_present[row] != 1 or _owner._o_generation[row] != ref.y or found >= 0:
			return -1
		found = row
	_resolve_source_ref = ref
	_resolve_source_hint = found
	return found


func _resolve_room_source_refusal(room: Vector2i, source: int) -> StringName:
	"""Compare actual mirrored Room facts directly; no Buildings/Source observation runs during selection."""
	if not _ids.is_valid_of_kind(room, Directory.KIND_ROOM):
		return &"LOCATION_ROOM_STALE"
	var row: int = _ids.get_typed_row(room)
	if row < 0 or row >= _buildings._r_present.size() or _buildings._r_present[row] != 1 \
			or _buildings._r_ref_slot[row] != room.x or _buildings._r_ref_generation[row] != room.y \
			or _buildings._r_spatial_kind[row] != Buildings.ROOM_SPACE_UNDERGROUND:
		return &"LOCATION_ROOM_STALE"
	return &"" if _owner._o_kind[source] == Directory.KIND_ROOM \
		and _owner._o_parent_slot[source] == _buildings._r_building_slot[row] \
		and _owner._o_parent_generation[source] == _buildings._r_building_generation[row] \
		and _owner._o_a[source] == _buildings._r_type[row] and _owner._o_b[source] == 0 \
		and _owner._o_c[source] == 0 and _owner._o_d[source] == Buildings.ROOM_SPACE_UNDERGROUND \
		else &"LOCATION_SOURCE_STALE"


func _resolve_unique_row(room: Vector2i, section: Vector2i, level: int, role: int, point: Vector3i) -> int:
	"""A second live payload at the same selector is ambiguous even if its stored geometry proof is stale."""
	var found: int = -1
	for row: int in _capacity:
		if _live.present[row] != 1 or _ref_at(_live, ROOM_SLOT, row) != room \
				or _ref_at(_live, SECTION_SLOT, row) != section or _get32(_live, LEVEL, row) != level \
				or _get32(_live, ROLE, row) != role or _get32(_live, X, row) != point.x \
				or _get32(_live, Y, row) != point.y or _get32(_live, Z, row) != point.z:
			continue
		if found >= 0:
			return -2
		found = row
	return found


func prepared_location_into(token: int, location: Vector2i, out: Record) -> StringName:
	"""Copy an exact sealed endpoint for a nested graph candidate; never lend either bank's arrays."""
	var code: StringName = prepared_refusal(token)
	if code != &"":
		return code
	if out == null or out.envelope.size() != 6 or out.support.size() != 6:
		return &"LOCATION_OUTPUT_SHAPE"
	if not _live_ref(_stage, location):
		return &"LOCATION_STALE"
	_read_row(_stage, location.x, out)
	return &""


func storage_endpoint_refusal(location: Vector2i) -> StringName:
	"""A stored proof cannot survive a geometry edit silently; this callback never refreshes it."""
	if not is_live_location(location):
		return &"LOCATION_STALE"
	var row: int = location.x
	if _get32(_live, ROLE, row) != ROLE_STORAGE:
		return &"LOCATION_NOT_STORAGE"
	if _get64(_live, GEOMETRY_REVISION, row) != _owner.revision():
		return &"LOCATION_GEOMETRY_STALE"
	var room: Vector2i = _ref_at(_live, ROOM_SLOT, row)
	if room != NULL_REF and not _buildings.is_live_room(room):
		return &"LOCATION_ROOM_STALE"
	return &"" if _owner.is_live_region(_ref_at(_live, SECTION_SLOT, row)) else &"LOCATION_SECTION_STALE"


func same_storage_cell(first: Vector2i, second: Vector2i) -> bool:
	"""Section identity separates stacked floors; floor division remains exact below the datum."""
	if not is_live_location(first) or not is_live_location(second) \
			or _ref_at(_live, SECTION_SLOT, first.x) != _ref_at(_live, SECTION_SLOT, second.x):
		return false
	return _cell(_get32(_live, X, first.x), _domain._datum.x) == _cell(_get32(_live, X, second.x), _domain._datum.x) \
		and _cell(_get32(_live, Z, first.x), _domain._datum.z) == _cell(_get32(_live, Z, second.x), _domain._datum.z)


func begin_prepare(cold_token: int, owner_token: int = 0, site: Vector2i = NULL_REF,
		operation: int = -1, phase_stage: int = -1) -> Result:
	"""Borrow the already-reserved shared cold arena; no live endpoint changes before publication."""
	if _reject_retention_callback() or _capacity == 0 or world_ref() == NULL_REF or _token != 0 or _next_token == 9223372036854775807:
		return Result.new(&"LOCATION_PREPARATION_BUSY")
	if not _cold.covers(cold_token, cold_peak_bytes()):
		return Result.new(&"LOCATION_COLD_CAPACITY")
	if owner_token == 0 and _owner.has_prepared():
		return Result.new(&"LOCATION_GEOMETRY_BUSY")
	if owner_token != 0:
		var code: StringName = _future_context_refusal(owner_token, site, operation, phase_stage)
		if code != &"":
			return Result.new(code)
	return _start_preparation(cold_token, owner_token, site, operation, phase_stage)


func _start_preparation(cold_token: int, owner_token: int, site: Vector2i,
		operation: int, phase_stage: int) -> Result:
	"""Reuse the two admitted banks only after the caller's exact publication context is proved."""
	_stage.copy_from(_live)
	_stage.header[13] += 1
	if _stage.header[13] <= _live.header[13]:
		return Result.new(&"LOCATION_REVISION_EXHAUSTED")
	_token = _next_token
	_next_token += 1
	_cold_token = cold_token
	_owner_token = owner_token
	_site = site
	_operation = operation
	_phase_stage = phase_stage
	_base_geometry_revision = _owner.revision()
	_target_geometry_revision = _owner.revision() + (1 if owner_token != 0 and _owner.prepared_has_changes(owner_token) else 0)
	_remaining = _domain._checks
	return Result.new(&"", _token)


func begin_room_prepare(cold_token: int, owner_token: int, room: Vector2i,
		room_type: int) -> Result:
	"""Refresh completed endpoints after Room geometry seals, never create first-entry space or a Site."""
	if _reject_retention_callback() or _capacity == 0 or world_ref() == NULL_REF or _token != 0 \
			or _next_token == 9223372036854775807 or owner_token <= 0:
		return Result.new(&"LOCATION_PREPARATION_BUSY")
	var orders: RoomOrders = _actual_orders()
	var code: StringName = _room_preflight(orders, cold_token, owner_token, room, room_type)
	if code != &"":
		return Result.new(code)
	var result: Result = _start_preparation(cold_token, owner_token, NULL_REF, -1, -1)
	if result.error == &"":
		_room_admission = true
		_admission_room = room
		_admission_type = room_type
	return result


func begin_world_prepare(cold_token: int, owner_token: int) -> Result:
	"""Prepare only against the once-bound World publisher and its exact sealed natural-space candidate."""
	if _reject_retention_callback() or _capacity == 0 or world_ref() == NULL_REF or _token != 0 \
			or _next_token == 9223372036854775807 or owner_token <= 0:
		return Result.new(&"LOCATION_PREPARATION_BUSY")
	var code: StringName = _world_preflight(_actual_world_scope(), cold_token, owner_token)
	if code != &"":
		return Result.new(code)
	var result: Result = _start_preparation(cold_token, owner_token, NULL_REF, -1, -1)
	if result.error == &"":
		_world_preparation = true
		_target_geometry_revision = _owner.revision() + 1
	return result


func installation_binding_refusal(context: InstallationContext) -> StringName:
	"""Pure link admission runs before either side writes its once-bound actual installation context."""
	return installation_binding_leaf_refusal(self, context)


static func installation_binding_leaf_refusal(actual: RefCounted, context: InstallationContext) -> StringName:
	"""The final reciprocal link proof cannot dispatch an overridden observation method."""
	if actual == null or actual._capacity == 0 or actual._token != 0 or actual._in_retention or context == null \
			or (actual._installation != null and actual._installation != context) or context.issuer == null \
			or context.issuer.get_ref() == null or context.locations == null or context.locations.get_ref() != actual \
			or context.space == null or context.space.get_ref() != actual._owner or context.budget != actual._cold \
			or context.world != actual._world or context.construction != actual._sources._construction:
		return &"LOCATION_INSTALLATION_BINDING"
	return &"" if context.budget.is_quiescent() else &"LOCATION_COLD_CAPACITY"


func bind_installation_context(context: InstallationContext) -> StringName:
	"""Once bind the exact shared packet after reciprocal pure preflight; no provider is invoked."""
	var code: StringName = installation_binding_refusal(context)
	if code == &"":
		_installation = context
	return code


static func installation_scope_refusal(actual: RefCounted, context: InstallationContext,
		publishing: bool = false) -> StringName:
	"""Exact actual Construction/Router leaves replace any virtual publication-success predicate."""
	if context == null or context != actual._installation or context.locations == null \
			or context.locations.get_ref() != actual or context.space == null or context.space.get_ref() != actual._owner \
			or context.budget != actual._cold or context.world != actual._world or context.issuer == null \
			or context.issuer.get_ref() == null or context.construction == null \
			or context.construction != actual._sources._construction or context.cold_token <= 0 \
			or not actual._cold.covers(context.cold_token, Budget.COLD_BYTES):
		return &"LOCATION_INSTALLATION_CONTEXT"
	if actual._token > 0 and (context.location_token != actual._token or context.cold_token != actual._cold_token \
			or context.space_token != actual._owner_token or context.base_revision != actual._base_geometry_revision \
			or context.target_revision != actual._target_geometry_revision):
		return &"LOCATION_INSTALLATION_CONTEXT"
	var router: Router = context.router.get_ref() as Router if context.router != null else null
	var paid: Modular.Owner = context.paid_owner.get_ref() as Modular.Owner if context.paid_owner != null else null
	if router == null or paid == null or router._ready_error != &"" or router._construction != context.construction \
			or router._world != context.world or router._inventory != actual._inventory or router._connector_owner == null \
			or router._connector_owner.get_ref() != paid or context.construction._modular_authority == null \
			or context.construction._modular_authority.get_ref() != router:
		return &"LOCATION_INSTALLATION_CONTEXT"
	if publishing and (not router._busy or router._publishing_project != context.project \
			or router._publishing_action != Modular.COMMIT or router._publishing_owner != paid):
		return &"LOCATION_INSTALLATION_WINDOW"
	return _installation_project_refusal(actual, context)


static func _installation_project_refusal(actual: RefCounted, context: InstallationContext) -> StringName:
	"""Neither a coincident local handle nor the released postpayment worker assignment grants identity."""
	var project: Vector2i = context.project
	var construction: Construction = context.construction
	if construction._directory != actual._ids or not actual._ids.is_valid_of_kind(context.world, Directory.KIND_WORLD) \
			or not actual._ids.is_valid_of_kind(project, Directory.KIND_CONSTRUCTION):
		return &"LOCATION_INSTALLATION_PROJECT"
	var row: int = actual._ids.get_typed_row(project)
	if row < 0 or row >= Construction.CONSTRUCTION_CAPACITY or construction._present[row] != 1 \
			or construction._ref_slot[row] != project.x or construction._ref_generation[row] != project.y \
			or construction._purpose[row] != Construction.PURPOSE_CONNECTOR_INSTALL \
			or construction._type_id[row] != context.assembly or context.assembly < 0 \
			or Vector2i(construction._subject_slot[row], construction._subject_generation[row]) != context.placement \
			or context.placement.x < 0 or context.placement.y <= 0:
		return &"LOCATION_INSTALLATION_PROJECT"
	return &""


func begin_installation_prepare(context: InstallationContext) -> Result:
	"""Prepare a paid installation companion against an exact sealed Space token, with no borrowed Site permit."""
	if _reject_retention_callback() or _token != 0 or _next_token == 9223372036854775807:
		return Result.new(&"LOCATION_PREPARATION_BUSY")
	var code: StringName = installation_scope_refusal(self, context)
	if code != &"" or context.space_token <= 0 or _owner._stage_token != context.space_token or not _owner._sealed:
		return Result.new(code if code != &"" else &"LOCATION_GEOMETRY_STALE")
	var cold_token: int = context.cold_token
	var space_token: int = context.space_token
	var base_revision: int = context.base_revision
	var target_revision: int = context.target_revision
	_in_retention = true
	_retention_reentered = false
	code = _owner.prepared_refusal(context.space_token)
	_in_retention = false
	if _retention_reentered:
		return Result.new(&"LOCATION_RETENTION_REENTRY")
	if code == &"":
		code = installation_scope_refusal(self, context)
	if code != &"" or context.cold_token != cold_token or context.space_token != space_token \
			or context.base_revision != base_revision or context.target_revision != target_revision \
			or _owner._stage_token != space_token or not _owner._sealed \
			or _owner._header[17] != base_revision or _owner._s_header[17] != target_revision:
		return Result.new(code if code != &"" else &"LOCATION_GEOMETRY_STALE")
	var result: Result = _start_installation(context)
	context.location_token = result.token if result.error == &"" else 0
	return result


func _start_installation(context: InstallationContext) -> Result:
	"""The final pure lease gate immediately precedes bank copying; no observer supplies numeric revision pins."""
	if not _cold.covers(context.cold_token, Budget.COLD_BYTES) or _live.header[13] == 9223372036854775807:
		return Result.new(&"LOCATION_COLD_CAPACITY")
	_stage.copy_from(_live)
	_stage.header[13] += 1
	_token = _next_token
	_next_token += 1
	_cold_token = context.cold_token
	_owner_token = context.space_token
	_site = NULL_REF
	_operation = -1
	_phase_stage = -1
	_base_geometry_revision = context.base_revision
	_target_geometry_revision = context.target_revision
	_remaining = _domain._checks
	return Result.new(&"", _token)


func _installation_active() -> bool:
	"""Exact local token identity distinguishes this context from all other endpoint preparation modes."""
	return _installation != null and _token > 0 and _installation.location_token == _token


static func installation_prepared_leaf_refusal(actual: RefCounted, context: InstallationContext) -> StringName:
	"""Pure final candidate proof; all source/retention observations already completed before Funding."""
	var code: StringName = installation_scope_refusal(actual, context)
	if code != &"":
		return code
	if actual._token <= 0 or actual._token != context.location_token or not actual._sealed or actual._in_retention \
			or actual._cold_token != context.cold_token or actual._owner_token != context.space_token \
			or actual._base_geometry_revision != context.base_revision or actual._target_geometry_revision != context.target_revision:
		return &"LOCATION_TOKEN_STALE"
	return _installation_rows_refusal(actual, context)


static func _installation_rows_refusal(actual: RefCounted, context: InstallationContext) -> StringName:
	"""Paid installation only adds/refreshes endpoints; no existing immutable payload or retention can disappear."""
	for row: int in actual._capacity:
		if actual._live.present[row] != 0:
			if actual._stage.present[row] != actual._live.present[row]:
				return &"LOCATION_INSTALLATION_CREATE_ONLY"
			for field: int in I32_FIELDS:
				if actual._live.i32[field * actual._capacity + row] != actual._stage.i32[field * actual._capacity + row]:
					return &"LOCATION_INSTALLATION_CREATE_ONLY"
			if actual._live.i64[PAYLOAD_REVISION * actual._capacity + row] != actual._stage.i64[PAYLOAD_REVISION * actual._capacity + row]:
				return &"LOCATION_INSTALLATION_CREATE_ONLY"
		if actual._stage.present[row] != 0 and actual._stage.i64[GEOMETRY_REVISION * actual._capacity + row] != context.target_revision:
			return &"LOCATION_INSTALLATION_REFRESH_REQUIRED"
	return &""


static func publish_installation(actual: RefCounted, context: InstallationContext) -> bool:
	"""Static kernel: no observer follows payment or Space publication; old endpoints are always preserved."""
	if installation_scope_refusal(actual, context, true) != &"" \
			or installation_prepared_leaf_refusal(actual, context) != &"" \
			or actual._owner._stage_token != 0 or actual._owner._header[17] != context.target_revision \
			or actual._owner._last_published_token != context.space_token:
		return false
	var previous: Bank = actual._live
	actual._live = actual._stage
	actual._stage = previous
	actual._last_published_token = context.location_token
	_clear_installation_preparation(actual)
	return true


static func _clear_installation_preparation(actual: RefCounted) -> void:
	"""Reset only transient fields directly, avoiding any virtual dispatch inside the paid kernel."""
	actual._token = 0
	actual._cold_token = 0
	actual._owner_token = 0
	actual._site = NULL_REF
	actual._operation = -1
	actual._phase_stage = -1
	actual._base_geometry_revision = 0
	actual._target_geometry_revision = 0
	actual._sealed = false
	actual._snapshot = null
	actual._room_admission = false
	actual._admission_room = NULL_REF
	actual._admission_type = -1
	actual._world_preparation = false


static func room_scope_leaf_refusal(actual: RefCounted, context: RoomContext, publishing: bool = false) -> StringName:
	"""Read only the actual once-bound RoomOrders' retained entry and original shared arena; no scope callback."""
	if actual == null or context == null or context.orders == null or context.locations == null \
			or context.locations.get_ref() != actual or context.space == null or context.space.get_ref() != actual._owner \
			or context.budget != actual._cold or context.world != actual._world or actual._room_orders == null \
			or not actual._cold.covers(context.cold_token, Budget.COLD_BYTES):
		return &"LOCATION_ROOM_CONTEXT"
	var orders: RoomOrders = context.orders.get_ref() as RoomOrders
	if orders == null or actual._room_orders.get_ref() != orders or not orders._entry_mode or not orders._cold_held \
			or orders._stage_action != RoomOrders.ROOM_ADMISSION_STAGE or orders._world != context.world \
			or orders._room_budget != context.budget or orders._room_cold_token != context.cold_token \
			or orders._space != actual._owner or orders._stage_token != context.space_token \
			or orders._stage_room != context.room or orders._room_candidate.ref != context.room \
			or orders._sources != actual._sources or orders._buildings != actual._buildings \
			or orders._construction != actual._sources._construction or actual._buildings._spatial_authority == null \
			or actual._buildings._spatial_authority.get_ref() != orders \
			or not actual._ids.is_valid_of_kind(context.world, Directory.KIND_WORLD):
		return &"LOCATION_ROOM_CONTEXT"
	return &"LOCATION_ROOM_WINDOW" if publishing and not orders._publishing else &""


static func room_prepared_leaf_refusal(actual: RefCounted, context: RoomContext) -> StringName:
	"""Admission only refreshes complete old endpoints; all observation/retention callbacks have already returned."""
	var code: StringName = room_scope_leaf_refusal(actual, context)
	if code != &"":
		return code
	if actual._token <= 0 or actual._token != context.location_token or not actual._sealed \
			or actual._in_retention or actual._retention_reentered or actual._snapshot != null \
			or not actual._room_admission or actual._admission_room != context.room \
			or actual._admission_type != Buildings.ROOM_TYPE_CORRIDOR or actual._cold_token != context.cold_token \
			or actual._owner_token != context.space_token or actual._base_geometry_revision != context.base_revision \
			or actual._target_geometry_revision != context.target_revision:
		return &"LOCATION_TOKEN_STALE"
	return _room_rows_leaf_refusal(actual, context.target_revision)


static func _room_rows_leaf_refusal(actual: RefCounted, target_revision: int) -> StringName:
	"""Same full handles and immutable payloads preserve every Inventory, actor and route retainer without observers."""
	if actual._stage.count != actual._live.count or actual._stage.free_count != actual._live.free_count:
		return &"LOCATION_ROOM_REFRESH_ONLY"
	for row: int in actual._capacity:
		if actual._stage.present[row] != actual._live.present[row] or actual._stage.retired[row] != actual._live.retired[row]:
			return &"LOCATION_ROOM_REFRESH_ONLY"
		for field: int in I32_FIELDS:
			if actual._stage.i32[field * actual._capacity + row] != actual._live.i32[field * actual._capacity + row]:
				return &"LOCATION_ROOM_REFRESH_ONLY"
		if actual._stage.i64[PAYLOAD_REVISION * actual._capacity + row] != actual._live.i64[PAYLOAD_REVISION * actual._capacity + row]:
			return &"LOCATION_ROOM_REFRESH_ONLY"
		if actual._stage.present[row] != 0 and actual._stage.i64[GEOMETRY_REVISION * actual._capacity + row] != target_revision:
			return &"LOCATION_ROOM_REFRESH_REQUIRED"
	return &""


static func publish_room_preflighted(actual: RefCounted, context: RoomContext) -> bool:
	"""The exact Room and Space receipts precede this static refresh-only swap; no observer can fail afterward."""
	if room_scope_leaf_refusal(actual, context, true) != &"" or room_prepared_leaf_refusal(actual, context) != &"" \
			or actual._owner._stage_token != 0 or actual._owner._header[17] != context.target_revision \
			or actual._owner._last_published_token != context.space_token \
			or not actual._ids.is_valid_of_kind(context.room, Directory.KIND_ROOM):
		return false
	var previous: Bank = actual._live
	actual._live = actual._stage
	actual._stage = previous
	actual._last_published_token = context.location_token
	_clear_installation_preparation(actual)
	return true


func _actual_world_scope() -> WorldScope:
	"""Keep the weakly bound real publisher alive for the complete synchronous observation."""
	return _world_scope.get_ref() as WorldScope if _world_scope != null else null


func _world_scope_current(scope: WorldScope, cold_token: int, owner_token: int) -> bool:
	"""Pure owner, capacity and original-lease pins precede every allocating source observation."""
	return scope != null and scope == _actual_world_scope() and world_ref() != NULL_REF and owner_token > 0 \
		and _cold.covers(cold_token, cold_peak_bytes() + WORLD_COPY_CONTROL_BYTES) \
		and _owner.allocation_within(Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY) \
		and _domain._regions <= Budget.PHASE_VOLUME_CAPACITY


func _world_preflight(scope: WorldScope, cold_token: int, owner_token: int) -> StringName:
	"""Complete all virtual observers before final pure context checks and any bank/image allocation."""
	if not _world_scope_current(scope, cold_token, owner_token) or _owner._stage_token != owner_token \
			or not _owner._sealed or _owner._validation_sources >= 0:
		return &"LOCATION_WORLD_SCOPE"
	_in_retention = true
	_retention_reentered = false
	var code: StringName = &"" if scope.exact_binding(self, _owner, _cold, _world) else &"LOCATION_WORLD_SCOPE"
	if code == &"" and _world_scope_current(scope, cold_token, owner_token):
		code = scope.prepared_refusal(owner_token, cold_token)
	if code == &"" and _world_scope_current(scope, cold_token, owner_token):
		code = _owner.prepared_refusal(owner_token)
	if code == &"" and _world_scope_current(scope, cold_token, owner_token):
		code = scope.prepared_refusal(owner_token, cold_token)
	_in_retention = false
	if _retention_reentered or not _world_scope_current(scope, cold_token, owner_token) \
			or _owner._stage_token != owner_token or not _owner._sealed:
		return &"LOCATION_WORLD_SCOPE"
	return code


func _actual_orders() -> RoomOrders:
	"""Borrow the once-bound actual coordinator strongly for a complete synchronous observation."""
	return _room_orders.get_ref() as RoomOrders if _room_orders != null else null


func _room_preflight(orders: RoomOrders, cold_token: int, owner_token: int,
		room: Vector2i, room_type: int, check_geometry: bool = true) -> StringName:
	"""The original actual lease precedes callbacks and covers Room copies plus one sequential survey."""
	if orders == null or orders != _buildings.spatial_authority() or world_ref() == NULL_REF \
			or not _cold.covers(cold_token, Budget.COLD_BYTES) \
			or not _owner.allocation_within(Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY) \
			or _domain._regions > Budget.PHASE_VOLUME_CAPACITY:
		return &"LOCATION_ROOM_SCOPE"
	_in_retention = true
	_retention_reentered = false
	var code: StringName = orders.room_companion_refusal(room, room_type, owner_token, cold_token, _owner, _cold)
	if code == &"" and check_geometry:
		code = _owner.prepared_refusal(owner_token)
	if code == &"":
		code = orders.room_companion_refusal(room, room_type, owner_token, cold_token, _owner, _cold)
	_in_retention = false
	if _retention_reentered or not _cold.covers(cold_token, Budget.COLD_BYTES) or world_ref() == NULL_REF:
		return &"LOCATION_ROOM_SCOPE"
	return _entry_payload_refusal(orders, cold_token) if code == &"" else code


func _entry_payload_refusal(orders: RoomOrders, cold_token: int) -> StringName:
	"""Recount both actual mutable EntryPlan images after observations, immediately before a companion copy."""
	if not orders._entry_mode:
		return &""
	if orders._entry_plan == null or not EntryPlan.same(orders._entry_plan, orders._entry_request):
		return &"LOCATION_ROOM_SCOPE"
	var bytes: int = 2 * EntryPlan.payload_bytes(orders._entry_plan) + cold_peak_bytes() + 2048
	return &"" if _cold.covers(cold_token, bytes) else &"LOCATION_COLD_CAPACITY"


func _future_context_refusal(owner_token: int, site: Vector2i, operation: int,
		phase_stage: int) -> StringName:
	"""A future endpoint is tied to the exact real physical phase and sealed spatial candidate."""
	var physical: Sites = _physical()
	if physical == null or not physical.is_live_site(site) or operation < 0 or operation >= Contract.OP_COUNT \
			or phase_stage not in [Contract.STAGE_START, Contract.STAGE_COMMIT, Contract.STAGE_CANCEL]:
		return &"LOCATION_SITE_OWNER"
	if not physical.operation_into(site, _math) or _math.value != operation \
			or physical.room_of(site) == NULL_REF:
		return &"LOCATION_SITE_PHASE"
	return _owner.prepared_refusal(owner_token)


func stage_add(token: int, record: Record) -> Result:
	"""Register only fully covered actual void and support, never a guessed point in empty dirt."""
	var code: StringName = _editable(token)
	if code == &"" and _room_admission:
		code = &"LOCATION_ROOM_REFRESH_ONLY"
	if code == &"" and _world_preparation and (record == null or record.room != NULL_REF or record.level != 0):
		code = &"LOCATION_WORLD_CREATE_ONLY"
	if code == &"":
		code = _validate_record(record)
	if code != &"":
		return Result.new(code)
	if _stage.free_count == 0:
		return Result.new(&"LOCATION_ARENA_FULL")
	var row: int = _pop_free(_stage)
	var generation: int = _get32(_stage, GENERATION, row) + 1
	_set32(_stage, GENERATION, row, generation)
	_write_row(row, record)
	_stage.present[row] = 1
	_stage.count += 1
	return Result.new(&"", token, Vector2i(row, generation))


func stage_refresh(token: int, location: Vector2i) -> StringName:
	"""Revalidate an existing immutable endpoint without changing Inventory's payload revision."""
	var code: StringName = _editable(token)
	if code != &"" or not _live_ref(_stage, location):
		return code if code != &"" else &"LOCATION_STALE"
	_prepare_record_scratch()
	_read_row(_stage, location.x, _record)
	code = _validate_record(_record)
	if code == &"":
		_set64(_stage, GEOMETRY_REVISION, location.x, _snapshot.revision)
	return code


func stage_remove(token: int, location: Vector2i) -> StringName:
	"""Retained real goods keep their exact endpoint, including after its geometric proof goes stale."""
	var code: StringName = _editable(token)
	if code != &"" or not _live_ref(_stage, location):
		return code if code != &"" else &"LOCATION_STALE"
	if _room_admission:
		return &"LOCATION_ROOM_REFRESH_ONLY"
	if _world_preparation:
		return &"LOCATION_WORLD_CREATE_ONLY"
	if _inventory.has_spatial_location(location, _get64(_stage, PAYLOAD_REVISION, location.x)):
		return &"LOCATION_INVENTORY_RETAINED"
	code = _route_retention_refusal(location)
	if code == &"":
		code = _editable(token)
	if code != &"":
		return code
	if _inventory.has_spatial_location(location, _get64(_stage, PAYLOAD_REVISION, location.x)):
		return &"LOCATION_INVENTORY_RETAINED"
	_clear_row(_stage, location.x)
	_stage.count -= 1
	if _get32(_stage, GENERATION, location.x) == Space.I32_MAX:
		_stage.retired[location.x] = 1
	else:
		_push_free(_stage, location.x)
	return &""


func seal(token: int) -> StringName:
	"""Finish derived ordering and check the actual geometry has not changed during cold preparation."""
	var code: StringName = _editable(token)
	if code != &"":
		return code
	code = _geometry_current_refusal()
	if code != &"":
		return code
	code = _prepared_retention_refusal()
	if code != &"":
		return code
	_rebuild_order(_stage)
	_sealed = true
	_snapshot = null
	return &""


func prepared_refusal(token: int) -> StringName:
	"""Validate this receiver's exact sealed candidate and retained cold lease."""
	if _reject_retention_callback() or token == 0 or token != _token or not _sealed or not _cold.covers(_cold_token, cold_peak_bytes()):
		return &"LOCATION_TOKEN_STALE"
	return _prepared_retention_refusal()


func _prepared_retention_refusal() -> StringName:
	"""All observer callbacks precede fresh actual geometry, Inventory and lease checks."""
	var code: StringName = _current_retention_refusal()
	if code == &"":
		code = _geometry_current_refusal()
	if code == &"" and _room_admission:
		code = _refreshed_room_rows_refusal()
	if code == &"" and _world_preparation:
		code = _world_rows_refusal()
	if code == &"" and _installation_active():
		code = _installation_rows_refusal(self, _installation)
	if code == &"":
		code = _installed_witnesses_refusal()
	return _final_inventory_refusal(_cold_token, cold_peak_bytes()) if code == &"" else code


func _world_rows_refusal() -> StringName:
	"""Preserve every retained immutable handle; only new World/level-zero rows may be added."""
	for row: int in _capacity:
		if _live.present[row] != 0 and (not _row_payload_unchanged(row) \
				or _get64(_stage, PAYLOAD_REVISION, row) != _get64(_live, PAYLOAD_REVISION, row)):
			return &"LOCATION_WORLD_CREATE_ONLY"
		if _stage.present[row] == 0:
			continue
		if _get64(_stage, GEOMETRY_REVISION, row) != _target_geometry_revision:
			return &"LOCATION_WORLD_REFRESH_REQUIRED"
		if _live.present[row] == 0 and (_ref_at(_stage, ROOM_SLOT, row) != NULL_REF or _get32(_stage, LEVEL, row) != 0):
			return &"LOCATION_WORLD_CREATE_ONLY"
	return &""


func _refreshed_room_rows_refusal() -> StringName:
	"""A Room confirmation preserves every existing immutable endpoint with its new complete proof."""
	for row: int in _capacity:
		if _live.present[row] != _stage.present[row] or not _row_payload_unchanged(row):
			return &"LOCATION_ROOM_REFRESH_ONLY"
		if _live.present[row] != 0 and (_get64(_stage, PAYLOAD_REVISION, row) != _get64(_live, PAYLOAD_REVISION, row) \
				or _get64(_stage, GEOMETRY_REVISION, row) != _target_geometry_revision):
			return &"LOCATION_ROOM_REFRESH_REQUIRED"
	return &""


func abort(token: int) -> bool:
	"""Drop only the transient candidate; the composition owner still holds its shared cold lease."""
	if _reject_retention_callback() or token == 0 or token != _token:
		return false
	_reset_preparation()
	return true


func publish(token: int) -> bool:
	"""Swap only in the prepared actual Sites or Room callback, after the exact Space publication."""
	if _reject_retention_callback() or token == 0 or token != _token or not _sealed or not _cold.covers(_cold_token, cold_peak_bytes()):
		return false
	if _installation_active():
		return false # The static paid kernel owns this context.
	if _world_preparation:
		if _world_publication_refusal() != &"":
			return false
	elif _current_retention_refusal() != &"" or _publication_geometry_refusal() != &"":
		return false
	if _owner_token == 0 and _installed_witnesses_refusal() != &"":
		return false
	if _final_inventory_refusal(_cold_token, cold_peak_bytes()) != &"":
		return false
	var previous: Bank = _live
	_live = _stage
	_stage = previous
	_last_published_token = token
	_reset_preparation()
	return true


func _world_publication_refusal() -> StringName:
	"""No terrain/source/retention observer follows Space's swap in the actual World commit window."""
	var scope: WorldScope = _actual_world_scope()
	if not _world_scope_current(scope, _cold_token, _owner_token):
		return &"LOCATION_WORLD_SCOPE"
	_in_retention = true
	_retention_reentered = false
	var publishing: bool = scope.is_publishing(_owner_token, _cold_token)
	_in_retention = false
	if not publishing or _retention_reentered or not _world_scope_current(scope, _cold_token, _owner_token):
		return &"LOCATION_WORLD_SCOPE"
	var code: StringName = _published_owner_refusal()
	return _world_rows_refusal() if code == &"" else code


func _publication_geometry_refusal() -> StringName:
	"""Future numeric revisions cannot substitute another transaction's actual owner receipt."""
	if _room_admission:
		return _room_publication_refusal()
	if _owner_token == 0:
		return _geometry_current_refusal()
	var physical: Sites = _physical()
	if physical == null or not physical.is_publishing_spatial_transition(physical.origin_of(_site),
			_operation, _phase_stage, physical.room_of(_site), physical.bound_spatial_authority()):
		return &"LOCATION_SITE_PHASE"
	return _published_owner_refusal()


func _published_owner_refusal() -> StringName:
	"""Final callback-free exact receipt and generation checks precede either candidate bank swap."""
	return &"" if not _owner.has_prepared() and _owner.revision() == _target_geometry_revision \
		and _owner.last_published_token() == _owner_token and world_ref() != NULL_REF else &"LOCATION_GEOMETRY_STALE"


func _room_publication_refusal() -> StringName:
	"""No direct call or old Room callback may publish a retained endpoint proof."""
	var orders: RoomOrders = _actual_orders()
	if orders == null or orders != _buildings.spatial_authority() or not _cold.covers(_cold_token, Budget.COLD_BYTES):
		return &"LOCATION_ROOM_SCOPE"
	_in_retention = true
	_retention_reentered = false
	var code: StringName = orders.room_companion_refusal(_admission_room, _admission_type,
		_owner_token, _cold_token, _owner, _cold)
	if code == &"" and not orders.is_publishing_room_admission(_admission_room, _admission_type):
		code = &"LOCATION_ROOM_SCOPE"
	_in_retention = false
	if _retention_reentered or not _cold.covers(_cold_token, Budget.COLD_BYTES):
		return &"LOCATION_ROOM_SCOPE"
	if code == &"":
		code = _refreshed_room_rows_refusal()
	return _published_owner_refusal() if code == &"" else code


func _reset_preparation() -> void:
	"""Clear transient scope without changing live rows or another owner's lease."""
	_token = 0
	_cold_token = 0
	_owner_token = 0
	_site = NULL_REF
	_operation = -1
	_phase_stage = -1
	_base_geometry_revision = 0
	_target_geometry_revision = 0
	_sealed = false
	_snapshot = null
	_room_admission = false
	_admission_room = NULL_REF
	_admission_type = -1
	_world_preparation = false


func _editable(token: int) -> StringName:
	"""Every mutable operation belongs to this actual owner and one active cold candidate."""
	if _reject_retention_callback():
		return &"LOCATION_RETENTION_REENTRY"
	if token <= 0 or token != _token or _sealed or not _cold.covers(_cold_token, cold_peak_bytes()):
		return &"LOCATION_TOKEN_STALE"
	if _installation_active():
		return installation_scope_refusal(self, _installation)
	if _world_preparation:
		return _world_preflight(_actual_world_scope(), _cold_token, _owner_token)
	return _room_preflight(_actual_orders(), _cold_token, _owner_token, _admission_room,
		_admission_type, false) if _room_admission else &""


func _geometry_current_refusal() -> StringName:
	"""Prepared spatial truth is immutable; live preparations retain their starting world revision."""
	if _room_admission:
		return _room_preflight(_actual_orders(), _cold_token, _owner_token, _admission_room, _admission_type)
	if _world_preparation:
		return _world_preflight(_actual_world_scope(), _cold_token, _owner_token)
	if _installation_active():
		var code: StringName = installation_scope_refusal(self, _installation)
		if code == &"":
			code = _owner.prepared_refusal(_owner_token)
		return installation_scope_refusal(self, _installation) if code == &"" else code
	if _owner_token != 0:
		return _owner.prepared_refusal(_owner_token)
	if _owner.has_prepared() or _base_geometry_revision != _owner.revision():
		return &"LOCATION_GEOMETRY_STALE"
	return &""


func _validate_record(record: Record) -> StringName:
	"""World observations cannot mutate their caller input or reenter the retained endpoint candidate."""
	if not _world_preparation and not _installation_active():
		return _record_geometry_refusal(record)
	var scope: WorldScope = _actual_world_scope()
	if record == null or not _record_scope_current(scope):
		return &"LOCATION_WORLD_SCOPE"
	if record.envelope.size() != 6 or record.support.size() != 6:
		return &"LOCATION_GEOMETRY_FORMAT"
	var pinned: Record = _copy_world_record(record)
	_in_retention = true
	_retention_reentered = false
	var code: StringName = _record_geometry_refusal(pinned)
	_in_retention = false
	if _retention_reentered or not _record_scope_current(scope) \
			or _owner._stage_token != _owner_token or not _owner._sealed:
		return &"LOCATION_WORLD_SCOPE"
	if not _world_record_matches(record, pinned):
		return &"LOCATION_REQUEST_CHANGED"
	return code


func _record_scope_current(scope: WorldScope) -> bool:
	"""Both publication contexts require the exact current original lease before copied caller geometry."""
	return installation_scope_refusal(self, _installation) == &"" if _installation_active() \
		else _world_scope_current(scope, _cold_token, _owner_token)


func _copy_world_record(record: Record) -> Record:
	"""Pin mutable caller geometry only after exact cold admission, without retaining another owner image."""
	var pinned: Record = Record.new()
	pinned.point = record.point
	pinned.room = record.room
	pinned.section = record.section
	pinned.level = record.level
	pinned.role = record.role
	pinned.envelope = record.envelope.duplicate()
	pinned.support = record.support.duplicate()
	return pinned


func _world_record_matches(record: Record, pinned: Record) -> bool:
	"""Compare every caller input used by validation or row publication after the last source observer."""
	return record.point == pinned.point and record.room == pinned.room and record.section == pinned.section \
		and record.level == pinned.level and record.role == pinned.role \
		and record.envelope == pinned.envelope and record.support == pinned.support


func _record_geometry_refusal(record: Record) -> StringName:
	"""Exact integer coverage and source identity qualify geometry, not movement or storage contents."""
	if record == null or not Space.valid_box(record.envelope) or not Space.valid_box(record.support) \
			or record.level < 0 or record.role < ROLE_TRANSIT or record.role > ROLE_WORK \
			or not Space.contains_box(_domain._bounds, record.envelope) \
			or not Space.contains_box(_domain._bounds, record.support):
		return &"LOCATION_GEOMETRY_FORMAT"
	for axis: int in 3:
		if record.point[axis] < record.envelope[axis] or record.point[axis] >= record.envelope[axis + 3]:
			return &"LOCATION_POINT_OUTSIDE"
	if record.support[4] != record.envelope[1] or record.support[0] > record.envelope[0] \
			or record.support[2] > record.envelope[2] or record.support[3] < record.envelope[3] \
			or record.support[5] < record.envelope[5] or record.point.y != record.envelope[1]:
		return &"LOCATION_SUPPORT_GEOMETRY"
	var code: StringName = _section_refusal(record)
	if code == &"":
		code = _survey_for(record)
	if code != &"":
		return code
	var rows: Space.Volumes = _snapshot.volumes
	for row: int in rows.role.size():
		if not _spend():
			return &"LOCATION_OPERATION_BUDGET"
		if rows.role[row] in [Space.DRY_SOLID, Space.OBSTACLE, Space.PROTECTED_ACCESS, Space.SUPPORT, Space.OPENABLE_SHELL,
				Space.WATER, Space.RESOURCE, Space.OCCUPANT, Space.UNFINISHED] and Space.overlaps(record.envelope, rows.box_at(row)):
			return &"LOCATION_ENVELOPE_BLOCKED"
	if not _covered(record.envelope, Space.SUPPORTED_VOID) or not _covered(record.support, Space.SUPPORT):
		return &"LOCATION_COVERAGE_MISSING" if _remaining >= 0 else &"LOCATION_OPERATION_BUDGET"
	return &""


func _section_refusal(record: Record) -> StringName:
	"""World surface and actual underground Room sections are disjoint identity domains."""
	var code: StringName = _read_section(record.section)
	if code != &"" or _region.role != Space.FLOOR_DATUM or _region.claim_kind != Owner.CLAIM_NONE \
			or _region.level != record.level or _region.box[1] != record.point.y:
		return &"LOCATION_SECTION_STALE"
	if record.room == NULL_REF:
		if _region.owner != _world or record.level != 0:
			return &"LOCATION_SURFACE_IDENTITY"
	else:
		var kind: Buildings.OpResult = _buildings.spatial_kind_of_room(record.room)
		if not kind.ok or kind.value != Buildings.ROOM_SPACE_UNDERGROUND or _region.owner != record.room:
			return &"LOCATION_ROOM_STALE"
	if record.role == ROLE_TRANSIT:
		return &"" if record.point.x >= _region.box[0] and record.point.x < _region.box[3] \
			and record.point.z >= _region.box[2] and record.point.z < _region.box[5] else &"LOCATION_SECTION_CONTAINMENT"
	if record.envelope[0] < _region.box[0] or record.envelope[2] < _region.box[2] \
			or record.envelope[3] > _region.box[3] or record.envelope[5] > _region.box[5]:
		return &"LOCATION_SECTION_CONTAINMENT"
	return &""


func _read_section(section: Vector2i) -> StringName:
	"""The World path brackets a reused pure row observation with its complete source preflight and leased image."""
	if _world_preparation or _installation_active():
		_region.box.resize(6)
		return _owner.prepared_region_observation_into(_owner_token, section, _region)
	return _owner.prepared_region_into(_owner_token, section, _region) \
		if _owner_token != 0 else _owner.region_into(section, _region)


func _survey_for(record: Record) -> StringName:
	"""Transit omits only nonphysical Room markers; underground endpoints still need their actual Sites/Room key."""
	_snapshot = null # Release a prior survey before requesting the next isolated image.
	var physical: Sites = _physical()
	var site: Vector2i = NULL_REF
	if record.room != NULL_REF:
		site = _observed_record_site(record, physical)
		if site == NULL_REF: return &"LOCATION_PAID_SITE_MISSING"
		var scope: StringName = _owner.site_scope_refusal(physical, site)
		if scope != &"":
			return scope
	if _world_preparation and not _world_scope_current(_actual_world_scope(), _cold_token, _owner_token):
		return &"LOCATION_WORLD_SCOPE"
	var image: Space.Snapshot = Space.Snapshot.new()
	var code: StringName = _snapshot_for_into(record, physical, site, image)
	if code == &"":
		_snapshot = image
	return code


func _observed_record_site(record: Record, physical: Sites) -> Vector2i:
	"""Keep ordinary Site observations and domain refusals while recognizing installed datums before their lookup."""
	var installed: int = _installed_record_kind(record)
	if installed < 0: return NULL_REF
	if installed > 0: return _installed_surface_site(record, physical)
	var site: Vector2i = physical.site_at(_cube_origin(record.point)) if physical != null else NULL_REF
	return site if site != NULL_REF and physical.room_of(site) == record.room else NULL_REF


func _snapshot_for_into(record: Record, physical: Sites, site: Vector2i, image: Space.Snapshot) -> StringName:
	"""Select the exact existing claim predicate without changing scope, allocating another image or post-filtering."""
	if _world_preparation:
		return _owner.prepared_snapshot_leased_into(_owner_token, image, _cold, _cold_token)
	if _installation_active():
		return _installation_snapshot_into(record, physical, site, image)
	if record.role == ROLE_TRANSIT:
		return _owner.prepared_snapshot_for_traversal_into(_owner_token, image) \
			if _owner_token != 0 else _owner.snapshot_for_traversal_into(image)
	if record.room == NULL_REF:
		return _owner.prepared_snapshot_into(_owner_token, image) if _owner_token != 0 else _owner.snapshot_into(image)
	return _owner.prepared_snapshot_for_site_into(_owner_token, image, physical, site) \
		if _owner_token != 0 else _owner.snapshot_for_site_into(image, physical, site)


func _installation_snapshot_into(record: Record, physical: Sites, site: Vector2i,
		image: Space.Snapshot) -> StringName:
	"""Leased typed predicates preserve real paid Site proof and every non-exempt physical blocker."""
	if installation_scope_refusal(self, _installation) != &"":
		return &"LOCATION_INSTALLATION_CONTEXT"
	if record.role == ROLE_TRANSIT:
		return _owner.prepared_snapshot_for_traversal_leased_into(_owner_token, image, _cold, _cold_token)
	if record.room != NULL_REF:
		return _owner.prepared_snapshot_for_site_leased_into(_owner_token, image, physical, site, _cold, _cold_token)
	return _owner.prepared_snapshot_leased_into(_owner_token, image, _cold, _cold_token)


func _covered(box: PackedInt32Array, role: int) -> bool:
	"""Exact disjoint subtraction detects interior holes; sampled corners are insufficient."""
	var pending: Array[PackedInt32Array] = [box]
	var rows: Space.Volumes = _snapshot.volumes
	for row: int in rows.role.size():
		if not _spend():
			return false
		if rows.role[row] != role:
			continue
		var next: Array[PackedInt32Array] = []
		for fragment: PackedInt32Array in pending:
			if not _spend() or not _subtract(fragment, rows.box_at(row), next):
				return false
		pending = next
		if pending.is_empty():
			return true
	return false


func _subtract(box: PackedInt32Array, cover: PackedInt32Array, out: Array[PackedInt32Array]) -> bool:
	"""Six half-open outside slabs retain exact integer coverage with a bounded fragment arena."""
	if not Space.overlaps(box, cover):
		return _append_fragment(out, box)
	var cut: PackedInt32Array = Space.intersection(box, cover)
	var core: PackedInt32Array = box.duplicate()
	for axis: int in 3:
		if core[axis] < cut[axis]:
			var before: PackedInt32Array = core.duplicate()
			before[axis + 3] = cut[axis]
			if not _append_fragment(out, before):
				return false
			core[axis] = cut[axis]
		if core[axis + 3] > cut[axis + 3]:
			var after: PackedInt32Array = core.duplicate()
			after[axis] = cut[axis + 3]
			if not _append_fragment(out, after):
				return false
			core[axis + 3] = cut[axis + 3]
	return true


func _append_fragment(out: Array[PackedInt32Array], box: PackedInt32Array) -> bool:
	"""Two fragment lists together consume at most 24K packed bytes in the shared cold envelope."""
	@warning_ignore("integer_division") var limit: int = maxi(1, _domain._regions / 2)
	if out.size() >= limit:
		_remaining = -1
		return false
	out.append(box)
	return true


func _spend(checks: int = 1) -> bool:
	"""The complete edit shares one comparison budget; later records do not reset it."""
	if checks < 0 or checks > _remaining:
		_remaining = -1
		return false
	_remaining -= checks
	return true


func _physical() -> Sites:
	"""A weak Sites link prevents an Inventory/geometry/publication ownership cycle."""
	return _sites.get_ref() as Sites if _sites != null else null


func _cube_origin(point: Vector3i) -> Vector3i:
	"""Use the immutable paid-cube datum; this looks up an existing key and creates no cut."""
	var out: Vector3i = Vector3i.ZERO
	for axis: int in 3:
		out[axis] = _domain._datum[axis] + _floor_div(int(point[axis]) - _domain._datum[axis], Space.QUANTUM_U) * Space.QUANTUM_U
	return out


static func installed_prism_into(issuer: RefCounted, row: int, ordinal: int, out: PackedInt32Array) -> StringName:
	"""Pure geometry observation for the guarded installation owner; only complete horizontal rectangles are represented."""
	if issuer == null or out.size() != 6 or row < 0 or row >= issuer._capacity or issuer._live.present[row] != 1:
		return &"LOCATION_INSTALLED_PART"
	var catalog: ConnectorCatalog = issuer._catalog
	var selected: int = issuer._live.i32[issuer.CATALOG_ROW * issuer._capacity + row]
	if selected < 0 or ordinal < 0 or ordinal >= catalog._live.variants[ConnectorCatalog.V_PART_COUNT * ConnectorCatalog.MAX_VARIANTS + selected]:
		return &"LOCATION_INSTALLED_PART"
	var part: int = catalog._live.variants[ConnectorCatalog.V_PART_START * ConnectorCatalog.MAX_VARIANTS + selected] + ordinal
	if catalog._live.parts[part] == ConnectorCatalog.Geometry.HATCH or catalog._live.parts[8 * ConnectorCatalog.MAX_PARTS + part] != 4:
		return &"LOCATION_INSTALLED_PRISM_SUBSET"
	var first: int = catalog._live.parts[7 * ConnectorCatalog.MAX_PARTS + part]
	var low: Vector3i = Vector3i(catalog._live.vertices[first], catalog._live.vertices[ConnectorCatalog.MAX_VERTICES + first],
		catalog._live.vertices[2 * ConnectorCatalog.MAX_VERTICES + first])
	var high: Vector3i = low
	for index: int in range(first + 1, first + 4):
		if catalog._live.vertices[ConnectorCatalog.MAX_VERTICES + index] != low.y: return &"LOCATION_INSTALLED_PRISM_SUBSET"
		low.x = mini(low.x, catalog._live.vertices[index])
		low.z = mini(low.z, catalog._live.vertices[2 * ConnectorCatalog.MAX_VERTICES + index])
		high.x = maxi(high.x, catalog._live.vertices[index])
		high.z = maxi(high.z, catalog._live.vertices[2 * ConnectorCatalog.MAX_VERTICES + index])
	if not _installed_rectangle(catalog, first, low, high): return &"LOCATION_INSTALLED_PRISM_SUBSET"
	low.y -= catalog._live.parts[ConnectorCatalog.MAX_PARTS + part]
	return _installed_world_box(issuer, row, low, high, out)


func _installed_surface_site(record: Record, physical: Sites) -> Vector2i:
	"""A real installed prism and exact Catalog datum may locate its paid lower cube; arbitrary y-minus-one cannot."""
	if physical == null or _installation == null or _installation.issuer == null or not _spend(1024): return NULL_REF
	var issuer: RefCounted = _installation.issuer.get_ref()
	if not _installed_sources_current(issuer): return NULL_REF
	if _installation_active() and installation_scope_refusal(self, _installation) != &"": return NULL_REF
	var found: Vector2i = NULL_REF
	var matches: int = 0
	for row: int in issuer._capacity:
		if not _spend(32): return NULL_REF
		if issuer._live.present[row] != 1 or issuer._live.i32[issuer.ROOM_SLOT * issuer._capacity + row] != record.room.x \
				or issuer._live.i32[(issuer.ROOM_SLOT + 1) * issuer._capacity + row] != record.room.y: continue
		var prefix: int = issuer._live.i32[issuer.INSTALLED * issuer._capacity + row]
		if _installation_active() and _installation.placement == Vector2i(row, issuer._live.i32[row]):
			if issuer._prepared_placement != _installation.placement or issuer._prepared_assembly != prefix \
					or issuer._space_token != _owner_token or issuer._cold_token != _cold_token: return NULL_REF
			prefix += 1
		if prefix < 1 or prefix > issuer._assemblies._header[5]: continue
		var site: Vector2i = _installed_row_site(issuer, row, prefix, record, physical)
		if site != NULL_REF:
			found = site
			matches += 1
	return found if matches == 1 and _installed_sources_current(issuer) else NULL_REF


func _record_paid_site(record: Record, physical: Sites) -> Vector2i:
	"""A Catalog landing needs its installed prism even when its fractional root lies inside a completed cube."""
	var installed: int = _installed_record_kind(record)
	if installed < 0: return NULL_REF
	if installed > 0: return _installed_surface_site(record, physical)
	var row: int = _installed_site_row(physical, _cube_origin(record.point))
	return Vector2i(row, Sites.SITE_GENERATION) if row >= 0 and physical._room_slot[row] == record.room.x \
		and physical._room_generation[row] == record.room.y else NULL_REF


func _installed_record_kind(record: Record) -> int:
	"""Derive the witness from current immutable LANDING geometry; no saved flag or cube-height inference applies."""
	if _installation == null: return 0
	var issuer: RefCounted = _installation.issuer.get_ref() if _installation.issuer != null else null
	if issuer == null or not _spend(1024): return -1
	var matches: int = 0
	var current: bool = false
	for row: int in issuer._capacity:
		if not _spend(32): return -1
		if issuer._live.present[row] != 1 or issuer._live.i32[issuer.ROOM_SLOT * issuer._capacity + row] != record.room.x \
				or issuer._live.i32[(issuer.ROOM_SLOT + 1) * issuer._capacity + row] != record.room.y: continue
		if not current:
			if not _installed_sources_current(issuer): return -1
			current = true
		if not _installed_row_source(issuer, row, record.room): return -1
		var count: int = _installed_landing_count(issuer, row, record)
		if count < 0: return -1
		matches += count
	if matches > 1 or (matches == 1 and not _installed_future_context(issuer)): return -1
	return matches


func _installed_future_context(issuer: RefCounted) -> bool:
	"""Only preflighted World or static paid/Room companions may refresh installed endpoints with future Space."""
	if _owner_token == 0: return true
	if _owner._stage_token != _owner_token or not _owner._sealed: return false
	if _world_preparation: return true
	if _installation_active(): return installation_scope_refusal(self, _installation) == &""
	return _room_admission and issuer._admission_mode and issuer._admission_context.location_token == _token \
		and room_scope_leaf_refusal(self, issuer._admission_context) == &""


func _installed_sources_current(issuer: RefCounted) -> bool:
	"""Read actual immutable source banks and original owner identity directly, never an overridable permission hook."""
	if issuer == null or issuer._locations != self or issuer._space != _owner or issuer._sources != _sources \
			or issuer._budget != _cold or issuer._world != _world or issuer._construction != _sources._construction \
			or issuer._context != _installation or not issuer._configured or issuer._live.header.size() != 16 \
			or issuer._live.digests.size() != 128 or issuer._catalog == null or issuer._assemblies == null or issuer._recipes == null \
			or not _installed_actual_wiring(issuer):
		return false
	var groups: RefCounted = issuer._assemblies
	var recipes: RefCounted = issuer._recipes
	if not groups._loaded or groups._busy or not recipes._loaded or recipes._busy or groups._catalog != issuer._catalog \
			or groups._recipes != recipes or recipes._catalog != issuer._catalog or groups._inventory != _inventory \
			or recipes._inventory != _inventory or groups._header[0] != issuer._live.header[issuer.H_GROUP_REV] \
			or recipes._header[0] != issuer._live.header[issuer.H_RECIPE_REV] or groups._header[5] != issuer._live.header[issuer.H_GROUP_COUNT]:
		return false
	for index: int in 32:
		if groups._digests[index] != issuer._live.digests[32 + index] \
				or recipes._digests[index] != issuer._live.digests[64 + index] \
				or groups._digests[32 + index] != issuer._live.digests[index] \
				or recipes._digests[32 + index] != issuer._live.digests[index] \
				or recipes._digests[64 + index] != groups._digests[index]: return false
	return ConnectorFacts.refusal(issuer._catalog, issuer._live.header[issuer.H_CATALOG_ROW],
		issuer._live.header[issuer.H_VARIANT_REV], issuer._live.header[issuer.H_CATALOG_REV], issuer._live.digests) == &""


func _installed_actual_wiring(p: RefCounted) -> bool:
	"""The installed-source witness uses the original actual route/profile/terrain namespace, not matching numbers."""
	var routes: RefCounted = _sources._locations
	var provider: RefCounted = p._world_routes
	if routes == null or provider == null or p._ids != _ids or p._buildings != _buildings \
			or p._inventory != _inventory or p._transforms != _transforms or p._routes != routes: return false
	return routes._locations == self and routes._owner == _owner and routes._sources == _sources \
		and routes._cold == _cold and routes._world == _world and routes._bindings == provider \
		and routes._profiles == p._profiles and p._catalog._profiles == p._profiles \
		and p._profiles._inventory == _inventory and p._profiles._transforms == _transforms \
		and p._profiles._residents == routes._residents and p._profiles._work == routes._work \
		and p._profiles._gear == p._gear and p._profiles._carry == p._carry \
		and p._profiles._reservations == p._reservations and p._profiles._piles == p._piles \
		and provider._catalog == p._catalog and provider._profiles == p._profiles \
		and provider._levels == p._catalog._levels and provider._movement == p._catalog._movement \
		and provider._locations_ref != null and provider._locations_ref.get_ref() == self \
		and provider._owner_ref != null and provider._owner_ref.get_ref() == _owner \
		and provider._sources_ref != null and provider._sources_ref.get_ref() == _sources \
		and provider._routes_ref != null and provider._routes_ref.get_ref() == routes \
		and provider._budget == _cold and _resolve_domain_matches() \
		and _resolve_domain_matches(provider._domain) and _resolve_domain_matches(routes._domain)


func _installed_row_source(p: RefCounted, row: int, room: Vector2i) -> bool:
	"""An unrelated stale Placement is never laundered into a supported endpoint by the current operation."""
	var section: Vector2i = Vector2i(p._live.i32[p.SECTION_SLOT * p._capacity + row],
		p._live.i32[(p.SECTION_SLOT + 1) * p._capacity + row])
	return _owner._region_live(section, false) and _ids.is_valid_of_kind(room, Directory.KIND_ROOM) \
		and _owner._r_owner_slot[section.x] == room.x and _owner._r_owner_generation[section.x] == room.y \
		and _owner._r_role[section.x] == Space.FLOOR_DATUM \
		and _owner._r_level[section.x] == p._live.i32[p.LEVEL * p._capacity + row] \
		and _owner._r_owner_revision[section.x] == p._live.i64[p.ROOM_REVISION * p._capacity + row]


func _installed_row_site(issuer: RefCounted, row: int, prefix: int, record: Record, physical: Sites) -> Vector2i:
	"""The exact stored FLOOR_DATUM must equal one authored landing of this full live Placement."""
	if not _installed_row_source(issuer, row, record.room) or _installed_landing_count(issuer, row, record) != 1: return NULL_REF
	var found: Vector2i = NULL_REF
	for group: int in prefix:
		var part_first: int = issuer._assemblies._first_part[group]
		for part: int in range(part_first, part_first + issuer._assemblies._part_count[group]):
			if not _spend(96): return NULL_REF
			if installed_prism_into(issuer, row, part, _region.box) != &"": return NULL_REF
			if _region.box[4] != record.point.y or record.point.x < _region.box[0] or record.point.x >= _region.box[3] \
					or record.point.z < _region.box[2] or record.point.z >= _region.box[5]: continue
			var site: Vector2i = _installed_part_site(record, physical)
			if site == NULL_REF or (found != NULL_REF and found != site): return NULL_REF
			found = site
	return found


func _installed_landing_count(issuer: RefCounted, row: int, record: Record) -> int:
	"""An exact authored landing is recognized before either prefix or ordinary Site fallback is considered."""
	var catalog: ConnectorCatalog = issuer._catalog
	var variant: int = issuer._live.i32[issuer.CATALOG_ROW * issuer._capacity + row]
	var first: int = catalog._live.variants[ConnectorCatalog.V_REGION_START * ConnectorCatalog.MAX_VARIANTS + variant]
	var count: int = catalog._live.variants[ConnectorCatalog.V_REGION_COUNT * ConnectorCatalog.MAX_VARIANTS + variant]
	var matched: int = 0
	for index: int in count:
		if not _spend(32): return -1
		var at: int = first + index
		if catalog._live.regions[6 * ConnectorCatalog.MAX_REGIONS + at] != Space.LANDING: continue
		if _installed_datum_matches(issuer, row, at, record): matched += 1
	return matched


func _installed_datum_matches(issuer: RefCounted, row: int, at: int, record: Record) -> bool:
	"""Both live and exact prepared metadata compare full owner/generation, authored level and all six world bounds."""
	var catalog: ConnectorCatalog = issuer._catalog
	var level: int = issuer._live.i32[issuer.LEVEL * issuer._capacity + row] + catalog._live.regions[7 * ConnectorCatalog.MAX_REGIONS + at]
	if record.level != level or not _owner._region_live(record.section, _owner_token > 0): return false
	for axis: int in 3:
		var a: int = installed_coordinate(issuer, row, catalog._live.regions[at], catalog._live.regions[ConnectorCatalog.MAX_REGIONS + at],
			catalog._live.regions[2 * ConnectorCatalog.MAX_REGIONS + at], axis)
		var b: int = installed_coordinate(issuer, row, catalog._live.regions[3 * ConnectorCatalog.MAX_REGIONS + at],
			catalog._live.regions[4 * ConnectorCatalog.MAX_REGIONS + at], catalog._live.regions[5 * ConnectorCatalog.MAX_REGIONS + at], axis)
		if mini(a, b) != _installed_section_bound(record.section.x, axis) \
				or maxi(a, b) != _installed_section_bound(record.section.x, axis + 3): return false
	return true


func _installed_section_bound(row: int, axis: int) -> int:
	"""Read the already-full-generation-validated metadata directly, unaffected by reused prism scratch."""
	match axis:
		0: return _owner._s_r_lo_x[row] if _owner_token > 0 else _owner._r_lo_x[row]
		1: return _owner._s_r_lo_y[row] if _owner_token > 0 else _owner._r_lo_y[row]
		2: return _owner._s_r_lo_z[row] if _owner_token > 0 else _owner._r_lo_z[row]
		3: return _owner._s_r_hi_x[row] if _owner_token > 0 else _owner._r_hi_x[row]
		4: return _owner._s_r_hi_y[row] if _owner_token > 0 else _owner._r_hi_y[row]
		_: return _owner._s_r_hi_z[row] if _owner_token > 0 else _owner._r_hi_z[row]


func _installed_part_site(record: Record, physical: Sites) -> Vector2i:
	"""Only the source prism's genuine positive thickness selects this exact completed same-Room paid cube."""
	if _region.box[1] >= record.point.y or _region.box[4] != record.point.y: return NULL_REF
	var origin: Vector3i = _cube_origin(Vector3i(record.point.x, record.point.y - 1, record.point.z))
	var row: int = _installed_site_row(physical, origin)
	if row < 0 or physical._phase[row] != Sites.SUPPORTED_VOID \
			or physical._room_slot[row] != record.room.x or physical._room_generation[row] != record.room.y: return NULL_REF
	return Vector2i(row, Sites.SITE_GENERATION)


func _installed_witnesses_refusal() -> StringName:
	"""After all observers, rederive every candidate installed witness from current source and paid columns only."""
	if _installation == null: return &""
	if not _spend(64): return &"LOCATION_OPERATION_BUDGET"
	var physical: Sites = _physical()
	for row: int in _capacity:
		if not _spend(): return &"LOCATION_OPERATION_BUDGET"
		if _stage.present[row] != 1 or _ref_at(_stage, ROOM_SLOT, row) == NULL_REF: continue
		if not _spend(_owner._source_capacity + 104): return &"LOCATION_OPERATION_BUDGET"
		_record.point = Vector3i(_get32(_stage, X, row), _get32(_stage, Y, row), _get32(_stage, Z, row))
		_record.room = _ref_at(_stage, ROOM_SLOT, row)
		_record.section = _ref_at(_stage, SECTION_SLOT, row)
		_record.level = _get32(_stage, LEVEL, row)
		var source: int = _resolve_source_row(_record.room)
		if source < 0 or _resolve_room_source_refusal(_record.room, source) != &"": return &"LOCATION_SOURCE_STALE"
		if _record_paid_site(_record, physical) == NULL_REF:
			return &"LOCATION_OPERATION_BUDGET" if _remaining < 0 else &"LOCATION_PAID_SITE_MISSING"
	return &""


func _installed_site_row(physical: Sites, origin: Vector3i) -> int:
	"""Pure exact paid-key lookup validates the actual immutable Domain and reverse index, without a Site observer."""
	if not _spend(64) or not _installed_sites_current(physical): return -1
	var x: int = _floor_div(int(origin.x) - _domain._datum.x, 1024) - _domain._min_quantum.x
	var y: int = _floor_div(int(origin.y) - _domain._datum.y, 1024) - _domain._min_quantum.y
	var z: int = _floor_div(int(origin.z) - _domain._datum.z, 1024) - _domain._min_quantum.z
	if x < 0 or x >= _domain._size_quanta.x or y < 0 or y >= _domain._size_quanta.y \
			or z < 0 or z >= _domain._size_quanta.z: return -1
	var key: int = (y * _domain._size_quanta.z + z) * _domain._size_quanta.x + x
	var low: int = 0
	var high: int = physical._count
	while low < high:
		@warning_ignore("integer_division") var middle: int = low + (high - low) / 2
		if physical._ordered_key[middle] < key: low = middle + 1
		else: high = middle
	if low >= physical._count or physical._ordered_key[low] != key: return -1
	var row: int = physical._ordered_row[low]
	return row if row >= 0 and row < physical._count and physical._present[row] == 1 \
		and physical._site_key[row] == key else -1


func _installed_sites_current(physical: Sites) -> bool:
	"""No same-number foreign World, Domain or reconfigured Site owner can replace the original physical witness."""
	return physical != null and physical._ready_error == &"" and physical._construction == _sources._construction \
		and physical._inventory == _inventory and physical._construction._excavation_authority != null \
		and physical._construction._excavation_authority.get_ref() == physical and physical._domain.world_ref == _world \
		and physical._domain.datum_u == _domain._datum and physical._domain.minimum_quantum == _domain._min_quantum \
		and physical._domain.size_quanta == _domain._size_quanta and _ids.is_valid_of_kind(_world, Directory.KIND_WORLD)


static func _installed_rectangle(catalog: ConnectorCatalog, first: int, low: Vector3i, high: Vector3i) -> bool:
	"""Every corner appears exactly once and every edge is axis aligned; a convex envelope cannot replace the real solid."""
	if low.x >= high.x or low.z >= high.z: return false
	var mask: int = 0
	for index: int in 4:
		var x: int = catalog._live.vertices[first + index]
		var z: int = catalog._live.vertices[2 * ConnectorCatalog.MAX_VERTICES + first + index]
		if (x != low.x and x != high.x) or (z != low.z and z != high.z): return false
		var bit: int = 1 << (int(x == high.x) + 2 * int(z == high.z))
		if (mask & bit) != 0: return false
		mask |= bit
		var next: int = first + (index + 1) % 4
		if x != catalog._live.vertices[next] and z != catalog._live.vertices[2 * ConnectorCatalog.MAX_VERTICES + next]: return false
	return mask == 15


static func installed_coordinate(issuer: RefCounted, row: int, x: int, y: int, z: int, axis: int) -> int:
	"""Signed int64 rotation precedes narrowing; placement translation never changes authored rise or part size."""
	var rotation: int = issuer._live.i32[issuer.ROTATION * issuer._capacity + row]
	var origin: int = issuer._live.i32[(issuer.X + axis) * issuer._capacity + row]
	if axis == 1: return origin + y
	if axis == 0: return origin + (x if rotation == 0 else -z if rotation == 1 else -x if rotation == 2 else z)
	return origin + (z if rotation == 0 else x if rotation == 1 else -z if rotation == 2 else -x)


static func _installed_world_box(issuer: RefCounted, row: int, low: Vector3i, high: Vector3i, out: PackedInt32Array) -> StringName:
	"""Validate the whole world extent before touching caller-owned scratch."""
	for axis: int in 3:
		var a: int = installed_coordinate(issuer, row, low.x, low.y, low.z, axis)
		var b: int = installed_coordinate(issuer, row, high.x, high.y, high.z, axis)
		if not Space.int32(a) or not Space.int32(b) or a == b \
				or mini(a, b) < issuer._space._domain._bounds[axis] or maxi(a, b) > issuer._space._domain._bounds[axis + 3]:
			return &"LOCATION_INSTALLED_PART_BOUNDS"
	for axis: int in 3:
		var a: int = installed_coordinate(issuer, row, low.x, low.y, low.z, axis)
		var b: int = installed_coordinate(issuer, row, high.x, high.y, high.z, axis)
		out[axis] = mini(a, b)
		out[axis + 3] = maxi(a, b)
	return &""


static func _floor_div(value: int, denominator: int) -> int:
	"""All operands are bounded int32 differences; negative coordinates need mathematical floor."""
	@warning_ignore("integer_division") var result: int = value / denominator
	return result - 1 if value < 0 and value % denominator != 0 else result


static func _cell(value: int, datum: int) -> int:
	"""No storage endpoint can be rounded into another room or floor."""
	return _floor_div(value - datum, STORAGE_CELL_U)


func _live_ref(bank: Bank, ref: Vector2i) -> bool:
	"""Local namespace validation always compares presence and generation."""
	return ref.x >= 0 and ref.x < _capacity and ref.y > 0 and bank.present[ref.x] == 1 \
		and bank.i32[GENERATION * _capacity + ref.x] == ref.y


func _get32(bank: Bank, field: int, row: int) -> int:
	"""Field-major packed integer lookup has no allocation or entity object."""
	return bank.i32[field * _capacity + row]


func _set32(bank: Bank, field: int, row: int, value: int) -> void:
	"""Every authoritative narrowing follows validated integer input."""
	bank.i32[field * _capacity + row] = value


func _get64(bank: Bank, field: int, row: int) -> int:
	"""Read exact monotone revisions without a float conversion."""
	return bank.i64[field * _capacity + row]


func _set64(bank: Bank, field: int, row: int, value: int) -> void:
	"""Store a checked immutable payload or actual proof revision."""
	bank.i64[field * _capacity + row] = value


func _ref_at(bank: Bank, field: int, row: int) -> Vector2i:
	"""Both halves remain in their explicitly declared namespace."""
	return Vector2i(bank.i32[field * _capacity + row], bank.i32[(field + 1) * _capacity + row])


func _prepare_record_scratch() -> void:
	"""Cold setup alone sizes one reusable packet; hot endpoint reads require caller sizing."""
	_record.envelope.resize(6)
	_record.support.resize(6)


func _read_row(bank: Bank, row: int, out: Record) -> void:
	"""Copy only into already-sized caller buffers; no packed aliases escape either bank."""
	out.point = Vector3i(_get32(bank, X, row), _get32(bank, Y, row), _get32(bank, Z, row))
	out.room = _ref_at(bank, ROOM_SLOT, row)
	out.section = _ref_at(bank, SECTION_SLOT, row)
	out.level = _get32(bank, LEVEL, row)
	out.role = _get32(bank, ROLE, row)
	out.world = _world
	out.payload_revision = _get64(bank, PAYLOAD_REVISION, row)
	out.geometry_revision = _get64(bank, GEOMETRY_REVISION, row)
	for axis: int in 6:
		out.envelope[axis] = _get32(bank, ENVELOPE + axis, row)
		out.support[axis] = _get32(bank, SUPPORT + axis, row)


func _write_row(row: int, record: Record) -> void:
	"""New payload revision is the unique local generation; immutable fields cannot be edited later."""
	for axis: int in 3:
		_set32(_stage, X + axis, row, record.point[axis])
	_set32(_stage, ROOM_SLOT, row, record.room.x)
	_set32(_stage, ROOM_GENERATION, row, record.room.y)
	_set32(_stage, SECTION_SLOT, row, record.section.x)
	_set32(_stage, SECTION_GENERATION, row, record.section.y)
	_set32(_stage, LEVEL, row, record.level)
	_set32(_stage, ROLE, row, record.role)
	for axis: int in 6:
		_set32(_stage, ENVELOPE + axis, row, record.envelope[axis])
		_set32(_stage, SUPPORT + axis, row, record.support[axis])
	_set64(_stage, PAYLOAD_REVISION, row, _get32(_stage, GENERATION, row))
	_set64(_stage, GEOMETRY_REVISION, row, _snapshot.revision)


func _clear_row(bank: Bank, row: int) -> void:
	"""Canonical absent rows retain only their generation and exhaustion marker."""
	bank.present[row] = 0
	for field: int in range(1, I32_FIELDS):
		_set32(bank, field, row, -1 if field in [ROOM_SLOT, SECTION_SLOT] else 0)
	for field: int in I64_FIELDS:
		_set64(bank, field, row, 0)


func _rebuild_order(bank: Bank) -> void:
	"""Canonical local-slot order needs no native comparator or unstable sort."""
	bank.ordered.fill(-1)
	var count: int = 0
	for row: int in _capacity:
		if bank.present[row] == 1:
			bank.ordered[count] = row
			count += 1
	assert(count == bank.count, "validated endpoint count must match packed presence")


func _pop_free(bank: Bank) -> int:
	"""A min-heap makes lowest available slot reuse deterministic."""
	var result: int = bank.free_rows[0]
	bank.free_count -= 1
	var tail: int = bank.free_rows[bank.free_count]
	var index: int = 0
	while index * 2 + 1 < bank.free_count:
		var child: int = index * 2 + 1
		if child + 1 < bank.free_count and bank.free_rows[child + 1] < bank.free_rows[child]:
			child += 1
		if bank.free_rows[child] >= tail:
			break
		bank.free_rows[index] = bank.free_rows[child]
		index = child
	bank.free_rows[index] = tail
	return result


func _push_free(bank: Bank, row: int) -> void:
	"""Return a non-exhausted slot without shifting the whole finite arena."""
	var index: int = bank.free_count
	bank.free_count += 1
	while index > 0:
		@warning_ignore("integer_division") var parent: int = (index - 1) / 2
		if bank.free_rows[parent] < row:
			break
		bank.free_rows[index] = bank.free_rows[parent]
		index = parent
	bank.free_rows[index] = row


func capture_state_into(cold_token: int, out: PackedByteArray) -> StringName:
	"""The caller retains this exact lease while consuming its one empty-to-filled wire image."""
	if _capacity == 0 or _token != 0 or _owner.has_prepared() or not out.is_empty():
		return &"LOCATION_CAPTURE_BUSY"
	if not _cold.covers(cold_token, wire_bytes()):
		return &"LOCATION_COLD_CAPACITY"
	if world_ref() == NULL_REF:
		return &"LOCATION_WORLD_STALE"
	out.resize(wire_bytes())
	var offset: int = 0
	for value: int in _live.header:
		out.encode_s64(offset, value)
		offset += 8
	for value: int in _live.i32:
		out.encode_s32(offset, value)
		offset += 4
	for value: int in _live.i64:
		out.encode_s64(offset, value)
		offset += 8
	for value: int in _live.present:
		out[offset] = value
		offset += 1
	for value: int in _live.retired:
		out[offset] = value
		offset += 1
	return &""


func restore_state_bytes(cold_token: int, bytes: PackedByteArray) -> StringName:
	"""Decode into the inactive bank; malformed, stale or retained-ref changes leave live bytes intact."""
	if _reject_retention_callback() or _capacity == 0 or _token != 0 or _owner.has_prepared() or bytes.size() != wire_bytes():
		return &"LOCATION_IMAGE_SHAPE"
	if not _cold.covers(cold_token, wire_bytes() + cold_peak_bytes()):
		return &"LOCATION_COLD_CAPACITY"
	for index: int in HEADER_FIELDS:
		var value: int = bytes.decode_s64(index * 8)
		if (index != 13 and value != _live.header[index]) or (index == 13 and value < 1):
			return &"LOCATION_IMAGE_HEADER"
		_stage.header[index] = value
	_decode_columns(bytes)
	_remaining = _domain._checks
	_base_geometry_revision = _owner.revision()
	var code: StringName = _loaded_rows_refusal()
	_snapshot = null
	if code == &"": code = _restore_current_refusal(cold_token)
	if code != &"":
		return code
	_rebuild_allocation(_stage)
	var previous: Bank = _live
	_live = _stage
	_stage = previous
	_last_published_token = 0
	return &""


func _restore_current_refusal(cold_token: int) -> StringName:
	"""Final retention observations precede fresh physical/source witnesses and the original lease/Inventory tail."""
	var code: StringName = _current_retention_refusal()
	if code == &"" and (_owner.has_prepared() or _owner.revision() != _base_geometry_revision or world_ref() == NULL_REF):
		code = &"LOCATION_GEOMETRY_STALE"
	if code == &"": code = _installed_witnesses_refusal()
	return _final_inventory_refusal(cold_token, wire_bytes() + cold_peak_bytes()) if code == &"" else code


func _decode_columns(bytes: PackedByteArray) -> void:
	"""Stream fixed-width fields directly into the already allocated replacement bank."""
	var offset: int = HEADER_FIELDS * 8
	for index: int in _stage.i32.size():
		_stage.i32[index] = bytes.decode_s32(offset)
		offset += 4
	for index: int in _stage.i64.size():
		_stage.i64[index] = bytes.decode_s64(offset)
		offset += 8
	for index: int in _capacity:
		_stage.present[index] = bytes[offset]
		offset += 1
	for index: int in _capacity:
		_stage.retired[index] = bytes[offset]
		offset += 1


func _loaded_rows_refusal() -> StringName:
	"""Every live record rechecks complete geometry; unused payload and exhausted generations are canonical."""
	_prepare_record_scratch()
	for row: int in _capacity:
		if not _spend():
			return &"LOCATION_OPERATION_BUDGET"
		var generation: int = _get32(_stage, GENERATION, row)
		if generation < 0 or _stage.present[row] > 1 or _stage.retired[row] > 1 \
				or (_stage.retired[row] == 1 and generation != Space.I32_MAX) \
				or (_stage.present[row] == 0 and generation == Space.I32_MAX and _stage.retired[row] != 1):
			return &"LOCATION_IMAGE_LIFECYCLE"
		var code: StringName = _loaded_retention_refusal(row)
		if code != &"":
			return code
		if _stage.present[row] == 0:
			if not _unused_row_canonical(row):
				return &"LOCATION_IMAGE_UNUSED"
			continue
		if generation < 1 or _stage.retired[row] != 0 \
				or _get64(_stage, PAYLOAD_REVISION, row) != generation \
				or _get64(_stage, GEOMETRY_REVISION, row) < 1 \
				or _get64(_stage, GEOMETRY_REVISION, row) > _owner.revision():
			return &"LOCATION_IMAGE_LIFECYCLE"
		_read_row(_stage, row, _record)
		code = _validate_record(_record)
		if code != &"":
			return code
	return &""


func _row_payload_unchanged(row: int) -> bool:
	"""Compare all immutable live payload fields; proof revision refresh alone never repoints a handle."""
	if _live.present[row] == 0:
		return true
	if _stage.present[row] == 0:
		return false
	for field: int in I32_FIELDS:
		if _get32(_live, field, row) != _get32(_stage, field, row):
			return false
	return true


func _loaded_retention_refusal(row: int) -> StringName:
	"""Never repoint an existing full handle; cold load cannot erase a retained real endpoint."""
	if _row_payload_unchanged(row):
		return &""
	if _stage.present[row] == 1 and _get32(_live, GENERATION, row) == _get32(_stage, GENERATION, row):
		return &"LOCATION_IMMUTABLE_PAYLOAD"
	var location: Vector2i = Vector2i(row, _get32(_live, GENERATION, row))
	return _route_retention_refusal(location)


func _final_inventory_refusal(cold_token: int, bytes: int) -> StringName:
	"""No observer executes after this final pass, including one that retained an earlier changed row."""
	if not _cold.covers(cold_token, bytes):
		return &"LOCATION_COLD_CAPACITY"
	for row: int in _capacity:
		if _row_payload_unchanged(row):
			continue
		var location: Vector2i = Vector2i(row, _get32(_live, GENERATION, row))
		if _inventory.has_spatial_location(location, _get64(_live, PAYLOAD_REVISION, row)):
			return &"LOCATION_INVENTORY_RETAINED"
	return &""


func _current_retention_refusal() -> StringName:
	"""A container created after staging still keeps its live endpoint at every final boundary."""
	for row: int in _capacity:
		var code: StringName = _loaded_retention_refusal(row)
		if code != &"":
			return code
	return &""


func _unused_row_canonical(row: int) -> bool:
	"""No free-row payload can preserve a hidden Room, old support or proof revision."""
	for field: int in range(1, I32_FIELDS):
		if _get32(_stage, field, row) != (-1 if field in [ROOM_SLOT, SECTION_SLOT] else 0):
			return false
	return _get64(_stage, PAYLOAD_REVISION, row) == 0 and _get64(_stage, GEOMETRY_REVISION, row) == 0


func _rebuild_allocation(bank: Bank) -> void:
	"""Sorted free rows form a canonical min-heap; all tail bytes are initialized."""
	bank.free_rows.fill(-1)
	bank.free_count = 0
	bank.count = 0
	for row: int in _capacity:
		if bank.present[row] == 1:
			bank.count += 1
		elif bank.retired[row] == 0 and _get32(bank, GENERATION, row) < Space.I32_MAX:
			bank.free_rows[bank.free_count] = row
			bank.free_count += 1
	_rebuild_order(bank)
