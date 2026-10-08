extends RefCounted
## Hands the GameManager AUTOLOAD back to the next suite with a fresh, unadvanced clock.
##
## The autoload outlives every suite in a run, and a SettlementSystem built with `.new()` still
## reads it: `_ensure_command_clock()` rebinds the settlement's command queue to
## `GameManager.clock()` after its first drain. A suite that advanced the autoload to tick N and
## left it there makes every later settlement stamp its commands at N+1, past any tick a test's
## private GameManager will reach, so those commands never drain and stamped replays refuse as
## TICK_IN_PAST. That passed alone and failed only in the full run (decision 1236).
##
## So a suite that drives the autoload's clock calls `release()` from its `after_each()`.


static func release() -> bool:
	"""Unbind, replace the autoload clock with a tick-0 one, and empty its scheduler queue.

	`start_game()` is the one API that installs a fresh clock; the player resume it queues is
	dropped with the rest of the queue, so nothing is left pending for the next suite. Returns
	false when the autoload refused the fresh clock (a load barrier left standing).
	"""
	GameManager.unbind_simulation()
	var fresh: bool = GameManager.start_game()
	GameManager.scheduler_events().clear()
	return fresh and GameManager.clock().completed_tick() == 0
