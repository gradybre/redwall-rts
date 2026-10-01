extends RefCounted
## The playtest log's FREEZE WATCH: a thread that notices when no frame has been drawn for a while (decision
## 0562). DEMO DIAGNOSTICS.
##
## WHY A THREAD. The session also measures every frame's length on the main thread and logs a freeze when the game
## recovers (playtest_session.gd `frame`). That says nothing about a hang the tester ends by killing the game. This
## thread wakes every POLL_MSEC, and once the main thread's last `beat` is older than the threshold it calls
## `on_freeze(stalled_usec)` -- ONCE per stall -- from this thread, so the session can write the freeze and the
## last breadcrumbs while the main thread is still stuck.
##
## THE THRESHOLD is the host's: long while loading (a boot or a restart may hold one frame for seconds), short
## once the village runs (`set_threshold_usec`).
##
## COST. `beat` is a lock, an int write and an unlock: no allocation. `stop` must be called before the session
## lets go of this object (it joins the thread); the session's `stop` does.

const POLL_MSEC: int = 200

## `(stalled_usec: int) -> void`, called from the watch thread; it must touch nothing but thread-safe state.
var on_freeze: Callable = Callable()

var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _stop: bool = false
var _last_beat_usec: int = 0
var _threshold_usec: int = 0
## The beat a freeze was last reported for (one report per stall).
var _reported_beat_usec: int = -1
var _reports: int = 0


func start(threshold_usec: int) -> bool:
	"""Start watching from now with `threshold_usec`. False when already running or the thread did not start."""
	if _thread != null:
		return false
	set_threshold_usec(threshold_usec)
	beat(Time.get_ticks_usec())
	_stop = false
	_thread = Thread.new()
	if _thread.start(_run, Thread.PRIORITY_LOW) != OK:
		_thread = null
		return false
	return true


func running() -> bool:
	"""Whether the thread is running."""
	return _thread != null


func beat(now_usec: int) -> void:
	"""The main thread drew a frame at `now_usec`."""
	_mutex.lock()
	_last_beat_usec = now_usec
	_mutex.unlock()


func set_threshold_usec(threshold_usec: int) -> void:
	"""How long without a beat counts as a freeze."""
	_mutex.lock()
	_threshold_usec = threshold_usec
	_mutex.unlock()


func reports() -> int:
	"""Freezes reported so far."""
	_mutex.lock()
	var count: int = _reports
	_mutex.unlock()
	return count


func check(now_usec: int) -> int:
	"""One look at the clock: the stall in microseconds when it is a freeze not yet reported, else 0. The thread
	calls this every POLL_MSEC; tests call it directly."""
	_mutex.lock()
	var stalled: int = now_usec - _last_beat_usec
	var fresh: bool = stalled >= _threshold_usec and _threshold_usec > 0 and _reported_beat_usec != _last_beat_usec
	if fresh:
		_reported_beat_usec = _last_beat_usec
		_reports += 1
	_mutex.unlock()
	return stalled if fresh else 0


func stop() -> void:
	"""Stop and join the thread (safe to call twice)."""
	if _thread == null:
		return
	_mutex.lock()
	_stop = true
	_mutex.unlock()
	_thread.wait_to_finish()
	_thread = null


func _run() -> void:
	"""The watch loop (on the thread)."""
	while true:
		OS.delay_msec(POLL_MSEC)
		_mutex.lock()
		var stopping: bool = _stop
		_mutex.unlock()
		if stopping:
			return
		var stalled: int = check(Time.get_ticks_usec())
		if stalled > 0 and on_freeze.is_valid():
			on_freeze.call(stalled)
