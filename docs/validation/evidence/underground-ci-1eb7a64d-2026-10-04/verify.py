#!/usr/bin/env python3
"""Replay the unchanged shard verifier against the exact tested commit's suite corpus."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
HEAD = "1eb7a64d5b36c69081c5403e330f90f906ca2e65"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def main():
    verifier = git("show", HEAD + ":tools/ci_test_shards.py")
    assert verifier == (ROOT / "tools/ci_test_shards.py").read_bytes(), "verifier changed; use the tested version"
    spec = importlib.util.spec_from_file_location("verified_shards", ROOT / "tools/ci_test_shards.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    corpus = git("ls-tree", "-r", "--name-only", HEAD, "godot/test").decode().splitlines()
    corpus = [name for name in corpus if Path(name).parent.as_posix() == "godot/test"
              and Path(name).name.startswith("test_") and name.endswith(".gd")]
    with tempfile.TemporaryDirectory(prefix="codex-ci-1eb7a64d-corpus-") as temporary:
        checkout = Path(temporary)
        (checkout / "godot/test").mkdir(parents=True)
        for name in corpus:
            (checkout / name).write_bytes(git("show", HEAD + ":" + name))
        result = module.aggregate(HERE / "merged", 8, repo=checkout)
    archive = json.loads((HERE / "log-archive.json").read_text())
    compressed = (HERE / "run.log.gz").read_bytes()
    raw = gzip.decompress(compressed)
    assert hashlib.sha256(compressed).hexdigest() == archive["gzip_sha256"]
    assert hashlib.sha256(raw).hexdigest() == archive["raw_sha256"]
    assert b"0 GDScript warning(s) in 0 of 1220 file(s)" in raw
    result["tested_commit"] = HEAD
    result["verifier_sha256"] = hashlib.sha256(verifier).hexdigest()
    result["analyzer"] = "0 GDScript warning(s) in 0 of 1220 file(s)"
    (HERE / "aggregate.json").write_text(json.dumps(result, indent=2) + "\n")
    print("ok:", result["suite_count"], "suite files exactly once across", result["shard_count"], "shards")
    print(json.dumps({key: value for key, value in result.items() if key != "suite_usec"}, sort_keys=True))


if __name__ == "__main__":
    main()
