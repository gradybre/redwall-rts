# Packed footprint validation evidence

The new validator preserves the exact canonical cells, refusal order, connectivity,
pinch and hole policy, and existing 16,384-cell operation ceiling. Shape creation,
editing and public contour/surface methods are unchanged. The new packed packet
is temporary, with 13N logical packed bytes plus one 8-byte capacity value; no
authoritative state or saved column is introduced.

All 65,536 subsets of a 4×4 grid compare both hole policies with an independent
test-only Dictionary flood and the unchanged contour API. Additional tests cover
the full existing capacity, narrow staircases, signed extremes, enormous absent
spans, multiple holes, refusal precedence, exact allocation and repeated calls.

The two clean runs cover 144 tests, 203,330 assertions and zero failures:

| Run | Suite | Tests | Assertions |
| --- | --- | ---: | ---: |
| geometry | packed footprint | 8 | 196768 |
| geometry | existing footprint | 36 | 4038 |
| geometry | existing room layout | 57 | 563 |
| callers | room orders | 28 | 1457 |
| callers | actual room admission | 15 | 504 |

Each run moved its own demo assets aside if present, deleted `godot/.godot`,
executed `godot --headless --path godot --editor --quit`, and then invoked the
unchanged `./tools/run_tests.sh --shard i/n --output-dir ...`. Complete manifests,
raw output and machine-readable summaries are retained. Assets were restored in
`finally`; no other checkout or process was changed. Imports have no errors or
warnings. Every strict and raw diagnostic footer reports zero unexpected errors,
zero unexpected warnings and zero object/resource leaks; expected/tolerated
counts are also zero.

The warning command was:

```sh
python3 tools/gdscript_warnings.py godot/scripts/core/room_footprint.gd godot/test/test_room_footprint_packed.gd --max 0 --port 6156 --json /tmp/ug1094-analyzer1.json
```

It reports `0 GDScript warning(s) in 0 of 2 file(s)`. The registry gate passes
120 modules, 600 rows and 963 module-level packed columns. The nested packet is
explicit category-3 transient scratch, not an omitted authoritative column.

Independent root review accepted the exact two hashes in `source-sha256.json`
with no high or medium finding after tracing the algorithm and adversarial
tests. It did not duplicate the engine runs. Four full-capacity validations took
97,141 microseconds locally; no target-hardware or frame-budget pass is claimed.

The temporary 477-cell actual-admission allowance remains until the separately
reviewed one-snapshot/Terrain composition follow-up. These tests confer no
excavation, support, entry, route, furnishing or service permission.
