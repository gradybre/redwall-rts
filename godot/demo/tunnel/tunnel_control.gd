extends Node3D
## The Dig tool: player-laid tunnels in the live demo. Decisions 0196 (live demo) and 0208 (the network
## graph and the B tool; design docs/design/underground_revamp.md §2 "Planning" and §4). Presentation only:
## the tunnels shape the demo cast's walks, never the simulation (MOVE-G01..05 are open).
##
## CONTROLS (demo_command.gd hands every event here first; Enter, and a drag's motion and release, are read
## in its `_input`, before the HUD, so they can never press or be lost to a HUD control):
##   B (or T, or "Dig tunnel" in the Demo party panel)   the Dig tool: the view goes underground (the
##                                         cutaway, tunnel_view.gd) and back to what it was when the tool
##                                         closes; again: close it. B was the HUD's Build key, locked in the
##                                         demo (its command strip says so); U stays the view's own switch.
##   in the tool:  drag (left)          lay a piece: press where it starts, release where it ends -- the
##                                      piece is dug at once if it may be; Shift while dragging drops a bend
##                                      at the pointer
##                 left clicks          or lay it point by point: the start, each bend, the end
##                 Enter / right click  dig the piece laid        Backspace   take back the last point
##                 Esc                  drop the piece laid; with none, close the tool
##   right click a dig's start with a digger selected:
##                    the segment it is digging   nothing changes: it keeps digging (and says so)
##                    a paused or waiting one     it goes to dig that -- pausing what it was digging, with
##                                                all its progress kept
##   U                                  underground view (tunnel_view.gd: a layer cutaway, decision 0206);
##                                      U again puts back the notice the view replaced. In it, every click
##                                      lands on the level's floor (the plane the cutaway shows)
## The tool stays open after a piece is dug, for the next: pieces queue behind a digger's current dig as
## THE JOB LIST (underground_graph.gd). The camera's own keys and the wheel are never taken.
##
## SNAPPING AND THE GHOST (tunnel_plan.gd SNAPS). A start or end laid on or near the network snaps to it: an
## existing junction, or a point on a bore's side where a new junction will be cut; anywhere else it opens a
## new mouth. While laying, the piece is drawn to the pointer as its drawn centreline curves (a GHOST,
## tunnel_overlay.gd): chalk-cream while it may be dug, clay with the reason beside the pointer when it may
## not (MOVE-REQ-018: in words, not colour alone); a snap target glows brass; and the COST READOUT
## (dig_readout.gd) follows the pointer: length, quanta, hours for the crew that would dig it, spoil, and
## the ground that slows or weakens it.
##
## WHO DIGS (decision 0208: the digging skill, dig_skills.gd, replaces the mole-only rule). Anybeast whose
## body fits a standard bore digs. The piece's digger is the first selected resident who can dig, else the
## village's most skilled; busy with another dig, it digs this one next (the job list). The rest of the
## selection joins its crew when the dig starts now.
##
## WHAT A PIECE MUST CLEAR is the plan's (tunnel_plan.gd THE WHOLE PIECE) -- and, on digging, nobody
## standing on a new entrance, and a way for the digger to its start (on the surface, or through the
## network). Accepted, its heaps are placed (tunnel_heaps.gd), the world's grass is cleared from its holes,
## heaps and route, and every segment it split hands its walkers and hazards to the halves
## (tunnel_works.gd `after_splits`).
##
## THE NOTICE FOLLOWS THE TUNNELS. Every frame the tool compares the network's revision with the one it
## last saw, and says what changed: a dig through, paused (at N% of its piece, and how to resume it), kept
## as a plan its digger could not reach, or dropped before any ground was broken -- so the panel never keeps
## saying "Digging" about a dig that has stopped. A freed mouth's heap stops being an obstacle.
##
## WHO FITS. At setup each resident's body is recorded -- the height the cast draws it at and its body
## radius, in integer u -- and its fit is judged per segment from it (underground_graph.set_body).
##
## ROOMS (decision 0209). In the tool, H or C (or the party panel's "Burrow home (H)" / "Root cellar (C)")
## opens the ROOM TOOL for a burrow home or a root cellar (demo/burrow/room_tool.gd): a ghost room follows the
## pointer, R turns it, a click lays it with a passage to the network proposed (Shift+click: standalone), and
## Esc goes back to laying tunnels. A room is dug by the same diggers, crews and job list as a tunnel. A tunnel
## laid to a room's socket joins it there (tunnel_plan.gd ROOMS).
##
## THE EXTENSIONS (tunnel_ext.gd: weather, hauling, upgrades, hazards, finds, ground, crews, threats) are
## built here and handed what this tool does not take.
##
## THE SECOND LEVEL (decision 0212). In the U view, PgUp and PgDn show level 1 and level 2 (tunnel_view.gd THE
## LEVELS) -- read before the HUD and the camera (`takes_before_gui`), so in the U view they never zoom; on the
## surface they stay the camera's zoom keys (the wheel zooms everywhere), and U stays the view's switch. The Dig
## tool lays pieces and rooms on the level shown: a piece on level 2 starts on its network (a stair's or ramp's
## foot, a junction, a bore) and may end blind. L in the tool lays a LINK down between the levels instead -- L once
## a RAMP, again STAIRS, again back to tunnels: click (or press) its head on level 1's network and release (or
## click) its foot, which snaps onto level 2's network or ends blind there; the ghost's words give its run and
## slope, quanta, hours, spoil, grade and ground, or the refusal in words (tunnel_plan.gd LEVELS AND LINKS). Both
## points are picked on the shown level's floor; each snaps onto its own level. With the U view off the tool lays on
## level 1 (`laying_level`): switching the view with U while laying re-lays on the level it now shows.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const ReadoutScript := preload("res://demo/tunnel/dig_readout.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const ViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const ExtScript := preload("res://demo/tunnel/tunnel_ext.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const RoomToolScript := preload("res://demo/burrow/room_tool.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FarmCatalog := preload("res://demo/farm/farm_catalog.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

## A right click this close to a dig's start is about that dig.
const RESUME_PICK_M: float = 1.1
## A mouth keeps this far (plus MOUTH_CLEAR_U) from a work spot, and this from another mouth.
const SPOT_KEEP_U: int = 512
const MOUTH_KEEP_U: int = 768
## The grass cleared along a new piece's route, either side (the mound's width).
const COVER_CLEAR_M: float = 0.6
## A press moved this far (px) is a drag; the ghost is checked again once the pointer moves this far (m).
const DRAG_PX: float = 8.0
const GHOST_STEP_M: float = 0.1
const PLAN_FIRST: String = "Dig: drag from where the tunnel starts to where it ends, or click its points -- start on a tunnel to branch off it"
const PLAN_MORE: String = "Dig: %s, %s -- click: add · Enter / right-click: dig · Backspace: undo · Esc: drop"
const PLAN_CANCELLED: String = "Dig tool closed"
const PLAN_DROPPED: String = "Piece dropped -- lay another, or Esc to close the tool"
## What a dig costs through its own ground (at one F1000 worker; a crew is quicker).
const DIG_STARTED: String = "Digging a %s tunnel: %d m³ to cut, %d U of spoil, about %d s"
const DIG_QUEUED: String = "Queued a %s tunnel: %s digs it after its present dig"
## A link's (see THE SECOND LEVEL): its kind for "tunnel", e.g. "Digging a 5.0 m stairs down".
const LINK_WORD: Array[String] = ["tunnel", "ramp down", "stairs down"]
const DIG_RESUMED: String = "Resuming the tunnel at %d%%"
const DIG_KEPT: String = "Already digging this tunnel (%d%%)"
## A tunnel's bore fits the small; a room and its front door or hatch fit everybeast (decision 0209), and the
## words say which is which.
const DIG_OPEN: String = "Tunnel open: mice, moles and squirrels walk its bore; otters and badgers need it widened -- rooms and their doors take everybeast"
const DIG_PAUSED: String = "Tunnel paused at %d%% — right-click where it starts with a digger to resume"
const DIG_UNREACHED: String = "The digger couldn't reach the start — tunnel paused at %d%%; right-click where it starts with a digger to resume"
const DIG_DROPPED: String = "Dig called off before any ground was broken"
const REFUSED: String = "Can't dig: %s"
## The tools' action cards (tool_card_into).
const TOOL_NEEDS: String = "a resident who fits a bore (a mole, a mouse or a squirrel); no stores (the pointer's readout shows the work, spoil and brace cost)"
const TOOL_NOBODY: String = "nobody can dig: select a mole, a mouse or a squirrel"
const TOOL_FREE: String = "the village's most skilled free digger"
const TOOL_BUSY: String = "the most skilled digger: it digs this after its present dig"
## The card's code when no piece at all could fit (`begin_plan`'s capacity gate, decision 0361's F08).
const TOOL_FULL_CODE: String = "NETWORK_FULL"
const VIEW_ON: String = "Underground view (U to return)"
const LEVEL_SHOWN: String = "Underground view: level %d of 2 -- PgUp / PgDn to switch, U to return"
const LINK_FIRST: String = "Dig %s down: press on the first level's network where it starts and release where its foot lands on the second -- L: %s · Esc: back to tunnels"
const LINK_OPEN: Array[String] = ["", "Ramp down open: a walk down to the second level at 1:2.5", "Stairs down open: 16 timber risers down to the second level -- steep, and slower to climb"]
const ROOM_OPEN: Array[String] = ["", "Burrow home dug: everybeast fits and stands upright in it -- in at its round door or a tunnel",
	"Root cellar dug: the pantry stores harvests in it; everybeast stands in it, in at its hatch"]

var planning: bool = false
## The link the tool lays now (tunnel_rules.gd LINK_*; LINK_NONE: tunnels) -- see THE SECOND LEVEL.
var link_kind: int = Rules.LINK_NONE
## The pieces said to be dug through in this look at the network (so each is said once).
var _opened: PackedInt32Array = PackedInt32Array()
var plan: PlanScript = PlanScript.new()
var network: GraphScript = null
var overlay: OverlayScript = null
var view: ViewScript = null
var ext: ExtScript = null
## The room tools (see ROOMS).
var room: RoomToolScript = null

var _cast: DemoCastScript = null
var _camera: Camera3D = null
var _space: CastSpaceScript = null
var _world: DemoWorldScript = null
var _selection: Callable = Callable()
var _mark: Callable = Callable()
var _notice: Callable = Callable()
var _planner: int = 0
var _notice_about: Callable = Callable()
var _bounds_u: Rect2i = Rect2i()
var _circles_u: PackedInt32Array = PackedInt32Array()
var _spots_u: PackedInt32Array = PackedInt32Array()
var _under_u: PackedInt32Array = PackedInt32Array()
var _ground: Vector2 = Vector2.ZERO
var _cursor: Vector2 = Vector2.ZERO
var _has_cursor: bool = false
var _ref: PackedInt32Array = PackedInt32Array([-1, 0, -1])
var _snap: PackedInt32Array = PackedInt32Array([0, -1, 0, 0])
var _route: PackedVector2Array = PackedVector2Array()
var _last_notice: String = ""
var _before_view: String = ""
## Whether the U view was on when the tool opened (it goes back to that on closing).
var _view_before_tool: bool = false
var _pressing: bool = false
var _dragging: bool = false
var _press_laid: bool = false
var _press_screen: Vector2 = Vector2.ZERO
var _ghost_at: Vector2 = Vector2.INF
var _ghost_refusal: int = Rules.REFUSE_NONE
var _ghost_words: String = ""
var _seen_revision: int = -1
var _seen_phase: PackedByteArray = PackedByteArray()
var _seen_generation: PackedInt32Array = PackedInt32Array()
var _seen_reason: PackedByteArray = PackedByteArray()
var _seen_mouth: PackedInt32Array = PackedInt32Array()


func configure(cast: DemoCastScript, camera: Camera3D, selection: Callable, mark: Callable, notice: Callable,
		services: ServicesScript = null) -> void:
	"""Plan and draw tunnels for this cast, picking through this camera. `selection` returns the selected
	actor indices; `mark(at: Vector3, accepted: bool)` drops an order marker; `notice(text)` shows a line in
	the party panel; `services` are the demo's shared weather, water and notice feed (none: the extensions
	make a set of their own)."""
	name = "TunnelControl"
	_cast = cast
	_camera = camera
	_space = cast.space()
	network = _space.tunnels
	_selection = selection
	_mark = mark
	_notice = notice
	var bounds := cast.bounds()
	_bounds_u = Rect2i(Rules.to_u(bounds.position.x), Rules.to_u(bounds.position.y), Rules.to_u(bounds.size.x),
		Rules.to_u(bounds.size.y))
	_refresh_clearances()
	_describe_cast()
	_build_parts(cast, camera, selection, mark, services)
	_seen_phase.resize(Rules.MAX_SEGMENTS)
	_seen_generation.resize(Rules.MAX_SEGMENTS)
	_seen_reason.resize(Rules.MAX_SEGMENTS)
	_seen_mouth.resize(Rules.MAX_MOUTHS)
	_sync_seen()


func _build_parts(cast: DemoCastScript, camera: Camera3D, selection: Callable, mark: Callable,
		services: ServicesScript) -> void:
	"""The overlay, the extensions and the underground view over their ground and water; everything the view
	draws registers for its prewarm (decision 0206)."""
	overlay = OverlayScript.new()
	add_child(overlay)
	overlay.configure(network, _space, cast.clock)
	ext = ExtScript.new()
	add_child(ext)
	ext.configure(cast, camera, overlay, _bounds_u, selection, mark, _say, services)
	plan.water_crossing = ext.works.water.crosses_water
	plan.job_busy = ext.works.jobs.has_job
	view = ViewScript.new()
	add_child(view)
	view.configure(camera, ext.works.ground, ext.works.water)
	overlay.set_view(view.cap, view.prewarm, view.caps[Rules.LEVEL_2])
	overlay.set_calendar(services.calendar if services != null else null)
	ext.set_view(view)
	DemoActorScript.register_marker(view.prewarm)
	room = RoomToolScript.new()
	add_child(room)
	room.configure(self)
	room.register(view.prewarm)


func set_world(world: DemoWorldScript) -> void:
	"""The world whose buildings no tunnel may pass under (their footings and its trees' roots drawn on the
	underground view's cap) and whose grass a new tunnel clears."""
	_world = world
	view.set_world(world, world.building_obstacles(), world.trees())
	overlay.bores.set_trees(world.trees())
	_under_u = Rules.circles_to_u(PackedVector3Array(world.building_obstacles()))
	ext.set_world(world, _under_u)


func _describe_cast() -> void:
	"""Each resident's bore fit, from its drawn height and body radius."""
	for i in _cast.actor_count():
		var actor := _cast.actor(i) as DemoActorScript
		network.set_body(actor.brain.index, Rules.to_u(actor.height_m), Rules.to_u(actor.brain.radius))


func is_digger(actor_index: int) -> bool:
	"""Whether this actor can dig (its body fits a standard bore; decision 0208)."""
	return ext.can_dig[actor_index] == 1


func _brain(actor_index: int) -> BrainScript:
	"""An actor's brain."""
	return (_cast.actor(actor_index) as DemoActorScript).brain


func _say(text: String) -> void:
	"""Show a line in the party panel, and remember it (the underground view puts it back)."""
	_last_notice = text
	_notice.call(text)


func set_notice_about(notice_about: Callable) -> void:
	"""`notice_about(text: String, who: int)`: a line about one resident -- a tunnel's own news, said whoever
	is selected when it happens (demo_command.gd `say_about`; decision 0205)."""
	_notice_about = notice_about


func _say_about(text: String, slot: int) -> void:
	"""A dig's own news, kept for the resident it concerns: its digger, else the last planning digger."""
	var who: int = network.piece_digger[network.piece[slot]] if network.piece_digger[network.piece[slot]] >= 0 else _planner
	if not _notice_about.is_valid():
		_say(text)
		return
	_last_notice = text
	_notice_about.call(text, who)


func notice() -> String:
	"""The line this tool last showed."""
	return _last_notice


# --- input ----------------------------------------------------------------------------------

func handle_input(event: InputEvent) -> bool:
	"""Apply one event; true when it was a tunnel input (and so consumed)."""
	if _level_key(event):
		return true
	if planning:
		return _plan_input(event)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _on_key(event as InputEventKey)
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		return _try_resume(button.position)
	return false


static func key_of(event: InputEventKey) -> Key:
	"""The event's key: its physical key when it has one, else its logical key."""
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


static func is_confirm_key(event: InputEvent) -> bool:
	"""Whether `event` presses Enter (either one) -- what digs the piece being laid."""
	var key := event as InputEventKey
	return key != null and key.is_pressed() and not key.is_echo() \
			and (key_of(key) == KEY_ENTER or key_of(key) == KEY_KP_ENTER)


func takes_before_gui(event: InputEvent) -> bool:
	"""Whether the tool must see `event` before any HUD control: Enter while laying, and a drag's motion and
	release (so a drag ending over the HUD still ends here)."""
	if view.on and is_level_key(event):
		return true
	if not planning:
		return false
	if is_confirm_key(event):
		return true
	var button := event as InputEventMouseButton
	if _pressing and button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		return true
	return _pressing and event is InputEventMouseMotion


static func level_step(event: InputEvent) -> int:
	"""The level step an unmodified PgDn (+1) or PgUp (-1) press asks for (0: neither; see THE SECOND LEVEL)."""
	var key := event as InputEventKey
	if key == null or not key.is_pressed() or key.is_echo() or _modified(key):
		return 0
	if key_of(key) == KEY_PAGEDOWN:
		return 1
	return -1 if key_of(key) == KEY_PAGEUP else 0


static func is_level_key(event: InputEvent) -> bool:
	"""Whether `event` presses PgUp or PgDn, unmodified, its key's repeats too (Alt+PgUp/PgDn stay the camera's
	pitch): in the U view every one is the tool's, so a held key never reaches the camera's zoom."""
	var key := event as InputEventKey
	return key != null and key.is_pressed() and not _modified(key) \
			and (key_of(key) == KEY_PAGEDOWN or key_of(key) == KEY_PAGEUP)


func _level_key(event: InputEvent) -> bool:
	"""In the U view, a PgUp or PgDn press: show the level up or down (see THE SECOND LEVEL); its repeats are taken
	and do nothing. True when taken."""
	if not view.on or not is_level_key(event):
		return false
	var step := level_step(event)
	if step != 0:
		show_level(view.level + step)
	return true


func show_level(level: int) -> void:
	"""Show `level` in the U view; the tool, open, lays on it now (a piece half laid on the other is dropped)."""
	if not view.set_level(level):
		return
	_say(LEVEL_SHOWN % view.level)
	_relay()


func reveal_tunnel(slot: int) -> void:
	"""Show the level segment `slot` is seen on, when the U view is on and shows a level it is not on (the news's "Go
	to" on a level-2 tunnel, decision 0331 with 0212). A link is seen from both levels, so it never switches."""
	if not view.on or slot < 0 or slot >= network.seg_level.size() or ext.actions.on_level(slot, view.level):
		return
	show_level(network.seg_level[slot])


func laying_level() -> int:
	"""The level the tool lays on: the U view's, or with the view off level 1 (see THE SECOND LEVEL)."""
	return view.level if view.on else Rules.TOP_LEVEL


func _relay() -> void:
	"""The level laid on changed: the tool, open, drops a piece half laid and lays on `laying_level` now."""
	if not planning:
		return
	plan.clear()
	_ghost_at = Vector2.INF
	_sync_plan_level()
	if room.active:
		room.set_level(laying_level())
	_redraw()


func _sync_plan_level() -> void:
	"""The plan's level and link from the tool's: a link's head is always on level 1; the ghost on the level laid on."""
	plan.link_kind = link_kind
	plan.level = Rules.TOP_LEVEL if link_kind != Rules.LINK_NONE else laying_level()
	overlay.set_plan_level(laying_level())


func cycle_link() -> int:
	"""L in the tool: tunnels -> a ramp down -> stairs down -> tunnels (see THE SECOND LEVEL). Returns the kind now."""
	link_kind = (link_kind + 1) % (Rules.LINK_STAIRS + 1)
	plan.clear()
	_ghost_at = Vector2.INF
	_sync_plan_level()
	_say(plan_status())
	_redraw()
	return link_kind


static func _shift_only_non_letter(event: InputEventKey) -> bool:
	"""Whether only Shift is held with a key that is not a letter (Shift+Enter still digs)."""
	var key := key_of(event)
	return event.shift_pressed and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed) \
			and not (key >= KEY_A and key <= KEY_Z)


static func _modified(event: InputEventKey) -> bool:
	"""Whether a modifier is held (B, T and U are plain keys)."""
	return event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed


func _on_key(event: InputEventKey) -> bool:
	"""B or T opens the Dig tool; U switches the underground view."""
	if _modified(event):
		return false
	if key_of(event) == KEY_B or key_of(event) == KEY_T:
		begin_plan()
		return true
	if key_of(event) == KEY_U:
		toggle_view()
		return true
	return false


func _plan_input(event: InputEvent) -> bool:
	"""In the tool: presses, drags and releases, confirm, undo, drop and close (see CONTROLS); with a room tool
	open, its own input first (see ROOMS)."""
	if room.active:
		return room.handle_input(event) or _room_key(event)
	if event is InputEventMouseMotion:
		_hover((event as InputEventMouseMotion).position)
		return _pressing
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_on_press(button.position)
		else:
			_on_release(button.position)
		return true
	if button != null and button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			confirm()
		return true
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _plan_key(event as InputEventKey)
	return false


func _plan_key(event: InputEventKey) -> bool:
	"""Enter digs, Backspace takes a point back, Esc drops the piece (or closes the tool), B or T closes it,
	U switches the view, Shift while dragging drops a bend. A key held with Ctrl, Cmd or Alt -- or a letter with Shift --
	is not the tool's."""
	if _modified(event) and not (key_of(event) == KEY_SHIFT or _shift_only_non_letter(event)):
		return false
	match key_of(event):
		KEY_ENTER, KEY_KP_ENTER:
			confirm()
		KEY_BACKSPACE:
			undo_point()
		KEY_ESCAPE:
			_escape()
		KEY_B, KEY_T:
			cancel_plan()
		KEY_U:
			toggle_view()
		KEY_H:
			begin_room(RoomsScript.TEMPLATE_HOME)
		KEY_C:
			begin_room(RoomsScript.TEMPLATE_CELLAR)
		KEY_L:
			cycle_link()
		KEY_SHIFT:
			return _bend_here()
		_:
			return false
	return true


func _room_key(event: InputEvent) -> bool:
	"""With a room tool open: B or T closes the Dig tool, U switches the view, H or C switches the room tool
	(the same one again: back to tunnels)."""
	var key := event as InputEventKey
	if key == null or not key.is_pressed() or key.is_echo() or _modified(key):
		return false
	match key_of(key):
		KEY_B, KEY_T:
			cancel_plan()
		KEY_U:
			toggle_view()
		KEY_H:
			begin_room(RoomsScript.TEMPLATE_HOME)
		KEY_C:
			begin_room(RoomsScript.TEMPLATE_CELLAR)
		_:
			return false
	return true


func begin_room(kind: int) -> bool:
	"""Open the room tool for template `kind` (see ROOMS), opening the Dig tool first when it is closed; the
	tool already open for `kind` goes back to laying tunnels. Returns whether a room tool is open now."""
	if not planning and not begin_plan():
		return false
	if room.active and room.plan.kind == kind:
		end_room()
		return false
	link_kind = Rules.LINK_NONE
	_sync_plan_level()
	plan.clear()
	overlay.hide_plan()
	room.begin(kind, room_site())
	ext.placing_room = kind
	return true


func end_room() -> void:
	"""Close the room tool: back to laying tunnels."""
	room.end()
	ext.placing_room = RoomsScript.TEMPLATE_NONE
	_say(PLAN_FIRST)
	_redraw()


func site_key() -> Vector2i:
	"""What a room's site depends on, as it stands: the network's revision (its mouths) and how often the ground's
	obstacles (heaps, mounds) have been rebuilt. The room tool takes its site afresh when this changes."""
	return Vector2i(network.revision, _space.obstacle_builds)


func room_site() -> RoomsScript.Site:
	"""What a room must keep clear of now (underground_rooms.gd Site): the village, the obstacles, work spots and
	mouths, the buildings, the crop beds and the water."""
	_refresh_clearances()
	var site := RoomsScript.Site.new()
	site.bounds_u = _bounds_u
	site.circles_u = _circles_u
	site.spots_u = _spots_u.duplicate()
	site.under_u = _under_u.duplicate()
	for bed in FarmCatalog.BED_COUNT:
		var at: Vector2 = FarmCatalog.bed_centre_m(bed)
		site.beds_u.append_array(PackedInt32Array([Rules.to_u(at.x), Rules.to_u(FarmCatalog.BED_HALF_M), Rules.to_u(at.y)]))
	site.water = ext.works.water.crosses_water
	return site


func _escape() -> void:
	"""Esc: drop the piece being laid, or close the tool when there is none."""
	if plan.count == 0 and link_kind != Rules.LINK_NONE:
		link_kind = Rules.LINK_NONE
		_sync_plan_level()
		_say(PLAN_FIRST)
		_redraw()
		return
	if plan.count == 0:
		cancel_plan()
		return
	plan.clear()
	_pressing = false
	_dragging = false
	_redraw()
	_say(PLAN_DROPPED)


func _on_press(screen: Vector2) -> void:
	"""A left press: the start, when nothing is laid yet; and the start of a drag either way."""
	_pressing = true
	_dragging = false
	_press_screen = screen
	_press_laid = plan.count == 0
	if _press_laid:
		lay_at(screen)


func _on_release(screen: Vector2) -> void:
	"""A left release: the end of a drag (laid and dug), or a click laying the next point."""
	var dragged := _dragging
	var laid := _press_laid
	_pressing = false
	_dragging = false
	if dragged and plan.count > 0:
		if lay_at(screen):
			confirm()
	elif not laid:
		lay_at(screen)


func _bend_here() -> bool:
	"""Shift while dragging: a bend at the pointer. False (not taken) when not dragging."""
	if not _dragging or not _has_cursor:
		return false
	lay_ground(_cursor)
	return true


func _ground_at(screen: Vector2) -> bool:
	"""The point under a screen point on the view's plane (the ground, or the level's floor in the U view),
	into _ground. False when the ray misses it."""
	var at: Vector2 = view.ground_at(screen)
	if at == Vector2.INF:
		return false
	_ground = at
	return true


func _hover(screen: Vector2) -> void:
	"""Follow the pointer with the ghost (a press moved far enough becomes a drag)."""
	if _pressing and screen.distance_to(_press_screen) > DRAG_PX:
		_dragging = true
	_has_cursor = _ground_at(screen)
	_cursor = _ground
	_redraw()


func toggle_view() -> void:
	"""Switch the underground view (one cull-mask write, tunnel_view.gd); switched back, the notice it
	replaced returns. The tool, open, lays on the level now shown (`laying_level`)."""
	var was := laying_level()
	if view.toggle():
		_before_view = _last_notice
		_say(VIEW_ON)
	elif _last_notice == VIEW_ON or _last_notice.begins_with(LEVEL_SHOWN.left(20)):
		_say(_before_view)
	if laying_level() != was:
		_relay()


# --- the tool -------------------------------------------------------------------------------

func toggle_plan() -> bool:
	"""The panel's "Dig tunnel" button: open the Dig tool -- or, open, close it, as B does. Returns whether it
	is open now."""
	if planning:
		cancel_plan()
	else:
		begin_plan()
	return planning


func begin_plan() -> bool:
	"""Open the Dig tool (see CONTROLS), showing the cutaway -- turned on before the plan takes its level, so it lays
	on the level shown -- or refuse, saying why: nobody in the village can dig, or no piece at all could fit (decision 0361:
	a network with no mouth left still takes a connection; the piece as laid is refused for the capacity it would
	exhaust). Any HUD button's focus is released, so nothing but the tool hears the Enter that digs."""
	if not _any_digger():
		_refuse(Rules.REFUSE_NOT_A_DIGGER)
		return false
	var full: int = network.any_piece_refusal()
	if full != Rules.REFUSE_NONE:
		_refuse(full)
		return false
	if is_inside_tree():
		get_viewport().gui_release_focus()
	planning = true
	ext.set_planning(true)
	_view_before_tool = view.on
	if not view.on:
		view.set_on(true)
	link_kind = Rules.LINK_NONE
	_sync_plan_level()
	plan.clear()
	_refresh_clearances()
	_has_cursor = false
	_redraw()
	_say(PLAN_FIRST)
	return true


func _any_digger() -> bool:
	"""Whether anybody in the village can dig."""
	return ext.can_dig.has(1)


func _refresh_clearances() -> void:
	"""What a new mouth must clear now: every obstacle and heap, and every work spot and mouth (see WHAT A
	PIECE MUST CLEAR)."""
	_circles_u = Rules.circles_to_u(_space.obstacles)
	_spots_u.clear()
	for poi in _space.poi_position.size():
		for k in _space.poi_capacity[poi]:
			var at := _space.slot_position(poi, k)
			_spots_u.append_array(PackedInt32Array([Rules.to_u(at.x), SPOT_KEEP_U, Rules.to_u(at.y)]))
	for m in Rules.MAX_MOUTHS:
		if network.is_mouth(m):
			var mouth := network.node_at(network.mouth_node[m])
			_spots_u.append_array(PackedInt32Array([mouth.x, MOUTH_KEEP_U, mouth.y]))


func lay_at(screen: Vector2) -> bool:
	"""Lay the next point on the view's plane under a screen point. False when refused (or off the plane)."""
	return _ground_at(screen) and lay_ground(_ground)


func lay_ground(at: Vector2) -> bool:
	"""Lay the next point at (x, z) metres, snapped to the network where it lies on or near it (see SNAPPING
	AND THE GHOST); a refused point is marked clay with its reason."""
	var kind := PlanScript.snap_into(network, Vector2i(Rules.to_u(at.x), Rules.to_u(at.y)), _snap, plan.level_of_point(plan.count))
	var reason := plan.try_add_snapped(_snap[2], _snap[3], kind, _snap[1], _bounds_u, _circles_u, _spots_u, _under_u)
	if reason != Rules.REFUSE_NONE:
		_mark.call(Vector3(at.x, 0.0, at.y), false)
		_say(REFUSED % Rules.link_text(reason, ""))
	else:
		_say(plan_status())
	_ghost_at = Vector2.INF
	_redraw()
	return reason == Rules.REFUSE_NONE


func plan_status() -> String:
	"""What the panel says while a piece is being laid."""
	if plan.count == 0 and link_kind != Rules.LINK_NONE:
		return LINK_FIRST % [Rules.LINK_NAMES[link_kind], "stairs" if link_kind == Rules.LINK_RAMP else "back to tunnels"]
	if plan.count == 0:
		return PLAN_FIRST
	var points := "1 point" if plan.count == 1 else "%d points" % plan.count
	var status := PLAN_MORE % [points, PlanScript.length_text(plan.length_u())]
	return status if plan.count < 2 else "%s · %s" % [status, ext.route_ground(plan.points_u, plan.count, plan.level)]


func undo_point() -> void:
	"""Take back the last point; with none left, close the tool."""
	if not plan.undo():
		cancel_plan()
		return
	_say(plan_status())
	_redraw()


func cancel_plan() -> void:
	"""Close the Dig tool without digging what is laid; the view goes back to what it was."""
	_end_plan()
	_say(PLAN_CANCELLED)


func _end_plan() -> void:
	"""Close the tool: clear its drawing, and put the view back."""
	planning = false
	_pressing = false
	_dragging = false
	plan.clear()
	room.end()
	ext.placing_room = RoomsScript.TEMPLATE_NONE
	ext.set_planning(false)
	overlay.hide_plan()
	if view.on != _view_before_tool:
		view.set_on(_view_before_tool)


func _refuse(reason: int) -> void:
	"""Say why (naming the tunnel it concerns), and drop a clay marker where it went wrong (the end for an end
	refusal, the start for one about the start, otherwise the last point laid)."""
	_say(REFUSED % Rules.link_text(reason, plan.refused_name(network)))
	if plan.count == 0 or not planning:
		return
	var k := plan.count - 1
	if reason == Rules.REFUSE_ENTRANCE_BLOCKED or reason == Rules.REFUSE_UNREACHABLE \
			or reason == Rules.REFUSE_ENTRANCE_OCCUPIED:
		k = 0
	var at := plan.point_m(k)
	_mark.call(Vector3(at.x, 0.0, at.y), false)


static func tunnel_name(slot: int) -> String:
	"""How the words name a segment: "Tunnel N" (slot + 1), or "a tunnel" for none."""
	return "Tunnel %d" % (slot + 1) if slot >= 0 else "a tunnel"


# --- the ghost ------------------------------------------------------------------------------

func _redraw() -> void:
	"""Draw the piece laid and, to the pointer, the ghost: its snap, whether it may be dug and why not, and
	the cost readout (see SNAPPING AND THE GHOST). A room tool draws its own."""
	if not planning or room.active:
		return
	var snap := SpecScript.END_NEW_MOUTH
	var cursor := _cursor
	if _has_cursor:
		snap = PlanScript.snap_into(network, Vector2i(Rules.to_u(_cursor.x), Rules.to_u(_cursor.y)), _snap,
			plan.level_of_point(plan.count))
		cursor = Vector2(Rules.to_m(_snap[2]), Rules.to_m(_snap[3]))
		_check_ghost(cursor, snap)
	overlay.show_ghost(plan, cursor, _has_cursor, snap, _ghost_refusal != Rules.REFUSE_NONE, _ghost_words)


func _check_ghost(cursor: Vector2, snap: int) -> void:
	"""Check the piece as it would be with its end at the pointer (throttled to a move of GHOST_STEP_M): its
	refusal and its words -- the reason, or the cost readout."""
	if _ghost_at.distance_to(cursor) < GHOST_STEP_M:
		return
	_ghost_at = cursor
	_ghost_refusal = Rules.REFUSE_NONE
	_ghost_words = ""
	if plan.count == 0:
		return
	_ghost_refusal = plan.try_add_snapped(_snap[2], _snap[3], snap, _snap[1], _bounds_u, _circles_u, _spots_u, _under_u)
	if _ghost_refusal == Rules.REFUSE_NONE:
		_ghost_refusal = plan.piece_reason(network, _bounds_u, _circles_u, _spots_u, _under_u)
		var digger := choose_digger()
		_ghost_words = ReadoutScript.text(plan, ext.works.ground, crew_rate(digger), crew_size(digger)) \
				if _ghost_refusal == Rules.REFUSE_NONE else Rules.link_text(_ghost_refusal, plan.refused_name(network))
		plan.undo()
	else:
		_ghost_words = Rules.link_text(_ghost_refusal, "")


func ghost_words() -> String:
	"""What the ghost says beside the pointer now (the readout, or the reason it may not be dug)."""
	return _ghost_words


func ghost_refused() -> bool:
	"""Whether the ghost to the pointer may not be dug."""
	return _ghost_refusal != Rules.REFUSE_NONE


func laid_piece_reason() -> int:
	"""Why the piece as laid (not the ghost to the pointer) may not be dug -- the plan's own whole-piece check, as
	`confirm` runs it; REFUSE_NONE when it may (the route preview's question, decision 0461)."""
	if plan.count < 2:
		return Rules.REFUSE_TOO_FEW_POINTS
	return plan.piece_reason(network, _bounds_u, _circles_u, _spots_u, _under_u)


func laid_spec() -> SpecScript:
	"""The piece as laid, as `confirm` would store it (its digger the one `choose_digger` names) -- for a preview on a
	copy of the network only (decision 0461)."""
	return plan.spec_of(maxi(choose_digger(), 0))


func crew_size(digger: int) -> int:
	"""How many would dig: the digger and the rest of the selection it can take on (at most a full crew)."""
	var n := 1
	for i in _selection.call() as PackedInt32Array:
		if i != digger and n < CrewScript.MAX_BUILDERS:
			n += 1
	return n


func crew_rate(digger: int, faces: int = 1) -> int:
	"""The rate (per mille) the crew would dig at, on `faces` quanta side by side (a room: three): the pipeline
	for those at the work (the digger and those selected who fit), times the digger's skill (tunnel_crew.gd)."""
	var workers := 1
	for i in _selection.call() as PackedInt32Array:
		if i != digger and workers < CrewScript.MAX_BUILDERS and network.fits(i):
			workers += 1
	var skill := ext.works.crew.skills.factor_permille(digger) if digger >= 0 else Rules.PERMILLE
	return CrewScript.pipeline_permille(workers, faces) * skill / Rules.PERMILLE


# --- digging a piece ------------------------------------------------------------------------

func choose_digger() -> int:
	"""Who digs the piece (see WHO DIGS): the first selected resident who can dig, else the village's most
	skilled digger who is free, else its most skilled (to dig it next); -1 when nobody can dig."""
	for i in _selection.call() as PackedInt32Array:
		if is_digger(i):
			return i
	var best := -1
	for i in _cast.actor_count():
		if is_digger(i) and (best < 0 or _ranks_before(i, best)):
			best = i
	return best


func _ranks_before(i: int, j: int) -> bool:
	"""Whether digger i is the better pick than digger j: free before busy, then the higher skill."""
	var i_free := _brain(i).dig_tunnel < 0
	var j_free := _brain(j).dig_tunnel < 0
	if i_free != j_free:
		return i_free
	return ext.works.crew.skills.level_of(i) > ext.works.crew.skills.level_of(j)


func confirm() -> bool:
	"""Dig the piece as laid: check it (the plan's rules; nobody on a new entrance; a way for the digger),
	store it, place its heaps and send the digger -- or queue it behind the digger's present dig. A refusal
	keeps it laid, marks the point at fault and says why."""
	var digger := choose_digger()
	_planner = maxi(digger, 0)
	var reason := plan.piece_reason(network, _bounds_u, _circles_u, _spots_u, _under_u) if plan.count >= 2 \
			else Rules.REFUSE_TOO_FEW_POINTS
	if reason == Rules.REFUSE_NONE and digger < 0:
		reason = Rules.REFUSE_NOT_A_DIGGER
	var now := digger >= 0 and _brain(digger).dig_tunnel < 0
	if reason == Rules.REFUSE_NONE and plan.starts_at_mouth() and _entrance_occupied(digger):
		reason = Rules.REFUSE_ENTRANCE_OCCUPIED
	if reason == Rules.REFUSE_NONE and now and plan.starts_at_mouth() and not _entrance_reachable(digger):
		reason = Rules.REFUSE_UNREACHABLE
	if reason == Rules.REFUSE_NONE and not network.add_piece(plan.spec_of(digger), _ref):
		reason = network.rows_refusal(plan.spec_of(digger))
		reason = Rules.REFUSE_NETWORK_FULL if reason == Rules.REFUSE_NONE else reason
	if reason != Rules.REFUSE_NONE:
		_refuse(reason)
		return false
	accept_piece(_ref[2])
	_send(digger, now)
	plan.clear()
	_ghost_at = Vector2.INF
	_redraw()
	return true


func _send(digger: int, now: bool) -> void:
	"""The piece just stored: its digger goes to dig it (with the rest of the selection as its crew), or it
	waits in the job list behind the digger's present dig."""
	var first := _ref[0]
	var length := PlanScript.length_text(_piece_length_u(_ref[2]))
	if not now:
		_sync_seen()
		_say(_link_worded(DIG_QUEUED % [length, (_cast.actor(digger) as DemoActorScript).display_name]))
		return
	network.start_dig(first, _ref[1], digger)
	_brain(digger).order_dig(first, _ref[1])
	ext.works.say(CrewScript.LINE_START)
	ext.crew_on_dig(first, digger)
	_sync_seen()
	_mark.call(_start3(first), true)
	var ticks := PackedInt32Array([0, 0])
	network.piece_ticks_into(_ref[2], ticks)
	_say(_link_worded(DIG_STARTED % [length, _piece_quanta(_ref[2]), _finished_spoil_u(_ref[2]), ticks[1] / Rules.TICKS_PER_SECOND]))


func _link_worded(words: String) -> String:
	"""A dig's notice naming what the piece just stored is: a tunnel, or a ramp or stairs down (`_ref`'s first
	segment's link kind)."""
	var kind: int = network.seg_link[_ref[0]]
	return words if kind == Rules.LINK_NONE else words.replace(" tunnel", " " + LINK_WORD[kind])


func _piece_length_u(p: int) -> int:
	"""A piece's length along its segments (u)."""
	var chain := PackedInt32Array()
	network.piece_segments_into(p, chain)
	var total := 0
	for slot in chain:
		total += network.length_u[slot]
	return total


func _piece_quanta(p: int) -> int:
	"""How many quanta a piece's segments cut."""
	var chain := PackedInt32Array()
	network.piece_segments_into(p, chain)
	var total := 0
	for slot in chain:
		total += network.timeline_count(slot)
	return total


func _finished_spoil_u(p: int) -> int:
	"""The whole units of spoil a piece will heap, through its ground (tunnel_ground.gd)."""
	var chain := PackedInt32Array()
	network.piece_segments_into(p, chain)
	var spoil := PackedInt64Array()
	spoil.resize(GraphScript.P_SIZE)
	var total := 0
	for slot in chain:
		network.progress_into(slot, network.total_ticks(slot), 1, spoil)
		total += spoil[GraphScript.P_SPOIL]
	return total / 1000


func accept_piece(p: int) -> void:
	"""A piece just stored: place the heaps of the mouths it spoils at (obstacles from now on), clear the
	grass from its holes, heaps and route, and hand what it split to the halves."""
	var chain := PackedInt32Array()
	network.piece_segments_into(p, chain)
	var mouths := PackedInt32Array([network.piece_mouth[p]])
	for slot in chain:
		var out := network.mouth_of_end(slot, true)
		if out >= 0 and not mouths.has(out):
			mouths.append(out)
	for m in mouths:
		if network.is_mouth(m):
			HeapsScript.place(network, _space, m)
	ext.works.after_splits()
	_circles_u = Rules.circles_to_u(_space.obstacles)
	_clear_cover(chain, mouths)


func _clear_cover(chain: PackedInt32Array, mouths: PackedInt32Array) -> void:
	"""Clear the world's grass from a new piece's route, its holes and heaps."""
	if _world == null:
		return
	var circles := PackedVector3Array()
	for m in mouths:
		if network.is_mouth(m):
			var at := network.mouth_at(m)
			circles.append(Vector3(network.heap_at[m].x, network.heap_radius_m[m], network.heap_at[m].y))
			circles.append(Vector3(at.x, Rules.HOLE_RADIUS_M * Rules.RIM_FACTOR, at.y))
	for slot in chain:
		_route.clear()
		for k in network.point_count[slot]:
			_route.append(network.point(slot, k))
		_world.hide_cover(_route, COVER_CLEAR_M, circles)


func _entrance_occupied(digger: int) -> bool:
	"""Whether someone other than the digger stands on the new entrance (see `occupied_at`)."""
	return occupied_at(digger, plan.point_m(0))


func occupied_at(digger: int, at: Vector2) -> bool:
	"""Whether someone other than the digger stands on a new entrance at `at`: closer than their radius plus the
	digger's plus the planning margin (so the digger could never step into the hole to dig)."""
	var radius := _brain(digger).radius if digger >= 0 else 0.3
	for j in _space.resident_position.size():
		if j == digger or _space.resident_underground[j] != 0 or _space.resident_walking[j] != 0:
			continue
		var reach := _space.resident_radius[j] + radius + CastNavScript.PLAN_MARGIN_M
		if _space.resident_position[j].distance_to(at) < reach:
			return true
	return false


func _entrance_reachable(digger: int) -> bool:
	"""Whether the digger can walk to the new entrance (see `reachable`)."""
	return reachable(digger, plan.point_m(0))


func reachable(digger: int, at: Vector2) -> bool:
	"""Whether the digger can walk from where it will stand to `at`, round everyone standing."""
	var brain := _brain(digger)
	_space.plan_path(brain.index, brain.surface_point(), at, brain.radius, _route)
	return _space.nav.last_found


# --- the room tool's hooks (demo/burrow/room_tool.gd) ---------------------------------------

func entrance_refusal(digger: int, at: Vector2) -> int:
	"""Why a room's door at `at` may not be dug by `digger` (a tunnel's entrance's rules), or REFUSE_NONE:
	nobody can dig, someone stands on it, or -- the digger free to start now -- it cannot reach it."""
	if digger < 0:
		return Rules.REFUSE_NOT_A_DIGGER
	if occupied_at(digger, at):
		return Rules.REFUSE_ENTRANCE_OCCUPIED
	if _brain(digger).dig_tunnel < 0 and not reachable(digger, at):
		return Rules.REFUSE_UNREACHABLE
	return Rules.REFUSE_NONE


func room_laid(p: int, passage: int) -> void:
	"""A room just laid as piece `p`, and its passage as piece `passage` (-1: none): its mound stands as an
	obstacle, then each piece's heaps are placed and its grass cleared (`accept_piece`)."""
	ext.room_view.refresh()
	accept_piece(p)
	if passage >= 0:
		accept_piece(passage)


func start_room(first: int, gen: int, digger: int) -> bool:
	"""Send `digger` to dig a room just laid (its first segment `first`, generation `gen`), the rest of the
	selection its crew -- or, busy digging, leave it in its job list. Returns whether it starts now."""
	var now := _brain(digger).dig_tunnel < 0
	if now:
		network.start_dig(first, gen, digger)
		_brain(digger).order_dig(first, gen)
		ext.works.say(CrewScript.LINE_START)
		ext.crew_on_dig(first, digger)
		_mark.call(_start3(first), true)
	_sync_seen()
	return now


func digger_name(i: int) -> String:
	"""Resident `i`'s name."""
	return (_cast.actor(i) as DemoActorScript).display_name


func say(text: String) -> void:
	"""Show a line in the party panel (the room tool's words)."""
	_say(text)


func mark_at(at: Vector2, accepted: bool) -> void:
	"""Drop an order marker at `at` on the ground."""
	_mark.call(Vector3(at.x, 0.0, at.y), accepted)


func _start3(slot: int) -> Vector3:
	"""Where a segment starts, as a point on its level (the ground for a mouth)."""
	var at := network.end_at(slot, false)
	return Vector3(at.x, network.node_floor_y(network.node_a[slot]), at.y)


# --- resuming and watching ------------------------------------------------------------------

func _try_resume(screen: Vector2) -> bool:
	"""A right click, on the view's plane under a screen point (see resume_at)."""
	return _ground_at(screen) and resume_at(_ground)


func resume_at(at: Vector2) -> bool:
	"""A right click at (x, z) with a digger selected (see CONTROLS): on the start of the segment it is
	digging, nothing changes; on a paused or waiting one's, it goes to dig that. False (the click is an
	order) anywhere else, or with no digger selected."""
	var digger := -1
	for i in _selection.call() as PackedInt32Array:
		if is_digger(i):
			digger = i
			break
	if digger < 0:
		return _join_crew_at(at)
	_planner = digger
	var slot := entrance_near(at)
	if slot < 0:
		return false
	if slot == _brain(digger).dig_tunnel:
		_mark.call(_start3(slot), true)
		ext.crew_on_dig(slot, digger)
		_say(DIG_KEPT % network.piece_percent(network.piece[slot]))
		return true
	return network.phase[slot] != GraphScript.PHASE_DIGGING and resume(slot)


func _join_crew_at(at: Vector2) -> bool:
	"""A right click at (x, z) with no digger selected: on the start of a segment being dug, the selected
	residents join its crew. False (the click is an order) anywhere else, or when nobody joined."""
	var slot := entrance_near(at)
	if slot < 0 or network.phase[slot] != GraphScript.PHASE_DIGGING:
		return false
	if ext.actions.add_crew(slot, _selection.call() as PackedInt32Array, network.digger[slot]) == 0:
		return false
	_mark.call(_start3(slot), true)
	return true


func select_tunnel_at(screen: Vector2) -> bool:
	"""A left click that picked no resident: select the finished segment under it (tunnel_ext.gd)."""
	return ext.select_at_screen(screen)


func entrance_near(at: Vector2) -> int:
	"""The unfinished segment, next of its piece to dig, whose start -- on the level the view shows (decision 0212) -- is
	nearest `at` within RESUME_PICK_M, or -1."""
	var best := -1
	var best_d := RESUME_PICK_M
	var level := laying_level()
	for slot in Rules.MAX_SEGMENTS:
		if not network.is_unfinished(slot) or not _next_to_dig(slot) \
				or not PlanScript.on_level_or_mouth(network, network.node_a[slot], level):
			continue
		var d := network.end_at(slot, false).distance_to(at)
		if d <= best_d:
			best_d = d
			best = slot
	return best


func _next_to_dig(slot: int) -> bool:
	"""Whether a segment is the next of its piece to dig: its start is a mouth, or the segment before it is
	open."""
	var start := network.node_a[slot]
	if network.node_mouth[start] >= 0:
		return true
	for k in GraphScript.DEGREE:
		var other := network.node_segment(start, k)
		if other >= 0 and other != slot and network.is_open(other):
			return true
	return false


func resume(slot: int) -> bool:
	"""Send the planning digger (_planner) to dig paused or waiting segment `slot`; one it was digging is
	paused with its progress (resident_brain.order_dig)."""
	if not network.start_dig(slot, network.generation[slot], _brain(_planner).index):
		return false
	_brain(_planner).order_dig(slot, network.generation[slot])
	_sync_seen()
	_mark.call(_start3(slot), true)
	_say(DIG_RESUMED % network.piece_percent(network.piece[slot]))
	return true


func _process(_delta: float) -> void:
	"""Say what changed in the network (see THE NOTICE FOLLOWS THE TUNNELS)."""
	if network == null or network.revision == _seen_revision:
		return
	_seen_revision = network.revision
	_opened.clear()
	for slot in Rules.MAX_SEGMENTS:
		var phase := network.phase[slot]
		if phase == _seen_phase[slot] and network.generation[slot] == _seen_generation[slot] \
				and network.pause_reason[slot] == _seen_reason[slot]:
			continue
		_announce(slot, _seen_phase[slot], phase)
		_seen_phase[slot] = phase
		_seen_generation[slot] = network.generation[slot]
		_seen_reason[slot] = network.pause_reason[slot]
	_watch_mouths()


func _announce(slot: int, was: int, now: int) -> void:
	"""The notice for segment `slot` going from phase `was` to `now`: its piece dug through (a room: dug out) --
	once, however many of its segments opened since the last look (a room's walks open with its body) -- paused,
	or dropped."""
	if now == GraphScript.PHASE_OPEN and _opened.has(network.piece[slot]):
		return
	if now == GraphScript.PHASE_OPEN and was != GraphScript.PHASE_FREE and network.piece_done(network.piece[slot]):
		_opened.append(network.piece[slot])
		var r: int = network.seg_room[slot]
		var words := LINK_OPEN[network.seg_link[slot]] if network.seg_kind[slot] == GraphScript.SEG_LINK else DIG_OPEN
		_say_about(ROOM_OPEN[network.rooms.template[r]] if r >= 0 else words, slot)
	elif now == GraphScript.PHASE_PAUSED and network.pause_reason[slot] == GraphScript.PAUSED_UNREACHED:
		_say_about(DIG_UNREACHED % network.piece_percent(network.piece[slot]), slot)
	elif now == GraphScript.PHASE_PAUSED:
		_say_about(DIG_PAUSED % network.piece_percent(network.piece[slot]), slot)
	elif now == GraphScript.PHASE_FREE and was == GraphScript.PHASE_DIGGING:
		_say(DIG_DROPPED)


func _watch_mouths() -> void:
	"""A freed mouth's heap stops being an obstacle."""
	for m in Rules.MAX_MOUTHS:
		var live := network.mouth_gen[m] if network.is_mouth(m) else -1
		if live == _seen_mouth[m]:
			continue
		if live < 0 and _seen_mouth[m] >= 0:
			HeapsScript.clear(network, _space, m)
			_circles_u = Rules.circles_to_u(_space.obstacles)
		_seen_mouth[m] = live


func _sync_seen() -> void:
	"""Take the network as it stands as seen: changes the tool made itself need no second notice."""
	_seen_revision = network.revision
	for slot in Rules.MAX_SEGMENTS:
		_seen_phase[slot] = network.phase[slot]
		_seen_generation[slot] = network.generation[slot]
		_seen_reason[slot] = network.pause_reason[slot]
	for m in Rules.MAX_MOUTHS:
		_seen_mouth[m] = network.mouth_gen[m] if network.is_mouth(m) else -1


# --- the tools' action cards (decision 0332, review F33/F44) ----------------------------------------

func tool_card_into(card: CardScript, verb: String, what: String) -> void:
	"""The Dig tool's (or a room tool's) action card: what it lays, that it spends nothing from the stores (the
	pointer's readout gives the time, the spoil and the brace cost of the piece laid), and who digs -- `choose_digger`,
	the rule `confirm` sends, with the crew the selection makes (`crew_size`). Refused, naming the capacity that ran
	out, when `begin_plan` would refuse to open for it (decision 0361, the review's F08)."""
	card.reset(verb)
	card.result = what
	card.prerequisites.append(TOOL_NEEDS)
	card.work_note = ""
	var full: int = network.any_piece_refusal()
	if full != Rules.REFUSE_NONE:
		card.refuse(TOOL_FULL_CODE, Rules.link_text(full, ""))
	var digger := choose_digger()
	if digger < 0:
		card.who = TOOL_NOBODY
		return
	var selection := _selection.call() as PackedInt32Array
	var name: String = (_cast.actor(digger) as DemoActorScript).display_name
	card.worker = digger
	if selection.has(digger):
		card.who = CardScript.assign_first(name, selection.size(), "who can dig")
	else:
		card.who = CardScript.assign_village(name, TOOL_FREE if _brain(digger).dig_tunnel < 0 else TOOL_BUSY)
	var crew := crew_size(digger) - 1
	if crew > 0:
		card.who += " + %d on the crew" % crew
