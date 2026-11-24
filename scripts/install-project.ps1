#Requires -Version 7.0
<#
.SYNOPSIS
Installs the AI Software Factory into a project.

.DESCRIPTION
Copies the agents, skills and factory core into the project, merges the managed rules block into AGENTS.md,
and creates .devai/config.yaml if it does not exist.

Safe to run again: it upgrades the factory-owned files and never overwrites .devai/config.yaml,
.devai/work-items/ or the rest of AGENTS.md. It stops before changing anything if a factory file was edited
in the project or already exists but was not installed by the factory.

.PARAMETER Target
Project directory to install into. It must already exist.

.PARAMETER Force
Overwrite factory files that were edited in the project or that the factory did not install.

.EXAMPLE
./scripts/install-project.ps1 -Target C:\src\my-app

.EXAMPLE
./scripts/install-project.ps1 C:\src\my-app -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Target,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/factory.ps1')

$Target = Assert-ExistingDirectory $Target 'Target directory'
Assert-NotInsideTemplate $Target

$globalManifest = Join-Path (Get-GlobalRoot $HOME) $script:GlobalManifestRel
if (Test-Path -LiteralPath $globalManifest) {
    Write-Warning 'A global installation exists for this user. The project copy will be listed next to the global one in VS Code. Uninstall one of them to avoid duplicates.'
}

$result = Install-Payload `
    -Plan (@(Get-ProjectPlan $Target)) `
    -Seeds (@(Get-ProjectSeeds $Target)) `
    -Root $Target `
    -ManifestRel $script:ProjectManifestRel `
    -Scope project `
    -Force:$Force

$agentsResult = Set-AgentsBlock (Join-Path $Target 'AGENTS.md') (Get-AgentsBlock)

if ($WhatIfPreference) {
    Write-Host 'Dry run: nothing was changed.'
    return
}

$s = $result.Stats
$from = if ($result.PreviousVersion) { " (was $($result.PreviousVersion))" } else { '' }
Write-Host "AI Software Factory $($result.Version) installed in $Target$from"
Write-Host "  Factory files: $($s.Created) created, $($s.Updated) updated, $($s.Unchanged) unchanged, $($s.Removed) removed"
Write-Host "  AGENTS.md: $agentsResult"
Write-Host "  .devai/config.yaml: $(if ($s.Seeded -gt 0) { 'created' } else { 'kept' })"
Write-Host 'Next: reload the VS Code window, open Copilot Chat, select the coordinator agent and run /workflow-start.'
