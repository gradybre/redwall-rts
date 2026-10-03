extends RefCounted
## Cold fixed-content compiler. Integer part geometry and conservative volumes; no world authority.
## Numerical rows are authored inputs. Synthetic tests do not become a production connector catalog.

const Space := preload("res://scripts/core/room_space.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const MAX_PARTS: int = 128
const MAX_POINTS: int = 2048
const MAX_PART_POINTS: int = 16
const MAX_TRIANGLES: int = 8192
const MAX_MATERIALS: int = 16
const MAX_LOCAL_U: int = 262144 # Cold arithmetic safety ceiling, not a gameplay size.
const TREAD: int = 0
const RISER: int = 1
const RAMP_DECK: int = 2
const POST: int = 3
const RAIL: int = 4
const LADDER_RAIL: int = 5
const RUNG: int = 6
const HATCH: int = 7
const PART_KIND_COUNT: int = 8


class Limits extends RefCounted:
	var parts: int = 0
	var points: int = 0
	var triangles: int = 0
	var regions: int = 0


class Parts extends RefCounted:
	## Top polygon offsets count vertices (not XYZ scalars); each prism extrudes vertically downward.
	var offsets: PackedInt32Array = PackedInt32Array([0])
	var top_xyz: PackedInt32Array = PackedInt32Array()
	var depth_u: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var level: PackedInt32Array = PackedInt32Array()
	var materials: PackedInt32Array = PackedInt32Array() # top, bottom, sides per part.
	var hinge_edge: PackedInt32Array = PackedInt32Array() # -1 except the one ladder/hatch leaf.


class Row extends RefCounted:
	var definition: Connectors.Definition = null
	var parts: Parts = Parts.new()
	var material_period_u: PackedInt32Array = PackedInt32Array()
	## The authored centre of a spiral; unused by other families. No radius or angle is synthesized.
	var spiral_centre_xz: Vector2i = Vector2i.ZERO


class Compiled extends RefCounted:
	var definition: Connectors.Definition = null
	var triangle_xyz: PackedInt32Array = PackedInt32Array() # nine values per complete triangle.
	var triangle_material: PackedInt32Array = PackedInt32Array()
	var triangle_part: PackedInt32Array = PackedInt32Array()
	var part_kind: PackedInt32Array = PackedInt32Array()
	var material_period_u: PackedInt32Array = PackedInt32Array()
	## One hinge's local start/end XYZ and full sweep; empty for families without a hatch.
	var hinge_xyz: PackedInt32Array = PackedInt32Array()
	var hinge_open_sign: int = 0
	var hatch_sweep: PackedInt32Array = PackedInt32Array()


class Result extends RefCounted:
	var ok: bool = false
	var error: StringName = &""
	var compiled: Compiled = null


static func compile(row: Row, limits: Limits) -> Result:
	"""Return one complete isolated candidate or no geometry; never reserve, pay or publish a route."""
	var out: Result = Result.new()
	out.error = _input_error(row, limits)
	if out.error != &"":
		return out
	var candidate: Compiled = Compiled.new()
	candidate.definition = _copy_definition(row.definition)
	candidate.part_kind = row.parts.kind.duplicate()
	candidate.material_period_u = row.material_period_u.duplicate()
	for part: int in row.parts.kind.size():
		out.error = _compile_part(row.parts, part, limits, candidate)
		if out.error != &"":
			return out
	out.error = _family_error(row, candidate)
	if out.error == &"":
		out.ok = true
		out.compiled = candidate
	return out


static func _input_error(row: Row, limits: Limits) -> StringName:
	"""Refuse unbounded/malformed columns before allocation, copying or narrowing arithmetic."""
	if row == null or limits == null or row.definition == null or row.parts == null:
		return &"CONNECTOR_GEOMETRY_UNBOUND"
	if limits.parts < 1 or limits.parts > MAX_PARTS or limits.points < 3 or limits.points > MAX_POINTS \
			or limits.triangles < 1 or limits.triangles > MAX_TRIANGLES or limits.regions < 1 or limits.regions > Space.MAX_REGIONS:
		return &"CONNECTOR_GEOMETRY_CAPACITY"
	var p: Parts = row.parts
	var count: int = p.kind.size()
	if count < 1 or count > limits.parts or p.top_xyz.size() > limits.points * 3:
		return &"CONNECTOR_GEOMETRY_CAPACITY"
	if p.offsets.size() != count + 1 or p.top_xyz.size() % 3 != 0 or p.offsets[0] != 0 \
			or p.offsets[count] * 3 != p.top_xyz.size() or p.materials.size() != count * 3:
		return &"CONNECTOR_GEOMETRY_FORMAT"
	for column: PackedInt32Array in [p.depth_u, p.level, p.hinge_edge]:
		if column.size() != count:
			return &"CONNECTOR_GEOMETRY_FORMAT"
	if row.material_period_u.is_empty() or row.material_period_u.size() > MAX_MATERIALS:
		return &"CONNECTOR_MATERIAL_MISSING"
	for period: int in row.material_period_u:
		if period < 1 or period > MAX_LOCAL_U:
			return &"CONNECTOR_MATERIAL_SCALE"
	return _content_error(row, limits)


static func _content_error(row: Row, limits: Limits) -> StringName:
	"""Require complete existing metadata/contact contract, not a permissive geometry-only callback."""
	var d: Connectors.Definition = row.definition
	if d.key == &"" or d.revision < 1 or d.family < 0 or d.family >= Connectors.FAMILY_COUNT \
			or d.allowed_rotations < 1 or d.allowed_rotations > 15:
		return &"CONNECTOR_CATALOG_MISSING"
	if not _local_point(d.start) or not _local_point(d.end) or d.start.y == d.end.y:
		return &"CONNECTOR_GEOMETRY_ENDPOINT"
	if not Space.int32(d.start_level_offset) or not Space.int32(d.end_level_offset):
		return &"CONNECTOR_GEOMETRY_ENDPOINT"
	var code: StringName = _plan_error(d.geometry, limits)
	if code != &"":
		return code
	if not Space.has_landing(d.geometry.volumes, d.start, d.start_level_offset) \
			or not Space.has_landing(d.geometry.volumes, d.end, d.end_level_offset):
		return &"CONNECTOR_LANDING_MISSING"
	for material: int in row.parts.materials:
		if material < 0 or material >= row.material_period_u.size():
			return &"CONNECTOR_MATERIAL_MISSING"
	for part: int in row.parts.kind.size():
		code = _part_error(row.parts, part)
		if code != &"":
			return code
	return &""


static func _plan_error(plan: Space.Plan, limits: Limits) -> StringName:
	"""Validate every cold contract column before invoking its copy helpers."""
	if plan == null or plan.volumes == null or plan.contacts == null \
			or plan.contacts.approach == null or plan.contacts.reach == null:
		return &"CONNECTOR_CONTACT_MISSING"
	var count: int = plan.contacts.profile_id.size()
	var total: int = plan.volumes.role.size() + count * 2 + plan.cut_contacts.size()
	if total > limits.regions or plan.cut_contacts.size() > Space.MAX_CELLS:
		return &"CONNECTOR_GEOMETRY_CAPACITY"
	for rows: Space.Volumes in [plan.volumes, plan.contacts.approach, plan.contacts.reach]:
		if not _rows_valid(rows):
			return &"CONNECTOR_GEOMETRY_FORMAT"
	if count < 1 or plan.contacts.approach.role.size() != count or plan.contacts.reach.role.size() != count \
			or plan.contacts.work_xyz.size() != count * 3 or plan.contacts.profile_revision.size() != count \
			or plan.cuts_xyz.size() != plan.cut_contacts.size() * 3:
		return &"CONNECTOR_CONTACT_MISSING"
	for contact: int in count:
		if plan.contacts.profile_id[contact] < 0 or plan.contacts.profile_revision[contact] < 1:
			return &"CONNECTOR_CONTACT_MISSING"
	for contact: int in plan.cut_contacts:
		if contact < 0 or contact >= count:
			return &"CONNECTOR_CONTACT_MISSING"
	if not plan.volumes.role.has(Space.ENVELOPE) or not plan.volumes.role.has(Space.SUPPORT_REQUIRED) \
			or not plan.volumes.role.has(Space.OPENING):
		return &"CONNECTOR_FOOTPRINT_MISSING"
	return &""


static func _rows_valid(rows: Space.Volumes) -> bool:
	"""Count before indexing every packed column; all local boxes and roles are explicit."""
	var count: int = rows.role.size()
	if count > Space.MAX_REGIONS:
		return false
	for column: Variant in [rows.lo_x, rows.lo_y, rows.lo_z, rows.hi_x, rows.hi_y, rows.hi_z,
			rows.level, rows.owner_slot, rows.owner_generation, rows.owner_revision]:
		if column.size() != count:
			return false
	for at: int in count:
		if not Space.valid_box(rows.box_at(at)) or rows.role[at] < Space.ENVELOPE or rows.role[at] > Space.SOLID:
			return false
		for coordinate: int in rows.box_at(at):
			if absi(coordinate) > MAX_LOCAL_U:
				return false
	return true


static func _part_error(parts: Parts, part: int) -> StringName:
	"""Prisms have finite convex planar top polygons and exact positive downward thickness."""
	var begin: int = parts.offsets[part]
	var end: int = parts.offsets[part + 1]
	if begin < 0 or end - begin < 3 or end - begin > MAX_PART_POINTS or end * 3 > parts.top_xyz.size() \
			or parts.kind[part] < 0 or parts.kind[part] >= PART_KIND_COUNT:
		return &"CONNECTOR_PART_FORMAT"
	if parts.depth_u[part] < 1 or parts.depth_u[part] > MAX_LOCAL_U:
		return &"CONNECTOR_PART_THICKNESS"
	if parts.kind[part] != HATCH and parts.hinge_edge[part] != -1:
		return &"CONNECTOR_HINGE_FORMAT"
	for point: int in range(begin, end):
		var top: Vector3i = _point(parts, point)
		if not _local_point(top) or absi(int(top.y) - parts.depth_u[part]) > MAX_LOCAL_U:
			return &"CONNECTOR_GEOMETRY_OVERFLOW"
		if parts.kind[part] in [TREAD, RUNG, HATCH] and top.y != parts.top_xyz[begin * 3 + 1]:
			return &"CONNECTOR_PART_TOP_NOT_FLAT"
	if parts.kind[part] == RAMP_DECK:
		var box: PackedInt32Array = _part_box(parts, part)
		if box[4] - box[1] == parts.depth_u[part]:
			return &"CONNECTOR_RAMP_NOT_SLOPED"
	return _polygon_error(parts, part)


static func _polygon_error(parts: Parts, part: int) -> StringName:
	"""Exact cross products reject concavity, self-intersection, repeated/collinear vertices and warped tops."""
	var begin: int = parts.offsets[part]
	var count: int = parts.offsets[part + 1] - begin
	var first: Vector3i = _point(parts, begin)
	var normal: PackedInt64Array = _cross(_point(parts, begin + 1) - first, _point(parts, begin + 2) - first)
	if normal[1] == 0:
		return &"CONNECTOR_PART_DEGENERATE"
	for edge: int in count:
		var a: Vector3i = _point(parts, begin + edge)
		var b: Vector3i = _point(parts, begin + (edge + 1) % count)
		for other: int in count:
			var c: Vector3i = _point(parts, begin + other)
			if _dot(normal, c - first) != 0:
				return &"CONNECTOR_PART_NONPLANAR"
			if other == edge or other == (edge + 1) % count:
				continue
			var side: int = _cross(b - a, c - a)[1]
			if side == 0 or (side > 0) != (normal[1] > 0):
				return &"CONNECTOR_PART_NONCONVEX"
	return &""


static func _compile_part(parts: Parts, part: int, limits: Limits, out: Compiled) -> StringName:
	"""One top/bottom fan and exact side strips, with conservative physical and moving volumes."""
	var count: int = parts.offsets[part + 1] - parts.offsets[part]
	if out.triangle_material.size() + count * 4 - 4 > limits.triangles:
		return &"CONNECTOR_GEOMETRY_CAPACITY"
	var box: PackedInt32Array = _part_box(parts, part)
	if not _inside_envelope(out.definition.geometry.volumes, box):
		return &"CONNECTOR_PART_OUTSIDE_ENVELOPE"
	var extra: int = 2 if parts.kind[part] == HATCH else 1
	var plan: Space.Plan = out.definition.geometry
	if plan.volumes.role.size() + plan.contacts.profile_id.size() * 2 + plan.cut_contacts.size() + extra > limits.regions:
		return &"CONNECTOR_GEOMETRY_CAPACITY"
	plan.volumes.append(box, Space.SOLID, parts.level[part], Space.NULL_REF, 0)
	if parts.kind[part] == HATCH:
		var code: StringName = _compile_hatch(parts, part, out)
		if code != &"":
			return code
	_emit_prism(parts, part, out)
	return &""


static func _part_box(parts: Parts, part: int) -> PackedInt32Array:
	"""Integer AABB encloses every triangle; no cube quantization or paid cut is added."""
	var first: Vector3i = _point(parts, parts.offsets[part])
	var low: Vector3i = first - Vector3i(0, parts.depth_u[part], 0)
	var high: Vector3i = first
	for at: int in range(parts.offsets[part], parts.offsets[part + 1]):
		var point: Vector3i = _point(parts, at)
		low.x = mini(low.x, point.x)
		low.y = mini(low.y, int(point.y) - parts.depth_u[part])
		low.z = mini(low.z, point.z)
		high = high.max(point)
	return PackedInt32Array([low.x, low.y, low.z, high.x, high.y, high.z])


static func _inside_envelope(volumes: Space.Volumes, box: PackedInt32Array) -> bool:
	"""A single authored envelope must contain a whole part; conservative failure cannot miss a collision."""
	for row: int in volumes.role.size():
		if volumes.role[row] == Space.ENVELOPE and Space.contains_box(volumes.box_at(row), box):
			return true
	return false


static func _emit_prism(parts: Parts, part: int, out: Compiled) -> void:
	"""Normalize winding so closed surfaces all point outward, independently of the authored loop order."""
	var begin: int = parts.offsets[part]
	var count: int = parts.offsets[part + 1] - begin
	var first: Vector3i = _point(parts, begin)
	var forward: bool = _cross(_point(parts, begin + 1) - first, _point(parts, begin + 2) - first)[1] > 0
	var points: Array[Vector3i] = []
	for step: int in count:
		points.append(_point(parts, begin + (step if forward else (count - step) % count)))
	var down: Vector3i = Vector3i(0, parts.depth_u[part], 0)
	for step: int in range(1, count - 1):
		_triangle(out, part, parts.materials[part * 3], points[0], points[step], points[step + 1])
		_triangle(out, part, parts.materials[part * 3 + 1], points[0] - down, points[step + 1] - down, points[step] - down)
	for step: int in count:
		var a: Vector3i = points[step]
		var b: Vector3i = points[(step + 1) % count]
		_triangle(out, part, parts.materials[part * 3 + 2], a, a - down, b - down)
		_triangle(out, part, parts.materials[part * 3 + 2], a, b - down, b)


static func _triangle(out: Compiled, part: int, material: int, a: Vector3i, b: Vector3i, c: Vector3i) -> void:
	"""Append a complete triangle only after the whole part's output budget was checked."""
	out.triangle_xyz.append_array(PackedInt32Array([a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z]))
	out.triangle_material.append(material)
	out.triangle_part.append(part)


static func _compile_hatch(parts: Parts, part: int, out: Compiled) -> StringName:
	"""A horizontal rectangular leaf rotates upward by a quarter-turn around its exact authored edge."""
	if not out.hinge_xyz.is_empty() or parts.offsets[part + 1] - parts.offsets[part] != 4 \
			or parts.hinge_edge[part] < 0 or parts.hinge_edge[part] > 3:
		return &"CONNECTOR_HINGE_FORMAT"
	var begin: int = parts.offsets[part]
	var a: Vector3i = _point(parts, begin + parts.hinge_edge[part])
	var b: Vector3i = _point(parts, begin + (parts.hinge_edge[part] + 1) % 4)
	var box: PackedInt32Array = _part_box(parts, part)
	if (a.x != b.x and a.z != b.z) or a.y != b.y or box[4] != a.y:
		return &"CONNECTOR_HINGE_FORMAT"
	for at: int in range(begin, begin + 4):
		var point: Vector3i = _point(parts, at)
		if point.y != a.y or point.x not in [box[0], box[3]] or point.z not in [box[2], box[5]]:
			return &"CONNECTOR_HINGE_FORMAT"
	var sweep: PackedInt32Array = _hatch_box(a, b, box, parts.depth_u[part])
	if sweep.is_empty() or not _inside_envelope(out.definition.geometry.volumes, sweep):
		return &"CONNECTOR_HATCH_SWEEP_OUTSIDE_ENVELOPE"
	out.hinge_xyz = PackedInt32Array([a.x, a.y, a.z, b.x, b.y, b.z])
	out.hinge_open_sign = signi(int(b.z - a.z) * (int(box[0]) + box[3] - int(a.x) * 2)
		- int(b.x - a.x) * (int(box[2]) + box[5] - int(a.z) * 2))
	out.hatch_sweep = sweep
	out.definition.geometry.volumes.append(sweep, Space.ENVELOPE, parts.level[part], Space.NULL_REF, 0)
	return &""


static func _hatch_box(a: Vector3i, b: Vector3i, box: PackedInt32Array, depth: int) -> PackedInt32Array:
	"""Outward integer radius covers every intermediate leaf angle, including its actual thickness."""
	var axis: int = 2 if a.x != b.x else 0
	var span: int = box[axis + 3] - box[axis]
	var radius: int = _ceil_sqrt(span * span + depth * depth)
	var low: PackedInt64Array = PackedInt64Array([box[0], a.y - depth, box[2]])
	var high: PackedInt64Array = PackedInt64Array([box[3], a.y + radius, box[5]])
	if a[axis] == box[axis]:
		high[axis] = int(a[axis]) + radius
	else:
		low[axis] = int(a[axis]) - radius
	for value: int in low + high:
		if absi(value) > MAX_LOCAL_U:
			return PackedInt32Array()
	return PackedInt32Array([low[0], low[1], low[2], high[0], high[1], high[2]])


static func _family_error(row: Row, compiled: Compiled) -> StringName:
	"""Require the actual distinguishing construction parts, without inventing dimensions or permissions."""
	var kinds: PackedInt32Array = row.parts.kind
	if row.definition.family != Connectors.LADDER_HATCH and not compiled.hinge_xyz.is_empty():
		return &"CONNECTOR_HINGE_FAMILY"
	match row.definition.family:
		Connectors.EARTH_TIMBER:
			if not kinds.has(TREAD) or not kinds.has(RISER) or not kinds.has(RAIL):
				return &"CONNECTOR_FAMILY_INCOMPLETE"
		Connectors.STONE:
			if not kinds.has(TREAD) or not kinds.has(RAIL):
				return &"CONNECTOR_FAMILY_INCOMPLETE"
		Connectors.RAMP:
			if not kinds.has(RAMP_DECK) or not kinds.has(RAIL):
				return &"CONNECTOR_FAMILY_INCOMPLETE"
		Connectors.SPIRAL:
			if kinds.count(TREAD) < 3 or not kinds.has(POST) or not kinds.has(RAIL):
				return &"CONNECTOR_FAMILY_INCOMPLETE"
			return _spiral_error(row)
		Connectors.LADDER_HATCH:
			if kinds.count(LADDER_RAIL) < 2 or not kinds.has(RUNG) or kinds.count(HATCH) != 1:
				return &"CONNECTOR_FAMILY_INCOMPLETE"
	return &""


static func _spiral_error(row: Row) -> StringName:
	"""Require the explicit centre's support and consistently winding authored tread centres."""
	var centre: Vector2i = row.spiral_centre_xz
	if absi(int(centre.x)) > MAX_LOCAL_U or absi(int(centre.y)) > MAX_LOCAL_U:
		return &"CONNECTOR_GEOMETRY_OVERFLOW"
	var supported: bool = false
	var previous: Vector2i = Vector2i.ZERO
	var direction: int = 0
	for part: int in row.parts.kind.size():
		if row.parts.kind[part] == POST:
			var box: PackedInt32Array = _part_box(row.parts, part)
			supported = supported or (box[0] <= centre.x and centre.x < box[3] and box[2] <= centre.y and centre.y < box[5])
		elif row.parts.kind[part] == TREAD:
			var current: Vector2i = _centroid_sum(row.parts, part, centre)
			var cross: int = int(previous.x) * current.y - int(previous.y) * current.x
			if previous != Vector2i.ZERO and (cross == 0 or (direction != 0 and signi(cross) != direction)):
				return &"CONNECTOR_SPIRAL_WINDING"
			if cross != 0:
				direction = signi(cross)
			previous = current
	return &"" if supported and direction != 0 else &"CONNECTOR_SPIRAL_SUPPORT"


static func _centroid_sum(parts: Parts, part: int, centre: Vector2i) -> Vector2i:
	"""Use the unnormalized sum: convex polygon vertex count cannot affect winding sign."""
	var x: int = 0
	var z: int = 0
	for at: int in range(parts.offsets[part], parts.offsets[part + 1]):
		var point: Vector3i = _point(parts, at)
		x += int(point.x) - centre.x
		z += int(point.z) - centre.y
	return Vector2i(x, z) # At most 16 * 2 * MAX_LOCAL_U, checked before this narrowing.


static func _copy_definition(source: Connectors.Definition) -> Connectors.Definition:
	"""Copy validated cold content; editing the authoring row cannot resize an already compiled preview."""
	var out: Connectors.Definition = Connectors.Definition.new()
	out.key = source.key
	out.revision = source.revision
	out.family = source.family
	out.allowed_rotations = source.allowed_rotations
	out.start = source.start
	out.end = source.end
	out.start_level_offset = source.start_level_offset
	out.end_level_offset = source.end_level_offset
	out.geometry.volumes = source.geometry.volumes.copy()
	out.geometry.contacts = source.geometry.contacts.copy()
	out.geometry.cuts_xyz = source.geometry.cuts_xyz.duplicate()
	out.geometry.cut_contacts = source.geometry.cut_contacts.duplicate()
	return out


static func _point(parts: Parts, index: int) -> Vector3i:
	"""Read a validated packed vertex (constructor itself performs no arithmetic)."""
	return Vector3i(parts.top_xyz[index * 3], parts.top_xyz[index * 3 + 1], parts.top_xyz[index * 3 + 2])


static func _local_point(point: Vector3i) -> bool:
	"""The explicit coordinate ceiling keeps every cross/dot operation safely inside int64."""
	return absi(int(point.x)) <= MAX_LOCAL_U and absi(int(point.y)) <= MAX_LOCAL_U and absi(int(point.z)) <= MAX_LOCAL_U


static func _cross(a: Vector3i, b: Vector3i) -> PackedInt64Array:
	"""Vector3i.cross would narrow intermediate results; keep exact int64 products instead."""
	return PackedInt64Array([int(a.y) * b.z - int(a.z) * b.y,
		int(a.z) * b.x - int(a.x) * b.z, int(a.x) * b.y - int(a.y) * b.x])


static func _dot(a: PackedInt64Array, b: Vector3i) -> int:
	"""At the local coordinate ceiling, even the sum of all three products fits int64."""
	return a[0] * b.x + a[1] * b.y + a[2] * b.z


static func _ceil_sqrt(value: int) -> int:
	"""Exact outward length enclosure; no floating point or 1024u paid-cut rounding."""
	var low: int = 0
	var high: int = 3 * MAX_LOCAL_U
	while low < high:
		@warning_ignore("integer_division") var mid: int = (low + high) / 2
		if mid * mid >= value:
			high = mid
		else:
			low = mid + 1
	return low
