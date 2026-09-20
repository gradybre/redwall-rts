# Bound API excerpts

Exact current source excerpts; whole-file SHA named for provenance.

## inventory.gd SHA256 28ae01f313261b234bf11661e48ea3e8eac2bbe8e95a63b1234185f349727d39
```gdscript
func is_transaction_open() -> bool:
	"""True while an explicit transaction is accepting operations."""
	return _tx_open
```
```gdscript
func is_transaction_poisoned() -> bool:
	"""True when an operation in the OPEN transaction refused, so commit() will roll back.

	False whenever no transaction is open: the flag is cleared as the transaction closes, so
	this predicate never reports a poisoning that belongs to a sequence already finished.
	"""
	return _tx_poisoned
```

## sim_clock.gd SHA256 a5c6282467092ee85a69a183f2405caf96c68355af2fdc1d181c9c7bf25c645a
```gdscript
func is_load_barrier_held() -> bool:
	"""True while a load holds this clock's barrier.

	The HUD may show LOAD from this; the pause mask never carries it, and neither does any saved
	state. It is also how a caller tells a barred command from an ordinary refusal, since a barred
	command writes no reason anywhere.
	"""
	return _load_barrier != null and _load_barrier.is_held()
```

## item_definitions.gd SHA256 4e745577260b8cbb7b16370ebb6f5be05c9441eb8b6976e5022f734814175551
```gdscript
func is_loaded() -> bool:
	"""True once load_from_file()/load_default() has fully succeeded on this instance."""
	return _loaded
```
SimClock.LoadBarrier.is_held() returns its bool _held field, without mutation.
