extends "res://test/framework/test_case.gd"
## ADR1201: actual pinned source images, the actual published Profile rows and the actual paid handling clock.
## Actors are recording subclasses over the real shared Palette (headless has no renderer to configure one).

const Presentation := preload("res://data/underground/mole-worker/mole_presentation.gd")
const ContentSet := preload("res://demo/cast/underground_content_set.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Actor := preload("res://demo/cast/underground_actor.gd")
const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Catalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const Assembly := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const Clock := preload("res://data/underground/mole-worker/qualified-assembly-v1/handling_clock.gd")
const Qualified := preload("res://test/test_mole_qualified_profiles.gd")
const PaidSuite := preload("res://test/test_underground_paid_assembly_handling.gd")
const ONE: int = 65536
const OTHER_SHA: String = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"


class RecordingActor extends Actor:
	## The real Palette samples every frame equation; only native part nodes are absent.
	var poses: int = 0
	var last_frames: PackedInt32Array = PackedInt32Array()

	func borrow(palette: Actor.Palette) -> void:
		"""Share the Content's own immutable Palette, exactly as Content.configure_actor does."""
		_palette = palette
		_scratch.resize(palette.scratch_count())
		_visible_parts = (1 << palette.part_count()) - 1

	func apply_pose(frames: PackedInt32Array) -> StringName:
		"""Real sampling validation; a refused frame leaves the recorded pose unchanged."""
		if _palette == null:
			return &"UNDERGROUND_ACTOR_UNBOUND"
		var code: StringName = _palette.sample_into(frames, _scratch)
		if code == &"":
			poses += 1
			last_frames = frames.duplicate()
		return code

	func set_parts_visible(mask: int) -> StringName:
		"""Same mask contract as the native Actor, over the Palette's part count."""
		if _palette == null or mask < 0 or mask >= (1 << _palette.part_count()):
			return &"UNDERGROUND_ACTOR_PART_MASK"
		_visible_parts = mask
		return &""


var _owned: Array[Node] = []


func after_each() -> void:
	"""Free every recording Actor node this suite created."""
	for node: Node in _owned:
		node.free()
	_owned.clear()


func _loaded(include_haul: bool) -> ContentSet:
	"""The pinned production table through the one public loader."""
	var sources: ContentSet = ContentSet.new()
	assert_equal(Presentation.load_sources(sources, include_haul), &"", "pinned source images")
	return sources


func _presenter(sources: ContentSet) -> Presentation:
	"""One recording Actor per loaded source, adopted hidden."""
	var result: Presentation = Presentation.new()
	assert_equal(result.configure(sources), &"", "actor and handling images bound")
	for source: int in ContentSet.MAX_SOURCES:
		if not sources.has_source(source):
			continue
		var actor: RecordingActor = RecordingActor.new()
		_owned.append(actor)
		actor.borrow(sources.content(source)._palette)
		assert_equal(result.adopt_actor(source, actor), &"", "source %d actor" % source)
		assert_equal(actor._visible_parts, 0, "adopted hidden")
	return result


func _masks(presenter: Presentation) -> PackedInt32Array:
	"""Visible part mask of every source's Actor (-1 when absent)."""
	var result: PackedInt32Array = PackedInt32Array()
	for source: int in ContentSet.MAX_SOURCES:
		var actor: Actor = presenter.actor(source)
		result.append(-1 if actor == null else actor._visible_parts)
	return result


func test_pinned_sources_load_inside_the_declared_set_reservation() -> void:
	"""Three exact images, each at its exact peak, summed into the Session's explicit set reservation."""
	var sources: ContentSet = _loaded(true)
	assert_equal(Session.HANDLING_ACTOR_SHA, Assembly.ACTOR_SHA, "handling pin is row 29's source digest")
	assert_equal(Session.HANDLING_ACTOR_SHA, Catalog.Pins.HANDLING_SOURCE_SHA, "same digest the catalog requires")
	assert_equal(Session.PRESENTATION_SET_BYTES, 21256576, "7141920 + 6628488 + 7486168")
	assert_equal(sources.reserved_bytes(), Session.PRESENTATION_SET_BYTES, "every source reserved, none shared")
	var peaks: PackedInt32Array = [Session.PRESENTATION_BYTES, Session.HANDLING_PRESENTATION_BYTES, Session.HAUL_PRESENTATION_BYTES]
	var clips: PackedInt32Array = [14, 3, 12]
	for source: int in 3:
		assert_equal(sources.content(source).required_peak_bytes(), peaks[source], "exact declared peak %d" % source)
		assert_equal(sources.content(source).clip_count(), clips[source], "clip count %d" % source)
	assert_equal(sources.content(2).source_digest(), Session.HAUL_ACTOR_SHA, "haul pin")
	for clip: int in 12:
		assert_equal(sources.clip_mask(2, clip), Presentation.HAUL_MASKS[clip], "haul clip %d mask" % clip)
	assert_equal(sources.clip_mask(1, 3), -1, "no fourth handling clip")
	assert_false(_loaded(false).has_source(2), "haul image stays optional")


func test_clip_spans_cover_every_frame_exactly_once() -> void:
	"""Frame-to-clip lookup is derived from the Content reader and is contiguous for loop and clamp clips."""
	var sources: ContentSet = _loaded(true)
	var frames: PackedInt32Array = [538, 112, 824]
	for source: int in 3:
		var expected: int = 0
		for frame: int in frames[source]:
			var clip: int = sources.clip_of_frame(source, frame)
			assert_true(clip == expected or clip == expected + 1, "source %d frame %d contiguous" % [source, frame])
			expected = clip
		assert_equal(expected, sources.content(source).clip_count() - 1, "last clip reached")
		assert_equal(sources.clip_of_frame(source, frames[source]), -1, "no frame past the image")
	assert_equal(sources.clip_of_frame(1, 57), 2, "recovery starts at frame 57")
	assert_equal(sources.clip_of_frame(2, 595), Presentation.HAUL_STAND, "stand span")


func test_set_refuses_wrong_digest_capacity_budget_masks_and_duplicates() -> void:
	"""Every refusal leaves the source absent and the reservation unchanged."""
	var sources: ContentSet = ContentSet.new()
	assert_equal(sources.load_source(0, Session.ACTOR_PATH, Session.Catalog.Pins.ACTOR_SHA, 1, Presentation.ACTOR_MASKS),
		&"CONTENT_SET_UNBOUND", "budget first")
	assert_equal(sources.configure(Session.PRESENTATION_SET_BYTES), &"", "set budget")
	assert_equal(sources.load_source(1, Session.HANDLING_ACTOR_PATH, OTHER_SHA, Session.HANDLING_PRESENTATION_BYTES,
		Presentation.HANDLING_MASKS), &"ACTOR_CONTENT_DIGEST", "wrong sha")
	assert_equal(sources.load_source(1, Session.HANDLING_ACTOR_PATH, Session.HANDLING_ACTOR_SHA,
		Session.HANDLING_PRESENTATION_BYTES, Presentation.ACTOR_MASKS), &"CONTENT_SET_CLIPS", "mask table must match clips")
	assert_equal(sources.load_source(1, Session.HANDLING_ACTOR_PATH, Session.HANDLING_ACTOR_SHA,
		Session.HANDLING_PRESENTATION_BYTES, PackedInt32Array([3, 4, 3])), &"CONTENT_SET_MASK", "only existing parts")
	assert_equal(sources.load_source(1, Session.HANDLING_ACTOR_PATH, Session.HANDLING_ACTOR_SHA,
		Session.HANDLING_PRESENTATION_BYTES - 1, Presentation.HANDLING_MASKS), &"ACTOR_CONTENT_PRESENTATION_RESERVE", "exact peak")
	var many: PackedInt32Array = PackedInt32Array()
	many.resize(Content.MAX_CLIPS + 1)
	many.fill(3)
	var header: String = _seventeen_clip_header()
	assert_equal(sources.load_source(1, header, OTHER_SHA, 1000000, many), &"CONTENT_SET_ARGUMENT", "mask table capped")
	assert_equal(sources.load_source(1, header, OTHER_SHA, 1000000, Presentation.HANDLING_MASKS),
		&"ACTOR_CONTENT_CAPACITY", "MAX_CLIPS stays 16")
	assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(header)), OK, "owned candidate removed")
	assert_equal(sources.load_source(3, Session.HANDLING_ACTOR_PATH, Session.HANDLING_ACTOR_SHA,
		Session.HANDLING_PRESENTATION_BYTES, Presentation.HANDLING_MASKS), &"CONTENT_SET_ARGUMENT", "three sources")
	assert_equal(sources.reserved_bytes(), 0, "nothing admitted")
	assert_equal(sources.load_source(1, Session.HANDLING_ACTOR_PATH, Session.HANDLING_ACTOR_SHA,
		Session.HANDLING_PRESENTATION_BYTES, Presentation.HANDLING_MASKS), &"", "exact handling image")
	assert_equal(sources.load_source(1, Session.HANDLING_ACTOR_PATH, Session.HANDLING_ACTOR_SHA,
		Session.HANDLING_PRESENTATION_BYTES, Presentation.HANDLING_MASKS), &"CONTENT_SET_SOURCE_LOADED", "immutable slot")
	assert_equal(sources.load_source(2, Session.HANDLING_ACTOR_PATH, Session.HANDLING_ACTOR_SHA,
		Session.HANDLING_PRESENTATION_BYTES, Presentation.HANDLING_MASKS), &"CONTENT_SET_DUPLICATE", "one image per source")
	assert_equal(sources.load_source(0, Session.ACTOR_PATH, Session.Catalog.Pins.ACTOR_SHA,
		Session.PRESENTATION_SET_BYTES, Presentation.ACTOR_MASKS), &"CONTENT_SET_BUDGET", "sum stays inside the budget")
	assert_equal(sources.reserved_bytes(), Session.HANDLING_PRESENTATION_BYTES, "only the admitted image")
	assert_equal(Presentation.new().configure(sources), &"MOLE_PRESENTATION_INPUT", "actor image required")


func _seventeen_clip_header() -> String:
	"""A header-only candidate whose clip count exceeds MAX_CLIPS; it is refused before any table read."""
	var path: String = "user://mole-presentation-17-clips-%d.bin" % get_instance_id()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("UGACNT01".to_ascii_buffer())
	for value: int in [1, 1, 1, Content.MAX_CLIPS + 1, 2, 12]:
		file.store_32(value)
	var rest: PackedByteArray = PackedByteArray()
	rest.resize(Content.HEADER_BYTES - 32)
	file.store_buffer(rest)
	file.close()
	return path


func test_haul_clips_apply_their_own_mask_and_hidden_actors_keep_their_pose() -> void:
	"""Selecting a clip applies its mask; switching source hides the others without posing them."""
	var presenter: Presentation = _presenter(_loaded(true))
	var pick: RecordingActor = presenter.actor(0) as RecordingActor
	var haul: RecordingActor = presenter.actor(2) as RecordingActor
	assert_equal(presenter.present_clip(0, 3, 4 * ONE), &"", "pick entry clip")
	assert_equal(_masks(presenter), PackedInt32Array([3, 0, 0]), "only the actor image shows")
	var pick_frames: PackedInt32Array = pick.last_frames.duplicate()
	for clip: int in 12:
		assert_equal(presenter.present_clip(2, clip, ONE), &"", "haul clip %d" % clip)
		assert_equal(_masks(presenter), PackedInt32Array([0, 0, Presentation.HAUL_MASKS[clip]]), "haul clip %d mask" % clip)
	assert_equal(presenter.visible_source(), 2, "haul visible")
	assert_equal(pick.poses, 1, "hidden actor not posed")
	assert_equal(pick.last_frames, pick_frames, "hidden actor pose stable")
	assert_equal(haul.poses, 12, "one pose per haul clip")
	var blend: PackedInt32Array = [595, 596, 0, 311, 312, 0, ONE / 2]
	assert_equal(presenter._sources.frames_mask(2, blend), -1, "stand-to-carry blend has no single mask")
	assert_equal(presenter.present_clip(2, 12, 0), &"ACTOR_CONTENT_CLIP_QUERY", "no thirteenth clip")
	assert_equal(_masks(presenter), PackedInt32Array([0, 0, 3]), "refusal changes nothing")


func test_absent_haul_source_refuses_without_changing_the_shown_actor() -> void:
	"""Content-5 haul rows may arrive before the haul image; presentation then refuses rather than substituting."""
	var presenter: Presentation = _presenter(_loaded(false))
	assert_equal(presenter.present_clip(1, 0, 0), &"", "handling entry")
	assert_equal(presenter.present_clip(2, Presentation.HAUL_STAND, 0), &"MOLE_PRESENTATION_SOURCE_ABSENT", "no haul image")
	assert_equal(_masks(presenter), PackedInt32Array([0, 3, -1]), "handling actor still shown")
	assert_equal(presenter.visible_source(), 1, "unchanged selection")


func test_profile_rows_select_the_actor_of_their_own_source_digest() -> void:
	"""Rows 0 and 29 of the actual published catalog choose source 0 and source 1 by profile_matches."""
	var fixture: Qualified = Qualified.new()
	fixture.before_each()
	var profiles: Presentation.Routes.Profiles = fixture._fixture._profiles
	var presenter: Presentation = _presenter(_loaded(true))
	var sources: ContentSet = presenter._sources
	var content: int = Catalog.CONTENT_REVISION
	assert_equal(sources.source_for_row(profiles, 0, 1, content), 0, "stand row is the actor image")
	assert_equal(sources.source_for_row(profiles, Assembly.PROFILE, 1, content), 1, "row 29 is the assembly image")
	assert_equal(sources.source_for_row(profiles, Assembly.PROFILE, 2, content), -1, "exact revision")
	var frame: Driver.Frame = _frame(sources, 1, 0, Assembly.PROFILE, content)
	assert_equal(presenter.present(profiles, frame), &"", "row 29 frame")
	assert_equal(_masks(presenter), PackedInt32Array([0, 3, 0]), "assembly actor shown")
	frame = _frame(sources, 0, 1, 0, content)
	assert_equal(presenter.present(profiles, frame), &"", "stand row frame")
	assert_equal(_masks(presenter), PackedInt32Array([3, 0, 0]), "actor image shown again")
	frame = _frame(sources, 0, 1, Assembly.PROFILE, content)
	assert_equal(presenter.present(profiles, frame), &"MOLE_PRESENTATION_FRAME_SOURCE", "row 29 cannot draw pick frames")
	assert_equal(_masks(presenter), PackedInt32Array([3, 0, 0]), "refusal changes nothing")
	fixture.after_each()
	assert_true(fixture.failures.is_empty(), "qualified fixture: %s" % fixture.failures)


func _frame(sources: ContentSet, source: int, clip: int, profile: int, content: int) -> Driver.Frame:
	"""A source-clip frame bound to one actual row tuple."""
	var frame: Driver.Frame = Driver.Frame.new()
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0])
	assert_equal(sources.content(source).clip_into(clip, ONE, pose), &"", "source clip pose")
	for index: int in 3:
		frame.frames[index] = pose[index]
		frame.frames[index + 3] = pose[index]
	frame.source_digest = sources.content(source).source_digest()
	frame.profile_id = profile
	frame.profile_revision = 1
	frame.content_revision = content
	return frame


func test_row_29_handling_cycle_is_drawn_from_the_actual_clock() -> void:
	"""Actual paid L0 handling: READY, thirty entry ticks, thirty recovery ticks, HANDLED_READY on the assembly actor."""
	var probe: PaidSuite.PaidProbe = PaidSuite.PaidProbe.new()
	probe.before_each()
	var project: Vector2i = probe.prepare_l0()
	assert_true(project != Vector2i(-1, 0), "actual L0 prepared: %s" % probe.failures)
	if project == Vector2i(-1, 0):
		probe.after_each()
		return
	var job: int = probe._router._primary_row(project)
	probe.deliver_installation_inputs(project, job)
	probe.retire_first_pair(project, job)
	assert_true(probe._router.start_work(project, 0).ok, "actual paid START")
	var routes: Presentation.Routes = probe._world._routes
	var worker: Vector2i = probe._world._worker
	var ref: Vector2i = probe._world._jobs.ref_of(job)
	var presenter: Presentation = _presenter(_loaded(false))
	var frame: Driver.Frame = Driver.Frame.new()
	assert_equal(presenter.present_handling(routes, worker, ref, frame), &"", "READY handling frame")
	assert_equal([frame.phase, frame.frames[0], frame.ready], [Clock.READY, 0, true], "seat entry first pose")
	assert_equal(routes.begin_assembly_handling(worker, ref), &"", "actual handling entry")
	_handling_ticks(probe, presenter, routes, worker, ref, frame)
	assert_equal(presenter.present_handling(routes, worker, ref, frame), &"", "completed handling frame")
	assert_equal([frame.phase, frame.frames[0], frame.frames[1], frame.ready], [Clock.HANDLED_READY, 111, 111, true],
		"recovery final pose")
	assert_equal(_masks(presenter), PackedInt32Array([0, 3, -1]), "pick actor hidden throughout")
	assert_equal((presenter.actor(0) as RecordingActor).poses, 0, "pick actor never posed by handling")
	assert_equal(presenter.handling_frame_into(routes, worker, Vector2i(ref.x, ref.y + 1), frame),
		&"MOLE_PRESENTATION_NOT_HANDLING", "exact Job generation")
	probe.after_each()
	assert_true(probe.failures.is_empty(), "actual paid fixture: %s" % probe.failures)


func _handling_ticks(probe: PaidSuite.PaidProbe, presenter: Presentation, routes: Presentation.Routes,
		worker: Vector2i, ref: Vector2i, frame: Driver.Frame) -> void:
	"""Each accepted tick's clock word maps onto the entry then recovery clip with no frame moving backwards."""
	var previous: int = -1
	for tick: int in 60:
		assert_equal(presenter.present_handling(routes, worker, ref, frame), &"", "tick %d frame" % tick)
		var expected_phase: int = Clock.ENTRY if tick < 30 else Clock.RECOVERY
		@warning_ignore("integer_division") var interval: int = (tick % 30) * Clock.SOURCE_INTERVALS / Clock.TRANSITION_TICKS
		var first: int = 0 if tick < 30 else 57
		assert_equal([frame.phase, frame.frames[0], frame.ready], [expected_phase, first + interval, false], "tick %d pose" % tick)
		assert_true(frame.frames[0] >= previous, "monotone source frames")
		previous = frame.frames[0]
		assert_equal(presenter.visible_source(), Presentation.SOURCE_HANDLING, "handling actor shown")
		routes.advance_tick(probe._tick)
		probe._tick += 1
