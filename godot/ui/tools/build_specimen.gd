extends SceneTree
## Assemble the five panel silhouettes from their own edge and corner art and export them.
##
## This is the specimen that ART-UI-02 asks for: the five containers together on a neutral
## background, each built the way a renderer would build it -- a flat token fill, four
## stretched edge strips and four corner pieces that are never scaled. Nothing here crops a
## composite: every pixel comes from a declared SVG source through `ui_art.gd`.
##
## Run: `godot --headless --path godot --script ui/tools/build_specimen.gd`

const ART: GDScript = preload("res://ui/ui_art.gd")

const OUTPUT: String = "res://ui/review/exports/specimen_panels.png"
const NEUTRAL: Color = Color("#9A9A96")
const FOREST_FILL: Color = Color("#1E3028")
const PAPER_FILL: Color = Color("#EAE1C8")

const FRAME_TRAY: int = 0
const FRAME_TIME: int = 1
const FRAME_FOLIO: int = 2
const FRAME_JOURNAL: int = 3
const FRAME_DOCK: int = 4

## Sheet geometry: x, y, width, height per silhouette, then the fill each one uses.
const PLACEMENT: Array[int] = [
	24, 24, 452, 120,
	500, 24, 236, 96,
	24, 176, 260, 200,
	500, 152, 300, 380,
	24, 408, 452, 96,
]


func _init() -> void:
	"""Compose the specimen sheet and report where it landed."""
	var sheet: Image = Image.create(824, 556, false, Image.FORMAT_RGBA8)
	sheet.fill(NEUTRAL)
	for frame: int in ART.frame_count():
		_draw_frame(sheet, frame)
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	var status: int = sheet.save_png(OUTPUT)
	print("specimen: %s (%d)" % [OUTPUT, status])
	quit(0 if status == OK else 1)


func _draw_frame(sheet: Image, frame: int) -> void:
	"""Fill one panel rectangle with its token colour, then lay its edges and corners."""
	var at: int = frame * 4
	var rect: Rect2i = Rect2i(PLACEMENT[at], PLACEMENT[at + 1],
		PLACEMENT[at + 2], PLACEMENT[at + 3])
	var fill: Color = PAPER_FILL if frame == FRAME_JOURNAL else FOREST_FILL
	_fill(sheet, frame, rect, fill)
	_lay_edges(sheet, frame, rect)
	_lay_corners(sheet, frame, rect)
	if frame == FRAME_JOURNAL:
		_lay_binding(sheet, rect)


func _fill(sheet: Image, frame: int, rect: Rect2i, color: Color) -> void:
	"""Paint the flat interior the renderer owns: the cross between the four corner pieces.

	The corners are left bare because each corner piece carries its own field cut to the
	silhouette. Filling under them would put a square back behind every notch and chamfer.
	"""
	var tl: Vector2i = ART.frame_corner_size(frame, 0)
	var br: Vector2i = ART.frame_corner_size(frame, 3)
	var patch: Image = Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	patch.fill(color)
	sheet.blit_rect(patch, Rect2i(0, 0, rect.size.x, rect.size.y - tl.y - br.y),
		rect.position + Vector2i(0, tl.y))
	sheet.blit_rect(patch, Rect2i(0, 0, rect.size.x - tl.x - br.x, rect.size.y),
		rect.position + Vector2i(tl.x, 0))


func _lay_edges(sheet: Image, frame: int, rect: Rect2i) -> void:
	"""Stretch the four edge strips between the corner extents."""
	var first: int = ART.frame_first_asset(frame)
	var tl: Vector2i = ART.frame_corner_size(frame, 0)
	var br: Vector2i = ART.frame_corner_size(frame, 3)
	var span_x: int = rect.size.x - tl.x - br.x
	var span_y: int = rect.size.y - tl.y - br.y
	_stretch(sheet, first + 0, Vector2i(span_x, ART.frame_edge_inset(frame, 0)),
		rect.position + Vector2i(tl.x, 0))
	_stretch(sheet, first + 1, Vector2i(span_x, ART.frame_edge_inset(frame, 2)),
		rect.position + Vector2i(tl.x, rect.size.y - ART.frame_edge_inset(frame, 2)))
	_stretch(sheet, first + 2, Vector2i(ART.frame_edge_inset(frame, 3), span_y),
		rect.position + Vector2i(0, tl.y))
	_stretch(sheet, first + 3, Vector2i(ART.frame_edge_inset(frame, 1), span_y),
		rect.position + Vector2i(rect.size.x - ART.frame_edge_inset(frame, 1), tl.y))


func _lay_corners(sheet: Image, frame: int, rect: Rect2i) -> void:
	"""Place the four corner pieces at their true size; a corner is never scaled."""
	var first: int = ART.frame_first_asset(frame) + 4
	for corner: int in 4:
		var size: Vector2i = ART.frame_corner_size(frame, corner)
		var origin: Vector2i = rect.position
		if corner == 1 or corner == 3:
			origin.x += rect.size.x - size.x
		if corner >= 2:
			origin.y += rect.size.y - size.y
		_stretch(sheet, first + corner, size, origin)


func _lay_binding(sheet: Image, rect: Rect2i) -> void:
	"""The journal's non-stretching brass rings and its closing strap."""
	var ring: int = ART.frame_first_asset(FRAME_JOURNAL) + 8
	var y: int = rect.position.y + 30
	while y < rect.position.y + rect.size.y - 30:
		_stretch(sheet, ring, Vector2i(10, 14), Vector2i(rect.position.x + 1, y))
		y += 40
	_stretch(sheet, ring + 1, Vector2i(14, 88),
		Vector2i(rect.position.x + rect.size.x - 8, rect.position.y + (rect.size.y - 88) / 2))


func _stretch(sheet: Image, asset: int, size: Vector2i, origin: Vector2i) -> void:
	"""Rasterise one asset at its authored width, resize to `size` and blend it in."""
	if size.x <= 0 or size.y <= 0:
		return
	var image: Image = ART.rasterise(ART.source_path_of(asset), ART.optical_sizes_of(asset)[0])
	if image == null:
		push_error("specimen: missing source %s" % ART.source_path_of(asset))
		return
	if image.get_size() != size:
		image.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	sheet.blend_rect(image, Rect2i(Vector2i.ZERO, size), origin)
