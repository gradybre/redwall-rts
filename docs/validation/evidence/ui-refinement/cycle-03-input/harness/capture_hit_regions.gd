extends SceneTree
## UI-C3-EVIDENCE input-region capture harness: draws §1.2's click-through table over the
## real shell and probes named points against it.
##
## RETAINED, NOT SCRATCH. It sits beside its own evidence rather than in
## `docs/validation/harnesses/artui12/` only because this lane's allowlist is the evidence
## directory; the cycle-01 harnesses there are byte-untouched by this lane.
##
## Run from the repository root:
##
##   godot --path godot \
##       --script ../docs/validation/evidence/ui-refinement/cycle-03-input/harness/capture_hit_regions.gd \
##       --resolution 1280x720 -- <absolute-out.png> <mode> <scale-percent>
##
## Modes:
##   boundary       settlement created, nothing opened -- the resource/world band boundary
##   detail_open    settlement created, UI-SET-036's detail panel open beside the world
##   roster_open    settlement + two real notices, roster workspace OPEN
##   roster_closed  settlement + the same two notices, roster NOT opened
##
## The same four traps the cycle-01 harness records still apply: a `--script` SceneTree run
## hangs forever if an error abandons `_initialize()` before `quit()`, so this counts frames
## and quits either way; `save_png` needs an ABSOLUTE path; autoload identifiers do not
## resolve at compile time under `--script`; and `--headless` returns null from `get_image()`.
##
## NOTHING HERE ASSERTS GEOMETRY. Every rectangle drawn is read back from the shell's own
## controls, and every verdict printed is `ui_hit_test.gd`'s own answer at a point. The
## harness supplies the points and the paint, not the expectations.

## §4 element ids this harness may find. Read from the shell, never assumed present.
const MAX_ELEMENT_ID: int = 103

const KIND_DECORATIVE: int = 0
const KIND_CONSUMING: int = 1
const KIND_FOCUS: int = 2
const KIND_MISMATCH: int = 3

var _out: String = ""
var _mode: String = "boundary"
var _scale: int = 100
var _relayout: bool = false
var _frames: int = 0
var _acted: bool = false
var _overlaid: bool = false


func _initialize() -> void:
	"""Read the arguments, boot the project's own main scene, and start counting frames."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1:
		_out = args[0]
	if args.size() >= 2:
		_mode = args[1]
	if args.size() >= 3:
		_scale = int(args[2])
	if args.size() >= 4:
		_relayout = args[3] == "relayout"
	var scene: PackedScene = load("res://scenes/main.tscn")
	root.add_child(scene.instantiate())


func _process(_delta: float) -> bool:
	"""Drive on frame 20, paint the overlay on frame 40, capture on frame 60, always quit."""
	_frames += 1
	if _frames == 20 and not _acted:
		_acted = true
		_drive()
	if _frames == 40 and not _overlaid:
		_overlaid = true
		_paint()
	if _frames >= 60:
		_capture()
		quit()
	return false


func _shell() -> Control:
	"""The shell under test, reached at runtime because autoloads do not resolve under --script."""
	var main: Node = root.get_node_or_null("Main")
	return (main.get_node_or_null("UI/HUD") as Node).call("shell") as Control


func _drive() -> void:
	"""Drive the interface's own public entry points for this mode, then lay out at the scale."""
	var manager: Node = root.get_node_or_null("UIManager")
	var main: Node = root.get_node_or_null("Main")
	var hud: Node = main.get_node_or_null("UI/HUD")
	var shell: Control = hud.shell()
	if _mode == "boundary" or _mode == "detail_open":
		print("[input] create -> %s" % manager.create_world())
		if _mode == "detail_open":
			shell.set_detail_open(true)
	else:
		var session: RefCounted = manager.world_session()
		print("[input] choose HOLT -> %s" % session.set_architecture(1))
		print("[input] create -> %s" % manager.create_world())
		if _mode == "roster_open":
			(shell.control_for(31) as Button).pressed.emit()
	shell.apply_user_scale(_scale)
	shell.layout_for(int(root.size.x), int(root.size.y))


# --- rectangles -------------------------------------------------------------------------------

func _shell_rect(shell: Control, control: Control) -> Rect2:
	"""A control's rectangle in shell coordinates, summed from its own parent chain.

	This mirrors `ui_shell.gd::_shell_rect_of()` so the rectangle drawn is the rectangle that
	was registered, rather than a global rect that the shell's scale transform has already
	multiplied.
	"""
	var origin: Vector2 = control.position
	var node: Node = control.get_parent()
	while node != null and node != shell:
		if node is Control:
			origin += (node as Control).position
		node = node.get_parent()
	return Rect2(origin, control.size)


func _is_visible_chain(shell: Control, control: Control) -> bool:
	"""True when a control and every ancestor up to the shell are visible."""
	if not control.visible:
		return false
	var node: Node = control.get_parent()
	while node != null and node != shell:
		if node is Control and not (node as Control).visible:
			return false
		node = node.get_parent()
	return true


func _drawn_elements(shell: Control) -> Array:
	"""Every §4 element the shell currently draws, as {id, rect, consumes} in shell coordinates."""
	var found: Array = []
	for id: int in range(1, MAX_ELEMENT_ID + 1):
		if not shell.renders(id):
			continue
		var control: Control = shell.control_for(id) as Control
		if control == null or not _is_visible_chain(shell, control):
			continue
		found.append({"id": id, "rect": _shell_rect(shell, control),
			"consumes": control.mouse_filter != Control.MOUSE_FILTER_IGNORE})
	var second: Panel = shell.alert_card_at(1) as Panel
	if second != null and _is_visible_chain(shell, second):
		found.append({"id": 11, "rect": _shell_rect(shell, second),
			"consumes": second.mouse_filter != Control.MOUSE_FILTER_IGNORE})
	return found


# --- probes -----------------------------------------------------------------------------------

func _probe_points(shell: Control) -> Array:
	"""The named logical points this lane asks about, derived from geometry, never hard-coded."""
	var g: RefCounted = shell.geometry()
	var r: Rect2 = g.resources
	var points: Array = []
	points.append(["resource frame, 4px inside its top-left", r.position + Vector2(4.0, 4.0)])
	points.append(["resource frame, last pixel inside its right edge",
		Vector2(r.end.x - 1.0, r.position.y + 4.0)])
	points.append(["first pixel right of the resource frame", Vector2(r.end.x, r.position.y + 4.0)])
	points.append(["resource frame, last pixel inside its bottom edge",
		Vector2(r.position.x + 4.0, r.end.y - 1.0)])
	points.append(["first pixel below the resource frame", Vector2(r.position.x + 4.0, r.end.y)])
	points.append(["first row of the reserved band (management_top)",
		Vector2(r.position.x + 4.0, g.management_top)])
	points.append(["the stale fixture's old origin (240,120)", Vector2(240.0, 120.0)])
	points.append(["the stale fixture's last stale row (368,136)", Vector2(368.0, 136.0)])
	points.append(["test_ui_hit_test _world_point(0)", Vector2(240.0, g.management_top)])
	points.append(["test_ui_hit_test _world_point(999)",
		Vector2(240.0 + 39.0 * 16.0, g.management_top + 24.0 * 16.0)])
	if g.logical_width >= 1280.0:
		## Only meaningful where the point is inside the logical viewport at all: at 125% and
		## 150% the logical width is 1024 and 853⅓, so x=1000 is off the layout or off its edge.
		points.append(["test_ui_shell's \"world beside it\" point (1000,300)",
			Vector2(1000.0, 300.0)])
	points.append(["centre of the world band",
		Vector2(g.logical_width * 0.5, (g.management_top + g.commands.position.y) * 0.5)])
	_append_zone_probes(shell, g, points)
	return points


func _append_zone_probes(shell: Control, g: RefCounted, points: Array) -> void:
	"""Alert cards, minimap, command strip, detail, and the narrow commands/minimap overlap."""
	for instance: int in 2:
		var card: Panel = shell.alert_card_at(instance) as Panel
		if card != null and _is_visible_chain(shell, card):
			points.append(["alert card %d, its centre" % instance,
				_shell_rect(shell, card).get_center()])
	points.append(["first pixel below the alert zone",
		Vector2(g.alerts.position.x + 4.0, g.alerts.end.y)])
	points.append(["minimap frame, its centre", g.minimap.get_center()])
	points.append(["command strip, its centre", g.commands.get_center()])
	if g.detail_open:
		points.append(["detail panel, its centre", g.detail.get_center()])
	var overlap: Rect2 = g.commands.intersection(g.minimap)
	if overlap.size.x > 0.0 and overlap.size.y > 0.0:
		points.append(["commands/minimap OVERLAP, its centre", overlap.get_center()])
	_append_workspace_probes(shell, points)


func _append_workspace_probes(shell: Control, points: Array) -> void:
	"""The workspace frame and its first roster row, only while the shell actually draws them."""
	var workspace: Control = shell.control_for(51) as Control
	if workspace == null or not _is_visible_chain(shell, workspace):
		return
	var rect: Rect2 = _shell_rect(shell, workspace)
	points.append(["workspace frame, its centre", rect.get_center()])
	points.append(["workspace frame, 2px above its top edge",
		Vector2(rect.get_center().x, rect.position.y - 2.0)])
	if int(shell.roster_shown()) > 0:
		points.append(["roster row 0, its centre",
			_shell_rect(shell, shell.roster_row(0) as Control).get_center()])


func _report(shell: Control, elements: Array, probes: Array) -> void:
	"""Print the geometry, every drawn element's ownership verdict and every probe's answer."""
	var g: RefCounted = shell.geometry()
	print("[input] relayout=%s" % _relayout)
	print("[input] mode=%s scale=%d profile=%d logical=%.2fx%.2f viewport=%dx%d" % [_mode,
		_scale, g.profile, g.logical_width, g.logical_height, int(root.size.x), int(root.size.y)])
	print("[input] resources=%s alerts=%s time=%s management_top=%.2f" % [g.resources, g.alerts,
		g.time, g.management_top])
	print("[input] minimap=%s commands=%s detail=%s detail_open=%s scrim=%s" % [g.minimap,
		g.commands, g.detail, g.detail_open, shell.hit_test().scrim_is_up()])
	var hits: RefCounted = shell.hit_test()
	print("[input] regions=%d consuming=%d" % [hits.region_count(), hits.consuming_count()])
	for index: int in hits.region_count():
		print("[region] index=%d rect=%s consumes=%s" % [index, hits.region_rect(index),
			hits.region_consumes(index)])
	for entry: Dictionary in elements:
		print("[element] id=%d rect=%s consumes=%s registered=%s centre_owner=%s verdict=%s" % [
			entry["id"], entry["rect"], entry["consumes"], entry["registered"],
			entry["owner_text"], entry["verdict"]])
	_report_overlaps(elements)
	for index: int in probes.size():
		var entry: Dictionary = probes[index]
		print("[probe] #%d %s logical=%s world_receives=%s owner=%s layer=%s" % [index,
			entry["name"], entry["point"], entry["world"], entry["owner_text"],
			entry["layer_text"]])


func _report_overlaps(elements: Array) -> void:
	"""Print every pair of drawn consuming rectangles that cross without one containing the other.

	Nesting is ordinary -- a button inside its frame. Two rectangles that merely CROSS mean one
	element is painting over part of another, and the lower one loses every click in the shared
	area whatever it looks like.
	"""
	var crossings: int = 0
	for first: int in elements.size():
		for second: int in range(first + 1, elements.size()):
			var a: Dictionary = elements[first]
			var b: Dictionary = elements[second]
			if not bool(a["consumes"]) or not bool(b["consumes"]):
				continue
			var ra: Rect2 = a["rect"] as Rect2
			var rb: Rect2 = b["rect"] as Rect2
			var shared: Rect2 = ra.intersection(rb)
			if shared.size.x <= 0.0 or shared.size.y <= 0.0:
				continue
			if ra.encloses(rb) or rb.encloses(ra):
				continue
			crossings += 1
			print("[overlap] %d %s crosses %d %s over %s" % [a["id"], ra, b["id"], rb, shared])
	print("[input] crossing pairs=%d" % crossings)


func _judge_elements(shell: Control, elements: Array) -> void:
	"""Ask the hit table who owns each drawn element's own centre, and name the disagreement."""
	var hits: RefCounted = shell.hit_test()
	for entry: Dictionary in elements:
		var centre: Vector2 = (entry["rect"] as Rect2).get_center()
		var owner: RefCounted = hits.element_at(centre)
		entry["owner_text"] = str(owner.value) if owner.ok else "NONE(%s)" % hits.last_refusal()
		entry["mismatch"] = false
		entry["registered"] = _is_registered(hits, entry["rect"] as Rect2)
		if not bool(entry["consumes"]):
			entry["verdict"] = "DECORATIVE, takes nothing"
			if owner.ok:
				entry["verdict"] = "DECORATIVE, its centre belongs to %d" % owner.value
			continue
		_judge_consuming(hits, elements, entry, owner)


func _judge_consuming(hits: RefCounted, elements: Array, entry: Dictionary,
		owner: RefCounted) -> void:
	"""Classify one consuming element: its own, a child inside it, the scrim, or a real cover.

	A frame whose centre belongs to a control DRAWN INSIDE IT is ordinary nesting, not a
	defect, so it is named rather than flagged. A frame whose centre belongs to a rectangle
	that is NOT inside it is the failure this lane is looking for.
	"""
	if not bool(entry["registered"]):
		entry["verdict"] = "DRAWN AND CLICKABLE BUT HAS NO INPUT RECTANGLE"
		entry["mismatch"] = true
		return
	if not owner.ok:
		if hits.scrim_is_up():
			entry["verdict"] = "BEHIND THE SCRIM, excluded from input"
			return
		entry["verdict"] = "REGISTERED BUT NO POINT REACHES IT"
		entry["mismatch"] = true
		return
	if int(owner.value) == int(entry["id"]):
		entry["verdict"] = "OWNS ITS OWN CENTRE"
		return
	if _is_nested(elements, int(owner.value), entry["rect"] as Rect2):
		entry["verdict"] = "NESTED: centre belongs to %d drawn inside it" % owner.value
		return
	entry["verdict"] = "COVERED BY %d" % owner.value
	entry["mismatch"] = true


func _is_registered(hits: RefCounted, rect: Rect2) -> bool:
	"""True when this exact rectangle is present in the table, whatever the scrim is doing.

	`element_at()` answers "who owns this point NOW", which a raised scrim changes. This asks
	the different question the fourth bullet needs: did the shell give this drawn control an
	input rectangle at all?
	"""
	for index: int in hits.region_count():
		if hits.region_rect(index).is_equal_approx(rect):
			return true
	return false


func _is_nested(elements: Array, owner_id: int, outer: Rect2) -> bool:
	"""True when every drawn rectangle carrying `owner_id` lies inside `outer`."""
	var seen: bool = false
	for entry: Dictionary in elements:
		if int(entry["id"]) != owner_id:
			continue
		seen = true
		if not outer.encloses(entry["rect"] as Rect2):
			return false
	return seen


func _judge_probes(shell: Control, probes: Array) -> Array:
	"""Answer each named point from the table: world, or which element and layer took it."""
	var hits: RefCounted = shell.hit_test()
	var judged: Array = []
	for pair: Array in probes:
		var point: Vector2 = pair[1]
		var owner: RefCounted = hits.element_at(point)
		var owner_text: String = str(owner.value) if owner.ok else "NONE(%s)" % hits.last_refusal()
		var layer: RefCounted = hits.layer_at(point)
		var layer_text: String = str(layer.value) if layer.ok else "none"
		judged.append({"index": judged.size(), "name": pair[0], "point": point,
			"world": hits.world_receives(point), "owner_text": owner_text,
			"layer_text": layer_text, "scrim": hits.scrim_is_up() and not owner.ok})
	return judged


# --- overlay ----------------------------------------------------------------------------------

func _paint() -> void:
	"""Build the region/probe tables, print them, and put the drawn overlay on screen."""
	var shell: Control = _shell()
	if _relayout:
		## The second pass this lane captures separately: the containers have sorted their
		## children by now, so one more layout re-registers every rectangle from the sizes the
		## window is actually showing. Never done in the at-rest captures.
		print("[input] forced relayout -> %s" % shell.layout_for(int(root.size.x),
			int(root.size.y)))
	var elements: Array = _drawn_elements(shell)
	_judge_elements(shell, elements)
	var probes: Array = _judge_probes(shell, _probe_points(shell))
	_report(shell, elements, probes)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 128
	root.add_child(layer)
	var overlay: Overlay = Overlay.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.size = Vector2(root.size)
	overlay.transform2d = shell.get_global_transform()
	overlay.elements = elements
	overlay.probes = probes
	overlay.focus_ids = _focus_ids()
	overlay.bands = _bands(shell)
	layer.add_child(overlay)
	overlay.queue_redraw()


func _focus_ids() -> PackedInt32Array:
	"""The §4 ids this mode's question is about, drawn thick so a reader can find them."""
	if _mode == "boundary":
		return PackedInt32Array([1, 2, 3, 4, 5, 6, 7, 8, 23])
	return PackedInt32Array([10, 11, 51, 69, 20, 26])


func _bands(shell: Control) -> Array:
	"""The two horizontal lines UI-C3-R01 §4 defines, in shell coordinates."""
	var g: RefCounted = shell.geometry()
	return [["resource frame bottom y=%.0f" % g.resources.end.y, g.resources.end.y],
		["management_top y=%.0f" % g.management_top, g.management_top]]


func _capture() -> void:
	"""Write the real window's own framebuffer to an absolute path."""
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("[input] NO IMAGE -- run windowed, not --headless")
		return
	print("[input] %s -> %s (%dx%d)" % [_mode, _out, image.get_width(), image.get_height()])
	image.save_png(_out)


class Overlay extends Control:
	"""Paints the registered input rectangles and the probed points over the live shell."""

	var transform2d: Transform2D = Transform2D.IDENTITY
	var elements: Array = []
	var probes: Array = []
	var focus_ids: PackedInt32Array = PackedInt32Array()
	var bands: Array = []

	const COLOR_CONSUMING: Color = Color(0.15, 0.85, 1.0, 0.95)
	const COLOR_DECORATIVE: Color = Color(0.6, 0.6, 0.6, 0.55)
	const COLOR_FOCUS: Color = Color(1.0, 0.85, 0.1, 1.0)
	const COLOR_MISMATCH: Color = Color(1.0, 0.2, 0.2, 1.0)
	const COLOR_WORLD: Color = Color(0.2, 1.0, 0.35, 1.0)
	const COLOR_TAKEN: Color = Color(1.0, 0.35, 0.35, 1.0)
	const COLOR_BAND: Color = Color(1.0, 0.45, 0.95, 0.9)
	const LABEL_SIZE: int = 11

	func _physical(rect: Rect2) -> Rect2:
		"""One shell-space rectangle in window pixels, through the shell's own transform."""
		var origin: Vector2 = transform2d * rect.position
		return Rect2(origin, transform2d * rect.end - origin)

	func _draw() -> void:
		"""Draw the bands, then every rectangle, then every probed point on top."""
		_draw_bands()
		for entry: Dictionary in elements:
			_draw_element(entry)
		for entry: Dictionary in probes:
			_draw_probe(entry)

	func _draw_bands() -> void:
		"""UI-C3-R01 §4's resource-frame bottom and management_top, across the full width."""
		for band: Array in bands:
			var y: float = (transform2d * Vector2(0.0, band[1] as float)).y
			draw_line(Vector2(0.0, y), Vector2(size.x, y), COLOR_BAND, 2.0)
			_label(Vector2(size.x - 220.0, y - 4.0), band[0] as String, COLOR_BAND)

	func _draw_element(entry: Dictionary) -> void:
		"""One drawn element: colour by consuming/decorative/focus, red when the table disagrees."""
		var rect: Rect2 = _physical(entry["rect"] as Rect2)
		var id: int = int(entry["id"])
		if bool(entry["mismatch"]):
			draw_rect(rect, COLOR_MISMATCH, false, 3.0)
			_label(rect.position + Vector2(2.0, 12.0), "%d %s" % [id, entry["verdict"]],
				COLOR_MISMATCH)
			return
		if not bool(entry["consumes"]):
			draw_rect(rect, COLOR_DECORATIVE, false, 1.0)
			return
		if focus_ids.has(id):
			draw_rect(rect, COLOR_FOCUS, false, 3.0)
			_label(rect.position + Vector2(2.0, 12.0), str(id), COLOR_FOCUS)
			return
		draw_rect(rect, COLOR_CONSUMING, false, 1.0)

	func _draw_probe(entry: Dictionary) -> void:
		"""One probed point: green when the world receives it, red with the owning id when not."""
		var point: Vector2 = transform2d * (entry["point"] as Vector2)
		var world: bool = bool(entry["world"])
		var color: Color = COLOR_WORLD if world else COLOR_TAKEN
		draw_circle(point, 5.0, color)
		draw_circle(point, 6.0, Color(0.0, 0.0, 0.0, 0.9), false, 1.5)
		var verdict: String = "UI %s" % entry["owner_text"]
		if world:
			verdict = "WORLD"
		elif bool(entry["scrim"]):
			verdict = "SCRIM"
		var text: String = "#%d %s" % [int(entry["index"]), verdict]
		_label(point + Vector2(8.0, 4.0), text, color)

	func _label(at: Vector2, text: String, color: Color) -> void:
		"""Draw small text on a dark backing so it reads over any HUD colour."""
		var font: Font = ThemeDB.fallback_font
		if font == null:
			return
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			LABEL_SIZE).x
		draw_rect(Rect2(at.x - 2.0, at.y - 10.0, width + 4.0, 13.0), Color(0.0, 0.0, 0.0, 0.75))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, color)
