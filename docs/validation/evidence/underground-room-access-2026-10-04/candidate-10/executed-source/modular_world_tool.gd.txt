extends Node3D
## Direct-on-dirt input adapter. The host owns tool selection, camera, modal router and site authority.
## A pixel ray is presentation input; only the resulting integer cells enter the retained draft.

const Editor := preload("res://demo/burrow/modular_editor.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const Overlay := preload("res://demo/burrow/modular_world_overlay.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UNITS_PER_M: float = 1024.0

class Pick extends RefCounted:
	var ok: bool = false
	var cell: Vector2i = Vector2i.ZERO
	var error: StringName = &"WORLD_PICK_MISS"

var overlay: Overlay = null
var _camera: Camera3D = null
var _editor: Editor = null
var _draft: Draft = null
var _datum: Vector3i = Vector3i.ZERO
var _pitch: int = 0
var _level: int = -1
var _bounds: Rect2i = Rect2i()
var _active: bool = false
var _view_matches: bool = false
var _captured: bool = false
var _blocked: Callable = Callable()
var _read_view: Callable = Callable()
var _access_marks: MeshInstance3D = null


func configure(camera: Camera3D, editor: Editor, datum: Vector3i,
		marks_layer: int, input_blocked: Callable, read_view: Callable) -> StringName:
	"""Bind one draft and its real world placement once; input blocking must come from the host."""
	if _editor != null or camera == null or editor == null or editor.draft == null \
			or not input_blocked.is_valid() or not read_view.is_valid():
		return &"WORLD_TOOL_BINDING"
	var snapshot: Dictionary = editor.draft.grid_domain()
	if not snapshot.configured:
		return &"WORLD_TOOL_BINDING"
	var drawn: Overlay = Overlay.new()
	var error: StringName = drawn.configure(datum, snapshot.pitch_u, snapshot.bounds, marks_layer)
	if error != &"":
		drawn.free()
		return error
	_camera = camera
	_editor = editor
	_draft = editor.draft
	_datum = datum
	_pitch = snapshot.pitch_u
	_level = snapshot.level
	_bounds = snapshot.bounds
	_blocked = input_blocked
	_read_view = read_view
	overlay = drawn
	add_child(overlay)
	overlay.visible = false
	editor.preview_changed.connect(_preview_changed)
	_create_access_marks(marks_layer)
	_preview_changed(_draft.visible_cells(), _draft.visual_revision)
	return &""


func set_active(enabled: bool) -> void:
	"""Changing tools cancels the transient gesture, retaining the drawn plan and its history."""
	_active = enabled and _editor != null
	if not _active:
		_cancel_capture()
	if overlay != null:
		overlay.visible = _active and _view_matches and _binding_valid()
	_sync_access_visibility()


func set_view(level: int, floor_u: int, underground_visible: bool) -> void:
	"""Follow the real selected slice. Never transfer an existing plan to another floor by accident."""
	_view_matches = underground_visible and level == _level and floor_u == _datum.y and _binding_valid()
	if not _view_matches:
		_cancel_capture()
	if overlay != null:
		overlay.visible = _active and _view_matches
	_sync_access_visibility()


func datum_u() -> Vector3i:
	"""The coordinator must bind this same immutable datum when validating or accepting local cells."""
	return _datum


func matches_editor(editor: Editor) -> bool:
	"""A confirmation host must borrow the same live inspector and world-picking domain."""
	return editor != null and editor == _editor and _binding_valid()


func confirmation_view_ready() -> bool:
	"""Re-read current level and modal state on a button press as well as on world input."""
	return _can_draw()


func pick(screen: Vector2) -> Pick:
	"""Project through the live camera onto this draft's actual floor, never a screen-space canvas."""
	if not is_instance_valid(_camera) or not _camera.is_inside_tree() or not screen.is_finite():
		return Pick.new()
	if not _camera.get_viewport().get_visible_rect().has_point(screen):
		return Pick.new()
	return ray_pick(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen), _datum, _pitch)


static func ray_pick(origin: Vector3, direction: Vector3, datum: Vector3i, pitch_u: int) -> Pick:
	"""Convert finite presentation coordinates once; negative coordinates use floor, never truncation."""
	var out: Pick = Pick.new()
	if pitch_u < 1 or not origin.is_finite() or not direction.is_finite() or direction.y >= -0.000001:
		return out
	var time: float = (float(datum.y) / UNITS_PER_M - origin.y) / direction.y
	if not is_finite(time) or time < 0.0:
		return out
	var hit: Vector3 = origin + direction * time
	var x: float = floor((float(hit.x) * UNITS_PER_M - datum.x) / pitch_u)
	var z: float = floor((float(hit.z) * UNITS_PER_M - datum.z) / pitch_u)
	if not is_finite(x) or not is_finite(z) or x < -2147483648.0 or x > 2147483647.0 \
			or z < -2147483648.0 or z > 2147483647.0:
		return out
	out.ok = true
	out.error = &""
	out.cell = Vector2i(int(x), int(z))
	return out


func _ready() -> void:
	"""Receive focus-loss notifications even while the rest of the game is paused."""
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	"""Only cancel lost captures here. Camera updates never sample a stationary pointer into paint."""
	_sync_view()
	if _captured and not _can_draw():
		_cancel_capture()


func _notification(what: int) -> void:
	"""A lost application focus never leaves a held mouse stroke waiting to commit later."""
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		_cancel_capture()


func _input(event: InputEvent) -> void:
	"""Own a captured release before GUI, even over a button; presses start only after GUI declines."""
	if not _captured:
		return
	if not _can_draw():
		_cancel_capture()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_captured = false
		_editor.world_release()
		get_viewport().set_input_as_handled()
	elif _cancel_event(event):
		_cancel_capture()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	"""World-only painting leaves wheel/middle/right camera gestures and keyboard focus with the host."""
	if not _can_draw():
		return
	if _editor.selecting_access() and _cancel_event(event):
		_editor.cancel_access_pick()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit: Pick = pick(event.position)
		if hit.ok and _editor.selecting_access():
			_editor.place_access_at(hit.cell)
			get_viewport().set_input_as_handled()
		elif hit.ok and _editor.world_press(hit.cell):
			_captured = true
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _captured:
		if event.relative == Vector2.ZERO:
			return
		var hit: Pick = pick(event.position)
		if hit.ok:
			_editor.world_motion(hit.cell)
		get_viewport().set_input_as_handled()


func _can_draw() -> bool:
	"""Presentation gating never substitutes for the construction coordinator's authoritative checks."""
	_sync_view()
	return _active and _view_matches and _blocked.is_valid() and not bool(_blocked.call())


func _sync_view() -> void:
	"""Read selected level on the event itself, preventing a same-frame level-switch/click race."""
	if not _read_view.is_valid():
		set_view(-1, 0, false)
		return
	var context: Variant = _read_view.call()
	if context is Vector3i:
		set_view(context.x, context.y, context.z == 1)
	else:
		set_view(-1, 0, false)


func _binding_valid() -> bool:
	"""A replaced inspector, freed camera or changed draft cannot leave stale marks on another site."""
	return is_instance_valid(_editor) and _editor.draft == _draft and _draft != null \
		and is_instance_valid(_camera) and _same_domain()


func _same_domain() -> bool:
	"""An empty session reconfiguration cannot quietly reuse an old world-to-cell binding."""
	var domain: Dictionary = _draft.grid_domain()
	return domain.configured and domain.level == _level and domain.pitch_u == _pitch and domain.bounds == _bounds


func _cancel_capture() -> void:
	"""Cancel at most this gesture; earlier strokes, unrelated orders and simulation pauses survive."""
	var was_captured: bool = _captured
	_captured = false
	if was_captured and is_instance_valid(_editor) and _editor.draft == _draft:
		_editor.cancel_stroke()
	elif was_captured and _draft != null:
		_draft.cancel_stroke()


static func _cancel_event(event: InputEvent) -> bool:
	"""Escape/right-click cancel only an active stroke; no added global key or confirmation shortcut."""
	return (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)


func _preview_changed(cells: PackedInt32Array, _revision: int) -> void:
	"""Draw copied world geometry on a change, keeping text refusals in the inspector."""
	if overlay == null or not _binding_valid():
		if overlay != null:
			overlay.visible = false
		return
	var error: StringName = _draft.preview_error() if _draft.drawing() else _draft.confirmation_error()
	overlay.refresh(cells, error != &"")


func _create_access_marks(layer: int) -> void:
	"""One bounded unlit line mesh shares the room slice; it owns no terrain or opening geometry."""
	_editor.access_preview_changed.connect(_access_preview_changed)
	_access_marks = MeshInstance3D.new()
	_access_marks.layers = layer
	_access_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = 4
	_access_marks.material_override = material
	add_child(_access_marks)
	_access_marks.set_as_top_level(true)
	_access_marks.visible = false


func _sync_access_visibility() -> void:
	"""Access guides follow this exact floor/tool binding, including same-frame view changes."""
	if _access_marks != null:
		_access_marks.visible = _active and _view_matches and _binding_valid() and _access_marks.mesh != null


func _access_preview_changed(view: Dictionary) -> void:
	"""The first paid cube, measured contact/clearance and actual existing route remain distinct line geometry."""
	if _access_marks == null: return
	_access_marks.mesh = null
	if not view.get("selected", false) or not _binding_valid():
		_sync_access_visibility()
		return
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_access_prisms(mesh, view)
	var route: PackedInt32Array = view.route
	for at: int in range(0, route.size(), 3):
		mesh.surface_add_vertex(Vector3(route[at], route[at + 1], route[at + 2]) / UNITS_PER_M)
	mesh.surface_end()
	_access_marks.mesh = mesh
	(_access_marks.material_override as StandardMaterial3D).albedo_color = Palette.CREAM if view.error == &"" else Palette.CLAY
	_sync_access_visibility()


static func _access_prisms(mesh: ImmediateMesh, view: Dictionary) -> void:
	"""Profile geometry was already oriented by its source; this presentation adds the exact root only once."""
	_wire_box(mesh, view.target, view.target + Vector3i(1024, 1024, 1024))
	var patch: PackedInt32Array = view.patch
	_wire_box(mesh, Vector3i(patch[0], patch[1], patch[2]), Vector3i(patch[3], patch[4], patch[5]))
	var roles: PackedInt32Array = view.roles
	for at: int in range(0, roles.size(), 7):
		if roles[at + 6] == Profiles.CONTACT_POINT or roles[at + 6] == Profiles.CONTACT_PATCH: continue
		var low: Vector3i = Vector3i(roles[at], roles[at + 1], roles[at + 2])
		var high: Vector3i = Vector3i(roles[at + 3], roles[at + 4], roles[at + 5])
		if low != high: _wire_box(mesh, view.root + low, view.root + high)


static func _wire_box(mesh: ImmediateMesh, low: Vector3i, high: Vector3i) -> void:
	"""Render integer box/patch edges directly; no grown outline is fed back into source clearance."""
	for axis: int in 3:
		if low[axis] == high[axis]: continue
		for corner: int in 4:
			var start: Vector3 = Vector3(low)
			start[(axis + 1) % 3] = high[(axis + 1) % 3] if corner & 1 else low[(axis + 1) % 3]
			start[(axis + 2) % 3] = high[(axis + 2) % 3] if corner & 2 else low[(axis + 2) % 3]
			var end: Vector3 = start
			end[axis] = high[axis]
			mesh.surface_add_vertex(start / UNITS_PER_M)
			mesh.surface_add_vertex(end / UNITS_PER_M)
