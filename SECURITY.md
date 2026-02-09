# Security

## Rules

- Skill bundles are immutable once released.
- Every release must be verified against `pins/skills.lock.json`.
- `public-keys.json` must be digest-pinned in lock metadata.

## Release Gate

A pin is releasable only if:
- `provenact-cli verify` succeeds,
- `artifact` and `manifest_hash` match lock entries,
- `keys_digest` matches lock entry,
- expected signer IDs are present,
- at least two signatures are present, and
- signatures map to at least two distinct public keys.

## Reporting

Report security issues privately to maintainers first.
