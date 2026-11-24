build {
  name = "windows-desktop"
  sources = [
    "source.hyperv-iso.windows"
  ]
  provisioner "powershell" {
    script           = "scripts/guest/Prepare.ps1"
    environment_vars = ["FACTORY_RELEASE=${var.windows_release}", "FACTORY_EDITION=${var.edition}", "FACTORY_NETFX_SOURCE=${var.netfx_source}", "FACTORY_NETFX3=${var.enable_netfx3}", "FACTORY_EOL=${var.acknowledge_windows10_eol}"]
    timeout          = var.provisioning_timeout
  }
  provisioner "windows-features" {
    remove              = ["MicrosoftWindowsPowerShellV2Root"]
    ignore_unavailable  = true
    restart_if_required = true
    restart_timeout     = var.reboot_timeout
    operation_timeout   = var.provisioning_timeout
    report_path         = "${local.reports}/features-remove.json"
  }
  dynamic "provisioner" {
    for_each = var.enable_netfx3 ? [1] : []
    labels   = ["windows-features"]
    content {
      install             = ["NetFx3"]
      source              = var.netfx_source
      limit_access        = true
      restart_if_required = true
      restart_timeout     = var.reboot_timeout
      operation_timeout   = var.provisioning_timeout
      report_path         = "${local.reports}/features-netfx.json"
    }
  }
  dynamic "provisioner" {
    for_each = var.software_packages
    labels   = ["file"]
    content {
      source      = provisioner.value.path
      destination = "C:/ProgramData/PackerCleanup/Staging/${provisioner.value.id}.${provisioner.value.kind == "msi" ? "msi" : "exe"}"
    }
  }
  provisioner "file" {
    content     = jsonencode(var.software_packages)
    destination = "C:/ProgramData/ImageFactory/software.json"
  }
  provisioner "powershell" {
    script  = "scripts/guest/Install-Software.ps1"
    timeout = var.provisioning_timeout
  }
  provisioner "windows-restart" {
    restart_timeout = var.reboot_timeout
  }
  provisioner "windows-optimize" {
    profile            = var.optimization_profile
    reboot_if_required = true
    restart_timeout    = var.reboot_timeout
    report_path        = "${local.reports}/optimization.json"
    timeout            = var.provisioning_timeout
  }
  dynamic "provisioner" {
    for_each = startswith(var.windows_release, "11-") ? [1] : []
    labels   = ["windows-harden"]
    content {
      baseline           = "auto"
      profile            = var.hardening_profile
      mode               = "compatibility"
      reboot_if_required = true
      restart_timeout    = var.reboot_timeout
      report_path        = "${local.reports}/hardening.json"
      timeout            = var.provisioning_timeout
    }
  }
  provisioner "powershell" {
    script           = "scripts/guest/Set-DesktopPolicy.ps1"
    environment_vars = ["FACTORY_RELEASE=${var.windows_release}", "FACTORY_REMOVE_CONSUMER=${var.remove_consumer_apps}"]
  }
  dynamic "provisioner" {
    for_each = var.approved_oob_packages
    labels   = ["file"]
    content {
      source      = provisioner.value.path
      destination = "C:/ProgramData/PackerCleanup/Staging/${provisioner.value.kb}.msu"
    }
  }
  provisioner "file" {
    content     = jsonencode(var.approved_oob_packages)
    destination = "C:/ProgramData/ImageFactory/oob.json"
  }
  provisioner "file" {
    source      = "scripts/guest/Install-ApprovedPackage.ps1"
    destination = "C:/Windows/Temp/packer-factory-oob.ps1"
  }
  dynamic "provisioner" {
    for_each = var.approved_oob_packages
    labels   = ["windows-restart"]
    content {
      restart_command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\packer-factory-oob.ps1 -KB ${provisioner.value.kb} -Sha256 ${provisioner.value.sha256}"
      restart_timeout = var.reboot_timeout
      timeout         = var.provisioning_timeout
    }
  }
  provisioner "windows-update" {
    search_criteria    = var.update_search_criteria
    filters            = ["exclude:$_.Title -match 'Preview'", "include:$true"]
    update_limit       = var.update_limit
    update_max_retries = var.update_max_retries
    restart_timeout    = var.reboot_timeout
    timeout            = var.update_timeout
  }
  provisioner "windows-restart" {
    restart_timeout = var.reboot_timeout
  }
  provisioner "windows-optimize" {
    profile     = var.optimization_profile
    dry_run     = true
    report_path = "${local.reports}/optimization-validation.json"
    timeout     = var.provisioning_timeout
  }
  dynamic "provisioner" {
    for_each = startswith(var.windows_release, "11-") ? [1] : []
    labels   = ["windows-harden"]
    content {
      baseline    = "auto"
      profile     = var.hardening_profile
      mode        = "compatibility"
      dry_run     = true
      report_path = "${local.reports}/hardening-validation.json"
      timeout     = var.provisioning_timeout
    }
  }
  provisioner "file" {
    direction   = "download"
    source      = "C:/ProgramData/ImageFactory/software-report.json"
    destination = "${local.reports}/software.json"
  }
  provisioner "file" {
    direction   = "download"
    source      = "C:/ProgramData/ImageFactory/desktop-policy.json"
    destination = "${local.reports}/desktop-policy.json"
  }
  provisioner "windows-cleanup" {
    profile                = var.cleanup_profile
    component_store        = true
    windows_update         = true
    provisioning_artifacts = true
    artifact_paths = concat([
      var.netfx_source,
      "C:\\Windows\\Panther\\Unattend.xml",
      "C:\\Windows\\Panther\\Unattend\\Unattend.xml",
      "C:\\Windows\\System32\\Sysprep\\Unattend.xml",
      "C:\\Windows\\Temp\\packer-windows-update.ps1",
      "C:\\Windows\\Temp\\packer-windows-update-elevated.ps1",
      "C:\\Windows\\Temp\\packer-factory-oob.ps1",
      "C:\\Windows\\Temp\\packer-windows-update-pending-reboot-elevated.ps1"
      ],
      [for p in var.software_packages : "C:\\ProgramData\\PackerCleanup\\Staging\\${p.id}.${p.kind == "msi" ? "msi" : "exe"}"],
    [for p in var.approved_oob_packages : "C:\\ProgramData\\PackerCleanup\\Staging\\${p.kb}.msu"])
    pending_reboot_policy = "error"
    validate_system       = true
    required_services     = ["WinRM", "RpcSs"]
    required_features     = var.enable_netfx3 ? ["NetFx3"] : []
    sysprep               = false
    operation_timeout     = var.provisioning_timeout
    report_path           = "${local.reports}/cleanup.json"
  }
  provisioner "powershell" {
    script           = "scripts/guest/Validate.ps1"
    environment_vars = ["FACTORY_RELEASE=${var.windows_release}", "FACTORY_EDITION=${var.edition}", "FACTORY_SEARCH=${var.update_search_criteria}", "FACTORY_NETFX3=${var.enable_netfx3}"]
    timeout          = var.provisioning_timeout
  }
  provisioner "file" {
    direction   = "download"
    source      = "C:/ProgramData/ImageFactory/validation.json"
    destination = "${local.reports}/validation.json"
  }
  provisioner "file" {
    source      = "scripts/guest/Finalize.ps1"
    destination = "C:/ProgramData/ImageFactory/Finalize.ps1"
  }
  post-processor "manifest" {
    output     = "${local.reports}/packer-manifest.json"
    strip_path = false
    custom_data = {
      windows_release = var.windows_release
      edition         = var.edition
      image_version   = var.image_version
      image_id        = local.image_id
      iso_checksum    = var.iso_checksum
    }
  }
}
