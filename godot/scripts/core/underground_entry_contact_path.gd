extends RefCounted
## ADR1202: production ground path between the material STORAGE endpoint M and an installed WORK contact.
## A paid installation creates its contact with no route edge; the next installation stationed on it (T0 on
## the L0 landing) cannot open until one exists. The ADR1191 work-area surveys leave one real gap between the
## surface footing and the installed deck: the ground strip north of the excavation face and the air above it.
## This surveys that strip through SurfaceAnchor (natural support and exterior air are Terrain's proofs), then
## publishes walking polylines both ways through WorldRoutes, which keeps every endpoint, footing, air and
## profile proof. It publishes no Room, Site, Job or permission and relabels no geometry.
## Split landing (ADR1202 blocker 3): when the contact has an installed arrival behind it, M <-> arrival is the
## all-yaw ground polyline and arrival <-> contact is one straight leg on the contact's own line, for the narrow
## forward and backward approach profiles. WorldRoutes alone decides which profiles fit each edge.

const Anchor := preload("res://scripts/core/underground_surface_anchor.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_OWNER: StringName = &"ENTRY_CONTACT_PATH_OWNER"
const REFUSE_LEASE: StringName = &"ENTRY_CONTACT_PATH_LEASE"
## Source-local crossing survey, relative to the entry origin: from the excavation's north face (z = 0) to the
## work-area storage footing (z = 238), as wide as the all-yaw stance; air spans the gap between the contact's
## own air (z <= -280), the storage air (z >= 280) and the outer pair airs (|x| >= 280).
const CROSSING_POINT: Array[int] = [0, 0, 128]
const CROSSING_AIR: Array[int] = [-280, 0, -280, 280, 1036, 280]
const CROSSING_FOOT: Array[int] = [-406, -1, 0, 406, 0, 238]
## Source-local depth of the turn from M's line onto the contact's line, on surveyed storage ground.
const BEND_Z: int = 2048


class Ends extends RefCounted:
	## The live Locations, the entry origin and the content revision every route reader names.
	var ground: Vector2i = NULL_REF
	var contact: Vector2i = NULL_REF
	var arrival: Vector2i = NULL_REF # Optional: the ground path then ends here and one straight leg follows.
	var origin: Vector3i = Vector3i.ZERO
	var content_revision: int = 0
	var crossing: Vector2i = NULL_REF


static func publish(anchor: Anchor, binding: WorldRoutes, routes: Routes, budget: Budget, owner: RefCounted,
		ends: Ends, locations: Locations) -> StringName:
	"""Survey the crossing strip, then stage, seal and publish every leg and its reverse once."""
	if anchor == null or binding == null or routes == null or budget == null or owner == null or ends == null \
			or locations == null:
		return REFUSE_OWNER
	var records: Array[Locations.Record] = [_record(locations, ends.ground), _record(locations, ends.arrival),
		_record(locations, ends.contact)]
	if records[0] == null or records[2] == null or (ends.arrival != NULL_REF and records[1] == null):
		return REFUSE_OWNER
	var code: StringName = _survey_crossing(anchor, ends, records[0].section)
	if code != &"": return code
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return REFUSE_LEASE
	var begun: Routes.Result = binding.begin_prepare(lease)
	code = begun.error
	if code == &"": code = _refresh_live(routes, begun.token)
	if code == &"": code = _stage_legs(routes, begun.token, ends, records, owner)
	if code == &"": code = binding.seal(begun.token)
	if code == &"": code = binding.publish(begun.token)
	binding.abort(begun.token)
	budget.release(lease)
	return code


static func _stage_legs(routes: Routes, token: int, ends: Ends, records: Array[Locations.Record],
		owner: RefCounted) -> StringName:
	"""Ground to the arrival (or straight to the contact) on the bend polyline; then arrival to contact."""
	var split: bool = ends.arrival != NULL_REF
	var near: Vector2i = ends.arrival if split else ends.contact
	var near_point: Vector3i = records[1].point if split else records[2].point
	var code: StringName = _stage_both(routes, token, ends, [ends.ground, near],
		polyline(ends.origin, records[0].point, near_point), records[0], owner)
	if code != &"" or not split: return code
	var deck: Array[Vector3i] = [records[1].point, records[2].point]
	return _stage_both(routes, token, ends, [ends.arrival, ends.contact], deck, records[2], owner)


static func _stage_both(routes: Routes, token: int, ends: Ends, pair: Array[Vector2i], points: Array[Vector3i],
		domain: Locations.Record, owner: RefCounted) -> StringName:
	"""Stage one polyline from pair[0] to pair[1], then its exact reverse, in domain's section, Room and level."""
	for reverse: bool in [false, true]:
		var code: StringName = routes.stage_add(token, _edge(ends, pair, points, domain, owner, reverse)).error
		if code != &"": return code
	return &""


static func _refresh_live(routes: Routes, token: int) -> StringName:
	"""The survey advanced the Space revision: WorldRoutes requalifies every retained span before the seal."""
	for row: int in routes._edge_capacity:
		if routes._live.present[row] == 0: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row])
		var code: StringName = routes.stage_refresh(token, ref)
		if code != &"": return code
	return &""


static func _survey_crossing(anchor: Anchor, ends: Ends, section: Vector2i) -> StringName:
	"""One natural TRANSIT contact in the ground section; Anchor proves the footing and the air independently."""
	var at: Vector3i = ends.origin + Vector3i(CROSSING_POINT[0], CROSSING_POINT[1], CROSSING_POINT[2])
	var created: Anchor.Result = anchor.create_in_section(at, _offset(CROSSING_AIR, ends.origin),
		_offset(CROSSING_FOOT, ends.origin), section, Locations.ROLE_TRANSIT)
	ends.crossing = created.location
	return created.error


static func _offset(box: Array[int], at: Vector3i) -> PackedInt32Array:
	"""Integer translation only."""
	return PackedInt32Array([box[0] + at.x, box[1] + at.y, box[2] + at.z, box[3] + at.x, box[4] + at.y, box[5] + at.z])


static func _record(locations: Locations, ref: Vector2i) -> Locations.Record:
	"""One complete live Location record, or null (also for the null handle)."""
	var record: Locations.Record = Locations.Record.new()
	record.envelope.resize(6)
	record.support.resize(6)
	return record if ref != NULL_REF and locations.read_location_into(ref, record) == &"" else null


static func _edge(ends: Ends, pair: Array[Vector2i], points: Array[Vector3i], domain: Locations.Record,
		owner: RefCounted, reverse: bool) -> Routes.Edge:
	"""One level walking polyline in the domain endpoint's section, Room and level; axis-aligned legs only."""
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = pair[1] if reverse else pair[0]
	edge.to_location = pair[0] if reverse else pair[1]
	edge.section = domain.section
	edge.room = domain.room
	edge.level = domain.level; edge.family = -1; edge.variant = 0
	edge.mode = Profiles.MODE_WALK; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = ends.content_revision
	edge.geometry_revision = owner.revision()
	var ordered: Array[Vector3i] = points.duplicate()
	if reverse: ordered.reverse()
	for at: Vector3i in ordered: edge.points.append_array(PackedInt32Array([at.x, at.y, at.z]))
	edge.point_count = ordered.size()
	for i: int in range(1, ordered.size()):
		edge.length_u += absi(ordered[i].x - ordered[i - 1].x) + absi(ordered[i].z - ordered[i - 1].z)
	return edge


static func polyline(origin: Vector3i, ground: Vector3i, contact: Vector3i) -> Array[Vector3i]:
	"""Ground point, across to the contact's line at the bend depth, then straight along it to the contact."""
	var result: Array[Vector3i] = [ground]
	var bend: Vector3i = Vector3i(contact.x, ground.y, origin.z + BEND_Z)
	if bend != ground: result.append(bend)
	result.append(contact)
	return result
