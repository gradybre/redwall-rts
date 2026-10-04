# Final source-qualified live-query packet

The three production files and Locations tests are identical to independently
accepted hot-2. Routes test differs only in the assertion text: an unchanged
Object counter is not evidence of zero transient native allocation. Construction
accepted that wording correction. Final hashes are in `source-sha256.json`.

Clean import, Locations55/1654, Routes56/9961 and unchanged WorldRoutes26/1711
passed: **137 tests /13,326 assertions /0 failures**. Every strict/raw diagnostics
and leak footer is zero; analyzer0/5. Original project bytes and assets were
restored, and all source pins stayed unchanged throughout this isolated run.
Reproduce with the adjacent `../reproduce-hot.py` command documented in hot-2.

The final 20 batches of256 callers on three spans/O2048 measured45.241ms minimum,
45.953ms median,46.419ms p95 and46.757ms maximum. Parent full validation was
concurrent; timing remains diagnostic. The prior47.555ms p95 is retained in
hot-2. **Both runs fail hot-path runtime qualification.** This commit provides
correct static observation, not an approved every-worker productive workload,
native-memory measurement or production-profile/physical-contact qualification.
