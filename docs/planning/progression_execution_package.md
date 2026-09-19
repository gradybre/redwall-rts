# PC-06 — progression execution package

2026-09-19 · Version 2 after independent review; timing adopted below, runtime owners still gated · PROGRESS-C4-R01.
Authority: GDD §5.11, R-BUILD-DOM-001, ARCH-TICK-002, UI §3.
This is an authored resolution of the timing ambiguity, not measured M4 reachability.

## Continuous winter condition

Retain all GDD thresholds and the existing award instant: midnight starting winter
day 12, after that tick's needs, injury, death and departure commits. At that instant
T, every M4 predicate must be true in every committed state from T−54000 through T,
including both endpoints. Those 54000 intervals cover winter days 9, 10 and 11.
This deliberately defines 54001 committed observations covering 54000 complete intervals. The older proposal did not disambiguate its endpoints; this revision does. The start endpoint matters: becoming true at T−53999 is one tick too late.
Midnight samples alone cannot establish the interval. Paused wall time adds zero ticks.

Every completed tick has exactly one final predicate observation after lifecycle.
A false predicate clears the saved true-since sentinel to −1; a transition to true
records that completed tick; continued true retains the original tick. Leaving
winter clears it. Only complete, contiguous observations qualify. Initialization
at tick 0 establishes an observation without granting elapsed time. Restore resumes
from the saved last-observed tick; duplicate, reversed or skipped observations are
integration errors, not extra elapsed evidence. They refuse without modifying state.
A missing/unavailable prerequisite is not true and cannot count toward an interval.
A failed owner observation records its exact unavailable reason and requests an integrity pause; it does not abort the process or substitute a true predicate. A normal false predicate simply resets the interval.

An award requires year≥3, season WINTER, day-in-season=12, hour=0 and the exact
midnight tick; current predicates true; true-since≥the current winter start;
T−true-since≥54000; M4 not previously awarded. A charter already awarded remains
awarded even if later predicates fail. It never replays rewards or its completion
screen merely because a save loads or a later winter arrives.

Year-3 fixture, using the existing 4500-tick calendar offset:

| Boundary | Absolute day | Completed tick |
|---|---:|---:|
| Start winter | 133 | 2371500 |
| Start winter day 9 | 141 | 2515500 |
| Start winter day 12 / award | 144 | 2569500 |
| End winter day 12 / start year 4 | 145 | 2587500 |

## One owner and exact meanings

Progression owns earned bits, award ticks, gift state and the continuous interval.
`milestones.gd` remains a stateless bit-domain helper. World.milestone_mask is an
atomically updated projection of Progress.unlocked_mask, not a second authority.
Each eligible milestone is considered independently in ascending ID order. M3
without M1 is legal; a highest ordinal never substitutes for an earned bit.
M0 is initialized exactly once by assigning INITIAL_MASK=1 at successful world publication; do not award M0 onto an already initialized mask.

The following disambiguations are [NEW authored readings], preserving the numeric thresholds. M1 uses absolute day≥4, living≥12, cumulative completed prepared portions≥200.
Prepared meal/ration portions (BAL-CONFLICT-010, excluding raw/preserved ingredient production) come only from committed production completion, once per job completion;
imported stock, failed work, loading or transferring meals cannot earn portions.
M2 uses living≥48, survival through the end of the first winter and ≥3 mastered
recipes. Survival means a noncollapsed live settlement at the post-lifecycle
midnight starting year 2; no zero-death requirement is added to M2.
M3 uses living≥80, year≥2 and current ready food-days≥8 against current demand.
M4 keeps all table predicates, including winter demand for its 18-day stocks.
All living stages count toward population and warm beds and use their actual
stage-specific demand. Missing PC-04 values prevent certification, never adult fallback.

Eight named specialists means eight distinct living resident identities. Each specialist must individually have at least one active skill at level≥8, read through `Residents.skill_level_into` (the resident owner owns XP→level). The
union of active skills with level≥8 among those residents must contain at least
six skill IDs; reserved hunter skill is excluded. A UI name change neither creates
a specialist nor adds a second identity. Dead/departed residents do not qualify.
Mastery counts distinct mastered recipe IDs. Feasts count committed successful
feasts once. Mood is the existing integer mean over living residents. Every living
resident needs a valid, reachable, assigned warm bed; floor sleep is not a bed.
Current-winter starvation/exposure deaths are checked from lifecycle history across winter days 1–12, including deaths committed at award tick T; the window is not restricted to the three-day maintained interval.
Changing a resident name, accepting arrivals or changing year cannot erase them.
Fuel qualification requires a computed winter heating demand; an unavailable
heating owner is not zero. Authored zero heating demand satisfies fuel coverage
without an infinite number being presented. Food and fuel reservations are excluded
by their owning availability rules. No future harvest or unmade meal counts ready.

M3's two apple and two pear saplings are a one-time reward. The award atomically
sets an outstanding-gift bit. Starting at the next tick, ARCH-SYS-015 LogisticsCommit attempts it once each tick after ordinary already-reserved transfers, in ascending pending milestone ID. It
places all four actual units or leaves the bit outstanding. Use catalog keys `sapling_apple` and `sapling_pear` (present in item_definitions.json), 2000 milli-U each, PLAIN quality, the existing protected ORDINARY provenance (PROV-R01: this gift is explicitly an ordinary source with no provenance privilege), no recipe, age0. Do not add or renumber a provenance member; the Progress award/gift latch records its one-time origin. Visit item IDs ascending and eligible reachable containers by `(slot,generation)` ascending; use actual mass, filters and free unreserved capacity. Preflight every placement and journal cell before committing all lots plus gift-bit retirement. Do not retry elsewhere in the tick. Receipt is idempotent,
uses the shared Inventory and legal containers, never an unlimited buffer, and
clears the bit in the same commit as the goods. Full storage does not revoke the
unlock or discard the gift. The UI shows the outstanding grant and its exact
refusal. No player action can create another outstanding grant for this award.

## Planned persistence and memory

The current Progress allocation is 3 I32 (12 B) +2 I64 (16 B) +1 B8 (1 B) =29 packed bytes.
The implementation packet must explicitly replace its unused victory_streak_days
I32 with derived presentation, not maintain daily samples as authority. Proposed
new persistent fields: m4_true_since_tick I64 (8), last_observed_tick I64 (8),
award_tick I64[5] (40), pending_gift_mask I32 (4), first_winter_survived B8 (1), collapsed B8 (1).
Result: 29−4+8+8+40+4+1+1 = 87 packed bytes, +58 bytes before allocator overhead.
All sentinel ticks are −1 when unset; M0 award tick is the publication tick.
Only bit3 may be set in pending_gift_mask, and it requires earned M3. The first
winter latch is monotonic within a world and clears on New Settlement. The saved last-observed tick is a deliberate cross-section integrity check against World.tick, not an independent clock. The collapsed latch sets once only after publication and a lifecycle commit leaves no living resident; an uninitialized empty store is not collapsed.

Counter ownership is explicit. The future `core/production_counters.gd` owns the
already-budgeted WorldRuntime.prepared_portions I32 and MasteryCounter.good_batches /
total_portions I32[64] each (architecture lines currently 448/450). Move the former's
existing four-byte allocation from WorldRuntime into that owner's ledger row;
no duplicate allocation or insertion into the frozen 80-byte WORLD runtime body.
Serialize all three counter columns in §6 AUXILIARY_STATE's production-counters
owner block. Counter overflow refuses the whole production completion, never wraps.
The production completion identity prevents double credit. Progress owns its existing
mastered_recipe_mask I64 and feasts_completed I32 in §4 COMPONENT_COLUMNS, with
producer commits updating these once alongside their own completion latches.
The identity/history owners supply the winter death count; they must publish its
exact persisted cause/day fields before PROGRESS-FACTS dispatch. No new history
counter or truncated-history derivation is hidden inside the 87-byte Progress row.

These are planned fields, not an active ledger/registry/schema change. The runtime
owner must update the ledger chain, canonical registry, source capacities, save
section schema/version and compiled table together before dispatch. No current
save gains an undeclared field. Restore rejects future/negative-invalid ticks,
mask disagreements, nonmonotonic award facts, a pending gift without M3, impossible
true-since outside winter, and last_observed_tick differing from World.tick.
It validates into prepared caller-owned columns before mutating live state.
A new world initializes the helper at tick0. Mid-life introduction requires an explicit versioned baseline at the current committed tick, with no credit for prior time; do not call the fresh tick0 sentinel path at a later tick. This helper does not define or activate that migration. Old schemas require an explicit migration; reconstructing an interval from daily
samples or current stock is forbidden.

## Tick order, completion and collapse

After lifecycle, first determine collapse. A committed living count of zero latches
collapse, forbids progression rewards at that boundary and raises a dedicated
COLLAPSE=32 pause bit/modal [NEW internal reason]. Only successful world replacement
or validated restore may clear that bit; ordinary Resume, Continue, menu close,
overload acknowledgement and critical-autopause settings cannot. The future clock/
scheduler packet must extend known-bit validation, reason names, authorized
producers, save schema compatibility and refusal tests together. No change is
made to current clock code or active save schema by this document. No daily autosave, prewinter save or rotating-slot replacement may
commit for that collapsed state. A disk job already prepared for a prior valid
boundary may complete only under the save orchestrator's recorded-boundary policy;
it cannot read the now-collapsed mutable world. Preserve all existing files.

ARCH-SYS-020 is amended to a cheap final observation each completed tick; the
daily crossing still follows ARCH-TICK-003. Gather expensive owner aggregates only
when their inputs change, with complete invalidation from every participating
mutation (inventory/reservations/expiry; population, names and skills; mood;
beds/reachability/heat; production/feasts/deaths; calendar). Rebuild derived caches
before the observation on restore. Cache absence is unavailable, not assumed true.
Do not scan every lot/resident on every tick merely to maintain elapsed time.
PROGRESS-QA measures 256 residents at 1×/4× against the existing simulation/UI
budgets; these are acceptance limits, not a claimed achieved performance result.

Otherwise observe the interval once, evaluate eligible awards in ascending ID,
commit mask/award tick/gift intent together, then publish UI intents. M4 adds the
VICTORY pause reason; Continue removes only VICTORY and preserves PLAYER/MENU/LOAD
or integrity pauses and requested speed. The charter flag and award tick remain.
Warden death alone does not collapse; the existing adult appointment rule applies.
Loading a chartered save preserves its paused state through the clock/UI contracts
through `SimClock.restore_runtime()` and never manufactures a new award event or setter-induced debt discard. The daily reputation stage precedes progression, so a charter earned at T contributes its existing +1000 term starting with the next daily recomputation, not a second same-tick pass. A successful New Settlement clears all
old progression only as part of the shared publication transaction.

## Bounded implementation packets

| Packet | Files / responsibility | Dependencies |
|---|---|---|
| PROGRESS-INTERVAL | New stateless `core/progression_interval.gd` and focused tests; exact integer transition and eligibility math, caller-owned result, no new mutable owner | Reviewed timing contract |
| PROGRESS-STATE | `core/progression.gd`, packed columns, clear/capture/restore, memory ledger and registry/schema in one owned packet; reserve clock/scheduler/save reason changes for COLLAPSE | Reviewed field schema; save owner interface |
| PROGRESS-FACTS | Gather typed committed predicates from existing producers with explicit unavailable refusal; per-tick final observation; awards and masks | INIT-E, production/mastery/feast/care/PC-04/heating/history owners |
| PROGRESS-REWARD | Exact legal sapling placement and atomic grant retirement | Shared inventory and storage contacts; PROGRESS-STATE |
| PROGRESS-UI-SAVE | Objectives, earned-bit migration of `ui_availability.gd`, grant refusal, victory/continue/collapse; protected disk writes and replay | PROGRESS-FACTS/REWARD, full save orchestrator |
| PROGRESS-QA | Real year3 and later-year fixtures, adversarial ticks, restart/collapse disk proof | All above; independent reviewer and one heavy job |

PROGRESS-INTERVAL may be tested independently but does not award M4 in production.
No other packet becomes ready solely because this table exists; their exact owner
APIs and schema reservations must be attached before dispatch.

## Required acceptance

Boundary tests include T−54000 pass, T−53999 fail, a single false observation
between midnights, false at T, true only at T, missing/duplicate/backward observations,
season exit/reentry, year2 refusal, exact day12 midnight versus one tick before/after,
and later-year eligibility. Test restore at T−1 and during the interval produces
the identical next states as uninterrupted execution. Restore an invalid interval
without changing live columns. Pause and 1×/2×/4× must produce the same tick history.

Test sparse masks, exactly-once portion/feast/mastery producers, eight identities
with six skills and counterexamples, one unheated/missing bed, reservation reducing
stock below threshold, death at the award tick, zero-heat versus missing-heat owners,
full reward storage followed by capacity release, repeat load before/after gift
commit, and same-tick collapse versus award. Disk fault injection proves no
collapsed-state autosave replaces the prior valid file. Actual integrated strategy
traces remain required to establish M4 reachability; static fixtures cannot do so.

Review follow-through tests also cover each specialist failing individually,
reserved-skill-only residents, sparse M4, interval starting at winter start,
charter-to-next-day reputation, COLLAPSE surviving overload acknowledgement,
and saved VICTORY restore without a sub-tick debt discard.
