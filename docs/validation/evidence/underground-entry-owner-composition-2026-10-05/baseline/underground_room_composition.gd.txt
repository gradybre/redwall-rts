extends RefCounted
## Stateless constructor for the actual mounted Session's existing private owner packet. ADR1163.
## No endpoint, Room, route, physical phase or paid input is created here.

const Retirement := preload("res://scripts/core/underground_world_retirement.gd")
const Provider := preload("res://scripts/core/underground_room_world_bindings.gd")
const Authority := preload("res://scripts/core/underground_space_authority.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Funding := preload("res://scripts/core/excavation_inventory.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const RoomBindings := preload("res://scripts/core/underground_room_bindings.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")


static func construct(session: RefCounted) -> StringName:
	"""The exact Session opens this synchronous bracket; no supplied owner tuple can register authorities."""
	if not Retirement.constructor_session_matches(session) or session._operations_state != 1 \
			or not session._busy or session._operations_prefix != 0:
		return &"UNDERGROUND_COMPOSITION_SCOPE"
	var code: StringName = _prepare_phase(session)
	if code == &"": code = _bind_excavation(session)
	if code == &"": code = _bind_router(session)
	if code == &"": code = _bind_rooms(session)
	if code == &"": code = _bind_locations(session)
	return code


static func _original_refusal(session: RefCounted) -> StringName:
	"""Every observed constructor result is followed by the original private direct-source leaf."""
	var code: StringName = session._original_refusal()
	if code == &"": code = session._foundation_refusal()
	return code


static func _prepare_phase(session: RefCounted) -> StringName:
	"""Prepare only private candidates before the first once-bound authority is installed."""
	var o: Retirement.Owners = session._retirement_owners
	o.world_bindings = Provider.new()
	var code: StringName = o.world_bindings.configure(o.world, o.terrain, o.space, o.sources, o.budget)
	if code == &"": code = _original_refusal(session)
	if code != &"": return code
	o.authority = Authority.new()
	code = o.authority.configure(o.space, o.world_bindings, Budget.PROOF_CAPACITY)
	return _original_refusal(session) if code == &"" else code


static func _bind_excavation(session: RefCounted) -> StringName:
	"""Retain the real Sites immediately; its owner writes cannot be undone by dropping a local."""
	var o: Retirement.Owners = session._retirement_owners
	o.sites = Sites.new(o.construction, o.inventory, o.reservations, o.items, o.jobs, o.work,
		o.authority, Funding.MAX_RECEIPT_CAPACITY, Sites.MAX_SITE_CAPACITY)
	var code: StringName = o.sites.initialization_refusal()
	if code != &"":
		o.sites = null # Refused initializer publishes no owner links.
		return code
	session._operations_prefix = 1
	code = _original_refusal(session)
	if code == &"": code = o.authority.bind_sites(o.sites)
	return _original_refusal(session) if code == &"" else code


static func _bind_router(session: RefCounted) -> StringName:
	"""The Router shares Sites' one Funding arena and installs the second pair of exact owner links."""
	var o: Retirement.Owners = session._retirement_owners
	o.router = Router.new(o.construction, o.inventory, o.reservations, o.items, o.jobs, o.work, o.sites)
	var code: StringName = o.router.initialization_refusal()
	if code != &"":
		o.router = null # This initializer preflights both links before either write.
		return code
	session._operations_prefix = 2
	return _original_refusal(session)


static func _bind_rooms(session: RefCounted) -> StringName:
	"""Retain the published Buildings authority even if its subsequent reciprocal admission setup refuses."""
	var o: Retirement.Owners = session._retirement_owners
	o.room_bindings = RoomBindings.new()
	var code: StringName = o.room_bindings.configure(o.world_bindings, o.sites, o.budget)
	if code == &"": code = _original_refusal(session)
	if code == &"" and o.buildings._definitions == null: code = &"UNDERGROUND_COMPOSITION_CATALOG"
	if code != &"":
		o.room_bindings = null
		return code
	o.rooms = Orders.new()
	code = o.rooms.configure(o.router, o.space, o.sources, RoomCatalog.new(o.buildings._definitions), o.room_bindings)
	if code != &"":
		o.rooms = null
		o.room_bindings = null
		return code
	session._operations_prefix = 3
	code = _original_refusal(session)
	if code == &"": code = o.room_bindings.configure_room_admission(o.rooms, o.levels)
	if code == &"": code = _original_refusal(session)
	if code == &"": code = o.world_bindings.bind_room_bindings(o.room_bindings)
	return _original_refusal(session) if code == &"" else code


static func _bind_locations(session: RefCounted) -> StringName:
	"""Allocate the already admitted empty namespace, then bind its exact Inventory adapter once."""
	var o: Retirement.Owners = session._retirement_owners
	o.locations = Locations.new()
	var code: StringName = o.locations.configure(o.directory, o.buildings, o.transforms, o.inventory,
		o.space, o.sources, o.budget, Budget.LOCATION_CAPACITY, 228 * Budget.LOCATION_CAPACITY + 256)
	if code != &"":
		o.locations = null
		return code
	code = _original_refusal(session)
	if code == &"": code = o.locations.bind_sites(o.sites)
	if code == &"": code = _original_refusal(session)
	if code == &"": code = o.locations.bind_room_orders(o.rooms)
	if code == &"": code = _original_refusal(session)
	return _bind_inventory(session) if code == &"" else code


static func _bind_inventory(session: RefCounted) -> StringName:
	"""Keep the original adapter after successful binding; identical finite arenas are reused on remount."""
	var o: Retirement.Owners = session._retirement_owners
	o.inventory_locations = Locations.InventoryLocations.new(o.locations)
	var result: Inventory.OpResult = o.inventory.bind_spatial_locations(o.inventory_locations,
		Budget.INVENTORY_ENDPOINT_CAPACITY)
	if not result.ok:
		o.inventory_locations = null
		return result.error
	session._operations_prefix = 4
	return _original_refusal(session)


static func drop_unbound(session: RefCounted) -> void:
	"""Only before the first owner write: drop this Session's private constructor references."""
	if session._operations_prefix != 0: return
	var o: Retirement.Owners = session._retirement_owners
	o.authority = null
	o.world_bindings = null


static func complete_refusal(o: Retirement.Owners) -> StringName:
	"""Direct reciprocal object proof; no completed endpoint, geometry or work permission is inferred."""
	if o.world_bindings == null or o.world_bindings.get_script() != Provider or o.authority == null \
			or o.authority.get_script() != Authority or o.sites == null or o.sites.get_script() != Sites \
			or o.router == null or o.router.get_script() != Router or o.rooms == null or o.rooms.get_script() != Orders \
			or o.room_bindings == null or o.room_bindings.get_script() != RoomBindings \
			or o.locations == null or o.locations.get_script() != Locations or o.inventory_locations == null \
			or o.inventory_locations.get_script() != Locations.InventoryLocations:
		return &"UNDERGROUND_COMPOSITION_OWNER"
	if not Retirement._weak_matches(o.world_bindings._room_bindings, o.room_bindings) \
			or not Retirement._weak_matches(o.room_bindings._levels, o.levels) \
			or not Retirement._weak_matches(o.locations._sites, o.sites) \
			or not Retirement._weak_matches(o.locations._room_orders, o.rooms):
		return &"UNDERGROUND_COMPOSITION_OWNER"
	var code: StringName = Retirement.constructor_catalog_refusal(o)
	if code == &"": code = Retirement._owners_refusal(o)
	return _installed_links_refusal(o) if code == &"" else code


static func _installed_links_refusal(o: Retirement.Owners) -> StringName:
	"""Original once-bound receivers survive canonical clearing until the explicit release tail."""
	if not Retirement._weak_matches(o.buildings._spatial_authority, o.rooms) \
			or not Retirement._weak_matches(o.construction._excavation_authority, o.sites) \
			or not Retirement._weak_matches(o.construction._modular_authority, o.router) \
			or not Retirement._weak_matches(o.work._excavation_authority, o.sites) \
			or not Retirement._weak_matches(o.work._modular_authority, o.router) \
			or not Retirement._weak_matches(o.inventory._spatial_authority, o.inventory_locations) \
			or o.inventory._spatial_world != o.world_ref:
		return &"UNDERGROUND_COMPOSITION_OWNER"
	return &""
