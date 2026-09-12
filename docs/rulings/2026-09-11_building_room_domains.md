# Building, furniture and room domain rulings

2026-09-11 · R-BUILD-DOM-001–004 · Astra engineering decisions.
**Definitions resolved; runtime implementation and artifact regeneration remain open.**
Owners: GDD §4.2–4.3/§5.9/§5.11, REQ-SET-121/129/154/159,
BAL-CAT-001/002/006/007/011, ARCH-ID/STATE/SAVE/HASH and task 04.3/06.1.
See also decision 0056 and READY_07 §7.2. These rulings do not claim that the
stores, service topology or full starter settlement already work.

## R-BUILD-DOM-001 — Milestone is the unlock domain

Decision 0056 correctly identified missing publication/binding, but its statement
that 0/1/2/3 was merely plausible overlooks **BAL-CAT-002**, which already explicitly
states M0=0, M1=1, M2=2, M3=3, M4=4. Preserve those values.

Publish protected catalog domain **Milestone**, with exact keys and values:

| Key | ID | GDD display name |
| --- | ---: | --- |
| M0 | 0 | Refuge / Start |
| M1 | 1 | Settled Hearth |
| M2 | 2 | Abundance |
| M3 | 3 | Deep Roots |
| M4 | 4 | Hearth Charter |

`BuildingDefinition.unlock` AND `RecipeDefinition.unlock` hold one ID from
Milestone, not a bitmask, building ID or free-form label. `Start` is a source-table
label mapping to M0, not a sixth catalog key. No published definition may use -1
or an unknown ordinal to mean unlocked. Current building/recipe rows use 0–3;
publish all five milestones now so the domain is complete. No new M4 production
entry is created by publishing its milestone.

`Progress.milestone` uses this same domain and records the highest earned
milestone for presentation. **New explicit mask binding:** bit m in the existing
`World.milestone_mask` and `Progress.unlocked_mask` means milestone m was actually
awarded; both masks agree in a published world. A definition is unlocked exactly
when `(unlocked_mask & (1 << definition.unlock)) != 0`. Active new settlements
start with M0 earned, masks=1 and milestone=0. Bits above 4 are reserved zero.
An absent/unbound Progress store is unavailable, not a fabricated M0 world.

Award each milestone only when its own GDD conditions pass, once, with its rewards
and notice in the same commit. Awards persist when stock/population later falls.
Do not infer other earned bits or repeat their rewards from a higher ordinal;
the GDD does not state an additional predecessor condition. Evaluate eligible
awards deterministically in ascending milestone ID. A sparse earned mask is
legal; `Progress.milestone` is max(set bits), not the authoritative gate.
This preserves complete-condition checks rather than silently granting earlier
unlocks on a numeric comparison. Example: M0+M3 gives mask 9 and highest=3, but
an M1 definition is still locked until M1's own conditions earn bit 1.

Progression owns both masks, reward latches and invalidation of cached job gates.
Do not add a second mutable milestone store. The current UI's highest-ordinal
`>=` gate in `ui_availability.gd` must migrate to earned-bit evidence when real
Progress is bound; record its old fixture assumption and add a sparse-mask test.
Store implementation can proceed before progression implementation; advanced
services/gates remain unavailable until their real owner is integrated.

## R-BUILD-DOM-002 — Publish the full separate Station domain

BAL-CAT-011 already authors all eleven service keys. Compile **Station** by the
existing ascending-ASCII policy, through `catalog.gd` and `catalog_ids.gd`:

| Key | Station ID |
| --- | ---: |
| brewery | 0 |
| composter | 1 |
| dryer | 2 |
| kitchen | 3 |
| mill | 4 |
| nursery | 5 |
| preserver | 6 |
| saltpan | 7 |
| well | 8 |
| workbench | 9 |
| workshop | 10 |

`RecipeDefinition.station` stores this domain, never `BuildingDefinition`.
For example kitchen service=3, exterior kitchen building=14, hall building=12,
and kitchen_bench furniture=5. Numerical coincidences in different domains do
not imply compatibility; a range check cannot detect every wrong-domain integer.
Import by the field's named domain and bind through explicit provider mappings.
All 36 currently tabulated recipes/ancillary conversions name a real station.
The GDD's empty-catalog sentinel -1 remains for unused fields only; it is not a
new Station key or permission for those recipes to run anywhere.

Publish the eleven keys now, independently of whether the recipe runtime exists.
Identity tables belong in the existing catalog owner. Do not create a runtime
Station entity/store merely to hold this enum or a second drifting list of keys.

Provider binding:

- The eleven same-named exterior building definitions provide their corresponding
  Station service only when their actual owning building/service conditions pass.
  Worker capacities and buffers remain the keyed balance §4.1/4.2 values.
- Each eligible kitchen_bench in a valid KITCHEN room provides one kitchen worker
  slot, owned by that room's exterior building. The starter hall's one bench gives
  one slot; do not add hall's catalog slots again or invent two exterior-kitchen
  slots for it. Each 2×1 bench is one furniture instance, not two slots.
- An exterior kitchen supplies its existing two slots. Interior and exterior
  providers satisfy the same service ID through different real target refs.
  Job destination is the chosen bench/station; order owner is its building.
- Other buildings are not automatically recipe Stations because they have worker
  slots. Boathouse assembly, extraction and non-recipe actions retain their owning
  contracts; this ruling adds no boathouse Station or boat inventory item.
- Passive batch capacity is distinct from active worker slots. Inputs, output
  capacity, actual source/target refs, access, occupancy and operational conditions
  remain independent gates. Well/brine extraction still requires its bound physical
  source; a service ID alone supplies neither water nor reachability.

Validate generations and ownership on lookup, and suspend/invalidate dependent
gates on service/room/building changes. A kitchen furniture bit is not proof of a
usable station. Do not silently enable missing services with neutral/default state.

## R-BUILD-DOM-003 — Furniture mask is a presence summary

**New explicit representation:** for a validated FurnitureDefinition ID i,
`furniture_bit(i) = 1 << i`. The existing compiled furniture IDs are unchanged:

| Furniture key | Existing ID / bit position | Bit value |
| --- | ---: | ---: |
| bed | 0 | 1 |
| decoration | 1 | 2 |
| hearth | 2 | 4 |
| interior_door | 3 | 8 |
| interior_partition | 4 | 16 |
| kitchen_bench | 5 | 32 |
| patient_bed | 6 | 64 |
| seat | 7 | 128 |
| shelf | 8 | 256 |

`Room.furniture_mask` is the bitwise OR over **live, committed Furniture rows whose
`room` EntityRef resolves to this exact room generation**. It is structural row
presence, not service availability. Include those rows irrespective of condition,
user assignment, room validity, fuel or access; these have separate service checks.
An uncommitted placement/reservation contributes nothing. If construction uses a
committed Furniture row before completion, its bit records that row's presence
only and must never authorize use before the construction contract allows it.

Empty room=0; known bits mask=511. Reject negative values, bits outside 0–8,
invalid definition IDs and stale/wrong-owner references before publication.
Every valid bit must correspond to at least one matching row, and every matching
row must contribute its bit. Two beds still yield bit value 1; adding/removing
one cannot clear that bit while the other remains. When the final instance is
removed or reassigned, clear it. Reuse of a room slot cannot inherit old bits.

Mask reads do not establish counts, seats, bed capacity, comfort, pantry grams,
heat, route connectivity or operational work slots. Evaluate those from actual
rows and GDD room/service rules. A damaged bed still has a presence bit; whether
it is usable is a separate check. Edge furniture contributes to its explicit
`Furniture.room` owner only; do not fabricate a duplicate instance to set both
adjoining rooms' bits. Shared-edge connectivity follows the actual topology and
can affect both rooms without either room using this mask as its adjacency graph.

Update mask and membership atomically on create/remove/reassign and invalidate
room/service results in the same commit. Recompute from the owning bounded rows
on structural edits, or use an explicitly accounted index; never add a new
per-room nine-counter arena without updating the memory ledger. Do not scan all
furniture per resident per tick. No new authoritative column is needed.

The existing field remains saved and hashed under its owning schema. On load,
recompute expected masks from staged validated furniture references and compare;
refuse mismatch before activating state rather than silently repairing it.
Future furniture keys/bit growth require a versioned catalog/schema decision,
including the signed-int32 limit; never wrap a shift or silently renumber bits.

## R-BUILD-DOM-004 — Resolve the adjacent starter-shelf ambiguity

Decision 0056 also leaves a fourth nearby placement question. Adopt the earlier
READY_07 recommendation explicitly: instantiate all FIVE S cells in the starter
diagram. The kitchen S is kitchen-owned furniture; the other four are pantry-owned.
Only the four shelves in the valid PANTRY room contribute to the named pantry
service: 4 × 50000 = 200000 g. The kitchen shelf does not create an extra pantry
container, add 50000 g to that pantry, or gain an invented industrial buffer.
If later legitimately included in a valid PANTRY room, it follows ordinary shelf
capacity rules. This preserves the diagram and the stated starter capacity.

Both rooms can have the shelf-presence bit 256 without equal shelf counts or
storage services. Existing `inventory.gd` owns containers; do not create a parallel
container store. Capacity removal/reassignment must preserve goods/reservations
through the owning evacuation/refusal contract.

## Catalog, schema and evidence handoff

Compile/protect the new domains through the existing registry. Regenerate
`catalog_ids.json`, record the actual changed digest and byte/row counts, and
retain all existing BuildingDefinition/FurnitureDefinition/RoomType/BuildingState
IDs. Existing saves with the old catalog digest must refuse before mutation unless
an explicit migration exists; no permissive fallback. Do not claim a regenerated
artifact exists from this planning document or invent its digest.

No new packed column or allocation is adopted here. Existing mask/ordinal payload
widths stay unchanged. New immutable domain data belongs in the read-only catalog
budget; measure actual artifact/implementation changes rather than claiming zero
cost or adding already-ledgered Building/Furniture/Room payloads again.

Required acceptance:

1. Exact complete domain mappings, independent of dictionary insertion order;
   protected Milestone refusal on renumber; Start normalized to M0 only at source
   import; invalid unlock/station IDs and misbound keys refused; sibling IDs stable.
2. Every building and recipe unlock validates; every recipe station resolves;
   M0 initial mask=1, M4 valid=4, reserved bits refused, sparse mask gate=exact bit,
   highest ordinal not used as a shortcut, rewards once, state persists on decline.
3. Kitchen Station=3 resolves both an exterior kitchen with two slots and a valid
   hall bench with one; no hall double counting; multiple benches separately bound;
   invalid room/stale refs/blocked access cannot provide ready work; passive slots
   remain independently enforced. Missing topology means that readiness test is
   still open, not that a fabricated reachable flag may pass it.
4. Nine bit vectors; empty=0; bed+hearth+shelf=261; kitchen_bench+hearth+shelf=292;
   all nine=511; duplicate-kind removal; final removal; damaged row; invalid room;
   room slot reuse; reassignment; edge ownership; rollback leaves original mask.
5. Starter has five shelf rows but pantry=200000 g, kitchen owned S distinct;
   shelf capacity and bench slots are computed from real instances, not bit counts.
6. Save/hash/load owner/mask consistency and catalog compatibility when the codec
   exists; otherwise test store/import validation and record save parity as open.

Implement catalog additions first, then packed Building/Furniture/Room storage and
mutation validation, then dependency-ready starter/service/container composition.
Keep progression, topology, complete building lifecycle, heat, gear and expanded
underground engineering as separately evidenced work. These three domain questions
(and the shelf interpretation) must no longer be reported as unanswered, but their
resolution does not claim task 06 or full first-playable completion.

Use the existing agent hierarchy with one writer per file: catalog owner, packed-
store owner, integration lead and independent test/review owners. Update decision
0056 with a dated resolution pointer while preserving its historical evidence.
