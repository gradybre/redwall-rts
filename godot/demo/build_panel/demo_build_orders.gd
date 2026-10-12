extends RefCounted
## CONFIRM ALL'S ORDER ROUTE in the demo (decision 1871; Brendan's ruling 2 of 2026-10-12: "Confirm all orders them
## through the planner's existing route, the same one 'Plan an underground room' uses today").
##
## Each pending room operation IS a planner draft (build_batch.gd). To order one, this binds that very draft to a
## fresh, off-tree planner editor and world tool on the operation's level -- the actual floor of the settlement's
## level catalog -- and a `modular_runtime.gd` command adapter over the settlement's own RoomOrders, room bindings and
## level catalog, exactly as `modular_room_mode.gd` composes them; then asks the runtime's `check_request` and, when
## that passes, its `submit_request`. The runtime re-checks every identity, and RoomOrders alone admits or refuses the
## room: no access endpoint is invented here, so with no completed passage to the room it refuses in its own words
## ("Connect a completed passage ..."), and the batch keeps the operation with that reason. NOTHING IS DEDUCTED HERE
## (BUILD-REQ-019): an admitted room becomes a project whose materials are hauled and used when work starts. The
## temporary editor, tool and runtime are freed before `submit` returns; the draft is the batch's.
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

## The initial level pack's square in cells (data/underground/initial_level_pack.json: datum x/z 0, 256 quanta).
const DEFAULT_BOUNDS: Rect2i = Rect2i(0, 0, 256, 256)
const PITCH_U: int = 1024
const NOT_COMPOSED: String = "the settlement's underground is not ready in this run, so nothing can be ordered"

var _orders: WeakRef = null
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
	var record: Levels.Record = Levels.Record.new()
	if levels != null and levels.level_into(1, 0, record) == &"":
		_clear_height = record.clear_height_u


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
	"""The levels' clear height (the ledger prices a cell by it)."""
	return _clear_height


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
	return answer


func _never_blocked() -> bool:
	"""The route runs inside a Confirm all press; the host has already refused it behind a modal."""
	return false


static func _view_of(level: int, floor_u: int) -> Vector3i:
	"""The tool's view: the operation's own level and floor, shown."""
	return Vector3i(level, floor_u, 1)


static func _owner(handle: WeakRef) -> Object:
	"""A weakly held owner, or null once it is gone."""
	return handle.get_ref() if handle != null else null
