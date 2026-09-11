# 0049 — Source intent is recorded on what it produced, and ARCH-SYS-023 is where a float becomes legal
Date: 2026-09-10 · Status: **Accepted** ·
Closes: bullets 3, 4 and 5 of `docs/tasks/04_world_commands.md` §04.4 ·
Depends on decisions [0039](0039-job-planner-pending-service-identity.md),
[0041](0041-forage-demand-is-a-standing-policy-on-a-designation.md),
[0042](0042-the-command-queue-orders-by-an-unsigned-key.md),
[0043](0043-command-dispatch-commits-per-kind-schemas.md),
[0046](0046-ecology-runs-one-leg-of-the-daily-boundary.md),
[0047](0047-cropweather-has-two-cadences.md),
[0048](0048-world-generation-anchors-and-what-it-refuses-to-invent.md)

## Decision

`settlement_system.gd` calls `command_dispatch.bind_ecology()` during composition and
dispatches **nine** `systems_architecture.md` §5 stages, adding ARCH-SYS-009 JobPlanner
and ARCH-SYS-023 PresentationExtract to the seven it already ran. A player's
`DESIGNATE_ZONE` therefore reaches `forage.gd` and `job_planner.gd` **in the running
game** instead of refusing `COMMAND_STORE_NOT_BOUND`, and the next planner tick
publishes a QUEUED FORAGE job against generated stock.

Four things were decided on the way there, and each could be undone by accident.

## 1. The producer's idempotence was not the identity 04.4 asked for, and that was measured

04.4 bullet 3 asks to "record source intent/job identity so repeated evaluation cannot
duplicate a job". `job_planner.gd` already makes **repeated evaluation** idempotent:
demand identity is `(designation EntityRef, patch kind)`, a repeat `enable_forage_demand()`
refuses, `mark_zone_dirty()` sets a membership bit before pushing, and midnight reconciles
rather than reopens. Those guards were re-tested here and they hold.

They are the **producer's** guards and they are per designation. They cannot see that two
designations came from one player command, and two designations did.

**The defect was reproduced before it was fixed**, on 2026-09-10, through the real modules:

* `commands.gd` refuses a duplicate `(execute_tick, player_id, sequence)` key only while the
  record is still **queued** (`_has_key` walks live rows), and refuses a stamped record whose
  `execute_tick` has already completed.
* Neither catches the same envelope re-admitted through `admit_stamped_into()` at a **later**
  tick. Doing that after a committed `DESIGNATE_ZONE` committed a **second** designation over
  the same basin: `forage.zone_count()` went 8 → 9 and
  `job_planner.forage_demand_enabled_count()` went 1 → 2, for one player intent.
* **The job count did not move**, and that is the point. The first harvest's claim still held
  the shared daily quota, so the second demand found nothing to claim. The accounting was
  saving the identity, not the identity holding. A freed quota — a cancelled claim, a
  midnight, a completed harvest — turns the second demand into a second job.

A test that watched only `jobs.job_count()` would have passed against the defect. The tests
written here watch `forage.zone_count()`, `source_intent_count()` **and**
`forage_demand_enabled_count()`.

## 2. The identity is the command's, recorded on the entity it produced

`command_dispatch.gd` gains a **source-intent ledger**: one row per `forage.gd` HarvestZone
row, holding ARCH-CMD-001's own `(player_id, sequence_high, sequence_low)` plus the
**generation** of the zone that command created. `DESIGNATE_ZONE`'s preflight looks the
identity up before anything is created and refuses `COMMAND_DUPLICATE_INTENT`.

Three alternatives were rejected, each for a stated reason:

* **Deduplicate by CONTENT** (same basin, same tiles, same band). Rejected because it
  contradicts the owning store: `forage.gd`'s `add_tile()` says in terms that "a tile covered
  by ANOTHER zone is accepted: §5.1's overlapping designations are the case the per-tile list
  exists for". Two commands the player really issued twice are two intents.
* **A monotonic sequence watermark** — refuse any command whose sequence is at or below the
  highest already committed. O(1) and no storage, but it is an **ordering** test on an
  identity, and `commands.gd`'s `restore_sequence()` plus `admit_stamped_into()`'s
  "arrival order need not be key order" make a legitimate lower-sequenced command reachable
  on the load path. It would refuse real player intent. Two tests now pin this: a different
  intent with a **lower** low word, and one with a **lower high word and an equal low word**,
  must both commit. Both were written after mutation testing found the `<`-for-`!=`
  substitutions surviving.
* **A ring over command history.** Rejected because a window silently forgets. Indexing the
  ledger **by the zone row it describes** bounds it at §4.2's own 128 designations and makes
  forgetting impossible while the designation is alive. An intent whose designation was
  destroyed is correctly no longer a duplicate: there is no second job for it to duplicate.

**It does not persist.** There is no save module; task 09 owns the codec. Across a process the
guard is untested and unclaimed, exactly as the result ledger is.

Adding `COMMAND_DUPLICATE_INTENT` to `RESULT_CODES` renumbers every id above it, because the
**index is the stored id**. That is the domain's own documented behaviour (the sort is an
assertion, not a comment), the domain is in-process only today, and no test hard-codes a
numeric id.

## 3. ARCH-SYS-023 is the float boundary, and read-only is structural

`scripts/core/presentation_extract.gd` captures **fourteen committed integers** once per tick,
keeps the last **two** frames, and interpolates between them at an integer alpha in 0..1000
thousandths of a tick. `FloatRead` is the only type in `scripts/core/` that carries a `float`,
and nothing in the simulation reads one back. Read-only is enforced by construction, not by
convention:

* no accessor returns a store, a column or any reference to what was read;
* every read fills a record the **caller** owns, and mutating that record changes nothing;
* the only mutators are `capture()`, which copies *from* the simulation, and
  `set_layer_visible()`, which touches one visibility byte;
* hiding a layer makes its fields **refuse** `PRESENTATION_LAYER_HIDDEN`. It does not zero the
  column, does not stop the next capture recording the real value, and cannot reach the store.
  Unhiding shows the same number. A test hides all six layers over a generated world with a
  live designation and asserts the basin stock, the zone count, the job queue and the living
  population by value afterwards.

`capture()` **latches its tick** and refuses a repeat, for the reason `ecology.gd` latches its
day: a second capture of one tick rolls a genuine previous frame out of the buffer and makes
the renderer interpolate from a frame to itself. A presentation layer that calls `capture()`
therefore cannot disturb the baseline either.

An **unbound source refuses rather than reading 0**: a settlement with no planner has no
standing-demand count, and 0 would be indistinguishable from a settlement that has one and no
demand.

Fourteen fields is what exists. There are **no dirty pages and no render buffer**, because
ARCH-SYS-001 has no Transform store: nothing spatial exists to page or to interpolate.

## 4. The stage list is a count of dispatched call sites, and two stages are out of order

The header now says **nine** dispatched stages and names them. It has carried a wrong count
twice before, so the count is of call sites, the list *is* the count, and
`tick_stage_count()` publishes the seven that are on the per-tick path so the comment and the
code cannot drift silently. Two ordering facts are stated rather than glossed:

* **ARCH-SYS-009 runs before ARCH-SYS-008**, not after it. The table reads 008, 009, 010; this
  node runs 009 and then a fused 008/010 pass in which each resident's activity is resolved
  immediately before that resident is offered a job. The fusion is what stops eligibility step
  2 reading a stale hour, and the two stages share no data. What the table order is *for* —
  R06-JOB-008's "reconcile its demand before selection" — is satisfied exactly.
* **ARCH-SYS-017 CareHealth runs in ARCH-SYS-003's slot, fourteen places early.** This is an
  ordering **debt**, now stated in full instead of implied. `needs.gd` integrates health, cold
  exposure and the incapacitation/death transitions inside `tick_all()`. The table's own
  constraint ("before lifecycle and progression") still holds, because neither ARCH-SYS-019 nor
  ARCH-SYS-020 exists. What is lost is everything between the two positions: cold exposure
  cannot see **this** tick's ARCH-SYS-016 RoomHeat result and injury care cannot see **this**
  tick's care work. Both inputs are absent today, so the debt is currently unobservable — and
  becomes a real one-tick lag the moment either store lands. Repaying it means a separate
  CareHealth call, which is a change to `needs.gd`.

ARCH-SYS-009's **midnight** is dispatched too, after the crop/weather leg, and is deliberately
**not** logged as a REQ-SET-007 leg: the requirement names five legs and job planning is not
among them. `planner_day_count()` counts it, because with no FarmPlot and no designation it has
no visible effect of its own and "it ran" would otherwise be indistinguishable from "it was
skipped".

Per-stage measurement was added because `PerfTimer` made it two `Time.get_ticks_usec()` calls
per stage. `tick_stage_usec_at()` and `mean_tick_stage_usec()` publish microseconds and
`tick_stage_measured_count()` publishes how many times each window was closed.
**No budget is asserted and no qualification is claimed**: REQ-SET-163's figures are for 256
residents on a named machine this has not been run on. The measurement count exists because the
microsecond figures cannot catch a stage that stopped being dispatched — an unclosed window
simply keeps its previous non-negative value.

## Memory

`docs/systems_architecture.md` §2.3 gains two rows and ARCH-MEM-009 one step, **+2292 bytes**:

| Item | Arithmetic | Bytes |
|---|---|---:|
| Source-intent ledger | 128 HarvestZone rows x 4 i32 | 2048 |
| ARCH-SYS-023 snapshot | 14 fields x 8 bytes x 2 frames + 14 + 6 flag bytes | 244 |

Carried ledger total 59816882 → **59819174**; with the same 8388608 reserve, **68207782**,
which is 31792218 below the decimal 100 MB gate. Both §2.3 allocations add **no §2.2 field
row**, exactly as decisions 0042 and 0043 did. `settlement_system.gd`'s per-stage columns
(3 x 7 i64 = 168 bytes) sit inside the existing "Timing samples" diagnostic row.

**All fifteen ARCH-MEM-009 rows were re-added individually**, not spot-checked: every running
total is the row above plus its own delta and every reserve cell is its payload plus 8388608.
The printed §2.3 row sum moved 60254514 → 60256806, so ARCH-MEM-010's gap is **still exactly
437632** — both halves moved by the same +2292 and the gap absorbed nothing new.

**Found while doing it:** the prose reconciliation paragraph at the end of §2.4 still carried
decision 0043's figures (59656914 / 68045522 / 121486852) and had never been advanced for
decisions 0044, 0045 or 0048 — understating the ledger by 250080 bytes. It is **annotated with
the current figures rather than rewritten**, because it is a dated record of when each
reconciliation happened and both of its conclusions are unchanged on either basis.

## What this refuses to invent

* **`world_init.gd` IS NOT COMPOSED into `settlement_system.gd`**, and the acceptance test
  generates through the accessors that file publishes for exactly this purpose. Its scenario
  `Request` needs tree, stone, iron, forage and fish **item ids that no document assigns**, and
  the New Settlement control that would supply them is 04.4's UI half, which is out of scope
  and not built. Composing it would mean inventing either the ids or the caller.
* **The UI shell** — camera, selection, zone tool, pending preview, accessible refusal display,
  registry profiles, input rectangles, Mac trackpad alternatives and screenshots — is not
  built, not stubbed and not claimed. 04.4's own acceptance asks for Mac screenshots and a
  command/state trace; this increment delivers the headless half of that sentence and says so.
* **No delivered output.** Nothing writes `JOB_STATE_WORK`. A published harvest reaches QUEUED
  and, if a resident is free, RESERVED. Its inputs gate is `GATE_UNAVAILABLE` because
  REQ-SET-069's output-capacity contract has no store, so it refuses at selection anyway.
* **No save round trip.** The intent ledger, the result ledger and the pending queue are
  in-process only. Task 09 owns the codec.
* **The 12-resident fixture** remains blocked on task 06's Building/Container/gear contracts.
