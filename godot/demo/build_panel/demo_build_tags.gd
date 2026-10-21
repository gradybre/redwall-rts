extends RefCounted
## NAME TAGS THAT NEVER SIT ON EACH OTHER (decision 1913). The dug view's tags ("Way up to the surface", "Waiting for
## the mole", "Digging") and the names over the figures below are billboards on the same few metres: a mole digging
## beside the landing put its name on the way's. Each frame the level is shown, every shown tag is measured on screen
## (`screen_rect`: its anchor and its text's size through the camera) and `spread` lifts each one, in order, just clear
## of every one before it; the lift is the tag's own offset, so where each tag stands is never changed. The figures'
## names go first (they stay over their bodies); the fixed tags give way. A lift moves only when it changed by more
## than MOVE_PX (a Label3D redraws its text on a change). A tag drawn at a constant screen size (`fixed_size`: the
## Surface's, decision 2002) is measured at its drawn size: its world size grows with its depth before the camera, as
## the engine draws it. Presentation only.

## Screen pixels kept between two tags, and the least change of lift worth redrawing a tag for.
const GAP_PX: float = 8.0 # Decision 1991: 4 px left a crew's stacked tags cramped at 1280 x 720.
const MOVE_PX: float = 0.5
const LIFT_SLACK_PX: float = 0.01

var _rects: Array[Rect2] = []
var _scales: PackedFloat32Array = PackedFloat32Array()
var _lifts: PackedFloat32Array = PackedFloat32Array()
var _placed: Array[Rect2] = []


static func spread(rects: Array[Rect2], gap: float) -> PackedFloat32Array:
	"""How far up (screen px, >= 0) each rect is lifted so that it meets none before it, `gap` apart; the first is
	never lifted, and each is lifted no further than it must."""
	var lifts: PackedFloat32Array = PackedFloat32Array()
	var placed: Array[Rect2] = []
	spread_into(rects, gap, lifts, placed)
	return lifts


static func spread_into(rects: Array[Rect2], gap: float, lifts: PackedFloat32Array, placed: Array[Rect2]) -> void:
	"""`spread` into `lifts`, with `placed` as its working list (both cleared first; reused a frame)."""
	lifts.resize(rects.size())
	placed.clear()
	for k: int in rects.size():
		var clear: Rect2 = clear_of(rects[k], placed, gap)
		lifts[k] = rects[k].position.y - clear.position.y
		placed.append(clear)


static func clear_of(rect: Rect2, placed: Array[Rect2], gap: float) -> Rect2:
	"""`rect` lifted just above each placed rect it meets, until it meets none (it only rises, so it passes each placed
	rect at most once). A rect with no area (a tag behind the camera) is left where it is."""
	var out: Rect2 = rect
	if not rect.has_area():
		return out
	for _pass: int in placed.size() + 1:
		var hit: int = first_hit(out, placed, gap)
		if hit < 0:
			return out
		# LIFT_SLACK_PX more: Rect2's float32 sums could leave it one ulp short and meet the same rect again (review M3).
		out.position.y = placed[hit].position.y - gap - out.size.y - LIFT_SLACK_PX
	return out


static func first_hit(rect: Rect2, placed: Array[Rect2], gap: float) -> int:
	"""The first placed rect closer than `gap` to `rect` (touching at exactly `gap` is clear; one with no area is
	never met), or -1."""
	for k: int in placed.size():
		if placed[k].has_area() and rect.intersects(placed[k].grow(gap)):
			return k
	return -1


static func world_size(tag: Label3D, depth: float) -> Vector2:
	"""`tag`'s text's size in metres as drawn `depth` metres before the camera: its font's size at its pixel size, grown
	with the depth when it is drawn at a constant screen size (`fixed_size`)."""
	var font: Font = tag.font if tag.font != null else ThemeDB.fallback_font
	var size: Vector2 = font.get_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag.font_size) * tag.pixel_size
	return size * depth if tag.fixed_size else size


static func screen_rect(camera: Camera3D, tag: Label3D) -> Rect2:
	"""Where `tag`'s text is on screen with no lift (its anchor in the middle, as a billboard draws it); an empty rect
	when it is behind the camera."""
	var at: Vector3 = tag.global_position
	if camera.is_position_behind(at):
		return Rect2()
	var size: Vector2 = world_size(tag, -(camera.global_transform.affine_inverse() * at).z)
	var middle: Vector2 = camera.unproject_position(at)
	var half_w: float = middle.distance_to(camera.unproject_position(at + camera.global_basis.x * size.x / 2.0))
	var half_h: float = middle.distance_to(camera.unproject_position(at + camera.global_basis.y * size.y / 2.0))
	return Rect2(middle - Vector2(half_w, half_h), Vector2(half_w, half_h) * 2.0)


func space(camera: Camera3D, tags: Array[Label3D]) -> void:
	"""Lift `tags` (in order: the first never moves) so that none sits on another on `camera`'s screen."""
	_rects.clear()
	_scales.resize(tags.size())
	for k: int in tags.size():
		var rect: Rect2 = screen_rect(camera, tags[k])
		_rects.append(rect)
		var font: Font = tags[k].font if tags[k].font != null else ThemeDB.fallback_font
		var text_px: float = font.get_height(tags[k].font_size)
		_scales[k] = text_px / rect.size.y if rect.size.y > 0.0 else 0.0
	spread_into(_rects, GAP_PX, _lifts, _placed)
	for k: int in tags.size():
		var lift: float = _lifts[k] * _scales[k]
		if absf(tags[k].offset.y - lift) > MOVE_PX:
			tags[k].offset.y = lift


static func overlaps(camera: Camera3D, tags: Array[Label3D]) -> int:
	"""How many pairs of `tags` sit on each other on screen as drawn, lifts included (checks)."""
	var drawn: Array[Rect2] = []
	for tag: Label3D in tags:
		var rect: Rect2 = screen_rect(camera, tag)
		var font: Font = tag.font if tag.font != null else ThemeDB.fallback_font
		var scale: float = rect.size.y / font.get_height(tag.font_size) if rect.size.y > 0.0 else 0.0
		drawn.append(Rect2(rect.position - Vector2(0.0, tag.offset.y * scale), rect.size))
	var pairs: int = 0
	for a: int in drawn.size():
		for b: int in range(a + 1, drawn.size()):
			pairs += 1 if drawn[a].has_area() and drawn[b].has_area() and drawn[a].intersects(drawn[b]) else 0
	return pairs
