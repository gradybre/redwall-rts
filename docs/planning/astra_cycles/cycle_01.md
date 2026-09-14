# Astra Cycle 1 — rulings, alignment audit and executor handoff

2026-09-14 · On-demand planning cycle for `settlement_rules_v2`.
**Two planning blockers answered; runtime implementation remains with Claude.**

Read this before older STATUS/review-packet summaries. The reviewed working folder
is `/Users/brendan/Developer/redwall-rts`. Existing staged and untracked work was
preserved. This cycle does not authorize new paid generation or grant visual
acceptance. It does not commit, push, merge, or start the executor's automation.

## Decisions and priority order

| Rank | Blocking question | Cycle 1 outcome and reason |
|---|---|---|
| 1 | Resident spawn positions / private pose scaffold | **Answered: INIT-POSE-R01.** Compose one simulation Transform store and place the initial twelve by persistent ID on the hall's south apron. This releases truthful positions, renderer ownership, and eventual save/movement integration; removes a planned 3,151,872-byte duplicate after implementation. |
| 2 | WORLD section's seven missing encoders | **Answered: R-WORLD-S1-001.** Persist all nine owners, with explicit schemas, shapes, validation and framing. Correct three deposit scratch fields rather than fossilize them into saves. |
| 3 | Retired inventory bytes / canonical digest | **Open, next cycle priority.** Reconcile canonical inactive bytes with generations, retirement and allocator ordering. Identical live entities alone do not imply identical future state. The queue no longer prejudges blanking or row omission. |
| 4 | Inventory containers by owner | **Open.** Blocks the stored-goods half of destructive-edit safety. Keep REQ-SET-128 in full; move the dependency off the already merged store to `CONSTRUCTION-GOODS`. |
| 5 | MOVE-G01 measured envelopes and modes | **Open.** Broad release scope remains adopted. Rank reflects immediate dispatch dependencies, not permission to reduce connected movement. Existing policy/mode rulings must be reconciled before requesting duplicate decisions. |

The first-cycle instruction explicitly limits this pass to two thorough answers.
Six advisory questions remain. Completed questions are preserved verbatim in
`docs/rulings/requests/open_items.json` under `answered`, with ruling links.

Read the complete contracts:

- [Initial resident placement and Transform ownership](../../rulings/2026-09-14_initial_resident_positions.md).
- [WORLD owners and exact framing](../../rulings/2026-09-14_world_section_owner_encoders.md).
- [Machine-readable WORLD target](cycle_01_world_schema.json).

The target schema is an implementation contract, **not a replacement for the
currently active canonical registry**. Runtime code, classification, registry,
version/digest producers and corresponding fixtures must migrate atomically on
the reconciled implementation base.

## Evidence and the mixed-snapshot problem

The local branch is `docs/executor-followup-rulings`; HEAD was
`3e094e927c822056b51953aac4168b77acdee814`. It has hundreds of staged changes
containing code much newer than HEAD. Cached `origin/master` was
`b37cf82f50e53fb77f60ef8adb707bbe660bf78c` (PR #104). These are distinct sources.
For example, §7/§12 codecs are merged remotely but absent from this working
snapshot. The test result below applies to the **working files**, not a clean
checkout of that integration commit. `cycle_01_evidence.json` pins source hashes.

Actual checks run by Astra on the available Mac:

| Check | Actual result |
|---|---|
| `./tools/run_tests.sh` | Exit 0; **4,238 tests, 142,421 assertions, 0 failures**; Godot 4.7.2 editor binary. **14 ObjectDB instances leaked; 3 resources still in use at exit.** |
| `python3 -B docs/validation/state_registry_coverage.py` | PASS: 52 modules, 350 rows, 681 packed columns. |
| `python3 -B docs/validation/validate_save_registry_handoff.py --source-root .` | **FAIL:** 17 Construction packed state fields exist in the classification registry/code but are missing from the canonical registry. Its 31 independent primitive fixtures pass before the source comparison fails. |
| `python3 -B docs/validation/decision_numbers.py` | **FAIL before this cycle's changes:** duplicate 0090, 0091 and 0092 records, three pairs. Existing untracked historical copies were preserved. |
| Queue validation and inbox rendering check | PASS on the incoming 15-task queue; post-edit results are recorded in `cycle_01_checks.log`. |

The canonical JSON currently reports 582 records and 536 persisted packed source
fields. The inbox's 590/501 numbers are a historical observation, not the
current census. The WORLD scratch correction subtracts three from that artifact;
the missing Construction fields and any later integration changes must be
reconciled separately. **579/533 are not final integrated registry totals.**

The full Godot baseline is preserved as `cycle_01_baseline.log`. No new
performance measurement, release export, Windows qualification, movement gate
closure or full save/load parity was performed. Planning checks cannot supply
any of those results.

## Merged deviations and surviving mutants

A read-only GitHub query captured **103 merged PR records** in the UTC date
filter `merged:2026-09-10..2026-09-14`, using limit 200 (not truncated). The
packet's September 10–13 New York window contains 102 of those; one UTC record
is September 9 locally. Final PR bodies and merge SHAs are preserved in
`cycle_01_merged_prs.json`.

Only nine records contain all three exact declaration blocks; 94 lack all three.
Missing declarations are **missing evidence**, not approved exceptions or a
retroactive finding that older work violated a then-nonexistent gate. No supplied
final PR body declares a nonempty `BLOCKED` block. The two substantive final
exceptions are:

- **PR #104, DEVIATIONS — acceptable.** The section 12 record-major format follows
  SAVE-LAYOUT-R01's explicit schema-2/64-byte economic records/SCHQ0001 exception.
  The lane correctly rejected a conflicting column-major brief. No undo is
  required. The PR also documents an arena-base restore limitation: capture
  refusing a state it cannot restore is honest containment, but the missing
  command payload-arena restore path remains required release work.
- **PR #112, SURVIVED_MUTANTS — acceptable only for its additive store scope.**
  The current public writers derive `_refund_policy` through `_policy_for()`;
  the redundant comparison is unreachable through that API. READY is entered
  with all bill lines complete (or an empty bill), so the second guard is
  equivalent for current reachable states. Preserve both guards. When restore
  can supply rows, malformed policy/READY-plus-missing-material fixtures must
  exercise them. This is not mutation coverage for a future decoder or complete
  construction integration. Do not delete guards to improve a score.

PRs #103/#104 use `SURVIVED_MUTANTS: none — ...` to describe initially surviving
mutants subsequently killed. Those explanations are not final survivors. The
existing parser treats them as nonempty; that needs a declared grammar and
tests, not a heuristic that silently discards arbitrary text after “none”.

The old packet's “None in this window” was unsupported as a PR audit: it read
local HEAD commit bodies, omitted squash results via `--merges`, and lacked the
later merged work. All 50 PRs it listed have no exact final declaration blocks;
49 additional in-window PRs reachable from cached master were absent (40
one-parent results plus nine later two-parent merges). Three other in-window
PRs are not reachable from that cached ref. The generator now labels its local
commit-only evidence limit and links this cycle; `PACKET-EVIDENCE` owns the full
ref/pagination/final-PR-body correction. No gate was bypassed by this review.

## Alignment pass: what green local tests do not establish

1. **Bulk adapters are narrower than the queue title.** PR #111 covers Needs,
   Residents and Jobs, not every store. The title and dependency claim are fixed.
   §4/§5 codecs and other owner adapters remain separate work.
2. **Residents render, but not with authoritative roots or correct production
   species appearance.** PR #109 is useful MultiMesh infrastructure. The existing
   scene displays one untextured bind-pose mouse mesh across the cohort, with
   private poses. INIT-POSE-R01 fixes ownership/placement only; species/material/
   rig/facing validation remains a separate presentation lane.
3. **The construction store is not task 06.1 complete.** No initial building,
   room, furniture or project exists; no command-to-job-to-work path completes a
   building. Stored-goods refusal and upgraded demolition economics remain open.
   The store's own tests honestly pin the empty starter state.
4. **EventSchedule is storage, not an event system or §11 save body.** Its kind
   and argument semantics, producers, consumers, codec and composition remain
   missing. A schema assertion cannot establish those behaviors.
5. **Alert fitting is narrower than usable responsive UI.** Existing captures
   show the specification's 44px/two-full-card premise is unreachable with the
   current font/padding; a workspace occludes alerts at the supported floor.
   These are specification questions still in the inbox, not silently completed
   UX acceptance. Counter clipping and NARROW dock/minimap overlap need tracked
   corrections even though they predate that lane.

**Unrecorded drops:** no deliberate deletion of a gameplay requirement was
established in the inspected scope. Most narrowed runtime work is explicitly
recorded as incomplete. A concrete unrecorded schema omission *was* found: the
17 Construction fields missing from the canonical artifact despite classification
as persistent state. That must be repaired, not accepted as an exclusion.

Work absent from the original 15-task dispatch queue includes the full save
dependency matrix (remaining codecs/adapters/header digest producers, section
12 payload-arena restore, orchestrator), initial building/furniture/stock
composition, construction command/worker/hauling execution, event semantics and
composition, production species rendering, responsive UI corrections and clean
shutdown investigation. `PLAN-SAVE-COVERAGE` and `PLAN-RELEASE-COVERAGE` must
materialize bounded, owned implementation tasks for these before their planning
tasks close. The existing release roadmap remains authoritative; queue entries
do not replace or shrink it.

Additional source gap: `farming._tile_orchard_row` has allocation, clear and
reader operations but no producer in the inspected tree. Preserve its declared
state; restoring arbitrary “corrected” orchard links would invent history.
Track and implement the owning inverse-link producer before claiming complete
orchard restore consistency.

## Visual review

DEC-036 authorizes direct supplied-image/reference use, including IMG-25.
DEC-037/038 own the grounded, rounded, expressive 3D direction; the approved
concept is not a runtime screenshot. Combine literary atmosphere, supplied
anatomy images and modern RTS readability; do not impose the UI watercolor
illustration style on all world materials.

DEC-039 **exists in `setting_decisions.md`** and approves the height anchors:
mouse 1.00 m, mole 0.90 m, squirrel **1.15 m**, otter 1.49 m, badger 2.55 m
(integer heights 1024/922/1178/1526/2611). The five-species elevation capture is
a hand-authored box comparison. It demonstrates scale; it does not demonstrate
recognizable finished anatomy, appealing materials, equipment fit or traversal
clearance. The white mouse-only runtime crowd likewise misses the approved
world-art target even while proving that instances draw.

The reviewed UI captures show welcome material/illustration direction, but the
roster-over-alert and clipped-counter examples fail the intended readable shell.
ART-UI-12 remains pending. There is no newly granted visual verdict this cycle.

The approval file's pending ART-PROPORTION entry describes creation of evidence
that partly exists and overlaps the narrower DEC-039 height approval. Separate
free evidence preparation from post-approval verification in the queue. Preserve
Brendan's actual recorded height approval without broadening it into full body,
contact, rig or paid-generation approval. `art_approvals.json` remains untouched;
no credits are authorized or spent. Further evidence can be prepared without
making the author the final visual approver.

## Exact executor sequence

1. **BASELINE-INTEGRATION:** reconcile a fresh integration checkout with the
   reviewed staged snapshot without discarding or mass-committing Brendan's
   work. Record the real base, source hashes and which local planning artifacts
   need transfer. Resolve the duplicate ADR histories by comparing contents and
   updating links, not deleting unexplained copies. Record shutdown warnings.
   Finish only when there is a precise shared baseline for subsequent lanes.
2. Dispatch **RENDER-SPAWN** and **SAVE-REGISTRY-RECONCILE** with separate owned
   files. The latter registers missing Construction state under REG-R01 and
   restores the source-membership check; it must preserve the S1 scratch change
   for the subsequent atomic S1 implementation unless integrated together under
   one owned lane.
3. **SAVE-S1-OWNERS** applies R-WORLD-S1-001, including its targeted schema/
   classification/version/digest/test migration. Capture and restore adapters
   must be validated, not just generic wrapper serialization.
4. **PLAN-SAVE-COVERAGE** publishes every remaining save prerequisite and inserts
   its bounded tasks into the queue. `SAVE-CAPTURE` depends on those tasks, the
   digest ruling, S1 and authoritative spawn integration; do not mark the planning
   task done while this broad umbrella could dispatch with missing bodies.
5. **PLAN-RELEASE-COVERAGE** fills the other absent release work from tasks 04–10.
   Keep independent work flowing while three blocking rulings and six advisory
   questions remain. Cycle 2 should first resolve retired-row canonicalization
   and stored-goods enumeration; inspect any new severe blockers before applying
   that order mechanically.

The queue is updated from verified merge metadata: eight review tasks are done
**for their documented merged slices**, not for full owning requirements. New
follow-ups carry the remaining acceptance. This cycle does not dispatch them.

Use the repository subagent hierarchy: plan-parser/read-only Sonnet for bounded
dependency extraction; game-coder/inherited capable model for implementation;
test-runner/Haiku for exact command execution; user-qa and code-reviewer/Sonnet
for independent UX and code checks; escalate difficult state/transaction proofs
to the lead. One owner per file; no concurrent mutation harnesses. Git-manager
handles authorized release operations only after checks, preserving unrelated
work. Astra used a high-reasoning architectural audit and two smaller bounded
process/visual audits in this cycle; no agent granted its own art approval.

## Copyable instruction for Claude

Read `docs/planning/astra_cycles/cycle_01.md` first, then both linked 2026-09-14
rulings and `cycle_01_world_schema.json`. Follow the updated work queue. Start
with BASELINE-INTEGRATION: the planner's tested working files, Git HEAD and
merged master are different snapshots, and the canonical source check currently
misses 17 Construction fields. Preserve all staged/untracked work. Implement
INIT-POSE-R01 and R-WORLD-S1-001 under their explicit file ownership and acceptance
tests. The two inbox questions are answered; implementation, full saves, movement
gates and art acceptance are not complete. Report actual tests and unresolved
dependencies back into the repository. Do not treat this package as approval to
spend asset credits.
