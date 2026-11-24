# Shared helpers for the install and uninstall scripts.
# Dot-source this file from a script in ../. Do not run it directly.

Set-StrictMode -Version Latest

$script:RepoRoot     = (Resolve-Path (Join-Path $PSScriptRoot '../..')).ProviderPath
$script:TemplateRoot = Join-Path $script:RepoRoot 'template'
$script:BlockBegin   = '<!-- software-factory:begin -->'
$script:BlockEnd     = '<!-- software-factory:end -->'
$script:BlockPattern = '(?s)' + [regex]::Escape($script:BlockBegin) + '.*?' + [regex]::Escape($script:BlockEnd)

# Manifest locations, relative to the install root.
$script:ProjectManifestRel = '.devai/core/manifest.json'
$script:GlobalManifestRel  = 'software-factory/manifest.json'

# ---------------------------------------------------------------- text and hashing

function Read-Text {
    # Reads a text file as UTF-8 with LF line endings, so hashes ignore CRLF and BOM differences.
    param([Parameter(Mandatory)][string]$Path)
    ([IO.File]::ReadAllText($Path)) -replace "`r`n", "`n"
}

function Get-TextHash {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text)))
}

function Get-FileTextHash {
    param([Parameter(Mandatory)][string]$Path)
    Get-TextHash (Read-Text $Path)
}

# ---------------------------------------------------------------- template

function Get-TemplateVersion {
    (Read-Text (Join-Path $script:TemplateRoot '.devai/core/VERSION')).Trim()
}

function Get-TemplateFiles {
    # Factory-owned files, as paths relative to template/ with forward slashes.
    foreach ($sub in '.github', '.devai/core') {
        $base = Join-Path $script:TemplateRoot $sub
        if (-not (Test-Path -LiteralPath $base)) { throw "Template is incomplete: missing $base" }
        Get-ChildItem -LiteralPath $base -Recurse -File -Force | ForEach-Object {
            [IO.Path]::GetRelativePath($script:TemplateRoot, $_.FullName).Replace('\', '/')
        }
    }
}

function Get-AgentsBlock {
    $text = Read-Text (Join-Path $script:TemplateRoot 'AGENTS.md')
    $m = [regex]::Match($text, $script:BlockPattern)
    if (-not $m.Success) { throw 'template/AGENTS.md has no managed block.' }
    $m.Value
}

function New-PlanEntry {
    param([string]$Rel, [string]$Dest, [string]$Text)
    [pscustomobject]@{ Rel = $Rel; Dest = $Dest; Text = $Text; Hash = (Get-TextHash $Text) }
}

# ---------------------------------------------------------------- install plans

function Get-ProjectPlan {
    param([Parameter(Mandatory)][string]$Target)
    foreach ($rel in Get-TemplateFiles) {
        New-PlanEntry $rel (Join-Path $Target $rel) (Read-Text (Join-Path $script:TemplateRoot $rel))
    }
}

function Get-ProjectSeeds {
    # Files created once from a template. After that they belong to the project.
    param([Parameter(Mandatory)][string]$Target)
    $text = Read-Text (Join-Path $script:TemplateRoot '.devai/core/templates/config.yaml')
    New-PlanEntry '.devai/config.yaml' (Join-Path $Target '.devai/config.yaml') $text
}

function ConvertTo-GlobalText {
    # In a global install the core and the rules file are outside the project, so the
    # project-relative tokens in agents and skills become absolute paths.
    param([string]$Text, [string]$FactoryRoot)
    $Text = $Text.Replace('.devai/core/', "$FactoryRoot/core/")
    $Text.Replace('`AGENTS.md`', "``$FactoryRoot/AGENTS.md``")
}

function Get-GlobalPlan {
    param([Parameter(Mandatory)][string]$ProfileRoot)
    $root = Join-Path $ProfileRoot '.copilot'
    $factoryRoot = (Join-Path $root 'software-factory').Replace('\', '/')

    foreach ($rel in Get-TemplateFiles) {
        $text = Read-Text (Join-Path $script:TemplateRoot $rel)
        if ($rel.StartsWith('.github/')) {
            $dest = $rel.Substring('.github/'.Length)          # agents/..., skills/...
            $text = ConvertTo-GlobalText $text $factoryRoot
        }
        else {
            $dest = 'software-factory/' + $rel.Substring('.devai/'.Length)   # software-factory/core/...
        }
        New-PlanEntry $dest (Join-Path $root $dest) $text
    }

    $rules = ((Get-AgentsBlock) -split "`n" | Where-Object { $_ -notmatch '^<!--.*-->\s*$' }) -join "`n"
    $note = "> Installed globally. Factory files are in ``$factoryRoot``. Project files (``.devai/config.yaml`` and ``.devai/work-items/``) stay in each project.`n`n"
    $text = $note + (ConvertTo-GlobalText $rules.Trim() $factoryRoot) + "`n"
    New-PlanEntry 'software-factory/AGENTS.md' (Join-Path $root 'software-factory/AGENTS.md') $text
}

# ---------------------------------------------------------------- manifest

function Read-Manifest {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { throw "Cannot read the install manifest at $Path : $($_.Exception.Message)" }
}

# ---------------------------------------------------------------- file operations

function Remove-EmptyParents {
    # Removes empty directories above $Path, stopping before $StopAt.
    param([string]$Path, [string]$StopAt)
    $stop = [IO.Path]::GetFullPath($StopAt).TrimEnd('\', '/')
    $dir = Split-Path -Parent $Path
    while ($dir -and ([IO.Path]::GetFullPath($dir).TrimEnd('\', '/') -ne $stop) -and (Test-Path -LiteralPath $dir -PathType Container)) {
        if (@(Get-ChildItem -LiteralPath $dir -Force).Count -gt 0) { break }
        Remove-Item -LiteralPath $dir
        $dir = Split-Path -Parent $dir
    }
}

function Install-Payload {
    param(
        [Parameter(Mandatory)][object[]]$Plan,
        [object[]]$Seeds = @(),
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ManifestRel,
        [Parameter(Mandatory)][ValidateSet('project', 'global')][string]$Scope,
        [switch]$Force
    )

    $manifestPath = Join-Path $Root $ManifestRel
    $old = Read-Manifest $manifestPath
    $oldFiles = @{}
    $oldSeeded = @{}
    if ($old) {
        foreach ($p in $old.files.PSObject.Properties) { $oldFiles[$p.Name] = $p.Value }
        foreach ($p in $old.seeded.PSObject.Properties) { $oldSeeded[$p.Name] = $p.Value }
    }

    # 1. Detect conflicts before changing anything.
    $conflicts = @(foreach ($e in $Plan) {
            if (-not (Test-Path -LiteralPath $e.Dest)) { continue }
            if (-not (Test-Path -LiteralPath $e.Dest -PathType Leaf)) {
                [pscustomobject]@{ Path = $e.Dest; Reason = 'a directory exists at this path' }
                continue
            }
            $current = Get-FileTextHash $e.Dest
            if ($current -eq $e.Hash) { continue }
            if ($oldFiles.ContainsKey($e.Rel)) {
                if ($current -ne $oldFiles[$e.Rel]) { [pscustomobject]@{ Path = $e.Dest; Reason = 'modified since it was installed' } }
            }
            else {
                [pscustomobject]@{ Path = $e.Dest; Reason = 'exists and was not installed by the factory' }
            }
        })
    if ($conflicts.Count -gt 0 -and -not $Force) {
        foreach ($c in $conflicts) { Write-Warning "$($c.Path): $($c.Reason)" }
        throw "Installation stopped before any change: $($conflicts.Count) file(s) would be overwritten. Review them, then run again with -Force to overwrite."
    }

    # 2. Write factory-owned files.
    $stats = [ordered]@{ Created = 0; Updated = 0; Unchanged = 0; Removed = 0; Seeded = 0 }
    foreach ($e in $Plan) {
        $exists = Test-Path -LiteralPath $e.Dest -PathType Leaf
        if ($exists -and (Get-FileTextHash $e.Dest) -eq $e.Hash) { $stats.Unchanged++; continue }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $e.Dest) | Out-Null
        Set-Content -LiteralPath $e.Dest -Value $e.Text -NoNewline -Encoding utf8NoBOM
        if ($exists) { $stats.Updated++ } else { $stats.Created++ }
    }

    # 3. Remove files that an older version installed and this version no longer has.
    $newRels = @{}
    foreach ($e in $Plan) { $newRels[$e.Rel] = $true }
    foreach ($rel in @($oldFiles.Keys | Where-Object { -not $newRels.ContainsKey($_) })) {
        $dest = Join-Path $Root $rel
        if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) { continue }
        if ((Get-FileTextHash $dest) -ne $oldFiles[$rel] -and -not $Force) {
            Write-Warning "Left in place (modified, and no longer part of the factory): $dest"
            continue
        }
        Remove-Item -LiteralPath $dest
        Remove-EmptyParents $dest $Root
        $stats.Removed++
    }

    # 4. Seed project-owned files that do not exist yet. Never overwrite them.
    $seeded = [ordered]@{}
    foreach ($s in $Seeds) {
        if (Test-Path -LiteralPath $s.Dest) {
            if ($oldSeeded.ContainsKey($s.Rel)) { $seeded[$s.Rel] = $oldSeeded[$s.Rel] }
            continue
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $s.Dest) | Out-Null
        Set-Content -LiteralPath $s.Dest -Value $s.Text -NoNewline -Encoding utf8NoBOM
        $seeded[$s.Rel] = $s.Hash
        $stats.Seeded++
    }

    # 5. Record what was installed.
    $files = [ordered]@{}
    foreach ($e in ($Plan | Sort-Object Rel)) { $files[$e.Rel] = $e.Hash }
    $manifest = [ordered]@{
        schema      = 1
        scope       = $Scope
        version     = Get-TemplateVersion
        installedAt = (Get-Date).ToUniversalTime().ToString('o')
        files       = $files
        seeded      = $seeded
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $manifestPath) | Out-Null
    Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 5) -Encoding utf8NoBOM

    $previous = $null
    if ($old) { $previous = $old.version }
    [pscustomobject]@{ PreviousVersion = $previous; Version = $manifest.version; Stats = $stats }
}

function Uninstall-Payload {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ManifestRel,
        [switch]$Force
    )

    $manifestPath = Join-Path $Root $ManifestRel
    $m = Read-Manifest $manifestPath
    if (-not $m) { throw "No AI Software Factory installation found in $Root (missing $ManifestRel)." }

    $stats = [ordered]@{ Removed = 0; Kept = 0 }

    foreach ($p in $m.files.PSObject.Properties) {
        $dest = Join-Path $Root $p.Name
        if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) { continue }
        if ((Get-FileTextHash $dest) -ne $p.Value -and -not $Force) {
            Write-Warning "Kept (modified since it was installed): $dest. Use -Force to remove it."
            $stats.Kept++
            continue
        }
        Remove-Item -LiteralPath $dest
        Remove-EmptyParents $dest $Root
        $stats.Removed++
    }

    # Seeded files belong to the project. Remove them only if they are still the unedited seed.
    foreach ($p in $m.seeded.PSObject.Properties) {
        $dest = Join-Path $Root $p.Name
        if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) { continue }
        if ((Get-FileTextHash $dest) -eq $p.Value) {
            Remove-Item -LiteralPath $dest
            Remove-EmptyParents $dest $Root
            $stats.Removed++
        }
        else {
            Write-Host "  Kept (edited by the project): $dest"
            $stats.Kept++
        }
    }

    Remove-Item -LiteralPath $manifestPath
    Remove-EmptyParents $manifestPath $Root
    [pscustomobject]@{ Version = $m.version; Stats = $stats }
}

# ---------------------------------------------------------------- AGENTS.md managed block

function Set-AgentsBlock {
    # Inserts or replaces the managed block. Returns created | updated | appended | unchanged.
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Block)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Set-Content -LiteralPath $Path -Value ($Block + "`n") -NoNewline -Encoding utf8NoBOM
        return 'created'
    }

    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $raw = [IO.File]::ReadAllText($Path)
    $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $b = $Block.Replace("`n", $nl)

    if ([regex]::IsMatch($raw, $script:BlockPattern)) {
        $evaluator = [Text.RegularExpressions.MatchEvaluator] { param($m) $b }
        $new = [regex]::Replace($raw, $script:BlockPattern, $evaluator, 'None')
        $result = 'updated'
    }
    else {
        $sep = if ($raw.Length -eq 0 -or $raw.EndsWith($nl + $nl)) { '' } elseif ($raw.EndsWith($nl)) { $nl } else { $nl + $nl }
        $new = $raw + $sep + $b + $nl
        $result = 'appended'
    }

    if ($new -eq $raw) { return 'unchanged' }
    $encoding = if ($hasBom) { 'utf8BOM' } else { 'utf8NoBOM' }
    Set-Content -LiteralPath $Path -Value $new -NoNewline -Encoding $encoding
    $result
}

function Remove-AgentsBlock {
    # Removes the managed block. Deletes the file if nothing else is left.
    # Returns absent | removed | deleted.
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 'absent' }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $raw = [IO.File]::ReadAllText($Path)
    if (-not [regex]::IsMatch($raw, $script:BlockPattern)) { return 'absent' }

    $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $new = [regex]::Replace($raw, $script:BlockPattern + '(\r?\n)?', '')
    if ($new.Trim().Length -eq 0) {
        Remove-Item -LiteralPath $Path
        return 'deleted'
    }
    $new = [regex]::Replace($new, '(\r?\n){3,}', $nl + $nl).TrimEnd() + $nl
    $encoding = if ($hasBom) { 'utf8BOM' } else { 'utf8NoBOM' }
    Set-Content -LiteralPath $Path -Value $new -NoNewline -Encoding $encoding
    'removed'
}

# ---------------------------------------------------------------- checks

function Assert-ExistingDirectory {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "$Label not found: $Path" }
    (Resolve-Path -LiteralPath $Path).ProviderPath
}

function Assert-NotInsideTemplate {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $tpl = [IO.Path]::GetFullPath($script:TemplateRoot).TrimEnd('\', '/')
    if ($full -eq $tpl -or $full.StartsWith($tpl + [IO.Path]::DirectorySeparatorChar)) {
        throw "Refusing to use a directory inside this repository's template/ folder: $Path"
    }
}

function Get-GlobalRoot {
    param([string]$ProfileRoot)
    Join-Path $ProfileRoot '.copilot'
}
