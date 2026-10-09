# Independent Room memory review — corrected candidate accepted

The bounded source/accounting review is accepted. R1 from `memory-review-1`
is closed, with no remaining high or medium finding in this scope. All writes
were confined to this reviewer's evidence worktree; root sources, shared
metadata, caches and engine project were read-only.

## Exact correction

The manifest now includes the complete actual `movement.gd` source at
`4121be883c9fab58ec98d274a7e712703b61c2b5d2e46d34d0f0258c6287eb69`.
The preceding 50 current source entries are unchanged. The adapter changes
only its immutable manifest digest; the test adds the actual reached-method
4,096-byte scratch mutation. The final reviewed pins are:

| Input | SHA-256 |
| --- | --- |
| `tools/underground_room_memory.py` | `3a00fc651f5aa3193c7d8fba3b7826b582d4f116a0ffa22a9e1a07570cd908b5` |
| `tools/test_underground_room_memory.py` | `51fadc710dbe2c06ce741ba53018ea66cfac86a5094833193f3a70341639cc56` |
| Room memory manifest | `40097d0372f0bd4c351f51f75882e151778e8c94248a3af20b414349f9c675b7` |

`review-inputs.json` also pins the unchanged main budget generator/test and
the then-current generated pack. The complete corrected manifest and two
changed tools are retained here. `memory-review-1` preserves the rejected
checker, original mutant and wider projection/lifetime review.

The reached reader chain is Catalog `_movement_pace_refusal` through actual
Movement `profile_revision_of`, `profile_species_id_into`,
`profile_life_stage_into` and `profile_speed_into`. The column readers use
`_profile_field_into` and `is_profile`, then the already allocated
`IntMath.IntResult.succeed/refuse` output. The exact implementations perform
bounded integer column reads and output writes, with no new packed allocation.
Their source dependencies are pinned before any producer executes.

## Independent replay

All 11 focused tests passed in 1.054 seconds. The reviewer separately injected
the **same** method-local mutant from R1, SHA
`89eb1c8e91633624a874a28e1202023b614b2c57c3553c75a88c6776c55b83ad`,
into the complete normal budget build. It refused with
`room memory: current reviewed source changed: movement`; an independently
mocked producer confirms no producer ran. No runtime file was changed.

The first recheck harness expected the adapter's `ValueError`, while the
normal budget entry intentionally wraps it as `AssertionError`. Its source
and log remain in `wrapped-refusal-harness.*`. The corrected harness checks
the actual public entry's refusal and message. This was a reviewer harness
correction, not a product failure or code change.

The complete valid budget build passed with subprocess access disabled. Its
only differences from the previous generated pack were the manifest digest
and the added Movement source provenance. Rebuilt pack SHA:
`c140c8f8c0870fd8f37036e3495fd13d897a1f696fcf5effadb006aeef0f72c9`.
Root owns regeneration of the shared pack; this review writes none of it.

```sh
PYTHONDONTWRITEBYTECODE=1 \
  PYTHONPATH=/Users/brendan/Developer/redwall-rts-codex-ug-integration/tools \
  python3 -B -m unittest -v test_underground_room_memory
PYTHONDONTWRITEBYTECODE=1 python3 -B \
  docs/validation/evidence/underground-room-integration-check-2026-10-05/memory-review-2/recheck.py
```

All source and metadata pins remained unchanged through replay. Accounting
remains lifecycle controls 6,019 + helpers 1,903 = 7,922/8,192; exclusive
constructor coexistence 7,493/8,192; Catalog fixed 1,468/2,048; global declared
99,999,806 with 194 bytes of headroom. No global reservation changed.
Runtime qualification and native measurement remain false.

This acceptance concerns the source-derived accounting checker. The separate
`checkpoint-1` runtime composition failure remains a failure; no source renewal,
clearance, whole-room completion or playable acceptance is inferred here.
