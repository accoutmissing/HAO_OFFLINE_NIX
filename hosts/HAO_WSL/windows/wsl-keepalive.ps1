# Keep HAO_WSL alive (Penpot / Hindsight must stay online 24x7).
#
# Compatibility fallback: current WSL supports [general] instanceIdleTimeout=-1.
# This loop also keeps older WSL releases attached for 10 minutes at a time;
# if the VM was shut down, the next iteration starts it again.
#
# Single-instance guard: both the scheduled task and the Startup shortcut may
# launch this script; a named mutex keeps only one loop running.

$mutex = New-Object System.Threading.Mutex($false, "Global\HaoWslKeepalive")
if (-not $mutex.WaitOne(0)) {
    exit 0
}

try {
    while ($true) {
        & wsl.exe -d HAO_WSL -u root -- /run/current-system/sw/bin/sleep 600 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Start-Sleep -Seconds 10
        }
    }
} finally {
    $mutex.ReleaseMutex()
}
