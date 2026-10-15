---
name: python-project-quality
description: Quy ước thực hành cho project Python, script và CLI có thể bảo trì.
---

# Python Project Quality

- Kiểm tra phiên bản Python và dependency hiện tại trước khi dùng API mới.
- Ưu tiên `pathlib`, `logging`, `argparse` hoặc CLI framework đã có trong project.
- Dùng type hints khi giúp làm rõ contract; tránh typing phức tạp không cần thiết.
- Tách phần parse input, business logic và I/O khi việc đó giúp test dễ hơn.
- Không bắt exception chung rồi tiếp tục như thể thành công. Bổ sung ngữ cảnh và giữ nguyên traceback khi cần.
- Với cấu hình: ưu tiên argument/environment/config file; không hard-code secret.
- Với script dùng một lần, vẫn cần validate input, thông báo lỗi hữu ích và hướng dẫn chạy.
- Với file output, tránh ghi đè ngoài ý muốn; cân nhắc output path rõ ràng.
- Nếu thêm dependency, giải thích lợi ích và cập nhật file quản lý dependency đúng cách.
- Chỉ thêm abstraction khi nó làm code dễ hiểu hoặc dễ test hơn.
