extends "res://demo/lens_subject.gd"
## Whose water range the "Getting there: Water range" lens paints, and what each of them can do there.
## Decision 0292 (the review's F47: the water view used only the first selected resident's height, which
## misrepresents a mixed group). Presentation only; it reads the swim rows (swim_state.gd) and the zone
## thresholds (water_rules.gd) and writes nothing.
##
## THE SUBJECT follows the selection (`follow`):
##   * nobody selected -- the 1.0 m mouse anchor, and the lens says so;
##   * one resident -- that resident's zones;
##   * a group -- by default the WHOLE GROUP: the zones are painted for its shortest member, so yellow is
##     water EVERY member wades (each body's wade limit scales with its height: the shortest's is the
##     least), and the notes say by name who among them swims and who dives -- per-member compatibility,
##     never one member standing in silently for the rest. The player can step (◀ ▶) from the group to
##     each member in turn and back (`step`): the zones are then that member's, the lens names it ("Badger
##     quarryman (2 of 3 selected)") and the notes give its own wading depth, swimming and diving.
## A new selection goes back to the whole group; the same selection keeps the member chosen.

const SwimStateScript := preload("res://demo/waterplay/swim_state.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")

## `focus` for the whole group (else an index into `members`).
const GROUP: int = -1
const NOBODY_LABEL: String = "a 1.0 m mouse"

## The selected residents (cast order), and whom the zones show: GROUP or one of them.
var members: PackedInt32Array = PackedInt32Array()
var focus: int = GROUP

var _state: SwimStateScript = null
var _name_of: Callable = Callable()


func configure(state: SwimStateScript, name_of: Callable) -> void:
	"""Read each resident's swim row from `state`, and its name from `name_of(who: int) -> String`."""
	_state = state
	_name_of = name_of


func follow(selected: PackedInt32Array) -> bool:
	"""Follow the selection: a different one goes back to the whole group. Returns whether it changed."""
	if selected == members:
		return false
	members = selected
	focus = GROUP
	revision += 1
	return true


func has_subject() -> bool:
	"""The Water range lens is always drawn for someone (the mouse anchor with nobody selected)."""
	return true


func can_step() -> bool:
	"""A group can be stepped member by member."""
	return members.size() >= 2


func step(delta: int) -> void:
	"""Group -> each member in cast order -> group (`delta` +1), or back (-1)."""
	if not can_step():
		return
	var span: int = members.size() + 1
	focus = posmod(focus + 1 + delta, span) - 1
	revision += 1


func painted_who() -> int:
	"""The resident the zones are painted for: the focused member, else the group's shortest (the first in
	cast order on a tie); -1 with nobody selected."""
	if members.is_empty():
		return -1
	if focus != GROUP:
		return members[focus]
	var shortest: int = members[0]
	for who: int in members:
		if _state.height_u[who] < _state.height_u[shortest]:
			shortest = who
	return shortest


func paint_height_u() -> int:
	"""The body height the zones are painted for."""
	var who: int = painted_who()
	return WaterRules.MOUSE_HEIGHT_U if who < 0 else _state.height_u[who]


func paint_label() -> String:
	"""Whom the water's own legend names: 'Otter fisher (1.10 m)', or the group by its shortest."""
	var who: int = painted_who()
	if who < 0:
		return NOBODY_LABEL
	var named: String = "%s (%.2f m)" % [_name_of.call(who), WaterRules.to_m(_state.height_u[who])]
	if focus == GROUP and members.size() >= 2:
		return "all %d selected, by the shortest: %s" % [members.size(), named]
	return named


func subject_line() -> String:
	"""'Water range for: Otter fisher', '... for: all 3 selected', '... for: Badger (2 of 3 selected)'."""
	if members.is_empty():
		return "Water range for: %s (nobody selected)" % NOBODY_LABEL
	if members.size() == 1:
		return "Water range for: %s" % _name_of.call(members[0])
	if focus == GROUP:
		return "Water range for: all %d selected" % members.size()
	return "Water range for: %s (%d of %d selected)" % [_name_of.call(members[focus]), focus + 1, members.size()]


func notes() -> String:
	"""What the subject can do in the water: one resident's own range; for the whole group who among them
	swims and who dives (yellow is what every one wades); nobody selected: what selecting does."""
	if members.is_empty():
		return "Select residents to see their own range."
	if members.size() == 1 or focus != GROUP:
		return member_line(painted_who())
	return "All of them wade the yellow. Swim: %s. Dive: %s." % [_who_can(true), _who_can(false)]


func _who_can(swimming: bool) -> String:
	"""The group's swimmers (or divers) by name: 'all', 'none', 'Otter fisher', or 'all but Badger'."""
	var able := PackedStringArray()
	var unable := PackedStringArray()
	for who: int in members:
		var can: bool = _state.can_swim(who) if swimming else _state.can_dive(who)
		(able if can else unable).append(_name_of.call(who))
	if unable.is_empty():
		return "all"
	if able.is_empty():
		return "none"
	if unable.size() < able.size():
		return "all but " + ", ".join(unable)
	return ", ".join(able)


func member_line(who: int) -> String:
	"""'Wades to 0.37 m · swims · dives' (or 'cannot swim', 'does not dive')."""
	var swims: String = "swims" if _state.can_swim(who) else "cannot swim"
	var dives: String = "dives" if _state.can_dive(who) else "does not dive"
	return "Wades to %.2f m · %s · %s" % [WaterRules.to_m(WaterRules.wade_max_u(_state.height_u[who])), swims, dives]
