# 📋 Implementation and qualification report

Date: 2026-11-20. Project: packer-hyperv-windows-desktop.

Adapted the inherited HCL2/Gen 2 Hyper-V image factory for Windows 10 22H2 and Windows 11 24H2/25H2/26H2 x64 with applicable Pro/Enterprise/Education editions. Added vTPM, desktop media/identity/lifecycle checks, client features, optional NetFx3, local OOBE account lifecycle, desktop policy, approved software bridge, narrow optional consumer removal and final Defender/firewall/AppX checks. Preserved bounded servicing, safe cleanup, plugin verification, builder Sysprep and read-only offline release gates. See [source analysis](source-analysis.md), [plugin audit](plugin-audit.md) and [operations](operations.md).

## ⚠️ Limitations

No real ISO, Windows SIM, VM installation, WinRM provisioning, live plugin execution, update completion, Sysprep or deployed-image smoke test is certified by static tests. These remain dedicated-host production qualification gates with approved media/secrets.

Windows 10 has no available plugin hardening baseline; limited local policy is explicitly reported. Standard support expired and acknowledgement does not establish ESU. Expired Windows 11 24H2 Pro is rejected for live use. N/LTSC/IoT/Home/ARM64 and retail/OEM/evaluation channels are outside implemented targets. Missing software plugin uses opt-in MSI/VC++ bridge; missing custom update source uses inherited rgl updater. No installers are bundled.

Ambiguous enablement media fails closed; some ESD mount channels need an approved WIM ISO instead. No dedicated WinRE partition; supported CPU and host capabilities require qualification. Capture remains unencrypted and consumers create fresh TPM state. Deployment must review Store capture hold and other retained desktop policies. Enterprise-only policy effectiveness is not claimed on Pro.

## 🧪 Executed validation

- Packer 1.16.2: the final native Windows PowerShell 5.1 run in the delivered directory passed 95 static checks, including init/fmt, all twelve release/edition schemas, negative inputs and optional provisioner blocks. Evidence: reports/final-static-validation.log.
- Optional NetFx3, MSI, VC++ EXE and offline MSU/restart blocks are covered by inert schema fixtures. Nothing in these fixtures is installed.
- Native Windows PowerShell 5.1: 76 syntax, XML escaping, pipeline/security and documentation checks passed; eight isolated software trust/install tests and five pre-Packer input rejection tests passed.
- Synthetic manifest acceptance, SHA256, failed offline/pending-hardening/software rejection, Windows 10 limited baseline and skipped NetFx3 behavior passed.
- PSScriptAnalyzer 1.22.0 reported zero Error/Warning findings for scripts. Evidence: reports/script-analysis.json.
- All twelve settings/example JSON files and both workflow YAML files parsed successfully.
- Four custom plugins compiled and installed from audited local source commits; Hyper-V 1.1.5 and rgl/windows-update 0.18.4 installed successfully. Provenance includes binary SHA256 and dirty state. Three source trees had pre-existing untracked Copilot instruction files; no tracked plugin source was changed.
- Hyper-V schema checks warned of insufficient free host RAM. No approved real media/settings/build secret was supplied. No live VM was created, and no image artifact is claimed.

The Server source repository remained clean at commit 81cf8e34da209fd0942c6cd53cebfdeda3746005. The new sibling project was initialized with a main branch; no commit, push or workflow dispatch was performed. Static results do not establish production image qualification.
