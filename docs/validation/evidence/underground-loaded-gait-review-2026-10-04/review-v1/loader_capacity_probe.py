#!/usr/bin/env python3
"""Reproduce the pre-materialization capacity gap without writing in the source checkout."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import tempfile

import numpy as np


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()
    sys.path.insert(0, str(args.source))
    import prove_loaded_gait as proof
    with tempfile.TemporaryDirectory(prefix="loaded-gait-review-") as temporary:
        path = Path(temporary) / "compressed-4096.npz"
        np.savez_compressed(path, matrices=np.zeros((4096, 25, 12), dtype=np.float32),
                            grounding=np.zeros(4096, dtype=np.float32))
        events = []
        original = np.lib.npyio.NpzFile.__getitem__

        def observed(self, key):
            value = original(self, key)
            events.append({"key": key, "shape": list(value.shape), "nbytes": value.nbytes})
            return value

        np.lib.npyio.NpzFile.__getitem__ = observed
        try:
            try:
                proof.load_case(path, 0)
            except Exception as error:
                refusal = type(error).__name__ + ": " + str(error)
            else:
                refusal = "SUCCESS"
        finally:
            np.lib.npyio.NpzFile.__getitem__ = original
        print(json.dumps({
            "source_sha256": hashlib.sha256((args.source / "prove_loaded_gait.py").read_bytes()).hexdigest(),
            "disk_bytes": path.stat().st_size,
            "disk_gate": 4 * proof.MAX_KEYS * 301 + 4096,
            "max_keys": proof.MAX_KEYS,
            "arrays_materialized_before_refusal": events,
            "refusal": refusal,
        }, indent=2))


if __name__ == "__main__":
    main()
