# Work reader optimization — 2026-09-07

## Scope and contracts

ADR 0016's requested follow-up: caller-owned `IntResult` readers in needs and residents,
used by work-factor computation, job health/rescue eligibility, hazard-latch refresh,
and XP reads. The allocating convenience APIs still return fresh objects. Every refusal
clears the output value; integer checks, refusal precedence, clamps, thresholds, packed
columns, resident/reference validation, needs timing and work carries retain their existing
semantics. Owners: REQ-SET-015/020/023, BAL-WORK-001, ARCH-AUTH-003, ARCH-MEM-001,
ARCH-MIG-006 and ADR 0015/0016. No gameplay constants or movement contracts changed.

The persistent-ID convenience read, escaping work result and XP mutator result still
allocate. This is not an allocation-free entire WU tick. No signals or callbacks occur while
these reader scratches are live; each needed input is copied to an integer before reuse.

## Reproducible measurement

The earlier ADR 0016 benchmark driver was not retained in the repository. This is a **new
explicit fixture**, not a claimed exact rerun of that unavailable driver. Both versions run
the identical checked-in `tools/benchmark_work.gd` through `tools/run_work_benchmark.py`.
The baseline core files were verified byte-for-byte against commit
`48e92cedb5235b535cc2946137801322565c7265`. Reports preserve all core source SHA-256 hashes,
the frozen harness SHA-256, commands, per-process results and captured output tails.

Machine checked directly: Apple M5 Pro, 18 cores, 48 GiB, macOS 26.6.2 (25G83),
Godot 4.7.2 stable official ed1daf0bf, editor binary. Export presets remain absent and
the local export-template directory empty. These are Mac development measurements,
not Windows release or minimum-hardware qualification.

Fixture: 12 or 256 mice with default needs, one long KEEP job per mouse, default priorities,
resolved WORK hour 8, and no movement. Each job starts with 1,000,000,000,000 milli-WU to
avoid completion; this is a benchmark input, not a newly approved production value.
Needs-only, WU-only and combined run 300 warm-up ticks then 3000 sampled ticks. Combined
runs needs before WU. Minimal tick-result checks are inside the timed region; redundant
state validation and hashing are outside it. No job completes and every WU tick must report
positive accepted work. Two independent processes per configuration per source version,
run sequentially. No other test suite ran during the timed comparison.

Percentiles use nearest rank. The table conservatively shows the **larger result of the
two repeats** for each metric. Raw per-repeat summaries are in the JSON files.

| Configuration | Population | Before p99 µs | After p99 µs | Before pair p95 µs | After pair p95 µs |
|---|---:|---:|---:|---:|---:|
| needs | 12 | 81 | 82 | 144 | 144 |
| needs | 256 | 1265 | 1323 | 2463 | 2522 |
| wu | 12 | 216 | 150 | 383 | 264 |
| wu | 256 | 4457 | 3103 | 8086 | 5607 |
| combined | 12 | 294 | 225 | 535 | 407 |
| combined | 256 | 5785 | 4324 | 10689 | 8045 |

At 256 residents, WU p99 falls about 30% and combined p99 about 25%. Combined
p99 remains 4324 µs against the 2000 µs development threshold; the pair proxy remains
8045 µs against 6000 µs. Needs-only changes little, as expected from unchanged integration.
These results measure the benefit of reusable results; they do not separate the remaining
allocation, call, checking and arithmetic costs or prove the full earlier causation claim.

The pair p95 sums consecutive tick pairs, giving 1500 windows. It is a **4× CPU proxy**
for 120 ticks/s at 60 frames/s, not an actual rendered-frame/scheduler capture; it does not
cover catch-up frames with more ticks. Compare 2000 µs and 6000 µs as development warning
thresholds only. REQ-SET-163 and ADR 0016 remain open. No staggered integration, inlining
or native-code option is selected by this change.

## Determinism and verification

All six configurations have equal setup and final SHA-256 digests across both independent
repeats **and across before/after source versions** (24 process runs). Canonical UTF-8 lines
cover health and its remainder, all five needs and remainders, all resident skill XP,
work carry, active-skill XP remainders, and job state/remaining milli-WU. The reserved skill
must return its exact expected refusal. This SHA-256 protocol is newly versioned and is
not comparable directly to the earlier unretained FNV-1a digests. It proves parity for
these fixture columns and horizon, not all authoritative stores, arbitrary replay or saves.

- Baseline Godot suite: **624 tests, 19,275 assertions, 0 failures**.
- Updated Godot suite: **631 tests, 19,381 assertions, 0 failures**.
- Python validation: **33 tests, OK**.
- Godot editor import and 120-frame headless boot: exit 0, no script errors.
- Independent static review found no semantic regressions. Its allocation-comment and
  harness error/provenance findings were corrected and re-reviewed without blockers.
- Initial sandboxed baseline could not write `user://` fixtures/logs; it was rejected as
  an environment failure and rerun with required access. Initial harness smoke exposed
  an incorrect Schedule result type; it was fixed before accepted measurements.

## Run it

From the repository root:

```sh
godot --headless --path godot --script test/run_tests.gd
python3 -B tools/run_work_benchmark.py --project-path godot --output-path validation-results/work-readers-current.json --repetitions 2
```

To recreate the old source without touching the working checkout:

```sh
baseline_dir=$(mktemp -d)
git archive 48e92cedb5235b535cc2946137801322565c7265 godot | tar -x -C "$baseline_dir"
python3 -B tools/run_work_benchmark.py --project-path "$baseline_dir/godot" --output-path validation-results/work-readers-baseline.json --repetitions 2
```

The driver freezes the harness for each invocation, rejects logged script errors even with
exit code 0, rejects disagreement between repeat digests, and bounds each subprocess to
120 seconds. Use matching fixture hashes for any before/after comparison. Final-state
hash equality alone does not prove timing workloads were identical.

## Exact next task and limits

Next: profile the remaining productive-WU cost under this retained harness, including the
persistent-ID reader, XP writes, and escaping tick result, before selecting another scoped
optimization or ADR 0016 architecture option. Add adversarial mixed-band/party workloads
for wider optimization parity before changing work arithmetic or needs timing. Release
export setup and qualification remain separate pending work; Windows testing is deferred
by the user. No complete playable colony or survival trajectory is established.

BAL-WORK-001 weather, darkness and workshop rational factors still depend on missing owner
stores. They were not silently replaced with neutral constants. MOVE-G01–05 remain open;
this reader-only change is independent of them. Persistent underground, swimming/diving
and connected climbing/canopy requirements remain in scope for later dependent tasks.
