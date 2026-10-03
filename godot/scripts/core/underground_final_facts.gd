extends RefCounted
## Cold final actual-source attestation after all external observation callbacks. No new permission,
## survey, state, revision or per-entity storage. Static entry points avoid observer dispatch (1100).

const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const BINDING_CHECKS: int = 128
const SOURCE_CHECKS: int = 64
const RESIDENT_CHECKS: int = 256
const REFUSE_BINDING: StringName = &"SPACE_FINAL_BINDING"
const REFUSE_BUSY: StringName = &"SPACE_FINAL_BUSY"
const REFUSE_BUDGET: StringName = &"SPACE_FINAL_OPERATION_BUDGET"


static func snapshot_refusal(owner: Owner, routes: Routes, locations: Locations,
		expected_revision: int, max_checks: int) -> StringName:
	"""Recheck all retained actual source/claim facts without any public observation callback."""
	if max_checks < BINDING_CHECKS or max_checks > Space.MAX_CHECKS:
		return REFUSE_BUDGET
	var code: StringName = _binding_refusal(owner, routes, locations, expected_revision)
	if code != &"":
		return code
	if max_checks > owner._domain._checks or max_checks < BINDING_CHECKS + 2 * (owner._region_capacity + owner._source_capacity):
		return REFUSE_BUDGET
	if max_checks < _required_checks(owner):
		return REFUSE_BUDGET
	code = _sources_refusal(owner, routes, locations)
	return _claims_refusal(owner) if code == &"" else code


static func _binding_refusal(owner: Owner, routes: Routes, locations: Locations, revision: int) -> StringName:
	"""Borrow exact real stores; numerical ref equality in another World is insufficient."""
	if owner == null or routes == null or locations == null or owner._ready_error != &"" \
			or owner._domain == null or not owner._sources is Owner.CoreSources:
		return REFUSE_BINDING
	var sources: Owner.CoreSources = owner._sources as Owner.CoreSources
	if sources._directory == null or sources._buildings == null or sources._construction == null \
			or sources._locations != routes or routes._ids != sources._directory or routes._sources != sources \
			or routes._owner != owner or routes._locations != locations or routes._buildings != sources._buildings \
			or routes._transforms != locations._transforms or routes._cold != locations._cold \
			or routes._transforms == null or routes._residents == null \
			or routes._transforms._directory != sources._directory or routes._residents._directory != sources._directory \
			or sources._buildings._directory != sources._directory or sources._construction._directory != sources._directory \
			or sources._construction._buildings != sources._buildings:
		return REFUSE_BINDING
	if not _location_binding(locations, owner) or not _same_domain(owner._domain, routes._domain) \
			or not _same_domain(owner._domain, locations._domain) or routes._world != owner._domain._world:
		return REFUSE_BINDING
	if owner._stage_token != 0 or owner._validation_sources >= 0 or owner._validation_regions >= 0 or owner._room_callback \
			or routes._token != 0 or routes._in_callback or routes._advancing or routes._searching \
			or routes._occupancy_reading or locations._token != 0 or locations._in_retention:
		return REFUSE_BUSY
	return &"" if revision > 0 and owner._header[17] == revision else &"SPACE_REVISION_STALE"


static func _same_domain(first: Space.Domain, second: Space.Domain) -> bool:
	"""Compare complete immutable domain identity without descriptor copies or a hash collision."""
	return first != null and second != null and first._world == second._world \
		and first._datum == second._datum and first._min_quantum == second._min_quantum \
		and first._size_quanta == second._size_quanta and first._bounds == second._bounds \
		and first._cells == second._cells and first._regions == second._regions and first._checks == second._checks


static func _required_checks(owner: Owner) -> int:
	"""Precharge both finite scans and every present leaf before reading or writing reusable facts."""
	var required: int = BINDING_CHECKS + 2 * (owner._region_capacity + owner._source_capacity)
	for row: int in owner._source_capacity:
		if owner._o_present[row] != 0:
			required += RESIDENT_CHECKS if owner._o_kind[row] == Directory.KIND_RESIDENT else SOURCE_CHECKS
	for row: int in owner._region_capacity:
		if owner._r_present[row] != 0 and owner._r_claim_kind[row] != Owner.CLAIM_NONE:
			required += SOURCE_CHECKS
	return required


static func _sources_refusal(owner: Owner, routes: Routes, locations: Locations) -> StringName:
	"""Stored kinds bound leaf work; current full Directory identity must match before dispatch."""
	var sources: Owner.CoreSources = owner._sources as Owner.CoreSources
	for row: int in owner._source_capacity:
		if owner._o_present[row] == 0:
			continue
		if owner._o_present[row] != 1:
			return &"SPACE_SOURCE_FORMAT"
		var ref: Vector2i = Vector2i(owner._o_slot[row], owner._o_generation[row])
		if not sources._directory.is_valid_of_kind(ref, owner._o_kind[row]):
			return &"SPACE_SOURCE_STALE"
		var code: StringName = _resident_into(routes, locations, ref, owner._facts) \
			if owner._o_kind[row] == Directory.KIND_RESIDENT else Owner.CoreSources.read_leaf_into(sources, ref, owner._facts)
		if code == &"":
			code = _facts_refusal(sources, ref, owner._facts)
		if code != &"":
			return code
		if not owner._facts_match(row, false):
			return &"SPACE_SOURCE_DRIFT"
	return &""


static func _claims_refusal(owner: Owner) -> StringName:
	"""Room and project claims keep the same full identity rules as an ordinary live snapshot."""
	var sources: Owner.CoreSources = owner._sources as Owner.CoreSources
	for row: int in owner._region_capacity:
		if owner._r_present[row] == 0:
			continue
		if owner._r_present[row] != 1:
			return &"SPACE_REGION_FORMAT"
		if owner._r_claim_kind[row] == Owner.CLAIM_NONE:
			continue
		var kind: int = owner._r_claim_kind[row]
		if kind != Owner.CLAIM_ROOM and kind != Owner.CLAIM_CONSTRUCTION:
			return &"SPACE_RESERVATION_FORMAT"
		var ref: Vector2i = Vector2i(owner._r_claim_slot[row], owner._r_claim_generation[row])
		var expected: int = Directory.KIND_ROOM if kind == Owner.CLAIM_ROOM else Directory.KIND_CONSTRUCTION
		if not sources._directory.is_valid_of_kind(ref, expected):
			return &"SPACE_SOURCE_STALE"
		var code: StringName = Owner.CoreSources.read_leaf_into(sources, ref, owner._facts)
		if code == &"":
			code = _facts_refusal(sources, ref, owner._facts)
		if code != &"":
			return code
		if kind == Owner.CLAIM_ROOM and ref != Vector2i(owner._r_owner_slot[row], owner._r_owner_generation[row]):
			return &"SPACE_ROOM_CLAIM_IDENTITY"
	return &""


static func _facts_refusal(sources: Owner.CoreSources, ref: Vector2i, facts: Owner.Facts) -> StringName:
	"""Preserve the ordinary source format/domain checks after bypassing its observation adapter."""
	if facts.kind != sources._directory.get_kind(ref) or not Owner._nullable_ref(facts.parent) \
			or not Space.int32(facts.a) or not Space.int32(facts.b) or not Space.int32(facts.c) or not Space.int32(facts.d):
		return &"SPACE_SOURCE_FORMAT"
	if facts.kind == Directory.KIND_WORLD and (facts.parent != NULL_REF or facts.a != 0 \
			or facts.b != 0 or facts.c != 0 or facts.d != 0):
		return &"SPACE_SOURCE_FORMAT"
	if facts.kind == Directory.KIND_RESIDENT and (facts.d < 0 or (facts.parent != NULL_REF \
			and not sources._directory.is_valid_of_kind(facts.parent, Directory.KIND_ROOM))):
		return &"SPACE_RESIDENT_LOCATION_INVALID"
	return &""


static func _location_binding(actual: Locations, owner: Owner) -> bool:
	"""Observe exact configured endpoint owners and live World without their public binding hooks."""
	if actual == null or owner == null or actual._capacity <= 0 or actual._owner != owner \
			or actual._ids == null or actual._domain == null or owner._domain == null \
			or actual._sources != owner._sources or actual._sources == null \
			or not owner._sources is Owner.CoreSources or actual._buildings == null:
		return false
	return actual._world == owner._domain._world and actual._ids.is_valid_of_kind(actual._world, Directory.KIND_WORLD) \
		and actual._sources._directory == actual._ids and actual._sources._buildings == actual._buildings


static func record_matches(actual: Locations, location: Vector2i, expected: Locations.Record, owner: Owner) -> bool:
	"""Compare the entire actual full-generation endpoint without invoking read_location_into."""
	if expected == null or expected.envelope.size() != 6 or expected.support.size() != 6 \
			or not _location_binding(actual, owner) or actual._token != 0 or actual._in_retention \
			or not actual._live_ref(actual._live, location):
		return false
	var row: int = location.x
	if expected.world != actual._world or expected.point != Vector3i(actual._get32(actual._live, Locations.X, row),
			actual._get32(actual._live, Locations.Y, row), actual._get32(actual._live, Locations.Z, row)) \
			or expected.room != actual._ref_at(actual._live, Locations.ROOM_SLOT, row) \
			or expected.section != actual._ref_at(actual._live, Locations.SECTION_SLOT, row) \
			or expected.level != actual._get32(actual._live, Locations.LEVEL, row) \
			or expected.role != actual._get32(actual._live, Locations.ROLE, row) \
			or expected.payload_revision != actual._get64(actual._live, Locations.PAYLOAD_REVISION, row) \
			or expected.geometry_revision != actual._get64(actual._live, Locations.GEOMETRY_REVISION, row):
		return false
	for axis: int in 6:
		if expected.envelope[axis] != actual._get32(actual._live, Locations.ENVELOPE + axis, row) \
				or expected.support[axis] != actual._get32(actual._live, Locations.SUPPORT + axis, row):
			return false
	return owner._region_live(expected.section, false) and (expected.room == NULL_REF or actual._buildings.is_live_room(expected.room))


static func _resident_into(actual: Routes, locations: Locations, worker: Vector2i, out: Owner.Facts) -> StringName:
	"""Use actual packed movement and leaf Transform facts, never ResidentLocations/read_actor hooks."""
	if actual._edge_capacity <= 0 or actual._profiles == null or actual._work == null or actual._work.jobs() != actual._jobs:
		return &"ROUTE_ACTOR_UNBOUND"
	if not actual._ids.is_valid_of_kind(worker, Directory.KIND_RESIDENT) or not actual._transforms.read_into(worker, actual._pose):
		return &"ROUTE_ACTOR_STALE"
	var row: int = actual._ids.get_typed_row(worker)
	if actual._resident_ref(row) != worker or not actual._residents.is_alive(row):
		return &"ROUTE_ACTOR_NOT_REGISTERED"
	var code: StringName = _resident_location_refusal(actual, locations, row)
	if code != &"":
		return code
	out.kind = Directory.KIND_RESIDENT
	out.parent = actual._resident_pair(Routes.R_ROOM_SLOT, row)
	out.a = actual._pose.x
	out.b = actual._pose.y
	out.c = actual._pose.z
	out.d = actual._motion.resident[Routes.R_MODE * Routes.RESIDENT_CAPACITY + row]
	return &""


static func _resident_location_refusal(actual: Routes, locations: Locations, row: int) -> StringName:
	"""Committed full endpoint/span facts preserve containment without an observation or box copy."""
	var location: Vector2i = actual._resident_pair(Routes.R_LOCATION_SLOT, row)
	if not locations._live_ref(locations._live, location):
		return &"LOCATION_STALE"
	if locations._world != actual._world or not actual._owner._region_live(actual._resident_pair(Routes.R_SECTION_SLOT, row), false):
		return &"ROUTE_LOCATION_STALE"
	var room: Vector2i = actual._resident_pair(Routes.R_ROOM_SLOT, row)
	if room != NULL_REF and not actual._buildings.is_live_room(room):
		return &"ROUTE_LOCATION_STALE"
	if actual._resident_pair(Routes.R_EDGE_SLOT, row) != NULL_REF:
		return _transit_refusal(actual, row)
	if locations._get32(locations._live, Locations.X, location.x) != actual._pose.x \
			or locations._get32(locations._live, Locations.Y, location.x) != actual._pose.y \
			or locations._get32(locations._live, Locations.Z, location.x) != actual._pose.z:
		return &"ROUTE_ACTOR_POSITION_DRIFT"
	if locations._ref_at(locations._live, Locations.ROOM_SLOT, location.x) != room \
			or locations._ref_at(locations._live, Locations.SECTION_SLOT, location.x) != actual._resident_pair(Routes.R_SECTION_SLOT, row) \
			or locations._get32(locations._live, Locations.LEVEL, location.x) != actual._motion.resident[Routes.R_LEVEL * Routes.RESIDENT_CAPACITY + row]:
		return &"ROUTE_ACTOR_CONTAINMENT_DRIFT"
	return &""


static func _transit_refusal(actual: Routes, row: int) -> StringName:
	"""Validate committed full span generation and exact integer progress without public edge hooks."""
	var edge: Vector2i = actual._resident_pair(Routes.R_EDGE_SLOT, row)
	if not actual._live_edge(actual._live, edge):
		return &"ROUTE_EDGE_STALE"
	var segment: int = actual._motion.resident[Routes.R_SEGMENT * Routes.RESIDENT_CAPACITY + row]
	var progress: int = actual._motion.resident_long[Routes.R_PROGRESS * Routes.RESIDENT_CAPACITY + row]
	if segment < 0 or segment + 1 >= actual._edge_i32(actual._live, Routes.E_PATH_COUNT, edge.x):
		return &"ROUTE_PROGRESS_STALE"
	var first: Vector3i = actual._vertex(edge.x, segment)
	var second: Vector3i = actual._vertex(edge.x, segment + 1)
	var length: int = Routes._segment_length(first, second)
	if progress < 0 or progress >= length or actual._edge_pair(actual._live, Routes.E_SECTION_SLOT, edge.x) != actual._resident_pair(Routes.R_SECTION_SLOT, row):
		return &"ROUTE_PROGRESS_STALE"
	return &"" if Routes._interpolate(first, second, progress, length) == Vector3i(actual._pose.x, actual._pose.y, actual._pose.z) \
		else &"ROUTE_ACTOR_POSITION_DRIFT"
