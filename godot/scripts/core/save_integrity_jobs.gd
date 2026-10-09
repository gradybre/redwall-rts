extends RefCounted
## The save file's integrity hashes, computed on worker threads (ADR 1235).
##
## A whole save's fifteen section CRC-32s and its body SHA-256 are pure functions of immutable
## bytes, each a single native call (`save_header.gd`). `CrcJob` folds every section in a
## WorkerThreadPool group task; `DigestJob` hashes `[264, EOF)` in one task. The main thread
## meanwhile does the work that does not need them (the section 15 walk on a save; the section
## decode and digest walk on a load) and then collects the numbers, judging them in exactly the
## order the sequential code did. No simulation state is read or written off the main thread:
## each job reads only the byte arrays it was handed, through its own references.
##
## A job is always collected (`values()` / `digest()`), and one dropped uncollected waits for its
## task as it is freed, so no task can outlive the bytes or the cells it writes.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const SaveHeader := preload("res://scripts/core/save_header.gd")


class Cell:
	"""One section's bytes and, once its task ran, its CRC-32."""
	var bytes: PackedByteArray = PackedByteArray()
	var crc32: int = 0

	func _init(p_bytes: PackedByteArray) -> void:
		"""Hold the section's bytes."""
		bytes = p_bytes


class CrcJob:
	"""The CRC-32 of each of `sections`, one group task per section."""
	var _cells: Array[Cell] = []
	var _group: int = -1

	func _init(sections: Array[PackedByteArray]) -> void:
		"""Start one task per section. The byte-loop fallback's lookup table is built here, on this
		thread, so no worker ever fills it."""
		SaveHeader._crc_lookup()
		for bytes: PackedByteArray in sections:
			_cells.append(Cell.new(bytes))
		if not _cells.is_empty():
			_group = WorkerThreadPool.add_group_task(_fold, _cells.size(), -1, true,
				"save section CRC-32")

	func _fold(index: int) -> void:
		"""Worker: one section's CRC-32 into its own cell."""
		_cells[index].crc32 = SaveHeader.crc32_of(_cells[index].bytes)

	func count() -> int:
		"""How many sections this job folds."""
		return _cells.size()

	func values() -> PackedInt64Array:
		"""Wait for every task, then the CRCs in section order."""
		_wait()
		var crcs: PackedInt64Array = PackedInt64Array()
		for cell: Cell in _cells:
			crcs.append(cell.crc32)
		return crcs

	func values_for(sections: Array[PackedByteArray]) -> PackedInt64Array:
		"""The CRCs, but only when each folded section is still byte-identical to `sections`;
		otherwise empty, so the caller folds them again rather than trusting a stale one."""
		var crcs: PackedInt64Array = values()
		for index: int in _cells.size():
			if index >= sections.size() or _cells[index].bytes != sections[index]:
				return PackedInt64Array()
		return crcs

	func _wait() -> void:
		"""Block until the group task has finished (once)."""
		if _group >= 0:
			WorkerThreadPool.wait_for_group_task_completion(_group)
			_group = -1

	func _notification(what: int) -> void:
		"""Never free the cells under a running task (inline: no method call while freeing)."""
		if what == NOTIFICATION_PREDELETE and _group >= 0:
			WorkerThreadPool.wait_for_group_task_completion(_group)
			_group = -1


class DigestJob:
	"""SAVE-REPLAY-R01's offset-232 body digest of `bytes`, on one worker task."""
	var _bytes: PackedByteArray = PackedByteArray()
	var _digest: PackedByteArray = PackedByteArray()
	var _task: int = -1

	func _init(bytes: PackedByteArray) -> void:
		"""Start hashing `bytes`."""
		_bytes = bytes
		_task = WorkerThreadPool.add_task(_hash, true, "save body SHA-256")

	func _hash() -> void:
		"""Worker: the body digest."""
		_digest = SaveHeader.compute_body_digest(_bytes)

	func digest() -> PackedByteArray:
		"""Wait for the task, then the 32-byte digest (empty for a buffer shorter than a header)."""
		_wait()
		return _digest

	func _wait() -> void:
		"""Block until the task has finished (once)."""
		if _task >= 0:
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1

	func _notification(what: int) -> void:
		"""Never free the bytes under a running task (inline: no method call while freeing)."""
		if what == NOTIFICATION_PREDELETE and _task >= 0:
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
