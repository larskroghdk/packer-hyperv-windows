<#
.SYNOPSIS
    Exercises software trust, installer outcomes and registration gates with isolated mocks.

.EXAMPLE
    ./tests/static/Test-Software.ps1

.NOTES
    Author: Lars Krogh project contributors
    Version: 1.0.0
#>

$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

Import-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security

$scenario = @{}
function Get-Content {
    ConvertTo-Json -InputObject @(
        @{
            id           = 'runtime';
            kind         = $scenario.kind;
            sha256       = ('a' * 64);
            product_code = '{00000000-0000-0000-0000-000000000001}'
        })
}

function Get-FileHash {
    @{Hash = $scenario.hash }
}

function Get-AuthenticodeSignature {
    @{
        Status            = $scenario.signature;
        SignerCertificate = @{
            Subject = $scenario.publisher
        }
    }
}

function Start-Process {
    param(
        $FilePath,
        $ArgumentList,
        [switch]$Wait,
        [switch]$PassThru,
        $WindowStyle
    )
    $scenario.launched = $true
    if ($scenario.kind -eq 'vcredist' -and $ArgumentList -ne '/install /quiet /norestart') {
        throw 'VC++ silent arguments changed.'
    }
    @{ExitCode = $scenario.exit }
}

function Test-Path {
    $scenario.registered
}

function Set-Content {
    param(
        $Path,
        $Encoding,
        [Parameter(ValueFromPipeline)]$Value
    )
    process {
        $scenario.report = $Value | ConvertFrom-Json
    }
}

$cases = @(
    @{
        Name       = 'MSI succeeds';
        Kind       = 'msi';
        Hash       = ('a' * 64);
        Signature  = 'Valid';
        Publisher  = 'O=Microsoft Corporation';
        Exit       = 0;
        Registered = $true;
        Expected   = $true
    },
    @{
        Name       = 'MSI reboot required';
        Kind       = 'msi';
        Hash       = ('a' * 64);
        Signature  = 'Valid';
        Publisher  = 'O=Microsoft Corporation';
        Exit       = 3010;
        Registered = $true;
        Expected   = $true
    },
    @{
        Name       = 'VC runtime succeeds';
        Kind       = 'vcredist';
        Hash       = ('a' * 64);
        Signature  = 'Valid';
        Publisher  = 'O=Microsoft Corporation';
        Exit       = 0;
        Registered = $true;
        Expected   = $true
    },
    @{
        Name       = 'Hash mismatch';
        Kind       = 'msi';
        Hash       = ('b' * 64);
        Signature  = 'Valid';
        Publisher  = 'O=Microsoft Corporation';
        Exit       = 0;
        Registered = $true;
        Expected   = $false
    },
    @{
        Name       = 'Unsigned MSI';
        Kind       = 'msi';
        Hash       = ('a' * 64);
        Signature  = 'NotSigned';
        Publisher  = 'O=Example';
        Exit       = 0;
        Registered = $true;
        Expected   = $false
    },
    @{
        Name       = 'Wrong VC publisher';
        Kind       = 'vcredist';
        Hash       = ('a' * 64);
        Signature  = 'Valid';
        Publisher  = 'O=Example';
        Exit       = 0;
        Registered = $true;
        Expected   = $false
    },
    @{
        Name       = 'Installer failed';
        Kind       = 'msi';
        Hash       = ('a' * 64);
        Signature  = 'Valid';
        Publisher  = 'O=Microsoft Corporation';
        Exit       = 1603;
        Registered = $true;
        Expected   = $false
    },
    @{
        Name       = 'Registration absent';
        Kind       = 'msi';
        Hash       = ('a' * 64);
        Signature  = 'Valid';
        Publisher  = 'O=Microsoft Corporation';
        Exit       = 0;
        Registered = $false;
        Expected   = $false
    }
)
foreach ($case in $cases) {
    $scenario = $case.Clone()
    $scenario.launched = $false
    $scenario.report = $null
    $passed = $false
    try {
        & (Join-Path $PSScriptRoot '../../scripts/guest/Install-Software.ps1');
        $passed = $true
    }
    catch {
        if ($case.Expected) {
            throw
        }
    }
    if ($passed -ne $case.Expected) {
        throw "Software gate produced the wrong result: $($case.Name)"
    }
    if ($case.Expected -and $scenario.report.status -ne 'passed') {
        throw 'Software success report missing.'
    }
    if ($case.Name -in 'Hash mismatch', 'Unsigned MSI', 'Wrong VC publisher' -and $scenario.launched) {
        throw 'Untrusted software reached the installer.'
    }
}
Write-Output "Passed $($cases.Count) isolated software trust/install gate tests. No installers ran."
