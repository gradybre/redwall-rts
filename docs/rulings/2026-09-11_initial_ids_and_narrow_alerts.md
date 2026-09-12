# Rulings — initial persistent IDs and NARROW alerts

2026-09-11 · Astra specification-owner rulings. Design resolved; implementation
and runtime verification remain open. This records no new user aesthetic approval.

## R-INIT-ID-001 — Preserve literal global persistent IDs 1–12

Owners: GDD §4.2 / §5.1, REQ-SET-009, ARCH-ID-001–004, task 04.3.

**Ruling:** the starting residents receive global persistent IDs 1 through 12,
in the existing specified cohort order; Warden Rowan has persistent ID 1.
They are not resident ordinals or display aliases. All entity kinds share the
same monotonically assigned, non-reused positive-int32 sequence.

Task 04.3's reset is a reset BEFORE new-world allocation. It does not require a
second reset inside terrain publication after residents have been allocated.
`EntityDirectory.clear()`'s current location is implementation structure, not
an owning-spec constraint. Refactor the composed initialization boundary.

Required lifecycle:

1. Prepare/stage the generation plan and preflight all implemented collaborators,
   cohort capacity, catalog bindings and necessary resources without changing the
   prior valid world. Preserve the deterministic terrain generation algorithm.
2. Enter the initialization transaction. Reset new-world directory/allocators,
   stores, command/job/child state once, and seed the required RNG streams before
   consumers use them. This is new-world initialization, not save-load behavior.
3. Allocate the twelve resident identities first, in canonical cohort order,
   through the normal directory allocator. Attach/finalize their implemented
   components within the transaction. Do not expose an active partial world.
4. Allocate generated world entities from the same continuing counter (next ID 13
   before any subsequent entity allocation). Terrain publication must not clear
   or reseed the resident-bearing world. Complete remaining implemented startup
   bindings and validate before publishing the active world.
5. Publish together. A refused initialization retains the previous valid world;
   an empty start returns to empty. Preflight expected failures; any remaining
   fallible commit work needs a restoration strategy within existing memory
   contracts. Reset-to-empty alone is insufficient when a valid world preceded it.

The standalone ecology generator can retain its own reset wrapper for isolated
controls, but the composed initializer must use an internal post-reset population
phase that cannot erase the cohort. Do not generate then renumber, skip a reset
across new worlds, introduce per-kind ID counters, force IDs into live rows, or
reserve an arbitrary offset to conceal the problem. No new allocator state or
save schema field is authorized by this ruling.

The current census of 1713 consumed world IDs is diagnostic evidence, not the
starting-resident contract. Keep the derived census test. Replace the explicitly
named divergence test with exact resident IDs 1–12 and Rowan=1. Independently
assert cross-kind uniqueness, no reuse of destroyed IDs, valid references and
counter progression derived from ALL allocation events. If only the same twelve
residents and 1713 world creations occur, the next ID is 1726; if later composition
adds entities, derive the result rather than pinning that illustrative total.

Required evidence: repeated same-seed initialization determinism under the NEW
order; all cohort identities; complete uniqueness/reference audit; failure before
and during composition without partial publication; new-world reset behavior;
existing occupied-settlement refusal; save/load identity preservation when the
codec is available. Regenerate golden hashes affected by changed identity order
explicitly, retaining the old result and reason. Do not claim old and new state
digests match. Source-only generation geometry/census should remain unchanged.

Closing this identity issue does not complete missing relationships, buildings,
beds, gear/inventory composition, topology or the full settlement fixture.

## R-UI-ALERT-001 — Compact summary with complete disclosed details

Owners: UI §1.2/1.3/§7, UI-SET-010/011/012/085/102, UXV-018/032, A08/A11.

**Ruling:** retain the NARROW alerts zone at y=76 and height=48 logical pixels,
with one 44-high card, existing padding/rail and the highest-severity active alert
plus count. Do not grow it over another HUD zone. The compact HUD card is a
separately authored alert SUMMARY, not the full message body squeezed or truncated
into that rectangle. This is an explicit responsive-presentation refinement.

Each notice presentation maps its real condition/error category to a concise,
localized summary with a severity icon AND word, plus a short cause title.
For the reported generation failure, use severity `Error` and title
`Generation failed`; retain the exact detailed reason, validation code and recovery
in the notice record. Do not put an arbitrary long resident name, raw exception,
three-line generation sentence or full recovery instructions into the summary.
The summary must remain truthful to the active condition; do not replace every
cause with a generic `Something happened` message.

At NARROW render the title/severity in one measured line at the prescribed NOTICE
16px typography with its real icon/gaps/rail accounted for. Do not shrink fonts,
ellipsize, substring, crop or silently discard the original notice. Every supported
summary must fit the minimum supported logical viewport at 100/125/150% scaling;
if it fails, author a shorter equivalent category title and retest. Additional
language support requires qualified localized compact titles, not automatic
truncation. Full message/source/recovery content belongs in the expanded view.

Pointer activation or Enter/Space on the card opens UI-SET-012 with that notice
selected and its full details expanded. All original message text, severity,
source, code and applicable recovery controls remain available with wrapping and
vertical scrolling, a reachable close/back control and correct focus return.
Source centering becomes an explicit available action in the expanded entry.
The separate History trigger and N shortcut still open the entire history; neither
acknowledges nor resolves a condition automatically. Opening details follows the
existing workspace/input/pause policies. Critical integrity faults still use their
required stop modal; this card never substitutes for it.

The accessible card name/description exposes severity and the full original
message with an `Open alert details` action, even when hover tooltips are disabled.
A tooltip alone is not a full-message access path. State updates must not steal
focus or generate repeated announcements without a real notice change.

Wide/standard retain their existing layouts when content fits. Their visible-card
limit is a maximum, not a requirement to overlap: if measured full cards do not
fit together, show fewer, or use this same compact-summary/detail interaction.
Never grow each card against the full stack ceiling independently while retaining
fixed row origins. Keep highest-severity ordering and history coverage unchanged.

This qualifies the previous no-truncation rule: authored summary plus guaranteed
full disclosure is allowed for compact HUD notices. Full notice/error/history
content and all costs still obey wrap/scroll, no clipping, no ellipsis and no
font reduction. Do not apply the exception to arbitrary labels or other panels.

Acceptance: exact reported three-line generation refusal preserved and available;
summary inside NARROW card; mouse AND keyboard access to full content/recovery;
correct close/focus return; no unexpected pause/acknowledgment; twenty notices
retained/grouped under existing policy; long source name/code; 100/125/150% scales;
neutral and live captures; empty state only History; two long wide/standard cards
cannot overlap. Unit geometry tests plus actual font/layout/input evidence are
required. Headless test counts alone do not close this visual issue.

## Executor handoff

Implement these independently with disjoint ownership: initialization owner for
world/directory/cohort orchestration and integration tests; UI owner for notice
presentation, measured layout, disclosure and input tests. Keep source allocation
and error content truthful. Update stale code comments and the divergence-test
ledger with this ruling; preserve dated historical evidence. Report actual checks,
remaining failures and precise next steps. This planning change itself edits no
runtime code and claims no new test-suite result.
