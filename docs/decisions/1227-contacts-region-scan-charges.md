# 1227 — Contacts charges a Region scan by the rows it reads (ADR 1197 G14)

Date: 2026-10-07 · Status: Accepted; implemented. Closes ADR 1197 G14. The live chain now runs the whole first-entry
prefix and finishes; what is left is G9's Kitchen, which waits on Brendan (ADR 1208).

## The gap, measured

Since ADR 1224's G13 fix, T0's paid FUND in the live chain refused `CONNECTOR_CONTACT_OPERATION_CAPACITY` at tick
4349. The suspected cause was ADR 1219's reach scan over the resident rows. **Measurement refuted that.** A temporary
probe recorded every `Fragments.spend` of the failing operation, with its call site. The operation is one budget
(`Space.MAX_CHECKS`, 1,048,576) spent across `prepare_workpiece_start`, the START proof, the material proof and the
final observation. It spent 1,046,706 checks and had 1,870 left when the final `_scope_leaf` asked for 2,048.

| Charge | Calls | Checks | Share |
|---|---:|---:|---:|
| `_retained_earth_refusal` (12 × Region capacity 6,144) | 4 | 294,912 | 28% |
| WorldRoutes reachability (`_path_refusal`) | 3 | 250,825 | 24% |
| `_unique_datum` (16 × Region capacity) | 2 | 196,608 | 19% |
| Source rows and `_scope_leaf` (2,048 each) | 56 | 114,688 | 11% |
| Location resolves (16 × Locations capacity 1,024 + sources) | 3 | 74,496 | 7% |
| `_scene_leaf` (both halves) | 2 | 66,304 | 6% |
| Start-volume slots, terrain, fragments, others | | 48,873 | 5% |
| of which the occupancy leaf, ADR 1219's reach scan included (16 × 512 rows) | 1 | 8,192 | 0.8% |

So the reach scan is not the cause, and an unregistered-resident index would save under 1%. Nearly half the
operation is two full scans of the Space Region bank, charged 16 and 12 checks for every one of its 6,144 slots,
present or not. The fixture's operation is the same shape and was already at 96% (41,038 left); the live chain's
larger Locations capacity (1,024 against the fixture's 32) adds about 48k and tips it over.

## Decision

Brendan's direction for budgets stands (ADRs 1205, 1207): **do not raise the budget; make the cost scale with what
matters.** What a Region scan actually reads is one presence byte per slot, plus the row's fields when it is present.
The three Contacts Region scans that precharged a per-slot figure now charge exactly that:

- `_unique_datum`: one check per slot, then `PRESENT_DATUM_CHECKS` (15) more per present row (16 per present row in all,
  as before).
- `_retained_earth_refusal` and `_installed_bearing_obstacles`: one per slot, then `PRESENT_REGION_CHECKS` (11) more per
  present row (12 in all, as before).

This is the convention FinalFacts already uses (`_required_checks`: a per-slot pass plus a per-present-row leaf charge)
and the one `_installed_part_refusal` and `_assembly_start_regions` in the same file already follow (one per slot).

### Why it is exactly as sound

- **The loops are unchanged.** Every slot is still visited in the same order, and every present row is examined by
  the same predicate. The result of each scan is identical by construction, so no oracle is needed: there is no
  index, cache or skipped row whose equivalence would have to be shown.
- **The charge can only be lower or equal.** A full bank (every slot present) costs exactly the old precharge, so the
  worst-case bound on work per operation is unchanged. With fewer rows it costs what it reads.
- **A mid-scan refusal is pure.** These scans read packed columns only, dispatch no observer and write nothing, so
  charging per present row inside the loop (instead of one precharge before it) refuses with the same code and leaves
  no partial state. `_fragments.failed` still poisons every later spend of the operation.

### Rejected

- **Raise the per-operation budget, or reset it between the operation's proofs.** Brendan's rule.
- **An unregistered-resident spatial index or per-operation cache** (the original hypothesis): it targets 0.8% of the
  spend and would add saved-or-rebuilt state for nothing.
- **A Region high-water mark or a dense live-row list in SpaceOwner.** It would cut the per-slot pass too, but it is a
  new derived field on a shared owner. Every publication path, both banks, the bank swap and every codec load would have
  to keep it exact, and one missed writer would hide present rows from every scan that trusts it. The per-row charge
  needs nothing kept.
- **The same rule in FinalFacts or Locations.** Those charges are shared by many owners and pinned by measured check
  counts (ADR 1205, ADR 1207). The live chain does not need them now.

## Measured after (live chain, `Contacts.final_observation_refusal`, checks left of 1,048,576)

| Operation | Before | After |
|---|---:|---:|
| L0 START | 328,893 | 597,733 |
| L0 PRODUCTIVE | 420,866 | 689,662 |
| T0 START | refused (1,870 left, needed 2,048) | 443,268 |
| T0 PRODUCTIVE | not reached | 543,368 |

T0's START now spends 58% of its budget, against 99.8% before.

## The live chain now (`test_underground_host.gd`, `run_tick` only)

It runs the whole first-entry prefix with no refusal and finishes at **tick 4630**:

- the surface walk (373 ticks) and every haul (9 whole units);
- L0's twelve paid phases and its installation (32,000 mWU of fastening);
- T0's six cut phases (54,000 mWU of cut Work in all) and T0's installation (12,000 mWU);
- placement INSTALLED 2, no live Project, and only the crew registered with Routes.

On the finishing tick the crew gives its Job back, and the runtime moves to `STEP_DONE`. ADR 1223's invariant now
reads: the crew holds an entry Job at every tick from arrival to the last.

**No new refusal code.** The next gap is not a refusal. Nothing past the prefix is planned, because the Kitchen's own
cuts (G9) wait on Brendan's choice of how to cut it (ADR 1208). There is no runtime alert for that yet: a finished
prefix is not a stall, and inventing a "Kitchen unbuilt" code would decide the Kitchen's shape early.

**Variants.** The restore-every-tick chain (runtime restored every tick, route owners cold-restored every 23 ticks)
ends byte-identical to the plain chain at the same finishing tick. Every crew-loss variant (ADR 1225), and the
rest-hour variant (ADR 1226), finish with the same ledgers. The handling-loss chain restored every 7 ticks is
byte-identical too.

**Recorded, not changed:** `UndergroundEntryRuntime.error()` keeps the refusal of the first `start` attempt after a
later attempt succeeds. In the live chain that is the G11 `ENTRY_CREW_NO_TOOLED_MOLE` from before the stand-in equips
a tool. It is part of the ADR 1218 record, so the tests read `step()` and the foreman's own `error()` instead.

## Persistence and memory

Nothing is saved or rebuilt: no field, column, wire byte or registry row. The two constants are check-charge
constants. Their storage delta is reviewed at 0 bytes in `reviewed-deltas.json`, and `REVIEWED_SHA` is re-pinned.
The joint pack is unchanged.

## Amendment (2026-10-07, coordinator's engineering decisions): the G9 alert and the stale refusal

**1. The finished prefix raises `ENTRY_DESCENT_UNBUILT` (G9).** The next room is decided. Stairs go past T0 first
(ADR 1209, paw-fitted treads side-on, still being authored), then a Kitchen dug to reachable height (DEC-054). So the
gap is named by what is missing next: the descent past T0, not the Kitchen's shape.
- The runtime raises it once, on the finishing tick, as `advance`'s return; `run_tick` then alerts it with its gap
  row.
- It stays as the runtime's `error()`.
- A later `begin_underground_entry` on a finished entry refuses with the same code, so the alert is never lost.

**2. A successful `start()` clears the previous attempt's refusal.** `_stop` now records the attempt's result, empty
on success. The live chain's G11 code from before the stand-in equips a tool no longer survives the successful start.
- `_error` is in the ADR 1218 record, so the record's `VERSION` is now 2.
- A version-1 record is refused with `ENTRY_SAVE_VERSION`, because there is no migration before 1.0 (DEC-055 item 1).
- The wire layout and `MAX_WIRE_BYTES` are unchanged.
- The restore-every-tick variants stay byte-identical.

The "Recorded, not changed" note above is superseded by item 2.
