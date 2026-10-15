---
name: game-prototype-scope
description: Giữ phạm vi game nhỏ gọn, tập trung vòng lặp gameplay và khả năng kiểm thử.
---

# Game Prototype Scope

- Mô tả game loop chính trong 1–3 câu trước khi thiết kế hệ thống.
- Xây vertical slice nhỏ có thể chơi/kiểm tra trước khi thêm tính năng phụ.
- Tách input, state, gameplay rules và presentation khi điều đó giúp thay đổi dễ hơn.
- Dùng dữ liệu cấu hình cho tham số thường xuyên tinh chỉnh; tránh tạo framework tổng quát quá sớm.
- Định nghĩa điều kiện thắng/thua, restart và trạng thái pause rõ ràng.
- Xác định nguồn sở hữu của game state; tránh nhiều node cùng sửa một giá trị mà không có quy ước.
- Ưu tiên test logic độc lập và checklist test thủ công cho tương tác trong engine.
- Theo dõi phạm vi: nêu rõ tính năng nào nằm ngoài yêu cầu hiện tại.
