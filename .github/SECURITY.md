# Security policy

## Supported versions

This repository publishes source releases only. It does not distribute Windows images, installation media, plugin binaries or installers. Security fixes land on `main` and ship in the next release; older releases are not patched.

| Version | Supported |
| --- | --- |
| `main` and the latest release | Yes |
| Older releases | No |

Images built from this factory belong to the operator who built them. A fix in the factory does not update an existing image; rebuild it and redeploy it.

## Reporting a vulnerability

Do not open a public issue, pull request or discussion.

Use [private vulnerability reporting](https://github.com/larskroghdk/packer-hyperv-windows/security/advisories/new) (Security tab, "Report a vulnerability").

Include:

- The commit or release, `packer version` and `packer plugins installed` output, and the custom plugin commit and dirty fields from `.validation/plugin-provenance.json`.
- Host Windows version and build, and the target Windows release and edition.
- The affected stage: wrapper preflight, answer media, bootstrap, provisioning, finalization, offline verification or a GitHub Actions workflow.
- Steps to reproduce, the impact, and relevant log excerpts with secrets removed.

Never include passwords, tokens, product keys, answer media, ISO files, VHDX files or internal host names. Test only on hosts and media you own or are authorized to use.

## Process

The target is to acknowledge a report within 7 days. This is a single-maintainer project, so all timelines are best effort. The maintainer confirms or rejects the issue, agrees a disclosure date with the reporter, and publishes a fix with a GitHub Security Advisory. A CVE is requested through GitHub when appropriate. Reporters are credited unless they decline.

## Scope

In scope are defects in this repository that weaken the factory's security model:

- **Secrets.** The build password, or any credential, reaching tracked files, settings, command arguments, reports, Packer logs, workflow artifacts or the captured VHDX. Answer media holds the temporary password by necessity, so its isolation, ACLs and disposal under `.build/<id>` are in scope.
- **Unattended installation.** Autologon, unescaped values in `Autounattend.xml`, or a temporary account (`PackerBuild`, built-in Administrator credential) that survives finalization.
- **WinRM and PowerShell.** The bootstrap listener, certificate or scoped firewall rule surviving finalization, scope widened beyond `winrm_allowed_address`, protocols weakened, or input interpolated into elevated PowerShell command text.
- **Elevated execution.** Host scripts that run elevated and act on paths, VMs, switches or outputs they did not create, or that delete outside the exact verified build path.
- **Media integrity.** Bypassing the SHA256, image name, build, edition or architecture checks, or accepting ambiguous media instead of failing closed.
- **Software supply chain.** Bypassing hash or signature checks for approved MSI and VC++ packages or hash checks for offline MSU packages, plugin pins or provenance recording, or the release gate that checks the manifest and VHDX hash.
- **Hyper-V isolation.** Generation 2, Secure Boot, vTPM or switch isolation disabled, or the canonical disk booted or modified during offline verification.
- **Security baselines.** A hardening or Defender/firewall result reported as applied or validated when it is not. Settings deferred in compatibility mode and the limited Windows 10 local policy are documented limitations, not vulnerabilities.
- **GitHub Actions.** Untrusted code reaching the self-hosted `hyperv-image-factory` runner, dispatch input interpolated into shell source, excessive token permissions, or secrets or answer media in uploaded artifacts.

Out of scope; report these upstream:

- Windows, Hyper-V, WinRM, Defender, Sysprep or Windows Setup: [Microsoft Security Response Center](https://msrc.microsoft.com/report).
- Packer, the Hyper-V builder or the Packer plugin SDK: [HashiCorp security](https://www.hashicorp.com/security).
- `packer-plugin-windows-*` plugins: the private vulnerability reporting of the plugin's own repository.
- `rgl/packer-plugin-windows-update`: [its repository](https://github.com/rgl/packer-plugin-windows-update).

## Operator responsibilities

The factory cannot protect a build environment the operator controls. Before running live builds:

- Use a dedicated elevated Hyper-V host and an isolated DHCP switch. WinRM skips PKI validation by design, so the build network must be trusted.
- Supply `PKR_VAR_administrator_password` from a secret store with a unique value per build. Rotate it after any crash or interrupted build. Do not enable `PACKER_LOG` on shared systems.
- Obtain media from Microsoft and approve its SHA256 independently. Approve every software package and offline update by hash and signature.
- Restrict access to the runner workspace, `.build/`, `reports/`, `output/` and Packer caches, and encrypt that storage. Reports contain paths and inventory.
- Protect the `hyperv-build` environment with required reviewers. Never run pull request jobs on the self-hosted runner.
- Treat the captured VHDX as unencrypted. Deploy a copy with a fresh VM, fresh vTPM state and your own unattend for accounts, activation and management. Review retained desktop policies, and apply your own security baseline when the documented deferrals or Windows 10 limitations are unacceptable.

See the [operating guide](../docs/operations.md) for the full procedure.
