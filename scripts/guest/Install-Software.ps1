<#
.SYNOPSIS
    Installs approved, hashed machine-wide MSI packages without network downloads.

.EXAMPLE
    & C:\Build\Install-Software.ps1

.NOTES
    Author: Lars Krogh
    Version: 1.0.0
#>

$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

$packages = @(Get-Content C:\ProgramData\ImageFactory\software.json -Raw | ConvertFrom-Json)
$results = @()

foreach ($package in $packages) {
    if ($package.id -notmatch '^[A-Za-z0-9_-]+$' -or $package.product_code -notmatch '^\{[A-Fa-f0-9-]{36}\}$') {
        throw 'Invalid approved software identity.'
    }
    $extension = if ($package.kind -eq 'msi') {
        'msi'
    }
    elseif ($package.kind -eq 'vcredist') {
        'exe'
    }
    else {
        throw 'Unsupported software type.'
    }
    $path = "C:\ProgramData\PackerCleanup\Staging\$($package.id).$extension"
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $package.sha256) {
        throw "Software hash mismatch: $($package.id)"
    }
    if ((Get-AuthenticodeSignature -LiteralPath $path).Status -ne 'Valid') {
        throw "Invalid software publisher signature: $($package.id)"
    }
    if ($package.kind -eq 'msi') {
        $process = Start-Process -FilePath msiexec.exe -ArgumentList @('/i', $path, '/qn', '/norestart') -Wait -PassThru -WindowStyle Hidden
    }
    else {
        if ((Get-AuthenticodeSignature -LiteralPath $path).SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
            throw 'VC++ runtime must be signed by Microsoft.'
        }
        $process = Start-Process -FilePath $path -ArgumentList '/install /quiet /norestart' -Wait -PassThru -WindowStyle Hidden
    }
    if ($process.ExitCode -notin 0, 3010) {
        throw "MSI failed: $($package.id), exit $($process.ExitCode)"
    }
    $keys = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($package.product_code)", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$($package.product_code)")
    if (-not @($keys | Where-Object { Test-Path -LiteralPath $_ }).Count) {
        throw "MSI product registration missing: $($package.id)"
    }
    $results += @{id = $package.id; sha256 = $package.sha256; product_code = $package.product_code; exit_code = $process.ExitCode }
}
@{status = 'passed'; packages = $results; implementation = 'approved-msi-bridge'; software_plugin_available = $false } | ConvertTo-Json -Depth 8 | Set-Content C:\ProgramData\ImageFactory\software-report.json -Encoding UTF8
