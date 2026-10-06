extends RefCounted
## ADR1201 per-source mole presentation: one Actor per loaded source image, chosen by the row's source digest.
## Presentation only. It reads the actual Routes owner and never advances a clock or grants work or movement.

const ContentSet := preload("res://demo/cast/underground_content_set.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Actor := preload("res://demo/cast/underground_actor.gd")
const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Assembly := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const Clock := preload("res://data/underground/mole-worker/qualified-assembly-v1/handling_clock.gd")
const ONE: int = 65536
const SOURCE_ACTOR: int = 0
const SOURCE_HANDLING: int = 1
const SOURCE_HAUL: int = 2
# Body = part 0, held item (pick or haul stock) = part 1. Every pick clip shows both parts.
const ACTOR_MASKS: PackedInt32Array = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
const HANDLING_MASKS: PackedInt32Array = [3, 3, 3]
# haul-handling-v1 native-program-v8 plan.json part_visibility_masks (ADR1198 step 4a).
const HAUL_MASKS: PackedInt32Array = [3, 3, 3, 3, 3, 3, 3, 3, 1, 1, 3, 3]
# Haul image clip ordinals, in plan order. Rows that select them are content-5 work (ADR1198 step 4).
const HAUL_APPROACH: int = 0
const HAUL_LIFT: int = 1
const HAUL_PLACE: int = 2
const HAUL_RECOVERY: int = 3
const HAUL_HOLD: int = 4
const HAUL_ENTER: int = 5
const HAUL_CARRY: int = 6
const HAUL_EXIT: int = 7
const HAUL_STAND: int = 8
const HAUL_WALK: int = 9
const HAUL_ENTER_HAUL: int = 10
const HAUL_LEAVE_HAUL: int = 11
const HANDLING_ENTRY_CLIP: int = 0
const HANDLING_RECOVERY_CLIP: int = 2

var _sources: ContentSet = null
var _actors: Array[Actor] = []
var _visible: int = -1
var _actor: Routes.Actor = Routes.Actor.new()
var _state: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
var _clock: PackedInt32Array = PackedInt32Array([0, 0])
var _pose: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _frames: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, ONE])


static func load_sources(sources: ContentSet, include_haul: bool) -> StringName:
	"""Actor and assembly images are required; the haul image is optional until content 5 publishes it."""
	if sources == null:
		return &"MOLE_PRESENTATION_INPUT"
	var code: StringName = sources.configure(Session.PRESENTATION_SET_BYTES)
	if code == &"":
		code = sources.load_source(SOURCE_ACTOR, Session.ACTOR_PATH, Session.Catalog.Pins.ACTOR_SHA,
			Session.PRESENTATION_BYTES, ACTOR_MASKS)
	if code == &"":
		code = sources.load_source(SOURCE_HANDLING, Session.HANDLING_ACTOR_PATH, Session.HANDLING_ACTOR_SHA,
			Session.HANDLING_PRESENTATION_BYTES, HANDLING_MASKS)
	if code == &"":
		code = handling_timing_refusal(sources.content(SOURCE_HANDLING))
	if code == &"" and include_haul:
		code = sources.load_source(SOURCE_HAUL, Session.HAUL_ACTOR_PATH, Session.HAUL_ACTOR_SHA,
			Session.HAUL_PRESENTATION_BYTES, HAUL_MASKS)
	return code


static func handling_timing_refusal(image: Content) -> StringName:
	"""The handling clock reads clips 0 and 2 over exactly SOURCE_INTERVALS clamped source intervals."""
	var timing: PackedInt32Array = PackedInt32Array([0, 0])
	if image == null or image.source_digest() != Assembly.ACTOR_SHA:
		return &"MOLE_PRESENTATION_HANDLING_SOURCE"
	for clip: int in [HANDLING_ENTRY_CLIP, HANDLING_RECOVERY_CLIP]:
		if not image.clip_timing_into(clip, timing) or timing[0] != Clock.SOURCE_INTERVALS * ONE or timing[1] != 0:
			return &"MOLE_PRESENTATION_HANDLING_SOURCE"
	return &""


func configure(sources: ContentSet) -> StringName:
	"""Bind one loaded set; the actor and handling images must both be present."""
	if _sources != null:
		return &"MOLE_PRESENTATION_ALREADY_BOUND"
	if sources == null or not sources.has_source(SOURCE_ACTOR) or not sources.has_source(SOURCE_HANDLING) \
			or handling_timing_refusal(sources.content(SOURCE_HANDLING)) != &"":
		return &"MOLE_PRESENTATION_INPUT"
	_sources = sources
	_actors.resize(ContentSet.MAX_SOURCES)
	return &""


func configure_actor(source: int, bound: Actor, meshes: Array[Mesh], materials: Array[Material]) -> StringName:
	"""Bind an Actor to one source's shared Palette (Content.configure_actor), then adopt it hidden."""
	if _sources == null or not _sources.has_source(source):
		return &"MOLE_PRESENTATION_SOURCE_ABSENT"
	var code: StringName = _sources.content(source).configure_actor(bound, meshes, materials)
	return adopt_actor(source, bound) if code == &"" else code


func adopt_actor(source: int, bound: Actor) -> StringName:
	"""Accept an Actor already configured from this source's own image; it starts hidden."""
	if _sources == null or not _sources.has_source(source):
		return &"MOLE_PRESENTATION_SOURCE_ABSENT"
	if bound == null or bound._palette == null \
			or bound._palette.source_digest() != _sources.content(source).source_digest():
		return &"MOLE_PRESENTATION_ACTOR_SOURCE"
	if _actors[source] != null:
		return &"MOLE_PRESENTATION_ACTOR_BOUND"
	var code: StringName = bound.set_parts_visible(0)
	if code == &"":
		_actors[source] = bound
	return code


func present(profiles: Routes.Profiles, frame: Driver.Frame) -> StringName:
	"""Show the Actor whose image is the row's Profile source; apply the frame clip's part mask; hide the rest."""
	if _sources == null or frame == null or frame.frames.size() != 7:
		return &"MOLE_PRESENTATION_UNBOUND"
	var source: int = _sources.source_for_row(profiles, frame.profile_id, frame.profile_revision, frame.content_revision)
	if source < 0:
		return &"MOLE_PRESENTATION_ROW_SOURCE"
	if _sources.content(source).source_digest() != frame.source_digest:
		return &"MOLE_PRESENTATION_FRAME_SOURCE"
	return _show(source, frame.frames)


func present_clip(source: int, clip: int, time_q16: int) -> StringName:
	"""Show one clip of one source directly (haul modes); an absent source refuses without changing anything."""
	if _sources == null:
		return &"MOLE_PRESENTATION_UNBOUND"
	if not _sources.has_source(source):
		return &"MOLE_PRESENTATION_SOURCE_ABSENT"
	var code: StringName = _sources.content(source).clip_into(clip, time_q16, _pose)
	if code != &"":
		return code
	for index: int in 3:
		_frames[index] = _pose[index]
		_frames[index + 3] = _pose[index]
	_frames[6] = ONE
	return _show(source, _frames)


func _show(source: int, frames: PackedInt32Array) -> StringName:
	"""Every check precedes the first visible change; hidden Actors keep their last pose untouched."""
	var mask: int = _sources.frames_mask(source, frames)
	if mask < 1:
		return &"MOLE_PRESENTATION_CLIP_MASK"
	var shown: Actor = _actors[source]
	if shown == null:
		return &"MOLE_PRESENTATION_ACTOR"
	var code: StringName = shown.apply_pose(frames)
	if code == &"":
		code = shown.set_parts_visible(mask)
	if code != &"":
		return code
	for other: int in _actors.size():
		if other != source and _actors[other] != null:
			_actors[other].set_parts_visible(0)
	_visible = source
	return &""


func handling_frame_into(routes: Routes, worker: Vector2i, job: Vector2i, out: Driver.Frame) -> StringName:
	"""Row 29: read the actual handling clock word and map it onto the assembly image; output is preserved on refusal."""
	if _sources == null or routes == null or out == null or out.frames.size() != 7:
		return &"MOLE_PRESENTATION_UNBOUND"
	var code: StringName = routes.read_actor_into(worker, _actor)
	if code != &"":
		return code
	if _actor.profile_id != Assembly.PROFILE or _actor.job != job:
		return &"MOLE_PRESENTATION_NOT_HANDLING"
	if _sources.source_for_row(routes._profiles, Assembly.PROFILE, _actor.profile_revision,
			_actor.content_revision) != SOURCE_HANDLING:
		return &"MOLE_PRESENTATION_ROW_SOURCE"
	code = Routes.source_state_leaf_into(routes, worker, job, Assembly.PROFILE, _actor.profile_revision,
		_actor.content_revision, _state)
	if code == &"":
		code = Clock.source_into(_state[0], _state[1], _clock)
	if code == &"":
		code = _sources.content(SOURCE_HANDLING).clip_into(_clock[0], _clock[1], _pose)
	if code != &"":
		return code
	_publish_handling(worker, job, out)
	return &""


func _publish_handling(worker: Vector2i, job: Vector2i, out: Driver.Frame) -> void:
	"""Single unconditional output write after every handling read succeeded."""
	for index: int in 3:
		out.frames[index] = _pose[index]
		out.frames[index + 3] = _pose[index]
	out.frames[6] = ONE
	out.source_digest = _sources.content(SOURCE_HANDLING).source_digest()
	out.worker = worker
	out.job = job
	out.tool = _actor.tool
	out.point = _actor.point
	out.yaw = _actor.yaw
	out.phase = _state[0]
	out.ready = _state[0] == Clock.READY or _state[0] == Clock.HANDLED_READY
	out.profile_id = Assembly.PROFILE
	out.profile_revision = _actor.profile_revision
	out.content_revision = _actor.content_revision


func present_handling(routes: Routes, worker: Vector2i, job: Vector2i, out: Driver.Frame) -> StringName:
	"""Read the row-29 frame, then present it through the same source-digest selection as every row."""
	var code: StringName = handling_frame_into(routes, worker, job, out)
	return present(routes._profiles, out) if code == &"" else code


func visible_source() -> int:
	"""The source whose Actor was last shown, or -1."""
	return _visible


func actor(source: int) -> Actor:
	"""The adopted Actor for one source, or null."""
	if source < 0 or source >= _actors.size():
		return null
	return _actors[source]


func release() -> void:
	"""Drop Actor and set references; the host owns and frees the Actor nodes."""
	_actors.clear()
	_sources = null
	_visible = -1
