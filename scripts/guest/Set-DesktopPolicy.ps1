<#
.SYNOPSIS
    Configures supported desktop policies while retaining servicing and Store dependencies.

.EXAMPLE
    & C:\Build\Set-DesktopPolicy.ps1

.NOTES
    Author: Lars Krogh
    Version: 1.0.0
#>

$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

$policies = @(
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent';
        Name = 'DisableWindowsConsumerFeatures'; Value = 1
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';
        Name = 'AllowTelemetry'; Value = 1
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE';
        Name = 'DisablePrivacyExperience'; Value = 1
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent';
        Name = 'DisableWindowsSpotlightWindowsWelcomeExperience'; Value = 1
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore';
        Name = 'AutoDownload'; Value = 2
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';
        Name = 'TargetReleaseVersion'; Value = 1
    }
)
foreach ($policy in $policies) {
    New-Item -Path $policy.Path -Force | Out-Null
    New-ItemProperty -Path $policy.Path -Name $policy.Name -Value $policy.Value -PropertyType DWord -Force | Out-Null
    if ((Get-ItemPropertyValue -Path $policy.Path -Name $policy.Name) -ne $policy.Value) {
        throw "Policy read-back failed: $($policy.Name)"
    }
}
$update = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$product = if ($env:FACTORY_RELEASE -like '10-*') { 'Windows 10' } else { 'Windows 11' }
New-ItemProperty $update -Name ProductVersion -Value $product -PropertyType String -Force | Out-Null
New-ItemProperty $update -Name TargetReleaseVersionInfo -Value ($env:FACTORY_RELEASE -split '-')[1] -PropertyType String -Force | Out-Null
Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True
Set-MpPreference -DisableRealtimeMonitoring $false
if (@(Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Count) {
    throw 'Firewall protection could not be enabled.'
}
if (-not (Get-MpComputerStatus).RealTimeProtectionEnabled) {
    throw 'Defender real-time protection is unavailable.'
}
$removedApps = @()
if ($env:FACTORY_REMOVE_CONSUMER -eq 'true') {
    $approvedNames = @('Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.XboxApp')
    foreach ($app in Get-AppxProvisionedPackage -Online | Where-Object DisplayName -in $approvedNames) {
        Remove-AppxProvisionedPackage -Online -PackageName $app.PackageName | Out-Null
        $removedApps += $app.DisplayName
    }
}
@{
    status = 'passed'; removed_consumer_apps = $removedApps; summary = @{failed = 0; pending = 0 }; policies = $policies
    baseline_compliance = $false
    limitations = @('Consumer-feature policy is edition dependent; Pro may ignore it.', 'Windows 10 has no implemented plugin security baseline.', 'Store automatic updates are suspended for capture; deployment must restore its update policy.')
} | ConvertTo-Json -Depth 8 | Set-Content C:\ProgramData\ImageFactory\desktop-policy.json -Encoding UTF8
