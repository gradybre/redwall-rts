extends "res://test/framework/test_case.gd"
## ADR1211: the live demo's entry worker view. G5 presentation half on a real settlement whose first-entry chain has
## chosen its crew (the ADR1197 host fixture, with the G11 test stand-in tool); the drawing half on the real content-6
## stone haul (ADR1206 fixture) through a host seam; and the mesh factories' exact fingerprints.

const View := preload("res://demo/cast/entry_worker_view.gd")
const Meshes := preload("res://demo/cast/entry_worker_meshes.gd")
const Presentation := preload("res://data/underground/mole-worker/mole_presentation.gd")
const ContentSet := preload("res://demo/cast/underground_content_set.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Grip := preload("res://data/underground/mole-worker/mole_grip_source.gd")
const HostSuite := preload("res://test/test_underground_host.gd")
const HaulGrip := preload("res://test/test_underground_haul_grip.gd")
const PresentationSuite := preload("res://test/test_mole_presentation.gd")
const EntryRuntime := preload("res://scripts/core/underground_entry_runtime.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const NEAR: Vector3i = Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)


class Member extends Node3D:
	## A cast actor as the view reads it: a position and its creature key.
	var creature_key: StringName = &""


class Cast extends Node:
	## The DemoCast calls the view makes; orders and releases are recorded, walking is the test's to do.
	var members: Array[Node3D] = []
	var orders: Array[Vector3] = []
	var released: int = 0

	func actor_count() -> int:
		"""Cast size."""
		return members.size()

	func actor(index: int) -> Node3D:
		"""One cast actor."""
		return members[index]

	func order_move(picked: PackedInt32Array, point: Vector3) -> Dictionary:
		"""Record the order; the formation lands where asked."""
		assert(picked.size() == 1)
		orders.append(point)
		return {"ok": true, "at": point}

	func release(_picked: PackedInt32Array) -> void:
		"""Record a hand-back to wandering."""
		released += 1


class Runtime extends RefCounted:
	## The entry-runtime reads the view makes, over a real crew worker.
	var _crew: EntryRuntime.Foreman.Crew = EntryRuntime.Foreman.Crew.new()

	func step() -> int:
		"""Past crew selection."""
		return EntryRuntime.STEP_CREW

	func origin() -> Vector3i:
		"""Any origin; the drawing half never reads it."""
		return Vector3i.ZERO

	func crew() -> EntryRuntime.Foreman.Crew:
		"""The real crew worker the view draws."""
		return _crew


class Owners extends RefCounted:
	var routes: Routes = null


class Session extends RefCounted:
	var _retirement_owners: Owners = Owners.new()


class Host extends Node:
	## Host seam over the ADR1206 fixture's real Routes owner and worker.
	var entry: Runtime = Runtime.new()
	var session: Session = Session.new()
	var tick: int = 0

	func underground_entry() -> RefCounted:
		"""The crew-bearing runtime."""
		return entry

	func underground_session() -> RefCounted:
		"""The owners holding the real Routes."""
		return session

	func ticks_run() -> int:
		"""The fixed tick the test sets."""
		return tick


var _alerts: Array[StringName] = []
var _nodes: Array[Node] = []
var _host_suite: HostSuite = null
var _haul: HaulGrip = null


func after_each() -> void:
	"""Free views, casts and fixtures."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_alerts.clear()
	for fixture: RefCounted in [_host_suite, _haul]:
		if fixture != null:
			fixture.after_each()
			assert_true(fixture.failures.is_empty(), "actual fixture: %s" % fixture.failures)
	_host_suite = null
	_haul = null


func _record(code: StringName) -> void:
	"""Alert sink standing in for UIManager.push_refusal."""
	_alerts.append(code)


func _cast(keys: Array[StringName]) -> Cast:
	"""A cast of members with these creature keys, all at the origin."""
	var cast: Cast = Cast.new()
	_nodes.append(cast)
	for key: StringName in keys:
		var member: Member = Member.new()
		member.creature_key = key
		_nodes.append(member)
		cast.members.append(member)
	return cast


func _view(host: Node, cast: Cast, include_stone: bool = true) -> View:
	"""A configured view over the pinned image set."""
	var sources: ContentSet = ContentSet.new()
	assert_equal(Presentation.load_sources(sources, true, include_stone), &"", "pinned images")
	var view: View = View.new()
	_nodes.append(view)
	assert_equal(view.configure(host, cast, sources, _record), &"", "view bound")
	return view


func _crew_host() -> HostSuite:
	"""The real ADR1197 chain on a generated settlement, stopped at G4 with its crew chosen (G11 stand-in tool)."""
	_host_suite = HostSuite.new()
	_host_suite.before_each()
	var session: RefCounted = _host_suite._generate_and_mount()
	var host: Node = _host_suite._host
	assert_true(host.compose_underground_room_owners() and host.compose_underground_route_owners()
		and host.compose_underground_surface_anchor() and host.compose_underground_entry_owners(), "owners composed")
	assert_false(host.begin_underground_entry(NEAR), "G11 first")
	_host_suite._equip_first_mole(session._retirement_owners, host.underground_entry()._output)
	assert_false(host.begin_underground_entry(NEAR), "then G4")
	assert_equal(host.underground_entry().step(), EntryRuntime.STEP_CREW, "crew chosen")
	return _host_suite


func test_surface_walk_brings_a_cast_mole_to_the_anchor_then_raises_the_g5_alert_once() -> void:
	"""The resident has no Routes actor: the walk is ordered to H, and only arrival raises the exact G5 alert."""
	var host: Node = _crew_host()._host
	var cast: Cast = _cast([&"otter_fisher", Meshes.CAST_KEY])
	var view: View = _view(host, cast)
	var runtime: EntryRuntime = host.underground_entry()
	var actor: Routes.Actor = Routes.Actor.new()
	assert_true(host.underground_session()._retirement_owners.routes.read_actor_into(runtime._crew.worker, actor) != &"",
		"the simulation half is missing: the crew's resident is not a Routes actor")
	assert_equal(view.advance(1), &"", "walking: no alert yet")
	assert_equal(view.stage(), View.STAGE_WALKING, "the walk is ordered")
	assert_equal(cast.orders, [View.anchor_m(runtime.origin())] as Array[Vector3], "one order, to H in metres")
	var h: Vector3i = View.WorkArea.point(runtime.origin(), 0)
	assert_equal(View.anchor_m(runtime.origin()), Vector3(h) / 1024.0, "endpoint 0 at 1024 units per metre")
	cast.members[1].position = View.anchor_m(runtime.origin()) + Vector3(1.0, 0.0, 0.0)
	assert_equal(view.advance(2), &"", "a metre short is not arrival")
	cast.members[1].position = View.anchor_m(runtime.origin()) + Vector3(0.5, 0.0, 0.5)
	assert_equal(view.advance(3), View.ALERT_HANDOFF, "arrival at H meets the missing hand-off")
	assert_equal(view.advance(4), View.ALERT_HANDOFF, "it stands")
	assert_equal(_alerts, [View.ALERT_HANDOFF] as Array[StringName], "raised exactly once")
	assert_equal(cast.orders.size(), 1, "never re-ordered")
	assert_true(View.gap_of(View.ALERT_HANDOFF).begins_with("G5"), "G5 gap row")
	assert_true(View.gap_of(&"ENTRY_FOREMAN_INPUT_LOT").begins_with("G4"), "the runtime's own rows still map")


func test_no_crew_draws_nothing_and_no_cast_mole_is_an_alert() -> void:
	"""Before crew selection nothing happens; with a crew but no mole in the cast the walk cannot be presented."""
	_host_suite = HostSuite.new()
	_host_suite.before_each()
	_host_suite._generate_and_mount()
	var idle: View = _view(_host_suite._host, _cast([Meshes.CAST_KEY]))
	assert_equal([idle.advance(0), idle.stage(), _alerts.size()], [&"", View.STAGE_NONE, 0], "no entry runtime")
	_host_suite.after_each()
	var host: Node = _crew_host()._host
	var view: View = _view(host, _cast([&"otter_fisher"]))
	assert_equal(view.advance(0), View.ALERT_NO_CAST_MOLE, "no mole to walk")
	assert_true(View.gap_of(View.ALERT_NO_CAST_MOLE).begins_with("G5"), "G5 gap row")


func _haul_host(include_stone: bool) -> Array:
	"""[Host, View, job]: the ADR1206 stone haul up to R with the view's presenter on recording Actors."""
	_haul = HaulGrip.new()
	if not _haul._ready():
		return []
	var lot: Vector2i = _haul._stage(1000, &"stone")
	var job: HaulGrip.Jobs.OpResult = _haul._haul_job()
	assert_true(_haul._delivery.admit(job.ref, lot, 1000, HaulGrip.EXPIRY).ok, "stone admitted")
	assert_true(_haul._probe._world._jobs.set_state(job.value, HaulGrip.Jobs.JOB_STATE_TRAVEL).ok, "travel")
	var host: Host = Host.new()
	_nodes.append(host)
	host.entry._crew.worker = _haul._probe._world._worker
	host.session._retirement_owners.routes = _haul._probe._world._routes
	var view: View = _view(host, _cast([Meshes.CAST_KEY]), include_stone)
	for source: int in ContentSet.MAX_SOURCES:
		if view.presenter()._sources.has_source(source):
			var actor: PresentationSuite.RecordingActor = PresentationSuite.RecordingActor.new()
			_nodes.append(actor)
			actor.borrow(view.presenter()._sources.content(source)._palette)
			assert_equal(view.presenter().adopt_actor(source, actor), &"", "adopted")
	return [host, view, job]


func test_an_admitted_worker_is_drawn_on_its_row_and_placed_on_its_point_and_heading() -> void:
	"""The Routes actor's own row picks the Actor; the node carries the integer root and the 16-bit heading."""
	var fixture: Array = _haul_host(true)
	if fixture.is_empty():
		return
	var view: View = fixture[1]
	view.mark_composed()
	assert_equal(view.advance(0), &"", "WALK row drawn")
	assert_equal([view.stage(), view.presenter().visible_source()], [View.STAGE_UNDERGROUND, 2], "haul image")
	assert_true(_haul._travel(fixture[2], View.WorkArea.STAND_R, Profiles.MODE_WALK), "to R's stand")
	assert_true(_haul._grip(fixture[2], 39), "stone lift row")
	(fixture[0] as Host).tick = 40
	assert_equal(view.advance(40), &"", "stone lift row drawn")
	var shown: Node3D = view.presenter().actor(3)
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_haul._probe._world._routes.read_actor_into(_haul._probe._world._worker, actor), &"", "actual actor")
	assert_equal(shown.position, Vector3(actor.point) / 1024.0, "integer root in metres")
	assert_true(shown.basis.is_equal_approx(Basis(Vector3.UP, float(actor.yaw) * TAU / 65536.0)), "16-bit heading")
	assert_equal(actor.yaw, 16384, "the certified grip heading")
	assert_equal(_alerts.size(), 0, "nothing alerted")


func test_a_composition_refusal_is_alerted_only_once_the_worker_needs_drawing() -> void:
	"""Unstaged assets keep drawing off; the exact code is raised when a Routes actor exists, and a missing image too."""
	var fixture: Array = _haul_host(false)
	if fixture.is_empty():
		return
	var view: View = fixture[1]
	var parts: Meshes.Parts = Meshes.build({}, null)
	assert_equal(parts.error, &"ENTRY_WORKER_ASSETS_NOT_STAGED", "no staged mole or pick")
	assert_equal(view.compose_actors(parts), &"ENTRY_WORKER_ASSETS_NOT_STAGED", "composition refused")
	assert_equal(_alerts.size(), 0, "not alerted at composition")
	assert_equal(view.advance(0), &"ENTRY_WORKER_ASSETS_NOT_STAGED", "alerted when the worker needs drawing")
	assert_equal(view.advance(1), &"ENTRY_WORKER_ASSETS_NOT_STAGED", "it stands")
	assert_equal(_alerts, [&"ENTRY_WORKER_ASSETS_NOT_STAGED"] as Array[StringName], "once")


func test_mesh_factories_match_their_source_images_exactly() -> void:
	"""The wood stock factory and the stone lump are each image's own part 1; the pick fit is the pinned grip fit."""
	var sources: ContentSet = ContentSet.new()
	assert_equal(Presentation.load_sources(sources, true, true), &"", "pinned images")
	assert_equal(Content.mesh_fingerprint(Meshes.stock_mesh(), 0, 522, 1), sources.content(2)._part_hashes.slice(32, 64),
		"v8 stock factory")
	assert_equal(Content.mesh_fingerprint(Presentation.Dressing.stone_mesh(), 0, 70, 1),
		sources.content(3)._part_hashes.slice(32, 64), "v9 stone lump")
	assert_equal(Grip.transform_digest(Meshes.pick_fit()), Grip.FIT_DIGEST, "approved pick fit")
	for source: int in 4:
		assert_equal(sources.content(source)._part_hashes.slice(0, 32).hex_encode(), Grip.DERIVED_DIGEST,
			"source %d body is the approved hand derivative" % source)
