# AutoTimeFix: Windows Time Sync Recovery for Old Laptops

AutoTimeFix helps fix the wrong date and time on an old Windows laptop when a dead CMOS/BIOS battery or power loss resets its RTC clock. It restores the last known good date at startup so a time synchronization program such as NetTime can sync Windows with internet time afterward.

This is a Windows clock recovery tool, not an NTP client: it does not fetch internet time or replace NetTime. It saves a known-good date, detects a clock reset to an earlier year (for example, 2019), and restores the saved date before NetTime's automatic synchronization.

## Behavior

- Save the current local date each time the script runs.
- Check whether the system date is suspiciously old, such as year 2019.
- If the date is in the bad range, restore the saved date from the previous good run.
- Check only whether NetTime is installed; do not launch NetTime manually.
- Let NetTime auto-sync the time afterward.

## Requirements

- Windows 10 hoặc mới hơn
- Windows PowerShell 5.1
- NetTime đã cài đặt và tự đồng bộ theo cách của nó
- Quyền Administrator để chỉnh thời gian hệ thống

## Bước 1: sao chép project

Giải nén hoặc copy thư mục dự án vào ổ đĩa cố định, ví dụ:

```powershell
C:\Tools\AutoTimeFix
```

## Bước 2: mở PowerShell với quyền Admin

Mở PowerShell dưới dạng Administrator, sau đó vào thư mục dự án:

```powershell
cd C:\Tools\AutoTimeFix
```

## Bước 3: chạy thử trước

Thực hiện kiểm tra dry run trước khi cài task:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\src\AutoTimeFix.ps1 -Test
```

Lệnh này sẽ:
- kiểm tra NetTime có cài chưa
- kiểm tra ngày hệ thống hiện tại
- không thay đổi thời gian nếu chưa cần
- ghi log vào `logs\AutoTimeFix.log`

## Bước 4: chỉnh cấu hình nếu cần

Mở file `config.json` và chỉnh lại các mục:

- `NetTimePath`: nếu NetTime không được tự phát hiện, điền đường dẫn tới `NetTime.exe`
- `LastKnownDateFile`: vị trí file lưu ngày an toàn
- `LastKnownDateHistoryFile`: vị trí lịch sử ngày hợp lệ
- `ResetYearThreshold`: năm dưới mốc nào sẽ coi là ngày lỗi. Mặc định là `2020`

Ví dụ:

```json
{
  "NetTimePath": "",
  "LastKnownDateFile": "logs\\LastKnownDate.txt",
  "LastKnownDateHistoryFile": "logs\\LastKnownDateHistory.txt",
  "ResetYearThreshold": 2020
}
```

## Bước 5: cài đặt nhanh bằng file .bat (khuyến nghị)

Chỉ cần chạy file gốc ở thư mục dự án:

```bat
Install.bat
```

File này sẽ tự làm mọi thứ cho bạn:
- kiểm tra quyền Administrator
- tìm NSSM hoặc tải NSSM nếu chưa có
- tạo service Windows tên `AutoTimeFix`
- cấu hình service chạy dưới LocalSystem
- khởi động service ngay lập tức; AutoTimeFix chạy một lần mỗi 24 giờ, lỗi thì thử lại sau 4 giờ
- nếu tìm thấy đúng một service NetTime đang ở chế độ Automatic, lưu cấu hình hiện tại rồi chuyển sang Automatic (Delayed Start) để AutoTimeFix kiểm tra ngày trước trong lần khởi động Windows tiếp theo
- giữ nguyên logic kiểm tra ngày và phục hồi bản ghi an toàn khi hệ thống trả về 2019

Nếu cần gỡ cài đặt:

```bat
Uninstall.bat
```

## Fallback: cài tay bằng PowerShell

Nếu bạn muốn cài thủ công:

```powershell
.\scripts\Install.ps1
```

Nếu NSSM không nằm trong PATH:

```powershell
.\scripts\Install.ps1 -NssmPath "C:\\Tools\\nssm\\win64\\nssm.exe"
```

Lệnh này sẽ:
- tạo service Windows tên `AutoTimeFix`
- dùng LocalSystem để có quyền sửa thời gian hệ thống
- chạy service runner khi máy khởi động; runner lưu lịch chạy, chạy lại sau 24 giờ nếu thành công hoặc 4 giờ nếu lỗi
- nếu tìm thấy đúng một service NetTime đang ở chế độ Automatic, đặt thành Automatic (Delayed Start) sau khi lưu startup mode ban đầu
- kiểm tra ngày hệ thống và khôi phục về mốc an toàn nếu bị quay về 2019

## Bước 6: kiểm tra log

File log:

```powershell
logs\AutoTimeFix.log
```

Bạn nên xem log để verify:
- có phát hiện ngày sai không
- có phục hồi về ngày trước đó không
- NetTime có được phát hiện không

## Bước 7: gỡ cài đặt service nếu không cần nữa

Cách nhanh nhất:

```bat
Uninstall.bat
```

Nếu muốn gỡ theo PowerShell:

```powershell
.\scripts\Uninstall.ps1
```

Nếu NSSM không nằm trong PATH:

```powershell
.\scripts\Uninstall.ps1 -NssmPath "C:\\Tools\\nssm\\win64\\nssm.exe"
```

Lệnh này xóa service `AutoTimeFix`, không xóa project và log.

## Lưu ý quan trọng

- Script chỉ phục hồi ngày, không tự động chạy NetTime từ dự án.
- NetTime phải tự đồng bộ thời gian theo cách cài đặt của nó.
- Bộ cài chuyển service NetTime sang Delayed Start để AutoTimeFix chạy trước ở lần boot kế tiếp; Windows thường trì hoãn khoảng 1–2 phút nhưng không cam kết một số giây cố định. Thay đổi không dừng NetTime đang chạy.
- Trạng thái startup ban đầu được lưu ở `logs\NetTimeStartupState.json` và khôi phục khi gỡ AutoTimeFix. Nếu không tìm thấy duy nhất một service NetTime, hoặc service không ở chế độ Automatic, bộ cài sẽ giữ nguyên cấu hình đó.
- Nếu BIOS hoặc RTC bị reset về 2019 sau mất điện, script sẽ giữ và phục hồi lại ngày an toàn gần nhất, không lưu ngày 2019 như dữ liệu tốt.
- Phương án service NSSM được ưu tiên hơn Scheduled Task vì chạy ổn định hơn khi máy khởi động và không phụ thuộc vào Task Scheduler.

## Notes

- File ngày an toàn: `logs\LastKnownDate.txt`
- File lịch sử: `logs\LastKnownDateHistory.txt`
- Nếu máy đang ở 2019 trong nhiều ngày, script vẫn giữ giá trị ngày hợp lệ gần nhất, không bị ghi đè bằng 2019.
