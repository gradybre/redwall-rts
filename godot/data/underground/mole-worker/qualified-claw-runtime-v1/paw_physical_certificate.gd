extends RefCounted
## ADR 1217 step 5: concrete final geometry of the paw handling station, shared by Routes and WorldRoutes without a
## reverse preload. The tool-free successor of `qualified-assembly-v1/physical_certificate.gd`: the handling row is
## 59 (source 5), the seating tap whose canonical READY equals the handled READY is row 52 (source 4), and the
## station holds two volumes (all body words, the stance) instead of the pick's three (body, foot, held pick). Every
## owner, World, terrain, source-row, claim, endpoint, air and footing proof is the pick certificate's own.
## No retained packet, source observer or paid-state mutation lives here.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Parent := preload("res://data/underground/mole-worker/qualified-assembly-v1/physical_certificate.gd")
const Source := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/paw_program.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/claw_program.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE: StringName = Parent.REFUSE
const BUDGET: StringName = Parent.BUDGET
const TAP: int = 52


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
	var room: Vector2i = Parent._resident_room(graph, selection.worker)
	for part: int in Source.PART_COUNT:
		code = _box_into(selection, part, bindings._bounds)
		if code == &"": code = Parent._volume(bindings, graph, pieces._contacts.get_ref(), target, part == 1, room)
		if code != &"": return code
	return &""


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
	for part: int in Source.PART_COUNT:
		code = _box_into(selection, part, bindings._bounds)
		if code == &"": code = Parent._volume(bindings, graph, pieces._contacts.get_ref(), -1, part == 1,
			Parent._location_room(graph, location))
		if code != &"": return code
	return &""


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
	if selection.profile_id == TAP:
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
	"""Only the source-4 seating tap 52's canonical READY is identical to the proved handled READY (both are the claw
	stand key 8); no other phase borrows it."""
	if g == null or selection == null or g._ids == null or g._profiles == null \
			or selection.profile_id != TAP or selection.profile_revision != 1 or selection.source_id != Claw.SOURCE \
			or selection.yaw != 0 or selection.mode != Profiles.MODE_WORK or not Source.uses(g._profiles) \
			or Claw.profile_refusal(g._profiles, TAP, 1, selection.content_revision) != &"": return REFUSE
	var row: int = Owner.CoreSources._final_row(g._ids, selection.worker, Directory.KIND_RESIDENT)
	if row < 0 or row >= g.RESIDENT_CAPACITY \
			or g._motion.resident[g.R_SLOT * g.RESIDENT_CAPACITY + row] != selection.worker.x \
			or g._motion.resident[g.R_GENERATION * g.RESIDENT_CAPACITY + row] != selection.worker.y \
			or g._motion.resident[g.R_JOB_SLOT * g.RESIDENT_CAPACITY + row] != selection.job.x \
			or g._motion.resident[(g.R_JOB_SLOT + 1) * g.RESIDENT_CAPACITY + row] != selection.job.y \
			or g._motion.resident[g.R_PROFILE * g.RESIDENT_CAPACITY + row] != TAP \
			or g._motion.resident_long[g.R_PROFILE_REVISION * g.RESIDENT_CAPACITY + row] != 1 \
			or g._motion.resident_long[g.R_CONTENT_REVISION * g.RESIDENT_CAPACITY + row] != selection.content_revision \
			or g._motion.resident[g.R_PHASE * g.RESIDENT_CAPACITY + row] != Claw.word(0, Claw.READY) \
			or g._motion.resident_long[g.R_REQUEST_TICK * g.RESIDENT_CAPACITY + row] != 0 \
			or g._motion.resident[g.R_EDGE_SLOT * g.RESIDENT_CAPACITY + row] != -1 \
			or g._motion.resident[(g.R_EDGE_SLOT + 1) * g.RESIDENT_CAPACITY + row] != 0 \
			or g._motion.resident[g.R_HEAD * g.RESIDENT_CAPACITY + row] != -1 \
			or g._motion.resident[g.R_TAIL * g.RESIDENT_CAPACITY + row] != -1:
		return REFUSE
	return &""


static func _source_station(p: RefCounted, placement: Vector2i, selection: Profiles.Selection) -> StringName:
	"""The handling root and part transform are the pick certificate's (same bearers, same stations)."""
	return Parent._source_station(p, placement, selection)


static func _piece(p: RefCounted, placement: Vector2i, project: Vector2i,
		selection: Profiles.Selection) -> StringName:
	"""Only the entire original paid bearer at the exact source root can receive the paw certificate."""
	return Parent._piece(p, placement, project, selection)


static func _box_into(selection: Profiles.Selection, part: int, out: PackedInt32Array) -> StringName:
	"""Source volumes are already oriented (heading 0); integer translation cannot clip or rotate them."""
	for axis: int in 6:
		var value: int = Source.volume_word(part, axis) + (selection.x if axis % 3 == 0 else selection.y if axis % 3 == 1 else selection.z)
		if not Space.int32(value): return REFUSE
		out[axis] = value
	return &""


static func occupant_refusal(b: RefCounted, mine: Profiles.Selection, other: Profiles.Selection) -> StringName:
	"""The caller has concretely selected both actual bodies; every complete foreign body/recovery box blocks."""
	var profiles: Profiles = b._profiles
	if other.box_count < 1 or other.box_count > Profiles.MAX_SELECTION_BOXES or other.profile_id < 0 \
			or other.profile_id >= profiles._live.header[1]: return REFUSE
	for part: int in Source.PART_COUNT:
		var code: StringName = _box_into(mine, part, b._bounds)
		if code != &"": return code
		code = _foreign_boxes_refusal(b, profiles, other)
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
