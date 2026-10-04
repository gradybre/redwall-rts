# Strict integrated checkpoint runner

This successor preserves the exact clean-assets/cache/editor-import/no-argument
full-suite/zero-warning-analyzer sequence and source/HEAD/restoration checks
from the retained ca622e1c runner. It takes the expected full HEAD explicitly
and refuses every nonempty output directory, including partial prior runs.
That corrects the historical LOW evidence-overwrite finding. All historical
executed helpers and logs remain unchanged. A successful runtime invocation,
with quoted summary/diagnostic/analyzer lines, is still required per checkpoint.
