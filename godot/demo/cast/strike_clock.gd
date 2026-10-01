extends RefCounted
## When a digger at the dig face swings its pick: ONCE PER STRIKE. Decision 0371 (the underground revamp's P7; decision
## 0204: Meshy's Heavy_Hammer_Swing ends turned 68-81 degrees from where it began, so a looped swing snaps back each
## cycle). Presentation only: the swing changes nothing the dig does.
##
## A dig cuts its quanta one by one (underground_graph.gd `cut_count`; the face's clods burst at each, dig_theatre.gd).
## The digger owes ONE swing for each quantum: the first as it reaches the face (or a new face: the count going down),
## then one for every cut. Once the time
## between cuts is known (`period`, eased over the cuts seen) a swing is started so its blow -- `impact_s` into the clip,
## measured off the clip at staging -- lands as the next cut falls; until then, as soon as the swing is owed. Between
## swings the digger stands for at least REST_S (demo_actor.gd blends it back to its stance, so the swing's turn eases
## out instead of snapping). A dig quicker than a swing gets its swings back to back, never more than one a cut.
## Everything runs on demo time: paused, nothing moves; at 4x, four times as fast.

## The least time a digger stands between two swings (s): the blend back out of the last one.
const REST_S: float = 0.35

## The swing clip's length and the moment of its blow (s; demo_actor.gd sets both from the staged clip).
var swing_s: float = 1.87
var impact_s: float = 1.73
## Swings started so far (checks).
var swings: int = 0
var _cuts: int = -1
var _since_cut: float = 0.0
var _period: float = -1.0
var _owed: bool = true
var _left: float = 0.0
var _rest: float = 0.0


func reset() -> void:
	"""Forget the dig: the next step is a digger reaching a face, owed its first swing."""
	_cuts = -1
	_since_cut = 0.0
	_period = -1.0
	_owed = true
	_left = 0.0
	_rest = 0.0


func _begin(cuts: int) -> void:
	"""A face reached with `cuts` cut: the first step, or a count that went DOWN -- a new dig begun inside one frame
	(demo_actor.gd sees no step off the face to `reset` on at 4x) -- owes its first swing at once."""
	_cuts = cuts
	_since_cut = 0.0
	_period = -1.0
	_owed = true


func swinging() -> bool:
	"""Whether a swing is playing now."""
	return _left > 0.0


func period() -> float:
	"""The time between cuts, as eased so far (s; negative before the first cut)."""
	return _period


func step(cuts: int, delta_s: float) -> bool:
	"""Advance `delta_s` of demo time with the dig's cut count now; true when a swing starts on this step."""
	if _cuts < 0 or cuts < _cuts:
		_begin(cuts)
	_since_cut += delta_s
	if cuts > _cuts:
		_period = _since_cut if _period < 0.0 else lerpf(_period, _since_cut, 0.5)
		_since_cut = 0.0
		_cuts = cuts
		_owed = true
	if _left > 0.0:
		_left -= delta_s
		if _left <= 0.0:
			_rest = REST_S
		return false
	_rest = maxf(_rest - delta_s, 0.0)
	if not _owed or _rest > 0.0 or (_period > 0.0 and _since_cut < _period - impact_s):
		return false
	_owed = false
	_left = swing_s
	swings += 1
	return true
