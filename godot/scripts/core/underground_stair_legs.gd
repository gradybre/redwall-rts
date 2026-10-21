extends RefCounted
## Decision 2091 (stair-leg Delivery, decision 1941 §2 item 1; P-2091-3 (a)): the stateless leg helper over M5's
## flight. It plans a loaded mover's way down and an empty mover's way back up as explicit legs, each one published
## edge on one named row, and checks them against the live graph:
## - **down, loaded** (P-2091-5 (a): down-only): from the top H, on every module j above the target landing, the
##   approach (73/79) to A at its L0 position, the eight descents (74/80) to its sill and onto landing j+1's F, and the
##   walk-off (73/79 again, decision 1981 W1/S1) to F'; between modules, the loaded ground join F'(j) -> H'(j) on the
##   item's ground CARRY row (32/37), straight down the flight's centre line, so no loaded turn is needed. Optional
##   ground legs join a source stand to H and the last F' to a destination stand;
## - **up, empty**: from the target landing's F' to the crossing arrival X, the stair path's own `hops_up_from_walk_off`
##   (the back-up 72, the floor half-turn 55, the ascents 54, the turning spot R' on 45/47 at every landing,
##   P-2045-11 (a)).
## Rows come from the grip certificate's item family, never a literal quantity (1941 §2; 2b-2 adds earth's family).
## Each leg is one static edge certificate, as Contacts' `_row_path_refusal` checks a stair leg, but every leg is
## matched in **one pass** over the live edge table (decision 2091 F5) and by mode too: a stair descent's WALK edge and
## its CARRY twin join the same two stops (`StairPath._joined`). A leg is matched to the first live edge, in row
## order, with its stops and mode whose metadata reads, as Contacts' scan takes the first. The scan charges one check
## a row, as Contacts' does, and one a leg.
## A leg list is a PackedInt32Array of LEG_WORDS words a leg: from (slot, generation), to (slot, generation), row.

const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const StairPins := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const LEG_WORDS: int = 5
## Positions in a family's six stair carry rows (decision 1981: approach, descent, ascent, half-turn, retreat,
## back-up; `StairPins.STAIR_CARRY_WOOD_ROWS` 73-78, stone 79-84).
const APPROACH: int = 0
const DESCENT: int = 1
## Decision 1981: eight loaded descents a module (L0 position to T0, T0..T5 to the sill, the sill onto the floor).
const DESCENTS: int = StairPath.SILL_LEVEL + 2
const REFUSE_ITEM: StringName = &"STAIR_LEGS_UNCERTIFIED_ITEM"
const REFUSE_LANDING: StringName = &"STAIR_LEGS_LANDING"
const REFUSE_STOP: StringName = &"STAIR_LEGS_STOP"
const REFUSE_SHAPE: StringName = &"STAIR_LEGS_SHAPE"
const REFUSE_BUDGET: StringName = &"STAIR_LEGS_CHECKS"
const REFUSE_OWNER: StringName = &"STAIR_LEGS_OWNER"
## Contacts' word for a leg no live edge joins (`underground_connector_contacts.gd` `_row_path_refusal`).
const REFUSE_UNJOINED: StringName = &"ROUTE_NOT_CONNECTED"


static func stair_rows(item: int) -> PackedInt32Array:
	"""The item's six stair carry rows by its grip family (wood 73-78, stone 79-84), or none for an uncertified item."""
	match Grip.family_of(Grip.carry_row_for(item)):
		0: return StairPins.STAIR_CARRY_WOOD_ROWS
		1: return StairPins.STAIR_CARRY_STONE_ROWS
	return PackedInt32Array()


static func leg_count(legs: PackedInt32Array) -> int:
	"""Legs in a list."""
	@warning_ignore("integer_division") var count: int = legs.size() / LEG_WORDS
	return count


static func from_of(legs: PackedInt32Array, leg: int) -> Vector2i:
	"""A leg's start stop."""
	return Vector2i(legs[LEG_WORDS * leg], legs[LEG_WORDS * leg + 1])


static func to_of(legs: PackedInt32Array, leg: int) -> Vector2i:
	"""A leg's end stop."""
	return Vector2i(legs[LEG_WORDS * leg + 2], legs[LEG_WORDS * leg + 3])


static func row_of(legs: PackedInt32Array, leg: int) -> int:
	"""A leg's row."""
	return legs[LEG_WORDS * leg + 4]


static func _append(out: PackedInt32Array, from: Vector2i, to: Vector2i, row: int) -> bool:
	"""Add one leg; false when either stop is not live."""
	if from == NULL_REF or to == NULL_REF: return false
	out.append(from.x)
	out.append(from.y)
	out.append(to.x)
	out.append(to.y)
	out.append(row)
	return true


static func loaded_down_into(stops: StairPath.Stops, item: int, landing: int, out: PackedInt32Array,
		source_stand: Vector2i = NULL_REF, destination_stand: Vector2i = NULL_REF) -> StringName:
	"""The loaded way from H down to landing `landing`'s F' (1..MODULES), module by module; with a source stand, a
	first ground leg from it to H, and with a destination stand, a last ground leg from that F' to it, both on the
	item's ground CARRY row. A loaded mover keeps the heading it lifted at (no loaded turn), so both stands must be
	yaw-0 grips, facing down the flight (decision 2092 G0); this plan cannot see a stand's yaw, and an edge that does
	not exist refuses at resolution. `out` is cleared, and left empty on a refusal."""
	out.clear()
	var rows: PackedInt32Array = stair_rows(item)
	if rows.is_empty(): return REFUSE_ITEM
	if stops == null or landing < 1 or landing > StairPath.MODULES: return REFUSE_LANDING
	var ground: int = Grip.carry_row_for(item)
	var ok: bool = source_stand == NULL_REF or _append(out, source_stand, stops.hm[0], ground)
	for module: int in landing:
		if not ok: break
		ok = _module_down(stops, module, rows, out)
		if ok and module + 1 < landing: ok = _append(out, stops.fp[module + 1], stops.hm[module + 1], ground)
	if ok and destination_stand != NULL_REF: ok = _append(out, stops.fp[landing], destination_stand, ground)
	if not ok: out.clear()
	return &"" if ok else REFUSE_STOP


static func _module_down(stops: StairPath.Stops, module: int, rows: PackedInt32Array, out: PackedInt32Array) -> bool:
	"""Module `module`'s loaded legs: its H (H' below module 0) to A at its L0 position on the approach, the eight
	descents onto landing module + 1's F, and the walk-off to its F' on the approach row again (decision 1981 W1)."""
	var top: int = StairPath.global_level(module, -1) + 1
	var ok: bool = _append(out, stops.hm[module], stops.a[top], rows[APPROACH])
	for step: int in DESCENTS - 1:
		if ok: ok = _append(out, stops.a[top + step], stops.a[top + step + 1], rows[DESCENT])
	var floor_stop: Vector2i = stops.f[module + 1]
	if ok: ok = _append(out, stops.a[top + DESCENTS - 1], floor_stop, rows[DESCENT])
	return ok and _append(out, floor_stop, stops.fp[module + 1], rows[APPROACH])


static func empty_up_into(stops: StairPath.Stops, landing: int, out: PackedInt32Array) -> StringName:
	"""The empty way from landing `landing`'s F' up to the crossing arrival X: the stair path's own hops (the walk the
	entry crew takes, decision 1940 and P-2045-11 (a)). `out` is cleared, and left empty on a refusal."""
	out.clear()
	if stops == null or landing < 1 or landing > StairPath.MODULES: return REFUSE_LANDING
	var at: Vector2i = stops.fp[landing]
	var ok: bool = true
	for hop: Array in StairPath.hops_up_from_walk_off(stops, landing):
		if not ok: break
		var next: Vector2i = hop[0]
		ok = _append(out, at, next, int(hop[1]))
		at = next
	if not ok: out.clear()
	return &"" if ok else REFUSE_STOP


static func _spend(remaining: PackedInt32Array, cost: int) -> bool:
	"""Charge `cost` checks to the caller's allowance; an exhausted allowance stays exhausted."""
	if remaining.size() != 1 or remaining[0] < cost:
		if remaining.size() == 1: remaining[0] = -1
		return false
	remaining[0] -= cost
	return true


static func _order_by_from(legs: PackedInt32Array, order: PackedInt32Array) -> void:
	"""Leg indices sorted by their start slot (stable insertion sort; a list holds a few dozen legs)."""
	order.clear()
	for leg: int in leg_count(legs):
		var at: int = order.size()
		order.append(leg)
		while at > 0 and legs[LEG_WORDS * order[at - 1]] > legs[LEG_WORDS * leg]:
			order[at] = order[at - 1]
			at -= 1
		order[at] = leg


static func _first_from(legs: PackedInt32Array, order: PackedInt32Array, slot: int) -> int:
	"""The first position in `order` whose leg starts at `slot`, or order.size() when none does."""
	var low: int = 0
	var high: int = order.size()
	while low < high:
		@warning_ignore("integer_division") var middle: int = (low + high) / 2
		if legs[LEG_WORDS * order[middle]] < slot: low = middle + 1
		else: high = middle
	return low


static func resolve_into(routes: Routes, profiles: Profiles, legs: PackedInt32Array, edges_out: PackedInt32Array,
		remaining: PackedInt32Array) -> StringName:
	"""Match every leg to its live edge in one pass over the edge table: `edges_out` gets the edge (slot, generation)
	of each leg, or NULL_REF's words where no live edge with its stops and its row's mode reads. Refuses an empty or
	malformed list (STAIR_LEGS_SHAPE, before anything is charged), the allowance's STAIR_LEGS_CHECKS, or the first
	unmatched leg's ROUTE_NOT_CONNECTED."""
	edges_out.clear()
	if routes == null or profiles == null or profiles._live == null: return REFUSE_OWNER
	var count: int = leg_count(legs)
	if count == 0 or legs.size() % LEG_WORDS != 0: return REFUSE_SHAPE
	var modes: PackedInt32Array = PackedInt32Array()
	for leg: int in count:
		var row: int = row_of(legs, leg)
		if row < 0 or row >= profiles._profile_capacity: return REFUSE_SHAPE
		modes.append(profiles._live.fields[Profiles.F_MODE * profiles._profile_capacity + row])
		edges_out.append(NULL_REF.x)
		edges_out.append(NULL_REF.y)
	if not _spend(remaining, routes._edge_capacity + count): return REFUSE_BUDGET
	var order: PackedInt32Array = PackedInt32Array()
	_order_by_from(legs, order)
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] == 1: _match_edge(routes, row, legs, modes, order, edges_out, edge)
	for leg: int in count:
		if edges_out[2 * leg] < 0: return REFUSE_UNJOINED
	return &""


static func _match_edge(routes: Routes, row: int, legs: PackedInt32Array, modes: PackedInt32Array,
		order: PackedInt32Array, edges_out: PackedInt32Array, edge: Routes.Edge) -> void:
	"""Give live edge `row` to every still-unmatched leg with its stops and mode, once its metadata reads."""
	var stride: int = routes._edge_capacity
	var fields: PackedInt32Array = routes._live.fields
	var from: Vector2i = Vector2i(fields[Routes.E_FROM_SLOT * stride + row],
		fields[Routes.E_FROM_GENERATION * stride + row])
	var to: Vector2i = Vector2i(fields[Routes.E_TO_SLOT * stride + row], fields[Routes.E_TO_GENERATION * stride + row])
	var mode: int = fields[Routes.E_MODE * stride + row]
	var ref: Vector2i = Vector2i(row, fields[Routes.E_GENERATION * stride + row])
	var read: bool = false
	for at: int in range(_first_from(legs, order, from.x), order.size()):
		var leg: int = order[at]
		if legs[LEG_WORDS * leg] != from.x: return
		if edges_out[2 * leg] >= 0 or mode != modes[leg] or from != from_of(legs, leg) or to != to_of(legs, leg):
			continue
		if not read and routes.edge_metadata_into(ref, edge) != &"": return
		read = true
		edges_out[2 * leg] = ref.x
		edges_out[2 * leg + 1] = ref.y


static func certify_refusal(binding: WorldRoutes, profiles: Profiles, legs: PackedInt32Array,
		edges: PackedInt32Array, content_revision: int) -> StringName:
	"""Each resolved leg's published certificate admits its row at the row's loaded revision
	(`WorldRoutes.static_profile_edge_refusal`, a pure read, as Contacts' stair legs are checked)."""
	if binding == null or profiles == null or profiles._live == null: return REFUSE_OWNER
	if legs.size() % LEG_WORDS != 0 or edges.size() != 2 * leg_count(legs): return REFUSE_SHAPE
	for leg: int in leg_count(legs):
		var row: int = row_of(legs, leg)
		var code: StringName = binding.static_profile_edge_refusal(Vector2i(edges[2 * leg], edges[2 * leg + 1]), row,
			profiles._live.quantities[Profiles.L_REVISION * profiles._profile_capacity + row], content_revision)
		if code != &"": return code
	return &""


static func legs_refusal(binding: WorldRoutes, routes: Routes, profiles: Profiles, legs: PackedInt32Array,
		edges_out: PackedInt32Array, remaining: PackedInt32Array) -> StringName:
	"""The whole static check of one leg list: one resolving pass, then every leg's certificate. Like Contacts'
	`_legs_refusal` before its last `_scope_leaf`, it reads no owner scope: the caller (Delivery, the hauler, the
	runner) runs its own scope leaf after it, inside the same operation."""
	var code: StringName = resolve_into(routes, profiles, legs, edges_out, remaining)
	return code if code != &"" else certify_refusal(binding, profiles, legs, edges_out, profiles.content_revision())
