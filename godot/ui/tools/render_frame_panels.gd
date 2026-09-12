extends SceneTree
## Render each container frame onto a flat panel, at three sizes, as review PNGs.
##
## The point of these images is to show PLACEMENT, so they are composed through the SAME
## `ui_frame_geometry.gd` the runtime builder uses: every piece is blitted at the rectangle
## `rects_into()` returns, rasterised from its own SVG at its authored size and scaled only
## along its run. Nothing here re-implements the contract, so a sheet that looks right is
## evidence about the contract rather than about this script.
##
## The flat opaque fill is drawn first because the renderer owns it -- frames are edge and
## corner art over a fill, never a replacement for it.
##
## Run: `godot --headless --path godot --script ui/tools/render_frame_panels.gd`
## Then: `python3 godot/ui/tools/build_frame_sheet.py` to label and assemble the sheet.
## This is a developer tool. Nothing in the game loads it.

const ART: GDScript = preload("res://ui/ui_art.gd")
const Geometry: GDScript = preload("res://ui/ui_frame_geometry.gd")

const EXPORT_DIRECTORY: String = "res://ui/review/exports"

## The same three sizes `test/test_ui_frame_geometry.gd` asserts the built tree at.
const SHEET_SIZES: Array[Vector2i] = [
	Vector2i(132, 76), Vector2i(300, 120), Vector2i(760, 96),
]

## FOREST panel fill, §2.1 token SURFACE. The frames sit on this, they do not supply it.
const PANEL_FILL: Color = Color("#1E3028")


func _init() -> void:
	"""Render every frame at every sheet size, then report the count."""
	DirAccess.make_dir_recursive_absolute(EXPORT_DIRECTORY)
	var written: int = 0
	for frame: int in Geometry.frame_count():
		for panel_size: Vector2i in SHEET_SIZES:
			if _render_one(frame, panel_size):
				written += 1
	print("frame-panels: wrote %d PNG(s) to %s" % [written, EXPORT_DIRECTORY])
	quit(0 if written == Geometry.frame_count() * SHEET_SIZES.size() else 1)


func _render_one(frame: int, panel_size: Vector2i) -> bool:
	"""Compose one panel and save it. Returns false and complains on any refusal."""
	var rects: Array[Rect2] = []
	if not Geometry.rects_into(frame, Vector2(panel_size), rects):
		push_error("frame-panels: %s refuses %v"
			% [Geometry.refusal_for(frame, Vector2(panel_size)), panel_size])
		return false
	var canvas: Image = Image.create_empty(
		panel_size.x, panel_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(PANEL_FILL)
	for piece: int in Geometry.PIECE_COUNT:
		if not _blit_piece(canvas, frame, piece, rects[piece]):
			return false
	var key: String = String(ART.FRAME_KEYS[frame])
	var target: String = "%s/frame_%s_%dx%d.png" % [
		EXPORT_DIRECTORY, key, panel_size.x, panel_size.y]
	return canvas.save_png(ProjectSettings.globalize_path(target)) == OK


func _blit_piece(canvas: Image, frame: int, piece: int, rect: Rect2) -> bool:
	"""Rasterise one piece and blend it at its computed rectangle. False if it will not load."""
	var index: int = Geometry.registry_index_of(frame, piece)
	var source: Image = ART.rasterise(ART.source_path_of(index), ART.optical_sizes_of(index)[0])
	if source == null:
		push_error("frame-panels: could not rasterise %s" % ART.source_path_of(index))
		return false
	var target_size: Vector2i = Vector2i(rect.size.round())
	if source.get_size() != target_size:
		source.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	canvas.blend_rect(source, Rect2i(Vector2i.ZERO, target_size),
		Vector2i(rect.position.round()))
	return true
