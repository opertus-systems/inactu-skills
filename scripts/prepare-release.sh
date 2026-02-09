#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVENACT_CLI_BIN="${PROVENACT_CLI_BIN:-}"
source "$ROOT_DIR/scripts/lib/provenact_cli.sh"

SKILL_ID=""
FROM_VERSION=""
TO_VERSION=""
KEYS_FILE="public-keys.json"
ALLOW_REPLACE="false"
ALLOW_EXPERIMENTAL="false"

usage() {
  cat <<'USAGE'
usage:
  ./scripts/prepare-release.sh \
    --id <skill-id> \
    --from-version <version> \
    --to-version <version> \
    [--keys-file <filename>] \
    [--allow-replace] \
    [--allow-experimental]

This command scaffolds an unsigned next-version bundle under:
  skills/<id>/<to-version>

It copies:
  - skill.wasm
  - public-keys.json (or --keys-file override)

And regenerates:
  - manifest.json (version set to --to-version)
  - signatures.json (unsigned scaffold via provenact-cli pack)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id)
      SKILL_ID="${2:-}"
      shift 2
      ;;
    --from-version)
      FROM_VERSION="${2:-}"
      shift 2
      ;;
    --to-version)
      TO_VERSION="${2:-}"
      shift 2
      ;;
    --keys-file)
      KEYS_FILE="${2:-}"
      shift 2
      ;;
    --allow-replace)
      ALLOW_REPLACE="true"
      shift
      ;;
    --allow-experimental)
      ALLOW_EXPERIMENTAL="true"
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

if [[ -z "$SKILL_ID" || -z "$FROM_VERSION" || -z "$TO_VERSION" ]]; then
  echo "error: --id, --from-version, and --to-version are required" >&2
  usage
  exit 1
fi

if [[ ! "$SKILL_ID" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
  echo "error: --id must match ^[a-z0-9][a-z0-9._-]*$" >&2
  exit 1
fi
if [[ ! "$FROM_VERSION" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
  echo "error: --from-version must match ^[a-z0-9][a-z0-9._-]*$" >&2
  exit 1
fi
if [[ ! "$TO_VERSION" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
  echo "error: --to-version must match ^[a-z0-9][a-z0-9._-]*$" >&2
  exit 1
fi

resolve_provenact_cli "$ROOT_DIR"

if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required" >&2
  exit 1
fi

SOURCE_DIR="$ROOT_DIR/skills/$SKILL_ID/$FROM_VERSION"
TARGET_DIR="$ROOT_DIR/skills/$SKILL_ID/$TO_VERSION"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "error: source bundle not found: $SOURCE_DIR" >&2
  exit 1
fi

for f in skill.wasm manifest.json "$KEYS_FILE"; do
  if [[ ! -f "$SOURCE_DIR/$f" ]]; then
    echo "error: missing source file: $SOURCE_DIR/$f" >&2
    exit 1
  fi
done

if [[ -d "$TARGET_DIR" && "$ALLOW_REPLACE" != "true" ]]; then
  echo "error: target exists: $TARGET_DIR (use --allow-replace to overwrite)" >&2
  exit 1
fi

if [[ -d "$TARGET_DIR" && "$ALLOW_REPLACE" == "true" ]]; then
  rm -rf "$TARGET_DIR"
fi
mkdir -p "$TARGET_DIR"

TMP_MANIFEST="$(mktemp)"
trap 'rm -f "$TMP_MANIFEST"' EXIT

node -e '
const fs = require("fs");
const src = process.argv[1];
const out = process.argv[2];
const expectedId = process.argv[3];
const nextVersion = process.argv[4];
const manifest = JSON.parse(fs.readFileSync(src, "utf8"));
if (manifest.name !== expectedId) {
  console.error(`error: manifest.name (${manifest.name}) must equal --id (${expectedId})`);
  process.exit(1);
}
manifest.version = nextVersion;
fs.writeFileSync(out, JSON.stringify(manifest, null, 2) + "\n");
' "$SOURCE_DIR/manifest.json" "$TMP_MANIFEST" "$SKILL_ID" "$TO_VERSION"

PACK_ARGS=(
  pack
  --bundle "$TARGET_DIR"
  --wasm "$SOURCE_DIR/skill.wasm"
  --manifest "$TMP_MANIFEST"
)
if [[ "$ALLOW_EXPERIMENTAL" == "true" ]]; then
  PACK_ARGS+=(--allow-experimental)
fi
"$PROVENACT_CLI_BIN" "${PACK_ARGS[@]}" >/dev/null

cp "$SOURCE_DIR/$KEYS_FILE" "$TARGET_DIR/$KEYS_FILE"

SIGNATURE_COUNT="$(node -pe '(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).signatures || []).length' "$TARGET_DIR/signatures.json")"
if [[ "$SIGNATURE_COUNT" != "0" ]]; then
  echo "error: expected unsigned scaffold, got signatures=$SIGNATURE_COUNT" >&2
  exit 1
fi

echo "OK prepare-release id=$SKILL_ID from=$FROM_VERSION to=$TO_VERSION bundle=skills/$SKILL_ID/$TO_VERSION"
echo "next:"
echo "  $PROVENACT_CLI_BIN sign --bundle \"$TARGET_DIR\" --signer <signer-id> --secret-key <secret-key-file>"
echo "  ./scripts/release-skill.sh --id \"$SKILL_ID\" --version \"$TO_VERSION\" --source-bundle \"$TARGET_DIR\""
