# Settlement delivery status — 2026-09-20

The settlement remains under development and has not passed first-playable acceptance. The approved outcome includes the complete settlement experience; tactical battles and the campaign map are outside the current build scope. The immediate priority is to turn the specified starting refuge and isolated simulation systems into an observable player journey.

| Delivery measure | Verified position |
|---|---|
| Accepted loop changes | 35 merged PRs, #140–174 |
| Latest merged regression suite | 4,999 tests; 522,412 assertions |
| Buildings validation | PR #174 merged after both exact-commit CI checks passed |
| Starter refuge | Independent review approved; 35 focused tests, 5,034-test local regression and 26 metadata cases pass; packaging and CI pending |
| First playable | 0 of 12 acceptance cases executed |
| Complete settlement release | In development; no defensible completion percentage or release date yet |

This snapshot distinguishes merged work, local candidate evidence and planned work. The accepted baseline is merge commit `205e56b` (PR #174). Candidate-only evidence is listed separately below.

## Accepted work

35 loop PRs, #140–174, have merged after their required checks. The latest merged build passes 4,999 tests and 522,412 assertions. Movement’s local component validation passed both exact-head CI checks before merging.

This work has reconciled planning and state ownership, repaired several runtime defects, and implemented persistence primitives with explicit contracts, independent reviews and fault tests. Fourteen of the eighteen component owners now have merged local validation implementations. Local component validation does not establish complete-file consistency or authorize world restoration by itself.

Movement is merged. Buildings is merged and accepted within its local-validation scope: 4,999 tests, 522,412 assertions, zero failures; 6 focused tests and 19,242 assertions; 75 functional and one allocation fault unit caught; 77 metadata cases and 693 assertions. Its adapter borrows the 29 saved buffers and preserves valid retired history. [PR #174](https://github.com/gradybre/redwall-rts/pull/174) merged at 14:25 UTC after both checks passed on commit `2aba188`. An initial CI packaging failure exposed an omitted generated audit file; the file is now committed and the specification check passes. This does not complete save/load, live construction or the first-playable settlement.

## Next playable milestone

The next milestone is the authored refuge: 12 residents, 7 completed buildings, 4 hall rooms, 12 beds, 12 seats, 5 shelves, one bench and one hearth, real storage and 24 total tools, then safe-roots designation followed by travel, work and delivery. None of the 12 first-playable acceptance cases has yet been executed end to end.

Independent design review confirmed the starter layout's 31 floor furnishing instances, 33 occupied tiles, 47 walk tiles, eight partition edges and south exit. These are captured in the [preparation contract](starter_structures_preparation_contract.md). The repaired layout module now imports cleanly on the development branch, passes 17 specification checks and passes its small smoke test (1 test, 6 assertions). Independent functional validation has passed; the module is not yet wired into game startup.

The independently authored functional suite passes **35 tests and 3,674 assertions**, including exact layout checks, guarded frozen-reference loading, diagram validation, observable output isolation and deterministic failure/recovery. The full local regression passes **5,034 tests and 526,086 assertions**, with zero failures. The existing 553-object/33-resource shutdown diagnostics remain open. The source-metadata fault campaign passes all **26 cases and 450 assertions**, including 24 deliberate faults and two controls, and is wired into CI.

Independent review approved the test follow-up and found no production correctness, safety or allocation defect. Its small documentation/style notes are being closed during packaging. The full local result covers the reviewed test file; final committed-file identity and exact-commit CI will cover the cosmetic integration edits. This is still a local candidate awaiting PR acceptance. These results validate preparation of the authored layout; they do not establish playable settlement behavior.

This is tile-layout work; measured body passage, runtime geometry, contacts and room validity remain separate. A source-derived goods plan conserves all 20 item quantities in 46 lots: 12 equipped tools plus stored goods, with 179,200 g in the pantry and 1,500,000 g across four stockpiles. It is planning arithmetic, not seeded runtime state.

The immediate sequence is to finish the reviewed compact refuge preparation; close physical topology/contact and profile requirements; bind real goods/equipment and the single inventory authority; integrate movement/work/hauling/needs; then execute FP-01–12 with visual/input evidence. Persistence work proceeds alongside this. Safe replacement of a prior valid world retains its full disk rollback dependency; an empty-world boot cannot be reported as completing that requirement.

The first visible success will be a correctly initialized refuge where the player can inspect beds and stocks, designate safe roots while paused, resume, and watch a resident travel, work, carry and deliver the result. Acceptance also requires cancellation, contested storage, stale targets, blocked routes, needs interruption, deterministic speeds and usable keyboard/trackpad controls. A successful startup alone will not close that milestone.

## Planning, artwork and content

The project has substantial existing specifications, artwork references and content research. The review has preserved that direction and traced implementation contracts back to it. Remaining gaps concern binding those decisions to real state ownership, geometry, transactions and observable behavior, as well as unfinished scenario and family packages.

Creature heights and several building dimensions are already authored. Those numbers should not be reported as missing design decisions. They also do not prove that actual body envelopes fit doors or reach service contacts. A diagnostic using the existing mouse mesh’s actual vertices found that its static pose extends beyond the current navigation footprint anchor; increasing the clearance size cannot fix that offset mismatch. This is a concrete placement-contract issue, not a completed animated-body fit measurement. The starting cohort is six mice, two moles, two otters and two squirrels; only one mouse body has been imported. Inspection of its GLB and the source GLB found no embedded skins, joint weights or animation clips; this is a static mesh, not a completed animated character. The other species, rigs, life stages, equipment, poses and final visual qualification remain substantial production work. Bulk creature authoring has an approved direction, but no new paid asset generation is authorized by this status update.

The literary library contains 12 books, about 1.28 million words, 7,665 extracted records and 1,755 candidates. These are reference and extraction counts, not implemented game-content counts. Eulalia and Salamandastron retain documented source gaps. Scenario authoring, family integration, community producers and related UI still need closure.

## Remaining delivery work

| Area | Current position | Required closure |
|---|---|---|
| Save/load | Structural codecs, streaming and several owner validators are accepted | Remaining owner domains, consistency across saved sections, owner capture/apply adapters, file assembly, disk rollback and continuation |
| Settlement start | Starter requirements and some initialization primitives are specified | Complete starting world, validated replacement of an existing world and coherent initial inventories/buildings/furniture |
| Gameplay | Many isolated systems and tests exist | Connect movement, work, delivery, construction, food production, arrivals and relief into the live simulation |
| Connected movement | Ground primitives and policy work exist; production profiles and broader geometry remain incomplete | Persistent tunnels and underground homes, multi-level excavation, surface swimming/diving and connected climbing/canopy access remain required for the full settlement release |
| Family and community | Rules and helpers exist in parts | Bind producers, permissions, relationships, care and UI; complete integrated scenarios |
| Presentation and assets | Literary sources, supplied references and approved world direction are preserved | Production geometry, rigs, life stages, equipment, poses, interaction and visual qualification |
| Release qualification | Local deterministic tests and CI run | First-playable criteria, integrated playtests, platform/minimum-hardware evidence and outstanding native memory measurements |

The current game boot is not the planned finished starting settlement. Test totals measure regression coverage, not delivery percentage. The existing full-suite shutdown diagnostics of 553 objects and 33 resources remain open. Only one mouse body has been imported; that is not qualification of the complete species and life-stage asset set. The content library also retains the documented Eulalia and Salamandastron source gaps.

There is no current decision required from Brendan to continue the active code and planning work. A credible delivery estimate needs evidence from the first integrated gameplay milestone; the present test totals and merged PR count do not support a percentage-complete claim.

See [the first-playable checklist](first_playable_acceptance.md), [the execution queue](work_queue.json), [component acceptance](component_columns_acceptance.md) and [the resumption record](resumption_2026_09_19/README.md) for the detailed dependencies and evidence. Work is progressing in the foreground loop; no unattended supervisor is claimed.
