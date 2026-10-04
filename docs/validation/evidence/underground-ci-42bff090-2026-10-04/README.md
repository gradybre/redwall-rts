# CI checkpoint42bff090 — 2026-10-04

[Run37211546342](https://github.com/gradybre/redwall-rts/actions/runs/37211546342)
passed all14 jobs at exact commit42bff0909dd98e1577375160cc932705cf8cd229.
Created15:03:01Z; completed15:15:58Z:12 minutes57 seconds. The slowest suite
shard took640 seconds (its job732 seconds); the analyzer job took756 seconds.

The unchanged shard verifier, replayed with this commit's actual389-file corpus,
proves every file executed exactly once across8 shards. Aggregate:10,910 tests,
1,002,786 assertions,0 failures;0 unexpected errors,0 unexpected warnings,
272 expected diagnostics,353 tolerated notices,0 leaked objects,0 leaked resources.
The analyzer's actual line is `0 GDScript warning(s) in 0 of 1213 file(s)`.

`merged/` retains every original manifest, raw shard log and JSON report.
`aggregate.json` is recomputed by `verify.py`, which restores the exact tested
suite files into a temporary read-only verification corpus and validates reports
against raw logs. `run.log.gz` is the lossless complete GitHub log;
`log-archive.json` records both compressed and uncompressed SHA256 values.
`run.json` preserves job and commit identity.

No no-argument local full run exists at this exact head. `baseline_matches:false`
is intentional; this packet does not claim exact local/CI assertion equivalence.
The earlier32db348a local/CI comparison remains separate and still exposes its
11-assertion difference. No verifier or diagnostic gate was relaxed.
