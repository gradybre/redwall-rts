extends "res://scripts/core/haul_transfer_contract.gd"
## ADR1140: one synchronous actual delivery composer; Planner/Pool/Jobs retain every per-haul fact.

const Directory := preload("res://scripts/core/entity_directory.gd")
const Planner := preload("res://scripts/core/haul_planner.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Pool := preload("res://scripts/core/reservations.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const FinalFacts := preload("res://scripts/core/underground_final_facts.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const TransferContract := preload("res://scripts/core/haul_transfer_contract.gd")
const RESERVED_BYTES: int = 4096
const HELPER_BYTES: int = 1024
const NATIVE_RESERVE: int = 2048 # A declaration ceiling, not measured native allocation.
const REFUSE_BINDING: StringName = &"CONNECTOR_DELIVERY_BINDING"
const REFUSE_BUSY: StringName = &"CONNECTOR_DELIVERY_BUSY"
const REFUSE_JOB: StringName = &"CONNECTOR_DELIVERY_JOB"
const REFUSE_SOURCE: StringName = &"CONNECTOR_DELIVERY_SOURCE"
const REFUSE_ENDPOINT: StringName = &"CONNECTOR_DELIVERY_ENDPOINT"
const REFUSE_ARRIVAL: StringName = &"CONNECTOR_DELIVERY_NOT_ARRIVED"
const REFUSE_HANDLING: StringName = &"CONNECTOR_DELIVERY_HANDLING_SOURCE"
const REFUSE_BUDGET: StringName = &"CONNECTOR_DELIVERY_CHECKS"
const REFUSE_TRANSFER: StringName = &"CONNECTOR_DELIVERY_TRANSFER"

var _placements: Placements = null
var _frontier: Frontier = null
var _planner: Planner = null
var _provider: WorldRoutes = null
var _work: RefCounted = null
var _configured: bool = false
var _busy: bool = false
var _poisoned: bool = false
var _work_tick: bool = false
var _job: Vector2i = NULL_REF
var _worker: Vector2i = NULL_REF
var _project: Vector2i = NULL_REF
var _placement: Vector2i = NULL_REF
var _source_lot: Vector2i = NULL_REF
var _source_container: Vector2i = NULL_REF
var _destination: Vector2i = NULL_REF
var _source_location: Vector2i = NULL_REF
var _destination_location: Vector2i = NULL_REF
var _action: int = -1
var _quantity: int = 0
var _grams: int = 0
var _expiry: int = 0
var _geometry_revision: int = 0
var _frontier_revision: int = 0
var _location_receipt: int = 0
var _route_receipt: int = 0
var _job_remaining: int = 0
var _job_state: int = -1
var _claim_row: int = -1
var _checks: int = 0
var _order: Placements.OrderRecord = null
var _selection: Profiles.Selection = null
var _location: Locations.Record = null
var _box: Profiles.Box = null
var _number: IntMath.IntResult = null
var _frame: PackedInt32Array = PackedInt32Array()
var _install: PackedInt32Array = PackedInt32Array()
var _endpoint: PackedInt32Array = PackedInt32Array()
var _bounds: PackedInt32Array = PackedInt32Array()
var _support: PackedInt32Array = PackedInt32Array()
var _remaining: PackedInt32Array = PackedInt32Array()


func configure(placements: Placements, frontier: Frontier, planner: Planner,
		provider: WorldRoutes, work: RefCounted, reserved_bytes: int) -> StringName:
	"""Admit the complete fixed packet before allocation, then bind one concrete Work owner at initialization."""
	if _configured or _placements != null or reserved_bytes != RESERVED_BYTES or placements == null \
			or frontier == null or planner == null or provider == null or work == null:
		return REFUSE_BINDING
	_placements = placements
	_frontier = frontier
	_planner = planner
	_provider = provider
	_work = work
	var code: StringName = _binding_leaf(self)
	if code == &"": code = work.bind_spatial_delivery(self)
	if code != &"":
		_placements = null; _frontier = null; _planner = null; _provider = null; _work = null
		return code
	_allocate()
	_configured = true
	return &""


func _allocate() -> void:
	"""Allocate one bounded caller packet, never a per-Job bank or a second pooled Transfer."""
	_order = Placements.OrderRecord.new()
	_selection = Profiles.Selection.new()
	_location = Locations.Record.new()
	_box = Profiles.Box.new()
	_number = IntMath.IntResult.new()
	_frame.resize(9)
	_install.resize(9)
	_endpoint.resize(7)
	_bounds.resize(6)
	_support.resize(6)
	_remaining.resize(1)
	_location.envelope.resize(6)
	_location.support.resize(6)


static func _binding_leaf(a: RefCounted) -> StringName:
	"""Compare original concrete owners directly; equal handles in another World never compose."""
	if a._placements == null or a._frontier == null or a._planner == null or a._provider == null or a._work == null:
		return REFUSE_BINDING
	var p: Placements = a._placements
	if p._work != a._work or p._world_routes != a._provider or p._jobs != a._work._jobs \
			or a._planner._inventory != p._inventory or a._planner._reservations != p._reservations \
			or a._planner._residents != p._residents or a._planner._buildings != p._buildings \
			or a._planner._piles != p._piles or a._work._residents != p._residents \
			or p._reservations._bound_inventory == null or p._reservations._bound_inventory.get_ref() != p._inventory:
		return REFUSE_BINDING
	if a._frontier._catalog != p._catalog or a._frontier._assemblies != p._assemblies \
			or a._frontier._recipes != p._recipes or a._frontier._profiles != p._profiles:
		return REFUSE_BINDING
	return Frontier.source_leaf_refusal(a._frontier)


func _enter(cleanup_only: bool = false) -> StringName:
	"""A nested request poisons the original operation instead of replacing its retained tuple."""
	if _busy:
		_poisoned = true
		return REFUSE_BUSY
	if not _configured: return REFUSE_BINDING
	_busy = true
	_poisoned = false
	_checks = Space.MAX_CHECKS
	var code: StringName = _cleanup_binding(self) if cleanup_only else _binding_leaf(self)
	if code != &"": _clear(self)
	return code


static func _clear(a: RefCounted) -> void:
	"""Callback-free cleanup follows every outcome, including the irreversible transfer tail."""
	a._busy = false
	a._poisoned = false
	a._work_tick = false
	a._job = NULL_REF
	a._worker = NULL_REF
	a._project = NULL_REF
	a._placement = NULL_REF
	a._source_lot = NULL_REF
	a._source_container = NULL_REF
	a._destination = NULL_REF
	a._source_location = NULL_REF
	a._destination_location = NULL_REF
	a._action = -1
	a._quantity = 0
	a._grams = 0
	a._claim_row = -1


func _finish(code: StringName, result: Inventory.OpResult = null) -> Inventory.OpResult:
	"""Clear the synchronous packet; only the existing Inventory result carries any committed effect."""
	_clear(self)
	return result if result != null else Inventory.OpResult.new(false, code, NULL_REF, 0)


static func _spend(a: RefCounted, cost: int) -> bool:
	"""All repeated source, endpoint, Terrain and actor checks spend one cumulative bounded allowance."""
	if cost < 0 or a._checks < cost:
		a._checks = -1
		return false
	a._checks -= cost
	return true


static func handles_job(a: RefCounted, job: Vector2i) -> bool:
	"""The existing full Planner row identifies spatial handling without another map or admission flag."""
	if a == null or a._planner == null or job.x < 0 or job.x >= Planner.JOB_CAPACITY or job.y <= 0:
		return false
	return a._planner._job_generation[job.x] == job.y and a._planner._dest_slot[job.x] >= 0 \
		and a._planner._dest_tile[job.x] == Planner.NO_TILE


func _pin_job(job: Vector2i, action: int) -> StringName:
	"""Pin a real solo HAUL assignment and its Directory Project source; no foreign handle enters Jobs."""
	var row: int = _directory_row(job, Directory.KIND_JOB)
	if row < 0: return REFUSE_JOB
	var jobs: Jobs = _placements._jobs
	if jobs._job_present[row] != 1 or jobs._job_ref_slot[row] != job.x or jobs._job_ref_generation[row] != job.y \
			or jobs._kind[row] != Jobs.JOB_KIND_HAUL or jobs._is_coordinator[row] != 0 or jobs._coordinator_slot[row] != -1:
		return REFUSE_JOB
	_job = job
	_action = action
	_worker = Vector2i(jobs._worker_slot[row], jobs._worker_generation[row])
	_project = Vector2i(jobs._source_slot[row], jobs._source_generation[row])
	_job_remaining = jobs._remaining_mwu[row]
	_job_state = jobs._state[row]
	return _pin_project()


func _directory_row(ref: Vector2i, kind: int) -> int:
	"""Direct full Directory identity avoids copied-old/ref-reuse observations in final checks."""
	return _full_row(_placements._ids, ref, kind)


static func _full_row(ids: Directory, ref: Vector2i, kind: int) -> int:
	"""Resolve one actual active generation and kind without an overridable public reader."""
	if ids == null or ref.x < 0 or ref.x >= ids._active.size() or ref.y <= 0 \
			or ids._active[ref.x] != 1 or ids._generation[ref.x] != ref.y or ids._kind[ref.x] != kind:
		return -1
	var row: int = ids._typed_row[ref.x]
	return row if row >= 0 and row < Directory.KIND_CAPACITY[kind] \
		and ids._typed_owner_slot[ids._kind_base[kind] + row] == ref.x and ids._persistent_id[ref.x] > 0 else -1


func _pin_project() -> StringName:
	"""Only the current unpaid connector assembly may request its actual material container."""
	var row: int = _directory_row(_project, Directory.KIND_CONSTRUCTION)
	var construction: Construction = _placements._construction
	if row < 0 or construction._present[row] != 1 or construction._ref_slot[row] != _project.x \
			or construction._ref_generation[row] != _project.y or construction._purpose[row] != Construction.PURPOSE_CONNECTOR_INSTALL \
			or construction._phase[row] > Construction.PHASE_READY or construction._paused[row] != 0:
		return REFUSE_JOB
	_placement = Vector2i(construction._subject_slot[row], construction._subject_generation[row])
	_destination = Vector2i(construction._material_container_slot[row], construction._material_container_generation[row])
	var code: StringName = _placements.placement_into(_placement, _order)
	if code != &"" or _order.project != _project: return REFUSE_SOURCE
	_geometry_revision = _placements._space._header[17]
	_frontier_revision = _frontier._header[0]
	_location_receipt = _placements._locations._last_published_token
	_route_receipt = _placements._routes._last_published_token
	code = _placements.placement_frame_into(_placement, _frame)
	if code == &"": code = _frontier.installation_into(_order.installed_count, _install)
	return code if code != &"" else _pin_material()


func _pin_material() -> StringName:
	"""The selected Inventory endpoint must match the immutable assembly material selector exactly."""
	if _frame.size() != 9 or _install.size() != 9: return REFUSE_SOURCE
	var code: StringName = _frontier.endpoint_into(_install[7], _endpoint)
	if code != &"" or _endpoint.size() != 7 or _endpoint[3] != Locations.ROLE_STORAGE:
		return REFUSE_ENDPOINT
	_destination_location = _placements._inventory.spatial_location_of(_destination)
	code = _placements._locations.read_location_into(_destination_location, _location)
	return code if code != &"" else _material_leaf(self)


static func _coordinate(frame: PackedInt32Array, x: int, y: int, z: int, axis: int) -> int:
	"""Apply the adopted integer quarter-turn convention in the original Placement frame."""
	if axis == 1: return int(frame[1]) + y
	var rotated: int = x if axis == 0 else z
	match frame[3]:
		1: rotated = -z if axis == 0 else x
		2: rotated = -x if axis == 0 else -z
		3: rotated = z if axis == 0 else -x
	return int(frame[axis]) + rotated


static func _material_leaf(a: RefCounted) -> StringName:
	"""Exact point/role/Room/section and already-paid prefix are required; no selector creates support."""
	var locations: Locations = a._placements._locations
	if not locations._live_ref(locations._live, a._destination_location): return REFUSE_ENDPOINT
	var row: int = a._destination_location.x
	if locations._get32(locations._live, Locations.ROLE, row) != Locations.ROLE_STORAGE:
		return REFUSE_ENDPOINT
	for axis: int in 3:
		var point: int = _coordinate(a._frame, a._endpoint[4], a._endpoint[5], a._endpoint[6], axis)
		if not Space.int32(point) or locations._get32(locations._live, Locations.X + axis, row) != point:
			return REFUSE_ENDPOINT
	var section: Vector2i = locations._ref_at(locations._live, Locations.SECTION_SLOT, row)
	if a._endpoint[0] == Frontier.SURFACE_ANCHOR or a._endpoint[0] == Frontier.SURFACE_CONTACT:
		var anchor: Vector2i = Vector2i(a._frame[7], a._frame[8])
		if not locations._live_ref(locations._live, anchor) \
				or locations._ref_at(locations._live, Locations.ROOM_SLOT, row) != NULL_REF \
				or locations._ref_at(locations._live, Locations.SECTION_SLOT, anchor.x) != section:
			return REFUSE_ENDPOINT
		return &"" if a._endpoint[0] != Frontier.SURFACE_ANCHOR or a._destination_location == anchor else REFUSE_ENDPOINT
	if a._endpoint[0] != Frontier.INSTALLED_CONTACT or a._endpoint[1] < 0 \
			or a._endpoint[1] >= a._order.installed_count \
			or locations._ref_at(locations._live, Locations.ROOM_SLOT, row) != a._order.corridor:
		return REFUSE_ENDPOINT
	return _installed_material_leaf(a, section)


static func _installed_material_leaf(a: RefCounted, section: Vector2i) -> StringName:
	"""An installed selector must name the exact current Catalog LANDING, not another same-height floor."""
	var catalog: Catalog = a._placements._catalog
	var ordinal: int = a._endpoint[2]
	var variant: int = a._order.catalog_row
	if ordinal < 0 or ordinal >= catalog._v(catalog._live, variant, Catalog.V_REGION_COUNT):
		return REFUSE_ENDPOINT
	var at: int = catalog._v(catalog._live, variant, Catalog.V_REGION_START) + ordinal
	if catalog._live.regions[6 * Catalog.MAX_REGIONS + at] != Space.LANDING: return REFUSE_ENDPOINT
	var owner: Owner = a._placements._space
	if not owner._region_live(section, false): return REFUSE_ENDPOINT
	for axis: int in 6: a._support[axis] = catalog._live.regions[axis * Catalog.MAX_REGIONS + at]
	for axis: int in 3:
		var first: int = _coordinate(a._frame, a._support[0], a._support[1], a._support[2], axis)
		var last: int = _coordinate(a._frame, a._support[3], a._support[4], a._support[5], axis)
		a._bounds[axis] = mini(first, last)
		a._bounds[axis + 3] = maxi(first, last)
	return &"" if owner._r_owner_slot[section.x] == a._order.corridor.x \
		and owner._r_owner_generation[section.x] == a._order.corridor.y \
		and owner._r_role[section.x] == Space.FLOOR_DATUM and owner._r_lo_x[section.x] == a._bounds[0] \
		and owner._r_lo_y[section.x] == a._bounds[1] and owner._r_lo_z[section.x] == a._bounds[2] \
		and owner._r_hi_x[section.x] == a._bounds[3] and owner._r_hi_z[section.x] == a._bounds[5] \
		and owner._r_level[section.x] == a._frame[4] + catalog._live.regions[7 * Catalog.MAX_REGIONS + at] else REFUSE_ENDPOINT


func admit(job: Vector2i, source_lot: Vector2i, requested_milli: int, expiry_tick: int) -> Inventory.OpResult:
	"""Create one actual spatial haul admission; a route reservation never moves or delivers any goods."""
	var code: StringName = _enter()
	if code != &"": return Inventory.OpResult.new(false, code, NULL_REF, 0)
	code = _pin_job(job, ADMIT)
	_source_lot = source_lot
	_expiry = expiry_tick
	if code == &"": code = _size_admission(requested_milli)
	if code == &"": code = _pin_origin()
	if code == &"": code = _observe_admission()
	if code != &"": return _finish(code)
	var result: Inventory.OpResult = _planner.admit_spatial(job, _directory_row(_worker, Directory.KIND_RESIDENT),
		source_lot, _quantity, expiry_tick, _destination, self)
	return _finish(result.error, result)


func _size_admission(requested: int) -> StringName:
	"""Use the adopted real carry limit and item mass; partial ordinary shipments are valid."""
	var inventory: Inventory = _placements._inventory
	var worker_row: int = _directory_row(_worker, Directory.KIND_RESIDENT)
	if worker_row < 0 or not inventory.is_lot_valid(_source_lot) or inventory.is_lot_equipped(_source_lot) \
			or requested <= 0 or _job_state < Jobs.JOB_STATE_QUEUED or _job_state > Jobs.JOB_STATE_TRAVEL \
			or _job_remaining != Planner.HAUL_LOAD_MILLI_WU or handles_job(self, _job): return REFUSE_JOB
	if not _placements._carry.carry_limit_g_into(worker_row, _number): return REFUSE_TRANSFER
	var mass: int = inventory.item_mass_g(inventory.lot_item_id(_source_lot))
	if not Planner.payload_milli_into(mini(requested, inventory.lot_available_milli(_source_lot)), mass,
		_number.value, 0, _number) or _number.value <= 0: return REFUSE_TRANSFER
	_quantity = _number.value
	if not IntMath.inventory_capacity_debit_g_into(_quantity, mass, _number): return REFUSE_TRANSFER
	_grams = _number.value
	return &""


func _pin_origin() -> StringName:
	"""Observe the actual source container; carried goods retain their original full satchel identity."""
	var inventory: Inventory = _placements._inventory
	_source_container = inventory.lot_container(_source_lot)
	if _action == UNLOAD or _action == REPOST:
		_source_location = _destination_location
		return &"" if _source_container == _placements._residents.satchel_of(_directory_row(_worker, Directory.KIND_RESIDENT)) \
			and inventory.is_satchel(_source_container) else REFUSE_TRANSFER
	_source_location = inventory.spatial_location_of(_source_container)
	if _source_location == NULL_REF or _source_container == _destination: return REFUSE_ENDPOINT
	return _placements._locations.read_location_into(_source_location, _location)


func _pin_claim(purpose: int) -> StringName:
	"""Read the existing unique full Job claim chain; no caller quantity or second claim record is retained."""
	if not handles_job(self, _job): return REFUSE_JOB
	var pool: Pool = _placements._reservations
	_claim_row = pool._job_head[_job.x]
	if _claim_row < 0 or _claim_row >= pool._row_capacity or pool._occupied[_claim_row] != 1 \
			or pool._job_next[_claim_row] != -1 or pool._r_job_slot[_claim_row] != _job.x \
			or pool._r_job_generation[_claim_row] != _job.y or pool._r_purpose[_claim_row] != purpose:
		return REFUSE_TRANSFER
	_source_lot = Vector2i(pool._r_lot_slot[_claim_row], pool._r_lot_generation[_claim_row])
	_quantity = pool._r_quantity_milli[_claim_row]
	_expiry = pool._r_expiry[_claim_row]
	_grams = _planner._reserved_g[_job.x]
	if _quantity <= 0 or _grams < 0 or _planner._dest_slot[_job.x] != _destination.x \
			or _planner._dest_generation[_job.x] != _destination.y: return REFUSE_TRANSFER
	return _pin_origin()


func begin_load(job: Vector2i) -> StringName:
	"""Only an arrived, source-qualified HAUL handling actor enters WORK; this changes no progress or goods."""
	var code: StringName = _enter()
	if code != &"": return code
	code = _pin_job(job, LOAD)
	if code == &"": code = _pin_claim(Pool.PURPOSE_HAUL_SOURCE)
	if code == &"" and (_job_state != Jobs.JOB_STATE_TRAVEL or _job_remaining != Planner.HAUL_LOAD_MILLI_WU):
		code = REFUSE_JOB
	if code == &"": code = _observe_handling()
	if code == &"": code = _operation_leaf(self, null)
	if code == &"": _placements._jobs._state[_directory_row(job, Directory.KIND_JOB)] = Jobs.JOB_STATE_WORK
	_clear(self)
	return code


func load_payload(job: Vector2i) -> Inventory.OpResult:
	"""Completed load work moves the real claimed lot into a real satchel through the guarded Inventory owner."""
	return _transfer(job, LOAD)


func unload_payload(job: Vector2i) -> Inventory.OpResult:
	"""Completed HAUL_OUTPUT handling commits the real payload once; a refused transfer earns no extra work."""
	return _transfer(job, UNLOAD)


func _transfer(job: Vector2i, action: int) -> Inventory.OpResult:
	"""Pin the complete original tuple before staging and keep it through the pure successful tail."""
	var code: StringName = _enter()
	if code != &"": return Inventory.OpResult.new(false, code, NULL_REF, 0)
	code = _pin_job(job, action)
	if code == &"": code = _pin_claim(Pool.PURPOSE_HAUL_SOURCE if action == LOAD else Pool.PURPOSE_HAUL_DESTINATION)
	if code == &"" and (_job_remaining != 0 or _job_state != (Jobs.JOB_STATE_WORK if action == LOAD else Jobs.JOB_STATE_HAUL_OUTPUT)):
		code = REFUSE_JOB
	if code == &"": code = _observe_handling()
	if code != &"": return _finish(code)
	var row: int = _directory_row(_worker, Directory.KIND_RESIDENT)
	if not _placements._carry.carry_limit_g_into(row, _number): return _finish(REFUSE_TRANSFER)
	var result: Inventory.OpResult = _placements._reservations.transfer_haul_guarded(action, job, _worker,
		_source_lot, _destination, _selection.satchel, _grams, _number.value, self, _placements._inventory)
	if result.ok: _publish_transfer(self, result)
	return _finish(result.error, result)


func cancel(job: Vector2i) -> Inventory.OpResult:
	"""Release only original claims and Planner grams; carried goods survive a retired Project or released worker."""
	var code: StringName = _enter(true)
	if code != &"": return Inventory.OpResult.new(false, code, NULL_REF, 0)
	if not handles_job(self, job): return _finish(REFUSE_JOB)
	_job = job
	_action = CANCEL
	_destination = Vector2i(_planner._dest_slot[job.x], _planner._dest_generation[job.x])
	_grams = _planner._reserved_g[job.x]
	var result: Inventory.OpResult = _placements._reservations.transfer_haul_guarded(CANCEL, job, NULL_REF,
		NULL_REF, _destination, NULL_REF, _grams, 0, self, _placements._inventory)
	if result.ok: _publish_cancel(self)
	return _finish(result.error, result)


static func _publish_transfer(a: RefCounted, result: Inventory.OpResult) -> void:
	"""No public Inventory/Resident/Planner setter runs after commit; the original full rows were proved first."""
	var resident: int = a._placements._ids._typed_row[a._worker.x]
	var job: int = a._placements._ids._typed_row[a._job.x]
	var inventory: Inventory = a._placements._inventory
	var satchel: Vector2i = NULL_REF
	if a._action == LOAD or a._action == REPOST:
		satchel = Vector2i(inventory._l_container_slot[result.ref.x], inventory._l_container_generation[result.ref.x])
		a._placements._jobs._state[job] = Jobs.JOB_STATE_HAUL_OUTPUT
		a._placements._jobs._remaining_mwu[job] = Planner.HAUL_UNLOAD_MILLI_WU
	else:
		_clear_planner(a._planner, a._job)
		a._placements._jobs._state[job] = Jobs.JOB_STATE_COMPLETE
	a._placements._residents._equip_satchel_slot[resident] = satchel.x
	a._placements._residents._equip_satchel_generation[resident] = satchel.y


static func _clear_planner(planner: Planner, job: Vector2i) -> void:
	"""Release no resource here: the same guarded journal already released every claim and exact gram."""
	planner._job_generation[job.x] = 0
	planner._dest_slot[job.x] = -1
	planner._dest_generation[job.x] = 0
	planner._dest_tile[job.x] = Planner.NO_TILE
	planner._reserved_g[job.x] = 0


static func _publish_cancel(a: RefCounted) -> void:
	"""A stale Job needs no phase write; full live Jobs end without requiring a productive assignment."""
	_clear_planner(a._planner, a._job)
	var row: int = _full_row(a._placements._ids, a._job, Directory.KIND_JOB)
	if row >= 0 and a._placements._jobs._job_present[row] == 1 \
			and a._placements._jobs._job_ref_slot[row] == a._job.x \
			and a._placements._jobs._job_ref_generation[row] == a._job.y:
		a._placements._jobs._state[row] = Jobs.JOB_STATE_CANCELLED


func _observe_admission() -> StringName:
	"""Observe the real actor and both endpoint owners; reachability reserves no arrival or delivered quantity."""
	var graph: Routes = _placements._routes
	var row: int = _directory_row(_worker, Directory.KIND_RESIDENT)
	if row < 0 or not _spend(self, 8192): return REFUSE_JOB
	var code: StringName = graph._current_profile_into(row, _selection)
	if code == &"" and _selection.mode != Profiles.MODE_WALK and _selection.mode != Profiles.MODE_STAND:
		code = REFUSE_HANDLING
	if code == &"": code = _placements._locations.read_location_into(graph._resident_pair(Routes.R_LOCATION_SLOT, row), _location)
	if code == &"": code = _provider._terrain.binding_refusal()
	if code == &"": code = _reach(graph._resident_pair(Routes.R_LOCATION_SLOT, row), _source_location)
	if code == &"": code = _reach(_source_location, _destination_location)
	return code if code != &"" else _operation_leaf(self, null)


func _reach(first: Vector2i, last: Vector2i) -> StringName:
	"""Borrow the actual graph's finite search; no path image, destination map or movement permission is retained."""
	var code: StringName = WorldRoutes.profile_reachability_refusal(_provider, first, last,
		_selection.profile_id, _selection.profile_revision, _selection.content_revision, _checks, _remaining)
	if code == &"": _checks = _remaining[0]
	return code


func _observe_handling() -> StringName:
	"""All ordinary source/pose/endpoint observations precede the direct final worker and space proof."""
	var row: int = _directory_row(_worker, Directory.KIND_RESIDENT)
	if row < 0 or not _spend(self, 8192): return REFUSE_JOB
	var code: StringName = _placements._routes._current_profile_into(row, _selection)
	if code == &"": code = _handling_profile_leaf(self)
	var endpoint: Vector2i = _destination_location if _action == UNLOAD else _source_location
	if code == &"": code = _placements._locations.read_location_into(endpoint, _location)
	if code == &"": code = _provider._terrain.binding_refusal()
	return code if code != &"" else _operation_leaf(self, null)


static func _handling_profile_leaf(a: RefCounted) -> StringName:
	"""A selected no-tool HAUL work program must declare the complete entry/work/recovery and contact roles."""
	var profiles: Profiles = a._placements._profiles
	var selected: Profiles.Selection = a._selection
	var profile: int = selected.profile_id
	if profile < 0 or profile >= profiles._live.header[1] or selected.mode != Profiles.MODE_WORK \
			or selected.tool != NULL_REF or profiles._field(profiles._live, profile, Profiles.F_WORK_KIND) != Jobs.JOB_KIND_HAUL \
			or profiles._field(profiles._live, profile, Profiles.F_CONTACT_KIND) != Profiles.CONTACT_ANCHOR_AND_PATCH:
		return REFUSE_HANDLING
	var states: int = Profiles.STATE_WORK | Profiles.STATE_ENTRY | Profiles.STATE_REVERSAL | Profiles.STATE_RECOVERY
	return &"" if (profiles._field(profiles._live, profile, Profiles.F_STATES) & states) == states else REFUSE_HANDLING


static func _cleanup_binding(a: RefCounted) -> StringName:
	"""Claim cleanup remains possible after Project/source retirement; only the original economic owners matter."""
	if a._placements == null or a._planner == null or a._work == null \
			or a._planner._inventory != a._placements._inventory \
			or a._planner._reservations != a._placements._reservations \
			or a._planner._residents != a._placements._residents or a._work._jobs != a._placements._jobs:
		return REFUSE_BINDING
	var pool: Pool = a._placements._reservations
	return &"" if pool._bound_inventory != null and pool._bound_inventory.get_ref() == a._planner._inventory else REFUSE_BINDING


static func _operation_leaf(a: RefCounted, transfer: Transfer = null) -> StringName:
	"""One concrete final proof closes every observer before work credit or the guarded Inventory commit."""
	if not a._busy or a._poisoned: return REFUSE_BUSY
	if a._checks < 0: return REFUSE_BUDGET
	if a._action == CANCEL: return _cancel_leaf(a, transfer)
	var code: StringName = _binding_leaf(a)
	if code == &"": code = _source_leaf(a)
	if code == &"": code = _job_leaf(a)
	if code == &"": code = _endpoint_leaf(a, a._destination, a._destination_location)
	if code == &"" and a._action != UNLOAD and a._action != REPOST:
		code = _endpoint_leaf(a, a._source_container, a._source_location)
	if code == &"": code = _material_leaf(a)
	if code == &"": code = _worker_leaf(a, transfer)
	if code == &"": code = _scene_leaf(a)
	if code == &"": code = _roles_leaf(a)
	if code == &"": code = _occupants_leaf(a)
	return code


static func _source_leaf(a: RefCounted) -> StringName:
	"""A full original Placement/source/prefix and all live graph receipts must survive every callback."""
	var p: Placements = a._placements
	if not _spend(a, 512) or p._busy or not p._ready or not p._is_live(p._live, a._placement): return REFUSE_SOURCE
	if p._space._header[17] != a._geometry_revision or a._frontier._header[0] != a._frontier_revision \
			or p._locations._last_published_token != a._location_receipt or p._routes._last_published_token != a._route_receipt \
			or p._pair(p._live, Placements.PROJECT_SLOT, a._placement.x) != a._project \
			or p._pair(p._live, Placements.ROOM_SLOT, a._placement.x) != a._order.corridor \
			or p._get64(p._live, Placements.PAYLOAD_REVISION, a._placement.x) != a._order.payload_revision \
			or p._get32(p._live, Placements.CATALOG_ROW, a._placement.x) != a._order.catalog_row \
			or p._get32(p._live, Placements.INSTALLED, a._placement.x) != a._order.installed_count:
		return REFUSE_SOURCE
	if p._live.header[Placements.H_CATALOG_REV] != a._order.catalog_revision \
			or p._live.header[Placements.H_VARIANT_REV] != a._order.variant_revision \
			or p._live.header[Placements.H_GROUP_REV] != a._order.grouping_revision \
			or p._live.header[Placements.H_RECIPE_REV] != a._order.recipe_revision: return REFUSE_SOURCE
	for axis: int in 3:
		if p._get32(p._live, Placements.X + axis, a._placement.x) != a._frame[axis]: return REFUSE_SOURCE
	if p._get32(p._live, Placements.ROTATION, a._placement.x) != a._frame[3] \
			or p._get32(p._live, Placements.LEVEL, a._placement.x) != a._frame[4] \
			or p._pair(p._live, Placements.SECTION_SLOT, a._placement.x) != Vector2i(a._frame[5], a._frame[6]) \
			or p._pair(p._live, Placements.ANCHOR_SLOT, a._placement.x) != Vector2i(a._frame[7], a._frame[8]): return REFUSE_SOURCE
	return &""


static func _job_leaf(a: RefCounted) -> StringName:
	"""The full assigned HAUL Job and current unpaid assembly must still name the captured actual worker/store."""
	var ids: Directory = a._placements._ids
	var jobs: Jobs = a._placements._jobs
	var row: int = _full_row(ids, a._job, Directory.KIND_JOB)
	var worker: int = _full_row(ids, a._worker, Directory.KIND_RESIDENT)
	if row < 0 or worker < 0 or jobs._job_present[row] != 1 or jobs._job_ref_slot[row] != a._job.x \
			or jobs._job_ref_generation[row] != a._job.y or jobs._kind[row] != Jobs.JOB_KIND_HAUL \
			or jobs._worker_slot[row] != a._worker.x or jobs._worker_generation[row] != a._worker.y \
			or jobs._source_slot[row] != a._project.x or jobs._source_generation[row] != a._project.y \
			or jobs._state[row] != a._job_state or jobs._remaining_mwu[row] != a._job_remaining \
			or jobs._is_coordinator[row] != 0 or jobs._coordinator_slot[row] != -1 \
			or jobs._tool_gate[row] != Jobs.GATE_NOT_REQUIRED or jobs._agent_present[worker] != 1 \
			or jobs._agent_persistent_id[worker] != ids._persistent_id[a._worker.x] \
			or jobs._agent_job_slot[worker] != a._job.x or jobs._agent_job_generation[worker] != a._job.y: return REFUSE_JOB
	row = _full_row(ids, a._project, Directory.KIND_CONSTRUCTION)
	var c: Construction = a._placements._construction
	return &"" if row >= 0 and c._present[row] == 1 and c._ref_slot[row] == a._project.x \
		and c._ref_generation[row] == a._project.y and c._purpose[row] == Construction.PURPOSE_CONNECTOR_INSTALL \
		and c._phase[row] <= Construction.PHASE_READY and c._paused[row] == 0 \
		and Vector2i(c._subject_slot[row], c._subject_generation[row]) == a._placement \
		and Vector2i(c._material_container_slot[row], c._material_container_generation[row]) == a._destination else REFUSE_JOB


static func _endpoint_leaf(a: RefCounted, container: Vector2i, endpoint: Vector2i) -> StringName:
	"""Read exact Inventory spatial columns and actual Location generation/revision without provider callbacks."""
	var inventory: Inventory = a._placements._inventory
	var locations: Locations = a._placements._locations
	if not TransferContract.container_live(inventory, container) or not locations._live_ref(locations._live, endpoint) \
			or inventory._spatial_world != a._order.world or inventory._spatial_authority == null: return REFUSE_ENDPOINT
	var provider: Locations.InventoryLocations = inventory._spatial_authority.get_ref() as Locations.InventoryLocations
	if provider == null or provider._locations == null or provider._locations.get_ref() != locations: return REFUSE_ENDPOINT
	var row: int = -2 - inventory._c_anchor_tile[container.x]
	if row < 0 or row >= Inventory.SPATIAL_ENDPOINT_CAPACITY \
			or inventory._spatial_container_slot[row] != container.x or inventory._spatial_container_generation[row] != container.y \
			or inventory._spatial_location_slot[row] != endpoint.x or inventory._spatial_location_generation[row] != endpoint.y \
			or inventory._spatial_location_revision[row] != locations._get64(locations._live, Locations.PAYLOAD_REVISION, endpoint.x):
		return REFUSE_ENDPOINT
	return &"" if Vector2i(inventory._c_owner_slot[container.x], inventory._c_owner_generation[container.x]) == a._order.world \
		and inventory._c_reachable[container.x] == 1 and inventory._c_max_mass_g[container.x] == Inventory.GROUND_PILE_MAX_MASS_G \
		and inventory._c_filters[container.x] == Inventory.FILTERS_ACCEPT_ALL \
		and (inventory._c_policy[container.x] == Inventory.UNSET_POLICY or inventory._c_policy[container.x] == Inventory.POLICY_GROUND_PILE) \
		and locations._get32(locations._live, Locations.ROLE, endpoint.x) == Locations.ROLE_STORAGE else REFUSE_ENDPOINT


static func _worker_leaf(a: RefCounted, transfer: Transfer) -> StringName:
	"""Prove current full actor/pose/profile with the original cargo or the exact in-journal cargo transition."""
	var graph: Routes = a._placements._routes
	var row: int = _full_row(a._placements._ids, a._worker, Directory.KIND_RESIDENT)
	if row < 0 or not _spend(a, 1024): return REFUSE_JOB
	var code: StringName = _staged_worker_leaf(a, transfer) if transfer != null else \
		Routes.turn_selection_into(graph, row, graph._checked_selection)
	if code != &"": return code
	if transfer == null and not Routes._same_selection(a._selection, graph._checked_selection): return REFUSE_HANDLING
	if graph._resident_ref(row) != a._worker or graph._resident_pair(Routes.R_JOB_SLOT, row) != a._job \
			or graph._motion.resident[Routes.R_PHASE * Routes.RESIDENT_CAPACITY + row] != Routes.PHASE_IDLE \
			or graph._resident_pair(Routes.R_EDGE_SLOT, row) != NULL_REF \
			or graph._motion.resident[Routes.R_HEAD * Routes.RESIDENT_CAPACITY + row] >= 0: return REFUSE_ARRIVAL
	var endpoint: Vector2i = graph._resident_pair(Routes.R_LOCATION_SLOT, row)
	if a._action != ADMIT and endpoint != (a._destination_location if a._action == UNLOAD else a._source_location):
		return REFUSE_ARRIVAL
	if not FinalFacts.record_matches(a._placements._locations, endpoint, a._location, a._placements._space) \
			or a._location.point != Vector3i(a._selection.x, a._selection.y, a._selection.z): return REFUSE_ARRIVAL
	return &""


static func _staged_worker_leaf(a: RefCounted, transfer: Transfer) -> StringName:
	"""Resident still names the original satchel until commit; never query ordinary cargo against staged Inventory."""
	var graph: Routes = a._placements._routes
	var code: StringName = Routes._turn_identity_leaf(graph, a._worker)
	if code != &"": return code
	var profiles: Profiles = a._placements._profiles
	var row: int = profiles._worker_row
	var selected: Profiles.Selection = a._selection
	if selected.worker != a._worker or selected.job != a._job or selected.tool != NULL_REF \
			or profiles._identity[0] != selected.species or profiles._identity[1] != selected.life_stage \
			or profiles._identity[2] != selected.rig or profiles._pose.x != selected.x or profiles._pose.y != selected.y \
			or profiles._pose.z != selected.z or profiles._pose.yaw != selected.yaw \
			or a._placements._residents._equip_tool_item_id[row] != Residents.NO_TOOL_ITEM \
			or a._work._tool_lot_slot[row] != -1 or not graph._committed_selection(row, selected): return REFUSE_HANDLING
	if Vector2i(a._placements._residents._equip_satchel_slot[row], a._placements._residents._equip_satchel_generation[row]) \
			!= selected.satchel: return REFUSE_TRANSFER
	if transfer.action == LOAD and (selected.satchel != NULL_REF or selected.cargo != NULL_REF): return REFUSE_TRANSFER
	if transfer.action == UNLOAD or transfer.action == REPOST:
		if selected.satchel != transfer.original_satchel or selected.cargo != transfer.source_lot \
				or selected.cargo_quantity_milli != transfer.source_quantity_milli: return REFUSE_TRANSFER
	return _selected_profile_leaf(a)


static func _selected_profile_leaf(a: RefCounted) -> StringName:
	"""Monotonic content plus exact immutable row/revision and original actor selection pins every source primitive."""
	var profiles: Profiles = a._placements._profiles
	var selected: Profiles.Selection = a._selection
	var row: int = selected.profile_id
	if profiles._loading or row < 0 or row >= profiles._live.header[1] \
			or profiles._live.header[0] != selected.content_revision or profiles._live.flags[row] != Profiles.CERT_REQUIRED \
			or profiles._long(profiles._live, row, Profiles.L_REVISION) != selected.profile_revision \
			or profiles._field(profiles._live, row, Profiles.F_SOURCE) != selected.source_id \
			or profiles._field(profiles._live, row, Profiles.F_MODE) != selected.mode \
			or profiles._field(profiles._live, row, Profiles.F_BOX_COUNT) != selected.box_count: return REFUSE_HANDLING
	return _handling_profile_leaf(a) if a._action != ADMIT else &""


static func _scene_leaf(a: RefCounted) -> StringName:
	"""Current Terrain and complete actual retained sources close late unchanged-receipt mutations."""
	var p: Placements = a._placements
	var code: StringName = WorldRoutes._reach_stores_refusal(a._provider, p._routes, p._space, p._locations)
	if code != &"": return code
	var checks: int = FinalFacts._required_checks(p._space)
	if not _spend(a, checks): return REFUSE_BUDGET
	code = FinalFacts.snapshot_refusal(p._space, p._routes, p._locations, a._geometry_revision, checks)
	return a._provider._terrain._leaf_binding_refusal(a._geometry_revision) if code == &"" else code


static func _roles_leaf(a: RefCounted) -> StringName:
	"""Retain every source body/approach/stroke/recovery primitive and its exact stance; nothing is clipped away."""
	var roles: int = 0
	for ordinal: int in a._selection.box_count:
		if not _spend(a, 4096): return REFUSE_BUDGET
		var code: StringName = WorldRoutes._turn_box_into(a._placements._profiles, a._selection, ordinal, a._box)
		if code == &"": code = _box_bounds(a, a._selection, a._bounds)
		if code != &"": return code
		roles |= 1 << a._box.role
		if a._box.role == Profiles.CONTACT_POINT or a._box.role == Profiles.CONTACT_PATCH:
			if not _contact_contains_endpoint(a): return REFUSE_HANDLING
			continue
		code = a._provider._terrain._local_tiles_refusal(a._bounds, Terrain.EXCLUSIONS)
		if code != &"": return code
		if a._box.role == Profiles.STANCE_SUPPORT:
			if not Space.contains_box(a._location.support, a._bounds): return REFUSE_HANDLING
		elif not _body_contained(a): return REFUSE_HANDLING
	var required: int = 7 if a._action == ADMIT else 127
	return &"" if (roles & required) == required else REFUSE_HANDLING


static func _box_bounds(a: RefCounted, selected: Profiles.Selection, out: PackedInt32Array) -> StringName:
	"""Immutable boxes are already oriented; only exact integer root translation is applied."""
	for axis: int in 3:
		var root: int = selected.x if axis == 0 else (selected.y if axis == 1 else selected.z)
		var low: int = int(a._box.low[axis]) + root
		var high: int = int(a._box.high[axis]) + root
		if not Space.int32(low) or not Space.int32(high) or low > high: return REFUSE_HANDLING
		out[axis] = low
		out[axis + 3] = high
	return &""


static func _contact_contains_endpoint(a: RefCounted) -> bool:
	"""Handling contact names this Inventory service point, independently from any connector fastening target."""
	for axis: int in 3:
		if a._location.point[axis] < a._bounds[axis] or a._location.point[axis] > a._bounds[axis + 3]: return false
	return true


static func _body_contained(a: RefCounted) -> bool:
	"""Both sides of the real floor remain proved; below-plane body needs actual support and a full stance primitive."""
	var floor_y: int = a._location.envelope[1]
	for axis: int in 6: a._support[axis] = a._bounds[axis]
	if a._bounds[4] > floor_y:
		a._support[1] = maxi(a._bounds[1], floor_y)
		if not Space.contains_box(a._location.envelope, a._support): return false
	if a._bounds[1] >= floor_y: return true
	a._support[1] = a._bounds[1]
	a._support[4] = mini(a._bounds[4], floor_y)
	if not Space.contains_box(a._location.support, a._support): return false
	for ordinal: int in a._selection.box_count:
		if WorldRoutes._turn_box_into(a._placements._profiles, a._selection, ordinal, a._box) != &"": return false
		if a._box.role != Profiles.STANCE_SUPPORT: continue
		var fits: bool = true
		for axis: int in 3:
			var root: int = a._selection.x if axis == 0 else (a._selection.y if axis == 1 else a._selection.z)
			if int(a._box.low[axis]) + root > a._support[axis] or int(a._box.high[axis]) + root < a._support[axis + 3]: fits = false
		if fits: return true
	return false


static func _occupants_leaf(a: RefCounted) -> StringName:
	"""Every other living Resident needs a current actual physical registration; unregistered bodies are never empty air."""
	var graph: Routes = a._placements._routes
	if not _spend(a, 16 * Routes.RESIDENT_CAPACITY): return REFUSE_BUDGET
	var worker_row: int = _full_row(a._placements._ids, a._worker, Directory.KIND_RESIDENT)
	for row: int in Routes.RESIDENT_CAPACITY:
		if row == worker_row: continue
		if graph._resident_ref(row) == NULL_REF:
			var missing: StringName = WorldRoutes._turn_unregistered_refusal(graph, row)
			if missing != &"": return missing
			continue
		if not _spend(a, 512): return REFUSE_BUDGET
		var code: StringName = Routes.physical_selection_into(graph, row, graph._occupant_selection)
		if code == &"": code = FinalFacts._resident_into(graph, a._placements._locations, graph._resident_ref(row), a._placements._space._facts)
		if code == &"": code = _occupied_boxes(a, graph._occupant_selection)
		if code != &"": return code
	return &""


static func _occupied_boxes(a: RefCounted, other: Profiles.Selection) -> StringName:
	"""Check full handling motion against every current occupied body, using borrowed existing route scratch only."""
	if not _spend(a, 64 * a._selection.box_count * other.box_count): return REFUSE_BUDGET
	for first: int in a._selection.box_count:
		var code: StringName = WorldRoutes._turn_box_into(a._placements._profiles, a._selection, first, a._box)
		if code != &"": return code
		if a._box.role == Profiles.STANCE_SUPPORT or a._box.role >= Profiles.CONTACT_POINT: continue
		code = _box_bounds(a, a._selection, a._bounds)
		if code != &"": return code
		for second: int in other.box_count:
			code = WorldRoutes._turn_box_into(a._placements._profiles, other, second, a._box)
			if code != &"": return code
			if a._box.role != Profiles.BODY_HELD_LOAD and a._box.role != Profiles.TURN_RECOVERY: continue
			code = _box_bounds(a, other, a._support)
			if code != &"": return code
			if Space.overlaps(a._bounds, a._support): return &"ROUTE_OCCUPIED"
	return &""


func final_transfer_refusal(transfer: Transfer, inventory: RefCounted, pool: RefCounted) -> StringName:
	"""The actual Inventory-owned barrier keeps the journal open while this last concrete spatial leaf executes."""
	if inventory != _placements._inventory or pool != _placements._reservations or not inventory._attesting:
		return REFUSE_TRANSFER
	var code: StringName = TransferContract.scope_refusal(inventory, pool, self, transfer)
	if code == &"": code = _transfer_tuple_leaf(self, transfer)
	return _operation_leaf(self, transfer) if code == &"" else code


static func _transfer_tuple_leaf(a: RefCounted, transfer: Transfer) -> StringName:
	"""The pooled packet cannot be repurposed for another full Job, payload, Planner store or action."""
	if transfer.action != a._action or transfer.job != a._job or transfer.destination != a._destination \
			or transfer.reserved_mass_g != a._grams: return REFUSE_TRANSFER
	if a._action == CANCEL: return &""
	if transfer.worker != a._worker or transfer.source_lot != a._source_lot \
			or transfer.source_container != a._source_container or transfer.quantity_milli != a._quantity \
			or transfer.expiry_tick != a._expiry: return REFUSE_TRANSFER
	if a._action == ADMIT:
		return &"" if a._planner._job_generation[a._job.x] == 0 \
			and a._planner._chosen.kind == Planner.DESTINATION_STORE and a._planner._chosen.container == a._destination \
			and a._planner._chosen.tile == Planner.NO_TILE and a._planner._chosen.charge_g == a._grams else REFUSE_TRANSFER
	return &"" if transfer.claim_row == a._claim_row and handles_job(a, a._job) \
		and a._planner._dest_slot[a._job.x] == a._destination.x and a._planner._dest_generation[a._job.x] == a._destination.y \
		and a._planner._reserved_g[a._job.x] == a._grams else REFUSE_TRANSFER


static func _cancel_leaf(a: RefCounted, transfer: Transfer) -> StringName:
	"""Cleanup uses the exact original economic receipt even when its Project, worker or immutable source retired."""
	var code: StringName = _cleanup_binding(a)
	if code != &"": return code
	return &"" if transfer != null and handles_job(a, a._job) \
		and Vector2i(a._planner._dest_slot[a._job.x], a._planner._dest_generation[a._job.x]) == a._destination \
		and a._planner._reserved_g[a._job.x] == a._grams else REFUSE_TRANSFER


static func work_tick_observation_refusal(a: RefCounted, job: Vector2i) -> StringName:
	"""Work borrows this same packet once per handling tick; the loaded walking leg grants no productive permission."""
	var code: StringName = a._enter()
	if code != &"": return code
	a._work_tick = true
	var row: int = _full_row(a._placements._ids, job, Directory.KIND_JOB)
	if row < 0:
		_clear(a)
		return REFUSE_JOB
	var action: int = UNLOAD if a._placements._jobs._state[row] == Jobs.JOB_STATE_HAUL_OUTPUT else LOAD
	code = a._pin_job(job, action)
	if code == &"": code = a._pin_claim(Pool.PURPOSE_HAUL_DESTINATION if action == UNLOAD else Pool.PURPOSE_HAUL_SOURCE)
	if code == &"": code = a._observe_handling()
	return code


static func work_tick_leaf_refusal(a: RefCounted, job: Vector2i) -> StringName:
	"""The final Work boundary is entirely concrete and retains the exact original job/progress snapshot."""
	if a._job != job or a._job_remaining <= 0 \
			or (a._job_state != Jobs.JOB_STATE_WORK and a._job_state != Jobs.JOB_STATE_HAUL_OUTPUT): return REFUSE_JOB
	return _operation_leaf(a, null)


static func discard_work_tick(a: RefCounted, job: Vector2i) -> void:
	"""No post-credit observer or foreign packet cleanup follows a successful fixed Work publication."""
	if a._busy and a._work_tick and a._job == job: _clear(a)
