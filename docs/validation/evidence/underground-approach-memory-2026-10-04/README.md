# Portable 1156 memory enforcement

This component adds `tools/underground_approach_memory.py` on isolated branch
`codex/underground-approach-memory`, based on `721038a4`. It changes no gameplay
source, shared ledger, registry, capacity, or reservation. Root owns the main
checker import and eventual normal integrated run.

## API and accounting

`build(index, joint)` takes the parsed current source index and the existing
Motion census's `joint` dictionary **before** Session and retirement additions.
It copies the index, honors every supplied `Module.text` override, and reparses
constants from that text. Only absent non-core Driver, SourceProgram, and
Catalog modules are loaded from the current checkout. Missing core modules or
substituted paths refuse.

The result retains the full accepted 1156 census shape. In particular:

| Account | Bytes | Existing reservation |
| --- | ---: | ---: |
| Profile controls, complete declared cold/hot frames and constant payloads | 3,183 | 4,096 logical slice |
| SourceProgram constants, included once above | 640 | Within that slice |
| Profile controls plus provisional native/reference overhead | — | 32,768 |
| Current paired Profiles, 26 profiles / 250 boxes / one source | 19,224 | Existing PROFILE_BYTES |
| Profile/Level/Motion joint before Session/retirement | 237,140 | 262,144 |
| Same joint with Session 1,536 and retirement 8,192 | 246,868 | 262,144 |
| Remaining joint capacity | 15,276 | No new reserve |

`additional_reserved_bytes` is **zero**. This result validates slices already
inside PROFILE_BYTES. Adding its totals to the global pack would double charge
them. Independent global Profile maxima remain unchanged and their composition
still refuses (444,284 bytes before Session/retirement).

The wrapper derives the current Profile counts/row widths/control reserve,
Level, Motion, Session, retirement, and Budget constants from the supplied
source text and requires the actual Motion result to agree. Thus a stale
18-profile subtotal, altered arena, omitted term, extra slice, or already-added
Session/retirement cannot pass merely by supplying the accepted total.

## Portable source proof

The reviewed `underground-work-approach-2026-10-04/census.py`, its accepted JSON,
and its retirement witness remain byte-for-byte unchanged. The wrapper loads
them only after fixed SHA-256 checks. It executes the original algorithm with
assertions enabled even under `python -O`; current source lookups and reported
hashes use caller text. The algorithm never falls back to historical source for
a current read.

`predecessors.json` contains the six exact full source texts originally read by
`git show 84acf74036484bd8ec4930895b7d0a96f8567937:<path>`: Profiles, Routes,
WorldRoutes, Driver, HaulCarry, and Inventory. Each record contains its original
repository path and source hash; the complete witness has a fixed wrapper pin.
Git was used once to package those witnesses, not by the wrapper or CI replay.
No predecessor API or permission is imported into the game.

The complete five reviewed approach implementations are pinned, in addition to
running the source-derived member/allocation/frame checks. This deliberately
rejects an added call or transient allocation that leaves declared numeric
locals unchanged. The eight specific foreign Gear/HaulCarry/Inventory frame
bodies are independently pinned in `foreign-frames.json`, extracted from the
accepted source commit `fe79f9bc4fab8e837f8ce9e2ee8cc5a102773bba`. The later
Inventory retirement change is outside these frames and does not invalidate
this census. Changing an unrelated foreign method is permitted and its actual
current module hash is reported. A change to a reviewed frame or any of the five
approach implementations requires an explicit fresh census/review, even if an
author believes the new implementation fits.

There is no cache of previous successful source text or output. A missing,
modified, or substituted portable witness refuses before execution. The test
replays from a directory containing only witnesses, with no `.git` directory,
runtime source tree, or subprocess access, while all current module text is
supplied in memory.

## Validation

Run from this worktree:

```sh
python3 -B docs/validation/evidence/underground-approach-memory-2026-10-04/reproduce.py docs/validation/evidence/underground-approach-memory-2026-10-04/candidate-1
```

The output directory must be new. The runner records inputs before/after,
commands, full test output, the complete census, and output hashes. Its fixture
uses the actual source index plus the exact reviewed root v3 Catalog snapshot
(`d5f28ac82d76a97ad3f11763b36e0d7e42ce286624bf2c968511662b1a3aaa9e`), because
the branch base predates that publication. This is labeled injected-source
component validation, not a normal integrated main-checker pass or a runtime
Catalog qualification.

The tests cover added/untyped/duplicate/inherited state, repeated resize calls,
actor width changes, SourceProgram constant/allocation growth, additional cold
or hot calls, foreign helper drift, stale parser metadata, non-core mutation
overrides, absent/path-substituted modules, exact current counts and all joint
terms, double counting, corrupted witnesses, and Git-free replay. Two selected
negative tests run again with optimization enabled to prove the immutable
census's assertions cannot disappear under `python -O`.

Native headers, interpreter frames, actual allocation peaks, performance and
256-actor qualification remain outside this logical-source check. No Godot,
asset, project, runtime consumer, or other worktree is mutated or executed.
