<#
.SYNOPSIS
    Issues a release manifest only after required guest and offline evidence passes.

.EXAMPLE
    Get-Help scripts/New-Manifest.ps1 -Full

.NOTES
    Author: Lars Krogh
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [hashtable]$Variables,
    [Parameter(Mandatory)]
    [string]$ReportDirectory,
    [Parameter(Mandatory)]
    [string]$Vhdx,
    [Parameter(Mandatory)]
    [datetime]$StartedAt
)

$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

function Read-Report([string]$Name) {
    Get-Content -LiteralPath (Join-Path $ReportDirectory $Name) -Raw | ConvertFrom-Json
}

$validation = Read-Report 'validation.json'
$offline = Read-Report 'offline-validation.json'
$packerManifest = Read-Report 'packer-manifest.json'
$cleanup = Read-Report 'cleanup.json'
$optimization = Read-Report 'optimization.json'
$isWindows11 = $Variables.windows_release -like '11-*'
$hardening = if ($isWindows11) {
    Read-Report 'hardening.json'
}
else {
    @{summary               = @{
            failed  = 0;
            pending = 0
        };
        status              = 'limited_local_policy';
        baseline_compliance = $false
    }
}
$optimizationValidation = Read-Report 'optimization-validation.json'
$hardeningValidation = if ($isWindows11) {
    Read-Report 'hardening-validation.json'
}
else {
    Read-Report 'desktop-policy.json'
}
$removed = Read-Report 'features-remove.json'
$netfx = if ($Variables.enable_netfx3) {
    Read-Report 'features-netfx.json'
}
else {
    @{validation = @{passed = $true }; status = 'not_requested' }
}
$software = Read-Report 'software.json'
$desktopPolicy = Read-Report 'desktop-policy.json'
if ($software.status -ne 'passed' -or $desktopPolicy.status -ne 'passed') {
    throw 'Software or desktop policy did not pass.'
}
if ($validation.status -ne 'passed' -or $offline.status -ne 'passed' -or $cleanup.status -ne 'success' -or -not $removed.validation.passed -or -not $netfx.validation.passed) {
    throw 'A required validation/cleanup report did not pass.'
}
if ($optimization.summary.failed -ne 0 -or $optimization.summary.pending -ne 0 -or $hardening.summary.failed -ne 0 -or $hardening.summary.pending -ne 0) {
    throw 'Optimization or hardening reports contain failures/pending changes.'
}
if ($optimizationValidation.summary.failed -ne 0 -or $optimizationValidation.summary.pending -ne 0 -or $hardeningValidation.summary.failed -ne 0 -or $hardeningValidation.summary.pending -ne 0) {
    throw 'Post-update optimization/hardening verification failed.'
}
$versionOutput = @(& packer version)
if ($LASTEXITCODE -ne 0) {
    throw 'Cannot read Packer version.'
}
$packerVersion = $versionOutput[0].Trim()
$plugins = @(& packer plugins installed)
if ($LASTEXITCODE -ne 0) {
    throw 'Cannot read installed plugin inventory.'
}

$end = [datetime]::UtcNow
$disk = Get-Item -LiteralPath $Vhdx
$hash = (Get-FileHash -LiteralPath $disk.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$id = $packerManifest.builds[-1].custom_data.image_id
@{
    schema_version       = 1;
    image_id             = $id;
    image_version        = $Variables.image_version
    windows_release      = $Variables.windows_release;
    edition              = $Variables.edition;
    installation_type    = 'Client';
    software_results     = $software;
    desktop_policy       = $desktopPolicy
    windows_build        = $validation.windows_build;
    packer_version       = $packerVersion
    plugin_constraints   = @{
        hyperv             = '1.1.5';
        'windows-features' = '1.0.0';
        'windows-optimize' = '1.0.0';
        'windows-harden'   = '0.1.0';
        'windows-cleanup'  = '0.1.0';
        'windows-update'   = '0.18.4'
    }
    plugin_inventory     = $plugins;
    plugin_provenance    = $(if (Test-Path '.validation/plugin-provenance.json') {
            Get-Content '.validation/plugin-provenance.json' -Raw | ConvertFrom-Json
        }
        else {
            @()
        })
    features             = $validation.features;
    installed_updates    = $validation.installed_updates;
    servicing_packages   = $validation.packages
    update_results       = @{
        history            = $validation.update_history;
        remaining_required = $validation.remaining_required_updates;
        approved_oob       = $Variables.approved_oob_packages
    }
    optimization_results = $optimization;
    hardening_results    = $hardening;
    cleanup_results      = $cleanup
    feature_results      = @{
        remove = $removed;
        netfx  = $netfx
    }
    started_at           = $StartedAt.ToUniversalTime().ToString('o');
    finished_at          = $end.ToString('o');
    duration_seconds     = ($end - $StartedAt.ToUniversalTime()).TotalSeconds
    vhdx_filename        = $disk.Name;
    vhdx_size_bytes      = $disk.Length;
    sha256               = $hash;
    iso_checksum         = $Variables.iso_checksum
    final_validation     = @{
        status       = 'passed';
        guest        = $validation;
        offline      = $offline;
        optimization = $optimizationValidation;
        hardening    = $hardeningValidation
    }
} | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $ReportDirectory "$id.manifest.json") -Encoding UTF8
"$hash  $($disk.Name)" | Set-Content -LiteralPath (Join-Path $ReportDirectory "$id.sha256") -Encoding ASCII
@{ schema_version = 1; history = $validation.update_history; packages = $validation.packages; remaining_required = $validation.remaining_required_updates } | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $ReportDirectory 'updates.json') -Encoding UTF8
