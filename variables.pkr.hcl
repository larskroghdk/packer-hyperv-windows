variable "windows_release" {
  type = string
  validation {
    condition     = contains(["10-22H2", "11-24H2", "11-25H2", "11-26H2"], var.windows_release)
    error_message = "Choose 10-22H2, 11-24H2, 11-25H2 or 11-26H2."
  }
}
variable "edition" {
  type    = string
  default = "Enterprise"
  validation {
    condition     = contains(["Professional", "Enterprise", "Education"], var.edition)
    error_message = "Use the exact edition ID: Professional, Enterprise or Education."
  }
}
variable "enable_netfx3" {
  type    = bool
  default = false
}
variable "acknowledge_windows10_eol" {
  type        = bool
  default     = false
  description = "Explicit acknowledgement of Windows 10 end of support. Does not enroll or license ESU."
}
variable "software_packages" {
  type        = list(object({ path = string, sha256 = string, id = string, product_code = string, kind = optional(string, "msi") }))
  default     = []
  description = "Approved machine-wide MSI packages, including PowerShell 7. VC++ Redistributable EXEs use kind=vcredist."
  validation {
    condition     = alltrue([for p in var.software_packages : contains(["msi", "vcredist"], p.kind) && can(regex("^[a-fA-F0-9]{64}$", p.sha256)) && can(regex("^[A-Za-z0-9_-]+$", p.id)) && can(regex("^\\{[A-Fa-f0-9-]{36}\\}$", p.product_code))])
    error_message = "Each MSI requires a safe ID, SHA256 and MSI ProductCode GUID."
  }
}
variable "image_name" {
  type        = string
  description = "Exact /IMAGE/NAME from Get-WindowsImage against the selected Microsoft ISO."
  validation {
    condition     = length(trimspace(var.image_name)) > 0
    error_message = "Supply the exact installation image name."
  }
}
variable "iso_path" {
  type        = string
  description = "Absolute local path to approved official Microsoft installation media."
}
variable "iso_checksum" {
  type = string
  validation {
    condition     = can(regex("^sha256:[0-9a-fA-F]{64}$", var.iso_checksum))
    error_message = "Supply sha256: followed by the approved ISO's 64-digit SHA256."
  }
}
variable "switch_name" {
  type = string
}
variable "administrator_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.administrator_password) >= 16 && can(regex("[A-Z]", var.administrator_password)) && can(regex("[a-z]", var.administrator_password)) && can(regex("[0-9]", var.administrator_password)) && can(regex("[^A-Za-z0-9]", var.administrator_password))
    error_message = "Use a unique password of at least 16 characters with upper/lowercase, a digit and a symbol."
  }
}
variable "administrator_username" {
  type    = string
  default = "Administrator"
  validation {
    condition     = var.administrator_username == "Administrator"
    error_message = "This factory uses the built-in Administrator; use English installation media."
  }
}
variable "cpus" {
  type    = number
  default = 4
  validation {
    condition     = var.cpus >= 2 && floor(var.cpus) == var.cpus
    error_message = "Use at least two whole CPUs."
  }
}
variable "memory_mb" {
  type    = number
  default = 4096
  validation {
    condition     = var.memory_mb >= 4096 && floor(var.memory_mb) == var.memory_mb
    error_message = "Use at least 4096 MB."
  }
}
variable "disk_size_mb" {
  type    = number
  default = 81920
  validation {
    condition     = var.disk_size_mb >= 65536 && floor(var.disk_size_mb) == var.disk_size_mb
    error_message = "Use at least 65536 MB."
  }
}
variable "image_version" {
  type = string
  validation {
    condition     = can(regex("^[0-9][0-9A-Za-z._-]{0,39}$", var.image_version))
    error_message = "Image version must start with a digit and contain only letters, digits, dots, underscores or hyphens."
  }
}
variable "build_id" {
  type        = string
  description = "Unique isolation suffix, supplied by Build.ps1."
  validation {
    condition     = can(regex("^[a-f0-9]{12}$", var.build_id))
    error_message = "Use a unique 12-digit lowercase hexadecimal build ID."
  }
}
variable "output_directory" {
  type    = string
  default = "output"
}
variable "report_directory" {
  type    = string
  default = "reports"
}
variable "winrm_timeout" {
  type    = string
  default = "2h"
}
variable "reboot_timeout" {
  type    = string
  default = "30m"
}
variable "shutdown_timeout" {
  type    = string
  default = "30m"
}
variable "provisioning_timeout" {
  type    = string
  default = "2h"
}
variable "update_timeout" {
  type    = string
  default = "6h"
}
variable "winrm_port" {
  type    = number
  default = 5986
  validation {
    condition     = var.winrm_port >= 1024 && var.winrm_port <= 65535 && floor(var.winrm_port) == var.winrm_port
    error_message = "Choose a TCP port between 1024 and 65535."
  }
}
variable "winrm_allowed_address" {
  type        = string
  description = "Build host IP or CIDR reachable by the guest; restricts the temporary firewall rule."
  validation {
    condition     = can(regex("^[0-9a-fA-F:./]+$", var.winrm_allowed_address))
    error_message = "Supply a host IP or CIDR, never an unrestricted wildcard."
  }
}
variable "netfx_source" {
  type    = string
  default = "C:\\ProgramData\\PackerCleanup\\Staging\\sxs"
  validation {
    condition     = startswith(var.netfx_source, "C:\\ProgramData\\PackerCleanup\\Staging\\") && alltrue([for segment in split("\\", trimprefix(var.netfx_source, "C:\\ProgramData\\PackerCleanup\\Staging\\")) : can(regex("^[A-Za-z0-9_-]+$", segment))])
    error_message = "Choose a named subdirectory inside C:\\ProgramData\\PackerCleanup\\Staging using letters, digits, underscores and hyphens."
  }
}
variable "optimization_profile" {
  type    = string
  default = "recommended"
  validation {
    condition     = contains(["recommended", "performance", "vdi"], var.optimization_profile)
    error_message = "Choose recommended, performance or vdi; recommended preserves desktop dependencies."
  }
}
variable "hardening_profile" {
  type    = string
  default = "non_domain_joined"
  validation {
    condition     = var.hardening_profile == "non_domain_joined"
    error_message = "Base images must not be domain joined."
  }
}
variable "cleanup_profile" {
  type    = string
  default = "safe"
  validation {
    condition     = var.cleanup_profile == "safe"
    error_message = "Only the reviewed safe cleanup profile is supported."
  }
}
variable "update_search_criteria" {
  type    = string
  default = "IsInstalled=0 and IsHidden=0 and Type='Software'"
}
variable "update_limit" {
  type    = number
  default = 25
  validation {
    condition     = var.update_limit >= 1 && var.update_limit <= 1000 && floor(var.update_limit) == var.update_limit
    error_message = "Update batch size must be an integer from 1 through 1000."
  }
}
variable "update_max_retries" {
  type    = number
  default = 5
  validation {
    condition     = var.update_max_retries >= 1 && var.update_max_retries <= 10 && floor(var.update_max_retries) == var.update_max_retries
    error_message = "Update retry limit must be an integer from 1 through 10."
  }
}
variable "approved_oob_packages" {
  type        = list(object({ path = string, sha256 = string, kb = string }))
  default     = []
  description = "Ordered offline Microsoft MSU packages, including checkpoint prerequisites; reviewed and hashed by preflight."
  validation {
    condition     = alltrue([for p in var.approved_oob_packages : can(regex("^[a-fA-F0-9]{64}$", p.sha256)) && can(regex("^KB[0-9]+$", p.kb))])
    error_message = "Each approved package needs its exact SHA256 and KB identity."
  }
}
variable "locale" {
  type    = string
  default = "en-US"
  validation {
    condition     = can(regex("^[a-z]{2}-[A-Z]{2}$", var.locale))
    error_message = "Use a locale such as en-US or da-DK; media UI remains English."
  }
}
variable "keyboard_layout" {
  type    = string
  default = "0409:00000409"
  validation {
    condition     = can(regex("^[0-9a-fA-F]{4}:[0-9a-fA-F]{8}$", var.keyboard_layout))
    error_message = "Use an input locale such as 0409:00000409."
  }
}
variable "time_zone" {
  type    = string
  default = "Romance Standard Time"
}

variable "remove_consumer_apps" {
  type        = bool
  default     = false
  description = "Remove only the reviewed BingNews, BingWeather, GetHelp, Getstarted and XboxApp provisioned packages."
}
