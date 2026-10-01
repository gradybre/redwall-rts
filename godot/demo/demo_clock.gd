extends RefCounted
## The live demo's one presentation clock. Decision 0196. Everything in the demo that moves with
## the game's time -- the residents' walking, turning and work timers, digging and walking tunnels,
## the mound over a digger, and every resident's AnimationPlayer -- reads its seconds HERE, so the
## HUD's pause and 1x / 2x / 4x buttons govern the whole village at once. The camera, the HUD, the
## demo party panel and the selection and order marks stay on real time: they are the player's
## hands, and must work while the world is paused (UI §1.1).
##
## SPEED comes from the bound source's `get_effective_speed()` -- the GameManager autoload in the
## demo, or a test's own instance -- read once per frame: 0 while any pause reason is held, else
## the requested 1, 2 or 4 (AGENTS.md: there is no 3x). Unbound, the clock runs at 1x.
##
## TIME IS COUNTED IN WHOLE MICROSECONDS. A frame's real delta is rounded to microseconds ONCE and
## then multiplied by the speed, so 2x is exactly twice 1x in every consumer, including the tunnel's
## integer dig clock (which credits microseconds). A frame's demo time is handed out in `steps()`
## sub-steps no longer than MAX_STEP_USEC, split in integer microseconds, so a slow frame at 4x
## never makes one walker step a quarter of a metre at once.
##
## Presentation only: nothing here feeds the simulation, whose own clock this merely reads.

const GameManagerScript := preload("res://scripts/systems/game_manager.gd")

const USEC_PER_SECOND: int = 1000000
## The longest single sub-step handed to a walker: a 30 Hz frame's worth.
const MAX_STEP_USEC: int = 33334

## The effective speed this frame (0, 1, 2 or 4) and the demo microseconds it covers.
var speed: int = 1
var frame_usec: int = 0

var _source: GameManagerScript = null


func bind(source: GameManagerScript) -> void:
	"""Take the effective speed from `source` (null: run at 1x)."""
	_source = source


func advance(real_delta: float) -> void:
	"""Start a frame of `real_delta` real seconds: read the speed, and how many demo microseconds pass."""
	speed = _source.get_effective_speed() if _source != null else 1
	frame_usec = roundi(real_delta * float(USEC_PER_SECOND)) * speed


func delta_s() -> float:
	"""This frame's demo time, in seconds (0 while paused)."""
	return float(frame_usec) / float(USEC_PER_SECOND)


func steps() -> int:
	"""How many sub-steps this frame's demo time is handed out in (0 while paused)."""
	return ceili(float(frame_usec) / float(MAX_STEP_USEC))


func step_usec(k: int) -> int:
	"""Sub-step `k`'s share of this frame, in microseconds: an even split, the remainder going one
	microsecond at a time to the first sub-steps, so the shares add up exactly."""
	var count := steps()
	return frame_usec / count + (1 if k < frame_usec % count else 0)


func step_s(k: int) -> float:
	"""Sub-step `k`'s share of this frame, in seconds."""
	return float(step_usec(k)) / float(USEC_PER_SECOND)
