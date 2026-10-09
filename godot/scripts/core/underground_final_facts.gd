extends RefCounted
## Cold final actual-source attestation after all external observation callbacks. No new permission,
## survey, state, revision or per-entity storage. Static entry points avoid observer dispatch (1100).

const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
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
	"""Ordinary final snapshots remain live-only even though Room admission has its own typed sealed proof."""
	var code: StringName = _stores_refusal(owner, routes, locations)
	if code != &"":
		return code
	if owner._stage_token != 0 or owner._validation_sources >= 0 or owner._validation_regions >= 0 or owner._room_callback \
			or routes._token != 0 or routes._in_callback or routes._advancing or routes._searching \
			or routes._occupancy_reading or locations._token != 0 or locations._in_retention:
		return REFUSE_BUSY
	return &"" if revision > 0 and owner._header[17] == revision else &"SPACE_REVISION_STALE"


static func _stores_refusal(owner: Owner, routes: Routes, locations: Locations) -> StringName:
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
	return &""


static func prepared_room_refusal(owner: Owner, routes: Routes, locations: Locations, orders: RoomOrders,
		candidate: Directory.CreateCandidate, space_token: int, budget: Budget, cold_token: int, max_checks: int) -> StringName:
	"""Final actual Room request/allocator/source proof, after observers and before Room or Site identity writes."""
	if max_checks < BINDING_CHECKS or max_checks > Space.MAX_CHECKS:
		return REFUSE_BUDGET
	var code: StringName = _stores_refusal(owner, routes, locations)
	if code != &"":
		return code
	code = _room_scope_refusal(owner, orders, candidate, space_token, budget, cold_token)
	if code == &"":
		code = _room_companion_scope(owner, routes, locations, orders, space_token, cold_token)
	if code != &"":
		return code
	var initial: int = BINDING_CHECKS + 2 * (owner._source_capacity + owner._region_capacity) + _room_request_checks(orders)
	if max_checks > owner._domain._checks or initial > max_checks or _room_required_checks(owner, initial) > max_checks:
		return REFUSE_BUDGET
	code = _room_request_refusal(orders)
	if code != &"":
		return code
	code = _room_source_rows(owner, routes, locations, candidate.ref)
	return _room_claim_rows(owner, candidate.ref) if code == &"" else code


static func _room_scope_refusal(owner: Owner, orders: RoomOrders, candidate: Directory.CreateCandidate,
		space_token: int, budget: Budget, cold_token: int) -> StringName:
	"""Read the concrete coordinator's private candidate and original arena directly, never an authority override."""
	if orders == null or orders._ready_error != &"" or orders._publishing \
			or orders._stage_action != RoomOrders.ROOM_ADMISSION_STAGE or orders._space != owner \
			or orders._stage_token != space_token or orders._room_candidate != candidate \
			or candidate == null or orders._stage_room != candidate.ref or not _room_request_present(orders) \
			or orders._room_budget != budget or not orders._cold_held \
			or cold_token <= 0 or orders._room_cold_token != cold_token or budget == null \
			or not budget.covers(cold_token, Budget.COLD_BYTES):
		return RoomOrders.REFUSE_ROOM_COLD
	var sources: Owner.CoreSources = owner._sources as Owner.CoreSources
	if orders._world != owner._domain._world or not sources._directory.is_valid_of_kind(orders._world, Directory.KIND_WORLD) \
			or orders._sources != sources \
			or not _same_domain(owner._domain, orders._room_domain) \
			or orders._construction != sources._construction or orders._buildings != sources._buildings \
			or orders._buildings._spatial_authority == null or orders._buildings._spatial_authority.get_ref() != orders \
			or orders._router == null or orders._router.get_ref() == null or orders._construction._modular_authority == null \
			or orders._router.get_ref() != orders._construction._modular_authority.get_ref() \
			or orders._bindings == null or not orders._bindings.get_ref() is RoomOrders.Bindings \
			or not _room_request_world_matches(orders, owner._header[17]):
		return REFUSE_BINDING
	var room_type: int = Buildings.ROOM_TYPE_CORRIDOR if orders._entry_mode else orders._room_plan.room_type
	var code: StringName = Owner.room_prepared_leaf_refusal(owner, space_token, candidate, room_type, orders)
	return _room_candidate_leaf(sources._directory, candidate) if code == &"" else code


static func _room_request_present(orders: RoomOrders) -> bool:
	"""The two request protocols never borrow a private packet left by the other admission mode."""
	return orders._entry_plan != null and orders._entry_request != null if orders._entry_mode \
		else orders._room_plan != null and orders._room_request != null


static func _room_request_world_matches(orders: RoomOrders, revision: int) -> bool:
	"""Scalar scope proof precedes budgeted payload comparison and the actual future source proof."""
	return orders._entry_plan.world == orders._world and orders._entry_plan.space_revision == revision if orders._entry_mode \
		else orders._room_plan.world == orders._world and orders._room_plan.space_revision == revision


static func _room_request_checks(orders: RoomOrders) -> int:
	"""Precharge the complete caller/private comparison before looking at any array element."""
	return EntryPlan.SOURCE_BYTES + orders._entry_plan.claims.size() + orders._entry_plan.opening_targets.size() \
		if orders._entry_mode else 2 * maxi(orders._room_plan.cells.size(), orders._room_request.cells.size())


static func _room_request_refusal(orders: RoomOrders) -> StringName:
	"""Exact base cells/scalars cannot stand in for the separate derived approach or entry-source proofs."""
	if orders._entry_mode:
		return &"" if EntryPlan.same(orders._entry_plan, orders._entry_request) else EntryPlan.REFUSE
	return &"" if Owner._ordinary_room_plan_matches(orders, orders._world, orders._room_plan.space_revision,
		orders._room_plan.room_type) else RoomOrders.REFUSE_PLAN


static func _room_candidate_leaf(ids: Directory, candidate: Directory.CreateCandidate) -> StringName:
	"""Rederive the exact free slot/typed row/PID from actual heaps without calling mutable packet methods."""
	if ids._free_count <= 0 or ids._kind_free_count[Directory.KIND_ROOM] <= 0 \
			or ids._next_persistent_id >= Directory.PERSISTENT_ID_EXHAUSTED:
		return Directory.REFUSAL_CANDIDATE
	var slot: int = ids._free_heap[0]
	return &"" if candidate.ref == Vector2i(slot, ids._generation[slot] + 1) \
		and candidate.kind == Directory.KIND_ROOM and candidate.typed_row == ids._heap_index[ids._kind_base[Directory.KIND_ROOM]] \
		and candidate.persistent_id == ids._next_persistent_id else Directory.REFUSAL_CANDIDATE


static func _room_companion_scope(owner: Owner, routes: Routes, locations: Locations, orders: RoomOrders,
		space_token: int, cold_token: int) -> StringName:
	"""Only idle or this exact sealed Room companions may coexist with the final current-source census."""
	var room_type: int = Buildings.ROOM_TYPE_CORRIDOR if orders._entry_mode else orders._room_plan.room_type
	if routes._in_callback or routes._callback_reentered or routes._advancing or routes._searching \
			or routes._occupancy_reading or locations._in_retention or locations._retention_reentered \
			or routes._cold != orders._room_budget:
		return REFUSE_BUSY
	if locations._token != 0 and (not locations._sealed or not locations._room_admission \
			or locations._room_orders == null or locations._room_orders.get_ref() != orders \
			or locations._cold_token != cold_token or locations._owner_token != space_token \
			or locations._admission_room != orders._stage_room or locations._admission_type != room_type \
			or locations._base_geometry_revision != owner._header[17] \
			or locations._target_geometry_revision != owner._s_header[17]):
		return REFUSE_BUSY
	if routes._token != 0 and (not routes._sealed or routes._space_token != space_token \
			or routes._location_token != locations._token or routes._cold_token != cold_token \
			or routes._operation_error != &"" or routes._base_geometry_revision != owner._header[17] \
			or routes._target_geometry_revision != owner._s_header[17]):
		return REFUSE_BUSY
	return &""


static func _room_required_checks(owner: Owner, required: int) -> int:
	"""Precharge every actual staged source/claim leaf before the first fact reader runs."""
	for row: int in owner._source_capacity:
		if owner._s_o_present[row] != 0:
			required += RESIDENT_CHECKS if owner._s_o_kind[row] == Directory.KIND_RESIDENT else SOURCE_CHECKS
	for row: int in owner._region_capacity:
		if owner._s_r_present[row] != 0 and owner._s_r_claim_kind[row] != Owner.CLAIM_NONE:
			required += SOURCE_CHECKS
	return required


static func _room_source_rows(owner: Owner, routes: Routes, locations: Locations, future: Vector2i) -> StringName:
	"""Only the exact already-pinned future Room row bypasses a live Directory identity; all other facts stay strict."""
	var sources: Owner.CoreSources = owner._sources as Owner.CoreSources
	for row: int in owner._source_capacity:
		if owner._s_o_present[row] == 0 or row == owner._room_row:
			continue
		var ref: Vector2i = Vector2i(owner._s_o_slot[row], owner._s_o_generation[row])
		if owner._s_o_present[row] != 1 or ref == future or not sources._directory.is_valid_of_kind(ref, owner._s_o_kind[row]):
			return &"SPACE_SOURCE_STALE"
		var code: StringName = _resident_into(routes, locations, ref, owner._facts) \
			if owner._s_o_kind[row] == Directory.KIND_RESIDENT else Owner.CoreSources.read_final_into(sources, ref, owner._facts)
		if code == &"":
			code = _facts_refusal(sources, ref, owner._facts)
		if code != &"":
			return code
		if not _staged_facts_match(owner, row):
			return &"SPACE_SOURCE_DRIFT"
	return &""


static func _staged_facts_match(owner: Owner, row: int) -> bool:
	"""Compare current reusable facts directly so a public Owner override cannot replace the final answer."""
	return owner._facts.kind == owner._s_o_kind[row] \
		and owner._facts.parent == Vector2i(owner._s_o_parent_slot[row], owner._s_o_parent_generation[row]) \
		and owner._facts.a == owner._s_o_a[row] and owner._facts.b == owner._s_o_b[row] \
		and owner._facts.c == owner._s_o_c[row] and owner._facts.d == owner._s_o_d[row]


static func _room_claim_rows(owner: Owner, future: Vector2i) -> StringName:
	"""Future Room markers stay exact; every retained Room/Construction claim gets its ordinary live source proof."""
	for row: int in owner._region_capacity:
		if owner._s_r_present[row] == 0:
			continue
		if owner._s_r_present[row] != 1:
			return &"SPACE_REGION_FORMAT"
		var ref: Vector2i = Vector2i(owner._s_r_owner_slot[row], owner._s_r_owner_generation[row])
		var claim: Vector2i = Vector2i(owner._s_r_claim_slot[row], owner._s_r_claim_generation[row])
		if ref == future or claim == future:
			var code: StringName = _future_marker_refusal(owner, row, future)
			if code != &"":
				return code
		elif owner._s_r_claim_kind[row] != Owner.CLAIM_NONE:
			var code: StringName = _staged_claim_refusal(owner, row, ref, claim)
			if code != &"":
				return code
	return &""


static func _future_marker_refusal(owner: Owner, row: int, future: Vector2i) -> StringName:
	"""A future Room owns only metadata and exact blocking claims linked to its own complete staged section."""
	if owner._s_r_owner_slot[row] != future.x or owner._s_r_owner_generation[row] != future.y \
			or owner._s_r_owner_revision[row] != owner._s_o_revision[owner._room_row]:
		return &"SPACE_ROOM_ADMISSION_REGION"
	if owner._s_r_role[row] == Space.FLOOR_DATUM and owner._s_r_claim_kind[row] == Owner.CLAIM_NONE \
			and Vector2i(owner._s_r_claim_slot[row], owner._s_r_claim_generation[row]) == NULL_REF:
		return &""
	var section: Vector2i = Vector2i(owner._s_r_section_slot[row], owner._s_r_section_generation[row])
	return &"" if owner._s_r_role[row] == Space.OBSTACLE and owner._s_r_claim_kind[row] == Owner.CLAIM_ROOM \
		and Vector2i(owner._s_r_claim_slot[row], owner._s_r_claim_generation[row]) == future \
		and section.x >= 0 and section.x < owner._region_capacity and owner._s_r_present[section.x] == 1 \
		and owner._s_r_generation[section.x] == section.y and owner._s_r_role[section.x] == Space.FLOOR_DATUM \
		and owner._s_r_owner_slot[section.x] == future.x and owner._s_r_owner_generation[section.x] == future.y \
		and owner._s_r_level[row] == owner._s_r_level[section.x] else &"SPACE_ROOM_ADMISSION_REGION"


static func _staged_claim_refusal(owner: Owner, row: int, ref: Vector2i, claim: Vector2i) -> StringName:
	"""Actual full source facts remain required for claims that do not belong to the sole future Room."""
	var kind: int = owner._s_r_claim_kind[row]
	if kind != Owner.CLAIM_ROOM and kind != Owner.CLAIM_CONSTRUCTION:
		return &"SPACE_RESERVATION_FORMAT"
	var sources: Owner.CoreSources = owner._sources as Owner.CoreSources
	var expected: int = Directory.KIND_ROOM if kind == Owner.CLAIM_ROOM else Directory.KIND_CONSTRUCTION
	if not sources._directory.is_valid_of_kind(claim, expected):
		return &"SPACE_SOURCE_STALE"
	var code: StringName = Owner.CoreSources.read_final_into(sources, claim, owner._facts)
	if code == &"":
		code = _facts_refusal(sources, claim, owner._facts)
	return &"SPACE_ROOM_CLAIM_IDENTITY" if code == &"" and kind == Owner.CLAIM_ROOM and claim != ref else code


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
			if owner._o_kind[row] == Directory.KIND_RESIDENT else Owner.CoreSources.read_final_into(sources, ref, owner._facts)
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
		var code: StringName = Owner.CoreSources.read_final_into(sources, ref, owner._facts)
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
	return Locations.air_record_matches(actual, actual._live, row, expected) and owner._region_live(expected.section, false) \
		and (expected.room == NULL_REF or actual._buildings.is_live_room(expected.room))


static func _resident_into(actual: Routes, locations: Locations, worker: Vector2i, out: Owner.Facts) -> StringName:
	"""Use actual packed movement and leaf Transform facts, never ResidentLocations/read_actor hooks."""
	if actual._edge_capacity <= 0 or actual._profiles == null or actual._work == null or actual._work.jobs() != actual._jobs:
		return &"ROUTE_ACTOR_UNBOUND"
	var row: int = _resident_pose_into(actual, worker)
	if row < 0:
		return &"ROUTE_ACTOR_STALE"
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


static func _resident_pose_into(actual: Routes, worker: Vector2i) -> int:
	"""Read a full mirrored Resident and its bound PID before copying any current Transform scratch."""
	var ids: Directory = actual._ids
	var transforms: Transforms = actual._transforms
	var slot: int = worker.x
	if ids == null or transforms == null or transforms._directory != ids or slot < 0 or slot >= Directory.DIRECTORY_CAPACITY:
		return -1
	if ids._active[slot] != 1 or ids._generation[slot] != worker.y or ids._kind[slot] != Directory.KIND_RESIDENT:
		return -1
	var row: int = ids._typed_row[slot]
	if row < 0 or row >= Directory.KIND_CAPACITY[Directory.KIND_RESIDENT] \
			or ids._typed_owner_slot[ids._kind_base[Directory.KIND_RESIDENT] + row] != slot:
		return -1
	var position: int = Transforms.POSITIONED_BASE[Directory.KIND_RESIDENT] + row
	if ids._persistent_id[slot] <= 0 or transforms._bound_persistent_id[position] != ids._persistent_id[slot]:
		return -1
	_copy_pose(transforms, position, actual._pose)
	return row


static func _copy_pose(transforms: Transforms, row: int, out: Transforms.Pose) -> void:
	"""The final proof bypasses overridable Transform readers and does not change Transform refusal state."""
	out.x = transforms._x[row]
	out.y = transforms._y[row]
	out.z = transforms._z[row]
	out.yaw = transforms._yaw[row]
	out.prev_x = transforms._prev_x[row]
	out.prev_y = transforms._prev_y[row]
	out.prev_z = transforms._prev_z[row]
	out.prev_yaw = transforms._prev_yaw[row]


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


static func frontier_refusal(owner: Owner, routes: Routes, locations: Locations,
		context: Locations.FrontierContext, max_checks: int) -> StringName:
	"""Distinct exact candidate scope reuses current source/claim facts without permitting prepared Space."""
	var code: StringName = _stores_refusal(owner, routes, locations)
	if code == &"": code = Locations.frontier_scope_refusal(locations, context)
	if code != &"": return code
	if context.owner != owner or context.graph != routes or owner._validation_sources >= 0 \
			or owner._validation_regions >= 0 or owner._room_callback or routes._in_callback \
			or routes._advancing or routes._searching or routes._occupancy_reading \
			or (routes._token != 0 and routes._token != context.route_token): return REFUSE_BUSY
	if max_checks > Space.MAX_CHECKS or max_checks > owner._domain._checks \
			or max_checks < _required_checks(owner): return REFUSE_BUDGET
	code = _sources_refusal(owner, routes, locations)
	return _claims_refusal(owner) if code == &"" else code
