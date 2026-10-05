# Current Room memory integration

The `manifest.json` SHA-256 is
`40097d0372f0bd4c351f51f75882e151778e8c94248a3af20b414349f9c675b7`.
It identifies 51 actual current source modules, 29 immutable witnesses and
the exact historical accounting inputs. `tools/underground_room_memory.py`
verifies that complete closure before replaying accepted census producers.

Reproduce from the repository root:

```sh
python3 -B tools/underground_memory_budget.py --check
python3 -B tools/test_underground_memory_budget.py
```

The original ten extension tests and full 245-test run preceded independent
review. Review found a missing Movement source pin; the original manifest is
retained as `manifest-before-movement-review.json`. The corrected eleven-test
extension run covers the original reached-method mutation. The full corrected
run is `joint-tests-review-2.log`. Independent findings and acceptance live in
`../underground-room-integration-check-2026-10-05/`.

Logical allocation is 99,999,806 bytes, headroom 194 bytes, runtime qualified
false. This adapter preserves the original reservations; it provides no native
RAM, timing, complete Room construction or save/resume acceptance. See decision
1169 for the source compatibility and lifetime decomposition.
