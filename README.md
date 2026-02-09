# provenact-skills

[![Compatibility](https://img.shields.io/badge/compatibility-provenact_pinned-blue)](./COMPATIBILITY.md)
[![Status](https://img.shields.io/badge/status-pinned-green)](./pins/skills.lock.json)

Immutable, signed base skills pinned for reproducible execution.

Ecosystem map: `provenact/docs/ecosystem.md` in the substrate repository.

This repository is for skill artifacts and pin metadata only.
It does not include agent orchestration logic.

Compatibility pinning is tracked in `COMPATIBILITY.md`.

## Layout

- `skills/<skill-id>/<version>/`:
  - `skill.wasm`
  - `manifest.json`
  - `signatures.json`
  - `public-keys.json`
- `pins/skills.lock.json`: authoritative pin set (artifact, manifest hash, key digest)
- `scripts/verify_pins.sh`: lockfile enforcement using `provenact-cli verify`
- `scripts/bootstrap-base-skills.sh`: generate/sign/pin the baseline skill set
- `scripts/prepare-release.sh`: scaffold an unsigned next-version bundle
- `scripts/release-skill.sh`: add/update a pinned skill release from a source bundle

## Baseline Skills

Pinned baseline set:
- `http.fetch`
- `kv.get`
- `kv.put`
- `hash.sha256`
- `time.now`
- `random.bytes`
- `json.transform`
- `template.render`
- `fs.read`
- `fs.write`
- `receipt.verify`
- `signature.verify`
- `policy.eval`
- `retry.with_backoff`
- `queue.publish`
- `queue.consume`

Intentionally excluded:
- `exec.detached` (out of scope for safe skill execution boundaries)

## Default Bundle v0 (Scaffold)

Proposed default bundle (agent-facing IDs):

- `fs.read_text`
- `fs.read_tree`
- `fs.write_patch`
- `shell.exec_safe`
- `search.ripgrep`
- `git.status`
- `git.diff`
- `http.fetch_text`
- `json.validate`
- `extract.text`

Spec: `DEFAULT_BUNDLE_V0_SPEC.md`.

Bootstrap command:

```bash
./scripts/bootstrap-default-bundle-v0.sh
```

Current ABI status:

- Implemented hostcall-backed behavior: `fs.read_text`, `fs.read_tree`, `http.fetch_text`
- Placeholder behavior pending runtime hostcall support:
  `fs.write_patch`, `shell.exec_safe`, `search.ripgrep`, `git.status`,
  `git.diff`, `json.validate`, `extract.text`
- Placeholder skills are emitted with empty capability declarations in the
  default-bundle bootstrap until corresponding hostcalls are implemented.

Bootstrap command:

```bash
./scripts/bootstrap-base-skills.sh
```

Current implementation note:
- Baseline bundles are generated from per-skill WAT sources under
  `skills-src/*.wat` via `tools/watc`.
- They are deterministic reference implementations with distinct binaries and
  capability declarations.
- Host-integrated behaviors (network/fs/kv/queue/time/random) require runtime
  ABI hostcall support in `provenact-cli`.
- Current hostcall-backed functional skills:
  - `time.now` (`time_now_unix`)
  - `random.bytes` (`random_fill`)
  - `hash.sha256` (`sha256_input_hex`)
  - `fs.read` (`fs_read_file`)
  - `fs.write` (`fs_write_file`)
  - `http.fetch` (`http_fetch`)
  - `kv.get` / `kv.put` (`kv_get` / `kv_put`)
  - `queue.publish` / `queue.consume` (`queue_publish` / `queue_consume`)

## Verify All Pins

```bash
./scripts/verify_pins.sh
```

Default policy enforces at least two signers backed by two unique public keys
for every pinned bundle (`MIN_SIGNERS=2`).

Optional binary override:

```bash
PROVENACT_CLI_BIN=/path/to/provenact-cli ./scripts/verify_pins.sh
```

Optional signer threshold override:

```bash
MIN_SIGNERS=2 ./scripts/verify_pins.sh
```

## Release A Skill

Recommended flow:

1. Prepare the next bundle version (unsigned):

```bash
./scripts/prepare-release.sh \
  --id echo.minimal \
  --from-version 0.1.0 \
  --to-version 0.1.1
```

2. Sign the prepared bundle:

```bash
provenact-cli sign \
  --bundle ./skills/echo.minimal/0.1.1 \
  --signer alice.dev \
  --secret-key /path/to/ed25519-secret-key.txt
```

3. Pin the signed release in lock metadata:

```bash
./scripts/release-skill.sh \
  --id echo.minimal \
  --version 0.1.1 \
  --source-bundle ./skills/echo.minimal/0.1.1
```

Options:
- `--keys-file <filename>`: defaults to `public-keys.json`
- `--substrate-commit <sha>`: override inferred substrate pin
- `--allow-replace`: overwrite existing `skills/<id>/<version>` bundle directory
