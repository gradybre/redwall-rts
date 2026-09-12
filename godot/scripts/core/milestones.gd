extends RefCounted
## The Milestone unlock gate: earned-bit masks, and the one predicate every unlock test uses.
##
## R-BUILD-DOM-001 (docs/rulings/2026-09-11_building_room_domains.md, adopted as decision 0074)
## binds three existing fields to one protected domain:
##   * `BuildingDefinition.unlock` and `RecipeDefinition.unlock` each hold ONE Milestone id --
##     "not a bitmask, building ID or free-form label".
##   * `World.milestone_mask` and `Progress.unlocked_mask` are EARNED-BIT masks: bit m means
##     milestone m was actually AWARDED. "Both masks agree in a published world."
##   * `Progress.milestone` is the highest earned ordinal, "for presentation" only.
##
## THE GATE, AND WHY THE OBVIOUS IMPLEMENTATION IS WRONG. A definition is unlocked exactly when
## `(unlocked_mask & (1 << definition.unlock)) != 0`. It is NOT `highest_earned >= unlock`. The
## ruling gives its own counterexample: "M0+M3 gives mask 9 and highest=3, but an M1 definition
## is still locked until M1's own conditions earn bit 1." A sparse earned mask is legal because
## GDD §5.11 states each milestone's complete conditions independently and states no predecessor
## requirement -- M3 is "Population>=80 AND year>=2 AND food-days>=8", which a settlement can
## satisfy without ever having prepared M1's 200 cumulative portions. A `>=` comparison would
## silently grant M1's mill, workshop, cellar, preserver, saltpan, infirmary and lookout the
## moment M3 landed, with no condition ever having passed and no reward ever having committed.
## `is_unlocked()` below is therefore the only unlock predicate in this module, and
## `highest_earned()` is deliberately a separate presentation call that nothing here gates on.
##
## WHAT THIS MODULE DOES NOT OWN. Progression owns the masks, the award latches and the reward
## commits: "Do not add a second mutable milestone store." This module holds NO state at all --
## every function is static and pure, taking the mask as an argument. It cannot award a
## milestone, cannot fabricate one, and cannot be the second source of truth the ruling forbids.
## When a Progress store lands it calls `award_into()` to fold one earned bit into a mask, having
## itself decided that GDD §5.11's conditions for that milestone passed.
##
## AN ABSENT PROGRESS STORE IS UNAVAILABLE, NOT AN M0 WORLD. The ruling: "An absent/unbound
## Progress store is unavailable, not a fabricated M0 world." Mask 0 is therefore refused by
## every call that needs an earned milestone -- `highest_earned(0)` refuses rather than answering
## M0, because answering would manufacture exactly the fabricated world the ruling names. Only
## `validate_mask()` accepts 0, and only as the structural statement "these bits are in range".
##
## BLOCKERS, NAMED RATHER THAN INVENTED:
##   * GDD §5.11's award CONDITIONS (day/population/portions/recipes/feasts/mood/food-days/fuel)
##     are not evaluated here. They read Resident, Needs, Inventory, Feast and MasteryCounter
##     state that this module has no business touching, and REQ-SET-154's "record the triggering
##     tick" needs a Progress row to record it in. No Progress store exists in this repository.
##   * The REWARDS in §5.11's third column are catalog unlocks plus one-off grants (M3's "2
##     apple+2 pear saplings once"). Granting them is Progression's commit, not a gate's.
##   * `scripts/ui/ui_availability.gd` currently gates advanced UI on a highest-ordinal `>=`
##     comparison against a fixture milestone. The ruling requires that to migrate to earned-bit
##     evidence "when real Progress is bound". That file belongs to another owner; this module
##     is the predicate it must call, and `test_milestones.gd` pins the sparse case it must pass.

const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## The five keys of the protected domain, read from its owner. Never mirrored here.
const DOMAIN: String = Catalog.MILESTONE_DOMAIN

## BAL-CAT-002: "Unlock values are M0=0, M1=1, M2=2, M3=3, M4=4". Five ids, 0..4.
const COUNT: int = 5
const MIN_ID: int = 0
const MAX_ID: int = COUNT - 1

## Every bit a published mask may carry: `(1 << 5) - 1`. R-BUILD-DOM-001: "Bits above 4 are
## reserved zero", so a mask carrying one is refused rather than masked down to the legal part.
const ALLOWED_MASK: int = (1 << COUNT) - 1

## R-BUILD-DOM-001: "Active new settlements start with M0 earned, masks=1 and milestone=0."
const INITIAL_MASK: int = 1

## The empty mask. Not a world state: an unbound Progress store, which is UNAVAILABLE.
const EMPTY_MASK: int = 0

## §5.9's building table prints `Start` in the unlock column where §5.11 calls the milestone M0.
## R-BUILD-DOM-001: "`Start` is a source-table label mapping to M0, not a sixth catalog key."
## Normalization happens at source import and nowhere else, which is why this lives beside
## `id_of_source_label()` rather than in `Catalog.MILESTONE`.
const SOURCE_LABEL_START: String = "Start"
## The key `Start` normalizes to. Spelled once so the mapping cannot drift from the table.
const SOURCE_LABEL_M0: String = "M0"

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_MILESTONE: StringName = &"UNKNOWN_MILESTONE"
const REFUSE_NEGATIVE_MASK: StringName = &"NEGATIVE_MILESTONE_MASK"
const REFUSE_RESERVED_BIT: StringName = &"RESERVED_MILESTONE_BIT"
const REFUSE_UNBOUND_PROGRESS: StringName = &"UNBOUND_PROGRESS"
const REFUSE_UNKNOWN_SOURCE_LABEL: StringName = &"UNKNOWN_MILESTONE_LABEL"
const REFUSE_ALREADY_AWARDED: StringName = &"MILESTONE_ALREADY_AWARDED"
const REFUSE_MASK_DISAGREEMENT: StringName = &"MILESTONE_MASKS_DISAGREE"


static func is_milestone_id(milestone_id: int) -> bool:
	"""True when `milestone_id` is one of the five published Milestone ordinals M0..M4."""
	return milestone_id >= MIN_ID and milestone_id <= MAX_ID


static func key_of(milestone_id: int) -> IntMath.IntResult:
	"""Refuse or succeed on one ordinal; the value is the ordinal, `error` names a refusal.

	The protected table is consulted rather than the 0..4 range, so a table edited out of step
	with COUNT is caught here instead of producing a key-less id.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	for key: String in Catalog.MILESTONE.keys():
		if int(Catalog.MILESTONE[key]) == milestone_id:
			out.succeed(milestone_id)
			return out
	out.refuse(String(REFUSE_UNKNOWN_MILESTONE))
	return out


static func bit_of(milestone_id: int) -> IntMath.IntResult:
	"""The earned bit `1 << milestone_id`, or a refusal for an id outside M0..M4.

	There is no sentinel: a refusal carries value 0, which is also a legal empty mask, so `.ok`
	MUST be inspected. `bit_of_into()` is the non-allocating form.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	bit_of_into(milestone_id, out)
	return out


static func bit_of_into(milestone_id: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating bit_of(): write `1 << milestone_id` into caller-owned `out`."""
	if not is_milestone_id(milestone_id):
		return out.refuse(String(REFUSE_UNKNOWN_MILESTONE))
	return out.succeed(1 << milestone_id)


static func validate_mask(unlocked_mask: int) -> StringName:
	"""REFUSE_NONE when a mask is structurally legal, otherwise the code that rejects it.

	Legal means: not negative, and carrying no bit above M4. The empty mask 0 passes this
	structural check and still fails `require_active_mask()`, because "no milestone is earned"
	is a well-formed value and an unbound Progress store, not a playable world.
	"""
	if unlocked_mask < 0:
		return REFUSE_NEGATIVE_MASK
	if (unlocked_mask & ~ALLOWED_MASK) != 0:
		return REFUSE_RESERVED_BIT
	return REFUSE_NONE


static func require_active_mask(unlocked_mask: int) -> StringName:
	"""REFUSE_NONE when a mask is legal AND describes an active world (M0 actually earned).

	R-BUILD-DOM-001: active settlements start at mask 1, and an absent/unbound Progress store is
	unavailable rather than a fabricated M0 world -- so mask 0 refuses here instead of being
	quietly upgraded to INITIAL_MASK.
	"""
	var structural: StringName = validate_mask(unlocked_mask)
	if structural != REFUSE_NONE:
		return structural
	if (unlocked_mask & INITIAL_MASK) == 0:
		return REFUSE_UNBOUND_PROGRESS
	return REFUSE_NONE


static func is_earned(unlocked_mask: int, milestone_id: int) -> bool:
	"""True when bit `milestone_id` is set in a VALID mask; false for any invalid input.

	Callers that must distinguish "not earned" from "that is not a milestone" use
	`unlock_gate()`, which refuses with a code. This predicate is for the hot path, where the
	mask has already been validated once by its owner.
	"""
	if not is_milestone_id(milestone_id):
		return false
	if validate_mask(unlocked_mask) != REFUSE_NONE:
		return false
	return (unlocked_mask & (1 << milestone_id)) != 0


static func is_unlocked(unlocked_mask: int, unlock_id: int) -> bool:
	"""THE UNLOCK GATE. True when a definition whose `unlock` is `unlock_id` may be built.

	R-BUILD-DOM-001: "A definition is unlocked exactly when
	`(unlocked_mask & (1 << definition.unlock)) != 0`" -- the definition's OWN bit, never a
	comparison against the highest earned ordinal. See this module's header for the M0+M3
	counterexample that makes the difference observable.
	"""
	return is_earned(unlocked_mask, unlock_id)


static func unlock_gate(unlocked_mask: int, unlock_id: int) -> IntMath.IntResult:
	"""`is_unlocked()` with an explicit refusal channel: value 1 unlocked, 0 locked.

	Refuses an unlock id outside M0..M4 and a mask carrying a reserved or negative bit, so a
	definition row with a bad `unlock` cannot be read as merely locked.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	unlock_gate_into(unlocked_mask, unlock_id, out)
	return out


static func unlock_gate_into(unlocked_mask: int, unlock_id: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating unlock_gate(): write 1 (unlocked) or 0 (locked) into caller-owned `out`."""
	var structural: StringName = validate_mask(unlocked_mask)
	if structural != REFUSE_NONE:
		return out.refuse(String(structural))
	if not is_milestone_id(unlock_id):
		return out.refuse(String(REFUSE_UNKNOWN_MILESTONE))
	return out.succeed(1 if (unlocked_mask & (1 << unlock_id)) != 0 else 0)


static func highest_earned(unlocked_mask: int) -> IntMath.IntResult:
	"""`Progress.milestone`: max(set bits). PRESENTATION ONLY -- never an unlock threshold.

	Refuses the empty mask, because "no milestone earned" names no ordinal and answering M0
	would fabricate the award the ruling says an unbound Progress store does not have.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	highest_earned_into(unlocked_mask, out)
	return out


static func highest_earned_into(unlocked_mask: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating highest_earned(): write max(set bits) into caller-owned `out`."""
	var structural: StringName = validate_mask(unlocked_mask)
	if structural != REFUSE_NONE:
		return out.refuse(String(structural))
	if unlocked_mask == EMPTY_MASK:
		return out.refuse(String(REFUSE_UNBOUND_PROGRESS))
	for milestone_id: int in range(MAX_ID, MIN_ID - 1, -1):
		if (unlocked_mask & (1 << milestone_id)) != 0:
			return out.succeed(milestone_id)
	return out.refuse(String(REFUSE_UNBOUND_PROGRESS))


static func earned_count(unlocked_mask: int) -> IntMath.IntResult:
	"""How many milestones a mask records as awarded, 0..5, or a refusal for an illegal mask."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var structural: StringName = validate_mask(unlocked_mask)
	if structural != REFUSE_NONE:
		out.refuse(String(structural))
		return out
	var total: int = 0
	for milestone_id: int in COUNT:
		if (unlocked_mask & (1 << milestone_id)) != 0:
			total += 1
	out.succeed(total)
	return out


static func award(unlocked_mask: int, milestone_id: int) -> IntMath.IntResult:
	"""Fold one newly earned milestone into a mask and return the new mask.

	Awards commit ONCE (R-BUILD-DOM-001, REQ-SET-154), so re-awarding an already-set bit refuses
	rather than returning an unchanged mask: a caller that cannot tell the difference would
	re-run the rewards. Progression decides that the milestone's own §5.11 conditions passed;
	this call only performs the bit arithmetic and its validation.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	award_into(unlocked_mask, milestone_id, out)
	return out


static func award_into(unlocked_mask: int, milestone_id: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating award(): write the updated mask into caller-owned `out`."""
	var structural: StringName = validate_mask(unlocked_mask)
	if structural != REFUSE_NONE:
		return out.refuse(String(structural))
	if not is_milestone_id(milestone_id):
		return out.refuse(String(REFUSE_UNKNOWN_MILESTONE))
	if (unlocked_mask & (1 << milestone_id)) != 0:
		return out.refuse(String(REFUSE_ALREADY_AWARDED))
	return out.succeed(unlocked_mask | (1 << milestone_id))


static func masks_agree(world_milestone_mask: int, progress_unlocked_mask: int) -> StringName:
	"""REFUSE_NONE when both published masks are legal and identical, else the refusing code.

	R-BUILD-DOM-001: "both masks agree in a published world". `World.milestone_mask` is int32 and
	`Progress.unlocked_mask` is int64 (GDD §4.2), and the two widths are exactly why a load has
	to compare them rather than pick one; five bits fit in both.
	"""
	var world_code: StringName = validate_mask(world_milestone_mask)
	if world_code != REFUSE_NONE:
		return world_code
	var progress_code: StringName = validate_mask(progress_unlocked_mask)
	if progress_code != REFUSE_NONE:
		return progress_code
	if world_milestone_mask != progress_unlocked_mask:
		return REFUSE_MASK_DISAGREEMENT
	return REFUSE_NONE


static func id_of_source_label(label: String) -> IntMath.IntResult:
	"""Normalize one SOURCE-TABLE unlock label into a Milestone id. Import boundary only.

	GDD §5.9's building table spells M0 as `Start`; R-BUILD-DOM-001 maps that label to M0 and
	forbids it as a sixth catalog key, so the translation is confined to this one function and
	`Catalog.MILESTONE` never gains a `Start` entry. Every other label must already be one of the
	five published keys; anything else refuses, including "" and an unknown "M5".
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if label == SOURCE_LABEL_START:
		out.succeed(int(Catalog.MILESTONE[SOURCE_LABEL_M0]))
		return out
	if Catalog.MILESTONE.has(label):
		out.succeed(int(Catalog.MILESTONE[label]))
		return out
	out.refuse(String(REFUSE_UNKNOWN_SOURCE_LABEL))
	return out

