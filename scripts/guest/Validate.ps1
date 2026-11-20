<#
.SYNOPSIS
    Collects final servicing, desktop security and image readiness evidence.

.EXAMPLE
    Get-Help scripts/guest/Validate.ps1 -Full

.NOTES
    Author: Lars Krogh
    Version: 1.0.0
#>

$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

$root = 'C:\ProgramData\ImageFactory'
$problems = [System.Collections.Generic.List[string]]::new()
$builds = @{ '10-22H2' = 19045; '11-24H2' = 26100; '11-25H2' = 26200; '11-26H2' = 26300 }
$os = Get-CimInstance Win32_OperatingSystem
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

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
$features = @(Get-WindowsOptionalFeature -Online | Select-Object FeatureName, State)
if ($env:FACTORY_NETFX3 -eq 'true' -and (Get-WindowsOptionalFeature -Online -FeatureName NetFx3).State -ne 'Enabled') {
    $problems.Add('.NET 3.5 is not enabled')
}
if (@($features | Where-Object { $_.FeatureName -like 'MicrosoftWindowsPowerShellV2*' -and $_.State -eq 'Enabled' }).Count) {
    $problems.Add('PowerShell 2 remains enabled')
}
if (@(Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Count) {
    $problems.Add('Firewall profile disabled')
}
$policyReport = Get-Content C:\ProgramData\ImageFactory\desktop-policy.json -Raw | ConvertFrom-Json
foreach ($policy in $policyReport.policies) {
    if ((Get-ItemPropertyValue -Path $policy.Path -Name $policy.Name) -ne $policy.Value) {
        $problems.Add("Desktop policy changed: $($policy.Name)")
    }
}
$softwareReport = Get-Content C:\ProgramData\ImageFactory\software-report.json -Raw | ConvertFrom-Json
foreach ($package in $softwareReport.packages) {
    if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($package.product_code)") -and -not (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$($package.product_code)")) {
        $problems.Add("Software registration lost: $($package.id)")
    }
}
$defender = Get-MpComputerStatus
if (-not $defender.AntivirusEnabled -or -not $defender.RealTimeProtectionEnabled) {
    $problems.Add('Defender protection is disabled')
}
$provisioned = @(Get-AppxProvisionedPackage -Online)
foreach ($app in Get-AppxPackage -AllUsers | Where-Object { -not $_.IsFramework -and -not $_.NonRemovable }) {
    if (-not @($provisioned | Where-Object { $_.DisplayName -eq $app.Name -and [version]$_.Version -eq [version]$app.Version }).Count) {
        $problems.Add("AppX package may block Sysprep: $($app.Name)")
    }
}
if ($PSVersionTable.PSVersion -lt [version]'5.1' -or -not [Environment]::Is64BitProcess) {
    $problems.Add('Native PowerShell 5.1 unavailable')
}
$reboot = @()
foreach ($key in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')) {
    if (Test-Path $key) {
        $reboot += $key
    }
}
$session = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
if ($session.PSObject.Properties['PendingFileRenameOperations'] -and $session.PendingFileRenameOperations) {
    $reboot += 'PendingFileRenameOperations'
}
if (Test-Path C:\Windows\WinSxS\pending.xml) {
    $reboot += 'pending.xml'
}
$packages = @(Get-WindowsPackage -Online)
if (@($packages | Where-Object PackageState -Match 'Pending').Count) {
    $reboot += 'Pending DISM package'
}
if ($reboot.Count) {
    $problems.Add('Pending restart remains')
}
if ((New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired) {
    $problems.Add('Windows Update requires reboot')
}
if ((New-Object -ComObject Microsoft.Update.Installer).IsBusy) {
    $problems.Add('Windows Update installer is busy')
}
$wu = New-Object -ComObject Microsoft.Update.Session
$searcher = $wu.CreateUpdateSearcher()
$remaining = $searcher.Search($env:FACTORY_SEARCH)
if ($remaining.ResultCode -ne 2) {
    throw "Final update search did not succeed: $($remaining.ResultCode)"
}
$required = @($remaining.Updates | Where-Object { $_.Title -notmatch 'Preview' })
if ($required.Count) {
    $problems.Add('Required updates remain applicable')
}
$historyCount = $searcher.GetTotalHistoryCount()
$history = @()
if ($historyCount -gt 0) {
    $history = @($searcher.QueryHistory(0, $historyCount) | Select-Object Title, Date, Operation, ResultCode, HResult)
}
$approved = @(Get-Content "$root\oob.json" -Raw | ConvertFrom-Json)
$hotfixes = @(Get-HotFix | Select-Object HotFixID, Description, InstalledOn)
foreach ($p in $approved) {
    if (-not @($hotfixes | Where-Object HotFixID -eq $p.kb).Count -and -not @($packages | Where-Object { $_.PackageName -match [regex]::Escape($p.kb) -and $_.PackageState -in 'Installed', 'Superseded' }).Count) {
        $problems.Add("Approved package lacks installed/superseded evidence: $($p.kb)")
    }
}
if ((Get-Service WinRM).Status -ne 'Running') {
    $problems.Add('WinRM unavailable')
}
if (-not (Confirm-SecureBootUEFI)) {
    $problems.Add('Secure Boot disabled')
}
if ((Get-Disk -Number 0).PartitionStyle -ne 'GPT') {
    $problems.Add('System disk is not GPT')
}
if ((Get-BitLockerVolume -MountPoint C:).VolumeStatus -ne 'FullyDecrypted') {
    $problems.Add('Capture disk must be unencrypted; build TPM state is not portable.')
}
$health = Repair-WindowsImage -Online -ScanHealth
if ($health.ImageHealthState -ne 'Healthy') {
    $problems.Add('Component store is not healthy')
}
@{
    schema_version = 1; status = $(if ($problems.Count) { 'failed' } else { 'passed' })
    checked_at = [DateTime]::UtcNow.ToString('o'); errors = @($problems.ToArray())
    windows_release = $env:FACTORY_RELEASE; edition = $cv.EditionID; architecture = $os.OSArchitecture; display_version = $cv.DisplayVersion; installation_type = $cv.InstallationType
    windows_build = "$($os.Version).$($cv.UBR)"; features = $features
    installed_updates = $hotfixes; packages = @($packages | Select-Object PackageName, PackageState)
    update_history = $history; remaining_required_updates = @($required | ForEach-Object Title)
    pending_reboot = $reboot; component_health = [string]$health.ImageHealthState
} | ConvertTo-Json -Depth 12 | Set-Content "$root\validation.json" -Encoding UTF8
if ($problems.Count) { throw ($problems -join '; ') }
