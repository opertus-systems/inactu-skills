# Default Skill Bundle v0 Specification

Status: Draft for implementation in `provenact-skills`

## Goal

Provide a minimal, auditor-defensible default skill set for day-one coding workflows while preserving strict safety boundaries.

## Scope

### Mandatory v0 skill IDs

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

### Explicitly out of scope for v0

- `git.commit`
- `git.push`
- unrestricted shell execution
- arbitrary file writes
- long-lived daemons
- implicit background execution

## Shared invariants (all skills)

- Deterministic, bounded output with truncation flags.
- Host-enforced allowlists for paths/domains/commands.
- No ambient credentials.
- Every invocation is auditable (request envelope + policy outcome + result metadata).
- No network unless capability explicitly permits it.

## Request/response contracts

### `fs.read_text`

Request:

```json
{
  "path": "string",
  "max_bytes": 65536,
  "encoding": "utf-8"
}
```

Response:

```json
{
  "path": "string",
  "text": "string",
  "bytes_read": 1234,
  "truncated": false,
  "normalized_encoding": "utf-8"
}
```

### `fs.read_tree`

Request:

```json
{
  "root": "string",
  "max_entries": 2000,
  "max_depth": 8,
  "include_hidden": false
}
```

Response:

```json
{
  "root": "string",
  "entries": [
    {"path": "src/main.rs", "kind": "file", "bytes": 2312}
  ],
  "truncated": false
}
```

### `fs.write_patch`

Request:

```json
{
  "base": "optional path",
  "unified_diff": "string"
}
```

Response:

```json
{
  "applied": true,
  "files_changed": 2,
  "hunks_applied": 8,
  "rejects": []
}
```

### `shell.exec_safe`

Request:

```json
{
  "argv": ["npm", "test"],
  "cwd": ".",
  "timeout_ms": 120000,
  "max_output_bytes": 65536
}
```

Response:

```json
{
  "exit_code": 0,
  "stdout": "...",
  "stderr": "...",
  "stdout_truncated": false,
  "stderr_truncated": false,
  "duration_ms": 8123
}
```

### `search.ripgrep`

Request:

```json
{
  "pattern": "TODO",
  "paths": ["."],
  "glob": ["*.rs"],
  "case_sensitive": false,
  "max_matches": 500
}
```

Response:

```json
{
  "matches": [
    {
      "file": "src/lib.rs",
      "line": 42,
      "column": 7,
      "match": "TODO",
      "context_before": "...",
      "context_after": "..."
    }
  ],
  "truncated": false
}
```

### `git.status`

Request:

```json
{}
```

Response:

```json
{
  "branch": "feature/x",
  "ahead": 1,
  "behind": 0,
  "staged": ["a.txt"],
  "unstaged": ["b.txt"],
  "untracked": ["c.txt"]
}
```

### `git.diff`

Request:

```json
{
  "target": "working|staged|commit",
  "commit": "optional sha",
  "max_bytes": 131072
}
```

Response:

```json
{
  "diff": "unified diff text",
  "bytes": 8192,
  "truncated": false
}
```

### `http.fetch_text`

Request:

```json
{
  "url": "https://example.com/spec.md",
  "max_bytes": 131072
}
```

Response:

```json
{
  "url": "https://example.com/spec.md",
  "final_url": "https://example.com/spec.md",
  "status": 200,
  "mime": "text/markdown",
  "text": "...",
  "bytes": 5321,
  "truncated": false
}
```

### `json.validate`

Request:

```json
{
  "json": "string",
  "schema": {"type": "object"}
}
```

Response:

```json
{
  "valid": true,
  "errors": []
}
```

### `extract.text`

Request:

```json
{
  "content_type": "text/html|text/markdown|application/pdf",
  "bytes_b64": "base64-encoded payload"
}
```

Response:

```json
{
  "text": "normalized text",
  "hints": {"title": "optional", "sections": []}
}
```

## Capability model

Each skill manifest MUST declare only the minimal capability set required.

- `fs.read_text`: `fs.read`
- `fs.read_tree`: `fs.read` (tree traversal via dedicated hostcall)
- `http.fetch_text`: `net.http`
- ABI-blocked placeholder skills use `[]` until hostcalls exist:
  `fs.write_patch`, `shell.exec_safe`, `search.ripgrep`, `git.status`,
  `git.diff`, `json.validate`, `extract.text`

## ABI mapping status in this repository

Implemented on current hostcalls:

- `fs.read_text` via `fs_read_file`
- `fs.read_tree` via `fs_read_tree`
- `http.fetch_text` via `http_fetch`

ABI-blocked until runtime hostcall support is added:

- `fs.write_patch`
- `shell.exec_safe`
- `search.ripgrep`
- `git.status`
- `git.diff`
- `json.validate`
- `extract.text`

For ABI-blocked skills, this repo currently ships deterministic placeholder Wasm modules that return a non-zero code and write a short `UNIMPLEMENTED_HOSTCALL` marker.

## Rollout notes

- Keep versions at `0.1.0` for first release of each new skill ID.
- Pin each bundle in `pins/skills.lock.json` only after signing policy is satisfied.
- Require `scripts/verify_pins.sh` to pass before merge.
