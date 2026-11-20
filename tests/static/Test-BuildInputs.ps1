<#
.SYNOPSIS
    Verifies that unsafe or unsupported build requests fail before invoking Packer.

.EXAMPLE
    ./tests/static/Test-BuildInputs.ps1

.NOTES
    Author: Lars Krogh project contributors
    Version: 1.0.0
#>

$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

function packer {
    throw 'Test failure: a rejected input reached Packer.'
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$directory = Join-Path $root '.validation'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$fixture = Join-Path $directory 'rejected-build-settings.json'
$base = @{
    iso_path              = 'C:/validation-only.iso';
    iso_checksum          = ('sha256:' + ('0' * 64));
    image_name            = 'Windows 11 Enterprise';
    switch_name           = 'inert';
    winrm_allowed_address = '192.0.2.10/32';
    image_version         = '0.test'
}
$cases = @(
    @{
        Version = '11-25H2';
        Key     = 'administrator_password';
        Value   = 'MustNeverBeAccepted';
        Error   = 'Do not put passwords'
    },
    @{
        Version = '10-22H2';
        Key     = 'acknowledge_windows10_eol';
        Value   = $false;
        Error   = 'Windows 10 is out of standard support'
    },
    @{
        Version = '11-24H2';
        Key     = 'edition';
        Value   = 'Professional';
        Error   = 'Windows 11 24H2 Pro is out of support'
    },
    @{
        Version = '11-25H2';
        Key     = 'edition';
        Value   = 'Datacenter';
        Error   = 'Invalid edition'
    },
    @{
        Version = '11-25H2';
        Key     = 'image_version';
        Value   = '../existing';
        Error   = 'Invalid edition'
    }
)
foreach ($case in $cases) {
    $settings = $base.Clone()
    $settings[$case.Key] = $case.Value
    $settings | ConvertTo-Json | Set-Content -LiteralPath $fixture -Encoding UTF8
    $caught = $false
    try {
        & (Join-Path $root 'scripts/Build.ps1') -Version $case.Version -SettingsPath $fixture
    }
    catch {
        if ($_.Exception.Message -notlike ($case.Error + '*')) {
            throw
        }
        $caught = $true
    }
    if (-not $caught) {
        throw 'Unsupported build request was accepted.'
    }
}
Remove-Item -LiteralPath $fixture
Write-Output "Passed $($cases.Count) build-input rejection tests. Packer was never invoked."
