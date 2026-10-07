# Keep HAO_WSL alive (Penpot / Hindsight must stay online 24x7).
#
# Why: WSL stops the distro when no wsl.exe client is attached (changing
# .wslconfig vmIdleTimeout does not help), so this loop holds one long-lived
# client for 10 minutes and re-attaches; if the VM was shut down, the next
# iteration starts it again.
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
    }
} finally {
    $mutex.ReleaseMutex()
}
