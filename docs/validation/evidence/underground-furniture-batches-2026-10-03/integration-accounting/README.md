# Integrated furniture cold-allocation accounting

The accepted future-Furniture source bridge adds four lease-bound packed observations to SpaceOwner. The earlier permanent-column census correctly refused the changed source (`72` columns versus its expected `68`). This correction explicitly accounts for those four exact fields while preserving the original permanent-bank census and total reserved memory. The borrowed input aliases an already charged caller packet; private copies cost 60N bytes plus 16 numeric control bytes and live only under the actual shared cold lease.

Independent source review matched `b62b19b11ece08de63cb8ac4e834eb483bb6f25a09299ef19b2e49d8f64b62ab` (checker) and `95c1b5d7ebada9334ea0df92c330dd6c763304b2dad3b0a2c90dbf19218b5f51` (tests). No high/medium finding. All 18 adversarial Python checks pass, including changed width, extra input copy, tuple cardinality, cleanup and charged size. The generated ledger still reports 99,955,154 bytes, 44,846 headroom and `runtime_qualified: false`.

The numbered files are actual combined stdout/stderr from the named commands. These checks concern source-derived accounting and registry/queue consistency; the separate retained Godot component evidence and full fc4fac4f checkpoint are not rerun or extended by this record.
