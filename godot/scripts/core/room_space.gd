extends RefCounted
## Bounded, cold integer geometry validation. This module owns NO world occupancy or paid history.
## Snapshot truth comes from the spatial owners; Authority must bind measured profiles and real
## support/work contacts. A Result is a revision-bound candidate, never a construction permission.

const VERSION: int = 1
const QUANTUM_U: int = 1024 # SET-MOVE-ECON-001 ECON-001, not a drawing-grid restriction.
const MAX_CELLS: int = 16384 # Same cold-operation ceiling as RoomFootprint.
const MAX_REGIONS: int = 16384
const MAX_CHECKS: int = 1048576 # Cold-operation work budget; not a claimed frame-time budget.
const I32_MIN: int = -2147483648
const I32_MAX: int = 2147483647
const NULL_REF: Vector2i = Vector2i(-1, 0)

const DRY_SOLID: int = 0
const SUPPORTED_VOID: int = 1
const OBSTACLE: int = 2
const PROTECTED_ACCESS: int = 3
const SUPPORT: int = 4
const OPENABLE_SHELL: int = 5
const WATER: int = 6
const RESOURCE: int = 7
const OCCUPANT: int = 8
const UNFINISHED: int = 9
const FLOOR_DATUM: int = 10 # Metadata extent: lo_y is the owner-authored floor, not free void.
const WORLD_ROLE_COUNT: int = 11
const ENVELOPE: int = 16
const LANDING: int = 17
const SUPPORT_REQUIRED: int = 18
const OPENING: int = 19
const SOLID: int = 20


class Value extends RefCounted:

	static func valid_ref(ref: Vector2i) -> bool:
		"""Share identity validation across outer helpers and nested cold input builders."""
		return ref.x >= 0 and ref.y >= 1

	static func int32(value: int) -> bool:
		"""Check in int64 before any packed input builder can narrow the supplied scalar."""
		return value >= I32_MIN and value <= I32_MAX

	static func valid_box(box: PackedInt32Array) -> bool:
		"""Boxes need six ordered endpoints even when built before the main validator runs."""
		return box.size() == 6 and box[0] < box[3] and box[1] < box[4] and box[2] < box[5]


class Domain extends RefCounted:

	## Configured once by the world owner. All axes use the same immutable economic datum.
	var _world: Vector2i = NULL_REF
	var _datum: Vector3i = Vector3i.ZERO
	var _min_quantum: Vector3i = Vector3i.ZERO
	var _size_quanta: Vector3i = Vector3i.ZERO
	var _bounds: PackedInt32Array = PackedInt32Array()
	var _cells: int = 0
	var _regions: int = 0
	var _checks: int = 0

	func configure(world: Vector2i, datum: Vector3i, minimum: Vector3i, size: Vector3i,
			cells: int, regions: int, checks: int) -> StringName:
		"""Register a finite immutable domain without allocating a dense underground world."""
		if not _bounds.is_empty():
			return &"SPACE_DOMAIN_ALREADY_REGISTERED"
		if not Value.valid_ref(world) or cells < 1 or cells > MAX_CELLS or regions < 1 \
				or regions > MAX_REGIONS or checks < 1 or checks > MAX_CHECKS:
			return &"SPACE_DOMAIN_INVALID"
		var bounds: PackedInt32Array = PackedInt32Array()
		for axis: int in 3:
			var low: int = int(datum[axis]) + int(minimum[axis]) * QUANTUM_U
			var high: int = low + int(size[axis]) * QUANTUM_U
			if size[axis] < 1 or not Value.int32(low) or not Value.int32(high):
				return &"SPACE_DOMAIN_INVALID"
			bounds.append(low)
			bounds.append(high)
		_bounds = PackedInt32Array([bounds[0], bounds[2], bounds[4], bounds[1], bounds[3], bounds[5]])
		_world = world
		_datum = datum
		_min_quantum = minimum
		_size_quanta = size
		_cells = cells
		_regions = regions
		_checks = checks
		return &""

	func descriptor() -> Dictionary:
		"""Copy the immutable domain binding for the physical ledger and eventual save owner."""
		return {"world_ref": _world, "datum_u": _datum, "min_quantum": _min_quantum,
			"size_quanta": _size_quanta, "bounds_u": _bounds.duplicate(),
			"max_cells": _cells, "max_regions": _regions, "max_checks": _checks}


class Volumes extends RefCounted:

	## Caller-owned packed columns; boxes are half-open [lo,hi). No float AABB participates.
	var lo_x: PackedInt32Array = PackedInt32Array()
	var lo_y: PackedInt32Array = PackedInt32Array()
	var lo_z: PackedInt32Array = PackedInt32Array()
	var hi_x: PackedInt32Array = PackedInt32Array()
	var hi_y: PackedInt32Array = PackedInt32Array()
	var hi_z: PackedInt32Array = PackedInt32Array()
	var role: PackedInt32Array = PackedInt32Array()
	var level: PackedInt32Array = PackedInt32Array()
	var owner_slot: PackedInt32Array = PackedInt32Array()
	var owner_generation: PackedInt32Array = PackedInt32Array()
	var owner_revision: PackedInt64Array = PackedInt64Array()

	func append(box: PackedInt32Array, kind: int, floor_id: int, owner: Vector2i, revision: int) -> bool:
		"""Build one bounded cold record; owner truth and role semantics are checked at validation."""
		if not Value.valid_box(box) or role.size() >= MAX_REGIONS \
				or not Value.int32(kind) or not Value.int32(floor_id):
			return false
		lo_x.append(box[0])
		lo_y.append(box[1])
		lo_z.append(box[2])
		hi_x.append(box[3])
		hi_y.append(box[4])
		hi_z.append(box[5])
		role.append(kind)
		level.append(floor_id)
		owner_slot.append(owner.x)
		owner_generation.append(owner.y)
		owner_revision.append(revision)
		return true

	func box_at(row: int) -> PackedInt32Array:
		"""Read an already validated row into cold-operation scratch."""
		return PackedInt32Array([lo_x[row], lo_y[row], lo_z[row], hi_x[row], hi_y[row], hi_z[row]])

	func ref_at(row: int) -> Vector2i:
		"""Read both halves of a row's owner identity."""
		return Vector2i(owner_slot[row], owner_generation[row])

	func copy() -> Volumes:
		"""Copy a validated finite table; never expose mutable caller storage to an adapter."""
		var out: Volumes = Volumes.new()
		for row: int in role.size():
			out.append(box_at(row), role[row], level[row], ref_at(row), owner_revision[row])
		return out


class Contacts extends RefCounted:

	## Each contact has an actual body approach envelope, work point and authored reach volume.
	## The profile ID/revision is verified against measured content by Authority, not by a boolean.
	var approach: Volumes = Volumes.new()
	var reach: Volumes = Volumes.new()
	var work_xyz: PackedInt32Array = PackedInt32Array()
	var profile_id: PackedInt32Array = PackedInt32Array()
	var profile_revision: PackedInt64Array = PackedInt64Array()

	func copy() -> Contacts:
		"""Isolate already validated contact evidence for one owner-qualification call."""
		var out: Contacts = Contacts.new()
		out.approach = approach.copy()
		out.reach = reach.copy()
		out.work_xyz = work_xyz.duplicate()
		out.profile_id = profile_id.duplicate()
		out.profile_revision = profile_revision.duplicate()
		return out


class Snapshot extends RefCounted:

	## Full region inventory for the requested domain, including pending and installed obstacles.
	## Missing dry/void/support coverage means unknown; it never means empty or safely supported.
	var version: int = VERSION
	var world_ref: Vector2i = NULL_REF
	var revision: int = 0
	var live_refs: PackedInt32Array = PackedInt32Array()
	var live_revisions: PackedInt64Array = PackedInt64Array()
	var volumes: Volumes = Volumes.new()

	func copy() -> Snapshot:
		"""Make an isolated finite image after all shape/capacity checks pass."""
		var out: Snapshot = Snapshot.new()
		out.version = version
		out.world_ref = world_ref
		out.revision = revision
		out.live_refs = live_refs.duplicate()
		out.live_revisions = live_revisions.duplicate()
		out.volumes = volumes.copy()
		return out


class Plan extends RefCounted:

	## All cuts are absolute cube origins, canonical ascending X then Y then Z, never local indices.
	## Each cut names a real work-contact row. OPENING rows name the exact existing shell owner.
	var expected_revision: int = 0
	var owner_ref: Vector2i = NULL_REF
	var owner_revision: int = 0
	var volumes: Volumes = Volumes.new()
	var cuts_xyz: PackedInt32Array = PackedInt32Array()
	var cut_contacts: PackedInt32Array = PackedInt32Array()
	var contacts: Contacts = Contacts.new()
	var catalog_key: StringName = &""
	var catalog_revision: int = 0
	var endpoints_xyz: PackedInt32Array = PackedInt32Array()
	var endpoint_levels: PackedInt32Array = PackedInt32Array()
	var endpoint_refs: PackedInt32Array = PackedInt32Array()
	var endpoint_revisions: PackedInt64Array = PackedInt64Array()

	func copy() -> Plan:
		"""Copy a checked candidate, retaining every target generation and revision."""
		var out: Plan = Plan.new()
		out.expected_revision = expected_revision
		out.owner_ref = owner_ref
		out.owner_revision = owner_revision
		out.volumes = volumes.copy()
		out.cuts_xyz = cuts_xyz.duplicate()
		out.cut_contacts = cut_contacts.duplicate()
		out.contacts = contacts.copy()
		out.catalog_key = catalog_key
		out.catalog_revision = catalog_revision
		out.endpoints_xyz = endpoints_xyz.duplicate()
		out.endpoint_levels = endpoint_levels.duplicate()
		out.endpoint_refs = endpoint_refs.duplicate()
		out.endpoint_revisions = endpoint_revisions.duplicate()
		return out


class Authority extends RefCounted:

	func qualification_error(_domain: Domain, _snapshot: Snapshot, _plan: Plan) -> StringName:
		"""Bind measured profiles, real dry/support/reach rules and legal connected work access."""
		return &"SPACE_AUTHORITY_UNBOUND"


class Result extends RefCounted:

	var ok: bool = false
	var error: StringName = &""
	var conflict_ref: Vector2i = NULL_REF
	var conflict_revision: int = 0
	var level: int = -1
	var row: int = -1
	var checks: int = 0
	var candidate: Plan = null


class Check extends RefCounted:

	var domain: Domain = null
	var snapshot: Snapshot = null
	var plan: Plan = null
	var live: Dictionary = {}
	var known: Volumes = Volumes.new()
	var result: Result = Result.new()
	var remaining: int = 0

	func spend() -> bool:
		"""Refuse exhaustion before a comparison can create more scratch or partial output."""
		if remaining < 1:
			result.error = &"SPACE_OPERATION_BUDGET"
			return false
		remaining -= 1
		result.checks += 1
		return true


static func validate(domain: Domain, snapshot: Snapshot, plan: Plan, authority: Authority = null) -> Result:
	"""Validate one immutable candidate; no callbacks may mutate the checked geometry or world."""
	var check: Check = Check.new()
	check.domain = domain
	check.snapshot = snapshot
	check.plan = plan
	check.result.error = _format_error(check)
	if check.result.error != &"":
		return check.result
	check.remaining = domain._checks
	check.snapshot = snapshot.copy()
	check.plan = plan.copy()
	if not _survey_consistent(check) or not _validate_cuts(check):
		return check.result
	_prepare_known(check)
	if not _validate_regions(check) or not _validate_contacts(check) or not _validate_endpoints(check):
		return check.result
	if authority == null:
		check.result.error = &"SPACE_AUTHORITY_UNBOUND"
		return check.result
	check.result.error = authority.qualification_error(domain, check.snapshot.copy(), check.plan.copy())
	if check.result.error == &"":
		check.result.ok = true
		check.result.candidate = check.plan
	return check.result


static func _format_error(check: Check) -> StringName:
	"""Bound every input before copying, deriving keys or walking any Cartesian combination."""
	var d: Domain = check.domain
	var s: Snapshot = check.snapshot
	var p: Plan = check.plan
	if d == null or d._bounds.is_empty() or s == null or p == null:
		return &"SPACE_INPUT_UNBOUND"
	if s.version != VERSION or s.world_ref != d._world or s.revision < 1 \
			or p.expected_revision != s.revision:
		return &"SPACE_SNAPSHOT_STALE"
	if s.volumes == null or p.volumes == null or p.contacts == null:
		return &"SPACE_FORMAT"
	var error: StringName = _owners_error(check)
	if error != &"":
		return error
	if not _owner_matches(check, p.owner_ref, p.owner_revision):
		return &"SPACE_OWNER_STALE"
	if p.volumes.role.is_empty() or p.cuts_xyz.size() % 3 != 0 \
			or p.cuts_xyz.size() > d._cells * 3 or p.cut_contacts.size() * 3 != p.cuts_xyz.size():
		return &"SPACE_FORMAT"
	return _tables_error(check)


static func _owners_error(check: Check) -> StringName:
	"""Validate complete source-owner generations and revisions; slot reuse never preserves a proof."""
	var s: Snapshot = check.snapshot
	if s.live_refs.size() != s.live_revisions.size() * 2 or s.live_revisions.size() > check.domain._regions:
		return &"SPACE_OWNER_FORMAT"
	for row: int in s.live_revisions.size():
		var ref: Vector2i = Vector2i(s.live_refs[row * 2], s.live_refs[row * 2 + 1])
		if not valid_ref(ref) or s.live_revisions[row] < 1 or check.live.has(ref.x):
			return &"SPACE_OWNER_FORMAT"
		check.live[ref.x] = row
	if not check.live.has(s.world_ref.x) or not _owner_matches(check, s.world_ref,
			s.live_revisions[check.live[s.world_ref.x]]):
		return &"SPACE_OWNER_STALE"
	return &""


static func _tables_error(check: Check) -> StringName:
	"""Check all SoA lengths and ownership, including contacts, before a single row is read."""
	var c: Contacts = check.plan.contacts
	if c.approach == null or c.reach == null:
		return &"SPACE_CONTACT_FORMAT"
	var tables: Array[Volumes] = [check.snapshot.volumes, check.plan.volumes, c.approach, c.reach]
	var total: int = check.plan.cut_contacts.size()
	for index: int in tables.size():
		var rows: Volumes = tables[index]
		total += rows.role.size()
		if total > check.domain._regions:
			return &"SPACE_REGION_CAPACITY"
		var error: StringName = _rows_error(check, rows, index == 0)
		if error != &"":
			return error
	var count: int = c.approach.role.size()
	if count < 1 or c.reach.role.size() != count or c.work_xyz.size() != count * 3 \
			or c.profile_id.size() != count or c.profile_revision.size() != count:
		return &"SPACE_CONTACT_FORMAT"
	var p: Plan = check.plan
	var ends: int = p.endpoint_levels.size()
	if ends not in [0, 2] or p.endpoints_xyz.size() != ends * 3 \
			or p.endpoint_refs.size() != ends * 2 or p.endpoint_revisions.size() != ends:
		return &"SPACE_ENDPOINT_FORMAT"
	if ends == 2 and (p.catalog_key == &"" or p.catalog_revision < 1):
		return &"SPACE_CATALOG_MISSING"
	return &""


static func _rows_error(check: Check, rows: Volumes, world: bool) -> StringName:
	"""All physical extents are real half-open integer boxes within the registered world."""
	var count: int = rows.role.size()
	for column: Variant in [rows.lo_x, rows.lo_y, rows.lo_z, rows.hi_x, rows.hi_y, rows.hi_z,
			rows.level, rows.owner_slot, rows.owner_generation, rows.owner_revision]:
		if column.size() != count:
			return &"SPACE_FORMAT"
	for row: int in count:
		if not valid_box(rows.box_at(row)) or not contains_box(check.domain._bounds, rows.box_at(row)):
			return &"SPACE_BOUNDS"
		if rows.level[row] < 0 or not _owner_matches(check, rows.ref_at(row), rows.owner_revision[row]):
			return &"SPACE_OWNER_STALE"
		var role: int = rows.role[row]
		if (world and (role < 0 or role >= WORLD_ROLE_COUNT)) \
				or (not world and (role < ENVELOPE or role > SOLID)):
			return &"SPACE_ROLE"
	return &""


static func _owner_matches(check: Check, ref: Vector2i, revision: int) -> bool:
	"""Consult the trusted snapshot's full live identity inventory."""
	if not check.live.has(ref.x):
		return false
	var row: int = check.live[ref.x]
	return check.snapshot.live_refs[row * 2 + 1] == ref.y \
		and check.snapshot.live_revisions[row] == revision


static func _survey_consistent(check: Check) -> bool:
	"""Solid and completed void cannot claim the same volume; contradictions are never tie-broken."""
	var rows: Volumes = check.snapshot.volumes
	for a: int in rows.role.size():
		if rows.role[a] != DRY_SOLID:
			continue
		for b: int in rows.role.size():
			if not check.spend():
				return false
			if rows.role[b] == SUPPORTED_VOID and overlaps(rows.box_at(a), rows.box_at(b)):
				return _conflict(check, &"SPACE_SURVEY_CONTRADICTION", rows, b)
	return true


static func _validate_cuts(check: Check) -> bool:
	"""Prove every charged cube is whole, dry solid, actually removed and assigned a legal work face."""
	var p: Plan = check.plan
	for row: int in p.cut_contacts.size():
		var origin: Vector3i = point_at(p.cuts_xyz, row)
		var cube: PackedInt32Array = quantum_box(check.domain, origin)
		if cube.is_empty():
			return _fail(check, &"SPACE_CUT_DATUM")
		if row > 0 and not point_less(point_at(p.cuts_xyz, row - 1), origin):
			return _fail(check, &"SPACE_CUT_NONCANONICAL")
		if not _covers(check, cube, check.snapshot.volumes, [DRY_SOLID]):
			return _fail(check, &"SPACE_CUT_NOT_DRY_SOLID")
		if not _covers(check, cube, p.volumes, [ENVELOPE, SOLID]):
			return _fail(check, &"SPACE_PARTIAL_QUANTUM")
		var contact: int = p.cut_contacts[row]
		if contact < 0 or contact >= p.contacts.profile_id.size() \
				or not _on_face(cube, point_at(p.contacts.work_xyz, contact)):
			return _fail(check, &"SPACE_WORK_FACE")
	return true


static func _validate_regions(check: Check) -> bool:
	"""Check all levels geometrically, not by level-ID equality or a two-endpoint shortcut."""
	var p: Volumes = check.plan.volumes
	var has_space: bool = false
	var has_support: bool = false
	for row: int in p.role.size():
		if p.role[row] == SUPPORT_REQUIRED:
			has_support = true
			if not _covers(check, p.box_at(row), check.snapshot.volumes, [SUPPORT]):
				return _fail(check, &"SPACE_SUPPORT_MISSING")
		elif p.role[row] == OPENING:
			if not _opening_valid(check, row):
				return false
		else:
			has_space = true
			if not _space_known(check, p.box_at(row)) or not _unobstructed(check, p.box_at(row)):
				return false
	if not has_space or not has_support:
		return _fail(check, &"SPACE_SUPPORT_MISSING")
	return _internal_clearance(check)


static func _opening_valid(check: Check, row: int) -> bool:
	"""Only the explicitly targeted shell can be cut, and only inside the actual proposed volume."""
	var p: Volumes = check.plan.volumes
	if not _covers(check, p.box_at(row), check.snapshot.volumes, [OPENABLE_SHELL], p.ref_at(row)):
		return _fail(check, &"SPACE_OPENING_TARGET")
	if not _covers(check, p.box_at(row), p, [ENVELOPE, SOLID]):
		return _fail(check, &"SPACE_OPENING_OUTSIDE_PLAN")
	return true


static func _space_known(check: Check, box: PackedInt32Array) -> bool:
	"""Every new usable/occupied volume must be already finished void or an exact requested cut."""
	if not _covers(check, box, check.known, [SUPPORTED_VOID]):
		return _fail(check, &"SPACE_UNPRICED_VOLUME")
	return true


static func _prepare_known(check: Check) -> void:
	"""Build one bounded coverage image rather than rebuilding it for every proposed region."""
	for row: int in check.snapshot.volumes.role.size():
		if check.snapshot.volumes.role[row] == SUPPORTED_VOID:
			check.known.append(check.snapshot.volumes.box_at(row), SUPPORTED_VOID, 0, check.plan.owner_ref, 1)
	for row: int in check.plan.cut_contacts.size():
		check.known.append(quantum_box(check.domain, point_at(check.plan.cuts_xyz, row)), SUPPORTED_VOID, 0,
			check.plan.owner_ref, 1)


static func _unobstructed(check: Check, box: PackedInt32Array, planned_openings: bool = true) -> bool:
	"""Protect furniture, pending work, supporting solids, water/resources and all access claims."""
	var world: Volumes = check.snapshot.volumes
	for row: int in world.role.size():
		if not check.spend():
			return false
		if world.role[row] < OBSTACLE or world.role[row] == FLOOR_DATUM \
				or not overlaps(box, world.box_at(row)):
			continue
		if planned_openings and world.role[row] == OPENABLE_SHELL \
				and _covers(check, intersection(box, world.box_at(row)),
				check.plan.volumes, [OPENING], world.ref_at(row)):
			continue
		return _conflict(check, &"SPACE_OBSTRUCTED", world, row)
	return true


static func _internal_clearance(check: Check) -> bool:
	"""A spiral post, stair solid or required support cannot overlap its own clearance or landing."""
	var rows: Volumes = check.plan.volumes
	for a: int in rows.role.size():
		if rows.role[a] != SOLID and rows.role[a] != SUPPORT_REQUIRED:
			continue
		for b: int in rows.role.size():
			if not check.spend():
				return false
			if rows.role[b] in [ENVELOPE, LANDING] and overlaps(rows.box_at(a), rows.box_at(b)):
				return _conflict(check, &"SPACE_INTERNAL_CLEARANCE", rows, b)
	return true


static func _validate_contacts(check: Check) -> bool:
	"""A work face is reached from complete dry space; proximity to a proposed room is insufficient."""
	var c: Contacts = check.plan.contacts
	for row: int in c.profile_id.size():
		if c.profile_id[row] < 0 or c.profile_revision[row] < 1:
			return _fail(check, &"SPACE_PROFILE_MISSING")
		if not _covers(check, c.approach.box_at(row), check.snapshot.volumes, [SUPPORTED_VOID]):
			return _fail(check, &"SPACE_WORK_APPROACH_UNFINISHED")
		if not contains_box(c.reach.box_at(row), c.approach.box_at(row)) \
				or not _contains_point(c.reach.box_at(row), point_at(c.work_xyz, row)):
			return _fail(check, &"SPACE_WORK_REACH")
		if not _unobstructed(check, c.approach.box_at(row), false):
			return false
		if not _covers(check, c.reach.box_at(row), check.snapshot.volumes, [DRY_SOLID, SUPPORTED_VOID]) \
				or not _unobstructed(check, c.reach.box_at(row), false):
			return _fail(check, &"SPACE_WORK_REACH")
	return true


static func _validate_endpoints(check: Check) -> bool:
	"""Fixed connector landings meet actual owner floors, including two heights on one nominal level."""
	var p: Plan = check.plan
	for row: int in p.endpoint_levels.size():
		var ref: Vector2i = Vector2i(p.endpoint_refs[row * 2], p.endpoint_refs[row * 2 + 1])
		if not _owner_matches(check, ref, p.endpoint_revisions[row]):
			return _fail(check, &"SPACE_ENDPOINT_STALE")
		var point: Vector3i = point_at(p.endpoints_xyz, row)
		if not _has_floor(check, point, p.endpoint_levels[row], ref):
			return _fail(check, &"SPACE_ENDPOINT_HEIGHT")
		if not has_landing(p.volumes, point, p.endpoint_levels[row]):
			return _fail(check, &"SPACE_ENDPOINT_LANDING")
	return true


static func _has_floor(check: Check, point: Vector3i, level: int, owner: Vector2i) -> bool:
	"""Floor metadata proves endpoint identity and height without granting any excavated volume."""
	var rows: Volumes = check.snapshot.volumes
	for row: int in rows.role.size():
		if not check.spend():
			return false
		if rows.role[row] == FLOOR_DATUM and rows.ref_at(row) == owner \
				and rows.level[row] == level and _at_floor(rows.box_at(row), point):
			return true
	return false


static func has_landing(rows: Volumes, point: Vector3i, level: int) -> bool:
	"""A named endpoint is on the actual half-open landing floor, never just its external corner."""
	for row: int in rows.role.size():
		if rows.role[row] == LANDING and rows.level[row] == level and _at_floor(rows.box_at(row), point):
			return true
	return false


static func _at_floor(box: PackedInt32Array, point: Vector3i) -> bool:
	"""A floor contact's X/Z are inside its footprint and Y is exactly the owner-authored floor."""
	return point.y == box[1] and point.x >= box[0] and point.x < box[3] \
		and point.z >= box[2] and point.z < box[5]


static func _covers(check: Check, box: PackedInt32Array, covers: Volumes,
		roles: Array[int], owner: Vector2i = NULL_REF) -> bool:
	"""Exact union coverage through bounded box subtraction; no point sampling or bounding-box fill."""
	var pending: Array[PackedInt32Array] = [box]
	for row: int in covers.role.size():
		if not check.spend():
			return false
		if covers.role[row] not in roles or (owner != NULL_REF and covers.ref_at(row) != owner):
			continue
		var next: Array[PackedInt32Array] = []
		for fragment: PackedInt32Array in pending:
			if not check.spend() or not _subtract_into(check, fragment, covers.box_at(row), next):
				return false
		pending = next
		if pending.is_empty():
			return true
	return false


static func _subtract_into(check: Check, box: PackedInt32Array, cover: PackedInt32Array,
		out: Array[PackedInt32Array]) -> bool:
	"""Subtract a box as at most six disjoint slabs, refusing fragment-capacity exhaustion."""
	if not overlaps(box, cover):
		return _fragment(check, out, box)
	var cut: PackedInt32Array = intersection(box, cover)
	var core: PackedInt32Array = box.duplicate()
	for axis: int in 3:
		if core[axis] < cut[axis]:
			var left: PackedInt32Array = core.duplicate()
			left[axis + 3] = cut[axis]
			if not _fragment(check, out, left):
				return false
			core[axis] = cut[axis]
		if core[axis + 3] > cut[axis + 3]:
			var right: PackedInt32Array = core.duplicate()
			right[axis] = cut[axis + 3]
			if not _fragment(check, out, right):
				return false
			core[axis + 3] = cut[axis + 3]
	return true


static func _fragment(check: Check, out: Array[PackedInt32Array], box: PackedInt32Array) -> bool:
	"""Bound peak fragmentation independently of geometric coordinate span."""
	if out.size() >= check.domain._regions:
		return _fail(check, &"SPACE_FRAGMENT_CAPACITY")
	out.append(box)
	return true


static func quantum_box(domain: Domain, origin: Vector3i) -> PackedInt32Array:
	"""Return the exact immutable-datum cube or empty; never round or narrow an overflowing corner."""
	if domain == null or domain._bounds.is_empty():
		return PackedInt32Array()
	var box: PackedInt32Array = PackedInt32Array([origin.x, origin.y, origin.z])
	for axis: int in 3:
		var far: int = int(origin[axis]) + QUANTUM_U
		if (int(origin[axis]) - int(domain._datum[axis])) % QUANTUM_U != 0 or not int32(far):
			return PackedInt32Array()
		box.append(far)
	return box if contains_box(domain._bounds, box) else PackedInt32Array()


static func valid_ref(ref: Vector2i) -> bool:
	"""A non-null generation-qualified owner pair; liveness belongs to the actual snapshot owner."""
	return Value.valid_ref(ref)


static func int32(value: int) -> bool:
	"""Check before writing into Vector3i or packed int32 storage."""
	return Value.int32(value)


static func valid_box(box: PackedInt32Array) -> bool:
	"""Reject empty and inverted boxes; touching boundaries do not occupy a volume."""
	return Value.valid_box(box)


static func contains_box(outer: PackedInt32Array, inner: PackedInt32Array) -> bool:
	"""Containment allows tangency; margins are explicit geometry from the owning catalog."""
	if not valid_box(outer) or not valid_box(inner):
		return false
	for axis: int in 3:
		if inner[axis] < outer[axis] or inner[axis + 3] > outer[axis + 3]:
			return false
	return true


static func overlaps(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	"""Positive-volume intersection in all three axes, independent of nominal level labels."""
	if not valid_box(a) or not valid_box(b):
		return false
	for axis: int in 3:
		if a[axis + 3] <= b[axis] or b[axis + 3] <= a[axis]:
			return false
	return true


static func intersection(a: PackedInt32Array, b: PackedInt32Array) -> PackedInt32Array:
	"""Return the overlap or empty; malformed or touching inputs never manufacture occupied space."""
	if not overlaps(a, b):
		return PackedInt32Array()
	return PackedInt32Array([maxi(a[0], b[0]), maxi(a[1], b[1]), maxi(a[2], b[2]),
		mini(a[3], b[3]), mini(a[4], b[4]), mini(a[5], b[5])])


static func point_less(a: Vector3i, b: Vector3i) -> bool:
	"""Canonical lexicographic cube order retains all three signed int32 coordinates."""
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y if a.y != b.y else a.z < b.z


static func point_at(values: PackedInt32Array, row: int) -> Vector3i:
	"""Read one validated packed coordinate triple."""
	return Vector3i(values[row * 3], values[row * 3 + 1], values[row * 3 + 2])


static func _contains_point(box: PackedInt32Array, point: Vector3i) -> bool:
	"""Work-contact endpoints may sit on a box face; unlike occupancy these are closed bounds."""
	for axis: int in 3:
		if point[axis] < box[axis] or point[axis] > box[axis + 3]:
			return false
	return true


static func _on_face(box: PackedInt32Array, point: Vector3i) -> bool:
	"""A work point belongs to the actual cube boundary, not its centre or an unrelated far wall."""
	if not _contains_point(box, point):
		return false
	for axis: int in 3:
		if point[axis] == box[axis] or point[axis] == box[axis + 3]:
			return true
	return false


static func _fail(check: Check, code: StringName) -> bool:
	"""Keep a more specific capacity refusal instead of relabeling it as missing geometry."""
	if check.result.error == &"":
		check.result.error = code
	return false


static func _conflict(check: Check, code: StringName, rows: Volumes, row: int) -> bool:
	"""Expose the actual conflicting owner and floor for later player-facing explanations."""
	_fail(check, code)
	check.result.conflict_ref = rows.ref_at(row)
	check.result.conflict_revision = rows.owner_revision[row]
	check.result.level = rows.level[row]
	check.result.row = row
	return false
