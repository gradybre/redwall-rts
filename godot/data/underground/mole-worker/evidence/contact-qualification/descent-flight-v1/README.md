# Descent flight v1 — the accepted 128u gaits repeated over T0-family treads (ADR 1209 step 2)

Source-local, yaw-0 offline proof. It grants no pace, Location, route, installed support or production permission.

## What was proved

`../prove_descent_flight.py` derives the flight from `docs/design/underground-planning/first-entry-prefix-v1.json`
(`edd56205…`) and nothing else:

- T_k (k = 1..5) is T0's seven parts translated by (0, −128k, −512k);
- every post keeps its foot on the cut floor (y = −1024), so only its height changes: 576, 448, 320, 192 and 64 u;
- every post keeps its natural bearing, y ∈ [−1152, −1024];
- the trench's floor slab, side walls and both end walls are natural solids, six cube rows long (z down to −6144).

T6 is refused (`DESCENT_FLIGHT_TREAD_6_POST_BELOW_FLOOR`). The fixture holds 82 solids.

The accepted sequence prover (`prove_stair_sequence.prove`, unchanged) then runs both accepted gaits over six
consecutive segments:

- the descent (`stair-descent-v7` case 0): L0 → T0 → … → T5;
- the ascent (`stair-motion-v15` case 0): T5 → … → L0.

| File | Content |
|---|---|
| `derivation.json` | the 82 solids, the deck ordinals and the T6 refusal |
| `descent-fixture.json`, `ascent-fixture.json` | the exact prover inputs |
| `proof.json` | both results, producer pins, the verified source files and the historical restorations |
| `proof.log` | the run's stdout and progress |

| Gait | Pairs | Separating checks | Sole contacts | Unresolved | Supports inside |
|---|---:|---:|---:|---:|---:|
| Descent | 4,044 | 162 | 3,978 | 0 | 540 / 540 |
| Ascent | 4,686 | 336 | 4,350 | 0 | 540 / 540 |

`../descent-bottom-v1/` is the ADR 1209 D1/D2 decision diagnostic: the candidate sill T6 and the steps
T5 → T6 → floor.

- With six rows, the body meets the end wall from interval 44 of the step onto the floor (`rows-6`, exit 2).
- With seven rows, the run is clear: 1,348 pairs, 0 unresolved (`rows-7`).

## How it differs from the accepted stair evidence

- **Capacities.** Only the prover's capacities are raised: 4 → 8 segments and 32 → 96 solids.
- **Historical script bytes.** The accepted source closure pins 20 project scripts that have changed since the
  actor images were captured. `historical_snapshot` restores each from the newest git commit whose bytes hash to its
  pin (ADR 1214). `proof.json → historical_source_snapshot` lists every path with its commit. Scripts that are
  unchanged are hard-linked, as before.

## Inputs outside git

The recorded stair invocation (`../analysis-carry-arm-v7/invocation.json`) reads the palette source, proof, plan,
topology and import archive from the frozen `redwall-rts-codex-ug-space` worktree (ADR 1192 §6), each by SHA-256.

The closure also lists 76 gitignored `godot/demo/assets/` files. For this run they were cloned from that worktree's
staged assets and then verified against the image's own source pins. They were removed afterwards.

**This is offline evidence, not a test.** ADR 1192 §2 admits only committed inputs to tests.
`../test_descent_flight.py` (7 tests) checks the following without those inputs:

- the derivation;
- the T6 refusal;
- the segment chaining;
- that the stored fixtures equal a fresh derivation;
- that the stored proofs are clear and pinned to the current scripts.

## Reproduce

```sh
PY=/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
Q=godot/data/underground/mole-worker/evidence/contact-qualification
$PY $Q/prove_descent_flight.py <fresh-dir>                    # the flight, both gaits (about 25 s)
$PY $Q/prove_descent_flight.py <fresh-dir> --bottom-rows 7    # the bottom diagnostic (6 refuses, exit 2)
$PY $Q/test_descent_flight.py
```

Outputs are create-only. The staged demo assets must match their pins, or the source closure refuses.
