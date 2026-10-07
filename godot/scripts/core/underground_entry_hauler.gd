extends RefCounted
## ADR1210 (ADR1197 G4): fixed-tick haul of one step's missing inputs. The tooled worker walks to M, puts its tool
## in M's container, switches at rest to the tool-free rows (ADR1168 as amended), carries every whole unit from R's
## staging to M through Delivery (ADR1203 trip: WALK to stand R, turn, named lift row, CARRY to stand M, set-down),
## walks back onto M under the step's BUILD Job and re-equips. Every guard stays with Routes, Delivery and Gear.

const Jobs := preload("res://scripts/core/jobs.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Planner := preload("res://scripts/core/haul_planner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-stone-v7/grip_certificate.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const STAGE_APPROACH: int = 0
const STAGE_TO_SOURCE: int = 1
const STAGE_LIFT: int = 2
const STAGE_CARRY: int = 3
const STAGE_SET_DOWN: int = 4
const STAGE_HOME: int = 5
const STAGE_DONE: int = 6
const CLAIM_WINDOW: int = 100000
const REFUSE_PLAN: StringName = &"ENTRY_HAUL_PLAN"
const REFUSE_ITEM: StringName = &"ENTRY_HAUL_UNCERTIFIED_ITEM"
const REFUSE_STAGED: StringName = &"ENTRY_HAUL_NO_STAGED_STOCK"
const REFUSE_STAND: StringName = &"ENTRY_HAUL_NO_STAND"
const REFUSE_HELD: StringName = &"ENTRY_HAUL_ROUTE_HELD"


class Leg extends RefCounted:
	## One tooled travel leg toward M on an explicit source profile.
	var target: Vector2i = NULL_REF
	var profile: int = -1
	var revision: int = 0


var _o: RefCounted = null # The foreman's Owners packet (delivery and gear included).
var _crew: RefCounted = null
var _project: Vector2i = NULL_REF
var _home: int = -1
var _queue: PackedInt32Array = PackedInt32Array()
var _legs: Array[Leg] = []
var _leg: int = 0
var _trip: int = 0
var _job: int = -1
var _stage: int = STAGE_DONE
var _content: int = 0
var _store: Vector2i = NULL_REF
var _stand_source: Vector2i = NULL_REF
var _stand_store: Vector2i = NULL_REF
var _haul_mwu: int = 0
var _trips: int = 0
var _actor: Routes.Actor = Routes.Actor.new()


static func units_into(owners: RefCounted, container: Vector2i, items: PackedInt32Array, milli: PackedInt64Array,
		out: PackedInt32Array) -> StringName:
	"""Whole 1000-milli units per item that cover each bill beyond the container's free stock, in bill order."""
	out.clear()
	for line: int in items.size():
		if items.find(items[line]) != line: continue
		var need: int = -free_milli(owners.inventory, container, items[line])
		for other: int in range(line, items.size()):
			if items[other] == items[line]: need += int(milli[other])
		if need > 0 and Grip.carry_row_for(items[line]) < 0: return REFUSE_ITEM
		while need > 0:
			out.append(items[line])
			need -= Grip.QUANTITY_MILLI
	return &""


static func free_milli(inventory: RefCounted, container: Vector2i, item: int) -> int:
	"""Unreserved quantity of one item in one container."""
	var total: int = 0
	var lot: Vector2i = inventory.container_first_lot(container)
	while lot != NULL_REF:
		if inventory.lot_item_id(lot) == item: total += inventory.lot_available_milli(lot)
		lot = inventory.container_next_lot(lot)
	return total


func begin(owners: RefCounted, crew: RefCounted, project: Vector2i, home_job: int, queue: PackedInt32Array,
		legs: Array[Leg], start: Vector2i, tick: int) -> StringName:
	"""Plan the trips, create the first HAUL Job and set off for M with the tool still held."""
	if owners == null or owners.delivery == null or owners.gear == null or queue.is_empty() or legs.is_empty():
		return REFUSE_PLAN
	_o = owners; _crew = crew; _project = project; _home = home_job; _queue = queue; _legs = legs
	_content = owners.profiles.content_revision()
	_store = owners.inventory.spatial_location_of(crew.storage)
	_stand_source = _stand_beside(owners.inventory.spatial_location_of(crew.output))
	_stand_store = _stand_beside(_store)
	if _stand_source == NULL_REF or _stand_store == NULL_REF or legs[legs.size() - 1].target != _store: return REFUSE_STAND
	_leg = 0; _trip = 0; _stage = STAGE_APPROACH
	var code: StringName = _new_job()
	if code == &"" and _o.routes._resident_ref(_row()) == NULL_REF:
		code = _o.routes.admit_travel_actor(_crew.worker, _job_ref(), start, legs[0].profile, legs[0].revision,
			_content, 0, -1, _crew.tool)
	return _next_leg(tick) if code == &"" else code


func stage() -> int:
	"""Current haul stage."""
	return _stage


func trips() -> int:
	"""Whole units delivered to M so far."""
	return _trips


func haul_mwu() -> int:
	"""Lift and set-down Work accepted by the real Work owner across all trips."""
	return _haul_mwu


func advance(tick: int) -> StringName:
	"""One fixed tick of the current stage; instantaneous transitions chain inside it."""
	for step: int in 8:
		var before: int = _stage
		var code: StringName = _run(tick)
		if code != &"" or _stage == before or _stage == STAGE_DONE: return code
	return &""


func _run(tick: int) -> StringName:
	"""Dispatch exactly one stage."""
	match _stage:
		STAGE_APPROACH: return _approach(tick)
		STAGE_TO_SOURCE: return _to_source(tick)
		STAGE_LIFT: return _lift(tick)
		STAGE_CARRY: return _carry(tick)
		STAGE_SET_DOWN: return _set_down(tick)
		STAGE_HOME: return _home_leg(tick)
	return &""


func _row() -> int:
	"""The worker's typed Resident row."""
	return _o.residents.directory().get_typed_row(_crew.worker)


func _job_ref() -> Vector2i:
	"""Full generation of the current HAUL Job."""
	return _o.jobs.ref_of(_job)


func _new_job() -> StringName:
	"""A solo HAUL Job requested and sourced by the step's Project, assigned to the worker."""
	var made: RefCounted = _o.jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, Planner.HAUL_LOAD_MILLI_WU, 0)
	if not made.ok: return made.error
	_job = made.value
	var result: RefCounted = _o.jobs.set_requester(_job, _project)
	if result.ok: result = _o.jobs.set_source(_job, _project)
	if result.ok: result = _o.jobs.assign_worker(_row(), _job)
	return &"" if result.ok else result.error


func _next_leg(tick: int) -> StringName:
	"""Skip legs already reached; at M the tool goes down and the first trip starts."""
	if _o.routes.read_actor_into(_crew.worker, _actor) != &"": return REFUSE_PLAN
	while _leg < _legs.size() and _legs[_leg].target == _actor.location: _leg += 1
	if _leg >= _legs.size(): return _at_store(tick)
	var leg: Leg = _legs[_leg]
	var code: StringName = _o.routes.refresh_travel_actor(_crew.worker, _job_ref(), leg.profile, leg.revision,
		_content, 0, -1, _crew.tool)
	return _o.routes.request_route(_crew.worker, leg.target, tick) if code == &"" else code


func _approach(tick: int) -> StringName:
	"""Tooled source travel; each source-ready arrival starts the next leg."""
	var leg: Leg = _legs[_leg]
	var arrived: int = _arrived(leg.target, tick)
	if arrived < 0: return REFUSE_HELD
	if arrived == 0 or Routes.source_ready_leaf_refusal(_o.routes, _crew.worker, _job_ref(), leg.profile,
			leg.revision, _content) != &"": return &""
	_leg += 1
	return _next_leg(tick)


func _arrived(target: Vector2i, tick: int) -> int:
	"""Advance one route tick: 1 idle on the target, 0 still moving, -1 held."""
	_o.routes.advance_tick(tick)
	if _o.routes.read_actor_into(_crew.worker, _actor) != &"" or _actor.phase == Routes.PHASE_HELD: return -1
	return 1 if _actor.location == target and _actor.phase == Routes.PHASE_IDLE and _actor.edge == NULL_REF else 0


func _at_store(tick: int) -> StringName:
	"""At M: the tool goes into M's container, so every trip is tool-free from its first step."""
	var result: RefCounted = _o.gear.unequip(_crew.tool, _crew.storage, false)
	return _start_trip(tick) if result.ok else result.error


func _start_trip(tick: int) -> StringName:
	"""Switch to tool-free WALK, admit one whole unit with Delivery, then walk to R's stand."""
	var lot: Vector2i = _staged_lot(_queue[_trip])
	if lot == NULL_REF: return REFUSE_STAGED
	var code: StringName = _o.routes.refresh_actor(_crew.worker, _job_ref(), Profiles.MODE_WALK, 0, -1, NULL_REF)
	if code != &"": return code
	var admitted: RefCounted = _o.delivery.admit(_job_ref(), lot, Grip.QUANTITY_MILLI, tick + CLAIM_WINDOW)
	if not admitted.ok: return admitted.error
	var result: RefCounted = _o.jobs.set_state(_job, Jobs.JOB_STATE_TRAVEL)
	if not result.ok: return result.error
	_stage = STAGE_TO_SOURCE
	return _o.routes.request_route(_crew.worker, _stand_source, tick)


func _staged_lot(item: int) -> Vector2i:
	"""The first lot of the item at R's staging with at least one whole free unit."""
	var inventory: RefCounted = _o.inventory
	var lot: Vector2i = inventory.container_first_lot(_crew.output)
	while lot != NULL_REF:
		if inventory.lot_item_id(lot) == item and inventory.lot_available_milli(lot) >= Grip.QUANTITY_MILLI: return lot
		lot = inventory.container_next_lot(lot)
	return NULL_REF


func _to_source(tick: int) -> StringName:
	"""At R's stand: empty-handed turn to the grip heading, the item's named lift row, then Delivery's load entry."""
	var arrived: int = _arrived(_stand_source, tick)
	if arrived != 1: return REFUSE_HELD if arrived < 0 else &""
	var row: int = Grip.carry_row_for(_queue[_trip]) + 2 # ADR1206: 34 wood, 39 stone (yaw 16384 lift).
	var code: StringName = &""
	if _actor.yaw != Grip.QUARTER:
		code = WorldRoutes.turn_actor(_o.binding, _crew.worker, _job_ref(), Grip.QUARTER, Space.MAX_CHECKS)
	if code == &"": code = _grip(row)
	if code == &"": code = _o.delivery.begin_load(_job_ref())
	if code == &"": _stage = STAGE_LIFT
	return code


func _grip(row: int) -> StringName:
	"""Select one certified grip row explicitly; an empty lift is never chosen automatically in content 6."""
	return _o.routes.refresh_work_actor(_crew.worker, _job_ref(), row, 1, Grip.CONTENT_REVISION, 0, -1, NULL_REF)


func _work(tick: int) -> int:
	"""One Work tick of the handling phase: 1 finished, 0 continuing, -1 refused."""
	_o.routes.advance_tick(tick)
	var worked: RefCounted = _o.work.tick_solo(_job)
	if not worked.ok: return -1
	_haul_mwu += worked.accepted_mwu
	return 1 if worked.remaining_mwu == 0 else 0


func _lift(tick: int) -> StringName:
	"""Lift work, the guarded load, then the item's loaded gait to M's stand."""
	var done: int = _work(tick)
	if done != 1: return &"ENTRY_HAUL_WORK" if done < 0 else &""
	var loaded: RefCounted = _o.delivery.load_payload(_job_ref())
	if not loaded.ok: return loaded.error
	var code: StringName = _o.routes.refresh_actor(_crew.worker, _job_ref(), Profiles.MODE_CARRY, 0, -1, NULL_REF)
	if code == &"": code = _o.routes.request_route(_crew.worker, _stand_store, tick)
	if code == &"": _stage = STAGE_CARRY
	return code


func _carry(tick: int) -> StringName:
	"""The CARRY edge arrives on the grip heading; the item's named set-down row follows."""
	var arrived: int = _arrived(_stand_store, tick)
	if arrived != 1: return REFUSE_HELD if arrived < 0 else &""
	var code: StringName = _grip(Grip.carry_row_for(_queue[_trip]) + 4) # ADR1206: 36 wood, 41 stone.
	if code == &"": _stage = STAGE_SET_DOWN
	return code


func _set_down(tick: int) -> StringName:
	"""Set-down work and the guarded unload into M; then the next trip or the walk home."""
	var done: int = _work(tick)
	if done != 1: return &"ENTRY_HAUL_WORK" if done < 0 else &""
	var unloaded: RefCounted = _o.delivery.unload_payload(_job_ref())
	if not unloaded.ok: return unloaded.error
	_trips += 1
	_trip += 1
	var code: StringName = _retire_job()
	if code != &"": return code
	if _trip >= _queue.size(): return _go_home(tick)
	code = _new_job()
	return _start_trip(tick) if code == &"" else code


func _retire_job() -> StringName:
	"""A completed HAUL Job leaves the worker and its row, as the JobPlanner retires a completed service."""
	var result: RefCounted = _o.jobs.release_worker(_row())
	if result.ok: result = _o.jobs.destroy_job(_job)
	return &"" if result.ok else result.error


func _go_home(tick: int) -> StringName:
	"""The step's own BUILD Job takes the worker; still tool-free it walks from M's stand onto M."""
	_job = _home
	var result: RefCounted = _o.jobs.assign_worker(_row(), _home)
	if not result.ok: return result.error
	var code: StringName = _o.routes.refresh_actor(_crew.worker, _job_ref(), Profiles.MODE_WALK, 0, -1, NULL_REF)
	if code == &"": code = _o.routes.request_route(_crew.worker, _store, tick)
	if code == &"": _stage = STAGE_HOME
	return code


func _home_leg(tick: int) -> StringName:
	"""On M the worker takes its tool back from M's container."""
	var arrived: int = _arrived(_store, tick)
	if arrived != 1: return REFUSE_HELD if arrived < 0 else &""
	var result: RefCounted = _o.gear.equip(_crew.tool, _crew.worker)
	if not result.ok: return result.error
	_stage = STAGE_DONE
	return &""


func _stand_beside(storage: Vector2i) -> Vector2i:
	"""The one live WORK endpoint at the certified stand offset from a storage endpoint (Delivery re-proves it)."""
	var bank: Locations.Bank = _o.locations._live
	var capacity: int = _o.locations._capacity
	if storage == NULL_REF or bank.present[storage.x] != 1: return NULL_REF
	var point: Vector3i = _point(bank, capacity, storage.x) - Grip.stock_offset(Grip.QUARTER)
	var found: Vector2i = NULL_REF
	for at: int in capacity:
		if bank.present[at] != 1 or bank.i32[Locations.ROLE * capacity + at] != Locations.ROLE_WORK: continue
		if _point(bank, capacity, at) != point: continue
		if found != NULL_REF: return NULL_REF
		found = Vector2i(at, bank.i32[Locations.GENERATION * capacity + at])
	return found


static func _point(bank: Locations.Bank, capacity: int, row: int) -> Vector3i:
	"""Exact packed endpoint point."""
	return Vector3i(bank.i32[Locations.X * capacity + row], bank.i32[Locations.Y * capacity + row],
		bank.i32[Locations.Z * capacity + row])
