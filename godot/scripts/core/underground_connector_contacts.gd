extends "res://scripts/core/underground_connector_work.gd".Contacts
## Actual installation contacts. Authored selectors never create a cut, bearing, endpoint or worker.
## Fixed reusable observations; no per-Placement progress, reservation, geometry or permission bank.

const Paid := preload("res://scripts/core/underground_connector_work.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const PhaseContract := preload("res://scripts/core/excavation_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const FinalFacts := preload("res://scripts/core/underground_final_facts.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Workpieces := preload("res://scripts/core/underground_connector_workpieces.gd")
const AssemblySource := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const AssemblyPhysical := preload("res://data/underground/mole-worker/qualified-assembly-v1/physical_certificate.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CONTROL_BYTES: int = 4096
const FRAGMENT_CAPACITY: int = 32
const SOURCE_CHECKS: int = 2048
const REFUSE_BINDING: StringName = &"CONNECTOR_CONTACT_BINDING"
const REFUSE_SCOPE: StringName = &"CONNECTOR_CONTACT_SCOPE"
const REFUSE_SOURCE: StringName = &"CONNECTOR_CONTACT_SOURCE"
const REFUSE_GEOMETRY: StringName = &"CONNECTOR_CONTACT_GEOMETRY"
const REFUSE_CUT: StringName = &"CONNECTOR_CONTACT_CUT_DEPENDENCY"
const REFUSE_BEARING: StringName = &"CONNECTOR_CONTACT_BEARING"
const REFUSE_ENDPOINT: StringName = &"CONNECTOR_CONTACT_ENDPOINT"
const REFUSE_PROFILE: StringName = &"CONNECTOR_CONTACT_PROFILE"
const REFUSE_WORKER: StringName = &"CONNECTOR_CONTACT_WORKER"
const REFUSE_MATERIAL: StringName = &"CONNECTOR_CONTACT_MATERIAL"
const REFUSE_CAPACITY: StringName = &"CONNECTOR_CONTACT_OPERATION_CAPACITY"
const REFUSE_REENTRY: StringName = &"CONNECTOR_CONTACT_REENTRY"
const REFUSE_PHASE_PREPARED: StringName = &"CONNECTOR_PHASE_COMPANION_UNBOUND"
const PHASE_CONTACT_ONLY: int = -1

class Fragments extends RefCounted:
	## Exact six-slab subtraction, with two fixed banks and one shared operation counter.
	var first: PackedInt32Array = PackedInt32Array()
	var second: PackedInt32Array = PackedInt32Array()
	var core: PackedInt32Array = PackedInt32Array()
	var cut: PackedInt32Array = PackedInt32Array()
	var slab: PackedInt32Array = PackedInt32Array()
	var count: int = 0
	var next_count: int = 0
	var remaining: int = 0
	var failed: bool = false

	func allocate() -> void:
		"""Only initial admitted fixed controls allocate; a worker tick never resizes a bank."""
		first.resize(6 * FRAGMENT_CAPACITY)
		second.resize(6 * FRAGMENT_CAPACITY)
		core.resize(6)
		cut.resize(6)
		slab.resize(6)

	func spend(amount: int = 1) -> bool:
		"""Every cube, source row and fragment shares this finite call budget."""
		if failed or amount < 0 or amount > remaining:
			failed = true
			return false
		remaining -= amount
		return true

	func start(bounds: PackedInt32Array) -> void:
		"""Keep all requested volume, including the source's negative foot residual."""
		count = 1
		for axis: int in 6:
			first[axis] = bounds[axis]

	func subtract(cover: PackedInt32Array) -> bool:
		"""A bounded exact union cannot turn an unvisited interior hole into coverage."""
		next_count = 0
		for row: int in count:
			if not spend():
				return false
			for axis: int in 6:
				core[axis] = first[row * 6 + axis]
			if not _fragment(cover):
				return false
		var previous: PackedInt32Array = first
		first = second
		second = previous
		count = next_count
		return true

	func _fragment(cover: PackedInt32Array) -> bool:
		"""Disjoint slabs preserve half-open boundaries and never overlap one another."""
		if not Space.overlaps(core, cover):
			return _append(core)
		for axis: int in 3:
			cut[axis] = maxi(core[axis], cover[axis])
			cut[axis + 3] = mini(core[axis + 3], cover[axis + 3])
		for axis: int in 3:
			if not _outside(axis, false) or not _outside(axis, true):
				return false
		return true

	func _outside(axis: int, after: bool) -> bool:
		"""Shrink the retained core after each side, emitting only positive outside slabs."""
		var edge: int = axis + 3 if after else axis
		if (core[edge] <= cut[edge] if after else core[edge] >= cut[edge]):
			return true
		for field: int in 6:
			slab[field] = core[field]
		slab[axis if after else axis + 3] = cut[edge]
		if not _append(slab):
			return false
		core[edge] = cut[edge]
		return true

	func _append(bounds: PackedInt32Array) -> bool:
		"""Exhaustion refuses the operation; this finite scratch limit is not a room-size policy."""
		if next_count >= FRAGMENT_CAPACITY:
			failed = true
			return false
		for axis: int in 6:
			second[next_count * 6 + axis] = bounds[axis]
		next_count += 1
		return true

var _placements: Placements = null
var _router: WeakRef = null
var _frontier: Frontier = null
var _sites: Sites = null
var _terrain: Terrain = null
var _configured: bool = false
var _busy: bool = false
var _poisoned: bool = false
var _valid: bool = false
var _placement: Vector2i = NULL_REF
var _project: Vector2i = NULL_REF
var _ordinal: int = -1
var _action: int = -1
var _geometry_revision: int = 0
var _frontier_revision: int = 0
var _station_location: Vector2i = NULL_REF
var _material_location: Vector2i = NULL_REF
var _retreat_location: Vector2i = NULL_REF
var _station_payload: int = 0
var _material_payload: int = 0
var _retreat_payload: int = 0
var _primary_job: Vector2i = NULL_REF
var _material_container: Vector2i = NULL_REF
var _space_receipt: int = 0
var _location_receipt: int = 0
var _route_receipt: int = 0
var _order: Placements.OrderRecord = Placements.OrderRecord.new()
var _frame: PackedInt32Array = PackedInt32Array()
var _install: PackedInt32Array = PackedInt32Array()
var _station: PackedInt32Array = PackedInt32Array()
var _endpoint: PackedInt32Array = PackedInt32Array()
var _cut: PackedInt32Array = PackedInt32Array()
var _bearing: PackedInt32Array = PackedInt32Array()
var _part: PackedInt32Array = PackedInt32Array()
var _region: PackedInt32Array = PackedInt32Array()
var _pair: PackedInt32Array = PackedInt32Array()
var _remaining: PackedInt32Array = PackedInt32Array()
var _bounds: PackedInt32Array = PackedInt32Array()
var _support: PackedInt32Array = PackedInt32Array()
var _target: PackedInt32Array = PackedInt32Array()
var _scratch: PackedInt32Array = PackedInt32Array()
var _location: Locations.Record = Locations.Record.new()
var _other: Locations.Record = Locations.Record.new()
var _descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
var _selection: Profiles.Selection = Profiles.Selection.new()
var _box: Profiles.Box = Profiles.Box.new()
var _stance: Profiles.Box = Profiles.Box.new()
var _number: IntMath.IntResult = IntMath.IntResult.new()
var _phase_mode: bool = false
var _phase_site: Vector2i = NULL_REF
var _phase_operation: int = -1
var _phase_episode: int = -1
var _phase_cold_token: int = 0
var _phase_space_token: int = 0
var _phase_companion_token: int = 0
var _phase_output_location: Vector2i = NULL_REF
var _phase_output_payload: int = 0
var _phase_output_container: Vector2i = NULL_REF
var _episode: PackedInt32Array = PackedInt32Array()
var _profile_revision: int = 0
var _fragments: Fragments = Fragments.new()


func configure(placements: Placements, router: Router, frontier: Frontier, controls: int) -> StringName:
	"""Bind actual immutable and live owners once, admitting the whole fixed packet before allocation."""
	if _configured or placements == null or router == null or frontier == null or controls != CONTROL_BYTES:
		return REFUSE_BINDING
	_placements = placements
	_router = weakref(router)
	_frontier = frontier
	_sites = router._sites
	_terrain = placements._world_routes._terrain if placements._world_routes != null else null
	var code: StringName = _binding_leaf()
	if code != &"":
		return code
	_allocate()
	_configured = true
	return &""


func _allocate() -> void:
	"""One bounded reusable packet replaces per-call descriptors, arrays and entity objects."""
	_episode.resize(19)
	_frame.resize(9)
	_install.resize(9)
	_station.resize(9)
	_endpoint.resize(7)
	_cut.resize(7)
	_bearing.resize(9)
	_part.resize(9)
	_region.resize(8)
	_pair.resize(2)
	_remaining.resize(1)
	_bounds.resize(6)
	_support.resize(6)
	_target.resize(6)
	_scratch.resize(6)
	_location.envelope.resize(6)
	_location.support.resize(6)
	_other.envelope.resize(6)
	_other.support.resize(6)
	_fragments.allocate()


func exact_binding(placements: Placements, router: Router, world: Vector2i) -> bool:
	"""Metadata borrowing cannot grant contact permission to a coincident foreign World or composer."""
	return _configured and _placements != null and _router != null \
		and placements == _placements and router == _actual_router() \
		and world == _placements._world and _binding_leaf() == &""


static func retirement_refusal_in(actual: RefCounted, original: RefCounted) -> StringName:
	"""The complete retirement kernel supplies its original packet; only this owner's retained pins are read here."""
	if actual == null or original == null or original.contacts != actual or not actual._configured \
			or actual._placements == null or actual._router == null or actual._frontier == null \
			or actual._sites == null or actual._terrain == null or actual._fragments == null \
			or original.room_bindings == null or original.world_bindings == null \
			or original.world_routes == null or original.world == null or original.budget == null:
		return REFUSE_BINDING
	if actual._busy or actual._valid or actual._phase_space_token != 0 or actual._phase_companion_token != 0 \
			or original.budget._token != 0 or original.budget._used != 0:
		return REFUSE_SCOPE
	if actual._placements != original.placements or actual._router.get_ref() != original.router \
			or actual._sites != original.sites or actual._terrain != original.terrain \
			or actual._frontier != original.room_bindings._entry_frontier:
		return REFUSE_BINDING
	return _retirement_original_stores_in(actual, original)


static func _retirement_original_stores_in(actual: RefCounted, original: RefCounted) -> StringName:
	"""Placement and Router remain bound until after Contacts; Workpieces and Delivery may already be released."""
	if original.placements._ids != original.directory or original.placements._world != original.world_ref \
			or original.placements._construction != original.construction \
			or original.placements._world_routes != original.world_routes \
			or original.placements._budget != original.budget or original.router == null \
			or original.router._world != original.world_ref or original.router._construction != original.construction \
			or original.router._sites != actual._sites or original.world._directory != original.directory \
			or actual._terrain._world != original.world or actual._terrain._world_ref != original.world_ref \
			or actual._terrain._budget != original.budget or original.world_routes._terrain != actual._terrain:
		return REFUSE_BINDING
	return &""


static func world_retirement_release_preflighted_in(actual: RefCounted, original: RefCounted,
		persistent_id: int) -> StringName:
	"""Only the exact cleared, unpublished World permits dropping these pins; normal configure remains one-way."""
	var code: StringName = retirement_refusal_in(actual, original)
	if code != &"": return code
	code = Routes.Buildings.whole_world_retirement_refusal_in(original.directory, original.world_ref, persistent_id, true)
	if code != &"": return code
	if original.world._published: return REFUSE_BINDING
	_release_retired_controls_in(actual)
	return &""


static func _release_retired_controls_in(actual: RefCounted) -> void:
	"""Release this packet only, with no foreign callback or recursive owner check after the first write."""
	actual._poisoned = true
	actual._placements = null
	actual._router = null
	actual._frontier = null
	actual._sites = null
	actual._terrain = null
	actual._order = null
	actual._location = null
	actual._other = null
	actual._descriptor = null
	actual._selection = null
	actual._box = null
	actual._stance = null
	actual._number = null
	actual._fragments = null
	_release_retired_arrays_in(actual)


static func _release_retired_arrays_in(actual: RefCounted) -> void:
	"""No array literal or replacement owner is allocated while releasing the fixed retained scratch."""
	actual._frame.clear()
	actual._install.clear()
	actual._station.clear()
	actual._endpoint.clear()
	actual._cut.clear()
	actual._bearing.clear()
	actual._part.clear()
	actual._region.clear()
	actual._pair.clear()
	actual._remaining.clear()
	actual._bounds.clear()
	actual._support.clear()
	actual._target.clear()
	actual._scratch.clear()
	actual._episode.clear()


func _actual_router() -> Router:
	"""Borrow only the original weak Router; callbacks may not silently replace it."""
	return _router.get_ref() as Router if _router != null else null


func _binding_leaf() -> StringName:
	"""Direct source/store identities close public observer rewiring without another observer loop."""
	var router: Router = _actual_router()
	if _placements == null or router == null or _frontier == null or _sites == null or _terrain == null \
			or not _placements._owners_current() or _placements._source_refusal() != &"" \
			or router._ready_error != &"" or router._world != _placements._world \
			or router._construction != _placements._construction or router._inventory != _placements._inventory \
			or router._jobs != _placements._jobs or router._work != _placements._work or router._sites != _sites \
			or _sites._construction != _placements._construction or _sites._jobs != _placements._jobs \
			or _sites._inventory != _placements._inventory or _sites._funding != router._funding \
			or _sites._pool != _placements._reservations or _sites._work != _placements._work or _sites._domain == null \
			or _sites._domain.world_ref != _placements._world \
			or _terrain != _placements._world_routes._terrain or _terrain._space == null \
			or _terrain._space.get_ref() != _placements._space or _terrain._budget != _placements._budget:
		return REFUSE_BINDING
	if _frontier._catalog != _placements._catalog or _frontier._assemblies != _placements._assemblies \
			or _frontier._recipes != _placements._recipes or _frontier._profiles != _placements._profiles:
		return REFUSE_BINDING
	return Frontier.source_leaf_refusal(_frontier) if _site_domain_matches() and _dynamic_bindings_leaf() else REFUSE_BINDING


func _dynamic_bindings_leaf() -> bool:
	"""Equipment and cargo readers must share the exact actual owners even after a successful late observer."""
	var gear: Gear = _placements._gear as Gear
	var carry: RefCounted = _placements._carry
	var reservations: RefCounted = _placements._reservations
	return gear != null and carry != null and reservations != null \
		and gear._inventory == _placements._inventory and gear._directory_binding == _placements._ids \
		and gear._residents == _placements._residents and _placements._work._gear == gear \
		and carry._inventory == _placements._inventory and carry._reservations == reservations \
		and carry._residents == _placements._residents and carry._piles == _placements._piles \
		and reservations._bound_inventory != null and reservations._bound_inventory.get_ref() == _placements._inventory


func _site_domain_matches() -> bool:
	"""The paid-key namespace must be the exact geometric quantum namespace, not just the same World."""
	var domain: Space.Domain = _placements._space._domain
	return _sites._ready_error == &"" and _sites._domain != null \
		and _sites._domain.world_ref == domain._world and _sites._domain.datum_u == domain._datum \
		and _sites._domain.minimum_quantum == domain._min_quantum and _sites._domain.size_quanta == domain._size_quanta


func _enter() -> bool:
	"""Nested callbacks poison this attempt without replacing the outer packet or lease."""
	if _busy:
		_poisoned = true
		return false
	_busy = true
	_poisoned = false
	return true


func _leave(code: StringName) -> StringName:
	"""All returned observations are synchronous and own no outstanding cold lease."""
	_busy = false
	if _poisoned:
		_valid = false
		return REFUSE_REENTRY
	return code


func _pin_scope(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
	"""Pin the actual next prefix and source tuple before any endpoint or profile observation."""
	_valid = false
	_phase_mode = false
	_phase_companion_token = 0
	if placement != _placement or project != _project:
		_primary_job = NULL_REF
		_material_container = NULL_REF
	var code: StringName = _binding_leaf()
	if not _configured or code != &"":
		return code if code != &"" else REFUSE_BINDING
	code = _placements.placement_into(placement, _order)
	if code != &"" or _order.installed_count != assembly or assembly < 0 or assembly >= _order.assembly_count \
			or _order.project != project:
		return REFUSE_SCOPE
	_placement = placement
	_project = project
	_ordinal = assembly
	_action = action
	_geometry_revision = _placements._space._header[17]
	_frontier_revision = _frontier._header[0]
	_fragments.remaining = _placements._space._domain._checks - SOURCE_CHECKS
	_fragments.failed = false
	code = _observe_rows()
	if code == &"" and project != NULL_REF and (action != Contract.CANCEL or _workpiece_owner() != null):
		code = _pin_material()
	return code if code != &"" else _copy_descriptor()


func _observe_rows() -> StringName:
	"""Recheck caller packet shapes after each observer before indexing their mutable output."""
	var code: StringName = _order_leaf()
	if code == &"":
		code = _placements.placement_frame_into(_placement, _frame)
	if code != &"" or _frame.size() != 9 or _poisoned:
		return code if code != &"" else REFUSE_SOURCE
	code = _frontier.installation_into(_ordinal, _install)
	if code != &"" or _install.size() != 9 or _frame.size() != 9 or _poisoned:
		return code if code != &"" else REFUSE_SOURCE
	code = _frontier.station_into(_install[1], _station, _number, _frame[3])
	_profile_revision = _number.value
	return code if code != &"" else _scope_leaf()


func _order_leaf() -> StringName:
	"""Every copied Order fact must still be the actual live row/header, including the source census."""
	var bank: Placements.Bank = _placements._live
	var attached: Vector2i = NULL_REF if _phase_mode else _project
	if not _placements._is_live(bank, _placement) or _order.placement != _placement \
			or _order.world != _placements._world or _order.project != attached or _order.installed_count != _ordinal \
			or _placements._get64(bank, Placements.PAYLOAD_REVISION, _placement.x) != _order.payload_revision \
			or _placements._get32(bank, Placements.INSTALLED, _placement.x) != _ordinal \
			or _placements._pair(bank, Placements.PROJECT_SLOT, _placement.x) != attached \
			or _placements._pair(bank, Placements.ROOM_SLOT, _placement.x) != _order.corridor \
			or _placements._get32(bank, Placements.CATALOG_ROW, _placement.x) != _order.catalog_row:
		return REFUSE_SCOPE
	return &"" if _order.catalog_revision == bank.header[Placements.H_CATALOG_REV] \
		and _order.variant_revision == bank.header[Placements.H_VARIANT_REV] \
		and _order.grouping_revision == bank.header[Placements.H_GROUP_REV] \
		and _order.recipe_revision == bank.header[Placements.H_RECIPE_REV] \
		and _order.assembly_count == bank.header[Placements.H_GROUP_COUNT] else REFUSE_SCOPE


func _pin_material() -> StringName:
	"""The actual bound container survives synchronous contact-cache cleanup; no second delivery ledger is retained."""
	var row: int = _project_row()
	if row < 0:
		return REFUSE_SCOPE
	var construction: Construction = _placements._construction
	_material_container = Vector2i(construction._material_container_slot[row], construction._material_container_generation[row])
	return &""


func _scope_leaf() -> StringName:
	"""Original full identities and private copied values remain exact after every public observer."""
	if not _fragments.spend(SOURCE_CHECKS):
		return REFUSE_CAPACITY
	var code: StringName = _binding_leaf()
	if code != &"" or _poisoned or _frontier._header[0] != _frontier_revision \
			or _placements._space._header[17] != _geometry_revision \
			or not _packet_shapes_match():
		return code if code != &"" else REFUSE_SCOPE
	var bank: Placements.Bank = _placements._live
	if _order_leaf() != &"" or _placements._room_refusal(bank, _placement.x) != &"":
		return REFUSE_SCOPE
	for field: int in 5:
		if _frame[field] != _placements._get32(bank, Placements.X + field, _placement.x):
			return REFUSE_SCOPE
	for field: int in 4:
		if _frame[5 + field] != _placements._get32(bank, Placements.SECTION_SLOT + field, _placement.x):
			return REFUSE_SCOPE
	code = _source_rows_leaf()
	return _site_scope_leaf() if code == &"" and _phase_mode else code


func _packet_shapes_match() -> bool:
	"""Observers cannot resize a borrowed output and make the next pure leaf index a different packet."""
	return _frame.size() == 9 and _install.size() == 9 and _station.size() == 9 and _episode.size() == 19 \
		and _endpoint.size() == 7 and _cut.size() == 7 and _bearing.size() == 9 and _part.size() == 9 \
		and _region.size() == 8 and _pair.size() == 2 and _remaining.size() == 1 \
		and _bounds.size() == 6 and _support.size() == 6 and _target.size() == 6 and _scratch.size() == 6 \
		and _location.envelope.size() == 6 and _location.support.size() == 6 \
		and _other.envelope.size() == 6 and _other.support.size() == 6 \
		and _fragments.first.size() == 6 * FRAGMENT_CAPACITY and _fragments.second.size() == 6 * FRAGMENT_CAPACITY \
		and _fragments.core.size() == 6 and _fragments.cut.size() == 6 and _fragments.slab.size() == 6


func _source_rows_leaf() -> StringName:
	"""A source subclass cannot substitute a different station or installation after the digest proof."""
	if _phase_mode:
		return _episode_source_leaf()
	if _install.size() != 9 or _station.size() != 9 or _frame.size() != 9 \
			or not _frontier._valid_row(Frontier.INSTALL, _ordinal) or _install[0] != _ordinal \
			or not _frontier._valid_row(Frontier.STATION, _install[1]):
		return REFUSE_SOURCE
	for field: int in 9:
		if _install[field] != _frontier._field(Frontier.INSTALL, _ordinal, field) \
				or (field != 5 and _station[field] != _frontier._field(Frontier.STATION, _install[1], field)):
			return REFUSE_SOURCE
	if _frame[3] < 0 or _frame[3] > 3 or _station[5] != _frontier._station_profile(_install[1], _frame[3]) \
			or _profile_revision != _frontier._profile_revision[_frame[3] * _frontier._capacities[Frontier.STATION] + _install[1]]:
		return REFUSE_SOURCE
	if _placements._live.header[Placements.H_FRONTIER_REV] != _frontier_revision:
		return REFUSE_SOURCE
	for index: int in 32:
		if _placements._live.digests[96 + index] != _frontier._digests[index]:
			return REFUSE_SOURCE
	return &""


func _world_box(source: PackedInt32Array, first: int, out: PackedInt32Array) -> StringName:
	"""Exact quarter turns use int64 intermediates; no shape snaps, grows or wraps at a signed boundary."""
	if out.size() != 6 or first < 0 or source.size() < first + 6 or _frame[3] < 0 or _frame[3] > 3:
		return REFUSE_GEOMETRY
	for axis: int in 3:
		var a: int = _coordinate(source[first], source[first + 1], source[first + 2], axis)
		var b: int = _coordinate(source[first + 3], source[first + 4], source[first + 5], axis)
		if not Space.int32(a) or not Space.int32(b) or a == b:
			return REFUSE_GEOMETRY
		out[axis] = mini(a, b)
		out[axis + 3] = maxi(a, b)
	return &"" if Space.contains_box(_placements._space._domain._bounds, out) else REFUSE_GEOMETRY


func _coordinate(x: int, y: int, z: int, axis: int) -> int:
	"""The finite authored frame rotates X/Z only; relative rise never aliases a flat tile."""
	if axis == 1:
		return y + _frame[1]
	if axis == 0:
		return _frame[0] + (x if _frame[3] == 0 else -z if _frame[3] == 1 else -x if _frame[3] == 2 else z)
	return _frame[2] + (z if _frame[3] == 0 else x if _frame[3] == 1 else -z if _frame[3] == 2 else -x)


func _cut_dependencies() -> StringName:
	"""Every exact whole cube names its actual permanent same-Room Site and required stable phase."""
	for index: int in range(_install[3], _install[3] + _install[4]):
		if not _fragments.spend():
			return REFUSE_CAPACITY
		var code: StringName = _read_source_row(Frontier.CUT, index, _cut)
		if code == &"":
			code = _world_box(_cut, 0, _bounds)
		if code == &"":
			code = _cube_range()
		if code != &"":
			return code
	return _scope_leaf()


func _cube_range() -> StringName:
	"""Huge authored extents spend before each lookup; key history is never inferred from physical air."""
	var datum: Vector3i = _placements._space._domain._datum
	for axis: int in 3:
		if (int(_bounds[axis]) - datum[axis]) % Space.QUANTUM_U != 0 \
				or (int(_bounds[axis + 3]) - datum[axis]) % Space.QUANTUM_U != 0:
			return REFUSE_CUT
	var y: int = _bounds[1]
	while y < _bounds[4]:
		var z: int = _bounds[2]
		while z < _bounds[5]:
			var x: int = _bounds[0]
			while x < _bounds[3]:
				if not _fragments.spend(20):
					return REFUSE_CAPACITY
				var row: int = _site_row(Vector3i(x, y, z))
				if row < 0 or _sites._room_slot[row] != _order.corridor.x \
						or _sites._room_generation[row] != _order.corridor.y or _sites._phase[row] != _cut[6]:
					return REFUSE_CUT
				x += Space.QUANTUM_U
			z += Space.QUANTUM_U
		y += Space.QUANTUM_U
	return &""


func _site_row(origin: Vector3i) -> int:
	"""The actual sorted permanent key ledger is read without invoking spatial Room observation hooks."""
	var key: int = _sites._key_at(origin)
	if key < 0:
		return -1
	var at: int = _sites._key_lower_bound(key)
	if at >= _sites._count or _sites._ordered_key[at] != key:
		return -1
	var row: int = _sites._ordered_row[at]
	return row if row >= 0 and row < _sites._count and _sites._present[row] == 1 else -1


func _read_endpoint(selector: int, location: Vector2i, out: Locations.Record) -> StringName:
	"""A full live handle must match every authored selector field and the actual installed datum."""
	var code: StringName = _read_source_row(Frontier.ENDPOINT, selector, _endpoint)
	if code != &"" or not _placements._locations._live_ref(_placements._locations._live, location):
		return REFUSE_ENDPOINT
	_placements._locations._read_row(_placements._locations._live, location.x, out)
	if out.world != _placements._world or out.geometry_revision != _geometry_revision \
			or out.payload_revision <= 0 or out.role != _endpoint[3]:
		return REFUSE_ENDPOINT
	if _endpoint[0] == Frontier.SURFACE_ANCHOR and location != Vector2i(_frame[7], _frame[8]):
		return REFUSE_ENDPOINT
	for axis: int in 3:
		var point: int = _coordinate(_endpoint[4], _endpoint[5], _endpoint[6], axis)
		if not Space.int32(point) or out.point[axis] != point:
			return REFUSE_ENDPOINT
	return _endpoint_section(out)


func _endpoint_section(record: Locations.Record) -> StringName:
	"""Null Room identifies the real World's surface, while an installed datum belongs to this Corridor."""
	var owner: Owner = _placements._space
	var section: Vector2i = record.section
	if not owner._region_live(section, false) or owner._r_role[section.x] != Space.FLOOR_DATUM \
			or owner._r_claim_kind[section.x] != Owner.CLAIM_NONE or owner._r_level[section.x] != record.level \
			or owner._r_lo_y[section.x] != record.point.y:
		return REFUSE_ENDPOINT
	if _endpoint[0] == Frontier.SURFACE_ANCHOR or _endpoint[0] == Frontier.SURFACE_CONTACT:
		var anchor: Vector2i = Vector2i(_frame[7], _frame[8])
		var locations: Locations = _placements._locations
		if not locations._live_ref(locations._live, anchor) or record.room != NULL_REF or record.level != 0 \
				or locations._ref_at(locations._live, Locations.SECTION_SLOT, anchor.x) != section \
				or owner._r_owner_slot[section.x] != _placements._world.x \
				or owner._r_owner_generation[section.x] != _placements._world.y:
			return REFUSE_ENDPOINT
		return &""
	if _endpoint[0] != Frontier.INSTALLED_CONTACT or _endpoint[1] < 0 or _endpoint[1] >= _ordinal \
			or record.room != _order.corridor or owner._r_owner_slot[section.x] != _order.corridor.x \
			or owner._r_owner_generation[section.x] != _order.corridor.y:
		return REFUSE_ENDPOINT
	return _installed_datum(record)


func _installed_datum(record: Locations.Record) -> StringName:
	"""An authored datum ordinal must match actual full source geometry, never a guessed floor or prefix alone."""
	var code: StringName = _read_catalog_region(_endpoint[2])
	if code != &"" or _region[6] != Space.LANDING or record.level != _frame[4] + _region[7]:
		return REFUSE_ENDPOINT
	code = _world_box(_region, 0, _scratch)
	if code != &"":
		return code
	var owner: Owner = _placements._space
	var row: int = record.section.x
	return &"" if owner._r_lo_x[row] == _scratch[0] and owner._r_lo_y[row] == _scratch[1] \
		and owner._r_lo_z[row] == _scratch[2] and owner._r_hi_x[row] == _scratch[3] \
		and owner._r_hi_z[row] == _scratch[5] else REFUSE_ENDPOINT


func _resolve_endpoint(selector: int) -> Vector2i:
	"""The finite pure selector reuses caller scratch; no coordinate creates a handle or allocates a survey."""
	if _read_source_row(Frontier.ENDPOINT, selector, _endpoint) != &"":
		return NULL_REF
	var locations: Locations = _placements._locations
	var anchor: Vector2i = Vector2i(_frame[7], _frame[8])
	if _endpoint[0] == Frontier.SURFACE_ANCHOR:
		return anchor if _read_endpoint(selector, anchor, _other) == &"" else NULL_REF
	var code: StringName = _resolve_section()
	if code != &"":
		return NULL_REF
	var x: int = _coordinate(_endpoint[4], _endpoint[5], _endpoint[6], 0)
	var y: int = _coordinate(_endpoint[4], _endpoint[5], _endpoint[6], 1)
	var z: int = _coordinate(_endpoint[4], _endpoint[5], _endpoint[6], 2)
	if not Space.int32(x) or not Space.int32(y) or not Space.int32(z):
		return NULL_REF
	var checks: int = 256 + 16 * locations._capacity + 4 * _placements._space._source_capacity
	if not _fragments.spend(checks):
		return NULL_REF
	code = locations.resolve_existing_live_into(_other.room, _other.section, _other.level, _endpoint[3],
		Vector3i(x, y, z), _geometry_revision, checks, _pair)
	var result: Vector2i = Vector2i(_pair[0], _pair[1]) if code == &"" else NULL_REF
	return result if _scope_leaf() == &"" and _read_endpoint(selector, result, _other) == &"" else NULL_REF


func _resolve_section() -> StringName:
	"""Find the exact authored installed datum, or borrow the full real surface anchor section."""
	var locations: Locations = _placements._locations
	var anchor: Vector2i = Vector2i(_frame[7], _frame[8])
	if _endpoint[0] == Frontier.SURFACE_CONTACT and locations._live_ref(locations._live, anchor):
		_other.room = NULL_REF
		_other.section = locations._ref_at(locations._live, Locations.SECTION_SLOT, anchor.x)
		_other.level = 0
		return &""
	if _endpoint[0] != Frontier.INSTALLED_CONTACT or _endpoint[1] < 0 or _endpoint[1] >= _ordinal:
		return REFUSE_ENDPOINT
	var code: StringName = _read_catalog_region(_endpoint[2])
	if code != &"" or _region[6] != Space.LANDING:
		return REFUSE_ENDPOINT
	code = _world_box(_region, 0, _scratch)
	if code != &"":
		return code
	_other.room = _order.corridor
	_other.level = _frame[4] + _region[7]
	_other.section = _unique_datum()
	return &"" if _other.section != NULL_REF else REFUSE_ENDPOINT


func _unique_datum() -> Vector2i:
	"""A second actual identical datum is ambiguous; no first-match or synthetic full reference is permitted."""
	var found: Vector2i = NULL_REF
	var owner: Owner = _placements._space
	if not _fragments.spend(16 * owner._region_capacity):
		return NULL_REF
	for row: int in owner._region_capacity:
		if owner._r_present[row] != 1 or owner._r_role[row] != Space.FLOOR_DATUM \
				or owner._r_claim_kind[row] != Owner.CLAIM_NONE or owner._r_level[row] != _other.level \
				or owner._r_owner_slot[row] != _order.corridor.x or owner._r_owner_generation[row] != _order.corridor.y:
			continue
		if owner._r_lo_x[row] != _scratch[0] or owner._r_lo_y[row] != _scratch[1] \
				or owner._r_lo_z[row] != _scratch[2] or owner._r_hi_x[row] != _scratch[3] \
				or owner._r_hi_z[row] != _scratch[5]:
			continue
		if found != NULL_REF:
			return NULL_REF
		found = Vector2i(row, owner._r_generation[row])
	return found


func _bearing_dependencies() -> StringName:
	"""Every named bearing must already exist; the pending installation supplies none of its own support."""
	for row: int in range(_install[5], _install[5] + _install[6]):
		var code: StringName = _bearing_refusal(row, _bounds)
		if code != &"":
			return code
	if _phase_mode:
		return _phase_target_into(_target)
	return _workpiece_target_into() if _workpiece_owner() != null else _bearing_refusal(_install[2], _target)


func _workpiece_owner() -> Workpieces:
	"""Borrow the one reciprocally bound actual owner; phase excavation never becomes a connector workpiece."""
	return _placements._workpieces.get_ref() as Workpieces if not _phase_mode \
		and _placements._workpieces != null else null


func _workpiece_target_into() -> StringName:
	"""Only the exact immutable part or its actual prepared/live Project obstacle can supply the INSTALL target."""
	var actual: Workpieces = _workpiece_owner()
	var code: StringName = Workpieces._activation_leaf(actual)
	if code == &"":
		code = Workpieces.candidate_bounds_into(actual, _placement, _ordinal, _target)
	if code != &"" or _project == NULL_REF:
		return code
	code = Workpieces.source_leaf_refusal(actual, _placement, _project)
	if code != &"": return code
	if _placements._space._stage_token != 0:
		return _workpiece_context_leaf()
	var row: int = _project_row()
	if row < 0: return REFUSE_SCOPE
	if _placements._construction._work_begun[row] == 0:
		return &"" if _action == -1 else REFUSE_SCOPE
	if not Workpieces._row_matches(actual, _placement, _project) or not Workpieces._funded(actual, _project, row):
		return Workpieces.REFUSE_REGION
	return Workpieces._region_leaf(actual, _placement, _project,
		Workpieces._row_region(actual._live, _placement.x, actual._capacity))


func _workpiece_context_leaf() -> StringName:
	"""One actual retained sealed context proves original source, Project, action, bounds and lease together."""
	var actual: Workpieces = _workpiece_owner()
	if actual == null or actual._stage_action != _action or actual._context == null:
		return REFUSE_SCOPE
	var code: StringName = Workpieces.prepared_leaf_refusal(actual, _placement, _project, _action, actual._cold_token)
	if code != &"": return code
	return _placements.prepared_installation_leaf_refusal(_placement, _project, _ordinal, actual._cold_token) \
		if _action == Contract.COMMIT else _placements.prepared_workpiece_leaf_refusal(actual._context)


func _bearing_refusal(row: int, out: PackedInt32Array) -> StringName:
	"""Source kind selects a real original-earth or paid prior-part proof, never a generic success callback."""
	if not _fragments.spend():
		return REFUSE_CAPACITY
	var code: StringName = _read_source_row(Frontier.BEARING, row, _bearing)
	if code == &"":
		code = _world_box(_bearing, 3, out)
	if code != &"":
		return code
	if _bearing[0] == Frontier.NATURAL:
		code = _terrain_refusal(out, Terrain.DIG)
		if code == &"":
			code = _retained_earth_refusal(out)
	else:
		code = _installed_part_refusal(out)
		if code == &"":
			code = _terrain_refusal(out, Terrain.EXCLUSIONS)
	return code if code != &"" else _scope_leaf()


func _retained_earth_refusal(bounds: PackedInt32Array) -> StringName:
	"""Original terrain cannot refill a paid cavity or stand in for installed timber after excavation."""
	var owner: Owner = _placements._space
	if not _fragments.spend(12 * owner._region_capacity):
		return REFUSE_CAPACITY
	for row: int in owner._region_capacity:
		if owner._r_present[row] != 1 or owner._r_role[row] == Space.FLOOR_DATUM:
			continue
		_copy_region_box(row, _scratch)
		if not Space.overlaps(bounds, _scratch):
			continue
		if owner._r_claim_kind[row] == Owner.CLAIM_ROOM and _row_room_claim(row):
			continue
		if owner._r_claim_kind[row] != Owner.CLAIM_NONE:
			return REFUSE_BEARING
		if owner._r_role[row] != Space.DRY_SOLID and owner._r_role[row] != Space.SUPPORT:
			return REFUSE_BEARING
	return _virgin_keys_refusal(bounds)


func _row_room_claim(row: int) -> bool:
	"""Only this permanent Corridor's exact marker can coexist with its own retained bearing."""
	var owner: Owner = _placements._space
	return owner._r_claim_slot[row] == _order.corridor.x and owner._r_claim_generation[row] == _order.corridor.y \
		and owner._r_owner_slot[row] == _order.corridor.x and owner._r_owner_generation[row] == _order.corridor.y


func _virgin_keys_refusal(bounds: PackedInt32Array) -> StringName:
	"""Even a backfilled paid cube is not relabelled retained natural earth."""
	var datum: Vector3i = _placements._space._domain._datum
	var y: int = datum.y + _floor_div(int(bounds[1]) - datum.y, 1024) * 1024
	while y < bounds[4]:
		var z: int = datum.z + _floor_div(int(bounds[2]) - datum.z, 1024) * 1024
		while z < bounds[5]:
			var x: int = datum.x + _floor_div(int(bounds[0]) - datum.x, 1024) * 1024
			while x < bounds[3]:
				if not _fragments.spend(20):
					return REFUSE_CAPACITY
				var row: int = _site_row(Vector3i(x, y, z))
				if row >= 0 and _sites._ever_cut[row] != 0:
					return REFUSE_BEARING
				x += 1024
			z += 1024
		y += 1024
	return &""


static func _floor_div(value: int, denominator: int) -> int:
	"""Negative coordinates use mathematical floor, preserving the actual paid datum."""
	@warning_ignore("integer_division") var result: int = value / denominator
	return result - 1 if value < 0 and value % denominator != 0 else result


func _copy_region_box(row: int, out: PackedInt32Array) -> void:
	"""Copy current packed bounds into fixed caller scratch without a region object or observation hook."""
	var owner: Owner = _placements._space
	out[0] = owner._r_lo_x[row]
	out[1] = owner._r_lo_y[row]
	out[2] = owner._r_lo_z[row]
	out[3] = owner._r_hi_x[row]
	out[4] = owner._r_hi_y[row]
	out[5] = owner._r_hi_z[row]


func _installed_part_refusal(bounds: PackedInt32Array) -> StringName:
	"""A prior billable prefix is necessary but physical source-part and current solid coverage are also required."""
	var group: int = _bearing[1]
	var part: int = _bearing[2]
	var assemblies: Assemblies = _placements._assemblies
	if _bearing[0] != Frontier.INSTALLED_PART or group < 0 or group >= _ordinal \
			or part < assemblies._first_part[group] or part >= assemblies._first_part[group] + assemblies._part_count[group]:
		return REFUSE_BEARING
	var catalog: Catalog = _placements._catalog
	var at: int = Catalog._v(catalog._live, _order.catalog_row, Catalog.V_PART_START) + part
	for field: int in 9:
		_part[field] = catalog._live.parts[field * Catalog.MAX_PARTS + at]
	var code: StringName = _part_box_refusal()
	if code == &"":
		code = _installed_bearing_obstacles(bounds)
	if code != &"":
		return code
	_fragments.start(bounds)
	var owner: Owner = _placements._space
	for row: int in owner._region_capacity:
		if not _fragments.spend():
			return REFUSE_CAPACITY
		if not _installed_solid_row(row):
			continue
		_copy_region_box(row, _scratch)
		if not _fragments.subtract(_scratch):
			return REFUSE_CAPACITY
		if _fragments.count == 0:
			return &""
	return REFUSE_BEARING


func _installed_bearing_obstacles(bounds: PackedInt32Array) -> StringName:
	"""An exact part and positive support union cannot hide another owner's claim or physical obstacle."""
	var owner: Owner = _placements._space
	if not _fragments.spend(12 * owner._region_capacity):
		return REFUSE_CAPACITY
	for row: int in owner._region_capacity:
		if owner._r_present[row] != 1 or owner._r_role[row] == Space.FLOOR_DATUM or _installed_solid_row(row):
			continue
		if owner._r_claim_kind[row] == Owner.CLAIM_ROOM and _row_room_claim(row):
			continue
		_copy_region_box(row, _scratch)
		if Space.overlaps(bounds, _scratch):
			return REFUSE_BEARING
	return &""


func _installed_solid_row(row: int) -> bool:
	"""Only lasting actual same-Corridor physical rows can supply an installed part's solid target."""
	var owner: Owner = _placements._space
	return owner._r_present[row] == 1 and owner._r_claim_kind[row] == Owner.CLAIM_NONE \
		and owner._r_owner_slot[row] == _order.corridor.x and owner._r_owner_generation[row] == _order.corridor.y \
		and (owner._r_role[row] == Space.SUPPORT or owner._r_role[row] == Space.OBSTACLE)


func _part_box_refusal() -> StringName:
	"""The first timber reader proves convex horizontal prism containment; sloped or concave parts refuse explicitly."""
	var count: int = _part[8]
	var first: int = _part[7]
	var catalog: Catalog = _placements._catalog
	if count < 3 or count > 16 or not _fragments.spend(16 + 12 * count * count):
		return REFUSE_CAPACITY
	var top: int = catalog._live.vertices[Catalog.MAX_VERTICES + first]
	if _bearing[4] < top - _part[1] or _bearing[7] > top:
		return REFUSE_BEARING
	var orientation: int = 0
	for edge: int in count:
		var a: int = first + edge
		var b: int = first + (edge + 1) % count
		if catalog._live.vertices[Catalog.MAX_VERTICES + a] != top:
			return REFUSE_BEARING
		for point: int in count:
			var cross: int = _part_cross(a, b, catalog._live.vertices[first + point],
				catalog._live.vertices[2 * Catalog.MAX_VERTICES + first + point])
			if cross == 0:
				continue
			if orientation == 0:
				orientation = 1 if cross > 0 else -1
			elif cross * orientation < 0:
				return REFUSE_BEARING
	if orientation == 0:
		return REFUSE_BEARING
	return _bearing_in_prism(first, count, orientation)


func _bearing_in_prism(first: int, count: int, orientation: int) -> StringName:
	"""For a proved convex top polygon, all four rectangle corners prove the entire bearing projection."""
	for edge: int in count:
		var a: int = first + edge
		var b: int = first + (edge + 1) % count
		for corner: int in 4:
			var x: int = _bearing[3 if (corner & 1) == 0 else 6]
			var z: int = _bearing[5 if (corner & 2) == 0 else 8]
			if _part_cross(a, b, x, z) * orientation < 0:
				return REFUSE_BEARING
	return &""


func _part_cross(a: int, b: int, x: int, z: int) -> int:
	"""Catalog bounds keep every exact cross-product safely within signed int64."""
	var vertices: PackedInt32Array = _placements._catalog._live.vertices
	var ax: int = vertices[a]
	var az: int = vertices[2 * Catalog.MAX_VERTICES + a]
	return (int(vertices[b]) - ax) * (z - az) - (int(vertices[2 * Catalog.MAX_VERTICES + b]) - az) * (x - ax)


func _profile_refusal() -> StringName:
	"""An installation source must explicitly name the real BUILD tool and complete certified WORK contact roles."""
	var profiles: Profiles = _placements._profiles
	var id: int = _station[5]
	var code: StringName = profiles.descriptor_into(id, _frontier._header[5], _descriptor)
	if code == &"":
		code = _scope_leaf()
	if code != &"":
		return code
	var heading: int = _world_yaw()
	if _descriptor.profile_revision != _profile_revision or _descriptor.source_id != _frontier._header[7] \
			or _descriptor.mode != Profiles.MODE_WORK or _descriptor.work_kind != Jobs.JOB_KIND_BUILD \
			or _descriptor.yaw_kind != Profiles.YAW_EXACT or _descriptor.yaw != heading \
			or _descriptor.posture != _station[6] or _descriptor.certificate_flags != Profiles.CERT_REQUIRED \
			or _descriptor.contact_kind != Profiles.CONTACT_ANCHOR_AND_PATCH \
			or _descriptor.tool_item < 0 or _descriptor.tool_item != _tool_item():
		return REFUSE_PROFILE
	return _scope_leaf()


func _read_profile_box(ordinal: int, out: Profiles.Box, source_profile: int = -1) -> bool:
	"""Immutable source columns supply exact boxes; no public profile observer runs in the final physical leaf."""
	var profiles: Profiles = _placements._profiles
	var profile: int = _station[5] if source_profile < 0 else source_profile
	var count: int = profiles._field(profiles._live, profile, Profiles.F_BOX_COUNT)
	if ordinal < 0 or ordinal >= count or not _fragments.spend():
		return false
	var at: int = profiles._field(profiles._live, profile, Profiles.F_FIRST_BOX) + ordinal
	out.low = Vector3i(profiles._live.boxes[at], profiles._live.boxes[profiles._box_capacity + at],
		profiles._live.boxes[2 * profiles._box_capacity + at])
	out.high = Vector3i(profiles._live.boxes[3 * profiles._box_capacity + at],
		profiles._live.boxes[4 * profiles._box_capacity + at], profiles._live.boxes[5 * profiles._box_capacity + at])
	out.role = profiles._live.boxes[6 * profiles._box_capacity + at]
	return true


func _profile_bounds(box: Profiles.Box, out: PackedInt32Array) -> StringName:
	"""Profiles already encode the exact World yaw; only the actual station root translates their bounds."""
	var domain: Space.Domain = _placements._space._domain
	for axis: int in 3:
		var low: int = int(_location.point[axis]) + int(box.low[axis])
		var high: int = int(_location.point[axis]) + int(box.high[axis])
		if low >= high or low < domain._bounds[axis] or high > domain._bounds[axis + 3]:
			return REFUSE_PROFILE
		out[axis] = low
		out[axis + 3] = high
	return &""


func _profile_geometry(source_profile: int = -1) -> StringName:
	"""The entire source motion must fit actual completed air/support; only productive stroke may touch its bearing."""
	var point: bool = false
	var patch: bool = false
	var stance: bool = false
	for ordinal: int in _profile_box_count(source_profile):
		if not _read_profile_box(ordinal, _box, source_profile):
			return REFUSE_CAPACITY
		var code: StringName = &""
		if _box.role == Profiles.CONTACT_POINT or _box.role == Profiles.CONTACT_PATCH:
			code = _contact_refusal(_box, source_profile)
			point = point or _box.role == Profiles.CONTACT_POINT
			patch = patch or _box.role == Profiles.CONTACT_PATCH
		else:
			code = _profile_bounds(_box, _bounds)
			if code == &"":
				code = _role_geometry(_box.role, source_profile)
			stance = stance or _box.role == Profiles.STANCE_SUPPORT
		if code != &"":
			return code
	return &"" if point and patch and stance else REFUSE_PROFILE


func _profile_box_count(source_profile: int) -> int:
	"""A separate handling proof traverses its whole immutable source while retaining the original INSTALL Descriptor."""
	return _descriptor.box_count if source_profile < 0 else _placements._profiles._field(
		_placements._profiles._live, source_profile, Profiles.F_BOX_COUNT)


func _role_geometry(role: int, source_profile: int = -1) -> StringName:
	"""Qualified endpoint boxes are immutable exact unions, not a bounding-box approximation to an unproved room."""
	var code: StringName = _terrain_refusal(_bounds, Terrain.EXCLUSIONS)
	if code != &"":
		return code
	if _workpiece_owner() != null and role != Profiles.WORK_STROKE and Space.overlaps(_bounds, _target):
		return REFUSE_GEOMETRY
	if role == Profiles.STANCE_SUPPORT:
		return &"" if Space.contains_box(_location.support, _bounds) else REFUSE_GEOMETRY
	_fragments.start(_bounds)
	if not _fragments.subtract(_location.envelope):
		return REFUSE_CAPACITY
	if role == Profiles.WORK_STROKE:
		if not _fragments.subtract(_target):
			return REFUSE_CAPACITY
	elif not _subtract_stances(source_profile):
		return REFUSE_CAPACITY if _fragments.failed else REFUSE_GEOMETRY
	return &"" if _fragments.count == 0 else REFUSE_GEOMETRY


func _subtract_stances(source_profile: int = -1) -> bool:
	"""Only the exact authored stance intersection with actual completed support excuses below-root body residual."""
	for ordinal: int in _profile_box_count(source_profile):
		if not _read_profile_box(ordinal, _stance, source_profile):
			return false
		if _stance.role != Profiles.STANCE_SUPPORT:
			continue
		if _profile_bounds(_stance, _support) != &"":
			return false
		if not Space.overlaps(_support, _location.support):
			continue
		for axis: int in 3:
			_support[axis] = maxi(_support[axis], _location.support[axis])
			_support[axis + 3] = mini(_support[axis + 3], _location.support[axis + 3])
		if not _fragments.subtract(_support):
			return false
	return true


func _contact_refusal(box: Profiles.Box, source_profile: int = -1) -> StringName:
	"""Positive source patch containment includes the selected maximum face; an anchor alone cannot qualify it."""
	var face: int = _world_face(_station[7])
	@warning_ignore("integer_division") var axis: int = face / 2
	var plane: int = _target[axis + (3 if face % 2 != 0 else 0)]
	if _workpiece_owner() == null and ((face % 2 == 0 and _location.point[axis] >= plane) \
			or (face % 2 != 0 and _location.point[axis] < plane)):
		return REFUSE_GEOMETRY
	for component: int in 3:
		var low: int = int(_location.point[component]) + int(box.low[component])
		var high: int = int(_location.point[component]) + int(box.high[component])
		if not Space.int32(low) or not Space.int32(high):
			return REFUSE_GEOMETRY
		if component == axis:
			if low != plane or high != plane:
				return REFUSE_GEOMETRY
		elif low < _target[component] or high > _target[component + 3] \
				or (box.role == Profiles.CONTACT_PATCH and low >= high):
			return REFUSE_GEOMETRY
	return _stroke_reaches(box, source_profile) if box.role == Profiles.CONTACT_POINT else &""


func _stroke_reaches(contact: Profiles.Box, source_profile: int = -1) -> StringName:
	"""A contact plane outside every actual source stroke cannot be relabelled a fastening motion."""
	for ordinal: int in _profile_box_count(source_profile):
		if not _read_profile_box(ordinal, _stance, source_profile):
			return REFUSE_CAPACITY
		if _stance.role != Profiles.WORK_STROKE:
			continue
		if contact.low.x >= _stance.low.x and contact.low.y >= _stance.low.y and contact.low.z >= _stance.low.z \
				and contact.low.x <= _stance.high.x and contact.low.y <= _stance.high.y and contact.low.z <= _stance.high.z:
			return &""
	return REFUSE_GEOMETRY


func _world_face(face: int) -> int:
	"""The six canonical face tags rotate exactly with the authored Placement's quarter turn."""
	if face == 2 or face == 3 or _frame[3] == 0:
		return face
	var x: int = -1 if face == 0 else 1 if face == 1 else 0
	var z: int = -1 if face == 4 else 1 if face == 5 else 0
	var rx: int = -z if _frame[3] == 1 else -x if _frame[3] == 2 else z
	var rz: int = x if _frame[3] == 1 else -z if _frame[3] == 2 else -x
	return 0 if rx < 0 else 1 if rx > 0 else 4 if rz < 0 else 5


func _terrain_refusal(bounds: PackedInt32Array, purpose: int) -> StringName:
	"""Only the exact original sealed installation or phase context admits prepared local facts."""
	if not _fragments.spend(256 + 16 * Terrain.LOCAL_TILE_LIMIT):
		return REFUSE_CAPACITY
	if _placements._space._stage_token == 0:
		return _terrain.local_facts_refusal(bounds, purpose, _geometry_revision)
	if _phase_mode:
		var code: StringName = _prepared_phase_leaf(_phase_space_token, _phase_companion_token)
		return code if code != &"" else _terrain.prepared_local_facts_refusal(bounds, purpose,
			_geometry_revision, _phase_space_token, _phase_cold_token)
	if _workpiece_owner() != null:
		var code: StringName = _workpiece_context_leaf()
		if code != &"": return code
	elif _action != Contract.COMMIT:
		return REFUSE_SCOPE
	if _placements._prepared_placement != _placement \
			or _placements._prepared_project != _project or _placements._prepared_assembly != _ordinal:
		return REFUSE_SCOPE
	return _terrain.prepared_local_facts_refusal(bounds, purpose, _geometry_revision,
		_placements._space_token, _placements._cold_token)


func _read_source_row(table: int, row: int, out: PackedInt32Array) -> StringName:
	"""Final proof reads exact immutable banks directly, with no overridable row observer."""
	if not _fragments.spend(SOURCE_CHECKS):
		return REFUSE_CAPACITY
	if Frontier.source_leaf_refusal(_frontier) != &"" or not _frontier._valid_row(table, row) \
			or out.size() != Frontier.row_fields(table):
		return REFUSE_SOURCE
	for field: int in out.size():
		out[field] = _frontier._field(table, row, field)
	return &""


func _read_catalog_region(ordinal: int) -> StringName:
	"""A variant-relative LANDING supplies authored floor metadata, never physical supported void."""
	if not _fragments.spend(SOURCE_CHECKS):
		return REFUSE_CAPACITY
	var catalog: Catalog = _placements._catalog
	if _binding_leaf() != &"" or ordinal < 0 \
			or ordinal >= Catalog._v(catalog._live, _order.catalog_row, Catalog.V_REGION_COUNT):
		return REFUSE_SOURCE
	var at: int = Catalog._v(catalog._live, _order.catalog_row, Catalog.V_REGION_START) + ordinal
	for field: int in 8:
		_region[field] = catalog._live.regions[field * Catalog.MAX_REGIONS + at]
	return &""


func admission_refusal(placement: Vector2i, assembly: int) -> StringName:
	"""Actual source, completed approach, dependencies and retreat precede spending a Project identity."""
	if not _enter():
		return REFUSE_REENTRY
	var code: StringName = _pin_scope(placement, NULL_REF, assembly, Contract.ADMIT)
	if code == &"":
		code = _observe_live()
	if code == &"":
		code = _resolve_proof(false)
	_valid = code == &""
	return _leave(code)


func transition_refusal(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
	"""The tick path allocates no cold image and reuses only current actual endpoint and graph facts."""
	if not _enter():
		return REFUSE_REENTRY
	if _workpiece_owner() != null and _placements._space._stage_token != 0:
		var prepared: StringName = _prepared_start_proof(placement, project, assembly, action)
		_valid = prepared == &""
		return _leave(prepared)
	var code: StringName = _pin_scope(placement, project, assembly, action)
	if code == &"" and action != Contract.PRODUCTIVE:
		code = _observe_live()
	if code == &"":
		code = _cancel_proof() if action == Contract.CANCEL else _resolve_proof(action != Contract.COMMIT)
	_valid = code == &""
	return _leave(code)


func prepare_workpiece_start(placement: Vector2i, project: Vector2i, assembly: int) -> StringName:
	"""Pin live endpoints, routes and goods first; no target or work permission exists until the later full proof."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = _pin_scope(placement, project, assembly, Contract.START)
	if code == &"": code = _observe_live()
	if code == &"": code = _phase_leaf()
	if code == &"": code = _resolve_all_endpoints()
	if code == &"": code = _material_leaf(_material_container)
	if code == &"": code = _scene_leaf()
	if code == &"": _pin_receipts()
	_valid = false
	return _leave(code if code != &"" else _scope_leaf())


func _prepared_start_proof(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
	"""Reuse the original unprivileged prepass without resetting its work counter or querying prepared live banks."""
	if _phase_mode or _valid or action != Contract.START or action != _action or placement != _placement \
			or project != _project or assembly != _ordinal: return REFUSE_SCOPE
	var code: StringName = _workpiece_context_leaf()
	if code == &"": code = _scope_leaf()
	if code == &"": code = _receipt_leaf()
	if code == &"": code = _profile_refusal()
	if code == &"": code = _phase_leaf()
	if code == &"": code = _physical_leaf()
	if code == &"": code = _crew_leaf()
	if code == &"": code = _material_leaf(_material_container)
	if code == &"": code = _scene_leaf()
	return code if code != &"" else _scope_leaf()


func _observe_live() -> StringName:
	"""Cold observers finish before physical leaf proof; they cannot choose a later mutable source packet."""
	if _placements._space._stage_token != 0:
		return REFUSE_SCOPE
	var code: StringName = _terrain.binding_refusal()
	if code == &"" and _action != Contract.CANCEL:
		code = _profile_refusal()
	return code if code != &"" else _scope_leaf()


func _resolve_proof(require_worker: bool) -> StringName:
	"""Fresh full selectors and certified paths are necessary in addition to actual cut and support truth."""
	var code: StringName = _observe_workpiece_terrain()
	if code == &"":
		code = _phase_leaf()
	if code == &"":
		code = _resolve_all_endpoints()
	if code == &"":
		code = _physical_leaf()
	if code == &"" and require_worker:
		code = _crew_leaf()
	if code == &"" and _material_container != NULL_REF:
		code = _material_leaf(_material_container)
	if code == &"" and _phase_mode:
		code = _phase_output_leaf()
	if code == &"":
		code = _scene_leaf()
	if code == &"":
		_pin_receipts()
	return code if code != &"" else _scope_leaf()


func _observe_workpiece_terrain() -> StringName:
	"""A paid set-down changes Space: observe its current World facts before all physical and worker leaves."""
	if _phase_mode or _terrain._checked_geometry_revision == _geometry_revision:
		return &""
	var actual: Workpieces = _workpiece_owner()
	if actual == null:
		return &""
	var code: StringName = Workpieces.source_leaf_refusal(actual, _placement, _project)
	var row: int = _project_row()
	if code != &"" or row < 0 or not Workpieces._row_matches(actual, _placement, _project) \
			or not Workpieces._funded(actual, _project, row) or _placements._space._stage_token != 0:
		return code if code != &"" else REFUSE_SCOPE
	if not _fragments.spend(256 + 2 * _placements._space._source_capacity):
		return REFUSE_CAPACITY
	code = _terrain.binding_refusal()
	return code if code != &"" else _scope_leaf()


func _resolve_all_endpoints() -> StringName:
	"""Only already-live unique WORK/STORAGE/retreat identities can satisfy immutable selectors."""
	_station_location = _resolve_endpoint(_station[0])
	_material_location = _resolve_endpoint(_install[7])
	_retreat_location = _resolve_endpoint(_install[8])
	if _station_location == NULL_REF or _material_location == NULL_REF or _retreat_location == NULL_REF:
		return REFUSE_ENDPOINT
	var code: StringName = _endpoint_payloads()
	if code == &"":
		code = _approach_refusal()
	if code == &"":
		code = _path_refusal(_station_location, _retreat_location, _install[8])
	return _phase_resolve_output() if code == &"" and _phase_mode else code


func _approach_refusal() -> StringName:
	"""ADR1202 split landing: a station whose own travel profile differs from the material selector's admits only
	that narrow approach, so the worker changes profile at the authored retreat (arrival) endpoint: material to
	arrival on the material profile, then arrival to station on the station's. Equal profiles go direct."""
	var material: int = _install[7]
	if _frontier._travel_profile[material] == _frontier._travel_profile[_station[0]] \
			and _frontier._travel_revision[material] == _frontier._travel_revision[_station[0]]:
		return _path_refusal(_material_location, _station_location, material)
	var code: StringName = _path_refusal(_material_location, _retreat_location, material)
	return code if code != &"" else _path_refusal(_retreat_location, _station_location, _station[0])


func _endpoint_payloads() -> StringName:
	"""Retain exact payload revisions only; future queries still prove actual full handles and source facts."""
	var code: StringName = _read_endpoint(_station[0], _station_location, _location)
	if code != &"" or _location.role != Locations.ROLE_WORK:
		return REFUSE_ENDPOINT
	_station_payload = _location.payload_revision
	code = _read_endpoint(_install[7], _material_location, _other)
	if code != &"" or _other.role != Locations.ROLE_STORAGE:
		return REFUSE_MATERIAL
	_material_payload = _other.payload_revision
	code = _read_endpoint(_install[8], _retreat_location, _other)
	if code != &"":
		return code
	_retreat_payload = _other.payload_revision
	return &""


func _path_refusal(first: Vector2i, last: Vector2i, selector: int) -> StringName:
	"""A finite static route is feasibility only; no worker arrival or actual carry is inferred."""
	var before: int = _fragments.remaining
	var code: StringName = WorldRoutes.profile_reachability_refusal(_placements._world_routes, first, last,
		_frontier._travel_profile[selector], _frontier._travel_revision[selector], _frontier._header[5], before, _remaining)
	if code != &"":
		return code
	if _remaining[0] < 0 or _remaining[0] > before or not _fragments.spend(before - _remaining[0]):
		return REFUSE_CAPACITY
	return _scope_leaf()


func _physical_leaf() -> StringName:
	"""Exact current prerequisites precede the complete source motion; no prefix grants a geometric shortcut."""
	var code: StringName = _cut_dependencies()
	if code == &"":
		code = _bearing_dependencies()
	if code == &"":
		code = _descriptor_leaf()
	if code == &"" and not _phase_mode and (_action == Contract.PRODUCTIVE or _action == Contract.COMMIT) \
			and _assembly_source_selected():
		code = Workpieces.handled_leaf_refusal(_workpiece_owner(), _placement, _project)
	return _profile_geometry() if code == &"" else code


func _cancel_proof() -> StringName:
	"""Cancellation preserves paid prefixes even when a new installation is no longer physically possible."""
	var code: StringName = _phase_leaf()
	if code == &"" and _material_container != NULL_REF:
		code = _resolve_all_endpoints()
		if code == &"":
			code = _material_leaf(_material_container)
	if code == &"":
		code = _scene_leaf()
	if code == &"":
		_pin_receipts()
	return code


func _pin_receipts() -> void:
	"""A COMMIT candidate may retain these live banks only while every original successful receipt remains exact."""
	_space_receipt = _placements._space._last_published_token
	_location_receipt = _placements._locations._last_published_token
	_route_receipt = _placements._routes._last_published_token


func _receipt_leaf() -> StringName:
	"""Equal numeric geometry revisions do not authorize replaced live graph or endpoint images."""
	if _space_receipt != _placements._space._last_published_token \
			or _location_receipt != _placements._locations._last_published_token \
			or _route_receipt != _placements._routes._last_published_token:
		return REFUSE_SCOPE
	var code: StringName = _read_endpoint(_station[0], _station_location, _location)
	if code != &"" or _location.payload_revision != _station_payload:
		return REFUSE_ENDPOINT
	code = _read_endpoint(_install[7], _material_location, _other)
	if code != &"" or _other.payload_revision != _material_payload or _other.role != Locations.ROLE_STORAGE:
		return REFUSE_MATERIAL
	code = _read_endpoint(_install[8], _retreat_location, _other)
	if code != &"" or _other.payload_revision != _retreat_payload:
		return REFUSE_ENDPOINT
	return _phase_output_receipt() if _phase_mode else &""


func final_observation_refusal(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
	"""All potentially observing reads remain before the actual pure source/worker/geometry payment guard."""
	if not _enter():
		return REFUSE_REENTRY
	var code: StringName = _retained_scope(placement, project, assembly, action)
	if code == &"" and action != Contract.CANCEL:
		code = _profile_refusal()
	if code == &"" and (action == Contract.START or action == Contract.PRODUCTIVE):
		code = _observe_workers()
	if code == &"" and _station_location != NULL_REF and _placements._locations._token == 0:
		code = _placements._locations.read_location_into(_station_location, _other)
	return _leave(code if code != &"" else _scope_leaf())


func handling_observation_refusal(placement: Vector2i, project: Vector2i, worker: Vector2i,
		job: Vector2i) -> StringName:
	"""The paid handling owner borrows one original graph budget before observations; its concrete tail repeats proof."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = _binding_leaf() if _configured else REFUSE_BINDING
	var pieces: Workpieces = _workpiece_owner() if code == &"" else null
	if code == &"" and pieces == null: code = REFUSE_BINDING
	if code == &"":
		code = Workpieces.handling_leaf_refusal(pieces, placement, project, worker, job)
	if code == &"":
		code = _placements._world_routes.assembly_handling_refusal(pieces, placement, project, worker, job)
	return _leave(code)


func release_observation_refusal(placement: Vector2i, project: Vector2i, worker: Vector2i,
		job: Vector2i) -> StringName:
	"""Positioning-only release observes current owners under the caller's original whole-crew budget."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = _binding_leaf() if _configured else REFUSE_BINDING
	var pieces: Workpieces = _workpiece_owner() if code == &"" else null
	if code == &"" and pieces == null: code = REFUSE_BINDING
	if code == &"":
		code = _placements._world_routes.assembly_release_observation_refusal(pieces, placement, project, worker, job)
	return _leave(code)


func _observe_workers() -> StringName:
	"""Actual selection observers finish before the direct final worker and physical proof."""
	var primary: int = _job_row(_primary_job)
	if primary < 0: return REFUSE_WORKER
	var jobs: Jobs = _placements._jobs
	var row: int = primary if jobs._is_coordinator[primary] == 0 else jobs._member_head[primary]
	var count: int = 0
	while row >= 0:
		count += 1
		if row >= Router.JOB_CAPACITY or count > Construction.MAX_BUILDERS: return REFUSE_WORKER
		var worker: Vector2i = Vector2i(jobs._worker_slot[row], jobs._worker_generation[row])
		var job: Vector2i = Vector2i(jobs._job_ref_slot[row], jobs._job_ref_generation[row])
		if worker != NULL_REF:
			if not _fragments.spend(256): return REFUSE_CAPACITY
			var code: StringName = _placements._profiles._prepare_query(worker, job, Profiles.MODE_WORK,
				_station[6], -1, NULL_REF, _selection)
			if code == &"":
				if _assembly_start():
					code = Routes.source_ready_leaf_refusal(_placements._routes, worker, job,
						AssemblySource.PROFILE, 1, _frontier._header[5])
				else:
					code = _placements._routes.source_work_observation_refusal(worker, job, _station[5],
						_profile_revision, _frontier._header[5])
			if code != &"": return code
		if jobs._is_coordinator[primary] == 0: break
		row = jobs._member_next[row]
	return &""


func final_leaf_refusal(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
	"""No new observer, profile selection, path allocation or payment follows this actual-state proof."""
	if not _enter():
		return REFUSE_REENTRY
	var code: StringName = _retained_scope(placement, project, assembly, action)
	if code == &"":
		_fragments.remaining = _placements._space._domain._checks
		_fragments.failed = false
		code = _phase_leaf()
	if code == &"" and (action != Contract.CANCEL or _material_container != NULL_REF):
		code = _receipt_leaf()
	if code == &"" and action != Contract.CANCEL:
		code = _physical_leaf()
	if code == &"" and (action == Contract.START or action == Contract.PRODUCTIVE):
		code = _crew_leaf()
	if code == &"" and _material_container != NULL_REF:
		code = _material_leaf(_material_container)
	if code == &"":
		code = _scene_leaf()
	return _leave(code if code != &"" else _scope_leaf())


func _retained_scope(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
	"""A direct or stale final call cannot reuse the previous unrelated contact observation."""
	if _phase_mode or not _valid or placement != _placement or project != _project or assembly != _ordinal or action != _action:
		return REFUSE_SCOPE
	return _scope_leaf()


func discard_transition(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> void:
	"""Release only local exact-scope observations; there is no lease or authoritative progress to discard."""
	if not _busy and not _phase_mode and placement == _placement and project == _project and assembly == _ordinal and action == _action:
		_valid = false
		_primary_job = NULL_REF
		_material_container = NULL_REF


func _project_row() -> int:
	"""Purpose8's local Placement subject never aliases a Directory Room or a foreign project's ordinal."""
	var construction: Construction = _placements._construction
	var ids: Directory = _placements._ids
	if not ids.is_valid_of_kind(_project, Directory.KIND_CONSTRUCTION):
		return -1
	var row: int = ids.get_typed_row(_project)
	if _phase_mode:
		return _site_project_row(row)
	return row if row >= 0 and row < Construction.CONSTRUCTION_CAPACITY and construction._present[row] == 1 \
		and construction._ref_slot[row] == _project.x and construction._ref_generation[row] == _project.y \
		and construction._purpose[row] == Construction.PURPOSE_CONNECTOR_INSTALL \
		and construction._subject_slot[row] == _placement.x and construction._subject_generation[row] == _placement.y \
		and construction._type_id[row] == _ordinal else -1


func _phase_leaf() -> StringName:
	"""Late phase or pause changes cannot retain a valid identity while authorizing another irreversible action."""
	if _phase_mode:
		return _site_lifecycle_leaf()
	if _action == Contract.ADMIT:
		return &"" if _project == NULL_REF and _order.project == NULL_REF else REFUSE_SCOPE
	var row: int = _project_row()
	if row < 0:
		return REFUSE_SCOPE
	var construction: Construction = _placements._construction
	var phase: int = construction._phase[row]
	if phase < 0 or phase >= Construction.PHASE_COUNT or construction._remaining_mwu[row] < 0:
		return REFUSE_SCOPE
	if _action == Contract.CANCEL or _action == -1:
		return &""
	if construction._paused[row] != 0:
		return Construction.REFUSE_PAUSED
	var funding: RefCounted = _actual_router()._funding
	var funded: bool = funding._project_slot[row] == _project.x and funding._project_generation[row] == _project.y
	if _action == Contract.START and phase == Construction.PHASE_READY and construction._work_begun[row] == 0 and not funded:
		return &""
	if not funded or construction._work_begun[row] != 1:
		return Construction.REFUSE_WRONG_PHASE
	if _action == Contract.COMMIT:
		return &"" if phase == Construction.PHASE_WORK_DONE and construction._remaining_mwu[row] == 0 else Construction.REFUSE_WRONG_PHASE
	return &"" if (_action == Contract.START or _action == Contract.PRODUCTIVE) and phase == Construction.PHASE_WORKING \
		and construction._remaining_mwu[row] > 0 else Construction.REFUSE_WRONG_PHASE


func _owner_action(project: Vector2i) -> int:
	"""A material/worker hook may precede the purpose owner's transition, so it cannot mint that transition."""
	var router: Router = _actual_router()
	var owner: Paid = router._connector_owner.get_ref() as Paid if router != null and router._connector_owner != null else null
	return owner._stage_action if owner != null and owner._stage_project == project else -1


func material_refusal(placement: Vector2i, project: Vector2i, assembly: int, container: Vector2i, job: Vector2i) -> StringName:
	"""Delivered and refunded goods need the exact current STORAGE endpoint and authored certified route."""
	if not _enter():
		return REFUSE_REENTRY
	if _workpiece_owner() != null and _placements._space._stage_token != 0:
		return _leave(_prepared_material_refusal(placement, project, assembly, container, job))
	var code: StringName = _pin_scope(placement, project, assembly, _owner_action(project))
	if code == &"":
		code = _pin_primary(job)
	if code == &"":
		_material_container = container
		code = _observe_live()
	if code == &"":
		code = _cancel_proof() if _action == Contract.CANCEL else _resolve_proof(false)
	_valid = code == &""
	return _leave(code)


func _prepared_material_refusal(placement: Vector2i, project: Vector2i, assembly: int,
		container: Vector2i, job: Vector2i) -> StringName:
	"""Funding's later material hook may only reattest the exact already-selected live endpoint under this candidate."""
	var code: StringName = _retained_scope(placement, project, assembly, _owner_action(project))
	if code == &"": code = _workpiece_context_leaf()
	if code == &"": code = _pin_primary(job)
	if code == &"": code = _receipt_leaf()
	if code == &"": code = _material_leaf(container)
	if code == &"": _material_container = container
	return code if code != &"" else _scope_leaf()


func _material_leaf(container: Vector2i) -> StringName:
	"""Material binding and the selected current STORAGE endpoint must agree inside settlement."""
	var code: StringName = _material_binding_refusal(container)
	return _storage_leaf(container, _material_location, _install[7]) if code == &"" else code


func _storage_leaf(container: Vector2i, location: Vector2i, selector: int) -> StringName:
	"""Actual finite spatial Inventory cannot substitute a coincident container or a replaced Location payload."""
	var inventory: RefCounted = _placements._inventory
	var row: int = inventory._spatial_row(container)
	if row < 0 or inventory._spatial_world != _placements._world or inventory._spatial_authority == null \
			or inventory._spatial_location(row) != location or inventory._c_reachable[container.x] != 1 \
			or inventory._c_owner_slot[container.x] != _placements._world.x \
			or inventory._c_owner_generation[container.x] != _placements._world.y \
			or inventory._c_max_mass_g[container.x] != inventory.GROUND_PILE_MAX_MASS_G \
			or inventory._c_filters[container.x] != inventory.FILTERS_ACCEPT_ALL:
		return REFUSE_MATERIAL
	var adapter: RefCounted = inventory._spatial_authority.get_ref() as RefCounted
	if not adapter is Locations.InventoryLocations or adapter._locations == null \
			or adapter._locations.get_ref() != _placements._locations:
		return REFUSE_MATERIAL
	if inventory._c_policy[container.x] != inventory.UNSET_POLICY and inventory._c_policy[container.x] != inventory.POLICY_GROUND_PILE:
		return REFUSE_MATERIAL
	var code: StringName = _read_endpoint(selector, location, _other)
	return code if code != &"" else &"" if _other.role == Locations.ROLE_STORAGE \
		and inventory._spatial_location_revision[row] == _other.payload_revision else REFUSE_MATERIAL


func _material_binding_refusal(container: Vector2i) -> StringName:
	"""Only the final paid phases require the retained destination to equal Construction's actual delivery binding."""
	if _action != Contract.START and _action != Contract.PRODUCTIVE and _action != Contract.COMMIT:
		return &""
	var row: int = _project_row()
	var construction: Construction = _placements._construction
	return &"" if row >= 0 and container == Vector2i(construction._material_container_slot[row],
		construction._material_container_generation[row]) else REFUSE_MATERIAL


func _pin_primary(job: Vector2i) -> StringName:
	"""Resolve an accepted member through its real full coordinator; no hot global Job search is required."""
	var row: int = _job_row(job)
	if row < 0:
		return REFUSE_WORKER
	var jobs: Jobs = _placements._jobs
	_primary_job = Vector2i(jobs._coordinator_slot[row], jobs._coordinator_generation[row]) \
		if jobs._coordinator_slot[row] >= 0 else job
	var primary: int = _job_row(_primary_job)
	return &"" if primary >= 0 and jobs._coordinator_slot[primary] == -1 else REFUSE_WORKER


func _job_row(job: Vector2i) -> int:
	"""Generation, request owner and Router's persistent binding must agree before any worker row is read."""
	var ids: Directory = _placements._ids
	if not ids.is_valid_of_kind(job, Directory.KIND_JOB):
		return -1
	var row: int = ids.get_typed_row(job)
	var router: Router = _actual_router()
	var jobs: Jobs = _placements._jobs
	if _phase_mode:
		return _site_job_row(job, row)
	return row if row >= 0 and row < Router.JOB_CAPACITY and jobs._job_present[row] == 1 \
		and jobs._job_ref_slot[row] == job.x and jobs._job_ref_generation[row] == job.y \
		and router._job_slot[row] == job.x and router._job_generation[row] == job.y \
		and router._project_slot[row] == _project.x and router._project_generation[row] == _project.y \
		and jobs._requester_slot[row] == _project.x and jobs._requester_generation[row] == _project.y else -1


func worker_refusal(placement: Vector2i, project: Vector2i, assembly: int, job: Vector2i, worker: Vector2i) -> StringName:
	"""Current actual selection, root, Job, equipment and complete motion are read without a cold arena."""
	if not _enter():
		return REFUSE_REENTRY
	var code: StringName = _pin_scope(placement, project, assembly, _owner_action(project))
	if code == &"":
		code = _pin_primary(job)
	if code == &"":
		code = _copy_descriptor()
	if code == &"":
		code = _resolve_proof(false)
	if code == &"":
		code = _worker_leaf(job, worker)
	_valid = code == &""
	return _leave(code if code != &"" else _scope_leaf())


func _crew_leaf() -> StringName:
	"""At most four actual contributors are rechecked after the last external observer; no crew array is retained."""
	var primary: int = _job_row(_primary_job)
	if primary < 0:
		return REFUSE_WORKER
	var jobs: Jobs = _placements._jobs
	if jobs._is_coordinator[primary] == 0:
		return _worker_leaf(_primary_job, Vector2i(jobs._worker_slot[primary], jobs._worker_generation[primary]))
	var row: int = jobs._member_head[primary]
	var count: int = 0
	var workers: int = 0
	while row >= 0:
		count += 1
		if row >= Router.JOB_CAPACITY or count > Construction.MAX_BUILDERS:
			return REFUSE_WORKER
		var job: Vector2i = Vector2i(jobs._job_ref_slot[row], jobs._job_ref_generation[row])
		if _job_row(job) != row or Vector2i(jobs._coordinator_slot[row], jobs._coordinator_generation[row]) != _primary_job:
			return REFUSE_WORKER
		var worker: Vector2i = Vector2i(jobs._worker_slot[row], jobs._worker_generation[row])
		if worker != NULL_REF:
			var code: StringName = _worker_leaf(job, worker)
			if code != &"":
				return code
			workers += 1
		row = jobs._member_next[row]
	return &"" if workers > 0 else REFUSE_WORKER


func _worker_leaf(job: Vector2i, worker: Vector2i) -> StringName:
	"""Only the real selected WORK actor already at the full station can earn labor there."""
	var graph: Routes = _placements._routes
	var row: int = _placements._ids.get_typed_row(worker)
	if _job_row(job) < 0 or not _placements._ids.is_valid_of_kind(worker, Directory.KIND_RESIDENT) \
			or row < 0 or row >= Routes.RESIDENT_CAPACITY or graph._resident_ref(row) != worker \
			or graph._resident_pair(Routes.R_JOB_SLOT, row) != job \
			or graph._resident_pair(Routes.R_LOCATION_SLOT, row) != _station_location \
			or graph._resident_pair(Routes.R_EDGE_SLOT, row) != NULL_REF:
		return REFUSE_WORKER
	if _phase_mode and _phase_needs_worker() and (_sites._worker_site[row] != _phase_site.x \
			or _sites._worker_generation[row] != worker.y):
		return REFUSE_WORKER
	if _assembly_start() or _assembly_unfunded_worker(): return _assembly_start_worker_leaf(job, worker, row)
	var code: StringName = _dynamic_selection(row, worker, job, _selection)
	if code != &"" or not graph._committed_selection(row, _selection) \
			or _selection.profile_id != _station[5] or _selection.profile_revision != _profile_revision \
			or _selection.mode != Profiles.MODE_WORK or _selection.posture != _station[6] \
			or Vector3i(_selection.x, _selection.y, _selection.z) != _location.point \
			or _selection.yaw != _world_yaw() \
			or graph._resident_pair(Routes.R_ROOM_SLOT, row) != _location.room \
			or graph._resident_pair(Routes.R_SECTION_SLOT, row) != _location.section \
			or graph._motion.resident[Routes.R_LEVEL * Routes.RESIDENT_CAPACITY + row] != _location.level:
		return code if code != &"" else REFUSE_WORKER
	code = Routes.source_work_leaf_refusal(graph, worker, job, _station[5],
		_profile_revision, _frontier._header[5])
	if code == &"": code = _worker_retreat_leaf(worker, job)
	if code == &"": code = _occupancy_leaf(worker)
	return _handling_leaf(worker, job) if code == &"" else code


func _assembly_source_selected() -> bool:
	"""Only the explicit new handling selector enters this protocol; legacy fixture paths keep their old contract."""
	var actual: Workpieces = _workpiece_owner()
	return actual != null and _ordinal >= 0 and _ordinal < actual._assembly_capacity \
		and actual._parts.size() == 6 * actual._assembly_capacity \
		and actual._parts[Workpieces.PROFILE * actual._assembly_capacity + _ordinal] == AssemblySource.PROFILE


func _assembly_start() -> bool:
	"""Funding starts at canonical handling READY; the INSTALL work selector is chosen only after handled recovery."""
	return not _phase_mode and _action == Contract.START and _assembly_source_selected()


func _assembly_unfunded_worker() -> bool:
	"""An early Router worker check observes READY before the paid owner stages START; it grants no transition."""
	if _phase_mode or _action != -1 or not _assembly_source_selected(): return false
	var row: int = _project_row()
	if row < 0: return false
	var construction: Construction = _placements._construction
	var funding: RefCounted = _actual_router()._funding
	return construction._phase[row] == Construction.PHASE_READY and construction._work_begun[row] == 0 \
		and construction._paused[row] == 0 and funding._project_slot[row] == -1 \
		and funding._project_generation[row] == 0


func _assembly_start_worker_leaf(job: Vector2i, worker: Vector2i, row: int) -> StringName:
	"""Actual BUILD assignment/tool/body and canonical READY precede payment, with no fastening work granted."""
	var actual: Workpieces = _workpiece_owner()
	var graph: Routes = _placements._routes
	var code: StringName = Workpieces.source_leaf_refusal(actual, _placement, _project)
	if code == &"": code = Routes.turn_selection_into(graph, row, _selection)
	if code == &"": code = AssemblySource.profile_refusal(_placements._profiles, _selection.profile_id,
		_selection.profile_revision, _selection.content_revision)
	if code != &"" or _selection.worker != worker or _selection.job != job \
			or _selection.content_revision != _frontier._header[5] or _selection.yaw != 0 \
			or _selection.yaw != _world_yaw() or Vector3i(_selection.x, _selection.y, _selection.z) != _location.point \
			or graph._resident_pair(Routes.R_ROOM_SLOT, row) != _location.room \
			or graph._resident_pair(Routes.R_SECTION_SLOT, row) != _location.section \
			or graph._motion.resident[Routes.R_LEVEL * Routes.RESIDENT_CAPACITY + row] != _location.level:
		return code if code != &"" else REFUSE_WORKER
	code = Routes.source_ready_leaf_refusal(graph, worker, job, AssemblySource.PROFILE, 1, _frontier._header[5])
	if code == &"": code = AssemblyPhysical._source_station(actual, _placement, _selection)
	if code == &"": code = AssemblySource.bearer_refusal(_ordinal, _location.point, _target)
	if code == &"": code = _assembly_start_geometry()
	if code == &"": code = _worker_retreat_leaf(worker, job)
	return _occupancy_leaf(worker, AssemblySource.PROFILE) if code == &"" else code


func _assembly_start_geometry() -> StringName:
	"""The full source fits current real air and footing before its future obstacle is published; no target is subtracted."""
	if _terrain._checked_geometry_revision != _geometry_revision \
			or not Terrain._final_owners_match(_terrain, _placements._space._sources): return REFUSE_BINDING
	for part: int in 3:
		var code: StringName = AssemblyPhysical._box_into(_selection, part, _bounds)
		if code == &"": code = _assembly_start_volume(part == 1)
		if code != &"": return code
	return &""


func _assembly_start_volume(foot: bool) -> StringName:
	"""Complete live physical/source proof is independent of the future full-part triangle certificate."""
	if not _fragments.spend(Terrain.LOCAL_QUERY_CHECKS): return REFUSE_CAPACITY
	var code: StringName = Terrain._final_local_tiles(_terrain, _bounds, Terrain.EXCLUSIONS)
	if code != &"": return code
	if foot and (not Space.contains_box(_location.support, _bounds) or Space.overlaps(_bounds, _target)):
		return REFUSE_GEOMETRY
	_fragments.start(_bounds)
	code = _assembly_start_regions(foot)
	if code != &"" or foot: return code
	for fragment: int in _fragments.count:
		if not _fragments.spend(Terrain.LOCAL_QUERY_CHECKS): return REFUSE_CAPACITY
		for axis: int in 6: _scratch[axis] = _fragments.first[fragment * 6 + axis]
		code = Terrain._final_local_tiles(_terrain, _scratch, Terrain.EXTERIOR)
		if code != &"": return code
	return &""


func _assembly_start_regions(foot: bool) -> StringName:
	"""Every overlapping Region; a foot may share proved SUPPORT only with its station Room's own marker (ADR 1202)."""
	var owner: Owner = _placements._space
	for region: int in owner._region_capacity:
		if not _fragments.spend(): return REFUSE_CAPACITY
		if owner._r_present[region] == 0: continue
		_copy_region_box(region, _scratch)
		if not Space.overlaps(_bounds, _scratch): continue
		if foot and AssemblyPhysical.own_room_marker(owner, region, _location.room): continue
		var role: int = owner._r_role[region]
		if role == Space.SUPPORTED_VOID:
			if not foot and not _fragments.subtract(_scratch): return REFUSE_CAPACITY
		elif role == Space.DRY_SOLID or role == Space.SUPPORT:
			if not foot: return REFUSE_GEOMETRY
		elif role != Space.FLOOR_DATUM and role != Space.PROTECTED_ACCESS: return REFUSE_GEOMETRY
	return &""


func _handling_leaf(worker: Vector2i, job: Vector2i) -> StringName:
	"""Initial set-down requires its distinct complete source and actual worker/tool/load; INSTALL is not that permission."""
	var actual: Workpieces = _workpiece_owner()
	if actual == null or _action != Contract.START or actual._stage_action != Contract.START:
		return &""
	var code: StringName = Workpieces.source_leaf_refusal(actual, _placement, _project)
	if code != &"" or not _fragments.spend(256): return code if code != &"" else REFUSE_CAPACITY
	var profile: int = actual._parts[Workpieces.PROFILE * actual._assembly_capacity + _ordinal]
	var profiles: Profiles = _placements._profiles
	var posture: int = profiles._field(profiles._live, profile, Profiles.F_POSTURE)
	code = _prepare_dynamic_leaf(worker, job, Profiles.MODE_WORK, posture, -1, NULL_REF)
	if code != &"" or not profiles._matches(profile, Profiles.MODE_WORK, posture, -1) \
			or Vector3i(profiles._pose.x, profiles._pose.y, profiles._pose.z) != _location.point \
			or profiles._pose.yaw != _world_yaw(): return code if code != &"" else REFUSE_WORKER
	code = _profile_geometry(profile)
	if code == &"": code = _occupancy_leaf(worker, profile)
	return Workpieces.source_leaf_refusal(actual, _placement, _project) if code == &"" else code


func _worker_retreat_leaf(worker: Vector2i, job: Vector2i) -> StringName:
	"""The explicit retreat certificate must fit this worker's current equipped tool and carried load."""
	if not _fragments.spend(256):
		return REFUSE_CAPACITY
	var profiles: Profiles = _placements._profiles
	var profile: int = _frontier._travel_profile[_install[8]]
	var mode: int = profiles._field(profiles._live, profile, Profiles.F_MODE)
	var posture: int = profiles._field(profiles._live, profile, Profiles.F_POSTURE)
	var family: int = -1
	if mode == Profiles.MODE_CLIMB:
		family = Catalog._v(_placements._catalog._live, _order.catalog_row, Catalog.V_FAMILY)
	var code: StringName = _prepare_dynamic_leaf(worker, job, mode, posture, family, _selection.tool)
	return code if code != &"" else &"" if profiles._matches(profile, mode, posture, family) else REFUSE_PROFILE


func _dynamic_selection(row: int, worker: Vector2i, job: Vector2i, out: Profiles.Selection) -> StringName:
	"""Populate selection from direct actual leaves; no public identity/pose/equipment reader runs here."""
	if not _fragments.spend(256):
		return REFUSE_CAPACITY
	var profiles: Profiles = _placements._profiles
	var graph: Routes = _placements._routes
	var profile: int = graph._motion.resident[Routes.R_PROFILE * Routes.RESIDENT_CAPACITY + row]
	var mode: int = graph._motion.resident[Routes.R_MODE * Routes.RESIDENT_CAPACITY + row]
	var posture: int = graph._motion.resident[Routes.R_POSTURE * Routes.RESIDENT_CAPACITY + row]
	var family: int = graph._motion.resident[Routes.R_FAMILY * Routes.RESIDENT_CAPACITY + row]
	if profile < 0 or profile >= profiles._live.header[1] or profiles._live.flags[profile] != Profiles.CERT_REQUIRED \
			or graph._motion.resident_long[Routes.R_PROFILE_REVISION * Routes.RESIDENT_CAPACITY + row] != profiles._live.quantities[profile] \
			or graph._motion.resident_long[Routes.R_CONTENT_REVISION * Routes.RESIDENT_CAPACITY + row] != profiles._live.header[0]:
		return REFUSE_PROFILE
	var code: StringName = _prepare_dynamic_leaf(worker, job, mode, posture, family, graph._resident_pair(Routes.R_TOOL_SLOT, row))
	if code != &"" or not profiles._matches(profile, mode, posture, family):
		return code if code != &"" else REFUSE_PROFILE
	profiles._write_selection(profile, worker, job, out)
	return &""


func _prepare_dynamic_leaf(worker: Vector2i, job: Vector2i, mode: int, posture: int,
		family: int, hint: Vector2i) -> StringName:
	"""Reuse Profiles scratch while deriving current facts directly after all observation callbacks."""
	if mode < Profiles.MODE_STAND or mode > Profiles.MODE_CLIMB or posture < 0 \
			or posture > Profiles.POSTURE_STOOPED or family < -1 or family >= 5:
		return REFUSE_PROFILE
	var code: StringName = _dynamic_identity_leaf(worker)
	if code != &"": return code
	var profiles: Profiles = _placements._profiles
	profiles._query_values.fill(-1)
	profiles._candidate.tool = NULL_REF
	profiles._candidate.satchel = NULL_REF
	profiles._candidate.cargo = NULL_REF
	profiles._candidate.cargo_quantity_milli = 0
	code = _dynamic_job_leaf(worker, job, mode)
	if code == &"": code = _dynamic_tool_leaf(worker, job, mode, hint)
	return _dynamic_cargo_leaf(worker) if code == &"" else code


func _dynamic_identity_leaf(worker: Vector2i) -> StringName:
	"""Full Directory and mirrored Resident identity precede actual species/rig and persistent Transform reads."""
	var residents: Residents = _placements._residents
	var row: int = _dynamic_directory_row(worker, Directory.KIND_RESIDENT)
	if row < 0 or row >= Routes.RESIDENT_CAPACITY or residents._present[row] != 1 \
			or residents._ref_slot[row] != worker.x or residents._ref_generation[row] != worker.y \
			or residents._needs._present[row] != 1 or residents._needs._health[row] <= 0 \
			or residents._catalog_error != "" or residents._rig_catalog_error != "" \
			or residents._life_stage[row] != Residents.LIFE_STAGE_ADULT:
		return REFUSE_WORKER
	var species: int = residents._species[row]
	if species < 0 or species >= residents._species_key.size(): return REFUSE_PROFILE
	var key: StringName = StringName(residents._species_key[species])
	if not Residents.SPECIES_RIG_KEY.has(key): return REFUSE_PROFILE
	var rig: StringName = Residents.SPECIES_RIG_KEY[key] as StringName
	if not residents._rig_ids.has(rig): return REFUSE_PROFILE
	var profiles: Profiles = _placements._profiles
	profiles._worker_row = row
	profiles._identity[0] = species
	profiles._identity[1] = residents._life_stage[row]
	profiles._identity[2] = int(residents._rig_ids[rig])
	return _dynamic_pose_leaf(worker, row)


func _dynamic_directory_row(ref: Vector2i, kind: int) -> int:
	"""The final leaf checks full identity and the reverse typed owner directly, without Directory observers."""
	var ids: Directory = _placements._ids
	if ref.x < 0 or ref.x >= Directory.DIRECTORY_CAPACITY or ids._active[ref.x] != 1 \
			or ids._generation[ref.x] != ref.y or ids._kind[ref.x] != kind:
		return -1
	var row: int = ids._typed_row[ref.x]
	return row if row >= 0 and row < Directory.KIND_CAPACITY[kind] \
		and ids._typed_owner_slot[ids._kind_base[kind] + row] == ref.x else -1


func _dynamic_pose_leaf(worker: Vector2i, resident_row: int) -> StringName:
	"""A reused typed row cannot inherit another full resident's pose; no read_into observer is dispatched."""
	var transforms: Transforms = _placements._transforms
	var row: int = Transforms.POSITIONED_BASE[Directory.KIND_RESIDENT] + resident_row
	var pid: int = _placements._ids._persistent_id[worker.x]
	if pid <= 0 or row < 0 or row >= Transforms.TRANSFORM_CAPACITY \
			or transforms._bound_persistent_id[row] != pid or transforms._yaw[row] < 0 or transforms._yaw[row] >= 65536:
		return REFUSE_WORKER
	var profiles: Profiles = _placements._profiles
	profiles._pose.x = transforms._x[row]
	profiles._pose.y = transforms._y[row]
	profiles._pose.z = transforms._z[row]
	profiles._pose.yaw = transforms._yaw[row]
	return &""


func _dynamic_job_leaf(worker: Vector2i, job: Vector2i, mode: int) -> StringName:
	"""Read both actual Job and generation-safe resident-agent links without requester or worker observers."""
	if job == NULL_REF: return REFUSE_WORKER if mode == Profiles.MODE_WORK else &""
	var ids: Directory = _placements._ids
	var jobs: Jobs = _placements._jobs
	var row: int = _dynamic_directory_row(job, Directory.KIND_JOB)
	var worker_row: int = _placements._profiles._worker_row
	if row < 0 or row >= Jobs.JOB_CAPACITY or jobs._job_present[row] != 1 \
			or jobs._job_ref_slot[row] != job.x or jobs._job_ref_generation[row] != job.y \
			or jobs._worker_slot[row] != worker.x or jobs._worker_generation[row] != worker.y \
			or jobs._agent_present[worker_row] != 1 or jobs._agent_persistent_id[worker_row] != ids._persistent_id[worker.x] \
			or jobs._agent_job_slot[worker_row] != job.x or jobs._agent_job_generation[worker_row] != job.y:
		return REFUSE_WORKER
	if mode == Profiles.MODE_WORK: _placements._profiles._query_values[4] = jobs._kind[row]
	return &""


func _dynamic_tool_leaf(worker: Vector2i, job: Vector2i, mode: int, hint: Vector2i) -> StringName:
	"""An actual Work-bound or hinted lot must be equipped by this resident, and WORK needs its exact live claim."""
	var profiles: Profiles = _placements._profiles
	var row: int = profiles._worker_row
	var work: RefCounted = _placements._work
	var tool: Vector2i = Vector2i(work._tool_lot_slot[row], work._tool_lot_generation[row])
	if tool != NULL_REF and hint != NULL_REF and tool != hint: return REFUSE_WORKER
	if tool == NULL_REF: tool = hint
	if tool == NULL_REF:
		return &"" if _placements._residents._equip_tool_item_id[row] == Residents.NO_TOOL_ITEM else REFUSE_WORKER
	var gear: Gear = _placements._gear as Gear
	var at: int = gear._resolve_row(tool)
	var inventory: Inventory = _placements._inventory
	if at < 0 or tool.x >= inventory._l_capacity or inventory._l_live[tool.x] != 1 \
			or inventory._l_generation[tool.x] != tool.y or inventory._l_container_slot[tool.x] != -1 \
			or gear._equipped[at] != 1 or gear._owner_slot[at] != worker.x or gear._owner_generation[at] != worker.y \
			or _placements._residents._equip_tool_item_id[row] != gear._item_id[at]: return REFUSE_WORKER
	if mode == Profiles.MODE_WORK and (work._tool_job_slot[row] != job.x or work._tool_job_generation[row] != job.y \
			or gear._claim_job_slot[at] != job.x or gear._claim_job_generation[at] != job.y or gear._durability[at] <= 0):
		return REFUSE_WORKER
	profiles._query_values[0] = gear._item_id[at]
	profiles._query_values[1] = gear._manufacture_recipe[at]
	profiles._candidate.tool = tool
	return &""


func _dynamic_cargo_leaf(worker: Vector2i) -> StringName:
	"""The actual resident mirror and full live satchel/lot list must agree; no carried-load observer is called."""
	var profiles: Profiles = _placements._profiles
	var row: int = profiles._worker_row
	var residents: Residents = _placements._residents
	var inventory: Inventory = _placements._inventory
	var satchel: Vector2i = Vector2i(residents._equip_satchel_slot[row], residents._equip_satchel_generation[row])
	if satchel == NULL_REF: return &""
	if satchel.x < 0 or satchel.x >= inventory._c_capacity or inventory._c_live[satchel.x] != 1 \
			or inventory._c_generation[satchel.x] != satchel.y or inventory._c_policy[satchel.x] != Inventory.POLICY_SATCHEL \
			or inventory._c_owner_slot[satchel.x] != worker.x or inventory._c_owner_generation[satchel.x] != worker.y:
		return REFUSE_WORKER
	profiles._candidate.satchel = satchel
	var count: int = inventory._c_lot_count[satchel.x]
	if count == 0: return &"" if inventory._c_first_lot[satchel.x] == -1 else REFUSE_WORKER
	var lot: int = inventory._c_first_lot[satchel.x]
	if count != 1 or lot < 0 or lot >= inventory._l_capacity or inventory._l_live[lot] != 1 \
			or inventory._l_container_slot[lot] != satchel.x or inventory._l_container_generation[lot] != satchel.y \
			or inventory._l_next[lot] != -1 or inventory._l_prev[lot] != -1 or inventory._l_quantity_milli[lot] < 1:
		return REFUSE_WORKER
	profiles._candidate.cargo = Vector2i(lot, inventory._l_generation[lot])
	profiles._candidate.cargo_quantity_milli = inventory._l_quantity_milli[lot]
	profiles._query_values[2] = inventory._l_item_id[lot]
	profiles._query_values[3] = inventory._l_recipe_id[lot]
	return &""


func _copy_descriptor() -> StringName:
	"""Hot proof fills only the exact immutable fields consumed below, directly from the qualified source bank."""
	var profiles: Profiles = _placements._profiles
	var row: int = _station[5]
	if _scope_leaf() != &"" or row < 0 or row >= profiles._live.header[1]:
		return REFUSE_PROFILE
	_descriptor.profile_id = row
	_descriptor.profile_revision = profiles._live.quantities[row]
	_descriptor.content_revision = profiles._live.header[0]
	_descriptor.source_id = profiles._field(profiles._live, row, Profiles.F_SOURCE)
	_descriptor.mode = profiles._field(profiles._live, row, Profiles.F_MODE)
	_descriptor.posture = profiles._field(profiles._live, row, Profiles.F_POSTURE)
	_descriptor.tool_item = profiles._field(profiles._live, row, Profiles.F_TOOL)
	profiles._write_descriptor_geometry(row, _descriptor)
	return _descriptor_leaf()


func _descriptor_leaf() -> StringName:
	"""No callback-sized or substituted Descriptor can reduce the complete source box census or work contact."""
	var profiles: Profiles = _placements._profiles
	var row: int = _station[5]
	if row < 0 or row >= profiles._live.header[1] or _descriptor.profile_id != row \
			or _descriptor.content_revision != _frontier._header[5] or _descriptor.profile_revision != _profile_revision \
			or profiles._live.quantities[row] != _profile_revision or profiles._live.flags[row] != Profiles.CERT_REQUIRED \
			or _descriptor.box_count != profiles._field(profiles._live, row, Profiles.F_BOX_COUNT):
		return REFUSE_PROFILE
	if profiles._field(profiles._live, row, Profiles.F_SOURCE) != _frontier._header[7] \
			or profiles._field(profiles._live, row, Profiles.F_MODE) != Profiles.MODE_WORK \
			or profiles._field(profiles._live, row, Profiles.F_WORK_KIND) != Jobs.JOB_KIND_BUILD \
			or profiles._field(profiles._live, row, Profiles.F_TOOL) < 0 \
			or profiles._field(profiles._live, row, Profiles.F_TOOL) != _tool_item() \
			or profiles._field(profiles._live, row, Profiles.F_POSTURE) != _station[6] \
			or profiles._field(profiles._live, row, Profiles.F_YAW_KIND) != Profiles.YAW_EXACT \
			or profiles._field(profiles._live, row, Profiles.F_YAW) != _world_yaw() \
			or profiles._field(profiles._live, row, Profiles.F_CONTACT_KIND) != Profiles.CONTACT_ANCHOR_AND_PATCH:
		return REFUSE_PROFILE
	return &""


func _tool_item() -> int:
	"""The actual loaded Items source names the BUILD tool before any Gear row has populated its lazy ID cache."""
	return int(_placements._recipes._items._item_ids.get(&"tool", -1))


func _world_yaw() -> int:
	"""RoomConnectors quarter turn maps local -Z to +X, the negative quarter of Routes' yaw convention."""
	return (_station[4] + (4 - _frame[3]) * 16384) % 65536


func _scene_leaf() -> StringName:
	"""Exact live source/claim facts remain current even when geometry revision numbers have not changed."""
	var owner: Owner = _placements._space
	var code: StringName = _geometry_context_leaf()
	if code != &"" or not _fragments.spend(2 * (owner._region_capacity + owner._source_capacity)):
		return code if code != &"" else REFUSE_CAPACITY
	var checks: int = FinalFacts._required_checks(owner)
	if not _fragments.spend(checks):
		return REFUSE_CAPACITY
	code = FinalFacts._sources_refusal(owner, _placements._routes, _placements._locations)
	return FinalFacts._claims_refusal(owner) if code == &"" else code


func _geometry_context_leaf() -> StringName:
	"""Only this exact sealed installation may coexist with a final read of its unchanged live predecessors."""
	var owner: Owner = _placements._space
	var graph: Routes = _placements._routes
	var locations: Locations = _placements._locations
	if owner._stage_token == 0:
		return FinalFacts._binding_refusal(owner, graph, locations, _geometry_revision)
	if _phase_mode:
		var code: StringName = _prepared_phase_leaf(_phase_space_token, _phase_companion_token)
		return _phase_geometry_leaf() if code == &"" else code
	if _workpiece_owner() != null:
		var code: StringName = _workpiece_context_leaf()
		if code != &"": return code
	elif _action != Contract.COMMIT:
		return REFUSE_SCOPE
	if _placements._prepared_placement != _placement \
			or _placements._prepared_project != _project or _placements._prepared_assembly != _ordinal \
			or _placements._cold_token <= 0 or not _placements._budget.covers(_placements._cold_token, _placements._cold_bytes) \
			or owner._stage_token != _placements._space_token or not owner._sealed \
			or locations._token != _placements._location_token or not locations._sealed \
			or graph._token != _placements._route_token or not graph._sealed \
			or graph._in_callback or graph._advancing or graph._searching or graph._occupancy_reading \
			or locations._in_retention or owner._room_callback or owner._validation_sources >= 0 \
			or owner._validation_regions >= 0 or owner._header[17] != _geometry_revision:
		return REFUSE_SCOPE
	return &"" if FinalFacts._location_binding(locations, owner) \
		and FinalFacts._same_domain(owner._domain, locations._domain) \
		and FinalFacts._same_domain(owner._domain, graph._domain) else REFUSE_BINDING


func _occupancy_leaf(worker: Vector2i, source_profile: int = -1) -> StringName:
	"""Current committed actor loads and actual poses can change without graph receipts, so every candidate is fresh."""
	var graph: Routes = _placements._routes
	if not _fragments.spend(16 * Routes.RESIDENT_CAPACITY):
		return REFUSE_CAPACITY
	for row: int in Routes.RESIDENT_CAPACITY:
		var other: Vector2i = graph._resident_ref(row)
		if other == NULL_REF:
			if graph._residents.is_alive(row):
				return &"CONNECTOR_CONTACT_ACTOR_UNBOUND"
			continue
		if other == worker:
			continue
		if not _placements._ids.is_valid_of_kind(other, Directory.KIND_RESIDENT) \
				or _placements._ids.get_typed_row(other) != row:
			return REFUSE_WORKER
		var code: StringName = _dynamic_selection(row, other, graph._resident_pair(Routes.R_JOB_SLOT, row), _selection)
		if code != &"" or not graph._committed_selection(row, _selection):
			return code if code != &"" else REFUSE_WORKER
		code = _occupant_boxes(source_profile)
		if code != &"":
			return code
	return &""


func _occupant_boxes(source_profile: int = -1) -> StringName:
	"""Full current body/recovery volumes block all productive and nonproductive installation motion."""
	for ordinal: int in _profile_box_count(source_profile):
		if not _read_profile_box(ordinal, _box, source_profile):
			return REFUSE_CAPACITY
		if _box.role == Profiles.STANCE_SUPPORT or _box.role == Profiles.CONTACT_POINT or _box.role == Profiles.CONTACT_PATCH:
			continue
		var code: StringName = _profile_bounds(_box, _bounds)
		if code != &"":
			return code
		for other: int in _selection.box_count:
			if not _fragments.spend(8):
				return REFUSE_CAPACITY
			if _occupant_overlap(other):
				return &"CONNECTOR_CONTACT_OCCUPIED"
	return &""


func _occupant_overlap(ordinal: int) -> bool:
	"""Compare int64 translated half-open bounds directly; narrowing cannot hide an outside actor."""
	var profiles: Profiles = _placements._profiles
	var at: int = profiles._field(profiles._live, _selection.profile_id, Profiles.F_FIRST_BOX) + ordinal
	var role: int = profiles._live.boxes[6 * profiles._box_capacity + at]
	if role != Profiles.BODY_HELD_LOAD and role != Profiles.TURN_RECOVERY:
		return false
	for axis: int in 3:
		var position: int = _selection.x if axis == 0 else _selection.y if axis == 1 else _selection.z
		var low: int = position + int(profiles._live.boxes[axis * profiles._box_capacity + at])
		var high: int = position + int(profiles._live.boxes[(axis + 3) * profiles._box_capacity + at])
		if low >= _bounds[axis + 3] or high <= _bounds[axis]:
			return false
	return true


func phase_observe_refusal(placement: Vector2i, site: Vector2i, episode: int, operation: int,
		stage: int, cold_token: int = 0, space_token: int = 0) -> StringName:
	"""Observe one actual excavation episode in the same packet; no observer creates a Site, Job or permit."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = _pin_phase_scope(placement, site, episode, operation, stage, cold_token, space_token)
	if code == &"" and _action != Contract.PRODUCTIVE:
		code = _observe_live()
	if code == &"":
		code = _cancel_proof() if _action == Contract.CANCEL else _resolve_proof(_phase_needs_worker())
	_valid = code == &""
	return _leave(code)


func _phase_action(stage: int) -> int:
	"""Translate the distinct public excavation stage namespace explicitly, never by numeric coincidence."""
	match stage:
		PhaseContract.STAGE_ADMIT: return Contract.ADMIT
		PhaseContract.STAGE_START: return Contract.START
		PhaseContract.STAGE_COMMIT: return Contract.COMMIT
		PhaseContract.STAGE_CANCEL: return Contract.CANCEL
		PhaseContract.STAGE_WORK: return Contract.PRODUCTIVE
		PHASE_CONTACT_ONLY: return -1
	return -2


func _pin_phase_scope(placement: Vector2i, site: Vector2i, episode: int, operation: int,
		stage: int, cold_token: int, space_token: int) -> StringName:
	"""Exact original Site and immutable episode facts precede any source observer or copied output use."""
	_valid = false
	_phase_mode = true
	_primary_job = NULL_REF
	_material_container = NULL_REF
	_phase_output_container = NULL_REF
	if not _configured or _binding_leaf() != &"" or _phase_action(stage) == -2 \
			or operation < PhaseContract.OP_BRACE or operation > PhaseContract.OP_FINISH \
			or site.y != Sites.SITE_GENERATION or site.x < 0 or site.x >= _sites._count or _sites._present[site.x] != 1:
		return REFUSE_SCOPE
	_placement = placement
	_phase_site = site
	_phase_operation = operation
	_phase_episode = episode
	_phase_cold_token = cold_token
	_phase_space_token = space_token
	_phase_companion_token = 0
	_project = Vector2i(_sites._project_slot[site.x], _sites._project_generation[site.x])
	_action = _phase_action(stage)
	_geometry_revision = _placements._space._header[17]
	_frontier_revision = _frontier._header[0]
	_fragments.remaining = _placements._space._domain._checks
	_fragments.failed = false
	var code: StringName = _phase_token_leaf()
	return _observe_phase_rows() if code == &"" else code


func _observe_phase_rows() -> StringName:
	"""Mutable observation outputs are checked against their actual sources before reuse or indexing."""
	var code: StringName = _placements.placement_into(_placement, _order)
	if code != &"" or _order.project != NULL_REF: return REFUSE_SCOPE
	_ordinal = _order.installed_count
	code = _placements.placement_frame_into(_placement, _frame)
	if code == &"": code = _frontier.episode_into(_phase_episode, _episode)
	if code != &"" or _poisoned or not _packet_shapes_match(): return REFUSE_SOURCE
	if _phase_token_leaf() != &"": return REFUSE_SCOPE
	_install[0] = _ordinal
	_install[1] = _episode[7 + _phase_operation]
	_install[2] = -1
	_install[3] = _episode[11]; _install[4] = _episode[12]
	_install[5] = _episode[13]; _install[6] = _episode[14]
	_install[7] = _episode[15]; _install[8] = _episode[17]
	code = _frontier.station_into(_install[1], _station, _number, _frame[3])
	_profile_revision = _number.value
	if code == &"": code = _scope_leaf()
	if code == &"" and _project != NULL_REF:
		_primary_job = Vector2i(_sites._job_slot[_phase_site.x], _sites._job_generation[_phase_site.x])
		_phase_output_container = Vector2i(_sites._output_slot[_phase_site.x], _sites._output_generation[_phase_site.x])
		code = _pin_material()
	return _copy_descriptor() if code == &"" else code


func _phase_token_leaf() -> StringName:
	"""A cold observation retains the original real arena; a numeric prepared token supplies no permission."""
	if _phase_cold_token < 0 or _phase_space_token < 0:
		return REFUSE_SCOPE
	if _phase_cold_token > 0 and not _placements._budget.covers(_phase_cold_token, CONTROL_BYTES):
		return REFUSE_SCOPE
	if _phase_space_token != 0 or _phase_companion_token != 0 or _placements._space._stage_token != 0:
		return _prepared_phase_leaf(_phase_space_token, _phase_companion_token)
	return &""


func bind_prepared_phase(placement: Vector2i, site: Vector2i, operation: int, stage: int,
		cold_token: int, space_token: int, companion_token: int) -> StringName:
	"""Attach the actual sealed context to the existing live observation; no endpoint or route is re-observed."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = REFUSE_SCOPE
	if _valid and _phase_mode and placement == _placement and site == _phase_site \
			and operation == _phase_operation and _phase_action(stage) == _action \
			and cold_token > 0 and cold_token == _phase_cold_token \
			and (_phase_space_token == 0 or _phase_space_token == space_token) \
			and (_phase_companion_token == 0 or _phase_companion_token == companion_token):
		code = _prepared_phase_leaf(space_token, companion_token)
	if code != &"": return _leave(code)
	var old_space: int = _phase_space_token
	var old_companion: int = _phase_companion_token
	_phase_space_token = space_token
	_phase_companion_token = companion_token
	code = _scope_leaf()
	if code != &"":
		_phase_space_token = old_space
		_phase_companion_token = old_companion
	return _leave(code)


func _prepared_phase_leaf(space_token: int, companion_token: int) -> StringName:
	"""Direct actual issuer controls and the original observed full tuple qualify one sealed phase context."""
	if not _phase_mode or space_token <= 0 or companion_token <= 0 or _phase_cold_token <= 0:
		return REFUSE_PHASE_PREPARED
	var context: Locations.PhaseContext = _placements._phase_context
	var authority: RefCounted = _sites._space.get_ref() if _sites._space != null else null
	if context == null or authority == null or context.placement != _placement or context.site != _phase_site \
			or context.room != _order.corridor or context.project != _project or context.operation != _phase_operation \
			or _phase_action(context.stage) != _action or context.cold_token != _phase_cold_token \
			or context.space_token != space_token or context.location_token != companion_token \
			or context.world != _order.world or context.budget != _placements._budget \
			or context.base_revision != _geometry_revision or context.target_revision != _geometry_revision + 1 \
			or context.profile_revision != _frontier._header[5] \
			or context.catalog_revision != _order.catalog_revision \
			or context.placement_revision != _placements._live.header[Placements.H_REVISION] \
			or _placements._location_token != companion_token or _placements._route_token != context.route_token:
		return REFUSE_PHASE_PREPARED
	var code: StringName = Placements.phase_operation_leaf_refusal(_placements, authority, _phase_site,
		_phase_operation, context.stage, _order.corridor, _project, _phase_cold_token, space_token)
	return _phase_geometry_leaf() if code == &"" else code


func _phase_geometry_leaf() -> StringName:
	"""Sealed original companions preserve live predecessors; query/retention reentry and foreign domains refuse."""
	var owner: Owner = _placements._space
	var graph: Routes = _placements._routes
	var locations: Locations = _placements._locations
	var context: Locations.PhaseContext = _placements._phase_context
	if locations._token != context.location_token or not locations._sealed or graph._token != context.route_token \
			or not graph._sealed or _placements._world_routes._route_token != context.route_token \
			or not _placements._world_routes._sealed or _placements._world_routes._proof != null \
			or graph._in_callback or graph._advancing or graph._searching or graph._occupancy_reading \
			or locations._in_retention or owner._room_callback or owner._validation_sources >= 0 \
			or owner._validation_regions >= 0:
		return REFUSE_PHASE_PREPARED
	return &"" if FinalFacts._location_binding(locations, owner) \
		and FinalFacts._same_domain(owner._domain, locations._domain) \
		and FinalFacts._same_domain(owner._domain, graph._domain) else REFUSE_BINDING


func _episode_source_leaf() -> StringName:
	"""The normalized reusable selector rows are derived only from the exact pinned EPISODE, never INSTALL."""
	if not _frontier._valid_row(Frontier.EPISODE, _phase_episode) or _phase_operation < 1 or _phase_operation > 3:
		return REFUSE_SOURCE
	for field: int in 19:
		if _episode[field] != _frontier._field(Frontier.EPISODE, _phase_episode, field): return REFUSE_SOURCE
	if _episode[7] != _ordinal or (_episode[6] & (1 << (_phase_operation - 1))) == 0 \
			or _install[0] != _ordinal or _install[1] != _episode[7 + _phase_operation] or _install[2] != -1 \
			or _install[3] != _episode[11] or _install[4] != _episode[12] \
			or _install[5] != _episode[13] or _install[6] != _episode[14] \
			or _install[7] != _episode[15] or _install[8] != _episode[17] \
			or not _frontier._valid_row(Frontier.STATION, _install[1]) or _frame[3] < 0 or _frame[3] > 3:
		return REFUSE_SOURCE
	for field: int in 9:
		if field != 5 and _station[field] != _frontier._field(Frontier.STATION, _install[1], field): return REFUSE_SOURCE
	if _station[5] != _frontier._station_profile(_install[1], _frame[3]) or _station[7] != _episode[18] \
			or _profile_revision != _frontier._profile_revision[_frame[3] * _frontier._capacities[Frontier.STATION] + _install[1]] \
			or _placements._live.header[Placements.H_FRONTIER_REV] != _frontier_revision:
		return REFUSE_SOURCE
	for index: int in 32:
		if _placements._live.digests[96 + index] != _frontier._digests[index]: return REFUSE_SOURCE
	return &""


func _site_scope_leaf() -> StringName:
	"""Full Site/Room/Project and the original lease remain exact without a recursive spatial authority callback."""
	var row: int = _phase_site.x
	if _phase_site.y != Sites.SITE_GENERATION or row < 0 or row >= _sites._count or _sites._present[row] != 1 \
			or _sites._room_slot[row] != _order.corridor.x or _sites._room_generation[row] != _order.corridor.y \
			or Vector2i(_sites._project_slot[row], _sites._project_generation[row]) != _project \
			or (_project != NULL_REF and (_sites._operation[row] != _phase_operation or _project_row() < 0)):
		return REFUSE_SCOPE
	var code: StringName = _phase_token_leaf()
	return _phase_target_into(_target) if code == &"" else code


func _phase_target_into(out: PackedInt32Array) -> StringName:
	"""The permanent sorted Site key selects exactly one whole cube within the immutable authored episode."""
	var key: int = _sites._site_key[_phase_site.x]
	if key < 0 or not _fragments.spend(20): return REFUSE_CAPACITY
	var x: int = key % _sites._domain.size_quanta.x
	@warning_ignore("integer_division") var rest: int = key / _sites._domain.size_quanta.x
	var z: int = rest % _sites._domain.size_quanta.z
	@warning_ignore("integer_division") var y: int = rest / _sites._domain.size_quanta.z
	var coordinate: Vector3i = Vector3i(x, y, z)
	for axis: int in 3:
		var low: int = int(_sites._domain.datum_u[axis]) \
			+ (int(coordinate[axis]) + int(_sites._domain.minimum_quantum[axis])) * 1024
		if not Space.int32(low) or not Space.int32(low + 1024): return REFUSE_SCOPE
		out[axis] = low; out[axis + 3] = low + 1024
	if _site_row(Vector3i(out[0], out[1], out[2])) != _phase_site.x: return REFUSE_SCOPE
	var code: StringName = _world_box(_episode, 0, _scratch)
	return code if code != &"" else &"" if Space.contains_box(_scratch, out) else REFUSE_SCOPE


func _site_project_row(row: int) -> int:
	"""Purpose5 subjects are permanent Site refs; they cannot borrow purpose8's Placement identity."""
	var construction: Construction = _placements._construction
	return row if row >= 0 and row < Construction.CONSTRUCTION_CAPACITY and construction._present[row] == 1 \
		and construction._ref_slot[row] == _project.x and construction._ref_generation[row] == _project.y \
		and construction._purpose[row] == Construction.PURPOSE_EXCAVATION \
		and construction._subject_slot[row] == _phase_site.x and construction._subject_generation[row] == _phase_site.y \
		and construction._type_id[row] == _phase_operation else -1


func _site_job_row(job: Vector2i, row: int) -> int:
	"""A phase has one exact actual bound BUILD Job, no modular party/coordinator or separate mapping."""
	var jobs: Jobs = _placements._jobs
	return row if row >= 0 and row < Jobs.JOB_CAPACITY and jobs._job_present[row] == 1 \
		and jobs._job_ref_slot[row] == job.x and jobs._job_ref_generation[row] == job.y \
		and jobs._requester_slot[row] == _project.x and jobs._requester_generation[row] == _project.y \
		and jobs._kind[row] == Jobs.JOB_KIND_BUILD and jobs._is_coordinator[row] == 0 \
		and jobs._coordinator_slot[row] == -1 and _sites._job_site[row] == _phase_site.x \
		and _sites._job_slot[_phase_site.x] == job.x and _sites._job_generation[_phase_site.x] == job.y else -1


func _site_lifecycle_leaf() -> StringName:
	"""Match current paid phase/pause/work truth immediately before a real worker or payment boundary."""
	if _site_scope_leaf() != &"" or not _sites._operation_allowed(_phase_site.x, _phase_operation): return REFUSE_SCOPE
	if _action == Contract.ADMIT: return &"" if _project == NULL_REF else REFUSE_SCOPE
	var row: int = _project_row()
	if row < 0: return REFUSE_SCOPE
	var construction: Construction = _placements._construction
	var phase: int = construction._phase[row]
	if phase < 0 or phase >= Construction.PHASE_COUNT or construction._remaining_mwu[row] < 0: return REFUSE_SCOPE
	if _action == Contract.CANCEL or _action == -1: return &""
	var job_row: int = _job_row(_primary_job)
	if _phase_needs_worker() and (job_row < 0 or _placements._jobs._tool_gate[job_row] != Jobs.GATE_SATISFIED \
			or _placements._jobs._remaining_mwu[job_row] != construction._remaining_mwu[row]): return REFUSE_WORKER
	if construction._paused[row] != 0: return Construction.REFUSE_PAUSED
	var funding: RefCounted = _sites._funding
	var funded: bool = funding._project_slot[row] == _project.x and funding._project_generation[row] == _project.y
	if _action == Contract.START:
		return &"" if phase == Construction.PHASE_READY and construction._work_begun[row] == 0 and not funded \
			else Construction.REFUSE_WRONG_PHASE
	if not funded or construction._work_begun[row] != 1: return Construction.REFUSE_WRONG_PHASE
	if _action == Contract.COMMIT:
		return &"" if phase == Construction.PHASE_WORK_DONE and construction._remaining_mwu[row] == 0 else Construction.REFUSE_WRONG_PHASE
	return &"" if _action == Contract.PRODUCTIVE and phase == Construction.PHASE_WORKING \
		and construction._remaining_mwu[row] > 0 and job_row >= 0 \
		and _placements._jobs._remaining_mwu[job_row] == construction._remaining_mwu[row] else Construction.REFUSE_WRONG_PHASE


func _phase_needs_worker() -> bool:
	"""Admission is prospective; only START and real productive ticks require the assigned actual worker."""
	return _action == Contract.START or _action == Contract.PRODUCTIVE


func _phase_resolve_output() -> StringName:
	"""The authored output uses a distinct existing storage selector and a real directed certified path."""
	_phase_output_location = _resolve_endpoint(_episode[16])
	if _phase_output_location == NULL_REF: return REFUSE_ENDPOINT
	var code: StringName = _read_endpoint(_episode[16], _phase_output_location, _other)
	if code != &"" or _other.role != Locations.ROLE_STORAGE: return REFUSE_MATERIAL
	_phase_output_payload = _other.payload_revision
	return _path_refusal(_station_location, _phase_output_location, _episode[16])


func _phase_output_receipt() -> StringName:
	"""A payload or full handle change cannot reuse an earlier spoil contact observation."""
	var code: StringName = _read_endpoint(_episode[16], _phase_output_location, _other)
	return code if code != &"" else &"" if _other.payload_revision == _phase_output_payload \
		and _other.role == Locations.ROLE_STORAGE else REFUSE_ENDPOINT


func _phase_output_leaf() -> StringName:
	"""Only adopted CUT output binds a spatial container; zero-output phases retain no invented destination."""
	if _phase_operation != PhaseContract.OP_CUT:
		return &"" if _phase_output_container == NULL_REF else REFUSE_MATERIAL
	if _phase_output_container == NULL_REF:
		return &"" if _action == Contract.ADMIT or _action == -1 or _action == Contract.CANCEL else REFUSE_MATERIAL
	if _action == Contract.START or _action == Contract.PRODUCTIVE or _action == Contract.COMMIT:
		if _phase_output_container != Vector2i(_sites._output_slot[_phase_site.x], _sites._output_generation[_phase_site.x]) \
				or _sites._promotion_tile[_phase_site.x] != -1: return REFUSE_MATERIAL
	return _storage_leaf(_phase_output_container, _phase_output_location, _episode[16])


func _retained_phase_scope(placement: Vector2i, site: Vector2i, operation: int, stage: int) -> StringName:
	"""A final phase call cannot borrow an INSTALL packet or another Site, episode or original action."""
	if not _valid or not _phase_mode or placement != _placement or site != _phase_site \
			or operation != _phase_operation or _phase_action(stage) != _action or _phase_action(stage) == -2:
		return REFUSE_SCOPE
	return _scope_leaf()


func phase_material_refusal(placement: Vector2i, site: Vector2i, operation: int,
		container: Vector2i, job: Vector2i) -> StringName:
	"""Binding and refund contacts consume the exact retained phase observation, not an inferred INSTALL Project."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = _phase_contact_scope(placement, site, operation, job)
	if code == &"":
		_material_container = container
		code = _material_leaf(container)
	return _leave(code if code != &"" else _scope_leaf())


func phase_output_refusal(placement: Vector2i, site: Vector2i, operation: int,
		container: Vector2i, job: Vector2i, promotion_tile: int) -> StringName:
	"""Spoil requires the actual selected spatial storage; a surface tile cannot authorize a deeper output."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = _phase_contact_scope(placement, site, operation, job)
	if code == &"" and (operation != PhaseContract.OP_CUT or promotion_tile != -1): code = REFUSE_MATERIAL
	if code == &"":
		_phase_output_container = container
		code = _phase_output_leaf()
	return _leave(code if code != &"" else _scope_leaf())


func phase_worker_refusal(placement: Vector2i, site: Vector2i, operation: int,
		job: Vector2i, worker: Vector2i) -> StringName:
	"""The current single Site Job and exact selected worker/root/tool/load remain necessary after observation."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = _phase_contact_scope(placement, site, operation, job)
	if code == &"": code = _worker_leaf(job, worker)
	return _leave(code if code != &"" else _scope_leaf())


func _phase_contact_scope(placement: Vector2i, site: Vector2i, operation: int, job: Vector2i) -> StringName:
	"""Material/output/worker hooks are contact facts, not an implicit phase transition or Job allocation."""
	if not _valid or not _phase_mode or placement != _placement or site != _phase_site \
			or operation != _phase_operation or _primary_job != job or _job_row(job) < 0:
		return REFUSE_SCOPE
	_fragments.remaining = _placements._space._domain._checks
	_fragments.failed = false
	var code: StringName = _scope_leaf()
	if code == &"": code = _site_lifecycle_leaf()
	return _receipt_leaf() if code == &"" else code


func phase_final_observation_refusal(placement: Vector2i, site: Vector2i, operation: int, stage: int) -> StringName:
	"""Finish ordinary observers before the direct phase leaf; sealed companions use the retained endpoint payload."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = _retained_phase_scope(placement, site, operation, stage)
	if code == &"" and _action != Contract.CANCEL: code = _profile_refusal()
	if code == &"" and _phase_needs_worker(): code = _observe_workers()
	if code == &"" and _station_location != NULL_REF and _placements._locations._token == 0:
		code = _placements._locations.read_location_into(_station_location, _other)
	return _leave(code if code != &"" else _scope_leaf())


func phase_final_leaf_refusal(placement: Vector2i, site: Vector2i, operation: int, stage: int) -> StringName:
	"""No observer or allocation follows this exact actual live phase/worker/output/source proof."""
	if not _enter(): return REFUSE_REENTRY
	var code: StringName = _retained_phase_scope(placement, site, operation, stage)
	if code == &"":
		_fragments.remaining = _placements._space._domain._checks
		_fragments.failed = false
		code = _site_lifecycle_leaf()
	if code == &"" and (_action != Contract.CANCEL or _material_container != NULL_REF): code = _receipt_leaf()
	if code == &"" and _action != Contract.CANCEL: code = _physical_leaf()
	if code == &"" and _phase_needs_worker(): code = _crew_leaf()
	if code == &"" and _material_container != NULL_REF: code = _material_leaf(_material_container)
	if code == &"" and _action != Contract.CANCEL: code = _phase_output_leaf()
	if code == &"": code = _scene_leaf()
	return _leave(code if code != &"" else _scope_leaf())


func discard_phase(placement: Vector2i, site: Vector2i, operation: int, stage: int) -> void:
	"""Discard only this exact synchronous phase packet; no cold lease or authoritative gameplay row is owned."""
	if not _busy and _phase_mode and placement == _placement and site == _phase_site \
			and operation == _phase_operation and _phase_action(stage) == _action:
		_valid = false
		_primary_job = NULL_REF
		_material_container = NULL_REF
		_phase_output_container = NULL_REF
		_phase_companion_token = 0
		_phase_space_token = 0
