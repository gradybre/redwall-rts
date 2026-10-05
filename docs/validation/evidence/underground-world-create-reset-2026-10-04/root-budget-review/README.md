# Independent review of the shared 1152/1156/1158 memory migration

Read-only review of the integration worktree on 2026-10-04. This packet is
separate from the accepted 1160 UI/reset implementation. No engine, foreign
source, shared tool, registry or allocation was changed by the reviewer.

## Finding requiring correction

**MEDIUM — transitive retirement census executes before immutable admission.**
The original `tools/underground_retirement_memory.py` at
`f06437b9ef11cd346e83000d99b3498b37807f871ea7e1ee33bb19566483426c`
pins the 1158 census, then imports it. The imported file executes the 1155
census immediately. Its later `prior()` check obtains the expected 1155 hash
from a mutable, unpinned predecessor manifest. Coordinated producer and
manifest edits therefore replace the accepted counting algorithm without
changing the pinned 1158 file.

The isolated reproduction changes only the copied 1155 result expression
`'total_provisional': provisional_control` to zero and updates its copied
self-declared manifest hash. The wrapper accepts it and reports 72 controls
instead of 5,673. The outer source hash remains unchanged. The actual current
unmodified arithmetic is not incorrect; this is a future source-admission
failure. Root confirmed the finding and is adding immutable checks before
any import.

`reproducer-inputs.json` maps exact archived bytes to non-executable `.txt`
files. The reproducer restores them only to its own temporary directory,
applies the two edits there, and removes that directory afterward. It neither
patches a foreign module nor alters current production accounting.

```sh
python3 -B docs/validation/evidence/underground-world-create-reset-2026-10-04/root-budget-review/reproduce_transitive_gap.py
```

The expected historical result is retained in `reproduced-original-gap.json`.
For a proposed fixed wrapper, use `--wrapper PATH --expect-refusal`; the
unmodified baseline must still succeed, and coordinated drift must refuse.
The fixed producer, entire manifest and every admitted baseline locator must
be checked before importing the outer census or its transitive executable.

## Other reviewed accounting and verification

No other high or medium finding was identified in the reviewed migration.
The current source-derived Profile configuration is 26 rows / 250 boxes / one
source. Profiles use 19,224 paired bytes plus 32,768 controls. Motion/Levels
produce 237,140; original Session adds 1,536 and retirement adds 8,192 once,
for 246,868 of the existing 262,144 reservation. The ordinary Room provider's
additional 1,024 is a separate global charge, including its reviewed 986-byte
control/helper/provisional-native census. It is not a second Profile charge.

The provider now hashes actual current module text, including mutation-test
replacements, rather than trusting cached index metadata. The accepted source
approach wrapper is called with the actual current Motion joint. Its helper
and source terms remain inside existing reservations. No independent maximum
or native allocation claim was silently admitted. The Clock executable pin
update corresponds to its exact source-wire digest change.

The registry capacity artifact changes only four source fingerprints and line
provenance: 70 proof-chain locations and 36 resize-line locations. Numeric
capacity, field, parser and proof facts stay unchanged. Structured differences
are retained in `registry-capacity-delta.json`.

The reviewer independently ran the current 229 memory tests (75.142 seconds),
the actual memory-artifact `--check`, and READY07 arithmetic: all passed. The
16 snapshotted tool/document/manifest inputs stayed unchanged across those
runs. `current-pass-1/` contains exact command lines, raw logs, original input
snapshots and before/after hashes. This reproduced 99,999,806 logical bytes and
194 bytes of global headroom, with runtime qualification false. READY07's 53
allocation rows sum to 91,611,198 payload bytes; the existing reserve is added
once. The rejected two-World total remains rejected.

That initial pass preceded the repair and the 1160 shared-tool composition.
It does not qualify native memory, actual operational Room playback or
whole-client performance. The final narrow acceptance follows below.


## Corrected source and 1160 composition accepted

The reviewer accepted the four exact files in
`repair-pass-1/source-before.json`, unchanged at the end of review. The fixed
retirement wrapper pins the 1155 executable, complete 1158 predecessor manifest
and all six referenced snapshots before any census import. Its four new tests
reject producer drift, coordinated producer/manifest drift, manifest drift and
both original owner snapshot mutations before import. The original copied-tree
reproducer now preserves the correct 5,673-byte baseline and refuses the mutant.

The new UI wrapper pins the accepted 1160 executable and predecessor witnesses,
checks exact current UI/Form text, and substitutes only the already checked
current indexed Host result into the bounded compiler. Two targeted tests check
the unchanged reservation and reject altered UI text even with stale cached
module metadata. All six new tests independently passed in 1.548 seconds.

`check_current_host_frame.py` additionally injects one typed integer local into
an in-memory Host source, retaining its old cached SHA deliberately. The UI
composed Host frame grows from 9 to 17 bytes. This proves current indexed Host
frames survive the wrapper rather than being replaced by disk sources. The
script reproduces the retained result exactly and never writes source files.

The actual combined UI/Host result is 5,995/6,144 controls and 1,882/2,048
helpers inside the same 8,192-byte retirement slice. Global total and internal
Profile joint remain 99,999,806 and 246,868 respectively. No additional reserve
or runtime/native permission is introduced. No high or medium finding remains
in this reviewed source-accounting scope.
