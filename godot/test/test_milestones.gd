extends "res://test/framework/test_case.gd"
## Coverage for the Milestone domain and the earned-bit unlock gate (R-BUILD-DOM-001).
##
## Every value below is restated from the specification rather than read back out of the module:
## the five ordinals from BAL-CAT-002 ("Unlock values are M0=0, M1=1, M2=2, M3=3, M4=4",
## gameplay_balance.md:43), the initial mask from GDD §5.11's R-BUILD-DOM-001 paragraph ("Active
## new worlds start with M0=0 and both masks=1", game_gdd.md:771-772), and the sparse example
## from the ruling itself ("M0+M3 gives mask 9 and highest=3, but an M1 definition is still
## locked until M1's own conditions earn bit 1").
##
## THE CENTRAL TEST IS `test_a_sparse_mask_locks_an_earlier_milestone`. Replacing the gate with
## `highest_earned >= unlock` passes every other test in this file and fails that one.

const Milestones := preload("res://scripts/core/milestones.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## BAL-CAT-002's five ordinals, written out rather than derived from a loop bound.
const M0: int = 0
const M1: int = 1
const M2: int = 2
const M3: int = 3
const M4: int = 4

## The ruling's own worked mask: M0 and M3 earned, M1 and M2 not. `1 + 8`.
const SPARSE_MASK: int = 9

## Every legal bit, `(1 << 5) - 1`, and the first reserved one.
const ALL_FIVE: int = 31
const RESERVED_BIT: int = 32


func test_the_protected_domain_carries_exactly_the_five_bal_cat_002_ordinals() -> void:
	"""BAL-CAT-002 states M0=0 through M4=4; Start is not a sixth key."""
	assert_equal(CatalogScript.MILESTONE.size(), 5, "five milestone keys")
	assert_equal(int(CatalogScript.MILESTONE["M0"]), M0, "M0 is 0")
	assert_equal(int(CatalogScript.MILESTONE["M1"]), M1, "M1 is 1")
	assert_equal(int(CatalogScript.MILESTONE["M2"]), M2, "M2 is 2")
	assert_equal(int(CatalogScript.MILESTONE["M3"]), M3, "M3 is 3")
	assert_equal(int(CatalogScript.MILESTONE["M4"]), M4, "M4 is 4")
	assert_false(CatalogScript.MILESTONE.has("Start"), "Start is a source label, not a key")


func test_milestone_is_protected_and_refuses_a_recompile() -> void:
	"""Protection is what stops a later key re-sorting a persisted ordinal."""
	assert_true(CatalogScript.PROTECTED_ENUM_DOMAINS.has("Milestone"), "Milestone is protected")
	assert_false(CatalogScript.COMPILED_ENUM_DOMAINS.has("Milestone"), "and is not compiled")
	var refused: CatalogScript.DomainResult = CatalogScript.compile_domain(
		"Milestone", [&"M0", &"M1"] as Array[StringName])
	assert_false(refused.ok, "recompiling a protected domain must refuse")
	assert_equal(CatalogScript.fixed_enum("Milestone"), CatalogScript.MILESTONE,
		"fixed_enum returns the MILESTONE table itself")


func test_a_sparse_mask_locks_an_earlier_milestone() -> void:
	"""THE RULING'S CENTRAL CASE. Mask 9 is M0+M3; an M1 definition stays locked.

	R-BUILD-DOM-001: "A sparse earned mask is legal; `Progress.milestone` is max(set bits), not
	the authoritative gate... Example: M0+M3 gives mask 9 and highest=3, but an M1 definition is
	still locked until M1's own conditions earn bit 1." A `highest >= unlock` gate answers TRUE
	for M1 and M2 here, which is what this test exists to catch."""
	assert_true(Milestones.is_unlocked(SPARSE_MASK, M0), "M0 is earned in mask 9")
	assert_false(Milestones.is_unlocked(SPARSE_MASK, M1), "M1 is NOT earned in mask 9")
	assert_false(Milestones.is_unlocked(SPARSE_MASK, M2), "M2 is NOT earned in mask 9")
	assert_true(Milestones.is_unlocked(SPARSE_MASK, M3), "M3 is earned in mask 9")
	assert_false(Milestones.is_unlocked(SPARSE_MASK, M4), "M4 is not earned in mask 9")
	var highest: IntMath.IntResult = Milestones.highest_earned(SPARSE_MASK)
	assert_true(highest.ok, "mask 9 has a highest earned milestone")
	assert_equal(highest.value, M3, "highest(9) is M3, which is presentation only")


func test_the_highest_ordinal_is_never_the_gate_for_any_sparse_mask() -> void:
	"""Every mask with a gap must lock the gap, whatever its highest ordinal says."""
	for gap: int in [M1, M2, M3]:
		var mask: int = 1 | (1 << M4)
		assert_false(Milestones.is_unlocked(mask, gap),
			"mask M0+M4 must lock M%d even though highest is M4" % gap)
	var highest: IntMath.IntResult = Milestones.highest_earned(1 | (1 << M4))
	assert_true(highest.ok, "M0+M4 has a highest")
	assert_equal(highest.value, M4, "and it is M4")


func test_the_initial_mask_earns_m0_and_nothing_else() -> void:
	"""GDD §5.11: "Active new worlds start with M0=0 and both masks=1"."""
	assert_equal(Milestones.INITIAL_MASK, 1, "the initial mask is 1")
	assert_true(Milestones.is_unlocked(Milestones.INITIAL_MASK, M0), "M0 is earned at start")
	for locked: int in [M1, M2, M3, M4]:
		assert_false(Milestones.is_unlocked(Milestones.INITIAL_MASK, locked),
			"M%d is locked at start" % locked)
	var highest: IntMath.IntResult = Milestones.highest_earned(Milestones.INITIAL_MASK)
	assert_true(highest.ok, "the starting world has a highest milestone")
	assert_equal(highest.value, M0, "and it is M0")


func test_m4_is_a_valid_id_and_bit_sixteen() -> void:
	"""Publishing the fifth milestone completes the domain; `1 << 4` is 16."""
	assert_true(Milestones.is_milestone_id(M4), "M4 is a milestone id")
	var bit: IntMath.IntResult = Milestones.bit_of(M4)
	assert_true(bit.ok, "M4 has a bit")
	assert_equal(bit.value, 16, "M4's earned bit is 16")
	assert_true(Milestones.is_unlocked(ALL_FIVE, M4), "mask 31 earns M4")
	assert_equal(Milestones.ALLOWED_MASK, ALL_FIVE, "every legal bit is 31")


func test_an_unknown_ordinal_refuses_rather_than_reading_as_unlocked() -> void:
	"""R-BUILD-DOM-001: no definition may use -1 or an unknown ordinal to mean unlocked."""
	for bad: int in [-1, 5, 31, 1000]:
		assert_false(Milestones.is_milestone_id(bad), "%d is not a milestone id" % bad)
		assert_false(Milestones.is_unlocked(ALL_FIVE, bad),
			"an unknown unlock %d must NOT read as unlocked, even at mask 31" % bad)
		var gate: IntMath.IntResult = Milestones.unlock_gate(ALL_FIVE, bad)
		assert_false(gate.ok, "and the explicit gate refuses %d" % bad)
		assert_equal(gate.error, String(Milestones.REFUSE_UNKNOWN_MILESTONE), "with its own code")


func test_reserved_bits_and_negative_masks_are_refused() -> void:
	"""R-BUILD-DOM-001: "Bits above 4 are reserved zero"."""
	assert_equal(Milestones.validate_mask(Milestones.INITIAL_MASK),
		Milestones.REFUSE_NONE, "mask 1 is legal")
	assert_equal(Milestones.validate_mask(ALL_FIVE), Milestones.REFUSE_NONE, "mask 31 is legal")
	assert_equal(Milestones.validate_mask(ALL_FIVE | RESERVED_BIT),
		Milestones.REFUSE_RESERVED_BIT, "bit 5 is reserved and refuses")
	assert_equal(Milestones.validate_mask(-1), Milestones.REFUSE_NEGATIVE_MASK,
		"a negative mask refuses")
	assert_false(Milestones.is_unlocked(ALL_FIVE | RESERVED_BIT, M0),
		"an illegal mask grants nothing, not even M0")
	var gate: IntMath.IntResult = Milestones.unlock_gate(RESERVED_BIT, M0)
	assert_false(gate.ok, "the explicit gate refuses an illegal mask")


func test_an_empty_mask_is_unbound_progress_and_never_a_fabricated_m0_world() -> void:
	"""R-BUILD-DOM-001: "An absent/unbound Progress store is unavailable, not a fabricated M0"."""
	assert_equal(Milestones.validate_mask(Milestones.EMPTY_MASK), Milestones.REFUSE_NONE,
		"mask 0 is structurally well formed")
	assert_equal(Milestones.require_active_mask(Milestones.EMPTY_MASK),
		Milestones.REFUSE_UNBOUND_PROGRESS, "but it is not an active world")
	assert_equal(Milestones.require_active_mask(Milestones.INITIAL_MASK),
		Milestones.REFUSE_NONE, "mask 1 is an active world")
	var highest: IntMath.IntResult = Milestones.highest_earned(Milestones.EMPTY_MASK)
	assert_false(highest.ok, "mask 0 names no highest milestone")
	assert_equal(highest.error, String(Milestones.REFUSE_UNBOUND_PROGRESS), "and says why")
	assert_false(Milestones.is_unlocked(Milestones.EMPTY_MASK, M0), "mask 0 unlocks nothing")


func test_an_award_commits_once() -> void:
	"""REQ-SET-154 unlocks "once"; re-awarding a set bit refuses instead of looking idempotent."""
	var first: IntMath.IntResult = Milestones.award(Milestones.INITIAL_MASK, M1)
	assert_true(first.ok, "M1 can be awarded from the starting mask")
	assert_equal(first.value, 3, "mask 1 plus bit 1 is 3")
	var again: IntMath.IntResult = Milestones.award(first.value, M1)
	assert_false(again.ok, "awarding M1 twice must refuse")
	assert_equal(again.error, String(Milestones.REFUSE_ALREADY_AWARDED), "with its own code")
	var sparse: IntMath.IntResult = Milestones.award(Milestones.INITIAL_MASK, M3)
	assert_true(sparse.ok, "M3 can be awarded without M1 or M2")
	assert_equal(sparse.value, SPARSE_MASK, "and produces exactly the ruling's mask 9")


func test_award_refuses_an_unknown_or_illegal_input() -> void:
	"""An award is bit arithmetic with validation, never a clamp."""
	var unknown: IntMath.IntResult = Milestones.award(Milestones.INITIAL_MASK, 5)
	assert_false(unknown.ok, "M5 does not exist")
	var illegal: IntMath.IntResult = Milestones.award(RESERVED_BIT, M1)
	assert_false(illegal.ok, "a reserved bit in the incoming mask refuses")
	assert_equal(illegal.error, String(Milestones.REFUSE_RESERVED_BIT), "with the mask's code")


func test_earned_count_counts_set_bits_only() -> void:
	"""A count is not a highest ordinal: mask 9 has two awards and highest M3."""
	var sparse: IntMath.IntResult = Milestones.earned_count(SPARSE_MASK)
	assert_true(sparse.ok, "mask 9 counts")
	assert_equal(sparse.value, 2, "mask 9 records two awards")
	var all_five: IntMath.IntResult = Milestones.earned_count(ALL_FIVE)
	assert_equal(all_five.value, 5, "mask 31 records five")
	var empty: IntMath.IntResult = Milestones.earned_count(Milestones.EMPTY_MASK)
	assert_true(empty.ok, "an empty mask counts")
	assert_equal(empty.value, 0, "and counts zero")
	var illegal: IntMath.IntResult = Milestones.earned_count(RESERVED_BIT)
	assert_false(illegal.ok, "an illegal mask refuses rather than counting its legal part")


func test_the_two_published_masks_must_agree() -> void:
	"""R-BUILD-DOM-001: "both masks agree in a published world"."""
	assert_equal(Milestones.masks_agree(SPARSE_MASK, SPARSE_MASK), Milestones.REFUSE_NONE,
		"two equal legal masks agree")
	assert_equal(Milestones.masks_agree(SPARSE_MASK, Milestones.INITIAL_MASK),
		Milestones.REFUSE_MASK_DISAGREEMENT, "9 and 1 disagree")
	assert_equal(Milestones.masks_agree(RESERVED_BIT, RESERVED_BIT),
		Milestones.REFUSE_RESERVED_BIT, "two equal illegal masks still refuse")
	assert_equal(Milestones.masks_agree(-1, -1), Milestones.REFUSE_NEGATIVE_MASK,
		"a negative World.milestone_mask refuses")


func test_start_normalizes_to_m0_at_source_import_only() -> void:
	"""§5.9's building table prints `Start`; R-BUILD-DOM-001 maps it to M0 and nowhere else."""
	var start: IntMath.IntResult = Milestones.id_of_source_label("Start")
	assert_true(start.ok, "Start is a source label")
	assert_equal(start.value, M0, "and it normalizes to M0")
	var m3: IntMath.IntResult = Milestones.id_of_source_label("M3")
	assert_true(m3.ok, "M3 is a published key")
	assert_equal(m3.value, M3, "and resolves to 3")
	for bad: String in ["", "start", "M5", "M0 ", "Refuge"]:
		var refused: IntMath.IntResult = Milestones.id_of_source_label(bad)
		assert_false(refused.ok, "'%s' is not a milestone label" % bad)
		assert_equal(refused.error, String(Milestones.REFUSE_UNKNOWN_SOURCE_LABEL), "with a code")


func test_bit_of_refuses_outside_the_domain_and_never_returns_a_usable_zero() -> void:
	"""A refusal carries value 0, which is also a legal mask, so `.ok` is the only answer."""
	for milestone_id: int in [M0, M1, M2, M3, M4]:
		var bit: IntMath.IntResult = Milestones.bit_of(milestone_id)
		assert_true(bit.ok, "M%d has a bit" % milestone_id)
		assert_equal(bit.value, 1 << milestone_id, "M%d's bit is 1<<%d" % [milestone_id, milestone_id])
	var refused: IntMath.IntResult = Milestones.bit_of(5)
	assert_false(refused.ok, "M5 has no bit")
	assert_equal(refused.value, 0, "and a refusal zeroes the value")


func test_key_of_consults_the_protected_table_rather_than_the_range() -> void:
	"""A table edited out of step with COUNT is caught here instead of producing a key-less id."""
	for milestone_id: int in [M0, M1, M2, M3, M4]:
		assert_true(Milestones.key_of(milestone_id).ok, "M%d has a key" % milestone_id)
	assert_false(Milestones.key_of(5).ok, "5 names no published key")
	assert_false(Milestones.key_of(-1).ok, "-1 names no published key")


func test_unlock_gate_separates_locked_from_invalid() -> void:
	"""A locked definition and a malformed one must not look the same to a caller."""
	var locked: IntMath.IntResult = Milestones.unlock_gate(Milestones.INITIAL_MASK, M2)
	assert_true(locked.ok, "a legal question gets an answer")
	assert_equal(locked.value, 0, "and the answer is locked")
	var unlocked: IntMath.IntResult = Milestones.unlock_gate(Milestones.INITIAL_MASK, M0)
	assert_true(unlocked.ok, "a legal question gets an answer")
	assert_equal(unlocked.value, 1, "and the answer is unlocked")
	var invalid: IntMath.IntResult = Milestones.unlock_gate(Milestones.INITIAL_MASK, -1)
	assert_false(invalid.ok, "an invalid unlock id is refused, not reported locked")
