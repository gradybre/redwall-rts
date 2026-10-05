# ADR1190 formatter independent review

Accepted by `ug_furnishing` on 2026-10-05 for the pure metadata-serialization
component. No high or medium finding within that scope. The exact reviewed
formatter and test hashes are in `replay-1/review.json`; both remained unchanged.

I read both complete Python files, ADR1190, and the six actual wire readers.
The Catalog version/count rules, complete lengths, fixed seven input names,
linked revision/digest offsets, Frontier capacity arithmetic, and signed
little-endian digest words agree with those readers and the reserved interface.
Emission contains typed scalar constants at fixed paths and performs no I/O.

Independent execution passed all ten tests. Regeneration matched the retained
2,114-byte sample exactly (`dcce0c84001f6700ea2f926db1288ccb2b7a59f7706ddea35ff35f3e63558962`).
All 18 read inputs matched before and after; the caller packet was unchanged.
The raw test log, original executable snapshots, commands and hashes are retained.

This formatter checks linked header metadata, not all payload-row semantics.
For example, equal ground/catalog pace counts and source headers do not replace
the Catalog reader's pace-row validation. The publisher still must qualify the
actual source bytes, complete reader closure, geometry and paid execution before
it emits the reserved runtime accessor. The Workpieces input used by these tests
is explicitly a serialization fixture. No engine, native proof, actual source
publication, or World activation was performed or accepted here.

Reproduce from this worktree with a fresh output directory:

```sh
python3 -B docs/validation/evidence/underground-entry-owner-composition-2026-10-05/entry-source-constants-review-v1/review.py /Users/brendan/Developer/redwall-rts-codex-ug-integration /path/to/fresh-review-output
```

The command refuses if either frozen executable has changed before import.
