# After UG08 B1 — concrete state, attachment and connector work

2026-10-02. B1 measured 22 real sources and is committed. UG08 remains in progress.
This packet identifies the next implementation ownership boundaries; it does
not authorize missing dimensions, costs, capabilities or new paid assets.

## Existing owners to bind

| Input | Actual owner/API | What the next adapter must retain |
| --- | --- | --- |
| Resident identity, species and life stage | `core/residents.gd`: `ref_of`, `slot_of_ref`, `species_of`, `life_stage_of_ref`, `rig_binding` | Full live resident reference, actual stage and accepted rig binding. No adult fallback for children/elders. |
| Equipped tool/gear | `core/gear.gd`: `owner_of`, `is_equipped`, `item_id_into`, `claim_job_of`, `durability_into`; `core/work.gd` retains real tool/job bindings | Existing InventoryLot reference and generation, resident owner, actual Job claim and item/manufacture identity. Gear's private row index is not a persistent GearRef. |
| Actual carried payload | `core/haul_carry.gd`: `satchel_of`, `carried_lot`, `carry_limit_g_into`; Inventory owns item, quantity and container identity | Real satchel/lot generations, item/quantity variant, current resident carry ceiling. A gram mass does not define a cargo shape. |
| Body and clip application | `demo/cast/demo_actor.gd`: `_apply_clip`, `choose_clip`, `_apply_transform`; staging manifest and source hashes | Final body plus clip remapping, axes/root, animation blend, actual source versions and runtime deformation. Grounded input alone is not the final staged/live character. |
| Existing visual state behavior | `demo/cast/resident_brain.gd`: `_enter_turn`, `_step_turn`, `_locomotion_clip`, `turn_back`, `_walk_out`; actor `choose_clip` | Traceable presentation-state mapping useful for measurement fixtures. Its float timing and radius shortcuts do not become authoritative movement policy. |
| Digging attachment | `demo/tunnel/tunnel_ext.gd`: `pick_fit`; `demo_actor.gd`: `set_tool`, `_in_right_hand`; `demo/props/demo_props.gd`: `drawn_bound`, `fit_of` | Exact prop bytes, right-hand bone, fitted transform and rendered visibility interval. The demo's mole_pick is not yet a declared physical variant of core item `tool`. |
| Carry attachments | `demo_actor.gd`: `_build_load`, `_place_load`, `hold`; `demo/farm/farm_goods.gd`: `hand_fit`; `farm_carry_view.gd`: `harvest_in_hand_into` | Actual inter-hand procedural log or fitted item mesh. Measure the whole changing hand span and both crossfades; do not replace cargo with the demo's height-ratio width heuristic. |
| Spatial work and finish qualification | UG21 sparse space owner/authority, RoomSpace contacts, UG06 `ExcavationContract.SpatialAuthority` | Selected floor, actual dry/support/unfinished state, complete approach/reach, exact world datum, live profile revision and actual worker/job/contact references. |

## Next executable measurement increment

Suggested exclusive files are new `tools/measure_underground_variants.py`, its
test, and `profiles/variants/` evidence. Existing B1 functions can be imported;
any extension of the frozen B1 parser should be separately leased/reviewed.

1. Read the actual staged body plus stripped clip set and its manifest hashes,
   or deterministically assemble that same combination read-only from the
   existing grounded body/clip bytes. Check complete bone-name/parent/transform
   compatibility; do not assume equal node indices or silently drop a track.
2. Bind the existing mole pick and procedural carried log first. Measure all
   prop vertices under the exact current fitted bone/hand transforms. Then bind
   real farm item meshes by `hand_fit`. These can all be measured without a
   new asset purchase or gameplay permission. Record the presentation origin
   of each transform separately from a future approved physical item variant.
3. Capture an explicit seven-state matrix for each measured variant. Existing
   walk/idle/crouch/carry and mole/badger hammer sources provide inputs; they
   do not automatically supply ENTRY, HOLD, TURN, REVERSAL, RETREAT and EXIT
   transitions. Measure the actual clip blends, held props, root yaw and legal
   recovery path. An absent state stays absent, never an alias inserted solely
   to satisfy a schema count.
4. Extend the continuous proof over the *combined* clip/attachment state set.
   Taking the maximum of separate clip radii is insufficient in general for a
   blend that mixes node transforms. Combine each node's translation/scale/
   rotation bounds over the full source set, then compose the hierarchy. Improve
   tightness by using only vertices actually influenced by each joint, while
   retaining every positive influence. Diagnostic samples remain independent.
5. Inspect runtime stoop/tail and exact imported transforms for a proved bound
   and numerical error allowance. If the proof cannot cover them yet, retain
   that exact missing binding; do not promote a sampled margin. The current
   final-asset facing declaration also needs explicit verification: staging
   records `+Z`, while the simulation contract is `-Z` forward.

This increment produces real combined-variant evidence and an auditable
state/attachment mapping. Production profile publication additionally needs
the movement owner's state/cost/support contract and actual Catalog/Gear/Haul
binding; the demo animation-state enum is not that authority.

## Connector authoring that can proceed in parallel

Build a versioned integer parameter-to-fixed-geometry compiler and renderer
for all five families, with no implicit production parameter row. Once a row
is authored, its width/run/rise/landings never change during player placement.
Generate explicit tread/rung/rail/post/landing/opening geometry and the matching
RoomConnectors full envelope/cut/contact tables from the same row. Test material
UV scale, exact boundary closure and all allowed quarter turns against that row.

Earth/timber and stone need actual tread/riser counts and rail/post solids;
ramps need a full continuous slope and landing sweeps; spiral stairs need the
central post, handedness, every tread and under-flight headroom; ladders need
the rung/hand/step-off and hatch-motion sweeps. Existing demo ramp/stair code is
an inspectable visual starting point, not production permission to import its
4m floor spacing, 0.25m risers, 500‰ stair speed or 1250‰ work multiplier.

The approved family catalog does not yet provide numeric standard floor
heights, split offsets, stair sizes, step/reach limits, support spans, safe loads
or connector fixture recipes. Those remain explicit owner authoring decisions.
Measured anatomy/gear and actual mesh geometry can close measurement inputs;
they cannot derive material economy, safe load or movement policy by themselves.
No new innate species permission is needed for ordinary completed dry supported
tunnel walking: MOVE-C3 already settles that. Actual body/stage/posture/grip/load
fit still must be proven. Ladder protection and carried-load requirements need
their declared connection/profile binding, not an exemption for a named species.

## Production publication and tests

The next core profile owner should consume accepted immutable integer variant
records keyed by profile revision, species/stage/rig and real item/load variant.
It must revalidate the live resident, gear lot/claim and satchel/lot before
entry, changed load, turn/reversal and work contact. Swapping a carried item or
reusing a lot slot invalidates the old fit. No duplicate inventory or gear state
is created. Missing profiles are an authoring refusal, not a biological ban.

Required integration fixtures include a tool tip outside an otherwise fitting
body; cargo fitting straight travel but failing a turn; lowered crouch body
with an unchanged carried load; interrupted turn/retreat; stale/reused worker,
gear and cargo refs; a newly blocked landing; and exact selected-floor contact.
Use actual Residents/Gear/Inventory/Haul stores, then UG21/UG06, and validate
save/reload and source/profile revision invalidation. Keep geometric fit,
economic authorization and presentation coverage independently reported.
