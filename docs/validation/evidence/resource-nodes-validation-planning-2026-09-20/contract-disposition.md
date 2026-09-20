# Astra final contract disposition

2026-09-20. Accept RESOURCE-NODES-S4-VALIDATE-R01v1 after the independent review's two corrections and verification.

1. Keep the capacity-nonnegative gate for stable exact refusal identity. Omission has an exact-code witness (COLUMN_STOCK instead of COLUMN_CAPACITY), not an acceptance-domain witness. The required30mutants are real assertion failures; do not describe all30 as accepting malformed data.
2. Pin later presence comparisons to ==1 and exhaustion to (exhausted==1)==(quantity==0), with inactive as !=1 after valid flags. Add present stocked/exhausted2 and present negativequantity fixtures if classifying isolated flag/quantity acceptance witnesses. Direct flag gates retain precedence.
3. Existing FramedOwner.i64_column and set_i64 verified by actual engine probe12assertions/0: both4096element columns independently preserve9007199254740993 andINT64_MAX; physical shape passes; actual sourcebound chains352418/4096/16384 andnull(-1,0) match. No new API required.

Review metadata arithmetic and source/domain conclusions accepted. Firstauthor may now run against frozen accepted inputs. Intake remains after PR166 merges. No new permission or scope reduction is needed.
