extends RefCounted
## ADR 1217 step 5: one selector over the published handling programs, so Routes, WorldRoutes, Contacts, Workpieces
## and ConnectorWork pick the program by the handling row instead of a fixed row number. The pick program (row 29,
## source 1, with its INSTALL row 16) stays published and dormant (DEC-052). ADR 1229 increment 4: the selector also
## takes the content the row is read under, because content 10 moves the claw rows: content 9's paw program (row 59,
## with the claw seating tap 52) and content 10's (rows 65 and 66, with the seating tap 57 and the tread fitting tap
## 64) share the handling clock's phases and word encoding; they differ in the rows' words and boxes, the station's
## physical volumes and, for content 10's treads, the stations and bearers the derived tread geometry names.
## Stateless static dispatch only.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Pick := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const PickPhysical := preload("res://data/underground/mole-worker/qualified-assembly-v1/physical_certificate.gd")
const Paw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/paw_program.gd")
const PawPhysical := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/paw_physical_certificate.gd")
const ClawEndpoint := preload("res://data/underground/mole-worker/qualified-claw-certificate-v1/endpoint_certificate.gd")
const Paw10 := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/paw_program.gd")
const PawPhysical10 := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/paw_physical_certificate.gd")
const PICK_INSTALL: int = 16


static func is_handling(profile: int, content: int) -> bool:
	"""The published handling rows: pick 29 (dormant); paw 59 in content 9, paw 65 and 66 in content 10."""
	if profile == Pick.PROFILE: return true
	if content == Paw10.CONTENT: return Paw10.owns(profile)
	return profile == Paw.PROFILE


static func is_install_tap(profile: int, content: int) -> bool:
	"""The yaw-0 INSTALL rows whose canonical READY is the handled READY: pick 16; claw tap 52 in content 9; claw tap
	57 and the tread fitting tap 64 in content 10."""
	if profile == PICK_INSTALL: return true
	if content == Paw10.CONTENT: return PawPhysical10.is_tap(profile)
	return profile == PawPhysical.TAP


static func _paw10(profile: int, content: int) -> bool:
	"""Content 10's paw program owns its handling rows and the taps it hands over to."""
	return content == Paw10.CONTENT and (Paw10.owns(profile) or PawPhysical10.is_tap(profile))


static func _paw(profile: int, content: int) -> bool:
	"""Content 9's paw program owns its handling row and the claw tap it hands over to."""
	return content != Paw10.CONTENT and (profile == Paw.PROFILE or profile == PawPhysical.TAP)


static func profile_refusal(profiles: Profiles, profile: int, revision: int, content: int) -> StringName:
	"""The handling row's own complete certificate."""
	if content == Paw10.CONTENT and Paw10.owns(profile): return Paw10.profile_refusal(profiles, profile, revision, content)
	if profile == Paw.PROFILE and content != Paw10.CONTENT: return Paw.profile_refusal(profiles, profile, revision, content)
	return Pick.profile_refusal(profiles, profile, revision, content)


static func clock_refusal(source_word: int, source_clock: int, profile: int, content: int) -> StringName:
	"""The handling clock of the row's program."""
	if content == Paw10.CONTENT and Paw10.owns(profile): return Paw10.clock_refusal(source_word, source_clock, profile)
	if profile == Paw.PROFILE and content != Paw10.CONTENT: return Paw.clock_refusal(source_word, source_clock, profile)
	return Pick.clock_refusal(source_word, source_clock, profile)


static func source_of(profile: int, content: int) -> int:
	"""The handling row's profile source."""
	if content == Paw10.CONTENT and Paw10.owns(profile): return Paw10.SOURCE
	return Paw.SOURCE if profile == Paw.PROFILE and content != Paw10.CONTENT else Pick.SOURCE


static func role_count(profile: int, content: int) -> int:
	"""The handling row's published box count."""
	if content == Paw10.CONTENT and Paw10.owns(profile): return Paw10.ROLE_COUNT
	return Paw.ROLE_COUNT if profile == Paw.PROFILE and content != Paw10.CONTENT else Pick.ROLE_COUNT


static func part_count(profile: int, content: int) -> int:
	"""Physical volumes of the station: paw body and stance; pick body, foot and held pick."""
	if _paw10(profile, content): return Paw10.PART_COUNT
	return Paw.PART_COUNT if _paw(profile, content) else 3


static func profile_of(pieces: RefCounted, assembly: int) -> int:
	"""The set-down (handling) row the bound Workpieces names for one assembly, or -1."""
	if pieces == null or assembly < 0 or assembly >= pieces._assembly_capacity: return -1
	return pieces._parts[pieces.PROFILE * pieces._assembly_capacity + assembly]


static func physical_refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted, placement: Vector2i,
		project: Vector2i, worker: Vector2i, job: Vector2i, selection: Profiles.Selection) -> StringName:
	"""The funded physical proof of the selection's program."""
	if selection != null and _paw10(selection.profile_id, selection.content_revision):
		return PawPhysical10.refusal(bindings, graph, pieces, placement, project, worker, job, selection)
	if selection != null and _paw(selection.profile_id, selection.content_revision):
		return PawPhysical.refusal(bindings, graph, pieces, placement, project, worker, job, selection)
	return PickPhysical.refusal(bindings, graph, pieces, placement, project, worker, job, selection)


static func physical_admission_refusal(bindings: RefCounted, graph: RefCounted, pieces: RefCounted,
		placement: Vector2i, project: Vector2i, location: Vector2i, selection: Profiles.Selection) -> StringName:
	"""The unfunded READY admission proof of the selection's program."""
	if selection != null and _paw10(selection.profile_id, selection.content_revision):
		return PawPhysical10.admission_refusal(bindings, graph, pieces, placement, project, location, selection)
	if selection != null and _paw(selection.profile_id, selection.content_revision):
		return PawPhysical.admission_refusal(bindings, graph, pieces, placement, project, location, selection)
	return PickPhysical.admission_refusal(bindings, graph, pieces, placement, project, location, selection)


static func occupant_refusal(bindings: RefCounted, mine: Profiles.Selection, other: Profiles.Selection) -> StringName:
	"""Every foreign body/recovery box against the handling actor's own volumes."""
	if _paw10(mine.profile_id, mine.content_revision): return PawPhysical10.occupant_refusal(bindings, mine, other)
	if _paw(mine.profile_id, mine.content_revision): return PawPhysical.occupant_refusal(bindings, mine, other)
	return PickPhysical.occupant_refusal(bindings, mine, other)


static func source_station(pieces: RefCounted, placement: Vector2i, selection: Profiles.Selection) -> StringName:
	"""The canonical handling root and part transform: L0/T0's (both programs), or content 10's tread stations."""
	if selection != null and selection.content_revision == Paw10.CONTENT:
		return PawPhysical10._source_station(pieces, placement, selection)
	return PickPhysical._source_station(pieces, placement, selection)


static func bearer_refusal(assembly: int, point: Vector3i, bounds: PackedInt32Array, content: int) -> StringName:
	"""The full relative bearer prism at the stationary root: L0/T0's, or content 10's derived tread bearers."""
	if content == Paw10.CONTENT: return PawPhysical10.bearer_refusal(assembly, point, bounds)
	return Pick.bearer_refusal(assembly, point, bounds)


static func part_refusal(assembly: int, part: int, turn: int, translation: Vector3i, content: int) -> StringName:
	"""The included bearer transforms: L0/T0's, or content 10's derived tread bearers."""
	if content == Paw10.CONTENT: return PawPhysical10.part_refusal(assembly, part, turn, translation)
	return Pick.part_refusal(assembly, part, turn, translation)


static func box_into(selection: Profiles.Selection, part: int, out: PackedInt32Array) -> StringName:
	"""One translated physical volume of the selection's program."""
	if _paw10(selection.profile_id, selection.content_revision): return PawPhysical10._box_into(selection, part, out)
	if _paw(selection.profile_id, selection.content_revision): return PawPhysical._box_into(selection, part, out)
	return PickPhysical._box_into(selection, part, out)


static func tap_certified(profiles: Profiles, profile: int, revision: int, content: int, assembly: int,
		root: Vector3i, bearer: PackedInt32Array) -> bool:
	"""The claw seating tap 52 (content 9) at the exact canonical root of the L0 or T0 bearer: its entry, work and
	recovery were proved clear of both whole bearer prisms by triangles (ADR 1217 step 2, `paw-seat-v1/candidate-a`).
	Content 10: the same tap as row 57, and the tread fitting tap 64 at a tread station (DEC-058, tread-fit-v1)."""
	if content == Paw10.CONTENT: return PawPhysical10.tap_certified(profiles, profile, revision, assembly, root, bearer)
	return profile == PawPhysical.TAP and revision == 1 and content == ClawEndpoint.CONTENT \
		and ClawEndpoint._source_row_refusal(profiles, profile, content) == &"" \
		and Pick.bearer_refusal(assembly, root, bearer) == &""


static func own_room_marker(owner: Owner, row: int, room: Vector2i) -> bool:
	"""The station Room's own reservation marker (shared rule)."""
	return PickPhysical.own_room_marker(owner, row, room)
