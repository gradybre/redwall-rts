extends "res://scripts/core/underground_room_bindings.gd"
## Actual non-flat entrance admission. Confirmation reserves virgin cuts, never installed parts or usable air.
## The inherited installation/retirement gates remain closed until their concrete physical composition. Decision1111.

const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const EntryCuts := preload("res://scripts/core/underground_entry_cut_map.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const ConnectorCatalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const ENTRY_FIXED_BYTES: int = 4096
const ENTRY_EPISODE_FIELDS: int = 19
const ENTRY_BEARING_FIELDS: int = 9
const REFUSE_ENTRY_SOURCE: StringName = &"ENTRY_SOURCE_MISMATCH"
const REFUSE_ENTRY_CUTS: StringName = &"ENTRY_EXACT_CUT_SET_REQUIRED"
const REFUSE_ENTRY_BEARING: StringName = &"ENTRY_NATURAL_BEARING_REMOVED"
const REFUSE_ENTRY_ANCHOR: StringName = &"ENTRY_ACTUAL_SURFACE_ANCHOR"
const REFUSE_ENTRY_CONTACT: StringName = &"ENTRY_EXISTING_SURFACE_CONTACT"
const REFUSE_ENTRY_COLD: StringName = &"ENTRY_ORIGINAL_COLD_SCOPE"

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


func bind_entry(frontier: Frontier, placements: Placements) -> StringName:
	"""Share exact source/owner objects once; all variable confirmation buffers use the existing World lease."""
	if _entry_frontier != null or _entry_busy or _room_token != 0 or _actual_orders() == null \
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
	var aligned: StringName = _entry_aligned_claims(domain)
	if aligned != &"": return aligned
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


func _entry_aligned_claims(domain: Space.Domain) -> StringName:
	"""This authored connector reserves complete paid cubes; an undersized marker cannot hide its excavation."""
	if domain == null: return REFUSE_ENTRY_CUTS
	var datum: Vector3i = domain._datum
	for at: int in range(0, _entry_pin.claims.size(), 6):
		if not _entry_spend(6): return REFUSE_MASK_BUDGET
		for axis: int in 6:
			if (int(_entry_pin.claims[at + axis]) - datum[axis % 3]) % 1024 != 0:
				return REFUSE_ENTRY_CUTS
	return &""


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
	for at: int in range(0, _entry_pin.claims.size(), 6):
		for axis: int in 6: _clip[axis] = _entry_pin.claims[at + axis]
		var code: StringName = _entry_terrain_box(_clip, Terrain.DIG, space_token)
		if code == &"": code = _entry_retained_box(_clip, true)
		if code != &"": return code
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


func _entry_natural_bearing(bounds: PackedInt32Array, space_token: int) -> StringName:
	"""A later paid cut cannot remove the source's supposedly retained natural load-bearing matter."""
	for at: int in range(0, _entry_pin.claims.size(), 6):
		if not _entry_spend(): return REFUSE_MASK_BUDGET
		if bounds[0] < _entry_pin.claims[at + 3] and _entry_pin.claims[at] < bounds[3] \
				and bounds[1] < _entry_pin.claims[at + 4] and _entry_pin.claims[at + 1] < bounds[4] \
				and bounds[2] < _entry_pin.claims[at + 5] and _entry_pin.claims[at + 2] < bounds[5]:
			return REFUSE_ENTRY_BEARING
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
		if not _entry_spend(): return REFUSE_MASK_BUDGET
		if owner._r_present[row] == 0 or owner._r_role[row] == Space.FLOOR_DATUM: continue
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
