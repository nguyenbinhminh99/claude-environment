<#
.SYNOPSIS
  Remove the files this tool installed (only those still identical to what it installed).
.DESCRIPTION
  Backs up first. Files you edited since install are left alone. settings.json is NOT edited
  (use restore.ps1 with the install backup to revert it). Unmanaged agents/skills are never touched.
#>
[CmdletBinding()]
param([string]$ClaudeHome, [switch]$Yes, [switch]$DryRun)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')
Initialize-Env -ClaudeHome $ClaudeHome -Yes:$Yes -DryRun:$DryRun -Name 'uninstall'
try {
    $state = Get-State
    $rels = @($state['files'].Keys)
    if ($rels.Count -eq 0) { Write-Log INFO 'No install state found; nothing to uninstall.'; exit 0 }
    $del = @(); $keep = @()
    foreach ($r in $rels) {
        $p = Join-Path $script:CH $r.Replace('/', '\')
        if (-not (Test-Path -LiteralPath $p)) { continue }
        if ((Get-FileHashNorm $p) -eq $state['files'][$r]) { $del += $r } else { $keep += $r }
    }
    foreach ($r in $del) { Write-Log INFO "Will remove: $r" }
    foreach ($r in $keep) { Write-Log WARN "Keeping (edited since install): $r" }
    if ($DryRun -or $del.Count -eq 0) { if ($DryRun) { Write-Log INFO '[dry-run] nothing removed.' }; exit 0 }
    if (-not (Confirm-Step ("Remove {0} file(s) from {1}? A backup is made first." -f $del.Count, $script:CH))) { Write-Log SKIP 'Cancelled.'; exit 0 }
    $bk = New-Backup -Label 'uninstall' -IncludeFlagged
    foreach ($r in $del) {
        $p = Join-Path $script:CH $r.Replace('/', '\')
        Remove-Item -LiteralPath $p -Force -Confirm:$false
        $state['files'].Remove($r)
        $par = Split-Path -Path $p -Parent
        while ($par -and $par -ne $script:CH -and -not (Get-ChildItem -LiteralPath $par -Force)) { Remove-Item -LiteralPath $par -Force -Confirm:$false; $par = Split-Path -Path $par -Parent }
    }
    Save-State $state
    Write-Log OK ("Removed {0} file(s). Backup: {1}" -f $del.Count, $bk)
    Write-Log INFO 'settings.json was not changed (permissions/model remain). Use restore.ps1 to revert it.'
    exit 0
} catch { Write-Log ERROR $_.Exception.Message; exit 1 }
