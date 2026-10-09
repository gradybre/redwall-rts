# 1182 UI notice alias memory closure

This candidate starts from exact integrated checkpoint
`32c65ecd9b509d5944cce443cfff410fcadabfd2` in a fresh own worktree. A fresh fetch
left origin/master at `82d60ba8`; ancestry was checked before fast-forwarding.
Only `underground_room_memory.py`, its test, ADR1182 and this create-only evidence
subtree change. Runtime/UI, other tools, the original 1174 evidence/manifest,
registry and permanent generated pack remain untouched.

A complete comparison of 1174's 64 current modules and 138 witnesses found only
one changed path: `godot/scripts/systems/ui_manager.gd`, present in both maps.
1177 replaces its `CLOCK_OVERLOAD_CODE` literal with the constant of its
already-existing `UiNotices` preload. The rejected original checker outcome is
retained under `rejected-integration/`; no producer ran after that refusal.

The successor manifest captures the exact current UIManager, actual UiNotices,
old UIManager bytes and the entire unchanged 1174 manifest. The final successor has 65 current
module rows, 141 witnesses and 17 historical versions, including UiNotices as
a current module so injected text and identity cannot fall back to disk. Before any producer
executes, both current source hashes must match, the dependency must declare
one exact `"CLOCK_OVERLOADED"` literal, and replacing only the unique alias line
must reconstruct the complete old UIManager bytes. All remaining source bytes
and the existing preload are unchanged. Historical replay then uses the exact
archived original through the existing named projection. Current constructor
recount still reads current captured source.

The nine new tests cover the exact successor-map delta, separate current and
old identities, stale injected source text, changed dependency value/body,
extra UI source bytes, computed/duplicate constants and immutable predecessors.
Together with the inherited cases, all 32 focused tests pass. The complete
normal suite and capacity gates are recorded separately under `normal-2/`.

The proposed pack differs from the accepted 1174 result at exactly seven metadata
paths, listed in `candidate-2/pack-delta.json`: current UI hashes, successor
manifest references and the explicit alias-equivalence receipt. Existing
numerical accounting is unchanged: global 99,999,806/100,000,000 (194 remaining),
constructor 8,185/8,192 and complete Profile joint 248,632/262,144. The new receipt
states zero additional reservation. None is a native-memory or gameplay claim.

Run the evidence-only wrapper with a fresh output directory:

```sh
python3 -B docs/validation/evidence/underground-memory-ui-alias-2026-10-05/reproduce.py \
  --out docs/validation/evidence/underground-memory-ui-alias-2026-10-05/replay
```

It uses the normal full memory entry point, redirects only the generated pack
into this evidence tree, then runs the unchanged registry capacity gates.
Every tool pin and protected runtime/witness/registry/old-pack hash is compared
afterward. Source-review-2 was independently accepted by root with its five frozen pins
unchanged. Root replayed all 32 focused tests and rebuilt the proposed pack
byte-identically. The byte-exact receipt and original locator are retained in
`independent-review/`. Permanent pack regeneration remains root-owned.

## Retained intermediate candidate

Source-review-1 and manifest.json preserve the first candidate unchanged. Its
276 normal tests and capacity gates passed, but self-review demonstrated that a
caller-injected UiNotices Module could be ignored because that source was
listed only as a witness. The actual build/changed-value probe is retained at
`candidate-1/injected-dependency-probe.json`; this candidate was not accepted.
The final manifest-2.json adds precisely that reached current module, and the
proof now uses its already-verified text. The corrected exact probe refuses
before any producer executes. Source-review-2 and normal-2 bind that correction.

## Final result

Normal-2 passed all 278 memory tests and 190 capacity checks, with all eight
inspected tool files and 184 protected inputs unchanged. The independent review
accepts this exact source-only alias closure. No runtime or native-memory
qualification is added.
