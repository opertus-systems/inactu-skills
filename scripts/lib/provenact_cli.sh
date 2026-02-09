#!/usr/bin/env bash

resolve_provenact_cli() {
  local root_dir="$1"
  local provenact_root="${2:-$root_dir/../provenact-cli}"

  if [[ -z "${PROVENACT_CLI_BIN:-}" ]]; then
    if command -v provenact-cli >/dev/null 2>&1; then
      PROVENACT_CLI_BIN="provenact-cli"
    elif [[ -x "$provenact_root/target/debug/provenact-cli" ]]; then
      PROVENACT_CLI_BIN="$provenact_root/target/debug/provenact-cli"
    elif [[ -d "$provenact_root" ]]; then
      echo "building provenact-cli..." >&2
      cargo build -p provenact-cli --manifest-path "$provenact_root/Cargo.toml" >/dev/null
      PROVENACT_CLI_BIN="$provenact_root/target/debug/provenact-cli"
    else
      echo "error: provenact-cli not found (set PROVENACT_CLI_BIN or provide provenact-cli checkout)" >&2
      return 1
    fi
  fi

  if ! command -v "$PROVENACT_CLI_BIN" >/dev/null 2>&1 && [[ ! -x "$PROVENACT_CLI_BIN" ]]; then
    echo "error: configured PROVENACT_CLI_BIN is not executable: $PROVENACT_CLI_BIN" >&2
    return 1
  fi

  return 0
}
