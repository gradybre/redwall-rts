# 0061 — An equipped lot is a null-container lot some store can prove
Date: 2026-09-11 · Status: **Accepted** · Completes: the half
[decision 0038](0038-gear-instances-use-a-lowest-free-pool.md) deliberately left open ·
Source: `docs/rulings/2026-09-09_ready06_open_item_answers.md` §4 ("Equipped portable gear") and
`docs/rulings/2026-09-11_ready07_open_item_answers.md` §7.2 step 5

## Decision
`InventoryLot.container` may be the null ref `(-1, 0)` **only** while a bound *equipment
authority* attests that the lot is an equipped gear record with a live resident owner.
`inventory.gd` never decides this itself: it demands a proof, `gear.gd` supplies one through
`is_equipped_record()`, and `inventory.audit()` re-derives the biconditional for every live lot.
`gear.equip()` / `gear.unequip()` move the ownership relation, the `equipped` byte, the lot's
container and the resident's Equipment mirror together or not at all.

Four of GDD §4.2's five `Equipment` columns now live in `residents.gd`. The fifth,
`clothing_tier`, stays in `needs.gd`, which already applies §5.9's tier-1 spawn equipment.

## Why

### The double count had to become unrepresentable, not merely refused
Ruling §4 forbids counting one lot "once as equipped and again in storage". A flag beside the
container reference would have made that state *expressible* and then policed by a check someone
could later delete. Instead the single field `_l_container_slot` carries it:

* a valid slot means the lot is threaded into exactly one container's intrusive list, charges
  that container's used mass, and is loose stock;
* `NULL_SLOT` means it is in no list at all, charges nothing anywhere, and is equipment.

Container mass is only ever credited through link/unlink, so an unlinked lot cannot contribute
to it, and `audit()` re-walks each container's list to prove it. `total_loose_milli()` is
`total_live_milli()` minus `total_equipped_milli()` **by subtraction**, so `loose + equipped ==
live` holds by construction rather than by two walks happening to agree. There is no arrangement
of these columns in which one lot is both.

### The proof is asked for, not assumed, and it is asked for again every time
`inventory.gd` knows nothing about gear, so it must not judge. The authority is duck-typed on a
single method name (`gear.gd` preloads `inventory.gd`, so the reverse preload is impossible), and:

* **detach** refuses without a bound authority and refuses unless it attests;
* **attach** refuses while the authority *still* attests — the door that would otherwise admit a
  lot charging container mass while counting as equipment;
* `is_equipped_record()` re-validates the owner against the directory on every call, so a
  resident who dies withdraws the proof at once and the lot becomes a loud orphan rather than a
  silent one;
* `audit()` checks `container == NULL_REF ⟺ attested` for every live lot, in both directions.

Nothing was weakened to admit a null container. `create_lot()` still requires a live container,
and split, merge, move, transfer, sink and reserve all refuse an equipped lot outright — merge
needed an explicit guard because two equipped lots both carry `NULL_SLOT` and would otherwise
have read as sharing a container.

### An authority call is the one place this module calls out, so re-entry is refused
`inventory.gd`'s header claims it invokes no callback, which the attestation would have broken.
`_attesting` is raised across the call and `_guard()` refuses every mutator while it is set, so
an authority that tries to mutate mid-validation is refused instead of half-applying.

### The Equipment mirror gets one writer and an audit
ARCH-STATE-001 says equipped tools "transfer to the resident's Equipment fields" *and* keep their
instance record. A mirror that can disagree with `GearInstance.durability` is the same defect
class as the double count, so every durability write in `gear.gd` — fishing completion, general
wear, repair — funnels through one private `_set_durability()` that writes through, and
`audit_equipment_mirror()` re-derives every row from the gear store.

### Rollback ordering, not a second copy of the world
An equip runs its fallible steps first (mirror write, then detach) and follows them only with
unconditional column assignments, so the failure path restores all three stores byte-identically.
Unequip is the mirror image. `test_gear.gd` drives both undo paths with an `InventoryScript`
subclass whose detach/attach refuse *after* the preflight has passed, because every honest
refusal happens during the check and the undo would otherwise be unreachable code claiming to be
tested.

## Consequences

* **Permitted:** exactly one new state — a live lot with `container == NULL_REF` whose gear row
  is equipped and whose owner is a live resident. Nothing else.
* **Forbidden:** shelving a lot the authority still calls equipped; detaching a reserved lot;
  unbinding the authority while equipped lots live; rebinding `gear.gd`'s collaborators while any
  row is equipped; changing or clearing a gear owner, or destroying its record, while equipped.
* **Ledger unchanged.** No new packed column is billed. `residents.gd` allocates 8192 bytes of
  the Equipment row's ledgered 10240 (`clothing_tier` is `needs.gd`'s existing column and is not
  billed twice, per READY_07 §7.2 step 2); `inventory.gd` adds no column at all. The 192 bytes of
  bootstrap seeding scratch in `gear.gd` follow the existing unbilled-scratch precedent
  (`residents._cohort_slots`, `inventory._audit_live_milli`). ARCH-MEM-009 was re-added row by
  row on 2026-09-11 for this merge: 21 rows, every running total equal to the row above plus its
  own delta, every reserve column equal to payload + 8388608, final payload **60821078** and
  reserve column **69209686**. Decision 0050's 437632 is asserted at its own trail step and was
  not reapplied.
* **Six registry rows, classified under decision 0063's separated model.** Task 09.1's gate
  requires a `docs/persistence_state_registry.md` row for every packed column in
  `godot/scripts/core`. `residents.gd`'s four Equipment columns are **category 1**: the tool pair
  is a mirror of the authoritative `GearInstance` row and *is* reconstructible, but it is written
  and cross-checked for the same reason `_skill_level` and `inventory.gd`'s `_c_used_mass_g` are,
  and it is hashed because GDD §5.7's tool gate reads it; the satchel pair is derivable from
  nothing and is recorded as an **inventory container domain** reference so a codec does not
  validate it against the directory. `gear.gd`'s two seed-lot columns are **category 3** — a
  construction-time rollback record for one in-flight `seed_starter_tools()`, read by nothing
  once the call returns, unobservable to a save because ARCH-SAVE-003 saves only at a completed
  tick boundary — and are recorded as an **inventory lot domain** reference.
* **A bounded container lot walk.** `_audit_container_row()` refuses `AUDIT_LOT_LIST_CYCLE`
  past `_l_capacity` steps instead of looping forever on a corrupted `_l_next`. This is the one
  place in the module that could hang rather than refuse, and mutation testing found it the hard
  way (see below).
* **`test_gear.gd`'s `test_equipped_column_has_no_setter_in_this_increment` changed behaviour
  and was renamed**, not deleted. Its two `has_method` assertions were true only while decision
  0038 deferred this work; the part that did not change — creation never equips, and the lot
  keeps a real container — is still pinned.

## Refused rather than invented — named dependencies

1. **The twelve-resident starter fixture.** Out of scope by instruction and still blocked on the
   Building/Furniture/Room stores (§7.2 step 2) and the prepare/validate/publish bootstrap
   coordinator (step 3). `seed_starter_tools()` implements §5.9's allotment mechanism — 24 tools,
   12 equipped, 12 stored, durability 1000 — and takes the cohort as a parameter. It creates no
   residents. **The full starter fixture remains partial.**
2. **Only the general `tool` may be equipped.** §4.2's Equipment row has one `tool_item_id` pair
   and no field for a carried net, trap or ice kit; a tier-2 outfit transfers through
   `clothing_tier`, which `needs.gd` owns and this work must not write. All four refuse
   `EQUIP_KIND_UNSUPPORTED`. **Dependency:** an Equipment row shape that names carried gear, and
   `needs.gd` for outfit transfers.
3. **Installed gear — boats and weirs.** Unchanged from decision 0038: the owner/instance
   discriminator belongs to the expedition/installed-gear contract, no fake boat `InventoryLot`
   is minted, and `set_owner()` still refuses a non-resident owner.
4. **Save round trip.** `restore_row()` still cannot restore an equipped record: it would need
   the matching `InventoryLot` image — a lot whose container is null and whose gear row attests —
   restored in the same step, and `inventory.gd` has no restore path and this store has no save
   format. **Blocked**, exactly as ruling §4's "round-trip once the save module exists" allows.
5. **Death and departure do not unequip.** No handler owns that yet. `test_gear.gd` pins the
   state as loud rather than silent: the attestation is withdrawn the moment the owner dies and
   `inventory.audit()` refuses `AUDIT_ORPHAN_LOT`. **Dependency:** REQ-SET-024's "release their
   home/tool" integration.
6. **`quality` and `provenance` for the starter lots are parameters, not constants.** §5.9 says
   PLAIN and STARTER; both are opaque compiled catalog enum values, and `catalog_ids.gd` compiles
   neither domain yet. Numbering them here would be the hand-written second copy that file exists
   to prevent.

## Acceptance evidence
Decision 0038's acceptance list, now completable: equip/unequip preserve identity, age,
provenance, quantity and durability; a null-container lot without a live equipped owner still
refuses; an equipped lot is excluded from loose-stock availability and from container/satchel
mass; the same lot is never counted twice; unequip lands in a valid reserved destination; a
failed equip leaves lot, instance, container mass and mirror byte-identical; and the 24-tool
seeding contract with tier-1 clothing as spawn equipment rather than invented `outfit_tier2`
items.

Suite: **2423 tests, 93272 assertions, 0 failures**. Measured baselines, each run here rather
than quoted: this branch's base `360969d` gave 2265 / 81004 / 0; `origin/master` at `f40b8b1`
gave 2348 / 83675 / 0; and `origin/master` at **`e5216ad`**, which this branch is now merged up
to, gives **2365 tests / 92629 assertions / 0 failures**. 58 new tests and 643 new assertions at
every one of those baselines. `python3 docs/validation/ready07_arithmetic.py` PASS;
`python3 docs/validation/state_registry_coverage.py` PASS.

**Mutation-tested: 49 mutations, one per suite run**, each restored and SHA-256 byte-compared
against a pristine copy. 48 killed on a real expected-versus-got mismatch; the 49th
(`m49`, deleting the new lot-list cycle bound) is killed by the harness's hard per-run timeout,
which is the correct detection for an infinite loop and is what the bound exists to prevent.
**No survivor was explained away as equivalent.** Five survivors in the first pass were real
gaps and each got the test that was missing:

| Survivor | The gap, and the test now covering it |
|---|---|
| attestation ignoring the `equipped` byte | gear merely *owned* by a live resident (§5.4's "worker owns net") would have attested, letting any owned lot out of its container — `test_owned_but_unequipped_gear_attests_nothing` |
| `equip()` resetting durability to the cap | every equip test started from a full tool, where a reset is invisible — `test_equipping_a_worn_tool_carries_its_wear_with_it` wears it to 630 first |
| `audit()` not re-deriving the equipped-lot count | the published count was a cache nothing distrusted — now corrupted through the private column and caught |
| the 24-row seeding preflight | asserting "nothing survives" passes for a rollback after 23 wasted creations too; the preflight is now asked directly and the inventory image byte-compared, since a created-then-retired lot advances its slot generation |
| `despawn()` not clearing the Equipment mirror | `has_equipped_tool()` is false for an absent row whatever the columns hold, and a fresh spawn rewrites them — the byte image can tell, and does |

A sixth finding came from the harness itself and is recorded because it cost real time: a
mutation that left a detached lot linked made `_audit_container_row()`'s list walk loop forever,
and `godot` on PATH is a **wrapper shell script**, so killing it left the real binary running at
99% CPU as an orphan. The walk is now bounded and refuses `AUDIT_LOT_LIST_CYCLE`; the test-side
walk is bounded too; and any harness that kills a Godot run must kill the process **group**.
