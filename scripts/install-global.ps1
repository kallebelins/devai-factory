#Requires -Version 7.0
<#
.SYNOPSIS
Installs the AI Software Factory in the user profile, for every project.

.DESCRIPTION
Installs for the Copilot harness in VS Code:

  ~/.copilot/agents/                 the ten agents
  ~/.copilot/skills/workflow-*/      /workflow-start, /workflow-resume, /workflow-status
  ~/.copilot/software-factory/       core (contracts, templates), the universal rules, the install manifest

Paths inside the agents and skills are rewritten to the absolute location of ~/.copilot/software-factory/.
Nothing is written to any project. Each project gets .devai/config.yaml and .devai/work-items/ the first time
/workflow-start runs there.

The Local harness stores user agents in VS Code profile storage and is not covered.

Safe to run again: it upgrades the factory files. It stops before changing anything if a factory file was
edited, or if an agent or skill with the same name exists and was not installed by the factory.

.PARAMETER ProfileRoot
Home directory that contains .copilot. Defaults to the current user's home.

.PARAMETER Force
Overwrite files that were edited or that the factory did not install.

.EXAMPLE
./scripts/install-global.ps1

.EXAMPLE
./scripts/install-global.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProfileRoot = $HOME,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/factory.ps1')

$ProfileRoot = Assert-ExistingDirectory $ProfileRoot 'Profile directory'
$root = Get-GlobalRoot $ProfileRoot

$result = Install-Payload `
    -Plan (@(Get-GlobalPlan $ProfileRoot)) `
    -Root $root `
    -ManifestRel $script:GlobalManifestRel `
    -Scope global `
    -Force:$Force

if ($WhatIfPreference) {
    Write-Host 'Dry run: nothing was changed.'
    return
}

$s = $result.Stats
$from = if ($result.PreviousVersion) { " (was $($result.PreviousVersion))" } else { '' }
Write-Host "AI Software Factory $($result.Version) installed in $root$from"
Write-Host "  Files: $($s.Created) created, $($s.Updated) updated, $($s.Unchanged) unchanged, $($s.Removed) removed"
Write-Host 'Next: reload the VS Code window, open any project, select the coordinator agent and run /workflow-start.'
Write-Host 'Do not also install the factory into a project that uses the global one: the agents would be listed twice.'
