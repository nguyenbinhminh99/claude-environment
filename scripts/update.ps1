<#
.SYNOPSIS
  Compare the target config with this repository, show the differences, apply on confirmation.
.DESCRIPTION
  Same engine as install.ps1 but always prints a diff first. Items you edited locally
  (Customized) or that this tool never installed (Conflict) are kept unless you confirm each one.
  Run `git pull` yourself first if you want the newest repo content.
  To push local edits INTO the repo instead, use: .\scripts\backup.ps1 -ToRepo
.EXAMPLE
  .\scripts\update.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$ClaudeHome,
    [string[]]$Component = @('all'),
    [switch]$Yes,
    [switch]$Force,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')
Initialize-Env -ClaudeHome $ClaudeHome -Yes:$Yes -Force:$Force -DryRun:$DryRun -Name 'update'
try { $rc = Invoke-Sync -Mode Update -Components $Component }
catch { Write-Log ERROR $_.Exception.Message; $rc = 1 }
exit $rc
