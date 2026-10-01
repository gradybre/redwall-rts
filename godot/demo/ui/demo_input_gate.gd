extends Node
## The live demo's one owner of modal input and keyboard focus (decision 0261; UI §3's "a single
## UIPanelRouter owns focus, open workspace, pause-reasons and dismissal stack", for the demo's own
## pop-ups). DEMO UI.
##
## MODALS. A demo pop-up that presents as modal -- the Pantry, the pause menu, the Demo Lab -- is
## WATCHED here (`watch_modal`): while its CanvasLayer is visible it is on the stack, and while any
## modal is on the stack
##   * a SCRIM (UI §3 layer 80) is laid under its frame, across the whole viewport, so no click, drag
##     or wheel outside the frame reaches the HUD or the world;
##   * key PRESSES are swallowed before any world handler reads them -- only focus navigation (Tab,
##     Shift+Tab, the arrows, Home/End, Page Up/Down), activation (Enter, Space), F11 and the modal's
##     own close keys get through; key RELEASES always pass, so a camera key held when it opened is let
##     go;
##   * Esc (and the modal's own close keys: K for the Pantry, F8 for the Lab) dismisses the top modal
##     one step (its `close` Callable) and is consumed, so the same press never also clears the
##     selection (UI §3: "Closing a modal does not also clear selection in the same key press");
##   * focus is TRAPPED: it lands on the modal's first control when it opens, Tab and Shift+Tab cycle its
##     controls, and when it closes focus goes back where it was (or to the world).
## This node is added LAST under the demo's root, so its `_input` and `_unhandled_input` run before every
## other demo node's (Godot calls them in reverse tree order) -- its `_input` before the Dig tool's and the
## HUD's. The HUD's `_unhandled_key_input` (its command keys, N) runs before any `_unhandled_input`, but the
## only presses a modal lets past `_input` are navigation, activation and F11, none of which it reads.
##
## FOCUS OUTSIDE A MODAL. The demo's panels are REGIONS (`add_region`): the right column (its tab strip
## and the four panels), the left column (the party panel's buttons) and the Map layer picker (decision 0391).
## F7 moves focus world -> right column -> left column -> map layers -> world; Tab and Shift+Tab cycle within
## the focused region in reading order
## (Godot's own traversal stops at each CanvasLayer); Esc with keyboard focus in a region gives it back
## to the world.
##
## ENTER AND SPACE BY FOCUSED CONTEXT (F30). A button holding the KEYBOARD's focus (Tab, F7 -- Godot
## 4.7 draws it, `has_focus(true)`) takes Enter and Space: the gate presses it and consumes the key, so
## the Dig tool's Enter (read in `_input`, before the GUI) and the world's Space pause never see it. A
## button holding a CLICK's focus (hidden, `has_focus(true)` false) does not: the gate drops that focus
## and lets the key go on, so Enter still digs the piece laid and Space still pauses, exactly as when no
## button could take focus.
##
## A click's focus also gives up the arrows and Page Up/Down (the camera's) and F7 starts from the world:
## a clicked button is not where the keyboard is.
##
## THE STALL BANNER comes first: while it shows (`yield_to`), the gate lets its Enter and Space through to
## it untouched; every other key is routed as ever, so an open modal still blocks the world and the HUD.
## THE HUD'S OWN WORKSPACE (`defer_to`: the shell's scrimmed workspace, UI-SET-051) is a modal the gate does
## not own: while it holds the input the gate routes nothing to the demo's panels -- no F7, Tab or press. An
## ORDINARY workspace (the Residents roster) is not modal, but it draws over the right column at 1280x720:
## `occlude_with` names it, and a control it covers is skipped by F7 and Tab and never pressed by Enter or
## Space (decision 0391).

const ROUTE_PASS: int = 0
const ROUTE_CONSUME: int = 1
const ROUTE_CLOSE: int = 2
const ROUTE_NEXT: int = 3
const ROUTE_PREVIOUS: int = 4
const ROUTE_SWITCH: int = 5
const ROUTE_TO_WORLD: int = 6
const ROUTE_PRESS: int = 7
const ROUTE_DROP_FOCUS: int = 8

## F7: world -> right column -> left column -> map layers -> world. F6 is UI §8.2's World list, F1-F5 and F9 are
## bound.
const FOCUS_SWITCH_KEY: Key = KEY_F7
## F11 is the demo's full-screen key (demo_window_keys.gd): it works over a modal.
const PASS_KEYS: Array[Key] = [KEY_F11]
## Keys a modal lets through to the focused control: focus movement and scrolling.
const NAVIGATION_KEYS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END,
	KEY_PAGEUP, KEY_PAGEDOWN]
const ENTER_KEYS: Array[Key] = [KEY_ENTER, KEY_KP_ENTER]
## The scrim: a light shade over the world and the HUD, which says they are out of reach.
const SCRIM_COLOUR: Color = Color(0.05, 0.04, 0.02, 0.32)
const SCRIM_NAME: String = "ModalScrim"


## One watched modal: its layer, the control whose descendants form its focus trap, how it is dismissed
## one step, its own close keys, and (while open) its scrim and where focus was before it opened.
class Modal:
	var layer: CanvasLayer = null
	var root: Node = null
	var close: Callable = Callable()
	var close_actions: Array[StringName] = []
	var close_keys: Array[Key] = []
	## Its close button, put last in its Tab order (UI §8.2: content, then Cancel) and never focused first.
	var last: Control = null
	var scrim: ColorRect = null
	var return_focus: Control = null
	## Whether that focus was drawn (the keyboard's): it comes back the same way.
	var return_drawn: bool = false


var _watched: Array[Modal] = []
var _stack: Array[Modal] = []
var _regions: Array = []
var _region_names: PackedStringArray = PackedStringArray()
var _yield_to: Callable = Callable()
var _defer_to: Callable = Callable()
var _cover: Callable = Callable()
## The one Focus the gate fills per key press (no allocation per event).
var _focus_now: Focus = null
## Whether the last press was the pointer's: a modal opened by a click takes focus without the ring.
var _pointer_last: bool = false
## Where focus went last (tests read it off-tree, where nothing can hold focus).
var last_focused: Control = null


func _init() -> void:
	"""Named for the scene tree."""
	name = "DemoInputGate"


func yield_to(shown: Callable) -> void:
	"""While `shown()` is true let Enter and Space through untouched (the stall banner takes them itself)."""
	_yield_to = shown


func defer_to(holds_input: Callable) -> void:
	"""While `holds_input()` is true a modal the gate does not own (the HUD's workspace) has the input: the
	gate routes nothing to the demo's panels."""
	_defer_to = holds_input


func occlude_with(cover: Callable) -> void:
	"""`cover() -> Rect2`: where a HUD surface drawn over the demo's panels stands now, in viewport pixels (the
	shell's ordinary workspace, which is not modal; an empty rect when none is open). A control under it is no
	focus stop, and Enter or Space on one already focused goes on to the world instead (decision 0391)."""
	_cover = cover


func covered(control: Control) -> bool:
	"""Whether `control` lies, even in part, under the cover (occlude_with)."""
	if not _cover.is_valid() or control == null:
		return false
	var cover: Rect2 = _cover.call()
	return cover.has_area() and screen_rect(control).intersects(cover)


static func screen_rect(control: Control) -> Rect2:
	"""A control's rectangle in viewport pixels, its frame's and its canvas layer's scale included (off-tree: its
	parents' transforms alone)."""
	var xform: Transform2D = control.get_global_transform_with_canvas() if control.is_inside_tree() \
		else control.get_global_transform()
	return Rect2(xform.origin, control.size * xform.get_scale())


func yields(event: InputEvent) -> bool:
	"""Whether `event` is the stall banner's: Enter or Space while it shows."""
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and is_activation(key) and _yield_to.is_valid() \
		and bool(_yield_to.call())


# --- registration -------------------------------------------------------------------------------

func watch_modal(layer: CanvasLayer, root: Node, close: Callable, close_actions: Array[StringName] = [],
		close_keys: Array[Key] = []) -> void:
	"""Treat `layer` as a modal while it is visible: `root` (the layer itself will do) holds its controls, `close` dismisses it one
	step (Esc), and `close_actions` / `close_keys` also close it (its own toggle key)."""
	var modal := Modal.new()
	modal.layer = layer
	modal.root = root
	modal.close = close
	modal.close_actions = close_actions
	modal.close_keys = close_keys
	_watched.append(modal)
	layer.visibility_changed.connect(_on_modal_visibility.bind(modal))
	if layer.visible:
		_open(modal)


func set_modal_close(layer: CanvasLayer, close_button: Control) -> void:
	"""Put a watched modal's close button last in its Tab order, so opening it focuses its content."""
	for modal: Modal in _watched:
		if modal.layer == layer:
			modal.last = close_button


func add_region(region_name: String, roots: Array[Node]) -> void:
	"""A focus region for F7 and Tab: `roots` in reading order (CanvasLayers or Controls); only their
	shown, focusable controls take part."""
	_regions.append(roots)
	_region_names.append(region_name)


func region_count() -> int:
	"""How many regions F7 cycles through (the world is not counted)."""
	return _regions.size()


# --- state ----------------------------------------------------------------------------------------

func modal_open() -> bool:
	"""Whether a modal owns input (the world is blocked)."""
	return not _stack.is_empty()


func top_layer() -> CanvasLayer:
	"""The top modal's layer, or null."""
	return _stack.back().layer if not _stack.is_empty() else null


func region_controls(index: int) -> Array[Control]:
	"""Region `index`'s focusable controls, in order, as they stand now -- less any the cover hides."""
	var ring: Array[Control] = focusables(_regions[index])
	var cover: Rect2 = _cover.call() if _cover.is_valid() else Rect2()
	if not cover.has_area():
		return ring
	var open: Array[Control] = []
	for control: Control in ring:
		if not screen_rect(control).intersects(cover):
			open.append(control)
	return open


func modal_controls() -> Array[Control]:
	"""The top modal's focusable controls, in order (empty when none is open)."""
	if _stack.is_empty():
		return []
	return _ring_of(_stack.back())


func _ring_of(modal: Modal) -> Array[Control]:
	"""A modal's focusable controls in Tab order: reading order, its close button last."""
	var roots: Array[Node] = [modal.root]
	var ring: Array[Control] = focusables(roots)
	if modal.last != null and ring.has(modal.last):
		ring.erase(modal.last)
		ring.append(modal.last)
	return ring


func region_of(control: Control) -> int:
	"""The region holding `control`, or -1."""
	if control == null:
		return -1
	for index: int in _regions.size():
		for root: Node in _regions[index]:
			if root == control or root.is_ancestor_of(control):
				return index
	return -1


func in_top_modal(control: Control) -> bool:
	"""Whether `control` is inside the top modal."""
	return control != null and not _stack.is_empty() and _stack.back().root.is_ancestor_of(control)


static func focusables(roots: Array[Node]) -> Array[Control]:
	"""Every shown control under `roots` that takes keyboard focus, in tree (reading) order."""
	var out: Array[Control] = []
	for root: Node in roots:
		if root != null and shown(root):
			_collect(root, out)
	return out


static func _collect(node: Node, out: Array[Control]) -> void:
	"""Depth-first: `node`'s focusable, visible buttons (a hidden branch is skipped whole). Only buttons:
	the action controls; a scroll box that happens to take focus is not a stop."""
	for child: Node in node.get_children():
		var item := child as CanvasItem
		if item != null and not item.visible:
			continue
		var button := child as BaseButton
		if button != null and button.focus_mode == Control.FOCUS_ALL:
			out.append(button)
		_collect(child, out)


static func shown(node: Node) -> bool:
	"""Whether `node` and every ancestor are visible -- CanvasItems and CanvasLayers alike. Read from the
	nodes themselves, so it holds off-tree too."""
	var at: Node = node
	while at != null:
		var item := at as CanvasItem
		if item != null and not item.visible:
			return false
		var layer := at as CanvasLayer
		if layer != null and not layer.visible:
			return false
		at = at.get_parent()
	return true


static func step(ring: Array[Control], current: Control, forward: bool) -> Control:
	"""The control after (or before) `current` in `ring`, wrapping; the first (or last) when `current` is
	not in it; null for an empty ring."""
	if ring.is_empty():
		return null
	var at: int = ring.find(current)
	if at < 0:
		return ring[0] if forward else ring[ring.size() - 1]
	return ring[(at + (1 if forward else ring.size() - 1)) % ring.size()]


# --- routing ----------------------------------------------------------------------------------------

## What the gate knows of the focus owner when it routes a key.
class Focus:
	## The control holding focus (null: the world has it).
	var control: Control = null
	## Whether that focus is the keyboard's (drawn; `has_focus(true)`), not a click's.
	var keyboard: bool = false
	## Whether that control is a button.
	var button: bool = false
	## Whether it is inside one of the regions.
	var in_region: bool = false


func route(event: InputEvent, focus: Focus) -> int:
	"""What to do with one event (ROUTE_*), given the focus. Only key presses are routed; everything else,
	key releases included, passes."""
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return ROUTE_PASS
	if modal_open():
		return _route_modal(key, focus)
	return _route_free(key, focus)


func _route_modal(key: InputEventKey, focus: Focus) -> int:
	"""A key press while a modal owns input: Esc and its close keys close it, Tab cycles it, Enter and
	Space press its keyboard-focused button, navigation and F11 pass; every other press is swallowed."""
	var code: Key = key_of(key)
	if code == KEY_ESCAPE:
		return ROUTE_CLOSE if not key.echo else ROUTE_CONSUME
	if NAVIGATION_KEYS.has(code):
		return ROUTE_PASS
	if key.echo:
		return ROUTE_CONSUME
	if closes_top(key):
		return ROUTE_CLOSE
	if code == KEY_TAB and not key.ctrl_pressed:
		return ROUTE_PREVIOUS if key.shift_pressed else ROUTE_NEXT
	if is_activation(key):
		return ROUTE_PRESS if focus.button and focus.keyboard and in_top_modal(focus.control) else ROUTE_CONSUME
	return ROUTE_PASS if PASS_KEYS.has(code) else ROUTE_CONSUME


func _route_free(key: InputEventKey, focus: Focus) -> int:
	"""A key press with no modal: F7 switches region, Tab cycles a region, Esc leaves one, and Enter and
	Space go to a keyboard-focused button -- or, from a click's focus, on to the world."""
	if key.echo or (_defer_to.is_valid() and bool(_defer_to.call())):
		return ROUTE_PASS
	var code: Key = key_of(key)
	if focus.button and not focus.keyboard and (NAVIGATION_KEYS.has(code) or is_activation(key)):
		return ROUTE_DROP_FOCUS
	if code == FOCUS_SWITCH_KEY and not _modified(key):
		return ROUTE_SWITCH
	if code == KEY_TAB and focus.in_region and not key.ctrl_pressed:
		return ROUTE_PREVIOUS if key.shift_pressed else ROUTE_NEXT
	if code == KEY_ESCAPE and focus.in_region and focus.keyboard:
		return ROUTE_TO_WORLD
	if is_activation(key) and focus.button:
		return ROUTE_DROP_FOCUS if covered(focus.control) else ROUTE_PRESS
	return ROUTE_PASS


func closes_top(key: InputEventKey) -> bool:
	"""Whether `key` is one of the top modal's own close keys or actions."""
	if _stack.is_empty():
		return false
	var modal: Modal = _stack.back()
	if modal.close_keys.has(key_of(key)) and not _modified(key):
		return true
	for action: StringName in modal.close_actions:
		if key.is_action_pressed(action, false, true):
			return true
	return false


static func is_activation(key: InputEventKey) -> bool:
	"""Enter (either) or Space, unmodified -- Ctrl+Space stays the global pause (UI §3)."""
	var code: Key = key_of(key)
	return (ENTER_KEYS.has(code) or code == KEY_SPACE) and not _modified(key)


static func key_of(key: InputEventKey) -> Key:
	"""The event's key: its logical key when it has one, else its physical key."""
	return key.keycode if key.keycode != KEY_NONE else key.physical_keycode


static func _modified(key: InputEventKey) -> bool:
	"""Whether Ctrl, Alt or Meta is held (Shift is Tab's own)."""
	return key.ctrl_pressed or key.alt_pressed or key.meta_pressed


# --- applying a route -------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	"""Route every key press before the GUI and the world (see the header)."""
	_note_pointer(event)
	if not (event is InputEventKey and event.is_pressed()) or yields(event):
		return
	var focus := focus_now()
	var verdict: int = route(event, focus)
	if verdict == ROUTE_PASS:
		return
	apply(verdict, focus)
	if verdict != ROUTE_DROP_FOCUS and is_inside_tree():
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	"""While a modal is open nothing but a key release reaches the world."""
	if modal_open() and not (event is InputEventKey and not event.is_pressed()):
		get_viewport().set_input_as_handled()


func focus_now() -> Focus:
	"""The focus as it stands (the world's, off-tree), in the gate's one reused Focus."""
	if _focus_now == null:
		_focus_now = Focus.new()
	var focus: Focus = _focus_now
	focus.control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	focus.keyboard = focus.control != null and focus.control.has_focus(true)
	focus.button = focus.control is BaseButton
	focus.in_region = focus.control != null and region_of(focus.control) >= 0
	return focus


func apply(verdict: int, focus: Focus) -> void:
	"""Carry out one route (ROUTE_*) for this focus."""
	match verdict:
		ROUTE_CLOSE:
			close_top()
		ROUTE_NEXT, ROUTE_PREVIOUS:
			var ring: Array[Control] = modal_controls() if modal_open() \
				else region_controls(region_of(focus.control))
			_focus(step(ring, focus.control, verdict == ROUTE_NEXT), true)
		ROUTE_SWITCH:
			switch_region(focus.control if focus.keyboard else null)
		ROUTE_TO_WORLD, ROUTE_DROP_FOCUS:
			if focus.control != null:
				focus.control.release_focus()
		ROUTE_PRESS:
			press(focus.control as BaseButton)


func close_top() -> void:
	"""Dismiss the top modal one step (its own `close`: a page back, or shut)."""
	if not _stack.is_empty() and _stack.back().close.is_valid():
		_stack.back().close.call()


func switch_region(from: Control) -> void:
	"""F7: focus the next region with something to focus after the one holding `from` (none: the first);
	past the last, back to the world."""
	var at: int = region_of(from)
	for index: int in range(at + 1, _regions.size()):
		var ring: Array[Control] = region_controls(index)
		if not ring.is_empty():
			_focus(ring[0], true)
			return
	last_focused = null
	if from != null and from.is_inside_tree():
		from.release_focus()


static func press(button: BaseButton) -> void:
	"""Activate a button as a click would: a toggle flips, then `pressed` is emitted. A disabled one
	does nothing."""
	if button == null or button.disabled:
		return
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	button.pressed.emit()


func _focus(control: Control, keyboard: bool) -> void:
	"""Give `control` focus -- drawn (the keyboard's) or hidden (after a click)."""
	last_focused = control
	if control != null and control.is_inside_tree():
		control.grab_focus(not keyboard)


func _note_pointer(event: InputEvent) -> void:
	"""Remember whether the last press was the pointer's or the keyboard's."""
	if event is InputEventMouseButton and event.is_pressed():
		_pointer_last = true
	elif event is InputEventKey and event.is_pressed():
		_pointer_last = false


# --- opening and closing modals ---------------------------------------------------------------------

func _on_modal_visibility(modal: Modal) -> void:
	"""A watched layer shown or hidden: open or close it as a modal."""
	if modal.layer.visible:
		_open(modal)
	else:
		_close(modal)


func _open(modal: Modal) -> void:
	"""Put a modal on the stack: its scrim under its frame, and focus on its first control (the one before
	it kept, to go back to)."""
	if _stack.has(modal):
		return
	modal.return_focus = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	modal.return_drawn = modal.return_focus != null and modal.return_focus.has_focus(true)
	modal.scrim = _scrim()
	modal.layer.add_child(modal.scrim)
	modal.layer.move_child(modal.scrim, 0)
	modal.scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.append(modal)
	var ring: Array[Control] = _ring_of(modal)
	if not ring.is_empty():
		_focus(ring[0], not _pointer_last)


func _close(modal: Modal) -> void:
	"""Take a modal off the stack: its scrim goes, and focus goes back where it was before it opened (or
	to the world when that control is gone or hidden)."""
	var at: int = _stack.find(modal)
	if at < 0:
		return
	_stack.remove_at(at)
	if modal.scrim != null and is_instance_valid(modal.scrim):
		modal.layer.remove_child(modal.scrim)
		modal.scrim.queue_free()
	modal.scrim = null
	var back: Control = modal.return_focus
	modal.return_focus = null
	if not _stack.is_empty():
		var ring: Array[Control] = _ring_of(_stack.back())
		_focus(ring[0] if not ring.is_empty() else null, true)
	elif back != null and is_instance_valid(back) and back.is_inside_tree() and shown(back) \
			and back.focus_mode != Control.FOCUS_NONE:
		_focus(back, modal.return_drawn)
	else:
		last_focused = null


func _scrim() -> ColorRect:
	"""UI §3's scrim: the whole viewport, taking every click, under the modal's frame."""
	var scrim := ColorRect.new()
	scrim.name = SCRIM_NAME
	scrim.color = SCRIM_COLOUR
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.focus_mode = Control.FOCUS_NONE
	return scrim


func scrim_of(layer: CanvasLayer) -> ColorRect:
	"""The scrim an open modal's layer wears (null when it is not open)."""
	for modal: Modal in _stack:
		if modal.layer == layer:
			return modal.scrim
	return null
