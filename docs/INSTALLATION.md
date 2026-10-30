# Cài đặt

## Yêu cầu
- Windows 10/11, Windows PowerShell 5.1 trở lên (PowerShell 7 cũng chạy được). Không cần Administrator.
- Claude Code CLI **hoặc** Claude Desktop (tab Code). Cả hai dùng chung thư mục `~\.claude`. Script chỉ cảnh báo nếu không thấy CLI.
- Git (để clone repo).

## Máy hiện tại (đã có cấu hình)
```powershell
cd claude-environment
.\scripts\backup.ps1                 # snapshot an toàn
.\scripts\update.ps1 -DryRun         # xem lệch gì (ở máy gốc sẽ báo "đã khớp")
.\scripts\backup.ps1 -ToRepo         # sau khi bạn sửa agent/skill/CLAUDE.md, đưa ngược vào repo
.\scripts\validate.ps1 -Scope Repo ; git diff ; git commit
```

## Máy Windows mới
1. Cài Claude (Desktop và/hoặc CLI), đăng nhập một lần.
2. `git clone <url> claude-environment ; cd claude-environment`
3. `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -DryRun` rồi chạy lại không có `-DryRun`.
4. `.\scripts\validate.ps1`.
5. Mở phiên mới (cấu hình đọc lại khi phiên mới bắt đầu).

Rollback: lệnh `restore.ps1 -From '<thư mục backup>'` được in ở cuối install. Restore cũng xóa các file mà install đã tạo mới và khôi phục `settings.json` gốc.

## Phân loại thành phần (kết quả kiểm kê thực tế)

| Thành phần | Loại | Xử lý |
|---|---|---|
| `CLAUDE.md` global | Portable | Tự động |
| `agents/*.md` (7) | Portable | Tự động |
| `skills/*/SKILL.md` (7) | Portable | Tự động |
| `templates/project-CLAUDE.md` | Portable | Tự động |
| `settings.json`: `permissions`, `model` | Portable | Tự động, merge |
| `settings.json`: `theme` | Machine-specific | Chép tay từ `machine/settings.example.json` nếu muốn |
| `.credentials.json`, đăng nhập Max | Account + Secret | **Đăng nhập lại**; không bao giờ đóng gói |
| `~\.claude.json` (userID, oauth, cache, 5 project) | Account/Secret/Machine | Không đóng gói |
| `skills\synced\*` (artifact-emulator, docx, pdf…) | Account-specific | Tự đồng bộ khi đăng nhập lại; không đóng gói |
| Plugins (marketplace `claude-plugins-official`, plugin `engineering`) | Account-specific | Cài lại trong app; cache không đóng gói |
| MCP của plugin `engineering` (Asana, Atlassian, Datadog, GitHub, Linear, Notion, PagerDuty, Slack) | Account-specific | Cần OAuth qua `/mcp`; script không tự cấp |
| MCP cấp user (`mcpServers`) | — | **Không có** trên máy gốc (đã kiểm tra) |
| Hooks | — | **Không có** trên máy gốc; `global/hooks/` hỗ trợ sẵn nếu sau này thêm |
| `.claude/` hay `CLAUDE.md` trong 4 project gần đây | — | Không có |
| `team-setup/README.md` | Machine-specific | Thay bằng docs này (có đường dẫn máy cũ) |
| `projects/ sessions/ file-history/ shell-snapshots/ session-env/ plans/ cache/ ide/` | Lịch sử/cache | Không đóng gói |
| `backups/` | Dữ liệu cục bộ | Không đóng gói |

## Checklist thủ công sau khi cài
- [ ] Đăng nhập tài khoản Max (CLI: `claude` rồi `/login`; không đặt `ANTHROPIC_API_KEY` để tránh tính phí API).
- [ ] Claude Desktop, tab Code: kiểm tra bộ chọn model có đang ở chế độ mong muốn (`opusplan` trong `settings.json` là mặc định cho CLI/VS Code; Desktop có bộ chọn riêng).
- [ ] Cài lại plugin/MCP cần dùng và tự cấp quyền OAuth.
- [ ] (Tùy chọn) đặt `theme`.
- [ ] Mở phiên mới và thử `/feature-workflow`.
