extends SceneTree
## The demo's people (decision 0491, review group T) on the REAL scene with real input: the names on the roster and the
## party panel, the resident inspector (skills as meters, About opened by a click), a notable moment whose row is
## clicked to go to the person in it, the spotlight card clicked, and the roster's ★. Not discovered by the runner:
## test/test_demo_people_live.gd runs it in its own process, as the input and layout harnesses are (decisions 0261,
## 0391), because only an in-tree scene lays its Controls out and takes Viewport input.
##
##     godot --headless --path godot --script res://test/live/demo_people_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## The notable deed is a rescue written into the rescue's own assistance log (rescue.gd `_log_assist`, what a rescuer
## bringing a victim ashore writes): the suites drive the real rescue; here it is the frame that matters. Prints
## `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const PeopleBook := preload("res://demo/people/people_book.gd")
const CardScript := preload("res://demo/people/people_card.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
const FULL: float = 0.99

var _village: Node = null
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and run the checks."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size() - 1:
		if args[k] == "--size":
			var parts: PackedStringArray = args[k + 1].split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
		elif args[k] == "--capture":
			_capture_dir = args[k + 1]
	root.size = _size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_run.call_deferred()


func _frames(count: int) -> void:
	"""Wait `count` frames, holding the window size (the headless server sizes the root to 64x64 at first)."""
	for k: int in count:
		if root.size != _size:
			root.size = _size
		await process_frame


func _run() -> void:
	"""Every step, then the summary."""
	await _frames(BOOT_FRAMES)
	_manager().call(&"pause_game")
	_names_everywhere()
	await _the_roster()
	await _the_inspector()
	await _a_notable_moment()
	await _the_spotlight()
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers ------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail])


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _command() -> Node:
	"""The command layer."""
	return _village.get("_command")


func _people() -> Node:
	"""The village's people."""
	return _village.call(&"people")


func _section() -> Control:
	"""The party panel's person section."""
	return _command().call(&"panel").call(&"person_section")


func _cast() -> Node:
	"""The cast."""
	return _village.get("_cast")


func _index_of(key: StringName) -> int:
	"""The cast index of the resident with cast key `key` (-1: none)."""
	for who: int in int(_cast().call(&"actor_count")):
		if _cast().call(&"actor", who).get("creature_key") == key:
			return who
	return -1


func _fraction(control: Control) -> float:
	"""How much of `control` is on screen: its rect cut by the window and every clipping ancestor."""
	if control == null or not control.is_visible_in_tree():
		return 0.0
	var rect: Rect2 = control.get_global_rect()
	var clip := Rect2(Vector2.ZERO, Vector2(_size))
	var at: Node = control.get_parent()
	while at != null:
		if at is Control and (at as Control).clip_contents:
			clip = clip.intersection((at as Control).get_global_rect())
		at = at.get_parent()
	return rect.intersection(clip).get_area() / maxf(rect.get_area(), 0.0001)


func _reveal(control: Control) -> void:
	"""Scroll `control`'s scroll to it (the way focus does), and wait for it to move."""
	var at: Node = control.get_parent()
	while at != null and not at is ScrollContainer:
		at = at.get_parent()
	if at != null:
		if at.has_method(&"reveal"):
			at.call(&"reveal", control)
		else:
			(at as ScrollContainer).ensure_control_visible(control)
	await _frames(2)


func _click(control: Control) -> void:
	"""A left click at `control`'s centre, through the Viewport."""
	var at: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event)


func _floors(what: String, layer: Node) -> void:
	"""Every shown label and button under `layer` at least 14 px; every shown button at least 32 px tall."""
	var bad := PackedStringArray()
	for node: Node in layer.find_children("*", "Control", true, false):
		var control := node as Control
		if not (control is Label or control is Button) or not control.is_visible_in_tree():
			continue
		if String(control.get(&"text")).is_empty():
			continue
		if control.get_theme_font_size(&"font_size") < 14 or (control is Button and control.size.y < 32.0 - 0.01):
			bad.append("%s %dpx %.0f" % [control.name, control.get_theme_font_size(&"font_size"), control.size.y])
	_check("%s: text 14 px, buttons 32 px" % what, bad.is_empty(), ", ".join(bad))


func _capture(file_name: String) -> void:
	"""Save the frame now (only when asked for, and never headless)."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(2)
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [file_name, _size.x, _size.y]))
	_manager().set("_last_host_usec", Time.get_ticks_usec())


func _select(who: int) -> void:
	"""Select `who` alone and let the panel redraw."""
	_command().call(&"select", PackedInt32Array([who]))
	_command().call(&"_refresh_panel")
	await _frames(SETTLE_FRAMES)


# --- the steps ------------------------------------------------------------------------------------------------

func _names_everywhere() -> void:
	"""Every resident is its person, by the data file -- or, a placeholder with no row (nothing staged), keeps its
	key's label: never a stale trade label for a key that has a person."""
	var count: int = int(_cast().call(&"actor_count"))
	var right: int = 0
	for who: int in count:
		var actor: Node = _cast().call(&"actor", who)
		var key: StringName = actor.get("creature_key")
		var person: String = PeopleBook.name_of(key)
		var expected: String = person if not person.is_empty() else String(actor.call(&"friendly_name", key))
		if actor.get("display_name") == expected:
			right += 1
		_check("%s is named %s" % [key, expected], actor.get("display_name") == expected, actor.get("display_name"))
	_check("every resident named as its data says", right == count, "%d of %d" % [right, count])


func _the_roster() -> void:
	"""Residents (L): every row is its resident's name, species and role; a row clicked selects that resident."""
	var shell: Control = _village.call(&"_shell")
	var residents: int = int(shell.get_script().get_script_constant_map()["ID_RESIDENTS"])
	(shell.call(&"control_for", residents) as Button).pressed.emit()
	await _frames(SETTLE_FRAMES)
	var keeper: int = _index_of(&"mouse_keeper")
	var row: Button = shell.call(&"roster_row", maxi(keeper, 0))
	var name: String = String(_cast().call(&"actor", maxi(keeper, 0)).get("display_name"))
	_check("the roster's row names the resident", row.text.begins_with(name + " — "), row.text.get_slice("\n", 0))
	if keeper >= 0:
		_check("the trade stays a role", row.text.begins_with("Wenna Tallowby — mouse, keeper"), row.text.get_slice("\n", 0))
	await _capture("roster")
	_click(row)
	await _frames(SETTLE_FRAMES)
	_check("a row clicked selects that resident", _command().call(&"selected") == PackedInt32Array([maxi(keeper, 0)]),
		str(_command().call(&"selected")))


func _the_inspector() -> void:
	"""One resident: its name in the summary, its role, its skills as meters; About opened by a click shows its
	interest; the panel's floors hold."""
	var who: int = maxi(_index_of(&"squirrel_forester"), 0)
	await _select(who)
	var panel: CanvasLayer = _command().call(&"panel")
	var name: String = String(_cast().call(&"actor", who).get("display_name"))
	_check("the summary names the resident", String(panel.call(&"summary")).begins_with(name), panel.call(&"summary"))
	var section: Control = _section()
	_check("the person section shows", section.is_visible_in_tree())
	_check("its skills as meters", String(section.call(&"skill_line", 0)).begins_with("Felling · Level"),
		section.call(&"skill_line", 0))
	_check("four skills", not String(section.call(&"skill_line", 3)).is_empty(), section.call(&"skill_line", 3))
	var about: Button = section.call(&"about_button")
	await _reveal(about)
	_check("About is in view", _fraction(about) >= FULL, str(about.get_global_rect()))
	_check("details closed until asked", not bool(section.get(&"about_open")))
	_click(about)
	await _frames(SETTLE_FRAMES)
	_check("a click opens About", bool(section.get(&"about_open")))
	var has_person: bool = PeopleBook.has_person(_cast().call(&"actor", who).get("creature_key"))
	var interest: String = section.call(&"interest_text")
	_check("its interest (none for a placeholder)", interest.begins_with("Interest: ") if has_person else interest.is_empty(),
		interest)
	_floors("the inspector", panel)
	await _reveal(section.call(&"pin_button"))
	await _capture("inspector")


func _a_notable_moment() -> void:
	"""A rescue committed (see the header): the rescuer's moment reads it; a click on its row goes to the one it
	rescued (selected, the camera over them)."""
	var fisher: int = maxi(_index_of(&"otter_fisher"), 0)
	var mole: int = maxi(_index_of(&"mole_digger"), 1)
	var rescue: RefCounted = _village.call(&"waterplay").get("rescue")
	rescue.call(&"_log_assist", fisher, mole)
	_people().call(&"poll")
	await _select(fisher)
	var section: Control = _section()
	if not bool(section.get(&"about_open")):
		section.call(&"toggle_about")
	_command().call(&"_refresh_panel")
	await _frames(SETTLE_FRAMES)
	var row: Button = section.call(&"moment_row", 0)
	var words: String = section.call(&"moment_text", 0)
	_check("the moment is listed", words.contains("Brought ") and words.contains(" ashore"), words)
	if row == null:
		return
	await _reveal(row)
	_check("the moment's row in view", _fraction(row) >= FULL, str(row.get_global_rect()))
	await _capture("notable_event")
	_click(row)
	await _frames(SETTLE_FRAMES)
	_check("a click on it goes to the one rescued", _command().call(&"selected") == PackedInt32Array([mole]),
		str(_command().call(&"selected")))


func _the_spotlight() -> void:
	"""The spotlight card is shown, in the window, clear of the party panel; Spotlight ★ clicked marks the rescuer
	notable and the roster stars it."""
	var card: CanvasLayer = _village.call(&"people_card")
	var guide: Node = _village.call(&"guide")
	if bool(guide.get(&"card").call(&"is_shown")):
		card.call(&"refresh")
		_check("it waits while the guide's card shows (one card at the top centre)", not bool(card.call(&"is_shown")))
		guide.call(&"toggle_guide")
		await _frames(SETTLE_FRAMES)
	card.call(&"refresh")
	await _frames(SETTLE_FRAMES)
	_check("the spotlight shows", int(card.call(&"mode")) == CardScript.MODE_SPOTLIGHT, card.call(&"body_text"))
	var rect: Rect2 = card.call(&"frame_rect")
	_check("the card is in the window", Rect2(Vector2.ZERO, Vector2(_size)).encloses(rect), str(rect))
	var party: Rect2 = _command().call(&"panel").call(&"frame_rect")
	_check("clear of the party panel", not rect.intersects(party), "%s / %s" % [rect, party])
	var pause_card: CanvasLayer = _village.call(&"pause_card")
	var pause: Rect2 = pause_card.call(&"frame_rect") if bool(pause_card.call(&"is_shown")) else Rect2()
	_check("the pause card shows (paused)", bool(pause_card.call(&"is_shown")))
	_check("clear of the pause card (decision 0931)", not rect.intersects(pause), "%s / %s" % [rect, pause])
	_floors("the card", card)
	await _capture("spotlight")
	var fisher: int = maxi(_index_of(&"otter_fisher"), 0)
	_click(card.call(&"spotlight_button"))
	await _frames(SETTLE_FRAMES)
	_check("a click on Spotlight ★ marks it notable", bool(_people().call(&"is_notable", fisher)))
	_check("answered, the card goes", not bool(card.call(&"is_shown")))
	var roster: Node = _village.call(&"roster")
	_check("the roster stars it", String(roster.call(&"row_text", fisher)).contains("★"),
		String(roster.call(&"row_text", fisher)).get_slice("\n", 0))
