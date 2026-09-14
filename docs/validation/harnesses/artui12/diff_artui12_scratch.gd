extends SceneTree
## ART-UI-12 cycle-01 capture comparator. Counts differing pixels between two captures, over
## the whole frame and inside one named rectangle, exactly and with no tolerance.
##
## RETAINED, NOT SCRATCH. The `_scratch` in the filename is historical; see the sibling
## capture harness for why it is back and why it lives under `docs/validation/`.
##
## Run from the repository root:
##
##   godot --headless --path godot \
##       --script ../docs/validation/harnesses/artui12/diff_artui12_scratch.gd \
##       -- <absolute-a.png> <absolute-b.png> <x> <y> <w> <h>
##
## Headless is correct HERE and only here: this reads PNG files off disk and never asks the
## window for its framebuffer, so the dummy renderer's null `get_image()` cannot bite.

var _frames: int = 0


func _initialize() -> void:
	"""Compare the two named captures and print both counts."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var first: Image = Image.load_from_file(args[0])
	var second: Image = Image.load_from_file(args[1])
	var region: Rect2i = Rect2i(int(args[2]), int(args[3]), int(args[4]), int(args[5]))
	print("[diff] a=%s b=%s region=%s" % [args[0].get_file(), args[1].get_file(), region])
	var whole: Rect2i = Rect2i(0, 0, first.get_width(), first.get_height())
	print("[diff] whole frame differing pixels = %d of %d bounds=%s" % [
		_count(first, second, whole), whole.size.x * whole.size.y, _bounds(first, second, whole)])
	print("[diff] alert rectangle differing pixels = %d of %d bounds=%s" % [
		_count(first, second, region), region.size.x * region.size.y,
		_bounds(first, second, region)])


func _bounds(first: Image, second: Image, region: Rect2i) -> Rect2i:
	"""The tightest rectangle holding every differing pixel inside `region`."""
	var found: bool = false
	var box: Rect2i = Rect2i()
	for y: int in range(region.position.y, region.position.y + region.size.y):
		for x: int in range(region.position.x, region.position.x + region.size.x):
			if first.get_pixel(x, y) == second.get_pixel(x, y):
				continue
			if not found:
				found = true
				box = Rect2i(x, y, 1, 1)
			else:
				box = box.expand(Vector2i(x, y))
	return box


func _process(_delta: float) -> bool:
	"""Quit on the first frame whatever happened, so no run can hang."""
	_frames += 1
	return _frames >= 1


func _count(first: Image, second: Image, region: Rect2i) -> int:
	"""Differing pixels inside one rectangle, compared exactly and with no tolerance."""
	var differing: int = 0
	for y: int in range(region.position.y, region.position.y + region.size.y):
		for x: int in range(region.position.x, region.position.x + region.size.x):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				differing += 1
	return differing
