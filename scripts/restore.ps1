<#
.SYNOPSIS
  Restore the Claude config from a backup made by backup.ps1 / install.ps1 / update.ps1.
.DESCRIPTION
  -List shows available backups. -From takes a backup folder, or 'latest'.
  The current state is backed up first (label pre-restore). Files that did not exist when the
  backup was taken (recorded as createdFiles by install) are removed, so install is fully reversible.
#>
[CmdletBinding()]
param(
    [string]$ClaudeHome,
    [string]$From,
    [switch]$List,
    [switch]$Yes,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')
Initialize-Env -ClaudeHome $ClaudeHome -Yes:$Yes -DryRun:$DryRun -Name 'restore'
try {
    $root = Join-Path $script:CH 'backups\claude-environment'
    $all = @()
    if (Test-Path -LiteralPath $root) { $all = @(Get-ChildItem -LiteralPath $root -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'backup-manifest.json') } | Sort-Object Name) }
    if ($List -or -not $From) {
        if ($all.Count -eq 0) { Write-Log INFO "No backups under $root" } else { $all | ForEach-Object { Write-Host $_.FullName } }
        if (-not $From) { Write-Log INFO 'Use -From <folder|latest> to restore.'; exit 0 }
        exit 0
    }
    if ($From -eq 'latest') { if ($all.Count -eq 0) { Write-Log ERROR 'No backups found.'; exit 1 }; $From = $all[-1].FullName }
    if (-not [IO.Path]::IsPathRooted($From)) { $From = Join-Path $root $From }
    $mf = Join-Path $From 'backup-manifest.json'
    if (-not (Test-Path -LiteralPath $mf)) { Write-Log ERROR "Not a backup folder (backup-manifest.json missing): $From"; exit 1 }
    $man = ConvertTo-Ordered ((Read-Text $mf) | ConvertFrom-Json)
    $files = @($man['files']); $created = @($man['createdFiles'])
    Write-Log STEP ("Restore from {0} (label={1}, {2}): {3} file(s) to restore, {4} created-by-install file(s) to remove" -f $From, $man['label'], $man['created'], $files.Count, $created.Count)
    if ($DryRun) { Write-Log INFO '[dry-run] nothing written.'; exit 0 }
    if (-not (Confirm-Step ("Overwrite the matching files in {0}? Current state is backed up first." -f $script:CH))) { Write-Log SKIP 'Cancelled.'; exit 0 }
    $pre = New-Backup -Label 'pre-restore' -IncludeFlagged
    $n = 0; $fail = 0
    foreach ($f in $files) {
        try {
            $src = Join-Path $From ($f['path'].Replace('/', '\'))
            $dst = Join-Path $script:CH ($f['path'].Replace('/', '\'))
            $d = Split-Path -Path $dst -Parent
            if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            Copy-Item -LiteralPath $src -Destination $dst -Force; $n++
        } catch { Write-Log ERROR ("{0}: {1}" -f $f['path'], $_.Exception.Message); $fail++ }
    }
    foreach ($c in $created) {
        $p = Join-Path $script:CH ([string]$c).Replace('/', '\')
        if (Test-Path -LiteralPath $p) {
            Remove-Item -LiteralPath $p -Force -Confirm:$false
            $par = Split-Path -Path $p -Parent
            while ($par -and $par -ne $script:CH -and (Test-Path -LiteralPath $par) -and -not (Get-ChildItem -LiteralPath $par -Force)) { Remove-Item -LiteralPath $par -Force -Confirm:$false; $par = Split-Path -Path $par -Parent }
            Write-Log INFO ("Removed (did not exist at backup time): {0}" -f $c)
        }
    }
    Write-Log OK ("Restored {0} file(s), failures={1}. Pre-restore backup: {2}" -f $n, $fail, $pre)
    if ($fail -gt 0) { exit 1 } else { exit 0 }
} catch { Write-Log ERROR $_.Exception.Message; exit 1 }
