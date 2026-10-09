extends RefCounted
## Concrete final geometry, shared by Routes and WorldRoutes without a reverse preload.
## No retained packet, source observer or paid-state mutation lives here.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Source := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const Step := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const FRAGMENT_CAPACITY: int = 32
const REFUSE: StringName = &"ASSEMBLY_PHYSICAL_CERTIFICATE"
const BUDGET: StringName = &"ASSEMBLY_PHYSICAL_BUDGET"


static func refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted,
		placement: Vector2i, project: Vector2i, worker: Vector2i, job: Vector2i,
		selection: Profiles.Selection) -> StringName:
	"""The caller closes actual paid/selection facts; this closes complete current physical/source facts."""
	var code: StringName = _binding(bindings, graph, pieces, placement, project, worker, job, selection)
	if code != &"": return code
	var owner: Owner = graph._owner
	var contacts: RefCounted = pieces._contacts.get_ref()
	code = _source_rows(owner, graph)
	if code == &"": code = _claims(owner, graph)
	if code == &"": code = _endpoint(bindings, graph, selection)
	if code == &"": code = _piece(pieces, placement, project, selection)
	if code != &"": return code
	var target: int = pieces._live.fields[pieces.REGION_SLOT * pieces._capacity + placement.x]
	var room: Vector2i = _resident_room(graph, selection.worker)
	for part: int in 3:
		code = _box_into(selection, part, bindings._bounds)
		if code == &"": code = _volume(bindings, graph, contacts, target, part == 1, room)
		if code != &"": return code
	return &""


static func admission_refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted,
		placement: Vector2i, project: Vector2i, location: Vector2i, selection: Profiles.Selection) -> StringName:
	"""Before funding, the entire physical source must fit real air/footing; there is no obstacle exception."""
	if selection == null: return REFUSE
	var code: StringName = _binding(bindings, graph, pieces, placement, project,
		selection.worker, selection.job, selection, false)
	if code != &"": return code
	code = _source_rows(graph._owner, graph)
	if code == &"": code = _claims(graph._owner, graph)
	if code == &"": code = _location_at(bindings, graph, location, selection)
	if code == &"": code = _source_station(pieces, placement, selection)
	if code != &"": return code
	for part: int in 3:
		code = _box_into(selection, part, bindings._bounds)
		if code == &"": code = _volume(bindings, graph, pieces._contacts.get_ref(), -1, part == 1,
			_location_room(graph, location))
		if code != &"": return code
	return &""


static func _binding(b: RefCounted, g: RefCounted, p: RefCounted, placement: Vector2i,
		project: Vector2i, worker: Vector2i, job: Vector2i, selection: Profiles.Selection, funded: bool = true) -> StringName:
	"""Sequential concrete guards retain every original field without a cached success or observer."""
	var code: StringName = _owners_refusal(b, g, p, selection)
	if code == &"": code = _selection_refusal(b, g, p, placement, project, worker, job, selection, funded)
	if code == &"": code = _world_refusal(b, g, p)
	if code == &"": code = _terrain_scratch_refusal(b, g, p)
	if code != &"": return code
	return &"" if _spend(g, 512 + 2 * (g._owner._source_capacity + g._owner._region_capacity)) else BUDGET


static func _owners_refusal(b: RefCounted, g: RefCounted, p: RefCounted,
		selection: Profiles.Selection) -> StringName:
	"""Full reciprocal owner identities precede every packet and source read."""
	if b == null or g == null or p == null or selection == null or b._routes_ref == null \
			or b._routes_ref.get_ref() != g or g._bindings != b or b._owner_ref == null \
			or b._owner_ref.get_ref() != g._owner or b._locations_ref == null \
			or b._locations_ref.get_ref() != g._locations or p._placements == null \
			or p._placements._routes != g or p._placements._world_routes != b \
			or p._placements._space != g._owner or p._placements._locations != g._locations \
			or p._profiles != b._profiles or g._profiles != b._profiles or p._router == null or p._contacts == null \
			or p._contacts.get_ref() == null or p._contacts.get_ref()._placements != p._placements \
			or p._contacts.get_ref()._terrain != b._terrain or b._terrain == null:
		return REFUSE
	return &""


static func _selection_refusal(b: RefCounted, g: RefCounted, p: RefCounted, placement: Vector2i,
		project: Vector2i, worker: Vector2i, job: Vector2i, selection: Profiles.Selection, funded: bool) -> StringName:
	"""Exact current source and pending/handled full row identities remain independent of the observer."""
	if selection.worker != worker or selection.job != job or selection.yaw != 0 \
			or placement.x < 0 or placement.x >= p._capacity:
		return REFUSE
	if selection.profile_id == 16:
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


static func _world_refusal(b: RefCounted, g: RefCounted, p: RefCounted) -> StringName:
	"""The one World, Domain, source namespace and idle banks must still be the original owners."""
	var owner: Owner = g._owner
	var locations: Locations = g._locations
	if owner == null or locations == null or owner._ready_error != &"" or owner._domain == null or g._sources == null \
			or not owner._sources is Owner.CoreSources or owner._sources != g._sources \
			or g._sources._directory != g._ids or g._sources._locations != g \
			or g._sources._buildings != g._buildings or g._sources._construction != p._router._construction \
			or locations._owner != owner or locations._sources != owner._sources or locations._ids != g._ids \
			or locations._buildings != g._buildings or locations._transforms != g._transforms \
			or locations._world != g._world or g._world != owner._domain._world \
			or b._domain == null or b._domain._world != g._world or b._domain._bounds != owner._domain._bounds \
			or locations._domain == null or locations._domain._bounds != owner._domain._bounds \
			or g._domain == null or g._domain._bounds != owner._domain._bounds:
		return REFUSE
	if owner._stage_token != 0 or locations._token != 0 or g._token != 0 or b._route_token != 0 \
			or owner._room_callback or owner._validation_sources >= 0 or owner._validation_regions >= 0 \
			or locations._in_retention or g._searching or g._occupancy_reading or g._callback_reentered \
			or b._opening or b._compiling or b._publishing or owner._header[17] <= 0:
		return REFUSE
	return &""


static func _terrain_scratch_refusal(b: RefCounted, g: RefCounted, p: RefCounted) -> StringName:
	"""Reattested terrain and already-owned scratch are checked without allocating or resetting budget."""
	var terrain: Terrain = b._terrain
	if not terrain._ready or terrain._space == null or terrain._space.get_ref() != g._owner \
			or terrain._sources == null or terrain._sources.get_ref() != g._owner._sources \
			or terrain._world_ref != g._world or terrain._world != b._world \
			or terrain._domain_bounds != g._owner._domain._bounds or terrain._checked_geometry_revision != g._owner._header[17] \
			or not Terrain._final_owners_match(terrain, g._owner._sources): return REFUSE
	var scratch: RefCounted = p._contacts.get_ref()._fragments
	if scratch == null or scratch.first.size() != 6 * FRAGMENT_CAPACITY \
			or scratch.second.size() != 6 * FRAGMENT_CAPACITY or scratch.core.size() != 6 \
			or scratch.cut.size() != 6 or scratch.slab.size() != 6 or b._bounds.size() != 6 \
			or b._support.size() != 6 or b._scratch.size() != 6 or p._contacts.get_ref()._target.size() != 6:
		return REFUSE
	return &""


static func install_ready_selection_refusal(g: RefCounted, selection: Profiles.Selection) -> StringName:
	"""Only the source0 INSTALL16 canonical READY is identical to the proved handling READY; no other phase borrows it."""
	if g == null or selection == null or g._ids == null or g._profiles == null \
			or selection.profile_id != 16 or selection.profile_revision != 1 or selection.source_id != 0 \
			or selection.yaw != 0 or selection.mode != Profiles.MODE_WORK \
			or not Source.uses(g._profiles) \
			or Step.profile_refusal(g._profiles, 16, 1, selection.content_revision) != &"": return REFUSE
	var row: int = Owner.CoreSources._final_row(g._ids, selection.worker, Directory.KIND_RESIDENT)
	if row < 0 or row >= g.RESIDENT_CAPACITY \
			or g._motion.resident[g.R_SLOT * g.RESIDENT_CAPACITY + row] != selection.worker.x \
			or g._motion.resident[g.R_GENERATION * g.RESIDENT_CAPACITY + row] != selection.worker.y \
			or g._motion.resident[g.R_JOB_SLOT * g.RESIDENT_CAPACITY + row] != selection.job.x \
			or g._motion.resident[(g.R_JOB_SLOT + 1) * g.RESIDENT_CAPACITY + row] != selection.job.y \
			or g._motion.resident[g.R_PROFILE * g.RESIDENT_CAPACITY + row] != 16 \
			or g._motion.resident_long[g.R_PROFILE_REVISION * g.RESIDENT_CAPACITY + row] != 1 \
			or g._motion.resident_long[g.R_CONTENT_REVISION * g.RESIDENT_CAPACITY + row] != selection.content_revision \
			or g._motion.resident[g.R_PHASE * g.RESIDENT_CAPACITY + row] != Step.word(0, Step.Parent.READY) \
			or g._motion.resident_long[g.R_REQUEST_TICK * g.RESIDENT_CAPACITY + row] != 0 \
			or g._motion.resident[g.R_EDGE_SLOT * g.RESIDENT_CAPACITY + row] != -1 \
			or g._motion.resident[(g.R_EDGE_SLOT + 1) * g.RESIDENT_CAPACITY + row] != 0 \
			or g._motion.resident[g.R_HEAD * g.RESIDENT_CAPACITY + row] != -1 \
			or g._motion.resident[g.R_TAIL * g.RESIDENT_CAPACITY + row] != -1:
		return REFUSE
	return &""


static func _spend(graph: RefCounted, amount: int) -> bool:
	"""Consume the original caller's remaining operation budget without a virtual method or reset."""
	if amount < 0 or amount > graph._remaining or graph._operation_error != &"":
		graph._operation_error = BUDGET
		return false
	graph._remaining -= amount
	return true


static func _source_rows(owner: Owner, graph: RefCounted) -> StringName:
	"""Current actual source columns must still equal every retained image fact after the last observer."""
	for row: int in owner._source_capacity:
		if owner._o_present[row] == 0: continue
		if not _spend(graph, 256): return BUDGET
		var ref: Vector2i = Vector2i(owner._o_slot[row], owner._o_generation[row])
		if owner._o_present[row] != 1 \
				or Owner.CoreSources._final_row(graph._ids, ref, owner._o_kind[row]) < 0: return REFUSE
		if owner._o_kind[row] == Directory.KIND_RESIDENT:
			if not _resident_source(owner, graph, row, ref): return REFUSE
			continue
		var code: StringName = Owner.CoreSources.read_final_into(owner._sources, ref, owner._facts)
		if code != &"": return code
		if owner._facts.kind != owner._o_kind[row] \
				or owner._facts.parent != Vector2i(owner._o_parent_slot[row], owner._o_parent_generation[row]) \
				or owner._facts.a != owner._o_a[row] or owner._facts.b != owner._o_b[row] \
				or owner._facts.c != owner._o_c[row] or owner._facts.d != owner._o_d[row]: return REFUSE
	return &""


static func _resident_source(owner: Owner, g: RefCounted, source: int, worker: Vector2i) -> bool:
	"""Full Directory/PID and actual current pose/Room/mode close retained resident source rows."""
	var row: int = Owner.CoreSources._final_row(g._ids, worker, Directory.KIND_RESIDENT)
	if row < 0 or row >= g.RESIDENT_CAPACITY or g._residents._present[row] != 1 \
			or g._residents._needs._present[row] != 1 or g._residents._needs._health[row] <= 0 \
			or g._motion.resident[g.R_SLOT * g.RESIDENT_CAPACITY + row] != worker.x \
			or g._motion.resident[g.R_GENERATION * g.RESIDENT_CAPACITY + row] != worker.y:
		return false
	var pose: int = Transforms.POSITIONED_BASE[Directory.KIND_RESIDENT] + row
	return g._transforms._directory == g._ids and g._ids._persistent_id[worker.x] > 0 \
		and g._transforms._bound_persistent_id[pose] == g._ids._persistent_id[worker.x] \
		and owner._o_a[source] == g._transforms._x[pose] and owner._o_b[source] == g._transforms._y[pose] \
		and owner._o_c[source] == g._transforms._z[pose] \
		and owner._o_d[source] == g._motion.resident[g.R_MODE * g.RESIDENT_CAPACITY + row] \
		and owner._o_parent_slot[source] == g._motion.resident[g.R_ROOM_SLOT * g.RESIDENT_CAPACITY + row] \
		and owner._o_parent_generation[source] == g._motion.resident[(g.R_ROOM_SLOT + 1) * g.RESIDENT_CAPACITY + row]


static func _claims(owner: Owner, graph: RefCounted) -> StringName:
	"""No stale Room or Project claim becomes air when a physical source callback changes identity."""
	for row: int in owner._region_capacity:
		if owner._r_present[row] == 0: continue
		if owner._r_present[row] != 1: return REFUSE
		var kind: int = owner._r_claim_kind[row]
		if kind == Owner.CLAIM_NONE: continue
		if kind != Owner.CLAIM_ROOM and kind != Owner.CLAIM_CONSTRUCTION: return REFUSE
		if not _spend(graph, 128): return BUDGET
		var ref: Vector2i = Vector2i(owner._r_claim_slot[row], owner._r_claim_generation[row])
		if Owner.CoreSources._final_row(graph._ids, ref,
				Directory.KIND_ROOM if kind == Owner.CLAIM_ROOM else Directory.KIND_CONSTRUCTION) < 0: return REFUSE
		var code: StringName = Owner.CoreSources.read_final_into(owner._sources, ref, owner._facts)
		if code != &"": return code
		if kind == Owner.CLAIM_ROOM \
				and ref != Vector2i(owner._r_owner_slot[row], owner._r_owner_generation[row]): return REFUSE
	return &""


static func _endpoint(b: RefCounted, g: RefCounted, selection: Profiles.Selection) -> StringName:
	"""Read the original full live endpoint directly; its real footing is never inferred from body air."""
	var row: int = Owner.CoreSources._final_row(g._ids, selection.worker, Directory.KIND_RESIDENT)
	if row < 0 or row >= g.RESIDENT_CAPACITY: return REFUSE
	var locations: Locations = g._locations
	var at: int = g._motion.resident[g.R_LOCATION_SLOT * g.RESIDENT_CAPACITY + row]
	var generation: int = g._motion.resident[(g.R_LOCATION_SLOT + 1) * g.RESIDENT_CAPACITY + row]
	var code: StringName = _location_at(b, g, Vector2i(at, generation), selection)
	if code != &"": return code
	for field: int in 5:
		if g._motion.resident[(g.R_ROOM_SLOT + field) * g.RESIDENT_CAPACITY + row] \
				!= locations._live.i32[(Locations.ROOM_SLOT + field) * locations._capacity + at]: return REFUSE
	return &""


static func _location_at(b: RefCounted, g: RefCounted, location: Vector2i,
		selection: Profiles.Selection) -> StringName:
	"""Both first registration and a retained actor use the exact same full live endpoint payload."""
	var locations: Locations = g._locations
	var at: int = location.x
	if at < 0 or at >= locations._capacity or locations._live.present[at] != 1 \
			or locations._live.i32[Locations.GENERATION * locations._capacity + at] != location.y \
			or locations._live.i64[Locations.GEOMETRY_REVISION * locations._capacity + at] != g._owner._header[17] \
			or locations._live.i64[Locations.PAYLOAD_REVISION * locations._capacity + at] <= 0 \
			or locations._live.i32[Locations.ROLE * locations._capacity + at] != Locations.ROLE_WORK:
		return REFUSE
	if selection.x != locations._live.i32[Locations.X * locations._capacity + at] \
			or selection.y != locations._live.i32[Locations.Y * locations._capacity + at] \
			or selection.z != locations._live.i32[Locations.Z * locations._capacity + at]: return REFUSE
	var section: int = locations._live.i32[Locations.SECTION_SLOT * locations._capacity + at]
	if section < 0 or section >= g._owner._region_capacity or g._owner._r_present[section] != 1 \
			or g._owner._r_generation[section] != locations._live.i32[(Locations.SECTION_SLOT + 1) * locations._capacity + at] \
			or g._owner._r_role[section] != Space.FLOOR_DATUM: return REFUSE
	var room: Vector2i = Vector2i(locations._live.i32[Locations.ROOM_SLOT * locations._capacity + at],
		locations._live.i32[Locations.ROOM_GENERATION * locations._capacity + at])
	if room != NULL_REF and Owner.CoreSources._final_row(g._ids, room, Directory.KIND_ROOM) < 0: return REFUSE
	for axis: int in 6:
		b._support[axis] = locations._live.i32[(Locations.SUPPORT + axis) * locations._capacity + at]
	return &"" if Space.valid_box(b._support) else REFUSE


static func _source_station(p: RefCounted, placement: Vector2i, selection: Profiles.Selection) -> StringName:
	"""The canonical source never silently moves to another included part, root, orientation or Placement."""
	var owner: RefCounted = p._placements
	if owner._live.present[placement.x] != 1 \
			or owner._live.i32[owner.GENERATION * owner._capacity + placement.x] != placement.y \
			or owner._live.i32[owner.ROTATION * owner._capacity + placement.x] != 0: return REFUSE
	var assembly: int = owner._live.i32[owner.INSTALLED * owner._capacity + placement.x]
	if assembly < 0 or assembly > 1: return REFUSE
	if selection.x != owner._live.i32[owner.X * owner._capacity + placement.x] + (-832 if assembly == 0 else 0) \
			or selection.y != owner._live.i32[(owner.X + 1) * owner._capacity + placement.x] \
			or selection.z != owner._live.i32[(owner.X + 2) * owner._capacity + placement.x] + (512 if assembly == 0 else -1536):
		return REFUSE
	return Source.part_refusal(assembly, p._parts[p.PART * p._assembly_capacity + assembly],
		p._parts[p.ROTATION * p._assembly_capacity + assembly], Vector3i(p._parts[p.X * p._assembly_capacity + assembly],
		p._parts[(p.X + 1) * p._assembly_capacity + assembly], p._parts[(p.X + 2) * p._assembly_capacity + assembly]))


static func _piece(p: RefCounted, placement: Vector2i, project: Vector2i,
		selection: Profiles.Selection) -> StringName:
	"""Only the entire original paid bearer at the exact source root can receive the triangle certificate."""
	var owner: Owner = p._placements._space
	var assembly: int = p._placements._live.i32[p._placements.INSTALLED * p._placements._capacity + placement.x]
	var code: StringName = _source_station(p, placement, selection)
	if code != &"": return code
	var region: int = p._live.fields[p.REGION_SLOT * p._capacity + placement.x]
	if region < 0 or region >= owner._region_capacity or owner._r_present[region] != 1 \
			or owner._r_generation[region] != p._live.fields[(p.REGION_SLOT + 1) * p._capacity + placement.x] \
			or owner._r_owner_slot[region] != project.x or owner._r_owner_generation[region] != project.y \
			or owner._r_role[region] != Space.OBSTACLE or owner._r_claim_kind[region] != Owner.CLAIM_NONE:
		return REFUSE
	_region_into(owner, region, p._contacts.get_ref()._target)
	return Source.bearer_refusal(assembly, Vector3i(selection.x, selection.y, selection.z), p._contacts.get_ref()._target)


static func _box_into(selection: Profiles.Selection, part: int, out: PackedInt32Array) -> StringName:
	"""Source bounds are already oriented; integer translation cannot clip a body or rotate it again."""
	for axis: int in 6:
		var value: int = Source.box_word(part, axis) + (selection.x if axis % 3 == 0 else selection.y if axis % 3 == 1 else selection.z)
		if not Space.int32(value): return REFUSE
		out[axis] = value
	return &""


static func _volume(b: RefCounted, g: RefCounted, contacts: RefCounted, target: int, foot: bool,
		room: Vector2i) -> StringName:
	"""Foreign physical primitives always block; only the exact paid source prism uses its full-triangle proof."""
	var owner: Owner = g._owner
	if not Space.contains_box(owner._domain._bounds, b._bounds) or not _spend(g, Terrain.LOCAL_QUERY_CHECKS): return BUDGET
	var code: StringName = Terrain._final_local_tiles(b._terrain, b._bounds, Terrain.EXCLUSIONS)
	if code != &"": return code
	var fragments: RefCounted = contacts._fragments
	fragments.count = 1
	for axis: int in 6: fragments.first[axis] = b._bounds[axis]
	if target >= 0 and not foot and not _subtract(fragments, contacts._target, g): return BUDGET
	code = _regions_refusal(b, g, fragments, target, foot, room)
	if code != &"" or foot: return code
	for row: int in fragments.count:
		if not _spend(g, Terrain.LOCAL_QUERY_CHECKS): return BUDGET
		for axis: int in 6: b._scratch[axis] = fragments.first[row * 6 + axis]
		code = Terrain._final_local_tiles(b._terrain, b._scratch, Terrain.EXTERIOR)
		if code != &"": return code
	return &""


static func _regions_refusal(b: RefCounted, g: RefCounted, fragments: RefCounted, target: int, foot: bool,
		room: Vector2i) -> StringName:
	"""A foot must lie inside the station's proved SUPPORT; then every overlapping live Region is checked:
	bodies subtract air, and any foreign solid or claim blocks.

	ADR 1202 (Brendan, option 1): such a foot may share its SUPPORT only with the station Room's own
	nonphysical reservation marker, as WorldRoutes and Locations read it. Bodies never may."""
	if foot and not Space.contains_box(b._support, b._bounds): return &"ASSEMBLY_FOOTING"
	var owner: Owner = g._owner
	for row: int in owner._region_capacity:
		if not _spend(g, 1): return BUDGET
		if owner._r_present[row] == 0: continue
		_region_into(owner, row, b._scratch)
		if not Space.overlaps(b._bounds, b._scratch): continue
		var role: int = owner._r_role[row]
		if row == target:
			if foot: return &"ASSEMBLY_FOOTING"
			continue
		if foot and own_room_marker(owner, row, room): continue
		if role == Space.SUPPORTED_VOID:
			if not foot and not _subtract(fragments, b._scratch, g): return BUDGET
		elif role == Space.DRY_SOLID or role == Space.SUPPORT:
			if not foot: return &"ASSEMBLY_FOREIGN_SOLID"
		elif role != Space.FLOOR_DATUM and role != Space.PROTECTED_ACCESS:
			return &"ASSEMBLY_FOREIGN_SOLID"
	return &""


static func own_room_marker(owner: Owner, row: int, room: Vector2i) -> bool:
	"""Only the station Room's own typed reservation: Room-claimed, Room-owned OBSTACLE, claim = owner = room."""
	return room != NULL_REF and owner._r_present[row] == 1 and owner._r_role[row] == Space.OBSTACLE \
		and owner._r_claim_kind[row] == Owner.CLAIM_ROOM \
		and Vector2i(owner._r_claim_slot[row], owner._r_claim_generation[row]) == room \
		and Vector2i(owner._r_owner_slot[row], owner._r_owner_generation[row]) == room


static func _location_room(g: RefCounted, location: Vector2i) -> Vector2i:
	"""The Room of one already validated live station Location; NULL_REF for an unroomed surface station."""
	var locations: Locations = g._locations
	if location.x < 0 or location.x >= locations._capacity: return NULL_REF
	return Vector2i(locations._live.i32[Locations.ROOM_SLOT * locations._capacity + location.x],
		locations._live.i32[Locations.ROOM_GENERATION * locations._capacity + location.x])


static func _resident_room(g: RefCounted, worker: Vector2i) -> Vector2i:
	"""The Room of the worker's current station Location, the one `_endpoint` validated."""
	var row: int = Owner.CoreSources._final_row(g._ids, worker, Directory.KIND_RESIDENT)
	if row < 0 or row >= g.RESIDENT_CAPACITY: return NULL_REF
	return _location_room(g, Vector2i(g._motion.resident[g.R_LOCATION_SLOT * g.RESIDENT_CAPACITY + row],
		g._motion.resident[(g.R_LOCATION_SLOT + 1) * g.RESIDENT_CAPACITY + row]))


static func _region_into(owner: Owner, row: int, out: PackedInt32Array) -> void:
	"""Copy only fixed original live columns, never a virtual Region observer."""
	out[0] = owner._r_lo_x[row]; out[1] = owner._r_lo_y[row]; out[2] = owner._r_lo_z[row]
	out[3] = owner._r_hi_x[row]; out[4] = owner._r_hi_y[row]; out[5] = owner._r_hi_z[row]


static func _subtract(f: RefCounted, cover: PackedInt32Array, graph: RefCounted) -> bool:
	"""The existing two fixed fragment banks provide exact union subtraction without allocation or dispatch."""
	f.next_count = 0
	for row: int in f.count:
		if not _spend(graph, 64): return false
		for axis: int in 6: f.core[axis] = f.first[row * 6 + axis]
		if not Space.overlaps(f.core, cover):
			if not _append(f, f.core): return false
			continue
		for axis: int in 3:
			f.cut[axis] = maxi(f.core[axis], cover[axis])
			f.cut[axis + 3] = mini(f.core[axis + 3], cover[axis + 3])
		for axis: int in 3:
			if not _outside(f, axis, false) or not _outside(f, axis, true): return false
	var previous: PackedInt32Array = f.first
	f.first = f.second; f.second = previous; f.count = f.next_count
	return true


static func _outside(f: RefCounted, axis: int, after: bool) -> bool:
	"""Emit each positive disjoint slab exactly once; fixed-capacity exhaustion refuses."""
	var edge: int = axis + 3 if after else axis
	if (f.core[edge] <= f.cut[edge] if after else f.core[edge] >= f.cut[edge]): return true
	for field: int in 6: f.slab[field] = f.core[field]
	f.slab[axis if after else axis + 3] = f.cut[edge]
	if not _append(f, f.slab): return false
	f.core[edge] = f.cut[edge]
	return true


static func _append(f: RefCounted, bounds: PackedInt32Array) -> bool:
	"""No fragment, box or child array is created while a canonical tick is being decided."""
	if f.next_count >= FRAGMENT_CAPACITY: return false
	for axis: int in 6: f.second[f.next_count * 6 + axis] = bounds[axis]
	f.next_count += 1
	return true


static func occupant_refusal(b: RefCounted, mine: Profiles.Selection, other: Profiles.Selection) -> StringName:
	"""The caller has concretely selected both actual bodies; every complete foreign body/recovery box blocks."""
	var profiles: Profiles = b._profiles
	if other.box_count < 1 or other.box_count > Profiles.MAX_SELECTION_BOXES or other.profile_id < 0 \
			or other.profile_id >= profiles._live.header[1]: return REFUSE
	for part: int in 3:
		var code: StringName = _box_into(mine, part, b._bounds)
		if code != &"": return code
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
