# 0114 — A roster row is a generation-checked identity, not a bare slot

Date: 2026-09-12 · Status: **Accepted**

Implements item 3 of "Engineering work may proceed" in
[the 2026-09-12 save/registry ruling](../rulings/2026-09-12_save_registry_answers.md):
*"cache generation-checked resident reference and persistent ID with each roster row.
A stale click must never select the replacement at the same bare slot."*
It enforces **ARCH-UI-002** — "View commands use generation-validated persistent
identity, never render instance slots" — in `godot/scripts/systems/ui_manager.gd`.

It closes nothing else. It does not touch save/load, does not add a save section, and
claims **no visual verdict**: ART-UI-12 acceptance remains PENDING.

## The defect, confirmed before it was fixed

`ui_manager.gd` held `var _roster_slots: PackedInt32Array` — bare typed rows. A click
read `_roster_slots[row_index]` and guarded with `residents.is_alive(slot)`.

That guard catches a **dead** slot and cannot catch a **reused** one.
`entity_directory.gd`'s `create()` pops the lowest free directory slot *and* the lowest
free typed row, so a despawn immediately followed by a spawn returns the same resident
row at generation + 1. `is_alive(slot)` is then true again, and the old row opened the
panel on the **replacement**: B's species, needs, health and activity under A's heading,
with no refusal and nothing on screen to say the row had changed hands.

Confirmed, not assumed: the six tests added here were run against the pre-change file
(`git show HEAD:godot/scripts/systems/ui_manager.gd`) and **five of the six failed**.

## Decision

1. **Three packed columns replace the one slot column.** `_roster_ref_slot`,
   `_roster_ref_generation` and `_roster_persistent_id`, each `PackedInt32Array` of
   `UiShell.ROSTER_POOL` = 12, plus the scalar `_roster_count`. Structure-of-arrays,
   resized **once** in `_init()` — not `_ready()`, because this router is built off-tree
   by its suite and a column that only existed once the node entered the tree would be
   empty there. `refresh_roster()` overwrites; it never resizes.

2. **The generation is the DIRECTORY's.** `entity_directory.gd`'s `_generation`, on the
   directory slot. Not `inventory.gd`'s container or lot spaces, and not `navigation.gd`'s
   route-descriptor space. An unbound row holds GDD §4.1's null reference `(-1, 0)` and
   `NO_PERSISTENT_ID` = 0, and refuses a click by the same path a stale row does — there
   is no separate "is this row real" flag that could disagree with the columns beside it.

3. **A click validates before it resolves anything.** `_roster_identity_refusal()` runs
   first: `is_valid_of_kind(ref, KIND_RESIDENT)`, then the cached persistent id against
   `get_persistent_id(ref)`. Only then is the typed row resolved. A reallocated slot is
   therefore never read at all, rather than read and then second-guessed.

4. **Two guards, because neither subsumes the other.** The generation rejects a slot that
   was destroyed or handed to a different entity. The persistent id rejects a slot that
   still validates and no longer belongs to the same individual — which is what
   `restore_columns()` leaves behind, since it replaces the six persisted directory
   columns wholesale and "a reference taken before the call belongs to a different world".
   A test constructs exactly that: two live residents' persistent ids swapped, every other
   column byte-identical, the reference still valid, the click still refused.

5. **Three distinct refusal codes, not one word for three conditions.**
   `UI_ROSTER_ROW_IS_STALE` (the slot holds nobody), `UI_ROSTER_SLOT_REUSED` (the slot is
   live and holds someone else) and `UI_ROSTER_IDENTITY_CHANGED` (valid reference,
   different persistent identity). `ref_of_slot()` is what separates the first two.
   Each raises a `CATEGORY_ROSTER_STALE` notice carrying the code, a plain sentence that
   states **"nothing was selected"**, and a recovery action, and each is retained on
   `last_refusal()`. The defect being replaced was silent; the replacement is not.

6. **The detail path is ref-first throughout.** `_show_resident_detail()` takes the
   validated reference *and* the row it resolved to, selects the panel on that reference,
   and fills the five need rows through NEED-RATE-R01's `fill_needs_for(directory,
   residents, needs, ref)`. It never re-derives the reference from the slot.

## What was rejected

**Switching `fill_needs()` to `fill_needs_for()` and stopping there.** The ruling names
this as cosmetic and it is: the staleness originates in the stored row, so a ref-first
card fed a reference rebuilt from a reused slot is exactly as wrong, one call later.
The storage was fixed first and the call site followed.

**Refusing on `residents.is_alive()` alone with a friendlier message.** It cannot see a
reuse. A better sentence attached to a guard that does not fire is worse than no guard,
because it reads as coverage.

## Evidence

Full suite after the change: **3771 test(s), 133041 assertion(s), 0 failure(s)**
(baseline before it: 3765 / 132938 / 0).

Six mutations, one per Godot invocation, each restored and `shasum -a 256`
byte-compared against a pristine copy afterwards:

| Mutation | Failures | Verdict |
|---|---:|---|
| Generation dropped; reference rebuilt from the bare slot | 2 | KILLED |
| `is_alive(slot)` restored as the only guard | 3 | KILLED |
| Cached persistent id ignored | 1 | KILLED |
| Stale row falls through and selects the replacement | 4 | KILLED |
| Refresh stops caching the persistent id | 9 | KILLED |
| `_show_resident_detail()` re-derives the ref from the slot | 0 | **SURVIVED — equivalent** |

The survivor is recorded rather than papered over. It is an **equivalent mutant** under
the current stores: `_show_resident_detail()` is only reachable after validation, its
`slot` came from `slot_of_ref(ref)`, and `residents.ref_of(slot)` reads back the same
`_ref_slot`/`_ref_generation` pair that reference resolved through — so no reachable
state distinguishes the two expressions. The parameter is kept anyway, because the
property being preserved is that this function never re-derives identity from an index.

### Native macOS evidence, and what it does and does not show

Captured from the **native game** (no `--headless`) at 1280x720, scales 100% and 150%,
through a scratch harness deleted before commit:

```
godot --path godot --script capture_roster_scratch.gd --resolution 1280x720 \
    -- <ABSOLUTE out.png> <100|150> <valid|reused>
```

The harness fakes nothing: it runs `UIManager.create_world()`, presses the shell's own
Residents command, reallocates row 2's slot through `residents.despawn()` /
`residents.spawn()`, and presses the roster row. Observed, printed by the running game:

* `valid`  — detail identity line `mouse - Resident - Active`, `last_refusal()` empty.
* `reused` — detail identity line **empty** (the panel never opened), `last_refusal()`
  `UI_ROSTER_SLOT_REUSED`, and the roster row still reads `Unnamed resident  mouse`.
  The badger that took the slot appears nowhere on screen.

Two things this did **not** establish, recorded rather than glossed:

1. **No visual verdict.** ART-UI-12 stays PENDING; these are functional captures.
2. **The refusal notice is occluded while the roster page is open.** At 1280x720 the
   workspace page covers the top-centre alert zone, so the raised notice is not visible
   until the page is closed. With the page closed the card renders the category's
   authored title on one line (`Advisory: Resident is gone`), so the longer message
   this record introduces does not feed the known NARROW alert-card overflow — the card
   shows the title, not the message. The stacking question belongs to the layout and
   component owner (`ui_layout.gd`, `ui_shell.gd` workspace pages), not to this lane,
   and is reported rather than changed here.

## Owed elsewhere, and not written here

`docs/systems_architecture.md` §2.3/§3 and `docs/persistence_state_registry.md` are not
this lane's files. The three columns are **144 bytes** (3 × 4 × 12), replacing the
unledgered `_roster_slots` at 48 bytes, for **+96 bytes** net; all of it is category 3,
transient presentation, rebuilt by `refresh_roster()` and saved in no section. The exact
proposed rows were reported to the integration lead with their arithmetic.

`docs/validation/state_registry_coverage.py` enforces `godot/scripts/core` only, so it
sees nothing in `scripts/systems/` and cannot be relied on to raise this. It passed
before and after (47 modules, 326 rows, 648 packed columns) without ever looking.
