extends "res://test/live/demo_input_live.gd"
## A bounded live room-blueprint walkthrough. Uses the real village/input gate and shared capture helpers.
## Optional: -- --capture <directory>; images are runtime evidence, never design mockups.

const Rooms := preload("res://demo/burrow/underground_rooms.gd")
const RoomRules := preload("res://demo/tunnel/tunnel_rules.gd")
const RoomLayers := preload("res://demo/demo_layers.gd")

var _tool: Node3D = null
var _site_screen: Vector2 = Vector2.ZERO
var _site_m: Vector2 = Vector2.ZERO
var _initial_revision: int = 0
var _initial_stock: String = ""


func _initialize() -> void:
	"""Use the existing real-scene harness, replacing only its list of input steps."""
	super()
	_steps = [_open_room_tool, _choose_site, _hold_by_click, _inspect_held, _move_by_button,
		_hold_again, _confirm_by_button, _refuse_overlap, _discard_by_escape, _close_tool]


func _open_room_tool() -> void:
	"""B then H reach the room tool through the actual input gate."""
	_tool = _command().call(&"tunnels") as Node3D
	_key(KEY_B)
	_key(KEY_H)
	_check("B opens the Dig tool", _tool.planning)
	_check("H opens the home blueprint", _tool.room.active and _tool.room.plan.kind == Rooms.TEMPLATE_HOME)
	_initial_revision = _tool.network.revision
	_initial_stock = _tool.ext.works.stores.stock_line()


func _choose_site() -> void:
	"""Find a genuinely valid visible site in this village; do not fabricate an accepted placement."""
	var camera := _tool._camera as Camera3D
	var site: Rooms.Site = _tool.room_site()
	for z in range(-48, 49, 4):
		for x in range(-48, 49, 4):
			var at := Vector2(x, z)
			var at_u := Vector2i(RoomRules.to_u(at.x), RoomRules.to_u(at.y))
			if _tool.network.rooms.refusal(_tool.network, site, Rooms.TEMPLATE_HOME, at_u, 0, RoomRules.TOP_LEVEL) != Rooms.REFUSE_NONE:
				continue
			_tool.room.move_to(at)
			if _tool.room._entrance_refusal(_tool.choose_digger()) == RoomRules.REFUSE_NONE:
				var rig: Node3D = _village.get("_camera")
				rig.call(&"centre_on", Vector3(at.x, 0.0, at.y))
				rig.call(&"snap")
				# Leave the existing map legend and tutorial card clear: use open ground to their right.
				var under: Vector2 = _tool.view.ground_at(Vector2(810, 490))
				var offset := at - under
				var focus: Vector3 = rig.call(&"focus")
				rig.call(&"centre_on", focus + Vector3(offset.x, 0.0, offset.y))
				rig.call(&"snap")
				_site_screen = camera.unproject_position(Vector3(at.x, RoomLayers.floor_y(RoomRules.TOP_LEVEL), at.y))
				_site_m = at
				_manager().set("_last_host_usec", Time.get_ticks_usec())
				_check("a legal visible site exists", true, str(at))
				return
	_check("a legal visible site exists", false)


func _hold_by_click() -> void:
	"""A real world click holds the blueprint, never starting construction."""
	_site_screen = (_tool._camera as Camera3D).unproject_position(Vector3(_site_m.x, RoomLayers.floor_y(RoomRules.TOP_LEVEL), _site_m.y))
	_click(_site_screen)
	_check("click holds a blueprint", _tool.room.pending, "screen %s · %s" % [_site_screen, _tool.notice()])
	_check("click allocates no room", not _tool.network.rooms.is_room(0))
	_check("click leaves topology untouched", _tool.network.revision == _initial_revision)
	_check("click spends no stock", _tool.ext.works.stores.stock_line() == _initial_stock)
	_capture("room_blueprint_held")


func _inspect_held() -> void:
	"""Panel buttons fit the viewport; pointer motion and another click cannot submit the held plan."""
	var panel := _tool.ext.panel as TunnelPanel
	_check("blueprint card is visible", panel.blueprint_shown())
	_check("review card fits the viewport", Rect2(Vector2.ZERO, Vector2(_size)).encloses(panel.frame_rect()))
	for action: StringName in [TunnelPanel.ACTION_ROOM_CONFIRM, TunnelPanel.ACTION_ROOM_MOVE, TunnelPanel.ACTION_ROOM_DISCARD]:
		var button := panel.button(action)
		_check("review button is visible: %s" % action, button.is_visible_in_tree() and panel.frame_rect().has_point(_centre(button)))
	var centre: Vector2i = _tool.room.plan.centre_u
	_click(_site_screen + Vector2(40, 0))
	_check("second world click does not move the held plan", _tool.room.plan.centre_u == centre)
	_check("second world click does not confirm", not _tool.network.rooms.is_room(0))


func _move_by_button() -> void:
	"""The GUI Move command resumes previewing; its click does not leak to the world."""
	_click(_centre(_tool.ext.panel.button(TunnelPanel.ACTION_ROOM_MOVE)))
	_check("Move releases the held location", not _tool.room.pending)
	_check("Move preserves the room tool", _tool.room.active)
	_check("Move orders no room", not _tool.network.rooms.is_room(0))


func _hold_again() -> void:
	"""Repositioned previews require a new world click before confirmation."""
	_click(_site_screen)
	_check("the moved blueprint can be held again", _tool.room.pending)
	_check("Confirm is enabled for a valid held plan", not _tool.ext.panel.button(TunnelPanel.ACTION_ROOM_CONFIRM).disabled)


func _confirm_by_button() -> void:
	"""The actual Confirm button creates exactly one unfinished room and consumes the preview."""
	_click(_centre(_tool.ext.panel.button(TunnelPanel.ACTION_ROOM_CONFIRM)))
	_check("Confirm orders one room", _tool.network.rooms.template.count(Rooms.TEMPLATE_HOME) == 1, _tool.notice())
	_check("Confirm consumes the held blueprint", not _tool.room.pending)
	_check("the room is still awaiting excavation", not _tool.network.rooms.is_done(_tool.network, 0))
	_check("room stays on its reviewed level", _tool.network.rooms.level[0] == RoomRules.TOP_LEVEL)
	_capture("room_blueprint_confirmed")


func _refuse_overlap() -> void:
	"""Another blueprint at the same site visibly refuses instead of intersecting the ordered room."""
	_click(_site_screen)
	_check("invalid draft can still be reviewed", _tool.room.pending)
	_check("overlap disables Confirm", _tool.ext.panel.button(TunnelPanel.ACTION_ROOM_CONFIRM).disabled)
	_key(KEY_ENTER)
	_check("Enter cannot bypass the refusal", _tool.network.rooms.template.count(Rooms.TEMPLATE_HOME) == 1)
	_check("refused blueprint survives", _tool.room.pending)
	_capture("room_blueprint_refused")


func _discard_by_escape() -> void:
	"""Escape discards just the unconfirmed draft, leaving the earlier construction order alone."""
	_key(KEY_ESCAPE)
	_check("Escape discards the draft", not _tool.room.pending)
	_check("Escape preserves existing construction", _tool.network.rooms.is_room(0))
	_check("Escape preserves the room workspace", _tool.room.active and _tool.planning)


func _close_tool() -> void:
	"""The next Escape closes the room tool, not also the tunnel workspace."""
	_key(KEY_ESCAPE)
	_check("next Escape returns to tunnels", not _tool.room.active and _tool.planning)
	_check("review controls close with the room tool", not _tool.ext.panel.blueprint_shown())
	_key(KEY_B)
