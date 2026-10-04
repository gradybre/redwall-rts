# Independent shared Motion ledger review

**Accepted for the source-derived logical ledger increment.** No high or medium
finding was identified. The reviewer read the new shared census, its delta from
the independently accepted ADR1143 census, the memory-pack integration and new
negative tests, the appended persistence registry stanza, and the actual
Profile/Level/Motion allocation constants and expressions.

The source-census promotion retains the previously reviewed per-chunk decoder
frame boundary. It additionally checks actual Profile bank members, cardinality
and element widths, resolves the current published 18-profile / 194-box /
one-source configuration, and matches the runtime's joint formula. It rejects
changed bank size, allocations, decode-window lifetime/copies, native reserve,
Profile row/box growth, Level reserve growth and shared-cap enlargement.

The configured joint accounting is:

| Contribution | Bytes |
|---|---:|
| Both Profile banks and existing Profile control allowance | 47,288 |
| LevelCatalog retained/control allowance | 2,292 |
| Both Motion banks | 141,720 |
| One decoder payload window | 4,096 |
| Largest permitted caller coexistence | 176 |
| Motion logical/helper allowance | 4,096 |
| Motion provisional native allowance | 32,768 |
| Total inside existing PROFILE_BYTES | 232,436 |
| Existing PROFILE_BYTES | 262,144 |
| Remaining space within that reservation | 29,708 |

Independent maxima would total 444,284 bytes and are refused. The shared pack
charges PROFILE_BYTES once; it does not add the listed suballocations on top of
the same reservation. Existing global contributions and the total remain
unchanged at 99,998,782 bytes, leaving 1,218 bytes under the unchanged ceiling.
The actual native allowance remains unmeasured, as already stated by the
accepted component; no activation or measurement claim is added by this review.

All six reviewed files matched `source-pins.json` before and after review. Their
exact bytes are retained as text snapshots. The reviewer independently ran:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/test_underground_memory_budget.py
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/test_registry_capacity_audit.py
```

The first reports **205 tests, OK**; the second reports **190 checks, zero
failures**. The raw logs are retained here. A fresh `underground_memory_budget`
`build()` serialization exactly matches both the current generated artifact and
`reproduced-memory-pack.json`; existing contribution/total fields were compared
with the preceding checked-in artifact and were equal.

The first local result-summary assertion expected the phrase `190 checks`
instead of the actual `190 check(s)`. Its already-passing raw log was rechecked
using the exact output grammar; no tests or subject source changed. This is
recorded in `independent-result.json`.

No Godot engine, project, cache, foreign source or authoritative runtime state
was changed by the reviewer. Parent acceptance was sent before this evidence
commit. `manifest.json` pins this owned review packet.
