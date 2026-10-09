# 1160 — New settlement reset result, candidate1

Independently accepted as a bounded UI/reset component on
`codex/underground-world-create-reset`, base
`721038a4198df17d9bfab6c9994cc9916f875447`. Ownership is the two existing UI
modules and their two existing tests only, plus this evidence/ADR1160. Source
and output manifests enumerate the exact seven executable inputs and retained
results. `source.diff` is the complete runtime/test delta against that base.

## What is proved

The actual UI validates its form, abandons only through the actual original-live
host API, and only then borrows Content and stages a replacement. One guard
spans the complete Create attempt. The typed callback writes CLEARED, RETAINED
or STOPPED; an unwritten packet, unknown enum, contradictory cause or a boolean
return does not continue generation. Reset's original error is copied before
abandonment can replace the host's last refusal. RETAINED alone drops the new
plan. STOPPED preserves the exact request and Scope.

Later colony/remount cleanup uses that same actual host adapter. Confirmed
clearing alone withdraws the UI map; a refused cleanup retains the stage code
and separate cleanup code. Player text no longer claims every refusal emptied
the settlement or recommends blind Create retry after a stopped reset.
Standalone `create_into` is unchanged byte-for-byte, enforced by the census.

Actual tests cover the published source image/catalog, generated host and UI,
busy cold lease refusal plus successful retry/remount, a previously prepared
Scope with a staged request, invalid form before abandonment, source substitution
that refuses before new preflight, nested Create through a real placement read,
and real late cleanup/remount refusal. The partial-clear test overrides only
its own host's clear to interrupt it after Residents; the actual host/kernel
empty-owner proof then refuses. It checks the original Scope/request and error,
no replacement cohort, stopped tick/abandon and releases only test references.
That is an adverse interruption, never a positive authority/source override.
The existing UI cohort identity, Transform and inventory/economy tests remain.

## Results and restoration

- UiWorldSession: 21 tests / 119 assertions / zero failures.
- UIManager: 56 tests / 429 assertions / zero failures.
- Total: 77 / 548 / zero; one existing expected null-HUD diagnostic, zero
  unexpected/raw warnings/errors, tolerated diagnostics or leaks.
- Changed-file language-server analysis: zero findings across four files.
- Twelve source/census mutants pass. `census.json` includes the complete
  composed caller/static-retirement graph and the separate provisional terms.

Candidate1 uses the four exactly pinned, independently accepted publication-v3
files from root's integration worktree. The original v2 Catalog and absence of
v3 files are restored afterward; no current source consumer is substituted.
Only two exact missing core classifications are temporarily appended to the
registry. These test prerequisites are declared in
`candidate-1/diagnostic-prerequisites.json` and
`registry-test-only-append.md`; they are not shipped edits in this commit.
Original/current/restored source manifests agree, the four prerequisite source
files remain unchanged in the root worktree, and project, registry, assets,
import/UID sidecars and HEAD are all restored/unchanged. Clean import findings
are empty. Raw command output and official singleton shard identities are
retained under `candidate-1/`.

Reproduce while the exact prerequisite source files remain available:

```sh
python3 docs/validation/evidence/underground-world-create-reset-2026-10-04/reproduce.py \
  --out /tmp/ug1160-new-evidence \
  --prerequisite-root /Users/brendan/Developer/redwall-rts-codex-ug-integration
python3 -B docs/validation/evidence/underground-world-create-reset-2026-10-04/test_census.py -v
python3 -B docs/validation/evidence/underground-world-create-reset-2026-10-04/census.py \
  --out /tmp/ug1160-new-census.json
```

The wrapper deliberately refuses another publication hash or a now-permanent
retirement registry stanza: a future integrated rerun must record its new exact
source context, rather than silently pretending it executed this composition.

## Storage and limits

Additional retained guard/report fields are 18 scalar/name bytes; the one cold
ResetOutcome is 16 bytes with a provisional 256-byte object/header term. Three
new integer constants and one refusal name add 32 logical bytes. Its three
constructor sites have a maximum of one simultaneous packet, including the
later cleanup path. The accepted1158 controls plus this delta are 5,995/6,144;
full selected caller/static helper maxima are 186 scalar/name bytes and 45
reference values, giving 1,882/2,048 with the existing expression allowance.
Original Session1,536 and retirement8,192 are each charged once inside the
unchanged PROFILE_BYTES262,144 ceiling (prior joint246,868 unchanged).

The 32-byte reference, 256-byte packet/header and inherited native/symbol
allowances are provisional, not measured native allocation. Existing private UI
catalog, World preparation, colony/economy and bounded HUD notice lifetimes
remain in their original owner/presentation scopes. No packed arena, gameplay
clock, source certificate, Room constructor or shared registry/tool changes are
introduced. This selected headless component run is not full-demo, native UI,
operational Room, paid work, renderer or whole-client performance acceptance.

## Independent review

Geometry accepted the exact seven executable pins and 30 output pins, reviewed
the four-file runtime/test delta, and independently passed all twelve census
tests with the same 5,995/6,144 controls and 1,882/2,048 helper totals. No high
or medium finding remained. Review commit
`b9f90b39be8986349ee512890fe834c69c906984` is copied with provenance under
`independent-review/`. No engine run was duplicated for that review. The
component, native-memory and gameplay limits above remain unchanged.
