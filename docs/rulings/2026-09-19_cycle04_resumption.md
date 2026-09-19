# Cycle 4 — resume the settlement, close the current questions

2026-09-19 · Astra · Version 1 · Baseline `47a4da2`.

Authority: Brendan's current request to review the established project, finish
planning gaps and take development end to end; existing continuous-development
authorization in ADR 0129. This is continuation of the settlement scope, not
authorization for battle/campaign layers, expenses or unseen art approval.

## REG-C4-R01 — bounded addition in capacity proofs

The capacity resolver may parse unsigned decimal literals, local constants,
explicit preload-qualified constants, multiplication and addition. Multiplication
binds before addition; both associate left to right. The grammar is
`sum := product ('+' product)*; product := term ('*' term)*` using the existing
term grammar. Reject empty terms, unary signs, parentheses, subtraction, division,
calls, indexing and every other expression. Do not use `eval` or execute GDScript.

Check every intermediate result against signed int64, including nested constant
substitutions; an overflowing intermediate cannot be rescued by a later zero.
Preserve the depth bound, preload ownership, proof chain, exact resize binding,
and equality-versus-maximum distinction. Quarantine cycles and unknown constants.
This changes only the proof grammar, not a store, capacity, save schema or memory
allocation. Regenerate the sidecar from source; do not replace its claims with
guessed values. Test precedence, nested aliases, overflow, malformed expressions,
cycles, forbidden syntax, and the two orchard link capacities.

The read-only sidecar schema advances to 2 because its registry digest is now
correctly named `registry_canonical_json_sha256`. This hashes canonical JSON,
not literal file bytes. No active registry or save-schema version changes.

## BUILD-C4-R01 — completed upgrades count in demolition

For REQ-SET-127, an upgraded building's original material costs are the sum of
the recorded paid base package and each **completed** paid upgrade package
through its current tier (BAL-SAFE-013). Catalog rows define admission costs;
demolition reads the committed payment ledger, never reprices historic work
from the current catalog. Demolition work is one quarter of that same completed construction WU
sum. Calculate each item's total in milli-U, then floor its 50% refund once.
Do not refund furnishings through building costs; each remains a separately
owned item/instance. An in-progress upgrade settles through its cancellation/WIP
contract first and is not counted as completed capital.

Snapshot the eligible completed tier and catalog/ruleset identity when demolition
is admitted. The building cannot simultaneously upgrade and demolish. Evacuate
occupants and all physical goods before demolition work, preserve the last exit,
and reserve legal output capacity before the final atomic refund/removal. Blocked
evacuation never destroys occupants or inventory. Retry cannot issue another
refund or charge more completed work. A synthetic tier-2 fixture must derive its
expectation from distinct base/upgrade entries and demonstrate that cancelling
an incomplete upgrade does not earn both its refund and a demolition refund.

This is a newly authored economic interpretation, not a claim about source code.
The current base-only implementation remains unaccepted for upgraded demolition
until repaired and the owning ruleset/catalog/save identity is versioned under
REQ-SET-001. Ordinary tier-1 behavior remains the inherited formula.

## ECON-C4-R01 — excavation owns its physical phase

ECON-003 already explicitly says to compile the phase IDs under ASCII-domain
rules. Use a compiled `EXCAVATION_SITE_PHASE` domain, not a protected handwritten
numeric enum and not new values of `BuildingState` or Construction's lifecycle.
Keys in ASCII order are BACKFILLED, BRACED, BRACING, CLOSING, CUTTING, FINISHING,
OPEN_UNFINISHED, SOLID, SUPPORTED_VOID. Never infer transition order from IDs.

The future `excavation` store owns one phase per physical site/quantum and its
physical identity, origin, funded-input/WIP, installed support and commit state.
The existing Construction store owns each work project's lifecycle; it does not
gain a second physical phase column. One semantic site transition may use one
whole construction project. Completion retries spend no additional WU, XP,
durability or inputs. The exact transition graph remains ECON-003.

G02 owns the packed capacity, allocator, byte widths, peak-memory proof and
schema adoption before a production store is allocated. Add the compiled domain
through catalog generation and version/hash changes in that same reviewed packet;
do not publish an orphan domain as evidence that excavation exists. No spatial
capacity or underground depth is supplied by this ruling.

## UI-C4-R01 — visibility and input describe the same tree

A false contextual Gate means absent from drawing, input, focus and accessible
navigation. A true Gate with an unavailable feature means a visible unavailable
control with the existing concise explanation. An unmet milestone remains locked
in catalogs and absent from quick commands, as already specified. Missing
implementation is not a reason for an opaque visible panel to pass clicks through.

WORKSPACE means an open workspace, BACK means a reachable open workspace back
action, DETAIL and DETAIL_TABS mean an open valid selection detail, and PIN's
context follows the actual detail action. Update the contextual gate state when
opening, closing, changing selection and rebuilding layout; do not independently
reconstruct a different visibility state for hit testing. Shared structural
containers may be retained internally, but a closed context has no visible,
focusable or hit-testable descendant. Parent visibility also applies.

Register every actually visible consuming Control's rectangle using its actual
mouse filter. Decorative IGNORE regions remain nonconsuming. Also assert the
invariant between visible controls and their gate state so registration cannot
conceal erroneous drawing. Preserve ordinary workspace coexistence, compact
workspace scrims and true modal focus semantics from UI-C3-R01.

Regression cases: open and close roster; select and deselect a resident; Back;
detail tabs and name action; all at 1280×720 100/125/150% and 1920×1080 100%.
An opaque panel centre must not resolve WORLD; after closing, its former
uncovered centre must resolve WORLD. Exercise at least one actual engine input
path and prove no world command is queued through a panel. A geometry-only
assertion is useful but is not that end-to-end input evidence. Screenshots are
functional/structural evidence, not Brendan's ART-UI-12 acceptance.

## MOVE-C4-R01 — correct the question before answering it

Q2-34 and Q2-35 are already answered by MOVE-C3-R01 §§3–4,7 and are explicitly
marked answered in the merged profile authoring document. Retain those answers:
declarative profiles, no movement-learning subsystem; resident ceilings retained
with separately authored tighter mode limits. Do not reopen them or add skill
bits. Q2-32/33 also retain the Cycle 3 entry/recovery and elder rulings.

Q2-31 still needs source-informed ADULT/ELDER species permission authoring for
water and unprotected climbing. A categorical permission is not measured fit or
production readiness. The 288-row profile register remains the exhaustive owner
for species × stage × mode; missing profiles fail explicitly, with no adult or
other-species fallback. No unsupported flight, learned swimming or child hazard
entry is introduced by this continuation.

DEC-039 approves five height anchors including squirrel 1178u. Do not tell Brendan
those heights still await approval. It does not approve torso/gear/pose envelopes,
landmark ratios or final models. The still-pending ART-PROPORTION record is broader
than that approval. Leave the human-owned approval file intact and describe the
remaining evidence precisely. MOVE-C3-R01 §6 explicitly permits separately
qualified procedural/static geometry; absence of final rendering art is not a
blanket ban on simulation work. No proxy is automatically a measured production
profile and no height may stand in for a swept envelope.

## INIT-C4-R01 — the next product milestone

The first playable settlement contains every REQ-SET-009 starter instance and
inventory source, real needs services, and the command→travel→work→delivery loop
in FP-01–12. Follow [the implementation package](../planning/resumption_2026_09_19/starter_settlement.md).
Persistence work proceeds in independent files, but a codec count must no longer
stand in for progress toward a playable colony. The complete settlement release
still includes all adopted connected spaces, families, scenario/premise families,
food systems, community/progression, save/replay and presentation qualification.

No current test count closes first-playable, full-release, visual-acceptance,
Windows or minimum-hardware performance gates by implication.
