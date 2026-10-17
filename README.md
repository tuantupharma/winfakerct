# winfakerct: fix the wrong date and time on old Windows laptops

**winfakerct** is a "fake hardware clock" for Windows — the Windows equivalent of Linux's `fake-hwclock`. When a dead CMOS/BIOS battery or a power loss resets your PC's clock to an old date (for example, 2019), winfakerct restores the last known good date at startup so a time sync tool such as NetTime can then set the correct time from the internet.

In plain terms: your laptop keeps forgetting the date. winfakerct remembers it for you.

This is a Windows clock recovery tool, not an NTP client: it does not fetch internet time or replace NetTime. It saves a known-good date, detects a clock reset to an earlier year (for example, 2019), and restores the saved date before NetTime's automatic synchronization. If you also want to set the clock from the internet without NetTime, see the `no3rd` option below.

**Keywords:** Windows clock wrong, wrong date and time Windows 10, CMOS battery dead time reset, BIOS battery RTC reset 2019, fake-hwclock for Windows, fake RTC Windows, time sync recovery, clock rollback protection, anti-rollback clock, restore last known time, NetTime, NSSM Windows service, PowerShell, old laptop clock fix, RTC battery replacement.

## Behavior

- Save the current local date each time the script runs.
- Check whether the system date is suspiciously old, such as year 2019.
- If the date is in the bad range, restore the saved date from the previous good run.
- Check only whether NetTime is installed; do not launch NetTime manually.
- Let NetTime auto-sync the time afterward.

### Anti-rollback (forward-only baseline)

Like `fake-hwclock`, winfakerct never moves the saved date backwards:

- The saved baseline is only updated when the current clock is **newer** than the saved value. A clock that is behind but still plausible does not overwrite the good baseline.
- A restore is triggered when the year is below `ResetYearThreshold`, **or** when the clock moved backwards past the saved baseline by more than `RollbackToleranceHours` (default 24 hours).
- The tolerance window prevents fighting a legitimate correction — for example, when NetTime fixes a clock that was running ahead.

## Requirements

- Windows 10 hoặc mới hơn
- Windows PowerShell 5.1
- NetTime đã cài đặt và tự đồng bộ theo cách của nó
- Quyền Administrator để chỉnh thời gian hệ thống

## Bước 1: sao chép project

Giải nén hoặc copy thư mục dự án vào ổ đĩa cố định, ví dụ:

```powershell
C:\Tools\winfakerct
```

## Bước 2: mở PowerShell với quyền Admin

Mở PowerShell dưới dạng Administrator, sau đó vào thư mục dự án:

```powershell
cd C:\Tools\winfakerct
```

## Bước 3: chạy thử trước

Thực hiện kiểm tra dry run trước khi cài task:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\src\WinFakeRct.ps1 -Test
```

Lệnh này sẽ:
- kiểm tra NetTime có cài chưa
- kiểm tra ngày hệ thống hiện tại
- không thay đổi thời gian nếu chưa cần
- ghi log vào `logs\winfakerct.log`

## Bước 4: chỉnh cấu hình nếu cần

Mở file `config.json` và chỉnh lại các mục:

- `NetTimePath`: nếu NetTime không được tự phát hiện, điền đường dẫn tới `NetTime.exe`
- `LastKnownDateFile`: vị trí file lưu ngày an toàn
- `LastKnownDateHistoryFile`: vị trí lịch sử ngày hợp lệ
- `ResetYearThreshold`: năm dưới mốc nào sẽ coi là ngày lỗi. Mặc định là `2020`
- `RollbackToleranceHours`: số giờ cho phép đồng hồ chậm hơn bản lưu mà không bị coi là quay lùi. Mặc định là `24`

Ví dụ:

```json
{
  "NetTimePath": "",
  "LastKnownDateFile": "logs\\LastKnownDate.txt",
  "LastKnownDateHistoryFile": "logs\\LastKnownDateHistory.txt",
  "ResetYearThreshold": 2020,
  "RollbackToleranceHours": 24
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
- tạo service Windows tên `winfakerct`
- cấu hình service chạy dưới LocalSystem
- khởi động service ngay lập tức; winfakerct chạy một lần mỗi 24 giờ, lỗi thì thử lại sau 4 giờ
- nếu tìm thấy đúng một service NetTime đang ở chế độ Automatic, lưu cấu hình hiện tại rồi chuyển sang Automatic (Delayed Start) để winfakerct kiểm tra ngày trước trong lần khởi động Windows tiếp theo
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
- tạo service Windows tên `winfakerct`
- dùng LocalSystem để có quyền sửa thời gian hệ thống
- chạy service runner khi máy khởi động; runner lưu lịch chạy, chạy lại sau 24 giờ nếu thành công hoặc 4 giờ nếu lỗi
- nếu tìm thấy đúng một service NetTime đang ở chế độ Automatic, đặt thành Automatic (Delayed Start) sau khi lưu startup mode ban đầu
- kiểm tra ngày hệ thống và khôi phục về mốc an toàn nếu bị quay về 2019

## Bước 6: kiểm tra log

File log:

```powershell
logs\winfakerct.log
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

Lệnh này xóa service `winfakerct`, không xóa project và log.

## Lưu ý quan trọng

- Script chỉ phục hồi ngày, không tự động chạy NetTime từ dự án.
- NetTime phải tự đồng bộ thời gian theo cách cài đặt của nó.
- Bộ cài chuyển service NetTime sang Delayed Start để winfakerct chạy trước ở lần boot kế tiếp; Windows thường trì hoãn khoảng 1–2 phút nhưng không cam kết một số giây cố định. Thay đổi không dừng NetTime đang chạy.
- Trạng thái startup ban đầu được lưu ở `logs\NetTimeStartupState.json` và khôi phục khi gỡ winfakerct. Nếu không tìm thấy duy nhất một service NetTime, hoặc service không ở chế độ Automatic, bộ cài sẽ giữ nguyên cấu hình đó.
- Nếu BIOS hoặc RTC bị reset về 2019 sau mất điện, script sẽ giữ và phục hồi lại ngày an toàn gần nhất, không lưu ngày 2019 như dữ liệu tốt.
- Bản lưu ngày chỉ được cập nhật khi đồng hồ hiện tại **mới hơn** bản lưu (forward-only), giống `fake-hwclock`. Đồng hồ chậm hơn trong ngưỡng `RollbackToleranceHours` sẽ không ghi đè bản lưu tốt.
- Phương án service NSSM được ưu tiên hơn Scheduled Task vì chạy ổn định hơn khi máy khởi động và không phụ thuộc vào Task Scheduler.

## Tùy chọn: sửa giờ không cần NetTime (thư mục `no3rd`)

Nếu bạn không muốn cài NetTime hay NSSM, dùng script tự lấy giờ từ Internet. Đây là phần tương đương NTP client (giống `ntpd`/`chrony` trên Linux), khác với winfakerct ở trên (giống `fake-hwclock`):

```powershell
# Chạy thử, không đổi giờ
.\no3rd\Repair-Clock.ps1 -Test

# Sửa giờ thật (tự xin quyền Administrator)
.\no3rd\Repair-Clock.ps1
```

Hoặc nháy đúp file `no3rd\Run-Repair-Clock.bat`.

Cách hoạt động:
- Thử NTP trước (`time.cloudflare.com`, `time.google.com`, `pool.ntp.org`, `time.windows.com`), mỗi máy 2 lần.
- Nếu NTP thất bại, lấy giờ từ header `Date` của HTTPS (chứng chỉ TLS vẫn được kiểm tra).
- Không dùng `w32tm`, không cần NetTime.
- Log ghi vào `logs\Repair-Clock.log`.

Lưu ý:
- Script chỉ lấy giờ từ **một nguồn duy nhất** (nguồn đầu tiên trả lời), không kiểm tra chéo nhiều nguồn. Nếu mạng có captive portal hoặc proxy trả `Date` sai, giờ có thể bị đặt sai.
- Để chạy tự động, tạo Scheduled Task gọi trực tiếp `Repair-Clock.ps1` (đừng gọi file `.bat`, vì `.bat` sẽ dừng chờ khi nháy đúp).

## Notes

- File ngày an toàn: `logs\LastKnownDate.txt`
- File lịch sử: `logs\LastKnownDateHistory.txt`
- Nếu máy đang ở 2019 trong nhiều ngày, script vẫn giữ giá trị ngày hợp lệ gần nhất, không bị ghi đè bằng 2019.
