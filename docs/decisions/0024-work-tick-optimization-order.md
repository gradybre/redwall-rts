# 0024 — Work-tick optimisation order and workload references
Date: 2026-09-08 · Status: **Accepted** (Astra, 2026-09-08)

## Execution order
1. Establish the **three-workload baseline**
2. **Lazy persistent IDs**
3. Measure
4. **`TickResult` `_into`**
5. Measure
6. **Release-build setup**
7. Evaluate the **fused reader**

Decision 0016 stays open. Persistent caching and native-code migration remain
undecided.

## Correction carried forward
The earlier **64%** and the current **~16%** describe **different operations,
before and after the reader refactor. They are not directly comparable.** The new
evidence shows only that the three remaining suspects do not dominate the
remaining tick. Do not restate them as a like-for-like reduction.

Treat **232 µs as an isolated probe result, not promised savings.**

## 1. Persistent IDs — remove the routine read
IDs are collected for every contributor but used only to break equal fractional
remainders.

- Ordinary ticks perform **zero** identity reads for work allocation.
- A finishing tick with **no leftover** milli-WU also requires none.
- When leftover allocation needs identities, fetch each participating identity
  **at most once** into existing scratch storage.
- **Freeze contributor membership** through allocation and commit.
- **Resolve identity-read failures before committing shared progress or XP**,
  unless the enclosing transaction guarantees rollback.

**The hazard, stated explicitly:** `_commit()` currently consumes remaining work
*before* `_allocate_shares()`. Moving a potentially failing read into
`_distribute_leftover()` would introduce a failure **after progress was already
consumed**.

Test: tied fractions; reordered member storage; save/load before completion; a
departure scheduled on the completion tick. Preserve the established lifecycle
order.

## 2. `TickResult` — additive `_into`, published API preserved
```
tick_solo_into(job_slot, caller_owned_result)
tick_party_into(coordinator_slot, caller_owned_result)
```
`tick_solo()` and `tick_party()` remain as allocating convenience wrappers over
the same implementation. Simulation callers move to `_into`.

**Every call must overwrite every result field, including refusals**, so a prior
successful completion cannot leak into a later failed operation. Retained results
require separate caller-owned storage.

## 3. Workloads — mixed bands becomes the ordinary-play reference; uniform stays
**Uniform is not removed.** The claim that no realistic settlement produces that
synchrony is wrong: identical starting states, simultaneous assignments and
shared events can synchronise workers. The fixture deliberately concentrates that
condition.

| Fixture | Purpose |
|---|---|
| Mixed bands, solo jobs | Ordinary-play comparison |
| Uniform, solo jobs | Synchronised XP/write burst |
| Mixed bands, parties | Coordinator/member structure |

Report all three **independently**. Retain finishing-tick stress tests. **Do not
combine into one weighted score** without an explicitly defined workload
distribution. Make this correction **before** optimisation and preserve the
previous results for comparison — an improvement in mixed bands must not conceal
a material uniform or completion-path regression.

## 4. Factor chain — try a fused reader before maintaining a cache
Smaller experiment than persistent caching: one needs-owned reader
`work_factor_for_resident_into(resident_slot, skill_level, memory_total, out)`
that validates the resident once and uses the existing authoritative formula.
**Keep one canonical formula implementation** and compare against the existing
chain. It alters no integration, introduces no invalidation rules, and changes
which tick's values work observes not at all. Its benefit remains to be measured.

If caching is still justified afterwards, its contract must cover **every**
mutation — within-tick feeding, health changes, memory changes, skill thresholds,
spawning, loading. **"Computed this tick" is not sufficient validity.** Also
distinguish caching the weighted-needs subtotal from caching final mood or the
skill-dependent work factor.

## 5. Party overhead — evidence, not a proven lower bound
The ~450 µs difference supports **investigating** progress-row processing.
Dividing by 197 gives an **observed average difference per removed row**, not a
proven fixed cost of at least 2.28 µs. The paths also differ in result counts,
validation, completion handling and traversal.

Do not merge unrelated jobs or change party gameplay to capture that apparent
saving. Label the unmeasured remainder **unattributed cost**, not call overhead.

## 6. Clamp — retain it, document the proof
```
minimum = floor(1000 × 600  × 600  / 1,000,000) = 360
maximum = floor(1500 × 1150 × 1000 / 1,000,000) = 1725
```
The specified `[300, 1800]` clamp cannot activate within that domain. Record it
as an **invariant**. Do not manufacture an impossible runtime test, and do not
remove the contractual clamp for an unmeasured gain.

## Source
Astra, 2026-09-08, after inspecting the profiling report and the relevant code.
No repository changes were made by that inspection.
