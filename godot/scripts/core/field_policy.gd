extends RefCounted
## GDD §4.2's `FieldPolicy` store, and R06-JOB-005's rotation advance.
##
## ---------------------------------------------------------------------------------------
## THE CONTRACT, verbatim from `docs/rulings/2026-09-09_ready06_open_item_answers.md` §1:
##
##   R06-JOB-005  "When the current configured field planting cycle has finished
##                 harvesting/clearing and auto_rotation is enabled, FieldPolicy shall advance
##                 its cursor once and request the next configured crop. It shall not advance
##                 once per tile, skip blocked entries, or substitute a crop. If its legal window
##                 is future, retain the request; if missed, show the existing warning and wait
##                 for its next legal window or a player edit. With auto_rotation=false,
##                 completion shall not request another sowing cycle."
##
## and the three defaults paragraphs that bound it:
##
##   "FieldPolicy retains grain/beans/roots, cursor 0, auto_rotation=false, seed_reserve=true."
##   "Automatic next-field-cycle advancement waits for all participating plots in the current
##    cycle to resolve, preventing fast tiles from advancing the entire field repeatedly."
##   "Erasing a tile is not successful harvest; explicitly cancelled unresolved cycles need a
##    recorded cancellation rather than fabricated completion."
##
## §4.2's own row is the schema: `zone: EntityRef, rotation_ids: int32[3], rotation_cursor: int32,
## auto_rotation: bool, seed_reserve: bool`, "One per FARM zone; grain/beans/roots, cursor 0, auto
## false, reserve true". systems_architecture.md §2.2 budgets it at 128 rows, six I32 columns
## (3072 B) and two B8 (256 B). Those eight columns are here unchanged and unenlarged.
##
## ---------------------------------------------------------------------------------------
## THERE IS NO PLOT -> FIELD MAPPING IN THIS BUILD. THIS WAS CHECKED, NOT ASSUMED.
##
##   * GDD §5.6 says so in its own words: "A plot records its own growth and soil; FIELD GROUPING
##     IS A UI/WORK AGGREGATION."
##   * `farming.gd`'s FarmPlot row carries a TILE (`tile_of()`), a soil and a crop. It carries no
##     zone reference, and `TileHistory` carries `active_plot_row` -- tile -> plot, never
##     plot -> field.
##   * `forage.gd` owns a zone<->tile link store, and `create_zone()` does accept
##     `ZONE_TYPE_FARM`. But it publishes only the TILE-major walk (`tile_link_head_of()`,
##     `next_tile_link()`, `zone_slot_of_link()`); `_zone_link_head` is private, so no caller can
##     enumerate a zone's tiles. Nothing anywhere binds a FARM zone to a FarmPlot.
##
## So "all participating plots in the current cycle" HAS NO STORE TO READ, and this module does
## not invent a grouping one. The participating set is a VALIDATED CALLER-SUPPLIED GROUP --
## `open_cycle()` then one `enrol_plot()` per plot -- exactly the precedent `farming.gd` sets by
## taking `pollination_factor` as a parameter and `fishing.gd` by taking `base_catch_milli` as
## one. Every plot is validated on the way in (live FarmPlot row, not already enrolled in another
## field's open cycle) and every resolution is validated against the enrolment, so a caller cannot
## resolve a plot it never enrolled or resolve one twice.
##
## WHAT IS STORED IS AN ENROLMENT LEDGER, NOT A MEMBERSHIP MAP. `_plot_field_slot`,
## `_plot_cycle` and `_plot_outcome` record the group the caller supplied FOR ONE CYCLE, stamped
## with that cycle's ordinal. Outside an open cycle they answer nothing: the stamp goes stale the
## moment the next cycle opens, and `is_plot_enrolled()` reports false. They exist because
## R06-JOB-005's FIRST named failure mode -- "advancing once per tile" -- cannot be closed by a
## counter alone: without per-plot identity the same fast plot could report twice and trip the
## count. That is the defect the ruling calls the one most likely to pass a naive test.
##
## ---------------------------------------------------------------------------------------
## THREE DIFFERENT CURSORS EXIST AND NONE OF THEM IS ANOTHER. Decision 0040 gave sowing a
## field-cycle identity BECAUSE NO FieldPolicy EXISTED; that identity now meets this store, and
## the reconciliation is that they count different things:
##
##   1. `job_planner.gd`'s `_cycle_cursor[plot]` -- decision 0040. A PER-PLOT, monotonic,
##      never-wrapping ordinal: "cycle 1 is the first sowing cycle confirmed on that plot". It is
##      the third term of the sowing identity `(owner EntityRef, SOW, field cycle)` and its only
##      writer is `confirm_first_planting()`. THIS MODULE DOES NOT READ, WRITE OR DUPLICATE IT,
##      and adds no second per-plot cursor.
##   2. `FieldPolicy.rotation_cursor` -- §4.2's own column. A PER-FIELD INDEX INTO A THREE-ENTRY
##      LIST, 0..2, which WRAPS, because §5.6 calls the rotation "an explicit three-entry cycle".
##      It names which crop is next; it counts nothing.
##   3. `_cycle_ordinal[field]` -- this module's own. A PER-FIELD monotonic ordinal that stamps
##      an enrolment so a stale one cannot resolve the current cycle. It is a generation, in the
##      sense §4.1 uses that word, and it never wraps: `open_cycle()` REFUSES at int32's maximum
##      rather than reusing an ordinal a stale stamp might still name.
##
## The two field-level quantities are not derivable from decision 0040's per-plot one -- a field
## of ten plots has ten independent per-plot cursors and one rotation -- so the ruling's "any
## non-derivable cycle intent must be included in the schema/budget" applies and decision 0045
## budgets them.
##
## ---------------------------------------------------------------------------------------
## HOW "EXACTLY ONCE" IS ENFORCED. Four independent guards, so no single edit removes it:
##   1. A cycle closes only from `_maybe_close_cycle()`, and only when `_resolved == _participants`
##      with `_participants > 0`. A fast plot resolving first leaves `_resolved < _participants`
##      and closes nothing.
##   2. Closing sets `CYCLE_CLOSED`. Every resolution entry point requires `CYCLE_OPEN`, so a
##      resolution arriving after the close refuses with NO_OPEN_FIELD_CYCLE.
##   3. A plot whose outcome is no longer UNRESOLVED refuses with PLOT_ALREADY_RESOLVED, so one
##      plot cannot be counted twice inside one cycle.
##   4. An enrolment stamped with a different cycle ordinal is stale and refuses, so a plot
##      resolved against last cycle cannot resolve this one.
## The cursor advance itself is `(cursor + 1) % 3` evaluated ONCE inside `_advance_rotation()`,
## which `_close_cycle()` calls at most once per cycle.
##
## ---------------------------------------------------------------------------------------
## A BLOCKED ENTRY IS NOT SKIPPED AND NO CROP IS SUBSTITUTED. `_request_crop_at_cursor()` reads
## `_rotation_ids[field * 3 + cursor]` and nothing else. There is no loop over the other entries,
## no fallback crop and no "next legal crop" search anywhere in this file. §5.6 is the reason:
## "A missed planting window leaves the plot fallow and warns; IT DOES NOT CHOOSE A DIFFERENT
## SEED WITHOUT THE PLAYER'S ROTATION RULE." An entry that is `CROP_NONE` blocks with
## ROTATION_ENTRY_NOT_CONFIGURED and the cursor STAYS on it; the request waits for a player edit.
##
## THE WINDOW HAS THREE ANSWERS AND THE RULING NAMES ALL THREE. `_classify_window()` scans the
## year's 48 season-local days through `farming.is_plant_window()` -- the OWNING formula, never a
## copy of §5.6's window table -- and answers READY (legal now), WINDOW_FUTURE (its next legal day
## is ahead of today: "retain the request"), or WINDOW_MISSED (every legal day this year is
## behind: "show the existing warning and wait for its next legal window or a player edit"). Both
## non-ready answers RETAIN the request; they differ in what the UI shows, which is the whole of
## the distinction the ruling draws. A fourth answer, CROP_HAS_NO_LEGAL_WINDOW, exists for a crop
## that names no legal day at all: §5.6's table gives every crop at least one, so it is
## unreachable through the current catalog and is kept for the reason `forage.gd` keeps its
## malformed-stock guard -- a save/load path is coming and cannot be trusted to be well formed.
##
## ---------------------------------------------------------------------------------------
## ERASING A TILE IS NOT A HARVEST, AND IT IS NOT A RESOLUTION EITHER. `withdraw_plot()` is the
## erase/undesignate path. It records OUTCOME_WITHDRAWN, decrements `_participants`, increments
## `_withdrawn`, and NEVER touches `_resolved`. Only `record_plot_resolved()` with HARVESTED or
## CLEARED increments that. Two consequences are stated rather than discovered:
##   * A plot already resolved CANNOT be withdrawn (PLOT_ALREADY_RESOLVED). A harvest that
##     happened stays happened when its tile is later erased. This is also what makes
##     `_resolved <= _participants` an invariant, and therefore what makes `_participants == 0`
##     imply `_resolved == 0`.
##   * WITHDRAWING EVERY PARTICIPANT CLOSES THE CYCLE AS ABANDONED, NOT COMPLETED: no advance, no
##     request, no completed-cycle count. Erasing a whole field can therefore never advance its
##     rotation. INTERPRETATION, recorded in decision 0045: the alternative -- leaving the cycle
##     open on a field with no plots left -- is a permanent stall, and the ruling forbids
##     fabricating the completion, not refusing it.
##
## AN EXPLICIT CANCELLATION IS RECORDED AS ONE. `cancel_cycle()` closes an OPEN cycle with
## CLOSE_CANCELLED, increments the field's durable `_cancelled_cycles` count, and advances
## NOTHING. `_completed_cycles` is not touched, so a cancelled cycle can never be read back as a
## completed one. Both counters are per-field and durable, because the ruling forbids discarding
## completion history.
##
## ---------------------------------------------------------------------------------------
## `auto_rotation` DEFAULTS FALSE AND THAT IS LOAD-BEARING. `_close_cycle()` on a COMPLETED cycle
## calls `_advance_rotation()`, whose FIRST statement returns when `_auto_rotation` is 0, leaving
## the cursor where it was and the request state NONE. "With auto_rotation=false, completion shall
## not request another sowing cycle" is therefore structural, not a check placed later. Enabling
## `auto_rotation` AFTER a cycle has already closed does NOT retroactively advance it: the gate is
## read at close time and `set_auto_rotation()` starts nothing.
##
## CHANGING A ROTATION LIST SHALL NOT START WORK. `set_rotation()`, `set_rotation_cursor()`,
## `set_auto_rotation()` and `set_seed_reserve()` create no Job, open no cycle and publish
## nothing. What an edit DOES do is re-evaluate an OUTSTANDING request against the edited list at
## the unchanged cursor -- that is the ruling's own "or a player edit", the second thing that
## resolves a missed window. It never creates a request where none stood: `_request_state` NONE
## stays NONE across every edit.
##
## ---------------------------------------------------------------------------------------
## REQ-SET-088 IS AN UNSATISFIABLE GATE THAT REFUSES. "When a seed reserve is enabled, the system
## shall reserve enough seed for the next configured planting across designated fields before
## allowing seed export or nonplanting use." There is NO INVENTORY RESERVATION PATH THIS POLICY
## COULD USE:
##   * `reservations.gd`'s row shape is §4.2's `Reservation: job: EntityRef, lot: EntityRef, ...`
##     -- EVERY row is owned by a Job. A standing seed reserve has no Job; the next planting has
##     not been confirmed, and decision 0040's sowing Job carries `inputs_gate = GATE_UNAVAILABLE`
##     precisely because the seed supply cannot be answered.
##   * There is no export path and no "nonplanting use" path to gate.
## So `seed_reserve_gate_of()` answers `GATE_NOT_REQUIRED` when the policy is off and
## `GATE_UNAVAILABLE` when it is on -- jobs.gd's own values, read from jobs.gd, not mirrored --
## and `authorise_seed_release()` REFUSES with SEED_RESERVE_UNANSWERABLE whenever the reserve is
## enabled. IT NEVER ANSWERS GATE_SATISFIED, because that would fabricate a supply this build
## does not have. Decisions 0039 and 0040 set that precedent for §5.6's water and seed.
## `seed_requirement_milli_into()` is the half that CAN be computed honestly: §5.6's seed U/tile
## through `farming.seed_milli_of()`, times a caller-supplied tile count, checked for overflow.
## The tile count is caller-supplied for the same reason the participating set is: no store groups
## tiles into a field. THE CROP -> SEED ITEM ID MAPPING IS ALSO NOT MADE HERE; §5.6 says only
## "corresponding seed", `item_definitions.json` does hold `seed_grain` and its four siblings, and
## nothing authors the join. The requirement is therefore a QUANTITY, never an item.
##
## ---------------------------------------------------------------------------------------
## REQUIREMENTS THIS MODULE DOES NOT OWN, named so they are not duplicated here:
##   * REQ-SET-070's five sowing gates and REQ-SET-071's exact seed consumption are decision
##     0040's: `job_planner.confirm_first_planting()` / `_sowing_gate()` and `farming.plant()`.
##     This module requests a crop; it does not sow one and it creates no Job.
##   * REQ-SET-078's fallow fertility restore is `farming.apply_fallow_day()` /
##     `fallow_gain_for()`, already implemented with §5.6's 50/day and the 12-day LEGUME bonus.
##     Not restated here.
##   * REQ-SET-073's ripe harvest job and REQ-SET-085's withered clearing job keep their existing
##     route. This module OBSERVES their outcome through `record_plot_resolved()`; it does not
##     create, reroute or infer either.
##
## `OrderMode` IS NOT THE VEHICLE. ONCE/REPEAT/MAINTAIN_STOCK describe `ProductionOrder`, whose
## schema is recipe- and building-based. No field id and no zone id is written into a `recipe_id`
## here, and no `ProductionOrder` is created: the ruling says in its own words that "field rotation
## and daily hive care are not production recipes".
##
## NOTHING HERE WRITES `JOB_STATE_WORK`, because nothing here writes a Job at all. This module
## holds no reference to `jobs.gd`'s store; it preloads that script for two §4.2 gate values and
## for nothing else.
##
## ---------------------------------------------------------------------------------------
## BLOCKER U2 -- NO COMMAND DELIVERY. `create_policy()`, `set_rotation()`, `set_rotation_cursor()`,
## `set_auto_rotation()` and `set_seed_reserve()` ARE the entry points a command handler calls
## when U2 closes, and all five are complete and tested -- but nothing delivers to them, so no
## rotation is edited and no automatic rotation is enabled in a running settlement. NO COMMAND
## KIND IS INVENTED and ARCH-CMD-003 IS NOT RENUMBERED: `SET_FIELD_ROTATION` and `SET_POLICY`
## already exist in `catalog_ids.json`, and the ruling's implementation boundary directs that
## their PAYLOADS be refined, which is a change to a document this module does not own.
##
## BLOCKER -- NOTHING OPENS, ENROLS OR RESOLVES A CYCLE. `open_cycle()`, `enrol_plot()`,
## `record_plot_resolved()` and `withdraw_plot()` are the seams ARCH-SYS-006 (increment 10) drives
## when a field is actually planted and harvested. That orchestrator does not exist, so in the
## running build no cycle ever opens and no rotation ever advances. The producer is complete and
## driven only by its tests.
##
## BLOCKER -- NO SAVE ROUND TRIP. Persistence is in-process only; there is no save module, so the
## enrolment ledger, the two durable per-field counters and the rotation columns have no
## serialization and no load-time revalidation. `_cycle_ordinal` is deliberately monotonic ACROSS
## a row's whole lifetime -- `create_policy()` does not reset it -- so a row reused by a different
## zone cannot inherit a stale enrolment; that property is what a load repair would have to
## preserve.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. Every column is sized once in `_init()`; `clear()` refills the existing buffers and
## nothing outside `_allocate_columns()` calls `resize()`. Every reader has a non-allocating
## `_into(..., out) -> bool` form. The offset calendar is decoded into ONE OWNED
## `SimClock.Calendar` scratch through `calendar_at_into()`. Two calls allocate INSIDE modules this
## task does not own, each their published contract and each on a cold path:
##   * `forage.zone_type_of()`   one IntResult per `create_policy()` -- forage.gd publishes no
##     `_into` form for it. Reported, not worked around by editing a file this task does not own.
##   * `farming.seed_milli_of()` one IntResult per seed-requirement question, for the same reason.
## `_classify_window()` calls `farming.is_plant_window()` up to 48 times; that function allocates
## nothing and runs only when a cycle closes or a player edits a rotation, never per tick.
##
## REFUSAL, NOT SENTINELS. Every mutator returns an `OpResult` naming which rule declined, and
## every reader returns an `IntMath.IntResult`. `NO_FIELD` and `NO_CROP` are §4.2's own "empty"
## encodings, checked by explicit predicates, never returned to signal a failure.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

# --- capacities ---------------------------------------------------------------------------------

## §4.2: "One per FARM zone". The owner class is HarvestZone, so the row index IS the zone's typed
## row and the capacity is read from forage.gd rather than restated. systems_architecture.md §2.2
## budgets FieldPolicy at exactly these 128 rows.
const FIELD_CAPACITY: int = ForageScript.HARVEST_ZONE_CAPACITY
## §4.2's `rotation_ids: int32[3]`, and §5.6's "explicit three-entry cycle".
const ROTATION_LENGTH: int = 3
## The enrolment ledger's owner class: farming.gd's own FarmPlot capacity, read, not restated.
const PLOT_CAPACITY: int = FarmingScript.FARM_PLOT_CAPACITY

# --- §4.2's four defaults -----------------------------------------------------------------------

## §4.2 and the ruling: "grain/beans/roots". §5.6 states the same cycle: "default cycle
## grain->beans->roots". The ids are farming.gd's, which are catalog.gd's (decision 0018).
const DEFAULT_ROTATION: Array[int] = [
	FarmingScript.CROP_GRAIN, FarmingScript.CROP_BEANS, FarmingScript.CROP_ROOTS,
]
## §4.2 and the ruling: "cursor 0".
const DEFAULT_ROTATION_CURSOR: int = 0
## §4.2 and the ruling: "auto false". Load-bearing -- see the header.
const DEFAULT_AUTO_ROTATION: bool = false
## §4.2 and the ruling: "reserve true".
const DEFAULT_SEED_RESERVE: bool = true

# --- the field cycle ----------------------------------------------------------------------------

## No cycle has been opened on this field. Cycle ordinals start at 1, so 0 names none.
const NO_CYCLE: int = 0
## The first cycle opened on a field row.
const FIRST_CYCLE: int = 1
## int32's maximum. `open_cycle()` REFUSES at the cap; the ordinal never wraps onto a live stamp.
const MAX_CYCLE: int = IntMath.INT32_MAX
## §4.2: "empty catalog IDs are -1". An unconfigured rotation entry carries farming.gd's own value.
const NO_CROP: int = FarmingScript.CROP_NONE
## An unenrolled plot names no field. §4.1's null slot, checked explicitly, never returned as a
## failure signal.
const NO_FIELD: int = EntityDirectory.NULL_SLOT

# --- cycle state --------------------------------------------------------------------------------

## No cycle is open and none has closed on this row since it was created.
const CYCLE_IDLE: int = 0
## A planting cycle is in progress: participants may enrol, resolve or withdraw.
const CYCLE_OPEN: int = 1
## The cycle finished. `_close_reason` says how, and the advance decision has already been taken.
const CYCLE_CLOSED: int = 2
const CYCLE_STATE_COUNT: int = 3

# --- how a cycle closed -------------------------------------------------------------------------

## No cycle has closed on this row.
const CLOSE_NONE: int = 0
## Every participating plot finished harvesting or clearing. The ONLY reason that may advance.
const CLOSE_COMPLETED: int = 1
## `cancel_cycle()` closed an unresolved cycle. Recorded as a cancellation, never as a completion.
const CLOSE_CANCELLED: int = 2
## Every participant was withdrawn, so nothing was left that could ever resolve. No advance.
const CLOSE_ABANDONED: int = 3
const CLOSE_REASON_COUNT: int = 4

# --- a participating plot's outcome -------------------------------------------------------------

## Enrolled and still working, or never enrolled in the stamped cycle.
const OUTCOME_UNRESOLVED: int = 0
## REQ-SET-074's successful harvest.
const OUTCOME_HARVESTED: int = 1
## REQ-SET-085's withered clearing. The ruling's "finished harvesting/CLEARING".
const OUTCOME_CLEARED: int = 2
## The tile was erased or undesignated. NOT a resolution and NOT a successful harvest.
const OUTCOME_WITHDRAWN: int = 3
const OUTCOME_COUNT: int = 4

# --- the request, and REQ-SET-077's blocked reasons ---------------------------------------------

## No request stands. The state after an `auto_rotation = false` completion, and the state a
## player edit never leaves.
const REQUEST_NONE: int = 0
## The requested crop's planting window admits it today.
const REQUEST_READY: int = 1
## "If its legal window is future, retain the request."
const REQUEST_WINDOW_FUTURE: int = 2
## "If missed, show the existing warning and wait for its next legal window or a player edit."
const REQUEST_WINDOW_MISSED: int = 3
## The rotation entry at the cursor is `NO_CROP`. NOT skipped and NOT substituted.
const REQUEST_ENTRY_NOT_CONFIGURED: int = 4
## The crop names no legal planting day in the whole year. Unreachable through §5.6's table; kept
## for a save/load path that cannot be trusted to be well formed.
const REQUEST_NO_LEGAL_WINDOW: int = 5
const REQUEST_STATE_COUNT: int = 6

# --- REQ-SET-088's gate, in jobs.gd's own §4.2 values --------------------------------------------

## "This policy declares no such requirement": the reserve is off.
const SEED_GATE_NOT_REQUIRED: int = JobsScript.GATE_NOT_REQUIRED
## Decision 0023's "a missing subsystem must never silently read as satisfied": the reserve is on
## and no reservation path exists to satisfy it. NEVER `GATE_SATISFIED`.
const SEED_GATE_UNAVAILABLE: int = JobsScript.GATE_UNAVAILABLE

# --- refusal codes ------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_FIELD_SLOT: StringName = &"INVALID_FIELD_SLOT"
const REFUSE_INVALID_PLOT_SLOT: StringName = &"INVALID_PLOT_SLOT"
const REFUSE_INVALID_INDEX: StringName = &"INVALID_ROTATION_INDEX"
const REFUSE_INVALID_CURSOR: StringName = &"INVALID_ROTATION_CURSOR"
const REFUSE_INVALID_CROP: StringName = &"INVALID_CROP"
const REFUSE_INVALID_OUTCOME: StringName = &"INVALID_PLOT_OUTCOME"
const REFUSE_INVALID_REQUEST_STATE: StringName = &"INVALID_REQUEST_STATE"
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_INVALID_TILE_COUNT: StringName = &"INVALID_TILE_COUNT"
const REFUSE_ZONE_NOT_PRESENT: StringName = &"ZONE_NOT_PRESENT"
const REFUSE_ZONE_TYPE_MISMATCH: StringName = &"ZONE_TYPE_MISMATCH"
const REFUSE_POLICY_EXISTS: StringName = &"FIELD_POLICY_EXISTS"
const REFUSE_NO_POLICY: StringName = &"NO_FIELD_POLICY"
const REFUSE_CYCLE_OPEN: StringName = &"FIELD_CYCLE_ALREADY_OPEN"
const REFUSE_NO_OPEN_CYCLE: StringName = &"NO_OPEN_FIELD_CYCLE"
const REFUSE_CYCLE_OVERFLOW: StringName = &"FIELD_CYCLE_OVERFLOW"
const REFUSE_PLOT_NOT_PRESENT: StringName = &"PLOT_NOT_PRESENT"
const REFUSE_PLOT_ENROLLED: StringName = &"PLOT_ALREADY_ENROLLED"
const REFUSE_PLOT_NOT_ENROLLED: StringName = &"PLOT_NOT_ENROLLED"
const REFUSE_PLOT_RESOLVED: StringName = &"PLOT_ALREADY_RESOLVED"
const REFUSE_PLOT_WITHDRAWN: StringName = &"PLOT_WITHDRAWN"
const REFUSE_SEED_RESERVE: StringName = &"SEED_RESERVE_UNANSWERABLE"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"

# --- REQ-SET-077's blocked reason codes ----------------------------------------------------------

const BLOCKED_WINDOW_FUTURE: StringName = &"PLANT_WINDOW_IS_FUTURE"
const BLOCKED_WINDOW_MISSED: StringName = &"PLANT_WINDOW_MISSED"
const BLOCKED_ENTRY_NOT_CONFIGURED: StringName = &"ROTATION_ENTRY_NOT_CONFIGURED"
const BLOCKED_NO_LEGAL_WINDOW: StringName = &"CROP_HAS_NO_LEGAL_WINDOW"

## `_request_state` ordinal -> the reason REQ-SET-077 shows for it, or REFUSE_NONE when the
## request is not blocked at all. ONE mapping, so the byte kept on the row and the code shown to
## the player cannot drift. Indexed by REQUEST_*.
const REQUEST_BLOCKED_REASONS: Array[StringName] = [
	REFUSE_NONE, REFUSE_NONE, BLOCKED_WINDOW_FUTURE, BLOCKED_WINDOW_MISSED,
	BLOCKED_ENTRY_NOT_CONFIGURED, BLOCKED_NO_LEGAL_WINDOW,
]


class OpResult:
	"""Outcome of one policy operation: success flag, refusal code, produced value, reference.

	`.ok` MUST be inspected before `.value` or `.ref` is used. A refusal always carries value 0
	and the null reference, so an ignored refusal cannot surface a plausible-looking field row.
	"""
	var ok: bool
	var error: StringName
	var value: int
	var ref: Vector2i

	func _init(p_ok: bool, p_error: StringName, p_value: int, p_ref: Vector2i) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value
		ref = p_ref


# --- collaborating stores -----------------------------------------------------------------------

var _farming: FarmingScript = null
var _forage: ForageScript = null

# --- §4.2's eight budgeted columns (ARCH-MEM-001: packed, allocated once) ------------------------

## §4.2's `zone: EntityRef`, both halves. A HarvestZone row is reused after a destroy, so a policy
## that recorded only the row index would be inherited by whatever zone lands there next.
var _zone_slot: PackedInt32Array = PackedInt32Array()
var _zone_generation: PackedInt32Array = PackedInt32Array()
## §4.2's `rotation_ids: int32[3]`, owner-major: `field * ROTATION_LENGTH + index`.
var _rotation_ids: PackedInt32Array = PackedInt32Array()
## §4.2's `rotation_cursor`: which of the three entries is current. Wraps; counts nothing.
var _rotation_cursor: PackedInt32Array = PackedInt32Array()
## §4.2's `auto_rotation`. Read at cycle close and nowhere else.
var _auto_rotation: PackedByteArray = PackedByteArray()
## §4.2's `seed_reserve`. REQ-SET-088's policy flag; its gate is unsatisfiable in this build.
var _seed_reserve: PackedByteArray = PackedByteArray()

# --- decision 0045's cycle columns (same 128 rows, same allocate-once rule) -----------------------

## 1 while this row holds a policy. §4.2 gives no presence column; a store needs one.
var _field_present: PackedByteArray = PackedByteArray()
## The per-field monotonic ordinal that stamps an enrolment. NOT decision 0040's per-plot cursor.
var _cycle_ordinal: PackedInt32Array = PackedInt32Array()
## Enrolled and not withdrawn. The "all participating plots" the ruling's advance waits for.
var _participants: PackedInt32Array = PackedInt32Array()
## Participants that finished harvesting or clearing. Never incremented by a withdrawal.
var _resolved: PackedInt32Array = PackedInt32Array()
## Participants withdrawn by an erase. Durable, so an ABANDONED close can be explained.
var _withdrawn: PackedInt32Array = PackedInt32Array()
## Durable count of cycles that closed COMPLETED. Completion history the ruling forbids discarding.
var _completed_cycles: PackedInt32Array = PackedInt32Array()
## Durable count of cycles closed by an explicit cancellation. Kept separately from the above so a
## cancellation can never be read back as a completion.
var _cancelled_cycles: PackedInt32Array = PackedInt32Array()
## The crop the advance requested and retained. `NO_CROP` when no request stands.
var _requested_crop: PackedInt32Array = PackedInt32Array()
## CYCLE_IDLE / CYCLE_OPEN / CYCLE_CLOSED.
var _cycle_state: PackedByteArray = PackedByteArray()
## How the last cycle on this row closed.
var _close_reason: PackedByteArray = PackedByteArray()
## The request's state, which is also REQ-SET-077's blocked reason.
var _request_state: PackedByteArray = PackedByteArray()

# --- decision 0045's enrolment ledger, plot-major over farming.gd's own 4096 rows -----------------

## The field row this plot is enrolled in, or NO_FIELD. Meaningful only with a matching stamp.
var _plot_field_slot: PackedInt32Array = PackedInt32Array()
## The field cycle ordinal the enrolment was stamped with. A stamp that no longer matches the
## field's current ordinal is stale, and a stale enrolment can resolve nothing.
var _plot_cycle: PackedInt32Array = PackedInt32Array()
## OUTCOME_UNRESOLVED / HARVESTED / CLEARED / WITHDRAWN.
var _plot_outcome: PackedByteArray = PackedByteArray()

# --- observable counters ------------------------------------------------------------------------

var _policy_count: int = 0
var _opened_count: int = 0
var _completed_count: int = 0
var _cancelled_count: int = 0
var _abandoned_count: int = 0
var _advance_count: int = 0
var _resolved_plot_count: int = 0
var _withdrawn_plot_count: int = 0
var _retained_request_count: int = 0
var _missed_request_count: int = 0

# --- scratch (not simulation state) --------------------------------------------------------------

var _math: IntMath.IntResult = IntMath.IntResult.new()
## One owned Calendar, re-decoded through `SimClock.calendar_at_into()`. Every field is read into
## a local before anything else can touch it, so no two live values share this instance.
var _calendar: SimClock.Calendar = SimClock.Calendar.new()


func _init(p_farming: FarmingScript = null, p_forage: ForageScript = null) -> void:
	"""Bind the farm and zone stores, assert every borrowed contract, and allocate once."""
	_farming = p_farming if p_farming != null else FarmingScript.new()
	_forage = p_forage if p_forage != null else ForageScript.new(_farming.directory())
	_assert_borrowed_contracts()
	_allocate_columns()
	clear()


func _assert_borrowed_contracts() -> void:
	"""Assert the capacities, defaults and gate values this module reads rather than restates.

	Every number here belongs to another document or module. A drift assert is cheaper than a
	store that silently addresses 128 rows of a 256-row owner class.
	"""
	assert(FIELD_CAPACITY == ForageScript.HARVEST_ZONE_CAPACITY,
		"FieldPolicy rows must equal §4.2's HarvestZone capacity")
	assert(PLOT_CAPACITY == FarmingScript.FARM_PLOT_CAPACITY,
		"the enrolment ledger must equal farming.gd's FarmPlot capacity")
	assert(ROTATION_LENGTH == DEFAULT_ROTATION.size(),
		"§4.2's rotation_ids is int32[3] and the default cycle has three entries")
	assert(REQUEST_BLOCKED_REASONS.size() == REQUEST_STATE_COUNT,
		"every request state must map to exactly one REQ-SET-077 reason")
	assert(SEED_GATE_UNAVAILABLE != JobsScript.GATE_SATISFIED,
		"REQ-SET-088's gate must never read as satisfied")
	assert(not DEFAULT_AUTO_ROTATION, "the ruling's FieldPolicy default is auto_rotation=false")
	assert(DEFAULT_SEED_RESERVE, "the ruling's FieldPolicy default is seed_reserve=true")


func _allocate_columns() -> void:
	"""Size every packed column exactly once. Nothing outside this function calls resize().

	Each column is resized BY NAME. A loop over an `Array` of packed columns would resize COPIES:
	`PackedInt32Array` is a value type, so binding one to a loop variable duplicates it and the
	member arrays would stay empty.
	"""
	_zone_slot.resize(FIELD_CAPACITY)
	_zone_generation.resize(FIELD_CAPACITY)
	_rotation_ids.resize(FIELD_CAPACITY * ROTATION_LENGTH)
	_rotation_cursor.resize(FIELD_CAPACITY)
	_auto_rotation.resize(FIELD_CAPACITY)
	_seed_reserve.resize(FIELD_CAPACITY)
	_field_present.resize(FIELD_CAPACITY)
	_cycle_ordinal.resize(FIELD_CAPACITY)
	_participants.resize(FIELD_CAPACITY)
	_resolved.resize(FIELD_CAPACITY)
	_withdrawn.resize(FIELD_CAPACITY)
	_completed_cycles.resize(FIELD_CAPACITY)
	_cancelled_cycles.resize(FIELD_CAPACITY)
	_requested_crop.resize(FIELD_CAPACITY)
	_cycle_state.resize(FIELD_CAPACITY)
	_close_reason.resize(FIELD_CAPACITY)
	_request_state.resize(FIELD_CAPACITY)
	_allocate_enrolment_ledger()


func _allocate_enrolment_ledger() -> void:
	"""Size decision 0045's plot-major enrolment ledger once, over farming.gd's 4096 FarmPlots."""
	_plot_field_slot.resize(PLOT_CAPACITY)
	_plot_cycle.resize(PLOT_CAPACITY)
	_plot_outcome.resize(PLOT_CAPACITY)


func clear() -> void:
	"""Refill every existing buffer to the empty store. Allocates nothing and resizes nothing."""
	_zone_slot.fill(EntityDirectory.NULL_SLOT)
	_zone_generation.fill(EntityDirectory.NULL_GENERATION)
	_rotation_ids.fill(NO_CROP)
	_rotation_cursor.fill(DEFAULT_ROTATION_CURSOR)
	_auto_rotation.fill(1 if DEFAULT_AUTO_ROTATION else 0)
	_seed_reserve.fill(1 if DEFAULT_SEED_RESERVE else 0)
	_field_present.fill(0)
	_cycle_ordinal.fill(NO_CYCLE)
	_participants.fill(0)
	_resolved.fill(0)
	_withdrawn.fill(0)
	_completed_cycles.fill(0)
	_cancelled_cycles.fill(0)
	_requested_crop.fill(NO_CROP)
	_cycle_state.fill(CYCLE_IDLE)
	_close_reason.fill(CLOSE_NONE)
	_request_state.fill(REQUEST_NONE)
	_plot_field_slot.fill(NO_FIELD)
	_plot_cycle.fill(NO_CYCLE)
	_plot_outcome.fill(OUTCOME_UNRESOLVED)
	_reset_counters()


func _reset_counters() -> void:
	"""Zero every observable counter."""
	_policy_count = 0
	_opened_count = 0
	_completed_count = 0
	_cancelled_count = 0
	_abandoned_count = 0
	_advance_count = 0
	_resolved_plot_count = 0
	_withdrawn_plot_count = 0
	_retained_request_count = 0
	_missed_request_count = 0


func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful outcome carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refusal carrying no value and no reference."""
	return OpResult.new(false, code, 0, EntityDirectory.NULL_REF)


func farming() -> FarmingScript:
	"""The FarmPlot store this policy validates plots and planting windows against."""
	return _farming


func forage() -> ForageScript:
	"""The HarvestZone store this policy validates its FARM zone against."""
	return _forage


# --- rows and presence ---------------------------------------------------------------------------

func is_field_slot(field_slot: int) -> bool:
	"""True when `field_slot` addresses a row of the 128-row FieldPolicy table."""
	return field_slot >= 0 and field_slot < FIELD_CAPACITY


func is_present(field_slot: int) -> bool:
	"""True when this row holds a policy. Says nothing about the bound zone still being live."""
	return is_field_slot(field_slot) and _field_present[field_slot] == 1


func zone_is_live(field_slot: int) -> bool:
	"""True when this row holds a policy AND both halves of its zone EntityRef still resolve.

	Both halves are checked, because a HarvestZone row is reused after a destroy: a policy that
	compared only the row index would be inherited by whatever zone lands there next.
	"""
	if not is_present(field_slot):
		return false
	if not _forage.is_zone_present(field_slot):
		return false
	var ref: Vector2i = _forage.zone_ref_of(field_slot)
	return ref.x == _zone_slot[field_slot] and ref.y == _zone_generation[field_slot]


func zone_ref_of(field_slot: int) -> Vector2i:
	"""The zone EntityRef this policy is bound to, or §4.1's null reference `(-1, 0)`."""
	if not is_present(field_slot):
		return EntityDirectory.NULL_REF
	return Vector2i(_zone_slot[field_slot], _zone_generation[field_slot])


func field_slot_of(zone_ref: Vector2i) -> IntMath.IntResult:
	"""The policy row a live FARM-zone reference addresses, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	field_slot_of_into(zone_ref, out)
	return out


func field_slot_of_into(zone_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating field_slot_of(): write the validated row into caller-owned `out`."""
	if not _forage.zone_slot_of_into(zone_ref, out):
		return false
	var slot: int = out.value
	if not zone_is_live(slot):
		return out.refuse(String(REFUSE_NO_POLICY))
	return out.succeed(slot)


func _resolve(zone_ref: Vector2i) -> int:
	"""The live policy row for a zone reference, or -1 when `_math` now holds the refusal.

	Private, and its -1 is never returned to a caller: every public entry point converts `_math`'s
	refusal into an explicit `OpResult`. See the header on sentinels.
	"""
	if field_slot_of_into(zone_ref, _math):
		return _math.value
	return NO_FIELD


func policy_count() -> int:
	"""Number of live FieldPolicy rows."""
	return _policy_count


# --- creation and destruction --------------------------------------------------------------------

func create_policy(zone_ref: Vector2i) -> OpResult:
	"""Bind one FieldPolicy to a live FARM-type zone, with §4.2's four defaults. Returns its row.

	The row index IS the zone's typed row, which is what "one per FARM zone" means with a
	128-row policy table over a 128-row zone table; no allocator is needed and none is added.
	`_cycle_ordinal` is deliberately NOT reset, so a row reused by a different zone cannot
	inherit a stale enrolment stamp.
	"""
	if not _forage.zone_slot_of_into(zone_ref, _math):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	var slot: int = _math.value
	var zone_type: IntMath.IntResult = _forage.zone_type_of(slot)
	if not zone_type.ok:
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	if zone_type.value != ForageScript.ZONE_TYPE_FARM:
		return _refuse(REFUSE_ZONE_TYPE_MISMATCH)
	if _field_present[slot] == 1:
		if zone_is_live(slot):
			return _refuse(REFUSE_POLICY_EXISTS)
		_reclaim_stale_policy(slot)
	_write_default_policy(slot, zone_ref)
	return _succeed(slot, zone_ref)


func _reclaim_stale_policy(field_slot: int) -> void:
	"""Retire a policy whose zone was destroyed, so the reused row is not refused as occupied.

	`destroy_policy()` cannot reach such a row -- its own zone reference no longer resolves -- so
	without this a destroyed FARM zone would permanently block its row. The enrolment ledger is
	not walked: `_cycle_ordinal` is never reset, so every stamp written under the old policy is
	already stale for the new one.
	"""
	_field_present[field_slot] = 0
	_cycle_state[field_slot] = CYCLE_IDLE
	_policy_count -= 1


func _write_default_policy(field_slot: int, zone_ref: Vector2i) -> void:
	"""Write §4.2's row for a new policy: grain/beans/roots, cursor 0, auto false, reserve true."""
	_zone_slot[field_slot] = zone_ref.x
	_zone_generation[field_slot] = zone_ref.y
	for index: int in ROTATION_LENGTH:
		_rotation_ids[field_slot * ROTATION_LENGTH + index] = DEFAULT_ROTATION[index]
	_rotation_cursor[field_slot] = DEFAULT_ROTATION_CURSOR
	_auto_rotation[field_slot] = 1 if DEFAULT_AUTO_ROTATION else 0
	_seed_reserve[field_slot] = 1 if DEFAULT_SEED_RESERVE else 0
	_participants[field_slot] = 0
	_resolved[field_slot] = 0
	_withdrawn[field_slot] = 0
	_completed_cycles[field_slot] = 0
	_cancelled_cycles[field_slot] = 0
	_requested_crop[field_slot] = NO_CROP
	_cycle_state[field_slot] = CYCLE_IDLE
	_close_reason[field_slot] = CLOSE_NONE
	_request_state[field_slot] = REQUEST_NONE
	_field_present[field_slot] = 1
	_policy_count += 1


func destroy_policy(zone_ref: Vector2i) -> OpResult:
	"""Retire the policy bound to a zone. Any open cycle's enrolments go stale, never inherited.

	The enrolment ledger is NOT walked: `_cycle_ordinal` stays where it is and is never reset, so
	every stamp written under this policy fails the ordinal check for whatever policy occupies the
	row next. That is the same generation-validation discipline §4.1 applies to EntityRefs.
	"""
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	_zone_slot[field_slot] = EntityDirectory.NULL_SLOT
	_zone_generation[field_slot] = EntityDirectory.NULL_GENERATION
	_cycle_state[field_slot] = CYCLE_IDLE
	_request_state[field_slot] = REQUEST_NONE
	_requested_crop[field_slot] = NO_CROP
	_participants[field_slot] = 0
	_resolved[field_slot] = 0
	_field_present[field_slot] = 0
	_policy_count -= 1
	return _succeed(field_slot, zone_ref)


# --- §4.2's policy columns: the player edit path (blocker U2) --------------------------------------

func set_rotation(zone_ref: Vector2i, id_0: int, id_1: int, id_2: int, tick: int) -> OpResult:
	"""Replace §4.2's three rotation entries. STARTS NO WORK -- the ruling says so explicitly.

	Each entry is a crop id or `NO_CROP`; anything else refuses and writes nothing. The cursor is
	left where it was: an edit is not an advance. An OUTSTANDING request is re-evaluated against
	the edited list, because "a player edit" is the ruling's own second way out of a missed
	window; a row with no request keeps none.
	"""
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	if not _is_rotation_entry(id_0) or not _is_rotation_entry(id_1) \
			or not _is_rotation_entry(id_2):
		return _refuse(REFUSE_INVALID_CROP)
	var base: int = field_slot * ROTATION_LENGTH
	_rotation_ids[base] = id_0
	_rotation_ids[base + 1] = id_1
	_rotation_ids[base + 2] = id_2
	_refresh_outstanding_request(field_slot, tick)
	return _succeed(field_slot, zone_ref)


func _is_rotation_entry(crop_id: int) -> bool:
	"""True when a rotation entry names a §5.6 crop or is §4.2's explicit empty catalog id."""
	return crop_id == NO_CROP or _farming.is_crop(crop_id)


func set_rotation_cursor(zone_ref: Vector2i, cursor: int, tick: int) -> OpResult:
	"""Point §4.2's cursor at one of the three entries. STARTS NO WORK; this is a player edit.

	It is deliberately NOT the advance: `_advance_rotation()` is the only caller that moves the
	cursor by one on a completed cycle, and it is the only place `_advance_count` moves.
	"""
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	if cursor < 0 or cursor >= ROTATION_LENGTH:
		return _refuse(REFUSE_INVALID_CURSOR)
	_rotation_cursor[field_slot] = cursor
	_refresh_outstanding_request(field_slot, tick)
	return _succeed(cursor, zone_ref)


func set_auto_rotation(zone_ref: Vector2i, enabled: bool) -> OpResult:
	"""Set §4.2's `auto_rotation`. STARTS NO WORK and never advances a cycle that already closed.

	The gate is read at close time, so enabling this after a completion does not retroactively
	request a crop for it: that completion has already been settled under the old value.
	"""
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	_auto_rotation[field_slot] = 1 if enabled else 0
	return _succeed(field_slot, zone_ref)


func set_seed_reserve(zone_ref: Vector2i, enabled: bool) -> OpResult:
	"""Set §4.2's `seed_reserve`. STARTS NO WORK. See the header on REQ-SET-088's gate."""
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	_seed_reserve[field_slot] = 1 if enabled else 0
	return _succeed(field_slot, zone_ref)


func _refresh_outstanding_request(field_slot: int, tick: int) -> void:
	"""Re-evaluate an outstanding request after a player edit. Creates none where none stands.

	This is the ruling's "or a player edit". It cannot start work and cannot advance the cursor:
	it re-reads the entry the cursor already points at and re-classifies its window.
	"""
	if _request_state[field_slot] == REQUEST_NONE:
		return
	_request_crop_at_cursor(field_slot, tick)


# --- the field cycle -----------------------------------------------------------------------------

static func can_open_cycle(ordinal: int) -> bool:
	"""True when one more cycle ordinal fits above `ordinal` without leaving int32.

	The cap REFUSES rather than wrapping: a wrapped ordinal could match a stale enrolment stamp,
	and this codebase has already been bitten by an overflow sentinel a merge gate accepted.
	Public and static so the boundary is testable without 2^31 cycles.
	"""
	return ordinal >= NO_CYCLE and ordinal < MAX_CYCLE


func open_cycle(zone_ref: Vector2i) -> OpResult:
	"""Open the next planting cycle on a field and return its ordinal. Enrolments come after.

	Opening CONSUMES any outstanding request: the field is now planting, so the request the last
	advance retained has been acted on. Refuses while a cycle is already open, so a caller cannot
	silently discard an unresolved one -- `cancel_cycle()` is the entry point that records that.
	"""
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	if _cycle_state[field_slot] == CYCLE_OPEN:
		return _refuse(REFUSE_CYCLE_OPEN)
	if not can_open_cycle(_cycle_ordinal[field_slot]):
		return _refuse(REFUSE_CYCLE_OVERFLOW)
	_cycle_ordinal[field_slot] += 1
	_participants[field_slot] = 0
	_resolved[field_slot] = 0
	_withdrawn[field_slot] = 0
	_cycle_state[field_slot] = CYCLE_OPEN
	_close_reason[field_slot] = CLOSE_NONE
	_request_state[field_slot] = REQUEST_NONE
	_requested_crop[field_slot] = NO_CROP
	_opened_count += 1
	return _succeed(_cycle_ordinal[field_slot], zone_ref)


func enrol_plot(zone_ref: Vector2i, plot_slot: int) -> OpResult:
	"""Add one validated plot to the open cycle's participating set. Returns the new count.

	The set is caller-supplied because no store groups plots into fields -- see the header. What
	is validated here is everything that CAN be: a live FarmPlot row, an open cycle, and that the
	plot is not already enrolled in some field's open cycle.
	"""
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	if _cycle_state[field_slot] != CYCLE_OPEN:
		return _refuse(REFUSE_NO_OPEN_CYCLE)
	if not is_plot_slot(plot_slot):
		return _refuse(REFUSE_INVALID_PLOT_SLOT)
	if not _farming.is_present(plot_slot):
		return _refuse(REFUSE_PLOT_NOT_PRESENT)
	if is_plot_enrolled(plot_slot):
		return _refuse(REFUSE_PLOT_ENROLLED)
	_plot_field_slot[plot_slot] = field_slot
	_plot_cycle[plot_slot] = _cycle_ordinal[field_slot]
	_plot_outcome[plot_slot] = OUTCOME_UNRESOLVED
	_participants[field_slot] += 1
	return _succeed(_participants[field_slot], zone_ref)


func is_plot_slot(plot_slot: int) -> bool:
	"""True when `plot_slot` addresses a row of the 4096-row enrolment ledger."""
	return plot_slot >= 0 and plot_slot < PLOT_CAPACITY


func is_plot_enrolled(plot_slot: int) -> bool:
	"""True when this plot participates in some field's CURRENTLY OPEN cycle.

	Three things must hold together: a named field, that field's cycle open, and a stamp equal to
	that field's current ordinal. A stamp from a previous cycle is stale and reports false, which
	is what lets a plot be enrolled again next cycle without any ledger being walked.
	"""
	if not is_plot_slot(plot_slot):
		return false
	var field_slot: int = _plot_field_slot[plot_slot]
	if not is_present(field_slot):
		return false
	if _cycle_state[field_slot] != CYCLE_OPEN:
		return false
	return _plot_cycle[plot_slot] == _cycle_ordinal[field_slot]


func record_plot_resolved(zone_ref: Vector2i, plot_slot: int, outcome: int,
		tick: int) -> OpResult:
	"""Record one participant finishing HARVESTING or CLEARING, and close the cycle if it is last.

	This is the ONLY entry point that increments `_resolved`, and therefore the only one that can
	complete a cycle. `OUTCOME_WITHDRAWN` is refused here on purpose: erasing a tile is not a
	successful harvest, and `withdraw_plot()` is its own path.
	"""
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	if outcome != OUTCOME_HARVESTED and outcome != OUTCOME_CLEARED:
		return _refuse(REFUSE_INVALID_OUTCOME)
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	var code: StringName = _check_participant(field_slot, plot_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	_plot_outcome[plot_slot] = outcome
	_resolved[field_slot] += 1
	_resolved_plot_count += 1
	_maybe_close_cycle(field_slot, tick)
	return _succeed(_resolved[field_slot], zone_ref)


func withdraw_plot(zone_ref: Vector2i, plot_slot: int, tick: int) -> OpResult:
	"""Remove an UNRESOLVED participant whose tile was erased. NOT a harvest and NOT a resolution.

	`_resolved` is never touched here, so no erasure can ever advance a rotation on its own. A
	plot that already harvested or cleared REFUSES: that outcome happened and stays recorded,
	which is also what keeps `_resolved <= _participants` true.
	"""
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	var code: StringName = _check_participant(field_slot, plot_slot)
	if code != REFUSE_NONE:
		return _refuse(code)
	_plot_outcome[plot_slot] = OUTCOME_WITHDRAWN
	_participants[field_slot] -= 1
	_withdrawn[field_slot] += 1
	_withdrawn_plot_count += 1
	_maybe_close_cycle(field_slot, tick)
	return _succeed(_participants[field_slot], zone_ref)


func _check_participant(field_slot: int, plot_slot: int) -> StringName:
	"""The refusal a resolution or withdrawal of this plot earns, or REFUSE_NONE when it is legal.

	Five guards, and every one of them is part of "advance exactly once": an open cycle, a valid
	row, an enrolment stamped with THIS cycle, an outcome that is not a withdrawal, and an outcome
	still UNRESOLVED. A withdrawal gets its OWN code: a caller cannot act on "this tile was erased"
	and "this plot already harvested" the same way, and folding them together would report an
	erasure as a recorded harvest.
	"""
	if _cycle_state[field_slot] != CYCLE_OPEN:
		return REFUSE_NO_OPEN_CYCLE
	if not is_plot_slot(plot_slot):
		return REFUSE_INVALID_PLOT_SLOT
	if not is_plot_enrolled(plot_slot) or _plot_field_slot[plot_slot] != field_slot:
		return REFUSE_PLOT_NOT_ENROLLED
	if _plot_outcome[plot_slot] == OUTCOME_WITHDRAWN:
		return REFUSE_PLOT_WITHDRAWN
	if _plot_outcome[plot_slot] != OUTCOME_UNRESOLVED:
		return REFUSE_PLOT_RESOLVED
	return REFUSE_NONE


func cancel_cycle(zone_ref: Vector2i) -> OpResult:
	"""Close an open cycle as an EXPLICIT CANCELLATION. Records one; fabricates no completion.

	The ruling: "explicitly cancelled unresolved cycles need a recorded cancellation rather than
	fabricated completion". So this increments the field's durable cancellation count, leaves the
	completion count alone, advances nothing and requests nothing.
	"""
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	if _cycle_state[field_slot] != CYCLE_OPEN:
		return _refuse(REFUSE_NO_OPEN_CYCLE)
	_close_cycle(field_slot, CLOSE_CANCELLED, 0)
	return _succeed(_cancelled_cycles[field_slot], zone_ref)


func _maybe_close_cycle(field_slot: int, tick: int) -> void:
	"""Close the cycle if and only if the participating set has fully resolved, or emptied.

	THIS IS THE ONCE-PER-FIELD GUARD. A fast plot resolving first leaves `_resolved` below
	`_participants` and closes nothing, which is exactly the ruling's "waits for all participating
	plots in the current cycle to resolve, preventing fast tiles from advancing the entire field
	repeatedly". `_participants == 0` implies `_resolved == 0` -- a resolved plot cannot be
	withdrawn -- so an emptied field closes ABANDONED and never advances.
	"""
	if _participants[field_slot] == 0:
		_close_cycle(field_slot, CLOSE_ABANDONED, tick)
		return
	if _resolved[field_slot] < _participants[field_slot]:
		return
	_close_cycle(field_slot, CLOSE_COMPLETED, tick)


func _close_cycle(field_slot: int, reason: int, tick: int) -> void:
	"""Settle one cycle under its close reason. Only CLOSE_COMPLETED may reach the advance."""
	_cycle_state[field_slot] = CYCLE_CLOSED
	_close_reason[field_slot] = reason
	if reason == CLOSE_CANCELLED:
		_cancelled_cycles[field_slot] += 1
		_cancelled_count += 1
		return
	if reason == CLOSE_ABANDONED:
		_abandoned_count += 1
		return
	_completed_cycles[field_slot] += 1
	_completed_count += 1
	_advance_rotation(field_slot, tick)


func _advance_rotation(field_slot: int, tick: int) -> void:
	"""R06-JOB-005's advance: move the cursor ONE step and request the crop it now names.

	The `auto_rotation` gate is the FIRST statement, so "with auto_rotation=false, completion
	shall not request another sowing cycle" holds structurally. The step is `+1` modulo the
	three-entry list and is evaluated exactly once per completed cycle; there is no loop, no
	skip and no substitution anywhere below it.
	"""
	if _auto_rotation[field_slot] == 0:
		_request_state[field_slot] = REQUEST_NONE
		_requested_crop[field_slot] = NO_CROP
		return
	_rotation_cursor[field_slot] = (_rotation_cursor[field_slot] + 1) % ROTATION_LENGTH
	_advance_count += 1
	_request_crop_at_cursor(field_slot, tick)


func _request_crop_at_cursor(field_slot: int, tick: int) -> void:
	"""Request the crop the cursor names, and classify its planting window.

	It reads ONE entry -- the one at the cursor -- and never looks at the other two. An entry that
	is not a crop blocks with ROTATION_ENTRY_NOT_CONFIGURED and the cursor STAYS ON IT: §5.6 is
	explicit that a blocked planting "does not choose a different seed without the player's
	rotation rule".
	"""
	var crop: int = _rotation_ids[field_slot * ROTATION_LENGTH + _rotation_cursor[field_slot]]
	_requested_crop[field_slot] = crop
	if not _farming.is_crop(crop):
		_request_state[field_slot] = REQUEST_ENTRY_NOT_CONFIGURED
		return
	var state: int = _classify_window(crop, tick)
	_request_state[field_slot] = state
	if state == REQUEST_WINDOW_FUTURE:
		_retained_request_count += 1
	elif state == REQUEST_WINDOW_MISSED:
		_missed_request_count += 1


func _classify_window(crop_id: int, tick: int) -> int:
	"""READY, WINDOW_FUTURE, WINDOW_MISSED or NO_LEGAL_WINDOW for a crop at `tick`.

	The year is 48 season-local days (SimClock's own SEASONS_PER_YEAR * DAYS_PER_SEASON) and the
	admission test is `farming.is_plant_window()` -- §5.6's OWNING formula, never a copy of its
	window table. A missed window is still a future one next year; the ruling distinguishes them
	so the UI can warn, and both retain the request.
	"""
	SimClock.calendar_at_into(tick, _calendar)
	var today: int = _calendar.season * SimClock.DAYS_PER_SEASON + _calendar.season_day - 1
	if _farming.is_plant_window(crop_id, _calendar.season, _calendar.season_day):
		return REQUEST_READY
	var seen_any: bool = false
	for ordinal: int in SimClock.DAYS_PER_YEAR:
		if not _farming.is_plant_window(crop_id, ordinal / SimClock.DAYS_PER_SEASON,
				ordinal % SimClock.DAYS_PER_SEASON + 1):
			continue
		seen_any = true
		if ordinal > today:
			return REQUEST_WINDOW_FUTURE
	return REQUEST_WINDOW_MISSED if seen_any else REQUEST_NO_LEGAL_WINDOW


# --- REQ-SET-088: an unsatisfiable gate that refuses ----------------------------------------------

func seed_reserve_gate_of(field_slot: int) -> IntMath.IntResult:
	"""REQ-SET-088's gate for this field: NOT_REQUIRED when off, UNAVAILABLE when on. Never
	SATISFIED. See seed_reserve_gate_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	seed_reserve_gate_into(field_slot, out)
	return out


func seed_reserve_gate_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating seed_reserve_gate_of().

	`GATE_UNAVAILABLE` is decision 0023's "a missing subsystem must never silently read as
	satisfied": every `reservations.gd` row is owned by a Job EntityRef and a standing seed
	reserve has no Job, so nothing in this build can hold the reserve. Answering GATE_SATISFIED
	would fabricate a seed supply.
	"""
	if not is_present(field_slot):
		return out.refuse(String(REFUSE_NO_POLICY))
	if _seed_reserve[field_slot] == 0:
		return out.succeed(SEED_GATE_NOT_REQUIRED)
	return out.succeed(SEED_GATE_UNAVAILABLE)


func authorise_seed_release(zone_ref: Vector2i) -> OpResult:
	"""Ask whether seed may leave for export or nonplanting use. REFUSES while the reserve is on.

	REQ-SET-088 requires the next planting's seed be reserved BEFORE such a release. No path
	exists to reserve it, so this can never say yes while the policy is enabled, and it says so
	with its own code rather than pretending the reserve was taken.
	"""
	var field_slot: int = _resolve(zone_ref)
	if field_slot == NO_FIELD:
		return _refuse(StringName(_math.error))
	if _seed_reserve[field_slot] == 1:
		return _refuse(REFUSE_SEED_RESERVE)
	return _succeed(SEED_GATE_NOT_REQUIRED, zone_ref)


func next_planting_crop_of(field_slot: int) -> IntMath.IntResult:
	"""The crop the next planting on this field would use. See next_planting_crop_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	next_planting_crop_into(field_slot, out)
	return out


func next_planting_crop_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating next_planting_crop_of(): the retained request, else the cursor's entry.

	Both readings are the player's own configuration; neither substitutes a crop.
	"""
	if not is_present(field_slot):
		return out.refuse(String(REFUSE_NO_POLICY))
	if _request_state[field_slot] != REQUEST_NONE:
		return out.succeed(_requested_crop[field_slot])
	return out.succeed(_rotation_ids[field_slot * ROTATION_LENGTH + _rotation_cursor[field_slot]])


func seed_requirement_milli_of(field_slot: int, tile_count: int) -> IntMath.IntResult:
	"""§5.6's seed U/tile for the next planting times `tile_count`. See the _into() form."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	seed_requirement_milli_into(field_slot, tile_count, out)
	return out


func seed_requirement_milli_into(field_slot: int, tile_count: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating seed_requirement_milli_of(). Overflow refuses; it never wraps.

	The tile count is CALLER-SUPPLIED for the same reason the participating set is: nothing groups
	tiles into a field (see the header). This answers a QUANTITY only -- the crop -> seed item id
	join is not authored anywhere and is not invented here.
	"""
	if not next_planting_crop_into(field_slot, out):
		return false
	var crop: int = out.value
	if not _farming.is_crop(crop):
		return out.refuse(String(REFUSE_INVALID_CROP))
	if tile_count < 0:
		return out.refuse(String(REFUSE_INVALID_TILE_COUNT))
	var per_tile: IntMath.IntResult = _farming.seed_milli_of(crop)
	if not per_tile.ok:
		return out.refuse(String(REFUSE_INVALID_CROP))
	if not IntMath.checked_mul_into(per_tile.value, tile_count, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return true


# --- readers: §4.2's own columns ------------------------------------------------------------------

func rotation_id_of(field_slot: int, index: int) -> IntMath.IntResult:
	"""One of §4.2's three rotation entries, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	rotation_id_into(field_slot, index, out)
	return out


func rotation_id_into(field_slot: int, index: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating rotation_id_of()."""
	if not is_present(field_slot):
		return out.refuse(String(REFUSE_NO_POLICY))
	if index < 0 or index >= ROTATION_LENGTH:
		return out.refuse(String(REFUSE_INVALID_INDEX))
	return out.succeed(_rotation_ids[field_slot * ROTATION_LENGTH + index])


func rotation_cursor_of(field_slot: int) -> IntMath.IntResult:
	"""§4.2's `rotation_cursor` for this field, or an explicit refusal."""
	return _read_field(field_slot, _rotation_cursor)


func rotation_cursor_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating rotation_cursor_of()."""
	return _read_field_into(field_slot, _rotation_cursor, out)


func is_auto_rotation(field_slot: int) -> bool:
	"""§4.2's `auto_rotation`. False for a row that holds no policy."""
	return is_present(field_slot) and _auto_rotation[field_slot] == 1


func is_seed_reserve(field_slot: int) -> bool:
	"""§4.2's `seed_reserve`. False for a row that holds no policy."""
	return is_present(field_slot) and _seed_reserve[field_slot] == 1


# --- readers: decision 0045's cycle columns -------------------------------------------------------

func cycle_ordinal_of(field_slot: int) -> IntMath.IntResult:
	"""This field's current cycle ordinal, or NO_CYCLE before the first open."""
	return _read_field(field_slot, _cycle_ordinal)


func cycle_ordinal_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating cycle_ordinal_of()."""
	return _read_field_into(field_slot, _cycle_ordinal, out)


func cycle_state_of(field_slot: int) -> IntMath.IntResult:
	"""CYCLE_IDLE, CYCLE_OPEN or CYCLE_CLOSED for this field."""
	return _read_byte_field(field_slot, _cycle_state)


func cycle_state_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating cycle_state_of()."""
	return _read_byte_field_into(field_slot, _cycle_state, out)


func close_reason_of(field_slot: int) -> IntMath.IntResult:
	"""How the last cycle on this field closed: NONE, COMPLETED, CANCELLED or ABANDONED."""
	return _read_byte_field(field_slot, _close_reason)


func close_reason_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating close_reason_of()."""
	return _read_byte_field_into(field_slot, _close_reason, out)


func participant_count_of(field_slot: int) -> IntMath.IntResult:
	"""Plots enrolled in the current cycle and not withdrawn."""
	return _read_field(field_slot, _participants)


func participant_count_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating participant_count_of()."""
	return _read_field_into(field_slot, _participants, out)


func resolved_count_of(field_slot: int) -> IntMath.IntResult:
	"""Participants that finished harvesting or clearing in the current cycle."""
	return _read_field(field_slot, _resolved)


func resolved_count_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating resolved_count_of()."""
	return _read_field_into(field_slot, _resolved, out)


func withdrawn_count_of(field_slot: int) -> IntMath.IntResult:
	"""Participants withdrawn from the current cycle by an erase. Never counted as harvests."""
	return _read_field(field_slot, _withdrawn)


func withdrawn_count_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating withdrawn_count_of()."""
	return _read_field_into(field_slot, _withdrawn, out)


func completed_cycle_count_of(field_slot: int) -> IntMath.IntResult:
	"""Durable count of cycles that closed COMPLETED on this field."""
	return _read_field(field_slot, _completed_cycles)


func completed_cycle_count_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating completed_cycle_count_of()."""
	return _read_field_into(field_slot, _completed_cycles, out)


func cancelled_cycle_count_of(field_slot: int) -> IntMath.IntResult:
	"""Durable count of cycles closed by an explicit cancellation on this field."""
	return _read_field(field_slot, _cancelled_cycles)


func cancelled_cycle_count_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating cancelled_cycle_count_of()."""
	return _read_field_into(field_slot, _cancelled_cycles, out)


func requested_crop_of(field_slot: int) -> IntMath.IntResult:
	"""The crop the last advance requested and retained, or NO_CROP when no request stands."""
	return _read_field(field_slot, _requested_crop)


func requested_crop_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating requested_crop_of()."""
	return _read_field_into(field_slot, _requested_crop, out)


func request_state_of(field_slot: int) -> IntMath.IntResult:
	"""The request's state, which is also REQ-SET-077's blocked reason ordinal."""
	return _read_byte_field(field_slot, _request_state)


func request_state_into(field_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating request_state_of()."""
	return _read_byte_field_into(field_slot, _request_state, out)


func blocked_reason_of_state(request_state: int) -> StringName:
	"""REQ-SET-077's blocked reason for a request state, or REFUSE_NONE when it is not blocked.

	One mapping shared with the row's own byte, so what is retained and what is shown to the
	player cannot drift. An out-of-domain ordinal refuses rather than indexing past the table.
	"""
	if request_state < 0 or request_state >= REQUEST_STATE_COUNT:
		return REFUSE_INVALID_REQUEST_STATE
	return REQUEST_BLOCKED_REASONS[request_state]


func blocked_reason_of(field_slot: int) -> StringName:
	"""REQ-SET-077's blocked reason for this field's outstanding request."""
	if not is_present(field_slot):
		return REFUSE_NO_POLICY
	return REQUEST_BLOCKED_REASONS[_request_state[field_slot]]


func plot_outcome_of(plot_slot: int) -> IntMath.IntResult:
	"""A plot's recorded outcome in the cycle its enrolment was stamped with."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	plot_outcome_into(plot_slot, out)
	return out


func plot_outcome_into(plot_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating plot_outcome_of()."""
	if not is_plot_slot(plot_slot):
		return out.refuse(String(REFUSE_INVALID_PLOT_SLOT))
	return out.succeed(_plot_outcome[plot_slot])


func plot_field_slot_of(plot_slot: int) -> IntMath.IntResult:
	"""The field row a plot is enrolled in, or an explicit refusal when the enrolment is stale.

	It refuses rather than returning NO_FIELD as an answer, so "not enrolled" can never be read
	as field row -1.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	plot_field_slot_into(plot_slot, out)
	return out


func plot_field_slot_into(plot_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating plot_field_slot_of()."""
	if not is_plot_slot(plot_slot):
		return out.refuse(String(REFUSE_INVALID_PLOT_SLOT))
	if not is_plot_enrolled(plot_slot):
		return out.refuse(String(REFUSE_PLOT_NOT_ENROLLED))
	return out.succeed(_plot_field_slot[plot_slot])


func _read_field(field_slot: int, column: PackedInt32Array) -> IntMath.IntResult:
	"""One int32 field column, or an explicit refusal for a row holding no policy."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	_read_field_into(field_slot, column, out)
	return out


func _read_field_into(field_slot: int, column: PackedInt32Array,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating _read_field()."""
	if not is_present(field_slot):
		return out.refuse(String(REFUSE_NO_POLICY))
	return out.succeed(column[field_slot])


func _read_byte_field(field_slot: int, column: PackedByteArray) -> IntMath.IntResult:
	"""One byte field column, or an explicit refusal for a row holding no policy."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	_read_byte_field_into(field_slot, column, out)
	return out


func _read_byte_field_into(field_slot: int, column: PackedByteArray,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating _read_byte_field()."""
	if not is_present(field_slot):
		return out.refuse(String(REFUSE_NO_POLICY))
	return out.succeed(column[field_slot])


# --- observable counters --------------------------------------------------------------------------

func opened_cycle_count() -> int:
	"""Cycles opened across every field since the last clear()."""
	return _opened_count


func completed_cycle_count() -> int:
	"""Cycles that closed COMPLETED across every field."""
	return _completed_count


func cancelled_cycle_count() -> int:
	"""Cycles closed by an explicit cancellation across every field."""
	return _cancelled_count


func abandoned_cycle_count() -> int:
	"""Cycles closed with every participant withdrawn. These never advance a rotation."""
	return _abandoned_count


func advance_count() -> int:
	"""Times R06-JOB-005's cursor advance ran. One per COMPLETED cycle with auto_rotation on."""
	return _advance_count


func resolved_plot_count() -> int:
	"""Participants recorded as harvested or cleared across every field."""
	return _resolved_plot_count


func withdrawn_plot_count() -> int:
	"""Participants withdrawn by an erase across every field. Never harvests."""
	return _withdrawn_plot_count


func retained_request_count() -> int:
	"""Requests retained because their legal window is still ahead."""
	return _retained_request_count


func missed_request_count() -> int:
	"""Requests retained with a missed-window warning, waiting for the next window or an edit."""
	return _missed_request_count
