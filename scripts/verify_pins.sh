#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="$ROOT_DIR/pins/skills.lock.json"
PROVENACT_CLI_BIN="${PROVENACT_CLI_BIN:-}"
MIN_SIGNERS="${MIN_SIGNERS:-2}"
source "$ROOT_DIR/scripts/lib/provenact_cli.sh"

resolve_provenact_cli "$ROOT_DIR"

# Parse lock entries with Node for predictable JSON handling.
node -e '
const fs = require("fs");
const lock = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
for (const s of lock.skills) {
  process.stdout.write([
    s.id,
    s.version,
    s.bundle_dir,
    s.artifact,
    s.manifest_hash,
    s.keys_file,
    s.keys_digest,
    (s.signers || []).join(",")
  ].join("\t") + "\n");
}
' "$LOCK_FILE" | while IFS=$'\t' read -r ID VERSION BUNDLE_DIR EXPECT_ARTIFACT EXPECT_MANIFEST_HASH KEYS_FILE EXPECT_KEYS_DIGEST EXPECT_SIGNERS; do
  if [[ ! "$KEYS_FILE" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "error: lock entry $ID@$VERSION has invalid keys_file: $KEYS_FILE" >&2
    exit 1
  fi
  BUNDLE_PATH="$ROOT_DIR/$BUNDLE_DIR"
  KEYS_PATH="$BUNDLE_PATH/$KEYS_FILE"

  echo "verifying $ID@$VERSION"

  "$PROVENACT_CLI_BIN" verify \
    --bundle "$BUNDLE_PATH" \
    --keys "$KEYS_PATH" \
    --keys-digest "$EXPECT_KEYS_DIGEST" >/dev/null

  MANIFEST_ARTIFACT="$(node -pe 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).artifact' "$BUNDLE_PATH/manifest.json")"
  SIG_MANIFEST_HASH="$(node -pe 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).manifest_hash' "$BUNDLE_PATH/signatures.json")"
  SIGNERS_ACTUAL="$(node -pe '(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).signatures || []).map(s => s.signer).sort().join(",")' "$BUNDLE_PATH/signatures.json")"
  SIGNER_COUNT="$(node -pe '(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).signatures || []).map(s => s.signer).filter(Boolean).length' "$BUNDLE_PATH/signatures.json")"
  UNIQUE_SIGNER_KEYS="$(node -e '
const keys=JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const signs=(JSON.parse(require("fs").readFileSync(process.argv[2], "utf8")).signatures || []);
const vals=signs.map(s => keys[s.signer]).filter(Boolean);
console.log(new Set(vals).size);
' "$KEYS_PATH" "$BUNDLE_PATH/signatures.json")"

  if [[ "$MANIFEST_ARTIFACT" != "$EXPECT_ARTIFACT" ]]; then
    echo "error: $ID@$VERSION artifact mismatch" >&2
    exit 1
  fi

  if [[ "$SIG_MANIFEST_HASH" != "$EXPECT_MANIFEST_HASH" ]]; then
    echo "error: $ID@$VERSION manifest_hash mismatch" >&2
    exit 1
  fi

  if [[ "$SIGNERS_ACTUAL" != "$EXPECT_SIGNERS" ]]; then
    echo "error: $ID@$VERSION signer set mismatch" >&2
    exit 1
  fi

  if [[ "$SIGNER_COUNT" -lt "$MIN_SIGNERS" ]]; then
    echo "error: $ID@$VERSION signer count $SIGNER_COUNT is below minimum $MIN_SIGNERS" >&2
    exit 1
  fi

  if [[ "$UNIQUE_SIGNER_KEYS" -lt "$MIN_SIGNERS" ]]; then
    echo "error: $ID@$VERSION has fewer than $MIN_SIGNERS unique signer keys" >&2
    exit 1
  fi

done

echo "OK verify-pins count=$(node -pe 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).skills.length' "$LOCK_FILE")"
