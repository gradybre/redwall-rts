#!/usr/bin/env python3
"""Losslessly compress completed large logs and shard manifests; original paths and hashes remain auditable."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exclude", action="append", default=[])
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    manifest = root / "archive-index.json"
    entries = json.loads(manifest.read_text()) if manifest.exists() else {}
    candidates = set(root.rglob("*.log")) | set(root.rglob("manifest-*.json"))
    for path in sorted(candidates):
        relative = path.relative_to(root)
        if relative.parts[0] in args.exclude or (path.suffix == ".log" and path.stat().st_size < 65536):
            continue
        data = path.read_bytes()
        compressed = gzip.compress(data, mtime=0)
        assert gzip.decompress(compressed) == data
        target = path.with_suffix(path.suffix + ".gz")
        target.write_bytes(compressed)
        entries[str(relative)] = {
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "archive": str(target.relative_to(root)), "archive_bytes": len(compressed),
            "archive_sha256": hashlib.sha256(compressed).hexdigest(),
        }
        path.unlink()
    for name, record in entries.items():
        archived = (root / record["archive"]).read_bytes()
        assert hashlib.sha256(archived).hexdigest() == record["archive_sha256"], name
        raw = gzip.decompress(archived)
        assert len(raw) == record["bytes"] and hashlib.sha256(raw).hexdigest() == record["sha256"], name
    manifest.write_text(json.dumps(entries, indent=2, sort_keys=True) + "\n")
    print(f"Verified {len(entries)} lossless log archives.")


if __name__ == "__main__":
    main()
