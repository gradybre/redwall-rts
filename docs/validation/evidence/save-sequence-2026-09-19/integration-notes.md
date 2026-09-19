# Astra integration corrections

The structured worker bundle was complete and its owner stopped. Both target SHA-256 values matched the dispatch snapshot. Git rejected the original patch. Deterministic exact-context reconstruction found one hunk omitted the existing success return from its old text; Astra explicitly replaced that return with the new economic-high validation call. This is recorded as an integration correction, not a clean transport success. After that correction every old hunk matched exactly once. The original, integration and applied patches remain here.

The first focused run (268 tests, 33704 assertions, one failure) caught the codec's commands owner-schema constant still at 1, even though the registry and generated table were at 2. Astra updated it to 2. No other source correction was made at this stage.

The initial two pinned byte fixtures were independently transformed from committed HEAD: schema word 2 to 3 and four zero bytes inserted at offset 24; their lengths are independently asserted as 76 and 177. They do not derive expected bytes from the new writer.
