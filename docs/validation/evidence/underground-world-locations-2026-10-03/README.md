# Decision 1103: World-scope endpoint component

The independently reviewed slice adds a once-bound weak `Locations.WorldScope`,
`begin_world_prepare(cold_token, space_token)`, and a full-claim
`Owner.prepared_snapshot_leased_into(space_token, out, budget, cold_token)`.
The base is `60f22f11e9665d6790cfdf49977b74e966c915aa` on the isolated
`codex/underground-world-locations` branch. All four final source hashes are in
[source-sha256.json](source-sha256.json). Root reviewed those exact hashes before
commit; no high or medium finding remained.

## Verified behavior and limits

Binding requires the actual configured World/Space/Locations/Budget, no active
preparation and a quiescent cold arena. The weak scope cannot be replaced after
expiration. Begin and every subsequent observer require the exact original
Budget token and sealed Space transaction. Source callbacks cannot reenter the
endpoint owner, replace the lease and still allocate an image, or rewrite the
caller record that was privately pinned before observation.

The World path can add only null-Room, level-zero endpoints. Every existing full
endpoint handle and immutable payload must survive and receive a refreshed
geometry proof. Full claims remain blockers even for a new TRANSIT anchor.
This deliberately conservative bootstrap path does not omit an existing Room's
reservation for an underground endpoint refresh; that situation can refuse.
No first-entry, profile, traversal, timber, Room or paid-Site permission follows
from a successful component test.

All ordinary source, Terrain and retention observers run before the coordinator
publishes Space. World Locations publication then checks only the actual scope's
contractually callback-free publication predicate, exact successful Space token
and revision, the original Budget token, preserved packed endpoint facts and
actual Inventory retention. It does not invoke the scope's prepared observer,
source readers or graph retention observers after Space swaps. The pure actual
provider predicate remains a production integration obligation. Synthetic scope
fixtures prove the component boundary; root's concrete SurfaceAnchor supplies
natural Terrain/retained-space proof separately.

## Logical memory and lifetime census

| Item | Numeric or packed bytes | Lifetime |
|---|---:|---|
| World preparation flag | 1 | Unsaved Locations control, cleared by abort/publication |
| Weak scope link | Native reference overhead only | Once-bound weak collaborator; inside existing native reservation |
| Private World `Record` | 116 | 36 bytes of integer vectors, 32 bytes of scalar integers and two six-I32 copies (48); local validation only |
| Additional World validation allowance | 256 total | Includes that 116-byte private record and bounded scalar call frames; no retained third image |
| Leased staged snapshot allowance | `48R + 16O + 256 + prior_output_bytes` | Whole isolated candidate image and existing Owner copy controls; prior caller output is counted again after observers |
| Existing Locations cold allowance | `88K + 384` | Conservatively covers one snapshot and two bounded fragment lists plus reused scratch |
| World admission enforced before observers | `88K + 640` | Existing Locations allowance plus the new 256-byte validation allowance |

The actual whole-topology fixed census changes from 2,085 to **2,086** within its
existing 2,112-byte ceiling. The complete Locations/Routes reservation remains
**1,041,728 bytes**, with 26 bytes of fixed-control margin and 6,848 bytes inside
the existing 1 MiB topology envelope. No authoritative bank, allocator, wire,
save/hash column or per-entity array was added.

For the admitted pack R=6,144, O=2,048, K=8,192, the actual snapshot maximum is
327,680 bytes and the fragment payload maximum is 196,608 bytes. Adding the
existing 384-byte allowance and the new 256-byte allowance gives **524,928**
logical bytes on this path. The enforced conservative World bound is **721,536**
(`88 * 8192 + 640`), within the same original 1,048,960-byte shared cold lease.
Caller/provider packets must also coexist within that lease; this component's
bound is not permission to allocate a second arena. Root's concrete provider
separately accounts its retained fields and callbacks. Native headers, allocator
capacity/growth and complete-world resident memory remain unmeasured.

Owner rejects the leased snapshot before observers when the immutable operation
budget cannot afford `2 * (R + O)` for source/claim validation plus image scans.
Locations retains its existing charged row/fragment work budget. Additional
create-only identity checks are bounded by configured endpoint capacity: each
World pass reads at most N rows and compares all 22 I32 payload fields on present
old rows, plus fixed per-row generation/revision/domain predicates. Scope
callbacks have their own source-counted bounded provider obligations. There is
no productive-tick scan or allocation in this cold-only path.

## Evidence

Final [iteration-2](iteration-2/) ran from a clean Godot import:

- Locations: 47 tests / 1,416 assertions / 0 failures.
- Space Owner: 103 tests / 5,280 assertions / 0 failures.
- Routes regression: 45 tests / 9,328 assertions / 0 failures.
- Total: **195 tests / 16,024 assertions / 0 failures**.
- Strict and raw log counters: zero unexpected errors, warnings, object leaks
  and resource leaks; zero expected/tolerated diagnostics.
- Analyzer: zero warnings in all four changed files, port 6214.

The four source hashes remained unchanged after all final checks. This fresh
worktree had no `godot/demo/assets` directory to park; the reproducer still
parks/restores one when present. The retained
[iteration-1](iteration-1/) had one test-only expected-error mismatch: the existing
immutable-payload guard correctly returned `LOCATION_IMMUTABLE_PAYLOAD` before
the later World-specific guard. Only that assertion changed before iteration 2;
production source was unchanged. The rejected result is not passing evidence.

Run from the repository root into a new output directory:

```sh
python3 docs/validation/evidence/underground-world-locations-2026-10-03/reproduce.py --out /tmp/ug1103-world-locations-check --port 6214
```

The reproducer derives a suite selection from the unchanged strict wrapper; it
keeps every zero-diagnostic, nonzero-test and exit-leak gate. It restores any
parked assets even after failure. The raw executed wrapper/logs are retained
alongside each iteration.
