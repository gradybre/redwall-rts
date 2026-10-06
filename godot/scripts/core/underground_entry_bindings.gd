extends "res://scripts/core/underground_room_bindings.gd"
## Actual non-flat entrance admission. Confirmation reserves virgin cuts, never installed parts or usable air.
## Paid rectangular timber and supported contacts use the same actual purpose8 transaction. Decisions1111/1114.

const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const EntryCuts := preload("res://scripts/core/underground_entry_cut_map.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const ConnectorCatalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const ENTRY_FIXED_BYTES: int = 4096
const ENTRY_EPISODE_FIELDS: int = 19
const ENTRY_BEARING_FIELDS: int = 9
const TIMBER_SCOPE_CHECKS: int = 2048
const REFUSE_ENTRY_SOURCE: StringName = &"ENTRY_SOURCE_MISMATCH"
const REFUSE_ENTRY_CUTS: StringName = &"ENTRY_EXACT_CUT_SET_REQUIRED"
const REFUSE_ENTRY_BEARING: StringName = &"ENTRY_NATURAL_BEARING_REMOVED"
const REFUSE_ENTRY_ANCHOR: StringName = &"ENTRY_ACTUAL_SURFACE_ANCHOR"
const REFUSE_ENTRY_CONTACT: StringName = &"ENTRY_EXISTING_SURFACE_CONTACT"
const REFUSE_ENTRY_COLD: StringName = &"ENTRY_ORIGINAL_COLD_SCOPE"
const REFUSE_TIMBER: StringName = &"ENTRY_INSTALLED_PRISM_REQUIRED"
const REFUSE_TIMBER_CUT: StringName = &"ENTRY_INSTALLED_PAID_VOID_REQUIRED"
const REFUSE_TIMBER_BEARING: StringName = &"ENTRY_INSTALLED_BEARING_REQUIRED"
const REFUSE_TIMBER_CONTACT: StringName = &"ENTRY_INSTALLED_CONTACT_REQUIRED"

class TimberClearance extends WorldRoutes.Clearance:

	func allocate_rows(capacity: int, checks: int) -> void:
		"""Reuse the exact six-slab implementation with the actual sparse capacity and no retained snapshot."""
		remaining = checks
		fragments.resize(6 * capacity)
		next_fragments.resize(6 * capacity)
		box.resize(6)
		cover.resize(6)
		cut.resize(6)
		core.resize(6)

	func _append(bounds: PackedInt32Array) -> bool:
		"""An actual-capacity fragment bank refuses exhaustion before any partial proof is used."""
		if next_count * 6 >= next_fragments.size():
			error = &"ENTRY_TIMBER_FRAGMENT_CAPACITY"
			return false
		for axis: int in 6: next_fragments[next_count * 6 + axis] = bounds[axis]
		next_count += 1
		return true

class AdmissionAuthority extends Placements.Authority:

	var host: WeakRef = null

	func exact_binding(placements: RefCounted, space: Owner, locations: Locations,
			routes: Routes, budget: Budget) -> bool:
		"""Forward identity only to the once-bound actual entrance composition, with no ownership cycle."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual != null and actual._authority_binding(placements, space, locations, routes, budget)

	func admission_refusal(placement: Vector2i, request: Placements.Request, token: int) -> StringName:
		"""The caller's exact future Room/section and the source-qualified private plan must still match."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._authority_admission(placement, request, token) if actual != null else REFUSE_ENTRY_COLD

	func refresh_admission_locations(placement: Vector2i, token: int, cold_token: int) -> StringName:
		"""Retain only already-live exact endpoints; planned construction creates none."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._refresh_entry_locations(placement, token, cold_token) if actual != null else REFUSE_ENTRY_COLD

	func refresh_admission_routes(placement: Vector2i, token: int, cold_token: int) -> StringName:
		"""Recompile old route certificates through actual WorldRoutes before any Room identity publishes."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._refresh_entry_routes(placement, token, cold_token) if actual != null else REFUSE_ENTRY_COLD

	func installation_cold_bytes(placement: Vector2i, assembly: int) -> int:
		"""The concrete sequential geometry/endpoint/certificate pipeline shares the original whole arena."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._timber_cold_bytes(placement, assembly) if actual != null else 0

	func preflight_installation(placement: Vector2i, project: Vector2i, assembly: int, cold: int) -> StringName:
		"""Observe genuine live terrain and paid dependencies before opening the actual Space candidate."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._timber_preflight(placement, project, assembly, cold) if actual != null else REFUSE_ENTRY_COLD

	func workpiece_refusal(placement: Vector2i, project: Vector2i, action: int,
			bounds: PackedInt32Array, cold: int) -> StringName:
		"""Static WIP needs its complete actual air and bottom contact both before staging and before payment."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._workpiece_refusal(placement, project, action, bounds, cold) if actual != null else REFUSE_ENTRY_COLD

	func stage_installation(placement: Vector2i, project: Vector2i, assembly: int, token: int, cold: int) -> StringName:
		"""Insert every exact paid part and preserve the explicit surrounding cavity."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._stage_timber(placement, project, assembly, token, cold) if actual != null else REFUSE_ENTRY_COLD

	func stage_locations(placement: Vector2i, project: Vector2i, assembly: int, token: int, cold: int) -> StringName:
		"""Refresh old endpoints and create only complete source-selected installed contacts."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._stage_timber_locations(placement, project, assembly, token, cold) if actual != null else REFUSE_ENTRY_COLD

	func stage_routes(placement: Vector2i, project: Vector2i, assembly: int, token: int, cold: int) -> StringName:
		"""Refresh existing ground certificates; installation creates no stair route permission."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._stage_timber_routes(placement, project, assembly, token, cold) if actual != null else REFUSE_ENTRY_COLD

	func completion_refusal(placement: Vector2i, project: Vector2i, assembly: int, cold: int) -> StringName:
		"""Repeat current exclusions and dependency facts against the exact sealed original candidate."""
		var actual: RefCounted = host.get_ref() if host != null else null
		return actual._timber_final(placement, project, assembly, cold) if actual != null else REFUSE_ENTRY_COLD

	func discard_completion(placement: Vector2i, project: Vector2i, cold: int) -> void:
		"""Discard provider controls only; the actual Placement owns candidates and the caller owns its lease."""
		var actual: RefCounted = host.get_ref() if host != null else null
		if actual != null: actual._discard_timber(placement, project, cold)

var _entry_frontier: Frontier = null
var _entry_placements: Placements = null
var _entry_authority: AdmissionAuthority = null
var _entry_request: EntryPlan.Request = null
var _entry_pin: EntryPlan.Request = null
var _placement_request: Placements.Request = null
var _entry_candidate: Directory.CreateCandidate = null
var _entry_prepared: Vector2i = NULL_REF
var _entry_section: Vector2i = NULL_REF
var _entry_token: int = 0
var _entry_space_token: int = 0
var _entry_busy: bool = false
var _entry_poisoned: bool = false
var _entry_checks: int = 0
var _entry_anchor: Locations.Record = Locations.Record.new()
var _entry_contact: Locations.Record = Locations.Record.new()
var _entry_row: PackedInt32Array = PackedInt32Array()
var _entry_bearing: PackedInt32Array = PackedInt32Array()
var _entry_transform: Connectors.Placement = Connectors.Placement.new()
var _timber_placement: Vector2i = NULL_REF
var _timber_project: Vector2i = NULL_REF
var _timber_assembly: int = -1
var _timber_token: int = 0


func bind_entry(frontier: Frontier, placements: Placements) -> StringName:
	"""Share exact source/owner objects once; all variable confirmation buffers use the existing World lease."""
	if _entry_frontier != null or _entry_authority != null or _entry_checks < 0 or _entry_busy or _room_token != 0 or _actual_orders() == null \
			or frontier == null or placements == null or _budget == null or not _budget.is_quiescent():
		return REFUSE_ENTRY_SOURCE
	if not frontier.binding_matches(placements._catalog, placements._assemblies, placements._recipes, placements._profiles) \
			or placements._space != _actual_provider().space_owner() or placements._budget != _budget:
		return REFUSE_ENTRY_SOURCE
	_entry_frontier = frontier
	_entry_placements = placements
	_entry_authority = AdmissionAuthority.new()
	_entry_authority.host = weakref(self)
	var code: StringName = placements.bind_authority(_entry_authority)
	if code != &"":
		_entry_frontier = null
		_entry_placements = null
		_entry_authority = null
		return code
	_entry_anchor.envelope.resize(6)
	_entry_anchor.support.resize(6)
	_entry_contact.envelope.resize(6)
	_entry_contact.support.resize(6)
	_entry_row.resize(ENTRY_EPISODE_FIELDS)
	_entry_bearing.resize(ENTRY_BEARING_FIELDS)
	return &""


func _authority_binding(placements: RefCounted, space: Owner, locations: Locations,
		routes: Routes, budget: Budget) -> bool:
	"""Read actual identity from concrete owners without calling the Placement authority recursively."""
	return placements != null and placements == _entry_placements and space == _entry_placements._space \
		and locations == _entry_placements._locations and routes == _entry_placements._routes \
		and budget == _budget and _entry_frontier != null and _actual_provider() != null \
		and _actual_provider().space_owner() == space and _entry_frontier.binding_matches(
			_entry_placements._catalog, _entry_placements._assemblies, _entry_placements._recipes, _entry_placements._profiles)


static func entry_cold_bytes(plan: EntryPlan.Request, locations: Locations) -> int:
	"""Sequential source-cursor and companion images share one arena; no second snapshot survives publication."""
	if EntryPlan.shape_refusal(plan) != &"" or locations == null:
		return 0
	@warning_ignore("integer_division") var boxes: int = plan.claims.size() / 6
	var packets: int = 3 * EntryPlan.payload_bytes(plan) + ENTRY_FIXED_BYTES
	return maxi(Orders.entry_packet_cold_bytes(plan), packets \
		+ maxi(EntryCuts.scratch_bytes(boxes), maxi(locations.cold_peak_bytes(), 377856)))


func begin_entry_cold(plan: EntryPlan.Request) -> StringName:
	"""Take exclusivity and the original actual lease before any private plan, cursor or proof allocation."""
	if _entry_busy or _entry_token != 0 or _room_token != 0:
		_entry_poisoned = true
		return REFUSE_MASK_BUSY
	_entry_busy = true
	_entry_poisoned = false
	var code: StringName = _entry_input_refusal(plan)
	if code == &"":
		_entry_request = plan
		_entry_token = _budget.acquire(Budget.COLD_BYTES)
		code = _entry_scope_refusal()
	if code == &"":
		_entry_pin = EntryPlan.Request.new()
		EntryPlan.copy_into(plan, _entry_pin)
		_entry_transform.origin = plan.origin_u
		_entry_transform.rotation = plan.rotation
		_entry_checks = _entry_placements._space._domain._checks
		code = _preflight_entry()
	if code == &"":
		code = _entry_scope_refusal()
	if code != &"":
		_drop_entry()
	_entry_busy = false
	return code


func _entry_input_refusal(plan: EntryPlan.Request) -> StringName:
	"""A foreign provider, source, World, active operation or oversized packet cannot acquire this arena."""
	if _actual_orders() == null or _actual_provider() == null or _entry_placements == null \
			or _actual_orders().entry_admission_refusal(plan, self) != &"" \
			or _actual_provider().binding_refusal() != &"" or EntryPlan.shape_refusal(plan) != &"":
		return REFUSE_ENTRY_SOURCE
	var bytes: int = entry_cold_bytes(plan, _entry_placements._locations)
	if bytes < 1 or bytes > Budget.COLD_BYTES:
		return Budget.REFUSE_BYTES
	return _entry_source_refusal(plan)


func _entry_source_refusal(plan: EntryPlan.Request) -> StringName:
	"""Verify the whole selected immutable tuple, exact allowed rotation and actual loaded program identity."""
	if EntryPlan.shape_refusal(plan) != &"" or _entry_frontier == null or Frontier.source_leaf_refusal(_entry_frontier) != &"" \
			or _entry_placements._source_refusal() != &"" or plan.world != _entry_placements._world \
			or plan.space_revision != _entry_placements._space.revision():
		return REFUSE_ENTRY_SOURCE
	return _entry_plan_source_leaf(_entry_frontier, plan)


static func _entry_plan_source_leaf(frontier: Frontier, plan: EntryPlan.Request) -> StringName:
	"""Match the original complete immutable tuple through direct indexed reads after every observer."""
	if EntryPlan.shape_refusal(plan) != &"": return REFUSE_ENTRY_SOURCE
	var source: PackedInt64Array = frontier._header
	if plan.frontier_revision != source[0] or plan.catalog_revision != source[1] or plan.variant_revision != source[2] \
			or plan.grouping_revision != source[3] or plan.recipe_revision != source[4] or plan.catalog_row != source[6] \
			or (frontier._catalog._live.variants[ConnectorCatalog.V_ROTATIONS * ConnectorCatalog.MAX_VARIANTS \
				+ source[6]] & (1 << plan.rotation)) == 0:
		return REFUSE_ENTRY_SOURCE
	if plan.opening_targets.size() != 4 * frontier._catalog._live.variants[
			ConnectorCatalog.V_OPENING_COUNT * ConnectorCatalog.MAX_VARIANTS + source[6]]:
		return REFUSE_ENTRY_SOURCE
	for index: int in 96:
		if plan.source_digests[index] != frontier._digests[32 + index]:
			return REFUSE_ENTRY_SOURCE
	for index: int in 32:
		if plan.source_digests[96 + index] != frontier._digests[index]:
			return REFUSE_ENTRY_SOURCE
	return &""


func _entry_scope_refusal() -> StringName:
	"""Keep the original input, source, token and reciprocal owner identity pinned across every observer."""
	if _entry_poisoned or _entry_request == null or _entry_token <= 0 \
			or not _budget.covers(_entry_token, Budget.COLD_BYTES) or _actual_orders() == null \
			or _actual_orders().entry_admission_refusal(_entry_request, self) != &"" \
			or (_entry_pin != null and not EntryPlan.same(_entry_request, _entry_pin)):
		return REFUSE_ENTRY_COLD
	if not _authority_binding(_entry_placements, _entry_placements._space,
			_entry_placements._locations, _entry_placements._routes, _budget):
		return REFUSE_ENTRY_SOURCE
	var code: StringName = _entry_source_refusal(_entry_request)
	return _entry_scope_leaf(self) if code == &"" else code


static func _entry_scope_leaf(actual: RefCounted) -> StringName:
	"""Final original-lease/request check has no provider, hash or binding observer before the next allocation/write."""
	if actual._entry_poisoned or actual._entry_request == null or actual._entry_placements == null \
			or actual._entry_token <= 0 or actual._budget == null or actual._budget != actual._entry_placements._budget \
			or actual._budget._token != actual._entry_token or actual._budget._used < Budget.COLD_BYTES \
			or (actual._entry_pin != null and not EntryPlan.same(actual._entry_request, actual._entry_pin)):
		return REFUSE_ENTRY_COLD
	var orders: Orders = actual._orders.get_ref() as Orders if actual._orders != null else null
	if orders == null or orders._bindings == null or orders._bindings.get_ref() != actual \
			or orders._stage_action != Orders.ROOM_ADMISSION_STAGE or not orders._entry_mode or orders._publishing \
			or orders._entry_request != actual._entry_request:
		return REFUSE_ENTRY_COLD
	return _entry_owner_leaf(actual)


static func _entry_owner_leaf(actual: RefCounted) -> StringName:
	"""Borrow only the configured actual World and source owners; native weak-reference reads never call observers."""
	var provider: WorldBindings = actual._provider.get_ref() as WorldBindings if actual._provider != null else null
	var placements: Placements = actual._entry_placements
	var frontier: Frontier = actual._entry_frontier
	if provider == null or provider._owner == null or provider._source_reader == null or frontier == null \
			or provider._owner.get_ref() != placements._space or provider._source_reader.get_ref() != placements._sources \
			or provider._budget != actual._budget or frontier._catalog != placements._catalog \
			or frontier._assemblies != placements._assemblies or frontier._recipes != placements._recipes \
			or frontier._profiles != placements._profiles:
		return REFUSE_ENTRY_SOURCE
	if actual._entry_request.world != placements._world \
			or actual._entry_request.space_revision != placements._space._header[17]:
		return REFUSE_ENTRY_SOURCE
	var code: StringName = Frontier.source_leaf_refusal(frontier)
	return _entry_plan_source_leaf(frontier, actual._entry_request) if code == &"" else code


func room_cold_token() -> int:
	"""Only this confirmed request can expose its already-acquired lease; flat admission stays independent."""
	return _entry_token if _entry_token != 0 else super.room_cold_token()


func entry_cold_refusal(plan: EntryPlan.Request, token: int) -> StringName:
	"""The coordinator checks the original caller identity, not a same-value replacement request."""
	if _entry_busy or token != _entry_token or plan != _entry_request:
		_entry_poisoned = true
		return REFUSE_ENTRY_COLD
	return _entry_scope_leaf(self)


func _preflight_entry() -> StringName:
	"""Prove finite complete source cuts, actual virgin terrain, protected objects and a supported exterior anchor."""
	var code: StringName = _entry_level_refusal()
	if code == &"": code = _entry_anchor_refusal(0)
	if code == &"": code = _entry_surface_contacts_refusal(0)
	if code == &"": code = _entry_cut_set_refusal()
	if code == &"": code = _entry_physical_refusal(0)
	return code


func _entry_level_refusal() -> StringName:
	"""The actual level catalog owns surface height and Domain; connector-local geometry cannot move the surface."""
	var levels: Levels = _actual_levels()
	var domain: Space.Domain = _entry_placements._space.domain_copy()
	if domain == null or levels == null or not levels.binding_matches(domain, _entry_placements._ids, Space.VERSION):
		return REFUSE_LEVEL
	if _entry_pin.base_level != 0 or levels.level_into(0, 0, _level) != &"" \
			or _entry_pin.origin_u.y != _level.floor_y_u or _level.world_ref != _entry_pin.world:
		return REFUSE_LEVEL
	return &""


func _entry_anchor_refusal(space_token: int) -> StringName:
	"""An exact already-published World WORK contact supplies actual natural surface air and footing."""
	var locations: Locations = _entry_placements._locations
	var code: StringName = locations.read_location_into(_entry_pin.anchor, _entry_anchor)
	if code != &"" or _entry_anchor.world != _entry_pin.world or _entry_anchor.room != NULL_REF \
			or _entry_anchor.level != 0 or _entry_anchor.role != Locations.ROLE_WORK \
			or _entry_anchor.geometry_revision != _entry_pin.space_revision:
		return REFUSE_ENTRY_ANCHOR
	var owner: Owner = _entry_placements._space
	code = owner.region_into_reused(_entry_anchor.section, _region)
	if code != &"" or _region.owner != _entry_pin.world or _region.role != Space.FLOOR_DATUM:
		return REFUSE_ENTRY_ANCHOR
	code = _entry_terrain_box(_entry_anchor.envelope, Terrain.EXTERIOR, space_token)
	if code == &"": code = _entry_natural_bearing(_entry_anchor.support, space_token)
	if code == &"": code = _entry_retained_box(_entry_anchor.envelope, false)
	if code == &"": code = _entry_anchor_source_point()
	return code


func _entry_cut_set_refusal() -> StringName:
	"""Stream unique actual paid cubes, require all three authored phases and compare the nonoverlapping CUT census."""
	var domain: Space.Domain = _entry_placements._space.domain_copy()
	if domain == null: return REFUSE_ENTRY_CUTS
	var scope: StringName = _entry_scope_leaf(self)
	if scope != &"": return scope
	var cursor: EntryCuts = EntryCuts.new()
	var code: StringName = cursor.configure(_entry_pin.claims, domain, _entry_checks, _actual_sites().remaining_history_capacity())
	var count: int = 0
	while code == &"" and cursor.advance():
		code = cursor.charge_checks(HISTORY_LOOKUP_CHECKS + _entry_frontier._header[8 + Frontier.EPISODE] * 32)
		if code == &"" and _actual_sites().site_at(cursor.current_origin()) != NULL_REF:
			code = REFUSE_RETAINED
		if code == &"": code = _entry_cube_coverage(cursor.current_origin())
		count += 1
	if code == &"": code = cursor.refusal()
	_entry_checks = cursor.remaining_checks()
	cursor.clear()
	if code == &"": code = _entry_source_cube_count(count)
	return code


func _read_entry_episode(row: int) -> void:
	"""Copy one bounded immutable row under the already-pinned source; no repeated digest walk or callback."""
	for field: int in 19:
		_entry_row[field] = _entry_frontier._episode[field * _entry_frontier._capacities[Frontier.EPISODE] + row]


func _entry_cube_coverage(origin: Vector3i) -> StringName:
	"""Each exact world cube needs BRACE/CUT/FINISH source coverage; no partial-cube permission is inferred."""
	var mask: int = 0
	for row: int in _entry_frontier._header[8 + Frontier.EPISODE]:
		_read_entry_episode(row)
		var local_box: PackedInt32Array = _entry_row.slice(0, 6)
		var world_box: PackedInt32Array = Connectors.transform_box(local_box, _entry_transform)
		if world_box.size() != 6: return REFUSE_ENTRY_CUTS
		if origin.x >= world_box[0] and int(origin.x) + 1024 <= world_box[3] \
				and origin.y >= world_box[1] and int(origin.y) + 1024 <= world_box[4] \
				and origin.z >= world_box[2] and int(origin.z) + 1024 <= world_box[5]:
			mask |= _entry_row[6]
	return &"" if mask == 7 else REFUSE_ENTRY_CUTS


func _entry_source_cube_count(expected: int) -> StringName:
	"""CUT episodes cannot overlap by source validation; equal cardinality closes the reverse inclusion proof."""
	var total: int = 0
	var math: IntMath.IntResult = IntMath.IntResult.new()
	for row: int in _entry_frontier._header[8 + Frontier.EPISODE]:
		if not _entry_spend(32): return REFUSE_MASK_BUDGET
		_read_entry_episode(row)
		if (_entry_row[6] & 2) == 0: continue
		var count: int = 1
		for axis: int in 3:
			@warning_ignore("integer_division") var length: int = (int(_entry_row[axis + 3]) - _entry_row[axis]) / 1024
			if not IntMath.checked_mul_into(count, length, math) or math.value > Sites.MAX_SITE_CAPACITY:
				return REFUSE_ENTRY_CUTS
			count = math.value
		total += count
		if total > expected: return REFUSE_ENTRY_CUTS
	return &"" if total == expected else REFUSE_ENTRY_CUTS


func _entry_spend(checks: int = 1) -> bool:
	"""Every nested geometry walk consumes one shared finite cold-operation budget."""
	if checks < 0 or checks > _entry_checks: return false
	_entry_checks -= checks
	return true


func _entry_physical_refusal(space_token: int) -> StringName:
	"""Check current whole-cut dryness and exclusions, then preserve every authored natural bearing."""
	var paid: StringName = _entry_paid_cube_physics(space_token)
	if paid != &"": return paid
	for row: int in _entry_frontier._header[8 + Frontier.BEARING]:
		if not _entry_spend(12): return REFUSE_MASK_BUDGET
		for field: int in 9:
			_entry_bearing[field] = _entry_frontier._bearing[field * _entry_frontier._capacities[Frontier.BEARING] + row]
		var code: StringName = &""
		if _entry_bearing[0] != Frontier.NATURAL: continue
		var bounds: PackedInt32Array = Connectors.transform_box(_entry_bearing.slice(3, 9), _entry_transform)
		if bounds.size() != 6: return REFUSE_ENTRY_BEARING
		code = _entry_natural_bearing(bounds, space_token)
		if code != &"": return code
	return &""


func _entry_paid_cube_physics(space_token: int) -> StringName:
	"""Fine claims retain their shape; every touched whole paid cube gets fresh physical exclusion proof."""
	var code: StringName = _entry_scope_leaf(self)
	if code != &"": return code
	var cursor: EntryCuts = EntryCuts.new()
	code = cursor.configure(_entry_pin.claims, _entry_placements._space._domain, _entry_checks, Sites.MAX_SITE_CAPACITY)
	while code == &"" and cursor.advance():
		_entry_checks = cursor.remaining_checks()
		var before: int = _entry_checks
		var origin: Vector3i = cursor.current_origin()
		for axis: int in 3:
			_clip[axis] = origin[axis]
			_clip[axis + 3] = origin[axis] + 1024
		code = _entry_terrain_box(_clip, Terrain.DIG, space_token)
		if code == &"": code = _entry_retained_box(_clip, true)
		var charged: StringName = cursor.charge_checks(before - _entry_checks)
		if code == &"": code = charged
	if code == &"": code = cursor.refusal()
	_entry_checks = cursor.remaining_checks()
	cursor.clear()
	return code


func _entry_natural_bearing(bounds: PackedInt32Array, space_token: int) -> StringName:
	"""A later paid cut cannot remove the source's supposedly retained natural load-bearing matter."""
	for row: int in _entry_frontier._header[8 + Frontier.EPISODE]:
		if not _entry_spend(32): return REFUSE_MASK_BUDGET
		_read_entry_episode(row)
		if (_entry_row[6] & 2) == 0: continue
		var paid: PackedInt32Array = Connectors.transform_box(_entry_row.slice(0, 6), _entry_transform)
		if paid.size() != 6 or Space.overlaps(bounds, paid): return REFUSE_ENTRY_BEARING
	var code: StringName = _entry_bearing_history_refusal(bounds)
	if code == &"": code = _entry_terrain_box(bounds, Terrain.FOOTING, space_token)
	if code == &"": code = _entry_terrain_box(bounds, Terrain.EXCLUSIONS, space_token)
	return _entry_retained_box(bounds, true) if code == &"" else code


func _entry_bearing_history_refusal(bounds: PackedInt32Array) -> StringName:
	"""Paid fill never becomes original earth: inspect every intersected canonical key in the existing Site ledger."""
	var scope: StringName = _entry_scope_leaf(self)
	if scope != &"": return scope
	var owner: Owner = _entry_placements._space
	var sites: Sites = _sites.get_ref() as Sites
	var cursor: EntryCuts = EntryCuts.new()
	var code: StringName = cursor.configure(bounds, owner._domain, _entry_checks, Sites.MAX_SITE_CAPACITY)
	while code == &"" and cursor.advance():
		code = cursor.charge_checks(HISTORY_LOOKUP_CHECKS)
		if code != &"": break
		var site: Vector2i = sites.site_at(cursor.current_origin())
		if site != NULL_REF and sites._ever_cut[site.x] != 0:
			code = REFUSE_ENTRY_BEARING
	if code == &"": code = cursor.refusal()
	_entry_checks = cursor.remaining_checks()
	cursor.clear()
	return code


func _entry_terrain_box(bounds: PackedInt32Array, purpose: int, space_token: int) -> StringName:
	"""Tile windows retain exact Y and edges; all real terrain reads use the original revision and candidate."""
	if not Space.valid_box(bounds): return REFUSE_ENTRY_CUTS
	var z: int = bounds[2]
	while z < bounds[5]:
		var x: int = bounds[0]
		var next_z: int = z
		while x < bounds[3]:
			if not _entry_spend(Terrain.LOCAL_QUERY_CHECKS): return REFUSE_MASK_BUDGET
			@warning_ignore("integer_division") var tile_x: int = x / World.TILE_SIZE_UNITS
			@warning_ignore("integer_division") var tile_z: int = z / World.TILE_SIZE_UNITS
			_region.box[0] = x
			_region.box[1] = bounds[1]
			_region.box[2] = z
			_region.box[3] = mini(bounds[3], (tile_x + 8) * World.TILE_SIZE_UNITS)
			_region.box[4] = bounds[4]
			_region.box[5] = mini(bounds[5], (tile_z + 8) * World.TILE_SIZE_UNITS)
			x = _region.box[3]
			next_z = _region.box[5]
			var provider: WorldBindings = _provider.get_ref() as WorldBindings
			var terrain: Terrain = provider._terrain
			var code: StringName = terrain.local_facts_refusal(_region.box, purpose, _entry_pin.space_revision) if space_token == 0 \
				else terrain.prepared_local_facts_refusal(_region.box, purpose, _entry_pin.space_revision, space_token, _entry_token)
			if code != &"": return code
			code = _entry_scope_leaf(self)
			if code != &"": return code
		z = next_z
	return &""


func _entry_natural_support_row(owner: Owner, row: int) -> bool:
	"""Only a current World-owned support label can describe untouched natural footing; live Terrain is still mandatory."""
	return owner._r_role[row] == Space.SUPPORT and owner._r_owner_slot[row] == _entry_pin.world.x \
		and owner._r_owner_generation[row] == _entry_pin.world.y and owner._r_claim_kind[row] == Owner.CLAIM_NONE


func _entry_anchor_source_point() -> StringName:
	"""Every source anchor selector must name the exact existing World contact at the transformed authored point."""
	var found: bool = false
	for row: int in _entry_frontier._header[8 + Frontier.ENDPOINT]:
		if not _entry_spend(16): return REFUSE_MASK_BUDGET
		if _entry_frontier._field(Frontier.ENDPOINT, row, 0) != Frontier.SURFACE_ANCHOR: continue
		found = true
		var point: Vector3i = Vector3i(_entry_frontier._field(Frontier.ENDPOINT, row, 4),
			_entry_frontier._field(Frontier.ENDPOINT, row, 5), _entry_frontier._field(Frontier.ENDPOINT, row, 6))
		var target: PackedInt64Array = Connectors._point64(point, _entry_transform)
		if not Connectors._point_fits(target) or Vector3i(target[0], target[1], target[2]) != _entry_anchor.point \
				or _entry_frontier._field(Frontier.ENDPOINT, row, 3) != _entry_anchor.role:
			return REFUSE_ENTRY_ANCHOR
	return &"" if found else REFUSE_ENTRY_ANCHOR


func _entry_surface_contacts_refusal(space_token: int) -> StringName:
	"""Every authored exterior selector resolves uniquely to an actual supported World endpoint before excavation."""
	for row: int in _entry_frontier._header[8 + Frontier.ENDPOINT]:
		if not _entry_spend(16): return REFUSE_MASK_BUDGET
		if _entry_frontier._field(Frontier.ENDPOINT, row, 0) != Frontier.SURFACE_CONTACT: continue
		var local: Vector3i = Vector3i(_entry_frontier._field(Frontier.ENDPOINT, row, 4),
			_entry_frontier._field(Frontier.ENDPOINT, row, 5), _entry_frontier._field(Frontier.ENDPOINT, row, 6))
		var target: PackedInt64Array = Connectors._point64(local, _entry_transform)
		if not Connectors._point_fits(target): return REFUSE_ENTRY_CONTACT
		var role: int = _entry_frontier._field(Frontier.ENDPOINT, row, 3)
		var code: StringName = _entry_surface_contact(Vector3i(target[0], target[1], target[2]), role, space_token)
		if code != &"": return code
	return &""


func _entry_surface_contact(point: Vector3i, role: int, space_token: int) -> StringName:
	"""A current full endpoint and actual source section are mandatory; source coordinates grant no permission."""
	var locations: Locations = _entry_placements._locations
	if not _entry_spend(256 + 16 * locations._capacity + 4 * _entry_placements._space._source_capacity):
		return REFUSE_MASK_BUDGET
	var row: int = _entry_surface_contact_row(point, role)
	if row < 0: return REFUSE_ENTRY_CONTACT
	var ref: Vector2i = Vector2i(row, locations._get32(locations._live, Locations.GENERATION, row))
	var code: StringName = locations.read_location_into(ref, _entry_contact)
	if code != &"" or _entry_contact.world != _entry_pin.world or _entry_contact.geometry_revision != _entry_pin.space_revision \
			or _entry_contact.payload_revision <= 0 or _entry_contact.room != NULL_REF or _entry_contact.level != 0 \
			or _entry_contact.section != _entry_anchor.section:
		return REFUSE_ENTRY_CONTACT
	code = locations._resolve_section_refusal(NULL_REF, _entry_contact.section, 0, point)
	if code == &"": code = _entry_terrain_box(_entry_contact.envelope, Terrain.EXTERIOR, space_token)
	if code == &"": code = _entry_natural_bearing(_entry_contact.support, space_token)
	if code == &"": code = _entry_retained_box(_entry_contact.envelope, false)
	return code


func _entry_surface_contact_row(point: Vector3i, role: int) -> int:
	"""Scan the exact source anchor namespace; a different full surface section cannot supply the immutable selector."""
	var locations: Locations = _entry_placements._locations
	var found: int = -1
	for row: int in locations._capacity:
		if locations._live.present[row] != 1 or locations._ref_at(locations._live, Locations.ROOM_SLOT, row) != NULL_REF \
				or locations._ref_at(locations._live, Locations.SECTION_SLOT, row) != _entry_anchor.section \
				or locations._get32(locations._live, Locations.LEVEL, row) != 0 \
				or locations._get32(locations._live, Locations.ROLE, row) != role \
				or locations._get32(locations._live, Locations.X, row) != point.x \
				or locations._get32(locations._live, Locations.Y, row) != point.y \
				or locations._get32(locations._live, Locations.Z, row) != point.z:
			continue
		if found >= 0: return -2
		found = row
	return found


func _entry_retained_box(bounds: PackedInt32Array, natural: bool) -> StringName:
	"""Actual sparse rows protect furniture, claims and removed matter; metadata alone grants no clearance."""
	var owner: Owner = _entry_placements._space
	for row: int in owner._r_present.size():
		if owner._r_present[row] == 0: continue
		# The budget bounds live fragmentation; empty capacity slots cost nothing (scales with a real Session).
		if not _entry_spend(): return REFUSE_MASK_BUDGET
		if owner._r_role[row] == Space.FLOOR_DATUM: continue
		if natural and (owner._r_role[row] == Space.DRY_SOLID or _entry_natural_support_row(owner, row)): continue
		if not natural and (owner._r_role[row] == Space.SUPPORTED_VOID): continue
		if bounds[0] < owner._r_hi_x[row] and owner._r_lo_x[row] < bounds[3] \
				and bounds[1] < owner._r_hi_y[row] and owner._r_lo_y[row] < bounds[4] \
				and bounds[2] < owner._r_hi_z[row] and owner._r_lo_z[row] < bounds[5]:
			return REFUSE_CUT
	return &""


func entry_plan_refusal(plan: EntryPlan.Request, candidate: Directory.CreateCandidate,
		section: Vector2i, space_token: int) -> StringName:
	"""Pin only the exact future Room and unsealed candidate after the complete virgin preflight."""
	if _entry_busy or _entry_scope_leaf(self) != &"" or not EntryPlan.same(plan, _entry_pin) \
			or candidate != _actual_orders()._room_candidate or space_token != _entry_placements._space._stage_token:
		return REFUSE_ENTRY_COLD
	_entry_candidate = candidate
	_entry_section = section
	_entry_space_token = space_token
	return &""


func entry_prepared_refusal(plan: EntryPlan.Request, candidate: Directory.CreateCandidate,
		section: Vector2i, space_token: int) -> StringName:
	"""Only the sealed actual candidate may create a Placement and refresh its old physical companions."""
	var code: StringName = _entry_prepared_scope(plan, candidate, section, space_token)
	if code != &"": return code
	_entry_busy = true
	_placement_request = _make_placement_request()
	var result: Placements.Result = _entry_placements.prepare_admission(
		_placement_request, candidate, _actual_orders(), _entry_token, space_token)
	_entry_prepared = result.placement
	_entry_busy = false
	return result.error if result.error != &"" else _entry_scope_leaf(self)


func _make_placement_request() -> Placements.Request:
	"""Copy the admitted target image; only paired null expands into this exact future Room/section."""
	var request: Placements.Request = Placements.Request.new()
	request.corridor = _entry_candidate.ref
	request.section = _entry_section
	request.anchor = _entry_pin.anchor
	request.origin = _entry_pin.origin_u
	request.rotation = _entry_pin.rotation
	request.level = _entry_pin.base_level
	request.targets = _entry_pin.opening_targets.duplicate()
	for at: int in range(0, request.targets.size(), 4):
		if Vector2i(request.targets[at], request.targets[at + 1]) == NULL_REF:
			request.targets[at] = request.corridor.x
			request.targets[at + 1] = request.corridor.y
			request.targets[at + 2] = request.section.x
			request.targets[at + 3] = request.section.y
	return request


func _entry_prepared_scope(plan: EntryPlan.Request, candidate: Directory.CreateCandidate,
		section: Vector2i, token: int) -> StringName:
	"""Keep the original complete mutable request and actual sealed candidate across every preparation stage."""
	if _entry_busy or _entry_scope_leaf(self) != &"" or not EntryPlan.same(plan, _entry_pin) \
			or candidate != _entry_candidate or section != _entry_section or token != _entry_space_token \
			or token <= 0 or _entry_placements._space._stage_token != token or not _entry_placements._space._sealed:
		return REFUSE_ENTRY_COLD
	return &""


func _authority_admission(placement: Vector2i, request: Placements.Request, token: int) -> StringName:
	"""The nested concrete authority cannot authorize a different placement or borrow another cold operation."""
	if not _entry_busy or request != _placement_request or token != _entry_token \
			or _entry_scope_refusal() != &"" or placement != _entry_placements._prepared_placement \
			or request.corridor != _entry_candidate.ref or request.section != _entry_section:
		return REFUSE_ENTRY_COLD
	return &""


func _refresh_entry_locations(placement: Vector2i, token: int, cold_token: int) -> StringName:
	"""A finite scan preserves full old identities and refreshes actual support; no endpoint is fabricated."""
	if _authority_admission(placement, _placement_request, cold_token) != &"": return REFUSE_ENTRY_COLD
	var locations: Locations = _entry_placements._locations
	for row: int in locations._capacity:
		if not _entry_spend(): return REFUSE_MASK_BUDGET
		if locations._live.present[row] == 0: continue
		var ref: Vector2i = Vector2i(row, locations._live.i32[Locations.GENERATION * locations._capacity + row])
		var code: StringName = locations.stage_refresh(token, ref)
		if code != &"": return code
		if _authority_admission(placement, _placement_request, cold_token) != &"": return REFUSE_ENTRY_COLD
	return &""


func _refresh_entry_routes(placement: Vector2i, token: int, cold_token: int) -> StringName:
	"""Existing paths are requalified by the actual bound WorldRoutes source without a retained route map."""
	if _authority_admission(placement, _placement_request, cold_token) != &"": return REFUSE_ENTRY_COLD
	var routes: Routes = _entry_placements._routes
	for row: int in routes._edge_capacity:
		if not _entry_spend(): return REFUSE_MASK_BUDGET
		if routes._live.present[row] == 0: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row])
		var code: StringName = routes.stage_refresh(token, ref)
		if code != &"": return code
		if _authority_admission(placement, _placement_request, cold_token) != &"": return REFUSE_ENTRY_COLD
	return &""


func entry_final_refusal(plan: EntryPlan.Request, candidate: Directory.CreateCandidate,
		section: Vector2i, space_token: int) -> StringName:
	"""Recheck fresh natural facts after every observer, then the actual callback-free companion publication leaf."""
	var code: StringName = _entry_prepared_scope(plan, candidate, section, space_token)
	if code != &"": return code
	_entry_busy = true
	code = _entry_anchor_refusal(space_token)
	if code == &"": code = _entry_surface_contacts_refusal(space_token)
	if code == &"": code = _entry_physical_refusal(space_token)
	if code == &"": code = _entry_scope_leaf(self)
	if code == &"": code = _entry_placements.prepared_admission_leaf_refusal(
		_entry_prepared, candidate, _actual_orders(), _entry_token, space_token)
	_entry_busy = false
	return code


func discard_entry_plan(_room: Vector2i, space_token: int) -> void:
	"""Discard only this provider's still-prepared companion under its original exact caller scope."""
	if _reject_entry_cleanup(): return
	if _entry_prepared != NULL_REF and space_token == _entry_space_token and _entry_candidate != null:
		_entry_placements.discard_admission(_entry_prepared, _entry_candidate, _actual_orders(), _entry_token, space_token)
	_entry_prepared = NULL_REF
	_placement_request = null


func publish_entry_plan(room: Vector2i, space_token: int) -> void:
	"""Publish the already-preflighted exact Placement in the actual Room/Space receipt window, without observation."""
	if _reject_entry_cleanup(): return
	assert(_entry_candidate != null and room == _entry_candidate.ref and space_token == _entry_space_token)
	var code: StringName = _entry_placements.publish_admission(
		_entry_prepared, _entry_candidate, _actual_orders(), _entry_token, space_token)
	assert(code == &"", "Preflighted entry companions publish in their actual Room receipt window")
	_entry_prepared = NULL_REF
	_placement_request = null


func end_entry_cold() -> void:
	"""Drop every private image before releasing the exact original lease; never touch a replacement token."""
	if _reject_entry_cleanup(): return
	_drop_entry()


func _reject_entry_cleanup() -> bool:
	"""Nested observers cannot release the active owner's lease, discard its private plan or publish its future row."""
	if not _entry_busy: return false
	_entry_poisoned = true
	return true


func _drop_entry() -> void:
	"""Keep configured source/geometry owners while clearing only this synchronous admission's derived controls."""
	_entry_request = null
	_entry_pin = null
	_placement_request = null
	_entry_candidate = null
	_entry_prepared = NULL_REF
	_entry_section = NULL_REF
	_entry_space_token = 0
	if _entry_token > 0 and _budget.covers(_entry_token, Budget.COLD_BYTES):
		_budget.release(_entry_token)
	_entry_token = 0
	_entry_checks = 0


func _timber_cold_bytes(placement: Vector2i, assembly: int) -> int:
	"""Fixed storage is already admitted; sequential geometry and companion proofs require one original arena."""
	if _entry_busy or _entry_token != 0 or _room_token != 0 or _entry_placements == null \
			or not _entry_placements._is_live(_entry_placements._live, placement) or assembly < 0 \
			or assembly >= _entry_frontier._header[8 + Frontier.INSTALL]: return 0
	return Budget.COLD_BYTES


func _timber_scope_leaf(proof: TimberClearance = null) -> StringName:
	"""Precharge all bounded immutable-owner/hash leaves before observing the original operation scope."""
	if not (proof.spend(TIMBER_SCOPE_CHECKS) if proof != null else _entry_spend(TIMBER_SCOPE_CHECKS)):
		return REFUSE_MASK_BUDGET
	var p: Placements = _entry_placements
	if _entry_poisoned or p == null or _timber_token <= 0 or p._budget != _budget \
			or not _budget.covers(_timber_token, Budget.COLD_BYTES) or p._cold_token != _timber_token \
			or p._prepared_placement != _timber_placement or p._prepared_project != _timber_project \
			or p._prepared_assembly != _timber_assembly or p._admission_mode \
			or _entry_token != 0 or _entry_request != null or _room_token != 0:
		return REFUSE_ENTRY_COLD
	if Frontier.source_leaf_refusal(_entry_frontier) != &"" or p._completion_context_refusal() != &"" \
			or _entry_frontier._catalog != p._catalog or _entry_frontier._assemblies != p._assemblies \
			or _entry_frontier._recipes != p._recipes or _entry_frontier._profiles != p._profiles \
			or p._live.header[Placements.H_FRONTIER_REV] != _entry_frontier._header[0]: return REFUSE_ENTRY_SOURCE
	for index: int in 32:
		if p._live.digests[96 + index] != _entry_frontier._digests[index]: return REFUSE_ENTRY_SOURCE
	var provider: WorldBindings = _provider.get_ref() as WorldBindings if _provider != null else null
	var sites: Sites = _sites.get_ref() as Sites if _sites != null else null
	return &"" if provider != null and provider._owner != null and provider._owner.get_ref() == p._space and provider._budget == _budget \
		and provider._source_reader != null and provider._source_reader.get_ref() == p._sources and sites != null and sites._construction == p._construction \
		and p._locations._sites != null and p._locations._sites.get_ref() == sites \
		and p._construction._excavation_authority != null and p._construction._excavation_authority.get_ref() == sites \
		else REFUSE_ENTRY_SOURCE


func _timber_preflight(placement: Vector2i, project: Vector2i, assembly: int, cold: int) -> StringName:
	"""Pin the exact paid operation before any callback or variable geometry allocation."""
	if _entry_busy or _reading or _entry_token != 0 or _room_token != 0:
		_entry_poisoned = true
		return REFUSE_MASK_BUSY
	_timber_placement = placement
	_timber_project = project
	_timber_assembly = assembly
	_timber_token = cold
	_entry_poisoned = false
	_entry_checks = _entry_placements._space._domain._checks
	var code: StringName = _timber_scope_leaf()
	if code != &"": return code
	_entry_busy = true
	_reading = true
	if not _authority_binding(_entry_placements, _entry_placements._space,
		_entry_placements._locations, _entry_placements._routes, _budget): code = REFUSE_ENTRY_SOURCE
	if code == &"": code = _timber_scope_leaf()
	if code == &"": code = _timber_physical(0, false)
	_reading = false
	_entry_busy = false
	return code


func _timber_call_scope(placement: Vector2i, project: Vector2i, assembly: int, cold: int) -> StringName:
	"""A nested or different operation cannot inherit the already-held geometry scratch or original lease."""
	if _entry_busy or _reading:
		_entry_poisoned = true
		return REFUSE_MASK_BUSY
	if placement != _timber_placement or project != _timber_project or assembly != _timber_assembly or cold != _timber_token:
		return REFUSE_ENTRY_COLD
	return _timber_scope_leaf()


func _workpiece_refusal(placement: Vector2i, project: Vector2i, action: int,
		bounds: PackedInt32Array, cold: int) -> StringName:
	"""Source scope is retained across live and sealed proofs; no set-down profile or paid delivery is invented."""
	if _entry_busy or _reading or _entry_token != 0 or _room_token != 0:
		_entry_poisoned = true
		return REFUSE_MASK_BUSY
	var p: Placements = _entry_placements
	if p == null or p._prepared_action != action or (action != Placements.Contract.START and action != Placements.Contract.CANCEL):
		return REFUSE_ENTRY_COLD
	if p._cold_token != cold or p._prepared_placement != placement or p._prepared_project != project \
			or p._workpiece_context_leaf(p._actual_workpieces()) != &"": return REFUSE_ENTRY_COLD
	if _timber_token != cold and p._space_token == 0:
		_timber_placement = placement
		_timber_project = project
		_timber_assembly = p._prepared_assembly
		_timber_token = cold
		_entry_poisoned = false
		_entry_checks = p._space._domain._checks
	var code: StringName = _timber_call_scope(placement, project, p._prepared_assembly, cold)
	if code == &"": code = p._workpiece_context_leaf(p._actual_workpieces())
	if code != &"": return code
	_entry_busy = true
	_reading = true
	code = _workpiece_physical(bounds, p._space_token)
	_reading = false
	_entry_busy = false
	return code


func _workpiece_physical(bounds: PackedInt32Array, token: int) -> StringName:
	"""Reuse sequential fragment scratch; support and actual occupied air remain independent complete proofs."""
	var p: Placements = _entry_placements
	if not Space.valid_box(bounds) or not Space.contains_box(p._space._domain._bounds, bounds) \
			or not _budget.covers(_timber_token, 48 * p._space._region_capacity + ENTRY_FIXED_BYTES): return REFUSE_ENTRY_COLD
	var proof: TimberClearance = TimberClearance.new()
	proof.allocate_rows(p._space._region_capacity, _entry_checks)
	var code: StringName = _timber_terrain(proof, bounds, Terrain.EXCLUSIONS, token)
	if code == &"": code = _workpiece_air(proof, bounds, token)
	if code == &"": code = _workpiece_foot(proof, bounds, token)
	if code == &"": code = _workpiece_occupants(proof, bounds)
	if code == &"": code = _timber_scope_leaf(proof)
	if code == &"": code = p._workpiece_context_leaf(p._actual_workpieces())
	_entry_checks = proof.remaining
	return code


func _workpiece_air(proof: TimberClearance, bounds: PackedInt32Array, token: int) -> StringName:
	"""An unfinished cube or another obstacle cannot become air merely because the source calls it a set-down."""
	var owner: Owner = _entry_placements._space
	proof.start(bounds)
	for row: int in owner._region_capacity:
		if not proof.spend(): return REFUSE_MASK_BUDGET
		if owner._r_present[row] != 1 or owner._r_role[row] == Space.FLOOR_DATUM \
				or _timber_claim(row, false) or _workpiece_live_row(row): continue
		if not proof.spend(12): return REFUSE_MASK_BUDGET
		_timber_region_box(row, false, proof.cover)
		if not Space.overlaps(bounds, proof.cover): continue
		if owner._r_role[row] != Space.SUPPORTED_VOID or not _timber_void_row(row, false): return REFUSE_TIMBER_CUT
		if not proof.subtract_cover(): return REFUSE_MASK_BUDGET
	for row: int in proof.count:
		for axis: int in 6: proof.box[axis] = proof.fragments[row * 6 + axis]
		var code: StringName = _timber_terrain(proof, proof.box, Terrain.EXTERIOR, token)
		if code != &"": return code
	return &""


func _workpiece_live_row(row: int) -> bool:
	"""Only the exact bound full Project obstacle may be excluded while proving its own removal or set-down space."""
	var p: Placements = _entry_placements
	var owner: Owner = p._space
	return p._prepared_obstacle.x == row and p._prepared_obstacle.y == owner._r_generation[row] \
		and owner._r_present[row] == 1 and owner._r_role[row] == Space.OBSTACLE \
		and owner._r_claim_kind[row] == Owner.CLAIM_NONE and owner._r_owner_slot[row] == _timber_project.x \
		and owner._r_owner_generation[row] == _timber_project.y and p._workpieces != null


func _workpiece_foot(proof: TimberClearance, bounds: PackedInt32Array, token: int) -> StringName:
	"""The entire authored rectangular bottom plane needs existing real support; no new support row is created."""
	if bounds[1] == -2147483648: return REFUSE_TIMBER_BEARING
	for axis: int in 6: _cube[axis] = bounds[axis]
	_cube[4] = _cube[1]
	_cube[1] -= 1
	var code: StringName = _timber_terrain(proof, _cube, Terrain.EXCLUSIONS, token)
	if code != &"": return code
	proof.start(_cube)
	var owner: Owner = _entry_placements._space
	for row: int in owner._region_capacity:
		if not proof.spend(): return REFUSE_MASK_BUDGET
		if owner._r_present[row] != 1 or owner._r_role[row] == Space.FLOOR_DATUM or _timber_claim(row, false): continue
		if not proof.spend(12): return REFUSE_MASK_BUDGET
		_timber_region_box(row, false, proof.cover)
		if not Space.overlaps(_cube, proof.cover): continue
		if owner._r_claim_kind[row] != Owner.CLAIM_NONE or owner._r_role[row] not in [Space.SUPPORT, Space.DRY_SOLID]:
			return REFUSE_TIMBER_BEARING
		if owner._r_role[row] == Space.SUPPORT:
			code = _workpiece_support_cover(proof, row)
			if code != &"": return code
	return _workpiece_natural_foot(proof, token)


func _workpiece_support_cover(proof: TimberClearance, row: int) -> StringName:
	"""Only an exact prior paid prism discharges terrain proof; retained natural supports still check cut history."""
	var owner: Owner = _entry_placements._space
	var source: Vector2i = Vector2i(owner._r_owner_slot[row], owner._r_owner_generation[row])
	if source == _entry_placements._world: return &""
	if source != _timber_room(): return REFUSE_TIMBER_BEARING
	var groups: Placements.Assemblies = _entry_placements._assemblies
	for group: int in _timber_assembly:
		if not proof.spend(4): return REFUSE_MASK_BUDGET
		for part: int in range(groups._first_part[group], groups._first_part[group] + groups._part_count[group]):
			if not proof.spend(64): return REFUSE_MASK_BUDGET
			var code: StringName = Locations.installed_prism_into(_entry_placements, _timber_placement.x, part, proof.box)
			if code != &"": return code
			if Space.contains_box(proof.box, proof.cover):
				return &"" if proof.subtract_cover() else REFUSE_MASK_BUDGET
	return &""


func _workpiece_natural_foot(proof: TimberClearance, token: int) -> StringName:
	"""Residual footing is positively observed virgin matter, with exact permanent paid-key history retained."""
	for row: int in proof.count:
		for axis: int in 6: proof.box[axis] = proof.fragments[row * 6 + axis]
		var code: StringName = _timber_virgin_keys(proof, proof.box)
		if code == &"": code = _timber_natural_rows(proof, proof.box)
		if code == &"": code = _timber_terrain(proof, proof.box, Terrain.FOOTING, token)
		if code != &"": return code
	return &""


func _workpiece_occupants(proof: TimberClearance, bounds: PackedInt32Array) -> StringName:
	"""Exact current actors include unregistered-live refusals; no source observer follows the direct body proof."""
	if not proof.spend(16 * Routes.RESIDENT_CAPACITY): return REFUSE_MASK_BUDGET
	var actual: WorldRoutes = _entry_placements._world_routes
	var checks: int = WorldRoutes.workpiece_occupancy_checks(actual)
	if not proof.spend(checks - 16 * Routes.RESIDENT_CAPACITY): return REFUSE_MASK_BUDGET
	return WorldRoutes.workpiece_occupancy_refusal(actual, bounds, checks)


func _timber_physical(space_token: int, staging: bool) -> StringName:
	"""One sequential cold packet proves dependencies and complete parts; it dies before Locations allocate a survey."""
	var p: Placements = _entry_placements
	var code: StringName = _timber_scope_leaf()
	if code != &"" or not _budget.covers(_timber_token, 48 * p._space._region_capacity + ENTRY_FIXED_BYTES):
		return code if code != &"" else REFUSE_ENTRY_COLD
	var proof: TimberClearance = TimberClearance.new()
	proof.allocate_rows(p._space._region_capacity, _entry_checks)
	code = _timber_dependencies(proof, space_token if not staging else 0, staging)
	if code == &"": code = _timber_connections(proof)
	if code == &"": code = _timber_parts(proof, space_token, staging)
	if code == &"" and not staging: code = _timber_contact_air(proof, space_token, false)
	if code == &"": code = _timber_scope_leaf(proof)
	_entry_checks = proof.remaining
	return code


func _read_timber_install() -> void:
	"""Borrow exact immutable fields in existing fixed admission scratch; no second assembly record is retained."""
	for field: int in 9:
		_entry_row[field] = _entry_frontier._install[field * _entry_frontier._capacities[Frontier.INSTALL] + _timber_assembly]


func _timber_dependencies(proof: TimberClearance, space_token: int, staging: bool = false) -> StringName:
	"""Every named cut and prior bearing remains real; the pending assembly cannot support itself."""
	_read_timber_install()
	for row: int in range(_entry_row[3], _entry_row[3] + _entry_row[4]):
		if not proof.spend(8): return REFUSE_MASK_BUDGET
		var code: StringName = _timber_source_box(Frontier.CUT, row, 0, _cube)
		if code == &"": code = _timber_cut_keys(proof, _cube, _entry_frontier._cut[6 * _entry_frontier._capacities[Frontier.CUT] + row])
		if code != &"": return code
	for row: int in range(_entry_row[5], _entry_row[5] + _entry_row[6]):
		var code: StringName = _timber_bearing(proof, row, space_token, staging)
		if code != &"": return code
	if _entry_placements._workpieces != null:
		return _entry_placements._workpiece_context_leaf(_entry_placements._actual_workpieces())
	return _timber_bearing(proof, _entry_row[2], space_token, staging)


func _timber_source_box(table: int, row: int, first: int, out: PackedInt32Array) -> StringName:
	"""Read exact source coordinates before a checked integer quarter turn, without a copied input table."""
	var low: Vector3i = Vector3i(_entry_frontier._field(table, row, first),
		_entry_frontier._field(table, row, first + 1), _entry_frontier._field(table, row, first + 2))
	var high: Vector3i = Vector3i(_entry_frontier._field(table, row, first + 3),
		_entry_frontier._field(table, row, first + 4), _entry_frontier._field(table, row, first + 5))
	return Locations._installed_world_box(_entry_placements, _timber_placement.x, low, high, out)


func _timber_site_row(point: Vector3i) -> int:
	"""Read the actual nonrecycled paid-key ledger without a spatial provider callback."""
	var sites: Sites = _sites.get_ref() as Sites
	var key: int = sites._key_at(point)
	if key < 0: return -1
	var at: int = sites._key_lower_bound(key)
	if at >= sites._count or sites._ordered_key[at] != key: return -1
	var row: int = sites._ordered_row[at]
	return row if row >= 0 and row < sites._count and sites._present[row] == 1 else -1


func _timber_cut_keys(proof: TimberClearance, bounds: PackedInt32Array, phase: int) -> StringName:
	"""The immutable whole-key dependency is an exact stable phase, never a numeric progress comparison."""
	var sites: Sites = _sites.get_ref() as Sites
	var room: Vector2i = _timber_room()
	var datum: Vector3i = _entry_placements._space._domain._datum
	for axis: int in 3:
		if (int(bounds[axis]) - datum[axis]) % 1024 != 0 or (int(bounds[axis + 3]) - datum[axis]) % 1024 != 0:
			return REFUSE_TIMBER_CUT
	var y: int = bounds[1]
	while y < bounds[4]:
		var z: int = bounds[2]
		while z < bounds[5]:
			var x: int = bounds[0]
			while x < bounds[3]:
				if not proof.spend(20): return REFUSE_MASK_BUDGET
				var row: int = _timber_site_row(Vector3i(x, y, z))
				if row < 0 or sites._phase[row] != phase or sites._room_slot[row] != room.x \
						or sites._room_generation[row] != room.y: return REFUSE_TIMBER_CUT
				x += 1024
			z += 1024
		y += 1024
	return &""


func _timber_room() -> Vector2i:
	"""The lasting physical owner is the exact permanent Corridor, never the transient paid Project or World."""
	return _entry_placements._pair(_entry_placements._live, Placements.ROOM_SLOT, _timber_placement.x)


func _timber_bearing(proof: TimberClearance, row: int, space_token: int, staging: bool) -> StringName:
	"""Revalidate explicit natural or prior installed source bearings; no part kind invents structural support."""
	if not proof.spend(12): return REFUSE_MASK_BUDGET
	for field: int in 9:
		_entry_bearing[field] = _entry_frontier._bearing[field * _entry_frontier._capacities[Frontier.BEARING] + row]
	var code: StringName = _timber_source_box(Frontier.BEARING, row, 3, _cube)
	if code != &"": return code
	if _entry_bearing[0] == Frontier.NATURAL:
		code = _timber_virgin_keys(proof, _cube)
		if code == &"": code = _timber_natural_rows(proof, _cube)
		if code == &"" and not staging: code = _timber_terrain(proof, _cube, Terrain.FOOTING, space_token)
	else:
		code = _timber_installed_bearing(proof, _cube)
	if code == &"" and not staging: code = _timber_terrain(proof, _cube, Terrain.EXCLUSIONS, space_token)
	return code


func _timber_virgin_keys(proof: TimberClearance, bounds: PackedInt32Array) -> StringName:
	"""Permanent paid history prevents backfill or removed earth from being relabelled natural bearing."""
	var sites: Sites = _sites.get_ref() as Sites
	var datum: Vector3i = _entry_placements._space._domain._datum
	var y: int = datum.y + Locations._floor_div(int(bounds[1]) - datum.y, 1024) * 1024
	while y < bounds[4]:
		var z: int = datum.z + Locations._floor_div(int(bounds[2]) - datum.z, 1024) * 1024
		while z < bounds[5]:
			var x: int = datum.x + Locations._floor_div(int(bounds[0]) - datum.x, 1024) * 1024
			while x < bounds[3]:
				if not proof.spend(20): return REFUSE_MASK_BUDGET
				var row: int = _timber_site_row(Vector3i(x, y, z))
				if row >= 0 and sites._ever_cut[row] != 0: return REFUSE_TIMBER_BEARING
				x += 1024
			z += 1024
		y += 1024
	return &""


func _timber_natural_rows(proof: TimberClearance, bounds: PackedInt32Array) -> StringName:
	"""Retained geometry can invalidate original matter even while the immutable terrain survey is unchanged."""
	var owner: Owner = _entry_placements._space
	for row: int in owner._region_capacity:
		if not proof.spend(): return REFUSE_MASK_BUDGET
		if owner._r_present[row] != 1 or owner._r_role[row] == Space.FLOOR_DATUM or _timber_claim(row, false): continue
		if not proof.spend(12): return REFUSE_MASK_BUDGET
		_timber_region_box(row, false, proof.cover)
		if not Space.overlaps(bounds, proof.cover): continue
		if owner._r_claim_kind[row] != Owner.CLAIM_NONE or owner._r_role[row] not in [Space.DRY_SOLID, Space.SUPPORT]:
			return REFUSE_TIMBER_BEARING
	return &""


func _timber_installed_bearing(proof: TimberClearance, bounds: PackedInt32Array) -> StringName:
	"""An exact earlier group and real retained support must cover the named source prism before this operation."""
	var groups: Placements.Assemblies = _entry_placements._assemblies
	var group: int = _entry_bearing[1]
	var part: int = _entry_bearing[2]
	if group < 0 or group >= _timber_assembly or part < groups._first_part[group] \
			or part >= groups._first_part[group] + groups._part_count[group]: return REFUSE_TIMBER_BEARING
	var code: StringName = Locations.installed_prism_into(_entry_placements, _timber_placement.x, part, proof.cover)
	if code != &"" or not Space.contains_box(proof.cover, bounds): return REFUSE_TIMBER_BEARING
	proof.start(bounds)
	var owner: Owner = _entry_placements._space
	for row: int in owner._region_capacity:
		if not proof.spend(): return REFUSE_MASK_BUDGET
		if owner._r_present[row] != 1 or owner._r_role[row] == Space.FLOOR_DATUM or _timber_claim(row, false): continue
		if not proof.spend(12): return REFUSE_MASK_BUDGET
		_timber_region_box(row, false, proof.cover)
		if not Space.overlaps(bounds, proof.cover): continue
		if not _timber_owned(row, false) or owner._r_claim_kind[row] != Owner.CLAIM_NONE \
				or owner._r_role[row] not in [Space.SUPPORT, Space.OBSTACLE]: return REFUSE_TIMBER_BEARING
		if not proof.subtract_cover(): return REFUSE_MASK_BUDGET
	return &"" if proof.count == 0 else REFUSE_TIMBER_BEARING


func _timber_terrain(proof: TimberClearance, bounds: PackedInt32Array, purpose: int, space_token: int) -> StringName:
	"""Current mixed-height exclusions and matter use the original live or exact sealed candidate scope."""
	var z: int = bounds[2]
	while z < bounds[5]:
		var x: int = bounds[0]
		var next_z: int = z
		while x < bounds[3]:
			if not proof.spend(Terrain.LOCAL_QUERY_CHECKS): return REFUSE_MASK_BUDGET
			_region.box[0] = x
			_region.box[1] = bounds[1]
			_region.box[2] = z
			_region.box[3] = mini(bounds[3], (Locations._floor_div(x, World.TILE_SIZE_UNITS) + 8) * World.TILE_SIZE_UNITS)
			_region.box[4] = bounds[4]
			_region.box[5] = mini(bounds[5], (Locations._floor_div(z, World.TILE_SIZE_UNITS) + 8) * World.TILE_SIZE_UNITS)
			x = _region.box[3]
			next_z = _region.box[5]
			var terrain: Terrain = (_provider.get_ref() as WorldBindings)._terrain
			var code: StringName = terrain.local_facts_refusal(_region.box, purpose, _entry_placements._base_geometry_revision) \
				if space_token == 0 else terrain.prepared_local_facts_refusal(_region.box, purpose,
					_entry_placements._base_geometry_revision, space_token, _timber_token)
			if code != &"": return code
			code = _timber_scope_leaf(proof)
			if code != &"": return code
		z = next_z
	return &""


func _timber_region_box(row: int, staged: bool, out: PackedInt32Array) -> void:
	"""Direct scalar observation borrows no per-region array and dispatches no source callback."""
	var owner: Owner = _entry_placements._space
	out[0] = owner._s_r_lo_x[row] if staged else owner._r_lo_x[row]
	out[1] = owner._s_r_lo_y[row] if staged else owner._r_lo_y[row]
	out[2] = owner._s_r_lo_z[row] if staged else owner._r_lo_z[row]
	out[3] = owner._s_r_hi_x[row] if staged else owner._r_hi_x[row]
	out[4] = owner._s_r_hi_y[row] if staged else owner._r_hi_y[row]
	out[5] = owner._s_r_hi_z[row] if staged else owner._r_hi_z[row]


func _timber_owned(row: int, staged: bool) -> bool:
	"""Only the exact permanent Corridor's full source identity belongs to this assembly."""
	var owner: Owner = _entry_placements._space
	return Vector2i(owner._s_r_owner_slot[row], owner._s_r_owner_generation[row]) == _timber_room() if staged \
		else Vector2i(owner._r_owner_slot[row], owner._r_owner_generation[row]) == _timber_room()


func _timber_claim(row: int, staged: bool) -> bool:
	"""Typed ownership markers alone are nonphysical; no other Room, reservation or physical wall is exempt."""
	var owner: Owner = _entry_placements._space
	if not _timber_owned(row, staged): return false
	return owner._s_r_claim_kind[row] == Owner.CLAIM_ROOM and owner._s_r_role[row] == Space.OBSTACLE \
		and Vector2i(owner._s_r_claim_slot[row], owner._s_r_claim_generation[row]) == _timber_room() if staged \
		else owner._r_claim_kind[row] == Owner.CLAIM_ROOM and owner._r_role[row] == Space.OBSTACLE \
		and Vector2i(owner._r_claim_slot[row], owner._r_claim_generation[row]) == _timber_room()


func _timber_parts(proof: TimberClearance, token: int, staging: bool) -> StringName:
	"""A billable group publishes its complete part interval exactly once, never just its recipe anchor."""
	var groups: Placements.Assemblies = _entry_placements._assemblies
	var first: int = groups._first_part[_timber_assembly]
	var end: int = first + groups._part_count[_timber_assembly]
	for part: int in range(first, end):
		if not proof.spend(64): return REFUSE_MASK_BUDGET
		var code: StringName = Locations.installed_prism_into(_entry_placements, _timber_placement.x, part, _cube)
		if code == &"" and not staging: code = _timber_terrain(proof, _cube, Terrain.EXCLUSIONS, token)
		if code == &"": code = _timber_part_clearance(proof, token, staging)
		if code == &"" and staging: code = _stage_timber_part(proof, part, token)
		if code != &"": return code
	return _stage_timber_datums(proof, token) if staging else &""


func _timber_part_clearance(proof: TimberClearance, token: int, staging: bool) -> StringName:
	"""Paid cavities or positively observed exterior are required for all timber, including buried bearers."""
	var owner: Owner = _entry_placements._space
	proof.start(_cube)
	for row: int in owner._region_capacity:
		if not proof.spend(): return REFUSE_MASK_BUDGET
		if owner._r_present[row] != 1 or owner._r_role[row] == Space.FLOOR_DATUM or _timber_claim(row, false) \
				or _workpiece_live_row(row): continue
		if not proof.spend(12): return REFUSE_MASK_BUDGET
		_timber_region_box(row, false, proof.cover)
		if not Space.overlaps(_cube, proof.cover): continue
		if not _timber_void_row(row, false): return REFUSE_TIMBER_CUT
		if not proof.subtract_cover(): return REFUSE_MASK_BUDGET
	if staging: return &""
	for row: int in proof.count:
		if not proof.spend(): return REFUSE_MASK_BUDGET
		for axis: int in 6: proof.box[axis] = proof.fragments[row * 6 + axis]
		var code: StringName = _timber_terrain(proof, proof.box, Terrain.EXTERIOR, token)
		if code != &"": return REFUSE_TIMBER_CUT
	return &""


func _timber_void_row(row: int, staged: bool) -> bool:
	"""Only same-Corridor paid cavity or this World's already-retained exterior air may contain a new part."""
	var owner: Owner = _entry_placements._space
	var role: int = owner._s_r_role[row] if staged else owner._r_role[row]
	var claim: int = owner._s_r_claim_kind[row] if staged else owner._r_claim_kind[row]
	if claim != Owner.CLAIM_NONE: return false
	if _timber_owned(row, staged): return role == Space.SUPPORTED_VOID or role == Space.UNFINISHED
	var source: Vector2i = Vector2i(owner._s_r_owner_slot[row], owner._s_r_owner_generation[row]) if staged \
		else Vector2i(owner._r_owner_slot[row], owner._r_owner_generation[row])
	return source == _entry_placements._world and role == Space.SUPPORTED_VOID


func _stage_timber(placement: Vector2i, project: Vector2i, assembly: int, token: int, cold: int) -> StringName:
	"""Geometry mutation is confined to the exact already-open installation token and preserves its original scope."""
	var code: StringName = _timber_call_scope(placement, project, assembly, cold)
	if code != &"" or token != _entry_placements._space_token or token <= 0: return REFUSE_ENTRY_COLD
	_entry_busy = true
	_reading = true
	code = _timber_physical(token, true)
	_reading = false
	_entry_busy = false
	return code


func _stage_timber_part(proof: TimberClearance, part: int, token: int) -> StringName:
	"""Remove only the exact new solid from retained air, emitting disjoint residual slabs with original identities."""
	var owner: Owner = _entry_placements._space
	for row: int in owner._region_capacity:
		if not proof.spend(): return REFUSE_MASK_BUDGET
		if owner._s_r_present[row] != 1 or not _timber_void_row(row, true): continue
		if not proof.spend(12): return REFUSE_MASK_BUDGET
		_timber_region_box(row, true, proof.box)
		if not Space.overlaps(_cube, proof.box): continue
		var code: StringName = _timber_partition_row(proof, row, token)
		if code != &"": return code
	var catalog: ConnectorCatalog = _entry_placements._catalog
	var at: int = catalog._live.variants[ConnectorCatalog.V_PART_START * ConnectorCatalog.MAX_VARIANTS \
		+ _entry_placements._live.header[Placements.H_CATALOG_ROW]] + part
	_region.owner = _timber_room()
	_region.level = _entry_placements._get32(_entry_placements._live, Placements.LEVEL, _timber_placement.x) \
		+ catalog._live.parts[2 * ConnectorCatalog.MAX_PARTS + at]
	_region.section = _entry_placements._pair(_entry_placements._live, Placements.SECTION_SLOT, _timber_placement.x)
	if owner._s_r_level[_region.section.x] != _region.level: _region.section = NULL_REF
	_region.role = Space.SUPPORT if catalog._live.parts[at] in [ConnectorCatalog.Geometry.TREAD,
		ConnectorCatalog.Geometry.RISER, ConnectorCatalog.Geometry.POST, ConnectorCatalog.Geometry.RAMP_DECK] else Space.OBSTACLE
	_region.claim_kind = Owner.CLAIM_NONE
	_region.claim_ref = NULL_REF
	for axis: int in 6: _region.box[axis] = _cube[axis]
	if not proof.spend(owner._source_capacity + 32): return REFUSE_MASK_BUDGET
	var added: Owner.Result = owner.stage_add(token, _region)
	return _timber_scope_leaf(proof) if added.error == &"" else added.error


func _timber_partition_row(proof: TimberClearance, row: int, token: int) -> StringName:
	"""The original source, section and role survive subtraction; no cut history, fill or yield is changed."""
	var owner: Owner = _entry_placements._space
	_region.owner = Vector2i(owner._s_r_owner_slot[row], owner._s_r_owner_generation[row])
	_region.section = Vector2i(owner._s_r_section_slot[row], owner._s_r_section_generation[row])
	_region.level = owner._s_r_level[row]
	_region.role = owner._s_r_role[row]
	_region.claim_kind = Owner.CLAIM_NONE
	_region.claim_ref = NULL_REF
	proof.start(proof.box)
	for axis: int in 6: proof.cover[axis] = _cube[axis]
	if not proof.subtract_cover(): return REFUSE_MASK_BUDGET
	if not proof.spend(owner._source_capacity + 32): return REFUSE_MASK_BUDGET
	var code: StringName = owner.stage_remove(token, Vector2i(row, owner._s_r_generation[row]))
	if code != &"": return code
	code = _timber_scope_leaf(proof)
	for fragment: int in proof.count:
		if code != &"": return code
		if not proof.spend(owner._source_capacity + 16): return REFUSE_MASK_BUDGET
		for axis: int in 6: _region.box[axis] = proof.fragments[fragment * 6 + axis]
		code = owner.stage_add(token, _region).error
		if code == &"": code = _timber_scope_leaf(proof)
	return code


func _timber_final(placement: Vector2i, project: Vector2i, assembly: int, cold: int) -> StringName:
	"""Final prepayment observations repeat current dependencies and exclusions under the exact sealed Space token."""
	var code: StringName = _timber_call_scope(placement, project, assembly, cold)
	if code != &"": return code
	var owner: Owner = _entry_placements._space
	if not owner._sealed or owner._stage_token != _entry_placements._space_token: return REFUSE_ENTRY_COLD
	_entry_busy = true
	_reading = true
	code = _timber_physical(owner._stage_token, false)
	_reading = false
	_entry_busy = false
	return code


func _discard_timber(placement: Vector2i, project: Vector2i, cold: int) -> void:
	"""Original provider controls are the only cleanup ownership here; never release another arena or candidate."""
	if _entry_busy or _reading:
		_entry_poisoned = true
		return
	if placement != _timber_placement or project != _timber_project or cold != _timber_token: return
	_timber_placement = NULL_REF
	_timber_project = NULL_REF
	_timber_assembly = -1
	_timber_token = 0


func _timber_connections(proof: TimberClearance) -> StringName:
	"""The exact authored group must physically connect to every proved bearing; no span-strength formula is inferred."""
	_read_timber_install()
	var start: int = _entry_row[5]
	var end: int = start + _entry_row[6]
	for index: int in 16: _entry_row[index] = 0 #256 parts, sixteen safe low bits per reusedI32.
	for bearing: int in range(start, end):
		var bearing_code: StringName = _timber_connect_bearing(proof, bearing)
		if bearing_code != &"": return bearing_code
	return _timber_connect_parts(proof)


func _timber_connect_bearing(proof: TimberClearance, bearing: int) -> StringName:
	"""Actual positive-area bottom contact roots the component; metadata proximity is not support."""
	var code: StringName = _timber_source_box(Frontier.BEARING, bearing, 3, _cube)
	if code != &"": return code
	var groups: Placements.Assemblies = _entry_placements._assemblies
	var first: int = groups._first_part[_timber_assembly]
	var found: bool = false
	for index: int in groups._part_count[_timber_assembly]:
		if not proof.spend(64): return REFUSE_MASK_BUDGET
		code = Locations.installed_prism_into(_entry_placements, _timber_placement.x, first + index, _clip)
		if code != &"": return code
		if _clip[1] == _cube[4] and _clip[0] < _cube[3] and _cube[0] < _clip[3] \
				and _clip[2] < _cube[5] and _cube[2] < _clip[5]:
			_timber_mark(index)
			found = true
	return &"" if found else REFUSE_TIMBER_BEARING


func _timber_mark(index: int) -> void:
	"""Borrow bounded cold row scratch for graph reachability, never add a per-part paid or support ledger."""
	@warning_ignore("integer_division") var word: int = index / 16
	_entry_row[word] |= 1 << (index % 16)


func _timber_marked(index: int) -> bool:
	"""All bit positions stay within positive int32; the source-counted group has at most256 parts."""
	@warning_ignore("integer_division") var word: int = index / 16
	return (_entry_row[word] & (1 << (index % 16))) != 0


func _timber_connect_parts(proof: TimberClearance) -> StringName:
	"""Bounded fixed-point reachability refuses every disconnected prism even when another part reaches the ground."""
	var groups: Placements.Assemblies = _entry_placements._assemblies
	var count: int = groups._part_count[_timber_assembly]
	var first: int = groups._first_part[_timber_assembly]
	var changed: bool = true
	while changed:
		changed = false
		for index: int in count:
			if not proof.spend(): return REFUSE_MASK_BUDGET
			if _timber_marked(index): continue
			var code: StringName = Locations.installed_prism_into(_entry_placements, _timber_placement.x, first + index, _cube)
			if code != &"": return code
			for other: int in count:
				if not proof.spend(64): return REFUSE_MASK_BUDGET
				if not _timber_marked(other): continue
				code = Locations.installed_prism_into(_entry_placements, _timber_placement.x, first + other, _clip)
				if code != &"": return code
				if _timber_connected(_cube, _clip):
					_timber_mark(index)
					changed = true
					break
	for index: int in count:
		if not _timber_marked(index): return REFUSE_TIMBER_BEARING
	return &""


static func _timber_connected(first: PackedInt32Array, second: PackedInt32Array) -> bool:
	"""Positive volume or positive face contact can join prisms; an edge or isolated point cannot carry an assembly."""
	var planes: int = 0
	for axis: int in 3:
		var low: int = maxi(first[axis], second[axis])
		var high: int = mini(first[axis + 3], second[axis + 3])
		if low > high: return false
		planes += int(low == high)
	return planes <= 1


func _timber_landing_into(endpoint: int) -> StringName:
	"""One selector names an exact Catalog LANDING; its transformed box is metadata only."""
	var source: Frontier = _entry_frontier
	var ordinal: int = source._field(Frontier.ENDPOINT, endpoint, 2)
	var catalog: ConnectorCatalog = _entry_placements._catalog
	var variant: int = _entry_placements._live.header[Placements.H_CATALOG_ROW]
	if ordinal < 0 or ordinal >= catalog._live.variants[ConnectorCatalog.V_REGION_COUNT * ConnectorCatalog.MAX_VARIANTS + variant]:
		return REFUSE_TIMBER_CONTACT
	var at: int = catalog._live.variants[ConnectorCatalog.V_REGION_START * ConnectorCatalog.MAX_VARIANTS + variant] + ordinal
	if catalog._live.regions[6 * ConnectorCatalog.MAX_REGIONS + at] != Space.LANDING: return REFUSE_TIMBER_CONTACT
	var low: Vector3i = Vector3i(catalog._live.regions[at], catalog._live.regions[ConnectorCatalog.MAX_REGIONS + at],
		catalog._live.regions[2 * ConnectorCatalog.MAX_REGIONS + at])
	var high: Vector3i = Vector3i(catalog._live.regions[3 * ConnectorCatalog.MAX_REGIONS + at],
		catalog._live.regions[4 * ConnectorCatalog.MAX_REGIONS + at], catalog._live.regions[5 * ConnectorCatalog.MAX_REGIONS + at])
	var code: StringName = Locations._installed_world_box(_entry_placements, _timber_placement.x, low, high, _cube)
	if code != &"": return code
	_entry_contact.room = _timber_room()
	_entry_contact.level = _entry_placements._get32(_entry_placements._live, Placements.LEVEL, _timber_placement.x) \
		+ catalog._live.regions[7 * ConnectorCatalog.MAX_REGIONS + at]
	_entry_contact.role = source._field(Frontier.ENDPOINT, endpoint, 3)
	for axis: int in 3:
		var value: int = Locations.installed_coordinate(_entry_placements, _timber_placement.x,
			source._field(Frontier.ENDPOINT, endpoint, 4), source._field(Frontier.ENDPOINT, endpoint, 5),
			source._field(Frontier.ENDPOINT, endpoint, 6), axis)
		if not Space.int32(value): return REFUSE_TIMBER_CONTACT
		_entry_contact.point[axis] = value
	return &"" if _entry_contact.point.y == _cube[1] else REFUSE_TIMBER_CONTACT


func _timber_datum_ref() -> Vector2i:
	"""Reuse exactly equal same-source metadata or reject ambiguity; nearby rectangles are not interchangeable."""
	var owner: Owner = _entry_placements._space
	var found: Vector2i = NULL_REF
	for row: int in owner._region_capacity:
		if not _entry_spend(): return Vector2i(-3, 0)
		if owner._s_r_present[row] != 1: continue
		if not _entry_spend(12): return Vector2i(-3, 0)
		if owner._s_r_role[row] != Space.FLOOR_DATUM \
				or owner._s_r_level[row] != _entry_contact.level or not _timber_owned(row, true): continue
		_timber_region_box(row, true, _clip)
		if _clip != _cube: continue
		if found != NULL_REF: return Vector2i(-2, 0)
		found = Vector2i(row, owner._s_r_generation[row])
	return found


func _stage_timber_datums(proof: TimberClearance, token: int) -> StringName:
	"""Only completed group selectors receive datums, with full actual positive support and no new route."""
	for endpoint: int in _entry_frontier._header[8 + Frontier.ENDPOINT]:
		if not proof.spend(32): return REFUSE_MASK_BUDGET
		if _entry_frontier._field(Frontier.ENDPOINT, endpoint, 0) != Frontier.INSTALLED_CONTACT \
				or _entry_frontier._field(Frontier.ENDPOINT, endpoint, 1) != _timber_assembly: continue
		var prior: int = _timber_prior_landing(proof, endpoint)
		if prior < 0: return REFUSE_MASK_BUDGET
		if prior > 0: continue
		var code: StringName = _timber_landing_into(endpoint)
		if code != &"": return code
		for axis: int in 6: proof.box[axis] = _cube[axis]
		proof.box[4] = _cube[1]
		proof.box[1] = int(_cube[1]) - 1
		code = _timber_staged_support(proof, proof.box)
		if code == &"": code = _timber_create_datum(proof, token)
		if code != &"": return code
	return _timber_contact_air(proof, token, true)


func _timber_prior_landing(proof: TimberClearance, endpoint: int) -> int:
	"""Only earlier selectors in this same invocation can reuse identical assembly/LANDING metadata proof."""
	var ordinal: int = _entry_frontier._field(Frontier.ENDPOINT, endpoint, 2)
	for prior: int in endpoint:
		if not proof.spend(4): return -1
		if _entry_frontier._field(Frontier.ENDPOINT, prior, 0) == Frontier.INSTALLED_CONTACT \
				and _entry_frontier._field(Frontier.ENDPOINT, prior, 1) == _timber_assembly \
				and _entry_frontier._field(Frontier.ENDPOINT, prior, 2) == ordinal:
			return 1
	return 0


func _timber_staged_support(proof: TimberClearance, bounds: PackedInt32Array) -> StringName:
	"""Metadata cannot enlarge a platform: the complete declared landing must have actual installed solid under it."""
	proof.start(bounds)
	var owner: Owner = _entry_placements._space
	for row: int in owner._region_capacity:
		if not proof.spend(): return REFUSE_MASK_BUDGET
		if owner._s_r_present[row] != 1 or owner._s_r_role[row] != Space.SUPPORT \
				or owner._s_r_claim_kind[row] != Owner.CLAIM_NONE or not _timber_owned(row, true): continue
		if not proof.spend(12): return REFUSE_MASK_BUDGET
		_timber_region_box(row, true, proof.cover)
		if not proof.subtract_cover(): return REFUSE_MASK_BUDGET
	return &"" if proof.count == 0 else REFUSE_TIMBER_CONTACT


func _timber_create_datum(proof: TimberClearance, token: int) -> StringName:
	"""Datum creation happens only after physical group staging; its exact six metadata bounds grant no air."""
	_entry_checks = proof.remaining
	var section: Vector2i = _timber_datum_ref()
	proof.remaining = _entry_checks
	if section == Vector2i(-3, 0): return REFUSE_MASK_BUDGET
	if section == Vector2i(-2, 0): return REFUSE_TIMBER_CONTACT
	if section != NULL_REF: return &""
	if not proof.spend(_entry_placements._space._source_capacity + 32): return REFUSE_MASK_BUDGET
	_region.owner = _timber_room()
	_region.section = NULL_REF
	_region.level = _entry_contact.level
	_region.role = Space.FLOOR_DATUM
	_region.claim_kind = Owner.CLAIM_NONE
	_region.claim_ref = NULL_REF
	for axis: int in 6: _region.box[axis] = _cube[axis]
	var code: StringName = _entry_placements._space.stage_add(token, _region).error
	return _timber_scope_leaf(proof) if code == &"" else code


func _timber_profile(endpoint: int) -> int:
	"""A WORK selector uses its exact source station heading; other roles retain the explicit travel profile."""
	if _entry_contact.role != Locations.ROLE_WORK: return _entry_frontier._travel_profile[endpoint]
	var found: int = -1
	var rotation: int = _entry_placements._get32(_entry_placements._live, Placements.ROTATION, _timber_placement.x)
	for row: int in _entry_frontier._header[8 + Frontier.STATION]:
		if not _entry_spend(12): return -2
		if _entry_frontier._field(Frontier.STATION, row, 0) != endpoint: continue
		var profile: int = _entry_frontier._field(Frontier.STATION, row, 5) if rotation == 0 else \
			_entry_frontier._rotation_profile[(rotation - 1) * _entry_frontier._capacities[Frontier.STATION] + row]
		if found >= 0 and found != profile: return -1
		found = profile
	return found


func _timber_profile_envelope(endpoint: int) -> StringName:
	"""Select the exact immutable source; support and occupied air retain independent complete bounds."""
	var profile: int = _timber_profile(endpoint)
	var profiles: Profiles = _entry_placements._profiles
	if profile == -2: return REFUSE_MASK_BUDGET
	if profile < 0 or profile >= profiles._live.header[1] \
			or profiles._live.flags[profile] != Profiles.CERT_REQUIRED: return REFUSE_TIMBER_CONTACT
	var code: StringName = _timber_profile_bounds(profiles, profile)
	if code != &"" or _entry_contact.role != Locations.ROLE_WORK: return code
	# ADR1193: a WORK contact is also the arrival/departure point of its explicit travel profile, so its
	# declared footing and air cover that stance and body too. Real deck support and free air still decide.
	var travel: int = _entry_frontier._travel_profile[endpoint]
	if travel == profile: return &""
	if travel < 0 or travel >= profiles._live.header[1] \
			or profiles._live.flags[travel] != Profiles.CERT_REQUIRED: return REFUSE_TIMBER_CONTACT
	return _timber_union_profile(profiles, travel)


func _timber_union_profile(profiles: Profiles, profile: int) -> StringName:
	"""Enlarge, never replace, the already derived footing and air with one further authored profile."""
	var first: int = profiles._live.fields[Profiles.F_FIRST_BOX * profiles._profile_capacity + profile]
	var end: int = first + profiles._live.fields[Profiles.F_BOX_COUNT * profiles._profile_capacity + profile]
	var point: Vector3i = _entry_contact.point
	for box: int in range(first, end):
		if not _entry_spend(24): return REFUSE_MASK_BUDGET
		var role: int = profiles._live.boxes[6 * profiles._box_capacity + box]
		var code: StringName = &""
		if role == Profiles.STANCE_SUPPORT: code = _timber_extend_support(profiles, box, point, false)
		elif role in [Profiles.BODY_HELD_LOAD, Profiles.TURN_RECOVERY, Profiles.WORK_APPROACH]:
			code = _timber_extend_envelope(profiles, box, point)
		if code != &"": return code
	return &""


func _timber_profile_bounds(profiles: Profiles, profile: int) -> StringName:
	"""Only authored stance rows enlarge footing; held-tool overhang independently enlarges the air proof."""
	var point: Vector3i = _entry_contact.point
	for axis: int in 3:
		_entry_contact.envelope[axis] = point[axis]
		_entry_contact.envelope[axis + 3] = int(point[axis]) + 1
	var first: int = profiles._live.fields[Profiles.F_FIRST_BOX * profiles._profile_capacity + profile]
	var end: int = first + profiles._live.fields[Profiles.F_BOX_COUNT * profiles._profile_capacity + profile]
	var stance: bool = false
	for box: int in range(first, end):
		if not _entry_spend(24): return REFUSE_MASK_BUDGET
		var role: int = profiles._live.boxes[6 * profiles._box_capacity + box]
		if role == Profiles.STANCE_SUPPORT:
			var code: StringName = _timber_extend_support(profiles, box, point, not stance)
			if code != &"": return code
			stance = true
		if role in [Profiles.BODY_HELD_LOAD, Profiles.TURN_RECOVERY, Profiles.WORK_APPROACH]:
			var code: StringName = _timber_extend_envelope(profiles, box, point)
			if code != &"": return code
	return &"" if stance and Locations.support_covers_root(point, _entry_contact.support) else REFUSE_TIMBER_CONTACT


func _timber_extend_support(profiles: Profiles, box: int, point: Vector3i, first: bool) -> StringName:
	"""A single-plane contact retains every authored footing coordinate without borrowing body-only air."""
	if profiles._live.boxes[profiles._box_capacity + box] >= 0 \
			or profiles._live.boxes[4 * profiles._box_capacity + box] != 0: return REFUSE_TIMBER_CONTACT
	for axis: int in 3:
		var low: int = int(point[axis]) + profiles._live.boxes[axis * profiles._box_capacity + box]
		var high: int = int(point[axis]) + profiles._live.boxes[(axis + 3) * profiles._box_capacity + box]
		if not Space.int32(low) or not Space.int32(high): return REFUSE_TIMBER_CONTACT
		_entry_contact.support[axis] = low if first else mini(_entry_contact.support[axis], low)
		_entry_contact.support[axis + 3] = high if first else maxi(_entry_contact.support[axis + 3], high)
	return &""


func _timber_extend_envelope(profiles: Profiles, box: int, point: Vector3i) -> StringName:
	"""Below-root footprint remains in the real support box; clipping changes no selected source motion."""
	for axis: int in 3:
		var low: int = int(point[axis]) + profiles._live.boxes[axis * profiles._box_capacity + box]
		var high: int = int(point[axis]) + profiles._live.boxes[(axis + 3) * profiles._box_capacity + box]
		if not Space.int32(low) or not Space.int32(high): return REFUSE_TIMBER_CONTACT
		if axis == 1: low = maxi(low, point.y)
		_entry_contact.envelope[axis] = mini(_entry_contact.envelope[axis], low)
		_entry_contact.envelope[axis + 3] = maxi(_entry_contact.envelope[axis + 3], high)
	return &""


func _timber_contact_air(proof: TimberClearance, token: int, staging: bool) -> StringName:
	"""Endpoint air is observed from completed void or actual exterior, never from the Catalog envelope."""
	for endpoint: int in _entry_frontier._header[8 + Frontier.ENDPOINT]:
		if not proof.spend(32): return REFUSE_MASK_BUDGET
		if _entry_frontier._field(Frontier.ENDPOINT, endpoint, 0) != Frontier.INSTALLED_CONTACT \
				or _entry_frontier._field(Frontier.ENDPOINT, endpoint, 1) != _timber_assembly: continue
		var code: StringName = _timber_landing_into(endpoint)
		_entry_checks = proof.remaining
		if code == &"": code = _timber_profile_envelope(endpoint)
		proof.remaining = _entry_checks
		if code == &"": code = _timber_profile_foot(proof, endpoint)
		if code == &"": code = _timber_air_box(proof, token, staging)
		if code != &"": return code
	return &""


func _timber_air_box(proof: TimberClearance, token: int, staging: bool) -> StringName:
	"""Full occupied/recovery air retains all physical and foreign-claim blockers and only fills proven exterior."""
	if not staging:
		var code: StringName = _timber_terrain(proof, _entry_contact.envelope, Terrain.EXCLUSIONS, token)
		if code != &"": return code
	var owner: Owner = _entry_placements._space
	proof.start(_entry_contact.envelope)
	for row: int in owner._region_capacity:
		if not proof.spend(): return REFUSE_MASK_BUDGET
		if (owner._s_r_present[row] if staging else owner._r_present[row]) != 1: continue
		var role: int = owner._s_r_role[row] if staging else owner._r_role[row]
		if role == Space.FLOOR_DATUM or _timber_claim(row, staging) \
				or (not staging and _workpiece_live_row(row)): continue
		if not proof.spend(12): return REFUSE_MASK_BUDGET
		_timber_region_box(row, staging, proof.cover)
		if not Space.overlaps(_entry_contact.envelope, proof.cover): continue
		if role != Space.SUPPORTED_VOID or not _timber_void_row(row, staging): return REFUSE_TIMBER_CONTACT
		if not proof.subtract_cover(): return REFUSE_MASK_BUDGET
	for row: int in proof.count:
		for axis: int in 6: proof.box[axis] = proof.fragments[row * 6 + axis]
		var code: StringName = _stage_timber_exterior(proof, token) if staging \
			else _timber_terrain(proof, proof.box, Terrain.EXTERIOR, token)
		if code != &"": return code
	return &""


func _stage_timber_exterior(proof: TimberClearance, token: int) -> StringName:
	"""Only the independently preflighted and finally rechecked exterior residual becomes World-owned air."""
	if not proof.spend(_entry_placements._space._source_capacity + 16): return REFUSE_MASK_BUDGET
	_region.owner = _entry_placements._world
	_region.section = NULL_REF
	_region.level = 0
	_region.role = Space.SUPPORTED_VOID
	_region.claim_kind = Owner.CLAIM_NONE
	_region.claim_ref = NULL_REF
	for axis: int in 6: _region.box[axis] = proof.box[axis]
	var code: StringName = _entry_placements._space.stage_add(token, _region).error
	return _timber_scope_leaf(proof) if code == &"" else code


func _stage_timber_locations(placement: Vector2i, project: Vector2i, assembly: int, token: int, cold: int) -> StringName:
	"""Preserve all live payloads before adding exact completed contact selectors, under the same sealed candidate."""
	var code: StringName = _timber_call_scope(placement, project, assembly, cold)
	if code != &"" or token != _entry_placements._location_token: return REFUSE_ENTRY_COLD
	_entry_busy = true
	_reading = true
	code = _timber_refresh_locations(token)
	if code == &"" and _entry_placements._prepared_action == Placements.Contract.COMMIT: code = _timber_new_locations(token)
	_reading = false
	_entry_busy = false
	return code


func _timber_refresh_locations(token: int) -> StringName:
	"""Every old full endpoint remains identical and is freshly requalified; no retained storage or actor is displaced."""
	var locations: Locations = _entry_placements._locations
	for row: int in locations._capacity:
		if not _entry_spend(): return REFUSE_MASK_BUDGET
		if locations._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, locations._live.i32[row])
		var code: StringName = locations.stage_refresh(token, ref)
		if code != &"": return code
		code = _timber_scope_leaf()
		if code != &"": return code
	return &""


func _timber_new_locations(token: int) -> StringName:
	"""Only immutable installed selectors for the just-paid group receive complete physically qualified records."""
	for endpoint: int in _entry_frontier._header[8 + Frontier.ENDPOINT]:
		if not _entry_spend(32): return REFUSE_MASK_BUDGET
		if _entry_frontier._field(Frontier.ENDPOINT, endpoint, 0) != Frontier.INSTALLED_CONTACT \
				or _entry_frontier._field(Frontier.ENDPOINT, endpoint, 1) != _timber_assembly: continue
		var code: StringName = _timber_landing_into(endpoint)
		if code == &"": _entry_contact.section = _timber_datum_ref()
		if code == &"" and _entry_contact.section == Vector2i(-3, 0): return REFUSE_MASK_BUDGET
		if code != &"" or _entry_contact.section.x < 0: return REFUSE_TIMBER_CONTACT
		code = _timber_profile_envelope(endpoint)
		if code == &"": code = _entry_placements._locations.stage_add(token, _entry_contact).error
		if code == &"": code = _timber_scope_leaf()
		if code != &"": return code
	return &""


func _stage_timber_routes(placement: Vector2i, project: Vector2i, assembly: int, token: int, cold: int) -> StringName:
	"""Requalify old ground edges only; new stair motion requires the separate adopted source-phase contract."""
	var code: StringName = _timber_call_scope(placement, project, assembly, cold)
	if code != &"" or token != _entry_placements._route_token: return REFUSE_ENTRY_COLD
	_entry_busy = true
	_reading = true
	var routes: Routes = _entry_placements._routes
	for row: int in routes._edge_capacity:
		if not _entry_spend():
			code = REFUSE_MASK_BUDGET
			break
		if routes._live.present[row] != 1: continue
		code = routes.stage_refresh(token, Vector2i(row, routes._live.fields[row]))
		if code == &"": code = _timber_scope_leaf()
		if code != &"": break
	_reading = false
	_entry_busy = false
	return code


func _timber_profile_foot(proof: TimberClearance, endpoint: int) -> StringName:
	"""Only exact authored stance union can contain below-plane occupied/recovery residual; no generic clipping permission."""
	_entry_checks = proof.remaining
	var profile: int = _timber_profile(endpoint)
	proof.remaining = _entry_checks
	if profile == -2: return REFUSE_MASK_BUDGET
	if profile < 0: return REFUSE_TIMBER_CONTACT
	var profiles: Profiles = _entry_placements._profiles
	var first: int = profiles._live.fields[Profiles.F_FIRST_BOX * profiles._profile_capacity + profile]
	var end: int = first + profiles._live.fields[Profiles.F_BOX_COUNT * profiles._profile_capacity + profile]
	for box: int in range(first, end):
		if not proof.spend(16): return REFUSE_MASK_BUDGET
		var role: int = profiles._live.boxes[6 * profiles._box_capacity + box]
		if role not in [Profiles.BODY_HELD_LOAD, Profiles.TURN_RECOVERY, Profiles.WORK_APPROACH] \
				or profiles._live.boxes[profiles._box_capacity + box] >= 0: continue
		for axis: int in 6: proof.box[axis] = profiles._live.boxes[axis * profiles._box_capacity + box]
		proof.box[4] = mini(proof.box[4], 0)
		proof.start(proof.box)
		for stance: int in range(first, end):
			if not proof.spend(8): return REFUSE_MASK_BUDGET
			if profiles._live.boxes[6 * profiles._box_capacity + stance] != Profiles.STANCE_SUPPORT: continue
			for axis: int in 6: proof.cover[axis] = profiles._live.boxes[axis * profiles._box_capacity + stance]
			if not proof.subtract_cover(): return REFUSE_MASK_BUDGET
		if proof.count != 0: return REFUSE_TIMBER_CONTACT
	return &""


static func retirement_refusal_in(actual: RefCounted, original: RefCounted,
		stopped_constructor: bool = false) -> StringName:
	"""Inspect original owned references only; the kernel proves private stopped-prefix authority separately."""
	if actual == null or original == null or original.room_bindings != actual or actual._budget == null \
			or actual._budget != original.budget or actual._entry_checks < 0:
		return REFUSE_ENTRY_SOURCE
	if actual._reading or actual._room_token != 0 or actual._room_request != null or actual._room_pin != null \
			or actual._room_approach != null or actual._entry_busy or actual._entry_token != 0 \
			or actual._entry_space_token != 0 or actual._entry_request != null or actual._entry_pin != null \
			or actual._placement_request != null or actual._entry_candidate != null or actual._timber_token != 0:
		return REFUSE_ENTRY_COLD
	if not _retirement_weak_in(actual._provider, original.world_bindings) \
			or not _retirement_weak_in(actual._sites, original.sites) \
			or not _retirement_weak_in(actual._orders, original.rooms) \
			or not _retirement_weak_in(actual._levels, original.levels) \
			or not _retirement_weak_in(actual._room_routes, original.world_routes):
		return REFUSE_ENTRY_SOURCE
	return _retirement_entry_pins_in(actual, original, stopped_constructor)


static func _retirement_entry_pins_in(actual: RefCounted, original: RefCounted,
		stopped_constructor: bool) -> StringName:
	"""An unbound initial subtype or exact pre-authority prefix never becomes arbitrary incomplete permission."""
	if actual._entry_frontier == null:
		if actual._entry_placements != null or actual._entry_authority != null:
			return REFUSE_ENTRY_SOURCE
		return &"" if original.placements == null or (stopped_constructor and original.placements._authority == null) \
			else REFUSE_ENTRY_SOURCE
	if original.placements == null or actual._entry_placements != original.placements \
			or actual._entry_authority == null or not _retirement_weak_in(actual._entry_authority.host, actual) \
			or not _retirement_weak_in(original.placements._authority, actual._entry_authority):
		return REFUSE_ENTRY_SOURCE
	if actual._entry_frontier._catalog != original.placements._catalog \
			or actual._entry_frontier._assemblies != original.placements._assemblies \
			or actual._entry_frontier._recipes != original.placements._recipes \
			or actual._entry_frontier._profiles != original.profiles or actual._entry_frontier._busy:
		return REFUSE_ENTRY_SOURCE
	return &""


static func _retirement_weak_in(binding: WeakRef, expected: RefCounted) -> bool:
	"""An expired once-bound reference is never treated as an optional null original."""
	return binding == null if expected == null else binding != null and binding.get_ref() == expected


static func world_retirement_release_preflighted_in(actual: RefCounted, original: RefCounted,
		persistent_id: int, stopped_constructor: bool = false) -> StringName:
	"""After all kernel preflights, release this binding's own borrows and buffers without a World callback."""
	var code: StringName = retirement_refusal_in(actual, original, stopped_constructor)
	if code != &"": return code
	code = Buildings.whole_world_retirement_refusal_in(original.directory, original.world_ref, persistent_id, true)
	if code != &"": return code
	if original.world == null or original.world._published: return REFUSE_ENTRY_SOURCE
	actual._entry_checks = -1
	actual._entry_frontier = null
	actual._entry_placements = null
	actual._budget = null
	# Keep the inert weak AdmissionAuthority identity until Placement releases its original weak link.
	_release_retired_buffers_in(actual)
	return &""


static func _release_retired_buffers_in(actual: RefCounted) -> void:
	"""The old handle retains no variable entry or inherited Room proof storage."""
	actual._entry_anchor.envelope.clear()
	actual._entry_anchor.support.clear()
	actual._entry_contact.envelope.clear()
	actual._entry_contact.support.clear()
	actual._entry_row.clear()
	actual._entry_bearing.clear()
	actual._cube.clear()
	actual._clip.clear()
	actual._region.box.clear()
