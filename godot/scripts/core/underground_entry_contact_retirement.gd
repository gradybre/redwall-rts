extends RefCounted
## ADR1191 driver: retire the completed, unused first dig pair before the pending L0 bearer is staged.
## Stateless. Two real publications under one original cold lease: WorldRoutes removes the pair's incident
## edges, then Locations removes the now-unretained endpoints. Not atomic: a refused second step leaves the
## disconnected contacts live for a bounded retry, with payment, geometry and Site history unchanged.

const Locations := preload("res://scripts/core/underground_locations.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Scope := preload("res://scripts/core/underground_entry_contact_retirement_scope.gd")
const REFUSE_LEASE: StringName = &"ENTRY_CONTACT_RETIREMENT_LEASE"
const REFUSE_EDGES: StringName = &"ENTRY_CONTACT_RETIREMENT_EDGES"


class Owners extends RefCounted:
	## The caller's actual once-bound owners; borrowed for one synchronous call and never retained.
	var contacts: RefCounted = null
	var locations: Locations = null
	var binding: WorldRoutes = null
	var routes: Routes = null
	var budget: Budget = null
	var placement: Vector2i = Vector2i(-1, 0)
	var project: Vector2i = Vector2i(-1, 0)
	var worker: Vector2i = Vector2i(-1, 0)
	var job: Vector2i = Vector2i(-1, 0)
	var first: Vector2i = Vector2i(-1, 0)
	var second: Vector2i = Vector2i(-1, 0)


static func retire_completed_pair(owners: Owners) -> StringName:
	"""Publish both removals or leave every live bank, lease and receipt exactly as the refusal found it."""
	if owners == null or owners.budget == null or owners.locations == null or owners.binding == null \
			or owners.routes == null or owners.contacts == null:
		return Scope.REFUSE_SCOPE
	var cold: int = owners.budget.acquire(Budget.COLD_BYTES)
	if cold <= 0:
		return REFUSE_LEASE
	var scope: Scope = Scope.new()
	var context: Locations.ContactRetirementContext = _context(owners, scope, cold)
	var code: StringName = scope.bind_original(context, owners.contacts, owners.project, owners.worker, owners.job)
	if code == &"":
		code = owners.locations.begin_contact_retirement(context)
	if code == &"":
		code = _publish_graph(owners, scope, context)
	if code == &"":
		code = _publish_locations(owners, scope, context)
	owners.locations.discard_contact_retirement(context, scope)
	scope.clear_original()
	owners.budget.release(cold)
	return code


static func _context(owners: Owners, scope: Scope, cold: int) -> Locations.ContactRetirementContext:
	"""Pin every original owner, bank and revision before the first observer can run."""
	var c: Locations.ContactRetirementContext = Locations.ContactRetirementContext.new()
	c.issuer = scope
	c.issuer_script = Scope
	c.locations = owners.locations
	c.graph = owners.binding
	c.routes = owners.routes
	c.owner = owners.locations._owner
	c.budget = owners.budget
	c.live = owners.locations._live
	c.candidate = owners.locations._stage
	c.graph_live = owners.routes._live
	c.graph_candidate = owners.routes._stage
	c.masks_live = owners.binding._live
	c.masks_candidate = owners.binding._stage
	c.world = owners.locations._world
	c.placement = owners.placement
	c.first = owners.first
	c.second = owners.second
	c.cold = cold
	c.revision = owners.locations._owner._header[17]
	c.profiles = owners.binding._profiles._live.header[0]
	c.catalog = owners.binding._live_catalog_revision
	c.graph_revision = owners.routes._live.revision
	c.location_revision = owners.locations._live.header[13]
	return c


static func _publish_graph(owners: Owners, scope: Scope, context: Locations.ContactRetirementContext) -> StringName:
	"""First publication: only edges incident to the selected pair leave the graph and its certificates."""
	var begun: Routes.Result = owners.binding.begin_prepare(context.cold, 0, 0)
	if begun.error != &"":
		return begun.error
	context.route_token = begun.token
	context.phase = Scope.GRAPH_PREPARED
	var code: StringName = _stage_incident_removals(owners, scope, context)
	if code == &"":
		code = owners.binding.seal(begun.token)
	if code == &"":
		code = scope.open_graph_publication(context)
	if code == &"":
		code = owners.binding.publish(begun.token)
	scope.close_publication()
	if code != &"":
		owners.binding.abort(begun.token)
		return code
	context.route_receipt = begun.token
	context.phase = Scope.GRAPH_PUBLISHED
	return scope.contact_retirement_scope_refusal(context)


static func _stage_incident_removals(owners: Owners, scope: Scope, context: Locations.ContactRetirementContext) -> StringName:
	"""Remove every live edge touching either contact; the scope re-proves semantics after each removal."""
	var routes: Routes = owners.routes
	var edge: Routes.Edge = Routes.Edge.new()
	var removed: int = 0
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row])
		var code: StringName = routes.edge_metadata_into(ref, edge)
		if code != &"": return code
		if not scope.selected(edge.from_location) and not scope.selected(edge.to_location): continue
		code = routes.stage_remove(context.route_token, ref)
		if code == &"": code = scope.contact_retirement_scope_refusal(context)
		if code != &"": return code
		removed += 1
	return &"" if removed > 0 else REFUSE_EDGES


static func _publish_locations(owners: Owners, scope: Scope, context: Locations.ContactRetirementContext) -> StringName:
	"""Second publication: the now-disconnected, unretained endpoints leave the Locations bank."""
	var code: StringName = owners.locations.prepare_contact_retirement(context)
	if code == &"":
		code = scope.open_location_publication(context)
	if code == &"" and not Locations.commit_contact_retirement_preflighted(owners.locations, context):
		code = Locations.contact_retirement_leaf_refusal(owners.locations, context)
		if code == &"": code = &"LOCATION_CONTACT_RETIREMENT_ROWS"
	scope.close_publication()
	return code
