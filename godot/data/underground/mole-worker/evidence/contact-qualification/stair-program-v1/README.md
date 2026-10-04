# Source-indexed stair program candidate — ADR1139

This is an offline compiler and integer table candidate for the independently
reviewed 128u ascent and descent sources. It allocates no runtime owner, adopts
no pace, writes zero qualification bits and grants no installed-support or
route permission. This is the frozen candidate record; any subsequent independent
review is retained separately in `review.md`.

The executable pair is `../compile_stair_program.py` and
`../test_stair_program.py`. Exact final commands, pre/post source hashes and raw
logs are in `candidate-4/invocation.json`. `source-sha256.json` pins the pair;
`output-sha256.json`, `history-sha256.json` and `inherited-sha256.json` distinguish
new output, retained attempts and unchanged accepted dependencies.

## Actual result

The final run passed 16 adversarial Python tests and reconstructed all 537
original source/import inputs. It checked 211 compiler/input/evidence pins.
The two source programs retain all 182 roots and 180 intervals, including
stationary-root intervals: ascent `[0,29,60,89]`; descent
`[30,31,32,33,34,35,36,37,60,89]`. The decoded integer stream round-trips exactly.
No Godot process, native capture or original triangle proof was rerun.

The 19,332-byte `candidate-4/result/stair-program.ugstep` has SHA-256
`c966b64608b0308cca2e54973aeb72dd55a2b5b4e59f0b834517933667b50ee8`.
All original candidate-2 geometry, support, source and phase fields match
candidate-4; the wire is byte-identical. `geometry-comparison.json` records that
comparison. The Darwin process high-water observation in the report is an
offline Python compiler diagnostic, not simulation or client memory evidence.

## Exact source boundary and retained attempts

Candidate-1 refused `PALETTE_SOURCE_DRIFT`. It is preserved with its executed
compiler, test and input bytes. The original reader only supplied its one
accepted Profiles predecessor; eleven additional source files now differ from
the raw palette's historical source closure. Nothing was changed in those live
files or in the accepted proof algorithms to make the old raw palette pass.

The compiler reuses the unchanged, independently accepted
`source-gates-v3/renew_source_closure.py` adapter, SHA-256
`1dcdbe1ea5e1a4ae1d097897cfd81dd0c7c821eae05ee78b6140cd2aa6b82272`,
with locator manifest `46741887b362bfbc32a175b7fdeb48824d54d4b39564fd5f79fe8c439139467a`.
The exact original reader is `prove_high_wall.py`,
`4b33e7cdc9f168800f01e12e2260c33f8d039b4c9a86fd8e3070a52e0e169186`;
its invocation and raw image are the same tuple accepted by that adapter.
The adapter replaces only the eleven closed-list temporary hardlinks by unlink
then exclusive create, and the original reader supplies its fixed Profiles
predecessor. Both hooks are restored on success and refusal.

`candidate-4/source-boundary.json` lists all twelve original and current hashes,
current byte counts, exact raw/reader/adapter identities and explicit absence
of current runtime qualification. Current bytes are checked before/after source
reconstruction and again before output. This record observes live source; it
does not approve those current consumers. There is no arbitrary source-drift
fallback, altered raw metadata or matching-filename acceptance.

Candidate-2 is the first successful actual reconstruction. Candidate-3 added
source observations and the full memory census; a routine helper extraction
omitted redundant per-program nonqualification metadata from its JSON (the
root flags and wire remained zero). Candidate-4 restores that explicit metadata.
All three executed source snapshots and raw results are retained. The underlying
accepted ascent/descent, rejected 256u comparison, triangle/numerical/native
proofs and sequence supplement remain unchanged.

## Frame, phase and physical proof

Only ascent `stair-motion-v15` case 0 and descent `stair-descent-v7` case 0 can
be selected. Both have 91 keys, 90 nonlooping intervals and the exact
`separate_integer_ceil_v1` root equation. For source phase
`q = interval*65536 + share`, terminal `q = 90*65536` is row90/row90/share0.
The original three-second preview is recorded separately and adopts no tick
rate. The failed 256u source remains in its original presentation image but
cannot become a program row.

Each program-local swept box already includes its authored root trajectory.
The source equation adds signed local integer ceil after skinned pose, then
applies a separately certified orientation and fixed program-origin translation.
Rotating before ceil changes some coordinates and is forbidden. Runtime must
not add the current phase root a second time to these swept boxes.

The compiler recomputes complete body/clothing and held-pick vertex enclosures
using the accepted Q24 interval and numerical residual routines. Every original
terrain collision triangle remains covered: 10,209 body and 1,150 tool triangles
per interval. All mixed anatomical foot boundary triangles are retained. There
is no active-tool collision exception during travel. Complete body/tool boxes
are separate; their union is derivable without a third stored box or omissions.

Those boxes are conservative foreign/dynamic-obstacle bounds. They do not
prove separation from the staircase itself. The exact 22 program-local prisms
for each program pin the complete fourteen timber parts and eight natural
bearing boxes from the accepted sequence fixture. The prior full continuous
triangle proof covers exactly those solids. A future provider must resolve each
one to its actual paid Placement, source part, Catalog revision and full live
Region identity before using that proof. Geometric coincidence or a general
stair-solid exemption is insufficient; additional solids need ordinary clearance.

Each support record retains one foot, its complete continuous XZ projection,
program-local plane, exact fixture primitive and same original contact vertex.
The report also retains its complete 3D enclosure and rational endpoint gaps.
The compiler checks no true source vertex penetrates its plane, the same vertex
has a source gap in `[0,1)` units at both endpoints, and the complete footprint
is inside the exact deck. Native residual and positive signed-ceil enclosure
are unchanged from the accepted proof, not a new penetration tolerance.
Support projection never exempts any body or tool triangle from solid checks.

## Wire census and bounded refusal

`UGSTEP01`, version 1, flags 0, the 32-byte exact source-input digest, then seven
little-endian int32 tables and terminal `UGSEND01`. The offline reader checks
the whole stream digest, exact tags/widths/prefix census, descriptor/source shape,
root range/endpoints, all references, positive boxes, support plane/foot/primitive
identity and full footer consumption. It is not a production loader.

| Table | Row meaning | Rows | Bytes |
|---|---|---:|---:|
| DESC | fixed source index/rise/root-step-solid spans/duration/zero flags | 2 × 12 ints | 96 |
| ROOT | XYZ source keys | 182 × 3 ints | 2,184 |
| STEP | body box/tool box/support-reference start/count | 180 × 4 ints | 2,880 |
| BOXE | exact deduplicated body/tool interval boxes | 348 × 6 ints | 8,352 |
| SUPP | foot/primitive/plane/XZ4/contact vertex | 122 × 8 ints | 3,904 |
| SIDX | support record reference | 180 × 1 int | 720 |
| SOLI | exact program-local physical prisms | 44 × 6 ints | 1,056 |

Exact deduplication saves 2,144 bytes per bank versus dense rows; it does not
remove intervals, stationary pairs, foot or primitive identities. Source/proof
omission, positive source penetration, wrong plane, source drift, overflow,
count exhaustion, unsupported timing or existing output refuses. A dangling
output symlink also refuses before source reads. Tests include each boundary,
hook restoration and changed live bytes. No source is patched in place.

## Simulation and presentation lifetimes

One proposed packed bank plus its 32-byte input digest is 19,224 bytes; old/new
coexistence is 38,448. A proposed reusable 4,096-byte bounded stream buffer and
160-byte numeric caller packet make 42,704 before owner/native controls. The
caller proposal is 24 phase-key bytes, 12 root, 48 body/tool boxes, 64 for two
support rows and 12 lookup-index bytes. None of these runtime buffers exists.
The available 8,386-byte joint headroom cannot admit this proposal: it is short
34,318 bytes before native overhead. No reservation is implicitly borrowed.

One possible later engineering review is pack-specific Profiles box capacity
2304 rather than the current maximum3072, keeping P256/S64 and the global hard
maximum unchanged. That would free 43,008 numeric bytes. Profiles banks183,360
plus existing control allowance32,768, Levels2,292 and this proposed42,704 total
261,124 of the current262,144 arena. This arithmetic is **not adopted**: supported
family capacity, immutable-content replacement, actual caller ownership and
new native controls would have to be reviewed first; only1,020 would remain.
There are no Profiles, Budget, runtime owner or registry edits in this packet.

Existing presentation images retain 329,460 bytes of palettes/tables together;
old/new images alone would retain658,920. Conservatively allowing both prior
source-reader peaks simultaneously and the shared WorldBasis once gives
13,860,596 reserved bytes. A not-yet-implemented sequential single-reader plan
would count7,586,540; replacing both image sets while retaining old palettes
would count7,916,000. Those alternatives include their recorded decode staging,
mesh-array readback allowance and native-control reservation. They do not
measure native allocation or include borrowed original mesh/textures and
per-Actor RIDs. No simulation headroom or whole-client success is inferred.

## Remaining dependency and reproduction

Descent reaches `(0,-128,-2391)` in the L0/T0 fixture; the separately accepted
ascent starts at `(0,-128,-2217)` after a half-turn. Equal local endpoint pose
values do not bridge that174u displacement, turn, stationary hold or shared
ready/travel entry and exit. Those need explicit source/support proof. There
is still no adopted pace, live stair Profile row, installed-part binding,
default Metal deformation bound, actual Routes phase/save integration or
whole-client/performance qualification.

From this worktree, use the actual NumPy-enabled interpreter:

```sh
/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -B godot/data/underground/mole-worker/evidence/contact-qualification/test_stair_program.py
/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -B godot/data/underground/mole-worker/evidence/contact-qualification/compile_stair_program.py /tmp/ug1139-new-output
```

The output must not exist. The original hash-bound ignored raw palette,
WorldBasis and source/import archive must be present; missing inputs refuse.
The accepted source adapter and immutable Git objects at `ecbfcb123…` are
required. The compiler never reconstructs absent paid/generated assets or
changes live source to bypass those dependencies.
