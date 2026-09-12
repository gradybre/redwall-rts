# 0110 — Tool wear settles per contributor inside the job, not once at its end

Date: 2026-09-12 · Status: **Accepted**

[SET-MOVE-ECON-001](../underground_economy_hazard_amendment.md) ECON-002 names a
gap in the shipped code rather than proposing a new feature:

> The current Gear API settles a claimed job rather than every phase contributor.
> The implementation must add coordinated contribution settlement: accepted WU,
> XP and the contributing resident's equipped-tool wear/remainder commit together
> exactly once. […] Carry the per-resident remainder across phases/cancellation,
> and stop new tool-required work when durability is exhausted. Work acceptance
> and its tool claim must be validated before mutation; failed settlement cannot
> leave one owner advanced without the other.

This record states how `godot/scripts/core/work.gd` and
`godot/scripts/core/gear.gd` now satisfy that, and — just as importantly — what
this change deliberately does **not** do.

## Context

`gear.gd` had exactly one general-wear operation, `apply_general_wear_into()`,
which debits §5.7's "1 durability per completed 10 WU" **and releases the Job's
claim**. That is the right shape for a fishing cycle, which is one claim, one
completion, one debit. It cannot express an excavation project: ECON-002 gives a
project up to four builders, one at each work face, working for hundreds of ticks
across BRACING → CUTTING → FINISHING, and the first durability point falls due
long before anyone is finished. A wear call that hands the gear back cannot be
the per-tick settlement.

`work.gd` already owned the two things a settlement needs — the frozen
per-contributor scratch that decision 0017's acceptance split fills, and the
per-resident carries for §5.2's work remainder and §5.3's fractional XP — and
owned no tool state at all.

## Decision

1. **Three wear forms in `gear.gd`, differing only in the claim.**
   `preflight_general_wear_into()` answers "could this debit happen?" and writes
   nothing; `accrue_general_wear_into()` debits and **keeps** the claim;
   `apply_general_wear_into()` debits and **releases** it, exactly as before. All
   three delegate to one `_general_wear()`, so the validation order, the refusal
   codes and the arithmetic are a single implementation. A mutation flipping the
   accruing form's release flag to `true` is killed by four tests.

2. **The settlement binding is a column in `work.gd`, taken once.** A resident's
   bound tool is `(lot slot, lot generation)` plus the `(job slot, job
   generation)` that holds the gear claim, plus a broken byte.
   `claim_tool_for_work()` takes it and `release_tool_claim()` gives it back.
   **This is a performance decision, and it is the reason a binding exists at
   all.** `gear.gd` resolves a lot reference by a bounded ascending row scan and
   says outright that gear operations happen "never inside a per-tick loop". At
   256 residents, asking it to resolve a row for every contributor on every tick
   is a few hundred comparisons per worker per tick. So the per-tick gate reads
   three packed columns of `work.gd` and nothing else, and `gear.gd` is consulted
   only on the ticks a whole durability point actually falls due — at §5.2's
   ceiling of 144 milli-WU a tick, at most once every 70 ticks per worker.

3. **The index is the attribution.** `_settle_wear()` walks the same frozen
   contributor scratch `_award_all_xp()` walks and charges `_party_share[index]`
   — that contributor's own accepted milli-WU — to the tool bound to
   `_party_resident[index]`. The aggregate durability spend is identical under
   three wrong implementations (charge the party total to one tool, settle only
   the first contributor, settle only the last), so the tests read **each tool
   and each carry separately**. The fixture is deliberately asymmetric: an 80
   milli-WU/tick builder and a 40.8 milli-WU/tick builder over 125 ticks produce
   one spent point and an empty carry for the first, and no point at all and a
   5100 carry for the second.

4. **The carry is the resident's and survives everything.** `_wear_remainder` is
   one int32 per resident and is cleared by nothing — not by a job ending, not by
   releasing a claim, not by cancellation, not by a phase boundary. Only a
   settled whole point consumes it and only `clear()` resets it. That is §5.7's
   "preserve remainder across tasks" and ECON-002's "no resetting the remainder
   at quantum, project or worker handoff boundaries".

5. **Validate, then consume (decision 0059).** `_preflight_wear()` runs before
   `consume_remaining_mwu_into()` and writes nothing anywhere; `_settle_wear()`
   runs after the XP credit. A tool whose claim has gone therefore refuses the
   whole tick with the job's outstanding work, every XP column and the gear
   store byte-identical. `_distribute_leftover()` moved ahead of the consume so
   that the shares the preflight checks are final; it writes only `work.gd`'s own
   per-tick scratch, so moving it changes no outcome.

6. **A claim keyed to another Job refuses the tick.** A worker moved to a second
   job still carrying the first job's binding does not settle the new job's work
   against the old claim — ECON-002's "job/worker replacement must not rebill old
   WU or bill only the last worker". The new job takes its own claim, and the
   carry survives the handover because releasing never touches it.

7. **A broken tool stops that contributor, not the crew.** A tool worn to 0
   during settlement sets the broken byte; the next tick refuses `TOOL_BROKEN`
   for that worker. In a party that refusal is a skip, so the remaining builders
   keep working at their own rate — decision 0017's "a departure must not stop
   the crew" applied to a worn-out tool. A solo tick surfaces `TOOL_BROKEN`
   itself rather than the generic "no contributing worker".

8. **ECON-002's variable-q tip work is priced in `work.gd`, rounding UP.**
   `tip_compact_work_mwu_into()` is `ceil(q/4)` and
   `tip_reclaim_work_mwu_into()` is `ceil(q/2)`, from
   `tip.compact_mwu_per_milli_u_num/den` and `reclaim_…_num/den` in the values
   JSON. The direction is load-bearing, not tidiness: ECON-002 says "splitting
   orders can increase rounding work, never lower it", which is true of ceiling
   division and false of flooring — under `floor()` an order split into
   single-milli pieces would be free. `q <= 0` is **refused**, never answered
   with 0, because the table prices these rows for `q>0` only and a silent 0
   would read as "no work needed".

## What this does not establish

* **No tool-gate enforcement on the productive tick.** Whether a job *requires* a
  tool is `jobs.gd`'s `_tool_gate` column. `work.gd` does not read it per tick,
  because `jobs.tool_gate_of()` allocates an `IntResult` per call and `jobs.gd`
  publishes no `_into` form; adding one is that module's owner's change. The
  consequence is exact and is stated in `work.gd`'s header and pinned by a test:
  a tool-required job whose worker holds **no** binding produces work and wears
  nothing. Everything about a binding that *exists* is enforced.
* **No fixed excavation work costs.** Brace 2000, cut 4000, finish 3000,
  remove-support 1250, backfill 3000, prepare-tip 4000 and close-tip 4000 belong
  to the construction/site owner (EH-02), not to this file. Only the two
  variable-q formulas are here.
* **No claim on any MOVE gate and no task 05.1b completion.** ECON-003's
  work-ready/commit-pending site condition, the physical phase domain, the
  `SPOIL_OUTPUT_BLOCKED` capacity reservation and the `excavated_earth` catalog
  key are all other owners' work. What `work.gd` contributes to ECON-003's
  idempotent retry is only that a further productive tick against a COMPLETE job
  is refused outright, so a forced retry cannot buy a second durability debit.
* **No performance measurement.** The per-tick cost argument above is a
  structural one — packed reads instead of a row scan — not a profile. No budget
  in REQ-SET-163 is claimed as met.

## Registry rows owed

Six new packed columns in `work.gd` at `RESIDENT_CAPACITY` = 512:
`_wear_remainder`, `_tool_lot_slot`, `_tool_lot_generation`, `_tool_job_slot`,
`_tool_job_generation` (int32, 4 B each) and `_tool_broken` (u8). That is
5 × 512 × 4 + 512 = **10752 bytes**, re-derived at runtime by
`work.settlement_payload_bytes()` so the ledger number cannot go stale.
`docs/systems_architecture.md` and `docs/persistence_state_registry.md` are not
this change's files; `state_registry_coverage.py` fails until their owner adds
the rows, and the exact rows were handed over with this change.

`_wear_remainder` is `ResidentRuntime.wear_remainder` from architecture §3, which
is marked `[NEW]` there and which **no** store implements — there is no
ResidentRuntime module and `residents.gd` has no such column. It is homed in
`work.gd` because this file is the one that knows a contributor's accepted
milli-WU, and because `gear.gd` explicitly refuses to allocate a second copy. If
a ResidentRuntime store is later built, the column **moves** there; it is not
duplicated.
