<#
.SYNOPSIS
    Exercises release evidence acceptance and rejection with inert fixtures.

.EXAMPLE
    Get-Help tests/static/Test-Manifest.ps1 -Full

.NOTES
    Author: Lars Krogh
    Version: 1.0.0
#>


$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

function Write-Fixture(
    [string]$Name,
    [object]$Value) {
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $dir $Name) -Encoding UTF8
}

Set-Location (Join-Path $PSScriptRoot '..\..')

$dir = Join-Path $PWD ('.validation\manifest-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Write-Fixture 'validation.json' @{
    status                     = 'passed';
    windows_build              = '10.0.26200.1';
    features                   = @(@{
            FeatureName = 'NetFx3';
            State       = 'Enabled'
        });
    installed_updates          = @();
    packages                   = @();
    update_history             = @();
    remaining_required_updates = @()
}
Write-Fixture 'offline-validation.json' @{
    status      = 'passed';
    image_state = 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE'
}
Write-Fixture 'packer-manifest.json' @{
    builds = @(@{
            custom_data = @{
                image_id = 'test-image-1'
            }
        }
    )
}
Write-Fixture 'software.json' @{
    status = 'passed'
}
Write-Fixture 'desktop-policy.json' @{
    status  = 'passed';
    summary = @{
        failed  = 0;
        pending = 0
    }
}
Write-Fixture 'cleanup.json' @{
    status = 'success'
}
Write-Fixture 'optimization.json' @{
    summary = @{
        failed  = 0;
        pending = 0
    }
}
Write-Fixture 'hardening.json' @{
    summary = @{
        failed  = 0;
        pending = 0
    }
}
Write-Fixture 'optimization-validation.json' @{
    summary = @{
        failed  = 0;
        pending = 0
    }
}
Write-Fixture 'hardening-validation.json' @{
    summary = @{
        failed  = 0;
        pending = 0
    }
}
foreach ($name in 'features-remove.json', 'features-netfx.json') {
    Write-Fixture $name @{
        validation = @{passed = $true }
    }
}
$disk = Join-Path $dir 'inert-fixture.vhdx'
'Inert checksum fixture; not a virtual disk.' | Set-Content -LiteralPath $disk
$vars = @{
    image_version         = '1';
    windows_release       = '11-25H2';
    edition               = 'Enterprise';
    enable_netfx3         = $true;
    approved_oob_packages = @();
    iso_checksum          = ('sha256:' + ('a' * 64))
}
& ./scripts/New-Manifest.ps1 -Variables $vars -ReportDirectory $dir -Vhdx $disk -StartedAt ([DateTime]::UtcNow.AddSeconds(-1))
$manifest = Get-Content (Join-Path $dir 'test-image-1.manifest.json') -Raw | ConvertFrom-Json
if ($manifest.sha256 -ne (Get-FileHash $disk).Hash.ToLowerInvariant() -or $manifest.final_validation.status -ne 'passed' -or $manifest.duration_seconds -lt 0) {
    throw 'Manifest output/checksum contract failed.'
}
Remove-Item -LiteralPath (Join-Path $dir 'test-image-1.manifest.json')
Write-Fixture 'offline-validation.json' @{status = 'failed' }
$rejected = $false
try {
    & ./scripts/New-Manifest.ps1 -Variables $vars -ReportDirectory $dir -Vhdx $disk -StartedAt ([DateTime]::UtcNow)
}
catch {
    $rejected = $true
}
if (-not $rejected -or (Test-Path (Join-Path $dir 'test-image-1.manifest.json'))) {
    throw 'Failed offline validation must not issue a release manifest.'
}
Write-Fixture 'offline-validation.json' @{status = 'passed' }
Write-Fixture 'hardening-validation.json' @{
    summary = @{
        failed  = 0;
        pending = 1
    }
}
$rejected = $false
try {
    & ./scripts/New-Manifest.ps1 -Variables $vars -ReportDirectory $dir -Vhdx $disk -StartedAt ([DateTime]::UtcNow)
}
catch {
    $rejected = $true
}
if (-not $rejected -or (Test-Path (Join-Path $dir 'test-image-1.manifest.json'))) {
    throw 'Pending post-update hardening must block release.'
}
Write-Fixture 'hardening-validation.json' @{
    summary = @{
        failed  = 0;
        pending = 0
    }
}
$vars.windows_release = '10-22H2'
$vars.enable_netfx3 = $false
foreach ($name in 'hardening.json', 'hardening-validation.json', 'features-netfx.json') {
    Remove-Item -LiteralPath (Join-Path $dir $name)
}
& ./scripts/New-Manifest.ps1 -Variables $vars -ReportDirectory $dir -Vhdx $disk -StartedAt ([DateTime]::UtcNow)
$manifest = Get-Content (Join-Path $dir 'test-image-1.manifest.json') -Raw | ConvertFrom-Json
if ($manifest.hardening_results.baseline_compliance -ne $false -or $manifest.feature_results.netfx.status -ne 'not_requested') {
    throw 'Windows 10 must disclose its limited baseline and skipped NetFx3.'
}
Remove-Item -LiteralPath (Join-Path $dir 'test-image-1.manifest.json')
Write-Fixture 'software.json' @{status = 'failed' }
$rejected = $false
try {
    & ./scripts/New-Manifest.ps1 -Variables $vars -ReportDirectory $dir -Vhdx $disk -StartedAt ([DateTime]::UtcNow)
}
catch {
    $rejected = $true
}
if (-not $rejected -or (Test-Path (Join-Path $dir 'test-image-1.manifest.json'))) {
    throw 'Software failure must block release.'
}
Write-Output 'Passed manifest checksum, Windows 10 compatibility and failed-release rejection checks.'
