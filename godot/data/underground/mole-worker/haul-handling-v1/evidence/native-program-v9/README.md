# Native stone image v9 — 10 clips (ADR 1206)

This image holds the ten approved stone clips in one native-replayed Actor image. It is a **separate image**
(runtime source 3), not an extension of v8:

- the `.ugactor` wire has one fixed part list, and the stone is a different mesh from the wood stock;
- v8's 12 clips plus these 10 would exceed the 16-clip limit.

Parts: body (24 binds) and the procedural stone lump (rigid, 70 vertices / 108 triangles). Every clip shows both
parts (mask 3). Stand and walk stay in v8. v8 and its tools are unchanged.

Image: `compiled/stone-handling.ugactor`, 791,844 bytes, sha256
`49ff3018d363c7dbad05df0af91368e8fec11e30525c2f8231e6a959f80a7b95`. The stone's array-mesh fingerprint is
`e9c10ccc…`.

| # | Clip | Keys | Loop |
|---|---|---|---|
| 0–3 | approach, lift, place, recovery | 61 each | no |
| 4–7 | hold, enter, carry, exit | 2, 65, 219, 65 | carry only |
| 8–9 | enter_haul_stone, leave_haul_stone | 31 each | no |

That is 657 keys in total.

## Finding: the stone transcript needs exact bits

`stone-source-v1`'s JSON numbers drop the sign of 16 negative-zero coordinates. The values are equal, so every
geometric proof is unaffected. But the engine's mesh fingerprint hashes the bits, and the first replay refused
"both complete native mesh fingerprints".

`native_capture_stone/capture_stone_bits.gd` therefore records the committed surface as raw little-endian float32
bytes, together with the engine's own fingerprint (`../stone-source-v2/native-stone-bits.json`, deterministic).
The compiler requires those bits to equal v1's numbers value for value, and it requires its Python transcript to
reproduce the engine fingerprint.

## Replay (real Metal / Forward+, non-headless)

`run_native_program_v9.py` stages v7's runtime closure plus the real stone factory's closure (120 scripts):

- 7,794 native samples over v7's three nonzero root/heading views, with 31,262 assertions;
- zero failures, diagnostics or leaks;
- a clean import, and zero analyzer warnings in the capture script.

`verify_native_program_v9.py` checks the replay independently (`verification.json`):

- zero coefficient mismatches;
- largest source-to-native-input vertex error: body 0.000289 u, stone 0.00101 u;
- minimum visible floor gap: body 0.00137 u, stone 0.00197 u;
- 11,256 exact rational two-hand witnesses on the stone;
- per view, 11 exact joins and 4 reversal pairs;
- **a cross-image join**: v9's `enter_haul_stone`@0 body and World coefficients equal v8's native `stand`@8 in
  all three views.

`test_native_program_v9.py` holds 5 tests, including a byte-identical rebuild, v8 unchanged, and the lossy
transcript refusing.

**The stone renders untextured white in the replay.** The capture binds no material, and the tunnel dressing
colours its stones per instance. The runtime presentation must supply the stone material.

## Census (`census.json`, declared from the loader, not measured)

| Item | Bytes |
|---|---|
| Palette | 791,028 |
| Tables | 792 |
| **Declared peak** | **7,285,004** (v8: 7,486,168) |
| Capture | 10,038,688 |

**The presentation set with stone** is 28,541,580 bytes declared: actor 7,141,920 + assembly 6,628,488 + wood
haul 7,486,168 + stone 7,285,004. That is a presentation reservation. It is not simulation-owned memory inside
the 100 MB gate, and it is not a measured peak.

Reproduce:

1. `run_native_program_v9.py --palette … --grip-palette … --body …/cast/mole_digger/body.glb --out <new>`.
2. `verify_native_program_v9.py`, `test_native_program_v9.py` and `census.py`.

Run them with the NumPy Python.
