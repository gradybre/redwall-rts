# ADR1173 — current short-step source publication

Independently accepted source-publication component. Branch `codex/underground-short-step-publication`,
base `912de685b423c5eedd36ee68bc78f18670276cb7`.
Only the leased Catalog, Motion reader/Clock metadata, route-composition identity,
five existing tests, new publisher/tests/artifacts and this evidence change.

## Result and scope

`qualified-step-v4` contains the actual reviewed 29-profile, 271-box, content-3
wire. Its 10,502 bytes are exactly the accepted ADR1168 diagnostic geometry
`830ee531…`; the production admission is the new verified publication, not a
replacement source proof. Row revisions stay 1. IDs 0/1 preserve legacy ground,
2–9 preserve directed travel, 10/11 are the source-qualified finite 232u step at
body yaw49152, 12 is explicit canonical all-yaw ground, and 13–28 are the
unchanged four-by-four WORK block. `profile_id(1, yaw)` still returns legacy1;
`canonical_ground_profile_id()` and `short_step_profile_id()` require explicit
caller selection. The Driver retains exactly54 scalars for0,1,13…28.

The create-only publisher verifies independent receipt `6613e4cf…`, all21
reviewed1168 source pins, the complete537-input unchanged source reconstruction,
all402 actual native inputs and the sampled462 poses /144,144 matrix scalars /
46 images. Eight current consumers executed in that native replay. WorkFace
and Contacts are byte-identical to the accepted v3-frontier consumers and are
recorded separately; neither is claimed to have executed in the native scene.
All ten current cached Scripts are mandatory at runtime, including both source
programs. The old523-pin v3-frontier prerequisite set is reverified through
`lineage-inputs.json`; eight changed historical scripts/tests use explicit
byte-exact snapshots. Those snapshots never replace current consumers.

The unchanged ground compiler emits576 bytes with twelve explicit WALK paces
at the real Movement cap. Six fixed-connector tables remain empty. The actual
Session route composer loads this source into its existing Catalog and empty
graph; it creates no endpoint, actor admission, paid phase or route permission.

The Motion successor is70,936 bytes, SHA
`69fd9011da9b9c1d85e206401ef287943381a24d19322946287234b2dc66850c`.
Every geometry/phase/support/primitive/join word and independent rate/permission
word is preserved. All five stored runtime Profile/variant selectors are -1,
so no oldWORK10…25 selector aliases the new short rows. Only outer/joint/Profile
revision2→3, the complete Profile digest and numerical-provenance digest change.
The old Motion full wire, manifest and every numerical input remain verified.
The Clock changes only its exact wire hash:30-tick treads and45-tick supported
half-turn timing equations are untouched. Its stripped executable hash is
`6a2cd35c7521a37634b59ef046188cb09ec02a66b478519174c29970ce736cb6`.

This is source geometry/current-consumer publication. Actual World/paid next-cell
composition, saved game integration, target-hardware performance and native
memory remain separate. Stair Motion activation still returns `MOTION_SOURCE_ONLY`.
No source, envelope, support, cost, actor cap, rate or global reservation expands.

## Validation

- `python-final.log`:13 publisher tests pass, including actual source/native
  reconstruction, exact unchanged rows, full Motion byte comparison, immutable
  acceptance/consumer hashes, stripped publication, source mutation, output
  refusal and create-only semantics.
- `reproduction-final.json`:all seven generated files rebuild byte-identically.
- `focused-3/`:five actual strict singleton suites,71 tests /16,732 assertions /
  0 failures. All strict/raw errors, warnings, expected/tolerated diagnostics and
  leaks are0. Analyzer0 warnings across10 changed GDScript files. Clean import
  has no raw diagnostic. Source unchanged; project, registry, assets restored.
  No diagnostic registry or production-source override was used.
- `census-tests.log`:11 exact-delta/storage tests pass, including added retained
  field, collection literal, callback, larger hash/decode window, third bank,
  changed rate and missing current consumer.
- `census.json`:paired Profile20,988; unchanged paired Motion141,720; original
  Level2,292 and all control/decode/caller/Session/Retirement reservations coexist
  once. Total248,632 /262,144;13,512 remain inside this existing arena. Both old
  and candidate banks stay counted. Native controls are provisional, unmeasured.
  New mapping helpers retain no fields and add only0/9 numeric frame bytes.

`focused-1` and`focused-2` are retained rejected attempts: their only failures
were old tests using revision3 as an invalid value after the legitimate renewal.
The final tests reject stale2 and preserve complete refused outputs. Early
`inputs-1/2` retained missing/empty historical-input checks; the original536/537
reader was not relaxed. `python-1` retains test temp-path normalization mistakes;
`python-2` is clean. Disk-only native/import inputs were copied from exact accepted
own checkouts with hashes; staging receipts and helper commands are retained.
No native engine rerun was needed; the accepted sampled native oracle was
independently replayed in Python against its exact inputs.

## Reproduction

Use the bundled Python with NumPy:
`/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`.
Run `-B godot/data/underground/mole-worker/test_publish_short_step_profiles.py -v`
after restoring the exact recorded ignored source/native inputs. The publisher
refuses an existing destination; use its `inputs()` to compare a published
artifact without rewriting it. Missing historical imports/raw assets refuse.

Run `python3 -B <this-directory>/census.py` and`test_census.py`.
For actual runtime checks, run `python3 -B <this-directory>/reproduce.py --out
<a fresh directory> --port <an unused port>` from this checkout. The wrapper parks
and restores staged assets, isolates the Godot user directory, imports cleanly,
uses the official strict singleton shard runner and runs the zero-warning analyzer.
Root separately owns the shared memory checker, registry, full-pack reconciliation,
phase fixture pinning and integrated tests. This packet does not edit them.

## Independent acceptance

Construction rehashed all seventeen executable/UID files and eight artifacts,
ran the thirteen publisher tests and eleven census tests, exercised four extra
refusal probes, and rebuilt all seven generated files byte-identically. The
complete 1,015-pin source/native input admission and census reproduced with no
remaining high or medium finding. `independent-review/acceptance.json` is the
byte-exact receipt, SHA-256
`de2e9f1407cb7b40ea9efe8955df43db5117b5837080f7722f6cfa7fe32c6d34`;
the adjacent locator records its original reviewer-owned path.

Review requested the raw editor log in addition to the analyzer JSON.
`analyzer-editor-receipt/` retains the original port-6457 log and a timestamp,
command and source-pin attribution. Its modification time is inside the recorded
focused-3 analyzer command, all fourteen run-source pins still match, and the
existing raw diagnostic/leak scanner reports zero. This was a receipt capture,
not an engine rerun or source correction. The seventeen frozen pins are unchanged.
