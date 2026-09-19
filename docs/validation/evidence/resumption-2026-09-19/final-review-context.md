# Exact final source excerpts and diff for bounded independent review

## godot/scripts/ui/ui_shell.gd SHA256 14ef762a474afbd28254312207ec4fa8c5b0efab744935b80a58a696623abdbc
```gdscript
func build() -> bool:
	"""Create every element this shell renders. Public so a headless test can build off-tree."""
	if _built:
		return true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = load(THEME_PATH) as Theme
	_build_world_surface()
	_build_resources()
	_build_alerts()
	_build_time()
	_build_minimap()
	_build_commands()
	_build_detail()
	_build_workspace()
	_build_overlays()
	_apply_frames()
	_built = true
	_last_refusal = REFUSE_NONE
	return true


# --- construction ---------------------------------------------------------------------------------
```
```gdscript
func _ready() -> void:
	"""Build the HUD, keep processing through pauses, and lay out for the current viewport."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _built:
		build()
	resized.connect(_on_resized)
	_apply_geometry()
```
```gdscript
func _new_panel(id: int, text: String) -> Panel:
	"""Create one §4 PANEL/MODAL/NOTICE element: opaque, sized from the registry, hit-testable."""
	var panel: Panel = Panel.new()
	panel.name = String(_registry.element_key(id))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.theme_type_variation = PROFILE_VARIATION[_registry.profile_of(id).value]
	panel.custom_minimum_size = _control_minimum_size(id)
	panel.size = panel.custom_minimum_size
	_apply_semantics(panel, id, text)
	_controls[id] = panel
	if not _availability.is_wired(id):
		var reason: Label = _new_text(panel, &"Unavailable", _availability.unavailable_label(id))
		reason.clip_text = false
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return panel
```
```gdscript
func _new_button(id: int, text: String) -> Button:
	"""Create one §4 BUTTON/TOGGLE element, disabled when its owning store does not exist."""
	var button: Button = Button.new()
	button.name = String(_registry.element_key(id))
	button.text = text
	button.custom_minimum_size = _minimum_size(id)
	button.clip_text = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = _registry.profile_of(id).value == UiRegistry.PROFILE_TOGGLE
	button.disabled = not _availability.is_wired(id)
	button.focus_entered.connect(_on_control_focused.bind(id))
	_style_button(button, id)
	_apply_semantics(button, id, text)
	_controls[id] = button
	return button
```
```gdscript
func _build_detail() -> void:
	"""UI-SET-036's resident journal, in UXV-019's order, with a scrolling body.

	§4.1 fixes the hierarchy: (1) full name, species, close control and generic emblem;
	(2) health; (3) five needs; (4) current activity and skills. The header and the close stay
	pinned and the body below them SCROLLS, because five 52 px need rows plus health, activity
	and skills do not fit the 336 px narrow column and §4.1 says "long content scrolls inside
	the panel, not past the window".

	UI-IDENTITY-R01 gives this panel a DEDICATED header/body/footer rather than the generic
	vertical flow: a fixed identity header that grows with the name, a scrolling body, and
	§4.1's fixed 64 px action footer. Only the body scrolls.
	"""
	var detail: Panel = _zone_panel(ID_DETAIL, "Details")
	detail.visible = false
	_build_detail_header(detail)
	_build_detail_body(detail)
	_build_detail_footer(detail)
```
```gdscript
func _build_workspace() -> void:
	"""UI-SET-051's frame: a scrolling content column above a fixed action footer.

	§1.3: "Long inventories/rosters: Virtualized rows,44 px base height" and "Large text: Scroll
	panels vertically; fixed bottom confirmation row". A roster of twelve already overflows the
	frame, so the content scrolls and the footer does not move with it.
	"""
	var frame: Panel = _zone_panel(ID_WORKSPACE, "Workspace")
	frame.visible = false
	frame.clip_contents = true
	_decorate(frame)
	_workspace_title = _new_text(frame, &"Title", "")
	_workspace_title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_workspace_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_workspace_title.theme_type_variation = &"WoodlandPanelTitle"
	_workspace_scroll = ScrollContainer.new()
	_workspace_scroll.name = "Scroll"
	_workspace_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_workspace_scroll)
	_workspace_column = VBoxContainer.new()
	_workspace_column.name = "Content"
	_workspace_column.add_theme_constant_override(&"separation", int(ROW_GAP))
	_workspace_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace_scroll.add_child(_workspace_column)
	_workspace_column.add_child(_new_label(ID_SEARCH, ""))
	var new_world: Panel = _new_panel(ID_NEW_SETTLEMENT, "Create a settlement")
	_workspace_column.add_child(new_world)
	_build_create_action(new_world)
	_workspace_column.add_child(_new_panel(ID_WORLD_LIST, "World locations and entities"))
	_workspace_column.add_child(_new_panel(ID_NAME_EDITOR, "Name this notable resident"))
	_build_roster(_workspace_column)
	var back: Button = _new_button(ID_BACK, "Back")
	back.pressed.connect(_on_back_pressed)
	frame.add_child(back)
	var bar: VScrollBar = _workspace_scroll.get_v_scroll_bar()
	bar.custom_minimum_size = _minimum_size(ID_SCROLL)
	_apply_semantics(bar, ID_SCROLL, "Scroll the workspace")
	_controls[ID_SCROLL] = bar
```
```gdscript
func layout_for(width: int, height: int) -> bool:
	"""Lay the HUD out for an explicit viewport size. Used by the headless suite."""
	if not _layout.compute_into(width, height, _user_scale, _detail_open, _geometry):
		return _refuse(_layout.last_refusal())
	_place_zones()
	_apply_scale_transform()
	_register_hit_regions()
	_wire_focus()
	_last_refusal = REFUSE_NONE
	return true
```
```gdscript
func _apply_geometry() -> void:
	"""Lay out for the canvas this shell is drawn into, keeping the last layout if it refuses.

	THE SIZE USED HERE IS THE CANVAS SIZE, NOT THE WINDOW SIZE, AND AT PRESENT THOSE DIFFER.
	`project.godot` sets `window/stretch/mode="canvas_items"` against a 1920x1080 base, so a
	1280x720 window gives this Control a 1920x1080 rectangle and scales the whole canvas by
	0.667 -- measured, not assumed: the shell reports profile WIDE in a 1280x720 window.
	§1.2 says the opposite: "Do not scale the entire game through a low-resolution pixel
	viewport ... retain crisp fonts and explicit logical layout", and its own equations would
	give Lw 1280 and the STANDARD profile there.
	Laying out against the window size instead would be worse, not better: the rectangles would
	then be scaled a second time by the same stretch transform. The fix belongs in
	`project.godot`, which the integration lead owns, and is reported rather than worked around.
	"""
	var viewport: Vector2 = size
	if not is_inside_tree() or viewport.x <= 0.0:
		return
	layout_for(int(viewport.x), int(viewport.y))
```
```gdscript
func _show_open_page() -> void:
	"""Show exactly the open workspace page and hide the others.

	§3: "Only one primary management workspace open". Called from `open_workspace_page()` as
	well as from the layout pass, because which page is open is not a geometry question --
	`_apply_geometry()` refuses when the canvas has no size, and page visibility must not
	depend on whether a layout happened to succeed."""
	for id: int in WORKSPACE_PAGES:
		_page_control_of(id).visible = id == _workspace_page
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
func _layer_of(id: int) -> int:
	"""§3's layer for an element: world overlay, permanent HUD, expansion, workspace or modal."""
	if id == ID_WORLD_SURFACE:
		return UiHitTest.LAYER_WORLD_OVERLAY
	if id == ID_TOOLTIP:
		return UiHitTest.LAYER_TOOLTIP
	if id == ID_QUICK_MENU:
		return UiHitTest.LAYER_QUICK_MENU
	if id == ID_WORKSPACE or WORKSPACE_PAGES.has(id):
		return _workspace_layer()
	if id == ID_LEDGER or id == ID_HISTORY or id == ID_CALENDAR or id == ID_DETAIL:
		return UiHitTest.LAYER_EXPANSION
	return UiHitTest.LAYER_PERMANENT_HUD
```
```gdscript
func _workspace_owns_input() -> bool:
	"""True while an open workspace holds a SCRIM and the HUD behind it is out of input and focus.

	UI-C3-R01 §4: the compact variant retains "focus trap and SCRIM ... Background HUD controls are
	excluded from input/focus while this compact modal owns input", and "Do not let a click through
	a dimmed alert issue a world command." An ORDINARY workspace raises no scrim at all, which is
	§4.2's "no SCRIM or full-screen input block" -- the HUD stays live beside it.
	"""
	if not (_zones[ID_WORKSPACE] as Control).visible:
		return false
	return _workspace_page == ID_NAME_EDITOR or workspace_is_compact()
```
```gdscript
func _workspace_layer() -> int:
	"""§3's layer for the workspace frame and its open page: 40 ordinary, 80 modal or compact.

	SET-UX-VIS-002 §4.2 gives the ordinary workspace "z40, no SCRIM or full-screen input block"
	and the compact roster "z80, SCRIM and focus trap"; the New Settlement and name MODAL variants
	keep 80 with their own contracts. Every page used to return 80, which is how a roster came to
	sit in the modal layer above the permanent HUD.
	"""
	if MODAL_PAGES.has(_workspace_page) or UiLayout.workspace_is_compact(_geometry):
		return UiHitTest.LAYER_MODAL
	return UiHitTest.LAYER_WORKSPACE


# --- bindings ---------------------------------------------------------------------------------------
```
```gdscript
func _is_visible_chain(control: Control) -> bool:
	"""True when a control and every ancestor up to this shell are visible."""
	var node: Node = control.get_parent()
	while node != null and node != self:
		if node is Control and not (node as Control).visible:
			return false
		node = node.get_parent()
	return true
```
```gdscript
func _shell_rect_of(control: Control) -> Rect2:
	"""A control's rectangle in this shell's coordinates, summed from its own parent chain.

	`global_position` is not used: the headless suite builds this tree without a Window, and a
	rectangle that is only correct inside a real tree cannot be the one a test interrogates.
	"""
	var origin: Vector2 = control.position
	var node: Node = control.get_parent()
	while node != null and node != self:
		if node is Control:
			origin += (node as Control).position
		node = node.get_parent()
	return Rect2(origin, control.size)
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
```gdscript
func set_detail_open(open: bool) -> void:
	"""Open or close UI-SET-036, which also changes §1.2's command-strip interval."""
	_detail_open = open
	(_zones[ID_DETAIL] as Control).visible = open
	_recompute_selection_gate()
	_apply_geometry()
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
	var members: PackedInt32Array = PackedInt32Array([page_id])
	if not _focus.open_surface(page_id, members, members.size(), opener_id):
		return _refuse(REFUSE_UNKNOWN_ELEMENT)
	_retire_outgoing_members()
	_workspace_page = page_id
	_apply_workspace_gate(page_id, true)
	(_zones[ID_WORKSPACE] as Control).visible = true
	_show_open_page()
	_apply_geometry()
	# Context changes must refresh input even when an off-tree layout cannot run.
	_register_hit_regions()
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
```
```gdscript
func _retire_outgoing_members() -> void:
	"""Hide every member of the surface the last switch retired, so none keeps a hit region."""
	var count: int = _focus.outgoing_into(_outgoing)
	for index: int in count:
		var id: int = _outgoing[index]
		if _controls.has(id):
			(_controls[id] as Control).visible = false
		_gates.set_surface_open(id, false)
```
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
	_register_hit_regions()
```
```gdscript
func select_basin(basin: Vector2i, danger_band: int) -> bool:
	"""Point the zone tool at a generated ecology basin. Refuses a band §5.5 does not define."""
	if danger_band < DANGER_MIN or danger_band > DANGER_MAX:
		return _refuse(REFUSE_TILE_RANGE)
	_selected_basin = basin
	_selected_basin_danger = danger_band
	_recompute_selection_gate()
	_last_refusal = REFUSE_NONE
	return true
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
func select_job(job: Vector2i) -> void:
	"""Select a queued job, which the quick menu can cancel."""
	_selected_job = job
	_recompute_selection_gate()
```
```gdscript
func select_resident(resident: Vector2i, proposed_name: String) -> void:
	"""Select a resident and the name typed into UI-SET-082's editor."""
	_selected_resident = resident
	_pending_name = proposed_name
	_recompute_selection_gate()
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
	shell_action.emit(ID_BACK)
```
```gdscript
func _on_close_pressed() -> void:
	"""UI-SET-093: close the detail panel."""
	set_detail_open(false)
	shell_action.emit(ID_CLOSE)
```

## godot/scripts/core/inventory.gd SHA256 fb5edbddab8c8852148a544d010ede1b03750016f9432aa0b7a3f93bacb8b848
```gdscript
func set_seed_expiry_authority(authority: Object) -> OpResult:
	"""Bind -- or with null, unbind -- STOCK-SEED-R01's seed-consumer eligibility predicate.

	Refused while a transaction is open, and refused for an object that does not publish
	`refuses_seed_consumption(lot_ref) -> bool`: a guard that is bound but cannot be called
	would be enforcement in name only. The binding is wiring, not simulation state: it is not
	journaled, not part of state_bytes(), and survives clear().
	"""
	if _tx_open:
		return _refuse(REFUSE_TRANSACTION_OPEN)
	if authority != null and not authority.has_method(SEED_EXPIRY_ATTESTATION_METHOD):
		return _refuse(REFUSE_INVALID_SEED_EXPIRY_AUTHORITY)
	# An explicit unbind and a released binding are DIFFERENT states and stay different: null
	# enforces nothing, while a dead WeakRef refuses every consumer in the guard below.
	if authority == null:
		_seed_expiry_authority = null
	else:
		_seed_expiry_authority = weakref(authority)
	return _ok(NULL_REF, 0)
```
```gdscript
func has_seed_expiry_authority() -> bool:
	"""True when a LIVE seed-expiry authority is bound and seed consumption is enforced.

	False for never bound, for explicitly unbound, AND for a binding whose object has been
	released -- but only the first two admit anything. The third still REFUSES consumption.
	"""
	if _seed_expiry_authority == null:
		return false
	return _seed_expiry_authority.get_ref() != null
```
```gdscript
func _seed_consumption_refusal(lot_ref: Vector2i) -> StringName:
	"""REFUSE_SEED_PAST_SHELF_LIFE when the bound authority rejects this lot, else REFUSE_NONE.

	The one place this module asks about seed age. `_attesting` is raised across the call so
	`_guard()` refuses every mutator an authority might re-enter with, and no `_math` or `_plan`
	value may be held across it -- which is why every caller asks before it costs anything.

	STOCK-C4-LIFETIME-R01: the binding is borrowed, so a PREVIOUSLY BOUND authority that has been
	released fails CLOSED with INVALID_SEED_EXPIRY_AUTHORITY. It never degrades into the unbound
	case, which enforces nothing. The strong local below holds a live predicate for the call only.
	"""
	if _seed_expiry_authority == null:
		return REFUSE_NONE
	var authority: Object = _seed_expiry_authority.get_ref()
	if authority == null:
		return REFUSE_INVALID_SEED_EXPIRY_AUTHORITY
	_attesting = true
	var refuses: bool = bool(authority.call(SEED_EXPIRY_ATTESTATION_METHOD, lot_ref))
	_attesting = false
	if refuses:
		return REFUSE_SEED_PAST_SHELF_LIFE
	return REFUSE_NONE
```
```gdscript
func _guard() -> StringName:
	"""Refuse before touching state: attestation re-entry, a poisoned transaction, a full journal.

	The attestation check comes first because it is the only one that can be true while the
	caller is not this module at all -- an authority re-entering from inside `_attests()`.
	"""
	if _attesting:
		return REFUSE_ATTESTATION_REENTRY
	if _tx_poisoned:
		return REFUSE_TRANSACTION_POISONED
	if _j_count + MAX_JOURNAL_PER_OP > JOURNAL_CAPACITY:
		return REFUSE_JOURNAL_FULL
	return REFUSE_NONE
```
```gdscript
func reserve_lot(lot_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Claim quantity on a lot, enforcing GDD §4.2's `total per lot <= quantity`.

	BLOCKED, U4/U5: the Reservation row store (job, lot, quantity_milli, expiry, purpose; at
	most 32768 rows) attaches HERE, once its indexing is specified. 32768 rows against 8192
	Job rows implies an owner-major `job*4+i` layout that neither document states and that
	would cap a recipe at four input lots, and U5 budgets no allocator storage for it. So this
	release keeps only the per-lot total, which IS specified, and the owner-side rows that
	would let a lease expire (BAL-SAFE-004) or a job release its claims in job-ID order
	(REQ-SET-116) are deliberately absent rather than guessed.
	"""
	var owned: bool = _enter()
	if quantity_milli <= 0:
		return _leave(owned, REFUSE_INVALID_QUANTITY)
	return _leave(owned, _change_reservation(lot_ref, quantity_milli))
```
```gdscript
func sink_lot_quantity(lot_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Consume unreserved quantity out of the world. This is a conservation SINK.

	Consuming a lot to zero retires its row, so an emptied lot cannot hold a row against the
	16384-lot cap (REQ-SET-120).
	"""
	var owned: bool = _enter()
	return _leave(owned, _remove_quantity(lot_ref, quantity_milli, false))
```
```gdscript
func split_lot(lot_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Split `quantity_milli` off a lot into a new sibling lot in the same container.

	Quantity is conserved exactly. Charged mass may rise, because BAL-SAFE-016 rounds each
	child up on its own, and a split that would exceed the container is refused rather than
	being allowed to manufacture capacity. Reservations stay attached to the source lot, so
	only unreserved quantity may be split off.
	"""
	var owned: bool = _enter()
	return _leave(owned, _split_lot_checked(lot_ref, quantity_milli))
```
```gdscript
func _init(p_container_capacity: int = CONTAINER_CAPACITY, p_lot_capacity: int = LOT_CAPACITY) -> void:
	"""Allocate every column once at the requested capacities.

	Defaults are the specification bounds. A smaller capacity may be requested by a test or a
	bounded harness; a larger one is clamped down, because the memory ledger fixes the maxima.
	"""
	_c_capacity = clampi(p_container_capacity, 1, CONTAINER_CAPACITY)
	_l_capacity = clampi(p_lot_capacity, 1, LOT_CAPACITY)
	_allocate_container_columns()
	_allocate_lot_columns()
	_allocate_shared_columns()
	clear()
```

## godot/scripts/core/stock_age.gd SHA256 339b85a374bdabe1242474f25fbbf4b16ffd42e077c52156d49db1fe5fecd557
```gdscript
func _init(p_inventory: InventoryScript = null,
		p_definitions: ItemDefinitionsScript = null) -> void:
	"""Allocate the declaration columns once and bind the two stores this stage reads."""
	_c_storage_class.resize(CONTAINER_CAPACITY)
	_c_heated_interior.resize(CONTAINER_CAPACITY)
	_c_declared_generation.resize(CONTAINER_CAPACITY)
	_declared_slots.resize(CONTAINER_CAPACITY)
	_inventory = p_inventory
	_definitions = p_definitions
	_assert_shared_contracts()
	clear()
```
```gdscript
func bind_stores(p_inventory: InventoryScript, p_definitions: ItemDefinitionsScript) -> bool:
	"""Bind -- or with nulls, unbind -- the inventory and item catalog this stage reads.

	Refused while an inventory transaction is open, because rebinding mid-transaction would
	leave a half-applied sequence with nobody able to roll it back.

	BINDING A DIFFERENT INVENTORY DROPS EVERY DECLARATION. The declarations are keyed on the
	OLD store's container slots and generations; carried across, slot 4 of a new inventory would
	inherit the storage class of a container it has never held.
	"""
	if p_inventory != null and p_inventory.is_transaction_open():
		return _refuse(REFUSE_TRANSACTION_OPEN)
	if p_inventory != _inventory:
		clear()
	_inventory = p_inventory
	_definitions = p_definitions
	_spoiled_food_id = -1
	_compost_id = -1
	_last_refusal = REFUSE_NONE
	return true


# --- GDD §5.8's two factor tables ---------------------------------------------------------------

static func is_storage_class(storage_class: int) -> bool:
	"""True for one of §5.8's four declared store kinds. STORAGE_UNDECLARED is not one."""
	return storage_class > STORAGE_UNDECLARED and storage_class < STORAGE_CLASS_COUNT


static func store_factor_into(storage_class: int, out: IntMath.IntResult) -> bool:
	"""§5.8's store factor for a declared storage class, into a caller-owned result.

	Refuses an undeclared or unknown class rather than answering 0: a zero factor is a
	perfectly plausible-looking "this never ages", and that is exactly the silent wrong answer
	an undeclared container must not produce.
	"""
	if not is_storage_class(storage_class):
		return out.refuse(String(REFUSE_INVALID_STORAGE_CLASS))
	return out.succeed(STORE_FACTOR[storage_class])


static func temperature_factor_of(season: int, heated_interior: bool) -> int:
	"""§5.8's seasonal temperature factor, with the heated-interior exception applied in winter.

	"Seasonal temperature factor spring 1000/summer 1500/autumn 1000/winter 500; heated
	interiors use 1000 in winter." The exception is winter-only: a heated interior in summer
	still takes the summer factor, because §5.8 grants the substitution for winter alone.
	"""
	if season < 0 or season >= TEMPERATURE_FACTOR.size():
		return 0
	if heated_interior and season == SEASON_WINTER:
		return HEATED_WINTER_TEMPERATURE_FACTOR
	return TEMPERATURE_FACTOR[season]


# --- the storage-class declarations --------------------------------------------------------------
```
```gdscript
func refuses_seed_consumption(lot_ref: Vector2i) -> bool:
	"""STOCK-SEED-R01's seed-consumer eligibility predicate. True means: do NOT use this lot.

	Every seed-consuming path -- new reservation, withdrawal, transfer into production, seed
	selection, the sowing/work commit and any reservation taken before the lot aged out -- must
	reject a seed whose persisted age has reached its catalog shelf threshold. Derived from age
	and the item definition, so it adds no per-lot flag and cannot disagree with a save.

	FAIL-CLOSED: an unbound store, an unloaded catalog or an invalid lot all answer TRUE,
	because a guard that cannot evaluate a lot must never be the reason one is admitted. A valid
	NON-seed lot answers false; this predicate has no opinion about food.

	ENFORCEMENT IS NOT HERE (module header, gap 3): STOCK-SEED-R01 gives quantity admission to
	`inventory.gd`, and nothing calls this yet. Release, cancellation and this stage's own
	transform/sink stay permitted precisely because the guard lives at the consumer.
	"""
	if _inventory == null or _definitions == null or not _definitions.is_loaded():
		return true
	if not _inventory.is_lot_valid(lot_ref):
		return true
	var item_id: int = _inventory.lot_item_id(lot_ref)
	if not _definitions.is_seed(item_id):
		return false
	var threshold: int = _shelf_threshold_milli_hours(item_id)
	if threshold <= 0:
		return false
	return _inventory.lot_age_milli_hours(lot_ref) >= threshold
```

## godot/scripts/ui/ui_focus_order.gd SHA256 fe39cc2a33eb5d1b198344a63121c8999ab86eecf723d78368eed67fd0e801e9
```gdscript
func visible_sequence_into(gates: UiAvailability.Gates, out: PackedInt32Array) -> int:
	"""§8.2's order with every element whose §4 Gate is unsatisfied REMOVED, not merely disabled.

	This is the ordering contract, and it is different from `sequence_into()` above. That one
	writes §8.2's full table, which is the specification. This one writes the stops that exist:
	an element with no Control has no tab stop, so a hidden workspace contributes nothing here
	however many rows §8.2 lists inside it. Unavailable and locked stops DO remain -- they are
	on screen, and §2.2 requires a keyboard user to reach them to hear why they are disabled.
	"""
	var written: int = 0
	for id: int in HUD_ORDER:
		if written >= out.size():
			break
		if not _availability.creates_control(id, gates):
			continue
		out[written] = id
		written += 1
	_last_refusal = REFUSE_NONE
	return written
```
```gdscript
func wire_hud(gates: UiAvailability.Gates) -> int:
	"""Compute the visible HUD order and write it into the real Controls. Returns stops wired.

	`focus_next`, `focus_previous` and the four `focus_neighbor_*` properties are what Godot's
	own Tab and arrow navigation read. Setting them here is the difference between a focus order
	that exists and one a player can feel; an array nothing writes is the defect, not the fix.
	"""
	_order_count = visible_sequence_into(gates, _order)
	_apply_chain(_order, _order_count, false)
	if _focused != NO_ELEMENT and not _is_in(_order, _order_count, _focused):
		_focused = NO_ELEMENT
	_last_refusal = REFUSE_NONE
	return _order_count
```
```gdscript
func open_surface(page_id: int, members: PackedInt32Array, count: int, opener_id: int) -> bool:
	"""Open one workspace or modal page, replacing any open one, and take its opening focus.

	§3 allows "Only one primary management workspace open", so opening a second REPLACES the
	first: its members move to `outgoing_into()` for the caller to remove from the tree, and any
	focus still standing on one of them is dropped rather than left pointing at a dead surface.
	"""
	if count < 0 or count > SURFACE_CAPACITY:
		return _refuse(REFUSE_SURFACE_FULL)
	_restore_background()
	_retire_members()
	_member_count = count
	for index: int in count:
		_members[index] = members[index]
	_surface_page = page_id
	_surface_opener = opener_id
	_surface_modal = _registry.profile_of(page_id).value == UiRegistry.PROFILE_MODAL
	_apply_chain(_members, _member_count, true)
	if _surface_modal:
		_suppress_background()
	_last_refusal = REFUSE_NONE
	return _focus_opening_stop()
```
```gdscript
func close_surface(gates: UiAvailability.Gates) -> bool:
	"""Close the open surface and return focus where §2.2 says it goes.

	§2.2: "On close, focus returns to the opening control if still present, otherwise the zone's
	first control." Both branches are taken here; neither leaves focus on a control that has
	just been removed from the tree.
	"""
	if _surface_page == NO_ELEMENT:
		return _refuse(REFUSE_NO_SURFACE)
	_restore_background()
	_retire_members()
	var opener: int = _surface_opener
	_surface_page = NO_ELEMENT
	_surface_opener = NO_ELEMENT
	_surface_modal = false
	wire_hud(gates)
	if opener != NO_ELEMENT and _is_in(_order, _order_count, opener):
		return focus_element(opener)
	return _focus_zone_first(opener)
```
```gdscript
func _retire_members() -> void:
	"""Move the open surface's members to the outgoing list and drop focus standing on one."""
	_outgoing_count = _member_count
	for index: int in _member_count:
		_outgoing[index] = _members[index]
		_unwire(_members[index])
	if _focused != NO_ELEMENT and _is_in(_outgoing, _outgoing_count, _focused):
		_focused = NO_ELEMENT
	_member_count = 0
```

## Complete current tracked diff
```diff
diff --git a/docs/STATUS.md b/docs/STATUS.md
index ff8bd68..ba6329a 100644
--- a/docs/STATUS.md
+++ b/docs/STATUS.md
@@ -1,5 +1,7 @@
 # Status — the programme, task 03, and the READY_06 answers
 
+**2026-09-19 resumption:** [current verified baseline, Cycle 4 rulings and starter-settlement work](planning/resumption_2026_09_19/README.md). Baseline `47a4da2`: 4551 tests / 158103 assertions / zero failures, with shutdown leak warnings. Actual startup still has two inventory authorities and zero buildings/rooms/furniture. Older status below is historical.
+
 **Cycle3, 2026-09-14:** [current rulings and executor handoff](planning/astra_cycles/cycle_03.md). Integrated base2021444 includes five merges sinceCycle2. Four advisory questions answered; movement policy advanced but production gates remain open. Registry/source validation now passes on merged master.37-task queue; PR122/123 retain review ownership. Older status below is historical.
 
 **Cycle 2, 2026-09-14:** [current decisions and executor handoff](planning/astra_cycles/cycle_02.md). Baseline PR116 is merged; two inventory/goods questions answered, movement partly answered and still gated. PR117/118 remain in review in this cycle’s snapshot. The older local checkout is not the reconciled master baseline.
diff --git a/docs/planning/README.md b/docs/planning/README.md
index 9842682..9fc9a8f 100644
--- a/docs/planning/README.md
+++ b/docs/planning/README.md
@@ -1,5 +1,7 @@
 # Next settlement planning package
 
+**2026-09-19 resumption:** [current verified baseline, Cycle 4 rulings and starter-settlement work](resumption_2026_09_19/README.md). Baseline `47a4da2`: 4551 tests / 158103 assertions / zero failures, with shutdown leak warnings. Actual startup still has two inventory authorities and zero buildings/rooms/furniture. Older status below is historical.
+
 **Cycle 2, 2026-09-14:** [current decisions and executor handoff](astra_cycles/cycle_02.md). Baseline PR116 is merged; two inventory/goods questions answered, movement partly answered and still gated. PR117/118 remain in review in this cycle’s snapshot. The older local checkout is not the reconciled master baseline.
 
 
diff --git a/docs/planning/registry_capacity_audit.json b/docs/planning/registry_capacity_audit.json
index 9f23cca..4146fb4 100644
--- a/docs/planning/registry_capacity_audit.json
+++ b/docs/planning/registry_capacity_audit.json
@@ -1,10 +1,10 @@
 {
   "adopted": false,
   "audit_id": "RWL-REGISTRY-CAPACITY-AUDIT-2026-09-14-1",
-  "audit_schema_version": 1,
+  "audit_schema_version": 2,
   "audited_registry": {
     "path": "docs/planning/canonical_state_registry.json",
-    "registry_file_sha256": "bf8adf7b16f6d68624d5b725d45fc88fa8da2449faf9a3f46610bfd0aad6eb37",
+    "registry_canonical_json_sha256": "bf8adf7b16f6d68624d5b725d45fc88fa8da2449faf9a3f46610bfd0aad6eb37",
     "registry_id": "RWL-CANONICAL-REGISTRY-2026-09-15-3",
     "registry_version": 3
   },
@@ -78,7 +78,7 @@
       "upper_bound": 46
     }
   },
-  "contract": "REG-C3-R01 (docs/rulings/2026-09-14_cycle03_save_counts_and_capacities.md)",
+  "contract": "REG-C3-R01 (docs/rulings/2026-09-14_cycle03_save_counts_and_capacities.md); REG-C4-R01 (docs/rulings/2026-09-19_cycle04_resumption.md)",
   "kind": "read_only_sidecar",
   "non_capacity_canonical_records": [
     {
@@ -889,7 +889,8 @@
     "No prose capacity is converted into the registry here; a later ruling decides adoption.",
     "Every proof is GDScript source. Agreement with another document is never accepted as proof.",
     "Equality and upper bound are preserved as distinct claims and are never flattened.",
-    "source_registry_sha256 in the registry is NOT re-asserted by this audit; only the file digest below is this audit's own observation."
+    "REG-C4-R01 extends the proof grammar to bounded, left-associative sums of the existing allowlisted products; no store, capacity or save schema changed as a result.",
+    "source_registry_sha256 in the registry is NOT re-asserted by this audit; only the canonical JSON digest below is this audit's own observation."
   ],
   "rows": [
     {
@@ -9292,9 +9293,18 @@
       "ordinal": 0,
       "owner_key": "orchard_hive",
       "parsed_expression": "LINK_CAPACITY",
+      "proof_chain": [
+        "Farming.FARM_PLOT_CAPACITY -> godot/scripts/core/farming.gd:238 `const FARM_PLOT_CAPACITY = 4096` = 4096",
+        "FARM_RECIPIENT_CAPACITY -> godot/scripts/core/orchard_hive.gd:313 `const FARM_RECIPIENT_CAPACITY = Farming.FARM_PLOT_CAPACITY` = 4096",
+        "ORCHARD_CAPACITY -> godot/scripts/core/orchard_hive.gd:211 `const ORCHARD_CAPACITY = 1024` = 1024",
+        "RECIPIENT_CAPACITY -> godot/scripts/core/orchard_hive.gd:316 `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY` = 5120",
+        "LINKS_PER_RECIPIENT -> godot/scripts/core/orchard_hive.gd:318 `const LINKS_PER_RECIPIENT = 6` = 6",
+        "LINK_CAPACITY -> godot/scripts/core/orchard_hive.gd:319 `const LINK_CAPACITY = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT` = 30720"
+      ],
+      "proof_kind": "compiled_constant",
       "prose_relation": "eq",
       "prose_value": 30720,
-      "quarantine_reason": "LINK_CAPACITY halted at godot/scripts/core/orchard_hive.gd:319 `const LINK_CAPACITY = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT`: RECIPIENT_CAPACITY halted at godot/scripts/core/orchard_hive.gd:316 `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`: 'FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY' uses +; REG-C3-R01 allowlists products and qualified constants only",
+      "quarantine_reason": "",
       "section_id": 5,
       "source_file": "godot/scripts/core/orchard_hive.gd",
       "source_member": "_link_hive_slot",
@@ -9302,7 +9312,8 @@
       "source_relation": "eq",
       "source_resize_expression": "LINK_CAPACITY",
       "source_resize_line": 674,
-      "status": "unproved_non_allowlisted_operator"
+      "source_value": 30720,
+      "status": "proved_equality"
     },
     {
       "declared_capacity_prose": "`LINK_CAPACITY` = 30720",
@@ -9310,9 +9321,18 @@
       "ordinal": 1,
       "owner_key": "orchard_hive",
       "parsed_expression": "LINK_CAPACITY",
+      "proof_chain": [
+        "Farming.FARM_PLOT_CAPACITY -> godot/scripts/core/farming.gd:238 `const FARM_PLOT_CAPACITY = 4096` = 4096",
+        "FARM_RECIPIENT_CAPACITY -> godot/scripts/core/orchard_hive.gd:313 `const FARM_RECIPIENT_CAPACITY = Farming.FARM_PLOT_CAPACITY` = 4096",
+        "ORCHARD_CAPACITY -> godot/scripts/core/orchard_hive.gd:211 `const ORCHARD_CAPACITY = 1024` = 1024",
+        "RECIPIENT_CAPACITY -> godot/scripts/core/orchard_hive.gd:316 `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY` = 5120",
+        "LINKS_PER_RECIPIENT -> godot/scripts/core/orchard_hive.gd:318 `const LINKS_PER_RECIPIENT = 6` = 6",
+        "LINK_CAPACITY -> godot/scripts/core/orchard_hive.gd:319 `const LINK_CAPACITY = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT` = 30720"
+      ],
+      "proof_kind": "compiled_constant",
       "prose_relation": "eq",
       "prose_value": 30720,
-      "quarantine_reason": "LINK_CAPACITY halted at godot/scripts/core/orchard_hive.gd:319 `const LINK_CAPACITY = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT`: RECIPIENT_CAPACITY halted at godot/scripts/core/orchard_hive.gd:316 `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`: 'FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY' uses +; REG-C3-R01 allowlists products and qualified constants only",
+      "quarantine_reason": "",
       "section_id": 5,
       "source_file": "godot/scripts/core/orchard_hive.gd",
       "source_member": "_link_hive_generation",
@@ -9320,7 +9340,8 @@
       "source_relation": "eq",
       "source_resize_expression": "LINK_CAPACITY",
       "source_resize_line": 675,
-      "status": "unproved_non_allowlisted_operator"
+      "source_value": 30720,
+      "status": "proved_equality"
     },
     {
       "declared_capacity_prose": "`INTENT_CAPACITY` = 128",
@@ -13004,26 +13025,8 @@
     }
   ],
   "status_counts": {
-    "proved_equality": 468,
-    "proved_upper_bound": 46,
-    "unproved_non_allowlisted_operator": 2
+    "proved_equality": 470,
+    "proved_upper_bound": 46
   },
-  "unproved_or_contradicted": [
-    {
-      "field_key": "_link_hive_slot",
-      "ordinal": 0,
-      "owner_key": "orchard_hive",
-      "quarantine_reason": "LINK_CAPACITY halted at godot/scripts/core/orchard_hive.gd:319 `const LINK_CAPACITY = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT`: RECIPIENT_CAPACITY halted at godot/scripts/core/orchard_hive.gd:316 `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`: 'FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY' uses +; REG-C3-R01 allowlists products and qualified constants only",
-      "section_id": 5,
-      "status": "unproved_non_allowlisted_operator"
-    },
-    {
-      "field_key": "_link_hive_generation",
-      "ordinal": 1,
-      "owner_key": "orchard_hive",
-      "quarantine_reason": "LINK_CAPACITY halted at godot/scripts/core/orchard_hive.gd:319 `const LINK_CAPACITY = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT`: RECIPIENT_CAPACITY halted at godot/scripts/core/orchard_hive.gd:316 `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`: 'FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY' uses +; REG-C3-R01 allowlists products and qualified constants only",
-      "section_id": 5,
-      "status": "unproved_non_allowlisted_operator"
-    }
-  ]
+  "unproved_or_contradicted": []
 }
diff --git a/docs/planning/work_queue.json b/docs/planning/work_queue.json
index 1818dd0..e7a5238 100644
--- a/docs/planning/work_queue.json
+++ b/docs/planning/work_queue.json
@@ -1,6 +1,6 @@
 {
   "schema": 1,
-  "updated": "2026-09-14",
+  "updated": "2026-09-19",
   "note": "The dispatchable graph. tools/dispatch_plan.py reads this and emits the largest conflict-free set of ready tasks. Status values: blocked, ready, in_flight, review, done. A task is dispatchable only when every dependency is done, its gate is cleared, and no file it owns is owned by a task already in flight.",
   "gates": {
     "none": "No human decision required. Fully automatic.",
@@ -236,7 +236,7 @@
     {
       "id": "DIGEST-DETERMINISM",
       "title": "Implement the shared canonical inventory projection and strict schema3 codec",
-      "status": "ready",
+      "status": "done",
       "depends_on": [
         "BASELINE-INTEGRATION",
         "SAVE-REGISTRY-RECONCILE",
@@ -261,7 +261,11 @@
       "astra_request": "docs/rulings/requests/OPEN.md#retired-row-blanking",
       "note": "INV-CANON-R01 answers the question. Source masking only at quiescence; strict loader canonical form; no hot retirement clear, row omission or free-stack sort. Atomic schema3 activation; full continuation tests remain required.",
       "astra_answered": true,
-      "astra_ruling": "docs/rulings/2026-09-14_cycle02_inventory_canonicalization.md"
+      "astra_ruling": "docs/rulings/2026-09-14_cycle02_inventory_canonicalization.md",
+      "pr": 137,
+      "merge_commit": "92caa18de73a0c15f9e7edab3310c0b31d59504e",
+      "merged_at": "2026-09-18T11:41:19Z",
+      "completion_scope": "Merged bounded lane verified against GitHub on 2026-09-19; not full owning-system acceptance."
     },
     {
       "id": "MOVE-ENVELOPES",
@@ -459,7 +463,7 @@
     {
       "id": "PLAN-SAVE-COVERAGE",
       "title": "Materialize every remaining save prerequisite before whole-world capture",
-      "status": "review",
+      "status": "done",
       "depends_on": [
         "BASELINE-INTEGRATION"
       ],
@@ -470,12 +474,16 @@
       ],
       "agent": "self",
       "gate": "none",
-      "acceptance": "Inventory all 15 bodies, each owner capture/restore/hash adapter, header producers, cross-section validators and load orchestration. Include section12 arena-base restore and missing orchard inverse producer. Insert bounded owned tasks and add every implementation prerequisite to SAVE-CAPTURE before marking this planning task done. Publish a validation check that refuses a missing matrix task/dependency; expand ownership for that checker through the integration lead before implementing it. Use merged real paths save_section_inventories.gd and save_section_pending_commands.gd; include INV-CANON-R01 target and present source-state gaps. Include SAVE-C3-R01 and stock-integrity fault/retry/hold continuation. Before SAVE-CAPTURE dispatch, materialize all discovered runtime prerequisites; completed planning tasks alone cannot release it."
+      "acceptance": "Inventory all 15 bodies, each owner capture/restore/hash adapter, header producers, cross-section validators and load orchestration. Include section12 arena-base restore and missing orchard inverse producer. Insert bounded owned tasks and add every implementation prerequisite to SAVE-CAPTURE before marking this planning task done. Publish a validation check that refuses a missing matrix task/dependency; expand ownership for that checker through the integration lead before implementing it. Use merged real paths save_section_inventories.gd and save_section_pending_commands.gd; include INV-CANON-R01 target and present source-state gaps. Include SAVE-C3-R01 and stock-integrity fault/retry/hold continuation. Before SAVE-CAPTURE dispatch, materialize all discovered runtime prerequisites; completed planning tasks alone cannot release it.",
+      "pr": 136,
+      "merge_commit": "cf8e2bfe1eb316d54674b286246b59f29ae2c9d7",
+      "merged_at": "2026-09-18T11:40:45Z",
+      "completion_scope": "Merged bounded lane verified against GitHub on 2026-09-19; not full owning-system acceptance."
     },
     {
       "id": "PLAN-RELEASE-COVERAGE",
       "title": "Restore omitted release work to the dispatch graph from tasks 04 through 10",
-      "status": "ready",
+      "status": "in_flight",
       "depends_on": [
         "BASELINE-INTEGRATION",
         "PLAN-SAVE-COVERAGE"
@@ -486,7 +494,7 @@
       ],
       "agent": "self",
       "gate": "none",
-      "acceptance": "Create owned task entries for initial buildings/furniture/stocks, construction commands/jobs/hauling, event domains/producers/consumers, species rendering and UI corrections, shutdown leak investigation and qualification. Preserve all confirmed settlement scope and unresolved gates; no task completion from document existence alone. Explicitly cover one active inventory/economy authority, initial hall/beds/furniture/stocks and12equipped+12storedtools under REQ-SET-009. Preserve ARRIVAL and RELIEF follow-up tasks; do not claim completion from cohort/terrain assertions."
+      "acceptance": "Create owned task entries for initial buildings/furniture/stocks, construction commands/jobs/hauling, event domains/producers/consumers, species rendering and UI corrections, shutdown leak investigation and qualification. Preserve all confirmed settlement scope and unresolved gates; no task completion from document existence alone. Explicitly cover one active inventory/economy authority, initial hall/beds/furniture/stocks and12equipped+12storedtools under REQ-SET-009. Preserve ARRIVAL and RELIEF follow-up tasks; do not claim completion from cohort/terrain assertions. Matrix and 16 owned downstream task entries added on2026-09-19; implementation packets remain explicitly gated pending detailed contracts."
     },
     {
       "id": "PACKET-EVIDENCE",
@@ -651,7 +659,7 @@
     {
       "id": "UI-C3-EVIDENCE",
       "title": "Capture corrected responsive shell and input evidence",
-      "status": "review",
+      "status": "done",
       "depends_on": [
         "UI-RESPONSIVE-C3"
       ],
@@ -662,7 +670,11 @@
       ],
       "agent": "user-qa",
       "gate": "none",
-      "acceptance": "All UI-C3-R01 profiles/scales, boundary widths, actual font and physical rounding; paired alert pixels with workspace open; keyboard/focus/world-click isolation and value disclosure. Keep synthetic specimens separate; retain harnesses. Human art verdict remains separate."
+      "acceptance": "All UI-C3-R01 profiles/scales, boundary widths, actual font and physical rounding; paired alert pixels with workspace open; keyboard/focus/world-click isolation and value disclosure. Keep synthetic specimens separate; retain harnesses. Human art verdict remains separate.",
+      "pr": 138,
+      "merge_commit": "47a4da2642912afee4d5249424d31ab6c92f014a",
+      "merged_at": "2026-09-18T11:41:33Z",
+      "completion_scope": "Merged bounded lane verified against GitHub on 2026-09-19; not full owning-system acceptance."
     },
     {
       "id": "SAVE-S8-COUNT",
@@ -703,7 +715,7 @@
     {
       "id": "MOVE-POLICY-REGISTER",
       "title": "Apply adopted Cycle3 policy decisions to the Q2 register",
-      "status": "ready",
+      "status": "done",
       "depends_on": [
         "MOVE-PROFILE-AUTHORING"
       ],
@@ -715,7 +727,11 @@
       ],
       "agent": "self",
       "gate": "none",
-      "acceptance": "MOVE-C3-R01: separate adopted policy from measured/profile readiness. Bind ford, child voluntaryhazard versus recovery, elder/access and existingHAZ rules with citations. Correct needs/health units and stale claims. Recompute288 leaves; preserve conditional childCLIMB, no production qualified rows without real evidence. No all-null invariant after rulings; no invented dimensions/costs."
+      "acceptance": "MOVE-C3-R01: separate adopted policy from measured/profile readiness. Bind ford, child voluntaryhazard versus recovery, elder/access and existingHAZ rules with citations. Correct needs/health units and stale claims. Recompute288 leaves; preserve conditional childCLIMB, no production qualified rows without real evidence. No all-null invariant after rulings; no invented dimensions/costs.",
+      "pr": 134,
+      "merge_commit": "bc782968c5825ca417f4eb56a25f2b9f68cccf4c",
+      "merged_at": "2026-09-17T12:05:23Z",
+      "completion_scope": "Merged bounded lane verified against GitHub on 2026-09-19; not full owning-system acceptance."
     },
     {
       "id": "MOVE-ENVELOPE-ERROR",
@@ -1007,7 +1023,7 @@
     {
       "id": "UI-DRAWN-WITHOUT-INPUT",
       "title": "Five drawn opaque elements have no input rectangle, so clicks fall through to the world",
-      "status": "ready",
+      "status": "in_flight",
       "depends_on": [
         "UI-C3-EVIDENCE"
       ],
@@ -1018,9 +1034,283 @@
         "godot/test/test_ui_hit_test.gd"
       ],
       "agent": "game-coder",
+      "gate": "astra_ruling",
+      "note": "Found by UI-C3-EVIDENCE's rendered overlays, not by any test. add_visible_region() refuses a region when the \u00a74 Gate is unsatisfied, justified by 'an element whose gate is unsatisfied has no Control at all'. That premise is FALSE for 051 WORKSPACE, 092 BACK, 036 DETAIL, 038 DETAIL_TABS and 098 PIN: the shell draws them anyway, so they are visible, opaque and unclickable. Measured: the centre of the open roster workspace (752,356) and of the open detail panel (1096,416) both resolve to WORLD. The hit table reports WORLD at a visible panel. Actual engine command leakage is not established by that table alone; UI-C4-R01 requires real event routing evidence. Either the gate must also suppress drawing, or a drawn control must claim its rectangle; the current pair is self-contradictory. test_the_gate_decides_before_the_availability_claim_does pins the ordering as correct, and it IS correct given the premise -- which is why no test caught this.",
+      "astra_answered": true,
+      "astra_ruling": "docs/rulings/2026-09-19_cycle04_resumption.md",
+      "acceptance": "UI-C4-R01: synchronize contextual visibility, gates, focus and real consuming rectangles; test workspace/detail open-close and supported scales, plus engine input. No visual approval or full world-input implementation inferred."
+    },
+    {
+      "id": "REG-C4-ADDITION",
+      "title": "Prove nested capacity sums with a closed int64 grammar",
+      "status": "in_flight",
+      "depends_on": [
+        "REGISTRY-CAPACITY-AUDIT"
+      ],
+      "owns": [
+        "tools/audit_registry_capacities.py",
+        "tools/test_registry_capacity_audit.py",
+        "docs/planning/registry_capacity_audit.json"
+      ],
+      "agent": "game-coder",
+      "gate": "astra_ruling",
+      "astra_answered": true,
+      "astra_ruling": "docs/rulings/2026-09-19_cycle04_resumption.md",
+      "acceptance": "REG-C4-R01 addition grammar; reviewed author bundle recovered through strict parser after split output.158checks passed before independent F01/F02 repair; bounded cap-sound-a1 in progress. Do not mark done before integration and final review."
+    },
+    {
+      "id": "INIT-A",
+      "title": "Map starter APIs and physical owners",
+      "status": "review",
+      "depends_on": [],
+      "owns": [
+        "docs/planning/resumption_2026_09_19/starter_binding_manifest.json"
+      ],
+      "agent": "self",
       "gate": "none",
-      "note": "Found by UI-C3-EVIDENCE's rendered overlays, not by any test. add_visible_region() refuses a region when the \u00a74 Gate is unsatisfied, justified by 'an element whose gate is unsatisfied has no Control at all'. That premise is FALSE for 051 WORKSPACE, 092 BACK, 036 DETAIL, 038 DETAIL_TABS and 098 PIN: the shell draws them anyway, so they are visible, opaque and unclickable. Measured: the centre of the open roster workspace (752,356) and of the open detail panel (1096,416) both resolve to WORLD. A click in the middle of a visible panel issues a world command -- UX-T04's own failure criterion. Either the gate must also suppress drawing, or a drawn control must claim its rectangle; the current pair is self-contradictory. test_the_gate_decides_before_the_availability_claim_does pins the ordering as correct, and it IS correct given the premise -- which is why no test caught this."
+      "acceptance": "API names verified from source; owners, existing canonical APIs, duplicate stock, missing bindings, storage-class and transaction limitations explicitly recorded. Runtime activation is not granted by this map."
+    },
+    {
+      "id": "INIT-0",
+      "title": "Compose one inventory authority at boot and new-world creation",
+      "status": "blocked",
+      "depends_on": [
+        "INIT-A"
+      ],
+      "owns": [
+        "godot/scripts/systems/economy_system.gd",
+        "godot/scripts/systems/settlement_system.gd",
+        "godot/scripts/main.gd",
+        "godot/scripts/systems/ui_manager.gd",
+        "godot/scripts/ui/ui_world_session.gd",
+        "godot/test/test_starter_inventory_integration.gd"
+      ],
+      "agent": "game-coder",
+      "gate": "astra_ruling",
+      "acceptance": "Author exact borrow/reset/reseed/refusal contract first. Same inventory instance across UI, aging, construction and gear; no erased seeds, stale refs, double production allocations or equipment duplication. Physical containers require INIT-C/D contract agreement before activation.",
+      "astra_answered": false,
+      "astra_request": "docs/planning/resumption_2026_09_19/starter_settlement.md; bounded implementation contract and physical dependencies must close before dispatch"
+    },
+    {
+      "id": "INIT-B",
+      "title": "Seed the twelve residents' initial relationships",
+      "status": "blocked",
+      "depends_on": [
+        "INIT-A"
+      ],
+      "owns": [
+        "godot/scripts/core/starter_relationships.gd",
+        "godot/test/test_starter_relationships.gd"
+      ],
+      "agent": "game-coder",
+      "gate": "astra_ruling",
+      "acceptance": "Bind GDD six reciprocal Friend pairs through one relationship owner. Refuse capacity or invalid identity before reset; persistent ids1-12 unchanged; no invented bond/family coefficients.",
+      "astra_answered": false,
+      "astra_request": "docs/planning/resumption_2026_09_19/starter_settlement.md; bounded implementation contract and physical dependencies must close before dispatch"
+    },
+    {
+      "id": "INIT-C",
+      "title": "Build the seven starter buildings and hall interior",
+      "status": "blocked",
+      "depends_on": [
+        "INIT-A"
+      ],
+      "owns": [
+        "godot/scripts/core/starter_structures.gd",
+        "godot/test/test_starter_structures.gd"
+      ],
+      "agent": "game-coder",
+      "gate": "astra_ruling",
+      "acceptance": "Exact locations/rooms/furniture per starter_settlement.md; actual topology/doors/contact reachability; no blueprint-only completion, null physical owners or fabricated access.",
+      "astra_answered": false,
+      "astra_request": "docs/planning/resumption_2026_09_19/starter_settlement.md; bounded implementation contract and physical dependencies must close before dispatch"
+    },
+    {
+      "id": "INIT-D",
+      "title": "Place starter goods and equip the cohort",
+      "status": "blocked",
+      "depends_on": [
+        "INIT-C"
+      ],
+      "owns": [
+        "godot/scripts/core/starter_goods.gd",
+        "godot/test/test_starter_goods.gd"
+      ],
+      "agent": "game-coder",
+      "gate": "astra_ruling",
+      "acceptance": "Exact20item quantities, food-first/item-ID placement, real room/furniture/stockpile owners, per-lot ceil mass, 12 equipped +12 stored tools1000durability; capacity/refusal no duplication; class every aging container.",
+      "astra_answered": false,
+      "astra_request": "docs/planning/resumption_2026_09_19/starter_settlement.md; bounded implementation contract and physical dependencies must close before dispatch"
+    },
+    {
+      "id": "INIT-E",
+      "title": "Publish one transactional starter world on both entry paths",
+      "status": "blocked",
+      "depends_on": [
+        "INIT-0",
+        "INIT-B",
+        "INIT-C",
+        "INIT-D"
+      ],
+      "owns": [
+        "godot/scripts/systems/settlement_system.gd",
+        "godot/scripts/systems/ui_manager.gd",
+        "godot/scripts/ui/ui_world_session.gd",
+        "godot/scripts/main.gd",
+        "godot/test/test_starter_publication.gd"
+      ],
+      "agent": "game-coder",
+      "gate": "astra_ruling",
+      "acceptance": "One preflight/reset/seed/cohort/physical-world publication; same seed equality; prior valid world/save unchanged on any refusal; exact clocks/RNG/poses/map report bindings; no second full world allocation.",
+      "astra_answered": false,
+      "astra_request": "docs/planning/resumption_2026_09_19/starter_settlement.md; bounded implementation contract and physical dependencies must close before dispatch"
+    },
+    {
+      "id": "INIT-F",
+      "title": "Expose actual starter services and first interaction",
+      "status": "blocked",
+      "depends_on": [
+        "INIT-E",
+        "UI-DRAWN-WITHOUT-INPUT"
+      ],
+      "owns": [
+        "godot/scripts/systems/ui_manager.gd",
+        "godot/scripts/ui/ui_shell.gd",
+        "godot/test/test_starter_inspection.gd"
+      ],
+      "agent": "game-coder",
+      "gate": "astra_ruling",
+      "acceptance": "Real bed/room/stock inspection and capacity, no fictional completed gameplay; collect actual engine input evidence; art acceptance separate.",
+      "astra_answered": false,
+      "astra_request": "docs/planning/resumption_2026_09_19/starter_settlement.md; bounded implementation contract and physical dependencies must close before dispatch"
+    },
+    {
+      "id": "PLAN-PC03-SCENARIOS",
+      "title": "Author the complete finite scenario package",
+      "status": "ready",
+      "depends_on": [],
+      "owns": [
+        "docs/planning/scenario_execution_package.md"
+      ],
+      "agent": "self",
+      "gate": "none",
+      "acceptance": "PC-03/task08.1: finite named roster across original/Abbey/novel-era and founding/restoration/established premises; source-qualified casts; exact maps/stocks/population/objectives/admission/identity/save contracts. Preserve source gaps; explicit authored assumptions; no copied novel text."
+    },
+    {
+      "id": "PLAN-PC04-FAMILIES",
+      "title": "Author fixed life stages, dependents and care",
+      "status": "ready",
+      "depends_on": [],
+      "owns": [
+        "docs/planning/family_execution_package.md"
+      ],
+      "agent": "self",
+      "gate": "none",
+      "acceptance": "PC-04/task08.2: household/caregiver schema, age-stage species coefficients, schedules, services, safety/interruption/warnings/rescue/consequences. No births/aging, child productive/hazardous work or adults-only fallback; exact integer coefficients and save/replay contracts."
+    },
+    {
+      "id": "PLAN-PC06-PROGRESSION",
+      "title": "Resolve the continuous winter progression contract",
+      "status": "ready",
+      "depends_on": [],
+      "owns": [
+        "docs/planning/progression_execution_package.md"
+      ],
+      "agent": "self",
+      "gate": "none",
+      "acceptance": "PC-06/task08.6 and ARCH-CONFLICT-004: continuous winter interval, counters/reset conditions, cap/victory/continuation/collapse-save protection and exact tests; no milestone activation without approved finite rules."
+    },
+    {
+      "id": "PLAN-LIVE-CONSTRUCTION",
+      "title": "Specify command, material delivery and service integration",
+      "status": "ready",
+      "depends_on": [],
+      "owns": [
+        "docs/planning/construction_execution_package.md"
+      ],
+      "agent": "self",
+      "gate": "none",
+      "acceptance": "Task06.1-4: existing stores to18remaining commands; job admission/source/destination reservations/hauling/arrival/WU/upgrade/cancel/demolition/occupants/only exit; BUILD-C4-R01 paid package ledger and atomic outputs. Materialize bounded owned implementations after API review."
+    },
+    {
+      "id": "PLAN-LIVE-FOOD",
+      "title": "Specify full seasonal production and need services",
+      "status": "ready",
+      "depends_on": [],
+      "owns": [
+        "docs/planning/food_execution_package.md"
+      ],
+      "agent": "self",
+      "gate": "none",
+      "acceptance": "Task07: active recipe data, WIP/manual/passive batches, meal/water/rest/heat service contact, conservation, equipment, renewable food loops/forecasts/relief, exact integer needs interruption and save continuation. Source candidate is not active balanced data."
+    },
+    {
+      "id": "PLAN-COMMUNITY-EVENTS",
+      "title": "Specify event production and community consumers",
+      "status": "ready",
+      "depends_on": [
+        "PLAN-PC03-SCENARIOS",
+        "PLAN-PC04-FAMILIES",
+        "PLAN-PC06-PROGRESSION"
+      ],
+      "owns": [
+        "docs/planning/community_execution_package.md"
+      ],
+      "agent": "self",
+      "gate": "none",
+      "acceptance": "Task08: finite event domain/payload/capacity/producer/consumer/repeat/save; relationship/memory/grief/care/illness/lifecycle/admission/feasts/chronicle; preserve separate ARRIVAL/RELIEF plans and care-before-progression stage order."
+    },
+    {
+      "id": "PLAN-PRESENTATION-RELEASE",
+      "title": "Specify remaining UI, species, audio and packaging",
+      "status": "ready",
+      "depends_on": [],
+      "owns": [
+        "docs/planning/presentation_release_package.md"
+      ],
+      "agent": "self",
+      "gate": "none",
+      "acceptance": "Task10: all103UIelements/settings/camera/accessibility; approved art refs and height anchors; species/gear/pose/LOD/animation/contact maps; assets/audio provenance; reproducible localMac package. Human art and spend gates remain external, no unauthorized external store publication."
+    },
+    {
+      "id": "QA-SHUTDOWN-LEAKS",
+      "title": "Identify and repair shutdown ownership leaks",
+      "status": "ready",
+      "depends_on": [],
+      "owns": [
+        "docs/validation/evidence/shutdown-ownership/"
+      ],
+      "agent": "game-coder",
+      "gate": "none",
+      "acceptance": "Reproduce4551suite andboot leaks; attribute actual retained object/resource owners with bounded diagnostics; publish exact repair paths before edits. Do not suppress warnings or claim all leaks from count only. One heavy job."
+    },
+    {
+      "id": "PLAN-INTEGRATED-QUALIFICATION",
+      "title": "Define complete release candidate qualification",
+      "status": "ready",
+      "depends_on": [],
+      "owns": [
+        "docs/planning/integrated_qualification_package.md"
+      ],
+      "agent": "self",
+      "gate": "none",
+      "acceptance": "Task10.4-5: fullscenario3yearsurvival, allmovementdomains/construction/needs/savecorruption/replay; nativevisual/keyboard/trackpad/accessibility; perfandmemory actual exportedcandidate onnamedhardware; deferredWindows separatelyreported. Independent reviewer and requirementcoverage per candidate."
+    },
+    {
+      "id": "STOCK-AUTHORITY-LIFETIME",
+      "title": "Remove the verified Inventory/StockAge ownership cycle",
+      "status": "in_flight",
+      "depends_on": [],
+      "owns": [
+        "godot/scripts/core/inventory.gd",
+        "godot/test/test_stock_authority_lifetime.gd"
+      ],
+      "agent": "game-coder",
+      "gate": "astra_ruling",
+      "astra_answered": true,
+      "astra_request": "docs/rulings/2026-09-19_stock_authority_lifetime.md",
+      "acceptance": "STOCK-C4-LIFETIME-R01: borrowed live predicate, orphan fails closed, no canonical state changes; exact lifetime probe and full regression; remaining leak causes distinct."
     }
   ],
   "cycle_report": "docs/planning/astra_cycles/cycle_03.md"
-}
\ No newline at end of file
+}
diff --git a/docs/rulings/requests/OPEN.md b/docs/rulings/requests/OPEN.md
index 1102ad4..58dffdc 100644
--- a/docs/rulings/requests/OPEN.md
+++ b/docs/rulings/requests/OPEN.md
@@ -14,14 +14,11 @@ blocking in `docs/planning/work_queue.json`, which is what releases them to the
 dispatcher.
 
 
-**1 blocking, 3 advisory.** Oldest asked 2026-09-12.
+**1 blocking, 0 advisory.** Oldest asked 2026-09-12.
 
 | Question | Asked | Holding up |
 |---|---|---|
 | [MOVE-G01 Q1 and Q2: clearance classes and per-species modes](#move-g01-clearance-and-modes) | 2026-09-12 | `MOVE-ENVELOPES` |
-| [A tier-2 building's demolition basis is unresolved](#tier-two-demolition-basis) | 2026-09-13 | nothing yet |
-| [ECON-003's excavation phases need compiled ids and a site-phase column](#econ-003-excavation-phase-domain) | 2026-09-13 | nothing yet |
-| [May the capacity resolver allowlist `+` for nested constant definitions?](#capacity-resolver-addition-allowlist) | 2026-09-14 | nothing yet |
 
 <a id="move-g01-clearance-and-modes"></a>
 ## MOVE-G01 Q1 and Q2: clearance classes and per-species modes
@@ -36,39 +33,6 @@ dispatcher.
 
 - Blocks `MOVE-ENVELOPES` — Measured movement envelopes, MOVE-G01 Q1/Q2
 
-<a id="tier-two-demolition-basis"></a>
-## A tier-2 building's demolition basis is unresolved
-
-*Asked 2026-09-13.*
-
-**Question.** REQ-SET-127 prices demolition at 'declared construction WU x 0.25' returning '50% original material costs'. §4.2's upgrade table declares no demolition consequence, so for an upgraded building 'original' is ambiguous: the base §4.1 row, the sum of base plus upgrades, or the current tier's declared cost?
-
-**Why the executor cannot decide it.** Summing the upgrade chain is a rule, not an inference, and inventing it would set refund economics the balance tables never authored.
-
-**Impact.** The store uses the base §4.1 row at every tier and says so in its own header. Whichever way this is ruled, only a constant changes.
-
-<a id="econ-003-excavation-phase-domain"></a>
-## ECON-003's excavation phases need compiled ids and a site-phase column
-
-*Asked 2026-09-13.*
-
-**Question.** ECON-003 names nine excavation phases. They are SITE states and map onto the construction store's five project phases not at all one-for-one: each ECON-003 transition is one project run through the whole lifecycle, with 'consume inputs once at WORK start' = `begin_work()` and 'retain earned work, publish nothing' = PHASE_WORK_DONE. This needs compiled ASCII ids in `catalog.gd` and a site-phase column from the excavation owner. Who owns that column, and are the nine ids a protected or a compiled enum domain?
-
-**Why the executor cannot decide it.** Adding a domain to catalog.gd is a schema change with a digest consequence, and the excavation owner does not exist yet to be asked.
-
-**Impact.** Advisory. The mapping is documented in ADR 0131 so the excavation lane inherits it rather than re-deriving it.
-
-<a id="capacity-resolver-addition-allowlist"></a>
-## May the capacity resolver allowlist `+` for nested constant definitions?
-
-*Asked 2026-09-14.*
-
-**Question.** REG-C3-R01 allowlists "products and qualified constants" for the source-proved capacity resolver. Two of 519 capacities cannot be proved because resolution halts on an addition: `const LINK_CAPACITY = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT` reaches `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`. Source does prove the declared 30720. May `+` join the allowlist for nested constant definitions, or should these two rows stay quarantined?
-
-**Why the executor cannot decide it.** The allowlist is the ruling's, not the executor's. Widening it is a one-line change the audit lane deliberately declined to make, because a resolver that grows its own grammar to resolve more things is no longer proving anything on the ruling's terms.
-
-**Impact.** Exactly 2 of 519 capacities are unproved, both orchard_hive link columns (_link_hive_slot, _link_hive_generation). 517 are proved with zero contradictions. Nothing is blocked; the rows are quarantined in docs/planning/registry_capacity_audit.json rather than guessed.
-
 
 ## What is NOT here
 
diff --git a/docs/rulings/requests/open_items.json b/docs/rulings/requests/open_items.json
index 77efd38..57638fb 100644
--- a/docs/rulings/requests/open_items.json
+++ b/docs/rulings/requests/open_items.json
@@ -14,33 +14,6 @@
       "impact": "MOVE-POLICY-REGISTER, MOVE-ENVELOPE-ERROR and bounded MOVE-FORD-POLICY can proceed under dependencies. Production MOVE-ENVELOPES/05.1b/G01/G02 remain gated; no invented dimensions or bank-step capability.",
       "question_before_cycle_02": "Q1: the clearance class domain and its species assignments, or the measured-envelope convention that derives them. Q2: per species, which of swim-surface, dive, climb and tunnel-walk are enabled and which are explicitly disabled.",
       "partial_ruling": "docs/rulings/2026-09-14_cycle03_movement_policy.md"
-    },
-    {
-      "anchor": "tier-two-demolition-basis",
-      "title": "A tier-2 building's demolition basis is unresolved",
-      "blocks": [],
-      "asked": "2026-09-13",
-      "question": "REQ-SET-127 prices demolition at 'declared construction WU x 0.25' returning '50% original material costs'. \u00a74.2's upgrade table declares no demolition consequence, so for an upgraded building 'original' is ambiguous: the base \u00a74.1 row, the sum of base plus upgrades, or the current tier's declared cost?",
-      "why_we_cannot_decide": "Summing the upgrade chain is a rule, not an inference, and inventing it would set refund economics the balance tables never authored.",
-      "impact": "The store uses the base \u00a74.1 row at every tier and says so in its own header. Whichever way this is ruled, only a constant changes."
-    },
-    {
-      "anchor": "econ-003-excavation-phase-domain",
-      "title": "ECON-003's excavation phases need compiled ids and a site-phase column",
-      "blocks": [],
-      "asked": "2026-09-13",
-      "question": "ECON-003 names nine excavation phases. They are SITE states and map onto the construction store's five project phases not at all one-for-one: each ECON-003 transition is one project run through the whole lifecycle, with 'consume inputs once at WORK start' = `begin_work()` and 'retain earned work, publish nothing' = PHASE_WORK_DONE. This needs compiled ASCII ids in `catalog.gd` and a site-phase column from the excavation owner. Who owns that column, and are the nine ids a protected or a compiled enum domain?",
-      "why_we_cannot_decide": "Adding a domain to catalog.gd is a schema change with a digest consequence, and the excavation owner does not exist yet to be asked.",
-      "impact": "Advisory. The mapping is documented in ADR 0131 so the excavation lane inherits it rather than re-deriving it."
-    },
-    {
-      "anchor": "capacity-resolver-addition-allowlist",
-      "title": "May the capacity resolver allowlist `+` for nested constant definitions?",
-      "blocks": [],
-      "asked": "2026-09-14",
-      "question": "REG-C3-R01 allowlists \"products and qualified constants\" for the source-proved capacity resolver. Two of 519 capacities cannot be proved because resolution halts on an addition: `const LINK_CAPACITY = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT` reaches `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`. Source does prove the declared 30720. May `+` join the allowlist for nested constant definitions, or should these two rows stay quarantined?",
-      "why_we_cannot_decide": "The allowlist is the ruling's, not the executor's. Widening it is a one-line change the audit lane deliberately declined to make, because a resolver that grows its own grammar to resolve more things is no longer proving anything on the ruling's terms.",
-      "impact": "Exactly 2 of 519 capacities are unproved, both orchard_hive link columns (_link_hive_slot, _link_hive_generation). 517 are proved with zero contradictions. Nothing is blocked; the rows are quarantined in docs/planning/registry_capacity_audit.json rather than guessed."
     }
   ],
   "answered": [
@@ -157,6 +130,45 @@
       "cycle": 3,
       "implementation_complete": false,
       "ruling": "docs/rulings/2026-09-14_cycle03_ui_geometry.md#alert-zone-inside-workspace-frame"
+    },
+    {
+      "anchor": "tier-two-demolition-basis",
+      "title": "A tier-2 building's demolition basis is unresolved",
+      "blocks": [],
+      "asked": "2026-09-13",
+      "question": "REQ-SET-127 prices demolition at 'declared construction WU x 0.25' returning '50% original material costs'. \u00a74.2's upgrade table declares no demolition consequence, so for an upgraded building 'original' is ambiguous: the base \u00a74.1 row, the sum of base plus upgrades, or the current tier's declared cost?",
+      "why_we_cannot_decide": "Summing the upgrade chain is a rule, not an inference, and inventing it would set refund economics the balance tables never authored.",
+      "impact": "The store uses the base \u00a74.1 row at every tier and says so in its own header. Whichever way this is ruled, only a constant changes.",
+      "answered": "2026-09-19",
+      "cycle": 4,
+      "implementation_complete": false,
+      "ruling": "docs/rulings/2026-09-19_cycle04_resumption.md"
+    },
+    {
+      "anchor": "econ-003-excavation-phase-domain",
+      "title": "ECON-003's excavation phases need compiled ids and a site-phase column",
+      "blocks": [],
+      "asked": "2026-09-13",
+      "question": "ECON-003 names nine excavation phases. They are SITE states and map onto the construction store's five project phases not at all one-for-one: each ECON-003 transition is one project run through the whole lifecycle, with 'consume inputs once at WORK start' = `begin_work()` and 'retain earned work, publish nothing' = PHASE_WORK_DONE. This needs compiled ASCII ids in `catalog.gd` and a site-phase column from the excavation owner. Who owns that column, and are the nine ids a protected or a compiled enum domain?",
+      "why_we_cannot_decide": "Adding a domain to catalog.gd is a schema change with a digest consequence, and the excavation owner does not exist yet to be asked.",
+      "impact": "Advisory. The mapping is documented in ADR 0131 so the excavation lane inherits it rather than re-deriving it.",
+      "answered": "2026-09-19",
+      "cycle": 4,
+      "implementation_complete": false,
+      "ruling": "docs/rulings/2026-09-19_cycle04_resumption.md"
+    },
+    {
+      "anchor": "capacity-resolver-addition-allowlist",
+      "title": "May the capacity resolver allowlist `+` for nested constant definitions?",
+      "blocks": [],
+      "asked": "2026-09-14",
+      "question": "REG-C3-R01 allowlists \"products and qualified constants\" for the source-proved capacity resolver. Two of 519 capacities cannot be proved because resolution halts on an addition: `const LINK_CAPACITY = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT` reaches `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`. Source does prove the declared 30720. May `+` join the allowlist for nested constant definitions, or should these two rows stay quarantined?",
+      "why_we_cannot_decide": "The allowlist is the ruling's, not the executor's. Widening it is a one-line change the audit lane deliberately declined to make, because a resolver that grows its own grammar to resolve more things is no longer proving anything on the ruling's terms.",
+      "impact": "Exactly 2 of 519 capacities are unproved, both orchard_hive link columns (_link_hive_slot, _link_hive_generation). 517 are proved with zero contradictions. Nothing is blocked; the rows are quarantined in docs/planning/registry_capacity_audit.json rather than guessed.",
+      "answered": "2026-09-19",
+      "cycle": 4,
+      "implementation_complete": false,
+      "ruling": "docs/rulings/2026-09-19_cycle04_resumption.md"
     }
   ]
 }
diff --git a/godot/scripts/core/inventory.gd b/godot/scripts/core/inventory.gd
index a818cc7..38e00b3 100644
--- a/godot/scripts/core/inventory.gd
+++ b/godot/scripts/core/inventory.gd
@@ -479,7 +479,10 @@ var _attesting: bool = false
 ## STOCK-SEED-R01's seed-consumer eligibility authority: the object publishing
 ## `refuses_seed_consumption(lot_ref) -> bool`. `stock_age.gd` is the real one. Wiring, not
 ## simulation state: not journaled, absent from state_bytes(), and it survives clear().
-var _seed_expiry_authority: Object = null
+## STOCK-C4-LIFETIME-R01: BORROWED, therefore held WEAKLY. `settlement_system.gd` owns both
+## objects and `stock_age.gd` already holds this store strongly, so a strong edge back would
+## close an ownership cycle neither side can break. Still not journaled, still not saved state.
+var _seed_expiry_authority: WeakRef = null
 ## Cleanup declaration, in the INVENTORY LOT generation namespace (never the container one).
 ## `release_all_reservations()` sets `_tx_cleanup_lot`; the next operation inside the SAME
 ## explicit transaction picks it up in `_op_cleanup_lot` and clears the pending one, so a
@@ -2115,13 +2118,24 @@ func set_seed_expiry_authority(authority: Object) -> OpResult:
 		return _refuse(REFUSE_TRANSACTION_OPEN)
 	if authority != null and not authority.has_method(SEED_EXPIRY_ATTESTATION_METHOD):
 		return _refuse(REFUSE_INVALID_SEED_EXPIRY_AUTHORITY)
-	_seed_expiry_authority = authority
+	# An explicit unbind and a released binding are DIFFERENT states and stay different: null
+	# enforces nothing, while a dead WeakRef refuses every consumer in the guard below.
+	if authority == null:
+		_seed_expiry_authority = null
+	else:
+		_seed_expiry_authority = weakref(authority)
 	return _ok(NULL_REF, 0)
 
 
 func has_seed_expiry_authority() -> bool:
-	"""True when a seed-expiry authority is bound and seed consumption is therefore enforced."""
-	return _seed_expiry_authority != null
+	"""True when a LIVE seed-expiry authority is bound and seed consumption is enforced.
+
+	False for never bound, for explicitly unbound, AND for a binding whose object has been
+	released -- but only the first two admit anything. The third still REFUSES consumption.
+	"""
+	if _seed_expiry_authority == null:
+		return false
+	return _seed_expiry_authority.get_ref() != null
 
 
 func _seed_consumption_refusal(lot_ref: Vector2i) -> StringName:
@@ -2130,11 +2144,18 @@ func _seed_consumption_refusal(lot_ref: Vector2i) -> StringName:
 	The one place this module asks about seed age. `_attesting` is raised across the call so
 	`_guard()` refuses every mutator an authority might re-enter with, and no `_math` or `_plan`
 	value may be held across it -- which is why every caller asks before it costs anything.
+
+	STOCK-C4-LIFETIME-R01: the binding is borrowed, so a PREVIOUSLY BOUND authority that has been
+	released fails CLOSED with INVALID_SEED_EXPIRY_AUTHORITY. It never degrades into the unbound
+	case, which enforces nothing. The strong local below holds a live predicate for the call only.
 	"""
 	if _seed_expiry_authority == null:
 		return REFUSE_NONE
+	var authority: Object = _seed_expiry_authority.get_ref()
+	if authority == null:
+		return REFUSE_INVALID_SEED_EXPIRY_AUTHORITY
 	_attesting = true
-	var refuses: bool = bool(_seed_expiry_authority.call(SEED_EXPIRY_ATTESTATION_METHOD, lot_ref))
+	var refuses: bool = bool(authority.call(SEED_EXPIRY_ATTESTATION_METHOD, lot_ref))
 	_attesting = false
 	if refuses:
 		return REFUSE_SEED_PAST_SHELF_LIFE
diff --git a/godot/scripts/ui/ui_shell.gd b/godot/scripts/ui/ui_shell.gd
index 5de008c..1049924 100644
--- a/godot/scripts/ui/ui_shell.gd
+++ b/godot/scripts/ui/ui_shell.gd
@@ -2747,6 +2747,7 @@ func clear_resident_detail() -> void:
 		_need_rates[index].text = ""
 		_need_basis_points[index] = 0
 		_need_rows[index].visible = false
+	_recompute_selection_gate()
 
 
 func set_detail_health(text: String) -> void:
@@ -2891,6 +2892,7 @@ func set_detail_open(open: bool) -> void:
 	"""Open or close UI-SET-036, which also changes §1.2's command-strip interval."""
 	_detail_open = open
 	(_zones[ID_DETAIL] as Control).visible = open
+	_recompute_selection_gate()
 	_apply_geometry()
 
 
@@ -3299,14 +3301,31 @@ func open_workspace_page(page_id: int, opener_id: int = ID_RESIDENTS) -> bool:
 		return _refuse(REFUSE_UNKNOWN_ELEMENT)
 	_retire_outgoing_members()
 	_workspace_page = page_id
-	_gates.set_surface_open(page_id, true)
+	_apply_workspace_gate(page_id, true)
 	(_zones[ID_WORKSPACE] as Control).visible = true
 	_show_open_page()
 	_apply_geometry()
+	# Context changes must refresh input even when an off-tree layout cannot run.
+	_register_hit_regions()
 	_last_refusal = REFUSE_NONE
 	return true
 
 
+func _apply_workspace_gate(page_id: int, open: bool) -> void:
+	"""UI-C4-R01: opening a workspace page must gate the frame and its Back action too.
+
+	§4 gates UI-SET-051 (the frame) and UI-SET-092 (Back) on WORKSPACE, exactly the same fact
+	as the page itself. Only the page's own surface bit was being written, so the frame and
+	Back stayed §4-ABSENT under a truly open page: `_register_hit_regions()` reads
+	`creates_control()` before it will register a region, so a visibly drawn, opaque frame
+	was absent from the hit table. The engine-input baseline confirms Godot consumed
+	those clicks; the table was the inconsistent layer.
+	"""
+	_gates.set_surface_open(page_id, open)
+	_gates.set_surface_open(ID_WORKSPACE, open)
+	_gates.set_surface_open(ID_BACK, open)
+
+
 func _retire_outgoing_members() -> void:
 	"""Hide every member of the surface the last switch retired, so none keeps a hit region."""
 	var count: int = _focus.outgoing_into(_outgoing)
@@ -3322,12 +3341,30 @@ func workspace_page() -> int:
 	return _workspace_page
 
 
+func _recompute_selection_gate() -> void:
+	"""UI-C4-R01: SELECTED reflects any live reference OR an open detail/tile context.
+
+	`Gates.has_selection` was written nowhere, so every SELECTED-gated element -- the journal,
+	its tabs, Pin -- was permanently §4-ABSENT even while visibly drawn. A tile has no stored
+	resident/job/zone reference at all (`ui_manager.gd` opens tile detail through
+	`set_detail_display()`/`set_detail_open()` alone), so the open detail panel itself is also
+	a selected context, not only the four typed references.
+	"""
+	_gates.has_selection = _detail_open \
+		or _selected_basin != EntityDirectoryScript.NULL_REF \
+		or _selected_zone != EntityDirectoryScript.NULL_REF \
+		or _selected_job != EntityDirectoryScript.NULL_REF \
+		or _selected_resident != EntityDirectoryScript.NULL_REF
+	_register_hit_regions()
+
+
 func select_basin(basin: Vector2i, danger_band: int) -> bool:
 	"""Point the zone tool at a generated ecology basin. Refuses a band §5.5 does not define."""
 	if danger_band < DANGER_MIN or danger_band > DANGER_MAX:
 		return _refuse(REFUSE_TILE_RANGE)
 	_selected_basin = basin
 	_selected_basin_danger = danger_band
+	_recompute_selection_gate()
 	_last_refusal = REFUSE_NONE
 	return true
 
@@ -3372,18 +3409,20 @@ func select_zone(zone: Vector2i, enabled: bool) -> void:
 	_selected_zone = zone
 	_selected_zone_enabled = enabled
 	(_controls[ID_WORK_POLICY] as Control).visible = zone != EntityDirectoryScript.NULL_REF
-	_register_hit_regions()
+	_recompute_selection_gate()
 
 
 func select_job(job: Vector2i) -> void:
 	"""Select a queued job, which the quick menu can cancel."""
 	_selected_job = job
+	_recompute_selection_gate()
 
 
 func select_resident(resident: Vector2i, proposed_name: String) -> void:
 	"""Select a resident and the name typed into UI-SET-082's editor."""
 	_selected_resident = resident
 	_pending_name = proposed_name
+	_recompute_selection_gate()
 
 
 func cancel_selected_job() -> bool:
@@ -3535,15 +3574,20 @@ func report_action_result(accepted: bool, message: String) -> void:
 
 
 func _on_back_pressed() -> void:
-	"""UI-SET-092: close the workspace frame, returning focus where §2.2 sends it.
+	"""UI-SET-092: close the workspace frame. A CLOSE, never a toggle: it always ends closed.
 
 	§2.2: focus returns to the opening control if still present, otherwise the zone's first
 	control. The router owns both branches; closing without it left focus standing on a
-	control that had just been hidden."""
+	control that had just been hidden. §4 gates the frame (051) and Back (092) on WORKSPACE
+	exactly as it gates the page itself, so both drop with it here too, and a second press
+	must find nothing left open to reopen -- `_toggle_zone()` flips visibility either way and
+	could reopen what the first press had just closed.
+	"""
 	_focus.close_surface(_gates)
 	_retire_outgoing_members()
-	_gates.set_surface_open(_workspace_page, false)
-	_toggle_zone(ID_WORKSPACE)
+	_apply_workspace_gate(_workspace_page, false)
+	(_zones[ID_WORKSPACE] as Control).visible = false
+	_register_hit_regions()
 	shell_action.emit(ID_BACK)
 
 
@@ -3767,6 +3811,15 @@ func availability() -> UiAvailability:
 	return _availability
 
 
+func gates() -> UiAvailability.Gates:
+	"""The runtime context facts this shell's §4 Gate column is evaluated against.
+
+	Exposed for the suite, which must prove `has_selection` and the workspace surface bits
+	actually track the live selection and the open workspace, not merely assert it in prose.
+	"""
+	return _gates
+
+
 func registry() -> UiRegistry:
 	"""The §4 registry every control's name and size comes from."""
 	return _registry
diff --git a/godot/test/test_ui_shell.gd b/godot/test/test_ui_shell.gd
index 615fca9..d0aad13 100644
--- a/godot/test/test_ui_shell.gd
+++ b/godot/test/test_ui_shell.gd
@@ -2054,8 +2054,13 @@ func test_the_ordinary_workspace_raises_no_scrim_and_the_compact_one_does() -> v
 	assert_true(_shell.open_workspace_page(UiRegistry.ROSTER_ID), "the roster opens")
 	assert_true(_shell.layout_for(1280, 720), "the standard layout computes")
 	assert_false(_shell.hit_test().scrim_is_up(), "an ordinary workspace raises no scrim")
-	assert_true(_shell.hit_test().world_receives(Vector2(1000.0, 300.0)),
-		"and the world beside it is still clickable")
+	var frame: Rect2 = Rect2(_shell.control_for(UiShell.ID_WORKSPACE).position,
+		_shell.control_for(UiShell.ID_WORKSPACE).size)
+	var outside: Vector2 = Vector2(1200.0, 300.0)
+	assert_false(frame.has_point(outside), "the world probe is actually outside the workspace")
+	assert_false(_shell.hit_test().world_receives(frame.get_center()), "the opaque frame consumes")
+	assert_true(_shell.hit_test().world_receives(outside),
+		"and the uncovered world beside it is still clickable")
 	assert_true(_shell.apply_user_scale(UiLayout.USER_SCALE_150), "150 percent applies")
 	assert_true(_shell.layout_for(1280, 720), "the narrow layout computes")
 	assert_true(_shell.hit_test().scrim_is_up(), "the compact variant raises one")
diff --git a/tools/audit_registry_capacities.py b/tools/audit_registry_capacities.py
index 2ea3099..2fc8e81 100644
--- a/tools/audit_registry_capacities.py
+++ b/tools/audit_registry_capacities.py
@@ -10,6 +10,15 @@ docs/planning/canonical_state_registry.json and WRITES ONLY
 docs/planning/registry_capacity_audit.json. It never edits the registry, the
 registry's checker, the persistence document, or any compiled declaration.
 
+REG-C4-R01 (2026-09-19, docs/rulings/2026-09-19_cycle04_resumption.md) extends
+the proof grammar with bounded addition: a declared capacity may now be a
+left-associative sum of the same allowlisted products, `sum := product ('+'
+product)*`, with multiplication still binding tighter and every intermediate --
+including inside a nested constant's own definition -- checked against signed
+int64 before the next step. Nothing else about the sidecar's shape, scope or
+authority changes: this is still a read-only proof grammar, not a store, a
+capacity, a save schema or a memory allocation.
+
 THE PROOF RULE. A capacity is proved by godot/scripts/core/<module>.gd and by
 nothing else. The registry's own prose is the CLAIM under audit; agreement
 between the registry and another document is not evidence and is never accepted
@@ -20,8 +29,10 @@ here. Concretely, for each field the audit:
      requires it to be the SAME expression text (the binding proof);
   3. resolves that expression with a restricted integer evaluator -- decimal
      literals, module constants, `Alias.CONST` through explicit `preload`
-     aliases, and `*` products only. There is no `eval`, no cross-module
-     guessing of a bare name, and no float anywhere;
+     aliases, and left-associative sums of `*` products (REG-C4-R01:
+     `sum := product ('+' product)*`, multiplication binding tighter). There
+     is no `eval`, no cross-module guessing of a bare name, and no float
+     anywhere;
   4. classifies the SOURCE as equality or upper bound from the source itself: a
      compile-time constant is an equality, a runtime `var` narrowed by exactly
      one `clampi(arg, lo, MAX)` is an upper bound;
@@ -59,7 +70,7 @@ SIDECAR_PATH = ROOT / "docs/planning/registry_capacity_audit.json"
 CORE_DIR = ROOT / "godot/scripts/core"
 
 AUDIT_ID = "RWL-REGISTRY-CAPACITY-AUDIT-2026-09-14-1"
-AUDIT_SCHEMA_VERSION = 1
+AUDIT_SCHEMA_VERSION = 2
 
 INT64_MIN = -9223372036854775808
 INT64_MAX = 9223372036854775807
@@ -125,15 +136,33 @@ GROUP_RESIZE_RE = re.compile(
 	r"^\tfor ([a-z_]+)(?:: Packed[A-Za-z0-9]+Array)? in \[([\s\S]*?)\]:\n((?:\t\t[^\n]*\n)+)",
 	re.M,
 )
-CLAMPI_RE = re.compile(r"^[ \t]*(_[a-z0-9_]+) = clampi\(([^,]+), *(-?\d+), *([^()]+?)\)[ \t]*$", re.M)
-ASSIGN_RE_TEMPLATE = r"^[ \t]*%s = (?!=)[^\n]*$"
+# REG-C4-R01 independent-review F-01: a direct resize is now recognised at ANY
+# indentation (nested if/for/match bodies), with an optional `self.` prefix,
+# and as the tail of a single inline compound statement (`if cond: x.resize(...)`).
+# Additional direct resize spellings are counted below: an unmatched call must
+# quarantine the row even when a different, supported resize was recognised.
+DIRECT_RESIZE_TEMPLATE = r"^[ \t]*(?:\S.*:[ \t]*)?(?:self\.)?%s\.resize\(([^\n]+)\)[ \t]*$"
+CLAMPI_RE = re.compile(r"^[ \t]*(?:self\.)?(_[a-z0-9_]+) = clampi\(([^,]+), *(-?\d+), *([^()]+?)\)[ \t]*$", re.M)
+# REG-C4-R01 independent-review F-02: every AUGMENTED runtime assignment counts
+# too (=, +=, -=, *=, /=, %=, **=, <<=, >>=, &=, |=, ^=), with an optional
+# `self.` prefix and conventional whitespace, so a single clamp proof cannot
+# ignore a later write that moves the variable past its proved maximum.
+# `%%=` below escapes the literal `%` this template is later formatted with via `%`.
+ASSIGN_RE_TEMPLATE = (
+	r"(?<![A-Za-z0-9_.])(?:self\.)?%s[ \t]*"
+	r"(?:\*\*=|<<=|>>=|\+=|-=|\*=|/=|%%=|&=|\|=|\^=|=(?!=))"
+)
 
 TERM_RE = re.compile(r"^(?:\d+|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?)$")
 RUNTIME_VAR_RE = re.compile(r"^_[a-z0-9_]+$")
 DECIMAL_RE = re.compile(r"^\d+$")
 UPPER_NAME_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")
 QUALIFIED_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\.([A-Z][A-Z0-9_]*)$")
-NON_ALLOWLISTED_OPERATORS = "+-/%()<>&|^~"
+# REG-C4-R01 allowlists sums ('+') of products ('*') and qualified constants only.
+# Everything below -- unary sign, parentheses, subtraction, division, calls,
+# indexing, comparisons, bitwise operators -- halts resolution rather than being
+# folded or guessed at.
+NON_ALLOWLISTED_OPERATORS = "-/%()<>&|^~"
 
 
 class Proved(NamedTuple):
@@ -228,7 +257,12 @@ def load_source_index(core_dir: pathlib.Path = CORE_DIR) -> dict:
 
 # --- prose grammar --------------------------------------------------------
 
-LHS_RE = re.compile(r"^\s*`([A-Za-z0-9_. *]+)`\s*$")
+# The backtick class admits the same characters the resize-binding expression
+# may use under REG-C4-R01: names, dots, digits, `*` and `+`. A prose reading
+# still has to be the SAME text as the source's own resize argument (checked
+# later in resize_binding/audit_field); widening this class only lets the
+# prose SAY a sum, never lets it be believed without that binding match.
+LHS_RE = re.compile(r"^\s*`([A-Za-z0-9_. +*]+)`\s*$")
 RHS_RE = re.compile(r"^\s*(\d+)\s*$")
 RELATION_SPELLINGS = (("<=", RELATION_LTE), ("=", RELATION_EQ))
 
@@ -283,21 +317,48 @@ def _guard_int64(value: int, where: str):
 
 
 def resolve_expression(index: dict, module: str, expression: str, depth: int = 0):
-	"""Resolve an allowlisted integer expression from source. Products and names only."""
+	"""Resolve an allowlisted sum of products (REG-C4-R01).
+
+	The grammar is `sum := product ('+' product)*; product := term ('*' term)*`,
+	with `*` binding before `+` and both associating left to right. Every
+	intermediate result -- each product's running multiplication AND the running
+	sum across `+` -- is checked against signed int64 before the next step is
+	taken, including inside a nested constant's own definition, so an
+	overflowing intermediate can never be rescued by a later term that happens
+	to bring the total back into range.
+	"""
 	if depth > MAX_RESOLVE_DEPTH:
 		return Unproved("resolution_too_deep", "exceeded %d substitutions" % MAX_RESOLVE_DEPTH)
 	if module not in index:
 		return Unproved("unknown_module", "no godot/scripts/core/%s.gd" % module)
 	operators = sorted({character for character in expression if character in NON_ALLOWLISTED_OPERATORS})
 	if operators:
-		# REG-C3-R01 allowlists "products and qualified constants". `+` is NOT on that
-		# list, so a nested `const A = B + C` halts here instead of being folded. That is
-		# a deliberate refusal, not a parser gap: extending the allowlist is a decision
-		# for the reviewer of this sidecar, and the quarantine row names the exact
+		# REG-C4-R01 allowlists sums of products and qualified constants: `+` and
+		# `*` only, left-associative, with `*` binding tighter. Everything else --
+		# unary sign, parentheses, subtraction, division and the rest -- halts
+		# here instead of being folded. That is a deliberate refusal, not a
+		# parser gap: widening the grammar further is a decision for the
+		# reviewer of this sidecar, and the quarantine row names the exact
 		# definition and line where resolution stopped.
 		return Unproved("non_allowlisted_operator",
-			"%r uses %s; REG-C3-R01 allowlists products and qualified constants only"
+			"%r uses %s; REG-C4-R01 allowlists sums of products and qualified constants only"
 			% (expression, "".join(operators)))
+	total = 0
+	chain: list = []
+	for summand in expression.split("+"):
+		product = resolve_product(index, module, summand.strip(), depth)
+		if isinstance(product, Unproved):
+			return product
+		chain.extend(product.chain)
+		guarded = _guard_int64(total + product.value, expression)
+		if isinstance(guarded, Unproved):
+			return guarded
+		total = guarded.value
+	return Proved(total, tuple(chain))
+
+
+def resolve_product(index: dict, module: str, expression: str, depth: int):
+	"""Resolve one product term: literals and names joined by `*`, left to right."""
 	terms = [term.strip() for term in expression.split("*")]
 	if any(not TERM_RE.match(term) for term in terms):
 		return Unproved("unsupported_expression", "%r is not literals and names joined by `*`" % expression)
@@ -356,7 +417,9 @@ def resolve_clamped_bound(index: dict, module: str, variable: str):
 	source = index[module]
 	if variable not in source.int_vars:
 		return Unproved("unknown_symbol", "%s.gd declares no `var %s: int`" % (module, variable))
-	assignments = re.findall(ASSIGN_RE_TEMPLATE % re.escape(variable), source.text, re.M)
+	assignment_source = "\n".join(line for line in source.text.splitlines()
+		if not line.lstrip().startswith("#"))
+	assignments = re.findall(ASSIGN_RE_TEMPLATE % re.escape(variable), assignment_source, re.M)
 	clamps = [m for m in CLAMPI_RE.finditer(source.text) if m.group(1) == variable]
 	if len(clamps) != 1 or len(assignments) != len(clamps):
 		return Unproved(
@@ -374,17 +437,32 @@ def resolve_clamped_bound(index: dict, module: str, variable: str):
 	return Proved(bound.value, bound.chain + (step,))
 
 
+def _flatten_terms(expression: str) -> list:
+	"""Every leaf term across a sum of products, in left-to-right order.
+
+	With only one summand this is exactly the old product-only term list, so a
+	single-product expression's classification is unchanged; REG-C4-R01 only
+	generalises this to look across every summand as well.
+	"""
+	terms: list = []
+	for summand in expression.split("+"):
+		terms.extend(term.strip() for term in summand.split("*"))
+	return terms
+
+
 def classify_from_source(index: dict, module: str, expression: str):
 	"""Decide equality versus maximum FROM SOURCE, never from the prose operator.
 
 	A compile-time constant sizes the column exactly. A runtime `var` narrowed by
-	a single `clampi` sizes it at most. Mixing the two in one product is refused
-	rather than collapsed, because the result would be neither claim.
+	a single `clampi` sizes it at most. Mixing the two anywhere in the sum -- by
+	`+` or by `*` -- is refused rather than collapsed, because the result would be
+	neither claim.
 	"""
-	terms = [term.strip() for term in expression.split("*")]
+	terms = _flatten_terms(expression)
 	runtime = [term for term in terms if RUNTIME_VAR_RE.match(term)]
 	if runtime and len(terms) > 1:
-		return RELATION_LTE, Unproved("mixed_dynamic_expression", "%r multiplies runtime var(s) %s" % (expression, runtime))
+		return RELATION_LTE, Unproved("mixed_dynamic_expression",
+			"%r mixes runtime var(s) %s with other term(s)" % (expression, runtime))
 	if runtime:
 		return RELATION_LTE, resolve_clamped_bound(index, module, runtime[0])
 	return RELATION_EQ, resolve_expression(index, module, expression)
@@ -400,7 +478,17 @@ def resize_binding(index: dict, module: str, member: str):
 	source = index[module]
 	if member not in source.columns:
 		return Unproved("missing_column", "%s.gd declares no packed column %s" % (module, member))
-	direct = list(re.finditer(r"^\t%s\.resize\(([^\n]+)\)[ \t]*$" % re.escape(member), source.text, re.M))
+	# REG-C4-R01 independent-review F-01: DIRECT_RESIZE_TEMPLATE matches this column's
+	# resize at any indentation and with or without a `self.` prefix, so a conflicting
+	# resize nested inside an `if`/`for` body is no longer invisible to this scan.
+	direct = list(re.finditer(DIRECT_RESIZE_TEMPLATE % re.escape(member), source.text, re.M))
+	# Count every direct call token, including unsupported multiline/semicolon forms.
+	# A supported call elsewhere must not hide an unrecognised second sizing.
+	call_token = re.compile(r"(?<![A-Za-z0-9_])(?:self\.)?%s\.resize[ \t]*\(" % re.escape(member))
+	call_count = sum(len(call_token.findall(line)) for line in source.text.splitlines()
+		if not line.lstrip().startswith("#"))
+	if call_count != len(direct):
+		return Unproved("unsupported_resize", "%s.%s has an unrecognised direct resize" % (module, member))
 	found = [(m.group(1).strip(), _line_of(source.text, m.start())) for m in direct]
 	for group in GROUP_RESIZE_RE.finditer(source.text):
 		members = [name.strip() for name in group.group(2).replace("\n", " ").split(",")]
@@ -554,7 +642,8 @@ def build_audit(registry: dict, index: dict) -> dict:
 	return {
 		"audit_id": AUDIT_ID,
 		"audit_schema_version": AUDIT_SCHEMA_VERSION,
-		"contract": "REG-C3-R01 (docs/rulings/2026-09-14_cycle03_save_counts_and_capacities.md)",
+		"contract": "REG-C3-R01 (docs/rulings/2026-09-14_cycle03_save_counts_and_capacities.md); "
+			"REG-C4-R01 (docs/rulings/2026-09-19_cycle04_resumption.md)",
 		"kind": "read_only_sidecar",
 		"adopted": False,
 		"notes": [
@@ -562,12 +651,14 @@ def build_audit(registry: dict, index: dict) -> dict:
 			"No prose capacity is converted into the registry here; a later ruling decides adoption.",
 			"Every proof is GDScript source. Agreement with another document is never accepted as proof.",
 			"Equality and upper bound are preserved as distinct claims and are never flattened.",
-			"source_registry_sha256 in the registry is NOT re-asserted by this audit; only the file digest below is this audit's own observation.",
+			"REG-C4-R01 extends the proof grammar to bounded, left-associative sums of the existing "
+				"allowlisted products; no store, capacity or save schema changed as a result.",
+			"source_registry_sha256 in the registry is NOT re-asserted by this audit; only the canonical JSON digest below is this audit's own observation.",
 		],
 		"audited_registry": {
 			"registry_id": registry["registry_id"],
 			"registry_version": registry["registry_version"],
-			"registry_file_sha256": hashlib.sha256(
+			"registry_canonical_json_sha256": hashlib.sha256(
 				json.dumps(registry, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest(),
 			"path": REGISTRY_PATH.relative_to(ROOT).as_posix(),
 		},
diff --git a/tools/test_registry_capacity_audit.py b/tools/test_registry_capacity_audit.py
index 2b1bc7a..90e3e5e 100644
--- a/tools/test_registry_capacity_audit.py
+++ b/tools/test_registry_capacity_audit.py
@@ -1,5 +1,5 @@
 #!/usr/bin/env python3
-"""Self-test for the source-proved registry capacity audit (REG-C3-R01).
+"""Self-test for the source-proved registry capacity audit (REG-C3-R01, REG-C4-R01).
 
 NEGATIVE TESTS COME FIRST AND OUTNUMBER THE POSITIVE ONES, deliberately. An
 auditor with no refusal test is indistinguishable from one that stamps
@@ -7,7 +7,7 @@ auditor with no refusal test is indistinguishable from one that stamps
 indistinguishable from one that returns `eq` unconditionally -- which is
 precisely the flattening REG-C3-R01 forbids.
 
-The five cases this file exists for are the ones the task names:
+The five original cases this file exists for are the ones the task names:
 
   N01  prose that could be read two ways is refused, never resolved by
        preference. `<=` contains `=`, so a lenient left-hand side would make
@@ -23,6 +23,17 @@ The five cases this file exists for are the ones the task names:
        the expression is an allowlisted product, and is refused with its exact
        halting definition when it is not.
 
+REG-C4-R01 (2026-09-19) extends the resolver to bounded addition, and adds:
+
+  N18  multiplication binds before addition and both associate left to right.
+  N19  a sum may mix a local constant with a qualified `Alias.CONST` sum term.
+  N20  int64 overflow is caught on every addition step, including inside a
+       nested constant's own `+`, exactly as it always was for `*`.
+  N21  unary plus, empty addends and parenthesised sums are refused, never
+       silently repaired; only `+` and `*` were ever added to the allowlist.
+  N22  a self-referential or mutually-referential constant halts at the depth
+       bound rather than looping forever.
+
 EVERY SYNTHETIC MODULE HERE IS FICTIONAL. The constants are named so a search
 for a real store cannot find them, and no synthetic number is a capacity this
 project uses. The tests that touch real files read them; none writes them.
@@ -210,14 +221,19 @@ def test_n07_a_symbol_is_never_borrowed_from_another_module() -> None:
 
 
 def test_n08_expression_not_a_literal() -> None:
-	"""N08: allowlisted products resolve; other arithmetic halts with its exact definition."""
+	"""N08: allowlisted products resolve; other arithmetic halts with its exact definition.
+
+	REG-C4-R01 adds `+` to the allowlist, so this case no longer includes it (see
+	N18-N22 for addition's own coverage); subtraction, division and parentheses
+	remain refused exactly as before.
+	"""
 	product = module_index(alpha=const_module(
 		"BETA_TOTAL", "BETA_ROWS * BETA_COLUMNS",
 		extra="const BETA_ROWS: int = 7\nconst BETA_COLUMNS: int = 11\n"))
 	row = audit_one(product, "`BETA_TOTAL` = 77")
 	check("N08 a product of constants proves", row["status"] == "proved_equality" and row["source_value"] == 77)
 	check("N08 the proof chain shows every substitution", len(row["proof_chain"]) == 3)
-	for expression, operator in (("BETA_ROWS + BETA_COLUMNS", "+"), ("BETA_ROWS - BETA_COLUMNS", "-"),
+	for expression, operator in (("BETA_ROWS - BETA_COLUMNS", "-"),
 			("BETA_ROWS / BETA_COLUMNS", "/"), ("(BETA_ROWS)", "(")):
 		index = module_index(alpha=const_module(
 			"BETA_TOTAL", expression,
@@ -358,6 +374,184 @@ def test_n17_no_row_is_ever_dropped() -> None:
 		sum(built["status_counts"].values()) == 4)
 
 
+def test_n18_sum_precedence_and_nested_products() -> None:
+	"""REG-C4-R01: `+` associates left to right and binds looser than `*`, never the reverse."""
+	index = module_index(alpha=const_module(
+		"BETA_TOTAL", "BETA_ROWS + BETA_COLUMNS * BETA_STRIDE",
+		extra="const BETA_ROWS: int = 5\nconst BETA_COLUMNS: int = 3\nconst BETA_STRIDE: int = 4\n"))
+	row = audit_one(index, "`BETA_TOTAL` = 17")
+	check("N18 multiplication binds before addition", row["status"] == "proved_equality" and row["source_value"] == 17)
+	wrong = audit_one(index, "`BETA_TOTAL` = 32")
+	check("N18 the product-then-sum reading is the only one; a left-to-right sum-first reading does not match",
+		wrong["status"] == "finding_value_mismatch")
+	left_to_right = module_index(alpha=const_module(
+		"BETA_TOTAL", "BETA_A + BETA_B + BETA_C",
+		extra="const BETA_A: int = 1\nconst BETA_B: int = 2\nconst BETA_C: int = 3\n"))
+	sums = audit_one(left_to_right, "`BETA_TOTAL` = 6")
+	check("N18 a chain of sums resolves left to right", sums["status"] == "proved_equality" and sums["source_value"] == 6)
+	check("N18 the proof chain records every addend", len(sums["proof_chain"]) == 4)
+
+
+def test_n19_qualified_sums_resolve_through_aliases() -> None:
+	"""A sum may mix a local constant with a qualified constant from a preloaded module."""
+	index = module_index(
+		alpha='const Gamma := preload("res://scripts/core/gamma.gd")\n'
+			+ const_module("BETA_TOTAL", "BETA_ROWS + Gamma.GAMMA_ROWS",
+				resize_expression="BETA_ROWS + Gamma.GAMMA_ROWS",
+				extra="const BETA_ROWS: int = 40\n"),
+		gamma=const_module("GAMMA_ROWS", "2", column="_gamma_column"),
+	)
+	row = audit_one(index, "`BETA_ROWS + Gamma.GAMMA_ROWS` = 42")
+	check("N19 a qualified sum proves", row["status"] == "proved_equality" and row["source_value"] == 42)
+	check("N19 the chain names the aliased module", any("synthetic/gamma.gd" in step for step in row["proof_chain"]))
+
+
+def test_n20_addition_overflow_is_refused() -> None:
+	"""A sum whose running total cannot fit signed int64 is refused, not wrapped or truncated."""
+	index = module_index(alpha=const_module(
+		"BETA_TOTAL", "BETA_A + BETA_B",
+		extra="const BETA_A: int = %d\nconst BETA_B: int = 5\n" % (audit.INT64_MAX - 1)))
+	row = audit_one(index, "`BETA_TOTAL` = %d" % (audit.INT64_MAX + 4))
+	check("N20 an overflowing sum is refused", row["status"] == "unproved_overflow")
+	check("N20 no overflowed value is published", "source_value" not in row)
+	edge = module_index(alpha=const_module(
+		"BETA_TOTAL", "BETA_A + BETA_B",
+		extra="const BETA_A: int = %d\nconst BETA_B: int = 1\n" % (audit.INT64_MAX - 1)))
+	check("N20 a sum landing exactly on the int64 maximum still proves",
+		audit_one(edge, "`BETA_TOTAL` = %d" % audit.INT64_MAX)["status"] == "proved_equality")
+	nested = module_index(alpha=const_module(
+		"BETA_TOTAL", "BETA_MID + 1",
+		extra="const BETA_MID: int = %d\n" % audit.INT64_MAX))
+	nested_row = audit_one(nested, "`BETA_TOTAL` = 1")
+	check("N20 a nested constant's own overflow halts before any top-level comparison",
+		nested_row["status"] == "unproved_overflow")
+
+
+
+def test_c4_overflow_cannot_be_rescued_by_zero() -> None:
+	"""A nested overflowing sum is invalid even when its caller multiplies by zero."""
+	index = module_index(alpha=const_module(
+		"BETA_TOTAL", "BETA_MID * 0",
+		extra="const BETA_MID: int = %d + 1\n" % audit.INT64_MAX))
+	row = audit_one(index, "`BETA_TOTAL` = 0")
+	check("C4 nested addition overflow survives a later zero multiplier",
+		row["status"] == "unproved_overflow" and "source_value" not in row)
+	direct = audit.resolve_expression(index, "alpha", "%d * 2 * 0 + 1" % audit.INT64_MAX)
+	check("C4 product intermediate overflow survives a later zero and sum",
+		isinstance(direct, audit.Unproved) and direct.reason == "overflow")
+
+
+def test_n21_malformed_addition_is_refused() -> None:
+	"""Unary `+`, empty addends and parenthesised sums are refused, never silently repaired."""
+	index = module_index(alpha=const_module(
+		"BETA_TOTAL", "BETA_ROWS + BETA_COLUMNS",
+		extra="const BETA_ROWS: int = 7\nconst BETA_COLUMNS: int = 11\n"))
+	for expression in ("+BETA_ROWS + BETA_COLUMNS", "BETA_ROWS + BETA_COLUMNS +",
+			"BETA_ROWS + + BETA_COLUMNS", "BETA_ROWS++BETA_COLUMNS"):
+		refused = audit.resolve_expression(index, "alpha", expression)
+		check("N21 %r is refused as unsupported, not repaired" % expression,
+			isinstance(refused, audit.Unproved) and refused.reason == "unsupported_expression")
+	for expression in ("(BETA_ROWS + BETA_COLUMNS)", "BETA_ROWS - BETA_COLUMNS"):
+		refused = audit.resolve_expression(index, "alpha", expression)
+		check("N21 %r is refused as non-allowlisted" % expression,
+			isinstance(refused, audit.Unproved) and refused.reason == "non_allowlisted_operator")
+	malformed = module_index(alpha=const_module("BETA_ROWS", "7", resize_expression="+BETA_ROWS"))
+	row = audit_one(malformed, "`+BETA_ROWS` = 7")
+	check("N21 source-bound unary plus is refused by the proof grammar",
+		row["status"] == "unproved_unsupported_expression" and "source_value" not in row)
+
+
+def test_n22_cyclic_constants_are_quarantined_not_looped_forever() -> None:
+	"""A self-referential or mutually-referential constant halts at the depth bound, not in an infinite loop."""
+	self_ref = module_index(alpha=const_module("BETA_TOTAL", "BETA_TOTAL"))
+	row = audit_one(self_ref, "`BETA_TOTAL` = 5")
+	check("N22 a self-referential constant is quarantined", row["status"] == "unproved_resolution_too_deep")
+	check("N22 no value is invented for the cycle", "source_value" not in row)
+	mutual = module_index(alpha=const_module("BETA_A", "BETA_B", extra="const BETA_B: int = BETA_A\n"))
+	mutual_row = audit_one(mutual, "`BETA_A` = 5")
+	check("N22 a mutually-referential pair is quarantined too", mutual_row["status"] == "unproved_resolution_too_deep")
+	cyclic_sum = module_index(alpha=const_module("BETA_A", "BETA_B + 1", extra="const BETA_B: int = BETA_A + 1\n"))
+	cyclic_sum_row = audit_one(cyclic_sum, "`BETA_A` = 5")
+	check("N22 a cycle hidden inside a sum is quarantined the same way",
+		cyclic_sum_row["status"] == "unproved_resolution_too_deep")
+
+
+def test_f01_nested_and_self_conflicting_resize_is_caught() -> None:
+	"""Independent review F-01: a differently-indented or self-prefixed resize is not invisible.
+
+	Before this fix, only a resize written at exactly one leading tab was ever
+	seen, so a second, conflicting resize written inside an `if` body (deeper
+	indent) or spelled `self.column.resize(...)` was never compared against the
+	first, and the row proved despite two different sizing expressions existing
+	in source.
+	"""
+	nested = (
+		const_module("BETA_ROWS", "512", extra="const BETA_OTHER: int = 8\n")
+		+ "\tif true:\n"
+		+ "\t\t_alpha_column.resize(BETA_OTHER)\n"
+	)
+	row = audit_one(module_index(alpha=nested), "`BETA_ROWS` = 512")
+	check("F01 a resize nested inside `if` is no longer invisible",
+		row["status"] == "unproved_conflicting_resize")
+	self_prefixed = (
+		"const BETA_ROWS: int = 512\n"
+		"const BETA_OTHER: int = 8\n"
+		"var _alpha_column: PackedInt32Array = PackedInt32Array()\n"
+		"func _init() -> void:\n"
+		"\tself._alpha_column.resize(BETA_ROWS)\n"
+		"\t_alpha_column.resize(BETA_OTHER)\n"
+	)
+	row2 = audit_one(module_index(alpha=self_prefixed), "`BETA_ROWS` = 512")
+	check("F01 self.column.resize and bare column.resize are recognised as the same column",
+		row2["status"] == "unproved_conflicting_resize")
+	single_self = const_module("BETA_ROWS", "512").replace(
+		"\t_alpha_column.resize(BETA_ROWS)\n", "\tself._alpha_column.resize(BETA_ROWS)\n")
+	proved = audit_one(module_index(alpha=single_self), "`BETA_ROWS` = 512")
+	check("F01 a single self-prefixed resize still proves", proved["status"] == "proved_equality")
+
+
+def test_f02_augmented_assignment_defeats_clamp_proof() -> None:
+	"""Independent review F-02: a `+=`/`*=` after the clamp is counted, not ignored.
+
+	Before this fix, ASSIGN_RE_TEMPLATE matched only a bare `= ` assignment, so a
+	variable clamped once and then adjusted with an augmented operator still
+	looked like exactly one assignment with exactly one clamp, and the row
+	proved an upper bound the variable could then exceed.
+	"""
+	augmented = clamped_module("_beta_rows", "BETA_ROW_MAX", 16384).replace(
+		"\t_alpha_column.resize(_beta_rows)\n",
+		"\t_beta_rows += 1\n\t_alpha_column.resize(_beta_rows)\n")
+	row = audit_one(module_index(alpha=augmented), "`_beta_rows` <= 16384")
+	check("F02 a later += is counted and defeats the single-clamp proof",
+		row["status"] == "unproved_unbounded_runtime_variable")
+	multiplied = clamped_module("_beta_rows", "BETA_ROW_MAX", 16384).replace(
+		"\t_alpha_column.resize(_beta_rows)\n",
+		"\t_beta_rows *= 1\n\t_alpha_column.resize(_beta_rows)\n")
+	row2 = audit_one(module_index(alpha=multiplied), "`_beta_rows` <= 16384")
+	check("F02 a `*=` after the clamp is counted too", row2["status"] == "unproved_unbounded_runtime_variable")
+	self_clamped = clamped_module("_beta_rows", "BETA_ROW_MAX", 16384).replace(
+		"\t_beta_rows = clampi(p_rows, 1, BETA_ROW_MAX)\n",
+		"\tself._beta_rows = clampi(p_rows, 1, BETA_ROW_MAX)\n")
+	honest = audit_one(module_index(alpha=self_clamped), "`_beta_rows` <= 16384")
+	check("F02 a self-prefixed clamp with no other writes still proves",
+		honest["status"] == "proved_upper_bound")
+
+
+def test_f01_f02_unrecognised_forms_cannot_hide_behind_a_proof() -> None:
+	"""An accepted statement does not excuse a later write outside its syntax."""
+	for tail in ["\tif true: _alpha_column.resize(BETA_ROWS); _alpha_column.resize(8)\n",
+		"\t_alpha_column.resize(\n\t\t8)\n"]:
+		row = audit_one(module_index(alpha=const_module("BETA_ROWS", "512") + tail), "`BETA_ROWS` = 512")
+		check("F01 extra unsupported resize is refused", not row["status"].startswith("proved_"))
+	for operator in ["=", "+=", "-=", "*=", "/=", "%=", "**=", "<<=", ">>=", "&=", "|=", "^="]:
+		for prefix in ["", "self."]:
+			text = clamped_module("_beta_rows", "BETA_ROW_MAX", 16384)
+			text += "\tif true: %s_beta_rows%s1\n" % (prefix, operator)
+			row = audit_one(module_index(alpha=text), "`_beta_rows` <= 16384")
+			check("F02 inline %s%s invalidates bound" % (prefix, operator),
+				row["status"] == "unproved_unbounded_runtime_variable")
+
+
 # --------------------------------------------------------------------------
 # POSITIVE AND STRUCTURAL TESTS
 # --------------------------------------------------------------------------
@@ -429,7 +623,13 @@ def test_p04_render_is_byte_stable() -> None:
 
 
 def test_p05_real_census_matches_astra_or_says_so_loudly() -> None:
-	"""The real registry's census, stated against Astra's Cycle 3 numbers."""
+	"""The real registry's census, stated against Astra's Cycle 3 numbers.
+
+	The prose-level census (this test) is unaffected by REG-C4-R01: prose_relation
+	and prose_value are recorded as soon as the prose itself parses, independent
+	of whether the bound expression later resolves. The proof OUTCOME split is
+	test_p06's job, not this one's.
+	"""
 	built = real_audit()
 	observed = built["census"]["observed"]
 	check("P05 516 prose records", observed["prose_records"] == 516)
@@ -453,28 +653,35 @@ def test_p05_real_census_matches_astra_or_says_so_loudly() -> None:
 
 
 def test_p06_real_proof_status_is_exactly_reported() -> None:
-	"""The real proof outcome: 468 equalities, 46 bounds, 2 unproved, 0 contradictions."""
+	"""The real proof outcome under REG-C4-R01: 470 equalities, 46 bounds, 0 unproved, 0 contradictions.
+
+	Before REG-C4-R01, the two orchard_hive link capacities (`_link_hive_generation`,
+	`_link_hive_slot`) halted on a nested constant's own `+` and were quarantined as
+	`unproved_non_allowlisted_operator`. Addition is now allowlisted, so both resolve
+	from source -- no constant was invented to make this true; the same source that
+	halted resolution before now completes it.
+	"""
 	built = real_audit()
 	counts = built["status_counts"]
-	check("P06 468 proved equalities", counts.get("proved_equality") == 468)
+	check("P06 470 proved equalities", counts.get("proved_equality") == 470)
 	check("P06 46 proved upper bounds", counts.get("proved_upper_bound") == 46)
-	check("P06 2 unproved non-allowlisted operators", counts.get("unproved_non_allowlisted_operator") == 2)
-	check("P06 no other status appears", set(counts) == {"proved_equality", "proved_upper_bound", "unproved_non_allowlisted_operator"})
+	check("P06 no other status appears", set(counts) == {"proved_equality", "proved_upper_bound"})
 	check("P06 the statuses sum to 516", sum(counts.values()) == 516)
-	quarantined = built["unproved_or_contradicted"]
-	check("P06 both quarantined rows are orchard_hive link columns",
-		sorted(row["field_key"] for row in quarantined) == ["_link_hive_generation", "_link_hive_slot"])
-	check("P06 the quarantine names the halting definition",
-		all("orchard_hive.gd:316" in row["quarantine_reason"] for row in quarantined))
-	check("P06 no quarantined row carries a value",
-		all("source_value" not in row for row in built["rows"] if row["status"].startswith("unproved_")))
+	check("P06 nothing is quarantined or contradicted", built["unproved_or_contradicted"] == [])
+	links = [row for row in built["rows"] if row["field_key"] in ("_link_hive_generation", "_link_hive_slot")]
+	check("P06 both orchard link capacities are present and proved",
+		len(links) == 2 and all(row["status"] == "proved_equality" for row in links))
+	check("P06 the orchard link proof still runs through the same nested definition",
+		all(any("orchard_hive.gd:316" in step for step in row["proof_chain"]) for row in links))
+	check("P06 no proved row is missing its resolved value",
+		all("source_value" in row for row in links))
 
 
 def test_p07_every_proved_row_carries_its_provenance() -> None:
 	"""A proved row without a file, line and chain is an assertion, not a proof."""
 	built = real_audit()
 	proved = [row for row in built["rows"] if row["status"].startswith("proved_")]
-	check("P07 514 rows are proved", len(proved) == 514)
+	check("P07 all 516 rows are proved", len(proved) == 516)
 	check("P07 every proved row names a real source file",
 		all((ROOT / row["source_file"]).is_file() for row in proved))
 	check("P07 every proved row cites a resize line", all(row["source_resize_line"] >= 1 for row in proved))
@@ -500,7 +707,12 @@ def test_p08_keys_are_unique_and_nothing_is_lost() -> None:
 
 
 def test_p09_committed_sidecar_is_what_this_source_produces() -> None:
-	"""The committed sidecar regenerates byte-identically, and nothing active is touched."""
+	"""The committed sidecar regenerates byte-identically, and nothing active is touched.
+
+	This is the determinism/regeneration gate. The REG-C4-R01 sidecar is
+	regenerated during integration; this check requires the committed artifact
+	to match current source exactly and never updates it itself.
+	"""
 	before = hashlib.sha256(audit.REGISTRY_PATH.read_bytes()).hexdigest()
 	result = subprocess.run([sys.executable, str(ROOT / "tools/audit_registry_capacities.py"), "--check"],
 		capture_output=True, text=True)
@@ -527,6 +739,8 @@ def test_p10_the_sidecar_declares_itself_unadopted() -> None:
 		"source_registry_sha256" not in json.dumps(built["audited_registry"]))
 	check("P10 the notes say no prose is converted",
 		any("later ruling decides adoption" in note for note in built["notes"]))
+	check("P10 the contract names both governing rulings",
+		"REG-C3-R01" in built["contract"] and "REG-C4-R01" in built["contract"])
 
 
 _REAL: dict = {}

```
