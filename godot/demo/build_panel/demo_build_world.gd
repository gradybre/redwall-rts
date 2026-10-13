extends Node3D
## THE ACTUAL WORLD'S LEVEL IN THE BUILD PANEL (decision 1912, slice C1; Brendan's ruling on decision 1911 P-C6 (a):
## "levels 1–4 show the actual World at 5 m; the legacy warren is hidden while painting"). It replaces the separate
## planner view (`modular_demo_mode.gd`, retired by P-B7) inside the demo's own camera.
##
## WHAT IT DRAWS. The planner's read-only view of the settlement's actual World (`modular_world_view.gd`: the terrain
## cut at the chosen level's floor from the level catalog) on its own render layer, lit by its own light on that layer
## only, with the paint ghosts on the marks layer (demo_build_paint.gd). While shown, the U view draws exactly these two
## layers (tunnel_view.gd `set_override_mask`): the legacy warren, its residents and the surface are not drawn.
## BUILT ON FIRST USE: the view reads the World once (a cold mount, measured in `build_usec`), the first time the
## panel shows an underground level, never at boot. Presentation only: it creates no Room, void, route or order.

const WorldView := preload("res://demo/burrow/modular_world_view.gd")
const Look := preload("res://demo/world/world_look.gd")

## Render layers the legacy demo never uses (demo_layers.gd holds 1-32): the World's surface (built, never shown
## here), its section at a level, and the paint ghosts.
const SURFACE_LAYER: int = 64
const SECTION_LAYER: int = 128
const MARKS_LAYER: int = 256
const SHOWN_MASK: int = SECTION_LAYER | MARKS_LAYER
const REFUSE_UNBOUND: StringName = &"BUILD_WORLD_NOT_COMPOSED"

var _session: WeakRef = null
var _view: WorldView = null
var _light: DirectionalLight3D = null
var _level: int = -1
## Microseconds the one cold mount took (0 before it).
var build_usec: int = 0


func configure(session: Object) -> void:
	"""The settlement's underground session (SettlementSystem.underground_session(); null: none composed)."""
	name = "BuildWorld"
	_session = weakref(session) if session != null else null
	visible = false


func show_level(level: int) -> StringName:
	"""Show level `level`'s floor of the actual World (mounting the view on first use); a refusal hides it."""
	var code: StringName = _mount()
	if code == &"":
		code = _view.set_floor(level)
	if code != &"":
		hide_view()
		return code
	_level = level
	visible = true
	return &""


func hide_view() -> void:
	"""Stop drawing the World's level (the mount is kept for the next time)."""
	visible = false
	_level = -1


func shown_level() -> int:
	"""The level shown, or -1."""
	return _level if visible else -1


func mounted() -> bool:
	"""Whether the World view has been built."""
	return _view != null


func _mount() -> StringName:
	"""Build the World view and its light once, over the session's own World, domain and level catalog."""
	if _view != null:
		return _view.owner_refusal()
	var session: Object = _session.get_ref() if _session != null else null
	if session == null or session.call(&"current_refusal") != &"":
		return REFUSE_UNBOUND
	var started: int = Time.get_ticks_usec()
	var view: WorldView = WorldView.new()
	add_child(view)
	var code: StringName = view.configure(session.get(&"_world"), session.get(&"_world_ref"), session.get(&"_domain"),
		session.get(&"_levels"), SURFACE_LAYER, SECTION_LAYER)
	if code != &"":
		view.free()
		return code
	_view = view
	_light = Look.make_sun()
	_light.name = "BuildWorldLight"
	_light.light_cull_mask = SHOWN_MASK
	_light.shadow_enabled = false
	add_child(_light)
	build_usec = Time.get_ticks_usec() - started
	return &""
