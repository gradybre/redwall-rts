# Source-bound terrain component evidence

Decision1082. This pack validates actual finite terrain observation and narrow
readers. It does not activate the room tool, productive excavation, travel,
save or final native memory/performance qualification.

`iteration-1/` retains the rejected15-test run:302 assertions and4 failures
from fixtures passing planted day0 to an existing API requiring day1 or later.
The four production/source files are pinned for the corrected run under
`iteration-2/source-sha256.json`; only the test fixture calls changed.

`iteration-2/` moved demo assets aside if present, deleted this isolated
checkout's `.godot`, ran the clean editor import, and ran each named suite via
the existing strict runner with an exact singleton selection. These selections
are iteration evidence, not a substitute for the later no-argument full run.
Invocation JSON files retain commands, timing and exit status; raw logs retain
the actual evidence:

```text
15 test(s), 302 assertion(s), 0 failure(s)
122 test(s), 18192 assertion(s), 0 failure(s)
39 test(s), 637 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 4 file(s)
```

Both zero diagnostic/leak lines occur independently in each corrected suite.
The failed first runner stopped before its raw-log footer. The analyzer emitted
no warnings in either attempt. All source pins matched before and after the
corrected engine run and again before source commit.

The first Python `-m unittest tools...` invocation used the wrong import context
for this repository's standalone scripts and failed before useful tests. Its
log remains `spec-04.log`. The documented script entry points then reported
`test_registry_capacity_audit: PASS -- 190 check(s), 0 failure(s)` and13 joint
budget tests, all passing. Capacity-audit artifact and joint-budget checks pass;
no parser, guard, diagnostic allowance, memory ceiling or authoritative schema
was weakened. Registry coverage passed114 modules/546 rows/933 columns at that
snapshot; integrating the separately reviewed Profiles API raised it to115
modules/550 rows/935 columns with no Terrain source change.

Independent `ug_construction` review matched all four pinned files and reviewed
all Terrain functions, both reader diffs and the15 tests. No high/medium
correctness finding remained. Retained survey copies must stay charged to the
exact shared Budget until consumption. WorldBindings must still subtract paid
or unfinished space before introducing base matter and must recheck live
exclusions. Whole-call-path performance remains unmeasured.
