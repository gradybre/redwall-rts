# CI at ca1edc3f

[Run37262123814](https://github.com/gradybre/redwall-rts/actions/runs/37262123814), PR230, head ca1edc3f62b09300f0e36ff0dfbcb1172a5f90ac. run.json records all14 successful jobs on attempt2. The first Specification contracts job reached its unchanged5minute timeout; its raw log is retained. A rerun passed without source/workflow/allowance changes.

Independent aggregation using tools/ci_test_shards.py against the frozen ca1edc3f checkout verified406suite files, exactly once across8shards, with uploaded reports and completed per-suite counters matching every raw log.11226tests1028131assertions0failures; diagnostic totals0unexpectederrors/0unexpectedwarnings/272expected/353tolerated, leaked0objects/0resources. Analyzer reports0warnings across1252files. Shard test wall times are569,447,401,594,299,499,609,556seconds; end-to-end run includes the failed/repeated contract gate and is not claimed to finishwithin15minutes.

Raw logs are gzip-compressed losslessly with both raw and compressed SHA256/size pins. To replay on this exact source revision, expand verified-artifacts/*.log.gz beside their JSON reports, then call the existing ci_test_shards aggregate checker. aggregate.json retains the independent result. The root download copy was deleted only after all24files matched the retained flat copy.

The separately executed no-argument local suite has11226tests1028141assertions0failures with matching diagnostic totals. Its10extraassertions are being traced; exact local/CI assertion parity is not claimed. The first local analyzer reported0/1252warnings but its raw editor log had8errors; that failed wrapper remains recorded by the independent QA lane pending diagnosis/retry.
