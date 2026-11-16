extends RefCounted
## Decision 1936 (review H4): the one Jobs dispatcher of the mounted underground. Jobs keeps a single dispatcher
## (ADR1223); the entry runtime and the room-dig runtime both need one, so the host binds this composite once and it
## asks whichever runtimes the host currently holds. A Job either owns is owned; a resident either reserves is
## reserved. The pairing is sound because each foreman assigns only its own Jobs to its own crew, and Jobs refuses a
## reserved resident before the JobSelector scans anything (`REFUSE_AGENT_RESERVED`), so no owned Job is ever offered.
## It keeps no state of its own: the answers are the runtimes', derived from saved state.

const PATH: String = "res://scripts/core/underground_dispatch.gd"

var _entry: Callable = Callable() # Returns the host's current entry runtime, or null.
var _rooms: Callable = Callable() # Returns the host's current room-dig runtime, or null.


func configure(entry_source: Callable, rooms_source: Callable) -> bool:
	"""Borrow the host's two runtime readers once; both must be callable."""
	if _entry.is_valid() or not entry_source.is_valid() or not rooms_source.is_valid(): return false
	_entry = entry_source
	_rooms = rooms_source
	return true


func bind(jobs: RefCounted) -> StringName:
	"""Install this composite as Jobs' one dispatcher (a runtime that later binds itself defers to it)."""
	if not _entry.is_valid() or jobs == null: return &"UNDERGROUND_DISPATCH_SCOPE"
	var bound: RefCounted = jobs.bind_dispatcher(owns_job, reserves_resident)
	return &"" if bound.ok else bound.error


static func bound_to(jobs: RefCounted) -> bool:
	"""Jobs' dispatcher is a composite of this script: a runtime must not replace it with its own answers."""
	if jobs == null or not jobs._dispatch_owns.is_valid(): return false
	var owner: Object = jobs._dispatch_owns.get_object()
	return owner != null and owner.get_script() != null and owner.get_script().resource_path == PATH


func owns_job(job_slot: int) -> bool:
	"""Either runtime owns the Job."""
	var entry: RefCounted = _entry.call()
	if entry != null and entry.owns_job(job_slot): return true
	var rooms: RefCounted = _rooms.call()
	return rooms != null and rooms.owns_job(job_slot)


func reserves_resident(resident_slot: int) -> bool:
	"""Either runtime reserves the resident."""
	var entry: RefCounted = _entry.call()
	if entry != null and entry.reserves_resident(resident_slot): return true
	var rooms: RefCounted = _rooms.call()
	return rooms != null and rooms.reserves_resident(resident_slot)
