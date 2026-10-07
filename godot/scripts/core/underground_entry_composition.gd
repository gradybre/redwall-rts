extends RefCounted
## ADR1184: finite private Session entry-owner construction. No endpoint or paid work is created.
## construct() is the fixed wrapper (ADR1195): it alone reads the ADR1190 bundle; no caller supplies a path.

const Retirement := preload("res://scripts/core/underground_world_retirement.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const ConnectorWork := preload("res://scripts/core/underground_connector_work.gd")
const Workpieces := preload("res://scripts/core/underground_connector_workpieces.gd")
const Delivery := preload("res://scripts/core/underground_connector_delivery.gd")
const Provider := preload("res://scripts/core/underground_room_world_bindings.gd")
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-stone-v5/catalog_source.gd")
const StructureScope := preload("res://scripts/core/underground_world_structure_scope.gd")
const EntryStructure := preload("res://scripts/core/underground_entry_structure.gd")


static func construct(session: RefCounted, original_host: Object) -> StringName:
	"""Load the fixed bundle readers against the mounted structure Catalog, then run every retained stage."""
	var code: StringName = _scope_refusal(session, 9)
	if code == &"": code = _host_refusal(session, original_host)
	if code != &"": return code
	var frontier: Frontier = Frontier.new()
	code = _load_bundle(session._retirement_owners, frontier)
	if code == &"": code = _bind_loaded_source(session, frontier)
	if code == &"": code = _bind_remaining(session, original_host,
		Bundle.WORKPIECES_PATH, Bundle.WORKPIECES_SHA, Bundle.WORKPIECES_REVISION)
	return code


static func _load_bundle(o: Retirement.Owners, frontier: Frontier) -> StringName:
	"""Bills, partition and Frontier bind the exact mounted Catalog and Profiles before any owner is retained."""
	var catalog: RefCounted = o.world_routes._catalog
	var recipes: Recipes = Recipes.new()
	var code: StringName = recipes.configure(Recipes.MAX_PARTS, Recipes.required_bytes(Recipes.MAX_PARTS))
	if code == &"": code = recipes.bind_actual(catalog, o.items, o.inventory)
	if code == &"": code = recipes.load_file(Bundle.RECIPE_PATH, Bundle.RECIPE_SHA, Bundle.RECIPE_REVISION,
		Bundle.GROUPING_SHA, Bundle.GROUPING_REVISION)
	var groups: Assemblies = Assemblies.new()
	if code == &"": code = groups.configure(Assemblies.MAX_GROUPS, Assemblies.required_bytes(Assemblies.MAX_GROUPS))
	if code == &"": code = groups.bind_actual(catalog, recipes, o.items, o.inventory)
	if code == &"": code = groups.load_file(Bundle.GROUPING_PATH, Bundle.GROUPING_SHA, Bundle.GROUPING_REVISION,
		Bundle.RECIPE_SHA, Bundle.RECIPE_REVISION)
	var capacities: PackedInt32Array = PackedInt32Array([Bundle.INSTALL_COUNT, Bundle.STATION_COUNT,
		Bundle.CUT_COUNT, Bundle.BEARING_COUNT, Bundle.ENDPOINT_COUNT, Bundle.EPISODE_COUNT])
	if code == &"": code = frontier.configure(capacities, Frontier.required_bytes(capacities))
	if code == &"": code = frontier.bind_actual(catalog, groups, recipes, o.profiles)
	if code == &"": code = frontier.load_file(Bundle.FRONTIER_PATH, Bundle.FRONTIER_SHA, Bundle.FRONTIER_REVISION)
	return code


static func _bind_loaded_source(session: RefCounted, frontier: Frontier) -> StringName:
	"""The fixed-source reader frame ends after original authority binding, before later owner constructors."""
	if frontier == null or frontier.get_script() != Frontier or not frontier._loaded:
		return &"UNDERGROUND_ENTRY_COMPOSITION_SOURCE"
	var code: StringName = _prepare_placement(session, frontier._assemblies, frontier._recipes)
	if code == &"": code = _bind_frontier(session, frontier)
	return code


static func _bind_remaining(session: RefCounted, original_host: Object,
		workpiece_path: String, workpiece_sha: String, workpiece_revision: int) -> StringName:
	"""Only the future fixed wrapper supplies source constants; every exposed failure stays in the original prefix."""
	var code: StringName = _prepare_contacts(session)
	if code == &"": code = _bind_phase(session)
	if code == &"": code = _bind_structure(session)
	if code == &"": code = _bind_work(session)
	if code == &"": code = _prepare_workpieces(session, workpiece_path, workpiece_sha, workpiece_revision)
	if code == &"": code = _bind_workpieces(session)
	if code == &"": code = _bind_delivery(session, original_host)
	return code


static func _scope_refusal(session: RefCounted, prefix: int) -> StringName:
	"""Only the original live Session's synchronous constructor may advance an exact finite prefix."""
	if not Retirement.constructor_session_matches(session) or not session._busy \
			or session._operations_state != 1 or session._operations_prefix != prefix \
			or prefix < 9 or prefix > 17 or session._retirement_scope != null:
		return &"UNDERGROUND_ENTRY_COMPOSITION_SCOPE"
	var code: StringName = session._original_refusal()
	if code == &"": code = _original_packet_refusal(session)
	if code == &"": code = Retirement._owners_refusal(session._retirement_owners, prefix)
	if code == &"": code = session._foundation_refusal()
	if code == &"": code = Retirement.entry_constructor_shape_refusal(session._retirement_owners, prefix)
	if code == &"": code = Retirement.surface_refusal(session._retirement_owners)
	return code


static func _original_packet_refusal(session: RefCounted) -> StringName:
	"""The private packet must still contain the Session's original foundations after every observation."""
	var o: Retirement.Owners = session._retirement_owners
	if o.world != session._world or o.world_ref != session._world_ref or o.directory != session._directory \
			or o.buildings != session._buildings or o.construction != session._construction \
			or o.inventory != session._inventory or o.items != session._items or o.jobs != session._jobs \
			or o.work != session._work or o.residents != session._residents or o.reservations != session._reservations \
			or o.transforms != session._transforms or o.gear != session._gear or o.carry != session._carry \
			or o.piles != session._piles or o.content != session._content or o.space != session._space \
			or o.sources != session._sources or o.routes != session._routes or o.budget != session._budget \
			or o.terrain != session._terrain or o.profiles != session._profiles or o.levels != session._levels:
		return &"UNDERGROUND_ENTRY_COMPOSITION_OWNER"
	return &""


static func _prepare_placement(session: RefCounted, groups: Assemblies, recipes: Recipes) -> StringName:
	"""Privately configure exact existing arenas, then retain the fully bound candidate before authority binding."""
	var code: StringName = _scope_refusal(session, 9)
	if code != &"": return code
	var o: Retirement.Owners = session._retirement_owners
	var candidate: Placements = Placements.new()
	code = candidate.configure(Placements.MAX_PLACEMENTS, Placements.MAX_OPENINGS,
		Placements.required_bytes(Placements.MAX_PLACEMENTS, Placements.MAX_OPENINGS))
	if code == &"": code = candidate.bind_actual(o.space, o.locations, o.routes, o.budget,
		o.world_routes._catalog, groups, recipes, o.construction)
	if code == &"": code = _scope_refusal(session, 9)
	if code != &"": return code
	o.placements = candidate
	session._operations_prefix = 10
	return _scope_refusal(session, 10)


static func _bind_frontier(session: RefCounted, frontier: Frontier) -> StringName:
	"""Install the original EntryBindings authority only after the immutable source is fully loaded."""
	var code: StringName = _scope_refusal(session, 10)
	if code != &"": return code
	var o: Retirement.Owners = session._retirement_owners
	code = (o.room_bindings as Retirement.EntryBindings).bind_entry(frontier, o.placements)
	if o.room_bindings._entry_authority != null:
		session._operations_prefix = 11
	if code != &"": return code
	return _scope_refusal(session, 11)


static func _prepare_contacts(session: RefCounted) -> StringName:
	"""A private Contacts failure installs no external link; successful exact storage precedes phase binding."""
	var code: StringName = _scope_refusal(session, 11)
	if code != &"": return code
	var o: Retirement.Owners = session._retirement_owners
	var candidate: Contacts = Contacts.new()
	code = candidate.configure(o.placements, o.router, o.room_bindings._entry_frontier, Contacts.CONTROL_BYTES)
	if code == &"": code = _scope_refusal(session, 11)
	if code != &"": return code
	o.contacts = candidate
	session._operations_prefix = 12
	return _scope_refusal(session, 12)


static func _bind_phase(session: RefCounted) -> StringName:
	"""The original provider publishes only its existing reciprocal phase context and bounded scratch."""
	var code: StringName = _scope_refusal(session, 12)
	if code != &"": return code
	var o: Retirement.Owners = session._retirement_owners
	code = (o.world_bindings as Provider).bind_phase_contacts(o.contacts, Provider.ENTRY_CONTROL_BYTES)
	if o.world_bindings._entry_contacts != null:
		session._operations_prefix = 13
	if code != &"": return code
	return _scope_refusal(session, 13)


static func _bind_structure(session: RefCounted) -> StringName:
	"""ADR1224 (ADR1197 G12): the provider's structural reads go to one entry structure (natural entry bearings plus
	the base paid-Room protection) under its own phase Scope, exactly as ADR1122's fixture composes it. The pair is
	retained before the one-way bind, so a refused bind still leaves it for whole-World retirement."""
	var code: StringName = _scope_refusal(session, 13)
	if code != &"": return code
	var o: Retirement.Owners = session._retirement_owners
	var scope: StructureScope = StructureScope.new()
	var structure: EntryStructure = EntryStructure.new()
	code = scope.configure(o.world_bindings, o.levels, o.budget)
	if code == &"": code = structure.configure(scope, o.space, o.terrain, o.levels, o.sites, o.budget)
	if code == &"": code = structure.bind_entry_sources(o.placements, o.room_bindings._entry_frontier,
		EntryStructure.ENTRY_CONTROL_BYTES)
	if code == &"": code = _scope_refusal(session, 13)
	if code != &"": return code
	o.structure_scope = scope
	o.entry_structure = structure
	code = o.world_bindings.bind_phase_structure(structure, o.levels)
	return code if code != &"" else _scope_refusal(session, 13)


static func _bind_work(session: RefCounted) -> StringName:
	"""Retain the new paid owner before its first Router write, including every refused reciprocal prefix."""
	var code: StringName = _scope_refusal(session, 13)
	if code != &"": return code
	var o: Retirement.Owners = session._retirement_owners
	o.connector = ConnectorWork.new()
	session._operations_prefix = 14
	code = o.connector.configure(o.placements, o.router, o.contacts)
	if code != &"": return code
	return _scope_refusal(session, 14)


static func _prepare_workpieces(session: RefCounted, path: String, digest: String, revision: int) -> StringName:
	"""The fixed-source wrapper alone supplies these immutable constants; no Host API accepts a path or digest."""
	var code: StringName = _scope_refusal(session, 14)
	if code != &"": return code
	var o: Retirement.Owners = session._retirement_owners
	var candidate: Workpieces = Workpieces.new()
	code = candidate.configure(Placements.MAX_PLACEMENTS, Workpieces.MAX_ASSEMBLIES,
		Workpieces.required_bytes(Placements.MAX_PLACEMENTS, Workpieces.MAX_ASSEMBLIES))
	if code == &"": code = candidate.bind_actual(o.placements, o.router, o.connector)
	if code == &"": code = candidate.load_file(path, digest, revision)
	if code == &"": code = _scope_refusal(session, 14)
	if code != &"": return code
	o.workpieces = candidate
	session._operations_prefix = 15
	return _scope_refusal(session, 15)


static func _bind_workpieces(session: RefCounted) -> StringName:
	"""A failed reciprocal bind retains the exact loaded reader in prefix fifteen for whole-World retirement."""
	var code: StringName = _scope_refusal(session, 15)
	if code != &"": return code
	var o: Retirement.Owners = session._retirement_owners
	code = o.connector.bind_workpieces(o.workpieces)
	if o.connector._workpieces == o.workpieces:
		session._operations_prefix = 16
	if code != &"": return code
	return _scope_refusal(session, 16)


static func _bind_delivery(session: RefCounted, original_host: Object) -> StringName:
	"""Only the actual original Host Planner and clock enter the one existing Work delivery link."""
	var code: StringName = _scope_refusal(session, 16)
	if code == &"": code = _host_refusal(session, original_host)
	if code != &"": return code
	var o: Retirement.Owners = session._retirement_owners
	var candidate: Delivery = Delivery.new()
	code = candidate.configure(o.placements, o.room_bindings._entry_frontier,
		original_host._haul_planner, o.world_routes, o.work, original_host._commands._clock, Delivery.RESERVED_BYTES)
	if o.work._spatial_delivery != null and o.work._spatial_delivery.get_ref() == candidate:
		o.delivery = candidate
		session._operations_prefix = 17
	if code == &"": code = _host_refusal(session, original_host)
	if code == &"": code = _scope_refusal(session, 17)
	return code


static func _host_refusal(session: RefCounted, original_host: Object) -> StringName:
	"""Caller identity is insufficient: match the cached actual Host and its full original mounted tuple."""
	var actual: Script = ResourceLoader.get_cached_ref("res://scripts/systems/settlement_system.gd") as Script
	if not is_instance_valid(original_host) or actual == null or original_host.get_script() != actual \
			or original_host._underground_reset_phase != 0 or original_host._underground_session != session:
		return &"UNDERGROUND_ENTRY_COMPOSITION_HOST"
	var code: StringName = original_host._mounted_underground_refusal(session)
	if code == &"": code = Retirement.delivery_host_refusal(original_host, session._retirement_owners)
	return code
