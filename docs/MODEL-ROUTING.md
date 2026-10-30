# Model routing (giữ nguyên như máy gốc)

| Thành phần | Model | Effort | Nguồn |
|---|---|---|---|
| Phiên chính | `opusplan` (Sonnet thực thi, Opus khi ở plan mode) | mặc định | `settings.json` -> `model` |
| `architect` | `opus` | `high` | frontmatter agent |
| `scout` | `haiku` | `low` | frontmatter agent |
| `ba-analyst`, `qa-tester`, `code-reviewer`, `security-reviewer`, `ui-reviewer` | `sonnet` | mặc định | frontmatter agent |

Gói này **không đổi** các giá trị trên; chỉ sao chép đúng như đã kiểm tra trên máy gốc.

## Tự động và theo chỉ dẫn
- Tự động (Claude Code thực thi): `opusplan` chuyển sang Opus khi vào plan mode; model/effort trong frontmatter từng agent.
- Theo chỉ dẫn (Claude tự quyết dựa trên `CLAUDE.md`, không đảm bảo 100%): khi nào vào plan mode, gọi agent nào, khi nào nâng một lần gọi lên `model: "opus"` hoặc hạ xuống `haiku`.
- Phiên chính không tự đổi model theo từng prompt. Dùng `/model` để ghi đè tạm thời.

## Kiểm tra tương thích (script `validate.ps1`)
- Alias hợp lệ: `opusplan, opus, sonnet, haiku, inherit, default`, hoặc ID đầy đủ dạng `claude-...`.
- Effort hợp lệ: `low, medium, high, xhigh, max`. Giá trị lạ -> FAIL.
- `name` trong frontmatter phải khớp tên file/thư mục.
- Cảnh báo nếu agent có tool `Agent` (có thể tự sinh agent con).

## Chưa kiểm chứng
- Việc Claude Desktop có áp dụng `model` trong `settings.json` giống CLI hay không: Desktop có bộ chọn model riêng, hãy kiểm tra thủ công trên máy mới.
- Alias và effort phụ thuộc phiên bản Claude Code cài trên máy đích; máy gốc đã kiểm tra với CLI 2.1.312 (ghi nhận trong tài liệu cũ). Phiên bản cũ hơn có thể không hiểu `effort`.
- Cập nhật chỉ riêng routing: `.\scripts\install.ps1 -Component routing` (hỏi xác nhận nếu máy đích đang dùng model khác).
