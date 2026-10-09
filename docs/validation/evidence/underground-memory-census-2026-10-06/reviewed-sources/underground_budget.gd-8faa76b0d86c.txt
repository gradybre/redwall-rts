extends RefCounted
## Joint technical allocation limits. Passing admission is not movement, save or RAM qualification.
## One instance belongs to the actual composed world; all cold consumers share its exact lease.

const REGION_CAPACITY: int = 6144
const SOURCE_CAPACITY: int = 2048
const PROOF_CAPACITY: int = 256
const PHASE_VOLUME_CAPACITY: int = 8192
const TIP_CAPACITY: int = 256
const LAYOUT_ROOM_CAPACITY: int = 256
const LAYOUT_PLACEMENT_CAPACITY: int = 1024
const LOCATION_CAPACITY: int = 1024
const INVENTORY_ENDPOINT_CAPACITY: int = 1024
const SPACE_BANK_BYTES: int = 149 * REGION_CAPACITY + 92 * SOURCE_CAPACITY + 288
const SPACE_WIRE_BYTES: int = 68 * REGION_CAPACITY + 42 * SOURCE_CAPACITY + 144
const PROOF_BYTES: int = 69 * PROOF_CAPACITY + 60
const COLD_BYTES: int = 120 * PHASE_VOLUME_CAPACITY + 32 * SOURCE_CAPACITY + 384
const LOCATION_AND_TOPOLOGY_BYTES: int = 1048576
const INVENTORY_EXTENSION_BYTES: int = 131072
const PROFILE_BYTES: int = 262144
const TERRAIN_BYTES: int = 131072
const LAYOUT_COLD_BYTES: int = 262144
const BINDINGS_AND_GROWTH_BYTES: int = 524288
const I64_MAX: int = 9223372036854775807
const REFUSE_BUSY: StringName = &"UNDERGROUND_COLD_BUSY"
const REFUSE_BYTES: StringName = &"UNDERGROUND_COLD_CAPACITY"
const REFUSE_TOKEN: StringName = &"UNDERGROUND_COLD_LEASE"

var _next_token: int = 1
var _token: int = 0
var _used: int = 0
var _peak: int = 0


func admission_refusal(bytes: int) -> StringName:
	"""Check the whole simultaneous request before constructing any cold image or changing the lease."""
	if bytes < 1 or bytes > COLD_BYTES:
		return REFUSE_BYTES
	if _token != 0 or _next_token >= I64_MAX:
		return REFUSE_BUSY
	return &""


func acquire(bytes: int) -> int:
	"""Reserve one synchronous operation; zero grants no permission and changes no accounting."""
	if admission_refusal(bytes) != &"":
		return 0
	_token = _next_token
	_next_token += 1
	_used = bytes
	_peak = maxi(_peak, _used)
	return _token


func extend(token: int, extra_bytes: int) -> StringName:
	"""A nested companion must charge its coexistence to the same operation before allocating."""
	if token <= 0 or token != _token:
		return REFUSE_TOKEN
	if extra_bytes < 0 or extra_bytes > COLD_BYTES - _used:
		return REFUSE_BYTES
	_used += extra_bytes
	_peak = maxi(_peak, _used)
	return &""


func release(token: int) -> StringName:
	"""Release only the exact active operation after every charged image and companion is discarded."""
	if token <= 0 or token != _token:
		return REFUSE_TOKEN
	_token = 0
	_used = 0
	return &""


func covers(token: int, bytes: int) -> bool:
	"""Attest this exact arena's live token and retained positive charge without changing it."""
	return token > 0 and token == _token and bytes > 0 and bytes <= _used


func used_bytes() -> int:
	"""Return currently reserved logical payload, not allocator or operating-system memory."""
	return _used


func peak_reserved_bytes() -> int:
	"""Expose the observed reservation peak without calling it measured native allocation."""
	return _peak


func is_quiescent() -> bool:
	"""A composed save or world replacement cannot cross a live cold-operation lease."""
	return _token == 0 and _used == 0
