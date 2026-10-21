extends "res://scripts/core/underground_phase_structure.gd"
## Actual entry natural bearings. Reuses paid Room protection; creates no timber, roof or walkability.
## The original phase Scope, physical ledger and sealed candidate remain mandatory. Decision1122.

const BaseStructure := preload("res://scripts/core/underground_phase_structure.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const ENTRY_CONTROL_BYTES: int = 384
const REFUSE_ENTRY: StringName = &"STRUCTURE_ENTRY_SOURCE"
const REFUSE_HISTORY: StringName = &"STRUCTURE_ENTRY_BEARING_HISTORY"

var _entry_placements: WeakRef = null
var _entry_frontier: WeakRef = null
var _entry_source_revision: int = 0
var _entry_ref: Vector2i = NULL_REF
var _entry_payload: int = 0
var _entry_prefix: int = -1
var _entry_episode_row: int = -1
var _entry_selected: bool = false
var _entry_frame: PackedInt32Array = PackedInt32Array()
var _entry_episode: PackedInt32Array = PackedInt32Array()


func bind_entry_sources(placements: Placements, frontier: Frontier, reserved_bytes: int) -> StringName:
	"""Bind the original source owners once; the extra fixed packet must be separately admitted."""
	if _reading:
		_poisoned = true
		return REFUSE_BUSY
	if _entry_placements != null or reserved_bytes < ENTRY_CONTROL_BYTES or _budget == null \
			or not _budget.is_quiescent() or _actual_owner() == null or _actual_owner().has_prepared():
		return REFUSE_BINDING
	if _entry_binding_leaf(placements, frontier) != &"":
		return REFUSE_ENTRY
	_entry_placements = weakref(placements)
	_entry_frontier = weakref(frontier)
	_entry_source_revision = frontier._header[0]
	_entry_frame.resize(9)
	_entry_episode.resize(19)
	return &""


func _entry_binding_leaf(placements: Placements, frontier: Frontier) -> StringName:
	"""Exact actual stores and immutable source namespaces, with no observing callback or copied permission."""
	var sites: Sites = _actual_sites()
	if placements == null or frontier == null or sites == null or not placements._configured \
			or placements._space != _actual_owner() or placements._budget != _budget \
			or placements._construction != sites._construction or placements._construction == null \
			or placements._construction._excavation_authority == null \
			or placements._construction._excavation_authority.get_ref() != sites \
			or frontier._catalog != placements._catalog or frontier._assemblies != placements._assemblies \
			or frontier._recipes != placements._recipes or frontier._profiles != placements._profiles \
			or frontier._catalog._levels != _levels or Frontier.source_leaf_refusal(frontier) != &"" \
			or not _entry_placement_available(placements, sites):
		return REFUSE_ENTRY
	return &""


func _entry_placement_available(placements: Placements, sites: Sites) -> bool:
	"""Only this exact PREPARED operation may observe an active companion, including its busy copy interval."""
	if not placements._phase_mode: return not placements._busy
	if not _reading or _mode != PREPARED or sites._space == null: return false
	return Placements.phase_operation_leaf_refusal(placements, sites._space.get_ref(), _site,
		_operation, _stage, _room, _project, _cold_token, _owner_token) == &""


func _observe_inputs() -> StringName:
	"""The entry's explicit bearings replace only its own flat bands; ordinary Rooms keep the existing rule."""
	var code: StringName = _begin_refusal()
	if code == &"": code = _select_entry()
	if code != &"": return code
	if not _entry_selected: return super._observe_inputs()
	var owner: Owner = _actual_owner()
	code = owner.section_for_paid_cube_into(_room, _actual_sites().origin_of(_site), _revision, _section)
	if code == &"" and (_section.section != Vector2i(_entry_frame[5], _entry_frame[6]) \
			or _section.owner != _room or _section.role != Space.FLOOR_DATUM or _section.level != _entry_frame[4]):
		code = REFUSE_SECTION
	if code == &"": code = _current_refusal()
	if code != &"": return code
	_write_query_boxes()
	code = owner.overlapping_regions_into(_column, _handles)
	if code == &"": code = _current_refusal()
	if code != &"": return code
	if _handles.size() > _capacity * 2 or _handles.size() % 2 != 0: return REFUSE_CAPACITY
	return _prepare_mode()


func _select_entry() -> StringName:
	"""A full actual Corridor selects one Placement; no endpoint, height or coincident slot implies entry identity."""
	var placements: Placements = _entry_actual_placements()
	var frontier: Frontier = _entry_actual_frontier()
	if _entry_binding_leaf(placements, frontier) != &"" or frontier._header[0] != _entry_source_revision:
		return REFUSE_ENTRY
	if not _spend(placements._capacity * 4): return REFUSE_BUDGET
	var found: int = -1
	for row: int in placements._capacity:
		if placements._live.present[row] != 1 or placements._pair(placements._live, Placements.ROOM_SLOT, row) != _room:
			continue
		if found >= 0: return REFUSE_ENTRY
		found = row
	if found < 0: return &""
	if _operation not in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]: return REFUSE_ENTRY
	_entry_ref = Vector2i(found, placements._get32(placements._live, Placements.GENERATION, found))
	_entry_payload = placements._get64(placements._live, Placements.PAYLOAD_REVISION, found)
	_entry_prefix = placements._get32(placements._live, Placements.INSTALLED, found)
	var code: StringName = _entry_frame_into(placements)
	if code != &"" or placements._pair(placements._live, Placements.PROJECT_SLOT, found) != NULL_REF: return REFUSE_ENTRY
	_entry_selected = true
	_write_query_boxes()
	return _select_episode(frontier)


func _entry_frame_into(placements: Placements) -> StringName:
	"""Copy the real nine-int frame without reopening a public observer during exact companion preparation."""
	if not placements._phase_mode: return placements.placement_frame_into(_entry_ref, _entry_frame)
	if not _entry_placement_available(placements, _actual_sites()) \
			or placements._placement_leaf(placements._live, _entry_ref.x) != &"": return REFUSE_ENTRY
	for axis: int in 3:
		_entry_frame[axis] = placements._get32(placements._live, Placements.X + axis, _entry_ref.x)
	_entry_frame[3] = placements._get32(placements._live, Placements.ROTATION, _entry_ref.x)
	_entry_frame[4] = placements._get32(placements._live, Placements.LEVEL, _entry_ref.x)
	for axis: int in 2:
		_entry_frame[5 + axis] = placements._get32(placements._live, Placements.SECTION_SLOT + axis, _entry_ref.x)
		_entry_frame[7 + axis] = placements._get32(placements._live, Placements.ANCHOR_SLOT + axis, _entry_ref.x)
	return &"" if _entry_placement_available(placements, _actual_sites()) else REFUSE_ENTRY


func _select_episode(frontier: Frontier) -> StringName:
	"""The permanent whole paid cube must belong to one phase-enabled source episode at the actual installed prefix."""
	var matches: int = 0
	for row: int in frontier._header[8 + Frontier.EPISODE]:
		if not _spend(24): return REFUSE_BUDGET
		if (frontier._field(Frontier.EPISODE, row, 6) & (1 << (_operation - 1))) == 0 \
				or frontier._field(Frontier.EPISODE, row, 7) != _entry_prefix: continue
		var code: StringName = _entry_world_box(frontier, Frontier.EPISODE, row, 0, _piece)
		if code != &"": return code
		if not Space.contains_box(_piece, _cube): continue
		matches += 1
		_entry_episode_row = row
		for field: int in 19: _entry_episode[field] = frontier._field(Frontier.EPISODE, row, field)
	return _entry_leaf() if matches == 1 else REFUSE_ENTRY


func _write_query_boxes() -> void:
	"""One bounded handle image includes all named bearings and neighboring protections, even outside the paid cube."""
	super._write_query_boxes()
	if _entry_selected:
		for axis: int in 6: _column[axis] = _domain._bounds[axis]


func _walk_claims() -> StringName:
	"""No flat roof is inferred for the entry; every foreign ordinary Room retains its authored protection."""
	if not _entry_selected: return super._walk_claims()
	var found: int = 0
	for ordinal: int in (_handles.size() >> 1):
		var code: StringName = _read_live(ordinal * 2, _claim)
		if code != &"": return code
		if _claim.claim_kind != Owner.CLAIM_ROOM:
			if _claim.role == Space.SUPPORT and Space.overlaps(_claim.box, _cube): return REFUSE_PROTECTED
			continue
		if _claim.role != Space.OBSTACLE or _claim.owner != _claim.claim_ref: return REFUSE_CLAIM
		if _claim.owner == _room:
			code = _entry_claim_refusal(ordinal)
			if Space.overlaps(_claim.box, _cube): found += 1
		else:
			if _claim.box[0] >= _cube[3] or _claim.box[3] <= _cube[0] \
					or _claim.box[2] >= _cube[5] or _claim.box[5] <= _cube[2]: continue
			code = _claim_level_refusal()
			if code == &"": code = _neighbor_refusal()
		if code != &"": return code
	return _entry_bearings() if found > 0 else REFUSE_CLAIM


func _entry_claim_refusal(ordinal: int) -> StringName:
	"""Confirmed fine cells retain their actual section and full identity; no whole paid cube expands the Room."""
	if _claim.section != _section.section or _claim.level != _section.level: return REFUSE_CLAIM
	for previous: int in ordinal:
		var code: StringName = _read_live(previous * 2, _row)
		if code != &"": return code
		if _row.claim_kind == Owner.CLAIM_ROOM and _row.owner == _room and Space.overlaps(_row.box, _claim.box):
			return REFUSE_CLAIM
	if _mode == PREPARED:
		var code: StringName = _actual_owner().prepared_region_observation_into(_owner_token,
			Vector2i(_handles[ordinal * 2], _handles[ordinal * 2 + 1]), _row)
		if code != &"" or not BaseStructure._same_region(_claim, _row): return REFUSE_CLAIM
	return _fast_refusal()


func _entry_bearings() -> StringName:
	"""Protect only explicit natural post roots; unsupported prior-part designs remain closed until their adapter exists."""
	var frontier: Frontier = _entry_actual_frontier()
	for row: int in range(_entry_episode[13], _entry_episode[13] + _entry_episode[14]):
		if not _spend(20 + 2 * Terrain.LOCAL_QUERY_CHECKS): return REFUSE_BUDGET
		if frontier._field(Frontier.BEARING, row, 0) != Frontier.NATURAL: return REFUSE_ENTRY
		var code: StringName = _entry_world_box(frontier, Frontier.BEARING, row, 3, _band)
		if code == &"": code = _actual_terrain().natural_support_refusal(_band)
		if code == &"": code = _actual_terrain().exclusions_refusal(_band)
		if code == &"": code = _fast_refusal()
		if code == &"": code = _entry_history_refusal(_band)
		if code == &"": code = _retained_band_refusal()
		if code != &"": return code
		if _mode == STAGE and _operation == Contract.OP_BRACE and _stage == Contract.STAGE_COMMIT:
			code = _stage_band()
		elif _needs_coverage and not (_mode == CHECK and _operation == Contract.OP_BRACE and _stage == Contract.STAGE_COMMIT):
			code = _support_coverage_refusal()
		if code != &"": return code
	return _fast_refusal()


func _entry_history_refusal(bounds: PackedInt32Array) -> StringName:
	"""Backfill cannot relabel previously cut earth as a natural post footing."""
	var sites: Sites = _actual_sites()
	for row: int in sites._count:
		if not _spend(16): return REFUSE_BUDGET
		if sites._present[row] != 1 or sites._ever_cut[row] == 0: continue
		var key: int = sites._site_key[row]
		var x: int = key % sites._domain.size_quanta.x
		@warning_ignore("integer_division") var rest: int = key / sites._domain.size_quanta.x
		var z: int = rest % sites._domain.size_quanta.z
		@warning_ignore("integer_division") var y: int = rest / sites._domain.size_quanta.z
		var origin: Vector3i = sites._domain.datum_u + (Vector3i(x, y, z) + sites._domain.minimum_quantum) * 1024
		var overlaps: bool = true
		for axis: int in 3:
			if int(origin[axis]) >= bounds[axis + 3] or int(origin[axis]) + 1024 <= bounds[axis]: overlaps = false
		if overlaps: return REFUSE_HISTORY
	return &""


func _entry_world_box(frontier: Frontier, table: int, row: int, first: int, out: PackedInt32Array) -> StringName:
	"""Rotate half-open bounds in int64, then check every translated coordinate before narrowing."""
	for axis: int in 6:
		var value: int = _entry_rotated_coordinate(frontier, table, row, first, axis)
		value += _entry_frame[axis % 3]
		if not Space.int32(value): return REFUSE_ENTRY
		out[axis] = value
	for axis: int in 3:
		if out[axis + 3] <= out[axis]: return REFUSE_ENTRY
	return &"" if Space.contains_box(_domain._bounds, out) else REFUSE_ENTRY


func _entry_rotated_coordinate(frontier: Frontier, table: int, row: int, first: int, axis: int) -> int:
	"""Compute a half-open cardinal bound in int64 before any packed int32 write."""
	var selected: int = axis
	var sign_value: int = 1
	match _entry_frame[3]:
		3:
			if axis % 3 == 0: selected = axis + 2
			elif axis % 3 == 2: selected = 3 - (axis - 2); sign_value = -1
		2:
			if axis % 3 != 1: selected = (axis + 3) % 6; sign_value = -1
		1:
			if axis % 3 == 0: selected = 5 - axis; sign_value = -1
			elif axis % 3 == 2: selected = axis - 2
	return sign_value * int(frontier._field(table, row, first + selected))


func _entry_leaf() -> StringName:
	"""Original source revision, complete placement frame, phase episode and current prefix remain exact after observers."""
	var placements: Placements = _entry_actual_placements()
	var frontier: Frontier = _entry_actual_frontier()
	if _entry_binding_leaf(placements, frontier) != &"" or frontier._header[0] != _entry_source_revision \
			or not placements._is_live(placements._live, _entry_ref) \
			or placements._pair(placements._live, Placements.ROOM_SLOT, _entry_ref.x) != _room \
			or placements._pair(placements._live, Placements.PROJECT_SLOT, _entry_ref.x) != NULL_REF \
			or placements._get64(placements._live, Placements.PAYLOAD_REVISION, _entry_ref.x) != _entry_payload \
			or placements._get32(placements._live, Placements.INSTALLED, _entry_ref.x) != _entry_prefix \
			or not frontier._valid_row(Frontier.EPISODE, _entry_episode_row): return REFUSE_ENTRY
	for axis: int in 3:
		if placements._get32(placements._live, Placements.X + axis, _entry_ref.x) != _entry_frame[axis]: return REFUSE_ENTRY
	for field: int in 19:
		if frontier._field(Frontier.EPISODE, _entry_episode_row, field) != _entry_episode[field]: return REFUSE_ENTRY
	if placements._get32(placements._live, Placements.ROTATION, _entry_ref.x) != _entry_frame[3] \
			or placements._get32(placements._live, Placements.LEVEL, _entry_ref.x) != _entry_frame[4] \
			or placements._pair(placements._live, Placements.SECTION_SLOT, _entry_ref.x) != Vector2i(_entry_frame[5], _entry_frame[6]) \
			or placements._pair(placements._live, Placements.ANCHOR_SLOT, _entry_ref.x) != Vector2i(_entry_frame[7], _entry_frame[8]):
		return REFUSE_ENTRY
	return _entry_source_leaf(placements, frontier)


func _entry_source_leaf(placements: Placements, frontier: Frontier) -> StringName:
	"""The Placement's published namespace must still name this exact immutable frontier and its source owners."""
	if placements._live.header[Placements.H_FRONTIER_REV] != _entry_source_revision \
			or placements._live.header[Placements.H_CATALOG_REV] != frontier._header[1] \
			or placements._live.header[Placements.H_VARIANT_REV] != frontier._header[2] \
			or placements._live.header[Placements.H_GROUP_REV] != frontier._header[3] \
			or placements._live.header[Placements.H_RECIPE_REV] != frontier._header[4] \
			or placements._live.header[Placements.H_CATALOG_ROW] != frontier._header[6]: return REFUSE_ENTRY
	for index: int in 96:
		if placements._live.digests[index] != frontier._digests[32 + index]: return REFUSE_ENTRY
	for index: int in 32:
		if placements._live.digests[96 + index] != frontier._digests[index]: return REFUSE_ENTRY
	return &""


func _fast_refusal() -> StringName:
	"""The additional packet fits the original shared lease; no cold limit is enlarged."""
	var code: StringName = super._fast_refusal()
	if code == &"" and BaseStructure.cold_peak_bytes(_mode, _capacity) + ENTRY_CONTROL_BYTES > Budget.COLD_BYTES:
		return REFUSE_COLD
	return _entry_leaf() if code == &"" and _entry_selected and _entry_episode_row >= 0 else code


func _current_refusal() -> StringName:
	"""Repeat permanent bearing history after the final source/Space observations before returning permission."""
	var code: StringName = super._current_refusal()
	if code != &"" or not _entry_selected: return code
	var frontier: Frontier = _entry_actual_frontier()
	for row: int in range(_entry_episode[13], _entry_episode[13] + _entry_episode[14]):
		code = _entry_world_box(frontier, Frontier.BEARING, row, 3, _piece)
		if code == &"": code = _entry_natural_leaf(_piece)
		if code == &"": code = _entry_history_refusal(_piece)
		if code != &"": return code
	return _entry_leaf()


func _entry_natural_leaf(bounds: PackedInt32Array) -> StringName:
	"""After World/Space observers, reread actual bounded terrain and exclusions without public observing callbacks."""
	var terrain: Terrain = _actual_terrain()
	if terrain == null or not _spend(2 * Terrain.LOCAL_QUERY_CHECKS): return REFUSE_BUDGET
	# The inherited current proof has just attested this actual Terrain/World/Space tuple.
	# Reuse its exact bounded local readers also while our own Space candidate is not sealed yet.
	var code: StringName = terrain._local_tiles_refusal(bounds, Terrain.FOOTING)
	return terrain._local_tiles_refusal(bounds, Terrain.EXCLUSIONS) if code == &"" else code


func _drop_cold() -> void:
	"""Transient selection ends with the inherited charged images; no entry context survives the phase call."""
	super._drop_cold()
	_entry_selected = false
	_entry_ref = NULL_REF
	_entry_payload = 0
	_entry_prefix = -1
	_entry_episode_row = -1


func _entry_actual_placements() -> Placements:
	"""Borrow the original actual Placement owner without retaining its world graph."""
	return _entry_placements.get_ref() as Placements if _entry_placements != null else null


func _entry_actual_frontier() -> Frontier:
	"""Borrow the original immutable source namespace; expired or replaced sources cannot grant structure."""
	return _entry_frontier.get_ref() as Frontier if _entry_frontier != null else null
