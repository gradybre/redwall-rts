extends RefCounted
## Decision 1936: composing room digs in the running game. The host builds the room runtime when the Session's room
## owners are composed and binds the owners it borrows once the entry owners are (`owners_of`). An order then
## (P-1936-1 (a)) binds the room phases' contacts to its access the first time, and refuses a room on another access
## until a per-access binding exists; picks its crew; parks each builder off the access; and starts the dig. Nothing
## here pays, claims or digs: the runtime's foreman and the owners do.
##
## Decision 1991 (C3; Brendan, P-1990-4 (a) "Selected moles crew it"): an order may name its crew, 1-4 residents the
## player chose; with none named, the first idle adult mole that holds no Job and no tool, is not seeking food or
## rest and no dispatcher reserves digs (P-1936-2 (a)'s rule). A resident digs one room at a time, so an order whose
## crew is busy (a batch's later rooms, or every mole at work) is kept QUEUED with its crew, and `start_waiting`
## starts it on the first fixed tick that crew is free -- in room-row order, so a load resumes the same way. Only a
## crew that could never dig (no such resident, or one that is not a living adult mole free of tools) is refused.

const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Parking := preload("res://scripts/core/underground_room_parking.gd")
const Provider := preload("res://scripts/core/underground_room_world_bindings.gd")
const WorkFace := preload("res://scripts/core/underground_work_face.gd")
const EntryRuntime := preload("res://scripts/core/underground_entry_runtime.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_SCOPE: StringName = &"ROOM_DIG_SCOPE"
const REFUSE_OTHER_ACCESS: StringName = &"ROOM_DIG_OTHER_ACCESS"
## No resident could ever dig the room: no living adult mole free of tools (decision 1991: a busy one is waited for).
const REFUSE_NO_MOLE: StringName = &"ROOM_DIG_NO_IDLE_MOLE"
const REFUSE_NO_CELLS: StringName = &"ROOM_DIG_NO_SITES"
## Decision 1991: a named crew of more than four, or naming a resident twice.
const REFUSE_CREW_SIZE: StringName = &"ROOM_DIG_CREW_SIZE"
## Decision 1991: a named crew member who is not a living adult mole free of tools.
const REFUSE_CREW_MEMBER: StringName = &"ROOM_DIG_CREW_NOT_A_DIGGER"
## Decision 1991, internal: the crew is busy; the record keeps waiting (never an alert).
const WAIT: StringName = &"ROOM_DIG_WAITING_FOR_CREW"
## Decision 1991 (review C-1): on the fixed tick a room waiting for "the first idle mole" looks through one eighth of
## the resident slots, the window keyed by the tick (64 slots at 512), so the scan costs an eighth on every tick
## rather than a whole pass on each; such a room starts at most seven ticks later than a full scan would. A choice of
## cost, not a rule.
const IDLE_WINDOWS: int = 8


class Order extends RefCounted:
	## One room to dig: its access endpoint and retreat travel row (the order's way in), its three containers, and
	## (decision 1991) the crew the player named, as resident (slot, generation) pairs; empty for the first idle mole.
	var room: Vector2i = NULL_REF
	var access: Vector2i = NULL_REF
	var travel: int = -1
	var storage: Vector2i = NULL_REF
	var output: Vector2i = NULL_REF
	var staging: Vector2i = NULL_REF
	var crew: PackedInt32Array = PackedInt32Array()


class Idle extends RefCounted:
	## Decision 1991 (review C-1): one fixed tick's idle diggers, scanned once (lazily, by the first waiting room that
	## names no live crew) and handed out in slot order, so N waiting rooms cost one resident scan, not N.
	var scanned: bool = false
	var slots: PackedInt32Array = PackedInt32Array()
	var next: int = 0
	var from: int = 0
	var to: int = Residents.RESIDENT_CAPACITY
	var mole: int = -1 # The mole's species id, read once per tick.


static func owners_of(o: RefCounted) -> Builder.Owners:
	"""The Session's composed owners as a dig borrows them (`Retirement.Owners`, complete after the entry owners)."""
	var out: Builder.Owners = Builder.Owners.new()
	out.provider = o.world_bindings; out.sites = o.sites; out.jobs = o.jobs; out.work = o.work; out.routes = o.routes
	out.binding = o.world_routes; out.residents = o.residents; out.pool = o.reservations; out.inventory = o.inventory
	out.profiles = o.profiles; out.construction = o.construction; out.items = o.items; out.owner = o.space
	out.budget = o.budget; out.transforms = o.transforms; out.delivery = o.delivery; out.locations = o.locations
	return out


static func order(runtime: Runtime, placements: RefCounted, request: Order) -> StringName:
	"""Check the crew, bind or check the way in, queue the room with its crew, and start it at once when that crew is
	free; otherwise it waits QUEUED (`start_waiting`). An order whose parking or start is refused leaves no record
	behind (decision 1937)."""
	var owners: Builder.Owners = runtime.bound_owners() if runtime != null else null
	if owners == null or placements == null or request == null or owners.locations == null: return REFUSE_SCOPE
	var code: StringName = crew_refusal(owners, request.crew)
	if code == &"" and _room_box(owners.sites, request.room).is_empty(): code = REFUSE_NO_CELLS
	if code == &"": code = _contacts(runtime, owners, placements, request)
	if code == &"": code = runtime.order_room(request.room, request.storage, request.output, request.staging, request.crew)
	if code != &"": return code
	code = _start(runtime, owners, request.room, request.access)
	if code == WAIT: return &"" # Its crew is busy: it waits QUEUED and starts when the crew is free.
	if code != &"": runtime.cancel_queued(request.room)
	return code


static func crew_refusal(owners: Builder.Owners, crew: PackedInt32Array) -> StringName:
	"""Decision 1991: a named crew is 0-4 distinct residents (Foreman.MAX_BUILDERS, ECON-001), each one that could dig;
	with none named, some resident must be able to dig at all."""
	if crew.size() % 2 != 0 or crew.size() > 2 * Foreman.MAX_BUILDERS: return REFUSE_CREW_SIZE
	var seen: PackedInt32Array = PackedInt32Array()
	for at: int in range(0, crew.size(), 2):
		var slot: int = _slot_of(owners.residents, Vector2i(crew[at], crew[at + 1]))
		if slot < 0 or not could_dig(owners.residents, slot): return REFUSE_CREW_MEMBER
		if seen.has(slot): return REFUSE_CREW_SIZE
		seen.append(slot)
	if not crew.is_empty(): return &""
	var mole: int = _mole_id(owners.residents)
	for slot: int in Residents.RESIDENT_CAPACITY:
		if _could_dig_as(owners.residents, slot, mole): return &""
	return REFUSE_NO_MOLE


static func could_dig(residents: Residents, slot: int) -> bool:
	"""A living adult mole free of tools: one who digs with its claws (DEC-052) whenever it is idle."""
	return _could_dig_as(residents, slot, _mole_id(residents))


static func _mole_id(residents: Residents) -> int:
	"""The mole's compiled species id, or -1 when the catalog has none."""
	var id: IntMath.IntResult = residents.species_id(&"mole")
	return id.value if id.ok else -1


static func _could_dig_as(residents: Residents, slot: int, mole: int) -> bool:
	"""`could_dig` without allocating (review C-1): the cheap column reads first, the species by its raw id."""
	return mole >= 0 and residents.life_stage_code_of(slot) == Residents.LIFE_STAGE_ADULT \
		and residents._species[slot] == mole and residents.is_alive(slot) and not residents.has_equipped_tool(slot)


static func _slot_of(residents: Residents, ref: Vector2i) -> int:
	"""A live resident reference's slot, or -1. The kind is checked (ARCH-ID-003, review H-2): another kind's
	reference never names the resident at its typed row."""
	if ref.x < 0 or ref.y < 0 or not residents.directory().is_valid_of_kind(ref, Directory.KIND_RESIDENT): return -1
	return residents.directory().get_typed_row(ref)


static func start_waiting(runtime: Runtime, placements: RefCounted, tick: int = -1) -> Array[StringName]:
	"""Decision 1991: every QUEUED room whose crew is free now starts, in room-row order. A named member who can no
	longer dig is dropped (none left: the first idle mole digs, looked for in this tick's window of slots; with no
	tick, all of them). A start refused now (no parking, or the foreman's plan) forgets the record and is returned for
	its alert; the room stays confirmed and may be ordered again."""
	var refused: Array[StringName] = []
	var owners: Builder.Owners = runtime.bound_owners() if runtime != null else null
	if owners == null or placements == null or runtime.kept() == 0: return refused
	var waiting: Array[Vector2i] = []
	runtime.queued_into(waiting)
	var idle: Idle = Idle.new()
	idle.mole = _mole_id(owners.residents)
	if tick >= 0:
		@warning_ignore("integer_division") var width: int = Residents.RESIDENT_CAPACITY / IDLE_WINDOWS
		idle.from = (tick % IDLE_WINDOWS) * width
		idle.to = idle.from + width
	for room: Vector2i in waiting:
		var code: StringName = _start(runtime, owners, room, runtime.contacts_access(), idle)
		if code == WAIT: continue
		if code != &"":
			runtime.cancel_queued(room)
			refused.append(code)
	return refused


static func _start(runtime: Runtime, owners: Builder.Owners, room: Vector2i, access: Vector2i,
		idle: Idle = null) -> StringName:
	"""Start a QUEUED room now if its crew is free: park each builder off the access and hand the crew to a foreman.
	WAIT when the crew is busy. `idle` shares one resident scan across a tick's waiting rooms."""
	var crew: Array[Builder.Crew] = []
	if not _crew_into(runtime, owners, runtime.crew_of(room), crew, idle): return WAIT
	var code: StringName = _park_all(runtime, owners, room, access, crew)
	if code == &"": code = runtime.start_room(room, owners, crew)
	return code


static func _crew_into(runtime: Runtime, owners: Builder.Owners, named: PackedInt32Array,
		out: Array[Builder.Crew], idle: Idle = null) -> bool:
	"""The crew to start with now, or false while it is busy. Named members who can no longer dig are dropped; with
	none named (or none left), the first idle mole by slot."""
	out.clear()
	var mole: int = idle.mole if idle != null else _mole_id(owners.residents)
	for at: int in range(0, named.size(), 2):
		var slot: int = _slot_of(owners.residents, Vector2i(named[at], named[at + 1]))
		if slot < 0 or not _could_dig_as(owners.residents, slot, mole): continue
		if not _idle(runtime, owners, slot): return false
		out.append(_member(owners.residents, slot))
	if not out.is_empty(): return true
	var first: int = _first_idle(runtime, owners, mole, idle)
	if first < 0: return false
	out.append(_member(owners.residents, first))
	return true


static func _first_idle(runtime: Runtime, owners: Builder.Owners, mole: int, idle: Idle) -> int:
	"""The first idle digger by slot, or -1. With `idle`, the residents are scanned once per tick and each candidate
	is checked again when handed out (a room started earlier this tick may have taken it)."""
	if idle == null:
		for slot: int in Residents.RESIDENT_CAPACITY:
			if _could_dig_as(owners.residents, slot, mole) and _idle(runtime, owners, slot): return slot
		return -1
	if not idle.scanned:
		idle.scanned = true
		for slot: int in range(idle.from, idle.to):
			if _could_dig_as(owners.residents, slot, mole) and _idle(runtime, owners, slot): idle.slots.append(slot)
	while idle.next < idle.slots.size():
		var slot: int = idle.slots[idle.next]
		idle.next += 1
		if _idle(runtime, owners, slot): return slot
	return -1


static func _idle(runtime: Runtime, owners: Builder.Owners, slot: int) -> bool:
	"""P-1936-2 (a)'s rule for a resident free to dig now: no Job, not seeking food or rest (DEC-059), reserved by no
	dispatcher (the entry crew, another dig's builders)."""
	var reserves: Callable = owners.jobs._dispatch_reserves
	return owners.jobs.job_of(slot) == NULL_REF and not EntryRuntime._seeking(owners.jobs.needs(), slot) \
		and not runtime.reserves_resident(slot) and not (reserves.is_valid() and bool(reserves.call(slot)))


static func _member(residents: Residents, slot: int) -> Builder.Crew:
	"""One crew member (claws: no tool)."""
	var crew: Builder.Crew = Builder.Crew.new()
	crew.worker = residents.ref_of(slot)
	return crew


static func _park_all(runtime: Runtime, owners: Builder.Owners, room: Vector2i, access: Vector2i,
		crew: Array[Builder.Crew]) -> StringName:
	"""Each builder's parking, off the access, away from the room's cells and off every other builder's (decision
	1935's finding). Decision 1991 (review H-1): the first builder must park; a later member with no parking left off
	this access is left out of this dig (the access's geometry has room for fewer bodies) and stays free."""
	var ctx: Builder.Context = Foreman._context(owners, NULL_REF, NULL_REF) # Only its travel rows and content.
	if ctx.forward < 0 or ctx.backward < 0: return Foreman.REFUSE_ROWS
	var ask: Parking.Request = Parking.Request.new()
	ask.access = access; ask.forward = ctx.forward; ask.backward = ctx.backward; ask.content = ctx.content
	ask.room_box = _room_box(owners.sites, room)
	if ask.room_box.is_empty(): return REFUSE_NO_CELLS
	ask.taken = runtime.parkings()
	var containers: Array[Vector2i] = []
	runtime.containers_into(room, containers)
	for container: Vector2i in containers:
		if container != NULL_REF: ask.keep_clear.append(owners.inventory.spatial_location_of(container))
	for at: int in crew.size():
		var found: Array[Vector2i] = []
		var code: StringName = Parking.find_into(owners, ask, found)
		if code != &"" and at == 0: return code
		if code != &"":
			crew.resize(at)
			return &""
		crew[at].parking = found[0]
		ask.taken.append(found[0])
	return &""


static func access_refusal(runtime: Runtime, request: Order) -> StringName:
	"""Decision 1991: what `order` would refuse about the way in, read without binding anything, so Confirm can refuse
	before RoomOrders admits the room (review M-3): a full record pool, another access (P-1936-1 (a)), or, before the
	first bind, a retreat row out of range. The provider's own first bind can still refuse after admission."""
	var owners: Builder.Owners = runtime.bound_owners() if runtime != null else null
	if owners == null or request == null: return REFUSE_SCOPE
	if runtime.kept() >= Runtime.MAX_KEPT: return Runtime.REFUSE_CAPACITY
	if owners.provider._ordinary_routes != null:
		return &"" if _same_access(owners.provider, request) else REFUSE_OTHER_ACCESS
	return &"" if _travel_in_range(owners, request.travel) else REFUSE_SCOPE


static func _same_access(provider: Provider, request: Order) -> bool:
	"""The bound contacts are this order's access and retreat row."""
	return provider._ordinary_retreat == request.access and provider._ordinary_travel == request.travel


static func _travel_in_range(owners: Builder.Owners, travel: int) -> bool:
	"""A retreat travel row the live route profiles hold."""
	return travel >= 0 and travel < owners.profiles._live.header[1]


static func _contacts(runtime: Runtime, owners: Builder.Owners, placements: RefCounted, request: Order) -> StringName:
	"""P-1936-1 (a): the room phases' contacts bind once, to the first order's access and travel row (the runtime keeps
	the work face they borrow alive); a later order on another access is refused."""
	var provider: Provider = owners.provider
	if provider._ordinary_routes != null:
		if not _same_access(provider, request): return REFUSE_OTHER_ACCESS
		runtime.note_contacts(request.access, request.travel)
		return &""
	if not _travel_in_range(owners, request.travel): return REFUSE_SCOPE
	var code: StringName = bind_contacts(runtime, owners, placements, request.access, request.travel)
	if code == &"": runtime.note_contacts(request.access, request.travel)
	return code


static func bind_contacts(runtime: Runtime, owners: Builder.Owners, placements: RefCounted, access: Vector2i,
		travel: int) -> StringName:
	"""Bind the room phases' contacts to one access and retreat row, with the runtime's work face."""
	return owners.provider.bind_room_phase_contacts(owners.binding, runtime.work_face(), placements, access, travel,
		owners.profiles._live.quantities[travel], Provider.ROOM_CONTROL_BYTES)


static func _room_box(sites: Sites, room: Vector2i) -> PackedInt32Array:
	"""The room's cells on the floor plane (x0, z0, x1, z1), from its Sites; empty when it has none."""
	var box: PackedInt32Array = PackedInt32Array()
	for row: int in sites._count:
		if sites._present[row] != 1 or sites._room(row) != room: continue
		var origin: Vector3i = sites.origin_of(Vector2i(row, Sites.SITE_GENERATION))
		var side: int = Contract.QUANTUM_SIDE_U
		if box.is_empty(): box = PackedInt32Array([origin.x, origin.z, origin.x + side, origin.z + side])
		box[0] = mini(box[0], origin.x); box[1] = mini(box[1], origin.z)
		box[2] = maxi(box[2], origin.x + side); box[3] = maxi(box[3], origin.z + side)
	return box


static func rebind(runtime: Runtime, placements: RefCounted) -> StringName:
	"""After a load: bind the room phases' contacts again to the saved access and row (P-1936-1 (a)), unless the
	provider is already bound to them; bound to another, the record is refused."""
	var owners: Builder.Owners = runtime.bound_owners()
	var access: Vector2i = runtime.contacts_access()
	if access == NULL_REF: return &""
	if owners == null or placements == null: return REFUSE_SCOPE
	var provider: Provider = owners.provider
	if provider._ordinary_routes != null:
		return &"" if provider._ordinary_retreat == access and provider._ordinary_travel == runtime._contact_travel \
			else REFUSE_OTHER_ACCESS
	if runtime._contact_travel < 0 or runtime._contact_travel >= owners.profiles._live.header[1]: return REFUSE_SCOPE
	return bind_contacts(runtime, owners, placements, access, runtime._contact_travel)
