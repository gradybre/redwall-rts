extends RefCounted
## One synchronous cold retirement scope, never a saved permission or another owner bank.
## No owner preload: Locations can require this exact Script without a Routes/Locations cycle.

const NULL_REF: Vector2i = Vector2i(-1, 0)
const REGISTERED: int = 0
const GRAPH_PREPARED: int = 1
const GRAPH_PUBLISHED: int = 2
const LOCATIONS_PREPARED: int = 3
const DONE: int = 4
const REFUSE_SCOPE: StringName = &"ENTRY_CONTACT_RETIREMENT_SCOPE"
const REFUSE_SOURCE: StringName = &"ENTRY_CONTACT_RETIREMENT_SOURCE"
const REFUSE_HISTORY: StringName = &"ENTRY_CONTACT_RETIREMENT_HISTORY"
const REFUSE_RETAINED: StringName = &"ENTRY_CONTACT_RETIREMENT_RETAINED"
const REFUSE_WORKER: StringName = &"ENTRY_CONTACT_RETIREMENT_WORKER"
const REFUSE_CAPACITY: StringName = &"ENTRY_CONTACT_RETIREMENT_CAPACITY"
const PIECES_SCRIPT: String = "res://scripts/core/underground_connector_workpieces.gd"
const ROUTES_SCRIPT: String = "res://scripts/core/underground_routes.gd"
const FRONTIER_SCRIPT: String = "res://scripts/core/underground_entry_frontier.gd"

var _context: RefCounted = null
var _context_script: Script = null
var _locations: RefCounted = null
var _graph: RefCounted = null
var _routes: RefCounted = null
var _owner: RefCounted = null
var _budget: RefCounted = null
var _live: RefCounted = null
var _candidate: RefCounted = null
var _graph_live: RefCounted = null
var _graph_candidate: RefCounted = null
var _masks_live: RefCounted = null
var _masks_candidate: RefCounted = null
var _contacts: RefCounted = null
var _placements: RefCounted = null
var _placement_bank: RefCounted = null
var _pieces: RefCounted = null
var _router: RefCounted = null
var _construction: RefCounted = null
var _funding: RefCounted = null
var _sites: RefCounted = null
var _ids: RefCounted = null
var _jobs: RefCounted = null
var _inventory: RefCounted = null
var _frontier: RefCounted = null
var _profiles: RefCounted = null
var _profile_bank: RefCounted = null
var _catalog_owner: RefCounted = null
var _catalog_bank: RefCounted = null
var _pieces_script: Script = null
var _routes_script: Script = null
var _frontier_script: Script = null
var _world: Vector2i = NULL_REF
var _placement: Vector2i = NULL_REF
var _first: Vector2i = NULL_REF
var _second: Vector2i = NULL_REF
var _project: Vector2i = NULL_REF
var _worker: Vector2i = NULL_REF
var _job: Vector2i = NULL_REF
var _room: Vector2i = NULL_REF
var _cold: int = 0
var _cold_bytes: int = 0
var _revision: int = 0
var _content: int = 0
var _catalog: int = 0
var _graph_revision: int = 0
var _location_revision: int = 0
var _route_token: int = 0
var _location_token: int = 0
var _project_row: int = -1
var _worker_row: int = -1
var _location_publish: bool = false
var _graph_publish: bool = false
var _bound: bool = false
var _poisoned: bool = false
var _source32: PackedInt32Array = PackedInt32Array()
var _source64: PackedInt64Array = PackedInt64Array()
var _source_digest: PackedByteArray = PackedByteArray()
var _placement_row: PackedInt32Array = PackedInt32Array()
var _placement_longs: PackedInt64Array = PackedInt64Array()
var _site_rows: PackedInt32Array = PackedInt32Array()
var _site_keys: PackedInt64Array = PackedInt64Array()
var _site_history: PackedInt64Array = PackedInt64Array()
var _worker_fields: PackedInt32Array = PackedInt32Array()
var _worker_longs: PackedInt64Array = PackedInt64Array()
var _heap: PackedInt32Array = PackedInt32Array()
var _piece_bounds: PackedInt32Array = PackedInt32Array()
var _air: PackedInt32Array = PackedInt32Array()


func bind_original(context: RefCounted, contacts: RefCounted, project: Vector2i,
		worker: Vector2i, job: Vector2i) -> StringName:
	"""Capture the admitted original tuple before the first graph or retention observer."""
	if _bound or context == null or contacts == null or context.budget == null \
			or context.cold <= 0 or context.budget._token != context.cold \
			or context.budget._used != context.budget.COLD_BYTES:
		return REFUSE_SCOPE
	_context = context
	_context_script = context.get_script()
	_contacts = contacts
	_project = project
	_worker = worker
	_job = job
	_copy_context()
	var code: StringName = _bind_owners()
	if code == &"": code = _initial_source()
	if code == &"": code = _capture()
	_bound = code == &""
	return contact_retirement_scope_refusal(context) if _bound else code


func _copy_context() -> void:
	"""Original mirrors never follow a subsequently mutated public Context."""
	_locations = _context.locations
	_graph = _context.graph
	_routes = _context.routes
	_owner = _context.owner
	_budget = _context.budget
	_live = _context.live
	_candidate = _context.candidate
	_graph_live = _context.graph_live
	_graph_candidate = _context.graph_candidate
	_masks_live = _context.masks_live
	_masks_candidate = _context.masks_candidate
	_world = _context.world
	_placement = _context.placement
	_first = _context.first
	_second = _context.second
	_cold = _context.cold
	_cold_bytes = _budget._used
	_revision = _context.revision
	_content = _context.profiles
	_catalog = _context.catalog
	_graph_revision = _context.graph_revision
	_location_revision = _context.location_revision
	_route_token = _routes._next_token
	_location_token = _locations._next_token


func _bind_owners() -> StringName:
	"""The private scope is derived from the real once-bound Contacts and paid owners."""
	if _contacts._placements == null or _contacts._router == null or _contacts._frontier == null:
		return REFUSE_SCOPE
	_placements = _contacts._placements
	_router = _contacts._router.get_ref()
	_frontier = _contacts._frontier
	_sites = _contacts._sites
	if _router == null or _sites == null or _placements._workpieces == null:
		return REFUSE_SCOPE
	_pieces = _placements._workpieces.get_ref()
	_construction = _router._construction
	_funding = _router._funding
	_jobs = _router._jobs
	_inventory = _router._inventory
	_ids = _placements._ids
	_profiles = _placements._profiles
	_catalog_owner = _placements._catalog
	_placement_bank = _placements._live
	_profile_bank = _profiles._live
	_catalog_bank = _catalog_owner._live
	_pieces_script = _pieces.get_script() if _pieces != null else null
	_routes_script = _routes.get_script()
	_frontier_script = _frontier.get_script()
	return _script_refusal()


func _script_refusal() -> StringName:
	"""Only original concrete static leaves are cached; a supplied arbitrary Script is never authority."""
	if _pieces_script == null or _routes_script == null or _frontier_script == null \
			or _pieces_script.resource_path != PIECES_SCRIPT or _routes_script.resource_path != ROUTES_SCRIPT \
			or _frontier_script.resource_path != FRONTIER_SCRIPT or _pieces == null \
			or _pieces.get_script() != _pieces_script or _routes.get_script() != _routes_script \
			or _frontier.get_script() != _frontier_script:
		return REFUSE_SCOPE
	return &""


func _initial_source() -> StringName:
	"""This bounded L0 operation derives its four paid cubes from the actual immutable source."""
	var code: StringName = _pieces_script.source_leaf_refusal(_pieces, _placement, _project)
	if code == &"": code = _frontier_script.source_leaf_refusal(_frontier)
	if code != &"": return code
	if not _source_shapes() or _frontier._header[8] != 2 or _frontier._header[13] != 6 \
			or _routes._edge_capacity < 1 or _routes._edge_capacity > 1536:
		return REFUSE_SOURCE
	_project_row = _directory_row(_project, 1)
	_worker_row = _directory_row(_worker, 14)
	if _project_row < 0 or _worker_row < 0 or _construction._type_id[_project_row] != 0:
		return REFUSE_SOURCE
	_room = Vector2i(_placement_bank.i32[_placements.ROOM_SLOT * _placements._capacity + _placement.x],
		_placement_bank.i32[(_placements.ROOM_SLOT + 1) * _placements._capacity + _placement.x])
	return &""


func _capture() -> StringName:
	"""Allocate fixed private cold packets only after the coordinator admits their simultaneous peak."""
	_source32.resize(446)
	_source64.resize(70)
	_source_digest.resize(320)
	_placement_row.resize(18)
	_placement_longs.resize(2)
	_site_rows.resize(4)
	_site_keys.resize(4)
	_site_history.resize(24)
	_worker_fields.resize(27)
	_worker_longs.resize(6)
	_heap.resize(_routes._edge_capacity)
	_piece_bounds.resize(6)
	_air.resize(6)
	for index: int in _source32.size(): _source32[index] = _source_i32(index)
	for index: int in _source64.size(): _source64[index] = _source_i64(index)
	for index: int in 160:
		_source_digest[index] = _frontier._digests[index]
		_source_digest[160 + index] = _pieces._digests[index]
	for field: int in 18: _placement_row[field] = _placement_bank.i32[field * _placements._capacity + _placement.x]
	for field: int in 2: _placement_longs[field] = _placement_bank.i64[field * _placements._capacity + _placement.x]
	for field: int in 27: _worker_fields[field] = _routes._motion.resident[field * 512 + _worker_row]
	for field: int in 6: _worker_longs[field] = _routes._motion.resident_long[field * 512 + _worker_row]
	return _capture_sites()


func _source_i32(index: int) -> int:
	"""Flatten only the finite accepted source form; no source row is chosen by the caller."""
	if index < 6: return _frontier._capacities[index]
	index -= 6
	if index < 18: return _frontier._install[index]
	index -= 18
	if index < 72: return _frontier._station[index]
	index -= 72
	if index < 24: return _frontier._rotation_profile[index]
	index -= 24
	if index < 14: return _frontier._cut[index]
	index -= 14
	if index < 90: return _frontier._bearing[index]
	index -= 90
	if index < 84: return _frontier._endpoint[index]
	index -= 84
	if index < 12: return _frontier._travel_profile[index]
	index -= 12
	if index < 114: return _frontier._episode[index]
	return _pieces._parts[index - 114]


func _source_i64(index: int) -> int:
	"""Include header, all directional work revisions, travel revisions and the separate handling source."""
	if index < 14: return _frontier._header[index]
	index -= 14
	if index < 32: return _frontier._profile_revision[index]
	index -= 32
	if index < 12: return _frontier._travel_revision[index]
	index -= 12
	if index < 9: return _pieces._header[index]
	return _pieces._profile_revisions[index - 9] if index < 11 else _catalog_bank.header[0]


func _capture_sites() -> StringName:
	"""Resolve every required L0 cube to permanent real paid history, never manufacture a completed row."""
	for episode: int in 4:
		if _frontier._episode[7 * 6 + episode] != 0: return REFUSE_SOURCE
		var key: int = _episode_key(episode)
		var row: int = _find_site(key)
		if row < 0: return REFUSE_HISTORY
		_site_rows[episode] = row
		_site_keys[episode] = key
		_site_history[episode * 6] = _sites._embedded_milli[row]
		for operation: int in 5:
			_site_history[episode * 6 + 1 + operation] = _sites._earned_mwu[operation * _sites._capacity + row]
	return _history_refusal()


func _episode_key(episode: int) -> int:
	"""The accepted cardinal Placement transforms an exact source cube onto the original Sites lattice."""
	var cell: Vector3i = Vector3i.ZERO
	var rotation: int = _placement_row[_placements.ROTATION]
	for axis: int in 3:
		var low: int = _frontier._episode[axis * 6 + episode]
		if axis != 1:
			var swapped: int = _frontier._episode[(2 if axis == 0 else 0) * 6 + episode]
			var high: int = _frontier._episode[(axis + 3) * 6 + episode]
			var swapped_high: int = _frontier._episode[(5 if axis == 0 else 3) * 6 + episode]
			low = low if rotation == 0 else (-swapped_high if axis == 0 else swapped) if rotation == 1 \
				else -high if rotation == 2 else (swapped if axis == 0 else -swapped_high)
		var delta: int = low + _placement_row[_placements.X + axis] - _sites._domain.datum_u[axis]
		if delta % 1024 != 0: return -1
		@warning_ignore("integer_division") var at: int = delta / 1024 - _sites._domain.minimum_quantum[axis]
		if at < 0 or at >= _sites._domain.size_quanta[axis]: return -1
		cell[axis] = at
	return (int(cell.y) * _sites._domain.size_quanta.z + cell.z) * _sites._domain.size_quanta.x + cell.x


func _find_site(key: int) -> int:
	"""Search the actual finite permanent history; an absent or duplicate key grants no contact retirement."""
	var found: int = -1
	for row: int in _sites._count:
		if _sites._present[row] != 1 or _sites._site_key[row] != key: continue
		if found >= 0: return -1
		found = row
	return found


func contact_retirement_scope_refusal(context: RefCounted) -> StringName:
	"""Every shared observation and final leaf closes current semantics against the original private tuple."""
	if not _bound or _poisoned or not _snapshot_shapes() or not _context_matches(context): return REFUSE_SCOPE
	var code: StringName = _owner_refusal()
	if code == &"": code = _phase_refusal(context)
	if code == &"": code = _source_refusal()
	if code == &"": code = _selectors_refusal()
	if code == &"": code = _project_refusal()
	if code == &"": code = _history_refusal()
	if code == &"": code = _worker_refusal()
	if code == &"": code = _retention_refusal()
	return code


func _snapshot_shapes() -> bool:
	"""Even a retained private packet exposed through Context cannot hide a shortened proof image."""
	return _source32.size() == 446 and _source64.size() == 70 and _source_digest.size() == 320 \
		and _placement_row.size() == 18 and _placement_longs.size() == 2 and _site_rows.size() == 4 \
		and _site_keys.size() == 4 and _site_history.size() == 24 and _worker_fields.size() == 27 \
		and _worker_longs.size() == 6 and _piece_bounds.size() == 6 and _air.size() == 6 \
		and _heap.size() == _routes._edge_capacity


func _context_matches(c: RefCounted) -> bool:
	"""No public Context mutation can replace an original owner, bank, full ref, lease or source revision."""
	return c != null and c == _context and c.get_script() == _context_script and c.issuer == self \
		and c.issuer_script == get_script() and c.locations == _locations and c.graph == _graph \
		and c.routes == _routes and c.owner == _owner and c.budget == _budget \
		and c.live == _live and c.candidate == _candidate and c.graph_live == _graph_live \
		and c.graph_candidate == _graph_candidate and c.masks_live == _masks_live \
		and c.masks_candidate == _masks_candidate and c.world == _world and c.placement == _placement \
		and c.first == _first and c.second == _second and c.cold == _cold and c.revision == _revision \
		and c.profiles == _content and c.catalog == _catalog and c.graph_revision == _graph_revision \
		and c.location_revision == _location_revision and _budget._token == _cold \
		and _budget._used == _cold_bytes and _cold > 0 and _first != _second


func _owner_refusal() -> StringName:
	"""Close direct reciprocal bindings before any cached concrete source or clock leaf is called."""
	if _script_refusal() != &"" or _contacts._placements != _placements or _contacts._sites != _sites \
			or _contacts._frontier != _frontier or _contacts._router == null or _contacts._router.get_ref() != _router \
			or _placements._live != _placement_bank or _placements._space != _owner \
			or _placements._locations != _locations or _placements._routes != _routes \
			or _placements._world_routes != _graph or _placements._budget != _budget \
			or _placements._ids != _ids or _placements._profiles != _profiles or _placements._catalog != _catalog_owner:
		return REFUSE_SCOPE
	if _router._construction != _construction or _router._funding != _funding or _router._jobs != _jobs \
			or _router._inventory != _inventory or _sites._construction != _construction or _sites._jobs != _jobs \
			or _sites._inventory != _inventory or _construction._directory != _ids or _jobs._directory != _ids \
			or _routes._ids != _ids or _routes._jobs != _jobs or _routes._cold != _budget \
			or _routes._locations_ref == null or _routes._locations_ref.get_ref() != _locations \
			or _routes._bindings_ref == null or _routes._bindings_ref.get_ref() != _graph \
			or _routes._owner_ref == null or _routes._owner_ref.get_ref() != _owner \
			or _routes._profiles_ref == null or _routes._profiles_ref.get_ref() != _profiles:
		return REFUSE_SCOPE
	return &""


func _phase_refusal(c: RefCounted) -> StringName:
	"""The anticipated tokens admit only the two real synchronous transitions, never a replacement preparation."""
	if _locations._live != _live or _locations._stage != _candidate or _owner._stage_token != 0 \
			or _owner._header[17] != _revision or _routes._world != _world: return REFUSE_SCOPE
	if c.phase == REGISTERED:
		return &"" if c.route_token == 0 and c.route_receipt == 0 and c.location_token == 0 \
			and _routes._token == 0 and _locations._token == 0 else REFUSE_SCOPE
	if c.route_token != _route_token: return REFUSE_SCOPE
	if c.phase == GRAPH_PREPARED:
		return &"" if c.route_receipt == 0 and c.location_token == 0 and _routes._token == _route_token \
			and _routes._live == _graph_live and _routes._stage == _graph_candidate \
			and _graph._live == _masks_live and _graph._stage == _masks_candidate else REFUSE_SCOPE
	if c.phase != GRAPH_PUBLISHED and c.phase != LOCATIONS_PREPARED: return REFUSE_SCOPE
	if c.route_receipt != _route_token or _routes._last_published_token != _route_token or _routes._token != 0 \
			or _routes._live != _graph_candidate or _routes._stage != _graph_live \
			or _graph._live != _masks_candidate or _graph._stage != _masks_live \
			or _routes._live.revision != _graph_revision + 1: return REFUSE_SCOPE
	if c.phase == GRAPH_PUBLISHED:
		return &"" if c.location_token == 0 and _locations._token == 0 else REFUSE_SCOPE
	return &"" if c.location_token == _location_token and _locations._token == _location_token \
		and _locations._cold_token == _cold else REFUSE_SCOPE


func _source_refusal() -> StringName:
	"""Source content and exact original banks remain unchanged, independently of matching revision numbers."""
	if not _source_shapes() or _profiles._live != _profile_bank or _catalog_owner._live != _catalog_bank \
			or _profiles._live.header[0] != _content or _graph._live_catalog_revision != _catalog \
			or _frontier._digests.size() != 160 or _pieces._digests.size() != 160: return REFUSE_SOURCE
	var code: StringName = _pieces_script.source_leaf_refusal(_pieces, _placement, _project)
	if code == &"": code = _frontier_script.source_leaf_refusal(_frontier)
	if code != &"": return code
	for index: int in _source32.size():
		if _source32[index] != _source_i32(index): return REFUSE_SOURCE
	for index: int in _source64.size():
		if _source64[index] != _source_i64(index): return REFUSE_SOURCE
	for index: int in 160:
		if _source_digest[index] != _frontier._digests[index] \
				or _source_digest[160 + index] != _pieces._digests[index]: return REFUSE_SOURCE
	for field: int in 18:
		if _placement_row[field] != _placement_bank.i32[field * _placements._capacity + _placement.x]: return REFUSE_SOURCE
	for field: int in 2:
		if _placement_longs[field] != _placement_bank.i64[field * _placements._capacity + _placement.x]: return REFUSE_SOURCE
	return &""


func _source_shapes() -> bool:
	"""Check all finite source payload lengths before any static source leaf or indexed replay."""
	return _frontier._capacities.size() == 6 and _frontier._header.size() == 14 \
		and _frontier._capacities[0] == 2 and _frontier._capacities[1] == 8 \
		and _frontier._capacities[2] == 2 and _frontier._capacities[3] == 10 \
		and _frontier._capacities[4] == 12 and _frontier._capacities[5] == 6 \
		and _frontier._install.size() == 18 and _frontier._station.size() == 72 \
		and _frontier._rotation_profile.size() == 24 and _frontier._cut.size() == 14 \
		and _frontier._bearing.size() == 90 and _frontier._endpoint.size() == 84 \
		and _frontier._travel_profile.size() == 12 and _frontier._episode.size() == 114 \
		and _frontier._profile_revision.size() == 32 and _frontier._travel_revision.size() == 12 \
		and _frontier._digests.size() == 160 and _pieces._header.size() == 9 \
		and _pieces._parts.size() == 12 and _pieces._profile_revisions.size() == 2 \
		and _pieces._digests.size() == 160


func _selectors_refusal() -> StringName:
	"""Re-derive both contacts from complete source travel air and the exact unfunded piece every time."""
	var code: StringName = _pieces_script.candidate_bounds_into(_pieces, _placement, 0, _piece_bounds)
	if code != &"": return code
	var count: int = 0
	var first_found: bool = false
	var second_found: bool = false
	for selector: int in 12:
		if _frontier._endpoint[3 * 12 + selector] != 2: continue
		code = _travel_air_into(selector)
		if code != &"": return code
		if not _air_overlaps_piece(selector): continue
		if not _unused_completed_selector(selector): return REFUSE_RETAINED
		var handle: Vector2i = _resolve_selector(selector)
		if handle == NULL_REF or not selected(handle): return REFUSE_SOURCE
		first_found = first_found or handle == _first
		second_found = second_found or handle == _second
		count += 1
	return &"" if count == 2 and first_found and second_found else REFUSE_SOURCE


func _travel_air_into(selector: int) -> StringName:
	"""The complete positive BODY/recovery/approach union includes held-pick rows; feet remain separate."""
	var profile: int = _frontier._travel_profile[selector]
	if profile < 0 or profile >= _profile_bank.header[1] \
			or _profile_bank.quantities[profile] != _frontier._travel_revision[selector]: return REFUSE_SOURCE
	var first: int = _profile_bank.fields[14 * _profiles._profile_capacity + profile]
	var count: int = _profile_bank.fields[15 * _profiles._profile_capacity + profile]
	if count < 1 or first < 0 or first + count > _profile_bank.header[2]: return REFUSE_SOURCE
	_air.fill(0)
	var found: bool = false
	for row: int in range(first, first + count):
		var role: int = _profile_bank.boxes[6 * _profiles._box_capacity + row]
		if role != 0 and role != 2 and role != 3: continue
		if _profile_bank.boxes[4 * _profiles._box_capacity + row] <= 0: continue
		for axis: int in 3:
			var low: int = _profile_bank.boxes[axis * _profiles._box_capacity + row]
			var high: int = _profile_bank.boxes[(axis + 3) * _profiles._box_capacity + row]
			if axis == 1: low = maxi(low, 0)
			_air[axis] = mini(_air[axis], low) if found else low
			_air[axis + 3] = maxi(_air[axis + 3], high) if found else high
		found = true
	return &"" if found else REFUSE_SOURCE


func _air_overlaps_piece(selector: int) -> bool:
	"""This is only a conservative retirement selector, never permission to clip physical source geometry."""
	for axis: int in 3:
		var point: int = _selector_axis(selector, axis)
		if point + _air[axis] >= _piece_bounds[axis + 3] or _piece_bounds[axis] >= point + _air[axis + 3]:
			return false
	return true


func _selector_axis(selector: int, axis: int) -> int:
	"""Apply the original immutable Placement cardinal transform exactly once to the source endpoint."""
	var x: int = _frontier._endpoint[4 * 12 + selector]
	var z: int = _frontier._endpoint[6 * 12 + selector]
	var rotation: int = _placement_row[_placements.ROTATION]
	var value: int = _frontier._endpoint[5 * 12 + selector] if axis == 1 \
		else (x if rotation == 0 else -z if rotation == 1 else -x if rotation == 2 else z) if axis == 0 \
		else (z if rotation == 0 else x if rotation == 1 else -z if rotation == 2 else -x)
	return value + _placement_row[_placements.X + axis]


func _resolve_selector(selector: int) -> Vector2i:
	"""Resolve one exact source geometry to a unique original live full handle; aliases are not first-match permission."""
	var result: Vector2i = NULL_REF
	for row: int in _locations._capacity:
		if _live.present[row] != 1 or not _selector_row_matches(selector, row): continue
		if result != NULL_REF: return NULL_REF
		result = Vector2i(row, _live.i32[row])
	return result


func _selector_row_matches(selector: int, row: int) -> bool:
	"""Surface contacts retain the exact World floor section and role, not merely matching coordinates."""
	var capacity: int = _locations._capacity
	var anchor: Vector2i = Vector2i(_placement_row[_placements.ANCHOR_SLOT],
		_placement_row[_placements.ANCHOR_SLOT + 1])
	if anchor.x < 0 or anchor.x >= capacity or _live.present[anchor.x] != 1 \
			or _live.i32[anchor.x] != anchor.y or _frontier._endpoint[selector] != 2 \
			or _live.i32[9 * capacity + row] != _frontier._endpoint[3 * 12 + selector] \
			or _live.i32[4 * capacity + row] != -1 or _live.i32[5 * capacity + row] != 0 \
			or _live.i32[8 * capacity + row] != 0 or _live.i64[row] <= 0 \
			or _live.i64[capacity + row] != _revision: return false
	for field: int in range(6, 8):
		if _live.i32[field * capacity + row] != _live.i32[field * capacity + anchor.x]: return false
	for axis: int in 3:
		if _live.i32[(axis + 1) * capacity + row] != _selector_axis(selector, axis): return false
	return true


func _same_selector(first: int, second: int) -> bool:
	"""Immutable selectors may differ in travel policy while retaining the same real endpoint."""
	if first < 0 or first >= 12 or second < 0 or second >= 12: return false
	for field: int in 7:
		if _frontier._endpoint[field * 12 + first] != _frontier._endpoint[field * 12 + second]: return false
	return true


func _station_uses(station: int, selector: int) -> bool:
	"""A malformed source station is retained conservatively; it cannot authorize removal."""
	return station < 0 or station >= 8 or _same_selector(_frontier._station[station], selector)


func _unused_completed_selector(selector: int) -> bool:
	"""No INSTALL, future phase, material or spoil alias may require a completed work contact."""
	var used: bool = false
	for install: int in 2:
		if _station_uses(_frontier._install[install], selector) \
				or _same_selector(_frontier._install[7 * 2 + install], selector) \
				or _same_selector(_frontier._install[8 * 2 + install], selector): return false
	for episode: int in 6:
		if _same_selector(_frontier._episode[15 * 6 + episode], selector) \
				or _same_selector(_frontier._episode[16 * 6 + episode], selector): return false
		for field: int in range(8, 11):
			if not _station_uses(_frontier._episode[field * 6 + episode], selector): continue
			if episode >= 4: return false
			used = true
		if _same_selector(_frontier._episode[17 * 6 + episode], selector):
			if episode >= 4: return false
			used = true
	return used


func _project_refusal() -> StringName:
	"""Retirement changes traversal metadata only while the exact original L0 Project is unfunded and ready."""
	if _directory_row(_project, 1) != _project_row or _construction._phase[_project_row] != 1 \
			or _construction._paused[_project_row] != 0 or _construction._work_begun[_project_row] != 0 \
			or _construction._type_id[_project_row] != 0 or _construction._assigned_count[_project_row] != 1 \
			or _funding._project_slot[_project_row] != -1 or _funding._project_generation[_project_row] != 0 \
			or _funding._head[_project_row] != -1 or _funding._output_slot[_project_row] != -1 \
			or _funding._output_generation[_project_row] != 0 or _funding._output_mass_g[_project_row] != 0 \
			or _pieces._live.present[_placement.x] != 0 or _pieces._stage_action != -1 \
			or _pieces._busy or _pieces._context != null or _placements._busy or _router._busy:
		return REFUSE_SCOPE
	return &""


func _history_refusal() -> StringName:
	"""Each actual permanent cube retains all paid labor/material history and no active phase or output."""
	if _sites._starting or _sites._settling or _sites._permit_action != -1 or _sites._publishing_spatial:
		return REFUSE_HISTORY
	for episode: int in 4:
		var row: int = _site_rows[episode]
		if row < 0 or row >= _sites._count or _sites._present[row] != 1 or _sites._phase[row] != 8 \
				or _sites._site_key[row] != _site_keys[episode] or _episode_key(episode) != _site_keys[episode] \
				or _sites._room_slot[row] != _room.x or _sites._room_generation[row] != _room.y \
				or _sites._installed[row] != 1 or _sites._ever_cut[row] != 1 \
				or _sites._project_slot[row] != -1 or _sites._project_generation[row] != 0 \
				or _sites._job_slot[row] != -1 or _sites._job_generation[row] != 0 \
				or _sites._output_slot[row] != -1 or _sites._output_generation[row] != 0 \
				or _sites._operation[row] != -1 or _sites._promotion_tile[row] != -1 \
				or _sites._embedded_milli[row] != _site_history[episode * 6]: return REFUSE_HISTORY
		for operation: int in 5:
			if _sites._earned_mwu[operation * _sites._capacity + row] != _site_history[episode * 6 + 1 + operation]:
				return REFUSE_HISTORY
	return &""


func _worker_refusal() -> StringName:
	"""The original BUILD assignment, full committed physical tuple and canonical READY stay exact."""
	if _directory_row(_worker, 14) != _worker_row or _routes._advancing or _routes._searching:
		return REFUSE_WORKER
	var code: StringName = _pieces_script._assigned_worker_leaf(_pieces, _project, _worker, _job)
	if code != &"": return code
	for field: int in 27:
		if _worker_fields[field] != _routes._motion.resident[field * 512 + _worker_row]: return REFUSE_WORKER
	for field: int in 6:
		if _worker_longs[field] != _routes._motion.resident_long[field * 512 + _worker_row]: return REFUSE_WORKER
	if _resolve_selector(0) != Vector2i(_worker_fields[2], _worker_fields[3]): return REFUSE_WORKER
	return _routes_script.source_ready_leaf_refusal(_routes, _worker, _job,
		_worker_fields[13], _worker_longs[0], _worker_longs[1])


func _retention_refusal() -> StringName:
	"""No live Site registration, worker endpoint or actual storage alias may still need either contact."""
	for row: int in _sites._job_site.size():
		if _is_completed_row(_sites._job_site[row]): return REFUSE_RETAINED
	for row: int in _sites._worker_site.size():
		if _is_completed_row(_sites._worker_site[row]): return REFUSE_RETAINED
	for row: int in _inventory._spatial_location_slot.size():
		if selected(Vector2i(_inventory._spatial_location_slot[row], _inventory._spatial_location_generation[row])):
			return REFUSE_RETAINED
	for row: int in 512:
		if _routes._motion.resident[row] < 0: continue
		if selected(Vector2i(_routes._motion.resident[2 * 512 + row], _routes._motion.resident[3 * 512 + row])):
			return REFUSE_RETAINED
	return &""


func _is_completed_row(row: int) -> bool:
	"""A stale registration into any completed source cube refuses rather than being silently detached."""
	return row >= 0 and (row == _site_rows[0] or row == _site_rows[1] or row == _site_rows[2] or row == _site_rows[3])


func _directory_row(ref: Vector2i, kind: int) -> int:
	"""Full Directory generations and kind are checked directly, without an overridable identity reader."""
	if ref.x < 0 or ref.x >= _ids._active.size() or ref.y <= 0 or _ids._active[ref.x] != 1 \
			or _ids._generation[ref.x] != ref.y or _ids._kind[ref.x] != kind: return -1
	return _ids._typed_row[ref.x]


func selected(location: Vector2i) -> bool:
	"""Only the two derived original full handles are selected; slot reuse never matches."""
	return location == _first or location == _second


func contact_retirement_graph_publish_refusal(context: RefCounted) -> StringName:
	"""A generic observed publish call cannot borrow the private graph publication window."""
	if not _graph_publish or _location_publish or context != _context or context.phase != GRAPH_PREPARED:
		return REFUSE_SCOPE
	return contact_retirement_scope_refusal(context)


func contact_retirement_publish_refusal(context: RefCounted) -> StringName:
	"""The private Location window still rechecks all current owner, worker and paid-history facts."""
	if not _location_publish or _graph_publish or context != _context or context.phase != LOCATIONS_PREPARED:
		return REFUSE_SCOPE
	return contact_retirement_scope_refusal(context)


func owns_location_preparation(context: RefCounted, token: int, cold: int) -> bool:
	"""Expired cleanup trusts only private originals, never the mutable Context token or replacement lease."""
	return _bound and context == _context and context != null and context.get_script() == _context_script \
		and _locations != null and token == _location_token and token > 0 and cold == _cold \
		and _locations._token == token and _locations._cold_token == cold \
		and _locations._live == _live and _locations._stage == _candidate


func clear_original() -> void:
	"""Break the borrowed Context/issuer cycle after original owners discard, including expired refusals."""
	if _context != null and _context.issuer == self: _context.issuer = null
	_context = null
	_bound = false
	_graph_publish = false
	_location_publish = false
