extends CanvasLayer
## Placeholder HUD holding the six anchored screen zones defined in CLAUDE.md.
##
## Only UIManager talks to this script; it renders what it is given and owns no
## game state beyond the values currently on screen.

const ALERT_HOLD_SECONDS: float = 4.0

@onready var _resource_label: Label = $Root/ResourceZone/ResourceLabel
@onready var _alert_label: Label = $Root/AlertZone/AlertLabel
@onready var _status_label: Label = $Root/StatusZone/StatusLabel

var _amounts: Dictionary = {}
var _alert_seconds_left: float = 0.0


func _ready() -> void:
	"""Start with an empty alert zone and keep ticking while the game is paused."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	_alert_label.text = ""


func _process(delta: float) -> void:
	"""Expire the current alert once its hold time has elapsed."""
	if _alert_seconds_left <= 0.0:
		return
	_alert_seconds_left -= delta
	if _alert_seconds_left <= 0.0:
		_alert_label.text = ""


func set_resource(resource_type: StringName, amount: float) -> void:
	"""Record one resource counter and repaint the top-left zone."""
	_amounts[resource_type] = amount
	_render_resources()


func set_status(state_name: String, speed_multiplier: float) -> void:
	"""Repaint the top-right game state and speed readout."""
	_status_label.text = "%s  x%.0f" % [state_name.capitalize(), speed_multiplier]


func show_alert(text: String) -> void:
	"""Display a transient message in the top-centre zone."""
	_alert_label.text = text
	_alert_seconds_left = ALERT_HOLD_SECONDS


func _render_resources() -> void:
	"""Rebuild the resource counter line from the recorded amounts."""
	var parts: PackedStringArray = PackedStringArray()
	for resource_type: StringName in _amounts:
		parts.append("%s %d" % [resource_type, int(_amounts[resource_type])])
	_resource_label.text = "   ".join(parts)
