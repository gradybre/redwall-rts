# Reserved-fauna metadata fault plan

Planning arithmetic only; actual engine checks follow implementation. Owner 17 is last, beginning at global field 289. All faults use disposable clones and preserve schema and physical frame validity before bridge metadata checks.

| Fault | Balanced change |
|---|---|
| Key | `world_init` → `world_iniu`, same ten-byte ASCII length and still after `work` |
| Version | Owner 17 version 1 → 2 |
| Primary | Owner 17: 384 → 385; owner 16: 512 → 511; descriptor sum unchanged |
| Children | Move owner's 10 one child extent to 17; child begins 11–17 become 4; owner 10 payload/block -8, owner 17 +8; offsets 11–17 -8; section total unchanged |
| Field count | Move Work's trailing `_tool_broken` u8[512] descriptor at global 288 to the end of all three field tables. Owner 16 count becomes 8, owner 17 becomes 10, owner 17 begin becomes 288. The first nine fauna fields remain in their original order, followed by the moved extra field. Work payload/block -520, WorldInit +520, owner 17 offset -520; section bytes and field total stay unchanged. This isolates the field-count guard without also breaking a required fauna field. |
| First field key | Global 289 becomes another nonempty key |
| First field type | Global 289 i32 → i64, delta +1536 bytes. Adjust owner 17 payload/block and both section-total constants; no later owner offset exists. |
| First field extent | Global 289 count 384 → 385, delta +4 bytes; adjust the same totals |

Each matching metadata comparison bypass must produce an assertion failure, never a parse/script failure. The valid empty control fills zone slots with pinned -1; all other values remain zero. Under counterfactuals, schema and frame validity are asserted independently before the bridge result, so value defects cannot mask whether gate 4 was reached.

Separately change each EntityDirectory null constant in the clone (`NULL_SLOT` -1 → -2 and `NULL_GENERATION` 0 → 1). These are source-guard witnesses, not schema changes. The bridge must reject at metadata before evaluating columns. The caller fixture retains the canonical -1/0 pair. Product Directory, WorldInit, schema and bridge hashes remain unchanged.
