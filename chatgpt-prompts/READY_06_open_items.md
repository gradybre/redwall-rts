# Open items Astra needs to close — register as of 2026-09-09

Branch `feat/ecology-rng`, head `23056ff`. **1161 tests, 34543 assertions, 0
failures.** Task 03 increments 1, 2, 3, 4, 6 and the stock half of 5 are done.

Ordered by **how much work each unblocks**, not by how hard it is to answer.
Items 1–4 block implementation. Items 5–9 concern code already shipped and
running. Item 10 has been open since 2026-09-06 with no owner.

---

## 1. Job-creation triggers — the largest gap in the document set

**This blocks the playable loop, not one increment.**

`docs/tasks/03` records it plainly: **only `FarmPlot` creates a job
automatically** — REQ-SET-073 (ripe → priority-2 harvest) and REQ-SET-085
(health 0 → 10-WU clearing).

**Foraging, fishing and hive tending have no stated job-creation trigger
anywhere in the document set.** Sowing has a validation gate (REQ-SET-070) but no
EARS trigger event saying *when* a sowing job comes into existence.

So the ecology stores now exist, are tested, and **nothing in the specification
says what causes a resident to go and use them.** Four stores' worth of work is
reachable only through a trigger nobody has written.

Needed: EARS trigger events for forage, fishing, hive tending and sowing —
whether they are player-command-driven, standing-order-driven (`OrderMode` is
numbered in §4.3 and now compiled but unused), or condition-driven.

**Blocks:** increment 7, increment 10, and any end-to-end play.

---

## 2. Three enums §4.2 types but §4.3 never numbers — one ruling, not three

The same gap has now appeared three times, and **every instance is a persisted
column**, so a later renumbering breaks saved games rather than merely behaving
differently.

| Column | Module | §4.3 lists it? |
|---|---|---|
| `FishHabitat.type` | `fishing.gd` | No |
| `Weather.event` | `weather.gd` | No |
| `FarmPlot.last_family` | `farming.gd` | No |

All three are currently module-local constants in their source table's printed
order, and deliberately **not** added to `PROTECTED_ENUM_DOMAINS` — decision 0018
covers enums §4.3 *numbers*, and protecting a guess would lend it the standing of
a specified value.

`Weather.event` is the sharpest: **§4.3 does list an `EventDefinition` catalog**,
and `catalog.gd` compiles catalog keys in ascending ASCII order by stated,
tested contract. That numbering agrees with §5.10's printed order **on `drought`
alone.**

Needed: either add all three to §4.3 with explicit values, or state that these
are catalog-compiled and therefore ASCII-numbered. **One general rule covering
the pattern is worth more than three separate answers**, since a fourth instance
is likely.

---

## 3. U6 — `HivePollinationLinks` has no owner-major index formula

Unchanged since task 02. Every other store in this group derived its index from
stated numbers; this one has **no stated or derivable formula**.

**Blocks:** increment 8 (orchard + hive), therefore increment 9's full ecology
leg and increment 10. REQ-SET-082's one/two-hive multiplier cannot be built.

Note the yield formula itself is *not* blocked — `pollination_factor` is a
parameter in `farming.gd`, so REQ-SET-074 is complete and only the hive lookup
waits.

---

## 4. U5 — no allocator budget for `GearInstance`

Unchanged since task 02. **Blocks:** the gear half of increment 5 — durability,
wear per cycle, repairs, and "a cycle cannot start with durability below wear" —
and everything expedition-shaped that depends on it.

The stock half of fishing shipped without it (§5.4's stocks, quotas, recovery,
closures, effort slots and the catch formula are all done).

---

## 5. Ruling 4 — two columns §4.2 omits for fishing (decision 0027)

**Never answered.** The 2026-09-09 handoff responded to the three-ruling brief at
head `90739ef`, written before `fishing.gd` existed.

- **Effort-slot occupancy has no column.** §4.2 gives `effort_slots` as a
  capacity with nowhere to record how many are taken; REQ-SET-044/050 require it.
- **REQ-SET-048's hysteresis has no column.** The 30-down/40-up band needs one
  bit that population alone cannot supply.

Both are save-carried state, currently marked **PROVISIONAL** in the §2.2 ledger.

Also here: **does "default to restocking" block harvest in the 30–40% band, or
only warn?** Implemented as blocking-unless-intensive-policy. The warning-only
reading is three lines away.

---

## 6. Ruling 6 — five contracts §5.6 leaves open (decision 0032)

**Three govern persisted columns.**

1. **`SOWN` vs `GROWING`** — §4.3 numbers both; §5.6 never says what separates
   them. Read as: SOWN = seed committed, 4 WU outstanding; GROWING = integrating.
2. **`family_streak` counts harvests, not sowings** — from "a second consecutive
   same-family *harvest*"; a withered crop does not advance it.
3. **What `FarmPlot.compost_milli` holds** — `TileHistory.compost_season` is
   already the eligibility gate. Used as a quantity ledger (0, then 2000).
4. **Do the 48-hour ripe grace and the 5-day withering share one instant?** They
   do in the implementation. **The alternative differs by two whole days of yield
   decay** — the largest balance consequence in this register.
5. Crop-family enum — folded into item 2 above.

---

## 7. `family_streak` has no `TileHistory` column — spend 65536 bytes or accept the loss?

ARCH-STATE-003 is otherwise satisfied and tested verbatim: a redraw does not
restore fertility and does not reset compost eligibility.

But §4.2 puts the streak *length* on the `FarmPlot` row while §2's `TileHistory`
carries only `last_family`, so **a redraw restores the family but not the count.**

The error runs in the safe direction: a restored family with a zero count reads
as a **second** consecutive harvest (850), never a first (1000), so **a redraw can
never fabricate a rotation bonus** — BAL-SAFE-014's actual concern. It can still
*lose* a penalty, turning a third-or-later 700 into 850.

Closing it needs a seventh I32 column, **+65536 bytes** over the budgeted 393216.

---

## 8. Two smaller readings, both currently interpretations

- **§5.5's regrowth formula has no stated cap**, where §5.4's fish formula writes
  its cap explicitly. The 1 U minimum is currently clamped to the room left.
- **"Up to 32" fish habitats versus §5.1's "one stock basin of each habitat
  type"** — three. The same tension decision 0026 resolved for forage, left
  unresolved here because `FishStock`'s owner is `habitat` and §5.4 states no
  zone-sharing rule of its own. If a player designation is ever allowed to create
  a habitat, fishing will need forage's anti-multiplication guard.

---

## 9. Fixtures that cannot be executed until their subsystems exist

Not rulings — dependencies, listed so they are not mistaken for passes.

| Evidence | Blocked by |
|---|---|
| R05-QTEST-12 cross-process round trip | **No save module exists in the repository** |
| R05-QTEST-14 designation preview | Command queue (U2) and UI |
| R05-QTEST-15 output-capacity leg | No Job↔reserved-container binding |
| R05-QTEST-07 cargo creation | `inventory.gd` owns cargo |
| R05-QUOTA-007 lease-expiry trigger | `jobs.gd` never writes `lease_expiry` (ARCH-JOB-004) |

---

## 10. Decision 0016 — open since 2026-09-06, owner unassigned

`needs.tick_all()` costs **1.19 ms at the 256-resident cap** against a whole-tick
budget of 2 ms (ARCH-PERF-001 / REQ-SET-163). Measured, reproduced in a release
build, and never resolved. It is not blocking implementation, which is precisely
why it has stayed open for three days while four modules were added on top of it.

Also still open from task 02: **U1** (`catalog_ids.json` has no specified shape,
serialization, or hash relationship) and **U7** (ARCH-MIG-006 requires "golden GDD
fixtures" and never enumerates them).
