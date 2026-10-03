extends "res://scripts/core/underground_room_orders.gd".Bindings
## Actual Room claim observations for paid phases. These readers grant no work, support or route.
## The unimplemented inherited admission/contact/service gates remain closed. Decision1092.

const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_MASK_BINDING: StringName = &"ROOM_MASK_WORLD_BINDING"
const REFUSE_MASK_BUSY: StringName = &"ROOM_MASK_REENTRY"
const REFUSE_MASK_OUTPUT: StringName = &"ROOM_MASK_OUTPUT_SHAPE"
const REFUSE_MASK_CAPACITY: StringName = &"ROOM_MASK_CAPACITY"
const REFUSE_MASK_OVERLAP: StringName = &"ROOM_MASK_OVERLAPPING_CLAIMS"
const REFUSE_MASK_EMPTY: StringName = &"ROOM_MASK_CLAIM_MISSING"
const REFUSE_MASK_SCOPE: StringName = &"ROOM_MASK_SITE_SCOPE"
const REFUSE_MASK_BUDGET: StringName = &"ROOM_MASK_OPERATION_BUDGET"
const CONTROL_BYTES: int = 512
const SCAN_CHECKS: int = 12 * (Budget.REGION_CAPACITY + Budget.SOURCE_CAPACITY)

var _provider: WeakRef = null
var _sites: WeakRef = null
var _budget: Budget = null
var _reading: bool = false
var _remaining: int = 0
var _cube: PackedInt32Array = PackedInt32Array()
var _clip: PackedInt32Array = PackedInt32Array()
var _region: Owner.Region = Owner.Region.new()


func configure(provider: WorldBindings, sites: Sites, budget: Budget) -> StringName:
	"""Bind actual stores before fixed scratch allocation; no Room or physical identity is created."""
	if _reading or _provider != null:
		return REFUSE_MASK_BINDING
	_reading = true
	var code: StringName = _configuration_refusal(provider, sites, budget)
	if code != &"":
		_reading = false
		return code
	_provider = weakref(provider)
	_sites = weakref(sites)
	_budget = budget
	_cube.resize(6)
	_clip.resize(6)
	_region.box.resize(6)
	_reading = false
	return code


func _configuration_refusal(provider: WorldBindings, sites: Sites, budget: Budget) -> StringName:
	"""A coincident World/site number in another composition cannot bind this provider."""
	if provider == null or sites == null or budget == null or provider.binding_refusal() != &"" \
			or not provider.is_bound_budget(budget) or provider.space_owner() == null \
			or provider.sources() == null or provider.sources().construction_owner() == null:
		return REFUSE_MASK_BINDING
	var construction: Construction = provider.sources().construction_owner()
	if sites.initialization_refusal() != &"" or sites.construction_owner() != construction \
			or construction.excavation_authority() != sites \
			or not provider.space_owner().is_bound_sources(provider.sources()):
		return REFUSE_MASK_BINDING
	return &"" if construction.directory().is_valid_of_kind(provider.world_ref(), Directory.KIND_WORLD) \
		else REFUSE_MASK_BINDING


func exact_binding(buildings: Buildings, space: Owner, construction: Construction, world: Vector2i) -> bool:
	"""O(1) actual-object wiring only; phase/source/contact permission is checked by its separate owner."""
	var provider: WorldBindings = _actual_provider()
	var sites: Sites = _actual_sites()
	return provider != null and sites != null and construction != null and buildings != null \
		and provider.space_owner() == space and provider.world_ref() == world \
		and provider.sources() != null and provider.sources().construction_owner() == construction \
		and provider.sources().directory() == construction.directory() and construction.buildings() == buildings \
		and space != null and space.is_bound_sources(provider.sources()) \
		and sites.construction_owner() == construction and construction.excavation_authority() == sites \
		and provider.is_bound_budget(_budget) and construction.directory().is_valid_of_kind(world, Directory.KIND_WORLD)


func phase_world_owner() -> RefCounted:
	"""Borrow this exact configured composer; expiration never substitutes another same-store owner."""
	return _actual_provider()


func layout_budget_owner() -> Budget:
	"""Borrow only the configured actual arena; the inherited layout admission still refuses."""
	var provider: WorldBindings = _actual_provider()
	return _budget if provider != null and provider.is_bound_budget(_budget) else null


func phase_section_into(site: Vector2i, room: Vector2i, cold_token: int, out: Owner.Region) -> StringName:
	"""Resolve claims, never the metadata envelope or the paid cube's upper-cut Y, as the owning section."""
	if _reading:
		return REFUSE_MASK_BUSY
	_reading = true
	var provider: WorldBindings = _actual_provider()
	var sites: Sites = _actual_sites()
	var owner: Owner = provider.space_owner() if provider != null else null
	var code: StringName = _scope_refusal(site, room, cold_token) \
		if sites != null and owner != null else REFUSE_MASK_BINDING
	if code == &"" and (out == null or out.box.size() != 6):
		code = REFUSE_MASK_OUTPUT
	if code == &"":
		code = _read_section(site, room, cold_token, out)
	_reading = false
	return code


func _read_section(site: Vector2i, room: Vector2i, token: int, out: Owner.Region) -> StringName:
	"""Keep caller metadata untouched until every actual source/lease boundary has passed."""
	var provider: WorldBindings = _actual_provider()
	var owner: Owner = provider.space_owner()
	var revision: int = owner.revision()
	_remaining = _configured_checks(owner)
	if not _spend(SCAN_CHECKS):
		return REFUSE_MASK_BUDGET
	var current: StringName = _scope_refusal(site, room, token)
	if current != &"":
		return current
	var code: StringName = owner.section_for_paid_cube_into(room, _actual_sites().origin_of(site), revision, _region)
	if code == &"":
		code = _current_refusal(site, room, token, revision)
	if code == &"":
		_copy_region(_region, out)
	return code


func finish_mask_into(site: Vector2i, room: Vector2i, cold_token: int,
		row_limit: int, out: PackedInt32Array) -> StringName:
	"""Emit exact disjoint claimed volume; the caller retains the same lease until this array is cleared."""
	if _reading:
		return REFUSE_MASK_BUSY
	_reading = true
	out.clear()
	var provider: WorldBindings = _actual_provider()
	var sites: Sites = _actual_sites()
	var owner: Owner = provider.space_owner() if provider != null else null
	var code: StringName = _scope_refusal(site, room, cold_token) \
		if sites != null and owner != null else REFUSE_MASK_BINDING
	if code == &"" and (row_limit < 1 or row_limit > Budget.REGION_CAPACITY):
		code = REFUSE_MASK_CAPACITY
	if code == &"":
		code = _read_mask(site, room, cold_token, row_limit, out)
	if code != &"":
		out.clear()
	_reading = false
	return code


func _read_mask(site: Vector2i, room: Vector2i, token: int, limit: int, out: PackedInt32Array) -> StringName:
	"""Admit all cold scratch and actual work before the first whole-owner handle survey."""
	var provider: WorldBindings = _actual_provider()
	var owner: Owner = provider.space_owner()
	var revision: int = owner.revision()
	_remaining = _configured_checks(owner)
	if not _spend(SCAN_CHECKS):
		return REFUSE_MASK_BUDGET
	var code: StringName = _current_refusal(site, room, token, revision)
	if code != &"":
		return code
	code = owner.section_for_paid_cube_into(room, _actual_sites().origin_of(site), revision, _region)
	if code != &"":
		return code
	var section: Vector2i = _region.section
	var level: int = _region.level
	_write_cube(_actual_sites().origin_of(site))
	code = _current_refusal(site, room, token, revision)
	if code != &"":
		return code
	return _collect_mask(site, room, token, revision, section, level, limit, out)


func _collect_mask(site: Vector2i, room: Vector2i, token: int, revision: int,
		section: Vector2i, level: int, limit: int, out: PackedInt32Array) -> StringName:
	"""The8R handle image coexists with one exactly sized24F result, then drops before returning."""
	var handles: PackedInt32Array = PackedInt32Array()
	var code: StringName = _actual_provider().space_owner().overlapping_regions_into(_cube, handles)
	if code == &"":
		code = _current_refusal(site, room, token, revision)
	if code == &"" and (handles.size() % 2 != 0 or handles.size() > Budget.REGION_CAPACITY * 2):
		code = REFUSE_MASK_CAPACITY
	var counted: IntMath.IntResult = null
	if code == &"":
		counted = IntMath.IntResult.new()
		code = _count_mask_rows(handles, room, section, level, limit, counted)
	if code == &"":
		code = _current_refusal(site, room, token, revision)
	if code == &"":
		out.resize(counted.value * 6)
		code = _fill_mask(handles, room, section, level, out)
	if code == &"":
		code = _current_refusal(site, room, token, revision)
	handles.clear()
	return code


func _count_mask_rows(handles: PackedInt32Array, room: Vector2i, section: Vector2i,
		level: int, limit: int, out: IntMath.IntResult) -> StringName:
	"""Count before a separate exact-scope recheck; no callback may cause output allocation under a dead lease."""
	var rows: int = 0
	for at: int in range(0, handles.size(), 2):
		var code: StringName = _read_claim(Vector2i(handles[at], handles[at + 1]), room, section, level)
		if code != &"":
			return code
		if not _is_room_claim(room):
			continue
		if rows >= limit:
			return REFUSE_MASK_CAPACITY
		rows += 1
	out.value = rows
	return &"" if rows > 0 else REFUSE_MASK_EMPTY


func _fill_mask(handles: PackedInt32Array, room: Vector2i, section: Vector2i,
		level: int, out: PackedInt32Array) -> StringName:
	"""Fill one pre-sized output; no geometry snapshot, dictionary or per-fragment object is constructed."""
	var rows: int = 0
	for at: int in range(0, handles.size(), 2):
		var code: StringName = _read_claim(Vector2i(handles[at], handles[at + 1]), room, section, level)
		if code != &"":
			return code
		if not _is_room_claim(room):
			continue
		_clip_claim()
		code = _write_mask_row(out, rows)
		if code != &"":
			return code
		rows += 1
	return &"" if out.size() == rows * 6 else REFUSE_MASK_SCOPE


func _read_claim(handle: Vector2i, room: Vector2i, section: Vector2i, level: int) -> StringName:
	"""Every fixed-row observation and later pair check consumes the configured Domain work allowance."""
	if not _spend(1):
		return REFUSE_MASK_BUDGET
	var code: StringName = _actual_provider().space_owner().region_into_reused(handle, _region)
	if code != &"" or not _is_room_claim(room):
		return code
	return &"" if _region.section == section and _region.level == level else REFUSE_MASK_SCOPE


func _write_mask_row(out: PackedInt32Array, row: int) -> StringName:
	"""Every pair comparison consumes the actual domain work allowance before reading the next prior box."""
	if (row + 1) * 6 > out.size():
		return REFUSE_MASK_SCOPE
	for previous: int in row:
		if not _spend(1):
			return REFUSE_MASK_BUDGET
		if _overlaps_flat(_clip, out, previous * 6):
			return REFUSE_MASK_OVERLAP
	for axis: int in 6:
		out[row * 6 + axis] = _clip[axis]
	return &""


func _scope_refusal(site: Vector2i, room: Vector2i, token: int) -> StringName:
	"""Check exact actual World/site/Room lease before allocation and after every collaborator callback."""
	var provider: WorldBindings = _actual_provider()
	var sites: Sites = _actual_sites()
	if provider == null or sites == null or _budget == null or not provider.is_bound_budget(_budget) \
			or not _budget.covers(token, Budget.COLD_BYTES):
		return REFUSE_MASK_BINDING
	var owner: Owner = provider.space_owner()
	if owner == null:
		return REFUSE_MASK_BINDING
	var code: StringName = provider.cold_site_refusal(token, site, room)
	if code != &"":
		return code
	var construction: Construction = sites.construction_owner()
	if construction == null or not exact_binding(construction.buildings(), owner, construction, provider.world_ref()) \
			or not sites.is_live_site(site) or sites.room_of(site) != room or room == NULL_REF:
		return REFUSE_MASK_SCOPE
	code = owner.site_scope_refusal(sites, site)
	if code != &"":
		return code
	return provider.cold_site_refusal(token, site, room)


func _current_refusal(site: Vector2i, room: Vector2i, token: int, revision: int) -> StringName:
	"""A final callback cannot revoke the lease or change actual source facts behind the copied claim prefix."""
	var code: StringName = _scope_refusal(site, room, token)
	if code != &"":
		return code
	code = _actual_provider().space_owner().snapshot_revision_refusal(revision)
	if code == &"":
		code = _scope_refusal(site, room, token)
	if code != &"":
		return code
	return &"" if _actual_provider().space_owner().revision() == revision else &"SPACE_REVISION_STALE"


static func _configured_checks(owner: Owner) -> int:
	"""A bounded admitted descriptor exists only before the handle/result images, then drops immediately."""
	var domain: Space.Domain = owner.domain_copy()
	return int(domain.descriptor().max_checks) if domain != null else 0


func _spend(checks: int) -> bool:
	"""Pathological fragmentation refuses; it never silently runs an unbounded pair scan."""
	if checks < 0 or checks > _remaining:
		return false
	_remaining -= checks
	return true


func _is_room_claim(room: Vector2i) -> bool:
	"""Only explicit exact-room reservation rows define the usable outline, never datum envelopes."""
	return _region.role == Space.OBSTACLE and _region.owner == room \
		and _region.claim_kind == Owner.CLAIM_ROOM and _region.claim_ref == room


func _write_cube(origin: Vector3i) -> void:
	"""Sites owns the canonical whole quantum; no painted cell is rounded or used as a replacement key."""
	for axis: int in 3:
		_cube[axis] = origin[axis]
		_cube[axis + 3] = int(origin[axis]) + Space.QUANTUM_U


func _clip_claim() -> void:
	"""The already overlapping exact claim contributes only its true intersection with this paid cube."""
	for axis: int in 3:
		_clip[axis] = maxi(_cube[axis], _region.box[axis])
		_clip[axis + 3] = mini(_cube[axis + 3], _region.box[axis + 3])


static func _overlaps_flat(box: PackedInt32Array, rows: PackedInt32Array, offset: int) -> bool:
	"""Half-open adjacency is legal; duplicate or positive-volume overlapping claims are not disjoint output."""
	return box[0] < rows[offset + 3] and rows[offset] < box[3] \
		and box[1] < rows[offset + 4] and rows[offset + 1] < box[4] \
		and box[2] < rows[offset + 5] and rows[offset + 2] < box[5]


static func _copy_region(source: Owner.Region, out: Owner.Region) -> void:
	"""Both boxes are pre-sized; copying these fixed fields allocates no new output array."""
	for axis: int in 6:
		out.box[axis] = source.box[axis]
	out.role = source.role
	out.level = source.level
	out.owner = source.owner
	out.section = source.section
	out.claim_ref = source.claim_ref
	out.claim_kind = source.claim_kind


func _actual_provider() -> WorldBindings:
	"""Borrow one actual concrete composer without a WorldBindings-to-RoomOrders reference cycle."""
	return _provider.get_ref() as WorldBindings if _provider != null else null


func _actual_sites() -> Sites:
	"""The paid ledger's namespace is never reconstructed from numeric aliases in another world."""
	return _sites.get_ref() as Sites if _sites != null else null
