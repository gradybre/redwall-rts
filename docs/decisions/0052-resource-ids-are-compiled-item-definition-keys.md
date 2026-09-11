# 0052 — Resource, forage and fish IDs are compiled `ItemDefinition` keys, resolved at one boundary
Date: 2026-09-11 · Status: Accepted
Implements [READY_07 §2](../rulings/2026-09-11_ready07_open_item_answers.md) in
`godot/scripts/core/resource_catalog_binding.gd` and `godot/scripts/core/world_init.gd`.
Consumes decision [0034](0034-the-catalog-artifact-is-compared-as-bytes.md) and
[0048](0048-world-generation-anchors-and-what-it-refuses-to-invent.md) unchanged, and the
allocate-before-consume rule (see the note below on its citation).

**Carried discrepancy, recorded not fixed.** Twenty-five comments across ten core modules —
`command_dispatch.gd`, `commands.gd`, `farming.gd`, `fishing.gd`, `gear.gd`, `job_planner.gd`,
`needs.gd`, `resource_nodes.gd`, `work.gd` and `world_init.gd` — cite *"decision 0024"* for
allocate-before-consume, but [0024](0024-work-tick-optimization-order.md) is *"Work-tick
optimisation order and workload references"* and contains no such rule. The rule itself is real and
uniformly applied; only the citation is wrong, and correcting twenty-five comments is not this
change's scope. Whoever next touches them should either write the missing record under a new number
or repoint the citations — not invent a third number. This record deliberately cites the rule by
name rather than by that number.

## What this closes

`world_init.gd` generated a complete, fully tested world and **could not be composed into the
runtime**, because its `Request` needed resource item IDs and nothing in the repository said which
catalog they came from. Three store headers said so in terms: `resource_nodes.gd`'s
*"`resource_id`'s DOMAIN IS UNSTATED"*, `forage.gd`'s *"`item_id`'s DOMAIN IS THE CALLER'S"*,
`fishing.gd`'s *"`species_id`'s DOMAIN IS UNSTATED"*. READY_07 §2 settles it.

`ResourceNode.resource_id` identifies the **extracted output's compiled `ItemDefinition` ID**.
`ForagePatch.item_id` and each `FishStock`'s item-ID field use the same domain. The five `Request`
fields hold **three scalars plus arrays of five and nine — seventeen bindings**:

| Request field | ItemDefinition keys, in required consumer order |
|---|---|
| `tree_resource_id` | `wood` |
| `stone_resource_id` | `stone` |
| `iron_resource_id` | `iron` |
| `forage_item_ids` | `berries, nuts, mushrooms, herb, roots` |
| `fish_species_item_ids` | `trout, dace, salmon, perch, carp, whitefish, herring, mackerel, mussel` |

This does **not** complete New Settlement. The ruling is explicit: the generator clears a shared
directory and rejects foreign live rows, and bootstrap composition order is §7's separate problem.
`settlement_system.gd` still composes no generator, and this change does not add one.

## 1. No numeric catalog ID is written anywhere

The planner's handoff printed the IDs it observed — wood 59, stone 52, iron 19, forage
`1,35,32,15,39`, fish `55,8,41,37,5,58,16,20,33`. Those are **diagnostics**. Every one of them is
a position in an ASCII sort of `item_definitions.json`, so adding one food item moves them.
Nothing in `scripts/` and nothing in the test suite asserts any of those numbers. What is asserted
is that each **key** resolves, and that the ID it resolves to is the ID the catalog itself reports
through two independent readers: the loaded `item_definitions.gd` registry, and the committed
`catalog_ids.json` artifact. The two must agree, key by key, or the binding refuses.

## 2. Order is the contract, and it is borrowed rather than retyped

The ruling: *"sorting those arrays by compiled IDs would associate the wrong quotas, yields and
habitats."* `PATCH_CAPACITY_U[kind]`, `SPECIES_CAPACITY_U[species]` and
`SPECIES_HABITAT_TYPE[species]` are subscripted by **row**, and a compiled item ID is a different
index entirely.

The boundary therefore does not contain a list of forage or fish keys. It walks `Forage.PATCH_KEYS`
and `Fishing.SPECIES_KEYS` — the owning stores' own arrays — so its output is in row order **by
construction**, and there is no second list to fall out of step. `verify_ids()` proves an
externally built request agrees position by position, which is what makes the defect impossible
rather than merely avoided. Neither shipped order is ascending compiled-ID order, so a test that
sorts and compares is a real discriminator and not a coincidence.

## 3. The defect this exposed: `fishing.gd` takes a different index order

**Found by this change, and it was invisible before it.** `fishing.gd`'s
`generate_initial_estuary(species_ids)` takes its nine IDs addressed
`habitat_type * 3 + species_index` under the **compiled** `HabitatType` ordinals COAST=0, LAKE=1,
RIVER=2. `Fishing.SPECIES_KEYS` is in §5.4's own **species-row** order, which is RIVER, LAKE,
COAST. `world_init._publish_fish_basins()` passed the request array straight through.

| Habitat | Stocks it holds (§5.4 rows) | Item IDs it was given |
|---|---|---|
| COAST | herring, mackerel, mussel | **trout, dace, salmon** |
| LAKE | perch, carp, whitefish | perch, carp, whitefish |
| RIVER | trout, dace, salmon | **herring, mackerel, mussel** |

The lake's middle triple coincides under both orders, so a test that checked one habitat would
have passed straight over it, and every fixture used opaque integers (`20..28`) in which no
misassignment is visible. It only became detectable once the IDs were real catalog IDs with names
attached.

**The adapter belongs on the caller's side.** `fishing.gd`'s habitat-major argument order is
documented, tested and unchanged; its header already warned that the two indices are unrelated.
`world_init._habitat_major_fish_item_ids()` re-addresses the request through `fishing.gd`'s **own**
`HABITAT_SPECIES_ROWS` binding table, so neither order is retyped and neither contract moves.
`test_every_fish_stock_carries_its_own_species_item_id` and
`test_the_coast_and_river_stocks_are_not_each_others_species` pin it.

## 4. Deviation: the ruling names a call that cannot serve

READY_07 §2 says *"Resolve with `Catalog.compiled_id_of("ItemDefinition", key)`"*. **That call
refuses.** Run against Godot 4.7.2 it answers `ok=false`,
`'ItemDefinition' is not a compiled enum domain`: `catalog.gd`'s `compiled_enum()` owns four
domains — CommandKind, CropFamily, EventDefinition, HabitatType — and `ItemDefinition` is not one
of them. Its keys live in `res://data/item_definitions.json`.

It cannot simply be added. `catalog_ids.gd`'s header records why: `item_definitions.gd` preloads
`catalog.gd`, so an edge from `catalog.gd` to the item catalog is a **preload cycle**. That is the
same reason the artifact registry lives in `catalog_ids.gd` and `catalog.gd` is left byte-untouched.

`ResourceCatalogBinding.compiled_item_id_of(key)` is that call's ItemDefinition-domain equivalent:
the same `ok`/`key`/`id`/`error` result shape, resolved through the registry that owns the domain
and cross-checked against the verified artifact. The ruling's intent — resolve by key, check `.ok`,
verify the artifact — is implemented exactly; only the function's home moved, because the one it
named does not and cannot own this domain.

## 5. Refusal is the only failure channel, and it costs nothing

Opening the boundary verifies `catalog_ids.json` against the installed catalog **before** a key is
read (decision 0034: the artifact is compared as bytes, never trusted). Resolution then refuses, with its
own `StringName` code and no usable ID, for each of:

| Case | Code |
|---|---|
| No registry / unloaded registry | `ITEM_BINDING_NO_REGISTRY` / `ITEM_BINDING_REGISTRY_NOT_LOADED` |
| Stale, edited, truncated or missing artifact | `ITEM_BINDING_CATALOG_ARTIFACT` |
| Boundary never opened | `ITEM_BINDING_NOT_OPEN` |
| SET-AMEND-001 §3 retired key | `ITEM_BINDING_RETIRED_KEY` |
| Key not in the catalog | `ITEM_BINDING_UNKNOWN_KEY` |
| Registry and artifact disagree on an ID | `ITEM_BINDING_ARTIFACT_DISAGREES` |
| Array not five / not nine long | `ITEM_BINDING_SET_SIZE` |
| Any position holding another key's ID | `ITEM_BINDING_ID_NOT_BOUND` |

A retired key refuses **before** the registry is consulted, so "hunting was retired" is never
reported as "typo", and `world_init.gd` adds `WORLD_UNBOUND_ITEM_CATALOG` for a request that
carries no boundary at all. There is no fallback ID, no substituted free resource and no partial
binding: a refusal hands back `null`, not sixteen of seventeen IDs.

The allocate-before-consume rule is what makes this free. `world_init` validates the request inside `_prepare()`,
before a row is cleared or written, so a refused binding leaves every collaborating store
byte-identical — proved against the world fingerprint, not just against the return code.

## 6. `_item_id_is_storable()` is kept, and demoted

The ruling named its weakness precisely: *"accepts an arbitrary valid-looking integer, so it cannot
prove correct catalogs."* It is not deleted — it is the cheap shape precondition that gives a
negative or non-int32 ID its own `WORLD_INVALID_ITEM_ID` code instead of a confusing binding
refusal. `_refuse_binding()` is what proves the ID is the *right* one. Both run before any store
is read for capacity.

## 7. No ledger row

The boundary holds one cold-path key→ID `Dictionary`, read from the already-counted catalog
artifact, alive only for the duration of world construction, and stores nothing per entity.
It adds **no** §2.2 field row and **no** §2.3 allocation row; `docs/validation/ready07_arithmetic.py`
still passes with 135 field rows and 23 allocation rows, planned payload **60256806** and one world
plus reserve **68645414**. ADR 0050's +437632 reconciliation is reproduced by that script's own
assertion and is **not** applied a second time.

## 8. What is still blocked

* **The save round trip.** There is no save module in this repository. `catalog_ids.gd` already
  produces the header digest and section payload a save writer needs, and its load path verifies
  the same artifact this boundary verifies — but "generate a world, save it, reload it, prove the
  bound IDs survive" cannot be exercised, and is reported BLOCKED rather than passing.
* **Bootstrap composition.** `world_init` is now constructible from a loaded item registry alone
  (`WorldInit.bound_request(items)` names no key and no number), but composing it into
  `settlement_system.gd` is READY_07 §7's, together with starter buildings, footprint clearing and
  the 12-resident fixture. Footprint clearing legitimately changes the node-count fixture; nothing
  here protects that obsolete count.
* **`fish` as a recipe selector.** `fish` is not a runtime stock item and no generic `tree`,
  `forage` or `fish` `ItemDefinition` was invented. How a recipe selects among the nine species
  keys is unresolved and untouched here.

## Alternatives rejected

* **Adding `ItemDefinition` to `catalog.gd`'s compiled domains.** A preload cycle, per §4.
* **Letting `world_init` keep the range check alone and adding a separate "correct" constructor.**
  The defect the ruling names is that a *request* cannot be proved; a constructor nobody is
  obliged to use proves nothing about the requests that reach `generate()`.
* **Re-ordering `Fishing.SPECIES_KEYS` to habitat-major.** It is §5.4's row order and every
  per-species table is subscripted by it. Re-ordering would move nine capacities, nine recovery
  rates and thirty-six availability entries to prevent one caller from mis-addressing an argument.
* **Sorting the bound arrays for stable comparison.** Exactly the defect the ruling forbids.
