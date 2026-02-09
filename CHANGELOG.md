# Changelog

All notable changes to this project will be documented in this file.

## 0.1.1

- Added placeholder default-bundle releases for:
  `fs.write_patch`, `shell.exec_safe`, `search.ripgrep`, `git.status`,
  `git.diff`, `json.validate`, `extract.text`.
- These new placeholder versions (`0.1.1`) keep historical `0.1.0` bundles
  intact and switch manifest capabilities to `[]` until runtime hostcalls
  exist for those IDs.
- Updated `pins/skills.lock.json` with the new signed releases.

## 0.1.0

- Initial repository bootstrap with pinned skill bundles.
- Lockfile verification workflow and scripts.
- Base skills bootstrap and release utility scripts.
