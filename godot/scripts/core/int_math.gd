extends RefCounted
## Checked integer arithmetic core for authoritative simulation values.
##
## ARCH-AUTH-002/003 and BAL-AUTH-002/BAL-NUM-001 require every authoritative decision to use
## integer arithmetic, positive-only denominators, retained sub-unit remainders, and an explicit
## refusal on int64 overflow rather than a silent wrap or truncation. GDScript's `int` is already
## 64-bit, so "int64 before narrowing" means every checked operation here stays in that 64-bit
## space; a caller narrows to int32 only at the storage boundary, via narrow_to_int32().
##
## Every checked operation returns an IntResult instead of raising or trusting the caller: `.ok`
## MUST be inspected before `.value` is used. Nothing here ever wraps a bad input into a plausible
## looking answer.
##
## ALLOCATION (task 2.7, decision 0015). Every operation exists twice. The `*_into()` form takes a
## caller-owned IntResult, writes the outcome into it, and returns the same `ok` flag as a bool, so
## a hot path allocates nothing per operation. The plain form allocates exactly one IntResult and
## delegates to the `*_into()` form, for cold paths, tests and callers that want to keep a result.
## Both refuse identically: neither ever encodes a refusal as an in-band value. A refused
## `*_into()` call leaves `out.ok == false`, `out.value == 0` and `out.error` non-empty, so
## ignoring the bool return still cannot yield a plausible looking number (ARCH-AUTH-003, and the
## finding H4 sentinel that this module must never reintroduce).
##
## ALIASING. The `*_into()` forms are static and hold no shared state, so the only scratch object
## involved is the one the caller passes. A caller reusing one scratch across several calls MUST
## copy `out.value` into a local before the next call; every caller in this repository does.
##
## Persistence note (blocker U1): this module never emits or hashes a catalog file; see
## catalog.gd for the corresponding in-memory-only compile step and its U1 comment.

const IntMathScript := preload("res://scripts/core/int_math.gd")

const INT64_MAX: int = 9223372036854775807
const INT64_MIN: int = -9223372036854775807 - 1
const INT32_MAX: int = 2147483647
const INT32_MIN: int = -2147483648


class IntResult:
	"""Outcome of one checked integer operation: success flag, resulting value, refusal reason."""
	var ok: bool
	var value: int
	var error: String

	func _init(p_ok: bool = false, p_value: int = 0, p_error: String = "") -> void:
		"""Store the outcome fields for this checked operation."""
		ok = p_ok
		value = p_value
		error = p_error

	func succeed(p_value: int) -> bool:
		"""Record a successful outcome carrying p_value; always returns true."""
		ok = true
		value = p_value
		error = ""
		return true

	func refuse(p_error: String) -> bool:
		"""Record a refusal with a reason and a zeroed value; always returns false.

		The value is zeroed rather than left stale so an ignored refusal cannot surface an
		earlier operation's number as if it were this one's answer.
		"""
		ok = false
		value = 0
		error = p_error
		return false


class RemainderAccumulator:
	"""Retains the sub-unit remainder of a nonnegative rational rate across many integration steps.

	BAL-NUM-001 requires carrying a rate's fractional remainder across ticks, task switches,
	saves, and worker changes rather than re-truncating it away on every step. Each call to
	integrate() folds in one step's numerator, releases the whole units it produces, and keeps
	the leftover fraction for the next call.

	integrate_into() is the non-allocating form for per-tick callers; integrate() allocates one
	IntResult and delegates to it. Neither keeps a shared scratch object, so two accumulators --
	or two live results from one accumulator -- can never alias each other.
	"""
	var _remainder: int = 0

	func remainder() -> int:
		"""Current unconsumed remainder numerator, always nonnegative."""
		return _remainder

	func reset() -> void:
		"""Discard the retained remainder.

		Only for the documented bound-clamp case in BAL-NUM-001 (discarding the portion that
		would push a need past its bound); never call this merely to avoid tracking a rate.
		"""
		_remainder = 0

	func integrate(step_numerator: int, denominator: int) -> IntMathScript.IntResult:
		"""Add step_numerator/denominator of value; return whole units released this step.

		The fractional remainder is retained internally rather than discarded. Refuses on a
		non-positive denominator, a negative step, or int64 overflow.
		"""
		var out: IntMathScript.IntResult = IntMathScript.IntResult.new()
		integrate_into(step_numerator, denominator, out)
		return out

	func integrate_into(step_numerator: int, denominator: int, out: IntMathScript.IntResult) -> bool:
		"""Non-allocating integrate(): write the released whole units into `out`, return out.ok.

		`out` is caller-owned and is used as this call's own scratch, so it must not be a
		result the caller still needs. The retained remainder is updated only on success.
		"""
		if step_numerator < 0:
			return out.refuse("step_numerator must be nonnegative")
		if not IntMathScript.checked_add_into(_remainder, step_numerator, out):
			return false
		var total: int = out.value
		if not IntMathScript.floor_div_into(total, denominator, out):
			return false
		return _consume_into(total, out.value, denominator, out)

	func _consume_into(total: int, whole: int, denominator: int, out: IntMathScript.IntResult) -> bool:
		"""Subtract the released whole*denominator from total and retain the rest as remainder."""
		if not IntMathScript.checked_mul_into(whole, denominator, out):
			return false
		if not IntMathScript.checked_add_into(total, -out.value, out):
			return false
		_remainder = out.value
		return out.succeed(whole)


static func floor_div(a: int, b: int) -> IntResult:
	"""Nonnegative floor division: a/b truncated toward zero, which equals floor for a,b>=0.

	Used for BAL-NUM-001's "round down" family: nutrition, yield, and material discounts.
	Refuses a negative numerator or a non-positive denominator rather than guessing intent.
	"""
	var out: IntResult = IntResult.new()
	floor_div_into(a, b, out)
	return out


static func floor_div_into(a: int, b: int, out: IntResult) -> bool:
	"""Non-allocating floor_div(): write the quotient into `out` and return out.ok."""
	if a < 0:
		return out.refuse("floor_div requires a nonnegative numerator")
	if b <= 0:
		return out.refuse("denominator must be positive")
	return out.succeed(a / b)


static func ceil_div(a: int, b: int) -> IntResult:
	"""Nonnegative ceiling division: (a+b-1)/b per BAL-AUTH-002.

	Used for BAL-NUM-001's "round up" family: required trips, whole portions, batches, beds,
	and stations. Refuses a negative numerator, a non-positive denominator, or int64 overflow
	while forming a+b-1.
	"""
	var out: IntResult = IntResult.new()
	ceil_div_into(a, b, out)
	return out


static func ceil_div_into(a: int, b: int, out: IntResult) -> bool:
	"""Non-allocating ceil_div(): write the rounded-up quotient into `out` and return out.ok.

	`b - 1` is nonnegative once b > 0, so the overflow test needs no second checked call.
	"""
	if a < 0:
		return out.refuse("ceil_div requires a nonnegative numerator")
	if b <= 0:
		return out.refuse("denominator must be positive")
	if a > INT64_MAX - (b - 1):
		return out.refuse("int64 overflow forming ceil_div numerator")
	return out.succeed((a + b - 1) / b)


static func trunc_div(a: int, b: int) -> IntResult:
	"""Signed truncating division: trunc_div(a,b) = sign(a)*floor_div(abs(a),b) per BAL-AUTH-002.

	GDScript's native `/` already truncates toward zero for a positive divisor, which matches
	that formula exactly for every representable `a` (including INT64_MIN, where the abs/sign
	decomposition would itself overflow) without needing to compute abs(a) separately.
	Denominators must still be positive.
	"""
	var out: IntResult = IntResult.new()
	trunc_div_into(a, b, out)
	return out


static func trunc_div_into(a: int, b: int, out: IntResult) -> bool:
	"""Non-allocating trunc_div(): write the truncated quotient into `out` and return out.ok."""
	if b <= 0:
		return out.refuse("denominator must be positive")
	return out.succeed(a / b)


static func checked_add(a: int, b: int) -> IntResult:
	"""Add two int64 values, refusing rather than wrapping on overflow."""
	var out: IntResult = IntResult.new()
	checked_add_into(a, b, out)
	return out


static func checked_add_into(a: int, b: int, out: IntResult) -> bool:
	"""Non-allocating checked_add(): write the sum into `out` and return out.ok."""
	if b >= 0:
		if a > INT64_MAX - b:
			return out.refuse("int64 addition would overflow")
	else:
		if a < INT64_MIN - b:
			return out.refuse("int64 addition would overflow")
	return out.succeed(a + b)


static func checked_mul(a: int, b: int) -> IntResult:
	"""Multiply two int64 values, refusing rather than wrapping on overflow."""
	var out: IntResult = IntResult.new()
	checked_mul_into(a, b, out)
	return out


static func checked_mul_into(a: int, b: int, out: IntResult) -> bool:
	"""Non-allocating checked_mul(): write the product into `out` and return out.ok."""
	if a == 0 or b == 0:
		return out.succeed(0)
	if (a == -1 and b == INT64_MIN) or (b == -1 and a == INT64_MIN):
		return out.refuse("int64 multiplication would overflow")
	var product: int = a * b
	if product / b != a:
		return out.refuse("int64 multiplication would overflow")
	return out.succeed(product)


static func narrow_to_int32(value: int) -> IntResult:
	"""Narrow a checked int64 value into the int32 storage range used by packed columns.

	Refuses rather than truncating when the value falls outside [INT32_MIN, INT32_MAX].
	"""
	var out: IntResult = IntResult.new()
	narrow_to_int32_into(value, out)
	return out


static func narrow_to_int32_into(value: int, out: IntResult) -> bool:
	"""Non-allocating narrow_to_int32(): write the narrowed value into `out`, return out.ok."""
	if value < INT32_MIN or value > INT32_MAX:
		return out.refuse("value does not fit in int32")
	return out.succeed(value)


static func fits_int32(value: int) -> bool:
	"""True when value is storable in an int32 column, with no result object built at all.

	For range checks whose only output is the verdict; a caller that needs the narrowed number
	must still use narrow_to_int32() or narrow_to_int32_into() so the refusal stays explicit.
	"""
	return value >= INT32_MIN and value <= INT32_MAX


static func inventory_capacity_debit_g(quantity_milli: int, mass_g: int) -> IntResult:
	"""Per-lot inventory capacity debit: ceil_div(quantity_milli*mass_g, 1000), per BAL-NUM-001.

	Splitting a lot must never create free carrying capacity, so this always rounds up and
	refuses on a negative input or an overflowing multiplication rather than under-charging.
	"""
	var out: IntResult = IntResult.new()
	inventory_capacity_debit_g_into(quantity_milli, mass_g, out)
	return out


static func inventory_capacity_debit_g_into(quantity_milli: int, mass_g: int, out: IntResult) -> bool:
	"""Non-allocating inventory_capacity_debit_g(): write the debit into `out`, return out.ok.

	`out` doubles as this call's scratch for the intermediate product, which is consumed
	immediately, so no caller value survives across the two steps.
	"""
	if quantity_milli < 0 or mass_g < 0:
		return out.refuse("quantity_milli and mass_g must be nonnegative")
	if not checked_mul_into(quantity_milli, mass_g, out):
		return false
	return ceil_div_into(out.value, 1000, out)
