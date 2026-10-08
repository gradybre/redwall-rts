extends RefCounted
## ADR1201/1211: one immutable presentation Content per profile source image, inside one declared byte budget.
## Presentation only. A loaded image grants no movement, work, contact or Profile permission.

const Content := preload("res://demo/cast/underground_actor_content.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const MAX_SOURCES: int = 6 # ADR1211/1217: actor, assembly handling, wood haul, stone haul, claw, paw handling.
const CLIP_STRIDE: int = Content.MAX_CLIPS + 1

var _contents: Array[Content] = []
var _masks: PackedInt32Array = PackedInt32Array() # MAX_SOURCES x MAX_CLIPS part masks; 0 = absent clip.
var _spans: PackedInt32Array = PackedInt32Array() # MAX_SOURCES x CLIP_STRIDE first frames, last entry = frame end.
var _reserves: PackedInt64Array = PackedInt64Array() # Declared admission per source; 0 = absent.
var _budget: int = 0
var _timing: PackedInt32Array = PackedInt32Array([0, 0])
var _pose: PackedInt32Array = PackedInt32Array([0, 0, 0])


func configure(total_bytes: int) -> StringName:
	"""Fix the total declared reservation before any image is admitted; tables are cold and bounded."""
	if _budget != 0:
		return &"CONTENT_SET_ALREADY_CONFIGURED"
	if total_bytes <= 0:
		return &"CONTENT_SET_ARGUMENT"
	_contents.resize(MAX_SOURCES)
	_masks.resize(MAX_SOURCES * Content.MAX_CLIPS)
	_spans.resize(MAX_SOURCES * CLIP_STRIDE)
	_reserves.resize(MAX_SOURCES)
	_budget = total_bytes
	return &""


func load_source(source: int, path: String, digest: String, reserve_bytes: int, masks: PackedInt32Array) -> StringName:
	"""Exact sha-pinned image with one part mask per clip; any refusal leaves the source absent."""
	var code: StringName = _admission_refusal(source, digest, reserve_bytes, masks)
	if code != &"":
		return code
	var image: Content = Content.new()
	code = image.load_file(path, digest, reserve_bytes)
	if code == &"":
		code = _shape_refusal(source, image, masks)
	if code != &"":
		return code
	for clip: int in masks.size():
		_masks[source * Content.MAX_CLIPS + clip] = masks[clip]
	_contents[source] = image
	_reserves[source] = reserve_bytes
	return &""


func _admission_refusal(source: int, digest: String, reserve_bytes: int, masks: PackedInt32Array) -> StringName:
	"""Index, budget and digest uniqueness are checked before the image file is opened."""
	if _budget == 0:
		return &"CONTENT_SET_UNBOUND"
	if source < 0 or source >= MAX_SOURCES or reserve_bytes <= 0 or masks.is_empty() \
			or masks.size() > Content.MAX_CLIPS:
		return &"CONTENT_SET_ARGUMENT"
	if _contents[source] != null:
		return &"CONTENT_SET_SOURCE_LOADED"
	if reserved_bytes() + reserve_bytes > _budget:
		return &"CONTENT_SET_BUDGET"
	for other: Content in _contents:
		if other != null and other.source_digest() == digest:
			return &"CONTENT_SET_DUPLICATE"
	return &""


func _shape_refusal(source: int, image: Content, masks: PackedInt32Array) -> StringName:
	"""The declared mask table must name every clip and only parts the image actually has."""
	if image.clip_count() != masks.size():
		return &"CONTENT_SET_CLIPS"
	for mask: int in masks:
		if mask < 1 or mask >= (1 << image.part_count()):
			return &"CONTENT_SET_MASK"
	return _record_spans(source, image)


func _record_spans(source: int, image: Content) -> StringName:
	"""Frame spans come from the Content's own clip reader; an absent source's stale spans are never read."""
	for clip: int in image.clip_count():
		if not image.clip_timing_into(clip, _timing) or image.clip_into(clip, 0, _pose) != &"":
			return &"CONTENT_SET_CLIPS"
		_spans[source * CLIP_STRIDE + clip] = _pose[0]
		# A looping clip's final interval wraps to its first frame, so its last start frame is read instead.
		var looping: bool = _timing[1] == 1
		if image.clip_into(clip, _timing[0] - 1 if looping else _timing[0], _pose) != &"":
			return &"CONTENT_SET_CLIPS"
		_spans[source * CLIP_STRIDE + clip + 1] = _pose[0] + (2 if looping else 1)
	return &""


func content(source: int) -> Content:
	"""The loaded immutable image, or null when that source is absent."""
	if source < 0 or source >= _contents.size():
		return null
	return _contents[source]


func has_source(source: int) -> bool:
	"""True only after a complete pinned load."""
	return content(source) != null


func reserved_bytes() -> int:
	"""Sum of every admitted source's declared reservation; never a measured allocation."""
	var total: int = 0
	for value: int in _reserves:
		total += value
	return total


func budget_bytes() -> int:
	"""The single declared presentation-set budget."""
	return _budget


func clip_mask(source: int, clip: int) -> int:
	"""Part-visibility mask for one clip, or -1 for an absent source or clip."""
	var loaded: Content = content(source)
	if loaded == null or clip < 0 or clip >= loaded.clip_count():
		return -1
	return _masks[source * Content.MAX_CLIPS + clip]


func clip_of_frame(source: int, frame: int) -> int:
	"""The clip whose contiguous span holds one absolute palette frame, or -1."""
	var loaded: Content = content(source)
	if loaded == null:
		return -1
	for clip: int in loaded.clip_count():
		if frame >= _spans[source * CLIP_STRIDE + clip] and frame < _spans[source * CLIP_STRIDE + clip + 1]:
			return clip
	return -1


func frames_mask(source: int, frames: PackedInt32Array) -> int:
	"""One mask for a seven-int frame equation; frames spanning clips with different masks refuse (-1)."""
	if frames.size() != 7:
		return -1
	var mask: int = clip_mask(source, clip_of_frame(source, frames[0]))
	for index: int in [1, 3, 4]:
		if clip_mask(source, clip_of_frame(source, frames[index])) != mask:
			return -1
	return mask


func source_for_row(profiles: Profiles, profile: int, revision: int, content_revision: int) -> int:
	"""Select the image whose digest equals the row's own Profile source digest (Content.profile_matches)."""
	for source: int in _contents.size():
		if _contents[source] != null and _contents[source].profile_matches(profiles, profile, revision, content_revision):
			return source
	return -1
