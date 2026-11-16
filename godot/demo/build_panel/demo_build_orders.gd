extends RefCounted
## CONFIRM ALL'S ORDER ROUTE in the demo (decision 1871; Brendan's ruling 2 of 2026-10-12: "Confirm all orders them
## through the planner's existing route, the same one 'Plan an underground room' uses today").
##
## Each pending room operation IS a planner draft (build_batch.gd). To order one, this binds that very draft to a
## fresh, off-tree planner editor and world tool on the operation's level -- the actual floor of the settlement's
## level catalog -- and a `modular_runtime.gd` command adapter over the settlement's own RoomOrders, room bindings and
## level catalog, exactly as `modular_room_mode.gd` composes them; then asks the runtime's `check_request` and, when
## that passes, its `submit_request`. The runtime re-checks every identity, and RoomOrders alone admits or refuses the
## room: no access endpoint is invented here, so with no way in bound to the room it refuses, and `classify` puts
## that in the panel's words ("No way in: ...; the way in from the build panel comes in a later update", P-B11); a
## site that can never take the room is "X Cannot dig here". The batch keeps the operation with that reason. NOTHING IS DEDUCTED HERE
## (BUILD-REQ-019): an admitted room becomes a project whose materials are hauled and used when work starts. The
## temporary editor, tool and runtime are freed before `submit` returns; the draft is the batch's.
##
## SLICE C1 (decision 1912). Every painted room on levels 1-4 has no way in until slice D's entrance (decision 1911
## §2.1), so the batch holds Confirm all back with "No way in" (BUILD-REQ-013, judged per cell) and this route is not
## reached from the panel; it stays for the rooms C3 will order. This file also lends the panel what it reads of the
## actual underground: each level's floor (`floor_of`), the height a room is actually dug there (`dug_height_of`:
## the clear height capped by DEC-054's reachable height for the claw crew -- decision 1911 P-C3 (a) as corrected by
## P-C2-3 (a) of decision 1931, read in `modular_runtime.gd dug_height_u`), and the
## terrain survey, the excavation Sites and the space owner for the ground reader (demo_build_ground.gd).
##
## The planning area and a room's most cells are the actual space domain's (the same 0..256 m square the planner
## draws on), on the 1 m grid; with no underground composed in this run (`bound` false), a default of the initial level
## pack's 256 × 256 cells is used and every order is refused, saying so.

const Runtime := preload("res://demo/burrow/modular_runtime.gd")
const Editor := preload("res://demo/burrow/modular_editor.gd")
const Tool := preload("res://demo/burrow/modular_world_tool.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Ledger := preload("res://scripts/ui/build_ledger.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const RoomBindings := preload("res://scripts/core/underground_room_bindings.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")

## The initial level pack's square in cells (data/underground/initial_level_pack.json: datum x/z 0, 256 quanta).
const DEFAULT_BOUNDS: Rect2i = Rect2i(0, 0, 256, 256)
const PITCH_U: int = 1024
const NOT_COMPOSED: String = "the settlement's underground is not ready in this run, so nothing can be ordered"
## The coordinator's resolution of review H3 (decision 1871): RoomOrders' missing-approach refusal in the canonical
## BUILD-REQ-013 words, with the plain clause that the way in itself is a later update (slices C/D).
const LATER_WAY_IN: String = "; the way in from the build panel comes in a later update"
## RoomOrders refusals that can never succeed on that site, in the canonical ECON-003 words ("X Cannot dig here"):
## the room bindings' occupied cut, above and footing, and the terrain survey's protected water, resources,
## foundations, building sites and ground that is not natural dry solid (underground_terrain.gd; decision 1871, the
## second review of H3). The survey's binding, bounds, capacity and open-exterior refusals are not the site's: they
## keep the runtime's words as "!".
const NEVER_HERE: Dictionary = {
	Terrain.REFUSE_WATER: "water",
	RoomBindings.REFUSE_CUT: "occupied",
	RoomBindings.REFUSE_ABOVE: "protected ground",
	RoomBindings.REFUSE_FOOTING: "protected ground",
	Terrain.REFUSE_RESOURCE: "protected ground",
	Terrain.REFUSE_FOUNDATION: "protected ground",
	Terrain.REFUSE_BODY: "protected ground",
	Terrain.REFUSE_DRY: "protected ground",
}

var _orders: WeakRef = null
var _session: WeakRef = null
var _bindings: WeakRef = null
var _levels: WeakRef = null
var _camera: Camera3D = null
var _datum: Vector3i = Vector3i.ZERO
var _bounds: Rect2i = DEFAULT_BOUNDS
var _capacity: int = Footprint.MAX_OPERATION_CELLS
var _clear_height: int = Ledger.DEFAULT_CLEAR_HEIGHT_U
## Orders submitted and admitted (checks).
var submitted: int = 0
var admitted: int = 0


func bind_session(session: Object, camera: Camera3D) -> StringName:
	"""Borrow the settlement's composed underground (SettlementSystem.underground_session()): its RoomOrders, room
	bindings, level catalog and space domain. A refusal leaves the route unbound (every order then refused)."""
	if session == null or not session.has_method(&"room_orders"):
		return &"BUILD_ORDERS_NO_SESSION"
	var code: StringName = session.call(&"current_refusal")
	if code != &"":
		return code
	var owners: Object = session.get(&"_retirement_owners")
	var space: Object = session.call(&"space_owner")
	if owners == null or space == null or session.call(&"room_orders") == null:
		return &"BUILD_ORDERS_NO_SESSION"
	var domain: Dictionary = space.call(&"domain_copy").call(&"descriptor")
	_session = weakref(session)
	bind_owners(session.call(&"room_orders"), owners.get(&"room_bindings"), session.call(&"level_catalog"), camera,
		domain.datum_u, grid_bounds(domain.bounds_u, domain.datum_u), mini(int(domain.max_cells), Footprint.MAX_OPERATION_CELLS))
	return &"" if bound() else &"BUILD_ORDERS_NO_SESSION"


func bind_owners(orders: Object, bindings: Object, levels: Levels, camera: Camera3D, datum: Vector3i, bounds: Rect2i,
		capacity: int) -> void:
	"""The owners the planner's runtime is composed over (weakly held: a retired World cannot be kept alive here)."""
	_orders = weakref(orders) if orders != null else null
	_bindings = weakref(bindings) if bindings != null else null
	_levels = weakref(levels) if levels != null else null
	_camera = camera
	_datum = datum
	_bounds = bounds
	_capacity = capacity
	_clear_height = clear_height_of(1)


static func grid_bounds(bounds_u: PackedInt32Array, datum: Vector3i) -> Rect2i:
	"""The space domain's whole-metre box as cells of the 1 m grid from the datum (modular_room_mode.gd's rule at
	1024 u a cell)."""
	@warning_ignore("integer_division") var x: int = (bounds_u[0] - datum.x) / PITCH_U
	@warning_ignore("integer_division") var z: int = (bounds_u[2] - datum.z) / PITCH_U
	@warning_ignore("integer_division") var width: int = (bounds_u[3] - bounds_u[0]) / PITCH_U
	@warning_ignore("integer_division") var depth: int = (bounds_u[5] - bounds_u[2]) / PITCH_U
	return Rect2i(x, z, width, depth)


func bound() -> bool:
	"""Whether the settlement's owners are bound and still alive."""
	return _owner(_orders) != null and _owner(_bindings) != null and _owner(_levels) != null and is_instance_valid(_camera)


func cell_bounds() -> Rect2i:
	"""The planning area in 1 m cells."""
	return _bounds


func cell_capacity() -> int:
	"""A room's most cells."""
	return _capacity


func clear_height() -> int:
	"""Level 1's clear height (the ledger prices a cell by its own level's: `clear_height_of`)."""
	return _clear_height


func clear_height_of(level: int) -> int:
	"""Level `level`'s clear height from the bound level catalog (the level pack's 4096 u when unbound or unknown)."""
	var levels: Levels = _owner(_levels) as Levels
	var record: Levels.Record = Levels.Record.new()
	if levels != null and levels.level_into(level, 0, record) == &"" and record.has_roof:
		return record.clear_height_u
	return Ledger.DEFAULT_CLEAR_HEIGHT_U


func floor_of(level: int) -> int:
	"""Level `level`'s floor (u) from the bound level catalog (section 0), or 0 when unbound or unknown."""
	var levels: Levels = _owner(_levels) as Levels
	var record: Levels.Record = Levels.Record.new()
	if levels != null and levels.level_into(level, 0, record) == &"" and record.has_roof:
		return record.floor_y_u
	return 0


func dug_height_of(level: int) -> int:
	"""DEC-054: the height a room on `level` is actually dug to, read where the planner reads it
	(`modular_runtime.gd dug_height_u`: the claw crew's reach, never "any row"; P-C2-3 (a))."""
	var session: Object = _owner(_session)
	var provider: Object = session.call(&"world_route_provider") if session != null else null
	return Runtime.dug_height_u(provider.get(&"_profiles") if provider != null else null, clear_height_of(level))


func terrain_owner() -> Object:
	"""The settlement's terrain survey (null unbound)."""
	var session: Object = _owner(_session)
	return session.call(&"terrain_owner") if session != null else null


func space_owner() -> Object:
	"""The settlement's space owner (null unbound)."""
	var session: Object = _owner(_session)
	return session.call(&"space_owner") if session != null else null


func excavation_sites() -> Object:
	"""The settlement's excavation Sites, through RoomOrders' construction owner (null unbound)."""
	var orders: Object = _owner(_orders)
	var construction: Object = orders.call(&"construction_owner") if orders != null else null
	return construction.call(&"excavation_authority") if construction != null else null


func datum_u() -> Vector3i:
	"""The space domain's datum: cell (0, 0) starts at its x and z."""
	return _datum


func submit(draft: Draft, level: int, _room_type: int) -> Dictionary:
	"""Order one operation through the planner's runtime (see the header): {ok, error (words), room on success}."""
	submitted += 1
	if not bound():
		return {"ok": false, "error": NOT_COMPOSED}
	var levels: Levels = _owner(_levels) as Levels
	var record: Levels.Record = Levels.Record.new()
	var code: StringName = levels.level_into(level, 0, record)
	if code != &"" or not record.has_roof:
		return {"ok": false, "error": Runtime.refusal_words(code if code != &"" else Runtime.REFUSE_LEVEL)}
	var answer: Dictionary = _through_runtime(draft, level, record.floor_y_u)
	if bool(answer.get("ok", false)):
		admitted += 1
	return answer


func _through_runtime(draft: Draft, level: int, floor_u: int) -> Dictionary:
	"""Compose editor, tool and runtime over `draft`, check, submit, and free them again."""
	var editor: Editor = Editor.new()
	editor.configure(draft, 0)
	var tool: Tool = Tool.new()
	var answer: Dictionary = {"ok": false, "error": Runtime.refusal_words(Runtime.REFUSE_BINDING)}
	var code: StringName = tool.configure(_camera, editor, Vector3i(_datum.x, floor_u, _datum.z), 1, _never_blocked,
		_view_of.bind(level, floor_u))
	if code == &"":
		tool.set_active(true)
		answer = _check_and_submit(editor, tool)
	tool.free()
	editor.free()
	return answer


func _check_and_submit(editor: Editor, tool: Tool) -> Dictionary:
	"""The runtime's check, then its submit; it is disconnected before the editor and tool are freed."""
	var runtime: Runtime = Runtime.new()
	var code: StringName = runtime.configure(editor, tool, _owner(_orders), _owner(_bindings), _owner(_levels) as Levels, 0)
	if code != &"":
		return {"ok": false, "error": Runtime.refusal_words(code)}
	var request: Dictionary = editor.command_snapshot()
	var words: String = runtime.check_request(request)
	var answer: Dictionary = {"ok": false, "error": words} if not words.is_empty() else runtime.submit_request(request)
	runtime.disconnect_view()
	return classify(answer)


static func classify(answer: Dictionary) -> Dictionary:
	"""A refused answer in the build panel's words and kind (decision 1871, H3): no approach is "! Blocked: No way in:
	…" (retried by the next Confirm all); water, a cut or protected ground is "X Not possible: Cannot dig here: …";
	anything else "! Blocked" with the runtime's own words. An admitted answer is returned as it came."""
	if bool(answer.get("ok", false)):
		return answer
	var code: StringName = answer.get("error_code", &"")
	var out: Dictionary = answer.duplicate()
	out["kind"] = Validity.KIND_BLOCKED
	if code == RoomBindings.REFUSE_ENTRY:
		out["error"] = Validity.no_way_in() + LATER_WAY_IN
	elif NEVER_HERE.has(code):
		out["kind"] = Validity.KIND_NOT_POSSIBLE
		out["error"] = Validity.cannot_dig(NEVER_HERE[code])
	return out


func _never_blocked() -> bool:
	"""The route runs inside a Confirm all press; the host has already refused it behind a modal."""
	return false


static func _view_of(level: int, floor_u: int) -> Vector3i:
	"""The tool's view: the operation's own level and floor, shown."""
	return Vector3i(level, floor_u, 1)


static func _owner(handle: WeakRef) -> Object:
	"""A weakly held owner, or null once it is gone."""
	return handle.get_ref() if handle != null else null
