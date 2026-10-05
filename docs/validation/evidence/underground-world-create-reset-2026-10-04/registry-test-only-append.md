

### `godot/scripts/core/underground_room_world_bindings.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Bounded route-query remaining counter | `_ordinary_checks` | 4 | `1` = 1 | Empty before bind; overwritten after successful query | 3 | -- | ADR1152. One4B result shared sequentially by the directed path queries; included in the1024B contribution. |
| Original ordinary Room provider wiring and synchronous phase request | -- | -- | -- | No pending phase outside original cold lease | 3 | -- | ADR1152. Inherits the existing Entry provider without duplicating its packed columns. Adds three weak references, one borrowed13-owner Configuration and one68B Request. Full reviewed fixed/helper/provisional-native contribution986 fits a separately counted1024B global contribution, including256B native allowance. Paid Site/Project state remains in its original canonical owners. Final full source/Room/Site/worker checks precede payment or publication; no saved callback permission. |

### `godot/scripts/core/underground_world_retirement.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
| Exact original host owner tuple and bounded retirement Scope | -- | -- | -- | No active retirement at a save boundary | 3 | -- | ADR1155/1158. Stateless module with nested fixed Owners and Scope packets; no new bank or per-entity state. Session retains the exact original owners and at most one pending Scope. Host stops gameplay while preparing/clearing; a partial clear remains stopped. Original-live abandonment is distinct from successful clearing. Preparation/request references are transient and must not be serialized or treated as persistent authority. The8192B slice within PROFILE_BYTES includes5673/6144 provisional controls and1162/2048 helpers; native allocation is unmeasured. Canonical rows remain in their actual owners until the reviewed release boundary. |

