extends RefCounted
## REDUCED MOTION, as the demo's moving presentation reads it. Decision 0471 (review UX-023; UI §8.1 `reduced_motion`,
## "disables all nonessential UI/camera smoothing/fades"; UX-T13). Presentation only: nothing here changes what
## happens or when -- an action's timing, the clock and every number are untouched (REQ-UX-008).
##
## With `reduced` on:
##   * the camera stops easing: every pan, turn, zoom and "Go to" lands at once (demo_camera.gd `step`);
##   * the selection rings, a swimmer's ripple ring and the mound over a digger stop pulsing (`pulse`:
##     demo_command.gd, swim_view.gd, tunnel_overlay.gd);
##   * every particle system -- chips, dust, smoke, splashes, flames, the dig's clods -- emits PARTICLE_RATIO of
##     its particles (`apply_particles`, on each one as it enters the tree and on all of them when the setting
##     changes);
##   * the rain and snow veils fall thinner (the same ratio) and VEIL_SPEED as fast (weather_view.gd).
## The demo has no camera shake to turn down.

## The share of each particle system's particles kept with reduced motion on.
const PARTICLE_RATIO: float = 0.35
## The rain's and snow's fall speed with reduced motion on (of the game's speed).
const VEIL_SPEED: float = 0.5
## Where a particle system keeps its full count while it is reduced.
const FULL_AMOUNT: StringName = &"demo_full_amount"

static var reduced: bool = false


static func pulse(wave: float) -> float:
	"""A pulsing size factor `wave` (about 1.0), or exactly 1.0 with reduced motion: still."""
	return 1.0 if reduced else wave


static func veil_speed() -> float:
	"""The rain's and snow's speed factor (1.0, or VEIL_SPEED with reduced motion)."""
	return VEIL_SPEED if reduced else 1.0


static func apply_particles(node: Node) -> void:
	"""Bring one particle system to the setting: PARTICLE_RATIO of its full count with reduced motion, all of it
	without. Anything else is left alone. The full count is remembered on the node the first time it is cut."""
	var cpu := node as CPUParticles3D
	if cpu != null:
		var want: int = _amount_for(cpu, cpu.amount)
		if cpu.amount != want:
			cpu.amount = want
		return
	var gpu := node as GPUParticles3D
	if gpu != null:
		gpu.amount_ratio = PARTICLE_RATIO if reduced else 1.0


static func _amount_for(node: Node, amount: int) -> int:
	"""The count a CPU system should emit now (at least one), remembering its full count."""
	if not node.has_meta(FULL_AMOUNT):
		if not reduced:
			return amount
		node.set_meta(FULL_AMOUNT, amount)
	var full: int = int(node.get_meta(FULL_AMOUNT))
	return maxi(1, int(float(full) * PARTICLE_RATIO)) if reduced else full


static func apply_tree(root: Node) -> int:
	"""Bring every particle system under `root` to the setting; returns how many it touched."""
	var touched: int = 0
	if root is CPUParticles3D or root is GPUParticles3D:
		apply_particles(root)
		touched += 1
	for child: Node in root.get_children():
		touched += apply_tree(child)
	return touched
