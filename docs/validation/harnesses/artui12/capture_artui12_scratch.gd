extends SceneTree
## ART-UI-12 cycle-01 native capture harness.
##
## RETAINED, NOT SCRATCH. The `_scratch` in the filename is historical -- this file was
## written as a throwaway and deleted before the first commit, and Astra's Cycle 2 review
## asked for it back so the evidence can be reproduced from repository contents. It now lives
## under `docs/validation/`, which owns validators and evidence. It is NOT a Godot source file
## of the project: nothing in `godot/` loads it, and the project must stay able to build and
## test without it.
##
## Run from the repository root:
##
##   godot --path godot \
##       --script ../docs/validation/harnesses/artui12/capture_artui12_scratch.gd \
##       --resolution <W>x<H> -- <absolute-out.png> <mode> <scale-percent>
##
## No copy step is needed. Godot 4.7.2's `--script` resolves a path OUTSIDE the project
## directory -- both a `../` relative path and an absolute one -- which was measured rather
## than assumed; the cycle-01 evidence README records the check.
##
## Modes:
##   unpopulated  no world created; every counter carries hud.gd's own "--" marker
##   settlement   UI-SET-103's real Create; every counter carries a store-derived value
##   ladder       the ONE mode with harness-supplied value text, one glyph per writable cell
##   occl_expired roster workspace open, notices raised, alert hold expired
##   occl_active  roster workspace open, the same notices, cards active
##   occl_open    the same notices, roster workspace NOT opened
##
## Four known traps, all still true: a --script SceneTree run hangs forever if an error
## abandons _initialize() before quit(), so this counts frames and quits either way; save_png
## needs an ABSOLUTE path; autoload identifiers do not resolve at compile time under --script,
## so UIManager is reached with root.get_node_or_null() at runtime; and --headless returns null
## from get_image(), so every capture must be run windowed.

const COUNTER_IDS: Array[int] = [2, 3, 4, 5, 6, 7]
const LADDER_MIN_GLYPHS: int = 1
const LADDER_MAX_GLYPHS: int = 6
const DIGITS: String = "1234567890"

var _out: String = ""
var _mode: String = "settlement"
var _scale: int = 100
var _frames: int = 0
var _acted: bool = false


func _initialize() -> void:
	"""Read the arguments, boot the project's own main scene, and start counting frames."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1:
		_out = args[0]
	if args.size() >= 2:
		_mode = args[1]
	if args.size() >= 3:
		_scale = int(args[2])
	var scene: PackedScene = load("res://scenes/main.tscn")
	root.add_child(scene.instantiate())


func _process(_delta: float) -> bool:
	"""Act on frame 20, capture on frame 60, and quit whatever happened."""
	_frames += 1
	if _frames == 20 and not _acted:
		_acted = true
		_drive()
	if _frames >= 60:
		_capture()
		quit()
	return false


func _drive() -> void:
	"""Drive the interface's own public entry points, then report what is on screen."""
	var manager: Node = root.get_node_or_null("UIManager")
	var main: Node = root.get_node_or_null("Main")
	var hud: Node = main.get_node_or_null("UI/HUD")
	var shell: Control = hud.shell()
	if _mode == "settlement" or _mode == "ladder":
		print("[capture] create -> %s" % manager.create_world())
	if _mode.begins_with("occl"):
		_drive_occlusion(manager, hud, shell)
	shell.apply_user_scale(_scale)
	shell.layout_for(int(root.size.x), int(root.size.y))
	if _mode == "ladder":
		_drive_ladder(shell)
	_report(shell)


func _drive_occlusion(manager: Node, hud: Node, shell: Control) -> void:
	"""Raise the same two real notices every time, then open or expire exactly one thing."""
	## HOLT is a value UI-SET-103's own dropdown offers and ui_world_session.gd refuses as
	## unauthored. The refusal sentence and its severity are composed by the code under test;
	## this harness supplies no message text anywhere.
	var session: RefCounted = manager.world_session()
	print("[capture] choose HOLT -> %s" % session.set_architecture(1))
	print("[capture] create -> %s" % manager.create_world())
	if _mode != "occl_open":
		(shell.control_for(31) as Button).pressed.emit()
	if _mode == "occl_expired":
		## hud.gd's OWN four-second hold expiry calls exactly this.
		hud.show_alert("")


func _drive_ladder(shell: Control) -> void:
	"""Step the value by ONE glyph per writable cell, through hud.gd's own cell writer.

	A cell whose owning store does not exist REFUSES, and that refusal decides which cells take
	part: the ladder is spread over the cells the shell will actually write, so consecutive
	drawn cells differ by exactly one glyph and the first cut lands between two neighbours.
	"""
	var writable: Array[int] = []
	for id: int in COUNTER_IDS:
		if not (shell.control_for(id) as Control).visible:
			continue
		if shell.set_counter_display(id, DIGITS.substr(0, LADDER_MIN_GLYPHS)):
			writable.append(id)
		else:
			print("[capture] ladder id=%d REFUSED (%s)" % [id, shell.last_refusal()])
	for index: int in writable.size():
		var glyphs: int = mini(LADDER_MIN_GLYPHS + index, LADDER_MAX_GLYPHS)
		print("[capture] ladder id=%d glyphs=%d -> %s" % [writable[index], glyphs,
			shell.set_counter_display(writable[index], DIGITS.substr(0, glyphs))])


func _report(shell: Control) -> void:
	"""Print every counter cell's measured fit and the alert stack's own state."""
	print("[capture] mode=%s scale=%d profile=%d viewport=%dx%d" % [_mode, _scale,
		shell.geometry().profile, int(root.size.x), int(root.size.y)])
	for id: int in COUNTER_IDS:
		_report_cell(id, shell.control_for(id) as Button)
	print("[capture] alerts rect=%s wanted=%d visible=%d undisplayed=%d" % [
		shell.geometry().alerts, shell.wanted_alert_cards(), shell.visible_alert_cards(),
		shell.undisplayed_notices()])
	for instance: int in 2:
		print("[capture]   card%d visible=%s rect=%s text='%s'" % [instance,
			shell.alert_card_at(instance).visible,
			shell.alert_card_at(instance).get_global_rect(),
			shell.alert_label_at(instance).text])
	if shell.roster_shown() > 0:
		print("[capture]   roster shown=%d row0=%s text='%s'" % [shell.roster_shown(),
			shell.roster_row(0).get_global_rect(), shell.roster_row(0).text])


func _report_cell(id: int, button: Button) -> void:
	"""One cell: its rectangle, its text, the measured text width and its own pixel budget."""
	if button == null or not button.visible:
		print("[capture] cell id=%d not drawn at this profile" % id)
		return
	var font: Font = button.get_theme_font(&"font")
	var size: int = button.get_theme_font_size(&"font_size")
	var style: StyleBox = button.get_theme_stylebox(&"normal")
	var icon_w: float = 0.0 if button.icon == null else float(button.icon.get_width())
	var budget: float = button.size.x - style.get_margin(SIDE_LEFT) \
		- style.get_margin(SIDE_RIGHT) - icon_w - float(button.get_theme_constant(&"h_separation"))
	var text_px: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT,
		-1.0, size).x
	print("[capture] cell id=%d rect=%s text='%s' text_px=%.2f budget_px=%.2f verdict=%s value_digits_that_fit=%s" % [id,
		button.get_rect(), button.text, text_px, budget,
		"FITS" if text_px <= budget else "CLIPPED by %.2f px" % (text_px - budget),
		_value_digits_that_fit(button, budget)])


func _value_digits_that_fit(button: Button, budget: float) -> String:
	"""How many digits of VALUE this cell's own label can carry before the cut begins.

	Stated in words rather than as a number when the answer is "not even zero": a bare label
	wider than the budget is a real measured outcome, and reporting it as -1 would put a
	sentinel where a reader expects a count.
	"""
	var font: Font = button.get_theme_font(&"font")
	var size: int = button.get_theme_font_size(&"font_size")
	var label: String = button.text.split(" ")[0]
	for digits: int in range(0, DIGITS.length() + 1):
		var candidate: String = "%s %s" % [label, DIGITS.substr(0, digits)]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x <= budget:
			continue
		if digits == 0:
			return "none, the bare label already overflows"
		return str(digits - 1)
	return str(DIGITS.length())


func _capture() -> void:
	"""Write the real window's own framebuffer to an absolute path."""
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("[capture] NO IMAGE -- run windowed, not --headless")
		return
	print("[capture] %s -> %s (%dx%d)" % [_mode, _out, image.get_width(), image.get_height()])
	image.save_png(_out)
