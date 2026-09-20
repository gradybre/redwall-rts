# Settlement delivery status — 2026-09-20

The settlement remains under development and has not passed first-playable acceptance. The approved outcome includes the complete settlement experience; tactical battles and the campaign map are outside the current build scope.

## Accepted work

29 loop PRs, #140–168, have merged after their required checks. The latest merged build passes 4,951 tests and 354,744 assertions. Injury’s overflow repair and component validation passed both exact-head CI checks before merging.

This work has reconciled planning and state ownership, repaired several runtime defects, and implemented persistence primitives with explicit contracts, independent reviews and fault tests. Eight of the eighteen component owners now have merged local validation implementations. Local component validation does not establish complete-file consistency or authorize world restoration by itself.

Residents is locally accepted and awaiting exact-head CI: 4,960 tests and 402,166 assertions pass; focused tests pass 9/47,422 with clean shutdown. All48 required code mutations and8 metadata bypasses were detected;27 metadata cases pass. The change preserves legacy capture/restore error order and retained departure history, refuses negative arrival writes and fixes script errors on null capture/restore. Independent source review found no production defect. FieldPolicy is in contract review; its public lifecycle probe passes76 assertions, with no production change yet.

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
