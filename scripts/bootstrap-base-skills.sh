#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVENACT_CLI_BIN="${PROVENACT_CLI_BIN:-}"
PROVENACT_ROOT="${PROVENACT_ROOT:-$ROOT_DIR/../provenact-cli}"
VERSION="${VERSION:-0.1.0}"
SIGNER_ID="${SIGNER_ID:-alice.dev}"
SECRET_KEY="${SECRET_KEY:-$PROVENACT_ROOT/test-vectors/good/verify-run-verify-receipt/signer-secret-key.txt}"
TEMPLATE_WASM="${TEMPLATE_WASM:-$PROVENACT_ROOT/test-vectors/good/minimal-zero-cap/skill.wasm}"
TEMPLATE_KEYS="${TEMPLATE_KEYS:-$PROVENACT_ROOT/test-vectors/good/minimal-zero-cap/public-keys.json}"
WATC_MANIFEST="${WATC_MANIFEST:-$ROOT_DIR/tools/watc/Cargo.toml}"
source "$ROOT_DIR/scripts/lib/provenact_cli.sh"

resolve_provenact_cli "$ROOT_DIR" "$PROVENACT_ROOT"
if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required" >&2
  exit 1
fi
for f in "$SECRET_KEY" "$TEMPLATE_KEYS" "$WATC_MANIFEST"; do
  if [[ ! -f "$f" ]]; then
    echo "error: missing required file: $f" >&2
    exit 1
  fi
done

# id|capabilities_json|wat_path
SKILLS=(
  'http.fetch|[{"kind":"net.http","value":"https://example.com/"}]|skills-src/http.fetch.wat'
  'kv.get|[{"kind":"kv.read","value":"*"}]|skills-src/kv.get.wat'
  'kv.put|[{"kind":"kv.write","value":"*"}]|skills-src/kv.put.wat'
  'hash.sha256|[]|skills-src/hash.sha256.wat'
  'time.now|[{"kind":"time.now","value":"utc"}]|skills-src/time.now.wat'
  'random.bytes|[{"kind":"random.bytes","value":"bounded"}]|skills-src/random.bytes.wat'
  'json.transform|[]|skills-src/json.transform.wat'
  'template.render|[]|skills-src/template.render.wat'
  'fs.read|[{"kind":"fs.read","value":"/tmp/provenact-fs"}]|skills-src/fs.read.wat'
  'fs.write|[{"kind":"fs.write","value":"/tmp/provenact-fs"}]|skills-src/fs.write.wat'
  'receipt.verify|[]|skills-src/receipt.verify.wat'
  'signature.verify|[]|skills-src/signature.verify.wat'
  'policy.eval|[]|skills-src/policy.eval.wat'
  'retry.with_backoff|[]|skills-src/retry.with_backoff.wat'
  'queue.publish|[{"kind":"queue.publish","value":"*"}]|skills-src/queue.publish.wat'
  'queue.consume|[{"kind":"queue.consume","value":"*"}]|skills-src/queue.consume.wat'
)

for row in "${SKILLS[@]}"; do
  IFS='|' read -r ID CAPS WAT_PATH <<< "$row"
  TARGET_DIR="$ROOT_DIR/skills/$ID/$VERSION"
  mkdir -p "$TARGET_DIR"
  if [[ ! -f "$ROOT_DIR/$WAT_PATH" ]]; then
    echo "error: missing wat source: $ROOT_DIR/$WAT_PATH" >&2
    exit 1
  fi

  TMP_WASM="$(mktemp)"
  cargo run --quiet --manifest-path "$WATC_MANIFEST" -- "$ROOT_DIR/$WAT_PATH" "$TMP_WASM" >/dev/null
  ARTIFACT="sha256:$(shasum -a 256 "$TMP_WASM" | awk '{print $1}')"
  TMP_MANIFEST="$(mktemp)"
  node -e '
const fs = require("fs");
const out = process.argv[1];
const id = process.argv[2];
const version = process.argv[3];
const artifact = process.argv[4];
const signer = process.argv[5];
const capabilities = JSON.parse(process.argv[6]);
const manifest = {
  name: id,
  version,
  entrypoint: "run",
  artifact,
  capabilities,
  signers: [signer]
};
fs.writeFileSync(out, JSON.stringify(manifest, null, 2) + "\n");
' "$TMP_MANIFEST" "$ID" "$VERSION" "$ARTIFACT" "$SIGNER_ID" "$CAPS"

  "$PROVENACT_CLI_BIN" pack \
    --bundle "$TARGET_DIR" \
    --wasm "$TMP_WASM" \
    --manifest "$TMP_MANIFEST" >/dev/null
  rm -f "$TMP_MANIFEST" "$TMP_WASM"

  cp "$TEMPLATE_KEYS" "$TARGET_DIR/public-keys.json"

  "$PROVENACT_CLI_BIN" sign \
    --bundle "$TARGET_DIR" \
    --signer "$SIGNER_ID" \
    --secret-key "$SECRET_KEY" >/dev/null

  PROVENACT_CLI_BIN="$PROVENACT_CLI_BIN" "$ROOT_DIR/scripts/release-skill.sh" \
    --id "$ID" \
    --version "$VERSION" \
    --source-bundle "$TARGET_DIR" \
    --allow-replace >/dev/null

  echo "OK bootstrap-skill id=$ID version=$VERSION"
done

echo "OK bootstrap-base-skills count=${#SKILLS[@]} version=$VERSION"
