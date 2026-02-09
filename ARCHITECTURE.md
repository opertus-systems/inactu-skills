# Architecture

## Scope

- Store signed, immutable skill bundles.
- Publish a lockfile with digests and signer expectations.
- Provide deterministic verification automation.

## Out of Scope

- Agent loops, planning, scheduling, memory.
- Runtime policy decisions at execution time.

## Trust Model

- `manifest.json` and `signatures.json` are the signed control plane for each bundle.
- `skills.lock.json` pins expected artifact hash, manifest hash, and trusted key-file digest.
- Lock verification enforces multi-signer requirements (`MIN_SIGNERS=2` by default)
  and distinct key material per signer set.
- Verification is delegated to `provenact-cli` using pinned key material.
