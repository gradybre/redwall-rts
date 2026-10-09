# Historical native capture sources

Native attempts v1–v6 retain their original capture program as
`source/capture_native_program.gd.gz`. These are rejected historical snapshots,
not current executable inputs. The byte contents still match each attempt's
original `source-sha256.json`; `historical-source-archives.json` records the
original and compressed SHA-256 values. Current `native_replay/` and accepted
v7 files are unchanged.

Verify and extract one snapshot from the repository root into a separate
temporary directory for inspection:

```python
from pathlib import Path
import gzip, hashlib, json, tempfile

root = Path.cwd()
base = root / "godot/data/underground/mole-worker/haul-handling-v1/evidence"
record = json.loads((base / "historical-source-archives.json").read_text())["files"][0]
compressed = (root / record["archive_path"]).read_bytes()
assert hashlib.sha256(compressed).hexdigest() == record["archive_sha256"]
raw = gzip.decompress(compressed)
assert len(raw) == record["original_bytes"]
assert hashlib.sha256(raw).hexdigest() == record["original_sha256"]
destination = Path(tempfile.mkdtemp(prefix="underground-historical-source-"))
(destination / "capture_native_program.gd").write_bytes(raw)
print(destination)
```

Select another entry in `files` for a different attempt. These snapshots contain
the warnings and, where applicable, defects recorded in their failed runs.
Extracting them does not turn those runs into accepted evidence. The current
runner stages the live capture program, not these historical files.
