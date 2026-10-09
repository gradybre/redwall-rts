# Failed CI checkpoint ebdd5daa

[Run37250182343](https://github.com/gradybre/redwall-rts/actions/runs/37250182343)
failed because all nine support-clearance tests used an obsolete fixture
publication. Seven other shards, the analyzer, specification contracts and
all three metadata jobs passed. The aggregate correctly failed.

Every one of the402 suite files appears exactly once in the eight original
raw logs and matches its unchanged manifest assignment; completed per-suite
counters agree with each shard summary. `failure-analysis.json` is descriptive
failure analysis, not a replacement report. The missing successful shard-4
report was not manufactured, and the original strict parser still rejects it.

Across the raw logs:

```text
11156 test(s), 1026335 assertion(s), 9 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1243 file(s)
```

The original downloads, job/timestamp record and lossless raw log archives are
retained; `log-archives.json` records decoded SHA-256 hashes and lengths. The
reviewed correction is documented in `../support-clearance-v3-2/`. The full
local run of this original failed head continues independently; a new full
corrected-head milestone is required before claiming integrated acceptance.
