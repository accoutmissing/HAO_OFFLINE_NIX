param([string]$Directory = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$taskCreatedTemporary = $false
$taskTemporaryPath = $null
try {
    $taskDirectory = (Resolve-Path -LiteralPath $Directory).Path
    $taskHashes = @{}
    $taskManifests = @(Get-ChildItem -LiteralPath $taskDirectory -File -Filter 'SHA256SUMS*')
    foreach ($taskManifest in $taskManifests) {
        foreach ($taskLine in Get-Content -LiteralPath $taskManifest.FullName -Encoding UTF8) {
            if ($taskLine -match '^([a-fA-F0-9]{64})\s+\*?(?:\./)?(hao-installer-offline-[a-zA-Z0-9._-]+\.iso(?:\.part[0-9]{2})?)$') {
                $taskHash = $Matches[1].ToLowerInvariant()
                $taskName = $Matches[2]
                if ($taskHashes.ContainsKey($taskName) -and $taskHashes[$taskName] -ne $taskHash) {
                    throw "同名文件的校验值冲突：$taskName"
                }
                $taskHashes[$taskName] = $taskHash
            }
        }
    }
    $taskIsos = @($taskHashes.Keys | Where-Object { $_ -match '\.iso$' } | Sort-Object)
    if ($taskIsos.Count -eq 0) { throw '没有找到完整 ISO 的校验值。请将校验文件、所有分卷和脚本放在同一个文件夹。' }
    $taskIso = $taskIsos[0]
    if ($taskIsos.Count -gt 1) {
        for ($taskIndex = 0; $taskIndex -lt $taskIsos.Count; $taskIndex++) {
            Write-Host (('{0}. {1}' -f ($taskIndex + 1), $taskIsos[$taskIndex]))
        }
        $taskChoice = Read-Host '选择需要合并的镜像序号'
        if ($taskChoice -notmatch '^[0-9]{1,2}$' -or [int]$taskChoice -lt 1 -or [int]$taskChoice -gt $taskIsos.Count) {
            throw '选择的序号无效。'
        }
        $taskIso = $taskIsos[[int]$taskChoice - 1]
    }
    $taskOutputPath = Join-Path $taskDirectory $taskIso
    if (Test-Path -LiteralPath $taskOutputPath) {
        if ((Get-FileHash -LiteralPath $taskOutputPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskHashes[$taskIso]) {
            throw '同名 ISO 已存在但校验失败，请先移走这个文件，再重试。'
        }
        Write-Host "镜像已完整通过校验，可直接写入 U 盘：$taskIso"
        exit 0
    }
    $taskPartPattern = '^' + [regex]::Escape($taskIso) + '\.part[0-9]{2}$'
    $taskParts = @($taskHashes.Keys | Where-Object { $_ -match $taskPartPattern } | Sort-Object)
    if ($taskParts.Count -eq 0) { throw '没有找到分卷校验值，请确认下载的是对应机型的完整校验文件。' }
    for ($taskIndex = 0; $taskIndex -lt $taskParts.Count; $taskIndex++) {
        $taskExpectedName = $taskIso + '.part' + $taskIndex.ToString('D2')
        if ($taskParts[$taskIndex] -ne $taskExpectedName -or !(Test-Path -LiteralPath (Join-Path $taskDirectory $taskExpectedName) -PathType Leaf)) {
            throw "缺少分卷：$taskExpectedName。下载齐全后再运行。"
        }
    }
    $taskTemporaryPath = $taskOutputPath + '.assembling'
    $taskOutput = [System.IO.File]::Open($taskTemporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $taskCreatedTemporary = $true
    try {
        foreach ($taskPart in $taskParts) {
            Write-Host "正在合并：$taskPart"
            $taskInput = [System.IO.File]::OpenRead((Join-Path $taskDirectory $taskPart))
            try { $taskInput.CopyTo($taskOutput, 4194304) } finally { $taskInput.Dispose() }
        }
    } finally { $taskOutput.Dispose() }
    Write-Host '正在校验完整镜像，请稍候……'
    $taskActualHash = (Get-FileHash -LiteralPath $taskTemporaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($taskActualHash -ne $taskHashes[$taskIso]) { throw '镜像校验失败，请重新下载损坏或未完成的分卷。' }
    Move-Item -LiteralPath $taskTemporaryPath -Destination $taskOutputPath
    $taskCreatedTemporary = $false
    Write-Host "合并和校验完成。使用 Rufus 的 DD 模式将此文件写入 U 盘：$taskIso"
} catch {
    if ($taskCreatedTemporary -and (Test-Path -LiteralPath $taskTemporaryPath -PathType Leaf)) {
        Remove-Item -LiteralPath $taskTemporaryPath
    }
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
