# Astra Cycle 2 — inventory state, demolition goods and movement measurements

2026-09-14 · Planning loop completed. **Two blocking questions answered; one
movement question partially answered and still open.** No runtime implementation
or art approval is claimed by publishing this package.

## Read these decisions

| Question | Decision | Implementation task |
|---|---|---|
| Canonical inactive/retired inventory | [INV-CANON-R01](../../rulings/2026-09-14_cycle02_inventory_canonicalization.md): normalize unused payloads in the quiescent save/hash copy; preserve live values, generations and used free-stack order. Never clear source attributes during hot retirement. | DIGEST-DETERMINISM |
| Container enumeration / stranded goods | [INV-GOODS-R01](../../rulings/2026-09-14_cycle02_construction_goods.md): Inventory provides a bounded owner query; the real demolition coordinator proves complete affected endpoints and rechecks goods/claims/occupants before changing state. Real hauling precedes demolition. | CONSTRUCTION-GOODS, with explicit containment/evacuation follow-up |
| Movement Q1/Q2 | [MOVE-C2-R01](../../rulings/2026-09-14_cycle02_movement_envelopes.md): retain classes 1–512, measure swept body/gear/load bounds, quantize outward, and prove fit relative to the actual north-west anchor and root offset. **Q2 production profiles remain open.** | MOVE-ENVELOPE-TOOLING and MOVE-PROFILE-AUTHORING; MOVE-ENVELOPES remains gated |

Six advisory questions remain unchanged: §8/§9 primary count, numeric registry
capacities, alert typography, workspace/HUD overlap, tier-2 demolition basis,
and excavation phase ownership/IDs. Cycle 3 should address the UI geometry pair
with the incoming measured evidence, and complete the movement profile authoring
package without guessing unmeasured body dimensions.

## Progress since Cycle 1

The latest inspected merged baseline is PR116,
`127c8e4ce14ef7acab0b2b608abb8b6b92935928`. PR115 moved 38 historical lane reports
out of shared checklists; PR116 reconciled the staged snapshot with master and
transferred Cycle 1's planning work. Both final PR bodies declare no deviations,
surviving mutants or blockers. The document/process changes match their stated
scope: **accepted for planning alignment; no undo requested.** This is not a new
merge authorization.

PR116's [integration manifest](../integration_manifest.json) records content
comparison of the stale ADR0090/0091/0092 copies and the live 0097/0106/0107
versions. It correctly preserves Cycle 1's new decision as **ADR0136**; ADR0135
belongs to lane records on master. The local folder still contains the old
untracked copies and old staged snapshot; their local duplicate-number failure
is **not an unresolved master integration defect**. Do not repeat BASELINE-
INTEGRATION or delete Brendan's local files to make that folder resemble master.

The queue now records BASELINE-INTEGRATION done with PR116's actual merge SHA.
Implementation must begin on the reconciled integration base, not this folder's
old HEAD `3e094e9`. An exact copy of the merged manifest is supplied locally for
readability; no checkout/reset/stage/commit was performed by Astra.

The 17 missing Construction canonical fields remain a real failure in the
reviewed local source and are reproduced by PR116. SAVE-REGISTRY-RECONCILE remains
required. Cycle 1's spawn and WORLD contracts have **not** become implemented
merely because the baseline PR merged.

## Strongest new code finding

A blanket retirement clear is unsafe in the current Inventory algorithm.
`_apply_transfer()` retires the source before `_credit_new_lot()` reads its
attributes. With one available lot slot, the same slot can be reused with a
new generation. The save/hash adapter must not mutate those runtime bytes.

A second public-operation case matters for the merged §7 codec: reserving 250
milli-U on a 1000-milli-U lot, then merging it into a compatible 1000-milli-U
lot, leaves the dead source at quantity 0 / reserved 250; the live destination
correctly holds reserved 250. The live audit passes. Raw serialization followed
by an unconditional `reserved <= quantity` check rejects this reachable state.
The new projection writes dead reserved=0 while retaining the live claim.
External Reservation rows still need their own correct retargeting and checks;
the probe is a store-level test, not proof of the orchestrated claim path.

Generation MAX is also not synonymous with retirement: a slot freed from
MAX−1 is pushed at MAX for its final valid reuse. Prefix membership and occupancy
distinguish free-MAX, live-MAX and retired-MAX. The ruling preserves all three.

## Exact change boundaries

INV-CANON-R01 adopts inventory owner schema 3 and §7 descriptor schema 3, with
the same field layout and zero added/removed canonical records in this delta.
Generation-zero inactive rows accepted by the older loose codec are refused by
the new target: instantiated inventories start every generation at 1. Version,
normalization, registry, compiled declarations, adapters and tests activate
together; active runtime/registry files were not changed in this planning cycle.

INV-GOODS-R01 introduces a read-only scan over existing packed rows. No new
saved reverse index, revision counter, storage policy, instant transfer or ground
pile is authorized. Missing endpoint bindings return a missing-contract refusal,
not a successful empty scan. A container's directory owner and its inventory
handle are different reference domains. Goods under other affected owners and
undelivered capacity reservations cannot disappear from the safety decision.

MOVE-C2-R01 supplies a measurement/placement method, not measured dimensions.
The current +256/+256 root offset can make a wide swept body incompatible with
the north-west clearance square **regardless of how large k becomes**. Negative
translated minima cannot be fixed by merely increasing clearance class. Recentring
routes would need a separate reviewed position/anchor/save contract. All adopted
underground, water and canopy requirements remain; no biological inability is
inferred from missing profiles. DEC-039 height approval and DEC-040/ECON/HAZ
parameters remain inherited inputs, not questions reopened by this cycle.

## Active lanes and ownership

At the PR query snapshot:

- **PR117 / PACKET-EVIDENCE is in review.** It owns the packet generator, shared
  declaration parser/merge integration, generated packet and its tests. This
  cycle updates the queue to reflect those files, and does not edit or regenerate
  its packet. Its proposed QUALIFIED classification for `none — explanation`
  addresses the semantic ambiguity identified in Cycle 1; its reported 67-case
  checks and mutation results are executor evidence, not independently rerun here.
- **PR118 / ART-UI-12-EVIDENCE is in review.** Its report quantifies counter text
  budgets and measures zero alert pixels behind the workspace, with a useful
  workspace-closed control. Synthetic value ladders are correctly identified as
  harness content. This supports prioritizing the two UI geometry questions;
  it grants no visual acceptance. The report names capture/diff scripts deleted
  before commit: preserve those harnesses under a validation-owned path so the
  evidence can be reproduced from repository contents. No art gate was cleared.

Both are still open in the inspected snapshot, not merged completions. PR118's
nonempty deviation declaration remains visible in the preserved PR body.
Its additional control and labeled synthetic values are reasonable evidence
choices; deleting the harness leaves the reproducibility follow-up above. This
is scope feedback, not a gate override or an instruction to merge the PR.

Two merges since Cycle 1 do not trigger another five-merge alignment pass.
The targeted review still confirms narrowed work: the §7 byte codec has no
complete live capture/restore adapter, and a container owner scan alone does not
prove physical containment. Those acceptance gaps are now explicit in the queue.
No additional unrecorded deletion of game scope was established in this review.
The broader missing-release-work matrix remains PLAN-RELEASE-COVERAGE's task.

## Validation and honest limits

**Astra executed:** a focused Godot probe against unchanged local Inventory,
which is byte-identical to PR116: **14 checks, 0 failures, exit 0**. It confirms
reserved-merge residue, final live reservations, live audit, one-slot whole
transfer, generation replacement, item/quality/provenance/recipe and unmerged
age/remainder preservation. The run still emits 14 ObjectDB leaks and three
resources in use at shutdown. Source, final output and unsuccessful preliminary
probe logs are saved alongside this report.

The first probe fixture mistakenly used a rejecting filter mask. It also had
an invalid failure-exit helper that could print success after an assertion.
Both were corrected; the second attempt correctly exited 1 with eight failed
checks. An intermediate age expectation was also wrong: an unmerged transfer
keeps its age; merge rounding is a separate path. The final run is the only
passing probe result. These were diagnostic-harness errors, not production fixes.

**Executor-reported baseline:** PR116 reports **4,336 tests, 152,719 assertions,
zero failures** after importing the clean worktree. That full suite was not
rerun by Astra in Cycle 2 and must not be attributed to the older local snapshot.
PR116 separately reports editor-import shutdown warnings (1464 leaked objects /
7 resources) and test-run warnings (14 / 3). None is a performance measurement.

Cycle 2's independent fixture/check results are in `cycle_02_checks.log`.
They test the specified normalized representation, allocator edge cases, movement
fit arithmetic and handoff wiring; they are not the production save codec.
The local canonical-source comparison still fails on 17 Construction fields;
the local ADR duplicate check still fails on old copies. These failures are
preserved with their correct source scope. No Windows, save-continuation,
movement-runtime, new visual or qualification-floor acceptance was performed.

## Claude handoff

Read this report, then the three linked Cycle 2 rulings and
`cycle_02_inventory_target.json`. Use PR116 or its actual descendant as the code
base. Preserve all local staged/untracked work; BASELINE-INTEGRATION is already
merged. Keep PR117/118 ownership intact. Complete SAVE-REGISTRY-RECONCILE, then
implement INV-CANON-R01's coordinated inventory/§7/digest change; run independent
review and the real continuation tests when the loader exists. Implement the
bounded owner query and direct demolition refusal, then its separate full
containment/real-hauling integration. The new measurement tooling can proceed. MOVE-PROFILE-AUTHORING is proposal
and evidence work only: missing policy/cost values stay explicitly unresolved
until the Q2 ruling. Production movement remains blocked on approved profiles
and measured fit evidence.
Write one dated lane report per lane under `docs/tasks/lanes/<task>/`, with the
exact code base, tests, failures and remaining scope. Do not reopen already
settled rules, invent missing dimensions, grant art approval or spend credits.

Final independent review: the goods ruling retains both its named-rule and inbox
anchors; the checks log exists in this package; profile authoring is explicitly
proposal/evidence-only while Q2 remains unresolved.
