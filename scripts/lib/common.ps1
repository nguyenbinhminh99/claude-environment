# common.ps1 - shared helpers, dot-sourced by every script in scripts/.
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
# Compatible with Windows PowerShell 5.1 and PowerShell 7.

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:CH = $null          # Claude config home (target)
$script:AutoYes = $false
$script:ForceAll = $false
$script:IsDry = $false
$script:LogFile = $null

# ---------------------------------------------------------------- init / log
function Initialize-Env {
    param([string]$ClaudeHome, [switch]$Yes, [switch]$Force, [switch]$DryRun, [string]$Name = 'script')
    if (-not $ClaudeHome) { $ClaudeHome = Join-Path $env:USERPROFILE '.claude' }
    $script:CH = [IO.Path]::GetFullPath($ClaudeHome)
    $script:AutoYes = [bool]$Yes
    $script:ForceAll = [bool]$Force
    $script:IsDry = [bool]$DryRun
    $script:Manifest = (Get-Content -LiteralPath (Join-Path $script:RepoRoot 'manifest.json') -Raw) | ConvertFrom-Json
    if (-not $script:IsDry) {
        try {
            $ld = Join-Path $script:RepoRoot 'logs'
            if (-not (Test-Path -LiteralPath $ld)) { New-Item -ItemType Directory -Path $ld -Force | Out-Null }
            $script:LogFile = Join-Path $ld ('{0}-{1}.log' -f $Name, (Get-Date -Format 'yyyyMMdd-HHmmss'))
        } catch { $script:LogFile = $null }
    }
}

function Write-Log {
    param([string]$Level = 'INFO', [string]$Message)
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $color = 'Gray'
    switch ($Level) { 'OK' { $color = 'Green' } 'WARN' { $color = 'Yellow' } 'ERROR' { $color = 'Red' } 'SKIP' { $color = 'DarkYellow' } 'STEP' { $color = 'Cyan' } }
    Write-Host $line -ForegroundColor $color
    if ($script:LogFile) { try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 } catch { } }
}

function Test-Interactive {
    try { return ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) } catch { return $false }
}

# Returns $true when the user (or -Yes) agrees.
function Confirm-Step {
    param([string]$Question, [switch]$NeedsForce)
    if ($script:AutoYes) { if ($NeedsForce) { return $script:ForceAll } else { return $true } }
    if (-not (Test-Interactive)) { return $false }
    $a = Read-Host ("{0} [y/N]" -f $Question)
    return ($a -match '^(y|yes)$')
}

# ---------------------------------------------------------------- text / hash / json
function Read-Text { param([string]$Path) return [IO.File]::ReadAllText($Path) }

function Write-Text {
    param([string]$Path, [string]$Text)
    $d = Split-Path -Path $Path -Parent
    if ($d -and -not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Get-TextHash {
    param([string]$Text)
    $n = $Text -replace "`r`n", "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($n))) -replace '-', '').ToLower()
}

$script:TextExt = @('.md', '.json', '.txt', '.ps1', '.yml', '.yaml', '.toml', '.sh')
function Test-TextFile { param([string]$Path) return ($script:TextExt -contains ([IO.Path]::GetExtension($Path).ToLower())) }

function Get-FileHashNorm {
    param([string]$Path)
    if (Test-TextFile $Path) { return Get-TextHash (Read-Text $Path) }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
}

function Copy-Managed {
    param([string]$Src, [string]$Dst)
    if (Test-TextFile $Src) { Write-Text $Dst (Read-Text $Src) }
    else {
        $d = Split-Path -Path $Dst -Parent
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        Copy-Item -LiteralPath $Src -Destination $Dst -Force
    }
}

function ConvertTo-Ordered {
    param($o)
    if ($null -eq $o) { return $null }
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-Ordered $p.Value }
        return $h
    }
    if ($o -is [System.Collections.IList]) {
        $l = @()
        foreach ($i in $o) { $l += , (ConvertTo-Ordered $i) }
        return , $l
    }
    return $o
}

function ConvertTo-JsonString {
    param([string]$s)
    $e = $s.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`r", '\r').Replace("`t", '\t')
    return '"' + $e + '"'
}

function ConvertTo-JsonText {
    param($o, [int]$Indent = 0)
    $pad = ' ' * ($Indent + 2); $end = ' ' * $Indent
    if ($null -eq $o) { return 'null' }
    if ($o -is [System.Collections.IDictionary]) {
        if ($o.Count -eq 0) { return '{}' }
        $items = @(foreach ($k in $o.Keys) { $pad + (ConvertTo-JsonString ([string]$k)) + ': ' + (ConvertTo-JsonText $o[$k] ($Indent + 2)) })
        return "{`n" + ($items -join ",`n") + "`n$end}"
    }
    if ($o -is [System.Collections.IList]) {
        if ($o.Count -eq 0) { return '[]' }
        $items = @(foreach ($i in $o) { $pad + (ConvertTo-JsonText $i ($Indent + 2)) })
        return "[`n" + ($items -join ",`n") + "`n$end]"
    }
    if ($o -is [bool]) { if ($o) { return 'true' } else { return 'false' } }
    if ($o -is [string]) { return ConvertTo-JsonString $o }
    return [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $o)
}

function Read-JsonOrdered {
    param([string]$Path)
    return ConvertTo-Ordered ((Read-Text $Path) | ConvertFrom-Json)
}

# ---------------------------------------------------------------- secrets / paths scan
$script:SecretPatterns = @(
    @{ N = 'Anthropic API key';     R = 'sk-ant-[A-Za-z0-9_\-]{10,}' },
    @{ N = 'OpenAI-style key';      R = '\bsk-[A-Za-z0-9]{20,}' },
    @{ N = 'GitHub token';          R = '\bgh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}' },
    @{ N = 'AWS access key id';     R = '\bAKIA[0-9A-Z]{16}\b' },
    @{ N = 'Slack token';           R = '\bxox[abprs]-[A-Za-z0-9\-]{10,}' },
    @{ N = 'Private key block';     R = '-----BEGIN [A-Z ]*PRIVATE KEY-----' },
    @{ N = 'JWT';                   R = '\beyJ[A-Za-z0-9_\-]{15,}\.[A-Za-z0-9_\-]{15,}\.[A-Za-z0-9_\-]{5,}' },
    @{ N = 'Credential assignment'; R = '(?i)\b(api[_-]?key|secret|passw(or)?d|token|client[_-]?secret)\b["'']?\s*[:=]\s*["'']?(?!\$|\{|<|your|example|placeholder|changeme|xxx)[A-Za-z0-9/+_\-\.]{12,}' }
)
$script:SensitiveNames = @('.env', '.env.*', '*.pem', '*.key', '*.pfx', 'id_rsa*', 'id_ed25519*', '.credentials.json', '.claude.json', '*.token')

# Returns finding names only (never the matched value).
function Test-SecretFile {
    param([string]$Path)
    $found = @()
    $name = Split-Path -Path $Path -Leaf
    foreach ($pat in $script:SensitiveNames) { if ($name -like $pat) { $found += "sensitive file name ($pat)"; break } }
    if (Test-TextFile $Path) {
        $t = ''
        try { $t = Read-Text $Path } catch { }
        foreach ($p in $script:SecretPatterns) { if ($t -match $p.R) { $found += $p.N } }
    }
    return $found
}

# Windows user-profile style absolute paths that will not exist on another machine.
function Test-AbsPath {
    param([string]$Path)
    if (-not (Test-TextFile $Path)) { return @() }
    $t = ''
    try { $t = Read-Text $Path } catch { return @() }
    $hits = @()
    $ms = [regex]::Matches($t, '(?i)[A-Z]:\\(Users|Documents and Settings)\\[^\\\s"''`]+')
    foreach ($m in $ms) { $hits += $m.Value }
    return @($hits | Select-Object -Unique)
}

# ---------------------------------------------------------------- environment checks
function Find-Claude {
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $cands = @(
        (Join-Path $env:USERPROFILE '.local\bin\claude.exe'),
        (Join-Path $env:APPDATA 'npm\claude.cmd')
    )
    foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    $desk = Join-Path $env:APPDATA 'Claude\claude-code'
    if (Test-Path -LiteralPath $desk) {
        $f = Get-ChildItem -LiteralPath $desk -Recurse -Filter 'claude.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}

function Test-Preflight {
    $ok = $true
    if ($env:OS -ne 'Windows_NT') { Write-Log ERROR 'Windows is required.'; $ok = $false }
    else { Write-Log OK ("Windows detected ({0})" -f [Environment]::OSVersion.VersionString) }
    if ($PSVersionTable.PSVersion -lt [version]'5.1') { Write-Log ERROR ("PowerShell 5.1+ required, found {0}" -f $PSVersionTable.PSVersion); $ok = $false }
    else { Write-Log OK ("PowerShell {0}" -f $PSVersionTable.PSVersion) }
    $admin = $false
    try { $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { }
    if ($admin) { Write-Log WARN 'Running as Administrator is not needed; everything lives under your user profile.' }
    else { Write-Log OK 'Not elevated (Administrator is not required).' }
    $cl = Find-Claude
    if ($cl) { Write-Log OK ("Claude Code CLI found: {0}" -f $cl) }
    else { Write-Log WARN 'Claude Code CLI not found in PATH. If you only use Claude Desktop this is fine (it shares ~/.claude). Otherwise install Claude Code first.' }
    if (-not (Test-Path -LiteralPath $script:CH)) {
        Write-Log WARN ("Config dir does not exist yet: {0} (will be created)" -f $script:CH)
    } else { Write-Log OK ("Config dir: {0}" -f $script:CH) }
    return $ok
}

# ---------------------------------------------------------------- state
function Get-StatePath { return (Join-Path $script:CH 'claude-environment.state.json') }

function Get-State {
    $p = Get-StatePath
    $s = $null
    if (Test-Path -LiteralPath $p) {
        try { $s = Read-JsonOrdered $p } catch { Write-Log WARN 'State file unreadable; treating as no previous install.' }
    }
    if (-not $s) { $s = [ordered]@{ version = 1 } }
    if (-not ($s.Contains('files') -and $s['files'] -is [System.Collections.IDictionary])) { $s['files'] = [ordered]@{} }
    if (-not ($s.Contains('settings') -and $s['settings'] -is [System.Collections.IDictionary])) { $s['settings'] = [ordered]@{} }
    return $s
}

function Save-State {
    param($State)
    if ($script:IsDry) { return }
    $State['updated'] = (Get-Date).ToString('s')
    $State['repoVersion'] = [string]$script:Manifest.version
    Write-Text (Get-StatePath) ((ConvertTo-JsonText $State) + "`n")
}

# ---------------------------------------------------------------- backup
function Get-ManagedTargetFiles {
    # Existing files in the target that this tool may touch (used for backups).
    $list = @()
    foreach ($f in 'CLAUDE.md', 'settings.json', 'claude-environment.state.json') {
        $p = Join-Path $script:CH $f
        if (Test-Path -LiteralPath $p) { $list += $f }
    }
    foreach ($d in 'agents', 'skills', 'templates', 'hooks') {
        $root = Join-Path $script:CH $d
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue) {
            $rel = $f.FullName.Substring($script:CH.Length + 1).Replace('\', '/')
            if ($rel -like 'skills/synced/*') { continue }
            $list += $rel
        }
    }
    return $list
}

function New-Backup {
    param([string]$Label = 'manual', [string]$Dest, [switch]$IncludeFlagged, [string[]]$CreatedFiles = @())
    if ($script:IsDry) { Write-Log INFO "[dry-run] backup skipped"; return $null }
    if (-not $Dest) {
        $Dest = Join-Path $script:CH ('backups\claude-environment\{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), $Label)
    }
    $files = @(); $flagged = @()
    foreach ($rel in Get-ManagedTargetFiles) {
        $src = Join-Path $script:CH $rel
        $hits = @(Test-SecretFile $src)
        if ($hits.Count -gt 0 -and -not $IncludeFlagged) { $flagged += [ordered]@{ path = $rel; reasons = $hits }; continue }
        $dst = Join-Path $Dest $rel
        $d = Split-Path -Path $dst -Parent
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        Copy-Item -LiteralPath $src -Destination $dst -Force
        $files += [ordered]@{ path = $rel; sha256 = (Get-FileHashNorm $src) }
    }
    if (-not (Test-Path -LiteralPath $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
    $man = [ordered]@{
        tool = 'claude-environment'; schema = 1; label = $Label
        created = (Get-Date).ToString('s'); computer = $env:COMPUTERNAME
        source = $script:CH; files = $files; createdFiles = @($CreatedFiles); skippedPossibleSecrets = $flagged
    }
    Write-Text (Join-Path $Dest 'backup-manifest.json') ((ConvertTo-JsonText $man) + "`n")
    Write-Log OK ("Backup '{0}': {1} file(s) -> {2}" -f $Label, $files.Count, $Dest)
    if ($flagged.Count -gt 0) { Write-Log WARN ("{0} file(s) NOT backed up because they look like they contain secrets (use -IncludeFlagged to override)." -f $flagged.Count) }
    return $Dest
}

# ---------------------------------------------------------------- sync plan
function Get-AllComponents { return @('instructions', 'agents', 'skills', 'templates', 'hooks', 'routing', 'permissions', 'settings') }

function Resolve-Components {
    param([string[]]$Names)
    # -File mode passes "a,b" as one string, so split on commas ourselves.
    $n = @($Names | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
    if ($n.Count -eq 0 -or $n -contains 'all') { return (Get-AllComponents) }
    $bad = @($n | Where-Object { (Get-AllComponents) -notcontains $_ })
    if ($bad.Count -gt 0) { throw ("Unknown component(s): {0}. Valid: all, {1}" -f ($bad -join ', '), ((Get-AllComponents) -join ', ')) }
    return @(Get-AllComponents | Where-Object { $n -contains $_ })
}
function Get-SourceFiles {
    param($c)
    $out = @()
    if ($c.type -eq 'files') {
        foreach ($e in $c.map) {
            $s = Join-Path $script:RepoRoot $e.src
            if (Test-Path -LiteralPath $s) { $out += [pscustomobject]@{ Src = $s; Rel = [string]$e.dst } }
        }
    } else {
        $root = Join-Path $script:RepoRoot $c.src
        if (Test-Path -LiteralPath $root) {
            foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Name -ne '.gitkeep' }) {
                $out += [pscustomobject]@{ Src = $f.FullName; Rel = ([string]$c.dst + '/' + $f.FullName.Substring($root.Length + 1).Replace('\', '/')) }
            }
        }
    }
    return $out
}

function New-Item2 {
    param($Component, $Kind, $Id, $Rel, $Status, $Detail = '', $Extra = $null)
    return [pscustomobject]@{ Component = $Component; Kind = $Kind; Id = $Id; Rel = $Rel; Status = $Status; Detail = $Detail; Extra = $Extra; Result = ''; Note = '' }
}

function Get-SettingComponent {
    param([string]$TopKey)
    $s = $script:Manifest.settings
    if ($s.routingKeys -contains $TopKey) { return 'routing' }
    if ($s.permissionKeys -contains $TopKey) { return 'permissions' }
    return 'settings'
}

function Get-SettingOps {
    param($Repo, $Cur, [string]$Prefix, $State, [string]$Top)
    $ops = @()
    foreach ($k in @($Repo.Keys)) {
        $path = if ($Prefix) { "$Prefix.$k" } else { [string]$k }
        $topKey = if ($Top) { $Top } else { [string]$k }
        $comp = Get-SettingComponent $topKey
        $rv = $Repo[$k]
        $has = ($Cur -is [System.Collections.IDictionary]) -and $Cur.Contains($k)
        $cv = $null; if ($has) { $cv = $Cur[$k] }
        if ($rv -is [System.Collections.IDictionary]) {
            if (-not $has) { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'New' 'add section' @{ Path = $path; Op = 'set'; Value = $rv }; continue }
            if ($cv -is [System.Collections.IDictionary]) { $ops += Get-SettingOps $rv $cv $path $State $topKey; continue }
            $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'Conflict' 'target has a non-object here' @{ Path = $path; Op = 'set'; Value = $rv }
        }
        elseif ($rv -is [System.Collections.IList]) {
            if (-not $has) { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'New' ("add {0} item(s)" -f $rv.Count) @{ Path = $path; Op = 'set'; Value = $rv }; continue }
            if (-not ($cv -is [System.Collections.IList])) { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'Conflict' 'target is not a list' @{ Path = $path; Op = 'set'; Value = $rv }; continue }
            $missing = @($rv | Where-Object { $cv -notcontains $_ })
            if ($missing.Count -gt 0) { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'Update' ("add {0} item(s), keep yours" -f $missing.Count) @{ Path = $path; Op = 'add'; Items = $missing } }
            else { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'Unchanged' '' @{ Path = $path; Op = 'none' } }
        }
        else {
            $ex = @{ Path = $path; Op = 'set'; Value = $rv }
            if (-not $has) { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'New' ("set {0}" -f $rv) $ex; continue }
            if ([string]$cv -ceq [string]$rv) { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'Unchanged' '' $ex; continue }
            $rec = $null; if ($State['settings'].Contains($path)) { $rec = $State['settings'][$path] }
            $detail = "'{0}' -> '{1}'" -f $cv, $rv
            if ($null -ne $rec -and [string]$rec -ceq [string]$cv) { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'Update' $detail $ex }
            elseif ($null -ne $rec) { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'Customized' $detail $ex }
            else { $ops += New-Item2 $comp 'setting' "settings:$path" 'settings.json' 'Conflict' $detail $ex }
        }
    }
    return $ops
}

function Set-AtPath {
    param($Root, [string]$Path, $Value, [switch]$Append)
    $parts = $Path.Split('.')
    $node = $Root
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        if (-not ($node.Contains($parts[$i]) -and $node[$parts[$i]] -is [System.Collections.IDictionary])) { $node[$parts[$i]] = [ordered]@{} }
        $node = $node[$parts[$i]]
    }
    $leaf = $parts[-1]
    if ($Append) {
        $l = @(); if ($node.Contains($leaf)) { $l = @($node[$leaf]) }
        foreach ($v in $Value) { if ($l -notcontains $v) { $l += $v } }
        $node[$leaf] = $l
    } else { $node[$leaf] = $Value }
}

function Get-Frontmatter {
    param([string]$Text)
    $m = [regex]::Match($Text, '(?s)\A---\r?\n(.*?)\r?\n---')
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}

function Get-FmValue {
    param([string]$Text, [string]$Field)
    $fm = Get-Frontmatter $Text
    if ($null -eq $fm) { return $null }
    $m = [regex]::Match($fm, "(?m)^$([regex]::Escape($Field)):[ \t]*(.+?)[ \t]*\r?$")
    if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}

function Set-FmValue {
    param([string]$Text, [string]$Field, [string]$Value)
    $m = [regex]::Match($Text, '(?s)\A(---\r?\n)(.*?)(\r?\n---)')
    if (-not $m.Success) { return $Text }
    $body = $m.Groups[2].Value
    $rx = "(?m)^$([regex]::Escape($Field)):[ \t]*.+?[ \t]*(\r?)$"
    if ($body -match $rx) { $body = [regex]::Replace($body, $rx, ("{0}: {1}`$1" -f $Field, $Value)) }
    else { $body = $body + "`n" + ("{0}: {1}" -f $Field, $Value) }
    return $m.Groups[1].Value + $body + $m.Groups[3].Value + $Text.Substring($m.Length)
}

function Get-Plan {
    param([string[]]$Components, $State)
    $plan = @()
    $m = $script:Manifest
    foreach ($cn in $Components) {
        $c = $m.components.$cn
        if (-not $c) { continue }
        if ($c.type -eq 'settings') { continue }
        $srcs = @(Get-SourceFiles $c)
        if ($srcs.Count -eq 0) {
            if ($c.optional) { Write-Log INFO ("Component '{0}': nothing in repo (optional) - skipped." -f $cn) }
            else { Write-Log WARN ("Component '{0}': no source files found in repo." -f $cn) }
            continue
        }
        foreach ($s in $srcs) {
            $tgt = Join-Path $script:CH $s.Rel
            $sh = Get-FileHashNorm $s.Src
            $status = 'New'
            if (Test-Path -LiteralPath $tgt) {
                $th = Get-FileHashNorm $tgt
                if ($th -eq $sh) { $status = 'Unchanged' }
                else {
                    $rec = $null; if ($State['files'].Contains($s.Rel)) { $rec = $State['files'][$s.Rel] }
                    if ($rec -and $rec -eq $th) { $status = 'Update' }
                    elseif ($rec) { $status = 'Customized' }
                    else { $status = 'Conflict' }
                }
            }
            $plan += New-Item2 $cn 'file' $s.Rel $s.Rel $status '' @{ Src = $s.Src; Hash = $sh }
        }
    }
    # settings
    $setComps = @($Components | Where-Object { $_ -in 'routing', 'permissions', 'settings' })
    $srcSettings = Join-Path $script:RepoRoot $m.settings.src
    if ($setComps.Count -gt 0 -and (Test-Path -LiteralPath $srcSettings)) {
        $repo = Read-JsonOrdered $srcSettings
        $cur = [ordered]@{}
        $tp = Join-Path $script:CH $m.settings.dst
        $broken = $false
        if (Test-Path -LiteralPath $tp) {
            try { $cur = Read-JsonOrdered $tp } catch { $broken = $true }
        }
        if ($broken) { Write-Log ERROR 'Target settings.json is not valid JSON; settings left untouched. Fix it or restore a backup.' }
        else {
            foreach ($op in (Get-SettingOps $repo $cur '' $State '')) { if ($setComps -contains $op.Component) { $plan += $op } }
        }
    }
    # routing also covers agent frontmatter when agents are not installed wholesale
    if (($Components -contains 'routing') -and -not ($Components -contains 'agents')) {
        $fields = @($m.settings.agentRoutingFields)
        $adir = Join-Path $script:RepoRoot $m.components.agents.src
        if (Test-Path -LiteralPath $adir) {
            foreach ($f in Get-ChildItem -LiteralPath $adir -Filter '*.md' -File) {
                $rel = 'agents/' + $f.Name
                $tgt = Join-Path $script:CH $rel
                $rt = Read-Text $f.FullName
                if (-not (Test-Path -LiteralPath $tgt)) {
                    $plan += New-Item2 'routing' 'frontmatter' "routing:$rel" $rel 'Missing' 'agent not installed here (install the agents component)' $null
                    continue
                }
                $tt = Read-Text $tgt
                $diffs = @()
                foreach ($fld in $fields) {
                    $rv = Get-FmValue $rt $fld
                    if ($null -eq $rv) { continue }
                    $tv = Get-FmValue $tt $fld
                    if ($tv -ne $rv) { $diffs += @{ Field = $fld; Value = $rv; Old = $tv } }
                }
                if ($diffs.Count -eq 0) { $plan += New-Item2 'routing' 'frontmatter' "routing:$rel" $rel 'Unchanged' '' $null }
                else {
                    $d = ($diffs | ForEach-Object { "{0}: '{1}' -> '{2}'" -f $_.Field, $_.Old, $_.Value }) -join '; '
                    $plan += New-Item2 'routing' 'frontmatter' "routing:$rel" $rel 'Conflict' $d @{ Diffs = $diffs; Src = $f.FullName }
                }
            }
        }
    }
    return $plan
}

function Show-Plan {
    param($Plan, [switch]$Diff)
    $changes = @($Plan | Where-Object { $_.Status -ne 'Unchanged' })
    $same = @($Plan | Where-Object { $_.Status -eq 'Unchanged' }).Count
    Write-Host ''
    foreach ($i in $changes) {
        $color = 'White'
        switch ($i.Status) { 'New' { $color = 'Green' } 'Update' { $color = 'Cyan' } 'Customized' { $color = 'Yellow' } 'Conflict' { $color = 'Magenta' } 'Missing' { $color = 'DarkGray' } }
        Write-Host ('  {0,-10} [{1}] {2} {3}' -f $i.Status, $i.Component, $i.Id, $i.Detail) -ForegroundColor $color
        if ($Diff -and $i.Kind -eq 'file' -and $i.Status -in 'Update', 'Customized', 'Conflict') {
            $old = (Read-Text (Join-Path $script:CH $i.Rel)) -split "`r?`n"
            $new = (Read-Text $i.Extra.Src) -split "`r?`n"
            $d = @(Compare-Object -ReferenceObject $old -DifferenceObject $new | Select-Object -First 30)
            foreach ($l in $d) {
                if ($l.SideIndicator -eq '=>') { Write-Host ('      + ' + $l.InputObject) -ForegroundColor DarkGreen }
                else { Write-Host ('      - ' + $l.InputObject) -ForegroundColor DarkRed }
            }
        }
    }
    Write-Host ("  ({0} item(s) already up to date)" -f $same) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  New=will be added | Update=repo newer, your copy untouched since last install | Customized=you edited it (kept unless confirmed) | Conflict=exists but not installed by this tool (kept unless confirmed)' -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-Sync {
    param([ValidateSet('Install', 'Update')][string]$Mode, [string[]]$Components, [switch]$Menu)
    if (-not (Test-Preflight)) { return 2 }
    $comps = Resolve-Components $Components
    if ($Menu) {
        $all = Get-AllComponents
        for ($i = 0; $i -lt $all.Count; $i++) { Write-Host ('  {0}) {1}' -f ($i + 1), $all[$i]) }
        $a = Read-Host 'Numbers separated by commas (empty = all)'
        if ($a.Trim()) { $comps = @($a.Split(',') | ForEach-Object { $n = 0; if ([int]::TryParse($_.Trim(), [ref]$n) -and $n -ge 1 -and $n -le $all.Count) { $all[$n - 1] } }) }
    }
    if ($comps.Count -eq 0) { Write-Log ERROR 'No component selected.'; return 2 }
    Write-Log STEP ("{0}: components = {1}" -f $Mode, ($comps -join ', '))
    $state = Get-State
    $plan = @(Get-Plan $comps $state)
    Show-Plan $plan -Diff:($Mode -eq 'Update')
    $todo = @($plan | Where-Object { $_.Status -in 'New', 'Update', 'Customized', 'Conflict' })
    $adopt = @($plan | Where-Object { $_.Status -eq 'Unchanged' -and $_.Kind -eq 'file' -and -not $state['files'].Contains($_.Rel) })
    if ($todo.Count -eq 0 -and $adopt.Count -eq 0) { Write-Log OK 'Nothing to do - target already matches the repository.'; return 0 }
    if ($script:IsDry) { Write-Log INFO '[dry-run] no changes written.'; return 0 }

    if ($todo.Count -gt 0) {
        if (-not (Confirm-Step ("Apply changes to {0}? A backup is made first." -f $script:CH))) {
            if ($script:AutoYes) { } else { Write-Log SKIP 'Cancelled (or non-interactive without -Yes). Nothing changed.'; return 0 }
        }
    }
    # decide which items are allowed
    foreach ($i in $todo) {
        $ok = $false
        switch ($i.Status) {
            'New' { $ok = $true }
            'Update' { $ok = $true }
            default {
                if ($script:AutoYes) { $ok = $script:ForceAll }
                elseif (Test-Interactive) { $ok = Confirm-Step ("Overwrite '{0}' ({1})?" -f $i.Id, $i.Status) }
            }
        }
        $i | Add-Member -NotePropertyName Allowed -NotePropertyValue $ok -Force
    }
    $created = @()
    foreach ($i in $todo) { if ($i.Allowed -and $i.Kind -eq 'file' -and $i.Status -eq 'New') { $created += $i.Rel } }
    $sdst = $script:Manifest.settings.dst
    if (-not (Test-Path -LiteralPath (Join-Path $script:CH $sdst)) -and @($todo | Where-Object { $_.Kind -eq 'setting' -and $_.Allowed }).Count -gt 0) { $created += $sdst }
    if (-not (Test-Path -LiteralPath (Get-StatePath))) { $created += 'claude-environment.state.json' }

    $bk = $null
    if (@($todo | Where-Object { $_.Allowed }).Count -gt 0) {
        if (-not (Test-Path -LiteralPath $script:CH)) { New-Item -ItemType Directory -Path $script:CH -Force | Out-Null }
        try { $bk = New-Backup -Label ($Mode.ToLower()) -IncludeFlagged -CreatedFiles $created }
        catch { Write-Log ERROR ("Backup failed ({0}); aborting before any change." -f $_.Exception.Message); return 1 }
    }

    # apply files
    foreach ($i in $todo) {
        if (-not $i.Allowed) { $i.Result = 'Skipped'; $i.Note = if ($i.Status -in 'Customized', 'Conflict') { 'kept your version (use -Yes -Force or answer y)' } else { '' }; continue }
        if ($i.Kind -eq 'file') {
            try {
                Copy-Managed $i.Extra.Src (Join-Path $script:CH $i.Rel)
                $state['files'][$i.Rel] = $i.Extra.Hash
                if ($i.Status -eq 'New') { $i.Result = 'Installed' } else { $i.Result = 'Updated' }
            } catch { $i.Result = 'Failed'; $i.Note = $_.Exception.Message }
        }
        elseif ($i.Kind -eq 'frontmatter') {
            try {
                $tgt = Join-Path $script:CH $i.Rel
                $t = Read-Text $tgt
                foreach ($d in $i.Extra.Diffs) { $t = Set-FmValue $t $d.Field $d.Value }
                Write-Text $tgt $t
                if ((Get-TextHash $t) -eq (Get-FileHashNorm $i.Extra.Src)) { $state['files'][$i.Rel] = (Get-FileHashNorm $i.Extra.Src) }
                $i.Result = 'Updated'
            } catch { $i.Result = 'Failed'; $i.Note = $_.Exception.Message }
        }
    }
    # apply settings (one write)
    $sset = @($plan | Where-Object { $_.Kind -eq 'setting' })
    if ($sset.Count -gt 0) {
        $tp = Join-Path $script:CH $sdst
        try {
            $cur = [ordered]@{}
            if (Test-Path -LiteralPath $tp) { $cur = Read-JsonOrdered $tp }
            $wrote = $false
            foreach ($i in $sset) {
                $e = $i.Extra
                if ($i.Status -eq 'Unchanged') { if ($e.Op -eq 'set' -and ($e.Value -is [string] -or $e.Value -is [bool] -or $e.Value -is [int])) { $state['settings'][$e.Path] = $e.Value }; continue }
                if (-not $i.Allowed) { continue }
                try {
                    if ($e.Op -eq 'add') { Set-AtPath $cur $e.Path $e.Items -Append }
                    else { Set-AtPath $cur $e.Path $e.Value }
                    if ($e.Value -is [string] -or $e.Value -is [bool] -or $e.Value -is [int]) { $state['settings'][$e.Path] = $e.Value }
                    $wrote = $true
                    if ($i.Status -eq 'New') { $i.Result = 'Installed' } else { $i.Result = 'Updated' }
                } catch { $i.Result = 'Failed'; $i.Note = $_.Exception.Message }
            }
            if ($wrote) { Write-Text $tp ((ConvertTo-JsonText $cur) + "`n") }
        } catch { foreach ($i in $sset) { if ($i.Allowed) { $i.Result = 'Failed'; $i.Note = $_.Exception.Message } } }
    }
    # adopt identical files
    foreach ($i in $adopt) { $state['files'][$i.Rel] = $i.Extra.Hash }
    try { Save-State $state } catch { Write-Log ERROR ("Could not write state file: {0}" -f $_.Exception.Message) }

    Write-Host ''
    $fail = 0
    foreach ($i in $todo) {
        $lvl = 'INFO'; switch ($i.Result) { 'Installed' { $lvl = 'OK' } 'Updated' { $lvl = 'OK' } 'Skipped' { $lvl = 'SKIP' } 'Failed' { $lvl = 'ERROR'; $fail++ } }
        Write-Log $lvl ("{0,-9} {1} {2}" -f $i.Result, $i.Id, $i.Note)
    }
    $sum = $todo | Group-Object Result | ForEach-Object { '{0}={1}' -f $_.Name, $_.Count }
    Write-Log STEP ("Summary: {0}; unchanged={1}" -f ($sum -join ' '), @($plan | Where-Object { $_.Status -eq 'Unchanged' }).Count)
    if ($bk) { Write-Log INFO ("Rollback: .\scripts\restore.ps1 -From '{0}'" -f $bk) }
    Write-Log INFO 'Next: sign in (claude /login or Desktop), then run .\scripts\validate.ps1'
    if ($fail -gt 0) { return 1 } else { return 0 }
}
