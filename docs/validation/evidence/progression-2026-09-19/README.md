# Progression contract and helper evidence

Astra–Claude foreground loop · 2026-09-19 · base5ea810e (merged PR140).

The full Godot4.7.2 supervised runner passed **4590tests,159439assertions,0failures**
with16new interval tests. All15 static checks passed. Runtime raw log retains
553object/33resource shutdown warnings inherited from the accepted baseline;
the boot process has no such warnings. No first-playable/M4/save/native or
release qualification is implied.

Three distinct subscription-backed Claude Opus5 sessions provided contract review,
authoring and independent code review. All owned processes stopped; exact provider
IDs and input hashes are in worker-ledger.json. Raw result bundles, packets and
progress events are retained. The original v1 contract is retained because the
review findings concern that version. Reviewers executed no tests; Astra ran them.

Astra integration trimmed the author's255-line module to215lines and replaced
formatted error messages (which allocate arrays/strings on refusal) with literal
codes. The final independent reviewer saw that exact production code. Following
review, only the pause fixture's docstring/assertion label changed; no test logic
or implementation changed after the full run. See review-disposition.md for scope.

Reviewer erratum: the pause fixture **does** fold the T observation through
advance_since_into(last+1,...) before asking eligibility. Its actual limitation is
that it exercises a supplied-tuple protocol, not a live paused SimClock. The final
text now makes that boundary explicit. A scalar copied from out.value into a call
that reuses out is safe under GDScript's value semantics, as the reviewer noted.

The reviewer did not receive the registry/architecture source files in its bounded
packet. Both required edits are present and verified by source/contract checks:
category3 stateless registration and the updated ARCH-SYS-020 cadence. Planned
Progress87-byte fields/COLLAPSE bit remain future-owner contracts; current schemas,
packed-state counts and memory totals are unchanged.

PR140's actual green checks and merge commit are recorded separately. The new
helper and planning follow-through are a second change; neither PR finishes the
settlement. Native computer review still requires an unlocked Mac. No unattended
service or schedule was started.
