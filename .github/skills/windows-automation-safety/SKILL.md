---
name: windows-automation-safety
description: Checklist thiết kế automation Windows an toàn, có log, dry-run và xử lý lỗi.
---

# Windows Automation Safety

## Trước khi viết
- Xác định phạm vi file, process, app, user context và quyền cần thiết.
- Ưu tiên CLI/API chính thức hơn click theo tọa độ màn hình.
- Kiểm tra path đầu vào, xử lý khoảng trắng và ký tự đặc biệt.

## Với subprocess/PowerShell
- Truyền arguments tách biệt thay vì nối chuỗi lệnh từ input.
- Đặt timeout cho tiến trình có thể treo; ghi exit code và stderr.
- Không chạy lệnh lấy từ web hoặc file không tin cậy mà chưa kiểm tra.
- Không dùng quyền Administrator nếu không thật sự cần.

## Với thao tác file
- Có chế độ dry-run cho thao tác xóa, di chuyển, đổi tên hoặc ghi đè hàng loạt.
- In/log danh sách mục tiêu trước khi thực thi.
- Chặn path ngoài thư mục gốc được cho phép nếu yêu cầu giới hạn phạm vi.
- Với tác vụ rủi ro, tạo backup hoặc yêu cầu xác nhận.

## Với GUI automation
- Ưu tiên selector/accessibility API nếu có.
- Dùng wait/timeout thay vì sleep cố định dài.
- Kiểm tra cửa sổ đúng ứng dụng và trạng thái trước khi gửi input.
- Cung cấp cách dừng khẩn cấp và log bước thất bại.

## Kết thúc
Ghi rõ cách chạy, quyền cần thiết, tác động, cách dry-run và cách phục hồi.
