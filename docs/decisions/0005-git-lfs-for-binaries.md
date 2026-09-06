# 0005 — Binary assets use Git LFS
Date: 2026-09-05 · Status: Accepted

## Decision
Models, textures and audio are tracked with Git LFS. See `.gitattributes`.

## Why
Thirteen species with textures and LODs makes a repository that is unpleasant to
clone. LFS was adopted while **no committed file yet matched any LFS pattern**,
so it applied with no history rewrite.

## Consequences
- **`.gitattributes` must be committed before or with the first binary of a new
  type.** A binary committed first enters history as a raw blob and needs a
  history rewrite to fix. Add new binary extensions to LFS tracking *before*
  their first commit.
- Verify a new type is actually pointerised: `git cat-file -p :path/to/file`
  should print a ~130-byte pointer, not binary.

## Source
`git ls-files` confirmed zero pre-existing matches, 2026-09-05.
