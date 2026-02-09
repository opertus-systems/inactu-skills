#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVENACT_CLI_BIN="${PROVENACT_CLI_BIN:-}"
SIGNER_ID="${SIGNER_ID:-alice.dev}"
SECRET_KEY="${SECRET_KEY:-$ROOT_DIR/../provenact-cli/test-vectors/good/verify-run-verify-receipt/signer-secret-key.txt}"
WATC_MANIFEST="${WATC_MANIFEST:-$ROOT_DIR/tools/watc/Cargo.toml}"
source "$ROOT_DIR/scripts/lib/provenact_cli.sh"

resolve_provenact_cli "$ROOT_DIR"
if [[ ! -f "$SECRET_KEY" ]]; then
  echo "error: secret key not found: $SECRET_KEY" >&2
  exit 1
fi
if [[ ! -f "$WATC_MANIFEST" ]]; then
  echo "error: watc manifest not found: $WATC_MANIFEST" >&2
  exit 1
fi

# id|version|wat_file
SKILLS=(
  'echo.minimal|0.1.0|skills-src/echo.minimal.wat'
  'echo.minimal|0.1.1|skills-src/echo.minimal.wat'
  'http.fetch|0.1.0|skills-src/http.fetch.wat'
  'kv.get|0.1.0|skills-src/kv.get.wat'
  'kv.put|0.1.0|skills-src/kv.put.wat'
  'hash.sha256|0.1.0|skills-src/hash.sha256.wat'
  'time.now|0.1.0|skills-src/time.now.wat'
  'random.bytes|0.1.0|skills-src/random.bytes.wat'
  'json.transform|0.1.0|skills-src/json.transform.wat'
  'template.render|0.1.0|skills-src/template.render.wat'
  'fs.read|0.1.0|skills-src/fs.read.wat'
  'fs.write|0.1.0|skills-src/fs.write.wat'
  'receipt.verify|0.1.0|skills-src/receipt.verify.wat'
  'signature.verify|0.1.0|skills-src/signature.verify.wat'
  'policy.eval|0.1.0|skills-src/policy.eval.wat'
  'retry.with_backoff|0.1.0|skills-src/retry.with_backoff.wat'
  'queue.publish|0.1.0|skills-src/queue.publish.wat'
  'queue.consume|0.1.0|skills-src/queue.consume.wat'
)

for row in "${SKILLS[@]}"; do
  IFS='|' read -r ID VERSION WAT_FILE <<< "$row"
  BUNDLE_DIR="$ROOT_DIR/skills/$ID/$VERSION"
  if [[ ! -d "$BUNDLE_DIR" ]]; then
    echo "error: bundle not found: $BUNDLE_DIR" >&2
    exit 1
  fi
  if [[ ! -f "$ROOT_DIR/$WAT_FILE" ]]; then
    echo "error: wat source missing: $ROOT_DIR/$WAT_FILE" >&2
    exit 1
  fi

  TMP_DIR="$(mktemp -d)"
  TMP_WASM="$TMP_DIR/skill.wasm"
  TMP_MANIFEST="$TMP_DIR/manifest.json"

  cargo run --quiet --manifest-path "$WATC_MANIFEST" -- "$ROOT_DIR/$WAT_FILE" "$TMP_WASM" >/dev/null

  ARTIFACT="sha256:$(shasum -a 256 "$TMP_WASM" | awk '{print $1}')"

  node -e '
const fs = require("fs");
const srcPath = process.argv[1];
const outPath = process.argv[2];
const expectedId = process.argv[3];
const expectedVersion = process.argv[4];
const artifact = process.argv[5];
const m = JSON.parse(fs.readFileSync(srcPath, "utf8"));
if (m.name !== expectedId) {
  console.error(`manifest.name mismatch: ${m.name} != ${expectedId}`);
  process.exit(1);
}
if (m.version !== expectedVersion) {
  console.error(`manifest.version mismatch: ${m.version} != ${expectedVersion}`);
  process.exit(1);
}
m.artifact = artifact;
fs.writeFileSync(outPath, JSON.stringify(m, null, 2) + "\n");
' "$BUNDLE_DIR/manifest.json" "$TMP_MANIFEST" "$ID" "$VERSION" "$ARTIFACT"

  "$PROVENACT_CLI_BIN" pack --bundle "$BUNDLE_DIR" --wasm "$TMP_WASM" --manifest "$TMP_MANIFEST" >/dev/null
  "$PROVENACT_CLI_BIN" sign --bundle "$BUNDLE_DIR" --signer "$SIGNER_ID" --secret-key "$SECRET_KEY" >/dev/null
  PROVENACT_CLI_BIN="$PROVENACT_CLI_BIN" "$ROOT_DIR/scripts/release-skill.sh" --id "$ID" --version "$VERSION" --source-bundle "$BUNDLE_DIR" --allow-replace >/dev/null

  rm -rf "$TMP_DIR"
  echo "OK rebuild-skill id=$ID version=$VERSION"
done

echo "OK rebuild-real-wasm count=${#SKILLS[@]}"
