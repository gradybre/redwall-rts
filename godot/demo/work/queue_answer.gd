extends RefCounted
## What a Shift+right-click did (decision 0411; work_orders.gd): whether an order was queued (or taken up at once), and
## what to tell the player. A typed answer, so the command layer never reads success from the words.

## Whether an order went onto a list (or was taken up at once).
var ok: bool = false
## What to tell the player ("" when there was nothing to say: nobody selected, off the ground).
var words: String = ""


func _init(queued: bool = false, said: String = "") -> void:
	"""An answer: queued or not, and its words."""
	ok = queued
	words = said
