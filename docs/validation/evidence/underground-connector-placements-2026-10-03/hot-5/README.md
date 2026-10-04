# Rejected analyzer iteration and nested observer proof

All three strict suites passed: Locations57/1731, Routes60/10078 and
WorldRoutes26/1711 =143 tests/13520 assertions/0 failures; every strict/raw
error/warning and exit leak count was0. Analyzer reported one unused-private
field warning because only static RefCounted access consumed the memo field.
The correction explicitly initializes its unproved state during configure.
No warning gate was weakened. Exact files and original project bytes stayed
unchanged/restored across this isolated run.

This iteration uses the actual Terrain callback replacement regression. It does
not close the outer provider override defect retained in hot-4. The final
candidate restores that original probe as another test with the typed direct
cold source-identity correction. Diagnostic256-query p95 was27.478ms (min25.629,
median26.870,max28.123), still failed runtime qualification.
