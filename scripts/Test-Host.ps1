<#
.SYNOPSIS
    Checks host prerequisites and approved installation media before VM creation.

.EXAMPLE
    Get-Help scripts/Test-Host.ps1 -Full

.NOTES
    Author: Lars Krogh
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [hashtable]$Variables
)

$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Live builds require an elevated dedicated Windows Hyper-V host.'
}
foreach ($cmd in 'Get-VM', 'Get-VMSwitch', 'Mount-DiskImage', 'Get-WindowsImage', 'Mount-VHD', 'Enable-VMTPM', 'Set-VMKeyProtector') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Missing prerequisite command: $cmd"
    }
}
if (-not (Get-Command oscdimg.exe -ErrorAction SilentlyContinue)) {
    throw 'Install Windows ADK Deployment Tools and add oscdimg.exe to PATH.'
}
if ((Get-Service vmms).Status -ne 'Running') {
    throw 'Hyper-V Virtual Machine Management service is not running.'
}
if (-not (Get-CimInstance Win32_ComputerSystem).HypervisorPresent) {
    throw 'The Hyper-V hypervisor is not active; check host/nested virtualization support.'
}
$memoryMB = if ($Variables.ContainsKey('memory_mb')) {
    [double]$Variables.memory_mb
}
else {
    4096
}
if ((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024 -lt $memoryMB + 1024) {
    throw 'Insufficient free physical memory for the guest plus host overhead.'
}
Get-VMSwitch -Name $Variables.switch_name -ErrorAction Stop | Out-Null
if ($Variables.iso_checksum -notmatch '^sha256:([a-fA-F0-9]{64})$') {
    throw 'Approved ISO SHA256 is required.'
}
$expectedHash = $Matches[1]
$iso = Get-Item -LiteralPath $Variables.iso_path
if ($iso.Extension -ne '.iso' -or -not [IO.Path]::IsPathRooted($iso.FullName)) {
    throw 'Use an absolute local ISO path.'
}
if ((Get-FileHash -LiteralPath $iso.FullName -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'ISO checksum mismatch.'
}

$disk = Get-DiskImage -ImagePath $iso.FullName -ErrorAction SilentlyContinue
$wasAttached = $disk -and $disk.Attached

try {
    if (-not $wasAttached) {
        Mount-DiskImage -ImagePath $iso.FullName -PassThru | Out-Null
    }
    $volumes = @(Get-DiskImage -ImagePath $iso.FullName | Get-Volume | Where-Object DriveLetter)
    if ($volumes.Count -ne 1) {
        throw 'Cannot determine installation ISO volume.'
    }
    $drive = "$($volumes[0].DriveLetter):"
    $imagePath = Join-Path $drive 'sources\install.wim'
    if (-not (Test-Path $imagePath)) {
        $imagePath = Join-Path $drive 'sources\install.esd'
    }
    if (-not (Test-Path $imagePath)) {
        throw 'ISO has no supported install.wim/install.esd.'
    }
    $images = @(Get-WindowsImage -ImagePath $imagePath | Where-Object ImageName -eq $Variables.image_name)
    if ($images.Count -ne 1) {
        throw 'Exact image_name must identify one image; inspect media with Get-WindowsImage.'
    }
    $image = Get-WindowsImage -ImagePath $imagePath -Index $images[0].ImageIndex
    $builds = @{
        '10-22H2' = 19045;
        '11-24H2' = 26100;
        '11-25H2' = 26200;
        '11-26H2' = 26300
    }
    $mediaBuild = ([version]$image.Version).Build
    if ($mediaBuild -ne $builds[$Variables.windows_release]) {
        $enablement = @{
            '10-22H2' = @{
                Base = 19041;
                KB   = 'KB5015684'
            };
            '11-25H2' = @{
                Base = 26100;
                KB   = 'KB5054156'
            }
        }
        if (-not $enablement.ContainsKey($Variables.windows_release) -or $mediaBuild -ne $enablement[$Variables.windows_release].Base) {
            throw 'ISO image build differs from requested release.'
        }
        $mountPath = Join-Path ([IO.Path]::GetTempPath()) ('packer-media-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $mountPath | Out-Null
        $mounted = $false
        try {
            Mount-WindowsImage -ImagePath $imagePath -Index $image.ImageIndex -Path $mountPath -ReadOnly -CheckIntegrity | Out-Null
            $mounted = $true
            $kb = $enablement[$Variables.windows_release].KB
            $packages = @(Get-WindowsPackage -Path $mountPath | Where-Object { $_.PackageName -match $kb -and $_.PackageState -in 'Installed', 'Superseded' })
            if (-not $packages.Count) {
                throw "Media does not prove the required enablement package: $kb"
            }
        }
        finally {
            if ($mounted) {
                Dismount-WindowsImage -Path $mountPath -Discard | Out-Null
            }
            Remove-Item -LiteralPath $mountPath -ErrorAction SilentlyContinue
        }
    }
    if ($image.EditionId -ne $Variables.edition) {
        throw 'ISO edition differs from requested edition.'
    }
    if ($image.InstallationType -ne 'Client' -or $image.Architecture -notin 9, 'amd64', 'x64') {
        throw 'ISO must contain an x64 Client installation.'
    }
    if (@($image.Languages | Where-Object { $_ -match '^en-US' }).Count -eq 0) {
        throw 'Use English Microsoft media; regional settings remain configurable.'
    }
    if (-not (Test-Path "$drive\efi\microsoft\boot\efisys.bin")) {
        throw 'Media lacks Windows UEFI boot image.'
    }
    if ($Variables.enable_netfx3 -and @(Get-ChildItem "$drive\sources\sxs" -File -Filter '*netfx3*').Count -eq 0) {
        throw '.NET 3.5 installation payload is missing.'
    }
}
finally {
    if (-not $wasAttached) {
        Dismount-DiskImage -ImagePath $iso.FullName | Out-Null
    }
}
$seen = @{}
if ($Variables.ContainsKey('approved_oob_packages')) {
    foreach ($package in $Variables.approved_oob_packages) {
        if ($package.kb -notmatch '^KB[0-9]+$' -or $seen.ContainsKey($package.kb)) {
            throw 'Offline packages require distinct KB identities.'
        }
        $seen[$package.kb] = $true
        if ([IO.Path]::GetExtension($package.path) -ne '.msu' -or (Get-FileHash -LiteralPath $package.path -Algorithm SHA256).Hash -ne $package.sha256) {
            throw "Approved MSU checksum mismatch: $($package.kb)"
        }
    }
}
Write-Output 'Host, switch, approved ISO, image edition/type, UEFI and feature payload validated.'
if ($Variables.ContainsKey('software_packages')) {
    $softwareIds = @{}
    foreach ($package in $Variables.software_packages) {
        if ($package.id -notmatch '^[A-Za-z0-9_-]+$' -or $softwareIds.ContainsKey($package.id)) {
            throw 'Software IDs must be safe and unique.'
        }
        $softwareIds[$package.id] = $true
        $kind = if ($package.PSObject.Properties['kind']) {
            $package.kind
        }
        else {
            'msi'
        }
        $extension = if ($kind -eq 'msi') {
            '.msi'
        }
        elseif ($kind -eq 'vcredist') {
            '.exe'
        }
        else {
            throw 'Unsupported package kind.'
        }
        if ([IO.Path]::GetExtension($package.path) -ne $extension -or (Get-FileHash -LiteralPath $package.path).Hash -ne $package.sha256) {
            throw 'Approved software extension/hash mismatch.'
        }
        if ((Get-AuthenticodeSignature -LiteralPath $package.path).Status -ne 'Valid') {
            throw 'Approved software signature is not valid.'
        }
    }
}
