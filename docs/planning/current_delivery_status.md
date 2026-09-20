# Settlement delivery status — 2026-09-20

The settlement remains under development and has not passed first-playable acceptance. The approved outcome includes the complete settlement experience; tactical battles and the campaign map are outside the current build scope.

## Accepted work

34 loop PRs, #140–173, have merged after their required checks. The latest merged build passes 4,993 tests and 503,170 assertions. Movement’s local component validation passed both exact-head CI checks before merging.

This work has reconciled planning and state ownership, repaired several runtime defects, and implemented persistence primitives with explicit contracts, independent reviews and fault tests. Thirteen of the eighteen component owners now have merged local validation implementations. Local component validation does not establish complete-file consistency or authorize world restoration by itself.

Movement is merged. Buildings is locally accepted: 4,999 tests, 522,412 assertions, zero failures; 6 focused tests and 19,242 assertions;75 functional and one allocation fault unit caught;77 metadata cases and 693 assertions. Its adapter borrows the 29 saved buffers and preserves valid retired history. Exact-head CI and merge remain required. This does not complete save/load, live construction or the first-playable settlement.

## Next playable milestone

The next milestone is the authored refuge:12 residents,7 completed buildings,4 hall rooms,12 beds,12 seats,5 shelves,one bench andone hearth, real storage and24 total tools, then safe-roots designation followed by travel, work and delivery. None of the 12 first-playable acceptance cases has yet been executed end to end.

Independent design review confirmed the starter layout's31 floor furnishing instances/33 occupied tiles/47 walk tiles, eight partition edges and south exit, with concrete interface refinements remaining before implementation. This is tile-layout evidence; measured body passage, runtime geometry, contacts and room validity remain separate. A source-derived goods plan conserves all 20 item quantities in 46 lots:12 equipped tools plus stored goods, with 179,200 g in the pantry and 1,500,000 g across four stockpiles. It is planning arithmetic, not seeded runtime state.

The immediate sequence is to finish Buildings acceptance; implement the reviewed compact refuge preparation; close physical topology/contact and profile requirements; bind real goods/equipment and the single inventory authority; integrate movement/work/hauling/needs; then execute FP-01–12 with visual/input evidence. Persistence work proceeds alongside this. Safe replacement of a prior valid world retains its full disk rollback dependency; an empty-world boot cannot be reported as completing that requirement.

## Remaining delivery work

| Area | Current position | Required closure |
|---|---|---|
| Save/load | Structural codecs, streaming and several owner validators are accepted | Remaining owner domains, consistency across saved sections, owner capture/apply adapters, file assembly, disk rollback and continuation |
| Settlement start | Starter requirements and some initialization primitives are specified | Complete starting world, validated replacement of an existing world and coherent initial inventories/buildings/furniture |
| Gameplay | Many isolated systems and tests exist | Connect movement, work, delivery, construction, food production, arrivals and relief into the live simulation |
| Family and community | Rules and helpers exist in parts | Bind producers, permissions, relationships, care and UI; complete integrated scenarios |
| Presentation and assets | Literary sources, supplied references and approved world direction are preserved | Production geometry, rigs, life stages, equipment, poses, interaction and visual qualification |
| Release qualification | Local deterministic tests and CI run | First-playable criteria, integrated playtests, platform/minimum-hardware evidence and outstanding native memory measurements |

The current game boot is not the planned finished starting settlement. Test totals measure regression coverage, not delivery percentage. The existing full-suite shutdown diagnostics of 553 objects and 33 resources remain open. Only one mouse body has been imported; that is not qualification of the complete species and life-stage asset set. The content library also retains the documented Eulalia and Salamandastron source gaps.

See [the first-playable checklist](first_playable_acceptance.md), [the execution queue](work_queue.json), [component acceptance](component_columns_acceptance.md) and [the resumption record](resumption_2026_09_19/README.md) for the detailed dependencies and evidence. Work is progressing in the foreground loop; no unattended supervisor is claimed.
