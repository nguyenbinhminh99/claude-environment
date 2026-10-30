# claude-environment

Bộ đóng gói môi trường **Claude Code dùng chung cho mọi repository** (global `CLAUDE.md`, 7 subagents, 7 skills, permissions, model routing) để backup, cài lại trên máy Windows mới, cập nhật và rollback.

Không chứa: credentials, token, lịch sử hội thoại, dữ liệu dự án, cấu hình MCP/plugin gắn tài khoản.

## Dùng nhanh (máy mới)

```powershell
git clone <url-repo> claude-environment
cd claude-environment
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
# rồi đăng nhập Claude (Desktop hoặc `claude` -> /login) và chạy:
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1
```

`-ExecutionPolicy Bypass` chỉ áp dụng cho tiến trình đó, không đổi cấu hình hệ thống. Không cần quyền Administrator.

## Lệnh thường dùng

| Việc | Lệnh |
|---|---|
| Xem trước, không ghi gì | `.\scripts\install.ps1 -DryRun` |
| Cài toàn bộ (hỏi xác nhận) | `.\scripts\install.ps1` |
| Cài không hỏi | `.\scripts\install.ps1 -Yes` |
| Chỉ agents / skills | `.\scripts\install.ps1 -Component agents` / `skills` |
| Chỉ global CLAUDE.md | `.\scripts\install.ps1 -Component instructions` |
| Chỉ model routing | `.\scripts\install.ps1 -Component routing` |
| Backup cấu hình hiện tại | `.\scripts\backup.ps1` |
| Đưa cấu hình đang dùng vào repo | `.\scripts\backup.ps1 -ToRepo` |
| So sánh + cập nhật | `.\scripts\update.ps1` (thêm `-DryRun` để chỉ xem) |
| Liệt kê / khôi phục backup | `.\scripts\restore.ps1 -List` / `-From latest` |
| Kiểm tra | `.\scripts\validate.ps1` (`-Scope Repo` hoặc `Installed`) |
| Gỡ phần đã cài | `.\scripts\uninstall.ps1` |
| Chạy bộ test (thư mục tạm) | `.\tests\run-tests.ps1` |

Chọn nhiều thành phần: `-Component "agents,skills"`. Thành phần: `instructions, agents, skills, templates, hooks, routing, permissions, settings`.

## Nguyên tắc an toàn của script

- Luôn backup vào `~\.claude\backups\claude-environment\<timestamp>-<label>\` trước khi ghi; in lệnh rollback.
- Chạy lại nhiều lần cho cùng kết quả (idempotent); file giống hệt thì bỏ qua.
- File bạn đã sửa sau khi cài (`Customized`) hoặc file đã có sẵn nhưng không do tool cài (`Conflict`) **được giữ nguyên** trừ khi bạn xác nhận từng file, hoặc dùng `-Yes -Force`.
- `settings.json` được **merge**: danh sách `deny/ask` là hợp của cả hai bên, key khác (theme, env, allow…) giữ nguyên. Không tự thêm quyền `allow`.
- Không bao giờ đọc/ghi `.credentials.json`, `~\.claude.json`, `projects`, `skills\synced`.
- Không cài MCP server hay plugin.

Chi tiết: [docs/INSTALLATION.md](docs/INSTALLATION.md) · [CONFIGURATION](docs/CONFIGURATION.md) · [MODEL-ROUTING](docs/MODEL-ROUTING.md) · [SECURITY](docs/SECURITY.md) · [TROUBLESHOOTING](docs/TROUBLESHOOTING.md)

## Thêm agent / skill / quy tắc mới

Chỉ cần thêm file vào `global/agents/<ten>.md` hoặc `global/skills/<ten>/SKILL.md` (script tự phát hiện theo thư mục, không cần sửa manifest). Sau đó `validate.ps1 -Scope Repo`, rồi commit. Bật hook kiểm tra secret trước commit: `git config core.hooksPath .githooks`.
