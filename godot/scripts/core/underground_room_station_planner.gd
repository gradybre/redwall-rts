extends RefCounted
## ADR1213 Room-station planner: one Site face and yaw become the bounded ADR1161 publication Request.
## Static and synchronous. Geometry comes only from published Profile boxes and live Space/Location rows;
## nothing is published, reserved or permitted here. publish_into remains the complete physical proof.

const Frontier := preload("res://scripts/core/underground_room_frontier.gd")
const Publication := preload("res://scripts/core/underground_room_frontier_publication.gd")
const Provider := preload("res://scripts/core/underground_room_world_bindings.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const StepProgram := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Face := preload("res://scripts/core/underground_work_face.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const MAX_STATIONS: int = Publication.MAX_STATIONS
const MAX_CHAIN: int = MAX_STATIONS + 2 # Room to detect, and name, a chain one or two stations too long.
const MAX_REGIONS: int = 192 # Per kind (void, support, blocker, section) inside the query hull.
const MAX_FRAGMENTS: int = 96
const MAX_CANDIDATES: int = 2048
const MAX_EDGES: int = 256
const MAX_PRIMITIVES: int = 32 # Air primitives of one station's adjoining sources, before merging.
const AIR_BOXES: int = Publication.AIR_BOXES
## Declared logical cold slice (45,752 B): four region tables and their section refs, two fragment arenas,
## candidate keys, edge/plane scratch, the chain packets and their ADR1215 air boxes, the primitive scratch,
## eight six-int boxes and a 1,024 B scalar/reference allowance.
## Not a native measurement. The Query dies before publish_into admits its own lifetime in the same lease.
const CONTROL_BYTES: int = 4 * 6 * MAX_REGIONS * 4 + 2 * MAX_REGIONS * 4 + 2 * 6 * MAX_FRAGMENTS * 4 \
	+ MAX_CANDIDATES * 8 + 2 * MAX_EDGES * 4 + MAX_CHAIN * (3 * 4 + 4 * 8 + 2 * 4 + 4 + AIR_BOXES * 6 * 4) \
	+ MAX_PRIMITIVES * 6 * 4 + 8 * 6 * 4 + 1024
const IDENTITY_FIELDS: Array[int] = [Profiles.F_SOURCE, Profiles.F_SPECIES, Profiles.F_STAGE, Profiles.F_RIG,
	Profiles.F_POSTURE, Profiles.F_TOOL, Profiles.F_TOOL_VARIANT, Profiles.F_CARGO, Profiles.F_CARGO_VARIANT]
const REFUSE_SCOPE: StringName = &"ROOM_STATION_SCOPE"
const REFUSE_VERTICAL: StringName = &"ROOM_STATION_VERTICAL_FACE"
const REFUSE_CAPACITY: StringName = &"ROOM_STATION_OPERATION_CAPACITY"
const REFUSE_HEADING: StringName = &"ROOM_STATION_RETREAT_HEADING"
const REFUSE_TRAVEL: StringName = &"ROOM_STATION_TRAVEL_SOURCE"
const REFUSE_GATEWAY: StringName = &"ROOM_STATION_GATEWAY"
const REFUSE_REACH: StringName = &"ROOM_STATION_REACH_MISSING"
const REFUSE_CLOSED: StringName = &"ROOM_STATION_GEOMETRY_CLOSED"
const REFUSE_SECTION: StringName = &"ROOM_STATION_SECTION"
const REFUSE_GROUND: StringName = &"ROOM_STATION_GROUND_SOURCE_MISSING"
const REFUSE_STEP: StringName = &"ROOM_STATION_SHORT_STEP_MISSING"
const REFUSE_ENVELOPE: StringName = &"ROOM_STATION_LOCATION_ENVELOPE"
const REFUSE_CHAIN: StringName = &"ROOM_STATION_CHAIN_CAPACITY"
## ADR1220 earth benches: a WORK row reaches the cube only from a bench top a whole number of cubes above the Room
## floor, and no published travel row of the retreat row's identity climbs (no certified MODE_CLIMB row).
const REFUSE_BENCH_ASCENT: StringName = &"ROOM_STATION_BENCH_ASCENT_MISSING"
## ADR1220: a climbing row exists, but a bench top has no published footing (an unpaid Kitchen cube is a Room
## reservation marker, not SUPPORT) and no FLOOR_DATUM section at the bench rise to plan stations on.
const REFUSE_BENCH_FOOTING: StringName = &"ROOM_STATION_BENCH_FOOTING_MISSING"
## Refusal precedence: the most advanced failure over every work row and root candidate is reported.
const RANKED: Array[StringName] = [REFUSE_REACH, REFUSE_CLOSED, REFUSE_SECTION, REFUSE_GROUND, REFUSE_STEP,
	REFUSE_ENVELOPE, REFUSE_CHAIN]


class Query extends RefCounted:
	## Private cold packet; dies before publish_into allocates. No owner, bank or caller packet is retained after return.
	var profiles: Profiles = null
	var owner: Owner = null
	var origin: Vector3i = Vector3i.ZERO
	var axis: int = 0
	var lateral: int = 2
	var direction: int = 1
	var face: int = -1
	var yaw: int = -1
	var gateway: Vector2i = NULL_REF
	var entry: Vector2i = NULL_REF # The published chain's gateway: the retreat, or an existing station on the chain.
	var locations: Locations = null
	var start: Vector3i = Vector3i.ZERO
	var level: int = -1
	var backward: int = -1
	var forward: int = -1
	var short_forward: int = -1
	var short_backward: int = -1
	var ground: int = -1
	var work: int = -1
	var anchor: Vector3i = Vector3i.ZERO
	var root: Vector3i = Vector3i.ZERO
	var target: PackedInt32Array = PackedInt32Array()
	var hull: PackedInt32Array = PackedInt32Array()
	var tables: Array[PackedInt32Array] = [] # void, support, blocker, section boxes
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var section_refs: PackedInt32Array = PackedInt32Array()
	var front: PackedInt32Array = PackedInt32Array()
	var back: PackedInt32Array = PackedInt32Array()
	var other: PackedInt32Array = PackedInt32Array()
	var envelope: PackedInt32Array = PackedInt32Array()
	var footing: PackedInt32Array = PackedInt32Array()
	var keys: PackedInt64Array = PackedInt64Array()
	var edges: PackedInt32Array = PackedInt32Array()
	var planes: PackedInt32Array = PackedInt32Array()
	var points: PackedInt32Array = PackedInt32Array()
	var spans: PackedInt64Array = PackedInt64Array()
	var sections: PackedInt32Array = PackedInt32Array()
	var air_counts: PackedInt32Array = PackedInt32Array()
	var air: PackedInt32Array = PackedInt32Array()
	var primitives: PackedInt32Array = PackedInt32Array()
	var merged: PackedInt32Array = PackedInt32Array()
	var stations: int = 0
	var box: PackedInt32Array = PackedInt32Array()
	var remaining: int = 0
	var rank: int = -1
	var exhausted: bool = false
	var bench: int = -1 # ADR1220: smallest whole-cube bench rise from which some eligible WORK row reaches the cube.
	var bench_work: int = -1


const VOID: int = 0
const SUPPORT: int = 1
const BLOCKER: int = 2
const SECTION: int = 3


static func plan_into(actual: Provider, candidate: Frontier.Candidate, face: int, yaw: int,
		cold: int, max_checks: int, out: Publication.Request) -> StringName:
	"""Derive one bounded station chain for the candidate Site; every refusal leaves the caller Request unchanged."""
	var q: Query = Query.new()
	var code: StringName = _open(q, actual, candidate, face, yaw, cold, max_checks,
		out != null and out.get_script() == Publication.Request)
	if code == &"": code = _plan(q)
	if code == &"": _output(q, out)
	return code


static func bench_into(actual: Provider, candidate: Frontier.Candidate, face: int, yaw: int,
		cold: int, max_checks: int, out: PackedInt32Array) -> StringName:
	"""ADR1220: the smallest whole-cube bench rise, its WORK row and the climbing row ([rise, work, climb], -1 when
	absent) for a cube no floor station reaches. A floor-reachable cube writes rise 0; refusals write nothing."""
	var q: Query = Query.new()
	var code: StringName = _open(q, actual, candidate, face, yaw, cold, max_checks, out.size() == 3)
	if code != &"": return code
	for row: int in q.profiles._live.header[1]:
		if not _spend(q, 8): return REFUSE_CAPACITY
		if not _work_row(q, row): continue
		if _reaches(q):
			q.bench = 0; q.bench_work = row; break
		_bench_note(q, row)
	out[0] = q.bench; out[1] = q.bench_work; out[2] = _climb_row(q) if q.bench > 0 else -1
	return &""


static func _open(q: Query, actual: Provider, candidate: Frontier.Candidate, face: int, yaw: int,
		cold: int, max_checks: int, out_ok: bool) -> StringName:
	"""Shared scope, lease and candidate validation, then the bound sources, gateway and hull regions."""
	var code: StringName = Frontier._guard(actual, cold, CONTROL_BYTES, max_checks)
	if code != &"": return code
	if candidate == null or candidate.get_script() != Frontier.Candidate or not out_ok or face < 0 or face > 5 \
			or yaw < 0 or yaw > 65535: return REFUSE_SCOPE
	code = Frontier._candidate_leaf(actual, candidate, cold)
	if code != &"": return code
	if candidate.project != NULL_REF or candidate.operation != Contract.OP_BRACE: return REFUSE_SCOPE
	if face == 2 or face == 3: return REFUSE_VERTICAL # Roots are planned on the Room floor against side faces only.
	_hold(q, actual, candidate, face, yaw, max_checks)
	code = _sources(q, actual)
	if code == &"": code = _gateway(q, actual)
	if code == &"": code = _regions(q)
	return code


static func next_contact_into(actual: Provider, room: Vector2i, after_key: int, cold: int, max_checks: int,
		candidate: Frontier.Candidate, contact: Face.Request, request: Publication.Request,
		result: Publication.Result) -> StringName:
	"""One foreman step: the next unpaid Site and a proved contact, publishing a planned chain when none exists yet."""
	var code: StringName = Frontier.next_site_into(actual, room, after_key, cold, max_checks, candidate)
	if code != &"": return code
	var q: Query = Query.new()
	q.profiles = actual._ordinary_config.profiles
	q.yaw = _retreat_yaw(actual)
	code = _sources(q, actual)
	if code != &"": return code
	var revision: int = q.profiles._live.quantities[q.forward]
	code = Frontier.contact_into(actual, candidate, actual._ordinary_retreat, q.forward, revision, cold, max_checks, contact)
	if code != Frontier.REFUSE_CONTACT: return code
	code = plan_into(actual, candidate, facing_face(actual, q.yaw), q.yaw, cold, max_checks, request)
	if code == &"": code = Publication.publish_into(actual, candidate, request, cold, max_checks, result)
	if code == &"": code = Frontier.next_site_into(actual, room, candidate.key - 1, cold, max_checks, candidate)
	if code == &"": code = Frontier.contact_into(actual, candidate, actual._ordinary_retreat, q.forward, revision, cold, max_checks, contact)
	return code


static func _retreat_yaw(actual: Provider) -> int:
	"""The bound retreat row's exact heading, or -1."""
	var profiles: Profiles = actual._ordinary_config.profiles
	var row: int = actual._ordinary_travel
	if row < 0 or row >= profiles._live.header[1] \
			or profiles._live.fields[Profiles.F_YAW_KIND * profiles._profile_capacity + row] != Profiles.YAW_EXACT: return -1
	return profiles._live.fields[Profiles.F_YAW * profiles._profile_capacity + row]


static func facing_face(actual: Provider, yaw: int) -> int:
	"""The cube face a worker of this yaw strikes: the dominant horizontal axis and sign of a WORK row's anchor."""
	var profiles: Profiles = actual._ordinary_config.profiles
	var stride: int = profiles._profile_capacity
	for row: int in profiles._live.header[1]:
		if profiles._live.fields[Profiles.F_MODE * stride + row] != Profiles.MODE_WORK \
				or profiles._live.fields[Profiles.F_YAW_KIND * stride + row] != Profiles.YAW_EXACT \
				or profiles._live.fields[Profiles.F_YAW * stride + row] != yaw: continue
		for index: int in profiles._live.fields[Profiles.F_BOX_COUNT * stride + row]:
			var box: int = profiles._live.fields[Profiles.F_FIRST_BOX * stride + row] + index
			if profiles._live.boxes[6 * profiles._box_capacity + box] != Profiles.CONTACT_POINT: continue
			var x: int = profiles._live.boxes[box]
			var z: int = profiles._live.boxes[2 * profiles._box_capacity + box]
			if absi(x) >= absi(z): return 0 if x > 0 else 1
			return 4 if z > 0 else 5
	return -1


static func _hold(q: Query, actual: Provider, candidate: Frontier.Candidate, face: int, yaw: int, checks: int) -> void:
	"""Pin the original immutable owners and allocate every fixed scratch packet once."""
	q.profiles = actual._ordinary_config.profiles; q.owner = actual._ordinary_config.owner
	q.locations = actual._ordinary_config.locations
	q.origin = Frontier._origin(actual._ordinary_original_sites(), candidate.key)
	@warning_ignore("integer_division") var axis: int = face / 2
	q.face = face; q.yaw = yaw; q.axis = axis; q.lateral = 2 if axis == 0 else 0
	q.direction = 1 if face % 2 == 0 else -1
	q.remaining = checks - Frontier._scope_checks(actual)
	q.target.resize(6); q.hull.resize(6); q.box.resize(6); q.other.resize(6); q.envelope.resize(6); q.footing.resize(6)
	for axis_index: int in 3:
		q.target[axis_index] = q.origin[axis_index]
		q.target[axis_index + 3] = int(q.origin[axis_index]) + Contract.QUANTUM_SIDE_U
	q.tables.resize(4)
	for kind: int in 4:
		var table: PackedInt32Array = PackedInt32Array()
		table.resize(6 * MAX_REGIONS)
		q.tables[kind] = table
	q.section_refs.resize(2 * MAX_REGIONS)
	q.front.resize(6 * MAX_FRAGMENTS); q.back.resize(6 * MAX_FRAGMENTS)
	q.keys.resize(MAX_CANDIDATES); q.edges.resize(MAX_EDGES); q.planes.resize(MAX_EDGES)
	q.points.resize(3 * MAX_CHAIN); q.spans.resize(4 * MAX_CHAIN); q.sections.resize(2 * MAX_CHAIN)
	q.air_counts.resize(MAX_CHAIN); q.air.resize(MAX_CHAIN * AIR_BOXES * 6); q.primitives.resize(MAX_PRIMITIVES * 6); q.merged.resize(6)


static func _spend(q: Query, checks: int) -> bool:
	"""One monotone finite counter covers scans, coverage and candidate ordering."""
	if q.exhausted or q.remaining < checks:
		q.exhausted = true; return false
	q.remaining -= checks
	return true


static func _field(q: Query, profile: int, field: int) -> int:
	"""Borrow one immutable Profile column without a descriptor copy."""
	return q.profiles._live.fields[field * q.profiles._profile_capacity + profile]


static func _sources(q: Query, actual: Provider) -> StringName:
	"""The bound retreat row fixes the heading family; every leg profile is selected from that family alone."""
	q.backward = actual._ordinary_travel
	var profiles: Profiles = q.profiles
	if q.backward < 0 or q.backward >= profiles._live.header[1]: return REFUSE_TRAVEL
	if _field(q, q.backward, Profiles.F_YAW_KIND) != Profiles.YAW_EXACT: return REFUSE_HEADING
	if _field(q, q.backward, Profiles.F_YAW) != q.yaw: # ADR1213: the bound row's backward sibling at this heading.
		q.backward = Itinerary.family_row(profiles, q.backward, q.yaw, Profiles.POLICY_READY_BACKWARD)
		if q.backward < 0: return REFUSE_HEADING
	for row: int in profiles._live.header[1]:
		if not Itinerary._compatible(profiles, q.backward, row): continue
		var policy: int = Profiles.selection_policy_leaf(profiles, row, profiles._live.quantities[row], profiles._live.header[0])
		var exact: bool = _field(q, row, Profiles.F_YAW_KIND) == Profiles.YAW_EXACT and _field(q, row, Profiles.F_YAW) == q.yaw
		if exact and policy == Profiles.POLICY_READY_FORWARD and q.forward < 0: q.forward = row
		elif exact and policy == Profiles.POLICY_SHORT_FORWARD and q.short_forward < 0: q.short_forward = row
		elif exact and policy == Profiles.POLICY_SHORT_BACKWARD and q.short_backward < 0: q.short_backward = row
		elif _field(q, row, Profiles.F_YAW_KIND) == Profiles.YAW_ALL and q.ground < 0 \
				and _field(q, row, Profiles.F_MODE) == Profiles.MODE_WALK: q.ground = row
	if q.short_forward < 0 or q.short_backward < 0:
		q.short_forward = -1; q.short_backward = -1
	return &"" if q.forward >= 0 else REFUSE_TRAVEL


static func _gateway(q: Query, actual: Provider) -> StringName:
	"""The provider's bound retreat endpoint anchors the chain: its plane and level fix every station."""
	var locations: Locations = actual._ordinary_config.locations
	q.gateway = actual._ordinary_retreat
	if not locations._live_ref(locations._live, q.gateway): return REFUSE_GATEWAY
	var row: int = q.gateway.x
	q.start = Vector3i(locations._get32(locations._live, Locations.X, row),
		locations._get32(locations._live, Locations.Y, row), locations._get32(locations._live, Locations.Z, row))
	q.level = locations._get32(locations._live, Locations.LEVEL, row)
	return &"" if q.start.y <= q.origin.y else REFUSE_GATEWAY


static func _regions(q: Query) -> StringName:
	"""Copy only live rows that can meet any profile box between the gateway and the target cube."""
	_hull(q)
	var owner: Owner = q.owner
	for row: int in owner._region_capacity:
		if not _spend(q, 4): return REFUSE_CAPACITY
		if owner._r_present[row] != 1: continue
		var role: int = owner._r_role[row]
		var kind: int = SECTION if role == Space.FLOOR_DATUM else VOID if role == Space.SUPPORTED_VOID \
			else SUPPORT if role == Space.SUPPORT else BLOCKER
		if kind == BLOCKER and role == Space.OBSTACLE and owner._r_claim_kind[row] == Owner.CLAIM_ROOM: continue
		if kind == SECTION and (owner._r_claim_kind[row] != Owner.CLAIM_NONE or owner._r_level[row] != q.level \
				or owner._r_lo_y[row] != q.start.y): continue
		_region_box(owner, row, q.box)
		if not Space.overlaps(q.box, q.hull): continue
		if q.counts[kind] >= MAX_REGIONS: return REFUSE_CAPACITY
		_put(q.tables[kind], q.counts[kind], q.box)
		if kind == SECTION:
			q.section_refs[2 * q.counts[kind]] = row; q.section_refs[2 * q.counts[kind] + 1] = owner._r_generation[row]
		q.counts[kind] += 1
	return &""


static func _hull(q: Query) -> void:
	"""Gateway and target cube, widened by the largest published box extent of any row in the bank."""
	var reach: int = 0
	var profiles: Profiles = q.profiles
	for box: int in profiles._live.header[2]:
		for axis: int in 6:
			reach = maxi(reach, absi(profiles._live.boxes[axis * profiles._box_capacity + box]))
	for axis: int in 3:
		q.hull[axis] = mini(q.start[axis], q.target[axis]) - reach - 1
		q.hull[axis + 3] = maxi(q.start[axis], q.target[axis + 3]) + reach + 1


static func _region_box(owner: Owner, row: int, out: PackedInt32Array) -> void:
	"""Read one live half-open extent into reused scratch."""
	out[0] = owner._r_lo_x[row]; out[1] = owner._r_lo_y[row]; out[2] = owner._r_lo_z[row]
	out[3] = owner._r_hi_x[row]; out[4] = owner._r_hi_y[row]; out[5] = owner._r_hi_z[row]


static func _put(table: PackedInt32Array, index: int, box: PackedInt32Array) -> void:
	"""Write one box into a fixed table row."""
	for axis: int in 6: table[index * 6 + axis] = box[axis]


static func _plan(q: Query) -> StringName:
	"""Try every eligible WORK row in ascending ID; the first row with an admissible chain wins."""
	for row: int in q.profiles._live.header[1]:
		if not _spend(q, 8): return REFUSE_CAPACITY
		if not _work_row(q, row): continue
		q.work = row
		if not _reaches(q):
			_bench_note(q, row); continue
		_note(q, 1)
		if _try_row(q): return &""
		if q.exhausted: return REFUSE_CAPACITY
	if q.rank <= 0 and q.bench > 0: return REFUSE_BENCH_ASCENT if _climb_row(q) < 0 else REFUSE_BENCH_FOOTING
	return RANKED[maxi(q.rank, 0)]


static func _bench_note(q: Query, row: int) -> void:
	"""ADR1220: the smallest positive whole-cube stance rise putting this row's anchor strictly inside the cube band."""
	var need: int = int(q.origin.y) - q.start.y - q.anchor.y # Stance offset at which the anchor meets the cube floor.
	if need < 0: return
	@warning_ignore("integer_division") var rise: int = (need / Contract.QUANTUM_SIDE_U + 1) * Contract.QUANTUM_SIDE_U
	if rise - need >= Contract.QUANTUM_SIDE_U or (q.bench > 0 and rise >= q.bench): return
	q.bench = rise; q.bench_work = row


static func _climb_row(q: Query) -> int:
	"""The first certified MODE_CLIMB row with the retreat row's actor/tool/cargo identity, or -1."""
	for row: int in q.profiles._live.header[1]:
		if q.profiles._live.flags[row] != Profiles.CERT_REQUIRED or _field(q, row, Profiles.F_MODE) != Profiles.MODE_CLIMB: continue
		var same: bool = true
		for field: int in IDENTITY_FIELDS: same = same and _field(q, row, field) == _field(q, q.backward, field)
		if same: return row
	return -1


static func _note(q: Query, rank: int) -> void:
	"""Keep the most advanced refusal seen; REACH is rank 0 and implicit."""
	q.rank = maxi(q.rank, rank)


static func _work_row(q: Query, row: int) -> bool:
	"""Exact BUILD source rows of the requested yaw and the retreat row's actor/tool/cargo identity."""
	if q.profiles._live.flags[row] != Profiles.CERT_REQUIRED or _field(q, row, Profiles.F_MODE) != Profiles.MODE_WORK \
			or _field(q, row, Profiles.F_WORK_KIND) != Jobs.JOB_KIND_BUILD \
			or _field(q, row, Profiles.F_CONTACT_KIND) != Profiles.CONTACT_ANCHOR_AND_PATCH \
			or _field(q, row, Profiles.F_YAW_KIND) != Profiles.YAW_EXACT or _field(q, row, Profiles.F_YAW) != q.yaw: return false
	for field: int in IDENTITY_FIELDS:
		if _field(q, row, field) != _field(q, q.backward, field): return false
	var stride: int = q.profiles._profile_capacity
	for field: int in [Profiles.L_QUANTITY_MIN, Profiles.L_QUANTITY_MAX]:
		if q.profiles._live.quantities[field * stride + row] != q.profiles._live.quantities[field * stride + q.backward]: return false
	return _anchor(q, row)


static func _anchor(q: Query, row: int) -> bool:
	"""Exactly one published CONTACT_POINT, ahead of the stance along the face normal."""
	var found: int = 0
	for index: int in _field(q, row, Profiles.F_BOX_COUNT):
		var box: int = _field(q, row, Profiles.F_FIRST_BOX) + index
		if q.profiles._live.boxes[6 * q.profiles._box_capacity + box] != Profiles.CONTACT_POINT: continue
		found += 1
		for axis: int in 3: q.anchor[axis] = q.profiles._live.boxes[axis * q.profiles._box_capacity + box]
	return found == 1 and q.anchor[q.axis] * q.direction > 0


static func _reaches(q: Query) -> bool:
	"""The anchor must lie strictly inside the cube's band above the Room floor and the root stand outside the cube."""
	var plane: int = int(q.origin[q.axis]) + (0 if q.direction > 0 else Contract.QUANTUM_SIDE_U)
	var height: int = q.start.y + q.anchor.y
	q.root = q.start
	q.root[q.axis] = plane - q.anchor[q.axis]
	return height > q.origin.y and height < q.origin.y + Contract.QUANTUM_SIDE_U


static func _try_row(q: Query) -> bool:
	"""Order lateral candidates (gateway line first, then nearest the anchor-centred root) and test each chain."""
	var count: int = _candidates(q)
	if count < 0: return false
	q.keys.resize(count); q.keys.sort(); q.keys.resize(MAX_CANDIDATES)
	var previous: int = -1
	for index: int in count:
		var value: int = int(q.keys[index] & 0xFFFFFFFF) - 2147483648
		if index > 0 and value == previous: continue
		previous = value
		q.root[q.lateral] = value
		if _chain(q): return true
		if q.exhausted: return false
	return false


static func _candidates(q: Query) -> int:
	"""Critical lateral roots: every region/cube plane minus every published box edge, inside the anchor band."""
	var low: int = int(q.origin[q.lateral]) + 1 - q.anchor[q.lateral]
	var high: int = int(q.origin[q.lateral]) + Contract.QUANTUM_SIDE_U - 1 - q.anchor[q.lateral]
	var centre: int = int(q.origin[q.lateral]) + (Contract.QUANTUM_SIDE_U >> 1) - q.anchor[q.lateral]
	var edges: int = _edges(q)
	var planes: int = _planes(q)
	if edges < 0 or planes < 0: return -1
	var count: int = 0
	for value: int in [q.start[q.lateral], centre, low, high]:
		count = _key(q, count, value, low, high, centre, value == q.start[q.lateral])
	for plane: int in planes:
		for edge: int in edges:
			if count < 0 or not _spend(q, 1): return -1
			count = _key(q, count, q.planes[plane] - q.edges[edge], low, high, centre, false)
	return count


static func _key(q: Query, count: int, value: int, low: int, high: int, centre: int, preferred: bool) -> int:
	"""Encode (priority, value) so a native sort orders by distance from the centre, then by value."""
	if count < 0 or value < low or value > high: return count
	if count >= MAX_CANDIDATES: return -1
	var priority: int = 0 if preferred else absi(value - centre) + 1
	q.keys[count] = (priority << 32) | (value + 2147483648)
	return count + 1


static func _edges(q: Query) -> int:
	"""Distinct lateral box faces of the work row and every selected travel row."""
	var count: int = 0
	for profile: int in [q.work, q.forward, q.backward, q.short_forward, q.short_backward, q.ground]:
		if profile < 0: continue
		for index: int in _field(q, profile, Profiles.F_BOX_COUNT):
			var box: int = _field(q, profile, Profiles.F_FIRST_BOX) + index
			for side: int in [0, 3]:
				count = _unique(q.edges, count, q.profiles._live.boxes[(q.lateral + side) * q.profiles._box_capacity + box])
				if count < 0: return -1
	return count


static func _planes(q: Query) -> int:
	"""Distinct lateral planes of the target cube and every hull region."""
	var count: int = _unique(q.planes, 0, q.target[q.lateral])
	count = _unique(q.planes, count, q.target[q.lateral + 3])
	for kind: int in 3:
		for index: int in q.counts[kind]:
			for side: int in [0, 3]:
				count = _unique(q.planes, count, q.tables[kind][index * 6 + q.lateral + side])
				if count < 0: return -1
	return count


static func _unique(values: PackedInt32Array, count: int, value: int) -> int:
	"""Append a value once into a bounded scratch list."""
	if count < 0: return -1
	for index: int in count:
		if values[index] == value: return count
	if count >= values.size(): return -1
	values[count] = value
	return count + 1


static func _chain(q: Query) -> bool:
	"""Work station, then the gateway turn, then heading legs (full travel, else the finite step)."""
	q.stations = 0; q.entry = q.gateway
	if not _work_fits(q): return false
	var at: Vector3i = q.start
	if q.start[q.lateral] != q.root[q.lateral]:
		if q.ground < 0: _note(q, 3); return false
		var turn: Vector3i = q.start
		turn[q.lateral] = q.root[q.lateral]
		if not _leg(q, at, turn, q.ground, q.ground): return false
		at = turn
	if q.direction * (q.root[q.axis] - at[q.axis]) <= 0: return false
	return _heading(q, at)


static func _heading(q: Query, at: Vector3i) -> bool:
	"""Full selected travel to the root when it fits; otherwise the published finite step as the final leg."""
	var saved: int = q.stations
	if _legs(q, at, q.root, q.forward, q.backward): return _complete(q)
	q.stations = saved
	var step: Vector3i = q.root
	step[q.axis] -= q.direction * StepProgram.DISTANCE
	if q.direction * (step[q.axis] - at[q.axis]) < 0: return false
	if step != at and not _legs(q, at, step, q.forward, q.backward): return false
	if q.short_forward < 0:
		_note(q, 4); return false
	if not _leg(q, step, q.root, q.short_forward, q.short_backward): return false
	return _complete(q)


static func _complete(q: Query) -> bool:
	"""Each station's single published air/footing box must fit, then the chain must fit the bounded publication."""
	for index: int in q.stations:
		if not _station_fits(q, index):
			_note(q, 5); return false
	if q.stations <= MAX_STATIONS or _regateway(q): return true
	_note(q, 6)
	return false


static func _regateway(q: Query) -> bool:
	"""An over-long chain may start at an existing TRANSIT station it passes through exactly (latest first)."""
	for keep: int in range(q.stations - 2, -1, -1):
		if q.stations - keep - 1 > MAX_STATIONS: return false
		var ref: Vector2i = _existing_station(q, keep)
		if ref == NULL_REF: continue
		var drop: int = keep + 1
		for index: int in range(drop, q.stations):
			var to: int = index - drop
			for word: int in 3: q.points[to * 3 + word] = q.points[index * 3 + word]
			for word: int in 4: q.spans[to * 4 + word] = q.spans[index * 4 + word]
			for word: int in 2: q.sections[to * 2 + word] = q.sections[index * 2 + word]
			q.air_counts[to] = q.air_counts[index]
			for word: int in AIR_BOXES * 6: q.air[to * AIR_BOXES * 6 + word] = q.air[index * AIR_BOXES * 6 + word]
		q.stations -= drop; q.entry = ref
		return true
	return false


static func _existing_station(q: Query, index: int) -> Vector2i:
	"""A live TRANSIT Location at exactly this planned point and section, or null."""
	var locations: Locations = q.locations
	var section: Vector2i = Vector2i(q.sections[index * 2], q.sections[index * 2 + 1])
	for row: int in locations._capacity:
		if not _spend(q, 4): return NULL_REF
		if locations._live.present[row] != 1 or locations._get32(locations._live, Locations.ROLE, row) != Locations.ROLE_TRANSIT \
				or locations._ref_at(locations._live, Locations.SECTION_SLOT, row) != section: continue
		if locations._get32(locations._live, Locations.X, row) == q.points[index * 3] \
				and locations._get32(locations._live, Locations.Y, row) == q.points[index * 3 + 1] \
				and locations._get32(locations._live, Locations.Z, row) == q.points[index * 3 + 2]:
			return Vector2i(row, locations._get32(locations._live, Locations.GENERATION, row))
	return NULL_REF


static func _station_fits(q: Query, index: int) -> bool:
	"""Mirror ADR1161 records: one air AABB and one footing AABB over every adjoining source, as publish_into builds them."""
	var point: Vector3i = Vector3i(q.points[index * 3], q.points[index * 3 + 1], q.points[index * 3 + 2])
	_set_box(q.envelope, point, point + Vector3i.ONE)
	q.footing[0] = 1; q.footing[3] = 0 # Empty until the first stance box.
	var last: bool = index + 1 == q.stations
	for profile: int in [q.spans[index * 4], q.spans[index * 4 + 2],
			q.work if last else q.spans[index * 4 + 4], -1 if last else q.spans[index * 4 + 6]]:
		if profile >= 0: _extend(q, profile, point)
	for axis: int in 6: q.box[axis] = q.footing[axis]
	if q.footing[0] >= q.footing[3] or not _covered(q, SUPPORT, false): return false
	for axis: int in 6: q.box[axis] = q.envelope[axis]
	q.air_counts[index] = 0
	if (_blocked(q) or not _covered(q, VOID, false)) and not _station_air(q, index, point, last): return false
	if not last: return true
	var section: int = _section_at(q, point)
	_slice(q.tables[SECTION], section, q.other)
	return q.footing[0] >= q.other[0] and q.footing[2] >= q.other[2] and q.footing[3] <= q.other[3] and q.footing[5] <= q.other[5]


static func _station_air(q: Query, index: int, point: Vector3i, last: bool) -> bool:
	"""ADR1215: the one AABB is not open, so claim the sources' own air primitives, merged only where open."""
	var count: int = 0
	for profile: int in [q.spans[index * 4], q.spans[index * 4 + 2],
			q.work if last else q.spans[index * 4 + 4], -1 if last else q.spans[index * 4 + 6]]:
		if profile >= 0: count = _primitives(q, profile, point, count)
	if count < 0: return false
	count = _merge(q, count)
	if count < 0 or count > AIR_BOXES or not _root_first(q, count, point): return false
	q.air_counts[index] = count
	for word: int in count * 6: q.air[index * AIR_BOXES * 6 + word] = q.primitives[word]
	return true


static func _primitives(q: Query, profile: int, point: Vector3i, count: int) -> int:
	"""Body, turn and approach boxes above the root plane, clamped to it; contained duplicates are dropped."""
	var bank: PackedInt32Array = q.profiles._live.boxes
	var stride: int = q.profiles._box_capacity
	for index: int in _field(q, profile, Profiles.F_BOX_COUNT):
		var box: int = _field(q, profile, Profiles.F_FIRST_BOX) + index
		var role: int = bank[6 * stride + box]
		if count < 0 or (role != Profiles.BODY_HELD_LOAD and role != Profiles.TURN_RECOVERY and role != Profiles.WORK_APPROACH) \
				or point.y + bank[4 * stride + box] <= point.y: continue
		_set_box(q.other, _box_low(q, box, point), _box_high(q, box, point))
		q.other[1] = maxi(q.other[1], point.y)
		count = _add_primitive(q, count)
	return count


static func _add_primitive(q: Query, count: int) -> int:
	"""Keep q.other unless an existing primitive contains it; drop existing ones it contains."""
	var kept: int = 0
	for index: int in count:
		_slice(q.primitives, index, q.box)
		if Space.contains_box(q.box, q.other): return count
		if not Space.contains_box(q.other, q.box):
			_put(q.primitives, kept, q.box); kept += 1
	if kept >= MAX_PRIMITIVES: return -1
	_put(q.primitives, kept, q.other)
	return kept + 1


static func _merge(q: Query, count: int) -> int:
	"""Greedy, deterministic: replace the first pair whose AABB is open void by that AABB, until none is."""
	var merged: bool = true
	while merged and count > 1:
		merged = false
		for first: int in count:
			for second: int in range(first + 1, count):
				_slice(q.primitives, first, q.merged); _slice(q.primitives, second, q.other)
				for axis: int in 3:
					q.merged[axis] = mini(q.merged[axis], q.other[axis]); q.merged[axis + 3] = maxi(q.merged[axis + 3], q.other[axis + 3])
				for axis: int in 6: q.box[axis] = q.merged[axis]
				if q.exhausted: return -1
				if _blocked(q) or not _covered(q, VOID, false): continue
				_put(q.primitives, first, q.merged)
				for later: int in range(second + 1, count):
					_slice(q.primitives, later, q.box); _put(q.primitives, later - 1, q.box)
				count -= 1; merged = true
				break
			if merged: break
	return count


static func _root_first(q: Query, count: int, point: Vector3i) -> bool:
	"""The box holding the root on its floor becomes the published envelope."""
	for index: int in count:
		_slice(q.primitives, index, q.box)
		if q.box[1] == point.y and point.x >= q.box[0] and point.x < q.box[3] and point.z >= q.box[2] and point.z < q.box[5]:
			_slice(q.primitives, 0, q.other); _put(q.primitives, 0, q.box); _put(q.primitives, index, q.other)
			return true
	return false


static func _extend(q: Query, profile: int, point: Vector3i) -> void:
	"""Body, turn and approach boxes widen the air (clamped to the floor); stance boxes widen the footing."""
	var bank: PackedInt32Array = q.profiles._live.boxes
	var stride: int = q.profiles._box_capacity
	for index: int in _field(q, profile, Profiles.F_BOX_COUNT):
		var box: int = _field(q, profile, Profiles.F_FIRST_BOX) + index
		var role: int = bank[6 * stride + box]
		var target: PackedInt32Array = q.footing if role == Profiles.STANCE_SUPPORT else q.envelope
		if role != Profiles.STANCE_SUPPORT and role != Profiles.BODY_HELD_LOAD and role != Profiles.TURN_RECOVERY \
				and role != Profiles.WORK_APPROACH: continue
		var empty: bool = role == Profiles.STANCE_SUPPORT and q.footing[0] >= q.footing[3]
		for axis: int in 3:
			var low: int = int(point[axis]) + bank[axis * stride + box]
			if axis == 1 and role != Profiles.STANCE_SUPPORT: low = maxi(low, point.y)
			var high: int = int(point[axis]) + bank[(axis + 3) * stride + box]
			target[axis] = low if empty else mini(target[axis], low)
			target[axis + 3] = high if empty else maxi(target[axis + 3], high)


static func _legs(q: Query, first: Vector3i, last: Vector3i, forward: int, backward: int) -> bool:
	"""Split one heading run at each section boundary; each span stays inside its own section."""
	var at: Vector3i = first
	while at != last:
		var section: int = _section_at(q, at)
		if section < 0: _note(q, 2); return false
		var next: Vector3i = last
		var bound: int = q.tables[SECTION][section * 6 + q.axis + (3 if q.direction > 0 else 0)]
		if q.direction > 0 and last[q.axis] > bound: next[q.axis] = bound
		elif q.direction < 0 and last[q.axis] < bound: _note(q, 2); return false
		if not _leg(q, at, next, forward, backward): return false
		at = next
	return true


static func _leg(q: Query, first: Vector3i, last: Vector3i, forward: int, backward: int) -> bool:
	"""Both directed sources sweep the whole span; the arrival becomes the next station."""
	var section: int = _section_at(q, first)
	var arrival: int = _section_at(q, last)
	if section < 0 or arrival < 0 or q.stations >= MAX_CHAIN: _note(q, 2 if q.stations < MAX_CHAIN else 6); return false
	_slice(q.tables[SECTION], section, q.box)
	if Publication.section_span_refusal(first, last, q.box) != &"": _note(q, 2); return false
	if not _sweep(q, forward, first, last) or not _sweep(q, backward, last, first): return false
	for axis: int in 3: q.points[q.stations * 3 + axis] = last[axis]
	q.spans[q.stations * 4] = forward; q.spans[q.stations * 4 + 2] = backward
	q.spans[q.stations * 4 + 1] = q.profiles._live.quantities[forward]
	q.spans[q.stations * 4 + 3] = q.profiles._live.quantities[backward]
	q.sections[q.stations * 2] = q.section_refs[arrival * 2]; q.sections[q.stations * 2 + 1] = q.section_refs[arrival * 2 + 1]
	q.stations += 1
	return true


static func _slice(table: PackedInt32Array, index: int, out: PackedInt32Array) -> void:
	"""Copy one fixed table row."""
	for axis: int in 6: out[axis] = table[index * 6 + axis]


static func _section_at(q: Query, point: Vector3i) -> int:
	"""The Room-floor section whose half-open plan extent holds the point."""
	for index: int in q.counts[SECTION]:
		var at: int = index * 6
		var table: PackedInt32Array = q.tables[SECTION]
		if point.x >= table[at] and point.x < table[at + 3] and point.z >= table[at + 2] and point.z < table[at + 5]:
			return index
	return -1


static func _work_fits(q: Query) -> bool:
	"""Every published work box at the root: air in open void, stroke in void or the target, footing on support."""
	var profiles: Profiles = q.profiles
	for index: int in _field(q, q.work, Profiles.F_BOX_COUNT):
		var box: int = _field(q, q.work, Profiles.F_FIRST_BOX) + index
		var role: int = profiles._live.boxes[6 * profiles._box_capacity + box]
		if role == Profiles.CONTACT_POINT or role == Profiles.CONTACT_PATCH: continue
		if not _fits(q, _box_low(q, box, q.root), _box_high(q, box, q.root), role == Profiles.WORK_STROKE):
			_note(q, 1); return false
	return true


static func _box_low(q: Query, box: int, at: Vector3i) -> Vector3i:
	"""Translate a published low corner by an integer root."""
	var bank: PackedInt32Array = q.profiles._live.boxes
	var stride: int = q.profiles._box_capacity
	return Vector3i(at.x + bank[box], at.y + bank[stride + box], at.z + bank[2 * stride + box])


static func _box_high(q: Query, box: int, at: Vector3i) -> Vector3i:
	"""Translate a published high corner by an integer root."""
	var bank: PackedInt32Array = q.profiles._live.boxes
	var stride: int = q.profiles._box_capacity
	return Vector3i(at.x + bank[3 * stride + box], at.y + bank[4 * stride + box], at.z + bank[5 * stride + box])


static func _sweep(q: Query, profile: int, first: Vector3i, last: Vector3i) -> bool:
	"""Integer translation of every non-contact box over the whole axis-aligned span."""
	var profiles: Profiles = q.profiles
	var low_root: Vector3i = Vector3i(mini(first.x, last.x), first.y, mini(first.z, last.z))
	var high_root: Vector3i = Vector3i(maxi(first.x, last.x), first.y, maxi(first.z, last.z))
	for index: int in _field(q, profile, Profiles.F_BOX_COUNT):
		var box: int = _field(q, profile, Profiles.F_FIRST_BOX) + index
		var role: int = profiles._live.boxes[6 * profiles._box_capacity + box]
		if role == Profiles.CONTACT_POINT or role == Profiles.CONTACT_PATCH: continue
		if not _fits(q, _box_low(q, box, low_root), _box_high(q, box, high_root), false):
			_note(q, 1); return false
	return true


static func _fits(q: Query, low: Vector3i, high: Vector3i, stroke: bool) -> bool:
	"""Air above the Room floor needs void (and no blocker); anything below it needs actual support."""
	var plane: int = q.start.y
	if high.y > plane:
		_set_box(q.box, low, high)
		q.box[1] = maxi(low.y, plane)
		if _blocked(q) or not _covered(q, VOID, stroke): return false
	if low.y < plane:
		_set_box(q.box, low, high)
		q.box[4] = mini(high.y, plane)
		if not _covered(q, SUPPORT, false): return false
	return true


static func _set_box(out: PackedInt32Array, low: Vector3i, high: Vector3i) -> void:
	"""Write a half-open box from two corners."""
	out[0] = low.x; out[1] = low.y; out[2] = low.z; out[3] = high.x; out[4] = high.y; out[5] = high.z


static func _blocked(q: Query) -> bool:
	"""Any physical non-void, non-support row meeting the air refuses; Room reservation markers are not walls."""
	for index: int in q.counts[BLOCKER]:
		if not _spend(q, 1): return true
		_slice(q.tables[BLOCKER], index, q.other)
		if Space.overlaps(q.box, q.other): return true
	return false


static func _covered(q: Query, kind: int, stroke: bool) -> bool:
	"""Exact half-open subtraction of every cover row (and the target cube for a stroke) from the query box."""
	_put(q.front, 0, q.box)
	var count: int = 1
	for index: int in q.counts[kind] + (1 if stroke else 0):
		if index < q.counts[kind]: _slice(q.tables[kind], index, q.other)
		else: _slice(q.target, 0, q.other)
		count = _subtract_all(q, count)
		if count <= 0: return count == 0
	return false


static func _subtract_all(q: Query, count: int) -> int:
	"""Subtract the current cover from each live fragment into the other arena, then swap arenas."""
	var next: int = 0
	for index: int in count:
		if not _spend(q, 6): return -1
		next = _subtract(q, index * 6, next)
		if next < 0: return -1
	var swap: PackedInt32Array = q.front
	q.front = q.back; q.back = swap
	return next


static func _subtract(q: Query, at: int, next: int) -> int:
	"""Six outside slabs of one fragment minus the cover; a disjoint fragment is copied unchanged."""
	for axis: int in 6: q.box[axis] = q.front[at + axis]
	if not Space.overlaps(q.box, q.other):
		return _emit(q, next)
	for axis: int in 3:
		var cut_low: int = maxi(q.box[axis], q.other[axis])
		var cut_high: int = mini(q.box[axis + 3], q.other[axis + 3])
		if q.box[axis] < cut_low:
			var keep: int = q.box[axis + 3]
			q.box[axis + 3] = cut_low; next = _emit(q, next); q.box[axis + 3] = keep
			q.box[axis] = cut_low
		if q.box[axis + 3] > cut_high and next >= 0:
			var keep_low: int = q.box[axis]
			q.box[axis] = cut_high; next = _emit(q, next); q.box[axis] = keep_low
			q.box[axis + 3] = cut_high
		if next < 0: return -1
	return next


static func _emit(q: Query, next: int) -> int:
	"""Append the scratch box to the back arena, refusing at the fixed fragment bound."""
	if next < 0 or next >= MAX_FRAGMENTS:
		q.exhausted = true; return -1
	_put(q.back, next, q.box)
	return next + 1


static func _output(q: Query, out: Publication.Request) -> void:
	"""Only a complete admissible chain is written; unused tails are explicit nulls and zeros."""
	out.gateway = q.entry; out.count = q.stations
	out.sections = PackedInt32Array([-1, 0, -1, 0, -1, 0])
	out.points = PackedInt32Array(); out.points.resize(9)
	out.profiles = PackedInt64Array(); out.profiles.resize(12)
	for index: int in q.stations:
		out.sections[index * 2] = q.sections[index * 2]; out.sections[index * 2 + 1] = q.sections[index * 2 + 1]
		for axis: int in 3: out.points[index * 3 + axis] = q.points[index * 3 + axis]
		for field: int in 4: out.profiles[index * 4 + field] = q.spans[index * 4 + field]
	for index: int in MAX_STATIONS:
		out.air_counts[index] = q.air_counts[index] if index < q.stations else 0
	out.air.fill(0)
	for index: int in q.stations:
		for word: int in AIR_BOXES * 6: out.air[index * AIR_BOXES * 6 + word] = q.air[index * AIR_BOXES * 6 + word]
	out.work_profile = q.work; out.work_revision = q.profiles._live.quantities[q.work]
	out.face = q.face; out.yaw = q.yaw
