extends RefCounted
## What a resident does under ORDER_TASK (resident_brain.gd TASKS). Decision 0196 (live demo).
## Presentation only. A tunnel job (tunnel_jobs.gd), a place in a dig crew (tunnel_crew.gd) and an
## evacuation (demo/events/) are each one of these: the brain walks its resident to `site()`, calls
## `arrived()` there, then `step()` every frame while it answers true; when it answers false the
## task is over and `finish()` is called, or `cancel()` when another order takes the resident first.
## A task moves its resident only through the brain's task_* functions. A task whose site is underground
## (a job on a segment deep in the network) names its node (`site_node`) and is walked there through it.
##
## The base does nothing and ends at once, so a bare task is harmless.


func site(brain: RefCounted) -> Vector2:
	"""Where the resident walks first (the brain's own position for the base: no walk)."""
	return brain.position


func site_node(_brain: RefCounted) -> int:
	"""The network node underground the resident walks to first instead of `site` (-1: `site`, on the
	surface; the base)."""
	return -1


func arrived(_brain: RefCounted) -> void:
	"""The resident reached the point it was walking to."""
	pass


func step(_brain: RefCounted, _delta: float) -> bool:
	"""One frame of the task; false when it is over."""
	return false


func finish(_brain: RefCounted) -> void:
	"""The task ended on its own."""
	pass


func cancel(_brain: RefCounted) -> void:
	"""Another order or a release took the resident from the task."""
	pass


func unfinished() -> RefCounted:
	"""Called away before it was done: the job to come back to (cast/unfinished_job.gd), or null when
	there is nothing to come back to (the base, an evacuation, a crew place)."""
	return null


func label() -> String:
	"""What the resident is doing, in words, for the panel."""
	return "on an errand"
