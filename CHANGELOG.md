# Changelog

## 1.0.0 - 2026-10-30
- Đóng gói lần đầu từ cấu hình đang dùng: global `CLAUDE.md`, 7 agents, 7 skills, template `project-CLAUDE.md`, `settings.json` (permissions + `model: opusplan`).
- Scripts: install, update, backup (+ `-ToRepo`), restore, validate, uninstall; bộ test `tests/run-tests.ps1`.
- Chủ ý không đóng gói: `theme` (machine), `team-setup/README.md` (chứa đường dẫn máy cũ, được thay bằng docs/), credentials, `.claude.json`, plugins, skills đồng bộ từ tài khoản.
