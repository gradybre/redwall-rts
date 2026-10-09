# Current support-clearance fixture

The full `ebdd5daa` CI run exposed nine failures in this suite. It loaded the
new 26-profile/250-box publication through the old 18/194, content-1 fixture
and compared its bytes with the immutable v1 hash. This was a test migration
omission; the actual profile source and clearance guards were not changed.

The corrected fixture uses the current exact publication and maps the old
INSTALL role to current row13. All complete air, footing, contact, one-unit
gap, late-tree and stale-identity checks remain. The historical v1 wire and
source-drift rejection are explicitly checked. An independent review caught
one mistaken descriptor revision argument in the first migration; its failing
run is preserved in `../support-clearance-v3-1/`.

The second run parked assets, deleted `.godot`, performed a clean editor
import, ran the unchanged strict CI singleton-shard wrapper, and restored the
original assets/project. Source bytes remained unchanged during the run.

```text
9 test(s), 138 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1 file(s)
```

`review.json` records the independent review and exact final test hash. This
focused result does not replace the complete corrected-head milestone.
