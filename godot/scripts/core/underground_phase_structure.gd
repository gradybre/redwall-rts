extends RefCounted
## Actual retained natural earth for confirmed Rooms. No recipe, installed beam, work contact or route
## is invented here. SUPPORT protections persist until actual Room structural retirement. Decision1093.

const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CHECK: int = 0
const STAGE: int = 1
const PREPARED: int = 2
const CONTROL_BYTES: int = 1536
const PLAN_ROWS: int = 1013
const REFUSE_BINDING: StringName = &"STRUCTURE_ACTUAL_BINDING"
const REFUSE_SCOPE: StringName = &"STRUCTURE_PHASE_SCOPE"
const REFUSE_BUSY: StringName = &"STRUCTURE_REENTRY"
const REFUSE_BUDGET: StringName = &"STRUCTURE_OPERATION_BUDGET"
const REFUSE_COLD: StringName = &"STRUCTURE_COLD_LEASE"
const REFUSE_SECTION: StringName = &"STRUCTURE_AUTHORED_SECTION"
const REFUSE_CLAIM: StringName = &"STRUCTURE_EXACT_CLAIMS"
const REFUSE_BAND: StringName = &"STRUCTURE_RETAINED_EARTH_MISSING"
const REFUSE_PROTECTED: StringName = &"STRUCTURE_NEIGHBOR_PROTECTION"
const REFUSE_SUPPORT: StringName = &"STRUCTURE_PROTECTION_COVERAGE"
const REFUSE_OVERLAP: StringName = &"STRUCTURE_DUPLICATE_PROTECTION"
const REFUSE_BRACE: StringName = &"STRUCTURE_PAID_BRACE_MISSING"
const REFUSE_CAPACITY: StringName = &"STRUCTURE_FRAGMENT_CAPACITY"


class Scope extends RefCounted:
	func phase_world_owner() -> RefCounted:
		"""Identity-only reciprocal composition; an unbound scope cannot nominate a real World provider."""
		return null

	## The real WorldBindings adapter retains the exact current cold Site/Room/project/op/stage pins.
	func exact_binding(_owner: Owner, _terrain: Terrain, _levels: Levels, _sites: Sites,
			_budget: Budget) -> bool:
		"""A bare shared token or coincident full-ref number cannot select a different composed World."""
		return false

	func phase_refusal(_token: int, _site: Vector2i, _operation: int, _stage: int,
			_room: Vector2i) -> StringName:
		"""Check the actual retained synchronous scope without granting work/contact permission."""
		return &"STRUCTURE_PHASE_OWNER_UNBOUND"


var _scope: WeakRef = null
var _owner: WeakRef = null
var _terrain: WeakRef = null
var _sites: WeakRef = null
var _levels: Levels = null
var _budget: Budget = null
var _domain: Space.Domain = null
var _level_revision: int = 0
var _terrain_revision: int = 0
var _capacity: int = 0
var _reading: bool = false
var _poisoned: bool = false
var _owns_stage: bool = false
var _mode: int = CHECK
var _operation: int = -1
var _stage: int = -1
var _cold_token: int = 0
var _owner_token: int = 0
var _revision: int = 0
var _remaining: int = 0
var _physical_phase: int = -1
var _site: Vector2i = NULL_REF
var _room: Vector2i = NULL_REF
var _project: Vector2i = NULL_REF
var _needs_coverage: bool = false
var _installed: bool = false
var _count: int = 0
var _next_count: int = 0
var _cube: PackedInt32Array = PackedInt32Array()
var _column: PackedInt32Array = PackedInt32Array()
var _band: PackedInt32Array = PackedInt32Array()
var _piece: PackedInt32Array = PackedInt32Array()
var _cut: PackedInt32Array = PackedInt32Array()
var _overlap: PackedInt32Array = PackedInt32Array()
var _section: Owner.Region = Owner.Region.new()
var _claim: Owner.Region = Owner.Region.new()
var _row: Owner.Region = Owner.Region.new()
var _level: Levels.Record = Levels.Record.new()
var _other_level: Levels.Record = Levels.Record.new()
var _number: IntMath.IntResult = IntMath.IntResult.new()
var _handles: PackedInt32Array = PackedInt32Array()
var _front: PackedInt32Array = PackedInt32Array()
var _back: PackedInt32Array = PackedInt32Array()
var _future: Space.Snapshot = null


func configure(scope: Scope, owner: Owner, terrain: Terrain, levels: Levels,
		sites: Sites, budget: Budget) -> StringName:
	"""Pin only actual owners and an immutable authored domain; no physical row or authority is allocated."""
	if _reading:
		_poisoned = true
		return REFUSE_BUSY
	if _scope != null:
		return REFUSE_BINDING
	_reading = true
	_poisoned = false
	var domain: Space.Domain = owner.domain_copy() if owner != null else null
	var code: StringName = _configure_refusal(scope, owner, terrain, levels, sites, budget, domain)
	if code == &"" and not _poisoned:
		_scope = weakref(scope)
		_owner = weakref(owner)
		_terrain = weakref(terrain)
		_sites = weakref(sites)
		_levels = levels
		_budget = budget
		_domain = domain
		_level_revision = levels.content_revision()
		_terrain_revision = terrain.content_revision()
		_capacity = owner.region_capacity()
		_allocate_fixed()
	_reading = false
	return REFUSE_BUSY if _poisoned else code


func _configure_refusal(scope: Scope, owner: Owner, terrain: Terrain, levels: Levels,
		sites: Sites, budget: Budget, domain: Space.Domain) -> StringName:
	"""Reject missing source content and foreign identity before retaining configuration or allocating arrays."""
	if scope == null or owner == null or terrain == null or levels == null or sites == null or budget == null:
		return REFUSE_BINDING
	if not budget.is_quiescent() or not owner.allocation_within(Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY) \
			or sites.construction_owner() == null or sites.initialization_refusal() != &"" \
			or terrain.binding_refusal() != &"" or not terrain.is_bound_budget(budget):
		return REFUSE_BINDING
	if domain == null or domain._regions > Budget.PHASE_VOLUME_CAPACITY:
		return REFUSE_BINDING
	if not levels.binding_matches(domain, sites.construction_owner().directory(), Space.VERSION) \
			or levels.content_revision() < 1 or not scope.exact_binding(owner, terrain, levels, sites, budget):
		return REFUSE_BINDING
	return &"" if not _poisoned and budget.is_quiescent() and not owner.has_prepared() else REFUSE_BINDING


func _allocate_fixed() -> void:
	"""One reused constant-size packet, never one object per Room, Site, fragment or resident."""
	for box: PackedInt32Array in [_cube, _column, _band, _piece, _cut, _overlap,
		_section.box, _claim.box, _row.box]:
		box.resize(6)


func _allocate_banks() -> void:
	"""The exact lease and complete staged lifetime have already been checked immediately before entry."""
	_front.resize(_capacity * 6)
	_back.resize(_capacity * 6)


func scope_owner() -> Scope:
	"""Expose the borrowed configured Scope identity; this is never a structural or contact permission."""
	return _actual_scope()


func is_bound_to(owner: Owner, terrain: Terrain, levels: Levels, sites: Sites, budget: Budget) -> bool:
	"""Identity-only reciprocal composition must use these exact nonnull configured owners."""
	if owner == null or terrain == null or levels == null or sites == null or budget == null \
			or _actual_scope() == null or _actual_owner() != owner or _actual_terrain() != terrain \
			or _actual_sites() != sites or _levels != levels or _budget != budget or _domain == null:
		return false
	return sites.construction_owner() != null and terrain.binding_refusal() == &"" \
		and levels.content_revision() == _level_revision and terrain.content_revision() == _terrain_revision


func structure_refusal(site: Vector2i, operation: int, stage: int, room: Vector2i,
		cold_token: int) -> StringName:
	"""Cold actual natural/retained geometry proof; this grants no work or space publication by itself."""
	return _run(CHECK, 0, site, operation, stage, room, cold_token)


func stage_geometry(owner_token: int, site: Vector2i, operation: int, stage: int,
		room: Vector2i, cold_token: int) -> StringName:
	"""Only a real paid BRACE completion adds exact natural protections to the existing actual candidate."""
	return _run(STAGE, owner_token, site, operation, stage, room, cold_token)


func prepared_refusal(owner_token: int, site: Vector2i, operation: int, stage: int,
		room: Vector2i, cold_token: int) -> StringName:
	"""Re-read exact obligations against the sealed future before physical payment/publication."""
	return _run(PREPARED, owner_token, site, operation, stage, room, cold_token)


func _run(mode: int, owner_token: int, site: Vector2i, operation: int, stage: int,
		room: Vector2i, cold_token: int) -> StringName:
	"""Hold strong borrowed collaborators across all callbacks; only this synchronous operation owns scratch."""
	if _reading:
		_poisoned = true
		return REFUSE_BUSY
	var owner: Owner = _actual_owner()
	var scope: Scope = _actual_scope()
	var terrain: Terrain = _actual_terrain()
	var sites: Sites = _actual_sites()
	if owner == null or scope == null or terrain == null or sites == null:
		return REFUSE_BINDING
	_reading = true
	_prepare_run(mode, owner_token, site, operation, stage, room, cold_token)
	var code: StringName = _observe_inputs()
	if code == &"":
		code = _walk_claims()
	if code == &"":
		code = _current_refusal()
	if code != &"" and _owns_stage:
		owner.abort(_owner_token)
	_drop_cold()
	_reading = false
	return code


func _prepare_run(mode: int, owner_token: int, site: Vector2i, operation: int, stage: int,
		room: Vector2i, cold_token: int) -> void:
	"""Replace only transient context after exclusivity and strong lifetime borrows have been established."""
	_poisoned = false
	_mode = mode
	_owner_token = owner_token
	_site = site
	_operation = operation
	_stage = stage
	_room = room
	_cold_token = cold_token
	_owns_stage = false


func _observe_inputs() -> StringName:
	"""Admit the complete simultaneous lifetime before query handles, bank images or future snapshots."""
	var code: StringName = _begin_refusal()
	if code != &"":
		return code
	var owner: Owner = _actual_owner()
	code = owner.section_for_paid_cube_into(_room, _actual_sites().origin_of(_site), _revision, _section)
	if code == &"":
		code = _level_for(_section, _level)
	if code == &"":
		code = _current_refusal()
	if code != &"":
		return code
	_write_query_boxes()
	code = owner.overlapping_regions_into(_column, _handles)
	if code == &"":
		code = _current_refusal()
	if code != &"":
		return code
	if _handles.size() > _capacity * 2 or _handles.size() % 2 != 0:
		return REFUSE_CAPACITY
	return _prepare_mode()


func _begin_refusal() -> StringName:
	"""Pin the immutable content and current actual paid phase before retaining any dependent observation."""
	var owner: Owner = _actual_owner()
	var scope: Scope = _actual_scope()
	var terrain: Terrain = _actual_terrain()
	var sites: Sites = _actual_sites()
	if owner == null or scope == null or terrain == null or sites == null or _domain == null:
		return REFUSE_BINDING
	_revision = owner.revision()
	_remaining = _domain._checks
	if not _spend(8 * _capacity + 12 * Budget.SOURCE_CAPACITY):
		return REFUSE_BUDGET
	if not Contract.valid_operation(_operation) or _stage < Contract.STAGE_ADMIT or _stage > Contract.STAGE_WORK \
			or (_mode != CHECK and _stage not in [Contract.STAGE_START, Contract.STAGE_COMMIT, Contract.STAGE_CANCEL]):
		return REFUSE_SCOPE
	var admission: StringName = _fast_refusal()
	if admission != &"":
		return admission
	if not scope.exact_binding(owner, terrain, _levels, sites, _budget) \
			or _levels.content_revision() != _level_revision or terrain.content_revision() != _terrain_revision:
		return REFUSE_BINDING
	var code: StringName = _scope_refusal()
	if code == &"":
		code = owner.site_scope_refusal(sites, _site)
	if code == &"":
		code = _phase_refusal()
	return _current_refusal() if code == &"" else code


func _phase_refusal() -> StringName:
	"""A true paid byte is separate from a phase name; future brace completion still requires actual accepted work."""
	var sites: Sites = _actual_sites()
	_project = sites.project_of(_site)
	if sites.room_of(_site) != _room or not sites.phase_into(_site, _number):
		return REFUSE_SCOPE
	_physical_phase = _number.value
	if _stage == Contract.STAGE_ADMIT:
		if _project != NULL_REF:
			return REFUSE_SCOPE
	elif not sites.operation_into(_site, _number) or _number.value != _operation:
		return REFUSE_SCOPE
	var code: StringName = _paid_work_refusal()
	if code != &"":
		return code
	_installed = sites.installed_support(_site)
	if _operation in [Contract.OP_CUT, Contract.OP_FINISH] and not _installed:
		return REFUSE_BRACE
	_needs_coverage = _installed or (_operation == Contract.OP_BRACE and _stage == Contract.STAGE_COMMIT)
	return &""


func _paid_work_refusal() -> StringName:
	"""Repeated final checks read the actual phase/work/Job rather than retaining an earlier completed value."""
	var sites: Sites = _actual_sites()
	var construction: Construction = sites.construction_owner()
	if construction == null:
		return REFUSE_SCOPE
	if _stage == Contract.STAGE_START and (not construction.phase_into(_project, _number) \
			or _number.value != Construction.PHASE_READY):
		return REFUSE_SCOPE
	if _stage == Contract.STAGE_COMMIT and (not construction.phase_into(_project, _number) \
			or _number.value != Construction.PHASE_WORK_DONE \
			or not construction.remaining_mwu_into(_project, _number) or _number.value != 0 \
			or sites.job_of(_site) == NULL_REF):
		return REFUSE_SCOPE
	return &""


func _prepare_mode() -> StringName:
	"""Staging uses flat banks; future verification uses a snapshot after those banks and old survey have dropped."""
	var code: StringName = _scope_refusal()
	if code != &"":
		return code
	if _mode == STAGE:
		code = _actual_owner().stage_source(_owner_token, _room)
		if code != &"":
			return code
		_owns_stage = true
		code = _current_refusal()
		if code == &"" and _operation == Contract.OP_BRACE and _stage == Contract.STAGE_COMMIT:
			_allocate_banks()
	elif _mode == PREPARED:
		code = _actual_owner().prepared_refusal(_owner_token)
		if code == &"":
			code = _current_refusal()
		if code == &"":
			_future = Space.Snapshot.new()
			code = _actual_owner().prepared_snapshot_into(_owner_token, _future)
		if code == &"":
			code = _prepared_section_refusal()
		if code == &"":
			code = _current_refusal()
	return code


func _prepared_section_refusal() -> StringName:
	"""The future must retain the exact authored floor/claim namespace, not merely physical boxes at similar heights."""
	if _future.version != Space.VERSION or _future.world_ref != _domain._world \
			or _future.revision != _revision + 1 or _future.volumes.role.size() > _capacity:
		return REFUSE_SECTION
	var code: StringName = _actual_owner().prepared_region_observation_into(_owner_token, _section.section, _row)
	if code != &"" or not _same_region(_section, _row):
		return REFUSE_SECTION
	return _fast_refusal()


func _write_query_boxes() -> void:
	"""The canonical paid origin is not rounded from fine paint; the neighboring protections use the same column."""
	var origin: Vector3i = _actual_sites().origin_of(_site)
	for axis: int in 3:
		_cube[axis] = origin[axis]
		_cube[axis + 3] = int(origin[axis]) + Space.QUANTUM_U
		_column[axis] = _cube[axis]
		_column[axis + 3] = _cube[axis + 3]
	_column[1] = _domain._bounds[1]
	_column[4] = _domain._bounds[4]


func _walk_claims() -> StringName:
	"""Every contributing accepted fine footprint remains exact; datum envelopes add no usable area."""
	var found: int = 0
	for ordinal: int in (_handles.size() >> 1):
		var at: int = ordinal * 2
		var code: StringName = _read_live(at, _claim)
		if code != &"":
			return code
		if _claim.claim_kind != Owner.CLAIM_ROOM:
			if _opening_operation() and _claim.role == Space.SUPPORT and Space.overlaps(_claim.box, _cube):
				return REFUSE_PROTECTED
			continue
		if _claim.role != Space.OBSTACLE or _claim.owner != _claim.claim_ref:
			return REFUSE_CLAIM
		code = _claim_level_refusal()
		if code != &"":
			return code
		if _claim.owner == _room and _claim.section == _section.section:
			found += 1
			code = _own_claim_refusal(at)
		else:
			code = _neighbor_refusal()
		if code != &"":
			return code
	return &"" if found > 0 else REFUSE_CLAIM


func _claim_level_refusal() -> StringName:
	"""Resolve actual generation-qualified metadata and the exact authored offset, never infer a ceiling."""
	var code: StringName = _actual_owner().region_into_reused(_claim.section, _row)
	if code != &"":
		return code
	if _row.role != Space.FLOOR_DATUM or _row.owner != _claim.owner \
			or _row.level != _claim.level:
		return REFUSE_SECTION
	code = _level_for(_row, _other_level)
	if code != &"":
		return code
	var top: int = _claim.box[4]
	if _claim.box[1] != _other_level.floor_y_u or (top != _other_level.clear_roof_y_u # DEC-054: or whole cubes below it.
			and (top <= _claim.box[1] or top > _other_level.clear_roof_y_u or (top - _claim.box[1]) % Space.QUANTUM_U != 0)):
		return REFUSE_SECTION
	return _fast_refusal()


func _level_for(section: Owner.Region, out: Levels.Record) -> StringName:
	"""The same immutable actual catalog owns clear height, roof and footing requirements."""
	var code: StringName = _levels.level_into(section.level, 0, out)
	if code != &"":
		return code
	var offset: int = int(section.box[1]) - out.floor_y_u
	code = _levels.level_into(section.level, offset, out)
	if code == &"" and (out.world_ref != _domain._world or out.content_revision != _level_revision \
			or out.floor_y_u != section.box[1]):
		return REFUSE_SECTION
	return code


func _own_claim_refusal(at: int) -> StringName:
	"""Disjoint claims make each exact natural band independent without double-counting future additions."""
	var code: StringName = &""
	for ordinal: int in (at >> 1):
		var previous: int = ordinal * 2
		code = _read_live(previous, _row)
		if code != &"":
			return code
		if _row.claim_kind == Owner.CLAIM_ROOM and _row.owner == _room 				and _row.section == _section.section and Space.overlaps(_row.box, _claim.box):
			return REFUSE_CLAIM
	if _mode == PREPARED:
		code = _actual_owner().prepared_region_observation_into(_owner_token,
			Vector2i(_handles[at], _handles[at + 1]), _row)
		if code != &"" or not _same_region(_claim, _row):
			return REFUSE_CLAIM
	code = _one_band(_level.required_footing_low_u, _level.required_footing_high_u)
	if code == &"" and _level.has_roof:
		code = _one_band(_claim.box[4], _level.protected_above_high_u) # DEC-054: from the Room's own top.
	return code


func _neighbor_refusal() -> StringName:
	"""Another confirmed section's required earth is protected even before it publishes a brace row."""
	if not _opening_operation():
		return &""
	_band_from_claim(_other_level.required_footing_low_u, _other_level.required_footing_high_u)
	if Space.overlaps(_band, _cube):
		return REFUSE_PROTECTED
	if _other_level.has_roof:
		_band_from_claim(_claim.box[4], _other_level.protected_above_high_u)
		if Space.overlaps(_band, _cube):
			return REFUSE_PROTECTED
	return &""


func _one_band(low_y: int, high_y: int) -> StringName:
	"""Original dry earth is necessary but every retained cavity, claim and physical obstruction also matters."""
	_band_from_claim(low_y, high_y)
	var terrain: Terrain = _actual_terrain()
	var code: StringName = terrain.natural_support_refusal(_band)
	if code == &"":
		code = terrain.exclusions_refusal(_band)
	if code == &"":
		code = _fast_refusal()
	if code == &"":
		code = _retained_band_refusal()
	if code != &"":
		return code
	if _mode == STAGE and _operation == Contract.OP_BRACE and _stage == Contract.STAGE_COMMIT:
		return _stage_band()
	if _needs_coverage and not (_mode == CHECK and _operation == Contract.OP_BRACE and _stage == Contract.STAGE_COMMIT):
		return _support_coverage_refusal()
	return &""


func _band_from_claim(low_y: int, high_y: int) -> void:
	"""Clip only horizontal fine boundaries; authored vertical obligations are never shortened."""
	_band[0] = maxi(_column[0], _claim.box[0])
	_band[2] = maxi(_column[2], _claim.box[2])
	_band[3] = mini(_column[3], _claim.box[3])
	_band[5] = mini(_column[5], _claim.box[5])
	_band[1] = low_y
	_band[4] = high_y


func _retained_band_refusal() -> StringName:
	"""Even an unfinished paid cavity removes natural bearing earth; metadata cannot fill the hole."""
	var count: int = _future.volumes.role.size() if _mode == PREPARED else _handles.size() >> 1
	for ordinal: int in count:
		var code: StringName = _read_row(ordinal, _row)
		if code != &"":
			return code
		if not Space.overlaps(_band, _row.box):
			continue
		if _row.claim_kind == Owner.CLAIM_NONE and _row.role in [Space.DRY_SOLID, Space.SUPPORT, Space.FLOOR_DATUM]:
			continue
		return REFUSE_BAND
	return &""


func _support_coverage_refusal() -> StringName:
	"""Disjoint clipped volume sum proves the complete integer union without allocating a third fragment image."""
	var total: int = 0
	var count: int = _future.volumes.role.size() if _mode == PREPARED else _handles.size() >> 1
	for ordinal: int in count:
		var code: StringName = _read_row(ordinal, _row)
		if code != &"":
			return code
		if not _matching_support(_row) or not Space.overlaps(_band, _row.box):
			continue
		_intersect(_band, _row.box, _cut)
		code = _support_pair_refusal(ordinal)
		if code != &"":
			return code
		total += _volume(_cut)
		if total > _volume(_band):
			return REFUSE_OVERLAP
	return &"" if total == _volume(_band) else REFUSE_SUPPORT


func _support_pair_refusal(ordinal: int) -> StringName:
	"""A duplicate support row cannot hide a missing interior patch through volume arithmetic."""
	for previous: int in ordinal:
		var code: StringName = _read_row(previous, _row)
		if code != &"":
			return code
		if _matching_support(_row) and Space.overlaps(_cut, _row.box):
			return REFUSE_OVERLAP
	return &""


func _stage_band() -> StringName:
	"""Subtract exact retained protections before adding the new Room-owned remainder to the same candidate."""
	for axis: int in 6:
		_front[axis] = _band[axis]
	_count = 1
	var code: StringName = &""
	for ordinal: int in (_handles.size() >> 1):
		var at: int = ordinal * 2
		code = _read_live(at, _row)
		if code != &"":
			return code
		if _matching_support(_row) and Space.overlaps(_band, _row.box):
			code = _subtract_bank(_row.box)
			if code != &"":
				return code
	code = _current_refusal()
	return _emit_supports() if code == &"" else code


func _emit_supports() -> StringName:
	"""Only the exact current candidate receives natural Room-lifetime protections; each addition is bounded."""
	for row: int in _count:
		var code: StringName = _fast_refusal()
		if code != &"":
			return code
		_copy_flat(_front, row * 6, _row.box)
		_row.role = Space.SUPPORT
		_row.level = _section.level
		_row.owner = _room
		_row.section = _section.section
		_row.claim_kind = Owner.CLAIM_NONE
		_row.claim_ref = NULL_REF
		code = _actual_owner().stage_add(_owner_token, _row).error
		if code != &"":
			return code
	return _fast_refusal()


func _subtract_bank(cut: PackedInt32Array) -> StringName:
	"""Six disjoint slabs implement exact set difference; capacity and comparison charges precede writes."""
	_next_count = 0
	for row: int in _count:
		if not _spend(1):
			return REFUSE_BUDGET
		_copy_flat(_front, row * 6, _piece)
		var code: StringName = _subtract_piece(cut)
		if code != &"":
			return code
	var previous: PackedInt32Array = _front
	_front = _back
	_back = previous
	_count = _next_count
	return &""


func _subtract_piece(cut: PackedInt32Array) -> StringName:
	"""Remove the intersection while shrinking the core; no face-overlap duplicates are emitted."""
	if not Space.overlaps(_piece, cut):
		return _emit_piece()
	_intersect(_piece, cut, _overlap)
	for axis: int in 3:
		if _piece[axis] < _overlap[axis]:
			var high: int = _piece[axis + 3]
			_piece[axis + 3] = _overlap[axis]
			var code: StringName = _emit_piece()
			_piece[axis + 3] = high
			_piece[axis] = _overlap[axis]
			if code != &"":
				return code
		if _piece[axis + 3] > _overlap[axis + 3]:
			var low: int = _piece[axis]
			_piece[axis] = _overlap[axis + 3]
			var code: StringName = _emit_piece()
			_piece[axis] = low
			_piece[axis + 3] = _overlap[axis + 3]
			if code != &"":
				return code
	return &""


func _emit_piece() -> StringName:
	"""Refuse before a flat scratch row can exceed the actual configured region capacity."""
	if not _spend(1):
		return REFUSE_BUDGET
	if _next_count >= _capacity:
		return REFUSE_CAPACITY
	for axis: int in 6:
		_back[_next_count * 6 + axis] = _piece[axis]
	_next_count += 1
	return &""


func _read_live(at: int, out: Owner.Region) -> StringName:
	"""One generation-qualified packed observation per charged row; source census brackets the complete pass."""
	if not _spend(1):
		return REFUSE_BUDGET
	var code: StringName = _actual_owner().region_into_reused(Vector2i(_handles[at], _handles[at + 1]), out)
	return _fast_refusal() if code == &"" else code


func _read_row(ordinal: int, out: Owner.Region) -> StringName:
	"""The sealed future is a bounded isolated snapshot; live qualification retains exact section identities."""
	if _mode != PREPARED:
		return _read_live(ordinal * 2, out)
	if not _spend(1):
		return REFUSE_BUDGET
	var rows: Space.Volumes = _future.volumes
	out.box[0] = rows.lo_x[ordinal]
	out.box[1] = rows.lo_y[ordinal]
	out.box[2] = rows.lo_z[ordinal]
	out.box[3] = rows.hi_x[ordinal]
	out.box[4] = rows.hi_y[ordinal]
	out.box[5] = rows.hi_z[ordinal]
	out.role = rows.role[ordinal]
	out.level = rows.level[ordinal]
	out.owner = rows.ref_at(ordinal)
	out.claim_kind = Owner.CLAIM_NONE # Physical SUPPORT rows cannot be claim markers in this provider.
	out.section = NULL_REF # Physical snapshot intentionally carries no section metadata.
	out.claim_ref = NULL_REF
	return &""


func _matching_support(row: Owner.Region) -> bool:
	"""Physical protection belongs to the Room for its lifetime; a metadata relink cannot lend a foreign Room support."""
	return row.role == Space.SUPPORT and row.claim_kind == Owner.CLAIM_NONE and row.owner == _room \
		and row.level == _section.level


func _opening_operation() -> bool:
	"""Closing restores matter and never removes these Room-lifetime protections."""
	return _operation in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]


func _scope_refusal() -> StringName:
	"""All allocating and mutating boundaries require the exact retained caller scope and actual arena token."""
	var code: StringName = _fast_refusal()
	if code != &"":
		return code
	var scope: Scope = _actual_scope()
	if scope == null:
		return REFUSE_BINDING
	if not _spend(4 * Budget.SOURCE_CAPACITY + 32):
		return REFUSE_BUDGET
	code = scope.phase_refusal(_cold_token, _site, _operation, _stage, _room)
	return _fast_refusal() if code == &"" else code


func _current_refusal() -> StringName:
	"""Source callbacks finish before final exact lease/revision/phase proof; no snapshot or flag substitutes for it."""
	var code: StringName = _scope_refusal()
	if code == &"" and not _spend(_capacity + Budget.SOURCE_CAPACITY):
		return REFUSE_BUDGET
	if code == &"":
		code = _actual_owner().snapshot_revision_refusal(_revision)
	if code == &"":
		code = _scope_refusal()
	if code == &"" and _mode == PREPARED:
		if not _spend(_capacity + Budget.SOURCE_CAPACITY):
			return REFUSE_BUDGET
		code = _actual_owner().prepared_refusal(_owner_token)
	return _paid_scope_refusal() if code == &"" else code


func _paid_scope_refusal() -> StringName:
	"""A callback cannot swap the physical phase or installed byte while retaining the same geometry revision."""
	var code: StringName = _scope_refusal()
	if code != &"":
		return code
	var sites: Sites = _actual_sites()
	if sites.project_of(_site) != _project or not sites.phase_into(_site, _number) \
			or _number.value != _physical_phase or sites.installed_support(_site) != _installed:
		return REFUSE_SCOPE
	if _stage != Contract.STAGE_ADMIT and (not sites.operation_into(_site, _number) or _number.value != _operation):
		return REFUSE_SCOPE
	code = _paid_work_refusal()
	return _fast_refusal() if code == &"" else code


func _fast_refusal() -> StringName:
	"""Leaf observations may invalidate a token; detect that before further scratch growth or staged writes."""
	if _poisoned:
		return REFUSE_BUSY
	var owner: Owner = _actual_owner()
	var sites: Sites = _actual_sites()
	if owner == null or sites == null or _budget == null or owner.revision() != _revision:
		return REFUSE_SCOPE
	var peak: int = cold_peak_bytes(_mode, _capacity)
	if peak < 0 or peak > Budget.COLD_BYTES or not _budget.covers(_cold_token, Budget.COLD_BYTES):
		return REFUSE_COLD
	return &""


func _drop_cold() -> void:
	"""The caller owns its lease; success/refusal clears only this provider's charged images and controls."""
	_handles.clear()
	_front.clear()
	_back.clear()
	_future = null
	_count = 0
	_next_count = 0
	_owns_stage = false
	_owner_token = 0
	_cold_token = 0


func _spend(checks: int) -> bool:
	"""Finite engineering work exhaustion is an explicit refusal, never a new room gameplay limit."""
	if checks < 0 or checks > _remaining:
		return false
	_remaining -= checks
	return true


func _actual_scope() -> Scope:
	"""Borrow the exact actual coordinator adapter without a permanent owner cycle."""
	return _scope.get_ref() as Scope if _scope != null else null


func _actual_owner() -> Owner:
	"""The full region namespace belongs to this actual instance, not its numeric handles alone."""
	return _owner.get_ref() as Owner if _owner != null else null


func _actual_sites() -> Sites:
	"""Borrow only the configured actual paid ledger."""
	return _sites.get_ref() as Sites if _sites != null else null


func _actual_terrain() -> Terrain:
	"""Missing actual natural terrain cannot be recreated from metadata or a caller box."""
	return _terrain.get_ref() as Terrain if _terrain != null else null


static func cold_peak_bytes(mode: int, region_rows: int) -> int:
	"""Count every simultaneous packed image, including caller surveys/plans, before provider growth."""
	if region_rows < 1 or region_rows > Budget.REGION_CAPACITY:
		return -1
	var plans: int = 144 * PLAN_ROWS
	var sources: int = 16 * Budget.SOURCE_CAPACITY
	if mode == CHECK:
		return 2 * (48 * Budget.PHASE_VOLUME_CAPACITY + sources) + plans + 8 * region_rows + CONTROL_BYTES
	if mode == STAGE:
		return 48 * Budget.PHASE_VOLUME_CAPACITY + sources + plans + 56 * region_rows + CONTROL_BYTES
	if mode == PREPARED:
		return 56 * region_rows + sources + plans + CONTROL_BYTES
	return -1


static func _same_region(a: Owner.Region, b: Owner.Region) -> bool:
	"""Exact claim identity and geometry remain immutable through structural preparation."""
	return a.box == b.box and a.role == b.role and a.level == b.level and a.owner == b.owner \
		and a.section == b.section and a.claim_kind == b.claim_kind and a.claim_ref == b.claim_ref


static func _intersect(a: PackedInt32Array, b: PackedInt32Array, out: PackedInt32Array) -> void:
	"""Called only on positively overlapping boxes; caller storage is reused without clipping permission."""
	for axis: int in 3:
		out[axis] = maxi(a[axis], b[axis])
		out[axis + 3] = mini(a[axis + 3], b[axis + 3])


static func _copy_flat(rows: PackedInt32Array, offset: int, out: PackedInt32Array) -> void:
	"""Copy exactly one already-bounded row into an unaliased reusable six-integer packet."""
	for axis: int in 6:
		out[axis] = rows[offset + axis]


static func _volume(box: PackedInt32Array) -> int:
	"""Each clipped band is at most1m by1m within the finite48m vertical terrain domain: int64-safe."""
	return int(box[3] - box[0]) * int(box[4] - box[1]) * int(box[5] - box[2])
