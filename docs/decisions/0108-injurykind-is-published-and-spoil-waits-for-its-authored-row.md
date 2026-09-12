# 0108 — InjuryKind is published; spoil and lot provenance wait for their authored rows
Date: 2026-09-12 · Status: Accepted

## Decision

Three separate calls for EH-01 of
[SET-MOVE-ECON-001](../underground_economy_hazard_amendment.md) (policy owner
[DEC-040](../setting_decisions.md), parameters
[decision 0107](0107-underground-economy-and-hazard-parameters.md)):

1. **Publish `InjuryKind` in `godot/scripts/core/catalog.gd` as a PROTECTED enum
   domain**, carrying GDD §4.3's own numbers verbatim — `NONE=0, CUT=1, BITE=2,
   FALL=3, EXPOSURE=4, EXHAUSTION=5` (`game_gdd.md:215`). `catalog_ids.json`
   moved from 4062 bytes / 28 domains / 275 rows /
   `3407b52e4db6fb19874d8ea3a3d636e46575def0048b513558f7a5d3894c3e90` to
   **4140 bytes / 29 domains / 281 rows /
   `4fdd24b8b49182798b844221efda12a0e211db5dd6d7e6582307b8a86dab1e8a`**. That is
   an intentional catalog/schema change, not a parity result: every save written
   against the old digest refuses until an explicit migration exists.
2. **Do not add the `excavated_earth` ItemDefinition here.** ECON-002 authors it
   completely, but the ItemDefinition catalog has exactly one authored source and
   that source is not in this change's ownership. The exact row and tool change
   are reported to the owner rather than hand-inserted.
3. **Do not create the `InventoryLot.provenance` domain.** ECON-002 names three
   of its members; no specification names the domain or its complete member list.

## Why

### InjuryKind is protected, not compiled

HAZ-001 is explicit: "Use integer state and existing GDD InjuryKind ... No new
injury-kind enum or combat system is introduced. The earlier request review
incorrectly said the complete kind domain was absent: GDD §4.3 already lists it."
`catalog.gd`'s own header had already listed `InjuryKind` among the §4.3 enums it
did not yet carry and had already ruled that adding one is "an intentional
artifact/digest change, not a fix". So the definition existed and the *publication*
did not; HAZ-002/003 then bind EXPOSURE, EXHAUSTION and FALL to new hazard
outcomes by reusing those three numbers.

Decision 0018 settles which table it goes in: every enum §4.3 numbers explicitly
belongs in `PROTECTED_ENUM_DOMAINS`, because a protected table is the thing that
*refuses* a recompile. This domain is the clearest case yet. Ascending ASCII over
its own keys generates `BITE=0, CUT=1, EXHAUSTION=2, EXPOSURE=3, FALL=4, NONE=5`
— which agrees with §4.3 on `CUT=1` and disagrees on the other five. A partial
coincidence is the dangerous shape, not a safe one: a silent regeneration would
look half-right while repointing every persisted `Injury.kind` at a different
injury, with `NONE` (absence) landing on `EXHAUSTION`'s number. Both halves are
asserted rather than assumed: `test_catalog.gd` feeds the compiler these six keys
in **strictly descending** ASCII order, so a compiler that enumerated its input
instead of sorting it produces the exact reverse on every key and dies.

The aggregate Injury store, severity values, hourly drains and care work are
**not** here. This table carries identity only; the injury/care owner reads
`Catalog.INJURY_KIND[...]` rather than mirroring the numbers, so there is exactly
one copy and no drift is possible.

### `excavated_earth` is authored, and still blocked on one row

ECON-002 leaves nothing to invent: key `excavated_earth`, category MATERIAL,
mass 1000 g/U, nutrition 0, shelf_hours 0, raw_edible false, seed false, effect
NONE, effect_value 0, and an explicit prohibition on aliasing `stone` or
`compost` (both of which exist and neither of which is earth; `compost` even
shares MATERIAL/1000 g, which is exactly why a rename would have looked
plausible). None of that is the obstacle.

The obstacle is that this repository has one authored source for the item
catalog, `docs/gameplay_balance.md` §3.1, mechanically extracted by
`tools/extract_item_definitions.py` into `godot/data/item_definitions.json`, and
`godot/test/test_item_definitions.gd` runs that real extractor against that real
document as a subprocess. Writing the key into the JSON, or into `catalog.gd`,
without the §3.1 row would create precisely the hand-copied second catalog the
pipeline exists to prevent — and the suite would fail honestly when it did.
Neither the balance document nor the extractor is in this change's ownership, so
the row and the `EXPECTED_ROW_COUNT` bump are reported, not invented. Inventing
the number was never the risk here; bypassing the single-source rule was.

### The provenance domain has no name and no complete key set

GDD §4.2 types `InventoryLot.provenance` as `enum` and §4.3 does not number it,
so under §4.2's closing paragraph it is compiled from its own sorted ASCII keys —
as `inventory.gd` already says in terms, while deliberately refusing to assert
what any member equals. ECON-002 supplies three members (`EXCAVATION`,
`BACKFILL_RECLAIM`, `SPOIL_RECLAIM`); GDD §5.11 mentions `STARTER` and §5.7 a
coastal-brine kind; nothing anywhere declares the domain's **name** or its
**complete** member list.

Publishing three keys of an unknown number, under an invented domain name, would
bake a wrong save-carried numbering into the header digest — the failure mode
`BuildingDefinition` was published whole to avoid (decision 0056), and the same
grounds on which `catalog_ids.gd` already refuses to name the entity-kind and
RNG-stream domains. A domain name is the artifact's own object key, so changing
it later moves the hash again. Refused, and named as a blocker in `catalog.gd`
rather than guessed.

## Consequences

- `Catalog.INJURY_KIND` and `Catalog.INJURY_KIND_DOMAIN` are the single source of
  those six ordinals. The injury/care owner (task 08) must read them from there;
  a locally mirrored copy is the drift decision 0018 forbids.
- The catalog digest moved for the fourth time. `test_catalog_ids.gd` pins the
  new bytes/domains/rows/digest and pins the previous set alongside them, so "it
  changed" is asserted rather than assumed.
- No packed column was added — `catalog.gd` holds no `var` — so no
  `systems_architecture.md` §2.2/§2.3 allocation row and no new
  `persistence_state_registry.md` row is owed. The existing registry row for
  `catalog.gd` says "eight protected enum tables"; it was already stale at
  fourteen and is now fifteen, and that one word is a correction owed to the
  registry owner.
- `excavated_earth` does not exist at runtime, so nothing may reference it yet,
  and no test can yet pin its mass or its 2000 milli-U per-quantum yield. Those
  two numbers are currently pinned only by
  `docs/validation/validate_underground_economy_hazards.py`, which was
  mutation-checked against both.
- **No MOVE gate and no task 05.1b item is closed by this decision.** ECON-003–006
  and HAZ-003–006 are untouched; this is catalog identity only.

## Superseded by

Nothing yet. Retiring the two blockers needs, respectively, a §3.1 row for
`excavated_earth` and a ruling naming the provenance domain plus its complete
member list. Numeric tuning of any adopted value happens through a recorded owner
revision backed by observed play, per DEC-040.
