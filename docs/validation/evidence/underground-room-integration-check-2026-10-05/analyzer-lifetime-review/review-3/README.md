# ADR1180 independent acceptance

The corrected analyzer is accepted at the exact three pins in
`source-sha256.json`. Its actual framed reader retains nonempty findings
separately from fresh per-file replies. Cleanup harvests the ordered union of
completed and unfinished requested files, so a later retry cannot omit a newly
diagnosed earlier dependency. The final requested file stays unfinished until
the bounded one-second drain completes. Missing, empty and non-script explicit
selections refuse before any editor starts.

The twelve protocol tests pass independently. The four warning-loss cases
retained under review-1/review-2 now preserve their warning, including the
actual pump receiving a separate queued final frame. Missing selection also
refuses. All probes load the exact local nonexecuting source snapshots, so the
rejected candidates remain reproducible after the author's files change.

The author's final-tool-3 actual clean import and `--max 0` CLI both exit zero.
The CLI reports zero diagnostics across 1,256 files; independent inspection of
both raw logs finds no error, warning, parse or positive leak line. All 1,260
invocation source pins match before/after, including the reviewed tool/tests.
The exact receipts are copied under `author-final-tool-3/` and bound by
`acceptance.json`. No duplicate engine or foreign source writes occurred.

No high/medium finding remains in this bounded tool change. The one-second
drain is not a guarantee about notifications delayed arbitrarily beyond that
window. Gameplay, performance, and other runtime qualification remain outside
this review. The original failed analyzer behavior and the intermediate retry
finding are retained separately without changing their outcomes.
