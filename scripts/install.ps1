<#
.SYNOPSIS
  Install the Claude Code global environment from this repository.
.DESCRIPTION
  Idempotent. Backs up first. Never touches credentials, history, MCP servers or
  files outside the managed set. Files you edited after a previous install are kept.
.PARAMETER Component
  all (default) | instructions | agents | skills | templates | hooks | routing | permissions | settings
  routing = settings "model" + agent model/effort frontmatter only.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
  .\scripts\install.ps1 -Component agents,skills -DryRun
  .\scripts\install.ps1 -Component routing
#>
[CmdletBinding()]
param(
    [string]$ClaudeHome,
    [string[]]$Component = @('all'),
    [switch]$Menu,
    [switch]$Yes,
    [switch]$Force,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')
Initialize-Env -ClaudeHome $ClaudeHome -Yes:$Yes -Force:$Force -DryRun:$DryRun -Name 'install'
try { $rc = Invoke-Sync -Mode Install -Components $Component -Menu:$Menu }
catch { Write-Log ERROR $_.Exception.Message; $rc = 1 }
exit $rc
