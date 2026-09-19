# Bounded UI repair final functions
Source SHA256 044f44ce53207ac99dd50c816a1e33775674c7650c0d9eaa0bab0bc23831debe
```gdscript
func _recompute_selection_gate() -> void:
	"""UI-C4-R01: SELECTED reflects any live reference OR an open detail/tile context.

	`Gates.has_selection` was written nowhere, so every SELECTED-gated element -- the journal,
	its tabs, Pin -- was permanently §4-ABSENT even while visibly drawn. A tile has no stored
	resident/job/zone reference at all (`ui_manager.gd` opens tile detail through
	`set_detail_display()`/`set_detail_open()` alone), so the open detail panel itself is also
	a selected context, not only the four typed references.
	"""
	_gates.has_selection = _detail_open \
		or _selected_basin != EntityDirectoryScript.NULL_REF \
		or _selected_zone != EntityDirectoryScript.NULL_REF \
		or _selected_job != EntityDirectoryScript.NULL_REF \
		or _selected_resident != EntityDirectoryScript.NULL_REF
	if not _built:
		return
	_register_hit_regions()
	_wire_focus()



```
```gdscript
func open_workspace_page(page_id: int, opener_id: int = ID_RESIDENTS) -> bool:
	"""Show one workspace page, taking its opening focus and retiring the outgoing one.

	§3 allows only one primary management workspace open, so opening a second REPLACES the
	first. The router decides what that means for focus; this function's job is to act on the
	answer -- hide the members it retires and re-register the hit table, so a control that is
	no longer shown cannot keep an input rectangle."""
	if not WORKSPACE_PAGES.has(page_id):
		return _refuse(REFUSE_UNKNOWN_ELEMENT)
	if _registry.gate_of(page_id).value == UiRegistry.GATE_SELECTED and not _gates.has_selection:
		return _refuse(REFUSE_NO_TARGET)
	var members: PackedInt32Array = PackedInt32Array([page_id])
	if not _focus.open_surface(page_id, members, members.size(), opener_id):
		return _refuse(REFUSE_UNKNOWN_ELEMENT)
	_retire_outgoing_members()
	_workspace_page = page_id
	_apply_workspace_gate(page_id, true)
	(_zones[ID_WORKSPACE] as Control).visible = true
	_show_open_page()
	_apply_geometry()
	# Context changes must refresh input and focus even when an off-tree layout cannot run.
	_register_hit_regions()
	_wire_focus()
	_last_refusal = REFUSE_NONE
	return true



```
```gdscript
func _apply_workspace_gate(page_id: int, open: bool) -> void:
	"""UI-C4-R01: opening a workspace page must gate the frame and its Back action too.

	§4 gates UI-SET-051 (the frame) and UI-SET-092 (Back) on WORKSPACE, exactly the same fact
	as the page itself. Only the page's own surface bit was being written, so the frame and
	Back stayed §4-ABSENT under a truly open page: `_register_hit_regions()` reads
	`creates_control()` before it will register a region, so a visibly drawn, opaque frame
	was absent from the hit table. The engine-input baseline confirms Godot consumed
	those clicks; the table was the inconsistent layer.
	"""
	_gates.set_surface_open(page_id, open)
	_gates.set_surface_open(ID_WORKSPACE, open)
	_gates.set_surface_open(ID_BACK, open)
	_gates.set_surface_open(ID_SEARCH, open)



```
```gdscript
func _on_back_pressed() -> void:
	"""UI-SET-092: close the workspace frame. A CLOSE, never a toggle: it always ends closed.

	§2.2: focus returns to the opening control if still present, otherwise the zone's first
	control. The router owns both branches; closing without it left focus standing on a
	control that had just been hidden. §4 gates the frame (051) and Back (092) on WORKSPACE
	exactly as it gates the page itself, so both drop with it here too, and a second press
	must find nothing left open to reopen -- `_toggle_zone()` flips visibility either way and
	could reopen what the first press had just closed.
	"""
	_focus.close_surface(_gates)
	_retire_outgoing_members()
	_apply_workspace_gate(_workspace_page, false)
	(_zones[ID_WORKSPACE] as Control).visible = false
	_register_hit_regions()
	_wire_focus()
	shell_action.emit(ID_BACK)



```
```gdscript
func _register_hit_regions() -> void:
	"""Mirror the built tree's own mouse filters into the §1.2 click-through table.

	The `consumes` flag is READ FROM THE CONTROL, not asserted here, so the table cannot
	disagree with what the engine will actually do with the event.
	"""
	_hits.reset()
	for id: int in _controls:
		var control: Control = _controls[id]
		if not control.visible or not _is_visible_chain(control):
			continue
		var consumes: bool = control.mouse_filter != Control.MOUSE_FILTER_IGNORE
		_hits.add_visible_region(id, _shell_rect_of(control), _layer_of(id), consumes,
			_availability.creates_control(id, _gates))
	_register_second_card_region()
	if _workspace_owns_input():
		_hits.raise_scrim(UiHitTest.LAYER_MODAL)
	else:
		_hits.lower_scrim()



```
```gdscript
func _wire_focus() -> int:
	"""Write the computed focus order onto the real Controls. Returns the stops wired.

	UXV-033 names "focus-list data without runtime wiring" as insufficient, and that was
	exactly the state: `ui_focus_order.gd` computed a correct order, was unit-tested, and
	NOTHING CALLED IT -- `bind_controls()` and `wire_hud()` had no call site anywhere in the
	repository. `focus_next`, `focus_previous` and the four `focus_neighbor_*` properties are
	what Godot's own Tab and arrow navigation read, so until they are written the order is a
	data structure and not a behaviour. Called from `_apply_geometry()` because the visible
	set changes with the profile, so the order must be recomputed when the layout changes."""
	_focus.bind_controls(_controls)
	var wired: int = _focus.wire_hud(_gates)
	_wire_second_card_focus()
	return wired



```
```gdscript
func set_detail_open(open: bool) -> void:
	"""Open or close UI-SET-036, which also changes §1.2's command-strip interval."""
	_detail_open = open
	(_zones[ID_DETAIL] as Control).visible = open
	_recompute_selection_gate()
	_apply_geometry()



```
```gdscript
func select_resident(resident: Vector2i, proposed_name: String) -> void:
	"""Select a resident and the name typed into UI-SET-082's editor."""
	_selected_resident = resident
	_pending_name = proposed_name
	_recompute_selection_gate()



```
```gdscript
func select_job(job: Vector2i) -> void:
	"""Select a queued job, which the quick menu can cancel."""
	_selected_job = job
	_recompute_selection_gate()



```
```gdscript
func select_zone(zone: Vector2i, enabled: bool) -> void:
	"""Select a designated zone, carrying the enabled flag its policy toggle will invert.

	This is also the ONLY thing that shows UI-SET-100. UXV-023: "zone harvesting policies never
	appear on a resident merely because a template exists", and the journal used to carry a
	`Harvesting enabled` toggle under every resident's needs -- an action that could only ever
	refuse with UI_SHELL_NOTHING_SELECTED, because a resident is not a zone.
	"""
	_selected_zone = zone
	_selected_zone_enabled = enabled
	(_controls[ID_WORK_POLICY] as Control).visible = zone != EntityDirectoryScript.NULL_REF
	_recompute_selection_gate()



```
```gdscript
func clear_resident_detail() -> void:
	"""Empty every row that only a resident fills, and hide the medallion with them."""
	_detail_emblem.texture = null
	_detail_emblem.visible = false
	_detail_health.text = ""
	_detail_activity.text = ""
	_detail_note.text = ""
	## UXV-023: the harvesting policy belongs to a zone, and a new selection is not one until
	## `select_zone()` says so. Hiding it here means a resident can never inherit the last
	## zone's toggle.
	(_controls[ID_WORK_POLICY] as Control).visible = false
	_selected_zone = EntityDirectoryScript.NULL_REF
	for index: int in _need_rows.size():
		_need_names[index].text = ""
		_need_values[index].text = ""
		_need_rates[index].text = ""
		_need_basis_points[index] = 0
		_need_rows[index].visible = false
	_recompute_selection_gate()



```
