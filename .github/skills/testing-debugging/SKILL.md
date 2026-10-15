---
name: testing-debugging
description: Quy trình tái hiện bug, tìm nguyên nhân gốc, viết test hồi quy và báo cáo kết quả trung thực.
---

# Testing & Debugging

1. Xác định hành vi mong muốn và hành vi thực tế.
2. Tạo bước tái hiện nhỏ nhất; giữ lại log, traceback hoặc thông báo lỗi liên quan.
3. Thu hẹp phạm vi bằng cách kiểm tra giả thuyết từng bước.
4. Tìm nguyên nhân gốc thay vì chỉ che triệu chứng.
5. Sửa patch nhỏ nhất có thể; tránh refactor không liên quan.
6. Thêm test hồi quy hoặc bước kiểm tra lặp lại.
7. Chạy test phù hợp và báo chính xác lệnh/kết quả; nếu không thể chạy, nói rõ lý do.
8. Kiểm tra trường hợp biên, input không hợp lệ và hành vi khi thất bại.
9. Không xóa test đang fail chỉ để làm build xanh; giải thích nếu test không còn phù hợp.
