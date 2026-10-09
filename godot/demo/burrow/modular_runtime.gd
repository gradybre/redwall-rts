extends RefCounted
## Command adapter for the actual room coordinator. No simulation, clock, geometry or payment is owned here.
## The host retains the composed owners; this view borrows them weakly and cannot keep a retired World alive.

const Editor := preload("res://demo/burrow/modular_editor.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const WorldTool := preload("res://demo/burrow/modular_world_tool.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const RoomBindings := preload("res://scripts/core/underground_room_bindings.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Access := preload("res://demo/burrow/modular_access.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_BINDING: StringName = &"MODULAR_VIEW_OWNER_BINDING"
const REFUSE_DRAFT: StringName = &"MODULAR_VIEW_DRAFT_CHANGED"
const REFUSE_LEVEL: StringName = &"MODULAR_VIEW_LEVEL_CHANGED"
const REFUSE_BUSY: StringName = &"MODULAR_VIEW_BUSY"

class AccessSetup extends RefCounted:
	## Temporary original configuration; all strong owners and the copied drawing die before this call returns.
	var editor: Editor = null
	var tool: WorldTool = null
	var draft: Draft = null
	var orders: Orders = null
	var bindings: RoomBindings = null
	var levels: Levels = null
	var provider: WorldRoutes = null
	var phase: WorldBindings = null
	var config: WorldRoutes.Configuration = WorldRoutes.Configuration.new()
	var request: Dictionary = {}
	var camera: Camera3D = null
	var blocked: Callable = Callable()
	var read_view: Callable = Callable()

var _editor: Editor = null
var _tool: WorldTool = null
var _draft: WeakRef = null
var _orders: WeakRef = null
var _bindings: WeakRef = null
var _levels: WeakRef = null
var _world: Vector2i = NULL_REF
var _datum: Vector3i = Vector3i.ZERO
var _level_id: int = -1
var _section_offset: int = 0
var _pitch: int = 0
var _bounds: Rect2i = Rect2i()
var _busy: bool = false
var _access: Access = null


func configure(editor: Editor, tool: WorldTool, orders: Orders, bindings: RoomBindings,
		levels: Levels, section_offset_u: int) -> StringName:
	"""Bind an actual world-drawing view once; a matching level number alone never grants construction."""
	if _busy or _orders != null or not is_instance_valid(editor) or not is_instance_valid(tool) \
			or not tool.matches_editor(editor) or orders == null or bindings == null or levels == null:
		return REFUSE_BINDING
	_busy = true
	var draft: Draft = editor.draft
	var code: StringName = _owners_refusal(orders, bindings, levels)
	var record: Levels.Record = Levels.Record.new()
	var grid: Dictionary = draft.grid_domain()
	if code == &"":
		code = levels.level_into(grid.level, section_offset_u, record)
	if not is_instance_valid(editor) or not is_instance_valid(tool) or editor.draft != draft \
			or not tool.matches_editor(editor):
		code = REFUSE_BINDING
	if code == &"" and (not record.has_roof or record.world_ref != orders.world_ref() \
			or tool.datum_u().y != record.floor_y_u):
		code = REFUSE_LEVEL
	if code == &"":
		_pin(editor, tool, orders, bindings, levels, section_offset_u, grid)
		if not editor.bind_confirmation(check_request, submit_request):
			_clear_handles()
			code = REFUSE_BINDING
	_busy = false
	return code


func _pin(editor: Editor, tool: WorldTool, orders: Orders, bindings: RoomBindings,
		levels: Levels, section_offset_u: int, grid: Dictionary) -> void:
	"""Retain view identity and small immutable coordinates; authoritative owners remain externally owned."""
	_editor = editor
	_tool = tool
	_draft = weakref(editor.draft)
	_orders = weakref(orders)
	_bindings = weakref(bindings)
	_levels = weakref(levels)
	_world = orders.world_ref()
	_datum = tool.datum_u()
	_level_id = grid.level
	_section_offset = section_offset_u
	_pitch = grid.pitch_u
	_bounds = grid.bounds


func configure_access(provider: WorldRoutes, anchor: Vector2i) -> StringName:
	"""The actual host supplies its completed anchor; this view never guesses a surface or passage endpoint."""
	if _busy or _access != null or not is_instance_valid(_editor) or not is_instance_valid(_tool) \
			or provider == null or provider.get_script() != WorldRoutes: return REFUSE_BINDING
	_busy = true
	var original: AccessSetup = _access_setup(provider)
	var code: StringName = _observe_access_setup(original, anchor)
	_busy = false
	return code


func _access_setup(provider: WorldRoutes) -> AccessSetup:
	"""Capture the original view, callbacks, drawing and concrete source owners before observing any of them."""
	var out: AccessSetup = AccessSetup.new()
	out.editor = _editor
	out.tool = _tool
	out.draft = _draft.get_ref() as Draft if _draft != null else null
	out.orders = _actual_orders()
	out.bindings = _actual_bindings()
	out.levels = _actual_levels()
	out.provider = provider
	out.camera = _tool._camera
	out.blocked = _tool._blocked
	out.read_view = _tool._read_view
	if out.bindings != null and out.bindings._provider != null:
		out.phase = out.bindings._provider.get_ref() as WorldBindings
	Approach.Witness.capture_configuration(provider, out.config)
	if out.draft != null: out.request = out.draft.snapshot()
	return out


func _observe_access_setup(original: AccessSetup, anchor: Vector2i) -> StringName:
	"""Every external observation is followed by original-identity checks; publication has no refresh callback tail."""
	var code: StringName = _access_setup_refusal(original)
	if code == &"": code = _owners_refusal(original.orders, original.bindings, original.levels)
	if code == &"": code = _access_setup_refusal(original)
	if code == &"": code = _access_binding_refusal(original.provider, original.bindings, original.levels)
	if code == &"": code = _access_setup_refusal(original)
	var access: Access = Access.new()
	if code == &"": code = access.configure(original.provider, anchor)
	var tuple_code: StringName = _access_setup_refusal(original)
	if tuple_code != &"": return tuple_code
	if code == &"": code = _access_view_refusal(original)
	if code != &"": return code
	if not original.editor.bind_access(access, search_access): return REFUSE_BINDING
	code = _access_setup_refusal(original, access)
	if code == &"": _access = access
	elif is_instance_valid(original.editor): original.editor.unbind_access(access, search_access)
	return code


func _access_view_refusal(original: AccessSetup) -> StringName:
	"""Call the original view functions without dereferencing a Node that either callback may free."""
	if not original.read_view.is_valid() or not original.blocked.is_valid(): return REFUSE_BINDING
	var view: Variant = original.read_view.call()
	var code: StringName = _access_setup_refusal(original)
	if code != &"": return code
	if not view is Vector3i or view != Vector3i(_level_id, _datum.y, 1): return REFUSE_LEVEL
	var blocked: Variant = original.blocked.call()
	code = _access_setup_refusal(original)
	if code != &"": return code
	return &"" if typeof(blocked) == TYPE_BOOL and not blocked else REFUSE_LEVEL


func _access_setup_refusal(original: AccessSetup, published: Access = null) -> StringName:
	"""This final comparison uses stored identities and values only, including each original weak composition link."""
	if not is_instance_valid(original.editor) or not is_instance_valid(original.tool) \
			or not is_instance_valid(original.camera) or original.draft == null \
			or _editor != original.editor or _tool != original.tool or _draft == null \
			or _draft.get_ref() != original.draft or _access != null: return REFUSE_BINDING
	if original.orders == null or original.bindings == null or original.levels == null \
			or original.orders != _actual_orders() or original.bindings != _actual_bindings() \
			or original.levels != _actual_levels() or original.phase == null: return REFUSE_BINDING
	if original.editor.draft != original.draft or original.editor._access != published \
			or original.editor._checker != check_request or original.editor._submitter != submit_request \
			or (published != null and original.editor._access_search != search_access): return REFUSE_BINDING
	if original.tool._editor != original.editor or original.tool._draft != original.draft \
			or original.tool._camera != original.camera or original.tool._blocked != original.blocked \
			or original.tool._read_view != original.read_view or not original.tool._active: return REFUSE_BINDING
	if not _access_owners_match(original): return REFUSE_BINDING
	return _access_drawing_refusal(original)


func _access_owners_match(original: AccessSetup) -> bool:
	"""Original authority links and the full WorldRoutes configuration remain exact after all external callbacks."""
	if original.bindings._provider == null or original.bindings._provider.get_ref() != original.phase \
			or original.phase._owner == null or original.phase._owner.get_ref() != original.config.owner \
			or original.phase._world != original.config.world or original.phase._terrain != original.config.terrain \
			or original.phase._budget != original.config.budget or original.bindings._budget != original.config.budget \
			or original.config.levels != original.levels or original.config.profiles == null \
			or original.config.terrain == null: return false
	if original.orders._world != _world or original.orders._space != original.config.owner \
			or original.orders._sources != original.config.sources or original.orders._bindings == null \
			or original.orders._bindings.get_ref() != original.bindings or original.orders._buildings == null \
			or original.orders._buildings._spatial_authority == null \
			or original.orders._buildings._spatial_authority.get_ref() != original.orders: return false
	return Approach.Witness.exact_configuration(original.provider, original.config)


func _access_drawing_refusal(original: AccessSetup) -> StringName:
	"""The same cells, purpose, floor, draft identity and world tool domain must survive every configuration callback."""
	if original.tool._datum != _datum or original.tool._level != _level_id \
			or original.tool._pitch != _pitch or original.tool._bounds != _bounds: return REFUSE_LEVEL
	var draft: Draft = original.draft
	var request: Dictionary = original.request
	if not draft._configured or draft._drawing or draft._level != _level_id or draft._pitch_u != _pitch \
			or draft._bounds != _bounds or draft.revision != request.revision \
			or draft._room_type != request.room_type or draft._allow_holes != request.allow_holes \
			or draft._cells != request.cells: return REFUSE_DRAFT
	return &""


static func _access_binding_refusal(provider: WorldRoutes, bindings: RoomBindings, levels: Levels) -> StringName:
	"""Preview and confirmation must use the same actual World, Terrain, Space, cold arena and level catalog."""
	if provider == null or bindings == null: return REFUSE_BINDING
	var phase: WorldBindings = bindings.phase_world_owner() as WorldBindings
	var config: WorldRoutes.Configuration = WorldRoutes.Configuration.new()
	Approach.Witness.capture_configuration(provider, config)
	if phase == null or config.owner != phase.space_owner() or config.world != phase._world \
			or config.terrain != phase.terrain_owner() or config.budget != bindings.layout_budget_owner() \
			or config.levels != levels: return REFUSE_BINDING
	return &""


func search_access(resuggest: bool, picked: Vector2i, has_pick: bool) -> StringName:
	"""Start bounded view work after exact owner/drawing checks; this never calls RoomOrders.confirm_room."""
	if _busy or _access == null: return REFUSE_BUSY
	_busy = true
	var request: Dictionary = _editor.command_snapshot() if is_instance_valid(_editor) else {}
	var orders: Orders = _actual_orders()
	var bindings: RoomBindings = _actual_bindings()
	var levels: Levels = _actual_levels()
	var code: StringName = _request_refusal(request, orders, bindings, levels)
	var level: Levels.Record = Levels.Record.new()
	if code == &"": code = levels.level_into(_level_id, _section_offset, level)
	var plan: Orders.RoomPlan = _make_plan(bindings, request, level) if code == &"" else null
	if code == &"" and plan == null: code = REFUSE_BINDING
	if code == &"": code = _view_refusal(request)
	if code == &"": code = _access.begin(plan, request.revision, resuggest, picked, has_pick)
	_busy = false
	return code


static func _owners_refusal(orders: Orders, bindings: RoomBindings, levels: Levels) -> StringName:
	"""Prove the exact Buildings/World/Space/provider composition without creating or substituting owners."""
	if orders == null or bindings == null or levels == null or orders.binding_refusal() != &"" \
			or not orders.is_bound_room_bindings(bindings):
		return REFUSE_BINDING
	var provider: WorldBindings = bindings.phase_world_owner() as WorldBindings
	var space: Owner = provider.space_owner() if provider != null else null
	var buildings: Buildings = orders.buildings_owner() as Buildings
	if space == null or buildings == null or buildings.spatial_authority() != orders \
			or provider.world_ref() != orders.world_ref() or provider.binding_refusal() != &"":
		return REFUSE_BINDING
	var domain: Space.Domain = space.domain_copy()
	return &"" if domain != null and levels.binding_matches(domain, buildings.directory(), Space.VERSION) \
		else REFUSE_BINDING


func check_request(request: Dictionary) -> String:
	"""Check current view/owner identity; RoomOrders alone performs physical admission on submission."""
	if _busy:
		return refusal_words(REFUSE_BUSY)
	_busy = true
	var orders: Orders = _actual_orders()
	var bindings: RoomBindings = _actual_bindings()
	var levels: Levels = _actual_levels()
	var code: StringName = _request_refusal(request, orders, bindings, levels)
	if code == &"" and _access != null: code = _selected_refusal(request, bindings, levels)
	_busy = false
	return refusal_words(code)


func _pure_view_refusal(request: Dictionary) -> StringName:
	"""A replaced draft, retired World, changed floor or stale copied request cannot submit old paint."""
	if not is_instance_valid(_editor) or not is_instance_valid(_tool) or _draft == null \
			or _editor.draft != _draft.get_ref() or not _tool.matches_editor(_editor):
		return REFUSE_BINDING
	if not _typed_request(request) or _editor.draft.drawing() or request != _editor.command_snapshot() \
			or _editor.draft.confirmation_error() != &"":
		return REFUSE_DRAFT
	var grid: Dictionary = _editor.draft.grid_domain()
	if not grid.configured or grid.level != _level_id or grid.pitch_u != _pitch or grid.bounds != _bounds \
			or _tool.datum_u() != _datum:
		return REFUSE_LEVEL
	return &""


func _view_refusal(request: Dictionary) -> StringName:
	"""A view observer may change the drawing itself; finish with a callback-free identity/snapshot check."""
	var code: StringName = _pure_view_refusal(request)
	if code != &"":
		return code
	if not _tool.confirmation_view_ready():
		return REFUSE_LEVEL
	return _pure_view_refusal(request)


func _request_refusal(request: Dictionary, orders: Orders, bindings: RoomBindings, levels: Levels) -> StringName:
	"""Hold one original owner set in the caller and reobserve the current view after all owner callbacks."""
	var view_code: StringName = _view_refusal(request)
	if view_code != &"":
		return view_code
	var code: StringName = _owners_refusal(orders, bindings, levels)
	if code != &"" or orders.world_ref() != _world:
		return code if code != &"" else REFUSE_BINDING
	if orders != _actual_orders() or bindings != _actual_bindings() or levels != _actual_levels():
		return REFUSE_BINDING
	return _view_refusal(request)


static func _typed_request(request: Dictionary) -> bool:
	"""Numeric equality cannot admit float input into an authoritative integer room plan."""
	if request.has("access_revision") and typeof(request.access_revision) != TYPE_INT: return false
	for key: String in ["revision", "room_type", "level", "pitch_u"]:
		if typeof(request.get(key)) != TYPE_INT:
			return false
	return request.get("cells") is PackedInt32Array and typeof(request.get("allow_holes")) == TYPE_BOOL


func submit_request(request: Dictionary) -> Dictionary:
	"""Forward one typed exact plan and the actual full Room receipt; no legacy graph or elapsed-time fallback."""
	if _busy:
		return _refused(REFUSE_BUSY)
	_busy = true
	var orders: Orders = _actual_orders()
	var bindings: RoomBindings = _actual_bindings()
	var levels: Levels = _actual_levels()
	var code: StringName = _request_refusal(request, orders, bindings, levels)
	if code != &"":
		_busy = false
		return _refused(code)
	var record: Levels.Record = Levels.Record.new()
	code = levels.level_into(_level_id, _section_offset, record)
	if code == &"" and (record.world_ref != _world or not record.has_roof or record.floor_y_u != _datum.y):
		code = REFUSE_LEVEL
	var answer: Dictionary = _confirm(orders, bindings, request, record) if code == &"" else _refused(code)
	_busy = false
	return answer


func _confirm(orders: Orders, bindings: RoomBindings, request: Dictionary, level: Levels.Record) -> Dictionary:
	"""The caller plan is the already budgeted command input; the actual owner admits all protected copies."""
	var plan: Orders.RoomPlan = _make_plan(bindings, request, level)
	if plan == null: return _refused(REFUSE_BINDING)
	if _access != null:
		var code: StringName = _access.lock_selection(plan, request.revision, request.get("access_revision", -1))
		if code != &"": return _refused(code)
		plan = _access.selected_request(plan, request.revision, request.access_revision)
		if plan == null:
			_access.unlock_selection()
			return _refused(Access.REFUSE_CHANGED)
	var view_code: StringName = _view_refusal(request)
	if view_code != &"":
		if _access != null: _access.unlock_selection()
		return _refused(view_code)
	var result: Buildings.OpResult = orders.confirm_room(plan)
	if _access != null: _access.unlock_selection()
	if not result.ok: return _refused(result.error)
	return _receipt(orders, result.ref, plan.room_type, plan.space_revision)


func _make_plan(bindings: RoomBindings, request: Dictionary, level: Levels.Record) -> Orders.RoomPlan:
	"""Preserve exact fine cells and authored height; no view-selected endpoint is added to a plain plan here."""
	var provider: WorldBindings = bindings.phase_world_owner() as WorldBindings
	var space: Owner = provider.space_owner() if provider != null else null
	if space == null or level.world_ref != _world or not level.has_roof or level.floor_y_u != _datum.y: return null
	var plan: Orders.RoomPlan = Orders.RoomPlan.new()
	plan.world = _world
	plan.space_revision = space.revision()
	plan.room_type = request.room_type
	plan.level = _level_id
	plan.origin_u = _datum
	plan.cell_size_u = _pitch
	plan.height_u = _excavated_height(level.clear_height_u)
	plan.cells = request.cells
	return plan


func _excavated_height(clear_height_u: int) -> int:
	"""DEC-054: the level's clear height, capped at the band the published dig rows reach from the floor."""
	var provider: WorldRoutes = _access._actual() if _access != null else null
	if provider == null or provider._profiles == null: return clear_height_u
	var reach: int = Approach.reachable_height_u(provider._profiles, -1)
	return mini(clear_height_u, reach) if reach > 0 else clear_height_u


func _selected_refusal(request: Dictionary, bindings: RoomBindings, levels: Levels) -> StringName:
	"""A copied selection stamp is checked after all view observations; the full proof still belongs to Orders."""
	if typeof(request.get("access_revision")) != TYPE_INT: return Access.REFUSE_CHANGED
	var level: Levels.Record = Levels.Record.new()
	var code: StringName = levels.level_into(_level_id, _section_offset, level)
	if code != &"": return code
	var plan: Orders.RoomPlan = _make_plan(bindings, request, level)
	if plan == null: return REFUSE_BINDING
	code = _access.selection_refusal(plan, request.revision, request.access_revision)
	return _view_refusal(request) if code == &"" else code


func _receipt(orders: Orders, room: Vector2i, purpose: int, prior_revision: int) -> Dictionary:
	"""An ambiguous post-commit answer disables Editor retry instead of claiming a safe rollback."""
	var buildings: Buildings = orders.buildings_owner() as Buildings
	if buildings == null or not buildings.directory().is_valid_of_kind(room, Directory.KIND_ROOM) \
			or not buildings.is_live_room(room):
		return {"error": "The room result needs review before another order.", "room": room}
	var actual_type: Buildings.OpResult = buildings.type_of_room(room)
	var domain: Buildings.OpResult = buildings.spatial_kind_of_room(room)
	if not actual_type.ok or actual_type.value != purpose or not domain.ok \
			or domain.value != Buildings.ROOM_SPACE_UNDERGROUND:
		return {"error": "The room result needs review before another order.", "room": room}
	return {"ok": true, "error": "", "room": room, "world": _world, "room_type": purpose,
		"level": _level_id, "origin_u": _datum, "prior_space_revision": prior_revision}


func disconnect_view() -> StringName:
	"""Drop this exact view binding at quiescence; accepted Rooms and a newer host remain untouched."""
	if _busy:
		return REFUSE_BUSY
	if is_instance_valid(_editor):
		if _access != null: _editor.unbind_access(_access, search_access)
		_editor.unbind_confirmation(check_request, submit_request)
	_clear_handles()
	return &""


func _clear_handles() -> void:
	"""Discard only this adapter's handles after refusal or quiescent detach, never a replacement host's."""
	_editor = null
	_tool = null
	_draft = null
	_orders = null
	_bindings = null
	_levels = null
	_access = null
	_world = NULL_REF


func _actual_orders() -> Orders:
	"""Expired composition never implicitly creates a replacement Room owner."""
	return _orders.get_ref() as Orders if _orders != null else null


func _actual_bindings() -> RoomBindings:
	"""Keep only the existing host's actual room geometry provider."""
	return _bindings.get_ref() as RoomBindings if _bindings != null else null


func _actual_levels() -> Levels:
	"""Read the host's source-pinned level catalog; view labels are never floor-height authority."""
	return _levels.get_ref() as Levels if _levels != null else null


static func _refused(code: StringName) -> Dictionary:
	"""Keep machine evidence separate from the short explanation shown by the inspector."""
	return {"ok": false, "error": refusal_words(code), "error_code": code}


static func refusal_words(code: StringName) -> String:
	"""Explain the current action's refusal without presenting internal module names to the player."""
	match code:
		&"": return ""
		REFUSE_DRAFT: return "The room drawing changed. Review it before confirming."
		REFUSE_LEVEL, RoomBindings.REFUSE_LEVEL: return "Return to this room's floor before confirming."
		REFUSE_BUSY: return "The current room order is still being checked."
		Access.REFUSE_SEARCHING: return "Searching completed passages for a supported first cut…"
		Access.REFUSE_CHANGED: return "The access or source changed. Review the marked first cut before confirming."
		Access.REFUSE_BOUNDARY: return "Choose a reachable first-cut face on the room's drawn boundary."
		Access.REFUSE_MISSING: return "No reachable first cut was found. Revise the room or its access."
		RoomBindings.REFUSE_ENTRY: return "Connect a completed passage with a supported work face before ordering this room."
		RoomBindings.REFUSE_ABOVE: return "This room would obstruct the space above it."
		RoomBindings.REFUSE_FOOTING: return "This room would remove required support."
		RoomBindings.REFUSE_CUT: return "This room overlaps existing excavation or a reserved construction area."
		&"TERRAIN_WATER_PROTECTED": return "This room would intersect protected water."
		&"SPACE_REVISION_STALE": return "The site changed. Review the room and its access before confirming."
	return "This site is not ready for that room. Review its location and access."
