extends RefCounted
## Decision 1933 (C2.1): the foreman of one confirmed underground room. It derives BUILD-REQ-012's dig order once,
## then on every fixed tick advances Routes and its builders (1-4, ECON-001) and hands each idle builder the first
## open cube in that order; a builder that finished a cube is sent up the same column first (painted height). A
## cube whose contact or station is refused waits until another cube is finished or a builder parks (ADR1213's loop).
## The room is done only when every one of its Sites is SUPPORTED_VOID with no live phase, re-read from Sites.
## A refusal stops the room: each builder's open phase is then released (unpaid ones cancelled), never left holding a
## resident.

const Builder := preload("res://scripts/core/underground_room_builder.gd")
const DigOrder := preload("res://scripts/core/underground_room_dig_order.gd")
const Footprint := preload("res://scripts/core/underground_room_footprint.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Progress := preload("res://scripts/core/underground_room_progress.gd")
const EntryProgress := preload("res://scripts/core/underground_entry_progress.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## ECON-001: a project has at most 4 builders, at most one worker at each quantum's face.
const MAX_BUILDERS: int = 4
const CUBE_OPEN: int = 0
const CUBE_TAKEN: int = 1
const CUBE_DONE: int = 2
const CUBE_REFUSED: int = 3
const STATE_DIGGING: int = 0
const STATE_DONE: int = 1
const STATE_FAILED: int = 2
const REFUSE_SCOPE: StringName = &"ROOM_FOREMAN_SCOPE"
const REFUSE_STATE: StringName = &"ROOM_FOREMAN_STATE"
const REFUSE_CREW: StringName = &"ROOM_FOREMAN_CREW"
const REFUSE_ROWS: StringName = &"ROOM_FOREMAN_TRAVEL_ROWS"
const REFUSE_STUCK: StringName = &"ROOM_FOREMAN_NO_CUBE_REACHABLE"
## Every builder that could still move waits on another's body or footprint: nothing can ever change.
const REFUSE_BLOCKED: StringName = &"ROOM_FOREMAN_CREW_BLOCKED"
const REFUSE_NOT_DONE: StringName = &"ROOM_FOREMAN_SITES_NOT_DONE"
## Decision 1991, P-1990-5 (a): the player stopped the dig ("Stop digging"); not a fault.
const REFUSE_PLAYER_STOP: StringName = &"ROOM_DIG_STOPPED"


var _ctx: Builder.Context = null
var _room: Vector2i = NULL_REF
var _builders: Array[Builder] = []
var _order: DigOrder.Order = DigOrder.Order.new()
var _cube: PackedByteArray = PackedByteArray()
var _state: int = STATE_FAILED
var _error: StringName = REFUSE_SCOPE
var _abandon_error: StringName = &""
var _last_refusal: StringName = &""
var _done: int = 0
var _registered: bool = false
var _epoch: int = 0 # Counts changes to any builder's stage, motion or footprint: a blocked builder rechecks after one.
var _blocked_at: PackedInt64Array = PackedInt64Array()
var _blocked: PackedByteArray = PackedByteArray()
var _blocked_ticks: int = 0
var _column_tries: int = 0


func configure(owners: Builder.Owners, target: Vector2i, storage: Vector2i, output: Vector2i, staging: Vector2i,
		crew: Array[Builder.Crew]) -> StringName:
	"""Plan the dig order and bind 1-4 builders; nothing is opened, claimed or published here. `staging` (or null)
	is the same-level container a BRACE's missing inputs are hauled from when a Delivery is bound (decision 1934)."""
	if _state == STATE_DIGGING: return REFUSE_STATE
	if not _owners_complete(owners) or target == NULL_REF or storage == NULL_REF or output == NULL_REF \
			or staging == storage: return REFUSE_SCOPE
	var code: StringName = _crew_refusal(crew)
	if code != &"": return code
	var ctx: Builder.Context = _context(owners, storage, output)
	ctx.staging = staging
	if ctx.forward < 0 or ctx.backward < 0: return REFUSE_ROWS
	var planned: DigOrder.Order = DigOrder.Order.new()
	code = DigOrder.order_into(owners.sites, owners.owner, target, planned)
	if code == &"": code = _bind_builders(ctx, crew)
	if code != &"": return code
	_room = target
	planned.keys.clear() # Decision 1937 (P-1937-1 E): a key is read from Sites when needed, and only the planning
	planned.distance.clear() # sort reads the distance, so each Site keeps 5 B (its row and mark).
	_order = planned
	_cube.resize(planned.rows.size())
	_cube.fill(CUBE_OPEN)
	_mark_finished()
	_state = STATE_DIGGING
	_error = &""
	return &""


static func _owners_complete(o: Builder.Owners) -> bool:
	"""Every borrowed owner is present (a missing one refuses rather than failing later)."""
	return o != null and o.provider != null and o.sites != null and o.jobs != null and o.work != null \
		and o.routes != null and o.binding != null and o.residents != null and o.pool != null and o.inventory != null \
		and o.profiles != null and o.construction != null and o.items != null and o.owner != null \
		and o.budget != null and o.transforms != null


static func _crew_refusal(crew: Array[Builder.Crew]) -> StringName:
	"""1-4 distinct workers with distinct parking endpoints."""
	if crew.is_empty() or crew.size() > MAX_BUILDERS: return REFUSE_CREW
	for index: int in crew.size():
		if crew[index] == null: return REFUSE_CREW
		for other: int in index:
			if crew[other].worker == crew[index].worker or crew[other].parking == crew[index].parking: return REFUSE_CREW
	return &""


static func _context(owners: Builder.Owners, storage: Vector2i, output: Vector2i) -> Builder.Context:
	"""The provider's bound retreat row and its forward partner at the same heading (ADR1213)."""
	var ctx: Builder.Context = Builder.Context.new()
	ctx.owners = owners
	ctx.content = owners.profiles.content_revision()
	ctx.storage = storage
	ctx.output = output
	ctx.backward = owners.provider._ordinary_travel
	var profiles: Profiles = owners.profiles
	if ctx.backward < 0 or ctx.backward >= profiles._live.header[1]: return ctx
	var yaw: int = profiles._live.fields[Profiles.F_YAW * profiles._profile_capacity + ctx.backward]
	ctx.forward = Itinerary.family_row(profiles, ctx.backward, yaw, Profiles.POLICY_READY_FORWARD)
	return ctx


func _bind_builders(ctx: Builder.Context, crew: Array[Builder.Crew]) -> StringName:
	"""One builder per crew member, each starting idle on its own parking."""
	var made: Array[Builder] = []
	for member: Builder.Crew in crew:
		var builder: Builder = Builder.new()
		var code: StringName = builder.configure(ctx, member)
		if code != &"": return code
		made.append(builder)
	_ctx = ctx
	_builders = made
	_blocked_at.resize(made.size())
	_blocked_at.fill(-1)
	_blocked.resize(made.size())
	_blocked.fill(0)
	return &""


func _mark_finished() -> void:
	"""Cubes already SUPPORTED_VOID with no live phase are done before anyone is sent."""
	_done = 0
	for at: int in _order.rows.size():
		if _finished(_order.rows[at]):
			_cube[at] = CUBE_DONE
			_done += 1


func _finished(row: int) -> bool:
	"""Sites' own record: the quantum is a supported void and no phase Project is live on it."""
	var sites: Sites = _ctx.owners.sites
	return sites._phase[row] == Sites.SUPPORTED_VOID and sites.project_of(Vector2i(row, Sites.SITE_GENERATION)) == NULL_REF


func advance(tick: int) -> StringName:
	"""One fixed tick: Routes once, then every builder; idle builders take the next open cube in order."""
	if _state != STATE_DIGGING: return _error
	if _done == _order.rows.size() and _all_parked(): return _finish()
	for builder: Builder in _builders:
		if builder.lost(): return _halt(Builder.REFUSE_LOST) # In every stage, before any owner is touched.
	var arrived: StringName = _arrive()
	if arrived != &"": return _halt(arrived)
	if _walking_in(): return &"" # ADR1219: no work moves before the whole crew has arrived.
	_ctx.owners.routes.advance_tick(tick)
	for index: int in _builders.size():
		var code: StringName = _advance_builder(index, tick)
		if code != &"": return _halt(code)
	if _frozen(): return _halt(REFUSE_BLOCKED)
	if not _all_parked(): return &""
	if _done == _order.rows.size(): return _finish()
	if _next_open() < 0: return _halt(_last_refusal if _last_refusal != &"" else REFUSE_STUCK)
	return &""


func _advance_builder(index: int, tick: int) -> StringName:
	"""One builder's tick (`advance` has already stopped the room for a lost builder); one that has not set off waits
	until its cube's footprint is clear of the others'."""
	var builder: Builder = _builders[index]
	_blocked[index] = 0
	if builder.walking(): return &"" # Still on its walk in: no cube yet.
	var was_idle: bool = builder.idle()
	var before: Vector3i = Vector3i(builder.stage(), int(builder.in_motion()), builder.footprint_serial())
	var code: StringName = &""
	if builder.at_column_end(): code = _up_or_home(builder, tick)
	elif was_idle: code = _dispatch(builder, tick)
	else: code = builder.advance(tick, _may_set_off(index))
	if code != &"": return code
	if before != Vector3i(builder.stage(), int(builder.in_motion()), builder.footprint_serial()): _epoch += 1
	_collect(builder)
	if not was_idle and builder.idle(): _reopen() # A builder off the work may have been what blocked a cube.
	return &""


func _may_set_off(index: int) -> bool:
	"""ECON-001: a builder sets off only when its whole footprint (way there, station, way back) meets no other
	builder's body or footprint, so builders whose footprints overlap take turns. A builder still blocked when
	nothing can move any more is caught by `_frozen` (ROOM_FOREMAN_CREW_BLOCKED)."""
	var builder: Builder = _builders[index]
	if not builder.walking_next() or builder.in_motion(): return true
	if _blocked_at[index] != _epoch:
		_blocked_at[index] = -1
		for other: int in _builders.size():
			if other != index and Footprint.overlap(builder.claim(), _builders[other].occupied()):
				_blocked_at[index] = _epoch
				break
	if _blocked_at[index] != _epoch: return true
	_blocked[index] = 1
	_blocked_ticks += 1
	return false


func _frozen() -> bool:
	"""Some builder is blocked, and every builder is either blocked (by what is still there: nothing changed since its
	check this tick) or parked with no open cube to take."""
	var any: bool = false
	for index: int in _builders.size():
		if _blocked[index] == 1:
			if _blocked_at[index] != _epoch: return false # Something moved after the check: look again next tick.
			any = true
		elif not _builders[index].idle() or _next_open() >= 0:
			return false
	return any


func _arrive() -> StringName:
	"""P-1933-1 (a): on the first tick every builder sets off on its walk in; each tick the walks advance and a
	builder arriving is registered on its parking, in crew order, so each occupancy proof sees the ones already
	registered. No cube is given before the whole crew has arrived (as ADR1219 registers before any work moves)."""
	for builder: Builder in _builders:
		var code: StringName = builder.begin_walk_in() if not _registered else builder.advance_walk()
		if code != &"": return code
	_registered = true
	return &""


func _walking_in() -> bool:
	"""Some builder is still on its walk in."""
	for builder: Builder in _builders:
		if builder.walking(): return true
	return false


func crew_out() -> bool:
	"""Some builder is still underground (registered, or walking in or out)."""
	for builder: Builder in _builders:
		if builder.underground(): return true
	return false


func shed_crew() -> void:
	"""After the dig (done or stopped), a builder that is out (no actor, no walk) is forgotten, so the dig keeps only
	the builders still underground, as the save writes them (decision 1937): nothing it keeps can act on a resident
	another dig may pick next."""
	if is_running(): return
	for index: int in range(_builders.size() - 1, -1, -1):
		if not _builders[index].underground():
			_builders.remove_at(index)
			_blocked_at.remove_at(index)
	_blocked.resize(_builders.size())
	_blocked.fill(0)


func advance_out(tick: int) -> StringName:
	"""P-1936-3 (a): after the dig (done or stopped) each builder leaves from rest and walks back out; one walking
	out advances. Routes still runs for an actor finishing the step it was on."""
	if is_running() or not crew_out(): return &""
	_ctx.owners.routes.advance_tick(tick)
	for builder: Builder in _builders:
		var code: StringName = builder.advance_walk() if builder.walking() else builder.leave()
		if code != &"": return code
	return &""


func _dispatch(builder: Builder, tick: int) -> StringName:
	"""Hand the idle builder the first open cube; a refused contact marks that cube until the next finished cube or
	parking. A builder whose hour rests (or whose health forbids work) is not sent; a busy cold lease is retried."""
	if not builder.may_work(): return &""
	var at: int = _next_open()
	if at < 0: return &""
	var code: StringName = builder.begin(at, Vector2i(_order.rows[at], Sites.SITE_GENERATION), _key(at), tick)
	return _taken(builder, at, code)


func _taken(builder: Builder, at: int, code: StringName) -> StringName:
	"""Record what a begin or continue did to cube `at`; only the builder's own failure stops the room."""
	if builder.failed(): return code
	if code == Budget.REFUSE_BUSY: return &""
	_cube[at] = CUBE_TAKEN if code == &"" else CUBE_REFUSED
	if code != &"": _last_refusal = code
	return &""


func _up_or_home(builder: Builder, tick: int) -> StringName:
	"""Painted height: the next cube up the finished cube's column, if open, is taken from the same station;
	otherwise (none, or its contact refused) the builder walks home. During a rest hour it waits at the station."""
	if not builder.may_work(): return &""
	var at: int = builder.last_index() + 1
	if at < _cube.size() and _cube[at] == CUBE_OPEN and _same_column(at - 1, at):
		_column_tries += 1
		var code: StringName = builder.continue_column(at, Vector2i(_order.rows[at], Sites.SITE_GENERATION),
			_key(at), tick)
		code = _taken(builder, at, code)
		if code != &"" or not builder.at_column_end(): return code
	return builder.go_home()


func _same_column(a: int, b: int) -> bool:
	"""Two order entries in one cell (the dig order keeps a column's cubes consecutive, bottom up)."""
	var plane: int = _ctx.owners.sites._domain.size_quanta.x * _ctx.owners.sites._domain.size_quanta.z
	return _key(a) % plane == _key(b) % plane


func _key(at: int) -> int:
	"""One order entry's Site key, Sites' own lattice rank of the cube (decision 1937: not kept in the order)."""
	return _ctx.owners.sites._site_key[_order.rows[at]]


func _next_open() -> int:
	"""The first cube in dig order nobody holds, has finished or has been refused since the last progress."""
	for at: int in _cube.size():
		if _cube[at] == CUBE_OPEN: return at
	return -1


func _collect(builder: Builder) -> void:
	"""A settled FINISH is progress: the cube is done and every refused cube may be tried again."""
	var at: int = builder.take_finished()
	if at < 0: return
	_cube[at] = CUBE_DONE if _finished(_order.rows[at]) else CUBE_OPEN
	_done += 1 if _cube[at] == CUBE_DONE else 0
	_reopen()


func _reopen() -> void:
	"""Progress, or a builder walking off the work, makes every refused cube worth trying again."""
	for index: int in _cube.size():
		if _cube[index] == CUBE_REFUSED: _cube[index] = CUBE_OPEN


func _all_parked() -> bool:
	"""Every builder is idle on its parking: the room can only finish, or be found stuck, then."""
	for builder: Builder in _builders:
		if not builder.idle() or builder.walking(): return false
	return true


func _finish() -> StringName:
	"""Done only when Sites' own record shows every cube finished, and every builder is parked."""
	for row: int in _order.rows:
		if not _finished(row): return _halt(REFUSE_NOT_DONE)
	_state = STATE_DONE
	return &""


func _halt(code: StringName) -> StringName:
	"""The first refusal stops the room for good and is kept for the alert; completed cubes stay paid. Every builder
	then releases its open phase (unpaid ones are cancelled); the first such refusal is kept apart."""
	_state = STATE_FAILED
	_error = code
	for builder: Builder in _builders:
		var released: StringName = builder.abandon()
		if released != &"" and _abandon_error == &"": _abandon_error = released
	return code


func stop() -> StringName:
	"""Decision 1991, P-1990-5 (a): the player's Stop, through the one stopping path (`_halt`): each builder's open
	phase is released (an unpaid one cancelled, a paid one kept for a re-order to take over) and the crew walks out
	from rest. Only a running dig stops."""
	if _state != STATE_DIGGING: return REFUSE_STATE
	_halt(REFUSE_PLAYER_STOP)
	return &""


func reserves_resident(resident_slot: int) -> bool:
	"""One of this dig's builders, while the dig runs or while that builder is still underground."""
	for builder: Builder in _builders:
		if builder.worker_row() == resident_slot and (is_running() or builder.underground()): return true
	return false


func state() -> int:
	"""STATE_DIGGING, STATE_DONE or STATE_FAILED."""
	return _state


func is_running() -> bool:
	"""True while the room is still being dug."""
	return _state == STATE_DIGGING


func error() -> StringName:
	"""The refusal that stopped the room, or empty."""
	return _error


func abandon_error() -> StringName:
	"""The first refusal met while releasing the builders' open phases after a stop, or empty."""
	return _abandon_error


func room() -> Vector2i:
	"""The room being dug."""
	return _room


func done_cubes() -> int:
	"""Cubes finished by Sites' own record."""
	return _done


func total_cubes() -> int:
	"""Every Site of the room."""
	return _order.rows.size()


func blocked_ticks() -> int:
	"""Builder-ticks spent waiting for another builder's body or footprint (ECON-001 turns)."""
	return _blocked_ticks


func column_tries() -> int:
	"""Times a builder that had just finished a cube was offered the next cube up its column."""
	return _column_tries


func order() -> DigOrder.Order:
	"""The planned dig order (read-only for status and tests)."""
	return _order


func builders() -> Array[Builder]:
	"""The bound builders (read-only for status and tests)."""
	return _builders


# --- Decision 1936: save and load (section 6 `underground_room_progress`) -------------------------------------------

func write_state(w: EntryProgress.Writer) -> void:
	"""This dig: room, state, codes, ledgers and latch, epoch, context, then (while it runs) its order and marks, and
	each builder it keeps after its blocked epoch (after the dig, only those still underground: `shed_crew`)."""
	w.ref(_room)
	w.i32(_state)
	for value: StringName in [_error, _abandon_error, _last_refusal]:
		w.code(value)
	w.i32(_done)
	w.flag(_registered)
	w.i64(_epoch)
	w.i64(_blocked_ticks)
	w.i32(_column_tries)
	_write_context(w)
	var running: bool = is_running()
	w.i32(_order.rows.size() if running else 0)
	if running:
		for at: int in _order.rows.size():
			w.i32(_order.rows[at])
			w.i32(_cube[at])
	w.i32(_builders.size())
	for index: int in _builders.size():
		w.i64(_blocked_at[index])
		_builders[index].write_state(w)


func _write_context(w: EntryProgress.Writer) -> void:
	"""The pinned content, the two travel rows and the three containers."""
	w.i64(_ctx.content)
	w.i32(_ctx.forward)
	w.i32(_ctx.backward)
	w.ref(_ctx.storage)
	w.ref(_ctx.output)
	w.ref(_ctx.staging)


func read_state(r: EntryProgress.Reader, owners: Builder.Owners) -> StringName:
	"""Decode a saved dig into this fresh foreman under the restored owners; the order's keys are read again from
	Sites and each builder's footprint is swept again from its plan."""
	if _ctx != null or owners == null: return Progress.REFUSE_TARGET
	_room = r.ref()
	_state = r.ranged(STATE_DIGGING, STATE_FAILED)
	_error = r.code()
	_abandon_error = r.code()
	_last_refusal = r.code()
	_done = r.ranged(0, Progress.MAX_SITES)
	_registered = r.flag()
	_epoch = r.i64()
	_blocked_ticks = r.i64()
	_column_tries = r.i32()
	_ctx = _read_context(r, owners)
	var code: StringName = _read_order(r, owners)
	if code != &"": return code
	for index: int in r.ranged(0, MAX_BUILDERS):
		_blocked_at.append(r.i64())
		var builder: Builder = Builder.new()
		code = builder.read_state(r, _ctx)
		if code != &"": return code
		_builders.append(builder)
	_blocked.resize(_builders.size())
	_blocked.fill(0)
	return &"" if (_state == STATE_FAILED) == (_error != &"") else Progress.REFUSE_SHAPE


static func _read_context(r: EntryProgress.Reader, owners: Builder.Owners) -> Builder.Context:
	"""The saved context, under the restored owners."""
	var ctx: Builder.Context = Builder.Context.new()
	ctx.owners = owners
	ctx.content = r.i64()
	ctx.forward = r.i32()
	ctx.backward = r.i32()
	ctx.storage = r.ref()
	ctx.output = r.ref()
	ctx.staging = r.ref()
	return ctx


func _read_order(r: EntryProgress.Reader, owners: Builder.Owners) -> StringName:
	"""The running dig's Site rows and marks (each key is read from Sites when needed, as in play)."""
	var sites: Sites = owners.sites
	_order = DigOrder.Order.new()
	for at: int in r.ranged(0, Progress.MAX_SITES):
		var row: int = r.i32()
		var mark: int = r.ranged(CUBE_OPEN, CUBE_REFUSED)
		var site: Vector2i = Vector2i(row, Sites.SITE_GENERATION)
		if not sites.is_live_site(site): return Progress.REFUSE_SHAPE
		_order.rows.append(row)
		_cube.append(mark)
	return &""
