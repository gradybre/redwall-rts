# Immutable connector grouping component evidence

Own branch `codex/underground-connector-assemblies` was created from freshly
fetched origin/master82d60ba8 and fast-forwarded to reviewed integration60f22f11.
No other agent's source or branch was changed. Final exact source/test pins are
in `source-sha256.json`; independent review is recorded separately when complete.

Each iteration moved this worktree's `godot/demo/assets` aside if present,
removed its `.godot`, ran `godot --headless --path godot --editor --quit`, then
ran selected singleton shards through the actual committed
`./tools/run_tests.sh --shard INDEX/COUNT --output-dir ...`. `full-plan.json`
contains the complete exactly-once corpus assignment; selected manifest/report
files prove which suites ran. This does not claim unselected suites ran. Assets
were restored in a finally block. Import logs contain no errors/warnings.

Iteration1 is rejected: the new observed Recipe fixture inherited the existing
generic Catalog alias and used it in a typed override instead of the connector
Catalog alias. The suite did not load (1 test,0 assertions,2 failures). The
production reader was not the parse-error source.

Iteration2 is rejected despite15 tests/965 assertions/0 failures: the intentional
empty corrupt input called `HashingContext.update` with zero bytes, once in the
test source writer and once in the reader's bounded stream helper. Godot emitted
two unexpected errors, and the unchanged strict wrapper correctly failed. Both
paths now finish an empty SHA context without an invalid empty update.

Accepted iteration3 has the complete focused regression selection. Iteration4
repeats the new suite unchanged in behavior after renaming one test local to
remove `CONFUSABLE_LOCAL_DECLARATION`; the rejected analyzer log/JSON are retained.
The narrow `digest-shape/` run adds direct final source-output resize guards
(17 tests/993 assertions). `final/` verifies the added pure current assembly-count
reader (17/1002). Final pins describe both corrections and the count reader;
earlier pins are retained separately. Unique final totals, without counting the
repeated suite twice, are:

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| Connector assemblies | 17 | 1002 | 0 |
| Actual connector recipes regression | 20 | 869 | 0 |
| Actual connector Catalog regression | 18 | 332 | 0 |
| Total | 55 | 2203 | 0 |

Every accepted suite includes both unchanged strict footers:

```
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The tests cover complete actual-part census, nonempty/disjoint/contiguous range
ownership, omitted/invented parts, extra included-part bills, absent/wrong
anchors, exact source hashes/revisions, malformed/truncated wire, maximum256
and candidate26 groups, independently reflected packed bytes, unchanged refused
outputs, actual foreign owner composition, and final-observer reentry/Profile
reload/World generation reuse/Items rewiring/output resizing. Geometry and prices
are explicit synthetic fixtures. No entry contact, installed support, active
numeric content, playable stairs or native runtime-memory qualification is
claimed by this source reader.

Analyzer uses `tools/gdscript_warnings.py --project godot --port 6156 --max 0`
on the two pinned GDScript files, with raw log and JSON saved here. Registry
coverage passes130 modules,650 rows,998 packed columns. All22 reader functions
and34 test/fixture helpers are within the30-line source rule. Native and joint
Placement/content memory obligations remain explicit in decision1104.

Final analyzer: `0 GDScript warning(s) in 0 of 2 file(s)`. Independent root
source review accepted the exact final pins; see `review.md`.
