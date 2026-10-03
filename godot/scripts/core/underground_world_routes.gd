extends "res://scripts/core/underground_routes.gd".Bindings
## Actual supported route certificates. Room reservation markers are not walls; finished
## void, physical walls, support, pending work and current World exclusions remain decisive.
## No cold observation creates excavation, a floor, a Job or a movement allowance.

const Routes := preload("res://scripts/core/underground_routes.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const World := preload("res://scripts/core/world_init.gd")
const Movement := preload("res://scripts/core/movement.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const MASK_BYTES: int = 32
const EDGE_CAPACITY: int = Routes.MAX_EDGES
const CERTIFICATE_BYTES: int = 2 * EDGE_CAPACITY * (MASK_BYTES + 4 + 16)
const CONTROL_RESERVE: int = 4096 # Fixed packets, weak links and numeric controls; not measured native RAM.
const RESERVED_BYTES: int = CERTIFICATE_BYTES + CONTROL_RESERVE
const FRAGMENT_CAPACITY: int = 1024
const SNAPSHOT_BYTES: int = 48 * Budget.REGION_CAPACITY + 16 * Budget.SOURCE_CAPACITY
const COLD_BYTES: int = SNAPSHOT_BYTES + 48 * FRAGMENT_CAPACITY + 1024
const SOURCE_PASS_CHECKS: int = Budget.REGION_CAPACITY + Budget.SOURCE_CAPACITY
const REFUSE_BINDING: StringName = &"WORLD_ROUTE_BINDING"
const REFUSE_CONTEXT: StringName = &"WORLD_ROUTE_CONTEXT"
const REFUSE_BUDGET: StringName = &"WORLD_ROUTE_COLD_LEASE"
const REFUSE_BUSY: StringName = &"WORLD_ROUTE_BUSY"
const REFUSE_COVERAGE: StringName = &"WORLD_ROUTE_COVERAGE"


class Configuration extends RefCounted:

	## Borrowed only during configure; the retained binding breaks the actual World owner cycles.
	var routes: Routes = null
	var owner: Owner = null
	var sources: Owner.CoreSources = null
	var locations: Locations = null
	var profiles: Profiles = null
	var catalog: Catalog = null
	var levels: Levels = null
	var movement: Movement = null
	var residents: Residents = null
	var transforms: Transforms = null
	var world: World = null
	var terrain: Terrain = null
	var budget: Budget = null


class Certificates extends RefCounted:
	## Two fixed derived banks. Generation zero is absent; paths cannot change at a live generation.
	var masks: PackedByteArray = PackedByteArray()
	var generations: PackedInt32Array = PackedInt32Array()
	var geometry: PackedInt64Array = PackedInt64Array()
	var content: PackedInt64Array = PackedInt64Array()

	func allocate() -> void:
		"""The complete two-bank peak is admitted before either bank grows."""
		masks.resize(EDGE_CAPACITY * MASK_BYTES)
		generations.resize(EDGE_CAPACITY)
		geometry.resize(EDGE_CAPACITY)
		content.resize(EDGE_CAPACITY)

	func copy_from(other: Certificates) -> void:
		"""Copy into already-owned storage; assignment would retain a third image on first mutation."""
		for index: int in masks.size():
			masks[index] = other.masks[index]
		for row: int in EDGE_CAPACITY:
			generations[row] = other.generations[row]
			geometry[row] = other.geometry[row]
			content[row] = other.content[row]

	func clear_row(row: int) -> void:
		"""An aborted or removed numeric row never certifies a later generation."""
		generations[row] = 0
		geometry[row] = 0
		content[row] = 0
		for index: int in MASK_BYTES:
			masks[row * MASK_BYTES + index] = 0

	func admits(row: int, profile: int) -> bool:
		"""Membership has finite dense profile IDs and exact per-edge generation/revision checks outside."""
		@warning_ignore("integer_division") var byte: int = profile / 8
		return profile >= 0 and profile < Profiles.MAX_PROFILES \
			and (masks[row * MASK_BYTES + byte] & (1 << (profile % 8))) != 0

	func admit(row: int, profile: int) -> void:
		"""Only a completed whole-profile proof sets its bit; other species are independent."""
		@warning_ignore("integer_division") var byte: int = profile / 8
		masks[row * MASK_BYTES + byte] |= 1 << (profile % 8)


class Clearance extends RefCounted:
	## One lease-bound exact-union query. Two flat arrays bound fragmentation without native Array growth.
	var image: Space.Snapshot = null
	var remaining: int = 0
	var error: StringName = &""
	var fragments: PackedInt32Array = PackedInt32Array()
	var next_fragments: PackedInt32Array = PackedInt32Array()
	var count: int = 0
	var next_count: int = 0
	var box: PackedInt32Array = PackedInt32Array()
	var cover: PackedInt32Array = PackedInt32Array()
	var cut: PackedInt32Array = PackedInt32Array()
	var core: PackedInt32Array = PackedInt32Array()

	func allocate(snapshot: Space.Snapshot, checks: int) -> void:
		"""Caller proves the actual shared lease before constructing this entire cold packet."""
		image = snapshot
		remaining = checks
		fragments.resize(6 * FRAGMENT_CAPACITY)
		next_fragments.resize(6 * FRAGMENT_CAPACITY)
		box.resize(6)
		cover.resize(6)
		cut.resize(6)
		core.resize(6)

	func spend(amount: int = 1) -> bool:
		"""The whole route preparation shares this bound, including refused profile candidates."""
		if amount < 0 or amount > remaining:
			error = &"WORLD_ROUTE_CHECK_CAPACITY"
			return false
		remaining -= amount
		return true

	func read_box(row: int, out: PackedInt32Array) -> void:
		"""Copy one actual source row into fixed scratch; never allocate a per-row box."""
		var rows: Space.Volumes = image.volumes
		out[0] = rows.lo_x[row]
		out[1] = rows.lo_y[row]
		out[2] = rows.lo_z[row]
		out[3] = rows.hi_x[row]
		out[4] = rows.hi_y[row]
		out[5] = rows.hi_z[row]

	func blocked(bounds: PackedInt32Array, supporting: bool = false) -> bool:
		"""Omitted room markers never suppress actual physical walls, unfinished work or protected access."""
		var rows: Space.Volumes = image.volumes
		for row: int in rows.role.size():
			if not spend():
				return true
			var role: int = rows.role[row]
			if role == Space.FLOOR_DATUM or role == Space.SUPPORTED_VOID or role == Space.SUPPORT:
				continue
			if supporting and role == Space.DRY_SOLID:
				continue # Dry matter alone still cannot satisfy the separate actual SUPPORT coverage.
			read_box(row, box)
			if Space.overlaps(bounds, box):
				return true
		return false

	func start(bounds: PackedInt32Array) -> void:
		"""Keep the whole requested volume, including authored negative contact residuals."""
		count = 1
		for axis: int in 6:
			fragments[axis] = bounds[axis]

	func subtract_role(role: int, limit: PackedInt32Array = PackedInt32Array()) -> bool:
		"""Intersect optional authored stance with actual support; a stance is never support by itself."""
		var rows: Space.Volumes = image.volumes
		for row: int in rows.role.size():
			if not spend():
				return false
			if rows.role[row] != role:
				continue
			read_box(row, cover)
			if not limit.is_empty():
				if not Space.overlaps(limit, cover):
					continue
				for axis: int in 3:
					cover[axis] = maxi(cover[axis], limit[axis])
					cover[axis + 3] = mini(cover[axis + 3], limit[axis + 3])
			if not subtract_cover():
				return false
			if count == 0:
				return true
		return true

	func covered(bounds: PackedInt32Array, role: int) -> bool:
		"""Exact subtraction detects interior holes that corners, centres or sampled points miss."""
		start(bounds)
		return subtract_role(role) and count == 0

	func subtract_cover() -> bool:
		"""Consume all existing fragments into the other preallocated bank before swapping roles."""
		next_count = 0
		for row: int in count:
			if not spend():
				return false
			for axis: int in 6:
				core[axis] = fragments[row * 6 + axis]
			if not _subtract_fragment():
				return false
		var previous: PackedInt32Array = fragments
		fragments = next_fragments
		next_fragments = previous
		count = next_count
		return true

	func _subtract_fragment() -> bool:
		"""Emit at most six disjoint outside slabs, with half-open exact integer contact faces."""
		if not Space.overlaps(core, cover):
			return _append(core)
		for axis: int in 3:
			cut[axis] = maxi(core[axis], cover[axis])
			cut[axis + 3] = mini(core[axis + 3], cover[axis + 3])
		for axis: int in 3:
			if not _outside_slab(axis, false) or not _outside_slab(axis, true):
				return false
		return true

	func _outside_slab(axis: int, after: bool) -> bool:
		"""Only the shrinking core remains after each emitted slab, preventing overlaps and omissions."""
		var endpoint: int = axis + 3 if after else axis
		if (core[endpoint] <= cut[endpoint] if after else core[endpoint] >= cut[endpoint]):
			return true
		for field: int in 6:
			box[field] = core[field]
		box[axis if after else axis + 3] = cut[endpoint]
		if not _append(box):
			return false
		core[endpoint] = cut[endpoint]
		return true

	func _append(bounds: PackedInt32Array) -> bool:
		"""Fragment exhaustion is explicit and never silently treats an unvisited interior as clear."""
		if next_count >= FRAGMENT_CAPACITY:
			error = &"WORLD_ROUTE_FRAGMENT_CAPACITY"
			return false
		for axis: int in 6:
			next_fragments[next_count * 6 + axis] = bounds[axis]
		next_count += 1
		return true


var _routes_ref: WeakRef = null
var _owner_ref: WeakRef = null
var _sources_ref: WeakRef = null
var _locations_ref: WeakRef = null
var _profiles: Profiles = null
var _catalog: Catalog = null
var _levels: Levels = null
var _movement: Movement = null
var _residents: Residents = null
var _transforms: Transforms = null
var _world: World = null
var _terrain: Terrain = null
var _budget: Budget = null
var _domain: Space.Domain = null
var _live: Certificates = Certificates.new()
var _stage: Certificates = Certificates.new()
var _proof: Clearance = null
var _opening: bool = false
var _compiling: bool = false
var _publishing: bool = false
var _reading: bool = false
var _sealed: bool = false
var _route_token: int = 0
var _space_token: int = 0
var _location_token: int = 0
var _cold_token: int = 0
var _base_revision: int = 0
var _target_revision: int = 0
var _content_revision: int = 0
var _catalog_revision: int = 0
var _live_catalog_revision: int = 0
var _descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
var _body: Profiles.Box = Profiles.Box.new()
var _stance: Profiles.Box = Profiles.Box.new()
var _endpoint: Locations.Record = Locations.Record.new()
var _section: Owner.Region = Owner.Region.new()
var _edge: Routes.Edge = Routes.Edge.new()
var _pace: IntMath.IntResult = IntMath.IntResult.new()
var _bounds: PackedInt32Array = PackedInt32Array()
var _support: PackedInt32Array = PackedInt32Array()
var _scratch: PackedInt32Array = PackedInt32Array()
var _first_point: PackedInt32Array = PackedInt32Array()
var _last_point: PackedInt32Array = PackedInt32Array()


func configure(config: Configuration) -> StringName:
	"""Bind exact stores before Routes.configure; that owner subsequently attests this same provider."""
	if _domain != null:
		return &"WORLD_ROUTE_ALREADY_BOUND"
	if not _configuration_matches(config):
		return REFUSE_BINDING
	_domain = config.owner.domain_copy()
	if _domain == null or not config.catalog.binding_matches(config.profiles, config.levels,
			config.movement, config.residents, config.transforms, _domain):
		_domain = null
		return REFUSE_BINDING
	_store_configuration(config)
	_live.allocate()
	_stage.allocate()
	_allocate_scratch()
	return &""


static func _configuration_matches(config: Configuration) -> bool:
	"""Foreign lookalike Worlds, source namespaces and cold arenas cannot supply permission."""
	if config == null or config.routes == null or config.owner == null or config.sources == null \
			or config.locations == null or config.profiles == null or config.catalog == null \
			or config.levels == null or config.movement == null or config.residents == null \
			or config.transforms == null or config.world == null or config.terrain == null or config.budget == null:
		return false
	return config.owner.is_bound_sources(config.sources) \
		and config.sources.resident_locations_owner() == config.routes \
		and config.routes.directory() == config.residents.directory() \
		and config.locations.is_bound_world(config.residents.directory(), config.locations.world_ref(), config.owner) \
		and config.locations.is_bound_budget(config.budget) \
		and config.terrain.is_bound_world(config.world, config.owner, config.sources) \
		and config.terrain.is_bound_budget(config.budget) and config.terrain.binding_refusal() == &"" \
		and config.owner.allocation_within(Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY) \
		and RESERVED_BYTES + Catalog.RESERVED_BYTES <= Budget.BINDINGS_AND_GROWTH_BYTES


func _store_configuration(config: Configuration) -> void:
	"""Break the Routes/CoreSources cycle while the actual World controller retains its owners."""
	_routes_ref = weakref(config.routes)
	_owner_ref = weakref(config.owner)
	_sources_ref = weakref(config.sources)
	_locations_ref = weakref(config.locations)
	_profiles = config.profiles
	_catalog = config.catalog
	_levels = config.levels
	_movement = config.movement
	_residents = config.residents
	_transforms = config.transforms
	_world = config.world
	_terrain = config.terrain
	_budget = config.budget


func _allocate_scratch() -> void:
	"""All hot outputs are fixed packets inside CONTROL_RESERVE, never a per-resident object pool."""
	_bounds.resize(6)
	_support.resize(6)
	_scratch.resize(6)
	_first_point.resize(3)
	_last_point.resize(3)
	_endpoint.envelope.resize(6)
	_endpoint.support.resize(6)
	_section.box.resize(6)


func _routes() -> Routes:
	"""Borrow only the original actual graph, never recreate one from numeric identities."""
	return _routes_ref.get_ref() as Routes if _routes_ref != null else null


func _owner() -> Owner:
	"""An expired geometry owner refuses every later read instead of retaining a stale World."""
	return _owner_ref.get_ref() as Owner if _owner_ref != null else null


func _sources() -> Owner.CoreSources:
	"""The actual typed source reader owns the full EntityRef namespace."""
	return _sources_ref.get_ref() as Owner.CoreSources if _sources_ref != null else null


func _locations() -> Locations:
	"""The exact local endpoint namespace is distinct from Directory and sparse region handles."""
	return _locations_ref.get_ref() as Locations if _locations_ref != null else null


func exact_binding(routes: RefCounted, locations: Locations, owner: Owner, cold: Budget) -> bool:
	"""This predicate works during initial Routes.configure without requiring a circular prior bind."""
	return _domain != null and routes != null and routes == _routes() and locations == _locations() \
		and owner != null and owner == _owner() and cold == _budget and _sources() != null \
		and owner.is_bound_sources(_sources()) and _sources().resident_locations_owner() == routes \
		and _terrain.is_bound_world(_world, owner, _sources()) and _terrain.is_bound_budget(cold) \
		and locations.is_bound_world(_residents.directory(), _domain._world, owner)


func binding_refusal() -> StringName:
	"""Operational calls require the fully bound actual profiles as well as the original collaborators."""
	var graph: Routes = _routes()
	if not exact_binding(graph, _locations(), _owner(), _budget) \
			or not graph.binding_matches(_residents, _transforms, _locations(), _owner(), _budget, _profiles) \
			or not _catalog.binding_matches(_profiles, _levels, _movement, _residents, _transforms, _domain):
		return REFUSE_BINDING
	return _terrain.binding_refusal()


func begin_prepare(cold_token: int, space_token: int = 0, location_token: int = 0) -> Routes.Result:
	"""Own the certificate companion of one real Routes transaction under the actual whole-operation lease."""
	if _opening or _compiling or _publishing or _reading or _route_token != 0:
		return Routes.Result.new(REFUSE_BUSY)
	_opening = true
	var code: StringName = binding_refusal()
	if code == &"" and not _budget.covers(cold_token, Budget.COLD_BYTES):
		code = REFUSE_BUDGET
	var result: Routes.Result = _routes().begin_prepare(cold_token, space_token, location_token) \
		if code == &"" else Routes.Result.new(code)
	if result.error == &"":
		_pin_preparation(result.token, cold_token, space_token, location_token)
		result.error = _begin_proof()
		if result.error != &"":
			_routes().abort(result.token)
			_clear_preparation()
			result.token = 0
	_opening = false
	return result


func _pin_preparation(token: int, cold_token: int, space_token: int, location_token: int) -> void:
	"""Non-reused graph and lease tokens disambiguate aborted candidates with equal row generations."""
	_route_token = token
	_cold_token = cold_token
	_space_token = space_token
	_location_token = location_token
	_base_revision = _owner().revision()
	_target_revision = _base_revision + (1 if space_token != 0 and _owner().prepared_has_changes(space_token) else 0)
	_content_revision = _profiles.content_revision()
	_catalog_revision = _catalog.content_revision()
	_stage.copy_from(_live)
	if _live_catalog_revision != _catalog_revision:
		_stage.content.fill(0) # Retain handles so every surviving edge must be explicitly requalified.
		_stage.masks.fill(0)
	_sealed = false


func _begin_proof() -> StringName:
	"""No snapshot or fragments allocate before the exact lease and finite coexistence peak are admitted."""
	if _domain._checks < 3 * SOURCE_PASS_CHECKS:
		return &"WORLD_ROUTE_CHECK_CAPACITY"
	var code: StringName = _preparation_refusal()
	if code != &"":
		return code
	var snapshot: Space.Snapshot = Space.Snapshot.new()
	code = _owner().prepared_snapshot_for_traversal_into(_space_token, snapshot) if _space_token != 0 \
		else _owner().snapshot_for_traversal_into(snapshot)
	if code == &"":
		code = _preparation_refusal()
	if code != &"":
		return code
	_proof = Clearance.new()
	_proof.allocate(snapshot, _domain._checks)
	return &"" if _proof.spend(3 * (Budget.REGION_CAPACITY + Budget.SOURCE_CAPACITY)) else _proof.error


func _preparation_refusal() -> StringName:
	"""Lease expiry, content reload and physical preparation drift invalidate the complete candidate."""
	if _route_token <= 0 or not _budget.covers(_cold_token, Budget.COLD_BYTES):
		return REFUSE_BUDGET
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	if _profiles.content_revision() != _content_revision or _catalog.content_revision() != _catalog_revision \
			or _owner().revision() != _base_revision:
		return REFUSE_CONTEXT
	if _space_token != 0:
		if _proof != null and not _proof.spend(SOURCE_PASS_CHECKS):
			return _proof.error
		return _owner().prepared_refusal(_space_token)
	return &"SPACE_TRANSACTION_BUSY" if _owner().has_prepared() else &""


func edge_refusal(edge: Routes.Edge, route_token: int, space_token: int, location_token: int) -> StringName:
	"""Compile whole-profile masks only for our original live transaction and exact immutable path."""
	if _opening or _compiling or _publishing or _reading or _sealed or _proof == null \
			or route_token != _route_token or space_token != _space_token or location_token != _location_token:
		return REFUSE_CONTEXT
	_compiling = true
	var code: StringName = _preparation_refusal()
	if code == &"":
		code = _compile_edge(edge)
	if code == &"":
		code = _preparation_refusal()
	_compiling = false
	return code


func _compile_edge(edge: Routes.Edge) -> StringName:
	"""Each finite profile qualifies separately, so a narrow valid mouse route does not promise badger clearance."""
	if edge == null or edge.ref.x < 0 or edge.ref.x >= EDGE_CAPACITY or edge.ref.y <= 0 \
			or edge.geometry_revision != _target_revision or edge.content_revision != _content_revision:
		return REFUSE_CONTEXT
	_stage.clear_row(edge.ref.x)
	var code: StringName = _path_refusal(edge)
	if code != &"":
		return code
	var accepted: int = 0
	for profile: int in _profiles.profile_count(_content_revision):
		if not _proof.spend():
			return _proof.error
		code = _profile_edge_refusal(profile, edge)
		if _proof.error != &"":
			return _proof.error
		if code == &"":
			_stage.admit(edge.ref.x, profile)
			accepted += 1
	if accepted == 0:
		return &"WORLD_ROUTE_NO_FITTING_PROFILE"
	_stage.generations[edge.ref.x] = edge.ref.y
	_stage.geometry[edge.ref.x] = _target_revision
	_stage.content[edge.ref.x] = _content_revision
	return &""


func _path_refusal(edge: Routes.Edge) -> StringName:
	"""This increment qualifies level ground only; fixed connector geometry also needs its actual installed owner."""
	if edge.point_count < 2 or edge.point_count > Routes.MAX_VERTICES \
			or edge.points.size() < edge.point_count * 3:
		return &"WORLD_ROUTE_PATH_FORMAT"
	if edge.family == -1:
		if edge.variant != 0 or edge.mode == Profiles.MODE_CLIMB:
			return &"WORLD_ROUTE_GROUND_CONTENT"
		for point: int in edge.point_count:
			if not _proof.spend():
				return _proof.error
			if edge.points[point * 3 + 1] != edge.points[1]:
				return &"WORLD_ROUTE_GROUND_HEIGHT"
		return &""
	return &"WORLD_ROUTE_FIXED_CONNECTOR_SOURCE_REQUIRED"


func _profile_edge_refusal(profile: int, edge: Routes.Edge) -> StringName:
	"""Source/continuous/numerical/presentation proofs must all be present in this exact finite catalog."""
	var code: StringName = _profiles.descriptor_into(profile, _content_revision, _descriptor)
	if code != &"":
		return code
	if _descriptor.certificate_flags != Profiles.CERT_REQUIRED or _descriptor.mode != edge.mode \
			or _descriptor.posture != edge.posture or (edge.family >= 0 and (_descriptor.family_mask & (1 << edge.family)) == 0):
		return &"WORLD_ROUTE_PROFILE_KIND"
	code = _catalog.pace_into(profile, _descriptor.profile_revision, _content_revision,
		edge.family, edge.variant, _catalog_revision, _pace)
	if code != &"":
		return code
	for segment: int in edge.point_count - 1:
		if not _proof.spend():
			return _proof.error
		var first: Vector3i = _point(edge, segment)
		var last: Vector3i = _point(edge, segment + 1)
		if _descriptor.yaw_kind != Profiles.YAW_ALL \
				and Routes.heading_for_delta(last - first, _descriptor.yaw) != _descriptor.yaw:
			return &"WORLD_ROUTE_PROFILE_HEADING"
		code = _profile_segment_refusal(first, last)
		if code != &"":
			return code
	return &""


static func _point(edge: Routes.Edge, ordinal: int) -> Vector3i:
	"""Read only a prevalidated triple; Vector3i is a value, not an allocated scene object."""
	return Vector3i(edge.points[ordinal * 3], edge.points[ordinal * 3 + 1], edge.points[ordinal * 3 + 2])


func _profile_box_into(ordinal: int, out: Profiles.Box) -> StringName:
	"""Every extent read is tied to the same actual full finite content revision."""
	return _profiles.box_into(_descriptor.profile_id, _descriptor.profile_revision,
		_descriptor.content_revision, ordinal, out)


func _profile_segment_refusal(first: Vector3i, last: Vector3i) -> StringName:
	"""Stance is independently supported before any body residual may share that real support."""
	var code: StringName = _stance_sweeps_refusal(first, last)
	if code != &"":
		return code
	for ordinal: int in _descriptor.box_count:
		if not _proof.spend():
			return _proof.error
		code = _profile_box_into(ordinal, _body)
		if code != &"":
			return code
		if _body.role != Profiles.BODY_HELD_LOAD and _body.role != Profiles.TURN_RECOVERY:
			continue
		code = _sweep_into(_body, first, last, _bounds)
		if code == &"":
			code = _terrain.exclusions_refusal(_bounds)
		if code != &"":
			return code
		if _proof.blocked(_bounds, true) or not _body_covered(first, last) or not _solid_contacts_covered(first, last):
			return _proof.error if _proof.error != &"" else REFUSE_COVERAGE
	return &""


func _solid_contacts_covered(first: Vector3i, last: Vector3i) -> bool:
	"""Physical matter, including support inside void, is excused only at explicitly authored support contact."""
	for row: int in _proof.image.volumes.role.size():
		if not _proof.spend():
			return false
		if _proof.image.volumes.role[row] != Space.DRY_SOLID and _proof.image.volumes.role[row] != Space.SUPPORT:
			continue
		_proof.read_box(row, _scratch)
		if not Space.overlaps(_scratch, _bounds):
			continue
		for axis: int in 3:
			_scratch[axis] = maxi(_scratch[axis], _bounds[axis])
			_scratch[axis + 3] = mini(_scratch[axis + 3], _bounds[axis + 3])
		_proof.start(_scratch)
		for ordinal: int in _descriptor.box_count:
			if not _proof.spend() or _profile_box_into(ordinal, _stance) != &"":
				return false
			if _stance.role != Profiles.STANCE_SUPPORT:
				continue
			if _sweep_into(_stance, first, last, _support) != &"" \
					or not _proof.subtract_role(Space.SUPPORT, _support):
				return false
		if _proof.count != 0:
			return false
	return true


func _stance_sweeps_refusal(first: Vector3i, last: Vector3i) -> StringName:
	"""The full explicit contact volume needs real support, including transitions between adjacent boxes."""
	for ordinal: int in _descriptor.box_count:
		if not _proof.spend():
			return _proof.error
		var code: StringName = _profile_box_into(ordinal, _stance)
		if code != &"":
			return code
		if _stance.role != Profiles.STANCE_SUPPORT:
			continue
		code = _sweep_into(_stance, first, last, _support)
		if code == &"":
			code = _terrain.exclusions_refusal(_support)
		if code != &"":
			return code
		if _proof.blocked(_support, true) or not _proof.covered(_support, Space.SUPPORT):
			return _proof.error if _proof.error != &"" else &"WORLD_ROUTE_SUPPORT"
	return &""


func _body_covered(first: Vector3i, last: Vector3i) -> bool:
	"""Void plus actual SUPPORT intersected with authored stance covers every body/load/recovery point."""
	_proof.start(_bounds)
	if not _proof.subtract_role(Space.SUPPORTED_VOID):
		return false
	for ordinal: int in _descriptor.box_count:
		if _proof.count == 0:
			return true
		if not _proof.spend() or _profile_box_into(ordinal, _stance) != &"":
			return false
		if _stance.role != Profiles.STANCE_SUPPORT:
			continue
		if _sweep_into(_stance, first, last, _support) != &"" \
				or not _proof.subtract_role(Space.SUPPORT, _support):
			return false
	return _proof.count == 0


func _sweep_into(box: Profiles.Box, first: Vector3i, last: Vector3i, out: PackedInt32Array) -> StringName:
	"""The swept AABB conservatively contains the entire continuous segment, not sampled instants."""
	for axis: int in 3:
		var low: int = int(mini(first[axis], last[axis])) + int(box.low[axis])
		var high: int = int(maxi(first[axis], last[axis])) + int(box.high[axis])
		if low < _domain._bounds[axis] or high > _domain._bounds[axis + 3] or low >= high:
			return &"WORLD_ROUTE_PROFILE_BOUNDS"
		out[axis] = low
		out[axis + 3] = high
	return &""


func seal(token: int) -> StringName:
	"""Seal actual routes and companion masks before payment; discard the cold snapshot before publication."""
	if _opening or _compiling or _publishing or _reading or token <= 0 or token != _route_token or _sealed:
		return REFUSE_CONTEXT
	_compiling = true
	var code: StringName = _preparation_refusal()
	if code == &"":
		code = _routes().seal(token)
	if code == &"":
		code = _sealed_certificates_refusal()
	if code == &"":
		code = _preparation_refusal()
	if code == &"":
		_sealed = true
		_proof = null
	_compiling = false
	return code


func _sealed_certificates_refusal() -> StringName:
	"""Full generations distinguish removed rows; refreshed routes must have a new full geometry proof."""
	if not _proof.spend(4 * SOURCE_PASS_CHECKS): # Batch brackets plus both same-stack publication boundaries.
		return _proof.error
	var code: StringName = _routes().prepared_refusal(_route_token)
	if code != &"":
		return code
	for row: int in EDGE_CAPACITY:
		if not _proof.spend():
			return _proof.error
		if _stage.generations[row] == 0:
			continue
		var ref: Vector2i = Vector2i(row, _stage.generations[row])
		code = _routes().prepared_edge_metadata_reused_into(_route_token, ref, _edge)
		if code == &"ROUTE_EDGE_STALE":
			_stage.clear_row(row)
			continue
		if code != &"":
			return code
		if _stage.geometry[row] != _edge.geometry_revision or _stage.content[row] != _edge.content_revision \
				or _stage.geometry[row] != _target_revision or _stage.content[row] != _content_revision:
			return &"WORLD_ROUTE_CERTIFICATE_STALE"
	return _routes().prepared_refusal(_route_token)


func publication_refusal(route_token: int, space_token: int, location_token: int) -> StringName:
	"""Only our same-stack publish wrapper may promote the graph; agreeing here never swaps certificates."""
	if not _publishing or not _sealed or route_token != _route_token \
			or space_token != _space_token or location_token != _location_token:
		return &"WORLD_ROUTE_PUBLICATION_CONTEXT"
	return _publication_context_refusal()


func _publication_context_refusal() -> StringName:
	"""All fallible checks precede the real graph swap; physical and endpoint companions are already live."""
	if not _budget.covers(_cold_token, Budget.COLD_BYTES):
		return REFUSE_BUDGET
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	if _owner().has_prepared() or _owner().revision() != _target_revision \
			or _profiles.content_revision() != _content_revision or _catalog.content_revision() != _catalog_revision:
		return REFUSE_CONTEXT
	return _owner().snapshot_revision_refusal(_target_revision)


func publish(token: int) -> StringName:
	"""Actual Routes success is the final mutation boundary; later owner checks cannot publish a private mask early."""
	if _opening or _compiling or _publishing or _reading or not _sealed or token <= 0 or token != _route_token:
		return REFUSE_CONTEXT
	var code: StringName = _publication_context_refusal()
	if code != &"":
		return code
	_publishing = true
	code = _routes().publish(token)
	_publishing = false
	if code != &"":
		return code
	assert(_routes().last_published_token() == token, "Only this exact actual route swap promotes its certificates")
	var previous: Certificates = _live
	_live = _stage
	_stage = previous
	_live_catalog_revision = _catalog_revision
	_clear_preparation()
	return &""


func abort(token: int) -> bool:
	"""Abort only this candidate; never release another owner's retained cold lease or alter live certificates."""
	if _opening or _compiling or _publishing or _reading or token <= 0 or token != _route_token:
		return false
	var aborted: bool = _routes().abort(token)
	_clear_preparation()
	return aborted


func _clear_preparation() -> void:
	"""All cold allocations die before the caller may release its exact shared arena."""
	_proof = null
	_route_token = 0
	_space_token = 0
	_location_token = 0
	_cold_token = 0
	_base_revision = 0
	_target_revision = 0
	_content_revision = 0
	_catalog_revision = 0
	_sealed = false


func _selection_refusal(selection: Profiles.Selection) -> StringName:
	"""Actual Routes re-reads dynamic owners around callbacks; this additionally pins authored descriptor identity."""
	if selection == null or selection.content_revision <= 0 \
			or selection.content_revision != _profiles.content_revision():
		return &"WORLD_ROUTE_PROFILE_STALE"
	var code: StringName = _profiles.descriptor_into(selection.profile_id, selection.content_revision, _descriptor)
	if code != &"":
		return code
	if _descriptor.profile_revision != selection.profile_revision or _descriptor.box_count != selection.box_count \
			or _descriptor.species != selection.species or _descriptor.life_stage != selection.life_stage \
			or _descriptor.rig != selection.rig or _descriptor.mode != selection.mode \
			or _descriptor.posture != selection.posture or _descriptor.yaw_kind != selection.orientation \
			or (_descriptor.yaw_kind != Profiles.YAW_ALL and _descriptor.yaw != selection.yaw) \
			or _descriptor.certificate_flags != Profiles.CERT_REQUIRED:
		return &"WORLD_ROUTE_PROFILE_STALE"
	return &""


func _hot_refusal() -> StringName:
	"""Movement cannot cross any uncommitted geometry transaction or active compilation scratch."""
	if _opening or _compiling or _publishing or _route_token != 0:
		return REFUSE_BUSY
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	return REFUSE_CONTEXT if _owner().has_prepared() else &""


func _certificate_refusal(ref: Vector2i, selection: Profiles.Selection) -> StringName:
	"""An old geometry/content revision or aborted edge generation never supplies a cached movement proof."""
	var code: StringName = _hot_refusal()
	if code == &"":
		code = _selection_refusal(selection)
	if code != &"":
		return code
	if ref.x < 0 or ref.x >= EDGE_CAPACITY or ref.y <= 0 or _live.generations[ref.x] != ref.y \
			or _live.geometry[ref.x] != _owner().revision() or _live.content[ref.x] != selection.content_revision \
			or _live_catalog_revision <= 0 or _live_catalog_revision != _catalog.content_revision() \
			or not _live.admits(ref.x, selection.profile_id):
		return &"WORLD_ROUTE_CERTIFICATE_STALE"
	code = _routes().edge_metadata_into(ref, _edge)
	if code == &"" and (_edge.geometry_revision != _live.geometry[ref.x] \
			or _edge.content_revision != _live.content[ref.x] or _edge.mode != selection.mode \
			or _edge.posture != selection.posture):
		code = &"WORLD_ROUTE_CERTIFICATE_STALE"
	return code


func travel_refusal(edge: Vector2i, selection: Profiles.Selection) -> StringName:
	"""Static eligibility is constant-time; current pace and local dynamic obstacles are checked when traversed."""
	if _reading:
		return REFUSE_BUSY
	_reading = true
	return _finish_read(_certificate_refusal(edge, selection))


func pace_into(selection: Profiles.Selection, family: int, variant: int, out: IntMath.IntResult) -> StringName:
	"""Guard the complete actual-source callback lifetime before touching shared query scratch."""
	if _reading:
		return REFUSE_BUSY
	_reading = true
	return _finish_read(_pace_into(selection, family, variant, out))


func _finish_read(code: StringName) -> StringName:
	"""Every admitted read, including refusals, returns ownership of the single reusable query packet."""
	_reading = false
	return code


func _pace_into(selection: Profiles.Selection, family: int, variant: int, out: IntMath.IntResult) -> StringName:
	"""Only the exact finite catalog and actual Movement profile can publish this actor's integer pace."""
	var code: StringName = _hot_refusal()
	if code == &"":
		code = _selection_refusal(selection)
	if code != &"":
		return code
	if out == null or _live_catalog_revision <= 0 or _live_catalog_revision != _catalog.content_revision():
		return &"WORLD_ROUTE_PACE_STALE"
	return _catalog.pace_into(selection.profile_id, selection.profile_revision, selection.content_revision,
		family, variant, _live_catalog_revision, out)


func actor_admission_refusal(location: Vector2i, selection: Profiles.Selection) -> StringName:
	"""A reentrant terrain/source callback cannot overwrite the outer resident's exact body and stance."""
	if _reading:
		return REFUSE_BUSY
	_reading = true
	return _finish_read(_actor_admission_refusal(location, selection))


func _actor_admission_refusal(location: Vector2i, selection: Profiles.Selection) -> StringName:
	"""Fit an actual grounded profile into a current complete endpoint; metadata or equal floor height is insufficient."""
	var code: StringName = _hot_refusal()
	if code == &"":
		code = _selection_refusal(selection)
	if code == &"":
		code = _locations().read_location_into(location, _endpoint)
	if code != &"":
		return code
	var point: Vector3i = Vector3i(selection.x, selection.y, selection.z)
	if _endpoint.world != _domain._world or _endpoint.geometry_revision != _owner().revision() \
			or _endpoint.point != point:
		return &"WORLD_ROUTE_ENDPOINT_STALE"
	for ordinal: int in _descriptor.box_count:
		code = _profile_box_into(ordinal, _body)
		if code == &"":
			code = _endpoint_box_refusal(point, selection.worker)
		if code != &"":
			return code
	return &""


func _endpoint_box_refusal(point: Vector3i, worker: Vector2i) -> StringName:
	"""Keep exact support-contact residuals while independently containing the complete occupied body."""
	if _body.role != Profiles.STANCE_SUPPORT and _body.role != Profiles.BODY_HELD_LOAD \
			and _body.role != Profiles.TURN_RECOVERY:
		return &""
	var code: StringName = _sweep_into(_body, point, point, _bounds)
	if code == &"":
		code = _terrain.exclusions_refusal(_bounds)
	if code != &"":
		return code
	if _body.role == Profiles.STANCE_SUPPORT:
		return &"" if Space.contains_box(_endpoint.support, _bounds) else &"WORLD_ROUTE_ENDPOINT_SUPPORT"
	if not _endpoint_body_contained(point):
		return &"WORLD_ROUTE_ENDPOINT_BODY"
	return _routes().occupancy_refusal(_bounds, worker)


func _endpoint_body_contained(point: Vector3i) -> bool:
	"""Partition at the actual endpoint floor; neither half of a grounded body is discarded."""
	var floor_y: int = _endpoint.envelope[1]
	for axis: int in 6:
		_scratch[axis] = _bounds[axis]
	if _bounds[4] > floor_y:
		_scratch[1] = maxi(_bounds[1], floor_y)
		if not Space.contains_box(_endpoint.envelope, _scratch):
			return false
	if _bounds[1] >= floor_y:
		return true
	_scratch[1] = _bounds[1]
	_scratch[4] = mini(_bounds[4], floor_y)
	if not Space.contains_box(_endpoint.support, _scratch):
		return false
	return _in_authored_stance(_scratch, point)


func _in_authored_stance(bounds: PackedInt32Array, point: Vector3i) -> bool:
	"""Endpoint residuals need one complete authored stance region; partial overlap never excuses body penetration."""
	for ordinal: int in _descriptor.box_count:
		if _profile_box_into(ordinal, _stance) != &"":
			return false
		if _stance.role == Profiles.STANCE_SUPPORT and _sweep_into(_stance, point, point, _support) == &"" \
				and Space.contains_box(_support, bounds):
			return true
	return false


func motion_refusal(worker: Vector2i, ref: Vector2i, segment: int, first: Vector3i,
		last: Vector3i, selection: Profiles.Selection) -> StringName:
	"""Protect moving-body scratch across all actual local exclusion and occupancy reads."""
	if _reading:
		return REFUSE_BUSY
	_reading = true
	return _finish_read(_motion_refusal(worker, ref, segment, first, last, selection))


func _motion_refusal(worker: Vector2i, ref: Vector2i, segment: int, first: Vector3i,
		last: Vector3i, selection: Profiles.Selection) -> StringName:
	"""Use cold whole-span proof plus actual sparse occupants and current local World protection at every tick."""
	var code: StringName = _certificate_refusal(ref, selection)
	if code != &"":
		return code
	if selection.worker != worker or segment < 0 or segment + 1 >= _edge.point_count:
		return &"WORLD_ROUTE_MOTION_CONTEXT"
	code = _routes().edge_point_into(ref, segment, _first_point)
	if code == &"":
		code = _routes().edge_point_into(ref, segment + 1, _last_point)
	if code != &"" or not _inside_segment_box(first) or not _inside_segment_box(last):
		return code if code != &"" else &"WORLD_ROUTE_MOTION_CONTEXT"
	for ordinal: int in _descriptor.box_count:
		code = _profile_box_into(ordinal, _body)
		if code == &"":
			code = _moving_box_refusal(worker, first, last)
		if code != &"":
			return code
	return &""


func _inside_segment_box(point: Vector3i) -> bool:
	"""The stored cold swept AABB contains every actual integer interpolation point on this immutable span."""
	for axis: int in 3:
		if point[axis] < mini(_first_point[axis], _last_point[axis]) \
				or point[axis] > maxi(_first_point[axis], _last_point[axis]):
			return false
	return true


func _moving_box_refusal(worker: Vector2i, first: Vector3i, last: Vector3i) -> StringName:
	"""Occupancy covers both body and turning recovery; current terrain exclusions also cover grounded contacts."""
	if _body.role != Profiles.STANCE_SUPPORT and _body.role != Profiles.BODY_HELD_LOAD \
			and _body.role != Profiles.TURN_RECOVERY:
		return &""
	var code: StringName = _sweep_into(_body, first, last, _bounds)
	if code == &"":
		code = _terrain.exclusions_refusal(_bounds)
	if code == &"" and _body.role != Profiles.STANCE_SUPPORT:
		code = _routes().occupancy_refusal(_bounds, worker)
	return code


func transit_region_into(section: Vector2i, segment: int, point: Vector3i, out: Owner.Region) -> StringName:
	"""Containment metadata uses the same exclusive fixed scratch as other hot actual-owner readers."""
	if _reading:
		return REFUSE_BUSY
	_reading = true
	return _finish_read(_transit_region_into(section, segment, point, out))


func _transit_region_into(section: Vector2i, segment: int, point: Vector3i, out: Owner.Region) -> StringName:
	"""Return the real full section at an already certified span point, without creating a floor from its height."""
	var code: StringName = _hot_refusal()
	if code != &"":
		return code
	if out == null or out.box.size() != 6 or segment < 0:
		return &"WORLD_ROUTE_SECTION_OUTPUT"
	code = _owner().region_into_reused(section, _section)
	if code != &"":
		return code
	if _section.role != Space.FLOOR_DATUM or _section.claim_kind != Owner.CLAIM_NONE \
			or point.x < _section.box[0] or point.x >= _section.box[3] \
			or point.z < _section.box[2] or point.z >= _section.box[5]:
		return &"WORLD_ROUTE_SECTION_CONTAINMENT"
	for axis: int in 6:
		out.box[axis] = _section.box[axis]
	out.owner = _section.owner
	out.section = _section.section
	out.role = _section.role
	out.level = _section.level
	out.claim_ref = _section.claim_ref
	out.claim_kind = _section.claim_kind
	return &""
