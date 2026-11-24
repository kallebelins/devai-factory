#Requires -Version 7.0
<#
.SYNOPSIS
Removes the AI Software Factory from a project.

.DESCRIPTION
Removes the files recorded in the install manifest and the managed block in AGENTS.md. Other content in
AGENTS.md is kept, and the file is deleted only if nothing else is left in it.

Factory files that were edited in the project are kept and reported, unless -Force is used.
.devai/config.yaml is removed only if it was created by the installer and never edited.
.devai/work-items/ is always kept unless -Purge is used.

.PARAMETER Target
Project directory to uninstall from.

.PARAMETER Purge
Also delete the whole .devai/ directory: config and every work item. Asks for confirmation.
Work items are the project's design record. Back them up first.

.PARAMETER Force
Remove factory files even if they were edited in the project.

.EXAMPLE
./scripts/uninstall-project.ps1 -Target C:\src\my-app

.EXAMPLE
./scripts/uninstall-project.ps1 C:\src\my-app -Purge
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Target,

    [switch]$Purge,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/factory.ps1')

$Target = Assert-ExistingDirectory $Target 'Target directory'

$result = Uninstall-Payload -Root $Target -ManifestRel $script:ProjectManifestRel -Force:$Force
$agentsResult = Remove-AgentsBlock (Join-Path $Target 'AGENTS.md')

$purged = $false
$devai = Join-Path $Target '.devai'
if ($Purge -and (Test-Path -LiteralPath $devai)) {
    if ($PSCmdlet.ShouldProcess($devai, 'Delete the whole directory: config and ALL work items')) {
        Remove-Item -LiteralPath $devai -Recurse -Force
        $purged = $true
    }
}

if ($WhatIfPreference) {
    Write-Host 'Dry run: nothing was changed.'
    return
}

Write-Host "AI Software Factory $($result.Version) removed from $Target"
Write-Host "  Files: $($result.Stats.Removed) removed, $($result.Stats.Kept) kept"
Write-Host "  AGENTS.md: $agentsResult"
if ($purged) { Write-Host '  .devai/: deleted' }
elseif (Test-Path -LiteralPath (Join-Path $devai 'work-items')) { Write-Host '  .devai/work-items/: kept. Use -Purge to delete it.' }
