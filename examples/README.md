# Build examples

Each JSON file selects one release/edition. Professional is the Pro DISM edition ID. Expired Win11 24H2 Pro is omitted. Windows 10 examples acknowledge support expiry without claiming ESU entitlement. All paths/hashes are placeholders, not approved identities. Copy outside the repository and approve actual media/name/hash, switch and host CIDR. Inject PKR_VAR_administrator_password from your secret store.

```powershell
./scripts/Build.ps1 -Version 10-22H2 -SettingsPath C:/Private/win10-enterprise.json
./scripts/Build.ps1 -Version 11-24H2 -SettingsPath C:/Private/win11-education.json
./scripts/Build.ps1 -Version 11-25H2 -SettingsPath C:/Private/win11-pro.json -Build
./scripts/Build.ps1 -Version 11-26H2 -SettingsPath C:/Private/win11-enterprise.json -Build
```

-Build authorizes a live VM; omit it for configuration validation. [Operations](../docs/operations.md) explains all settings. For PowerShell 7 supply an official signed x64 machine-wide MSI with hash, ID, ProductCode under software_packages. VC++ x64/x86 use separate approved Microsoft-signed EXEs, kind=vcredist, version-specific uninstall GUIDs and hashes. Additional MSI packages use kind=msi. No download occurs automatically; empty arrays request no software.

Enable NetFx3 only with matching SxS. Consumer app removal is optional/narrow; dependencies remain. For offline MSUs supply all prerequisites in vendor order under approved_oob_packages; a hash alone does not establish trusted provenance.
