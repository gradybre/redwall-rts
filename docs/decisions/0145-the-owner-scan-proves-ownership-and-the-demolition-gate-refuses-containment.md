# 0145 — The owner scan proves ownership, and the demolition gate refuses containment
Date: 2026-09-14 · Status: Accepted

## Decision

[INV-GOODS-R01](../rulings/2026-09-14_cycle02_construction_goods.md) is
implemented in three parts, and the third one is a refusal.

1. **`inventory.gd` publishes `containers_by_owner_into()`** — a bounded,
   read-only, two-pass scan over the existing container rows. A **directory**
   owner pair goes in; complete **inventory-container** pairs come out, flat,
   in ascending container-slot order, into a buffer the caller owns and reuses.
   No reverse index is built, saved or kept. `owner_query_cells()` publishes the
   largest result the store can produce, so a caller sizes its scratch from the
   store rather than from a number of its own choosing.

2. **`settlement_system.gd::request_demolition()` is REQ-SET-128's composed
   gate**, because that is the only place `buildings()`, `construction()` and
   `inventory()` meet over one directory. It runs five ordered stages —
   subject, endpoint proof, goods, occupant recheck, footprint coverage — and
   **changes no state in any of them**. It never calls
   `construction().open_demolition()`.

3. **It always refuses today, at stage 5, as `MISSING_CONTAINMENT_CONTRACT`.**
   An `InventoryContainer` row carries owner, mass, filters, reserved mass,
   policy and reachability and **no position**, and nothing maps a tile to a
   container. Owner equality with a Building proves **ownership**. It does not
   prove **containment**, so a ground pile in the doorway or a visitor's cart
   inside the footprint is invisible to every query that exists.

Four supporting choices go with it:

* **A missing binding refuses differently from a proved-empty scan.** A
  malformed owner, an undersized buffer, a `material_container` handle that
  names no live container, and a project that has taken delivery while naming
  no container at all are each refusals. Only a complete scan for a well-formed,
  live owner is allowed to report 0.
* **The two reference domains stay apart.** `construction.gd` still
  range-validates `material_container` and still holds no Inventory. The gate
  validates that handle against **Inventory**, and every other endpoint ref
  against the **directory**. Neither is ever validated as the other.
* **One walk defines the affected endpoint set, and it is run twice** — once to
  prove, once to scan. Neither stage owns a list, so they cannot disagree about
  which endpoints exist. The occupant recheck is taken **after** the proof,
  from `construction.gd`'s own counters.
* **A live lot is counted once whatever its `reserved_milli`**, and a
  container's `reserved_mass_g` is reported separately as an outstanding
  capacity claim. No lot is invented to account for undelivered headroom.

## Why

The previous lane refused to accept a caller-supplied "goods are clear" boolean
and cited MOVE-DEP-R05. That refusal was correct and is not undone here: what
lands instead is evidence the gate gathers itself, from the authoritative stores,
immediately before the decision.

The trap this design is built around is that **an empty answer and an unasked
question look identical in a count**. A gate that enumerated the containers it
can see, found none, and published a demolition project would be reporting "I
looked and found nothing" when the truth is "I cannot see there". That is the
exact shape of the `-1` overflow sentinel this repository has already been bitten
by, one level up: a value that is technically true and operationally a lie. So
stage 5 refuses unconditionally and names the binding owner who must close it,
and stages 2 to 4 run first so that every concrete blocker is reported with its
exact count rather than being masked by the gap.

Keeping the gate read-only is what makes it safe to ship in that state. It is
callable now, it is honest now, and the day a footprint/placement binding lands
it gains a success path without any of its refusals changing meaning.

## Consequences

* `REQ-SET-128` stays open. A container owner scan alone does not prove physical
  containment, and the relocation half — real hauling, then a retry that re-reads
  these same stores — is the separate containment/evacuation integration.
* `construction.gd::open_demolition()` is unchanged in behaviour and is now
  documented as a store-level transition rather than the player-facing gate. It
  publishes a project and moves the subject to DEMOLISHING as soon as the
  resident half passes, and it can see no container at all.
* Two refusal branches in the gate — the owner query refusing, and the int64
  overflow of a quantity total — are guards that the current composition cannot
  reach. They stay, with the reason written at the branch, because reading a
  refused query as "no goods" is precisely the failure this ruling forbids.
* Scratch memory owed to the ledger: `settlement_system.gd` allocates 1043456
  bytes once, in `_init()` — `_demolition_pairs` 811008, `_demolition_seen`
  101376, and the report's two lot columns 131072. None of it is registry state
  (the registry covers `godot/scripts/core`), and none of it is touched by a
  tick.
* The tier-2 demolition basis is still unresolved and still uses the base §4.1
  row at every tier, exactly as before.
