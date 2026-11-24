#Requires -Version 7.0
<#
.SYNOPSIS
Removes the global AI Software Factory installation from the user profile.

.DESCRIPTION
Removes the files recorded in the install manifest under ~/.copilot. Other agents, skills and settings in
~/.copilot are not touched. Files that were edited are kept and reported, unless -Force is used.
Projects are not touched: their .devai/ directories stay.

.PARAMETER ProfileRoot
Home directory that contains .copilot. Defaults to the current user's home.

.PARAMETER Force
Remove factory files even if they were edited.

.EXAMPLE
./scripts/uninstall-global.ps1
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

$result = Uninstall-Payload -Root $root -ManifestRel $script:GlobalManifestRel -Force:$Force

if ($WhatIfPreference) {
    Write-Host 'Dry run: nothing was changed.'
    return
}

Write-Host "AI Software Factory $($result.Version) removed from $root"
Write-Host "  Files: $($result.Stats.Removed) removed, $($result.Stats.Kept) kept"
Write-Host 'Project work items in .devai/ were not touched.'
