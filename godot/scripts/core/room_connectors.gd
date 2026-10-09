extends RefCounted
## Fixed connector content transformation, not a catalog of invented production dimensions.
## The five approved families share the same complete volume/contact/cut contract. UG09 must
## qualify the transformed Plan through RoomSpace and its real Authority before ordering work.

const Space := preload("res://scripts/core/room_space.gd")
const EARTH_TIMBER: int = 0
const STONE: int = 1
const RAMP: int = 2
const SPIRAL: int = 3
const LADDER_HATCH: int = 4
const FAMILY_COUNT: int = 5
const FAMILY_KEYS: PackedStringArray = ["earth_timber", "stone", "ramp", "spiral", "ladder_hatch"]


class Definition extends RefCounted:

	## Authored local-space geometry in u, +Y up. No width/run/rise stretch or hidden piece defaults.
	## Every pose, turn, tread, post, opening and hatch sweep must be conservatively represented.
	var key: StringName = &""
	var revision: int = 0
	var family: int = -1
	var allowed_rotations: int = 0 # Explicit four-bit quarter-turn mask, not a placement permission.
	var start: Vector3i = Vector3i.ZERO
	var end: Vector3i = Vector3i.ZERO
	var start_level_offset: int = 0
	var end_level_offset: int = 0
	var geometry: Space.Plan = Space.Plan.new()


class Placement extends RefCounted:

	var origin: Vector3i = Vector3i.ZERO
	var rotation: int = 0
	var level_base: int = 0
	var start_floor_u: int = 0
	var end_floor_u: int = 0
	var expected_revision: int = 0
	var owner_ref: Vector2i = Space.NULL_REF
	var owner_revision: int = 0
	var endpoint_refs: PackedInt32Array = PackedInt32Array()
	var endpoint_revisions: PackedInt64Array = PackedInt64Array()
	## One target per OPENING row, in catalog row order. All other rows belong to owner_ref.
	var opening_refs: PackedInt32Array = PackedInt32Array()
	var opening_revisions: PackedInt64Array = PackedInt64Array()


class Result extends RefCounted:

	var ok: bool = false
	var error: StringName = &""
	var plan: Space.Plan = null


static func place(domain: Space.Domain, variant: Definition, placement: Placement) -> Result:
	"""Transform fixed authored geometry exactly; never pay, reserve, qualify or publish space."""
	var out: Result = Result.new()
	out.error = _format_error(domain, variant, placement)
	if out.error != &"":
		return out
	var plan: Space.Plan = Space.Plan.new()
	plan.owner_ref = placement.owner_ref
	plan.owner_revision = placement.owner_revision
	plan.expected_revision = placement.expected_revision
	plan.catalog_key = variant.key
	plan.catalog_revision = variant.revision
	out.error = _endpoints(variant, placement, plan)
	if out.error == &"":
		out.error = _regions(variant.geometry.volumes, placement, plan.volumes, true)
	if out.error == &"":
		out.error = _contacts(variant.geometry.contacts, placement, plan.contacts)
	if out.error == &"":
		out.error = _cuts(domain, variant.geometry, placement, plan)
	if out.error == &"":
		out.ok = true
		out.plan = plan
	return out


static func _format_error(domain: Space.Domain, variant: Definition, placement: Placement) -> StringName:
	"""Reject malformed/missing content before copying an unbounded table or narrowing transforms."""
	if domain == null or domain.descriptor().bounds_u.is_empty() or variant == null or placement == null:
		return &"CONNECTOR_INPUT_UNBOUND"
	if variant.key == &"" or variant.revision < 1 or variant.family < 0 or variant.family >= FAMILY_COUNT:
		return &"CONNECTOR_CATALOG_MISSING"
	if placement.rotation < 0 or placement.rotation > 3 or variant.allowed_rotations < 1 \
			or variant.allowed_rotations > 15 or (variant.allowed_rotations & (1 << placement.rotation)) == 0:
		return &"CONNECTOR_ROTATION"
	if not Space.valid_ref(placement.owner_ref) or placement.owner_revision < 1 or placement.expected_revision < 1:
		return &"CONNECTOR_OWNER_UNBOUND"
	if placement.endpoint_refs.size() != 4 or placement.endpoint_revisions.size() != 2:
		return &"CONNECTOR_ENDPOINT_UNBOUND"
	for row: int in 2:
		if not Space.valid_ref(Vector2i(placement.endpoint_refs[row * 2], placement.endpoint_refs[row * 2 + 1])) \
				or placement.endpoint_revisions[row] < 1:
			return &"CONNECTOR_ENDPOINT_UNBOUND"
	return _content_error(domain, variant, placement)


static func _content_error(domain: Space.Domain, variant: Definition, placement: Placement) -> StringName:
	"""Content can be synthetic for tests, but cannot omit its entire spatial or work contract."""
	var p: Space.Plan = variant.geometry
	if p == null or p.volumes == null or p.contacts == null or p.contacts.approach == null or p.contacts.reach == null:
		return &"CONNECTOR_FORMAT"
	var total: int = p.volumes.role.size() + p.contacts.approach.role.size() + p.contacts.reach.role.size()
	if p.cuts_xyz.size() % 3 != 0 or p.cuts_xyz.size() != p.cut_contacts.size() * 3:
		return &"CONNECTOR_FORMAT"
	var limits: Dictionary = domain.descriptor()
	if total + p.cut_contacts.size() > limits.max_regions or p.cut_contacts.size() > limits.max_cells:
		return &"CONNECTOR_CAPACITY"
	for rows: Space.Volumes in [p.volumes, p.contacts.approach, p.contacts.reach]:
		if not _local_rows_valid(rows):
			return &"CONNECTOR_FORMAT"
	var count: int = p.contacts.approach.role.size()
	if count < 1 or p.contacts.reach.role.size() != count or p.contacts.work_xyz.size() != count * 3 \
			or p.contacts.profile_id.size() != count or p.contacts.profile_revision.size() != count:
		return &"CONNECTOR_CONTACT_MISSING"
	var openings: int = p.volumes.role.count(Space.OPENING)
	if placement.opening_refs.size() != openings * 2 or placement.opening_revisions.size() != openings:
		return &"CONNECTOR_OPENING_UNBOUND"
	if variant.start.y == variant.end.y or not _local_landings(variant):
		return &"CONNECTOR_LANDING_MISSING"
	return &""


static func _local_rows_valid(rows: Space.Volumes) -> bool:
	"""Validate local packed columns; their placeholder owner refs are replaced only at placement."""
	var count: int = rows.role.size()
	for column: Variant in [rows.lo_x, rows.lo_y, rows.lo_z, rows.hi_x, rows.hi_y, rows.hi_z,
			rows.level, rows.owner_slot, rows.owner_generation, rows.owner_revision]:
		if column.size() != count:
			return false
	for row: int in count:
		if not Space.valid_box(rows.box_at(row)) or rows.role[row] < Space.ENVELOPE or rows.role[row] > Space.SOLID:
			return false
	return true


static func _local_landings(variant: Definition) -> bool:
	"""The authored endpoint floor contacts must be inside explicit landing footprints."""
	var rows: Space.Volumes = variant.geometry.volumes
	return Space.has_landing(rows, variant.start, variant.start_level_offset) \
		and Space.has_landing(rows, variant.end, variant.end_level_offset) \
		and rows.role.has(Space.SUPPORT_REQUIRED) and rows.role.has(Space.ENVELOPE)


static func _endpoints(variant: Definition, placement: Placement, out: Space.Plan) -> StringName:
	"""Compare exact endpoint heights and levels; incompatible rise never scales the authored piece."""
	if not Space.int32(placement.level_base) or not Space.int32(variant.start_level_offset) \
			or not Space.int32(variant.end_level_offset):
		return &"CONNECTOR_OVERFLOW"
	var points: Array[Vector3i] = [variant.start, variant.end]
	var levels: Array[int] = [variant.start_level_offset, variant.end_level_offset]
	var floors: Array[int] = [placement.start_floor_u, placement.end_floor_u]
	for row: int in 2:
		var point: PackedInt64Array = _point64(points[row], placement)
		var level: int = int(placement.level_base) + int(levels[row])
		if not _point_fits(point) or level < 0 or not Space.int32(level):
			return &"CONNECTOR_OVERFLOW"
		if point[1] != floors[row]:
			return &"CONNECTOR_HEIGHT_MISMATCH"
		out.endpoints_xyz.append_array(PackedInt32Array([point[0], point[1], point[2]]))
		out.endpoint_levels.append(level)
	out.endpoint_refs = placement.endpoint_refs.duplicate()
	out.endpoint_revisions = placement.endpoint_revisions.duplicate()
	return &""


static func _regions(source: Space.Volumes, placement: Placement,
		out: Space.Volumes, bind_openings: bool) -> StringName:
	"""Rotate all eight box corners implicitly through monotone axis extrema, preserving thin shells."""
	var opening: int = 0
	for row: int in source.role.size():
		var box: PackedInt32Array = transform_box(source.box_at(row), placement)
		var level: int = int(placement.level_base) + int(source.level[row])
		if box.is_empty() or level < 0 or not Space.int32(level):
			return &"CONNECTOR_OVERFLOW"
		var owner: Vector2i = placement.owner_ref
		var revision: int = placement.owner_revision
		if bind_openings and source.role[row] == Space.OPENING:
			owner = Vector2i(placement.opening_refs[opening * 2], placement.opening_refs[opening * 2 + 1])
			revision = placement.opening_revisions[opening]
			opening += 1
		if not Space.valid_ref(owner) or revision < 1:
			return &"CONNECTOR_OPENING_UNBOUND"
		out.append(box, source.role[row], level, owner, revision)
	return &""


static func _contacts(source: Space.Contacts, placement: Placement, out: Space.Contacts) -> StringName:
	"""Transform actual approach and reach envelopes together with their profile-qualified work points."""
	var error: StringName = _regions(source.approach, placement, out.approach, false)
	if error != &"":
		return error
	error = _regions(source.reach, placement, out.reach, false)
	if error != &"":
		return error
	for row: int in source.profile_id.size():
		var point: PackedInt64Array = _point64(Space.point_at(source.work_xyz, row), placement)
		if not _point_fits(point):
			return &"CONNECTOR_OVERFLOW"
		if source.profile_id[row] < 0 or source.profile_revision[row] < 1:
			return &"CONNECTOR_PROFILE_MISSING"
		out.work_xyz.append_array(PackedInt32Array([point[0], point[1], point[2]]))
	out.profile_id = source.profile_id.duplicate()
	out.profile_revision = source.profile_revision.duplicate()
	return &""


static func _cuts(domain: Space.Domain, source: Space.Plan, placement: Placement,
		out: Space.Plan) -> StringName:
	"""Rotate cube extents, not just their minimum points, then preserve contact bindings while sorting."""
	var by_origin: Dictionary = {}
	var sorted: Array[Vector3i] = []
	for row: int in source.cut_contacts.size():
		var local: Vector3i = Space.point_at(source.cuts_xyz, row)
		var box: PackedInt32Array = _local_cube(local)
		if box.is_empty():
			return &"CONNECTOR_OVERFLOW"
		box = transform_box(box, placement)
		if box.is_empty():
			return &"CONNECTOR_OVERFLOW"
		var origin: Vector3i = Vector3i(box[0], box[1], box[2])
		if Space.quantum_box(domain, origin) != box or by_origin.has(origin):
			return &"CONNECTOR_CUT_DATUM"
		var contact: int = source.cut_contacts[row]
		if contact < 0 or contact >= source.contacts.profile_id.size():
			return &"CONNECTOR_CONTACT_MISSING"
		by_origin[origin] = contact
		sorted.append(origin)
	_sorted_cuts(sorted, by_origin, out)
	return &""


static func _sorted_cuts(origins: Array[Vector3i], contacts: Dictionary, out: Space.Plan) -> void:
	"""No hash iteration decides paid work order; canonical signed coordinates determine it."""
	origins.sort_custom(Space.point_less)
	for origin: Vector3i in origins:
		out.cuts_xyz.append_array(PackedInt32Array([origin.x, origin.y, origin.z]))
		out.cut_contacts.append(contacts[origin])


static func _local_cube(origin: Vector3i) -> PackedInt32Array:
	"""Check the far corner before narrowing; local lattice alignment is checked after placement."""
	var box: PackedInt32Array = PackedInt32Array([origin.x, origin.y, origin.z])
	for axis: int in 3:
		var far: int = int(origin[axis]) + Space.QUANTUM_U
		if not Space.int32(far):
			return PackedInt32Array()
		box.append(far)
	return box


static func transform_box(box: PackedInt32Array, placement: Placement) -> PackedInt32Array:
	"""Exact quarter turns and translation; int64 intermediates precede all int32 writes."""
	if not Space.valid_box(box) or placement == null or placement.rotation < 0 or placement.rotation > 3:
		return PackedInt32Array()
	var a: PackedInt64Array = _point64(Vector3i(box[0], box[1], box[2]), placement)
	var b: PackedInt64Array = _point64(Vector3i(box[3], box[4], box[5]), placement)
	if not _point_fits(a) or not _point_fits(b):
		return PackedInt32Array()
	return PackedInt32Array([mini(a[0], b[0]), mini(a[1], b[1]), mini(a[2], b[2]),
		maxi(a[0], b[0]), maxi(a[1], b[1]), maxi(a[2], b[2])])


static func _point64(point: Vector3i, placement: Placement) -> PackedInt64Array:
	"""Rotate X/Z around local origin, leaving Y and every relative rise unchanged."""
	var x: int = point.x
	var z: int = point.z
	match placement.rotation:
		1:
			x = -int(point.z)
			z = int(point.x)
		2:
			x = -int(point.x)
			z = -int(point.z)
		3:
			x = int(point.z)
			z = -int(point.x)
	return PackedInt64Array([x + int(placement.origin.x), int(point.y) + int(placement.origin.y),
		z + int(placement.origin.z)])


static func _point_fits(point: PackedInt64Array) -> bool:
	"""No Vector3i conversion is allowed to conceal signed-int32 overflow."""
	return Space.int32(point[0]) and Space.int32(point[1]) and Space.int32(point[2])
