# Independent CI timing-table review

Accepted: timing data only, with no high or medium correctness finding.
The reviewed table SHA256 is
`25717b79e9f510fb8cf69ac1ef16dbeddd1af8837a14d9d2d13fb9965493a72e`.
Root's original CI evidence is
`docs/validation/evidence/underground-host-checkpoint-2026-10-04/ci-256c1908/`,
run 37226172376 at `256c19082a173f1dde8118c6ebf7ad36abd31598`.

The unchanged `ci_test_shards.py weights` command reproduced the entire table
byte-for-byte from all eight manifests, reports and corroborating raw logs.
It records 397 measured suites instead of the older table's 240. The original
assignments took 259.609–817.081 seconds of summed measured suite time; the same
measurements produce estimated new buckets of 439.877–439.879 seconds. This is
redistribution arithmetic, not a newly measured CI wall time.

The first attempt against the then-current integration corpus correctly
refused with `manifest corpus differs from discovered test files`: root had
integrated the new 1153 test. No guard was changed. `review.py` then copied the
exact measured commit's direct test files and unchanged helper into an owned
temporary directory and replayed the command there. The temporary copy was
removed afterward. The new test remains unknown to this older timing table
and is still discovered normally. An additional discovery-only probe verifies
that an unweighted direct test is assigned exactly once.

The helper, its tests, shell and Godot runners, and CI workflow are byte-identical
to the measured commit. The table's version and descriptive note are unchanged;
only `suite_usec` values and measured entries differ. All 13 pure Python guard
tests passed; the 5 engine cases were intentionally skipped for this data-only
review. No engine ran, and no foreign source, project or cache was changed.

`review.json` contains all exact source pins, counts and bucket values.
`reproduced-weights.json` is the independent output. `python-guards.log` records
the guard run. `review.py` records and checks the reproduction procedure.
The original reports total 11,027 tests and 1,020,358 assertions with zero
failures, unexpected diagnostics and leaks; their 272 expected and 353
tolerated diagnostics are retained, not represented as zero.
