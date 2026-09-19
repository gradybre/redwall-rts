# Planner dirty-state format acceptance

2026-09-19; SAVE-J2-R01v2 / decision0157. Based on integrated34c2196 (PR147).

The original29-field projection collided for three real planners whose next jobs differed. Three existing dirty arrays and three scalar counts now belong to the canonical registry. Ordinals0..28 remain unchanged; schema2 appends29..34. Canonical unused tails are zero; pop preserves existing LIFO order. Descriptor-aware decode identifies unsupported versions from23 bytes before demanding the larger body.

Validation: focused293 tests/6431 assertions/0 failures; full4670 tests/181533 assertions/0 failures; all15 specification checks; editor import; independent source review no blockers. Literal Python wire vectors and pinned Godot assertions agree at all six appended offsets. Malformed count/index/duplicate/tail, schema refusal precedence, input/output immutability, full queues, row0, idempotent marks and real future-outcome separation are exercised. The first focused run's sole failure was a stale existing29-word count assertion, corrected and rerun; both logs retained.

Registry610 listed/602 canonical/553 packed,52 owners. Capacity census519 prose=473 equalities+46bounds and83other shapes;55distinct expressions. Historical Cycle3 evidence unchanged; its net delta is explained by decisions0142/0157.

One author attempt timed out without a patch; owner stopped and inputs verified before Astra implementation. The independent reviewer returned malformed JSON solely due to four unescaped content quotes; raw public response and exact metadata repair retained. Acceptance includes this limitation rather than disguising either worker terminal state.

Not complete: J2 live column API/capture/apply, cross-owner references, full save/replay and the first playable settlement. Existing553 leaked objects/33 resources remain unresolved suite shutdown findings. No new spending or visual acceptance.
