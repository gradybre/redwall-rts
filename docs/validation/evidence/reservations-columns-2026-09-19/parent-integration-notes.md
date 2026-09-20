# Parent integration adjustments

Initial independent17-test addition plus existing suites passed117tests/2639
assertions/0failures before these source refinements.

The author retained returned job_order while allocating the second sort's two
buffers, contradicting the two-buffer simultaneous budget. Parent explicitly
releases job_order after linking and before sorting by lot. This changes no
canonical state or ordering. Corrected the comment that incorrectly claimed a
returned array was released on function return. New-fragment range loops were
replaced by integer-count iteration so allocation accounting does not rely on
compiler range optimization. Existing runtime loops remain unchanged.

These changes precede independent source review and final validation.
