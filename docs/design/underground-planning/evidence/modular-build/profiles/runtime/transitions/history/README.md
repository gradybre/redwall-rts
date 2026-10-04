# Earlier instrumentation attempts

These are historical diagnostic inputs and outputs, not the accepted final batch.
The first one-case walk pilot passed its then-current verifier. The five-case
behavior pilot recorded real motion, but its midpoint nearest-exit fixture left
through the forward exit. Its verifier correctly refused to call that a retreat;
the final fixture starts one-quarter along the same existing bore.

The original analyzer invocation mapped the outside-project inherited script
to `res://tools/`, where the editor had no matching file. Both warnings are
preserved. The final analyzer used byte-identical copies of both scripts in a
temporary copy of the actual project and returned zero diagnostics. No warning
was suppressed and no source declaration was changed to pass analysis.

`../native-v1/` is a rejected relative-output-path invocation: Godot changes its
working directory under `--path`, so the initial relative report path could not
be opened. The wrapper now resolves its fresh output directory before engine
execution, and an adversarial test pins that behavior. No prior evidence was
overwritten. Only `../native-v2/` is the final full native batch.
