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
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
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
const REFUSE_ADMISSION: StringName = &"ROOM_ADMISSION_BINDING"
const REFUSE_LEVEL: StringName = &"ROOM_AUTHORED_LEVEL_REQUIRED"
const REFUSE_CUT: StringName = &"ROOM_PAID_CUT_OCCUPIED"
const REFUSE_RETAINED: StringName = &"ROOM_RETAINED_CUT_MAPPING_UNBOUND"
const REFUSE_ABOVE: StringName = &"ROOM_PROTECTED_ABOVE_OCCUPIED"
const REFUSE_FOOTING: StringName = &"ROOM_REQUIRED_FOOTING_OCCUPIED"
const REFUSE_ENTRY: StringName = &"PROSPECTIVE_ENTRY_CONTACT_UNBOUND"
const ROOM_CONTROL_BYTES: int = 2048
const ROOM_FOOTPRINT_BYTES_PER_CELL: int = 2192 #128 packed +16 plan copies +2048 native/growth.
const ROOM_TERRAIN_RUN_CHECKS: int = 3 * 16 * Terrain.LOCAL_TILE_LIMIT

var _provider: WeakRef = null
var _sites: WeakRef = null
var _budget: Budget = null
var _reading: bool = false
var _remaining: int = 0
var _cube: PackedInt32Array = PackedInt32Array()
var _clip: PackedInt32Array = PackedInt32Array()
var _region: Owner.Region = Owner.Region.new()
var _orders: WeakRef = null
var _levels: WeakRef = null
var _room_request: Orders.RoomPlan = null
var _room_pin: Orders.RoomPlan = null
var _room_token: int = 0
var _level: Levels.Record = Levels.Record.new()


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


func configure_room_admission(orders: Orders, levels: Levels) -> StringName:
	"""Bind the sole actual Room authority and authored heights; cold admission later proves their Domain."""
	var provider: WorldBindings = _actual_provider()
	if _reading or _orders != null or provider == null or orders == null or levels == null or levels.content_revision() < 1:
		return REFUSE_ADMISSION
	if not orders.is_bound_room_bindings(self) or orders.construction_owner() == null \
			or not exact_binding(orders.buildings_owner() as Buildings, provider.space_owner(),
				orders.construction_owner(), orders.world_ref()):
		return REFUSE_ADMISSION
	_orders = weakref(orders)
	_levels = weakref(levels)
	return &""


static func room_admission_cold_bytes(cell_count: int) -> int:
	"""Conservative temporary operation envelope, never a gameplay room-size or drawing-grid policy."""
	if cell_count < 1 or cell_count > Footprint.MAX_OPERATION_CELLS:
		return 0
	return maxi(WorldBindings.COMPOSITION_BYTES + 16 * cell_count + ROOM_CONTROL_BYTES,
		ROOM_FOOTPRINT_BYTES_PER_CELL * cell_count + ROOM_CONTROL_BYTES)


func begin_room_cold(plan: Orders.RoomPlan) -> StringName:
	"""Take the actual World lease before copies; genuine geometry precedes the missing entry companion."""
	if _reading or _room_token != 0:
		return REFUSE_MASK_BUSY
	_reading = true
	var provider: WorldBindings = _actual_provider()
	var orders: Orders = _actual_orders()
	var levels: Levels = _actual_levels()
	var sites: Sites = _actual_sites()
	var code: StringName = _admission_input_refusal(plan, orders, provider, levels, sites)
	if code == &"":
		_room_request = plan
		_room_token = _budget.acquire(Budget.COLD_BYTES)
		code = Budget.REFUSE_BUSY if _room_token == 0 else _current_room_refusal()
	if code == &"":
		_room_pin = Orders.RoomPlan.new()
		_room_pin.copy_from(plan)
		code = _admission_preflight(provider, levels)
	_drop_room_cold()
	_reading = false
	return code


func _admission_input_refusal(plan: Orders.RoomPlan, orders: Orders, provider: WorldBindings,
		levels: Levels, sites: Sites) -> StringName:
	"""Bound every caller dimension and capacity before one plan, Domain or Dictionary is copied."""
	if orders == null or provider == null or levels == null or sites == null or _budget == null \
			or sites != _actual_sites() or sites.construction_owner() != orders.construction_owner() \
			or orders.room_admission_refusal(plan, self) != &"" or plan == null \
			or plan.world != provider.world_ref() or plan.space_revision != provider.space_owner().revision():
		return REFUSE_ADMISSION
	var code: StringName = _admission_shape_refusal(plan)
	return code if code != &"" else _budget.admission_refusal(Budget.COLD_BYTES)


static func _admission_shape_refusal(plan: Orders.RoomPlan) -> StringName:
	"""Repeat nonallocating size arithmetic after callbacks before accepting a grown caller buffer."""
	if plan == null:
		return Orders.REFUSE_PLAN
	if plan.cells.size() < 2 or plan.cells.size() % 2 != 0 or plan.cell_size_u < 1 \
			or plan.cell_size_u > Space.I32_MAX or plan.height_u < 1 or plan.height_u > Space.I32_MAX \
			or not Space.int32(int(plan.origin_u.y) + plan.height_u):
		return Orders.REFUSE_PLAN
	@warning_ignore("integer_division") var count: int = plan.cells.size() / 2
	var bytes: int = room_admission_cold_bytes(count)
	if bytes < 1 or bytes > Budget.COLD_BYTES:
		return Budget.REFUSE_BYTES
	return &""


func room_cold_token() -> int:
	"""This read cannot create a lease or borrow the token of another synchronous owner."""
	return _room_token


func room_cold_refusal(plan: Orders.RoomPlan, token: int) -> StringName:
	"""An exact original input and live token are mandatory even before future entry companions exist."""
	if _reading or plan == null or plan != _room_request or token != _room_token:
		return Orders.REFUSE_ROOM_COLD
	return _current_room_refusal()


func _current_room_refusal() -> StringName:
	"""Recheck actual owner/source wiring, immutable input and exact lease around collaborator callbacks."""
	var provider: WorldBindings = _actual_provider()
	var orders: Orders = _actual_orders()
	if provider == null or orders == null or _actual_levels() == null or not _room_lease_current() \
			or orders.room_admission_refusal(_room_request, self) != &"" \
			or not exact_binding(orders.buildings_owner() as Buildings, provider.space_owner(),
				orders.construction_owner(), orders.world_ref()):
		return Orders.REFUSE_ROOM_COLD
	var code: StringName = provider.binding_refusal()
	if code == &"":
		code = _admission_shape_refusal(_room_request)
	if code == &"" and (not provider.is_bound_budget(_budget) or provider.terrain_owner() == null \
			or not provider.terrain_owner().is_bound_budget(_budget)):
		code = REFUSE_ADMISSION
	if code == &"" and provider.space_owner().revision() != _room_request.space_revision:
		code = &"SPACE_REVISION_STALE"
	if code == &"" and (not _room_lease_current() or orders.room_admission_refusal(_room_request, self) != &"" \
			or (_room_pin != null and not _same_admission_plan(_room_request, _room_pin))):
		code = Orders.REFUSE_ROOM_COLD
	return code


func _room_lease_current() -> bool:
	"""Pure identity and actual token checks are repeated immediately before every allocating boundary."""
	return _room_token > 0 and _budget != null and _budget.covers(_room_token, Budget.COLD_BYTES)


static func _same_admission_plan(first: Orders.RoomPlan, second: Orders.RoomPlan) -> bool:
	"""No callback may silently replace, sort, round, truncate or retype the original player request."""
	return first != null and second != null and first.world == second.world \
		and first.space_revision == second.space_revision and first.room_type == second.room_type \
		and first.level == second.level and first.origin_u == second.origin_u \
		and first.cell_size_u == second.cell_size_u and first.height_u == second.height_u and first.cells == second.cells


func _admission_preflight(provider: WorldBindings, levels: Levels) -> StringName:
	"""Run sequential Footprint and compositor peaks under one exact admitted synchronous lifetime."""
	var domain: Space.Domain = provider.space_owner().domain_copy()
	var code: StringName = _current_room_refusal()
	if code != &"" or domain == null:
		return code if code != &"" else REFUSE_ADMISSION
	var descriptor: Dictionary = domain.descriptor()
	_remaining = descriptor.max_checks
	if not _spend(SCAN_CHECKS + _room_pin.cells.size() * 32):
		return REFUSE_MASK_BUDGET
	code = _level_refusal(levels, domain, provider.sources().directory())
	if code == &"":
		code = _current_room_refusal()
	if code == &"":
		code = Footprint.validation_error(_room_pin.cells, descriptor.max_cells, true)
	if code != &"":
		return code
	var bounds: PackedInt32Array = _admission_bounds(descriptor.datum_u)
	if not Space.valid_box(bounds) or not Space.contains_box(descriptor.bounds_u, bounds):
		return Orders.REFUSE_PLAN
	code = _current_room_refusal()
	return code if code != &"" else _observe_room(provider, descriptor.datum_u, bounds)


func _level_refusal(levels: Levels, domain: Space.Domain, directory: Directory) -> StringName:
	"""Only the actual immutable catalog supplies the floor, roof, protected band and required footing."""
	if not levels.binding_matches(domain, directory, Space.VERSION):
		return REFUSE_LEVEL
	for index: int in levels.section_offset_count():
		var code: StringName = levels.level_into(_room_pin.level, levels.section_offset_at(index), _level)
		if code != &"":
			return code
		if _level.floor_y_u == _room_pin.origin_u.y:
			return &"" if _level.has_roof and _level.clear_height_u == _room_pin.height_u \
				and _level.world_ref == _room_pin.world else REFUSE_LEVEL
	return REFUSE_LEVEL


func _admission_bounds(datum: Vector3i) -> PackedInt32Array:
	"""Only the survey envelope expands to whole paid cuts and authored bands; confirmed cells stay exact."""
	var left: int = _room_pin.cells[0]
	var right: int = left
	for index: int in range(2, _room_pin.cells.size(), 2):
		left = mini(left, _room_pin.cells[index])
		right = maxi(right, _room_pin.cells[index])
	if not _write_room_box(left, _room_pin.cells[1], right + 1, _room_pin.cells[-1] + 1):
		return PackedInt32Array()
	if not _write_cut_span(datum):
		return PackedInt32Array()
	_clip[1] = mini(_clip[1], _level.required_footing_low_u)
	_clip[4] = maxi(_clip[4], _level.protected_above_high_u)
	return _clip.duplicate()


func _observe_room(provider: WorldBindings, datum: Vector3i, bounds: PackedInt32Array) -> StringName:
	"""The one unfiltered actual snapshot keeps every foreign claim, wall, item and paid cavity visible."""
	var snapshot: Space.Snapshot = Space.Snapshot.new()
	var code: StringName = provider.composed_snapshot_into(bounds, snapshot, _room_token)
	if code == &"":
		code = _current_room_refusal()
	if code == &"":
		code = _all_room_runs(snapshot, datum)
	if code == &"":
		code = provider.space_owner().snapshot_revision_refusal(_room_pin.space_revision)
	if code == &"":
		code = _current_room_refusal()
	# No prospective contact, profile, support or first-work companion is fabricated here.
	return code if code != &"" else REFUSE_ENTRY


func _all_room_runs(snapshot: Space.Snapshot, datum: Vector3i) -> StringName:
	"""Canonical X runs preserve holes and concavity; every nested row/cube comparison spends cold work."""
	var start: int = 0
	while start < _room_pin.cells.size():
		var end: int = start + 2
		while end < _room_pin.cells.size() and _room_pin.cells[end + 1] == _room_pin.cells[start + 1] \
				and _room_pin.cells[end] == _room_pin.cells[end - 2] + 1:
			end += 2
		if not _write_room_box(_room_pin.cells[start], _room_pin.cells[start + 1],
				_room_pin.cells[end - 2] + 1, _room_pin.cells[start + 1] + 1):
			return Orders.REFUSE_PLAN
		var code: StringName = _room_run_refusal(snapshot, datum)
		if code != &"":
			return code
		start = end
	return &""


func _room_run_refusal(snapshot: Space.Snapshot, datum: Vector3i) -> StringName:
	"""Original dry soil is necessary; retained geometry can still block the entire economic cut volume."""
	if not _spend(ROOM_TERRAIN_RUN_CHECKS):
		return REFUSE_MASK_BUDGET
	if not _write_cut_span(datum):
		return Orders.REFUSE_PLAN
	var code: StringName = _actual_provider().terrain_owner().dig_refusal(_clip)
	if code == &"":
		code = _retained_volume_refusal(snapshot.volumes, _clip, REFUSE_CUT)
	if code == &"":
		code = _retained_sites_refusal()
	if code == &"":
		code = _room_band_refusal(snapshot, _level.required_footing_low_u, _level.required_footing_high_u, REFUSE_FOOTING)
	if code == &"":
		code = _room_band_refusal(snapshot, _level.protected_above_low_u, _level.protected_above_high_u, REFUSE_ABOVE)
	return code


func _room_band_refusal(snapshot: Space.Snapshot, low: int, high: int, code: StringName) -> StringName:
	"""Local authored bands intersect only each exact painted run, never an unclaimed bounding-box hole."""
	for axis: int in 6:
		_clip[axis] = _cube[axis]
	_clip[1] = low
	_clip[4] = high
	var terrain_code: StringName = _actual_provider().terrain_owner().dig_refusal(_clip)
	return terrain_code if terrain_code != &"" else _retained_volume_refusal(snapshot.volumes, _clip, code)


func _retained_volume_refusal(volumes: Space.Volumes, box: PackedInt32Array, blocked: StringName) -> StringName:
	"""Metadata and unchanged dry matter grant no access; every other retained intersecting role blocks this virgin preflight."""
	for row: int in volumes.role.size():
		if not _spend(1):
			return REFUSE_MASK_BUDGET
		if volumes.role[row] == Space.FLOOR_DATUM or volumes.role[row] == Space.DRY_SOLID:
			continue
		if box[0] < volumes.hi_x[row] and volumes.lo_x[row] < box[3] \
				and box[1] < volumes.hi_y[row] and volumes.lo_y[row] < box[4] \
				and box[2] < volumes.hi_z[row] and volumes.lo_z[row] < box[5]:
			return blocked
	return &""


func _retained_sites_refusal() -> StringName:
	"""Old physical identities cannot become virgin yield; reusing/backfilling needs the later actual room cut-map companion."""
	for x: int in range(_clip[0], _clip[3], Space.QUANTUM_U):
		for y: int in range(_clip[1], _clip[4], Space.QUANTUM_U):
			for z: int in range(_clip[2], _clip[5], Space.QUANTUM_U):
				if not _spend(1):
					return REFUSE_MASK_BUDGET
				if _actual_sites().site_at(Vector3i(x, y, z)) != NULL_REF:
					return REFUSE_RETAINED
	return &""


func _write_room_box(left: int, near: int, right: int, far: int) -> bool:
	"""Transform in int64 and refuse overflow before packing any coordinate; never round the fine outline."""
	var low_x: int = int(_room_pin.origin_u.x) + left * _room_pin.cell_size_u
	var low_z: int = int(_room_pin.origin_u.z) + near * _room_pin.cell_size_u
	var high_x: int = int(_room_pin.origin_u.x) + right * _room_pin.cell_size_u
	var high_z: int = int(_room_pin.origin_u.z) + far * _room_pin.cell_size_u
	if not Space.int32(low_x) or not Space.int32(low_z) or not Space.int32(high_x) or not Space.int32(high_z):
		return false
	_cube[0] = low_x
	_cube[1] = _room_pin.origin_u.y
	_cube[2] = low_z
	_cube[3] = high_x
	_cube[4] = int(_room_pin.origin_u.y) + _room_pin.height_u
	_cube[5] = high_z
	return true


func _write_cut_span(datum: Vector3i) -> bool:
	"""Whole touched economic quanta are surveyed separately, with exact signed integer floor division."""
	for axis: int in 3:
		var low: int = _quantum_floor(_cube[axis], datum[axis])
		var high: int = _quantum_floor(int(_cube[axis + 3]) - 1, datum[axis]) + Space.QUANTUM_U
		if not Space.int32(low) or not Space.int32(high):
			return false
		_clip[axis] = low
		_clip[axis + 3] = high
	return true


static func _quantum_floor(value: int, datum: int) -> int:
	"""GDScript division truncates toward zero; negative remainders require one explicit floor step."""
	var delta: int = value - datum
	@warning_ignore("integer_division") var units: int = delta / Space.QUANTUM_U
	if delta < 0 and delta % Space.QUANTUM_U != 0:
		units -= 1
	return datum + units * Space.QUANTUM_U


func end_room_cold() -> void:
	"""Only the completed synchronous caller can release this exact request; nested cleanup owns nothing."""
	if _reading:
		return
	_drop_room_cold()


func _drop_room_cold() -> void:
	"""Drop copied plan before releasing our exact token; never release a newly acquired foreign lease."""
	_room_pin = null
	_room_request = null
	if _budget != null and _budget.covers(_room_token, Budget.COLD_BYTES):
		var released: StringName = _budget.release(_room_token)
		assert(released == &"", "exact room admission lease released once")
	_room_token = 0


func _actual_orders() -> Orders:
	"""Borrow only the once-bound actual Room authority; it owns all eventual Directory publication."""
	return _orders.get_ref() as Orders if _orders != null else null


func _actual_levels() -> Levels:
	"""The actual immutable level catalog remains strongly owned by the World composition, not this adapter."""
	return _levels.get_ref() as Levels if _levels != null else null


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
