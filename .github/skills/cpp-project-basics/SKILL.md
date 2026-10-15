---
name: cpp-project-basics
description: Checklist C++ hiện đại, quản lý lifetime, CMake và debug cho project nhỏ/game prototype.
---

# C++ Project Basics

- Xác nhận compiler, chuẩn C++ và build system trước khi dùng tính năng mới.
- Dùng RAII để quản lý resource; xác định rõ ownership và lifetime.
- Ưu tiên `std::vector`, `std::string`, smart pointers và value semantics khi phù hợp.
- Không trả reference/pointer tới local object hoặc lưu pointer tới object có thể bị hủy.
- Tránh undefined behavior, signed/unsigned mismatch, out-of-bounds và data races.
- Dùng `const` khi phù hợp; tránh global mutable state nếu không cần.
- CMake: tổ chức theo target, khai báo include/dependency có chủ đích, không hard-code path máy cá nhân.
- Debug theo thứ tự: tái hiện, thu hẹp, kiểm tra giả thuyết, sửa nguyên nhân, thêm regression test.
- Không tối ưu dựa trên cảm giác; đo trước khi thay đổi kiến trúc vì hiệu năng.
