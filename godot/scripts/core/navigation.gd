extends RefCounted
## ARCH-PATH-002/003/004/005 ground routing: deterministic A* on the baseline surface graph, its
## bounded route cache, and the request states that keep "still queued" apart from "proven
## unreachable".
##
## ---------------------------------------------------------------------------------------
## PATH-R02: EXACT-START A*, AND WHAT IT REPLACED.
##
## ARCH-PATH-003 as written stores one route per `(start_macro, goal_cell, clearance, revision)`
## bucket, keyed by the macro's canonical ANCHOR, and gives a start that is not the anchor a
## macro-local entry segment to reach it. Implemented literally that routes EVERY start through
## its anchor. Decision 0053 measured the consequence on the authored map: cell (100,100) to
## (104,102) composed to cost 160 against a true optimum of 48, and a start whose goal lies back
## past the anchor retraced its own cells. Bounded by the 16-cell macro, so negligible on a long
## journey and dominant on a short one -- which is most job trips.
##
## PATH-R02 supersedes that construction for new requests. A cached route is reused only when its
## own start is the requester's actual start; a request whose start already IS the anchor also
## matches the ordinary `variant_start=-1` descriptor, because that route genuinely begins there.
## Every other miss runs unconstrained exact-start to exact-goal A* and publishes the whole route
## with `variant_start=start_cell`. There is NO distance threshold and NO nearest-point splice:
## the ruling rejected both, because a geometrically nearest join is not necessarily the cheapest
## one. `PHASE_SEARCHING_LOCAL` is consequently unreachable and the prefix-plus-bucket
## concatenation is gone; `_r_start_cell` is now always `_r_exact_start`, since no stage rewrites
## the origin to an anchor any more.
##
## The cost is cache hit rate: two residents in one macro walking to one destination now search
## twice instead of sharing a bucket. The quota stays at 2048 expansions a tick regardless --
## PATH-R02 forbids both raising it and adding a separate small-query budget -- so the honest
## report is a remeasured readiness distribution, which `test_navigation.gd` pins.
##
## ---------------------------------------------------------------------------------------
## SCOPE, AND THE HEURISTIC'S EXACT VALIDITY.
##
## The octile heuristic `10*(dx+dz)-6*min(dx,dz)` is admissible ON THIS GRAPH AND ONLY ON IT: a
## uniform 512x512 half-metre lattice whose only edge costs are 10 orthogonal and 14 diagonal. The
## moment a nonlocal connection with its own transition cost exists -- a ladder, a shore entry, a
## tunnel mouth -- two cells one lattice step apart may be reachable for less than 10, the bound
## breaks, and A* silently returns a non-shortest path that still looks plausible. SET-MOVE-001 4
## therefore makes Dijkstra with `h=0` the correctness reference for any expanded graph, and
## `reference_cost_into()` below is that reference on the ground graph. NOTHING IN THIS MODULE
## MIXES A TRANSITION COST INTO THE HEURISTIC, and no nonlocal connection is enabled here; adding
## one requires the expanded-graph Dijkstra comparison first (task 05.1b, MOVE-G02).
##
## ---------------------------------------------------------------------------------------
## QUEUED IS NOT UNREACHABLE (READY_07 1.2 acceptance).
##
## A search interrupted by the shared 2048-expansion tick quota has proved NOTHING. Only a search
## whose open set empties without reaching the goal has proved unreachability, and only for the
## clearance class and map revision it ran under. `is_pending()` and `is_proven_unreachable()` are
## separate predicates over separate phases, there is no phase that means both, and the
## quota-interrupted request keeps its heap, parents, g-scores and cursor for the next tick
## (ARCH-PATH-006). `is_blocked_on_route_storage()` is a third, equally distinct state: the route
## was FOUND and could not be stored.
##
## ---------------------------------------------------------------------------------------
## IDENTITY. Endpoints arrive as `spatial_world.gd` Location records, which carry domain, layer,
## map revision, cell AND a generation-safe contact owner. No entry point here takes a bare X/Z
## pair, because X/Z does not identify a destination once any second domain exists. Owners are
## revalidated at service time as well as at submit, both halves of the EntityRef together.
##
## ---------------------------------------------------------------------------------------
## MEMORY. The A* builder, route arena, descriptors and request records below ARE
## systems_architecture.md 2.3's already-budgeted rows. The one addition this slice makes is the
## five-column `PathRequestContact` table (8192 rows, 163840 bytes) holding the two contact owner
## references and the requester's persistent ID, because ARCH-MEM-008's sixteen PathRequest columns
## have nowhere to put a generation-safe contact owner. Decision 0053 records it. No array is
## resized outside `_init()`.

const IntMath := preload("res://scripts/core/int_math.gd")
const SpatialWorld := preload("res://scripts/core/spatial_world.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")

# --- graph constants, ARCH-PATH-002 --------------------------------------------------------------

## "A* uses N,E,S,W,NE,SE,SW,NW expansion order". North is -Z, matching GDD 4.2's -Z forward.
const NEIGHBOUR_COUNT: int = 8
const NEIGHBOUR_DX: Array[int] = [0, 1, 0, -1, 1, 1, -1, -1]
const NEIGHBOUR_DZ: Array[int] = [-1, 0, 1, 0, -1, 1, 1, -1]

## "edge costs 10 orthogonal/14 diagonal".
const COST_ORTHOGONAL: int = 10
const COST_DIAGONAL: int = 14
const NEIGHBOUR_COST: Array[int] = [10, 10, 10, 10, 14, 14, 14, 14]

## "no diagonal crossing when either adjacent orthogonal cell is blocked for clearance". These are
## the two orthogonal neighbour INDEXES each diagonal must find passable: NE needs E and N, and so
## on around the compass. Entries 0..3 are unused because an orthogonal step has no corner.
const CORNER_A: Array[int] = [-1, -1, -1, -1, 1, 1, 3, 3]
const CORNER_B: Array[int] = [-1, -1, -1, -1, 0, 2, 2, 0]

## "Heuristic=`10*(dx+dz)-6*min(dx,dz)`" -- 14 - 2*10 = -6.
const HEURISTIC_DIAGONAL_DISCOUNT: int = 6

# --- bounded capacities, ARCH-PATH-005 and systems_architecture.md 2.3 ---------------------------

## "Every removed/finalized search cell counts toward the global 2048 expansions/tick".
const EXPANSION_QUOTA_PER_TICK: int = 2048

## PATH-R02 holds the quota fixed: "All finalized expansions share the existing 2048/tick quota;
## do not add a 'small query' budget." Exact-start search spends MORE of it than anchor composition
## did, and the correct response to that is a measured readiness report, not a larger number here.

const ROUTE_DESCRIPTOR_CAPACITY: int = 256
const ROUTE_CELL_CAPACITY: int = 1048576
const PATH_REQUEST_CAPACITY: int = 8192

## `service()` cannot loop forever: every pass either burns an expansion or settles one request.
const SERVICE_ITERATION_GUARD: int = EXPANSION_QUOTA_PER_TICK + PATH_REQUEST_CAPACITY + 16

# --- request phases -----------------------------------------------------------------------------

const PHASE_FREE: int = 0
const PHASE_QUEUED: int = 1

## RETIRED BY PATH-R02 AND DELIBERATELY NOT RENUMBERED. This was ARCH-PATH-003's macro-local
## start->anchor entry segment. No request enters it any more -- `_start_first_stage()` admits
## only SEARCHING_FULL and SEARCHING_VARIANT -- but the value keeps its slot so that a persisted
## `_r_phase` byte written before this change still decodes to what it meant, instead of silently
## re-reading as SEARCHING_FULL. `ROUTE_SEMANTICS_VERSION` is what refuses such a payload.
const PHASE_SEARCHING_LOCAL: int = 2
const PHASE_SEARCHING_FULL: int = 3
const PHASE_SEARCHING_VARIANT: int = 4
const PHASE_READY: int = 5
const PHASE_UNREACHABLE: int = 6
const PHASE_BLOCKED_ROUTE_STORAGE: int = 7
const PHASE_STALE_REQUESTER: int = 8
const PHASE_STALE_START: int = 9
const PHASE_STALE_GOAL: int = 10
const PHASE_STALE_REVISION: int = 11
const PHASE_CANCELLED: int = 12
const PHASE_COUNT: int = 13

const PHASE_NAMES: Array[StringName] = [
	&"FREE", &"QUEUED", &"SEARCHING_LOCAL", &"SEARCHING_FULL", &"SEARCHING_VARIANT",
	&"READY", &"UNREACHABLE", &"BLOCKED_ROUTE_STORAGE", &"STALE_REQUESTER", &"STALE_START",
	&"STALE_GOAL", &"STALE_REVISION", &"CANCELLED",
]

# --- refusal codes ------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_REQUESTER: StringName = &"REQUESTER_REF_STALE"
const REFUSE_START_OWNER: StringName = &"START_OWNER_REF_STALE"
const REFUSE_GOAL_OWNER: StringName = &"GOAL_OWNER_REF_STALE"
const REFUSE_START_LOCATION: StringName = &"START_LOCATION_NOT_CURRENT"
const REFUSE_GOAL_LOCATION: StringName = &"GOAL_LOCATION_NOT_CURRENT"
const REFUSE_CLEARANCE: StringName = &"INVALID_CLEARANCE_CLASS"
const REFUSE_REQUEST_CAPACITY: StringName = &"CAPACITY_PATH_REQUEST"
const REFUSE_DESCRIPTOR_CAPACITY: StringName = &"CAPACITY_ROUTE_DESCRIPTOR"
const REFUSE_ARENA_CAPACITY: StringName = &"CAPACITY_ROUTE_CELL_ARENA"
const REFUSE_INVALID_REQUEST: StringName = &"INVALID_REQUEST_ROW"
const REFUSE_NOT_READY: StringName = &"REQUEST_NOT_READY"
const REFUSE_INVALID_INDEX: StringName = &"INVALID_ROUTE_INDEX"
const REFUSE_REFERENCE_BUSY: StringName = &"REFERENCE_SEARCH_BUSY"
const REFUSE_REFERENCE_UNREACHABLE: StringName = &"REFERENCE_UNREACHABLE"
const REFUSE_INVALID_CELL: StringName = &"INVALID_CELL"
const REFUSE_PATH_CYCLE: StringName = &"INTERNAL_PATH_CYCLE"
const REFUSE_REVISION_STALE: StringName = &"MAP_REVISION_STALE"
const REFUSE_ROUTE_SEMANTICS: StringName = &"ROUTE_SEMANTICS_VERSION_INCOMPATIBLE"

# --- route semantics version, PATH-R02's continuation gate ---------------------------------------

## Version 1 was ARCH-PATH-003's compulsory composition: a stored route was keyed by the macro
## ANCHOR, a non-anchor start held a separate entry prefix, and the published route was the
## concatenation of the two. Version 2 is PATH-R02: every published route begins at the exact
## start it was requested from, SEARCHING_LOCAL is unreachable, and no prefix hold exists.
##
## The two are not interchangeable and array shape does not distinguish them -- a version 1
## descriptor table has the same sixteen columns of the same width. So a section 9 NAVIGATION
## restore must compare this number and REFUSE, not flush the cache and not reinterpret an
## in-flight request. `refuse_route_semantics()` is that comparison. There is no section 9 writer
## yet (decision 0053 records ARCH-PATH-006 save/load as BLOCKED), which is exactly why the gate
## is published here now rather than invented by whoever writes it.
const ROUTE_SEMANTICS_VERSION: int = 2
const ROUTE_SEMANTICS_VERSION_ANCHOR_COMPOSITION: int = 1

# --- internal search bookkeeping ----------------------------------------------------------------

const STATE_UNTOUCHED: int = 0
const STATE_OPEN: int = 1
const STATE_CLOSED: int = 2

const STEP_RUNNING: int = 0
const STEP_REACHED: int = 1
const STEP_EXHAUSTED: int = 2

const FLAG_IN_USE: int = 1

## A descriptor whose generation would leave int32 is RETIRED rather than wrapped: reusing it
## would hand a stale holder a generation that matches, which is exactly the check's purpose.
const FLAG_RETIRED: int = 2

## Absence markers for internal columns. These are never returned from a public function as a
## failure code; every public refusal is an explicit `false` plus a StringName.
const NO_ROW: int = -1
const NO_ROUTE: int = -1
const NO_VARIANT: int = -1

## Tick halves: both stored nonnegative so PackedInt32Array never truncates a set high bit.
const TICK_LOW_BITS: int = 31
const TICK_LOW_MASK: int = 0x7FFFFFFF

var _directory: EntityDirectory = null
var _world: SpatialWorld = null

# --- A* builder, 2.3 "Active A* builder": g,parent,heap,heap_position,stamp i32 + state byte -----

var _g: PackedInt32Array = PackedInt32Array()
var _parent: PackedInt32Array = PackedInt32Array()
var _heap: PackedInt32Array = PackedInt32Array()
var _heap_position: PackedInt32Array = PackedInt32Array()
var _stamp: PackedInt32Array = PackedInt32Array()
var _state: PackedByteArray = PackedByteArray()

var _heap_size: int = 0
var _search_serial: int = 0
var _search_goal: int = NO_ROW
var _search_origin: int = NO_ROW
var _search_macro: int = NO_ROW
var _search_clearance: int = 0
## False only for `reference_cost_into()`'s Dijkstra, which must run with h=0 by definition.
var _use_heuristic: bool = true

# --- route arena and descriptors, 2.3 "Route cell arena" / "Route descriptors" -------------------

var _arena: PackedInt32Array = PackedInt32Array()
var _arena_used: int = 0

var _d_route_id: PackedInt32Array = PackedInt32Array()
var _d_generation: PackedInt32Array = PackedInt32Array()
var _d_start_macro: PackedInt32Array = PackedInt32Array()
var _d_goal_cell: PackedInt32Array = PackedInt32Array()
var _d_clearance: PackedInt32Array = PackedInt32Array()
var _d_map_revision: PackedInt32Array = PackedInt32Array()
var _d_variant_start: PackedInt32Array = PackedInt32Array()
var _d_anchor: PackedInt32Array = PackedInt32Array()
var _d_offset: PackedInt32Array = PackedInt32Array()
var _d_count: PackedInt32Array = PackedInt32Array()
var _d_refcount: PackedInt32Array = PackedInt32Array()
var _d_use_low: PackedInt32Array = PackedInt32Array()
var _d_use_high: PackedInt32Array = PackedInt32Array()
var _d_flags: PackedInt32Array = PackedInt32Array()
var _d_next_variant: PackedInt32Array = PackedInt32Array()
var _d_reserved: PackedInt32Array = PackedInt32Array()

# --- path requests, 2.3 "Path request records" plus this slice's contact table -------------------

var _r_job_slot: PackedInt32Array = PackedInt32Array()
var _r_job_generation: PackedInt32Array = PackedInt32Array()
var _r_start_cell: PackedInt32Array = PackedInt32Array()
var _r_goal_cell: PackedInt32Array = PackedInt32Array()
var _r_clearance: PackedInt32Array = PackedInt32Array()
var _r_start_macro: PackedInt32Array = PackedInt32Array()
var _r_map_revision: PackedInt32Array = PackedInt32Array()
var _r_phase: PackedInt32Array = PackedInt32Array()
var _r_route_id: PackedInt32Array = PackedInt32Array()
var _r_route_generation: PackedInt32Array = PackedInt32Array()
var _r_created_low: PackedInt32Array = PackedInt32Array()
var _r_created_high: PackedInt32Array = PackedInt32Array()
var _r_next_queue: PackedInt32Array = PackedInt32Array()
var _r_exact_start: PackedInt32Array = PackedInt32Array()
var _r_anchor: PackedInt32Array = PackedInt32Array()
var _r_expansions: PackedInt32Array = PackedInt32Array()

var _c_start_owner_slot: PackedInt32Array = PackedInt32Array()
var _c_start_owner_generation: PackedInt32Array = PackedInt32Array()
var _c_goal_owner_slot: PackedInt32Array = PackedInt32Array()
var _c_goal_owner_generation: PackedInt32Array = PackedInt32Array()
var _c_requester_persistent_id: PackedInt32Array = PackedInt32Array()

var _free_request_head: int = NO_ROW
var _queue_head: int = NO_ROW
var _active_request: int = NO_ROW
var _live_requests: int = 0

var _expansions_remaining: int = 0
var _expansions_total: int = 0
var _served_revision: int = 0
var _storage_blocked_count: int = 0
var _last_refusal: StringName = REFUSE_NONE


func _init(directory: EntityDirectory, world: SpatialWorld) -> void:
	"""Bind the directory and ground map, then allocate every packed column once to capacity."""
	_directory = directory
	_world = world
	_served_revision = world.current_map_revision()
	_allocate_builder()
	_allocate_routes()
	_allocate_requests()


func _allocate_builder() -> void:
	"""Allocate the shared A* builder columns; the stamp makes clearing them between searches free."""
	_g.resize(SpatialWorld.CELL_COUNT)
	_parent.resize(SpatialWorld.CELL_COUNT)
	_heap.resize(SpatialWorld.CELL_COUNT)
	_heap_position.resize(SpatialWorld.CELL_COUNT)
	_stamp.resize(SpatialWorld.CELL_COUNT)
	_state.resize(SpatialWorld.CELL_COUNT)


func _allocate_routes() -> void:
	"""Allocate the 1048576-cell route arena and the 256 route descriptors, all marked free.

	Each column is resized by name. A PackedInt32Array is a copy-on-write VALUE, so resizing one
	through a temporary Array of columns would resize sixteen private copies and leave every real
	column at length zero.
	"""
	_arena.resize(ROUTE_CELL_CAPACITY)
	_d_route_id.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_generation.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_start_macro.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_goal_cell.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_clearance.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_map_revision.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_variant_start.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_anchor.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_offset.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_count.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_refcount.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_use_low.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_use_high.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_flags.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_next_variant.resize(ROUTE_DESCRIPTOR_CAPACITY)
	_d_reserved.resize(ROUTE_DESCRIPTOR_CAPACITY)
	for row: int in ROUTE_DESCRIPTOR_CAPACITY:
		_d_route_id[row] = row
		_d_generation[row] = 1
		_d_next_variant[row] = NO_VARIANT


func _allocate_requests() -> void:
	"""Allocate the 8192 request records and thread them onto the free list in ascending order."""
	_r_job_slot.resize(PATH_REQUEST_CAPACITY)
	_r_job_generation.resize(PATH_REQUEST_CAPACITY)
	_r_start_cell.resize(PATH_REQUEST_CAPACITY)
	_r_goal_cell.resize(PATH_REQUEST_CAPACITY)
	_r_clearance.resize(PATH_REQUEST_CAPACITY)
	_r_start_macro.resize(PATH_REQUEST_CAPACITY)
	_r_map_revision.resize(PATH_REQUEST_CAPACITY)
	_r_phase.resize(PATH_REQUEST_CAPACITY)
	_r_route_id.resize(PATH_REQUEST_CAPACITY)
	_r_route_generation.resize(PATH_REQUEST_CAPACITY)
	_r_created_low.resize(PATH_REQUEST_CAPACITY)
	_r_created_high.resize(PATH_REQUEST_CAPACITY)
	_r_next_queue.resize(PATH_REQUEST_CAPACITY)
	_r_exact_start.resize(PATH_REQUEST_CAPACITY)
	_r_anchor.resize(PATH_REQUEST_CAPACITY)
	_r_expansions.resize(PATH_REQUEST_CAPACITY)
	_allocate_contacts()
	for row: int in range(PATH_REQUEST_CAPACITY - 1, -1, -1):
		_r_phase[row] = PHASE_FREE
		_r_route_id[row] = NO_ROUTE
		_r_next_queue[row] = _free_request_head
		_free_request_head = row


func _allocate_contacts() -> void:
	"""Allocate this slice's PathRequestContact table: both contact owners plus the requester ID."""
	_c_start_owner_slot.resize(PATH_REQUEST_CAPACITY)
	_c_start_owner_generation.resize(PATH_REQUEST_CAPACITY)
	_c_goal_owner_slot.resize(PATH_REQUEST_CAPACITY)
	_c_goal_owner_generation.resize(PATH_REQUEST_CAPACITY)
	_c_requester_persistent_id.resize(PATH_REQUEST_CAPACITY)


# --- tick encoding ------------------------------------------------------------------------------

static func _tick_low(tick: int) -> int:
	"""The low 31 bits of a nonnegative tick, so the stored half is never a negative int32."""
	return tick & TICK_LOW_MASK


static func _tick_high(tick: int) -> int:
	"""The remaining high bits of a nonnegative tick. Together the halves rebuild it exactly."""
	return tick >> TICK_LOW_BITS


static func _tick_from_halves(high: int, low: int) -> int:
	"""Rebuild a nonnegative tick from the two stored halves."""
	return (high << TICK_LOW_BITS) | low


# --- submission ---------------------------------------------------------------------------------

func submit_request_into(
	requester: Vector2i, start: SpatialWorld.Location, goal: SpatialWorld.Location,
	clearance_class: int, tick: int, out: IntMath.IntResult
) -> bool:
	"""Queue one ground route request, writing its record row into `out`, or refuse explicitly.

	Both endpoints must be CURRENT ground locations whose contact owners are live references, and
	the requester must be live too. Nothing is queued unless every check passes; there is no
	partial submission and no fallback endpoint.
	"""
	var refusal: StringName = _validate_submission(requester, start, goal, clearance_class)
	if refusal != REFUSE_NONE:
		_last_refusal = refusal
		return out.refuse(refusal)
	if _free_request_head == NO_ROW:
		_last_refusal = REFUSE_REQUEST_CAPACITY
		return out.refuse(REFUSE_REQUEST_CAPACITY)
	var row: int = _free_request_head
	_free_request_head = _r_next_queue[row]
	_fill_request(row, requester, start, goal, clearance_class, tick)
	_enqueue(row)
	_live_requests += 1
	_last_refusal = REFUSE_NONE
	return out.succeed(row)


func _validate_submission(
	requester: Vector2i, start: SpatialWorld.Location, goal: SpatialWorld.Location,
	clearance_class: int
) -> StringName:
	"""Every precondition for queueing a request, as the refusal it produces or REFUSE_NONE."""
	if clearance_class < SpatialWorld.MIN_CLEARANCE_CLASS \
			or clearance_class > SpatialWorld.MAX_CLEARANCE_CLASS:
		return REFUSE_CLEARANCE
	if not _directory.is_valid(requester):
		return REFUSE_REQUESTER
	var uncontracted: StringName = _world.refuse_uncontracted(start.domain, start.layer)
	if uncontracted != REFUSE_NONE:
		return uncontracted
	uncontracted = _world.refuse_uncontracted(goal.domain, goal.layer)
	if uncontracted != REFUSE_NONE:
		return uncontracted
	if not _world.location_is_current(start):
		return REFUSE_START_LOCATION
	if not _world.location_is_current(goal):
		return REFUSE_GOAL_LOCATION
	if not _directory.is_valid(start.owner_ref()):
		return REFUSE_START_OWNER
	if not _directory.is_valid(goal.owner_ref()):
		return REFUSE_GOAL_OWNER
	return REFUSE_NONE


func _fill_request(
	row: int, requester: Vector2i, start: SpatialWorld.Location, goal: SpatialWorld.Location,
	clearance_class: int, tick: int
) -> void:
	"""Write one validated submission into its record row and its contact row."""
	_r_job_slot[row] = requester.x
	_r_job_generation[row] = requester.y
	# Equal to `_r_exact_start` by construction since PATH-R02 removed the anchor rewrite. Both
	# columns are kept because ARCH-MEM-008 names them and a section 9 writer must persist both.
	_r_start_cell[row] = start.cell
	_r_exact_start[row] = start.cell
	_r_goal_cell[row] = goal.cell
	_r_clearance[row] = clearance_class
	_r_start_macro[row] = SpatialWorld.macro_of(start.cell)
	_r_map_revision[row] = start.revision
	_r_phase[row] = PHASE_QUEUED
	_r_route_id[row] = NO_ROUTE
	_r_route_generation[row] = 0
	_r_created_low[row] = _tick_low(tick)
	_r_created_high[row] = _tick_high(tick)
	_r_anchor[row] = NO_ROW
	_r_expansions[row] = 0
	_c_start_owner_slot[row] = start.owner_slot
	_c_start_owner_generation[row] = start.owner_generation
	_c_goal_owner_slot[row] = goal.owner_slot
	_c_goal_owner_generation[row] = goal.owner_generation
	_c_requester_persistent_id[row] = _directory.get_persistent_id(requester)


func _enqueue(row: int) -> void:
	"""Insert a queued request in ARCH-PATH-002's order: job persistent ID, then request generation.

	The record row breaks a remaining tie, so two requests from one job in one tick still have one
	deterministic order. The list is kept sorted at insert rather than scanned at service, so the
	per-tick service loop never sorts.
	"""
	_r_next_queue[row] = NO_ROW
	if _queue_head == NO_ROW or _queue_precedes(row, _queue_head):
		_r_next_queue[row] = _queue_head
		_queue_head = row
		return
	var cursor: int = _queue_head
	while _r_next_queue[cursor] != NO_ROW and not _queue_precedes(row, _r_next_queue[cursor]):
		cursor = _r_next_queue[cursor]
	_r_next_queue[row] = _r_next_queue[cursor]
	_r_next_queue[cursor] = row


func _queue_precedes(left: int, right: int) -> bool:
	"""True when request `left` must be serviced before request `right`."""
	var left_id: int = _c_requester_persistent_id[left]
	var right_id: int = _c_requester_persistent_id[right]
	if left_id != right_id:
		return left_id < right_id
	if _r_job_generation[left] != _r_job_generation[right]:
		return _r_job_generation[left] < _r_job_generation[right]
	return left < right


# --- request lifecycle --------------------------------------------------------------------------

func is_request_row(row: int) -> bool:
	"""True when `row` names a request record that is currently allocated."""
	return row >= 0 and row < PATH_REQUEST_CAPACITY and _r_phase[row] != PHASE_FREE


func request_phase(row: int) -> int:
	"""The phase of a live request, or PHASE_FREE for any row that is not allocated."""
	if row < 0 or row >= PATH_REQUEST_CAPACITY:
		return PHASE_FREE
	return _r_phase[row]


func request_phase_name(row: int) -> StringName:
	"""The phase of a request as its diagnostic StringName."""
	return PHASE_NAMES[request_phase(row)]


func is_pending(row: int) -> bool:
	"""True while a request is queued or mid-search. A pending request has proved NOTHING."""
	var phase: int = request_phase(row)
	return phase >= PHASE_QUEUED and phase <= PHASE_SEARCHING_VARIANT


func is_queued(row: int) -> bool:
	"""True while a request is waiting for service and has not consumed a single expansion."""
	return request_phase(row) == PHASE_QUEUED


func is_ready(row: int) -> bool:
	"""True when a request holds a complete, still-valid route."""
	return request_phase(row) == PHASE_READY


func is_proven_unreachable(row: int) -> bool:
	"""True ONLY when a search emptied its open set without reaching the goal.

	Never true for a quota-interrupted search, a stale reference or a storage refusal. Those are
	`is_pending()`, the PHASE_STALE_* phases and `is_blocked_on_route_storage()` respectively.
	"""
	return request_phase(row) == PHASE_UNREACHABLE


func is_blocked_on_route_storage(row: int) -> bool:
	"""True when the route was found and the bounded cache had nowhere to put it (ARCH-PATH-005)."""
	return request_phase(row) == PHASE_BLOCKED_ROUTE_STORAGE


func is_stale(row: int) -> bool:
	"""True when a reference or the map revision invalidated the request before it completed."""
	var phase: int = request_phase(row)
	return phase >= PHASE_STALE_REQUESTER and phase <= PHASE_STALE_REVISION


func cancel_request(row: int) -> bool:
	"""Cancel a live request, releasing any route reference it holds, or refuse explicitly."""
	if not is_request_row(row):
		_last_refusal = REFUSE_INVALID_REQUEST
		return false
	_settle_request(row, PHASE_CANCELLED)
	_last_refusal = REFUSE_NONE
	return true


func release_request(row: int) -> bool:
	"""Return a settled request record to the free list, dropping its route reference first."""
	if not is_request_row(row):
		_last_refusal = REFUSE_INVALID_REQUEST
		return false
	_settle_request(row, PHASE_CANCELLED)
	_detach_from_queue(row)
	_r_phase[row] = PHASE_FREE
	_r_next_queue[row] = _free_request_head
	_free_request_head = row
	_live_requests -= 1
	_last_refusal = REFUSE_NONE
	return true


func _settle_request(row: int, phase: int) -> void:
	"""Move a request to a terminal phase, releasing its held route reference exactly once."""
	if _active_request == row:
		_abandon_active_search()
	_detach_from_queue(row)
	if _r_route_id[row] != NO_ROUTE:
		_release_route(_r_route_id[row], _r_route_generation[row])
		_r_route_id[row] = NO_ROUTE
		_r_route_generation[row] = 0
	_r_phase[row] = phase


func _detach_from_queue(row: int) -> void:
	"""Unlink a request from the pending queue if it is on it."""
	if _queue_head == row:
		_queue_head = _r_next_queue[row]
		_r_next_queue[row] = NO_ROW
		return
	var cursor: int = _queue_head
	while cursor != NO_ROW and _r_next_queue[cursor] != row:
		cursor = _r_next_queue[cursor]
	if cursor == NO_ROW:
		return
	_r_next_queue[cursor] = _r_next_queue[row]
	_r_next_queue[row] = NO_ROW


# --- route readers ------------------------------------------------------------------------------

func route_length_into(row: int, out: IntMath.IntResult) -> bool:
	"""The cell count of a ready request's route, or an explicit refusal."""
	if not is_ready(row):
		_last_refusal = REFUSE_NOT_READY
		return out.refuse(REFUSE_NOT_READY)
	return out.succeed(_d_count[_r_route_id[row]])


func route_cell_into(row: int, index: int, out: IntMath.IntResult) -> bool:
	"""One cell of a ready request's route, start first and goal last, or an explicit refusal."""
	if not is_ready(row):
		_last_refusal = REFUSE_NOT_READY
		return out.refuse(REFUSE_NOT_READY)
	var route: int = _r_route_id[row]
	if index < 0 or index >= _d_count[route]:
		_last_refusal = REFUSE_INVALID_INDEX
		return out.refuse(REFUSE_INVALID_INDEX)
	return out.succeed(_arena[_d_offset[route] + index])


func route_cost_into(row: int, out: IntMath.IntResult) -> bool:
	"""The 10/14 cost of a ready request's stored route, summed over its steps."""
	if not is_ready(row):
		_last_refusal = REFUSE_NOT_READY
		return out.refuse(REFUSE_NOT_READY)
	var route: int = _r_route_id[row]
	var offset: int = _d_offset[route]
	var total: int = 0
	for index: int in range(1, _d_count[route]):
		var previous: int = _arena[offset + index - 1]
		var cell: int = _arena[offset + index]
		var dx: int = absi(SpatialWorld.cell_x_of(cell) - SpatialWorld.cell_x_of(previous))
		var dz: int = absi(SpatialWorld.cell_z_of(cell) - SpatialWorld.cell_z_of(previous))
		total += COST_DIAGONAL if dx + dz == 2 else COST_ORTHOGONAL
	return out.succeed(total)


func request_route_id(row: int) -> int:
	"""The descriptor a ready request references, or NO_ROUTE. Internal identity, never a result."""
	if not is_request_row(row):
		return NO_ROUTE
	return _r_route_id[row]


func request_expansions(row: int) -> int:
	"""How many finalized cells this request has spent from the shared quota so far."""
	if not is_request_row(row):
		return 0
	return _r_expansions[row]


func request_anchor(row: int) -> int:
	"""The cell this request searched from, which under PATH-R02 is always its exact start.

	Kept because ARCH-MEM-008 names the column and a section 9 writer must persist it. It is no
	longer ever a macro anchor that differs from the start; when the two coincide the request
	publishes the `variant_start=-1` descriptor, and when they do not the anchor is not consulted.
	"""
	if not is_request_row(row):
		return NO_ROW
	return _r_anchor[row]


# --- per-tick service ---------------------------------------------------------------------------

func service(tick: int) -> int:
	"""Spend up to 2048 finalized expansions on the pending queue and return how many were used.

	ARCH-PATH-002's quota is GLOBAL and shared by local-entry, exact-route and reference-start
	searches alike, so a busy tick starves later requests rather than exceeding the budget. A
	request left mid-search keeps its heap, parents, g-scores and cursor and resumes next tick; it
	does NOT become unreachable, and an incomplete search never exposes a traversable prefix.
	"""
	_expansions_remaining = EXPANSION_QUOTA_PER_TICK
	_handle_revision_change()
	var guard: int = 0
	while _expansions_remaining > 0 and guard < SERVICE_ITERATION_GUARD:
		guard += 1
		if _active_request == NO_ROW and not _begin_next_request(tick):
			break
		if _active_request != NO_ROW:
			_advance_active(tick)
	return EXPANSION_QUOTA_PER_TICK - _expansions_remaining


func _handle_revision_change() -> void:
	"""ARCH-PATH-005 invalidation: a new map revision retires every route built under the old one.

	Requests are settled FIRST, so each releases its own route reference exactly once and the
	descriptors are unreferenced by the time they are freed. A settled request lands in
	PHASE_STALE_REVISION rather than being silently re-searched: its endpoint Location records
	were minted against the previous revision and only their owner may re-approve them.
	"""
	var current: int = _world.current_map_revision()
	if current == _served_revision:
		return
	_served_revision = current
	_abandon_active_search()
	for row: int in PATH_REQUEST_CAPACITY:
		if _r_phase[row] == PHASE_FREE or _r_map_revision[row] == current:
			continue
		if _r_phase[row] <= PHASE_READY:
			_settle_request(row, PHASE_STALE_REVISION)
	for descriptor: int in ROUTE_DESCRIPTOR_CAPACITY:
		if _d_flags[descriptor] & FLAG_IN_USE and _d_map_revision[descriptor] != current:
			_free_descriptor(descriptor)
	_compact_arena()


func _begin_next_request(tick: int) -> bool:
	"""Take the queue head, revalidate it, and start its first search stage. False when idle."""
	if _queue_head == NO_ROW:
		return false
	var row: int = _queue_head
	_queue_head = _r_next_queue[row]
	_r_next_queue[row] = NO_ROW
	var refusal: StringName = _revalidate(row)
	if refusal != REFUSE_NONE:
		_settle_request(row, _stale_phase_of(refusal))
		return true
	_start_first_stage(row, tick)
	return true


func _revalidate(row: int) -> StringName:
	"""Recheck a queued request's references and revision, both EntityRef halves together."""
	if _r_map_revision[row] != _world.current_map_revision():
		return REFUSE_REVISION_STALE
	if not _directory.is_valid(Vector2i(_r_job_slot[row], _r_job_generation[row])):
		return REFUSE_REQUESTER
	var start_owner: Vector2i = Vector2i(_c_start_owner_slot[row], _c_start_owner_generation[row])
	if not _directory.is_valid(start_owner):
		return REFUSE_START_OWNER
	var goal_owner: Vector2i = Vector2i(_c_goal_owner_slot[row], _c_goal_owner_generation[row])
	if not _directory.is_valid(goal_owner):
		return REFUSE_GOAL_OWNER
	return REFUSE_NONE


static func _stale_phase_of(refusal: StringName) -> int:
	"""The phase a revalidation refusal settles its request into."""
	if refusal == REFUSE_REQUESTER:
		return PHASE_STALE_REQUESTER
	if refusal == REFUSE_START_OWNER:
		return PHASE_STALE_START
	if refusal == REFUSE_GOAL_OWNER:
		return PHASE_STALE_GOAL
	return PHASE_STALE_REVISION


func _start_first_stage(row: int, tick: int) -> void:
	"""PATH-R02 admission: an exact-start cache hit, the zero-travel case, or exact-start A*.

	ARCH-PATH-003's compulsory macro-local start->anchor entry segment is gone. A stored route is
	reused ONLY when its own start is this request's actual start (PATH-R02 2), with the single
	equivalence PATH-R02 3 states: a request whose start already IS the canonical macro anchor is
	served by, and publishes, the ordinary `variant_start=-1` anchor descriptor, because that
	descriptor's route genuinely begins at this exact start. Every other miss runs an
	unconstrained exact-start to exact-goal search (PATH-R02 4).
	"""
	var start: int = _r_exact_start[row]
	var goal: int = _r_goal_cell[row]
	var clearance: int = _r_clearance[row]
	if not _world.cell_passes_clearance(start, clearance) \
			or not _world.cell_passes_clearance(goal, clearance):
		_settle_request(row, PHASE_UNREACHABLE)
		return
	var start_is_anchor: bool = start == _world.lowest_passable_cell_in_macro(
		_r_start_macro[row], clearance)
	_r_anchor[row] = start
	var cached: int = _find_exact_start_route(row, start, goal, clearance, start_is_anchor)
	if cached != NO_ROUTE:
		_attach_route(row, cached, tick)
		return
	if start == goal:
		_complete_direct(row, tick, start)
		return
	_begin_search(
		row, PHASE_SEARCHING_FULL if start_is_anchor else PHASE_SEARCHING_VARIANT,
		start, goal, NO_ROW)


func _find_exact_start_route(
	row: int, start: int, goal: int, clearance: int, start_is_anchor: bool
) -> int:
	"""PATH-R02 2 and 3's cache probe: this start's own variant, or the anchor route it equals.

	It NEVER returns a descriptor built for a different start merely because the two share a macro.
	That reuse is exactly the detour decision 0053 measured at 160 against an optimum of 48, and
	removing it is the whole of PATH-R02. `_find_descriptor()` already pins goal, clearance and
	map revision, so this probe adds only the start-identity rule.
	"""
	var macro_id: int = _r_start_macro[row]
	var exact: int = _find_descriptor(macro_id, goal, clearance, start)
	if exact != NO_ROUTE:
		return exact
	if not start_is_anchor:
		return NO_ROUTE
	return _find_descriptor(macro_id, goal, clearance, NO_VARIANT)


func _advance_active(tick: int) -> void:
	"""Run the active search until the quota runs out or the stage settles, then route the result."""
	var row: int = _active_request
	var result: int = _step_search(row)
	if result == STEP_RUNNING:
		return
	if _r_phase[row] == PHASE_SEARCHING_FULL:
		_finish_full(row, result, tick)
	else:
		_finish_variant(row, result, tick)


func _finish_full(row: int, result: int, tick: int) -> void:
	"""The anchor-start search settled: publish the `variant_start=-1` route, or prove it unreachable.

	Under PATH-R02 this stage runs only when the request's exact start IS the canonical macro
	anchor, so the published route begins at the caller's real start. It keeps the `-1` key so a
	later request starting on the same anchor finds it, per PATH-R02 3.
	"""
	if result == STEP_EXHAUSTED:
		_settle_request(row, PHASE_UNREACHABLE)
		return
	var bucket: int = _store_route(
		_r_anchor[row], _r_goal_cell[row], _r_start_macro[row], _r_goal_cell[row],
		_r_clearance[row], NO_VARIANT, _r_anchor[row], tick)
	if bucket == NO_ROUTE:
		_settle_request(row, PHASE_BLOCKED_ROUTE_STORAGE)
		_storage_blocked_count += 1
		return
	_abandon_active_search()
	_attach_route(row, bucket, tick)


func _finish_variant(row: int, result: int, tick: int) -> void:
	"""The exact-start search settled: publish a start-keyed variant, or prove it unreachable."""
	if result == STEP_EXHAUSTED:
		_settle_request(row, PHASE_UNREACHABLE)
		return
	var variant: int = _store_route(
		_r_exact_start[row], _r_goal_cell[row], _r_start_macro[row], _r_goal_cell[row],
		_r_clearance[row], _r_exact_start[row], _r_exact_start[row], tick)
	if variant == NO_ROUTE:
		_settle_request(row, PHASE_BLOCKED_ROUTE_STORAGE)
		_storage_blocked_count += 1
		return
	_abandon_active_search()
	_attach_route(row, variant, tick)


func _complete_direct(row: int, tick: int, cell: int) -> void:
	"""Publish the one-cell route of a request whose start already is its goal."""
	var route: int = _store_route(
		cell, cell, _r_start_macro[row], cell, _r_clearance[row], cell, cell, tick)
	if route == NO_ROUTE:
		_settle_request(row, PHASE_BLOCKED_ROUTE_STORAGE)
		_storage_blocked_count += 1
		return
	_attach_route(row, route, tick)


func _attach_route(row: int, route: int, tick: int) -> void:
	"""Make a stored route this request's result, holding a reference so it cannot be evicted."""
	_hold_route(route, tick)
	_r_route_id[row] = route
	_r_route_generation[row] = _d_generation[route]
	_r_phase[row] = PHASE_READY
	if _active_request == row:
		_abandon_active_search()


# --- the A* search itself, ARCH-PATH-002 ---------------------------------------------------------

func _begin_search(row: int, phase: int, origin: int, goal: int, macro_limit: int) -> void:
	"""Start one search stage from `origin` to `goal`, optionally confined to one macro cell."""
	_r_phase[row] = phase
	_active_request = row
	_search_origin = origin
	_search_goal = goal
	_search_macro = macro_limit
	_search_clearance = _r_clearance[row]
	_use_heuristic = true
	_next_serial()
	_heap_size = 0
	_touch(origin, 0, NO_ROW)
	_heap_push(origin)


func _abandon_active_search() -> void:
	"""Drop the active search's heap without touching any request phase."""
	_active_request = NO_ROW
	_heap_size = 0
	_search_goal = NO_ROW
	_search_origin = NO_ROW
	_search_macro = NO_ROW


func _next_serial() -> void:
	"""Advance the stamp that makes the 262144-cell builder self-clearing between searches."""
	if _search_serial >= IntMath.INT32_MAX - 1:
		_stamp.fill(0)
		_search_serial = 0
	_search_serial += 1


func _touched(cell: int) -> bool:
	"""True when this search has already visited `cell`."""
	return _stamp[cell] == _search_serial


func _touch(cell: int, cost: int, parent: int) -> void:
	"""Enrol a cell in the current search with a g-score and a predecessor."""
	_stamp[cell] = _search_serial
	_g[cell] = cost
	_parent[cell] = parent
	_state[cell] = STATE_OPEN
	_heap_position[cell] = NO_ROW


func _heuristic(cell: int) -> int:
	"""ARCH-PATH-002's octile estimate `10*(dx+dz)-6*min(dx,dz)`, or 0 for the Dijkstra reference."""
	if not _use_heuristic:
		return 0
	var dx: int = absi(SpatialWorld.cell_x_of(cell) - SpatialWorld.cell_x_of(_search_goal))
	var dz: int = absi(SpatialWorld.cell_z_of(cell) - SpatialWorld.cell_z_of(_search_goal))
	var smaller: int = dx if dx < dz else dz
	return COST_ORTHOGONAL * (dx + dz) - HEURISTIC_DIAGONAL_DISCOUNT * smaller


func _step_search(row: int) -> int:
	"""Finalize cells until the goal is reached, the open set empties, or the quota runs out."""
	while _expansions_remaining > 0:
		if _heap_size == 0:
			return STEP_EXHAUSTED
		var cell: int = _heap_pop()
		_state[cell] = STATE_CLOSED
		_expansions_remaining -= 1
		_expansions_total += 1
		_r_expansions[row] += 1
		if cell == _search_goal:
			return STEP_REACHED
		_expand(cell)
	return STEP_RUNNING


func _expand(cell: int) -> void:
	"""Relax every legal neighbour of a finalized cell, in the fixed N,E,S,W,NE,SE,SW,NW order."""
	var x: int = SpatialWorld.cell_x_of(cell)
	var z: int = SpatialWorld.cell_z_of(cell)
	for index: int in NEIGHBOUR_COUNT:
		var nx: int = x + NEIGHBOUR_DX[index]
		var nz: int = z + NEIGHBOUR_DZ[index]
		if not SpatialWorld.is_cell_coord(nx, nz):
			continue
		var neighbour: int = nz * SpatialWorld.CELLS_X + nx
		if not _step_is_legal(x, z, neighbour, index):
			continue
		if _touched(neighbour) and _state[neighbour] == STATE_CLOSED:
			continue
		_relax(cell, neighbour, _g[cell] + NEIGHBOUR_COST[index])


func _step_is_legal(x: int, z: int, neighbour: int, index: int) -> bool:
	"""Clearance and ARCH-PATH-002's corner rule for one candidate step.

	A diagonal is refused when EITHER adjacent orthogonal cell fails the clearance class, so a
	body can never slip through the gap between two blocked cells that touch only at a corner.
	"""
	if not _world.cell_passes_clearance(neighbour, _search_clearance):
		return false
	if _search_macro != NO_ROW and SpatialWorld.macro_of(neighbour) != _search_macro:
		return false
	if index < 4:
		return true
	return _corner_open(x, z, CORNER_A[index]) and _corner_open(x, z, CORNER_B[index])


func _corner_open(x: int, z: int, orthogonal_index: int) -> bool:
	"""True when one of a diagonal's two adjacent orthogonal cells is on-map and passable."""
	var cx: int = x + NEIGHBOUR_DX[orthogonal_index]
	var cz: int = z + NEIGHBOUR_DZ[orthogonal_index]
	if not SpatialWorld.is_cell_coord(cx, cz):
		return false
	return _world.cell_passes_clearance(cz * SpatialWorld.CELLS_X + cx, _search_clearance)


func _relax(cell: int, neighbour: int, tentative: int) -> void:
	"""Open, improve, or apply ARCH-PATH-002's equal-g tie rule to one neighbour."""
	if not _touched(neighbour):
		_touch(neighbour, tentative, cell)
		_heap_push(neighbour)
		return
	if tentative < _g[neighbour]:
		_g[neighbour] = tentative
		_parent[neighbour] = cell
		_heap_sift_up(_heap_position[neighbour])
		return
	if tentative == _g[neighbour] and cell < _parent[neighbour]:
		_parent[neighbour] = cell


# --- indexed binary min-heap over `(f, cell_id)` --------------------------------------------------

func _heap_less(left: int, right: int) -> bool:
	"""ARCH-PATH-002's heap order: lower f first, then lower cell ID. Total and deterministic."""
	var left_f: int = _g[left] + _heuristic(left)
	var right_f: int = _g[right] + _heuristic(right)
	if left_f != right_f:
		return left_f < right_f
	return left < right


func _heap_push(cell: int) -> void:
	"""Insert a cell that has no heap entry yet; each cell holds at most one."""
	_heap[_heap_size] = cell
	_heap_position[cell] = _heap_size
	_heap_size += 1
	_heap_sift_up(_heap_size - 1)


func _heap_pop() -> int:
	"""Remove and return the minimum cell. Caller has checked `_heap_size > 0`."""
	var top: int = _heap[0]
	_heap_position[top] = NO_ROW
	_heap_size -= 1
	if _heap_size > 0:
		var moved: int = _heap[_heap_size]
		_heap[0] = moved
		_heap_position[moved] = 0
		_heap_sift_down(0)
	return top


func _heap_sift_up(index: int) -> void:
	"""Restore the heap upwards after an insert or a decrease-key."""
	var position: int = index
	while position > 0:
		var parent: int = (position - 1) / 2
		if not _heap_less(_heap[position], _heap[parent]):
			return
		_heap_swap(position, parent)
		position = parent


func _heap_sift_down(index: int) -> void:
	"""Restore the heap downwards after a pop."""
	var position: int = index
	while true:
		var left: int = position * 2 + 1
		if left >= _heap_size:
			return
		var smallest: int = left
		var right: int = left + 1
		if right < _heap_size and _heap_less(_heap[right], _heap[left]):
			smallest = right
		if not _heap_less(_heap[smallest], _heap[position]):
			return
		_heap_swap(position, smallest)
		position = smallest


func _heap_swap(left: int, right: int) -> void:
	"""Exchange two heap slots, keeping each cell's recorded position correct."""
	var left_cell: int = _heap[left]
	var right_cell: int = _heap[right]
	_heap[left] = right_cell
	_heap[right] = left_cell
	_heap_position[right_cell] = left
	_heap_position[left_cell] = right


# --- route storage, ARCH-PATH-005 -----------------------------------------------------------------

func _store_route(
	origin: int, goal: int, start_macro: int, goal_cell: int, clearance: int,
	variant_start: int, anchor: int, tick: int
) -> int:
	"""Materialize the finished search's parent chain into a descriptor, or NO_ROUTE on refusal.

	NO_ROUTE is an internal absence: every caller converts it into an explicit request phase and a
	`last_refusal()` code, and no route index ever leaves this module as a failure signal.
	"""
	var length: int = _path_length(origin, goal)
	if length < 0:
		_last_refusal = REFUSE_PATH_CYCLE
		return NO_ROUTE
	var descriptor: int = _acquire_descriptor(tick)
	if descriptor == NO_ROUTE:
		_last_refusal = REFUSE_DESCRIPTOR_CAPACITY
		return NO_ROUTE
	_describe(descriptor, start_macro, goal_cell, clearance, variant_start, anchor, tick)
	var offset: int = _acquire_arena(length)
	if offset == NO_ROW:
		_free_descriptor(descriptor)
		_last_refusal = REFUSE_ARENA_CAPACITY
		return NO_ROUTE
	_d_offset[descriptor] = offset
	_d_count[descriptor] = length
	_write_path(offset, origin, goal, length)
	_d_refcount[descriptor] = 0
	_link_variant(descriptor)
	return descriptor


func _path_length(origin: int, goal: int) -> int:
	"""Cells on the parent chain from `origin` to `goal` inclusive, or -1 if the chain is broken."""
	var count: int = 1
	var cell: int = goal
	while cell != origin:
		cell = _parent[cell]
		if cell < 0 or cell >= SpatialWorld.CELL_COUNT:
			return -1
		count += 1
		if count > SpatialWorld.CELL_COUNT:
			return -1
	return count


func _write_path(offset: int, origin: int, goal: int, length: int) -> void:
	"""Write the parent chain into the arena in travel order: origin first, goal last."""
	var cell: int = goal
	for index: int in range(length - 1, -1, -1):
		_arena[offset + index] = cell
		if index > 0:
			cell = _parent[cell]
	_arena[offset] = origin


func _describe(
	descriptor: int, start_macro: int, goal_cell: int, clearance: int,
	variant_start: int, anchor: int, tick: int
) -> void:
	"""Fill a freshly acquired descriptor's key fields and take the construction-time hold.

	The hold matters: `_acquire_arena()` may evict unreferenced descriptors, and without it the
	descriptor being built is itself a legal victim.
	"""
	_d_flags[descriptor] = FLAG_IN_USE
	_d_start_macro[descriptor] = start_macro
	_d_goal_cell[descriptor] = goal_cell
	_d_clearance[descriptor] = clearance
	_d_map_revision[descriptor] = _world.current_map_revision()
	_d_variant_start[descriptor] = variant_start
	_d_anchor[descriptor] = anchor
	_d_offset[descriptor] = 0
	_d_count[descriptor] = 0
	_d_refcount[descriptor] = 1
	_d_use_low[descriptor] = _tick_low(tick)
	_d_use_high[descriptor] = _tick_high(tick)
	_d_next_variant[descriptor] = NO_VARIANT
	_d_reserved[descriptor] = 0


func _link_variant(descriptor: int) -> void:
	"""Chain a start-keyed variant onto the macro bucket sharing its key, per ARCH-MEM-008."""
	if _d_variant_start[descriptor] == NO_VARIANT:
		return
	var bucket: int = _find_descriptor(
		_d_start_macro[descriptor], _d_goal_cell[descriptor], _d_clearance[descriptor], NO_VARIANT)
	if bucket == NO_ROUTE:
		return
	_d_next_variant[descriptor] = _d_next_variant[bucket]
	_d_next_variant[bucket] = descriptor


func _find_descriptor(start_macro: int, goal_cell: int, clearance: int, variant_start: int) -> int:
	"""ARCH-PATH-003's cache key lookup at the CURRENT revision, or NO_ROUTE when absent."""
	var revision: int = _world.current_map_revision()
	for descriptor: int in ROUTE_DESCRIPTOR_CAPACITY:
		if _d_flags[descriptor] != FLAG_IN_USE:
			continue
		if _d_start_macro[descriptor] != start_macro or _d_goal_cell[descriptor] != goal_cell:
			continue
		if _d_clearance[descriptor] != clearance or _d_map_revision[descriptor] != revision:
			continue
		if _d_variant_start[descriptor] != variant_start:
			continue
		return descriptor
	return NO_ROUTE


func _acquire_descriptor(tick: int) -> int:
	"""Take a free descriptor, evicting the least recently used unreferenced one if need be."""
	for descriptor: int in ROUTE_DESCRIPTOR_CAPACITY:
		if _d_flags[descriptor] == 0:
			return descriptor
	var victim: int = _lowest_use_unreferenced()
	if victim == NO_ROW:
		return NO_ROUTE
	_free_descriptor(victim)
	if _d_flags[victim] != 0:
		return NO_ROUTE
	return victim


func _lowest_use_unreferenced() -> int:
	"""ARCH-PATH-005's eviction order `(last_use_tick, cache_id)`. Referenced routes are skipped."""
	var best: int = NO_ROW
	var best_tick: int = 0
	for descriptor: int in ROUTE_DESCRIPTOR_CAPACITY:
		if _d_flags[descriptor] != FLAG_IN_USE or _d_refcount[descriptor] > 0:
			continue
		var used: int = _tick_from_halves(_d_use_high[descriptor], _d_use_low[descriptor])
		if best == NO_ROW or used < best_tick:
			best = descriptor
			best_tick = used
	return best


func _free_descriptor(descriptor: int) -> void:
	"""Return a descriptor to the free pool, advancing its generation so stale holders can tell."""
	_d_flags[descriptor] = 0
	_d_count[descriptor] = 0
	_d_offset[descriptor] = 0
	_d_refcount[descriptor] = 0
	_d_next_variant[descriptor] = NO_VARIANT
	if _d_generation[descriptor] >= IntMath.INT32_MAX - 1:
		_d_flags[descriptor] = FLAG_RETIRED
	else:
		_d_generation[descriptor] += 1
	for other: int in ROUTE_DESCRIPTOR_CAPACITY:
		if _d_next_variant[other] == descriptor:
			_d_next_variant[other] = NO_VARIANT


func _hold_route(descriptor: int, tick: int) -> void:
	"""Take a reference on a stored route and refresh its last-use tick."""
	_d_refcount[descriptor] += 1
	_d_use_low[descriptor] = _tick_low(tick)
	_d_use_high[descriptor] = _tick_high(tick)


func _release_route(descriptor: int, generation: int) -> void:
	"""Drop one reference, but only if the descriptor is still the one the holder referenced."""
	if descriptor < 0 or descriptor >= ROUTE_DESCRIPTOR_CAPACITY:
		return
	if _d_flags[descriptor] != FLAG_IN_USE or _d_generation[descriptor] != generation:
		return
	if _d_refcount[descriptor] > 0:
		_d_refcount[descriptor] -= 1


# --- the bounded route cell arena -----------------------------------------------------------------

func _acquire_arena(count: int) -> int:
	"""Reserve `count` contiguous route cells, reclaiming evictable space first. NO_ROW when full."""
	if _arena_used + count <= ROUTE_CELL_CAPACITY:
		var offset: int = _arena_used
		_arena_used += count
		return offset
	_reclaim_arena(count)
	if _arena_used + count <= ROUTE_CELL_CAPACITY:
		var offset: int = _arena_used
		_arena_used += count
		return offset
	return NO_ROW


func _reclaim_arena(needed: int) -> void:
	"""Evict unreferenced descriptors in `(last_use_tick, cache_id)` order, then compact once."""
	var free_cells: int = ROUTE_CELL_CAPACITY - _arena_used
	while free_cells < needed:
		var victim: int = _lowest_use_unreferenced()
		if victim == NO_ROW:
			break
		free_cells += _d_count[victim]
		_free_descriptor(victim)
	_compact_arena()


func _compact_arena() -> void:
	"""Slide every live route block down to close the gaps left by eviction.

	Descriptors are visited in ascending arena offset, so each block only ever moves to a LOWER
	offset and a forward element copy can never overwrite a cell it has yet to read.
	"""
	var cursor: int = 0
	var last_offset: int = -1
	while true:
		var best: int = _lowest_block_above(last_offset)
		if best == NO_ROW:
			break
		last_offset = _d_offset[best]
		_move_block(_d_offset[best], cursor, _d_count[best])
		_d_offset[best] = cursor
		cursor += _d_count[best]
	_arena_used = cursor


func _lowest_block_above(last_offset: int) -> int:
	"""The live, non-empty route block with the smallest arena offset above `last_offset`."""
	var best: int = NO_ROW
	for descriptor: int in ROUTE_DESCRIPTOR_CAPACITY:
		if _d_flags[descriptor] != FLAG_IN_USE or _d_count[descriptor] <= 0:
			continue
		if _d_offset[descriptor] <= last_offset:
			continue
		if best == NO_ROW or _d_offset[descriptor] < _d_offset[best]:
			best = descriptor
	return best


func _move_block(source: int, target: int, count: int) -> void:
	"""Copy one route block down the arena; a no-op when it is already in place."""
	if source == target:
		return
	for index: int in count:
		_arena[target + index] = _arena[source + index]


# --- the correctness reference, SET-MOVE-001 4 ---------------------------------------------------

func reference_cost_into(
	start_cell: int, goal_cell: int, clearance_class: int, out: IntMath.IntResult
) -> bool:
	"""Dijkstra with `h=0` from `start_cell` to `goal_cell`: the cost A* must agree with exactly.

	THIS IS A VALIDATION REFERENCE, NOT A GAMEPLAY PATH. It runs to completion rather than inside
	the 2048-expansion tick quota, spends none of that quota, publishes no route and stores nothing
	in the cache. It exists because the octile heuristic is only admissible on THIS lattice: before
	any nonlocal connection with its own transition cost is enabled, the expanded-graph Dijkstra
	reference -- not a modified heuristic -- is what a new search must be compared against.

	Refuses REFERENCE_SEARCH_BUSY rather than corrupting a request's in-progress builder state.
	"""
	if _active_request != NO_ROW:
		_last_refusal = REFUSE_REFERENCE_BUSY
		return out.refuse(REFUSE_REFERENCE_BUSY)
	var refusal: StringName = _reference_precondition(start_cell, goal_cell, clearance_class)
	if refusal != REFUSE_NONE:
		_last_refusal = refusal
		return out.refuse(refusal)
	var cost: int = _run_reference(start_cell, goal_cell, clearance_class)
	if cost < 0:
		_last_refusal = REFUSE_REFERENCE_UNREACHABLE
		return out.refuse(REFUSE_REFERENCE_UNREACHABLE)
	_last_refusal = REFUSE_NONE
	return out.succeed(cost)


func _reference_precondition(start_cell: int, goal_cell: int, clearance_class: int) -> StringName:
	"""Every input check the Dijkstra reference makes before it touches the builder."""
	if not SpatialWorld.is_cell(start_cell) or not SpatialWorld.is_cell(goal_cell):
		return REFUSE_INVALID_CELL
	if clearance_class < SpatialWorld.MIN_CLEARANCE_CLASS \
			or clearance_class > SpatialWorld.MAX_CLEARANCE_CLASS:
		return REFUSE_CLEARANCE
	if not _world.cell_passes_clearance(start_cell, clearance_class):
		return REFUSE_REFERENCE_UNREACHABLE
	if not _world.cell_passes_clearance(goal_cell, clearance_class):
		return REFUSE_REFERENCE_UNREACHABLE
	return REFUSE_NONE


func _run_reference(start_cell: int, goal_cell: int, clearance_class: int) -> int:
	"""Run the uniform-cost search to completion; -1 means the open set emptied without arriving."""
	_search_origin = start_cell
	_search_goal = goal_cell
	_search_macro = NO_ROW
	_search_clearance = clearance_class
	_use_heuristic = false
	_next_serial()
	_heap_size = 0
	_touch(start_cell, 0, NO_ROW)
	_heap_push(start_cell)
	var answer: int = -1
	var budget: int = SpatialWorld.CELL_COUNT
	while _heap_size > 0 and budget > 0:
		budget -= 1
		var cell: int = _heap_pop()
		_state[cell] = STATE_CLOSED
		if cell == goal_cell:
			answer = _g[cell]
			break
		_expand(cell)
	_use_heuristic = true
	_heap_size = 0
	return answer


# --- observation ----------------------------------------------------------------------------------

func queued_count() -> int:
	"""How many submitted requests are still waiting for their first expansion."""
	var total: int = 0
	var cursor: int = _queue_head
	while cursor != NO_ROW:
		total += 1
		cursor = _r_next_queue[cursor]
	return total


func live_request_count() -> int:
	"""How many request records are allocated, in any phase other than FREE."""
	return _live_requests


func has_active_search() -> bool:
	"""True while one request holds the shared A* builder mid-search."""
	return _active_request != NO_ROW


func active_request_row() -> int:
	"""The request currently holding the builder, or NO_ROW. Internal identity, never a result."""
	return _active_request


func descriptor_in_use_count() -> int:
	"""How many of the 256 route descriptors currently hold a stored route."""
	var total: int = 0
	for descriptor: int in ROUTE_DESCRIPTOR_CAPACITY:
		if _d_flags[descriptor] == FLAG_IN_USE:
			total += 1
	return total


func route_reference_count(descriptor: int) -> int:
	"""How many live requests reference a stored route. Referenced routes cannot be evicted."""
	if descriptor < 0 or descriptor >= ROUTE_DESCRIPTOR_CAPACITY:
		return 0
	return _d_refcount[descriptor]


func route_generation_of(descriptor: int) -> int:
	"""The generation stamp of a descriptor, which advances every time the row is reused."""
	if descriptor < 0 or descriptor >= ROUTE_DESCRIPTOR_CAPACITY:
		return 0
	return _d_generation[descriptor]


func route_variant_start(descriptor: int) -> int:
	"""The exact start a start-keyed variant belongs to, or NO_VARIANT for a macro bucket."""
	if descriptor < 0 or descriptor >= ROUTE_DESCRIPTOR_CAPACITY:
		return NO_VARIANT
	return _d_variant_start[descriptor]


func arena_used() -> int:
	"""How many of the 1048576 route cells are currently committed to stored routes."""
	return _arena_used


func total_expansions() -> int:
	"""Every finalized search cell this navigator has ever spent from the shared quota."""
	return _expansions_total


func expansions_remaining_this_tick() -> int:
	"""What is left of the 2048-expansion quota after the most recent `service()` call."""
	return _expansions_remaining


func storage_blocked_count() -> int:
	"""How many completed searches ARCH-PATH-005's bounded cache had nowhere to store."""
	return _storage_blocked_count


static func route_semantics_version() -> int:
	"""The published route-semantics version of this module: 2 since PATH-R02."""
	return ROUTE_SEMANTICS_VERSION


static func refuse_route_semantics(version: int) -> StringName:
	"""The refusal a section 9 restore owes a payload it cannot continue, or REFUSE_NONE.

	Anything that is not this module's current version is refused, including the version 1
	anchor-composition state PATH-R02 retires. There is no migration: a version 1 route stored a
	macro anchor's path for a start that may not be on it, and re-keying it would republish the
	same detour under a new name.
	"""
	if version == ROUTE_SEMANTICS_VERSION:
		return REFUSE_NONE
	return REFUSE_ROUTE_SEMANTICS


func served_revision() -> int:
	"""The map revision the last `service()` call ran against."""
	return _served_revision


func last_refusal() -> StringName:
	"""The refusal code from the most recent refusing call, or REFUSE_NONE after a success."""
	return _last_refusal
