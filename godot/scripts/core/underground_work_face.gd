extends RefCounted
## Cold completed-space work-face observation. No Room/Site claim, Job or productive permission.
## Sources and integer envelopes are actual; source/profile qualification is not invented here.

const Routes := preload("res://scripts/core/underground_world_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const FinalFacts := preload("res://scripts/core/underground_final_facts.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CONTROL_BYTES: int = 2048
const COLD_BYTES: int = Routes.SNAPSHOT_BYTES + 48 * Routes.FRAGMENT_CAPACITY + CONTROL_BYTES
const TERRAIN_CHECKS: int = 2 * (Profiles.MAX_SELECTION_BOXES + 1) * Terrain.LOCAL_QUERY_CHECKS
const REFUSE_BINDING: StringName = &"WORK_FACE_ACTUAL_BINDING"
const REFUSE_LEASE: StringName = &"WORK_FACE_COLD_LEASE"
const REFUSE_STALE: StringName = &"WORK_FACE_SOURCE_CHANGED"
const REFUSE_PROFILE: StringName = &"WORK_FACE_PROFILE"
const REFUSE_TARGET: StringName = &"WORK_FACE_TARGET"
const REFUSE_BODY: StringName = &"WORK_FACE_COMPLETE_SPACE"
const REFUSE_STANCE: StringName = &"WORK_FACE_SUPPORT"
const REFUSE_STROKE: StringName = &"WORK_FACE_STROKE"
const REFUSE_CONTACT: StringName = &"WORK_FACE_CONTACT"
const REFUSE_BUSY: StringName = &"WORK_FACE_REENTRY"


class Request extends RefCounted:
	## Caller-owned cold input. Face order is -X,+X,-Y,+Y,-Z,+Z; origin is absolute datum-aligned units.
	var location: Vector2i = NULL_REF
	var target_origin: Vector3i = Vector3i.ZERO
	var face: int = -1
	var profile_id: int = -1
	var profile_revision: int = 0
	var content_revision: int = 0
	var geometry_revision: int = 0
	var yaw: int = -1


class Check extends RefCounted:
	## One lease-bound packet, held only for this synchronous observation; never saved or retained per worker.
	var actual: Routes.Configuration = Routes.Configuration.new()
	var original: Routes.Configuration = null
	var request: Request = Request.new()
	var original_request: Request = null
	var token: int = 0
	var world_seed: int = 0
	var domain: Space.Domain = null
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	var body: Profiles.Box = Profiles.Box.new()
	var stance: Profiles.Box = Profiles.Box.new()
	var endpoint: Locations.Record = Locations.Record.new()
	var endpoint_after: Locations.Record = Locations.Record.new()
	var section: Owner.Region = Owner.Region.new()
	var proof: Routes.Clearance = null
	var target: PackedInt32Array = PackedInt32Array()
	var bounds: PackedInt32Array = PackedInt32Array()
	var support: PackedInt32Array = PackedInt32Array()
	var scratch: PackedInt32Array = PackedInt32Array()
	var contact: Vector3i = Vector3i.ZERO
	var has_contact: bool = false
	var has_patch: bool = false
	var stroke_touches_contact: bool = false

	static func input_refusal(config: Routes.Configuration, query: Request, cold: int) -> StringName:
		"""Only pure bound-owner checks run before the actual lease admits any private packet allocation."""
		if config == null or query == null or config.budget == null or not config.budget.covers(cold, COLD_BYTES):
			return REFUSE_LEASE
		if config.routes == null or config.owner == null or config.sources == null or config.locations == null \
				or config.profiles == null or config.residents == null or config.transforms == null \
				or config.terrain == null or config.world == null:
			return REFUSE_BINDING
		if not config.routes.binding_matches(config.residents, config.transforms, config.locations,
				config.owner, config.budget, config.profiles) or not config.owner.is_bound_sources(config.sources) \
				or config.sources.resident_locations_owner() != config.routes \
				or not config.locations.is_bound_budget(config.budget) or not config.terrain.is_bound_budget(config.budget) \
				or not config.terrain.is_bound_world(config.world, config.owner, config.sources) \
				or not config.owner.allocation_within(Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY):
			return REFUSE_BINDING
		if query.face < 0 or query.face > 5 or query.yaw < 0 or query.yaw > 65535 \
				or query.geometry_revision < 1 or query.profile_id < 0 or query.profile_revision < 1 \
				or query.content_revision < 1:
			return REFUSE_PROFILE
		return &""

	func hold(config: Routes.Configuration, query: Request, cold: int) -> void:
		"""Pin every consumed owner strongly and copy all query fields under the already admitted original lease."""
		original = config
		original_request = query
		actual.routes = config.routes
		actual.owner = config.owner
		actual.sources = config.sources
		actual.locations = config.locations
		actual.profiles = config.profiles
		actual.residents = config.residents
		actual.transforms = config.transforms
		actual.terrain = config.terrain
		actual.world = config.world
		actual.budget = config.budget
		request.location = query.location
		request.target_origin = query.target_origin
		request.face = query.face
		request.profile_id = query.profile_id
		request.profile_revision = query.profile_revision
		request.content_revision = query.content_revision
		request.geometry_revision = query.geometry_revision
		request.yaw = query.yaw
		token = cold
		world_seed = actual.world.section_1_published_seed()

	func allocate_outputs() -> void:
		"""Packed arrays are copy-on-write values: size the actual fixed fields, not loop aliases."""
		endpoint.envelope.resize(6)
		endpoint.support.resize(6)
		endpoint_after.envelope.resize(6)
		endpoint_after.support.resize(6)
		section.box.resize(6)
		bounds.resize(6)
		support.resize(6)
		scratch.resize(6)

	func current_refusal() -> StringName:
		"""After callbacks, compare pure actual identities/revisions and the unchanged caller request again."""
		if not actual.budget.covers(token, COLD_BYTES):
			return REFUSE_LEASE
		if actual.routes != original.routes or actual.owner != original.owner or actual.sources != original.sources \
				or actual.locations != original.locations or actual.profiles != original.profiles \
				or actual.residents != original.residents or actual.transforms != original.transforms \
				or actual.terrain != original.terrain or actual.world != original.world or actual.budget != original.budget:
			return REFUSE_STALE
		if not same_request() or actual.owner.revision() != request.geometry_revision or actual.owner.has_prepared() \
				or actual.profiles.content_revision() != request.content_revision \
				or not actual.world.is_published() or actual.world.section_1_published_seed() != world_seed:
			return REFUSE_STALE
		if domain != null and (not actual.sources.directory().is_valid_of_kind(domain._world, Directory.KIND_WORLD) \
				or not actual.locations.is_bound_world(actual.sources.directory(), domain._world, actual.owner)):
			return REFUSE_STALE
		if endpoint.payload_revision > 0 and (not actual.locations.is_live_location(request.location) \
				or actual.locations.location_revision(request.location) != endpoint.payload_revision \
				or not actual.owner.is_live_region(endpoint.section) \
				or (endpoint.room != NULL_REF and not actual.sources.directory().is_valid_of_kind(endpoint.room, Directory.KIND_ROOM))):
			return REFUSE_STALE
		return &""

	func same_request() -> bool:
		"""Late request mutation is refused, even when a previous private snapshot still happens to fit."""
		return request.location == original_request.location and request.target_origin == original_request.target_origin \
			and request.face == original_request.face and request.profile_id == original_request.profile_id \
			and request.profile_revision == original_request.profile_revision \
			and request.content_revision == original_request.content_revision \
			and request.geometry_revision == original_request.geometry_revision and request.yaw == original_request.yaw

	func run() -> StringName:
		"""One actual traversal image is acquired only after exact descriptor, endpoint and dry target checks."""
		allocate_outputs()
		var code: StringName = current_refusal()
		if code != &"":
			return code
		domain = actual.owner.domain_copy()
		code = current_refusal()
		if code == &"" and domain != null and domain._checks < TERRAIN_CHECKS + 3 * Routes.SOURCE_PASS_CHECKS:
			return &"WORLD_ROUTE_CHECK_CAPACITY"
		if code == &"":
			code = identities_refusal()
		if code == &"":
			code = snapshot_refusal()
		if code == &"":
			code = geometry_refusal()
		if code == &"":
			code = finish_refusal()
		return code if code != &"" else current_refusal()

	func identities_refusal() -> StringName:
		"""Loaded source authority and an already completed endpoint are necessary, never a caller-selected worker."""
		if domain == null:
			return REFUSE_BINDING
		var code: StringName = actual.profiles.descriptor_into(request.profile_id, request.content_revision, descriptor)
		if code == &"":
			code = current_refusal()
		if code != &"":
			return code
		if descriptor.profile_revision != request.profile_revision or descriptor.mode != Profiles.MODE_WORK \
				or descriptor.work_kind != Jobs.JOB_KIND_BUILD or descriptor.certificate_flags != Profiles.CERT_REQUIRED \
				or descriptor.yaw_kind != Profiles.YAW_EXACT or descriptor.yaw != request.yaw \
				or descriptor.contact_kind != Profiles.CONTACT_ANCHOR_AND_PATCH:
			return REFUSE_PROFILE
		code = actual.locations.read_location_into(request.location, endpoint)
		if code == &"":
			code = current_refusal()
		if code == &"":
			code = actual.owner.region_into_reused(endpoint.section, section)
		if code == &"":
			code = current_refusal()
		return code if code != &"" else target_refusal()

	func target_refusal() -> StringName:
		"""Allocate the exact target only after endpoint and section observations still retain the original lease."""
		if endpoint.world != domain._world or endpoint.geometry_revision != request.geometry_revision \
				or section.role != Space.FLOOR_DATUM or section.level != endpoint.level \
				or endpoint.point.y != section.box[1] or endpoint.role == Locations.ROLE_STORAGE:
			return REFUSE_STALE
		target = Space.quantum_box(domain, request.target_origin)
		if target.is_empty():
			return REFUSE_TARGET
		var code: StringName = actual.terrain.dig_refusal(target)
		return code if code != &"" else current_refusal()

	func snapshot_refusal() -> StringName:
		"""The earlier admission survey must already be dropped; this is one separately charged physical image."""
		var code: StringName = current_refusal()
		if code != &"":
			return code
		var image: Space.Snapshot = Space.Snapshot.new()
		code = actual.owner.snapshot_for_traversal_leased_into(image, actual.budget, token)
		if code == &"":
			code = current_refusal()
		if code != &"":
			return code
		if image.world_ref != domain._world or image.revision != request.geometry_revision \
				or image.volumes.role.size() > Budget.REGION_CAPACITY or image.live_revisions.size() > Budget.SOURCE_CAPACITY:
			return REFUSE_STALE
		proof = Routes.Clearance.new()
		proof.allocate(image, domain._checks - TERRAIN_CHECKS)
		if not proof.spend(3 * Routes.SOURCE_PASS_CHECKS):
			return proof.error
		for row: int in image.volumes.role.size():
			if not proof.spend():
				return proof.error
			if image.volumes.role[row] in [Space.DRY_SOLID, Space.FLOOR_DATUM]:
				continue
			proof.read_box(row, scratch)
			if Space.overlaps(target, scratch):
				return REFUSE_TARGET
		return &""

	func geometry_refusal() -> StringName:
		"""Keep actual stance, body and recovery independent from the sole permitted target-stroke intersection."""
		var code: StringName = stances_refusal()
		if code != &"":
			return code
		for ordinal: int in descriptor.box_count:
			code = actual.profiles.box_into(request.profile_id, request.profile_revision, request.content_revision, ordinal, body)
			if code == &"":
				code = box_refusal()
			if code != &"":
				return code
		return &"" if has_contact and has_patch and stroke_touches_contact else REFUSE_CONTACT

	func box_refusal() -> StringName:
		"""Translate source-oriented boxes only; point faces use inclusive plane checks separately from volumes."""
		if not proof.spend():
			return proof.error
		if body.role == Profiles.STANCE_SUPPORT:
			return &""
		if body.role == Profiles.CONTACT_POINT:
			return contact_refusal()
		if body.role == Profiles.CONTACT_PATCH:
			return patch_refusal()
		var code: StringName = translate_into(body, bounds)
		if code == &"":
			code = actual.terrain.exclusions_refusal(bounds)
		if code != &"":
			return code
		if body.role == Profiles.WORK_STROKE:
			return stroke_refusal()
		if proof.blocked(bounds, true) or not body_covered() or not solid_contacts_covered():
			return proof.error if proof.error != &"" else REFUSE_BODY
		return current_refusal()

	func stances_refusal() -> StringName:
		"""Every authored stance volume requires actual support before any body residual can share it."""
		for ordinal: int in descriptor.box_count:
			if not proof.spend():
				return proof.error
			var code: StringName = actual.profiles.box_into(request.profile_id, request.profile_revision,
				request.content_revision, ordinal, stance)
			if code != &"":
				return code
			if stance.role != Profiles.STANCE_SUPPORT:
				continue
			code = translate_into(stance, support)
			if code == &"":
				code = actual.terrain.exclusions_refusal(support)
			if code != &"":
				return code
			if proof.blocked(support, true) or not proof.covered(support, Space.SUPPORT):
				return proof.error if proof.error != &"" else REFUSE_STANCE
		return current_refusal()

	func body_covered() -> bool:
		"""Never clip negative body coordinates; actual support and the exact stance explain that volume."""
		proof.start(bounds)
		return proof.subtract_role(Space.SUPPORTED_VOID) and subtract_stances() and proof.count == 0

	func subtract_stances() -> bool:
		"""Only the intersection with a source-authored stance may consume actual support contact."""
		for ordinal: int in descriptor.box_count:
			if not proof.spend() or actual.profiles.box_into(request.profile_id, request.profile_revision,
					request.content_revision, ordinal, stance) != &"":
				return false
			if stance.role == Profiles.STANCE_SUPPORT and (translate_into(stance, support) != &"" \
					or not proof.subtract_role(Space.SUPPORT, support)):
				return false
		return true

	func solid_contacts_covered() -> bool:
		"""A positive void row cannot conceal an intersecting wall or unrelated support volume."""
		for row: int in proof.image.volumes.role.size():
			if not proof.spend():
				return false
			if proof.image.volumes.role[row] not in [Space.DRY_SOLID, Space.SUPPORT]:
				continue
			proof.read_box(row, scratch)
			if not Space.overlaps(scratch, bounds):
				continue
			for axis: int in 3:
				scratch[axis] = maxi(scratch[axis], bounds[axis])
				scratch[axis + 3] = mini(scratch[axis + 3], bounds[axis + 3])
			proof.start(scratch)
			if not subtract_stances() or proof.count != 0:
				return false
		return true

	func stroke_refusal() -> StringName:
		"""Only the exact queried target may contain solid stroke; a second cube or support is not excused."""
		if proof.blocked(bounds, true):
			return proof.error if proof.error != &"" else REFUSE_STROKE
		for row: int in proof.image.volumes.role.size():
			if not proof.spend():
				return proof.error
			if proof.image.volumes.role[row] not in [Space.SUPPORT, Space.DRY_SOLID]:
				continue
			proof.read_box(row, scratch)
			if not Space.overlaps(bounds, scratch):
				continue
			if proof.image.volumes.role[row] == Space.SUPPORT:
				return REFUSE_STROKE
			for axis: int in 3:
				if maxi(bounds[axis], scratch[axis]) < target[axis] \
						or mini(bounds[axis + 3], scratch[axis + 3]) > target[axis + 3]:
					return REFUSE_STROKE
		proof.start(bounds)
		if not proof.subtract_role(Space.SUPPORTED_VOID):
			return proof.error
		for axis: int in 6:
			proof.cover[axis] = target[axis]
		if not proof.subtract_cover() or proof.count != 0:
			return proof.error if proof.error != &"" else REFUSE_STROKE
		return current_refusal()

	func contact_refusal() -> StringName:
		"""One exact face-plane point includes max faces and must actually be reached by an authored stroke."""
		for axis: int in 3:
			var value: int = int(endpoint.point[axis]) + int(body.low[axis])
			if not Space.int32(value):
				return REFUSE_CONTACT
			contact[axis] = value
		@warning_ignore("integer_division") var face_axis: int = request.face / 2
		var plane: int = target[face_axis + (3 if request.face % 2 == 1 else 0)]
		if contact[face_axis] != plane or (request.face % 2 == 0 and endpoint.point[face_axis] >= plane) \
				or (request.face % 2 == 1 and endpoint.point[face_axis] < plane):
			return REFUSE_CONTACT
		for axis: int in 3:
			if contact[axis] < target[axis] or contact[axis] > target[axis + 3]:
				return REFUSE_CONTACT
		has_contact = true
		return contact_stroke_refusal()

	func patch_refusal() -> StringName:
		"""The complete positive-area source patch must lie on the chosen face, never just its focus anchor."""
		@warning_ignore("integer_division") var face_axis: int = request.face / 2
		var plane: int = target[face_axis + (3 if request.face % 2 == 1 else 0)]
		for axis: int in 3:
			var low: int = int(endpoint.point[axis]) + int(body.low[axis])
			var high: int = int(endpoint.point[axis]) + int(body.high[axis])
			if not Space.int32(low) or not Space.int32(high):
				return REFUSE_CONTACT
			if axis == face_axis:
				if low != plane or high != plane:
					return REFUSE_CONTACT
			elif low >= high or low < target[axis] or high > target[axis + 3]:
				return REFUSE_CONTACT
		has_patch = true
		return &""

	func contact_stroke_refusal() -> StringName:
		"""A point on the right plane alone is insufficient when the loaded stroke never reaches it."""
		for ordinal: int in descriptor.box_count:
			if not proof.spend():
				return proof.error
			var code: StringName = actual.profiles.box_into(request.profile_id, request.profile_revision,
				request.content_revision, ordinal, stance)
			if code != &"":
				return code
			if stance.role != Profiles.WORK_STROKE:
				continue
			code = translate_into(stance, support)
			if code != &"":
				return code
			if contact.x >= support[0] and contact.y >= support[1] and contact.z >= support[2] \
					and contact.x <= support[3] and contact.y <= support[4] and contact.z <= support[5]:
				stroke_touches_contact = true
		return &"" if stroke_touches_contact else REFUSE_CONTACT

	func translate_into(box: Profiles.Box, out: PackedInt32Array) -> StringName:
		"""Compute in int64 before narrowing; a source extent never wraps or escapes the finite actual Domain."""
		for axis: int in 3:
			var low: int = int(endpoint.point[axis]) + int(box.low[axis])
			var high: int = int(endpoint.point[axis]) + int(box.high[axis])
			if low < domain._bounds[axis] or high > domain._bounds[axis + 3] or low >= high:
				return REFUSE_BODY
			out[axis] = low
			out[axis + 3] = high
		return &""

	func finish_refusal() -> StringName:
		"""Finish observation callbacks before rereading actual local and retained facts from leaf stores."""
		var code: StringName = actual.owner.snapshot_revision_refusal(request.geometry_revision)
		if code == &"":
			code = actual.terrain.binding_refusal()
		if code == &"":
			code = actual.locations.read_location_into(request.location, endpoint_after)
		if code == &"":
			code = current_refusal()
		if code == &"":
			code = final_local_refusal()
		if code == &"":
			code = FinalFacts.snapshot_refusal(actual.owner, actual.routes, actual.locations,
				request.geometry_revision, proof.remaining)
		if code != &"":
			return code
		if not FinalFacts.record_matches(actual.locations, request.location, endpoint, actual.owner):
			return REFUSE_STALE
		return current_refusal()

	func final_local_refusal() -> StringName:
		"""Recheck the exact target and every nondegenerate role against fresh actual exclusions after callbacks."""
		var code: StringName = actual.terrain.local_facts_refusal(target, Terrain.DIG, request.geometry_revision)
		if code != &"":
			return code
		for ordinal: int in descriptor.box_count:
			if not proof.spend():
				return proof.error
			code = actual.profiles.box_into(request.profile_id, request.profile_revision,
				request.content_revision, ordinal, body)
			if code != &"":
				return code
			if body.role == Profiles.CONTACT_POINT or body.role == Profiles.CONTACT_PATCH:
				continue
			code = translate_into(body, bounds)
			if code == &"":
				code = actual.terrain.local_facts_refusal(bounds, Terrain.EXCLUSIONS, request.geometry_revision)
			if code != &"":
				return code
		return current_refusal()


var _reading: bool = false
var _reentered: bool = false


func solid_face_refusal(config: Routes.Configuration, request: Request, cold_token: int) -> StringName:
	"""Observe exact loaded geometry at a completed endpoint; actual claim/phase/worker admission is separate."""
	if _reading:
		_reentered = true
		return REFUSE_BUSY
	_reading = true
	_reentered = false
	var code: StringName = Check.input_refusal(config, request, cold_token)
	if code == &"":
		var check: Check = Check.new()
		check.hold(config, request, cold_token)
		code = check.run()
	_reading = false
	return REFUSE_BUSY if _reentered else code
