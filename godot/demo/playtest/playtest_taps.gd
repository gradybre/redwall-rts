extends RefCounted
## Where the village's BREADCRUMBS come from (decision 0562). DEMO DIAGNOSTICS. `wire` is called once per village
## (demo_village.gd `_ready`, after the input is built), with the objects it reads; the village's own code is not
## otherwise touched.
##
## THE SOURCES, read through public state only:
##   panels    the modal on top of the input gate (`top_layer`): the game menu, the Pantry, the Lab, Work, the
##             news history ... opened and closed, by node name; and the right column's panel or its collapse
##   views     the underground view on or off; the map layer shown (its index in the farm's lenses)
##   orders    every order mark (`demo_command.gd mark`), accepted or refused, with how many were selected; and the
##             party panel's Dig tunnel, Release and room buttons
##   notices   each new village-news post: its source and level (the text stays in the game's own history)
##   speed     the clock's speed and state (the node hears GameManager's signals itself)
##   scene     this village built, and opened once its first frames are drawn (`opened`)
## The game time for the heartbeat is the demo calendar's date and the clock's speed; the tick is the calendar's.

const PlaytestLog := preload("res://demo/playtest/playtest_log.gd")
const Crumbs := preload("res://demo/playtest/breadcrumbs.gd")
const SessionScript := preload("res://demo/playtest/playtest_session.gd")
const InputGateScript := preload("res://demo/ui/demo_input_gate.gd")
const DetailZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const LensesScript := preload("res://demo/map_lenses.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SPEED_WORDS: Array[String] = Crumbs.SPEED_WORDS


static func wire(village: Node, gate: InputGateScript, zone: DetailZoneScript, lenses: LensesScript,
		command: DemoCommandScript, notices: NoticesScript, calendar: CalendarScript) -> void:
	"""Bind one village's sources (see THE SOURCES); they are dropped when it leaves the tree."""
	var node: Node = PlaytestLog.ensure(village.get_tree())
	PlaytestLog.clear_probes()
	node.move_last.call_deferred()
	PlaytestLog.crumb(Crumbs.KIND_SCENE, &"village built")
	PlaytestLog.bind_time(func() -> String: return "%s, %s" % [calendar.date_text(), _speed_word(village)],
		func() -> int: return calendar.tick)
	PlaytestLog.probe_layer(gate.top_layer)
	PlaytestLog.probe(Crumbs.KIND_PANEL, &"right_column",
		func() -> int: return -1 if zone.is_collapsed() else zone.shown)
	PlaytestLog.probe(Crumbs.KIND_VIEW, &"underground", func() -> int: return int(command.underground_view()))
	PlaytestLog.probe(Crumbs.KIND_VIEW, &"map layer", func() -> int: return lenses.active)
	_wire_orders(command)
	PlaytestLog.probe(Crumbs.KIND_NOTICE, &"notice", func() -> int: return notices.revision,
		func() -> int: return notices.source(0) * 2 + notices.level(0) if notices.count() > 0 else 0)
	village.tree_exiting.connect(PlaytestLog.clear_probes)


static func _wire_orders(command: DemoCommandScript) -> void:
	"""Every order mark, and the party panel's own orders."""
	PlaytestLog.probe(Crumbs.KIND_ORDER, &"accepted", func() -> int: return command.orders_accepted,
		command.selection_count)
	PlaytestLog.probe(Crumbs.KIND_ORDER, &"refused", func() -> int: return command.orders_refused,
		command.selection_count)
	var panel: Object = command.panel()
	if panel == null:
		return
	panel.connect(&"dig_requested", func() -> void: PlaytestLog.crumb(Crumbs.KIND_ORDER, &"dig tunnel",
		command.selection_count()))
	panel.connect(&"release_requested", func() -> void: PlaytestLog.crumb(Crumbs.KIND_ORDER, &"release",
		command.selection_count()))
	panel.connect(&"room_requested", func(kind: int) -> void: PlaytestLog.crumb(Crumbs.KIND_ORDER, &"room",
		command.selection_count(), kind))


static func opened() -> void:
	"""The village's first frames are drawn and its clock runs: the scene breadcrumb, and the short freeze
	threshold from now on."""
	PlaytestLog.crumb(Crumbs.KIND_SCENE, &"village open")
	PlaytestLog.set_phase(SessionScript.PHASE_RUNNING)


static func restarting() -> void:
	"""Restart demo was confirmed: the scene breadcrumb, and the loading threshold until the new village opens."""
	PlaytestLog.crumb(Crumbs.KIND_SCENE, &"restart")
	PlaytestLog.set_phase(SessionScript.PHASE_LOADING)


static func _speed_word(village: Node) -> String:
	"""The clock's speed in words ('paused', '1x' ...), from the autoload."""
	if not is_instance_valid(village) or not village.is_inside_tree():
		return "-"
	var manager: Node = village.get_tree().root.get_node_or_null(^"GameManager")
	if manager == null:
		return "-"
	var speed: int = int(manager.call(&"get_speed"))
	return SPEED_WORDS[speed] if speed >= 0 and speed < SPEED_WORDS.size() else str(speed)
