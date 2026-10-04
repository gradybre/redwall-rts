# Rejected integrated checkpoint ca622e1c

The exact frozen source passed clean editor import and then failed the unchanged
no-argument full suite. Source and HEAD were unchanged and assets restored.

```text
10722 test(s), 982115 assertion(s), 4 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
error: 4 failing test(s).
```

The strict wrapper exits on test failures before its raw-log summary guard.
The analyzer consequently did not run. Neither is claimed as passing.
Full suite elapsed time was1383.114 seconds.

Two Contacts fixtures still hard-coded Room generation1 despite actual
Directory reuse. Two shared Inventory fixtures lacked the guarded Funding
input/final hooks. Reviewed commits55104f9e and921287c2 fix the isolated
fixtures and preserve every production payment and identity check. Focused
suites passed; a new integrated full checkpoint remains required.

The same source passed34/34 Specification-contract commands under
`docs/validation/evidence/underground-spec-ca622e1c/`; that is independent
contract evidence, not a substitute for this rejected full runtime result.
The executed helper is retained byte-for-byte; its later LOW fresh-directory
hygiene finding is corrected only in the next helper version.
