#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="$ROOT_DIR/pins/skills.lock.json"
INACTU_CLI_BIN="${INACTU_CLI_BIN:-}"

SKILL_ID=""
SKILL_VERSION=""
SOURCE_BUNDLE=""
KEYS_FILE="public-keys.json"
SUBSTRATE_COMMIT=""
ALLOW_REPLACE="false"

usage() {
  cat <<'USAGE'
usage:
  ./scripts/release-skill.sh \
    --id <skill-id> \
    --version <version> \
    --source-bundle <path> \
    [--keys-file <filename>] \
    [--substrate-commit <git-sha>] \
    [--allow-replace]

required source bundle files:
  - skill.wasm
  - manifest.json
  - signatures.json
  - public-keys.json (or --keys-file override)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id)
      SKILL_ID="${2:-}"
      shift 2
      ;;
    --version)
      SKILL_VERSION="${2:-}"
      shift 2
      ;;
    --source-bundle)
      SOURCE_BUNDLE="${2:-}"
      shift 2
      ;;
    --keys-file)
      KEYS_FILE="${2:-}"
      shift 2
      ;;
    --substrate-commit)
      SUBSTRATE_COMMIT="${2:-}"
      shift 2
      ;;
    --allow-replace)
      ALLOW_REPLACE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$SKILL_ID" || -z "$SKILL_VERSION" || -z "$SOURCE_BUNDLE" ]]; then
  echo "error: --id, --version, and --source-bundle are required" >&2
  usage
  exit 1
fi

if [[ -z "$INACTU_CLI_BIN" ]]; then
  if command -v inactu-cli >/dev/null 2>&1; then
    INACTU_CLI_BIN="inactu-cli"
  elif [[ -x "$ROOT_DIR/../inactu/target/debug/inactu-cli" ]]; then
    INACTU_CLI_BIN="$ROOT_DIR/../inactu/target/debug/inactu-cli"
  elif [[ -d "$ROOT_DIR/../inactu" ]]; then
    echo "building sibling inactu-cli..." >&2
    cargo build -p inactu-cli --manifest-path "$ROOT_DIR/../inactu/Cargo.toml" >/dev/null
    INACTU_CLI_BIN="$ROOT_DIR/../inactu/target/debug/inactu-cli"
  else
    echo "error: inactu-cli not found (set INACTU_CLI_BIN or provide ../inactu checkout)" >&2
    exit 1
  fi
fi

if ! command -v "$INACTU_CLI_BIN" >/dev/null 2>&1 && [[ ! -x "$INACTU_CLI_BIN" ]]; then
  echo "error: configured INACTU_CLI_BIN is not executable: $INACTU_CLI_BIN" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required" >&2
  exit 1
fi

SOURCE_BUNDLE_ABS="$(cd "$SOURCE_BUNDLE" && pwd)"
for f in skill.wasm manifest.json signatures.json "$KEYS_FILE"; do
  if [[ ! -f "$SOURCE_BUNDLE_ABS/$f" ]]; then
    echo "error: missing source file: $SOURCE_BUNDLE_ABS/$f" >&2
    exit 1
  fi
done

TARGET_DIR="$ROOT_DIR/skills/$SKILL_ID/$SKILL_VERSION"
if [[ -d "$TARGET_DIR" && "$ALLOW_REPLACE" != "true" ]]; then
  echo "error: target exists: $TARGET_DIR (use --allow-replace to overwrite)" >&2
  exit 1
fi
mkdir -p "$TARGET_DIR"

copy_if_needed() {
  local src="$1"
  local dst="$2"
  local src_real dst_real
  src_real="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
  dst_real="$(cd "$(dirname "$dst")" && pwd)/$(basename "$dst")"
  if [[ "$src_real" == "$dst_real" ]]; then
    return 0
  fi
  cp "$src" "$dst"
}

copy_if_needed "$SOURCE_BUNDLE_ABS/skill.wasm" "$TARGET_DIR/skill.wasm"
copy_if_needed "$SOURCE_BUNDLE_ABS/manifest.json" "$TARGET_DIR/manifest.json"
copy_if_needed "$SOURCE_BUNDLE_ABS/signatures.json" "$TARGET_DIR/signatures.json"
copy_if_needed "$SOURCE_BUNDLE_ABS/$KEYS_FILE" "$TARGET_DIR/$KEYS_FILE"

MANIFEST_NAME="$(node -pe 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).name' "$TARGET_DIR/manifest.json")"
MANIFEST_VERSION="$(node -pe 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).version' "$TARGET_DIR/manifest.json")"

if [[ "$MANIFEST_NAME" != "$SKILL_ID" ]]; then
  echo "error: manifest.name ($MANIFEST_NAME) must equal --id ($SKILL_ID)" >&2
  exit 1
fi
if [[ "$MANIFEST_VERSION" != "$SKILL_VERSION" ]]; then
  echo "error: manifest.version ($MANIFEST_VERSION) must equal --version ($SKILL_VERSION)" >&2
  exit 1
fi

KEYS_DIGEST="sha256:$(shasum -a 256 "$TARGET_DIR/$KEYS_FILE" | awk '{print $1}')"
ARTIFACT="$(node -pe 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).artifact' "$TARGET_DIR/manifest.json")"
MANIFEST_HASH="$(node -pe 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).manifest_hash' "$TARGET_DIR/signatures.json")"
SIGNERS="$(node -pe '(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).signatures || []).map(s => s.signer).sort().join(",")' "$TARGET_DIR/signatures.json")"

"$INACTU_CLI_BIN" verify \
  --bundle "$TARGET_DIR" \
  --keys "$TARGET_DIR/$KEYS_FILE" \
  --keys-digest "$KEYS_DIGEST" >/dev/null

if [[ -z "$SUBSTRATE_COMMIT" ]]; then
  if [[ -d "$ROOT_DIR/../inactu/.git" ]]; then
    SUBSTRATE_COMMIT="$(cd "$ROOT_DIR/../inactu" && git rev-parse HEAD)"
  elif [[ -f "$LOCK_FILE" ]]; then
    SUBSTRATE_COMMIT="$(node -pe 'const l=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); (l.substrate_pin&&l.substrate_pin.commit)||""' "$LOCK_FILE")"
  fi
fi

if [[ -z "$SUBSTRATE_COMMIT" ]]; then
  echo "error: could not determine substrate commit; pass --substrate-commit" >&2
  exit 1
fi

node - "$LOCK_FILE" "$SKILL_ID" "$SKILL_VERSION" "$KEYS_FILE" "$KEYS_DIGEST" "$ARTIFACT" "$MANIFEST_HASH" "$SIGNERS" "$SUBSTRATE_COMMIT" <<'NODE'
const fs = require("fs");
const lockPath = process.argv[2];
const skillId = process.argv[3];
const version = process.argv[4];
const keysFile = process.argv[5];
const keysDigest = process.argv[6];
const artifact = process.argv[7];
const manifestHash = process.argv[8];
const signers = process.argv[9] ? process.argv[9].split(",").filter(Boolean) : [];
const substrateCommit = process.argv[10];

let lock;
if (fs.existsSync(lockPath)) {
  lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
} else {
  lock = {
    schema_version: "1.0.0",
    generated_at: new Date().toISOString(),
    substrate_pin: { repo: "inactu", commit: substrateCommit },
    skills: []
  };
}

lock.schema_version = "1.0.0";
lock.generated_at = new Date().toISOString();
lock.substrate_pin = { repo: "inactu", commit: substrateCommit };
if (!Array.isArray(lock.skills)) lock.skills = [];

const bundleDir = `skills/${skillId}/${version}`;
const entry = {
  id: skillId,
  version,
  bundle_dir: bundleDir,
  artifact,
  manifest_hash: manifestHash,
  keys_file: keysFile,
  keys_digest: keysDigest,
  signers
};

const idx = lock.skills.findIndex((s) => s.id === skillId && s.version === version);
if (idx >= 0) lock.skills[idx] = entry;
else lock.skills.push(entry);

lock.skills.sort((a, b) => {
  const idCmp = String(a.id).localeCompare(String(b.id));
  if (idCmp !== 0) return idCmp;
  return String(a.version).localeCompare(String(b.version));
});

fs.writeFileSync(lockPath, JSON.stringify(lock, null, 2) + "\n");
NODE

echo "OK release-skill id=$SKILL_ID version=$SKILL_VERSION bundle=skills/$SKILL_ID/$SKILL_VERSION"
