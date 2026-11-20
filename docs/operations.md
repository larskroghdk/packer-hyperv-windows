# 🛠️ Operations

## 💿 Prerequisites and media

Use a dedicated elevated Windows Hyper-V host with Gen 2, MicrosoftWindows Secure Boot, supported Windows 11 CPU, virtualization, virtual TPM commands and Windows ADK Deployment Tools (`oscdimg.exe` on PATH). Provide at least two vCPUs, 4096 MB fixed RAM and 65536 MB disk (81920 default), plus host and scratch capacity. The wrapper checks cmdlets, vmms, hypervisor, RAM, switch and media; CPU eligibility and nested virtualization require operator qualification. No existing switch or VM is modified. Windows 11 uses the actual Hyper-V `enable_tpm` option, without hardware bypasses.

Use official English x64 volume-license media and independently approved SHA256. Inspect exact names with `Get-WindowsImage -ImagePath X:/sources/install.wim` (ESD where DISM supports it). Host checks checksum, exact image name, build, edition ID, Client type, x64, English UI and UEFI payload. Reviewed enablement media with WIM base 19041 or 26100 requires installed/superseded KB5015684 (10 22H2) or KB5054156 (11 25H2) in a read-only mounted image. Ambiguous media, split WIM and unsupported ESD mounts fail closed. Installed build, DisplayVersion and edition are checked before and after servicing. Same-media SxS is required only for optional NetFx3.

Public Microsoft volume client setup keys select the requested edition without a product-key prompt. They confer no license entitlement. No activation/ESU enrollment or private MAK/KMS host key is included. Licensed consumers provide their own activation. Retail/OEM/evaluation channels require separate Windows SIM qualification and are not promised.

## ▶️ Configuration and execution

Copy [settings](../config/settings.example.json) or a release/edition [example](../examples/README.md) outside the repository and replace all placeholders. Required: iso_path, iso_checksum (`sha256:<64 hex>`), exact image_name, existing switch_name, host IP/CIDR winrm_allowed_address, image_version. Edition is Professional (Pro), Enterprise or Education; default Enterprise. Select Version as 10-22H2, 11-24H2, 11-25H2 or 11-26H2. The wrapper selects the release; settings cannot override it. [Variables](../variables.pkr.hcl) documents other inputs.

Inject PKR_VAR_administrator_password from a secret manager: unique, at least 16 characters with upper/lowercase, digit and symbol. Never place it in settings or command arguments.

```powershell
./scripts/Install-LocalPlugins.ps1
$env:PACKER_PLUGIN_PATH = "$pwd/.validation/plugins"
./tests/static/Test-Project.ps1
./scripts/Build.ps1 -Version 11-26H2 -SettingsPath C:/Private/win11-26h2.json
./tests/live/Test-Build.ps1 -Version 11-26H2 -SettingsPath C:/Private/win11-26h2.json -AuthorizeLiveBuild
```

The wrapper without -Build validates configuration only. Live builds require -Build or the live test switch. Existing VMs/output are never replaced. locale, keyboard_layout and time_zone configure region/input/timezone while UI remains en-US. Windows 10 requires acknowledge_windows10_eol=true; this accepts legacy support risk without establishing ESU entitlement or patch completeness. Win11 24H2 Pro is expired and rejected for live use. The Windows 11 hardening plugin independently enforces lifecycle. Review these dates when support policies change.

## 🧩 Features, software and desktop behavior

The shared order is features, approved software, restart, optimization, compatible hardening, desktop policy, approved offline updates, online updates/restarts, verification, cleanup and final evidence. NetFx3 is opt-in via enable_netfx3=true and same-media source/limit_access. PowerShell 2 is disabled when available; PowerShell 5.1/.NET 4 remain.

software_packages is an ordered array of objects: id, path, sha256, product_code, kind. kind defaults to msi. Supply a signed machine-wide PowerShell 7 x64 MSI and any additional approved MSI packages. kind=vcredist accepts Microsoft-signed VC++ Redistributable EXEs using fixed `/install /quiet /norestart`. Supply the version-specific uninstall registration GUID (MSI ProductCode or VC++ bundle registration). Both registry views are checked. No arbitrary arguments, URLs or package managers. Host and guest verify hashes/signatures; exits 0/3010 are accepted, followed by a controlled restart. Native PowerShell 5.1 continues provisioning. Empty software arrays explicitly request no software; installers/hashes are operator-owned, not automatically downloaded.

remove_consumer_apps=true removes only provisioned BingNews, BingWeather, GetHelp, Getstarted and XboxApp. No wildcard AppX removal, dependency deletion or default-profile hive manipulation. Installed per-user apps without matching provisioned packages block release rather than being forcibly removed. Store frameworks, Edge/WebView2, Defender, firewall and servicing dependencies remain.

Desktop machine policies govern new users: required diagnostic data, consumer suggestions where supported, privacy/welcome screens, Store auto-update hold during capture, and Windows Update target product/release. Pro may ignore enterprise-only consumer policies. Deployment must review retained policies and restore Store AutoDownload policy after capture. Store itself remains functional. Default profiles are not copied from an interactive session.

Windows 11 uses hardening auto/non_domain_joined/compatibility with explicit deferrals. Windows 10 has no plugin baseline and receives limited local policy only. Full Microsoft baseline compliance is not claimed. Defender realtime protection, all firewall profiles, Secure Boot and TPM readiness are validated. Optimization defaults recommended; other profiles need desktop qualification.

## 📦 Updates and release

The pinned rgl updater installs applicable nonhidden software updates excluding Preview titles. It does not change WSUS/source or automatically enroll Microsoft Update. Retry limits bound failures; default update_timeout is six hours. The extra restart drains servicing. Final applicability scan uses the same filter: no applicable updates does not establish Windows 10 ESU entitlement or source coverage.

approved_oob_packages is an ordered array of path, sha256 and kb, including every prerequisite. The inherited SYSTEM WUSA bridge hash-checks packages, accepts supported outcomes and uses per-package restart boundaries. No plugin report_path or offline update interface is invented. Final WUA history/search, package inventory, DISM health, absence of pending restart and plugin dry-run results gate release.

Temporary HTTPS WinRM uses NTLM with a unique self-signed certificate and scoped firewall rule. Packer skips PKI validation, requiring an isolated trusted DHCP build network. No autologon. Setup enables built-in Administrator for Packer and creates temporary PackerBuild to satisfy desktop OOBE. Finalization deletes PackerBuild, invalidates Administrator password, removes listener/certificate/rule and runs Sysprep. No guest provisioner follows staging of the finalizer.

Answer media necessarily contains the temporary password. The wrapper uses ACL-protected .build/<id> TEMP and removes only the verified path. Restrict runner/cache/workspace access, encrypt storage and rotate the per-build secret after crashes. Do not enable PACKER_LOG or publish answer media, caches or VM working folders. Reports contain paths/policy/software evidence and need access control. Cached answer files are explicitly removed.

Builder shutdown waits for generalize/oobe/shutdown; no fallback shutdown disguises failure. Host checks the detached standalone VHDX read-only, inspects generalized OOBE state and known artifact absence, then issues manifest and SHA256. Direct packer build omits these host release gates and is not a validated release. No dedicated WinRE partition is created; qualify recovery layout separately if required.

Deploy a COPY of the canonical disk with a fresh Gen 2 VM, Secure Boot/vTPM and consumer unattend for identity, accounts, activation, network and management. Never boot the canonical disk. Capture is unencrypted: vTPM state is not exported with standalone VHDX, so consumers create fresh TPM state and must not bind build secrets to it. A disposable deployment smoke test is required for production qualification.

## 🔎 CI, validation and troubleshooting

Static tests parse PowerShell/XML, check pipeline/security invariants and links, run init/fmt/full schema validation for twelve release/edition combinations, optional blocks and invalid inputs. Synthetic manifests exercise acceptance/rejection. Static schema acceptance of expired Pro 24H2 does not authorize live use. These checks do not certify a real ISO or image.

Hosted validate.yml compiles four source-pinned sibling plugins and uploads evidence. Their private/unpublished commits must be reachable by the workflow token. Manual build.yml requires trusted main, authorize_live_build, protected hyperv-build environment and a dedicated Windows/X64/hyperv-image-factory runner. Configure reviewers, PACKER_PLUGIN_PATH variable and PACKER_ADMINISTRATOR_PASSWORD environment secret. Never run untrusted PR jobs there.

Reports upload on failure; VHDX publication requires success and explicit upload input. Keep report/output paths at defaults for workflow discovery. ExternalStorage accepts an existing mounted directory authenticated by runner identity; a unique destination is created and disk copy hash verified, without overwrite or embedded credentials.

For init failures use the local installer and inspect .validation/plugin-provenance.json: custom downloadable releases were unavailable in the source audit. For media errors inspect exact metadata/enablement packages, not filenames. For TPM errors check host/key-protector capabilities. For WinRM check scoped DHCP, bootstrap and certificates without disabling firewall. For servicing/Sysprep inspect plugin JSON, reports/<id>/packer.log, Panther, CBS, DISM and Sysprep logs. AppX readiness failures require clean account/media provisioning, not framework deletion. Packer normally disposes its failed VM; preserve diagnostics through an approved dedicated-host procedure. Never retry while a prior servicing task may still run, and never use packer -force.
