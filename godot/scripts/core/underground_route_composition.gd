extends RefCounted
## ADR1167: source-bound graph-owner composition in the existing actual Session packet.
## Empty arenas and real pace metadata grant no endpoint, actor, movement, Room or work permission.

const Retirement := preload("res://scripts/core/underground_world_retirement.gd")
const RoomComposition := preload("res://scripts/core/underground_room_composition.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Movement := preload("res://scripts/core/movement.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
## ADR1229: the T1-T6 first-entry bundle (content 10, Frontier on source 4, workpieces on source 5); ADR1217 step 5
## mounted the claw bundle `qualified-claw-v6` (content 9).
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-stairs-v8/catalog_source.gd")
## ADR1229: the claw stair tables Routes samples for the stair and short-step rows 51-55.
const StairMotion := preload("res://scripts/core/underground_stair_motion.gd")
const MotionPins := preload("res://data/underground/mole-worker/qualified-claw-stair-motion-v1/catalog_source.gd")
const PROFILE_CONTENT_REVISION: int = Bundle.CONTENT_REVISION
# ADR1190/1195: the mounted graph selects the published first-entry structure, which carries the same
# ground paces plus the L0/T0 regions; selecting it before the first WorldRoutes binding is final.
const CATALOG_REVISION: int = Bundle.CATALOG_REVISION
const CATALOG_PATH: String = Bundle.CATALOG_PATH
const CATALOG_SHA: String = Bundle.CATALOG_SHA
## ADR1200/1206/1217/1229: content 6's fifteen, claw WALK 42, the narrow claw rows 43-50 and the short steps 51/52 as
## ground caps, then DEC-050's authored stair paces (descent 53, ascent 54, half-turn 55).
const GROUND_PACE_COUNT: int = 29

const CATALOG_DIGEST_0: int = Bundle.CATALOG_DIGEST_0
const CATALOG_DIGEST_1: int = Bundle.CATALOG_DIGEST_1
const CATALOG_DIGEST_2: int = Bundle.CATALOG_DIGEST_2
const CATALOG_DIGEST_3: int = Bundle.CATALOG_DIGEST_3


static func construct(session: RefCounted) -> StringName:
	"""Only the actual Session's synchronous Room-ready bracket can construct the next finite prefix."""
	if not Retirement.constructor_session_matches(session) or not session._busy \
			or session._operations_state != 1 or session._operations_prefix != 4:
		return &"UNDERGROUND_ROUTE_COMPOSITION_SCOPE"
	if session._retirement_owners.world_routes != null \
			or session._retirement_owners.profiles._live.header[0] != PROFILE_CONTENT_REVISION:
		return &"UNDERGROUND_ROUTE_COMPOSITION_SOURCE"
	var config: WorldRoutes.Configuration = _configuration(session._retirement_owners)
	var code: StringName = _prepare_catalog(config)
	if code == &"": code = _original_refusal(session)
	if code != &"": return code
	var candidate: WorldRoutes = WorldRoutes.new()
	code = candidate.configure(config)
	if code == &"": code = _original_refusal(session)
	if code != &"": return code
	session._retirement_owners.world_routes = candidate
	session._operations_prefix = 5
	config = null # The temporary configuration dies before any graph bank allocation.
	if code == &"": code = _bind_graph(session)
	if code == &"": code = _bind_profiles(session)
	if code == &"": code = _bind_approach(session)
	return code


static func _original_refusal(session: RefCounted) -> StringName:
	"""Close every observed operation against the original private Session and source owners."""
	var code: StringName = session._original_refusal()
	if code == &"": code = session._foundation_refusal()
	if code == &"": code = RoomComposition.complete_refusal(session._retirement_owners)
	if code == &"": code = unpublished_refusal(session._retirement_owners)
	if code == &"" and session._operations_prefix >= 5:
		code = Retirement.route_constructor_refusal(session._retirement_owners, session._operations_prefix)
	return code


static func unpublished_refusal(o: Retirement.Owners) -> StringName:
	"""Late constructor observations cannot publish operational facts beneath the original empty start."""
	if o.sites._count != 0 or o.sites._funding._free_count != o.sites._funding._capacity \
			or o.locations._live.count != 0 or o.locations._stage.count != 0 \
			or o.routes._live.edge_count != 0 or o.routes._stage.edge_count != 0 or o.routes._proposed_count != 0:
		return &"UNDERGROUND_ROUTE_COMPOSITION_OCCUPIED"
	return &""


static func _configuration(o: Retirement.Owners) -> WorldRoutes.Configuration:
	"""Borrow exact actual owners; create the sole Movement source and Catalog in their existing arenas."""
	var config: WorldRoutes.Configuration = WorldRoutes.Configuration.new()
	config.routes = o.routes
	config.owner = o.space
	config.sources = o.sources
	config.locations = o.locations
	config.profiles = o.profiles
	config.catalog = Catalog.new()
	config.levels = o.levels
	config.movement = Movement.new(o.directory, null, null, o.transforms, o.residents)
	config.residents = o.residents
	config.transforms = o.transforms
	config.world = o.world
	config.terrain = o.terrain
	config.budget = o.budget
	return config


static func _prepare_catalog(config: WorldRoutes.Configuration) -> StringName:
	"""Load one explicit immutable pace artifact; no latest-version lookup or replacement speed exists."""
	var code: StringName = config.catalog.configure(Catalog.RESERVED_BYTES)
	if code == &"":
		code = config.catalog.bind_actual(config.profiles, config.levels, config.movement, config.residents,
			config.transforms, config.owner._domain)
	return config.catalog.load_file(CATALOG_PATH, CATALOG_SHA, CATALOG_REVISION) if code == &"" else code


static func _bind_graph(session: RefCounted) -> StringName:
	"""Prefix five is retained even if Routes has written aliases but its retention bind refuses."""
	var o: Retirement.Owners = session._retirement_owners
	var code: StringName = o.routes.configure(o.locations, o.space, o.sources, o.buildings, o.budget,
		o.world_routes, Budget.LOCATION_CAPACITY, Routes.MAX_EDGES, Routes.MAX_VERTICES,
		Routes.MAX_LINKS, Budget.LOCATION_AND_TOPOLOGY_BYTES)
	if code != &"": return code
	session._operations_prefix = 6
	return _original_refusal(session)


static func _bind_profiles(session: RefCounted) -> StringName:
	"""A post-write extent refusal keeps the real Profile/Work references in the retained graph prefix."""
	var o: Retirement.Owners = session._retirement_owners
	var code: StringName = o.routes.bind_profiles(o.profiles, o.inventory, o.gear, o.carry,
		o.work, o.reservations, o.piles)
	if code == &"": code = _bind_stair_motion(o.routes)
	if code != &"": return code
	session._operations_prefix = 7
	return _original_refusal(session)


static func _bind_stair_motion(routes: Routes) -> StringName:
	"""ADR1229: load the pinned claw stair tables once and lend them to this Session's Routes."""
	var motion: StairMotion = StairMotion.new()
	var code: StringName = motion.load_file(MotionPins.WIRE_PATH, MotionPins.WIRE_SHA)
	return routes.bind_stair_motion(motion) if code == &"" else code


static func _bind_approach(session: RefCounted) -> StringName:
	"""Bind the existing Room admission observer to this exact graph, without creating an access endpoint."""
	var o: Retirement.Owners = session._retirement_owners
	var code: StringName = o.room_bindings.configure_room_approach(o.world_routes)
	if code != &"": return code
	session._operations_prefix = 8
	return _original_refusal(session)


static func complete_refusal(o: Retirement.Owners) -> StringName:
	"""Direct complete original wiring and explicit source revisions; no observer supplies final success."""
	if o == null or o.world_routes == null or o.world_routes.get_script() != WorldRoutes \
			or o.routes.get_script() != Routes or o.world_routes._catalog == null \
			or o.world_routes._catalog.get_script() != Catalog or o.world_routes._movement == null \
			or o.world_routes._movement.get_script() != Movement:
		return &"UNDERGROUND_ROUTE_COMPOSITION_OWNER"
	var code: StringName = RoomComposition.complete_refusal(o)
	if code == &"": code = Retirement.route_constructor_refusal(o, 8)
	if code == &"": code = _source_refusal(o)
	if code == &"" and (o.routes._stair_motion == null or not o.routes._stair_motion.is_loaded()):
		code = &"UNDERGROUND_ROUTE_COMPOSITION_SOURCE" # ADR1229: a complete graph samples the claw stair tables.
	return code


static func _source_refusal(o: Retirement.Owners) -> StringName:
	"""Retain the exact accepted pace and profile publication, including source-only Movement wiring."""
	var catalog: Catalog = o.world_routes._catalog
	var movement: Movement = o.world_routes._movement
	if o.profiles._live.header[0] != PROFILE_CONTENT_REVISION or catalog._live.header[0] != CATALOG_REVISION \
			or catalog._live.header[7] != GROUND_PACE_COUNT or movement._world != null or movement._navigation != null \
			or o.world_routes._catalog_identity != catalog.get_instance_id() \
			or o.world_routes._profile_identity != o.profiles.get_instance_id() \
			or o.world_routes._levels_identity != o.levels.get_instance_id():
		return &"UNDERGROUND_ROUTE_COMPOSITION_SOURCE"
	# The exact four-word source digest below pins every header field, including the entry structure's
	# single variant and regions; a ground-only zero-region check no longer applies (ADR1195).
	if catalog._live.digests.decode_s64(0) != CATALOG_DIGEST_0 \
			or catalog._live.digests.decode_s64(8) != CATALOG_DIGEST_1 \
			or catalog._live.digests.decode_s64(16) != CATALOG_DIGEST_2 \
			or catalog._live.digests.decode_s64(24) != CATALOG_DIGEST_3:
		return &"UNDERGROUND_ROUTE_COMPOSITION_SOURCE"
	return &""
