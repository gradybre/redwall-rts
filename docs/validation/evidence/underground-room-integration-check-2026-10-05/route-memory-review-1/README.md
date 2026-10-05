# Independent 1167 shared memory renewal review — accepted

The frozen shared accounting delta is accepted, with no high or medium finding.
This review read root's uncommitted delta over
`e234bde0882695d9a0d28288f7bf45ca05b9a953`; it made no root, runtime, registry,
cache or engine changes. All writes are review evidence in the reviewer's own
worktree. The separate 1167 runtime-source review remains in
`../route-owner-review-1` (review commit `7d8edbd4795bd9a4779c1d3726a753fbf38db604`).

## Exact reviewed inputs

`replay-1/review-inputs.json` pins the complete four tools and manifest. Their
snapshots are retained beside it.

| File | SHA-256 |
| --- | --- |
| `tools/underground_room_memory.py` | `846d75ba2c8b5f899f354d44bcad432af2b2b8d441c13c672e721323b4e75667` |
| `tools/test_underground_room_memory.py` | `6d2216c20d197fda39cba8ff220e2e1ec2fb896e96351ad1b660693358d94962` |
| `tools/underground_memory_budget.py` | `54aa947dbc1dcb5fe99746e4511661c16eeabbf917eb9ff6820d3008387bd986` |
| `tools/test_underground_memory_budget.py` | `046913e38c3e2469a51c5f7e21feb9e2fa0c0ed1f49aed31808dfffbb823ad4a` |
| `route-owner-manifest.json` | `f396686d73684ce19c8d133d2c72aed782de43c99c4aaf3c63f7389c8bea3def` |

The existing UI mutation test now expects the exact earlier refusal from the
expanded current-source closure. Its mutation and its failure assertion remain
intact. Root's original 251-test run with two stale error-message subtest
expectations remains a rejected run; this review does not relabel it or claim
the broader corrected run. The independently replayed UI test passes at the
pin above.

## Source closure and projection

All 54 current source texts are checked against exact names, paths and hashes
before any census producer runs. Injected `Module.text` is checked directly,
then reparsed; neither a stale cached hash nor a disk replacement can hide a
changed injected source. All 41 witnesses, 12 original baseline rows, five
Publisher predecessors and three route predecessors are also verified first.
There are 115 unique pinned input paths.

The outer closure contains every dependency declared by the reviewed route
producer: 22 constructor inputs, 11 inherited inputs, six engine-lifetime
sources and three predecessor files. This includes the constructor parser and
the engine compiler/code-generation facts used for the sequential temporary
Array lifetime. The producer is executed only from verified bytes, with
`optimize=0`; its nested constructor import follows the complete outer check
and its own immutable checks. The accepted normal replay requires no Git
history or subprocess census.

The full **current** route constructor/reset producer runs first. Only then
are the exact reviewed Session, Retirement and Host predecessors supplied to
the older Room constructor calculation. The current 1161 Publisher, 1165
itinerary and 1166 ground Catalog recounts still run. Existing Locations
constructor/class/initializer comparison and the Provider's complete
outside-dispatch comparison still guard their narrower historical projections.
Current source identity and historical accounting provenance are separately
labelled in the result; the old constructor result is not presented as the
new route constructor's peak.

## Reconciled lifetime

| Lifetime | Accounted bytes | Existing ceiling |
| --- | ---: | ---: |
| UI/reset controls | 6,067 | 6,144 |
| UI/reset helpers | 1,919 | 2,048 |
| Controls plus reset helpers | 7,986 | 8,192 |
| Route constructor coexistence | 8,161 | 8,192 |
| Profile/Motion/Session/Retirement joint | 246,868 | 262,144 |

The six immutable numeric constants add 48 bytes to the previous 6,019-byte
control figure. During construction the original retirement Scope and its
copied Owners packet are absent (2,065 bytes). Remaining controls are 4,002
bytes; the complete current constructor stack/temporary heap is 4,159 bytes.
Their simultaneous total is 8,161, leaving 31 bytes in that already reserved
slice. The existing Session reserve is counted once; the two Session controls
and Scope scalar from 1163 remain charged to the retirement slice. There is
no new route retained state, packed bank or global reservation.

The normal generated artifact changes only the seven expected accounting or
provenance groups: retirement, room extensions, ordinary-provider provenance,
Session, source-approach provenance, source hashes and UI reset. Contributions
and declaration bytes are unchanged. Global declared usage remains
**99,999,806 bytes**, with **194 bytes** of headroom. Provisional reference,
header and expression allowances remain explicit; `runtime_qualified` and
`native_measured` remain false. The arithmetic is not native-memory or gameplay
qualification.

## Independent replay

The reviewer ran all 15 extension tests and two normal-budget integration
tests: **17 tests, zero failures/errors**, in 2.621 seconds. The added direct
probes mutated all 54 current sources while retaining their cached hash and
parsed metadata, then all 61 unique immutable witnesses/predecessors. Every
one of these 115 mutations refused before any producer executed.

The full normal budget build passed with subprocess execution disabled and
rebuilt root's artifact byte-identically:
`bdd0fced7c88ee5389c75282a1f4cabb576cd9d42afd588b1bdf89a9e60f4582`.
All tool, manifest and closure pins were rechecked unchanged after replay.
`replay-1/result.json`, mutation results, full test log, rebuilt pack and
snapshots retain the exact evidence. Total replay and probe time was 6.255
seconds; no engine was started.
The raw `replay-1.log` retains the final blank line emitted by the review
script; its sole `git diff --check` finding is preserved as captured output.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B \
  docs/validation/evidence/underground-room-integration-check-2026-10-05/route-memory-review-1/replay.py \
  --root /path/to/the/exact/reviewed/integration-checkout \
  --out /path/to/a/new/reviewer-owned/evidence-directory
```

This review adds no clearance, motion, paid-work, whole-room or playable
acceptance. The separately preserved full 9dad run still has its two original
fixture expectation failures.
