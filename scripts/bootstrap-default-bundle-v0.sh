#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVENACT_CLI_BIN="${PROVENACT_CLI_BIN:-}"
PROVENACT_ROOT="${PROVENACT_ROOT:-$ROOT_DIR/../provenact-cli}"
VERSION="${VERSION:-0.1.0}"
SIGNER_ID="${SIGNER_ID:-alice.dev}"
SECOND_SIGNER_ID="${SECOND_SIGNER_ID:-codex.release}"
SECRET_KEY="${SECRET_KEY:-$PROVENACT_ROOT/test-vectors/good/verify-run-verify-receipt/signer-secret-key.txt}"
TEMPLATE_KEYS="${TEMPLATE_KEYS:-$PROVENACT_ROOT/test-vectors/good/minimal-zero-cap/public-keys.json}"
WATC_MANIFEST="${WATC_MANIFEST:-$ROOT_DIR/tools/watc/Cargo.toml}"
MIN_SIGNERS="${MIN_SIGNERS:-2}"
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

TMP_SECOND_SECRET="$(mktemp)"
TMP_SECOND_PUB="$(mktemp)"
cleanup() {
  rm -f "$TMP_SECOND_SECRET" "$TMP_SECOND_PUB"
}
trap cleanup EXIT

python3 - "$TMP_SECOND_SECRET" "$TMP_SECOND_PUB" <<'PY'
import base64
import os
import sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

secret_path = sys.argv[1]
pub_path = sys.argv[2]
seed = os.urandom(32)
priv = Ed25519PrivateKey.from_private_bytes(seed)
pub = priv.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
with open(secret_path, "w", encoding="utf-8") as f:
    f.write(base64.b64encode(seed).decode("ascii") + "\n")
with open(pub_path, "w", encoding="utf-8") as f:
    f.write(base64.b64encode(pub).decode("ascii") + "\n")
PY
SECOND_SIGNER_PUB="$(cat "$TMP_SECOND_PUB")"

# id|capabilities_json|wat_path
SKILLS=(
  'fs.read_text|[{"kind":"fs.read","value":"/tmp/provenact-fs"}]|skills-src/fs.read_text.wat'
  'fs.read_tree|[{"kind":"fs.read","value":"/tmp/provenact-fs"}]|skills-src/fs.read_tree.wat'
  # Placeholder stubs keep an empty capability set until hostcalls are implemented in the runtime.
  'fs.write_patch|[]|skills-src/unimplemented.hostcall.wat'
  'shell.exec_safe|[]|skills-src/unimplemented.hostcall.wat'
  'search.ripgrep|[]|skills-src/unimplemented.hostcall.wat'
  'git.status|[]|skills-src/unimplemented.hostcall.wat'
  'git.diff|[]|skills-src/unimplemented.hostcall.wat'
  'http.fetch_text|[{"kind":"net.http","value":"https://example.com/"}]|skills-src/http.fetch_text.wat'
  'json.validate|[]|skills-src/unimplemented.hostcall.wat'
  'extract.text|[]|skills-src/unimplemented.hostcall.wat'
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
const secondSigner = process.argv[6];
const capabilities = JSON.parse(process.argv[7]);
const manifest = {
  name: id,
  version,
  entrypoint: "run",
  artifact,
  capabilities,
  signers: [signer, secondSigner]
};
fs.writeFileSync(out, JSON.stringify(manifest, null, 2) + "\n");
' "$TMP_MANIFEST" "$ID" "$VERSION" "$ARTIFACT" "$SIGNER_ID" "$SECOND_SIGNER_ID" "$CAPS"

  "$PROVENACT_CLI_BIN" pack \
    --bundle "$TARGET_DIR" \
    --wasm "$TMP_WASM" \
    --manifest "$TMP_MANIFEST" >/dev/null
  rm -f "$TMP_MANIFEST" "$TMP_WASM"

  node -e '
const fs = require("fs");
const inPath = process.argv[1];
const outPath = process.argv[2];
const signer = process.argv[3];
const pub = process.argv[4];
const keys = JSON.parse(fs.readFileSync(inPath, "utf8"));
keys[signer] = pub;
fs.writeFileSync(outPath, JSON.stringify(keys, null, 2) + "\n");
' "$TEMPLATE_KEYS" "$TARGET_DIR/public-keys.json" "$SECOND_SIGNER_ID" "$SECOND_SIGNER_PUB"

  "$PROVENACT_CLI_BIN" sign \
    --bundle "$TARGET_DIR" \
    --signer "$SIGNER_ID" \
    --secret-key "$SECRET_KEY" >/dev/null
  "$PROVENACT_CLI_BIN" sign \
    --bundle "$TARGET_DIR" \
    --signer "$SECOND_SIGNER_ID" \
    --secret-key "$TMP_SECOND_SECRET" >/dev/null

  MIN_SIGNERS="$MIN_SIGNERS" PROVENACT_CLI_BIN="$PROVENACT_CLI_BIN" "$ROOT_DIR/scripts/release-skill.sh" \
    --id "$ID" \
    --version "$VERSION" \
    --source-bundle "$TARGET_DIR" \
    --allow-replace >/dev/null

  echo "OK bootstrap-v0-skill id=$ID version=$VERSION"
done

echo "OK bootstrap-default-bundle-v0 count=${#SKILLS[@]} version=$VERSION"
