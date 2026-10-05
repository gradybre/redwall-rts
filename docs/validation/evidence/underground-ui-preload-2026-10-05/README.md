# UI preload correction — 1177

The six reviewed UI files preserve display values, notice identity and public
APIs while removing the resident card/snapshot cycle, the banner dependency on
an autoload solely for a notice code, and the specimen's unused Shell preload.

Candidate 2 (cycle fix only) still reports five banner load errors. Candidate 3
runs the identical ordered seven-file LSP probe cleanly. Candidate 1's editor
import crash and candidate 4's missing-file reimport error are retained; the
named PNG exists and its post-run bytes are recorded. Candidate 5 retries with
identical source, clean import and six existing official UI suites.

`318 test(s), 4635 assertion(s), 0 failure(s)`

`diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 1 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)`

`log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`

The entire analyzer reports **0 warnings in 1258 files**, but its raw editor
log reports UiSpecimen failing to reload UiRegistry (12 diagnostic lines).
This is a **failed raw-editor gate**, not an integrated green milestone. All
source/project/assets/previous sidecars were restored. UiRegistry has no
preload cycle. The next bounded investigation concerns the analyzer's
open/close document lifetime; no error is waived or filtered by this change.

Independent source review: `source-review.json`. These component corrections
do not close UG09 or any remaining gameplay/qualification lane.
