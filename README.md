# 🖥️ packer-hyperv-windows

Packer HCL2 factory for generalized Windows 10/11 x64 Hyper-V VHDX templates. Reuses the architecture of `packer-hyperv-windows-server`: one shared ISO source, audited plugins, scoped HTTPS WinRM, controlled servicing, builder-owned Sysprep and detached read-only release verification. The original project is unchanged.

## 🪟 Supported Windows releases

| Release | Installed build | Editions | Lifecycle/qualification |
| --- | --- | --- | --- |
| Windows 10 22H2 | 19045 | Pro, Enterprise, Education | EOL acknowledgement required; limited local hardening policy |
| Windows 11 24H2 | 26100 | Enterprise, Education | Pro servicing expired; live Pro builds rejected |
| Windows 11 25H2 | 26200 | Pro, Enterprise, Education | Plugin baseline available |
| Windows 11 26H2 | 26300 | Pro, Enterprise, Education | Official GA; plugin baseline available |

These are implemented targets, not live-qualified images. English volume-license media is required. N/LTSC/IoT/Home/ARM64 are outside scope. [Microsoft release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information) lists 26H2 GA on 2026-09-29; [Windows 10 standard support](https://learn.microsoft.com/en-us/lifecycle/announcements/windows-10-22h2-end-of-support-update) ended on 2025-10-14.

## 🚀 Getting started

Use a dedicated elevated Hyper-V host with supported hardware, an isolated DHCP switch, Windows ADK Deployment Tools (`oscdimg.exe`), Packer 1.16.2 and Go for local plugin compilation.

```powershell
./scripts/Install-LocalPlugins.ps1
$env:PACKER_PLUGIN_PATH = "$pwd/.validation/plugins"
./tests/static/Test-Project.ps1
# Prepare private settings with approved media and inject the password from a secret store.
./scripts/Build.ps1 -Version 11-25H2 -SettingsPath C:/Private/win11.json
./scripts/Build.ps1 -Version 11-25H2 -SettingsPath C:/Private/win11.json -Build
```

The first build command validates configuration only. `-Build` authorizes creation and disposal of an isolated VM after preflight. Supply `PKR_VAR_administrator_password` through the environment, never settings or command arguments. See [examples](examples/README.md).

## 🏗️ Factory layout and pipeline

`versions.pkr.hcl` pins dependencies; `variables.pkr.hcl` defines inputs; `sources.pkr.hcl` defines Gen 2/Secure Boot/vTPM; `build.pkr.hcl` orders provisioning. Release selections live in `config/`, Setup XML in `http/autounattend/`, host/guest operations in `scripts/`, and static/live checks in `tests/`.

The pipeline validates installed identity, handles optional features and approved software, optimizes/hardens compatible releases, applies desktop policies, installs offline/online updates with restarts, verifies settings, cleans safely and collects evidence. Builder shutdown runs detached SYSTEM Sysprep. Read-only host verification gates the manifest and disk SHA256. Outputs use `win<release>-<edition>-<image_version>-<unique_id>`; existing resources are never overwritten.

## 📚 Documentation

- [Operations and troubleshooting](docs/operations.md)
- [Plugin interfaces and compatibility](docs/plugin-audit.md)
- [Source analysis and desktop differences](docs/source-analysis.md)
- [Actual validation and limitations](docs/implementation-report.md)
- [Agent instructions](AGENTS.md)

## 🔐 Media, licensing and qualification

No ISO, installer, activation entitlement or ESU enrollment is bundled. Software is opt-in using approved hashes/signatures. The missing software plugin uses a documented MSI/VC++ bridge; Windows 10 has no compatible plugin security baseline and uses explicitly limited local policy.
