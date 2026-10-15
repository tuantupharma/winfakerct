# Manual test plan

Run from an elevated Windows PowerShell 5.1 terminal.

1. `.\src\AutoTimeFix.ps1 -Test` — verifies config, time-source quorum and NetTime discovery without changing the clock or launching NetTime.
2. Temporarily disconnect Wi-Fi and run the script — it should retry a bounded number of times and exit non-zero.
3. With Internet connected and correct time, run without `-Test`; check logs and NetTime's own log for `Single Sync Successful` or equivalent.
4. Only after backup and with a maintenance window, test a large clock offset. A wrong clock can affect TLS, sign-in, file timestamps, and scheduled tasks.
5. Verify Scheduled Task history and `logs\AutoTimeFix.log` after reboot.
6. On a test machine, install AutoTimeFix and verify `NetTime` is set to Automatic (Delayed Start); reboot and compare AutoTimeFix and NetTime service/log start times. Uninstall and verify NetTime's original startup mode is restored.

Do not deliberately set a production machine's clock to 2014 just to test. The HTTP Date header is only second-resolution and depends on HTTPS endpoints and any proxy in the path.
