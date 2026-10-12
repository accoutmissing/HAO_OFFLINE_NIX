# Final verification of the WSL keep-alive setup (ASCII output only).
$match = 'wsl-keepalive.ps1'

# 1. task definition
$t = Get-ScheduledTask -TaskName 'WSL_Auto_Start'
"task state      : $($t.State)"
"task action     : $($t.Actions.Execute) $($t.Actions.Arguments)"
"task enabled    : $($t.Settings.Enabled)"
"mul instances   : $($t.Settings.MultipleInstances)"
"time limit      : $($t.Settings.ExecutionTimeLimit)"
"trigger type    : $($t.Triggers[0].CimClass.CimClassName)"

# 2. mutex guard: try to start a second loop, expect it to exit immediately
Start-Process powershell -ArgumentList '-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File','C:\Users\admin\wsl-keepalive.ps1' -WindowStyle Hidden
Start-Sleep -Seconds 8
$procs = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like "*$match*" })
"keepalive count : $($procs.Count)  (expect 1)"
$procs | ForEach-Object { "  pid=$($_.ProcessId)" }

# 3. distro + endpoints
"distro          : $((wsl.exe -l -v) -join ' | ')"
# Endpoints use the LAN IP detected inside WSL (fetched, not hardcoded):
# Windows loopback to WSL-published ports does not work in current WSL, while
# the LAN IP is both this machine's check address and the real PUBLIC_URI
# browsers use. Falls back to 127.0.0.1 if the env file is unavailable.
$envText = (wsl.exe -d HAO_WSL -u root -- cat /run/penpot-public-uri.env) -join "`n"
$ip = '127.0.0.1'
if ($envText -match 'PENPOT_PUBLIC_URI=https://([0-9.]+):9001') { $ip = $Matches[1] }
foreach ($u in @("https://${ip}:9001","http://${ip}:8888/health","http://${ip}:9999/")) {
    $code = & curl.exe --noproxy '*' -sk -o NUL -w '%{http_code}' --max-time 12 $u
    "$u -> $code"
}
