# Repoint scheduled task WSL_Auto_Start to the WSL keep-alive script.
# Requires elevation (run once, 2026-10-07 WSL migration).
# ASCII-only on purpose: Windows PowerShell 5.1 mis-parses UTF-8 without BOM.

$ErrorActionPreference = "Stop"

$log = "C:\Users\admin\wsl-task-update.log"
"=== $(Get-Date) ===" | Out-File $log

try {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\admin\wsl-keepalive.ps1"'

    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"

    # Resident task: must not stop on idle or on battery, no execution time limit.
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries -DontStopOnIdleEnd `
        -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -MultipleInstances IgnoreNew `
        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
        -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask -TaskName "WSL_Auto_Start" -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force `
        -Description "Start and keep alive WSL distro HAO_WSL (Penpot / Hindsight), 2026-10-07" | Out-Null

    "OK: task updated" | Out-File $log -Append
    $t = Get-ScheduledTask -TaskName "WSL_Auto_Start"
    "State: $($t.State)" | Out-File $log -Append
    "Action: $($t.Actions.Execute) $($t.Actions.Arguments)" | Out-File $log -Append
    "AllowBattery: $($t.Settings.AllowStartIfOnBatteries) DontStopBattery: $($t.Settings.DontStopIfGoingOnBatteries) StopOnIdle: $($t.Settings.StopOnIdleEnd) TimeLimit: $($t.Settings.ExecutionTimeLimit)" | Out-File $log -Append
} catch {
    "FAILED: $($_.Exception.Message)" | Out-File $log -Append
    exit 1
}
