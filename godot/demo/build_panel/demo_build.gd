extends Node
## THE ONE BUILD PANEL AND THE LEVEL BAR IN THE DEMO (DEC-061 Q1; docs/ui_ux_controls.md UI-BUILD-001; decisions 1871
## and 1912). The panel and the bar are game UI (scripts/ui/build_panel.gd, level_bar.gd); this mounts them over the
## village and maps them onto what the demo has.
##
## KEYS (read through demo_command.gd's build hooks: `takes_before_gui`, then `handle_input`):
##   B                  open or close the panel (closing with pending changes asks Keep / Discard).
##   PageUp / PageDown  the level bar, everywhere (level_up / level_down): Surface ... Level 4. Read before the HUD;
##                      never behind a modal.
##   in the panel:      Esc one layer (the stroke, a question, the ledger, the panel); Ctrl+Tab / Ctrl+Shift+Tab the
##                      tabs; Ctrl+Z / Cmd+Z undo; Ctrl+Shift+Z, Ctrl+Y / Cmd+Shift+Z redo; with a room type armed,
##                      left drag paints with the chosen tool, right click cancels the stroke, the arrows move the cell
##                      cursor RELATIVE TO THE CAMERA (Up is the way the camera looks, snapped to the grid: P-B10 (b))
##                      and Enter sets the first corner, Enter again the second.
##
## THE LEVELS (decision 1912; Brendan's ruling on decision 1911 P-C6 (a)). WHILE THE PANEL IS OPEN the bar decides:
## Levels 1-4 are the settlement's ACTUAL underground levels, 5 m apart (demo_build_world.gd draws the World cut at
## the level's floor; the U view draws only that, so the legacy warren is hidden), and painting is armed there;
## Surface and Overview are the surface view with painting off. U pressed meanwhile is read as a choice: off goes to
## the Surface, on goes to Level 1. WITH THE PANEL CLOSED the bar follows the legacy U view as before (decision 1871:
## Level 1 / 2 the legacy warren's; Levels 3 and 4 show nothing). A level with no way in yet is marked "!" on the bar
## and still painted: each cell then says "No way in" on its ghost (BUILD-REQ-013 per cell).
##
## THE CARDS. A room type -- Passage among them -- arms painting on levels 1-4; the Entrance (surface) and Way down
## (levels 1-3) cards arm placing a way down (build_items.gd). The old Passage / Burrow home / Root cellar tool cards
## are gone (Brendan's ruling on decision 1911 P-C2 (c)). While the panel shows, the HUD's command strip (UI-SET-026)
## and its detail (UI-SET-036), the demo's right column, its map-layer picker and its news strip are hidden (their
## place is the panel's), and given back on close. Opening, painting, Undo, Redo and Discard all touch no store,
## reservation or job. Confirm all is held back while any cell has no way in.
##
## THE PROOF OF CONCEPT (decision 1912; Brendan's ruling of 2026-10-12: "A simple mole digs", "Free for now", "Place a
## simple entrance", "Paint rooms + passages"). Confirm all hands the batch to demo_build_works.gd -- nothing is paid,
## nothing reaches the settlement -- and sends a mole (the first selected mole, else the first one free): it walks to
## the Entrance and digs the ordered cells one by one, drawn below by a stand-in figure (demo_build_below_task.gd);
## the dug rooms are drawn open (demo_build_dug.gd) and count as finished space for the next plan. With residents
## selected, a right click on a dug cell sends them down into it. Slice C3 replaces all of it with the real thing.
##
## THE FURNISH TAB (decision 1921; Brendan's rulings of 2026-10-13: "A resident fits it", "Room becomes valid",
## "Footprint + rotation"). An item card chosen on levels 1-4 arms placing it: its ghost follows the cursor on the dug
## pits' floor, R / Shift+R turn it (`placement_rotate`), a click places it in the batch (judged by
## build_furniture.gd: dug cells of one room that uses it, no overlap; refused in words), Shift keeps the card, a right
## click puts it down. Confirm
## all hands each piece to demo_build_fittings.gd -- free, like the rooms -- and sends a resident (the first selected,
## else the first one free who is not a mole) down to fit them one by one (demo_build_below_task.gd MODE_FIT). Each
## room's line ("✓ Kitchen ready") is drawn over it and shown on the Furnish tab, and fitted beds count in the HUD's
## Beds (`built_beds`). Slice E replaces it with install crews, access tiles and payment.
##
## MOUND HOMES (decision 2002, the proof of concept of decision 2001; P-2001-11 (a): free, drawn over unchanged ground,
## unsaved). On the Surface the Rooms tab paints room types in the Mound style; the Furnish tab places a Mound's Front
## door (its colour on the tool strip, oak first) and Windows on its rooms' outer edges -- a click on the edge nearest the
## pointer, again to take one away; Enter at the cursor cell on the side R / Shift+R names -- and furniture on its dug
## floor; the Entrance card placed on a Mound room's floor is its hatch to level 1. Confirm all hands the rooms, doors and
## windows to demo_build_mound_host.gd, whose resident heaps, digs, frames and tops the hill; while the panel shows the
## Surface the hill is drawn cut away. The mole goes down a hatch through its Mound's door.

const BuildPanel := preload("res://scripts/ui/build_panel.gd")
const LevelBar := preload("res://scripts/ui/level_bar.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const Paint := preload("res://demo/build_panel/demo_build_paint.gd")
const Orders := preload("res://demo/build_panel/demo_build_orders.gd")
const Ground := preload("res://demo/build_panel/demo_build_ground.gd")
const BuildWorld := preload("res://demo/build_panel/demo_build_world.gd")
const TunnelControl := preload("res://demo/tunnel/tunnel_control.gd")
const ThemeResource: Theme = preload("res://ui/theme/woodland_theme.tres")
const CommandTips := preload("res://demo/ui/demo_command_tips.gd")
## The paint label keeps this far inside the window's edges (UI §1.2's safe inset).
const SAFE_INSET: float = 16.0

## Over the demo's panels (layer 0), with the HUD's.
const CANVAS_LAYER: int = 1
const LABEL_OFFSET: Vector2 = Vector2(18.0, 18.0)
const LABEL_PX: int = 16
## The paint label keeps this far above the panel.
const LABEL_GAP: float = 8.0
const ARMED_HINT: String = "Paint %s: drag on the floor, or Enter to set a corner"
const ORDERED: String = "Confirm all: %d ordered, %d kept back"
## Decision 1912 (P-C2 (c)): the panel plans; digging what it plans comes later, and it says so.
const OPENED: String = "Build on %s: place an Entrance from the surface, paint rooms and passages below, Confirm all, and a mole digs them (free for now)"
const CLOSED_KEPT: String = "Build panel closed; its pending changes are kept"
## The demo's Build command (UI-SET-027, P-B3 as Brendan approved on 2026-10-12): what it does here.
const BUILD_COMMAND: String = "Open the build panel: place an Entrance, paint rooms and passages below, and a mole digs them"
const ARROW_KEYS: Array[int] = [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Dug := preload("res://demo/build_panel/demo_build_dug.gd")
const Figure := preload("res://demo/build_panel/demo_build_figure.gd")
const Tags := preload("res://demo/build_panel/demo_build_tags.gd")
const BelowTask := preload("res://demo/build_panel/demo_build_below_task.gd")
const Items := preload("res://scripts/ui/build_items.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const MOLE: String = "Mole"
## How often a waiting order looks for a free mole again (seconds; a guard against asking every frame).
const SEND_EVERY_S: float = 2.0
const NO_MOLE: String = "No mole lives in the village: %s digs instead"
const NOBODY: String = "Nobody can dig: the ordered cells wait"
const CUT_OFF: String = "%d ordered cells cannot be reached from an Entrance: they wait"
const SENT: String = "%s goes to the Entrance to dig"
const VISIT: String = "%s goes down to the dug room"
const PLACE_HINT: String = "Place %s: click a spot, or Enter at the cursor"
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")
const Furnish := preload("res://demo/build_panel/demo_build_furnish.gd")
const Rooms := preload("res://demo/build_panel/demo_build_rooms.gd")
const Furniture := preload("res://scripts/ui/build_furniture.gd")
const FITTER_SENT: String = "%s goes to the Entrance to fit the furniture"
const NO_FITTER: String = "Nobody can fit the furniture: it waits"
const FIT_CUT_OFF: String = "The waiting furniture cannot be reached from an Entrance: it waits"
const PIECE_LABEL: String = "Place %s%s\n%s"
const MoundHost := preload("res://demo/build_panel/demo_build_mound_host.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const EDGE_HINT: String = "Place %s: click a Mound room's outer edge"

var panel: BuildPanel = null
var bar: LevelBar = null
var batch: Batch = null
var catalog: BuildCatalog = null
var paint: Paint = null
var orders: Orders = null
var ground: Ground = null
var world: BuildWorld = null
var _layer: CanvasLayer = null
var _label_box: PanelContainer = null
var _label: Label = null
var _tunnels: TunnelControl = null
var _shell: UiShell = null
var _camera: Camera3D = null
var _blocked: Callable = Callable()
var _say: Callable = Callable()
var _hide: Array[Node] = []
var _hidden_was: PackedByteArray = PackedByteArray()
var _holding: bool = false
var _special: int = -1
var _special_on: bool = false
## While building: the level the view was last set to (-1: none) and whether the U view was left on.
var _applied_level: int = -1
var _applied_on: bool = false
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _minimap_was: bool = true
var _pointer: Vector2 = Vector2.INF
var _seen_label: int = -1
## Why the panel could not be set up ("": it was): painting stays disarmed (decision 1871, review M4).
var _setup_refusal: StringName = &""
## Why the actual World's level could not be shown ("": it was, or was not asked for).
var world_refusal: StringName = &""
var works: Works = null
var dug: Dug = null
var _floors: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var _cast: Node = null
var _selection: Callable = Callable()
## The dig trip under way (null: none), and every trip below with its figure.
var digger: BelowTask = null
var _trips: Array[BelowTask] = []
var _figures: Array[Figure] = []
var _spacer: Tags = Tags.new()
var _tag_list: Array[Label3D] = []
var _trip_actors: PackedInt32Array = PackedInt32Array()
var _send_in: float = 0.0
## The last thing said about why no mole went (said once, review M6).
var _said: String = ""
## The works revision the bar's marks were set at.
var _marked_at: int = -1
## The Furnish tab (decision 1921): the confirmed furniture, its drawing, the trip fitting it, and the armed piece's
## quarter turns.
var fittings: Fittings = null
var furnish: Furnish = null
var fitter: BelowTask = null
var _turn: int = 0
var _fit_in: float = 0.0
var _piece_label: Vector4i = Vector4i(0, 0, -1, -1)
var _piece_label_moved: Vector2i = Vector2i(-1, -1)
## The last thing said about why no fitter went (said once, apart from the mole's words).
var _said_fit: String = ""
## Decision 2002: the Mound homes' store, drawing and builder.
var mound: MoundHost = null


func configure(tunnels: TunnelControl, shell: UiShell, camera: Camera3D, blocked: Callable, say: Callable,
		hide: Array[Node], session: Object) -> void:
	"""Mount over this village: its U view, the HUD shell, the camera that paints, the modal test (`blocked() ->
	bool`), the notice line (`say(text)`), the demo surfaces the panel replaces while open, and the settlement's
	underground session (null: none composed, every order refused)."""
	name = "DemoBuild"
	_tunnels = tunnels
	_shell = shell
	_camera = camera
	_blocked = blocked
	_say = say
	_hide = hide.duplicate()
	catalog = BuildCatalog.new()
	orders = Orders.new()
	orders.bind_session(session, camera)
	batch = Batch.new()
	take_setup(batch.configure(catalog, orders.cell_bounds(), orders.cell_capacity()))
	_configure_ground()
	_configure_furnish()
	_configure_mounds()
	_configure_world(session)
	_build_layer()
	unlock_build_command()
	place()


func _configure_ground() -> void:
	"""Each level's dug height (the ledger, DEC-054) and floor (the ghosts), and the ground reader bound to the batch
	(only over a composed underground: with none, the batch judges shapes alone and Confirm all says why)."""
	ground = Ground.new()
	ground.configure(orders.datum_u(), orders.cell_bounds())
	ground.bind(orders.terrain_owner(), orders.excavation_sites(), orders.space_owner())
	works = Works.new()
	works.configure(orders.cell_bounds())
	ground.bind_works(works)
	for level: int in range(1, LevelBar.LEVEL_DEEPEST + 1):
		catalog.set_level_clear_height(level, orders.dug_height_of(level))
		_floors[level] = orders.floor_of(level)
		ground.set_level(level, _floors[level], orders.dug_height_of(level))
	if ground.bound():
		batch.bind_ground(ground.ground, ground.revision)
	paint = Paint.new()
	add_child(paint)
	take_setup(paint.configure(batch, _camera, _datum_xz(), orders.cell_bounds(), _floors))
	dug = Dug.new()
	add_child(dug)
	dug.configure(works, _floors, _datum_xz(), orders.cell_bounds())
	dug.earth.threaded = true


func _configure_furnish() -> void:
	"""The Furnish tab's store, its readers bound to the batch, and its drawing (decision 1921)."""
	fittings = Fittings.new()
	batch.bind_furniture_host(room_at, fittings.occupant, fittings.edge_occupant, fittings.row_at)
	furnish = Furnish.new()
	add_child(furnish)
	furnish.configure(batch, works, fittings, _floors, _datum_xz(), orders.cell_bounds())


func _configure_mounds() -> void:
	"""The Mound homes (decision 2002): their store, its readers bound to the batch, and their drawing."""
	mound = MoundHost.new()
	add_child(mound)
	mound.configure(batch, works, fittings, orders.cell_bounds(), Vector2(_datum_xz()) / 1024.0)


func bind_village(village_world: Object, water: Object, is_day: Callable) -> void:
	"""The village's placements and water (what a Mound's hill would cover) and `is_day() -> bool` (its windows'
	daylight; decision 2002)."""
	mound.bind_village(village_world, water, is_day)


func room_at(level: int, cell: Vector2i) -> int:
	"""build_furniture.gd's room reader: a dug room cell's type, else ROOM_EARTH, ROOM_WAITING (ordered, not dug) or
	ROOM_BARE (dug, no room: a way down's cells, where it stands or lands, even when dug into a room)."""
	var state: int = works.state(level, cell)
	if state != Works.OPEN:
		return Furniture.ROOM_WAITING if state == Works.ORDERED else Furniture.ROOM_EARTH
	var type: int = works.type_of(level, cell)
	return Furniture.ROOM_BARE if type == Works.TYPE_NONE or works.on_way(level, cell) else type


func built_beds() -> int:
	"""Fitted beds, for the HUD's Beds (Brendan's "Placed beds count in the HUD's Beds")."""
	return Rooms.beds(fittings)


func _datum_xz() -> Vector2i:
	"""Cell (0, 0)'s x and z (u)."""
	return Vector2i(orders.datum_u().x, orders.datum_u().z)


func bind_cast(cast: Node, selection: Callable) -> void:
	"""The village's residents (moles dig; anyone visits) and `selection() -> PackedInt32Array`, the selected ones."""
	_cast = cast
	_selection = selection
	mound.bind_cast(cast, _pick_fitter, _say)


func bind_props(props: Object) -> void:
	"""The demo's staged props table (demo_props.gd): the build art drawn where it is staged (decision 1913), and the
	furniture's models (decision 1921)."""
	dug.use_props(props)
	furnish.use_props(props)
	mound.use_props(props)


func _configure_world(session: Object) -> void:
	"""The actual World's level view, built when first shown."""
	world = BuildWorld.new()
	world.configure(session)
	add_child(world)


func unlock_build_command() -> bool:
	"""P-B3, in the demo only: the HUD's Build command (UI-SET-027) is enabled and opens or closes the panel, as B
	does, wearing its own icon, not the lock (decision 1891). The settlement game's shell keeps it locked (ruling 4);
	the shell only lends the icon (`command_icon`). False without a shell."""
	var button: Button = _shell.control_for(UiShell.ID_BUILD) as Button if _shell != null else null
	if button == null:
		return false
	button.disabled = false
	# The shell gave it the lock at creation (UI §2.2: an unwired control wears the lock); enabled, it wears its own
	# icon (decision 1891, correcting 1871 E21).
	button.icon = _shell.command_icon(UiShell.ID_BUILD)
	var index: int = UiShell.COMMAND_IDS.find(UiShell.ID_BUILD)
	button.tooltip_text = CommandTips.tooltip(UiShell.COMMAND_LABELS[index], UiShell.COMMAND_ACTIONS[index],
		BUILD_COMMAND, "")
	button.accessibility_description = BUILD_COMMAND
	if not button.pressed.is_connected(toggle_panel):
		button.pressed.connect(toggle_panel)
	return true


func take_setup(code: StringName) -> void:
	"""A setup step's answer: a refusal is kept (painting stays disarmed) and shown as a HUD refusal."""
	if code == &"" or _setup_refusal != &"":
		return
	_setup_refusal = code
	UIManager.push_refusal(code)


func setup_refusal() -> StringName:
	"""Why the panel could not be set up ("" when it was)."""
	return _setup_refusal


func _build_layer() -> void:
	"""The canvas layer, the level bar (always shown), the panel and the size label."""
	_layer = CanvasLayer.new()
	_layer.name = "BuildLayer"
	_layer.layer = CANVAS_LAYER
	add_child(_layer)
	bar = LevelBar.new()
	bar.build()
	for level: int in [3, 4]:
		bar.set_reachable(level, false)
	bar.level_chosen.connect(_on_level_chosen)
	_layer.add_child(bar)
	panel = BuildPanel.new()
	panel.configure(batch, catalog, _stock)
	panel.card_chosen.connect(_on_card_chosen)
	panel.confirm_requested.connect(confirm_all)
	panel.closed.connect(_on_closed)
	_layer.add_child(panel)
	_build_label()


func _build_label() -> void:
	"""UI-BUILD-010's size label beside the pointer: a small framed line, never taking the mouse."""
	_label_box = PanelContainer.new()
	_label_box.name = "PaintLabel"
	_label_box.theme = ThemeResource
	_label_box.theme_type_variation = &"WoodlandPanel"
	_label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_box.visible = false
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", LABEL_PX)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_box.add_child(_label)
	_layer.add_child(_label_box)


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(place)
	place()


func place() -> void:
	"""The bar and the panel at the HUD's layout for the window and the interface scale (demo_ui_scale.gd)."""
	if bar == null:
		return
	var size_px: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	if not _layout.compute_into(maxi(int(size_px.x), UiLayout.SUPPORTED_MIN_WIDTH),
			maxi(int(size_px.y), UiLayout.SUPPORTED_MIN_HEIGHT), DemoUiScale.percent, false, _geometry):
		return
	_minimap_was = minimap_shown()
	bar.place(_geometry, _minimap_was)
	panel.place(_geometry)
	_label_box.scale = Vector2(_geometry.scale, _geometry.scale)


func minimap_shown() -> bool:
	"""Whether the HUD's minimap frame shows (the bar sits above it, or above its restore control)."""
	var frame: Control = _shell.control_for(UiShell.ID_MINIMAP_FRAME) if _shell != null else null
	return frame == null or frame.is_visible_in_tree()


func _stock(good: StringName) -> int:
	"""What the settlement's stores hold, for the ledger (read only; nothing is reserved)."""
	return EconomySystem.stock_milli(good)


# --- opening and closing -------------------------------------------------------------------------------------------

func is_open() -> bool:
	"""Whether the panel is open."""
	return panel.is_open()


func open_panel() -> bool:
	"""Open the panel on the level shown (refused behind a modal or the stall banner). True when it is open."""
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	if not panel.is_open():
		_mark_reachable()
		panel.open_on(bar.shown_level(), bar.is_reachable(bar.shown_level()))
		_hold_hud()
		_apply_build_view()
		if is_inside_tree():
			get_viewport().gui_release_focus()
		_say.call(OPENED % LevelBar.level_name(bar.shown_level()))
	return true


func toggle_panel() -> bool:
	"""B or the Build command: open, or ask to close. True when the panel is open afterwards."""
	if panel.is_open():
		panel.request_close()
		return panel.is_open()
	return open_panel()


func _on_closed(kept: bool) -> void:
	"""The panel closed: the HUD's surfaces back, the actual World's level put away (the U view shows its own level
	again), the ghosts' stroke and label hidden."""
	_release_hud()
	_leave_build_view()
	_label_box.visible = false
	paint.refresh(-1, false)
	if kept and batch.pending_count() > 0:
		_say.call(CLOSED_KEPT)


func _mark_reachable() -> void:
	"""The bar's "no way in yet" marks: a level has a way in when a confirmed way down lands on it (the proof of
	concept's, decision 1912) or, conservatively, when any settlement excavation Site exists; every cell's ghost judges
	it exactly."""
	var sites: Object = orders.excavation_sites()
	var any: bool = sites != null and int(sites.get(&"_count")) > 0
	for level: int in range(1, LevelBar.LEVEL_DEEPEST + 1):
		bar.set_reachable(level, any or _landed_on(level))
	_marked_at = works.revision


func _landed_on(level: int) -> bool:
	"""Whether a confirmed way down lands on `level`."""
	for row: int in works.way_count():
		if works.way_level(row) + 1 == level:
			return true
	return false


# --- per frame -----------------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Follow the view (U), the minimap; hold the HUD; redraw the ghosts and label. Integer compares a frame;
	allocation only when something changed."""
	follow_view()
	if minimap_shown() != _minimap_was:
		place()
	var open: bool = panel.is_open()
	if open:
		_hold_hud()
	elif _holding:
		_release_hud()
	paint.refresh(bar.shown_level() if open else -1, open and (armed_type() >= 0 or way_down_armed()), way_down_armed())
	_refresh_furnish(open)
	_sync_label(open)
	_tick_works(_delta)


func _refresh_furnish(open: bool) -> void:
	"""The furniture drawn for the level shown (the armed piece's ghost at the cursor), and the rooms' lines handed to
	the panel."""
	var level: int = bar.shown_level() if open else -1
	var fitting_row: int = fitter.fitting_row() if fitting() else -1
	furnish.lines_shown = level >= 1 or panel.shown_tab() != BuildCatalog.TAB_ROOMS
	furnish.refresh(level, armed_item(), paint.cursor(), _turn, fitting_row)
	if open:
		panel.set_room_lines(furnish.rooms.lines_text())


func follow_view() -> void:
	"""While building, the bar decides and the view follows (U read as a choice); else the bar follows the legacy
	U view (decision 1871)."""
	if panel.is_open():
		_follow_build_view()
		return
	var shown: int = view_level()
	if shown != bar.shown_level():
		bar.set_level(shown)


func _follow_build_view() -> void:
	"""U pressed while building: off goes to the Surface, on goes to Level 1; then the view is kept as the bar says."""
	if _applied_level >= 0 and _tunnels.view.on != _applied_on:
		bar.set_level(LevelBar.LEVEL_SURFACE if not _tunnels.view.on else 1)
		_applied_level = -1
	if bar.shown_level() != panel.building_level():
		batch.cancel_stroke()
		panel.set_level(bar.shown_level(), bar.is_reachable(bar.shown_level()))
	_apply_build_view()


func _apply_build_view() -> void:
	"""Show what the bar's level is while building: an underground level's actual World (the U view on, drawing only
	it), or the surface view. Writes only when the level changed."""
	var level: int = bar.shown_level()
	if level == _applied_level:
		return
	_applied_level = level
	_special = -1
	var underground: bool = Paint.paintable(level)
	if _tunnels.view.on != underground:
		_tunnels.toggle_view()
	_applied_on = _tunnels.view.on
	if not underground:
		world.hide_view()
		return
	world_refusal = world.show_level(level)
	if world_refusal == &"" and not dug.has_kinds():
		dug.set_kinds(world.section_kinds())
	# The earth, the dug rooms and the ghosts (decision 1913); with no World to draw (review M4) the earth is plain.
	_tunnels.view.set_override_mask(BuildWorld.SHOWN_MASK)


func _leave_build_view() -> void:
	"""Building ended: the World's level hidden and the U view's own level back (the bar then follows it)."""
	world.hide_view()
	_tunnels.view.set_override_mask(-1)
	_applied_level = -1


func view_level() -> int:
	"""The level shown with the panel closed, in the bar's terms: a level 3/4 or Overview choice while the view is as
	it left it, else the U view's level, or the surface with it off."""
	var on: bool = _tunnels.view.on
	if _special >= 0 and on == _special_on:
		return _special
	if _special >= 0:
		_set_special(-1)
	return _tunnels.view.level if on else LevelBar.LEVEL_SURFACE


func _hold_hud() -> void:
	"""Hide the surfaces the panel replaces (recorded once per opening, re-hidden each frame: their owners may show
	them again)."""
	if not _holding:
		_holding = true
		_hidden_was.resize(_hide.size())
		for k: int in _hide.size():
			_hidden_was[k] = 1 if is_instance_valid(_hide[k]) and bool(_hide[k].get(&"visible")) else 0
	for node: Node in _hide:
		if is_instance_valid(node):
			node.set(&"visible", false)


func _release_hud() -> void:
	"""Give the hidden surfaces back as they were."""
	if not _holding:
		return
	_holding = false
	for k: int in mini(_hide.size(), _hidden_was.size()):
		if is_instance_valid(_hide[k]):
			_hide[k].set(&"visible", _hidden_was[k] == 1)


func _sync_label(open: bool) -> void:
	"""The paint label beside the pointer (or the cursor cell): the stroke's size and validity, or how to begin."""
	var type: int = armed_type() if open else -1
	var placing: bool = open and way_down_armed()
	_label_box.visible = type >= 0 or placing or (open and (piece_armed() or edge_armed()))
	if not _label_box.visible:
		return
	var label_key: int = batch.stroke_revision * 8 + (bar.shown_level() + 1 if placing else 0)
	if open and edge_armed():
		_sync_edge_label()
	elif open and piece_armed():
		_sync_piece_label()
	elif label_key != _seen_label:
		_seen_label = label_key
		_piece_label = Vector4i(0, 0, -1, -1)
		_label.text = batch.stroke_line().replace("; ", "\n") if batch.stroke_active() \
			else PLACE_HINT % Items.name_of(bar.shown_level()) if placing else ARMED_HINT % BuildCatalog.type_name(type)
		_label_box.accessibility_name = batch.stroke_line() if batch.stroke_active() else _label.text
		_label_box.reset_size()
	var at: Vector2 = _pointer if _pointer.is_finite() else paint.screen_of(paint.cursor(), bar.shown_level(),
		pick_lift())
	if at.is_finite():
		var view: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
		_label_box.position = label_position(at + LABEL_OFFSET, _label_box.size * _label_box.scale, view,
			panel.screen_rect())


func _sync_piece_label() -> void:
	"""The armed piece's words beside the pointer: "Place Hearth, turned once" and its validity at the cursor; worded
	again only when the cursor, the turn, the item or the batch moved."""
	var cursor: Vector2i = paint.cursor()
	var key: Vector4i = Vector4i(cursor.x, cursor.y, (bar.shown_level() * 4 + _turn) * 64 + armed_item(), batch.revision)
	var moved: Vector2i = Vector2i(works.revision, fittings.revision)
	if key == _piece_label and moved == _piece_label_moved:
		return
	_piece_label = key
	_piece_label_moved = moved
	_seen_label = -1
	var item: int = armed_item()
	var pieces: Furniture = batch.furniture()
	var judged: Array = pieces.judge(bar.shown_level(), pieces.anchor_for(item, _turn, cursor), _turn, item, -1)
	var turned: String = Furniture.turn_words(pieces.is_edge(item), _turn)
	_label.text = PIECE_LABEL % [Furniture.name_of(item), ", " + turned if not turned.is_empty() else "",
		Validity.line(int(judged[0]), String(judged[1]))]
	_label_box.accessibility_name = _label.text.replace("\n", "; ")
	_label_box.reset_size()


static func label_position(wanted: Vector2, drawn: Vector2, view: Vector2, avoid: Rect2) -> Vector2:
	"""Where the paint label stands: at `wanted`, kept 16 px inside the window, and lifted above the panel (`avoid`)
	rather than drawn over it."""
	var inset: Vector2 = Vector2(SAFE_INSET, SAFE_INSET)
	var at: Vector2 = wanted.clamp(inset, (view - drawn - inset).max(inset))
	if Rect2(at, drawn).intersects(avoid):
		at.y = maxf(avoid.position.y - drawn.y - LABEL_GAP, SAFE_INSET)
	return at


func label_text() -> String:
	"""What the paint label says (checks)."""
	return _label.text if _label_box.visible else ""


# --- the levels ----------------------------------------------------------------------------------------------------

func step_level(by: int) -> bool:
	"""PageDown (+1) or PageUp (-1): the bar's next level, or the canonical words at an end."""
	if bar.step(by):
		return true
	_say.call(Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.no_level_above() if by < 0 else Validity.no_level_below()))
	return false


func _on_level_chosen(level: int) -> void:
	"""The bar's choice: while building, the view follows it (`_apply_build_view`); else it is mapped onto the legacy
	U view as decision 1871 did (Levels 1/2 its levels, 3/4 nothing, Overview the surface)."""
	if panel.is_open():
		_follow_build_view()
		return
	_set_special(-1)
	match level:
		LevelBar.LEVEL_SURFACE, LevelBar.LEVEL_OVERVIEW:
			if _tunnels.view.on:
				_tunnels.toggle_view()
		_:
			if not _tunnels.view.on:
				_tunnels.toggle_view()
			if level <= 2:
				_tunnels.show_level(level)
	if (level == 3 or level == 4) and _tunnels.view.on:
		_set_special(level)
	elif level == LevelBar.LEVEL_OVERVIEW and not _tunnels.view.on:
		_set_special(level)
	follow_view()


func _set_special(level: int) -> void:
	"""Hold a level the legacy view cannot name itself (3, 4 or Overview) until the view changes under it."""
	_special = level
	_special_on = _tunnels.view.on
	_tunnels.view.set_unreached(level == 3 or level == 4)


# --- painting ------------------------------------------------------------------------------------------------------

func armed_type() -> int:
	"""The room type a stroke paints now, or -1: the panel open with a type chosen, on an underground level. (With no
	underground composed in the run the World cannot be drawn, `world_refusal` says why, and painting still works:
	Confirm all then says nothing can be ordered.)"""
	if _setup_refusal != &"" or not panel.is_open():
		return -1
	var level: int = bar.shown_level()
	return panel.paint_type() if Paint.paintable(level) or level == Mound.SURFACE else -1


func _begin_at(cell: Vector2i) -> bool:
	"""Start a stroke of the armed type at `cell` on the level shown."""
	var type: int = armed_type()
	if type < 0:
		return false
	paint.set_cursor(cell, bar.shown_level(), type)
	return batch.begin_stroke(type, bar.shown_level(), cell, panel.style())


func _finish() -> void:
	"""End the stroke: it joins the batch, or is dropped saying why."""
	var kind: int = batch.finish_stroke()
	if kind == Validity.KIND_NOT_POSSIBLE:
		_say.call(batch.last_dropped())
	elif kind >= 0:
		_say.call(panel.confirm_blocked() if not panel.confirm_blocked().is_empty() else Validity.line(kind, ""))


func confirm_all() -> void:
	"""Confirm all: the ways down, then every valid room, to the proof of concept's works (nothing is paid; decision
	1912); then a mole is sent to dig them."""
	if _blocked.is_valid() and bool(_blocked.call()):
		return
	var result: PackedInt32Array = batch.confirm_all(_submit_room, _submit_way_down, _submit_piece, _submit_edge)
	if result[0] > 0 and works.waiting() > 0:
		_send_mole()
	mound.send_worker()
	if fittings.waiting_below() > 0:
		_send_fitter()
	var first: int = batch.first_invalid()
	if first < 0:
		first = batch.first_refused()
	var words: String = ORDERED % [result[0], result[1]]
	if first >= 0:
		words += " -- %s: %s" % [BuildCatalog.type_name(batch.operation_type(first)), batch.operation_reason(first)]
	panel.refresh(true)
	_say.call(words)


func _submit_room(draft: Object, level: int, room_type: int) -> Dictionary:
	"""The proof of concept's order route for a room: its cells wait for the mole (free for now)."""
	var cells: PackedInt32Array = (draft.call(&"snapshot") as Dictionary).cells
	if level == Mound.SURFACE:
		return {"ok": mound.submit_room(cells, room_type), "error": Validity.outside()}
	return {"ok": works.order_room(level, cells, room_type), "error": Validity.outside()}


func _submit_way_down(level: int, cell: Vector2i) -> Dictionary:
	"""The proof of concept's order route for a way down: it and its landing wait for the mole."""
	return {"ok": works.order_way_down(level, cell), "error": Validity.outside()}


func _submit_edge(_level: int, cell: Vector2i, side: int, kind: int, colour: int, removal: bool) -> Dictionary:
	"""Decision 2002's order route for a Mound's door, window or removal (free for now)."""
	return mound.submit_edge(cell, side, kind, colour, removal)


func _submit_piece(level: int, anchor: Vector2i, turn: int, item: int) -> Dictionary:
	"""The Furnish tab's order route for a piece: it waits for a fitter (free for now; decision 1921)."""
	return {"ok": fittings.order(level, anchor, turn, item), "error": Validity.not_on_room()}


# --- the proof of concept's mole and visitors (decision 1912) -----------------------------------------------------

func _tick_works(delta: float) -> void:
	"""Every frame: the dug rooms drawn for the level shown (the cell being dug deepening), each figure shown only on
	its own level, the tags kept off each other, and -- every SEND_EVERY_S while cells wait and no mole is digging -- a
	mole sent again."""
	var shown: int = bar.shown_level() if panel.is_open() else -1
	var dig_cell: Vector3i = digger.digging_cell() if digging() else Dug.Earth.NO_CELL
	dug.refresh(shown, dig_cell)
	dug.earth.set_grid(shown >= 1 and panel.shown_tab() != BuildCatalog.TAB_DECOR)
	if digging():
		_show_dig(dig_cell)
	if works.revision != _marked_at:
		_mark_reachable()
	for k: int in _trips.size():
		_figures[k].visible = _trips[k].below() and shown >= 1 and _trips[k].at().x == shown and _still_on(_trips[k])
	_space_tags(shown)
	_send_in -= delta
	if _send_in <= 0.0 and works.waiting() > 0 and not digging():
		_send_in = SEND_EVERY_S
		_send_mole()
	_fit_in -= delta
	if _fit_in <= 0.0 and fittings.waiting_below() > 0 and not fitting():
		_fit_in = SEND_EVERY_S
		_send_fitter()
	mound.tick(delta, panel.is_open() and bar.shown_level() == Mound.SURFACE, armed_edge_kind())


func _show_dig(dig_cell: Vector3i) -> void:
	"""The cell being dug (none: x < 1) deepens, and a mole standing on it stands on its floor so far (review M2);
	anywhere else the mole stands on a dug floor."""
	var share: float = digger.dig_share()
	if dig_cell.x >= 1:
		dug.set_progress(share)
	var row: int = _trips.find(digger)
	var on_it: bool = row >= 0 and dig_cell.x >= 1 and digger.at() == dig_cell
	if row >= 0:
		_figures[row].set_sink(Dug.Earth.dug_depth_m(share) if on_it else Figure.SINK_M)


func _space_tags(shown: int) -> void:
	"""The level's tags and the figures' names kept off each other on screen (demo_build_tags.gd; names first); on the
	Surface, the Mounds' and the furniture's words (decision 2002)."""
	if shown < 0 or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return
	_collect_tags()
	_spacer.space(_camera, _tag_list)


func _collect_tags() -> void:
	"""The shown figures' names, then the level's shown tags, into `_tag_list` (reused)."""
	_tag_list.clear()
	for figure: Figure in _figures:
		if figure.visible:
			_tag_list.append(figure.tag())
	if bar.shown_level() == Mound.SURFACE:
		mound.shown_tags(_tag_list)
	else:
		dug.shown_tags(_tag_list)
	furnish.shown_tags(_tag_list)


func tag_overlaps() -> int:
	"""How many pairs of the level's tags and names sit on each other on screen now (checks)."""
	if not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return 0
	_collect_tags()
	return Tags.overlaps(_camera, _tag_list)


func digging() -> bool:
	"""Whether a mole is on its dig trip now."""
	return digger != null and _still_on(digger)


func _still_on(trip: BelowTask) -> bool:
	"""Whether a resident is still on `trip` (no other order took it)."""
	var row: int = _trips.find(trip) if trip != null else -1
	if row < 0 or _cast == null or _trip_actors[row] < 0:
		return false
	return (_cast.call(&"actor", _trip_actors[row]) as Node).get(&"brain").get(&"task") == trip


func _send_mole() -> bool:
	"""A mole to the Entrance to dig (see `_pick_mole`) -- only when no mole is digging, an Entrance exists and an
	ordered cell can be reached from it (review H4); each reason not to is said once, not every SEND_EVERY_S (M6)."""
	if digging() or way_in() < 0 or _cast == null:
		return false
	if works.next_dig(works.landing_of(way_in())).is_empty():
		_say_once(CUT_OFF % works.waiting())
		return false
	var mole: int = _pick_mole()
	if mole < 0:
		_say_once(NOBODY)
		return false
	var trip: BelowTask = _send(mole, BelowTask.MODE_DIG, Vector3i.ZERO)
	if not _still_on(trip):
		_say_once(NOBODY)
		return false
	digger = trip
	_said = ""
	_say.call(SENT % _name_of(mole) if _is_mole(mole) else NO_MOLE % _name_of(mole))
	return true


func fitting() -> bool:
	"""Whether a resident is on its trip fitting the furniture now."""
	return fitter != null and _still_on(fitter)


func _send_fitter() -> bool:
	"""A resident to the Entrance to fit the waiting furniture (see `_pick_fitter`) -- only when nobody is fitting, an
	Entrance exists and a waiting piece can be reached from it; why not is said once (decision 1921)."""
	if fitting() or way_in() < 0 or _cast == null or fittings.waiting_below() == 0:
		return false
	if fittings.next_fit(works, works.landing_of(way_in())).is_empty():
		_say_fit_once(FIT_CUT_OFF)
		return false
	var who: int = _pick_fitter()
	var trip: BelowTask = _send(who, BelowTask.MODE_FIT, Vector3i.ZERO) if who >= 0 else null
	if not _still_on(trip):
		_say_fit_once(NO_FITTER)
		return false
	fitter = trip
	_said_fit = ""
	_say.call(FITTER_SENT % _name_of(who))
	return true


func _say_fit_once(words: String) -> void:
	"""Say `words` unless they were the last thing said about fitting."""
	if words != _said_fit:
		_said_fit = words
		_say.call(words)


func _pick_fitter() -> int:
	"""The first selected resident not below, else the first resident free (on no task) who is not a mole -- moles
	dig -- else the first resident not below; -1 when nobody can go (decision 1921, a PROPOSAL)."""
	var selected: PackedInt32Array = PackedInt32Array(_selection.call()) if _selection.is_valid() else PackedInt32Array()
	for i: int in selected:
		if not _below_now(i):
			return i
	var anyone: int = -1
	for i: int in int(_cast.call(&"actor_count")):
		if _below_now(i):
			continue
		var free: bool = int((_cast.call(&"actor", i) as Node).get(&"brain").get(&"order")) != BrainScript.ORDER_TASK
		if free and not _is_mole(i):
			return i
		anyone = i if anyone < 0 else anyone
	return anyone


func _say_once(words: String) -> void:
	"""Say `words` unless they were the last thing this said about digging."""
	if words != _said:
		_said = words
		_say.call(words)


func _pick_mole() -> int:
	"""The first selected mole, else the first mole on no task, else the first mole not below on a visit (its routine
	task gives way, as any order's does); with no mole in the village (the art-free placeholders), any resident not
	below (decision 1912 P-1912-3). -1 when nobody can go."""
	var selected: PackedInt32Array = PackedInt32Array(_selection.call()) if _selection.is_valid() else PackedInt32Array()
	for i: int in selected:
		if _is_mole(i) and not _below_now(i):
			return i
	var any: int = -1
	var anyone: int = -1
	for i: int in int(_cast.call(&"actor_count")):
		if _below_now(i):
			continue
		anyone = i if anyone < 0 else anyone
		if not _is_mole(i):
			continue
		if int((_cast.call(&"actor", i) as Node).get(&"brain").get(&"order")) != BrainScript.ORDER_TASK:
			return i
		any = i if any < 0 else any
	return any if any >= 0 or _has_mole() else anyone


func _has_mole() -> bool:
	"""Whether any mole lives in the village."""
	for i: int in int(_cast.call(&"actor_count")):
		if _is_mole(i):
			return true
	return false


func _below_now(i: int) -> bool:
	"""Whether resident `i` is on one of the build panel's trips below, or building a Mound (decision 2002)."""
	var row: int = _trip_actors.find(i)
	return (row >= 0 and _still_on(_trips[row])) or mound.works_with(i)


func _is_mole(i: int) -> bool:
	"""Whether resident `i` is a mole."""
	return String((_cast.call(&"actor", i) as Node).get(&"species")) == MOLE


func _name_of(i: int) -> String:
	"""Resident `i`'s name."""
	return String((_cast.call(&"actor", i) as Node).get(&"display_name"))


func _send(i: int, mode: int, goal: Vector3i) -> BelowTask:
	"""Resident `i` on a trip below (a figure made for it, or reused from a finished trip)."""
	var row: int = _free_trip_row()
	var way: int = way_in()
	var site: Vector2 = mound.hatch_site(works.way_cell(way)) if way >= 0 else Vector2.INF
	var trip: BelowTask = BelowTask.new(works, _figures[row], _floors, _datum_xz(), mode, goal, _name_of(i), way, site)
	trip.use_fittings(fittings)
	_trips[row] = trip
	_trip_actors[row] = i
	(_cast.call(&"actor", i) as Node).get(&"brain").call(&"order_task", trip)
	return trip


func _free_trip_row() -> int:
	"""A trip row whose resident is no longer on it (its figure reused), else a new one."""
	for row: int in _trips.size():
		if not _still_on(_trips[row]):
			return row
	var figure: Figure = Figure.new()
	add_child(figure)
	_figures.append(figure)
	_trips.append(null)
	_trip_actors.append(-1)
	return _trips.size() - 1


func send_visitors(cell: Vector2i) -> int:
	"""The selected residents down into the dug cell `cell` on the level shown; how many were sent."""
	var level: int = bar.shown_level()
	var selected: PackedInt32Array = PackedInt32Array(_selection.call()) if _selection.is_valid() else PackedInt32Array()
	if _cast == null or way_in() < 0 or works.state(level, cell) != Works.OPEN:
		return 0
	for i: int in selected:
		_send(i, BelowTask.MODE_VISIT, Vector3i(level, cell.x, cell.y))
	if not selected.is_empty():
		_say.call(VISIT % _name_of(selected[0]))
	return selected.size()


func way_in() -> int:
	"""The confirmed Entrance residents go down by: the first whose way can be reached -- off the Mounds, or a hatch
	on a dug Mound room's floor whose door is fitted (decision 2002) -- or -1."""
	for row: int in works.way_count():
		if works.way_level(row) == 0 and mound.hatch_ready(works.way_cell(row)):
			return row
	return -1


func piece_armed() -> bool:
	"""Whether a click places a piece of furniture now (the panel open, an item card chosen, the Surface -- a Mound
	room's floor, decision 2002 -- or levels 1-4 shown)."""
	var level: int = bar.shown_level()
	return _setup_refusal == &"" and panel.is_open() and panel.piece_armed() \
		and (Paint.paintable(level) or level == Mound.SURFACE)


func edge_armed() -> bool:
	"""Whether a click places a Mound's front door or window now (decision 2002: its card chosen, a level shown)."""
	return _setup_refusal == &"" and panel.is_open() and panel.edge_armed() \
		and bar.shown_level() <= LevelBar.LEVEL_DEEPEST


func armed_edge_kind() -> int:
	"""The door or window a click places now (build_mound.gd KIND_*; -1: none)."""
	return panel.armed_edge_kind() if edge_armed() else -1


func ground_point(screen: Vector2) -> Vector2:
	"""Where the view ray through `screen` meets the ground (world x, z; INF off it)."""
	if not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return Vector2.INF
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var direction: Vector3 = _camera.project_ray_normal(screen)
	if direction.y >= -0.000001:
		return Vector2.INF
	var hit: Vector3 = origin + direction * (-origin.y / direction.y)
	return Vector2(hit.x, hit.z)


func _edge_at_screen(screen: Vector2) -> Vector3i:
	"""The edge a click at `screen` names: on the Surface the Mound's outer edge nearest the ground point; below it the
	nearest side of the cell under the pointer (a window there is refused in words)."""
	var level: int = bar.shown_level()
	if level == Mound.SURFACE:
		var at: Vector2 = ground_point(screen)
		return mound.edge_near(at) if at.is_finite() else MoundHost.NO_EDGE
	var hit: Paint.WorldTool.Pick = paint.pick(screen, level, pick_lift())
	return Vector3i(hit.cell.x, hit.cell.y, 0) if hit.ok else MoundHost.NO_EDGE


func _place_edge(edge: Vector3i, at: Vector2, keep: bool = false) -> bool:
	"""A click with a door or window armed on `edge` (see the header); said in words. False with nothing to place."""
	if edge == MoundHost.NO_EDGE:
		return false
	var kind: int = mound.place(bar.shown_level(), edge, armed_edge_kind(), panel.door_colour(), at)
	if kind == Validity.KIND_CAN_BUILD:
		_say.call("%s %s" % [Validity.glyph(kind), batch.last_step_words()])
		if not keep:
			panel.clear_choice()
	elif kind >= 0:
		_say.call(batch.last_dropped())
	return kind >= 0


func _sync_edge_label() -> void:
	"""The armed door's or window's words beside the pointer: its judgement on the edge under it, or how to begin."""
	var words: String = mound.hover_words if mound.hover != MoundHost.NO_EDGE \
		else EDGE_HINT % Mound.kind_name(armed_edge_kind())
	if words != _label.text:
		_label.text = words
		_label_box.accessibility_name = words.replace("\n", "; ")
		_label_box.reset_size()
	_seen_label = -1


func armed_item() -> int:
	"""The item a click places now (-1: none)."""
	return panel.armed_item() if piece_armed() else -1


func piece_turn() -> int:
	"""The armed piece's quarter turns, 0-3 (R / Shift+R)."""
	return _turn


func rotate_piece(by: int) -> int:
	"""Turn the armed piece `by` quarter turns (R: +1, Shift+R: -1); its turns now."""
	_turn = posmod(_turn + by, Furniture.ROTATIONS)
	return _turn


func put_down_piece() -> bool:
	"""A right click with a piece armed puts its card down (a PROPOSAL, decision 1921: UI-BUILD's input table names no
	way to); false when none was armed."""
	if not piece_armed():
		return false
	panel.clear_choice()
	return true


func _place_piece(cell: Vector2i, keep: bool = false) -> bool:
	"""Place the armed piece with the cursor at `cell` on the level shown; it joins the batch (the card put down,
	unless `keep`: Shift), or is dropped saying why. False when nothing was tried (a stroke in progress)."""
	var item: int = armed_item()
	var kind: int = batch.place_piece(bar.shown_level(), batch.furniture().anchor_for(item, _turn, cell), _turn, item)
	if kind < 0:
		return false
	if kind != Validity.KIND_CAN_BUILD:
		_say.call(batch.last_dropped())
		return true
	_say.call("%s %s placed" % [Validity.glyph(kind), Furniture.name_of(item)])
	if not keep:
		panel.clear_choice()
	return true


func way_down_armed() -> bool:
	"""Whether a click places a way down now (the panel open, its card chosen, a level with one shown)."""
	return _setup_refusal == &"" and panel.is_open() and panel.way_down_armed() and bar.shown_level() <= Items.DEEPEST_TOP


func _place_way_down(cell: Vector2i, keep: bool = false) -> bool:
	"""Place the chosen way down at `cell` on the level shown; it joins the batch (the card put down, unless `keep`:
	Shift, UI-BUILD's "keeps the item for another"), or is dropped saying why."""
	var kind: int = batch.place_item(bar.shown_level(), cell)
	if kind == Validity.KIND_NOT_POSSIBLE:
		_say.call(batch.last_dropped())
		return true
	if kind >= 0:
		_say.call(Validity.line(kind, batch.item_reason(batch.items().count() - 1)))
		if not keep:
			panel.clear_choice()
	return kind >= 0


# --- input ---------------------------------------------------------------------------------------------------------

func takes_before_gui(event: InputEvent) -> bool:
	"""Before the HUD: the level keys (everywhere), and a stroke's motion and release (so a drag ending over the HUD
	still ends here) and the keyboard's Enter in the world. True when taken."""
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	if _level_key(event):
		return true
	if not panel.is_open():
		return false
	if batch.stroke_active() and _stroke_pointer(event):
		return true
	return _world_enter(event)


func _level_key(event: InputEvent) -> bool:
	"""PageUp / PageDown (`level_up` / `level_down`, exactly: Alt+PageUp is the pitch); a held key's repeats are taken
	and do nothing."""
	var up: bool = event.is_action_pressed(&"level_up", true, true)
	if not up and not event.is_action_pressed(&"level_down", true, true):
		return false
	if not event.is_echo():
		step_level(-1 if up else 1)
	return true


func _stroke_pointer(event: InputEvent) -> bool:
	"""The stroke follows the pointer and ends on the left release, wherever it is."""
	if event is InputEventMouseMotion:
		_pointer = (event as InputEventMouseMotion).position
		var hit: Paint.WorldTool.Pick = paint.pick(_pointer, bar.shown_level())
		if hit.ok:
			paint.set_cursor(hit.cell, bar.shown_level(), armed_type())
			batch.extend_stroke(hit.cell)
		return true
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_finish()
		return true
	return false


func _world_enter(event: InputEvent) -> bool:
	"""Enter with a type armed and no control focused: the first corner, then the second (the keyboard's paint)."""
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _focused() \
			or (armed_type() < 0 and not way_down_armed() and not piece_armed() and not edge_armed()):
		return false
	if key.keycode != KEY_ENTER and key.keycode != KEY_KP_ENTER:
		return false
	if edge_armed():
		var at: Vector2i = paint.cursor()
		return _place_edge(Vector3i(at.x, at.y, _turn), Vector2(_datum_xz()) / 1024.0 + Vector2(at) + Vector2(0.5, 0.5),
			key.shift_pressed)
	if piece_armed():
		return _place_piece(paint.cursor(), key.shift_pressed)
	if way_down_armed():
		_place_way_down(paint.cursor(), key.shift_pressed)
		return true
	if not batch.stroke_active():
		_pointer = Vector2.INF
		_begin_at(paint.cursor())
	else:
		_finish()
	return true


func _focused() -> bool:
	"""Whether a control holds the focus (Enter is then its own)."""
	return is_inside_tree() and get_viewport().gui_get_focus_owner() != null


func handle_input(event: InputEvent) -> bool:
	"""After the HUD: B, and the panel's keys and world clicks (see KEYS). True when taken."""
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	if event.is_action_pressed(&"open_build", false, true):
		toggle_panel()
		return true
	if not panel.is_open():
		return false
	if event is InputEventKey:
		return _panel_key(event as InputEventKey)
	if event is InputEventMouseButton:
		return _panel_click(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		_hover((event as InputEventMouseMotion).position)
	return false


func _panel_key(key: InputEventKey) -> bool:
	"""Escape, the tab cycle, Undo / Redo, and the arrows' cell cursor."""
	if not key.pressed:
		return false
	if key.keycode == KEY_ESCAPE and not key.echo:
		return panel.escape()
	if key.is_action_pressed(&"ui_tab_next", false, true) or key.is_action_pressed(&"ui_tab_previous", false, true):
		panel.cycle_tab(not key.shift_pressed)
		return true
	if key.is_action_pressed(&"tool_redo", true, true):
		if not batch.stroke_active():
			batch.redo()
		return true
	if key.is_action_pressed(&"tool_undo", true, true):
		batch.undo()
		return true
	if (piece_armed() or edge_armed()) and key.is_action_pressed(&"placement_rotate", false, true):
		rotate_piece(-1 if key.shift_pressed else 1)
		return true
	return _arrow(key)


func _arrow(key: InputEventKey) -> bool:
	"""With a type armed, an arrow moves the cell cursor one cell relative to the camera and drags a keyboard stroke
	with it."""
	if (armed_type() < 0 and not piece_armed() and not edge_armed()) or not ARROW_KEYS.has(key.keycode) \
			or key.shift_pressed \
			or key.ctrl_pressed or key.alt_pressed:
		return false
	_pointer = Vector2.INF
	var forward: Vector3 = -_camera.global_transform.basis.z if is_instance_valid(_camera) else Vector3.FORWARD
	var cell: Vector2i = paint.cursor() + arrow_step(key.keycode, forward)
	paint.set_cursor(cell, bar.shown_level(), armed_type())
	batch.extend_stroke(cell)
	return true


static func arrow_step(keycode: int, forward: Vector3) -> Vector2i:
	"""P-B10 (b): Up moves one cell the way the camera looks, snapped to the grid's nearer axis (a tie goes to z);
	Right a quarter turn clockwise from it seen from above; Down and Left the opposites. Vector2i(0, 0) for another key."""
	var up: Vector2i = Vector2i(1 if forward.x > 0.0 else -1, 0) if absf(forward.x) > absf(forward.z) \
		else Vector2i(0, -1 if forward.z <= 0.0 else 1)
	var right: Vector2i = Vector2i(-up.y, up.x)
	match keycode:
		KEY_UP:
			return up
		KEY_DOWN:
			return -up
		KEY_RIGHT:
			return right
		KEY_LEFT:
			return -right
	return Vector2i.ZERO


func _panel_click(button: InputEventMouseButton) -> bool:
	"""A left press on the floor begins a stroke; a right press cancels one in progress."""
	if not button.pressed:
		return false
	if button.button_index == MOUSE_BUTTON_RIGHT:
		return batch.cancel_stroke() or put_down_piece() or _visit_at(button.position)
	if button.button_index == MOUSE_BUTTON_LEFT and edge_armed():
		_pointer = button.position
		return _place_edge(_edge_at_screen(button.position), ground_point(button.position), button.shift_pressed)
	if button.button_index == MOUSE_BUTTON_LEFT and piece_armed():
		var on_floor: Paint.WorldTool.Pick = paint.pick(button.position, bar.shown_level(), pick_lift())
		_pointer = button.position
		return on_floor.ok and _place_piece(on_floor.cell, button.shift_pressed)
	if button.button_index != MOUSE_BUTTON_LEFT or (armed_type() < 0 and not way_down_armed()):
		return false
	var hit: Paint.WorldTool.Pick = paint.pick(button.position, bar.shown_level())
	_pointer = button.position
	if hit.ok and way_down_armed():
		return _place_way_down(hit.cell, button.shift_pressed)
	return hit.ok and _begin_at(hit.cell)


func _visit_at(screen: Vector2) -> bool:
	"""A right click on a dug cell of the level shown sends the selected residents down into it (picked on the dug
	pit's floor, where the player sees it: decision 1913)."""
	if bar.shown_level() < 1:
		return false
	var hit: Paint.WorldTool.Pick = paint.pick(screen, bar.shown_level(), -Dug.Earth.DEPTH_U)
	return hit.ok and send_visitors(hit.cell) > 0


func _hover(at: Vector2) -> void:
	"""The cursor cell follows the pointer over the floor (not taken: the hover ring still follows too)."""
	_pointer = at
	if edge_armed():
		mound.set_hover(bar.shown_level(), _edge_at_screen(at), armed_edge_kind(), panel.door_colour(), ground_point(at))
	if armed_type() < 0 and not way_down_armed() and not piece_armed() and not edge_armed():
		return
	var hit: Paint.WorldTool.Pick = paint.pick(at, bar.shown_level(), pick_lift())
	if hit.ok:
		paint.set_cursor(hit.cell, bar.shown_level(), armed_type())


func centre_cursor() -> void:
	"""Put the cell cursor under the middle of the screen (the keyboard's start)."""
	if not is_inside_tree():
		return
	var hit: Paint.WorldTool.Pick = paint.pick(get_viewport().get_visible_rect().size / 2.0, bar.shown_level(),
		pick_lift())
	if hit.ok:
		paint.set_cursor(hit.cell, bar.shown_level(), armed_type())
	_pointer = Vector2.INF


func pick_lift() -> int:
	"""Where the cursor is picked: on the dug pits' floor while a piece is armed (where it will stand), else on the
	paint plane."""
	return -Dug.Earth.DEPTH_U if piece_armed() and bar.shown_level() >= 1 else 0


# --- the cards -----------------------------------------------------------------------------------------------------

func _on_card_chosen(card: BuildCatalog.Card) -> void:
	"""A room type or a way down arms the world (the cursor to the screen's middle); a locked card is only shown."""
	if card.kind != BuildCatalog.CARD_TOOL and card.usable():
		centre_cursor()
