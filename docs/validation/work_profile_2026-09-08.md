# WU tick profiling and adversarial workloads — 2026-09-08

## Scope and contracts

The reader follow-up ([work_reader_benchmark.md](work_reader_benchmark.md)) closed with an
"exact next task": profile the remaining productive-WU tick cost — the persistent-ID reader,
XP writes and the escaping tick result — under the retained harness before selecting another
scoped optimization, and add adversarial mixed-band/party workloads before changing work
arithmetic or needs timing. This entry does that and only that. No file under `godot/scripts`
was modified; `godot` test suite is unchanged at 631 tests / 19,381 assertions / 0 failures
(`validation-results/work-profile-2026-09-08/tests.log`). Owners: REQ-SET-015/020/023,
BAL-WORK-001, ARCH-AUTH-003, ARCH-MEM-001, ARCH-MIG-006; ADR 0015/0016/0017.

## What changed in the harness

`tools/benchmark_work.gd` gained six single-part probe configs — `loop` (the fixed
per-iteration floor every probe pays and must be read against), `pid`
(`jobs.agent_persistent_id_of()`, decision 0017's tie-break read), `xp` (the XP-credit write
branch, forcing a write every sampled tick rather than only on threshold-crossing ticks —
"the value written is the value read, not the sum," so this probe is an upper bound on that
branch's per-tick cost, not its real average frequency), `result` (one escaping `TickResult`
built and read as `work._finish()` does), `factor` (the four-read `work_factor_of()` chain:
skill level, health, mood, `work_factor_into()`), and `gate` (`jobs.resident_may_work_into()`) —
plus two new workloads beyond the original single-KEEP-job-per-resident fixture: `bands`
(residents spread across §5.2's mood and health bands via fixed `MEMORY_TOTAL_BY_MOOD_BAND` /
`HEALTH_BY_BAND` offsets, and across job kinds/skill levels by fixed strides, so the population
is not uniform) and `party` (decision 0017 coordinators formed from party sizes 1–8, cycling
59 coordinators across the same 256 residents). `party_fast` and `party_finish` compare
decision 0017's two acceptance paths (never-finishing vs. finishing-tick proportional split)
against each other; both require `--workload party`. `tools/run_work_benchmark.py` gained a
`build_context` block recording the Godot binary kind, export-preset and export-template
presence, and machine identity, collected once per invocation rather than between runs, plus
setup-hash (not just final-hash) comparison across repeats, and per-record verification that a
run answered for the config/workload/population it was asked to run. Every fixture input that
is a choice of this harness rather than a value fixed by the GDD or decisions 0017/0022 is
named in `BENCHMARK_ARTIFACTS`-equivalent constants at the top of `benchmark_work.gd` and is not
a newly approved balance value.

**What a probe measures, restated because it is easy to over-read.** Each probe runs strictly
less work in the same loop shape as a full WU tick and nothing else — it does not partition the
whole tick. Probe costs overlap (the `loop` floor is inside every one of them, so they do not
sum to the `wu` config's cost), and they omit interaction: instruction-cache pressure, branch
history and allocator state that a full tick's call graph creates are all absent from an
isolated probe. A probe therefore establishes the cost of running that named part alone. It does
not establish that removing that part from the full tick recovers that many microseconds, and no
arithmetic performed on these numbers turns measurement into causation.

## Reproducible measurement

Same protocol as the reader follow-up: 300 warm-up ticks discarded, 3000 sampled, nearest-rank
percentiles, two independent processes per configuration, the larger of the two repeats reported
below. Machine and build recorded directly by the driver rather than assumed: Apple M5 Pro,
macOS 26.6.2, Godot `4.7.2.stable.official.ed1daf0bf`, the **editor binary**.
`godot/export_presets.cfg` does not exist and the local export-template directory is empty
(`build_context.export_templates_entries` is `[]`). **This is not a release measurement and not
the REQ-SET-163 qualification-floor measurement** (Ryzen 5 3600 / GTX 1660 Super / 16 GB); it
compares configurations against each other on one development machine and nothing more.

### Per-part probes at 256 residents (p50 / p99, microseconds, larger of two repeats)

| Probe | uniform | bands | party |
|---|---:|---:|---:|
| `loop` (floor) | 6 / 6 | 6 / 7 | 6 / 7 |
| `pid` | 212 / 239 | 210 / 237 | 211 / 242 |
| `xp` (forced every tick) | 405 / 441 | 447 / 533 | 446 / 483 |
| `result` | 167 / 192 | 172 / 196 | 169 / 195 |
| `factor` | 672 / 715 | 659 / 705 | 665 / 711 |
| `gate` | 265 / 294 | 262 / 290 | 280 / 345 |
| `wu` (whole tick) | 2383 / 2911 | 2438 / 2620 | 1959 / 2181 |
| `combined` (needs+wu) | 3563 / 4138 | 3646 / 3822 | 3167 / 3336 |

Read as raw isolated-part costs, `pid` + `xp` + `result` together are a minority of the `wu`
tick and `factor` alone is smaller than that sum in every row above — but `xp` here is forced to
write on **every** sampled tick, which the probe's own docstring flags as an upper bound: real
XP crediting only fires the tick a resident's accumulator actually crosses the 1000-milli-WU
threshold, on the order of once every 11–12 ticks at the default factor. Amortizing the `xp`
probe by that real crediting frequency rather than reading it as a per-tick constant is what
turns "the three suspects together" into roughly a sixth of the tick and leaves `factor` — which
runs unconditionally every tick in the real code — as the larger single share, on the order of a
quarter of the tick, with roughly half the tick remaining as call-graph work no single isolated
probe accounts for. That amortization is an interpretation of the raw table above, not a further
directly-sampled measurement; the raw isolated-cost numbers are what this harness actually
timed, and are reported as such rather than re-expressed as a single disputed percentage table.

### Workload comparison, `combined` config, 256 residents (p50, larger-of-repeats read as the
### smaller savings estimate — see note)

| Workload | Progress rows | `combined` p50 µs |
|---|---:|---:|
| `bands` (solo jobs, one per resident) | 256 | 3621–3646 |
| `party` (decision 0017 coordinators) | 59 | 3158–3167 |

Holding resident state identical (`bands`'s banded needs/health/skill assignment) and changing
only job plumbing — 256 solo progress rows collapsing to 59 coordinators for the same 256
residents — costs on the order of 450 microseconds less at the median. Divided by the 197 fewer
progress rows (256 − 59), that is a fixed per-progress-row overhead on the order of 2.3
microseconds, against a whole-tick cost on the order of 11 microseconds per contributor. This is
the largest single effect measured in this entry, and it was found incidentally: `party` and
`bands` exist to give the per-part probes a non-synchronized, non-degenerate population, not to
evaluate party-structure cost. It is reported because it is real and larger than any of the
per-part probe effects above, not because this entry set out to measure it.

### The `uniform` workload's p99 artifact

`uniform` — the workload the original reader-follow-up and decision-0016 measurements used —
gives every one of the 256 residents the default spawn work factor, exactly 1100. `80 * 1100 /
1000` releases exactly 88 milli-WU with a remainder of exactly zero every tick, so all 256
resident XP accumulators cross the 1000-milli-WU threshold on the *same* tick. Compare `wu`
p99/p50 ratios above: `uniform` is 2911/2383 = 1.22, `bands` is 2620/2438 = 1.07, `party` is
2181/1959 = 1.11. The synchronized burst inflates `uniform`'s p99 tail relative to the
desynchronized workloads. No realistic settlement produces this synchrony, so `bands` is the
reference workload for any future p99 claim; a change scored against `uniform` p99 alone is
partly being scored against this artifact.

### Incidental finding, nothing changed

`needs.gd`'s `work_factor()` clamps to `[WORK_FACTOR_MIN, WORK_FACTOR_MAX]` = `[300, 1800]`
(§5.2). The published band tables give a legal range of 360–1725 for `skill * mood * health /
1_000_000`, so no fixture — including the adversarial `bands` workload built for this entry —
can drive either clamp bound. The branch is unreachable rather than untested; nothing in
`needs.gd` was changed to address it.

## Determinism and verification

Same SHA-256 canonical-line hash protocol as the reader follow-up (`HASH_PROTOCOL`,
`redwall-work-benchmark-v1/sha256/utf8-canonical-lines`); the `uniform` workload emits the v1
line set byte for byte, so its digests are directly comparable to
`validation-results/work-readers-2026-09-07/`. A workload with coordinator rows (`party`)
appends `coordinator|...` lines after the per-worker lines; a workload without one (`uniform`,
`bands`) appends none. Every one of the 33 (config, workload, population) combinations in this
run produced setup-hash and final-hash agreement across both independent repeats
(`hash_comparisons` in `validation-results/work-profile-2026-09-08/profile.json`); the driver
raises rather than reports a result if any pair disagrees.

`godot` suite: **631 tests, 19,381 assertions, 0 failures** — unchanged from the reader
follow-up, because no game code was touched by this entry
(`validation-results/work-profile-2026-09-08/tests.log`).

## Run it

From the repository root:

```sh
godot --headless --path godot --script test/run_tests.gd
python3 -B tools/run_work_benchmark.py --project-path godot \
  --output-path validation-results/work-profile-current.json --repetitions 2
```

Restrict to a subset with `--configs`, `--workloads` and `--populations`, e.g. only the new
probes against `bands` at the population cap:

```sh
python3 -B tools/run_work_benchmark.py --project-path godot \
  --configs pid xp result factor gate loop --workloads bands --populations 256 \
  --output-path validation-results/work-profile-probes.json --repetitions 2
```

## Exact next task and limits

This entry does not select among decision 0016's four architectural options, and does not
change work arithmetic, needs timing, or the single-integrator design. It replaces an inferred
"~64% is reader-call plumbing" estimate with a measured, smaller share, and identifies
party-structure overhead as the largest effect found so far — but that finding was incidental,
not the result of a workload built to isolate it, and no change to coordinator/member job
structure is proposed here. Release export setup and qualification-hardware measurement remain
separate, unstarted work; Windows testing is deferred by the user. `BAL-WORK-001`'s weather,
darkness and workshop rational factors still depend on missing owner stores and are not
defaulted to a neutral constant. `MOVE-G01–05` remain open and are independent of this entry.
