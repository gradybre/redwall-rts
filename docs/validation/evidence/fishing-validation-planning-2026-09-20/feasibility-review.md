# Fishing owner 4 section 4 feasibility review

Read-only source review of the current heads named in `source-layout.json`. No public
probe has been run; nothing below is a runtime result, an acceptance, or an
authorization to implement.

## Re-derived pins (section 4 only)

`save_component_columns_schema.gd` owner index 4: key `fishing`, key_bytes 7,
OWNER_VERSIONS 1, primary_count 32, field_count 22, field_begin 80,
child_count 0, child_begin 3, offset 8503348, payload 5524, block 5555.
Types split 5 u8 / 13 i32 / 4 i64. Values are 352 + 1280 + 1152 + 256 + 2304 =
5344 bytes; payload 5344 + 22*8 + 4 = 5524; block 5524 + 24 + 7 = 5555; and
8503348 + 5555 = 8508903, the next owner offset. Section pins: declaration 1,
section schema 2, 18 owners, 298 fields, 193184 rows, 12947565 bytes. Stock
columns are literal 96-length fields, not a declared child extent.

**Pin hazard.** `fishing.gd` declares `CANONICAL_OWNER_SCHEMA_VERSION = 2`, which
is the section 7 claim owner schema under FISH-ID-R01. Section 4's owner version
is 1. A bridge must read the section 4 metadata table, never that constant.

## Hypotheses against the writers

Section 4 population writers are `_write_created_stocks` (80% of the table
capacity), `harvest_into`, `recover_stock`, `recover_daily`, and the clear and
destroy paths. Harvest refuses any amount above `allowed_stock`, whose floor is
30% or 10% under the visible intensive policy (restored to 30% inside a closure
window), and recovery caps at the room below K. No public path lowers P below
`floor(K/10)` or raises it above K, so 10%K..K holds for present stocks; I found
no counterexample and no producer defect on that path.

The restocking latch is written only by `_update_restocking`, reached from both
mutators. `100*P < 30*K` forces 1 and `100*P > 40*K` forces 0; inside the
inclusive 30..40 band either value is reachable, because a rise from below and a
fall from above both retain. Equality at exactly 30 or 40 admits both values.
Never recompute the latch from P.

Per-habitat `harvested_today` is incremented only in `harvest_into`, which is
bounded by `remaining_quota_milli` against `floor(K_total/40)`, and zeroed
globally by `reset_harvested_today`. The three-stock sum bound holds.

`destroy_habitat` refuses while `effort_used > 0`, then clears presence, self
ref, zone ref, capacity and intensive, and blanks all three stock rows, while
retaining type, effort_slots, pollution, danger and protected_fraction.
`clear()` instead zeroes everything, leaving type COAST(0) beside effort_slots 0.
**Finding:** an inactive row therefore cannot be required to satisfy
`effort_slots == EFFORT_SLOTS_BY_TYPE[type]`; the admissible domain is
`effort_slots in {0, EFFORT_SLOTS_BY_TYPE[type]}` with `effort_used == 0`.

For a present habitat the same-owner relation holds exactly: its three stock rows
are present, each stock reference equals the habitat's own self reference, each
stock capacity is `SPECIES_CAPACITY_U[HABITAT_SPECIES_ROWS[type*3+i]] * 1000`,
the habitat capacity is their sum, and the three species ids are distinct.

Species ids are validated only as nonnegative int32; they are never used to
subscript the nine-row tables. Do not require catalog membership.

`_refuse_zone_binding` rejects only an exact duplicate slot/generation pair among
live habitats, so two live habitats may legitimately hold the same zone slot at
different generations. Slot-only zone uniqueness would be a false refusal.
Present self-reference slot uniqueness is sound, since each live row owns one
current Directory slot.

`effort_used` is locally constrained to 0..effort_slots only. Equality against
claim totals needs the section 7 claim columns plus Directory, Jobs and
Expedition joins; `restore_effort_claim` deliberately leaves `effort_used`
untouched, so section 4 alone cannot prove the aggregate.

## Candidate shape

A cold 22-array `SectionColumns` with fixed 32/96 lengths, a static pure
predicate over it, and a bridge pair on `fishing.gd` that adds no gameplay path
and mutates no existing column. Needed sources: `HABITAT_SPECIES_ROWS`,
`SPECIES_CAPACITY_U`, `MILLI_PER_UNIT`, `EFFORT_SLOTS_BY_TYPE`, `Catalog`
HabitatType ids, `SPECIES_PER_HABITAT`, the two capacities, `DANGER_MIN/MAX`,
the percent and quota constants, and `EntityDirectory` NULL/bound values. Pin
every table length before indexing. Conservative logical cost 5344 + 5344 =
10688 packed bytes; native overhead unmeasured.
