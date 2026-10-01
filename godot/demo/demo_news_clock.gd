extends RefCounted
## The news's own clock: real milliseconds that STAND STILL while the village is paused. Decision 0331
## (review F11). Presentation only; it decides nothing in the simulation.
##
## WHY. A toast on the news strip, a resolved incident card's last look and a snooze all run on real time
## (UI §7: "12 real seconds on HUD"), so a warning does not vanish faster at 4x. But real time also ran
## while the player had paused to read: a frost warning was gone 30 s after it was posted, whether or not
## anyone could act on it. So everything the news shows for a while is timed on THIS clock, which is real
## time with the paused stretches taken out: pausing permits reading indefinitely (the review's P1
## chronicle row), and 1x, 2x and 4x all age a toast at the same real rate.
##
## `sync()` is fed the real time and whether the village is paused, once a frame, by the news strip (the
## one news surface that always processes). Unbound or never synced, `now_msec()` is 0 and stands still.

## The clock's own reading: real milliseconds the village has spent unpaused since the clock began.
var _awake_msec: int = 0
## The real time last synced (-1: never).
var _last_real_msec: int = -1


func sync(real_msec: int, paused: bool) -> void:
	"""Advance by the real time since the last sync, unless the village is paused now (the stretch is
	then let go uncounted). A real clock that went backwards counts nothing."""
	if _last_real_msec >= 0 and not paused and real_msec > _last_real_msec:
		_awake_msec += real_msec - _last_real_msec
	_last_real_msec = real_msec


func now_msec() -> int:
	"""Real milliseconds the village has been unpaused (the news's 'now')."""
	return _awake_msec


func advance(msec: int) -> void:
	"""Move the clock on by `msec` unpaused milliseconds directly (checks, and a host without frames)."""
	_awake_msec += maxi(msec, 0)
