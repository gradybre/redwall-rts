# Actual public flag predicates

godot/scripts/core/inventory.gd
```gdscript
func is_transaction_open() -> bool:
	"""True while an explicit transaction is accepting operations."""
	return _tx_open
```

godot/scripts/core/inventory.gd
```gdscript
func is_transaction_poisoned() -> bool:
	"""True when an operation in the OPEN transaction refused, so commit() will roll back.

	False whenever no transaction is open: the flag is cleared as the transaction closes, so
	this predicate never reports a poisoning that belongs to a sequence already finished.
	"""
	return _tx_poisoned
```

godot/scripts/core/sim_clock.gd
```gdscript
func is_load_barrier_held() -> bool:
	"""True while a load holds this clock's barrier.

	The HUD may show LOAD from this; the pause mask never carries it, and neither does any saved
	state. It is also how a caller tells a barred command from an ordinary refusal, since a barred
	command writes no reason anywhere.
	"""
	return _load_barrier != null and _load_barrier.is_held()
```
