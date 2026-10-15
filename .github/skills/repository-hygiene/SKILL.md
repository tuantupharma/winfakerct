---
name: repository-hygiene
description: Giữ repo sạch, cấu hình rõ, không lộ secret và tránh file sinh ra không cần thiết.
---

# Repository Hygiene

- Kiểm tra `.gitignore`, file cấu hình và convention hiện tại trước khi thêm file.
- Không commit secret, token, credential, dữ liệu cá nhân hoặc file output lớn ngoài ý muốn.
- Không tự ý xóa file người dùng, file sinh ra chưa được xác nhận hoặc thay đổi không liên quan.
- Ghi rõ dependency mới, cách cài và cách chạy.
- Tránh đường dẫn tuyệt đối phụ thuộc máy cá nhân.
- Giữ README cập nhật khi cách setup/chạy thay đổi.
- Trước khi kết thúc, xem lại diff để tìm thay đổi ngoài phạm vi và lỗi định dạng rõ ràng.
