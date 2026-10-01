extends ScrollContainer
## A demo panel's vertical scroll that brings the focused control into view at ANY frame scale. Decision 0391.
## DEMO UI.
##
## The demo's panels are laid out in the HUD's logical pixels and drawn at its scale S through their frame's own
## `scale` (decision 0196). Godot's `follow_focus` / `ensure_control_visible` work in global (drawn) pixels but
## set the scroll in the container's own (logical) ones, so at S != 1 (125 %, 150 %, a 4K window) they scroll
## too far and the focused row lands out of view. `reveal` works in the container's own pixels instead, and runs
## whenever focus moves to a control inside it (Tab, F7, the input gate).

## The gap kept round a revealed control, logical px.
const MARGIN: float = 4.0


func _init() -> void:
	"""Vertical only; focus is followed here, not by the engine (see the header)."""
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = false


func _ready() -> void:
	"""Follow the viewport's focus."""
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _on_focus_changed(control: Control) -> void:
	"""Bring a newly focused control of ours into view."""
	if control != null and is_ancestor_of(control):
		reveal(control)


func reveal(control: Control) -> void:
	"""Scroll the least distance that shows all of `control` (its top, when it is taller than the view)."""
	var top: float = offset_in(control)
	if top < 0.0:
		return
	var bottom: float = top + control.size.y
	var view: float = size.y
	if bottom - top + 2.0 * MARGIN > view:
		scroll_vertical = int(top)
	elif top - MARGIN < float(scroll_vertical):
		scroll_vertical = int(maxf(top - MARGIN, 0.0))
	elif bottom + MARGIN > float(scroll_vertical) + view:
		scroll_vertical = int(ceilf(bottom + MARGIN - view))


func offset_in(control: Control) -> float:
	"""`control`'s top within this scroll's content, in the content's own pixels (-1 when it is not inside it)."""
	if get_child_count() == 0:
		return -1.0
	var content: Node = get_child(0)
	var y: float = 0.0
	var at: Node = control
	while at != null and at != content:
		var item := at as Control
		if item == null:
			return -1.0
		y += item.position.y
		at = at.get_parent()
	return y if at == content else -1.0
