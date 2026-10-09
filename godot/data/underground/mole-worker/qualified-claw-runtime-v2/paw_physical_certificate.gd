extends RefCounted
## ADR 1229 increment 4: concrete final geometry of content 10's paw handling stations, the successor of runtime-v1's
## paw physical certificate (content 9). Two kinds of station:
## - **L0 and T0** (assemblies 0 and 1): runtime-v1's own rules with content 10's rows: paw handling 65 and the yaw-0
##   seating tap 57, the pick certificate's roots, bearer prisms and part transforms, and real air/footing for every
##   volume (the pick certificate's `_volume`).
## - **The treads** (assemblies 2-7, T1-T6): the station is `TreadGeometry.station_of` on the tread above, the bearer
##   the derived staged prism, the handling row 66 and the fitting tap 64 (DEC-058). Their approved proofs stood on the
##   tread fixture (tread-fit-v1 candidate b: the support deck, the deck behind, bearers, posts and trench walls), so a
##   volume may meet the station Room's own installed SUPPORT (that fixture's timber) as well as void, the certified
##   pending bearer while funded, and terrain-proved exterior air; any other matter or claim refuses.
## Every owner, World, terrain, source-row, claim, endpoint and footing proof is the pick certificate's own. No retained
## packet, source observer or paid-state mutation lives here.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Parent := preload("res://data/underground/mole-worker/qualified-assembly-v1/physical_certificate.gd")
const Pick := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const Source := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/paw_program.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/tread_geometry.gd")
const Endpoint := preload("res://data/underground/mole-worker/qualified-claw-certificate-v2/endpoint_certificate.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE: StringName = Parent.REFUSE
const BUDGET: StringName = Parent.BUDGET
const TAP: int = Source.Pins.CLAW_TAP_ROWS[0]
const TREAD_TAP: int = Source.Pins.CLAW_TREAD_TAP_ROW


static func is_tap(profile: int) -> bool:
	"""The yaw-0 seating tap 57 (L0/T0) and the tread fitting tap 64."""
	return profile == TAP or profile == TREAD_TAP


static func refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted,
		placement: Vector2i, project: Vector2i, worker: Vector2i, job: Vector2i,
		selection: Profiles.Selection) -> StringName:
	"""The caller closes actual paid/selection facts; this closes complete current physical/source facts."""
	var code: StringName = _binding(bindings, graph, pieces, placement, project, worker, job, selection)
	if code != &"": return code
	var owner: Owner = graph._owner
	code = Parent._source_rows(owner, graph)
	if code == &"": code = Parent._claims(owner, graph)
	if code == &"": code = Parent._endpoint(bindings, graph, selection)
	if code == &"": code = _piece(pieces, placement, project, selection)
	if code != &"": return code
	var target: int = pieces._live.fields[pieces.REGION_SLOT * pieces._capacity + placement.x]
	return _volumes(bindings, graph, pieces, placement, selection, target, Parent._resident_room(graph, selection.worker))


static func admission_refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted,
		placement: Vector2i, project: Vector2i, location: Vector2i, selection: Profiles.Selection) -> StringName:
	"""Before funding, the entire physical source must fit real air/footing; there is no obstacle exception."""
	if selection == null: return REFUSE
	var code: StringName = _binding(bindings, graph, pieces, placement, project,
		selection.worker, selection.job, selection, false)
	if code != &"": return code
	code = Parent._source_rows(graph._owner, graph)
	if code == &"": code = Parent._claims(graph._owner, graph)
	if code == &"": code = Parent._location_at(bindings, graph, location, selection)
	if code == &"": code = _source_station(pieces, placement, selection)
	if code != &"": return code
	return _volumes(bindings, graph, pieces, placement, selection, -1, Parent._location_room(graph, location))


static func _volumes(b: RefCounted, g: RefCounted, p: RefCounted, placement: Vector2i,
		selection: Profiles.Selection, target: int, room: Vector2i) -> StringName:
	"""Body then stance: L0/T0 in real air and footing; a tread station also within its Room's own timber."""
	var tread: bool = Tread.is_tread(_assembly(p, placement))
	for part: int in Source.PART_COUNT:
		var code: StringName = _box_into(selection, part, b._bounds)
		if code == &"":
			code = _tread_volume(b, g, p._contacts.get_ref(), target, part == 1, room) if tread \
				else Parent._volume(b, g, p._contacts.get_ref(), target, part == 1, room)
		if code != &"": return code
	return &""


static func _assembly(p: RefCounted, placement: Vector2i) -> int:
	"""The Placement's next assembly (the one being handled)."""
	var owner: RefCounted = p._placements
	return owner._live.i32[owner.INSTALLED * owner._capacity + placement.x]


static func _binding(b: RefCounted, g: RefCounted, p: RefCounted, placement: Vector2i,
		project: Vector2i, worker: Vector2i, job: Vector2i, selection: Profiles.Selection, funded: bool = true) -> StringName:
	"""Sequential concrete guards retain every original field without a cached success or observer."""
	var code: StringName = Parent._owners_refusal(b, g, p, selection)
	if code == &"": code = _selection_refusal(b, g, p, placement, project, worker, job, selection, funded)
	if code == &"": code = Parent._world_refusal(b, g, p)
	if code == &"": code = Parent._terrain_scratch_refusal(b, g, p)
	if code != &"": return code
	return &"" if Parent._spend(g, 512 + 2 * (g._owner._source_capacity + g._owner._region_capacity)) else BUDGET


static func _selection_refusal(b: RefCounted, g: RefCounted, p: RefCounted, placement: Vector2i,
		project: Vector2i, worker: Vector2i, job: Vector2i, selection: Profiles.Selection, funded: bool) -> StringName:
	"""Exact current source and pending/handled full row identities remain independent of the observer."""
	if selection.worker != worker or selection.job != job or selection.yaw != 0 \
			or placement.x < 0 or placement.x >= p._capacity:
		return REFUSE
	if is_tap(selection.profile_id):
		if not funded or p._live.present[placement.x] != 2 \
				or install_ready_selection_refusal(g, selection) != &"": return REFUSE
	elif Source.profile_refusal(b._profiles, selection.profile_id, selection.profile_revision,
			selection.content_revision) != &"": return REFUSE
	if funded and ((p._live.present[placement.x] != 1 and p._live.present[placement.x] != 2) \
			or p._live.fields[p.GENERATION * p._capacity + placement.x] != placement.y \
			or p._live.fields[p.PROJECT_SLOT * p._capacity + placement.x] != project.x \
			or p._live.fields[(p.PROJECT_SLOT + 1) * p._capacity + placement.x] != project.y):
		return REFUSE
	return &""


static func install_ready_selection_refusal(g: RefCounted, selection: Profiles.Selection) -> StringName:
	"""Only the source-4 taps' canonical READY is identical to the proved handled READY (both are the claw stand key 8);
	no other phase borrows it."""
	if g == null or selection == null or g._ids == null or g._profiles == null \
			or not is_tap(selection.profile_id) or selection.profile_revision != 1 or selection.source_id != Claw.SOURCE \
			or selection.yaw != 0 or selection.mode != Profiles.MODE_WORK or not Source.uses(g._profiles) \
			or Claw.profile_refusal(g._profiles, selection.profile_id, 1, selection.content_revision) != &"": return REFUSE
	var row: int = Owner.CoreSources._final_row(g._ids, selection.worker, Directory.KIND_RESIDENT)
	if row < 0 or row >= g.RESIDENT_CAPACITY \
			or g._motion.resident[g.R_SLOT * g.RESIDENT_CAPACITY + row] != selection.worker.x \
			or g._motion.resident[g.R_GENERATION * g.RESIDENT_CAPACITY + row] != selection.worker.y \
			or g._motion.resident[g.R_JOB_SLOT * g.RESIDENT_CAPACITY + row] != selection.job.x \
			or g._motion.resident[(g.R_JOB_SLOT + 1) * g.RESIDENT_CAPACITY + row] != selection.job.y \
			or g._motion.resident[g.R_PROFILE * g.RESIDENT_CAPACITY + row] != selection.profile_id \
			or g._motion.resident_long[g.R_PROFILE_REVISION * g.RESIDENT_CAPACITY + row] != 1 \
			or g._motion.resident_long[g.R_CONTENT_REVISION * g.RESIDENT_CAPACITY + row] != selection.content_revision \
			or g._motion.resident[g.R_PHASE * g.RESIDENT_CAPACITY + row] != Claw.word(0, Claw.READY):
		return REFUSE
	return _idle_route_refusal(g, row)


static func _idle_route_refusal(g: RefCounted, row: int) -> StringName:
	"""A READY tap holds no clock, no occupied edge and no queue."""
	if g._motion.resident_long[g.R_REQUEST_TICK * g.RESIDENT_CAPACITY + row] != 0 \
			or g._motion.resident[g.R_EDGE_SLOT * g.RESIDENT_CAPACITY + row] != -1 \
			or g._motion.resident[(g.R_EDGE_SLOT + 1) * g.RESIDENT_CAPACITY + row] != 0 \
			or g._motion.resident[g.R_HEAD * g.RESIDENT_CAPACITY + row] != -1 \
			or g._motion.resident[g.R_TAIL * g.RESIDENT_CAPACITY + row] != -1:
		return REFUSE
	return &""


static func _source_station(p: RefCounted, placement: Vector2i, selection: Profiles.Selection) -> StringName:
	"""L0/T0 keep the pick certificate's roots and transforms; a tread's root is its derived station on the tread above
	and its staged bearer the derived part, turn and translation."""
	var owner: RefCounted = p._placements
	if owner._live.present[placement.x] != 1 \
			or owner._live.i32[owner.GENERATION * owner._capacity + placement.x] != placement.y \
			or owner._live.i32[owner.ROTATION * owner._capacity + placement.x] != 0: return REFUSE
	var assembly: int = owner._live.i32[owner.INSTALLED * owner._capacity + placement.x]
	if not Tread.is_tread(assembly): return Parent._source_station(p, placement, selection)
	var origin: Vector3i = Vector3i(owner._live.i32[owner.X * owner._capacity + placement.x],
		owner._live.i32[(owner.X + 1) * owner._capacity + placement.x],
		owner._live.i32[(owner.X + 2) * owner._capacity + placement.x])
	if Vector3i(selection.x, selection.y, selection.z) != origin + Tread.station_of(assembly): return REFUSE
	return part_refusal(assembly, p._parts[p.PART * p._assembly_capacity + assembly],
		p._parts[p.ROTATION * p._assembly_capacity + assembly], Vector3i(p._parts[p.X * p._assembly_capacity + assembly],
		p._parts[(p.X + 1) * p._assembly_capacity + assembly], p._parts[(p.X + 2) * p._assembly_capacity + assembly]))


static func part_refusal(assembly: int, part: int, turn: int, translation: Vector3i) -> StringName:
	"""L0/T0's included bearer transforms, or a tread's derived staged bearer."""
	if not Tread.is_tread(assembly): return Pick.part_refusal(assembly, part, turn, translation)
	return &"" if part == Tread.bearer_part(assembly) and turn == Tread.T0_TURN \
		and translation == Tread.bearer_translation(assembly) else &"ASSEMBLY_SOURCE_PART"


static func bearer_refusal(assembly: int, point: Vector3i, bounds: PackedInt32Array) -> StringName:
	"""L0/T0's full relative prisms, or a tread's derived staged prism around its station root."""
	if not Tread.is_tread(assembly): return Pick.bearer_refusal(assembly, point, bounds)
	var expected: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	if bounds.size() != 6 or not Tread.bearer_prism_into(assembly, point, expected): return &"ASSEMBLY_SOURCE_BEARER"
	return &"" if bounds == expected else &"ASSEMBLY_SOURCE_BEARER"


static func _piece(p: RefCounted, placement: Vector2i, project: Vector2i,
		selection: Profiles.Selection) -> StringName:
	"""Only the entire original paid bearer at the exact source root can receive the paw certificate."""
	var owner: Owner = p._placements._space
	var assembly: int = _assembly(p, placement)
	if not Tread.is_tread(assembly): return Parent._piece(p, placement, project, selection)
	var code: StringName = _source_station(p, placement, selection)
	if code != &"": return code
	var region: int = p._live.fields[p.REGION_SLOT * p._capacity + placement.x]
	if region < 0 or region >= owner._region_capacity or owner._r_present[region] != 1 \
			or owner._r_generation[region] != p._live.fields[(p.REGION_SLOT + 1) * p._capacity + placement.x] \
			or owner._r_owner_slot[region] != project.x or owner._r_owner_generation[region] != project.y \
			or owner._r_role[region] != Space.OBSTACLE or owner._r_claim_kind[region] != Owner.CLAIM_NONE:
		return REFUSE
	Parent._region_into(owner, region, p._contacts.get_ref()._target)
	return bearer_refusal(assembly, Vector3i(selection.x, selection.y, selection.z), p._contacts.get_ref()._target)


static func _tread_volume(b: RefCounted, g: RefCounted, contacts: RefCounted, target: int, foot: bool,
		room: Vector2i) -> StringName:
	"""A tread station's body meets only void, its Room's installed timber, the certified pending bearer and exterior
	air; its stance lies inside the station's proved footing."""
	var owner: Owner = g._owner
	if not Space.contains_box(owner._domain._bounds, b._bounds) or not Parent._spend(g, Terrain.LOCAL_QUERY_CHECKS): return BUDGET
	var code: StringName = Terrain._final_local_tiles(b._terrain, b._bounds, Terrain.EXCLUSIONS)
	if code != &"": return code
	if foot: return &"" if Space.contains_box(b._support, b._bounds) else &"ASSEMBLY_FOOTING"
	var fragments: RefCounted = contacts._fragments
	fragments.count = 1
	for axis: int in 6: fragments.first[axis] = b._bounds[axis]
	if target >= 0 and not Parent._subtract(fragments, contacts._target, g): return BUDGET
	code = _tread_regions(b, g, fragments, target, room)
	if code != &"": return code
	for row: int in fragments.count:
		if not Parent._spend(g, Terrain.LOCAL_QUERY_CHECKS): return BUDGET
		for axis: int in 6: b._scratch[axis] = fragments.first[row * 6 + axis]
		code = Terrain._final_local_tiles(b._terrain, b._scratch, Terrain.EXTERIOR)
		if code != &"": return code
	return &""


static func _tread_regions(b: RefCounted, g: RefCounted, fragments: RefCounted, target: int, room: Vector2i) -> StringName:
	"""Void and the Room's own SUPPORT cover the body; floor metadata and access are inert; anything else blocks.
	ADR1229: the trench's void cubes are subtracted first and the timber second, so the exact remainder stays within
	the fixed fragment banks however many treads stand nearby (the union is the same in either order)."""
	for pass_void: bool in [true, false]:
		var code: StringName = _tread_pass(b, g, fragments, target, room, pass_void)
		if code != &"": return code
	return &""


static func _tread_pass(b: RefCounted, g: RefCounted, fragments: RefCounted, target: int, room: Vector2i,
		pass_void: bool) -> StringName:
	"""One pass over the Regions: the void pass also refuses foreign matter; the timber pass subtracts only timber."""
	var owner: Owner = g._owner
	for row: int in owner._region_capacity:
		if not Parent._spend(g, 1): return BUDGET
		if owner._r_present[row] == 0 or row == target: continue
		Parent._region_into(owner, row, b._scratch)
		if not Space.overlaps(b._bounds, b._scratch) or Parent.own_room_marker(owner, row, room): continue
		var role: int = owner._r_role[row]
		var own: bool = role == Space.SUPPORT and owner._r_claim_kind[row] == Owner.CLAIM_NONE \
			and Vector2i(owner._r_owner_slot[row], owner._r_owner_generation[row]) == room
		if (role == Space.SUPPORTED_VOID and pass_void) or (own and not pass_void):
			if not Parent._subtract(fragments, b._scratch, g) or not _coalesce(fragments, g): return BUDGET
		elif pass_void and not own and role != Space.SUPPORTED_VOID and role != Space.FLOOR_DATUM \
				and role != Space.PROTECTED_ACCESS:
			return &"ASSEMBLY_FOREIGN_SOLID"
	return &""


static func _coalesce(f: RefCounted, g: RefCounted) -> bool:
	"""ADR1229: merge remainder fragments that share two axis intervals and touch on the third, until none do. The
	union is unchanged; the trench's thin void slabs otherwise leave more pieces than the fixed banks hold."""
	var merged: bool = true
	while merged:
		merged = false
		for i: int in f.count:
			for j: int in range(i + 1, f.count):
				if not Parent._spend(g, 1): return false
				if not _join(f.first, i, j): continue
				f.count -= 1
				for axis: int in 6: f.first[j * 6 + axis] = f.first[f.count * 6 + axis]
				merged = true
				break
			if merged: break
	return true


static func _join(boxes: PackedInt32Array, i: int, j: int) -> bool:
	"""Grow box i over box j when they equal on two axes and abut on the third."""
	var free: int = -1
	for axis: int in 3:
		if boxes[i * 6 + axis] == boxes[j * 6 + axis] and boxes[i * 6 + axis + 3] == boxes[j * 6 + axis + 3]: continue
		if free >= 0: return false
		free = axis
	if free < 0 or (boxes[i * 6 + free + 3] != boxes[j * 6 + free] and boxes[j * 6 + free + 3] != boxes[i * 6 + free]):
		return false
	boxes[i * 6 + free] = mini(boxes[i * 6 + free], boxes[j * 6 + free])
	boxes[i * 6 + free + 3] = maxi(boxes[i * 6 + free + 3], boxes[j * 6 + free + 3])
	return true


static func _box_into(selection: Profiles.Selection, part: int, out: PackedInt32Array) -> StringName:
	"""The row's volumes are already oriented (heading 0); a tap selection presents its handling row's volumes."""
	var profile: int = selection.profile_id
	if profile == TAP: profile = Source.Pins.PAW_HANDLING_ROW
	elif profile == TREAD_TAP: profile = Source.Pins.PAW_TREAD_HANDLING_ROW
	for axis: int in 6:
		var value: int = Source.volume_word(profile, part, axis) \
			+ (selection.x if axis % 3 == 0 else selection.y if axis % 3 == 1 else selection.z)
		if not Space.int32(value): return REFUSE
		out[axis] = value
	return &""


static func occupant_refusal(b: RefCounted, mine: Profiles.Selection, other: Profiles.Selection) -> StringName:
	"""Every complete foreign body/recovery box against the station's two volumes."""
	var profiles: Profiles = b._profiles
	if other.box_count < 1 or other.box_count > Profiles.MAX_SELECTION_BOXES or other.profile_id < 0 \
			or other.profile_id >= profiles._live.header[1]: return REFUSE
	for part: int in Source.PART_COUNT:
		var code: StringName = _box_into(mine, part, b._bounds)
		if code == &"": code = _foreign_boxes_refusal(b, profiles, other)
		if code != &"": return code
	return &""


static func _foreign_boxes_refusal(b: RefCounted, profiles: Profiles, other: Profiles.Selection) -> StringName:
	"""Every BODY/TURN box of the other actor, at its root, against the volume in b._bounds."""
	for ordinal: int in other.box_count:
		var at: int = profiles._live.fields[Profiles.F_FIRST_BOX * profiles._profile_capacity + other.profile_id] + ordinal
		if at < 0 or at >= profiles._live.header[2]: return REFUSE
		var role: int = profiles._live.boxes[6 * profiles._box_capacity + at]
		if role != Profiles.BODY_HELD_LOAD and role != Profiles.TURN_RECOVERY: continue
		for axis: int in 6:
			var value: int = int(profiles._live.boxes[axis * profiles._box_capacity + at]) \
				+ (other.x if axis % 3 == 0 else other.y if axis % 3 == 1 else other.z)
			if not Space.int32(value): return REFUSE
			b._scratch[axis] = value
		if Space.overlaps(b._bounds, b._scratch): return &"ASSEMBLY_OCCUPIED"
	return &""


static func tap_certified(profiles: Profiles, profile: int, revision: int, assembly: int, root: Vector3i,
		bearer: PackedInt32Array) -> bool:
	"""Tap 57 at the L0/T0 roots (paw-seat-v1 candidate a cleared both whole bearer prisms); the tread fitting tap 64 at
	a tread station (tread-fit-v1 candidate b: the bearer hard for every triangle, tread and sill)."""
	if revision != 1 or Claw.profile_refusal(profiles, profile, 1, Source.CONTENT) != &"": return false
	if profile == TAP:
		return not Tread.is_tread(assembly) and Endpoint._source_row_refusal(profiles, profile, Source.CONTENT) == &"" \
			and Pick.bearer_refusal(assembly, root, bearer) == &""
	return profile == TREAD_TAP and Tread.is_tread(assembly) and bearer_refusal(assembly, root, bearer) == &""
