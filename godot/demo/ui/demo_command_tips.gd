extends RefCounted
## The command strip's hover tooltips in the live demo: what each command does, and its key. DEMO UI.
## Decision 0196 (live demo); playtest 2026-09-29: "Tooltips for what things mean in action bars when
## you hover over them".
##
## The HUD shell gives a wired command its bare label ("Zone") as its tooltip and a locked one only
## "Unavailable: <owner>", which says neither what the command is for nor how to reach it. Here every
## one of the seven says both:
##
##     Zone (Z) — Paint a work zone on the map with the zone brush
##     Build (B) — Place and upgrade the settlement's buildings
##     Not in the demo yet: no Building, Furniture or Room store exists; task 06 owns those contracts
##
## THE KEY IS READ FROM THE INPUT MAP (`UiShell.COMMAND_ACTIONS`, the project's `open_*` actions), never
## written here, so a rebinding in project.godot cannot leave a tooltip naming the old key. The shell
## presses an enabled command on that key (`UiShell.handle_command_key`), so the key named works.
## Only `tooltip_text` is written: the shell's accessible name and description (§2.2's "reason
## follows") are left as the shell set them. The Food command, once the farm has unlocked it as the
## Pantry, keeps the tip the farm wrote in this same form (farm_hud.gd `unlock_food_command`).

const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiAvailability := preload("res://scripts/ui/ui_availability.gd")

## What each command does, in `UiShell.COMMAND_IDS` order (the game's meaning; §4's rows 027-033).
const WHAT: Array[String] = [
	"Place and upgrade the settlement's buildings",
	"Paint a work zone on the map with the zone brush",
	"Set which work each resident does first",
	"Recipes and food orders for the kitchens",
	"The resident roster: pick a resident to open their journal",
	"Plan a feast for the settlement",
	"The settlement's goals and how far along they are",
]
## Between the command's name-and-key and what it does.
const DASH: String = " — "
## The second line of a command the demo does not have yet, before the shell's own reason.
const NOT_YET: String = "Not in the demo yet: "


static func key_text(action: StringName) -> String:
	"""The first keyboard key bound to `action` in the input map, as the player reads it ("B",
	"Ctrl+Space"); empty when the action is unknown or has no key (the tooltip then names none)."""
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.as_text_keycode()
	return ""


static func tooltip(label: String, action: StringName, what: String, missing: String) -> String:
	"""One command's tooltip: "Label (Key) — what it does", and, when `missing` names what the game
	still lacks, a second line "Not in the demo yet: <missing>"."""
	var key: String = key_text(action)
	var head: String = label if key.is_empty() else "%s (%s)" % [label, key]
	var text: String = "%s%s%s" % [head, DASH, what]
	if missing.is_empty():
		return text
	return "%s\n%s%s" % [text, NOT_YET, missing]


static func apply(shell: UiShell) -> int:
	"""Write every command's tooltip on `shell`'s strip; returns how many were written. The Food
	command the farm unlocked (enabled) keeps the Pantry tip the farm wrote."""
	if shell == null:
		return 0
	var written: int = 0
	for index: int in UiShell.COMMAND_IDS.size():
		var id: int = UiShell.COMMAND_IDS[index]
		var button := shell.control_for(id) as Button
		if button == null or (id == UiShell.ID_FOOD_ORDERS and not button.disabled):
			continue
		button.tooltip_text = tooltip(UiShell.COMMAND_LABELS[index], UiShell.COMMAND_ACTIONS[index], WHAT[index],
			missing_of(shell, id) if button.disabled else "")
		written += 1
	return written


static func missing_of(shell: UiShell, id: int) -> String:
	"""What the game lacks for a locked command: the shell's own named reason (§2.2's missing owner)."""
	var reason := shell.availability().reason_of(id)
	if not reason.ok or reason.value == UiAvailability.REASON_WIRED or reason.value >= UiAvailability.REASON_TEXTS.size():
		return "this command's system is not built yet"
	return UiAvailability.REASON_TEXTS[reason.value]
