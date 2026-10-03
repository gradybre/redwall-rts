# Shared reservation census review

The actual immutable Assembly bank and fixed SurfaceAnchor packets consume existing
binding reserve:4760 and2048 bytes respectively. Known consumers now use378120
of524288 bytes, leaving146168 for actual Placement, adapters, frontier and native
growth. The overall logical pack stays99959250 bytes, headroom40750; native
qualification remains open. No capacity or diagnostic gate is relaxed.

The checker counts92 numeric provider bytes and204 packet bytes. The1024-byte
helper allowance is a conservative logical allowance, not measured native stack
or object overhead. Native composition references remain explicitly unmeasured.

Independent Construction review found a medium census omission: initializer-only
matching missed a commented or later-allocated second packet. It also missed an
unknown nested Array field. Concrete typed member enumeration and nested field
checks now reject these cases. Separate tests reject changed packet width, added
packed fields, insufficient reservation and mistakenly counted later function
locals. The corrected frozen source was independently accepted and38 Python
checks passed; the committed generated pack matches the source.

Exact accepted pins,38-test output and artifact comparison are retained here.
No engine rerun is needed for this source-census tooling; the integrated runtime
checkpoint is recorded separately.
