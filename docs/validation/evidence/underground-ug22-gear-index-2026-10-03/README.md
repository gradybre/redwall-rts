# UG22 Gear lot index evidence

The exact reviewed implementation and test hashes are in `source-sha256.json`.
They were unchanged between focused validation, independent review by
`ug_geometry`, and publication. Review found no blocking findings; requested
prose spacing was corrected afterward. Review covered slot and row reuse,
publication callers, clear/blanking, both restore paths, whole-image refusal
atomicity, full-generation access, reverse audit, and live/cold memory accounting.
The index remains private category 2 state; canonical fields are unchanged.

Validation moved this worktree's demo assets aside if present, deleted its
`.godot`, and ran `godot --headless --path godot --editor --quit`. The import log
has zero error/warning diagnostics. Each relevant suite then ran through the
strict runner as a single-file shard, with its normal census and log checks.
These are focused checks, not a complete no-argument suite run. Shard positions
refer to the recorded 311-file source corpus and are not stable identifiers.

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| `test_gear.gd` | 82 | 1169 | 0 |
| `test_gear_columns.gd` | 25 | 1322 | 0 |
| `test_work.gd` | 76 | 9234 | 0 |
| `test_excavation_physical.gd` | 34 | 22295 | 0 |
| Total | 217 | 34020 | 0 |

Every focused suite printed both of these lines:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The changed-source analyzer on its own port 6157 printed:

```text
0 GDScript warning(s) in 0 of 3 file(s)
```

The retained 256-worker probe printed a 9728 µs mean / 9953 µs maximum paid
excavation pass, with a 1424 µs mean / 1485 µs maximum worker gate. The prior
UG06 probe recorded 10336 / 10696 µs and 2563 / 2714 µs respectively. These were
not controlled performance runs: other verification processes were active and
the test corpus changed. They must not be reported as a qualified speedup or
whole-tick p99. The complete pass still exceeds the 2 ms whole-tick target.
UG17 must measure the complete composition on its qualification hardware.

The source establishes an allocation-free O(1) lot lookup, with occupancy,
recorded slot and full-generation validation retained. The deliberate cold
capture/audit integrity scan remains O(rows + 16384). Two 65536-byte index
lifetimes are conservatively reserved: live and private whole-image staging.
They add 131072 to the ledger, yielding a planned payload of 86405078 bytes,
94793686 with the existing reserve, and 5206314 arithmetic headroom. These
figures are source-ledger arithmetic, not a measured RAM peak or composed-load
qualification. Later Room/Furniture and sparse-space owners are separate work.
