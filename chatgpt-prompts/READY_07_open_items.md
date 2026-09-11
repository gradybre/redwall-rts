# What the executor needs from the planner — 2026-09-11

`master` at `6cac394`. **1999 tests, 56972 assertions, 0 failures.** Tasks 01–03
complete; task 04 at 9 of 20. CI enforces the suite on every PR.

Ordered by what each unblocks. **Item 1 blocks the remaining programme; items 2
and 3 block specific work; 4–7 are correctness and ownership questions that do
not block but are accumulating.**

---

## 1. MOVE-G01–05 — the wall

**Task 05 is 0 of 20 requirements and cannot start.**

`docs/movement_direction_amendment.md` adopts the scope; decision 0020 records
the gates as open. Task 04.1's phrasing applies to them exactly: geometry,
traversal profiles, construction accounting and the interruption/hazard matrix
are *"design deliverables, not unspecified values a coder may choose at runtime."*

**Everything built this session is inert until this closes.** A job reaches
`RESERVED` and stops: there is no pathfinder, no Transform store, and no
`RESERVED → TRAVEL → WORK`. Four job producers queue work nobody can walk to.

The roadmap's own first-playable checkpoint (FP-01…12) needs movement, UI and
commands together. Commands are done; the other two are not.

---

## 2. Resource item ids — five values, and the cheapest thing on this list

`world_init.gd` **cannot be composed into `settlement_system.gd`** because its
scenario request needs **tree, stone, iron, forage and fish item ids that no
document assigns**. `resource_nodes.gd` has recorded since it was written that
`resource_id`'s domain is unstated; §4.2 types it `int32` and never says whether
it indexes a compiled `ItemDefinition` or a separate resource catalog.

So world generation works and is tested, and the runtime cannot call it without
inventing five numbers.

**What is needed:** either assign the ids, or state that they are compiled
`ItemDefinition` keys and name them. This is a short answer that unblocks the
New Settlement path immediately.

---

## 3. The 04.1 scheduler-event amendment — U2's other half

The **economic** command queue ships and is merged. ARCH-CMD-002's **speed/pause
scheduler-event queue** does not exist, because 04.1 reserves its envelope
fields, queue size, packed widths, stride, accepted enum values, exhaustion
refusal, save subsection and memory accounting as amendment deliverables.

**None were invented.** `sim_clock.gd` is byte-untouched and its two
`BLOCKER U2` comments remain accurate.

---

## 4. Three contradictions inside the specifications

Each is recorded in code as `NEEDS A RULING`, with **nothing written either way**
so no save carries a guess.

| Where | The contradiction |
|---|---|
| `crop_weather.gd:126` | **`fishing.gd` contradicts itself** on who owns mussel's summer blight closure — one comment says ARCH-SYS-006, another says ARCH-SYS-005, and §5's *Writes* column lists no fish closure at all |
| `weather.gd:149` | The event **taxonomy** is unresolved; the field is deliberately not stored until it is |
| `weather.gd:159` | Which season ARCH-SYS-006 supplies to a given step |

---

## 5. ARCH-MEM-010 — which figure is authoritative

§2.2's prose sits **437632 bytes** below its own table's mechanical sum. The gap
is exactly `131072 + 306304 + 256` — three items named inside the *Fixed registry
payload* derivation but absent from the ARCH-MEM-009 trail, so the carried total
never picked them up.

**Five separate increments reproduced it independently and none moved it**,
because every headroom and conflict figure derives from the carried total.
Re-basing is a planner decision.

Related, and already corrected in place rather than silently: ARCH-MEM-010's own
*reconciliation* figure had gone stale (computed against decision 0043 and never
advanced for 0044/0045/0048), and §2.4's prose reconciliation was understating by
250080 bytes. **The 437632 gap itself is unchanged.**

---

## 6. Decision 0016 — still `Owner: unassigned`

`needs.tick_all()` costs **1.19 ms at the 256-resident cap** against a 2 ms
whole-tick budget. Open since 2026-09-06. READY_06 §10A recommended
"implementation lead, with independent performance review" and a checkpoint after
the integrated path exists. **That path now exists** and the record still says
unassigned.

A related debt is now stated rather than implicit: **ARCH-SYS-017 CareHealth runs
fourteen places early**, in ARCH-SYS-003's slot. It is unobservable today because
016 RoomHeat and injury care do not exist — and becomes a **one-tick lag the
moment either lands.**

---

## 7. Task 06's starter contracts — the colony has no inhabitants

The 12-resident fixture is **BLOCKED**. No Building, Furniture or Container store
exists, and 04.3 forbids substituting *"unlimited piles, fictional beds,
duplicated tools or unregistered inventory owners."*

A generated world therefore has terrain, trees, ore, basins and fish — and nobody
living in it.

---

## If only one thing gets answered

**Item 1.** Items 2–7 each block one thing; item 1 blocks the remaining
programme. Item 2 is the cheapest and would unblock the New Settlement path the
same day.

## Not asking for these yet
U5's four remaining child stores (`BatchState`, `LotEffect`, `NoticeCondition`,
`ChildSliceIndex`), U6's `ManualTask` owner-major index, and decision 0048's two
residuals (the danger-band anchor's latitude, and basins created
`enabled = false`). All real, all narrower, all fine to leave until their owning
task starts.
