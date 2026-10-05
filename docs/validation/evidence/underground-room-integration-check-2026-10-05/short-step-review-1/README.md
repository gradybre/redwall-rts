# Independent ADR 1168 component review

**Verdict: accepted at the corrected `source-review-2` pins.** No remaining high
or medium finding, and no finding waiver. This accepts the bounded source/runtime
component and sampled native replay. Production publication, paid next-cell
composition, finite World activation, target-hardware performance, and native
memory measurement remain open.

The review was read-only in
`/Users/brendan/Developer/redwall-rts-codex-ug-short-work-step-runtime`, whose
source base was `116f2f2e7b6c5334af7e18a34457fd3c6cc1a34d`. All review outputs
are in this directory in the separate evidence worktree. The reviewer did not
run Godot, modify author sources, stage diagnostic consumer overlays, or change
the independently running `ca1edc3f` full-suite worktree.

## Exact accepted candidate

The author's manifest is
`docs/validation/evidence/underground-short-work-step-runtime-2026-10-05/source-review-2/source-sha256.json`,
SHA-256 `1bc01db521fcf1a3a806e1f42385d465773df46609c9eab1a5c2b6dab809cf9b`.
All 21 current executable pins match [final-source-pins.json](final-source-pins.json).
[acceptance.json](acceptance.json) is the machine-readable publication review
receipt, SHA-256
`6613e4cfa8c1b3a17b779d19bff46f8fb16b6115da5f50f47fc5f8a78818a37e`.
It includes the five runtime module hashes, serializers, immutable source report,
diagnostic images, runtime evidence, exact native before/after/report/binary
pins, ancestry receipt, scope, and remaining gates.

The full source review covered Profiles version/content/row compatibility,
Routes canonical readiness and clock transitions, the ground-only WorldRoutes
gate, Driver source composition, the stateless short-step program, diagnostic
serializers, native capture/verification, adversarial tests, and the source
census. The old 26-row protocol-5 image remains supported. The new content-3
image has 29 rows: short forward/backward are 10/11, canonical all-yaw ground
is 12, and WORK rows are 13 through 28. Fresh READY admission is distinct from
claiming readiness for an already registered legacy actor.

The 232-unit program preserves the inherited pace and rational remainder:
three moving ticks are bracketed by eight fade and eight recovery ticks.
Interrupted motion retains the physical prefix and remainder. Wrong source,
pace, shape, successor, and malformed clock/remainder cases refuse. Rendering
does not decide readiness. Turns still require the actual canonical READY
ground profile and complete physical proof.

## R1: uncounted allocation expressions, reproduced and closed

The first census froze constructor spellings and numeric local fields but
accepted new retained or method-local collection storage without changing its
reported total. Independent injected-source probes demonstrated all four:

- A 4,096-element Array literal in `ShortStep.uses`.
- A 4,096-element Array literal in `Routes.advance_tick`.
- Driver `_pose` initializer growth from three to 65,536 packed integers.
- Profiles Bank header initializer growth from four to 4,096 packed integers.

[allocation-probes.json](allocation-probes.json),
[initializer-probes.json](initializer-probes.json), their logs, and the probe
scripts preserve these results. The initial author source/producer pins are
in [original-source-pins.json](original-source-pins.json); the exact rejected
producer and `8eff2596...` contract remain in the author's `source-review-1`
nonexecuting snapshots. No runtime source was changed to execute a mutant.

The corrected census closes complete owned-module code tokens, measured
function tokens, local type topology, and collection literal payloads,
including initializer arguments and constants. Its lexer preserves `#`
inside strings. The corrected contract is
`ab3d24c07a7e8fcca8c259dace66399282081bee5bc01f4e67f7175585ad7475`.
All four original probes now refuse, as preserved in
[corrected-allocation-probes.json](corrected-allocation-probes.json).
Thirty independent census tests pass, including typed/untyped/nested Array,
Dictionary, aliases, both initializer growth cases, and token preservation.

## Small final runtime delta and memory scope

[clock-delta.diff](clock-delta.diff) is the sole runtime change after the first
review: removal of an eight-byte `clock` local in `_source_clock_leaf`.
The three concrete static calls read the same original packed column inline;
there is no observer between those reads. It changes no state, protocol,
source, timing, or permission rule.

The reproduced [final-census.json](final-census.json) matches the author result:

| Logical lifetime | Bytes |
| --- | ---: |
| Profile controls within 4,096 | 3,571 |
| Complete moving helper | 877 |
| Turn helper within 512 | 504 |
| Pure WORK/READY leaf | 344 |
| Paired profile delta | 1,764 |
| Joint profile admission within 262,144 | 248,632 |

There are no new actor columns or global banks. These are source-derived
logical counts, not native allocation measurements. Root retains final
foreign-caller and whole-pack accounting; the complete provider caller is
not silently charged to this component's helper.

## Independent verification and author evidence inspection

The independent Python checks passed: six serializer tests, fifteen native
audit tests, and thirty corrected census tests. The profile wire and ground
wire/manifest rebuilt byte-for-byte. Native verification reproduced exactly:
462 poses, 144,144 exact scalar comparisons, 46 captures, and 2,558 assertions.
All 402 current native input hashes match, and native before/after manifests
are identical. `native4-tests.log` uses the final native-4 result after the
clock-local change; initial native-3 replay evidence remains labelled as such.

The author runtime-7 raw summaries and restoration facts were independently
read and checked: four suites, 167 tests, 18,407 assertions, zero failures;
all strict/raw error, warning, expected, tolerated, and leak counters are
zero. The analyzer reports zero warnings in eleven files. The author native-4
import/capture commands have zero raw diagnostics and restored original
sources, override, and import sidecars. This review does not claim a second
engine execution.

[source-ancestry.json](source-ancestry.json) independently closes all 509 old-v3
prerequisite pins, nineteen direct source-1164 inputs, and twenty-two source
producers. Changed historical code is read from the exact old consumer commit
`721038a4198df17d9bfab6c9994cc9916f875447`; it is never installed as a live
replacement. The two raw Actor/WorldBasis inputs use explicit hashed asset
locators. The previously accepted continuous source proof is retained; this
review does not reauthor its 537-input proof.

For reproducibility, run the scripts from this directory using Python `-B`
and `PYTHONDONTWRITEBYTECODE=1`. `verify_ancestry.py` checks immutable ancestry;
`replay.py` reproduces the initial candidate's wire/native audit;
`final_review.py` validates the current corrected pins, all four original R1
mutants, final native-4 audit, runtime footers, and final acceptance receipt.
`final_review.py` requires NumPy; the used interpreter was
`/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`.
The author census tests were run directly with Python `-B` and their output
is retained in `corrected-census-tests.log`.

Three reviewer setup errors are retained rather than counted as test evidence:
`probe-tuple-normalization-error.log` records an initial tuple-versus-JSON
comparison error, `initializer-missing-old-contract.log` records the attempt
before selecting the immutable rejected contract, and
`native-missing-numpy.log` records the system Python missing NumPy. The corrected
replays described above completed successfully.
