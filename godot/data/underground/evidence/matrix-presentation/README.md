# Finite underground matrix presentation

The accepted local source checkpoint is `native-v8/` with its outward numerical
enclosures in `proof-v4/envelopes.json`. It contains 42 actual cast/clip/posture
cases, 3,566 finite frames and 164 body/attachment parts. The native capture checks
102,144 skin matrices. The proof rechecks 529 exact source pins. **Zero production
profiles are qualified.** This bounds the deliberately finite affine renderer,
not the old live quaternion, modifier, tail or spring animation continuum.

The source is the real original mesh, its four/eight nonnegative skin influences,
final native skin matrices, held-item socket/fitting matrices and one common
post-skin grounding translation. The renderer blends four finite frames with
positive fixed weights. Therefore the ideal interpolated position lies in the
endpoint hull. The exporter rounds Q24 geometry operations outward and adds an
explicit rational bound for binary64 interpolation, binary32 storage/shader
arithmetic, UNORM16 weights and compressed static-vertex decoding. The pinned
desktop OpenGL 4.7.2 path is required; another backend does not inherit this proof.

Independent construction-lane review accepted the seven frozen local source
files and the v7/v3 proof within this scope. The low follow-up now refuses any
unrecorded attachment per-surface material override. A real MeshInstance test
checks both refusal and unchanged source material. The refreshed v8/v4 artifacts
retain the same geometry bounds and the new exact source hashes. Independent
narrow re-review accepted this correction and verified that all 42 proof rows
match the prior accepted geometry exactly. Earlier batches
and failed attempts remain historical evidence, not alternative accepted results.

The clean component run in `material-checks-v1/` reports:

```text
15 test(s), 120 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Its changed-file analyzer reports zero warnings in four files. The separate
byte-identical baker mirror receives its own analyzer log under
`material-analyzer-v1/`. Native v8 checks report 147 adapter/lifecycle assertions
and eight grounding assertions, all passing, with no unexpected diagnostics or
leaks. The previously accepted unchanged proof/reproducer Python tests are kept
with their original invocation logs; they were not relabeled as a new run.

To reproduce against the pinned, staged, available source assets, use a new output
directory and raw filename each time:

```sh
python3 godot/data/underground/evidence/matrix-presentation/reproduce.py \
  godot/data/underground/evidence/matrix-presentation/native-N \
  --raw-name all-cast-N.ugpal --preview
python3 tools/export_underground_envelopes.py \
  godot/demo/assets/underground-matrices/all-cast-N.ugpal \
  --sha256 <digest-from-verification.json> --palette \
  --import-archive godot/demo/assets/underground-matrices/all-cast-N.inputs \
  --out <new-proof-directory>/envelopes.json
```

The proof requires NumPy. Its exact invocation is preserved in `proof-v4/`.
The 39,317,702-byte derived stream and byte-identical imported input archive stay
inside this worktree's ignored demo assets. Commands, source hashes, complete
proof results, raw logs and native comparison images remain in the repository.
Missing or changed raw assets, manifests, source scripts or archived imports
refuse proof verification; an old success never substitutes for them.

The final native images show the same source pose, grounded finite pose and
half-frame interpolation. They are close-view still evidence only. Actual
cross-clip transitions, current Gear/Haul identity, animation/physical source
binding, finite world-root arithmetic and stance/productive contact policy still
need their own completion. In particular, `all_yaw_bounds_u` in this **local**
report describes ideal mathematical rotation; the new complete native heading
table is separate work and must supply its actual coefficient/numerical bound
before it can certify world placement.
