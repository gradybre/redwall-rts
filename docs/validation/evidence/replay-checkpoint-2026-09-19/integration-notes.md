# Header implementation intake

The Claude Opus author acknowledged SAVE-REPLAY-R01 v2 and stopped with a complete
structured bundle. The sole target save_header.gd matched its exact input SHA-256.
The raw unified patch failed `git apply --recount --check` at its first hunk.
Every old hunk context matched exactly once in sequence; deterministic replacement
reconstructed only the hunk metadata. No semantic changes were made during intake.
Original and applied patches, public bundle, events and source hashes are retained.

Parent independently owns the adapted existing tests, new header/checkpoint tests,
section1 file-position constants and docs/registry/queue updates. The new full264byte
header vector was independently generated with Python struct from literal offsets;
expected bytes do not derive from the implementation under test.
