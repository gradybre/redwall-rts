extends RefCounted
## Who or what a map lens is drawn for (decision 0292): the base, for a lens with no subject. The Water
## range lens's subject is demo/waterplay/water_range.gd (a resident, or a mixed group member by member).
## Presentation only.

## Moves whenever what the subject is changes (a new selection, a step), so the picker re-texts at once.
var revision: int = 0


func has_subject() -> bool:
	"""Whether this lens is drawn for a particular subject (the base: no)."""
	return false


func subject_line() -> String:
	"""'Water range for: Otter fisher' -- the lens's subject in words."""
	return ""


func notes() -> String:
	"""What the subject can do there, a line each (per member for a group)."""
	return ""


func can_step() -> bool:
	"""Whether the player can step the subject (a mixed group: the group, then each member)."""
	return false


func step(_delta: int) -> void:
	"""Step the subject by `_delta` (the base has nothing to step)."""
	pass
