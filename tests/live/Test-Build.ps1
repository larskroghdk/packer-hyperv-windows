<#
.SYNOPSIS
    Runs the explicitly authorized live Hyper-V installation and release gates.

.EXAMPLE
    Get-Help tests/live/Test-Build.ps1 -Full

.NOTES
    Author: Lars Krogh
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        '10-22H2',
        '11-24H2',
        '11-25H2',
        '11-26H2'
    )]
    [string]$Version,
    [Parameter(Mandatory)]
    [string]$SettingsPath,
    [switch]$AuthorizeLiveBuild,
    [string]$ExternalStorage
)

$ErrorActionPreference = 'Stop'

if (-not $AuthorizeLiveBuild) {
    throw 'Live integration creates and disposes an isolated VM and consumes storage. Supply -AuthorizeLiveBuild explicitly on a dedicated host.'
}

& (Join-Path $PSScriptRoot '..\..\scripts\Build.ps1') -Version $Version -SettingsPath $SettingsPath -Build -ExternalStorage $ExternalStorage
