# Changelog

## 1.0.0 - 2026-08-26

- Added a pinned and signature-checked MouseMux V3 installer workflow.
- Added loopback-only Input Mapper MCP validation.
- Added safe, idempotent Codex TOML configuration with backups.
- Added tool-name validation to prevent TOML configuration injection.
- Added canonical install and uninstall path-boundary checks.
- Added strict, fail-closed MouseMux process identity and current-user ownership checks.
- Added separate vendor and non-elevated current-user emergency controls.
- Removed the prerelease elevated scheduled-task design.
- Added input-device discovery, sandbox launch, verification, and uninstall scripts.
- Added Cursor skill, setup auditor, security model, and acceptance test.
