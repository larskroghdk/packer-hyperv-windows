<#
.SYNOPSIS
    Validates installed desktop identity and security hardware before provisioning.

.EXAMPLE
    Get-Help scripts/guest/Prepare.ps1 -Full

.NOTES
    Author: Lars Krogh
    Version: 1.0.0
#>

$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

$builds = @{ '10-22H2' = 19045; '11-24H2' = 26100; '11-25H2' = 26200; '11-26H2' = 26300 }
$os = Get-CimInstance Win32_OperatingSystem
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

if ($env:FACTORY_RELEASE -eq '10-22H2' -and $env:FACTORY_EOL -ne 'true') {
    throw 'Explicit Windows 10 end-of-support acknowledgement is required.'
}
if ($env:FACTORY_RELEASE -eq '11-24H2' -and $env:FACTORY_EDITION -eq 'Professional' -and [DateTime]::UtcNow -gt [DateTime]'2026-10-14') {
    throw 'Windows 11 24H2 Pro is out of servicing.'
}
if ($os.ProductType -ne 1 -or [int]$os.BuildNumber -ne $builds[$env:FACTORY_RELEASE] -or $cv.InstallationType -ne 'Client') {
    throw 'Installed OS differs from requested Windows desktop release.'
}
if ($cv.EditionID -ne $env:FACTORY_EDITION -or $cv.DisplayVersion -ne ($env:FACTORY_RELEASE -split '-')[1]) {
    throw 'Installed edition or display version differs from request.'
}
if (-not [Environment]::Is64BitOperatingSystem -or -not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
    throw 'Native x64 Windows is required.'
}
if ($env:FACTORY_RELEASE -like '11-*') {
    $tpm = Get-Tpm
    if (-not $tpm.TpmPresent -or -not $tpm.TpmReady) {
        throw 'Windows 11 requires a ready virtual TPM.'
    }
    $spec = (Get-CimInstance -Namespace root/CIMV2/Security/MicrosoftTpm -ClassName Win32_Tpm).SpecVersion
    if ($spec -notmatch '(^|,\s*)2\.0') {
        throw 'TPM 2.0 is required.'
    }
}
if ($PSVersionTable.PSVersion.Major -ne 5 -or -not [Environment]::Is64BitProcess) {
    throw 'Native Windows PowerShell 5.1 is required.'
}
if ((Get-Content 'C:\ProgramData\ImageFactory\bootstrap-status.json' -Raw | ConvertFrom-Json).bootstrap -ne 'passed') {
    throw 'Bootstrap did not complete.'
}
if (-not (Confirm-SecureBootUEFI)) {
    throw 'Secure Boot is not enabled.'
}
if ((Get-Disk -Number 0).PartitionStyle -ne 'GPT') {
    throw 'System disk must be GPT.'
}
if ($env:FACTORY_NETFX3 -eq 'true' -and -not (Test-Path -LiteralPath $env:FACTORY_NETFX_SOURCE)) {
    throw 'Validated feature payload is missing.'
}
