# 1174 current memory integration

Implementation/review candidate at source checkpoint
`db03b1f7955afedb0aba87d1715498aaedca1623`. Independent source review accepted the
11 unchanged `source-review-1` pins.
Only the four memory tools, their four test counterparts, ADR1174 and this
evidence tree change. Runtime scripts, old evidence, registry and the shared
`docs/planning/underground_memory_pack.json` are unchanged.

The source-counted global declaration remains **99,999,806 / 100,000,000 bytes**,
with **194 bytes** remaining. This is not measured native memory, a gameplay
acceptance, or closure of the separate ca1 editor diagnostics.

## Current and historical lifetimes

| Current lifetime | Logical/provisional bytes | Existing ceiling |
| --- | ---: | ---: |
| Actual constructor coexistence | 4,034 controls + 4,151 frames/heap = 8,185 | 8,192 |
| Actual lifecycle controls | 6,131 | 6,144 |
| Actual maximum reset helpers | 1,919 | 2,048 |
| Profile helpers and fixed controls | 3,571 | 4,096 within Profile controls |
| Itinerary helper | 432 | 512 |
| Complete Provider source helper | 509 | 512 |
| Contacts foreign source helper | 344 | 576 |
| Motion plus Clock helpers | 1,298 | 4,096 |
| Clock caller packet | 44 | 176 |
| Profile/Level/Motion/Session/retirement joint | 248,632 | 262,144 |

The paired Profile increment is exactly
`2 * (3 * 98 + 21 * 28) = 1,764` bytes. Motion still has two 70,860-byte banks.
Session's 1,536 and retirement's 8,192 contributions appear once. SurfaceAnchor
retains its existing separate 2,048-byte logical reservation. Its two new
retained reference slots are already inside 6,131; no second Anchor or Scope is
introduced. Native header/reference estimates remain explicitly provisional.

The earlier 8,161-byte constructor and 246,868-byte complete joint remain in
named historical reports. They are never presented as current admission.
Current Profile counts are 29/271/one source; the current ground artifact has
12 exact pace rows. The old26-row formula is replayed only to validate the
unchanged historical1156/1158/1160 accounting slices.

## Verification order and source closure

`manifest.json` pins 64 current runtime modules, 138 immutable inputs and 16
historical source versions. Current caller-supplied `Module.text` is hashed and
reparsed, including the distinct `source_program` and `short_program` aliases.
A cached source hash or same frame count cannot authorize altered text.

All input bytes and identities close before any census producer executes. The
small read facade serves captured bytes only; an unlisted file/read/directory
scan refuses. Its nested imports compile the same pinned producer bytes with
assertions enabled. Normal checking needs no Git history. A regression blocks
all real `Path.read_bytes/read_text` after the first producer starts and still
reproduces the complete result.

The accepted current1168 runtime and current1172 caller graphs are reproduced
first. Current1173 then proves the exact Catalog, Motion, Clock and
RouteComposition metadata/source-map changes; every other executable byte must
match the reviewed original. The Clock's only change is its immutable wire
literal. Only then can named historical source versions feed the older
constructors and1156 report.

1171's original constructor manifests are verified against their exact archived
source versions. Its constructor parser separately reads the captured **current**
source, including current1168. The entire resulting current frame/lifetime
report must equal the accepted1171 result except for the clearly reported
source hashes. The prior1167 result is reproduced in a separate original view;
its hardcoded revision2/nine-pace checks are not disabled. Existing1161,
1163,1165 and1166 reports also replay without rewriting their evidence.

`capture_manifest.py` is an author-only fixed-checkpoint capture aid. It may use
Git to locate an exact old source hash. It is not imported or run by the normal
checker and refuses another HEAD. All captured locators and immutable producer
inputs needed by normal checks live in the repository.

## Tests and retained failures

- `rejected-baseline/`: the exact unchanged starting room checker refuses the
  new current Driver source before executing any producer. This is an initial
  gate reproduction, not a full test run.
- `candidate-1/`: 23 focused closure tests and ten direct Motion/Clock tests
  pass. The earlier15-case focused log is also retained.
- `normal-1/`: the first full run executed269 tests and failed one old test
  assumption. Its packet-parser unit appended an unrelated method to the now
  exactly pinned SurfaceAnchor and expected whole-build acceptance. The
  correction keeps both parser assertions at the direct parser boundary and
  additionally requires the complete build to reject the changed current
  source. No production guard changed. All source/protected files stayed fixed.
- `normal-2/`: all 269 memory tests and 190 capacity checks pass, along with
  proposed pack generation/check and the registry capacity check. All eight
  tool/test pins and 181 protected files remain unchanged. `invocation.json`
  retains the complete commands, timing, hashes and exit codes.

The new cases cover stale cached hashes, both source-program aliases,
metadata-only versus body/allocation changes, unreviewed producer and engine
inputs, captured-read closure, old totals posing as current, current29-row
arithmetic, duplicate bank charging, constant/helper/caller growth and the
Clock literal-only renewal. Existing negative tests remain active.

## Reproduction and handoff

From this repository checkout, choose a new output path:

```sh
python3 -B docs/validation/evidence/underground-current-memory-2026-10-05/reproduce.py \
  --out docs/validation/evidence/underground-current-memory-2026-10-05/independent-run
```

The wrapper runs the normal full memory suite, generates and checks a proposed
pack in that output directory, then runs the unchanged capacity checker/tests.
It captures all tool pins, runtime/witness/registry/shared-pack hashes and
before/after invariants. A failed gate stops dependent commands and remains a
failure. The normal pack entry point is used with only its output pathname
redirected into this owned evidence directory.

`source-review-1/` contains all11 frozen executable/manifest pins, nonexecuting
copies, the tracked diff, a proposed pack and accounting summary. The two new
test files are included in the snapshots and exact pins even though Git's
unstaged tracked diff does not include them. Root owns permanent generated-pack
and registry integration after independent acceptance. No engine run is needed
solely for this Python/source-accounting update.

## Independent acceptance

Furnishing independently accepted all 11 frozen pins after reading the current
closure, exact historical projection, constructor and paired lifetime
accounting. Its 33 focused tests passed and its complete pack rebuild matched
`86fb4fc9cb18b6b758fd440b80966ce3aa9c60bba7f0eb17c377736f9590d627`
byte-for-byte; 192 protected/frozen inputs were unchanged. The reviewer did not
rerun an engine or the full normal suite. Root authorized this scoped author
commit while retaining permanent generated-pack ownership.

The freeze summary preserves its original pending flags as historical capture
state. `validation-summary.json` and the independent review receipt record
completion. No native-memory or gameplay qualification follows from this
accounting acceptance.
