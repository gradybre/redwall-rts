extends RefCounted
## Cold-path furniture planning, using completed geometry and the existing furniture catalog.
## No inventory, work, installed furniture or services are created here. The bound coordinator
## must atomically accept an entire Batch through the real construction command owner (1054).
## Snapshot links are the movement owner's already eligible undirected walk connections;
## sharing a room, X/Z, or a floor height never invents a connection between cells.

const Buildings := preload("res://scripts/core/buildings.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")

const SNAPSHOT_VERSION: int = 1
const ROOM_CAPACITY: int = Buildings.ROOM_CAPACITY
const PLACEMENT_CAPACITY: int = Buildings.FURNITURE_CAPACITY
const MAX_OPERATION_CELLS: int = 16384 # Matches the canonical footprint operation budget.
const LINKS_PER_OPERATION_CELL: int = 4 # Scratch budget, not a permitted movement degree.
const CONTACTS_PER_OPERATION_CELL: int = 4 # Shared contacts count too; no unbounded profile lists.
const CATALOG_TILE_UNITS: int = 2048 # GDD §5.9: footprints use two-metre tiles.
const I32_MAX: int = 2147483647
const NULL_REF: Vector2i = Vector2i(-1, 0)
const MODE_LAYOUT: int = 0
const MODE_INDIVIDUAL: int = 1
const DOMAIN_ROOM: int = 0
const DOMAIN_FURNITURE: int = 1
const DOMAIN_PROJECT: int = 2
const STATE_FREE: int = 0
const STATE_DRAFT: int = 1
const STATE_ACCEPTED: int = 2
const ENTRY_STRIDE: int = 4 # type, origin X, origin Z, rotation (0..3).


class Profile extends RefCounted:

	## Immutable authored clearance/contact facts, separate from GDD floor dimensions.
	## Offsets are integer cells at Snapshot.pitch_units, for rotation zero. Every supplied
	## installation/use contact must be reachable; an empty contact set is not an attestation.
	var height_units: int = 0
	var install_xy: PackedInt32Array = PackedInt32Array()
	var use_xy: PackedInt32Array = PackedInt32Array()


class Snapshot extends RefCounted:

	## The owner publishes a fresh, internally consistent image. revision changes with EVERY
	## geometry, occupancy, profile, compatibility, connection or completion change.
	var version: int = SNAPSHOT_VERSION
	var revision: int = -1
	var room_ref: Vector2i = NULL_REF
	var room_type: int = -1
	var level: int = 0
	var pitch_units: int = 0
	var shell_complete: bool = false
	var allowed_types_mask: int = -1
	var floor_xy: PackedInt32Array = PackedInt32Array()
	var floor_height: PackedInt32Array = PackedInt32Array()
	var ceiling_height: PackedInt32Array = PackedInt32Array()
	## Owned room-floor indices within the connected walk context above. Furniture cannot
	## occupy neighboring room/corridor cells, but real install/use contacts may reach them.
	var room_cells: PackedInt32Array = PackedInt32Array()
	## Floor indices, not XY coordinates. Entries already have a live external route.
	var entries: PackedInt32Array = PackedInt32Array()
	var protected_cells: PackedInt32Array = PackedInt32Array()
	## Structural/non-furniture obstructions only; object_entries stamp their own footprints.
	var blocked_cells: PackedInt32Array = PackedInt32Array()
	var walk_links: PackedInt32Array = PackedInt32Array()
	## Includes installed pieces AND accepted, unfinished projects. Each object occurs once.
	## refs is slot/generation pairs; kinds selects DOMAIN_FURNITURE or DOMAIN_PROJECT.
	var object_refs: PackedInt32Array = PackedInt32Array()
	var object_kinds: PackedInt32Array = PackedInt32Array()
	var object_entries: PackedInt32Array = PackedInt32Array()
	var profiles: Array[Profile] = []


class Batch extends RefCounted:

	## A copied transaction request. There is no callback that grants a service on this class.
	var room_ref: Vector2i = NULL_REF
	var room_type: int = -1
	var level: int = 0
	var pitch_units: int = 0
	var expected_revision: int = -1
	var entries: PackedInt32Array = PackedInt32Array()


class Submission extends RefCounted:

	## A coordinator's atomic result. Failure MUST leave all world owners unchanged.
	## Success supplies one live construction project per requested item, in request order;
	## the next snapshot must include those claims. This is acceptance, never installation.
	var ok: bool = false
	var error: StringName = &"CONSTRUCTION_COORDINATOR_UNBOUND"
	var project_refs: PackedInt32Array = PackedInt32Array()


class Result extends RefCounted:

	var ok: bool = false
	var error: StringName = &""
	var ref: Vector2i = NULL_REF
	var value: int = 0
	var occupied_xy: PackedInt32Array = PackedInt32Array()
	var install_xy: PackedInt32Array = PackedInt32Array()
	var use_xy: PackedInt32Array = PackedInt32Array()
	var affected_xy: PackedInt32Array = PackedInt32Array()


class Validation extends RefCounted:

	## One temporary, cold-path working image. No per-resident/per-tick allocations.
	var result: Result = Result.new()
	var cells: Dictionary = {}
	var occupied: PackedByteArray = PackedByteArray()
	var protected: PackedByteArray = PackedByteArray()
	var owned: PackedByteArray = PackedByteArray()
	var contacts: PackedInt32Array = PackedInt32Array()
	var adjacency: Dictionary = {}


var _room_capacity: int = 0
var _placement_capacity: int = 0
var _geometry_capacity: int = 0
var _room_slots: PackedInt32Array = PackedInt32Array()
var _room_generations: PackedInt32Array = PackedInt32Array()
var _room_types: PackedInt32Array = PackedInt32Array()
var _room_modes: PackedByteArray = PackedByteArray()
var _state: PackedByteArray = PackedByteArray()
var _generation: PackedInt32Array = PackedInt32Array()
var _room_row: PackedInt32Array = PackedInt32Array()
var _type: PackedInt32Array = PackedInt32Array()
var _x: PackedInt32Array = PackedInt32Array()
var _z: PackedInt32Array = PackedInt32Array()
var _rotation: PackedInt32Array = PackedInt32Array()
var _project_slot: PackedInt32Array = PackedInt32Array()
var _project_generation: PackedInt32Array = PackedInt32Array()
var _snapshot_reader: Callable = Callable()
var _ref_validator: Callable = Callable()
var _submitter: Callable = Callable()
var _definitions: BuildingDefinitions = BuildingDefinitions.new()
var _submitting: bool = false


func _init(room_capacity: int = ROOM_CAPACITY,
		placement_capacity: int = PLACEMENT_CAPACITY,
		geometry_capacity: int = MAX_OPERATION_CELLS) -> void:
	"""Allocate bounded packed UI/planning state; limits inherit existing owner capacities."""
	_room_capacity = clampi(room_capacity, 1, ROOM_CAPACITY)
	_placement_capacity = clampi(placement_capacity, 1, PLACEMENT_CAPACITY)
	_geometry_capacity = clampi(geometry_capacity, 1, MAX_OPERATION_CELLS)
	_room_slots.resize(_room_capacity)
	_room_slots.fill(-1)
	_room_generations.resize(_room_capacity)
	_room_types.resize(_room_capacity)
	_room_modes.resize(_room_capacity)
	_allocate_placements()


func _allocate_placements() -> void:
	"""Allocate all row columns once; identity generation is retained when a row is freed."""
	_state.resize(_placement_capacity)
	_generation.resize(_placement_capacity)
	_room_row.resize(_placement_capacity)
	_type.resize(_placement_capacity)
	_x.resize(_placement_capacity)
	_z.resize(_placement_capacity)
	_rotation.resize(_placement_capacity)
	_project_slot.resize(_placement_capacity)
	_project_generation.resize(_placement_capacity)
	_project_slot.fill(-1)


func bind_sources(snapshot_reader: Callable, ref_validator: Callable,
		atomic_submitter: Callable = Callable()) -> Result:
	"""Bind owner methods, never an auto-success fallback. Ref validator takes (domain, ref)."""
	if _submitting:
		return _refuse(&"SUBMISSION_IN_PROGRESS")
	_snapshot_reader = snapshot_reader
	_ref_validator = ref_validator
	_submitter = atomic_submitter
	return _success()


func open_room(room_ref: Vector2i) -> Result:
	"""Bind this exact live room identity and its permanent type, without creating any work."""
	var checked: Result = _room_refusal(room_ref)
	if not checked.ok:
		return checked
	var snapshot: Snapshot = _read(room_ref)
	if not _basic_snapshot(snapshot, room_ref):
		return _refuse(&"INVALID_ROOM_SNAPSHOT")
	var row: int = _find_room(room_ref)
	if row >= 0:
		return _same_type(row, snapshot)
	row = _room_slots.find(-1)
	if row < 0:
		return _refuse(&"ROOM_LAYOUT_CAPACITY")
	_room_slots[row] = room_ref.x
	_room_generations[row] = room_ref.y
	_room_types[row] = snapshot.room_type
	_room_modes[row] = MODE_LAYOUT
	return _success(row)


func set_mode(room_ref: Vector2i, mode: int) -> Result:
	"""Change this room's placement interaction only; retained drafts and orders are untouched."""
	var checked: Result = _opened_room(room_ref)
	if not checked.ok:
		return checked
	if mode != MODE_LAYOUT and mode != MODE_INDIVIDUAL:
		return _refuse(&"INVALID_FURNISHING_MODE")
	_room_modes[checked.value] = mode
	return _success(mode)


func mode_of(room_ref: Vector2i) -> Result:
	"""Read the live room's preference without transferring it to a reused room slot."""
	var checked: Result = _opened_room(room_ref)
	return _success(_room_modes[checked.value]) if checked.ok else checked


func place(room_ref: Vector2i, type_id: int, origin: Vector2i, rotation: int) -> Result:
	"""Stage a layout preview, or submit one paid construction order in individual mode."""
	var checked: Result = _opened_room(room_ref)
	if not checked.ok:
		return checked
	if _room_modes[checked.value] == MODE_LAYOUT:
		return _stage(checked.value, room_ref, type_id, origin, rotation)
	var entries: PackedInt32Array = PackedInt32Array([type_id, origin.x, origin.y, rotation])
	return _confirm(room_ref, checked.value, entries, PackedInt32Array())


func preview(room_ref: Vector2i, type_id: int, origin: Vector2i, rotation: int) -> Result:
	"""Get footprint/access guides and legality without altering drafts, world claims or stock."""
	var checked: Result = _opened_room(room_ref)
	if not checked.ok:
		return checked
	var entries: PackedInt32Array = PackedInt32Array()
	if _room_modes[checked.value] == MODE_LAYOUT:
		entries = _draft_entries(checked.value)
	entries.append_array(PackedInt32Array([type_id, origin.x, origin.y, rotation]))
	return _validate(_read(room_ref), room_ref, entries)


func edit_draft(draft_ref: Vector2i, type_id: int, origin: Vector2i, rotation: int) -> Result:
	"""Replace one draft only after the entire resulting arrangement still validates."""
	var row: int = _draft_row(draft_ref)
	if row < 0:
		return _refuse(&"STALE_DRAFT_REF")
	var room_ref: Vector2i = _ref_for_room(_room_row[row])
	var checked: Result = _opened_room(room_ref)
	if not checked.ok:
		return checked
	var entries: PackedInt32Array = _draft_entries(_room_row[row], row)
	entries.append_array(PackedInt32Array([type_id, origin.x, origin.y, rotation]))
	checked = _validate(_read(room_ref), room_ref, entries)
	if checked.ok:
		_write_entry(row, type_id, origin, rotation)
		checked.ref = draft_ref
	return checked


func discard_draft(draft_ref: Vector2i) -> Result:
	"""Explicitly discard one preview; a stale room may be cleaned up, never repurposed."""
	if _submitting:
		return _refuse(&"SUBMISSION_IN_PROGRESS")
	var row: int = _draft_row(draft_ref)
	if row < 0:
		return _refuse(&"STALE_DRAFT_REF")
	_free_placement(row)
	return _success()


func confirm_layout(room_ref: Vector2i) -> Result:
	"""Re-read all current owner state and atomically submit exactly this room's retained draft."""
	var checked: Result = _opened_room(room_ref)
	if not checked.ok:
		return checked
	var rows: PackedInt32Array = _rows_with_state(checked.value, STATE_DRAFT)
	if rows.is_empty():
		return _refuse(&"EMPTY_LAYOUT")
	return _confirm(room_ref, checked.value, _draft_entries(checked.value), rows)


func placements(room_ref: Vector2i, state: int = STATE_DRAFT) -> PackedInt32Array:
	"""Copy rows as ref slot/generation, type, X, Z, rotation; never expose mutable columns."""
	var result: PackedInt32Array = PackedInt32Array()
	var checked: Result = _opened_room(room_ref)
	if not checked.ok or (state != STATE_DRAFT and state != STATE_ACCEPTED):
		return result
	for row: int in _rows_with_state(checked.value, state):
		result.append_array(PackedInt32Array([row, _generation[row], _type[row],
			_x[row], _z[row], _rotation[row]]))
	return result


func project_of(placement_ref: Vector2i) -> Vector2i:
	"""Read an accepted receipt's live project; this receipt provides no installed service."""
	var row: int = placement_ref.x
	if not _is_placement(placement_ref, STATE_ACCEPTED):
		return NULL_REF
	var project: Vector2i = Vector2i(_project_slot[row], _project_generation[row])
	return project if _live(DOMAIN_PROJECT, project) else NULL_REF


func forget_receipt(placement_ref: Vector2i) -> Result:
	"""Release UI tracking only after the project retires; world occupancy remains owner-held."""
	if _submitting:
		return _refuse(&"SUBMISSION_IN_PROGRESS")
	if not _is_placement(placement_ref, STATE_ACCEPTED):
		return _refuse(&"STALE_PLACEMENT_REF")
	if project_of(placement_ref) != NULL_REF:
		return _refuse(&"CONSTRUCTION_PROJECT_STILL_LIVE")
	_free_placement(placement_ref.x)
	return _success()


func forget_room(room_ref: Vector2i) -> Result:
	"""Release an empty UI binding only; room removal/backfill belongs to its actual owner."""
	if _submitting:
		return _refuse(&"SUBMISSION_IN_PROGRESS")
	if _live(DOMAIN_ROOM, room_ref):
		return _refuse(&"ROOM_STILL_LIVE")
	var row: int = _find_room(room_ref)
	if row < 0:
		return _refuse(&"ROOM_NOT_OPEN")
	for placement: int in _placement_capacity:
		if _state[placement] != STATE_FREE and _room_row[placement] == row:
			return _refuse(&"ROOM_HAS_LAYOUT_ENTRIES")
	_room_slots[row] = -1
	_room_generations[row] = 0
	_room_types[row] = 0
	_room_modes[row] = MODE_LAYOUT
	return _success()


func _stage(room_row: int, room_ref: Vector2i, type_id: int,
		origin: Vector2i, rotation: int) -> Result:
	"""Append one generation-validated draft after checking combined layout and free capacity."""
	var free_rows: PackedInt32Array = _free_rows(1)
	if free_rows.is_empty():
		return _refuse(&"LAYOUT_ENTRY_CAPACITY")
	var entries: PackedInt32Array = _draft_entries(room_row)
	entries.append_array(PackedInt32Array([type_id, origin.x, origin.y, rotation]))
	var checked: Result = _validate(_read(room_ref), room_ref, entries)
	if not checked.ok:
		return checked
	var row: int = free_rows[0]
	_generation[row] += 1
	_state[row] = STATE_DRAFT
	_room_row[row] = room_row
	_write_entry(row, type_id, origin, rotation)
	checked.ref = Vector2i(row, _generation[row])
	return checked


func _confirm(room_ref: Vector2i, room_row: int, entries: PackedInt32Array,
		draft_rows: PackedInt32Array) -> Result:
	"""Validate before calling the only world mutator; retain every draft on any refusal."""
	if not _submitter.is_valid():
		return _refuse(&"CONSTRUCTION_COORDINATOR_UNBOUND")
	var snapshot: Snapshot = _read(room_ref)
	var checked: Result = _validate(snapshot, room_ref, entries)
	if not checked.ok:
		return checked
	var rows: PackedInt32Array = draft_rows
	if rows.is_empty():
		@warning_ignore("integer_division") var count: int = entries.size() / ENTRY_STRIDE
		rows = _free_rows(count)
		if rows.size() != count:
			return _refuse(&"LAYOUT_ENTRY_CAPACITY")
	var batch: Batch = _make_batch(snapshot, entries)
	_submitting = true
	var answer: Variant = _submitter.call(batch)
	_submitting = false
	if not answer is Submission:
		return _coordinator_breach()
	var submitted: Submission = answer as Submission
	if not submitted.ok:
		return _refuse(submitted.error)
	if not _receipt_valid(submitted.project_refs, rows.size()):
		return _coordinator_breach()
	_accept_receipts(room_row, rows, entries, submitted.project_refs)
	checked.ref = Vector2i(rows[0], _generation[rows[0]])
	checked.value = rows.size()
	return checked


func _make_batch(snapshot: Snapshot, entries: PackedInt32Array) -> Batch:
	"""Copy version and all placements so a receiver cannot mutate the retained draft."""
	var batch: Batch = Batch.new()
	batch.room_ref = snapshot.room_ref
	batch.room_type = snapshot.room_type
	batch.level = snapshot.level
	batch.pitch_units = snapshot.pitch_units
	batch.expected_revision = snapshot.revision
	batch.entries = entries.duplicate()
	return batch


func _accept_receipts(room_row: int, rows: PackedInt32Array,
		entries: PackedInt32Array, projects: PackedInt32Array) -> void:
	"""Keep packed order receipts; real occupancy and progress stay with the construction owner."""
	for index: int in rows.size():
		var row: int = rows[index]
		if _state[row] == STATE_FREE:
			_generation[row] += 1
		_state[row] = STATE_ACCEPTED
		_room_row[row] = room_row
		var base: int = index * ENTRY_STRIDE
		_write_entry(row, entries[base], Vector2i(entries[base + 1], entries[base + 2]),
			entries[base + 3])
		_project_slot[row] = projects[index * 2]
		_project_generation[row] = projects[index * 2 + 1]


func _receipt_valid(projects: PackedInt32Array, count: int) -> bool:
	"""Require distinct, live project references, never a fake installed-furniture success."""
	if projects.size() != count * 2:
		return false
	var seen: Dictionary = {}
	for row: int in _placement_capacity:
		if _state[row] == STATE_ACCEPTED:
			seen[Vector2i(_project_slot[row], _project_generation[row])] = true
	for index: int in count:
		var project: Vector2i = Vector2i(projects[index * 2], projects[index * 2 + 1])
		if seen.has(project) or not _live(DOMAIN_PROJECT, project):
			return false
		seen[project] = true
	return true


func _coordinator_breach() -> Result:
	"""Disable resubmission after an invalid external success until its owner reconciles/rebinds."""
	_submitter = Callable()
	return _refuse(&"CONSTRUCTION_COORDINATOR_CONTRACT_BREACH")


func _validate(snapshot: Snapshot, room_ref: Vector2i,
		entries: PackedInt32Array) -> Result:
	"""Check finished support, occupancy, all old/new contacts, and every protected connection."""
	if not _live(DOMAIN_ROOM, room_ref):
		return _refuse(&"STALE_ROOM_REF")
	if not _basic_snapshot(snapshot, room_ref):
		return _refuse(&"INVALID_ROOM_SNAPSHOT")
	var same_type: Result = _same_type(_find_room(room_ref), snapshot)
	if not same_type.ok:
		return same_type
	if not snapshot.shell_complete:
		return _refuse(&"ROOM_SHELL_UNFINISHED")
	if entries.is_empty() or entries.size() % ENTRY_STRIDE != 0 \
			or entries.size() > _placement_capacity * ENTRY_STRIDE:
		return _refuse(&"INVALID_LAYOUT_ENTRIES")
	var work: Validation = Validation.new()
	var code: StringName = _prepare_geometry(snapshot, work)
	if code == &"":
		code = _existing_objects(snapshot, work)
	if code == &"":
		code = _stamp_entries(snapshot, entries, work, true)
	if code == &"":
		code = _validate_routes(snapshot, work)
	work.result.ok = code == &""
	work.result.error = code
	return work.result


func _prepare_geometry(snapshot: Snapshot, work: Validation) -> StringName:
	"""Validate a canonical finite floor image, including explicit wall/height walk links."""
	var count: int = snapshot.floor_height.size()
	if count == 0 or count > _geometry_capacity or snapshot.floor_xy.size() != count * 2 \
			or snapshot.ceiling_height.size() != count:
		return &"INVALID_FLOOR_COLUMNS"
	work.occupied.resize(count)
	work.protected.resize(count)
	work.owned.resize(count)
	for index: int in count:
		var cell: Vector2i = _cell(snapshot, index)
		if work.cells.has(cell) or snapshot.ceiling_height[index] <= snapshot.floor_height[index]:
			return &"INVALID_FLOOR_CELL"
		work.cells[cell] = index
	return _prepare_cell_masks(snapshot, count, work)


func _prepare_cell_masks(snapshot: Snapshot, count: int, work: Validation) -> StringName:
	"""Separate furniture ownership from its potentially cross-room connected walk context."""
	if snapshot.room_cells.is_empty() or not _indices_valid(snapshot.room_cells, count):
		return &"INVALID_ROOM_FLOOR_CELLS"
	if not _indices_valid(snapshot.entries, count) or snapshot.entries.is_empty():
		return &"ROOM_HAS_NO_VALID_ENTRANCE"
	if not _indices_valid(snapshot.protected_cells, count) \
			or not _indices_valid(snapshot.blocked_cells, count):
		return &"INVALID_PROTECTED_OR_BLOCKED_CELL"
	for index: int in snapshot.room_cells:
		work.owned[index] = 1
	for index: int in snapshot.entries:
		work.protected[index] = 1
	for index: int in snapshot.protected_cells:
		work.protected[index] = 1
	for index: int in snapshot.blocked_cells:
		work.occupied[index] = 1
	return _prepare_links(snapshot.walk_links, count, work)


func _prepare_links(links: PackedInt32Array, count: int, work: Validation) -> StringName:
	"""Use only movement-owned undirected links; their eligibility is not inferred here."""
	if links.size() % 2 != 0 or links.size() > _geometry_capacity * LINKS_PER_OPERATION_CELL * 2:
		return &"INVALID_WALK_LINK"
	var seen: Dictionary = {}
	for base: int in range(0, links.size(), 2):
		var a: int = links[base]
		var b: int = links[base + 1]
		if a < 0 or b < 0 or a >= count or b >= count or a == b:
			return &"INVALID_WALK_LINK"
		var pair: Vector2i = Vector2i(mini(a, b), maxi(a, b))
		if seen.has(pair):
			return &"DUPLICATE_WALK_LINK"
		seen[pair] = true
		_add_neighbor(work, a, b)
		_add_neighbor(work, b, a)
	return &""


func _existing_objects(snapshot: Snapshot, work: Validation) -> StringName:
	"""Revalidate generations and real footprints/access of installed and ordered furnishings."""
	var count: int = snapshot.object_kinds.size()
	if count > _placement_capacity or count > _geometry_capacity \
			or snapshot.object_refs.size() != count * 2 \
			or snapshot.object_entries.size() != count * ENTRY_STRIDE:
		return &"INVALID_OBJECT_COLUMNS"
	var seen: Dictionary = {}
	for index: int in count:
		var kind: int = snapshot.object_kinds[index]
		var ref: Vector2i = Vector2i(snapshot.object_refs[index * 2], snapshot.object_refs[index * 2 + 1])
		if kind != DOMAIN_FURNITURE and kind != DOMAIN_PROJECT:
			return &"INVALID_OBJECT_DOMAIN"
		if not _live(kind, ref):
			return &"STALE_OBJECT_REF"
		var key: Vector3i = Vector3i(kind, ref.x, ref.y)
		if seen.has(key):
			return &"DUPLICATE_OBJECT_REF"
		seen[key] = true
	return _stamp_entries(snapshot, snapshot.object_entries, work, false)


func _stamp_entries(snapshot: Snapshot, entries: PackedInt32Array,
		work: Validation, collect_guides: bool) -> StringName:
	"""Stamp all furniture before routing, so a later placement cannot trap an earlier item."""
	for base: int in range(0, entries.size(), ENTRY_STRIDE):
		var code: StringName = _stamp_one(snapshot, entries, base, work, collect_guides)
		if code != &"":
			return code
	return &""


func _stamp_one(snapshot: Snapshot, entries: PackedInt32Array, base: int,
		work: Validation, collect_guides: bool) -> StringName:
	"""Resolve catalog dimensions and an explicitly authored clearance/contact profile."""
	var type_id: int = entries[base]
	var rotation: int = entries[base + 3]
	var code: StringName = _definition_refusal(snapshot, type_id, rotation)
	if code != &"":
		return code
	var profile: Profile = snapshot.profiles[type_id]
	@warning_ignore("integer_division") var scale: int = CATALOG_TILE_UNITS / snapshot.pitch_units
	var size: Vector2i = Vector2i(_definitions.floor_x_of(type_id), _definitions.floor_z_of(type_id)) * scale
	if int(size.x) * int(size.y) > _geometry_capacity:
		return &"FURNITURE_FOOTPRINT_EXCEEDS_OPERATION_BUDGET"
	var origin: Vector2i = Vector2i(entries[base + 1], entries[base + 2])
	code = _stamp_footprint(snapshot, work, origin, size, rotation, profile, collect_guides)
	if code != &"":
		return code
	code = _stamp_contacts(snapshot, work, origin, size, rotation, profile.install_xy,
		work.result.install_xy if collect_guides else PackedInt32Array())
	if code != &"":
		return code
	return _stamp_contacts(snapshot, work, origin, size, rotation, profile.use_xy,
		work.result.use_xy if collect_guides else PackedInt32Array())


func _definition_refusal(snapshot: Snapshot, type_id: int, rotation: int) -> StringName:
	"""Unknown compatibility, edge geometry and clearance are refusals, never permissive defaults."""
	if not _definitions.is_furniture_id(type_id):
		return &"UNKNOWN_FURNITURE_TYPE"
	if rotation < 0 or rotation > 3:
		return &"INVALID_ROTATION"
	if (snapshot.allowed_types_mask & (1 << type_id)) == 0:
		return &"FURNITURE_NOT_PERMITTED_IN_ROOM"
	if _definitions.is_edge_furniture(type_id):
		return &"EDGE_FURNITURE_REQUIRES_OPENING_OWNER"
	if type_id >= snapshot.profiles.size() or snapshot.profiles[type_id] == null:
		return &"FURNITURE_PROFILE_MISSING"
	var profile: Profile = snapshot.profiles[type_id]
	if profile.height_units <= 0 or profile.height_units > I32_MAX \
			or profile.install_xy.is_empty() or profile.use_xy.is_empty() \
			or profile.install_xy.size() % 2 != 0 or profile.use_xy.size() % 2 != 0 \
			or profile.install_xy.size() > _geometry_capacity * 2 \
			or profile.use_xy.size() > _geometry_capacity * 2:
		return &"FURNITURE_PROFILE_INCOMPLETE"
	return &""


func _stamp_footprint(snapshot: Snapshot, work: Validation, origin: Vector2i,
		size: Vector2i, rotation: int, profile: Profile, collect_guides: bool) -> StringName:
	"""Require every occupied cell to lie on one supported floor with enough headroom."""
	var floor_level: int = 0
	var first: bool = true
	for z: int in size.y:
		for x: int in size.x:
			var cell64: PackedInt64Array = _world_cell(origin, Vector2i(x, z), size, rotation)
			if not _cell_fits(cell64):
				return &"CELL_COORDINATE_OVERFLOW"
			var cell: Vector2i = Vector2i(cell64[0], cell64[1])
			if not work.cells.has(cell):
				return _at(work, &"FURNITURE_OUTSIDE_FINISHED_FLOOR", cell)
			var index: int = int(work.cells[cell])
			if first:
				floor_level = snapshot.floor_height[index]
				first = false
			var code: StringName = _occupy_cell(snapshot, work, index, floor_level, profile.height_units)
			if code != &"":
				return _at(work, code, cell)
			if collect_guides:
				work.result.occupied_xy.append_array(PackedInt32Array([cell.x, cell.y]))
	return &""


func _occupy_cell(snapshot: Snapshot, work: Validation, index: int,
		floor_level: int, height_units: int) -> StringName:
	"""Validate one cell before it joins the temporary combined occupancy image."""
	if work.owned[index] == 0:
		return &"FURNITURE_OUTSIDE_ROOM"
	if work.protected[index] != 0:
		return &"FURNITURE_BLOCKS_ENTRANCE_OR_LANDING"
	if work.occupied[index] != 0:
		return &"FURNITURE_OVERLAP"
	if snapshot.floor_height[index] != floor_level:
		return &"FURNITURE_CROSSES_FLOOR_HEIGHT"
	if int(snapshot.ceiling_height[index]) - int(snapshot.floor_height[index]) < height_units:
		return &"FURNITURE_HEADROOM_BLOCKED"
	work.occupied[index] = 1
	return &""


func _stamp_contacts(snapshot: Snapshot, work: Validation, origin: Vector2i,
		size: Vector2i, rotation: int, offsets: PackedInt32Array,
		guides: PackedInt32Array) -> StringName:
	"""Preserve every actual install/use contact; floor membership alone does not imply a route."""
	if work.contacts.size() * 2 + offsets.size() > _geometry_capacity * CONTACTS_PER_OPERATION_CELL * 2:
		return &"LAYOUT_CONTACT_BUDGET"
	for base: int in range(0, offsets.size(), 2):
		var cell64: PackedInt64Array = _world_cell(origin,
			Vector2i(offsets[base], offsets[base + 1]), size, rotation)
		if not _cell_fits(cell64):
			return &"CELL_COORDINATE_OVERFLOW"
		var cell: Vector2i = Vector2i(cell64[0], cell64[1])
		if not work.cells.has(cell):
			return _at(work, &"FURNITURE_ACCESS_OUTSIDE_FLOOR", cell)
		var index: int = int(work.cells[cell])
		var origin_index: int = int(work.cells[origin])
		if snapshot.floor_height[index] != snapshot.floor_height[origin_index]:
			return _at(work, &"FURNITURE_ACCESS_HEIGHT_MISMATCH", cell)
		work.contacts.append(index)
		guides.append_array(PackedInt32Array([cell.x, cell.y]))
	return &""


func _validate_routes(snapshot: Snapshot, work: Validation) -> StringName:
	"""Flood only owner-provided connections, then protect all existing/new contacts and landings."""
	var reached: PackedByteArray = _flood(snapshot, work)
	for index: int in work.contacts:
		if work.occupied[index] != 0 or reached[index] == 0:
			return _at(work, &"FURNITURE_ACCESS_UNREACHABLE", _cell(snapshot, index))
	for index: int in work.protected.size():
		if work.protected[index] != 0 and (work.occupied[index] != 0 or reached[index] == 0):
			return _at(work, &"ENTRANCE_OR_LANDING_UNREACHABLE", _cell(snapshot, index))
	return &""


func _flood(snapshot: Snapshot, work: Validation) -> PackedByteArray:
	"""Deterministic breadth-first traversal, bounded by this snapshot's actual cell count."""
	var reached: PackedByteArray = PackedByteArray()
	reached.resize(work.occupied.size())
	var queue: PackedInt32Array = PackedInt32Array()
	for index: int in snapshot.entries:
		if work.occupied[index] == 0 and reached[index] == 0:
			reached[index] = 1
			queue.append(index)
	var cursor: int = 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		var neighbors: PackedInt32Array = work.adjacency.get(current, PackedInt32Array())
		for neighbor: int in neighbors:
			if work.occupied[neighbor] == 0 and reached[neighbor] == 0:
				reached[neighbor] = 1
				queue.append(neighbor)
	return reached


func _basic_snapshot(snapshot: Snapshot, room_ref: Vector2i) -> bool:
	"""Validate identity, schema, exact catalog-grid mapping and explicit room compatibility."""
	return snapshot != null and snapshot.version == SNAPSHOT_VERSION \
		and snapshot.room_ref == room_ref and snapshot.revision >= 0 \
		and snapshot.room_type >= 0 and snapshot.room_type < Catalog.ROOM_TYPE.size() \
		and snapshot.pitch_units > 0 and snapshot.pitch_units <= CATALOG_TILE_UNITS \
		and CATALOG_TILE_UNITS % snapshot.pitch_units == 0 \
		and snapshot.allowed_types_mask >= 0 \
		and (snapshot.allowed_types_mask & ~_definitions.known_furniture_mask()) == 0 \
		and snapshot.profiles.size() <= BuildingDefinitions.FURNITURE_DEFINITION_COUNT


func _room_refusal(room_ref: Vector2i) -> Result:
	"""Reject missing providers, stale identities and callback reentrancy before any mutation."""
	if _submitting:
		return _refuse(&"SUBMISSION_IN_PROGRESS")
	if not _snapshot_reader.is_valid() or not _ref_validator.is_valid():
		return _refuse(&"ROOM_LAYOUT_SOURCES_UNBOUND")
	return _success() if _live(DOMAIN_ROOM, room_ref) else _refuse(&"STALE_ROOM_REF")


func _opened_room(room_ref: Vector2i) -> Result:
	"""Check the live identity and immutable type of a previously opened room."""
	var checked: Result = _room_refusal(room_ref)
	if not checked.ok:
		return checked
	var row: int = _find_room(room_ref)
	if row < 0:
		return _refuse(&"ROOM_NOT_OPEN")
	var snapshot: Snapshot = _read(room_ref)
	if not _basic_snapshot(snapshot, room_ref):
		return _refuse(&"INVALID_ROOM_SNAPSHOT")
	return _same_type(row, snapshot)


func _same_type(row: int, snapshot: Snapshot) -> Result:
	"""An emptied kitchen remains a kitchen until actual removal creates a new room identity."""
	if row < 0:
		return _refuse(&"ROOM_NOT_OPEN")
	return _success(row) if _room_types[row] == snapshot.room_type else _refuse(&"ROOM_TYPE_CHANGED")


func _read(room_ref: Vector2i) -> Snapshot:
	"""Read a provider result without assuming a malformed return is a valid spatial image."""
	var value: Variant = _snapshot_reader.call(room_ref)
	return value as Snapshot if value is Snapshot else null


func _live(domain: int, ref: Vector2i) -> bool:
	"""References are domain-specific; a matching slot with a different generation is stale."""
	return ref.x >= 0 and ref.y > 0 and _ref_validator.is_valid() \
		and _ref_validator.call(domain, ref) == true


func _find_room(room_ref: Vector2i) -> int:
	"""Cold-path identity lookup; callers never scan this arena per resident or per tick."""
	for row: int in _room_capacity:
		if _room_slots[row] == room_ref.x and _room_generations[row] == room_ref.y:
			return row
	return -1


func _ref_for_room(row: int) -> Vector2i:
	"""Reassemble the binding's whole room identity."""
	return Vector2i(_room_slots[row], _room_generations[row])


func _draft_row(draft_ref: Vector2i) -> int:
	"""Validate this module's local draft namespace, separate from directory/project refs."""
	return draft_ref.x if _is_placement(draft_ref, STATE_DRAFT) else -1


func _is_placement(ref: Vector2i, state: int) -> bool:
	"""Require live row state and matching generation, including after retirement and reuse."""
	return ref.x >= 0 and ref.x < _placement_capacity and ref.y > 0 \
		and _state[ref.x] == state and _generation[ref.x] == ref.y


func _rows_with_state(room_row: int, state: int) -> PackedInt32Array:
	"""Select this room's rows in stable slot order; no dictionary iteration defines commands."""
	var rows: PackedInt32Array = PackedInt32Array()
	for row: int in _placement_capacity:
		if _state[row] == state and _room_row[row] == room_row:
			rows.append(row)
	return rows


func _draft_entries(room_row: int, excluding_row: int = -1) -> PackedInt32Array:
	"""Copy the retained preview, optionally replacing one edit target."""
	var entries: PackedInt32Array = PackedInt32Array()
	for row: int in _rows_with_state(room_row, STATE_DRAFT):
		if row != excluding_row:
			entries.append_array(PackedInt32Array([_type[row], _x[row], _z[row], _rotation[row]]))
	return entries


func _free_rows(count: int) -> PackedInt32Array:
	"""Find lowest free, nonretired rows without changing allocation state on refusal."""
	var rows: PackedInt32Array = PackedInt32Array()
	for row: int in _placement_capacity:
		if _state[row] == STATE_FREE and _generation[row] < I32_MAX:
			rows.append(row)
			if rows.size() == count:
				break
	return rows


func _write_entry(row: int, type_id: int, origin: Vector2i, rotation: int) -> void:
	"""Write one row after its complete validation has succeeded."""
	_type[row] = type_id
	_x[row] = origin.x
	_z[row] = origin.y
	_rotation[row] = rotation


func _free_placement(row: int) -> void:
	"""Clear a retired payload while retaining its generation against stale preview handles."""
	_state[row] = STATE_FREE
	_room_row[row] = 0
	_type[row] = 0
	_x[row] = 0
	_z[row] = 0
	_rotation[row] = 0
	_project_slot[row] = -1
	_project_generation[row] = 0


static func _world_cell(origin: Vector2i, cell: Vector2i,
		size: Vector2i, rotation: int) -> PackedInt64Array:
	"""Rotate and translate in int64; only a validated final coordinate may narrow to int32."""
	var x: int = cell.x
	var z: int = cell.y
	match rotation:
		1:
			x = int(size.y) - 1 - int(cell.y)
			z = cell.x
		2:
			x = int(size.x) - 1 - int(cell.x)
			z = int(size.y) - 1 - int(cell.y)
		3:
			x = cell.y
			z = int(size.x) - 1 - int(cell.x)
	return PackedInt64Array([int(origin.x) + x, int(origin.y) + z])


static func _cell_fits(cell: PackedInt64Array) -> bool:
	"""Prove int64 transformed coordinates fit the authoritative int32 position domain."""
	return cell[0] >= -2147483648 and cell[0] <= I32_MAX \
		and cell[1] >= -2147483648 and cell[1] <= I32_MAX


static func _indices_valid(indices: PackedInt32Array, count: int) -> bool:
	"""Refuse duplicate or out-of-range spatial index claims."""
	if indices.size() > count:
		return false
	var seen: Dictionary = {}
	for index: int in indices:
		if index < 0 or index >= count or seen.has(index):
			return false
		seen[index] = true
	return true


static func _add_neighbor(work: Validation, a: int, b: int) -> void:
	"""Append an edge to the temporary adjacency image."""
	var neighbors: PackedInt32Array = work.adjacency.get(a, PackedInt32Array())
	neighbors.append(b)
	work.adjacency[a] = neighbors


static func _cell(snapshot: Snapshot, index: int) -> Vector2i:
	"""Read one integer X/Z floor cell."""
	return Vector2i(snapshot.floor_xy[index * 2], snapshot.floor_xy[index * 2 + 1])


static func _at(work: Validation, code: StringName, cell: Vector2i) -> StringName:
	"""Return a specific refusal and retain its affected cell for visible highlighting."""
	work.result.affected_xy = PackedInt32Array([cell.x, cell.y])
	return code


static func _success(value: int = 0) -> Result:
	"""Return a typed success; no resource or construction side effect is implied."""
	var result: Result = Result.new()
	result.ok = true
	result.value = value
	return result


static func _refuse(code: StringName) -> Result:
	"""Expected placement failures are data for the UI, not unexpected engine diagnostics."""
	var result: Result = Result.new()
	result.error = code
	return result
