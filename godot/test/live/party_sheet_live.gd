extends RefCounted
## The live harnesses' one way into the party sheet (decision 1891). Where the Demo party panel is compact (1280x720,
## where the level bar takes the column's foot), its inspector -- the group section, the member rows, one resident's
## lines and person -- is in the folded party sheet; a harness that reads or clicks a control there opens the sheet
## first, with a real click on Open, as a player would. Shared by demo_select_live.gd, demo_people_live.gd and
## demo_care_live.gd.


static func open_for(control: Control, party: CanvasLayer) -> bool:
	"""Where `control` is in `party`'s folded sheet, click Open through the root Viewport and return true (the caller
	waits a few frames for the layout); false where there is nothing to open (the full form, or already open)."""
	var sheet: CanvasLayer = party.call(&"sheet")
	if not sheet.is_ancestor_of(control) or bool(sheet.call(&"is_open")):
		return false
	click(party.call(&"open_button"))
	return true


static func click(control: Control) -> void:
	"""A left click at `control`'s centre: a move, a press and its release, pushed to the root Viewport."""
	var at: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2.0)
	var root: Viewport = control.get_tree().root
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
