
### `godot/scripts/core/underground_motion_catalog.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Original Level identity | `_level_identity` | 4 | `21` = 21 | Empty before configure | 3 | -- | DIAGNOSTIC ADR1143 temporary metadata only. |
| Original Level configuration | `_level_config` | 4 | `13` = 13 | Empty before configure | 3 | -- | Original exact source. |
| Original Level digest and published wire | `_level_digest`, `_digest` | 1 | `32` = 32 | Empty before configure | 3 | -- | Fixed original identity controls. |
| Source-only banks | -- | -- | -- | Empty before admission | 2 | §1 WORLD | Two banks, each 17421I32+67I64+640B =70860B. No actor state or travel authority. |

### `godot/scripts/core/underground_connector_delivery.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Frame | `_frame` | 4 | `9` = 9 | Empty before configure | 3 | -- | DIAGNOSTIC accepted1140 prerequisite; final shared ledger belongs to root. |
| Install | `_install` | 4 | `9` = 9 | Empty before configure | 3 | -- | Existing scratch only. |
| Endpoint | `_endpoint` | 4 | `7` = 7 | Empty before configure | 3 | -- | Existing scratch only. |
| Bounds | `_bounds`, `_support` | 4 | `6` = 6 | Empty before configure | 3 | -- | Existing scratch only. |
| Remaining | `_remaining` | 4 | `1` = 1 | Empty before configure | 3 | -- | Existing scratch only. |
