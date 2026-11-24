## Summary

<!-- What changes and why. -->

## Related issues

<!-- Closes # / Refs #. Larger changes should start with an issue (see CONTRIBUTING.md). -->

## Compatibility

- [ ] No breaking change, or the impact on existing releases, editions, settings, outputs or workflows is described below
- [ ] Affected releases and editions:

## Static validation

- [ ] `./tests/static/Test-Project.ps1` passes. If `-SkipPacker` was used, the skipped coverage is stated
- [ ] `packer fmt -check -recursive .` and `packer validate` pass for all twelve configurations (part of the suite)
- [ ] PSScriptAnalyzer (`Invoke-ScriptAnalyzer -Recurse -Severity Error, Warning` on `scripts` and `tests`) reports no findings, or N/A
- [ ] Guest and bootstrap scripts remain Windows PowerShell 5.1 compatible, or N/A
- [ ] `actionlint` passes for workflow changes, or N/A
- [ ] New invariants and bug fixes have static tests where a static check can detect them

## Live validation

Static and schema checks do not prove image behavior. Complete this section for changes to Setup, bootstrap, provisioning, servicing, finalization, host checks or verification.

- [ ] Not required: the change does not affect build behavior
- [ ] Built with `Build.ps1 -Build` or `Test-Build.ps1 -AuthorizeLiveBuild` on a dedicated host. Release, edition, host build and sanitized evidence are attached
- [ ] Unattended Setup completed without prompts, autologon or extra accounts
- [ ] Hyper-V: Gen 2, Secure Boot and Windows 11 vTPM worked without hardware bypasses
- [ ] Plugin stages ran at their pinned versions and their reports show no failed or pending results
- [ ] Windows Update, offline packages and restarts completed within their bounds, with no pending restart at validation
- [ ] Sysprep generalized and shut down the VM, and offline verification and the manifest passed
- [ ] The temporary account, WinRM listener, certificate, firewall rule and cached answer files were removed
- [ ] Not run. Reason:

## Security, performance and reliability

- [ ] No credentials, product keys or sensitive data in code, examples, logs, reports or artifacts
- [ ] No weakening of WinRM scope, firewall, Defender, Secure Boot or hardening, or of hash and signature checks
- [ ] Workflows keep minimum permissions, pinned versions and env-passed inputs, and pull request jobs stay off the self-hosted runner, or N/A
- [ ] Cleanup stays exact-file only, and servicing metadata is untouched

Security, performance or reliability impact:

## Documentation

- [ ] README, operating guide, plugin audit, implementation report and examples updated where behavior changed, or N/A
- [ ] Limitations, deferrals and qualification status are stated accurately
- [ ] Release notes are drafted in this description for user-visible changes, or N/A
