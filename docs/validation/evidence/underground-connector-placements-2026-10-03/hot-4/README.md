# Rejected first source-reuse candidate

The exact frozen five-file manifest and isolated invocation are retained here.
Locations passed57 tests/1731 assertions. Routes ran60 tests/10077 assertions
with one failed test (two assertions); strict/raw diagnostics and leaks were0.
The failed outer `static_profile_edge_refusal` override replaced the provider's
Catalog after returning production success. The cold caller copied a result
because it checked only its retained old Catalog, not the provider's current
Catalog. The later correction moves the existing reference into the typed
Bindings base and checks it directly before output; the failing case stays an
active separate regression. This rejected run is not acceptance evidence.

The diagnostic20 batches of256 three-span/O2048 queries measured25.305ms min,
25.830ms median,26.373ms p95 and27.341ms max. This still fails runtime timing;
correctness failure independently rejects the candidate. Project/source pins
and asset restoration were confirmed. Analyzer was not run after test failure.
