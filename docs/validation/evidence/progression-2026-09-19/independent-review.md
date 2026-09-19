# PROGRESS-INTERVAL — independent code and contract review

2026-09-19 · Independent reviewer (not the author) · PROGRESS-C4-R01 v2.
Subjects: `godot/scripts/core/progression_interval.gd`,
`godot/test/test_progression_interval.gd`,
`docs/rulings/2026-09-19_progression_interval.md` (v2),
`docs/planning/progression_execution_package.md` (v2),
`docs/validation/evidence/progression-2026-09-19/review-disposition.md`,
and the `work_queue.json` / `starter_settlement.md` follow-up edits.

**I executed nothing.** No Godot run, no test, no graph validator, no git command. Every
statement below is derived by reading the supplied sources. The supervised suite is reported
as still running; **no pass is claimed here, and runtime behaviour of this helper is
unproven.** Acceptance below is for a stateless helper's *math and contract*, not for
integrated progression, M4 reachability, first playable or release.

## 1. Verdict

**Bounded accept. No blocking regression found.** Four non-blocking findings (§4) and two
unverifiable contract claims (§5) are recorded.

## 2. Independently re-derived arithmetic

All of this was recomputed from GDD §5.1 / `sim_clock.gd` constants, not read off the module.

- `day_index_at(2569500) = 2574000/18000 = 143`; `year = 143/48 + 1 = 3`;
  `season = (143 % 48 = 47)/12 = 3` (winter); `season_day = 47 % 12 + 1 = 12`;
  `tick_of_day = 2574000 % 18000 = 0`. The award instant is where the ruling puts it.
- `T-54000 = 2515500` -> day 140 -> winter day 9, midnight. Winter of year 3 is day indices
  132..143, i.e. ticks 2371500..2587499; 2587500 is spring, year 4. The test's literals for
  `WINTER3_START`, `WINTER3_END`, `YEAR2_T = 1705500` (day 95, year 2, winter day 12) and
  `YEAR5_T = 4297500` (day 239, year 5, winter day 12) are each correct, as are their
  `-54000` partners (days 92 and 236, both winter day 9).
- `MAX_OBSERVABLE_TICK = INT64_MAX - 4500 = 9223372036854771307`, matching the test's
  hand-written literal and `sim_clock.RESTORE_COMPLETED_TICK_MAX`. Reusing the clock's own
  ceiling rather than inventing one is correct.
- `_same_season_block` is sound, and its stated reason is the real reason: `DAYS_PER_YEAR`
  (48) is an exact multiple of `DAYS_PER_SEASON` (12), so `day_index / 12` numbers season
  occurrences consecutively from the epoch. Year-3 winter is block 11, year-2 winter block 7,
  so "same winter of the same year" is exactly block equality. Division only; nothing here
  can overflow.

## 3. Safety of the two hazards I was asked to inspect

**`last + 1` ceiling.** Ordering is checked only after *both* ticks are proven in domain:
`is_tick_in_domain(tick)`, then the `last == -1` fresh branch, then
`is_tick_in_domain(last_observed_tick)`, and only then `tick != last_observed_tick + 1`. With
`last <= INT64_MAX - 4500`, `last + 1` cannot overflow. At the ceiling the comparison is
vacuously unsatisfiable (`tick` cannot exceed `MAX`), so the last observable tick refuses to
advance rather than wrapping — fail-closed, and the 4500-unit headroom claim in the comment is
accurate. Every calendar entry point (`is_award_instant`, `_is_winter`, `_same_season_block`,
`_tick_of_day`) is reached only for domain-valid ticks; `is_award_instant` gates itself first,
so `tick + 4500` is at most `INT64_MAX` exactly and never past it.

**Invalid-tuple safety.** Both methods refuse corrupt history instead of repairing it or
reporting it as merely ineligible, as the ruling requires.

- `advance`: a set prior since must satisfy `0 <= since <= last` **and** `last` must itself be
  in winter **and** in the same season block. The `last`-not-winter case is the right extra
  rule: a streak that claims to have survived a season change is corrupt, not shortened.
  `-2`, a future since, a previous-winter since, a duplicate, a skip, a reversal, a negative
  tick, and a fresh `(tick != 0)` or fresh-with-since tuple all refuse.
- `award`: `last == tick` is required, so "the final observation happened" is enforced rather
  than assumed. Outside winter a live since refuses; inside winter, true predicates without a
  since and false predicates with one both refuse. `since <= tick` holds before the
  subtraction, so `tick - since` cannot overflow. The `already_awarded` / false-predicate /
  not-award-instant / short-interval paths all *succeed with 0*, which is the correct
  distinction: those are legitimate questions with a negative answer, not faults.
- The year gate is re-derived inside the helper (`is_award_instant` checks year >= 3
  independently of `all_predicates_true`), so a caller cannot bypass the temporal condition.
  The residual `true_since_tick == UNSET_SINCE` guard in `award_eligible_into` is already
  implied by validation; harmless, and I would keep it as defence in depth.

**Purity and allocation.** Both entry points are `static`, take a caller-owned
`IntMath.IntResult`, and mutate only it. GDScript ints are by value, so no caller scalar is
touched. No arrays, dictionaries, `Calendar` objects or catalog registrations are created;
`SimClock.day_index_at` is a static integer expression. Replacing the author's formatted
diagnostic strings with fixed literals removes the per-refusal string construction and is the
right call for a hot path; refusals still follow `IntResult` semantics exactly
(`ok=false, value=0, error` nonempty).

## 4. Non-blocking findings

1. **No test asserts *which* refusal code was produced.** `_assert_refused` checks only
   `error != ""`. Swapping, say, `PROGRESS_FUTURE_SINCE` for `PROGRESS_INVALID_SINCE`, or
   returning the same code everywhere, would pass the whole file. Since the codes are now
   static and stable, pin at least the distinct families.
2. **The codes are string literals, not exported constants.** `sim_clock.gd` publishes its
   `REFUSE_*` codes so a caller can branch without re-typing text. `IntResult.error` is a
   `String`, so `StringName` is unavailable, but `const REFUSE_* : String` would let
   PROGRESS-FACTS match refusals without literal duplication.
3. **One comment overstates its own test.** In `test_pause_is_represented_by_no_invocation`
   the body advances to `T-1`, then asks `award_eligible_into(T, T, ...)` without folding an
   observation at `T`; the closing message "a paused window still awards, because no tick was
   skipped" describes tuple validity, not an observed window. (The genuinely contiguous case
   is covered by the 54001-observation test.) Reword, or add the `T` observation. The same
   test also passes `_out.value` as an argument to a call whose out-parameter is `_out`; that
   is safe because the int is copied at call time, but it is a pattern worth not teaching.
4. **Mid-life migration entry is unstated.** The only fresh observation is tick 0, which is
   correct for a new world; a world that gains this owner at tick > 0 must be migrated with
   `last = World.tick - 1, since = -1`, never `last = -1` (which refuses,
   `PROGRESS_FRESH_TICK_NOT_ZERO` — a good fail-closed refusal). PC-06 already forbids
   reconstructing an interval; say this positively where the migration is specified.

I could not verify the assertion helpers (`before_each`, `assert_equal/true/false`) because
`test/framework/test_case.gd` was not in the packet; I assume the repository's existing
convention. The 54001-iteration loop is pure integer work and should be cheap, but its cost is
unmeasured here.

## 5. Contract follow-through

**Test-name honesty: passes.** Every subject the ruling enumerates exists as a real test —
contiguous 54001-observation pass, one-tick-late start, single false between midnights, false
at `T`, initialization and strict ordering, season exit reset, winter-start since, malformed /
future / prior-winter sentinels, year 2, later year, `T-1`/`T`/`T+1`, already-awarded,
restore-equivalent scalar handoff, pause-as-no-invocation, and the domain ceiling — plus a
fixture test that re-derives the calendar through the real `SimClock`. Nothing is named that
is not implemented, and nothing is implemented that contradicts its name except §4.3.

**B1–B5 disposition: properly handled as future-owner contracts, not as readiness.** B1 is a
planned `COLLAPSE=32` with clock/scheduler/producer/restore changes required *together*, and
PC-06 states plainly that no current clock code or save schema changes. B2 becomes a per-tick
cheap final observation with complete dirty invalidation and rebuilt caches, with performance
held explicitly as measured acceptance (PROGRESS-QA) rather than an achieved bound. B3 now
reads each of eight distinct living residents as individually >= 8, union >= 6, with Residents
owning XP->level. B4 moves the existing `prepared_portions` allocation to a named future
counter owner in §6 instead of inventing bytes in Progress, and the disposition is candid that
the earlier reviewer lacked those architecture rows. B5 anchors the gift in ARCH-SYS-015 with
fixed item/container order, preflight-then-commit, and PROV-R01 ORDINARY with no new
provenance member. Schema arithmetic re-checked: `29 - 4 + 8 + 8 + 40 + 4 + 1 + 1 = 87`,
`+58`; the earlier 86/57 differed only by the added collapse latch. All of it is correctly
labelled *planned*: no active ledger, registry, save schema or pause-bit change is claimed,
and no full runtime-budget or schema readiness is asserted anywhere I can find.

**Two claims I cannot verify from this packet — resolve before PROGRESS-FACTS dispatch.**
(a) PC-06 says "ARCH-SYS-020 is amended to a cheap final observation each completed tick", but
`docs/systems_architecture.md` is not in the packet, so I cannot confirm the row itself (and
ARCH-TICK-003's daily stage) was edited in the same revision — which was B2's own condition.
If only the planning document was changed, the architecture source still reads "On changed
predicates; daily streak after lifecycle" and the two disagree. (b) The ruling requires
registering this module as category 3 with no save fields; no registry or memory-ledger file
was supplied, so that registration is unverified here.

**Graph edits.** `INIT-E -> SAVE-CAPTURE` and the concrete codec/continuation prerequisites on
`SAVE-ORCHESTRATOR` are present, and `SAVE-CAPTURE` depends on `SAVE-ORCHESTRATOR` rather than
the reverse, so those edges introduce no cycle by inspection. `ARCH-MEM-006` is spelled
consistently in both the starter package and the disposition. I did not run the validator and
do not confirm "70 tasks, 0 problems". One latent hazard: `SAVE-CAPTURE` and
`SAVE-ORCHESTRATOR` both *own* `save_file.gd` and `test_save_round_trip.gd`; the dispatcher's
in-flight rule tolerates this, but two owners of one file should be narrowed before either is
dispatched. `PROGRESS-INTERVAL` and `PLAN-PC06-PROGRESSION` both remain `in_flight`, which is
consistent with claiming no downstream readiness.

## 6. Scope

Nothing above asks for the progression owner, schema, reward, UI, a new owner, or the full game
in this PR. §4 is four wording/coverage fixes inside the helper's own files; §5's two open
items are documentation consistency checks owed before the next packet dispatches, not work
for this one.
