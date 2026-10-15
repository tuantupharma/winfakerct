---
name: agent-routing
description: Chọn agent và skill phù hợp cho yêu cầu đa lĩnh vực, chia nhỏ công việc và tổng hợp kết quả.
---

# Agent Routing

## Bản đồ định tuyến
| Tín hiệu trong yêu cầu | Chuyên môn chính | Skill |
|---|---|---|
| Python, script, CLI, dữ liệu | Python Engineer | `python-project-quality` |
| Windows, PowerShell, file, process, GUI | Windows Automation Engineer | `windows-automation-safety` |
| C++, CMake, native performance | C++ Game & Systems Engineer | `cpp-project-basics` |
| Godot, GDScript, scene, node, signals | Godot Game Developer | `godot-gameplay-patterns` |
| Blender, bpy, mesh, material, export | Blender Technical Artist | `blender-bpy-pipeline` |
| Bug, review, regression, test | Code Reviewer & Debugger | `testing-debugging` |
| Prototype gameplay | Agent theo engine | `game-prototype-scope` |
| Thay đổi cấu trúc repo | Agent chính + review | `repository-hygiene` |

## Tác vụ kết hợp
- Chọn một agent chịu trách nhiệm chính.
- Xác định đầu vào/đầu ra giữa các bước, ví dụ Blender export → Godot import.
- Đưa ra checklist tích hợp ở cuối.
- Nếu môi trường không hỗ trợ handoff tự động, hướng dẫn người dùng chuyển agent; không tuyên bố đã gọi agent khác.
- Chỉ thêm review agent khi có rủi ro, logic phức tạp hoặc người dùng yêu cầu review.

## Chọn mức độ quy trình
- Việc nhỏ, ít rủi ro: sửa trực tiếp và kiểm tra nhanh.
- Nhiều file hoặc nhiều hệ thống: lập kế hoạch trước.
- Có xóa/ghi đè, thay đổi hệ thống hoặc dữ liệu quan trọng: dry-run/backup và chờ xác nhận.
