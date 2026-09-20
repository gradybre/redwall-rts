# Parent integration

Author returned exactly one439-line patch, strict complete/ownerStopped and all
input hashes matched. Original git apply --check failed: authored coordinates
and context structure were inaccurate. Normalized by matching EVERY old hunk
snippet exactly once, retaining replacement text unchanged, then regenerated a
standard unified diff. That normalized patch passes git apply --check and applied.
Raw patch and mechanical normalization proof retained; no fuzzy edit accepted.

Parent found one contract defect: owner validator checked appended Expedition
slot before old fields. Moved its active check after ordinal6 quantity, preserving
specified wire-order refusal precedence. Added a two-defect regression. No other
parent runtime repair so far. Registry/declaration, budget, test updates remain
parent owned and are outside the author's three-file patch.

Focused integrated run256tests/7923assertions/0failures. The five new public
identity tests include exact-pair membership, both reuse cases, structural
continuation and new-field refusal precedence. Two additional section codec tests
and one canonical-hash projection test exercise schema/blank/domain/declaration
behavior. Parent updated now-false schema/count comments without changing logic.
