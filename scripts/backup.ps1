<#
.SYNOPSIS
  Back up the managed part of the Claude config (timestamped, structure preserved).
.DESCRIPTION
  Default: copies CLAUDE.md, settings.json, agents, skills (not skills/synced), templates, hooks
  into <ClaudeHome>\backups\claude-environment\<timestamp>-manual\ with backup-manifest.json.
  Files that look like they contain secrets are skipped (use -IncludeFlagged to override).
  .credentials.json, .claude.json, history, projects and caches are never included.
  -ToRepo: instead copy the live config INTO this repo's global/ folder (for committing).
#>
[CmdletBinding()]
param(
    [string]$ClaudeHome,
    [string]$Destination,
    [switch]$IncludeFlagged,
    [switch]$ToRepo,
    [switch]$Yes,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')
Initialize-Env -ClaudeHome $ClaudeHome -Yes:$Yes -DryRun:$DryRun -Name 'backup'

function Get-LiveFilesForRepo {
    $m = $script:Manifest
    foreach ($cn in 'instructions', 'agents', 'skills', 'templates', 'hooks') {
        $c = $m.components.$cn
        if ($c.type -eq 'files') {
            foreach ($e in $c.map) { $p = Join-Path $script:CH $e.dst; if (Test-Path -LiteralPath $p) { [pscustomobject]@{ Live = $p; Repo = (Join-Path $script:RepoRoot $e.src) } } }
        } else {
            $root = Join-Path $script:CH $c.dst
            if (Test-Path -LiteralPath $root) {
                foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File) {
                    $sub = $f.FullName.Substring($root.Length + 1)
                    if ($cn -eq 'skills' -and $sub -like 'synced\*') { continue }
                    [pscustomobject]@{ Live = $f.FullName; Repo = (Join-Path (Join-Path $script:RepoRoot $c.src) $sub) }
                }
            }
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $script:CH)) { Write-Log ERROR "Config dir not found: $script:CH"; exit 1 }
    if (-not $ToRepo) {
        $d = New-Backup -Label 'manual' -Dest $Destination -IncludeFlagged:$IncludeFlagged
        if ($d) { Write-Log INFO ("Manifest: {0}" -f (Join-Path $d 'backup-manifest.json')) }
        exit 0
    }
    # ---- capture into repo
    $changes = @(); $flagged = @()
    foreach ($p in Get-LiveFilesForRepo) {
        $hits = @(Test-SecretFile $p.Live)
        if ($hits.Count -gt 0) { $flagged += ('{0} ({1})' -f $p.Live.Substring($script:CH.Length + 1), ($hits -join ', ')); continue }
        $abs = @(Test-AbsPath $p.Live)
        if ($abs.Count -gt 0) { Write-Log WARN ("{0} contains machine-specific path(s): {1}" -f $p.Live.Substring($script:CH.Length + 1), ($abs -join ', ')) }
        $st = 'New'
        if (Test-Path -LiteralPath $p.Repo) { if ((Get-FileHashNorm $p.Live) -eq (Get-FileHashNorm $p.Repo)) { $st = 'Same' } else { $st = 'Changed' } }
        if ($st -ne 'Same') { $changes += [pscustomobject]@{ St = $st; P = $p } }
    }
    # managed settings keys: refresh values of keys already present in repo settings
    $rs = Join-Path $script:RepoRoot $script:Manifest.settings.src
    $ls = Join-Path $script:CH $script:Manifest.settings.dst
    $newSettings = $null
    if ((Test-Path -LiteralPath $rs) -and (Test-Path -LiteralPath $ls)) {
        $repoObj = Read-JsonOrdered $rs; $liveObj = Read-JsonOrdered $ls
        function Sync-Keys($r, $l) { foreach ($k in @($r.Keys)) { if (-not $l.Contains($k)) { continue }
                if ($r[$k] -is [System.Collections.IDictionary] -and $l[$k] -is [System.Collections.IDictionary]) { Sync-Keys $r[$k] $l[$k] } else { $r[$k] = $l[$k] } } }
        Sync-Keys $repoObj $liveObj
        $txt = (ConvertTo-JsonText $repoObj) + "`n"
        if ((Get-TextHash $txt) -ne (Get-FileHashNorm $rs)) { $newSettings = $txt }
    }
    foreach ($c in $changes) { Write-Log INFO ("{0,-8} {1}" -f $c.St, $c.P.Live.Substring($script:CH.Length + 1)) }
    if ($newSettings) { Write-Log INFO 'Changed  settings.json (managed keys only)' }
    foreach ($f in $flagged) { Write-Log WARN ("Skipped (possible secret): {0}" -f $f) }
    if ($changes.Count -eq 0 -and -not $newSettings) { Write-Log OK 'Repo already matches the live config.'; exit 0 }
    if ($DryRun) { Write-Log INFO '[dry-run] nothing written.'; exit 0 }
    if (-not (Confirm-Step 'Copy these into the repository (global/)? Review with git diff afterwards.')) { Write-Log SKIP 'Cancelled.'; exit 0 }
    foreach ($c in $changes) { Copy-Managed $c.P.Live $c.P.Repo }
    if ($newSettings) { Write-Text $rs $newSettings }
    Write-Log OK 'Captured. Run .\scripts\validate.ps1 -Scope Repo, then review `git diff` before committing.'
    exit 0
} catch { Write-Log ERROR $_.Exception.Message; exit 1 }
