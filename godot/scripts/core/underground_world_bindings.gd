extends "res://scripts/core/underground_space_authority.gd".Bindings
## Actual World composition. A survey is observation, never excavation or traversal permission.
## Base matter is exactly subtracted around retained physical state; claims remain blockers.

const World := preload("res://scripts/core/world_init.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const NATURAL_ROW_LIMIT: int = 512
const COMPOSED_ROW_LIMIT: int = Budget.PHASE_VOLUME_CAPACITY
const FRAGMENT_LIMIT: int = 4096
const CONTROL_BYTES: int = 640
const SNAPSHOT_BYTES: int = 48 * Budget.REGION_CAPACITY + 16 * Budget.SOURCE_CAPACITY
const OUTPUT_BYTES: int = 48 * COMPOSED_ROW_LIMIT + 16 * Budget.SOURCE_CAPACITY
const SNAPSHOT_SCAN_CHECKS: int = 3 * (Budget.REGION_CAPACITY + Budget.SOURCE_CAPACITY)
const WORLD_LOOKUP_CHECKS: int = 10 * Budget.SOURCE_CAPACITY
const COMPOSITION_BYTES: int = SNAPSHOT_BYTES + 48 * NATURAL_ROW_LIMIT + OUTPUT_BYTES \
	+ 48 * FRAGMENT_LIMIT + CONTROL_BYTES
const REFUSE_BINDING: StringName = &"WORLD_COMPOSITION_BINDING"
const REFUSE_BOUNDS: StringName = &"WORLD_COMPOSITION_BOUNDS"
const REFUSE_CAPACITY: StringName = &"WORLD_COMPOSITION_CAPACITY"
const REFUSE_BUDGET: StringName = &"WORLD_COMPOSITION_COLD_LEASE"
const REFUSE_BUSY: StringName = &"WORLD_COMPOSITION_BUSY"

var _world: World = null
var _terrain: Terrain = null
var _owner: WeakRef = null
var _source_reader: WeakRef = null
var _budget: Budget = null
var _domain: Space.Domain = null
var _composing: bool = false
var _remaining: int = 0
var _retained_rows: int = 0
var _fragments: Array[PackedInt32Array] = []
var _next_fragments: Array[PackedInt32Array] = []
var _clip: PackedInt32Array = PackedInt32Array()
var _intersection: PackedInt32Array = PackedInt32Array()


func configure(world: World, terrain: Terrain, owner: Owner, reader: Owner.CoreSources,
		budget: Budget) -> StringName:
	"""Bind actual collaborators and the complete finite observation pack before any survey allocation."""
	if _owner != null:
		return &"WORLD_COMPOSITION_ALREADY_BOUND"
	if world == null or terrain == null or owner == null or reader == null or budget == null \
			or not owner.is_bound_sources(reader) or not terrain.is_bound_world(world, owner, reader) \
			or not terrain.is_bound_budget(budget) or terrain.binding_refusal() != &"":
		return REFUSE_BINDING
	if not owner.allocation_within(Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY) \
			or COMPOSITION_BYTES > Budget.COLD_BYTES:
		return REFUSE_CAPACITY
	_domain = owner.domain_copy()
	if _domain == null:
		return REFUSE_BINDING
	_world = world
	_terrain = terrain
	_owner = weakref(owner)
	_source_reader = weakref(reader)
	_budget = budget
	_clip.resize(6)
	_intersection.resize(6)
	return &""


func sources() -> Owner.CoreSources:
	"""Borrow the actual reader without making a Construction-to-Bindings reference cycle."""
	return _source_reader.get_ref() as Owner.CoreSources if _source_reader != null else null


func binding_refusal() -> StringName:
	"""Reject expired or rewired actual owners; static numeric references are insufficient."""
	var owner: Owner = _actual_owner()
	var reader: Owner.CoreSources = sources()
	if owner == null or reader == null or _terrain == null or _domain == null \
			or not owner.is_bound_sources(reader) or not _terrain.is_bound_world(_world, owner, reader) \
			or not _terrain.is_bound_budget(_budget):
		return REFUSE_BINDING
	return _terrain.binding_refusal()


func allocation_refusal(owner: Owner, proof_rows: int, cache_bytes: int) -> StringName:
	"""Attest actual bounded cache/owner identity; this supplies no physical qualification revision."""
	if binding_refusal() != &"" or owner != _actual_owner():
		return REFUSE_BINDING
	return &"" if proof_rows > 0 and proof_rows <= Budget.PROOF_CAPACITY \
		and cache_bytes == 69 * proof_rows + 60 and cache_bytes <= Budget.PROOF_BYTES \
		else REFUSE_CAPACITY


func is_bound_budget(candidate: Budget) -> bool:
	"""Only the configured World-owned cold arena can fund this provider's output lifetime."""
	return _budget != null and candidate == _budget


func composition_peak_bytes() -> int:
	"""Expose the full simultaneous packed peak; callers add their own retained plans and companions."""
	return COMPOSITION_BYTES if _owner != null else 0


func composed_snapshot_into(bounds: PackedInt32Array, out: Space.Snapshot, token: int) -> StringName:
	"""Compose under a retained lease; admitted failures clear output and reentry preserves the active output."""
	if _composing:
		return REFUSE_BUSY
	if out == null:
		return &"WORLD_COMPOSITION_OUTPUT"
	if out.volumes == null:
		_clear_snapshot(out)
		return &"WORLD_COMPOSITION_OUTPUT"
	_composing = true
	_clear_snapshot(out)
	var code: StringName = _query_refusal(bounds, token)
	if code == &"":
		code = _compose(bounds, out, token)
	_fragments.clear()
	_next_fragments.clear()
	if code != &"":
		_clear_snapshot(out)
	_composing = false
	return code


func _query_refusal(bounds: PackedInt32Array, token: int) -> StringName:
	"""Prove the exact borrowed lease before the first owner snapshot or transient fragment copy."""
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	if not Space.valid_box(bounds) or not Space.contains_box(_domain._bounds, bounds):
		return REFUSE_BOUNDS
	if not _budget.covers(token, COMPOSITION_BYTES):
		return REFUSE_BUDGET
	_remaining = _domain._checks
	_retained_rows = 0
	return &"" if _spend(SNAPSHOT_SCAN_CHECKS + WORLD_LOOKUP_CHECKS
		+ Terrain.natural_survey_checks(bounds)) else REFUSE_CAPACITY


func _compose(bounds: PackedInt32Array, out: Space.Snapshot, token: int) -> StringName:
	"""Keep one real source image, one finite natural image and the output; no hidden third snapshot."""
	var retained: Space.Snapshot = Space.Snapshot.new()
	var natural: Space.Volumes = Space.Volumes.new()
	var code: StringName = _actual_owner().snapshot_into(retained)
	if code == &"" and not _budget.covers(token, COMPOSITION_BYTES):
		return REFUSE_BUDGET
	if code == &"":
		code = _terrain.natural_survey_into(bounds, NATURAL_ROW_LIMIT, natural, token)
	if code == &"" and not _budget.covers(token, COMPOSITION_BYTES):
		return REFUSE_BUDGET
	if code == &"":
		code = _copy_retained(bounds, retained, out)
	if code == &"":
		code = _append_natural(natural, out.volumes)
	if code == &"":
		code = _current_sources_refusal(retained)
	if code == &"" and not _budget.covers(token, COMPOSITION_BYTES):
		return REFUSE_BUDGET
	if code == &"":
		out.version = retained.version
		out.world_ref = retained.world_ref
		out.revision = retained.revision
		out.live_refs = retained.live_refs.duplicate()
		out.live_revisions = retained.live_revisions.duplicate()
	return code


func _copy_retained(bounds: PackedInt32Array, retained: Space.Snapshot, out: Space.Snapshot) -> StringName:
	"""All actual clipped claims and blockers survive with their original full source identity."""
	if retained.volumes.role.size() > Budget.REGION_CAPACITY \
			or retained.live_revisions.size() > Budget.SOURCE_CAPACITY:
		return REFUSE_CAPACITY
	for row: int in retained.volumes.role.size():
		if not _spend():
			return REFUSE_CAPACITY
		if _clip_box(retained.volumes.box_at(row), bounds, _clip):
			var code: StringName = _append_row(out.volumes, _clip, retained.volumes, row)
			if code != &"":
				return code
	_retained_rows = out.volumes.role.size()
	return &""


func _append_natural(natural: Space.Volumes, out: Space.Volumes) -> StringName:
	"""Never let original substrate fill a retained void or erase its owner/unfinished state."""
	for row: int in natural.role.size():
		_fragments.clear()
		if not _append_fragment(_fragments, natural.box_at(row)):
			return REFUSE_CAPACITY
		for other: int in _retained_rows:
			if not _spend():
				return REFUSE_CAPACITY
			if not _suppresses_natural(natural.role[row], out.role[other]):
				continue
			var code: StringName = _subtract_retained(out.box_at(other))
			if code != &"":
				return code
			if _fragments.is_empty():
				break
		for box: PackedInt32Array in _fragments:
			var code: StringName = _append_row(out, box, natural, row)
			if code != &"":
				return code
	return &""


func _subtract_retained(cover: PackedInt32Array) -> StringName:
	"""Alternate two finite work lists, releasing the old fragments before reusing their list."""
	_next_fragments.clear()
	for box: PackedInt32Array in _fragments:
		if not _spend() or not _subtract_box(box, cover, _next_fragments):
			return REFUSE_CAPACITY
	_fragments.clear()
	var previous: Array[PackedInt32Array] = _fragments
	_fragments = _next_fragments
	_next_fragments = previous
	return &""


func _subtract_box(box: PackedInt32Array, cover: PackedInt32Array,
		out: Array[PackedInt32Array]) -> bool:
	"""Partition into at most six disjoint half-open slabs; never fill holes with a bounding box."""
	if not _clip_box(box, cover, _intersection):
		return _append_fragment(out, box)
	var center: PackedInt32Array = box.duplicate()
	for axis: int in 3:
		if center[axis] < _intersection[axis]:
			var lower: PackedInt32Array = center.duplicate()
			lower[axis + 3] = _intersection[axis]
			if not _append_fragment(out, lower):
				return false
			center[axis] = _intersection[axis]
		if center[axis + 3] > _intersection[axis + 3]:
			var upper: PackedInt32Array = center.duplicate()
			upper[axis] = _intersection[axis + 3]
			if not _append_fragment(out, upper):
				return false
			center[axis + 3] = _intersection[axis + 3]
	return true


func _append_fragment(out: Array[PackedInt32Array], box: PackedInt32Array) -> bool:
	"""Bound both packed fragment payload and work before any new retained copy."""
	if not _spend() or out.size() >= FRAGMENT_LIMIT:
		return false
	out.append(box.duplicate())
	return true


func _append_row(out: Space.Volumes, box: PackedInt32Array, source: Space.Volumes, row: int) -> StringName:
	"""Preserve source role/level/full generation/revision, refusing before capacity growth."""
	if not _spend() or out.role.size() >= mini(COMPOSED_ROW_LIMIT, _domain._regions):
		return REFUSE_CAPACITY
	return &"" if out.append(box, source.role[row], source.level[row], source.ref_at(row),
		source.owner_revision[row]) else REFUSE_CAPACITY


func _current_sources_refusal(snapshot: Space.Snapshot) -> StringName:
	"""Recheck actual source/claim truth in one finite owner scan, with no second snapshot or pair lookup."""
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	return _actual_owner().snapshot_revision_refusal(snapshot.revision)


func _actual_owner() -> Owner:
	"""A weak back-reference cannot extend an old World after its actual composition is gone."""
	return _owner.get_ref() as Owner if _owner != null else null


func _spend(amount: int = 1) -> bool:
	"""Keep clipping/subtraction/source observations inside the domain's unchanged cold-work ceiling."""
	if amount < 0 or _remaining < amount:
		return false
	_remaining -= amount
	return true


static func _suppresses_natural(natural_role: int, retained_role: int) -> bool:
	"""Actual material history wins; reservations/supports/occupants alone never claim a free excavation."""
	return retained_role == Space.DRY_SOLID or retained_role == Space.SUPPORTED_VOID \
		or retained_role == Space.UNFINISHED or retained_role == Space.WATER \
		or retained_role == Space.OPENABLE_SHELL \
		or (natural_role == Space.FLOOR_DATUM and retained_role == Space.FLOOR_DATUM)


static func _clip_box(first: PackedInt32Array, second: PackedInt32Array, out: PackedInt32Array) -> bool:
	"""Write exact integer intersection into caller scratch; zero-width face contact is not overlap."""
	for axis: int in 3:
		out[axis] = maxi(first[axis], second[axis])
		out[axis + 3] = mini(first[axis + 3], second[axis + 3])
		if out[axis] >= out[axis + 3]:
			return false
	return true


static func _clear_snapshot(out: Space.Snapshot) -> void:
	"""A refused or consumed observation has no world/revision or remaining packed output prefix."""
	out.version = Space.VERSION
	out.world_ref = NULL_REF
	out.revision = 0
	out.live_refs.clear()
	out.live_revisions.clear()
	if out.volumes == null:
		return
	out.volumes.lo_x.clear()
	out.volumes.lo_y.clear()
	out.volumes.lo_z.clear()
	out.volumes.hi_x.clear()
	out.volumes.hi_y.clear()
	out.volumes.hi_z.clear()
	out.volumes.role.clear()
	out.volumes.level.clear()
	out.volumes.owner_slot.clear()
	out.volumes.owner_generation.clear()
	out.volumes.owner_revision.clear()
