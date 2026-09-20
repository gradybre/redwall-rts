# Event schedule codec validation

SAVE-S11-R01v2 / ADR0161 implements the already ruled8+32N section11payload.
Independent author and reviewer sessions are archived with SHA-pinned inputs.

- Initial focused39/495/0; expanded41/528/0; final43/538/0.
- Full local suite4713/184355/0, followed by2review-requested test-only additions covered by final focus. Exact final-head CI remains required.
- Fifteen static checks pass; Godot import recorded separately.
- Literal byte vectors include empty1, exhausted0, signed/i64extrema and empty cursor500. Real schedule/cancel/pop continuation preserves next IDs/order and exhausted allocators.
- Invalid shape, descriptor/buffer bounds, malformed bytes and barrier refusal leave caller/owner state unchanged. Aliased input buffers are separated by publication.
- Prior shutdown leaks553objects/33resources unchanged; no gameplay activation or whole-save claim.
