extends RefCounted
## ADR1229: the descent's stair edges between the installed stair stops, and the retraction of the one stop a pending
## tread bearer covers. Stateless: every call reads the live Locations and Routes it is handed.
## The stops (all INSTALLED_CONTACT Locations of the bundle, in its source frame) are:
## - X, the crossing arrival on L0 (0, 0, -664), the way between M and the stair;
## - on L0, P (310 u behind its far edge, the walk-in stop), A (169, the descent's start) and U (343, the ascent's end);
## - on each standing tread T_j, A (169, a descent's arrival and the half-turn's start), S (310, the tread station of
##   T_{j+1}) and U (343, the half-turn's end and the ascent's start).
## Its edges are each approved motion over exactly its span (ADR 1209, DEC-050): X->P on the narrow approach,
## P->A(L0) and S->A on the step forward, A->S on the step back, A(j-1)->A(j) on the descent, A->U on the half-turn,
## U(j)->U(j-1) on the ascent and U(L0)->X on the yaw-32768 approach. WorldRoutes decides which rows each edge admits.
## Decision 1972 (decision 1981's stair carry, content 12): once the sill is installed its stops (A and U on T6)
## exist; H on L0 (343 u before A, where a loaded carrier steps on) is the prefix's L0 station. Only then are the
## sill's WALK edges (T5 -> T6 on the descent, T6 -> T5 on the ascent) and every CARRY edge (H -> A(L0), each descent
## down to T6, the half-turn on T6, each ascent up to U(L0), U(L0) -> H) published, so the entry's own chain is
## unchanged until its last tread is in.
## Decision 2044 (M5, decision 2043 P-2043-1 (a)): module j is the same module translated by (0, -1024j, -5120j), its
## L0 position being module j-1's natural run-out (landing j). A stop's global level is 8j + level (level -1 for L0's
## position, 0..6 for T0..T6), so module 0's levels and indices are v10's. Each landing j adds decision 1972's floor
## stops F, U and F' (here F, UF and FP, filed by landing) and, but for the last, module j's H' (its T0's station), P',
## A0' and U0'. P-2044-16 (a) (reversing P-2044-14 (a), whose ground joins at F and U met the sill deck): each landing
## has decision 1972's floor edges, the descent onto F, the floor half-turn F -> U, the ascent from U, and the empty
## walk-off F -> F' (71) and back-up F' -> F (72); a landing is joined to its module at F', where every ground row
## faces down the flight and clears the sill: F' -> P', F' -> H' and F' -> D on the narrow approach 43, H' -> F',
## U0' -> F', P' -> F' and D -> F' on the narrow retreat 47. The stair carry stays module 0's, H to its sill and back
## (decision 1972), until stair-leg Delivery. The deep stations a landing's floor carries for the next layer (2044) are
## joined to D, the hub, by `publish_floor` on the all-yaw claw WALK 42, and leave row by row through `retire_row`.

const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")
const StairPins := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## Global levels a module spans: its L0 position (-1) and T0..T6.
const MODULE_LEVELS: int = Tread.TREADS + 2
const MODULES: int = Tread.MODULES
## Decision 1972: L0 (level -1), T0..T5 and the sill T6 carry stops; decision 2044: five modules of them.
const LEVELS: int = MODULES * MODULE_LEVELS
const SILL_LEVEL: int = Tread.TREADS
## ADR 1142's handoff span (the approach): H stands this far before A on L0.
const HANDOFF_U: int = 343
const CROSSING_Z: int = -664
## Decision 1972's floor stops, `behind` measured from L0's far edge in the next module's frame (F 343, U 169 and F'
## 686 u beyond the sill's far edge, which is 2,560 u behind L0's far edge in that frame).
const FLOOR_ARRIVAL_BEHIND: int = 1193
const FLOOR_ASCENT_BEHIND: int = 1367
const FLOOR_WALK_OFF_BEHIND: int = 850
const REFUSE_LEASE: StringName = &"ENTRY_STAIR_PATH_LEASE"
const REFUSE_OWNER: StringName = &"ENTRY_STAIR_PATH_OWNER"
## Edge kinds in Stops.edges: [from kind, from level, to kind, to level, family].
const KIND_X: int = 0
const KIND_P: int = 1
const KIND_A: int = 2
const KIND_S: int = 3
const KIND_U: int = 4
## Decision 1972: H on L0; decision 2044: H' on a later module's landing (filed by module).
const KIND_H: int = 5
## Decision 2044: a landing's floor stops, filed by landing (1-5).
const KIND_F: int = 6
const KIND_UF: int = 7
const KIND_FP: int = 8
## P-2044-16 (a): the deep hub D on a landing (the landing row's station on the centre line), filed by landing.
const KIND_D: int = 9
## Words per planned edge: [from kind, from level, to kind, to level, family, mode].
const PLAN_WORDS: int = 6
## Decision 2044: the deep stations' floor walks (all-yaw claw WALK) and where a column's stations stand.
const FLOOR_ROW: int = 42


class Stops extends RefCounted:
	## Live stop handles by kind and global level index (level + 1); NULL_REF where the stop is not (yet) live.
	var x: Vector2i = NULL_REF
	var p: Vector2i = NULL_REF
	var h: Vector2i = NULL_REF
	var a: Array[Vector2i] = []
	var s: Array[Vector2i] = []
	var u: Array[Vector2i] = []
	## Decision 2044: H' by module (index 0 is H), and the floor stops by landing (index 0 unused).
	var hm: Array[Vector2i] = []
	var f: Array[Vector2i] = []
	var uf: Array[Vector2i] = []
	var fp: Array[Vector2i] = []
	var d: Array[Vector2i] = []

	func _init() -> void:
		"""Every level starts absent."""
		for index: int in LEVELS:
			a.append(NULL_REF)
			s.append(NULL_REF)
			u.append(NULL_REF)
		for index: int in MODULES + 1:
			hm.append(NULL_REF)
			f.append(NULL_REF)
			uf.append(NULL_REF)
			fp.append(NULL_REF)
			d.append(NULL_REF)

	func at(kind: int, level: int) -> Vector2i:
		"""One stop handle, or NULL_REF: a stair stop by global level, a floor stop by landing, H/H' by level -1 of
		its module."""
		if kind == KIND_X: return x
		if kind == KIND_P and level == -1: return p
		@warning_ignore("integer_division") var module: int = (level + 1) / MODULE_LEVELS
		if kind == KIND_H: return hm[module] if level >= -1 and level < LEVELS - 1 else NULL_REF
		if kind == KIND_F or kind == KIND_UF or kind == KIND_FP or kind == KIND_D:
			if level < 1 or level > MODULES: return NULL_REF
			if kind == KIND_D: return d[level]
			return f[level] if kind == KIND_F else (uf[level] if kind == KIND_UF else fp[level])
		if level < -1 or level >= LEVELS - 1: return NULL_REF
		if kind == KIND_P: return s[level + 1]
		return a[level + 1] if kind == KIND_A else (s[level + 1] if kind == KIND_S else u[level + 1])


static func module_of_level(level: int) -> int:
	"""The module of a global level (level -1 of module j is 8j - 1)."""
	@warning_ignore("integer_division") var module: int = (level + 1) / MODULE_LEVELS
	return module


static func global_level(module: int, level: int) -> int:
	"""Module j's level -1..6 as a global level."""
	return MODULE_LEVELS * module + level


static func classify(point: Vector3i) -> Vector2i:
	"""(kind, level) of a source-local stop point, or (-1, 0) for any other point; a floor stop's level is its
	landing."""
	if point.x != 0: return Vector2i(-1, 0)
	if point.y == 0 and point.z == CROSSING_Z: return Vector2i(KIND_X, -1)
	if point.y > 0 or point.y % Tread.RISE != 0: return Vector2i(-1, 0)
	@warning_ignore("integer_division") var module: int = -point.y / Tread.MODULE_DROP
	var depth: int = -point.y - Tread.MODULE_DROP * module
	@warning_ignore("integer_division") var level: int = depth / Tread.RISE - 1
	if module > MODULES or (module == MODULES and level != -1): return Vector2i(-1, 0)
	var behind: int = point.z + Tread.MODULE_RUN * module - Tread.far_z(level)
	if level < 0 and module > 0 and module < MODULES and behind == Tread.DEEP_INSIDE: return Vector2i(KIND_D, module)
	if level < 0 and module > 0:
		var floor_kind: int = _floor_kind(behind)
		if floor_kind >= 0: return Vector2i(floor_kind, module)
		if module == MODULES: return Vector2i(-1, 0)
	var global: int = global_level(module, level)
	if level < 0 and behind == Tread.ARRIVAL + HANDOFF_U: return Vector2i(KIND_H, global)
	if behind == Tread.ARRIVAL: return Vector2i(KIND_A, global)
	if behind == Tread.ASCENT_START: return Vector2i(KIND_U, global)
	if behind == Tread.STATION: return Vector2i(KIND_P if level < 0 else KIND_S, global)
	return Vector2i(-1, 0)


static func _floor_kind(behind: int) -> int:
	"""A landing's floor stop by its distance behind L0's far edge in the next module's frame, or -1."""
	if behind == FLOOR_ARRIVAL_BEHIND: return KIND_F
	if behind == FLOOR_ASCENT_BEHIND: return KIND_UF
	return KIND_FP if behind == FLOOR_WALK_OFF_BEHIND else -1


static func record(stops: Stops, kind_level: Vector2i, handle: Vector2i) -> void:
	"""File one live stop under its kind and level."""
	var level: int = kind_level.y
	match kind_level.x:
		KIND_X: stops.x = handle
		KIND_P:
			if level == -1: stops.p = handle
			else: stops.s[level + 1] = handle
		KIND_H:
			stops.hm[module_of_level(level)] = handle
			if level == -1: stops.h = handle
		KIND_A: stops.a[level + 1] = handle
		KIND_S: stops.s[level + 1] = handle
		KIND_U: stops.u[level + 1] = handle
		KIND_F: stops.f[level] = handle
		KIND_UF: stops.uf[level] = handle
		KIND_FP: stops.fp[level] = handle
		KIND_D: stops.d[level] = handle


static func edge_plan() -> PackedInt32Array:
	"""Every stair edge as [from kind, from level, to kind, to level, family, mode], in a fixed order: module 0's
	descent WALK edges (ADR 1229), its sill's and the stair carry (decision 1972), then each landing's floor edges and
	each later module's WALK edges (decision 2044)."""
	var walk: int = Profiles.MODE_WALK
	var out: PackedInt32Array = PackedInt32Array([KIND_X, -1, KIND_P, -1, -1, walk, KIND_P, -1, KIND_A, -1, -1, walk,
		KIND_U, -1, KIND_X, -1, -1, walk])
	out.append_array(_module_treads(0))
	out.append_array(_sill(0))
	out.append_array(carry_plan())
	for landing: int in range(1, MODULES + 1):
		out.append_array(_landing(landing))
		if landing < MODULES:
			out.append_array(PackedInt32Array([KIND_P, global_level(landing, -1), KIND_A, global_level(landing, -1), -1,
				walk]))
			out.append_array(_module_treads(landing))
			out.append_array(_sill(landing))
	return out


static func _module_treads(module: int) -> PackedInt32Array:
	"""A module's five WALK edges a tread (ADR 1229), T0..T5."""
	var walk: int = Profiles.MODE_WALK
	var out: PackedInt32Array = PackedInt32Array()
	for local: int in Tread.TREADS:
		var level: int = global_level(module, local)
		out.append_array(PackedInt32Array([KIND_A, level - 1, KIND_A, level, 0, walk,
			KIND_A, level, KIND_S, level, -1, walk, KIND_S, level, KIND_A, level, -1, walk,
			KIND_A, level, KIND_U, level, 0, walk, KIND_U, level, KIND_U, level - 1, 0, walk]))
	return out


static func _sill(module: int) -> PackedInt32Array:
	"""The sill's two WALK edges: T5 -> T6 on the descent, T6 -> T5 on the ascent (decision 1972)."""
	var walk: int = Profiles.MODE_WALK
	var sill: int = global_level(module, SILL_LEVEL)
	return PackedInt32Array([KIND_A, sill - 1, KIND_A, sill, 0, walk, KIND_U, sill, KIND_U, sill - 1, 0, walk])


static func _landing(landing: int) -> PackedInt32Array:
	"""Landing j's floor edges (decision 1972's floor plan, P-2044-16 (a)): the descent onto F, the half-turn F -> U,
	the ascent from U, the walk-off F -> F' and the back-up F' -> F; but for the last landing, the ground joins to
	module j and the deep hub at F': F' -> P', F' -> H' and F' -> D (narrow approach), H' -> F', U0' -> F', P' -> F'
	and D -> F' (narrow retreat)."""
	var walk: int = Profiles.MODE_WALK
	var sill: int = global_level(landing - 1, SILL_LEVEL)
	var out: PackedInt32Array = PackedInt32Array([KIND_A, sill, KIND_F, landing, 0, walk,
		KIND_F, landing, KIND_UF, landing, 0, walk, KIND_UF, landing, KIND_U, sill, 0, walk,
		KIND_F, landing, KIND_FP, landing, 0, walk, KIND_FP, landing, KIND_F, landing, 0, walk])
	if landing == MODULES: return out
	var foot: int = global_level(landing, -1)
	out.append_array(PackedInt32Array([KIND_FP, landing, KIND_P, foot, -1, walk, KIND_FP, landing, KIND_H, foot, -1, walk,
		KIND_H, foot, KIND_FP, landing, -1, walk, KIND_U, foot, KIND_FP, landing, -1, walk,
		KIND_P, foot, KIND_FP, landing, -1, walk, KIND_FP, landing, KIND_D, landing, -1, walk,
		KIND_D, landing, KIND_FP, landing, -1, walk]))
	return out


static func carry_plan() -> PackedInt32Array:
	"""The stair carry, H to the sill and back: H -> A(L0), every descent to T6, the half-turn on T6, every ascent to
	U(L0), U(L0) -> H."""
	var carry: int = Profiles.MODE_CARRY
	var out: PackedInt32Array = PackedInt32Array([KIND_H, -1, KIND_A, -1, 0, carry])
	for level: int in range(0, SILL_LEVEL + 1):
		out.append_array(PackedInt32Array([KIND_A, level - 1, KIND_A, level, 0, carry]))
	out.append_array(PackedInt32Array([KIND_A, SILL_LEVEL, KIND_U, SILL_LEVEL, 0, carry]))
	for level: int in range(SILL_LEVEL, -1, -1):
		out.append_array(PackedInt32Array([KIND_U, level, KIND_U, level - 1, 0, carry]))
	out.append_array(PackedInt32Array([KIND_U, -1, KIND_H, -1, 0, carry]))
	return out


static func _planned(stops: Stops, plan: PackedInt32Array, at: int) -> bool:
	"""Both stops are live, and an edge past module 0's descent (its sill's, a CARRY edge or a later module's) waits
	until module 0's sill arrival A(T6) exists, that is until that sill is installed."""
	if stops.at(plan[at], plan[at + 1]) == NULL_REF or stops.at(plan[at + 2], plan[at + 3]) == NULL_REF: return false
	return at < descent_words() or stops.at(KIND_A, SILL_LEVEL) != NULL_REF


static func descent_words() -> int:
	"""Plan words of module 0's descent WALK edges (X/P/U on L0 and five per tread T0..T5)."""
	return PLAN_WORDS * (3 + 5 * Tread.TREADS)


static func publish(binding: WorldRoutes, routes: Routes, budget: Budget, owner: RefCounted, locations: Locations,
		stops: Stops, content_revision: int) -> StringName:
	"""Stage every planned edge whose two stops are live and which no live edge already joins, then seal and
	publish them once; nothing is staged when every edge exists."""
	if binding == null or routes == null or budget == null or owner == null or locations == null or stops == null:
		return REFUSE_OWNER
	var plan: PackedInt32Array = edge_plan()
	if _missing_count(routes, stops, plan) == 0: return &""
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return REFUSE_LEASE
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = begun.error
	for at: int in range(0, plan.size(), PLAN_WORDS):
		if code != &"": break
		if not _planned(stops, plan, at): continue
		var ends: Array[Vector2i] = [stops.at(plan[at], plan[at + 1]), stops.at(plan[at + 2], plan[at + 3])]
		if _joined(routes, ends[0], ends[1], plan[at + 5]): continue
		code = _stage_edge(routes, begun.token, locations, owner, ends, plan.slice(at + 4, at + 6), content_revision)
	if code == &"": code = binding.seal(begun.token)
	if code == &"": code = binding.publish(begun.token)
	binding.abort(begun.token)
	budget.release(lease)
	return code


static func _missing_count(routes: Routes, stops: Stops, plan: PackedInt32Array) -> int:
	"""Planned edges with both stops live and no live edge between them."""
	var count: int = 0
	for at: int in range(0, plan.size(), PLAN_WORDS):
		if _planned(stops, plan, at) and not _joined(routes, stops.at(plan[at], plan[at + 1]),
				stops.at(plan[at + 2], plan[at + 3]), plan[at + 5]):
			count += 1
	return count


static func _joined(routes: Routes, first: Vector2i, last: Vector2i, mode: int) -> bool:
	"""Whether a live edge of `mode` already runs from `first` to `last` (a WALK edge never hides its CARRY twin)."""
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		if routes.edge_metadata_into(Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row]),
				edge) == &"" and edge.from_location == first and edge.to_location == last and edge.mode == mode:
			return true
	return false


static func _stage_edge(routes: Routes, token: int, locations: Locations, owner: RefCounted, ends: Array[Vector2i],
		family_mode: PackedInt32Array, content_revision: int) -> StringName:
	"""One straight two-point span of the planned family and mode in its start stop's section, Room and level."""
	var first: Locations.Record = _record(locations, ends[0])
	var last: Locations.Record = _record(locations, ends[1])
	if first == null or last == null: return REFUSE_OWNER
	var points: PackedInt32Array = PackedInt32Array([first.point.x, first.point.y, first.point.z,
		last.point.x, last.point.y, last.point.z])
	return routes.stage_add(token, _edge(first, ends, points, family_mode[0], family_mode[1], owner,
		content_revision)).error


static func _edge(first: Locations.Record, ends: Array[Vector2i], points: PackedInt32Array, family: int, mode: int,
		owner: RefCounted, content_revision: int) -> Routes.Edge:
	"""An edge over `points` (a polyline) in the start stop's section, Room and level; its length the polyline's."""
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = ends[0]
	edge.to_location = ends[1]
	edge.section = first.section
	edge.room = first.room
	edge.level = first.level; edge.family = family; edge.variant = 0
	edge.mode = mode; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = content_revision
	edge.geometry_revision = owner.revision()
	@warning_ignore("integer_division") edge.point_count = points.size() / 3
	edge.points = points
	edge.length_u = 0
	for at: int in range(3, points.size(), 3):
		edge.length_u += Routes._segment_length(Vector3i(points[at - 3], points[at - 2], points[at - 1]),
			Vector3i(points[at], points[at + 1], points[at + 2]))
	return edge


static func _record(locations: Locations, ref: Vector2i) -> Locations.Record:
	"""One complete live Location record, or null."""
	var out: Locations.Record = Locations.Record.new()
	out.envelope.resize(6)
	out.support.resize(6)
	return out if locations.read_location_into(ref, out) == &"" else null


static func retract(binding: WorldRoutes, routes: Routes, locations: Locations, budget: Budget,
		stop: Vector2i) -> StringName:
	"""Remove every live edge that starts or ends at `stop`, publish, then remove the stop itself: a pending tread
	bearer is staged where it stands (ADR 1209 step 5). The bundle re-creates it when that tread commits."""
	if binding == null or routes == null or locations == null or budget == null: return REFUSE_OWNER
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return REFUSE_LEASE
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = _stage_incident_removals(routes, begun.token, stop) if begun.error == &"" else begun.error
	if code == &"": code = binding.seal(begun.token)
	if code == &"": code = binding.publish(begun.token)
	binding.abort(begun.token)
	if code == &"": code = _remove_location(locations, lease, stop)
	budget.release(lease)
	return code


static func _stage_incident_removals(routes: Routes, token: int, stop: Vector2i) -> StringName:
	"""Every live edge touching the stop leaves the graph, and so does the ascent leaving the stop its half-turn
	reaches (U on the same tread): that climb starts with the body's tail over the staged bearer."""
	var turned: Vector2i = _turned_from(routes, stop)
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row])
		var code: StringName = routes.edge_metadata_into(ref, edge)
		if code == &"" and (edge.from_location == stop or edge.to_location == stop
				or (turned != NULL_REF and edge.from_location == turned and edge.family == 0)):
			code = routes.stage_remove(token, ref)
		if code != &"": return code
	return &""


static func _turned_from(routes: Routes, stop: Vector2i) -> Vector2i:
	"""The stop a connector edge leads to from `stop` while the tread below is pending: only the half-turn can (the
	descent from it needs the stop below, which that tread's commit creates), or NULL_REF."""
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row])
		if routes.edge_metadata_into(ref, edge) == &"" and edge.from_location == stop and edge.family == 0:
			return edge.to_location
	return NULL_REF


static func _remove_location(locations: Locations, lease: int, stop: Vector2i) -> StringName:
	"""The now-disconnected stop leaves the Locations bank in its own preparation."""
	var begun: Locations.Result = locations.begin_prepare(lease)
	var code: StringName = begun.error
	if code == &"": code = locations.stage_remove(begun.token, stop)
	if code == &"": code = locations.seal(begun.token)
	if code == &"" and not locations.publish(begun.token): code = &"ENTRY_STAIR_PATH_PUBLISH"
	if code != &"": locations.abort(begun.token)
	return code


## Decision 2044: per-edge hops [stop, profile row] along the stair, for the foreman's legs and Contacts' leg-by-leg
## reach proofs. Every hop is one published edge, so a run of hops on one row is one route on that row.


static func hops_down(stops: Stops, level: int) -> Array:
	"""From the crossing arrival X down to A at global `level` (level -1 of a later module: its A0'): P, A0, every
	descent to the sill, onto the floor F, the walk-off to F', then the next module's P' and A0', until the target's
	module (P-2044-16 (a))."""
	var out: Array = [[stops.p, StairPins.CLAW_APPROACH_ROWS[0]], [stops.a[0], StairPins.CLAW_STEP_FORWARD_ROW]]
	var module: int = module_of_level(level)
	for within: int in module:
		_descend(stops, within, SILL_LEVEL, out)
		out.append([stops.f[within + 1], StairPins.CLAW_DESCENT_ROW])
		out.append([stops.fp[within + 1], StairPins.STAIR_EMPTY_FLOOR_ROWS[0]])
		out.append([stops.s[global_level(within + 1, -1) + 1], StairPins.CLAW_APPROACH_ROWS[0]])
		out.append([stops.a[global_level(within + 1, -1) + 1], StairPins.CLAW_STEP_FORWARD_ROW])
	_descend(stops, module, level - global_level(module, 0), out)
	return out


static func hops_down_to_floor(stops: Stops, landing: int) -> Array:
	"""From X down to landing j's floor stop F (module j-1's whole flight, then the descent onto the floor)."""
	var out: Array = hops_down(stops, global_level(landing - 1, SILL_LEVEL))
	out.append([stops.f[landing], StairPins.CLAW_DESCENT_ROW])
	return out


static func hops_down_to_walk_off(stops: Stops, landing: int) -> Array:
	"""From X down to landing j's F', where its ground joins start: onto F, then the walk-off (P-2044-16 (a))."""
	var out: Array = hops_down_to_floor(stops, landing)
	out.append([stops.fp[landing], StairPins.STAIR_EMPTY_FLOOR_ROWS[0]])
	return out


static func _descend(stops: Stops, module: int, last: int, out: Array) -> void:
	"""Module j's descents from its L0 position's A down to its T_last."""
	for local: int in range(0, last + 1):
		out.append([stops.a[global_level(module, local) + 1], StairPins.CLAW_DESCENT_ROW])


static func hops_up(stops: Stops, level: int) -> Array:
	"""From U at global `level` up to X: every ascent to the module's U0, then for a later module the approach to its
	landing's U and the floor's ascent onto the sill below, and so on up to U(L0) and the approach to X."""
	var out: Array = []
	var module: int = module_of_level(level)
	for local: int in range(level - global_level(module, 0) - 1, -2, -1):
		out.append([stops.u[global_level(module, local) + 1], StairPins.CLAW_ASCENT_ROW])
	out.append_array(hops_up_from_landing(stops, module) if module > 0 else [[stops.x, StairPins.CLAW_APPROACH_ROWS[2]]])
	return out


static func hops_up_from_landing(stops: Stops, landing: int) -> Array:
	"""From module j's U0' (on landing j) up to X: the retreat back to F', then the way up from there."""
	var out: Array = [[stops.fp[landing], StairPins.CLAW_RETREAT_ROWS[0]]]
	out.append_array(hops_up_from_walk_off(stops, landing))
	return out


static func hops_up_from_walk_off(stops: Stops, landing: int) -> Array:
	"""From landing j's F' up to X: the back-up to F, the half-turn onto U, then the ascents (P-2044-16 (a))."""
	var out: Array = [[stops.f[landing], StairPins.STAIR_EMPTY_FLOOR_ROWS[1]], [stops.uf[landing], StairPins.CLAW_TURN_ROW]]
	out.append_array(hops_up_from_floor(stops, landing))
	return out


static func hops_up_from_floor(stops: Stops, landing: int) -> Array:
	"""From landing j's U up to X: the floor's ascent onto module j-1's sill, then that module's way up."""
	var out: Array = [[stops.u[global_level(landing - 1, SILL_LEVEL) + 1], StairPins.CLAW_ASCENT_ROW]]
	out.append_array(hops_up(stops, global_level(landing - 1, SILL_LEVEL)))
	return out


## Decision 2044: a landing's deep stations (layer j + 1) and the all-yaw floor walks between them. Station (row,
## column) stands on `row`'s floor and strikes (row + 1, column); a floor's first station row is its landing row.


class Deep extends RefCounted:
	## One landing's deep station handles by (row - first_row) * 2 + column; NULL_REF where retired or not live.
	var landing: int = 0
	var first_row: int = 0
	var handles: Array[Vector2i] = []

	func at(row: int, column: int) -> Vector2i:
		"""One station handle, or NULL_REF."""
		var index: int = (row - first_row) * 2 + column
		return handles[index] if row >= first_row and index >= 0 and index < handles.size() else NULL_REF


static func classify_deep(point: Vector3i) -> Vector3i:
	"""(landing, row, column) of a deep station's source-local point, or (-1, 0, 0)."""
	if point.x != Tread.DEEP_X[0] and point.x != Tread.DEEP_X[1]: return Vector3i(-1, 0, 0)
	if point.y >= 0 or point.y % Tread.MODULE_DROP != 0: return Vector3i(-1, 0, 0)
	@warning_ignore("integer_division") var landing: int = -point.y / Tread.MODULE_DROP
	var inside: int = point.z + Tread.ROW_U * Tread.ROWS
	if landing >= MODULES or inside % Tread.ROW_U != Tread.DEEP_INSIDE: return Vector3i(-1, 0, 0)
	@warning_ignore("integer_division") var row: int = Tread.ROWS - 1 - inside / Tread.ROW_U
	if landing < 1 or row < Tread.deep_first_row(landing) - 1 or row >= Tread.ROWS - 1: return Vector3i(-1, 0, 0)
	return Vector3i(landing, row, 0 if point.x == Tread.DEEP_X[0] else 1)


static func publish_floor(binding: WorldRoutes, routes: Routes, budget: Budget, owner: RefCounted,
		locations: Locations, stops: Stops, deep: Deep, content_revision: int) -> StringName:
	"""Join landing j's floor to its deep stations on the claw WALK: D (the hub, P-2044-16 (a)) to the landing row's
	column-1 station and back (two L-shaped walks), the column-1 spine between rows and each row's crossing, both
	ways."""
	if binding == null or routes == null or budget == null or owner == null or locations == null or deep == null:
		return REFUSE_OWNER
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return REFUSE_LEASE
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = begun.error
	var staged: int = 0
	for pair: Array in _floor_pairs(stops, deep):
		if code != &"": break
		if pair[0] == NULL_REF or pair[1] == NULL_REF or _joined(routes, pair[0], pair[1], Profiles.MODE_WALK): continue
		code = _stage_floor_edge(routes, begun.token, locations, owner, [pair[0], pair[1]], content_revision)
		staged += 1
	if code == &"" and staged > 0: code = binding.seal(begun.token)
	if code == &"" and staged > 0: code = binding.publish(begun.token)
	binding.abort(begun.token)
	budget.release(lease)
	return code


static func _floor_pairs(stops: Stops, deep: Deep) -> Array:
	"""Every floor walk of one landing as [from, to] handle pairs, in a fixed order."""
	var top: int = deep.first_row
	var hub: Vector2i = stops.d[deep.landing] # P-2044-16 (a): D, the landing's hub.
	var out: Array = [[hub, deep.at(top, 1)], [deep.at(top, 1), hub]]
	for row: int in range(top, Tread.ROWS - 1):
		out.append([deep.at(row, 0), deep.at(row, 1)])
		out.append([deep.at(row, 1), deep.at(row, 0)])
		if row + 1 < Tread.ROWS - 1:
			out.append([deep.at(row, 1), deep.at(row + 1, 1)])
			out.append([deep.at(row + 1, 1), deep.at(row, 1)])
	return out


static func _stage_floor_edge(routes: Routes, token: int, locations: Locations, owner: RefCounted,
		ends: Array[Vector2i], content_revision: int) -> StringName:
	"""One ground WALK over the floor: straight when the two stops share x or z, else an L along the slot's centre
	line first (from a floor stop) or last (to one)."""
	var first: Locations.Record = _record(locations, ends[0])
	var last: Locations.Record = _record(locations, ends[1])
	if first == null or last == null: return REFUSE_OWNER
	var points: PackedInt32Array = PackedInt32Array([first.point.x, first.point.y, first.point.z])
	if first.point.x != last.point.x and first.point.z != last.point.z:
		var corner: Vector3i = Vector3i(first.point.x, first.point.y, last.point.z) if first.point.x == 0 \
			else Vector3i(last.point.x, first.point.y, first.point.z)
		points.append_array(PackedInt32Array([corner.x, corner.y, corner.z]))
	points.append_array(PackedInt32Array([last.point.x, last.point.y, last.point.z]))
	return routes.stage_add(token, _edge(first, ends, points, -1, Profiles.MODE_WALK, owner, content_revision)).error


static func retire_row(binding: WorldRoutes, routes: Routes, locations: Locations, budget: Budget, deep: Deep,
		row: int) -> StringName:
	"""A finished deep row leaves before its own cubes are cut: every edge touching its two stations, published,
	then the stations themselves (2044; their strip goes with the row's first cube, P-2044-12 (a))."""
	if deep == null: return REFUSE_OWNER
	return retire_stops(binding, routes, locations, budget, [deep.at(row, 0), deep.at(row, 1)])


static func retire_stops(binding: WorldRoutes, routes: Routes, locations: Locations, budget: Budget,
		stations: Array[Vector2i]) -> StringName:
	"""Every edge touching the given floor stops, published, then the stops themselves (NULL_REF entries skipped)."""
	if binding == null or routes == null or locations == null or budget == null: return REFUSE_OWNER
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return REFUSE_LEASE
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = begun.error
	if code == &"": code = _stage_touching(routes, begun.token, stations)
	if code == &"": code = binding.seal(begun.token)
	if code == &"": code = binding.publish(begun.token)
	binding.abort(begun.token)
	for stop: Vector2i in stations:
		if code == &"" and stop != NULL_REF and locations.is_live_location(stop):
			code = _remove_location(locations, lease, stop)
	budget.release(lease)
	return code


static func _stage_touching(routes: Routes, token: int, stops: Array[Vector2i]) -> StringName:
	"""Every live edge that starts or ends at one of `stops` leaves the graph, once (a row's crossing touches both)."""
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row])
		var code: StringName = routes.edge_metadata_into(ref, edge)
		if code == &"" and (_listed(stops, edge.from_location) or _listed(stops, edge.to_location)):
			code = routes.stage_remove(token, ref)
		if code != &"": return code
	return &""


static func _listed(stops: Array[Vector2i], stop: Vector2i) -> bool:
	"""One of the given live stops (NULL_REF never matches)."""
	return stop != NULL_REF and stop in stops
