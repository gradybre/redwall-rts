extends Node
## The scale test's end-of-processing mark (decision 0561): it runs last in every frame's processing (priority 100000)
## and tells its driver when (scale_driver.gd `process_end_usec`).

var driver: Node = null


func _process(_delta: float) -> void:
	"""Stamp the end of this frame's processing."""
	if driver != null:
		driver.set(&"process_end_usec", Time.get_ticks_usec())
