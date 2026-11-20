# GitHub Copilot instructions

Maintain this Packer HCL2 factory for generalized Windows 10/11 x64 Hyper-V desktop images. Follow [AGENTS.md](../AGENTS.md), the shared source of agent guidance, and the [image factory procedure](../.agents/skills/image-factory/SKILL.md). Load the focused procedures relevant to the change.

## Project layout and scope

- Keep one shared pipeline for Pro, Enterprise and Education. Release selections belong in `config/`; do not duplicate sources by release or edition.
- Use `versions.pkr.hcl` for dependency pins, `variables.pkr.hcl` for inputs, `sources.pkr.hcl` for the Hyper-V builder, and `build.pkr.hcl` for provisioning order.
- Keep unattended Setup templates in `http/autounattend/`, host and guest operations in `scripts/`, and validation in `tests/`.
- Read the [plugin audit](../docs/plugin-audit.md) before changing provisioning and the [operating guide](../docs/operations.md) before running builds. Treat implemented targets and static schema acceptance separately from live-qualified images.

## Implementation rules

- Verify plugin options against Config, generated HCL2Spec, registration, guest actions and tests. Do not infer support from a plugin name or modify sibling plugin repositories.
- Use plugins for implemented operations. Limit scripts to bootstrap, approved software/package bridges, documented desktop policy, evidence, host orchestration and generalization.
- Preserve elevated native Windows PowerShell 5.1, .NET 4.x, WinRM, networking, firewall protection, Defender and servicing dependencies.
- Preserve Gen 2, Secure Boot, Windows 11 vTPM and scoped HTTPS WinRM. Do not bypass hardware requirements or disable protection to resolve connectivity failures.
- Keep software opt-in and hash/signature checked. Preserve ordered approved offline packages and their prerequisites; do not introduce arbitrary installer arguments or automatic downloads.
- Use plugin-owned bounded restarts. Offline packages use the documented `windows-restart` `restart_command` boundary.
- Keep cleanup manifests scoped to exact files. Never manually delete WinSxS, Installer, SoftwareDistribution, Catroot2 or servicing metadata.
- Keep cleanup-plugin `sysprep = false` on Hyper-V. The builder shutdown lifecycle owns Sysprep; no guest provisioning may follow it. Verify the detached disk without booting the canonical image.
- Preserve explicit compatibility limitations: Windows 10 uses limited local policy because no compatible plugin baseline exists; Windows 11 compatibility-mode deferrals remain visible. Do not claim complete Microsoft baseline compliance.

## Credentials and live builds

- Never put build credentials in tracked files, settings, command arguments or reports. Supply `PKR_VAR_administrator_password` through the environment from a secret store.
- Treat answer media, caches and VM working folders as sensitive. Preserve build-directory isolation, scoped disposal and exact-path checks described in the operating guide.
- Live tests require an explicit `-AuthorizeLiveBuild` or `-Build` invocation on a dedicated host. Do not alter existing VMs, switches or media, overwrite outputs, or use `packer -force`.
- Use the host build wrapper for release gates. Direct `packer build` does not perform the complete host verification and manifest workflow.

## Validation and documentation

Run the project static suite after changes:

```powershell
./tests/static/Test-Project.ps1
```

The suite includes documentation links and Packer schema checks. If Packer or plugin prerequisites are unavailable, report the failure and use `-SkipPacker` for the remaining checks; identify the skipped coverage. Syntax and schema checks do not certify guest behavior or production readiness. Do not run a live build merely to validate an edit.

Keep [README.md](../README.md) as the entrypoint, the plugin audit as the interface/dependency record, the operating guide as operator guidance, and the [implementation report](../docs/implementation-report.md) as the record of actual qualification. Align documentation, CI pins and dependency provenance. Update [examples](../examples/README.md) when configuration or build commands change, retaining usable desktop and approved offline-package instructions without credentials or claims that example media identities are approved.

Summarize the change, checks performed, failed or unavailable checks, and remaining compatibility or qualification limits.
