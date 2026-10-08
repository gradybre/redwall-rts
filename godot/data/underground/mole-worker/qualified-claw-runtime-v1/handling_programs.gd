extends RefCounted
## ADR 1217 step 5: one selector over the two published handling programs, so Routes, WorldRoutes, Contacts,
## Workpieces and ConnectorWork pick the program by the handling row instead of a fixed row number. The pick program
## (row 29, source 1, with its INSTALL row 16) stays published and dormant (DEC-052); the paw program (row 59, source 5,
## with the claw seating tap 52) is the active one. Both share the handling clock's phases and word encoding, the L0/T0
## part transforms and the bearer prisms; they differ in the row's words and boxes and the station's physical volumes.
## Stateless static dispatch only.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Pick := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const PickPhysical := preload("res://data/underground/mole-worker/qualified-assembly-v1/physical_certificate.gd")
const Paw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/paw_program.gd")
const PawPhysical := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/paw_physical_certificate.gd")
const ClawEndpoint := preload("res://data/underground/mole-worker/qualified-claw-certificate-v1/endpoint_certificate.gd")
const PICK_INSTALL: int = 16


static func is_handling(profile: int) -> bool:
	"""The published handling rows: pick 29 (dormant) and paw 59."""
	return profile == Pick.PROFILE or profile == Paw.PROFILE


static func is_install_tap(profile: int) -> bool:
	"""The yaw-0 INSTALL rows whose canonical READY is the handled READY: pick 16 and claw tap 52."""
	return profile == PICK_INSTALL or profile == PawPhysical.TAP


static func _paw(profile: int) -> bool:
	"""The paw program owns its handling row and the claw tap it hands over to."""
	return profile == Paw.PROFILE or profile == PawPhysical.TAP


static func profile_refusal(profiles: Profiles, profile: int, revision: int, content: int) -> StringName:
	"""The handling row's own complete certificate."""
	if profile == Paw.PROFILE: return Paw.profile_refusal(profiles, profile, revision, content)
	return Pick.profile_refusal(profiles, profile, revision, content)


static func clock_refusal(source_word: int, source_clock: int, profile: int) -> StringName:
	"""The handling clock of the row's program."""
	if profile == Paw.PROFILE: return Paw.clock_refusal(source_word, source_clock, profile)
	return Pick.clock_refusal(source_word, source_clock, profile)


static func source_of(profile: int) -> int:
	"""The handling row's profile source."""
	return Paw.SOURCE if profile == Paw.PROFILE else Pick.SOURCE


static func role_count(profile: int) -> int:
	"""The handling row's published box count."""
	return Paw.ROLE_COUNT if profile == Paw.PROFILE else Pick.ROLE_COUNT


static func part_count(profile: int) -> int:
	"""Physical volumes of the station: paw body and stance; pick body, foot and held pick."""
	return Paw.PART_COUNT if _paw(profile) else 3


static func profile_of(pieces: RefCounted, assembly: int) -> int:
	"""The set-down (handling) row the bound Workpieces names for one assembly, or -1."""
	if pieces == null or assembly < 0 or assembly >= pieces._assembly_capacity: return -1
	return pieces._parts[pieces.PROFILE * pieces._assembly_capacity + assembly]


static func physical_refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted, placement: Vector2i,
		project: Vector2i, worker: Vector2i, job: Vector2i, selection: Profiles.Selection) -> StringName:
	"""The funded physical proof of the selection's program."""
	if selection != null and _paw(selection.profile_id):
		return PawPhysical.refusal(bindings, graph, pieces, placement, project, worker, job, selection)
	return PickPhysical.refusal(bindings, graph, pieces, placement, project, worker, job, selection)


static func physical_admission_refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted,
		placement: Vector2i, project: Vector2i, location: Vector2i, selection: Profiles.Selection) -> StringName:
	"""The unfunded READY admission proof of the selection's program."""
	if selection != null and _paw(selection.profile_id):
		return PawPhysical.admission_refusal(bindings, graph, pieces, placement, project, location, selection)
	return PickPhysical.admission_refusal(bindings, graph, pieces, placement, project, location, selection)


static func occupant_refusal(bindings: RefCounted, mine: Profiles.Selection, other: Profiles.Selection) -> StringName:
	"""Every foreign body/recovery box against the handling actor's own volumes."""
	if _paw(mine.profile_id): return PawPhysical.occupant_refusal(bindings, mine, other)
	return PickPhysical.occupant_refusal(bindings, mine, other)


static func source_station(pieces: RefCounted, placement: Vector2i, selection: Profiles.Selection) -> StringName:
	"""The canonical handling root and part transform (identical for both programs)."""
	return PickPhysical._source_station(pieces, placement, selection)


static func bearer_refusal(assembly: int, point: Vector3i, bounds: PackedInt32Array) -> StringName:
	"""The full relative bearer prism at the stationary root (identical for both programs)."""
	return Pick.bearer_refusal(assembly, point, bounds)


static func part_refusal(assembly: int, part: int, turn: int, translation: Vector3i) -> StringName:
	"""The included L0/T0 bearer transforms (identical for both programs)."""
	return Pick.part_refusal(assembly, part, turn, translation)


static func box_into(selection: Profiles.Selection, part: int, out: PackedInt32Array) -> StringName:
	"""One translated physical volume of the selection's program."""
	if _paw(selection.profile_id): return PawPhysical._box_into(selection, part, out)
	return PickPhysical._box_into(selection, part, out)


static func tap_certified(profiles: Profiles, profile: int, revision: int, content: int, assembly: int,
		root: Vector3i, bearer: PackedInt32Array) -> bool:
	"""The claw seating tap 52 (content 9, every published word and box) at the exact canonical root of the L0 or T0
	bearer. Its entry, work and recovery were proved clear of both whole bearer prisms by triangles (ADR 1217 step 2,
	`paw-seat-v1/candidate-a/proof.json`: world proofs clear, paws pressing at most 2 u into the top)."""
	return profile == PawPhysical.TAP and revision == 1 and content == ClawEndpoint.CONTENT \
		and ClawEndpoint._source_row_refusal(profiles, profile, content) == &"" \
		and Pick.bearer_refusal(assembly, root, bearer) == &""


static func own_room_marker(owner: Owner, row: int, room: Vector2i) -> bool:
	"""The station Room's own reservation marker (shared rule)."""
	return PickPhysical.own_room_marker(owner, row, room)
