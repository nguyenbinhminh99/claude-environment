<#
.SYNOPSIS
  End-to-end tests. Uses temp directories only - never touches your real ~/.claude.
#>
[CmdletBinding()]
param([switch]$KeepTemp)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('ce-tests-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null
$pass = 0; $failc = 0

function Check([string]$Name, [bool]$Cond, [string]$Info = '') {
    if ($Cond) { Write-Host "  PASS  $Name" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  FAIL  $Name $Info" -ForegroundColor Red; $script:failc++ }
}
function Run([string]$Root, [string]$Script, [string[]]$Args2) {
    $ErrorActionPreference = 'Continue'
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "scripts\$Script") @Args2 2>&1 | Out-String
    return [pscustomobject]@{ Rc = $LASTEXITCODE; Out = $out }
}
function NewRepoCopy([string]$Name) {
    $d = Join-Path $tmp $Name
    Copy-Item -LiteralPath $repo -Destination $d -Recurse
    Remove-Item -LiteralPath (Join-Path $d 'logs') -Recurse -Force -ErrorAction SilentlyContinue
    return $d
}
function TreeHash([string]$Dir) {
    $l = Get-ChildItem -LiteralPath $Dir -Recurse -File | Where-Object { $_.FullName -notmatch '\\backups\\' } | Sort-Object FullName |
        ForEach-Object { $_.FullName.Substring($Dir.Length) + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash }
    return ($l -join '|')
}
function Same([string]$A, [string]$B) { return ((Get-FileHash -LiteralPath $A).Hash -eq (Get-FileHash -LiteralPath $B).Hash) }

try {
    Write-Host "`n[0] not elevated" -ForegroundColor Cyan
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Check 'test session is not Administrator (scripts must work without it)' (-not $admin)

    Write-Host "`n[1] fresh install into empty config dir" -ForegroundColor Cyan
    $h1 = Join-Path $tmp 'home1'
    $r = Run $repo 'install.ps1' @('-ClaudeHome', $h1, '-Yes')
    Check 'exit 0' ($r.Rc -eq 0) $r.Out
    Check 'CLAUDE.md identical to repo' (Same "$h1\CLAUDE.md" "$repo\global\CLAUDE.md")
    Check '7 agents installed' (@(Get-ChildItem "$h1\agents" -Filter *.md).Count -eq 7)
    Check '7 skills installed' (@(Get-ChildItem "$h1\skills" -Directory).Count -eq 7)
    $s = Get-Content "$h1\settings.json" -Raw | ConvertFrom-Json
    Check 'settings.json valid, model=opusplan' ($s.model -eq 'opusplan')
    Check 'bypass mode disabled' ($s.permissions.disableBypassPermissionsMode -eq 'disable')
    Check 'no theme written (machine-specific)' ($null -eq $s.theme)
    Check 'architect = opus/high' ((Get-Content "$h1\agents\architect.md" -Raw) -match '(?m)^model: opus\r?\n' -and (Get-Content "$h1\agents\architect.md" -Raw) -match '(?m)^effort: high')
    Check 'no credentials created' (-not (Test-Path "$h1\.credentials.json"))
    $v = Run $repo 'validate.ps1' @('-ClaudeHome', $h1)
    Check 'validate passes on fresh install' ($v.Rc -eq 0) $v.Out

    Write-Host "`n[3] re-install is idempotent" -ForegroundColor Cyan
    $before = TreeHash $h1
    $nb = @(Get-ChildItem "$h1\backups\claude-environment" -Directory).Count
    $r = Run $repo 'install.ps1' @('-ClaudeHome', $h1, '-Yes')
    Check 'exit 0' ($r.Rc -eq 0)
    Check 'reports nothing to do' ($r.Out -match 'Nothing to do')
    Check 'tree unchanged' ($before -eq (TreeHash $h1))
    Check 'no extra backup, no duplicate files' (@(Get-ChildItem "$h1\backups\claude-environment" -Directory).Count -eq $nb)

    Write-Host "`n[2] install over an existing, customised config" -ForegroundColor Cyan
    $h2 = Join-Path $tmp 'home2'
    New-Item -ItemType Directory -Path "$h2\agents", "$h2\skills\synced\x" -Force | Out-Null
    Set-Content "$h2\agents\mine.md" "---`nname: mine`ndescription: x`n---`nmine" -Encoding UTF8
    Set-Content "$h2\skills\synced\x\SKILL.md" 'synced' -Encoding UTF8
    Set-Content "$h2\.credentials.json" 'DO-NOT-TOUCH' -Encoding UTF8
    Set-Content "$h2\CLAUDE.md" 'my own global notes' -Encoding UTF8
    '{ "theme": "light", "model": "sonnet", "permissions": { "allow": ["Bash(ls *)"], "deny": ["Read(//**/secret.txt)"] }, "env": { "FOO": "1" } }' | Set-Content "$h2\settings.json" -Encoding UTF8
    $origSettings = Get-Content "$h2\settings.json" -Raw
    $r = Run $repo 'install.ps1' @('-ClaudeHome', $h2, '-Yes')
    Check 'exit 0' ($r.Rc -eq 0) $r.Out
    Check 'own CLAUDE.md kept (conflict, no -Force)' ((Get-Content "$h2\CLAUDE.md" -Raw).Trim() -eq 'my own global notes')
    Check 'unmanaged agent kept' (Test-Path "$h2\agents\mine.md")
    Check 'synced skills untouched' ((Get-Content "$h2\skills\synced\x\SKILL.md" -Raw).Trim() -eq 'synced')
    Check 'credentials untouched' ((Get-Content "$h2\.credentials.json" -Raw).Trim() -eq 'DO-NOT-TOUCH')
    $s = Get-Content "$h2\settings.json" -Raw | ConvertFrom-Json
    Check 'theme/env/allow preserved' ($s.theme -eq 'light' -and $s.env.FOO -eq '1' -and $s.permissions.allow -contains 'Bash(ls *)')
    Check 'own model=sonnet kept (needs -Force)' ($s.model -eq 'sonnet')
    Check 'deny list is union (own + managed)' ($s.permissions.deny -contains 'Read(//**/secret.txt)' -and $s.permissions.deny -contains 'Read(~/.ssh/**)')
    Check 'bypass disabled added' ($s.permissions.disableBypassPermissionsMode -eq 'disable')
    $bk = Get-ChildItem "$h2\backups\claude-environment" -Directory | Select-Object -Last 1
    Check 'pre-install backup holds original settings' ((Get-Content "$($bk.FullName)\settings.json" -Raw) -eq $origSettings)
    Write-Host "  -- rollback via restore.ps1" -ForegroundColor DarkGray
    $r = Run $repo 'restore.ps1' @('-ClaudeHome', $h2, '-From', $bk.FullName, '-Yes')
    Check 'restore exit 0' ($r.Rc -eq 0) $r.Out
    Check 'settings.json back to original' ((Get-Content "$h2\settings.json" -Raw) -eq $origSettings)
    Check 'installed agents removed again' (-not (Test-Path "$h2\agents\architect.md"))
    Check 'own files still there' ((Test-Path "$h2\agents\mine.md") -and (Test-Path "$h2\.credentials.json"))
    Check 'state file removed' (-not (Test-Path "$h2\claude-environment.state.json"))

    Write-Host "`n[4] backup + restore" -ForegroundColor Cyan
    $dest = Join-Path $tmp 'bk-manual'
    $r = Run $repo 'backup.ps1' @('-ClaudeHome', $h1, '-Destination', $dest)
    Check 'backup exit 0' ($r.Rc -eq 0) $r.Out
    Check 'manifest written' (Test-Path "$dest\backup-manifest.json")
    Check 'structure kept' (Test-Path "$dest\agents\architect.md")
    Check 'credentials/.claude.json never copied' (-not (Test-Path "$dest\.credentials.json"))
    Add-Content "$h1\CLAUDE.md" "`nBROKEN EDIT"
    Remove-Item "$h1\agents\scout.md" -Force
    $r = Run $repo 'restore.ps1' @('-ClaudeHome', $h1, '-From', $dest, '-Yes')
    Check 'restore exit 0' ($r.Rc -eq 0) $r.Out
    Check 'CLAUDE.md restored' (Same "$h1\CLAUDE.md" "$repo\global\CLAUDE.md")
    Check 'scout.md restored' (Test-Path "$h1\agents\scout.md")
    Check 'pre-restore backup created' (@(Get-ChildItem "$h1\backups\claude-environment" -Directory | Where-Object Name -like '*pre-restore').Count -ge 1)

    Write-Host "`n[5] update flow" -ForegroundColor Cyan
    $rc = NewRepoCopy 'repo-update'
    Add-Content "$rc\global\agents\scout.md" "`n<!-- repo change -->"
    Add-Content "$rc\global\agents\architect.md" "`n<!-- repo change 2 -->"
    Add-Content "$h1\agents\architect.md" "`n<!-- my local edit -->"
    $r = Run $rc 'update.ps1' @('-ClaudeHome', $h1, '-DryRun')
    Check 'dry-run shows Update + Customized and writes nothing' ($r.Out -match 'Update\s+\[agents\] agents/scout.md' -and $r.Out -match 'Customized\s+\[agents\] agents/architect.md' -and -not ((Get-Content "$h1\agents\scout.md" -Raw) -match 'repo change'))
    $r = Run $rc 'update.ps1' @('-ClaudeHome', $h1, '-Yes')
    Check 'update exit 0' ($r.Rc -eq 0) $r.Out
    Check 'scout updated' ((Get-Content "$h1\agents\scout.md" -Raw) -match 'repo change')
    Check 'locally edited architect kept' ((Get-Content "$h1\agents\architect.md" -Raw) -match 'my local edit' -and (Get-Content "$h1\agents\architect.md" -Raw) -notmatch 'repo change 2')
    $r = Run $rc 'update.ps1' @('-ClaudeHome', $h1, '-Yes', '-Force')
    Check '-Yes -Force overwrites customised file' ((Get-Content "$h1\agents\architect.md" -Raw) -match 'repo change 2' -and (Get-Content "$h1\agents\architect.md" -Raw) -notmatch 'my local edit')

    Write-Host "`n[5b] component selection + routing only" -ForegroundColor Cyan
    $h5 = Join-Path $tmp 'home5'
    $r = Run $repo 'install.ps1' @('-ClaudeHome', $h5, '-Component', 'skills', '-Yes')
    Check 'skills only: skills yes, agents/CLAUDE.md/settings no' ((Test-Path "$h5\skills\feature-workflow\SKILL.md") -and -not (Test-Path "$h5\agents") -and -not (Test-Path "$h5\CLAUDE.md") -and -not (Test-Path "$h5\settings.json"))
    $r = Run $repo 'install.ps1' @('-ClaudeHome', $h5, '-Component', 'instructions', '-Yes')
    Check 'instructions only' ((Test-Path "$h5\CLAUDE.md") -and -not (Test-Path "$h5\agents"))
    $r = Run $repo 'install.ps1' @('-ClaudeHome', $h5, '-Component', 'agents', '-Yes')
    $a = Get-Content "$h5\agents\scout.md" -Raw
    Set-Content "$h5\agents\scout.md" ($a -replace '(?m)^model: haiku', 'model: sonnet') -NoNewline
    $r = Run $repo 'install.ps1' @('-ClaudeHome', $h5, '-Component', 'routing', '-Yes', '-Force')
    Check 'routing-only fixes agent model + sets model' ((Get-Content "$h5\agents\scout.md" -Raw) -match '(?m)^model: haiku' -and (Get-Content "$h5\settings.json" -Raw) -match '"model": "opusplan"') $r.Out
    Check 'routing-only did not add permissions' ((Get-Content "$h5\settings.json" -Raw) -notmatch 'permissions')

    Write-Host "`n[6] optional/missing components" -ForegroundColor Cyan
    $rm = NewRepoCopy 'repo-missing'
    Remove-Item "$rm\global\skills" -Recurse -Force
    $h6 = Join-Path $tmp 'home6'
    $r = Run $rm 'install.ps1' @('-ClaudeHome', $h6, '-Yes')
    Check 'installs the rest, exit 0, warns about skills' ($r.Rc -eq 0 -and $r.Out -match "Component 'skills'" -and (Test-Path "$h6\agents\scout.md"))
    $r = Run $repo 'install.ps1' @('-ClaudeHome', $h6, '-Component', 'hooks', '-Yes')
    Check 'hooks absent in repo: skipped cleanly' ($r.Rc -eq 0 -and $r.Out -match 'optional')
    Remove-Item "$h6\settings.json" -Force
    '{ broken' | Set-Content "$h6\settings.json"
    $r = Run $repo 'install.ps1' @('-ClaudeHome', $h6, '-Yes', '-Component', 'settings,permissions,routing')
    Check 'corrupt target settings.json is not overwritten' ((Get-Content "$h6\settings.json" -Raw).Trim() -eq '{ broken')

    Write-Host "`n[8] absolute path detection" -ForegroundColor Cyan
    $ra = NewRepoCopy 'repo-abs'
    Add-Content "$ra\global\CLAUDE.md" ("`nsee " + 'C:\Users\someone\proj')
    $r = Run $ra 'validate.ps1' @('-Scope', 'Repo')
    Check 'validate warns about C:\Users\... path' ($r.Out -match 'machine-specific absolute path')

    Write-Host "`n[9] secret detection" -ForegroundColor Cyan
    $rs = NewRepoCopy 'repo-secret'
    $fake = 'sk-' + 'ant-' + ('a1B2' * 8)
    Add-Content "$rs\global\CLAUDE.md" "`nkey = $fake"
    Set-Content "$rs\global\.env" 'X=1'
    $r = Run $rs 'validate.ps1' @('-Scope', 'Repo')
    Check 'validate fails (rc=1) on key-like string and .env file' ($r.Rc -eq 1 -and $r.Out -match 'Anthropic API key' -and $r.Out -match 'sensitive file name')
    Check 'output does not echo the secret' ($r.Out -notmatch [regex]::Escape($fake))
    $h9 = Join-Path $tmp 'home9'
    New-Item -ItemType Directory -Path "$h9\agents" -Force | Out-Null
    Set-Content "$h9\agents\leaky.md" "---`nname: leaky`ndescription: x`n---`npassword = hunter2hunter2hunter2" -Encoding UTF8
    Set-Content "$h9\agents\fine.md" "---`nname: fine`ndescription: x`n---`nok" -Encoding UTF8
    $r = Run $repo 'backup.ps1' @('-ClaudeHome', $h9, '-Destination', (Join-Path $tmp 'bk9'))
    Check 'backup skips file with secret by default, keeps clean one' (-not (Test-Path "$tmp\bk9\agents\leaky.md") -and (Test-Path "$tmp\bk9\agents\fine.md"))

    Write-Host "`n[10] uninstall" -ForegroundColor Cyan
    $r = Run $repo 'uninstall.ps1' @('-ClaudeHome', $h1, '-Yes')
    Check 'uninstall exit 0, files removed, settings kept' ($r.Rc -eq 0 -and -not (Test-Path "$h1\agents\scout.md") -and (Test-Path "$h1\settings.json"))

    Write-Host "`n[11] repo self-validation" -ForegroundColor Cyan
    $r = Run $repo 'validate.ps1' @('-Scope', 'Repo')
    Check 'real repo passes validate' ($r.Rc -eq 0) $r.Out
}
finally {
    if (-not $KeepTemp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$false }
}
Write-Host ("`nTotal: {0} passed, {1} failed" -f $pass, $failc) -ForegroundColor $(if ($failc) { 'Red' } else { 'Green' })
if ($failc -gt 0) { exit 1 } else { exit 0 }
