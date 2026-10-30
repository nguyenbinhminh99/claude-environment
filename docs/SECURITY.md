# Bảo mật

## Không bao giờ đưa vào repo
API key, access token, mật khẩu, SSH key, `.credentials.json`, `~\.claude.json`, `.env*`, `*.pem`, lịch sử hội thoại, dữ liệu dự án công ty. `.gitignore` chặn các mẫu này.

## Kiểm tra tự động
- `validate.ps1 -Scope Repo` quét toàn repo: mẫu key (Anthropic, OpenAI-style, GitHub, AWS, Slack, JWT, khối private key), gán `password/token/secret = <giá trị dài>`, tên file nhạy cảm. **Không in giá trị tìm thấy**, chỉ in tên loại và file. Có FAIL (exit 1) nếu phát hiện.
- Bật chặn trước khi commit: `git config core.hooksPath .githooks`.
- `backup.ps1` mặc định bỏ qua file nghi chứa secret; `-IncludeFlagged` mới ghi đè. Backup an toàn nội bộ của install/restore/uninstall nằm cục bộ trong `~\.claude\backups`, không nằm trong repo.
- Quét chỉ là heuristic; hãy đọc `git diff` trước khi commit.

## Quyền hạn
- `permissions.deny` chặn đọc `.env*`, `~/.ssh`, `~/.aws`, `~/.azure`, docker config, `.npmrc`, `.git-credentials`, `.credentials.json`, `*.pem`, `id_rsa*`, `id_ed25519*`.
- `permissions.ask` buộc hỏi cho push, reset --hard, clean, tag, merge PR, release, publish, `rm -r`, migrate:fresh/rollback, db:wipe, terraform apply/destroy, kubectl apply/delete, deploy (vercel, netlify, firebase, wrangler), `Remove-Item`.
- `disableBypassPermissionsMode: "disable"`.
- Script **không thêm bất kỳ mục `allow` nào**; `validate.ps1` FAIL nếu `allow` chứa `Bash(*)`/`PowerShell(*)` hoặc thiếu các mục deny/ask bắt buộc.
- Merge chỉ thêm vào `deny/ask`, nên không thể làm yếu cấu hình sẵn có của máy đích.
- Không cài MCP server, plugin hay cấp OAuth. `machine/mcp.example.json` chỉ là mẫu với biến môi trường giữ chỗ.

## Giới hạn đã biết
- Quy tắc `deny` chặn công cụ Read và lệnh shell đơn giản; một script gián tiếp mở file bí mật không đảm bảo bị chặn (phần còn lại dựa vào chỉ dẫn trong `CLAUDE.md`).
- Chạy script nghĩa là tin nội dung repo: hãy `git pull` từ nguồn bạn tin và đọc `update.ps1 -DryRun` trước.
- `-Yes -Force` ghi đè file bạn đã sửa (sau khi backup).
