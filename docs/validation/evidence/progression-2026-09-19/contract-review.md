# PC-06 contract review — independent

2026-09-19 · Reviewer: independent Claude Opus pass · PROGRESS-C4-R01.
Subject: `docs/planning/progression_execution_package.md` v1 draft.
Planning review only. No tools, tests or runtime were run. Astra owns final decisions.
The `docs/validation_resolution.md:94-109` amendment is **not yet applied**; nothing below
treats it as adopted source.

## 1. Verified correct

**Calendar fixture.** Re-derived independently. A day boundary tick is
`(D-1)*18000 - 4500`: day 133 → 2371500, day 141 → 2515500, day 144 → 2569500,
day 145 → 2587500. All four rows match. Decoding 2569500 through `sim_clock.gd`'s
`Calendar.set_tick()` gives `time = 2574000`, `day_zero = 143`, `year = 3`,
`season = 47/12 = 3` (winter), `season_day = 12`, `tick_of_day = 0` → hour 0. The award
predicate (`year>=3`, WINTER, day-in-season 12, hour 0, exact midnight tick) is decidable from
the existing clock with no new calendar code. `is_day_boundary()` agrees.

**Schema arithmetic.** `29 - 4 + 8 + 8 + 40 + 4 + 1 = 86`; `86 - 29 = 57`. Both correct.
`I64[5] = 40` correct.

**Masks.** Sparse earned bits, ascending-ID evaluation, one owner, `milestones.gd` staying
stateless, and `World.milestone_mask` as a projection all agree with R-BUILD-DOM-001
(`docs/game_gdd.md:778-817`) and `milestones.gd`'s `is_unlocked()`/`masks_agree()`. "M3 without
M1 is legal" is the ruling's own counterexample. Good.

**Restore.** Preserving a chartered save's paused state "through the clock/UI contracts" is the
right reading: `sim_clock.restore_runtime()` is the only legal path, because `set_pause(PLAYER,
true)` zeroes sub-tick debt and increments `_subtick_debt_discards`. Worth naming explicitly in
the final draft so an implementer cannot reach for the setter.

**Paused wall time adds zero ticks** is correct: `advance()` returns 0 at `SPEED_PAUSED` before
accumulating debt.

## 2. Blockers

**B1 — the collapse pause reason is unnamed, and the obvious choice is already clearable.**
The draft says collapse "raises the mandatory pause/modal" but never names a bit.
`sim_clock.gd` publishes PLAYER/MENU/CRITICAL/VICTORY/LOAD only, and
`acknowledge_without_catchup()` executes `_pause_mask &= ~CRITICAL` unconditionally. If collapse
uses CRITICAL, an overload acknowledgement silently dismisses a settlement-collapse hold, which
REQ-SET-156 requires to stand. Alternatives: (a) add a dedicated COLLAPSE bit — costs
`KNOWN_PAUSE_BITS`, `ALL_PAUSE_REASONS`, `PAUSE_REASON_NAMES`, the save mask and
`_restore_control_refusal()`, and must be declared in this packet; (b) keep CRITICAL and forbid
`acknowledge_without_catchup()` while collapse is latched; (c) hold collapse outside the pause
mask as a modal state, like the load barrier. Any is acceptable; silence is not.

**B2 — the per-tick observation contradicts ARCH-SYS-020's declared frequency.**
The draft requires "exactly one final predicate observation after lifecycle" on *every*
completed tick. `docs/systems_architecture.md:594-625` gives ARCH-SYS-020 the frequency "On
changed predicates; daily streak after lifecycle", and ARCH-TICK-003 lists progression as a
*daily* ordering stage. Evaluating mean mood, ready food-days, fuel days and per-resident warm
beds up to 256 residents at 4x for 54000 consecutive ticks is also a REQ-SET-162/163 budget risk
that this draft neither measures nor bounds. Alternatives: (a) keep per-tick observation and
amend the ARCH-SYS-020 row in the same revision, plus a declared incremental/dirty-flag
evidence rule and a budget measurement in PROGRESS-QA; (b) have each predicate owner maintain a
cheap `last_false_tick`, and let progression evaluate at midnight with the interval test
`max(last_false_tick) < T-54000` — this preserves genuine continuity without a progression pass
per tick, and shrinks `m4_true_since_tick` to a derived value; (c) restrict per-tick observation
to the winter window only. Option (b) looks cheapest and is still continuous.

**B3 — "eight named specialists" is under-defined as written.**
The draft says eight distinct living identities, and separately that the *union* of their
level-≥8 active skills must contain ≥6 IDs. Read literally, two residents covering six skills
plus six arbitrary residents satisfies both clauses. GDD's "8 named specialists with skill≥8
across≥6 skills" most plausibly means each of the eight independently holds at least one active
skill at level ≥8, and those eight between them cover ≥6 distinct skill IDs. State that
explicitly. Excluding the reserved skill is fine but should be cited to §5.11's "reserved skill
index 3 remains zero" as [DERIVED], not authored. Also name the owner of the XP→level mapping:
§5.11 gives immigrants "skill XP 5000", not a level, and the draft's refusal rule must bind to
that owner.

**B4 — no field or named owner is reserved for the cumulative counters.**
M1 needs cumulative prepared portions, M2 and M4 need mastered recipe counts, M4 needs completed
feasts. ARCH-SYS-014 writes "mastery/portion increments", but the draft's schema reserves nothing
and does not name which save section persists them. If no existing section does, PROGRESS-STATE's
86 bytes is short. Resolve before dispatch: either cite the owning section per counter, or add
the fields here and redo the arithmetic.

**B5 — the sapling grant lacks a determinism anchor.**
"The next legal deterministic storage transaction" does not say *when* the attempt occurs or in
what container order. ARCH-SYS-015 LogisticsCommit is the plausible anchor and ARCH-SYS-022
hashes the result, so an unspecified retry point is a replay-divergence risk. Name the phase, the
container selection order, and whether the attempt repeats every tick or only on a storage-dirty
signal. Also confirm the apple/pear sapling item keys exist and are container-legal; if not,
that is a named dependency, not a silent substitution.

## 3. Clarifications (not blockers)

- **Endpoint count.** Requiring truth at both `T-54000` and `T` is **54001** observations, not
  54000, and `T-54000` is the commit that *closes* winter day 8. That is defensible and stricter
  than `docs/validation_resolution.md:94-109`'s literal "throughout the preceding 54000 ticks".
  Say so, and say the amendment wording will be tightened to match, so the extra tick is not read
  later as an off-by-one bug.
- **"End winter | 145 | 2587500"** — day 145 is year 4 spring day 1. Relabel as "end of winter
  day 12 / start of year 4".
- **"12 I32 +16 I64 +1 B8"** reads as field counts to some reviewers. Write "3 I32 (12 B) + 2 I64
  (16 B) + 1 B8 (1 B) = 29 B".
- **Untagged new interpretations.** M2's "survival = noncollapsed live settlement at the
  post-lifecycle midnight starting year 2", M1's "absolute day≥4", population = living residents,
  and "authored zero heating demand satisfies fuel coverage" are all authored readings, not
  inherited. Mark them `[NEW]` per SET-AMEND-001 §1's provenance convention.
- **Charter → reputation.** §5.11's daily reputation formula contains `1000*charter_awarded`.
  The draft never mentions it. Since progression runs last in ARCH-TICK-003, the charter earned at
  T affects reputation only from the next midnight; state that ordering.
- **"The runtime must halt"** on a failed owner observation is stronger than the rest of the
  document, which refuses without mutating. Prefer: refuse the observation, record unavailability,
  raise the integrity pause; do not abort the process.
- **`last_observed_tick`** duplicates `World.tick` by the draft's own restore rule. Either keep it
  as a deliberate cross-section integrity check (say so) or drop it and save 8 bytes.
- **Zero-death window.** State that deaths committed *at* T count and block, and that "current
  winter" means winter days 1–12, not just the maintained interval.
- **`ui_availability.gd`** still gates on a highest-ordinal `>=` comparison; `milestones.gd`'s
  header requires that migration "when real Progress is bound". PROGRESS-UI-SAVE should name it.
- **M0 initialization** must set `INITIAL_MASK` directly; `milestones.award_into()` refuses an
  already-set bit and would refuse M0 on mask 1.

## 4. Tests to add

Interval start exactly at winter start; award attempt with M3 unearned (sparse M4); each of the
eight specialists failing individually; reserved-skill-only resident; charter flag reaching the
next reputation recompute; collapse latched while an overload acknowledgement is issued (B1);
restore of a saved VICTORY pause via `restore_runtime()` never touching `_subtick_debt_discards`.

## 5. Scope

The packet table and the refusal to certify M4 reachability from static fixtures are both right.
None of B1–B5 asks for gameplay to be implemented here; each is a wording, ownership or
field-reservation fix inside this draft's own scope.
