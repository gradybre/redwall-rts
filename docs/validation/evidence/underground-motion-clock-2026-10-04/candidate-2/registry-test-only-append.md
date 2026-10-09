
### `godot/scripts/core/underground_motion_clock.gd`

| Column group | Members | Width B | Count | Null / unused | Cat | ARCH-SAVE-002 | Notes |
|---|---|---:|---|---|:-:|---|---|
| Stateless source tick sampler | -- | -- | -- | -- | 3 | -- | ADR1147 temporary test-only metadata, expressly authorized by root. Zero retained numeric state or packed fields. Caller44B stays within Motion176B; extra helper ceiling256B shares Motion's existing4096B (counted1090B before this helper). No per-resident clock, source bank or travel permission. Permanent registry remains root-owned. |
