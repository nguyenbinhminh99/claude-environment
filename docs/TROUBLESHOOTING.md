# Xử lý sự cố

| Triệu chứng | Nguyên nhân / cách xử lý |
|---|---|
| "running scripts is disabled" | Chạy bằng `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1` (chỉ áp dụng cho tiến trình đó). |
| Script "Cancelled (non-interactive without -Yes)" | Không có console tương tác; thêm `-Yes`. |
| File báo `Customized` / `Conflict` và không được ghi | Đó là chủ ý (bảo vệ chỉnh sửa của bạn). Xem diff bằng `update.ps1 -DryRun`; ghi đè bằng `-Yes -Force` hoặc trả lời `y` khi hỏi. |
| Muốn giữ thay đổi tay làm chuẩn | `.\scripts\backup.ps1 -ToRepo`, xem `git diff`, commit. |
| "Target settings.json is not valid JSON" | Sửa JSON hoặc `restore.ps1 -From latest`. Script không ghi đè file lỗi. |
| `-Component agents,skills` báo lỗi | Dùng đúng tên: `instructions, agents, skills, templates, hooks, routing, permissions, settings`. Có thể viết `-Component "agents,skills"`. |
| CLI không thấy | Cảnh báo, không lỗi: Desktop dùng chung `~\.claude`. Cài CLI nếu cần dùng terminal. |
| Cài xong nhưng phiên đang mở chưa đổi | Mở phiên mới. |
| Skill cá nhân không thấy trong Cowork/cloud | Skill cá nhân không nạp trong các môi trường đó (giới hạn của sản phẩm). |
| `validate.ps1` FAIL "non-ASCII in .ps1" | Giữ file `.ps1` thuần ASCII (Windows PowerShell 5.1 đọc file không BOM theo ANSI). |
| Cần hoàn tác | `.\scripts\restore.ps1 -List` rồi `-From <thư mục>`; mỗi lần restore cũng tạo backup `pre-restore`. |
| Log | `logs\<script>-<time>.log` trong repo (đã gitignore). |
