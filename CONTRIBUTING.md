# Contributing

## Scope Guardrails

`provenact-skills` stores immutable skill artifacts and pin metadata.

Allowed:
- adding/updating signed skill bundles
- lockfile/pin maintenance
- deterministic release and verification script improvements

Not allowed:
- agent orchestration logic
- mutable/runtime side effects in checked-in artifacts
- pin bypasses that reduce verification guarantees

## Development Standards

- Keep skill changes deterministic and traceable.
- Update lock metadata for any artifact change.
- Verify all pins before PR:

```bash
./scripts/verify_pins.sh
```

- If changing scripts, ensure shell syntax validity:

```bash
find scripts -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
```

## Security Reporting

See `SECURITY.md` for disclosure process.

## Work item labeling

All work must have `area:*`, `type:*`, and `risk:*` labels so it is triaged and synced into the org project.
