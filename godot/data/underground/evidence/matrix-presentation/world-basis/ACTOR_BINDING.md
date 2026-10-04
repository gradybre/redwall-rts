# Exact finite world-source Actor binding

This component retains the original meshes, skin weights, materials and finite
matrix interpolation. A complete immutable native heading table supplies the
exact binary32 coefficients for all65,536 headings. The table reader hashes the
same stream it consumes, checks the exact producer and backend, rejects incomplete
or extra bytes, and bounds the metadata before parsing it. JSON input is at most
1,024 bytes, four containers, two levels and64 member separators. It allocates
one524,288-byte coefficient array; no replacement image or resident copy exists.

`bind_world_source` compares the entire actual immutable Domain descriptor and
both source digests. It admits only integer root bounds within the exact
binary32 integer range. It is a presentation binding, never movement or contact
permission. The physical owner must still admit the full translated body/gear/load
and bind the actual selected profile. Each world-bound MeshInstance is top-level:
its world matrix uses explicit binary64 scalar expressions and binary32 stores,
so arbitrary parent translation, rotation and scale cannot alter the equation.
Static attachments receive the same root, native heading and post-skin grounding.
Local presentation, original mesh/material identity and native skinning remain.
Culling boxes remain in each original MeshInstance's pre-instance-transform frame;
these synthetic fixtures deliberately use generous boxes and do not qualify tight
production culling.

## Exact evidence

- `actor-checks-v4`: clean assets-aside import;20 tests,213 assertions,0 failures.
  Both strict and raw footers report zero unexpected errors/warnings and zero
  object/resource leaks; expected/tolerated counts are zero. Analyzer0/4.
- `actor-native-v2`: the actual reviewed native heading stream, an exact finite
  Domain and deliberately synthetic meshes.21 pixel assertions pass. Parent
  translation1900m, nonuniform scale and non-Y rotation do not move either part.
  Native yaw32768 mirrors both; the shared half-metre grounding and integer root
  changes each move both by32 pixels. The PNG was inspected.
- The exact test suite in the native renderer plus rendered tree-entry/re-entry
  checks reports256 assertions,0 failures. Analyzer0/3. Native logs contain no
  unexpected diagnostics or object/resource leaks.
- `actor-checks-v1` retains a native font-import crash before any tests. The
  unchanged retry v2 passed201 assertions but exposed three naming warnings.
  v3 fixes those names. v4 additionally tests pre-decode JSON capacity/shape
  refusal. Earlier successful native-v1 witnesses remain previous-source evidence.

The actual allocator observations around the table load are134,809,634 bytes
before and135,334,198 after:524,564 retained bytes. The historical process peak
remained231,698,702, so that observation cannot isolate transient decode peak.
The544,768-byte table reservation remains524,288 packed +4,096 decoder/control
+16,384 unmeasured native allowance. No simulation arena is borrowed. Each bound
Actor adds53 logical numeric bytes (World8, bounds24, root12, heading8, ready1)
and a shared source handle. Presentation-pool/native admission remains open.

Independent root source/evidence review accepted the exact final Actor, test and
native-helper hashes with no high/medium blocker in this presentation-only scope.
This component and the native synthetic fixtures do
not qualify any production clearance, pose/state union, work contact, connector,
animated visual quality or full256-resident presentation budget. The separate
world-envelope exporter is in progress and excluded from this source review.
