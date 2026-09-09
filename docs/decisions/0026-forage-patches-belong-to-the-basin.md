# 0026 — Forage patches hang off the basin, not the designation
Date: 2026-09-09 · Status: **Provisional — needs a planner ruling**
Resolves a contradiction **inside `docs/game_gdd.md`**

## The contradiction
Two sections of the same document disagree.

- **§4.2** gives `ForagePatch` the field `zone: EntityRef` and cardinality
  "5 patches/forest zone".
- **§5.1** says *"There is one stock basin of each habitat type; dividing a
  player zone never creates extra ecology stock"* and *"Player harvest zones
  reference basin IDs; all intersecting zones share its quotas and do not
  multiply capacity."*

Read literally and in isolation, §4.2 gives every designated zone its own five
patches — which is exactly the capacity multiplication §5.1 forbids. Drawing two
overlapping zones over one forest would double its yield.

## What was implemented
`ForagePatch.zone` points at the **basin** zone that owns the stock, not at the
player's designation. `HarvestZone` carries a basin reference, self-referencing
at creation so there is no unbound state, and every harvest path resolves
**zone → basin → patch row**. Overlapping designations therefore debit one
`stock_milli` and accumulate one `harvested_year_milli`.

§4.2's field shape is preserved byte for byte. **The addition §5.1 requires and
§4.2 omits is the basin reference on `HarvestZone`** — that column exists in the
implementation and in neither section's field list.

Four guards make drawing twice unprofitable: a zone bound elsewhere is refused
its own patches; a basin already owning patches is refused a rebind; chains are
refused, so `basin_of(basin_of(z))` cannot disagree with `basin_of(z)`; and the
effective quota is `min(basin quota, harvesting zone quota)` — §5.1 gives the
quota to the basin and §4.2 gives each zone one, and the minimum honours both
while only ever being stricter.

## Why this needs a ruling
It adds a column to a §4.2 row. That is a schema change, and schema changes
belong to whoever owns the GDD, not to an implementer resolving a contradiction
under time pressure. The alternative readings are: patches genuinely are
per-designation and §5.1's rule is enforced somewhere else entirely; or basin
membership is derived from tile geometry rather than stored.

**Amended 2026-09-09 — the first version of this paragraph overstated the case.**
It said the geometric reading was rejected because no store owns a tile→basin
mask. That is true of `WorldTileMaps` (`building_slot`, `room_slot`,
`zone_link_head`, `resource_slot`, no basin column), but it is not the whole
picture: `game_gdd.md:241` defines the basins geometrically — west
`x=8..49,z=20..105`, east `x=82..119,z=20..105` — so membership *can* be computed
by a predicate needing no storage. The 16384-link-budget objection applies only to
the variant that registers ~6880 tiles as zone links, not to a pure test.

The surviving objections are narrower. The rectangles exclude water, so the
predicate must also apply §5.1's coast/river/lake mask priority, and each basin
splits at `z=62` into north/south partners — four regions, not two. And it
hardcodes one authored preset's geometry into the ecology store, where §5.1 calls
the shipping map "a deterministic authored estuary preset". A stored reference
answers for any map; a predicate answers only for this one. Neither objection is
fatal, and the planner may still prefer derivation. `zones_intersect()` is exposed so the eventual
designation command can enforce §5.1's intersection rule when a command path
exists.

## Note on a related gap
`ForagePatch`'s owner-major index is `zone_slot * 5 + kind`, which is **derivable**
from two stated numbers — §2.2's 640 rows and §4.2's 5 per zone — so it was not
invented. That distinguishes it from `HivePollinationLinks`, which blocker **U6**
records as having no stated formula and no derivable one.

## Source
Found while implementing task 03 increment 4, 2026-09-09.
