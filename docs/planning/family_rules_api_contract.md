# Family stage-rate table API

FAMILY-RULES-R01 · version1 accepted bounded contract · 2026-09-19 · Astra

This bounded packet implements the reviewed family hunger and daily-demand table as
an immutable derived catalog helper. It does not activate family gameplay, change
Needs/Residents consumers, qualify child profiles, or close the full PC-04 package.
Numerical/schema repairs were independently confirmed through FAMILY-C4-R01v4;
this API contract passed its independent check before the helper was implemented.

## Public surface and ownership

New `godot/scripts/core/family_rules.gd`, extending RefCounted. Only preload
`int_math.gd`: do not import Residents or Needs, since they will eventually consume
this helper and importing them here would create a preload cycle.

- `is_ready() -> bool`: true only after all36 table values are built and checked.
- `hunger_rate_milli_into(life_stage:int, size_class:int, winter:bool,
  out:IntMath.IntResult) -> bool`: positive magnitude of hunger decay, milli-points/hour.
- `daily_demand_np_into(life_stage:int, size_class:int, winter:bool,
  out:IntMath.IntResult) -> bool`: integer nutrition points/day for one resident.

Queries write caller-owned outcomes and return out.ok. A refusal sets value0 and
an explicit error; zero is never a successful substitute for missing stage data.
No query allocates a buffer, mutates a table, reads a world, or derives a stage from
species. The caller supplies the validated resident life stage and size class.
Winter is a boolean, matching the existing Needs public seasonal interface.

Two private PackedInt64Array fields,18 elements each, built once in `_init()`;
index=`life_stage*6 + size_class*2 + (1 if winter else 0)`. No public array accessor,
setter, reset or catalog-reload method. No Dictionary or nested array table.
The helper owns288 bytes of packed derived values plus ordinary object/scalar
overhead. It owns no authoritative world state or serialized field. Production
composition later owns one instance per published rules catalog, never one per
resident or per tick. That composition is outside this packet.

The protected local input IDs are ADULT0/CHILD1/ELDER2 and SMALL0/MEDIUM1/LARGE2.
Tests independently assert equality with Residents/Needs; the helper avoids their
preload cycle. Stage/size counts are bounds only and are not persisted identities.

## Construction and results

For each stage/size/winter combination, use checked IntMath i64 multiplication
before one final floor division. Stage multipliers are1000/750/1000; size
multipliers1000/1200/1600; season1000/1200. Hunger base250000, denominator1000000000.
Daily demand base6000, same multiplier product and denominator. Store every result
only after checked arithmetic; readiness becomes true only when both18-row tables
are complete. An overflow/domain failure leaves readiness false; partially built
private storage cannot be queried successfully. No runtime configuration input is
accepted, so missing rows are a build defect, not an invitation to fall back to ADULT.

Query refusal precedence: unavailable table → FAMILY_STAGE_RULES_UNAVAILABLE;
life_stage outside0..2 → FAMILY_STAGE_INVALID; size outside0..2 → FAMILY_SIZE_INVALID.
Valid results (size small/medium/large, nonwinter then winter):

| Stage | Hunger milli/hour, nonwinter | Hunger milli/hour, winter | NP/day, nonwinter | NP/day, winter |
|---|---|---|---|---|
| ADULT |250000,300000,400000|300000,360000,480000|6000,7200,9600|7200,8640,11520|
| CHILD |187500,225000,300000|225000,270000,360000|4500,5400,7200|5400,6480,8640|
| ELDER |250000,300000,400000|300000,360000,480000|6000,7200,9600|7200,8640,11520|

Do not use a net care-restoration rate in this table, round NP from the hunger
result, or truncate after each multiplication. Care is a separate owner/rate.
Food admission later sums individually floored resident demands; this helper
neither forecasts fractional portions nor discards resident distinctions.

## Acceptance and scope

Independent literal tests cover every36 result, IDs, flat index mapping, both
season values, adult/elder equality, exact child fractions and maximum480000.
Negative and upper-bound-invalid stage/size requests refuse and clear a reused
successful outcome. Check large signed inputs without multiplying/indexing them.
Test public immutability by repeated queries before/after refusal; no mutation
hook is added solely to corrupt an otherwise immutable table. Source/registry
classification checks prove the two packed fields are derived, not newly saved.

Register the helper's two arrays as category2 in persistence_state_registry; no
canonical field-count/version change. Record288-byte derived catalog payload in
the existing memory ownership ledger and the packet evidence. Existing runtime
hunger, daily demand, existing catalog fingerprints and saves remain unchanged
until the separately reviewed family activation transaction commits. This is an
explicit preparation task, not proof that children can be spawned or played.

Task ownership: new helper and its dedicated tests; parent owns registry/ledger
classification and task graph. Required validation: targeted tests plus existing
Needs/Residents regressions, full headless suite once, all specification gates,
and independent source review before merge. No GUI/art acceptance follows.

## Accepted dispatch citations

Independent review `draft-v4-and-rules-api-review.md` found no helper blocker.
Astra verified `int_math.gd:39–67`: IntResult has ok:bool, value:int, error:String;
`succeed(value)->bool` writes true/value/empty error and `refuse(error:String)->bool`
writes false/0/error. Use these exact methods. The helper owns three new diagnostic
String constants REFUSE_TABLE_UNAVAILABLE="FAMILY_STAGE_RULES_UNAVAILABLE",
REFUSE_STAGE_INVALID="FAMILY_STAGE_INVALID", REFUSE_SIZE_INVALID="FAMILY_SIZE_INVALID".
They are not catalog enum IDs, not stored command values and not a fingerprint
change. Future family consumers import these constants for the same diagnostic.

Packed members are `_hunger_rates_milli` and `_daily_demand_np`, each resized to
`TABLE_COUNT = 18`. Readiness is private `_ready:bool`. These are derived catalog
values under the registry's existing category2/catalog-table precedent (see
`item_definitions.gd` rows); reconstruct from the same compiled rules at publication.
No per-save mutable input is introduced. Category2 table membership does not claim
that the later complete family fingerprint producer already exists. The helper
remains unbound until activation; catalog versions must change when its values
begin affecting the authoritative world.
