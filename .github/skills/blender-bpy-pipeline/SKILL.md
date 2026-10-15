---
name: blender-bpy-pipeline
description: Hướng dẫn Blender bpy, procedural asset, batch processing và export sang game engine.
---

# Blender bpy Pipeline

- Kiểm tra version Blender trước khi dùng API; ghi rõ version mục tiêu trong script.
- Ưu tiên data API (`bpy.data`) nếu phù hợp để giảm phụ thuộc vào context.
- Nếu dùng `bpy.ops`, xác minh mode, active object, selection và context.
- Làm script idempotent khi có thể: chạy lại không tạo object/material trùng vô hạn.
- Đặt tên object, collection, material và file xuất nhất quán.
- Với batch operation, lọc rõ phạm vi; không xóa hoặc ghi đè asset ngoài ý muốn.
- Trước export, kiểm tra scale, rotation, origin/pivot, normals, material slots và animation.
- Với Godot, thống nhất đơn vị/scale, format xuất và cách xử lý material/texture.
- Tách cấu hình (đường dẫn, tên collection, định dạng) khỏi logic khi script dùng thường xuyên.
- Báo cách chạy trong Text Editor hoặc Blender background mode và nơi lưu kết quả.
