<#
.SYNOPSIS
  Validate the repository content and/or the installed Claude config.
.PARAMETER Scope
  Repo      = check repo files (frontmatter, models, permissions, secrets, absolute paths)
  Installed = check the target config matches the repo and is well-formed
  All       = both (default)
.NOTES
  Exit code 0 = no FAIL, 1 = at least one FAIL. WARN does not fail.
#>
[CmdletBinding()]
param([string]$ClaudeHome, [ValidateSet('Repo', 'Installed', 'All')][string]$Scope = 'All')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')
Initialize-Env -ClaudeHome $ClaudeHome -DryRun -Name 'validate'
$script:fails = 0; $script:warns = 0
function Pass($m) { Write-Log OK $m }
function Fail($m) { Write-Log ERROR $m; $script:fails++ }
function Warn($m) { Write-Log WARN $m; $script:warns++ }

$v = $script:Manifest.validation

function Test-Agent {
    param([string]$Path, [string]$Label)
    $t = Read-Text $Path
    if ($null -eq (Get-Frontmatter $t)) { Fail "$Label : no YAML frontmatter"; return }
    $base = [IO.Path]::GetFileNameWithoutExtension($Path)
    foreach ($f in $v.agentRequiredFields) { if ($null -eq (Get-FmValue $t $f)) { Fail "$Label : missing '$f'" } }
    $n = Get-FmValue $t 'name'
    if ($n -and $n -ne $base) { Fail "$Label : name '$n' != file name '$base'" }
    $mo = Get-FmValue $t 'model'
    if ($mo) {
        if (($v.modelAliases -contains $mo) -or ($mo -match $v.modelIdPattern)) { } else { Fail "$Label : unknown model '$mo'" }
    } else { Warn "$Label : no model (inherits the session model)" }
    $ef = Get-FmValue $t 'effort'
    if ($ef -and ($v.effortLevels -notcontains $ef)) { Fail "$Label : invalid effort '$ef'" }
    $tools = Get-FmValue $t 'tools'
    if ($tools -and $tools -match '\bAgent\b') { Warn "$Label : has the Agent tool (can spawn sub-agents)" }
}

function Test-Skill {
    param([string]$Dir, [string]$Label)
    $sk = Join-Path $Dir 'SKILL.md'
    if (-not (Test-Path -LiteralPath $sk)) { Fail "$Label : SKILL.md missing"; return }
    $t = Read-Text $sk
    if ($null -eq (Get-Frontmatter $t)) { Fail "$Label : no frontmatter"; return }
    $n = Get-FmValue $t 'name'
    if (-not $n) { Fail "$Label : missing name" } elseif ($n -ne (Split-Path -Leaf $Dir)) { Fail "$Label : name '$n' != folder '$(Split-Path -Leaf $Dir)'" }
    if (-not (Get-FmValue $t 'description')) { Fail "$Label : missing description" }
}

function Test-SettingsObj {
    param($o, [string]$Label)
    $mo = $null; if ($o.Contains('model')) { $mo = [string]$o['model'] }
    if ($mo) { if (($v.modelAliases -contains $mo) -or ($mo -match $v.modelIdPattern)) { Pass "$Label : model '$mo'" } else { Fail "$Label : unknown model '$mo'" } }
    $p = $null; if ($o.Contains('permissions')) { $p = $o['permissions'] }
    if (-not $p) { Fail "$Label : no permissions section"; return }
    $deny = @(); if ($p.Contains('deny')) { $deny = @($p['deny']) }
    $ask = @(); if ($p.Contains('ask')) { $ask = @($p['ask']) }
    $allow = @(); if ($p.Contains('allow')) { $allow = @($p['allow']) }
    foreach ($r in $v.requiredDeny) { if ($deny -notcontains $r) { Fail "$Label : permissions.deny missing '$r'" } }
    foreach ($r in $v.requiredAsk) { if ($ask -notcontains $r) { Fail "$Label : permissions.ask missing '$r'" } }
    foreach ($r in $v.forbiddenAllow) { if ($allow -contains $r) { Fail "$Label : permissions.allow contains broad rule '$r'" } }
    if (-not $p.Contains('disableBypassPermissionsMode') -or $p['disableBypassPermissionsMode'] -ne 'disable') { Fail "$Label : disableBypassPermissionsMode is not 'disable'" }
    else { Pass "$Label : bypass-permissions mode disabled" }
    if ($o.Contains('skipDangerousModePermissionPrompt') -and $o['skipDangerousModePermissionPrompt']) { Fail "$Label : skipDangerousModePermissionPrompt is on" }
}

try {
    if ($Scope -in 'Repo', 'All') {
        Write-Log STEP 'Repo checks'
        # JSON
        foreach ($j in 'manifest.json', 'global/settings.json', 'machine/settings.example.json', 'machine/mcp.example.json') {
            $p = Join-Path $script:RepoRoot $j
            if (Test-Path -LiteralPath $p) { try { [void](Read-JsonOrdered $p); Pass "valid JSON: $j" } catch { Fail "invalid JSON: $j" } }
            else { Warn "missing: $j" }
        }
        $rs = Join-Path $script:RepoRoot 'global/settings.json'
        if (Test-Path -LiteralPath $rs) { try { Test-SettingsObj (Read-JsonOrdered $rs) 'global/settings.json' } catch { } }
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'global/agents') -Filter '*.md' -File -ErrorAction SilentlyContinue) { Test-Agent $f.FullName ("agents/" + $f.Name) }
        foreach ($d in Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'global/skills') -Directory -ErrorAction SilentlyContinue) { Test-Skill $d.FullName ("skills/" + $d.Name) }
        if (-not (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'global/CLAUDE.md'))) { Fail 'global/CLAUDE.md missing' } else { Pass 'global/CLAUDE.md present' }
        if (-not (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'global/hooks'))) { Pass 'hooks: none in repo (optional)' }
        # secrets / abs paths / non-ascii scripts
        $scan = @(Get-ChildItem -LiteralPath $script:RepoRoot -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\(\.git|logs)\\' })
        $sec = 0; $abs = 0
        foreach ($f in $scan) {
            $rel = $f.FullName.Substring($script:RepoRoot.Length + 1)
            $h = @(Test-SecretFile $f.FullName)
            if ($h.Count -gt 0) { Fail ("possible secret in {0}: {1}" -f $rel, ($h -join ', ')); $sec++ }
            if ($rel -notmatch '^(docs|tests)\\') {
                $a = @(Test-AbsPath $f.FullName)
                if ($a.Count -gt 0) { Warn ("machine-specific absolute path in {0}: {1}" -f $rel, ($a -join ', ')); $abs++ }
            }
            if ($f.Extension -eq '.ps1') {
                $bytes = [IO.File]::ReadAllBytes($f.FullName)
                if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) { Fail "non-ASCII characters in $rel (breaks Windows PowerShell 5.1)" }
            }
        }
        if ($sec -eq 0) { Pass ("secret scan: {0} files clean" -f $scan.Count) }
        if ($abs -eq 0) { Pass 'no machine-specific absolute paths' }
    }
    if ($Scope -in 'Installed', 'All') {
        Write-Log STEP ("Installed checks: {0}" -f $script:CH)
        if (-not (Test-Path -LiteralPath $script:CH)) { Fail 'config dir missing' }
        else {
            $state = Get-State
            $plan = @(Get-Plan (Get-AllComponents) $state)
            foreach ($i in $plan) {
                switch ($i.Status) {
                    'Unchanged' { }
                    'New' { Fail ("not installed: {0}" -f $i.Id) }
                    'Update' { Warn ("repo newer than installed: {0} (run update.ps1)" -f $i.Id) }
                    'Customized' { Warn ("locally edited: {0} {1}" -f $i.Id, $i.Detail) }
                    'Conflict' { Warn ("differs from repo, not installed by this tool: {0} {1}" -f $i.Id, $i.Detail) }
                    'Missing' { Fail ("not installed: {0}" -f $i.Id) }
                }
            }
            if (@($plan | Where-Object { $_.Status -eq 'Unchanged' }).Count -eq $plan.Count -and $plan.Count -gt 0) { Pass ("all {0} managed items match the repo" -f $plan.Count) }
            $sp = Join-Path $script:CH 'settings.json'
            if (Test-Path -LiteralPath $sp) { try { Test-SettingsObj (Read-JsonOrdered $sp) 'installed settings.json' } catch { Fail 'installed settings.json is not valid JSON' } }
            else { Fail 'installed settings.json missing' }
            foreach ($f in Get-ChildItem -LiteralPath (Join-Path $script:CH 'agents') -Filter '*.md' -File -ErrorAction SilentlyContinue) { Test-Agent $f.FullName ("installed agents/" + $f.Name) }
            foreach ($d in Get-ChildItem -LiteralPath (Join-Path $script:CH 'skills') -Directory -ErrorAction SilentlyContinue) { if ($d.Name -ne 'synced') { Test-Skill $d.FullName ("installed skills/" + $d.Name) } }
            $cr = Join-Path $script:CH '.credentials.json'
            if (Test-Path -LiteralPath $cr) { Pass 'signed in (credentials file present; contents not read)' } else { Warn 'not signed in yet: run `claude` then /login, or sign in via Claude Desktop' }
        }
        if (-not (Find-Claude)) { Warn 'Claude Code CLI not found (OK for Desktop-only use)' }
        Warn 'Not checkable here: MCP/plugin sign-ins and Claude Desktop model picker - see docs/INSTALLATION.md checklist'
        $script:warns--   # informational reminder, not a real warning
    }
    Write-Log STEP ("Result: {0} FAIL, {1} WARN" -f $script:fails, $script:warns)
    if ($script:fails -gt 0) { exit 1 } else { exit 0 }
} catch { Write-Log ERROR $_.Exception.Message; exit 1 }
