extends RefCounted
## ADR1197: drive the first entry in the real settlement, step by step, and stop at the first missing capability
## with its exact refusal code and gap row. Completed steps stay published; nothing is faked or rolled back.

const Site := preload("res://scripts/core/underground_entry_site.gd")
const WorkArea := preload("res://scripts/core/underground_entry_work_area.gd")
const Foreman := preload("res://scripts/core/underground_entry_foreman.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const SEARCH_RINGS: int = 8
const REFUSE_SCOPE: StringName = &"ENTRY_RUNTIME_SCOPE"
const REFUSE_NO_TOOLED_MOLE: StringName = &"ENTRY_CREW_NO_TOOLED_MOLE"
const REFUSE_INPUTS: StringName = &"ENTRY_INPUTS_NOT_DELIVERED"
const STEP_NONE: int = 0
const STEP_SITE: int = 1
const STEP_PUBLISHED: int = 2
const STEP_CONFIRMED: int = 3
const STEP_CONTAINERS: int = 4
const STEP_CREW: int = 5
const STEP_RUNNING: int = 6
const STEP_DONE: int = 7
## ADR1197 gap rows; an alert names the row that, once built, clears it.
const GAPS: Dictionary = {
	&"ENTRY_SITE_NONE_FOUND": "G1/G2 no surveyed entry site near the settlement",
	&"ENTRY_CREW_NO_TOOLED_MOLE": "G11 no adult mole with an equipped basic tool (tool equipping is not gameplay yet)",
	&"ENTRY_INPUTS_NOT_DELIVERED": "G4 cut inputs must be hauled to underground storage (mole haul activation, ADR 1198)",
	&"ENTRY_FOREMAN_INPUT_LOT": "G4 cut inputs must be hauled to underground storage (mole haul activation, ADR 1198)",
}

var _step: int = STEP_NONE
var _error: StringName = &""
var _origin: Vector3i = Vector3i.ZERO
var _published: WorkArea.Published = WorkArea.Published.new()
var _storage: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF
var _crew: Foreman.Crew = null


static func gap_of(code: StringName) -> String:
	"""The ADR1197 gap row an alert maps to, or an unclassified refusal that needs triage."""
	return GAPS.get(code, "unclassified refusal %s" % code)


func step() -> int:
	"""How far the real chain got."""
	return _step


func error() -> StringName:
	"""The first refusal, or empty."""
	return _error


func origin() -> Vector3i:
	"""The surveyed entry origin once chosen."""
	return _origin


func start(session: RefCounted, near: Vector3i) -> StringName:
	"""Run every not-yet-done step in order; a refusal stops the chain and is retained for alerting."""
	if session == null or session._operations_prefix != 17 or session._operations_state != 2: return _stop(REFUSE_SCOPE)
	var o: RefCounted = session._retirement_owners
	var code: StringName = _choose_site(session, o, near) if _step < STEP_SITE else &""
	if code == &"" and _step < STEP_PUBLISHED: code = _publish(session, o)
	if code == &"" and _step < STEP_CONFIRMED: code = _confirm(session, o)
	if code == &"" and _step < STEP_CONTAINERS: code = _containers(o)
	if code == &"" and _step < STEP_CREW: code = _select_crew(o)
	if code == &"" and _step < STEP_RUNNING: code = _inputs(o)
	return _stop(code) if code != &"" else &""


func _stop(code: StringName) -> StringName:
	"""Retain the first refusal of this attempt."""
	_error = code
	return code


func _choose_site(session: RefCounted, o: RefCounted, near: Vector3i) -> StringName:
	"""Read-only survey of the cube grid around the requested point."""
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var code: StringName = Site.suggest(session._terrain, o.room_bindings._entry_frontier, o.space.revision(),
		near, SEARCH_RINGS, out)
	if code != &"": return code
	_origin = Vector3i(out[0], out[1], out[2])
	_step = STEP_SITE
	return &""


func _publish(session: RefCounted, o: RefCounted) -> StringName:
	"""All nine endpoints, then all 28 paths, through the real SurfaceAnchor and WorldRoutes."""
	var code: StringName = WorkArea.publish_locations(session.surface_anchor(), _origin, _published)
	if code == &"": code = WorkArea.publish_paths(o.world_routes, o.routes, o.budget, o.space, _origin, _published,
		o.profiles.content_revision())
	if code == &"": _step = STEP_PUBLISHED
	return code


func _confirm(session: RefCounted, o: RefCounted) -> StringName:
	"""The EntryPlan comes from the mounted bundle and the published anchor; RoomOrders admits it."""
	var plan: RefCounted = Site.entry_plan(session._world_ref, o.space.revision(), _origin, _published.endpoints[0],
		o.world_routes._catalog, o.room_bindings._entry_frontier)
	if plan == null: return REFUSE_SCOPE
	var result: RefCounted = o.rooms.confirm_entry(plan)
	if not result.ok: return result.error
	_step = STEP_CONFIRMED
	return &""


func _containers(o: RefCounted) -> StringName:
	"""Material storage at M and spoil output at R are real spatial ground-staging containers."""
	var material: RefCounted = o.inventory.create_spatial_ground_staging(_published.endpoints[1])
	if not material.ok: return material.error
	var output: RefCounted = o.inventory.create_spatial_ground_staging(_published.endpoints[2])
	if not output.ok: return output.error
	_storage = material.ref
	_output = output.ref
	_step = STEP_CONTAINERS
	return &""


func _select_crew(o: RefCounted) -> StringName:
	"""The first adult mole holding an equipped tool lot; no tool is created or equipped here."""
	var residents: RefCounted = o.residents
	for row: int in o.gear._row_capacity:
		if o.gear._occupied[row] != 1 or o.gear._equipped[row] != 1: continue
		var owner: Vector2i = Vector2i(o.gear._owner_slot[row], o.gear._owner_generation[row])
		var slot: int = residents.directory().get_typed_row(owner)
		if slot < 0 or not residents.is_present(slot) or residents.species_key(residents.species_of(slot).value) != &"mole":
			continue
		_crew = Foreman.Crew.new()
		_crew.worker = owner
		_crew.tool = Vector2i(o.gear._lot_slot[row], o.gear._lot_generation[row])
		_crew.storage = _storage
		_crew.output = _output
		_step = STEP_CREW
		return &""
	return REFUSE_NO_TOOLED_MOLE


func _inputs(o: RefCounted) -> StringName:
	"""Cut inputs must already sit in underground storage; only a real haul may put them there."""
	return REFUSE_INPUTS if o.inventory.container_lot_count(_storage) == 0 else &""
