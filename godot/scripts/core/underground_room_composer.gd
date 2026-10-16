extends RefCounted
## Decision 1936: composing room digs in the running game. The host builds the room runtime when the Session's room
## owners are composed and binds the owners it borrows once the entry owners are (`owners_of`). An order then
## (P-1936-1 (a)) binds the room phases' contacts to its access the first time, and refuses a room on another access
## until a per-access binding exists; (P-1936-2 (a)) picks one builder, the first idle adult mole that holds no Job
## and no tool and that no dispatcher reserves; parks it off the access; and starts the dig. Nothing here pays,
## claims or digs: the runtime's foreman and the owners do.

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
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_SCOPE: StringName = &"ROOM_DIG_SCOPE"
const REFUSE_OTHER_ACCESS: StringName = &"ROOM_DIG_OTHER_ACCESS"
const REFUSE_NO_MOLE: StringName = &"ROOM_DIG_NO_IDLE_MOLE"
const REFUSE_NO_CELLS: StringName = &"ROOM_DIG_NO_SITES"


class Order extends RefCounted:
	## One room to dig: its access endpoint and retreat travel row (the order's way in), and its three containers.
	var room: Vector2i = NULL_REF
	var access: Vector2i = NULL_REF
	var travel: int = -1
	var storage: Vector2i = NULL_REF
	var output: Vector2i = NULL_REF
	var staging: Vector2i = NULL_REF


static func owners_of(o: RefCounted) -> Builder.Owners:
	"""The Session's composed owners as a dig borrows them (`Retirement.Owners`, complete after the entry owners)."""
	var out: Builder.Owners = Builder.Owners.new()
	out.provider = o.world_bindings; out.sites = o.sites; out.jobs = o.jobs; out.work = o.work; out.routes = o.routes
	out.binding = o.world_routes; out.residents = o.residents; out.pool = o.reservations; out.inventory = o.inventory
	out.profiles = o.profiles; out.construction = o.construction; out.items = o.items; out.owner = o.space
	out.budget = o.budget; out.transforms = o.transforms; out.delivery = o.delivery; out.locations = o.locations
	return out


static func order(runtime: Runtime, placements: RefCounted, request: Order) -> StringName:
	"""Bind or check the way in, pick the builder, queue the room, park the builder and start the dig. An order whose
	parking or start is refused leaves no record behind (decision 1937)."""
	var owners: Builder.Owners = runtime.bound_owners() if runtime != null else null
	if owners == null or placements == null or request == null or owners.locations == null: return REFUSE_SCOPE
	var code: StringName = _contacts(runtime, owners, placements, request)
	var crew: Array[Builder.Crew] = []
	if code == &"": code = _builder_into(runtime, owners, crew)
	if code == &"": code = runtime.order_room(request.room, request.storage, request.output, request.staging)
	if code != &"": return code
	code = _park(runtime, owners, request, crew[0])
	if code == &"": code = runtime.start_room(request.room, owners, crew)
	if code != &"": runtime.cancel_queued(request.room)
	return code


static func _contacts(runtime: Runtime, owners: Builder.Owners, placements: RefCounted, request: Order) -> StringName:
	"""P-1936-1 (a): the room phases' contacts bind once, to the first order's access and travel row (the runtime keeps
	the work face they borrow alive); a later order on another access is refused."""
	var provider: Provider = owners.provider
	if provider._ordinary_routes != null:
		if provider._ordinary_retreat != request.access or provider._ordinary_travel != request.travel:
			return REFUSE_OTHER_ACCESS
		runtime.note_contacts(request.access, request.travel)
		return &""
	if request.travel < 0 or request.travel >= owners.profiles._live.header[1]: return REFUSE_SCOPE
	var code: StringName = bind_contacts(runtime, owners, placements, request.access, request.travel)
	if code == &"": runtime.note_contacts(request.access, request.travel)
	return code


static func bind_contacts(runtime: Runtime, owners: Builder.Owners, placements: RefCounted, access: Vector2i,
		travel: int) -> StringName:
	"""Bind the room phases' contacts to one access and retreat row, with the runtime's work face."""
	return owners.provider.bind_room_phase_contacts(owners.binding, runtime.work_face(), placements, access, travel,
		owners.profiles._live.quantities[travel], Provider.ROOM_CONTROL_BYTES)


static func _builder_into(runtime: Runtime, owners: Builder.Owners, out: Array[Builder.Crew]) -> StringName:
	"""P-1936-2 (a): the first living adult mole by resident slot that holds no Job and no tool, is not tired or
	hungry (DEC-059) and is reserved by no dispatcher (the entry crew, another dig's builders). Claws need no tool."""
	var residents: Residents = owners.residents
	var reserves: Callable = owners.jobs._dispatch_reserves
	for slot: int in Residents.RESIDENT_CAPACITY:
		if not residents.is_alive(slot) or residents.life_stage_code_of(slot) != Residents.LIFE_STAGE_ADULT \
				or residents.species_key(residents.species_of(slot).value) != &"mole" or residents.has_equipped_tool(slot) \
				or owners.jobs.job_of(slot) != NULL_REF or EntryRuntime._seeking(owners.jobs.needs(), slot) \
				or runtime.reserves_resident(slot) or (reserves.is_valid() and bool(reserves.call(slot))): continue
		var crew: Builder.Crew = Builder.Crew.new()
		crew.worker = residents.ref_of(slot)
		out.assign([crew])
		return &""
	return REFUSE_NO_MOLE


static func _park(runtime: Runtime, owners: Builder.Owners, request: Order, crew: Builder.Crew) -> StringName:
	"""Its parking, off the access and away from the room's cells (decision 1935's finding)."""
	var ctx: Builder.Context = Foreman._context(owners, request.storage, request.output)
	var ask: Parking.Request = Parking.Request.new()
	ask.access = request.access; ask.forward = ctx.forward; ask.backward = ctx.backward; ask.content = ctx.content
	ask.room_box = _room_box(owners.sites, request.room)
	if ctx.forward < 0 or ctx.backward < 0: return Foreman.REFUSE_ROWS
	if ask.room_box.is_empty(): return REFUSE_NO_CELLS
	ask.taken = runtime.parkings()
	var found: Array[Vector2i] = []
	var code: StringName = Parking.find_into(owners, ask, found)
	if code == &"": crew.parking = found[0]
	return code


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
