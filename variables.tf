variable "location" {
  description = "Azure region for the Jenkins resources."
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group for Jenkins."
  type        = string
  default     = "rg-jenkins-ado"
}

variable "name_prefix" {
  description = "Short prefix used to name the Jenkins VM and network resources."
  type        = string
  default     = "jenkins-ado"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,18}[a-z0-9])?$", var.name_prefix))
    error_message = "name_prefix must contain 1-20 lowercase letters, numbers, or hyphens."
  }
}

variable "vm_size" {
  description = "Azure VM size for the Jenkins host."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Linux administrator account for SSH access."
  type        = string
  default     = "jenkinsadmin"
}

variable "admin_password" {
  description = "Password for the Linux administrator account. Store as an Azure DevOps secret variable."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12 && length(var.admin_password) <= 72
    error_message = "The administrator password must be between 12 and 72 characters."
  }

  validation {
    condition = (
      (can(regex("[A-Z]", var.admin_password)) ? 1 : 0) +
      (can(regex("[a-z]", var.admin_password)) ? 1 : 0) +
      (can(regex("[0-9]", var.admin_password)) ? 1 : 0) +
      (can(regex("[^A-Za-z0-9]", var.admin_password)) ? 1 : 0)
    ) >= 3
    error_message = "The administrator password must include at least three of: uppercase, lowercase, number, and special character."
  }

  validation {
    condition     = !strcontains(lower(var.admin_password), lower(var.admin_username))
    error_message = "The administrator password must not contain the administrator username."
  }
}

variable "admin_source_cidr" {
  description = "Single trusted IPv4 CIDR allowed to reach SSH and Jenkins on port 8080."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_source_cidr)) && var.admin_source_cidr != "0.0.0.0/0"
    error_message = "admin_source_cidr must be a valid IPv4 CIDR other than 0.0.0.0/0."
  }
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default = {
    managed-by = "terraform"
    workload   = "jenkins"
  }
}
