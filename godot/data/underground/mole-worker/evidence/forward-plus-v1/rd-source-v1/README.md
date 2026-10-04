# Actual Metal shader source audit

Decision 1132 phase three. This additive offline audit inspects exact
cache/container bytes produced by the accepted native witness in a fresh
isolated user directory. It preserves every per-stage generated MSL hash and
reflection record. The inspector is not a renderer or profile certificate.

The old phase-two decision bytes are preserved in
`decision-after-phase2.md.txt`; historical phase-two manifests still resolve
that one later-appended path through this explicit locator. No accepted
Actor/Profile/source-consumer code is edited in this increment.

Finite bounds: at most 8 cache files, 32 variants per file, 5 shader stages per
variant, 8 reflection sets, 128 total uniforms/specializations, 2 MiB per stage,
8 MiB decompressed source per cache and 32 MiB across the audit. Input caches
are at most 4 MiB each. These are offline parser admission limits; they neither
reserve runtime memory nor limit gameplay content.

The accepted phase-two helper ran once in a previously absent isolated user
directory. `capture-v1/invocation.json` records the full command and restoration:
45 native assertions, zero failures, no raw error/warning/leak lines, 1,209
source/input pins unchanged, project unchanged, and temporary override removed.
Its report records 43 assertions before the final two report-write checks. The
fixture is the existing small skin/static attachment witness, not the complete
mole, map, workpiece, or gameplay scene. Compiled cache variants include engine
alternatives; their existence alone does not mean each variant was drawn.

The final `audit-v3/report.json` consumes five cache files (695,656 bytes), 34
compiled variants and 66 stages. It counts 3,281,991 decompressed source bytes
including repeated stage occurrences, retaining 58 distinct MSL sources. Each
record keeps the original cache digest, variant/stage identity, reflection
digest, embedded source digest and exact decoded bytes. The complete raw caches
retain bindings, specialization values and ABI padding. Padding is consumed
but not required to be zero; raw cache bytes can differ between fresh native
runs while the generated source bytes remain equal.

The inspected 3D skin source has four/eight positive influence paths, a float3
bitcast position, `unpack_unorm2x16_to_float` weights and a final row-vector
matrix product. The current Actor requires no blend shapes. Forward vertex
sources retain their exact unpack/model/view function bodies and full original
files. A function slice is inspection evidence, not a parsed arithmetic proof.
The audit reports zero qualified profiles and false numerical/World flags.

Unsupported precision and incomplete World/source enclosure remain explicit:
native compiled-machine optimizer behavior, built-in UNORM conversion accuracy,
the actual surface compression flags, model/view arithmetic and complete actor
primitive/state enclosure do not follow from extraction. The phase-one theorem
is conditional on its reviewed finite expression; this packet does not extend
that theorem to arbitrary Metal optimization or silently borrow a GL bound.
No runtime owner, profile, Actor or presentation reservation changes.

## Reproduction and retained refusal

Use the actual interpreter used in these records (bare `python3` on this host
is a different runtime):

```sh
PY=/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
E=godot/data/underground/mole-worker/evidence/forward-plus-v1/rd-source-v1
"$PY" tools/test_audit_underground_metal_cache.py
"$PY" tools/audit_underground_metal_cache.py "$E/capture-v1/cache-manifest.json" \
  --zstd-library /opt/homebrew/lib/libzstd.dylib \
  --zstd-sha256 e2847c4613b386683c234913ae3b7b04299254096caf7616e3b3cd9bb97a39ab \
  --out-dir "$E/a-new-audit-directory"
```

The audit requires the exact existing local decoder and source manifests; it
does not install or search for another toolchain. `capture_cache.py` can create
a new native bundle with the same inherited helper when its exact inputs are
available, using a new output name/user directory. It refuses existing output,
project overrides, source drift or missing raw inputs. Reusing a preserved
bundle is an error, not an overwrite mode.

`audit-v1.log` preserves the first real-cache refusal. The initial parser
incorrectly expected a NUL inside `CharString.length()`; that count excludes
the terminator and alignment bytes are separate. Exact rejected parser/test
bytes are in `rejected-name-terminator/`. `audit-v2` succeeded after that fix;
`prior-successful-parser/` preserves its exact executed source hashes. Final
v3 adds explicit reflection/cache/variant provenance and the real five-cache
regression. `python-tests-4.log` reports **18 tests, OK** with no skip; the
actual native libzstd test and captured corpus both ran. No unchanged Godot
suite or GPU witness was rerun solely for this offline metadata addition.

`review-phase3-v1/` freezes the three executable sources, all output/history
bytes and the exact inherited engine/native inputs for independent review.
Review acceptance, if received, remains bounded to this source-census scope.
