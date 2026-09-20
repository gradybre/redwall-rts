# Existing test subclass syntax reference

Source: `godot/test/test_commands_arena_restore.gd`, SHA256 `a261a55e995ea72826962df346bbe3f231e957d4710188b6d05db0add432ba0d`, lines292–318. This is an existing test pattern, not execution evidence for a starter subclass.

```gdscript
class FaultScheduler extends Scheduler:
	"""Force a public install refusal after the real preflight succeeds."""
	var observing: Commands = null
	var observed_count: int = -1
	func restore_extension(_bytes: PackedByteArray, _offset: int, _tick: int) -> bool:
		"""Refuse without writing or fabricating a diagnostic, exercising the adapter fallback."""
		if observing != null:
			observed_count = observing.pending_count()
		return false


class FaultCommands extends Commands:
	"""Permit install, then refuse the public recovery call; no production fault switches."""
	var calls_until_failure: int = 1

	func restore_pending_window(records: PackedByteArray, arena: PackedByteArray,
			high: int, low: int) -> bool:
		"""Fail exactly the configured public restore call without mutating the owner."""
		if calls_until_failure == 0:
			return false
		calls_until_failure -= 1
		return super.restore_pending_window(records, arena, high, low)


func _saved_pair() -> Pending.Record:
	"""A real incoming economic command and scheduler event, captured before any barrier."""
	assert_true(_queue.submit_into(_command(), _result), "source economic command")
```
