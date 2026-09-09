extends RefCounted
## Deterministic integer RNG for the settlement simulation.
##
## ARCH-RNG-001 fixes the algorithm: "Use the crowd's xorshift32 exactly. Read signed stored
## state with `& 0xffffffff`; replace a zero initialized state with 1. The fixed test stream
## from seed 1 begins 270369,67634689,2647435461,307599695,2398689233." Its pseudocode block
## and `docs/crowd_rendering_architecture.md` §6.1 give the identical three-shift form and the
## identical `hash_pair`; the two documents agree constant for constant, so there is nothing to
## reconcile between them. §6.1 adds the storage rule reproduced in to_stored_int32().
##
## ARCH-RNG-002 fixes everything else: the nine stream keys "in ASCII order", the per-stream
## seed `hash_pair(world.seed, stream_id + 1)` "replacing zero with 1", "Store state plus int64
## draw count", and "No other system may consume these streams".
##
## ---------------------------------------------------------------------------------------
## WHY THIS IS NOT Godot's RandomNumberGenerator. Crowd §6.1: "Godot's RNG implementation is an
## implementation detail and should not be treated as a guaranteed cross-version replay format.
## A stored seed alone is insufficient when draw order changes." Hence one explicit algorithm,
## one state per domain, and a draw counter per domain -- so a replay divergence localises to a
## named stream and a draw index rather than to "the RNG".
##
## ---------------------------------------------------------------------------------------
## MODULO, NOT REJECTION SAMPLING. ARCH-RNG-002 is explicit: "Bounded selections use modulo with
## the same disclosed small bias as the crowd document; no rejection sampling changes
## unspecified draw counts." Crowd §5.3 discloses it as "Modulo introduces a tiny known bias; it
## is acceptable for this prototype and deterministic." draw_below() therefore performs exactly
## one draw and one `%`, and the residual bias is a specified, tested property of this module --
## test_rng.gd measures its exact size rather than asserting uniformity. A rejection loop would
## consume a variable number of draws per call, which is precisely what the stated draw
## disciplines below (one roll per cycle, two rolls per candidate, ...) forbid.
##
## ---------------------------------------------------------------------------------------
## DRAW DISCIPLINES belong to the consuming systems, not to this module. ARCH-RNG-002 states
## them per stream -- ECOLOGY one wildlife-pressure roll per eligible basin/apiary at midnight,
## FISHING one hazard plus one rare-quality roll per completed eligible cycle keyed by
## expedition ID, FORAGE one hazard roll per completed 60 WU exposure segment, IMMIGRATION two
## skill-selection rolls per candidate, QUALITY one roll per committing batch with
## `R=(draw mod 21)-10`, SOCIAL one roll per eligible conflict pair at 18:00, WEATHER one
## weighted event-selection roll per new season after the forced first spring. This module
## supplies the draws and counts them; ordering, eligibility and discard rules are enforced by
## the systems that own those events, which do not exist yet.
##
## ---------------------------------------------------------------------------------------
## HUNTING IS A TOMBSTONE, NOT A GAP. `setting_rules_amendment.md` §3: "Retain existing stream
## slot/key as a tombstone initialized by the prior seed rule; draw_count remains 0 and no
## system may draw from it", and ARCH-RNG-002: "Retired stream; never draw in rules v2 | Keep
## original seed initialization and zero draw_count; noncanonical loaded values fail
## validation". So the slot exists, is seeded exactly like every other stream (keeping every
## other stream's `stream_id + 1` unchanged), draw() refuses on it, and restore_stream() rejects
## any saved value other than the canonical seed with a zero count -- REQ-SET-065's "keep them
## inactive and reject noncanonical saved data".
##
## ---------------------------------------------------------------------------------------
## REFUSALS. Nothing here returns a sentinel. Every operation that can fail returns an
## IntMath.IntResult or an OpResult whose `.ok` must be inspected first; a refusal carries value
## 0 and a reason, and mutates no column. In particular a refused draw does NOT advance state or
## the draw count, so a refusal cannot silently desynchronise a replay.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. The two packed columns are sized once in _init(); clear() refills them. Every
## operation has an `_into(..., out)` form that allocates nothing, plus a plain form that
## allocates exactly one IntResult for cold paths and tests, matching int_math.gd's contract
## (decision 0015).
##
## ---------------------------------------------------------------------------------------
## GAPS -- named, not invented (AGENTS.md "do not invent a constant"):
##   * WEATHER's roll is "weighted event-selection" over "weights normalized within the season's
##     eligible rows" (GDD §5.10). ARCH-RNG-002 fixes the DRAW COUNT at one but states no
##     mapping from that one draw to a weighted row -- no cumulative-scan direction, no
##     tie rule, no rounding rule for the normalisation. No pick_weighted() is provided here
##     because that mapping would be invented. The weather increment must resolve it.
##   * Save/load ENCODING is ARCH-SAVE-001/002's business (section 10 RNG, little-endian
##     two's-complement). This module exposes the exact integers that section must carry --
##     stored_state_of() and draw_count_of() -- and validates them on the way back in. It does
##     not write bytes.
##   * The stream key table lives here rather than in catalog.gd's protected enum table: those
##     are the eight enums GDD §4.3 numbers explicitly (decision 0018), and RNG streams are not
##     one of them. Their IDs come from ARCH-RNG-002's ASCII-order rule, asserted in _init().

const IntMath := preload("res://scripts/core/int_math.gd")

# --- ARCH-RNG-001 / crowd §6.1 arithmetic domain -------------------------------------------------

const U32_MASK: int = 0xffffffff
const U32_COUNT: int = 4294967296
## Values at or above this store as negative int32 (crowd §6.1 storage rule).
const INT32_SIGN_LIMIT: int = 2147483648
## `hash_pair` constants, byte for byte from ARCH-RNG-001's pseudocode block.
const HASH_GOLDEN: int = 0x9e3779b9
const HASH_MULTIPLIER: int = 1664525
const HASH_INCREMENT: int = 1013904223

# --- ARCH-RNG-002 stream domain ------------------------------------------------------------------

## "Compile the following stream keys in ASCII order". _init() asserts this list IS in ascending
## ASCII order, so an edit that inserts a key in the wrong place fails loudly instead of quietly
## renumbering every stream after it and invalidating every existing save.
const STREAM_KEYS: Array[String] = [
	"ECOLOGY", "FISHING", "FORAGE", "HUNTING", "IMMIGRATION",
	"MAP", "QUALITY", "SOCIAL", "WEATHER",
]
const STREAM_COUNT: int = 9

const STREAM_ECOLOGY: int = 0
const STREAM_FISHING: int = 1
const STREAM_FORAGE: int = 2
## Retired by SET-AMEND-001 §3. Seeded, never drawn. There is deliberately no active-use path.
const STREAM_HUNTING: int = 3
const STREAM_IMMIGRATION: int = 4
const STREAM_MAP: int = 5
const STREAM_QUALITY: int = 6
const STREAM_SOCIAL: int = 7
const STREAM_WEATHER: int = 8

# --- refusal codes -------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_STREAM: StringName = &"RNG_UNKNOWN_STREAM"
const REFUSE_NOT_SEEDED: StringName = &"RNG_NOT_SEEDED"
const REFUSE_RETIRED_STREAM: StringName = &"RNG_RETIRED_STREAM"
const REFUSE_ZERO_STATE: StringName = &"RNG_ZERO_STATE"
const REFUSE_STATE_OUT_OF_RANGE: StringName = &"RNG_STATE_OUT_OF_RANGE"
const REFUSE_NEGATIVE_DRAW_COUNT: StringName = &"RNG_NEGATIVE_DRAW_COUNT"
const REFUSE_NONCANONICAL_TOMBSTONE: StringName = &"RNG_NONCANONICAL_TOMBSTONE"
const REFUSE_SEED_NOT_INT32: StringName = &"RNG_SEED_NOT_INT32"
const REFUSE_BOUND_NOT_POSITIVE: StringName = &"RNG_BOUND_NOT_POSITIVE"
const REFUSE_BOUND_ABOVE_U32: StringName = &"RNG_BOUND_ABOVE_U32"
const REFUSE_RANGE_INVERTED: StringName = &"RNG_RANGE_INVERTED"
const REFUSE_RANGE_NOT_INT32: StringName = &"RNG_RANGE_NOT_INT32"
const REFUSE_DRAW_COUNT_OVERFLOW: StringName = &"RNG_DRAW_COUNT_OVERFLOW"


class OpResult:
	"""Outcome of one RNG operation: success flag, refusal code, produced value.

	`.ok` MUST be inspected before `.value` is used. A refusal carries 0 and has mutated no
	column: no state advanced and no draw counted.
	"""
	var ok: bool
	var error: StringName
	var value: int

	func _init(p_ok: bool, p_error: StringName, p_value: int) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value


# --- authoritative columns (ARCH-MEM-001: packed, allocated once) ---------------------------------

## Per-stream xorshift32 state in crowd §6.1's SIGNED storage form; read back with `& U32_MASK`.
var _state: PackedInt32Array = PackedInt32Array()
## Per-stream int64 draw count, per ARCH-RNG-002 "Store state plus int64 draw count".
var _draw_count: PackedInt64Array = PackedInt64Array()

var _seeded: bool = false
var _world_seed: int = 0


func _init() -> void:
	"""Assert the ASCII-order stream table, then allocate both columns once and clear them."""
	assert(STREAM_KEYS.size() == STREAM_COUNT,
		"ARCH-RNG-002 names exactly nine streams, including the HUNTING tombstone")
	for i: int in range(1, STREAM_COUNT):
		assert(STREAM_KEYS[i - 1] < STREAM_KEYS[i],
			"ARCH-RNG-002 compiles the stream keys in ascending ASCII order")
	assert(STREAM_KEYS[STREAM_HUNTING] == "HUNTING",
		"the retired SET-AMEND-001 §3 slot must keep its original key and position")
	_allocate_columns()
	clear()


func _allocate_columns() -> void:
	"""Size both packed columns exactly once, per ARCH-MEM-001. Never called again."""
	_state.resize(STREAM_COUNT)
	_draw_count.resize(STREAM_COUNT)


func clear() -> void:
	"""Return every stream to the unseeded state, refilling the existing buffers.

	An unseeded store holds state 0 in every slot, which is exactly the value xorshift32
	forbids, so every draw refuses until seed_world() has run.
	"""
	_state.fill(0)
	_draw_count.fill(0)
	_seeded = false
	_world_seed = 0


# --- pure algorithm (ARCH-RNG-001) ---------------------------------------------------------------

static func hash_pair(a: int, b: int) -> int:
	"""ARCH-RNG-001's integer hash of two integers into one u32. Total: every input is valid."""
	var h: int = (a ^ HASH_GOLDEN) & U32_MASK
	h = (h * HASH_MULTIPLIER + HASH_INCREMENT + (b & U32_MASK)) & U32_MASK
	h = (h ^ (h >> 16)) & U32_MASK
	return h


static func next_u32_from(state: int) -> IntMath.IntResult:
	"""One xorshift32 step from `state`, allocating one IntResult. Refuses a zero or non-u32 state."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	next_u32_from_into(state, out)
	return out


static func next_u32_from_into(state: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating next_u32_from(): write the successor u32 into `out`, return out.ok.

	Zero state is forbidden (crowd §6.1, ARCH-RNG-001) because xorshift32 fixes it: it is
	refused here rather than assert()ed, since assertions are stripped from release builds and
	a zero state would then silently produce an all-zero stream forever.
	"""
	var x: int = state & U32_MASK
	if x != state:
		return out.refuse(String(REFUSE_STATE_OUT_OF_RANGE))
	if x == 0:
		return out.refuse(String(REFUSE_ZERO_STATE))
	x = (x ^ ((x << 13) & U32_MASK)) & U32_MASK
	x = (x ^ (x >> 17)) & U32_MASK
	x = (x ^ ((x << 5) & U32_MASK)) & U32_MASK
	return out.succeed(x)


static func seeded_state_for(world_seed: int, stream_id: int) -> IntMath.IntResult:
	"""ARCH-RNG-002's per-stream seed: `hash_pair(world_seed, stream_id+1)`, zero replaced by 1.

	Exposed so a save validator can recompute a stream's canonical initial state without
	constructing a store.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if stream_id < 0 or stream_id >= STREAM_COUNT:
		out.refuse(String(REFUSE_UNKNOWN_STREAM))
		return out
	if not IntMath.fits_int32(world_seed):
		out.refuse(String(REFUSE_SEED_NOT_INT32))
		return out
	var derived: int = hash_pair(world_seed, stream_id + 1)
	out.succeed(1 if derived == 0 else derived)
	return out


# --- crowd §6.1 signed storage form ---------------------------------------------------------------

static func to_stored_int32(state: int) -> IntMath.IntResult:
	"""Convert a u32 state to the signed int32 column/save form: `s if s<2^31 else s-2^32`."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if state < 0 or state > U32_MASK:
		out.refuse(String(REFUSE_STATE_OUT_OF_RANGE))
		return out
	out.succeed(state if state < INT32_SIGN_LIMIT else state - U32_COUNT)
	return out


static func from_stored_int32(stored: int) -> IntMath.IntResult:
	"""Recover a u32 state from its signed int32 column/save form, per `& 0xffffffff`."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not IntMath.fits_int32(stored):
		out.refuse(String(REFUSE_STATE_OUT_OF_RANGE))
		return out
	out.succeed(stored & U32_MASK)
	return out


# --- stream identity ------------------------------------------------------------------------------

static func stream_id_of(key: String) -> IntMath.IntResult:
	"""ID of a named stream, or an explicit refusal for a key ARCH-RNG-002 does not list."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var index: int = STREAM_KEYS.find(key)
	if index < 0:
		out.refuse(String(REFUSE_UNKNOWN_STREAM))
		return out
	out.succeed(index)
	return out


static func stream_key_of(stream_id: int) -> String:
	"""Key of a stream ID, or the empty String for an ID outside the nine compiled streams."""
	if stream_id < 0 or stream_id >= STREAM_COUNT:
		return ""
	return STREAM_KEYS[stream_id]


static func is_retired(stream_id: int) -> bool:
	"""True only for the HUNTING tombstone retired by SET-AMEND-001 §3."""
	return stream_id == STREAM_HUNTING


# --- seeding --------------------------------------------------------------------------------------

func seed_world(world_seed: int) -> OpResult:
	"""Derive all nine stream states from the world seed and zero every draw count.

	`World.seed` is int32 (GDD §4.2); a wider value is refused rather than silently masked,
	because masking would let two different saved seeds share one stream set. The HUNTING
	tombstone is seeded here like any other stream: SET-AMEND-001 §3 requires its slot keep
	"the prior seed rule", which also keeps every later stream's `stream_id+1` unchanged.
	"""
	if not IntMath.fits_int32(world_seed):
		return OpResult.new(false, REFUSE_SEED_NOT_INT32, 0)
	for stream_id: int in range(STREAM_COUNT):
		var derived: IntMath.IntResult = seeded_state_for(world_seed, stream_id)
		if not derived.ok:
			return OpResult.new(false, REFUSE_SEED_NOT_INT32, 0)
		var stored: IntMath.IntResult = to_stored_int32(derived.value)
		if not stored.ok:
			return OpResult.new(false, REFUSE_STATE_OUT_OF_RANGE, 0)
		_state[stream_id] = stored.value
		_draw_count[stream_id] = 0
	_world_seed = world_seed
	_seeded = true
	return OpResult.new(true, REFUSE_NONE, world_seed)


func is_seeded() -> bool:
	"""True once seed_world() has succeeded and before the next clear()."""
	return _seeded


func world_seed_value() -> IntMath.IntResult:
	"""The seed the current stream states were derived from, or a refusal while unseeded."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not _seeded:
		out.refuse(String(REFUSE_NOT_SEEDED))
		return out
	out.succeed(_world_seed)
	return out


# --- validation ------------------------------------------------------------------------------------

func _check_drawable(stream_id: int) -> StringName:
	"""REFUSE_NONE when `stream_id` names a seeded, non-retired stream holding a legal state."""
	if stream_id < 0 or stream_id >= STREAM_COUNT:
		return REFUSE_UNKNOWN_STREAM
	if not _seeded:
		return REFUSE_NOT_SEEDED
	if is_retired(stream_id):
		return REFUSE_RETIRED_STREAM
	if (_state[stream_id] & U32_MASK) == 0:
		return REFUSE_ZERO_STATE
	return REFUSE_NONE


func _check_readable(stream_id: int) -> StringName:
	"""REFUSE_NONE when `stream_id` names a seeded stream. Reads are legal on the tombstone."""
	if stream_id < 0 or stream_id >= STREAM_COUNT:
		return REFUSE_UNKNOWN_STREAM
	if not _seeded:
		return REFUSE_NOT_SEEDED
	return REFUSE_NONE


# --- reads -------------------------------------------------------------------------------------------

func state_of(stream_id: int) -> IntMath.IntResult:
	"""Current u32 state of a stream. Legal on the tombstone; refuses while unseeded."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var code: StringName = _check_readable(stream_id)
	if code != REFUSE_NONE:
		out.refuse(String(code))
		return out
	out.succeed(_state[stream_id] & U32_MASK)
	return out


func stored_state_of(stream_id: int) -> IntMath.IntResult:
	"""Current state in crowd §6.1's signed int32 form -- the integer a save writes."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var code: StringName = _check_readable(stream_id)
	if code != REFUSE_NONE:
		out.refuse(String(code))
		return out
	out.succeed(_state[stream_id])
	return out


func draw_count_of(stream_id: int) -> IntMath.IntResult:
	"""Draws taken from a stream since seeding. Always 0 for the HUNTING tombstone."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var code: StringName = _check_readable(stream_id)
	if code != REFUSE_NONE:
		out.refuse(String(code))
		return out
	out.succeed(_draw_count[stream_id])
	return out


# --- draws ---------------------------------------------------------------------------------------------

func draw(stream_id: int) -> IntMath.IntResult:
	"""One raw u32 draw from a stream, allocating one IntResult. See draw_into() for the contract."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	draw_into(stream_id, out)
	return out


func draw_into(stream_id: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating draw(): advance the stream once, count it, write the u32 into `out`.

	Exactly one state advance and exactly one increment of that stream's own draw count. A
	refusal -- unknown stream, unseeded store, the retired HUNTING slot, an illegal state, or a
	draw count at int64 maximum -- advances nothing and counts nothing, so replay cannot drift
	past a rejected call.
	"""
	var code: StringName = _check_drawable(stream_id)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	if not IntMath.checked_add_into(_draw_count[stream_id], 1, out):
		return out.refuse(String(REFUSE_DRAW_COUNT_OVERFLOW))
	var next_count: int = out.value
	if not next_u32_from_into(_state[stream_id] & U32_MASK, out):
		return false
	var stored: int = out.value if out.value < INT32_SIGN_LIMIT else out.value - U32_COUNT
	_state[stream_id] = stored
	_draw_count[stream_id] = next_count
	return true


func draw_below(stream_id: int, bound: int) -> IntMath.IntResult:
	"""One draw reduced to `[0, bound)`, allocating one IntResult. See draw_below_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	draw_below_into(stream_id, bound, out)
	return out


func draw_below_into(stream_id: int, bound: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating draw_below(): one draw, reduced by modulo, written into `out`.

	ARCH-RNG-002: "Bounded selections use modulo with the same disclosed small bias as the crowd
	document; no rejection sampling changes unspecified draw counts." So this consumes exactly
	one draw for every bound, and values below `2^32 mod bound` are drawn one extra time in
	2^32 -- the disclosed bias, measured in test_rng.gd rather than assumed away. The bound is
	validated BEFORE the draw, so a refused call consumes nothing.
	"""
	if bound <= 0:
		return out.refuse(String(REFUSE_BOUND_NOT_POSITIVE))
	if bound > U32_COUNT:
		return out.refuse(String(REFUSE_BOUND_ABOVE_U32))
	if not draw_into(stream_id, out):
		return false
	return out.succeed(out.value % bound)


func draw_in_range(stream_id: int, low: int, high: int) -> IntMath.IntResult:
	"""One draw reduced to the inclusive range `[low, high]`, allocating one IntResult."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	draw_in_range_into(stream_id, low, high, out)
	return out


func draw_in_range_into(stream_id: int, low: int, high: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating draw_in_range(): `low + (draw % (high-low+1))`, inclusive at both ends.

	This is the shape GDD §5.7 states for QUALITY, "R is deterministic integer -10..10 once per
	batch", which ARCH-RNG-002 pins to `R=(draw mod 21)-10`: draw_in_range(QUALITY, -10, 10) is
	that expression exactly. One draw, same disclosed modulo bias as draw_below_into().

	Both bounds must fit int32: every stochastic range in the settlement rules is an int32
	quantity, and confining them here means `high - low + 1` cannot overflow int64.
	"""
	if not IntMath.fits_int32(low) or not IntMath.fits_int32(high):
		return out.refuse(String(REFUSE_RANGE_NOT_INT32))
	if high < low:
		return out.refuse(String(REFUSE_RANGE_INVERTED))
	var span: int = high - low + 1
	if not draw_below_into(stream_id, span, out):
		return false
	return out.succeed(low + out.value)


# --- save / restore -----------------------------------------------------------------------------------

func restore_stream(stream_id: int, state: int, draw_count: int) -> OpResult:
	"""Restore one stream's u32 state and draw count from a save, validating both.

	ARCH-SAVE-005's posture applies: reject rather than clamp. Zero state, a state outside u32,
	a negative draw count, an unknown stream and an unseeded store are all refused. The store
	must already be seeded because the HUNTING tombstone's canonical value is defined against
	the world seed, and ARCH-RNG-002 requires "noncanonical loaded values fail validation".
	"""
	var code: StringName = _check_readable(stream_id)
	if code != REFUSE_NONE:
		return OpResult.new(false, code, 0)
	if state < 0 or state > U32_MASK:
		return OpResult.new(false, REFUSE_STATE_OUT_OF_RANGE, 0)
	if state == 0:
		return OpResult.new(false, REFUSE_ZERO_STATE, 0)
	if draw_count < 0:
		return OpResult.new(false, REFUSE_NEGATIVE_DRAW_COUNT, 0)
	if is_retired(stream_id) and not _tombstone_is_canonical(state, draw_count):
		return OpResult.new(false, REFUSE_NONCANONICAL_TOMBSTONE, 0)
	_state[stream_id] = state if state < INT32_SIGN_LIMIT else state - U32_COUNT
	_draw_count[stream_id] = draw_count
	return OpResult.new(true, REFUSE_NONE, state)


func _tombstone_is_canonical(state: int, draw_count: int) -> bool:
	"""True when a loaded HUNTING pair is the untouched seed with a zero count (SET-AMEND-001 §3)."""
	if draw_count != 0:
		return false
	var canonical: IntMath.IntResult = seeded_state_for(_world_seed, STREAM_HUNTING)
	return canonical.ok and canonical.value == state


func tombstone_is_intact() -> bool:
	"""True when HUNTING still holds its canonical seed and a zero draw count.

	REQ-SET-065 requires the retained slot stay inactive; a caller can assert this after a load
	or at a tick boundary without needing the seed rule itself.
	"""
	if not _seeded:
		return false
	return _tombstone_is_canonical(_state[STREAM_HUNTING] & U32_MASK, _draw_count[STREAM_HUNTING])
