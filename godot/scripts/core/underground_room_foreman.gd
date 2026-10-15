extends RefCounted
## Decision 1931 (C2.1): the foreman of one confirmed underground room. It derives BUILD-REQ-012's dig order once,
## then on every fixed tick advances Routes and its builders (1-4, ECON-001) and hands each idle builder the
## first open cube in that order. A cube whose contact or station is refused waits until another cube is finished
## (ADR1213's loop: an upper cube opens once the cubes below and beside it are paid). The room is done only when
## every one of its Sites is SUPPORTED_VOID with no live phase, read from Sites, never from this record.

const Builder := preload("res://scripts/core/underground_room_builder.gd")
const DigOrder := preload("res://scripts/core/underground_room_dig_order.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
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
const REFUSE_CREW: StringName = &"ROOM_FOREMAN_CREW"
const REFUSE_ROWS: StringName = &"ROOM_FOREMAN_TRAVEL_ROWS"
const REFUSE_STUCK: StringName = &"ROOM_FOREMAN_NO_CUBE_REACHABLE"


var _ctx: Builder.Context = null
var _room: Vector2i = NULL_REF
var _builders: Array[Builder] = []
var _order: DigOrder.Order = DigOrder.Order.new()
var _cube: PackedByteArray = PackedByteArray()
var _state: int = STATE_FAILED
var _error: StringName = REFUSE_SCOPE
var _last_refusal: StringName = &""
var _done: int = 0
var _registered: bool = false
var _epoch: int = 0 # Counts set-offs and parkings: a blocked builder rechecks only after one.
var _blocked_at: PackedInt32Array = PackedInt32Array()
var _mine: PackedInt32Array = PackedInt32Array() # Scratch for the set-off check; refilled, never kept.
var _theirs: PackedInt32Array = PackedInt32Array()


func configure(owners: Builder.Owners, target: Vector2i, storage: Vector2i, output: Vector2i,
		crew: Array[Builder.Crew]) -> StringName:
	"""Plan the dig order and bind 1-4 builders; nothing is opened, claimed or published here."""
	if owners == null or owners.provider == null or owners.sites == null or target == NULL_REF \
			or storage == NULL_REF or output == NULL_REF: return REFUSE_SCOPE
	var code: StringName = _crew_refusal(owners, crew)
	if code != &"": return code
	_ctx = _context(owners, storage, output)
	if _ctx.forward < 0 or _ctx.backward < 0: return REFUSE_ROWS
	var planned: DigOrder.Order = DigOrder.Order.new()
	code = DigOrder.order_into(owners.sites, owners.owner, target, planned)
	if code != &"": return code
	code = _bind_builders(crew)
	if code != &"": return code
	_room = target
	_order = planned
	_cube.resize(planned.keys.size())
	_cube.fill(CUBE_OPEN)
	_mark_finished()
	_state = STATE_DIGGING
	_error = &""
	return &""


static func _crew_refusal(owners: Builder.Owners, crew: Array[Builder.Crew]) -> StringName:
	"""1-4 distinct workers with distinct parking endpoints."""
	if crew.is_empty() or crew.size() > MAX_BUILDERS: return REFUSE_CREW
	for index: int in crew.size():
		if crew[index] == null: return REFUSE_CREW
		for other: int in index:
			if crew[other].worker == crew[index].worker or crew[other].parking == crew[index].parking: return REFUSE_CREW
	return &"" if owners.residents != null else REFUSE_SCOPE


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


func _bind_builders(crew: Array[Builder.Crew]) -> StringName:
	"""One builder per crew member, each starting idle on its own parking."""
	var made: Array[Builder] = []
	for member: Builder.Crew in crew:
		var builder: Builder = Builder.new()
		var code: StringName = builder.configure(_ctx, member)
		if code != &"": return code
		made.append(builder)
	_builders = made
	_blocked_at.resize(made.size())
	_blocked_at.fill(-1)
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
	if not _registered:
		var code: StringName = _register()
		if code != &"": return _halt(code)
	_ctx.owners.routes.advance_tick(tick)
	for index: int in _builders.size():
		var code: StringName = _advance_builder(index, tick)
		if code != &"": return _halt(code)
	if not _all_parked(): return &""
	if _done == _order.rows.size(): return _finish()
	if _next_open() < 0: return _halt(_last_refusal if _last_refusal != &"" else REFUSE_STUCK)
	return &""


func _advance_builder(index: int, tick: int) -> StringName:
	"""One builder's tick; a builder that has not set off waits until its cube's footprint is clear of the others'."""
	var builder: Builder = _builders[index]
	var was_idle: bool = builder.idle()
	var was_moving: bool = builder.in_motion()
	var code: StringName = &""
	if builder.at_column_end(): code = _up_or_home(builder, tick)
	elif was_idle: code = _dispatch(builder, tick)
	else: code = builder.advance(tick, _may_set_off(index))
	if code != &"": return code
	if was_moving != builder.in_motion() or was_idle != builder.idle(): _epoch += 1
	_collect(builder)
	if not was_idle and builder.idle(): _reopen() # A builder off the work may have been what blocked a cube.
	return &""


func _may_set_off(index: int) -> bool:
	"""ECON-001, deadlock-free: a builder sets off only when its whole footprint (way there, station, way back) meets
	no other builder's parked body or footprint. Builders whose footprints overlap therefore take turns."""
	var builder: Builder = _builders[index]
	if not builder.walking_next() or builder.in_motion(): return true
	if _blocked_at[index] == _epoch: return false # Nothing has set off or parked since the last check.
	_mine = builder.claim()
	for other: int in _builders.size():
		if other == index: continue
		_builders[other].occupied_into(_theirs)
		if _overlap(_mine, _theirs):
			_blocked_at[index] = _epoch
			return false
	return true


static func _overlap(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	"""Any half-open box of one list meets any box of the other."""
	@warning_ignore("integer_division") var count_a: int = a.size() / 6
	@warning_ignore("integer_division") var count_b: int = b.size() / 6
	for i: int in count_a:
		for j: int in count_b:
			var meets: bool = true
			for axis: int in 3:
				meets = meets and a[6 * i + axis] < b[6 * j + axis + 3] and b[6 * j + axis] < a[6 * i + axis + 3]
			if meets: return true
	return false


func _register() -> StringName:
	"""Every builder becomes a route actor on its parking before the first cube is dispatched."""
	for builder: Builder in _builders:
		var code: StringName = builder.register()
		if code != &"": return code
	_registered = true
	return &""


func _dispatch(builder: Builder, tick: int) -> StringName:
	"""Hand the idle builder the first open cube; a refused contact marks that cube until the next finished cube.
	A builder whose hour rests (or whose health forbids work) is not sent."""
	var at: int = _next_open()
	if at < 0 or not builder.may_work(): return &""
	var site: Vector2i = Vector2i(_order.rows[at], Sites.SITE_GENERATION)
	var code: StringName = builder.begin(at, site, _order.keys[at], tick)
	if builder.failed(): return code
	if code != &"":
		_cube[at] = CUBE_REFUSED
		_last_refusal = code
		return &""
	_cube[at] = CUBE_TAKEN
	return &""


func _up_or_home(builder: Builder, tick: int) -> StringName:
	"""Painted height: the next cube up the finished cube's column, if open, is taken from the same station;
	otherwise (none, or its contact refused) the builder walks home. During a rest hour it waits at the station."""
	if not builder.may_work(): return &""
	var at: int = builder.last_index() + 1
	if at < _cube.size() and _cube[at] == CUBE_OPEN and _same_column(at - 1, at):
		var code: StringName = builder.continue_column(at, Vector2i(_order.rows[at], Sites.SITE_GENERATION), _order.keys[at], tick)
		if builder.failed(): return code
		if code == &"":
			_cube[at] = CUBE_TAKEN
			return &""
		_cube[at] = CUBE_REFUSED
		_last_refusal = code
	return builder.go_home()


func _same_column(a: int, b: int) -> bool:
	"""Two order entries in one cell (the dig order keeps a column's cubes consecutive, bottom up)."""
	var plane: int = _ctx.owners.sites._domain.size_quanta.x * _ctx.owners.sites._domain.size_quanta.z
	return _order.keys[a] % plane == _order.keys[b] % plane


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
		if not builder.idle(): return false
	return true


func _finish() -> StringName:
	"""Every cube is done by Sites' own record and every builder has walked back to its parking."""
	_state = STATE_DONE
	return &""


func _halt(code: StringName) -> StringName:
	"""The first refusal stops the room for good and is kept for the alert; completed cubes stay paid."""
	_state = STATE_FAILED
	_error = code
	return code


func state() -> int:
	"""STATE_DIGGING, STATE_DONE or STATE_FAILED."""
	return _state


func is_running() -> bool:
	"""True while the room is still being dug."""
	return _state == STATE_DIGGING


func error() -> StringName:
	"""The refusal that stopped the room, or empty."""
	return _error


func room() -> Vector2i:
	"""The room being dug."""
	return _room


func done_cubes() -> int:
	"""Cubes finished by Sites' own record."""
	return _done


func total_cubes() -> int:
	"""Every Site of the room."""
	return _order.rows.size()


func order() -> DigOrder.Order:
	"""The planned dig order (read-only for status and tests)."""
	return _order


func builders() -> Array[Builder]:
	"""The bound builders (read-only for status and tests)."""
	return _builders
