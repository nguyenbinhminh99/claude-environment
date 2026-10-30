# Cấu hình repo

## Cấu trúc
```
global/            -> được cài vào ~\.claude
  CLAUDE.md  settings.json  agents/  skills/  templates/  (hooks/ tùy chọn)
machine/           -> chỉ là ví dụ, KHÔNG bao giờ được script cài
  settings.example.json  mcp.example.json
scripts/           install update backup restore validate uninstall + lib/common.ps1
tests/run-tests.ps1
manifest.json      danh sách thành phần, giá trị model/effort hợp lệ, quy tắc bắt buộc, vùng không đụng tới
```

## Cách `settings.json` được xử lý
`global/settings.json` chỉ chứa phần được quản lý. Khi cài, script merge vào file đích:

| Kiểu giá trị | Quy tắc |
|---|---|
| Danh sách (`permissions.deny/ask`) | Hợp của hai bên; không xóa mục của bạn |
| Object | Merge đệ quy |
| Giá trị đơn (`model`, `disableBypassPermissionsMode`) | Thiếu -> thêm. Khác -> `Update` nếu bạn chưa từng đổi, ngược lại cần xác nhận / `-Force` |

Thành phần: `routing` = key `model` + trường `model`/`effort` trong frontmatter agents; `permissions` = key `permissions`; `settings` = key còn lại (ví dụ `hooks` nếu sau này thêm).

## Trạng thái cài đặt
`~\.claude\claude-environment.state.json` lưu hash của file đã cài để phân biệt "repo mới hơn" với "bạn đã sửa tay". Xóa file này thì mọi file khác repo sẽ được xem là `Conflict` (vẫn được giữ nguyên).

## Thêm thành phần mới
- Agent: `global/agents/<name>.md` (frontmatter `name` khớp tên file, `description`, `model`...).
- Skill: `global/skills/<name>/SKILL.md` (`name` khớp tên thư mục, `description`).
- Hook: đặt script trong `global/hooks/` và khai báo `hooks` trong `global/settings.json`.
- Kiểu thành phần hoàn toàn mới: thêm vào `manifest.json` (`components`).
Sau đó chạy `validate.ps1 -Scope Repo` và `tests\run-tests.ps1`.
