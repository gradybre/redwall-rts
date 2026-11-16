extends RefCounted
## Decision 2044 (P-2044-9 (a), P-2044-13 (a)): the module-aware successor of
## `qualified-claw-runtime-v2/paw_physical_certificate.gd`, which the handling dispatch names for content 12. Every
## call about an assembly of module 0 (L0, T0..T6: assemblies 0-7) is handed to the published certificate unchanged, so
## today's entry behaves byte for byte as before. A later module's assembly is judged by the published rules moved by
## its module translation (`tread_geometry.gd` here):
## - a module's T0 (installed from its natural landing): T0's station, part and transform translated, its prism by
##   the L0/T0 rules (`assembly_physical_certificate.gd`), its body by the published underground (tread) volume rule;
## - its T1..T6: the published tread rules at the module's derived station and staged bearer.
## Its proofs, volumes and owners are the published certificate's own; nothing here is retained between calls.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Published := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/paw_physical_certificate.gd")
const Parent := preload("res://data/underground/mole-worker/qualified-assembly-v1/physical_certificate.gd")
const Assembly := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/assembly_physical_certificate.gd")
const Source := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/paw_program.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")
const REFUSE: StringName = Published.REFUSE
const BUDGET: StringName = Published.BUDGET
const TAP: int = Published.TAP
const TREAD_TAP: int = Published.TREAD_TAP


static func is_tap(profile: int) -> bool:
	"""The published taps: 57 (L0/T0, and every module's T0) and the tread fitting tap 64."""
	return Published.is_tap(profile)


static func _published(assembly: int) -> bool:
	"""Module 0's assemblies (and anything unknown) take the published certificate unchanged."""
	return Tread.module_of(assembly) <= 0


static func _assembly(p: RefCounted, placement: Vector2i) -> int:
	"""The Placement's next assembly (the one being handled), or -1 for no row."""
	if p == null or p._placements == null or placement.x < 0 or placement.x >= p._placements._capacity: return -1
	return Published._assembly(p, placement)


static func refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted,
		placement: Vector2i, project: Vector2i, worker: Vector2i, job: Vector2i,
		selection: Profiles.Selection) -> StringName:
	"""The published funded proof; a later module's assembly at its translated station and bearer."""
	var assembly: int = _assembly(pieces, placement)
	if _published(assembly):
		return Published.refusal(bindings, graph, pieces, placement, project, worker, job, selection)
	var code: StringName = Published._binding(bindings, graph, pieces, placement, project, worker, job, selection)
	if code != &"": return code
	var owner: Owner = graph._owner
	code = Parent._source_rows(owner, graph)
	if code == &"": code = Parent._claims(owner, graph)
	if code == &"": code = Parent._endpoint(bindings, graph, selection)
	if code == &"": code = _piece(pieces, placement, project, selection)
	if code != &"": return code
	var target: int = pieces._live.fields[pieces.REGION_SLOT * pieces._capacity + placement.x]
	return _volumes(bindings, graph, pieces, assembly, selection, target, Parent._resident_room(graph, selection.worker))


static func admission_refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted,
		placement: Vector2i, project: Vector2i, location: Vector2i, selection: Profiles.Selection) -> StringName:
	"""The published unfunded proof; a later module's assembly at its translated station."""
	var assembly: int = _assembly(pieces, placement)
	if _published(assembly):
		return Published.admission_refusal(bindings, graph, pieces, placement, project, location, selection)
	if selection == null: return REFUSE
	var code: StringName = Published._binding(bindings, graph, pieces, placement, project,
		selection.worker, selection.job, selection, false)
	if code != &"": return code
	code = Parent._source_rows(graph._owner, graph)
	if code == &"": code = Parent._claims(graph._owner, graph)
	if code == &"": code = Parent._location_at(bindings, graph, location, selection)
	if code == &"": code = _source_station(pieces, placement, selection)
	if code != &"": return code
	return _volumes(bindings, graph, pieces, assembly, selection, -1, Parent._location_room(graph, location))


static func _volumes(b: RefCounted, g: RefCounted, p: RefCounted, assembly: int, selection: Profiles.Selection,
		target: int, room: Vector2i) -> StringName:
	"""Body then stance by the published rules: a tread's station stands inside its Room's own paid cubes, so its body
	meets only void, the Room's own timber and its own reservation (`_tread_volume`). Decision 2044 (P-2044-16 (a)): a
	later module's T0 is installed from its landing, a station inside the Room's completed cubes too, so it takes the
	same underground rule rather than L0's surface one (whose body may not share the Room's cube reservation)."""
	var tread: bool = Tread.is_tread(assembly) or Tread.module_of(assembly) > 0
	for part: int in Source.PART_COUNT:
		var code: StringName = Published._box_into(selection, part, b._bounds)
		if code == &"":
			code = Published._tread_volume(b, g, p._contacts.get_ref(), target, part == 1, room) if tread \
				else Parent._volume(b, g, p._contacts.get_ref(), target, part == 1, room)
		if code != &"": return code
	return &""


static func _source_station(p: RefCounted, placement: Vector2i, selection: Profiles.Selection) -> StringName:
	"""Module 0: the published roots. A later module: its T0's translated L0 station and transform, or a tread's
	derived station on the tread above and its derived staged bearer."""
	var owner: RefCounted = p._placements
	if placement.x < 0 or placement.x >= owner._capacity: return REFUSE
	var assembly: int = owner._live.i32[owner.INSTALLED * owner._capacity + placement.x]
	if _published(assembly): return Published._source_station(p, placement, selection)
	if owner._live.present[placement.x] != 1 \
			or owner._live.i32[owner.GENERATION * owner._capacity + placement.x] != placement.y \
			or owner._live.i32[owner.ROTATION * owner._capacity + placement.x] != 0: return REFUSE
	var origin: Vector3i = Vector3i(owner._live.i32[owner.X * owner._capacity + placement.x],
		owner._live.i32[(owner.X + 1) * owner._capacity + placement.x],
		owner._live.i32[(owner.X + 2) * owner._capacity + placement.x])
	var station: Vector3i = Tread.station_of(assembly) if Tread.is_tread(assembly) else Tread.t0_station_of(assembly)
	if Vector3i(selection.x, selection.y, selection.z) != origin + station: return REFUSE
	return part_refusal(assembly, p._parts[p.PART * p._assembly_capacity + assembly],
		p._parts[p.ROTATION * p._assembly_capacity + assembly], Vector3i(p._parts[p.X * p._assembly_capacity + assembly],
		p._parts[(p.X + 1) * p._assembly_capacity + assembly], p._parts[(p.X + 2) * p._assembly_capacity + assembly]))


static func part_refusal(assembly: int, part: int, turn: int, translation: Vector3i) -> StringName:
	"""Module 0's published transforms; a later module's derived staged bearer (its T0's and treads' alike)."""
	if _published(assembly): return Published.part_refusal(assembly, part, turn, translation)
	if Tread.is_t0(assembly): return Assembly.part_refusal(assembly, part, turn, translation)
	return &"" if part == Tread.bearer_part(assembly) and turn == Tread.T0_TURN \
		and translation == Tread.bearer_translation(assembly) else &"ASSEMBLY_SOURCE_PART"


static func bearer_refusal(assembly: int, point: Vector3i, bounds: PackedInt32Array) -> StringName:
	"""Module 0's published prisms; a later module's T0 as T0's, its treads' derived staged prisms."""
	if _published(assembly): return Published.bearer_refusal(assembly, point, bounds)
	if Tread.is_t0(assembly): return Assembly.bearer_refusal(assembly, point, bounds)
	return Published.bearer_refusal(Tread.base_assembly(assembly), point, bounds)


static func _piece(p: RefCounted, placement: Vector2i, project: Vector2i, selection: Profiles.Selection) -> StringName:
	"""Only the entire original paid bearer at the exact derived root receives the paw certificate."""
	var owner: Owner = p._placements._space
	var assembly: int = _assembly(p, placement)
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


static func _box_into(selection: Profiles.Selection, part: int, out: PackedInt32Array) -> StringName:
	"""The published oriented volumes (module-independent)."""
	return Published._box_into(selection, part, out)


static func occupant_refusal(b: RefCounted, mine: Profiles.Selection, other: Profiles.Selection) -> StringName:
	"""The published foreign-body proof (module-independent)."""
	return Published.occupant_refusal(b, mine, other)


static func install_ready_selection_refusal(g: RefCounted, selection: Profiles.Selection) -> StringName:
	"""The published taps' READY identity (module-independent)."""
	return Published.install_ready_selection_refusal(g, selection)


static func tap_certified(profiles: Profiles, profile: int, revision: int, assembly: int, root: Vector3i,
		bearer: PackedInt32Array) -> bool:
	"""Module 0: the published certificate. A later module: tap 57 at its T0's root (the T0 bearer prism), the tread
	tap 64 at a tread station, exactly as the published proofs certified them for module 0."""
	if _published(assembly): return Published.tap_certified(profiles, profile, revision, assembly, root, bearer)
	var base: int = Tread.base_assembly(assembly)
	return Published.tap_certified(profiles, profile, revision, base, root, bearer)
