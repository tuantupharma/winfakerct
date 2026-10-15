---
name: godot-gameplay-patterns
description: Mẫu thiết kế gameplay Godot cho scene tree, signals, input, physics và save/load.
---

# Godot Gameplay Patterns

- Xác định rõ phiên bản Godot; cú pháp và API phải khớp version.
- Một Node/script nên có trách nhiệm dễ mô tả; tránh script khổng lồ.
- Dùng signals để thông báo sự kiện giữa các hệ thống khi giảm coupling.
- Dùng exported properties cho tham số cần tinh chỉnh trong Inspector.
- Tạo input action trong Project Settings thay vì rải keycode khắp code.
- Dùng `_physics_process` cho tương tác physics; dùng delta phù hợp với chuyển động.
- Kiểm tra node path, signal connections, lifecycle và thứ tự khởi tạo khi debug.
- Save/load: có schema rõ ràng, xử lý file lỗi/phiên bản cũ và không tin dữ liệu đầu vào tuyệt đối.
- Khi thay đổi scene/node name, tìm toàn bộ tham chiếu để tránh làm hỏng project.
- Ưu tiên prototype tối thiểu có thể chơi được trước khi xây hệ thống tổng quát.
