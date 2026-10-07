extends Node3D
## ADR1211 (ADR1197 G8 remainder and the presentation half of G5): the live demo's entry worker.
##
## One Actor per loaded mole source image is composed once, hidden, for the entry crew. Each frame reads the real
## first-entry runtime of the settlement host:
##   - no crew yet: nothing is drawn (the runtime's own G11/G4 alerts stand);
##   - crew chosen, but its resident has no Routes actor: the demo's existing surface walk brings a cast mole (the
##     mole_digger body every source image was compiled from) to the stair-top anchor H (work-area endpoint 0). On
##     arrival the G5 alert ENTRY_SURFACE_HANDOFF_UNBUILT is raised: the simulation half (the resident's Transform
##     placed exactly on H, then Routes admission) does not exist, and nothing here fakes it;
##   - the resident has a Routes actor: MolePresentation.present_row draws its actual selected row on the settlement's
##     fixed tick and the shown Actor is placed on the actor's integer point and 16-bit heading.
## Presentation only: it reads owners, never writes the simulation, and never grants work or movement.

const Presentation := preload("res://data/underground/mole-worker/mole_presentation.gd")
const ContentSet := preload("res://demo/cast/underground_content_set.gd")
const Meshes := preload("res://demo/cast/entry_worker_meshes.gd")
const Actor := preload("res://demo/cast/underground_actor.gd")
const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorkArea := preload("res://scripts/core/underground_entry_work_area.gd")
const EntryRuntime := preload("res://scripts/core/underground_entry_runtime.gd")
const ALERT_HANDOFF: StringName = &"ENTRY_SURFACE_HANDOFF_UNBUILT"
const ALERT_NO_CAST_MOLE: StringName = &"ENTRY_WORKER_NO_CAST_MOLE"
## ADR1197 gap rows for the alerts this view raises (the entry runtime's own table is not this file's to extend).
const GAPS: Dictionary = {
	&"ENTRY_SURFACE_HANDOFF_UNBUILT": "G5 surface arrival: the resident's Transform is not placed on the stair-top anchor and no Routes actor is admitted",
	&"ENTRY_WORKER_NO_CAST_MOLE": "G5 no cast mole can present the crew's surface walk",
}
const RENDERER_UNAVAILABLE: StringName = &"UNDERGROUND_RENDERER_UNAVAILABLE"
const UNITS_PER_M: float = 1024.0
const HEADINGS: float = 65536.0
## A cast walker this close (m, on the ground plane) to the anchor has arrived.
const ARRIVE_M: float = 0.75
const STAGE_NONE: int = 0
const STAGE_WALKING: int = 1
const STAGE_AT_ANCHOR: int = 2
const STAGE_UNDERGROUND: int = 3

var _host: Node = null
var _cast: Node = null
var _alert: Callable = Callable()
var _presenter: Presentation = Presentation.new()
var _frame: Driver.Frame = Driver.Frame.new()
var _actor: Routes.Actor = Routes.Actor.new()
var _member: int = -1
var _members: PackedInt32Array = PackedInt32Array([-1])
var _anchor: Vector3 = Vector3.ZERO
var _stage: int = STAGE_NONE
var _alerted: StringName = &""
var _compose_error: StringName = &"ENTRY_WORKER_UNCOMPOSED"


static func gap_of(code: StringName) -> String:
	"""The ADR1197 gap row this view's alert maps to, or the entry runtime's own row."""
	return GAPS.get(code, EntryRuntime.gap_of(code))


func configure(host: Node, cast: Node, sources: ContentSet, alert: Callable) -> StringName:
	"""Bind the settlement host, the demo cast and the loaded image set; `alert` receives each new alert code."""
	if _host != null:
		return &"ENTRY_WORKER_ALREADY_BOUND"
	if host == null or cast == null or not alert.is_valid():
		return &"ENTRY_WORKER_INPUT"
	var code: StringName = _presenter.configure(sources)
	if code != &"":
		return code
	_host = host
	_cast = cast
	_alert = alert
	return &""


func compose_actors(parts: Meshes.Parts) -> StringName:
	"""One hidden Actor per loaded source; any refusal frees what was built and disables drawing (never a fallback)."""
	if parts == null or parts.error != &"":
		return _compose_failed(&"ENTRY_WORKER_ASSETS_NOT_STAGED" if parts == null else parts.error)
	for source: int in ContentSet.MAX_SOURCES:
		if not _presenter._sources.has_source(source):
			continue
		var actor: Actor = Actor.new()
		actor.name = "EntryWorkerSource%d" % source
		add_child(actor)
		var code: StringName = _presenter.configure_actor(source, actor, parts.meshes[source], parts.materials[source])
		if code != &"":
			return _compose_failed(code)
	_compose_error = &""
	return &""


func _compose_failed(code: StringName) -> StringName:
	"""Free every composed Actor; drawing stays off with the exact refusal retained."""
	for child: Node in get_children():
		if child is Actor:
			(child as Actor).release()
			child.free()
	var sources: ContentSet = _presenter._sources
	_presenter.release()
	if sources != null:
		_presenter.configure(sources)
	_compose_error = code
	return code


func _process(_delta: float) -> void:
	"""Follow the real entry runtime on the settlement's own fixed tick."""
	if _host != null:
		advance(_host.ticks_run())


func advance(tick: int) -> StringName:
	"""One observation; returns the code of the alert standing for this frame, or empty."""
	var runtime: RefCounted = _host.underground_entry()
	if runtime == null or runtime.step() < EntryRuntime.STEP_CREW or runtime.crew() == null:
		_stage = STAGE_NONE
		return &""
	var worker: Vector2i = runtime.crew().worker
	var routes: Routes = _routes_of()
	if routes != null and routes.read_actor_into(worker, _actor) == &"":
		return _present_underground(routes, worker, tick)
	return _surface_walk(runtime.origin())


func _routes_of() -> Routes:
	"""The mounted Session's Routes owner, or null before it is composed."""
	var session: RefCounted = _host.underground_session()
	if session == null or session._retirement_owners == null:
		return null
	return session._retirement_owners.routes as Routes


func _surface_walk(origin: Vector3i) -> StringName:
	"""Presentation half of G5: the cast walk to H; arrival raises the hand-off alert, nothing is placed or admitted."""
	if _member < 0:
		_member = _cast_mole()
		if _member < 0:
			return _raise(ALERT_NO_CAST_MOLE)
	if _stage == STAGE_NONE or _stage == STAGE_UNDERGROUND:
		_anchor = anchor_m(origin)
		_members[0] = _member
		_stage = STAGE_WALKING if bool(_cast.order_move(_members, _anchor).get("ok", false)) else STAGE_NONE
	if _stage == STAGE_WALKING and _arrived():
		_stage = STAGE_AT_ANCHOR
	return _raise(ALERT_HANDOFF) if _stage == STAGE_AT_ANCHOR else &""


static func anchor_m(origin: Vector3i) -> Vector3:
	"""The stair-top anchor H (work-area endpoint 0) in metres: 1024 units per metre, -Z forward in both frames."""
	var point: Vector3i = WorkArea.point(origin, 0)
	return Vector3(float(point.x) / UNITS_PER_M, float(point.y) / UNITS_PER_M, float(point.z) / UNITS_PER_M)


func _cast_mole() -> int:
	"""The first cast actor drawn with the mole_digger body every source image was compiled from, or -1."""
	for index: int in _cast.actor_count():
		var member: Node3D = _cast.actor(index)
		if member != null and member.get(&"creature_key") == Meshes.CAST_KEY:
			return index
	return -1


func _arrived() -> bool:
	"""Ground-plane distance of the walker to H."""
	var member: Node3D = _cast.actor(_member)
	if member == null:
		return false
	var dx: float = member.position.x - _anchor.x
	var dz: float = member.position.z - _anchor.z
	return dx * dx + dz * dz <= ARRIVE_M * ARRIVE_M


func _present_underground(routes: Routes, worker: Vector2i, tick: int) -> StringName:
	"""The resident is a Routes actor: draw its actual selected row, or alert the exact reason it cannot be drawn."""
	if _stage == STAGE_WALKING or _stage == STAGE_AT_ANCHOR:
		_cast.release(_members)
	_stage = STAGE_UNDERGROUND
	if _compose_error != &"":
		return &"" if _compose_error == RENDERER_UNAVAILABLE else _raise(_compose_error)
	var code: StringName = _presenter.present_row(routes, worker, tick, _frame)
	if code != &"":
		return _raise(code)
	_place(_presenter.actor(_presenter.visible_source()))
	_alerted = &""
	return &""


func _place(shown: Actor) -> void:
	"""The local Actor path (no World basis is staged in the demo): the node carries the integer root and heading."""
	if shown == null:
		return
	shown.position = Vector3(float(_frame.point.x) / UNITS_PER_M, float(_frame.point.y) / UNITS_PER_M,
		float(_frame.point.z) / UNITS_PER_M)
	shown.basis = Basis(Vector3.UP, float(_frame.yaw) * TAU / HEADINGS)


func _raise(code: StringName) -> StringName:
	"""Each distinct alert is raised once, with its exact code; it stands until the state changes."""
	if code != _alerted:
		_alerted = code
		_alert.call(code)
	return code


func stage() -> int:
	"""Where the crew's resident is in the hand-off: none, walking, at the anchor, or underground."""
	return _stage


func presenter() -> Presentation:
	"""The per-source presenter (tests adopt recording Actors through it)."""
	return _presenter


func mark_composed() -> void:
	"""Tests only: recording Actors were adopted directly through presenter(), with no native composition."""
	_compose_error = &""
