extends CanvasLayer
## The song bubbles: a short line at a time over each singer, on the screen over their head. Decision 0442. DEMO UI
## in the woodland colours; presentation only.
##
## A POOL of BUBBLES parchment bubbles is made once; each frame `show_bubble` places one per singer at its head's
## screen point (the camera's projection), and `finish` hides the rest. A singer behind the camera or off the screen
## gets none. The layer draws under every HUD and demo panel (layer -1), over the world.

const Palette := preload("res://demo/ui/woodland_palette.gd")

const BUBBLES: int = 8
const FONT_PX: int = 15
const LIFT_PX: float = 10.0
const RADIUS: int = 9
const MARGINS: Vector4 = Vector4(10.0, 5.0, 10.0, 6.0)
const BUBBLE_ALPHA: float = 0.94

var _bubbles: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _used: int = 0


func _init() -> void:
	"""The pool, hidden."""
	name = "SongBubbles"
	layer = -1
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.OAT, BUBBLE_ALPHA)
	style.border_color = Palette.UMBER
	style.set_border_width_all(2)
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = MARGINS.x
	style.content_margin_top = MARGINS.y
	style.content_margin_right = MARGINS.z
	style.content_margin_bottom = MARGINS.w
	for k: int in BUBBLES:
		var bubble := PanelContainer.new()
		bubble.add_theme_stylebox_override(&"panel", style)
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.visible = false
		var label := Label.new()
		label.add_theme_font_size_override(&"font_size", FONT_PX)
		label.add_theme_color_override(&"font_color", Palette.INK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.add_child(label)
		add_child(bubble)
		_bubbles.append(bubble)
		_labels.append(label)


func begin() -> void:
	"""A new frame of bubbles: none placed yet."""
	_used = 0


func show_bubble(camera: Camera3D, head: Vector3, text: String) -> bool:
	"""One bubble saying `text` over world point `head`; false when it cannot be seen (no camera in the tree, behind
	it, off the screen) or the pool is spent."""
	if _used >= BUBBLES or camera == null or not camera.is_inside_tree() or camera.is_position_behind(head):
		return false
	var at: Vector2 = camera.unproject_position(head)
	var screen: Rect2 = camera.get_viewport().get_visible_rect()
	if not screen.has_point(at):
		return false
	var bubble: PanelContainer = _bubbles[_used]
	if _labels[_used].text != text:
		_labels[_used].text = text
		bubble.reset_size()
	var size: Vector2 = bubble.get_combined_minimum_size()
	bubble.position = Vector2(at.x - size.x * 0.5, at.y - size.y - LIFT_PX)
	bubble.visible = true
	_used += 1
	return true


func finish() -> void:
	"""Hide every bubble not placed this frame."""
	for k: int in range(_used, BUBBLES):
		_bubbles[k].visible = false


func shown() -> PackedStringArray:
	"""The words of every bubble shown (checks)."""
	var out := PackedStringArray()
	for k: int in BUBBLES:
		if _bubbles[k].visible:
			out.append(_labels[k].text)
	return out
