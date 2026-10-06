extends "res://scripts/core/haul_transfer_contract.gd"
## ADR1140: one synchronous actual delivery composer; Planner/Pool/Jobs retain every per-haul fact.

const Directory := preload("res://scripts/core/entity_directory.gd")
const Planner := preload("res://scripts/core/haul_planner.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Pool := preload("res://scripts/core/reservations.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Gear := preload("res://scripts/core/gear.gd")
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
const World := preload("res://scripts/core/world_init.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Definitions := preload("res://scripts/core/building_definitions.gd")
const WorkScript := preload("res://scripts/core/work.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-stone-v7/grip_certificate.gd")
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
const REFUSE_STAND: StringName = &"CONNECTOR_DELIVERY_NO_HAUL_STAND"

var _placements: Placements = null
var _frontier: Frontier = null
var _planner: Planner = null
var _provider: WorldRoutes = null
var _work: RefCounted = null
var _clock: Clock = null
var _decision_tick: int = 0
var _configured: bool = false
var _busy: bool = false
var _poisoned: bool = false
@warning_ignore("unused_private_class_variable") # Concrete static Work leaves borrow this bracket.
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
var _excavation: bool = false # ADR1197 G3: cut inputs for an entry excavation phase Project.
var _endpoint: PackedInt32Array = PackedInt32Array()
var _bounds: PackedInt32Array = PackedInt32Array()
var _support: PackedInt32Array = PackedInt32Array()
var _remaining: PackedInt32Array = PackedInt32Array()


func configure(placements: Placements, frontier: Frontier, planner: Planner,
		provider: WorldRoutes, work: RefCounted, clock: Clock, reserved_bytes: int) -> StringName:
	"""Admit the complete fixed packet before allocation, then bind one concrete Work owner at initialization."""
	if _configured or _placements != null or reserved_bytes != RESERVED_BYTES or placements == null \
			or frontier == null or planner == null or provider == null or work == null or clock == null:
		return REFUSE_BINDING
	_placements = placements
	_frontier = frontier
	_planner = planner
	_provider = provider
	_work = work
	_clock = clock
	var code: StringName = _binding_leaf(self)
	if code == &"": code = work.bind_spatial_delivery(self)
	if code != &"":
		# A late refusal must not hide an already installed one-way Work binding.
		if work._spatial_delivery == null or work._spatial_delivery.get_ref() != self:
			_placements = null; _frontier = null; _planner = null; _provider = null; _work = null; _clock = null
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
	if _implementations(a) != &"": return REFUSE_BINDING
	if p._work != a._work or p._world_routes != a._provider or p._jobs != a._work._jobs \
			or a._planner._inventory != p._inventory or a._planner._reservations != p._reservations \
			or a._planner._residents != p._residents or a._planner._buildings != p._buildings \
			or a._planner._piles != p._piles or a._work._residents != p._residents or a._work._needs != p._residents._needs \
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
	_decision_tick = _clock._completed_tick + 1
	var code: StringName = _cleanup_binding(self) if cleanup_only else _binding_leaf(self)
	if code != &"": _clear(self)
	return code


static func _clear(a: RefCounted) -> void:
	"""Callback-free cleanup follows every outcome, including the irreversible transfer tail."""
	a._busy = false
	a._poisoned = false
	a._work_tick = false
	a._excavation = false
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
	"""The current unpaid connector assembly, or an entry cut awaiting inputs, may request its material container."""
	var row: int = _directory_row(_project, Directory.KIND_CONSTRUCTION)
	var construction: Construction = _placements._construction
	if row < 0 or construction._present[row] != 1 or construction._ref_slot[row] != _project.x \
			or construction._ref_generation[row] != _project.y \
			or construction._phase[row] > Construction.PHASE_READY or construction._paused[row] != 0:
		return REFUSE_JOB
	_excavation = construction._purpose[row] == Construction.PURPOSE_EXCAVATION
	if not _excavation and construction._purpose[row] != Construction.PURPOSE_CONNECTOR_INSTALL: return REFUSE_JOB
	_destination = Vector2i(construction._material_container_slot[row], construction._material_container_generation[row])
	_placement = _entry_placement() if _excavation else Vector2i(construction._subject_slot[row], construction._subject_generation[row])
	var code: StringName = _placements.placement_into(_placement, _order)
	if code != &"" or (not _excavation and _order.project != _project): return REFUSE_SOURCE
	_geometry_revision = _placements._space._header[17]
	_frontier_revision = _frontier._header[0]
	_location_receipt = _placements._locations._last_published_token
	_route_receipt = _placements._routes._last_published_token
	code = _placements.placement_frame_into(_placement, _frame)
	if code == &"": code = _frontier.installation_into(_order.installed_count, _install)
	return code if code != &"" else _pin_material()


func _entry_placement() -> Vector2i:
	"""Excavation hauls serve the one live entry Placement; zero or several refuse rather than choose."""
	var found: Vector2i = NULL_REF
	for row: int in _placements._capacity:
		var ref: Vector2i = Vector2i(row, _placements._live.i32[Placements.GENERATION * _placements._capacity + row])
		if not _placements._is_live(_placements._live, ref): continue
		if found != NULL_REF: return NULL_REF
		found = ref
	return found


func _pin_material() -> StringName:
	"""The selected Inventory endpoint must match the immutable assembly material selector exactly."""
	if _frame.size() != 9 or _install.size() != 9: return REFUSE_SOURCE
	if _excavation:
		_destination_location = _placements._inventory.spatial_location_of(_destination)
		var read: StringName = _placements._locations.read_location_into(_destination_location, _location)
		return read if read != &"" else _material_leaf(self)
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
	if not _location_live(locations, a._destination_location): return REFUSE_ENDPOINT
	var row: int = a._destination_location.x
	if _location32(locations, Locations.ROLE, row) != Locations.ROLE_STORAGE:
		return REFUSE_ENDPOINT
	var section: Vector2i = _location_pair(locations, Locations.SECTION_SLOT, row)
	if a._excavation: return _excavation_material_leaf(a, row, section)
	for axis: int in 3:
		var point: int = _coordinate(a._frame, a._endpoint[4], a._endpoint[5], a._endpoint[6], axis)
		if not Space.int32(point) or _location32(locations, Locations.X + axis, row) != point:
			return REFUSE_ENDPOINT
	if a._endpoint[0] == Frontier.SURFACE_ANCHOR or a._endpoint[0] == Frontier.SURFACE_CONTACT:
		var anchor: Vector2i = Vector2i(a._frame[7], a._frame[8])
		if not _location_live(locations, anchor) \
				or _location_pair(locations, Locations.ROOM_SLOT, row) != NULL_REF \
				or _location_pair(locations, Locations.SECTION_SLOT, anchor.x) != section:
			return REFUSE_ENDPOINT
		return &"" if a._endpoint[0] != Frontier.SURFACE_ANCHOR or a._destination_location == anchor else REFUSE_ENDPOINT
	if a._endpoint[0] != Frontier.INSTALLED_CONTACT or a._endpoint[1] < 0 \
			or a._endpoint[1] >= a._order.installed_count \
			or _location_pair(locations, Locations.ROOM_SLOT, row) != a._order.corridor:
		return REFUSE_ENDPOINT
	return _installed_material_leaf(a, section)


static func _excavation_material_leaf(a: RefCounted, row: int, section: Vector2i) -> StringName:
	"""Sites already proved this container for the cut at bind time and re-proves it at delivery; Delivery
	additionally requires a live room-free storage endpoint in the entry anchor's own surface section."""
	var locations: Locations = a._placements._locations
	var entry: Vector2i = Vector2i(a._frame[7], a._frame[8])
	return &"" if _location_live(locations, entry) and _location_pair(locations, Locations.ROOM_SLOT, row) == NULL_REF \
		and _location_pair(locations, Locations.SECTION_SLOT, entry.x) == section else REFUSE_ENDPOINT


static func _installed_material_leaf(a: RefCounted, section: Vector2i) -> StringName:
	"""An installed selector must name the exact current Catalog LANDING, not another same-height floor."""
	var catalog: Catalog = a._placements._catalog
	var ordinal: int = a._endpoint[2]
	var variant: int = a._order.catalog_row
	if ordinal < 0 or ordinal >= Catalog._v(catalog._live, variant, Catalog.V_REGION_COUNT):
		return REFUSE_ENDPOINT
	var at: int = Catalog._v(catalog._live, variant, Catalog.V_REGION_START) + ordinal
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
	var grip: bool = Grip.uses(_placements._profiles)
	if grip: requested = mini(requested, Grip.QUANTITY_MILLI)
	if not Planner.payload_milli_into(mini(requested, inventory.lot_available_milli(_source_lot)), mass,
		_number.value, 0, _number) or _number.value <= 0: return REFUSE_TRANSFER
	_quantity = _number.value
	if grip and (_quantity != Grip.QUANTITY_MILLI or Grip.carry_row_for(inventory.lot_item_id(_source_lot)) < 0):
		return REFUSE_TRANSFER
	if not IntMath.inventory_capacity_debit_g_into(_quantity, mass, _number): return REFUSE_TRANSFER
	_grams = _number.value
	return &""


func _pin_origin() -> StringName:
	"""Observe the actual source container; carried goods retain their original full satchel identity."""
	var inventory: Inventory = _placements._inventory
	_source_container = inventory.lot_container(_source_lot)
	if _action == UNLOAD or _action == REPOST or inventory.is_satchel(_source_container):
		_source_location = _destination_location if _action == UNLOAD else \
			_placements._routes._resident_pair(Routes.R_LOCATION_SLOT, _directory_row(_worker, Directory.KIND_RESIDENT))
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


func repost_payload(job: Vector2i) -> Inventory.OpResult:
	"""Repost real carried goods after cancellation without moving them or earning a second load phase."""
	var code: StringName = _enter()
	if code != &"": return Inventory.OpResult.new(false, code, NULL_REF, 0)
	code = _pin_job(job, REPOST)
	if code == &"": code = _pin_claim(Pool.PURPOSE_HAUL_SOURCE)
	if code == &"" and (_job_remaining != Planner.HAUL_LOAD_MILLI_WU \
			or _job_state < Jobs.JOB_STATE_QUEUED or _job_state > Jobs.JOB_STATE_TRAVEL): code = REFUSE_JOB
	if code == &"": code = _observe_admission()
	if code != &"": return _finish(code)
	var row: int = _directory_row(_worker, Directory.KIND_RESIDENT)
	if not _placements._carry.carry_limit_g_into(row, _number): return _finish(REFUSE_TRANSFER)
	var result: Inventory.OpResult = _placements._reservations.transfer_haul_guarded(REPOST, job, _worker,
		_source_lot, _destination, _selection.satchel, _grams, _number.value, self, _placements._inventory)
	if result.ok: _publish_transfer(self, result)
	return _finish(result.error, result)


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
		if TransferContract.container_live(inventory, a._source_container): satchel = a._source_container
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
	if code == &"": code = _admission_profile_leaf(self)
	if code == &"": code = _placements._locations.read_location_into(graph._resident_pair(Routes.R_LOCATION_SLOT, row), _location)
	if code == &"": code = _provider._terrain.binding_refusal()
	if code == &"" and Grip.uses(_placements._profiles): code = _reach_stands(graph._resident_pair(Routes.R_LOCATION_SLOT, row))
	elif code == &"":
		code = _reach(graph._resident_pair(Routes.R_LOCATION_SLOT, row), _source_location)
		if code == &"": code = _reach(_source_location, _destination_location)
	return code if code != &"" else _operation_leaf(self, null)


func _reach_stands(origin: Vector2i) -> StringName:
	"""ADR1198 grip hauling: walk to the source's stand (already carried goods start where the worker is), then
	carry one whole unit over CARRY edges to the destination's stand with the certified loaded gait."""
	var source: Vector2i = _source_location if _carried_source(self) else stand_of(self, _source_location)
	var destination: Vector2i = stand_of(self, _destination_location)
	if source == NULL_REF or destination == NULL_REF: return REFUSE_STAND
	var code: StringName = _reach(origin, source) if origin != source else &""
	if code != &"": return code
	var carry: int = Grip.carry_row_for(_placements._inventory.lot_item_id(_source_lot))
	return _reach(source, destination, carry, 1, Grip.CONTENT_REVISION) if carry >= 0 else REFUSE_TRANSFER


static func _admission_profile_leaf(a: RefCounted) -> StringName:
	"""An owned real satchel selects CARRY; an empty shipment starts in a complete ground source."""
	var selected: Profiles.Selection = a._selection
	if _carried_source(a):
		return &"" if selected.mode == Profiles.MODE_CARRY and selected.satchel == a._source_container \
			and selected.cargo == a._source_lot and selected.cargo_quantity_milli >= a._quantity else REFUSE_HANDLING
	return &"" if a._action == ADMIT and selected.satchel == NULL_REF and selected.cargo == NULL_REF \
		and (selected.mode == Profiles.MODE_WALK or selected.mode == Profiles.MODE_STAND) else REFUSE_HANDLING


static func _carried_source(a: RefCounted) -> bool:
	"""The actual container policy identifies satchel goods; no persistent carried flag or copied quantity is added."""
	var inventory: Inventory = a._placements._inventory
	return TransferContract.container_live(inventory, a._source_container) \
		and inventory._c_policy[a._source_container.x] == Inventory.POLICY_SATCHEL


func _reach(first: Vector2i, last: Vector2i, profile: int = -1, revision: int = 0, content: int = 0) -> StringName:
	"""Borrow the actual graph's finite search; no path image, destination map or movement permission is retained.
	Without an explicit certified profile the worker's current selection searches."""
	if profile < 0:
		profile = _selection.profile_id
		revision = _selection.profile_revision
		content = _selection.content_revision
	var code: StringName = WorldRoutes.profile_reachability_refusal(_provider, first, last,
		profile, revision, content, _checks, _remaining)
	if code == &"": _checks = _remaining[0]
	return code


func _observe_handling() -> StringName:
	"""All ordinary source/pose/endpoint observations precede the direct final worker and space proof."""
	var row: int = _directory_row(_worker, Directory.KIND_RESIDENT)
	if row < 0 or not _spend(self, 8192): return REFUSE_JOB
	var code: StringName = _placements._routes._current_profile_into(row, _selection)
	if code == &"": code = _handling_profile_leaf(self)
	var endpoint: Vector2i = _destination_location if _action == UNLOAD else _source_location
	if code == &"" and _grip_selected(self): endpoint =_placements._routes._resident_pair(Routes.R_LOCATION_SLOT, row)
	if code == &"": code = _placements._locations.read_location_into(endpoint, _location)
	if code == &"": code = _provider._terrain.binding_refusal()
	return code if code != &"" else _operation_leaf(self, null)


static func _handling_profile_leaf(a: RefCounted) -> StringName:
	"""A selected no-tool HAUL work program must declare the complete entry/work/recovery and contact roles."""
	var profiles: Profiles = a._placements._profiles
	var selected: Profiles.Selection = a._selection
	var profile: int = selected.profile_id
	if profile < 0 or profile >= profiles._live.header[1] or selected.mode != Profiles.MODE_WORK \
			or selected.tool != NULL_REF or profiles._field(profiles._live, profile, Profiles.F_WORK_KIND) != Jobs.JOB_KIND_HAUL:
		return REFUSE_HANDLING
	if _grip_selected(a): return _grip_profile_leaf(a)
	if profiles._field(profiles._live, profile, Profiles.F_CONTACT_KIND) != Profiles.CONTACT_ANCHOR_AND_PATCH:
		return REFUSE_HANDLING
	var states: int = Profiles.STATE_WORK | Profiles.STATE_ENTRY | Profiles.STATE_REVERSAL | Profiles.STATE_RECOVERY
	return &"" if (profiles._field(profiles._live, profile, Profiles.F_STATES) & states) == states else REFUSE_HANDLING


static func _grip_selected(a: RefCounted) -> bool:
	"""The selected row's own contact kind decides the station seam; no caller flag or retained mode exists."""
	var profiles: Profiles = a._placements._profiles
	var row: int = a._selection.profile_id
	return row >= 0 and row < profiles._live.header[1] and a._selection.mode == Profiles.MODE_WORK \
		and profiles._field(profiles._live, row, Profiles.F_CONTACT_KIND) == Profiles.CONTACT_HAUL_GRIP


static func _grip_profile_leaf(a: RefCounted) -> StringName:
	"""A certified grip row, lifting for LOAD and setting down for UNLOAD, for exactly one whole unit."""
	var row: int = a._selection.profile_id
	if not Grip.is_grip(row) or Grip.profile_refusal(a._placements._profiles, row) != &"" \
			or a._selection.profile_revision != 1 or a._selection.content_revision != Grip.CONTENT_REVISION \
			or Grip.is_load(row) != (a._action == LOAD) or a._quantity != Grip.QUANTITY_MILLI: return REFUSE_HANDLING
	# ADR1206: the grip row's cargo family must be the shipped item's (wood rows never lift stone).
	var inventory: Inventory = a._placements._inventory
	if a._action == LOAD and inventory.is_lot_valid(a._source_lot) \
			and inventory.lot_item_id(a._source_lot) != Grip.item_of(row): return REFUSE_HANDLING
	return &""


static func stand_of(a: RefCounted, storage: Vector2i) -> Vector2i:
	"""The one live WORK endpoint at a certified stand offset from a storage point, in its section, level and room;
	none or several refuse. The stand is derived from the certificate, never from a caller-supplied map."""
	var locations: Locations = a._placements._locations
	if not _location_live(locations, storage) or not _spend(a, 4 * locations._capacity): return NULL_REF
	var found: Vector2i = NULL_REF
	for row: int in locations._capacity:
		var ref: Vector2i = Vector2i(row, _location32(locations, Locations.GENERATION, row))
		if not _location_live(locations, ref) or not _beside(locations, ref, storage): continue
		if found != NULL_REF: return NULL_REF
		found = ref
	return found


static func _beside(locations: Locations, stand: Vector2i, storage: Vector2i) -> bool:
	"""A WORK endpoint in the storage endpoint's section/level/room whose point is S minus a certified S-R."""
	if _location32(locations, Locations.ROLE, stand.x) != Locations.ROLE_WORK \
			or _location_pair(locations, Locations.SECTION_SLOT, stand.x) != _location_pair(locations, Locations.SECTION_SLOT, storage.x) \
			or _location_pair(locations, Locations.ROOM_SLOT, stand.x) != _location_pair(locations, Locations.ROOM_SLOT, storage.x) \
			or _location32(locations, Locations.LEVEL, stand.x) != _location32(locations, Locations.LEVEL, storage.x): return false
	var offset: Vector3i = _location_point(locations, storage.x) - _location_point(locations, stand.x)
	return offset == Grip.stock_offset(0) or offset == Grip.stock_offset(Grip.QUARTER)


static func _location_point(locations: Locations, row: int) -> Vector3i:
	"""Exact packed endpoint point."""
	return Vector3i(_location32(locations, Locations.X, row), _location32(locations, Locations.Y, row),
		_location32(locations, Locations.Z, row))


static func _cleanup_binding(a: RefCounted) -> StringName:
	"""Claim cleanup remains possible after Project/source retirement; only the original economic owners matter."""
	if a._placements == null or a._planner == null or a._work == null \
			or a._planner.get_script() != Planner or a._placements._reservations == null \
			or a._placements._reservations.get_script() != Pool \
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
	if a._clock._completed_tick + 1 != a._decision_tick or a._expiry <= a._decision_tick:
		return &"CONNECTOR_DELIVERY_LEASE_EXPIRED"
	var code: StringName = _binding_leaf(a)
	if code == &"": code = _source_leaf(a)
	if code == &"": code = _job_leaf(a)
	if code == &"": code = _claim_leaf(a, transfer)
	if code == &"": code = _endpoint_leaf(a, a._destination, a._destination_location)
	if code == &"" and a._action != UNLOAD and a._action != REPOST and not _carried_source(a):
		code = _endpoint_leaf(a, a._source_container, a._source_location)
	if code == &"": code = _material_leaf(a)
	if code == &"": code = _worker_leaf(a, transfer)
	if code == &"": code = _scene_leaf(a)
	if code == &"": code = _roles_leaf(a)
	if code == &"": code = _occupants_leaf(a)
	return code


static func _claim_leaf(a: RefCounted, transfer: Transfer) -> StringName:
	"""The original live claim and Planner receipt remain required after every productive or transfer observer."""
	var pool: Pool = a._placements._reservations
	if not _spend(a, 64) or a._job.x < 0 or a._job.x >= pool._job_capacity or a._job.x >= Planner.JOB_CAPACITY:
		return REFUSE_TRANSFER
	if transfer == null and (a._placements._inventory._tx_open or pool._haul_active): return REFUSE_TRANSFER
	if a._action == ADMIT:
		return &"" if a._planner._job_generation[a._job.x] == 0 and pool._job_head[a._job.x] == -1 else REFUSE_TRANSFER
	var row: int = a._claim_row
	var purpose: int = Pool.PURPOSE_HAUL_DESTINATION if a._action == UNLOAD else Pool.PURPOSE_HAUL_SOURCE
	if not handles_job(a, a._job) or row < 0 or row >= pool._row_capacity or pool._job_head[a._job.x] != row \
			or pool._occupied[row] != 1 or pool._job_next[row] != -1 \
			or pool._r_job_slot[row] != a._job.x or pool._r_job_generation[row] != a._job.y \
			or pool._r_lot_slot[row] != a._source_lot.x or pool._r_lot_generation[row] != a._source_lot.y \
			or pool._r_purpose[row] != purpose or pool._r_quantity_milli[row] != a._quantity \
			or pool._r_expiry[row] != a._expiry or a._planner._reserved_g[a._job.x] != a._grams \
			or a._planner._dest_slot[a._job.x] != a._destination.x \
			or a._planner._dest_generation[a._job.x] != a._destination.y: return REFUSE_TRANSFER
	return &"" if transfer != null else _reserved_source_leaf(a)


static func _reserved_source_leaf(a: RefCounted) -> StringName:
	"""Live Work requires actual reserved goods; the lower guarded journal separately proves staged after-facts."""
	var inventory: Inventory = a._placements._inventory
	var row: int = a._source_lot.x
	return &"" if TransferContract.lot_live(inventory, a._source_lot) \
		and TransferContract.container_live(inventory, a._source_container) \
		and inventory._l_quantity_milli[row] >= a._quantity and inventory._l_reserved_milli[row] >= a._quantity \
		and inventory._l_container_slot[row] == a._source_container.x \
		and inventory._l_container_generation[row] == a._source_container.y else REFUSE_TRANSFER


static func _source_leaf(a: RefCounted) -> StringName:
	"""A full original Placement/source/prefix and all live graph receipts must survive every callback."""
	var p: Placements = a._placements
	if not _spend(a, 512) or p._busy or not p._ready or not p._is_live(p._live, a._placement): return REFUSE_SOURCE
	if p._space._header[17] != a._geometry_revision or a._frontier._header[0] != a._frontier_revision \
			or p._locations._last_published_token != a._location_receipt or p._routes._last_published_token != a._route_receipt \
			or (not a._excavation and p._pair(p._live, Placements.PROJECT_SLOT, a._placement.x) != a._project) \
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
	if row < 0 or c._present[row] != 1 or c._ref_slot[row] != a._project.x or c._ref_generation[row] != a._project.y \
			or c._phase[row] > Construction.PHASE_READY or c._paused[row] != 0 \
			or Vector2i(c._material_container_slot[row], c._material_container_generation[row]) != a._destination:
		return REFUSE_JOB
	if a._excavation: return &"" if c._purpose[row] == Construction.PURPOSE_EXCAVATION else REFUSE_JOB
	return &"" if c._purpose[row] == Construction.PURPOSE_CONNECTOR_INSTALL and c._type_id[row] == a._order.installed_count \
		and Vector2i(c._subject_slot[row], c._subject_generation[row]) == a._placement else REFUSE_JOB


static func _endpoint_leaf(a: RefCounted, container: Vector2i, endpoint: Vector2i) -> StringName:
	"""Read exact Inventory spatial columns and actual Location generation/revision without provider callbacks."""
	var inventory: Inventory = a._placements._inventory
	var locations: Locations = a._placements._locations
	if not TransferContract.container_live(inventory, container) or not _location_live(locations, endpoint) \
			or inventory._spatial_world != a._order.world or inventory._spatial_authority == null: return REFUSE_ENDPOINT
	var provider: Locations.InventoryLocations = inventory._spatial_authority.get_ref() as Locations.InventoryLocations
	if provider == null or provider._locations == null or provider._locations.get_ref() != locations: return REFUSE_ENDPOINT
	var row: int = -2 - inventory._c_anchor_tile[container.x]
	if row < 0 or row >= Inventory.SPATIAL_ENDPOINT_CAPACITY \
			or inventory._spatial_container_slot[row] != container.x or inventory._spatial_container_generation[row] != container.y \
			or inventory._spatial_location_slot[row] != endpoint.x or inventory._spatial_location_generation[row] != endpoint.y \
			or inventory._spatial_location_revision[row] != _location64(locations, Locations.PAYLOAD_REVISION, endpoint.x):
		return REFUSE_ENDPOINT
	return &"" if Vector2i(inventory._c_owner_slot[container.x], inventory._c_owner_generation[container.x]) == a._order.world \
		and inventory._c_reachable[container.x] == 1 and inventory._c_max_mass_g[container.x] == Inventory.GROUND_PILE_MAX_MASS_G \
		and inventory._c_filters[container.x] == Inventory.FILTERS_ACCEPT_ALL \
		and (inventory._c_policy[container.x] == Inventory.UNSET_POLICY or inventory._c_policy[container.x] == Inventory.POLICY_GROUND_PILE) \
		and _location32(locations, Locations.ROLE, endpoint.x) == Locations.ROLE_STORAGE else REFUSE_ENDPOINT


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
			or Routes.actor_phase_in(graph, a._worker) != Routes.PHASE_IDLE \
			or graph._resident_pair(Routes.R_EDGE_SLOT, row) != NULL_REF \
			or graph._motion.resident[Routes.R_HEAD * Routes.RESIDENT_CAPACITY + row] >= 0: return REFUSE_ARRIVAL
	var endpoint: Vector2i = graph._resident_pair(Routes.R_LOCATION_SLOT, row)
	var storage: Vector2i = a._destination_location if a._action == UNLOAD else a._source_location
	if a._action != ADMIT and _grip_selected(a):
		if _grip_station_leaf(a, endpoint, storage) != &"": return REFUSE_ARRIVAL
	elif a._action != ADMIT and endpoint != storage:
		return REFUSE_ARRIVAL
	if not _record_matches(a._placements._locations, endpoint, a._location, a._placements._space) \
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
	if transfer.action == ADMIT:
		code = Routes.turn_selection_into(graph, row, graph._checked_selection)
		if code != &"": return code
		if not Routes._same_selection(selected, graph._checked_selection): return REFUSE_TRANSFER
	return _selected_profile_leaf(a)


static func _grip_station_leaf(a: RefCounted, stand: Vector2i, storage: Vector2i) -> StringName:
	"""Final leaf: the worker stands on the storage endpoint's stand, and the grip certificate places the stock
	exactly on the storage point S at the certified offset from the worker's exact root and heading."""
	var locations: Locations = a._placements._locations
	if not _location_live(locations, stand) or not _location_live(locations, storage) \
			or not _beside(locations, stand, storage): return REFUSE_ARRIVAL
	return Grip.station_refusal(a._placements._profiles, a._selection.profile_id,
		Vector3i(a._selection.x, a._selection.y, a._selection.z), a._selection.yaw, _location_point(locations, storage.x))


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
	return _admission_profile_leaf(a) if a._action == ADMIT or a._action == REPOST else _handling_profile_leaf(a)


static func _scene_leaf(a: RefCounted) -> StringName:
	"""Current Terrain and complete actual retained sources close late unchanged-receipt mutations."""
	var p: Placements = a._placements
	var code: StringName = WorldRoutes._reach_stores_refusal(a._provider, p._routes, p._space, p._locations)
	if code != &"": return code
	var checks: int = FinalFacts._required_checks(p._space)
	if not _spend(a, checks): return REFUSE_BUDGET
	code = _snapshot_refusal(a, checks)
	return _terrain_binding(a) if code == &"" else code


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
		code = _terrain_exclusions(a, a._bounds)
		if code != &"": return code
		if a._box.role == Profiles.STANCE_SUPPORT:
			if not Space.contains_box(a._location.support, a._bounds): return REFUSE_HANDLING
		elif a._box.role == Profiles.WORK_STROKE and _grip_selected(a):
			if not _stock_contained(a): return REFUSE_HANDLING
		elif not _body_contained(a): return REFUSE_HANDLING
	var required: int = 7 if a._action == ADMIT or a._action == REPOST else (31 if _grip_selected(a) else 127)
	return &"" if (roles & required) == required else REFUSE_HANDLING


static func _stock_contained(a: RefCounted) -> bool:
	"""A grip row's stroke is the stock itself: above the floor in the stand's air, and its floor contact at S on the
	stand's surveyed footing (floor support at S). It is not a foot, so no stance region is asked to cover it."""
	var floor_y: int = a._location.envelope[1]
	for axis: int in 6: a._support[axis] = a._bounds[axis]
	if a._bounds[4] > floor_y:
		a._support[1] = maxi(a._bounds[1], floor_y)
		if not Space.contains_box(a._location.envelope, a._support): return false
	if a._bounds[1] >= floor_y: return true
	a._support[1] = a._bounds[1]
	a._support[4] = mini(a._bounds[4], floor_y)
	return Space.contains_box(a._location.support, a._support)


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
		if code == &"": code = _resident_into(a, graph._resident_ref(row), a._placements._space._facts)
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
	if code != &"": _clear(a)
	return code


static func work_tick_leaf_refusal(a: RefCounted, job: Vector2i) -> StringName:
	"""The final Work boundary is entirely concrete and retains the exact original job/progress snapshot."""
	if a._job != job or a._job_remaining <= 0 \
			or (a._job_state != Jobs.JOB_STATE_WORK and a._job_state != Jobs.JOB_STATE_HAUL_OUTPUT): return REFUSE_JOB
	return _operation_leaf(a, null)


static func discard_work_tick(a: RefCounted, job: Vector2i) -> void:
	"""No post-credit observer or foreign packet cleanup follows a successful fixed Work publication."""
	if a._busy and a._work_tick and a._job == job: _clear(a)


static func _implementations(a: RefCounted) -> StringName:
	"""This coordinator pins concrete final readers; observation-only Locations/Terrain subclasses stay separate."""
	var p: Placements = a._placements
	if p._space == null or p._ids == null or p._routes == null or p._profiles == null or p._catalog == null \
			or p._jobs == null or p._residents == null or p._residents._needs == null or p._buildings == null \
			or p._buildings._definitions == null or p._profiles._gear == null or p._reservations == null: return REFUSE_BINDING
	if p.get_script() != Placements or a._frontier.get_script() != Frontier or a._provider.get_script() != WorldRoutes \
			or a._planner.get_script() != Planner or p._reservations.get_script() != Pool \
			or a._clock == null or a._clock.get_script() != Clock or a._clock._completed_tick < 0 \
			or a._clock._completed_tick >= IntMath.INT64_MAX or p._space.get_script() != Owner \
			or p._ids.get_script() != Directory or p._routes.get_script() != Routes \
			or p._profiles.get_script() != Profiles or p._catalog.get_script() != Catalog \
			or p._jobs.get_script() != Jobs or p._residents.get_script() != Residents or p._residents._needs.get_script() != Needs \
			or a._work.get_script() != WorkScript or p._buildings.get_script() != Buildings or p._profiles._gear.get_script() != Gear:
		return REFUSE_BINDING
	var terrain: Terrain = a._provider._terrain
	if terrain == null or terrain._world == null or terrain._nodes == null \
			or terrain._world.get_script() != World or terrain._nodes.get_script() != Nodes \
			or terrain._buildings != p._buildings or p._buildings._definitions.get_script() != Definitions:
		return REFUSE_BINDING
	return &""


static func _location_live(actual: Locations, ref: Vector2i) -> bool:
	"""Only the actual packed generation/presence is consulted; no subclass method runs in the paid tail."""
	return ref.x >= 0 and ref.x < actual._capacity and ref.y > 0 and actual._live.present[ref.x] == 1 \
		and actual._live.i32[Locations.GENERATION * actual._capacity + ref.x] == ref.y


static func _location32(actual: Locations, field: int, row: int) -> int:
	"""Read one bounded field-major column directly."""
	return actual._live.i32[field * actual._capacity + row]


static func _location64(actual: Locations, field: int, row: int) -> int:
	"""Read one bounded revision column directly."""
	return actual._live.i64[field * actual._capacity + row]


static func _location_pair(actual: Locations, field: int, row: int) -> Vector2i:
	"""Keep full generations in their actual Location namespace."""
	return Vector2i(_location32(actual, field, row), _location32(actual, field + 1, row))


static func _record_matches(actual: Locations, ref: Vector2i, record: Locations.Record, owner: Owner) -> bool:
	"""Attest all copied endpoint facts after every observation, with no dynamic Location dispatch."""
	if not _location_live(actual, ref) or actual._token != 0 or actual._in_retention \
			or not FinalFacts._location_binding(actual, owner) or record.world != actual._world:
		return false
	if record.room != _location_pair(actual, Locations.ROOM_SLOT, ref.x) \
			or record.section != _location_pair(actual, Locations.SECTION_SLOT, ref.x) \
			or record.level != _location32(actual, Locations.LEVEL, ref.x) \
			or record.role != _location32(actual, Locations.ROLE, ref.x) \
			or record.payload_revision != _location64(actual, Locations.PAYLOAD_REVISION, ref.x) \
			or record.geometry_revision != _location64(actual, Locations.GEOMETRY_REVISION, ref.x): return false
	for axis: int in 3:
		if record.point[axis] != _location32(actual, Locations.X + axis, ref.x): return false
	for axis: int in 6:
		if record.envelope[axis] != _location32(actual, Locations.ENVELOPE + axis, ref.x) \
				or record.support[axis] != _location32(actual, Locations.SUPPORT + axis, ref.x): return false
	return owner._region_live(record.section, false) and (record.room == NULL_REF or actual._buildings.is_live_room(record.room))


static func _snapshot_refusal(a: RefCounted, checks: int) -> StringName:
	"""Preserve complete live source/claim validation, replacing only the overridable Location convenience readers."""
	var owner: Owner = a._placements._space
	var code: StringName = FinalFacts._binding_refusal(owner, a._placements._routes, a._placements._locations, a._geometry_revision)
	if code != &"": return code
	if checks > owner._domain._checks or checks < FinalFacts._required_checks(owner): return REFUSE_BUDGET
	for row: int in owner._source_capacity:
		if owner._o_present[row] == 0: continue
		if owner._o_present[row] != 1: return &"SPACE_SOURCE_FORMAT"
		var ref: Vector2i = Vector2i(owner._o_slot[row], owner._o_generation[row])
		if not owner._sources._directory.is_valid_of_kind(ref, owner._o_kind[row]): return &"SPACE_SOURCE_STALE"
		code = _resident_into(a, ref, owner._facts) if owner._o_kind[row] == Directory.KIND_RESIDENT \
			else Owner.CoreSources.read_final_into(owner._sources, ref, owner._facts)
		if code == &"": code = FinalFacts._facts_refusal(owner._sources, ref, owner._facts)
		if code != &"": return code
		if not owner._facts_match(row, false): return &"SPACE_SOURCE_DRIFT"
	return FinalFacts._claims_refusal(owner)


static func _resident_into(a: RefCounted, worker: Vector2i, out: Owner.Facts) -> StringName:
	"""Exact current physical pose and committed route containment supply retained Resident facts."""
	var graph: Routes = a._placements._routes
	var row: int = FinalFacts._resident_pose_into(graph, worker)
	if row < 0 or graph._resident_ref(row) != worker or not graph._residents.is_alive(row): return &"ROUTE_ACTOR_NOT_REGISTERED"
	var code: StringName = _resident_location(a, row)
	if code != &"": return code
	out.kind = Directory.KIND_RESIDENT
	out.parent = graph._resident_pair(Routes.R_ROOM_SLOT, row)
	out.a = graph._pose.x; out.b = graph._pose.y; out.c = graph._pose.z
	out.d = graph._motion.resident[Routes.R_MODE * Routes.RESIDENT_CAPACITY + row]
	return &""


static func _resident_location(a: RefCounted, row: int) -> StringName:
	"""Full current endpoint/span identity uses direct Location columns and concrete route geometry."""
	var graph: Routes = a._placements._routes
	var locations: Locations = a._placements._locations
	var location: Vector2i = graph._resident_pair(Routes.R_LOCATION_SLOT, row)
	var section: Vector2i = graph._resident_pair(Routes.R_SECTION_SLOT, row)
	var room: Vector2i = graph._resident_pair(Routes.R_ROOM_SLOT, row)
	if not _location_live(locations, location) or locations._world != graph._world \
			or not graph._owner._region_live(section, false) or (room != NULL_REF and not graph._buildings.is_live_room(room)):
		return &"ROUTE_LOCATION_STALE"
	if graph._resident_pair(Routes.R_EDGE_SLOT, row) != NULL_REF: return FinalFacts._transit_refusal(graph, row)
	if Vector3i(_location32(locations, Locations.X, location.x), _location32(locations, Locations.Y, location.x), \
		_location32(locations, Locations.Z, location.x)) != Vector3i(graph._pose.x, graph._pose.y, graph._pose.z): return &"ROUTE_ACTOR_POSITION_DRIFT"
	return &"" if _location_pair(locations, Locations.ROOM_SLOT, location.x) == room \
		and _location_pair(locations, Locations.SECTION_SLOT, location.x) == section \
		and _location32(locations, Locations.LEVEL, location.x) == graph._motion.resident[Routes.R_LEVEL * Routes.RESIDENT_CAPACITY + row] \
		else &"ROUTE_ACTOR_CONTAINMENT_DRIFT"


static func _terrain_binding(a: RefCounted) -> StringName:
	"""The ordinary Terrain observer has finished; exact actual source fields are read without its virtual helpers."""
	var t: Terrain = a._provider._terrain
	var owner: Owner = a._placements._space
	if not t._ready or t._space == null or t._space.get_ref() != owner \
			or t._sources == null or t._sources.get_ref() != owner._sources \
			or owner._header[17] != a._geometry_revision or owner._stage_token != 0 \
			or t._checked_geometry_revision != a._geometry_revision or not t._world._published \
			or t._world._published_seed != t._seed or t._world._nodes != t._nodes \
			or t._world._directory != a._placements._ids or t._world_ref != a._order.world \
			or owner._sources._construction != a._placements._construction:
		return Terrain.REFUSE_BINDING
	return &"" if _full_row(a._placements._ids, t._world_ref, Directory.KIND_WORLD) >= 0 else Terrain.REFUSE_BINDING


static func _terrain_exclusions(a: RefCounted, bounds: PackedInt32Array) -> StringName:
	"""Bounded exact dry/exclusion facts mirror Terrain without dispatching a Terrain subclass in the final journal."""
	var t: Terrain = a._provider._terrain
	if not Space.valid_box(bounds) or not Space.contains_box(t._domain_bounds, bounds): return Terrain.REFUSE_BOUNDS
	@warning_ignore("integer_division") var first_x: int = bounds[0] / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var last_x: int = (bounds[3] - 1) / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var first_z: int = bounds[2] / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var last_z: int = (bounds[5] - 1) / World.TILE_SIZE_UNITS
	if (last_x - first_x + 1) * (last_z - first_z + 1) > Terrain.LOCAL_TILE_LIMIT: return &"TERRAIN_LOCAL_CAPACITY"
	for z: int in range(first_z, last_z + 1):
		for x: int in range(first_x, last_x + 1):
			var code: StringName = _terrain_tile(t, z * World.MAP_TILES_X + x, bounds)
			if code != &"": return code
	return &""


static func _terrain_tile(t: Terrain, tile: int, bounds: PackedInt32Array) -> StringName:
	"""Concrete World/Resource/Building implementations are pinned before any final leaf call."""
	var kind: int = t._world._terrain[tile]
	if kind < 0 or kind >= World.TERRAIN_COUNT: return &"TERRAIN_WORLD_KIND"
	var floor_y: int = Terrain._natural_floor(tile, kind)
	if (floor_y == Terrain.BOTTOM_U and bounds[1] < 0) \
			or (floor_y < 0 and bounds[1] < 0 and bounds[4] > floor_y): return Terrain.REFUSE_WATER
	var code: StringName = _terrain_resource(t, tile, bounds)
	return _terrain_building(t, tile, bounds) if code == &"" else code


static func _terrain_resource(t: Terrain, tile: int, bounds: PackedInt32Array) -> StringName:
	"""Actual stock/regrowth and full resource identity retain the existing exact vertical exclusion."""
	var ref: Vector2i = t._nodes.ref_at_tile(tile)
	if ref == NULL_REF and not t._nodes.has_node_at_tile(tile): return &""
	var code: StringName = t._nodes.spatial_facts_into(ref, t._resource_facts)
	if code != &"": return code
	if t._resource_facts[0] != tile: return &"TERRAIN_RESOURCE_TILE"
	var kind: int = t._resource_ids.find(int(t._resource_facts[1]))
	if kind < 0 or t._resource_facts[2] < 0 or t._resource_facts[3] < 0: return &"TERRAIN_RESOURCE_CATALOG"
	if t._resource_facts[2] == 0 and t._resource_facts[3] == 0: return &""
	var low: int = World.LAND_Y_UNITS - (1024 if kind == 0 else 4096)
	var high: int = World.LAND_Y_UNITS + ((8192 if t._resource_facts[2] > 0 else 256) if kind == 0 else 1024)
	return Terrain.REFUSE_RESOURCE if Terrain._vertical_overlap(bounds, low, high) else &""


static func _terrain_building(t: Terrain, tile: int, bounds: PackedInt32Array) -> StringName:
	"""Exact actual rotated footprints retain complete foundation and upper-body exclusions."""
	var ref: Vector2i = t._buildings.building_at_tile(tile)
	if ref == NULL_REF: return &""
	var code: StringName = t._buildings.spatial_identity_into(ref, t._building_facts)
	if code != &"": return code
	var type_id: int = t._building_facts[0]
	var definitions: Definitions = t._buildings._definitions
	if not definitions.is_building_id(type_id) or not World.is_tile_index(t._building_facts[1]) \
			or t._building_facts[2] < 0 or t._building_facts[2] > 3 or t._building_facts[3] < 0 \
			or t._building_facts[3] >= Buildings.STATE_COUNT: return &"TERRAIN_BUILDING_CONTENT"
	var width: int = definitions.footprint_x_of(type_id)
	var depth: int = definitions.footprint_z_of(type_id)
	if t._building_facts[2] % 2 != 0:
		var original: int = width
		width = depth; depth = original
	var origin: int = t._building_facts[1]
	@warning_ignore("integer_division") var dz: int = tile / World.MAP_TILES_X - origin / World.MAP_TILES_X
	var dx: int = tile % World.MAP_TILES_X - origin % World.MAP_TILES_X
	if dx < 0 or dz < 0 or dx >= width or dz >= depth: return &"TERRAIN_BUILDING_FOOTPRINT"
	if Terrain._vertical_overlap(bounds, World.LAND_Y_UNITS - t._depth[type_id], World.LAND_Y_UNITS): return Terrain.REFUSE_FOUNDATION
	return Terrain.REFUSE_BODY if Terrain._vertical_overlap(bounds, World.LAND_Y_UNITS, World.LAND_Y_UNITS + t._height[type_id]) else &""


static func retirement_refusal_in(actual: RefCounted, original: RefCounted,
		stopped_constructor: bool = false) -> StringName:
	"""Match the original configured delivery or an exact retained late-refusal prefix, never another planner."""
	if actual == null or original == null or original.delivery != actual \
			or (not actual._configured and not stopped_constructor) or actual._placements == null \
			or actual._placements != original.placements or actual._provider != original.world_routes \
			or actual._work != original.work or actual._frontier == null or actual._planner == null \
			or actual._clock == null or actual._clock.get_script() != Clock:
		return REFUSE_BINDING
	if actual._busy or actual._work_tick or actual._action != -1 or actual._job != NULL_REF:
		return REFUSE_BUSY
	if original.work._spatial_delivery == null or original.work._spatial_delivery.get_ref() != actual \
			or original.work._delivery_script != actual.get_script():
		return REFUSE_BINDING
	return _retirement_sources_in(actual, original)


static func _retirement_sources_in(actual: RefCounted, original: RefCounted) -> StringName:
	"""The kernel additionally matches the exact private Host Planner/clock, using its already retained Host."""
	if original.room_bindings == null or actual._frontier != original.room_bindings._entry_frontier \
			or actual._planner.get_script() != Planner or actual._planner._inventory != original.inventory \
			or actual._planner._reservations != original.reservations or actual._planner._residents != original.residents \
			or actual._planner._buildings != original.buildings or actual._planner._piles != original.piles \
			or actual._planner._store_policy == null or actual._planner._store_policy._directory != original.directory \
			or actual._planner._store_policy._buildings != original.buildings \
			or actual._planner._store_policy._inventory != original.inventory:
		return REFUSE_BINDING
	return &""


static func world_retirement_release_preflighted_in(actual: RefCounted, original: RefCounted,
		persistent_id: int, stopped_constructor: bool = false) -> StringName:
	"""First in the new-owner tail: drop only Delivery memory after the exact canonical World clear."""
	var code: StringName = retirement_refusal_in(actual, original, stopped_constructor)
	if code != &"": return code
	code = Buildings.whole_world_retirement_refusal_in(original.directory, original.world_ref, persistent_id, true)
	if code != &"": return code
	if original.world == null or original.world._published: return REFUSE_BINDING
	actual._configured = true # Once-bound tombstone also covers a failed post-bind allocation/configuration.
	actual._placements = null
	actual._frontier = null
	actual._planner = null
	actual._provider = null
	actual._work = null
	actual._clock = null
	_release_retired_packet_in(actual)
	return &""


static func _release_retired_packet_in(actual: RefCounted) -> void:
	"""Release all owned caller scratch without allocating another packet or clearing a foreign Work link."""
	actual._order = null
	actual._selection = null
	actual._location = null
	actual._box = null
	actual._number = null
	actual._frame.clear()
	actual._install.clear()
	actual._endpoint.clear()
	actual._bounds.clear()
	actual._support.clear()
	actual._remaining.clear()
