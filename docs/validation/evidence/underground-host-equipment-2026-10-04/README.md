# Actual host equipment and Session integration

Root composed one existing-budget Gear and HaulCarry over the actual host stores,
without new stock or another tool seeder. Gear resets with Work and Inventory;
the same service identities survive regeneration. Session was independently
accepted at da7c5c66 (integration5de052ea) before these root host changes.

`reproduce.py --out candidate-1` used asset parking, cache removal, clean import,
official strict singleton shards and the actual shared registry. Results:

| Suite | Tests | Assertions | Expected diagnostics |
|---|---:|---:|---:|
| Settlement equipment | 4 | 43 | 0 |
| Underground Session | 14 | 211 | 0 |
| Settlement system | 179 | 6044 | 5 |
| Starter colony | 27 | 288 | 0 |
| Settlement demolition work | 42 | 586 | 0 |
| Settlement demolition complete | 26 | 413 | 3 |
| Settlement furniture removal | 21 | 359 | 1 |

**313 tests /7944 assertions /0 failures**. Every strict/raw unexpected error,
warning and leak is zero;9 expected and0 tolerated diagnostics. Analyzer:
`0 GDScript warning(s) in 0 of 4 file(s)`. Source/registry stayed unchanged;
project/assets were restored. Original logs/manifests remain in candidate-1.

Shared memory now derives the current Motion/Profile/Level result before adding
the source-counted1536B Session slice. Joint233972/262144B; global99998782B,
headroom1218B. Native/runtime qualification remains false. Root observed
`python3 tools/test_underground_memory_budget.py`:215 tests,OK,60.485s;
source/artifact, registry and capacity checks passed. Geometry separately replayed
the10new adversarial cases and reproduced the JSON. The eight reviewed hashes
and acceptance are in independent-review.json. No high/medium finding remains.

The actual demo Session mount, bound-authority retirement, individual starter
tool records, Routes/BUILD/Delivery and playable empty Kitchen remain open.
