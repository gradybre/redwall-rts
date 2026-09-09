# 0033 — Compiled enum IDs come from ASCII keys, and three modules got it wrong
Date: 2026-09-09 · Status: **Accepted — the contract was always in §4.2**
Corrects: `fishing.gd`, `weather.gd`, `farming.gd`, and my own reports about them

## The contract
`game_gdd.md:177`, the closing paragraph of §4.2:

> All gameplay enum numeric values **not individually listed** are generated once
> from the **lexicographically sorted ASCII catalog keys** within their own domain
> and committed to `catalog_ids.json`; loading verifies its hash. **Runtime
> enumeration by dictionary insertion order is prohibited.**

`BAL-CAT-001` repeats it. `BAL-CAT-002` names **crop-family** explicitly.

## The error
I reported three times — in module headers, in decision 0032, and in the brief
sent to the planner — that these enums had **no stated numbering** and needed a
ruling. They did not. §4.3's table does not list them, and I stopped there; §4.2's
closing paragraph says exactly what happens when a value is not listed, and I
never read it.

Three modules therefore numbered their enums in **printed-table order**, which is
the "dictionary insertion order" §4.2 prohibits by name.

| Column | Shipped | Required |
|---|---|---|
| `FarmPlot.last_family` | CEREAL=0, ROOT=1, LEGUME=2, LEAF=3, FIBER=4 | CEREAL=0, FIBER=1, LEAF=2, LEGUME=3, ROOT=4 |
| `Weather.event` | ideal_spell=0 … calm_days=6 | blight=0 … ideal_spell=6 |
| `FishHabitat.type` | RIVER=0, LAKE=1, COAST=2 | COAST=0, LAKE=1, RIVER=2 |

All three are persisted.

## One of them was a data bug, not a numbering choice
`fishing.gd` computed `habitat_type * SPECIES_PER_HABITAT + species_index` in
five places to reach §5.4's species table. That worked **only** because the
ordinals coincided with the table's printed row order. Under the correct
ordinals a river habitat would have received **coast species — wrong data, no
error, no refusal.**

Stock-row indexing `habitat_typed_row * 3 + species_index` is correct and stays.
Species *catalog identity* is now an explicit habitat-ID-to-species table. The two
were one formula and are two different things.

`weather.gd` had the same shape in miniature: the selection traversal and the
stored ID were the same ordering. Decision 0028's ruled traversal — §5.10's
printed order — is unchanged and still governs which event a seed selects. Only
the **stored number** changes, and no draw count or interval boundary moves.

## Two categories in `catalog.gd`, not one
Decision 0018 said new enums go into `PROTECTED_ENUM_DOMAINS`. That stays true
for enums **§4.3 numbers explicitly** — the protected table is the thing that
refuses a recompile, and those values must never be regenerated.

These three are the other kind, and they now have their own registry:
`COMPILED_ENUM_DOMAINS`. The distinction is exactly §4.2's: *individually
listed* values are protected, *not individually listed* values are compiled from
sorted keys. Protecting a compiled domain would be the original error in a new
form — pinning a guess as though someone had specified it.

`verify_compiled_enum()` re-derives each table from its own keys through the
existing ASCII compiler and every owning module calls it from `_init`, so the
tables are transcriptions of a generated result rather than a second set of
hand-picked ordinals.

## Migration
No production save module exists yet, which does not make silent reinterpretation
acceptable. Retained snapshots and replay fixtures translate through explicit
maps or are rejected with an unsupported-catalog message:

| Domain | old → new |
|---|---|
| Habitat | `[2,1,0]` |
| Weather | `[6,5,2,0,3,4,1]` |
| Family | `[0,4,3,2,1]` |

Changed fixture hashes are recorded as an **intentional ID/schema change**, never
as optimization parity.

## The process lesson, which is the reason this record exists
**This was the second "nothing states this" claim to prove false in one session.**
The first was `quota_milli`'s period, stated all along in UI-SET-050
(decision 0030). Both failures share one shape: I searched the document that
usually owns the answer, found nothing, and escalated — without checking the
document set's *general* rules or its sibling specifications.

An absence is only evidence after the general clauses have been read, not just
the specific table. Concretely, before reporting a contract as unstated:

1. Read the owning section's **closing/general paragraphs**, not only its tables.
2. Search `gameplay_balance.md` and `ui_ux_controls.md`, not just the GDD and the
   architecture.
3. Grep the whole `docs/` tree for the field name before writing "unstated".

The cost here was three modules shipped against a prohibited numbering, one of
them carrying a silent data-corruption path.

## Source
Planner answer §2 in `docs/rulings/2026-09-09_ready06_open_item_answers.md`,
2026-09-09, which identified the existing rule rather than supplying a new one.
