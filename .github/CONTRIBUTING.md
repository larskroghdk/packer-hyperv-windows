# 🤝 Contributing

Bug reports, fixes, documentation corrections and support for new Windows releases are welcome. Open an issue before starting a larger change so the approach can be agreed first.

Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities privately as described in the [security policy](SECURITY.md), never in issues.

Read [AGENTS.md](../AGENTS.md) before changing anything. It lists the invariants every change must keep, and it applies to human contributors as much as to coding agents. The [plugin audit](../docs/plugin-audit.md) and the [operating guide](../docs/operations.md) are required reading for provisioning and build changes.

## 🧰 Development environment

Static development needs:

- Windows with Windows PowerShell 5.1, plus PowerShell 7 for the CI-equivalent run.
- [Packer](https://developer.hashicorp.com/packer/install) 1.16.2, the version pinned in CI. `versions.pkr.hcl` accepts `>= 1.16.2, < 2.0.0`.
- Go 1.26.x and Git, to compile the custom plugins from source.
- The four plugin sources checked out beside this repository: `packer-plugin-windows-features`, `packer-plugin-windows-optimize`, `packer-plugin-windows-harden` and `packer-plugin-windows-cleanup`.
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) for script analysis.

Live builds additionally need a dedicated elevated Hyper-V host that meets the [operating guide](../docs/operations.md) prerequisites: Generation 2 with MicrosoftWindows Secure Boot, virtual TPM support, an existing isolated DHCP switch, [Windows ADK](https://learn.microsoft.com/windows-hardware/get-started/adk-install) Deployment Tools with `oscdimg.exe` on `PATH`, and approved English x64 volume-license media. The repository contains no media, installers or credentials, and contributors must not add them.

## 🔌 Plugin integration

`versions.pkr.hcl` pins every plugin. The custom `windows-features`, `windows-optimize`, `windows-harden` and `windows-cleanup` plugins have no downloadable releases, so `scripts/Install-LocalPlugins.ps1` compiles them from source, installs them into `.validation/plugins` and records commit, dirty state and binary SHA256 in `.validation/plugin-provenance.json`. `hashicorp/hyperv` and `rgl/windows-update` install from their published releases.

```powershell
./scripts/Install-LocalPlugins.ps1    # plugin sources checked out beside this repository
$env:PACKER_PLUGIN_PATH = "$pwd/.validation/plugins"
```

The installer builds whatever each checkout contains, so check out every plugin at the commit pinned in `.github/workflows/validate.yml` and the [plugin audit](../docs/plugin-audit.md), as CI does. A checkout that has moved past its pin builds a different version, and `packer init` rejects it. To leave your working clones untouched, clone the pins into a separate directory and pass it with `-RepositoryRoot`:

```powershell
$root = 'C:/Temp/factory-plugins'
foreach ($pin in @{ features = '891876d5b29fc5b7efc969747a1e55d1019369a2'; optimize = '0f5670039db6ff64b9f157ffd4ec9fb7ed2344c3'; harden = '8dc70d2c81be4515ad243dfbe288d61151ab722d'; cleanup = '862156428506ce6a8d679a28bc18a39882c46c0f' }.GetEnumerator()) {
    git clone --quiet https://github.com/larskroghdk/packer-plugin-windows-$($pin.Key).git "$root/packer-plugin-windows-$($pin.Key)"
    git -C "$root/packer-plugin-windows-$($pin.Key)" checkout --quiet $pin.Value
}
./scripts/Install-LocalPlugins.ps1 -RepositoryRoot $root
$env:PACKER_PLUGIN_PATH = "$pwd/.validation/plugins"
```

Before using a plugin option, inspect its `Config` struct, generated HCL2 spec, registration, guest actions and tests at the pinned commit. Do not infer support from a plugin's name or documentation alone, and do not change sibling plugin repositories from here. A change that moves a plugin pin updates, in the same pull request:

- `versions.pkr.hcl`, the commit in `.github/workflows/validate.yml` and the pinned commits in this guide;
- the commit and the audited interface in the [plugin audit](../docs/plugin-audit.md);
- the configuration that uses any new or changed option, and its static tests.

Features, optimization, hardening, updates and cleanup belong to plugins. Scripts are limited to bootstrap, the approved software and offline-package bridges, documented desktop policy, evidence, host orchestration and generalization. When a plugin lacks a capability, record the gap in the plugin audit rather than reimplementing the plugin in a script.

## 🗂️ Repository structure

| Path | Purpose |
| --- | --- |
| `versions.pkr.hcl` | Packer and plugin version constraints |
| `variables.pkr.hcl` | Inputs and their validation |
| `sources.pkr.hcl` | The single Hyper-V ISO source: Gen 2, Secure Boot, vTPM, HTTPS WinRM, builder-owned Sysprep |
| `build.pkr.hcl` | Provisioning order, shared by every release and edition |
| `config/` | One `windows-desktop-<release>.pkrvars.hcl` per release |
| `http/autounattend/` | Setup answer file template |
| `scripts/` | Host orchestration: `Build.ps1`, `Test-Host.ps1`, `Test-Image.ps1`, `New-Manifest.ps1`, `Install-LocalPlugins.ps1` |
| `scripts/bootstrap/`, `scripts/guest/` | WinRM bootstrap and guest stages, run under elevated Windows PowerShell 5.1 |
| `tests/static/`, `tests/live/` | Static regression suite and the authorized live build test |
| `examples/` | Placeholder settings for each release and edition |
| `docs/` | Operations, plugin audit, source analysis and the implementation report |

Configuration conventions:

- Keep one shared source and build. Release differences belong in `config/` and in the release tables in scripts, not in duplicated sources. Pro, Enterprise and Education share a source.
- Operator settings are JSON files kept outside the repository and passed with `-SettingsPath`. The wrapper selects the release; settings cannot override it.
- `PKR_VAR_administrator_password` comes from the environment only. Never put credentials in tracked files, settings, examples, command arguments or reports.
- Example values are placeholders. Do not present example hashes or image names as approved media identities.

## ✅ Build, validate and test

Run the static suite after every change:

```powershell
./tests/static/Test-Project.ps1
```

It parses all PowerShell and the answer file template, checks pipeline and security invariants and local Markdown links, runs the software and build-input tests and synthetic manifest tests, then runs `packer init`, `packer fmt -check` and `packer validate` for all twelve release and edition combinations, rejected inputs and optional package blocks. Without Packer or the plugins, run it with `-SkipPacker` and state the skipped coverage in the pull request.

Run script analysis separately; the suite does not include it:

```powershell
'scripts', 'tests' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Recurse -Severity Error, Warning }
```

To check a private configuration without creating a VM, run the wrapper without `-Build`:

```powershell
./scripts/Build.ps1 -Version 11-26H2 -SettingsPath C:/Private/win11-26h2.json
```

A live build creates and disposes of an isolated VM. It runs only on a dedicated host, with approved media and a secret-store password, and only with an explicit switch:

```powershell
./scripts/Build.ps1 -Version 11-26H2 -SettingsPath C:/Private/win11-26h2.json -Build
./tests/live/Test-Build.ps1 -Version 11-26H2 -SettingsPath C:/Private/win11-26h2.json -AuthorizeLiveBuild
```

Never use `packer -force`, change existing VMs, switches or media, or overwrite output. A direct `packer build` skips the host release gates and does not produce a validated image. Static and schema checks do not prove Setup, WinRM provisioning, servicing, Sysprep or deployment behavior; only live evidence does.

## 📏 Coding standards

### PowerShell

- Guest and bootstrap scripts run under native elevated Windows PowerShell 5.1. Do not use PowerShell 7-only syntax or modules, and keep PowerShell 5.1 and .NET 4.x intact on the guest.
- Begin every script with comment-based help (`.SYNOPSIS`, `.EXAMPLE`, `.NOTES` with `Author` and `Version`), followed by `$ErrorActionPreference = 'Stop'` and `Set-StrictMode -Version Latest`. Keep the existing author and increase the version when behavior changes.
- Check native exit codes explicitly. Pass secrets through environment variables or protected files, never through arguments. Do not interpolate external input into command text.
- Uploaded guest scripts run from generated paths and must not depend on adjacent repository files. The bootstrap script is the exception.
- `.ps1` files use CRLF line endings, as enforced by `.gitattributes`.

### HCL

- Format with `packer fmt -recursive .`. Validate inputs with `validation` blocks that fail on unsupported values.
- Keep plugin-owned bounded restarts. Offline packages use the documented `windows-restart` `restart_command`. Keep `sysprep = false` in `windows-cleanup`; Sysprep belongs to the builder shutdown lifecycle, and no provisioner may run after it.

### YAML (workflows and issue forms)

- Use two-space indentation and LF line endings. Run `actionlint` on workflow changes.
- Grant minimum `permissions`. Pass dispatch inputs through `env:`, never by interpolating them into `run:` scripts. Pin actions to full commit SHAs with a version comment, pin tools to explicit versions, and pin sibling plugin checkouts to commit SHAs.
- Never route pull request jobs to the self-hosted runner.

### XML (answer files)

- Keep the template well formed and LF-terminated. Escape every substituted value in `sources.pkr.hcl` before templating; the static suite checks password escaping.
- Do not add autologon or product keys other than the public volume-licensing setup keys already used for edition selection. Validate answer-file changes against the target media with Windows System Image Manager before live qualification.

### Markdown

- Use relative links for repository files; the static suite checks them. Keep statements factual and distinguish implemented targets, schema acceptance and live qualification.

## 🪟 Adding a Windows release

New releases follow the existing ones. Document each release as exactly what has been demonstrated: implemented target, statically validated or live-qualified.

1. Confirm the release, its installed build number and the lifecycle of each edition in [Windows release information](https://learn.microsoft.com/windows/release-health/windows11-release-information) and the [Microsoft lifecycle](https://learn.microsoft.com/lifecycle/) pages.
2. Confirm plugin support at the pinned commits. Check `windows-harden` for a baseline and lifecycle entry, and check `windows-optimize` and `windows-cleanup` for build applicability. Record the result, and any deferrals, in the plugin audit.
3. Add `config/windows-desktop-<release>.pkrvars.hcl`.
4. Add the release to the `windows_release` validation in `variables.pkr.hcl`, the `ValidateSet` in `scripts/Build.ps1` and `tests/live/Test-Build.ps1`, and the build tables in `scripts/Test-Host.ps1`, `scripts/guest/Prepare.ps1` and `scripts/guest/Validate.ps1`. When release media ships as an enablement package, add its base build and KB to the enablement table in `Test-Host.ps1`.
5. Add any lifecycle rejection to `Build.ps1`, following the expired Windows 11 24H2 Pro rule.
6. Add the release to the version loop in `tests/static/Test-Project.ps1`, the `windows_release` options in `.github/workflows/build.yml`, and examples for every supported edition.
7. Update the release table in the README, the operating guide and the implementation report. Report static results and live qualification separately.

The same steps apply in reverse when a release is retired.

## 🔀 Branches, commits and pull requests

- Branch from `main` with a short descriptive name such as `fix/winrm-rule-cleanup` or `feat/windows-11-27h2`.
- Write commit messages in [Conventional Commits](https://www.conventionalcommits.org/) form, as the history does: `feat:`, `fix:`, `docs:`, `test:`, `ci:`, `refactor:` or `chore:`, followed by an imperative summary. Keep each commit to one logical change.
- Open a pull request against `main` and complete the [pull request template](PULL_REQUEST_TEMPLATE.md). The `Validate` workflow must pass.
- The maintainer reviews every pull request. Expect questions about invariants, evidence and documentation as well as code. Address review comments with new commits; the maintainer may squash on merge.
- GitHub Actions live builds run only through the protected manual workflow on trusted `main`. Pull requests cannot trigger them, so attach live evidence from your own authorized host when a change needs it.

## 📚 Documentation and test expectations

- Update the documentation that owns the behavior you change: the README as entry point, the plugin audit for interfaces and dependencies, the operating guide for operator decisions, and the implementation report for qualification status. Update `examples/` when configuration or build commands change.
- Add or extend a static test for every invariant you introduce and every bug you fix where a static check can detect it.
- For provisioning, bootstrap, finalization or verification changes, attach sanitized live evidence: release, edition, build, host version and the relevant report excerpts. If you could not run a live build, say so and say why.
- Record limitations, compatibility deferrals and source provenance. Do not claim Microsoft baseline compliance, release support or image qualification that has not been demonstrated.

## 🤖 AI-assisted contributions

Agent guidance lives in [AGENTS.md](../AGENTS.md) and [.agents/skills](../.agents/skills/image-factory/SKILL.md); tool-specific files only link to it. AI-assisted changes meet the same standards as any other change. The author is responsible for verifying every claim and test result in the pull request.

## 📄 License

By contributing, you agree that your contributions are licensed under the [Mozilla Public License 2.0](../LICENSE). Do not submit code or content you do not have the right to license this way, or any Microsoft media, installers or other third-party binaries.
